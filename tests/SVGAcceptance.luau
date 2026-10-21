--!strict
return function(Sources,Session,ScriptDOM,Animation,Parser,Viewport,Builder,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
 local result={}
 for index,original in Sources.Cases do
  local source=table.clone(original);source.Document=Parser.parse(source.SVG);source.Runtime=true
  assert(source.Document.Valid,source.Name)
  local session=Session.new(source.Document,function(_,states,animated)
   local data=Builder(Parser,Viewport,{Cases={source},States=states,Animated=animated},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
   assert(#data.Diagnostics==0,source.Name..': '..tostring(data.Diagnostics[1] and data.Diagnostics[1].Code)..' '..tostring(data.Diagnostics[1] and data.Diagnostics[1].Value))
   return data.Scenes[1]
  end)
  session.Animation=Animation.new(source.Document);session.Script=ScriptDOM.new(session);session.Script:Run();session:SetTime(0);session:Flush()
  assert(#session.Script.Diagnostics==0,session.Script.Diagnostics[1] and session.Script.Diagnostics[1].Value)
  local originalBytes=Raster.render(session.Scene,nil,240)
  for _,width in {240,480,960} do
   local bytes=Raster.render(session.Scene,nil,width);assert(bytes and buffer.len(bytes)==width*math.round(width*2/3)*4)
  end
  table.insert(result,{Name=source.Name,Scene=session.Scene})
  if index==1 then
   -- Inherited custom property flows from hovered use to its instantiated path.
   local function firstUse(n) if n.Name=='use' then return n end;for _,c in n.Children or {} do local found=firstUse(c);if found then return found end end end
   session.States.hover=firstUse(source.Document.Root);session.Dirty=true;session:Flush()
   assert(buffer.tostring(Raster.render(session.Scene,nil,240))~=buffer.tostring(originalBytes),'Flower use hover changes paint')
   table.insert(result,{Name='S45-flower-hover',Scene=session.Scene})
   session.States.hover=nil;session.Dirty=true;session:Flush()
   assert(buffer.tostring(Raster.render(session.Scene,nil,240))==buffer.tostring(originalBytes),'Flower hover restores exact pixels')
  elseif index==3 then
   local pixels=Raster.render(session.Scene,nil,480)
   local function alpha(x,y) return buffer.readu8(pixels,(y*480+x)*4+3) end
   assert(alpha(210,45)==0 and alpha(195,95)==0,'use user-space mask follows x/y: upper and left star arms are clipped')
   assert(alpha(220,100)>230,'Remaining star fragment samples mask near its local origin')
  elseif index==4 then
   local traveler=session:Node('traveler')
   for _,t in {0,.25,.5,.75,1} do
    session:SetTime(t);session:Flush()
    assert(math.abs(tonumber(session.Animated[traveler].cx)-(70+340*t))<.01)
    assert(#session.Animation.Diagnostics==0,session.Animation.Diagnostics[1] and session.Animation.Diagnostics[1].Code)
   end
   session:SetTime(.5);session:Activate(session:Node('action'));session:Flush()
   assert(session:Node('tone').Attributes['stop-color']=='#16a34a')
   assert(tonumber(session.Animated[traveler].cx)==240,'Script paint mutation preserves animation time')
   table.insert(result,{Name='S45-live-half-green',Scene=session.Scene})
   assert(buffer.tostring(Raster.render(session.Scene,nil,240))~=buffer.tostring(originalBytes))
   session:Focus(session:Node('action'));session:Key('Enter');session:Flush()
   assert(session:Node('tone').Attributes['stop-color']=='#2563eb','Keyboard toggles the same shared gradient')
   session:SetTime(0);session:Focus(nil);session:Flush()
   assert(buffer.tostring(Raster.render(session.Scene,nil,240))==buffer.tostring(originalBytes),'Returning color and clock restores initial pixels')
   assert(#session.Script.Diagnostics==0)
  end
  session:Destroy()
 end
 print('SVG S45: four combined scenes at 240/480/960, use hover, five animation times, JS shared paint, keyboard and exact restored pixels passed')
 return result
end
