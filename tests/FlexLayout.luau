--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, parent, warn)
		return Style.resolve(fixtureElement('div',{style = css}), parent or {}, warn or error)
	end
	local defaults = resolve('display:flex')
	assert(defaults.Display == 'flex' and not defaults.Hidden and defaults.FlexDirection == 'row' and defaults.AlignItems == 'stretch')
	assert(resolve('', resolve('display:flex; gap:3px 7px; flex-direction:column; justify-content:center; align-items:flex-end')).Gap[1] == 0)
	assert(resolve('display:none; display:flex').Display == 'flex' and not resolve('display:none; display:flex').Hidden)
	assert(resolve('display:none !important; display:flex').Hidden)
	for _, css in {'gap:-1px', 'gap:-10%', 'gap:1px 2px 3px', 'flex-direction:bad', 'align-items:last baseline', 'justify-content:bad'} do
		local count = 0
		resolve(css, nil, function() count += 1 end)
		assert(count == 1, css)
	end
	local objects, measurements = 0, 0
	local renderer = loadRenderTree({create = function(class, parent, props)
		objects += 1; local gui = table.clone(props); gui.Parent, gui.ClassName = parent, class; return gui
	end})
	local overrides = {['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(text, _, size) measurements += 1; return {X = #text * 5, Y = size} end}}
	local words = loadWordLayout(overrides)
	overrides['Layout/WordLayout'] = words
	local layout = loadBlockLayout(overrides)
	local function build(html) return renderer.build(Parser.parse(html), {}, error) end
	local function arrange(tree, width) return layout.arrange(tree, width or 300, 0, 0, function() return true end) end
	local function near(a, b) assert(math.abs(a - b) < .00001, tostring(a) .. ' != ' .. tostring(b)) end
	local function position(box, x, y) near(box.Gui.Position[1], x); near(box.Gui.Position[2], y) end
	for justify, positions in {
		['flex-start'] = {0, 60}, ['flex-end'] = {190, 250}, center = {95, 155},
		['space-between'] = {0, 250}, ['space-around'] = {47.5, 202.5}, ['space-evenly'] = {190/3, 60+380/3},
	} do
		local tree = build('<div style="display:flex; gap:10px; justify-content:' .. justify .. '"><div style="width:50px; height:20px"></div><div style="width:50px; height:30px"></div></div><div style="height:5px"></div>')
		arrange(tree)
		local box = tree.Children[1]
		position(box.Children[1], positions[1], 0); position(box.Children[2], positions[2], 0)
		near(box.OuterHeight, 30); position(tree.Children[2], 0, 30)
	end
	for align, y in {['flex-start'] = 0, center = 40, ['flex-end'] = 80, stretch = 0} do
		local tree = build('<div style="display:flex; height:100px; align-items:' .. align .. '"><div style="width:50px; height:20px"></div></div>')
		arrange(tree); position(tree.Children[1].Children[1], 0, y)
		near(tree.Children[1].Children[1].OuterHeight, 20)
	end
	local bars=build('<style>.bars{display:flex;align-items:end;gap:3px;height:32px}.bars span{display:block;flex:1}</style><div class="bars"><span style="height:10px"></span><span style="height:17px"></span><span style="height:24px"></span></div>')
	for _,width in {180,120,300} do
		arrange(bars,width)
		for index,child in bars.Children[1].Children do
			near(child.LayoutY+child.OuterHeight,32)
			near(child.OuterWidth,(width-6)/3)
			position(child,(index-1)*((width-6)/3+3),32-child.OuterHeight)
		end
	end
	for _,case in {
		{'row','ltr','start',0,60},{'row','ltr','end',190,250},
		{'row-reverse','ltr','start',60,0},{'row-reverse','ltr','end',250,190},
		{'row','rtl','start',250,190},{'row','rtl','end',60,0},
		{'row-reverse','rtl','start',190,250},{'row-reverse','rtl','end',0,60},
	} do
		local logical=build('<div style="display:flex;gap:10px;flex-direction:'..case[1]..';direction:'..case[2]..';justify-content:'..case[3]..'"><div style="width:50px;height:20px"></div><div style="width:50px;height:20px"></div></div>')
		arrange(logical,300)
		position(logical.Children[1].Children[1],case[4],0);position(logical.Children[1].Children[2],case[5],0)
	end
	for _,case in {{'start','ltr',0},{'end','ltr',80},{'start','rtl',80},{'end','rtl',0},{'flex-start','rtl',80}} do
		local logical=build('<div style="display:flex;flex-direction:column;direction:'..case[2]..';align-items:'..case[1]..'"><div style="width:20px;height:10px"></div></div>')
		arrange(logical,100);position(logical.Children[1].Children[1],case[3],0)
	end
	for _,case in {{'start',0},{'end',80}} do
		local logical=build('<div style="display:flex;flex-wrap:wrap-reverse;height:100px;align-items:'..case[1]..'"><div style="width:50px;height:20px"></div></div>')
		arrange(logical,100);position(logical.Children[1].Children[1],0,case[2])
	end
	local stretch = build('<div style="display:flex; padding:10px; border:2px solid; height:100px"><div style="width:40px; margin:3px; padding:4px; border:1px solid">A</div><div style="max-height:60px">B</div></div>')
	arrange(stretch)
	local box = stretch.Children[1]
	near(box.Children[1].OuterHeight, 94); near(box.Children[2].OuterHeight, 60)
	position(box.Children[1], 15, 15)
	local column = build('<div style="display:flex; flex-direction:column; gap:7px 90px; height:100px; align-items:center; justify-content:center"><div style="width:40px; height:20px"></div><div style="width:60px; height:30px"></div></div>')
	arrange(column)
	position(column.Children[1].Children[1], 130, 21.5); position(column.Children[1].Children[2], 120, 48.5)
	local embeddedStack = build('<div style="display:flex;flex-direction:column;align-items:flex-start;gap:19px"><div style="width:150px;height:160px"></div><div style="width:150px;height:90px"></div><div style="width:150px;height:90px"></div></div>')
	arrange(embeddedStack, 289)
	local embeddedItems = embeddedStack.Children[1].Children
	local firstGap = embeddedItems[2].Gui.Position[2] - embeddedItems[1].Gui.Position[2] - embeddedItems[1].OuterHeight
	local secondGap = embeddedItems[3].Gui.Position[2] - embeddedItems[2].Gui.Position[2] - embeddedItems[2].OuterHeight
	assert(firstGap == 19 and secondGap == 19, 'Consecutive embedded boxes keep exactly the same CSS gap')
	local margins = build('<div style="display:flex; flex-direction:column; gap:5px"><div style="height:10px; margin-bottom:12px"></div><div style="height:10px; margin-top:8px"></div></div>')
	arrange(margins); position(margins.Children[1].Children[2], 0, 35); near(margins.Children[1].OuterHeight, 45)
	local intrinsic = build('<div style="display:flex; gap:10px; align-items:flex-start"><span style="padding:3px">AAAA</span><div>BB</div></div>')
	arrange(intrinsic)
	assert(intrinsic.Children[1].Children[1].Node.Name == 'span', 'Direct inline elements become separate flex items')
	near(intrinsic.Children[1].Children[1].OuterWidth, 26); position(intrinsic.Children[1].Children[2], 36, 0)
	local anonymous = build('<div style="display:flex; gap:10px">AA<div style="width:20px; height:10px"></div>BB</div>')
	arrange(anonymous)
	local items = anonymous.Children[1].Children
	assert(#items == 3 and items[1].Kind == 'Words' and items[3].Kind == 'Words')
	position(items[2], 20, 0); near(items[3].Items[1].Gui.Position[1], 50)
	local nested = build('<div style="display:flex; gap:10px"><div style="display:flex; flex-direction:column; gap:5px"><div style="width:30px; height:10px"></div><div style="width:40px; height:20px"></div></div><div style="width:20px"></div></div>')
	arrange(nested); near(nested.Children[1].OuterHeight, 35); position(nested.Children[1].Children[2], 50, 0)
	local percent = build('<div style="display:flex; gap:10px"><div style="width:50%; padding:5px; box-sizing:border-box; height:20px"></div><div style="width:30px; visibility:hidden"></div><div style="display:none; width:50px"></div></div>')
	arrange(percent, 200); near(percent.Children[1].Children[1].OuterWidth, 100); position(percent.Children[1].Children[2], 110, 0)
	assert(#percent.Children[1].Children == 3 and #percent.Children[1].FlowChildren == 2
		and not percent.Children[1].Children[3].Gui.Visible, 'Hidden flex items are retained but consume neither width nor gap')
	local before, measured = objects, measurements
	arrange(intrinsic, 500); arrange(intrinsic, 100)
	assert(objects == before and measurements == measured, 'Flex reflow must reuse labels and native text bounds')
	local empty = build('<div style="display:flex; gap:99px"></div>')
	assert(arrange(empty) == 0)
	local autoRatio = build('<div style="display:flex"><div style="aspect-ratio:auto; height:30px">AB</div></div>')
	arrange(autoRatio); near(autoRatio.Children[1].Children[1].OuterWidth, 10)
	local ratio = build('<div style="display:flex; align-items:flex-start"><div style="aspect-ratio:2; height:30px"></div></div>')
	arrange(ratio); near(ratio.Children[1].Children[1].OuterWidth, 60)
	local over = build('<div style="display:flex; overflow:hidden"><div style="width:400px; height:30px"></div></div>')
	local h, w = arrange(over, 100); near(h, 30); near(w, 100)
	assert(layout.arrange(over, 100, 0, 0, function() return false end) == 0)
	-- Shorthands reset omitted components; longhands and important still cascade.
	for css, expected in {
		['flex:1'] = {1, 1, 0, true}, ['flex:2 3'] = {2, 3, 0, true},
		['flex:2 0 40px'] = {2, 0, 40, false}, ['flex:30% 2 0'] = {2, 0, 30, true},
		['flex:50px'] = {1, 1, 50, false}, ['flex:0 0 0'] = {0, 0, 0, false},
		['flex:none'] = {0, 0, 'auto'}, ['flex:auto'] = {1, 1, 'auto'}, ['flex:initial'] = {0, 1, 'auto'},
		['flex:content'] = {1, 1, 'content'}, ['flex:2;flex-shrink:0;flex-basis:10px'] = {2, 0, 10, false},
		['flex-grow:5;flex:none'] = {0, 0, 'auto'}, ['flex:2 !important;flex-grow:8'] = {2, 1, 0, true},
		['flex-grow:5 !important;flex:none'] = {5, 0, 'auto'},
	} do
		local s = resolve(css)
		assert(s.FlexGrow == expected[1] and s.FlexShrink == expected[2], css)
		if type(expected[3]) == 'string' then assert(s.FlexBasis == expected[3], css)
		else assert(s.FlexBasis.Value == expected[3] and s.FlexBasis.Percent == expected[4], css) end
	end
	local noInheritance = resolve('', resolve('flex:3 2 50px'))
	assert(noInheritance.FlexGrow == 0 and noInheritance.FlexShrink == 1 and noInheritance.FlexBasis == 'auto')
	for _, css in {'flex:-1', 'flex:1 -2', 'flex:1 2 3', 'flex:1 auto 2', 'flex:1 2 3px 4', 'flex:none 1',
		'flex-grow:NaN', 'flex-grow:1px', 'flex-shrink:-1', 'flex-basis:-5px'} do
		local count = 0
		local s = resolve('flex:2 3 40px;' .. css, nil, function() count += 1 end)
		assert(count == 1 and s.FlexGrow == 2 and s.FlexShrink == 3 and s.FlexBasis.Value == 40, css)
	end
	local relativeBasis = resolve('font-size:20px;flex-basis:20ex')
	assert(relativeBasis.FlexBasis.Value == 200 and not relativeBasis.FlexBasis.Percent,
		'Font-relative flex bases share the computed font length context')
	local function sizes(container, children, available, expected, columnAxis)
		local tree = build('<div style="display:flex;' .. container .. '">' .. children .. '</div><div style="height:5px"></div>')
		arrange(tree, available)
		for i, size in expected do near(if columnAxis then tree.Children[1].Children[i].OuterHeight else tree.Children[1].Children[i].OuterWidth, size) end
		position(tree.Children[2], 0, tree.Children[1].OuterHeight)
		return tree
	end
	local growing = sizes('gap:10px', '<div style="flex:1;min-width:0">A</div><div style="flex:2;min-width:0">B</div>', 310, {100, 200})
	position(growing.Children[1].Children[2], 110, 0)
	local allocated, cached = objects, measurements
	arrange(growing, 160); near(growing.Children[1].Children[1].OuterWidth, 50); near(growing.Children[1].Children[2].OuterWidth, 100)
	arrange(growing, 310)
	assert(objects == allocated and measurements == cached, 'Flexible resizing reuses labels and measurements')
	sizes('', '<div style="width:100px;flex-grow:1"></div><div style="width:50px;flex-grow:2"></div>', 300, {150, 150})
	sizes('', '<div style="width:200px"></div><div style="width:100px"></div>', 150, {100, 50})
	sizes('', '<div style="width:200px;flex-shrink:0"></div><div style="width:100px"></div>', 250, {200, 50})
	sizes('', '<div style="width:100px;flex:none"></div><div style="width:100px;flex:none"></div>', 100, {100, 100})
	sizes('', '<div style="flex:1;max-width:80px"></div><div style="flex:1"></div>', 300, {80, 220})
	sizes('', '<div style="width:200px;min-width:180px"></div><div style="width:100px"></div>', 250, {180, 70})
	sizes('', '<div style="flex:1;min-width:200px;max-width:100px"></div><div style="flex:1"></div>', 300, {200, 100})
	local partial = sizes('justify-content:center', '<div style="flex:.25 0 0px"></div><div style="flex:.25 0 0px"></div>', 200, {50, 50})
	position(partial.Children[1].Children[1], 50, 0)
	sizes('', '<div style="width:100px;flex-shrink:.25"></div><div style="width:100px;flex-shrink:.25"></div>', 100, {75, 75})
	sizes('', '<div style="width:999px;flex:0 0 25%"></div><div style="flex:1"></div>', 200, {50, 150})
	sizes('', '<div style="width:100px;flex:0 0 content">AAAA</div>', 200, {20})
	sizes('', '<div style="flex:1;box-sizing:border-box;padding:10px"></div><div style="flex:1;box-sizing:border-box;padding:20px"></div>', 200, {100, 100})
	sizes('gap:10px', '<div style="flex:1;padding:10px;border:2px solid;margin:5px"></div><div style="flex:1"></div>', 200, {102, 78})
	-- Auto minimum follows unbreakable content, unless min-width:0 or hidden overflow opts out.
	sizes('', '<div>AAAAAAAA</div><div>BB</div>', 30, {40, 10})
	sizes('', '<div style="min-width:0">AAAAAAAA</div><div style="min-width:0">BB</div>', 30, {24, 6})
	sizes('', '<div style="overflow:hidden">AAAAAAAA</div><div style="overflow:hidden">BB</div>', 30, {24, 6})
	sizes('', '<div style="overflow-wrap:break-word">AAAAAAAA</div>', 20, {40})
	sizes('', '<div style="width:15px">AAAAAAAA</div>', 10, {15})
	sizes('', '<div style="flex:1">AA BB</div><div style="width:10px;flex:none"></div>', 20, {10, 10})
	sizes('flex-direction:column;height:310px;gap:10px', '<div style="flex:1;min-height:0"></div><div style="flex:2;min-height:0"></div>', 200, {100, 200}, true)
	sizes('flex-direction:column;height:150px', '<div style="height:200px"></div><div style="height:100px"></div>', 200, {100, 50}, true)
	sizes('flex-direction:column;height:300px', '<div style="flex:1;max-height:80px"></div><div style="flex:1"></div>', 200, {80, 220}, true)
	sizes('flex-direction:column;height:200px', '<div style="flex:0 0 25%"></div><div style="flex:1"></div>', 200, {50, 150}, true)
	local indefinite = sizes('flex-direction:column', '<div style="flex:0 0 50%;height:80px"><div style="height:20px"></div></div>', 200, {20}, true)
	near(indefinite.Children[1].OuterHeight, 20)
	sizes('flex-direction:column', '<div style="flex:1"><div style="height:20px"></div></div><div style="flex:1"><div style="height:30px"></div></div>', 200, {20, 30}, true)
	local cascade = build('<style>.item{flex:1} #special{flex-grow:2}</style><div style="display:flex"><div class="item"></div><span id="special" class="item" style="flex-basis:0px"></span></div>')
	arrange(cascade, 300); near(cascade.Children[1].Children[1].OuterWidth, 100); near(cascade.Children[1].Children[2].OuterWidth, 200)
	local outside = build('<div style="width:80px;flex:1"></div>')
	arrange(outside, 300); near(outside.Children[1].OuterWidth, 80)
	local wrapped = sizes('', '<div style="flex:1;line-height:20px">AA BB</div><div style="flex:1"></div>', 40, {20, 20})
	near(wrapped.Children[1].OuterHeight, 40); position(wrapped.Children[2], 0, 40)
	arrange(wrapped, 100); near(wrapped.Children[1].OuterHeight, 20); position(wrapped.Children[2], 0, 20)
	local nestedFlex = sizes('gap:10px', '<div style="flex:1;display:flex;min-width:0"><div style="flex:1"></div><div style="flex:1"></div></div><div style="flex:1"></div>', 210, {100, 100})
	near(nestedFlex.Children[1].Children[1].Children[1].OuterWidth, 50)
	arrange(nestedFlex, 110); near(nestedFlex.Children[1].Children[1].Children[1].OuterWidth, 25)
	sizes('flex-direction:column;height:300px', '<div style="width:100px;aspect-ratio:2;flex:auto"></div><div style="height:100px;flex:auto"></div>', 200, {125, 175}, true)
	sizes('flex-direction:column;height:30px', '<div><div style="height:40px"></div></div><div><div style="height:10px"></div></div>', 200, {40, 10}, true)
	sizes('flex-direction:column;height:30px', '<div style="min-height:0"><div style="height:40px"></div></div><div style="min-height:0"><div style="height:10px"></div></div>', 200, {24, 6}, true)
	-- Intrinsic probes share native measurement caches, but never repaint or allocate GUI fragments.
	local probeTree = build('<div style="display:flex"><div style="text-decoration:underline;overflow-wrap:break-word;min-width:0">AAAAAAAA</div></div>')
	arrange(probeTree, 10)
	local run = probeTree.Children[1].Children[1].Children[1]
	local originalPosition, probeObjects = run.Items[1].Gui.Position, objects
	layout.naturalWidth(run, 10, function() return true end, true, true)
	assert(run.Items[1].Gui.Position == originalPosition and objects == probeObjects)
	arrange(probeTree, 100); near(probeTree.Children[1].Children[1].OuterWidth, 40)
	print('Flexible sizing: cascade, weighted grow/shrink, partial factors, freezing at limits, box edges, auto minima, bases, both axes and resize reuse passed')
	print('Flex: row/column, gaps, six main alignments, cross alignment/stretch, box sizing, margins, intrinsic/anonymous/inline items, nesting, percentages, clipping and reflow reuse passed')
end
