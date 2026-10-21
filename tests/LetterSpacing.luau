--!strict
return function(Parser: any, Style: any, Letters: any, loadRenderTree: any, loadWordLayout: any)
 local fixtureElement=require('DOM/Node').element
	local parent = {Font = "Inter", FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function resolve(css, inherited, warn)
		return Style.resolve(fixtureElement("span",{style = css}), inherited or parent, warn or function(message) error(message) end, true)
	end
	for value, expected in {normal = 0, ["0"] = 0, ["2px"] = 2, ["-1.5px"] = -1.5, ["+.5px"] = 0.5} do
		local style = resolve("letter-spacing: " .. value)
		assert(style.LetterSpacing == expected and resolve("", style).LetterSpacing == expected)
	end
	assert(resolve("letter-spacing: normal", resolve("letter-spacing: 2px")).LetterSpacing == 0)
	for _, value in {"auto", "10%", "2", "--1px", "-+2px", "100001px"} do
		local warnings = 0
		assert(resolve("letter-spacing: 3px; letter-spacing: " .. value, nil, function() warnings += 1 end).LetterSpacing == 3 and warnings == 1)
	end
	assert(#Letters.split("Äöß") == 3)
	local combined = Letters.split("Äp")
	assert(#combined == 2 and combined[1].Text == "Ä")
	local emoji = Letters.split("👩‍💻p")
	assert(#emoji == 2 and emoji[1].Text == "👩‍💻", "Keep joined emoji and combining sequences in a single label")
	local labels, frameCount = 0, 0
	local renderer = loadRenderTree({create = function(class, owner, properties)
		if class == "TextLabel" then labels += 1 else frameCount += 1 end
		local object = table.clone(properties)
		object.ClassName, object.Parent = class, owner
		return setmetatable(object, {__newindex = function(target, key, value)
			assert(class ~= "Frame" or (key ~= "TextSize" and key ~= "FontFace"), "Never write TextLabel properties to a word Frame")
			rawset(target, key, value)
		end})
	end})
	local requests, texts = 0, {}
	local face = {Family = "Test", Weight = "Bold", Style = "Italic"}
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = {face = function() return face end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			requests += 1; table.insert(texts, text)
			return {X = if text == " " or text == " " then 5 else 10 * #Letters.split(text), Y = size}
		end},
	})
	local function build(html)
		return renderer.build(Parser.parse(html), {}, function(message) error(message) end, function() return face end)
	end
	local function run(css, text) return build('<p style="' .. css .. '">' .. text .. '</p>').Children[1].Children[1] end
	local function arrange(words, width) return layout.arrange(words, width or 100, 0, 0, function() return true end) end
	local mixedSpacing = run("letter-spacing: 2px", 'X<span style="word-spacing: 6px">A&nbsp;B</span>')
	assert(#mixedSpacing.Items == 2, "Do not merge away word-spacing changes in a glyph-rendered NBSP group")
	arrange(mixedSpacing)
	assert(mixedSpacing.Items[2].Joined and mixedSpacing.Items[2].X == 12 and mixedSpacing.Items[2].Width == 35)
	local before = labels
	local tree = build([[<p style="letter-spacing: 2px; font-weight: bold; font-style: italic">AB CD</p>]])
	local words = tree.Children[1].Children[1]
	assert(labels == before + 4 and #words.Items == 2 and words.Items[1].Gui.ClassName == "Frame")
	assert(#tree.FontPreloadTargets == 1 and tree.FontPreloadTargets[1].ClassName == "TextLabel")
	assert(tree.FontPreloadTargets[1].FontFace == face)
	before = requests
	local height = arrange(words)
	assert(requests == before + 5 and texts[before + 1] == "A" and texts[before + 2] == "B", "Measure each character and one surviving space, not the whole word")
	local first, second = words.Items[1], words.Items[2]
	assert(first.Width == 22 and first.Glyphs[2].X == 12 and second.X == 31 and second.SpaceWidth == 9)
	assert(first.Glyphs[2].Gui.Position[1] == 12 and first.Glyphs[2].Gui.FontFace == face)
	assert(first.Glyphs[2].Gui.TextSize == first.TextSize and first.Glyphs[1].Gui.Parent == first.Gui)
	local count, labelCount, frames = requests, labels, frameCount
	assert(arrange(words, 52) == height * 2 and second.X == 0 and second.LineIndex == 2)
	assert(first.Glyphs[2].X == 12 and requests == count and labels == labelCount and frameCount == frames)
	arrange(words, 100)
	assert(second.X == 31 and requests == count, "Reuse character labels and native measurements on resize")
	words.Style.LetterSpacing = 3
	arrange(words)
	assert(first.Glyphs[2].X == 13 and first.Width == 23 and second.SpaceWidth == 11 and second.X == 34 and requests == count)
	words.Style.FontSize = 41
	arrange(words)
	assert(requests == count + 5 and first.Glyphs[1].Gui.TextSize == first.TextSize, "Font-size changes remeasure all character and space bounds")
	for _, text in {"Äöß", "Äp", "👩‍💻p"} do
		local unicode = run("letter-spacing: 2px", text)
		arrange(unicode)
		assert(#unicode.Items[1].Glyphs == #Letters.split(text))
		assert(unicode.Items[1].Glyphs[1].Gui.Text == Letters.split(text)[1].Text)
	end
	for _, css in {"", "letter-spacing: normal", "letter-spacing: 0px"} do
		before = labels
		local ordinary = run(css, "AB")
		assert(labels == before + 1 and ordinary.Items[1].Glyphs == nil and ordinary.Items[1].Gui.ClassName == "TextLabel")
	end
	local tabular = run("font-variant-numeric: tabular-nums", "109")
	assert(#tabular.Items[1].Glyphs == 3 and tabular.Items[1].Glyphs[1].Gui.TextXAlignment == Enum.TextXAlignment.Center)
	local digitWord={Style={TabularNums=true},Glyphs=Letters.split("109")}
	local digitCalls=0
	assert(Letters.measure(digitWord,face,57,function(value: string): any
		digitCalls+=1
		return {X=if value=="9" then 12 else 4,Y=57}
	end,function() return true end))
	Letters.arrange(digitWord,0,0)
	assert(digitCalls==10 and digitWord.Width==36 and digitWord.Glyphs[1].Width==12 and digitWord.Glyphs[2].X==12)
	local negative = run("letter-spacing: -2px", "ABC")
	arrange(negative)
	assert(negative.Items[1].Width == 26 and negative.Items[1].Glyphs[3].X == 16)
	local reverse = run("letter-spacing: -20px", "ABC")
	local _, extent = arrange(reverse)
	assert(reverse.Items[1].Width == 0 and reverse.Items[1].Glyphs[3].X == -20 and extent == 10)
	local spaced = run("letter-spacing: 2px; word-spacing: 6px", "AB CD")
	arrange(spaced)
	assert(spaced.Items[2].SpaceWidth == 15 and spaced.Items[2].X == 37)
	local inherited = build([[<div style="letter-spacing: 2px"><p>AB <span style="letter-spacing: normal">CD</span></p></div>]])
	local mixed = inherited.Children[1].Children[1].Children[1]
	arrange(mixed)
	assert(mixed.Items[1].Glyphs and not mixed.Items[2].Glyphs and mixed.Items[2].SpaceWidth == 8)
	local breaks = run("letter-spacing: 2px", "AB<br>CD EF")
	arrange(breaks)
	assert(breaks.Items[3].X == 0 and breaks.Items[4].SpaceWidth == 9)
	local center = run("letter-spacing: 2px; text-indent: 10px; text-align: center", "AB")
	arrange(center)
	assert(center.Items[1].X == 44)
	local justify = run("letter-spacing: 2px; text-align: justify", "AB CD EF")
	arrange(justify, 60)
	assert(justify.Items[1].X == 0 and justify.Items[2].X == 38 and justify.Items[3].X == 0)
	local transformed = run("letter-spacing: 2px; text-transform: uppercase", "straße")
	assert(#transformed.Items[1].Glyphs == 7 and transformed.Items[1].Glyphs[5].Text == "S")
	local nbsp = run("letter-spacing: 2px; word-spacing: 3px", "A&nbsp;B")
	arrange(nbsp, 1)
	assert(#nbsp.Items == 1 and #nbsp.Items[1].Glyphs == 3 and nbsp.Items[1].Width == 32 and nbsp.Items[1].Glyphs[3].X == 22)
	local decorated = run("letter-spacing: 3px; text-decoration: underline line-through", "Apa")
	before = requests
	arrange(decorated)
	local decoratedWord = decorated.Items[1]
	assert(requests == before + 3 and #decoratedWord.SkipInkCuts == 1, "Skip ink reuses individual character positions without prefix measurements")
	local cut = decoratedWord.SkipInkCuts[1]
	assert(cut.Left >= decoratedWord.Glyphs[2].X - 1 and cut.Right <= decoratedWord.Glyphs[2].X + decoratedWord.Glyphs[2].Width)
	assert(#decoratedWord.DecorationFrames == 3 and decoratedWord.DecorationFrames[3].Size[1] == decoratedWord.Width)
	count = requests
	decorated.Style.LetterSpacing = 5
	arrange(decorated)
	assert(decoratedWord.SkipInkCuts[1].Left == cut.Left + 2 and requests == count)
	local cancelled = {Glyphs = {{Text = "A"}, {Text = "B"}}}
	local alive, calls = true, 0
	assert(not Letters.measure(cancelled, face, 20, function()
		calls += 1; alive = false
		return {X = 10, Y = 20}
	end, function() return alive end))
	assert(calls == 1 and cancelled.Glyphs[1].Width == nil, "No partial character cache after destruction")
	print("Letter spacing: signed px, grapheme labels, transformed text, preload targets, whole-word wrapping, spacing, alignment, NBSP, skip ink, reuse and cancellation passed")
end
