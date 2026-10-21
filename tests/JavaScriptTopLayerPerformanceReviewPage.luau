--!strict
-- Run the shipped comparison page through native controls and top-layer adapters.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,Controller,html,css,browserStates,Dialog,Popover,ViewportLayer,HitTest)
	local function signal()
		local entries={};local s={}
		function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function s:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		function s:Count()local count=0;for _,entry in entries do if entry[1].Connected then count+=1 end end;return count end
		return s
	end
	local focused;local guis={};local deferred={};local nativeValues={}
	local factory={}
	function factory.create(class,parent,props)
		local changes,attributes={},{ }
		local values={Parent=parent,ClassName=class,Visible=true,ZIndex=1,TestOrder=#guis+1,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(520,500),Text="",CursorPosition=-1,SelectionStart=-1}
		for key,value in props do values[key]=value end
		if class=="ScrollingFrame"then values.CanvasPosition=Vector2.new(0,0)end
		local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)local old=values[key];values[key]=value;if old~=value and changes[key]then changes[key]:Fire()end end})
		nativeValues[gui]=values
		values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
		function values:GetPropertyChangedSignal(key)if not changes[key]then changes[key]=signal()end;return changes[key]end
		function values:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function values:SetAttribute(key,value)attributes[key]=value;if changes["attribute:"..key]then changes["attribute:"..key]:Fire()end end
		function values:GetAttribute(key)return attributes[key]end
		function values:IsA(kind)return kind==class or kind=="GuiObject"end
		function values:IsFocused()return focused==gui end
		function values:CaptureFocus()if focused and focused~=gui then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
		function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
		function values:Destroy()assert(not values.Destroyed);values.Destroyed=true;for _,child in guis do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument(html)
	local viewport=factory.create("Frame",nil,{Size=UDim2.fromOffset(520,500)})
	local messages={};local root=factory.create("ScrollingFrame",viewport,{Size=UDim2.fromOffset(520,500),AbsoluteWindowSize=Vector2.new(520,500)})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,{["styles.css"]=css},"http://localhost:8000/javascript-tests/index.html")
	Dialog.attachViewport(tree,root);Popover.attachViewport(tree,root)
	local arrangements,requests,now=0,0,0;local pendingNative={}
	local function arrange(width,items)
		arrangements+=1;tree:SetMediaEnvironment(width,500);tree.ViewportHeight=500
		Dirty.begin(tree,items);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)
		Dialog.arrange(tree,root);Popover.arrange(tree,root);ViewportLayer.attach(tree,root,factory);ViewportLayer.update(tree,root)
	end
	arrange(520);root:SetAttribute("Status","ready")
	local page={Alive=true,Document=document,DocumentURL="http://localhost:8000/javascript-tests/index.html",BaseURL="http://localhost:8000/javascript-tests/index.html",Root=root,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return focused end
	function input:IsKeyDown()return false end
	local function component(value,axis,index,basis)
		local part=value and value[axis]
		return if part then part.Offset+(part.Scale or 0)*basis else value and value[index]or 0
	end
	local function nativeBounds()
		local cache={}
		local function resolve(gui)
			if cache[gui]then return cache[gui]end
			local parent=gui.Parent and resolve(gui.Parent)or {X=0,Y=0,W=520,H=500}
			local width=if gui.Size then component(gui.Size,"X",1,parent.W)else parent.W
			local height=if gui.Size then component(gui.Size,"Y",2,parent.H)else parent.H
			local anchor=gui.AnchorPoint or Vector2.new(0,0)
			local x=parent.X+component(gui.Position,"X",1,parent.W)-anchor.X*width
			local y=parent.Y+component(gui.Position,"Y",2,parent.H)-anchor.Y*height
			if gui.Parent and gui.Parent.ClassName=="ScrollingFrame"then x-=gui.Parent.CanvasPosition.X;y-=gui.Parent.CanvasPosition.Y end
			local bounds={X=x,Y=y,W=width,H=height};cache[gui]=bounds
			-- Derived native bounds are sampled together, not writable properties
			-- that recursively emit another mouse refresh for each child.
			local values=nativeValues[gui]
			values.AbsolutePosition=Vector2.new(x,y);values.AbsoluteSize=Vector2.new(width,height)
			if gui.ClassName=="ScrollingFrame"then values.AbsoluteWindowSize=values.AbsoluteSize end
			return bounds
		end
		for _,gui in guis do if not gui.Destroyed then resolve(gui)end end
	end
	local function objectsAt(x,y)
		nativeBounds();local objects={};local paths={}
		for _,gui in guis do
			if gui.Destroyed then continue end
			local visible=true;local current=gui;local path={}
			while current do
				if current.Visible==false then visible=false;break end
				table.insert(path,1,{current.ZIndex or 1,current.TestOrder})
				current=current.Parent
			end
			local p,s=gui.AbsolutePosition,gui.AbsoluteSize
			if visible and x>=p.X and y>=p.Y and x<p.X+s.X and y<p.Y+s.Y then table.insert(objects,gui);paths[gui]=path end
		end
		table.sort(objects,function(a,b)
			local aa,bb=paths[a],paths[b]
			for index=1,math.min(#aa,#bb)do
				if aa[index][1]~=bb[index][1]then return aa[index][1]>bb[index][1]end
				if aa[index][2]~=bb[index][2]then return aa[index][2]>bb[index][2]end
			end
			return #aa>#bb
		end)
		return objects
	end
	local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function(_,x,y)return objectsAt(x,y)end},Factory=factory,Clock=function()return now end,
		RunService={RenderStepped=signal()},Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	Controller.start(page,tree,function(_,item)requests+=1;pendingNative[item or tree]=true end,error,services)
	local diagnostics={};local realm,flushing
	function page:HasPendingLayout()return (realm and realm:HasPending())or next(pendingNative)~=nil end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		local needed,items=realm:Flush()
		if needed or next(pendingNative)then
			items=items or {};for item in pendingNative do items[item]=true end;pendingNative={};arrange(520,items)
		end
		flushing=false
	end
	realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
	local function healthy()assert(#diagnostics==0,table.concat(diagnostics," | "));assert(#messages==0,table.concat(messages," | "))end
	local function run(source)realm:Run(source);healthy()end
	local function settle()
		for _=1,24 do
			page:FlushScriptLayout();realm:AfterLayout()
			local work=deferred;deferred={};for _,fn in work do fn()end
			local tasks=realm:PumpTasks()
			if #deferred==0 and tasks==0 and not realm:HasPending()then break end
		end
		healthy()
	end
	local function flush()local needed,items=realm:Flush();if needed then arrange(520,items)end;settle();return needed end
	flush()
	local function node(id)return assert(Node.findById(document,id),id)end

	local function status(id,value)
		local actual=Node.textContent(node(id));assert(actual==value,id..": "..actual.." ~= "..value)
	end
	local function compare(case)
		for _,sample in case.state.results do status(sample.id,sample.text)end
		for _,sample in case.state.dialogs do
			local native=tree.DialogsByNode[node(sample.id)]
			assert(native.Open==sample.open and native.Modal==sample.modal,sample.id.." native mode")
			local outer=if native.Box.OpacityGroup then native.Box.OpacityGroup.Gui else native.Box.Gui
			assert(outer.Visible==sample.open,sample.id.." native visibility")
		end
		for _,sample in case.state.popovers do
			local native=tree.PopoversByNode[node(sample.id)]
			assert(native.Open==sample.open,sample.id.." native open state")
			local outer=if native.Box.OpacityGroup then native.Box.OpacityGroup.Gui else native.Box.Gui
			assert(outer.Visible==sample.open,sample.id.." native visibility")
			assert((tree.CSSStates['popover-open'][node(sample.id)]==true)==sample.open,sample.id.." selector state")
		end
		for _,sample in case.state.checked do assert(page.FormModel:Resolve(node(sample.id)).Checked==sample.value,sample.id.." checked state")end
		assert(page.FormModel:Resolve(node("project-note")).Value==case.state.project,"Native project value")
		local recorded=(node("timing-bar").Attributes.class or ""):find("recorded",1,true)~=nil
		assert(recorded==case.state.bar,"Timing class state")
		-- Opening dialogs must actually move native focus into their controls.
		if case.action=="dialog-open"then assert(page.FormModel:GetActiveElement()==node("project-note"),"Native autofocus")end
		if case.action=="guard-open"then assert(page.FormModel:GetActiveElement()==node("guard-allow"),"Native checkbox autofocus")end
		if case.action=="dialog-confirm"then assert(page.FormModel:GetActiveElement()==node("dialog-open"),"Native dialog focus restoration")end
	end
	for _,case in browserStates do
		if case.action then
			local target=node(case.action);local c=assert(page.FormModel:Resolve(target),case.action)
			local gui=c.Item.BoxGui or c.Item.Gui
			nativeBounds()
			if not tree.ActiveModal and not gui:GetAttribute("HTMLPageOverlay")then root.CanvasPosition=Vector2.new(0,math.max(0,gui.AbsolutePosition.Y+root.CanvasPosition.Y-20))end
			ViewportLayer.update(tree,root);nativeBounds()
			local p,s=gui.AbsolutePosition,gui.AbsoluteSize;local point=Vector2.new(p.X+s.X/2,p.Y+s.Y/2)
			local hit=HitTest.pick(objectsAt(point.X,point.Y),tree.HitNodes,root,point,tree.HitStyles)
			local hitControl=hit and page.FormModel:Resolve(hit)
			assert(hitControl==c,case.action.." must be reachable by native mouse hit testing")
			local event={UserInputType=Enum.UserInputType.MouseButton1,Position=point}
			input.InputBegan:Fire(event,false);input.InputEnded:Fire(event,false)
		end
		settle();compare(case)
	end
	-- Native Escape and pointer dismissal execute the same JS algorithms.
	local opened=realm.TopLayer:NativeAction("show-modal",node("project-dialog"));assert(opened);settle()
	assert(tree.ActiveModal.Node==node("project-dialog"));assert(realm.TopLayer:Escape());settle()
	assert(not tree.DialogsByNode[node("project-dialog")].Open and tree.ActiveModal==nil)
	local show=realm.TopLayer:NativeAction("show-popover",node("material-popover"));assert(show);settle()
	assert(realm.TopLayer:Escape());settle();assert(not tree.PopoversByNode[node("material-popover")].Open)
	-- A newly inserted top-layer element obtains native resources; removal
	-- clears stale focus/input blockers even before the GUI is reconciled.
	run([[const fresh=document.createElement('dialog');fresh.id='fresh-dialog';fresh.innerHTML='<button id="fresh-close">Close</button>';document.body.append(fresh);fresh.showModal();]])
	settle();local freshNode=node("fresh-dialog");assert(tree.ActiveModal and tree.ActiveModal.Node==freshNode)
	run([[fresh.remove();]]);settle();assert(tree.ActiveModal==nil and not tree.DialogsByNode[freshNode])
	-- Attribute conversion reuses the existing GUI and returns it to flow.
	run([[const dynamic=document.createElement('div');dynamic.id='dynamic-popover';dynamic.textContent='Hint';document.body.append(dynamic);]])
	settle();local dynamic=node("dynamic-popover");local box=tree.NodeBoxes[dynamic];local gui=box.Gui
	run([[dynamic.popover='manual';dynamic.showPopover();]]);settle()
	assert(tree.NodeBoxes[dynamic]==box and box.Gui==gui and tree.PopoversByNode[dynamic].Open,"Convert retained GUI to popover")
	run([[dynamic.removeAttribute('popover');]]);settle()
	assert(tree.PopoversByNode[dynamic]==nil and not box.TopLayer and box.TopLayerParent==nil and box.Gui.Parent~=tree.PopoverHost.Layer and box.Gui.Parent~=tree.DialogHost.Layer,"Popover returns to document flow")
	assert(not box.TopLayerActive and not box.LayoutAsTopLayer and not box.TopLayerHidden and box.OuterHeight>0,"Removed popover attribute clears layout exclusions")
	assert(realm.EventLoop.FrameCount==0 and realm.EventLoop.TimerCount==0,"No continuous top-layer or observer work")
	page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end
	assert(not realm.Alive and realm.EventLoop.TaskCount==0 and services.RunService.RenderStepped:Count()==0,"Input, observers and queued events dispose")
	print("Dialog/popover/performance comparison: "..#browserStates.." real browser states via native mouse hit testing, focus/form/paint, Escape, dynamic resources and cleanup passed")
end
