--!strict
return function(Parser: any, Style: any, Flow: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local parent = { Font = "Roboto", FontSize = 20, Color = Color3.new(0, 0, 0) }
	local function resolve(css, inherited, warnings)
		return Style.resolve(fixtureElement("div",{ style = css }), inherited or parent, function(message)
			if warnings then table.insert(warnings, message) else error(message) end
		end)
	end
	assert(resolve("").TextAlign == "start")
	local centered = resolve("text-align: CENTER")
	assert(resolve("", centered).TextAlign == "center")
	assert(resolve("text-align: right", centered).TextAlign == "right")
	assert(resolve("", resolve("text-align: justify")).TextAlign == "justify")
	for _, value in { "match-parent", "10px", "" } do
		local warnings = {}
		assert(resolve("text-align: right; text-align: " .. value, nil, warnings).TextAlign == "right" and #warnings == 1)
	end
	local strut = { Ascent = 8, Descent = 2 }
	local function word(width, baseline, ascent, descent)
		return { Kind = "Word", Width = width, SpaceWidth = 5, SpaceBefore = true,
			Baseline = baseline or 8, Ascent = ascent or 8, Descent = descent or 2 }
	end
	local items = { word(20), word(30, 18, 20, 4), { Kind = "Break" }, word(10) }
	for align, positions in { left = { 0, 25, 0, 55 }, center = { 22.5, 47.5, 45, 77.5 }, right = { 45, 70, 90, 100 } } do
		local height, extent = Flow.arrange(items, 100, strut, align)
		assert(height == 34 and extent == positions[4])
		assert(items[1].X == positions[1] and items[2].X == positions[2] and items[4].X == positions[3])
		assert(items[1].Y + items[1].Baseline == items[2].Y + items[2].Baseline, "Alignment preserves mixed baselines")
	end
	assert(Flow.arrange(items, 40, strut, "center") == 44)
	assert(items[1].X == 10 and items[2].X == 5 and items[4].X == 15, "Wrap before aligning each individual line")
	Flow.arrange(items, 40, strut, "right")
	assert(items[1].X == 20 and items[2].X == 10 and items[4].X == 30)
	Flow.arrange(items, 100, strut, "left")
	assert(items[1].X == 0 and items[2].X == 25, "Reflow never accumulates previous offsets")
	local oversized = { word(120) }
	local height, extent = Flow.arrange(oversized, 100, strut, "center")
	assert(height == 10 and oversized[1].X == 0 and extent == 120, "Overlong centered inline contents fall back to start alignment (CSS Text 3 section 6.1)")
	height, extent = Flow.arrange(oversized, 100, strut, "right")
	assert(height == 10 and oversized[1].X == 0 and extent == 120, "Overlong right-aligned inline contents fall back to start alignment; the full word remains overflow")
	height, extent = Flow.arrange({ { Kind = "Break" } }, 100, strut, "right")
	assert(height == 10 and extent == 0, "Empty lines cannot invent horizontal content")
	assert(Flow.arrange({}, 100, strut, "center") == 0)

	local justified = { word(10), word(10), word(10), word(30), { Kind = "Break" }, word(10), word(10) }
	local jHeight, jExtent = Flow.arrange(justified, 50, strut, "justify")
	assert(jHeight == 30 and jExtent == 50)
	assert(justified[1].X == 0 and justified[2].X == 20 and justified[3].X == 40, "Equal extra space in both gaps of a wrapped line")
	assert(justified[4].X == 0 and justified[6].X == 0 and justified[7].X == 15, "br and final lines stay left aligned")
	Flow.arrange(justified, 100, strut, "justify")
	assert(justified[2].X == 15 and justified[3].X == 30 and justified[4].X == 45, "Widening removes previous justification")
	local adjacent = { word(10), word(10), word(10), word(30) }
	adjacent[2].SpaceBefore = false
	Flow.arrange(adjacent, 50, strut, "justify")
	assert(adjacent[2].X == 10 and adjacent[3].X == 40, "Expand only real word spaces")
	local alone = { word(120), word(20) }
	assert(Flow.arrange(alone, 100, strut, "justify") == 20 and alone[1].X == 0 and alone[2].X == 0)

	-- Actual parser -> inheritance -> block padding -> aligned word labels.
	local renderer = loadRenderTree({ create = function(_, _, properties) return table.clone(properties) end })
	local tree = renderer.build(Parser.parse([[<div style="font-family: Roboto; font-size: 20px; text-align: center; padding: 10px"><p style="margin: 0">AA BB</p><p style="margin: 0; text-align: right">CC <span style="text-align: left">DD</span></p></div>]]), {}, function(message) error(message) end)
	local requests = 0
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = { face = function(font) return font end },
		["Layout/TextMeasure"] = { measure = function(text, _, size)
			requests += 1
			return { X = if text == " " then 5 else 20, Y = size }
		end },
	})
	local block = loadBlockLayout({ ["Layout/WordLayout"] = layout })
	local container = tree.Children[1]
	local centerRun, rightRun = container.Children[1].Children[1], container.Children[2].Children[1]
	local initialHeight = block.arrange(tree, 120, 0, 0, function() return true end)
	assert(container.Gui.Size[1] == 120 and container.Children[1].Gui.Position[1] == 10)
	assert(centerRun.Items[1].Gui.Position[1] == 27.5 and rightRun.Items[1].Gui.Position[1] == 55)
	assert(rightRun.Items[2].Gui.Position[1] == 80, "Span text-align cannot reposition a word independently of its paragraph")
	assert(requests == 6)
	centerRun.Style.TextAlign = "right"
	assert(block.arrange(tree, 120, 0, 0, function() return true end) == initialHeight)
	assert(centerRun.Items[1].Gui.Position[1] == 55 and requests == 6, "Only alignment changes; no new measurements or heights")
	block.arrange(tree, 60, 0, 0, function() return true end)
	assert(centerRun.Items[1].Gui.Position[1] == 20 and centerRun.Items[2].Gui.Position[1] == 20 and requests == 6)
	local justifyTree = renderer.build(Parser.parse([[<p style="font-family: Roboto; text-align: justify; margin: 0">AA AA AA<br>AA AA</p>]]), {}, function(message) error(message) end)
	block.arrange(justifyTree, 60, 0, 0, function() return true end)
	local justifyRun = justifyTree.Children[1].Children[1]
	assert(justifyRun.Items[2].Gui.Position[1] == 40 and justifyRun.Items[6].Gui.Position[1] == 25)
	local measured = requests
	block.arrange(justifyTree, 100, 0, 0, function() return true end)
	assert(justifyRun.Items[2].Gui.Position[1] == 25 and requests == measured)
	print("Text-align: inheritance, invalid values, per-line alignment, wrapping, baselines, overflow, padding and measurement reuse passed")
end
