--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local warnings = 0
	local base = {Font = 'Roboto', FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function style(css, parent)
		return Style.resolve(fixtureElement('span',{style = css}), parent or base, function() warnings += 1 end, true)
	end
	assert(style('').OverflowWrap == 'normal')
	assert(style('', style('overflow-wrap: break-word')).OverflowWrap == 'break-word')
	assert(style('overflow-wrap: normal', style('overflow-wrap: break-word')).OverflowWrap == 'normal')
	assert(style('overflow-wrap: break-word !important; overflow-wrap: normal').OverflowWrap == 'break-word')
	assert(style('overflow-wrap: break-word; overflow-wrap: bad').OverflowWrap == 'break-word' and warnings == 1)
	local allocated, measured, cancel = 0, 0, false
	local onMeasure
	local function create(_, parent, props)
		allocated += 1
		local gui = table.clone(props)
		gui.Parent = parent
		if gui.Visible == nil then gui.Visible = true end
		function gui:Destroy() self.Destroyed = true end
		return gui
	end
	local renderer = loadRenderTree({create = create, modifier = create})
	local overrides = {['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(text, _, size)
			measured += 1
			if onMeasure then onMeasure() end
			local count = 0
			for _ in utf8.graphemes(text) do count += 1 end
			return {X = count * 5, Y = size}
		end}}
	local layout = loadWordLayout(overrides)
	overrides['Layout/WordLayout'] = layout
	local block = loadBlockLayout(overrides)
	local function build(text, extra)
		local tree = renderer.build(Parser.parse('<div style="font-family:Roboto; font-size:20px; line-height:20px; overflow-wrap:break-word;' .. (extra or '') .. '">' .. text .. '</div><div>End</div>'), {}, error)
		return tree, tree.Children[1].Children[1]
	end
	local function arrange(run, width) return layout.arrange(run, width, 0, 0, function() return not cancel end) end
	local tree, run = build('ABCDEFGHIJ')
	assert(arrange(run, 20) == 60)
	assert(#run.Items == 1 and run.Items[1].Text == 'ABCDEFGHIJ' and run.Items[1].Width == 50)
	assert(#run.DisplayItems == 3)
	for index, text in {'ABCD', 'EFGH', 'IJ'} do
		local item = run.DisplayItems[index]
		assert(item.Text == text and item.X == 0 and item.LineIndex == index and item.Gui.Visible)
	end
	assert(not run.Items[1].Gui.Visible)
	local created, calls = allocated, measured
	arrange(run, 20)
	assert(allocated == created and measured == calls, 'Same width reuses fragments and substring measurements')
	arrange(run, 100)
	assert(#run.DisplayItems == 1 and run.Items[1].Gui.Visible)
	for _, part in run.Items[1].WrapPool do assert(not part.Gui.Visible) end
	arrange(run, 20)
	assert(allocated == created and measured == calls, 'Wide then narrow restores existing fragments')
	block.arrange(tree, 20, 0, 0, function() return true end)
	assert(tree.Children[2].Gui.Position[2] == 60, 'Following blocks move below all emergency lines')
	local _, normal = build('AA BBBB')
	arrange(normal, 25)
	assert(#normal.DisplayItems == 2 and normal.DisplayItems[2] == normal.Items[2] and normal.Items[2].LineIndex == 2)
	assert(not normal.Items[2].WrapPool, 'A word that fits the next line stays whole')
	local _, after = build('AA ABCDEFGHIJ')
	arrange(after, 20)
	assert(after.DisplayItems[2].Text == 'ABCD' and after.DisplayItems[2].LineIndex == 2)
	local _, joined = build('AB<span style="color:red">CDEFGH</span>IJ')
	arrange(joined, 20)
	local texts = {}
	for _, part in joined.DisplayItems do table.insert(texts, part.Text); assert(part.X + part.Width <= 20) end
	assert(table.concat(texts) == 'ABCDEFGHIJ', 'Styled fragments stay one word without lost characters')
	for _, mode in {'nowrap', 'pre'} do
		local _, unbroken = build('ABCDEFGHIJ', 'white-space:' .. mode)
		assert(arrange(unbroken, 20) == 20 and not unbroken.DisplayItems and unbroken.Items[1].Width == 50)
	end
	for _, mode in {'pre-wrap', 'pre-line', 'break-spaces'} do
		local _, wrapped = build('ABCDEFGHIJ', 'white-space:' .. mode)
		assert(arrange(wrapped, 20) == 60)
	end
	local _, aligned = build('ABCDE', 'text-align:right')
	arrange(aligned, 20)
	assert(aligned.DisplayItems[2].Text == 'E' and aligned.DisplayItems[2].X == 15)
	local _, indented = build('ABCDE', 'text-indent:5px')
	arrange(indented, 20)
	assert(indented.DisplayItems[1].Text == 'ABC' and indented.DisplayItems[1].X == 5)
	local _, tiny = build('AB')
	assert(arrange(tiny, 0) == 40 and #tiny.DisplayItems == 2, 'One oversized grapheme must make progress')
	for _, text in {'Äp', '👩‍💻p'} do
		local _, unicode = build(text)
		arrange(unicode, 5)
		assert(#unicode.DisplayItems == 2 and unicode.DisplayItems[2].Text == 'p')
		assert(unicode.DisplayItems[1].Text == text:sub(1, -2), 'Do not split a grapheme')
	end
	local _, painted = build('<span style="background:red; text-decoration:underline; text-shadow:1px 1px">ABCDEFGHIJ</span>')
	arrange(painted, 20)
	for _, part in painted.DisplayItems do
		assert(part.DecorationFrames[1].Visible)
		assert(part.ShadowLabels[1].Gui.Visible and part.ShadowLabels[1].Gui.Text == part.Text)
	end
	assert(#painted.FragmentPool==#painted.DisplayItems,'A wrapping decorated inline retains one painted fragment per line')
	for _,fragment in painted.FragmentPool do
		assert(fragment.Gui.Visible and fragment.Gui.BackgroundTransparency==0 and fragment.Gui.BackgroundColor3==Color3.new(1,0,0))
	end
	local _, spaced = build('ABCDE', 'letter-spacing:2px')
	arrange(spaced, 20)
	assert(spaced.DisplayItems[1].Text == 'ABC' and spaced.DisplayItems[1].Width == 19)
	assert(#spaced.DisplayItems[1].Glyphs == 3 and spaced.DisplayItems[1].Glyphs[2].X == 7)
	arrange(spaced, 12); arrange(spaced, 20)
	local _, hidden = build('ABCDE', 'visibility:hidden')
	arrange(hidden, 20)
	for _, part in hidden.DisplayItems do assert(part.Gui.TextTransparency == 1) end
	local _, cancelled = build('ABCDEFGHIJ')
	arrange(cancelled, 200)
	local beforeCancel = allocated
	onMeasure = function() cancel = true end
	assert(arrange(cancelled, 20) == 0 and allocated == beforeCancel, 'Disposal during substring measurement must not create fragment GUIs')
	onMeasure = nil
	cancel = true
	assert(arrange(run, 10) == 0)
	print('Overflow wrap: inheritance, normal-word preservation, fragment reuse, resize, block flow, inline styles, whitespace, alignment, Unicode, paint and glyph spacing passed')
end
