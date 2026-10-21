--!strict
return function(Parser: any, Profiles: any, Metrics: any, Flow: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
	-- Hand-computed line boxes: the large word must affect only its own line.
	local strut = { Ascent = 8, Descent = 2 }
	local small = { Kind = "Word", Width = 10, Baseline = 8, Ascent = 8, Descent = 2, SpaceBefore = true, SpaceWidth = 5 }
	local large = { Kind = "Word", Width = 10, Baseline = 20, Ascent = 22, Descent = 4, SpaceBefore = true, SpaceWidth = 5 }
	local items = { table.clone(small), table.clone(large), table.clone(small) }
	assert(Flow.arrange(items, 40, strut) == 26)
	assert(items[1].Y == 14 and items[2].Y == 2 and items[3].Y == 14)
	for _, item in items do assert(item.Y + item.Baseline == 22) end
	assert(Flow.arrange(items, 10, strut) == 46)
	assert(items[1].Y == 0 and items[2].Y == 12 and items[3].Y == 36, "A wrapped large word cannot enlarge the preceding line")
	local explicit = { table.clone(small), { Kind = "Break" }, table.clone(large), { Kind = "Break" } }
	assert(Flow.arrange(explicit, 100, strut) == 36 and explicit[3].Y == 12)
	local tiny = { Kind = "Word", Width = 10, Baseline = 4, Ascent = 4, Descent = 1 }
	assert(Flow.arrange({ tiny }, 100, strut) == 10 and tiny.Y == 4, "Parent strut supplies a minimum line box")
	local zero = { Kind = "Word", Width = 10, Baseline = 8, Ascent = 3, Descent = -3 }
	assert(Flow.arrange({ zero, { Kind = "Break" }, table.clone(zero) }, 100, { Ascent = 3, Descent = -3 }) == 0)
	assert(zero.Y == -5, "Negative leading must not be clamped away")
	local shifted = { Kind = "Word", Width = 10, Baseline = 12, Ascent = 12, Descent = -2 }
	assert(Flow.arrange({ table.clone(small), shifted }, 100, strut) == 14, "Different baselines can grow a line even with equal line-height")

	-- Use the stored font-guide input conventions, including historical fits.
	for _, font in { "Roboto", "Inter", "Open Sans", Enum.Font.Arial, Enum.Font.Ubuntu } do
		for _, size in { 10, 20, 30, 40, 50 } do
			local profile = Profiles.get(font)
			local metrics = Metrics.resolve({ Font = font, FontSize = size })
			assert(metrics.Calibrated and metrics.TextSize == math.ceil(size * profile.SizeMultiplier))
			assert(metrics.Baseline == Profiles.guides(profile, size * profile.SizeMultiplier).Baseline)
		end
	end
	local fallback = Metrics.resolve({ Font = Enum.Font.SourceSans, FontSize = 20 })
	assert(not fallback.Calibrated and fallback.TextSize == 20 and fallback.Baseline == 16, "Uncalibrated fonts use an explicit estimate")

	local warnings = {}
	local renderer = loadRenderTree({ create = function(_, _, properties) return table.clone(properties) end })
	local function render(html)
		table.clear(warnings)
		local document = Parser.parse(html)
		assert(#document.Diagnostics == 0)
		return renderer.build(document, {}, function(message) table.insert(warnings, message) end)
	end
	local tree = render([[<div style="font-family: Roboto; font-size: 20px; line-height: 1.4; margin: 0">A <span style="font-size: 40px; color: red">B <span style="font-family: Inter">C</span></span> D<br>E</div><div style="height: 10px"></div>]])
	assert(#warnings == 0)
	local run = tree.Children[1].Children[1]
	local a, b, c, d, e = run.Items[1], run.Items[2], run.Items[3], run.Items[4], run.Items[6]
	assert(#run.Items == 6 and run.Items[5].Kind == "Break")
	assert(a.Style.FontSize == 20 and b.Style.FontSize == 40 and c.Style.FontSize == 40 and d.Style.FontSize == 20)
	assert(b.Style.Font == "Roboto" and c.Style.Font == "Inter" and c.Gui.TextColor3 == Color3.fromRGB(255, 0, 0))
	assert(b.SpaceStyle.FontSize == 20 and c.SpaceStyle.FontSize == 40 and c.SpaceStyle.Font == "Roboto", "Spaces keep the style of their own text node")
	local requests, live = {}, true
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = { face = function(font) return font end },
		["Layout/TextMeasure"] = { measure = function(text, font, size, width)
			assert(size == math.ceil(size) and width == 0)
			table.insert(requests, { Text = text, Font = font, Size = size })
			return { X = if text == " " then 5 else #text * size / 2, Y = size + 3 }
		end },
	})
	local function arrange(width)
		return layout.arrange(run, width or 1000, 7, 11, function() return live end)
	end
	assert(arrange() == 85, "Mixed first line is 57px, homogeneous second line 28px")
	assert(a.Baseline == 19 and b.Baseline == 37 and c.Baseline == 39)
	for _, word in { a, b, c, d } do assert(word.Gui.Position[2] + word.Baseline == 54, "All labels share the same visual baseline") end
	assert(b.Gui.TextSize == 46 and c.Gui.TextSize == 48 and b.Gui.FontFace == "Roboto" and c.Gui.FontFace == "Inter")
	assert(b.Gui.Size[2] == 49 and c.Gui.Size[2] == 51, "Glyph labels keep individual measured heights")
	assert(a.Gui.Position[1] == 7 and e.Gui.Position[2] == 70.5)
	assert(#requests == 8 and requests[3].Text == " " and requests[3].Size == 23)
	assert(requests[5].Text == " " and requests[5].Font == "Roboto" and requests[5].Size == 46)
	assert(arrange(12) == 196 and #requests == 8, "Rewrapping reuses only the individual word and space measurements")
	assert(arrange() == 85 and #requests == 8)
	local block = loadBlockLayout({ ["Layout/WordLayout"] = layout })
	assert(block.arrange(tree, 1000, 0, 0, function() return live end) == 95)
	assert(tree.Children[2].Gui.Position[2] == 85, "Following blocks move below all line boxes")
	-- Only the changed word is measured again; its preceding space belongs to B.
	c.Style = table.clone(c.Style)
	c.Style.Font = "Roboto"
	arrange()
	assert(#requests == 9 and requests[9].Text == "C" and c.Gui.TextSize == 46)
	live = false
	local previous = a.Gui.Position
	assert(arrange() == 0 and a.Gui.Position == previous)

	-- Whitespace, hidden spans and tag boundaries must not split or join words incorrectly.
	local textTree = render([[<p>  Hel<span>lo</span> <span style="color: red">red</span>dish A<span style="display: none">gone</span>B A&nbsp;B<br><br>C  </p>]])
	local words = textTree.Children[1].Children[1].Items
	assert(#warnings == 0)
	assert(#words == 8 and words[1].Text == "Hello" and words[2].Text == "red" and words[3].Text == "dish" and words[4].Text == "AB")
	assert(words[2].Gui.TextColor3 == Color3.fromRGB(255, 0, 0))
	assert(words[5].Text == "A\u{a0}B" and words[6].Kind == "Break" and words[7].Kind == "Break")
	assert(not words[1].SpaceBefore and words[2].SpaceBefore and not words[3].SpaceBefore and not words[8].SpaceBefore)
	local atomic = render([[<p><span style="font-size: 30px; padding: 5px; background: red; display: inline-flex">X</span></p>]])
	local atomicItem=atomic.Children[1].Children[1].Items[1]
	assert(#warnings == 0 and atomicItem.Style.FontSize == 30 and atomicItem.InlineBox,'inline-flex participates as an atomic inline box')
	local percent = render([[<p style="font-size: 20px; line-height: 150%"><span style="font-size: 40px">A</span> <span style="font-size: 40px; line-height: 150%">B</span></p>]])
	local percentageWords = percent.Children[1].Children[1].Items
	assert(#warnings == 0 and percentageWords[1].Style.LineHeight.Value == 30 and percentageWords[2].Style.LineHeight.Value == 60)
	live = true
	local duplicates = render([[<p style="font-family: Roboto">Same Same</p>]])
	local before = #requests
	layout.arrange(duplicates.Children[1].Children[1], 1000, 0, 0, function() return live end)
	assert(#requests == before + 3, "Identical words still get separate measurements and their own space measurement")
	print("Baseline: mixed fonts/sizes, per-line extents, strut, wrapping, guide fits, inline styles, spaces and measurement reuse passed")
end
