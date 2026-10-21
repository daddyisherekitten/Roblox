--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout, ImageBox, SkipInk)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, parent, warn)
		return Style.resolve(fixtureElement('span',{style = css}), parent or {}, warn or error, true)
	end
	assert(resolve('').Visibility == 'visible')
	local hidden = resolve('visibility: HIDDEN')
	assert(not hidden.Hidden and resolve('', hidden).Visibility == 'hidden')
	assert(resolve('visibility: visible', hidden).Visibility == 'visible')
	assert(resolve('visibility:collapse').VisibilityCollapse)
	for _, value in {'hidden visible', 'none'} do
		local warnings = 0
		assert(resolve('visibility: hidden; visibility: ' .. value, nil, function() warnings += 1 end).Visibility == 'hidden')
		assert(warnings == 1)
	end
	local created, measurements = {}, 0
	local function create(class, owner, props)
		local gui = table.clone(props)
		gui.ClassName, gui.Parent = class, owner
		if gui.Visible == nil then gui.Visible = true end
		table.insert(created, gui)
		return gui
	end
	local renderer = loadRenderTree({create = create, modifier = create})
	local overrides = {
		['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(text, _, size)
			measurements += 1; return {X = #text * 5, Y = size}
		end},
	}
	local layout = loadWordLayout(overrides)
	overrides['Layout/WordLayout'] = layout
	local block = loadBlockLayout(overrides)
	local function build(html)
		return renderer.build(Parser.parse(html), {}, function(message)
			assert(message == 'No image mapping for src: missing', message)
		end, nil, nil, nil, function(src) return if src == 'missing' then nil else 'rbxassetid://123' end)
	end
	local function arrange(tree, width) return block.arrange(tree, width or 200, 0, 0, function() return true end) end
	local function run(html) return build('<p>' .. html .. '</p>').Children[1].Children[1] end
	local function arrangeRun(value, width) return layout.arrange(value, width or 200, 0, 0, function() return true end) end
	local fragments = run('A<span style="visibility: hidden">B<span style="visibility: visible">C</span>D</span>E')
	assert(#fragments.Items == 5, 'Visibility boundaries must not merge')
	arrangeRun(fragments)
	for i, alpha in {0, 1, 0, 1, 0} do
		local item = fragments.Items[i]
		assert(item.Gui.Visible and item.Gui.TextTransparency == alpha)
		assert(item.X == (i - 1) * 5 and item.Width == 5)
	end
	local spaced = run('<span style="visibility: hidden; letter-spacing: 2px; text-shadow: 1px 1px">AB<span style="visibility: visible">CD</span></span>')
	arrangeRun(spaced)
	assert(spaced.Items[1].Glyphs[1].Gui.TextTransparency == 1 and not spaced.Items[1].ShadowLabels)
	assert(spaced.Items[2].Glyphs[1].Gui.TextTransparency == 0 and #spaced.Items[2].ShadowLabels > 0)
	local template = '<div style="visibility: %s; padding: 3px; border: 2px solid; background: red; box-shadow: 1px 1px, inset 1px 1px">AA BB<br>CC<div style="visibility: visible; background: blue">DD</div></div><div>End</div>'
	local hiddenTree, visibleTree = build(string.format(template, 'hidden')), build(string.format(template, 'visible'))
	for _, width in {200, 35} do
		assert(arrange(hiddenTree, width) == arrange(visibleTree, width))
		assert(hiddenTree.Children[2].Gui.Position[2] == visibleTree.Children[2].Gui.Position[2])
		assert(hiddenTree.Children[1].Gui.Size[2] == visibleTree.Children[1].Gui.Size[2])
	end
	local box = hiddenTree.Children[1]
	assert(box.Gui.Visible and box.Gui.BackgroundTransparency == 1 and box.InsetRenderer == nil)
	assert(box.Children[2].Gui.BackgroundTransparency == 0 and box.Children[2].Children[1].Items[1].Gui.TextTransparency == 0)
	for _, gui in created do
		if gui.Parent == box.Gui and (gui.ClassName == 'UIStroke' or gui.ClassName == 'UIShadow') then
			assert(gui.Enabled == false or gui.Transparency == 1, 'Retained borders/shadows must add no paint to a hidden box')
		end
	end
	local cascade = build('<style>p {visibility: hidden !important}</style><p style="visibility: visible">A<span style="visibility: visible">B</span></p><div style="display:none"><span style="visibility:visible">C</span></div>')
	arrange(cascade)
	assert(#cascade.Children == 2 and #cascade.FlowChildren == 1 and cascade.Children[1].Style.Visibility == 'hidden')
	assert(cascade.Children[2].Style.Hidden and not cascade.Children[2].Gui.Visible, 'display:none must suppress even explicitly visible descendants while preserving later state changes')
	assert(cascade.Children[1].Children[1].Items[2].Style.Visibility == 'visible')
	local incompleteDiagnostics={}
	local incomplete=renderer.build(Parser.parse('<div style="opacity:.5"><div style="display:table;border-collapse:collapse"><div style="display:table-cell">A</div><div style="display:table-cell">B</div></div><p>Visible text after the unsupported table structure</p></div>'),{},function(message)
		table.insert(incompleteDiagnostics,message)
	end)
	local incompleteGroup=incomplete.Children[1]
	for _,width in {200,100,200} do
		local height=arrange(incomplete,width)
		assert(height>0 and height<1000 and incompleteGroup.OpacityGroup.Gui.Size[1]>0,'Anonymous table descendants must participate in page-wide opacity composition')
		local tableBox=incompleteGroup.Children[1]
		assert(tableBox.TableRows[1].Box.AnonymousTable,'Direct table cells now receive an anonymous row')
		assert(tableBox.TableRows[1].Box.Children[1].Children[1].Items[1].X~=nil,'Anonymous table-cell text must have arranged geometry')
		local visibleRun=incompleteGroup.Children[2].Children[1]
		assert(visibleRun.Items[1].X~=nil and visibleRun.Items[1].Width>0,'Laid-out following text remains part of the opacity group')
	end
	assert(#incompleteDiagnostics==0,'Supported anonymous table structure must not be diagnosed as unsupported')
	local lists = build('<ol><li style="visibility:hidden">A<span style="visibility:visible">B</span></li><li>C</li></ol>')
	arrange(lists)
	assert(not lists.Children[1].Children[1].Marker.Gui.Visible and lists.Children[1].Children[2].Marker.Number == 2)
	assert(lists.Children[1].Children[1].Children[1].Items[2].Gui.TextTransparency == 0)
	-- Parent paint still covers a hidden descendant; that descendant adds no ink gaps.
	local ancestor = run('<span style="background:red; text-decoration:underline">A<span style="visibility:hidden">p</span>B</span>')
	arrangeRun(ancestor)
	local p = ancestor.Items[2]
	assert(p.Gui.TextTransparency==1 and ancestor.FragmentPool[1].Gui.Visible
		and ancestor.FragmentPool[1].Gui.BackgroundTransparency==0,'The visible ancestor fragment still paints beneath its hidden descendant')
	assert(p.DecorationFrames[1].Visible and not SkipInk.intersects(p, p.Style.Decorations[1]))
	local own = run('<span style="visibility:hidden; background:red; text-decoration:underline">A<span style="visibility:visible">B</span></span>')
	arrangeRun(own)
	for _, item in own.Items do assert(not item.Style.InlineBackground and #item.Style.Decorations == 0) end
	local gap = run('<span style="background:red">A </span><span style="visibility:hidden">B</span>')
	arrangeRun(gap)
	local gapFragment=gap.FragmentPool[1]
	assert(gap.Items[2].Gui.Visible and gapFragment.Gui.Visible and gapFragment.Gui.BackgroundTransparency==0
		and gapFragment.Width==gap.Items[2].X-gap.Items[1].X,'The visible inline fragment includes its trailing source space before the hidden sibling')
	local images = run('A<img src="ok" alt="Alt" width="40" height="30" style="visibility:hidden">B<img src="missing" style="visibility:hidden">C')
	arrangeRun(images)
	local image, missing = images.Items[2], images.Items[4]
	assert(image.Width == 40 and image.Height == 30 and image.Gui.Visible and not image.BoxGui.Visible)
	assert(images.Items[3].X == image.X + 40)
	assert(not missing.BoxGui.Visible and not missing.ErrorGui.Visible and not missing.FallbackGui.Visible)
	for _, loaded in {false, true} do
		image.ImageGui.IsLoaded, image.LoadFailed = loaded, true
		image.ImageGui.Visible = true -- ImageLoad can complete after the first layout.
		ImageBox.updateFallback(image)
		arrangeRun(images)
		assert(not image.BoxGui.Visible and not image.AltGui.Visible and not image.ErrorGui.Visible)
	end
	local count, measured = #created, measurements
	arrangeRun(images, 100); arrangeRun(images, 200)
	assert(#created == count and measurements == measured, 'Visibility must preserve resize reuse')
	print('Visibility: inheritance, explicit visible children, layout/wrap, markers, glyphs, paint origins, images, late loading and reuse passed')
end
