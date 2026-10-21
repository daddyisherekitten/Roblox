--!strict
-- Float exclusions are queried for the complete vertical band of each line.
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Border=require(script.Parent.BorderGeometry)
local ShapeImage=require(script.Parent.ShapeImage)
local FloatLayout={}

function FloatLayout.independent(style: any): boolean
 local display=style.Display
 return display=="flow-root" or display=="inline-block" or display=="flex" or display=="inline-flex" or display=="grid" or display=="inline-grid"
  or style.ColumnCount~=nil or style.ColumnWidth~=nil or style.ColumnHeight~=nil
  or (style.Overflow and style.Overflow~="visible") or (style.Float and style.Float~="none")
  or style.Position=="absolute" or style.Position=="fixed" or (style.Contain and (style.Contain.Layout or style.Contain.Paint))
end

function FloatLayout.add(flow: any,box: any,side: string,x: number,y: number,width: number,height: number,containingWidth: number): any
 local s=box.Style;local m=box.LayoutMargin or s.Margin or {0,0,0,0}
 local rect={Left=x,Top=y,Right=x+width,Bottom=y+height,Side=side,Shape=s.ShapeOutside}
 local shape=s.ShapeOutside
 if shape and shape.Kind=='image' then
  rect.ImageRows=box.ShapeImageProvider and box.ShapeImageProvider(shape.Source,s.ShapeImageThreshold or 0)
  if rect.ImageRows then
   local t,r,b,l=Border.sizes(s);local p=s.Padding or {0,0,0,0}
   rect.ImageX,rect.ImageY=x+m[4]+l+p[4],y+m[1]+t+p[1]
   rect.ImageWidth,rect.ImageHeight=box.ContentWidth or width-m[4]-m[2]-l-r-p[4]-p[2],box.ContentHeight or height-m[1]-m[3]-t-b-p[1]-p[3]
   rect.Margin=if type(s.ShapeMargin)=='number' then s.ShapeMargin elseif s.ShapeMargin then Length.resolve(s.ShapeMargin,containingWidth) else 0
  else rect.Shape=nil end
  table.insert(flow.Floats,rect);return rect
 end
 if shape then
  local bx,by,bw,bh=x,y,width,height
  local reference=shape.Box or "margin-box"
  if reference~="margin-box" then
   bx,by=x+m[4],y+m[1];bw,bh=box.OuterWidth or width-m[4]-m[2],box.OuterHeight or height-m[1]-m[3]
   if reference=="padding-box" or reference=="content-box" then
    local t,r,b,l=Border.sizes(s);bx+=l;by+=t;bw-=l+r;bh-=t+b
    if reference=="content-box" then local p=s.Padding;bx+=p[4];by+=p[1];bw-=p[4]+p[2];bh-=p[1]+p[3] end
   end
  end
  bw,bh=math.max(0,bw),math.max(0,bh)
  local function coordinate(axis,span)
   if not axis then return span/2 end
   local offset=if axis.Offset then Length.resolve(axis.Offset,span) else 0
   return (axis.Anchor or 0)*span+(if axis.Anchor==1 then -offset else offset)
  end
  rect.CX=bx+coordinate(shape.Position and shape.Position.X,bw)
  rect.CY=by+coordinate(shape.Position and shape.Position.Y,bh)
  local nearX,farX=math.min(math.abs(rect.CX-bx),math.abs(bx+bw-rect.CX)),math.max(math.abs(rect.CX-bx),math.abs(bx+bw-rect.CX))
  local nearY,farY=math.min(math.abs(rect.CY-by),math.abs(by+bh-rect.CY)),math.max(math.abs(rect.CY-by),math.abs(by+bh-rect.CY))
  local function radius(value,basis,near,far)
   return if value=="closest-side" then near elseif value=="farthest-side" then far else Length.resolve(value,basis)
  end
  if shape.Kind=="circle" then
   -- Circle percentages use the normalized diagonal of the reference box.
   rect.RX=radius(shape.Radius,math.sqrt((bw*bw+bh*bh)/2),math.min(nearX,nearY),math.max(farX,farY));rect.RY=rect.RX
  else rect.RX=radius(shape.X,bw,nearX,farX);rect.RY=radius(shape.Y,bh,nearY,farY) end
  rect.Margin=if type(s.ShapeMargin)=="number" then s.ShapeMargin elseif s.ShapeMargin then Length.resolve(s.ShapeMargin,containingWidth) else 0
 end
 table.insert(flow.Floats,rect);return rect
end

local function extent(float: any,top: number,bottom: number): number?
 if bottom<=float.Top or top>=float.Bottom then return nil end
 if not float.Shape then return nil end
 local cy= float.CY
 local dy=if cy<top then top-cy elseif cy>bottom then cy-bottom else 0
 local rx,ry,margin=math.max(0,float.RX),math.max(0,float.RY),math.max(0,float.Margin)
 if dy>=ry+margin or rx<=0 or ry<=0 then return nil end
 if math.abs(rx-ry)<1e-6 then return math.sqrt(math.max(0,(rx+margin)^2-dy^2)) end
 if margin<=0 then return rx*math.sqrt(math.max(0,1-(dy/ry)^2)) end
 -- An ellipse plus shape-margin is a Minkowski sum with a circle, not an
 -- ellipse whose two radii were simply increased. Its support is concave.
 local low,high=math.max(0,dy-margin),math.min(ry,dy+margin)
 local function at(y) return rx*math.sqrt(math.max(0,1-(y/ry)^2))+math.sqrt(math.max(0,margin^2-(dy-y)^2)) end
 for _=1,32 do local a,b=low+(high-low)/3,high-(high-low)/3;if at(a)<at(b) then low=a else high=b end end
 return at((low+high)/2)
end

function FloatLayout.bounds(flow: any,x: number,y: number,width: number,height: number,rectangular: boolean?): (number,number)
 local left,right=0,width
 for _,float in flow.Floats do
  if y+height<=float.Top or y>=float.Bottom then continue end
  local edge
  if rectangular or not float.Shape then edge=if float.Side=="left" then float.Right else float.Left
  else
   if float.ImageRows then edge=ShapeImage.edge(float,y,y+height)
   else
    local half=extent(float,y,y+height)
    if half then edge=if float.Side=='left' then float.CX+half else float.CX-half end
   end
   if edge==nil then continue end
   edge=if float.Side=='left' then math.min(float.Right,edge) else math.max(float.Left,edge)
  end
  if float.Side=="left" then left=math.max(left,edge-x) else right=math.min(right,edge-x) end
 end
 return math.clamp(left,0,width),math.clamp(right,0,width)
end

function FloatLayout.clear(flow: any,y: number,side: string): number
 for _,float in flow.Floats do if side=="both" or side==float.Side then y=math.max(y,float.Bottom) end end
 return y
end

function FloatLayout.lines(flow: any,width: number): any
 return function(y: number,height: number,needed: number?): (number,number,number)
  local left,right=FloatLayout.bounds(flow,flow.X,flow.Y+y,width,height)
  if needed and needed<=width and right-left+1e-6<needed then
   local finish=y
   for _,float in flow.Floats do finish=math.max(finish,float.Bottom-flow.Y) end
   -- Find the first usable band. Bounded integer probes also handle opposite
   -- floats and shapes that narrow first before widening below their centers.
   local previous=y;local found=false
   for step=1,math.min(4096,math.ceil(finish-y)) do
    local candidate=math.min(finish,y+step)
    local a,b=FloatLayout.bounds(flow,flow.X,flow.Y+candidate,width,height)
    if b-a+1e-6>=needed then
     local low,high=previous,candidate
     for _=1,20 do local middle=(low+high)/2;local l,r=FloatLayout.bounds(flow,flow.X,flow.Y+middle,width,height);if r-l+1e-6>=needed then high=middle else low=middle end end
     y=high;left,right=FloatLayout.bounds(flow,flow.X,flow.Y+y,width,height);found=true;break
    end
    previous=candidate
   end
   if not found then y=finish;left,right=FloatLayout.bounds(flow,flow.X,flow.Y+y,width,height) end
  end
  return left,right,y
 end
end
return FloatLayout
