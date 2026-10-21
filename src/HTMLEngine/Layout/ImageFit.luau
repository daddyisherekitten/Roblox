--!strict
-- Object geometry is independent of the replaced element's size in the line.
local ObjectPosition = require(script.Parent.Parent.CSS.ObjectPosition)
local ImageFit = {}
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local ViewBox=require(script.Parent.Parent.CSS.ObjectViewBox)

local function offset(axis: any, remaining: number): number
	local result=LengthExpression.resolve(axis,remaining)+(axis.Offset or 0)
	if axis.EdgeOffset then result+=LengthExpression.resolve(axis.EdgeOffset,remaining)*(axis.EdgeSign or 1) end
	return result
end

function ImageFit.custom(style: any): boolean
	if style.ObjectViewBox then return true end
	if style.ObjectFit == "fill" then
		local position = style.ObjectPosition or ObjectPosition.Default
		-- fill has no spare space: all percentage anchors produce zero displacement.
		return offset(position.X, 0) ~= 0 or offset(position.Y, 0) ~= 0
	end
	return style.ObjectFit == "none" or style.ObjectFit == "scale-down" or not ObjectPosition.centered(style.ObjectPosition)
end

function ImageFit.needsDimensions(style: any): boolean
	if style.ObjectViewBox then return true end
	if style.ObjectFit ~= "fill" and ImageFit.custom(style) then return true end
	if style.Width and style.Height then return false end
	local ratio = style.AspectRatio
	-- One specified axis plus a fixed author ratio fully determines the box.
	if ratio and ratio.Value and not ratio.Auto and (style.Width or style.Height) then return false end
	return true
end

function ImageFit.natural(item: any): (number,number,number,number,number,number)
	local width,height=item.IntrinsicWidth or item.AttributeWidth or 300,item.IntrinsicHeight or item.AttributeHeight or 150
	local x,y,w,h=ViewBox.rectangle(item.Style.ObjectViewBox,width,height)
	return width,height,x,y,w,h
end

function ImageFit.viewRectangle(item: any): (number,number,number,number)
	local style = item.Style
	local width, height = item.ContentWidth, item.ContentHeight
	local w, h = width, height
	if style.ObjectFit ~= "fill" then
		local _,_,_,_,naturalWidth,naturalHeight=ImageFit.natural(item)
		w,h=naturalWidth,naturalHeight
		if w <= 0 or h <= 0 then return 0, 0, 0, 0 end
		local scale = 1
		if style.ObjectFit == "cover" then scale = math.max(width / w, height / h)
		elseif style.ObjectFit == "contain" then scale = math.min(width / w, height / h)
		elseif style.ObjectFit == "scale-down" then scale = math.min(1, width / w, height / h) end
		w, h = w * scale, h * scale
	end
	local position = style.ObjectPosition or ObjectPosition.Default
	return offset(position.X, width - w), offset(position.Y, height - h), w, h
end

function ImageFit.rectangle(item: any): (number,number,number,number)
	local x,y,w,h=ImageFit.viewRectangle(item)
	if not item.Style.ObjectViewBox then return x,y,w,h end
	local nw,nh,vx,vy,vw,vh=ImageFit.natural(item)
	if vw<=0 or vh<=0 then return 0,0,0,0 end
	local sx,sy=w/vw,h/vh
	return x-vx*sx,y-vy*sy,nw*sx,nh*sy
end

return ImageFit
