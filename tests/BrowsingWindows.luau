--!strict
return function(Features,Parser,Runtime,Events)
	local a=Features.features('popup,width=420,height=300,left=-10,top=70,noopener=false');assert(a.Popup and a.Width==420 and a.Height==300 and a.Left==-10 and not a.NoOpener)
	a=Features.features('popup=0,width=420');assert(not a.Popup and a.Width==420)
	a=Features.features('noreferrer,innerWidth=301,innerHeight=205,screenX=2,screenY=4');assert(a.Popup and a.NoOpener and a.NoReferrer and a.Width==301 and a.Top==4)
	assert(not Features.features('noopener').Popup and not Features.features('attributionsrc').Popup)
	local requests={};local isClosed=false;local selfClosed=0;local focused=0;local desktop={Width=1600,Height=900}
	local handle={Name='child',IsClosed=function()return isClosed end,close=function()isClosed=true end,focus=function()focused+=1 end}
	local events=Events.new(error);local doc=Parser.parseDocument('<!doctype html><p>Window host</p>',{ScriptingEnabled=true})
	local realm=Runtime.new(doc,{URL='http://local.test/index.html',Events=events,Schedule=function()end,ApplyChanges=function()return false end,
		WindowHost={Open=function(r)table.insert(requests,r);return handle end,close=function()selfClosed+=1 end,IsClosed=function()return false end,
			ScreenMetrics=function(key)return if key=='width'or key=='availWidth'then desktop.Width elseif key=='height'or key=='availHeight'then desktop.Height else nil end}})
	assert(realm:Run([[var display=screen;screen.height=12;var desktopMetrics=screen===window.screen&&screen.width===1600&&screen.availHeight===900&&screen.height===900&&screen.availLeft===0&&screen.colorDepth===24;]]))
	assert(realm.Window.Get('desktopMetrics')==true,'Screen dimensions use the host desktop, remain read-only and have stable window identity')
	desktop.Width,desktop.Height=1280,720
	assert(realm:Run([[var resizedDisplay=display.width===1280&&display.availHeight===720;]]))
	assert(realm.Window.Get('resizedDisplay')==true,'An existing Screen object reads current desktop dimensions after resize')
	realm:Run([=[
		var first=open('child.html','child','popup,width=301');var same=window.open('other.html','child')===first;
		first.focus();first.close();var childClosed=first.closed;first.close();
		var protectedResult=window.open('child.html','child','noopener')===null;
		window.close();var converted=false;try{window.open(Symbol('url'));}catch(e){converted=e.name==='TypeError';}
	]=]);assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
	assert(realm.Window.Get('same')==true and realm.Window.Get('childClosed')==true and realm.Window.Get('protectedResult')==true and realm.Window.Get('converted')==true)
	assert(#requests==3 and requests[1].Features.Width==301 and requests[1].URL=='child.html'and selfClosed==1 and focused==1)
	assert(realm:Run("open('','empty');open();open('about:blank','explicit');"))
	assert(requests[4].URL==''and requests[5].URL==''and requests[6].URL=='about:blank','The host must distinguish omitted/empty URLs from an explicit blank navigation')
	realm:Destroy();events:Destroy()
	events=Events.new(error);realm=Runtime.new(Parser.parseDocument('<p>No GUI</p>'),{Events=events,Schedule=function()end,ApplyChanges=function()return false end})
	realm:Run('var unavailable=window.open()===null;window.close();var alive=!window.closed;var standaloneScreen=typeof screen==="object"&&screen.colorDepth===24;');assert(#realm.Diagnostics==0 and realm.Window.Get('unavailable')==true and realm.Window.Get('alive')==true and realm.Window.Get('standaloneScreen')==true)
	realm:Destroy();events:Destroy()
	-- Window.close is a nonblocking request. The supplied browser adapter
	-- defers its native beforeunload guard; it must not suspend an async or
	-- generator body as though close itself were an alert/confirm dialog.
	local routes={
		{'script',"var result=ACTION;var completed=result===undefined;"},
		{'event',"addEventListener('click',()=>{var result=ACTION;window.completed=result===undefined;});"},
		{'timer',"setTimeout(()=>{var result=ACTION;window.completed=result===undefined;},0);"},
		{'promise',"Promise.resolve().then(()=>{var result=ACTION;window.completed=result===undefined;});"},
		{'async',"async function ask(){var result=ACTION;return result===undefined;}ask().then(value=>{window.completed=value;});"},
		{'generator',"var gen=(function*(){try{var result=ACTION;window.completed=result===undefined;yield 'author value';}finally{console.log('generator finalizer');}})();var yielded=gen.next();var correctYield=yielded.value==='author value'&&!yielded.done;"},
		{'async-generator',"var gen=(async function*(){try{var result=ACTION;yield result===undefined;}finally{console.log('generator finalizer');}})();gen.next().then(value=>{window.completed=value.value===true&&!value.done;});"},
		{'idle',"requestIdleCallback(()=>{var result=ACTION;window.completed=result===undefined;});"},
	}
	for _,foreign in {false,true}do for _,route in routes do
		local queued,output={},{};local guardCalls=0;local targetClosed=false
		local target,caller;local targetEvents=Events.new(error);local callerEvents=if foreign then Events.new(error)else targetEvents
		local function closeRequest()
			table.insert(queued,function()
				if targetClosed or not target.Alive then return end
				if target:RequestLeave({Reason='close'})then target:CommitLeave();target:Destroy();targetClosed=true end
			end)
		end
		local remote={IsClosed=function()return targetClosed end,close=closeRequest}
		local function fresh(eventSource,closeHost)
			return Runtime.new(Parser.parseDocument('<!doctype html><p>Deferred close</p>'),{Events=eventSource,
				URL='https://close.test/page',Schedule=function()end,ApplyChanges=function()return false end,
				Console=function(_,message)table.insert(output,message)end,
				WindowHost=closeHost,ConfirmLeave=function()guardCalls+=1;return coroutine.yield('native-close-guard')end})
		end
		caller=fresh(callerEvents,{close=closeRequest,Open=function()return remote end,IsClosed=function()return not foreign and targetClosed end})
		target=if foreign then fresh(targetEvents,nil)else caller
		assert(target:Run("window.onbeforeunload=()=>false;"))
		targetEvents:Emit(target.Document,'mousedown',{isTrusted=true,button=0})
		local setup=if foreign then "var child=open('child.html');"else ''
		local action=if foreign then 'child.close()'else 'window.close()'
		local script=setup..route[2]:gsub('ACTION',action)
		local thread=coroutine.create(function()
			local ok,message=caller:Run(script);assert(ok,tostring(message))
			if route[1]=='event'then callerEvents:Emit(caller.Document,'click',{isTrusted=true})
			elseif route[1]=='timer'or route[1]=='idle'then caller:PumpTasks()end
		end)
		local ok,message=coroutine.resume(thread);assert(ok,tostring(message))
		assert(coroutine.status(thread)=='dead'and caller.Window.Get('completed')==true and #queued==1 and guardCalls==0,
			route[1]..' close must return undefined and finish its author stack before the native guard')
		if route[1]=='generator'then assert(caller.Window.Get('correctYield')==true,'close must not become a generator yield')end
		assert(#caller.Diagnostics==0 and #target.Diagnostics==0)
		local native=coroutine.create(table.remove(queued,1));local started,reason=coroutine.resume(native)
		assert(started and reason=='native-close-guard'and target.Alive and guardCalls==1,'The deferred native guard, rather than the author stack, waits')
		assert(coroutine.resume(native,false)and coroutine.status(native)=='dead'and target.Alive and not targetClosed,'Cancel retains the target document')
		closeRequest();native=coroutine.create(table.remove(queued,1));started,reason=coroutine.resume(native)
		assert(started and reason=='native-close-guard'and guardCalls==2)
		assert(coroutine.resume(native,true)and coroutine.status(native)=='dead'and not target.Alive and targetClosed)
		if foreign then assert(caller.Alive);caller:Destroy()end
		assert(#output==0 and #caller.Diagnostics==0 and #target.Diagnostics==0,'Closing does not run suspended author generator finalizers')
		targetEvents:Destroy();if foreign then callerEvents:Destroy()end
	end end
	print('BrowsingWindows: feature aliases/flags, stable handles, close/focus, JS conversions and no-host standalone behavior passed')
end
