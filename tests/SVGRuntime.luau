--!strict
return function(Events,Session,Actions,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Gradient,Resources,Sources,Text)
 local function near(a,b,label) assert(math.abs(a-b)<.02,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b)) end
 local errors={};local bus=Events.new(function(e) table.insert(errors,e) end)
 local root={};local group={Parent=root};local child={Parent=group};local trace={}
 for _,spec in {{root,true,'rc'},{group,true,'gc'},{child,true,'tc'},{child,false,'tb'},{group,false,'gb'},{root,false,'rb'}} do
  bus:On(spec[1],'x',function(e) table.insert(trace,spec[3]);assert(e.Target==child) end,spec[2])
 end
 bus:Emit(child,'x');assert(table.concat(trace,',')=='rc,gc,tc,tb,gb,rb','capture / target / bubble order')
 local n=0;bus:On(child,'once',function() n+=1;bus:Emit(child,'once') end,{Once=true});bus:Emit(child,'once');assert(n==1,'Once removed before nested dispatch')
 local t={};bus:On(child,'stop',function(e) table.insert(t,1);e:StopPropagation();e:PreventDefault() end)
 bus:On(child,'stop',function() table.insert(t,2) end);bus:On(group,'stop',function() error('must not bubble') end)
 assert(bus:Emit(child,'stop').DefaultPrevented and #t==2,'stopPropagation retains same-target listeners')
 bus:On(child,'immediate',function(e) e:StopImmediatePropagation() end);bus:On(child,'immediate',function() error('must not run') end);bus:Emit(child,'immediate')
 local removed=bus:On(child,'removed',function() error('removed') end);removed:Disconnect();bus:Emit(child,'removed');assert(#errors==0)
 bus:Destroy();assert(not pcall(function() bus:On(child,'x',function() end) end))
 local function make(source)
  source=table.clone(source);source.Document=Parser.parse(source.SVG);source.Runtime=true
  local session=Session.new(source.Document,function(_,states)
   local data=Viewports(Parser,Viewport,{Cases={source},States=states},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
   assert(#data.Diagnostics==0,'Runtime fixture diagnostics: '..source.Name..' '..tostring(data.Diagnostics[1] and data.Diagnostics[1].Code))
   return data.Scenes[1]
  end,{Screen=function() return {SX=2,SY=2,TX=100,TY=50} end,Report=function(e) error(e) end})
  return session,Actions.attach(session,source.Name)
 end
 local function pixel(s,x,y)
  s:Flush();local bytes=Raster.render(s.Scene,nil,480);local at=(y*480+x)*4
  return {buffer.readu8(bytes,at),buffer.readu8(bytes,at+1),buffer.readu8(bytes,at+2),buffer.readu8(bytes,at+3)}
 end
 local s,status=make(Sources.Cases[1]);local a=s:Node('a');local hits=s.Stats.HitBuilds
 assert(pixel(s,60,110)[3]==235,'normal blue')
 s:Pointer('move',60,110);assert(pixel(s,60,110)[2]==163,'hover green');assert(s:Cursor()=='pointer')
 assert(s.Stats.HitBuilds==hits,'color-only hover reuses hit geometry')
 s:Pointer('down',60,110);assert(pixel(s,60,110)[1]==245,'pressed orange');assert(s.States.focus==a)
 s:Pointer('up',60,110);assert(status():find('Klicks: 1',1,true));s:Key('Enter');assert(status():find('Klicks: 2',1,true))
 s:Pointer('move',-1,-1);assert(s.States.hover==nil and s.States.active==nil);s:Destroy()
 s,status=make(Sources.Cases[2]);s:Key('Tab');assert(s.States.focus==s:Node('b'));s:Key('Tab');assert(s.States.focus==s:Node('a'));s:Key('Tab');assert(s.States.focus==s:Node('c'));s:Key('Tab',true);assert(s.States.focus==s:Node('a'))
 local metadata=s:Metadata(s:Node('a'));assert(metadata.Label=='Aktion A' and metadata.Description=='Zweiter Tab-Stopp')
 near(s:GetBBox(s:Node('c')).Width,120,'link group bbox');near(s:GetBBox(s:Node('c')).Height,140)
 s:Focus(s:Node('c'));s:Key('Enter');assert(s.Link=='#destination')
 s.Link=nil;s:On(s:Node('c'),'click',function(e) e:PreventDefault() end);s:Key('Enter');assert(s.Link==nil,'preventDefault blocks navigation');s:Destroy()
 s,status=make(Sources.Cases[3]);s:Pointer('down',100,140);assert(status():find('capture: svg → capture: group → target: target → bubble: group',1,true));s:Pointer('up',100,140)
 s:Pointer('down',300,140);assert(status():find('Propagation gestoppt',1,true));s:Destroy()
 s,status=make(Sources.Cases[4]);s:Pointer('down',100,160);assert(s.Capture[1]==s:Node('drag'));s:Pointer('move',600,160);near(tonumber(s:Node('drag').Attributes.cx),445,'captured outside')
 s:Pointer('up',600,160);s:Pointer('move',100,160);near(tonumber(s:Node('drag').Attributes.cx),445,'released drag remains still')
 s:Pointer('down',445,160,2,'touch');s:Pointer('cancel',-1,-1,2,'touch');assert(s.Capture[2]==nil and s.Pointers[2]==nil and s.States.active==nil);s:Destroy()
 s,status=make(Sources.Cases[5]);hits=s.Stats.HitBuilds;local builds=s.Stats.Builds
 s:Activate(s:Node('button'));s:Activate(s:Node('button'));s:Activate(s:Node('button'));assert(s.Stats.Builds==builds,'mutations batched until flush')
 assert(pixel(s,100,100)[2]==163);assert(s.Stats.Builds==builds+1 and s.Stats.HitBuilds==hits,'paint flush preserves hit geometry')
 s:SetAttribute(s:Node('target'),'id','renamed');assert(s:Node('target')==nil and s:Node('renamed'));s:Destroy()
 s,status=make(Sources.Cases[6]);hits=s.Stats.HitBuilds;s:Pointer('down',240,65);s:Pointer('move',400,65);s:Pointer('up',400,65);s:Flush()
 near(tonumber(s:Node('handle').Attributes.cx),400,'drag changes attribute');assert(s.Stats.HitBuilds>hits);s:Key('ArrowLeft');near(tonumber(s:Node('handle').Attributes.cx),390)
 local b=s:GetBBox(s:Node('target'));near(b.Width,400);near(b.Height,150);s:Destroy()
 s,status=make(Sources.Cases[7]);local before=pixel(s,50,100);hits=s.Stats.HitBuilds;s:Activate(s:Node('button'));local after=pixel(s,50,100);assert(before[1]>after[1] and after[2]>before[2],'shared resource repaint');assert(s.Stats.HitBuilds==hits)
 local right=pixel(s,280,100);assert(right[2]>right[1],'second resource consumer refreshes');s:Destroy()
 s,status=make(Sources.Cases[8]);local path=s:Node('path');b=s:GetBBox(path);near(b.X,20);near(b.Y,25);near(b.Width,400);near(b.Height,150)
 local m=s:GetCTM(path);near(m.TX,20);near(m.TY,20);m=s:GetScreenCTM(path);near(m.SX,2);near(m.TX,140);near(m.TY,90)
 local len=200+2*math.sqrt(100^2+150^2);near(s:GetTotalLength(path),len)
 local p=s:GetPointAtLength(path,len/2);near(p.X,220);near(p.Y,25);near(s:GetPointAtLength(path,-1).X,20);near(s:GetPointAtLength(path,math.huge).X,420)
 s:Activate(s:Node('button'));s:Activate(s:Node('button'));near(tonumber(s:Node('dot').Attributes.cx),220);near(tonumber(s:Node('dot').Attributes.cy),25)
 s:SetAttribute(path,'d','M0 0H100');near(s:GetTotalLength(path),100,'queries flush geometry changes');s:Destroy()
 s=make({Name='runtime-clip',SVG='<svg xmlns="http://www.w3.org/2000/svg"><defs><clipPath id="clip"><rect id="cut" x="0" y="0" width="50" height="50"/></clipPath></defs><rect id="box" width="150" height="150" clip-path="url(#clip)"/></svg>'})
 s:Pointer('move',100,20);assert(s.States.hover==nil);hits=s.Stats.HitBuilds
 s:SetAttribute(s:Node('cut'),'width',120);s:Pointer('move',100,20);assert(s.States.hover==s:Node('box') and s.Stats.HitBuilds>hits,'changing clip dependency updates hit region')
 s:Flush();hits=s.Stats.HitBuilds;s.Scale=2;s:Flush();assert(s.Stats.HitBuilds==hits+1,'scale invalidates flattened hit snapshot');near(s:GetCTM(s:Node('box')).SX,2);s:Destroy()
 s=make({Name='runtime-static-states',SVG='<svg xmlns="http://www.w3.org/2000/svg"><rect id="plain" width="150" height="150" fill="#2563eb"/></svg>'})
 builds=s.Stats.Builds;s:Pointer('move',20,20);s:Flush();s:Pointer('down',20,20);s:Flush();s:Pointer('up',20,20);s:Flush();s:Pointer('move',-1,-1);s:Flush()
 assert(s.Stats.Builds==builds,'hover and active without matching CSS do not rebuild or reraster');s:Destroy()
 local data={Scenes={},Diagnostics={}}
 for _,source in Sources.Cases do local session=make(source);table.insert(data.Scenes,session.Scene);session:Destroy() end
 print('SVG S37/S38: event phases, propagation, capture/release/cancel, CSS states, focus, links, metadata, batched mutations, shared resources and geometry queries passed')
 return data
end
