--!strict
return function(engineRoot: Instance)
	local Factory = require(engineRoot.Rendering.GuiFactory)
	local labRoot = engineRoot:WaitForChild("Examples"):WaitForChild("FontLab")
	local Report = require(labRoot.FontReport)
	local row = Factory.create("Frame", nil, {})
	local sample = Factory.create("TextLabel", row, { Name = "MeasuredText", Text = "H x p", TextSize = 56.5 }) :: TextLabel
	row:SetAttribute("HtmlSize", 50)
	row:SetAttribute("GuideSource", "fitted")
	for key, value in { Top = 8, XHeight = 16, Baseline = 45, Bottom = 56 } do
		row:SetAttribute("Manual" .. key .. "Offset", value)
	end
	local initialTextSize = sample.TextSize
	local before = Report.collect({ row }, Enum.Font.Arial, 1.13, true)
	row:SetAttribute("ManualXHeightOffset", 18)
	sample.TextSize = 60.25
	local after = Report.collect({ row }, Enum.Font.Arial, 1.13, true)
	assert(before.samples[1].guides.XHeight == 16)
	assert(after.samples[1].guides.XHeight == 18, "Report must read current positions")
	-- Compare stored values: Roblox may normalize an assigned fractional TextSize.
	assert(before.samples[1].robloxTextSize == initialTextSize)
	assert(after.samples[1].robloxTextSize == sample.TextSize, "Report must read current TextSize")
	assert(after.samples[1].htmlSize == 50)
	assert(after.fontEnum == Enum.Font.Arial.Name and after.sizeMultiplier == 1.13)
	sample.FontFace = Font.new("rbxassetid://12187368625")
	local assetReport = Report.collect({ row }, "Roboto Slab", 1, false)
	assert(assetReport.fontName == "Roboto Slab" and assetReport.fontEnum == nil)
	assert(assetReport.samples[1].fontFamily == "rbxassetid://12187368625")
	assert(not assetReport.sizeMultiplierKnown, "Neutral size must not imply calibration")
	assert(not sample.Active)
	row:Destroy()
end
