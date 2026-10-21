--!strict
return function(Parser,Runtime,VM,Events,fixtures)
	local failures={}
	for _,fixture in fixtures do
		local values,diagnostics={},{}
		local document=Parser.parseDocument('<html><head></head><body></body></html>')
		local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,URL='https://example.test/components',MaxSteps=200000,
			ControlAdapter={},
			Console=function(_,value)table.insert(values,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
		runtime:Run('function record(value){console.log(String(value));}\n'..fixture.source)
		while runtime.EventLoop.TaskCount>0 do runtime:PumpTasks()end
		if #diagnostics>0 or #values~=#fixture.expected then table.insert(failures,fixture.name..': '..table.concat(diagnostics,' / ')..' actual='..table.concat(values,' ; '))
		else for i,value in values do if value~=fixture.expected[i]then table.insert(failures,fixture.name..' ['..i..']: '..value..' ~= '..fixture.expected[i])end end end
		runtime:Destroy();events:Destroy()
	end
	for _,message in failures do print('Component mismatch: '..message)end
	assert(#failures==0,'Shadow DOM / custom element fixture failures: '..#failures)
	print('JavaScript components: '..#fixtures..' ownership/slots/events/custom-element fixtures passed')
end
