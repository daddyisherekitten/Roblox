--!strict
-- Live DOM boundary points. Registrations are weak; native mutations adjust
-- points synchronously without calling author code or allocating observers.
local Strings=require(script.Parent.Strings)
local Ranges={}
local CD={Text=true,Comment=true,CDATASection=true,ProcessingInstruction=true}
local TYPES={Element=true,Text=true,Comment=true,Document=true,DocumentFragment=true,ShadowRoot=true,
	CDATASection=true,ProcessingInstruction=true,DocumentType=true,Attribute=true}
local CONSTANTS={START_TO_START=0,START_TO_END=1,END_TO_END=2,END_TO_START=3}

function Ranges.install(vm: any,globals: any,options: any): any
	local VM=assert(vm.Model,"Ranges require vm.Model");local U,N=VM.Undefined,VM.Null
	options=table.clone(options);local api={Alive=true};local retainedEstimate=0
	local live,statics=setmetatable({},{__mode="k"}),setmetatable({},{__mode="k"})
	local abstractProto=vm.Object({});local rangeProto,staticProto=vm.Object({},abstractProto),vm.Object({},abstractProto)
	local function check()assert(api.Alive and vm.Alive,"JavaScript ranges disposed")end
	local function step()check();vm.Step()end
	local function fail(name,message)
		VM.throw(if options.Events and name~="TypeError"and name~="RangeError"then options.Events:DOMException(message,name)else VM.error(name,message))
	end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,N))end
	local function native(name,arity,fn)
		local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end}
		define(value,"length",{value=arity,configurable=true});define(value,"name",{value=name,configurable=true});return value
	end
	local function method(name,arity,fn)define(rangeProto,name,{value=native(name,arity,fn),writable=true,enumerable=true,configurable=true})end
	local function required(args,count)if #args<count then fail("TypeError","Not enough arguments for Range method")end end
	local function state(value,abstract)
		check();if not live[value]and not(abstract and statics[value])then fail("TypeError","Incompatible Range receiver")end
		return value.RangeState
	end
	local function node(value)
		local raw=options.Unwrap(value);if not raw or not TYPES[raw.Kind]then fail("TypeError","Expected a Node")end;return raw
	end
	local function integer(value,modulus)
		value=vm.ToPrimitive(value,"number")
		if type(value)=="table"and(value.Kind=="symbol"or value.Kind=="bigint")then fail("TypeError","Cannot convert value to an unsigned integer")end
		local number=VM.number(value);if number~=number or number==0 or math.abs(number)==math.huge then return 0 end
		return(if number<0 then math.ceil(number)else math.floor(number))%modulus
	end
	local function root(value,charge)
		while value.Parent do if charge then step()end;value=value.Parent end;return value
	end
	local function contains(parent,value,charge)
		while value do if charge then step()end;if value==parent then return true end;value=value.Parent end;return false
	end
	local function index(value)return if value.Parent then assert(table.find(value.Parent.Children,value),"Inconsistent DOM parent")-1 else 0 end
	local function length(value)return if CD[value.Kind]then Strings.length(value.Text)elseif value.Kind=="Attribute"or value.Kind=="DocumentType"then 0 else #value.Children end
	local function compare(a,ao,b,bo,charge)
		if a==b then return if ao==bo then 0 elseif ao<bo then -1 else 1 end
		local left,right={},{};local current=a
		while current do if charge then step()end;table.insert(left,current);current=current.Parent end
		current=b;while current do if charge then step()end;table.insert(right,current);current=current.Parent end
		if left[#left]~=right[#right]then fail("WrongDocumentError","Boundary points have different roots")end
		local i,j=#left,#right
		while i>0 and j>0 and left[i]==right[j]do i-=1;j-=1 end
		if i==0 then return if index(right[j])<ao then 1 else -1 end
		if j==0 then return if index(left[i])<bo then -1 else 1 end
		return if index(left[i])<index(right[j])then -1 else 1
	end
	local function common(a,b)
		local ancestors={}
		while a do step();ancestors[a]=true;a=a.Parent end
		while b do step();if ancestors[b]then return b end;b=b.Parent end
		return nil
	end
	local function validPoint(value,offset)
		if value.Kind=="DocumentType"then fail("InvalidNodeTypeError","A doctype cannot be a Range boundary")end
		if offset>length(value)then fail("IndexSizeError","Range offset exceeds node length")end
	end
	local function changed(value,kind)if options.Changed then options.Changed(value,kind)end end
	local function assign(value,sn,so,en,eo)
		local entry=state(value);local differs=entry.StartNode~=sn or entry.StartOffset~=so or entry.EndNode~=en or entry.EndOffset~=eo
		entry.StartNode,entry.StartOffset,entry.EndNode,entry.EndOffset=sn,so,en,eo
		if differs then changed(value,"boundary")end
	end
	local function new(sn,so,en,eo,isStatic,prototype)
		check()
		-- Only retained ranges count against the private registry limit. Recount
		-- at the threshold on an author allocation, never in mutation hooks.
		if retainedEstimate>=4096 then
			local retained=0
			for _ in live do step();retained+=1 end
			for _ in statics do step();retained+=1 end
			retainedEstimate=retained
			if retainedEstimate>=4096 then fail("RangeError","DOM retained range budget exceeded")end
		end
		retainedEstimate+=1
		local value=vm.Object({},prototype or(if isStatic then staticProto else rangeProto));value.RangeBrand=true;value.RangeStatic=isStatic
		value.RangeState={StartNode=sn,StartOffset=so,EndNode=en,EndOffset=eo}
		(if isStatic then statics else live)[value]=true;return value
	end
	function api.State(value)return state(value)end
	function api.AbstractState(value)return state(value,true)end
	function api.IsRange(value)check();return live[value]==true end
	function api.New(sn,so,en,eo)
		if not sn then sn=node(options.Document)end;so=so or 0;en=en or sn;eo=eo or so
		validPoint(sn,so);validPoint(en,eo);if compare(sn,so,en,eo,true)>0 then fail("IndexSizeError","Range start follows end")end
		return new(sn,so,en,eo,false)
	end
	function api.NewStatic(entry,prototype)
		check();if entry.StartNode.Kind=="DocumentType"or entry.EndNode.Kind=="DocumentType"or entry.StartNode.Kind=="Attribute"or entry.EndNode.Kind=="Attribute"then fail("InvalidNodeTypeError","Invalid StaticRange container")end
		return new(entry.StartNode,entry.StartOffset,entry.EndNode,entry.EndOffset,true,prototype)
	end
	function api.Set(value,sn,so,en,eo)
		state(value);validPoint(sn,so);validPoint(en,eo);if compare(sn,so,en,eo,true)>0 then fail("IndexSizeError","Range start follows end")end;assign(value,sn,so,en,eo)
	end
	function api.SetStart(value,raw,offset)
		local entry=state(value);validPoint(raw,offset)
		local en,eo=entry.EndNode,entry.EndOffset
		if root(raw,true)~=root(entry.StartNode,true)or compare(raw,offset,en,eo,true)>0 then en,eo=raw,offset end
		assign(value,raw,offset,en,eo)
	end
	function api.SetEnd(value,raw,offset)
		local entry=state(value);validPoint(raw,offset)
		local sn,so=entry.StartNode,entry.StartOffset
		if root(raw,true)~=root(sn,true)or compare(raw,offset,sn,so,true)<0 then sn,so=raw,offset end
		assign(value,sn,so,raw,offset)
	end
	function api.Collapse(value,toStart)
		local entry=state(value);local raw,offset=if toStart then entry.StartNode else entry.EndNode,if toStart then entry.StartOffset else entry.EndOffset
		assign(value,raw,offset,raw,offset)
	end
	api.Root=function(value)return root(value,true)end
	api.Contains=function(parent,value)return contains(parent,value,true)end
	api.Compare=function(a,ao,b,bo)return compare(a,ao,b,bo,true)end
	api.Length=length;api.Index=index;api.CommonAncestor=common;api.Check=check
	local function accessor(proto,name,read)
		define(proto,name,{get=native("get "..name,0,function(_,receiver)return read(state(receiver,proto==abstractProto))end),enumerable=true,configurable=true})
	end
	accessor(abstractProto,"startContainer",function(entry)return options.Wrap(entry.StartNode)end)
	accessor(abstractProto,"startOffset",function(entry)return entry.StartOffset end)
	accessor(abstractProto,"endContainer",function(entry)return options.Wrap(entry.EndNode)end)
	accessor(abstractProto,"endOffset",function(entry)return entry.EndOffset end)
	accessor(abstractProto,"collapsed",function(entry)return entry.StartNode==entry.EndNode and entry.StartOffset==entry.EndOffset end)
	accessor(rangeProto,"commonAncestorContainer",function(entry)return options.Wrap(common(entry.StartNode,entry.EndNode))end)
	for name,setter in {setStart=api.SetStart,setEnd=api.SetEnd}do method(name,2,function(args,receiver)
		state(receiver);required(args,2);local raw=node(args[1]);local offset=integer(args[2],4294967296);setter(receiver,raw,offset);return U
	end)end
	for name,info in {setStartBefore={true,false},setStartAfter={true,true},setEndBefore={false,false},setEndAfter={false,true}}do method(name,1,function(args,receiver)
		state(receiver);required(args,1);local raw=node(args[1]);local parent=raw.Parent
		if not parent then fail("InvalidNodeTypeError","Boundary reference has no parent")end
		(if info[1]then api.SetStart else api.SetEnd)(receiver,parent,index(raw)+(if info[2]then 1 else 0));return U
	end)end
	method("collapse",0,function(args,receiver)api.Collapse(receiver,VM.truth(args[1]or U));return U end)
	method("selectNode",1,function(args,receiver)
		state(receiver);required(args,1);local raw=node(args[1]);if not raw.Parent then fail("InvalidNodeTypeError","Selected node has no parent")end
		local at=index(raw);assign(receiver,raw.Parent,at,raw.Parent,at+1);return U
	end)
	method("selectNodeContents",1,function(args,receiver)
		state(receiver);required(args,1);local raw=node(args[1]);validPoint(raw,0);assign(receiver,raw,0,raw,length(raw));return U
	end)
	method("compareBoundaryPoints",2,function(args,receiver)
		local entry=state(receiver);required(args,2);local how=integer(args[1],65536);local other=state(args[2])
		if how>3 then fail("NotSupportedError","Unknown Range comparison mode")end
		local an,ao=if how==1 or how==2 then entry.EndNode else entry.StartNode,if how==1 or how==2 then entry.EndOffset else entry.StartOffset
		local bn,bo=if how==2 or how==3 then other.EndNode else other.StartNode,if how==2 or how==3 then other.EndOffset else other.StartOffset
		return compare(an,ao,bn,bo,true)
	end)
	method("cloneRange",0,function(_,receiver)local entry=state(receiver);return new(entry.StartNode,entry.StartOffset,entry.EndNode,entry.EndOffset,false)end)
	method("detach",0,function(_,receiver)state(receiver);return U end)
	for name,inRange in {isPointInRange=true,comparePoint=false}do method(name,2,function(args,receiver)
		local entry=state(receiver);required(args,2);local raw=node(args[1]);local offset=integer(args[2],4294967296)
		if root(raw,true)~=root(entry.StartNode,true)then if inRange then return false else fail("WrongDocumentError","Point has a different root")end end
		validPoint(raw,offset)
		local position=if compare(raw,offset,entry.StartNode,entry.StartOffset,true)<0 then -1 elseif compare(raw,offset,entry.EndNode,entry.EndOffset,true)>0 then 1 else 0
		return if inRange then position==0 else position
	end)end
	method("intersectsNode",1,function(args,receiver)
		local entry=state(receiver);required(args,1);local raw=node(args[1]);if root(raw,true)~=root(entry.StartNode,true)then return false end
		if not raw.Parent then return true end;local at=index(raw)
		return compare(raw.Parent,at,entry.EndNode,entry.EndOffset,true)<0 and compare(raw.Parent,at+1,entry.StartNode,entry.StartOffset,true)>0
	end)
	local function slice(text,first,last)
		local units,result=Strings.units(text),{};for i=first+1,last do table.insert(result,units[i])end;return Strings.fromUnits(result)
	end
	local function stringify(value)
		local entry=state(value)
		if entry.StartNode==entry.EndNode and(entry.StartNode.Kind=="Text"or entry.StartNode.Kind=="CDATASection")then return slice(entry.StartNode.Text,entry.StartOffset,entry.EndOffset)end
		if entry.StartNode==entry.EndNode and entry.StartOffset==entry.EndOffset then return ""end
		local parts,size,pending={},0,{common(entry.StartNode,entry.EndNode)}
		local function emit(text)size+=#text;if size>1024*1024 then fail("RangeError","Range string budget exceeded")end;table.insert(parts,text)end
		while #pending>0 do
			step();local current=table.remove(pending)
			if current.Kind=="Text"or current.Kind=="CDATASection"then
				if current==entry.StartNode then emit(slice(current.Text,entry.StartOffset,length(current)))
				elseif current==entry.EndNode then emit(slice(current.Text,0,entry.EndOffset))
				elseif compare(entry.StartNode,entry.StartOffset,current,0,true)<0 and compare(current,length(current),entry.EndNode,entry.EndOffset,true)<0 then emit(current.Text)end
			end
			for i=#current.Children,1,-1 do table.insert(pending,current.Children[i])end
		end;return Strings.canonical(table.concat(parts))
	end
	method("toString",0,function(_,receiver)return stringify(receiver)end);api.Stringify=stringify
	for name,hook in {getClientRects="RangeRects",getBoundingClientRect="RangeBoundingRect"}do method(name,0,function(_,receiver)
		local entry=state(receiver);if not options[hook]then fail("NotSupportedError","Range geometry adapter unavailable")end;return options[hook](entry)
	end)end
	local contents
	if options.Contents then
		local context=table.clone(assert(options.Context,"Range contents require DOM helpers"))
		for key,value in {vm=vm,VM=VM,State=api.State,New=api.New,Set=api.Set,SetStart=api.SetStart,SetEnd=api.SetEnd,Collapse=api.Collapse,
			Root=api.Root,Contains=api.Contains,Compare=api.Compare,Length=length,Index=index,CommonAncestor=common,Step=step,Check=check,Fail=fail,Wrap=options.Wrap,Unwrap=options.Unwrap}do context[key]=value end
		contents=options.Contents.install(context)
		for name in {deleteContents=true,extractContents=true,cloneContents=true,insertNode=true,surroundContents=true,createContextualFragment=true}do
			local needs=name=="insertNode"or name=="surroundContents"or name=="createContextualFragment"
			method(name,if needs then 1 else 0,function(args,receiver)
				state(receiver);local converted={}
				if needs then required(args,1);converted[1]=if name=="createContextualFragment"then VM.string(args[1])else node(args[1])end
				local result=contents[name](receiver,converted)
				return if name=="extractContents"or name=="cloneContents"or name=="createContextualFragment"then options.Wrap(result)else U
			end)
		end
	end
	local constructors={}
	for name,proto in {AbstractRange=abstractProto,Range=rangeProto,StaticRange=staticProto}do
		if vm.SymbolToStringTag then define(proto,vm.SymbolToStringTag,{value=name,configurable=true})end
		local constructor=native(name,if name=="StaticRange"then 1 else 0,function()fail("TypeError",name.." requires new")end)
		local function prototypeFor(newTarget)
			if not newTarget or newTarget==U then return proto end
			local prototype=vm.Get(newTarget,"prototype");return if vm.ObjectModel.IsObject(prototype)then prototype else proto
		end
		constructor.Construct=function(args,newTarget)
			check();if name=="AbstractRange"then fail("TypeError","Illegal constructor")end
			if name=="Range"then local prototype=prototypeFor(newTarget);local raw=node(options.Document);return new(raw,0,raw,0,false,prototype)end;required(args,1)
			local init=args[1];if init==N or init==U then init=vm.Object({},N)elseif not vm.ObjectModel.IsObject(init)then fail("TypeError","StaticRangeInit must be a dictionary")end
			local entry={}
			for _,field in {"endContainer","endOffset","startContainer","startOffset"}do
				local raw=vm.Get(init,field);if raw==U then fail("TypeError","Missing StaticRangeInit member: "..field)end
				local key=if field=="endContainer"then "EndNode"elseif field=="startContainer"then "StartNode"elseif field=="endOffset"then "EndOffset"else "StartOffset"
				entry[key]=if field=="endContainer"or field=="startContainer"then node(raw)else integer(raw,4294967296)
			end;return api.NewStatic(entry,prototypeFor(newTarget))
		end
		define(constructor,"prototype",{value=proto});define(proto,"constructor",{value=constructor,writable=true,configurable=true})
		if name=="Range"then for key,value in CONSTANTS do define(constructor,key,{value=value,enumerable=true});define(proto,key,{value=value,enumerable=true})end end
		globals[name]=constructor;vm.Global.Bindings[name]={Value=constructor}
		constructors[name]=constructor
	end
	constructors.Range.Prototype=constructors.AbstractRange;constructors.StaticRange.Prototype=constructors.AbstractRange
	local create=native("createRange",0,function(_,receiver)if receiver~=options.Document then fail("TypeError","Incompatible Document receiver")end;return api.New()end)
	function api.DocumentMethod(key)return if key=="createRange"then create else nil end
	local function update(callback)
		if not api.Alive then return end
		for value in live do local entry=value.RangeState;local boundary,content=callback(entry);if boundary or content then changed(value,if boundary then "boundary"else "content")end end
	end
	function api:BeforeRemove(removed)
		local parent=removed.Parent;if not parent then return end;local at=index(removed)
		update(function(entry)
			local hit,boundary=false,false
			if root(parent,false)==root(entry.StartNode,false)then hit=compare(parent,at,entry.EndNode,entry.EndOffset,false)<0 and compare(parent,at+1,entry.StartNode,entry.StartOffset,false)>0 end
			for _,prefix in {"Start","End"}do
				local nk,ok=prefix.."Node",prefix.."Offset"
				if contains(removed,entry[nk],false)then entry[nk],entry[ok]=parent,at;boundary=true
				elseif entry[nk]==parent and entry[ok]>at then entry[ok]-=1;boundary=true end
			end;return boundary,hit
		end)
	end
	function api:BeforeInsert(parent,at,count)
		if count==0 then return end
		update(function(entry)
			local hit,boundary=false,false
			if root(parent,false)==root(entry.StartNode,false)then hit=compare(entry.StartNode,entry.StartOffset,parent,at,false)<0 and compare(parent,at,entry.EndNode,entry.EndOffset,false)<0 end
			for _,prefix in {"Start","End"}do local nk,ok=prefix.."Node",prefix.."Offset";if entry[nk]==parent and entry[ok]>at then entry[ok]+=count;boundary=true end end;return boundary,hit
		end)
	end
	function api:CharacterData(raw,offset,count,inserted,dataChanged)
		update(function(entry)
			local hit,boundary=false,false
			if dataChanged~=false and(count>0 or inserted>0)and root(raw,false)==root(entry.StartNode,false)then
				hit=if count==0 then compare(entry.StartNode,entry.StartOffset,raw,offset,false)<=0 and compare(raw,offset,entry.EndNode,entry.EndOffset,false)<0
					else compare(raw,offset,entry.EndNode,entry.EndOffset,false)<0 and compare(raw,offset+count,entry.StartNode,entry.StartOffset,false)>0
			end
			for _,prefix in {"Start","End"}do local nk,ok=prefix.."Node",prefix.."Offset"
				if entry[nk]==raw then
					local old=entry[ok];if old>offset and old<=offset+count then entry[ok]=offset elseif old>offset+count then entry[ok]+=inserted-count end
					if old~=entry[ok]then boundary=true end
				end
			end;return boundary,hit
		end)
	end
	function api:SplitText(raw,newNode,offset)
		local parent=raw.Parent;if not parent then return end;local at=index(raw)+1
		update(function(entry)local hit=false
			for _,prefix in {"Start","End"}do local nk,ok=prefix.."Node",prefix.."Offset"
				if entry[nk]==raw and entry[ok]>offset then entry[nk],entry[ok]=newNode,entry[ok]-offset;hit=true
				elseif entry[nk]==parent and entry[ok]==at then entry[ok]+=1;hit=true end
			end;return hit
		end)
	end
	function api:NormalizeText(head,merged,oldLength)
		local parent=merged.Parent;local at=index(merged)
		update(function(entry)local hit=false
			for _,prefix in {"Start","End"}do local nk,ok=prefix.."Node",prefix.."Offset"
				if entry[nk]==merged then entry[nk],entry[ok]=head,oldLength+entry[ok];hit=true
				elseif entry[nk]==parent and entry[ok]==at then entry[nk],entry[ok]=head,oldLength;hit=true end
			end;return hit
		end)
	end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		for value in live do table.clear(value.RangeState);value.RangeState=nil end
		for value in statics do table.clear(value.RangeState);value.RangeState=nil end
		table.clear(live);table.clear(statics);table.clear(options)
	end
	return api
end
return Ranges
