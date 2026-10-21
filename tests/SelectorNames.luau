--!strict
return function(Parser,Node,Runtime,Events,Stylesheet,loadRenderTree,fixture)
	-- Lua %q uses backslash-newline for LF; JavaScript treats that as a line
	-- continuation. Keep raw CSS code points intact at the actual JS boundary.
	local function jsString(value)
		return '"'..value:gsub('[%z\1-\31\\"]',function(char)
			return if char=='"'or char=='\\'then '\\'..char else string.format('\\u%04x',string.byte(char))
		end)..'"'
	end
	for _,case in fixture.cases do
		local document=Parser.parseDocument(case.html);local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end})
		local ok,message=runtime:Run('globalThis.selectorResult='..case.action)
		assert(ok,case.name..': '..tostring(message))
		local actual=runtime.Window.Get('selectorResult');local expected=case.specExpected or case.expected
		assert(actual==expected,case.name..'\nexpected '..expected..'\nactual '..tostring(actual))
		assert(#runtime.Diagnostics==0,case.name..': '..table.concat(runtime.Diagnostics,' | '))
		runtime:Destroy();events:Destroy()
	end
	local renderer=loadRenderTree({create=function(_,_,props)return table.clone(props or{})end})
	for _,case in fixture.styles do
		local document=Parser.parseDocument('<!doctype html><style>body{color:rgb(3, 7, 11)}</style><body></body>')
		local events=Events.new(error);local runtime=Runtime.new(document,{Events=events,Schedule=function()end})
		assert(runtime:Run(case.setup),case.name)
		if case.scope then
			assert(runtime:Run('const sheet=new CSSStyleSheet();sheet.replaceSync('..jsString(case.css)..');const r=sheet.cssRules[sheet.cssRules.length-1];globalThis.scopeRuleResult=JSON.stringify([sheet.cssRules.length,r.constructor.name,r.start,r.end,r.cssRules?r.cssRules.length:null]);'),case.name)
			assert(runtime.Window.Get('scopeRuleResult')==case.rulesExpected,case.name..': actual CSSOM namespace/root/limit rule tree\nexpected '..case.rulesExpected..'\nactual '..tostring(runtime.Window.Get('scopeRuleResult')))
		end
		if case.grammar then
			assert(runtime:Run('const sheet=new CSSStyleSheet();sheet.replaceSync('..jsString(case.css)..');const r=sheet.cssRules[sheet.cssRules.length-1];globalThis.grammarRuleResult=JSON.stringify([sheet.cssRules.length,r?r.constructor.name:null,r?r.selectorText||null:null]);'),case.name)
			assert(runtime.Window.Get('grammarRuleResult')==case.grammarRulesExpected,case.name..': actual CSSOM token/selector rule tree\nexpected '..case.grammarRulesExpected..'\nactual '..tostring(runtime.Window.Get('grammarRuleResult')))
		end
		local function warning(message)
			local invalid=case.grammar and(case.grammarRulesExpected=='[0,null,null]')
			assert(message:find('Namespace',1,true)or message:find('Unsupported HTML element',1,true)or(case.scope or invalid)and message:find('Invalid @scope boundaries',1,true)or invalid and(message:find('Unsupported CSS selector',1,true)or message:find('CSS rule closed at end of style block',1,true)or message:find('Unsupported or incomplete CSS rule',1,true)),message)
		end
		local rules=Stylesheet.collect(document,warning,case.css)
		local node=assert(Node.findById(document,'e'))
		local selected=Stylesheet.match(rules,node)
		local expected=case.specExpected or case.expected
		local matched=expected=='rgb(17, 53, 91)'
		assert((#selected.Normal>0)==matched,case.name..': actual stylesheet selection')
		local tree=renderer.build(document,{},warning,nil,nil,nil,nil,case.css)
		local red,green,blue=expected:match('rgb%((%d+), (%d+), (%d+)%)')
		assert(tree.NodeStyles[node].Color==Color3.fromRGB(tonumber(red),tonumber(green),tonumber(blue)),case.name..': renderer cascade differs from reference')
		runtime:Destroy();events:Destroy()
	end
	print('Selector names: '..#fixture.cases..' native DOM sequences and '..#fixture.styles..' actual stylesheet/renderer paint records passed')
end
