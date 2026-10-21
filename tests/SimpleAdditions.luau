--!strict
return function(Parser, Style, Color, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local base = {Font = 'Roboto', FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function resolve(name, css, parent, warn, author)
		return Style.resolve(fixtureElement(name,{style = css}), parent or base, warn or error, false, author)
	end
	local function near(a, b) assert(math.abs(a - b) < .00001, tostring(a) .. ' ~= ' .. tostring(b)) end
	for _, value in {'hsl(0,100%,50%)', 'hsla(360,100%,50%,1)', 'hsl(-1turn 100% 50%)', 'hsl(400grad 100 50 / 100%)', 'hsla(0rad 100% 50%)', 'hsl(720deg, 100%, 50%)'} do
		local c, a = Color.parse(value)
		assert(c, value); near(c.R, 1); near(c.G, 0); near(c.B, 0); near(a, 1)
	end
	for _, value in {'hsl(120,100%,50%)', 'hsl(120deg 100% 50% / 25%)'} do
		local c = Color.parse(value); near(c.R, 0); near(c.G, 1); near(c.B, 0)
	end
	local blue = Color.parse('hsl(240 100% 50%)'); near(blue.B, 1); near(blue.R, 0)
	local gray = Color.parse('hsl(10, -50%, 25%)'); near(gray.R, .25); near(gray.G, .25)
	local white, zero = Color.parse('hsla(1, 200%, 150%, -1)'); near(white.R, 1); near(zero, 0)
	for _, value in {'hsl(0,100,50)', 'hsl(0 100% 50%,.5)', 'hsl(0,100%,50%,)', 'hsla(0 100% 50% /)', 'hsl(0 100% 50% / .5 / .5)', 'hsl(none 50% 50%)', 'hsl(0px 100% 50%)', 'hsl(0 50% 50% 1)', 'hsl(100001,50%,50%)'} do
		assert(Color.parse(value) == nil, value)
	end
	local colorCSS = 'hsl(0 100% 50% / .25)'
	local s = resolve('div', 'color:' .. colorCSS .. ';background:' .. colorCSS .. ';border:4px groove ' .. colorCSS .. ';outline:solid ' .. colorCSS .. ';text-decoration:underline ' .. colorCSS .. ';text-shadow:1px 1px ' .. colorCSS .. ';box-shadow:1px 2px ' .. colorCSS)
	near(s.ColorAlpha, .25); near(s.BorderColorAlpha, .25); near(s.OutlineColorAlpha, .25)
	near(s.Decorations[1].Alpha, .25); near(s.TextShadows[1].Alpha, .25); near(s.BoxShadows[1].Alpha, .25)
	assert(resolve('div', 'word-wrap:break-word;overflow-wrap:normal').OverflowWrap == 'normal')
	assert(resolve('div', 'overflow-wrap:normal;word-wrap:break-word').OverflowWrap == 'break-word')
	assert(resolve('div', 'word-wrap:break-word!important;overflow-wrap:normal').OverflowWrap == 'break-word')
	assert(resolve('div', 'word-wrap:normal', nil, nil, 'overflow-wrap:break-word!important').OverflowWrap == 'break-word')
	assert(resolve('div', '', resolve('div', 'word-wrap:break-word')).OverflowWrap == 'break-word')
	assert(resolve('address', '').FontStyle == 'italic' and resolve('address', 'font-style:normal').FontStyle == 'normal')
	assert(resolve('address', '').Margin[1] == 0)
	assert(resolve('dl', '').Margin[1] == 20 and resolve('dl', '').Padding[4] == 0)
	assert(resolve('dt', '').FontWeight == 400 and resolve('dt', '').Margin[4] == 0)
	assert(resolve('dd', '').Margin[4] == 40 and resolve('dd', 'margin-left:7px').Margin[4] == 7)
	local figure = resolve('figure', 'font-size:30px;margin-top:3px')
	assert(figure.Margin[1] == 3 and figure.Margin[3] == 30 and figure.Margin[4] == 40)
	assert(resolve('figcaption', '').Margin[1] == 0 and resolve('figcaption', '').TextAlign == 'start')
	local implicit = Parser.parse('<dl><dt>A<dd>B<dt>C<dd>D</dl>')
	assert(#implicit.Diagnostics == 0 and #implicit.Children[1].Children == 4)
	local nested = Parser.parse('<dl><dt>A<dd>B<dl><dt>C<dd>D</dl><dt>E</dl>')
	assert(#nested.Diagnostics == 0 and #nested.Children[1].Children == 3)
	local objects, measures = 0, 0
	local factory = {create = function(class, parent, props)
		objects += 1; local gui = table.clone(props); gui.ClassName, gui.Parent = class, parent; return gui
	end, modifier = function() objects += 1; return {} end}
	local renderer = loadRenderTree(factory)
	local words = loadWordLayout({['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(text, _, size) measures += 1; return {X = #text * 5, Y = size} end}})
	local layout = loadBlockLayout({['Layout/WordLayout'] = words})
	local function build(html) return renderer.build(Parser.parse(html), {}, error, nil, nil, nil, function() return 'rbxassetid://1' end) end
	local function arrange(tree, width) layout.arrange(tree, width or 100, 0, 0, function() return true end) end
	for _, kind in {'outset', 'groove', 'ridge'} do
		local tree = build('<div style="border:6px ' .. kind .. ' hsla(210,50%,50%,.5);height:20px"></div>')
		arrange(tree)
		local box = tree.Children[1]
		assert(box.OuterWidth == 100 and box.OuterHeight == 32 and box.Style.BorderStyle == kind)
		local edges = box.InsetEdges
		if kind == 'outset' then
			assert(edges[1].BackgroundColor3.B > edges[3].BackgroundColor3.B and edges[1].BackgroundTransparency == .5)
		else
			local pool = edges.Pools[1]
			assert(#pool == 2 and pool[1].Size[2] + pool[2].Size[2] == 6 and pool[2].Position[2] == 3)
			assert((pool[1].BackgroundColor3.B > pool[2].BackgroundColor3.B) == (kind == 'ridge'))
			assert(pool[1].BackgroundTransparency == .5)
		end
		local before = objects
		arrange(tree, 70); arrange(tree, 100); assert(objects == before)
		assert(resolve('div', 'border:solid;border-right-style:' .. kind).BorderSides[2].Style == kind)
		local warnings = 0
		assert(resolve('div', 'outline:solid;outline:' .. kind, nil, function() warnings += 1 end).OutlineStyle == 'solid' and warnings == 1)
	end
	local insetTree = build('<div style="border:6px inset rgba(118,118,118,.5);height:20px"></div>')
	arrange(insetTree)
	local insetEdges = insetTree.Children[1].InsetEdges
	assert(insetEdges[4].BackgroundColor3.B > insetEdges[1].BackgroundColor3.B)
	assert(insetEdges[3].BackgroundColor3.B > insetEdges[2].BackgroundColor3.B)
	assert(insetEdges[1].BackgroundColor3.B < 118 / 255 and insetEdges[2].BackgroundColor3.B < 118 / 255)
	assert(insetEdges[4].BackgroundColor3.B > 118 / 255 and insetEdges[3].BackgroundColor3.B > 118 / 255)
	assert(insetEdges[4].BackgroundColor3.B < 1 and insetEdges[3].BackgroundColor3.B < 1)
	assert(insetEdges[4].BackgroundTransparency == .5)
	local imageTree = build('<img src="a" width="30" height="20" style="border:5px ridge black">')
	arrange(imageTree)
	local edge = imageTree.ImageItems[1].BorderEdges.Pools[1]
	assert(edge[1].Size[2] + edge[2].Size[2] == 5 and edge[1].BackgroundColor3.R > edge[2].BackgroundColor3.R)
	local lists = build('<dl><dt>Term</dt><dd>Text<dl><dt>Inner</dt><dd>Value</dd></dl></dd></dl>')
	arrange(lists, 300)
	local list = lists.Children[1]
	assert(list.Children[1].Marker == nil and list.Children[2].Gui.Position[1] == 40)
	assert(list.Children[2].Children[2].Style.Margin[1] == 0)
	local fig = build('<figure><div>A</div><figcaption>B</figcaption></figure>')
	arrange(fig, 200)
	assert(fig.Children[1].Gui.Position[1] == 40 and fig.Children[1].OuterWidth == 120)
	local wrap = build('<div style="word-wrap:break-word;line-height:20px">ABCDEFGHIJ</div>')
	arrange(wrap, 20)
	local run = wrap.Children[1].Children[1]
	assert(#run.DisplayItems == 3 and wrap.Children[1].OuterHeight == 60)
	local before = measures; arrange(wrap, 100); arrange(wrap, 20); assert(measures == before)
	print('Small additions: HSL colors, word-wrap alias, relief borders, semantic blocks, defaults, omitted tags, images and resize reuse passed')
end
