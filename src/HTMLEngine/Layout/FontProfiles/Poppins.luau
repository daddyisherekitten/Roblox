--!strict
-- User-measured native Regular guides; size correction is a single-pair estimate.
return {
	Name = "Poppins normal",
	Family = "rbxassetid://11702779409",
	SizeMultiplier = 56 / 40,
	SizeMultiplierKnown = true,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.2, Intercept = 0 },
		XHeight = { Slope = 0.315, Intercept = -0.5 },
		Baseline = { Slope = 0.7, Intercept = 1 },
		Bottom = { Slope = 0.885, Intercept = 1 },
	},
	GuideSamples = {
		[20] = { Top = 4, XHeight = 6, Baseline = 15, Bottom = 19 },
		[40] = { Top = 8, XHeight = 12, Baseline = 29, Bottom = 36 },
		[60] = { Top = 12, XHeight = 18, Baseline = 43, Bottom = 54 },
		[80] = { Top = 16, XHeight = 25, Baseline = 57, Bottom = 72 },
		[16] = { Top = 2, XHeight = 4, Baseline = 12, Bottom = 15 },
	},
}
