--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, parent, warn)
		return Style.resolve(fixtureElement('div',{style = css}), parent or {Font = 'Roboto', FontSize = 20, Color = Color3.new(0, 0, 0)}, warn or error)
	end
	assert(resolve('').TextOverflow == 'clip')
	assert(resolve('', resolve('text-overflow:ellipsis')).TextOverflow == 'clip')
	assert(resolve('text-overflow:ellipsis!important;text-overflow:clip').TextOverflow == 'ellipsis')
	for _, bad in {'fade', 'ellipsis clip', '"..."'} do
		local warnings = 0
		assert(resolve('text-overflow:ellipsis;text-overflow:' .. bad, nil, function() warnings += 1 end).TextOverflow == 'ellipsis' and warnings == 1)
	end
	local allocated, measured, cancel, onMeasure = 0, 0, false, nil
	local function create(_, parent, props)
		allocated += 1
		local gui = table.clone(props); gui.Parent = parent
		function gui:Destroy() self.Destroyed = true end
		return gui
	end
	local renderer = loadRenderTree({create = create, modifier = create})
	local layout = loadWordLayout({['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(text, _, size)
			measured += 1
			if onMeasure then onMeasure(text) end
			local count = 0
			for _ in utf8.graphemes(text) do count += 1 end
			return {X = count * 5, Y = size}
		end}})
	local block = loadBlockLayout({['Layout/WordLayout'] = layout})
	local function build(text, extra)
		local tree = renderer.build(Parser.parse('<div style="font-family:Roboto;font-size:20px;line-height:20px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;' .. (extra or '') .. '">' .. text .. '</div><div>End</div>'), {}, error, nil, nil, nil, function() return 'rbxassetid://1' end)
		return tree, tree.Children[1].Children[1]
	end
	local function arrange(run, width) return layout.arrange(run, width, 0, 0, function() return not cancel end) end
	local function text(run)
		local result = {}
		for _, item in run.DisplayItems or run.Items do table.insert(result, item.Text or '') end
		return table.concat(result)
	end
	local tree, run = build('AA BBBBBBB CC')
	local height, far = arrange(run, 30)
	assert(height == 20 and far > 30 and text(run) == 'AABB…')
	assert(run.Items[2].Text == 'BBBBBBB' and run.Items[2].Width == 35 and not run.Items[2].Gui.Visible and not run.Items[3].Gui.Visible)
	local marker, part = run.EllipsisPool[1], run.Items[2].WrapPool[1]
	assert(marker.X == 25 and marker.Gui.Visible and part.Gui.Visible)
	local objects, calls = allocated, measured
	arrange(run, 30)
	assert(allocated == objects and measured == calls)
	arrange(run, 200)
	assert(not marker.Gui.Visible and run.Items[2].Gui.Visible and run.Items[3].Gui.Visible and not part.Gui.Visible)
	arrange(run, 30)
	assert(allocated == objects and measured == calls and marker.Gui.Visible and part.Gui.Visible)
	block.arrange(tree, 30, 0, 0, function() return true end)
	assert(tree.Children[2].Gui.Position[2] == 20 and tree.LocalRight == 30)
	local _, fitting = build('ABC')
	arrange(fitting, 15)
	assert(fitting.EllipsisPool == nil and text(fitting) == 'ABC')
	for _, extra in {'text-overflow:clip', 'overflow:visible'} do
		local _, clipped = build('ABCDEFG', extra)
		arrange(clipped, 15)
		assert(clipped.EllipsisPool == nil and clipped.Items[1].Text == 'ABCDEFG')
	end
	local _, tiny = build('ABC')
	arrange(tiny, 2)
	assert(text(tiny) == 'A…' and tiny.EllipsisPool[1].X == 5, 'First grapheme remains to be clipped by the container')
	for _, value in {'Äp', '👩‍💻p'} do
		local _, unicode = build(value)
		arrange(unicode, 6)
		assert(unicode.DisplayItems[1].Text == value:sub(1, -2))
	end
	local _, mixed = build('<span style="font-size:30px;background:red;text-decoration:underline;text-shadow:1px 1px">ABCDEFG</span>')
	arrange(mixed, 20)
	local head = mixed.DisplayItems[1]
	assert(head.Text == 'ABC' and head.ShadowLabels[1].Gui.Text == 'ABC' and head.DecorationFrames[1].Size[1] == 15)
	assert(mixed.FragmentPool[1].Gui.BackgroundTransparency == 0 and mixed.FragmentPool[1].Width==mixed.Items[1].Width
		and mixed.EllipsisPool[1].TextSize ~= head.TextSize,'Ellipsis preserves the original background box behind the overflow clip and uses the containing text style')
	assert(mixed.EllipsisPool[1].Y + mixed.EllipsisPool[1].Baseline == head.LineBaseline)
	local _, glyphs = build('ABCDE', 'letter-spacing:2px;text-shadow:1px 1px')
	arrange(glyphs, 20)
	assert(glyphs.DisplayItems[1].Text == 'AB' and #glyphs.DisplayItems[1].Glyphs == 2 and text(glyphs) == 'AB…')
	arrange(glyphs, 100); arrange(glyphs, 20)
	assert(text(glyphs) == 'AB…')
	local _, lines = build('<br>ABCDE<br><br>FGHIJ')
	arrange(lines, 15)
	assert(lines.EllipsisPool[2].Gui.Visible and lines.EllipsisPool[4].Gui.Visible)
	local _, right = build('ABCDE', 'text-align:right')
	arrange(right, 15)
	assert(right.EllipsisPool and text(right)=='AB…','An oversized right-aligned LTR word uses the CSS Text start fallback and overflows the end')
	local _, leftOnly=build('ABC','text-indent:-10px')
	arrange(leftOnly,15)
	assert(leftOnly.EllipsisPool==nil,'Left overflow alone does not trigger an LTR end ellipsis')
	local _, image = build('<img src="a" width="20" height="10"> ABCDEF')
	arrange(image, 10)
	assert(image.DisplayItems[1].Kind == 'Image' and image.EllipsisPool[1].X == 20)
	local _, wrap = build('ABCDEFG', 'white-space:normal;overflow-wrap:break-word')
	arrange(wrap, 15)
	assert(wrap.EllipsisPool == nil and #wrap.DisplayItems == 3)
	local _, disposed = build('ABCDE')
	onMeasure = function(value) if value == '…' then cancel = true end end
	assert(arrange(disposed, 15) == 0 and disposed.EllipsisPool == nil)
	print('Text overflow: cascade, grapheme truncation, mixed styles/paint, resize reuse, layout invariance, lines, images and cancellation passed')
end
