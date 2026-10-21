--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, parent, warn)
		return Style.resolve(fixtureElement('div',{style = css}), parent or {}, warn or error)
	end
	assert(resolve('').FlexWrap == 'nowrap' and resolve('').AlignContent == 'stretch')
	assert(resolve('', resolve('flex-wrap:wrap;align-content:center')).FlexWrap == 'nowrap')
	assert(resolve('', resolve('align-content:center')).AlignContent == 'stretch')
	assert(resolve('flex-wrap:wrap !important;flex-wrap:nowrap').FlexWrap == 'wrap')
	assert(resolve('align-content:safe center').AlignContent == 'safe center', 'Explicit safe center is a valid positional content value')
	for _, css in {'flex-wrap:bad', 'flex-wrap:wrap nowrap', 'align-content:baseline', 'align-content:safe stretch'} do
		local count = 0
		resolve(css, nil, function() count += 1 end)
		assert(count == 1, css)
	end
	local objects, measurements = 0, 0
	local renderer = loadRenderTree({create = function(_, _, props) objects += 1; return table.clone(props) end})
	local overrides = {['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(text, _, size) measurements += 1; return {X = #text * 5, Y = size} end}}
	overrides['Layout/WordLayout'] = loadWordLayout(overrides)
	local layout = loadBlockLayout(overrides)
	local function near(a, b) assert(math.abs(a - b) < 1e-5, tostring(a) .. ' != ' .. tostring(b)) end
	local function position(box, x, y) near(box.Gui.Position[1], x); near(box.Gui.Position[2], y) end
	local function arrange(tree, width) return layout.arrange(tree, width, 0, 0, function() return true end) end
	local function build(css, content, width)
		local html = '<div style="display:flex;flex-wrap:wrap;' .. css .. '">' .. content .. '</div><div style="height:5px"></div>'
		local tree = renderer.build(Parser.parse(html), {}, error)
		arrange(tree, width)
		return tree, tree.Children[1].Children
	end
	local cards = '<div style="width:100px;height:20px">A</div><div style="width:100px;height:40px">B</div><div style="width:100px;height:30px">C</div>'
	local tree, items = build('gap:10px 5px', cards, 250)
	position(items[1], 0, 0); position(items[2], 105, 0); position(items[3], 0, 50)
	near(tree.Children[1].OuterHeight, 80); position(tree.Children[2], 0, 80)
	local cached, allocated = measurements, objects
	arrange(tree, 310); position(items[3], 210, 0); near(tree.Children[1].OuterHeight, 40)
	arrange(tree, 100); position(items[2], 0, 30); position(items[3], 0, 80); near(tree.Children[1].OuterHeight, 110)
	arrange(tree, 205); position(items[2], 105, 0); position(items[3], 0, 50)
	arrange(tree, 204.5); position(items[2], 0, 30)
	assert(cached == measurements and allocated == objects, 'Changing line count reuses native measurements and labels')
	local _, noWrap = build('flex-wrap:nowrap;gap:10px', cards, 250)
	position(noWrap[3], 2 * (230/3 + 10), 0); near(noWrap[1].OuterWidth, 230/3)
	local _, grow = build('gap:10px', '<div style="flex:1 1 120px;height:20px"></div><div style="flex:1 1 120px;height:20px"></div><div style="flex:1 1 120px;height:20px"></div>', 300)
	near(grow[1].OuterWidth, 145); near(grow[2].OuterWidth, 145); near(grow[3].OuterWidth, 300); position(grow[3], 0, 30)
	local _, limits = build('', '<div style="flex:1;min-width:80px;height:20px"></div><div style="flex:1;min-width:80px;height:20px"></div>', 150)
	near(limits[1].OuterWidth, 150); position(limits[2], 0, 20)
	local _, maximum = build('gap:5px', '<div style="flex:0 1 200px;max-width:80px;height:10px"></div><div style="flex:0 1 200px;max-width:80px;height:10px"></div>', 165)
	position(maximum[2], 85, 0)
	local _, oversized = build('gap:5px', '<div style="width:300px;flex:none;height:20px"></div><div style="width:30px;height:10px"></div>', 100)
	near(oversized[1].OuterWidth, 300); position(oversized[2], 0, 25)
	local _, zero = build('', '<div style="width:100px;height:20px"></div><div style="width:0;height:10px"></div>', 100)
	position(zero[2], 100, 0)
	local _, percentage = build('gap:10px', '<div style="flex:0 0 50%;height:20px"></div><div style="flex:0 0 50%;height:20px"></div>', 200)
	near(percentage[1].OuterWidth, 100); position(percentage[2], 0, 30)
	local _, boxes = build('padding:10px;border:2px solid;gap:7px 5px', '<div style="width:50px;padding:5px;border:1px solid;margin:3px;height:10px"></div><div style="width:50px;padding:5px;border:1px solid;margin:3px;height:20px"></div>', 159)
	position(boxes[1], 15, 15); position(boxes[2], 15, 50)
	-- Cross-axis distribution: two lines with natural heights 40 and 30 plus a 10px gap.
	for mode, expected in {
		['flex-start'] = {0, 50}, ['flex-end'] = {100, 150}, center = {50, 100},
		['space-between'] = {0, 150}, ['space-around'] = {25, 125}, ['space-evenly'] = {100/3, 50+200/3}, stretch = {0, 100},
	} do
		local _, aligned = build('height:180px;gap:10px 5px;align-content:' .. mode, cards, 250)
		position(aligned[1], 0, expected[1]); position(aligned[3], 0, expected[2])
	end
	local _, oneLine = build('height:100px;align-content:center', '<div style="height:20px;width:50px"></div>', 100)
	position(oneLine[1], 0, 40)
	local _, oneNoWrap = build('flex-wrap:nowrap;height:100px;align-content:center', '<div style="height:20px;width:50px"></div>', 100)
	position(oneNoWrap[1], 0, 0)
	local _, stretch = build('height:100px;gap:10px', '<div style="width:60px;line-height:20px">A</div><div style="width:60px;line-height:20px">B</div>', 100)
	near(stretch[1].OuterHeight, 45); position(stretch[2], 0, 55)
	local _, itemAlign = build('align-items:flex-end;gap:10px 5px', cards, 250)
	position(itemAlign[1], 0, 20); position(itemAlign[3], 0, 50)
	local _, justify = build('justify-content:center;gap:10px 5px', cards, 250)
	position(justify[1], 22.5, 0); position(justify[3], 75, 50)
	local _, reverse = build('flex-wrap:wrap-reverse;gap:10px 5px', cards, 250)
	position(reverse[1], 0, 60); position(reverse[2], 105, 40); position(reverse[3], 0, 0)
	local columnCards = '<div style="height:40px">AA</div><div style="height:40px">AAAA</div><div style="height:40px">AAAAAA</div>'
	local column, cols = build('flex-direction:column;height:100px;gap:10px 20px;align-content:flex-start', columnCards, 200)
	position(cols[1], 0, 0); position(cols[2], 0, 50); position(cols[3], 40, 0)
	near(cols[1].OuterWidth, 20); near(cols[3].OuterWidth, 30); near(column.Children[1].OuterHeight, 100)
	local _, stretchedCols = build('flex-direction:column;height:100px;gap:10px 20px', columnCards, 200)
	near(stretchedCols[1].OuterWidth, 85); position(stretchedCols[3], 105, 0); near(stretchedCols[3].OuterWidth, 95)
	local _, reversedCols = build('flex-direction:column;flex-wrap:wrap-reverse;height:100px;gap:10px 20px;align-content:flex-start;align-items:flex-start', columnCards, 200)
	position(reversedCols[1], 190, 0); position(reversedCols[2], 180, 50); position(reversedCols[3], 130, 0)
	local autoColumn, autoItems = build('flex-direction:column;gap:10px 20px', columnCards, 200)
	position(autoItems[3], 0, 100); near(autoColumn.Children[1].OuterHeight, 140)
	local _, maxColumn = build('flex-direction:column;max-height:100px;gap:10px 20px;align-content:flex-start', columnCards, 200)
	position(maxColumn[3], 40, 0)
	local clipped = build('height:20px;overflow:hidden;gap:10px', cards, 100)
	local clippedH, clippedW = arrange(clipped, 100); near(clippedH, 25); near(clippedW, 100)
	local overflowing = build('height:20px;align-content:space-around;gap:10px', cards, 100)
	position(overflowing.Children[1].Children[1], 0, 0)
	local extent = arrange(overflowing, 100); near(extent, 110)
	local empty = build('gap:50px', '', 100); near(empty.Children[1].OuterHeight, 0)
	local nested = build('flex-wrap:nowrap', '<div style="display:flex;flex-wrap:wrap"><div style="width:50px;height:10px;flex:none"></div><div style="width:50px;height:10px;flex:none"></div></div><div style="width:20px;flex:none"></div>', 90)
	near(nested.Children[1].Children[1].OuterWidth, 70)
	position(nested.Children[1].Children[1].Children[2], 0, 10)
	assert(layout.arrange(tree, 100, 0, 0, function() return false end) == 0)
	print('Flex wrap: line breaks before flexing, independent line sizes, row/column gaps, align-content, reverse, limits, overflow, nesting and resize reuse passed')
end
