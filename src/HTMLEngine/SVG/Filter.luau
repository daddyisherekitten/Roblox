--!strict
-- Filter descriptors; pointwise graphs avoid intermediate image allocations.
local Matrix=require(script.Parent.Matrix)
local Length=require(script.Parent.Length)
local Paint=require(script.Parent.Paint)
local Blend=require(script.Parent.Blend)
local FilterColor=require(script.Parent.FilterColor)
local FilterOps=require(script.Parent.FilterOps)
local FilterPixels=require(script.Parent.FilterPixels)
local FilterKernel=require(script.Parent.FilterKernel)
local FilterLighting=require(script.Parent.FilterLighting)
local Filter={}
local function intersect(a: any,b: any): any
 local x,y=math.max(a.X,b.X),math.max(a.Y,b.Y)
 return {X=x,Y=y,Width=math.max(0,math.min(a.X+a.Width,b.X+b.Width)-x),Height=math.max(0,math.min(a.Y+a.Height,b.Y+b.Height)-y)}
end
local function union(a: any,b: any): any
 local x,y=math.min(a.X,b.X),math.min(a.Y,b.Y)
 return {X=x,Y=y,Width=math.max(a.X+a.Width,b.X+b.Width)-x,Height=math.max(a.Y+a.Height,b.Y+b.Height)-y}
end
local function inside(r: any,x: number,y: number): boolean return x>=r.X and y>=r.Y and x<r.X+r.Width and y<r.Y+r.Height end
function Filter.build(doc: any,node: any,box: any,context: any,t: any,report: any,outputClip: any?): any
 local value=node.Attributes.filter or 'none';if value=='none' then return nil end
 local url=Paint.reference(value)
 if not url then report('unsupported-svg-filter',value);return nil end
 local target,scope=doc.Resource(url.URL,node)
 if not target or target.Name~='filter' or target.NamespaceURI~=node.NamespaceURI then report('invalid-filter-reference',value);return nil end
 local a,children,childScope={},nil,nil;local seen={}
 for depth=1,33 do
  if depth>32 or seen[target] then report('cyclic-filter-reference',value);return nil end
  seen[target]=true
  for key,v in target.Attributes do if a[key]==nil then a[key]=v end end
  if not children then
   for _,child in target.Children do
    if child.Kind=='Element' and child.NamespaceURI==node.NamespaceURI and child.Name:sub(1,2)=='fe' then children=target.Children;childScope=scope;break end
   end
  end
  local href=target.Attributes.href or target.Attributes['xlink:href']
  if not href then break end
  target,scope=doc.Resource(href,scope)
  if not target or target.Name~='filter' then report('invalid-filter-reference',href);return nil end
 end
 local units=a.filterUnits or 'objectBoundingBox';local pu=a.primitiveUnits or 'userSpaceOnUse'
 if (units~='objectBoundingBox' and units~='userSpaceOnUse') or (pu~='objectBoundingBox' and pu~='userSpaceOnUse') then report('invalid-filter-units',value);return nil end
 local result={Steps={},Inverse=Matrix.inverse(t),OutputClip=outputClip,Transform=t}
 if not result.Inverse or ((units=='objectBoundingBox' or pu=='objectBoundingBox') and (box.Width<=0 or box.Height<=0)) then return result end
 local function region(attrs: any,mode: string,defaults: any): any?
  local ctx=table.clone(context);if mode=='objectBoundingBox' then ctx.Width=1;ctx.Height=1 end
  local r={}
  for key,dst in {x='X',y='Y',width='Width',height='Height'} do
   if attrs[key]==nil then r[dst]=defaults[dst];continue end
   local horizontal=key=='x' or key=='width'
   local n,err=Length.resolve(attrs[key],ctx,if horizontal then 'x' else 'y',key=='width' or key=='height')
   if not n or err then report('invalid-filter-region',key..':'..attrs[key]);return nil end
   if mode=='objectBoundingBox' then n*=if horizontal then box.Width else box.Height;if key=='x' then n+=box.X elseif key=='y' then n+=box.Y end
   elseif key=='x' and attrs[key]:find('%%') then n+=context.X or 0 elseif key=='y' and attrs[key]:find('%%') then n+=context.Y or 0 end
   r[dst]=n
  end
  return r
 end
 result.Region=region({x=a.x or '-10%',y=a.y or '-10%',width=a.width or '120%',height=a.height or '120%'},units,{})
 if not result.Region then return nil end
 local named={};local previous=0
 local function input(name: string?): number
  if name=='SourceGraphic' then return 0 elseif name=='SourceAlpha' then return -1 end
  if name=='BackgroundImage' or name=='BackgroundAlpha' or name=='FillPaint' or name=='StrokePaint' then report('unsupported-filter-input',name);return -2 end
  if name and not named[name] then report('unknown-filter-result',name) end
  return (name and named[name]) or previous
 end
 for _,child in children or {} do
  if child.Kind~='Element' or child.NamespaceURI~=node.NamespaceURI or child.Name:sub(1,2)~='fe' then continue end
  if #result.Steps>=64 then report('filter-primitive-limit',value);return nil end
  local ca=child.Attributes;local step={Kind=child.Name,Input=input(ca['in'])}
  local computed=doc.Compute(child,childScope,context)
  step.Space=if computed.Values['color-interpolation-filters']=='sRGB' then 'sRGB' else 'linearRGB'
  if child.Name=='feColorMatrix' then
   step.Matrix=FilterColor.matrix(ca)
   if not step.Matrix then report('invalid-color-matrix',ca.values or ca.type);return nil end
  elseif child.Name=='feComponentTransfer' then
   step.Functions={}
   for _,f in child.Children do
    local channel=({feFuncR=1,feFuncG=2,feFuncB=3,feFuncA=4})[f.Name]
    if f.Kind=='Element' and f.NamespaceURI==node.NamespaceURI and channel then
     local fn=FilterColor.transfer(f.Attributes)
     if not fn then report('invalid-component-transfer',f.Name);return nil end
     step.Functions[channel]=fn
    end
   end
  elseif child.Name=='feGaussianBlur' or child.Name=='feOffset' or child.Name=='feDropShadow' then
   result.Spatial=true
   local sigma=FilterColor.numbers(ca.stdDeviation)
   if not sigma or #sigma>2 or (ca.stdDeviation~=nil and #sigma==0) or (sigma[1] or 0)<0 or (sigma[2] or 0)<0 then report('invalid-filter-deviation',ca.stdDeviation);return nil end
   local default=if child.Name=='feDropShadow' then 2 else 0
   step.SigmaX=sigma[1] or default;step.SigmaY=sigma[2] or step.SigmaX
   local dx,dy=FilterColor.numbers(ca.dx),FilterColor.numbers(ca.dy)
   if not dx or not dy or #dx>1 or #dy>1 or (ca.dx~=nil and #dx==0) or (ca.dy~=nil and #dy==0) then report('invalid-filter-offset',ca.dx or ca.dy);return nil end
   step.DX=dx[1] or default;step.DY=dy[1] or default
   local sx,sy=if pu=='objectBoundingBox' then box.Width else 1,if pu=='objectBoundingBox' then box.Height else 1
   step.SigmaX*=sx;step.SigmaY*=sy;step.DX*=sx;step.DY*=sy
   if ca.edgeMode and ca.edgeMode~='none' then report('unsupported-blur-edge-mode',ca.edgeMode);return nil end
  elseif FilterLighting.Kinds[child.Name] then
   result.Spatial=true
   if not FilterLighting.parse(step,child,computed,context,box,pu,report) then return nil end
  elseif FilterKernel.Kinds[child.Name] then
   result.Spatial=true
   local sx,sy=if pu=='objectBoundingBox' then box.Width else 1,if pu=='objectBoundingBox' then box.Height else 1
   if not FilterKernel.parse(step,ca,doc,childScope,sx,sy,report) then return nil end
   if child.Name=='feDisplacementMap' then
    step.Input2=input(ca.in2);step.MapSpace=step.Space
    step.Space=if step.Input<=0 then 'sRGB' else result.Steps[step.Input].Space
   end
  elseif child.Name=='feFlood' then
   -- Flood has no image inputs and defaults to the full filter region.
  elseif child.Name=='feComposite' then
   step.Input2=input(ca.in2);step.Operator=ca.operator or 'over';step.K={}
   if not FilterOps.Operators[step.Operator] then report('invalid-composite-operator',step.Operator);return nil end
   for i=1,4 do
    local values=FilterColor.numbers(ca['k'..i]);if not values or #values>1 or (ca['k'..i]~=nil and #values==0) then report('invalid-composite-coefficient','k'..i);return nil end
    step.K[i]=values[1] or 0
   end
  elseif child.Name=='feMerge' then
   step.Inputs={}
   for _,merge in child.Children do
    if merge.Kind=='Element' and merge.NamespaceURI==node.NamespaceURI and merge.Name=='feMergeNode' then
     if #step.Inputs>=64 then report('filter-merge-limit',value);return nil end
     table.insert(step.Inputs,input(merge.Attributes['in']))
    end
   end
  elseif child.Name=='feBlend' then
   step.Input2=input(ca.in2);step.Mode=ca.mode or 'normal'
   if not Blend.Modes[step.Mode] then report('invalid-filter-blend-mode',step.Mode);return nil end
  else report('unsupported-filter-primitive',child.Name);return nil end
  if child.Name=='feFlood' or child.Name=='feDropShadow' then
   local state=Paint.resolve({color=computed.Values.color,fill=computed.Values['flood-color'],['fill-opacity']=computed.Values['flood-opacity']},nil,context)
   local color=Paint.used(state,context)
   step.Flood=FilterColor.convert({color[1]/255,color[2]/255,color[3]/255,color[4]},'sRGB',step.Space)
  end
  local defaults=if step.Input<=0 then result.Region else result.Steps[step.Input].Region
  if step.Input2 then defaults=union(defaults,if step.Input2<=0 then result.Region else result.Steps[step.Input2].Region) end
  if step.Kind=='feFlood' or step.Kind=='feImage' or step.Kind=='feTile' or step.Kind=='feTurbulence' or (step.Kind=='feComposite' and step.Operator=='arithmetic') then defaults=result.Region end
  if step.Inputs then
   defaults=nil
   for _,index in step.Inputs do
    local r=if index<=0 then result.Region else result.Steps[index].Region
    defaults=if defaults then union(defaults,r) else r
   end
   defaults=defaults or result.Region
  end
  if step.Kind=='feOffset' then defaults={X=defaults.X+step.DX,Y=defaults.Y+step.DY,Width=defaults.Width,Height=defaults.Height} end
  local r=region(ca,pu,defaults);if not r then return nil end
  step.Region=intersect(r,result.Region)
  FilterKernel.finish(step,r,box,pu,report)
  table.insert(result.Steps,step);previous=#result.Steps
  if ca.result and ca.result~='' then named[ca.result]=previous end
 end
 return result
end
local function inOutput(clip: any,x: number,y: number): boolean
 if not clip then return true end
 if not inside(clip,x,y) then return false end
 for _,polygon in clip.Polygons or {} do
  local lo,hi=math.huge,-math.huge
  for i,a in polygon do
   local b=polygon[i%#polygon+1]
   if y>=math.min(a[2],b[2]) and y<math.max(a[2],b[2]) then
    local at=a[1]+(y-a[2])/(b[2]-a[2])*(b[1]-a[1]);lo=math.min(lo,at);hi=math.max(hi,at)
   end
  end
  if x<lo or x>=hi then return false end
 end
 return true
end
function Filter.apply(bytes: buffer,graph: any,width: number,scale: number,check: any?,work: any?): boolean
 if graph.Spatial then return FilterPixels.apply(bytes,graph,width,scale,check,work,inOutput) end
 if not graph.Region or not graph.Inverse or #graph.Steps==0 then buffer.fill(bytes,0,0);return true end
 local height=buffer.len(bytes)/(width*4);local results={};local transparent={0,0,0,0}
 for y=0,height-1 do
  if check and not check() then return false end
  for x=0,width-1 do
   local at=(y*width+x)*4;local ux,uy=Matrix.point(graph.Inverse,(x+.5)/scale,(y+.5)/scale)
   if not inside(graph.Region,ux,uy) or not inOutput(graph.OutputClip,(x+.5)/scale,(y+.5)/scale) then buffer.writeu32(bytes,at,0);continue end
   local alpha=buffer.readu8(bytes,at+3)/255
   local original=if alpha==0 then transparent else {buffer.readu8(bytes,at)/255,buffer.readu8(bytes,at+1)/255,buffer.readu8(bytes,at+2)/255,alpha}
   local function get(index: number,space: string): any
    if index==0 then return FilterColor.convert(original,'sRGB',space)
    elseif index==-1 then return {0,0,0,alpha}
    elseif index==-2 then return transparent end
    return FilterColor.convert(results[index],graph.Steps[index].Space,space)
   end
   for i,step in graph.Steps do
    if not inside(step.Region,ux,uy) then results[i]=transparent;continue end
    results[i]=FilterOps.point(step,get)
   end
   local final=FilterColor.convert(results[#graph.Steps],graph.Steps[#graph.Steps].Space,'sRGB')
   for c=1,4 do buffer.writeu8(bytes,at+c-1,math.round(math.clamp(final[c],0,1)*255)) end
  end
 end
 return true
end
return Filter
