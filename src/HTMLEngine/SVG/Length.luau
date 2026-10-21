--!strict
-- SVG lengths resolve in user units BEFORE the viewport transform.
local Length={}
local absolute={px=1,["in"]=96,cm=96/2.54,mm=96/25.4,q=96/101.6,pt=96/72,pc=16}
local function finite(n: number): boolean return n==n and math.abs(n)<math.huge end
function Length.parse(text: string): (any?,string?)
	if #text>256 then return nil,"invalid-length" end
	text=text:match("^%s*(.-)%s*$") :: string
	local number=text:match("^[+%-]?%d+%.?%d*") or text:match("^[+%-]?%.%d+")
	if not number then return nil,"invalid-length" end
	local rest=text:sub(#number+1)
	local exponent=rest:match("^[eE][+%-]?%d+")
	if exponent then number..=exponent;rest=rest:sub(#exponent+1) end
	if rest~="" and rest~="%" and not rest:match("^%a+$") then return nil,"invalid-length" end
	local n=tonumber(number)
	if not n or not finite(n) then return nil,"invalid-length" end
	return {Value=n,Unit=rest:lower()},nil
end

function Length.diagonal(width: number,height: number): number
	local maximum=math.max(math.abs(width),math.abs(height))
	if maximum==0 then return 0 end
	-- Avoid overflow when squaring otherwise valid viewport dimensions.
	return maximum*math.sqrt(((width/maximum)^2+(height/maximum)^2)/2)
end

function Length.resolve(value: any,context: any,axis: string,nonNegative: boolean?): (number?,string?)
	assert(axis=="x" or axis=="y" or axis=="diagonal" or axis=="font","Invalid SVG length axis")
	local parsed,problem=value,nil
	if type(value)=="string" then parsed,problem=Length.parse(value) end
	if not parsed then return nil,problem end
	local n,unit=parsed.Value,parsed.Unit
	if nonNegative and n<0 then return nil,"negative-length" end
	local factor,notice=nil,nil
	if unit=="" then factor=1
	elseif absolute[unit] then factor=absolute[unit]
	elseif unit=="%" then
		if axis=="font" then factor=context.FontSize
		elseif axis=="x" then factor=context.Width
		elseif axis=="y" then factor=context.Height
		elseif context.Width and context.Height then factor=Length.diagonal(context.Width,context.Height) end
		if factor then factor/=100 end
	elseif unit=="em" then factor=context.FontSize
	elseif unit=="rem" then factor=context.RootFontSize
	elseif unit=="ex" or unit=="ch" then
		factor=if unit=="ex" then context.XHeight else context.ZeroAdvance
		if not factor and context.FontSize then factor=context.FontSize/2;notice="font-metric-fallback" end
	elseif unit=="lh" then factor=context.LineHeight
	elseif unit=="rlh" then factor=context.RootLineHeight
	elseif unit=="cap" then factor=context.CapHeight
	elseif unit=="ic" then factor=context.IdeographicAdvance
	elseif unit=="vw" or unit=="vh" or unit=="vmin" or unit=="vmax" then
		local w,h=context.CSSViewportWidth,context.CSSViewportHeight
		if unit=="vw" then factor=w elseif unit=="vh" then factor=h
		elseif w and h then factor=if unit=="vmin" then math.min(w,h) else math.max(w,h) end
		if factor then factor/=100 end
	else return nil,"unsupported-length-unit" end
	if factor==nil then return nil,"missing-length-context" end
	if not finite(factor) or factor<0 then return nil,"invalid-length-context" end
	local result=n*factor
	if not finite(result) then return nil,"length-overflow" end
	return result,notice
end

-- Geometry defaults are chosen by the caller, independently of diagnostics.
function Length.attribute(text: string?,context: any,axis: string,default: number,nonNegative: boolean?): (number,string?)
	if text==nil then return default,nil end
	local value,problem=Length.resolve(text,context,axis,nonNegative)
	return if value==nil then default else value,problem
end
return Length
