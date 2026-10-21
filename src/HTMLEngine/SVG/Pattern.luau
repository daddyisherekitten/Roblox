--!strict
local Matrix=require(script.Parent.Matrix)
local Viewport=require(script.Parent.Viewport)
local Length=require(script.Parent.Length)
local Transform=require(script.Parent.Transform)
local Pattern={}
function Pattern.bind(doc: any,node: any,paint: any,box: any,context: any,t: any,render: any,report: any,active: any): any
 local root,scope=doc.Resource(paint.URL,node)
 if not root or root.Name~='pattern' or root.NamespaceURI~=node.NamespaceURI then report('invalid-pattern-reference',paint.URL);return paint.Fallback end
 if active[root] then report('cyclic-pattern-content',paint.URL);return paint.Fallback end
 local style=doc.Compute(root,scope,context);local target=root;local values={};local children,childScope,childStyle;local transformStyle
 local seen={};local depth=0
 while target do
  depth+=1
  if seen[target] or depth>64 then report('cyclic-pattern-reference',paint.URL);return paint.Fallback end
  seen[target]=true
  if target.Name~='pattern' or target.NamespaceURI~=root.NamespaceURI then report('invalid-pattern-template',paint.URL);break end
  for _,key in {'x','y','width','height','viewBox','preserveAspectRatio','patternUnits','patternContentUnits'} do if values[key]==nil then values[key]=target.Attributes[key] end end
  if not transformStyle then
   local computed=if target==root then style else doc.Compute(target,scope,context)
   if computed.Specified.transform then transformStyle=computed end
  end
  if not children then
   local relevant=false
   for _,child in target.Children do if child.Kind=='Element' and child.Name~='title' and child.Name~='desc' and child.Name~='metadata' then relevant=true;break end end
   if relevant then
    children=target.Children;childScope=scope
    -- Browser-compatible pattern templates keep their content owner's styles.
    -- The referencing pattern still supplies tile geometry and transforms.
    childStyle=if target==root then style else doc.Compute(target,scope,context)
   end
  end
  local url=target.Attributes.href or (target.ExpandedAttributes and target.ExpandedAttributes['http://www.w3.org/1999/xlink\0href'])
  if not url or url=='' then break end
  target,scope=doc.Resource(url,scope)
  if not target then report('missing-pattern-template',url) end
 end
 if not children then return nil end
 local units=values.patternUnits or 'objectBoundingBox';local contentUnits=values.patternContentUnits or 'userSpaceOnUse'
 if units~='objectBoundingBox' and units~='userSpaceOnUse' then report('invalid-pattern-units',units);return paint.Fallback end
 if contentUnits~='objectBoundingBox' and contentUnits~='userSpaceOnUse' then report('invalid-pattern-content-units',contentUnits);return paint.Fallback end
 if (units=='objectBoundingBox' or contentUnits=='objectBoundingBox' and not values.viewBox) and (box.Width<=0 or box.Height<=0) then return nil end
 local basis=table.clone(context);basis.FontSize=style.FontSize
 local mapping=Matrix.identity()
 if units=='objectBoundingBox' then basis.Width=1;basis.Height=1;mapping={SX=box.Width,SY=box.Height,TX=box.X,TY=box.Y} end
 local coords={};for _,key in {'x','y','width','height'} do
  local axis=if key=='x' or key=='width' then 'x' else 'y'
  local value,issue=Length.resolve(values[key] or '0',basis,axis,key=='width' or key=='height')
  if not value or issue or math.abs(value)>1e9 then report('invalid-pattern-length',key);return paint.Fallback end
  coords[key]=value
 end
 local w,h=coords.width,coords.height
 if w<=0 or h<=0 then return nil end
 local transform=Matrix.identity()
 if transformStyle then
  local issues;transform,issues=Transform.resolve(Transform.declarations(transformStyle.Attributes),{X=0,Y=0,Width=basis.Width,Height=basis.Height},basis)
  for _,issue in issues do report(issue,paint.URL) end
 end
 local global=Matrix.multiply(t,Matrix.multiply(mapping,Matrix.multiply(transform,{SX=1,SY=1,TX=coords.x,TY=coords.y})))
 local inverse=Matrix.inverse(global);if not inverse then return nil end
 local clip={X=0,Y=0,Width=w,Height=h}
 local state
 if values.viewBox then
  state=Viewport.resolve(values,0,0,w,h,nil,clip)
  for _,issue in state.Diagnostics do report(issue,paint.URL) end
  if state.Disabled then return nil end
 else
  local sx,sy=1,1
  if units~=contentUnits then
   sx=if units=='objectBoundingBox' then 1/box.Width else box.Width
   sy=if units=='objectBoundingBox' then 1/box.Height else box.Height
  end
  state={Transform={SX=sx,SY=sy,TX=0,TY=0},Clip=clip,UserWidth=if contentUnits=='objectBoundingBox' then 1 else context.Width,UserHeight=if contentUnits=='objectBoundingBox' then 1 else context.Height}
 end
 if style.Values.overflow=='visible' then report('pattern-visible-overflow-clipped',paint.URL) end
 active[root]=true
 local contentContext=table.clone(context);contentContext.Width=state.UserWidth;contentContext.Height=state.UserHeight;contentContext.FontSize=childStyle.FontSize
 local content=doc.Content(children,childStyle,childScope,contentContext)
 local scene=render(content,state,w,h,nil)
 active[root]=nil
 return {Prepare=Pattern.prepare,Scene=scene,Inverse=inverse,Mapping=global,Width=w,Height=h,Opacity=paint.Opacity}
end
function Pattern.prepare(p: any,scale: number,check: any,work: any,raster: any): any
 if work.Patterns[p] then return work.Patterns[p] end
 work.PatternDepth+=1;assert(work.PatternDepth<=12,'SVG pattern render depth exceeded')
 local density=math.min(1e6,Matrix.scale(p.Mapping)*scale*2)
 local factor=math.min(density,1024/p.Width,1024/p.Height)
 local width=math.max(1,math.floor(p.Width*factor))
 local height=math.round(p.Height*width/p.Width)
 if height>1024 or height<1 then work.PatternDepth-=1;return {0,0,0,0} end
 work.PatternBytes+=width*height*4
 assert(work.PatternBytes<=32*1024*1024,'SVG pattern cache budget exceeded')
 local bytes,actualHeight=raster(p.Scene,nil,width,check,work)
 work.PatternDepth-=1
 if not bytes then return nil end
 local result={Sample=Pattern.sample,Bytes=bytes,PixelWidth=width,PixelHeight=actualHeight,Width=p.Width,Height=p.Height,Inverse=p.Inverse,Opacity=p.Opacity}
 work.Patterns[p]=result;return result
end
function Pattern.sample(p: any,x: number,y: number): any
 x,y=Matrix.point(p.Inverse,x,y)
 if x~=x or y~=y or math.abs(x)==math.huge or math.abs(y)==math.huge then return {0,0,0,0} end
 x=(x%p.Width)/p.Width*p.PixelWidth-.5;y=(y%p.Height)/p.Height*p.PixelHeight-.5
 local ix,iy=math.floor(x),math.floor(y);local fx,fy=x-ix,y-iy;local result={0,0,0,0}
 for dy=0,1 do for dx=0,1 do
  local at=(((iy+dy)%p.PixelHeight)*p.PixelWidth+(ix+dx)%p.PixelWidth)*4
  local alpha=buffer.readu8(p.Bytes,at+3)/255*(if dx==0 then 1-fx else fx)*(if dy==0 then 1-fy else fy)
  for c=1,3 do result[c]+=buffer.readu8(p.Bytes,at+c-1)*alpha end
  result[4]+=alpha
 end end
 if result[4]>0 then for c=1,3 do result[c]/=result[4] end end
 result[4]*=p.Opacity or 1;return result
end
return Pattern
