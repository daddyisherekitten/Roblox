--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, parent, warn)
		return Style.resolve(fixtureElement('div',{style = css}), parent or {}, warn or error)
	end
	local defaults = resolve('', resolve('order:-3;align-self:center;flex-direction:column-reverse'))
	assert(defaults.Order == 0 and defaults.AlignSelf == 'auto' and defaults.FlexDirection == 'row')
	assert(resolve('order:-2;order:+3 !important;order:9').Order == 3)
	assert(resolve('align-self:center;align-self:auto').AlignSelf == 'auto')
	for _, css in {'order:1.5', 'order:1px', 'order:1e2', 'order:100001', 'order:-100001', 'align-self:last baseline'} do
		local warnings = 0
		resolve(css, nil, function() warnings += 1 end)
		assert(warnings == 1, css)
	end
	assert(resolve('align-self:normal').AlignSelf=='normal')
	local objects, measurements = 0, 0
	local renderer = loadRenderTree({create = function(_, _, props) objects += 1; return table.clone(props) end})
	local overrides = {['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(text, _, size) measurements += 1; return {X = #text * 5, Y = size} end}}
	overrides['Layout/WordLayout'] = loadWordLayout(overrides)
	local layout = loadBlockLayout(overrides)
	local function near(a, b) assert(math.abs(a - b) < 1e-5, tostring(a) .. ' != ' .. tostring(b)) end
	local function position(box, x, y) near(box.Gui.Position[1], x); near(box.Gui.Position[2], y) end
	local function arrange(tree, width) layout.arrange(tree, width, 0, 0, function() return true end) end
	local function build(css, children, width)
		local tree = renderer.build(Parser.parse('<div style="display:flex;' .. css .. '">' .. children .. '</div>'), {}, error)
		arrange(tree, width or 200)
		return tree, tree.Children[1].Children
	end
	local pair = '<div style="width:50px;height:20px">A</div><div style="width:50px;height:20px">B</div>'
	for mode, normal in {['flex-start'] = {0, 60}, ['flex-end'] = {190, 250}, center = {95, 155},
		['space-between'] = {0, 250}, ['space-around'] = {47.5, 202.5}, ['space-evenly'] = {190/3, 60+380/3}} do
		local _, boxes = build('flex-direction:row-reverse;gap:10px;justify-content:' .. mode, pair, 300)
		position(boxes[1], 250 - normal[1], 0); position(boxes[2], 250 - normal[2], 0)
	end
	local _, column = build('flex-direction:column-reverse;height:100px;gap:10px', pair)
	position(column[1], 0, 80); position(column[2], 0, 50)
	local _, columnGrow = build('flex-direction:column-reverse;height:200px;gap:20px', '<div style="flex:1"></div><div style="flex:2"></div>')
	near(columnGrow[1].OuterHeight, 60); near(columnGrow[2].OuterHeight, 120)
	position(columnGrow[1], 0, 140); position(columnGrow[2], 0, 0)
	local ordered = '<div id="a" style="order:1;width:40px;height:20px">A</div><div id="b" style="order:-1;width:40px;height:20px">B</div><div id="c" style="order:1;width:40px;height:20px">C</div><span id="d" style="width:40px;height:20px">D</span>'
	local tree, items = build('gap:10px', ordered)
	position(items[2], 0, 0); position(items[4], 50, 0); position(items[1], 100, 0); position(items[3], 150, 0)
	assert(items[1].Node.Attributes.id == 'a' and items[2].Node.Attributes.id == 'b' and items[3].Node.Attributes.id == 'c')
	assert(items[1].Node.Parent.Children[1] == items[1].Node, 'DOM order is preserved')
	assert(items[2].Gui.ZIndex < items[4].Gui.ZIndex and items[1].Gui.ZIndex < items[3].Gui.ZIndex)
	local allocated, measured = objects, measurements
	arrange(tree, 300); arrange(tree, 200)
	assert(allocated == objects and measured == measurements)
	for _, direction in {'row', 'row-reverse'} do
		for _, wrap in {'wrap', 'wrap-reverse'} do
			local _, boxes = build('gap:10px;height:100px;align-content:flex-start;flex-direction:' .. direction .. ';flex-wrap:' .. wrap, ordered, 100)
			local firstX = if direction == 'row' then 0 else 60
			local secondX = if direction == 'row' then 50 else 10
			local firstY = if wrap == 'wrap' then 0 else 80
			local secondY = if wrap == 'wrap' then 30 else 50
			position(boxes[2], firstX, firstY); position(boxes[4], secondX, firstY)
			position(boxes[1], firstX, secondY); position(boxes[3], secondX, secondY)
		end
	end
	local _, twoAxes = build('flex-direction:column-reverse;flex-wrap:wrap-reverse;height:50px;gap:10px;align-content:flex-start', ordered)
	position(twoAxes[2], 160, 30); position(twoAxes[4], 160, 0)
	position(twoAxes[1], 110, 30); position(twoAxes[3], 110, 0)
	for mode, y in {auto = 40, ['flex-start'] = 0, ['flex-end'] = 80, center = 40, stretch = 0} do
		local _, boxes = build('height:100px;align-items:center', '<div style="width:50px;height:20px;align-self:' .. mode .. '">A</div>')
		position(boxes[1], 0, y); near(boxes[1].OuterHeight, 20)
	end
	local _, stretch = build('height:100px;align-items:flex-start', '<div style="align-self:stretch;max-height:80px;line-height:20px">A</div><div style="line-height:20px">B</div>')
	near(stretch[1].OuterHeight, 80); near(stretch[2].OuterHeight, 20)
	local _, widths = build('flex-direction:column', '<div style="align-self:center;height:20px">AA</div><div style="align-self:flex-end;height:20px">AA</div><div style="align-self:stretch;height:20px">AA</div>')
	position(widths[1], 95, 0); position(widths[2], 190, 20); near(widths[3].OuterWidth, 200)
	local _, reverseSelf = build('flex-wrap:wrap-reverse;height:100px', '<div style="align-self:flex-end;height:20px">A</div>')
	position(reverseSelf[1], 0, 0)
	local _, edges = build('height:60px;flex-direction:row-reverse', '<div style="width:50px;height:10px;padding:5px;margin:2px 7px 4px 3px;align-self:flex-end"></div>')
	position(edges[1], 133, 36)
	local _, anonymous = build('order:-5;align-self:flex-end;align-items:flex-start;gap:10px', 'AA<div style="order:-1;width:30px;height:20px"></div>BB')
	position(anonymous[2], 0, 0); near(anonymous[1].Items[1].Gui.Position[1], 40); near(anonymous[3].Items[1].Gui.Position[1], 60)
	local nested, nestedItems = build('', '<div style="display:flex;flex-direction:column-reverse"><div style="width:30px;height:10px"></div><div style="width:40px;height:20px"></div></div>')
	near(nestedItems[1].OuterWidth, 40); near(nested.Children[1].OuterHeight, 30)
	position(nestedItems[1].Children[1], 0, 20)
	local outside = renderer.build(Parser.parse('<div style="order:5;align-self:flex-end;width:50px;height:20px"></div><div style="order:-1;height:10px"></div>'), {}, error)
	arrange(outside, 200); position(outside.Children[1], 0, 0); position(outside.Children[2], 0, 20)
	print('Flex item controls: stable visual order, unchanged DOM, block paint order, per-item alignment, both reverse axes, wrap combinations and reuse passed')
end
