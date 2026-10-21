--!nonstrict
-- Every resource has one owner. Cleanup happens in reverse creation order.
local Lifetime={}
local function release(resource)
	if type(resource)=='function' then resource()
	elseif typeof(resource)=='Instance' then if resource:IsA('TweenBase') then resource:Cancel() end;resource:Destroy()
	elseif typeof(resource)=='RBXScriptConnection' then resource:Disconnect()
	elseif type(resource)=='thread' then if coroutine.status(resource)~='dead' and resource~=coroutine.running() then task.cancel(resource) end
	elseif resource and type(resource.Disconnect)=='function' then resource:Disconnect()
	elseif resource and type(resource.Destroy)=='function' then resource:Destroy()
	elseif resource and type(resource.Cancel)=='function' then resource:Cancel() end
end
function Lifetime.new()
	local self={Alive=true,Resources={}}
	function self:Add(resource)
		if resource==nil then return resource end
		if self.Alive then table.insert(self.Resources,resource) else pcall(release,resource) end
		return resource
	end
	function self:Child()
		local child=Lifetime.new();self:Add(child)
		child:Add(function()
			if self.Alive then local index=table.find(self.Resources,child);if index then table.remove(self.Resources,index) end end
		end)
		return child
	end
	function self:Destroy()
		if not self.Alive then return end
		self.Alive=false
		for index=#self.Resources,1,-1 do
			local resource=self.Resources[index];self.Resources[index]=nil
			local ok,message=pcall(release,resource)
			if not ok then warn('Wayline cleanup: '..tostring(message)) end
		end
	end
	return self
end
return Lifetime
