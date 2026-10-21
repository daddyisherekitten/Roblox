--!strict
-- One event-driven mouse/touch router per window, independent of content.
local Input={};local focusOwners=setmetatable({},{__mode='k'})
function Input.new(root,service,playerGui)
	local self={Alive=true,Root=root,Entries={},Connections={},Pressed=nil,Hovered=nil,Consumed=setmetatable({},{__mode='k'}),Keys={}}
	focusOwners[service]=self
	local function inside(object)
		local current=object
		while current do
			if current:GetAttribute('WindowClosing')then return false end
			if current:IsA('GuiObject')and not current.Visible then return false end
			if current:IsA('LayerCollector')and not current.Enabled then return false end
			if current==root then return true end;current=current.Parent
		end
		return false
	end
	local function pick(position)
		if self.FilterPointer and not self.FilterPointer(position)then return nil,true end
		local owned=false
		for _,object in playerGui:GetGuiObjectsAtPosition(position.X,position.Y)do
			if not inside(object)then
				if object:IsA('GuiObject')and object.Visible then return nil,false end
				continue
			end;owned=true
			local current=object
			while current and current~=root.Parent do
				local entry=self.Entries[current]
				if entry and entry.Enabled~=false then return entry,true end
				current=current.Parent
			end
			-- A topmost content surface must not fall through to chrome underneath.
			return nil,true
		end
		return nil,owned
	end
	local function hover(entry)
		if self.UpdateCursor then self.UpdateCursor(self.Pressed and self.Pressed.Entry or entry)end
		if entry==self.Hovered then return end
		local old=self.Hovered;self.Hovered=entry
		if old and old.Hover then old.Hover(false)end
		if entry and entry.Hover then entry.Hover(true)end
	end
	function self:HitTest(position)local entry=pick(position);return entry and entry.Gui end
	local function pressVisual(pressed,insideValue)
		if not pressed or pressed.Inside==insideValue then return end
		pressed.Inside=insideValue
		if pressed.Entry.Press then pressed.Entry.Press(insideValue)end
	end
	function self:Cancel()
		local pressed=self.Pressed;self.Pressed=nil;pressVisual(pressed,false);hover(nil)
		if pressed and pressed.Entry.Cancel then pressed.Entry.Cancel()end
	end
	function self:Bind(gui,callbacks)
		local entry=table.clone(callbacks or{});entry.Gui=gui;self.Entries[gui]=entry
		return function()
			if self.Entries[gui]~=entry then return end
			if self.Pressed and self.Pressed.Entry==entry then self:Cancel()end
			if self.Hovered==entry then hover(nil)end
			self.Entries[gui]=nil
		end,entry
	end
	local function connect(signal,callback)table.insert(self.Connections,signal:Connect(callback))end
	connect(service.InputBegan,function(event,processed)
		if not self.Alive then return end
		local kind=event.UserInputType
		if kind==Enum.UserInputType.MouseButton1 or kind==Enum.UserInputType.Touch then
			if self.BeforePointerDown and self.BeforePointerDown(event,processed)then self.Consumed[event]=true;return end
			local entry,owned=pick(event.Position)
			if owned then focusOwners[service]=self end
			if self.PointerDown then self.PointerDown(entry,event,owned)end
			if not self.Alive or self.Pressed or not entry or entry.Passive or self.Entries[entry.Gui]~=entry or entry.Enabled==false or not inside(entry.Gui)then return end
			if kind==Enum.UserInputType.Touch then hover(nil)else hover(entry)end
			local pressed={Entry=entry,Input=event,Touch=kind==Enum.UserInputType.Touch}
			self.Pressed=pressed;pressVisual(pressed,true)
			if self.UpdateCursor then self.UpdateCursor(entry)end
			self.Consumed[event]=true
			if self.Pressed~=pressed or not self.Alive then return end
			if entry.Begin then entry.Begin(event)end
		elseif kind==Enum.UserInputType.Keyboard and focusOwners[service]==self and self.Shortcut then
			if self.Shortcut(event,processed)or(self.FilterKeyboard and self.FilterKeyboard())then self.Consumed[event]=true;self.Keys[event.KeyCode]=true end
		end
	end)
	connect(service.InputChanged,function(event)
		if not self.Alive then return end
		local pressed=self.Pressed
		if pressed then
			if (pressed.Touch and event==pressed.Input)or(not pressed.Touch and event.UserInputType==Enum.UserInputType.MouseMovement)then
				if pressed.Entry.Move then pressed.Entry.Move(event)end
				self.Consumed[event]=true
				if self.Alive and self.Pressed==pressed then local entry=pick(event.Position);pressVisual(pressed,entry==pressed.Entry)end
			end
		end
		-- A held press keeps its action/drag owner, but hover follows the mouse.
		if self.Alive and event.UserInputType==Enum.UserInputType.MouseMovement and not(pressed and pressed.Touch)then
			local entry=pick(event.Position);hover(entry)
		end
	end)
	connect(service.InputEnded,function(event)
		if not self.Alive then return end
		if event.UserInputType==Enum.UserInputType.Keyboard and self.Keys[event.KeyCode]then self.Consumed[event]=true;self.Keys[event.KeyCode]=nil;if self.KeyReleased then self.KeyReleased(event)end;return end
		local pressed=self.Pressed;if not pressed then return end
		if (pressed.Touch and event~=pressed.Input)or(not pressed.Touch and event.UserInputType~=Enum.UserInputType.MouseButton1)then return end
		self.Pressed=nil;pressVisual(pressed,false)
		self.Consumed[event]=true
		if pressed.Entry.Finish then pressed.Entry.Finish(event)
		elseif pressed.Entry.Action and pressed.Entry.Enabled~=false then
			local entry=pick(event.Position);if entry==pressed.Entry then pressed.Entry.Action()end
		end
		-- The action can hide/remove its own control; pick again after it finishes.
		if self.Alive and not pressed.Touch then local entry=pick(event.Position);hover(entry)end
	end)
	connect(service.WindowFocusReleased,function()if self.Alive then self:Cancel();table.clear(self.Keys)end end)
	function self:Destroy()
		if not self.Alive then return end;self:Cancel();self.Alive=false
		for _,connection in self.Connections do connection:Disconnect()end
		table.clear(self.Connections);table.clear(self.Entries);table.clear(self.Keys);table.clear(self.Consumed)
		if focusOwners[service]==self then focusOwners[service]=nil end
		self.Shortcut=nil;self.PointerDown=nil;self.FilterKeyboard=nil;self.BeforePointerDown=nil;self.KeyReleased=nil;self.FilterPointer=nil;self.UpdateCursor=nil
	end
	return self
end
return Input
