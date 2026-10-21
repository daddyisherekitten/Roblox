--!strict
-- Feature queries reuse the cascade parser; CSS.escape serializes identifiers.
local Stylesheet=require(script.Parent.Parent.CSS.Stylesheet)
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local CSS={}
function CSS.install(vm,globals)
	local VM=vm.Model;local namespace=vm.Object({})
	local function text(value)value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then VM.throw(VM.error('TypeError','Cannot convert Symbol to string'))end;return VM.string(value)end
	local function method(name,length,fn)
		local value={Kind='native-function',Prototype=vm.Prototypes.Function,Values={name=name,length=length},Call=fn}
		vm.DefineProperty(namespace,name,vm.Object({value=value,writable=true,enumerable=true,configurable=true},VM.Null))
	end
	method('supports',1,function(args)
		if #args<1 then VM.throw(VM.error('TypeError','CSS.supports requires a condition'))end
		return Stylesheet.supports(if #args>=2 then '('..text(args[1])..':'..text(args[2])..')'else text(args[1]))
	end)
	method('escape',1,function(args)
		if #args<1 then VM.throw(VM.error('TypeError','CSS.escape requires an identifier'))end
		return Syntax.serializeIdentifier(text(args[1]))
	end)
	globals.CSS=namespace;vm.Global.Bindings.CSS={Value=namespace};return namespace
end
return CSS
