--!strict
return function(Style, Parser, loadRenderTree, loadWordLayout, loadBlockLayout, LengthExpression)
 local fixtureElement=require('DOM/Node').element
	local base = {Font = "Roboto", FontSize = 20, RootFontSize = 24, Color = Color3.new(0, 0, 0),ViewportWidth=800,ViewportHeight=600}
	local function resolve(css, parent, name, author, warnings)
		return Style.resolve(fixtureElement(name or "div",{style = css}), parent or base,
			function(message) if warnings then table.insert(warnings, message) else error(message) end end, false, author)
	end
	local function equal(a, b, path)
		if type(a) == "number" and type(b) == "number" then
			assert(math.abs(a - b) < .000001, path .. ": " .. tostring(a) .. " ~= " .. tostring(b))
		elseif type(a) == "table" and type(b) == "table" then
			for key, value in a do equal(value, b[key], path .. "." .. tostring(key)) end
			for key in b do assert(a[key] ~= nil, path .. "." .. tostring(key)) end
		else assert(a == b, path .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
	end
	-- All supported length consumers, including mixed/signed shortforms and nested parsers.
	for relative, pixels in {
		["width:2em;height:3rem;min-width:.5em;max-width:4rem;min-height:1em;max-height:5rem"] = "width:40px;height:72px;min-width:10px;max-width:96px;min-height:20px;max-height:120px",
		["margin:-.5em auto 1rem; padding:1em .5rem; padding-left:2em"] = "margin:-10px auto 24px;padding:20px 12px;padding-left:40px",
		["gap:.5em 1rem;row-gap:2em;flex:1 1 3rem"] = "gap:10px 24px;row-gap:40px;flex:1 1 72px",
		["inset:-.5em 1rem auto 2em;left:-1rem"] = "inset:-10px 24px auto 40px;left:-24px",
		["border:.1em solid red;border-left-width:.25rem;border-radius:.5em;outline:.125rem dashed blue;outline-offset:-.1em"] = "border:2px solid red;border-left-width:6px;border-radius:10px;outline:3px dashed blue;outline-offset:-2px",
		["line-height:1.5em;letter-spacing:.1em;word-spacing:-.25rem;text-indent:2em;tab-size:2rem"] = "line-height:30px;letter-spacing:2px;word-spacing:-6px;text-indent:40px;tab-size:48px",
		["text-decoration:underline wavy .1em red;text-underline-offset:.25rem"] = "text-decoration:underline wavy 2px red;text-underline-offset:6px",
		["object-position:right 1em bottom .5rem;vertical-align:-.5em"] = "object-position:right 20px bottom 12px;vertical-align:-10px",
		["box-shadow:.1em -.25rem .5em -.1em rgba(0,0,0,.5);text-shadow:.1em .25rem 0em blue"] = "box-shadow:2px -6px 10px -2px rgba(0,0,0,.5);text-shadow:2px 6px 0px blue",
	} do equal(resolve(relative, nil, "img"), resolve(pixels, nil, "img"), relative) end
	for _, css in {"padding:1em;font-size:1.5em", "font-size:1.5em;padding:1em"} do
		local s = resolve(css); assert(s.FontSize == 30 and s.Padding[1] == 30)
	end
	local root = resolve("font-size:2rem;padding:1rem;line-height:1em", nil, "html")
	assert(root.FontSize == 32 and root.RootFontSize == 32 and root.Padding[1] == 32 and root.LineHeight.Value == 32)
	local child = resolve("font-size:.5em;width:2rem", root)
	assert(child.FontSize == 16 and child.Width.Value == 64 and child.RootFontSize == 32)
	local grandchild = resolve("font-size:1.5rem;margin:1em;line-height:1.25em", child)
	assert(grandchild.FontSize == 48 and grandchild.Margin[1] == 48 and grandchild.LineHeight.Value == 60)
	local inherited = resolve("font-size:10px;margin:inherit;line-height:inherit", grandchild)
	assert(inherited.Margin[1] == 48 and inherited.LineHeight.Value == 60, "Inherited lengths retain computed pixels")
	assert(resolve("font-size:10px", resolve("line-height:1.5")).LineHeight.Kind == "number")
	local shorthand = resolve("font:italic 1.5em/2em Roboto;font-size:2rem;padding:1em")
	assert(shorthand.FontSize == 48 and shorthand.LineHeight.Value == 96 and shorthand.Padding[1] == 48)
	assert(resolve("font-size:larger;font:1em/1em Roboto").FontSize == 20)
	assert(resolve("font-size:2em;font-size:inherit;padding:1em").Padding[1] == 20)
	assert(resolve("font-size:2em;font-size:initial;padding:1em").Padding[1] == 16)
	local compiled = Style.compile("padding:1em;font-size:1.5em !important")
	local one = resolve("font-size:2rem", base, nil, compiled)
	local other = table.clone(base); other.FontSize = 30
	local two = resolve("", other, nil, compiled)
	assert(one.FontSize == 30 and one.Padding[1] == 30 and two.FontSize == 45 and two.Padding[1] == 45)
	assert(resolve("width:1rem", {FontSize = 20, Font = "Roboto"}).Width.Value == 16)
	local mathStyle=resolve("width:calc(50% - 10px);height:min(40vh,300px);min-width:max(10vw,60px);font-size:clamp(14px,2vw,22px);margin:calc(1rem + 2px);margin-left:calc(2rem + 1px)")
	assert(LengthExpression.resolve(mathStyle.Width,400)==190 and mathStyle.Height.Value==240 and mathStyle.MinWidth.Value==80)
	assert(mathStyle.FontSize==16 and mathStyle.Margin[1]==26 and mathStyle.Margin[4]==49)
	local nested=Style.length("clamp(20px, calc(25% + 5px), max(70px, 10%))",base)
	assert(nested and LengthExpression.resolve(nested,400)==70)
	for _, css in {"width:1eem", "width:--1em", "width:1.2.3rem", "width:1e3em", "padding:-1em", "width:calc(1px * 2px)",
		"width:calc(20px / 0)", "width:min(1px,2)", "width:clamp(1px,2px)",
		"width:100001em", "width:99999rem", "color:rgb(1em,0,0)", "font-size:100rem"} do
		local warnings = {}
		local s = resolve("width:7px;font-size:20px;" .. css, nil, nil, nil, warnings)
		assert(#warnings == 1 and s.Width.Value == 7 and s.FontSize == 20, css)
	end
	local limits = {}
	local boundedRoot = resolve("font:2rem/4000rem Roboto;padding:1em;width:1rem", nil, "html", nil, limits)
	assert(#limits == 1 and boundedRoot.FontSize == 20 and boundedRoot.RootFontSize == 20
		and boundedRoot.Padding[1] == 20 and boundedRoot.Width.Value == 20,
		"Rejected font shorthands must not leave a phantom root size")
	local allocations, measures = 0, 0
	local function create(class, parent, props)
		allocations += 1; local gui = table.clone(props); gui.Parent, gui.ClassName = parent, class
		function gui:Destroy() end
		return gui
	end
	local measure = {measure = function(text, _, size) measures += 1; return {X = #text * 5, Y = size} end}
	local overrides = {["Layout/TextMeasure"] = measure, ["Layout/FontProfiles"] = {face = function(font) return font end}}
	local words = loadWordLayout(overrides); overrides["Layout/WordLayout"] = words
	local blocks, renderer = loadBlockLayout(overrides), loadRenderTree({create = create, modifier = create})
	local function build(rootSize)
		return renderer.build(Parser.parse('<html><head><style>html{font-size:' .. rootSize .. 'px}body{font-size:1.25rem}#units{display:flex;gap:.5rem;padding:1em}#units div{flex:1;min-width:0}</style></head><body><div id="units"><div>AB CD EF</div><div>GH IJ</div></div></body></html>'), {}, error, function(font) return font end)
	end
	local function find(box, id)
		if box.Node and box.Node.Attributes and box.Node.Attributes.id == id then return box end
		for _, child in box.Children or {} do local found = find(child, id); if found then return found end end
		return nil
	end
	local tree = build(24)
	local panel = find(tree, "units")
	assert(panel.Style.FontSize == 30 and panel.Style.Padding[1] == 30 and panel.Style.Gap[2] == 12)
	blocks.arrange(tree, 300, 0, 0, function() return true end)
	local objects, measured = allocations, measures
	for _, width in {160, 400, 300} do blocks.arrange(tree, width, 0, 0, function() return true end) end
	assert(allocations == objects and measures == measured, "Relative units need no new labels or text bounds during resize")
	assert(panel.Style.Padding[1] == 30 and panel.Style.Gap[2] == 12)
	assert(find(build(16), "units").Style.FontSize == 20 and panel.Style.FontSize == 30, "Root size belongs to each page")
	local viewportTree=renderer.build(Parser.parse('<div id="viewport" style="width:25vw;height:10vh;padding:2vmin"></div>'),
		{AbsoluteSize={X=800,Y=600}},error,function(font) return font end)
	local viewport=find(viewportTree,"viewport")
	assert(viewportTree.HasViewportUnits and viewport.Style.Width.Value==200 and viewport.Style.Height.Value==60 and viewport.Style.Padding[1]==12)
	assert(viewportTree:SetMediaEnvironment(1000,400))
	assert(viewport.Style.Width.Value==250 and viewport.Style.Height.Value==40 and viewport.Style.Padding[1]==8)
	local calculated=renderer.build(Parser.parse('<div id="calculated" style="width:calc(50% - 10px)"></div>'),{},error,function(font) return font end)
	blocks.arrange(calculated,400,0,0,function() return true end)
	assert(find(calculated,"calculated").ContentWidth==190)
	print("Relative lengths: em/rem, viewport units, CSS math, sizing, cascade, invalid values and resize reuse passed")
end
