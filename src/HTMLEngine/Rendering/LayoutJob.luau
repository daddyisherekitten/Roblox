--!strict
-- A serialized layout pass yields cooperatively without publishing stale geometry.
local WorkBudget = require(script.Parent.WorkBudget)
local WorkContext=require(script.Parent.Parent.WorkContext)
local LayoutJob = {}

function LayoutJob.run(page: any, tree: any, milliseconds: number, current: () -> boolean,
	operation: any, taskAPI: any?, clock: (() -> number)?): (boolean, any, boolean, any)
	assert(not tree.LayoutInProgress, "Overlapping page layouts")
	local cancelled = {}
	local loading=page.LoadingWork and page.LoadingWork.Active
	local budget = if loading then nil else WorkBudget.new(milliseconds, taskAPI, clock)
	local active = true
	local function check(stylePass: boolean?): boolean
		-- Repaint callbacks retain this function after layout. They must keep
		-- ordinary page-lifetime checks, without an expired pass or its budget.
		if not active then return page.Alive end
		if not page.Alive or (not stylePass and not current()) then error(cancelled, 0) end
		WorkContext.checkpoint()
		if budget and not loading then budget:Checkpoint() end
		if not page.Alive or (not stylePass and not current()) then error(cancelled, 0) end
		return true
	end
	-- Finish a CSS recascade against one viewport before switching to a newer one.
	-- This keeps inherited styles coherent even if resize arrives during a yield.
	local function styleCheck(): boolean return check(true) end
	tree.LayoutInProgress = true
	local ok, result = pcall(WorkContext.runFor,page,function()
		if loading then budget=WorkContext.budget()end
		return operation(check,styleCheck)
	end)
	if ok and (not page.Alive or not current()) then ok, result = false, cancelled end
	if budget and not loading then budget:Finish() end
	active = false
	tree.LayoutInProgress = false
	return ok, result, result == cancelled, budget
end

return LayoutJob
