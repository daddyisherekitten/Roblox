--!nonstrict
-- Owned listeners only; requiring this module never connects native services.
local Signal={}
function Signal.new()
	local entries={};local self={}
	function self:Connect(callback)
		local entry={Connected=true};entries[entry]=callback
		function entry:Disconnect()if not self.Connected then return end;self.Connected=false;entries[self]=nil end
		return entry
	end
	function self:Fire(...)
		local failed,first=false,nil
		for entry,callback in table.clone(entries)do
			if entry.Connected then local ok,value=pcall(callback,...);if not ok and not failed then failed,first=true,value end end
		end
		if failed then error(first,0)end
	end
	function self:Destroy()for entry in entries do entry:Disconnect()end end
	return self
end
return Signal
