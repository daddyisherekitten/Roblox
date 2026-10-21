--!strict
-- User-measured native Regular guides; browser size correction is a single-pair estimate.
return {
	Name = "Lora normal",
	Family = "rbxassetid://12187366657",
	SizeMultiplier = 56 / 45,
	SizeMultiplierKnown = true,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.235, Intercept = -1 },
		XHeight = { Slope = 0.4, Intercept = -1 },
		Baseline = { Slope = 0.785, Intercept = 1 },
		Bottom = { Slope = 0.985, Intercept = 1 },
	},
	GuideSamples = {
		[20] = { Top = 4, XHeight = 7, Baseline = 17, Bottom = 21 },
		[40] = { Top = 8, XHeight = 15, Baseline = 32, Bottom = 40 },
		[60] = { Top = 13, XHeight = 23, Baseline = 48, Bottom = 60 },
		[80] = { Top = 18, XHeight = 31, Baseline = 64, Bottom = 80 },
		[16] = { Top = 3, XHeight = 5, Baseline = 13, Bottom = 16 },
	},
}
