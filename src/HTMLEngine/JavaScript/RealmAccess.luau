--!strict
-- Live same-origin objects cross realm boundaries through the owning runtime.
-- Weak caches preserve identity without rooting a closed document or UI graph.
local VM=require(script.Parent.VM)
local Access={}
local states=setmetatable({},{__mode='kv'})
local function check(caller,target)
	if not caller.Alive or not target or not target.Alive then VM.throw(caller.HostEvents:DOMException('The document has been disposed','InvalidStateError'))end
	if caller.DocumentOrigin~=target.DocumentOrigin then VM.throw(caller.HostEvents:DOMException('Cross-origin document access is denied','SecurityError'))end
end
function Access.wrap(caller,target,value)
	if value==nil or value==VM.Undefined or value==VM.Null or type(value)~='table'and type(value)~='function'then return value end
	local old=states[value]
	if old then
		check(caller,old.Target)
		if old.Target==caller then return old.Value end
		target,value=old.Target,old.Value
	end
	if caller==target then return value end;check(caller,target)
	if value==target.Window and target.BrowsingWindows and target.BrowsingWindows.SelfHandle then return caller.BrowsingWindows.Proxy(target.BrowsingWindows.SelfHandle)end
	caller.ForeignCache=caller.ForeignCache or setmetatable({},{__mode='kv'})
	local previous=caller.ForeignCache[value];if previous then return previous end
	local record={Target=target,Value=value};local vm=caller.VM;local result
	local function run(fn)
		check(caller,record.Target)
		return record.Target:Access(function()return fn(record.Target.VM,record.Value)end)
	end
	local function outward(v)return Access.wrap(caller,record.Target,v)end
	local function inward(v)return Access.wrap(record.Target,caller,v)end
	if VM.callable(value)then
		result={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,VMOwner=vm,
			Call=function(args,receiver)
				return outward(run(function(other,fn)
					local converted={};for i,v in args do converted[i]=inward(v)end
					return other:Call(fn,converted,inward(receiver))
				end))
			end}
	else
		result={
			Get=function(key)return outward(run(function(other,object)return other.Get(object,key)end))end,
			Set=function(key,v,strict)return run(function(other,object)return other.Set(object,key,inward(v),strict)end)end,
			Has=function(key)return run(function(other,object)return other.ObjectModel.Has(object,key)end)end,
			Keys=function(enumerable)return run(function(other,object)return other.ObjectModel.OwnKeys(object,enumerable)end)end,
			GetPrototype=function()return outward(run(function(other,object)return other.ObjectModel.GetPrototype(object)end))end,
			IsExtensible=function()return run(function(other,object)return other.ObjectModel.IsExtensible(object)end)end,
			GetOwnPropertyDescriptor=function(key)
				local d=run(function(other,object)return other.ObjectModel.Own(object,key)end);if not d then return nil end
				local copy=table.clone(d);if d.Accessor then copy.Get=outward(d.Get);copy.Set=outward(d.Set)else copy.Value=outward(d.Value)end;return copy
			end,
		}
	end
	-- Expando mutations and callback functions use the target runtime's mutation
	-- scheduling. No eval/string bridge and no unguarded target VM is exported.
	states[result]=record;caller.ForeignCache[value]=result
	target.ForeignExports=target.ForeignExports or setmetatable({},{__mode='k'});target.ForeignExports[record]=true
	return result
end
function Access.destroy(runtime)
	for record in runtime.ForeignExports or{}do record.Target=nil;record.Value=nil end
	if runtime.ForeignExports then table.clear(runtime.ForeignExports)end
	if runtime.ForeignCache then table.clear(runtime.ForeignCache)end
end
return Access
