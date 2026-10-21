--!strict
return function(Embedded,HTMLParser,Raster,Hit,html,Queue)
 local function find(n,name)
  if n.Name==name then return n end
  for _,c in n.Children or {} do local v=find(c,name);if v then return v end end
 end
 local doc=Embedded.document(assert(find(HTMLParser.parse(html),'svg')))
 local hot={}
 local function collect(n)
  if n.Attributes and n.Attributes.class=='crystal' then table.insert(hot,n) end
  for _,c in n.Children or {} do collect(c) end
 end
 collect(doc);assert(#hot==7,'Benchmark uses the seven current hover targets')
 local function checksum(bytes)
  local a,b=1,0
  for i=0,buffer.len(bytes)-1 do a=(a+buffer.readu8(bytes,i))%65521;b=(b+a)%65521 end
  return string.format('%08x',b*65536+a)
 end
 local work=if Raster.createWork then Raster.createWork() else nil
 local queue,owner,nextPixels
 if Queue then
  owner={}
  queue=Queue.new({CreateEditableImage=function(_,o)
   return {Size=o.Size,WritePixelsBuffer=function()end,Destroy=function()end}
  end},{render=function()return nextPixels end},{defer=function(fn)fn()end,wait=function()end},{Report=error})
 end
 for i=0,#hot do
  local before=os.clock()
  local scene,issues=Embedded.build(doc,446,576,{hover=hot[i]})
  if i==0 then for _,issue in issues do print('SVG_BENCH_DIAGNOSTIC',issue.Code,issue.Value) end end
  local buildMS=(os.clock()-before)*1000
  local checks,yields,last=0,0,os.clock();before=last
  local bytes=assert(Raster.render(scene,nil,446,function()
   checks+=1
   if os.clock()-last>=.004 then yields+=1;last=os.clock() end
   return true
  end,work))
  local rasterMS=(os.clock()-before)*1000
  before=os.clock();local snapshot=Hit.prepare(scene,1);local hitMS=(os.clock()-before)*1000
  before=os.clock()
   for n=1,500 do Hit.query(snapshot,n%446,(n*7)%576) end
  print(string.format('SVG_BENCH state=%d build_ms=%.3f raster_ms=%.3f hit_build_ms=%.3f query_500_ms=%.3f checks=%d yields=%d checksum=%s',i,buildMS,rasterMS,hitMS,(os.clock()-before)*1000,checks,yields,checksum(bytes)))
  if queue then
   nextPixels=bytes
   queue:Request(owner,tostring(i),function()return scene end,function()scene.EmbeddedSnapshot=snapshot end,true)
  end
 end
 if queue then
  print('SVG_BENCH_CACHE',#queue.Cache,queue.Stats.CacheBytes,queue.Stats.CacheFields,queue.Stats.CacheSkipped)
  for i=0,#hot do queue:Request(owner,tostring(i),function()error('Demo state unexpectedly evicted')end,function()end,true) end
  queue:Destroy()
 end
 if work and Raster.releaseWork then Raster.releaseWork(work) end
end
