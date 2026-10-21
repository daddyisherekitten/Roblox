--!strict
-- On-demand logical text navigation. The renderer supplies visual line/Bidi
-- boundaries; this module keeps UTF-16 DOM positions and grapheme boundaries.
local Strings=require(script.Parent.Strings)
local Unicode=require(script.Parent.RegExpUnicode)
local BidiClass=require(script.Parent.Parent.Layout.BidiClass)
local Navigation={}
local BLOCK={p=true,div=true,section=true,article=true,header=true,footer=true,main=true,aside=true,nav=true,
 h1=true,h2=true,h3=true,h4=true,h5=true,h6=true,li=true,ul=true,ol=true,blockquote=true,pre=true,tr=true}
local function includes(ranges,code)
 if not ranges then return false end
 local left,right=1,#ranges/2
 while left<=right do local middle=math.floor((left+right)/2);local at=middle*2-1
  if code<ranges[at]then right=middle-1 elseif code>ranges[at+1]then left=middle+1 else return true end
 end
 return false
end
local function word(code)
 return code~=nil and(code==95 or code>=48 and code<=57 or includes(Unicode.Properties['binary=Alphabetic'],code)
  or includes(Unicode.Properties['gc=M'],code)or includes(Unicode.Properties['gc=Nd'],code))
end
local function space(code)return code~=nil and(code==9 or code==10 or code==13 or code==32 or code==160 or includes(Unicode.Properties['binary=White_Space'],code))end
function Navigation.new(vm: any,options: any): any
 local api={};local ranges=options.Ranges
 local function snapshot(root)
  local units,nodes,runs,paragraphs={},{},{},{};local size,count=0,0
  local function addBreak(amount)
   if size==0 then return end
   local existing=0;local at=size;while at>0 and units[at]==10 do existing+=1;at-=1 end
   for _=existing+1,amount do table.insert(units,10);size+=1 end
  end
  local jobs={{Node=root,Exit=false}}
  while #jobs>0 do
   local job=table.remove(jobs);local node=job.Node
   if job.Exit then
    nodes[node].Finish=size
    if job.Block then table.insert(paragraphs,size);addBreak(if node.Name=='p'then 2 else 1)end
   else
    vm.Step();count+=1;if count>32768 then vm.Model.throw(vm.Model.error('RangeError','Selection navigation node budget exceeded'))end
    local style=options.StyleFor and options.StyleFor(node)
    local hidden=style and(style.Hidden or style.Visibility=='hidden'or style.Visibility=='collapse')
     or node.Kind=='Element'and(node.Name=='script'or node.Name=='style'or node.Name=='template')
    if hidden then nodes[node]={Start=size,Finish=size};continue end
    local block=node.Kind=='Element'and(if style then style.Display=='block'or style.Display=='flex'or style.Display=='grid'or style.Display=='table-row'else BLOCK[node.Name])
    if block then addBreak(if node.Name=='p'then 2 else 1);table.insert(paragraphs,size)end
    local entry={Start=size,Finish=size};nodes[node]=entry
    if node.Kind=='Text'or node.Kind=='CDATASection'then
     local text=Strings.units(node.Text or '');entry.Length=#text
     if #text>0 then table.insert(runs,{Node=node,Start=size,Finish=size+#text})end
     for _,unit in text do table.insert(units,unit)end;size+=#text;entry.Finish=size
    elseif node.Kind=='Element'and node.Name=='br'then addBreak(1);entry.Finish=size
    else
     table.insert(jobs,{Node=node,Exit=true,Block=block})
     for i=#(node.Children or {}),1,-1 do table.insert(jobs,{Node=node.Children[i],Exit=false})end
    end
    if size>1048576 then vm.Model.throw(vm.Model.error('RangeError','Selection navigation text budget exceeded'))end
   end
  end
  -- Trailing layout separators are not selectable characters.
  local finish=if #runs>0 then runs[#runs].Finish else 0
  while #units>finish do table.remove(units)end
  local data={Units=units,Nodes=nodes,Runs=runs,Paragraphs=paragraphs,Length=#units}
  function data:Offset(node,offset)
   local entry=self.Nodes[node];if not entry then return nil end
   if entry.Length then return entry.Start+math.clamp(offset,0,entry.Length)end
   local child=(node.Children or {})[offset+1];return if child and self.Nodes[child]then self.Nodes[child].Start else entry.Finish
  end
  function data:Point(offset,forward)
   offset=math.clamp(offset,0,self.Length)
   local previous=nil
   for _,run in self.Runs do vm.Step()
    if offset<run.Start then
     if previous then return previous.Node,previous.Finish-previous.Start end
     return run.Node,0
    end
    if offset<run.Finish or offset==run.Finish and not forward then return run.Node,offset-run.Start end
    previous=run
   end
   return if previous then previous.Node else nil,if previous then previous.Finish-previous.Start else 0
  end
  return data
 end
 local function codeAt(units,index)
  local code=units[index];local after=units[index+1]
  if code and code>=0xd800 and code<=0xdbff and after and after>=0xdc00 and after<=0xdfff then return 0x10000+(code-0xd800)*1024+after-0xdc00 end
  return code
 end
 local function character(data,at,forward)
  local source=Strings.fromUnits(data.Units);local boundaries={0};local offset=0
  local valid,result=pcall(function()
   for first,last in utf8.graphemes(source)do vm.Step();offset+=Strings.length(source:sub(first,last));table.insert(boundaries,offset)end
  end)
  if not valid then
   -- Native grapheme iteration does not accept lone surrogate code units.
   -- Treat such units independently while preserving paired supplementary text.
   boundaries={0};offset=0
   while offset<data.Length do vm.Step();local code=codeAt(data.Units,offset+1);offset+=if code and code>0xffff then 2 else 1;table.insert(boundaries,offset)end
  end
  if forward then for _,boundary in boundaries do if boundary>at then return boundary end end;return data.Length end
  for index=#boundaries,1,-1 do if boundaries[index]<at then return boundaries[index]end end;return 0
 end
 local function boundary(data,at,forward,granularity)
  local units=data.Units;local length=data.Length
  if granularity=='documentboundary'then return if forward then length else 0 end
  if granularity=='character'then return character(data,at,forward)end
  if granularity=='word'then
   if forward then
    local cursor=at
    local kind=word(codeAt(units,cursor+1))
    while cursor<length and not space(units[cursor+1])and word(codeAt(units,cursor+1))==kind do vm.Step();cursor+=if codeAt(units,cursor+1)>0xffff then 2 else 1 end
    while cursor<length and space(units[cursor+1])do vm.Step();cursor+=1 end
    return cursor
   end
   local cursor=at
   while cursor>0 and space(units[cursor])do vm.Step();cursor-=1 end
   local kind=word(units[cursor])
   while cursor>0 and not space(units[cursor])and word(units[cursor])==kind do vm.Step();cursor-=1 end
   if cursor>0 and units[cursor]>=0xd800 and units[cursor]<=0xdbff then cursor-=1 end
   return cursor
  end
  if granularity=='sentence'or granularity=='sentenceboundary'then
   if forward then
    local cursor=at
    while cursor<length do vm.Step();cursor+=1;local unit=units[cursor];if unit==46 or unit==33 or unit==63 or unit==10 or unit==0x3002 then break end end
    if granularity=='sentence'then while cursor<length and space(units[cursor+1])do vm.Step();cursor+=1 end end
    return cursor
   end
   local cursor=at;while cursor>0 and space(units[cursor])do vm.Step();cursor-=1 end
   if cursor>0 then cursor-=1 end
   while cursor>0 do vm.Step();local unit=units[cursor];if unit==46 or unit==33 or unit==63 or unit==10 or unit==0x3002 then break end;cursor-=1 end
   while cursor<at and space(units[cursor+1])do vm.Step();cursor+=1 end
   return cursor
  end
  -- Visual line operations use renderer boundaries when available. In a
  -- detached/nonvisual document explicit newlines still define logical lines.
  local cursor=at
  if forward then
   if granularity=='line'or granularity=='paragraph'then
    if units[cursor+1]==10 then while cursor<length and units[cursor+1]==10 do vm.Step();cursor+=1 end end
   end
   while cursor<length and units[cursor+1]~=10 do vm.Step();cursor+=1 end
  else
   if granularity=='line'or granularity=='paragraph'then while cursor>0 and units[cursor]==10 do vm.Step();cursor-=1 end end
   while cursor>0 and units[cursor]~=10 do vm.Step();cursor-=1 end
  end
  return cursor
 end
 function api:Move(node,offset,forward,granularity)
  if options.MoveVisual and(granularity=='line'or granularity=='lineboundary')then
   local nextNode,nextOffset=options.MoveVisual(node,offset,forward,granularity)
   if nextNode then return nextNode,nextOffset end
  end
  local data=snapshot(ranges.Root(node));local at=data:Offset(node,offset)
  if at==nil or #data.Runs==0 then return node,offset end
  local target=boundary(data,at,forward,granularity);local nextNode,nextOffset=data:Point(target,forward)
  return nextNode or node,nextOffset
 end
 function api:Direction(node)
  while node do
   local declared=node.Attributes and node.Attributes.dir and node.Attributes.dir:lower()
   if declared=='auto'then
    local jobs={node};local count=0
    while #jobs>0 do
     local entry=table.remove(jobs);vm.Step();count+=1
     if count>32768 then vm.Model.throw(vm.Model.error('RangeError','Selection direction node budget exceeded'))end
     if entry.Kind=='Text'or entry.Kind=='CDATASection'then
      for code in Strings.codes(entry.Text or '')do vm.Step();local class=BidiClass.get(code)
       if class=='L'then return 'ltr'elseif class=='R'or class=='AL'then return 'rtl'end
      end
     elseif not(entry.Kind=='Element'and(entry.Name=='script'or entry.Name=='style'or entry.Name=='textarea'or entry.Name=='bdi'or entry~=node and entry.Attributes and entry.Attributes.dir))then
      for i=#(entry.Children or{}),1,-1 do table.insert(jobs,entry.Children[i])end
     end
    end
   end
   local style=options.StyleFor and options.StyleFor(node)
   if style and style.Direction then return style.Direction end
   if declared=='ltr'or declared=='rtl'then return declared end
   node=node.Parent
  end
  return 'ltr'
 end
 function api:Destroy()table.clear(options)end
 return api
end
return Navigation
