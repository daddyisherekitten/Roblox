--!strict
return function(Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any, reference: any)
 local fixtureElement=require('DOM/Node').element
	local allocated, measurements = {}, 0
	local factory = {}
	function factory.create(class: string, parent: any, props: any): any
		local gui = table.clone(props or {})
		gui.ClassName, gui.Parent = class, parent
		gui.Visible = if gui.Visible == nil then true else gui.Visible
		gui.Destroy = function(self) self.Destroyed = true end
		table.insert(allocated, gui)
		return gui
	end
	factory.modifier = factory.create
	local renderer = loadRenderTree(factory)
	local words = loadWordLayout({["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			measurements += 1
			return {X = #text * 7, Y = size}
		end}})
	local blocks = loadBlockLayout({["Layout/WordLayout"] = words})
	local function near(a, b) assert(math.abs(a - b) < .001, tostring(a) .. " ~= " .. tostring(b)) end
	local function build(text: string, extra: string?): any
		local tree = renderer.build(Parser.parse('<style>div{color:blue}div:hover{color:red}div:focus{text-orientation:sideways!important}</style><div style="font:14px/1.4 Arial;writing-mode:vertical-rl;text-orientation:upright;width:80px;height:88px;box-sizing:border-box;padding:7px;border:2px solid blue;' .. (extra or '') .. '">' .. text .. '</div>'), {}, error, function(font) return font end)
		blocks.arrange(tree, 300, 0, 0, function() return true end)
		return tree, tree.Children[1], tree.Children[1].Children[1]
	end
	local tree, box, run = build("AVATAR 0123 — alpha beta gamma delta")
	assert(box.Gui.Rotation == nil or box.Gui.Rotation == 0)
	near(run.HeightBasis, 70)
	-- Chromium reference: AVAT / AR / 0123 / — / alph / a / beta ...
	local shown = run.DisplayItems
	assert(shown[1].Text == "AVAT" and shown[2].Text == "AR" and shown[3].Text == "0123")
	assert(shown[4].Text == "—" and shown[5].Text == "alph" and shown[6].Text == "a")
	assert(shown[7].Text == "beta" and shown[7].LineIndex == 7)
	for _, item in shown do
		assert(item.Gui.Rotation == 0 and item.Gui.AnchorPoint.X == 0)
		for index, glyph in item.UprightPool do
			near(glyph.Gui.Position[2], (index - 1) * 16)
			assert(glyph.TextGui.Text == item.VerticalCharacters[index].Text)
			assert(glyph.TextGui.Parent.Parent == item.Gui)
		end
	end
	near(shown[1].Gui.Position[1] - shown[2].Gui.Position[1], 19.6)
	assert(math.abs((reference.chars[1].x-reference.chars[5].x)-19.6)<.02)
	near(reference.chars[2].y-reference.chars[1].y, shown[1].UprightPool[2].Gui.Position[2])
	assert(reference.chars[5].c==shown[2].UprightPool[1].Text)
	assert(tree.HitNodes[shown[1].Gui] ~= nil, "Upright glyphs retain their source hit owner")
	local changed, needsLayout = tree:SetCSSState("hover", box.Node)
	assert(changed and not needsLayout, "Color-only hover does not reflow upright text")
	for _, item in shown do
		assert((item.TextGui or item.Gui).TextTransparency == 1)
		assert(item.UprightPool[1].TextGui.TextColor3 == Color3.fromRGB(255,0,0))
	end
	tree:SetCSSState("hover", nil)
	local count, measured = #allocated, measurements
	blocks.arrange(tree, 300, 0, 0, function() return true end)
	assert(#allocated == count and measurements == measured, "Unchanged reflow reuses glyphs and font bounds")
	box.Style.Height.Value = 120
	blocks.arrange(tree, 300, 0, 0, function() return true end)
	assert(run.DisplayItems[1].Text == "AVATAR", "Wrapping follows height changes")
	box.Style.Height.Value = 88
	blocks.arrange(tree, 300, 0, 0, function() return true end)
	assert(run.DisplayItems[1].Text == "AVAT")
	-- A dynamic mode change restores the source text and hides all upright pools.
	box.Style.TextOrientation = "sideways"
	blocks.arrange(tree, 300, 0, 0, function() return true end)
	for _, item in run.DisplayItems do
		assert(item.Gui.Rotation == 90 and (item.TextGui or item.Gui).TextTransparency == 0)
		for _, glyph in item.UprightPool or {} do assert(glyph.Gui.Visible == false) end
	end
	box.Style.TextOrientation = "upright"
	box.Style.WritingMode = "vertical-lr"
	blocks.arrange(tree, 300, 0, 0, function() return true end)
	assert(run.DisplayItems[1].Gui.Position[1] < run.DisplayItems[2].Gui.Position[1])
	local _, _, combined = build("Äp 👩‍💻p", "white-space:nowrap")
	assert(#combined.Items[1].UprightPool == 2 and combined.Items[1].UprightPool[1].Text == "Ä")
	assert(#combined.Items[2].UprightPool == 2 and combined.Items[2].UprightPool[1].Text == "👩‍💻")
	local _, _, tracked = build("AVATAR", "letter-spacing:2px")
	assert(tracked.DisplayItems[1].Text == "AVAT")
	near(tracked.DisplayItems[1].UprightPool[2].Gui.Position[2], 18)
	local _, _, preserved = build("A  B", "white-space:pre-wrap;direction:rtl;text-align:start")
	near(preserved.Items[1].X,6) -- 70px inline axis minus four 16px upright cells.
	local space = preserved.Items[2]
	assert(space.Kind == "Space" and space.Gui.Rotation == 0 and space.Gui.Size[2] == 32)
	local changedMode, modeLayout = tree:SetCSSState("focus", box.Node)
	assert(changedMode and modeLayout and box.Style.TextOrientation == "sideways")
	local inline = Style.resolve(fixtureElement("span",{style="text-orientation:upright"}), box.Style, error, true)
	assert(inline.TextOrientation == "upright")
	print("VerticalText tests passed: upright columns, height reflow, pooled glyphs, mode reset, Unicode clusters and tracking")
end
