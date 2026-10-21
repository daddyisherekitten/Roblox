--!strict
return function(Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadTextDecoration: any)
 local fixtureElement=require('DOM/Node').element
	local parent = { Font = "Inter", FontSize = 20, Color = Color3.new(0, 0, 0) }
	local function resolve(name, css, inherited, warnings)
		return Style.resolve(fixtureElement(name,{ style = css }), inherited or parent, function(message)
			if warnings then table.insert(warnings, message) else error(message) end
		end, true)
	end
	assert(resolve("u", "").Decorations[1].Underline)
	assert(resolve("s", "").Decorations[1].Strike and resolve("del", "").Decorations[1].Strike)
	assert(#resolve("u", "text-decoration: none").Decorations == 0)
	for _, property in {"text-decoration", "text-decoration-line"} do
		local selected = resolve("span", property .. ": underline overline line-through").Decorations[1]
		assert(selected.Underline and selected.Overline and selected.Strike)
		assert(#resolve("u", property .. ": none").Decorations == 0)
		for _, invalid in {"overline overline", "overline none", "overline red blue", "blink", "spelling-error", "grammar-error", ""} do
			local warnings = {}
			local preserved = resolve("span", property .. ": overline; " .. property .. ": " .. invalid, nil, warnings)
			assert(preserved.Decorations[1].Overline and #warnings == 1)
		end
	end
	local components = "text-decoration-color: red; text-decoration-thickness: 3px; text-decoration-style: wavy; text-underline-offset: 9px; "
	local longhand = resolve("u", components .. "text-decoration-line: overline").Decorations[1]
	assert(longhand.Overline and not longhand.Underline and longhand.Style == "wavy" and longhand.Thickness == 3 and longhand.UnderlineOffset == 9)
	assert(longhand.Color == Color3.fromRGB(255, 0, 0))
	local shorthand = resolve("u", components .. "text-decoration: overline").Decorations[1]
	assert(shorthand.Style == "solid" and shorthand.Thickness == 1 and shorthand.Color == parent.Color and shorthand.UnderlineOffset == 9)
	local restored = resolve("u", components .. "text-decoration-line: none; text-decoration-line: overline").Decorations[1]
	assert(restored.Style == "wavy" and restored.Thickness == 3 and restored.Color == longhand.Color)
	assert(resolve("u", "text-decoration-line: overline !important; text-decoration: underline").Decorations[1].Overline)
	assert(resolve("u", "text-decoration: overline !important; text-decoration-line: underline").Decorations[1].Overline)
	local upperOrigin = resolve("span", "text-decoration-line: overline; font-size: 20px")
	local upperChild = resolve("span", "text-decoration-line: none; font-size: 40px", upperOrigin)
	assert(upperChild.Decorations == upperOrigin.Decorations, "Descendants cannot erase or reposition an ancestor overline")
	local otherOrigin = resolve("span", "text-decoration-line: overline; font-size: 40px", upperOrigin)
	assert(#otherOrigin.Decorations == 2 and otherOrigin.Decorations[2].OverlineOffset < otherOrigin.Decorations[1].OverlineOffset)
	local origin = resolve("u", "color: blue")
	local child = resolve("span", "text-decoration: none; color: red; font-size: 40px", origin)
	assert(child.Decorations == origin.Decorations and child.Decorations[1].Color == Color3.fromRGB(0, 0, 255))
	assert(child.Decorations[1].Thickness == origin.Decorations[1].Thickness, "Descendants preserve the originating line's color and thickness")
	for _, case in { {10, 1}, {40, 1}, {41, 2}, {61, 2}, {62, 3}, {81, 3}, {82, 4}, {100, 4} } do
		for _, font in { "Arial", "Source Sans Pro", "Ubuntu", "Roboto", "Roboto Condensed", "Roboto Mono", "Roboto Slab", "Inter", "Open Sans" } do
			for _, weight in { 400, 700 } do
				local css = "text-decoration: underline line-through; font-size: " .. case[1] .. "px; font-weight: " .. weight .. "; font-family: " .. font
				assert(resolve("span", css).Decorations[1].Thickness == case[2], "Shared size thresholds across fonts and weights")
				assert(resolve("span", css .. "; text-decoration-thickness: auto").Decorations[1].Thickness == case[2])
			end
		end
	end
	for _, case in { {1, 1}, {20, 1}, {21, 2}, {34, 2}, {35, 3}, {48, 3}, {49, 4}, {100, 7} } do
		for _, font in { "Arial", "Source Sans Pro", "Ubuntu", "Roboto", "Roboto Condensed", "Roboto Mono", "Roboto Slab", "Inter", "Open Sans" } do
			for _, weight in { 400, 700 } do
				local css = "font-size: " .. case[1] .. "px; font-family: " .. font .. "; font-weight: " .. weight
				assert(resolve("u", css).Decorations[1].UnderlineOffset == case[2], "Shared underline offset follows CSS size across fonts and weights")
			end
		end
	end
	assert(resolve("u", "font-size: 100px; text-decoration-thickness: 1px").Decorations[1].Thickness == 1)
	assert(resolve("u", "font-size: 100px; text-decoration-thickness: 1px; text-decoration-thickness: auto").Decorations[1].Thickness == 4)
	assert(resolve("u", "text-decoration-thickness: 2px").Decorations[1].Thickness == 2)
	assert(resolve("u", "text-decoration-thickness: 10%").Decorations[1].Thickness == 2)
	assert(resolve("u", "text-decoration-thickness: 0").Decorations[1].Thickness == 1)
	local scaledOrigin = resolve("u", "font-size: 41px")
	assert(resolve("span", "font-size: 100px", scaledOrigin).Decorations[1].Thickness == 2, "Propagated lines keep origin thickness")
	assert(resolve("span", "font-size: 100px", scaledOrigin).Decorations[1].UnderlineOffset == 3, "Propagated lines keep origin offset")
	for _, value in { "-1px", "-10%", "from-font", "invalid" } do
		local warnings = {}
		assert(resolve("u", "text-decoration-thickness: 2px; text-decoration-thickness: " .. value, nil, warnings).Decorations[1].Thickness == 2 and #warnings == 1, "Rejected thickness must preserve the earlier declaration: " .. value)
	end
	local both = resolve("span", "text-decoration: line-through underline").Decorations[1]
	assert(both.Underline and both.Strike and both.UnderlineOffset == 1)
	for _, value in { "blink", "underline none", "underline underline", "underline red blue", "" } do
		local warnings = {}
		assert(resolve("span", "text-decoration: underline; text-decoration: " .. value, nil, warnings).Decorations[1].Underline and #warnings == 1)
	end
	local red, blue = Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 255)
	assert(resolve("u", "color: blue; text-decoration-color: red").Decorations[1].Color == red)
	assert(resolve("u", "text-decoration-color: currentcolor; color: blue").Decorations[1].Color == blue)
	assert(resolve("u", "text-decoration-color: #f00").Decorations[1].Color == red)
	assert(resolve("u", "text-decoration-color: red; text-decoration: underline; color: blue").Decorations[1].Color == blue, "Shorthand resets decoration color")
	assert(resolve("u", "text-decoration-color: red !important; text-decoration: underline; color: blue").Decorations[1].Color == red)
	assert(resolve("u", "text-decoration: underline !important; text-decoration-color: red; color: blue").Decorations[1].Color == blue)
	assert(resolve("u", "text-decoration-thickness: 4px; text-decoration: underline").Decorations[1].Thickness == 1)
	assert(resolve("u", "text-underline-offset: 6px; text-decoration: underline").Decorations[1].UnderlineOffset == 6, "Shorthand does not reset offset")
	for _, case in {{"auto", 1}, {"0", 0}, {"6px", 6}, {"-3px", -3}, {"+.5px", 1}, {"15%", 3}, {"-10%", -2}} do
		local value = resolve("u", "text-underline-offset: " .. case[1]).Decorations[1]
		assert(value.UnderlineOffset == case[2] and value.StrikeOffset == -5)
	end
	assert(resolve("u", "text-underline-offset: 10%; font-size: 40px").Decorations[1].UnderlineOffset == 4)
	local percentParent = resolve("span", "text-underline-offset: 10%; text-decoration-color: red; color: blue")
	local percentChild = resolve("u", "font-size: 40px", percentParent)
	assert(percentChild.UnderlineOffset.Percent and percentChild.Decorations[1].UnderlineOffset == 4)
	assert(percentChild.Decorations[1].Color == blue, "Decoration color itself is not inherited")
	assert(resolve("u", "text-underline-offset: auto; font-size: 40px", percentParent).Decorations[1].UnderlineOffset == 3)
	local pixelParent = resolve("span", "text-underline-offset: 6px")
	assert(resolve("u", "font-size: 40px", pixelParent).Decorations[1].UnderlineOffset == 6)
	local coloredOrigin = resolve("u", "text-decoration-color: red; text-underline-offset: 10%")
	local coloredChild = resolve("span", "text-decoration-color: blue; text-underline-offset: 9px; font-size: 40px", coloredOrigin)
	assert(coloredChild.Decorations == coloredOrigin.Decorations and coloredChild.Decorations[1].UnderlineOffset == 2)
	assert(coloredChild.Decorations[1].Color == red)
	local nestedLine = resolve("u", "text-decoration-color: blue; text-underline-offset: 9px", coloredOrigin)
	assert(#nestedLine.Decorations == 2 and nestedLine.Decorations[1] == coloredOrigin.Decorations[1])
	assert(nestedLine.Decorations[2].UnderlineOffset == 9 and nestedLine.Decorations[2].Color == blue)
	for _, value in {"normal", "1e3px", "-+2px", "2px 3px", "100001px"} do
		local warnings = {}
		local invalid = resolve("u", "text-underline-offset: 6px; text-underline-offset: " .. value, nil, warnings)
		assert(#warnings == 1 and invalid.Decorations[1].UnderlineOffset == 6)
	end
	for _, value in {"auto", "unknown", "#zzzzzz", "rgb(1, 2)"} do
		local warnings = {}
		assert(resolve("u", "text-decoration-color: red; text-decoration-color: " .. value, nil, warnings).Decorations[1].Color == red and #warnings == 1)
	end
	local compiled = Style.compile("text-decoration: underline; text-decoration-color: red; text-underline-offset: 10%")
	local function fromRules(size, inlineCSS)
		return Style.resolve(fixtureElement("span",{style = inlineCSS or ""}), {FontSize = size, Font = "Inter", Color = blue}, function(message) error(message) end, true, compiled)
	end
	local ruleA, ruleB = fromRules(20), fromRules(40)
	assert(ruleA.Decorations[1].UnderlineOffset == 2 and ruleB.Decorations[1].UnderlineOffset == 4)
	assert(fromRules(20, "text-decoration-color: currentcolor; text-underline-offset: 0").Decorations[1].Color == blue)
	assert(ruleA.UnderlineOffset ~= ruleB.UnderlineOffset, "Computed styles must not share mutable values")
	local frames, requests = {}, 0
	local renderer = loadRenderTree({ create = function(_, _, properties) return table.clone(properties) end })
	local decoration = loadTextDecoration({ create = function(class, gui, properties)
		assert(class == "Frame")
		local frame = table.clone(properties); frame.Parent = gui
		table.insert(frames, frame)
		return frame
	end })
	local layout = loadWordLayout({
		["Layout/TextDecoration"] = decoration,
		["Layout/FontProfiles"] = { face = function(font) return font end },
		["Layout/TextMeasure"] = { measure = function(text, _, size)
			requests += 1
			return { X = if text == " " then 5 else 10, Y = size }
		end },
	})
	local function run(html)
		return renderer.build(Parser.parse(html), {}, function(message) error(message) end).Children[1].Children[1]
	end
	local function arrange(words, width) return layout.arrange(words, width, 0, 0, function() return true end) end
	local words = run([[<p style="font-family: Inter; font-size: 20px; color: blue; text-decoration: underline">A <span style="color: red; text-decoration: none">B</span> C<br>D</p>]])
	local height = arrange(words, 100)
	assert(#frames == 4 and requests == 6)
	local b = words.Items[2]
	assert(b.DecorationFrames[1].Position[1] == -5 and b.DecorationFrames[1].Size[1] == 15)
	assert(b.DecorationFrames[1].Position[2] == b.Baseline + 1 and b.DecorationFrames[1].BackgroundColor3 == Color3.fromRGB(0, 0, 255))
	arrange(words, 10)
	assert(#frames == 4 and requests == 6 and b.DecorationFrames[1].Position[1] == 0 and b.DecorationFrames[1].Size[1] == 10)
	assert(arrange(words, 100) == height and #frames == 4 and requests == 6)
	local plain = run([[<p style="font-family: Inter; font-size: 20px">A B C<br>D</p>]])
	assert(arrange(plain, 100) == height and #frames == 4, "Decorations cannot alter layout or add frames to plain text")
	local justify = run([[<p style="text-decoration: underline; text-align: justify">A B C D</p>]])
	arrange(justify, 37)
	assert(justify.Items[2].DecorationFrames[1].Position[1] == -17 and justify.Items[2].DecorationFrames[1].Size[1] == 27, "Underline must cover the stretched justify gap")
	local gapOnly = run("<p><u>A </u>B</p>")
	arrange(gapOnly, 100)
	local gapFrame = gapOnly.Items[2].DecorationFrames[1]
	assert(gapFrame.Position[1] == -5 and gapFrame.Size[1] == 5, "A decorated trailing space does not decorate the next word")
	local count = #frames
	arrange(gapOnly, 10)
	assert(gapFrame.Visible == false and #frames == count)
	arrange(gapOnly, 100)
	assert(gapFrame.Visible and #frames == count)
	local combined = run([[<p style="font-size: 20px; text-decoration: underline line-through">A</p>]])
	arrange(combined, 100)
	assert(#combined.Items[1].DecorationFrames == 2)
	for _, frame in combined.Items[1].DecorationFrames do assert(frame.Size[2] == 1) end
	assert(combined.Items[1].DecorationFrames[2].Position[2] == combined.Items[1].Baseline - 5)
	for _, case in { {40, 1}, {41, 2}, {61, 2}, {62, 3}, {81, 3}, {82, 4} } do
		local scaled = run('<p style="font-size: ' .. case[1] .. 'px; text-decoration: underline line-through">A</p>')
		arrange(scaled, 100)
		assert(#scaled.Items[1].DecorationFrames == 2)
		for _, frame in scaled.Items[1].DecorationFrames do assert(frame.Size[2] == case[2]) end
	end
	local warnings = {}
	local partial = renderer.build(Parser.parse("<p>nor<u>mal</u></p>"), {}, function(message) table.insert(warnings, message) end)
	local fragments = partial.Children[1].Children[1].Items
	assert(#warnings == 0 and #fragments == 2 and #fragments[1].Style.Decorations == 0 and #fragments[2].Style.Decorations == 1)
	for _, case in { {20, 1}, {21, 2}, {34, 2}, {35, 3} } do
		local scaled = run('<p style="font-size: ' .. case[1] .. 'px; text-decoration: underline">A B</p>')
		arrange(scaled, 100)
		local underline = scaled.Items[2].DecorationFrames[1]
		assert(underline.Position[2] == scaled.Items[2].Baseline + case[2])
		arrange(scaled, 10)
		assert(scaled.Items[2].DecorationFrames[1] == underline and underline.Position[2] == scaled.Items[2].Baseline + case[2])
	end
	local custom = run([[<p style="font-size: 20px; color: blue; text-decoration: underline line-through; text-decoration-color: red; text-underline-offset: -3px; text-decoration-skip-ink: none">A B</p>]])
	local customHeight = arrange(custom, 100)
	local item = custom.Items[2]
	local line = item.DecorationFrames[1]
	assert(item.Gui.TextColor3 == blue and line.BackgroundColor3 == red)
	assert(line.Position[1] == -5 and line.Position[2] == item.Baseline - 3)
	assert(item.DecorationFrames[2].Position[2] == item.Baseline - 5)
	local frameCount, measureCount = #frames, requests
	arrange(custom, 10)
	assert(#frames == frameCount and requests == measureCount and item.DecorationFrames[1] == line)
	assert(line.Position[1] == 0 and line.Position[2] == item.Baseline - 3)
	assert(arrange(custom, 100) == customHeight and requests == measureCount)
	local noLines = run([[<p style="text-decoration-color: red; text-underline-offset: 10px">A B</p>]])
	arrange(noLines, 100)
	assert(#frames == frameCount, "Color or offset alone must not create decorations")
	local joined = run([[<p style="text-decoration: underline; letter-spacing: 2px">A<span style="color: red">B</span></p>]])
	arrange(joined, 100)
	local joinedItem = joined.Items[2]
	assert(joinedItem.Joined and joinedItem.DecorationFrames[1].Position[1] == -2, "Shared underline must bridge tracking at an inline style change")
	local separate = run([[<p style="letter-spacing: 2px"><u>A</u><u>B</u></p>]])
	arrange(separate, 100)
	assert(separate.Items[2].DecorationFrames[1].Position[1] == 0, "Independent decorations must not cross the inline boundary")
	local cascadeTree = renderer.build(Parser.parse([[<style>#lines {text-decoration-color: red !important} p {text-decoration: underline; text-underline-offset: 10%}</style><p id="lines" style="color: blue; font-size: 40px; text-decoration-color: blue">A</p>]]), {}, function(message) error(message) end)
	local cascadeRun = cascadeTree.Children[1].Children[1]
	arrange(cascadeRun, 100)
	assert(cascadeRun.Items[1].DecorationFrames[1].BackgroundColor3 == red)
	assert(cascadeRun.Items[1].DecorationFrames[1].Position[2] == cascadeRun.Items[1].Baseline + 4)
	local upper = run([[<p style="text-decoration-line: overline; font-size: 20px">A B</p>]])
	local upperHeight = arrange(upper, 100)
	local upperWord = upper.Items[2]
	local upperFrame = upperWord.DecorationFrames[1]
	assert(upperFrame.Position[2] == 0 and upperFrame.Position[1] == -5)
	local beforeFrames, beforeMeasures = #frames, requests
	arrange(upper, 10)
	assert(upperWord.DecorationFrames[1] == upperFrame and upperFrame.Position[1] == 0 and upperFrame.Position[2] == 0)
	assert(#frames == beforeFrames and requests == beforeMeasures)
	assert(arrange(upper, 100) == upperHeight and requests == beforeMeasures)
	local allLines = run([[<p style="text-decoration-line: underline overline line-through; text-decoration-skip-ink: none">A</p>]])
	arrange(allLines, 100)
	assert(#allLines.Items[1].DecorationFrames == 3)
	local upperCascade = renderer.build(Parser.parse([[<style>p {text-decoration-color: red; text-decoration-style: double; text-decoration-thickness: 3px; text-decoration-line: overline !important}</style><p style="text-decoration-line: underline">A</p>]]), {}, error)
	local upperRun = upperCascade.Children[1].Children[1]
	arrange(upperRun, 100)
	local upperRecord = upperRun.Items[1].Style.Decorations[1]
	assert(upperRecord.Overline and not upperRecord.Underline and upperRecord.Style == "double" and upperRecord.Thickness == 3 and upperRecord.Color == red)
	local tinted=run([[<p style="text-decoration:underline overline line-through; text-decoration-style:double; text-decoration-skip-ink:none">A B</p>]])
	arrange(tinted,100)
	local retained={}
	for _,word in tinted.Items do
		for _,frame in word.DecorationFrames or {} do retained[frame]={frame.Position,frame.Size} end
		local decorations={}
		for index,entry in word.Style.Decorations do local nextEntry=table.clone(entry);nextEntry.Color=red;nextEntry.Alpha=.5;decorations[index]=nextEntry end
		word.Style.Decorations=decorations
	end
	local changedStyles={};for _,word in tinted.Items do changedStyles[word.Style]=true;if word.SpaceStyle then changedStyles[word.SpaceStyle]=true end end
	assert(tinted.RepaintDecorationColors(changedStyles),'Solid/double/multiple lines have a retained color-only path')
	for frame,bounds in retained do
		assert(frame.BackgroundColor3==red and frame.BackgroundTransparency==.5)
		assert(frame.Position==bounds[1] and frame.Size==bounds[2],'Decoration color paint retains exact geometry values')
	end
	local tracking=run([[<p style="letter-spacing:2px;text-decoration:underline;text-decoration-skip-ink:none">A<span style="color:blue">B</span></p>]])
	arrange(tracking,100)
	local second=tracking.Items[2];local own=table.clone(second.Style.Decorations[1]);own.Color=red
	second.Style.Decorations={own}
	assert(not tracking.RepaintDecorationColors({[second.Style]=true}),'Diverging word/gap colors request decoration-only segmentation')
	local wordPosition,wordSize=second.Gui.Position,second.Gui.Size
	tracking.RepaintDecorations()
	assert(second.Gui.Position==wordPosition and second.Gui.Size==wordSize,'Segmentation never republishes word geometry')
	print("Text decoration: line longhand/overline, color/offset, cascade, origin preservation, wrapping and frame/measurement reuse passed")
end
