--!nonstrict
-- Adapts the imported controls to the existing mouse/touch owner and content routing.
local Input=require(script.Parent.Input)
local Theme=require(script.Parent.UI.Theme)
local Router={}
local function descendant(object,root)
	while object do if object==root then return true end;object=object.Parent end
	return false
end
function Router.new(manager,service,playerGui)
	local self=Input.new(manager.Root,service,playerGui)
	local disabled,registered={},{}
	local modal,onModalBlocked,focused
	local clock=manager.Clock
	local player=game:GetService('Players').LocalPlayer
	local mouse=manager.Options.Services and manager.Options.Services.Mouse or(player and player.GetMouse and player:GetMouse())
	local ownsCursor,previousCursor,lastCursor=false,nil,nil
	self.UpdateCursor=function(entry)
		if not mouse then return end
		if entry and not entry.Passive then
			if not ownsCursor then previousCursor=mouse.Icon;ownsCursor=true end
			lastCursor=entry.Cursor or Theme.cursor.default
			if mouse.Icon~=lastCursor then mouse.Icon=lastCursor end
		elseif ownsCursor then
			if mouse.Icon==lastCursor then mouse.Icon=previousCursor or''end
			ownsCursor=false;previousCursor=nil;lastCursor=nil
		end
	end
	local function belongs(native)
		if not modal then return true end
		for _=1,32 do if not native then return false end;if native.frame==modal then return true end;native=native.owner end
		return false
	end
	local function blocked(position,notify)
		local window=manager:GetWindowAt(position)
		if not window then return false end
		local callback
		if not belongs(window.Native)then callback=onModalBlocked or true
		else callback=disabled[window.Root]end
		if not callback then return false end
		if notify and type(callback)=='function'then callback(position)end
		return true
	end
	self.BeforePointerDown=function(event)return blocked(event.Position,true)end
	self.FilterPointer=function(position)return not blocked(position,false)end
	self.PointerDown=function(_,event,owned)
		if owned then local window=manager:GetWindowAt(event.Position);if window then manager:Focus(window)end end
	end
	function self:CanReceive(window,position)
		return window.Alive and self:canFocus(window.Native) and not blocked(position,false)
	end
	function self:canFocus(native)return native.enabled and belongs(native)end
	function self:register(gui,handlers,cleanup)
		local start,last,dragging,lastClick
		local draggable=handlers.onDragStart or handlers.onDrag or handlers.onDragEnd
		local function point(event)return Vector2.new(event.Position.X,event.Position.Y)end
		local function finish(event,cancelled)
			local at=if event then point(event)else last or start
			if dragging then
				dragging=false
				if handlers.onDragEnd then handlers.onDragEnd(at,at-start,cancelled==true)end
				return
			end
			if cancelled then if handlers.onUp then handlers.onUp(1,at,false)end;return end
			local inside=manager:GetWindowAt(at)~=nil and self:HitTest(at)==gui
			if handlers.onUp then handlers.onUp(1,at,inside)end
			if not inside then return end
			local now=clock()
			if handlers.onDoubleClick and lastClick and now-lastClick.Time<=0.5 and math.abs(at.X-lastClick.X)<=4 and math.abs(at.Y-lastClick.Y)<=4 then
				lastClick=nil;handlers.onDoubleClick(at)
			else
				lastClick={Time=now,X=at.X,Y=at.Y};if handlers.onClick then handlers.onClick(at)end
			end
		end
		local remove,entry=self:Bind(gui,{
			Enabled=handlers.enabled,
			Cursor=handlers.cursor,
			Passive=handlers.onActivate~=nil and not(handlers.onDown or handlers.onClick or draggable),
			Hover=function(value)
				local callback=if value then handlers.onEnter else handlers.onLeave
				if callback then callback()end
			end,
			Begin=function(event)
				start=point(event);last=start;dragging=false
				if handlers.onActivate then handlers.onActivate(start)end
				if handlers.onDown then handlers.onDown(1,start)end
			end,
			Move=function(event)
				last=point(event);local delta=last-start
				if draggable and not dragging and(math.abs(delta.X)>4 or math.abs(delta.Y)>4)then
					dragging=true;if handlers.onDragStart then handlers.onDragStart(last,start)end
				end
				if dragging and handlers.onDrag then handlers.onDrag(last,delta,start)end
			end,
			Finish=function(event)finish(event,false)end,
			Cancel=function()finish(nil,true)end,
		})
		registered[gui]={Handlers=handlers,Entry=entry}
		cleanup:add(function()registered[gui]=nil;remove()end)
		return remove
	end
	function self:handlersOf(gui)
		local item=registered[gui]
		if not item then return nil end
		return setmetatable({}, {__index=function(_,key)return item.Handlers[key]end,__newindex=function(_,key,value)
			item.Handlers[key]=value;if key=='enabled'then item.Entry.Enabled=value end
		end})
	end
	function self:refresh()if self.Pressed and self.Pressed.Entry.Enabled==false then self:Cancel()end end
	function self:setModal(root,callback)modal,onModalBlocked=root,callback;self:Cancel()end
	function self:getModal()return modal end
	function self:setDisabled(root,callback)
		disabled[root]=callback or true;self:Cancel()
		local text=service:GetFocusedTextBox()
		if text and descendant(text,root)then text:ReleaseFocus(false)end
	end
	function self:clearDisabled(root)disabled[root]=nil end
	function self:isDisabled(root)return disabled[root]~=nil end
	function self:setFocus(root)focused=root end
	function self:getFocus()return focused end
	self.Shortcut=function(event,processed)
		if processed then return false end
		if event.KeyCode==Enum.KeyCode.Escape and manager.Fullscreen then manager.Fullscreen:SetFullscreen(false);return true end
		local item=focused and registered[focused]
		local window=manager:GetFocused()
		if not item or not window or window.Native.keyPressed:listenerCount()==0 then return false end
		if item.Handlers.onKey then item.Handlers.onKey(event.KeyCode,true);return true end
		return false
	end
	self.KeyReleased=function(event)
		local item=focused and registered[focused]
		if item and item.Handlers.onKey then item.Handlers.onKey(event.KeyCode,false)end
	end
	local destroy=self.Destroy
	function self:Destroy()
		destroy(self);table.clear(disabled);table.clear(registered);modal=nil;onModalBlocked=nil;focused=nil
	end
	return self
end
return Router
