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
			return {X = if text == " " then 5 else #text * 10, Y = size}
		end},
	}
	local wordLayout = loadWordLayout(overrides)
	overrides["Layout/WordLayout"] = wordLayout
	local blockLayout = loadBlockLayout(overrides)
	local function build(html)
		local doc = Parser.parse(html)
		local original = DOM.textContent(doc)
		local tree = renderer.build(doc, {}, function(message) error(message) end)
		assert(DOM.textContent(doc) == original)
		return tree
	end
	local function run(text, css)
		return build('<p style="font-size: 20px; line-height: 20px; ' .. (css or "") .. '">' .. text .. '</p>').Children[1].Children[1]
	end
	local function arrange(words, width) return wordLayout.arrange(words, width or 200, 0, 0, function() return true end) end
	local scripts = run('m<sup>2</sup> H<sub>2</sub>O')
	arrange(scripts)
	local m, sup, h, sub, o = table.unpack(scripts.Items)
	assert(#scripts.Items == 5 and math.abs(sup.Style.FontSize - 20 / 1.2) < 0.0001 and sub.Style.FontSize == sup.Style.FontSize)
	assert(sup.Style.LineHeight.Kind == "normal" and o.Style.FontSize == 20)
	assert(sup.X == m.X + m.Width and sub.X == h.X + h.Width and o.X == sub.X + sub.Width, "No additional horizontal spaces around sup/sub")
	assert(sup.Y + sup.Baseline == m.Y + m.Baseline - 7.65625)
	assert(sub.Y + sub.Baseline == h.Y + h.Baseline + 5)
	local count, allocated = requests, objects
	arrange(scripts, 30)
	assert(requests == count and objects == allocated and sup.LineIndex == m.LineIndex and sub.LineIndex == o.LineIndex)
	local wrap = run('AA m<sup>2</sup>')
	arrange(wrap, 40)
	assert(wrap.Items[2].LineIndex == 2 and wrap.Items[3].LineIndex == 2 and wrap.Items[2].X == 0)
	local nested = run('x<sup>2<sub>n</sub></sup>')
	arrange(nested)
	assert(nested.Items[3].BaselineShift == -3.328125)
	local explicit = run('A<sup style="font-size: 20px; vertical-align: baseline; line-height: 20px">B</sup>C')
	arrange(explicit)
	assert(#explicit.Items == 1 and explicit.Items[1].Text == "ABC", "Matching explicit styles can still merge into one label")
	local marked = run('vor<mark>her</mark> <mark>AA BB </mark>CC')
	arrange(marked)
	assert(#marked.Items == 5 and marked.Items[2].X == marked.Items[1].Width)
	local yellow = Color3.fromRGB(255, 255, 0)
	assert(marked.FragmentPool[1].Gui.BackgroundColor3 == yellow and marked.FragmentPool[1].Gui.BackgroundTransparency == 0)
	assert(marked.Items[2].Gui.TextColor3 == Color3.new(0, 0, 0))
	assert(marked.FragmentPool[2].Width==marked.Items[5].X-marked.Items[3].X,'The whole highlighted fragment includes internal and trailing source spaces')
	assert(marked.Items[5].Style.InlineBackground == nil, "A trailing marked space must not highlight the following word")
	local fragment = marked.FragmentPool[2].Gui
	count = requests
	arrange(marked, 20)
	assert(marked.Items[4].LineIndex~=marked.Items[5].LineIndex and requests == count,'Wrapping discards the highlighted trailing space at the line boundary')
	arrange(marked, 200)
	assert(marked.FragmentPool[2].Gui == fragment and fragment.Visible and marked.FragmentPool[2].Width==marked.Items[5].X-marked.Items[3].X)
	local custom = run('<mark style="background: #123456; color: white">AA <b>BB</b></mark>')
	arrange(custom)
	assert(custom.FragmentPool[1].Gui.BackgroundColor3 == Color3.fromRGB(18, 52, 86) and custom.Items[2].Style.FontWeight == 700)
	local clear = run('<mark style="background: transparent">AA</mark>')
	arrange(clear)
	assert(clear.Items[1].Style.InlineBackground == nil)
	local preserved = run('<mark> AA  BB </mark>', 'white-space: pre')
	arrange(preserved)
	assert(preserved.Items[1].Kind == "Space" and preserved.FragmentPool[1].Gui.BackgroundTransparency == 0)
	local last = run('AA BB CC', 'text-align: left; text-align-last: right')
	arrange(last, 60)
	assert(last.Items[1].X == 0 and last.Items[3].X == 40 and last.Items[3].LineIndex == 2)
	local forced = run('AA<br>BB CC', 'text-align-last: center')
	arrange(forced, 100)
	assert(forced.Items[1].X == 40 and forced.Items[3].X == 27.5)
	local justified = run('AA BB', 'text-align-last: justify')
	arrange(justified, 100)
	assert(justified.Items[2].X == 80)
	for _, case in {{"auto", 0}, {"start", 0}, {"end", 80}, {"left", 0}, {"right", 80}, {"center", 40}} do
		local single = run('AA', 'text-align: justify; text-align-last: ' .. case[1])
		arrange(single, 100)
		assert(single.Items[1].X == case[2])
	end
	local hr = build('<div style="font-size: 20px"><hr><hr style="width: 50%"></div>')
	assert(blockLayout.arrange(hr, 200, 0, 0, function() return true end) == 34)
	local first, second = table.unpack(hr.Children[1].Children)
	assert(first.Gui.Size[2] == 2 and first.Style.Margin[1] == 10)
	assert(first.ClipContent and first.ClipContent.ClipsDescendants and first.ClipContent.Parent==first.Gui
		and first.ClipContent.Size[1]==first.OuterWidth and first.ClipContent.Size[2]==2,"The hr overflow clip retains its 2px border-box bounds")
	assert(second.Gui.Position[1] == 49 and second.Gui.Size[1] == 102 and second.Gui.Position[2] == 12,"The first hr margin collapses through its borderless block parent")
	assert(first.InsetEdges[1].Size[2] == 1 and first.InsetEdges[3].Position[2] == 1)
	local flat = build('<hr style="border: 2px solid red; margin: 3px 0; width: 40px">')
	assert(blockLayout.arrange(flat, 200, 0, 0, function() return true end) == 10)
	assert(flat.Children[1].InsetEdges == nil and flat.Children[1].Gui.Position[1] == 0)
	local parent = {FontSize = 20, Font = Enum.Font.Arial, Color = Color3.new(0, 0, 0), TextAlignLast = "right"}
	assert(Style.resolve(fixtureElement("span",{}), parent, error, true).TextAlignLast == "right")
	local warnings = 0
	local aligned = Style.resolve(fixtureElement("span",{style = "vertical-align: middle; text-align-last: match-parent"}), parent, function() warnings += 1 end, true)
	assert(aligned.VerticalAlign == 'middle' and warnings == 1,
		'Inline middle alignment is supported; unsupported last-line grammar still warns')
	local smaller = run('AA <small>BB<small>CC</small></small> DD')
	arrange(smaller)
	assert(math.abs(smaller.Items[2].Style.FontSize - 20 / 1.2) < 0.0001)
	assert(math.abs(smaller.Items[3].Style.FontSize - 20 / 1.44) < 0.0001)
	assert(smaller.Items[2].BaselineShift == 0 and smaller.Items[2].Y + smaller.Items[2].Baseline == smaller.Items[1].Y + smaller.Items[1].Baseline)
	assert(smaller.Items[2].Style.LineHeight.Kind == "px", "small inherits line-height instead of resetting it like sup/sub")
	local overrideSmall = run('<small style="font-size: 24px">AA</small>')
	assert(overrideSmall.Items[1].Style.FontSize == 24)
	local code = run('<code>AA   BB &lt; CC</code>')
	arrange(code)
	assert(#code.Items == 4 and code.Items[1].Style.Font == "Roboto Mono" and code.Items[2].X == 25)
	assert(code.Items[3].Text == "<", "Code is normal parsed HTML, not raw text or executable code")
	local monospace = run('AA', 'font-family: monospace')
	assert(monospace.Items[1].Style.Font == "Roboto Mono")
	for _, case in {{"\nAA", "AA"}, {"\r\nAA", "AA"}, {"\n\nAA", "\nAA"}, {" \nAA", " \nAA"}, {"&#10;AA", "AA"}, {"<!--x-->\nAA", "\nAA"}, {"<code>\nAA</code>", "\nAA"}} do
		assert(DOM.textContent(Parser.parse("<pre>" .. case[1] .. "</pre>")) == case[2], "Only one immediately leading pre newline is removed")
	end
	local pre = build('<pre style="font-size: 20px; line-height: 20px">\n  AA   BB\n    CC</pre>')
	local preHeight, preWidth = blockLayout.arrange(pre, 40, 0, 0, function() return true end)
	local preBox = pre.Children[1]
	assert(preHeight == 80 and preWidth == 65 and preBox.Style.Font == "Roboto Mono" and preBox.Style.Margin[1] == 20)
	assert(preBox.Style.WhiteSpace == "pre" and preBox.Children[1].Items[1].Kind == "Space")
	count = requests
	blockLayout.arrange(pre, 200, 0, 0, function() return true end)
	assert(requests == count)
	local preOverride = build('<pre style="font-family: Roboto; white-space: normal; margin: 0; line-height: 20px">AA BB</pre>')
	assert(blockLayout.arrange(preOverride, 25, 0, 0, function() return true end) == 40)
	assert(preOverride.Children[1].Style.Font == "Roboto" and preOverride.Children[1].Style.Margin[1] == 0)
	local quote = build('<blockquote style="font-size: 20px; line-height: 20px"><p>AA</p><p>BB</p></blockquote>')
	assert(blockLayout.arrange(quote, 200, 0, 0, function() return true end) == 96)
	local quoteBox = quote.Children[1]
	assert(quoteBox.Gui.Position[1] == 40 and quoteBox.Gui.Size[1] == 120 and quoteBox.Style.Margin[1] == 20)
	assert(quoteBox.Children[1].Gui.Position[2] == 0 and quoteBox.Children[2].Gui.Position[2] == 36)
	local nestedQuote = build('<blockquote style="line-height: 20px"><blockquote>AA</blockquote></blockquote>')
	assert(blockLayout.arrange(nestedQuote, 240, 0, 0, function() return true end) == 52)
	assert(nestedQuote.Children[1].Children[1].Gui.Position[1] == 40 and nestedQuote.Children[1].Children[1].Gui.Size[1] == 80)
	local paddedQuote = build('<blockquote style="padding: 5px; margin: 2px; line-height: 20px"><p>AA</p></blockquote>')
	assert(blockLayout.arrange(paddedQuote, 200, 0, 0, function() return true end) == 66)
	print("Small elements: hr, mark, sup/sub, small, code/pre, blockquote, last-line alignment, margins, parser newlines and reflow reuse passed")
end
