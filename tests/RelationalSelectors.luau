--!strict
return function(Parser,Node,Runtime,Events,Selectors,Nesting,Stylesheet,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,fixture)
	local function jsString(value)
		return '"'..value:gsub('[%z\1-\31\\"]',function(char)
			return if char=='"'or char=='\\'then '\\'..char else string.format('\\u%04x',string.byte(char))
		end)..'"'
	end
	local function color(value)
		local r,g,b=value:match('rgb%((%d+), (%d+), (%d+)%)')
		return Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b))
	end
	local document=Parser.parseDocument(fixture.grammarHTML);local e=assert(Node.findById(document,'e'))
	for _,case in fixture.grammar do
		local compiled=Selectors.compile(Selectors.list(case.source)[1]);local expected=case.specExpected or case.expected
		assert((compiled~=nil)==(expected~='SyntaxError'),case.source..': compile validity')
		if compiled then assert(Selectors.matches(e,compiled)==expected,case.source..': compiled match')end
	end
	local rest=assert(Selectors.compile(':has(:is(.leaf,:has(.leaf)))'))
	assert(Selectors.matches(e,rest)and table.concat(rest.Specificity,',')=='0,1,0','A valid forgiving rest branch retains its match and only its own specificity')
	local inner=rest.Parts[1].Tests[1].Selectors[1].Parts[2].Tests[1]
	assert(inner.Name=='is'and #inner.Selectors==1 and inner.Selectors[1].Parts[1].Tests[1].Value=='leaf','Forbidden nested :has must be removed from the compiled forgiving list')
	assert(not Selectors.matches(e,assert(Selectors.compile(':has(:is(.missing,:has(.leaf)))'))),'A forbidden nested branch cannot supply the relational match')
	assert(Selectors.compile(':has(:nth-last-child(1 of :has(.leaf)))')==nil,'The nested prohibition reaches nth-last-child filters')
	assert(Selectors.compile(':has(:where(:not(:has(.leaf))))')~=nil,'An invalid strict child is dropped by its forgiving parent')

	document=Parser.parseDocument(fixture.domHTML);e=assert(Node.findById(document,'e'))
	local events=Events.new(error);local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end})
	for _,case in fixture.dom do
		local ok,message=runtime:Run('globalThis.relationalDOMResult=(()=>{try{return document.getElementById("e").matches('..jsString(case.source)..');}catch(error){return error.name;}})();')
		assert(ok,case.source..': '..tostring(message))
		-- Bad strings have an explicit standard expectation. The separate EOF
		-- profile record preserves a known gap without calling it a standard error.
		local expected=case.specExpected or case.profileExpected or case.expected
		assert(runtime.Window.Get('relationalDOMResult')==expected,case.source..': actual DOM match/error')
		assert(runtime:Run('(()=>{const sheet=new CSSStyleSheet();sheet.replaceSync('..jsString(case.source..'{color:rgb(17,53,91)}')..');globalThis.relationalRuleCount=sheet.cssRules.length;})();'),case.source)
		assert(runtime.Window.Get('relationalRuleCount')==case.count,case.source..': actual CSSOM rule count')
	end
	local renderer=loadRenderTree({create=function(_,_,props)return table.clone(props or{})end})
	local function paintCase(case,selector)
		local compiled=assert(Selectors.compile(selector));assert(table.concat(compiled.Specificity,',')==table.concat(case.specificity,','),case.name..': specificity')
		local rules=Stylesheet.collect(document,error,case.css);local selected=Stylesheet.rawMatch(rules,e)
		assert(selected.Normal[#selected.Normal].Value==case.color:gsub(' ',''),case.name..': actual stylesheet winner')
		local tree=renderer.build(document,{},error,nil,nil,nil,nil,case.css)
		assert(tree.NodeStyles[e].Color==color(case.color),case.name..': actual renderer paint')
	end
	for _,case in fixture.winners do paintCase(case,case.selector)end
	for _,case in fixture.nesting do
		paintCase(case,Nesting.resolve(case.child,case.parent))
		assert(runtime:Run('(()=>{const sheet=new CSSStyleSheet();sheet.replaceSync('..jsString(case.css)..');globalThis.relationalRuleCount=sheet.cssRules.length;globalThis.relationalNestedCount=sheet.cssRules[0].cssRules.length;})();'),case.name)
		assert(runtime.Window.Get('relationalRuleCount')==case.count and runtime.Window.Get('relationalNestedCount')==case.nestedCount,case.name..': actual nested CSSOM rule tree')
	end
	-- Raw native selectorText values stay in the fixture. Forgiving serialization
	-- is unresolved in CSSWG issue 3676 and is not changed by this parser slice.
	assert(#runtime.Diagnostics==0,table.concat(runtime.Diagnostics,' | '));runtime:Destroy();events:Destroy()

	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
		return api
	end
	local guis={};local factory={create=function(class,parent,props)
		local gui=table.clone(props or{});gui.ClassName,gui.Parent=class,parent;gui.Visible=true;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(760,900)
		if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
		function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals['attribute:'..key]then signals['attribute:'..key]:Fire()end end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=='GuiObject'end
		function gui:IsFocused()return false end
		function gui:Destroy()assert(not self.Destroyed,'Relational GUI disposed twice');self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end}
	factory.modifier=factory.create
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);renderer=loadRenderTree(factory)
	document=Parser.parseDocument(fixture.retainedHTML);local messages={};local root=factory.create('ScrollingFrame',nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end)
	events=Events.new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
	local page={Alive=true,Document=document,DocumentURL='https://example.test/relational',BaseURL='https://example.test/relational',Root=root,FormModel=model,Events=events,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:RefreshDOMControls()model:RefreshControls()end
	function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
	local realm,flushing=nil,false;local arrangements=0
	local viewport={Width=760,Height=900,ClientWidth=760,ClientHeight=900,ScrollWidth=760,ScrollHeight=900,ScrollX=0,ScrollY=0}
	function page:GeometryViewport()return viewport end
	function page:HasPendingLayout()return false end
	local function arrange(targets)
		arrangements+=1;tree:SetMediaEnvironment(viewport.Width,viewport.Height);tree.ViewportHeight=viewport.Height;Dirty.begin(tree,targets)
		viewport.ScrollHeight=layout.arrange(tree,viewport.Width,0,0,function()return true end);Dirty.finish(tree,true)
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true;local needed,targets=realm:Flush();if needed then arrange(targets)end;flushing=false
	end
	arrange();root:SetAttribute('Status','ready')
	local services={Clock=function()return 0 end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return{Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	local diagnostics={};realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
	local function settle()
		for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks();if not realm:HasPending()and tasks==0 then break end end
		page:FlushScriptLayout();assert(#diagnostics==0,table.concat(diagnostics,' | '));assert(#messages==0,table.concat(messages,' | '))
	end
	settle();local target=assert(Node.findById(document,'target'));local kept=assert(Node.findById(document,'kept'));local outside=assert(Node.findById(document,'outside'))
	local targetBox,outsideBox=tree.NodeBoxes[target],tree.NodeBoxes[outside];local control=model:Resolve(kept);local inputGui=control.Item.Gui;local guiCount=#guis
	local surfaceItem
	for _,item in tree.TextItems do if item.Text=='Surface'then surfaceItem=item;break end end
	assert(surfaceItem,'Retained surface label');local surfaceGui=surfaceItem.TextGui or surfaceItem.Gui
	for index,case in fixture.retained do
		local before=arrangements;realm:Run('(()=>{'..case.code..'})();');settle()
		assert(tree.NodeStyles[target].Color==color(case.expected.color),case.name..': retained computed paint')
		assert((surfaceItem.TextGui or surfaceItem.Gui)==surfaceGui and surfaceGui.TextColor3==color(case.expected.color),case.name..': original label repaint')
		assert(tree.NodeBoxes[target]==targetBox and tree.NodeBoxes[outside]==outsideBox and model:Resolve(kept)==control and control.Item.Gui==inputGui and not inputGui.Destroyed and #guis==guiCount,case.name..': retained box/control/GUI identity')
		assert(control.Value==case.expected.value,case.name..': native control value')
		local expected=case.expected
		realm:Run('(()=>{const input=document.getElementById("kept");if(document.getElementById("sheet").sheet.cssRules.length!=='..expected.count..')throw new Error("Relative rule count");if(input.value!=='..jsString(expected.value)..')throw new Error("Retained input value");'..
			(if index>1 then 'if(input.selectionStart!=='..expected.selectionStart..'||input.selectionEnd!=='..expected.selectionEnd..'||input.selectionDirection!=='..jsString(expected.selectionDirection)..')throw new Error("Retained input selection");'else '')..
			(if expected.insertError then 'if(relativeInsertError!=='..jsString(expected.insertError)..')throw new Error("Relative insertRule error");'else '')..'})();');settle()
		if case.paintOnly then assert(arrangements==before,case.name..': color edit must not arrange')end
	end
	for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;model:Destroy();events:Destroy()
	print('Relational selectors: '..#fixture.grammar..' grammar cases, '..#fixture.dom..' actual DOM/CSSOM cases, '..(#fixture.winners+#fixture.nesting)..' specificity/renderer winners and '..#fixture.retained..' retained label/control paint states passed')
end
