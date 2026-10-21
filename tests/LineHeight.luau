--!strict
-- Exercise actual style/word/block layout with deterministic Roblox text measurements.
return function(Style: any, TextWords: any, Profiles: any, loadWordLayout: any, loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local parent = { FontSize = 20, Font = "Roboto", Color = Color3.new(0, 0, 0) }
	local function resolve(css, inherited, warnings)
		return Style.resolve(fixtureElement("div",{ style = css }), inherited or parent, function(message)
			if warnings then table.insert(warnings, message) else error(message) end
		end)
	end
	assert(resolve("").LineHeight.Kind == "normal")
	local factor = resolve("line-height: 1.4")
	assert(resolve("font-size: 30px", factor).LineHeight.Kind == "number")
	assert(resolve("font-size: 30px", factor).LineHeight.Value == 1.4)
	local pixels = resolve("line-height: 28px")
	assert(resolve("font-size: 30px", pixels).LineHeight.Value == 28)
	for _, css in { "line-height: 140%; font-size: 20px", "font-size: 20px; line-height: 140%" } do
		local percent = resolve(css)
		assert(percent.LineHeight.Kind == "px" and percent.LineHeight.Value == 28)
		assert(resolve("font-size: 30px", percent).LineHeight.Value == 28, "Percentages inherit as computed pixels")
	end
	assert(resolve("line-height: normal", pixels).LineHeight.Kind == "normal")
	for _, value in { "0", "0px", "0%", ".5", "+1.5", "28.5px", "125.5%" } do resolve("line-height: " .. value) end
	assert(resolve("line-height:calc(10px + 50%)").LineHeight.Value==20)
	assert(resolve('line-height:2ex').LineHeight.Value==20,'Font-relative line height resolves before inheritance')
	for _, value in { "-1", "-2px", "-10%", "nan", "inf", "1e999", "1.2.3", "1.", "100001", "100001px", "" } do
		local warnings = {}
		local style = resolve("line-height: 28px; line-height: " .. value, nil, warnings)
		assert(#warnings == 1 and style.LineHeight.Value == 28, "Invalid declarations must preserve earlier valid values: " .. value)
	end
	local copied = resolve("", factor)
	copied.LineHeight.Value = 9
	assert(factor.LineHeight.Value == 1.4, "Resolved styles own their line-height values")

	local requests, live = 0, true
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = { get = Profiles.get, face = function(font) return font end },
		["Layout/TextMeasure"] = { measure = function(text, _, size, width)
			assert(size == math.ceil(20 * 1.13) and width == 0)
			requests += 1
			return { X = if text == " " then 5 else #text * 5, Y = size + 3 }
		end },
	})
	local run = { Kind = "Words", Style = pixels, Items = TextWords.split("Alpha Beta\nGamma") }
	for _, item in run.Items do if item.Kind == "Word" then item.Gui = {} end end
	local function arrange(width)
		return layout.arrange(run, width or 50, 0, 0, function() return live end)
	end
	local first, second, last = run.Items[1].Gui, run.Items[2].Gui, run.Items[4].Gui
	local height, extent = arrange()
	assert(height == 56 and extent == 50 and second.Position[1] == 30)
	assert(first.TextSize == 23 and first.Size[2] == 26)
	assert(first.Position[2] == 2.5 and last.Position[2] == 30.5, "Two 28px lines with leading around the 23px logical font box")
	assert(requests == 4, "Each word and its required space are individually measured")
	run.Style = resolve("line-height: 40px")
	assert(arrange() == 80 and first.Position[2] == 8.5 and last.Position[2] == 48.5)
	assert(requests == 4, "Changing only line-height must reuse each word's own measurements")
	assert(arrange(30) == 120 and second.Position[2] - first.Position[2] == 40)
	assert(requests == 4, "Narrowing the container changes wrapping without remeasurement")
	for _, css in { "line-height: 1.4", "line-height: 140%", "line-height: 28px" } do
		run.Style = resolve(css)
		assert(arrange() == 56, "Line-height must use CSS font size, without the Roblox font factor")
	end
	run.Style = resolve("line-height: 10px")
	assert(arrange() == 20 and first.Size[2] == 26 and last.Position[2] - first.Position[2] == 10)
	assert(first.Position[2] == -6.5, "Small line-height permits overlap without shrinking glyph labels")
	run.Style = resolve("line-height: 0")
	assert(arrange() == 0 and first.Size[2] == 26 and last.Position[2] == first.Position[2])
	run.Style = resolve("line-height: normal")
	assert(arrange() == 52 and first.Position[2] == 1.5, "Normal uses measured spacing, with leading around the logical font box")
	run.Style = resolve("line-height: 28.5px")
	assert(arrange() == 57 and last.Position[2] - first.Position[2] == 28.5)

	-- Real block layout must move following siblings by the resulting text height.
	local block = loadBlockLayout({ ["Layout/WordLayout"] = layout })
	local textBox = { Node = { Kind = "Element" }, Gui = {}, Style = resolve("margin: 0"), Children = { run } }
	local sibling = { Node = { Kind = "Element" }, Gui = {}, Style = resolve("height: 10px"), Children = {} }
	local root = { Node = { Kind = "Document" }, Gui = {}, Style = resolve(""), Children = { textBox, sibling } }
	assert(block.arrange(root, 50, 0, 0, function() return live end) == 67)
	assert(sibling.Gui.Position[2] == 57)
	run.Style = pixels
	assert(block.arrange(root, 50, 0, 0, function() return live end) == 66)
	assert(sibling.Gui.Position[2] == 56 and requests == 4)
	live = false
	local position = first.Position
	assert(arrange() == 0 and first.Position == position, "Disposed pages must not receive new positions")
	print("Line-height: CSS inheritance, exact spacing, reflow, overlap, measurement reuse and following blocks passed")
end
