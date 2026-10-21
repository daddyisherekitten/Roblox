--!strict
return function(Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, parent, warn)
		return Style.resolve(fixtureElement("div",{style = css}), parent or {}, warn or function(message) error(message) end)
	end
	local sized = resolve("min-height: 20px; max-height: 40px; overflow: HIDDEN")
	assert(sized.MinHeight.Value == 20 and sized.MaxHeight.Value == 40 and sized.Overflow == "hidden")
	local child = resolve("", sized)
	assert(child.MinHeight == nil and child.MaxHeight == nil and child.Overflow == "visible")
	assert(resolve("min-height: 20px; min-height: auto").MinHeight == nil)
	assert(resolve("max-height: 20px; max-height: none").MaxHeight == nil)
	assert(resolve('min-height:20%;max-height:80%').MinHeight.Percent and resolve('min-height:20%;max-height:80%').MaxHeight.Percent,'Both vertical limits accept percentages; indefinite containing heights are resolved by layout')
	for _, css in {"min-height: -1px", "min-height: none", "max-height: auto", "max-height: 100001px", "overflow: auto hidden scroll", "overflow-x: auto hidden"} do
		local warnings = 0
		local value = resolve("min-height: 20px; max-height: 40px; overflow: hidden; " .. css, nil, function() warnings += 1 end)
		assert(warnings == 1 and value.MinHeight.Value == 20 and value.MaxHeight.Value == 40 and value.Overflow == "hidden")
	end
	local warnings = 0
	Style.resolve(fixtureElement("span",{style = "min-height: 2px; max-height: 4px; overflow: hidden"}), {}, function() warnings += 1 end, true)
	assert(warnings == 3)
	local renderer = loadRenderTree({create = function(_, parent, properties)
		local gui=table.clone(properties);gui.Parent=parent;return gui
	end})
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
	local function arrange(tree, width) return block.arrange(tree, width or 200, 0, 0, function() return true end) end
	for mode, extra in {["content-box"] = 24, ["border-box"] = 0} do
		for _, case in {{"min-height: 40px", 40}, {"height: 80px; max-height: 40px", 40}, {"height: 10px; min-height: 60px; max-height: 40px", 60}} do
			local tree = build('<div style="padding: 10px; border: 2px solid; box-sizing: ' .. mode .. '; ' .. case[1] .. '"></div>')
			arrange(tree)
			assert(tree.Children[1].Gui.Size[2] == case[2] + extra)
		end
	end
	local tiny = build('<div style="box-sizing: border-box; max-height: 0; padding: 10px; border: 2px solid"></div>')
	assert(arrange(tiny) == 24)
	for _, overflow in {"hidden", "visible"} do
		local tree = build('<div style="width: 40px; max-height: 20px; overflow: ' .. overflow .. '"><div style="width: 120px; height: 80px"></div></div><div style="height: 10px"></div>')
		local height, width = arrange(tree, 50)
		local box = tree.Children[1]
		assert(box.Gui.Size[2] == 20 and tree.Children[2].Gui.Position[2] == 20, "Overflow cannot displace following blocks")
		if overflow=="hidden"then
			local clip=assert(box.ClipContent)
			assert(clip.ClipsDescendants and clip.Parent==box.Gui and box.Children[1].Gui.Parent==clip,
				"The ancestor content host clips the overflowing child")
			assert(clip.Size[1]==40 and clip.Size[2]==20 and box.Children[1].OuterWidth==120 and box.Children[1].OuterHeight==80,
				"The clip region retains the constrained border box while the child lays out its full size")
		else
			assert(not box.ClipContent and box.Children[1].Gui.Parent==box.Gui,"Visible overflow stays in the ordinary content host")
		end
		assert(box.Children[1].Gui.ClipsDescendants == false, "Clipping is not inherited; the ancestor clips its descendants")
		assert(height == (if overflow == "hidden" then 30 else 80))
		assert(width == (if overflow == "hidden" then 50 else 120), "Hidden overflow cannot expand the page canvas")
	end
	local dynamic = build('<style>#clip{overflow:hidden}#clip:hover{overflow:visible}</style><div id="clip" style="width:40px;max-height:20px"><div style="width:120px;height:80px"></div></div><div style="height:10px"></div>')
	arrange(dynamic,50)
	local box,after=dynamic.Children[1],dynamic.Children[2]
	local gui,clip,content=box.Gui,assert(box.ClipContent),box.Children[1].Gui
	local function checkDynamic(hidden)
		local height,width=arrange(dynamic,50)
		assert(box.Gui==gui and box.ClipContent==clip and content==box.Children[1].Gui
			and clip.Parent==gui and content.Parent==clip,'Overflow changes retain the native hosts and descendant parent')
		assert(clip.ClipsDescendants==hidden and clip.Size[1]==40 and clip.Size[2]==20)
		assert(content.Size[1]==120 and content.Size[2]==80,'Toggling clipping preserves the complete child layout')
		assert(height==(if hidden then 30 else 80) and width==(if hidden then 50 else 120),
			'Dynamic overflow updates the page canvas to match the clipping state')
		assert(box.OuterHeight==20 and after.Gui.Position[2]==20 and after.OuterHeight==10,
			'Changing overflow preserves the constrained box and following sibling flow')
	end
	checkDynamic(true)
	for _,active in {true,false}do
		local changed,needsLayout=dynamic:SetCSSState('hover',if active then box.Node else nil)
		assert(changed and needsLayout);checkDynamic(not active)
	end
	for _,overflow in {'visible','hidden'}do
		box.Node.Attributes.style='width:40px;max-height:20px;overflow:'..overflow
		assert(dynamic:ApplyDOMChanges({[box.Node]={Attributes={style=true}}}))
		checkDynamic(overflow=='hidden')
	end
	local paddedOverflow = build('<div style="padding: 10px"><div style="padding: 10px"><div style="width: 120px; height: 1px"></div></div></div>')
	local _, paddedWidth = arrange(paddedOverflow, 100)
	assert(paddedWidth == 140, "Nested boxes add their leading padding before overflow without appending trailing padding after it")
	local flexOverflow = build('<div style="display: flex; padding: 10px"><div style="min-width: 120px; height: 1px"></div></div>')
	local _, flexWidth = arrange(flexOverflow, 100)
	assert(flexWidth == 130, "Flex overflow ends at the outermost item instead of adding trailing padding beyond it")
	local objectFallback = build('<style>object { display: block; box-sizing: border-box; width: 340px; height: 96px } .fallback-object { width: 100%; padding: 18px; border: 1px solid }</style><section style="padding: 24px"><object class="fallback-object" data="unsupported.demo" type="application/x-unsupported"><div>Fallback content is active.</div></object></section>')
	arrange(objectFallback, 500)
	local fallbackObject = objectFallback.Children[1].Children[1]
	assert(fallbackObject.OuterWidth == 452, "An unsupported object lays out its fallback subtree at the cascading percentage width")
	local nested = build('<div style="height: 40px; overflow: hidden"><div style="height: 10px; overflow: visible"><div style="height: 100px"></div></div></div>')
	assert(arrange(nested) == 40, "An outer clip caps all nested visible overflow")
	local autoParent = build('<div><div style="height: 10px"><div style="height: 100px"></div></div><div style="height: 5px"></div></div>')
	assert(arrange(autoParent) == 100 and autoParent.Children[1].Gui.Size[2] == 15, "Auto parent height follows boxes, while the canvas follows visible overflow")
	local zero = build('<div style="max-height: 0; overflow: hidden"><div style="height: 100px"></div></div>')
	assert(arrange(zero) == 0)
	local cascade = build('<style>div {overflow: hidden !important; min-height: 30px !important; max-height: 40px}</style><div style="overflow: visible; min-height: 5px; height: 100px"></div>')
	assert(arrange(cascade) == 40)
	local cascadeBox=cascade.Children[1]
	assert(cascadeBox.ClipContent and cascadeBox.ClipContent.ClipsDescendants and cascadeBox.ClipContent.Parent==cascadeBox.Gui
		and cascadeBox.ClipContent.Size[1]==cascadeBox.OuterWidth and cascadeBox.ClipContent.Size[2]==40)
	local reflow = build('<div style="min-height: 10px; max-height: 20px; overflow: hidden; line-height: 10px">AA BB CC</div>')
	assert(arrange(reflow, 100) == 10)
	local clip=reflow.Children[1].ClipContent
	assert(clip and clip.ClipsDescendants and clip.Parent==reflow.Children[1].Gui and clip.Size[1]==100 and clip.Size[2]==10)
	local count = requests
	assert(arrange(reflow, 20) == 20 and requests == count, "Height limits reflow without repeating text measurements")
	assert(reflow.Children[1].ClipContent==clip and clip.Size[1]==20 and clip.Size[2]==20,"Resize retains the content host and updates its clip bounds")
	for _,item in reflow.Children[1].Children[1].Items do if item.Gui then assert(item.Gui.Parent==clip)end end
	assert(reflow.Children[1].Children[1].Items[3].LineIndex == 3, "Clipped content is still laid out completely")
	local position = reflow.Children[1].Gui.Position
	assert(block.arrange(reflow, 10, 0, 0, function() return false end) == 0 and reflow.Children[1].Gui.Position == position)
	print("Overflow: height limits, box sizing, cascade, clipping, visible extent, nested/sibling flow, zero height, reflow reuse and cancellation passed")
end
