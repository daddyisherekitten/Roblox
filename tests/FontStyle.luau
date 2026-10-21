--!strict
return function(Parser: any, Style: any, Metrics: any, loadRenderTree: any, loadWordLayout: any, loadFontProfiles: any)
 local fixtureElement=require('DOM/Node').element
	local parent = { FontSize = 20, Font = "Inter", Color = Color3.new(0, 0, 0) }
	local function resolve(name, css, inherited, warnings)
		return Style.resolve(fixtureElement(name,{ style = css }), inherited or parent, function(message)
			if warnings then table.insert(warnings, message) else error(message) end
		end)
	end
	for _, name in { "i", "em" } do
		assert(resolve(name, "").FontStyle == "italic")
		assert(resolve(name, "font-style: normal").FontStyle == "normal")
	end
	local italic = resolve("p", "font-style: ITALIC")
	assert(resolve("span", "", italic).FontStyle == "italic")
	assert(resolve("strong", "", italic).FontStyle == "italic" and resolve("strong", "", italic).FontWeight == 700)
	for _, value in { "oblique", "oblique 15deg", "700", "italics", "" } do
		local warnings = {}
		assert(resolve("span", "font-style: italic; font-style: " .. value, nil, warnings).FontStyle == "italic" and #warnings == 1)
	end
	assert(resolve("em", "font-style: normal !important; font-style: italic").FontStyle == "normal")
	assert(Metrics.resolve(parent).Calibrated and not Metrics.resolve(italic).Calibrated)
	assert(Metrics.resolve(parent).Baseline == Metrics.resolve(italic).Baseline, "Italic keeps Regular guides as an explicit estimate")

	local fakeEnum = {
		Font = { Arial = {}, Ubuntu = {}, SourceSans = {} },
		FontWeight = { Regular = 400, Bold = 700 }, FontStyle = { Normal = "normal", Italic = "italic" },
	}
	local profiles = loadFontProfiles({
		fromEnum = function(font) return { Family = font, Weight = font.Weight or 400, Style = font.Style or "normal" } end,
		new = function(family, weight, style) return { Family = family, Weight = weight, Style = style } end,
	}, fakeEnum, function(value) return if type(value) == "table" then "EnumItem" else type(value) end)
	for _, family in { "Inter", "Roboto", "Open Sans", "Roboto Condensed", "Roboto Mono", "Roboto Slab", fakeEnum.Font.Arial, fakeEnum.Font.Ubuntu, fakeEnum.Font.SourceSans } do
		for _, weight in { 400, 700 } do
			for _, style in { "normal", "italic" } do
				local face = profiles.face(family, weight, style)
				assert(face.Family == profiles.face(family).Family and face.Weight == weight and face.Style == style)
			end
		end
	end
	local native = { Weight = 700, Style = "italic" }
	assert(profiles.face(native).Style == "italic" and profiles.face(native, 400).Style == "italic")
	assert(profiles.face(native, nil, "normal").Weight == 700 and profiles.face(native, nil, "normal").Style == "normal")

	local warnings = {}
	local renderer = loadRenderTree({ create = function(_, _, properties) return table.clone(properties) end })
	local tree = renderer.build(Parser.parse([[<style>.plain { font-style: normal; } .slant { font-style: italic; }</style><p style="font-family: Inter">A <i>B <span>C</span> <span style="font-style: normal">D</span></i> <strong><em>E</em></strong> <em class="plain">F</em> <span class="slant">G</span></p>]]), {}, function(message) table.insert(warnings, message) end)
	assert(#warnings == 0)
	local run = tree.Children[1].Children[1]
	for index, style in { "normal", "italic", "italic", "normal", "italic", "normal", "italic" } do assert(run.Items[index].Style.FontStyle == style) end
	local calls = {}
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = profiles,
		["Layout/TextMeasure"] = { measure = function(text, face, size)
			table.insert(calls, { Text = text, Face = face })
			local width = if face.Style == "italic" then 20 else 10
			return { X = if text == " " then width / 5 else width + (if face.Weight == 700 then 5 else 0), Y = size }
		end },
	})
	local function arrange(width) return layout.arrange(run, width, 0, 0, function() return true end) end
	arrange(1000)
	assert(#calls == 13 and run.Items[2].Width == 20 and run.Items[5].Width == 25)
	assert(run.Items[2].SpaceWidth == 2 and run.Items[3].SpaceWidth == 4, "Spaces retain their own text style")
	for _, item in run.Items do
		assert(item.Gui.FontFace.Style == item.Style.FontStyle and item.Gui.FontFace.Weight == item.Style.FontWeight)
		assert(item.Y + item.Baseline == run.Items[1].Y + run.Items[1].Baseline)
	end
	arrange(35)
	assert(#calls == 13 and run.Items[3].Y > run.Items[2].Y, "Italic bounds affect wrapping without new measurements")
	run.Items[2].Style = table.clone(run.Items[2].Style)
	run.Items[2].Style.FontStyle = "normal"
	arrange(1000)
	assert(#calls == 14 and calls[14].Text == "B" and run.Items[2].Width == 10)
	run.Items[3].SpaceStyle = table.clone(run.Items[3].SpaceStyle)
	run.Items[3].SpaceStyle.FontStyle = "normal"
	arrange(1000)
	assert(#calls == 15 and calls[15].Text == " " and run.Items[3].SpaceWidth == 2)
	arrange(200)
	assert(#calls == 15)
	local partial = renderer.build(Parser.parse('<p style="font-family: Inter">nor<i>mal</i></p>'), {}, function(message) table.insert(warnings, message) end)
	local fragments = partial.Children[1].Children[1]
	assert(#warnings == 0 and #fragments.Items == 2 and fragments.Items[2].Style.FontStyle == "italic")
	layout.arrange(fragments, 1, 0, 0, function() return true end)
	assert(fragments.Items[2].X == fragments.Items[1].Width and fragments.Items[2].LineIndex == 1)
	print("Font style: normal/italic, i/em, CSS overrides, bold italic, face selection, word/space measurements, wrapping and baseline estimates passed")
end
