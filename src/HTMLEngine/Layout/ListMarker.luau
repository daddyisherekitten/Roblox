--!strict
local FontMetrics = require(script.Parent.FontMetrics)
local Profiles = require(script.Parent.FontProfiles)
local TextMeasure = require(script.Parent.TextMeasure)
local Counters=require(script.Parent.Parent.CSS.Counters)
local ListMarker = {}
local function write(gui: any, key: string, value: any)
	if gui[key] ~= value then gui[key] = value end
end

function ListMarker.arrange(marker: any, style: any, baseline: number, left: number, alive: () -> boolean): boolean
	if marker.Arrange then
		if marker.MeasureOnly then assert(marker.Measure,'A custom marker needs a pure measurement path');marker:Measure(style);return true end
		return marker:Arrange(style,baseline,left)
	end
	style=marker.Style or style
	local metrics = FontMetrics.resolve(style)
	if marker.Kind=="image" then
		local size=math.max(1,math.round(style.FontSize))
		marker.Width,marker.Height=size+7,size
		write(marker.Gui,"Position",UDim2.fromOffset(if style.ListStylePosition=="inside" then left else left-size-7,baseline-metrics.Baseline))
		write(marker.Gui,"Size",UDim2.fromOffset(size,size))
	elseif marker.Kind ~= "disc" and marker.Kind ~= "circle" and marker.Kind ~= "square" then
		local text = marker.CustomText or Counters.formatRegistry(style.CounterStyles,marker.Number,marker.Kind,true)
		local weight, variant = style.FontWeight or 400, style.FontStyle or "normal"
		local font = (marker.ResolveFont or Profiles.face)(style.Font, weight, variant)
		local bounds=marker.NativeMarkerBounds
		if bounds and bounds.Text==text and bounds.Font==style.Font and bounds.Size==metrics.TextSize and bounds.Weight==weight and bounds.Variant==variant then
			marker.Text,marker.Font,marker.Size,marker.Weight,marker.Variant=bounds.Text,bounds.Font,bounds.Size,bounds.Weight,bounds.Variant
			marker.Width,marker.Height=bounds.Width,bounds.Height
		end
		if marker.Text ~= text or marker.Font ~= style.Font or marker.Size ~= metrics.TextSize
			or marker.Weight ~= weight or marker.Variant ~= variant then
			local bounds, message = TextMeasure.measure(text, font, metrics.TextSize, 0)
			if not alive() then return false end
			assert(bounds, "List marker measurement failed: " .. tostring(message))
			marker.Width, marker.Height = bounds.X, math.max(metrics.TextSize, bounds.Y)
			marker.Text, marker.Font, marker.Size = text, style.Font, metrics.TextSize
			marker.Weight, marker.Variant = weight, variant
		end
		write(marker.Gui, "Text", text)
		write(marker.Gui, "TextColor3", style.Color)
		write(marker.Gui, "TextTransparency", 1 - (style.ColorAlpha or 1))
		write(marker.Gui, "FontFace", font)
		write(marker.Gui, "TextSize", metrics.TextSize)
		write(marker.Gui, "OpenTypeFeatures", style.OpenTypeFeatures)
		write(marker.Gui, "Position", UDim2.fromOffset((if style.ListStylePosition == "inside" then left else left - marker.Width), baseline - metrics.Baseline))
		write(marker.Gui, "Size", UDim2.fromOffset(math.max(1, marker.Width), marker.Height))
	else
		-- Blink-like symbol geometry. Roblox does not expose true font ascent,
		-- so the existing baseline guide is used as its approximation.
		local ascent = math.max(1, math.round(metrics.Baseline))
		local offset = math.floor(ascent * 2 / 3)
		local size = math.max(1, math.floor((offset + 1) / 2))
		marker.Width, marker.Height = offset + 7, metrics.TextSize
		write(marker.Gui, "Position", UDim2.fromOffset(if style.ListStylePosition == "inside" then left + 1 else left - offset - 7, baseline - ascent + math.floor(3 * (ascent - offset) / 2)))
		write(marker.Gui, "Size", UDim2.fromOffset(size, size))
	end
	marker.Baseline = baseline
	return true
end

return ListMarker
