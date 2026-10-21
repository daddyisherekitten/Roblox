--!strict
-- One timer wake and an on-demand render connection per HTML realm; idle is free.
local ScriptClock={}
local WorkContext=require(script.Parent.Parent.WorkContext)
function ScriptClock.start(page: any,tree: any,runtime: any,services: any?,afterFrame: any?): any
	services=services or {}
	local tasks=services.Task or task
	local run=services.RunService or game:GetService("RunService")
	local loop=runtime.EventLoop
	local self={Alive=true};local timer,frame,changed=nil,nil,nil
	local timerDue=nil;local busy=false;local revision=0
	local wake
	local function canRun()
		if not self.Alive or not page.Alive or not runtime.Alive or tree.LayoutInProgress or (runtime.IsExecuting and runtime:IsExecuting()) then return false end
		return not page.Root.GetAttribute or page.Root:GetAttribute("Status")=="ready"
	end
	local function stopTimer()
		revision+=1
		if timer then tasks.cancel(timer);timer=nil end;timerDue=nil
	end
	local function runTasks()
		if not self.Alive or busy then return end
		if not canRun() then wake();return end
		busy=true;local ok,message=pcall(WorkContext.runFor,page,function()runtime:PumpTasks()end);busy=false
		if not ok and self.Alive and page.Alive then error(message,0)end;wake()
	end
	wake=function()
		if not self.Alive or busy then return end
		if not runtime.Alive or not page.Alive then self:Destroy();return end
		-- Layout completion/initial readiness will wake us again. A suspended
		-- layout must not be modified by callbacks from another Roblox thread.
		if not canRun() then stopTimer();if frame then frame:Disconnect();frame=nil end;return end
		if loop.FrameCount>0 and not frame then
			frame=run.RenderStepped:Connect(function()
				if not canRun() or busy then return end
				busy=true;local ok,message=pcall(WorkContext.runFor,page,function()
					runtime:PumpFrame()
					if self.Alive and afterFrame then afterFrame(runtime) end
				end);busy=false
				if not ok and self.Alive and page.Alive then error(message,0)end;wake()
			end)
		elseif loop.FrameCount==0 and frame then frame:Disconnect();frame=nil end
		local due=loop:NextDue()
		if not self.Alive or not runtime.Alive or not page.Alive then return end
		if due==timerDue and timer then return end
		stopTimer()
		if due then
			timerDue=due;local ticket=revision
			timer=tasks.delay(math.max(0,due-loop:Now()),function()
				if not self.Alive or ticket~=revision then return end
				timer,timerDue=nil,nil;runTasks()
			end)
		end
	end
	function self:Wake()wake()end
	function self:Destroy()
		if not self.Alive then return end;self.Alive=false
		stopTimer();if frame then frame:Disconnect();frame=nil end
		if changed then changed:Disconnect();changed=nil end
		runtime.WakeTasks=nil
	end
	runtime.WakeTasks=wake
	-- The page signals readiness and each completed/cancelled layout via Status.
	if page.Root.GetAttributeChangedSignal then changed=page.Root:GetAttributeChangedSignal("Status"):Connect(wake) end
	page:AddCleanup(function()self:Destroy()end)
	wake();return self
end
return ScriptClock
