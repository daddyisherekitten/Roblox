--!strict
return function(DOM,Session,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Sources,Text)
 local result={Scenes={}}
 for index,original in Sources.Cases do
  local source=table.clone(original);source.Document=Parser.parse(source.SVG);source.Runtime=true;local data
  local s=Session.new(source.Document,function(_,states)
   data=Viewports(Parser,Viewport,{Cases={source},States=states},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
   return data.Scenes[1]
  end)
  s.Script=DOM.new(s);s.Script:Run();s:Flush();assert(#s.Script.Diagnostics==0,s.Script.Diagnostics[1] and s.Script.Diagnostics[1].Value)
  if index==1 then
   local c=s:Node('host').Children[1];assert(c.Name=='circle' and c.Attributes.r=='35')
   s:Activate(s:Node('action'));s:Flush();assert(c.Attributes.r=='43' and c.Attributes.fill=='#16a34a')
   assert(s:Node('count').Children[1].Text=='1')
  elseif index==2 then
   s:Activate(s:Node('circle1'));s:Activate(s:Node('circle1'));s:Activate(s:Node('circle3'));s:Flush()
   assert(s:Node('circle0').Attributes.r=='28' and s:Node('circle1').Attributes.r=='38' and s:Node('circle3').Attributes.r=='33')
  elseif index==3 then
   s:Activate(s:Node('action'));s:Flush();assert(s:Node('dot')==nil and s:Node('status').Children[1].Text=='Entfernt')
   s:Focus(s:Node('action'));s:Key('Enter');s:Flush();assert(s:Node('dot') and s:Node('status').Children[1].Text=='Sichtbar')
  elseif index==4 then
   s:Activate(s:Node('action'));s:Flush();assert(s:Node('stop').Attributes['stop-color']=='#16a34a')
   s:Activate(s:Node('action'));s:Flush();assert(s:Node('stop').Attributes['stop-color']=='#2563eb')
  elseif index==8 then
   assert(#data.Diagnostics==1 and data.Diagnostics[1].Code=='missing-use-target')
   s:Focus(s:Node('known'));local meta=s:Metadata(s:Node('known'));assert(meta.Label=='Vorhandenes Symbol' and meta.Description=='Gruenes Dreieck aus einer lokalen Definition')
  end
  if index~=8 then assert(#data.Diagnostics==0,source.Name..': '..tostring(data.Diagnostics[1] and data.Diagnostics[1].Code)) end
  assert(#s.Script.Diagnostics==0,s.Script.Diagnostics[1] and s.Script.Diagnostics[1].Value)
  table.insert(result.Scenes,s.Scene);s:Destroy()
 end
 print('SVG S41/S42 scenes: identical inline scripts, closure isolation, keyboard reattachment, shared gradient mutation, native view setup and expected missing-resource diagnostic passed')
 return result
end
