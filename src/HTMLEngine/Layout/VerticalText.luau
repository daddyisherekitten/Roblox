--!strict
-- Vertical inline advances and reusable upright graphemes. The source word
-- remains the hit-test owner; its horizontal label is restored on mode changes.
local LetterSpacing = require(script.Parent.LetterSpacing)
local TextShadows = require(script.Parent.Parent.Rendering.TextShadows)
local Orientation=require(script.Parent.VerticalOrientation)
local BidiPaint=require(script.Parent.BidiPaint)
local VerticalText = {}

function VerticalText.measure(item: any, cell: number,em: number?)
	local spacing,wordSpacing=item.Style.LetterSpacing or 0,item.Style.WordSpacing or 0
	local cached=item.VerticalMeasure
	if cached and cached.Text==item.Text and cached.Cell==cell and cached.Em==em and cached.Spacing==spacing and cached.WordSpacing==wordSpacing then
		item.VerticalAdvance,item.VerticalEm,item.Width,item.VisualWidth,item.Height=cell,em,cached.Width,cached.VisualWidth,cached.Height
		return
	end
	if item.VerticalTextSource ~= item.Text then
		item.VerticalTextSource = item.Text
		item.VerticalCharacters = LetterSpacing.split(item.Text)
	end
	local cursor, edge, cross = 0, 0, 0
	for index, glyph in item.VerticalCharacters do
		if index > 1 then cursor += spacing end
		glyph.Advance = cursor
		-- Upright vertical scripts use their em advance. Horizontal-only
		-- scripts use the measured horizontal font cell when forced upright.
		-- A word may contain both, so one maximum cannot be every advance.
		glyph.Cell=if em and Orientation.cluster(glyph.Text)~='R'then em else cell
		cross=math.max(cross,glyph.Cell)
		edge = math.max(edge, cursor + glyph.Cell)
		cursor += glyph.Cell
		if glyph.Text == " " then cursor += wordSpacing end
	end
	item.VerticalAdvance,item.VerticalEm,item.Height = cell,em,cross
	item.Width, item.VisualWidth = math.max(0, cursor), edge
	item.VerticalMeasure={Text=item.Text,Cell=cell,Em=em,Spacing=spacing,WordSpacing=wordSpacing,Width=item.Width,VisualWidth=edge,Height=cross}
end

local function write(gui: any, key: string, value: any)
	if gui[key] ~= value then gui[key] = value end
end

function VerticalText.hide(item: any)
	for _, glyph in item.UprightPool or {} do glyph.Gui.Visible = false end
	for _, glyph in item.Glyphs or {} do glyph.Gui.Visible = true end
end

function VerticalText.place(run: any, item: any, x: number, y: number, width: number)
	local cell = item.Height
	local right = run.Style.WritingMode == "vertical-rl"
	local left = if right then width - item.Y - cell else item.Y
	item.PaintRect = {left, item.X, left + cell, item.X + item.Width}
	write(item.Gui, "AnchorPoint", Vector2.new(0, 0))
	write(item.Gui, "Rotation", 0)
	write(item.Gui, "Position", UDim2.fromOffset(x + left, y + item.X))
	write(item.Gui, "Size", UDim2.fromOffset(cell, math.max(1, item.Width)))
end

function VerticalText.paint(run: any, item: any, x: number, y: number, width: number)
	VerticalText.measure(item, item.VerticalAdvance,item.VerticalEm)
	VerticalText.place(run, item, x, y, width)
	local style, cell = item.Style, item.VerticalAdvance
	if not item.Glyphs then write(item.TextGui or item.Gui, "TextTransparency", 1) end
	for _, glyph in item.Glyphs or {} do glyph.Gui.Visible = false end
	for _, shadow in item.ShadowLabels or {} do shadow.Gui.Visible = false end
	item.UprightPool = item.UprightPool or {}
	for _, glyph in item.UprightPool do glyph.Gui.Visible = false end
	for index, character in item.VerticalCharacters do
		local glyph = item.UprightPool[index]
		if not glyph then
			glyph = {Kind = "Word", Style = style, Text = character.Text}
			glyph.Gui = run.Factory.create("Frame", item.Gui, {Name = "Upright_" .. index})
			glyph.TextGui = run.Factory.create("TextLabel", glyph.Gui, {Name = "Character", LineHeight = 1,
				TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = TextShadows.Foreground})
			TextShadows.create(glyph, run.Factory.create)
			item.UprightPool[index] = glyph
		end
		glyph.Text, glyph.Style = character.Text, style
		glyph.BidiDirection,glyph.NativeBidiForced=item.BidiDirection,item.NativeBidiForced
		local characterCell=character.Cell or cell
		glyph.Width, glyph.Height, glyph.TextSize, glyph.FontFace = characterCell,characterCell, item.TextSize, item.FontFace
		write(glyph.Gui, "Visible", true)
		write(glyph.Gui, "Position", UDim2.fromOffset((item.Height-characterCell)/2, character.Advance))
		write(glyph.Gui, "Size", UDim2.fromOffset(characterCell, characterCell))
		local label = glyph.TextGui
		write(label, "Text", BidiPaint.text(item,character.Text))
		write(label,"TextDirection",if item.BidiDirection=='rtl'then Enum.TextDirection.RightToLeft else Enum.TextDirection.LeftToRight)
		write(label, "FontFace", item.FontFace)
		write(label, "TextSize", item.TextSize)
		write(label, "OpenTypeFeatures", style.OpenTypeFeatures)
		write(label, "TextColor3", style.Color)
		write(label, "TextTransparency", if style.FontSize==0 or style.Visibility == "hidden" then 1 else 1 - (style.ColorAlpha or 1))
		write(label, "Size", UDim2.fromOffset(characterCell, characterCell))
		TextShadows.arrange(glyph)
	end
end

return VerticalText
