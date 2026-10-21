--!strict
return function(Parser: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
	local renderer = loadRenderTree({create = function(_, _, props) return table.clone(props) end})
	local requests = 0
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			requests += 1
			return {X = if text == " " then 5 else 20, Y = size}
		end},
	})
	local block = loadBlockLayout({["Layout/WordLayout"] = layout})
	local function build(html) return renderer.build(Parser.parse(html), {}, function(message) error(message) end) end
	local function arrange(tree, width) return block.arrange(tree, width or 200, 0, 0, function() return true end) end
	for _, pair in {{16, 16}, {12, 16}, {36, 12}, {0, 16}, {16, 0}} do
		local tree = build('<div style="height: 20px; margin: 0 0 ' .. pair[1] .. 'px"></div>\n<div style="height: 10px; margin: ' .. pair[2] .. 'px 0 0"></div>')
		assert(arrange(tree) == 30 + math.max(pair[1], pair[2]))
		assert(tree.Children[2].Gui.Position[2] == 20 + math.max(pair[1], pair[2]), "Use the larger adjacent margin, not the sum")
	end
	local paragraphs = build('<div style="padding: 20px; line-height: 10px"><h2 style="margin: 0 0 12px">Title</h2><p>AA BB CC</p><p>DD</p></div>')
	arrange(paragraphs)
	local card = paragraphs.Children[1]
	local heading, first, second = card.Children[1], card.Children[2], card.Children[3]
	assert(first.Gui.Position[2] - heading.Gui.Position[2] - heading.Gui.Size[2] == 16)
	assert(second.Gui.Position[2] - first.Gui.Position[2] - first.Gui.Size[2] == 16, "Default paragraphs must not have a doubled 32px gap")
	assert(heading.Gui.Position[2] == 20 and first.Gui.Position[1] == 20, "Parent padding stays intact")
	local count = requests
	arrange(paragraphs, 60)
	assert(second.Gui.Position[2] - first.Gui.Position[2] - first.Gui.Size[2] == 16 and requests == count, "Resize reuses measurements and never accumulates collapse")
	local hidden = build('<div style="height: 10px; margin: 0 0 16px"></div><div style="display: none; margin: 99px">hidden</div><div style="height: 10px; margin: 16px 0 0"></div>')
	assert(arrange(hidden) == 36, 'Hidden margins must not interrupt adjacent visible margin collapsing')
	assert(#hidden.Children == 3 and #hidden.FlowChildren == 2 and not hidden.Children[2].Gui.Visible)
	local inline = build('<div style="line-height: 10px"><div style="height: 10px; margin: 0 0 16px"></div>AA<div style="height: 10px; margin: 16px 0 0"></div></div>')
	arrange(inline)
	assert(inline.Children[1].Children[3].Gui.Position[2] == 52, "Intervening text prevents collapsing across it")
	local bordered = build('<div style="height: 10px; padding: 5px; border: 2px solid; margin: 3px 7px 16px; overflow: hidden"></div><div style="height: 10px; padding: 5px; border: 2px solid; margin: 12px 9px 4px; overflow: hidden"></div>')
	local height, width = arrange(bordered, 100)
	assert(height == 71 and width == 100)
	assert(bordered.Children[2].Gui.Position[2] == 43 and bordered.Children[2].Gui.Position[1] == 9, "Borders, padding and overflow do not prevent sibling margin collapse; horizontal margins stay intact")
	local overflow = build('<div style="height: 10px; margin: 0 0 16px"><div style="height: 100px"></div></div><div style="height: 10px; margin: 16px 0 0"></div>')
	assert(arrange(overflow) == 100 and overflow.Children[2].Gui.Position[2] == 26, "Visible overflow expands the canvas but not the collapsed sibling gap")
	local sides = build('<style>#a {margin: 3px 4px; padding-left: 9px} .card {margin-left: 99px; padding: 2px}</style><div class="card" id="a" style="height: 10px; margin-bottom: 16px; padding-right: 6px; overflow: hidden"></div><div style="height: 10px; margin-top: 12px; margin-left: 5px"></div>')
	assert(arrange(sides, 100) == 43)
	local firstBox, secondBox = sides.Children[1], sides.Children[2]
	assert(firstBox.Gui.Position[1] == 4 and firstBox.Gui.Position[2] == 3 and firstBox.Gui.Size[1] == 92)
	assert(firstBox.Style.Padding[4] == 9 and firstBox.Style.Padding[2] == 6)
	assert(secondBox.Gui.Position[1] == 5 and secondBox.Gui.Position[2] == 33, "Longhands preserve sibling collapse")
	arrange(sides, 80)
	assert(firstBox.Gui.Size[1] == 72 and secondBox.Gui.Position[2] == 33)
	for _, case in {{"margin-top: 0", 74}, {"margin-right: 10px", 138}, {"margin-left: 10px", 10}, {"margin: 0", 0}} do
		local rule = build('<hr style="width: 50px; ' .. case[1] .. '">')
		arrange(rule, 200)
		assert(rule.Children[1].Gui.Position[1] == case[2], "Untouched hr auto margins: " .. case[1] .. " actual=" .. tostring(rule.Children[1].Gui.Position[1]))
	end
	local headings = build('<div style="font-size: 20px; line-height: 20px; padding: 1px"><h3>AA BB CC</h3><h4>DD</h4></div>')
	arrange(headings, 200)
	local third, fourth = headings.Children[1].Children[1], headings.Children[1].Children[2]
	local function gap() return fourth.Gui.Position[2] - third.Gui.Position[2] - third.Gui.Size[2] end
	assert(math.abs(gap() - 26.6) < .0001)
	local measured, before = requests, fourth.Gui.Position[2]
	arrange(headings, 45)
	assert(requests == measured and fourth.Gui.Position[2] > before and math.abs(gap() - 26.6) < .0001)
	local positionedParent=build('<div style="position:relative;height:120px"><div style="height:54px;margin-top:30px"></div><div style="position:absolute"></div></div>')
	arrange(positionedParent,200)
	local stage,source=positionedParent.Children[1],positionedParent.Children[1].Children[1]
	assert(stage.LayoutMargin[1]==30 and source.Gui.Position[2]==0,"A relative block still collapses its first in-flow child margin through its top edge")
	print("Margins: longhands, headings, sibling collapse, padding, overflow and reflow reuse passed")
end
