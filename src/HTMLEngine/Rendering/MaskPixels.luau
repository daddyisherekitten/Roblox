--!strict
local WorkContext=require(script.Parent.Parent.WorkContext)
-- Gradient masks compose alpha, never paint the apparent parent background.
local Gradients=require(script.Parent.BackgroundPixels)
local BorderGeometry=require(script.Parent.Parent.Layout.BorderGeometry)
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local BorderImages=require(script.Parent.BorderImagePixels)
local MaskPixels={}
local function list(values,index,default)
 return if values and #values>0 then values[(index-1)%#values+1] else default
end
local function rect(style,width,height,name)
 local t,r,b,l=BorderGeometry.sizes(style)
 if name=="border-box" then return {X=0,Y=0,W=width,H=height} end
 if name=="content-box" then local p=style.Padding or {0,0,0,0};t+=p[1];r+=p[2];b+=p[3];l+=p[4] end
 return {X=l,Y=t,W=math.max(0,width-l-r),H=math.max(0,height-t-b)}
end
local function coordinate(axis,start,span,size)
 local free=span-size;local offset=if axis.Offset then Length.resolve(axis.Offset,free) else 0
 return start+(axis.Anchor or 0)*free+(if axis.Anchor==1 then -offset else offset)
end
function MaskPixels.compose(source: number,destination: number,operator: string): number
 if operator=="subtract" then return source*(1-destination)
 elseif operator=="intersect" then return source*destination
 elseif operator=="exclude" then return source*(1-destination)+destination*(1-source)
 else return source+destination*(1-source) end
end
function MaskPixels.render(style: any,definition: any,width: number,height: number,plan: any,check: any?): buffer?
 if definition.BorderMask then
  local t,r,b,l=BorderGeometry.sizes(style);local borders={t,r,b,l}
  local slices=style.MaskBorderSlice;local widths={};local outset=style.MaskBorderOutset;local out={}
  for i=1,4 do out[i]=BorderImages.width(outset[i],borders[i],if i%2==1 then height else width)end
  local w,h=width+out[2]+out[4],height+out[1]+out[3]
  for i=1,4 do local span=if i%2==1 then h else w;local auto=if slices.Percent and slices.Percent[i]then slices[i]/100*span else slices[i];widths[i]=BorderImages.width(style.MaskBorderWidth[i],borders[i],span,auto)end
  local borderStyle=table.clone(style);borderStyle.BorderImageSlice=slices;borderStyle.BorderImageRepeat=style.MaskBorderRepeat
  local expanded={Width=math.max(1,math.min(512,math.ceil(w))),Height=math.max(1,math.min(512,math.ceil(h)))}
  local rgba=BorderImages.render({Gradient=definition.Layers[1]},w,h,widths,borderStyle,expanded)
  local output=buffer.create(plan.Width*plan.Height)
  for py=0,plan.Height-1 do
   if check and not check()then return nil end
   for px=0,plan.Width-1 do
   if px%64==0 then WorkContext.checkpoint()end
   local cx=(px+.5)*(plan.ExtentWidth or width)/plan.Width+(plan.OffsetX or 0)+out[4]
   local cy=(py+.5)*(plan.ExtentHeight or height)/plan.Height+(plan.OffsetY or 0)+out[1]
   if cx<0 or cy<0 or cx>=w or cy>=h then continue end
   local x=math.clamp(math.floor(cx/w*expanded.Width),0,expanded.Width-1)
   local y=math.clamp(math.floor(cy/h*expanded.Height),0,expanded.Height-1)
   local at=(y*expanded.Width+x)*4;local a=buffer.readu8(rgba,at+3)
   if style.MaskBorderMode=='luminance'then a*=(.2126*buffer.readu8(rgba,at)+.7152*buffer.readu8(rgba,at+1)+.0722*buffer.readu8(rgba,at+2))/255 end
   buffer.writeu8(output,py*plan.Width+px,math.round(a))
  end end;return output
 end
 local layers={}
 for index,gradient in definition.Layers do
  local origin=rect(style,width,height,list(style.MaskOrigins,index,"border-box"))
  local clip=rect(style,width,height,list(style.MaskClips,index,"border-box"))
  local size=list(style.MaskSizes,index,{Kind="explicit"})
  local w=if size.X then Length.resolve(size.X,origin.W) else origin.W
  local h=if size.Y then Length.resolve(size.Y,origin.H) else origin.H
  local position=list(style.MaskPositions,index,{X={Anchor=0},Y={Anchor=0}})
  local repeatMode=list(style.MaskRepeats,index,{X='repeat',Y='repeat'})
  if repeatMode.X=='round'and w>0 then w=origin.W/math.max(1,math.floor(origin.W/w+.5))end
  if repeatMode.Y=='round'and h>0 then h=origin.H/math.max(1,math.floor(origin.H/h+.5))end
  local layer={W=w,H=h,X=coordinate(position.X,origin.X,origin.W,w),Y=coordinate(position.Y,origin.Y,origin.H,h),Clip=clip,Repeat=repeatMode,Origin=origin}
  if gradient.Kind~="none" and w>0 and h>0 then
   layer.Plan={Width=math.max(1,math.min(512,math.ceil(w))),Height=math.max(1,math.min(512,math.ceil(h)))}
   layer.Pixels=Gradients.render(w,h,gradient,style,layer.Plan)
  end
  table.insert(layers,layer)
 end
 local function alpha(layer,x,y)
  local clip=layer.Clip
  if not layer.Pixels or x<clip.X or y<clip.Y or x>=clip.X+clip.W or y>=clip.Y+clip.H then return 0 end
  local function repeatAt(at,start,size,origin,span,mode)
   if mode=='space'then
    local count=math.floor(span/size)
    if count>=2 then
     local period=size+(span-count*size)/(count-1);local localAt=at-origin
     if localAt<0 or localAt>=span then return -1 end
     localAt%=period;return if localAt<size then localAt else -1
    end
    return at-start
   end
   return if mode=='no-repeat'then at-start else (at-start)%size
  end
  x=repeatAt(x,layer.X,layer.W,layer.Origin.X,layer.Origin.W,layer.Repeat.X)
  y=repeatAt(y,layer.Y,layer.H,layer.Origin.Y,layer.Origin.H,layer.Repeat.Y)
  if x<0 or y<0 or x>=layer.W or y>=layer.H then return 0 end
  local px,py=x/layer.W*layer.Plan.Width-.5,y/layer.H*layer.Plan.Height-.5
  local ix,iy=math.floor(px),math.floor(py);local fx,fy=px-ix,py-iy;local a=0
  for oy=0,1 do for ox=0,1 do
   local at=(math.clamp(iy+oy,0,layer.Plan.Height-1)*layer.Plan.Width+math.clamp(ix+ox,0,layer.Plan.Width-1))*4
   local coverage=buffer.readu8(layer.Pixels,at+3)/255
   if style.MaskMode=='luminance'then coverage*=(.2126*buffer.readu8(layer.Pixels,at)+.7152*buffer.readu8(layer.Pixels,at+1)+.0722*buffer.readu8(layer.Pixels,at+2))/255 end
   a+=coverage*(if ox==0 then 1-fx else fx)*(if oy==0 then 1-fy else fy)
  end end
  return a
 end
 local output=buffer.create(plan.Width*plan.Height)
 for y=0,plan.Height-1 do
  if check and not check()then return nil end
  for x=0,plan.Width-1 do
  if x%64==0 then WorkContext.checkpoint()end
  local px,py=(x+.5)*(plan.ExtentWidth or width)/plan.Width+(plan.OffsetX or 0),(y+.5)*(plan.ExtentHeight or height)/plan.Height+(plan.OffsetY or 0)
  local a=alpha(layers[#layers],px,py)
  for index=#layers-1,1,-1 do a=MaskPixels.compose(alpha(layers[index],px,py),a,style.MaskComposite or "add") end
  buffer.writeu8(output,y*plan.Width+x,math.round(math.clamp(a,0,1)*255))
 end end
 return output
end
function MaskPixels.apply(pixels: buffer,alpha: buffer,check: any?): buffer?
 local output=buffer.create(buffer.len(pixels));buffer.copy(output,0,pixels)
 for pixel=0,buffer.len(alpha)-1 do
  if check and pixel%2048==0 and not check()then return nil end
  local at=pixel*4+3;buffer.writeu8(output,at,math.round(buffer.readu8(pixels,at)*buffer.readu8(alpha,pixel)/255))
 end
 return output
end
return MaskPixels
