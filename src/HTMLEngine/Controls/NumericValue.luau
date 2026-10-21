--!strict
local Numeric={}
function Numeric.parse(value: any): number?
	local text=tostring(value or "")
	local mantissa,exponent=text:match("^(.-)[eE]([+-]?%d+)$")
	local digits=mantissa or text
	if not (digits:match("^%-?%d+$") or digits:match("^%-?%d*%.%d+$")) then return nil end
	local n=tonumber(if exponent then digits .. "e" .. exponent else digits)
	return if n and n == n and math.abs(n) < math.huge then n else nil
end
return Numeric
