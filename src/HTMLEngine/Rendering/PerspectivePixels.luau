--!strict
--!optimize 2
--!native
local WorkContext=require(script.Parent.Parent.WorkContext)
-- Perspective-correct raster planes, eye clipping and per-pixel alpha/depth composition.
local CanvasSurface = require(script.Parent.CanvasSurface)
local Matrix4 = require(script.Parent.Parent.CSS.Matrix4)
local BorderGeometry = require(script.Parent.Parent.Layout.BorderGeometry)
local BackgroundPixels = require(script.Parent.BackgroundPixels)
local CornerRadii = require(script.Parent.CornerRadii)
local Blend = require(script.Parent.Parent.SVG.Blend)
local CanvasBackground=require(script.Parent.CanvasBackground)
local PerspectivePixels = {}
local sourceCache=setmetatable({}, {__mode="k"})

local function rgba(color: Color3, alpha: number): string
	return string.format("rgba(%d,%d,%d,%.4f)",math.round(color.R*255),math.round(color.G*255),math.round(color.B*255),alpha)
end

local function component(value: any, axis: string, index: number): number
	local part=value and value[axis]
	return if part and part.Offset~=nil then part.Offset elseif value then value[index] or 0 else 0
end

local function sourceKey(box: any,width: number,height: number): string
 local style=CanvasBackground.usedStyle(box);local parts={tostring(width),tostring(height),tostring(style.Background),tostring(style.BackgroundAlpha),tostring(style.BorderSize),tostring(style.BorderColor),tostring(style.BorderColorAlpha),tostring(style.BorderRadius)}
 for _,side in {"Top","Right","Bottom","Left"} do for _,field in {"Width","Color","ColorAlpha","Style"} do table.insert(parts,tostring(style["Border"..side..field])) end end
 for _,corner in CornerRadii.resolve(style,width,height) or {}do table.insert(parts,tostring(corner[1])..','..tostring(corner[2]))end
 for _,image in style.BackgroundImages or {} do table.insert(parts,tostring(image));for _,stop in image.Stops or {} do table.insert(parts,tostring(stop.Color)..":"..tostring(stop.Alpha)) end end
 for _,run in box.Children or {} do for _,item in run.Items or {} do
  local itemStyle=item.Style or run.Style
  local gui=item.TextGui or item.Gui
  table.insert(parts,(item.Text or "")..":"..tostring(component(gui and gui.Position,"X",1))..","..tostring(component(gui and gui.Position,"Y",2))..":"..tostring(itemStyle.Color)..":"..tostring(itemStyle.FontSize)..":"..tostring(itemStyle.FontWeight)..":"..tostring(itemStyle.FontStyle))
 end end
 return table.concat(parts,"|")
end
local function source(box: any,width: number,height: number,plan: any): any
 local key=sourceKey(box,width,height)..":"..plan.Width..":"..plan.Height
 local cached=sourceCache[box];if cached and cached.Key==key then return cached.Surface end
 local surface=CanvasSurface.new(plan.Width,plan.Height)
 local style=CanvasBackground.usedStyle(box)
 local sx,sy=plan.Width/math.max(1,width),plan.Height/math.max(1,height)
 if style.Background then
  surface:Set("fillStyle",rgba(style.Background,style.BackgroundAlpha or 1));surface:FillRect(0,0,plan.Width,plan.Height)
 end
 for i=#(style.BackgroundImages or {}),1,-1 do
  local image=style.BackgroundImages[i]
  if image.Kind=="linear" or image.Kind=="radial" or image.Kind=="conic" then
   local pixels=BackgroundPixels.render(width,height,image,style,plan)
   surface:DrawImage({Width=plan.Width,Height=plan.Height,Pixels=pixels},0,0)
  end
 end
 local t,r,b,l=BorderGeometry.sizes(box.Style)
 for _,edge in {{"Top",0,0,width,t},{"Right",width-r,0,r,height},{"Bottom",0,height-b,width,b},{"Left",0,0,l,height}} do
  local color=box.Style["Border"..edge[1].."Color"] or box.Style.BorderColor
  local alpha=box.Style["Border"..edge[1].."ColorAlpha"] or box.Style.BorderColorAlpha or 1
  if color and edge[4]>0 and edge[5]>0 then surface:Set("fillStyle",rgba(color,alpha));surface:FillRect(edge[2]*sx,edge[3]*sy,edge[4]*sx,edge[5]*sy) end
 end
 local item=box.ImageItem
 if item and item.CanvasSurface then surface:DrawImage(item.CanvasSurface,0,0,plan.Width,plan.Height) end
 local radii=CornerRadii.resolve(box.Style,width,height)
 if not radii and (box.Style.BorderRadius or 0)>0 then
  local radius=math.min(box.Style.BorderRadius,width/2,height/2);radii={{radius,radius},{radius,radius},{radius,radius},{radius,radius}}
 end
 if radii then for y=0,plan.Height-1 do for x=0,plan.Width-1 do
  if x%64==0 then WorkContext.checkpoint()end
  local px,py=(x+.5)/sx,(y+.5)/sy
  local index=if py<height/2 then (if px<width/2 then 1 else 2)else (if px<width/2 then 4 else 3)
  local rx,ry=radii[index][1],radii[index][2]
  local cx,cy=if index==1 or index==4 then rx else width-rx,if index<=2 then ry else height-ry
  if rx>0 and ry>0 and math.abs(px-cx)>0 and math.abs(py-cy)>0
   and (if index==1 or index==4 then px<cx else px>cx)
   and (if index<=2 then py<cy else py>cy)and ((px-cx)/rx)^2+((py-cy)/ry)^2>1 then
   buffer.writeu8(surface.Pixels,(y*plan.Width+x)*4+3,0)
  end
 end end end
 for _,run in box.Children or {} do for _,word in run.Items or {} do
  if not word.Text or word.Kind=="Space" or word.Kind=="Break" then continue end
  local style=word.Style or run.Style;local gui=word.TextGui or word.Gui;if not gui then continue end
  local x,y=component(gui.Position,"X",1)*sx,component(gui.Position,"Y",2)*sy
  local size=math.max(1,(word.TextSize or style.FontSize or 16)*math.min(sx,sy))
  local weight=if (style.FontWeight or 400)>=600 then "bold " else "";local italic=if style.FontStyle=="italic" then "italic " else ""
  surface:Set("font",italic..weight..size.."px sans-serif");surface:Set("textBaseline","top")
  surface:Set("fillStyle",rgba(style.Color or Color3.new(),style.ColorAlpha or 1));surface:FillText(word.Text,x,y)
 end end
 sourceCache[box]={Key=key,Surface=surface}
 return surface
end

local function sample(sourceValue: any,x: number,y: number): (number,number,number,number)
	x,y=math.clamp(x,.5,sourceValue.Width-.5),math.clamp(y,.5,sourceValue.Height-.5)
	local ix,iy=math.floor(x-.5),math.floor(y-.5);local fx,fy=x-.5-ix,y-.5-iy
	local alpha,red,green,blue=0,0,0,0;local data=sourceValue.Pixels
	for oy=0,1 do for ox=0,1 do
		local px,py=math.min(sourceValue.Width-1,ix+ox),math.min(sourceValue.Height-1,iy+oy)
		local weight=(if ox==0 then 1-fx else fx)*(if oy==0 then 1-fy else fy);local at=(py*sourceValue.Width+px)*4
		local a=buffer.readu8(data,at+3)/255*weight;alpha+=a;red+=buffer.readu8(data,at)*a;green+=buffer.readu8(data,at+1)*a;blue+=buffer.readu8(data,at+2)*a
	end end
	if alpha<=0 then return 0,0,0,0 end
	return math.round(red/alpha),math.round(green/alpha),math.round(blue/alpha),math.round(alpha*255)
end

-- Clip in homogeneous coordinates before division, including the eye plane.
function PerspectivePixels.project(width: number,height: number,matrix: any): any
 local points={}
 for _,p in {{0,0},{width,0},{width,height},{0,height}} do
  local point=Matrix4.point(matrix,p[1],p[2]);point.U,point.V=p[1],p[2];table.insert(points,point)
 end
 local clipped={};local previous=points[#points];local near=.0001
 for _,point in points do
  local inside,wasInside=point.W>=near,previous.W>=near
  if inside~=wasInside then
   local t=(near-previous.W)/(point.W-previous.W);local cut={}
   for _,key in {"X","Y","Z","W","U","V"} do cut[key]=previous[key]+(point[key]-previous[key])*t end
   table.insert(clipped,cut)
  end
  if inside then table.insert(clipped,point) end;previous=point
 end
 local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
 for _,point in clipped do
  point.Q=1/point.W;point.X*=point.Q;point.Y*=point.Q;point.Z*=point.Q
  minX,minY=math.min(minX,point.X),math.min(minY,point.Y);maxX,maxY=math.max(maxX,point.X),math.max(maxY,point.Y)
 end
 if #clipped<3 then return {Points={},Left=0,Top=0,Width=1,Height=1} end
 -- Bounding the allocation also clips unbounded planes near the eye.
 minX,minY,maxX,maxY=math.clamp(minX,-8192,8192),math.clamp(minY,-8192,8192),math.clamp(maxX,-8192,8192),math.clamp(maxY,-8192,8192)
 local left,top=math.floor(minX)-1,math.floor(minY)-1
 return {Points=clipped,Left=left,Top=top,Width=math.max(1,math.ceil(maxX)+1-left),Height=math.max(1,math.ceil(maxY)+1-top)}
end
local function appendPlane(planes: any,box: any,matrix: any,texture: any?,width: number?,height: number?)
 if box.Style.Visibility=="hidden" or (box.Style.BackfaceVisibility=="hidden" and Matrix4.backFacing(matrix)) then return end
 width,height=width or box.OuterWidth or 0,height or box.OuterHeight or 0
 if width<=0 or height<=0 then return end
 local painted=texture~=nil or box.Style.Background~=nil or (box.Style.BorderSize or 0)>0 or box.ImageItem~=nil 
 if not painted then for _,image in box.Style.BackgroundImages or {} do if image.Kind~="none" then painted=true;break end end end
 if not painted then for _,run in box.Children or {} do if #(run.Items or {})>0 then painted=true;break end end end
 if not painted then return end
 local geometry=PerspectivePixels.project(width,height,matrix)
 if #geometry.Points>=3 then table.insert(planes,{Box=box,Matrix=matrix,Geometry=geometry,Width=width,Height=height,Texture=texture,Opacity=box.Style.Opacity or 1,BlendMode=box.Style.MixBlendMode or 'normal'}) end
end
function PerspectivePixels.bounds(planes: any): any
 local left,top,right,bottom=0,0,1,1;local first=true
 for _,plane in planes do local g=plane.Geometry
  if first then left,top,right,bottom=g.Left,g.Top,g.Left+g.Width,g.Top+g.Height;first=false
  else left,top,right,bottom=math.min(left,g.Left),math.min(top,g.Top),math.max(right,g.Left+g.Width),math.max(bottom,g.Top+g.Height) end
 end
 return {Left=left,Top=top,Width=right-left,Height=bottom-top}
end
local function rasterLayer(plane: any,bounds: any,plan: any): any
 local texture=plane.Texture or source(plane.Box,plane.Width,plane.Height,{Width=math.max(1,math.min(1024,math.ceil(plane.Width*2))),Height=math.max(1,math.min(1024,math.ceil(plane.Height*2)))})
 local layer={Pixels=buffer.create(plan.Width*plan.Height*4),Depth=buffer.create(plan.Width*plan.Height*4)}
 local points={};local sx,sy=plan.Width/bounds.Width,plan.Height/bounds.Height
 for _,p in plane.Geometry.Points do table.insert(points,{X=(p.X-bounds.Left)*sx,Y=(p.Y-bounds.Top)*sy,Z=p.Z,Q=p.Q,U=p.U/plane.Width*texture.Width,V=p.V/plane.Height*texture.Height}) end
 for i=2,#points-1 do
  local a,b,c=points[1],points[i],points[i+1]
  local area=(b.X-a.X)*(c.Y-a.Y)-(b.Y-a.Y)*(c.X-a.X);if math.abs(area)<1e-9 then continue end
  local left,right=math.max(0,math.floor(math.min(a.X,b.X,c.X))),math.min(plan.Width-1,math.ceil(math.max(a.X,b.X,c.X)))
  local top,bottom=math.max(0,math.floor(math.min(a.Y,b.Y,c.Y))),math.min(plan.Height-1,math.ceil(math.max(a.Y,b.Y,c.Y)))
  for y=top,bottom do for x=left,right do
   if x%64==0 then WorkContext.checkpoint()end
   local px,py=x+.5,y+.5
   local wb=((px-a.X)*(c.Y-a.Y)-(py-a.Y)*(c.X-a.X))/area
   local wc=((b.X-a.X)*(py-a.Y)-(b.Y-a.Y)*(px-a.X))/area;local wa=1-wb-wc
   if wa>=-1e-7 and wb>=-1e-7 and wc>=-1e-7 then
    local q=wa*a.Q+wb*b.Q+wc*c.Q
    if q<=0 then continue end
    local u=(wa*a.U*a.Q+wb*b.U*b.Q+wc*c.U*c.Q)/q
    local v=(wa*a.V*a.Q+wb*b.V*b.Q+wc*c.V*c.Q)/q
    local r,g,blue,alpha=sample(texture,u,v);local at=(y*plan.Width+x)*4
    buffer.writeu8(layer.Pixels,at,r);buffer.writeu8(layer.Pixels,at+1,g);buffer.writeu8(layer.Pixels,at+2,blue);buffer.writeu8(layer.Pixels,at+3,math.round(alpha*plane.Opacity))
    buffer.writef32(layer.Depth,at,wa*a.Z+wb*b.Z+wc*c.Z)
   end
  end end
 end
 return layer
end
local function renderScenePixels(planes: any,bounds: any,plan: any): buffer
 local layers={};for _,plane in planes do table.insert(layers,rasterLayer(plane,bounds,plan)) end
 local output=buffer.create(plan.Width*plan.Height*4);local order={}
 for at=0,plan.Width*plan.Height*4-4,4 do
  if at%1024==0 then WorkContext.checkpoint()end
  table.clear(order)
  for i,layer in layers do if buffer.readu8(layer.Pixels,at+3)>0 then table.insert(order,i) end end
  if #order==0 then continue elseif #order==1 then buffer.copy(output,at,layers[order[1]].Pixels,at,4);continue end
  -- Per-pixel depth order supports intersecting and translucent planes.
  table.sort(order,function(a,b)local da,db=buffer.readf32(layers[a].Depth,at),buffer.readf32(layers[b].Depth,at);return if math.abs(da-db)<.00001 then a<b else da<db end)
  local red,green,blue,alpha=0,0,0,0
  for _,i in order do local pixels=layers[i].Pixels;local a=buffer.readu8(pixels,at+3)/255
   local mode=planes[i].BlendMode or 'normal'
   local function over(value,backdrop)
    local mixed=if alpha>0 and mode~='normal' then Blend.channel(mode,backdrop/alpha/255,value/255)*255 else value
    return a*((1-alpha)*value+alpha*mixed)+backdrop*(1-a)
   end
   red=over(buffer.readu8(pixels,at),red);green=over(buffer.readu8(pixels,at+1),green);blue=over(buffer.readu8(pixels,at+2),blue);alpha=a+alpha*(1-a)
  end
  if alpha>0 then buffer.writeu8(output,at,math.round(red/alpha));buffer.writeu8(output,at+1,math.round(green/alpha));buffer.writeu8(output,at+2,math.round(blue/alpha));buffer.writeu8(output,at+3,math.round(alpha*255)) end
 end
 return output
end
function PerspectivePixels.renderScene(planes: any,bounds: any,plan: any): buffer
 local factor=if plan.Width*plan.Height*math.max(1,#planes)<=524288 then 2 else 1
 if factor==1 then return renderScenePixels(planes,bounds,plan) end
 local work={Width=plan.Width*factor,Height=plan.Height*factor}
 local high=renderScenePixels(planes,bounds,work);local output=buffer.create(plan.Width*plan.Height*4)
 for y=0,plan.Height-1 do for x=0,plan.Width-1 do
  if x%64==0 then WorkContext.checkpoint()end
  local red,green,blue,alpha=0,0,0,0
  for oy=0,1 do for ox=0,1 do local at=((y*2+oy)*work.Width+x*2+ox)*4;local a=buffer.readu8(high,at+3)/255;alpha+=a;red+=buffer.readu8(high,at)*a;green+=buffer.readu8(high,at+1)*a;blue+=buffer.readu8(high,at+2)*a end end
  local at=(y*plan.Width+x)*4
  if alpha>0 then buffer.writeu8(output,at,math.round(red/alpha));buffer.writeu8(output,at+1,math.round(green/alpha));buffer.writeu8(output,at+2,math.round(blue/alpha));buffer.writeu8(output,at+3,math.round(alpha/4*255)) end
 end end
 return output
end
function PerspectivePixels.scene(root: any): any
 local planes={};local function collect(node: any,parentMatrix: any,output: any,depth: number)
  if depth>64 or #output>=64 or node.Box.Style.Hidden then return end
  local matrix=Matrix4.multiply(parentMatrix,node.Matrix)
  if #node.Children>0 and not node.Preserve then
   local localPlanes={}
   appendPlane(localPlanes,node.Box,Matrix4.identity());if localPlanes[1] then localPlanes[1].Opacity=1;localPlanes[1].BlendMode='normal' end
   for _,child in node.Children do collect(child,node.Perspective or Matrix4.identity(),localPlanes,depth+1) end
   local bounds=PerspectivePixels.bounds(localPlanes)
   if node.Clip then bounds={Left=0,Top=0,Width=math.max(1,node.Box.OuterWidth),Height=math.max(1,node.Box.OuterHeight)} end
   local scale=math.min(2,512/math.max(bounds.Width,bounds.Height));local plan={Width=math.max(1,math.ceil(bounds.Width*scale)),Height=math.max(1,math.ceil(bounds.Height*scale))}
   local texture={Width=plan.Width,Height=plan.Height,Pixels=PerspectivePixels.renderScene(localPlanes,bounds,plan)}
   local before=#output
   appendPlane(output,node.Box,Matrix4.multiply(matrix,Matrix4.translate(bounds.Left,bounds.Top)),texture,bounds.Width,bounds.Height)
   if node.NativeOpacity and #output>before then output[#output].Opacity=1 end
  else
   local before=#output
   appendPlane(output,node.Box,matrix)
   if node.NativeOpacity and #output>before then output[#output].Opacity=1 end
   local childrenMatrix=Matrix4.multiply(matrix,node.Perspective or Matrix4.identity())
   for _,child in node.Children do collect(child,childrenMatrix,output,depth+1) end
  end
 end
 collect(root,Matrix4.identity(),planes,0)
 return planes,PerspectivePixels.bounds(planes)
end
function PerspectivePixels.sceneKey(node: any): string
 local parts={}
 local function visit(item: any)
  table.insert(parts,sourceKey(item.Box,item.Box.OuterWidth or 0,item.Box.OuterHeight or 0));table.insert(parts,tostring(item.Box.Style.Opacity));table.insert(parts,tostring(item.Box.Style.Visibility));table.insert(parts,tostring(item.Box.Style.Hidden));table.insert(parts,tostring(item.Box.Style.BackfaceVisibility));table.insert(parts,tostring(item.Preserve));table.insert(parts,tostring(item.Clip))
  table.insert(parts,tostring(item.Box.Style.MixBlendMode));table.insert(parts,tostring(item.Box.Style.Isolation))
  for _,n in item.Matrix do table.insert(parts,string.format("%.9g",n)) end
  for _,n in item.Perspective or {} do table.insert(parts,string.format("%.9g",n)) end
  for _,child in item.Children do visit(child) end
 end
 visit(node);return table.concat(parts,"|")
end

-- Reuse the text/background raster source for bounded two-dimensional masks.
-- The root is composited before its outer transform and native group opacity.
function PerspectivePixels.flat(box: any,compositing: boolean?): any
 local function node(item,root,depth)
  local result={Box=item,Matrix=if root then Matrix4.identity() else Matrix4.translate(item.PaintX or item.LayoutX or 0,item.PaintY or item.LayoutY or 0),Children={},Preserve=false,Clip=item.Style.Overflow=="hidden",NativeOpacity=root}
  if compositing then result.Preserve=item.Style.Isolation~='isolate' and (item.Style.MixBlendMode or 'normal')=='normal' and (item.Style.Opacity or 1)==1 and not result.Clip and not item.Style.MaskImage and not item.Style.MaskBorderSource end
  if depth<64 then for _,child in item.Children or {} do
   if child.Kind~="Words" and child.Style and not child.Style.Hidden and child.OuterWidth then table.insert(result.Children,node(child,false,depth+1)) end
  end end
  return result
 end
 return node(box,true,0)
end

-- Capture before deferred work: later style/geometry writes cannot change the
-- pixels of an already queued frame. Native GUI objects never enter its cache.
local function snapshot(node: any, seen: any): any
 local function copy(value,seen)
  if type(value)~='table'then return value end
  if seen[value]then return seen[value]end
  local result=setmetatable({},getmetatable(value));seen[value]=result
  for k,v in value do result[k]=copy(v,seen)end
  return result
 end
 local box=node.Box;local captured={Style=copy(box.Style,seen),OuterWidth=box.OuterWidth,OuterHeight=box.OuterHeight,Children={}}
 if box.ImageItem and box.ImageItem.CanvasSurface then
  local surface=box.ImageItem.CanvasSurface;local pixels=buffer.create(buffer.len(surface.Pixels));buffer.copy(pixels,0,surface.Pixels)
  captured.ImageItem={CanvasSurface={Width=surface.Width,Height=surface.Height,Pixels=pixels}}
 end
 for _,run in box.Children or {}do if run.Kind=='Words'then
  local words={Style=copy(run.Style,seen),Items={}}
  for _,word in run.Items or {}do
   local gui=word.TextGui or word.Gui
   table.insert(words.Items,{Text=word.Text,Kind=word.Kind,Style=copy(word.Style or run.Style,seen),TextSize=word.TextSize,Gui=if gui then {Position=gui.Position}else nil})
  end
  table.insert(captured.Children,words)
 end end
 local result=table.clone(node);result.Box=captured;result.Children={}
 for _,child in node.Children do table.insert(result.Children,snapshot(child,seen))end
 return result
end

function PerspectivePixels.snapshot(node: any): any
 -- Share copied owners only inside this capture, never across queued frames.
 return snapshot(node,{})
end

return PerspectivePixels
