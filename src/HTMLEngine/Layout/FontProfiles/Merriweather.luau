--!strict
-- User-measured native Regular guides; browser correction is a single-pair estimate.
return {
	Name = "Merriweather normal",
	Family = "rbxasset://fonts/families/Merriweather.json",
	SizeMultiplier = 60 / 48,
	SizeMultiplierKnown = true,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.195, Intercept = -2 },
		XHeight = { Slope = 0.35, Intercept = -2 },
		Baseline = { Slope = 0.785, Intercept = 0.5 },
		Bottom = { Slope = 0.985, Intercept = 0.5 },
	},
	GuideSamples = {
		[20] = { Top = 2, XHeight = 5, Baseline = 16, Bottom = 20 },
		[40] = { Top = 6, XHeight = 12, Baseline = 32, Bottom = 40 },
		[60] = { Top = 9, XHeight = 19, Baseline = 48, Bottom = 60 },
		[80] = { Top = 14, XHeight = 26, Baseline = 63, Bottom = 79 },
		[16] = { Top = 2, XHeight = 4, Baseline = 13, Bottom = 16 },
	},
}
