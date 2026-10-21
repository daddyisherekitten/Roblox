--!strict
-- WebIDL indexed properties share one protocol across Typed OM collections.
-- Expandos use ordinary descriptors; supported indices remain host properties.
local Indexed={}
local function index(key)
	if type(key)~='string'then return nil end
	local n=tonumber(key);return if n and n>=0 and n%1==0 and n<4294967295 and tostring(n)==key then n else nil
end
function Indexed.attach(ctx: any,object: any,members: any,assign: any?)
	local vm,VM=ctx.VM,ctx.VM.Model;local model=vm.ObjectModel;local backing=vm.Object({})
	object.Values=nil;object.Kind='typed-indexed-value'
	object.Get=function(key)
		local i=index(key);if i and i<#members then return members[i+1]end
		backing.Prototype=object.Prototype;return model.Get(backing,key,object)
	end
	object.Set=function(key,value,strict)
		local i=index(key)
		if i then
			if assign then return assign(i,value)end
			if strict then VM.throw(VM.error('TypeError','Readonly Typed OM index'))end;return false
		end
		backing.Prototype=object.Prototype;return model.Set(backing,key,value,strict,object)
	end
	object.Keys=function(enumerable)
		local keys={};for i=1,#members do vm.Step();table.insert(keys,tostring(i-1))end
		for _,key in model.OwnKeys(backing,enumerable)do table.insert(keys,key)end;return keys
	end
	object.GetOwnPropertyDescriptor=function(key)
		local i=index(key);if i and i<#members then return {Value=members[i+1],Writable=assign~=nil,Enumerable=true,Configurable=true}end
		return model.Own(backing,key)
	end
	object.DefineProperty=function(key,descriptor)
		local d=model.ToDescriptor(descriptor);local i=index(key)
		if not i then return model.DefineOwn(backing,key,d)end
		if not assign or d.Accessor or d.Value==nil and d.Writable==nil then return false end
		return assign(i,if d.Value==nil then VM.Undefined else d.Value)
	end
	object.Delete=function(key)local i=index(key);return if i and i<#members then false else model.Delete(backing,key,false)end
	object.PreventExtensions=function()return false end
	object.GetPrototype=function()return object.Prototype or VM.Null end
	object.SetPrototype=function(proto)
		local cursor,seen=proto,{}
		while cursor~=VM.Null and cursor~=nil do
			vm.Step();if cursor==object or seen[cursor]then return false end;seen[cursor]=true;cursor=model.GetPrototype(cursor)
		end
		object.Prototype=proto;return true
	end
	return object
end
return Indexed
