--!strict
-- One host per browser session. JS reads/writes never wait for Roblox networking.
-- Only a durable server acknowledgement releases an outstanding write batch.
local Storage = require(script.Parent.Parent.JavaScript.Storage)
local Protocol = require(script.Parent.Protocol)
local Client = {}
Client.__index = Client

function Client.new(options: any): any
	assert(type(options.Load) == "function" and type(options.Send) == "function", "Storage transport is required")
	assert(Protocol.clientId(options.ClientId), "Storage client ID is required")
	local self = setmetatable({Alive=true, Options=options, Task=options.Task or task,
		Clock=options.Clock or os.clock, ClientId=options.ClientId, Origins={}, OriginCount=0, Observers={}, Disconnect=nil}, Client)
	if options.Subscribe then self.Disconnect=options.Subscribe(function(reply) self:_Reply(reply) end) end
	return self
end

function Client:_Notify(state: any)
	local status = if state.Area == nil then "unavailable" elseif state.Flight or #state.Pending>0 then "pending" else "saved"
	state.Status=status
	for _, observer in table.clone(self.Observers) do
		if observer.Origin==state.Origin then
			local ok,message=pcall(observer.Callback,status,state.Error)
			if not ok and self.Options.Diagnostic then self.Options.Diagnostic("Web Storage observer: "..tostring(message)) end
		end
	end
end

function Client:_Error(state: any, message: string)
	local changed=state.Error~=message;state.Error=message;self:_Notify(state)
	if changed and self.Options.Diagnostic then self.Options.Diagnostic("Web Storage: "..message) end
end

function Client:Observe(url: string, callback: any): any
	local origin=Protocol.origin(url)
	local observer={Origin=origin,Callback=callback};table.insert(self.Observers,observer)
	local state=origin and self.Origins[origin]
	if state then callback(state.Status,state.Error) else callback("unavailable",nil) end
	return function() local at=table.find(self.Observers,observer);if at then table.remove(self.Observers,at) end end
end

function Client:_Retry(state: any)
	local flight=state.Flight;if not flight then return end
	flight.Generation+=1;local generation=flight.Generation
	local delay=math.min(30,5*2^math.min(flight.Attempts-1,3))
	flight.Retry=self.Task.delay(delay,function()
		if self.Alive and state.Flight==flight and flight.Generation==generation then
			flight.Retry=nil;self:_Send(state)
		end
	end)
end

function Client:_StopRetry(flight: any)
	flight.Generation+=1
	local retry=flight.Retry;flight.Retry=nil
	-- Injected transports may provide only a delay callback. Keep generation
	-- guards for those hosts; native tasks can release the suspended closure now.
	if retry and self.Task.cancel then self.Task.cancel(retry)end
end

function Client:_Send(state: any)
	local flight=state.Flight;if not self.Alive or not flight then return end
	flight.Attempts+=1
	local ok,message=pcall(self.Options.Send,flight.Packet)
	if not ok then self:_Error(state,tostring(message)) end
	-- Fake/test transports may acknowledge synchronously; do not resurrect them.
	if state.Flight==flight then self:_Retry(state) end
end

function Client:_Dispatch(state: any)
	if not self.Alive or state.Flight or #state.Pending==0 then return end
	local batch,chars={},0
	for _,entry in state.Pending do
		if #batch>=Protocol.MaxChanges or chars+entry.Chars>Protocol.MaxWireBytes then break end
		table.insert(batch,entry.Change);chars+=entry.Chars
	end
	assert(#batch>0,"Storage mutation exceeds transport budget")
	local rest={};for i=#batch+1,#state.Pending do table.insert(rest,state.Pending[i]) end;state.Pending=rest
	state.Flight={Packet={Origin=state.Origin,ClientId=self.ClientId,Sequence=state.Sequence,Changes=batch},
		Chars=chars,Count=#batch,Generation=0,Attempts=0}
	state.Sequence+=1;self:_Notify(state);self:_Send(state)
end

function Client:_Schedule(state: any)
	if state.Scheduled then return end;state.Scheduled=true
	self.Task.defer(function() state.Scheduled=false;if self.Alive then self:_Dispatch(state) end end)
end

function Client:_Commit(state: any, change: any): boolean
	if not self.Alive then return false end
	local encoded=Protocol.encodeChange(change)
	local chars=#(encoded.Key or "")+#(encoded.Value or "")+32
	local count=#state.Pending+(if state.Flight then state.Flight.Count else 0)
	-- Consecutive unsent set operations on the same key can safely share a slot.
	local last=state.Pending[#state.Pending]
	local replace=last and encoded.Kind=="set" and last.Change.Kind=="set" and last.Change.Key==encoded.Key
	local prospective=state.PendingChars+chars-(if replace then last.Chars else 0)
	if chars>Protocol.MaxWireBytes or prospective>Protocol.MaxPendingBytes or count+(if replace then 0 else 1)>4096 then return false end
	if replace then
		state.PendingChars-=last.Chars;last.Change,last.Chars=encoded,chars
	else table.insert(state.Pending,{Change=encoded,Chars=chars}) end
	state.PendingChars+=chars;self:_Schedule(state);self:_Notify(state);return true
end

-- Hosts that close a browser gracefully can wait for durable acknowledgement.
-- Normal storage operations and page destruction never call this yielding API.
function Client:Flush(timeout: number?): boolean
	local deadline=self.Clock()+(timeout or 10)
	while self.Alive do
		local pending=false
		for _,state in self.Origins do
			if #state.Pending>0 or state.Flight then pending=true;self:_Dispatch(state) end
		end
		if not pending then return true end
		if self.Clock()>=deadline then return false end
		self.Task.wait(.05)
	end
	return false
end

function Client:_Reply(reply: any)
	if not self.Alive or type(reply)~="table" or reply.ClientId~=self.ClientId then return end
	local state=self.Origins[reply.Origin];local flight=state and state.Flight
	if not flight or reply.Sequence~=flight.Packet.Sequence then return end
	if reply.Ok and reply.Status=="saved" then
		self:_StopRetry(flight);state.PendingChars-=flight.Chars;state.Flight=nil;state.Error=nil
		self:_Notify(state);self:_Schedule(state)
	elseif not reply.Ok then self:_Error(state,tostring(reply.Error or "Storage save failed")) end
end

function Client:Prepare(url: string): any
	local origin=Protocol.origin(url)
	if not self.Alive or not origin then return function() return nil end end
	local state=self.Origins[origin]
	if not state then
		if self.OriginCount>=32 then return function() return nil end end
		state={Origin=origin,Session=Storage.createArea({QuotaBytes=Protocol.QuotaBytes,MaxEntries=Protocol.MaxEntries}),Area=nil,Pending={},PendingChars=0,Sequence=1,Status="unavailable"}
		self.OriginCount+=1
		self.Origins[origin]=state
	end
	if not state.Area and not state.Loading then
		local attempt={};state.Loading=attempt
		self.Task.spawn(function()
			local ok,response=pcall(self.Options.Load,origin)
			if not self.Alive or state.Loading~=attempt then return end
			state.Loading=nil
			if not ok or type(response)~="table" or not response.Ok then
				state.Denied=ok and type(response)=="table" and response.Denied==true
				self:_Error(state,tostring(if ok and type(response)=="table" then response.Error else response));return
			end
			local loaded,message=Protocol.decodeRecord(response.Record,origin)
			if not loaded then self:_Error(state,tostring(message));return end
			local area=Storage.createArea({QuotaBytes=Protocol.QuotaBytes,MaxEntries=Protocol.MaxEntries,Durability="datastore",Commit=function(change) return self:_Commit(state,change) end})
			state.Sequence=Protocol.receipt(response.Record.Receipts,self.ClientId)+1
			area.Values,area.Order,area.Bytes=loaded.Values,loaded.Order,loaded.Bytes;state.Area=area;state.Error=nil;state.Denied=false;self:_Notify(state)
		end)
	end
	local deadline=self.Clock()+(self.Options.LoadTimeout or 20)
	while self.Alive and state.Loading and self.Clock()<deadline do self.Task.wait(.05) end
	if self.Alive and state.Loading then self:_Error(state,"Storage load timed out; localStorage is unavailable until loading completes") end
	return function(kind)
		if not self.Alive or state.Denied then return nil end
		return if kind=="local" then state.Area elseif kind=="session" then state.Session else nil
	end
end

function Client:Destroy()
	if not self.Alive then return end
	-- Fire the last unsent batch while the transport still exists. Server teardown
	-- flushes accepted batches; abrupt disconnections cannot confirm delivery.
	for _,state in self.Origins do if not state.Flight then self:_Dispatch(state) end end
	self.Alive=false
	if self.Disconnect then self.Disconnect();self.Disconnect=nil end
	for _,state in self.Origins do
		if state.Flight then self:_StopRetry(state.Flight)end
		for _,area in {state.Session,state.Area} do if area then table.clear(area.Values);table.clear(area.Order);table.clear(area.Subscribers);area.Bytes=0 end end
		table.clear(state.Pending);state.Flight=nil
	end
	table.clear(self.Observers);table.clear(self.Origins)
end

function Client.fromReplicatedStorage(replicatedStorage: any, options: any?): any
	options=table.clone(options or {})
	options.ClientId=options.ClientId or game:GetService("HttpService"):GenerateGUID(false):gsub("-","")
	local loadRemote,changesRemote,connection,receive
	local function connect()
		if loadRemote and changesRemote then return end
		local folder=replicatedStorage:WaitForChild("HTMLStorage",10)
		assert(folder,"HTMLStorage server is missing; sync the server script with Rojo")
		local loaded=folder:WaitForChild("Load",5);local changes=folder:WaitForChild("Changes",5)
		assert(loaded and changes,"HTMLStorage server transport is incomplete")
		-- Two origins may be prepared concurrently while remotes replicate.
		if loadRemote and changesRemote then return end
		assert(receive,"Storage browser was closed while connecting")
		loadRemote,changesRemote=loaded,changes
		connection=changesRemote.OnClientEvent:Connect(function(reply) if receive then receive(reply) end end)
	end
	options.Load=function(origin) connect();return loadRemote:InvokeServer(origin) end
	options.Send=function(packet) assert(changesRemote,"Storage transport is unavailable");changesRemote:FireServer(packet) end
	options.Subscribe=function(callback)
		receive=callback
		return function() receive=nil;if connection then connection:Disconnect();connection=nil end end
	end
	return Client.new(options)
end
return Client
