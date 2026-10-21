--!strict
-- Regular: size factor 1.24 visually confirmed at HTML 10–50 px with ceil.
-- Guides fit native TextSize 10–50, measured before scaling; larger sizes extrapolate.
return {
	Name = "Roboto Mono normal",
	Family = "rbxasset://fonts/families/RobotoMono.json",
	SizeMultiplier = 1.24,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.28, Intercept = -1.6 },
		XHeight = { Slope = 0.4, Intercept = -1 },
		Baseline = { Slope = 0.8, Intercept = 1 },
		Bottom = { Slope = 0.95, Intercept = 1.3 },
	},
}
