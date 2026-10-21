--!strict
return function(Parser,Runtime,VM,fixtures)
	local failures={}
	for _,fixture in fixtures do
		local values,diagnostics={},{};local time=0
		local runtime=Runtime.new(Parser.parseDocument('<html><body></body></html>'),{Clock=function()return time end,
			Console=function(_,value)table.insert(values,value)end,Diagnostic=function(message)table.insert(diagnostics,message)end})
		runtime:Run('function record(value){console.log(String(value));}\n'..(if fixture.async then '(async()=>{ '..fixture.source..' })();'else fixture.source))
		for _=1,8 do runtime:PumpTasks();time+=.05 end
		if #diagnostics>0 or #values~=#fixture.expected then table.insert(failures,fixture.name..': '..table.concat(diagnostics,' / ')..' actual='..table.concat(values,' | '))
		else for i,value in values do if value~=fixture.expected[i]then table.insert(failures,fixture.name..' ['..i..']: '..value..' ~= '..fixture.expected[i])end end end
		runtime:Destroy()
	end
	for _,message in failures do print('Performance mismatch: '..message)end
	assert(#failures==0,'Performance fixture failures: '..#failures)
	-- Idle observers require no repeating timer or frame callback, and a closed
	-- document must not deliver a queued performance callback.
	local count=0;local runtime=Runtime.new(Parser.parseDocument('<html><body></body></html>'),{Console=function()count+=1 end})
	assert(runtime:Run("const p=new PerformanceObserver(()=>console.log('delivery'));p.observe({type:'mark'});performance.mark('pending')"))
	assert(runtime.EventLoop.TaskCount==1 and runtime.EventLoop.TimerCount==0 and runtime.EventLoop.FrameCount==0)
	runtime:Destroy();assert(count==0 and not runtime.Performance.Alive)
	-- Timeline and pending observer queues share one retained-record quota.
	-- Clearing the timeline alone cannot discard undelivered observer entries;
	-- draining them frees that quota without disconnecting a live observer.
	local diagnostics,values={},{}
	local bounded=Runtime.new(Parser.parseDocument('<html><body></body></html>'),{MaxSteps=1000000,
		Console=function(_,value)table.insert(values,value)end,Diagnostic=function(message)table.insert(diagnostics,message)end})
	bounded:Run([[const p=new PerformanceObserver(()=>{});p.observe({type:'mark'});
		let count=0;try{for(let i=0;i<3000;i++){performance.mark('bounded',{startTime:i});count++}}catch(e){console.log(e.name)}
		console.log(count);performance.clearMarks();try{performance.mark('blocked')}catch(e){console.log(e.name)}
		console.log(p.takeRecords().length);performance.mark('freed');console.log(p.takeRecords()[0].name);p.disconnect();performance.clearMarks();]])
	assert(#diagnostics==0,table.concat(diagnostics,' / '))
	assert(table.concat(values,'|')=='QuotaExceededError|2048|QuotaExceededError|2048|freed','Shared performance quota must release drained and cleared entries')
	bounded:Destroy()
	-- Failed clone and invalid timestamps do not publish partial records.
	local clean=Runtime.new(Parser.parseDocument('<html><body></body></html>'),{Diagnostic=error})
	assert(clean:Run([[const o=new PerformanceObserver(()=>{});o.observe({type:'mark'});
		try{performance.mark('invalid',{detail:()=>1})}catch(e){}
		try{performance.mark('invalid',{startTime:-1})}catch(e){}
		if(performance.getEntriesByType('mark').length!==0||o.takeRecords().length!==0)throw new Error('Failed marks leaked');
		o.disconnect();]]))
	clean:Destroy()
	local recovered={};local recovery=Runtime.new(Parser.parseDocument('<html><body></body></html>'),{
		Console=function(_,value)table.insert(recovered,value)end,Diagnostic=error})
	for _=1,1024 do recovery.EventLoop:QueueTask(function()end)end
	assert(recovery:Run([[performance.mark('buffered-source',{startTime:1});
		const observer=new PerformanceObserver(list=>console.log(list.getEntries().map(e=>e.name).join(',')));
		observer.observe({type:'mark'});try{performance.mark('pending')}catch(e){console.log(e.name)}
		if(performance.getEntriesByName('pending').length!==0||observer.takeRecords().length!==0)throw new Error('Failed queueing published a mark');
		const bufferedObserver=new PerformanceObserver(()=>{});
		try{bufferedObserver.observe({type:'mark',buffered:true})}catch(e){console.log(e.name)}
		if(bufferedObserver.takeRecords().length!==0)throw new Error('Failed buffered observe retained records');
		bufferedObserver.observe({entryTypes:['measure']});]]))
	recovery:PumpTasks();assert(recovery:Run("performance.clearMarks('buffered-source');performance.mark('retry')"))
	for _=1,40 do recovery:PumpTasks()end
	assert(table.concat(recovered,'|')=='QuotaExceededError|QuotaExceededError|retry','A full task queue must not publish partial records or permanently block observer delivery')
	assert(recovery.EventLoop.TaskCount==0);recovery:Destroy()
	print('JavaScript Performance: '..#fixtures..' authored fixtures, task batching, shared quotas and disposal passed')
end
