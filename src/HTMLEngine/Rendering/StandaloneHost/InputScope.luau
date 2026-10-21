--!strict
-- An independent HTML window owns input only while focused. Native frame
-- callbacks stay available to visible, unfocused documents.
local Scope={}
function Scope.new(input,run,blocked,diagnostic)
	local self={Alive=true,Active=false,Frames=true,Signals={}}
	local selfScope=self
	local function signal(native,always,frames,filter,keep)
		local callbacks,connection={},nil
		local api={}
		function api:Refresh()
			local enabled=#callbacks>0 and selfScope.Alive and(always or keep or(if frames then selfScope.Frames else selfScope.Active))
			if not enabled and connection then connection:Disconnect();connection=nil end
			if enabled and native and not connection then connection=native:Connect(function(...)
				if not selfScope.Alive or not(always or(if frames then selfScope.Frames else selfScope.Active))then return end
				if filter and blocked and blocked(...)then return end
				api:Fire(...)
			end)end
		end
		function api:Connect(callback)
			local record={Connected=true,Callback=callback};table.insert(callbacks,record)
			function record:Disconnect()
				if not self.Connected then return end;self.Connected=false;self.Callback=nil
				local index=table.find(callbacks,self);if index then table.remove(callbacks,index)end;api:Refresh()
			end
			api:Refresh();return record
		end
		function api:Fire(...)
			if not selfScope.Alive then return end
			for _,record in table.clone(callbacks)do if record.Connected then
				local ok,message=pcall(record.Callback,...);if not ok then diagnostic(message)end
			end end
		end
		function api:Clear()for _,record in callbacks do record.Connected=false;record.Callback=nil end;table.clear(callbacks);api:Refresh()end
		table.insert(selfScope.Signals,api);return api
	end
	local release=signal(input.WindowFocusReleased,true)
	local focused=signal(input.WindowFocused,false)
	-- A gesture that began in this document still owns its move/release after
	-- leaving its bounds. Focus loss emits the explicit cancellation boundary.
	local filtered={InputBegan=signal(input.InputBegan,false,false,true,true),InputChanged=signal(input.InputChanged,false,false,false),
		InputEnded=signal(input.InputEnded,false,false,false),WindowFocusReleased=release,WindowFocused=focused}
	local methods={}
	self.Input=setmetatable({},{__index=function(_,key)
		if filtered[key]then return filtered[key]end
		if key=='MouseEnabled'and not self.Active then return false end
		local value=input[key]
		if type(value)=='function'then
			if not methods[key]then methods[key]=function(_,...)return value(input,...)end end
			return methods[key]
		end
		return value
	end,__newindex=function(_,key,value)if self.Alive and self.Active then input[key]=value end end})
	self.Run={RenderStepped=signal(run.RenderStepped,false,true),Heartbeat=signal(run.Heartbeat,false,true)}
	function self:SetActive(active)
		if not self.Alive or self.Active==active then return end
		if not active then release:Fire()end
		self.Active=active;for _,entry in self.Signals do entry:Refresh()end;if active then focused:Fire()end
	end
	function self:SetFrames(active)if self.Alive and self.Frames~=active then self.Frames=active;for _,entry in self.Signals do entry:Refresh()end end end
	function self:Destroy()
		if not self.Alive then return end;self:SetActive(false);self.Alive=false
		for _,entry in self.Signals do entry:Clear()end;table.clear(self.Signals);table.clear(methods)
	end
	return self
end
return Scope
