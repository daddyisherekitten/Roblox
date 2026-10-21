--!strict
-- Logical directional pieces are established before native measurement. GUI
-- owners and source offsets remain in DOM order; BidiPaint orders actual lines.
local Bidi=require(script.Parent.Bidi)
local Class=require(script.Parent.BidiClass)
local Scope=require(script.Parent.BidiScope)
local Source=require(script.Parent.TextSource)
local Work=require(script.Parent.Parent.WorkContext)
local Orientation=require(script.Parent.VerticalOrientation)
local Inline={}
local fields={'BidiPositions','BidiParagraph','BidiFirst','BidiLast','BidiGap','BidiLevel','BidiDirection','BidiOverride','BidiGapRect','BidiJoined','NativeBidiForced'}
function Inline.copy(owner: any,target: any)
 for _,field in fields do target[field]=owner[field]end
end
local controls={LRE=true,RLE=true,LRO=true,RLO=true,PDF=true,LRI=true,RLI=true,FSI=true,PDI=true}
local function needs(items: any,style: any): boolean
 if style.Direction=='rtl'or style.UnicodeBidi=='plaintext'or style.UnicodeBidi=='bidi-override'or style.UnicodeBidi=='isolate-override'then return true end
 for _,item in items do
  if item.Kind=='Float'then continue end
  if #Scope.path(item.Style and item.Style.BidiContext,style.Node)>0 then return true end
  for _,code in utf8.codes(item.Text or '')do Work.checkpoint();local class=Class.get(code);if class=='R'or class=='AL'or controls[class]then return true end end
 end
 return false
end
function Inline.slice(owner: any,target: any,first: number,last: number)
 if not owner.BidiPositions then Inline.copy(owner,target);return end
 local positions={}
 for _,position in owner.BidiPositions do if position.FirstByte>=first and position.FirstByte<=last then
  table.insert(positions,{FirstByte=position.FirstByte-first+1,LastByte=math.min(position.LastByte,last)-first+1,Index=position.Index})
 end end
 target.BidiPositions=positions;target.BidiParagraph=owner.BidiParagraph
 target.BidiFirst=positions[1]and positions[1].Index;target.BidiLast=positions[#positions]and positions[#positions].Index
 target.BidiLevel,target.BidiDirection,target.BidiOverride=owner.BidiLevel,owner.BidiDirection,owner.BidiOverride
 target.NativeBidiForced=owner.NativeBidiForced
 target.BidiGap=if first==1 then owner.BidiGap else nil
end
-- Direction-only ASCII reflow changes parity, not logical word/source pieces.
-- Complex text, invisible controls and any actual re-splitting retain the full
-- tokenizer/regroup path. No GUI or source array is touched during preflight.
function Inline.refresh(items: any,style: any,axes: boolean?): (any?,any?)
 local inputs={}
 for _,item in items do
  if item.Kind~='Word'and item.Kind~='Space'and item.Kind~='Break'or item.SourceHiddenSpans or item.EmptyInline or not axes and item.Text and item.Text:find('[\128-\255]')then return nil,nil end
  local copy=table.clone(item);for _,field in fields do copy[field]=nil end;table.insert(inputs,copy)
  if axes and item.Kind=='Word'then
   if Orientation.mixed(item.Style or style)then
    local pieces=Orientation.parts(item.Text);if #pieces>1 then return nil,nil end
    local part=pieces[1];copy.VerticalOrientation=part and part.Mode;copy.VerticalAlternate=part and part.Alternate
   elseif item.VerticalSegmented then return nil,nil
   else copy.VerticalOrientation,copy.VerticalAlternate=nil,nil end
  end
 end
 local prepared,bidi=Inline.prepare(inputs,style)
 if #prepared~=#items then return nil,nil end
 for index,item in prepared do if item.Kind~=items[index].Kind or item.Text~=items[index].Text then return nil,nil end end
 return prepared,bidi
end
function Inline.prepare(items: any,style: any): (any,any?)
 if not needs(items,style)then return items,nil end
 local stream,map,records,paths={}, {}, {}, {}
 local active={};local count=0
 local rootMode=style.UnicodeBidi
 local rootUpright=(style.WritingMode=='vertical-rl'or style.WritingMode=='vertical-lr')and style.TextOrientation=='upright'
 local rootRTL=style.Direction=='rtl'and not rootUpright
 local rootOpen,rootClose='',''
 if rootMode=='bidi-override'or rootMode=='isolate-override'then rootOpen,rootClose=Scope.controls('bidi-override',rootRTL)end
 local function append(text: string,item: any?,gap: boolean?): any
  table.insert(stream,text);local positions={}
  for first,code in utf8.codes(text)do
   Work.checkpoint();count+=1;local last=(utf8.offset(text,2,first)or #text+1)-1
   map[count]={Item=item,FirstByte=first,LastByte=last,Gap=gap,Code=code}
   table.insert(positions,{FirstByte=first,LastByte=last,Index=count})
  end
  return positions
 end
 local function transition(path: any)
  local common=0
  while common<#active and common<#path and Scope.same(active[common+1],path[common+1])do common+=1 end
  for index=#active,common+1,-1 do local _,close=Scope.controls(active[index].Mode,active[index].Direction=='rtl');append(close)end
  for index=common+1,#path do local open=Scope.controls(path[index].Mode,path[index].Direction=='rtl');append(open)end
  active=path
 end
 local function pathFor(s: any): any
  if not paths[s]then paths[s]=Scope.path(s.BidiContext,style.Node)end
  return paths[s]
 end
 append(rootOpen)
 for _,item in items do
  -- The float's own paragraph belongs to its block contents. Its anchor has
  -- no bidi character or directional scope in the surrounding inline text.
  if item.Kind=='Float'then continue end
  local s=item.Style or style
  if item.Kind=='Break'then
   transition({});append(rootClose);records[item]={Positions=append('\n',item)};append(rootOpen)
  else
   local gap
   if item.SpaceBefore or item.AutoSpaceBefore then transition(pathFor(item.SpaceStyle or s));gap=append(' ',item,true)[1].Index end
   transition(pathFor(s))
   local text=if item.Kind=='Word'or item.Kind=='Space'then item.Text else utf8.char(0xfffc)
   local upright=(s.WritingMode=='vertical-rl'or s.WritingMode=='vertical-lr')and s.TextOrientation=='upright'
   if upright then append(utf8.char(0x202d))end
   records[item]={Positions=append(text,item),Gap=gap}
   if upright then append(utf8.char(0x202c))end
  end
 end
 transition({});append(rootClose)
 local resolved=Bidi.resolve(table.concat(stream),if rootUpright then 0 elseif rootMode=='plaintext'then nil elseif rootRTL then 1 else 0)
 local paragraphs,retained={},{}
 for _,paragraph in resolved.Paragraphs do
  -- Rendering needs the resolver's paragraph levels/classes, not a second
  -- retained DOM/source/codepoint map or full-paragraph visual order.
  local projection={InitialTypes=paragraph.InitialTypes,ResolvedLevels=paragraph.ResolvedLevels,ParagraphLevel=paragraph.ParagraphLevel,IndexOffset=paragraph.IndexOffset}
  table.insert(retained,projection)
  for index=1,#paragraph.Codes do paragraphs[paragraph.IndexOffset+index]=projection end
 end
 local out={}
 local function attach(piece: any,positions: any,gap: any?)
  local first=positions[1]and positions[1].Index
  local paragraph=first and paragraphs[first]
  for _,position in positions do position.Index-=paragraph.IndexOffset end
  piece.BidiPositions=positions;piece.BidiParagraph=paragraph
  piece.BidiFirst=positions[1]and positions[1].Index;piece.BidiLast=positions[#positions]and positions[#positions].Index
  piece.BidiGap=if gap and paragraph then gap-paragraph.IndexOffset else nil
  piece.BidiLevel=paragraph and paragraph.ResolvedLevels[piece.BidiFirst]or 0
  piece.BidiDirection=if piece.BidiLevel%2==1 then 'rtl'else 'ltr'
  table.insert(out,piece)
 end
 for _,item in items do
  Work.checkpoint();local record=records[item]
  if item.Kind=='Float'then table.insert(out,item);continue end
  if item.Kind~='Word'or item.EmptyInline then attach(item,record.Positions,record.Gap);continue end
  local sourcePositions=record.Positions;local parts={};local positionIndex=1
  for first,last in utf8.graphemes(item.Text)do
   Work.checkpoint()
   local positions,hidden,visible,level={}, {}, {}, nil
   local visibleBytes=0
   while sourcePositions[positionIndex]and sourcePositions[positionIndex].FirstByte<=last do
    local original=sourcePositions[positionIndex];local entry=map[original.Index];local class=Class.get(entry.Code)
    local paragraph=paragraphs[original.Index]
    if controls[class]then table.insert(hidden,entry)
    else
     local text=item.Text:sub(original.FirstByte,original.LastByte)
     local at=visibleBytes;visibleBytes+=#text
     table.insert(visible,text);table.insert(positions,{FirstByte=at+1,LastByte=at+#text,Index=original.Index})
     if class~='BN'then level=level or paragraph.ResolvedLevels[original.Index-paragraph.IndexOffset]end
    end
    positionIndex+=1
   end
   local text=table.concat(visible);level=level or 0
   local previous=parts[#parts]
   if previous and previous.Level==level and #hidden==0 and #previous.Hidden==0 then
    local shift=previous.Bytes;table.insert(previous.Pieces,text);previous.Bytes+=#text;previous.Last=last
    for _,position in positions do position.FirstByte+=shift;position.LastByte+=shift;table.insert(previous.Positions,position)end
   else table.insert(parts,{Pieces={text},Bytes=#text,First=first,Last=last,Level=level,Positions=positions,Hidden=hidden,HiddenIndex=hidden[1]and sourcePositions[positionIndex-1].Index})end
  end
  if #parts==0 then attach(item,sourcePositions,record.Gap);continue end
  for index,part in parts do
   part.Text=table.concat(part.Pieces);part.Pieces=nil
   local piece=table.clone(item);piece.Text=part.Text
   piece.SourceSpans=Source.slice(item.SourceSpans,part.First,part.Last)
   piece.SourceHiddenSpans={}
   for _,span in item.SourceHiddenSpans or {}do if span.Byte>=part.First-1 and span.Byte<=part.Last then
    local clone=table.clone(span);clone.Byte-=part.First-1;table.insert(piece.SourceHiddenSpans,clone)
   end end
   for _,entry in part.Hidden do
    for _,span in Source.slice(item.SourceSpans,entry.FirstByte,entry.LastByte)or {}do
     table.insert(piece.SourceHiddenSpans,{Node=span.Node,Start=span.Start,Finish=span.Finish,Byte=0,Text=utf8.char(entry.Code)})
    end
   end
   if #part.Hidden>0 then piece.SourceSpans=nil end
   if #piece.SourceHiddenSpans==0 then piece.SourceHiddenSpans=nil end
   piece.SoftHyphens={};for at,source in item.SoftHyphens or {}do if at>=part.First-1 and at<=part.Last then piece.SoftHyphens[at-part.First+1]=source end end
   if not next(piece.SoftHyphens)then piece.SoftHyphens=nil end
   piece.SpaceBefore=index==1 and item.SpaceBefore;piece.AutoSpaceBefore=index==1 and item.AutoSpaceBefore
   piece.SpaceStyle=if index==1 then item.SpaceStyle else nil;piece.SourceGap=if index==1 then item.SourceGap else nil
   piece.SoftBefore=index==1 and item.SoftBefore
   -- A bidi boundary is not a CSS word-break opportunity.
   piece.BidiJoined=index>1
   if #part.Positions==0 then
    part.Positions={{FirstByte=1,LastByte=0,Index=part.HiddenIndex}}
   end
   attach(piece,part.Positions,if index==1 then record.Gap else nil)
   piece.BidiLevel=part.Level;piece.BidiDirection=if part.Level%2==1 then 'rtl'else 'ltr'
   local odd=piece.BidiDirection=='rtl';local strong,forced=false,false
   for _,code in utf8.codes(piece.Text)do local kind=Class.get(code)
    if kind=='L'then strong=true;forced=forced or odd
    elseif kind=='R'or kind=='AL'then strong=true;forced=forced or not odd
    elseif kind=='EN'or kind=='AN'then strong=true;forced=forced or odd end
   end
   piece.NativeBidiForced=forced or odd and not strong
  end
 end
 return out,{Paragraphs=retained}
end
return Inline
