--!strict
return function(Parser: any, Style: any, Metrics: any, loadRenderTree: any, loadWordLayout: any, loadFontProfiles: any)
 local fixtureElement=require('DOM/Node').element
	local parent = { FontSize = 20, Font = "Inter", Color = Color3.new(0, 0, 0) }
	local function resolve(name, css, inherited, warnings)
		return Style.resolve(fixtureElement(name,{ style = css }), inherited or parent, function(message)
			if warnings then table.insert(warnings, message) else error(message) end
		end)
	end
	for _, name in { "b", "strong", "h1", "h2" } do
		assert(resolve(name, "").FontWeight == 700)
		assert(resolve(name, "font-weight: normal").FontWeight == 400)
	end
	for _, value in { "bold", "700", "BOLD !important" } do assert(resolve("span", "font-weight: " .. value).FontWeight == 700) end
	local bold = resolve("p", "font-weight: bold")
	assert(resolve("span", "", bold).FontWeight == 700 and resolve("span", "font-weight: 400", bold).FontWeight == 400)
	for _,value in {'1','100','500','600','900','1000','625.5'} do assert(resolve('p','font-weight:'..value).FontWeight==tonumber(value)) end
	local shorthand=resolve('p','font:600 14px/1.35 Arial')
	assert(shorthand.FontWeight==600 and shorthand.FontSize==14 and shorthand.LineHeight.Kind=='number' and shorthand.LineHeight.Value==1.35)
	assert(resolve('span','',shorthand).FontWeight==600)
	for _, value in { "0", "1001", "bolder", "lighter", "700px", "-700", "" } do
		local warnings = {}
		assert(resolve("p", "font-weight: 700; font-weight: " .. value, nil, warnings).FontWeight == 700 and #warnings == 1)
	end
	local regularMetrics, boldMetrics = Metrics.resolve(parent), Metrics.resolve(bold)
	assert(regularMetrics.Calibrated and not boldMetrics.Calibrated, "Do not claim Regular fits are calibrated for Bold")
	assert(regularMetrics.Baseline == boldMetrics.Baseline and regularMetrics.TextSize == boldMetrics.TextSize)
	local zero=resolve('span','font-size:0px')
	local zeroMetrics=Metrics.resolve(zero,1)
	assert(zero.FontSize==0 and zeroMetrics.TextSize==0 and zeroMetrics.Baseline==0 and zeroMetrics.Bottom==0,'Zero-sized text has no native glyph extents, including input offsets')

	-- Exercise the actual face constructor for asset and Enum families.
	local fakeEnum = {
		Font = { Arial = {}, Ubuntu = {}, SourceSans = {} },
		FontWeight = {Thin=100,ExtraLight=200,Light=300,Regular=400,Medium=500,SemiBold=600,Bold=700,ExtraBold=800,Heavy=900}, FontStyle = { Normal = "normal" },
	}
	local profiles = loadFontProfiles({
		fromEnum = function(font) return { Family = font, Weight = font.Weight or 400, Style = "normal" } end,
		new = function(family, weight, style) return { Family = family, Weight = weight, Style = style } end,
	}, fakeEnum, function(value) return if type(value) == "table" then "EnumItem" else type(value) end)
	local existingBoldEnum = { Weight = 700 }
	for _,weight in {100,200,300,400,500,600,700,800,900} do assert(profiles.face('Inter',weight).Weight==weight) end
	assert(profiles.face('Inter',625.5).Weight==600 and profiles.face('Inter',1000).Weight==900)
	local resolver=profiles.newResolver()
	assert(resolver('Inter',600).Weight==600 and resolver('Inter',600)==resolver('Inter',625.5) and resolver('Inter',600)~=resolver('Inter',400))
	assert(profiles.face(existingBoldEnum).Weight == 700 and profiles.face(existingBoldEnum, 400).Weight == 400)
	for _, family in { "Inter", "Roboto", "Open Sans", "Roboto Condensed", "Roboto Mono", "Roboto Slab", fakeEnum.Font.Arial, fakeEnum.Font.Ubuntu, fakeEnum.Font.SourceSans } do
		local regular, heavy = profiles.face(family), profiles.face(family, 700)
		assert(regular.Family == heavy.Family and regular.Weight == 400 and heavy.Weight == 700 and heavy.Style == "normal")
	end

	local warnings = {}
	local renderer = loadRenderTree({ create = function(_, _, properties) return table.clone(properties) end })
	local tree = renderer.build(Parser.parse([[<style>b { font-weight: normal; } .heavy { font-weight: bold; }</style><p style="font-family: Inter">A <strong>B <span>C</span> <span style="font-weight: normal">D</span></strong> E <b>F</b> <span class="heavy">G</span></p>]]), {}, function(message) table.insert(warnings, message) end)
	assert(#warnings == 0)
	local run = tree.Children[1].Children[1]
	for index, weight in { 400, 700, 700, 400, 400, 400, 700 } do assert(run.Items[index].Style.FontWeight == weight) end
	assert(run.Items[2].SpaceStyle.FontWeight == 400 and run.Items[3].SpaceStyle.FontWeight == 700)
	local calls = {}
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = profiles,
		["Layout/TextMeasure"] = { measure = function(text, face, size)
			table.insert(calls, { Text = text, Weight = face.Weight })
			return { X = if text == " " then (if face.Weight == 700 then 4 else 2) else (if face.Weight == 700 then 20 else 10), Y = size }
		end },
	})
	local function arrange(width) return layout.arrange(run, width, 0, 0, function() return true end) end
	arrange(1000)
	assert(#calls == 13, "Each word and its needed space are measured separately")
	assert(run.Items[2].Width == 20 and run.Items[2].SpaceWidth == 2 and run.Items[3].SpaceWidth == 4)
	for _, item in run.Items do
		assert(item.Gui.FontFace.Weight == item.Style.FontWeight and item.Gui.FontFace.Family == profiles.get("Inter").Family)
		assert(item.Y + item.Baseline == run.Items[1].Y + run.Items[1].Baseline)
	end
	arrange(35)
	assert(#calls == 13 and run.Items[3].Y > run.Items[2].Y, "Bold widths affect wrapping without remeasurement")
	-- A weight-only change invalidates that word, independently of its space.
	run.Items[2].Style = table.clone(run.Items[2].Style)
	run.Items[2].Style.FontWeight = 400
	arrange(1000)
	assert(#calls == 14 and calls[14].Text == "B" and run.Items[2].Width == 10)
	run.Items[2].SpaceStyle = table.clone(run.Items[2].SpaceStyle)
	run.Items[2].SpaceStyle.FontWeight = 700
	arrange(1000)
	assert(#calls == 15 and calls[15].Text == " " and calls[15].Weight == 700 and run.Items[2].SpaceWidth == 4)
	arrange(200)
	assert(#calls == 15)
	local partial = renderer.build(Parser.parse('<p style="font-family: Inter">nor<strong>mal</strong></p>'), {}, function(message) table.insert(warnings, message) end)
	local fragments = partial.Children[1].Children[1]
	assert(#warnings == 0 and #fragments.Items == 2 and fragments.Items[2].Style.FontWeight == 700)
	layout.arrange(fragments, 1, 0, 0, function() return true end)
	assert(fragments.Items[2].X == fragments.Items[1].Width and fragments.Items[2].LineIndex == 1, "Styled fragments stay joined even on a narrow line")
	local profileCalls, nativeCalls = 0, 0
	local cachedLayout = loadWordLayout({
		["Layout/FontProfiles"] = profiles,
		["Layout/FontMetrics"] = {extents = Metrics.extents, resolve = function(style)
			profileCalls += 1
			return Metrics.resolve(style)
		end},
		["Layout/TextMeasure"] = {measure = function(_, _, size)
			nativeCalls += 1
			return {X = 10, Y = size}
		end},
	})
	local common = renderer.build(Parser.parse('<p style="font-family: Inter">A B C</p>'), {}, function(message) error(message) end).Children[1].Children[1]
	cachedLayout.arrange(common, 200, 0, 0, function() return true end)
	assert(profileCalls == 1 and nativeCalls == 5, "One profile calculation, but all three words and two spaces are measured individually")
	cachedLayout.arrange(common, 20, 0, 0, function() return true end)
	assert(profileCalls == 2 and nativeCalls == 5)
	common.Style.FontSize = 30
	cachedLayout.arrange(common, 200, 0, 0, function() return true end)
	assert(profileCalls == 3 and nativeCalls == 10 and common.Items[1].TextSize == 36, "New pass observes changed style and remeasures each item")
	print("Font weight: variants, individual text bounds, per-pass profile reuse, wrapping and baseline estimates passed")
end
