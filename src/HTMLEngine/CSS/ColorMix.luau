--!strict
local Syntax=require(script.Parent.Syntax)
local Spaces=require(script.Parent.ColorSpaces)
local Mix={}
local function trim(s)return s:match('^%s*(.-)%s*$')or ''end
local spaces={srgb=true,['srgb-linear']=true,oklab=true,oklch=true}
function Mix.parse(body: string,parse: any): (any,number?)
	local terms,index={},1
	while index<=#body do local term,nextIndex=Syntax.scan(body,index,',');table.insert(terms,trim(term));index=nextIndex end
	if #terms~=3 or body:match(',%s*$')then return nil,nil end
	local space,hue=terms[1]:match('^in%s+([%a%-]+)%s+([%a]+)%s+hue$')
	if not space then space=terms[1]:match('^in%s+([%a%-]+)$')end
	if not spaces[space]or hue and(space~='oklch'or not({shorter=true,longer=true,increasing=true,decreasing=true})[hue])then return nil,nil end
	local function stop(source)
		local color,weight=source:match('^(.-)%s+([+%-]?[%d%.]+)%%$')
		if not color then weight,color=source:match('^([+%-]?[%d%.]+)%%%s+(.+)$')end
		local percentage=weight and tonumber(weight)
		if weight and(not percentage or percentage<0 or percentage>100)then return nil end
		local shade,alpha=parse(color or source)
		if not shade or type(shade)=='string'then return nil end
		return {Color=shade,Alpha=alpha or 1,Weight=percentage}
	end
	local a,b=stop(terms[2]),stop(terms[3]);if not a or not b then return nil,nil end
	local aw,bw=a.Weight,b.Weight
	if aw==nil and bw==nil then aw,bw=50,50 elseif aw==nil then aw=100-bw elseif bw==nil then bw=100-aw end
	local sum=aw+bw;if sum==0 then return nil,nil end
	aw,bw=aw/sum,bw/sum
	local alpha=a.Alpha*aw+b.Alpha*bw
	local left,right=Spaces.coordinates(a.Color,space),Spaces.coordinates(b.Color,space)
	if space=='oklch'then
		-- Achromatic colors carry the other endpoint's hue, rather than zero.
		if left[2]<.000004 then left[3]=right[3]elseif right[2]<.000004 then right[3]=left[3]end
		left[3],right[3]=Spaces.hue(left[3],right[3],hue or 'shorter')
	end
	local result={}
	for channel=1,3 do result[channel]=if space=='oklch'and channel==3 then left[channel]*aw+right[channel]*bw elseif alpha==0 then 0 else(left[channel]*a.Alpha*aw+right[channel]*b.Alpha*bw)/alpha end
	return Spaces.color(result,space),alpha*math.min(1,sum/100)
end
return Mix
