--!strict
return function(Parser,XML,Node,Runtime,Events,Sheet,Style,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,Controller,fixture)
	local function quote(value)return '"'..value:gsub('[%z\1-\31\\"]',function(c)return if c=='"'or c=='\\'then '\\'..c else string.format('\\u%04x',string.byte(c))end)..'"'end
	local function rgb(value)local r,g,b=value:match('rgb%((%d+), (%d+), (%d+)%)');return Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b))end
	local comparisons=0
	local function semanticRealm(document,stylesheets)
		local realm;local events=Events.new(error)
		local function styleOf(node)
			if node.Kind~='Element'then return nil end
			local root=node;while root.Parent do root=root.Parent end
			local parent=if node.Parent and node.Parent.Kind=='Element'then styleOf(node.Parent)else{}
			local rules=Sheet.collect(root,error,nil,nil,'https://example.test/owner',realm and realm.CSSOM)
			return Style.resolve(node,parent,error,nil,Sheet.match(rules,node,{}))
		end
		local tree={NodeStyles=setmetatable({},{__index=function(_,node)return styleOf(node)end}),NodeBoxes={}}
		realm=Runtime.new(document,{Events=events,URL='https://example.test/owner',Stylesheets=stylesheets,MaxSteps=1500000,GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return{Width=800,Height=600}end}})
		return realm,events
	end
	local function check(realm,source,call,keys,expected,label)
		assert(realm:Run(source..'\nglobalThis.ownerRows='..call..';'),label..': '..table.concat(realm.Diagnostics,' | '))
		local members={};for _,key in keys do table.insert(members,quote(key))end
		for index,json in expected do
			local project=if #keys==0 then 'ownerRows['..(index-1)..']'else '(()=>{const row=ownerRows['..(index-1)..'],out={};for(const key of ['..table.concat(members,',')..'])if(row[key]!==undefined)out[key]=row[key];return out;})()'
			assert(realm:Run('globalThis.ownerResult=JSON.stringify('..project..');'),label)
			local actual=realm.Window.Get('ownerResult');if actual~=json then print(label..' ['..index..'] actual '..tostring(actual))end;assert(actual==json,label..' ['..index..'] expected '..json);comparisons+=1
		end
		assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
	end
	for _,case in fixture.cases do
		local realm,events=semanticRealm(Parser.parseDocument(fixture.html))
		check(realm,fixture.source,'ownerProbe('..quote(case.mode)..','..quote(case.name)..').rows',fixture.comparisonKeys.owner,case.expectedJSON,case.mode..' '..case.name)
		realm:Destroy();events:Destroy()
	end
	for _,case in fixture.typeCases do
		local realm,events=semanticRealm(Parser.parseDocument(fixture.html))
		check(realm,fixture.typeSource,'typeProbe('..quote(case.namespace)..','..quote(case.foreign)..').rows',fixture.comparisonKeys.type,case.expectedJSON,'type '..case.namespace..' '..case.foreign)
		realm:Destroy();events:Destroy()
	end
	for _,case in fixture.reflectionCases do
		local realm,events=semanticRealm(Parser.parseDocument(fixture.html))
		check(realm,fixture.reflectionSource,'reflectionProbe('..(if case.namespace==nil then 'null'else quote(case.namespace))..','..quote(case.name)..').rows',fixture.comparisonKeys.reflection,case.expectedJSON,'reflection '..case.name..' '..tostring(case.namespace))
		realm:Destroy();events:Destroy()
	end
	for _,case in fixture.controlCases do
		local realm,events=semanticRealm(Parser.parseDocument(fixture.html))
		check(realm,fixture.controlSource,'directOwnerControl('..quote(case.mode)..')',{},case.expectedJSON,'direct '..case.mode)
		realm:Destroy();events:Destroy()
	end
	local xmlRealm,xmlEvents=semanticRealm(XML.parse(fixture.xml,'image/svg+xml'))
	check(xmlRealm,fixture.xmlSource,'xmlOwnerProbe().rows',fixture.comparisonKeys.xml,fixture.xmlCase.expectedJSON,'XML CDATA owner')
	xmlRealm:Destroy();xmlEvents:Destroy()
	-- Compare the observed source/CSSOM/identical-text import graph exactly,
	-- using packaged resources and real Runtime tasks instead of network timing.
	local imports=fixture.importCase
	local importRealm,importEvents=semanticRealm(Parser.parseDocument(fixture.html),{[imports.one]='.one{color:red}',[imports.two]='.two{color:blue}'})
	assert(importRealm:Run('const one='..quote(imports.one)..',two='..quote(imports.two)..';const style=document.createElement("style");style.textContent="@import url(\\\""+one+"\\\");";document.body.append(style);function snapshot(label,old){return{label,oldOwner:old?old.ownerNode===style:null,rules:Array.from(style.sheet.cssRules,r=>({href:r.href,sheetHref:r.styleSheet?r.styleSheet.href:null,selectors:r.styleSheet?Array.from(r.styleSheet.cssRules,q=>q.selectorText):null}))};}'))
	for _,phase in {{'source import initial',''},{'CSSOM import inserted before source import','const old=style.sheet;old.insertRule("@import url(\\\""+two+"\\\");",0);'},{'identical direct Text resets import graph','style.firstChild.data=style.firstChild.data;'}}do
		if phase[2]~=''then assert(importRealm:Run(phase[2]))end
		for _=1,8 do importRealm:PumpTasks()end
		local index=if phase[1]=='source import initial'then 1 elseif phase[1]=='CSSOM import inserted before source import'then 2 else 3
		check(importRealm,'','[snapshot('..quote(phase[1])..(if index==1 then ''else ',old')..')]',{},{imports.expectedJSON[index]},phase[1])
	end
	importRealm:Destroy();importEvents:Destroy()
	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
		function api:Count()local count=0;for _,entry in listeners do if entry[1].Connected then count+=1 end end;return count end
		return api
	end
	local guis={};local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(960,900)
		if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
		function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals["attribute:"..key]then signals["attribute:"..key]:Fire()end end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=="GuiObject"end
		function gui:IsFocused()return false end
		function gui:Destroy()assert(not self.Destroyed,"Native GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end}
	factory.modifier=factory.create
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local html=fixture.retainedHTML
	local document=Parser.parseDocument(html);local messages={};local root=factory.create("ScrollingFrame",nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,{["data:text/css,.one%7Bcolor%3Ared%7D"]=".one{color:red}",["data:text/css,.two%7Bcolor%3Ablue%7D"]=".two{color:blue}"},"https://example.test/page")
	local model,events
	local page={Alive=true,Document=document,DocumentURL="https://example.test/page",BaseURL="https://example.test/page",Root=root,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
	local realm,flushing=nil,false;local viewport={Width=960,Height=900,ClientWidth=960,ClientHeight=900,ScrollWidth=960,ScrollHeight=900,ScrollX=0,ScrollY=0}
	local controlLayout,controlTargets=false,{}
	function page:GeometryViewport()return viewport end
	function page:HasPendingLayout()return controlLayout end
	local arrangements,lastLayout,lastTargets=0,false,nil
	local function arrange(targets)
		arrangements+=1;tree:SetMediaEnvironment(viewport.Width,viewport.Height);tree.ViewportHeight=viewport.Height;Dirty.begin(tree,targets)
		viewport.ScrollHeight=layout.arrange(tree,viewport.Width,0,0,function()return true end);Dirty.finish(tree,true)
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		lastLayout,lastTargets=realm:Flush()
		if controlLayout then
			lastLayout=true;lastTargets=lastTargets or{}
			for item in controlTargets do lastTargets[item]=true end
			controlLayout=false;table.clear(controlTargets)
		end
		if lastLayout then arrange(lastTargets)end
		flushing=false
	end
	arrange();root:SetAttribute("Status","ready")
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return nil end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode()return ''end
	local stopInput=Controller.start(page,tree,function(_,item)
		controlLayout=true;if item then controlTargets[item]=true end
	end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=function()return 0 end,PickerLayout=layout})
	model,events=page.FormModel,page.Events
	local requests,cancellations={},0
	local services={Clock=function()return 0 end,LoadStylesheet=function(url,complete)
		local entry={URL=url,Complete=complete};table.insert(requests,entry)
		return function()entry.Cancelled=true;cancellations+=1 end
	end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return{Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	local diagnostics={};realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services,Stylesheets={['data:text/css,.one%7Bcolor%3Ared%7D']='.one{color:red}',['data:text/css,.two%7Bcolor%3Ablue%7D']='.two{color:blue}'}})
	local function healthy()
		assert(#diagnostics==0,table.concat(diagnostics," | "));assert(#messages==0,table.concat(messages," | "))
		assert(services.RunService.RenderStepped:Count()==0,"CSSOM work does not install an idle frame connection")
	end
	local function settle()
		for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks();if not realm:HasPending()and tasks==0 then break end end
		page:FlushScriptLayout();healthy()
	end
	local function run(code)realm:Run(code);settle()end
	local function node(id)return assert(Node.findById(document,id),id)end
	settle();local target,kept,outside=node('target'),node('notes'),node('outside')
	local targetBox,outsideBox=tree.NodeBoxes[target],tree.NodeBoxes[outside];local control=model:Resolve(kept)
	local inputGui,editor=control.Item.Gui,assert(control.Item.Editor,'Mounted native editor');local guiCount=#guis
	local words={};for _,item in tree.TextItems do if item.Text=='Surface'then table.insert(words,{Item=item,Gui=item.TextGui or item.Gui})end end;assert(#words>0,'Mounted target labels')
	local focusConnections=editor.Focused:Count();local textConnections=editor:GetPropertyChangedSignal('Text'):Count()
	for _,case in fixture.retained do
		local before=arrangements;run(case.code);local expected=case.expected;local color=rgb(expected.color)
		assert(tree.NodeStyles[target].Color==color,case.name..': computed color')
		for _,word in words do assert(table.find(tree.TextItems,word.Item)and(word.Item.TextGui or word.Item.Gui)==word.Gui and word.Gui.TextColor3==color,case.name..': original label repaint')end
		assert(tree.NodeBoxes[target]==targetBox and tree.NodeBoxes[outside]==outsideBox and model:Resolve(kept)==control and control.Item.Gui==inputGui and control.Item.Editor==editor and #guis==guiCount and not editor.Destroyed,case.name..': retained boxes/control/GUI/editor')
		assert(control.Value==expected.value and editor.Text=='edited',case.name..': native edited value')
		run('if(input.value!=='..quote(expected.value)..'||input.selectionStart!=='..expected.selectionStart..'||input.selectionEnd!=='..expected.selectionEnd..'||input.selectionDirection!=='..quote(expected.selectionDirection)..')throw Error("Editor selection");if((owner.sheet?owner.sheet.cssRules.length:null)!=='..(if expected.count==nil then 'null'else tostring(expected.count))..')throw Error("Owner rule count");')
		assert(editor.Focused:Count()==focusConnections and editor:GetPropertyChangedSignal('Text'):Count()==textConnections,case.name..': original editor connections')
		local owner=Node.findById(document,'owner')
		if owner then local metadata=Style.resolve(owner,{},error);assert(metadata.Display==fixture.standardDisplay.expected and metadata.Hidden and not tree.NodeBoxes[owner],case.name..': SVG2 non-rendered style metadata')end
		assert(arrangements==before,case.name..': style-only mutation must not arrange')
	end
	run('owner.textContent="#target{color:rgb(10,20,30)}";owner.sheet.insertRule("@import url(slow.css);",0);')
	assert(#requests==1 and not requests[1].Cancelled,'CSSOM import owns one outstanding request')
	local resource=node('owner').StylesheetResourceState;local generation=resource.Generation
	run('owner.firstChild.data=owner.firstChild.data;')
	assert(requests[1].Cancelled and cancellations==1 and resource.Generation>generation and tree.NodeStyles[target].Color==Color3.fromRGB(10,20,30),'Identical block update resets imports and cancels only old work')
	requests[1].Complete(true,{Source='#target{color:red}',MIME='text/css'});settle()
	assert(tree.NodeStyles[target].Color==Color3.fromRGB(10,20,30),'Obsolete import completion must not publish')
	run('owner.sheet.insertRule("@import url(dispose.css);",0);')
	assert(#requests==2 and not requests[2].Cancelled,'Current owner has one pending import before disposal')
	local cssom,resources=realm.CSSOM,realm.StylesheetResources;local owned=node('owner')
	for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;stopInput()
	assert(not realm.Alive and not cssom.Alive and not resources.Alive and resources.Pending==0 and owned.StylesheetResourceState==nil and cancellations==2,'Disposal releases owner state and cancels current import work')
	requests[2].Complete(true,{Source='#target{color:blue}',MIME='text/css'})
	assert(editor.Focused:Count()==0 and editor:GetPropertyChangedSignal('Text'):Count()==0,'Disposal disconnects retained native editor bindings')
	assert(#diagnostics==0 and #messages==0,table.concat(diagnostics,' | ')..table.concat(messages,' | '))
	-- Real Luau weak-owner collection, with an independent plain table proving
	-- that the bounded pressure actually completed a collector cycle.
	local weak,plain=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
	local function releasedOwner()
		local control={};plain[control]=true
		local d=Parser.parseDocument('<html><head></head><body></body></html>');local e=Events.new(error)
		local r=Runtime.new(d,{Events=e,URL='https://example.test/owner',Stylesheets={['one.css']='.one{color:red}'}})
		assert(r:Run('const el=document.createElementNS("http://www.w3.org/2000/svg","s:style");el.id="weak-owner";el.textContent="@import url(one.css);";document.body.append(el);el.sheet.cssRules;'))
		for _=1,8 do r:PumpTasks()end
		local owner=assert(Node.findById(d,'weak-owner'));weak[r]='realm';weak[r.VM]='vm';weak[owner]='owner';weak[assert(owner.StylesheetResourceState)]='resource'
		r:Destroy();e:Destroy()
	end
	releasedOwner()
	-- Keep next()'s transient weak key out of this long-lived GUI test frame.
	-- Otherwise a live Luau register can itself keep the whole owner realm alive.
	local function collected()return next(weak)==nil and next(plain)==nil end
	local function pressure()
		for batch=1,2048 do
			if collected()then return end
			local garbage=table.create(2048);for i=1,2048 do garbage[i]={i,batch}end
		end
	end
	pressure()
	assert(next(plain)==nil,'SVG owner GC control must complete a collector cycle')
	assert(next(weak)==nil,'Disposed SVG style owners, resource records and realms must be collectible')
	print('SVG style owners: '..comparisons..' native DOM/CSSOM/namespace/CDATA states, '..#fixture.retained..' retained paint/editor states and import-generation cancellation/disposal passed')
end
