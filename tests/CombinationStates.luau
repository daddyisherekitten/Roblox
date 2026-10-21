--!strict
-- Exercise live CSS on real replaced elements in different formatting contexts.
return function(Parser, loadRenderTree, loadWordLayout, loadBlockLayout, HTMLAnimations)
	local function create(class, parent, props)
		local gui = table.clone(props); gui.ClassName = class; gui.Parent = parent
		gui.Destroy = function(self) self.Parent = nil end
		return gui
	end
	local renderer = loadRenderTree({create = create, modifier = create})
	local overrides = {
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size) return {X = #text * size * .5, Y = size} end},
	}
	overrides["Layout/WordLayout"] = loadWordLayout(overrides)
	local layout = loadBlockLayout(overrides)
	local function near(a, b, context) assert(math.abs(a - b) < .001, context .. ": " .. tostring(a) .. " != " .. tostring(b)) end
	local count = 0
	for _, display in {"block", "flex", "grid"} do
		for _, element in {
			'<img id="target" src="photo" alt="">',
			'<svg id="target" width="80" height="50"><rect width="80" height="50"/></svg>',
			'<canvas id="target"></canvas>', '<video id="target"></video>', '<iframe id="target"></iframe>',
		} do
			local css = '#parent{display:' .. display .. ';width:220px}#target{display:block;width:80px;height:50px;margin:3px;background:red;border:1px solid blue;transition:transform 1s linear,opacity 1s linear}#parent:hover #target{transform:scale(1.2);opacity:.5;background:green;border-color:red;border-radius:8px;box-shadow:2px 3px 0 black}'
			local tree = renderer.build(Parser.parse('<style>' .. css .. '</style><div id="parent">' .. element .. '</div>'), {AbsoluteSize = Vector2.new(300, 400)}, function(message) assert(message == "video has no media source", message) end, nil, nil, nil, function() return "rbxassetid://1" end)
			layout.arrange(tree, 300, 0, 0, function() return true end)
			local parent, target
			for node, box in tree.NodeBoxes do
				if node.Attributes and node.Attributes.id == "parent" then parent = box end
				if node.Attributes and node.Attributes.id == "target" then target = box end
			end
			assert(target, "Replaced element must be registered for live CSS: " .. element)
			local item, width, height, gui = target.ImageItem, target.OuterWidth, target.OuterHeight, target.Gui
			local clock, tick, cleanups = 0, nil, {}
			local runtime = HTMLAnimations.start({Alive = true, Root = {SetAttribute = function() end}, AddCleanup = function(_, fn) table.insert(cleanups, fn) end}, tree, error,
				{RunService = {Heartbeat = {Connect = function(_, fn) tick = fn; return {Disconnect = function() tick = nil end} end}}, Clock = function() return clock end}, 0)
			runtime:AfterLayout()
			local changed, needsLayout = tree:SetCSSState("hover", parent.Node)
			assert(changed and needsLayout == false, "Replaced-element paint hover must not lay out its page")
			assert(target.Gui == gui and item.BoxGui.BackgroundColor3 == Color3.fromRGB(0, 128, 0), "Hover repaints the existing image surface")
			assert(target.Corner and target.Corner.CornerRadius.Offset == 8, "Image corners participate in paint updates: " .. element)
			assert(target.ShadowGuis and target.ShadowGuis[1], "Image shadows participate in paint updates: " .. element)
			assert(tick and target.TransformScale, "Replaced-element transition starts autonomously")
			local frames = runtime.Frames
			tree.LayoutInProgress = true; tick()
			assert(runtime.Frames == frames, "Animation callbacks cannot overwrite a suspended layout")
			tree.LayoutInProgress = false
			tree.LayoutNeedsRecovery = true; tick()
			assert(runtime.Frames == frames, "Animation also waits for a cancelled pass to recover")
			tree.LayoutNeedsRecovery = false
			near(target.TransformScale.Scale, 1, "Transition begins at previous scale")
			clock = .5; tick(); near(target.TransformScale.Scale, 1.1, "Transition midpoint")
			near(target.OpacityGroup.Gui.GroupTransparency, .25, "Opacity transition midpoint")
			clock = 1; tick(); near(target.TransformScale.Scale, 1.2, "Transition endpoint")
			near(target.OpacityGroup.Gui.GroupTransparency, .5, "Opacity transition endpoint")
			tree:SetCSSState("hover", nil)
			clock = 1.5; tick(); near(target.TransformScale.Scale, 1.1, "Reverse transition midpoint")
			clock = 2; tick(); near(target.TransformScale.Scale, 1, "Reverse transition endpoint")
			near(target.OpacityGroup.Gui.GroupTransparency, 0, "Opacity restores its initial value")
			near(target.OuterWidth, width, "Transform preserves layout width"); near(target.OuterHeight, height, "Transform preserves layout height")
			for _, cleanup in cleanups do cleanup() end
			assert(tick == nil, "Transition listeners disconnect")
			count += 1
		end
	end
	do
		-- Roblox Frames reject text properties on reads as well as writes. Keep
		-- that boundary strict so selection-only whitespace cannot masquerade
		-- as a TextLabel during a color-only focus recascade.
		local created = {}
		local function strictCreate(class, parent, props)
			local values = table.clone(props)
			values.ClassName, values.Parent, values.Visible = class, parent, true
			local attributes = {}
			function values:IsA(kind) return kind == class or kind == "GuiObject" end
			function values:SetAttribute(key, value) attributes[key] = value end
			function values:GetAttribute(key) return attributes[key] end
			function values:Destroy() self.Parent = nil end
			local function textProperty(key)
				if key == "TextColor3" or key == "TextTransparency" then
					assert(class == "TextLabel" or class == "TextBox" or class == "TextButton",
						key .. " is not a valid member of " .. class .. " " .. tostring(values.Name))
				end
			end
			local gui = setmetatable({}, {
				__index = function(_, key) textProperty(key); return values[key] end,
				__newindex = function(_, key, value) textProperty(key); values[key] = value end,
			})
			table.insert(created, gui)
			return gui
		end
		local strictRenderer = loadRenderTree({create = strictCreate, modifier = strictCreate})
		for _, vertical in {false, true} do
			local writing = if vertical then "writing-mode:vertical-rl;text-orientation:upright;width:120px;height:240px;" else ""
			local css = '#editor{white-space:pre-wrap;color:blue;' .. writing .. '}'
				.. '#editor:focus{color:rgba(255,0,0,.5)}.shadow{text-shadow:1px 1px}.glyph{letter-spacing:2px}.atomic{display:inline-block}.hidden{visibility:hidden}'
			local html = '<style>' .. css .. '</style><div id="editor" contenteditable="plaintext-only">A  \tB\n<br>C'
				.. '<span class="shadow">SH</span>  <span class="glyph">GL</span>\n'
				.. '<span class="hidden">HI</span><span class="atomic">AT</span><input value="field"></div>'
			local strictTree = strictRenderer.build(Parser.parse(html), {AbsoluteSize = Vector2.new(500, 600)}, error, function(font) return font end)
			layout.arrange(strictTree, 500, 0, 0, function() return true end)
			local editor
			for node, box in strictTree.NodeBoxes do if node.Attributes and node.Attributes.id == "editor" then editor = box end end
			assert(editor)
			local spaces, snapshots, breaks, atomics = 0, {}, 0, 0
			for _, item in strictTree.TextItems do
				assert(item.Kind == "Word" or item.Kind == "Space", "Only words and selection whitespace enter the text-paint registry")
				if item.Kind == "Space" then
					spaces += 1
					assert(item.Gui:IsA("Frame") and item.TextOwner and item.SelectionOrder, "Preserved spaces retain selection geometry")
					table.insert(snapshots, {Item = item, Gui = item.Gui, Position = item.Gui.Position, Size = item.Gui.Size, Order = item.SelectionOrder})
				end
			end
			for _, run in editor.Children do
				for _, item in run.Items or {} do
					if item.Kind == "Break" then breaks += 1; assert(item.Gui == nil) end
					if item.Kind == "Image" then atomics += 1; assert(table.find(strictTree.TextItems, item) == nil) end
				end
			end
			assert(spaces > 0 and breaks > 0 and atomics == 2, "The regression includes tabs/spaces, newlines/br, inline boxes and controls")
			local width, height, allocated = editor.OuterWidth, editor.OuterHeight, #created
			for _, active in {true, false, true, false} do
				local changed, needsLayout = strictTree:SetCSSState("focus", if active then editor.Node else nil)
				assert(changed and not needsLayout, "Editor focus/blur repaints text without a layout pass")
				local expected = if active then Color3.fromRGB(255, 0, 0) else Color3.fromRGB(0, 0, 255)
				local function checkLabel(label, style)
					assert(label.TextColor3 == expected, "Real glyphs still receive inherited focus colors")
					near(label.TextTransparency, if style.Visibility == "hidden" then 1 elseif active then .5 else 0, "Focused text alpha")
				end
				for _, item in strictTree.TextItems do
					if item.Kind ~= "Word" then continue end
					if item.VerticalAdvance then
						if item.Glyphs then
							for _, glyph in item.Glyphs do assert(glyph.Gui.Visible == false, "Upright tracked source remains hidden") end
						else assert((item.TextGui or item.Gui).TextTransparency == 1, "Upright source remains hidden") end
						for _, glyph in item.UprightPool do
							checkLabel(glyph.TextGui, item.Style)
							for _, shadow in glyph.ShadowLabels or {} do assert(shadow.Gui.TextColor3 == expected, "Upright currentcolor shadows repaint with their glyph") end
						end
					elseif item.Glyphs then
						for _, glyph in item.Glyphs do checkLabel(glyph.Gui, item.Style) end
					else checkLabel(item.TextGui or item.Gui, item.Style) end
					if not item.VerticalAdvance then
						for _, shadow in item.ShadowLabels or {} do assert(shadow.Gui.TextColor3 == expected, "currentcolor shadows repaint with their word") end
					end
				end
				for _, snapshot in snapshots do
					assert(snapshot.Item.Gui == snapshot.Gui and snapshot.Gui.Position == snapshot.Position and snapshot.Gui.Size == snapshot.Size
						and snapshot.Item.SelectionOrder == snapshot.Order, "Focus preserves retained whitespace and selection geometry")
				end
				assert(editor.OuterWidth == width and editor.OuterHeight == height and #created == allocated, "Focus paint preserves box geometry and allocated text surfaces")
			end
		end
		for _, sample in {
			'<div id="editor" contenteditable style="width:100px;height:20px;opacity:.5">Edit</div>',
			'<div id="outer" style="width:100px;height:20px;opacity:.5"><div id="editor" contenteditable style="width:100px;height:20px">Edit</div></div>',
			'<div id="outer" style="width:100px;height:20px;opacity:.5"><div id="editor" contenteditable style="display:inline-block;width:100px;height:20px">Edit</div></div>',
			'<div id="editor" contenteditable style="width:100px;height:20px;opacity:.5;overflow:hidden"><div id="wide" style="width:200px;height:40px">Wide</div></div>',
			'<div id="outer" style="width:100px;height:20px;opacity:.5"><input id="editor" style="box-sizing:border-box;width:100px;height:20px;margin:0;border:1px solid green"></div>',
		} do
			local strictTree = strictRenderer.build(Parser.parse(sample .. '<div id="untouched" style="width:80px;height:20px;opacity:.5">Unchanged</div>'),
				{AbsoluteSize=Vector2.new(500,600)}, error, function(font) return font end)
			layout.arrange(strictTree,500,0,0,function()return true end)
			local editor, outer, untouched, wide, control
			for node, box in strictTree.NodeBoxes do
				local id=node.Attributes and node.Attributes.id
				if id=="editor" then editor=box elseif id=="outer" then outer=box elseif id=="untouched" then untouched=box elseif id=="wide" then wide=box end
			end
			for _, c in strictTree.Controls do if c.Node.Attributes.id=="editor" then control=c end end
			local node=if control then control.Node else editor.Node
			local opacity=outer or editor
			assert(opacity.OpacityGroup and opacity.OpacityGroup.Gui.Size[1]==100)
			local unchangedBounds=untouched.OpacityBounds
			local unchangedSize=untouched.OpacityGroup.Gui.Size
			local width,height,right,bottom=opacity.OuterWidth,opacity.OuterHeight,strictTree.LocalRight,strictTree.LocalBottom
			local clip=editor and editor.ClipContent
			if wide then
				assert(clip and clip.ClipsDescendants and wide.Gui.Parent==clip, "Initially outline-free overflow content has an independent clip host")
				assert(editor.Gui.ClipsDescendants==false and clip.Size[1]==100 and clip.Size[2]==20)
			end
			local retainedOutline, allocated
			for _, active in {true,false,true,false} do
				local changed,needsLayout=strictTree:SetCSSState("focus-visible",if active then node else nil)
				assert(changed and not needsLayout, "The UA editor ring updates compositing without laying out content")
				local outline=if control then control.Item.ControlOutline else editor.Outline
				if active then
					assert(outline and outline.Gui.Visible~=false and outline.Edges==nil, "Auto focus uses a rounded native stroke")
					if not control then
						if retainedOutline then assert(outline.Gui==retainedOutline and #created==allocated, "Repeated generic focus reuses its outline surfaces")
						else retainedOutline,allocated=outline.Gui,#created end
					end
				end
				assert(opacity.OpacityGroup.Gui.Size[1]==(if active then 102 else 100)
					and opacity.OpacityGroup.Content.Position[1]==(if active then 1 else 0), "Own and ancestor CanvasGroups include the focus-ring outset")
				assert(untouched.OpacityBounds==unchangedBounds and untouched.OpacityGroup.Gui.Size==unchangedSize, "Unrelated opacity branches keep their cached bounds")
				assert(opacity.OuterWidth==width and opacity.OuterHeight==height and strictTree.LocalRight==right and strictTree.LocalBottom==bottom, "Compositing refits preserve layout and scroll geometry")
				if wide then assert(editor.ClipContent==clip and clip.ClipsDescendants and wide.Gui.Parent==clip and clip.Size[1]==100 and clip.Size[2]==20, "Focus preserves clipped overflowing content") end
			end
		end
	end
	print("Live CSS combinations: " .. count .. " block/flex/grid × image/SVG/canvas/video/iframe cases, autonomous transitions, strict whitespace/editor repaint and retained focus compositing/clipping")
end
