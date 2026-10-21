--!strict
local HttpService = game:GetService("HttpService")
local FontReport = {}

-- Read on click, so the exported values always include the latest adjustments.
function FontReport.collect(rows: { GuiObject }, font: Enum.Font | string, scale: number, knownScale: boolean)
	local samples = {}
	for _, row in rows do
		local sample = row:FindFirstChild("MeasuredText") :: TextLabel
		assert(sample and sample:IsA("TextLabel"), "Text sample missing")
		local guides = {} :: { [string]: number }
		for _, key in { "Top", "XHeight", "Baseline", "Bottom" } do
			local value = row:GetAttribute("Manual" .. key .. "Offset")
			assert(typeof(value) == "number", "Missing guide " .. key)
			guides[key] = value
		end
		table.insert(samples, {
			fontName = row:GetAttribute("FontName"),
			measurementStatus = row:GetAttribute("MeasurementStatus"),
			htmlSize = row:GetAttribute("HtmlSize"),
			robloxTextSize = sample.TextSize,
			fontFamily = sample.FontFace.Family,
			fontWeight = sample.FontFace.Weight.Name,
			fontStyle = sample.FontFace.Style.Name,
			text = sample.Text,
			lineHeight = sample.LineHeight,
			textBounds = { width = sample.TextBounds.X, height = sample.TextBounds.Y },
			guideOrigin = "TextLabel top; pixels downward",
			guides = guides,
			startingGuideSource = row:GetAttribute("GuideSource"),
		})
	end
	return {
		schema = "roblox-font-report/v1",
		fontEnum = if typeof(font) == "string" then nil else (font :: Enum.Font).Name,
		fontName = if typeof(font) == "string" then font else (font :: Enum.Font).Name,
		sizeMultiplier = scale,
		textSizeRounding = "ceil",
		sizeMultiplierKnown = knownScale,
		kind = "current manual guide positions; not automatic font metrics",
		samples = samples,
	}
end

function FontReport.print(rows: { GuiObject }, font: Enum.Font | string, scale: number, knownScale: boolean)
	-- One print call makes the complete report easy to copy from Studio Output.
	print("FONT_REPORT " .. HttpService:JSONEncode(FontReport.collect(rows, font, scale, knownScale)))
end

return FontReport
