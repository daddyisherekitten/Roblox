--!strict
local Matrix=require(script.Parent.Matrix)
local Viewport=require(script.Parent.Viewport)
local Length=require(script.Parent.Length)
local Image={}
-- The resolver supplies decoded immutable RGBA pixels or an independent SVG document.
function Image.measure(doc: any,node: any,context: any,report: any): any
 local a=node.Attributes
 local href=a.href or (node.Source and node.Source.ExpandedAttributes and node.Source.ExpandedAttributes['http://www.w3.org/1999/xlink\0href'])
 if not href or href=='' then return nil end
 local resource=doc.ImageResource(href,node)
 if not resource then report('image-unavailable',href);return nil end
 local iw,ih=resource.Width,resource.Height
 if resource.Root then
  local raw=resource.Root.Attributes;local box=Viewport.viewBox(raw.viewBox)
  iw=Length.resolve(raw.width or '',context,'x',true)
  ih=Length.resolve(raw.height or '',context,'y',true)
  if not iw then iw=if box and box.Height>0 and ih then ih*box.Width/box.Height elseif box then box.Width else 300 end
  if not ih then ih=if box and box.Width>0 then iw*box.Height/box.Width else 150 end
 end
 if not iw or not ih or iw<=0 or ih<=0 then return nil end
 local w=if a.width~='auto' then Length.resolve(a.width or '',context,'x',true) else nil
 local h=if a.height~='auto' then Length.resolve(a.height or '',context,'y',true) else nil
 w=w or (if h then h*iw/ih else iw);h=h or w*ih/iw
 if w<=0 or h<=0 then return nil end
 local x=Length.attribute(a.x,context,'x',0,false);local y=Length.attribute(a.y,context,'y',0,false)
 return {Resource=resource,Width=iw,Height=ih,Box={X=x,Y=y,Width=w,Height=h},Href=href}
end
function Image.build(doc: any,node: any,context: any,state: any,render: any,report: any,active: any): any
 local measured=Image.measure(doc,node,context,report);if not measured then return nil end
 local a=node.Attributes;local resource=measured.Resource;local iw,ih=measured.Width,measured.Height;local href=measured.Href
 if active[resource] then report('cyclic-image-reference',href);return nil end
 local box=measured.Box;local x,y,w,h=box.X,box.Y,box.Width,box.Height
 local fit=Viewport.resolve({viewBox=`0 0 {iw} {ih}`,preserveAspectRatio=a.preserveAspectRatio},x,y,w,h,state.Transform,state.Clip,false)
 for _,code in fit.Diagnostics do report(code,href) end
 if fit.Disabled then return nil end
 local color={Sample=Image.sample,Pixels=resource.Pixels,Width=iw,Height=ih,Inverse=Matrix.inverse(fit.Transform),Nearest=a['image-rendering']=='pixelated' or a['image-rendering']=='optimizeSpeed'}
 if resource.Root then
  active[resource]=true
  local root=doc.Content({resource.Root},nil,resource.Scope,{Width=iw,Height=ih,FontSize=16,RootFontSize=16})
  local svg=root.Children[1]
  if svg then svg.Attributes.x='0';svg.Attributes.y='0';svg.Attributes.width=tostring(iw);svg.Attributes.height=tostring(ih) end
  color.Scene=render(root,{Transform=Matrix.identity(),Clip={X=0,Y=0,Width=iw,Height=ih},UserWidth=iw,UserHeight=ih},iw,ih,nil)
  color.Prepare=Image.prepare;active[resource]=nil
 end
 return {Geometry={Kind='polygon',Points={{x,y},{x+w,y},{x+w,y+h},{x,y+h}},Closed=true},Transform=state.Transform,Clip=fit.Clip,Fill=color,StrokeWidth=0,ImageBox={X=x,Y=y,Width=w,Height=h}}
end
function Image.prepare(p: any,scale: number,check: any,work: any,raster: any): any
 if work.Patterns[p] then return work.Patterns[p] end
 local mapping=Matrix.inverse(p.Inverse)
 local factor=math.min(scale*Matrix.scale(mapping),1024/p.Width,1024/p.Height)
 local width=math.max(1,math.floor(p.Width*factor));local height=math.round(p.Height*width/p.Width)
 if height<1 or height>1024 then return {0,0,0,0} end
 work.PatternBytes+=width*height*4;assert(work.PatternBytes<=32*1024*1024,'SVG image raster budget exceeded')
 local bytes,actual=raster(p.Scene,nil,width,check,work);if not bytes then return nil end
 local copy=table.clone(p);copy.Prepare=nil;copy.Pixels=bytes;copy.PixelWidth=width;copy.PixelHeight=actual
 work.Patterns[p]=copy;return copy
end
function Image.sample(p: any,x: number,y: number): any
 x,y=Matrix.point(p.Inverse,x,y)
 if x<0 or y<0 or x>=p.Width or y>=p.Height then return {0,0,0,0} end
 local w,h=p.PixelWidth or p.Width,p.PixelHeight or p.Height
 x=x*w/p.Width-.5;y=y*h/p.Height-.5
 local function pixel(px: number,py: number): any
  local at=(math.clamp(py,0,h-1)*w+math.clamp(px,0,w-1))*4
  return {buffer.readu8(p.Pixels,at),buffer.readu8(p.Pixels,at+1),buffer.readu8(p.Pixels,at+2),buffer.readu8(p.Pixels,at+3)/255}
 end
 if p.Nearest then return pixel(math.floor(x+.5),math.floor(y+.5)) end
 local ix,iy=math.floor(x),math.floor(y);local fx,fy=x-ix,y-iy;local result={0,0,0,0}
 for dy=0,1 do for dx=0,1 do
  local v=pixel(ix+dx,iy+dy);local weight=(if dx==0 then 1-fx else fx)*(if dy==0 then 1-fy else fy)*v[4]
  for c=1,3 do result[c]+=v[c]*weight end;result[4]+=weight
 end end
 if result[4]>0 then for c=1,3 do result[c]/=result[4] end end
 return result
end
return Image
