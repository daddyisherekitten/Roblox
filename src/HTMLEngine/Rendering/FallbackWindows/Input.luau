--!nonstrict
local View=require(script.Parent.View)
local CursorLease=require(script.Parent.Parent.Parent.Input.CursorLease)
local Input={};Input.__index=Input
local function pointer(event)return event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch end
local function point(event)return Vector2.new(event.Position.X,event.Position.Y)end
local function same(a,b)return a and b and a.Window==b.Window and a.Kind==b.Kind and a.Dialog==b.Dialog end
local function modalHit(manager,window,position)
	for i=#manager.Dialogs,1,-1 do
		local dialog=manager.Dialogs[i]
		if dialog.Alive and dialog.Window==window and View.Contains(dialog.Owner,position)then
			for _,name in {'Accept','Reject','Field','Scroll'}do if View.Contains(dialog[name],position)then return {Window=window,Kind='dialog'..name,Dialog=dialog}end end
			return {Window=window,Kind='dialog',Dialog=dialog}
		end
	end
	return nil
end
function Input.new(manager,services)
	local native=services.Input or game:GetService('UserInputService')
	local playerGui=services.PlayerGui or game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')
	local self=setmetatable({Manager=manager,Native=native,PlayerGui=playerGui,GuiService=services.GuiService or game:GetService('GuiService'),Connections={},Consumed=setmetatable({},{__mode='k'}),Alive=true},Input)
	self.Cursor=CursorLease.new(native,20)
	table.insert(self.Connections,native.InputBegan:Connect(function(event)self:Begin(event)end))
	table.insert(self.Connections,native.InputChanged:Connect(function(event)self:Changed(event)end))
	table.insert(self.Connections,native.InputEnded:Connect(function(event)self:Ended(event)end))
	table.insert(self.Connections,native.WindowFocusReleased:Connect(function()self:Cancel();self.Cursor:Set(nil)end))
	return self
end
function Input:Allowed(position)
	local manager=self.Manager
	if not View.Contains(manager.Layer,position)then return false end
	for _,object in self.PlayerGui:GetGuiObjectsAtPosition(position.X,position.Y)do
		local owned=object==manager.Layer or object:IsDescendantOf(manager.Layer)
		if not owned then for _,dialog in manager.Dialogs do if object==dialog.Root or object:IsDescendantOf(dialog.Root)then owned=true;break end end end
		if owned and View.Contains(object,position)then return true end
		if not owned and object:IsA('GuiObject')and object.BackgroundTransparency<1 and View.Contains(object,position)then return false end
	end
	return true
end
function Input:Hit(position)
	local manager=self.Manager
	if not self:Allowed(position)then return nil end
	for i=#manager.Windows,1,-1 do local window=manager.Windows[i]
		if View.Contains(window.Dock,position)then return {Window=window,Kind='restore'}end
	end
	for i=#manager.Windows,1,-1 do
		local window=manager.Windows[i]
		if window.Alive and View.Contains(window.Root,position)then
			local dialog=modalHit(manager,window,position);if dialog then return dialog end
			for _,name in {'Close','Minimize','Maximize'}do if View.Contains(window[name..'Button'],position)then return {Window=window,Kind=string.lower(name)}end end
			if not window.Fullscreen and window.State=='normal'and window.Settings.Resizable~=false then
				local p,s=window.Root.AbsolutePosition,window.Root.AbsoluteSize
				local horizontal=if position.X<p.X+6 then -1 elseif position.X>=p.X+s.X-6 then 1 else 0
				local vertical=if position.Y<p.Y+6 then -1 elseif position.Y>=p.Y+s.Y-6 then 1 else 0
				if horizontal~=0 or vertical~=0 then return {Window=window,Kind='resize',X=horizontal,Y=vertical}end
			end
			if View.Contains(window.Titlebar,position)then return {Window=window,Kind='drag'}end
			return {Window=window,Kind=if window.InputEnabled then 'content'else 'blocked'}
		end
	end
	return modalHit(manager,nil,position)
end
function Input:_Paint(position)
	local hit=self:Hit(position);self.Hover=hit
	if self.Held and not self.Gesture then self.Pressed=if same(self.Held.Hit,hit)then hit else nil end
	self.Manager:_Paint()
	local active=self.Gesture or hit
	local cursor
	if active and active.Kind=='resize'then
		cursor=if active.X==0 then 'ns-resize'elseif active.Y==0 then 'ew-resize'elseif active.X==active.Y then 'nwse-resize'else 'nesw-resize'
	elseif active and active.Kind~='content'then cursor=if active.Kind=='dialogField'then 'text'else 'default'end
	self.Cursor:Set(cursor)
end
function Input:Refresh()
	if self.Alive then
		local physical=self.Native:GetMouseLocation();local inset=self.GuiService:GetGuiInset()
		self:_Paint(self.Last or Vector2.new(physical.X-inset.X,physical.Y-inset.Y))
	end
end
function Input:Consumes(event)return self.Consumed[event]==true end
function Input:Begin(event)
	if not self.Alive then return end
	self.Consumed[event]=nil
	if event.UserInputType==Enum.UserInputType.Keyboard then
		local dialog
		for i=#self.Manager.Dialogs,1,-1 do local candidate=self.Manager.Dialogs[i];if candidate.Window==self.Manager.Focused then dialog=candidate;break end end
		if dialog and dialog.Alive then
			if event.KeyCode==Enum.KeyCode.Escape then self.Consumed[event]=true;dialog.Finish(false)
			elseif event.KeyCode==Enum.KeyCode.Return or event.KeyCode==Enum.KeyCode.KeypadEnter then self.Consumed[event]=true;dialog.Finish(true)end
		end
		return
	end
	if not pointer(event)or self.Held then return end
	self.Last=point(event);local hit=self:Hit(self.Last)
	if not hit then self:_Paint(self.Last);return end
	if hit.Window then hit.Window:Focus()end
	if hit.Kind=='content'then self:_Paint(self.Last);return end
	self.Consumed[event]=true;self.Held={Event=event,Hit=hit};self.Pressed=hit
	local window=hit.Window
	if hit.Kind=='drag'and window.State=='normal'then
		self.Gesture={Kind='drag',Window=window,Start=self.Last,Position=window.Position}
	elseif hit.Kind=='resize'then
		self.Gesture={Kind='resize',Window=window,Start=self.Last,Position=window.Position,Size=window.Size,X=hit.X,Y=hit.Y}
		window.Root:SetAttribute('HTMLViewportResizing',true);window.Content:SetAttribute('HTMLViewportResizing',true)
	elseif hit.Kind=='dialogField'then hit.Dialog.Field:CaptureFocus()
	elseif hit.Kind=='dialogScroll'then self.Gesture={Kind='scroll',Window=window,Start=self.Last,Scroll=hit.Dialog.Scroll,Offset=hit.Dialog.Scroll.CanvasPosition.Y}end
	self:_Paint(self.Last);if event.UserInputType==Enum.UserInputType.Touch then self.Cursor:Set(nil)end
end
function Input:Changed(event)
	if not self.Alive then return end
	if event.UserInputType==Enum.UserInputType.MouseWheel then
		local physical=self.Native:GetMouseLocation();local inset=self.GuiService:GetGuiInset()
		local position=self.Last or Vector2.new(physical.X-inset.X,physical.Y-inset.Y);local hit=self:Hit(position)
		local scroll=hit and hit.Dialog and hit.Dialog.Scroll
		if scroll and View.Contains(scroll,position)then
			local limit=math.max(0,scroll.AbsoluteCanvasSize.Y-scroll.AbsoluteSize.Y)
			scroll.CanvasPosition=Vector2.new(0,math.clamp(scroll.CanvasPosition.Y-event.Position.Z*36,0,limit));self.Consumed[event]=true
		end
		return
	end
	local touch=self.Held and self.Held.Event.UserInputType==Enum.UserInputType.Touch
	if touch and event~=self.Held.Event then return end
	if not touch and event.UserInputType~=Enum.UserInputType.MouseMovement then return end
	self.Last=point(event);local gesture=self.Gesture
	if gesture and (not gesture.Window or gesture.Window.Alive)then
		local delta=self.Last-gesture.Start;local window=gesture.Window
		if gesture.Kind=='scroll'then
			local scroll=gesture.Scroll;local limit=math.max(0,scroll.AbsoluteCanvasSize.Y-scroll.AbsoluteSize.Y)
			scroll.CanvasPosition=Vector2.new(0,math.clamp(gesture.Offset-delta.Y,0,limit))
		elseif gesture.Kind=='drag'then window:SetPosition(gesture.Position+delta)
		else
			local area=self.Manager:_Area();local minimum=window.Minimum
			local left,top=gesture.Position.X,gesture.Position.Y;local right,bottom=left+gesture.Size.X,top+gesture.Size.Y
			if gesture.X<0 then left=math.clamp(left+delta.X,0,math.max(0,right-math.min(minimum.X,area.X)))elseif gesture.X>0 then right=math.clamp(right+delta.X,math.min(area.X,left+minimum.X),area.X)end
			if gesture.Y<0 then top=math.clamp(top+delta.Y,0,math.max(0,bottom-math.min(minimum.Y,area.Y)))elseif gesture.Y>0 then bottom=math.clamp(bottom+delta.Y,math.min(area.Y,top+minimum.Y),area.Y)end
			window.Position=Vector2.new(left,top);window.Size=Vector2.new(right-left,bottom-top);self.Manager:_FitWindow(window)
		end
	end
	if touch then self.Cursor:Set(nil)else self:_Paint(self.Last)end
end
function Input:Ended(event)
	if not self.Alive or not self.Held then return end
	local held=self.Held
	if held.Event.UserInputType==Enum.UserInputType.Touch then if event~=held.Event then return end
	elseif event.UserInputType~=Enum.UserInputType.MouseButton1 then return end
	self.Consumed[event]=true;local position=point(event);local hit=self:Hit(position)
	local action=if not self.Gesture and same(held.Hit,hit)then hit else nil
	self:Cancel();self.Last=position;self:_Paint(position)
	if not action then return end
	local window=action.Window
	self.Manager.Tasks.spawn(function()
		if not self.Manager.Alive or (window and not window.Alive)then return end
		if action.Dialog then
			if action.Kind=='dialogAccept'then action.Dialog.Finish(true)elseif action.Kind=='dialogReject'then action.Dialog.Finish(false,if action.Dialog.Kind=='permission'then 'denied'else nil)end
		elseif action.Kind=='close'then window:RequestClose()
		elseif action.Kind=='minimize'then window:Minimize()
		elseif action.Kind=='maximize'then if window.State=='maximized'then window:Restore()else window:Maximize()end
		elseif action.Kind=='restore'then window:Restore()end
	end)
end
function Input:Cancel(window)
	if window and self.Held and self.Held.Hit.Window~=window then return end
	if self.Gesture and self.Gesture.Kind=='resize'then
		self.Gesture.Window.Root:SetAttribute('HTMLViewportResizing',false);self.Gesture.Window.Content:SetAttribute('HTMLViewportResizing',false)
	end
	self.Gesture=nil;self.Held=nil;self.Pressed=nil;self.Hover=nil
	if self.Manager.Alive then self.Manager:_Paint()end
	self.Cursor:Set(nil)
end
function Input:Destroy()
	if not self.Alive then return end;self:Cancel();self.Alive=false
	for _,connection in self.Connections do connection:Disconnect()end;table.clear(self.Connections);self.Cursor:Destroy()
end
return Input
