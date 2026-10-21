--!nonstrict
-- A small native GUI shell. Documents, JavaScript and navigation belong to its host.
local Signal=require(script.Parent.Signal)
local View=require(script.Parent.View)
local Input=require(script.Parent.Input)
local Dialogs=require(script.Parent.Dialogs)
local Manager={};Manager.__index=Manager
local Window={};Window.__index=Window
local function vector(value,fallback)
	if value and type(value.X)=='number'and type(value.Y)=='number'then return Vector2.new(value.X,value.Y)end
	return fallback
end
local function attempt(state,callback)
	local ok,value=pcall(callback);if not ok and not state.Failed then state.Failed,state.Error=true,value end
end
function Manager.new(parent,services)
	assert(parent,'FallbackWindows requires a GUI parent')
	services=services or {};local self=setmetatable({Alive=true,Parent=parent,Services=services,Windows={},Connections={},Dialogs={},Serial=0},Manager)
	self.Gui=View.new(services);self.Tasks=services.Task or task
	self.FocusChanged=Signal.new();self.StateChanged=Signal.new();self.FullscreenChanged=Signal.new()
	self.Layer=self.Gui:Make('Frame',parent,{Name='HTMLFallbackWindows',Size=UDim2.fromScale(1,1),ClipsDescendants=true,ZIndex=100})
	self.Dock=self.Gui:Make('Frame',self.Layer,{Name='RestoreWindows',Size=UDim2.fromScale(1,1),ZIndex=1000})
	self.Input=Input.new(self,services)
	table.insert(self.Connections,self.Layer:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()self:_Fit()end))
	table.insert(self.Connections,self.Layer.Destroying:Connect(function()if self.Alive then self:Destroy()end end))
	return self
end
function Manager:_Area()return self.Layer.AbsoluteSize end
function Manager:_FitWindow(window)
	local area=self:_Area();local width,height=math.max(1,area.X),math.max(1,area.Y)
	if window.Fullscreen or window.State=='maximized'then window.Position=Vector2.new(0,0);window.Size=Vector2.new(width,height)
	else
		local minimum=window.Minimum
		window.Size=Vector2.new(math.clamp(window.Size.X,math.min(minimum.X,width),width),math.clamp(window.Size.Y,math.min(minimum.Y,height),height))
		window.Position=Vector2.new(math.clamp(window.Position.X,0,math.max(0,width-window.Size.X)),math.clamp(window.Position.Y,0,math.max(0,height-window.Size.Y)))
	end
	window.Root.Position=UDim2.fromOffset(window.Position.X,window.Position.Y);window.Root.Size=UDim2.fromOffset(window.Size.X,window.Size.Y)
	window.Root.Visible=window.Visible and window.State~='minimized'
	window.Titlebar.Visible=not window.Fullscreen
	local top=if window.Fullscreen then 0 else View.TitleHeight
	window.Content.Position=UDim2.fromOffset(0,top);window.Content.Size=UDim2.new(1,0,1,-top)
end
function Manager:_Dock()
	local area=self:_Area();local width=math.max(1,math.min(150,area.X));local columns=math.max(1,math.floor(area.X/(width+6)));local index=0
	for _,window in self.Windows do
		window.Dock.Visible=window.Visible and window.State=='minimized'
		if window.Dock.Visible then
			window.Dock.Position=UDim2.fromOffset(6+(index%columns)*(width+6),math.max(0,area.Y-34-math.floor(index/columns)*34))
			window.Dock.Size=UDim2.fromOffset(math.max(1,width-6),28);index+=1
		end
	end
end
function Manager:_Fit()if not self.Alive then return end;for _,window in self.Windows do self:_FitWindow(window)end;self:_Dock();self.Input:Refresh()end
function Manager:_Paint()
	for index,window in self.Windows do
		window.Root.ZIndex=100+index*10
		View.Paint(window,self.Focused==window,if self.Input.Hover and self.Input.Hover.Window==window then self.Input.Hover.Kind else nil,if self.Input.Pressed and self.Input.Pressed.Window==window then self.Input.Pressed.Kind else nil)
	end
end
function Manager:Open(settings)
	assert(self.Alive,'FallbackWindows manager was destroyed');settings=settings or {};self.Serial+=1
	local parts=View.Window(self.Gui,self.Layer,tostring(settings.Title or 'Untitled'))
	local window=setmetatable(parts,Window)
	window.Manager=self;window.Alive=true;window.Visible=settings.Visible~=false;window.State='normal';window.Fullscreen=false;window.ID=self.Serial;window.InputEnabled=true
	window.Position=vector(settings.Position,Vector2.new(24+(self.Serial-1)%8*24,24+(self.Serial-1)%8*24))
	window.Size=vector(settings.Size,Vector2.new(640,420));window.Minimum=vector(settings.MinSize,Vector2.new(240,140));window.Settings=settings
	window.Closed=Signal.new();window.Guard=settings.CloseGuard;window.GuardVersion=0
	window.Root:SetAttribute('ManagedWindow',window.ID)
	window.CloseButton.Visible=settings.Closable~=false;window.MinimizeButton.Visible=settings.Minimizable~=false;window.MaximizeButton.Visible=settings.Maximizable~=false
	window.Dock=self.Gui:Button(self.Dock,'Restore_'..window.ID,tostring(settings.Title or 'Untitled'),false);window.Dock.Visible=false
	window.RootConnection=window.Root.Destroying:Connect(function()if window.Alive then window:Close()end end)
	table.insert(self.Windows,window);self:_FitWindow(window);self:_Dock();self:Focus(window);self.Input:Refresh()
	return window
end
function Manager:GetWindows()return table.clone(self.Windows)end
function Manager:GetFocused()return self.Focused end
function Manager:Focus(window)
	if not self.Alive or (window and (not window.Alive or not window.Visible or window.Manager~=self or window.State=='minimized'))then return end
	if self.Focused==window then return end
	local old=self.Focused
	if old and old.Fullscreen then old:SetFullscreen(false)end
	for _,dialog in self.Dialogs do
		if dialog.Window==old and dialog.Field and dialog.Field:IsFocused()then dialog.Field:ReleaseFocus(false)end
	end
	self.Focused=window
	if window then local index=table.find(self.Windows,window);table.remove(self.Windows,index);table.insert(self.Windows,window)end
	self:_Paint();self.FocusChanged:Fire(window)
end
function Manager:CanReceivePointer(window,position)
	if not self.Alive then return false end
	if not self.Input:Allowed(position)then return false end
	local hit=self.Input:Hit(position)
	if not window then return hit==nil end
	return window:IsInputEnabled()and hit~=nil and hit.Window==window and hit.Kind=='content'
end
function Manager:ConsumesInput(event)return self.Alive and self.Input:Consumes(event)or false end
function Manager:ShowDialog(owner,request,complete)return Dialogs.Show(self,owner,request,complete)end
function Manager:Destroy()
	if not self.Alive then return end;self.Alive=false;local errors={}
	for _,dialog in table.clone(self.Dialogs)do attempt(errors,dialog.Cancel)end
	self.Input:Destroy()
	for _,connection in self.Connections do connection:Disconnect()end;table.clear(self.Connections)
	for _,window in table.clone(self.Windows)do attempt(errors,function()window:Close()end)end
	for _,signal in {self.FocusChanged,self.StateChanged,self.FullscreenChanged}do signal:Destroy()end
	self.Layer:Destroy();if errors.Failed then error(errors.Error,0)end
end
function Window:OnClose(callback)return self.Closed:Connect(callback)end
function Window:SetCloseGuard(callback)self.GuardVersion+=1;self.Guard=callback end
function Window:RequestClose()
	if not self.Alive or self.ClosePending or self.Settings.Closable==false then return false end
	self.ClosePending=true;local version=self.GuardVersion
	local ok,result=pcall(function()return not self.Guard or self.Guard(self)==true end)
	self.ClosePending=false
	if not ok then error(result,0)end
	if self.Alive and version==self.GuardVersion and result then self:Close();return true end
	return false
end
function Window:Close()
	if not self.Alive then return end;self.Alive=false;self.GuardVersion+=1;self.Guard=nil;self.Settings.CloseGuard=nil;local manager=self.Manager;local errors={}
	manager.Input:Cancel(self)
	for _,dialog in table.clone(manager.Dialogs)do if dialog.Owner==self.Content or dialog.Owner:IsDescendantOf(self.Root)then attempt(errors,dialog.Cancel)end end
	local index=table.find(manager.Windows,self);if index then table.remove(manager.Windows,index)end
	if self.RootConnection then self.RootConnection:Disconnect()end
	if manager.Focused==self then local nextWindow
		for i=#manager.Windows,1,-1 do if manager.Windows[i].Visible and manager.Windows[i].State~='minimized'then nextWindow=manager.Windows[i];break end end
		if manager.Alive then attempt(errors,function()manager:Focus(nextWindow)end)else manager.Focused=nil end
	end
	attempt(errors,function()self.Closed:Fire()end);self.Closed:Destroy()
	self.Dock:Destroy();self.Root:Destroy();manager:_Dock();if manager.Alive then manager:_Paint()end
	if errors.Failed then error(errors.Error,0)end;return true
end
function Window:Focus()self.Manager:Focus(self)end
function Window:IsInputEnabled()return self.Alive and self.Visible and self.InputEnabled and self.State~='minimized'and self.Manager.Focused==self end
function Window:SetInputEnabled(enabled)self.InputEnabled=enabled~=false end
function Window:SetVisible(visible)
	if not self.Alive then return end;self.Visible=visible~=false
	if not self.Visible then self.Manager.Input:Cancel(self);if self.Manager.Focused==self then self.Manager:Focus(nil)end end
	self.Manager:_FitWindow(self);self.Manager:_Dock()
	if self.Visible and self.State~='minimized'then self:Focus()end
end
function Window:GetPosition()return self.Position end
function Window:GetSize()return self.Size end
function Window:SetPosition(value)
	if not self.Alive or self.Fullscreen or self.State~='normal'then return false end
	self.Position=vector(value,self.Position);self.Manager:_FitWindow(self);return true
end
function Window:SetSize(value)
	if not self.Alive or self.Fullscreen or self.State~='normal'then return false end
	self.Size=vector(value,self.Size);self.Manager:_FitWindow(self);return true
end
function Window:SetTitle(title)self.TitleLabel.Text=tostring(title);self.Dock:FindFirstChildOfClass('TextLabel').Text=tostring(title)end
function Window:_State(state)
	self.State=state;self.Manager:_FitWindow(self);self.Manager:_Dock();self.Manager.StateChanged:Fire(self,state)
end
function Window:Minimize()
	if not self.Alive or self.State=='minimized'or self.Settings.Minimizable==false then return end
	if self.Fullscreen then self:SetFullscreen(false)end
	self.PreviousState=self.State;self.Manager.Input:Cancel(self);self:_State('minimized')
	if self.Manager.Focused==self then self.Manager:Focus(nil)
		for i=#self.Manager.Windows,1,-1 do local other=self.Manager.Windows[i];if other.Visible and other.State~='minimized'then other:Focus();break end end
	end
end
function Window:Maximize()
	if not self.Alive or self.Settings.Maximizable==false then return end
	if self.Fullscreen then self:SetFullscreen(false)end
	if self.State=='normal'then self.Normal={Position=self.Position,Size=self.Size}end
	self:_State('maximized');self:Focus()
end
function Window:Restore()
	if not self.Alive then return end
	if self.Fullscreen then self:SetFullscreen(false);return end
	local state=if self.State=='minimized'then self.PreviousState or 'normal'else 'normal'
	if state=='normal'and self.Normal then self.Position,self.Size=self.Normal.Position,self.Normal.Size;self.Normal=nil end
	self:_State(state);self:Focus()
end
function Window:SetFullscreen(enabled)
	enabled=enabled==true;if not self.Alive or self.Fullscreen==enabled then return false end
	self.Manager.Input:Cancel(self)
	if enabled then
		if self.State=='minimized'then self:Restore()end
		self:Focus();self.BeforeFullscreen={State=self.State,Position=self.Position,Size=self.Size};self.Fullscreen=true
	else
		self.Fullscreen=false;local saved=self.BeforeFullscreen;self.BeforeFullscreen=nil
		if saved then self.State,self.Position,self.Size=saved.State,saved.Position,saved.Size end
	end
	self.Manager:_FitWindow(self);self.Manager.FullscreenChanged:Fire(self,enabled);return true
end
return Manager
