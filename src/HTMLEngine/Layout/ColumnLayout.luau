--!strict
-- Multicol flow fragments line boxes; it never mutates CSS Grid placement.
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Border=require(script.Parent.BorderGeometry)
local Pattern=require(script.Parent.Parent.Rendering.BorderPattern)
local RuleInsets=require(script.Parent.Parent.CSS.ColumnRuleInsets)
local ColumnLayout={}
function ColumnLayout.is(s: any): boolean return s.Display~="grid" and s.Display~="inline-grid" and s.Display~="flex" and s.Display~="inline-flex" and (s.ColumnCount~=nil or s.ColumnWidth~=nil or s.ColumnHeight~=nil) end
function ColumnLayout.geometry(s: any,width: number): (number,number,number)
 local gap=if s.GridGapSpecified then (s.Gap or {0,0})[2] else s.FontSize or 16
 if type(gap)=='table' then gap=Length.resolve(gap,width) end
 gap=math.max(0,gap)
 local count=s.ColumnCount or (if s.ColumnWidth then 32 else 1)
 if s.ColumnWidth then
  local preferred=math.max(.001,Length.resolve(s.ColumnWidth,width))
  count=math.min(count,math.max(1,math.floor((width+gap)/(preferred+gap))))
 end
 count=math.clamp(count,1,32)
 return count,math.max(0,(width-gap*(count-1))/count),gap
end
local function lines(box: any): any
 local result={}
 local function visit(child,x,y)
  local first=#result+1
  if child.Kind=='Words' then
   local grouped={}
   for _,word in child.DisplayItems or child.Items do
    if word.Kind=='Break' or not word.LineIndex then continue end
    local line=grouped[word.LineIndex]
    if not line then
     line={Top=y+(word.LineTop or word.Y or 0),Height=word.LineHeight or word.Height or 0,Items={},Run=child}
     grouped[word.LineIndex]=line;table.insert(result,line)
    end
    table.insert(line.Items,word)
   end
  else for _,nested in child.Children or {} do
   if nested.Kind=='Words' then visit(nested,x,y+(nested.LayoutY or 0))
   elseif nested.Style and nested.Style.Position~='absolute' and nested.Style.Position~='fixed' then visit(nested,x+(nested.LayoutX or 0),y+(nested.LayoutY or 0)) end
  end end
  if child.Kind~='Words' and #result>=first then
   local s=child.Style
   if s.BreakBefore=='column' then result[first].BreakBefore=true end
   if s.BreakAfter=='column' then result[#result].BreakAfter=true end
   if s.BreakBefore=='avoid' or s.BreakBefore=='avoid-column' then result[first].AvoidBefore=true end
   if s.BreakAfter=='avoid' or s.BreakAfter=='avoid-column' then result[#result].AvoidAfter=true end
  end
 end
 visit(box,0,0);table.sort(result,function(a,b)return a.Top<b.Top end)
 return result
end
local function legalBreak(units,index,start)
 local previous,current=units[index-1],units[index]
 if previous and current then
  if previous.BreakAfter or current.BreakBefore then return true end
  if previous.AvoidAfter or current.AvoidBefore then return false end
 end
 if not current or previous.Box~=current.Box or not current.Line then return true end
 local first=if units[start].Box==current.Box then units[start].Index else 1
 return current.Index-first>=current.Orphans and current.Count-current.Index+1>=current.Widows
end
local function plan(units,height,place,lastRowCount)
 local column,start,bottom=1,1,0
 while start<=#units do
  -- Completed rows use the full fragment height. Balance only the remaining
  -- final row; each suffix retains its paragraph indices and widow/orphan rules.
  if lastRowCount and column>1 and (column-1)%lastRowCount==0 then
   local remaining={};local total=0
   for i=start,#units do table.insert(remaining,units[i]);total+=units[i].Height+(if i==start then 0 else units[i].Before or 0) end
   if plan(remaining,height)<=lastRowCount then
    local low,high=0,height
    for _=1,32 do local mid=(low+high)/2;if plan(remaining,mid)>lastRowCount then low=mid else high=mid end end
    local offset=column-1
    local actual,tailBottom=plan(remaining,high,if place then function(unit,col,y,cut)place(unit,col+offset,y,cut)end else nil)
    return offset+actual,math.max(bottom,tailBottom)
   end
  end
  local stop,y=start,0
  local forced=start==1 or units[start].BreakBefore or units[start-1].BreakAfter
  local function topCut(unit,index)
   return if unit.Atomic and index==start and (unit.MarginBreak=='discard' or unit.MarginBreak~='keep' and not forced) then unit.TopMargin or 0 else 0
  end
  local function leading(unit,index)
   if index~=start then return unit.Before or 0 end
   return if not unit.Atomic and (unit.MarginBreak=='keep' or unit.MarginBreak~='discard' and forced) then unit.Before or 0 else 0
  end
  while stop<=#units do
   local unit=units[stop];local before=leading(unit,stop);local usedHeight=unit.Height-topCut(unit,stop)
   if stop>start and (unit.BreakBefore or units[stop-1].BreakAfter or y+before+usedHeight>height+1e-6) then break end
   y+=before+usedHeight;stop+=1
  end
  if stop<=#units and not (units[stop].BreakBefore or units[stop-1].BreakAfter) then
   local boundary=nil
   for index=stop,start+1,-1 do if legalBreak(units,index,start) then boundary=index;break end end
   -- An indivisible paragraph fragment can grow beyond the requested height.
   if not boundary then
    for index=stop+1,#units+1 do if legalBreak(units,index,start) then boundary=index;break end end
   end
   stop=boundary or #units+1
  end
  y=0
  for index=start,stop-1 do
   local unit=units[index];y+=leading(unit,index)
   local cut=topCut(unit,index)
   local paintCut=if not unit.Atomic and index==start and unit.Index==1 then unit.TopMargin or 0 else cut
   if place then place(unit,column,y,paintCut) end
   y+=unit.Height-cut
   if index==stop-1 and unit.MarginBreak~='keep' and stop<=#units then
    local tail=unit.BottomMargin or 0
    y-=if unit.MarginBreak=='discard' then tail else math.min(tail,math.max(0,y-height))
   end
  end
  bottom=math.max(bottom,y);start=stop;column+=1
 end
 return column-1,bottom
end
function ColumnLayout.arrange(box,width,heightFor,layout,alive,definiteHeight,paintFragments)
 local s=box.Style;local count,columnWidth,gap=ColumnLayout.geometry(s,width)
 local bt,_,_,bl=Border.sizes(s);local left,top=bl+s.Padding[4],box.ContentTop or bt+s.Padding[1]
 local rowGap=if s.RowGapSpecified then (s.Gap or {0,0})[1] else s.FontSize or 16
 rowGap=math.max(0,if type(rowGap)=='table'then Length.resolve(rowGap,definiteHeight or 0)else rowGap)
 local columnHeight=if s.ColumnHeight then Length.resolve(s.ColumnHeight,width) else nil
 local wrap=s.ColumnWrap=='wrap' or (s.ColumnWrap~='nowrap' and columnHeight~=nil)
 local cursor=0;local right=width;local region={};local segments={};local fragments={};local usedColumns=0;local usedRows=0;local paintedBottom=0
 local function flush(final: boolean?)
  if #region==0 then return end
  local units={};local total=0;local runs={}
  for _,child in region do
   local firstUnit=#units+1
   local h=layout(child,columnWidth,0,0,alive,true,{})
   if not alive() then return end
   local m=if child.Kind=='Words' then {0,0,0,0} else child.LayoutMargin or child.Style.Margin
   local children=lines(child)
   -- Rich/independent boxes stay atomic; ordinary text blocks split at lines.
   local atomic=#children==0 or child.Kind~='Words' and (child.Style.BreakInside=='avoid' or child.Style.BreakInside=='avoid-column' or child.OpacityGroup or child.ScrollGui or child.Style.Display=='flex' or child.Style.Display=='grid' or child.ImageItem)
   if atomic then
    table.insert(units,{Box=child,Height=h,Before=0,Atomic=true,SourceTop=0,TopMargin=m[1],BottomMargin=m[3],MarginBreak=child.Style.MarginBreak or 'auto'})
   else
    local previous=0
    for index,line in children do
     local leading=if index==1 then m[1]+line.Top else math.max(0,line.Top-previous)
     table.insert(units,{Box=child,Height=line.Height,Before=leading,Line=line,SourceTop=line.Top,Index=index,Count=#children,Orphans=child.Style.Orphans or 2,Widows=child.Style.Widows or 2,BreakBefore=line.BreakBefore,BreakAfter=line.BreakAfter,AvoidBefore=line.AvoidBefore,AvoidAfter=line.AvoidAfter,MarginBreak=child.Style.MarginBreak or 'auto',TopMargin=m[1],BottomMargin=if index==#children then m[3] else 0})
     previous=line.Top+line.Height
    end
    if #units>0 then units[#units].Height+=math.max(0,h-m[1]-previous) end
   end
   if #units>=firstUnit and child.Kind~='Words' then
    if child.Style.BreakBefore=='column' then units[firstUnit].BreakBefore=true end
    if child.Style.BreakAfter=='column' then units[#units].BreakAfter=true end
    if child.Style.BreakBefore=='avoid' or child.Style.BreakBefore=='avoid-column' then units[firstUnit].AvoidBefore=true end
    if child.Style.BreakAfter=='avoid' or child.Style.BreakAfter=='avoid-column' then units[#units].AvoidAfter=true end
   end
  end
  for _,unit in units do total+=unit.Height+(unit.Before or 0) end
  -- Resolve the used height through the block sizing rules, including min/max
  -- limits, then remove space already consumed by earlier spanner regions.
  local limit=columnHeight or math.max(0,heightFor(math.huge)-cursor)
  local constrained=limit<math.huge
  local height=if s.ColumnFill=='auto' and constrained then limit else math.max(0,total/math.max(1,count))
  if not (s.ColumnFill=='auto' and constrained) then
   local low,high=height,total
   for _=1,32 do local middle=(low+high)/2;if plan(units,middle)>count then low=middle else high=middle end end
   height=high
  end
  -- Balancing may not grow a definite column area. Additional fragments flow
  -- into overflow columns using the same width and gap as the initial columns.
  if constrained then height=math.min(height,limit) end
  local bottom=0;local placed={}
  local actualCount=plan(units,height,function(unit,column,y,cut)
   local row=if wrap then math.floor((column-1)/count) else 0
   local physicalColumn=if wrap then (column-1)%count+1 else column
   if row>0 then y+=row*(limit+rowGap) end
   local child=unit.Box;local cx=(physicalColumn-1)*(columnWidth+gap)
   if s.Direction=='rtl' then cx=width-columnWidth-cx end
   right=math.max(right,cx+columnWidth)
   bottom=math.max(bottom,y+unit.Height)
   paintedBottom=math.max(paintedBottom,cursor+y+unit.Height)
   if not placed[child] then
    placed[child]={X=cx,Y=y}
    if child.Kind~='Words' then
     local m=child.LayoutMargin or child.Style.Margin
     child.LayoutX,child.LayoutY=left+cx+m[4],top+cursor+y+m[1]-(cut or 0)
     child.PaintX,child.PaintY=child.LayoutX,child.LayoutY
     child.Gui.Position=UDim2.fromOffset(child.LayoutX,child.LayoutY)
    end
   end
   if unit.Atomic then
    if child.Kind=='Words' then layout(child,columnWidth,left+cx,top+cursor+y,alive,true)
    end
   else
    local origin=placed[child]
    local dy=y-origin.Y-unit.SourceTop
    local dx=cx-origin.X
    if child.Kind=='Words' then dx=cx+left;dy=y-unit.SourceTop+top+cursor end
    for _,word in unit.Line.Items do
     word.X+=dx;word.Y+=dy
     word.ColumnIndex=column
     word.LineTop+=dy;word.LineBaseline+=dy;word.LineLeft+=dx;word.LineRight+=dx
    end
    runs[unit.Line.Run]=true
   end
   table.insert(fragments,{Box=child,Column=physicalColumn,Row=row+1,X=left+cx,Y=top+cursor+y,Width=columnWidth,Height=unit.Height})
  end,if wrap and s.ColumnFill~='auto' then count else nil)
  for run in runs do if not paintFragments(run,alive) then return end end
  usedColumns=math.max(usedColumns,actualCount)
  local rowCount=if wrap then math.ceil(actualCount/count) else 1
  usedRows+=rowCount
  local ruleHeight=if columnHeight or (final and definiteHeight) or (constrained and actualCount>count) then limit else bottom
  for row=0,rowCount-1 do
   local occupied=if wrap then math.min(count,actualCount-row*count) else actualCount
   local visibleCount=if s.ColumnRuleVisibilityItems=='all' or s.ColumnRuleVisibilityItems=='around' then math.max(count,occupied) else occupied
   table.insert(segments,{Y=top+cursor+(if row>0 then row*(limit+rowGap) else 0),Height=ruleHeight,Count=visibleCount,Occupied=occupied,Width=columnWidth,Gap=gap,
    StartGap=if row>0 then rowGap else 0,EndGap=if row<rowCount-1 then rowGap else 0,
    PreviousCount=if row>0 then count else 0,NextCount=if row<rowCount-1 then math.min(count,actualCount-(row+1)*count) else 0})
  end
  cursor+=if columnHeight then rowCount*limit+(rowCount-1)*rowGap else bottom
  table.clear(region)
 end
 for _,child in box.FlowChildren or box.Children do
  if not alive() then return 0,0,0 end
  if child.Kind~='Words' and (child.Style.Position=='absolute' or child.Style.Position=='fixed') then child.StaticX,child.StaticY=left,top+cursor;continue end
  if child.Kind~='Words' and child.Style.ColumnSpan=='all' then
   flush()
   local h=layout(child,width,left,top+cursor,alive,true,{})
   cursor+=h
  else table.insert(region,child) end
 end
 flush(true)
 box.ColumnLayout={Count=count,UsedCount=usedColumns,Rows=usedRows,Width=columnWidth,Gap=gap,Fragments=fragments,Segments=segments}
 box.ColumnRules=box.ColumnRules or {}
 box.ColumnRulePatterns=box.ColumnRulePatterns or {}
 local used=0;local enabled=s.ColumnRuleStyle~='none' and s.ColumnRuleStyle~='hidden' and (s.ColumnRuleWidth or 0)>0
 local painted={};local continuous={}
 for _,segment in segments do for index=1,segment.Count-1 do
  if s.ColumnRuleVisibilityItems=='around' and index>segment.Occupied then continue end
  local startJunction=segment.PreviousCount>index;local endJunction=segment.NextCount>index
  local startValue=if startJunction then s.ColumnRuleInsetJunctionStart else s.ColumnRuleInsetCapStart
  local endValue=if endJunction then s.ColumnRuleInsetJunctionEnd else s.ColumnRuleInsetCapEnd
  local legacyStart=if segment.StartGap==0 then s.ColumnRuleEdgeInsetStart else s.ColumnRuleInteriorInsetStart
  local legacyEnd=if segment.EndGap==0 then s.ColumnRuleEdgeInsetEnd else s.ColumnRuleInteriorInsetEnd
  local startInset=RuleInsets.offset(legacyStart or startValue,segment.StartGap,startJunction)
  local endInset=RuleInsets.offset(legacyEnd or endValue,segment.EndGap,endJunction)
  if s.ColumnRuleBreak=='none' then
   local old=continuous[index]
   if old then old.Bottom=segment.Y+segment.Height-endInset
   else old={Index=index,Y=segment.Y+startInset,Bottom=segment.Y+segment.Height-endInset};continuous[index]=old;table.insert(painted,old)end
  else table.insert(painted,{Index=index,Y=segment.Y+startInset,Bottom=segment.Y+segment.Height-endInset})end
 end end
 for _,segment in painted do
  local index=segment.Index
  used+=1;local rule=box.ColumnRules[used]
  if not rule and box.Factory then rule=box.Factory.create('Frame',box.Gui,{Name='ColumnRule_'..used,ZIndex=0});box.ColumnRules[used]=rule end
  if rule then
   local ruleHeight=math.max(0,segment.Bottom-segment.Y)
   rule.Visible=enabled and s.Visibility~='hidden' and ruleHeight>0;rule.BackgroundTransparency=1
   local center=index*(columnWidth+gap)-gap/2
   if s.Direction=='rtl' then center=width-center end
   rule.Position=UDim2.fromOffset(left+center-(s.ColumnRuleWidth or 1)/2,segment.Y)
   rule.Size=UDim2.fromOffset(s.ColumnRuleWidth or 1,ruleHeight)
   local pool=box.ColumnRulePatterns[used] or {};box.ColumnRulePatterns[used]=pool
   if enabled then Pattern.draw(pool,box.Factory,rule,s.ColumnRuleStyle,ruleHeight,s.ColumnRuleWidth,false,0,function()return s.ColumnRuleColor,s.ColumnRuleColorAlpha or 1 end) end
  end
 end
 for index=used+1,#box.ColumnRules do box.ColumnRules[index].Visible=false end
 local height=heightFor(cursor)
 return height,right,math.max(height,cursor,paintedBottom)
end
return ColumnLayout
