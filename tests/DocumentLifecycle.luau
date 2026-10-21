--!strict
return function(Parser,Runtime,Events)
	local clock=0;local prompts={};local permit=false
	local events=Events.new(error)
	local document=Parser.parseDocument('<!doctype html><body><button id="activate">Activate</button></body>')
	local realm=Runtime.new(document,{URL='https://lifecycle.test/start',Events=events,Clock=function()return clock end,
		Schedule=function()end,ApplyChanges=function()return false end,
		ConfirmLeave=function(request)table.insert(prompts,request);return permit end})
	local function run(source)local ok,message=realm:Run(source);assert(ok,tostring(message));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,'\n'))end
	local function pump()for _=1,10 do clock+=.01;realm:PumpTasks();realm.EventLoop:Checkpoint()end end
	local function equals(expression,expected)
		run('globalThis.actualLifecycleResult=('..expression..');')
		assert(realm.Window.Get('actualLifecycleResult')==expected,tostring(realm.Window.Get('actualLifecycleResult'))..' versus '..tostring(expected))
	end
	run([=[
		globalThis.trace=[];
		if(document.hidden||document.visibilityState!=='visible')throw new Error('Initial visibility');
		const detached=document.implementation.createHTMLDocument('Detached');
		if(!detached.hidden||detached.visibilityState!=='hidden')throw new Error('A detached document has no visible browsing context');
		const hidden=Object.getOwnPropertyDescriptor(Document.prototype,'hidden');
		if(typeof hidden.get!=='function'||hidden.set!==undefined)throw new Error('Readonly Document visibility descriptor');
		let rejected=false;try{hidden.get.call({});}catch(e){rejected=e.name==='TypeError';}
		if(!rejected)throw new Error('Visibility getter branding');
		try{new BeforeUnloadEvent('beforeunload');throw new Error('Must reject BeforeUnloadEvent construction');}catch(e){if(e.name!=='TypeError')throw e;}
		const synthetic=new PageTransitionEvent('pageshow',{persisted:true});
		if(!synthetic.persisted||synthetic.isTrusted||synthetic.bubbles||!(synthetic instanceof Event))throw new Error('Page transition constructor');
		window.addEventListener('load',()=>trace.push('load'));
		window.addEventListener('pageshow',event=>{
			trace.push('pageshow:'+event.persisted+':'+(event.target===document)+':'+(event.currentTarget===window)+':'+event.isTrusted+':'+event.bubbles+':'+event.cancelable);
			event.preventDefault();
		});
		document.addEventListener('visibilitychange',event=>trace.push('visibility:'+document.visibilityState+':'+event.cancelable+':'+event.bubbles));
		window.addEventListener('pagehide',event=>trace.push('pagehide:'+event.persisted+':'+document.visibilityState+':'+(event.target===document)));
		window.addEventListener('unload',event=>trace.push('unload:'+document.visibilityState+':'+(event.target===document)+':'+event.cancelable));
	]=])
	realm:Start();pump()
	assert(not realm:InitializeVisibility(false),'Initial visibility cannot replace live visibility after loading')
	equals('trace.join("|")','load|pageshow:false:true:true:true:true:true')
	realm:SetVisible(false);realm:SetVisible(false);realm:SetVisible(true);pump()
	equals('trace.slice(2).join("|")','visibility:hidden:false:true|visibility:visible:false:true')
	run([=[globalThis.beforeTrace=[];window.onbeforeunload=event=>{
		beforeTrace.push((event instanceof BeforeUnloadEvent)+':'+event.returnValue+':'+(event.target===window)+':'+event.cancelable+':'+event.isTrusted);
		location.hash='#must-not-navigate';location.assign('https://lifecycle.test/ignored');
		event.returnValue=false;
		beforeTrace.push(event.returnValue+':'+event.defaultPrevented);
	};]=])
	assert(realm:RequestLeave({Reason='navigate',URL='https://lifecycle.test/next'})==true and #prompts==0,'No sticky activation must suppress the unload prompt')
	equals('beforeTrace.join("|")','true::true:true:true|false:false')
	equals('location.href','https://lifecycle.test/start')
	local target=document.Children[#document.Children]
	events:Emit(target,'click',{isTrusted=false})
	assert(realm:RequestLeave({Reason='close'})==true and #prompts==0,'Synthetic clicks must not grant activation')
	events:Emit(target,'mousedown',{isTrusted=true,button=0})
	clock+=1000
	assert(realm:RequestLeave({Reason='close'})==false and #prompts==1,'A canceled leave preserves the document; sticky activation does not expire with the transient gesture')
	equals('document.visibilityState','visible')
	permit=true
	run('window.onbeforeunload=()=>false;')
	assert(realm:RequestLeave({Reason='reload'})==true and #prompts==2,'Legacy false handler return requests confirmation')
	assert(prompts[2].Reason=='reload'and prompts[2].Message==nil,'Author return text must not become confirmation UI text')
	run('trace=[];')
	-- A queued background transition cannot revive a realm after unloading.
	realm:SetVisible(false);realm:SetVisible(true);realm:CommitLeave();realm:CommitLeave();pump()
	equals('trace.join("|")','pagehide:false:visible:true|visibility:hidden:false:true|unload:hidden:true:false')
	equals('document.hidden',true)
	realm:Destroy();events:Destroy()
	local disposedEvents=Events.new(error);local disposed=Runtime.new(Parser.parseDocument('<p>Disposed before loading</p>'),{
		Events=disposedEvents,Schedule=function()end,Visible=false})
	assert(disposed:Run('if(!document.hidden||document.visibilityState!=="hidden")throw new Error("Initial hidden state");'))
	disposed:SetVisible(true);disposed:Destroy();disposedEvents:Destroy()
	local pausedEvents=Events.new(error);local pausedResult=nil
	local paused=Runtime.new(Parser.parseDocument('<p>Native confirmation wait</p>'),{Events=pausedEvents,Schedule=function()end,
		ConfirmLeave=function()return coroutine.yield('leave-prompt')end})
	assert(paused:Run('window.fired=[];window.onbeforeunload=event=>event.preventDefault();setTimeout(()=>fired.push("task"),0);requestAnimationFrame(()=>fired.push("frame"));'))
	paused.Lifecycle:NotifyUserActivation()
	local waiter=coroutine.create(function()pausedResult=paused:RequestLeave({Reason='close'})end)
	local ok,state=coroutine.resume(waiter)
	assert(ok and state=='leave-prompt'and paused:IsExecuting(),'A native leave prompt pauses its document task/frame pump')
	assert(paused:PumpTasks()==0 and paused:PumpFrame()==0 and paused.VM.Get(paused.Window.Get('fired'),'length')==0,'Timers and animation frames must not run while the leave prompt waits')
	assert(coroutine.resume(waiter,false)and pausedResult==false and not paused:IsExecuting(),'Staying on the page releases the lifecycle pause')
	paused:PumpTasks();paused:PumpFrame();assert(paused.VM.Get(paused.Window.Get('fired'),'length')==2,'Canceled leave resumes queued tasks and animation frames')
	paused:Destroy();pausedEvents:Destroy()
	print('DocumentLifecycle: pageshow, queued visibility, legacy targets, sticky beforeunload confirmation, cancellation and one-shot uncached unload passed')
end
