--!strict
local Range = {}
local numberValue=require(script.Parent.NumericValue).parse
function Range.read(attributes: any): any
	local minimum=numberValue(attributes.min)
	local step=numberValue(attributes.step)
	return {Min=minimum or 0,Max=numberValue(attributes.max) or 100,
		Base=minimum or numberValue(attributes.value) or 0,
		Step=if string.lower(attributes.step or "") == "any" then nil elseif step and step > 0 then step else 1}
end
function Range.normalize(range: any, raw: any): string
	local lo,hi=range.Min,math.max(range.Min,range.Max)
	local value=math.clamp(numberValue(raw) or (lo/2+hi/2),lo,hi)
	local step,base=range.Step,range.Base
	if step and hi > lo then
		local first,last=(lo-base)/step,(hi-base)/step
		local index=(value-base)/step
		-- Guard overflow for extreme (but valid) numeric attributes.
		if math.abs(first) < math.huge and math.abs(last) < math.huge and math.abs(index) < math.huge then
			local lowIndex,highIndex=math.ceil(first-1e-10),math.floor(last+1e-10)
			if lowIndex <= highIndex then
				value=math.clamp(base+math.clamp(math.floor(index+.5+1e-10),lowIndex,highIndex)*step,lo,hi)
			end
		end
	end
	return if value == 0 then "0" else tostring(value)
end
function Range.ratio(control: any): number
	local r=control.Range
	if r.Max <= r.Min then return 0 end
	return math.clamp(((tonumber(control.Value) or r.Min)/2-r.Min/2)/(r.Max/2-r.Min/2),0,1)
end
function Range.at(range: any, ratio: number): string
	local t=math.clamp(ratio,0,1)
	return Range.normalize(range,range.Min*(1-t)+math.max(range.Min,range.Max)*t)
end
return Range
