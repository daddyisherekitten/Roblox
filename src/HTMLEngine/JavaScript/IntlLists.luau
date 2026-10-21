--!strict
-- ECMA-402 ListFormat uses the realm's canonicalization and locale negotiation.
local Data=require(script.Parent.IntlListData)
local IntlLists={}
function IntlLists.install(vm: any,namespace: any,context: any): any
	local VM=vm.Model;local U=VM.Undefined
	local states=setmetatable({},{__mode="kv"});local alive=true
	local function fail(name,message)VM.throw(VM.error(name,message))end
	local function def(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,VM.Null))end
	local function native(name,length,callback)
		local fn={Kind="native-function",Prototype=vm.Prototypes.Function,Values={name=name,length=length},Call=function(args,receiver)
			assert(alive and vm.Alive,"Intl.ListFormat disposed");return callback(args,receiver)
		end};return fn
	end
	local proto=vm.Object({})
	local function method(name,length,callback)def(proto,name,{value=native(name,length,callback),writable=true,configurable=true})end
	local function state(receiver)local record=states[receiver];if not record then fail("TypeError","Intl.ListFormat requires a ListFormat receiver")end;return record end
	local function construct(args,newTarget)
		local requested=context.Locales(args[1] or U)
		local options=context.Options(args[2] or U)
		context.Choice(options,"localeMatcher",{"lookup","best fit"},"best fit")
		local locale=context.Resolve(requested)
		local kind=context.Choice(options,"type",{"conjunction","disjunction","unit"},"conjunction")
		local style=context.Choice(options,"style",{"long","short","narrow"},"long")
		local prototype=if newTarget then vm.Get(newTarget,"prototype") else proto
		if not vm.ObjectModel.IsObject(prototype) then prototype=proto end
		local value=vm.Object({},prototype)
		local record={Locale=locale,Type=kind,Style=style,Pattern=Data[if locale:sub(1,2)=="de" then "de" elseif locale=="en-GB"then "enGB"else "en"][kind][style]}
		value.IntlListFormatState=record;states[value]=record;return value
	end
	local ctor=native("ListFormat",0,function()fail("TypeError","Intl.ListFormat requires new")end)
	ctor.Construct=construct;def(ctor,"prototype",{value=proto});def(proto,"constructor",{value=ctor,writable=true,configurable=true})
	def(proto,vm.SymbolToStringTag,{value="Intl.ListFormat",configurable=true})
	def(namespace,"ListFormat",{value=ctor,writable=true,configurable=true})
	local function parts(record,input)
		local elements={};if input~=nil and input~=U then
			local nextValue,close=vm.Iterator(input)
			local ok,message=pcall(function()
				while true do
					vm.Step();local more,value=nextValue();if not more then break end
					if type(value)~="string" then fail("TypeError","List elements must be strings")end
					if #elements>=16384 then fail("RangeError","Intl list entry budget exceeded")end
					table.insert(elements,value)
				end
			end)
			if not ok then if close then pcall(close) end;error(message,0) end
		end
		local result,size={},0
		local function add(kind,value)
			if value=="" then return end
			size+=#value;if size>65536 then fail("RangeError","Intl list string budget exceeded")end
			local previous=result[#result]
			if kind=="literal" and previous and vm.Get(previous,"type")=="literal" then vm.Set(previous,"value",vm.Get(previous,"value")..value);return end
			table.insert(result,vm.Object({type=kind,value=value},nil,{"type","value"}))
		end
		for index,value in elements do
			if index>1 then add("literal",if #elements==2 then record.Pattern.Pair elseif index==#elements then record.Pattern.End else record.Pattern.Middle)end
			add("element",value)
		end
		return result
	end
	method("format",1,function(args,receiver)
		local output={};for _,part in parts(state(receiver),args[1])do table.insert(output,vm.Get(part,"value"))end;return table.concat(output)
	end)
	method("formatToParts",1,function(args,receiver)return vm.Array(parts(state(receiver),args[1]))end)
	method("resolvedOptions",0,function(_,receiver)local s=state(receiver);return vm.Object({locale=s.Locale,type=s.Type,style=s.Style},nil,{"locale","type","style"})end)
	def(ctor,"supportedLocalesOf",{value=native("supportedLocalesOf",1,function(args)
		local list=context.Locales(args[1] or U);local options=context.Options(args[2] or U)
		context.Choice(options,"localeMatcher",{"lookup","best fit"},"best fit")
		local result={};for _,tag in list do local language=context.Parse(tag).Language;if language=="en" or language=="de" then table.insert(result,tag) end end;return vm.Array(result)
	end),writable=true,configurable=true})
	return {Destroy=function()alive=false;table.clear(states)end}
end
return IntlLists
