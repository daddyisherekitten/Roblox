--!strict
-- Independent callback ownership; no renderer or game services.
local Signal={}
function Signal.new()
	local entries={};local alive=true;local self={}
	function self:Connect(callback)
		assert(alive and type(callback)=='function','Cannot connect a disposed browser signal')
		local entry={Callback=callback,Connected=true};table.insert(entries,entry)
		function entry:Disconnect()
			if not self.Connected then return end;self.Connected=false;self.Callback=nil
			local index=table.find(entries,self);if index then table.remove(entries,index)end
		end
		return entry
	end
	function self:Fire(...)
		if not alive then return end
		for _,entry in table.clone(entries)do if entry.Connected then
			local ok,message=pcall(entry.Callback,...)
			if not ok then warn('Browser callback: '..tostring(message))end
		end end
	end
	function self:Count()return #entries end
	function self:Destroy()
		if not alive then return end;alive=false
		for _,entry in entries do entry.Connected=false;entry.Callback=nil end;table.clear(entries)
	end
	return self
end
return Signal
