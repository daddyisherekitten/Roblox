--!strict
-- Sharp text copies: reuse final text/glyph geometry, never measure shadows.
local Color = require(script.Parent.Parent.CSS.Color)
local BidiPaint=require(script.Parent.Parent.Layout.BidiPaint)
local TextShadows = {}
TextShadows.Foreground = 17 -- CSS parser accepts at most 16 shadow layers.

function TextShadows.enabled(style: any): boolean
	if style.Visibility == "hidden" then return false end
	for _, shadow in style.TextShadows or {} do if Color.opacity(shadow, style) > 0 then return true end end
	return false
end

function TextShadows.create(item: any, create: any)
	item.ShadowFactory=create
	if not TextShadows.enabled(item.Style) then return end
	if not item.TextGui and not item.Glyphs and item.Gui and(item.Gui:IsA('TextLabel')or item.Gui:IsA('TextButton'))then
		-- A shadow added after initial render still needs sibling paint layers.
		-- Retain the original hit/source GUI as their parent; do not rebuild it.
		item.TextGui=create('TextLabel',item.Gui,{Name='Foreground',Text=item.Gui.Text or item.Text,LineHeight=1,
			FontFace=item.FontFace or item.Gui.FontFace,TextSize=item.TextSize or item.Gui.TextSize,
			TextColor3=item.Style.Color,TextTransparency=1-(item.Style.ColorAlpha or 1),
			TextDirection=item.Gui.TextDirection,OpenTypeFeatures=item.Style.OpenTypeFeatures,Size=item.Gui.Size,ZIndex=TextShadows.Foreground})
		item.Gui.TextTransparency=1
	end
	item.ShadowLabels = item.ShadowLabels or {}
	for index, shadow in item.Style.TextShadows do
		if Color.opacity(shadow, item.Style) == 0 then continue end
		local shapes = item.Glyphs or {item}
		for shapeIndex, shape in shapes do
			local existing
			for _,copy in item.ShadowLabels do if copy.Index==index and copy.ShapeIndex==shapeIndex then existing=copy;break end end
			if existing then existing.Shape=shape;continue end
			local label = create("TextLabel", item.Gui, {
				Name = "TextShadow_" .. index, Text = shape.Text, LineHeight = 1,
				TextColor3 = if shadow.Color == "currentcolor" then item.Style.Color else shadow.Color,
				TextTransparency = 1 - Color.opacity(shadow, item.Style), ZIndex = TextShadows.Foreground - index,
				Visible = false,
			})
			table.insert(item.ShadowLabels, {Gui = label, Shape = shape, Index = index,ShapeIndex=shapeIndex})
		end
	end
end

local function write(gui: any, key: string, value: any)
	if gui[key] ~= value then gui[key] = value end
end

function TextShadows.arrange(item: any)
	if item.ShadowFactory then TextShadows.create(item,item.ShadowFactory)end
	for _, copy in item.ShadowLabels or {} do
		local shadow = (item.Style.TextShadows or {})[copy.Index]
		local gui, shape = copy.Gui, if item.Glyphs then item.Glyphs[copy.ShapeIndex]else copy.Shape
		-- A source-scope repartition can publish colors before its required first
		-- layout. Keep newly created slots hidden until final glyph geometry exists.
		local visible = shape~=nil and type(shape.Width)=="number" and type(shape.Height)=="number" and item.Style.FontSize~=0 and item.Style.Visibility ~= "hidden" and shadow ~= nil and Color.opacity(shadow, item.Style) > 0
		write(gui, "Visible", visible)
		if not visible then continue end
		write(gui, "Text", BidiPaint.text(item,shape.Text))
		if item.BidiDirection then write(gui,"TextDirection",if item.BidiDirection=='rtl'then Enum.TextDirection.RightToLeft else Enum.TextDirection.LeftToRight)end
		write(gui, "FontFace", item.FontFace)
		write(gui, "TextSize", item.TextSize)
		write(gui, "OpenTypeFeatures", item.Style.OpenTypeFeatures)
		write(gui, "TextColor3", if shadow.Color == "currentcolor" then item.Style.Color else shadow.Color)
		write(gui, "TextTransparency", 1 - Color.opacity(shadow, item.Style))
		-- CSS shadow offsets are physical right/down distances. The word's
		-- native vertical glyph rotation must not rotate those distances again.
		local x,y=shadow.X,shadow.Y
		local rotation=item.ShadowRotation or(item.Gui and item.Gui.Rotation)or 0
		if rotation==90 then x,y=y,-x elseif rotation==-90 then x,y=-y,x end
		write(gui, "Position", UDim2.fromOffset((if item.Glyphs then BidiPaint.glyphX(item,shape) else 0)+x,y))
		write(gui, "Size", UDim2.fromOffset(math.max(1, shape.Width), shape.Height))
	end
end

return TextShadows
