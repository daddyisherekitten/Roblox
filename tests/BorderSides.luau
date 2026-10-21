--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout, ImageLayout, ImageBox, Pixels)
 local fixtureElement=require('DOM/Node').element
	local parent = {FontSize = 20, Font = "Inter", Color = Color3.new(0, 0, 0)}
	local function resolve(css, author, inherited)
		return Style.resolve(fixtureElement("div",{style = css}), inherited or parent, error, false, author)
	end
	for count, indices in {{1, 1, 1, 1}, {1, 2, 1, 2}, {1, 2, 3, 2}, {1, 2, 3, 4}} do
		for _, case in {
			{"border-width", {"0", "thin", "3px", "thick"}, "Width", {0, 1, 3, 5}},
			{"border-style", {"solid", "none", "inset", "solid"}, "Style", {"solid", "none", "inset", "solid"}},
			{"border-color", {"red", "rgb(0, 0, 255)", "currentcolor", "transparent"}, "Color", {Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 255), parent.Color, Color3.new(0, 0, 0)}},
		} do
			local value = table.concat(case[2], " ", 1, count)
			local expanded = resolve("border: 2px solid; " .. case[1] .. ": " .. value)
			for side, index in indices do assert(expanded.BorderSides[side][case[3]] == case[4][index], case[1] .. ": " .. value) end
		end
	end
	local multi = resolve("border-width: 1px 2px 3px 4px; border-left-width: 8px; border-style: solid none solid inset; border-color: rgba(255, 0, 0, .5) blue")
	assert(multi.BorderSides[4].Width == 8 and multi.BorderSizes[2] == 0 and multi.BorderSizes[4] == 8)
	assert(multi.BorderSides[1].Alpha == .5 and multi.BorderSides[3].Alpha == .5 and multi.BorderSides[4].Alpha == 1)
	multi = resolve("border-left-width: 8px; border-width: 1px 2px; border-style: solid")
	assert(multi.BorderSizes[4] == 2, "Later shorthand replaces every side of that component")
	multi = resolve("border-left-width: 8px !important; border-width: 1px 2px; border-style: solid")
	assert(multi.BorderSizes[4] == 8 and multi.BorderSizes[2] == 2)
	multi = resolve("border-width: 1px 2px !important; border-left-width: 8px; border-style: solid")
	assert(multi.BorderSizes[4] == 2)
	local shared = Style.compile("border-color: currentcolor rgba(255, 0, 0, .5); border-width: 1px 2px; border-style: solid")
	local first, second = resolve("color: blue; border-right-color: green", shared), resolve("color: red", shared)
	assert(first.BorderSides[1].Color == Color3.fromRGB(0, 0, 255) and second.BorderSides[1].Color == Color3.fromRGB(255, 0, 0))
	assert(first.BorderSides[2].Alpha == 1 and second.BorderSides[2].Alpha == .5, "Compiled colors remain independent between elements")
	for _, invalid in {"border-width: 1px 2px 3px 4px 5px", "border-width: 1px -2px", "border-color: red invalid blue", "border-color: red rgb(0, 0, 255", "border-style: solid invalid", "border-style: solid none solid none solid", "border-width:", "border-top-width: 1px 2px", "border-right-color: red blue", "border-bottom-style: solid none"} do
		local warnings = 0
		local preserved = Style.resolve(fixtureElement("div",{style = "border: 4px solid red; " .. invalid}), parent, function() warnings += 1 end)
		assert(warnings == 1 and preserved.BorderUniform and preserved.BorderSize == 4 and preserved.BorderColor == Color3.fromRGB(255, 0, 0), "Invalid declaration rejected as a whole: " .. invalid)
	end
	local multiRadius=resolve("border-radius:1px 2px")
	assert(multiRadius.BorderRadii and multiRadius.BorderRadii[1].X.Value==1 and multiRadius.BorderRadii[2].X.Value==2)
	for side, name in {"top", "right", "bottom", "left"} do
		local s = resolve("border: 2px solid red; border-" .. name .. ": 5px solid blue")
		for index = 1, 4 do
			assert(s.BorderSizes[index] == (if index == side then 5 else 2))
			assert(s.BorderSides[index].Color == (if index == side then Color3.fromRGB(0, 0, 255) else Color3.fromRGB(255, 0, 0)))
		end
		s = resolve("border: 2px solid; border-" .. name .. "-width: thick; border-" .. name .. "-color: rgba(255, 0, 0, .5); border-" .. name .. "-style: inset")
		assert(s.BorderSizes[side] == 5 and s.BorderSides[side].Alpha == .5 and s.BorderSides[side].Style == "inset")
		s = resolve("border: 2px solid red; border-" .. name .. ": none")
		assert(s.BorderSizes[side] == 0 and s.BorderSides[side].Width == 3 and s.BorderSides[side].Color == parent.Color)
		s = resolve("border-" .. name .. ": 8px solid !important; border: 1px solid")
		assert(s.BorderSizes[side] == 8)
		s = resolve("border: 1px solid !important; border-" .. name .. ": 8px solid")
		assert(s.BorderUniform and s.BorderSizes[side] == 1)
	end
	local s = resolve("border-left: 5px solid; color: blue; border-right: 2px solid transparent")
	assert(s.BorderSides[4].Color == Color3.fromRGB(0, 0, 255) and s.BorderSides[2].Alpha == 0)
	assert(resolve("", nil, s).BorderSize == 0, "Side borders do not inherit")
	local compiled = Style.compile("border-left: thick solid currentcolor")
	local a, b = resolve("color: red", compiled), resolve("color: blue", compiled)
	assert(a.BorderSides[4].Color ~= b.BorderSides[4].Color and a.BorderSides ~= b.BorderSides)
	local errors = 0
	s = Style.resolve(fixtureElement("div",{style = "border-left: 4px solid; border-left: -2px solid; border-top-width: 10%; border-right-color: red blue"}), parent, function() errors += 1 end)
	assert(errors == 3 and s.BorderSizes[4] == 4)
	local objects, measures = 0, 0
	local factory = {create = function(class, host, props)
		objects += 1
		local gui = table.clone(props); gui.ClassName, gui.Parent = class, host
		return gui
	end, modifier = function() objects += 1; return {} end}
	local renderer = loadRenderTree(factory)
	for _, kind in {"dashed", "dotted", "double"} do
		local parsed = resolve("border: 6px " .. kind .. " red")
		assert(parsed.BorderUniform and parsed.BorderStyle == kind and parsed.BorderSize == 6)
		parsed = resolve("border: 6px solid; border-right-style: " .. kind)
		assert(parsed.BorderSides[2].Style == kind and parsed.BorderSides[1].Style == "solid")
	end
	local words = loadWordLayout({["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(_, _, size) measures += 1; return {X = 20, Y = size} end}})
	local layout = loadBlockLayout({["Layout/WordLayout"] = words})
	local css = "border-top: 2px solid red; border-right: 4px solid blue; border-bottom: 6px solid green; border-left: 8px solid orange;"
	local function build(extra, contents)
		return renderer.build(Parser.parse('<div style="' .. css .. extra .. '">' .. (contents or '') .. '</div>'), {}, error)
	end
	local function arrange(tree, width) return layout.arrange(tree, width or 200, 0, 0, function() return true end) end
	local patterns = renderer.build(Parser.parse('<div style="border-width: 6px; border-style: dashed dotted double solid; border-color: rgba(255, 0, 0, .5); height: 40px"></div>'), {}, error)
	arrange(patterns, 120)
	local patternBox = patterns.Children[1]
	local edges = patternBox.InsetEdges
	assert(patternBox.OuterWidth == 120 and patternBox.OuterHeight == 52)
	assert(#edges.Pools[1] > 1 and edges.Pools[2] == nil and #edges.Pools[3] == 2 and #edges.Pools[4] > 1)
	assert(edges[1].BackgroundTransparency == 1 and edges.Pools[1][1].BackgroundTransparency == .5)
	assert(edges.Pools[3][1].Size[2] == 2 and edges.Pools[3][2].Position[2] == 4 and edges.Pools[3][2].Size[2] == 2)
	assert(edges.Pools[4][1].Size[1] == 6 and edges.Pools[4][1].Size[2] == 6)
	local allocated = objects
	local firstSegment, lastSegment = edges.Pools[1][1], edges.Pools[1][#edges.Pools[1]]
	arrange(patterns, 40)
	assert(objects == allocated and edges.Pools[1][1] == firstSegment and not lastSegment.Visible)
	arrange(patterns, 120)
	assert(objects == allocated and lastSegment.Visible, "Resize reuses hidden dash segments")
	local short = renderer.build(Parser.parse('<div style="width: 0; height: 1px; border-right: 6px dotted"></div>'), {}, error)
	arrange(short)
	local dot = short.Children[1].InsetEdges.Pools[4][1]
	assert(dot.Size[1] == 1 and dot.Size[2] == 1 and dot.Position[1] == 2.5, "Short edges keep dots round and inside their border band")
	local thin = renderer.build(Parser.parse('<div style="height: 1px; border: 2px double"></div>'), {}, error)
	arrange(thin)
	assert(#thin.Children[1].InsetEdges.Pools[1] == 1, "Double narrower than 3px uses the solid approximation")
	local huge = renderer.build(Parser.parse('<div style="width: 100000px; border-top: 1px dotted"></div>'), {}, error)
	arrange(huge)
	assert(#huge.Children[1].InsetEdges.Pools[1] == 128, "Pattern allocation is bounded per edge")
	local tree = build("width: 100px; height: 50px; padding: 3px;", '<div style="height: 10px">AA</div>')
	arrange(tree)
	local box = tree.Children[1]
	assert(box.OuterWidth == 118 and box.OuterHeight == 64 and box.Children[1].LayoutX == 11 and box.Children[1].LayoutY == 5)
	assert(box.InsetEdges[1].Size[2] == 2 and box.InsetEdges[2].Size[1] == 8 and box.InsetEdges[3].Position[2] == 58 and box.InsetEdges[4].Position[1] == 114)
	local count, measured = objects, measures
	arrange(tree, 300)
	assert(objects == count and measures == measured)
	tree = build("box-sizing: border-box; width: 100px; height: 50px; padding: 3px;")
	arrange(tree); box = tree.Children[1]
	assert(box.ContentWidth == 82 and box.ContentHeight == 36 and box.OuterWidth == 100 and box.OuterHeight == 50)
	tree = build("width: 100px; height: 40px; overflow: auto; position: relative;", '<div style="height: 100px"></div><div style="position: absolute; right: 0; top: 0; width: 10px; height: 5px"></div>')
	arrange(tree); box = tree.Children[1]
	assert(box.ScrollGui.Position[1] == 8 and box.ScrollGui.Position[2] == 2 and box.ScrollGui.Size[1] == 100 and box.ScrollGui.Size[2] == 40)
	assert(box.Children[2].Gui.Position[1] == 88 and box.Children[2].Gui.Position[2] == 2)
	assert(box.ScrollGui.CanvasSize[2] == 100)
	tree = build("display: flex; width: 100px; padding: 3px;", '<div style="width: 10px; height: 10px"></div>')
	arrange(tree); box = tree.Children[1]
	assert(box.Children[1].LayoutX == 11 and box.Children[1].LayoutY == 5)
	local image = {Style = resolve(css .. "width: 100px; height: 50px; padding: 3px;"), Source = "rbxassetid://1", Alt = "", EmptyAlt = true}
	ImageBox.create(image, {}, factory, nil, "TestImage")
	local width, height = ImageLayout.size(image, 200)
	ImageBox.arrange(image)
	assert(width == 118 and height == 64 and image.ImageGui.Position[1] == 11 and image.ImageGui.Position[2] == 5)
	assert(image.BorderEdges[2].Size[1] == 8 and image.BorderEdges[4].Size[1] == 4)
	local patternedImage = {Style = resolve("border: 6px double; width: 30px; height: 20px;"), Source = "rbxassetid://1", Alt = "", EmptyAlt = true}
	ImageBox.create(patternedImage, {}, factory, nil, "PatternImage")
	ImageLayout.size(patternedImage, 200); ImageBox.arrange(patternedImage)
	assert(patternedImage.BoxWidth == 42 and patternedImage.BoxHeight == 32 and #patternedImage.BorderEdges.Pools[1] == 2)
	local shadowStyle = resolve(css)
	shadowStyle.BoxShadows = {{Inset = true, X = 50, Y = 0, Blur = 0, Spread = 0, Alpha = 1, Color = Color3.new(0, 0, 0)}}
	local pixels = Pixels.render(30, 30, shadowStyle, {Scale = 1, Width = 30, Height = 30})
	local function alpha(x, y) return buffer.readu8(pixels, (y * 30 + x) * 4 + 3) end
	assert(alpha(7, 10) == 0 and alpha(8, 10) == 255 and alpha(25, 10) == 255 and alpha(26, 10) == 0)
	assert(alpha(10, 1) == 0 and alpha(10, 2) == 255 and alpha(10, 23) == 255 and alpha(10, 24) == 0, "Inset shadow clips at each individual inner border edge")
	print("Border sides: 16 properties, cascade/resets/important, independent colors, box/flex/image/scroll/position geometry and resize reuse passed")
end
