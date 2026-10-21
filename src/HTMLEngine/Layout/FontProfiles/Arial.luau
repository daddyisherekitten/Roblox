--!strict
-- Arial regular only. Fitted to the manual report at ceil(HTML size * 1.13).
-- Maximum rounded error at the nine measured sizes is 1 px (zero for Baseline).
return {
	Name = "Arial normal",
	SizeMultiplier = 1.13,
	GuideSizeRounding = "ceil",
	Guides = {
		Top = { Slope = 0.1659746657283603, Intercept = -0.8187895847994374 },
		XHeight = { Slope = 0.32390921885995777, Intercept = -1.1423293455313166 },
		Baseline = { Slope = 0.7837614356087262, Intercept = 0.9980647431386337 },
		Bottom = { Slope = 0.9673469387755103, Intercept = 1.4489795918367336 },
	},
}
