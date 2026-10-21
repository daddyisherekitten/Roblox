--!strict
-- User-measured native Regular guides; size correction is a single-pair estimate.
return {
	Name = "Playfair Display normal",
	Family = "rbxassetid://12187374765",
	SizeMultiplier = 57 / 42,
	SizeMultiplierKnown = true,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.3, Intercept = -1 },
		XHeight = { Slope = 0.435, Intercept = -1 },
		Baseline = { Slope = 0.82, Intercept = 0.5 },
		Bottom = { Slope = 0.955, Intercept = 0.5 },
	},
	GuideSamples = {
		[20] = { Top = 5, XHeight = 8, Baseline = 17, Bottom = 20 },
		[40] = { Top = 11, XHeight = 16, Baseline = 33, Bottom = 38 },
		[60] = { Top = 17, XHeight = 25, Baseline = 50, Bottom = 58 },
		[80] = { Top = 23, XHeight = 34, Baseline = 66, Bottom = 77 },
		[16] = { Top = 4, XHeight = 6, Baseline = 14, Bottom = 16 },
	},
}
