--!strict
return function(Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, parent, warn, author)
		return Style.resolve(fixtureElement("div",{style = css}), parent or {Font = "Inter", FontSize = 20, Color = Color3.new(0, 0, 0)}, warn or error, false, author)
	end
	local red = Color3.fromRGB(255, 0, 0)
	for _, value in {"red thick dashed", "dashed red thick", "thick dashed red"} do
		local s = resolve("outline:" .. value)
		assert(s.OutlineWidth == 5 and s.OutlineStyle == "dashed" and s.OutlineColor == red and s.BorderSize == 0)
	end
	local s = resolve("outline-color:blue; outline-width:9px; outline-offset:4px; outline:solid; color:red")
	assert(s.OutlineWidth == 3 and s.OutlineColor == red and s.OutlineOffset == 4)
	assert(resolve("", s).OutlineStyle == "none" and resolve("", s).OutlineOffset == 0)
	assert(resolve("outline-width:7px!important; outline:solid").OutlineWidth == 7)
	assert(resolve("outline:4px dotted red!important; outline-width:7px").OutlineWidth == 4)
	assert(resolve("outline:solid", nil, nil, "outline-color:red!important").OutlineColor == red)
	assert(resolve("outline:solid rgba(255, 0, 0, .5)").OutlineColorAlpha == .5)
	assert(resolve("outline:solid; outline:none").OutlineStyle == "none")
	assert(resolve("outline:solid; outline-width:0").OutlineWidth == 0)
	assert(resolve("outline:auto").OutlineStyle=="auto")
	assert(resolve("outline:5px auto red").OutlineWidth==5 and resolve("outline:5px auto red").OutlineColor==red)
	for _, css in {"outline:2px solid red blue", "outline:-1px solid", "border:auto", "outline:auto solid", "outline:inset", "outline-width:2px 4px", "outline-style:solid dashed", "outline-offset:10%", "outline-offset:--2px"} do
		local warnings = 0
		local kept = resolve("outline:2px solid red; outline-offset:-3px;" .. css, nil, function() warnings += 1 end)
		assert(warnings == 1 and kept.OutlineWidth == 2 and kept.OutlineStyle == "solid" and kept.OutlineOffset == -3)
	end
	local count, measures = 0, 0
	local factory = {create = function(class, parent, props)
		count += 1
		local object = table.clone(props); object.Parent, object.ClassName = parent, class; return object
	end, modifier = function(class, parent, props)
		count += 1
		local object = table.clone(props); object.Parent, object.ClassName = parent, class; return object
	end}
	local renderer = loadRenderTree(factory)
	local word = loadWordLayout({["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size) measures += 1; return {X = #text * 5, Y = size} end}})
	local block = loadBlockLayout({["Layout/WordLayout"] = word})
	local function build(extra, width)
		local tree = renderer.build(Parser.parse('<div style="height:40px;padding:5px;border:2px solid;overflow:hidden;' .. extra .. '">AA BB</div><div>CC</div>'), {}, error)
		block.arrange(tree, width or 100, 0, 0, function() return true end)
		return tree
	end
	local plain, outlined = build(""), build("outline:3px dashed red;outline-offset:5px")
	local box, other = outlined.Children[1], plain.Children[1]
	assert(box.OuterWidth == other.OuterWidth and box.OuterHeight == other.OuterHeight)
	assert(outlined.LocalRight == plain.LocalRight and outlined.LocalBottom == plain.LocalBottom)
	assert(outlined.Children[2].Gui.Position[2] == plain.Children[2].Gui.Position[2])
	assert(box.Gui.ClipsDescendants == false and box.ClipContent.ClipsDescendants == true)
	assert(box.Children[1].Items[1].Gui.Parent == box.ClipContent)
	assert(box.Outline.Gui.Parent == box.Gui and box.Outline.Gui.Position[1] == -8)
	assert(box.Outline.Gui.Size[1] == box.OuterWidth + 16 and box.ClipContent.Size[1] == box.OuterWidth)
	local segment = box.Outline.Edges.Pools[1][1]
	local before, requests = count, measures
	block.arrange(outlined, 60, 0, 0, function() return true end)
	block.arrange(outlined, 100, 0, 0, function() return true end)
	assert(count == before and measures == requests and box.Outline.Edges.Pools[1][1] == segment)
	for _, kind in {"solid", "dotted", "double"} do
		local b = build("outline:6px " .. kind .. ";outline-offset:-3px").Children[1]
		assert(b.Outline.Gui.Position[1] == -3 and b.Outline.Gui.Size[1] == b.OuterWidth + 6)
		if kind ~= "solid" then assert(#b.Outline.Edges.Pools[1] > 1) end
	end
	local tiny = build("outline:4px solid;outline-offset:-1000px").Children[1]
	assert(tiny.Outline.Gui.Size[1] == 8 and tiny.Outline.Gui.Size[2] == 8)
	assert(build("outline:0 solid").Children[1].Outline == nil)
	assert(build("outline:solid;visibility:hidden").Children[1].Outline == nil)
	local scroll = build("outline:2px solid;overflow:scroll").Children[1]
	assert(scroll.Gui.ClipsDescendants == false and scroll.ScrollGui.Parent == scroll.Gui and scroll.ClipContent == nil)
	assert(scroll.Outline.Gui.Parent == scroll.Gui)
	local imageTree = renderer.build(Parser.parse('<img src="test.png" width="30" height="20" style="outline:3px double red;outline-offset:2px">'), {}, error, nil, nil, nil, function() return "rbxassetid://1" end)
	block.arrange(imageTree, 100, 0, 0, function() return true end)
	local item = imageTree.ImageItems[1]
	assert(item.Outline.Gui.Parent == item.BoxGui and item.Outline.Gui.Size[1] == item.BoxWidth + 10)
	assert(#item.Outline.Edges.Pools[1] == 2)
	print("Outline: cascade/reset, alpha, offsets, layout/scroll invariance, clipping, images and resize reuse passed")
end
