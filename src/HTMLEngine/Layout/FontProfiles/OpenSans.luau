--!strict
-- Open Sans Regular: five H-height pairs suggest ~1.34. Verify with ceil enabled.
-- Guides fitted to the manual FONT_REPORT at ceil(size * 1.34); maximum measured error 1 px.
return {
	Name = "Open Sans normal",
	Family = "rbxassetid://11598121416",
	SizeMultiplier = 1.34,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.2482477956138368, Intercept = -0.47886050192177443 },
		XHeight = { Slope = 0.3911372371693421, Intercept = -0.8801718290752909 },
		Baseline = { Slope = 0.7744743386841512, Intercept = 1.1563418494234625 },
		Bottom = { Slope = 0.9473208229708344, Intercept = 1.5387745873841183 },
	},
}
