--!strict
-- Bounded CSS counter parser, scope stack and formatter for generated content.
local Counters = {}
local CounterStyles=require(script.Parent.CounterStyles)
local Syntax=require(script.Parent.Syntax)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local ROMAN={{1000,"M"},{900,"CM"},{500,"D"},{400,"CD"},{100,"C"},{90,"XC"},{50,"L"},{40,"XL"},{10,"X"},{9,"IX"},{5,"V"},{4,"IV"},{1,"I"}}

local function identifier(value: string): boolean
	return (value:match("^[%a_][%w_%-]*$")~=nil or value:match("^%-[%a_%-][%w_%-]*$")~=nil) and not({none=true,inherit=true,initial=true,unset=true,revert=true,["revert-layer"]=true,default=true})[value:lower()]
end

function Counters.parse(value: string,defaultValue: number,allowReversed: boolean?): any?
	if value:lower()=="none" then return {} end
	local tokens,cursor={},1;while cursor<=#value do local token,after=Syntax.scan(value,cursor,' \t\r\n');cursor=after;if token~=''then table.insert(tokens,token)end end
	local result,index={},1
	while index<=#tokens do
		local name=tokens[index];local reversed=allowReversed and name:match('^[Rr][Ee][Vv][Ee][Rr][Ss][Ee][Dd]%(%s*([%a_%-][%w_%-]*)%s*%)$')
		if reversed then name=reversed end
		if not identifier(name) then return nil end
		index+=1
		local number,automatic=defaultValue,reversed~=nil
		if tokens[index] and tokens[index]:match("^[%+%-]?%d+$") then
			number=tonumber(tokens[index]) :: number
			automatic=false
			if math.abs(number)>2147483647 then return nil end
			index+=1
		end
		table.insert(result,{Name=name,Value=number,Reversed=reversed~=nil,Automatic=automatic})
		if #result>16 then return nil end
	end
	return if #result>0 then result else nil
end

function Counters.content(source: string,index: number): (any?,number?)
 local opening=source:find('(',index,true);if not opening then return nil,nil end
 local kind=source:sub(index,opening-1):lower();if kind~='counter'and kind~='counters'then return nil,nil end
 local body,finish,closing=Syntax.scan(source,opening+1,')');if closing~=')'then return nil,nil end
 local args,cursor={},1
 while cursor<=#body do local arg,after,comma=Syntax.scan(body,cursor,',');cursor=after;table.insert(args,arg:match('^%s*(.-)%s*$'));if comma==','and cursor>#body then return nil,nil end end
 local name=args[1];if not name or not identifier(name)then return nil,nil end
 local expected=if kind=='counter'then 1 else 2
 if #args<expected or #args>expected+1 then return nil,nil end
 local separator=if kind=='counters'then CounterStyles.string(args[2])else nil
 if kind=='counters'and separator==nil then return nil,nil end
 local style=if args[expected+1]then CounterStyles.value(args[expected+1],false)else 'decimal';if style==nil then return nil,nil end
 return {Kind=kind,Name=name,Separator=separator,Style=style},finish
end

function Counters.new(registry: any?,styleFor: any?): any
 return {Depth=0,Values={},Registry=registry,StyleFor=styleFor}
end
local function integer(source)
 local raw=source and source:match('^[ \t\n\r\f]*([+-]?%d+)');local n=raw and tonumber(raw)
 return if n then math.clamp(n,-2147483647,2147483647)else nil
end
local function reversedCount(state,node,name)
 local total,last,done=0,0,false
 local function accumulate(style,candidate)
  local increment,explicit=0,false
  for _,entry in style and style.CounterIncrement or{}do if entry.Name==name then increment+=entry.Value;explicit=true end end
  if name=='list-item'and not explicit and(if style then style.ListItem else candidate and candidate.Name=='li')then increment=-1 end
  if increment~=0 then last=-increment end
  local set
  for _,entry in style and style.CounterSet or{}do if entry.Name==name then set=entry.Value end end
  if name=='list-item'and candidate and candidate.Name=='li'and not(style and style.CounterSetSpecified)then set=integer(candidate.Attributes.value)or set end
  if set then total+=set;done=true else total-=increment end
 end
 local function resets(style,candidate)
  for _,entry in style and style.CounterReset or{}do if entry.Name==name then return true end end
  return name=='list-item'and(candidate.Name=='ol'or candidate.Name=='ul'or candidate.Name=='menu')and not(style and style.CounterResetSpecified)
 end
 local visit
 local function pseudo(candidate,style,kind)
  local value=state.PseudoFor and state.PseudoFor(candidate,style,kind)
  local content=value and value.GeneratedContent
  local box=content and(content.Mode~='none'and(kind=='marker'and style and style.ListItem or #content>0))
  if value and not value.Hidden and box then
   for _,entry in value.CounterReset or{}do if entry.Name==name then return true end end
   accumulate(value,nil)
  end
  return false
 end
 visit=function(candidate,origin)
  if done or candidate.Kind~='Element'then return false end
  local style=state.StyleFor and state.StyleFor(candidate)or nil
  if style and(style.Hidden or style.Display=='none')then return false end
  -- An inner reset shields its full sibling scope. At the next parent level
  -- the originating counter resumes, just as during the ordinary flat walk.
  if not origin and resets(style,candidate)then return true end
  accumulate(style,candidate)
  local blocked=false
  if not done then blocked=pseudo(candidate,style,'marker');if not blocked then blocked=pseudo(candidate,style,'before')end end
  if not done and not blocked then for _,child in ShadowTree.FlatChildren(candidate)do if visit(child,false)or done then break end end end
  if not done and not blocked then pseudo(candidate,style,'after')end
  return false
 end
 local siblings=ShadowTree.FlatChildren(ShadowTree.FlatParent(node)or{Children={node}})
 local started=false
 for _,candidate in siblings do
  if candidate==node then started=true end
  if started and(visit(candidate,candidate==node)or done)then break end
 end
 return math.clamp(total+last,-2147483647,2147483647)
end

local function reset(state,name,value,reversed,nativeOwner)
 local stack=state.Values[name]or{};state.Values[name]=stack
 if #stack>0 and stack[#stack].Owner==state.Depth-1 then table.remove(stack)end
 table.insert(stack,{Owner=state.Depth-1,Value=value,Reversed=reversed==true,NativeOwner=nativeOwner})
end
function Counters.enter(state: any,style: any,node: any?)
	state.Depth+=1
	node=node or style.Node
	local real=node and not style.PseudoElement
	if real and(node.Name=='ol'or node.Name=='ul'or node.Name=='menu')and not style.CounterResetSpecified then
		local reversed=node.Name=='ol'and node.Attributes.reversed~=nil
		local first=if node.Name=='ol'then integer(node.Attributes.start)else nil
		if first==nil then first=if reversed then reversedCount(state,node,'list-item')-1 else 1 end
		reset(state,'list-item',first+(if reversed then 1 else-1),reversed,node)
	end
	for _,entry in style.CounterReset or {} do
		-- An instance scopes following siblings as well as descendants. A reset
		-- on a later sibling replaces that instance; an ancestor stays nested.
		reset(state,entry.Name,if entry.Automatic and node then reversedCount(state,node,entry.Name)else entry.Value,entry.Reversed)
	end
	local listIncrement=false
	for _,entry in style.CounterIncrement or {} do
		if entry.Name=='list-item'then listIncrement=true end
		local stack=state.Values[entry.Name] or {};state.Values[entry.Name]=stack
		if #stack==0 then table.insert(stack,{Owner=state.Depth-1,Value=entry.Value})
		else stack[#stack].Value=math.clamp(stack[#stack].Value+entry.Value,-2147483647,2147483647);stack[#stack].NativeOwner=nil end
	end
	if style.ListItem and not listIncrement then
		local stack=state.Values['list-item']or{};state.Values['list-item']=stack
		if #stack==0 then reset(state,'list-item',0,false);stack=state.Values['list-item']end
		stack[#stack].Value=math.clamp(stack[#stack].Value+(if stack[#stack].Reversed then-1 else 1),-2147483647,2147483647)
	end
	if real and style.ListItem and node.Name=='li'and not style.CounterSetSpecified then
		local value=integer(node.Attributes.value);if value then local stack=state.Values['list-item'];if stack and #stack>0 then stack[#stack].Value=value end end
	end
	for _,entry in style.CounterSet or {} do
		local stack=state.Values[entry.Name]or{};state.Values[entry.Name]=stack
		if #stack==0 then table.insert(stack,{Owner=state.Depth-1,Value=entry.Value})else stack[#stack].Value=entry.Value;stack[#stack].NativeOwner=nil end
	end
end

function Counters.markerNumber(state:any,node:any,style:any):number?
	-- Native HTML marker ordinals predate the unified CSS list-item counter.
	-- Keep ordinary ol/reversed markers consistent with HTML and Chromium,
	-- while authored counters and content:counter(...) use the CSS algorithm.
	local stack=state.Values['list-item'];local current=stack and stack[#stack]
	local owner=current and current.NativeOwner
	if not owner or owner.Name~='ol' or not node or node.Kind~='Element' then return nil end
	state.NativeOrdinals=state.NativeOrdinals or{}
	local values=state.NativeOrdinals[owner]
	if not values then
		local items={};local function visit(candidate)
			if candidate.Kind~='Element'then return end
			local ownStyle=state.StyleFor and state.StyleFor(candidate)
			if ownStyle and(ownStyle.Hidden or ownStyle.Display=='none')then return end
			if candidate.Name=='ol'or candidate.Name=='ul'or candidate.Name=='menu'then return end
			if (ownStyle and ownStyle.ListItem)or not ownStyle and candidate.Name=='li'then table.insert(items,{Node=candidate,Style=ownStyle})end
			for _,child in ShadowTree.FlatChildren(candidate)do visit(child)end
		end
		for _,child in ShadowTree.FlatChildren(owner)do visit(child)end
		local reversed=owner.Attributes.reversed~=nil;local first=integer(owner.Attributes.start)
		if first==nil then first=1;if reversed then first=0;for _,entry in items do if entry.Node.Name=='li'then first+=1 end end end end
		values={};for _,entry in items do
			local explicit=if entry.Node.Name=='li'and not(entry.Style and entry.Style.CounterSetSpecified)then integer(entry.Node.Attributes.value)else nil
			if explicit~=nil then first=explicit end
			values[entry.Node]=first;first=math.clamp(first+(if reversed then-1 else 1),-2147483647,2147483647)
		end
		state.NativeOrdinals[owner]=values
	end
	return values[node]
end

function Counters.value(state:any,name:string):number
	local stack=state.Values[name];return if stack and #stack>0 then stack[#stack].Value else 0
end

function Counters.leave(state: any)
	for name,stack in state.Values do
		while #stack>0 and stack[#stack].Owner==state.Depth do table.remove(stack) end
		if #stack==0 then state.Values[name]=nil end
	end
	state.Depth-=1
end

function Counters.format(number: number,style: string): string
	if style=="decimal-leading-zero" and number>=0 and number<10 then return "0"..tostring(number) end
	if (style=="lower-alpha" or style=="upper-alpha") and number>=1 then
		local result="";local base=if style=="lower-alpha" then 97 else 65
		repeat number-=1;result=string.char(base+number%26)..result;number=math.floor(number/26) until number==0
		return result
	end
	if (style=="lower-roman" or style=="upper-roman") and number>=1 and number<=3999 then
		local parts={};for _,pair in ROMAN do while number>=pair[1] do table.insert(parts,pair[2]);number-=pair[1] end end
		local result=table.concat(parts);return if style=="lower-roman" then result:lower() else result
	end
	return tostring(number)
end

function Counters.render(state: any,part: any): string
	local stack=state.Values[part.Name] or {}
	if #stack==0 then reset(state,part.Name,0,false);stack=state.Values[part.Name]end
	if part.Kind=="counter" then return Counters.formatRegistry(state.Registry,if #stack>0 then stack[#stack].Value else 0,part.Style) end
	local values={}
	for _,entry in stack do table.insert(values,Counters.formatRegistry(state.Registry,entry.Value,part.Style)) end
	if #values==0 then table.insert(values,Counters.formatRegistry(state.Registry,0,part.Style)) end
	return table.concat(values,part.Separator)
end

function Counters.formatRegistry(registry:any,number:number,style:any,marker:boolean?):string
	return CounterStyles.format(registry,number,style,marker,Counters.format)
end

return Counters
