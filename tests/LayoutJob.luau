--!strict
return function(Job)
	local page, tree = {Alive=true}, {}
	local time, waits, revision = 0, 0, 1
	local afterYield
	local runtime = {wait=function()
		assert(tree.LayoutInProgress, "The layout lock covers every cooperative pause")
		waits += 1; time += .016
		if afterYield then local callback=afterYield; afterYield=nil; callback() end
	end}
	local retained
	local ok, result, cancelled, budget = Job.run(page,tree,4,function() return revision == 1 end,function(check)
		retained = check
		for _=1,20 do time += .001; assert(check()) end
		return 17
	end,runtime,function() return time end)
	assert(ok and result == 17 and not cancelled and waits > 0 and budget.Yields == waits and budget.WaitMS > 0)
	assert(not tree.LayoutInProgress)
	revision = 2
	assert(retained(), "Retained word repaint callbacks remain usable after this pass ends")
	local calls = 0
	afterYield = function() revision=3 end
	ok,result,cancelled = Job.run(page,tree,4,function() return revision == 2 end,function(check)
		for _=1,100 do time+=.001; check(); calls+=1 end
	end,runtime,function() return time end)
	assert(not ok and cancelled and calls < 100 and not tree.LayoutInProgress, "A superseded pass stops at its next checkpoint")
	revision = 4
	afterYield = function() revision=5 end
	local styleSteps = 0
	ok,result,cancelled = Job.run(page,tree,4,function() return revision == 4 end,function(check,styleCheck)
		for _=1,20 do time+=.001; styleCheck(); styleSteps+=1 end
		check()
	end,runtime,function() return time end)
	assert(not ok and cancelled and styleSteps == 20, "A CSS recascade completes coherently before the old layout is cancelled")
	ok,result,cancelled = Job.run(page,tree,0,function() return true end,function() error("real layout failure") end,runtime,function() return time end)
	assert(not ok and not cancelled and tostring(result):find("real layout failure") and not tree.LayoutInProgress)
	afterYield = function() page.Alive=false end
	ok,result,cancelled = Job.run(page,tree,4,function() return true end,function(check)
		for _=1,100 do time+=.001; check() end
	end,runtime,function() return time end)
	assert(not ok and cancelled and not tree.LayoutInProgress and not retained(), "Disposal unwinds the job and retained lifetime checks")
	print("Layout job: cooperative pauses, latest request, coherent CSS, retained callbacks, errors and disposal passed")
end
