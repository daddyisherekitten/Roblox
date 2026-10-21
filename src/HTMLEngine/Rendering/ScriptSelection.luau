--!strict
-- Retained-fragment selection bridge. DOM ranges own live boundaries; this
-- module owns only paint overlays and bounded, on-demand source mapping.
local TextSelection=require(script.Parent.Parent.Input.TextSelection)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Stylesheet=require(script.Parent.Parent.CSS.Stylesheet)
local Style=require(script.Parent.Parent.CSS.InlineStyle)
local WhiteSpace=require(script.Parent.Parent.Layout.WhiteSpace)
local ScriptSelection={}
local MAX_NODES,MAX_SPANS,MAX_RECTS,MAX_TEXT=32768,131072,4096,1048576
local function length(text)
 local count=0;for _,code in utf8.codes(text or '')do count+=if code>=0x10000 then 2 else 1 end;return count
end
local function visible(item,geometry,textOnly)
 local gui=item.TextGui or item.Gui;local style=item.Style or {}
 return gui and(textOnly or gui.Visible~=false)and not style.Hidden and (geometry or(style.Visibility~='hidden'and style.Visibility~='collapse'))
end
local function graphemeOffsets(text,left,right)
 local start,finish,count=0,0,0
 for gFirst,gLast in utf8.graphemes(text or '')do count+=1;if gLast<left then start=count end;if gFirst<=right then finish=count end end
 return start,if right<left then start else finish
end
function ScriptSelection.new(page: any,tree: any,runtime: any,options: any?): any
 local extractOnly=options and options.ExtractOnly==true
 local owned=tree.TextSelection==nil
 local painter=tree.TextSelection or TextSelection.new(tree,if extractOnly then {Register=false}else nil)
 local api={Alive=true};local current,callback=nil,nil
 local customPainters,customRecords={},{}
 local function renderedNode(node)
  if tree.IsContentSkipped and node and tree:IsContentSkipped(node)then return false end
  local current=node
  while current do local style=tree.NodeStyles and tree.NodeStyles[current];if style and style.Hidden then return false end;current=current.Parent or(if current.Kind=='ShadowRoot'then current.Host else nil)end
  return true
 end
 local function indexed(root)
  local index,order={},{};local cursor,count=0,0
  local pending={{Node=root or page.Document,Exit=false}}
  while #pending>0 do
   local job=table.remove(pending);local node=job.Node
   if job.Exit then index[node].Finish=cursor;cursor+=1
   else
    count+=1;assert(count<=MAX_NODES,'Selection DOM mapping budget exceeded')
    local record={Start=cursor,Content=cursor+1};index[node]=record;table.insert(order,node);cursor+=1
    if node.Kind=='Text'or node.Kind=='Comment'or node.Kind=='CDATASection'then record.Length=length(node.Text);cursor+=record.Length;record.Finish=cursor;cursor+=1
    else table.insert(pending,{Node=node,Exit=true});for i=#(node.Children or {}),1,-1 do table.insert(pending,{Node=node.Children[i],Exit=false})end end
   end
  end
  return index,order
 end
 local function boundary(index,node,offset)
  local record=index[node];if not record then return nil end
  if record.Length then return record.Content+math.clamp(offset,0,record.Length)end
  local child=(node.Children or {})[offset+1];return if child and index[child]then index[child].Start else record.Finish
 end
 local function segments(a,ao,b,bo,caret,textOnly,sourceCopy)
  -- Rebuild on demand so silent live-range mutations cannot reuse an old DOM
  -- index. This never measures/reflows the document or changes source GUIs.
  if not ShadowTree.Connected(a,page.Document)or not ShadowTree.Connected(b,page.Document)then return {},nil,nil,{},{}end
  local root=ShadowTree.Root(a)
  if root~=ShadowTree.Root(b)then
   -- A range crossing tree scopes exposes only the ordinary-tree projection
   -- for rendered copying, just like the document selection in Chromium.
   local function rescope(node,offset,finish)
    local scope=ShadowTree.Root(node)
    while scope.Kind=='ShadowRoot'do
     local host=scope.Host;if not host or not host.Parent then return nil,0 end
     node,offset=host.Parent,assert(table.find(host.Parent.Children,host))-1+(if finish then 1 else 0)
     scope=ShadowTree.Root(node)
    end
    return node,offset
   end
   a,ao=rescope(a,ao,false);b,bo=rescope(b,bo,true)
   if not a or not b then return {},nil,nil,{},{}end
   root=ShadowTree.Root(a)
  end
  local index,order=indexed(root);local first,last=boundary(index,a,ao),boundary(index,b,bo)
  if not first or not last then return {},nil,nil,index,order end
  if first>last then first,last=last,first end
  local out,all,visited,work={},{},{},0
  for _,item in tree.TextItems or {}do
   if visited[item]then continue end;visited[item]=true
   if sourceCopy and item.Style and item.Style.UserSelect=='none'then continue end
   if not visible(item,caret,textOnly)or not renderedNode(item.Style and item.Style.Node)
    or(textOnly and(item.WrapOwner or item.PaintOwner))or not(item.SourceSpans or item.SourceHiddenSpans)then continue end
   local left,right,position,selectedStart,selectedEnd=nil,nil,nil,nil,nil
   for _,span in item.SourceSpans or {}do
    work+=1;assert(work<=MAX_SPANS,'Selection source mapping budget exceeded')
    local record=index[span.Node];if not record then continue end
    local start,finish=record.Content+span.Start,record.Content+span.Finish;position=position or start
    if not textOnly and start<last and finish>first then
     left=math.min(left or span.FirstByte,span.FirstByte);right=math.max(right or span.LastByte,span.LastByte)
     selectedStart=math.min(selectedStart or start,start);selectedEnd=math.max(selectedEnd or finish,finish)
    elseif not textOnly and caret and first==last and start<=first and finish>=first then
     local at=if first==finish then span.LastByte else span.FirstByte-1
     left,right,selectedStart,selectedEnd=at+1,at,first,first
    end
   end
   if not textOnly then for _,span in item.SourceHiddenSpans or {}do
    local record=index[span.Node];if not record then continue end
    local start,finish=record.Content+span.Start,record.Content+span.Finish;position=position or start
    if start<last and finish>first or caret and first==last and start<=first and finish>=first then
     left=math.min(left or span.Byte+1,span.Byte+1);right=math.max(right or span.Byte,span.Byte)
     selectedStart=math.min(selectedStart or start,start);selectedEnd=math.max(selectedEnd or finish,finish)
    end
   end end
   if textOnly then
    -- Browser stringification includes a displayed grapheme when its original
    -- starting UTF-16 boundary is selected. Geometry/paint above instead uses
    -- any overlap, as CSSOM View requires for partial typographic characters.
    local sourceIndex=1;local sourceSpans=item.SourceSpans or {}
    for gFirst,gLast in utf8.graphemes(item.Text or '')do
     while sourceSpans[sourceIndex]and sourceSpans[sourceIndex].LastByte<gFirst do sourceIndex+=1 end
     local span=sourceSpans[sourceIndex];local record=span and index[span.Node]
     if record and span.FirstByte<=gFirst then
      local start=record.Content+span.Start
      if start>=first and start<last then left=left or gFirst;right=gLast;selectedStart=selectedStart or start end
     end
    end
   end
   local gap=false
   for _,span in item.SourceGap or {}do
    work+=1;assert(work<=MAX_SPANS,'Selection source mapping budget exceeded')
    local record=index[span.Node]
    if record and record.Content+span.Start<last and record.Content+span.Finish>first then gap=true end
   end
   if position then table.insert(all,{Item=item,Order=position})end
   if left or gap then
    assert(#out<MAX_RECTS,'Selection rectangle budget exceeded')
    local start,finish=0,0
    if left then start,finish=graphemeOffsets(item.Text,left,right)end
    table.insert(out,{Item=item,First=start,Last=finish,Gap=gap,Order=position or 0,
     FirstByte=left,LastByte=right,SourceStart=selectedStart,SourceEnd=selectedEnd})
   end
  end
  table.sort(all,function(x,y)return x.Order<y.Order end)
  local previous={};for i=2,#all do previous[all[i].Item]=all[i-1].Item end
  table.sort(out,function(x,y)return x.Order<y.Order end)
  for _,entry in out do if entry.Gap then entry.Previous=previous[entry.Item]end end
  return out,first,last,index,order
 end
 local function ready()return api.Alive and page.Alive~=false and not tree.LayoutInProgress end
 function api:PaintHighlights(records)
  if not ready()then return end
  customRecords=records;local active={};local total=0
  for rank,record in records do
   local byItem={}
   for _,range in record.Ranges do
    for _,segment in segments(range.StartNode,range.StartOffset,range.EndNode,range.EndOffset,false)do
     total+=1;assert(total<=MAX_RECTS,'CSS highlight fragment budget exceeded')
     local list=byItem[segment.Item];if not list then list={};byItem[segment.Item]=list end;table.insert(list,segment)
    end
   end
   local slices={}
   for _,list in byItem do
    table.sort(list,function(a,b)return if a.First==b.First then a.Last<b.Last else a.First<b.First end)
    local united={}
    for _,segment in list do
     local last=united[#united]
     if last and segment.First<=last.Last then last.Last=math.max(last.Last,segment.Last);last.Previous=last.Previous or segment.Previous
     else table.insert(united,table.clone(segment))end
    end
    for index,segment in united do if not slices[index]then slices[index]={}end;table.insert(slices[index],segment)end
   end
   local pool=customPainters[record.Name];if not pool then pool={};customPainters[record.Name]=pool end;active[record.Name]=true
   local function color(item)
    local node=item.Style.Node;local result={Color=item.Style.Color,Background=Color3.new(0,0,0),Alpha=0}
    local lineage={};while node do if node.Kind=='Element'then table.insert(lineage,1,node)end;node=node.Parent or(if node.Kind=='ShadowRoot'then node.Host else nil)end
    for _,owner in lineage do
     local base=table.clone(item.Style);base.Color=result.Color
     if tree.HighlightStyle then
      local resolved=tree:HighlightStyle(owner,'highlight('..record.Name..')',base)
      if resolved then result.Color=resolved.Color;if resolved.Background then result.Background=resolved.Background;result.Alpha=resolved.BackgroundAlpha or 1 end end
      continue
     end
     local declarations=Stylesheet.matchPseudo(tree.CSSRules,owner,'highlight('..record.Name..')',tree.CSSStates)
     if #declarations.Normal>0 or #declarations.Important>0 then
      local fake={Kind='Element',Name='span',Attributes={},Children={},Parent=owner}
      local resolved=Style.resolve(fake,base,function()end,false,declarations)
      result.Color=resolved.Color
      if resolved.Background then result.Background=resolved.Background;result.Alpha=resolved.BackgroundAlpha or 1 end
     end
    end
    return result
   end
   for index,slice in slices do
    local painter=pool[index];if not painter then painter=TextSelection.new(tree,{Register=false,Style=color,ZOffset=rank*2});pool[index]=painter end
    painter.CustomStyle=color;painter.ZOffset=rank*2;painter:RefreshStyles();painter:Apply(slice)
   end
   for index=#pool,#slices+1,-1 do pool[index]:Destroy();pool[index]=nil end
  end
  for name,pool in customPainters do if not active[name]then for _,p in pool do p:Destroy()end;customPainters[name]=nil end end
 end
 local function repaint()
  if not ready()or(runtime and runtime.HasPending and runtime:HasPending())then return end
  if not current then painter:Apply({});return end
  painter:Apply(segments(current[1],current[2],current[3],current[4],false))
 end
 function api:Apply(a,ao,b,bo)
  if not api.Alive then return end
  local changed=if current then current[1]~=a or current[2]~=ao or current[3]~=b or current[4]~=bo else a~=nil and b~=nil
  current=if a and b then {a,ao,b,bo}else nil;repaint()
  if tree.SelectionCopyChanged then tree.SelectionCopyChanged(if changed then 'range'else 'paint')end
 end
 function api:Clear()current=nil;if ready()then painter:Clear(true)end;if tree.SelectionCopyChanged then tree.SelectionCopyChanged()end end
 function api:SetNativeChange(fn)if api.Alive then callback=fn end end
 if not extractOnly then painter:SetChanged(function(a,b)
  if not api.Alive or not callback then return end
  local anchor,focus=painter:Point(a),painter:Point(b)
  if anchor and focus then return callback(anchor.Node,anchor.Offset,focus.Node,focus.Offset)
  elseif not a and not b then return callback(nil,0,nil,0)end
 end)end
 function api:RangeRects(a,ao,b,bo)
  assert(ready(),'Range geometry requires a current live layout')
  local selected,first,last,index,order=segments(a,ao,b,bo,true);local result={}
  if not first then return result end
  local origin=page.Root and page.Root.AbsolutePosition or {X=0,Y=0}
  local function add(rect,position,node,merge)
   if not rect then return end
   assert(#result<MAX_RECTS,'Selection rectangle budget exceeded')
   rect.X-=origin.X;rect.Y-=origin.Y;table.insert(result,{Rect=rect,Order=position,Node=node,Merge=merge})
  end
  for _,entry in selected do
   local item=entry.Item;local gui=item.TextGui or item.Gui
   local merge=(gui.AbsoluteRotation or gui.Rotation or 0)==0
   if entry.Previous then
    for _,span in item.SourceGap or {}do local record=index[span.Node]
     if record and record.Content+span.Start<last and record.Content+span.Finish>first then
      add(painter:GapRect(entry.Previous,item),record.Content+span.Start,span.Node,merge);break
     end
    end
   end
   local byNode={}
   for _,span in item.SourceSpans or {}do local record=index[span.Node]
    if not record then continue end
    local start,finish=record.Content+span.Start,record.Content+span.Finish
    local left,right=span.FirstByte,span.LastByte
    if first==last and start<=first and finish>=first then
     local at=if first==finish then right else left-1;left,right=at+1,at
    elseif not(start<last and finish>first)then continue end
    local part=byNode[span.Node]
    if part then part.Left=math.min(part.Left,left);part.Right=math.max(part.Right,right)
    else byNode[span.Node]={Left=left,Right=right,Order=start}end
   end
   for _,span in item.SourceHiddenSpans or {}do local record=index[span.Node]
    if not record then continue end
    local start,finish=record.Content+span.Start,record.Content+span.Finish
    if not(start<last and finish>first or first==last and start<=first and finish>=first)then continue end
    local left,right=span.Byte+1,span.Byte;local part=byNode[span.Node]
    if part then part.Left=math.min(part.Left,left);part.Right=math.max(part.Right,right)
    else byNode[span.Node]={Left=left,Right=right,Order=start}end
   end
   for node,part in byNode do
    local left,right=graphemeOffsets(item.Text,part.Left,part.Right)
    add(painter:Rect(item,left,right),part.Order,node,merge)
   end
  end
  -- Wholly selected top-level elements contribute border-box rectangles,
  -- followed in document order by their selected Text fragments.
  if runtime and runtime.Geometry then
   for _,node in order do local record=index[node];local parent=index[node.Parent]
    if node.Kind=='Element'and first<=record.Start and last>=record.Finish+1
     and not(parent and first<=parent.Start and last>=parent.Finish+1)then
     for _,rect in runtime.Geometry:ClientRects(node)do
      assert(#result<MAX_RECTS,'Selection rectangle budget exceeded');table.insert(result,{Rect=rect,Order=record.Start})
     end
    end
   end
  end
  table.sort(result,function(x,y)return x.Order<y.Order end)
  local rects,lastEntry={},nil
  for _,entry in result do
   local rect,previous=entry.Rect,lastEntry and lastEntry.Rect
   if previous and entry.Node and entry.Node==lastEntry.Node and entry.Merge and lastEntry.Merge
    and math.abs(rect.Y-previous.Y)<0.01 and math.abs(rect.Height-previous.Height)<0.01
    and rect.X<=previous.X+previous.Width+0.01 and rect.X+rect.Width>=previous.X-0.01 then
    local right=math.max(previous.X+previous.Width,rect.X+rect.Width);previous.X=math.min(previous.X,rect.X);previous.Width=right-previous.X
   else table.insert(rects,rect);lastEntry=entry end
  end
  return rects
 end
 local verticalGoal=nil
 function api:MoveVisual(node,offset,forward,granularity)
  if not ready()then return nil end
  local root=ShadowTree.Root(node);local points,seen={},{};local work=0
  local currentRect=self:RangeRects(node,offset,node,offset)[1]
  if not currentRect then return nil end
  for _,item in tree.TextItems or {}do
   if seen[item]then continue end;seen[item]=true
   if not visible(item,true,false)or not renderedNode(item.Style and item.Style.Node)or not item.SourceSpans then continue end
   local count=0;for _ in utf8.graphemes(item.Text or '')do count+=1 end
   for at=0,count do
    work+=1;assert(work<=MAX_SPANS,'Selection caret mapping budget exceeded')
    local p=painter:Point({Item=item,Offset=at})
    if not p or ShadowTree.Root(p.Node)~=root then continue end
    local rect=painter:Rect(item,at,at)
    if rect then
     local origin=page.Root and page.Root.AbsolutePosition or {X=0,Y=0}
     table.insert(points,{Node=p.Node,Offset=p.Offset,X=rect.X-origin.X,Y=rect.Y-origin.Y,H=rect.Height})
    end
   end
  end
  if #points==0 then return nil end
  local lines={};table.sort(points,function(a,b)return if math.abs(a.Y-b.Y)<.5 then a.X<b.X else a.Y<b.Y end)
  for _,p in points do
   local line=lines[#lines]
   if not line or math.abs(p.Y-line.Y)>math.max(1,math.min(p.H,line.H)*.4)then
    line={Y=p.Y,H=p.H,Points={}};table.insert(lines,line)
   end
   table.insert(line.Points,p)
  end
  local lineIndex,distance=1,math.huge
  for i,line in lines do local d=math.abs(currentRect.Y-line.Y);if d<distance then lineIndex,distance=i,d end end
  local line=lines[lineIndex]
  if granularity=='lineboundary'then
   verticalGoal=nil
   local owner=node;local rtl=false
   while owner do
    local style=tree.NodeStyles and tree.NodeStyles[owner]
    if style and style.Direction then rtl=style.Direction=='rtl';break end
    owner=if owner.Kind=='ShadowRoot'then owner.Host else owner.Parent
   end
   local p=if forward~=rtl then line.Points[#line.Points]else line.Points[1]
   return p.Node,p.Offset
  end
  local goal=if verticalGoal and verticalGoal.Node==node and verticalGoal.Offset==offset then verticalGoal.X else currentRect.X
  local target=lines[math.clamp(lineIndex+(if forward then 1 else -1),1,#lines)]
  local best,bestDistance=nil,math.huge
  for _,p in target.Points do local d=math.abs(p.X-goal);if d<bestDistance then best,bestDistance=p,d end end
  verticalGoal={Node=best.Node,Offset=best.Offset,X=goal}
  return best.Node,best.Offset
 end
 function api:ScrollFocus(node,offset)
  if not ready()or not runtime or not runtime.Geometry or not runtime.Geometry.ScrollSelectionRect then return end
  local owner=node
  while owner and owner.Kind~='Element'do owner=owner.Parent or(if owner.Kind=='ShadowRoot'then owner.Host else nil)end
  if owner then runtime.Geometry:ScrollSelectionRect(owner,function()return self:RangeRects(node,offset,node,offset)[1]end)end
 end
 function api:RenderedText(a,ao,b,bo,trailingBlockBreaks,sourceCopy)
  assert(ready(),'Selection text requires a current live layout')
  -- Ellipsis/clamping and soft wrapping are paint projections. Copying still
  -- includes the source run, excluding generated hyphens/ellipsis characters.
  local selected,first,last,index,order=segments(a,ao,b,bo,false,true,sourceCopy)
  if not first or first==last then return ''end
  local events={}
  local blockCache,lastBreak,lastGlyph={},{},{}
  local function blockOf(node)
   if blockCache[node]then return blockCache[node]end
   local current=node.Parent;local result=page.Document
   while current do
    local style=tree.NodeStyles and tree.NodeStyles[current]
    if style and(style.Display=='block'or style.Display=='flex'or style.Display=='grid'or style.Display=='table-cell')then result=current;break end
    current=current.Parent
   end
   blockCache[node]=result;return result
  end
  for _,node in order do
   if node.Kind~='Text'or not renderedNode(node)then continue end
   local parentStyle=tree.NodeStyles and tree.NodeStyles[node.Parent];local collapse=parentStyle and WhiteSpace.collapse(parentStyle)
   if not parentStyle or parentStyle.Hidden or parentStyle.Visibility=='hidden'or(collapse~='preserve'and collapse~='preserve-breaks'and collapse~='break-spaces')then continue end
   local offset=0
   for _,code in utf8.codes(node.Text)do
    if code==10 then lastBreak[blockOf(node)]=index[node].Content+offset end
    offset+=if code>=0x10000 then 2 else 1
   end
  end
  local function sourceOrder(item,byte,fallback)
   for _,span in item.SourceSpans or {}do
    local record=index[span.Node]
    if record and span.LastByte>=byte then return record.Content+span.Start end
   end
   return fallback
  end
  local copiedSources={}
  for _,entry in selected do
   local item=entry.Item
   if sourceCopy and item.SourceTransform then
    for _,span in item.SourceSpans or {}do
     local record=index[span.Node];local at=record and record.Content+span.Start
     if at and at>=first and at<last and span.CopyText and not copiedSources[at]then
     copiedSources[at]=true;table.insert(events,{Order=at,Text=span.CopyText})
     end
    end
   elseif not sourceCopy and item.Kind=='Space'and WhiteSpace.expandable(item.Style or{})and((item.Style or{}).TextTransform or''):find('full-width',1,true)then
    for _,span in item.SourceSpans or{}do
     local record=index[span.Node];local at=record and record.Content+span.Start
     if at and at>=first and at<last then
      local rendered=item.Text:sub(span.FirstByte,span.LastByte):gsub(' ','　')
      table.insert(events,{Order=at,Text=rendered})
     end
    end
   elseif entry.FirstByte then
    local at=entry.FirstByte
    local text=item.CopyText or item.Text
    for _,span in item.SourceHiddenSpans or {}do
     if span.Byte>=at and span.Byte<entry.LastByte then
      table.insert(events,{Order=sourceOrder(item,at,entry.SourceStart or entry.Order),Text=text:sub(at,span.Byte)})
      at=span.Byte+1
     end
    end
    if at<=entry.LastByte then table.insert(events,{Order=sourceOrder(item,at,entry.SourceStart or entry.Order),Text=text:sub(at,entry.LastByte)})end
   end
   if entry.Gap and item.SpaceBefore and entry.Previous then table.insert(events,{Order=entry.Order-0.5,Text=' '})end
  end
  local visited={}
  for _,item in tree.TextItems or {}do
   if sourceCopy and item.Style and item.Style.UserSelect=='none'then continue end
   if visited[item]or item.WrapOwner or item.PaintOwner or not visible(item,false,true)or not renderedNode(item.Style and item.Style.Node)then continue end
   visited[item]=true
   for _,span in item.SourceSpans or {}do
    local record=index[span.Node]
    if record then local block=blockOf(span.Node);lastGlyph[block]=math.max(lastGlyph[block]or -math.huge,record.Content+span.Start)end
   end
   for _,span in item.SourceHiddenSpans or {}do
    local record=index[span.Node]
    if record then
     local at=record.Content+span.Start
     local block=blockOf(span.Node);lastGlyph[block]=math.max(lastGlyph[block]or -math.huge,at)
     if at>=first and at<last and(sourceCopy or not span.TransformHidden)then table.insert(events,{Order=at,Text=span.Text})end
    end
   end
  end
  for _,node in order do
   local record=index[node];local style=tree.NodeStyles and tree.NodeStyles[node]
   if not renderedNode(node)then continue end
   if node.Kind=='Element'and style and not style.Hidden and style.Visibility~='hidden'and style.Visibility~='collapse'then
    if sourceCopy and style.UserSelect=='none'then continue end
    if node.Name=='br'and first<=record.Start and last>=record.Finish+1 then table.insert(events,{Order=record.Start,Text='\n'})
    elseif style.Display=='block'or style.Display=='flex'or style.Display=='grid'or style.Display=='table-row'then
     local breaks=if node.Name=='p'then 2 else 1
     if first<record.Start and last>record.Start then table.insert(events,{Order=record.Start,Breaks=breaks})end
     if first<record.Finish and last>record.Finish then table.insert(events,{Order=record.Finish,Breaks=breaks})end
    end
   elseif record.Length and node.Kind=='Text'then
    local parentStyle=tree.NodeStyles and tree.NodeStyles[node.Parent];local collapse=parentStyle and WhiteSpace.collapse(parentStyle)
    if parentStyle and not(sourceCopy and parentStyle.UserSelect=='none')and not parentStyle.Hidden and parentStyle.Visibility~='hidden'and(collapse=='preserve'or collapse=='preserve-breaks'or collapse=='break-spaces')then
     local offset=0
     for _,code in utf8.codes(node.Text)do
      local start=record.Content+offset;offset+=if code>=0x10000 then 2 else 1
      if start<last and start+1>first and code==10 then
       local block=blockOf(node)
       -- A terminal source LF ends its current line without creating another
       -- rendered text line. Copy it only when following content remains.
       if start~=lastBreak[block]or start<(lastGlyph[block]or -math.huge)then table.insert(events,{Order=start,Text='\n'})end
      end
     end
    end
   end
  end
  table.sort(events,function(x,y)return x.Order<y.Order end)
  local result,bytes,pending={},0,0
  for _,event in events do
   if event.Breaks then pending=math.max(pending,event.Breaks)
   else
    if pending>0 and #result>0 then table.insert(result,string.rep('\n',pending));bytes+=pending end
    pending=0;bytes+=#event.Text;assert(bytes<=MAX_TEXT,'Selection text budget exceeded');table.insert(result,event.Text)
   end
  end
  if trailingBlockBreaks and pending>0 and #result>0 then
   bytes+=pending;assert(bytes<=MAX_TEXT,'Selection text budget exceeded');table.insert(result,string.rep('\n',pending))
  end
  return table.concat(result)
 end
 -- Plain-text copy preparation is distinct from Selection.toString's rendered
 -- string. This does not claim access to the operating system clipboard.
 function api:CopyText(a,ao,b,bo,trailingBlockBreaks)
  return self:RenderedText(a,ao,b,bo,trailingBlockBreaks,true)
 end
 function api:AfterLayout()
  repaint();if #customRecords>0 then self:PaintHighlights(customRecords)end
  if current and tree.SelectionCopyChanged then tree.SelectionCopyChanged()end
 end
 function api:AfterPaint(copyChanged)
  if current then painter:RefreshStyles();repaint();if tree.SelectionCopyChanged then tree.SelectionCopyChanged(if copyChanged then 'text'else 'paint')end end
  if #customRecords>0 then self:PaintHighlights(customRecords)end
 end
 local paintChanged=function(copyChanged)api:AfterPaint(copyChanged)end
 if not extractOnly then tree.SelectionPaintChanged=paintChanged end
 function api:Destroy()
  if not api.Alive then return end;api.Alive=false;callback,current=nil,nil
  if tree.SelectionPaintChanged==paintChanged then tree.SelectionPaintChanged=nil end
  for _,pool in customPainters do for _,p in pool do p:Destroy()end end;table.clear(customPainters);table.clear(customRecords)
  if extractOnly then if owned then painter:Destroy()end
  else painter:SetChanged(nil);if owned then painter:Destroy()elseif painter.Alive then painter:Clear(true)end end
 end
 return api
end
return ScriptSelection
