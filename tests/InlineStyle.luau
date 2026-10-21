--!strict
return function(Style: any)
 local fixtureElement=require('DOM/Node').element
	local parent = { FontSize = 16, Color = Color3.new(0, 0, 0), Font = Enum.Font.Arial }
	local warnings = {}
	local style = Style.resolve(fixtureElement("div",{ style = "padding: 2px 4px 6px; margin: 0; width: 50%; font-size: 24px; height: 80px" }), parent,
		function(message: string) table.insert(warnings, message) end)
	assert(style.Padding[1] == 2 and style.Padding[2] == 4 and style.Padding[3] == 6 and style.Padding[4] == 4)
	assert(style.Width.Percent and style.Width.Value == 50 and style.Height.Value == 80)
	assert(style.FontSize == 24 and style.Font == parent.Font and #warnings == 0)
	local child = Style.resolve(fixtureElement("div",{ style = "display: none; height: 20%; position: absolute" }), style,
		function(message: string) table.insert(warnings, message) end)
	assert(child.Hidden and child.Height.Percent and child.Height.Value == 20 and child.Position == "absolute" and #warnings == 0)
	assert(child.FontSize == 24 and child.Padding[1] == 0, "Only inheritable properties propagate")
	for _,position in {'absolute','fixed'} do
		for display,expected in {inline='block',['inline-block']='block',['inline-flex']='flex',['inline-grid']='grid'} do
			local positioned=Style.resolve(fixtureElement('button',{style='position:'..position..';display:'..display}),parent,error)
			assert(positioned.Display==expected,position..' '..display..' must blockify')
		end
	end
	for _,position in {'static','relative','sticky'} do
		local positioned=Style.resolve(fixtureElement('button',{style='position:'..position..';display:inline-block'}),parent,error)
		assert(positioned.Display=='inline-block',position..' must keep its inline display')
	end
	assert(Style.length("3.4.5px") == nil and Style.length("-1px") == nil)
	assert(Style.length("0").Value == 0)
	for _, value in { "1.px", "2.%", "1e3px", "nanpx", "100001px" } do assert(Style.length(value) == nil) end
	assert(Style.length("+.5px").Value == 0.5 and Style.length("+20%").Percent)
	local spaced = Style.resolve(fixtureElement("div",{ style = " \tFONT-FAMILY : 'Source Sans Pro'  \n; padding:  3px \t" }), parent, function() error("Valid whitespace rejected") end)
	assert(spaced.Font == Enum.Font.SourceSans and spaced.Padding[1] == 3)
	local ubuntu = Style.resolve(fixtureElement("p",{ style = "font-family: Ubuntu" }), parent, function() error("Ubuntu rejected") end)
	assert(ubuntu.Font ~= nil and ubuntu.Font == Enum.Font.Ubuntu)
	for _, name in { "Open Sans", "Inter", "Roboto", "Roboto Condensed", "Roboto Mono", "Roboto Slab", "PT Serif" } do
		local roboto = Style.resolve(fixtureElement("p",{ style = 'font-family: "' .. name .. '"' }), parent, function() error(name .. " rejected") end)
		assert(roboto.Font == name)
		local inherited = Style.resolve(fixtureElement("span",{}), roboto, function() error("Inheritance rejected") end)
		assert(inherited.Font == name, "Children must keep the selected font family")
	end
	local function sides(actual, expected)
		for side = 1, 4 do assert(actual[side] == expected[side], "Wrong spacing side " .. side) end
	end
	for list, expected in {
		['Roboto, sans-serif'] = 'Roboto', ['"Roboto Mono", monospace'] = 'Roboto Mono',
		['Missing, Inter, sans-serif'] = 'Inter', ['Ubuntu, Inter'] = Enum.Font.Ubuntu,
		['Inter, Ubuntu'] = 'Inter', ['"Missing, Font", "Open Sans", Arial'] = 'Open Sans',
		['Source   Sans\tPro, Arial'] = Enum.Font.SourceSans, ['"Inter", missing'] = 'Inter',
		['missing, sans-serif, Inter'] = Enum.Font.Arial, ['missing, serif'] = 'Roboto Slab',
		['missing, monospace'] = 'Roboto Mono', ['system-ui, Inter'] = Enum.Font.Arial,
		['"monospace", Inter'] = 'Inter', ['"serif", Ubuntu'] = Enum.Font.Ubuntu,
		['Missing, Other'] = 'PT Serif', ['"", Inter'] = 'Inter',
		['"Missing Font", /* fallback */ Inter'] = 'Inter',
	} do
		local selected = Style.resolve(fixtureElement('span',{style = 'font-family: ' .. list}),
			{Font = 'Roboto Mono', FontSize = 20}, error, true)
		assert(selected.Font == expected, list)
		assert(Style.resolve(fixtureElement('span',{}), selected, error, true).Font == expected)
	end
	for _, list in {'Inter,', ',Inter', 'Inter,,Arial', 'Inter, 123', 'Inter, "bad"word',
		'Inter, "unclosed', 'Inter, rgb(1,2,3)', 'Inter, inherit', 'Inter, foo/bar', 'Inter, "bad\\name"'} do
		local count = 0
		local invalid = Style.resolve(fixtureElement('span',{style = 'font-family: Ubuntu; font-family: ' .. list}),
			parent, function() count += 1 end, true)
		assert(count == 1 and invalid.Font == Enum.Font.Ubuntu, 'Reject the whole malformed list: ' .. list)
	end
	local cascade = Style.resolve(fixtureElement('span',{style = 'font-family: Inter, Arial !important; font-family: Ubuntu, sans-serif'}), parent, error, true)
	assert(cascade.Font == 'Inter')
	local fallbackRules = Style.compile('font-family: Missing, Other')
	for _, fallback in {'PT Serif', 'Inter'} do
		local resolved = Style.resolve(fixtureElement('span',{}), {Font = 'Roboto', DefaultFont = fallback}, error, true, fallbackRules)
		assert(resolved.Font == fallback, 'Compiled fallback rules must resolve independently per page')
	end
	local function resolve(css, name, author, inline)
		return Style.resolve(fixtureElement(name or "div",{style = css}), parent, function(message) error(message) end, inline, author)
	end
	sides(resolve("margin: 1px 2px 3px 4px; margin-left: 9px").Margin, {1, 2, 3, 9})
	sides(resolve("margin-left: 9px; margin: 1px 2px").Margin, {1, 2, 1, 2})
	sides(resolve("padding: 5px; padding-top: 0; padding-right: 2px; padding-bottom: 3px; padding-left: .5px").Padding, {0, 2, 3, .5})
	sides(resolve("padding-left: 8px; padding: 1px 2px 3px").Padding, {1, 2, 3, 2})
	sides(resolve("margin: 2px; margin-top: 9px !important; margin: 3px").Margin, {9, 3, 3, 3})
	sides(resolve("margin-top: 9px; margin: 2px !important").Margin, {2, 2, 2, 2})
	sides(resolve("margin: 4px", "div", "margin-left: 9px !important").Margin, {4, 4, 4, 9})
	sides(resolve("padding-left: 3px !important", "div", "padding: 8px !important").Padding, {8, 8, 8, 3})
	sides(resolve("margin-top: 3px", "p").Margin, {3, 0, 16, 0})
	sides(resolve("font-size: 20px; margin-left: 7px", "blockquote").Margin, {20, 40, 20, 7})
	sides(resolve("margin-bottom: 3px; font-size: 20px", "pre").Margin, {20, 0, 3, 0})
	local list = resolve("margin-top: 2px; padding-right: 3px", "ul")
	sides(list.Margin, {2, 0, 16, 0}); sides(list.Padding, {0, 3, 0, 40})
	local rule = resolve("margin-top: 3px", "hr")
	assert(rule.MarginAuto[2] and rule.MarginAuto[4])
	assert(not resolve("margin-left: 3px", "hr").MarginAuto[4])
	local compiled = Style.compile("margin: 1px 2px; margin-left: 9px; padding-top: 7px")
	local a, b = resolve("", "div", compiled), resolve("", "div", compiled)
	a.Margin[4], a.Padding[1] = 99, 99
	sides(b.Margin, {1, 2, 1, 9}); sides(b.Padding, {7, 0, 0, 0})
	sides(Style.resolve(fixtureElement("div",{}), b, function(message) error(message) end).Margin, {0, 0, 0, 0})
	for _, css in {"padding-top: -1px", "padding-left: auto", "padding-left: -5%", "margin-right: 1px 2px", "padding-top: 100001px"} do
		local count = 0
		local invalid = Style.resolve(fixtureElement("blockquote",{style = css}), parent, function() count += 1 end)
		assert(count == 1); sides(invalid.Margin, {16, 40, 16, 40})
	end
	local count = 0
	Style.resolve(fixtureElement("span",{style = "padding-left: 2px; margin-bottom: 1px"}), parent, function() count += 1 end, true)
	assert(count == 2, "Inline box spacing remains unsupported")
	local variables = Style.resolve(fixtureElement("div",{style = "--Tone: rgb(12, 34, 56); --space: 5px; color: var(--Tone); padding: var(--missing, var(--space)); font-size: var(--size, 19px)"}), parent, error)
	assert(variables.Color == Color3.fromRGB(12, 34, 56) and variables.Padding[1] == 5 and variables.FontSize == 19)
	assert(variables.Custom["--Tone"] == "rgb(12, 34, 56)" and variables.Custom["--tone"] == nil, "Custom property names stay case-sensitive")
	local inheritedVariables = Style.resolve(fixtureElement("p",{style = "background-color: var(--Tone); margin-left: var(--space)"}), variables, error)
	assert(inheritedVariables.Background == Color3.fromRGB(12, 34, 56) and inheritedVariables.Margin[4] == 5, "Custom properties inherit")
	local cycle = Style.resolve(fixtureElement("p",{style = "--a: var(--b); --b: var(--a); color: green; color: var(--a); width: var(--a, 11px)"}), variables, error)
	assert(cycle.Color == variables.Color and cycle.Width.Value == 11, "Cycles invalidate the winning value while declaration fallbacks remain usable")
	local importantVariable = Style.resolve(fixtureElement("p",{style = "--tone: blue; color: var(--tone)"}), parent, error, false,
		Style.compile("--tone: red !important"))
	assert(importantVariable.Color == Color3.fromRGB(255, 0, 0), "Important custom properties participate in the normal cascade")
	for _,case in {{'12.5%tail',12.5,true},{' 12.%',12,true},{'12. %',12,false},{'12e2',12,false},{'12px',12,false},{'0',0,false},
		{'+12',nil},{'-12',nil},{'.5',nil},{' 12',nil},{'100001',nil}}do
	 local node=fixtureElement('img',{width=case[1]})
	 local resolved=Style.resolve(node,parent,error)
	 assert((resolved.Width and resolved.Width.Value)==case[2],'HTML dimension prefix '..case[1])
	 if case[2]~=nil then assert(resolved.Width.Percent==case[3],'HTML dimension unit '..case[1])end
	end
	for _,css in {'width:initial','width:unset','width:revert','all:revert'}do
	 local hinted=Style.resolve(fixtureElement('img',{width='40',style=css}),parent,error)
	 assert(hinted.Width==nil,'Author reset removes HTML dimension hint: '..css)
	end
	local reverted=Style.resolve(fixtureElement('img',{width='40',style='width:revert-layer'}),parent,error)
	assert(reverted.Width.Value==40,'Inline layer rollback retains HTML dimension hint')
	assert(Style.resolve((function()local node=fixtureElement('img',{width='40'});node.NamespaceURI='urn:other';return node end)(),parent,error).Width==nil,'Foreign names do not receive HTML dimension hints')
	print("Inline style: parsing, spacing longhands, cascade, defaults, inheritance and unsupported values passed")
end
