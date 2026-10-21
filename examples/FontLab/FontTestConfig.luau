--!strict
-- Only one family is displayed at a time.
-- Arial is Enum.Font.Arial; asset-backed families use their registered string name.
return {
	Font = "Work Sans",
	-- The same regular face as comparison entry 124. No engine calibration yet.
	TestProfile = {
		Name = "Work Sans normal",
		Family = "rbxassetid://12187373327",
		SizeMultiplier = nil,
		Guides = {},
	},
	-- Neutral starting point, to be replaced only after the manual comparison.
	TestSizeMultiplier = 1,
	UseGuidePreset = false,
	-- Four fitting sizes, followed by a small-text control measurement.
	Sizes = { 20, 40, 60, 80, 16 },
}
