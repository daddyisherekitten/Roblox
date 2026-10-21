--!strict
local Matrix=require(script.Parent.Matrix)
local Viewport=require(script.Parent.Viewport)
local Length=require(script.Parent.Length)
local Paint=require(script.Parent.Paint)
local MarkerPositions=require(script.Parent.MarkerPositions)
local Marker={}
function Marker.build(doc: any,node: any,shape: any,context: any,render: any,report: any,active: any): any
 local a=node.Attributes
 if (a['marker-start'] or 'none')=='none' and (a['marker-mid'] or 'none')=='none' and (a['marker-end'] or 'none')=='none' then return nil end
 local result={}
 doc.MarkerWork=doc.MarkerWork or 0
 if doc.MarkerWork>=8192 then report('marker-work-limit','8192');return result end
 for _,position in MarkerPositions.build(shape.Geometry) do
  doc.MarkerWork+=1
  if doc.MarkerWork>8192 then report('marker-work-limit','8192');break end
  local value=a['marker-'..position.Kind] or 'none'
  if value=='none' then continue end
  local reference=Paint.reference(value);if not reference then continue end
  local root,scope=doc.Resource(reference.URL,node)
  if not root or root.NamespaceURI~=node.NamespaceURI or root.Name~='marker' then report('invalid-marker-reference',reference.URL);continue end
  if active[root] then report('cyclic-marker-content',reference.URL);continue end
  local attributes=root.Attributes;local style=doc.Compute(root,scope,context)
  local basis=table.clone(context);basis.FontSize=style.FontSize
  local w,ew=Length.resolve(attributes.markerWidth or '3',basis,'x',true)
  local h,eh=Length.resolve(attributes.markerHeight or '3',basis,'y',true)
  if not w or not h or ew or eh or w>1e6 or h>1e6 then report('invalid-marker-size',reference.URL);continue end
  if w==0 or h==0 then continue end
  local view=Viewport.resolve(attributes,0,0,w,h)
  for _,issue in view.Diagnostics do report(issue,reference.URL) end
  if view.Disabled then continue end
  local refContext=table.clone(basis);refContext.Width=view.UserWidth;refContext.Height=view.UserHeight
  local function referencePoint(key: string,axis: string): number?
   local v=attributes[key] or '0';local keyword=({left='0%',top='0%',center='50%',right='100%',bottom='100%'})[v]
   v=keyword or v
   local n,issue=Length.resolve(v,refContext,axis,false)
   if not n or issue then report('invalid-marker-reference-point',key);return nil end
   return n+(if v:match('%%%s*$') then (if axis=='x' then view.UserX else view.UserY) else 0)
  end
  local x,y=referencePoint('refX','x'),referencePoint('refY','y')
  if not x or not y then continue end
  x,y=Matrix.point(view.Transform,x,y)
  local orientation=attributes.orient or '0';local angle=position.Angle
  if orientation=='auto-start-reverse' then if position.Kind=='start' then angle+=math.pi end
  elseif orientation~='auto' then
   local token=Length.parse(orientation);local factors={['']=math.pi/180,deg=math.pi/180,rad=1,grad=math.pi/200,turn=2*math.pi}
   if not token or not factors[token.Unit] then report('invalid-marker-orient',orientation);continue end
   angle=token.Value*factors[token.Unit]
  end
  local units=attributes.markerUnits or 'strokeWidth'
  if units~='strokeWidth' and units~='userSpaceOnUse' then report('invalid-marker-units',units);continue end
  if units=='strokeWidth' and shape.NonScalingStroke then report('non-scaling-marker-units-approximation',reference.URL) end
  local unit=if units=='strokeWidth' then shape.StrokeWidth else 1
  if unit==0 then continue end
  local cos,sin=math.cos(angle)*unit,math.sin(angle)*unit
  local placement=Matrix.multiply(shape.Transform,{SX=cos,KX=-sin,KY=sin,SY=cos,TX=position.X-cos*x+sin*y,TY=position.Y-sin*x-cos*y})
  local state=Viewport.resolve(attributes,0,0,w,h,placement,shape.Clip,style.Values.overflow=='visible')
  if state.Disabled then continue end
  active[root]=true
  local content=doc.Content(root.Children,style,scope,refContext)
  local scene=render(content,state,nil,nil,{Fill=shape.ContextFill or shape.Fill,Stroke=shape.ContextStroke or shape.Stroke})
  active[root]=nil
  for _,entry in scene.RenderTree do table.insert(result,entry) end
 end
 return result
end
return Marker
