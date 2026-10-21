--!strict
return function(profiles: any)
	local families = {
		["Open Sans"] = "rbxassetid://11598121416",
		["Inter"] = "rbxassetid://12187365364",
		["Roboto"] = "rbxasset://fonts/families/Roboto.json",
		["Roboto Condensed"] = "rbxasset://fonts/families/RobotoCondensed.json",
		["Roboto Mono"] = "rbxasset://fonts/families/RobotoMono.json",
		["PT Serif"] = "rbxassetid://12187606624",
		["Roboto Slab"] = "rbxassetid://12187368625",
	}
	local seen = {}
	for name, family in families do
		local profile = profiles.get(name)
		assert(profile and profile.Family == family, "Wrong font family: " .. name)
		assert(not seen[profile], "Each family needs an independent profile")
		seen[profile] = true
		if name == "Roboto" then
			assert(profile.SizeMultiplier == 1.13, "Roboto size estimate from five measurements")
			assert(profile.GuideSizeRounding == "ceil")
			for index, observed in { { 1, 3, 10, 12 }, { 4, 7, 19, 23 }, { 5, 11, 28, 34 }, { 7, 14, 37, 45 }, { 9, 19, 46, 56 } } do
				local size = index * 10 * profile.SizeMultiplier
				local guides = profiles.guides(profile, size)
				local rounded = profiles.guides(profile, math.ceil(size))
				assert(guides and rounded, "Roboto guides must exist")
				for position, key in { "Top", "XHeight", "Baseline", "Bottom" } do
					assert(math.abs(guides[key] - observed[position]) <= 1, "Roboto guide exceeds measured tolerance: " .. key)
					assert(guides[key] == rounded[key], "Guide input must use the same ceil as TextSize")
				end
			end
		elseif name == "Inter" then
			assert(profile.SizeMultiplier == 1.18, "Inter confirmed size factor")
			assert(profile.GuideSizeRounding == "ceil")
			for index, observed in { { 1, 3, 10, 12 }, { 3, 7, 20, 24 }, { 7, 12, 30, 36 }, { 8, 15, 39, 48 }, { 10, 19, 48, 58 } } do
				local size = index * 10 * profile.SizeMultiplier
				local guides = profiles.guides(profile, size)
				local rounded = profiles.guides(profile, math.ceil(size))
				assert(guides and rounded, "Inter guides must exist")
				for position, key in { "Top", "XHeight", "Baseline", "Bottom" } do
					assert(math.abs(guides[key] - observed[position]) <= 1, "Inter guide exceeds measured tolerance: " .. key)
					assert(guides[key] == rounded[key], "Inter guides must use ceil TextSize")
				end
			end
		elseif name == "Open Sans" then
			assert(profile.SizeMultiplier == 1.34, "Open Sans size estimate from five measurements")
			assert(profile.GuideSizeRounding == "ceil")
			for index, observed in { { 3, 5, 12, 15 }, { 6, 9, 22, 27 }, { 10, 15, 33, 40 }, { 13, 21, 43, 53 }, { 16, 25, 53, 65 } } do
				local size = index * 10 * profile.SizeMultiplier
				local guides = profiles.guides(profile, size)
				local rounded = profiles.guides(profile, math.ceil(size))
				assert(guides and rounded, "Open Sans guides must exist")
				for position, key in { "Top", "XHeight", "Baseline", "Bottom" } do
					assert(math.abs(guides[key] - observed[position]) <= 1, "Open Sans guide exceeds measured tolerance: " .. key)
					assert(guides[key] == rounded[key], "Open Sans guides must use ceil TextSize")
				end
			end
		elseif name == "PT Serif" then
			assert(profile.SizeMultiplier == 1990 / 1626 and profile.GuideSizeRounding == "ceil")
			local sizes = {13, 25, 37, 49, 62}
			for index, observed in {{2, 4, 11, 14}, {5, 9, 20, 24}, {8, 14, 30, 36}, {11, 19, 39, 47}, {14, 24, 49, 59}} do
				local guides = profiles.guides(profile, index * 10 * profile.SizeMultiplier)
				local native = profiles.guides(profile, sizes[index])
				assert(guides and native)
				for position, key in {"Top", "XHeight", "Baseline", "Bottom"} do
					assert(guides[key] == native[key], "PT Serif guides must use native ceil TextSize")
					assert(math.abs(guides[key] - observed[position]) <= (if key == "Bottom" then 1 else 0), "PT Serif guide fit: " .. key)
				end
			end
		elseif name == "Roboto Mono" then
			assert(profile.SizeMultiplier == 1.24, "Roboto Mono size estimate from five measurements")
			assert(profile.GuideSizeRounding == "ceil")
			for index, observed in { { 1, 3, 9, 11 }, { 4, 7, 17, 20 }, { 7, 11, 25, 30 }, { 10, 15, 33, 39 }, { 12, 19, 41, 49 } } do
				-- Report used neutral TextSize, not the later corrected HTML sizes.
				local guides = profiles.guides(profile, index * 10)
				assert(guides)
				for position, key in { "Top", "XHeight", "Baseline", "Bottom" } do
					assert(math.abs(guides[key] - observed[position]) <= 1, "Roboto Mono guide exceeds measured tolerance: " .. key)
				end
			end
			local corrected = profiles.guides(profile, 30 * profile.SizeMultiplier)
			local rounded = profiles.guides(profile, 38)
			assert(corrected and rounded and corrected.Baseline == 31)
			for _, key in { "Top", "XHeight", "Baseline", "Bottom" } do
				assert(corrected[key] == rounded[key], "Roboto Mono guides must use ceil TextSize")
			end
		else
			assert(profile.SizeMultiplier == nil, "Uncalibrated families still need their own measurements")
			assert(profiles.guides(profile, 50) == nil, "Do not borrow another font's guides")
		end
	end
	assert(profiles.get("Unregistered font") == nil)
	local work = profiles.get("Work Sans")
	assert(work and work.Family == "rbxassetid://12187373327" and work.SizeMultiplier == 53 / 45)
	local workSizes = {20,40,60,80,16}
	local workObserved = {{4,7,17,21},{9,14,33,40},{12,21,48,59},{18,29,64,78},{2,4,13,16}}
	for index,size in workSizes do
		local guides = profiles.guides(work,size)
		for position,key in {"Top","XHeight","Baseline","Bottom"} do assert(guides[key] == workObserved[index][position]) end
		guides.Top = -100
		assert(profiles.guides(work,size).Top == workObserved[index][1])
	end
	local poppins = profiles.get("Poppins")
	assert(poppins and poppins.Family == "rbxassetid://11702779409" and poppins.SizeMultiplier == 56 / 40)
	for size = 1,100 do
		local guides = profiles.guides(poppins,size)
		assert(guides.Top <= guides.XHeight and guides.XHeight <= guides.Baseline and guides.Baseline <= guides.Bottom)
	end
	local poppinsSizes = {20,40,60,80,16}
	local poppinsObserved = {{4,6,15,19},{8,12,29,36},{12,18,43,54},{16,25,57,72},{2,4,12,15}}
	for index,size in poppinsSizes do
		local guides = profiles.guides(poppins,size)
		for position,key in {"Top","XHeight","Baseline","Bottom"} do assert(guides[key] == poppinsObserved[index][position]) end
		guides.Top = -100
		assert(profiles.guides(poppins,size).Top == poppinsObserved[index][1])
	end
	local playfair = profiles.get("Playfair Display")
	assert(playfair and playfair.Family == "rbxassetid://12187374765" and playfair.SizeMultiplier == 57 / 42)
	local playfairSizes = {20,40,60,80,16}
	local playfairObserved = {{5,8,17,20},{11,16,33,38},{17,25,50,58},{23,34,66,77},{4,6,14,16}}
	for index,size in playfairSizes do
		local guides = profiles.guides(playfair,size)
		for position,key in {"Top","XHeight","Baseline","Bottom"} do assert(guides[key] == playfairObserved[index][position]) end
		guides.Top = -100
		assert(profiles.guides(playfair,size).Top == playfairObserved[index][1])
	end
	local nunito = profiles.get("Nunito Sans")
	assert(nunito and nunito.Family == "rbxassetid://12187363368" and nunito.SizeMultiplier == 57 / 41)
	local nunitoSizes = {20,40,60,80,16}
	local nunitoObserved = {{4,7,16,19},{8,14,30,35},{13,22,45,53},{18,31,60,71},{3,6,13,15}}
	for index,size in nunitoSizes do
		local guides = profiles.guides(nunito,size)
		for position,key in {"Top","XHeight","Baseline","Bottom"} do assert(guides[key] == nunitoObserved[index][position]) end
		guides.Top = -100
		assert(profiles.guides(nunito,size).Top == nunitoObserved[index][1])
	end
	local noto = profiles.get("Noto Sans")
	assert(noto and noto.Family == "rbxassetid://12187370747" and noto.SizeMultiplier == 58 / 43)
	local notoSizes = {20,40,60,80,16}
	local notoObserved = {{3,6,16,20},{9,14,32,39},{14,22,48,59},{20,31,64,78},{3,5,13,16}}
	for index,size in notoSizes do
		local guides = profiles.guides(noto,size)
		for position,key in {"Top","XHeight","Baseline","Bottom"} do assert(guides[key] == notoObserved[index][position]) end
		guides.Top = -100
		assert(profiles.guides(noto,size).Top == notoObserved[index][1])
	end
	local montserrat = profiles.get("Montserrat")
	assert(montserrat and montserrat.Family == "rbxasset://fonts/families/Montserrat.json" and montserrat.SizeMultiplier == 56 / 46)
	local montserratSizes = {20,40,60,80,16}
	local montserratObserved = {{4,7,17,20},{8,14,33,40},{11,20,48,58},{17,28,64,77},{1,4,13,16}}
	for index,size in montserratSizes do
		local guides = profiles.guides(montserrat,size)
		for position,key in {"Top","XHeight","Baseline","Bottom"} do assert(guides[key] == montserratObserved[index][position]) end
		guides.Top = -100
		assert(profiles.guides(montserrat,size).Top == montserratObserved[index][1])
	end
	local merriweather = profiles.get("Merriweather")
	assert(merriweather and merriweather.Family == "rbxasset://fonts/families/Merriweather.json" and merriweather.SizeMultiplier == 60 / 48)
	local merriweatherSizes = {20,40,60,80,16}
	local merriweatherObserved = {{2,5,16,20},{6,12,32,40},{9,19,48,60},{14,26,63,79},{2,4,13,16}}
	for index,size in merriweatherSizes do
		local guides = profiles.guides(merriweather,size)
		for position,key in {"Top","XHeight","Baseline","Bottom"} do assert(guides[key] == merriweatherObserved[index][position]) end
		guides.Top = -100
		assert(profiles.guides(merriweather,size).Top == merriweatherObserved[index][1])
	end
	local lora = profiles.get("Lora")
	assert(lora and lora.Family == "rbxassetid://12187366657" and lora.SizeMultiplier == 56 / 45)
	local loraSizes = {20,40,60,80,16}
	local loraObserved = {{4,7,17,21},{8,15,32,40},{13,23,48,60},{18,31,64,80},{3,5,13,16}}
	for index,size in loraSizes do
		local guides = profiles.guides(lora,size)
		for position,key in {"Top","XHeight","Baseline","Bottom"} do assert(guides[key] == loraObserved[index][position]) end
		guides.Top = -100
		assert(profiles.guides(lora,size).Top == loraObserved[index][1])
	end
	local lato = profiles.get("Lato")
	assert(lato and lato.Family == "rbxassetid://11598289817" and lato.SizeMultiplier == 57 / 49)
	local latoSizes = {10,14,16,20,30,40,50,60,70,80}
	local latoObserved = {{1,3,9,11},{1,4,12,14},{3,6,14,16},{3,7,17,20},{5,10,25,30},{8,15,34,40},{9,19,42,49},{12,23,50,59},{15,27,58,68},{17,32,67,79}}
	for index,size in latoSizes do
		local guides=profiles.guides(lato,size)
		for position,key in {"Top","XHeight","Baseline","Bottom"} do assert(guides[key]==latoObserved[index][position],"Preserve the user's measured Lato guides") end
		guides.Top=-100
		assert(profiles.guides(lato,size).Top==latoObserved[index][1],"Returned samples cannot mutate the profile")
	end
	assert(profiles.get(Enum.Font.Ubuntu).SizeMultiplier == 1.09)
	local arial = profiles.get(Enum.Font.Arial)
	assert(arial.SizeMultiplier == 1.13 and arial.GuideSizeRounding == "ceil")
	local arialSizes = { 10, 16, 20, 30, 40, 50, 60, 70, 80 }
	local arialObserved = {
		{ 1, 3, 10, 12 }, { 2, 5, 16, 20 }, { 3, 6, 19, 24 },
		{ 5, 10, 28, 35 }, { 7, 13, 37, 46 }, { 9, 18, 46, 57 },
		{ 11, 21, 54, 67 }, { 12, 25, 64, 79 }, { 14, 28, 72, 89 },
	}
	for index, size in arialSizes do
		local guides = profiles.guides(arial, size * arial.SizeMultiplier)
		local rounded = profiles.guides(arial, math.ceil(size * arial.SizeMultiplier))
		assert(guides and rounded)
		for position, key in { "Top", "XHeight", "Baseline", "Bottom" } do
			assert(guides[key] == rounded[key], "Arial guides must use the actual ceil TextSize")
			assert(math.abs(guides[key] - arialObserved[index][position]) <= 1, "Arial guide fit: " .. key)
		end
	end
	print("Font profiles: independent families; existing calibrations preserved")
end
