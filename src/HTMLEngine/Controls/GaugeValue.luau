--!strict
local Numeric=require(script.Parent.NumericValue)
local Gauge={}
function Gauge.read(kind: string,a: any): any
	local maximum=Numeric.parse(a.max) or 1
	if kind == "progress" then return {Min=0,Max=if maximum > 0 then maximum else 1} end
	local minimum=Numeric.parse(a.min) or 0
	maximum=math.max(minimum,maximum)
	local low=math.clamp(Numeric.parse(a.low) or minimum,minimum,maximum)
	return {Min=minimum,Max=maximum,Low=low,High=math.clamp(Numeric.parse(a.high) or maximum,low,maximum),
		Optimum=math.clamp(Numeric.parse(a.optimum) or (minimum/2+maximum/2),minimum,maximum)}
end
function Gauge.assign(c: any,raw: any): boolean
	local g=c.Gauge
	local value=math.clamp(Numeric.parse(raw) or 0,g.Min,g.Max)
	local text=if value == 0 then "0" else tostring(value)
	local unknown=c.Type == "progress" and raw == nil
	local changed=c.Value ~= text or g.Indeterminate ~= unknown
	c.Value,g.Indeterminate=text,unknown
	local span=g.Max-g.Min
	g.Ratio=if span <= 0 then 0 elseif span < math.huge then math.clamp((value-g.Min)/span,0,1)
		else math.clamp((value/2-g.Min/2)/(g.Max/2-g.Min/2),0,1)
	g.Quality="optimum"
	if c.Type == "meter" then
		if g.Optimum < g.Low then
			g.Quality=if value <= g.Low then "optimum" elseif value <= g.High then "suboptimal" else "critical"
		elseif g.Optimum > g.High then
			g.Quality=if value >= g.High then "optimum" elseif value >= g.Low then "suboptimal" else "critical"
		elseif value < g.Low or value > g.High then g.Quality="suboptimal" end
	end
	return changed
end
return Gauge
