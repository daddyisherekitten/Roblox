--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local base = {Font = "Inter", FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function resolve(css, parent, warnings, author)
		return Style.resolve(fixtureElement("div",{style = css}), parent or base, function(message)
			if warnings then table.insert(warnings, message) else error(message) end
		end, false, author)
	end
	assert(resolve("").BoxShadows == nil and #resolve("box-shadow: none").BoxShadows == 0)
	for _, value in {"2px -3px 4px -5px red", "red 2px -3px 4px -5px"} do
		local shadow = resolve("box-shadow: " .. value).BoxShadows[1]
		assert(shadow.X == 2 and shadow.Y == -3 and shadow.Blur == 4 and shadow.Spread == -5 and shadow.Color == Color3.fromRGB(255, 0, 0))
	end
	local short = resolve("box-shadow: +0 -.5px").BoxShadows[1]
	assert(short.X == 0 and short.Y == -0.5 and short.Blur == 0 and short.Spread == 0 and short.Color == "currentcolor")
	for _, value in {"rgba(255, 0, 0, .25)", "rgb(100%, 0%, 0%, 25%)"} do
		local shadow = resolve("box-shadow: 0 0 8px " .. value).BoxShadows[1]
		assert(shadow.Color == Color3.fromRGB(255, 0, 0) and shadow.Alpha == 0.25)
	end
	assert(resolve("box-shadow: 0 0 #f008").BoxShadows[1].Alpha == 136 / 255)
	assert(resolve("box-shadow: 0 0 #ff000080").BoxShadows[1].Alpha == 128 / 255)
	assert(resolve("box-shadow: 0 0 transparent").BoxShadows[1].Alpha == 0)
	local list = resolve("box-shadow: 0 1px rgba(0, 0, 0, .2), blue -2px 3px 4px -1px").BoxShadows
	assert(#list == 2 and list[1].Alpha == .2 and list[2].X == -2)
	assert(#resolve("box-shadow: " .. string.rep("0 0,", 15) .. "0 0").BoxShadows == 16)
	local tooMany = {}
	assert(resolve("box-shadow: " .. string.rep("0 0,", 16) .. "0 0", nil, tooMany).BoxShadows == nil and #tooMany == 1)
	local clamped = resolve("box-shadow: 0 0 rgba(300, -2, 0, 2)").BoxShadows[1]
	assert(clamped.Color == Color3.fromRGB(255, 0, 0) and clamped.Alpha == 1)
	assert(resolve("box-shadow:0 0 calc(1px)").BoxShadows[1].Blur==1)
	assert(resolve('box-shadow:1ex 0').BoxShadows[1].X==10,'Font-relative shadow offsets share the CSS unit context')
	assert(resolve('box-shadow:0 0 rgb(0 0 0 / .5)').BoxShadows[1].Alpha==.5,'Modern RGB syntax is valid in box shadows')
	for _, value in {"", "1px", "1 2", "1px red 2px", "0 0 red blue", "0 0 -1px", "0 0 1001px", "0 0 0 0 0", "0 0 inset inset",
		"0 0,", ",0 0", "0 0, ", "none, 0 0", "10% 0", "--1px 0", "+-1px 0",
		"0 0 rgba(0, 0, 0,)", "0 0 rgb(0%, 0, 0)", "0 0 rgba(0, 0, 0, nan)"} do
		local warnings = {}
		local style = resolve("box-shadow: 1px 2px red; box-shadow: " .. value, nil, warnings)
		assert(#warnings == 1 and style.BoxShadows[1].X == 1, "Invalid declaration must leave previous complete shadow list intact: " .. value)
	end
	assert(#resolve("box-shadow: 0 0; box-shadow: none").BoxShadows == 0)
	assert(resolve("box-shadow: 0 0 !important; box-shadow: none").BoxShadows[1])
	assert(resolve("box-shadow: none", nil, nil, "box-shadow: 1px 2px !important").BoxShadows[1].X == 1)
	assert(resolve("", resolve("box-shadow: 0 0")).BoxShadows == nil, "Box shadows do not inherit")
	local warnings = {}
	local inline = Style.resolve(fixtureElement("span",{style = "box-shadow: 0 0"}), base, function(m) table.insert(warnings, m) end, true)
	assert(inline.BoxShadows == nil and #warnings == 1)
	local modifiers = {}
	local factory = {
		create = function(class, parent, props)
			local object = table.clone(props); object.ClassName, object.Parent = class, parent; return object
		end,
		modifier = function(class, parent, props)
			local object = table.clone(props); object.ClassName, object.Parent = class, parent
			table.insert(modifiers, object); return object
		end,
	}
	local renderer = loadRenderTree(factory)
	local requests = 0
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size) requests += 1; return {X = if text == " " then 5 else 20, Y = size} end},
	})
	local block = loadBlockLayout({["Layout/WordLayout"] = layout})
	local html = '<style>#card {box-shadow: 2px 3px 8px 4px rgba(0,0,0,.25), -2px -3px 0 -1px currentcolor !important}</style><div id="card" style="box-shadow: none; color: red; padding: 10px; border: 2px solid; border-radius: 8px; overflow: hidden">AA BB CC</div><div>AA</div>'
	local tree = renderer.build(Parser.parse(html), {}, error)
	local card = tree.Children[1]
	assert(#modifiers == 4 and modifiers[1].ClassName == "UICorner")
	local first, second = modifiers[2], modifiers[3]
	assert(first.ClassName == "UIShadow" and first.Parent == card.Gui and first.ZIndex == -1 and second.ZIndex == -2)
	assert(first.BlurRadius.Offset == 8 and first.Offset[1] == 2 and first.Offset[2] == 3 and first.Spread[1] == 4 and first.Transparency == .75)
	assert(second.Color == Color3.fromRGB(255, 0, 0) and second.Spread[1] == -1 and second.Spread[2] == -1)
	assert(card.ClipContent and card.ClipContent.ClipsDescendants and card.ClipContent.Parent==card.Gui,
		"Overflow clipping remains on the card content, independently of outer shadows/focus outline")
	for _,run in card.Children do for _,item in run.Items or {} do
		assert(item.Gui.Parent==card.ClipContent,"All overflowing card glyphs use the retained clipping host")
	end end
	local height, width = block.arrange(tree, 100, 0, 0, function() return true end)
	local calls = requests
	block.arrange(tree, 70, 0, 0, function() return true end)
	assert(card.Gui.Size[1] == 70 and first.Parent == card.Gui and #modifiers == 4 and requests == calls)
	assert(card.ClipContent.Size[1]==card.Gui.Size[1] and card.ClipContent.Size[2]==card.Gui.Size[2],
		"The clipping host tracks the exact resized card bounds")
	local againHeight, againWidth = block.arrange(tree, 100, 0, 0, function() return true end)
	assert(againHeight == height and againWidth == width and requests == calls)
	local plain = renderer.build(Parser.parse((html:gsub("box%-shadow:[^;}]+", "box-shadow: none"))), {}, error)
	local plainHeight, plainWidth = block.arrange(plain, 100, 0, 0, function() return true end)
	assert(plainHeight == height and plainWidth == width and plain.Children[2].Gui.Position[2] == tree.Children[2].Gui.Position[2], "Shadows must not affect flow or scroll dimensions")
	local count = #modifiers
	local retained=renderer.build(Parser.parse('<div style="box-shadow: none"></div><div style="display: none; box-shadow: 0 0"></div>'), {}, error)
	assert(#modifiers == count+1 and modifiers[#modifiers].Parent==retained.Children[2].Gui and not retained.Children[2].Gui.Visible,
		"Absent shadows allocate no modifier; hidden blocks retain a reusable, nonpainting shadow")
	count=#modifiers
	local transparent=renderer.build(Parser.parse('<div style="box-shadow: 0 0 transparent"></div>'), {}, error)
	for index=count+1,#modifiers do
		assert(modifiers[index].ClassName=='UIShadow' and modifiers[index].Transparency==1,
			'A transparent shadow may retain its animation object but contributes no paint')
	end
	count=#modifiers
	block.arrange(transparent,100,0,0,function()return true end)
	block.arrange(transparent,70,0,0,function()return true end)
	assert(#modifiers==count,'Transparent shadow resize reuses retained objects')
	local attempts = 0
	local unsupported = loadRenderTree({create = factory.create, modifier = function(class)
		assert(class == "UIShadow"); attempts += 1; error("UIShadow not available")
	end})
	warnings = {}
	local fallback = unsupported.build(Parser.parse('<div style="box-shadow: 0 0, 1px 1px">AA</div><div style="box-shadow: 0 0">BB</div>'), {}, function(m) table.insert(warnings, m) end)
	assert(#fallback.Children == 2 and attempts == 1 and #warnings == 1, "An unavailable API leaves the page usable with one diagnostic")
	print("Box shadows: CSS/alpha/cascade, native parameters/order, resize reuse, unchanged layout and API fallback passed")
end
