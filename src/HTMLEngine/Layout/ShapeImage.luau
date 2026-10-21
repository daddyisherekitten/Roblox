--!strict
-- Keep the two outer alpha edges of each row; internal holes cannot admit a line
-- connected to text outside a left/right float.
local ShapeImage={}
function ShapeImage.alpha(rgba: buffer,width: number,height: number,check: (() -> ())?): buffer
 assert(width>0 and height>0 and buffer.len(rgba)==width*height*4,'Invalid shape image pixels')
 local alpha=buffer.create(width*height)
 for y=0,height-1 do
  if check then check() end
  for x=0,width-1 do local pixel=y*width+x;buffer.writeu8(alpha,pixel,buffer.readu8(rgba,pixel*4+3)) end
 end
 return alpha
end
function ShapeImage.rows(alpha: buffer,width: number,height: number,threshold: number,check: (() -> ())?): any
 local rows={};local limit=math.clamp(threshold,0,1)*255
 for y=0,height-1 do
  if check then check() end
  local left,right
  for x=0,width-1 do
   if buffer.readu8(alpha,y*width+x)>limit then left=left or x;right=x+1 end
  end
  rows[y+1]=if left then {left,right} else false
 end
 return {Width=width,Height=height,Rows=rows}
end
function ShapeImage.edge(float: any,top: number,bottom: number): number?
 local data=float.ImageRows;local w,h=float.ImageWidth,float.ImageHeight
 if not data or w<=0 or h<=0 then return nil end
 local margin=math.max(0,float.Margin or 0)
 local first=math.max(0,math.floor((top-float.ImageY-margin)*data.Height/h))
 local last=math.min(data.Height-1,math.ceil((bottom-float.ImageY+margin)*data.Height/h)-1)
 local selected
 for row=first,last do
  local bounds=data.Rows[row+1]
  if not bounds then continue end
  local y1,y2=float.ImageY+row*h/data.Height,float.ImageY+(row+1)*h/data.Height
  local dy=math.max(0,top-y2,y1-bottom)
  if dy>margin or (margin==0 and (y2<=top or y1>=bottom)) then continue end
  local extra=math.sqrt(math.max(0,margin*margin-dy*dy))
  local edge=if float.Side=='left' then float.ImageX+bounds[2]*w/data.Width+extra else float.ImageX+bounds[1]*w/data.Width-extra
  selected=if selected==nil then edge elseif float.Side=='left' then math.max(selected,edge) else math.min(selected,edge)
 end
 return selected
end
return ShapeImage
