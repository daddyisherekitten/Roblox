--!strict
--!optimize 2
-- Cooperative CPU budget for HTML build/layout, Canvas rasterization and its script VM.
local WorkBudget={}

function WorkBudget.new(milliseconds: number,taskAPI: any?,clock: (() -> number)?): any?
	if milliseconds<=0 then return nil end
	local waitTask=taskAPI or task;local now=clock or os.clock;local interval=milliseconds/1000;local started=now()
	local self={Yields=0,WaitMS=0,ActiveMS=0,MaxSliceMS=0,Checks=0,Deadline=started+interval,Last=started}
	function self:Reset()local current=now();self.Last=current;self.Deadline=current+interval end
	function self:Checkpoint(force: boolean?)
		self.Checks+=1;local current=now();if not force and current<self.Deadline then return end
		local slice=math.max(0,(current-self.Last)*1000);self.MaxSliceMS=math.max(self.MaxSliceMS,slice)
		self.ActiveMS+=slice;local before=current;waitTask.wait();local after=now();self.WaitMS+=(after-before)*1000;self.Yields+=1;self.Last=after;self.Deadline=after+interval
	end
	function self:Finish()local current=now();local slice=math.max(0,(current-self.Last)*1000);self.ActiveMS+=slice;self.MaxSliceMS=math.max(self.MaxSliceMS,slice);self.Last=current;self.Deadline=current+interval end
	return self
end

return WorkBudget
