--!strict
local PointerCapture={}
function PointerCapture.install(vm,options)
	local VM=vm.Model;local U=VM.Undefined;local api={Alive=true};local methods={}
	local function fail(name,message)VM.throw(if name=="TypeError"then VM.error(name,message)else options.Events:DOMException(message,name))end
	local function long(value)
		value=vm.ToPrimitive(value,"number");local n=VM.number(value)
		if n~=n or math.abs(n)==math.huge then return 0 end
		n=(if n<0 then math.ceil(n)else math.floor(n))%4294967296
		return if n>=2147483648 then n-4294967296 else n
	end
	for name,action in {setPointerCapture="Set",releasePointerCapture="Release",hasPointerCapture="Has"}do
		local method={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)
			local node=if type(receiver)=="table"then receiver.DOMNode else nil
			if not api.Alive or not node or node.Kind~="Element"or options.Wrap(node)~=receiver then fail("TypeError","Invalid pointer capture receiver")end
			if #args<1 then fail("TypeError",name.." requires a pointerId")end
			local id=long(args[1]);local adapter=options.Adapter
			if action=="Has"then return adapter~=nil and adapter:Has(node,id)==true end
			local errorName=if adapter then adapter[action](adapter,node,id)else "NotFoundError"
			if errorName then fail(errorName,"The pointer is unavailable or the element is disconnected")end
			return U
		end}
		vm.DefineProperty(method,"name",vm.Object({value=name,configurable=true},VM.Null))
		vm.DefineProperty(method,"length",vm.Object({value=1,configurable=true},VM.Null));methods[name]=method
	end
	function api:ElementMethod(node,key)return if node.Kind=="Element"then methods[key]else nil end
	function api:Destroy()self.Alive=false;table.clear(methods);table.clear(options)end
	return api
end
return PointerCapture
