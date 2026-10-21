--!strict
--!optimize 2
-- Paint-server compilation is separate from per-pixel sampling. No images or network calls here.
local Matrix=require(script.Parent.Matrix)
local Transform=require(script.Parent.Transform)
local Length=require(script.Parent.Length)
local Paint=require(script.Parent.Paint)
local Gradient={}
local function linear(c: number): number c/=255;return if c<=.04045 then c/12.92 else ((c+.055)/1.055)^2.4 end
local function srgb(c: number): number return 255*(if c<=.0031308 then 12.92*c else 1.055*c^(1/2.4)-.055) end
local function href(node: any): string? return node.Attributes.href or (node.ExpandedAttributes and node.ExpandedAttributes['http://www.w3.org/1999/xlink\0href']) end
local common={'gradientUnits','spreadMethod'}
local axes={x1='x',x2='x',y1='y',y2='y',cx='x',cy='y',fx='x',fy='y',r='diagonal',fr='diagonal'}
function Gradient.bind(doc: any,node: any,paint: any,box: any,context: any,t: any,report: any): any
 if not paint or not paint.URL then return paint end
 local work=doc.GradientWork or {Bindings=0,References=0,Stops=0,Diagnostics=0}
 doc.GradientWork=work
 local emit=report
 report=function(code: string,value: any) if work.Diagnostics<100 then work.Diagnostics+=1;emit(code,value) end end
 work.Bindings+=1
 if work.Bindings>4096 then report('gradient-work-limit',paint.URL);return paint.Fallback end
 local target,scope=doc.Resource(paint.URL,node)
 if not target then report('missing-gradient-target',paint.URL);return paint.Fallback end
 if target.NamespaceURI~=node.NamespaceURI or (target.Name~='linearGradient' and target.Name~='radialGradient') then report('invalid-gradient-target',paint.URL);return paint.Fallback end
 local root=target;local values={};local stops,stopScope;local active={};local depth=0
 local keys=if root.Name=='linearGradient' then {'x1','y1','x2','y2'} else {'cx','cy','r','fx','fy','fr'}
 local style=doc.Compute(root,scope,context)
 if not style then return paint.Fallback end
 local transformStyle
 while target do
  depth+=1;work.References+=1
  if work.References>8192 then report('gradient-work-limit',paint.URL);return paint.Fallback end
  if active[target] or depth>64 then report('cyclic-gradient-reference',paint.URL);return paint.Fallback end
  active[target]=true
  if target.NamespaceURI~=root.NamespaceURI or (target.Name~='linearGradient' and target.Name~='radialGradient') then report('invalid-gradient-template',paint.URL);break end
  for _,key in common do if values[key]==nil then values[key]=target.Attributes[key] end end
  if target.Name==root.Name then for _,key in keys do if values[key]==nil then values[key]=target.Attributes[key] end end end
  if not transformStyle then
   local computed=if target==root then style else doc.Compute(target,scope,context)
   if computed and computed.Specified.transform then transformStyle=computed end
  end
  if not stops then
   local children={}
   for _,child in target.Children do if child.Kind=='Element' and child.NamespaceURI==root.NamespaceURI and child.Name=='stop' then table.insert(children,child) end end
   if #children>0 then stops=children;stopScope=scope end
  end
  local url=href(target)
  if not url or url=='' then break end
  local nextTarget,nextScope=doc.Resource(url,scope)
  if not nextTarget then report('missing-gradient-template',url);break end
  target,scope=nextTarget,nextScope
 end
 local colors={};local offset=0
 for i,stop in stops or {} do
  work.Stops+=1;if work.Stops>16384 then report('gradient-work-limit',paint.URL);return paint.Fallback end
  if i>1024 then report('gradient-stop-limit',paint.URL);return paint.Fallback end
  local computed=doc.Compute(stop,stopScope,context,style)
  local v=computed.Values
  local token=Length.parse(stop.Attributes.offset or '0')
  local n=if token and (token.Unit=='' or token.Unit=='%') then token.Value/(if token.Unit=='%' then 100 else 1) else 0
  if not token or (token.Unit~='' and token.Unit~='%') then report('invalid-gradient-offset',stop.Attributes.offset) end
  offset=math.max(offset,math.clamp(n,0,1))
  local state=Paint.resolve({color=v.color,fill=v['stop-color'],['fill-opacity']=v['stop-opacity']},nil,context)
  local rgba=Paint.used(state,context)
  table.insert(colors,{Offset=offset,Color=rgba})
 end
 if #colors==0 then return nil end
 local space=style.Values['color-interpolation']
 if space=='linearRGB' then for _,stop in colors do for i=1,3 do stop.Color[i]=linear(stop.Color[i]) end end end
 local units=values.gradientUnits or 'objectBoundingBox'
 if units~='objectBoundingBox' and units~='userSpaceOnUse' then report('invalid-gradient-units',units);units='objectBoundingBox' end
 local basis=table.clone(context);basis.FontSize=style.FontSize
 local mapping=Matrix.identity()
 if units=='objectBoundingBox' then
  if box.Width<=0 or box.Height<=0 then return nil end
  basis.Width=1;basis.Height=1;basis.X=0;basis.Y=0
  mapping={SX=box.Width,SY=box.Height,TX=box.X,TY=box.Y}
 end
 local transform=Matrix.identity()
 if transformStyle then
  local declarations=Transform.declarations(transformStyle.Attributes)
  local problems;transform,problems=Transform.resolve(declarations,{X=0,Y=0,Width=basis.Width,Height=basis.Height},basis)
  for _,code in problems do report(code,paint.URL) end
 end
 local inverse=Matrix.inverse(Matrix.multiply(t,Matrix.multiply(mapping,transform)))
 if not inverse then return nil end
 local spread=values.spreadMethod or 'pad'
 if spread~='pad' and spread~='repeat' and spread~='reflect' then report('invalid-gradient-spread',spread);spread='pad' end
 local invalid=false
 local function read(key: string,default: string): number
  local raw=values[key] or default
  local n,problem=Length.resolve(raw,basis,axes[key],key=='r' or key=='fr')
  if not n or problem or math.abs(n)>1e9 then report('invalid-gradient-length',key..':'..raw);invalid=true;return 0 end
  if units=='userSpaceOnUse' and raw:match('%%%s*$') and axes[key]~='diagonal' then n+=(if axes[key]=='x' then basis.X or 0 else basis.Y or 0) end
  return n
 end
 local result={Sample=Gradient.pixel,Kind=root.Name,Inverse=inverse,Stops=colors,Spread=spread,LinearRGB=space=='linearRGB',Opacity=paint.Opacity}
 if root.Name=='linearGradient' then
  result.X=read('x1','0%');result.Y=read('y1','0%');result.DX=read('x2','100%')-result.X;result.DY=read('y2','0%')-result.Y
  result.Length2=result.DX^2+result.DY^2
 else
  result.CX=read('cx','50%');result.CY=read('cy','50%');result.R=read('r','50%')
  result.FX=if values.fx then read('fx','0') else result.CX;result.FY=if values.fy then read('fy','0') else result.CY
  result.FR=read('fr','0%');result.DX=result.CX-result.FX;result.DY=result.CY-result.FY;result.DR=result.R-result.FR
  result.A=result.DX^2+result.DY^2-result.DR^2
 end
 if invalid then return paint.Fallback end
 result.Antialias=spread~='pad' or (root.Name=='radialGradient' and result.DX^2+result.DY^2>(result.R-result.FR)^2)
 for i=2,#colors do if colors[i].Offset==colors[i-1].Offset then result.Antialias=true end end
 -- Precompute the weighted average once for collapsed repeating radial rings.
 local average={0,0,0,0};local previous=0;local old=colors[1].Color
 for _,stop in colors do
  for i=1,4 do average[i]+=(old[i]+stop.Color[i])*.5*(stop.Offset-previous) end
  previous=stop.Offset;old=stop.Color
 end
 for i=1,4 do average[i]+=old[i]*(1-previous) end
 if result.LinearRGB then for i=1,3 do average[i]=srgb(average[i]) end end
 average[4]*=paint.Opacity or 1;result.Average=average
 return result
end
function Gradient.color(g: any,t: number): any
 if g.Spread=='repeat' then t=t-math.floor(t) elseif g.Spread=='reflect' then t=t%2;if t>1 then t=2-t end else t=math.clamp(t,0,1) end
 local stops=g.Stops;local a,b=stops[1],stops[#stops]
 if t<a.Offset then b=a
 elseif t>=b.Offset then a=b
 else
  -- Upper bound selects the last stop at an equal offset (hard edge).
  local lo,hi=1,#stops
  while lo<hi do local mid=math.floor((lo+hi)/2);if stops[mid].Offset<=t then lo=mid+1 else hi=mid end end
  a,b=stops[lo-1],stops[lo]
 end
 local f=if a==b then 0 else (t-a.Offset)/(b.Offset-a.Offset)
 local color={}
 for i=1,4 do color[i]=a.Color[i]+(b.Color[i]-a.Color[i])*f end
 if g.LinearRGB then for i=1,3 do color[i]=srgb(color[i]) end end
 color[4]*=g.Opacity or 1
 return color
end
function Gradient.sample(g: any,x: number,y: number): any
 x,y=Matrix.point(g.Inverse,x,y)
 if x~=x or y~=y or math.abs(x)>1e150 or math.abs(y)>1e150 then return {0,0,0,0} end
 local value
 if g.Kind=='linearGradient' then
  if g.Length2==0 then local last=table.clone(g);last.Spread='pad';return Gradient.color(last,1) end
  value=((x-g.X)*g.DX+(y-g.Y)*g.DY)/g.Length2
 else
  if g.DX==0 and g.DY==0 and g.DR==0 then return {0,0,0,0} end
  local qx,qy=x-g.FX,y-g.FY
  local a,b,c=g.A,-2*(qx*g.DX+qy*g.DY+g.FR*g.DR),qx*qx+qy*qy-g.FR*g.FR
  local eps=1e-12*math.max(1e-300,g.DX^2+g.DY^2+g.DR^2)
  if math.abs(a)<eps then
   -- At a focal point exactly on the outer circle, the half-plane beyond
   -- the tangent has infinitely compressed repeat rings (SVG compatibility).
   if g.FR==0 and g.Spread=='repeat' and b>=-eps then return g.Average end
   if math.abs(b)<eps then return {0,0,0,0} end
   value=-c/b
   if g.FR+value*g.DR<0 then return {0,0,0,0} end
  else
   local discriminant=b*b-4*a*c
   if discriminant<0 then return {0,0,0,0} end
   local d=math.sqrt(discriminant)
   local q=-.5*(b+(if b<0 then -d else d))
   local first,second=if q==0 then 0 else q/a,if q==0 then 0 else c/q
   value=-math.huge
   if g.FR+first*g.DR>=0 then value=first end
   if g.FR+second*g.DR>=0 then value=math.max(value,second) end
   if value==-math.huge then return {0,0,0,0} end
  end
 end
 if value~=value or math.abs(value)==math.huge then return {0,0,0,0} end
 return Gradient.color(g,value)
end
-- Four subpixel samples smooth discontinuous paint independently of the shape edge.
function Gradient.pixel(g: any,x: number,y: number,step: number?): any
 if not g.Antialias or not step then return Gradient.sample(g,x,y) end
 local result={0,0,0,0}
 for _,dy in {-.25,.25} do for _,dx in {-.25,.25} do
  local c=Gradient.sample(g,x+dx*step,y+dy*step)
  for i=1,3 do result[i]+=c[i]*c[4]*.25 end
  result[4]+=c[4]*.25
 end end
 if result[4]>0 then for i=1,3 do result[i]/=result[4] end end
 return result
end
return Gradient
