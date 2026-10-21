--!strict
-- User-measured native Regular guides; size correction is a single-pair estimate.
return {
	Name = "Montserrat normal",
	Family = "rbxasset://fonts/families/Montserrat.json",
	SizeMultiplier = 56 / 46,
	SizeMultiplierKnown = true,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.21, Intercept = -0.5 },
		XHeight = { Slope = 0.345, Intercept = 0 },
		Baseline = { Slope = 0.78, Intercept = 1.5 },
		Bottom = { Slope = 0.945, Intercept = 1.5 },
	},
	GuideSamples = {
		[20] = { Top = 4, XHeight = 7, Baseline = 17, Bottom = 20 },
		[40] = { Top = 8, XHeight = 14, Baseline = 33, Bottom = 40 },
		[60] = { Top = 11, XHeight = 20, Baseline = 48, Bottom = 58 },
		[80] = { Top = 17, XHeight = 28, Baseline = 64, Bottom = 77 },
		[16] = { Top = 1, XHeight = 4, Baseline = 13, Bottom = 16 },
	},
}
