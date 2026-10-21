--!strict
-- Suspended interpreter stacks only; Promise reactions schedule continuations.
-- No task.spawn/task.wait, timer polling or permanent frame connection.
local VM=require(script.Parent.VM)
local AsyncFunctions={}
local AWAIT={}
local HOST={}
function AsyncFunctions.new(options: any): any
	options=table.clone(options)
	local self={Alive=true}
	-- Reachable await reactions own their suspended stack. Unreachable cycles
	-- can be collected rather than retained for the document's entire lifetime.
	local records=setmetatable({},{__mode="kv"})
	local function release(record)
		if record.Done then return end;record.Done=true
		local thread=record.Thread;record.Thread=nil
		if thread then
			records[thread]=nil
			local status=coroutine.status(thread)
			if status=="suspended" or status=="dead" then pcall(coroutine.close,thread) end
		end
		record.Resolve,record.Reject,record.HostAction=nil,nil,nil
	end
	local function resume(record,rejected,value)
		if not self.Alive or record.Done then return VM.Undefined end
		local ok,result
		while true do
			ok,result=options.Resume(record,rejected,value)
			if not self.Alive or record.Done then return VM.Undefined end
			if not ok or result~=HOST or coroutine.status(record.Thread)=="dead" then break end
			local action=record.HostAction;record.HostAction=nil
			-- Run synchronous, yieldable host work outside this interpreted stack.
			-- A nested async call may itself be running in another managed stack;
			-- HostCall forwards its suspension until the actual host entry owns it.
			local succeeded,packed=pcall(function()return table.pack(self:HostCall(action))end)
			if not self.Alive or record.Done then return VM.Undefined end
			rejected,value=not succeeded,packed
		end
		if not ok then
			local reject=record.Reject;release(record);reject({VM.exceptionValue(result)})
		elseif coroutine.status(record.Thread)=="dead" then
			local resolve=record.Resolve;release(record);resolve({result})
		elseif result~=AWAIT then
			local reject=record.Reject;release(record)
			reject({VM.error("Error","Unexpected suspension in an async function")})
		end
		return VM.Undefined
	end
	function self:Start(body,context)
		assert(self.Alive,"JavaScript async functions disposed")
		local promise,resolve,reject=options.Create()
		local record={Thread=coroutine.create(body),Resolve=resolve,Reject=reject,Depth=1,Started=false,Done=false,Context=context}
		records[record.Thread]=record
		resume(record,false,VM.Undefined)
		return promise
	end
	function self:Await(value)
		assert(self.Alive,"JavaScript async functions disposed")
		local record=records[coroutine.running()]
		assert(record and not record.Done,"await requires an active async function")
		options.Wait(value,function(args)return resume(record,false,args[1])end,
			function(args)return resume(record,true,args[1])end)
		local rejected,result=coroutine.yield(AWAIT)
		assert(self.Alive,"JavaScript async functions disposed")
		if rejected then VM.throw(result) end
		return result
	end
	function self:HostCall(action)
		assert(self.Alive,"JavaScript async functions disposed")
		assert(type(action)=="function","HostCall requires a host function")
		local record=records[coroutine.running()]
		if not record then return action() end
		assert(not record.Done,"JavaScript async function disposed")
		record.HostAction=action
		local rejected,result=coroutine.yield(HOST)
		assert(self.Alive,"JavaScript async functions disposed")
		if rejected then error(result,0) end
		return table.unpack(result,1,result.n)
	end
	function self:Destroy()
		if not self.Alive then return end;self.Alive=false
		for _,record in records do release(record) end
		table.clear(records);table.clear(options)
	end
	return self
end
return AsyncFunctions
