--!strict
-- Experimental Latin descender approximation, isolated for easy removal.
-- Fractions describe a gap within the character's measured advance, not outlines.
local descenders = { p = {0.08, 0.35}, q = {0.65, 0.92}, g = {0.15, 0.85}, j = {0.12, 0.8}, y = {0.15, 0.8} }
local SkipInk = {}

-- Guide coordinates and the line rectangle both use the word label's origin.
-- The p guide approximates the vertical ink range of all supported descenders.
function SkipInk.intersects(item: any, decoration: any, bandOffset: number?, bandHeight: number?): boolean
	if item.Style and item.Style.Visibility == "hidden" then return false end
	if item.SkipInkTop == nil or item.SkipInkBottom == nil then return true end
	local top = item.Baseline + decoration.UnderlineOffset + (bandOffset or 0)
	local height = bandHeight or decoration.Thickness
	if not bandHeight and (decoration.Style == "wavy" or decoration.Style == "double") then height *= 3 end
	return top < item.SkipInkBottom and top + height > item.SkipInkTop
end

function SkipInk.measure(item: any, style: any, measure: any, alive: () -> boolean): boolean
	if item.SkipInkCuts then return true end
	local needed = false
	for _, decoration in style.Decorations or {} do
		if decoration.Underline and decoration.SkipInk ~= "none" and SkipInk.intersects(item, decoration) then needed = true; break end
	end
	if not needed then return true end
	local cuts, prefixes = {}, { [0] = 0, [#item.Text] = item.Width }
	local function prefix(index: number): number?
		if prefixes[index] ~= nil then return prefixes[index] end
		local bounds, message = measure(item.Text:sub(1, index), item.FontFace, item.TextSize, 0)
		if not alive() then return nil end
		assert(bounds, "Skip-ink measurement failed: " .. tostring(message))
		prefixes[index] = bounds.X
		return bounds.X
	end
	local padding = math.max(0.5, item.TextSize * 0.025)
	local function addCut(char: string, left: number, right: number)
		local fractions = descenders[char]
		if not fractions then return end
		local width = math.max(0, right - left)
		if width > 0 then
			table.insert(cuts, {
				Left = math.max(0, math.floor(left + width * fractions[1] - padding)),
				Right = math.min(item.Width, math.ceil(left + width * fractions[2] + padding)),
			})
		end
	end
	if item.Glyphs then
		-- Reuse exact label positions; no prefix calls for independently spaced text.
		for _, glyph in item.Glyphs do addCut(glyph.Text:sub(1, 1), glyph.X, glyph.X + glyph.Width) end
	else
		-- ASCII matches are UTF-8 boundaries even when other characters precede them.
		for index, char in item.Text:gmatch("()([pgjqy])") do
			local left = prefix(index - 1)
			if left == nil then return false end
			local right = prefix(index)
			if right == nil then return false end
			addCut(char, left, right)
		end
	end
	table.sort(cuts, function(a, b) return a.Left < b.Left end)
	item.SkipInkCuts = cuts
	return true
end

return SkipInk
