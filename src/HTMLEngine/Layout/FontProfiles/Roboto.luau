--!strict
-- Regular: size confirmed at HTML 10–50 px with ceil(size * 1.13).
-- Guides fitted to the manual FONT_REPORT; maximum error at measured sizes: 1 px.
return {
	Name = "Roboto normal",
	Family = "rbxasset://fonts/families/Roboto.json",
	SizeMultiplier = 1.13,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.1680238020670216, Intercept = -0.5800187911055428 },
		XHeight = { Slope = 0.34481678672095206, Intercept = -1.0616974632007494 },
		Baseline = { Slope = 0.7962730974005637, Intercept = 0.6082054494206091 },
		Bottom = { Slope = 0.973222674600689, Intercept = 0.5211399937362984 },
	},
}
