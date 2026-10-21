--!strict
-- Intrinsic sizing of an inline SVG viewport, independent of drawing/viewBox CTM.
local Sizing = {}

local Viewport = require(script.Parent.Viewport)
function Sizing.source(node: any): (number,number)
	local function dimension(value)
		local number=if value then tonumber(value) or tonumber(value:match('^%s*([%+%-]?[%d%.]+)px%s*$')) else nil
		-- A valid zero-sized SVG decodes successfully; zero is not a missing dimension.
		return if number and number>=0 and number<math.huge then number else nil
	end
	local w,h=dimension(node.Attributes.width),dimension(node.Attributes.height)
	local box=Viewport.viewBox(node.Attributes.viewBox)
	local ratio=if box and box.Width>0 and box.Height>0 then box.Width/box.Height else nil
	if w and not h and ratio then h=w/ratio elseif h and not w and ratio then w=h*ratio end
	-- viewBox coordinates supply an aspect ratio, never CSS pixel dimensions.
	if not w and not h and ratio then
		local scale=math.min(300/box.Width,150/box.Height)
		w,h=box.Width*scale,box.Height*scale
	end
	return w or 300,h or 150
end
function Sizing.viewBoxRatio(value: string?): number?
	local box=Viewport.viewBox(value)
	return if box and box.Width>0 and box.Height>0 then box.Width/box.Height else nil
end

function Sizing.natural(item: any, available: number, horizontal: number, vertical: number): (number,number,number?)
	local style = item.Style
	local function absolute(value: any, edges: number): number?
		if not value or value.Percent then return nil end
		return math.max(0,value.Value-(if style.BoxSizing == "border-box" then edges else 0))
	end
	local w,h = absolute(style.Width,horizontal),absolute(style.Height,vertical)
	local ratio = if w and h and w > 0 and h > 0 then w/h else Sizing.viewBoxRatio(item.SVG.Attributes.viewBox)
	if w == nil and h == nil then
		if ratio then
			w = math.max(0,available-horizontal-style.Margin[2]-style.Margin[4])
			h = w/ratio
		else w,h = 300,150 end
	elseif w == nil then w = if ratio then h*ratio else 300
	elseif h == nil then h = if ratio then w/ratio else 150 end
	return w,h,ratio
end

return Sizing
