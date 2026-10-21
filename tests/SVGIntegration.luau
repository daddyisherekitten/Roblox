--!strict
return function(Embedded,HTMLParser,Queue,loadImages,Raster,Hit,Stress,fixtureHTML)
 local page=HTMLParser.parse('<div><svg style="width:50%" viewBox="0 0 100 50"><defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x2="100"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs><rect width="100" height="50" fill="url(#g)"/></svg><svg viewBox="0 0 100 50"><defs><linearGradient id="g"><stop stop-color="green"/></linearGradient></defs><rect width="100" height="50" fill="url(#g)"/></svg></div>')
 local a,b=Embedded.document(page.Children[1].Children[1]),Embedded.document(page.Children[1].Children[2])
 assert(a.Ids.g.Name=='linearGradient' and a.Ids.g.Attributes.gradientUnits=='userSpaceOnUse','Foreign HTML names restored')
 assert(a.Ids.g~=b.Ids.g,'Independent resource ID scopes')
 local scene,errors=Embedded.build(a,200,100);assert(#errors==0,errors[1] and errors[1].Code)
 local bytes=Raster.render(scene,nil,200);local other=Raster.render(Embedded.build(b,200,100),nil,200)
 assert(buffer.readu8(bytes,0)>200 and buffer.readu8(bytes,199*4+2)>200,'Gradient covers full CSS box, no repeated percentage sizing')
 assert(buffer.readu8(other,1)>100 and buffer.readu8(other,0)==0,'Second instance keeps independent green paint')
 assert(page.Children[1].Children[1].Attributes.width==nil,'Rendering does not modify HTML source')
 local jobs={};local taskAPI={defer=function(fn)table.insert(jobs,coroutine.create(fn))end,wait=function()coroutine.yield()end}
 local function step() local co=table.remove(jobs,1);if co then local ok,e=coroutine.resume(co);assert(ok,e);if coroutine.status(co)~='dead' then table.insert(jobs,co) end end end
 local function drain()local n=0;while #jobs>0 do n+=1;assert(n<10000,'No unbounded worker');step() end end
 local live,created=0,0
 local api={CreateEditableImage=function(_,opts)
  live+=1;created+=1;local image={Size=opts.Size}
  function image:WritePixelsBuffer(_,_,pixels)assert(not self.Dead);self.Pixels=pixels end
  function image:Destroy()assert(not self.Dead);self.Dead=true;live-=1 end
  return image
 end}
 local mockRaster={render=function(s,_,width,check)taskAPI.wait();if not check() then return nil end;local p=buffer.create(width*math.round(s.Height*width/s.Width)*4);buffer.writeu8(p,0,s.Value or 1);return p end}
 local queue=Queue.new(api,mockRaster,taskAPI,{CacheBytes=1024*1024,MaxBytes=1024*1024,Report=error});local owner={};local installed
 local function request(key,w,value)queue:Request(owner,key,function()return {Width=w,Height=40,Value=value}end,function(image)installed=image end)end
 for i=1,100 do request('size'..i,100+i,i) end
 drain();assert(queue.Stats.Rasters==1 and installed.Size.X==200 and buffer.readu8(installed.Pixels,0)==100,'Burst builds and paints only final size')
 local image=installed;request('paint',200,22);drain();assert(installed==image,'Same-size update reuses texture')
 request('size100',200,100);drain();assert(queue.Stats.CacheHits==1 and queue.Stats.Rasters==2,'Warm state reuses CPU pixels')
 request('old',210,2);step();request('new',220,3);drain();assert(installed.Size.X==220 and buffer.readu8(installed.Pixels,0)==3,'Superseded render cannot upload stale size')
 assert(live==1 and queue.Stats.LiveBytes==220*40*4)
 request('dispose',230,4);step();queue:Destroy();drain();assert(live==0 and queue.Stats.LiveBytes==0 and queue.CacheBytes==0)
 for _=1,20 do local q=Queue.new(api,mockRaster,taskAPI,{Report=error});q:Request({},'cycle',function()return {Width=80,Height=40}end,function()end);drain();q:Destroy();assert(live==0) end
 local diagnostics={};local attrs={};local cleanups={};local htmlPage={Alive=true,Root={SetAttribute=function(_,k,v)attrs[k]=v end},AddCleanup=function(_,fn)table.insert(cleanups,fn)end}
 local node=HTMLParser.parse('<svg viewBox="0 0 100 50"><style>.hot:hover{fill:green}</style><rect class="hot" width="50" height="50" fill="blue" cursor="crosshair"/><rect x="50" width="50" height="50" fill="red"/></svg>').Children[1]
 local item={SVG=node,ContentWidth=200,ContentHeight=100,Style={FontSize=16},ImageGui={AbsolutePosition={X=20,Y=50},AbsoluteSize={X=200,Y=100}}}
 local tree={SVGItems={item}};local images=loadImages(Embedded,Queue,Raster,Hit)
 local q=images.start(htmlPage,tree,function(m)table.insert(diagnostics,m)end,{Asset=api,Task=taskAPI,Inset={X=0,Y=36}})
 item.UpdateSVG();drain();assert(#diagnostics==0,diagnostics[1]);assert(attrs.SVGReady and live==1)
 assert(q.Stats.WarmQueued==1 and q.Stats.WarmCompleted==1 and attrs.SVGPrewarmPending==0,'Initial paint prepares the unique hover state in the background')
 assert(tree.MousePosition({X=40,Y=86}).Y==50,'Screen-to-GUI conversion once')
 local staticRasters=q.Stats.Rasters;assert(tree.SVGCursor(node,{X=140,Y=80})==nil);drain()
 assert(q.Stats.Rasters==staticRasters,'Hovering between elements without matching state CSS does not redraw')
 assert(tree.SVGCursor(node,{X=40,Y=80})=='crosshair');drain()
 local rasters=q.Stats.Rasters;assert(tree.SVGCursor(node,{X=40,Y=80})=='crosshair');drain();assert(q.Stats.Rasters==rasters,'Unchanged hover does not redraw')

 local useNode=HTMLParser.parse('<svg viewBox="0 0 100 50"><defs><rect id="shape" width="40" height="40"/></defs><style>.hot:hover{fill:green}</style><use class="hot" href="#shape" fill="blue"/></svg>').Children[1]
 local useDoc=Embedded.document(useNode);local useScene=Embedded.build(useDoc,100,50,{});local useHit=Hit.query(Hit.prepare(useScene,1),20,20)
 assert(useHit and useHit.SourceNode==useDoc.Root.Children[3],'use hit is retargeted to the visible use instance')
 -- The HTML hit picker passes nil for a clipped/occluded SVG; hover is removed.
 assert(tree.SVGCursor(nil,{X=40,Y=80})==nil);drain()
 item.ImageGui.AbsolutePosition={X=20,Y=-50};assert(tree.SVGCursor(node,{X=40,Y=0})=='crosshair');drain()
 item.ContentWidth=100;item.UpdateSVG();drain();assert(q.Stats.WarmQueued==2 and q:WarmPending()==0,'Resize discards old states and prepares the new raster size')
 item.ContentWidth=0;item.UpdateSVG();assert(q:WarmPending()==0 and live==0,'Zero-size SVG releases its image and prepared states')
 item.ContentWidth=100;item.UpdateSVG();drain();assert(q.Stats.WarmQueued==3 and live==1,'Restoring the same size prepares its states again after removal')
 for _,fn in cleanups do fn() end;drain();assert(live==0 and not item.UpdateSVG and not tree.SVGCursor)
 -- Exercise the real HTML SVG host, including per-instance CSS and warm scene reuse.
 local uses=HTMLParser.parse('<svg width="120" height="40"><defs><rect id="tile" width="40" height="40"/></defs><style>.hot{fill:blue}.hot:hover{fill:yellow}</style><use class="hot" href="#tile"/><use class="hot" href="#tile" x="40"/><rect x="80" width="40" height="40" fill="red"/></svg>').Children[1]
 local ui={SVG=uses,ContentWidth=120,ContentHeight=40,Style={FontSize=16},ImageGui={AbsolutePosition={X=0,Y=0},AbsoluteSize={X=120,Y=40}}}
 local ut={SVGItems={ui}};local uq=images.start(htmlPage,ut,error,{Asset=api,Task=taskAPI})
 ui.UpdateSVG();drain()
 assert(uq.Stats.WarmQueued==2 and uq.Stats.WarmCompleted==2 and attrs.SVGPrewarmDone==2 and attrs.SVGReady,'Both unique use hover states are prepared before interaction')
 local function probe(x,r,g,b)
  local p=ui.ImageGui.ImageContent.Pixels;local at=(20*120+x)*4
  assert(buffer.readu8(p,at)==r and buffer.readu8(p,at+1)==g and buffer.readu8(p,at+2)==b,'Expected hover pixel at '..x)
 end
 local cancelled=uq.Stats.Cancelled;local preparedBuilds,preparedRasters=uq.Stats.Builds,uq.Stats.Rasters
 ut.SVGCursor(uses,{X=20,Y=20});step();ut.SVGCursor(uses,{X=60,Y=20});drain()
 assert(uq.Stats.Cancelled==cancelled,'Rapid immutable hover finishes and caches stale work instead of cancelling it')
 assert(uq.Stats.Builds==preparedBuilds and uq.Stats.Rasters==preparedRasters,'First hover uses precomputed pixels without scene construction or rasterization')
 probe(20,0,0,255);probe(60,255,255,0)
 ut.SVGCursor(uses,{X=20,Y=20});drain();probe(20,255,255,0);probe(60,0,0,255)
 ut.SVGCursor(uses,{X=60,Y=20});drain();probe(20,0,0,255);probe(60,255,255,0)
 ut.SVGCursor(uses,{X=100,Y=20});drain();probe(20,0,0,255);probe(60,0,0,255)
 local builds,rasters,hitBuilds=uq.Stats.Builds,uq.Stats.Rasters,uq.Stats.HitBuilds
 for _=1,12 do
  for _,x in {20,60,100} do ut.SVGCursor(uses,{X=x,Y=20});drain() end
 end
 assert(uq.Stats.HitBuilds==hitBuilds,'Warm hover also reuses hitboxes')
 assert(uq.Stats.Builds==builds and uq.Stats.Rasters==rasters,'Warm hover must skip scene construction AND rasterization')
 ut.SVGCursor(uses,{X=20,Y=20});ut.SVGCursor(uses,{X=60,Y=20});drain();probe(20,0,0,255);probe(60,255,255,0)
 for _,fn in cleanups do fn() end;drain();assert(live==0)
 print('SVG S43/S44: embedded viewport/gradient/ID scopes, queue coalescing/cache/cancellation, hover/scroll mapping and 20 clean lifecycles passed')
 local embeddedCount=0
 local function checkFixture(n)
  if n.Name=='svg' then
   local _,issues=Embedded.build(Embedded.document(n),480,200)
   assert(#issues==0,'Full HTML fixture SVG '..tostring(embeddedCount+1)..': '..tostring(issues[1] and issues[1].Code))
   embeddedCount+=1;return
  end
  for _,child in n.Children or {} do checkFixture(child) end
 end
 checkFixture(HTMLParser.parse(fixtureHTML));assert(embeddedCount==11)
 print('SVG S43/S44: all 11 full-page SVG scenes build without diagnostics')
 local scenes={}
 for _,source in Stress.Cases do
  local doc=Embedded.document(HTMLParser.parse(source.SVG).Children[1]);local s,issues=Embedded.build(doc,480,200);assert(#issues==0,issues[1] and issues[1].Code)
  local started=os.clock();local pixels=Raster.render(s,nil,480);local ms=(os.clock()-started)*1000;assert(buffer.len(pixels)==480*200*4)
  print('SVG_STRESS_BENCH',source.Name,string.format('%.3f',ms),'ms',#s.Shapes,'shapes',buffer.len(pixels),'bytes');table.insert(scenes,s)
 end
 return scenes
end
