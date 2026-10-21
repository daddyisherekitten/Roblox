--!strict
-- The optional integration filters background-tab input and frame callbacks.
local Scope={}
function Scope.new(nativeInput,nativeRun,blocked,keyboardPassthrough)
	local self={Alive=true,Active=false,Frames=true,Signals={}}
	local scope=self
	local passedKeys={}
	local function signal(native,always,frame,filtered,keepConnected,keyPhase)
		local callbacks={};local connection;local api={}
		function api:Refresh()
			local enabled=scope.Alive and #callbacks>0 and (always or keepConnected or (if frame then scope.Frames else scope.Active))
			if not enabled and connection then connection:Disconnect();connection=nil end
			if enabled and native and not connection then connection=native:Connect(function(...)
				-- Roblox may already have scheduled a callback before Disconnect.
				if not scope.Alive or not(always or(if frame then scope.Frames else scope.Active))then return end
				local event=...
				local pass=false
				if keyPhase and keyboardPassthrough and event.UserInputType==Enum.UserInputType.Keyboard then
					pass=keyboardPassthrough(event,keyPhase=='up'and passedKeys[event.KeyCode]==true)==true
					passedKeys[event.KeyCode]=if keyPhase=='down'and pass then true else nil
				end
				if filtered and blocked and blocked(...)and not pass then return end
				api:Fire(...)
			end)end
		end
		function api:Connect(fn)
			local record={Connected=true,Callback=fn};table.insert(callbacks,record)
			function record:Disconnect()
				if not self.Connected then return end;self.Connected=false;self.Callback=nil
				local index=table.find(callbacks,self);if index then table.remove(callbacks,index)end;api:Refresh()
			end
			api:Refresh();return record
		end
		function api:Fire(...)
			if not scope.Alive then return end
			for _,record in table.clone(callbacks)do if record.Connected then
				local ok,message=pcall(record.Callback,...);if not ok then warn('Browser input: '..tostring(message))end
			end end
		end
		function api:Clear()for _,record in callbacks do record.Connected=false;record.Callback=nil end;table.clear(callbacks);api:Refresh()end
		table.insert(self.Signals,api);return api
	end
	local release=signal(nativeInput.WindowFocusReleased,true)
	local focused=signal(nativeInput.WindowFocused,false)
	-- Keep the began listener registered so a host focus switch in an earlier
	-- native callback can deliver the first click. Its dispatch still checks Active.
	local filtered={InputBegan=signal(nativeInput.InputBegan,false,false,true,true,'down'),InputChanged=signal(nativeInput.InputChanged,false,false,true),InputEnded=signal(nativeInput.InputEnded,false,false,true,false,'up'),WindowFocusReleased=release,WindowFocused=focused}
	local methods={}
	self.Input=setmetatable({}, {__index=function(_,key)
		if filtered[key]then return filtered[key]end
		-- Inactive controllers can also wake from native geometry signals.
		-- Starting them without a mouse lease prevents saving another tab's cursor.
		if key=='MouseEnabled'and not self.Active then return false end
		local value=nativeInput[key]
		if type(value)=='function'then
			if not methods[key]then methods[key]=function(_,...)return value(nativeInput,...)end end
			return methods[key]
		end
		return value
	end,__newindex=function(_,key,value)if self.Alive and self.Active then nativeInput[key]=value end end})
	self.Run={RenderStepped=signal(nativeRun.RenderStepped,false,true),Heartbeat=signal(nativeRun.Heartbeat,false,true)}
	function self:SetActive(active)
		if not self.Alive or self.Active==active then return end
		if not active then table.clear(passedKeys);release:Fire()end
		self.Active=active;for _,entry in self.Signals do entry:Refresh()end;if active then focused:Fire()end
	end
	function self:SetFrames(active)if not self.Alive or self.Frames==active then return end;self.Frames=active;for _,entry in self.Signals do entry:Refresh()end end
	function self:Destroy()
		if not self.Alive then return end;self:SetActive(false);self.Alive=false
		for _,entry in self.Signals do entry:Clear()end;table.clear(self.Signals);table.clear(methods)
	end
	return self
end
return Scope
