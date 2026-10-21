--!strict
local WorkContext=require(script.Parent.Parent.WorkContext)
-- One centered circle, stroked about a path in the half-border-box.
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Geometry=require(script.Parent.Parent.Layout.BorderGeometry)
local Shapes={}

function Shapes.geometry(style: any,width: number,height: number): any
 local t,r,b,l=Geometry.sizes(style)
 local stroke=if style.BorderStyle=='none' then 0 else t
 local refW,refH=math.max(0,width-stroke),math.max(0,height-stroke)
 local radius=if style.BorderShape.ClosestSide then math.min(refW,refH)/2 else math.max(0,Length.resolve(style.BorderShape.Radius,math.sqrt((refW*refW+refH*refH)/2)))
 local outer=radius+stroke/2
 return {Radius=radius,Inner=math.max(0,radius-stroke/2),Outer=outer,Left=width/2-outer,Top=height/2-outer,Width=math.max(1,outer*2),Height=math.max(1,outer*2),Stroke=stroke}
end

function Shapes.render(style: any,g: any,plan: any): buffer
 local data=buffer.create(plan.Width*plan.Height*4)
 local bg=style.Background or Color3.new(0,0,0)
 local ba=if style.Background then style.BackgroundAlpha or 1 else 0
 local border=style.BorderColor or style.Color
 local a=style.BorderColorAlpha or 1
 local function byte(n)return math.clamp(math.floor(n*255+.5),0,255)end
 for y=0,plan.Height-1 do for x=0,plan.Width-1 do
  if x%64==0 then WorkContext.checkpoint()end
  local alpha,red,green,blue=0,0,0,0
  for sy=0,3 do for sx=0,3 do
   local dx=(x+(sx+.5)/4)/plan.Width*g.Width-g.Outer
   local dy=(y+(sy+.5)/4)/plan.Height*g.Height-g.Outer
   local distance=math.sqrt(dx*dx+dy*dy)
   if distance>g.Outer then continue end
   local over=if g.Stroke>0 and distance>=g.Inner then a else 0
   local ab=ba*(1-over)
   alpha+=over+ab;red+=border.R*over+bg.R*ab;green+=border.G*over+bg.G*ab;blue+=border.B*over+bg.B*ab
  end end
  local offset=(y*plan.Width+x)*4
  if alpha>0 then buffer.writeu8(data,offset,byte(red/alpha));buffer.writeu8(data,offset+1,byte(green/alpha));buffer.writeu8(data,offset+2,byte(blue/alpha))end
  buffer.writeu8(data,offset+3,byte(alpha/16))
 end end
 return data
end
return Shapes
