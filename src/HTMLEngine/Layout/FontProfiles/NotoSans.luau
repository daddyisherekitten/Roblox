--!strict
-- User-measured native Regular guides; size correction is a single-pair estimate.
return {
	Name = "Noto Sans normal",
	Family = "rbxassetid://12187370747",
	SizeMultiplier = 58 / 43,
	SizeMultiplierKnown = true,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.28, Intercept = -2.5000000000000018 },
		XHeight = { Slope = 0.415, Intercept = -2.5 },
		Baseline = { Slope = 0.8, Intercept = 0 },
		Bottom = { Slope = 0.97, Intercept = 0.5 },
	},
	GuideSamples = {
		[20] = { Top = 3, XHeight = 6, Baseline = 16, Bottom = 20 },
		[40] = { Top = 9, XHeight = 14, Baseline = 32, Bottom = 39 },
		[60] = { Top = 14, XHeight = 22, Baseline = 48, Bottom = 59 },
		[80] = { Top = 20, XHeight = 31, Baseline = 64, Bottom = 78 },
		[16] = { Top = 3, XHeight = 5, Baseline = 13, Bottom = 16 },
	},
}
