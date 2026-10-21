--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local parent = {Font = "Arial", FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function resolve(value, inherited, warn)
		return Style.resolve(fixtureElement('div',{style = 'aspect-ratio: ' .. value}), inherited or parent, warn or error)
	end
	for value, ratio in {['16 / 9'] = 16 / 9, ['4/3'] = 4 / 3, ['1.5'] = 1.5, ['+2 / .5'] = 4} do
		assert(resolve(value).AspectRatio.Value == ratio)
	end
	for _, value in {'auto 16 / 9', '16 / 9 auto'} do
		local ratio = resolve(value).AspectRatio
		assert(ratio.Auto and ratio.Value == 16 / 9)
	end
	for _, value in {'auto', '0', '0 / 1', '1 / 0', 'auto 0 / 0'} do assert(resolve(value).AspectRatio == nil) end
	for _, value in {'-1', '1 / -2', '2px', '50%', '1 /', '/ 1', '1 / 2 / 3', 'auto auto', 'auto 1 auto', '1 2', '1e2', '100001', '0.000001', '1 / 0.000001'} do
		local warnings = 0
		local style = resolve('2; aspect-ratio: ' .. value, nil, function() warnings += 1 end)
		assert(warnings == 1 and style.AspectRatio.Value == 2, value)
	end
	assert(resolve('2; aspect-ratio: auto').AspectRatio == nil)
	assert(Style.resolve(fixtureElement('div',{}), resolve('2'), error).AspectRatio == nil, 'No inheritance')
	local warnings = 0
	Style.resolve(fixtureElement('span',{style = 'aspect-ratio: 2'}), parent, function() warnings += 1 end, true)
	assert(warnings == 1, 'Inline text has no independently sized aspect-ratio box')
	local allocated, measurements = 0, 0
	local renderer = loadRenderTree({create = function(_, _, props) allocated += 1; return table.clone(props) end})
	local words = loadWordLayout({['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(_, _, size) measurements += 1; return {X = 20, Y = size} end}})
	local blocks = loadBlockLayout({['Layout/WordLayout'] = words})
	local function build(html)
		return renderer.build(Parser.parse(html), {}, error, nil, nil, nil, function() return 'rbxassetid://123' end)
	end
	local function near(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. ' ~= ' .. tostring(b)) end
	local function arrange(tree, width) blocks.arrange(tree, width or 400, 0, 0, function() return true end) end
	local function block(css, expectedW, expectedH, content)
		local tree = build('<div style="' .. css .. '">' .. (content or '') .. '</div><div>Following</div>')
		arrange(tree)
		local box = tree.Children[1]
		near(box.Gui.Size[1], expectedW); near(box.Gui.Size[2], expectedH)
		near(tree.Children[2].Gui.Position[2], expectedH)
		return tree, box
	end
	block('width: 240px; aspect-ratio: 16 / 9', 240, 135)
	block('height: 90px; aspect-ratio: 16 / 9', 160, 90)
	block('width: 240px; height: 80px; aspect-ratio: 1', 240, 80)
	block('aspect-ratio: 2', 400, 200)
	block('aspect-ratio: auto 2', 400, 200)
	block('aspect-ratio: 0', 400, 0)
	block('width: 240px; max-width: 160px; aspect-ratio: 2', 160, 80)
	block('height: 90px; max-height: 50px; aspect-ratio: 2', 100, 50)
	block('width: 240px; aspect-ratio: 2; max-height: 70px', 240, 70)
	block('aspect-ratio: 2; max-height: 70px', 140, 70)
	block('aspect-ratio: 2; min-height: 300px', 600, 300)
	block('aspect-ratio: 2; min-width: 200px; max-height: 70px', 200, 70)
	block('width: 100px; aspect-ratio: 2; padding: 10px; border: 2px solid red', 124, 74)
	block('width: 100px; aspect-ratio: 2; padding: 10px; border: 2px solid red; box-sizing: border-box', 100, 50)
	block('height: 50px; aspect-ratio: 2; padding: 10px; border: 2px solid red; box-sizing: border-box', 100, 50)
	block('width: 0; aspect-ratio: 1; padding: 10px; box-sizing: border-box', 20, 20)
	block('width: 100px; aspect-ratio: 2; line-height: 20px', 100, 80, 'A<br>B<br>C<br>D')
	block('width: 100px; aspect-ratio: 2; line-height: 20px; min-height: 0', 100, 50, 'A<br>B<br>C<br>D')
	block('width: 100px; aspect-ratio: 2; line-height: 20px; overflow: hidden', 100, 50, 'A<br>B<br>C<br>D')
	local tree, box = block('width: 50%; aspect-ratio: 2', 200, 100, 'Text')
	local count, measured = allocated, measurements
	arrange(tree, 200)
	near(box.Gui.Size[1], 100); near(box.Gui.Size[2], 50)
	assert(allocated == count and measurements == measured, 'Responsive ratio reuses objects and text measurements')
	local quote = build('<blockquote style="margin: 0; width: 100px; aspect-ratio: 1"><div style="height: 10px; margin-bottom: 20px"></div></blockquote>')
	arrange(quote)
	assert(not quote.Children[1].CollapseBottom, 'A ratio-derived height prevents parent/child bottom-margin collapse')
	local function image(css, attributes, expectedW, expectedH, naturalW, naturalH)
		local result = build('<p><img src="x" ' .. (attributes or '') .. ' style="' .. css .. '"></p>')
		local item = result.ImageItems[1]
		item.IntrinsicWidth, item.IntrinsicHeight = naturalW, naturalH
		arrange(result)
		near(item.BoxWidth, expectedW); near(item.BoxHeight, expectedH)
		return result, item
	end
	image('width: 240px; aspect-ratio: 16 / 9', '', 240, 135, 640, 320)
	image('height: 90px; aspect-ratio: 16 / 9', '', 160, 90, 640, 320)
	image('aspect-ratio: 1', 'width="100" height="70"', 100, 70, 640, 320)
	image('height: auto; aspect-ratio: 1', 'width="100" height="70"', 100, 100, 640, 320)
	image('width: 120px; aspect-ratio: auto 1', '', 120, 60, 640, 320)
	image('width: 120px; aspect-ratio: auto 1', '', 120, 120)
	image('width: 120px; height: auto; aspect-ratio: auto 1', 'width="100" height="70"', 120, 120)
	image('width: 120px; aspect-ratio: 1; aspect-ratio: auto', '', 120, 60, 640, 320)
	image('aspect-ratio: 1; max-width: 100px', '', 100, 100, 640, 320)
	image('width: 200px; max-width: 100px; aspect-ratio: 2', '', 100, 50, 640, 320)
	image('width: 100px; aspect-ratio: 2; min-height: 70px', '', 100, 70, 640, 320)
	image('width: 100px; aspect-ratio: 2; padding: 10px; border: 2px solid red', '', 124, 74, 640, 320)
	image('width: 100px; aspect-ratio: 2; padding: 10px; border: 2px solid red; box-sizing: border-box', '', 100, 50, 640, 320)
	image('width: 100px; aspect-ratio: auto 1; padding: 10px; border: 2px solid red; box-sizing: border-box', '', 100, 62, 640, 320)
	local fitted, item = image('width: 240px; aspect-ratio: 16 / 9; object-fit: none', '', 240, 135, 640, 320)
	assert(item.ImageGui.Size[1] == 640 and item.ImageGui.Size[2] == 320, 'Box aspect-ratio never overwrites natural content dimensions')
	item.TextFallback, item.Alt = true, 'Missing'
	arrange(fitted)
	near(item.ContentWidth,36)
	assert(item.BoxHeight < 135, 'Confirmed broken-image alt ignores preferred ratio')
	print('Aspect ratio: syntax/cascade, auto/natural precedence, both axes, constraints, box sizing, content growth, image fitting and reflow passed')
end
