--!strict
return function(Parser,Runtime,Events,WorkerRealm,reference)
	local time=0;local events=Events.new(error)
	local realm=Runtime.new(Parser.parseDocument('<!doctype html><p>Priority scheduler</p>'),{URL='https://scheduler.test/',Events=events,Clock=function()return time end,Schedule=function()end})
	local function run(source)local ok,message=realm:Run(source);assert(ok,tostring(message));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
	local function read(name)return realm.Window.Get(name)end
	local function trace()run("var observed=log.join('|')");return read('observed')end
	run([=[
		var log=[],controller=new TaskController({priority:'background'});
		if(!(controller instanceof AbortController)||!(controller.signal instanceof AbortSignal)||!(controller.signal instanceof TaskSignal))throw Error('Abort brands');
		if(!(scheduler instanceof Scheduler)||Object.prototype.toString.call(scheduler)!=='[object Scheduler]')throw Error('Scheduler interface');
		scheduler.postTask(()=>{log.push('dynamic');return 19},{signal:controller.signal}).then(value=>log.push('value:'+value));
		scheduler.postTask(()=>log.push('background'),{priority:'background'});
		scheduler.postTask(()=>log.push('visible'));
		scheduler.postTask(()=>log.push('blocking'),{priority:'user-blocking'});
		controller.setPriority('user-blocking');
	]=])
	assert(trace()=='');assert(realm.Scheduler.Count==4 and realm.EventLoop.TaskCount==1)
	realm:PumpTasks();assert(trace()=='dynamic|value:19|blocking|visible|background'and realm.Scheduler.Count==0 and realm.EventLoop:NextDue()==nil)
	run([=[
		log=[];
		scheduler.postTask(()=>log.push('delayed'),{delay:10});
		scheduler.postTask(()=>log.push('ready'));
	]=])
	realm:PumpTasks();assert(trace()=='ready'and realm.Scheduler.Count==1)
	time=.009;realm:PumpTasks();assert(trace()=='ready')
	time=.01;realm:PumpTasks();assert(trace()=='ready|delayed')
	run([=[
		log=[];var aborter=new AbortController();
		scheduler.postTask(()=>log.push('forbidden'),{signal:aborter.signal,delay:100}).catch(reason=>log.push('abort:'+reason));
		aborter.abort('reason');
		scheduler.postTask(()=>log.push('already-aborted'),{signal:aborter.signal}).catch(reason=>log.push('early:'+reason));
		scheduler.postTask(()=>{throw 27}).catch(value=>log.push('throw:'+value));
		scheduler.postTask(()=>Promise.resolve('thenable')).then(value=>log.push(value));
	]=])
	assert(trace()=='abort:reason|early:reason'and realm.Scheduler.Count==2)
	realm:PumpTasks();assert(trace()=='abort:reason|early:reason|throw:27|thenable')
	-- Every await and explicit then retains the posting task's priority and
	-- abort source. A timer started there begins a separate scheduling context.
	run([=[
		log=[];var yielding=new TaskController({priority:'background'});
		scheduler.postTask(async()=>{
			log.push('start');
			await Promise.resolve();
			await scheduler.yield();log.push('resume');
			await scheduler.yield();log.push('resume-again');
			setTimeout(()=>scheduler.yield().then(()=>log.push('timer-yield')),0);
		},{signal:yielding.signal});
		scheduler.postTask(()=>log.push('peer'),{priority:'background'});
	]=])
	realm:PumpTasks();assert(trace()=='start|resume|resume-again|peer|timer-yield',trace())
	run([=[
		log=[];var c=new TaskController({priority:'background'});
		scheduler.postTask(async()=>{log.push('begin');await new Promise(resolve=>{globalThis.release=resolve});await scheduler.yield();log.push('forbidden');},{signal:c.signal}).catch(e=>log.push('rejected:'+e));
	]=])
	realm:PumpTasks();assert(trace()=='begin')
	run("c.abort('after-await');release();");realm:PumpTasks();assert(trace()=='begin|rejected:after-await')
	run([=[
		log=[];var root=new TaskController({priority:'background'});
		var dependent=TaskSignal.any([],{priority:root.signal});
		var fixed=TaskSignal.any([],{priority:'user-blocking'});
		dependent.onprioritychange=event=>log.push('child:'+event.previousPriority+':'+event.target.priority);
		root.signal.addEventListener('prioritychange',event=>{
			log.push('root:'+event.previousPriority+':'+root.signal.priority);
			try{root.setPriority('background')}catch(e){log.push('nested:'+e.name)}
		});
		root.setPriority('user-visible');root.setPriority('user-visible');
		var change=new TaskPriorityChangeEvent('test',{previousPriority:'user-blocking',cancelable:true});
		if(!(change instanceof Event)||change.previousPriority!=='user-blocking'||!change.cancelable)throw Error('Priority event');
		var combined=TaskSignal.any([c.signal],{priority:fixed});
		if(!combined.aborted||combined.reason!=='after-await'||combined.priority!=='user-blocking')throw Error('Dependent abort');
	]=])
	assert(trace()=='root:background:user-visible|nested:NotAllowedError|child:background:user-visible',trace())
	-- Methods returning promises reject invalid Web IDL arguments; constructor
	-- and controller operations throw synchronously, before later conversions.
	run([=[
		log=[];var reads=[];
		scheduler.postTask(()=>{}, {get delay(){reads.push('delay');return 1},get priority(){reads.push('priority');return 'background'},get signal(){reads.push('signal');return undefined}});
		for(const options of [{delay:-1},{delay:Infinity},{delay:1n},{priority:'wrong'},{signal:null},4])scheduler.postTask(()=>{},options).catch(e=>log.push(e.name));
		scheduler.postTask().catch(e=>log.push(e.name));
		Scheduler.prototype.postTask.call({},()=>{}).catch(e=>log.push(e.name));
		Scheduler.prototype.yield.call({}).catch(e=>log.push(e.name));
		var thrown=0;for(const action of [()=>new Scheduler(),()=>new TaskSignal(),()=>new TaskController({priority:'wrong'}),()=>new TaskPriorityChangeEvent('x',{}),()=>TaskController.prototype.setPriority.call({},'background')])try{action()}catch(e){if(e.name==='TypeError')thrown++}
		var order=reads.join(',');
	]=])
	assert(read('thrown')==5 and read('order')=='delay,priority,signal'and trace()=='TypeError|TypeError|TypeError|TypeError|TypeError|TypeError|TypeError|TypeError|TypeError',trace())
	time+=.002;realm:PumpTasks()
	-- Captured intrinsics remain valid after changing public constructors and
	-- AbortController.prototype.signal. Priority signals retain genuine brands.
	run([=[
		var savedController=TaskController;
		Object.defineProperty(AbortController.prototype,'signal',{get(){throw Error('author getter')},configurable:true});
		globalThis.AbortController=null;globalThis.AbortSignal=null;
		var robust=new savedController();robust.setPriority('user-blocking');
		var robustPriority=robust.TaskPrioritySignal;
		if(robustPriority!==undefined)throw Error('Private host field escaped');
		scheduler.postTask(()=>{}, {delay:1000});
	]=])
	assert(realm.Scheduler.Count==1);realm:Destroy();events:Destroy()
	assert(realm.Scheduler.Count==0 and realm.EventLoop:NextDue()==nil and realm.EventLoop.TaskCount==0 and realm.EventLoop.ContinuationState==nil)
	-- Web IDL attribute-setter step 5.1 uses CreateDataPropertyOrThrow.
	-- Chrome155 silently ignores this failed replacement; this assertion is
	-- normative and deliberately separate from the captured native programs.
	do
		local input=Events.new(error)
		local actual=Runtime.new(Parser.parseDocument('<!doctype html><p>Replaceable accessor</p>'),{URL='https://scheduler.test/',Events=input,Schedule=function()end})
		local ok,message=actual:Run([=[
			var original=scheduler,d=Object.getOwnPropertyDescriptor(globalThis,'scheduler'),thrown='none';
			Object.defineProperty(globalThis,'scheduler',{configurable:false});
			try{d.set.call(globalThis,9)}catch(e){thrown=e.name}
			var protectedScheduler=thrown==='TypeError'&&scheduler===original&&d.get.call(globalThis)===original;
		]=]);assert(ok,tostring(message));assert(actual.Window.Get('protectedScheduler')==true,'Nonconfigurable replaceable accessor throws without replacing the original scheduler')
		assert(#actual.Diagnostics==0,table.concat(actual.Diagnostics,' | '));actual:Destroy();input:Destroy()
	end
	-- Worker uses the same host-free priority/task/promise implementation.
	local wire;local worker=WorkerRealm.new({url='https://scheduler.test/worker.js',source="var log=[];scheduler.postTask(()=>log.push('b'),{priority:'background'});scheduler.postTask(()=>log.push('a'),{priority:'user-blocking'});setTimeout(()=>postMessage(log.join('|')),0);"},{Clock=function()return 0 end,Message=function(value)wire=value end})
	worker:Start();worker:Pump();assert(wire~=nil);worker:Destroy()
	assert(#reference.records==12)
	for _,record in reference.records do
		local input=Events.new(error)
		local actual=Runtime.new(Parser.parseDocument('<!doctype html><p>Native scheduler reference</p>'),{URL='https://scheduler.test/',Events=input,Clock=function()return 0 end,Schedule=function()end})
		local ok,message=actual:Run(record.source);assert(ok,tostring(message))
		for _=1,100 do if actual.Window.Get('result')~=actual.VM.Model.Undefined then break end;actual:PumpTasks()end
		assert(actual.Window.Get('result')==record.result,record.name..': '..tostring(actual.Window.Get('result'))..' versus '..record.result)
		assert(#actual.Diagnostics==0,record.name..': '..table.concat(actual.Diagnostics,' | '))
		actual:Destroy();input:Destroy()
	end
	print('Scheduler: prioritized tasks, dynamic abort signals, delay, await/yield continuation inheritance, event/reentry/IDL/intrinsics, worker and disposal passed')
end
