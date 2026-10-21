--!strict
local WorkContext=require(script.Parent.Parent.WorkContext)
-- Nine-slice mapping for generated CSS image sources; layout remains rectangular.
local Gradient=require(script.Parent.BackgroundPixels)
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Pixels={}
function Pixels.width(value,border,basis,auto)
 if value=='auto'then return auto or border end
 return if type(value)=='table'then Length.resolve(value,basis)else (value or 0)*border
end
local function boundaries(span,start,finish)
 local factor=math.min(1,span/math.max(.000001,start+finish))
 return {0,start*factor,span-finish*factor,span}
end
local function region(at,points)
 if at<points[2]then return 1 elseif at>=points[3]then return 3 else return 2 end
end
local function coordinate(at,regionIndex,target,source,mode,tile)
 local t0,t1=target[regionIndex],target[regionIndex+1]
 local s0,s1=source[regionIndex],source[regionIndex+1]
 local size=s1-s0
 if size<=0 or t1<=t0 then return nil end
 local position=(at-t0)/(t1-t0)
 if regionIndex==2 and mode=='round'and tile and tile>0 then
  local count=math.max(1,math.floor((t1-t0)/tile+.5));position=(position*count)%1
 elseif regionIndex==2 and mode=='repeat'and tile and tile>0 then
  position=((at-(t0+t1)/2+tile/2)/tile)%1
 elseif regionIndex==2 and mode=='space'and tile and tile>0 then
  local count=math.floor((t1-t0)/tile)
  if count<1 then return nil end
  local gap=((t1-t0)-count*tile)/(count+1)
  local offset=at-t0-gap
  if offset<0 then return nil end
  local index=math.floor(offset/(tile+gap))
  if index>=count or offset-index*(tile+gap)>=tile then return nil end
  position=(offset-index*(tile+gap))/tile
 end
 return s0+position*size
end
function Pixels.render(definition,width,height,widths,style,plan)
 local slices=style.BorderImageSlice or {100,100,100,100}
 local s={};for index=1,4 do local span=if index%2==1 then height else width
  s[index]=math.min(span,if slices.Percent and slices.Percent[index]then slices[index]/100*span else slices[index])
 end
 local sx,sy={0,s[4],width-s[2],width},{0,s[1],height-s[3],height}
 local factor=math.min(1,width/math.max(.000001,widths[2]+widths[4]),height/math.max(.000001,widths[1]+widths[3]))
 local tx,ty=boundaries(width,widths[4]*factor,widths[2]*factor),boundaries(height,widths[1]*factor,widths[3]*factor)
 local sample=Gradient.sampler(width,height,definition.Gradient,style)
 local result=buffer.create(plan.Width*plan.Height*4)
 for py=0,plan.Height-1 do for px=0,plan.Width-1 do
  if px%64==0 then WorkContext.checkpoint()end
  local x,y=(px+.5)*width/plan.Width,(py+.5)*height/plan.Height
  local col,row=region(x,tx),region(y,ty)
  if col==2 and row==2 and not slices.Fill then continue end
  local mode=style.BorderImageRepeat or 'stretch';local horizontal,vertical=mode:match('^(%a+)%s+(%a+)$');horizontal=horizontal or mode;vertical=vertical or horizontal
  local xTile=if row~=2 then (sx[3]-sx[2])*(ty[row+1]-ty[row])/math.max(.000001,sy[row+1]-sy[row])else nil
  local yTile=if col~=2 then (sy[3]-sy[2])*(tx[col+1]-tx[col])/math.max(.000001,sx[col+1]-sx[col])else nil
  if col==2 and row==2 then
   xTile=(sx[3]-sx[2])*(if s[1]>0 then (ty[2]-ty[1])/s[1]elseif s[3]>0 then (ty[4]-ty[3])/s[3]else 1)
   yTile=(sy[3]-sy[2])*(if s[4]>0 then (tx[2]-tx[1])/s[4]elseif s[2]>0 then (tx[4]-tx[3])/s[2]else 1)
  end
  local sourceX=coordinate(x,col,tx,sx,horizontal,xTile)
  local sourceY=coordinate(y,row,ty,sy,vertical,yTile)
  if not sourceX or not sourceY then continue end
  local color,alpha=sample(sourceX,sourceY);local at=(py*plan.Width+px)*4
  buffer.writeu8(result,at,math.round(color.R*255));buffer.writeu8(result,at+1,math.round(color.G*255));buffer.writeu8(result,at+2,math.round(color.B*255));buffer.writeu8(result,at+3,math.round(alpha*255))
 end end
 return result
end
return Pixels
