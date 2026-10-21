--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Reflected list attributes share the ordinary attribute mutation path, so
-- counter numbering, selectors and custom-element reactions stay in sync.
local VM=require(script.Parent.VM)
local Lists={}
local html=ElementNames.html
function Lists.new(ctx: any): any
	local api={}
	local function long(value: any): number
		local primitive=if ctx.ToPrimitive then ctx.ToPrimitive(value,"number")else value
		if type(primitive)=="table"and(primitive.Kind=="symbol"or primitive.Kind=="bigint")then ctx.DOMError("TypeError","Cannot convert list value to a number")end
		local number=VM.number(primitive)
		if number~=number or number==math.huge or number==-math.huge or number==0 then return 0 end
		number=(if number<0 then math.ceil(number)else math.floor(number))%4294967296
		return if number<2147483648 then number else number-4294967296
	end
	function api:Has(node: any,key: any): boolean
		return html(node)and((ElementNames.htmlName(node)=="ol"and(key=="start"or key=="reversed"or key=="type"))or(ElementNames.htmlName(node)=="li"and(key=="value"or key=="type")))
	end
	function api:Get(node: any,key: any): (boolean,any)
		if not self:Has(node,key)then return false,nil end
		if key=="reversed"then return true,node.Attributes.reversed~=nil end
		if key=="type"then return true,node.Attributes.type or ""end
		local raw=node.Attributes[key];local parsed=raw and tonumber(raw:match("^[\t\n\f\r ]*([%+%-]?%d+)"))
		return true,if parsed and parsed>=-2147483648 and parsed<=2147483647 then parsed else if key=="start"then 1 else 0
	end
	function api:Set(node: any,key: any,value: any): boolean
		if not self:Has(node,key)then return false end
		local result=if key=="reversed"then(if VM.truth(value)then""else nil)elseif key=="type"then ctx.ReflectedString(value)else VM.string(long(value))
		ctx.Attribute(node,key,result);return true
	end
	return api
end
return Lists
