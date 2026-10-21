--!strict
return function(Parser,Runtime,WorkerRealm)
	local url="https://worker.test/"
	local clock=0;local children={};local output={};local errors={};local terminated=0
	local sources={
		[url.."classic.js"]=[[importScripts('./helper.js');onmessage=async e=>{const bytes=new Uint8Array(e.data);const first=bytes[0];await Promise.resolve();postMessage({result:double(first),buffer:bytes.buffer,isolated:typeof document+':'+typeof window,self:self===globalThis,location:location.pathname,name},[bytes.buffer]);postMessage('detached:'+bytes.byteLength);}]],
		[url.."helper.js"]=[[function double(x){return x*2;}]],
		[url.."module.js"]=[[import {triple} from './module-helper.js';await new Promise(r=>setTimeout(r,5));onmessage=e=>{postMessage('module:'+triple(e.data));try{importScripts('helper.js');}catch(e){postMessage(e.name);}};postMessage('ready');]],
		[url.."module-helper.js"]=[[export function triple(n){return n*3;}]],
		[url.."errors.js"]=[[addEventListener('error',e=>{e.preventDefault();postMessage('caught');});onmessage=()=>{throw new Error('handled worker error');};]],
		[url.."close.js"]=[[onmessage=()=>{close();postMessage('last');};]],
	}
	local parent=Runtime.new(Parser.parseDocument('<!doctype html><html><body></body></html>'),{
		URL=url.."index.html",ScriptSources=sources,SupportsModuleWorkers=true,Clock=function()return clock end,
		Schedule=function()end,Console=function(_,value)table.insert(output,value)end,Diagnostic=function(value)table.insert(errors,value)end,
		SpawnWorker=function(spec,callbacks)
			local child=WorkerRealm.new(spec,{Clock=function()return clock end,Sources=sources,Message=callbacks.Message,Error=callbacks.Error,Exit=callbacks.Exit})
			table.insert(children,child);child:Start()
			return {PostMessage=function(wire)child:PostMessage(wire)end,Terminate=function()terminated+=1;child:Destroy()end}
		end,
	})
	local function run(source)local ok,message=parent:Run(source);assert(ok,tostring(message))end
	local function pump()
		for _=1,20 do clock+=.001;parent:PumpTasks();for _,child in children do child:Pump()end end
		assert(#errors==0,table.concat(errors," | "))
	end
	run([[var w=new Worker('./classic.js',{name:'calculation'});var bytes=new Uint8Array([7,9]);w.onmessage=e=>{if(typeof e.data==='string'){console.log(e.data);return;}console.log(e.data.result,e.data.isolated,e.data.self,e.data.location,e.data.name,new Uint8Array(e.data.buffer).join(','),e.isTrusted);};w.postMessage(bytes.buffer,[bytes.buffer]);console.log('parent detached',bytes.byteLength);]])
	assert(#children==0 and table.concat(output,"|")=="parent detached 0","Construction queues background startup")
	pump();assert(table.concat(output,"|")=="parent detached 0|14 undefined:undefined true /classic.js calculation 7,9 true|detached:0","Isolated realm clones and transfers buffers in both directions")
	run([[var moduleWorker=new Worker('./module.js',{type:'module'});moduleWorker.onmessage=e=>{if(e.data==='ready'){moduleWorker.postMessage(8);}else{console.log(e.data);}};moduleWorker.postMessage(8);]])
	pump();assert(output[4]=="module:24" and output[5]=="TypeError"and #output==5,"Messages before a handler installed after top-level await are lost; a ready handshake permits subsequent delivery")
	run([[var errorsWorker=new Worker('./errors.js');errorsWorker.onmessage=e=>console.log(e.data);errorsWorker.postMessage(1);]])
	pump();assert(output[6]=="caught","Worker error cancellation suppresses parent reporting")
	run([[var closing=new Worker('./close.js');closing.onmessage=e=>console.log(e.data);closing.postMessage(1);closing.postMessage(2);]])
	pump();assert(output[7]=="last" and #output==7 and terminated==1,"close discards queued work after the current task and preserves its final message")
	run([[for(const value of [new Intl.Locale('en'),new Intl.NumberFormat('en'),new Intl.ListFormat('en')]){try{structuredClone(value);}catch(e){console.log(e.name);}}]])
	assert(output[8]=="DataCloneError" and output[9]=="DataCloneError" and output[10]=="DataCloneError","Intl platform objects reject structured cloning")
	parent:Destroy();for _,child in children do assert(not child.Alive and not child.VM.Alive and child.Loop.TaskCount==0 and child.Loop.TimerCount==0,"Destroy terminates all worker VM/queue owners")end
	assert(terminated==4,"Each independently owned worker terminates exactly once")
	local wakes=0
	local idle=WorkerRealm.new({url=url.."idle.js",source="setTimeout(()=>{},5000)",type="classic"},{Clock=function()return clock end,Wake=function()wakes+=1 end})
	idle:Start();local baseline=wakes
	for _=1,100 do idle:Pump()end
	assert(wakes==baseline and idle:NextDue()>clock,"Idle workers and future timers do not schedule continuous actor work")
	idle:Destroy()
	local failures,exits=0,0
	local invalid=WorkerRealm.new({url=url.."invalid.js",source="const = ;",type="classic"},{Error=function()failures+=1 end,Exit=function()exits+=1 end})
	invalid:Start();invalid:Pump();invalid:Pump();assert(invalid.Closing and failures==1 and exits==1,"Parse failure exits once instead of retaining an unusable worker")
	invalid:Destroy()
	local bounded=WorkerRealm.new({url=url.."budget.js",source="while(true){}",type="classic"},{MaxSteps=100,Error=function()failures+=1 end})
	bounded:Start();assert(bounded.Closing,"A start script that exhausts its instruction budget cannot retain a runnable realm");bounded:Destroy()
	-- Roblox's Actor bridge switches execution modes and suspends its host
	-- task. That suspension must not be interpreted as a JavaScript await/yield.
	for _,fixture in {
		{Type="classic",Source="onmessage=async()=>{await Promise.resolve();postMessage('async');postMessage('done');};",Expected="async|done"},
		{Type="classic",Source="function* values(){postMessage('generator');yield 1;postMessage('done');}onmessage=()=>{const g=values();g.next();g.next();};",Expected="generator|done"},
		{Type="classic",Source="async function* values(){await Promise.resolve();postMessage('async-generator');yield 1;postMessage('done');}onmessage=async()=>{for await(const n of values())postMessage('value:'+n);};",Expected="async-generator|value:1|done"},
		{Type="module",Source="await Promise.resolve();postMessage('module-ready');onmessage=()=>postMessage('module-message');",Expected="module-ready|module-message"},
	}do
		local delivered,failures={},{}
		local worker
		worker=WorkerRealm.new({url=url.."yielding.js",source=fixture.Source,type=fixture.Type},{Clock=function()return clock end,
			Message=function(wire)
				coroutine.yield("actor-synchronize")
				local data=worker.Clone:Deserialize(wire);table.insert(delivered,data)
			end,Error=function(detail)table.insert(failures,detail.message)end})
		local thread=coroutine.create(function()
			worker:Start();worker:PostMessage(worker.Clone:Serialize(1));worker:Pump()
		end)
		local suspensions=0
		while coroutine.status(thread)~="dead"do
			local ok,reason=coroutine.resume(thread);assert(ok,tostring(reason))
			if coroutine.status(thread)~="dead"then assert(reason=="actor-synchronize","Only the owning host task may suspend at the bridge");suspensions+=1 end
			assert(suspensions<=8,"Worker bridge failed to resume")
		end
		assert(#failures==0,fixture.Type..": "..table.concat(failures," | "))
		assert(table.concat(delivered,"|")==fixture.Expected and suspensions==#delivered,
			"Yieldable Actor message delivery preserves async, generator and top-level-await continuations")
		worker:Destroy()
	end
	print("Worker realm: DOM isolation, classic/module imports, awaited startup, messages/buffer transfer, error cancellation, close and lifecycle passed")
end
