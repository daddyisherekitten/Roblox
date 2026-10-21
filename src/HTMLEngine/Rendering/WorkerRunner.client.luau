--!strict
-- This template is inactive in ReplicatedStorage and runs only after WorkerHost
-- clones it under a dedicated Actor in the page's PlayerGui ancestry.
local actor=assert(script:GetActor())
local bridge=actor:WaitForChild("Bridge") :: BindableEvent
local module=(actor:WaitForChild("WorkerModule") :: ObjectValue).Value
local loaded,WorkerRealm=pcall(require,assert(module))
if not loaded then
	bridge:Fire("error",{message=tostring(WorkerRealm)});bridge:Fire("exit");return
end
local realm;local busy=false;local stopped=false;local pending={};local pendingBytes=0
local timer;local generation=0
local function stop()
	stopped=true;generation+=1
	if timer then pcall(task.cancel,timer);timer=nil end
	table.clear(pending);pendingBytes=0
	if realm then realm:Destroy()end
end
local function emit(kind,payload)
	task.synchronize()
	if actor.Parent then bridge:Fire(kind,payload)end
	task.desynchronize()
end
local function wake()if not stopped then actor:SendMessage("pump")end end
local function schedule()
	generation+=1;local expected=generation
	if timer then pcall(task.cancel,timer);timer=nil end
	local due=realm and realm:NextDue()
	if due then timer=task.delay(math.max(0,due-os.clock()),function()
		if not stopped and expected==generation then timer=nil;wake()end
	end)end
end
local function drive()
	if busy or stopped or not realm then return end;busy=true
	local ok,message=pcall(function()
		while #pending>0 and realm.Alive and not realm.Closing do
			local wire=table.remove(pending,1);pendingBytes-=wire.ByteLength or 0;realm:PostMessage(wire)
		end
		realm:Pump();schedule()
	end)
	if not ok then stop();emit("error",{message=tostring(message)});emit("exit")end
	busy=false
end
actor:BindToMessageParallel("start",function(spec)
	if realm or busy or stopped then return end;busy=true
	local ok,message=pcall(function()
		realm=WorkerRealm.new(spec,{Sources=spec.sources,Wake=wake,
			Message=function(wire)emit("message",wire)end,Error=function(details)emit("error",details)end,
			Exit=function()stop();emit("exit")end,
			Checkpoint=function()assert(actor.Parent,"Worker terminated")end})
		realm:Start()
	end)
	if not ok then stop();emit("error",{message=tostring(message),filename=spec.url});emit("exit")end
	busy=false;drive()
end)
actor:BindToMessageParallel("message",function(wire)
	if stopped then return end
	if #pending>=1024 or pendingBytes+(wire.ByteLength or 0)>4194304 then
		stop();emit("error",{message="Worker incoming queue budget exceeded"});emit("exit");return
	end
	table.insert(pending,wire);pendingBytes+=wire.ByteLength or 0;drive()
end)
actor:BindToMessageParallel("pump",drive)
bridge:Fire("ready")
