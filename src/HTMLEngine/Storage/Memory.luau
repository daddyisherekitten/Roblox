--!strict
-- One current-run host, shared by the documents/windows that receive it.
-- No transport, deferred writes or persistent backend is created.
local Storage = require(script.Parent.Parent.JavaScript.Storage)
local Protocol = require(script.Parent.Protocol)
local Memory = {}
Memory.__index = Memory

function Memory.new(): any
	return setmetatable({Alive=true, Origins={}, OriginCount=0, Observers={}}, Memory)
end

function Memory:Prepare(url: string): any
	local origin=Protocol.origin(url)
	if not self.Alive or not origin then return function()return nil end end
	local state=self.Origins[origin]
	if not state then
		if self.OriginCount>=32 then return function()return nil end end
		state={Local=Storage.createArea({QuotaBytes=Protocol.QuotaBytes,MaxEntries=Protocol.MaxEntries}),
			Session=Storage.createArea({QuotaBytes=Protocol.QuotaBytes,MaxEntries=Protocol.MaxEntries})}
		self.Origins[origin]=state;self.OriginCount+=1
		for _,observer in table.clone(self.Observers)do
			if observer.Origin==origin then observer.Callback("memory",nil)end
		end
	end
	return function(kind)
		if not self.Alive then return nil end
		return if kind=="local"then state.Local elseif kind=="session"then state.Session else nil
	end
end

function Memory:Observe(url: string, callback: any): any
	local origin=Protocol.origin(url)
	if not self.Alive then callback("unavailable",nil);return function()end end
	local observer={Origin=origin,Callback=callback};table.insert(self.Observers,observer)
	callback(if origin and self.Origins[origin]then "memory"else "unavailable",nil)
	return function()
		local index=table.find(self.Observers,observer)
		if index then table.remove(self.Observers,index)end
	end
end

function Memory:Flush(): boolean
	-- Kept for host compatibility. Memory storage has nothing to send or await.
	return self.Alive
end

function Memory:Destroy()
	if not self.Alive then return end
	self.Alive=false
	for _,state in self.Origins do
		for _,area in {state.Local,state.Session}do
			table.clear(area.Values);table.clear(area.Order);table.clear(area.Subscribers);area.Bytes=0
		end
	end
	table.clear(self.Origins);table.clear(self.Observers);self.OriginCount=0
end

return Memory
