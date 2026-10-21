--!strict
return function(Parser: any, Style: any, SkipInk: any, loadRenderTree: any, loadWordLayout: any, loadTextDecoration: any)
 local fixtureElement=require('DOM/Node').element
	local parent = { Font = "Inter", FontSize = 20, Color = Color3.new(0, 0, 0) }
	local function resolve(name, css, inherited, warn)
		return Style.resolve(fixtureElement(name,{ style = css }), inherited or parent, warn or function(message) error(message) end, true)
	end
	assert(resolve("u", "").Decorations[1].SkipInk == "auto")
	local disabled = resolve("div", "text-decoration-skip-ink: none")
	assert(resolve("u", "", disabled).Decorations[1].SkipInk == "none")
	local origin = resolve("u", "")
	assert(resolve("span", "text-decoration-skip-ink: none", origin).Decorations[1] == origin.Decorations[1])
	local warnings = 0
	assert(resolve("u", "text-decoration-skip-ink: none; text-decoration-skip-ink: invalid", nil, function() warnings += 1 end).Decorations[1].SkipInk == "none" and warnings == 1)
	local requests, frames = 0, {}
	local renderer = loadRenderTree({ create = function(_, _, properties) return table.clone(properties) end })
	local decoration = loadTextDecoration({ create = function(_, _, properties)
		local frame = table.clone(properties)
		table.insert(frames, frame)
		return frame
	end })
	local layout = loadWordLayout({
		["Layout/TextDecoration"] = decoration,
		["Layout/FontProfiles"] = { face = function(font) return font end },
		["Layout/TextMeasure"] = { measure = function(text, _, size)
			requests += 1
			return { X = assert(utf8.len(text), "Prefix must end on a UTF-8 boundary") * size / 2, Y = size }
		end },
	})
	local function run(css, text)
		return renderer.build(Parser.parse('<p style="' .. css .. '">' .. text .. '</p>'), {}, function(message) error(message) end).Children[1].Children[1]
	end
	local function arrange(words, width) return layout.arrange(words, width or 10000, 0, 0, function() return true end) end
	for _, size in {10, 20, 41, 82, 100} do
		local css = 'font-size: ' .. size .. 'px; text-decoration: underline line-through'
		local words = run(css, "Apa")
		local before = requests
		local height = arrange(words)
		local word = words.Items[1]
		assert(requests - before == 3, "Only two prefix measurements beyond the ordinary word measurement")
		local cut = word.SkipInkCuts[1]
		assert(#word.SkipInkCuts == 1 and cut.Left > 0 and cut.Right < word.Width)
		local lines = word.DecorationFrames
		assert(#lines == 3, "Two underline segments and a continuous strike")
		assert(lines[1].Position[1] + lines[1].Size[1] == cut.Left)
		assert(lines[2].Position[1] == cut.Right and lines[2].Position[1] + lines[2].Size[1] == word.Width)
		assert(lines[3].Position[1] == 0 and lines[3].Size[1] == word.Width)
		local calls, count = requests, #frames
		arrange(words, 1)
		assert(requests == calls and #frames == count and word.SkipInkCuts[1] == cut, "Reuse cuts and frames on width changes")
		local plain = run('font-size: ' .. size .. 'px', "Apa")
		assert(arrange(plain) == height and plain.Items[1].Width == word.Width, "No change to word dimensions or layout")
	end
	for _, css in { "", "text-decoration: line-through", "text-decoration: underline; text-decoration-skip-ink: none" } do
		local words = run(css, "pgjqy")
		local before = requests
		arrange(words)
		assert(requests == before + 1 and words.Items[1].SkipInkCuts == nil, "No extra measurements when skipping is unused")
	end
	for _, text in { "ABC", "PGJQY" } do
		local words = run("text-decoration: underline", text)
		local before = requests
		arrange(words)
		assert(requests == before + 1 and #words.Items[1].SkipInkCuts == 0)
	end
	for _, char in { "p", "g", "j", "q", "y" } do
		local words = run("text-decoration: underline", "Ä" .. char .. "ä")
		arrange(words)
		assert(#words.Items[1].SkipInkCuts == 1, "All five descenders, including after multibyte text")
	end
	local overlap = run("text-decoration: underline; font-size: 10px", "gjy")
	arrange(overlap)
	local lastRight = 0
	for _, line in overlap.Items[1].DecorationFrames or {} do
		assert(line.Size[1] > 0 and line.Position[1] >= lastRight, "Merged cuts cannot create negative or overlapping segments")
		lastRight = line.Position[1] + line.Size[1]
	end
	local wrapped = run("text-decoration: underline; text-align: justify", "Apa Apa Apa")
	arrange(wrapped, 100)
	local second = wrapped.Items[2]
	local gap = second.X - wrapped.Items[1].X - wrapped.Items[1].Width
	assert(second.DecorationFrames[1].Position[1] == -gap, "Keep the decorated justify gap before the first cut")
	local calls, count = requests, #frames
	arrange(wrapped, 1)
	assert(second.DecorationFrames[1].Position[1] == 0 and requests == calls and #frames == count)
	-- Cache must be invalidated when a word's measurement changes.
	second.Text = "Aqa"
	arrange(wrapped, 1)
	assert(requests > calls and second.SkipInkCuts[1].Left > wrapped.Items[1].SkipInkCuts[1].Left)
	-- Mono at CSS20 uses native25: fitted baseline21 and p-bottom25.
	-- An underline starting at baseline+4 only touches the bottom edge: no gap.
	local far = run("font-family: 'Roboto Mono'; font-size: 20px; text-decoration: underline line-through; text-underline-offset: 4px", "Apa")
	local before = requests
	arrange(far)
	local mono = far.Items[1]
	assert(mono.Baseline == 21 and mono.SkipInkBottom == 25)
	assert(requests == before + 1 and mono.SkipInkCuts == nil, "No prefix measurements below the descender")
	assert(#mono.DecorationFrames == 2 and mono.DecorationFrames[1].Size[1] == mono.Width)
	local function offset(value)
		local line = table.clone(mono.Style.Decorations[1])
		line.UnderlineOffset = value
		mono.Style.Decorations = {line}
		arrange(far)
	end
	offset(3)
	assert(requests == before + 3 and #mono.SkipInkCuts == 1 and #mono.DecorationFrames == 3)
	local cut, savedFrames, savedRequests = mono.SkipInkCuts[1], #frames, requests
	offset(20)
	assert(mono.DecorationFrames[1].Size[1] == mono.Width and not mono.DecorationFrames[3].Visible)
	assert(requests == savedRequests and #frames == savedFrames)
	offset(3)
	assert(mono.DecorationFrames[3].Visible and mono.SkipInkCuts[1] == cut)
	assert(requests == savedRequests and #frames == savedFrames, "Moving back restores cached gaps and frames")
	for _, size in {10, 20, 41, 82} do
		for _, font in {"Roboto Mono", "Inter", "Source Sans Pro"} do
			local below = run('font-family: ' .. font .. '; font-size: ' .. size .. 'px; text-decoration: underline; text-underline-offset: 100%', "Apa")
			local prior = requests
			arrange(below)
			local item = below.Items[1]
			assert(requests == prior + 1 and item.SkipInkCuts == nil)
			assert(#item.DecorationFrames == 1 and item.DecorationFrames[1].Size[1] == item.Width)
		end
	end
	local band = {Baseline = 20, SkipInkTop = 7, SkipInkBottom = 25}
	assert(SkipInk.intersects(band, {UnderlineOffset = 4, Thickness = 1}))
	assert(not SkipInk.intersects(band, {UnderlineOffset = 5, Thickness = 4}))
	assert(not SkipInk.intersects(band, {UnderlineOffset = -15, Thickness = 2}))
	assert(SkipInk.intersects(band, {UnderlineOffset = -15, Thickness = 3}), "Thickness can reach into the ink from above")
	local layered = run("font-size: 20px; text-decoration: underline; text-underline-offset: 1px", '<u style="text-underline-offset: 20px">Apa</u>')
	arrange(layered)
	local layers = layered.Items[1]
	assert(#layers.DecorationFrames == 3, "Check each originating underline separately")
	assert(layers.DecorationFrames[3].Size[1] == layers.Width and layers.DecorationFrames[3].Position[2] == layers.Baseline + 20)
	local glyphs = run("font-size: 20px; letter-spacing: 1px; text-decoration: underline; text-underline-offset: 20px", "Apa")
	arrange(glyphs)
	assert(glyphs.Items[1].Glyphs and glyphs.Items[1].SkipInkCuts == nil and #glyphs.Items[1].DecorationFrames == 1)
	local cancelled = { Text = "Apa", Width = 30, TextSize = 20, FontFace = "Inter" }
	local live = true
	assert(not SkipInk.measure(cancelled, origin, function()
		live = false
		return { X = 10, Y = 20 }
	end, function() return live end))
	assert(cancelled.SkipInkCuts == nil, "Do not store partial results after destruction")
	print("Skip ink: vertical guide overlap, offset changes, cached gaps/frames, fallback fonts, nested lines, glyphs and cancellation passed")
end
