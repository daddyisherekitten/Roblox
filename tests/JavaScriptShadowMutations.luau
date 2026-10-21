--!strict
-- Shadow redistribution must not turn paint/text writes into host replacement.
return function(Parser,Node,Runtime,VM,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel)
	local function signal()
		local entries={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		return api
	end
	local guis={};local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(760,900)
		if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
		function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals["attribute:"..key]then signals["attribute:"..key]:Fire()end end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=="GuiObject"end
		function gui:IsFocused()return false end
		function gui:Destroy()assert(not self.Destroyed,"Shadow GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end}
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument([=[<!doctype html><html><body><div id="host"><div id="one" slot="main"><input id="note" value="initial"></div></div><p id="after">Following block.</p><script>globalThis.shadowReady=true;</script></body></html>]=])
	local messages,diagnostics={},{};local root=factory.create("ScrollingFrame",nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,
		"html,body { margin:0; padding:0; } #host { display:block; width:320px; } input { width:90px; }",nil,nil,nil,nil,nil,"https://example.test/shadow-mutations")
	local events=Events.new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
	local page={Alive=true,Document=document,DocumentURL="https://example.test/shadow-mutations",BaseURL="https://example.test/shadow-mutations",Root=root,FormModel=model,Events=events,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:RefreshDOMControls()model:RefreshControls()end
	local viewport={Width=760,Height=900,ClientWidth=760,ClientHeight=900,ScrollWidth=760,ScrollHeight=900,ScrollX=0,ScrollY=0}
	function page:GeometryViewport()return viewport end
	function page:HasPendingLayout()return false end
	local layouts=0
	local function arrange(targets)
		layouts+=1;tree:SetMediaEnvironment(viewport.Width,viewport.Height);tree.ViewportHeight=viewport.Height;Dirty.begin(tree,targets)
		viewport.ScrollHeight=layout.arrange(tree,viewport.Width,0,0,function()return true end);Dirty.finish(tree,true)
	end
	local realm,flushing=nil,false
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true;local needed,targets=realm:Flush();if needed then arrange(targets)end;flushing=false
	end
	arrange();root:SetAttribute("Status","ready")
	local services={Clock=function()return 0 end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
	local function settle()
		for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local count=realm:PumpTasks();if not realm:HasPending()and count==0 then break end end
		page:FlushScriptLayout();assert(#diagnostics==0,table.concat(diagnostics," | "));assert(#messages==0,table.concat(messages," | "))
	end
	local function run(code)realm:Run(code);settle()end
	local function node(id)return assert(Node.findById(document,id),id)end
	local function renderedText(text)for _,item in tree.TextItems do if item.Text and item.Text:find(text,1,true)then return true end end;return false end
	local host=node("host");local note=model:Resolve(node("note"));local noteGui=note.Item.Gui;local afterBox=tree.NodeBoxes[node("after")]
	run([=[
	const host=document.getElementById('host'),note=document.getElementById('note'),slottable=document.getElementById('one');
	const shadow=host.attachShadow({mode:'open'});
	shadow.innerHTML='<style>.surface{display:block;width:100px;height:40px;background:#112233}.surface.warm{background:#aa3300}.copy{display:block}#main,#alt{display:block}</style><div id="surface" class="surface">Paint</div><p id="copy" class="copy">Short.</p><div id="main"><slot id="main-slot" name="main"><span id="fallback">Fallback.</span></slot></div><div id="alt"><slot id="alt-slot" name="alt"></slot></div>';
	note.value='edited value';note.setSelectionRange(2,5);
	globalThis.slotChanges=0;shadow.querySelector('#main-slot').addEventListener('slotchange',()=>{slotChanges++;});
	]=])
	local shadow=realm.VM.Global.Bindings.shadow.Value.DOMNode
	local function shadowNode(id)return assert(Node.findById(shadow,id),id)end
	local surfaceNode,copyNode=shadowNode("surface"),shadowNode("copy")
	local surfaceBox,copyBox=assert(tree.NodeBoxes[surfaceNode]),assert(tree.NodeBoxes[copyNode])
	local inputBox=assert(tree.NodeBoxes[node("one")]);local baseX=surfaceBox.TransformBaseX or surfaceBox.PositionX or 0
	local selectionStart,selectionEnd=note.SelectionStart,note.SelectionEnd
	local function stable()
		assert(model:Resolve(node("note"))==note and note.Item.Gui==noteGui and not noteGui.Destroyed and note.Value=="edited value","Shadow mutation replaced the native editor/value")
		assert(note.SelectionStart==selectionStart and note.SelectionEnd==selectionEnd,"Shadow mutation lost the selection")
		assert(tree.NodeBoxes[node("one")]==inputBox and tree.NodeBoxes[node("after")]==afterBox,"Shadow mutation rebuilt retained layout owners")
	end
	local function localWrite(source,label,paintOnly)
		local before=layouts;local sheet=require('CSS/Stylesheet');local collect=sheet.collect;local collections=0
		sheet.collect=function(...)collections+=1;return collect(...)end
		local ok,err=pcall(function()
			realm:Run(source)
			local pending=realm.Pending[host];assert(not pending or not pending.Children,label.." promoted to structural host update")
			settle();stable();if paintOnly then assert(layouts==before,label.." requested layout")end
		end)
		sheet.collect=collect;assert(ok,err)
		assert(collections==0,label..' must not rediscover/recompile shadow stylesheet scopes')
	end
	local before=#guis;local cached=afterBox.CachedLayout
	localWrite("shadow.querySelector('#surface').style.transform='translateX(17px)';","Shadow transform",true)
	local gui=surfaceBox.Gui;local left=gui.Position[1]-(gui.AnchorPoint and gui.AnchorPoint.X or 0)*gui.Size[1]
	assert(math.abs(left-baseX-17)<.001,"Shadow transform did not paint its final native position")
	assert(#guis==before and afterBox.CachedLayout==cached,"Shadow paint allocated native surfaces or invalidated unrelated cache")
	localWrite("shadow.querySelector('#surface').classList.add('warm');","Shadow class paint",true)
	assert(surfaceBox.Style.Background==Color3.fromRGB(170,51,0),"Shadow class did not repaint retained native surface")
	localWrite("shadow.querySelector('#copy').firstChild.data='A much longer shadow sentence that needs multiple lines. '.repeat(5);","Shadow character data",false)
	assert(tree.NodeBoxes[copyNode]==copyBox and copyBox.OuterHeight>30,"Shadow character data did not reflow its retained text box")
	localWrite("shadow.querySelector('#copy').textContent='Another much longer shadow sentence that needs multiple lines. '.repeat(6);","Shadow textContent",false)
	localWrite("shadow.querySelector('#surface').setAttribute('data-state','kept');","Shadow ordinary attribute",true)
	run("const inserted=document.createElement('div');inserted.id='added';inserted.textContent='New shadow child';shadow.append(inserted);")
	stable();local inserted=realm.VM.Global.Bindings.inserted.Value.DOMNode;assert(tree.NodeBoxes[inserted],"Shadow-root structural insertion was not rendered")
	run("inserted.remove();")
	stable();assert(not tree.NodeBoxes[inserted],"Shadow-root structural removal retained removed geometry")
	realm:Run("slottable.slot='alt';")
	assert(realm.Pending[host]and realm.Pending[host].Children,"Changed slot distribution did not invalidate the host flat tree")
	settle();stable();assert(inputBox.Gui.Parent==tree.NodeBoxes[shadowNode("alt")].Gui,"Slot update did not move the retained native input")
	run("shadow.querySelector('#main-slot').name='alt';")
	stable();assert(inputBox.Gui.Parent==tree.NodeBoxes[shadowNode("main")].Gui,"Renamed first matching slot did not redistribute input")
	localWrite("slottable.slot='alt';","Unchanged slot assignment",true)
	run("shadow.querySelector('#main-slot').name='main';")
	local fallback=shadowNode("fallback");assert(renderedText("Fallback."),"Empty slot did not render fallback content")
	localWrite("shadow.querySelector('#fallback').textContent='Updated fallback content';","Slot fallback text",false)
	assert(Node.textContent(fallback)=="Updated fallback content"and renderedText("Updated"),"Fallback text mutation did not update native text")
	run("slottable.slot='main';")
	stable();assert(inputBox.Gui.Parent==tree.NodeBoxes[shadowNode("main")].Gui,"Returning input to its slot did not restore retained ownership")
	run("shadow.innerHTML='<div id=restored><slot name=main></slot></div><p id=replaced>Replacement root</p>';")
	stable();assert(tree.NodeBoxes[shadowNode("replaced")]and inputBox.Gui.Parent==tree.NodeBoxes[shadowNode("restored")].Gui,"Replacing shadow root did not refresh structure/distribution")
	assert(realm.VM.Global.Bindings.slotChanges.Value>=2,"Distribution changes did not dispatch slotchange")
	for _,cleanup in page.Cleanups do cleanup()end;model:Destroy();events:Destroy()
	print("Shadow mutations: local native transform/class/text paint, no structural host promotion, retained input/selection, root structure and slot redistribution passed")
end
