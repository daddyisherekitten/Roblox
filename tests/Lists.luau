--!strict
return function(Parser: any, Style: any, DOM: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local requests, objects = 0, 0
	local renderer = loadRenderTree({create = function(class, parent, props)
		objects += 1
		local gui = table.clone(props)
		gui.ClassName, gui.Parent = class, parent
		return gui
	end})
	local overrides = {
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			requests += 1
			local width = 0
			for char in text:gmatch(".") do width += if char == " " then 5 else 10 end
			return {X = width, Y = size}
		end},
	}
	overrides["Layout/WordLayout"] = loadWordLayout(overrides)
	local layout = loadBlockLayout(overrides)
	local function build(html)
		local doc = Parser.parse(html)
		local source = DOM.textContent(doc)
		local tree = renderer.build(doc, {}, function(message) error(message) end)
		assert(DOM.textContent(doc) == source, "Markers never change the DOM text")
		return tree
	end
	local function arrange(tree, width) return layout.arrange(tree, width or 200, 0, 0, function() return true end) end
	local tree = build('<ul style="font-size: 20px; line-height: 20px"><li>AA BB CC DD</li><li>EE</li></ul>')
	local optional = Parser.parse('<ul><li>AA<li>BB<ul><li>CC<li>DD</ul></ul>')
	assert(#optional.Diagnostics == 0 and #optional.Children[1].Children == 2)
	assert(#optional.Children[1].Children[2].Children[2].Children == 2, "Omitted li end tags respect nesting")
	assert(arrange(tree, 100) == 100)
	local list = tree.Children[1]
	local first, second = list.Children[1], list.Children[2]
	assert(list.Style.Margin[1] == 20 and list.Style.Margin[3] == 20 and list.Style.Padding[4] == 40)
	assert(first.Gui.Position[1] == 40 and first.Gui.Size[1] == 60 and first.Gui.Size[2] == 40)
	assert(second.Gui.Position[2] == 40, "No implicit margins between plain li entries")
	local words = first.Children[1].Items
	assert(words[3].X == 0 and words[3].LineIndex == 2, "Continuation lines align with the content, not the bullet")
	assert(first.Marker.Baseline == words[1].LineBaseline and first.Marker.Gui.Position[1] < 0)
	local count, allocated = requests, objects
	arrange(tree, 200)
	assert(requests == count and objects == allocated and second.Gui.Position[2] == 20, "Reflow reuses marker and word measurements/objects")
	local nested = build('<ul><li>AA<ul><li>BB<ul><li>CC</li></ul></li></ul></li><li>DD</li></ul>')
	arrange(nested)
	local outer = nested.Children[1]
	local middle = outer.Children[1].Children[2]
	local inner = middle.Children[1].Children[2]
	assert(outer.Children[1].Marker.Kind == "disc" and middle.Children[1].Marker.Kind == "circle" and inner.Children[1].Marker.Kind == "square")
	assert(middle.Style.Margin[1] == 0 and middle.Style.Margin[3] == 0 and inner.Style.Margin[1] == 0)
	assert(middle.Children[1].Gui.Position[1] == 40 and inner.Children[1].Gui.Position[1] == 40)
	local ordered = build('<ol start="9" style="line-height: 20px"><li>AA</li><li>BB</li><li value="-2">CC</li><li>DD</li></ol>')
	arrange(ordered)
	local entries = ordered.Children[1].Children
	for index, expected in {9, 10, -2, -1} do
		assert(entries[index].Marker.Number == expected)
		assert(entries[index].Marker.Gui.Text == tostring(expected) .. ". ")
		assert(entries[index].Gui.Position[1] == 40)
		assert(entries[index].Marker.Gui.Position[1] + entries[index].Marker.Width == 0, "Markers grow leftwards; text does not shift for two-digit numbers")
	end
	count = requests
	arrange(ordered, 80)
	assert(requests == count)
	local reverse = build('<ol reversed><li>AA</li><li>BB</li><li>CC</li></ol>')
	assert(reverse.Children[1].Children[1].Marker.Number == 3 and reverse.Children[1].Children[3].Marker.Number == 1)
	local restart = build('<ol><li>AA<ol start="4"><li>BB</li></ol></li><li>CC</li></ol>')
	assert(restart.Children[1].Children[1].Children[2].Children[1].Marker.Number == 4 and restart.Children[1].Children[2].Marker.Number == 2)
	local hidden = build('<ol><li>AA</li><li style="display: none">BB</li><li style="list-style-type: none">CC</li><li>DD</li></ol>')
	arrange(hidden)
	local hiddenList = hidden.Children[1]
	assert(#hiddenList.Children == 4 and #hiddenList.FlowChildren == 3, "Initially hidden list entries are retained without occupying flow")
	assert(hiddenList.Children[2].Gui.Visible == false and hiddenList.Children[3].Marker == nil and hiddenList.Children[4].Marker.Number == 3, "Hidden entries do not advance visible list numbering")
	local empty = build('<ol style="line-height: 20px"><li></li><li>AA</li></ol>')
	arrange(empty)
	assert(empty.Children[1].Children[1].Gui.Size[2] == 20 and empty.Children[1].Children[2].Gui.Position[2] == 20)
	local mixed = build('<ul style="line-height: 20px"><li><span style="font-size: 40px">AA</span> BB</li></ul>')
	arrange(mixed)
	local entry = mixed.Children[1].Children[1]
	assert(entry.Marker.Baseline == entry.Children[1].Items[1].LineBaseline)
	local paragraphs = build('<ul style="line-height: 20px"><li><p>AA</p></li><li><p>BB</p></li></ul>')
	assert(arrange(paragraphs) == 88, "16 outer + 20 text + 16 collapsed gap + 20 text + 16 outer")
	list = paragraphs.Children[1]
	assert(list.Gui.Size[2] == 56 and list.Children[1].Gui.Position[2] == 0 and list.Children[2].Gui.Position[2] == 36)
	assert(list.Children[1].Marker.Baseline == list.Children[1].Children[1].FirstBaseline)
	count = requests
	assert(arrange(paragraphs, 160) == 88 and requests == count, "Collapsed margins cannot accumulate during resize")
	local padded = build('<ul style="margin: 0; padding: 10px; line-height: 20px"><li><p>AA</p></li></ul>')
	assert(arrange(padded) == 72, "List padding separates its margins from the paragraph's")
	-- Outside markers belong beyond the li border, not its padded text edge.
	local cards = build('<ol start="9" style="margin:0;padding-left:28px"><li style="padding:16px;border:1px solid black"><p style="margin:0">AA</p></li><li style="padding:16px;border:1px solid black"><p style="margin:0">BB</p></li></ol>')
	for _, width in {240, 160} do
		arrange(cards, width)
		for _, card in cards.Children[1].Children do
			assert(card.Marker.Gui.Position[1] + card.Marker.Width == 0, "Padded, bordered cards keep both one- and two-digit markers outside their border")
			assert(card.Children[1].Gui.Position[1] == 17, "Marker placement does not change the card's content inset")
			assert(card.Marker.Baseline == card.Children[1].Gui.Position[2] + card.Children[1].FirstBaseline, "Outside numbering stays on the first paragraph baseline")
		end
	end
	local symbolCard = build('<ul><li style="padding:24px;border:3px solid black">AA</li></ul>')
	arrange(symbolCard)
	entry = symbolCard.Children[1].Children[1]
	assert(entry.Marker.Gui.Position[1] + entry.Marker.Gui.Size[1] <= 0, "Outside bullets also stay beyond padded borders")
	local insideCard = build('<ol style="list-style-position:inside"><li style="padding:16px;border:1px solid black">AA</li></ol>')
	arrange(insideCard)
	entry = insideCard.Children[1].Children[1]
	assert(entry.Marker.Gui.Position[1] == 17, "Inside markers retain the padded content edge")
	local overflow = build('<ul style="margin: 0; line-height: 20px"><li style="height: 10px; margin: 0 0 16px"><div style="height: 100px"></div></li></ul>')
	assert(arrange(overflow) == 100, "Collapsed bottom margin cannot shrink visible descendant overflow")
	local custom = build('<ul style="font-size: 30px; margin: 3px 0; padding: 0; list-style-type: square"><li>AA</li><li style="display: block">BB</li></ul>')
	assert(custom.Children[1].Style.Margin[1] == 3 and custom.Children[1].Children[1].Marker.Kind == "square" and custom.Children[1].Children[2].Marker == nil)
	for _, case in {
		{"decimal-leading-zero", {-10, -1, 0, 1, 9, 10}, {"-10", "-1", "00", "01", "09", "10"}},
		{"lower-alpha", {-1, 0, 1, 26, 27, 52, 702, 703}, {"-1", "0", "a", "z", "aa", "az", "zz", "aaa"}},
		{"upper-alpha", {1, 26, 27, 702, 703}, {"A", "Z", "AA", "ZZ", "AAA"}},
		{"lower-roman", {-1, 0, 4, 9, 40, 90, 400, 900, 3999, 4000}, {"-1", "0", "iv", "ix", "xl", "xc", "cd", "cm", "mmmcmxcix", "4000"}},
		{"upper-roman", {1, 4, 9, 49, 944, 3999, 4000}, {"I", "IV", "IX", "XLIX", "CMXLIV", "MMMCMXCIX", "4000"}},
	} do
		local parts = {'<ol style="list-style-type: ' .. case[1] .. '">'}
		for _, number in case[2] do table.insert(parts, '<li value="' .. number .. '">AA BB</li>') end
		table.insert(parts, '</ol>')
		local formatted = build(table.concat(parts))
		arrange(formatted, 160)
		for index, entry in formatted.Children[1].Children do
			assert(entry.Marker.Kind == case[1] and entry.Marker.Gui.ClassName == "TextLabel")
			assert(entry.Marker.Gui.Text == case[3][index] .. ". ", case[1] .. ": " .. entry.Marker.Gui.Text)
			assert(entry.Marker.Gui.Position[1] + entry.Marker.Width == 0)
		end
		count, allocated = requests, objects
		arrange(formatted, 90)
		assert(requests == count and objects == allocated, "All counter styles reuse measurements and labels on resize")
	end
	local alphaReverse = build('<ol reversed start="28" style="list-style-type: upper-alpha"><li>AA</li><li>BB</li><li>CC</li></ol>')
	arrange(alphaReverse)
	for index, expected in {"AB. ", "AA. ", "Z. "} do assert(alphaReverse.Children[1].Children[index].Marker.Gui.Text == expected) end
	local warn = 0
	local style = Style.resolve(fixtureElement("ul",{style = "list-style-type: lower-greek"}), {FontSize = 16}, function() warn += 1 end)
	assert(warn == 0 and style.ListStyleType == "lower-greek", "A valid counter-style name is accepted before its registry definition is resolved")
	local undefined = build('<ol style="list-style-type: MissingCounter"><li>AA</li><li>BB</li></ol>')
	arrange(undefined)
	for index, item in undefined.Children[1].Children do
		assert(item.Marker.Kind == "MissingCounter" and item.Marker.Gui.Text == tostring(index)..". ", "An undefined custom counter-style retains its name and renders the required decimal fallback")
	end
	style = Style.resolve(fixtureElement("ul",{style = "list-style-type: invalid marker"}), {FontSize = 16}, function() warn += 1 end)
	assert(warn == 1 and style.ListStyleType == "disc", "Malformed declarations still preserve the default marker style")
	assert(layout.arrange(tree, 100, 0, 0, function() return false end) == 0)
	print("Lists: defaults, nesting, multiline alignment, marker baselines, counters, hidden/empty items, margin collapse, overrides and resize reuse passed")
end
