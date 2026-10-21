--!strict
return function(Popup,Parser,Node,State,FormModel,Events,Controller,HTMLScripts,loadRenderTree,loadWordLayout,loadBlockLayout)
	local signals,objects={},{};local nativeFocus;local counts={Creates=0,Destroys=0,Layouts=0};local factory={}
	local function signal()
		local entries={};local api={};table.insert(signals,api)
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function api:Fire(...)for _,pair in table.clone(entries)do if pair[1].Connected then pair[2](...)end end end
		function api:Count()local n=0;for _,pair in entries do if pair[1].Connected then n+=1 end end;return n end
		return api
	end
	function factory.create(class,parent,properties)
		local values={ClassName=class,Parent=parent,Visible=true,CanvasPosition=Vector2.new(0,0)};for k,v in properties or{}do values[k]=v end
		local changes,attributes={},{};local gui;gui=setmetatable({},{__index=function(_,key)
			if key=='AbsoluteSize'then
				if values.AbsoluteSize then return values.AbsoluteSize end
				local size=values.Size or {0,0};local ps=values.Parent and values.Parent.AbsoluteSize or Vector2.new(0,0)
				return Vector2.new(size[1]+(size.XScale or 0)*ps.X,size[2]+(size.YScale or 0)*ps.Y)
			elseif key=='AbsolutePosition'then
				if values.AbsolutePosition then return values.AbsolutePosition end
				local pos=values.Position or {0,0};local pp=values.Parent and values.Parent.AbsolutePosition or Vector2.new(0,0);local ps=values.Parent and values.Parent.AbsoluteSize or Vector2.new(0,0);local size=gui.AbsoluteSize;local anchor=values.AnchorPoint or Vector2.new(0,0)
				return Vector2.new(pp.X+pos[1]+(pos.XScale or 0)*ps.X-size.X*anchor.X,pp.Y+pos[2]+(pos.YScale or 0)*ps.Y-size.Y*anchor.Y)
			end
			return values[key]
		end,__newindex=function(_,key,value)local old=values[key];values[key]=value;if old~=value and changes[key]then changes[key]:Fire()end end})
		function values:GetPropertyChangedSignal(key)changes[key]=changes[key]or signal();return changes[key]end
		function values:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
		function values:SetAttribute(key,value)attributes[key]=value end;function values:GetAttribute(key)return attributes[key]end
		function values:IsA(kind)return class==kind or kind=='GuiObject'end
		values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
		function values:IsFocused()return nativeFocus==self end
		function values:CaptureFocus()if nativeFocus==self then return end;local old=nativeFocus;nativeFocus=self;if old then old.FocusLost:Fire(false)end;self.Focused:Fire()end
		function values:ReleaseFocus()if nativeFocus~=self then return end;nativeFocus=nil;self.FocusLost:Fire(false)end
		function values:Destroy()assert(not self.Destroyed,'Color picker double destruction');if nativeFocus==self then self:ReleaseFocus()end;self.Destroyed=true;counts.Destroys+=1;for _,child in objects do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(objects,gui);counts.Creates+=1;return gui
	end
	factory.modifier=factory.create
	local function find(name)for i=#objects,1,-1 do if objects[i].Name==name and not objects[i].Destroyed then return objects[i]end end;error('Missing '..name)end
	local parent=factory.create('Frame',nil,{AbsolutePosition=Vector2.new(12,24),AbsoluteSize=Vector2.new(800,600)})
	local root=factory.create('ScrollingFrame',parent,{AbsolutePosition=Vector2.new(12,24),AbsoluteSize=Vector2.new(800,600)})
	local document=Parser.parseDocument('<form><input id=color type=color value=#c7e5f0 readonly><input id=other></form>')
	local c=State.create(Node.findById(document,'color'));assert(c.ReadOnly==false,'readonly does not apply to color wells')
	c.Item={BoxGui=factory.create('Frame',root,{AbsolutePosition=Vector2.new(50,55),AbsoluteSize=Vector2.new(50,27)})}
	local events=Events.new(error);local history={};local model=FormModel.new(document,{c},events,function()end)
	for _,kind in {'input','change'}do events:On(c.Node,kind,function()table.insert(history,kind..':'..c.Value)end)end
	local page={Alive=true,Root=root};local opens={}
	function page:SetControlPickerOpen(owner,open)assert(owner==c);table.insert(opens,open)end
	local picker=Popup.new(page,function(owner,value)model:SetValue(owner,value,true)end,function(owner)model:Emit(owner,'change')end,factory)
	assert(picker:Open(c));local host=find('ColorPicker');assert(host.Visible and host.AbsoluteSize.X==234 and host.AbsoluteSize.Y==251 and host.AbsolutePosition.X==50 and host.AbsolutePosition.Y==82)
	assert(find('ColorPlane').AbsoluteSize.Y==139 and find('ColorChannel1').Text=='199' and find('ColorChannel2').Text=='229' and find('ColorChannel3').Text=='240')
	local initialObjects=counts.Creates;local initialBox=c.Item.BoxGui
	local function event(gui,x,y,kind)return {UserInputType=kind or Enum.UserInputType.MouseButton1,Position=Vector2.new(gui.AbsolutePosition.X+x,gui.AbsolutePosition.Y+y)}end
	local plane=find('ColorPlane');local down=event(plane,234,0);down.Position.X-=.001;assert(picker:Begin(down));assert(#history==1 and history[1]:sub(1,6)=='input:')
	local move={UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(plane.AbsolutePosition.X+400,plane.AbsolutePosition.Y+400)};assert(picker:Move(move));assert(c.Value=='#000000')
	assert(picker:Move(move)and #history==2,'Repeated coordinates do not emit duplicate input')
	assert(picker:Finish({UserInputType=Enum.UserInputType.MouseButton1,Position=move.Position}));assert(picker.Control==c)
	assert(counts.Creates==initialObjects and initialBox==c.Item.BoxGui,'Dragging retains all native widgets and the well')
	assert(picker:Key('Escape'));assert(history[#history]=='change:#000000' and opens[#opens]==false and host.Destroyed)
	local before=#history;assert(picker:Open(c));picker:Close();assert(#history==before,'Opening and closing unchanged color is silent')
	assert(picker:Open(c));local field=find('ColorChannel1');field:CaptureFocus();field.Text='255';assert(c.Value=='#ff0000');field.Text='999';assert(c.Value=='#ff0000');field.Text='';assert(c.Value=='#ff0000');field:ReleaseFocus();assert(field.Text=='255')
	field:CaptureFocus();field.Text='12';assert(c.Value=='#0c0000');assert(picker:Key('Up')and c.Value=='#0d0000');assert(picker:Key('Return'));assert(nativeFocus==nil and history[#history]=='change:#0d0000')
	assert(picker:Open(c));local format=find('ColorFormat');local e=event(format,12,8);assert(picker:Begin(e)and picker:Finish(e));assert(find('ColorChannelLabel1').Text=='H')
	field=find('ColorChannel1');field:CaptureFocus();field.Text='120';field:ReleaseFocus();field=find('ColorChannel2');field:CaptureFocus();field.Text='100';field:ReleaseFocus();field=find('ColorChannel3');field:CaptureFocus();field.Text='50';field:ReleaseFocus();assert(c.Value=='#00ff00')
	e=event(format,12,8);picker:Begin(e);picker:Finish(e);assert(find('ColorChannelLabel1').Text=='HEX'and not find('ColorChannel2').Visible)
	field=find('ColorChannel1');field:CaptureFocus();field.Text='ABCDEF';assert(c.Value=='#abcdef');field.Text='broken';assert(c.Value=='#abcdef');field:ReleaseFocus();assert(field.Text=='#ABCDEF')
	assert(picker:Key('Tab')and picker:Key('Space'));assert(find('ColorChannelLabel1').Text=='R');picker:Close()
	assert(picker:Open(c));local hue=find('ColorHue');local touch=event(hue,65,6,Enum.UserInputType.Touch);assert(picker:Begin(touch));local other=event(hue,0,6,Enum.UserInputType.Touch);local kept=c.Value;picker:Move(other);picker:Finish(other);assert(c.Value==kept)
	other.Position=Vector2.new(-100,-100);assert(picker:Begin(other)and picker:Move(other)and picker:Finish(other)and picker.Control==c and c.Value==kept,'A second touch outside cannot interrupt the captured color drag')
	touch.Position=Vector2.new(hue.AbsolutePosition.X-20,hue.AbsolutePosition.Y);assert(picker:Move(touch)and picker:Finish(touch));assert(picker:Begin({UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(0,0)})==false and picker.Control==nil)
	assert(picker:Open(c));before=#history;c.Value='#123456';picker:Refresh();picker:Close();assert(#history==before,'Programmatic changes do not synthesize events')
	c.Disabled=true;assert(not picker:Open(c));c.Disabled=false;assert(picker:Open(c));host=find('ColorPicker');c.Item.BoxGui.AbsolutePosition=Vector2.new(790,590);assert(host.Destroyed and picker.Control==nil)
	assert(picker:Open(c));host=find('ColorPicker');assert(host.AbsolutePosition.X+234<=812 and host.AbsolutePosition.Y+251<=624);picker:Close()
	root.AbsoluteSize=Vector2.new(180,200);assert(picker:Open(c));host=find('ColorPicker');local scale
	for _,gui in objects do if gui.Parent==host and gui.ClassName=='UIScale'then scale=gui.Scale end end
	assert(scale and scale<1 and host.AbsolutePosition.X+234*scale<=192);picker:Close()
	model:Destroy();events:Destroy();parent:Destroy()
	for _,sig in signals do assert(sig:Count()==0,'Standalone picker signal leak')end

	-- The mounted adapter drives the actual DOM value, JS listeners and paint path.
	table.clear(objects);table.clear(signals);counts.Creates,counts.Destroys=0,0
	parent=factory.create('Frame',nil,{AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(800,600)});root=factory.create('ScrollingFrame',parent,{AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(800,600)})
	document=Parser.parseDocument('<button id=launch>Open</button><input id=color type=color value=#c7e5f0><input id=other><script>var trace=[];var well=document.getElementById("color");well.addEventListener("input",function(){trace.push("input:"+well.value)});well.addEventListener("change",function(){trace.push("change:"+well.value)});document.getElementById("launch").addEventListener("click",function(){well.showPicker()});</script>')
	local tree=loadRenderTree(factory).build(document,root,error)
	local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*7,size)end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);layout.arrange(tree,800,0,0,function()return true end)
	page={Alive=true,Root=root,Document=document,DocumentURL='http://localhost:8000/color/',BaseURL='http://localhost:8000/color/',Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return nativeFocus end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode()return''end
	local controller=Controller.start(page,tree,function()counts.Layouts+=1 end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Task={defer=function(fn)fn();return{}end,cancel=function()end}})
	local realm=HTMLScripts.start(page,tree,function()end,error,{JavaScriptServices={Clock=function()return 0 end,RunService={RenderStepped=signal(),Heartbeat=signal()},Task={delay=function(_,fn)return{Callback=fn}end,cancel=function()end}}})
	page.JavaScriptRuntime=realm
	local function run(code)local ok=realm:Run(code);assert(ok);realm:Flush()end
	local leakedEvents=0
	for _,kind in {'keydown','keyup','pointerdown','pointermove','pointerup'}do page.Events:On(document,kind,function()leakedEvents+=1 end)end
	local function key(name)
		input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode[name]},false)
		input.InputEnded:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode[name]},false)
	end
	c=page.FormModel:Resolve(Node.findById(document,'color'));initialBox=c.Item.BoxGui
	page.FormModel:Activate(page.FormModel:Resolve(Node.findById(document,'launch')),nil,false)
	realm:Flush();host=find('ColorPicker');assert(page.FormModel.UserActivationUntil==0 and tree.CSSStates.open==c.Node)
	field=find('ColorChannel1');input.InputBegan:Fire(event(field,5,5),false);field.Text='31';realm:Flush();assert(c.Value=='#1fe5f0');assert(c.Item.ColorSwatch.BackgroundColor3==Color3.fromRGB(31,229,240))
	key('Escape');assert(host.Destroyed and nativeFocus==nil and tree.CSSStates.open==nil)
	assert(leakedEvents==0,'Picker-native input does not leak to the document beneath it')
	run('globalThis.actual=trace.join("|")');assert(realm.Window.Get('actual')=='input:#1fe5f0|change:#1fe5f0')
	assert(c.Item.BoxGui==initialBox and counts.Layouts==0,'Color interaction changes paint without layout')
	-- Native activation, keyboard activation, disabled state and pending cleanup.
	page.FormModel:Activate(c,nil,false);host=find('ColorPicker');field=find('ColorChannel2');input.InputBegan:Fire(event(field,5,5),false);field.Text='64';key('Return');assert(host.Destroyed)
	page.FormModel:Focus(c);key('Space');host=find('ColorPicker')
	run('well.disabled=true');page:RefreshDOMControls();assert(host.Destroyed);run('well.disabled=false');page:RefreshDOMControls()
	page.FormModel:OpenColor(c);host=find('ColorPicker');run('well.value="#112233"');assert(find('ColorChannel1').Text=='17');key('Escape')
	run('globalThis.before=trace.length;try{well.showPicker()}catch(e){globalThis.failure=e.name}');assert(realm.Window.Get('failure')=='NotAllowedError')
	page.FormModel.UserActivationUntil=0;run('well.click()');assert(tree.CSSStates.open==nil,'Unactivated scripted clicks do not open a color picker')
	page.FormModel:OpenColor(c);host=find('ColorPicker');run('well.remove()');page:RefreshDOMControls();assert(host.Destroyed,'Removing the owner releases the popup')
	run('document.body.appendChild(well)');page:RefreshDOMControls();c=page.FormModel:Resolve(Node.findById(document,'color'))
	page.FormModel:OpenColor(c);host=find('ColorPicker');page.Alive=false;realm:Destroy();controller();assert(host.Destroyed)
	for _,cleanup in tree.Cleanups or{}do cleanup()end;parent:Destroy()
	for _,sig in signals do assert(sig:Count()==0,'Mounted color picker signal leak')end
	assert(counts.Creates==counts.Destroys,'Mounted picker resources released')
	print('Color picker: RGB/HSL/HEX, pointer capture/clamping, live DOM input, commit, keyboard, showPicker, paint retention, viewport and cleanup passed')
end
