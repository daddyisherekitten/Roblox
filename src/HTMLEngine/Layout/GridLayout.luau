--!strict
local Tracks=require(script.Parent.GridTracks)
local Placement=require(script.Parent.GridPlacement)
local Border=require(script.Parent.BorderGeometry)
local BoxSpacing=require(script.Parent.BoxSpacing)
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local BoxAlignment=require(script.Parent.BoxAlignment)
local Grid={}
local Masonry=require(script.Parent.MasonryLayout)
local DirtyLayout=require(script.Parent.DirtyLayout)
local LayoutProbe=require(script.Parent.LayoutProbe)
function Grid.is(s: any): boolean return s.Display=='grid' or s.Display=='inline-grid' end
local function gap(s,index,size)
	-- Native ruby rows overlap only a small part of their font boxes. A larger
	-- overlap makes the annotation touch the base glyphs at display sizes.
	if index==1 and s.Display=='inline-grid' and s.RubyRowOverlap and not s.GridGapSpecified then
		return -(s.FontSize or 16)*s.RubyRowOverlap
	end
 local v=(s.Gap or {0,0})[index];return math.max(0,if type(v)=='table'then LengthExpression.resolve(v,size or 0)else v)
end
local function axes(box,width,height)
 local s=box.Style;local vp=box.GridViewport
 local columnGap=gap(s,2,width)
 local columnSpec,rowSpec=s.GridColumns,s.GridRows
 if s.LegacyGrid then columnSpec,rowSpec=s.LegacyGridColumns,s.LegacyGridRows end
 local cols=Tracks.expand(columnSpec,width,columnGap,s,s.GridAreas,false,box.SubgridColumns,vp)
 local rows=Tracks.expand(rowSpec,height,gap(s,1,height),s,s.GridAreas,true,box.SubgridRows,vp)
 local items=Placement.build(box,cols,rows)
 Tracks.initialize(cols,s.GridAutoColumns,items,false);Tracks.initialize(rows,s.GridAutoRows,items,true)
 return cols,rows,items
end
local function edges(child)
 if child.Kind=='Words' then return 0,0,{0,0,0,0} end
 local s=child.Style;local t,r,b,l=Border.sizes(s)
 return s.Padding[2]+s.Padding[4]+r+l,s.Padding[1]+s.Padding[3]+t+b,child.LayoutMargin or s.Margin
end
local function replacedMinimum(child,minimum)
 if child.Kind~='BlockImage' then return minimum end
 local s,item=child.Style,child.ImageItem
 if item.Control and item.Control.Type~='image' or s.MinWidth and s.MinWidth.Intrinsic then return minimum end
 -- Grid contributions cap compressible replaced elements by their preferred
 -- or maximum width. Cyclic percentages use zero here, not the whole grid or
 -- a min-height transferred through the natural image ratio (Grid 2, 6.6).
 local cap
 for _,value in {s.Width,s.MaxWidth}do
  if value and value.Percent then
   local resolved=math.max(0,LengthExpression.resolve(value,0))
   cap=if cap then math.min(cap,resolved)else resolved
  end
 end
 if cap==nil then return minimum end
 local edge,_,margin=edges(child)
 local function outer(value)
  return (if s.BoxSizing=='border-box'then math.max(edge,value)else edge+value)+margin[2]+margin[4]
 end
 local explicit=if s.MinWidth then math.max(0,LengthExpression.resolve(s.MinWidth,0))else 0
 return math.max(outer(explicit),math.min(minimum,outer(cap)))
end
local function contributions(cols,items,width,natural,alive,minimumOnly)
 local sorted=table.clone(items);table.sort(sorted,function(a,b) return a.Columns<b.Columns end)
 for _,v in sorted do
  local min=natural(v.Box,width or 0,alive,true)
  local child=v.Box
  min=replacedMinimum(child,min)
  if child.Kind~='Words' and not child.Style.Width then
   local s=child.Style
   -- A grid item's automatic minimum is allowed to shrink when the author
   -- explicitly sets min-width or when horizontal overflow is not visible.
   -- Keeping the intrinsic nowrap width here made an fr track exceed its grid.
   if s.MinWidth or (s.OverflowX and s.OverflowX~='visible') then
    local edge,_,margin=edges(child)
    local minimum=edge+margin[2]+margin[4]
    if s.MinWidth and not s.MinWidth.Intrinsic then
     local specified=math.max(0,LengthExpression.resolve(s.MinWidth,width or 0))
     minimum=(if s.BoxSizing=='border-box' then math.max(edge,specified) else edge+specified)+margin[2]+margin[4]
    end
    if not(s.MinWidth and s.MinWidth.Intrinsic)then min=minimum end
   end
  end
  local max=if minimumOnly then min else natural(v.Box,width or 0,alive,false)
  if not alive() then return end
  v.MinWidth,v.MaxWidth=min,max
  Tracks.contribute(cols,v.Column,v.Columns,min,max)
 end
end
function Grid.natural(box,available,natural,alive,minimum)
 local cols,_,items=axes(box,nil,nil)
 contributions(cols,items,available,natural,alive,minimum)
 Tracks.finish(cols,'start')
 return cols.Used
end
local function align(mode,free,before,after)
 if before or after then return if before then math.max(0,free)/(if after then 2 else 1) else 0 end
 if mode=='center' then return free/2 end
 if mode=='end' or mode=='self-end' or mode=='flex-end' or mode=='right' then return free end
 return 0
end
local function physicalAlign(mode,free,before,after)
 -- Grid2 11.2: overflowing auto margins resolve to zero, then box alignment
 -- applies. This deliberately differs from Flex's cross-auto overflow rule.
 if free>0 and(before or after)then return if before then free/(if after then 2 else 1)else 0 end
 return BoxAlignment.offset(mode,free)
end
local function size(axis,start,count) return axis.Ends[start+count-1]-axis.Starts[start] end
local function selfAlign(s,parent,field)
 local value=s[field..'Self'];if not value or value=='auto' then value=parent[field..'Items'] end
 return value or 'normal'
end
local function rowContribution(list,start,count,minimum,maximum)
 table.insert(list,{Start=start,Count=count,Minimum=minimum,Maximum=maximum})
end
local function subgridRows(list,item,probe,before,after,parentGap)
 local difference=(probe.RowGap-parentGap)/2
 local firstOccupied,lastOccupied=item.Rows+1,0
 for _,entry in probe.Rows do
  firstOccupied=math.min(firstOccupied,entry.Start)
  lastOccupied=math.max(lastOccupied,entry.Start+entry.Count-1)
 end
 for _,entry in probe.Rows do
  local ending=entry.Start+entry.Count-1
  local first=if entry.Start==1 then before else difference
  local last=if ending==item.Rows then after else difference
  rowContribution(list,item.Row+entry.Start-1,entry.Count,entry.Minimum+first+last,entry.Maximum+first+last)
  -- Edges must also fit when no item touches them directly (Grid 2 §9).
  if before>0 and entry.Start==firstOccupied and entry.Start>1 then
   rowContribution(list,item.Row,ending,entry.Minimum+before+last,entry.Maximum+before+last)
  end
  if after>0 and ending==lastOccupied and ending<item.Rows then
   rowContribution(list,item.Row+entry.Start-1,item.Rows-entry.Start+1,entry.Minimum+first+after,entry.Maximum+first+after)
  end
 end
 if #probe.Rows==0 then
  local empty=before+after+parentGap*(item.Rows-1)
  rowContribution(list,item.Row,item.Rows,empty,empty)
 else
  -- Empty outer tracks still accommodate the corresponding box edge.
  if firstOccupied>1 then rowContribution(list,item.Row,1,before,before)end
  if lastOccupied<item.Rows then rowContribution(list,item.Row+item.Rows-1,1,after,after)end
 end
end
function Grid.arrange(box,width,heightFor,natural,layout,alive,definiteHeight)
 if Masonry.is(box.Style)then return Masonry.arrange(box,width,heightFor,natural,layout,alive,definiteHeight)end
 local s=box.Style
 local cols,rows,items=axes(box,width,definiteHeight)
 contributions(cols,items,width,natural,alive)
 local justify=s.JustifyContent or 'normal'
 local justifyPosition,justifySafety=BoxAlignment.split(justify)
 if not s.GridJustifySpecified and justify=='flex-start' then justify='normal' end
 local physicalAlignment=BoxAlignment.horizontalContainer(s)
 if physicalAlignment and(justifyPosition=='left'or justifyPosition=='right')then
  local atEnd=BoxAlignment.resolve(justifyPosition,true,s,s)=='end'
  local position=if atEnd~=(s.Direction=='rtl')then 'end'else 'start'
  justify=if justifySafety then justifySafety..' '..position else position
 end
 Tracks.finish(cols,justify)
 local sorted=table.clone(items);table.sort(sorted,function(a,b) return a.Rows<b.Rows end)
 local baselines={};local rowContributions={}
 for _,v in sorted do
  if not alive() then return 0,0,0 end
  local child=v.Box;local cs=if child.Kind=='Words' then {} else child.Style
  local w=size(cols,v.Column,v.Columns)
  -- Intrinsic probes can leave spacing resolved against the containing grid,
  -- while cached probes leave the previous track's pixels untouched. Resolve
  -- the actual grid area before capturing edges used by stretch sizing.
  if child.Kind~='Words'then BoxSpacing.resolve(cs,w)end
  local ex,ey,m=edges(child);v.Margin=m;v.EdgesY=ey
  local j=selfAlign(cs,s,'Justify');local a=selfAlign(cs,s,'Align');v.Justify,v.Align=j,a
  local auto=cs.MarginAuto or {};v.Auto=auto
  local stretch=(j=='stretch' or BoxAlignment.split(j)=='normal') and not cs.AspectRatio and not auto[2] and not auto[4]
  local wanted=if stretch then w else math.min(v.MaxWidth,math.max(v.MinWidth,w))
  local hint={FlexItem=true,ContentWidth=math.max(0,wanted-ex-m[2]-m[4]),HeightBasis=nil,SpacingWidth=w}
  -- Replaced-element hints set used dimensions directly. Authored length/
  -- percentage axes instead resolve against this Grid area. Intrinsic keyword
  -- axes retain the existing contribution-based sizing path.
  if child.Kind=='BlockImage' and cs.Width and not cs.Width.Intrinsic then hint.ContentWidth=nil end
  if child.Kind~='Words' then
   child.HeightBasis=nil
   local bt,br,bb,bl=Border.sizes(cs)
   child.SubgridColumns=if Grid.is(cs)and not cs.LegacyGrid and cs.GridColumns and cs.GridColumns.Subgrid
    then Tracks.slice(cols,v.Column,v.Columns,bl+cs.Padding[4]+m[4],br+cs.Padding[2]+m[2])else nil
   child.SubgridRows=if Grid.is(cs)and not cs.LegacyGrid and cs.GridRows and cs.GridRows.Subgrid
    then Tracks.slice(rows,v.Row,v.Rows,bt+cs.Padding[1]+m[1],bb+cs.Padding[3]+m[3],true)else nil
   child.GridViewport=box.GridViewport
  end
  v.Hint=hint
  local probe=DirtyLayout.measure(child,'grid-height',w,hint,function()
   local h,_,bottom=LayoutProbe.arrange(child,w,layout,alive,hint)
   return {Height=h,Bottom=bottom,Width=if child.Kind=='Words' then hint.ContentWidth else child.OuterWidth+m[2]+m[4],
    Baseline=m[1]+(child.FirstBaseline or child.OuterHeight or h),
    Rows=if child.SubgridRows then child.GridRowContributions else nil,
    RowGap=if child.SubgridRows then child.GridLayout.Rows.Gap else nil}
  end,alive)
  local h=probe.Height
  v.Width=probe.Width
  v.Height=h;v.Bottom=probe.Bottom
  local minHeight=h
  if a=='baseline' then
   v.Baseline=probe.Baseline
   local line=baselines[v.Row] or {Before=0,After=0};baselines[v.Row]=line
   line.Before=math.max(line.Before,v.Baseline);line.After=math.max(line.After,h-v.Baseline)
  end
  if probe.Rows then
   subgridRows(rowContributions,v,probe,child.SubgridRows.Before,child.SubgridRows.After,rows.Gap)
  else rowContribution(rowContributions,v.Row,v.Rows,minHeight,minHeight)end
 end
 for row,b in baselines do rowContribution(rowContributions,row,1,b.Before+b.After,b.Before+b.After)end
 -- The descendants size their corresponding parent tracks; the subgrid's
 -- previously stretched outer height is never an intrinsic contribution.
 table.sort(rowContributions,function(a,b)return a.Count<b.Count end)
 for _,entry in rowContributions do Tracks.contribute(rows,entry.Start,entry.Count,entry.Minimum,entry.Maximum)end
 box.GridRowContributions=rowContributions
 local contentMode=s.AlignContent or 'stretch'
 Tracks.finish(rows,contentMode)
 local height=heightFor(rows.Used)
 -- Cyclic grid gaps contribute only their fixed term to intrinsic height,
 -- then resolve against that used content height for final track placement.
 -- The resulting overflow must not feed back into the container's height.
 local rowGap=(s.Gap or {0,0})[1]
 if definiteHeight==nil and not rows.Subgrid and type(rowGap)=='table'and rowGap.Percent then
  rows.Gap=gap(s,1,height);rows.Size=height;Tracks.finish(rows,contentMode)
 end
 if height~=rows.Size then rows.Size=height;Tracks.finish(rows,contentMode) end
 local bt,_,_,bl=Border.sizes(s);local left,top=bl+s.Padding[4]+(box.ScrollLeadingX or 0),box.ContentTop or bt+s.Padding[1]
 local right,bottom=width,height
 for index,v in items do
  local child,cs=v.Box,v.Box.Style;local m,auto=v.Margin,v.Auto
  local w,h=size(cols,v.Column,v.Columns),size(rows,v.Row,v.Rows)
  local hint=v.Hint;hint.HeightBasis=h
  if child.Kind~='Words' then
   child.HeightBasis=h
   local bt,_,bb=Border.sizes(cs)
   child.SubgridRows=if Grid.is(cs)and not cs.LegacyGrid and cs.GridRows and cs.GridRows.Subgrid
    then Tracks.slice(rows,v.Row,v.Rows,bt+cs.Padding[1]+m[1],bb+cs.Padding[3]+m[3])else nil
   local alignPosition=BoxAlignment.split(v.Align)
   if (alignPosition=='normal' or alignPosition=='stretch') and not cs.AspectRatio and not auto[1] and not auto[3]
    and(child.Kind~='BlockImage' or not cs.Height or cs.Height.Intrinsic)then hint.ContentHeight=math.max(0,h-v.EdgesY-m[1]-m[3]) end
  end
  local ch,cw,cb=LayoutProbe.arrange(child,w,layout,alive,hint)
  if not alive() then return 0,0,0 end
  local ow=if child.Kind=='Words' then hint.ContentWidth else child.OuterWidth+m[2]+m[4]
  local x,y
  if physicalAlignment then
   -- Project the grid area once, then position the item in physical space.
   -- Mirroring its already-resolved self/left/right edge again is incorrect.
   local areaX=if s.Direction=='rtl'then width-cols.Starts[v.Column]-w else cols.Starts[v.Column]
   x=areaX+physicalAlign(BoxAlignment.resolve(v.Justify,true,s,cs,nil,w-ow),w-ow,auto[4],auto[2])
   y=rows.Starts[v.Row]+physicalAlign(BoxAlignment.resolve(v.Align,false,s,cs,nil,h-ch),h-ch,auto[1],auto[3])
  else
   -- Vertical owner track/axis sizing is outside this position-only slice.
   x=cols.Starts[v.Column]+align(v.Justify,w-ow,auto[4],auto[2])
   y=rows.Starts[v.Row]+align(v.Align,h-ch,auto[1],auto[3])
   if s.Direction=='rtl'then x=width-x-ow end
  end
  if v.Align=='baseline' and v.Baseline and not auto[1] and not auto[3] then y=rows.Starts[v.Row]+baselines[v.Row].Before-v.Baseline end
  if child.Kind=='Words' then layout(child,w,left+x,top+y,alive,true,hint)
  else
   local moved=child.LayoutX~=left+x+m[4] or child.LayoutY~=top+y+m[1]
   child.LayoutX,child.LayoutY=left+x+m[4],top+y+m[1]
   child.PaintX,child.PaintY=child.LayoutX,child.LayoutY
   if moved and not child.OpacityGroup then child.TransformBaseX,child.TransformBaseY=child.LayoutX,child.LayoutY end
   local position=UDim2.fromOffset(child.LayoutX,child.LayoutY)
   if child.Gui.Position~=position then child.Gui.Position=position end
   if child.Gui.ZIndex~=index then child.Gui.ZIndex=index end
  end
  right=math.max(right,x+cw);bottom=math.max(bottom,y+cb)
  if box.FirstBaseline==nil then box.FirstBaseline=top+y+m[1]+(child.FirstBaseline or child.OuterHeight or ch) end
 end
 box.GridLayout={Columns=cols,Rows=rows,Items=items}
 for _,child in box.Children do if child.Kind~='Words' and child.Style.Position=='absolute' then
  local cs=child.Style
  local c1,c2=Placement.line(cs.GridColumnStart,cols),Placement.line(cs.GridColumnEnd,cols,true)
  local r1,r2=Placement.line(cs.GridRowStart,rows),Placement.line(cs.GridRowEnd,rows,true)
  local x1=if c1 and cols.Starts[c1] then cols.Starts[c1] else 0
  local x2=if c2 and cols.Ends[c2-1] then cols.Ends[c2-1] else width
  local y1=if r1 and rows.Starts[r1] then rows.Starts[r1] else 0
  local y2=if r2 and rows.Ends[r2-1] then rows.Ends[r2-1] else height
  child.StaticX,child.StaticY=left+x1,top+y1
  child.GridContaining={X=left+x1,Y=top+y1,Width=math.max(0,x2-x1),Height=math.max(0,y2-y1)}
 end end
 return height,right,bottom
end
return Grid
