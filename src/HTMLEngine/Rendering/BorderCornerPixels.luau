--!strict
--!optimize 2
--!native
local WorkContext=require(script.Parent.Parent.WorkContext)
local Geometry = require(script.Parent.Parent.Layout.BorderGeometry)
local Paint = require(script.Parent.BorderPaint)
local Pixels = {}
function Pixels.plan(style: any, width: number, height: number): any?
	local t, r, b, l = Geometry.sizes(style)
	if width < l + r or height < t + b or l + r == 0 or t + b == 0 then return nil end
	-- Bounded corner atlas, never a texture the size of the whole element.
	local scale = math.min(1, 128 / math.max(1, l + r, t + b))
	local lw, rw, th, bh = math.ceil(l * scale), math.ceil(r * scale), math.ceil(t * scale), math.ceil(b * scale)
	local tiles = {{0, 0, lw, th, 0, 0, l, t, 1, 4}, {lw, 0, rw, th, width-r, 0, r, t, 1, 2},
		{0, th, lw, bh, 0, height-b, l, b, 3, 4}, {lw, th, rw, bh, width-r, height-b, r, b, 3, 2}}
	return {Width = lw + rw, Height = th + bh, Tiles = tiles, Sizes = {t, r, b, l}, BoxWidth = width, BoxHeight = height}
end
function Pixels.render(style: any, plan: any): any
	local patterns, colors, alphas, kinds = {}, {}, {}, {}
	for side = 1, 4 do
		local length = if side == 1 or side == 3 then plan.BoxWidth else plan.BoxHeight
		local color, alpha, kind = Paint.edge(style, side)
		patterns[side] = Geometry.pattern(kind, length, plan.Sizes[side])
		colors[side] = {color}; alphas[side], kinds[side] = alpha, kind
		if kind == "groove" or kind == "ridge" then
			colors[side] = {Paint.edge(style, side, 1), (Paint.edge(style, side, 2))}
		end
	end
	local function sample(side: number, x: number, y: number): (any, number)
		local horizontal = side == 1 or side == 3
		local along = if horizontal then x else y
		local cross = if side == 1 then y elseif side == 3 then y - plan.BoxHeight + plan.Sizes[3]
			elseif side == 4 then x else x - plan.BoxWidth + plan.Sizes[2]
		for band, part in patterns[side] do
			if along >= part[1] and along < part[1]+part[3] and cross >= part[2] and cross < part[2]+part[4] then
				if kinds[side] == "dotted" then
					local dx, dy = (along-part[1])/part[3]-.5, (cross-part[2])/part[4]-.5
					if dx*dx + dy*dy > .25 then continue end
				end
				return colors[side][band] or colors[side][1], alphas[side]
			end
		end
		return nil, 0
	end
	local data = buffer.create(plan.Width * plan.Height * 4)
	for _, tile in plan.Tiles do
		for py = 0, tile[4]-1 do
			for px = 0, tile[3]-1 do
				if px%64==0 then WorkContext.checkpoint()end
				local red, green, blue, alpha = 0, 0, 0, 0
				for sy = 0, 3 do for sx = 0, 3 do
					local x = (px+(sx+.5)/4)/tile[3]*tile[7]
					local y = (py+(sy+.5)/4)/tile[4]*tile[8]
					local u = if tile[10] == 4 then x else tile[7]-x
					local v = if tile[9] == 1 then y else tile[8]-y
					local side = if v*tile[7] <= u*tile[8] then tile[9] else tile[10]
					local color, a = sample(side, tile[5]+x, tile[6]+y)
					if color then red += color.R*a; green += color.G*a; blue += color.B*a; alpha += a end
				end end
				local offset = ((tile[2]+py)*plan.Width+tile[1]+px)*4
				if alpha > 0 then
					buffer.writeu8(data, offset, math.round(255*red/alpha))
					buffer.writeu8(data, offset+1, math.round(255*green/alpha))
					buffer.writeu8(data, offset+2, math.round(255*blue/alpha))
				end
				buffer.writeu8(data, offset+3, math.round(255*alpha/16))
			end
		end
	end
	return data
end
return Pixels
