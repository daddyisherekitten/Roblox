--!strict
--!optimize 2
--!native
local WorkContext=require(script.Parent.Parent.WorkContext)
-- Pixel generation for the bounded border-image and clip-path profile.
local LengthExpression = require(script.Parent.Parent.CSS.LengthExpression)

local Pixels = {}
local MAX_SIDE, MAX_PIXELS = 512, 262144

function Pixels.plan(width: number, height: number): any
	width, height = math.max(1, width), math.max(1, height)
	local scale = math.min(1, MAX_SIDE / math.max(width, height), math.sqrt(MAX_PIXELS / (width * height)))
	return { Width = math.max(1, math.floor(width * scale + .5)), Height = math.max(1, math.floor(height * scale + .5)) }
end

local function byte(value: number): number return math.clamp(math.floor(value * 255 + .5), 0, 255) end

local function write(bufferValue: buffer, offset: number, color: Color3, alpha: number)
	buffer.writeu8(bufferValue, offset, byte(color.R))
	buffer.writeu8(bufferValue, offset + 1, byte(color.G))
	buffer.writeu8(bufferValue, offset + 2, byte(color.B))
	buffer.writeu8(bufferValue, offset + 3, byte(alpha))
end

local function resolved(value: any, reference: number): number
	return math.max(0, LengthExpression.resolve(value, reference))
end

local function clipGeometry(clip: any, width: number, height: number): any
	local geometry={Kind=clip.Kind,X=width/2,Y=height/2,Width=width,Height=height}
	if clip.Kind == "circle" then
		geometry.Radius=resolved(clip.Radius,math.sqrt((width*width+height*height)/2))
	elseif clip.Kind == "ellipse" then
		geometry.RX,geometry.RY=resolved(clip.X,width),resolved(clip.Y,height)
	elseif clip.Kind == "polygon" then
		geometry.Points={}
		for _,point in clip.Points do
			table.insert(geometry.Points,{X=LengthExpression.resolve(point.X,width),Y=LengthExpression.resolve(point.Y,height)})
		end
	else geometry.Radius=math.min(resolved(clip.Radius,math.min(width,height)),width/2,height/2) end
	return geometry
end

local function inside(geometry: any, x: number, y: number): boolean
	local cx, cy = geometry.X, geometry.Y
	if geometry.Kind == "circle" then
		local radius = geometry.Radius
		if radius <= 0 then return false end
		local dx, dy = (x - cx) / radius, (y - cy) / radius
		return dx * dx + dy * dy <= 1
	elseif geometry.Kind == "ellipse" then
		local rx, ry = geometry.RX, geometry.RY
		if rx <= 0 or ry <= 0 then return false end
		local dx, dy = (x - cx) / rx, (y - cy) / ry
		return dx * dx + dy * dy <= 1
	elseif geometry.Kind == "polygon" then
		local points,hit=geometry.Points,false
		local previous=points[#points]
		for _,point in points do
			if (point.Y>y)~=(previous.Y>y) and x<(previous.X-point.X)*(y-point.Y)/(previous.Y-point.Y)+point.X then hit=not hit end
			previous=point
		end
		return hit
	end
	local width,height,radius=geometry.Width,geometry.Height,geometry.Radius
	if radius <= 0 then return x >= 0 and x <= width and y >= 0 and y <= height end
	local qx = math.abs(x - cx) - (width / 2 - radius)
	local qy = math.abs(y - cy) - (height / 2 - radius)
	local ox, oy = math.max(qx, 0), math.max(qy, 0)
	return math.sqrt(ox * ox + oy * oy) + math.min(math.max(qx, qy), 0) <= radius
end

function Pixels.renderClip(clip: any, width: number, height: number, outside: Color3, plan: any): buffer
	local result = buffer.create(plan.Width * plan.Height * 4)
	local sx, sy = width / plan.Width, height / plan.Height
	local samples = {.125, .375, .625, .875}
	-- CSS lengths and bounds are constant for all sixteen coverage samples of
	-- every pixel; resolving them here avoids millions of repeated evaluations.
	local geometry=clipGeometry(clip,width,height)
	for py = 0, plan.Height - 1 do
		for px = 0, plan.Width - 1 do
			if px%64==0 then WorkContext.checkpoint()end
			local count = 0
			for _, oy in samples do for _, ox in samples do
				if inside(geometry, (px + ox) * sx, (py + oy) * sy) then count += 1 end
			end end
			write(result, (py * plan.Width + px) * 4, outside, 1 - count / 16)
		end
	end
	return result
end

-- Actual coverage for image alpha, rather than painting a guessed backdrop.
function Pixels.clipAlpha(clip: any,width: number,height: number,plan: any,check: any?): buffer?
	local result=buffer.create(plan.Width*plan.Height)
	local geometry=clipGeometry(clip,width,height);local samples={.125,.375,.625,.875}
	local sx,sy=(plan.ExtentWidth or width)/plan.Width,(plan.ExtentHeight or height)/plan.Height
	for y=0,plan.Height-1 do
		if check and not check()then return nil end
		for x=0,plan.Width-1 do
			local count=0
			for _,oy in samples do for _,ox in samples do
				if inside(geometry,(x+ox)*sx+(plan.OffsetX or 0),(y+oy)*sy+(plan.OffsetY or 0))then count+=1 end
			end end
			buffer.writeu8(result,y*plan.Width+x,math.round(count/16*255))
		end
	end
	return result
end

local function gradientPosition(direction: string, angle: number?, x: number, y: number, width: number, height: number): number
	if angle then
		local radians=math.rad(angle)
		local dx,dy=math.sin(radians),-math.cos(radians)
		local extent=math.abs(dx)*width/2+math.abs(dy)*height/2
		return if extent>0 then .5+((x-width/2)*dx+(y-height/2)*dy)/(2*extent) else .5
	end
	if direction == "to left" then return 1 - x / width end
	if direction == "to bottom" then return y / height end
	if direction == "to top" then return 1 - y / height end
	return x / width
end

function Pixels.renderBorder(definition: any, width: number, height: number, widths: {number}, plan: any): buffer
	local result = buffer.create(plan.Width * plan.Height * 4)
	local sx, sy = width / plan.Width, height / plan.Height
	local top, right, bottom, left = widths[1] or 1, widths[2] or 1, widths[3] or 1, widths[4] or 1
	for py = 0, plan.Height - 1 do
		for px = 0, plan.Width - 1 do
			if px%64==0 then WorkContext.checkpoint()end
			local x, y = (px + .5) * sx, (py + .5) * sy
			local border = y < top or x >= width - right or y >= height - bottom or x < left
			if border then
				local t = math.clamp(gradientPosition(definition.Direction,definition.Angle,x,y,width,height), 0, 1)
				local stops=definition.Stops
				local a,b,alphaA,alphaB
				if stops and #stops>1 then
					local position=t*(#stops-1)
					local at=math.min(#stops-1,math.floor(position)+1)
					a,b=stops[at].Color,stops[at+1].Color
					alphaA,alphaB=stops[at].Alpha,stops[at+1].Alpha
					t=position-(at-1)
				else a,b=definition.Color1,definition.Color2;alphaA,alphaB=definition.Alpha1 or 1,definition.Alpha2 or 1 end
				local color = Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
				local alpha = alphaA + (alphaB - alphaA) * t
				write(result, (py * plan.Width + px) * 4, color, alpha)
			end
		end
	end
	return result
end

return Pixels
