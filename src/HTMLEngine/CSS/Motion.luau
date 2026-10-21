--!strict
--!optimize 2
-- Parsing and interpolation helpers for the bounded HTML motion profile.
local Syntax=require(script.Parent.Syntax)
local Motion={}

local directions={normal=true,reverse=true,alternate=true,["alternate-reverse"]=true}
local fills={none=true,forwards=true,backwards=true,both=true}
local plays={running=true,paused=true}
local compositions={replace=true,add=true,accumulate=true}
local function transitionProperty(value: string): boolean
	-- CSS permits any property identifier here, including an unknown future
	-- property. The effect sampler determines whether a value is animatable.
	return value:match("^[%a_%-][%w_%-]*$")~=nil and value~="initial"and value~="inherit"and value~="unset"and value~="revert"and value~="revert-layer"
end
local transitionBehaviors={normal=true,["allow-discrete"]=true}
-- CSS Easing Functions: keyword curves are cubic Beziers, not polynomial
-- approximations. Keep the same solver for keywords and explicit curves.
local keywordCurves={
	ease={.25,.1,.25,1},
	["ease-in"]={.42,0,1,1},
	["ease-out"]={0,0,.58,1},
	["ease-in-out"]={.42,0,.58,1},
}
local function trim(value: string): string return value:match("^%s*(.-)%s*$") or "" end
local function cssNumber(value: string): number?
	local base=value:match('^(.-)[eE]([+%-]?%d+)$')
	base=base or value
	if not(base:match('^[+%-]?%d+$')or base:match('^[+%-]?%d*%.%d+$'))then return nil end
	local result=tonumber(value)
	return if result and result==result and math.abs(result)<=1000000 then result else nil
end
local function bezier(value: string): (number?,number?,number?,number?)
	local body=value:match("^cubic%-bezier%((.*)%)$")
	if not body then return nil,nil,nil,nil end
	local parts={}
	for part in body:gmatch("[^,]+") do table.insert(parts,part:match("^%s*(.-)%s*$")) end
	if #parts~=4 then return nil,nil,nil,nil end
	local values={}
	for _,part in parts do
		local parsed=cssNumber(part)
		if not parsed or math.abs(parsed)>100 then return nil,nil,nil,nil end
		table.insert(values,parsed)
	end
	if values[1]<0 or values[1]>1 or values[3]<0 or values[3]>1 then return nil,nil,nil,nil end
	return values[1],values[2],values[3],values[4]
end
local stepPositions={start=true,['end']=true,['jump-start']=true,['jump-end']=true,['jump-none']=true,['jump-both']=true}
local function step(value: string): any?
	local body=value:match('^steps%((.*)%)$');if not body then return nil end
	local count,position=body:match('^%s*([+]?%d+)%s*,%s*([%a%-]+)%s*$')
	if not count then count=body:match('^%s*([+]?%d+)%s*$');position='end'end
	local n=tonumber(count)
	if not n or n<1 or n>100000 or not stepPositions[position]or position=='jump-none'and n<2 then return nil end
	return {Count=n,Position=position}
end
local function linear(value: string): any?
	local body=value:match('^linear%((.*)%)$');if not body then return nil end
	local points,index={},1
	while index<=#body do
		local part,after,delimiter=Syntax.scan(body,index,',');index=after
		local output,positions=nil,{}
		for token in part:gmatch('%S+')do
			if token:sub(-1)=='%'then local x=cssNumber(token:sub(1,-2));if not x or #positions>=2 then return nil end;table.insert(positions,x/100)
			else if output~=nil then return nil end;output=cssNumber(token);if output==nil then return nil end end
		end
		if output==nil then return nil end
		table.insert(points,{X=positions[1],Y=output})
		if positions[2]then table.insert(points,{X=positions[2],Y=output})end
		if #points>128 or delimiter==','and index>#body then return nil end
	end
	if #points<2 then return nil end
	points[1].X=points[1].X or 0;points[#points].X=points[#points].X or 1
	local highest=-math.huge
	for _,point in points do if point.X~=nil then point.X=math.max(highest,point.X);highest=point.X end end
	local previous=1
	for i=2,#points do if points[i].X~=nil then
		for missing=previous+1,i-1 do points[missing].X=points[previous].X+(points[i].X-points[previous].X)*(missing-previous)/(i-previous)end
		previous=i
	end end
	return points
end
-- Easing is shared by CSS and script effects. Cache its immutable parse, not
-- per-frame results; clear the bounded cache before untrusted names accumulate.
local easingCache,easingCount={},0
local function easing(value: string): any?
	local cached=easingCache[value];if cached~=nil then return if cached==false then nil else cached end
	if #value>2048 then return nil end
	local result
	if keywordCurves[value]then result={Kind='bezier',Points=keywordCurves[value]}
	elseif value=='linear'then result={Kind='identity'}
	elseif value=='step-start'or value=='step-end'then result={Kind='step',Count=1,Position=if value=='step-start'then'start'else'end'}
	else
		local x1,y1,x2,y2=bezier(value)
		if x1 then result={Kind='bezier',Points={x1,y1,x2,y2}}
		else local data=step(value);if data then data.Kind='step';result=data
			else local points=linear(value);if points then result={Kind='linear',Points=points}end end
		end
	end
	if easingCount>=128 then table.clear(easingCache);easingCount=0 end
	easingCache[value]=result or false;easingCount+=1;return result
end
local function timingValue(value: string): boolean
	return easing(value)~=nil
end

function Motion.serializeEasing(value: string): string
	local parsed=easing(value)
	if not parsed then return value end
	if parsed.Kind=='step'then
		return 'steps('..tostring(parsed.Count)..(if parsed.Position=='end'then''else', '..parsed.Position)..')'
	elseif parsed.Kind=='bezier'and not keywordCurves[value]then
		local points={};for _,point in parsed.Points do table.insert(points,tostring(point))end
		return 'cubic-bezier('..table.concat(points,', ')..')'
	end
	return value
end

local function split(source: string,separator: string): {string}
	local result,index={},1
	while index<=#source do
		local part,nextIndex,delimiter=Syntax.scan(source,index,separator)
		part=trim(part);if part~="" then table.insert(result,part) end
		index=nextIndex;if delimiter=="" then break end
	end
	return result
end

local function time(value: string,allowNegative: boolean?): number?
	local number,unit=value:match("^([+%-]?%d*%.?%d+)(m?s)$")
	number=tonumber(number)
	if not number or math.abs(number)>3600000 or (number<0 and not allowNegative) then return nil end
	return number*(if unit=="ms" then .001 else 1)
end

local function number(value: string): number?
	if not value:match("^[+]?%d*%.?%d+$") then return nil end
	local result=tonumber(value);return if result and result<=100000 then result else nil
end

function Motion.list(value: string,kind: string): any?
	local values={}
	for _,part in split(value,",") do
		local parsed
		if kind=="time" or kind=="delay" then parsed=time(part,kind=="delay")
		elseif kind=="timing" then parsed=if timingValue(part) then part else nil
		elseif kind=="transition-property" then parsed=if transitionProperty(part)then part else nil
		elseif kind=="animation-name" then parsed=if part:lower()=="none"then'none'elseif part:match("^[%a_%-][%w_%-]*$")then part else nil
		elseif kind=="iteration" then parsed=if part=="infinite" then math.huge else number(part)
		elseif kind=="direction" then parsed=if directions[part] then part else nil
		elseif kind=="fill" then parsed=if fills[part] then part else nil
		elseif kind=="play" then parsed=if plays[part] then part else nil end
		if kind=="composition" then parsed=if compositions[part] then part else nil
		elseif kind=="transition-behavior" then parsed=if transitionBehaviors[part] then part else nil end
		if parsed==nil then return nil end
		if kind=='transition-property'and(part=='none'and #values>0 or #values>0 and values[1]=='none')then return nil end
		table.insert(values,parsed)
	end
	return if #values>0 and #values<=16 then values else nil
end

local function words(source: string): {string} return split(source," \t\r\n") end

function Motion.transition(value: string): any?
	local result={Property={},Duration={},Timing={},Delay={},Behavior={}}
	for _,part in split(value,",") do
		local property,duration,delay,easing,behavior=nil,nil,nil,nil,nil
		for _,token in words(part) do
			local seconds=time(token,true)
			if seconds~=nil then if duration==nil then if seconds<0 then return nil end;duration=seconds elseif delay==nil then delay=seconds else return nil end
			elseif timingValue(token) and not easing then easing=token
			elseif transitionBehaviors[token] and not behavior then behavior=token
			elseif not property and transitionProperty(token) then property=token
			else return nil end
		end
		table.insert(result.Property,property or "all");table.insert(result.Duration,duration or 0)
		table.insert(result.Timing,easing or "ease");table.insert(result.Delay,delay or 0);table.insert(result.Behavior,behavior or "normal")
	end
	if #result.Property>1 then for _,name in result.Property do if name=='none'then return nil end end end
	return if #result.Property>0 and #result.Property<=16 then result else nil
end

function Motion.animation(value: string): any?
	local result={Name={},Duration={},Timing={},Delay={},Iteration={},Direction={},Fill={},Play={}}
	for _,part in split(value,",") do
		local name,duration,delay,easing,iteration,direction,fill,play=nil,nil,nil,nil,nil,nil,nil,nil
		if part:lower()=="none" then name="none" end
		for _,token in if name=="none" then {} else words(part) do
			local keyword=token:lower();local seconds=time(keyword,true)
			if seconds~=nil then if duration==nil then if seconds<0 then return nil end;duration=seconds elseif delay==nil then delay=seconds else return nil end
			elseif timingValue(keyword) and not easing then easing=keyword
			elseif directions[keyword] and not direction then direction=keyword
			elseif fills[keyword] and not fill then fill=keyword
			elseif plays[keyword] and not play then play=keyword
			elseif keyword=="infinite" and not iteration then iteration=math.huge
			elseif number(token)~=nil and not iteration then iteration=number(token)
			elseif not name and(keyword=='none'or token:match("^[%a_%-][%w_%-]*$"))then name=if keyword=='none'then'none'else token
			else return nil end
		end
		if not name then return nil end
		table.insert(result.Name,name);table.insert(result.Duration,duration or 0)
		table.insert(result.Timing,easing or "ease");table.insert(result.Delay,delay or 0)
		table.insert(result.Iteration,iteration or 1);table.insert(result.Direction,direction or "normal")
		table.insert(result.Fill,fill or "none");table.insert(result.Play,play or "running")
	end
	return if #result.Name>0 and #result.Name<=16 then result else nil
end

function Motion.pick(values: any,index: number,default: any): any
	return if values and #values>0 then values[(index-1)%#values+1] else default
end

function Motion.ease(name: string,t: number,before: boolean?): number
	local parsed=easing(name);if not parsed then return t end
	local points=parsed.Points
	if parsed.Kind=='linear'then
		if before and t==points[1].X then return points[1].Y end
		for i=#points,1,-1 do if t==points[i].X then return points[i].Y end end
		local a,b=points[1],points[2]
		if t>points[#points].X then a,b=points[#points-1],points[#points]
		elseif t>=a.X then for i=2,#points do if t<points[i].X then a,b=points[i-1],points[i];break end end end
		if a.X==b.X then return b.Y end
		return a.Y+(b.Y-a.Y)*(t-a.X)/(b.X-a.X)
	elseif parsed.Kind=='bezier'then
		local x1,y1,x2,y2=points[1],points[2],points[3],points[4]
		if t<0 then return if x1>0 then t*y1/x1 elseif x2>0 then t*y2/x2 else 0 end
		if t>1 then return if x2<1 then 1+(t-1)*(y2-1)/(x2-1)elseif x1<1 then 1+(t-1)*(y1-1)/(x1-1)else 1 end
		if t==0 or t==1 then return t end
		local ax,bx,cx=1+3*x1-3*x2,3*x2-6*x1,3*x1
		local ay,by,cy=1+3*y1-3*y2,3*y2-6*y1,3*y1
		local low,high,u=0,1,t
		-- Solve x(u)=elapsed progress, then evaluate y(u). Most curves converge
		-- quickly with Newton's method; bisection handles flat tangents safely.
		for _=1,8 do
			local x=((ax*u+bx)*u+cx)*u
			if x==t then return ((ay*u+by)*u+cy)*u end
			if x<t then low=u else high=u end
			local slope=(3*ax*u+2*bx)*u+cx
			local nextU=if math.abs(slope)>1e-12 then u-(x-t)/slope else (low+high)/2
			if nextU<=low or nextU>=high then nextU=(low+high)/2 end
			if math.abs(nextU-u)<1e-10 then return ((ay*nextU+by)*nextU+cy)*nextU end
			u=nextU
		end
		for _=1,32 do
			local middle=(low+high)/2
			local x=((ax*middle+bx)*middle+cx)*middle
			if x==t then return ((ay*middle+by)*middle+cy)*middle end
			if x<t then low=middle else high=middle end
			if high-low<1e-10 then break end
		end
		u=(low+high)/2
		return ((ay*u+by)*u+cy)*u
	end
	if parsed.Kind=='step'then
		local steps,position=parsed.Count,parsed.Position
		local scaled=t*steps
		local current=math.floor(scaled)+(if position=='start'or position=='jump-start'or position=='jump-both'then 1 else 0)
		-- At a discontinuity, the before phase samples the lower side of the
		-- step. This keeps backwards fill still until the positive delay ends.
		if before and scaled%1==0 then current-=1 end
		local jumps=steps+(if position=='jump-both'then 1 elseif position=='jump-none'then -1 else 0)
		if t>=0 and current<0 then current=0 end
		if t<=1 and current>jumps then current=jumps end
		return current/jumps
	end
	return t
end

function Motion.progress(elapsed: number,duration: number,iterations: number,direction: string): (number?,boolean,boolean)
	if elapsed<0 then return nil,false,direction~="reverse" and direction~="alternate-reverse" end
	if duration<=0 then return 1,true,false end
	local total=duration*iterations
	local finished=elapsed>=total
	local cycle,value
	if finished then
		cycle=math.floor(iterations)
		value=iterations-cycle
		-- Integer counts finish at the end of the preceding cycle; fractional
		-- counts finish partway through their final cycle (including its direction).
		if value==0 and iterations>0 then cycle-=1;value=1 end
	else
		cycle=math.floor(elapsed/duration)
		value=(elapsed-cycle*duration)/duration
	end
	local reverse=direction=="reverse" or direction=="alternate-reverse"
	if (direction=="alternate" or direction=="alternate-reverse") and cycle%2==1 then reverse=not reverse end
	-- CSS Easing's before flag also applies after a reverse final iteration.
	return if reverse then 1-value else value,finished,finished and reverse
end

return Motion
