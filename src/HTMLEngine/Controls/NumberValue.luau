--!strict
local Numeric=require(script.Parent.NumericValue)
local Number={}
function Number.read(a: any): any
	local minimum,step=Numeric.parse(a.min),Numeric.parse(a.step)
	return {Min=minimum,Max=Numeric.parse(a.max),Base=minimum or Numeric.parse(a.value) or 0,
		Step=if string.lower(a.step or "") == "any" then nil elseif step and step > 0 then step else 1}
end
function Number.sanitize(value: string): string
	return if Numeric.parse(value) then value else ""
end
function Number.invalid(c: any): boolean
	if c.BadInput then return true end
	if c.Value == "" then return c.Required end
	local n=Numeric.parse(c.Value)
	if not n then return true end
	local r=c.Number
	if (r.Min and n < r.Min) or (r.Max and n > r.Max) then return true end
	if r.Step then
		local index=(n-r.Base)/r.Step
		return math.abs(index) == math.huge or math.abs(index-math.round(index)) > 1e-8
	end
	return false
end
function Number.step(c: any,direction: number): string?
	local r=c.Number
	local lo,hi=r.Min or -math.huge,r.Max or math.huge
	if lo > hi then return nil end
	-- UI arrows use one unit for step=any; DOM step methods reject step=any.
	local step=r.Step or 1
	local before=Numeric.parse(c.Value) or 0
	local index=(before-r.Base)/step
	if math.abs(index) == math.huge then return nil end
	local nearest=math.round(index)
	local nextIndex=if math.abs(index-nearest) < 1e-8 then nearest+direction
		elseif direction > 0 then math.ceil(index) else math.floor(index)
	local first,last=math.ceil((lo-r.Base)/step-1e-10),math.floor((hi-r.Base)/step+1e-10)
	if first > last then return nil end
	local value=r.Base+math.clamp(nextIndex,first,last)*step
	if math.abs(value) == math.huge or value ~= value or value < lo-1e-10 or value > hi+1e-10 then return nil end
	if (direction > 0 and value < before) or (direction < 0 and value > before) then return nil end
	return if value == 0 then "0" else tostring(value)
end
return Number
