--!strict
-- Inter Regular: size confirmed at HTML 10–50 px with ceil(size * 1.18).
-- Manual guide fit: measurements/inter-guide-fit.json; maximum measured error 1 px.
return {
	Name = "Inter normal",
	Family = "rbxassetid://12187365364",
	SizeMultiplier = 1.18,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.1951464675473866, Intercept = -1.1862435381964396 },
		XHeight = { Slope = 0.33902929350947736, Intercept = -0.9372487076392897 },
		Baseline = { Slope = 0.8051407237219991, Intercept = 0.5759620907524337 },
		Bottom = { Slope = 0.9833429063756465, Intercept = 0.3963239517518602 },
	},
}
