--!strict
-- CSS Text indentation flags leave the signed length/percentage representation intact.
local Length=require(script.Parent.LengthExpression)
local Indent={}
function Indent.parse(parts: {string},length: (string)->any): any
	local result,hanging,each=nil,false,false
	for _,part in parts do
		if part=='hanging'then if hanging then return nil end;hanging=true
		elseif part=='each-line'then if each then return nil end;each=true
		elseif result then return nil else result=length(part);if not result then return nil end end
	end
	if not result then return nil end
	result=table.clone(result);result.Hanging,result.EachLine=hanging,each;return result
end
function Indent.flow(value: any,width: number,first: boolean,rtl: boolean,intrinsic: boolean?): any
	if not value then return 0 end
	return {Amount=Length.resolve(value,if intrinsic then 0 else width),First=first,
		Hanging=value.Hanging==true,EachLine=value.EachLine==true,RTL=rtl and not intrinsic}
end
return table.freeze(Indent)
