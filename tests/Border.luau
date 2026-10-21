--!strict
return function(Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local parent = {Font = "Inter", FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function resolve(css, inherited, warn, author)
		return Style.resolve(fixtureElement("div",{style = css}), inherited or parent, warn or function(message) error(message) end, false, author)
	end
	assert(resolve("").BorderSize == 0 and resolve("").BorderRadius == 0)
	local red = Color3.fromRGB(255, 0, 0)
	for _, css in {"2px solid red", "red 2px solid", "solid red 2px"} do
		local style = resolve("border: " .. css)
		assert(style.BorderSize == 2 and style.BorderColor == red)
	end
	assert(resolve("border: solid; color: red").BorderColor == red)
	assert(resolve("color: red; border: solid").BorderColor == red)
	assert(resolve("border: solid").BorderSize == 3)
	assert(resolve("border: 2px red").BorderSize == 0, "Omitted style defaults to none")
	assert(resolve("border: 0 solid red").BorderSize == 0)
	assert(resolve("border: 3px solid red; border: none").BorderSize == 0)
	assert(resolve("border: 3px solid red; border-width: 1px").BorderSize == 1)
	assert(resolve("border-width: 1px; border: solid").BorderSize == 3, "Shorthand resets omitted width")
	assert(resolve("border-color: red; border: 2px solid").BorderColor == parent.Color, "Shorthand resets color to currentcolor")
	assert(resolve("border: 2px solid; border-color: red").BorderColor == red)
	local fractional=resolve("border-style: solid; border-width: 2.5px")
	assert(fractional.BorderSize == 2 and fractional.BorderWidth==2.5 and fractional.BorderSides[1].Width==2.5,"Used border widths follow the captured native pixel rounding while authored fractions remain available for animation")
	assert(resolve("border: 2px solid red !important; border-width: 8px").BorderSize == 2)
	assert(resolve("border-width: 8px !important; border: 2px solid red").BorderSize == 8)
	assert(resolve("border: 2px solid", nil, nil, "border-width: 9px !important").BorderSize == 9)
	local origin = resolve("border: 4px solid red; border-radius: 12px")
	local child = resolve("", origin)
	assert(child.BorderSize == 0 and child.BorderRadius == 0, "Borders and radii do not inherit")
	assert(resolve("border-radius: 12px; border: none").BorderRadius == 12, "Border shorthand does not reset radius")
	for _, value in {"2px invalid red", "2px solid red blue", "-1px solid", "10% solid", "solid solid", "", "thin thick solid"} do
		local warnings = 0
		local style = resolve("border: 2px solid red; border: " .. value, nil, function() warnings += 1 end)
		assert(style.BorderSize == 2 and style.BorderColor == red and warnings == 1)
	end
	for _, value in {"-1px", "auto", "2px // 4px", "2px /"} do
		local warnings = 0
		assert(resolve("border-radius: 6px; border-radius: " .. value, nil, function() warnings += 1 end).BorderRadius == 6 and warnings == 1)
	end
	for _,value in {"10%","2px 4px","2px / 4px"} do
		local warnings=0;local rounded=resolve("border-radius:"..value,nil,function() warnings+=1 end)
		assert(warnings==0 and rounded.BorderRadii,value)
	end
	local warnings = 0
	local inline = Style.resolve(fixtureElement("span",{style = "border: 2px solid; border-radius: 4px"}), parent, function() warnings += 1 end, true)
	assert(inline.BorderSize == 0 and inline.BorderRadius == 0 and warnings == 2)
	local modifiers = {}
	local renderer = loadRenderTree({
		create = function(class, owner, props)
			local object = table.clone(props); object.ClassName, object.Parent = class, owner
			return object
		end,
		modifier = function(class, owner, props)
			local object = table.clone(props); object.ClassName, object.Parent = class, owner
			table.insert(modifiers, object)
			return object
		end,
	})
	local requests = 0
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			requests += 1
			return {X = if text == " " then 5 else 20, Y = size}
		end},
	})
	local block = loadBlockLayout({["Layout/WordLayout"] = layout})
	local function build(html) return renderer.build(Parser.parse(html), {}, function(message) error(message) end) end
	local tree = build([[<div style="border: 2px solid red; border-radius: 8px; padding: 10px; line-height: 10px">AA BB CC</div>]])
	local box, words = tree.Children[1], tree.Children[1].Children[1]
	assert(#modifiers == 2 and modifiers[1].ClassName == "UICorner" and modifiers[1].CornerRadius.Offset == 8)
	assert(modifiers[2].ClassName == "UIStroke" and modifiers[2].Parent == box.Gui and modifiers[2].Thickness == 2)
	assert(modifiers[2].BorderStrokePosition == Enum.BorderStrokePosition.Inner and modifiers[2].Color == red)
	assert(modifiers[2].LineJoinMode == Enum.LineJoinMode.Round, "Rounded boxes use round stroke joins")
	assert(box.Gui.BackgroundTransparency == 1, "Border works without forcing an opaque fill")
	local height, width = block.arrange(tree, 100, 0, 0, function() return true end)
	assert(box.Gui.Size[1] == 100 and height == 34 and width == 100)
	assert(words.Items[1].Gui.Position[1] == 12 and words.Items[3].LineIndex == 1)
	local count = requests
	assert(block.arrange(tree, 80, 0, 0, function() return true end) == 44)
	assert(words.Items[3].LineIndex == 2 and requests == count and #modifiers == 2, "Resize accounts for border width and reuses measurements/modifiers")
	local layeredBorder = build([[<div style="height: 20px; border: 3px solid rgba(255, 0, 0, .5); border-radius: 6px; background-image: linear-gradient(red, blue)"></div>]])
	block.arrange(layeredBorder, 100, 0, 0, function() return true end)
	local layeredBox = layeredBorder.Children[1]
	assert(layeredBox.InsetEdges and layeredBox.InsetEdges.Overlay, "Image-backed borders use a foreground overlay")
	assert(layeredBox.InsetEdges.Stroke.Parent == layeredBox.InsetEdges.Overlay and layeredBox.InsetEdges.Overlay.ZIndex == 1,
		"The border stroke paints above background-image layers")
	assert(layeredBox.InsetEdges.Overlay.Size[1] == 100 and layeredBox.InsetEdges.Overlay.Size[2] == 26,
		"The border overlay follows the arranged border box")
	local fixed = build([[<div style="width: 40px; height: 30px; padding: 5px; margin: 3px; border: 2px solid"></div><div>AA</div>]])
	assert(modifiers[#modifiers].LineJoinMode == Enum.LineJoinMode.Miter, "Boxes without UICorner keep miter joins")
	block.arrange(fixed, 100, 0, 0, function() return true end)
	assert(fixed.Children[1].Gui.Size[1] == 54 and fixed.Children[1].Gui.Size[2] == 44)
	assert(fixed.Children[1].Gui.Position[1] == 3 and fixed.Children[2].Gui.Position[2] == 50, "Explicit sizes are content-box; sibling flow includes both border edges and margins")
	local percent = build([[<div style="width: 50%; padding: 5px; border: 2px solid"><p style="margin: 0; text-indent: 10%">AA</p></div>]])
	block.arrange(percent, 200, 0, 0, function() return true end)
	assert(percent.Children[1].Gui.Size[1] == 114)
	local paragraph = percent.Children[1].Children[1]
	assert(paragraph.Gui.Position[1] == 7 and paragraph.Children[1].Items[1].X == 10)
	local start = #modifiers
	local retained = build([[<div style="border: none; border-radius: 6px; background: red"></div><div style="border: 0 solid; border-radius: 0"></div><div style="display: none; border: 2px solid; border-radius: 5px"></div>]])
	assert(#modifiers == start + 3 and modifiers[start + 1].ClassName == "UICorner", "Rounded backgrounds need no border; zero styles allocate no modifiers")
	assert(modifiers[start + 2].Parent == retained.Children[3].Gui and modifiers[start + 3].Parent == retained.Children[3].Gui
		and not retained.Children[3].Gui.Visible, "Hidden blocks retain reusable border modifiers without painting them")
	print("Borders: shorthand/longhand cascade, currentcolor, no inheritance, invalid/inline diagnostics, inside strokes, corner modifiers, content-box sizing, wrapping, percentage widths and resize reuse passed")
end
