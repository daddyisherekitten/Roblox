--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- HTML text-control algorithms, separated from document Range/Selection.
local VM=require(script.Parent.VM)
local Strings=require(script.Parent.Strings)
local Native=require(script.Parent.Parent.Controls.TextSelection)
local API={}
local function uint(value)
	local n=VM.number(value)
	if n~=n or n==math.huge or n==-math.huge or n==0 then return 0 end
	return (if n<0 then math.ceil(n)else math.floor(n))%4294967296
end
local function argument(args,index)return if args[index]==nil then VM.Undefined else args[index]end
function API.new(context)
	local host=context.Host
	local function fail(name,message)
		VM.throw(if host.DOMException and name~="TypeError"and name~="RangeError"then host.DOMException(message,name)else VM.error(name,message))
	end
	local stringValue=host.ToString or VM.string
	local queued=setmetatable({},{__mode="k"})
	local callbacks=setmetatable({},{__mode="k"})
	local methods={}
	local alive=true
	local result={}
	local function emit(node,name)
		if not alive or not context.Alive()then return end
		local options={Bubbles=true,Cancelable=false}
		if host.EventDispatch then host.EventDispatch(node,name,{isTrusted=true},options)
		elseif host.Events then host.Events:Emit(node,name,{isTrusted=true},options)end
	end
	local function task(callback)
		if host.QueueTask then host.QueueTask(function()if alive and context.Alive()then callback()end end)
		elseif host.QueueSelectionTask then host.QueueSelectionTask(callback)end
	end
	function result:Bind(node,c)
		if callbacks[c]then return end
		local fn=function(_,selectEvent)
			if not alive then return end
			if not queued[node]then
				queued[node]=true
				task(function()queued[node]=nil;emit(node,"selectionchange")end)
			end
			if selectEvent then task(function()emit(node,"select")end)end
		end
		callbacks[c]=fn;c.SelectionChanged=fn
	end
	function result:Unbind(c)
		local fn=callbacks[c]
		if fn and c.SelectionChanged==fn then c.SelectionChanged=nil end
		callbacks[c]=nil
	end
	local function current(node)
		local c=context.Record(node);Native.ensure(c);Native.valueChanged(c,false)
		-- Signal callbacks normally keep this state current. An input listener can
		-- read synchronously before the deferred coalesced native notification.
		if c.Focused then Native.read(c)end
		return c
	end
	local function requireState(node)
		if not Native.applies(node)then fail("InvalidStateError","This input type does not support text selection")end
		return current(node)
	end
	local function set(node,c,start,finish,direction)
		Native.set(c,start,finish,direction,true)
		if host.SetControlSelection then host.SetControlSelection(node,c)else Native.paint(c)end
	end
	function result:Get(node,key)
		if (ElementNames.htmlName(node)~="input"and ElementNames.htmlName(node)~="textarea")or(key~="selectionStart"and key~="selectionEnd"and key~="selectionDirection"and key~="textLength")then return false end
		if key=="textLength"then return if ElementNames.htmlName(node)=="textarea"then true else false,if ElementNames.htmlName(node)=="textarea"then Strings.length(context.Record(node).Value)else nil end
		if not Native.applies(node)then return true,VM.Null end
		local c=current(node)
		return true,if key=="selectionStart"then c.SelectionStart elseif key=="selectionEnd"then c.SelectionEnd else c.SelectionDirection
	end
	function result:Set(node,key,newValue)
		if (ElementNames.htmlName(node)~="input"and ElementNames.htmlName(node)~="textarea")or(key~="selectionStart"and key~="selectionEnd"and key~="selectionDirection")then return false end
		-- Nullable WebIDL setters convert first, including on unsupported inputs.
		local converted=if newValue==VM.Null or newValue==VM.Undefined then (if key=="selectionDirection"then "none"else 0)
			elseif key=="selectionDirection"then stringValue(newValue)else uint(newValue)
		local c=requireState(node)
		if key=="selectionStart"then set(node,c,converted,math.max(converted,c.SelectionEnd),c.SelectionDirection)
		elseif key=="selectionEnd"then set(node,c,c.SelectionStart,converted,c.SelectionDirection)
		else set(node,c,c.SelectionStart,c.SelectionEnd,converted)end
		return true
	end
	local function receiver(node,target)
		if not alive or not context.Alive()then fail("InvalidStateError","This document has been disposed")end
		if target==nil then return node end -- Data-only DOM adapter calls.
		local other=if type(target)=="table"then target.DOMNode else nil
		if not other or ElementNames.htmlName(other)~=ElementNames.htmlName(node) or (other.NamespaceURI and other.NamespaceURI~="http://www.w3.org/1999/xhtml")
			or(context.Wrap and context.Wrap(other)~=target)then fail("TypeError","Incompatible text control receiver")end
		return other
	end
	local function method(node,key)
		if ElementNames.htmlName(node)~="input"and ElementNames.htmlName(node)~="textarea"then return nil end
		if key=="select"then return function(_,target)
			local actual=receiver(node,target)
			if not Native.selectable(actual)then return VM.Undefined end
			local c=current(actual);set(actual,c,0,math.huge,"none")
			return VM.Undefined
		end
		elseif key=="setSelectionRange"then return function(args,target)
			local actual=receiver(node,target)
			if #args<2 then fail("TypeError","setSelectionRange requires start and end")end
			local start,finish=uint(argument(args,1)),uint(argument(args,2))
			local direction=if args[3]==nil or args[3]==VM.Undefined then "none"else stringValue(args[3])
			local c=requireState(actual);set(actual,c,start,finish,direction)
			return VM.Undefined
		end
		elseif key=="setRangeText"then return function(args,target)
			local actual=receiver(node,target)
			if #args<1 or #args==2 then fail("TypeError","setRangeText requires one argument or at least three arguments")end
			local replacement=stringValue(argument(args,1))
			local start,finish,mode
			if #args>1 then
				start,finish=uint(argument(args,2)),uint(argument(args,3))
				mode=if args[4]==nil or args[4]==VM.Undefined then "preserve"else stringValue(args[4])
				if mode~="select"and mode~="start"and mode~="end"and mode~="preserve"then fail("TypeError","Invalid SelectionMode")end
			else mode="preserve"end
			local c=requireState(actual);c.DOMDirtyValue=true
			if #replacement>65536 then fail("RangeError","Control value budget exceeded")end
			if #args==1 then start,finish=c.SelectionStart,c.SelectionEnd end
			if start>finish then fail("IndexSizeError","The start offset is larger than the end offset")end
			local units=Strings.units(c.Value);start,finish=math.min(start,#units),math.min(finish,#units)
			local oldStart,oldEnd=c.SelectionStart,c.SelectionEnd
			local replacementUnits=Strings.units(replacement);local nextUnits={}
			for i=1,start do table.insert(nextUnits,units[i])end
			for _,unit in replacementUnits do table.insert(nextUnits,unit)end
			for i=finish+1,#units do table.insert(nextUnits,units[i])end
			local newValue=Strings.fromUnits(nextUnits)
			if #newValue>65536 then fail("RangeError","Control value budget exceeded")end
			context.SetValue(actual,newValue,false)
			local newEnd=start+#replacementUnits
			if mode=="select"then oldStart,oldEnd=start,newEnd
			elseif mode=="start"then oldStart,oldEnd=start,start
			elseif mode=="end"then oldStart,oldEnd=newEnd,newEnd
			else
				-- Existing browsers preserve offsets for either overload. The draft
				-- now limits these delta steps to the one-argument overload; retain
				-- the interoperable browser behavior explicitly in this profile.
				local delta=#replacementUnits-(finish-start)
				if oldStart>finish then oldStart+=delta elseif oldStart>start then oldStart=start end
				if oldEnd>finish then oldEnd+=delta elseif oldEnd>start then oldEnd=newEnd end
			end
			set(actual,c,oldStart,oldEnd,"none")
			return VM.Undefined
		end end
		return nil
	end
	function result:Method(node,key)
		if key~="select"and key~="setSelectionRange"and key~="setRangeText"then return nil end
		local entry=methods[node]
		if entry and entry[key]then return entry[key]end
		local value=method(node,key)
		if value and host.GetVM then
			local vm=host.GetVM()
			if vm then
				value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=value}
				vm.DefineProperty(value,"name",vm.Object({value=key,writable=false,enumerable=false,configurable=true},VM.Null))
				vm.DefineProperty(value,"length",vm.Object({value=if key=="setSelectionRange"then 2 elseif key=="setRangeText"then 1 else 0,writable=false,enumerable=false,configurable=true},VM.Null))
			end
		end
		if value then if not entry then entry={};methods[node]=entry end;entry[key]=value end
		return value
	end
	function result:Destroy()
		alive=false
		for c,fn in callbacks do if c.SelectionChanged==fn then c.SelectionChanged=nil end end
		table.clear(callbacks);table.clear(queued);table.clear(methods)
	end
	function result:Text(node)
		if not Native.selectable(node)then return nil end
		local c=current(node);local source=if c.Type=='number'then c.EditText or c.Value or ''else c.Value or ''
		local first,last=c.SelectionStart or 0,c.SelectionEnd or 0;local output,at={},0
		do
			local valid=pcall(function()
				for begin,finish in utf8.graphemes(source)do
					local text=source:sub(begin,finish)
					if at>=first and at<last then table.insert(output,if c.Type=='password'then '•'else text)end
					at+=Strings.length(text)
				end
			end)
			if valid then return table.concat(output)end
			-- Exact DOM strings may contain unpaired UTF-16 surrogates, which
			-- native grapheme iteration rejects. Keep those code units exact.
			table.clear(output);at=0
		end
		for code in Strings.codes(source)do
			if at>=first and at<last then table.insert(output,if c.Type=='password'then '•'else Strings.fromUnits(if code>0xffff then {0xd800+math.floor((code-0x10000)/1024),0xdc00+(code-0x10000)%1024}else {code}))end
			at+=if code>0xffff then 2 else 1
		end
		return table.concat(output)
	end
	return result
end
return API
