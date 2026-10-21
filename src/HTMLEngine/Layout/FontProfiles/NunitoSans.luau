--!strict
-- User-measured native Regular guides; size correction is a single-pair estimate.
return {
	Name = "Nunito Sans normal",
	Family = "rbxassetid://12187363368",
	SizeMultiplier = 57 / 41,
	SizeMultiplierKnown = true,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.235, Intercept = -1 },
		XHeight = { Slope = 0.4, Intercept = -1.5 },
		Baseline = { Slope = 0.735, Intercept = 1 },
		Bottom = { Slope = 0.87, Intercept = 1 },
	},
	GuideSamples = {
		[20] = { Top = 4, XHeight = 7, Baseline = 16, Bottom = 19 },
		[40] = { Top = 8, XHeight = 14, Baseline = 30, Bottom = 35 },
		[60] = { Top = 13, XHeight = 22, Baseline = 45, Bottom = 53 },
		[80] = { Top = 18, XHeight = 31, Baseline = 60, Bottom = 71 },
		[16] = { Top = 3, XHeight = 6, Baseline = 13, Bottom = 15 },
	},
}
