--!strict
-- Live ranges stay in DOMRanges; the registry schedules paint without layout.
local Highlights={}
function Highlights.install(vm,globals,host)
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true,Dirty=false};local states=setmetatable({},{__mode='kv'});local order={};local registered={};local queued=false
	local proto=vm.Object({});local registryProto=vm.Object({});local registry=vm.Object({},registryProto)
	local function fail(message)VM.throw(VM.error('TypeError',message))end
	local function check()assert(api.Alive and vm.Alive,'Highlights disposed')end
	local function text(value)value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then fail('Cannot convert Symbol to string')end;return VM.string(value)end
	local function define(value,key,d)vm.DefineProperty(value,key,vm.Object(d,N))end
	local function native(name,length,fn)return {Kind='native-function',Prototype=vm.Prototypes.Function,Values={name=name,length=length},Call=function(args,self)check();return fn(args,self)end}end
	local function method(p,name,length,fn)define(p,name,{value=native(name,length,fn),writable=true,enumerable=true,configurable=true})end
	local function accessor(p,name,get,set)define(p,name,{get=native('get '..name,0,function(_,self)return get(self)end),set=if set then native('set '..name,1,function(args,self)set(self,args[1]or U);return U end)else U,enumerable=true,configurable=true})end
	local function state(value)local s=states[value];if not s then fail('Expected a Highlight from this realm')end;return s end
	local function requireRegistry(self)if self~=registry then fail('Incompatible HighlightRegistry receiver')end end
	local function required(args,count)if #args<count then fail('Missing highlight argument')end end
	local function collection(value,name,args)return vm:Call(vm.Get(vm.Prototypes.Set,name),args or {},value)end
	local function schedule()
		api.Dirty=true;if queued then return end;queued=true
		host.QueueTask(function()queued=false;if api.Alive then host.Flush();api:Paint()end end)
	end
	local function changed(value)for _,member in registered do if member.Value==value then schedule();break end end end
	local function validRange(value)host.Ranges.AbstractState(value);return value end
	local function add(value,range)
		local s=state(value);validRange(range);if collection(s.Ranges,'has',{range})then return end
		if s.Ranges.Size>=256 then fail('Highlight range budget exceeded')end;collection(s.Ranges,'add',{range});changed(value)
	end
	local ctor=native('Highlight',0,function()fail('Highlight requires new')end)
	ctor.Construct=function(args,newTarget)
		local p=vm.Get(newTarget or ctor,'prototype');local value=vm.Object({},if vm.ObjectModel.IsObject(p)then p else proto);local s={Ranges=vm:Construct(globals.Set,{}),Priority=0,Type='highlight'};value.HighlightState=s;states[value]=s
		for _,range in args do add(value,range)end;return value
	end
	define(ctor,'prototype',{value=proto});define(proto,'constructor',{value=ctor,writable=true,configurable=true});define(proto,vm.SymbolToStringTag,{value='Highlight',configurable=true})
	globals.Highlight=ctor;vm.Global.Bindings.Highlight={Value=ctor};define(globals.CSS,'highlights',{value=registry,enumerable=true})
	local registryCtor=native('HighlightRegistry',0,function()fail('Illegal HighlightRegistry constructor')end)
	define(registryCtor,'prototype',{value=registryProto});define(registryProto,'constructor',{value=registryCtor,writable=true,configurable=true})
	globals.HighlightRegistry=registryCtor;vm.Global.Bindings.HighlightRegistry={Value=registryCtor}
	accessor(proto,'size',function(self)return state(self).Ranges.Size end)
	accessor(proto,'priority',function(self)return state(self).Priority end,function(self,value)local n=VM.number(vm.ToPrimitive(value,'number'));n=if n~=n or math.abs(n)==math.huge then 0 else (if n<0 then math.ceil(n)else math.floor(n))%4294967296;if n>=2147483648 then n-=4294967296 end;state(self).Priority=n;changed(self)end)
	accessor(proto,'type',function(self)return state(self).Type end,function(self,value)local t=text(value);if t~='highlight'and t~='spelling-error'and t~='grammar-error'then fail('Invalid Highlight type')end;state(self).Type=t;changed(self)end)
	method(proto,'add',1,function(args,self)required(args,1);add(self,args[1]);return self end)
	method(proto,'has',1,function(args,self)required(args,1);validRange(args[1]);return collection(state(self).Ranges,'has',args)end)
	method(proto,'delete',1,function(args,self)required(args,1);validRange(args[1]);local removed=collection(state(self).Ranges,'delete',args);if removed then changed(self)end;return removed end)
	method(proto,'clear',0,function(_,self)collection(state(self).Ranges,'clear');changed(self);return U end)
	local function iterator(read,pair)
		local index=0;local done=false;local value=vm.Object({});method(value,'next',0,function()
			index+=1;local member=if done then nil else read(index);done=member==nil;return vm.Object({done=done,value=if done then U elseif pair then vm.Array({member,member})else member})
		end);define(value,vm.SymbolIterator,{value=native('[Symbol.iterator]',0,function(_,self)return self end),writable=true,configurable=true});return value
	end
	for _,name in {'keys','values','entries'}do method(proto,name,0,function(_,self)return collection(state(self).Ranges,name)end)end
	define(proto,vm.SymbolIterator,{value=vm.Get(proto,'values'),writable=true,configurable=true})
	method(proto,'forEach',1,function(args,self)required(args,1);local nextValue=vm.Iterator(state(self).Ranges);while true do vm.Step();local more,range=nextValue();if not more then break end;vm:Call(args[1],{range,range,self},args[2]or U)end;return U end)
	accessor(registryProto,'size',function(self)requireRegistry(self);local count=0;for _ in registered do count+=1 end;return count end)
	method(registryProto,'set',2,function(args,self)
		requireRegistry(self);required(args,2);local name=text(args[1]);state(args[2]);if #name>1024 then fail('Highlight name budget exceeded')end
		if not registered[name]then
			local count=0;for _ in registered do count+=1 end;if count>=256 or #order>=65536 then fail('Highlight registry budget exceeded')end
			local entry={Name=name};table.insert(order,entry);registered[name]={Entry=entry,Value=args[2]}
		else registered[name].Value=args[2]end;schedule();return registry
	end)
	method(registryProto,'get',1,function(args,self)requireRegistry(self);required(args,1);local entry=registered[text(args[1])];return if entry then entry.Value else U end)
	method(registryProto,'has',1,function(args,self)requireRegistry(self);required(args,1);return registered[text(args[1])]~=nil end)
	method(registryProto,'delete',1,function(args,self)requireRegistry(self);required(args,1);local name=text(args[1]);local found=registered[name]~=nil;registered[name]=nil;if found then schedule()end;return found end)
	method(registryProto,'clear',0,function(_,self)requireRegistry(self);table.clear(registered);schedule();return U end)
	for _,name in {'keys','values','entries'}do method(registryProto,name,0,function(_,self)
		requireRegistry(self);local i=0;return iterator(function()
			while i<#order do i+=1;local entry=order[i];local key=entry.Name;local member=registered[key];if member and member.Entry==entry then local value=member.Value;return if name=='keys'then key elseif name=='values'then value else vm.Array({key,value})end end;return nil
		end,false)
	end)end
	define(registryProto,vm.SymbolIterator,{value=vm.Get(registryProto,'entries'),writable=true,configurable=true})
	define(registryProto,vm.SymbolToStringTag,{value='HighlightRegistry',configurable=true})
	method(registryProto,'forEach',1,function(args,self)requireRegistry(self);required(args,1);local i=1;while i<=#order do vm.Step();local entry=order[i];local member=registered[entry.Name];if member and member.Entry==entry then vm:Call(args[1],{member.Value,entry.Name,registry},args[2]or U)end;i+=1 end;return U end)
	function api:RangeChanged(range)for _,member in registered do if collection(state(member.Value).Ranges,'has',{range})then schedule();break end end end
	function api:Paint()
		if not self.Dirty or not host.Paint then return end;self.Dirty=false;local records={}
		for index,entry in order do local member=registered[entry.Name];if member and member.Entry==entry then local s=state(member.Value);local ranges={};for _,r in s.Ranges.Entries do if r.Active then table.insert(ranges,host.Ranges.AbstractState(r.Value))end end;table.insert(records,{Name=entry.Name,Priority=s.Priority,Order=index,Ranges=ranges})end end
		table.sort(records,function(a,b)return if a.Priority==b.Priority then a.Order<b.Order else a.Priority<b.Priority end);host.Paint(records)
	end
	function api:AfterLayout()if next(registered)then self.Dirty=true;self:Paint()end end
	function api:Destroy()self.Alive=false;if host.Paint then host.Paint({})end;for value in states do value.HighlightState=nil end;table.clear(states);table.clear(registered);table.clear(order)end
	return api
end
return Highlights
