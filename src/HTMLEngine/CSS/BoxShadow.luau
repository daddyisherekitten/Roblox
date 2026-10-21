--!strict
-- CSS outer and inset shadows. Parsed once; no Roblox instances here.
local Syntax = require(script.Parent.Syntax)
local Color = require(script.Parent.Color)
local AnimationColors=require(script.Parent.AnimationColors)
local BoxShadow = {}

function BoxShadow.parse(value: string, length: any, textShadow: boolean?): any?
	if value == "none" then return {} end
	local shadows, index = {}, 1
	while index <= #value do
		local source, nextIndex, separator = Syntax.scan(value, index, ",")
		index = nextIndex
		local lengths, tint, alpha, afterColor, inset = {}, nil, 1, false, false
		local cursor = 1
		while cursor <= #source do
			local token, nextCursor = Syntax.scan(source, cursor, " \t\r\n")
			cursor = nextCursor
			if token == "" then continue end
			if token == "inset" then
				if inset or textShadow then return nil end
				inset = true
				if #lengths > 0 then afterColor = true end
				continue
			end
			local sign = token:sub(1, 1)
			local parsed = length(if sign == "-" or sign == "+" then token:sub(2) else token)
			if parsed and not parsed.Percent then
				if #lengths >= (if textShadow then 3 else 4) or afterColor or token:match("^[%+%-][%+%-]") then return nil end
				table.insert(lengths, parsed.Value * (if sign == "-" then -1 else 1))
			else
				if tint ~= nil then return nil end
				tint, alpha = Color.parse(token)
				if tint == nil then return nil end
				afterColor = #lengths > 0
			end
		end
		if #lengths < 2 or (lengths[3] or 0) < 0 or (lengths[3] or 0) > 1000 or #shadows >= 16 then return nil end
		-- Initial text-shadow subset: preserve sharp glyph copies, never fake blur.
		if textShadow and (lengths[3] or 0) ~= 0 then return nil end
		table.insert(shadows, table.freeze({X = lengths[1], Y = lengths[2], Blur = lengths[3] or 0,
			Spread = lengths[4] or 0, Color = tint or "currentcolor", Alpha = alpha, Inset = inset}))
		if separator == "," and index > #value then return nil end
	end
	return if #shadows > 0 then shadows else nil
end

local function tint(shadow: any): any
	return shadow.AnimationColor or {Color=shadow.Color,Alpha=shadow.Alpha or 1}
end
local function zero(inset: boolean): any
	return {X=0,Y=0,Blur=0,Spread=0,Color=Color3.new(0,0,0),Alpha=0,Inset=inset}
end
local function compatible(a: any,b: any): boolean
	for index=1,math.min(#a,#b)do if a[index].Inset~=b[index].Inset then return false end end
	return true
end
BoxShadow.compatible=compatible
local function shadow(a: any,b: any,count: number,adding: boolean): any
	local function component(key: string): number
		local value=if adding then a[key]+b[key]*count else a[key]+(b[key]-a[key])*count
		return if key=='Blur'then math.max(0,value)else value
	end
	local color=if adding then AnimationColors.add(tint(a),tint(b),count)else AnimationColors.mix(tint(a),tint(b),count)
	return {X=component('X'),Y=component('Y'),Blur=component('Blur'),Spread=component('Spread'),Inset=a.Inset,
		Color=color.Color,Alpha=color.Alpha,AnimationColor=if color.Kind then color else nil}
end
function BoxShadow.mix(a: any,b: any,progress: number): any
	if not compatible(a,b)then return if progress<.5 then a else b end
	local result={}
	for index=1,math.max(#a,#b)do
		local left,right=a[index],b[index]
		table.insert(result,shadow(left or zero(right.Inset),right or zero(left.Inset),progress,false))
	end
	return result
end
function BoxShadow.add(a: any,b: any,mode: string?,count: number?): any
	count=count or 1;if count==0 then return a end
	if mode~='accumulate'then
		local result=table.clone(a);for _,value in b do table.insert(result,value)end;return result
	end
	if not compatible(a,b)then return b end
	local result={}
	for index=1,math.max(#a,#b)do
		local left,right=a[index],b[index]
		table.insert(result,shadow(left or zero(right.Inset),right or zero(left.Inset),count,true))
	end
	return result
end
function BoxShadow.resolve(values: any,current: any): any
	local result={}
	for _,value in values or{}do
		local color=AnimationColors.resolve(tint(value),current)
		table.insert(result,{X=value.X,Y=value.Y,Blur=math.max(0,value.Blur),Spread=value.Spread,Inset=value.Inset,Color=color.Color,Alpha=color.Alpha})
	end
	return result
end
local function number(value: number): string
	return (string.format('%.6f',value):gsub('0+$',''):gsub('%.$',''))
end
function BoxShadow.serialize(values: any,current: any,textShadow: boolean?): string
	local result={}
	for _,value in BoxShadow.resolve(values,current)do
		local color=value.Color;local parts={}
		for _,channel in {'R','G','B'}do table.insert(parts,tostring(math.floor(color[channel]*255+.5)))end
		local text=if value.Alpha==1 then'rgb('..table.concat(parts,', ')..')'else'rgba('..table.concat(parts,', ')..', '..number(value.Alpha)..')'
		for _,key in if textShadow then {'X','Y','Blur'}else {'X','Y','Blur','Spread'}do text..=' '..number(value[key])..'px'end
		if value.Inset then text..=' inset'end;table.insert(result,text)
	end
	return if #result==0 then'none'else table.concat(result,', ')
end

return BoxShadow
