--!strict
-- Raw native top-layer membership/focus states are separate from presentation.
return function(Parser,Node,Dirty,Controller,HTMLScripts,Dialog,Popover,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
	local function signal()
		local listeners={};local s={}
		function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function s:Fire(...)for _,v in table.clone(listeners)do if v[1].Connected then v[2](...)end end end
		function s:Count()local n=0;for _,v in listeners do if v[1].Connected then n+=1 end end;return n end
		return s
	end
	local focused;local surfaces,deferred={},{};local factory={}
	function factory.create(class,parent,props)
		local changes,attributes={},{}
		local values={Parent=parent,ClassName=class,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(800,600),AbsoluteWindowSize=Vector2.new(800,600),Text='',CursorPosition=-1,SelectionStart=-1}
		for k,v in props do values[k]=v end;if class=='ScrollingFrame'then values.CanvasPosition=Vector2.new(0,0)end
		local gui=setmetatable({},{__index=values,__newindex=function(_,k,v)local old=values[k];values[k]=v;if old~=v and changes[k]then changes[k]:Fire()end end})
		values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
		function values:GetPropertyChangedSignal(k)changes[k]=changes[k]or signal();return changes[k]end
		function values:GetAttributeChangedSignal(k)return self:GetPropertyChangedSignal('attribute:'..k)end
		function values:SetAttribute(k,v)attributes[k]=v end;function values:GetAttribute(k)return attributes[k]end
		function values:IsA(k)return k==class or(k=='GuiObject'and class~='ScreenGui')end
		function values:IsFocused()return focused==gui end
		function values:CaptureFocus()if focused==gui then return end;if focused then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
		function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
		function values:Destroy()if values.Destroyed then return end;values.Destroyed=true;if focused==gui then gui:ReleaseFocus()end;for _,child in surfaces do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
		table.insert(surfaces,gui);return gui
	end
	factory.modifier=factory.create
	local document=Parser.parseDocument(reference.source)
	local messages={};local function diagnostic(m)table.insert(messages,m)end
	local viewport=factory.create('ScreenGui',nil,{})
	local root=factory.create('ScrollingFrame',viewport,{ClipsDescendants=true})
	local tree=loadRenderTree(factory).build(document,root,diagnostic,function(font)return font end)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=(utf8.len(text)or 0)*size/2,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
	Dialog.attachViewport(tree,root);Popover.attachViewport(tree,root)
	local function arrange(items)
		tree.ViewportHeight=600;Dirty.begin(tree,items);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
		Dialog.arrange(tree,root);Popover.arrange(tree,root)
		for _,registry in {tree.Dialogs,tree.Popovers}do for _,state in registry do
			local box=state.Box;box.Gui.AbsolutePosition=Vector2.new(box.TopLayerPaintX or 0,box.TopLayerPaintY or 0);box.Gui.AbsoluteSize=Vector2.new(box.OuterWidth or 0,box.OuterHeight or 0)
		end end
	end
	arrange()
	local realm,flushing,pending=nil,false,false;local targets={}
	local page={Alive=true,Document=document,DocumentURL='https://visibility.test/top-layer',BaseURL='https://visibility.test/top-layer',Root=root,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:HasPendingLayout()return pending end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true;local needed,items=realm:Flush()
		if pending then needed=true;items=items or{};for box in targets do items[box]=true end;pending=false;table.clear(targets)end
		if needed then arrange(items)end;flushing=false
	end
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end
	local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=os.clock,Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return{Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end},RunService={RenderStepped=signal(),Heartbeat=signal()}}
	Controller.start(page,tree,function(_,box)pending=true;if box then targets[box]=true end end,diagnostic,services)
	realm=assert(HTMLScripts.start(page,tree,function()end,diagnostic,{JavaScriptServices=services}));page.JavaScriptRuntime=realm
	local function settle()
		for _=1,24 do page:FlushScriptLayout();realm:AfterLayout();local tasks=deferred;deferred={};for _,fn in tasks do fn()end;if #deferred==0 and realm:PumpTasks()==0 and not pending and not realm:HasPending()then break end end
		assert(#messages==0,table.concat(messages,' | '));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
	end
	local function run(source)local ok,err=realm:Run(source);assert(ok,tostring(err)..' | '..source);settle()end
	local dialog=assert(tree.DialogsByNode[Node.findById(document,'dialog')])
	local popover=assert(tree.PopoversByNode[Node.findById(document,'popover')])
	local dialogGui,popoverGui=dialog.Box.Gui,popover.Box.Gui
	local inside=Node.findById(document,'inside');local outside=Node.findById(document,'outside')
	local comparisons=0
	for _,expected in reference.states do
		if expected.operation=='native Escape'then
			local event={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Escape}
			input.InputBegan:Fire(event,false);input.InputEnded:Fire(event,false);settle()
		elseif expected.operation=='native pointer at (4,4)'or expected.operation=='native pointer at (400,300)'then
			local point=if expected.operation=='native pointer at (4,4)'then Vector2.new(4,4)else Vector2.new(400,300)
			local event={UserInputType=Enum.UserInputType.MouseButton1,Position=point}
			input.InputBegan:Fire(event,false);input.InputEnded:Fire(event,false);settle()
		else run(expected.operation)end
		local active=page.FormModel:GetActiveElement();local activeId=if active then active.Attributes.id or active.Name else 'body'
		assert(activeId==expected.active,'Top-layer focus disagrees with native browser: '..expected.name..' '..tostring(activeId))
		assert(dialog.Open==expected.dialog.open and dialog.Modal==expected.dialog.modal and popover.Open==expected.popover.open,'CSS suppression changed HTML membership: '..expected.name)
		assert(dialogGui.Visible==(expected.dialog.rectCount>0)and popoverGui.Visible==(expected.popover.rectCount>0),'Top-layer box paints under a skipped ancestor: '..expected.name)
		assert(tree.DialogHost.Backdrop.Visible==(expected.dialog.modal and expected.dialog.rectCount>0),'Backdrop paints without its dialog box: '..expected.name)
		assert(tree.DialogHost.Layer.Visible==(expected.dialog.rectCount>0 and expected.dialog.modal or expected.popover.rectCount>0),'Shared top-layer host paints without any visible member: '..expected.name)
		assert(dialog.Box.Gui==dialogGui and popover.Box.Gui==popoverGui and not dialogGui.Destroyed and not popoverGui.Destroyed,'Hide/reveal recreated top-layer surfaces')
		assert((tree.CSSStates.modal and tree.CSSStates.modal[dialog.Node]or false)==expected.dialog.modal,'Hidden modal lost :modal membership')
		assert((tree.CSSStates['popover-open']and tree.CSSStates['popover-open'][popover.Node]or false)==expected.popover.open,'Hidden popover lost :popover-open membership')
		assert(tree.ActiveModal==(if expected.dialog.modal then dialog else nil),'Rendering suppression lost modal inertness')
		if tree:IsContentSkipped(inside)then assert(Dialog.hidden(tree,inside)and Popover.hidden(tree,inside)and not Dialog.allows(tree,inside),'Hidden top-layer descendants remain focus/hit eligible')end
		if expected.dialog.modal then assert(not Dialog.allows(tree,outside),'Invisible open modal released the inert background')end
		comparisons+=1
	end
	for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end;page.Alive=false;viewport:Destroy()
	assert(input.InputBegan:Count()==0 and input.InputEnded:Count()==0 and tree.ContentVisibilityChanged==nil,'Top-layer/input cleanup leaked')
	print('Content visibility top layer: '..comparisons..' native modal/popover box, backdrop, membership, focus, inertness, self-hidden, reveal, pointer/Escape and retained-surface states passed')
end
