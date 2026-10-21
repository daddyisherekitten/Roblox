--!strict
return function(Parser,Runtime,Events,currentHTML,currentJavaScript)
	local function make(budget)
		local state={Time=0,Budget=budget};local events=Events.new(error)
		local realm=Runtime.new(Parser.parseDocument('<!doctype html><p>Idle task scheduling</p>'),{
			Events=events,URL='https://idle.test/',Clock=function()return state.Time end,
			Schedule=function()end,ApplyChanges=function()return false end,
			IdleBudget=if budget~=nil then function()return state.Budget end else nil})
		realm.VM:Install(function()
			realm.VM.GlobalEnvironment:Define('consume',realm.VM.Object({value=function(args)state.Time+=realm.VM.Model.number(args[1])/1000 end,writable=true,configurable=true}),true)
		end)
		local function run(source)
			local ok,message=realm:Run(source);assert(ok,tostring(message));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
		end
		local function get(name)return realm.Window.Get(name)end
		local function trace()run("var observedTrace=trace.join('|');");return get('observedTrace')end
		local function destroy()realm:Destroy();events:Destroy()end
		return realm,state,run,get,trace,destroy
	end
	local realm,clock,run,get,trace,destroy=make(nil)
	run([=[
		var trace=[],savedDeadline,initialRemaining,usedRemaining,urgentRemaining,receiverCorrect;
		var handle=requestIdleCallback(function(deadline){
			'use strict';receiverCorrect=this===undefined;savedDeadline=deadline;trace.push('idle');
			initialRemaining=deadline.timeRemaining();consume(.4);usedRemaining=deadline.timeRemaining();
			queueMicrotask(()=>trace.push('microtask'));
			setTimeout(()=>trace.push('timer-after'),0);urgentRemaining=deadline.timeRemaining();
		});
		setTimeout(()=>trace.push('timer-before'),0);
		var names=[requestIdleCallback.name,requestIdleCallback.length,cancelIdleCallback.name,cancelIdleCallback.length,IdleDeadline.name,IdleDeadline.length].join(',');
	]=])
	assert(realm.IdleCallbacks.Count==1 and trace()==''and realm.EventLoop:NextDue()==0)
	assert(realm:PumpTasks()==2 and trace()=='timer-before|idle|microtask')
	assert(get('receiverCorrect')and get('initialRemaining')>0 and get('initialRemaining')<=1.000001)
	assert(math.abs(get('initialRemaining')-get('usedRemaining')-.4)<.000001 and get('urgentRemaining')==0)
	realm:PumpTasks();assert(trace()=='timer-before|idle|microtask|timer-after'and realm.IdleCallbacks.Count==0 and realm.EventLoop:NextDue()==nil)
	run([=[
		if(!(savedDeadline instanceof IdleDeadline)||savedDeadline.didTimeout)throw new Error('Deadline interface');
		if(Object.prototype.toString.call(savedDeadline)!=='[object IdleDeadline]')throw new Error('Deadline tag');
		const descriptor=Object.getOwnPropertyDescriptor(IdleDeadline.prototype,'didTimeout');
		if(typeof descriptor.get!=='function'||descriptor.set!==undefined||!descriptor.enumerable||!descriptor.configurable)throw new Error('Readonly deadline descriptor');
		var errors=0;try{new IdleDeadline();}catch(e){if(e.name==='TypeError')errors++;}
		try{IdleDeadline.prototype.timeRemaining.call({});}catch(e){if(e.name==='TypeError')errors++;}
		try{descriptor.get.call({});}catch(e){if(e.name==='TypeError')errors++;}
		try{(()=>{'use strict';savedDeadline.didTimeout=true;})();}catch(e){if(e.name==='TypeError')errors++;}
	]=])
	assert(get('errors')==4 and get('names')=='requestIdleCallback,1,cancelIdleCallback,1,IdleDeadline,0')
	clock.Time+=1;run('var expired=savedDeadline.timeRemaining();');assert(get('expired')==0)
	destroy()
	-- Window receiver validation precedes options getters/number conversion;
	-- only the defining Window or null/undefined global normalization is valid.
	realm,clock,run,get,trace,destroy=make(0)
	run([=[
		var receiverErrors=0,optionReads=0,numberConversions=0,callbacksRun=0;
		var idleOptions={get timeout(){optionReads++;return 10;}};
		var idleHandle={valueOf(){numberConversions++;return 0;}};
		for(const receiver of [{},[],document,Window.prototype,Object.create(window),0,false,'text',Symbol(),1n]){
			try{requestIdleCallback.call(receiver,()=>callbacksRun++,idleOptions);}catch(e){if(e.name==='TypeError')receiverErrors++;}
			try{cancelIdleCallback.call(receiver,idleHandle);}catch(e){if(e.name==='TypeError')receiverErrors++;}
		}
		var readBeforeValid=optionReads,convertedBeforeValid=numberConversions;
		for(const receiver of [window,self,globalThis,null,undefined]){
			let id=requestIdleCallback.apply(receiver,[()=>callbacksRun++,idleOptions]);
			cancelIdleCallback.bind(receiver)({valueOf(){numberConversions++;return id;}});
		}
		function strictIdle(){'use strict';const request=requestIdleCallback,cancel=cancelIdleCallback;const id=request(()=>callbacksRun++);cancel(id);return typeof id==='number';}
		var strictValid=strictIdle();
	]=])
	assert(get('receiverErrors')==20 and get('readBeforeValid')==0 and get('convertedBeforeValid')==0)
	assert(get('optionReads')==5 and get('numberConversions')==5 and get('strictValid')and get('callbacksRun')==0)
	assert(realm.IdleCallbacks.Count==0 and realm.EventLoop.TaskCount==0 and realm.EventLoop:NextDue()==nil)
	destroy()

	-- Registration order is preserved; recursion and callbacks remaining from
	-- an earlier slice only run in a later cooperative period.
	realm,clock,run,get,trace,destroy=make(8)
	run([=[
		var trace=[];
		requestIdleCallback(()=>{trace.push('first');cancelIdleCallback(victim);requestIdleCallback(()=>trace.push('recursive'));});
		var removed=requestIdleCallback(()=>trace.push('removed'));
		requestIdleCallback(()=>{trace.push('third');cancelIdleCallback(removed);});
		var victim=requestIdleCallback(()=>trace.push('victim'));
		cancelIdleCallback(removed);cancelIdleCallback(removed);cancelIdleCallback(0);cancelIdleCallback(-1);
	]=])
	assert(realm:PumpTasks()==1 and trace()=='first')
	assert(realm:PumpTasks()==0 and math.abs(realm.EventLoop:NextDue()-.008)<.000001)
	clock.Time=.008;assert(realm:PumpTasks()==1 and trace()=='first|third')
	clock.Time=.016;assert(realm:PumpTasks()==1 and trace()=='first|third|recursive'and realm.EventLoop:NextDue()==nil)
	destroy()

	-- Positive timeout tasks still run when the host exposes no idle budget.
	-- They race the idle request once and expose a zero remaining deadline.
	realm,clock,run,get,trace,destroy=make(0)
	run([=[
		var trace=[],deadline;
		requestIdleCallback(value=>{deadline=value;trace.push('slow:'+value.didTimeout+':'+value.timeRemaining());},{timeout:50});
		requestIdleCallback(value=>trace.push('fast:'+value.didTimeout),{timeout:5});
		var canceled=requestIdleCallback(()=>trace.push('canceled'),{timeout:2});cancelIdleCallback(canceled);
		requestIdleCallback(value=>trace.push('zero:'+value.didTimeout),{timeout:0});
	]=])
	assert(realm.IdleCallbacks.Count==3 and realm.EventLoop.TaskCount==2 and realm.EventLoop:NextDue()==.005)
	clock.Time=.006;realm:PumpTasks();assert(trace()=='fast:true')
	clock.Time=.06;realm:PumpTasks();assert(trace()=='fast:true|slow:true:0'and realm.EventLoop:NextDue()==nil and realm.IdleCallbacks.Count==1)
	clock.Budget=5;realm.IdleCallbacks:Wake();realm:PumpTasks();assert(trace()=='fast:true|slow:true:0|zero:false')
	destroy()

	-- A continuous chain of ready ordinary tasks cannot hide an expired
	-- idle timeout behind the cooperative idle eligibility check.
	realm,clock,run,get,trace,destroy=make(0)
	run("var trace=[];requestIdleCallback(d=>trace.push('timeout:'+d.didTimeout),{timeout:5});")
	local busy=0;local again
	again=function()busy+=1;clock.Time+=.001;if busy<100 then realm.EventLoop:QueueTask(again)end end
	realm.EventLoop:QueueTask(again)
	for _=1,10 do realm:PumpTasks()end
	assert(trace()=='timeout:true'and busy==100 and realm.IdleCallbacks.Count==0)
	destroy()

	-- Web IDL callback/dictionary/unsigned timeout conversion, including
	-- getter ordering, positive fractional truncation and reentrant cancel.
	realm,clock,run,get,trace,destroy=make(0)
	run([=[
		var trace=[],errors=0;
		for(const value of [undefined,null,0,'source',{}]){try{requestIdleCallback(value);}catch(e){if(e.name==='TypeError')errors++;}}
		try{requestIdleCallback(()=>{},5);}catch(e){if(e.name==='TypeError')errors++;}
		try{requestIdleCallback(()=>{},{timeout:Symbol()});}catch(e){if(e.name==='TypeError')errors++;}
		try{requestIdleCallback(()=>{},{timeout:1n});}catch(e){if(e.name==='TypeError')errors++;}
		try{cancelIdleCallback();}catch(e){if(e.name==='TypeError')errors++;}
		var old=requestIdleCallback(()=>trace.push('old'));
		requestIdleCallback(d=>trace.push('converted:'+d.didTimeout),{get timeout(){trace.push('get');return{valueOf(){trace.push('valueOf');cancelIdleCallback(old);return 3.9;}};}});
		var unbounded=requestIdleCallback(()=>trace.push('unbounded'),{timeout:-1});
		cancelIdleCallback(unbounded+4294967296);
		requestIdleCallback(()=>trace.push('null-options'),null);
	]=])
	assert(get('errors')==9 and trace()=='get|valueOf'and realm.IdleCallbacks.Count==2 and math.abs(realm.EventLoop:NextDue()-.003)<.000001)
	clock.Time=.004;realm:PumpTasks();assert(trace()=='get|valueOf|converted:true'and realm.IdleCallbacks.Count==1)
	destroy();assert(realm.EventLoop:NextDue()==nil and realm.IdleCallbacks.Count==0)

	-- The hint never exceeds 50 ms or the next known task, and a hidden page
	-- defers ordinary idle work without polling while timeout work remains.
	realm,clock,run,get,trace,destroy=make(500)
	run("var trace=[],remaining;setTimeout(()=>trace.push('future'),12);requestIdleCallback(d=>{remaining=d.timeRemaining();trace.push('idle');});")
	realm:PumpTasks();assert(get('remaining')<=12.00001 and get('remaining')>11.9)
	run("requestIdleCallback(d=>trace.push('hidden:'+d.didTimeout),{timeout:20});")
	realm:SetVisible(false);realm:PumpTasks();assert(realm.IdleCallbacks.Count==1)
	clock.Time=.025;realm:PumpTasks();assert(trace()=='idle|future|hidden:true'and realm.EventLoop:NextDue()==nil)
	realm:SetVisible(true);realm:PumpTasks();run("requestIdleCallback(d=>{remaining=d.timeRemaining();trace.push('clamped');});")
	realm:PumpTasks();assert(get('remaining')<=50.00001)
	run("requestIdleCallback(()=>trace.push('stale'),{timeout:5});")
	assert(realm.IdleCallbacks.Count==1 and realm.EventLoop.TaskCount==1)
	destroy();clock.Time+=1;assert(realm:PumpTasks()==0 and realm.IdleCallbacks.Count==0 and realm.EventLoop.TaskCount==0 and realm.EventLoop:NextDue()==nil)

	-- Winning an idle race removes its timeout immediately; a throwing
	-- callback is reported without poisoning later idle periods.
	realm,clock,run,get,trace,destroy=make(5)
	run("var trace=[],won=0,recovered=false;requestIdleCallback(d=>{won++;if(d.didTimeout)throw new Error('Wrong race winner');},{timeout:20});")
	assert(realm.EventLoop.TaskCount==1);realm:PumpTasks()
	assert(get('won')==1 and realm.EventLoop.TaskCount==0 and realm.EventLoop:NextDue()==nil)
	clock.Time=.1;realm:PumpTasks();assert(get('won')==1)
	run("requestIdleCallback(()=>{throw new Error('Expected idle error');});requestIdleCallback(()=>{recovered=true;});")
	realm:PumpTasks();assert(#realm.Diagnostics==1 and realm.IdleCallbacks.Count==1)
	clock.Time+=.006;realm:PumpTasks();assert(get('recovered')==true and realm.IdleCallbacks.Count==0 and realm.EventLoop:NextDue()==nil)
	destroy()

	-- An injected host budget may synchronously dispose its requesting realm.
	-- Neither the idle request nor an already registered future timer survives.
	for _,boundary in {'due','pump'}do
		local reentrantEvents=Events.new(error);local disposed=false;local calls=0;local current
		current=Runtime.new(Parser.parseDocument('<p>Reentrant idle budget</p>'),{Events=reentrantEvents,
			Schedule=function()end,Clock=function()return 0 end,Console=function()calls+=1 end,
			IdleBudget=function()if not disposed then disposed=true;current:Destroy()end;return 5 end})
		assert(current:Run('requestIdleCallback(()=>console.log("stale idle"),{timeout:1000});setTimeout(()=>console.log("stale timer"),5000);'))
		if boundary=='due'then assert(current.EventLoop:NextDue()==nil)else current:PumpTasks()end
		assert(disposed and not current.Alive and calls==0 and current.IdleCallbacks.Count==0 and current.EventLoop.TaskCount==0 and current.EventLoop:NextDue()==nil,'Host budget disposal must invalidate idle and future timer scheduling')
		reentrantEvents:Destroy()
	end

	-- Execute the currently published comparison page, including its real
	-- deferred external script. The visible cancellation probe registers and
	-- cancels in one click, so a fast native idle period cannot hide the case.
	assert(type(currentHTML)=='string'and type(currentJavaScript)=='string','Idle comparison source fixture is required')
	local function comparison(supported,budget)
		local time=0;local events=Events.new(error)
		local document=Parser.parseDocument(currentHTML)
		local nodes=0;local pending={document};local byID={}
		while #pending>0 do
			local node=table.remove(pending);nodes+=1
			if node.Attributes and node.Attributes.id then byID[node.Attributes.id]=node end
			for _,child in node.Children do table.insert(pending,child)end
		end
		assert(nodes<250,'The idle probe must keep the comparison page small')
		local realm=Runtime.new(document,{URL='https://idle.test/comparison-script/index.html',Events=events,
			Clock=function()return time end,Schedule=function()end,ApplyChanges=function()return false end,
			IdleBudget=if budget~=nil then function()return budget end else nil,
			ScriptSources={['https://idle.test/comparison-script/app.js']=currentJavaScript}})
		if not supported then assert(realm:Run('window.requestIdleCallback=undefined;window.cancelIdleCallback=undefined;'))end
		realm:Start()
		for _=1,10 do realm:PumpTasks();realm.EventLoop:Checkpoint()end
		assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
		assert(realm.IdleCallbacks.Count==0,'The comparison must not schedule idle work during loading')
		local function text(id)
			assert(realm:Run('window.comparisonValue=document.getElementById("'..id..'").textContent;'))
			return realm.Window.Get('comparisonValue')
		end
		local function click(id)events:Emit(assert(byID[id]),'click',{isTrusted=true});assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
		local function pump(advance)time+=advance or 0;realm:PumpTasks();realm.EventLoop:Checkpoint()end
		return realm,click,text,pump,function()realm:Destroy();events:Destroy()end
	end
	local page,click,text,pump,close=comparison(true,nil)
	assert(text('idle-status')=='Bereit. Noch kein Idle-Test geplant.')
	click('idle-start');assert(page.IdleCallbacks.Count==1 and text('idle-status'):find('Geplant.',1,true))
	pump();local result=text('idle-status')
	assert(page.IdleCallbacks.Count==0 and result:find('Ausgeführt. didTimeout: false; timeRemaining(): ',1,true)and result:find(' ms.',1,true),'Published source must display the actual idle deadline result')
	click('idle-start');click('idle-cancel');local canceled=text('idle-status')
	assert(page.IdleCallbacks.Count==0 and canceled=='Abgebrochen. Der geplante Callback wird nicht ausgeführt.')
	pump(2);assert(text('idle-status')==canceled,'The canceled published callback must never overwrite its status')
	click('idle-cancel-now');local immediate=text('idle-status')
	assert(page.IdleCallbacks.Count==0 and immediate=='Direkt im selben Klick abgebrochen. Es wird kein Callback ausgeführt.')
	pump(2);assert(text('idle-status')==immediate,'Same-handler cancellation remains visible after its timeout')
	click('idle-cancel');assert(text('idle-status'):find('Kein ausstehender Callback.',1,true))
	close()
	page,click,text,pump,close=comparison(true,0)
	click('idle-start');pump(1.01)
	assert(text('idle-status')=='Ausgeführt. didTimeout: true; timeRemaining(): 0.00 ms.','Published timeout result must report the real timeout winner')
	close()
	page,click,text,pump,close=comparison(false,nil)
	assert(text('idle-status')=='Dieser Browser stellt requestIdleCallback und cancelIdleCallback nicht bereit.')
	assert(page:Run('window.disabledIdleControls=["idle-start","idle-cancel","idle-cancel-now"].every(id=>document.getElementById(id).disabled);'))
	assert(page.Window.Get('disabledIdleControls')==true,'Unsupported browser controls must explain and expose their disabled state')
	close()
	print('JavaScriptIdleCallbacks: cooperative deadline hints, idle/timeout races, task priority, cancellation, next periods, Web IDL conversions, hidden state and disposal passed')
end
