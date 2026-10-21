--!strict
-- Retain one semantic decoration box per inline line fragment.
local BorderBox=require(script.Parent.Parent.Rendering.BorderBox)
local Geometry=require(script.Parent.BorderGeometry)
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)
local Fragments={}
local function length(value: any,width: number): number
 return if type(value)=='number' then value elseif value then Length.resolve(value,width) else 0
end
function Fragments.prepare(items: any,width: number,flowStyle: any?)
 for index,item in items do
  local owner=item.Style and item.Style.InlineFragment
  item.Fragment=owner;item.FragmentPaintLeft=0;item.FragmentPaintRight=0
  if not owner then continue end
  local style=owner.Style;local t,r,b,l=Geometry.sizes(style)
  local p=style.PaddingValues or style.Padding
  owner.Padding={length(p[1],width),length(p[2],width),length(p[3],width),length(p[4],width)}
  owner.Borders={t,r,b,l}
  local low,high=WritingMode.flowSides(flowStyle or style)
  local left,right=owner.Borders[low]+owner.Padding[low],owner.Borders[high]+owner.Padding[high]
  item.FragmentLeft=if style.Direction=='rtl'then right else left
  item.FragmentRight=if style.Direction=='rtl'then left else right
  item.FragmentFirst=index==1 or not items[index-1].Style or items[index-1].Style.InlineFragment~=owner
  item.FragmentLast=index==#items or not items[index+1].Style or items[index+1].Style.InlineFragment~=owner
 end
end
function Fragments.draw(run: any,items: any,x: number,y: number,flowPaint: boolean?)
 local groups={};local previous
 for _,item in items do
  local gapOwner=item.SpaceStyle and item.SpaceStyle.InlineFragment
  if previous and item.SpaceBefore and not item.BidiGapRect and gapOwner==previous.Owner and item.LineIndex==previous.Line then
   previous.GapEnd=math.max(previous.GapEnd or 0,item.X-(item.FragmentPaintLeft or 0))
  end
  if item.Kind=='Break' or not item.Fragment or not flowPaint and item.Gui.Visible==false
   or run.Style.MaxLines and item.LineIndex>run.Style.MaxLines then previous=nil;continue end
  local owner=item.Fragment
  if not previous or previous.Owner~=owner or previous.Line~=item.LineIndex then
   previous={Owner=owner,Line=item.LineIndex,First=item,Last=item,Top=item.Y,Bottom=item.Y+item.Height,NativeHeight=item.NativeHeight or item.Height}
   table.insert(groups,previous)
  else previous.Last=item;previous.Top=math.min(previous.Top,item.Y);previous.Bottom=math.max(previous.Bottom,item.Y+item.Height);previous.NativeHeight=math.max(previous.NativeHeight,item.NativeHeight or item.Height) end
 end
 if #groups==0 and not run.FragmentPool then return end
 run.FragmentPool=run.FragmentPool or {}
 for index,g in groups do
  local slot=run.FragmentPool[index];local s=g.Owner.Style
  if s.FontSize==0 then g.Top=g.First.LineBaseline+(s.InlineShift or 0);g.Bottom=g.Top end
  if not slot then
   local gui=run.Factory.create('Frame',run.FragmentHost,{Name='InlineFragment',BackgroundTransparency=1,ZIndex=0})
   slot={Gui=gui};run.FragmentPool[index]=slot
  end
  local p,b=g.Owner.Padding,g.Owner.Borders
  local low,high,before,after=WritingMode.flowSides(run.Style)
  local left,right=g.First.FragmentPaintLeft or 0,g.Last.FragmentPaintRight or 0
  local style=table.clone(s);style.BorderUniform=false;style.Node=nil
  style.BorderSizes=table.clone(b);style.BorderSizes[low]=if left>0 then b[low]else 0;style.BorderSizes[high]=if right>0 then b[high]else 0
  if not slot.Edges then slot.Edges=BorderBox.create(style,slot.Gui,run.Factory)end
  local width=math.max(0,math.max(g.Last.X+g.Last.Width+right,g.GapEnd or 0)-g.First.X+left)
  local top,bottom=g.Top,g.Bottom
  if WritingMode.vertical(run.Style)then top=g.First.LineBaseline-g.NativeHeight/2;bottom=top+g.NativeHeight end
  local height=bottom-top+p[before]+p[after]+b[before]+b[after]
  slot.Gui.Visible=s.Visibility~='hidden'
  local px,py;px,py,width,height=WritingMode.rect(run.Style,g.First.X-left,top-p[before]-b[before],width,height,
   run.FlowContentWidth or run.ContentWidth or 0,run.FlowInlineExtent or run.HeightBasis or 0)
  slot.LocalX,slot.LocalY=x+px,y+py
  slot.Gui.Position=UDim2.fromOffset(slot.LocalX,slot.LocalY);slot.Gui.Size=UDim2.fromOffset(width,height)
  slot.Gui.BackgroundColor3=s.Background or Color3.new(1,1,1);slot.Gui.BackgroundTransparency=if s.Background then 1-(s.BackgroundAlpha or 1) else 1
  if slot.Edges then BorderBox.arrange(slot.Edges,style,width,height)end
  slot.OwnerStyle=s;slot.PaintStyle=style;slot.Width=width;slot.Height=height;slot.Active=true
  if run.HitNodes then run.HitNodes[slot.Gui]=s.HitNode or s.Node;run.HitStyles[slot.Gui]=s end
 end
 for index=#groups+1,#run.FragmentPool do run.FragmentPool[index].Gui.Visible=false;run.FragmentPool[index].Active=false end
end
function Fragments.repaint(run: any,styles: any)
 for _,slot in run.FragmentPool or {} do
  local s=slot.OwnerStyle
  if not s or not styles[s] then continue end
  local paint=table.clone(s);paint.BorderUniform=false;paint.Node=nil
  paint.BorderSizes=slot.PaintStyle.BorderSizes
  slot.Gui.BackgroundColor3=s.Background or Color3.new(1,1,1)
  slot.Gui.BackgroundTransparency=if s.Background then 1-(s.BackgroundAlpha or 1) else 1
  BorderBox.repaint(slot.Edges,paint,slot.Gui,slot.Width,slot.Height)
  slot.PaintStyle=paint
 end
end
return Fragments
