--!strict
-- Ubuntu Regular: size visually confirmed at HTML 10–50 px.
-- Guides fitted against requested Roblox size (HTML size * 1.09), not stored TextSize.
-- Manual measurements: measurements/ubuntu-guide-fit.json; maximum fit error 1 px.
return {
	Name = "Ubuntu normal",
	SizeMultiplier = 1.09,
	Guides = {
		Top = { Slope = 0.2110091743119266, Intercept = -1.3000000000000007 },
		XHeight = { Slope = 0.37614678899082565, Intercept = -1.5 },
		Baseline = { Slope = 0.8256880733944953, Intercept = 0 },
		Bottom = { Slope = 1, Intercept = -0.10000000000000142 },
	},
}
