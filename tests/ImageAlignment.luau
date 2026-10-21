--!strict
return function(Parser, Style, Metrics, loadRenderTree, loadWordLayout)
 local fixtureElement=require('DOM/Node').element
	local created, modifiers, requests = {}, {}, 0
	local factory = {
		create = function(class, parent, props)
			local gui = table.clone(props); gui.ClassName, gui.Parent = class, parent
			table.insert(created, gui); return gui
		end,
		modifier = function(class, parent, props)
			local gui = table.clone(props); gui.ClassName, gui.Parent = class, parent
			table.insert(modifiers, gui); return gui
		end,
	}
	local renderer = loadRenderTree(factory)
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			requests += 1; return {X = if text == " " then 5 else 20, Y = size}
		end},
	})
	local function build(content, css)
		return renderer.build(Parser.parse('<p style="font-size: 20px; line-height: 40px; ' .. (css or '') .. '">' .. content .. '</p>'), {}, function(message) error(message) end,
			nil, nil, nil, function() return "rbxassetid://15773523297" end).Children[1].Children[1]
	end
	local function img(css, height)
		return '<img src="landschaft.png" alt="Bild" width="30" height="' .. (height or 24) .. '" style="' .. css .. '">'
	end
	local function arrange(run, width) return layout.arrange(run, width or 600, 0, 0, function() return true end) end
	local function near(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. " != " .. tostring(b)) end
	for _, align in {"baseline", "middle", "text-top", "text-bottom", "top", "bottom", "super", "sub", "5px", "-5px", "25%"} do
		local run = build('Hxp ' .. img('vertical-align: ' .. align .. '; font-size: 50px') .. ' Hxp')
		local height = arrange(run)
		local text, image = run.Items[1], run.Items[2]
		local baseline = text.Y + text.Baseline
		local parent = Metrics.resolve(run.Style)
		if align == "baseline" then near(image.Y + image.Height, baseline)
		elseif align == "middle" then near(image.Y + image.Height / 2, baseline - (parent.Baseline - parent.XHeight) / 2)
		elseif align == "text-top" then near(image.Y, text.Y)
		elseif align == "text-bottom" then near(image.Y + image.Height, text.Y + parent.TextSize)
		elseif align == "top" then near(image.Y, 0)
		elseif align == "bottom" then near(image.Y + image.Height, height)
		elseif align == "super" then assert(image.Y + image.Height < baseline)
		elseif align == "sub" then assert(image.Y + image.Height > baseline)
		elseif align == "5px" then near(image.Y + image.Height, baseline - 5)
		elseif align == "-5px" then near(image.Y + image.Height, baseline + 5)
		elseif align == "25%" then near(image.Y + image.Height, baseline - 10) end
	end
	local topBottom = build(img('vertical-align: top', 100) .. img('vertical-align: bottom', 90) .. ' Hxp')
	near(arrange(topBottom), 100)
	near(topBottom.Items[1].Y, 0); near(topBottom.Items[2].Y, 10)
	local resizeCount, allocationCount = requests, #created
	near(arrange(topBottom, 30), 230) -- separate 100px/90px image lines, then a 40px text line
	near(topBottom.Items[1].Y, 0); near(topBottom.Items[2].Y, 100)
	near(arrange(topBottom), 100)
	assert(requests == resizeCount and #created == allocationCount, "Changing widths reuses measurements and image boxes")
	local tall = build(img('vertical-align: top', 80) .. '<br>' .. img('vertical-align: bottom', 10))
	near(arrange(tall), 120)
	near(tall.Items[3].Y, 110)
	local boxed = build('AA ' .. img('margin: 3px 4px 5px 6px; padding: 7px 8px 9px 10px; border: 2px solid red; border-radius: 12px; background: blue') .. ' BB')
	arrange(boxed)
	local image = boxed.Items[2]
	assert(image.ContentWidth == 30 and image.ContentHeight == 24)
	assert(image.BoxWidth == 52 and image.BoxHeight == 44 and image.Width == 62 and image.Height == 52)
	assert(image.X == 25 and boxed.Items[3].X == 92, "Both horizontal margins join the inline advance exactly once")
	assert(image.BoxGui.Position[1] == 6 and image.BoxGui.Position[2] == 3)
	assert(image.ImageGui.Position[1] == 12 and image.ImageGui.Position[2] == 9)
	assert(image.ImageGui.Size[1] == 30 and image.ImageGui.Size[2] == 24)
	assert(image.ErrorGui.Size[1]==16 and image.ErrorGui.Size[2]==16)
	assert(image.FallbackGui.Position[1]+image.ErrorGui.Position[1]==12)
	assert(image.FallbackGui.Position[2]+image.ErrorGui.Position[2]==9,"Error content starts inside the CSS padding")
	assert(image.FallbackGui.ClipsDescendants and image.AltGui.Position[1]==26)
	local errorIcon = image.ErrorGui
	arrange(boxed, 100)
	assert(image.ErrorGui==errorIcon and errorIcon.Size[1]==16 and errorIcon.Size[2]==16,"Reflow reuses the icon at fixed pixel size")
	arrange(boxed)
	assert(image.BoxCorner.Parent == image.BoxGui and image.ImageCorner.Parent == image.ImageGui)
	assert(image.Gui.BackgroundColor3 == nil and image.BoxGui.BackgroundColor3 == Color3.fromRGB(0, 0, 255))
	for _, modifier in modifiers do
		if modifier.Parent == image.BoxGui and modifier.ClassName == "UIStroke" then assert(modifier.LineJoinMode == Enum.LineJoinMode.Round) end
	end
	local square = build(img('border: 2px solid red'))
	arrange(square)
	for _, modifier in modifiers do
		if modifier.Parent == square.Items[1].BoxGui and modifier.ClassName == "UIStroke" then assert(modifier.LineJoinMode == Enum.LineJoinMode.Miter) end
	end
	local uniform = build(img('padding: 3px; border: 2px solid red; border-radius: 12px'))
	arrange(uniform)
	assert(uniform.Items[1].ImageCorner.CornerRadius.Offset == 7)
	local borderBox = build(img('width: 100px; height: 60px; box-sizing: border-box; padding: 5px; border: 2px solid red; margin: 3px'))
	arrange(borderBox)
	image = borderBox.Items[1]
	assert(image.BoxWidth == 100 and image.BoxHeight == 60 and image.ContentWidth == 86 and image.ContentHeight == 46)
	assert(image.Width == 106 and image.Height == 66)
	local minimum = build(img('width: 0; height: 0; box-sizing: border-box; padding: 5px; border: 2px solid red'))
	arrange(minimum)
	assert(minimum.Items[1].BoxWidth == 14 and minimum.Items[1].ContentWidth == 0 and minimum.Items[1].Gui.Visible)
	local ratio = build('<img src="landschaft.png" width="400" height="200" style="width: 100%; max-width: 200px; height: auto; padding: 5px; border: 2px solid red; box-sizing: border-box">')
	arrange(ratio, 300)
	assert(ratio.Items[1].BoxWidth == 200 and ratio.Items[1].ContentWidth == 186 and ratio.Items[1].ContentHeight == 93)
	local inset = build(img('border: 2px inset red'))
	arrange(inset)
	assert(#inset.Items[1].BorderEdges == 4 and inset.Items[1].BorderEdges[1].Size[1] == 34)
	local decorated = build('AA ' .. img('vertical-align: middle; margin: 4px') .. ' BB', 'text-decoration: underline')
	arrange(decorated)
	image = decorated.Items[2]
	local firstLine = decorated.Items[1].DecorationFrames[1]
	local gapLine = image.DecorationFrames[1]
	near(decorated.Items[1].Y + firstLine.Position[2], image.Y + gapLine.Position[2])
	local warnings = 0
	local parent = {FontSize = 20, Font = "Arial", Color = Color3.new(0, 0, 0)}
	for _, value in {"-+2px", "--2px", "auto"} do
		local resolved = Style.resolve(fixtureElement("img",{style = 'vertical-align: middle; vertical-align: ' .. value}), parent, function() warnings += 1 end, true)
		assert(resolved.VerticalAlign == "middle")
	end
	assert(warnings == 3)
	local fontShift=Style.resolve(fixtureElement('img',{style='vertical-align:1ex'}),parent,error,true);assert(type(fontShift.VerticalAlign)=='table'and fontShift.VerticalAlign.Value==10,'Shared font-relative vertical alignment')
	local inherited = Style.resolve(fixtureElement("img",{}), {FontSize = 20, Font = "Arial", Color = parent.Color, VerticalAlign = "top"}, error, true)
	assert(inherited.VerticalAlign == "baseline", "vertical-align is not inherited")
	print("Image alignment/boxes: baseline/font/line edges, px/percent shifts, mixed lines, reflow, margins, padding, sizing, corners and borders passed")
end
