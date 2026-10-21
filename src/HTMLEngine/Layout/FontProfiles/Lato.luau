--!strict
-- User-measured Regular guides at native TextSize 10..80.
-- Size estimate from the user's 49px Roblox / 57px browser comparison.
-- Exact samples apply at measured native sizes; other guides use a linear fit.
return {
	Name = "Lato normal",
	Family = "rbxassetid://11598289817",
	SizeMultiplier = 57 / 49,
	SizeMultiplierKnown = true,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.22970577809287487, Intercept = -1.5585253456221195 },
		XHeight = { Slope = 0.4090747961715704, Intercept = -1.3539170506912455 },
		Baseline = { Slope = 0.825948245303084, Intercept = 0.5880184331797238 },
		Bottom = { Slope = 0.9709322935129386, Intercept = 0.7336405529953935 },
	},
	GuideSamples = {
		[10] = { Top = 1, XHeight = 3, Baseline = 9, Bottom = 11 },
		[14] = { Top = 1, XHeight = 4, Baseline = 12, Bottom = 14 },
		[16] = { Top = 3, XHeight = 6, Baseline = 14, Bottom = 16 },
		[20] = { Top = 3, XHeight = 7, Baseline = 17, Bottom = 20 },
		[30] = { Top = 5, XHeight = 10, Baseline = 25, Bottom = 30 },
		[40] = { Top = 8, XHeight = 15, Baseline = 34, Bottom = 40 },
		[50] = { Top = 9, XHeight = 19, Baseline = 42, Bottom = 49 },
		[60] = { Top = 12, XHeight = 23, Baseline = 50, Bottom = 59 },
		[70] = { Top = 15, XHeight = 27, Baseline = 58, Bottom = 68 },
		[80] = { Top = 17, XHeight = 32, Baseline = 67, Bottom = 79 },
	},
}
