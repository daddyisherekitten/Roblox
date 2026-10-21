--!strict
return function(Style, Parser, loadRenderTree, loadWordLayout, Pixels, Insets)
 local fixtureElement=require('DOM/Node').element
	local parent = {Font = 'Arial', FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function resolve(css, inherited, name, warn)
		return Style.resolve(fixtureElement(name or 'div',{style = css}), inherited or parent, warn or error, name == 'span')
	end
	local function near(a, b) assert(math.abs(a - b) < .00001, tostring(a) .. ' ~= ' .. tostring(b)) end
	for value, expected in {['rgb(255, 0, 0)'] = 1, ['rgba(100%, 0%, 0%, 25%)'] = .25, ['#f004'] = 68 / 255,
		['#ff000080'] = 128 / 255, ['rgba(300, -10, 0, 2)'] = 1, ['rgba(255, 0, 0, -1)'] = 0,
		['rgb(255 0 0)']=1, ['rgba(100% 0% 0% / 25%)']=.25,
		['rgb(100% 0 0%/.65)']=.65, ['rgb(300 -10 0 / 2)']=1,
		['rgba(255 0 0 / -1)']=0, ['rgb(255 none none / none)']=0} do
		local style = resolve('color: ' .. value .. '; background: ' .. value .. '; border: 2px solid ' .. value .. '; text-decoration-color: ' .. value .. '; text-decoration: underline')
		assert(style.Color == Color3.new(1, 0, 0) and style.BorderColor == style.Color)
		near(style.ColorAlpha, expected); near(style.BackgroundAlpha, expected); near(style.BorderColorAlpha, expected)
		near(style.Decorations[1].Alpha, expected)
	end
	local modern=resolve('background:rgb(10 40 32 / .65);color:rgb(10 40 32 / 65%);border:2px solid rgb(10 40 32/.65);box-shadow:1px 2px rgb(10 40 32 / .65)')
	assert(modern.Background==Color3.fromRGB(10,40,32) and modern.Color==modern.Background and modern.BorderColor==modern.Background)
	near(modern.BackgroundAlpha,.65);near(modern.ColorAlpha,.65);near(modern.BorderColorAlpha,.65)
	assert(modern.BoxShadows[1].Color==modern.Background);near(modern.BoxShadows[1].Alpha,.65)
	local translucent = resolve('color: rgba(0, 0, 0, .25)')
	near(resolve('', translucent).ColorAlpha, .25)
	near(resolve('color: black', translucent).ColorAlpha, 1)
	near(resolve('color: currentcolor', translucent).ColorAlpha, .25)
	near(resolve('', translucent, 'mark').ColorAlpha, 1)
	local current = resolve('border: 2px solid; background: currentcolor; color: rgba(0, 0, 0, .25)')
	near(current.BorderColorAlpha, .25); near(current.BackgroundAlpha, .25)
	local reset = resolve('border-color: #f004; border: solid; color: blue')
	near(reset.BorderColorAlpha, 1)
	assert(resolve('color: transparent').ColorAlpha == 0)
	for _, value in {'rgb(0, 0)', 'rgba(0, 0, 0,)', 'rgb(0%, 0, 0)', 'rgba(0, 0, 0, nan)', '#ff00000', 'rgba(0,0,0,.5) red',
		'rgb(10 40)', 'rgb(10 40 32 .65)', 'rgb(10 40 32 /)', 'rgb(10 40 32 / .65 / .2)',
		'rgb(10,40,32 / .65)', 'rgb(10 40,32)', 'rgb(10 40 32 / nan)', 'rgb(none,0,0)'} do
		local warnings = 0
		local style = resolve('color: rgba(255,0,0,.5); color: ' .. value, nil, nil, function() warnings += 1 end)
		assert(warnings == 1 and style.ColorAlpha == .5 and style.Color == Color3.new(1, 0, 0), value)
	end
	local allocated, created = 0, {}
	local function create(class, owner, props)
		local gui = table.clone(props); gui.ClassName, gui.Parent = class, owner
		allocated += 1; table.insert(created, gui); return gui
	end
	local renderer = loadRenderTree({create = create, modifier = create})
	local measurements = 0
	local layout = loadWordLayout({['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(text, _, size) measurements += 1; return {X = if text == ' ' then 5 else 20, Y = size} end}})
	local function build(html, patterns)
		return renderer.build(Parser.parse(html), {}, error, nil, patterns, nil, function() return 'rbxassetid://123' end)
	end
	local function arrange(run) layout.arrange(run, 400, 0, 0, function() return true end) end
	local tree = build('<div style="color: rgba(0,0,0,.25); background: rgba(0,0,255,.2); border: 2px solid rgba(255,0,0,.4); box-shadow: 1px 1px">A<span style="color: rgba(0,0,0,.5)">B</span><span style="color: black">C</span></div>')
	local box, run = tree.Children[1], tree.Children[1].Children[1]
	near(box.Gui.BackgroundTransparency, .8)
	assert(#run.Items == 3, 'Equal RGB with different alpha must retain separate fragments')
	for i, transparency in {.75, .5, 0} do near(run.Items[i].Gui.TextTransparency, transparency) end
	for _, gui in created do
		if gui.Parent == box.Gui and gui.ClassName == 'UIStroke' then near(gui.Transparency, .6) end
		if gui.Parent == box.Gui and gui.ClassName == 'UIShadow' then near(gui.Transparency, .75) end
	end
	arrange(run); local count, measured = allocated, measurements
	arrange(run); assert(allocated == count and measurements == measured)
	local bgTree = build('<p><span style="background: rgba(255,0,0,.5)">A B<span style="background: rgba(0,0,255,.5)">C</span></span></p>')
	local bg = bgTree.Children[1].Children[1]
	arrange(bg)
	local fragment=bg.FragmentPool[1]
	near(fragment.Gui.BackgroundTransparency,.5)
	assert(fragment.Gui.BackgroundColor3==Color3.new(1,0,0) and fragment.Gui.ZIndex<(bg.Items[3].Gui.ZIndex or 1),
		'The ancestor background spans the inline fragment below descendant paint')
	near(bg.Items[3].Gui.BackgroundTransparency,.5)
	assert(bg.Items[3].Gui.BackgroundColor3==Color3.new(0,0,1),'The nested background retains its own alpha over the ancestor fragment')
	near(bg.Items[3].Gui.TextTransparency, 0)
	local glyphTree = build('<p style="color: rgba(0,0,0,.3); letter-spacing: 2px; text-shadow: 1px 1px, 2px 2px rgba(0,0,0,.6)">AB</p>')
	local glyphRun = glyphTree.Children[1].Children[1]; arrange(glyphRun)
	local item = glyphRun.Items[1]
	near(item.Glyphs[1].Gui.TextTransparency, .7)
	near(item.ShadowLabels[1].Gui.TextTransparency, .7); near(item.ShadowLabels[3].Gui.TextTransparency, .4)
	local patterned = build('<p style="color: rgba(0,0,0,.4); text-decoration: underline; text-decoration-style: dashed">A</p>', {Get = function() return {Width = 4, Height = 1, Content = 'pattern'} end})
	local lines = patterned.Children[1].Children[1]; arrange(lines)
	near(lines.Items[1].DecorationImages[1].ImageTransparency, .6)
	local solid = build('<p style="text-decoration: underline; text-decoration-color: rgba(0,0,0,.2)">A</p>')
	local solidRun = solid.Children[1].Children[1]; arrange(solidRun)
	near(solidRun.Items[1].DecorationFrames[1].BackgroundTransparency, .8)
	local imageTree = build('<p style="color: rgba(0,0,0,.25)"><img src="x" alt="Alt" width="40" height="30" style="background: rgba(0,0,255,.2); border: 2px solid rgba(255,0,0,.4)"></p>')
	local img = imageTree.ImageItems[1]
	near(img.AltGui.TextTransparency, .75); near(img.BoxGui.BackgroundTransparency, .8)
	assert(img.ImageGui.ImageTransparency == nil, 'Background alpha must not fade the image')
	local lists = build('<ul style="color: rgba(0,0,0,.25)"><li>A</li></ul><ol style="color: rgba(0,0,0,.25)"><li>B</li></ol>')
	near(lists.Children[1].Children[1].Marker.Gui.BackgroundTransparency, .75)
	near(lists.Children[2].Children[1].Marker.Gui.TextTransparency, .75)
	local insetStyle = resolve('color: rgba(0,0,0,.25); box-shadow: inset 0 0 0 10px')
	local plan = Pixels.plan(8, 8, insetStyle)
	local pixels = Pixels.render(8, 8, insetStyle, plan)
	assert(buffer.readu8(pixels, (4 * plan.Width + 4) * 4 + 3) == 64, 'Inset currentcolor includes text alpha')
	local writes = 0
	local inset = Insets.new(error, function() return {WritePixelsBuffer = function() writes += 1 end, Destroy = function() end} end)
	local insetBox = {Gui = {}, Style = insetStyle}
	inset:Draw(insetBox, 8, 8); inset:Draw(insetBox, 8, 8)
	assert(writes == 1)
	insetStyle.ColorAlpha = .5; inset:Draw(insetBox, 8, 8)
	assert(writes == 2, 'Inset cache invalidates when only currentcolor alpha changes')
	inset:Destroy()
	print('Colors: shared RGB/RGBA/hex parsing, alpha inheritance/cascade, fragments, nested backgrounds, borders, markers, decorations, shadows and reflow passed')
end
