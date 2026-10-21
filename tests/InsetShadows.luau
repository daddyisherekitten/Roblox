--!strict
return function(Parser, Style, Pixels, Insets, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local base = {Font = "Inter", FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function resolve(value, extra)
		return Style.resolve(fixtureElement("div",{style = "box-shadow: " .. value .. "; " .. (extra or "")}), base, error, false)
	end
	for _, value in {"inset 3px 4px red", "3px 4px inset red", "red inset 3px 4px", "3px 4px red inset"} do
		local record = resolve(value).BoxShadows[1]
		assert(record.Inset and record.X == 3 and record.Y == 4)
	end
	assert(not resolve("3px 4px red").BoxShadows[1].Inset)
	local invalid = 0
	Style.resolve(fixtureElement("div",{style = "box-shadow: 3px inset 4px"}), base, function() invalid += 1 end, false)
	assert(invalid == 1, "Inset cannot split the length group")
	local function render(value, extra, width, height)
		local style = resolve(value, extra)
		local plan = Pixels.plan(width or 20, height or 20, style)
		return Pixels.render(width or 20, height or 20, style, plan), plan
	end
	local function alpha(data, plan, x, y) return buffer.readu8(data, (y * plan.Width + x) * 4 + 3) end
	local hard, p = render("inset 3px 4px red")
	assert(alpha(hard, p, 10, 1) == 255 and alpha(hard, p, 1, 10) == 255)
	assert(alpha(hard, p, 10, 10) == 0 and alpha(hard, p, 19, 19) == 0)
	local negative, np = render("inset -3px -4px red")
	assert(alpha(negative, np, 1, 1) == 0 and alpha(negative, np, 19, 19) == 255)
	local zero, zp = render("inset 0 0 black", "border-radius: 6px")
	for offset = 3, buffer.len(zero) - 1, 4 do assert(buffer.readu8(zero, offset) == 0, "Zero inset must not leave a dark antialiased outline") end
	local spread, sp = render("inset 0 0 0 3px black")
	assert(alpha(spread, sp, 1, 10) == 255 and alpha(spread, sp, 10, 10) == 0)
	local expanded, ep = render("inset 0 0 0 -3px black")
	assert(alpha(expanded, ep, 1, 10) == 0 and alpha(expanded, ep, 19, 19) == 0)
	local soft, bp = render("inset 0 0 8px black")
	assert(alpha(soft, bp, 10, 0) > 50 and alpha(soft, bp, 10, 0) < 200)
	assert(alpha(soft, bp, 10, 10) < alpha(soft, bp, 10, 0), "Soft shadow fades toward the interior")
	local tiny, tp = render("inset 0 0 1px black")
	assert(alpha(tiny, tp, 10, 0) > 0 and alpha(tiny, tp, 10, 10) == 0, "Small positive blur retains an edge fade")
	local rounded, rp = render("inset 0 0 0 50px black", "border: 2px solid red; border-radius: 6px")
	assert(alpha(rounded, rp, 0, 10) == 0 and alpha(rounded, rp, 2, 2) == 0)
	assert(alpha(rounded, rp, 2, 10) == 255 and alpha(rounded, rp, 10, 10) == 255, "Inset is clipped to the rounded padding box, excluding the border")
	local layers, lp = render("inset 0 0 0 50px rgba(255,0,0,.5), inset 0 0 0 50px rgba(0,0,255,.5), 0 0 green")
	local center = (10 * lp.Width + 10) * 4
	assert(math.abs(buffer.readu8(layers, center) - 170) <= 1 and math.abs(buffer.readu8(layers, center + 2) - 85) <= 1)
	assert(math.abs(buffer.readu8(layers, center + 3) - 192) <= 1, "First CSS inset composites in front; outer shadows are excluded")
	local huge = Pixels.plan(10000, 10000, resolve("inset 0 0 1000px black"))
	assert(huge.Width <= 1024 and huge.Height <= 1024 and huge.Width * huge.Height <= 262144 and huge.Scale < 1)
	local created, warnings = {}, {}
	local function create(size)
		local image = {Size = size, Writes = 0, DestroyCalls = 0}
		function image:WritePixelsBuffer(_, dimensions, data)
			assert(dimensions.X == size.X and dimensions.Y == size.Y and buffer.len(data) == size.X * size.Y * 4)
			self.Writes += 1
		end
		function image:Destroy() self.DestroyCalls += 1 end
		table.insert(created, image); return image
	end
	local renderer = Insets.new(function(m) table.insert(warnings, m) end, create)
	local box = {Gui = {}, Style = resolve("inset 3px 4px black")}
	renderer:Draw(box, 20, 20)
	assert(#created == 1 and created[1].Writes == 1 and box.Gui.ImageTransparency == 0)
	renderer:Draw(box, 20, 20)
	assert(created[1].Writes == 1, "Unchanged geometry never regenerates pixels")
	box.Style = resolve("inset 2px 4px red")
	renderer:Draw(box, 20, 20)
	assert(#created == 1 and created[1].Writes == 2, "Same image dimensions reuse the allocation after a style change")
	renderer:Draw(box, 30, 20)
	assert(#created == 2 and created[1].DestroyCalls == 1 and created[2].Writes == 1)
	renderer:Draw(box, 0, 20)
	assert(created[2].DestroyCalls == 1 and box.Gui.ImageTransparency == 1)
	renderer:Draw(box, 30, 20)
	assert(#created == 3)
	renderer:Destroy(); renderer:Destroy(); renderer:Draw(box, 40, 20)
	assert(created[3].DestroyCalls == 1 and #created == 3)
	local attempts = 0
	local unavailable = Insets.new(function(m) table.insert(warnings, m) end, function() attempts += 1; return nil end)
	unavailable:Draw(box, 20, 20); unavailable:Draw(box, 30, 20)
	assert(attempts == 1 and #warnings == 1 and box.Gui.ImageTransparency == 1)
	local faulty = Insets.new(function() end, function(size)
		local image = create(size); function image:WritePixelsBuffer() error("write failed") end; return image
	end)
	faulty:Draw(box, 20, 20)
	assert(created[#created].DestroyCalls == 1)
	local modifiers, calls = {}, 0
	local factory = {create = function(class, parent, props)
		local gui = table.clone(props); gui.ClassName, gui.Parent = class, parent; return gui
	end, modifier = function(class, parent, props)
		local gui = table.clone(props); gui.ClassName, gui.Parent = class, parent; table.insert(modifiers, gui); return gui
	end}
	local live = Insets.new(error, create)
	local tree = loadRenderTree(factory).build(Parser.parse('<div style="border: 2px solid red; border-radius: 8px; box-shadow: inset 2px 4px 8px black, 2px 3px red; padding: 10px">AA BB CC</div>'), {}, error, nil, nil, live)
	local card = tree.Children[1]
	assert(card.Gui.ClassName == "ImageLabel" and card.InsetRenderer == live and card.Children[1].Items[1].Gui.Parent == card.Gui)
	assert(#modifiers == 3 and modifiers[2].ClassName == "UIShadow" and modifiers[2].ZIndex == -2, "Only outer layers allocate UIShadow")
	local word = loadWordLayout({["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size) calls += 1; return {X = if text == " " then 5 else 20, Y = size} end}})
	local block = loadBlockLayout({["Layout/WordLayout"] = word})
	local height = block.arrange(tree, 100, 0, 0, function() return true end)
	local count, measures, image = #created, calls, created[#created]
	assert(card.Gui.ImageTransparency == 0 and image.Writes == 1)
	assert(block.arrange(tree, 100, 0, 0, function() return true end) == height and #created == count and calls == measures and image.Writes == 1)
	block.arrange(tree, 70, 0, 0, function() return true end)
	assert(calls == measures and image.DestroyCalls == 1 and #created == count + 1 and #modifiers == 3)
	live:Destroy()
	for _, image in created do assert(image.DestroyCalls == 1) end
	print("Inset shadows: CSS, directional masks/blur, rounded padding clip, compositing, resize reuse and image cleanup/failure passed")
end
