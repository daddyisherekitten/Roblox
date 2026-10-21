--!strict
-- Data-only task/microtask/frame queues. Roblox scheduling lives in ScriptClock.
local VM=require(script.Parent.VM)
local EventLoop={}
local function callable(value: any): boolean
	return VM.callable(value)
end
local function integer(value: any,signed: boolean): number
	local n=VM.number(value)
	if n~=n or math.abs(n)==math.huge then return 0 end
	n=(if n<0 then math.ceil(n) else math.floor(n))%4294967296
	return if signed and n>=2147483648 then n-4294967296 else n
end
function EventLoop.new(options: any): any
	options=table.clone(options)
	local clock=options.Clock or os.clock
	local last=clock();local origin=last
	local loop={Alive=true,Timers={},Tasks={},Frames={},Microtasks={},TimerCount=0,TaskCount=0,FrameCount=0,
		Draining=false,Pumping=false,TimerLevel=0}
	local nextTimer,nextFrame,sequence,head=0,0,0,1
	local microtaskContexts={}
	local function check()assert(loop.Alive,"JavaScript event loop disposed")end
	local function now()
		last=math.max(last,clock());return last
	end
	local function wake()if options.Wake and loop.Alive then options.Wake() end end
	local function report(message)if options.Report then options.Report(message) end end
	function loop:Now(): number return now() end
	function loop:Timestamp(): number return (now()-origin)*1000 end
	function loop:QueueTask(fn: any,delaySeconds: number?)
		check();assert(callable(fn),"Task requires a function");assert(self.TaskCount<1024,"JavaScript task queue budget exceeded")
		sequence+=1;self.Tasks[sequence]={Handler=fn,Args={},Due=now()+math.max(0,delaySeconds or 0),Sequence=sequence,Task=true};self.TaskCount+=1;wake()
		return sequence
	end
	function loop:SetIdleSource(source: any?)
		assert(source==nil or self.IdleSource==nil or self.IdleSource==source,'An event loop has only one idle source')
		self.IdleSource=source;wake()
	end
	function loop:CancelTask(id: number?)
		if id and self.Tasks[id]then self.Tasks[id]=nil;self.TaskCount-=1;wake()end
	end
	function loop:WithContinuation(state: any,fn: any)
		local previous=self.ContinuationState;self.ContinuationState=state
		local result=table.pack(pcall(fn));self.ContinuationState=if self.Alive then previous else nil
		if not result[1]then error(result[2],0)end;return table.unpack(result,2,result.n)
	end
	function loop:QueueMicrotask(fn: any,ignoreContinuation: boolean?)
		check();assert(callable(fn),"Microtask requires a function")
		assert(#self.Microtasks-head+1<1024,"JavaScript microtask queue budget exceeded")
		if not ignoreContinuation then microtaskContexts[#self.Microtasks+1]=self.ContinuationState end
		table.insert(self.Microtasks,fn);wake()
	end
	local function delay(value,level)
		local ms=math.max(0,integer(value,true))
		if level>5 then ms=math.max(4,ms) end
		return ms/1000
	end
	local function timer(args,repeatTimer)
		check();assert(args[1]~=nil,"Timer requires a handler")
		assert(loop.TimerCount<1024,"JavaScript timer budget exceeded")
		local fn=args[1]
		if not callable(fn) then fn=VM.string(fn);assert(#fn<=65536,"JavaScript timer source budget exceeded") end
		local arguments={};for i=3,#args do table.insert(arguments,args[i]) end
		local level=loop.TimerLevel;local wait=delay(args[2] or VM.Undefined,level)
		nextTimer+=1;sequence+=1
		loop.Timers[nextTimer]={ID=nextTimer,Handler=fn,Args=arguments,DelayValue=args[2] or VM.Undefined,
			Due=now()+wait,Sequence=sequence,Repeat=repeatTimer,Nesting=level+1}
		loop.TimerCount+=1;wake();return nextTimer
	end
	local function clear(args)
		check();local id=integer(args[1],true)
		if loop.Timers[id] then loop.Timers[id]=nil;loop.TimerCount-=1;wake() end
		return VM.Undefined
	end
	local methods={}
	methods.setTimeout=function(args)return timer(args,false)end
	methods.setInterval=function(args)return timer(args,true)end
	methods.clearTimeout=clear;methods.clearInterval=clear
	methods.queueMicrotask=function(args)
		check();assert(callable(args[1]),"queueMicrotask requires a function")
		loop:QueueMicrotask(args[1]);return VM.Undefined
	end
	methods.requestAnimationFrame=function(args)
		check();assert(callable(args[1]),"requestAnimationFrame requires a function")
		assert(loop.FrameCount<512,"JavaScript animation frame budget exceeded")
		nextFrame+=1;loop.Frames[nextFrame]=args[1];loop.FrameCount+=1;wake();return nextFrame
	end
	methods.cancelAnimationFrame=function(args)
		check();local id=integer(args[1],false)
		if loop.Frames[id] then loop.Frames[id]=nil;loop.FrameCount-=1;wake() end
		return VM.Undefined
	end
	loop.Methods=methods
	function loop:Checkpoint()
		if not self.Alive or self.Draining then return end
		self.Draining=true
		local count,steps=0,0
		while self.Alive and head<=#self.Microtasks do
			if count>=512 or steps>=(options.MaxSteps or 30000) then
				table.clear(self.Microtasks);table.clear(microtaskContexts);head=1;report("JavaScript microtask checkpoint budget exceeded");break
			end
			local fn,state=self.Microtasks[head],microtaskContexts[head];self.Microtasks[head]=false;microtaskContexts[head]=nil;head+=1;count+=1
			if state~=nil or self.ContinuationState~=nil then
				steps+=self:WithContinuation(state,function()return options.Invoke(fn,{},'microtask')or 0 end)
			else steps+=options.Invoke(fn,{},'microtask')or 0 end
		end
		table.clear(self.Microtasks);table.clear(microtaskContexts);head=1;self.Draining=false
		if self.Alive and options.AfterCheckpoint then options.AfterCheckpoint() end
	end
	function loop:NextTaskDue(): number?
		local due=nil
		for _,record in self.Tasks do due=if due then math.min(due,record.Due)else record.Due end
		for _,record in self.Timers do due=if due then math.min(due,record.Due) else record.Due end
		return due
	end
	function loop:NextDue(): number?
		local due=self:NextTaskDue()
		local idleDue=if self.IdleSource then self.IdleSource:NextDue()else nil
		if not self.Alive then return nil end
		return if idleDue then(if due then math.min(due,idleDue)else idleDue)else due
	end
	function loop:PumpTasks(): number
		if not self.Alive or self.Pumping then return 0 end
		self.Pumping=true
		local count,steps=0,0
		while self.Alive and count<32 and steps<(options.MaxSteps or 30000) do
			local time=now();local record=nil
			for _,candidate in self.Timers do
				if candidate.Due<=time and (not record or candidate.Due<record.Due or (candidate.Due==record.Due and candidate.Sequence<record.Sequence)) then record=candidate end
			end
			for _,candidate in self.Tasks do
				if candidate.Due<=time and(not record or candidate.Due<record.Due or(candidate.Due==record.Due and candidate.Sequence<record.Sequence))then record=candidate end
			end
			if not record then break end
			-- Keep repeat handles active during invocation, so clearInterval (also
			-- from a microtask) can prevent rescheduling of this exact record.
			if record.Task then self.Tasks[record.Sequence]=nil;self.TaskCount-=1
			elseif not record.Repeat then self.Timers[record.ID]=nil;self.TimerCount-=1 end
			local previous=self.TimerLevel;self.TimerLevel=record.Nesting
			if record.Task then self.TimerLevel=0 end
			steps+=options.Invoke(record.Handler,record.Args,if record.Task then "task"else "timer") or 0
			self.TimerLevel=previous;count+=1
			if self.Alive and record.Repeat and self.Timers[record.ID]==record then
				sequence+=1;record.Sequence=sequence
				record.Due=now()+delay(record.DelayValue,record.Nesting);record.Nesting+=1
			end
		end
		-- Cooperative idle work is considered only after runnable ordinary
		-- tasks and their checkpoints. Its positive timeouts are ordinary
		-- delayed tasks, so continuous runnable work cannot hide an expiry.
		if self.Alive and count<32 and steps<(options.MaxSteps or 30000)and self.IdleSource then
			count+=self.IdleSource:Pump()
		end
		self.Pumping=false;wake();return count
	end
	function loop:PumpFrame(): number
		if not self.Alive or self.Pumping then return 0 end
		self.Pumping=true
		local ids={};for id in self.Frames do table.insert(ids,id) end;table.sort(ids)
		local timestamp=self:Timestamp();local count,steps=0,0
		for _,id in ids do
			if not self.Alive then break end
			local fn=self.Frames[id];if not fn then continue end
			self.Frames[id]=nil;self.FrameCount-=1
			if steps>=(options.MaxFrameSteps or 100000) then
				report("JavaScript animation frame instruction budget exceeded");continue
			end
			steps+=options.Invoke(fn,{timestamp},"frame") or 0;count+=1
		end
		self.Pumping=false;wake();return count
	end
	function loop:Destroy()
		if not self.Alive then return end;self.Alive=false
		table.clear(self.Timers);table.clear(self.Tasks);table.clear(self.Frames);table.clear(self.Microtasks);table.clear(methods)
		self.TimerCount,self.TaskCount,self.FrameCount=0,0,0;table.clear(options)
		self.IdleSource=nil
		self.ContinuationState=nil
		table.clear(microtaskContexts)
	end
	return loop
end
return EventLoop
