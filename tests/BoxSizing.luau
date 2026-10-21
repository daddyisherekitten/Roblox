--!strict
return function(Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local parent = {Font = "Inter", FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function resolve(css, inherited, warn)
		return Style.resolve(fixtureElement("div",{style = css}), inherited or parent, warn or function(message) error(message) end)
	end
	local sized = resolve("box-sizing: BORDER-BOX; min-width: 20%; max-width: 100px")
	assert(sized.BoxSizing == "border-box" and sized.MinWidth.Percent and sized.MinWidth.Value == 20 and sized.MaxWidth.Value == 100)
	local child = resolve("", sized)
	assert(child.BoxSizing == "content-box" and child.MinWidth == nil and child.MaxWidth == nil)
	assert(resolve("min-width: 30px; min-width: auto").MinWidth == nil)
	assert(resolve("max-width: 30px; max-width: none").MaxWidth == nil)
	for _, css in {"box-sizing: padding-box", "min-width: none", "max-width: auto", "max-width: -1px", "max-width: 100001px", "min-width: min-content garbage"} do
		local warnings = 0
		local style = resolve("box-sizing: border-box; min-width: 10px; max-width: 20px; " .. css, nil, function() warnings += 1 end)
		assert(warnings == 1 and style.BoxSizing == "border-box" and style.MinWidth.Value == 10 and style.MaxWidth.Value == 20)
	end
	for property,field in {['min-width']='MinWidth',['max-width']='MaxWidth',['min-height']='MinHeight',['max-height']='MaxHeight'}do
		for _,keyword in {'min-content','max-content','fit-content'}do
			local value=resolve(property..':10px;'..property..':'..keyword)[field]
			assert(value.Intrinsic==keyword and value.Percent==false and value.Value==nil,'Intrinsic limits replace previous lengths without becoming definite zero')
		end
	end
	local warnings = 0
	local inline = Style.resolve(fixtureElement("span",{style = "box-sizing: border-box; min-width: 2px; max-width: 3px"}), parent, function() warnings += 1 end, true)
	assert(inline.BoxSizing == "border-box" and warnings == 2 and inline.MinWidth == nil and inline.MaxWidth == nil)
	local renderer = loadRenderTree({create = function(_, _, properties) return table.clone(properties) end})
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
	local function make(css, text) return build('<div style="' .. css .. '">' .. (text or "") .. '</div>') end
	local function arrange(tree, width) return block.arrange(tree, width or 200, 0, 0, function() return true end) end
	for mode, size in {["content-box"] = {124, 74}, ["border-box"] = {100, 50}} do
		local tree = make("width: 100px; height: 50px; padding: 10px; border: 2px solid; box-sizing: " .. mode)
		arrange(tree)
		assert(tree.Children[1].Gui.Size[1] == size[1] and tree.Children[1].Gui.Size[2] == size[2])
	end
	for _, mode in {"content-box", "border-box"} do
		local tree = make("padding: 10px; border: 2px solid; margin: 3px; box-sizing: " .. mode)
		arrange(tree, 100)
		assert(tree.Children[1].Gui.Size[1] == 94 and tree.Children[1].Gui.Position[1] == 3, "Auto sizing excludes margins in both modes")
	end
	local tiny = make("box-sizing: border-box; width: 5px; height: 5px; padding: 10px; border: 2px solid")
	arrange(tiny)
	assert(tiny.Children[1].Gui.Size[1] == 24 and tiny.Children[1].Gui.Size[2] == 24, "Border box cannot shrink below padding plus border")
	local zero = make("width: 0; height: 0")
	arrange(zero)
	assert(zero.Children[1].Gui.Size[1] == 0 and zero.Children[1].Gui.Size[2] == 0)
	for mode, cases in {
		["content-box"] = {{"width: 100px; max-width: 60px", 84}, {"width: 10px; min-width: 60px", 84}, {"min-width: 90px; max-width: 60px", 114}},
		["border-box"] = {{"width: 100px; max-width: 60px", 60}, {"width: 10px; min-width: 60px", 60}, {"min-width: 90px; max-width: 60px", 90}},
	} do
		for _, case in cases do
			local tree = make(case[1] .. "; padding: 10px; border: 2px solid; box-sizing: " .. mode)
			arrange(tree)
			assert(tree.Children[1].Gui.Size[1] == case[2], "Clamp the selected box dimension, with min winning conflicts")
		end
	end
	local percent = make("box-sizing: border-box; width: 100%; max-width: 50%; min-width: 25%; padding: 10px; border: 2px solid; line-height: 10px", "AA BB CC")
	arrange(percent, 200)
	local box, words = percent.Children[1], percent.Children[1].Children[1]
	assert(box.Gui.Size[1] == 100 and words.Items[3].LineIndex == 1)
	local count = requests
	arrange(percent, 120)
	assert(box.Gui.Size[1] == 60 and words.Items[3].LineIndex == 3 and requests == count, "Percent limits adapt to the parent and reuse word measurements")
	local minimum = make("box-sizing: border-box; width: 100%; min-width: 90px; max-width: 50%; padding: 10px; border: 2px solid")
	arrange(minimum, 120)
	assert(minimum.Children[1].Gui.Size[1] == 90)
	local emptyMax = make("max-width: 0; padding: 10px; border: 2px solid")
	arrange(emptyMax)
	assert(emptyMax.Children[1].Gui.Size[1] == 24)
	local nested = make("box-sizing: border-box; width: 100px; padding: 10px; border: 2px solid", '<div style="width: 50%; height: 0"></div>')
	arrange(nested)
	assert(nested.Children[1].Children[1].Gui.Size[1] == 38, "Nested percentages use the remaining parent content width")
	local universal = build([[<style>* {box-sizing: border-box} .card {max-width: 80px !important}</style><div class="card" style="width: 100%; max-width: 120px; padding: 10px; border: 2px solid"><span>AA</span></div>]])
	arrange(universal)
	assert(universal.Children[1].Gui.Size[1] == 80)
	local zeroText = make("box-sizing: border-box; width: 0; padding: 10px; text-indent: 50%; line-height: 10px", "AA BB")
	arrange(zeroText)
	assert(zeroText.Children[1].Gui.Size[1] == 20 and zeroText.Children[1].Children[1].Items[1].X == 0)
	assert(zeroText.Children[1].Children[1].Items[2].LineIndex == 2, "Zero content width cannot invent a first empty line")
	local siblings = build([[<div style="box-sizing: border-box; width: 100px; height: 40px; padding: 10px; border: 2px solid; margin: 3px"></div><div>AA</div>]])
	arrange(siblings)
	assert(siblings.Children[2].Gui.Position[2] == 46)
	print("Box sizing: content/border box, fixed/auto sizes, minimum/maximum precedence, percentages, zero content, nested blocks, cascade, resize reuse and sibling flow passed")
end
