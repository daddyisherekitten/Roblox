--!strict
-- Independently rendered graphemes; words remain indivisible layout items.
local LetterSpacing = {}
local function tabularMetrics(font: Font, size: number, measure: any, alive: () -> boolean): any?
	-- WordLayout retains this item's completed glyph measurements on resize.
	-- Native digit bounds must not be shared between independent items/pages.
	local widths, cellWidth = {}, 0
	for digit = 0, 9 do
		local result, message = measure(tostring(digit), font, size, 0)
		if not alive() then return nil end
		assert(result, "Digit measurement failed: " .. tostring(message))
		widths[digit] = result
		cellWidth = math.max(cellWidth, result.X)
	end
	return {Widths = widths, CellWidth = cellWidth}
end

function LetterSpacing.split(text: string): {any}
	local glyphs = {}
	for first, last in utf8.graphemes(text) do
		table.insert(glyphs, {Text = text:sub(first, last)})
	end
	return glyphs
end

function LetterSpacing.measure(item: any, font: Font, size: number, measure: any, alive: () -> boolean): boolean
	local bounds = {}
	local tabularEnabled=item.Style and item.Style.TabularNums
	local tabular = if tabularEnabled then tabularMetrics(font, size, measure, alive) else nil
	if tabularEnabled and not tabular then return false end
	for index, glyph in item.Glyphs do
		local digit = if tabular then tonumber(glyph.Text:match("^[0-9]$")) else nil
		local result, message
		if digit then result = tabular.Widths[digit] else result, message = measure(glyph.Text, font, size, 0) end
		if not alive() then return false end
		assert(result, "Character measurement failed: " .. tostring(message))
		bounds[index] = {Width = if digit then tabular.CellWidth else result.X, Height = result.Y}
	end
	-- Commit only after all asynchronous measurements complete successfully.
	for index, glyph in item.Glyphs do
		glyph.Width, glyph.Height = bounds[index].Width, math.max(size, bounds[index].Height)
	end
	return true
end

function LetterSpacing.arrange(item: any, spacing: number, wordSpacing: number)
	local x, farRight, height = 0, 0, 0
	for index, glyph in item.Glyphs do
		if index > 1 then x += spacing end
		glyph.X = x
		farRight, height = math.max(farRight, x + glyph.Width), math.max(height, glyph.Height)
		x += glyph.Width
		if glyph.Text == " " then x += wordSpacing end
	end
	item.Width, item.VisualWidth, item.Height = math.max(0, x), farRight, height
	if item.AppliedLetterSpacing ~= spacing or item.AppliedWordSpacing ~= wordSpacing then item.SkipInkCuts = nil end
	item.AppliedLetterSpacing, item.AppliedWordSpacing = spacing, wordSpacing
end

return LetterSpacing
