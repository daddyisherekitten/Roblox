--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout)
 local fixtureElement=require('DOM/Node').element
	local base = {Font = "Inter", FontSize = 20, Color = Color3.new(0, 0, 0)}
	local warnings = {}
	local function warning(message) table.insert(warnings, message) end
	local function resolve(css, parent, author)
		return Style.resolve(fixtureElement("span",{style = css}), parent or base, warning, true, author)
	end
	assert(resolve("").TextShadows == nil and #resolve("text-shadow: none").TextShadows == 0)
	for _, value in {"2px -3px rgba(0, 0, 0, .4)", "rgba(0, 0, 0, .4) 2px -3px 0px"} do
		local shadow = resolve("text-shadow: " .. value).TextShadows[1]
		assert(shadow.X == 2 and shadow.Y == -3 and shadow.Blur == 0 and shadow.Alpha == .4)
	end
	local inherited = resolve("text-shadow: 1px 2px red, -2px 0 #0008")
	assert(#resolve("", inherited).TextShadows == 2)
	assert(#resolve("text-shadow: none", inherited).TextShadows == 0, "Children may disable inherited shadows")
	assert(resolve("text-shadow: 0 0 blue", nil, "text-shadow: 1px 2px red !important").TextShadows[1].X == 1)
	assert(#resolve("text-shadow: " .. string.rep("0 0,", 15) .. "0 0").TextShadows == 16)
	assert(#warnings == 0)
	for _, value in {"0", "0 0 2px", "0 0 0 0", "inset 0 0", "0 0 inset", "1% 0", "--1px 0", "0 red 0", "0 0 red blue", "0 0,", "none, 0 0", string.rep("0 0,", 16) .. "0 0"} do
		local count = #warnings
		local style = resolve("text-shadow: 1px 2px red; text-shadow: " .. value)
		assert(#warnings == count + 1 and style.TextShadows[1].X == 1, "Invalid/unsupported shadows preserve previous declarations: " .. value)
	end
	local allocations, measurements = 0, 0
	local renderer = loadRenderTree({create = function(class, parent, props)
		allocations += 1
		local gui = table.clone(props)
		gui.ClassName, gui.Parent = class, parent
		return gui
	end})
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = {face = function(font, weight, style) return font .. weight .. style end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			measurements += 1
			return {X = if text == " " then 5 else #text * 10, Y = size}
		end},
	})
	local function build(text, css)
		local tree = renderer.build(Parser.parse('<p style="font-family: Inter; font-size: 20px; ' .. (css or '') .. '">' .. text .. '</p>'), {}, function(message) error(message) end,
			function(font, weight, style) return font .. weight .. style end)
		return tree.Children[1].Children[1], tree
	end
	local function arrange(run, width) return layout.arrange(run, width or 200, 7, 11, function() return true end) end
	local css = "text-shadow: 2px 3px rgba(0, 0, 0, .4), -1px 1px #f008; font-weight: bold; font-style: italic"
	local run, tree = build("AA BB CC", css)
	local first = run.Items[1]
	assert(first.Gui.ClassName == "Frame" and first.TextGui.ClassName == "TextLabel" and #first.ShadowLabels == 2)
	assert(#tree.FontPreloadTargets == 1 and tree.FontPreloadTargets[1] == first.TextGui, "Shadow copies do not add font preload targets")
	local beforeFirstLayout=measurements
	require("Rendering/TextShadows").arrange(first)
	assert(not first.ShadowLabels[1].Gui.Visible and measurements==beforeFirstLayout,"Pre-layout style paint keeps new shadow slots hidden without inventing glyph geometry")
	local height, extent = arrange(run)
	local shadow = first.ShadowLabels[1].Gui
	assert(shadow.Text == first.TextGui.Text and shadow.FontFace == first.TextGui.FontFace and shadow.TextSize == first.TextGui.TextSize)
	assert(shadow.Position[1] == 2 and shadow.Position[2] == 3 and shadow.TextTransparency == .6)
	assert(shadow.Size[1] == first.Width and shadow.Size[2] == first.Height)
	assert(first.TextGui.ZIndex > shadow.ZIndex and shadow.ZIndex > first.ShadowLabels[2].Gui.ZIndex)
	assert(first.Gui.Position[1] == 7 and first.Gui.Position[2] == 11 + first.Y)
	local plain = build("AA BB CC", "font-weight: bold; font-style: italic")
	local before = measurements
	local plainHeight, plainExtent = arrange(plain)
	assert(height == plainHeight and extent == plainExtent and measurements - before == before, "Shadows change neither geometry nor measurement count")
	local count, created = measurements, allocations
	arrange(run, 45)
	assert(run.Items[3].LineIndex == 2 and allocations == created and measurements == count)
	arrange(run)
	assert(first.ShadowLabels[1].Gui == shadow and run.Items[3].LineIndex == 1)
	local glyphRun = build("AB", css .. "; letter-spacing: 3px")
	arrange(glyphRun)
	local glyphItem = glyphRun.Items[1]
	assert(#glyphItem.ShadowLabels == 4 and glyphItem.TextGui == nil)
	assert(glyphItem.ShadowLabels[2].Gui.Position[1] == glyphItem.Glyphs[2].X + 2)
	assert(glyphItem.Glyphs[1].Gui.ZIndex > glyphItem.ShadowLabels[1].Gui.ZIndex)
	local transparent = build("AA", "text-shadow: 2px 3px transparent")
	assert(transparent.Items[1].ShadowLabels == nil and transparent.Items[1].Gui.ClassName == "TextLabel")
	local mixed = build('AA<span style="text-shadow: none">BB</span>CC', css)
	assert(#mixed.Items == 3 and mixed.Items[1].ShadowLabels and not mixed.Items[2].ShadowLabels and mixed.Items[3].ShadowLabels)
	arrange(mixed, 45)
	assert(mixed.Items[3].LineIndex == 1 and mixed.Items[2].Joined, "Shadow style changes preserve unbreakable word fragments")
	local continuous = build("AA<span>BB</span>CC", css)
	assert(#continuous.Items == 1 and continuous.Items[1].Text == "AABBCC", "Inherited list copies do not split identical text styles")
	local colored = build('<span style="color: red">AA</span>', "text-shadow: 1px 2px")
	arrange(colored)
	assert(colored.Items[1].ShadowLabels[1].Gui.TextColor3 == Color3.fromRGB(255, 0, 0))
	local hidden = build('AA<span style="display: none; text-shadow: 2px 3px red">hidden</span>BB')
	assert(#hidden.Items == 1 and hidden.Items[1].Text == "AABB" and not hidden.Items[1].ShadowLabels)
	local marked = build('<mark>AA</mark>', css)
	arrange(marked)
	local background=assert(marked.FragmentPool and marked.FragmentPool[1]).Gui
	assert(background.BackgroundColor3==Color3.fromRGB(255,255,0)and background.ZIndex==0
		and(marked.Items[1].Gui.BackgroundTransparency or 1)==1,'The complete inline fragment background paints below the transparent word/shadow sibling (native default ZIndex 1)')
	print("Text shadows: CSS/cascade/inheritance, alpha/order, glyph copies, word boundaries, unchanged measurements/layout and reflow reuse passed")
end
