--!nonstrict
-- Standalone window system. Content modules are supplied by the application.
local Signal=require(script.Signal)
local Gui=require(script.Gui)
local Layers=require(script.Layers)
local Router=require(script.Router)
local Core=require(script.Windows.Manager)
local Window=require(script.Window)
local Snap=require(script.Windows.Snap)
local Geometry=require(script.Geometry)
local Glyphs=require(script.UI.Glyphs)
local Manager={};Manager.__index=Manager
function Manager.new(parent,options)
	options=options or{};local services=options.Services or{}
	Glyphs.retain()
	local self=setmetatable({Alive=true,Options=options,Records={},Closing={},ByRoot={},Connections={},Clock=services.Clock or os.clock},Manager)
	self.Gui=Gui.new(services.Create)
	self.Root=self.Gui:Make('Frame',parent,{Name='WindowManager',Size=UDim2.fromScale(1,1)})
	self.Layers=Layers.new(self.Root)
	self.Dock=self.Gui:Make('ScrollingFrame',self.Root,{Name='MinimizedWindows',Position=UDim2.new(0,0,1,-30),Size=UDim2.new(1,0,0,30),Visible=false,
		CanvasSize=UDim2.new(),CanvasPosition=Vector2.new(0,0),ScrollingDirection=Enum.ScrollingDirection.X,ScrollingEnabled=true,ScrollBarThickness=0,ZIndex=10000})
	self.Dock:SetAttribute('HTMLInputBlocker',true)
	self.PlayerGui=services.PlayerGui or game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')
	self.Input=Router.new(self,services.Input or game:GetService('UserInputService'),self.PlayerGui)
	for _,name in {'Opened','Closed','FocusChanged','Resizing','VisibilityChanged','FullscreenChanged'}do self[name]=Signal.new()end
	self.Core=Core.new({layers=self.Layers,input=self.Input,animate=options.Animations~=false})
	local function wrap(native)
		if not native then return nil end
		local window=self.Records[native]
		if not window then window=Window.new(self,native);self.Records[native]=window;self.ByRoot[window.Root]=window;self.ByRoot[window.Dock]=window end
		return window
	end
	self.Wrap=wrap
	self.Connections[1]=self.Core.windowOpened:connect(function(native)
		local window=wrap(native);self:_LayoutMinimized();self.Opened:Fire(window)
	end)
	self.Connections[2]=self.Core.windowClosed:connect(function(native)
		local window=self.Records[native];if not window then return end
		if not native.cleanup:isCleaned()then self.Closing[native]=true;native.cleanup:add(function()self.Closing[native]=nil end)end
		self.Records[native]=nil;self.ByRoot[window.Root]=nil;self.ByRoot[window.Dock]=nil;window:Release()
		self:_LayoutMinimized();self.Closed:Fire(window)
	end)
	self.Connections[3]=self.Core.focusChanged:connect(function(current,previous)
		self.Focused=wrap(current);self.FocusChanged:Fire(self.Focused,wrap(previous))
	end)
	self.Connections[4]=self.Root:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
		self.Input:Cancel();for _,window in self:GetWindows()do window:Fit()end
	end)
	self.Connections[5]=self.Root.Destroying:Connect(function()self:Destroy(true)end)
	return self
end
function Manager:GetWorkArea()local size=self.Root.AbsoluteSize;return Vector2.new(math.max(1,size.X),math.max(1,size.Y))end
function Manager:GetWindowAt(position)
	for _,object in self.PlayerGui:GetGuiObjectsAtPosition(position.X,position.Y)do
		local current=object
		while current do
			local window=self.ByRoot[current]
			if window and window.Alive and(window.Root.Visible or current==window.Dock)then return window end
			if current==self.Root then break end;current=current.Parent
		end
		if object:IsA('GuiObject')and object.Visible then return nil end
	end
	return nil
end
function Manager:CanReceivePointer(window,position)
	return self.Alive and self:GetWindowAt(position)==window and self.Input:CanReceive(window,position)
end
function Manager:_LayoutMinimized()
	local index=0;local width=math.min(180,self:GetWorkArea().X)
	for _,native in self.Core:listOpened()do
		local window=self.Records[native]
		if window then
			window.Dock.Visible=window.State=='minimized' and native:showsInTaskbar()
			if window.Dock.Visible then window.Dock.Position=UDim2.fromOffset(index*(width+4),0);window.Dock.Size=UDim2.fromOffset(width,28);index+=1 end
		end
	end
	self.Dock.CanvasSize=UDim2.fromOffset(index*(width+4),0);self.Dock.Visible=index>0
end
function Manager:Open(options)
	assert(self.Alive,'WindowManager is disposed')
	options=table.clone(options or{})
	local size=options.Size or options.size or Vector2.new(720,480)
	local minimum=options.MinSize or options.minSize or Vector2.new(320,220)
	local position=options.Position or options.position or Geometry.cascadePosition(#self.Core:listOpened(),size,self:GetWorkArea())
	position,size=Geometry.fit(position,size,minimum,self:GetWorkArea())
	local owner=options.Owner or options.owner
	if owner==false then owner=nil end
	local native=self.Core:open({title=options.Title or options.title,titleInset=options.TitleInset,appId=options.AppID or options.appId,icon=options.Icon or options.icon,
		position=position,size=size,minSize=minimum,owner=owner and(owner.Native or owner),
		resizable=options.Resizable~=false and options.resizable~=false,showMinimize=options.Minimizable~=false and options.showMinimize~=false,
		showMaximize=options.Resizable~=false and options.Maximizable~=false and options.showMaximize~=false,
		showClose=options.Closable~=false and options.showClose~=false,showInTaskbar=options.ShowInDock,
		animate=if options.Animate~=nil then options.Animate else self.Options.Animations~=false,
	})
	local window=self.Wrap(native);window.Options=options;window:Fit();return window
end
function Manager:Focus(window)
	if not self.Alive or not window or not window.Alive or window.State=='minimized'then return false end
	if not window.Native.enabled then return false end
	if not self.Input:canFocus(window.Native)then return false end
	if self.Fullscreen and self.Fullscreen~=window then self.Fullscreen:SetFullscreen(false)end
	window.Native:finishAnimation()
	self.Core:focus(window.Native);return true
end
function Manager:Close(window,external)
	if not window or not window.Alive then return false end
	if external then window.Native.animate=false end
	window.Native:close(external==true);return true
end
function Manager:GetWindows()
	local result={};for _,native in self.Core:listOpened()do local window=self.Records[native];if window then table.insert(result,window)end end
	return result
end
function Manager:GetFocused()return self.Records[self.Core:getFocused()]end
function Manager:GetOwnedWindows(window)
	local result={};for _,native in self.Core:listOwned(window.Native)do table.insert(result,self.Wrap(native))end;return result
end
function Manager:GetMinimizedWindows()
	local result={};for _,native in self.Core:listMinimized()do table.insert(result,self.Wrap(native))end;return result
end
function Manager:FindByAppID(id)return self.Wrap(self.Core:findByAppId(id))end
function Manager:FindAllByAppID(id)
	local result={};for _,native in self.Core:findAllByAppId(id)do table.insert(result,self.Wrap(native))end;return result
end
function Manager:ClearFocus()self.Core:clearFocus()end
function Manager:CloseAll()for _,window in self:GetWindows()do window:Close()end end
function Manager:ConsumesInput(event)return self.Input.Consumed[event]==true or(self.Input.Pressed~=nil and not self.Input.Pressed.Entry.Passive)end
function Manager:MessageBox(options)
	assert(self.Alive,'WindowManager is disposed')
	local cfg=table.clone(options or{})
	cfg.title=cfg.Title or cfg.title;cfg.message=cfg.Message or cfg.message;cfg.icon=cfg.Icon or cfg.icon
	cfg.buttons=cfg.Buttons or cfg.buttons;cfg.onResult=cfg.OnResult or cfg.onResult
	if cfg.Modal~=nil then cfg.modal=cfg.Modal end
	if cfg.Sound~=nil then cfg.sound=cfg.Sound end
	if cfg.Owner~=nil then cfg.owner=cfg.Owner end
	if cfg.owner then cfg.owner=cfg.owner.Native or cfg.owner end
	return self.Wrap(require(script.Dialogs.MessageBox).show(self.Core,cfg))
end
function Manager:ShowError(message,options)
	local cfg=table.clone(options or{});cfg.Message=message;cfg.Icon='error';cfg.Title=cfg.Title or cfg.title or'Error'
	return self:MessageBox(cfg)
end
function Manager:ModalDepth()return self.Core:modalDepth()end
function Manager:Beep(kind)
	assert(self.Alive,'WindowManager is disposed');require(script.Dialogs.MessageBox).beep(kind,self.Core)
end
function Manager:Destroy(external)
	if not self.Alive then return end;self.Alive=false
	self.Input:Cancel()
	for _,window in self:GetWindows()do
		local native=window.Native;native.animate=false
		if native._closing then native:disposeNow();self.Core:close(native)else native:close(true)end
	end
	for native in table.clone(self.Closing)do native:disposeNow()end
	self.Core:destroy();self.Input:Destroy();Snap.destroyPreview(self.Layers)
	Glyphs.release()
	for _,connection in self.Connections do if connection.Disconnect then connection:Disconnect()else connection:disconnect()end end
	table.clear(self.Connections);table.clear(self.ByRoot);table.clear(self.Records);table.clear(self.Closing);self.Focused=nil
	for _,name in {'Opened','Closed','FocusChanged','Resizing','VisibilityChanged','FullscreenChanged'}do self[name]:Destroy()end
	if not external then self.Root:Destroy()end
end
Manager.Geometry=Geometry
return Manager
