--!strict
-- Mounted component updates must change the retained flat render tree, not
-- merely produce correct light-DOM wrappers in a DOM-only test adapter.
return function(Parser,Node,Runtime,VM,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,fixture)
	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
		return api
	end
	local guis={};local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,900)
		if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
		function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals["attribute:"..key]then signals["attribute:"..key]:Fire()end end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=="GuiObject"end
		function gui:IsFocused()return false end
		function gui:Destroy()assert(not self.Destroyed,"Component GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end}
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument(fixture.html)
	local messages={};local root=factory.create("ScrollingFrame",nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,nil,"https://example.test/expanded-renderer")
	local events=Events.new(error);local changedControl;local model=FormModel.new(document,tree.Controls,events,function(c)if changedControl then changedControl(c)end end)
	local page={Alive=true,Document=document,DocumentURL="https://example.test/expanded-renderer",BaseURL="https://example.test/expanded-renderer",Root=root,FormModel=model,Events=events,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:RefreshDOMControls()model:RefreshControls()end
	function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
	local realm,flushing=nil,false;local viewport={Width=800,Height=900,ClientWidth=800,ClientHeight=900,ScrollWidth=800,ScrollHeight=900,ScrollX=0,ScrollY=0}
	function page:GeometryViewport()return viewport end
	function page:HasPendingLayout()return false end
	local function arrange(targets)
		tree:SetMediaEnvironment(viewport.Width,viewport.Height);tree.ViewportHeight=viewport.Height;Dirty.begin(tree,targets)
		viewport.ScrollHeight=layout.arrange(tree,viewport.Width,0,0,function()return true end);Dirty.finish(tree,true)
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true;local needed,targets=realm:Flush();if needed then arrange(targets)end;flushing=false
	end
	local directions=require('CSS/Directionality');local snapshots={}
	changedControl=function(c)
		local nextState=table.clone(snapshots);nextState[c.Node]={Value=c.Value,Directionality=directions.of(c.Node)};snapshots=nextState
		local _,needs,targets=tree:SetCSSState('form-state',snapshots);if needs then arrange(targets)end
	end
	arrange();root:SetAttribute("Status","ready")
	local services={Clock=function()return 0 end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	local diagnostics={};realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
	local function settle()
		for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks();if not realm:HasPending()and tasks==0 then break end end
		page:FlushScriptLayout();assert(#diagnostics==0,table.concat(diagnostics," | "));assert(#messages==0,table.concat(messages," | "))
	end
	local function run(code)assert(realm:Run(code),table.concat(realm.Diagnostics," | "));settle()end
	local function node(id)return assert(Node.findById(document,id),id)end
	run(fixture.source..'\nconst expandedResults=htmlExpandedHostChecks();')
	for index,expected in fixture.records do
		run('window.expandedResult=JSON.stringify(expandedResults['..tostring(index-1)..'].value);')
		local normative=fixture.normative[expected.name];local target=if normative then normative.json else expected.json
		assert(realm.Window.Get('expandedResult')==target,expected.name..' expected '..target..' actual '..tostring(realm.Window.Get('expandedResult')))
	end
	run('window.expandedMounted=htmlExpandedMountedSetup();')
	for index,expected in fixture.mounted do
		local target=Node.findById(document,expected.id)
		if not target then local host=node('expanded-host');target=Node.findById(host.InternalShadowRoot,expected.id)end
		assert(target and target.Name=='h:'..target.LocalName and target.Prefix=='h','Renderer changed public source QName')
		local box=assert(tree.NodeBoxes[target],expected.id..' not rendered')
		for axis,value in expected.rect do run('if(Math.abs(expandedMounted['..tostring(index-1)..'].rect['..tostring(axis-1)..']-'..tostring(value)..')>.02)throw new Error("'..expected.id..' axis '..tostring(axis)..' actual "+expandedMounted['..tostring(index-1)..'].rect['..tostring(axis-1)..']);')end
		assert(box.Style.Display==expected.display,expected.id..' native display')
	end
	local edit=node('expanded-edit');local control=assert(model:Resolve(edit));local gui=control.Item.Gui
	local panel=tree.NodeBoxes[node('expanded-panel')];local after=tree.NodeBoxes[node('expanded-after')]
	local light=node('expanded-light');local lightBox=tree.NodeBoxes[light]
	run("const expandedHost=document.getElementById('expanded-host'),expandedRoot=expandedHost.shadowRoot,expandedSlot=expandedRoot.getElementById('expanded-slot');expandedSlot.name='two';")
	assert(not tree.NodeBoxes[light]and light.Parent==node('expanded-host'),'Unassigned prefixed light node remains source-owned but hidden from flat renderer')
	run("expandedSlot.name='one';document.getElementById('expanded-edit').value='retained';")
	assert(tree.NodeBoxes[light]and light.Parent==node('expanded-host'),'Prefixed slot rename redistributes current light DOM')
	assert(model:Resolve(edit)==control and control.Item.Gui==gui and control.Value=='retained'and not gui.Destroyed,'Prefix slot update recreated unrelated native control')
	assert(tree.NodeBoxes[node('expanded-panel')]==panel and tree.NodeBoxes[node('expanded-after')]==after,'Slot update recreated unrelated boxes')
	run("const expandedAuto=document.createElementNS('http://www.w3.org/1999/xhtml','h:input');expandedAuto.id='expanded-auto';expandedAuto.dir='auto';expandedAuto.value='שלום';document.body.append(expandedAuto);")
	local auto=node('expanded-auto');local autoControl=assert(model:Resolve(auto));local autoGui=autoControl.Item.Gui;local autoStyle=tree.NodeStyles[auto]
	assert(autoStyle.Direction=='rtl'and auto.Attributes.value==nil,'Initial live prefixed auto input direction')
	run("expandedAuto.value='English';")
	assert(tree.NodeStyles[auto]==autoStyle and model:Resolve(auto)==autoControl and autoControl.Item.Gui==autoGui and autoStyle.Direction=='ltr'and auto.Attributes.value==nil,'Live value direction change preserves source attribute/native control')
	run("expandedAuto.remove();expandedHost.remove();document.getElementById('expanded-panel').remove();document.getElementById('expanded-after').remove();")
	assert(not tree.NodeBoxes[auto]and autoGui.Destroyed and gui.Destroyed,'Detached prefixed native controls release rendered resources')
	for _,cleanup in page.Cleanups do cleanup()end;model:Destroy();events:Destroy()
	print('H05 expanded rendering: 27 exact native UA/shadow/direction records + 2 normative namespace guards + 7 exact mounted rectangles + flat-tree/input/box retention and disposal passed')
end
