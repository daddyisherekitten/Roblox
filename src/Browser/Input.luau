--!nonstrict
-- One pointer router owns registered controls in GUI-inset screen pixels.
-- InputObject.Position, AbsolutePosition and native GUI picking share this space.
-- Physical GetMouseLocation is converted once when acquiring or scrolling.
local Tokens=require(script.Parent.Tokens)
local Signal=require(script.Parent.Signal)
local CursorIcons=require(script.Parent.CursorIcons)
local Input={}
local function point(value)return Vector2.new(value.X,value.Y)end
local function contains(object,position)
	local origin,size=object.AbsolutePosition,object.AbsoluteSize
	return position.X>=origin.X and position.Y>=origin.Y and position.X<origin.X+size.X and position.Y<origin.Y+size.Y
end
local function ancestor(object,parent)
	local current=object
	while current do if current==parent then return true end;current=current.Parent end
	return false
end
function Input.new(root,options,legacyPlayerGui)
	if options and options.InputBegan then options={Services={Input=options,PlayerGui=legacyPlayerGui}} end
	options=options or {};local services=options.Services or options
	local service=services.Input or services.UserInputService or game:GetService('UserInputService')
	local guiService=services.GuiService or game:GetService('GuiService')
	local playerGui=services.PlayerGui or game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')
	local scheduler=services.Task or task
	local clock=services.Clock or os.clock
	local self={Alive=true,Active=true,Root=root,Entries={},Connections={},Scrollers={},Pointers={},Hovered=nil,Pressed=nil,Consumed=setmetatable({},{__mode='k'}),Keys={},Modal=nil,Focus=nil,TooltipGeneration=0,PointerDownSignal=Signal.new(),Suspended=Signal.new()}
	local mouseKey={};local mousePosition=point(service:GetMouseLocation())-guiService:GetGuiInset()
	local cursorSaved,cursorIcon,cursorTask
	local mouse=service.MouseEnabled~=false
	local function visible(object,position)
		local current=object;local belongs=false
		while current do
			if current:IsA('GuiObject') then
				if not current.Visible then return false end
				if position and (current==object or current.ClipsDescendants) and not contains(current,position) then return false end
			elseif current:IsA('LayerCollector') and not current.Enabled then return false end
			if current==root then belongs=true end
			current=current.Parent
		end
		return belongs
	end
	local function allowed(position)
		return self.Alive and self.Active and visible(root,position) and (not options.CanReceivePointer or options.CanReceivePointer(position))
	end
	local function pick(position,includeDisabled)
		position=point(position)
		if not allowed(position) then return nil,false end
		local owned=false;local surface=false
		for _,object in playerGui:GetGuiObjectsAtPosition(position.X,position.Y) do
			if not ancestor(object,root) then
				-- A host may opt in to a precise occlusion policy. Without it, unrelated
				-- objects before our root are treated as an occluding surface.
				if not owned and object:IsA('GuiObject') and object.Visible and object.BackgroundTransparency<1 then return nil,false end
				continue
			end
			if not visible(object,position) then continue end;owned=true
			if self.Modal and not ancestor(object,self.Modal) then continue end
			local current=object;local skipped=false
			while current and current~=root.Parent do
				if options.CursorSurface and options.CursorSurface(current)then surface=true end
				local entry=self.Entries[current]
				if entry and visible(entry.Gui,position) then
					if entry.HitTest and not entry.HitTest(position) then skipped=true;break end
					return if includeDisabled or entry.Enabled~=false then entry else nil,true,true
				end
				current=current.Parent
			end
			if not skipped and object:GetAttribute('WaylineInputBlocker') then return nil,true,surface end
		end
		return nil,owned,surface
	end
	local function releaseCursor()
		if not cursorSaved then return end
		if service.MouseIcon==cursorIcon then service.MouseIcon=cursorSaved.Icon end
		if service.MouseIconEnabled==true then service.MouseIconEnabled=cursorSaved.Enabled end
		cursorSaved=nil;cursorIcon=nil
	end
	local function refreshCursor()
		if not mouse or not service.MouseEnabled or not self.Alive or not self.Active then releaseCursor();return end
		local entry,_,surface=pick(mousePosition,true)
		if not entry and not surface then releaseCursor();return end
		local kind=if entry and entry.Enabled~=false then entry.Cursor or(if entry.Gui:IsA('TextBox')then 'text'elseif entry.Action then 'pointer'else 'default')else 'default'
		if not cursorSaved then cursorSaved={Icon=service.MouseIcon or'',Enabled=service.MouseIconEnabled~=false}end
		cursorIcon=CursorIcons[kind]or kind
		if service.MouseIcon~=cursorIcon then service.MouseIcon=cursorIcon end
		if not service.MouseIconEnabled then service.MouseIconEnabled=true end
	end
	function self:RefreshCursor()
		refreshCursor()
		-- Run after other input listeners as well, so a departing HTML cursor
		-- cannot restore its previous icon over the browser's newly acquired one.
		if cursorTask then return end
		cursorTask=scheduler.defer(function()cursorTask=nil;refreshCursor()end)
	end
	local function hideTooltip()
		self.TooltipGeneration+=1
		if self.TooltipTask then pcall(scheduler.cancel,self.TooltipTask);self.TooltipTask=nil end
		if self.TooltipHandler then self.TooltipHandler(nil,nil) end
	end
	local function hover(entry)
		if entry==self.Hovered then return end
		local old=self.Hovered;self.Hovered=entry;hideTooltip()
		if old and old.Hover then old.Hover(false) end
		if entry and entry.Hover then entry.Hover(true) end
		if entry and entry.Tooltip and self.TooltipHandler then
			local generation=self.TooltipGeneration
			self.TooltipTask=scheduler.delay(options.TooltipDelay or Tokens.Constants.TooltipDelay,function()
				self.TooltipTask=nil
				if self.Alive and self.Active and self.Hovered==entry and generation==self.TooltipGeneration and next(self.Pointers)==nil then self.TooltipHandler(entry.Tooltip,entry.Gui) end
			end)
		end
	end
	local function pressVisual(pressed,insideValue)
		if pressed.Inside==insideValue then return end
		pressed.Inside=insideValue
		if pressed.Entry and pressed.Entry.Press then pressed.Entry.Press(insideValue) end
	end
	local function cancelPointer(key,pressed)
		self.Pointers[key]=nil;if self.Pressed==pressed then self.Pressed=nil end
		pressVisual(pressed,false)
		if pressed.Entry then
			if pressed.Dragging and pressed.Entry.DragEnd then pressed.Entry.DragEnd(pressed.Last or pressed.Input,true) end
			if pressed.Entry.Cancel then pressed.Entry.Cancel() end
		end
	end
	function self:ReleaseFocus()
		local focused=service:GetFocusedTextBox()
		if focused and ancestor(focused,root) then focused:ReleaseFocus(false) end
		self.Focus=nil
	end
	function self:CaptureFocus(textbox)
		if not self.Alive or not self.Active or not visible(textbox) then return false end
		if self.Modal and not ancestor(textbox,self.Modal) then return false end
		textbox:CaptureFocus();self.Focus=textbox;return true
	end
	function self:Cancel()
		local pending=table.clone(self.Pointers)
		for key,pressed in pending do cancelPointer(key,pressed) end
		hover(nil);hideTooltip();releaseCursor()
	end
	function self:SetActive(value)
		if not self.Alive then return end
		self.Active=value==true
		if not self.Active then self:Cancel();self:ReleaseFocus();self.Suspended:Fire() else self:RefreshCursor()end
	end
	function self:SetModal(value)
		if self.Modal==value then return end
		self:Cancel();self.Modal=value;self:RefreshCursor()
	end
	function self:SetTooltipHandler(callback)hideTooltip();self.TooltipHandler=callback end
	function self:OnPointerDown(callback)return self.PointerDownSignal:Connect(callback)end
	function self:OnSuspend(callback)return self.Suspended:Connect(callback)end
	function self:HitAt(position)return pick(position)end
	function self:GetPointerPosition()return mousePosition end
	function self:Consumes(event)return self.Consumed[event]==true end
	function self:Bind(object,callbacks)
		local previous=self.Entries[object];if previous and previous.Unbind then previous.Unbind() end
		local entry=table.clone(callbacks or {});entry.Gui=object;entry.Enabled=entry.Enabled~=false;self.Entries[object]=entry
		local removed=false;local connection
		local function unbind()
			if removed then return end;removed=true
			for key,pressed in table.clone(self.Pointers) do if pressed.Entry==entry then cancelPointer(key,pressed) end end
			if self.Hovered==entry then hover(nil) end
			if self.Entries[object]==entry then self.Entries[object]=nil end
			if connection then connection:Disconnect();connection=nil end
			if self.Alive then self:RefreshCursor()end
		end
		entry.Unbind=unbind;connection=object.Destroying:Connect(unbind)
		return unbind,entry
	end
	local function scrollRegion(position)
		if not allowed(position) then return nil end
		local selected=nil;local depth=-1
		for object,record in self.Scrollers do
			if visible(object,position) and (not self.Modal or ancestor(object,self.Modal)) then
				local current=object;local count=0;while current and current~=root do count+=1;current=current.Parent end
				if count>depth then selected=record;depth=count end
			end
		end
		-- Do not route a wheel through an unrelated menu placed over the viewport.
		local hit=pick(position)
		if hit and selected and not ancestor(hit.Gui,selected.Root) and not ancestor(selected.Root,hit.Gui) then return nil end
		return selected
	end
	function self:RegisterScroll(scroller,scrollbar,axis)
		axis=axis or 'Y';scroller.ScrollingEnabled=false;scroller.ScrollBarThickness=0
		local record={Root=scroller,Axis=axis,Alive=true};self.Scrollers[scroller]=record
		local connections={};local unbind
		local function dimensions()
			local canvas=scroller.AbsoluteCanvasSize;local view=scroller.AbsoluteSize;local declared=scroller.CanvasSize
			local native=if axis=='X' then canvas.X else canvas.Y
			local authored=if axis=='X' then declared.X.Offset+declared.X.Scale*view.X else declared.Y.Offset+declared.Y.Scale*view.Y
			return math.max(native,authored),if axis=='X' then view.X else view.Y
		end
		local function offset()return if axis=='X' then scroller.CanvasPosition.X else scroller.CanvasPosition.Y end
		function record:Set(value)
			if not self.Alive then return false end
			local total,view=dimensions();local clamped=math.clamp(value,0,math.max(0,total-view));local old=offset()
			scroller.CanvasPosition=if axis=='X' then Vector2.new(clamped,scroller.CanvasPosition.Y) else Vector2.new(scroller.CanvasPosition.X,clamped)
			self:Refresh();return old~=clamped
		end
		function record:Refresh()
			if not self.Alive or not scrollbar then return end
			local total,view=dimensions();local max=math.max(0,total-view);scrollbar.Visible=max>0
			if max<=0 then return end
			local track=scrollbar.Parent.AbsoluteSize;local length=if axis=='X' then track.X else track.Y
			local thumb=math.min(length,math.max(28,length*view/math.max(1,total)));local at=offset()/max*math.max(0,length-thumb)
			scrollbar.Size=if axis=='X' then UDim2.fromOffset(thumb,6) else UDim2.fromOffset(6,thumb)
			scrollbar.Position=if axis=='X' then UDim2.fromOffset(at,0) else UDim2.fromOffset(0,at)
		end
		local function clamp()if record.Alive then record:Set(offset()) end end
		for _,property in {'AbsoluteSize','AbsoluteCanvasSize'} do table.insert(connections,scroller:GetPropertyChangedSignal(property):Connect(clamp)) end
		table.insert(connections,scroller:GetPropertyChangedSignal('CanvasPosition'):Connect(function()record:Refresh()end))
		if scrollbar then
			local start,initial
			local function moveThumb(event)
				local total,view=dimensions();local parentSize=scrollbar.Parent.AbsoluteSize;local thumbSize=scrollbar.AbsoluteSize
				local travel=if axis=='X' then parentSize.X-thumbSize.X else parentSize.Y-thumbSize.Y
				local delta=point(event.Position)-start;local amount=if axis=='X' then delta.X else delta.Y
				record:Set(initial+amount/math.max(1,travel)*math.max(0,total-view))
			end
			unbind,record.Entry=self:Bind(scrollbar,{Tooltip='Scroll',Begin=function(event)start=point(event.Position);initial=offset()end,Move=moveThumb,DragBegin=function(event)moveThumb(event)end,Drag=moveThumb,
				Hover=function(value)if record.OnHover then record.OnHover(value) end end,
				Press=function(value)if record.OnPress then record.OnPress(value) end end})
		end
		local function remove()
			if not record.Alive then return end;record.Alive=false
			if self.Scrollers[scroller]==record then self.Scrollers[scroller]=nil end
			if unbind then unbind() end;for _,connection in connections do connection:Disconnect() end;table.clear(connections)
		end
		record.Remove=remove;table.insert(connections,scroller.Destroying:Connect(remove));record:Refresh()
		return remove,record
	end
	local function connect(signal,callback)if signal then table.insert(self.Connections,signal:Connect(callback)) end end
	connect(service.InputBegan,function(event)
		if not self.Alive or not self.Active then return end
		local kind=event.UserInputType
		if kind==Enum.UserInputType.Keyboard then
			local editor=service:GetFocusedTextBox()
			-- Native text editing remains untouched; the provider must not receive
			-- browser field typing or keyboard input through a browser modal.
			if editor and ancestor(editor,root) or not editor and self.Modal then self.Consumed[event]=true;self.Keys[event.KeyCode]=true end
			return
		end
		if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
		mouse=kind~=Enum.UserInputType.Touch
		if not mouse then releaseCursor()end
		local position=point(event.Position);local entry,owned=pick(position)
		if not owned then return end
		hideTooltip();if entry then self.Consumed[event]=true end
		if self.PointerDown then self.PointerDown(entry,event,true) end
		self.PointerDownSignal:Fire(entry,event,true)
		if not self.Alive or not self.Active then return end
		if entry and self.Entries[entry.Gui]~=entry then return end
		entry=pick(position)
		local focused=service:GetFocusedTextBox()
		local keepFocus=entry and entry.PreserveFocus
		local candidate=entry and entry.Gui
		while candidate and candidate~=root.Parent and not keepFocus do keepFocus=candidate:GetAttribute('WaylinePreserveFocus')==true;candidate=candidate.Parent end
		if focused and ancestor(focused,root) and (not entry or entry.Gui~=focused) and not keepFocus then self:ReleaseFocus() end
		if entry and self.Entries[entry.Gui]~=entry then return end
		local touch=kind==Enum.UserInputType.Touch;local scroll=if touch then scrollRegion(position) else nil
		if not entry and not scroll then return end
		self.Consumed[event]=true
		local key=if touch then event else mouseKey
		if self.Pointers[key] then cancelPointer(key,self.Pointers[key]) end
		local pressed={Entry=entry,Input=event,Touch=touch,Start=position,StartedAt=clock(),Last=event,Dragged=false,Dragging=false,Scroll=scroll,ScrollStart=scroll and scroll.Root.CanvasPosition}
		self.Pointers[key]=pressed;self.Pressed=pressed
		if touch then hover(nil) else mousePosition=position;hover(entry);self:RefreshCursor() end
		if entry then pressVisual(pressed,true);if entry.Begin then entry.Begin(event) end end
	end)
	connect(service.InputChanged,function(event)
		if not self.Alive or not self.Active then return end
		if not visible(root) then self:Cancel();self:ReleaseFocus();self.Suspended:Fire();return end
		local kind=event.UserInputType
		if kind==Enum.UserInputType.MouseWheel then
			local inset=guiService:GetGuiInset();local position=point(service:GetMouseLocation())-inset;local region=scrollRegion(position)
			while region do
				local old=if region.Axis=='X' then region.Root.CanvasPosition.X else region.Root.CanvasPosition.Y
				if region:Set(old-event.Position.Z*(options.WheelStep or Tokens.Constants.WheelStep)) then self.Consumed[event]=true;break end
				local parent=region.Root.Parent;region=nil
				while parent and parent~=root.Parent do if self.Scrollers[parent] then region=self.Scrollers[parent];break end;parent=parent.Parent end
			end
			if service.MouseEnabled then mousePosition=position;local target=pick(position,true);hover(target);self:RefreshCursor() end
			return
		end
		local touch=kind==Enum.UserInputType.Touch
		if not touch and kind~=Enum.UserInputType.MouseMovement then return end
		local position=point(event.Position);if not touch then mouse=true;mousePosition=position end
		local key=if touch then event else mouseKey;local pressed=self.Pointers[key]
		if pressed then
			pressed.Last=event;self.Consumed[event]=true
			local delta=position-pressed.Start
			local threshold=if touch then options.TouchDragThreshold or Tokens.Constants.TouchDragThreshold else options.MouseDragThreshold or Tokens.Constants.MouseDragThreshold
			if not pressed.Dragged and delta.Magnitude>threshold and(pressed.Scroll or pressed.Entry and pressed.Entry.DragBegin)then
				pressed.Dragged=true;pressVisual(pressed,false);hideTooltip()
				local heldEnough=not touch or not pressed.Scroll or clock()-pressed.StartedAt>=(options.TouchDragHold or Tokens.Constants.TouchDragHold)
				if heldEnough and pressed.Entry and pressed.Entry.DragBegin then pressed.Dragging=true;pressed.Entry.DragBegin(event) end
			end
			if self.Pointers[key]~=pressed then return end
			if pressed.Dragged and pressed.Scroll and not pressed.Dragging then
				local original=if pressed.Scroll.Axis=='X' then pressed.ScrollStart.X else pressed.ScrollStart.Y
				local amount=if pressed.Scroll.Axis=='X' then delta.X else delta.Y
				pressed.Scroll:Set(original-amount)
			elseif pressed.Dragging then if pressed.Entry.Drag then pressed.Entry.Drag(event) end
			elseif pressed.Entry and pressed.Entry.Move then pressed.Entry.Move(event) end
			if pressed.Entry and not pressed.Dragged then local target=pick(position);pressVisual(pressed,target==pressed.Entry) end
		end
		if not touch then local target=pick(position,true);hover(target);self:RefreshCursor() end
	end)
	connect(service.InputEnded,function(event)
		if not self.Alive or not self.Active then return end
		if not visible(root) then self:Cancel();self:ReleaseFocus();self.Suspended:Fire();return end
		if event.UserInputType==Enum.UserInputType.Keyboard then
			if self.Keys[event.KeyCode] then self.Consumed[event]=true;self.Keys[event.KeyCode]=nil end
			return
		end
		local touch=event.UserInputType==Enum.UserInputType.Touch
		if not touch and event.UserInputType~=Enum.UserInputType.MouseButton1 then return end
		local key=if touch then event else mouseKey;local pressed=self.Pointers[key];if not pressed then return end
		self.Pointers[key]=nil;if self.Pressed==pressed then self.Pressed=nil end
		self.Consumed[event]=true;pressVisual(pressed,false)
		local entry=pressed.Entry
		if entry then
			if pressed.Dragging then if entry.DragEnd then entry.DragEnd(event,false) end
			elseif pressed.Dragged then if entry.Cancel then entry.Cancel() end
			elseif entry.Finish then entry.Finish(event)
			elseif entry.Action and entry.Enabled~=false then local target=pick(event.Position);if target==entry then entry.Action(event) end end
		end
		if self.Alive and not touch then mousePosition=point(event.Position);local target=pick(event.Position,true);hover(target);self:RefreshCursor() end
	end)
	connect(service.WindowFocusReleased,function()mouse=false;if self.Alive then self:Cancel();self:ReleaseFocus();self.Suspended:Fire() end end)
	connect(service.WindowFocused,function()
		mouse=service.MouseEnabled~=false;mousePosition=point(service:GetMouseLocation())-guiService:GetGuiInset()
		if self.Alive then self:RefreshCursor()end
	end)
	connect(root:GetPropertyChangedSignal('Visible'),function()if not root.Visible then self:Cancel();self:ReleaseFocus();self.Suspended:Fire() end end)
	local function geometryChanged()
		if not self.Alive or not self.Active or not service.MouseEnabled then return end
		local target=pick(mousePosition,true);hover(target)
		self:RefreshCursor()
		local pressed=self.Pointers[mouseKey]
		if pressed and pressed.Entry and not pressed.Dragged then pressVisual(pressed,target==pressed.Entry) end
	end
	connect(root:GetPropertyChangedSignal('AbsolutePosition'),geometryChanged)
	connect(root:GetPropertyChangedSignal('AbsoluteSize'),geometryChanged)
	function self:Destroy()
		if not self.Alive then return end;self:Cancel();self:ReleaseFocus();self.Alive=false
		if cursorTask then pcall(scheduler.cancel,cursorTask);cursorTask=nil end
		for _,connection in self.Connections do connection:Disconnect() end;table.clear(self.Connections)
		for _,entry in table.clone(self.Entries) do entry.Unbind() end
		for _,record in table.clone(self.Scrollers) do record.Remove() end
		table.clear(self.Scrollers);table.clear(self.Entries);table.clear(self.Consumed);table.clear(self.Keys)
		self.PointerDown=nil;self.TooltipHandler=nil;self.Modal=nil;self.Focus=nil;self.PointerDownSignal:Destroy();self.Suspended:Destroy()
	end
	return self
end
return Input
