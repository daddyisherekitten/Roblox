--!strict
return function(Parser,Runtime,Events,Node)
	local function make(host,address)
		local resumed,output={},{}
		local events=Events.new(error)
		local realm=Runtime.new(Parser.parseDocument('<!doctype html><body><button id="button">Ask</button></body>'),{
			URL=address or 'https://example.test/dialogs',Events=events,SimpleDialogHost=host,
			Schedule=function()end,ApplyChanges=function()return false end,
			Console=function(_,message)table.insert(output,message)end,
			ResumeEntry=function(thread)table.insert(resumed,thread)end,
		})
		local function drain()
			local count=0
			while #resumed>0 do count+=1;assert(count<50,'Dialog resume queue did not settle')
				local thread=table.remove(resumed,1);local ok,message=coroutine.resume(thread);assert(ok,tostring(message))
			end
		end
		return realm,events,resumed,output,drain
	end
	local requests={}
	local realm,events=make({Show=function(request,complete)
		table.insert(requests,request);complete(true,if request.Kind=='prompt'then request.DefaultValue else nil)
	end})
	local initialOK=realm:Run([=[
		var alertResult=alert();alert(undefined);var confirmResult=confirm();confirm(undefined);
		var promptResult=prompt(undefined,undefined);var nullResult=prompt(null,null);
		alert('line1\r\nline2\rline3');var conversions=[];
		prompt({toString(){conversions.push('message');return 'question';}},{toString(){conversions.push('default');return 'answer';}});
		var symbolErrors=0;try{alert(Symbol());}catch(e){if(e.name==='TypeError')symbolErrors++;}
		try{confirm(Symbol());}catch(e){if(e.name==='TypeError')symbolErrors++;}
		try{prompt('x',Symbol());}catch(e){if(e.name==='TypeError')symbolErrors++;}
		var descriptors=[alert.name,confirm.name,prompt.name,alert.length,confirm.length,prompt.length].join(',');
		var conversionOrder=conversions.join(',');
		var globalDescriptor=Object.getOwnPropertyDescriptor(window,'alert');
		if(!globalDescriptor.writable||!globalDescriptor.enumerable||!globalDescriptor.configurable)throw new Error('Window operation descriptor');
	]=])
	assert(initialOK,table.concat(realm.Diagnostics,' | '))
	assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
	assert(#requests==8 and requests[1].Message==''and requests[2].Message=='undefined')
	assert(requests[3].Message==''and requests[4].Message==''and requests[5].Message==''and requests[5].DefaultValue=='')
	assert(requests[6].Message=='null'and requests[6].DefaultValue=='null'and requests[7].Message=='line1\nline2\nline3')
	assert(requests[8].Message=='question'and requests[8].DefaultValue=='answer'and requests[8].URL=='https://example.test/dialogs'and requests[8].Origin=='https://example.test')
	assert(realm.Window.Get('alertResult')==realm.VM.Model.Undefined and realm.Window.Get('confirmResult')==true)
	assert(realm.Window.Get('promptResult')==''and realm.Window.Get('nullResult')=='null'and realm.Window.Get('symbolErrors')==3,
		tostring(realm.Window.Get('promptResult'))..' / '..tostring(realm.Window.Get('nullResult'))..' / '..tostring(realm.Window.Get('symbolErrors')))
	assert(realm.Window.Get('conversionOrder')=='message,default'and realm.Window.Get('descriptors')=='alert,confirm,prompt,0,0,0')
	realm:Destroy();events:Destroy()
	-- Window operations brand their receiver before DOMString conversion or
	-- contacting the host. null/undefined still use the defining realm global.
	table.clear(requests)
	realm,events=make({Show=function(request,complete)table.insert(requests,request);complete(true,'accepted')end})
	assert(realm:Run([=[
		var receiverErrors=0,receiverConversions=0;
		var message={toString(){receiverConversions++;return 'message';}};
		var fallback={toString(){receiverConversions++;return 'default';}};
		for(const method of [alert,confirm,prompt]){
			for(const receiver of [{},[],document,Window.prototype,Object.create(window),0,false,'text',Symbol(),1n]){
				try{method.call(receiver,message,fallback);}catch(e){if(e.name==='TypeError')receiverErrors++;}
			}
		}
		var convertedBeforeValid=receiverConversions;
		var validResults=[];
		for(const receiver of [window,self,globalThis,null,undefined]){
			validResults.push(alert.call(receiver,'valid')===undefined);
			validResults.push(confirm.apply(receiver,['valid'])===true);
			validResults.push(prompt.bind(receiver)('valid','default')==='accepted');
		}
		function strictDialogs(){'use strict';const a=alert,c=confirm,p=prompt;a('strict');return c('strict')&&p('strict')==='accepted';}
		var strictValid=strictDialogs();var allValid=validResults.every(Boolean);
	]=]))
	assert(realm.Window.Get('receiverErrors')==30 and realm.Window.Get('convertedBeforeValid')==0 and #requests==18)
	assert(realm.Window.Get('strictValid')and realm.Window.Get('allValid')and #realm.Diagnostics==0)
	realm:Destroy();events:Destroy()
	local opaqueRequest
	realm,events=make({Show=function(request,complete)opaqueRequest=request;complete(true,'opaque value')end},'about:blank')
	local privateOrigin=realm.DocumentOrigin
	assert(type(privateOrigin)=='table'and realm:Run("var opaque=prompt('Opaque origin','');"))
	assert(opaqueRequest.Origin=='null'and type(opaqueRequest.Origin)=='string'and opaqueRequest.URL=='about:blank'and realm.DocumentOrigin==privateOrigin)
	assert(realm.Window.Get('opaque')=='opaque value'and #realm.Diagnostics==0)
	realm:Destroy();events:Destroy()

	-- Standalone HTML suppresses UI and still performs Web IDL conversions.
	realm,events=make(nil)
	assert(realm:Run([=[
		var called=0;var alertResult=alert({toString(){called++;return 'hidden';}});
		var confirmed=confirm();var prompted=prompt();var symbolError=false;
		try{prompt(Symbol());}catch(e){symbolError=e.name==='TypeError';}
		var suppressedReceiverError=false;try{confirm.call({},'hidden');}catch(e){suppressedReceiverError=e.name==='TypeError';}
	]=]))
	assert(realm.Window.Get('called')==1 and realm.Window.Get('confirmed')==false and realm.Window.Get('prompted')==realm.VM.Model.Null and realm.Window.Get('symbolError')and realm.Window.Get('suppressedReceiverError'))
	realm:Destroy();events:Destroy()

	local pending,cancelled={},{ }
	local function host()
		return {Show=function(request,complete)
			local item={Request=request,Complete=complete};table.insert(pending,item)
			return function()cancelled[item]=(cancelled[item]or 0)+1;complete(false)end
		end}
	end
	local resumed,output,drain
	realm,events,resumed,output,drain=make(host())
	local owner=coroutine.create(function()assert(realm:Run([=[
		var order=['before'];queueMicrotask(()=>order.push('microtask'));setTimeout(()=>order.push('timer'),0);
		document.getElementById('button').onclick=()=>order.push('event');
		var answer=confirm('continue');order.push('after '+answer);
	]=]))end)
	assert(coroutine.resume(owner)and coroutine.status(owner)=='suspended'and realm:IsExecuting()and #pending==1)
	assert(realm:PumpTasks()==0 and realm:PumpFrame()==0,'A waiting dialog stalls its realm task and microtask queues')
	local input=coroutine.create(function()events:Emit(Node.findById(realm.Document,'button'),'click')end)
	assert(coroutine.resume(input)and coroutine.status(input)=='suspended')
	pending[1].Complete(true);pending[1].Complete(false);assert(#resumed==1 and realm:IsExecuting())
	drain();assert(coroutine.status(owner)=='dead'and coroutine.status(input)=='dead'and not realm:IsExecuting())
	assert(realm:Run("var resultOrder=order.join('|');"))
	assert(realm.Window.Get('resultOrder')=='before|after true|microtask|event')
	realm:PumpTasks();assert(realm:Run("var timerOrder=order.join('|');"))
	assert(realm.Window.Get('timerOrder')=='before|after true|microtask|event|timer'and #realm.Diagnostics==0)
	realm:Destroy();events:Destroy();table.clear(pending)

	-- Every interpreter entry route owns the native wait. Managed async and
	-- generator coroutine yields must not become a rejected Promise or yield().
	local routes={
		{'script',"var result=prompt('script','value');"},
		{'event',"document.getElementById('button').onclick=()=>{window.result=prompt('event','value');};"},
		{'timer',"setTimeout(()=>{window.result=prompt('timer','value');},0);"},
		{'idle',"requestIdleCallback(()=>{window.result=prompt('idle','value');});"},
		{'promise',"Promise.resolve().then(()=>{window.result=prompt('promise','value');});"},
		{'async',"async function ask(){return prompt('async','value');}ask().then(value=>{window.result=value;});"},
		{'generator',"var gen=(function*(){yield prompt('generator','value');})();var result=gen.next().value;"},
		{'async generator',"var gen=(async function*(){yield prompt('async generator','value');})();gen.next().then(entry=>{window.result=entry.value;});"},
	}
	for _,route in routes do
		realm,events,resumed,output,drain=make(host())
		local thread=coroutine.create(function()
			assert(realm:Run(route[2]))
			if route[1]=='event'then events:Emit(Node.findById(realm.Document,'button'),'click')
			elseif route[1]=='timer'or route[1]=='idle'then realm:PumpTasks()end
		end)
		local ok,message=coroutine.resume(thread);assert(ok,tostring(message))
		assert(coroutine.status(thread)=='suspended'and #pending==1 and pending[1].Request.Message==route[1],route[1])
		pending[1].Complete(true,'returned');drain()
		assert(coroutine.status(thread)=='dead'and realm.Window.Get('result')=='returned'and #realm.Diagnostics==0,route[1]..': '..table.concat(realm.Diagnostics,' | '))
		realm:Destroy();events:Destroy();table.clear(pending)
		-- Dispose the same entry route while its interpreter stack waits.
		realm,events,resumed,output,drain=make(host())
		thread=coroutine.create(function()
			realm:Run(route[2])
			if not realm.Alive then return end
			if route[1]=='event'then events:Emit(Node.findById(realm.Document,'button'),'click')
			elseif route[1]=='timer'or route[1]=='idle'then realm:PumpTasks()end
		end)
		local started,failure=coroutine.resume(thread);assert(started,tostring(failure))
		assert(coroutine.status(thread)=='suspended'and #pending==1,route[1]..' disposal setup')
		local cancelledItem=pending[1];realm:Destroy();drain();cancelledItem.Complete(true,'stale')
		assert(coroutine.status(thread)=='dead'and #resumed==0 and #output==0 and #realm.Diagnostics==0,route[1]..' disposal')
		events:Destroy();table.clear(pending)
	end

	-- Converting an argument may itself ask a question, before the outer
	-- dialog starts. Completion remains sequential through the host trampoline.
	realm,events,resumed,output,drain=make(host())
	owner=coroutine.create(function()assert(realm:Run("var nested=prompt({toString(){return 'outer '+confirm('inner');}},'');"))end)
	assert(coroutine.resume(owner)and #pending==1 and pending[1].Request.Message=='inner')
	pending[1].Complete(true);drain();assert(coroutine.status(owner)=='suspended'and #pending==2 and pending[2].Request.Message=='outer true')
	pending[2].Complete(false);drain();assert(realm.Window.Get('nested')==realm.VM.Model.Null and #realm.Diagnostics==0)
	realm:Destroy();events:Destroy();table.clear(pending)

	-- Native host reentry while its modal is pending is safely suppressed.
	local nestedCalls=0
	realm,events=make({Show=function(_,complete)
		nestedCalls+=1;assert(realm:Run("var suppressed=confirm('nested native host');"));complete(true)
	end})
	assert(realm:Run("var result=confirm('outer');"))
	assert(nestedCalls==1 and realm.Window.Get('result')==true and realm.Window.Get('suppressed')==false)
	realm:Destroy();events:Destroy()

	-- Cancel a live realm: return the standard cancel value once, close its
	-- exact native dialog, and ignore old callbacks when a new one is active.
	realm,events,resumed,output,drain=make(host())
	owner=coroutine.create(function()assert(realm:Run("var cancelled=prompt('cancel','initial');var second=confirm('second');"))end)
	assert(coroutine.resume(owner)and #pending==1)
	local old=pending[1];realm.SimpleDialogs:Cancel();realm.SimpleDialogs:Cancel();drain()
	assert(cancelled[old]==1 and #pending==2 and realm.Window.Get('cancelled')==realm.VM.Model.Null)
	old.Complete(true,'stale');assert(#resumed==0 and realm.SimpleDialogs.Pending~=nil)
	pending[2].Complete(false);drain();assert(realm.Window.Get('second')==false)
	realm:Destroy();events:Destroy();table.clear(pending)

	-- Navigation/disposal must not run a JS catch/finally continuation after
	-- the document has died, even if its native UI completes again later.
	realm,events,resumed,output,drain=make(host())
	local document=realm.Document
	owner=coroutine.create(function()realm:Run("try { confirm('closing'); } catch(e) {document.body.setAttribute('data-stale','catch');} finally {console.log('stale finally');}")end)
	assert(coroutine.resume(owner)and #pending==1)
	old=pending[1];realm:Destroy();assert(cancelled[old]==1 and #resumed==1)
	old.Complete(true);drain()
	assert(coroutine.status(owner)=='dead'and #output==0 and #realm.Diagnostics==0)
	assert(Node.findElement(document,function(node)return node.Attributes and node.Attributes['data-stale']~=nil end)==nil)
	events:Destroy();table.clear(pending)

	local failedHostCalls=0
	realm,events=make({Show=function()failedHostCalls+=1;error('UI unavailable')end})
	local ran=realm:Run("var failed=confirm('host fault');")
	assert(ran and failedHostCalls==1 and realm.Window.Get('failed')==false and #realm.Diagnostics==1 and not realm.SimpleDialogs.Pending)
	realm:Destroy();events:Destroy()
	-- The standalone fallback resumes the owning Luau coroutine without a
	-- Roblox task service; destruction still precedes author catch/finally.
	local callback,cleanupCount=nil,0;local directEvents=Events.new(error);local directOutput={}
	local direct=Runtime.new(Parser.parseDocument('<p>Standalone callback host</p>'),{Events=directEvents,
		Console=function(_,message)table.insert(directOutput,message)end,
		SimpleDialogHost={Show=function(_,complete)callback=complete;return function()cleanupCount+=1;complete(false)end end}})
	local thread=coroutine.create(function()direct:Run("try{confirm('direct');}catch(e){console.log('stale catch');}finally{console.log('stale finally');}")end)
	assert(coroutine.resume(thread)and coroutine.status(thread)=='suspended')
	direct:Destroy();assert(coroutine.status(thread)=='dead'and cleanupCount==1 and #directOutput==0 and #direct.Diagnostics==0)
	callback(true);assert(cleanupCount==1 and #directOutput==0);directEvents:Destroy()
	-- Native image publication is a realm message, not strict live-object
	-- Access. It waits behind author execution and quietly cancels on disposal.
	-- Actual responsive selection queues its request microtask, and its load
	-- callback retains the normal Promise checkpoint.
	local function imageRealm()
		local queue,dialogs,loads={},{},{};local width=200
		local input=Events.new(error)
		local r=Runtime.new(Parser.parseDocument('<!doctype html><img id="responsive" loading="lazy" sizes="auto" srcset="small.png 200w, large.png 800w">'),{
			URL='https://images.test/',Events=input,Schedule=function()end,
			ResourceViewport=function()return {Width=1024,Resolution=1}end,
			ImageIsRendered=function()return {Width=width,Height=100}end,
			LoadImage=function(url,complete)table.insert(loads,url);complete(true,{Width=800,Height=100})end,
			ResumeEntry=function(thread)table.insert(queue,thread)end,
			SimpleDialogHost={Show=function(request,complete)table.insert(dialogs,{Request=request,Complete=complete});return function()end end}})
		assert(r:Run("var imageLog=[];document.getElementById('responsive').onload=function(){imageLog.push('load');Promise.resolve().then(()=>imageLog.push('microtask'));};"))
		for _=1,4 do r:PumpTasks()end
		assert(#loads==1 and loads[1]=='https://images.test/small.png','Initial actual image request is settled before the layout message')
		assert(r:Run('imageLog=[];'))
		local function resumeEntries()
			local count=0;while #queue>0 do
				count+=1;assert(count<16,'Image publication entry queue converges')
				local waiting=table.remove(queue,1)
				if coroutine.status(waiting)=='suspended'then local ok,why=coroutine.resume(waiting);assert(ok,tostring(why))end
			end
		end
		return r,input,loads,dialogs,resumeEntries,function()width=700 end
	end
	do
		local r,input,loads,_,_,resize=imageRealm();resize();r:ImageLayoutCompleted()
		assert(#loads==2 and loads[2]=='https://images.test/large.png','Image layout message checkpoints the actual selection request microtask before returning')
		for _=1,4 do r:PumpTasks()end
		assert(r:Run("var imageTrace=imageLog.join('|');"))
		assert(r.Window.Get('imageTrace')=='load|microtask','Actual image load event and author Promise callback retain normal checkpoints')
		assert(#r.Diagnostics==0,table.concat(r.Diagnostics,' | '));r:Destroy();input:Destroy()
	end
	for _,dispose in {false,true}do
		local r,input,loads,dialogs,resumeEntries,resize=imageRealm()
		local author=coroutine.create(function()r:Run("confirm('Image publication waits')")end)
		assert(coroutine.resume(author)and coroutine.status(author)=='suspended'and r:IsExecuting()and #dialogs==1)
		resize();local completed,failure
		local publication=coroutine.create(function()completed,failure=pcall(function()r:ImageLayoutCompleted()end)end)
		local began,why=coroutine.resume(publication);assert(began,tostring(why))
		assert(coroutine.status(publication)=='suspended'and #loads==1,'Native image message waits rather than executing concurrently with the author stack')
		if dispose then r:Destroy()else dialogs[1].Complete(true)end
		resumeEntries()
		assert(coroutine.status(publication)=='dead'and completed==true,tostring(failure))
		if dispose then
			assert(#loads==1,'A waiting image message does not select/request a resource after document disposal')
			assert(pcall(function()r:ImageLayoutCompleted()end),'An already disposed image recipient quietly rejects the background message')
			local strict=pcall(function()r:Access(function()error('Disposed access callback ran')end)end)
			assert(not strict,'Strict same-origin live-object Access still throws after document disposal')
		else
			assert(#loads==2 and loads[2]=='https://images.test/large.png','A waiting live image message resumes its actual selection microtask')
			for _=1,4 do r:PumpTasks()end
			assert(r:Run("var imageTrace=imageLog.join('|');"));assert(r.Window.Get('imageTrace')=='load|microtask')
			r:Destroy()
		end
		assert(#r.Diagnostics==0,table.concat(r.Diagnostics,' | '));input:Destroy()
	end
	print('JavaScriptSimpleDialogs: synchronous values/conversions, no-host suppression, script/event/timer/Promise/async/generator waits, serialized reentry and cancellation passed')
end
