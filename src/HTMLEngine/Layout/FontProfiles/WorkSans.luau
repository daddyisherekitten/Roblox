--!strict
-- User-measured native Regular guides; size correction is a single-pair estimate.
return {
	Name = "Work Sans normal",
	Family = "rbxassetid://12187373327",
	SizeMultiplier = 53 / 45,
	SizeMultiplierKnown = true,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.225, Intercept = -0.5 },
		XHeight = { Slope = 0.365, Intercept = -0.5 },
		Baseline = { Slope = 0.78, Intercept = 1.5 },
		Bottom = { Slope = 0.95, Intercept = 2 },
	},
	GuideSamples = {
		[20] = { Top = 4, XHeight = 7, Baseline = 17, Bottom = 21 },
		[40] = { Top = 9, XHeight = 14, Baseline = 33, Bottom = 40 },
		[60] = { Top = 12, XHeight = 21, Baseline = 48, Bottom = 59 },
		[80] = { Top = 18, XHeight = 29, Baseline = 64, Bottom = 78 },
		[16] = { Top = 2, XHeight = 4, Baseline = 13, Bottom = 16 },
	},
}
