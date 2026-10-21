--!strict
-- Loading-only cooperative work. Scopes follow a coroutine, never the shared DOM.
-- Concurrent native loaders share one deadline per Heartbeat, rather than each
-- spending a full CPU slice in the same frame. No idle connection is retained.
local Budget=require(script.Parent.Rendering.WorkBudget)
local WorkContext={}
local CANCELLED=table.freeze(setmetatable({},{__tostring=function()return 'Page loading cancelled'end}))
function WorkContext.isCancelled(value: any): boolean return value==CANCELLED end
local scopes=setmetatable({},{__mode="k"})
local nativeGate
local function acquireGate(signal)
	local gate=nativeGate
	if not gate then
		gate={Owners={},Deadline=nil};nativeGate=gate
		gate.Connection=signal:Connect(function()gate.Deadline=nil end)
	end
	return gate
end
function WorkContext.checkpoint(force: boolean?)
	local scope=scopes[coroutine.running()]
	if scope then scope.Check(false,force)end
end
function WorkContext.budget()
	local scope=scopes[coroutine.running()]
	return if scope and scope.Owner then scope.Budget else nil
end
local function invoke(scope,operation,...)
	local thread=coroutine.running();local previous=scopes[thread];scopes[thread]=scope
	local result=table.pack(pcall(operation,...));scopes[thread]=previous
	if not result[1]then error(result[2],0)end
	return table.unpack(result,2,result.n)
end
function WorkContext.with(check,operation,...)
	return invoke(if check then {Check=check}else nil,operation,...)
end
-- A realm constructor must finish wiring its destructor before cancellation
-- escapes. It still yields; its caller disposes the completed, unpublished realm.
function WorkContext.completeConstruction(operation,...)
	local scope=scopes[coroutine.running()]
	if not scope or not scope.Owner then return operation(...)end
	return invoke({Check=function(_,force)scope.Check(true,force)end,Budget=scope.Budget,Owner=scope.Owner},operation,...)
end
function WorkContext.new(milliseconds: number,services: any?): any?
	if milliseconds<=0 then return nil end
	services=services or{};local taskAPI=services.Task or task;local now=services.Clock or os.clock;local alive=services.Alive
	local owner={Active=true,Yields=0,WaitMS=0,ActiveMS=0,MaxSliceMS=0,Runs=0,Running=0}
	local gate=services.FrameGate
	if not gate and taskAPI==task and now==os.clock and game then
		local ok,signal=pcall(function()return game:GetService("RunService").Heartbeat end)
		if ok and signal then gate=acquireGate(signal)end
	end
	local function interval()
		local value=milliseconds/1000
		if gate then for _,limit in gate.Owners do value=math.min(value,limit)end end
		return value
	end
	if gate then gate.Owners[owner]=milliseconds/1000 end
	local function releaseGate()
		if gate and not owner.Active and owner.Running==0 then
			gate.Owners[owner]=nil
			if gate==nativeGate and not next(gate.Owners)then gate.Connection:Disconnect();nativeGate=nil end
		end
	end
	local function beginFrame()
		if gate and not gate.Deadline then gate.Deadline=now()+interval()end
	end
	function owner:Run(operation,...)
		if not self.Active then return operation(...)end
		local previous=scopes[coroutine.running()]
		if previous and previous.Owner==self then return operation(...)end
		self.Runs+=1;self.Running+=1;beginFrame()
		local budget=Budget.new(milliseconds,taskAPI,now)
		local function check(completing: boolean?,force: boolean?)
			if alive and not completing and not alive()then error(CANCELLED,0)end
			-- Finish stops new jobs. Existing jobs retain their share of the
			-- frame gate until they return, even after presentation/cancellation.
			beginFrame()
			budget:Checkpoint(force or gate and now()>=gate.Deadline)
			if alive and not completing and not alive()then error(CANCELLED,0)end
			beginFrame()
			-- Another loader may have used the frame before this waiter resumed.
			while gate and now()>=gate.Deadline do
				budget:Checkpoint(true)
				if alive and not completing and not alive()then error(CANCELLED,0)end
				beginFrame()
			end
		end
		local result=table.pack(pcall(invoke,{Check=check,Budget=budget,Owner=self},operation,...));budget:Finish();self.Running-=1;releaseGate()
		self.LastRun=budget
		self.Yields+=budget.Yields;self.WaitMS+=budget.WaitMS;self.ActiveMS+=budget.ActiveMS
		self.MaxSliceMS=math.max(self.MaxSliceMS,budget.MaxSliceMS)
		if not result[1]then error(result[2],0)end
		return table.unpack(result,2,result.n)
	end
	function owner:Finish()
		if not self.Active then return end;self.Active=false
		releaseGate()
		table.clear(services)
	end
	-- Keep the caller's service table independent of the lease's lifetime.
	services=table.clone(services)
	return owner
end
function WorkContext.runFor(page: any,operation,...)
	local work=page.LoadingWork
	if work and work.Active then return work:Run(operation,...)end
	return operation(...)
end
return WorkContext
