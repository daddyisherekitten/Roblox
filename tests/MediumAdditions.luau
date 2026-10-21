--!strict
return function(Parser, Style, Properties, loadRenderTree, loadWordLayout, loadBlockLayout, demoHTML)
 local fixtureElement=require('DOM/Node').element
	local propertyCount = 0
	for name, entry in Properties do
		propertyCount += 1
		assert(entry.Support == "supported", name .. " must be classified for the Roblox CSS profile")
	end
	assert(propertyCount == 536, "The documented Roblox CSS property catalog must stay in sync")
	local function resolve(css, parent, name)
		return Style.resolve(fixtureElement(name or "div",{style = css}), parent or {Font = "Roboto", FontSize = 20, Color = Color3.new(0, 0, 0)}, error)
	end
	local visual=resolve("accent-color:#c026d3;image-rendering:pixelated;scrollbar-color:#123456 #abcdef;scrollbar-width:thin;text-justify:none;text-underline-position:under")
	assert(visual.AccentColor==Color3.fromRGB(192,38,211) and visual.ImageRendering=="pixelated" and visual.ScrollbarWidth=="thin")
	assert(visual.ScrollbarColor.Thumb==Color3.fromRGB(18,52,86) and visual.ScrollbarColor.Track==Color3.fromRGB(171,205,239))
	assert(visual.TextJustify=="none" and visual.UnderlinePosition=="under")
	local separated=resolve("white-space:pre;white-space-collapse:collapse;text-wrap-mode:wrap;text-wrap-style:stable")
	assert(separated.WhiteSpace=="normal" and separated.WhiteSpaceCollapse=="collapse" and separated.TextWrapMode=="wrap" and separated.TextWrapStyle=="stable")
	local shorthand=resolve("text-wrap:nowrap stable",separated)
	assert(shorthand.TextWrapMode=="nowrap" and shorthand.TextWrapStyle=="stable" and shorthand.WhiteSpace=="nowrap")
	assert(resolve("list-style-image:url('marker.png')").ListStyleImage=="marker.png" and resolve("list-style-image:none").ListStyleImage==nil)
	local logical=resolve("direction:rtl;margin-inline:3px 7px;padding-block:5px 9px;inset-inline-start:11px;border-inline-end:4px solid red;pointer-events:none;user-select:none;touch-action:pan-x")
	assert(logical.Margin[2]==3 and logical.Margin[4]==7 and logical.Padding[1]==5 and logical.Padding[3]==9)
	assert(logical.Insetright.Value==11 and logical.BorderSides[4].Width==4 and logical.PointerEvents=="none" and logical.UserSelect=="none" and logical.TouchAction=="pan-x")
	local radii=resolve("border-radius:20px 10% / 8px 30%;border-bottom-left-radius:4px 9px")
	assert(radii.BorderRadii and radii.BorderRadii[1].X.Value==20 and radii.BorderRadii[2].X.Percent and radii.BorderRadii[4].X.Value==4 and radii.BorderRadii[4].Y.Value==9)
	local logicalBox=resolve("direction:rtl;inline-size:180px;block-size:70px;min-inline-size:90px;max-block-size:120px;overflow-inline:auto;overflow-block:hidden;border-start-start-radius:12px 7px;border-end-end-radius:5px")
	assert(logicalBox.Width.Value==180 and logicalBox.Height.Value==70 and logicalBox.MinWidth.Value==90 and logicalBox.MaxHeight.Value==120)
	assert(logicalBox.OverflowX=="auto" and logicalBox.OverflowY=="hidden")
	assert(logicalBox.BorderRadii and logicalBox.BorderRadii[2].X.Value==12 and logicalBox.BorderRadii[2].Y.Value==7 and logicalBox.BorderRadii[4].X.Value==5)
	local logicalBorders=resolve("direction:rtl;border-inline-width:2px 5px;border-inline-style:dashed solid;border-inline-color:red blue;border-block-start-width:7px;border-block-end-style:double")
	assert(logicalBorders.BorderSides[2].Width==2 and logicalBorders.BorderSides[4].Width==5)
	assert(logicalBorders.BorderSides[2].Style=="dashed" and logicalBorders.BorderSides[4].Style=="solid" and logicalBorders.BorderSides[3].Style=="double")
	assert(logicalBorders.BorderSides[2].Color==Color3.new(1,0,0) and logicalBorders.BorderSides[4].Color==Color3.new(0,0,1) and logicalBorders.BorderSides[1].Width==7)
	assert(resolve("position:fixed;display:inline-flex").Position=="fixed" and resolve("position:sticky;display:contents").Display=="contents")
	local parent = resolve("font: italic bold 24px/1.5 'Roboto Mono'; margin: 4px auto 8%; padding: 5%; border: 2px solid red; border-left: 7px dashed blue; opacity: .5")
	assert(parent.Font == "Roboto Mono" and parent.FontSize == 24 and parent.FontWeight == 700 and parent.LineHeight.Value == 1.5)
	local inherited = resolve("font: inherit; margin: inherit; padding-left: inherit; border: inherit; opacity:inherit", parent)
	assert(inherited.Font == parent.Font and inherited.FontSize == 24 and inherited.FontWeight == 700)
	assert(inherited.MarginAuto[2] and inherited.Margin[3].Value == 8 and inherited.Padding[4].Value == 5)
	assert(inherited.BorderSides[4].Width == 7 and inherited.BorderSides[4].Style == "dashed" and inherited.Opacity == .5)
	local reset = resolve("margin:9px; margin:initial; padding:9px; padding:unset; font:initial; border:initial; color:initial; display:initial; opacity:unset", parent, "h1")
	assert(reset.Margin[1] == 0 and reset.Padding[1] == 0 and reset.FontSize == 16 and reset.FontWeight == 400 and reset.Display == "inline" and reset.Opacity == 1)
	assert(resolve("font: 20px Roboto; font-weight:bold; font:18px/25px Inter").FontWeight == 400)
	assert(resolve("font: italic 20px/150% Roboto; font-size:30px").LineHeight.Value == 45)
	assert(resolve("list-style:upper-alpha inside;list-style:outside").ListStyleType == "disc")
	assert(resolve("opacity:150%").Opacity == 1 and resolve("opacity:-.5").Opacity == 0)
	-- Every catalog entry accepts each CSS-wide keyword, including nullable fields and shortforms.
	for key in Properties do
		for _, keyword in {"initial", "inherit", "unset", "revert", "revert-layer"} do resolve(key .. ":" .. keyword, parent) end
	end
	local allocations, measures = 0, 0
	local function create(class, host, props)
		allocations += 1
		local gui = table.clone(props); gui.Parent, gui.ClassName = host, class
		function gui:Destroy() self.Destroyed = true end
		return gui
	end
	local measure = {measure = function(text, _, size)
		measures += 1
		local count = utf8.len(text)
		return {X = count * 5, Y = size}
	end}
	local overrides = {["Layout/TextMeasure"] = measure, ["Layout/FontProfiles"] = {face = function(font) return font end}}
	local words = loadWordLayout(overrides)
	overrides["Layout/WordLayout"] = words
	local blocks, renderer = loadBlockLayout(overrides), loadRenderTree({create = create, modifier = create})
	local function build(html)
		return renderer.build(Parser.parse('<div style="font-family:Roboto;font-size:20px;line-height:20px">' .. html .. '</div>'), {}, error,
			function(font) return font end, nil, nil, function() return "rbxassetid://1" end)
	end
	local function arrange(tree, width) return blocks.arrange(tree, width, 0, 0, function() return true end) end
	local tree = build('AB<wbr>CD')
	arrange(tree, 12)
	local run = tree.Children[1].Children[1]
	assert(#run.Items == 2 and run.Items[1].Text == "AB" and run.Items[2].LineIndex == 2 and not run.Items[2].SpaceBefore)
	arrange(tree, 50); assert(run.Items[2].X == 10)
	local nowrap = build('<div style="white-space:nowrap">AB<wbr>CD</div>')
	arrange(nowrap, 12); assert(nowrap.Children[1].Children[1].Children[1].Items[2].LineIndex == 1)
	for mode, first in {["word-break:break-all"] = "CD", ["overflow-wrap:anywhere"] = "CDEF"} do
		local t = build('<div style="' .. mode .. '">AB CDEF</div>'); arrange(t, 25)
		local r = t.Children[1].Children[1].Children[1]
		local items = r.DisplayItems or r.Items
		assert(items[2].Text == first, mode)
		if mode == "word-break:break-all" then assert(items[2].LineIndex == 1 and items[3].LineIndex == 2) end
		assert(blocks.naturalWidth(r, 25, function() return true end, true) == 5)
	end
	local spaced = build('<div style="padding:10%;margin:5%"><div style="height:10px;margin-bottom:-4px"></div><div style="height:10px;margin-top:2px"></div></div>')
	arrange(spaced, 200)
	local outer = spaced.Children[1].Children[1]
	assert(outer.Style.Margin[1] == 10 and outer.Style.Padding[1] == 20 and outer.ContentWidth == 140)
	assert(outer.Children[2].LayoutY == 28, "Positive/negative adjoining margins sum; they do not double")
	arrange(spaced, 100); assert(outer.Style.Margin[1] == 5 and outer.Style.Padding[1] == 10)
	arrange(spaced, 200); assert(outer.Style.Padding[1] == 20)
	local inside = build('<ol style="margin:0;padding:0;list-style:upper-alpha inside"><li>AB CD EF</li><li><div>Next</div></li></ol>')
	arrange(inside, 30)
	local list = inside.Children[1].Children[1]
	local firstRun = list.Children[1].Children[1]
	assert(firstRun.Items[1].Kind == "Marker" and list.Children[1].Marker.Text == "A. ")
	assert(firstRun.Items[2].X == 15 and firstRun.Items[3].X == 0, "Only the first line reserves marker width")
	assert(list.Children[2].Children[1].Items[1].Kind == "Marker", "A block child starts below the inside marker line")
	local imageList = build('<ul style="list-style-image:url(marker.png);image-rendering:pixelated"><li>Image marker</li></ul>')
	arrange(imageList, 200)
	local imageMarker = imageList.Children[1].Children[1].Children[1].Marker
	assert(imageMarker and imageMarker.Kind == "image" and imageMarker.Gui.ClassName == "ImageLabel")
	local missingImageList = renderer.build(Parser.parse('<ul style="list-style-type:none;list-style-image:url(missing.png)"><li>Missing marker</li></ul>'), {}, error,
		function(font) return font end, nil, nil, nil)
	arrange(missingImageList, 200)
	assert(missingImageList.Children[1].Children[1].Marker == nil, "An unresolved image with a none fallback must not create a marker")
	local images = build('<img id="block" src="scene" width="80" height="40" style="display:block;margin:5px auto"><div style="display:flex;gap:10px"><img src="scene" width="40" height="20" style="flex:1;min-width:0"><img src="scene" width="40" height="20" style="flex:1;min-width:0"></div>')
	arrange(images, 200)
	local image = images.Children[1].Children[1]
	assert(image.Kind == "BlockImage" and image.OuterWidth == 80 and image.OuterHeight == 40 and image.LayoutX == 60)
	local flex = images.Children[1].Children[2]
	assert(#flex.Children == 2 and flex.Children[1].OuterWidth == 95 and flex.Children[2].LayoutX == 105)
	local imageStyle, flexStyle = image.ImageItem.Style, flex.Children[1].ImageItem.Style
	local n = allocations; arrange(images, 120); arrange(images, 200); assert(allocations == n)
	assert(image.ImageItem.Style == imageStyle and flex.Children[1].ImageItem.Style == flexStyle,
		"Image styles retain their identity for border atlas reuse")
	assert(blocks.naturalWidth(flex.Children[1], 200, function() return true end) == 40,
		"Intrinsic image measurement clears the previous flex size override")
	arrange(images, 200); assert(flex.Children[1].OuterWidth == 95)
	local transparent = build('<div style="opacity:.5;background:red;padding:5px"><div style="opacity:.5;background:blue">AB</div><span style="opacity:.5">CD <b>EF</b></span><img src="scene" width="30" height="20" style="opacity:.5"></div>')
	arrange(transparent, 100)
	local group = transparent.Children[1].Children[1]
	assert(group.OpacityGroup.Gui.GroupTransparency == .5 and group.Children[1].OpacityGroup.Gui.GroupTransparency == .5)
	assert(group.Gui.Parent == group.OpacityGroup.Content and group.Children[1].Gui.Parent == group.Children[1].OpacityGroup.Content)
	assert(#group.InlineOpacityGroups == 1 and #group.InlineOpacityGroups[1].Members == 2)
	local count = allocations; arrange(transparent, 60); arrange(transparent, 100); assert(allocations == count)
	local wrappedOpacity = build('<span style="opacity:.5;letter-spacing:1px;word-break:break-all">ABCDEFGHIJ</span>')
	for _, width in {20, 35, 20, 35, 20, 35} do arrange(wrappedOpacity, width) end
	local wrappedGroup = wrappedOpacity.Children[1].InlineOpacityGroups[1]
	for _, member in wrappedGroup.Members do
		assert(not member.Gui.Destroyed, "Replaced glyph fragments must leave their opacity group")
	end
	local aligned = build('<div style="overflow:auto;white-space:nowrap;text-overflow:ellipsis;text-align:right">AB CD</div>')
	arrange(aligned, 100)
	local alignedRun = aligned.Children[1].Children[1].Children[1]
	local paintedX = alignedRun.Items[1].X
	assert(paintedX > 0)
	blocks.naturalWidth(alignedRun, 100, function() return true end)
	assert(words.repaint(alignedRun, function() return true end))
	assert(alignedRun.DisplayItems[1].X == paintedX,
		"Intrinsic probes must not change the cached line positions used by scroll repaint")
	local scroll = build('<div style="overflow:auto;white-space:nowrap;text-overflow:ellipsis">ABCDEFGHIJ</div>')
	arrange(scroll, 25)
	local scroller = scroll.Children[1].Children[1]
	local text = scroller.Children[1]
	assert(text.EllipsisPool[1].Gui.Visible and scroller.ScrollRight == 50)
	scroller.ScrollGui.CanvasPosition = Vector2.new(25, 0); assert(words.repaint(text, function() return true end))
	assert(not text.EllipsisPool[1].Gui.Visible and text.Items[1].Gui.Visible and scroller.ScrollRight == 50)
	text.Items[1].Gui.ZIndex = 7
	scroller.ScrollGui.CanvasPosition = Vector2.new(10, 0); assert(words.repaint(text, function() return true end))
	assert(text.EllipsisPool[1].Gui.Visible and text.EllipsisPool[1].X == 30)
	assert(text.Items[1].WrapPool[1].Gui.ZIndex == 7)
	local originalHeight, originalWidth, canvas = scroll.OuterHeight, scroller.ScrollRight, scroller.ScrollGui.CanvasSize
	local measuredBefore = measures
	for _, offset in {25, 10, 25, 10} do
		scroller.ScrollGui.CanvasPosition = Vector2.new(offset, 0)
		assert(words.repaint(text, function() return true end))
	end
	assert(measures == measuredBefore and scroll.OuterHeight == originalHeight and scroller.ScrollRight == originalWidth and scroller.ScrollGui.CanvasSize == canvas,
		"Cached scrolling preserves block sizes/canvas and reuses substring measurements")
	assert(not words.repaint(text, function() return false end), "Disposed pages cannot repaint")
	local demo = renderer.build(Parser.parse(demoHTML), {}, error, function(font) return font end, nil, nil, function() return "rbxassetid://1" end)
	for _, width in {480, 240, 800, 480} do
		local height = arrange(demo, width)
		assert(height > 0 and height < 20000, "The entire comparison page lays out at narrow and wide sizes")
	end
	print("Medium additions: wide values/shorthands, wbr, grapheme wrapping/min-content, signed/percentage spacing, inside markers, block/flex images, opacity groups and scrolling ellipsis passed")
end
