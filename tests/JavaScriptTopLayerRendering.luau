--!strict
-- Mounted controls and top-layer surfaces: the HTML/JS examples alone cannot
-- detect stale Roblox objects, clipping/compositor parents or native commands.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,Controller,Dialog,Popover,GroupOpacity)
	local function signal()
		local entries={};local s={}
		function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function s:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		function s:Count()local n=0;for _,entry in entries do if entry[1].Connected then n+=1 end end;return n end
		return s
	end
	local focused;local guis={};local deferred={};local factory={}
	function factory.create(class,parent,props)
		local changes,attributes={},{}
		local values={Parent=parent,ClassName=class,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(520,500),Text="",CursorPosition=-1,SelectionStart=-1}
		for key,value in props do values[key]=value end
		if class=="ScrollingFrame"then values.CanvasPosition=Vector2.new(0,0)end
		local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)local old=values[key];values[key]=value;if old~=value and changes[key]then changes[key]:Fire()end end})
		values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
		function values:GetPropertyChangedSignal(key)if not changes[key]then changes[key]=signal()end;return changes[key]end
		function values:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
		function values:SetAttribute(key,value)attributes[key]=value;if changes['attribute:'..key]then changes['attribute:'..key]:Fire()end end
		function values:GetAttribute(key)return attributes[key]end
		function values:IsA(kind)return kind==class or kind=='GuiObject'end
		function values:IsFocused()return focused==gui end
		function values:CaptureFocus()if focused and focused~=gui then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
		function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
		function values:Destroy()assert(not values.Destroyed);values.Destroyed=true;for _,child in guis do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument('<html><body><input id="outside" value="origin"><button id="open" type="button" commandfor="d" command="show-modal">Open</button><div id="ordinary" style="height:20px">Ordinary box</div><div id="m" popover="manual">Older manual</div><dialog id="d" closedby="any" style="width:240px;opacity:.7"><input id="inside" autofocus value="name"><button id="request" type="button" commandfor="d" command="request-close" value="request">Request</button><form id="form" method="dialog"><button id="submit" value="accepted">Accept</button></form><div id="child" popover="manual">Newer manual</div></dialog><dialog id="empty"></dialog><dialog id="hidden" style="display:none">Hidden</dialog><div id="nested" style="position:relative;overflow:hidden"><dialog id="nonmodal" style="width:120px">Nonmodal</dialog></div><div id="after">Keep this native object.</div><script>globalThis.boot=1;</script></body></html>')
	local diagnostics,messages={},{}
	local viewport=factory.create('Frame',nil,{AbsolutePosition=Vector2.new(7,11)})
	local root=factory.create('ScrollingFrame',viewport,{AbsolutePosition=Vector2.new(17,26),AbsoluteSize=Vector2.new(520,500),AbsoluteWindowSize=Vector2.new(520,500)})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end)
	Dialog.attachViewport(tree,root);Popover.attachViewport(tree,root)
	local page={Alive=true,Document=document,DocumentURL='https://example.test/top-layer',BaseURL='https://example.test/top-layer',Root=root,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local width=520;local arrangements,requests=0,0
	local function arrange(items)
		arrangements+=1;tree:SetMediaEnvironment(width,500);tree.ViewportHeight=500;Dirty.begin(tree,items)
		layout.arrange(tree,width,0,0,function()return true end);if tree.HasOpacity then GroupOpacity.arrange(tree)end
		Dirty.finish(tree,true);root.AbsoluteSize=Vector2.new(width,500);root.AbsoluteWindowSize=root.AbsoluteSize;Dialog.arrange(tree,root);Popover.arrange(tree,root)
	end
	arrange()
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end
	local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return {}end},Factory=factory,Clock=function()return 0 end,RunService={RenderStepped=signal()},Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	Controller.start(page,tree,function()requests+=1 end,error,services)
	local realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
	function page:FlushScriptLayout()local needed,items=realm:Flush();if needed then arrange(items)end;return needed end
	local function healthy()assert(#diagnostics==0,table.concat(diagnostics,' | '));assert(#messages==0,table.concat(messages,' | '))end
	local function run(source)realm:Run(source);healthy()end
	local function settle()
		for _=1,32 do local work=deferred;deferred={};for _,fn in work do fn()end;local tasks=realm:PumpTasks();if #deferred==0 and tasks==0 then break end end;healthy()
	end
	local function flush()local needed=page:FlushScriptLayout();settle();return needed end
	flush()
	local stateRefreshes=0;local setCSSState=tree.SetCSSState
	tree.SetCSSState=function(self,name,...)
		if name=='modal'or name=='popover-open'then stateRefreshes+=1 end
		return setCSSState(self,name,...)
	end
	page:TopLayerChanged('dialog',nil);page:TopLayerChanged('popover',nil)
	assert(stateRefreshes==0,'Unchanged top-layer memberships do not rescan CSS selectors')
	local function node(id)return assert(Node.findById(document,id))end
	local function control(id)return assert(page.FormModel:Resolve(node(id)))end
	local function activate(id)page.FormModel:Activate(control(id));healthy();settle()end
	local d=node('d');local afterGui=tree.NodeBoxes[node('after')].Gui
	run("document.getElementById('ordinary').textContent='Ordinary text changes once';");flush()
	assert(stateRefreshes==0,'An unrelated script text mutation does not invalidate modal/popover selectors')
	tree.LayoutInProgress=true
	local queuedDialog=tree.DialogsByNode[d];queuedDialog.Open,queuedDialog.Modal=true,true
	page:TopLayerChanged('dialog',d)
	queuedDialog.Open,queuedDialog.Modal=false,false;page:TopLayerChanged('dialog',d)
	assert(tree.PendingCSSStates.modal and not tree.PendingCSSStates.modal.Node[d],'An open then close during layout replaces the queued modal membership')
	local queuedPopover=tree.PopoversByNode[node('m')];queuedPopover.Open=true;page:TopLayerChanged('popover',queuedPopover.Node)
	queuedPopover.Open=false;page:TopLayerChanged('popover',queuedPopover.Node)
	assert(tree.PendingCSSStates['popover-open']and not tree.PendingCSSStates['popover-open'].Node[queuedPopover.Node],'Popover membership compares the effective pending map during layout')
	tree.LayoutInProgress=false;tree:FlushCSSStates();Dialog.apply(tree);Popover.apply(tree)
	run("const d=document.getElementById('d'),outside=document.getElementById('outside');globalThis.log=[];d.oncancel=e=>log.push('cancel');d.onclose=()=>log.push('close:'+d.returnValue);outside.focus();")
	activate('open')
	assert(tree.DialogsByNode[d].Open and tree.DialogsByNode[d].Modal and tree.ActiveModal.Node==d,'A native command opens the shared modal state')
	assert(page.FormModel:GetActiveElement()==node('inside'),'Native focus delegate/autofocus receives modal focus')
	local native=tree.DialogsByNode[d];local box=native.Box
	assert(box.OpacityGroup and box.Gui.Parent==box.OpacityGroup.Content and box.OpacityGroup.Gui.Parent==tree.DialogHost.Layer,'Top-layer reparenting keeps the composed outer surface intact')
	assert(math.abs(box.OpacityGroup.Gui.GroupTransparency-.3)<.001,'Author opacity remains on the dialog compositor')
	run("outside.focus();if(document.activeElement.id!=='inside')throw new Error('Modal background is inert');d.addEventListener('cancel',e=>e.preventDefault(),{once:true});")
	activate('request');assert(native.Open,'A native request-close command obeys cancel.preventDefault')
	activate('request');assert(not native.Open and native.ReturnValue=='request' and page.FormModel:GetActiveElement()==node('outside'),'Closing restores previous native focus and publishes returnValue')
	run("if(log.join('|')!=='cancel|cancel|close:request')throw new Error('Native dialog event order');d.returnValue='persist';d.showModal();")
	activate('submit');assert(not native.Open and native.ReturnValue=='accepted','Native method=dialog form submission uses the same close algorithm')
	run("document.getElementById('m').showPopover();d.showModal();document.getElementById('child').showPopover();")
	local older=tree.PopoversByNode[node('m')].Box.Gui;local newer=tree.PopoversByNode[node('child')].Box.Gui;local backdrop=tree.DialogHost.Backdrop;local surface=box.OpacityGroup.Gui
	assert(older.Parent==surface.Parent and newer.Parent==surface.Parent and backdrop.Parent==surface.Parent,'All visible top-layer entries and modal backdrop are true siblings under Sibling ZIndex mode')
	assert(older.ZIndex<backdrop.ZIndex and backdrop.ZIndex<surface.ZIndex and surface.ZIndex<newer.ZIndex,'A preexisting manual popover stays below the modal backdrop while a later descendant paints above the modal')
	local before=arrangements
	run("document.getElementById('child').hidePopover();document.getElementById('m').hidePopover();")
	assert(arrangements==before,'Showing/hiding already-mounted popovers does not arrange document flow')
	run("d.closedBy='none';")
	local escape={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Escape}
	input.InputBegan:Fire(escape,false);settle();assert(native.Open,'closedby=none disables user Escape but not requestClose')
	run("d.closedBy='any';d.addEventListener('cancel',e=>e.preventDefault(),{once:true});")
	input.InputBegan:Fire(escape,false);settle();assert(native.Open,'Escape fires a cancelable native cancel event')
	input.InputBegan:Fire(escape,false);settle();assert(not native.Open and page.FormModel:GetActiveElement()==node('outside'),'An uncanceled Escape closes and restores focus')
	run("const empty=document.getElementById('empty');globalThis.blurs=0;empty.onblur=()=>blurs++;empty.showModal();if(document.activeElement!==empty)throw new Error('Dialog itself is focusable');empty.close();if(blurs!==1)throw new Error('Dialog blur');")
	settle()
	run("outside.focus();empty.showModal();empty.close();if(document.activeElement!==outside)throw new Error('Empty dialog restore');outside.blur();empty.showModal();empty.close();if(document.activeElement===empty)throw new Error('Closed dialog cannot stay active');")
	settle()
	run("document.getElementById('hidden').showModal();")
	local hidden=tree.DialogsByNode[node('hidden')];assert(hidden.Open and not hidden.Box.Gui.Visible,'display:none remains hidden even while the HTML dialog open state is true')
	run("document.getElementById('hidden').close();document.getElementById('nonmodal').show();")
	local nonmodal=tree.DialogsByNode[node('nonmodal')]
	assert(nonmodal.Box.Gui.Parent==nonmodal.NaturalParent and nonmodal.NaturalParent~=tree.DialogHost.Layer,'Nonmodal show retains the original clipping/containing block parent')
	run("document.getElementById('nonmodal').close();const ordinary=document.getElementById('ordinary');ordinary.popover='manual';ordinary.showPopover();")
	flush();local p=tree.PopoversByNode[node('ordinary')]
	assert(p and p.Open and p.Box.Gui.Visible and p.Box.Gui.Parent==tree.DialogHost.Layer,'Adding popover to an existing mounted box registers and paints a real native top-layer entry')
	run("ordinary.popover=null;");flush()
	assert(not tree.PopoversByNode[node('ordinary')] and not tree.NodeBoxes[node('ordinary')].TopLayer and tree.NodeBoxes[node('ordinary')].Gui.Visible,'Removing popover returns its existing native box to normal document flow')
	run("d.popover='manual';d.showPopover();")
	assert(tree.PopoversByNode[d] and tree.PopoversByNode[d].Open and box.Gui.Visible,'A dialog can use the popover API without gaining its open/modal states')
	assert(not Dialog.hidden(tree,node('inside'))and not Popover.hidden(tree,node('inside')),'Dialog popover controls share the union visibility state')
	run("d.hidePopover();d.show();")
	assert(box.Gui.Visible and box.Style.Position=='fixed' and box.OpacityGroup.Gui.Parent==tree.ViewportLayer and not Dialog.hidden(tree,node('inside'))and not Popover.hidden(tree,node('inside')),'The popover UA rule makes a nonmodal dialog fixed without changing its union visibility state')
	run("d.close();d.popover=null;d.showModal();")
	local oldSurface=box.OpacityGroup.Gui
	for _,size in {250,640}do
		width=size;arrange()
		assert(box.Gui.Parent==box.OpacityGroup.Content and box.OpacityGroup.Gui==oldSurface and oldSurface.Parent==tree.DialogHost.Layer,'Resize preserves the exact compositor and native text/control objects')
		assert(oldSurface.Parent==tree.DialogHost.Backdrop.Parent and oldSurface.ZIndex>tree.DialogHost.Backdrop.ZIndex,'Resize restores the composed modal above its backdrop after normal layout paint order')
	end
	run("d.remove();");flush()
	assert(not tree.DialogsByNode[d] and tree.ActiveModal==nil and oldSurface.Destroyed,'Removing an open modal prunes the native registry/backdrop and destroys its detached outer surface')
	run("document.body.append(d);");flush()
	local rebound=tree.DialogsByNode[d]
	assert(rebound and rebound.Open and not rebound.Modal and rebound.Box~=box,'A reattached dialog keeps its open attribute but does not regain modal state or a destroyed box')
	run("d.close();d.showModal();d.close('after-rebind');");settle()
	assert(rebound.ReturnValue=='after-rebind' and tree.NodeBoxes[node('after')].Gui==afterGui,'The native bridge rebinds dialog state without recreating unrelated objects')
	assert(services.RunService.RenderStepped:Count()==0,'Dialogs/popovers install no idle frame callback')
	for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;page.Alive=false
	assert(input.InputBegan:Count()==0 and input.InputEnded:Count()==0,'Page disposal releases native input entry points')
	local work=deferred;deferred={};for _,fn in work do fn()end;healthy()
	print('Top-layer rendering: native commands/form/Escape/events/focus/inertness, interleaved siblings, opacity, paint-only popovers, attributes, resize, detach/rebind and disposal passed')
end
