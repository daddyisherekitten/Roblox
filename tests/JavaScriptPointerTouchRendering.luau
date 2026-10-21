--!strict
-- Exercise native signals through the real controller, renderer and JS bridge.
return function(Parser,Node,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,Controller)
	local originalBackspace=Enum.KeyCode.Backspace
	local originalWheel=Enum.UserInputType.MouseWheel
	if not originalWheel then Enum.UserInputType.MouseWheel='MouseWheel'end
	if not originalBackspace then Enum.KeyCode.Backspace={Name='Backspace',Value=8}end
	local function signal()
		local entries={};local s={}
		function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function s:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		function s:Count()local count=0;for _,entry in entries do if entry[1].Connected then count+=1 end end;return count end
		return s
	end
	local focused;local guis,deferred={},{};local factory={}
	function factory.create(class,parent,props)
		local changes,attributes={},{};local values={ClassName=class,Parent=parent,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(500,500),Text='',CursorPosition=-1,SelectionStart=-1}
		for key,value in props do values[key]=value end
		if class=='ScrollingFrame'then values.CanvasPosition=Vector2.new(0,0);values.ScrollingEnabled=true end
		local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)local before=values[key];values[key]=value;if before~=value and changes[key]then changes[key]:Fire()end end})
		values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
		function values:GetPropertyChangedSignal(key)if not changes[key]then changes[key]=signal()end;return changes[key]end
		function values:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
		function values:SetAttribute(key,value)attributes[key]=value;if changes['attribute:'..key]then changes['attribute:'..key]:Fire()end end
		function values:GetAttribute(key)return attributes[key]end
		function values:IsA(kind)return kind==class or kind=='GuiObject'end
		function values:IsFocused()return focused==gui end
		function values:CaptureFocus()if focused and focused~=gui then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
		function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
		function values:Destroy()values.Destroyed=true;for _,child in guis do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument('<html><body><div id="a" style="width:160px;height:80px">Drag source</div><div id="b" style="width:160px;height:80px">Drag target</div><input id="edit" value="Hé"><input id="number" type="number" value="12"><input id="disabled" value="safe" readonly><script>globalThis.boot=1;</script></body></html>')
	local viewport=factory.create('Frame',nil,{AbsolutePosition=Vector2.new(0,0)});local root=factory.create('ScrollingFrame',viewport,{AbsoluteWindowSize=Vector2.new(500,500)})
	local messages,diagnostics={},{};local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end)
	Dirty.begin(tree);layout.arrange(tree,500,0,0,function()return true end);Dirty.finish(tree,true)
	local page={Alive=true,Document=document,DocumentURL='https://example.test/input',BaseURL='https://example.test/input',Root=root,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local hitGui;local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end
	local runService={RenderStepped=signal()};local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return if hitGui then {hitGui}else {}end},Factory=factory,Clock=function()return 0 end,RunService=runService,Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	Controller.start(page,tree,function()end,error,services)
	local realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
	function page:HasPendingLayout()return false end
	function page:FlushScriptLayout()
		local needed,items=realm:Flush()
		if needed then Dirty.begin(tree,items);layout.arrange(tree,500,0,0,function()return true end);Dirty.finish(tree,true)end
		return needed
	end
	function page:GeometryViewport()return {Width=500,Height=500,X=0,Y=0,ScrollX=root.CanvasPosition.X,ScrollY=root.CanvasPosition.Y,ScrollWidth=500,ScrollHeight=tree.Height or 500}end
	local function healthy()assert(#diagnostics==0,table.concat(diagnostics,' | '));assert(#messages==0,table.concat(messages,' | '))end
	local function run(source)realm:Run(source);healthy()end
	local function settle()for _=1,32 do local work=deferred;deferred={};for _,fn in work do fn()end;local count=realm:PumpTasks();if #deferred==0 and count==0 then break end end;healthy()end
	local function node(id)return assert(Node.findById(document,id))end
	local function target(id)hitGui=if id then tree.NodeBoxes[node(id)].Gui else nil end
	local function position(x,y)return setmetatable(Vector2.new(x,y),{__sub=function(a,b)return {X=a.X-b.X,Y=a.Y-b.Y,Magnitude=math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)}end})end
	local function pointer(kind,x,y)return {UserInputType=kind,Position=position(x or 20,y or 30),Delta=Vector2.new(0,0)}end
	run([[const a=document.getElementById('a'),b=document.getElementById('b');globalThis.log=[];
	 a.onpointerdown=e=>{log.push('down:'+e.pointerType);a.setPointerCapture(e.pointerId);};a.ongotpointercapture=e=>log.push('got');a.onpointermove=e=>log.push('move:'+e.target.id);a.onpointerup=e=>log.push('up');a.onlostpointercapture=e=>log.push('lost');a.onclick=e=>log.push('click');]])
	target('a');input.InputBegan:Fire(pointer(Enum.UserInputType.MouseButton1),false)
	target('b');input.InputChanged:Fire(pointer(Enum.UserInputType.MouseMovement,90,35));input.InputEnded:Fire(pointer(Enum.UserInputType.MouseButton1,90,35),false)
	run([[if(log.join('|')!=='down:mouse|got|move:a|up|lost|click')throw new Error(log.join('|'));]])
	-- A different capture target receives click and fresh viewport coordinates.
	run([[globalThis.captureClicks=0;globalThis.captureMoves=[];a.onpointerdown=e=>b.setPointerCapture(e.pointerId);a.onclick=()=>{throw new Error('Old down target click')};b.onclick=e=>{if(e.target!==b)throw new Error('Captured click target');captureClicks++};b.onpointermove=e=>{captureMoves.push([e.clientX,e.clientY,e.pageX,e.pageY].join(':'));b.style.transform='translateX('+e.clientX+'px)'};]])
	local targetBox=tree.NodeBoxes[node('b')];local baseLeft=targetBox.Gui.Position[1]-(targetBox.Gui.AnchorPoint and targetBox.Gui.AnchorPoint.X or 0)*targetBox.Gui.Size[1];local originalGui=targetBox.Gui
	root.AbsolutePosition=Vector2.new(15,10);root.CanvasPosition=Vector2.new(4,25);root.AbsoluteSize=Vector2.new(320,500)
	target('a');input.InputBegan:Fire(pointer(Enum.UserInputType.MouseButton1),false);target('a');input.InputChanged:Fire(pointer(Enum.UserInputType.MouseMovement,90,35));page:FlushScriptLayout()
	local paintedLeft=targetBox.Gui.Position[1]-(targetBox.Gui.AnchorPoint and targetBox.Gui.AnchorPoint.X or 0)*targetBox.Gui.Size[1]
	assert(targetBox.Gui==originalGui and math.abs(paintedLeft-baseLeft-75)<.0001,'Captured coordinates after viewport movement must paint the retained native GUI, not only update a style string: '..tostring(baseLeft)..' -> '..tostring(paintedLeft))
	input.InputEnded:Fire(pointer(Enum.UserInputType.MouseButton1,90,35),false)
	run([[if(captureMoves.join('|')!=='75:25:79:50'||captureClicks!==1)throw new Error('Capture after resize/scroll '+captureMoves.join('|')+'/'+captureClicks);b.style.transform='none';a.onpointerdown=e=>a.setPointerCapture(e.pointerId);globalThis.moveCapture=0;a.onpointermove=e=>{if(e.target!==a)throw new Error('Moved capture');moveCapture++};]])
	page:FlushScriptLayout();target('a');input.InputBegan:Fire(pointer(Enum.UserInputType.MouseButton1),false)
	local capturedGui=tree.NodeBoxes[node('a')].Gui
	run("document.body.moveBefore(a,null);");page:FlushScriptLayout();page:RefreshDOMControls();settle()
	assert(page.PointerCapture:Has(node('a'),1)and tree.NodeBoxes[node('a')].Gui==capturedGui,'moveBefore must preserve pending/active capture and retained GUI identity')
	target('b');input.InputChanged:Fire(pointer(Enum.UserInputType.MouseMovement,90,35));run([[if(moveCapture!==1)throw new Error('Preserved move capture')]]);
	run("a.remove();document.body.append(a);if(a.hasPointerCapture(1))throw new Error('Reinserted capture');");page:FlushScriptLayout();page:RefreshDOMControls()
	input.InputChanged:Fire(pointer(Enum.UserInputType.MouseMovement,90,35));input.InputEnded:Fire(pointer(Enum.UserInputType.MouseButton1,90,35),false)
	run([[globalThis.boundary=[];globalThis.stationaryMoves=0;a.onpointermove=()=>stationaryMoves++;b.onpointermove=()=>stationaryMoves++;a.onpointerover=e=>boundary.push('a:'+e.clientX+':'+e.pageY);]])
	target('a');root.CanvasPosition=Vector2.new(5,6);settle()
	run([[if(boundary.join('|')!=='a:75:31'||stationaryMoves!==0)throw new Error('Stationary boundary '+boundary.join('|')+'/'+stationaryMoves);]])
	root.AbsolutePosition=Vector2.new(0,0);root.CanvasPosition=Vector2.new(0,0);root.AbsoluteSize=Vector2.new(500,500);settle()
	-- Wheel is a trusted native WheelEvent; cancellation gates native scrolling
	-- until this input dispatch is over and preserves preexisting disabled state.
	run([[globalThis.wheels=[];a.onwheel=e=>{if(!(e instanceof WheelEvent)||!e.isTrusted||!e.cancelable)throw new Error('Native wheel');wheels.push([e.deltaMode,e.deltaY,e.clientX,e.clientY].join(':'));e.preventDefault()};]])
	target('a');local wheel=pointer(Enum.UserInputType.MouseWheel);wheel.Position.Z=1;input.InputChanged:Fire(wheel)
	assert(not root.ScrollingEnabled,'Canceled wheel must gate the native scroll widget during input dispatch');settle();assert(root.ScrollingEnabled,'Wheel gate must release without another input')
	root.ScrollingEnabled=false;input.InputChanged:Fire(wheel);settle();assert(not root.ScrollingEnabled,'Canceled wheel must preserve a disabled native scroll widget');root.ScrollingEnabled=true
	run([[if(wheels.join('|')!=='1:-3:20:30|1:-3:20:30')throw new Error('Wheel units '+wheels.join('|'));a.onwheel=null;a.onpointerdown=null;b.onpointermove=null;b.onpointerover=null;a.onclick=null;]])
	-- Canceling pointerdown suppresses mouse compatibility, never the click event.
	run([[globalThis.mouse=0;globalThis.clicks=0;a.onpointerdown=e=>{e.preventDefault();};a.onmousedown=()=>mouse++;a.onmouseup=()=>mouse++;a.onclick=()=>clicks++;]])
	target('a');input.InputBegan:Fire(pointer(Enum.UserInputType.MouseButton1),false);input.InputEnded:Fire(pointer(Enum.UserInputType.MouseButton1),false)
	run([[if(mouse!==0||clicks!==1)throw new Error('Pointer compatibility suppression '+mouse+'/'+clicks);]])
	-- Native contacts retain their original Touch.target despite capture changes.
	run([[globalThis.touch=[];globalThis.touchClicks=0;a.onpointerdown=e=>{b.setPointerCapture(e.pointerId);};a.onclick=()=>touchClicks++;b.onclick=()=>touchClicks++;
	 a.ontouchstart=e=>{touch.push('start:'+e.touches.length+':'+e.changedTouches[0].target.id);e.preventDefault();};a.ontouchmove=e=>{touch.push('move:'+e.touches.length+':'+e.targetTouches.length+':'+e.changedTouches[0].target.id);globalThis.oldTouch=e.changedTouches[0];};a.ontouchend=e=>touch.push('end:'+e.touches.length+':'+e.changedTouches.length);]])
	local t1,t2=pointer(Enum.UserInputType.Touch,20,30),pointer(Enum.UserInputType.Touch,40,50)
	target('a');input.InputBegan:Fire(t1,false);assert(root.ScrollingEnabled==false,'Canceling touchstart locks native page scrolling even with touch-action:auto')
	target('b');input.InputBegan:Fire(t2,false);t1.Position=position(50,60);input.InputChanged:Fire(t1);input.InputEnded:Fire(t1,false)
	assert(root.ScrollingEnabled==false,'A second active contact keeps the original scroll lock alive')
	input.InputEnded:Fire(t2,false);assert(root.ScrollingEnabled==true,'The last contact releases the original scroll setting')
	run([[if(touch.join('|')!=='start:1:a|move:2:1:a|end:1:1'||touchClicks!==0||oldTouch.clientX!==50)throw new Error('Native touch session '+touch.join('|')+'/'+touchClicks);]])
	-- Window focus loss terminates every contact and restores exact scroll state.
	run([[globalThis.cancels=0;a.onpointercancel=()=>cancels++;b.onpointercancel=()=>cancels++;a.ontouchcancel=()=>cancels++;a.ontouchstart=e=>e.preventDefault();]])
	root.ScrollingEnabled=false;target('a');local canceledTouch=pointer(Enum.UserInputType.Touch);input.InputBegan:Fire(canceledTouch,false);input.WindowFocusReleased:Fire()
	assert(not root.ScrollingEnabled and not page.PointerCapture:IsActive(4),'Focus loss preserves disabled scrolling and discards active pointer sessions')
	run([[if(cancels!==2)throw new Error('Native cancellation '+cancels);]])
	-- A contact beginning during a deferred wheel gate must snapshot the actual
	-- pre-wheel setting, otherwise ending the contact leaves scrolling stuck.
	root.ScrollingEnabled=true
	run([[a.onpointerdown=null;a.onwheel=e=>e.preventDefault();a.ontouchstart=e=>e.preventDefault();]])
	target('a');input.InputChanged:Fire(wheel);local overlappedTouch=pointer(Enum.UserInputType.Touch);input.InputBegan:Fire(overlappedTouch,false);settle()
	assert(not root.ScrollingEnabled,'A deferred wheel release must not override the active touch gate')
	input.InputEnded:Fire(overlappedTouch,false);assert(root.ScrollingEnabled,'The last touch must restore the setting from before the overlapping wheel gate')
	run([[a.onwheel=null;a.ontouchstart=null;]])
	local edit=assert(page.FormModel:Resolve(node('edit')));local editor=edit.Item.Editor
	run([[const edit=document.getElementById('edit');globalThis.edits=[];globalThis.compositions=0;for(const kind of ['compositionstart','compositionupdate','compositionend'])edit.addEventListener(kind,()=>compositions++);
	 edit.onbeforeinput=e=>{edits.push('before:'+e.inputType+':'+e.data+':'+edit.value+':'+e.isComposing);if(e.data==='!')e.preventDefault();};edit.oninput=e=>edits.push('input:'+e.inputType+':'+e.data+':'+edit.value+':'+e.isComposing);edit.focus();]])
	editor.Text='Hé森';settle();assert(edit.Value=='Hé森')
	editor.Text='Hé森!';settle();assert(editor.Text=='Hé森'and edit.Value=='Hé森','Cancelable beforeinput restores native editor and DOM value without input')
	local backspace={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Backspace}
	input.InputBegan:Fire(backspace,false);editor.Text='Hé';input.InputEnded:Fire(backspace,false);settle()
	run([[if(edits.join('|')!=='before:insertText:森:Hé:false|input:insertText:森:Hé森:false|before:insertText:!:Hé森:false|before:deleteContentBackward:null:Hé森:false|input:deleteContentBackward:null:Hé:false'||compositions!==0)throw new Error('Text input '+edits.join('|'));edit.value='script';]])
	assert(edit.Value=='script'and editor.Text=='script');settle()
	run([[if(edits.length!==5)throw new Error('Script value writes do not emit native input');edit.onbeforeinput=()=>{edit.value='author';};]])
	editor.Text='scriptZ';settle();assert(edit.Value=='author'and editor.Text=='author','An author value mutation during beforeinput is not overwritten by the old native edit')
	run([[edit.onbeforeinput=null;edit.onkeydown=e=>e.preventDefault();globalThis.preventedInputs=0;edit.oninput=()=>preventedInputs++;]])
	input.InputBegan:Fire(backspace,false);editor.Text='autho';input.InputEnded:Fire(backspace,false);settle()
	assert(edit.Value=='author'and editor.Text=='author','Canceling keydown restores native text edits before beforeinput/input')
	run([[if(preventedInputs!==0)throw new Error('Canceled key edit');edit.onkeydown=null;]])
	local readonly=page.FormModel:Resolve(node('disabled'));readonly.Item.Editor.Text='bad';assert(readonly.Value=='safe'and readonly.Item.Editor.Text=='safe','Readonly native text edits restore without author input events')
	run([[const number=document.getElementById('number');globalThis.numberEvents=[];number.oninput=e=>numberEvents.push(e.inputType+':'+e.data+':'+number.value);number.focus();]])
	local number=page.FormModel:Resolve(node('number'));number.Item.Editor.Text='12x';settle()
	assert(number.Value==''and number.EditText=='12x'and number.BadInput,'Number input preserves its invalid native draft while the DOM value is sanitized')
	run([[if(numberEvents.join('|')!=='insertText:x:')throw new Error('Number input draft '+numberEvents.join('|'));]])
	run([[globalThis.focusHost=document.createElement('div');focusHost.id='focus-host';globalThis.focusRoot=focusHost.attachShadow({mode:'closed',delegatesFocus:true});const inner=document.createElement('input');inner.id='focus-inner';inner.value='inside';focusRoot.append(inner);document.body.append(focusHost);]])
	page:FlushScriptLayout();page:RefreshDOMControls();settle()
	run([[focusHost.focus();if(document.activeElement!==focusHost||focusRoot.activeElement.id!=='focus-inner')throw new Error('Native delegated shadow focus');focusHost.blur();if(focusRoot.activeElement!==null)throw new Error('Native delegated shadow blur');]])
	assert(realm.EventLoop.FrameCount==0,'Pointer, touch and text editing create no animation frame polling')
	page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end
	assert(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0 and input.WindowFocusReleased:Count()==0,'Disposal removes every native input subscription')
	Enum.KeyCode.Backspace=originalBackspace
	Enum.UserInputType.MouseWheel=originalWheel
	print('Mounted pointer/touch input: capture, click suppression, multi-contact targets, scroll lock lifetime, native cancellation, beforeinput rollback, Unicode and number drafts passed')
end
