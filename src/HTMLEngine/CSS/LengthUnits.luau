--!strict
-- CSS reference pixels, font metrics and viewport/container axes. Hosts may
-- provide distinct small/large/dynamic viewports; Roblox normally supplies one.
local Units = {}
local absolute = table.freeze({px=1, ['in']=96, cm=96/2.54, mm=96/25.4, q=96/101.6, pt=96/72, pc=16})
local fonts = table.freeze({em=true,rem=true,ex=true,rex=true,ch=true,rch=true,cap=true,rcap=true,ic=true,ric=true,lh=true,rlh=true})
local containers = table.freeze({cqw=true,cqh=true,cqi=true,cqb=true,cqmin=true,cqmax=true})
local function viewport(unit: string): boolean
	return unit:match('^[sld]?v[whib]$')~=nil or unit:match('^[sld]?vmin$')~=nil or unit:match('^[sld]?vmax$')~=nil
end
function Units.has(unit: string): boolean return unit=='%'or absolute[unit]~=nil or fonts[unit]==true or containers[unit]==true or viewport(unit)end
function Units.contextual(unit: string): boolean return viewport(unit)or containers[unit]==true end
function Units.font(unit: string): boolean return fonts[unit]==true end
local function axes(context: any, prefix: string?): (number,number)
	local width=context[(prefix or '')..'ViewportWidth']or context.ViewportWidth or 0
	local height=context[(prefix or '')..'ViewportHeight']or context.ViewportHeight or 0
	return width,height
end
function Units.scale(unit: string, context: any?): number?
	context=context or {}
	if absolute[unit]then return absolute[unit]end
	if fonts[unit]then
		local root=unit:sub(1,1)=='r';local name=if root then unit:sub(2)else unit
		local prefix=if root then 'Root'else ''
		local size=context[prefix..'FontSize']or 16
		if name=='em'then return size
		elseif name=='ex'then return context[prefix..'XHeight']or size*.5
		elseif name=='ch'then return context[prefix..'ZeroAdvance']or size*.5
		elseif name=='cap'then return context[prefix..'CapHeight']or size*.7
		elseif name=='ic'then return context[prefix..'IdeographicAdvance']or size
		else return context[prefix..'LineHeight']or size*1.2 end
	end
	local vertical=(context.WritingMode or 'horizontal-tb')~='horizontal-tb'
	local width,height
	if containers[unit]then
		local vw,vh=axes(context,'Small')
		width,height=context.ContainerWidth or vw,context.ContainerHeight or vh
		unit=unit:sub(3)
	else
		if not viewport(unit)then return nil end
		local prefix=({s='Small',l='Large',d='Dynamic'})[unit:sub(1,1)]
		width,height=axes(context,prefix)
		unit=unit:sub(if prefix then 3 else 2)
	end
	local value=if unit=='w'then width elseif unit=='h'then height elseif unit=='i'then (if vertical then height else width)elseif unit=='b'then (if vertical then width else height)elseif unit=='min'then math.min(width,height)else math.max(width,height)
	return value/100
end
return Units
