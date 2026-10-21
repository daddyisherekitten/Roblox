--!strict
--!optimize 2
--!native
local WorkContext=require(script.Parent.Parent.WorkContext)
local BorderGeometry = require(script.Parent.Parent.Layout.BorderGeometry)
-- Rasterize the opaque area outside a shifted/shrunken padding-box hole.
-- Three separable box filters approximate a Gaussian with sigma = CSS blur / 2.
local Color = require(script.Parent.Parent.CSS.Color)
local Pixels = {}
local function radii(blur: number): {number}
	local sigma = blur / 2
	local lower = math.floor(math.sqrt(4 * sigma * sigma + 1))
	if lower % 2 == 0 then lower -= 1 end
	local count = math.clamp(math.round((12 * sigma * sigma - 3 * lower * lower - 12 * lower - 9) / (-4 * lower - 4)), 0, 3)
	return { (lower - 1 + (if count >= 1 then 0 else 2)) / 2,
		(lower - 1 + (if count >= 2 then 0 else 2)) / 2, (lower - 1 + (if count >= 3 then 0 else 2)) / 2 }
end

function Pixels.plan(width: number, height: number, style: any): any
	local blur = 0
	for _, shadow in style.BoxShadows or {} do
		if shadow.Inset and shadow.Alpha > 0 then blur = math.max(blur, shadow.Blur) end
	end
	-- Bound both native image dimensions and transient blur buffers.
	local extra = 3 * blur + 8
	local scale = math.min(1, 1024 / (math.max(width, height) + extra), math.sqrt(262144 / ((width + extra) * (height + extra))))
	return {Width = math.max(1, math.ceil(width * scale)), Height = math.max(1, math.ceil(height * scale)), Scale = scale}
end

local function inside(x: number, y: number, left: number, top: number, width: number, height: number, radius: number): boolean
	if width <= 0 or height <= 0 or x < left or y < top or x >= left + width or y >= top + height then return false end
	radius = math.min(radius, width / 2, height / 2)
	if radius <= 0 then return true end
	local dx = x - math.clamp(x, left + radius, left + width - radius)
	local dy = y - math.clamp(y, top + radius, top + height - radius)
	return dx * dx + dy * dy <= radius * radius
end

local function coverage(x: number, y: number, left: number, top: number, width: number, height: number, radius: number): number
	local count = 0
	for sy = 0, 1 do
		for sx = 0, 1 do
			if inside(x + (sx + 0.5) / 2, y + (sy + 0.5) / 2, left, top, width, height, radius) then count += 1 end
		end
	end
	return count / 4
end

-- Sliding sums make each pass linear in the number of pixels, not blur radius.
local function filter(source: buffer, target: buffer, width: number, height: number, radius: number, vertical: boolean, edgeWeight: number?)
	local length, lines = if vertical then height else width, if vertical then width else height
	local stride, step = if vertical then width else 1, if vertical then 1 else width
	local divisor = radius * 2 + 1
	for line = 0, lines - 1 do
		local base, sum = line * step, 0
		if edgeWeight then
			for index = 0, length - 1 do
				local value = buffer.readf32(source, (base + index * stride) * 4) * (1 - 2 * edgeWeight)
				if index > 0 then value += buffer.readf32(source, (base + (index - 1) * stride) * 4) * edgeWeight end
				if index + 1 < length then value += buffer.readf32(source, (base + (index + 1) * stride) * 4) * edgeWeight end
				buffer.writef32(target, (base + index * stride) * 4, value)
			end
			continue
		end
		for index = 0, math.min(radius, length - 1) do sum += buffer.readf32(source, (base + index * stride) * 4) end
		for index = 0, length - 1 do
			buffer.writef32(target, (base + index * stride) * 4, sum / divisor)
			local remove, add = index - radius, index + radius + 1
			if remove >= 0 then sum -= buffer.readf32(source, (base + remove * stride) * 4) end
			if add < length then sum += buffer.readf32(source, (base + add * stride) * 4) end
		end
	end
end

function Pixels.render(width: number, height: number, style: any, plan: any): buffer
	local scale, iw, ih = plan.Scale, plan.Width, plan.Height
	local bt, br, bb, bl = BorderGeometry.sizes(style)
	bt, br, bb, bl = bt * scale, br * scale, bb * scale, bl * scale
	local pw, ph = math.max(0, width * scale - br - bl), math.max(0, height * scale - bt - bb)
	local radius = math.max(0, math.min(style.BorderRadius or 0, width / 2, height / 2) * scale - math.max(bt, br, bb, bl))
	local clip, result = buffer.create(iw * ih), buffer.create(iw * ih * 4)
	for y = 0, ih - 1 do
		WorkContext.checkpoint()
		for x = 0, iw - 1 do buffer.writeu8(clip, y * iw + x, math.round(255 * coverage(x, y, bl, bt, pw, ph, radius))) end
	end
	local shadows = style.BoxShadows or {}
	-- Composite back to front: the first CSS shadow lies on top.
	for index = #shadows, 1, -1 do
		local shadow = shadows[index]
		if not shadow.Inset or shadow.Alpha <= 0 then continue end
		if shadow.Blur == 0 and shadow.X == 0 and shadow.Y == 0 and shadow.Spread == 0 then continue end
		local passes = radii(shadow.Blur * scale)
		local pad = passes[1] + passes[2] + passes[3]
		local edgeWeight = nil
		if pad == 0 and shadow.Blur > 0 then
			-- A subpixel Gaussian must not disappear when all box radii round to 0.
			local weight = math.exp(-2 / (shadow.Blur * scale)^2)
			edgeWeight = weight / (1 + 2 * weight); pad = 1
		end
		local w, h = iw + 2 * pad, ih + 2 * pad
		local mask, temp = buffer.create(w * h * 4), buffer.create(w * h * 4)
		local spread = shadow.Spread * scale
		local holeRadius = if radius == 0 then 0 else math.max(0, radius - spread)
		for y = 0, h - 1 do
			WorkContext.checkpoint()
			for x = 0, w - 1 do
				buffer.writef32(mask, (y * w + x) * 4, coverage(x - pad, y - pad,
					bl + spread + shadow.X * scale, bt + spread + shadow.Y * scale, pw - 2 * spread, ph - 2 * spread, holeRadius))
			end
		end
		for _, r in passes do
			if r > 0 then filter(mask, temp, w, h, r, false); filter(temp, mask, w, h, r, true) end
		end
		if edgeWeight then filter(mask, temp, w, h, 1, false, edgeWeight); filter(temp, mask, w, h, 1, true, edgeWeight) end
		local color = if shadow.Color == "currentcolor" then style.Color else shadow.Color
		for y = 0, ih - 1 do
			WorkContext.checkpoint()
			for x = 0, iw - 1 do
				local pixel = y * iw + x
				local a = Color.opacity(shadow, style) * math.clamp(1 - buffer.readf32(mask, ((y + pad) * w + x + pad) * 4), 0, 1)
				if a <= 0 or buffer.readu8(clip, pixel) == 0 then continue end
				local offset = pixel * 4
				local old = buffer.readu8(result, offset + 3) / 255 * (1 - a)
				local alpha = a + old
				buffer.writeu8(result, offset, math.round((color.R * a * 255 + buffer.readu8(result, offset) * old) / alpha))
				buffer.writeu8(result, offset + 1, math.round((color.G * a * 255 + buffer.readu8(result, offset + 1) * old) / alpha))
				buffer.writeu8(result, offset + 2, math.round((color.B * a * 255 + buffer.readu8(result, offset + 2) * old) / alpha))
				buffer.writeu8(result, offset + 3, math.round(alpha * 255))
			end
		end
	end
	-- Clip once after composition to avoid darkening antialiased rounded edges.
	for pixel = 0, iw * ih - 1 do
		buffer.writeu8(result, pixel * 4 + 3, math.round(buffer.readu8(result, pixel * 4 + 3) * buffer.readu8(clip, pixel) / 255))
	end
	return result
end

return Pixels
