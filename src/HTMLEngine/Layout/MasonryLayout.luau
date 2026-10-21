--!strict
-- Compatibility with the earlier masonry track-alignment draft.
local Tracks=require(script.Parent.GridTracks)
local Placement=require(script.Parent.GridPlacement)
local Border=require(script.Parent.BorderGeometry)
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Masonry={}
local LayoutProbe=require(script.Parent.LayoutProbe)
function Masonry.is(s)return not s.LegacyGrid and (s.GridRows and s.GridRows.Masonry or s.GridColumns and s.GridColumns.Masonry) end
local function gap(s,i,basis)local v=(s.Gap or {0,0})[i];return if type(v)=='table' then Length.resolve(v,basis or 0)else v end
local function edges(child)
 if child.Kind=='Words' then return 0,0,{0,0,0,0}end
 local s=child.Style;local t,r,b,l=Border.sizes(s)
 return s.Padding[2]+s.Padding[4]+r+l,s.Padding[1]+s.Padding[3]+t+b,child.LayoutMargin or s.Margin
end
function Masonry.arrange(box,width,heightFor,natural,layout,alive,definiteHeight)
 local s=box.Style;local vertical=s.GridRows and s.GridRows.Masonry
 local axis=Tracks.expand(if vertical then s.GridColumns else s.GridRows,if vertical then width else definiteHeight,gap(s,if vertical then 2 else 1,if vertical then width else definiteHeight),s,s.GridAreas,not vertical,nil,box.GridViewport)
 axis.First,axis.Last=1,math.max(1,axis.Explicit)
 local items={}
 for order,child in box.FlowChildren or box.Children do
  if child.Kind~='Words' and (child.Style.Position=='absolute' or child.Style.Position=='fixed')then continue end
  local cs=child.Style
  local at,span=Placement.pair(if vertical then cs.GridColumnStart else cs.GridRowStart,if vertical then cs.GridColumnEnd else cs.GridRowEnd,axis)
  span=math.max(1,span);axis.Last=math.max(axis.Last,if at then at+span-1 else span);axis.First=math.min(axis.First,at or 1)
  table.insert(items,{Box=child,Order=cs.Order or 0,Index=order,At=at,Span=span,Column=at or 1,Columns=span,Row=at or 1,Rows=span})
 end
 Tracks.initialize(axis,if vertical then s.GridAutoColumns else s.GridAutoRows,items,not vertical)
 for _,v in items do
  local min,max
  if vertical then min=natural(v.Box,width,alive,true);max=natural(v.Box,width,alive,false)
  else min=LayoutProbe.arrange(v.Box,width,layout,alive,{});max=min end
  if not alive()then return 0,0,0 end
  if v.At then Tracks.contribute(axis,v.At,v.Span,min,max)
  else for i=axis.First,axis.Last-v.Span+1 do Tracks.contribute(axis,i,v.Span,min,max)end end
 end
 Tracks.finish(axis,if vertical then s.JustifyContent else s.AlignContent)
 table.sort(items,function(a,b)return if a.Order==b.Order then a.Index<b.Index else a.Order<b.Order end)
 local positions,lanes={},{ };for i=axis.First,axis.Last do positions[i]=0;lanes[i]={}end
 local spacing=gap(s,if vertical then 1 else 2,if vertical then definiteHeight else width)
 local used=0
 for _,v in items do
  local at,best=v.At,math.huge
  if not at then
   for i=axis.First,axis.Last-v.Span+1 do
    local candidate=0;for k=i,i+v.Span-1 do candidate=math.max(candidate,positions[k])end
    if candidate<best then at,best=i,candidate end
   end
  end
  local start=0;for k=at,at+v.Span-1 do start=math.max(start,positions[k])end
  local laneSize=axis.Ends[at+v.Span-1]-axis.Starts[at]
  local ex,ey,m=edges(v.Box);local cs=v.Box.Style
  local hint={FlexItem=true,ContentWidth=math.max(0,(if vertical then laneSize else natural(v.Box,width,alive,false))-ex-m[2]-m[4]),HeightBasis=if vertical then nil else laneSize}
  if not vertical and (cs.AlignSelf=='auto' and s.AlignItems=='stretch' or cs.AlignSelf=='stretch' or cs.AlignSelf=='normal')then hint.ContentHeight=math.max(0,laneSize-ey-m[1]-m[3])end
  local h,w,b=LayoutProbe.arrange(v.Box,if vertical then laneSize else width,layout,alive,hint)
  local ow=if v.Box.Kind=='Words' then hint.ContentWidth else v.Box.OuterWidth+m[2]+m[4]
  v.At,v.Start,v.Height,v.Width,v.Hint,v.Bottom=at,start,h,ow,hint,b
  local length=if vertical then h else ow
  used=math.max(used,start+length)
  for k=at,at+v.Span-1 do positions[k]=start+length+spacing;table.insert(lanes[k],v)end
 end
 local height=if vertical then heightFor(used)else heightFor(axis.Used)
 local extent=if vertical then height else width
 local values=if vertical then s.AlignTracks else s.JustifyTracks
 local placed={};local bt,_,_,bl=Border.sizes(s);local left,top=bl+s.Padding[4],box.ContentTop or bt+s.Padding[1]
 local right,bottom=width,height
 for lane=axis.First,axis.Last do
  local list=lanes[lane];local mode=(values or {'normal'})[math.min(lane-axis.First+1,#(values or {'normal'}))]
  local free=extent-math.max(0,positions[lane]-(if #list>0 then spacing else 0));local offset,extra=0,0
  if mode=='end'then offset=free elseif mode=='center'then offset=free/2
  elseif free>0 and mode=='space-between' and #list>1 then extra=free/(#list-1)
  elseif free>0 and mode=='space-around' and #list>0 then extra=free/#list;offset=extra/2
  elseif free>0 and mode=='space-evenly' then extra=free/(#list+1);offset=extra end
  local stretch=0
  if free>0 and mode=='stretch' then
   local n=0;for _,v in list do if not v.Box.Style[if vertical then 'Height'else 'Width']then n+=1 end end
   stretch=if n>0 then free/n else 0
  end
  local stretched=0
  for i,v in list do
   if placed[v]then continue end;placed[v]=true
   local child,cs=v.Box,v.Box.Style;local ex,ey,m=edges(child)
   local at=v.Start+offset+(i-1)*extra+stretched
   local hint=table.clone(v.Hint)
   if stretch>0 and not cs[if vertical then 'Height'else 'Width']then
    if vertical then hint.ContentHeight=math.max(0,v.Height+stretch-ey-m[1]-m[3])
    else hint.ContentWidth=math.max(0,v.Width+stretch-ex-m[2]-m[4])end
    LayoutProbe.arrange(child,if vertical then axis.Ends[v.At+v.Span-1]-axis.Starts[v.At]else width,layout,alive,hint)
    stretched+=if vertical then child.OuterHeight+m[1]+m[3]-v.Height else child.OuterWidth+m[2]+m[4]-v.Width
   end
   local x,y=if vertical then axis.Starts[v.At]else at,if vertical then at else axis.Starts[v.At]
   if s.Direction=='rtl'then x=width-x-(if child.Kind=='Words' then v.Width else child.OuterWidth+m[2]+m[4])end
   if child.Kind=='Words'then layout(child,hint.ContentWidth,left+x,top+y,alive,true,hint)
   else child.LayoutX,child.LayoutY=left+x+m[4],top+y+m[1];child.Gui.Position=UDim2.fromOffset(child.LayoutX,child.LayoutY)end
   right=math.max(right,x+(if child.Kind=='Words'then v.Width else child.OuterWidth+m[2]+m[4]));bottom=math.max(bottom,y+(if child.Kind=='Words'then v.Height else child.OuterHeight+m[1]+m[3]))
  end
 end
 box.MasonryLayout={Axis=axis,Items=items,Lanes=lanes,Vertical=vertical};box.GridLayout=nil
 return height,right,bottom
end
return Masonry
