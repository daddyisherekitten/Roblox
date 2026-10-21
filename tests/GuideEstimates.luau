--!strict
return function(profiles: any)
	local arial = profiles.get(Enum.Font.Arial)
	local function calculate(size: number) return profiles.guides(arial, size * arial.SizeMultiplier) end
	for size = 1, 100, 0.5 do
		local value = calculate(size)
		assert(value.Top <= value.XHeight and value.XHeight <= value.Baseline and value.Baseline <= value.Bottom)
	end
	-- Fresh user x-line measurements from the rounded TextSize report.
	for size, observed in { [60] = 21, [70] = 25, [80] = 28 } do
		local value = calculate(size)
		assert(math.abs(value.XHeight - observed) <= 1)
	end
	local original = calculate(30)
	local expected = original.Top
	original.Top = 999
	assert(calculate(30).Top == expected)
	for _, size in { 0, -1, math.huge, 0 / 0 } do
		assert(calculate(size) == nil)
	end
	assert(profiles.guides(profiles.get(Enum.Font.SourceSans), 20) == nil)
	local ubuntu = profiles.get(Enum.Font.Ubuntu)
	-- Manual Ubuntu observations; the fitted model is allowed one pixel of error.
	for index, observed in { { 1, 3, 9, 11 }, { 3, 6, 18, 22 }, { 6, 11, 27, 32 }, { 8, 15, 36, 43 }, { 10, 19, 45, 55 } } do
		local guides = profiles.guides(ubuntu, index * 10 * ubuntu.SizeMultiplier)
		assert(guides, "Ubuntu guides must be calibrated")
		for position, key in { "Top", "XHeight", "Baseline", "Bottom" } do
			assert(math.abs(guides[key] - observed[position]) <= 1, "Ubuntu guide exceeds measurement tolerance: " .. key)
		end
	end
end
