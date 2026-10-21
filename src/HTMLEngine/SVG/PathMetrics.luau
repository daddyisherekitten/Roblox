--!strict
local Length=require(script.Parent.Length)
local PathMetrics={}
function PathMetrics.parse(value: string?): (number?,string?)
	if value==nil then return nil,nil end
	local n=Length.parse(value)
	if not n or n.Unit~='' or n.Value<0 then return nil,'invalid-path-length' end
	return n.Value,nil
end
function PathMetrics.distance(a: any,b: any): number
	local x,y=b[1]-a[1],b[2]-a[2]
	return math.sqrt(x*x+y*y)
end
function PathMetrics.measure(parts: any): number
	local total=0
	for _,part in parts do
		for i=2,#part.Points do total+=PathMetrics.distance(part.Points[i-1],part.Points[i]) end
		if part.Closed and #part.Points>1 then total+=PathMetrics.distance(part.Points[#part.Points],part.Points[1]) end
	end
	return total
end
function PathMetrics.calibrate(value: number,percent: boolean,total: number,author: number?): number
	if percent or author==nil or value==0 then return value end
	if author==0 then return if value>0 then math.huge else -math.huge end
	return value*(total/author)
end
return PathMetrics
