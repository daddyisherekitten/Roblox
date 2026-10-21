--!strict
-- Regular size visually confirmed against Times New Roman; retain the chosen factor.
-- Guides fit native TextSize 13/25/37/49/62; maximum rounded error is 1 px (Bottom).
return {
	Name = "PT Serif normal",
	Family = "rbxassetid://12187606624",
	SizeMultiplier = 1990 / 1626,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.2458355722729715, Intercept = -1.1450832885545394 },
		XHeight = { Slope = 0.40972595378828586, Intercept = -1.2418054809242336 },
		Baseline = { Slope = 0.7786136485760344, Intercept = 0.8355722729715183 },
		Bottom = { Slope = 0.9262493283181086, Intercept = 1.5435249865663594 },
	},
}
