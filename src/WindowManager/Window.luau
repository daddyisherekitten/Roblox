--!nonstrict
-- Public host contract over the imported window implementation.
local Signal=require(script.Parent.Signal)
local Geometry=require(script.Parent.Geometry)
local Snap=require(script.Parent.Windows.Snap)
local Window={}
Window.__index=function(self,key)
	if key=='State'then local native=rawget(self,'Native');return if native.state=='normal'and native:getSnapZone()then 'snapped'else native.state end
	return Window[key]
end
function Window.new(manager,native)
	local self=setmetatable({Alive=true,Manager=manager,Native=native,ID=native.id,Root=native.frame,Content=native.content,
		Titlebar=native.titlebar.frame,Minimum=native.minSize,Options={},Connections={},Closed=Signal.new()},Window)
	self.NativeCloseRequest=function()return self:RequestClose()end
	native.requestClose=self.NativeCloseRequest
	self.CloseButton=self.Titlebar:FindFirstChild('Close')
	self.MaximizeButton=self.Titlebar:FindFirstChild('Maximize')
	self.MinimizeButton=self.Titlebar:FindFirstChild('Minimize')
	self.Root:SetAttribute('ManagedWindow',self.ID);self.Titlebar:SetAttribute('HTMLInputBlocker',true)
	self.Dock=manager.Gui:Make('Frame',manager.Dock,{Name='Window_'..self.ID,Visible=false,BackgroundTransparency=0,BackgroundColor3=Color3.fromRGB(60,60,60)})
	self.DockTitle=manager.Gui:Make('TextLabel',self.Dock,{Size=UDim2.fromScale(1,1),Text=native.title,TextTruncate=Enum.TextTruncate.AtEnd})
	self.RemoveDock=manager.Input:Bind(self.Dock,{Action=function()self:Restore()end})
	self.Connections[1]=native.closed:connect(function()
		self.Alive=false
		if manager.Fullscreen==self then manager.Fullscreen=nil end
		self.Closed:Fire();self.Closed:Destroy()
	end)
	self.Connections[2]=native.stateChanged:connect(function()
		manager:_LayoutMinimized();manager.VisibilityChanged:Fire(self,self.State~='minimized')
	end)
	self.Connections[3]=native.gestureChanged:connect(function(active)manager.Resizing:Fire(self,active)end)
	self.Connections[4]=self.Root.Destroying:Connect(function()if self.Alive then manager:Close(self,true)end end)
	return self
end
function Window:GetPosition()return self.Native:getPosition()end
function Window:GetSize()return self.Native:getSize()end
function Window:SetPosition(position)
	if not self.Alive or self.Fullscreen then return false end
	local p=Geometry.fit(position,self:GetSize(),self.Minimum,self.Manager:GetWorkArea());self.Native:setPosition(p);return true
end
function Window:SetSize(size)
	if not self.Alive or self.Fullscreen then return false end
	local p,s=Geometry.fit(self:GetPosition(),size,self.Minimum,self.Manager:GetWorkArea());self:_Rect(p,s);return true
end
function Window:_Rect(position,size)
	self.Root.Position=UDim2.fromOffset(math.round(position.X),math.round(position.Y));self.Root.Size=UDim2.fromOffset(math.round(size.X),math.round(size.Y))
end
function Window:SetTitle(title)if self.Alive then self.Native:setTitle(title);self.DockTitle.Text=title end end
function Window:SetTitleInset(value)if self.Alive then self.Native.titlebar:setTitleInset(value)end end
function Window:Focus()if self.State=='minimized'then self:Restore()end;return self.Manager:Focus(self)end
function Window:Close()return self.Manager:Close(self)end
function Window:SetCloseGuard(guard)
	assert(guard==nil or type(guard)=='function','Window close guard must be a function or nil')
	self.CloseGuard=guard;self.CloseGuardVersion=(self.CloseGuardVersion or 0)+1
	return self
end
function Window:RequestClose()
	if not self.Alive or not self.Manager.Alive or self.CloseRequestPending then return false end
	local guard=self.CloseGuard
	if not guard then return self:Close()end
	self.CloseRequestPending=true
	local version=self.CloseGuardVersion
	-- Host prompts may yield. A second caption click must not open another
	-- prompt, and disposal or a replaced guard invalidates the old result.
	local ok,accepted=pcall(guard,self)
	self.CloseRequestPending=false
	if not ok then error(accepted,0)end
	if accepted~=true or not self.Alive or not self.Manager.Alive or self.CloseGuard~=guard or self.CloseGuardVersion~=version then return false end
	return self:Close()
end
function Window:OnClose(callback)return self.Closed:Connect(callback)end
function Window:IsInputEnabled()return self.Alive and self.Manager.Input:canFocus(self.Native)end
function Window:GetOwner()return self.Manager.Wrap(self.Native.owner)end
function Window:SetEnabled(value)
	if not self.Alive then return end
	self.Native:setEnabled(value)
	self.Manager.FocusChanged:Fire(self.Manager:GetFocused())
end
function Window:MessageBox(options)
	local cfg=table.clone(options or{});cfg.Owner=self;return self.Manager:MessageBox(cfg)
end
function Window:Snap(zone)
	if not self.Alive or self.Fullscreen or not self.Native.resizable then return false end
	if self.State=='minimized'then self:Restore()end
	return Snap.apply(self.Native,zone)
end
function Window:Maximize()return self:Snap('maximize')end
function Window:ToggleMaximize()if self.State=='maximized'then return self:Restore()else return self:Maximize()end end
function Window:Minimize()
	if not self.Alive or self.Fullscreen or self.Options.Minimizable==false or not self.MinimizeButton then return false end
	self.Manager.Input:Cancel();self.Native:minimize();return true
end
function Window:Restore()
	if not self.Alive or self.Fullscreen then return false end
	if self.State=='minimized'then self.Native:unminimize()else self.Native:restore()end
	self:Fit();self.Manager:Focus(self);return true
end
function Window:Fit()
	if not self.Alive then return end
	local area=self.Manager:GetWorkArea()
	if self.Fullscreen then self:_Rect(Vector2.new(0,0),area)
	elseif self.Native.state=='maximized'or self.Native:getSnapZone()then
		local p,s=Geometry.rectFor(self.Native:getSnapZone()or'maximize',area);self:_Rect(p,s)
	else
		local p,s=Geometry.fit(self:GetPosition(),self:GetSize(),self.Minimum,area);self:_Rect(p,s)
	end
	self.Manager:_LayoutMinimized()
end
function Window:SetFullscreen(enabled)
	if not self.Alive or(self.Fullscreen==true)==enabled then return end
	local manager=self.Manager;manager.Input:Cancel()
	if enabled then
		if self.State=='minimized'then self:Restore()end
		if manager.Fullscreen and manager.Fullscreen~=self then manager.Fullscreen:SetFullscreen(false)end
		self.FullscreenSaved={Position=self:GetPosition(),Size=self:GetSize()}
		self.Fullscreen=true;self.Native.fullscreen=true;manager.Fullscreen=self;self.Titlebar.Visible=false
		self.Content.Position=UDim2.fromOffset(0,0);self.Content.Size=UDim2.fromScale(1,1)
		if self.Native.resize then self.Native.resize:setEnabled(false)end
		if self.Native._shadow then self.Native._shadow.Enabled=false end
		self:Fit();self:Focus()
	else
		self.Fullscreen=false;self.Native.fullscreen=false;if manager.Fullscreen==self then manager.Fullscreen=nil end
		self.Titlebar.Visible=true;self.Content.Position=UDim2.fromOffset(0,32);self.Content.Size=UDim2.new(1,0,1,-32)
		if self.Native.resize then self.Native.resize:setEnabled(self.Native.state~='maximized')end
		local saved=self.FullscreenSaved;self.FullscreenSaved=nil
		if saved then self:_Rect(saved.Position,saved.Size)end
		self.Native:_applyShadow()
	end
	manager.FullscreenChanged:Fire(self,enabled)
end
function Window:Flash(times)if self.Alive then self.Native:flash(times)end end
function Window:Release()
	if self.Released then return end;self.Released=true;self.Alive=false
	self.CloseGuard=nil;self.CloseRequestPending=false
	if self.Native.requestClose==self.NativeCloseRequest then self.Native.requestClose=nil end
	self.NativeCloseRequest=nil
	self.RemoveDock();self.Dock:Destroy()
	for _,connection in self.Connections do if connection.Disconnect then connection:Disconnect()else connection:disconnect()end end
	table.clear(self.Connections)
end
return Window
