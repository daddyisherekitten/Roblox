--!strict
-- Compare shared JavaScript traces with native ECMAScript; exercise renderer
-- batching, bounded failures and lifetime without a native FPS benchmark.
return function(Runtime,Parser,Node,VM,fixtures)
	local function fresh(options)
		local s={Values={},Reports={},Schedules=0,Flushes=0,Time=100}
		local document=Parser.parseDocument('<html><body><p id="result">Before</p></body></html>')
		s.Document=document
		s.Runtime=Runtime.new(document,{Clock=function()return s.Time end,MaxSteps=options and options.MaxSteps,
			Console=function(_,message)table.insert(s.Values,message)end,
			Diagnostic=function(message)table.insert(s.Reports,message)end,
			Schedule=function()s.Schedules+=1 end,
			ApplyChanges=function(changes)s.Flushes+=1;s.Changes=changes;return false end})
		s.Runtime:Run('function record(v){console.log(String(v));}')
		return s
	end
	for _,fixture in fixtures do
		local s=fresh();s.Runtime:Run(fixture.source);s.Runtime:PumpTasks()
		assert(#s.Reports==0,fixture.name..": "..tostring(s.Reports[1]))
		assert(#s.Values==#fixture.expected,fixture.name..": "..table.concat(s.Values," | "))
		for i,value in fixture.expected do assert(s.Values[i]==value,fixture.name..": "..table.concat(s.Values," | ")) end
		s.Runtime:Destroy()
	end
	do
		local s=fresh();local r=s.Runtime
		r:Run([=[const label=document.getElementById("result");label.textContent="Sync";
Promise.resolve(1).then(function(v){label.textContent="First";return v+1;}).then(function(v){label.textContent="Final: "+v;});]=])
		assert(Node.textContent(Node.findById(s.Document,"result"))=="Final: 2" and s.Schedules==1,"Promise reactions join one DOM batch")
		r:Flush();assert(s.Flushes==1 and s.Changes[Node.findById(s.Document,"result")].Text)
		r:Run('Promise.reject("handled");Promise.reject("micro").catch(function(){});const p=Promise.reject("later in checkpoint");queueMicrotask(function(){p.catch(function(){});});')
		assert(#s.Reports==0 and r.EventLoop.TaskCount>0,"Unhandled rejection notification waits for a host task")
		r:PumpTasks()
		assert(#s.Reports==1 and s.Reports[1]:find("Unhandled promise rejection: handled",1,true),"Only still-unhandled rejections are reported by the notification task")
		r:Run('const noHandler=Promise.reject("forwarded");noHandler.then();')
		r:PumpTasks()
		assert(#s.Reports==2 and s.Reports[2]:find("forwarded",1,true),"An absent rejection handler transfers responsibility to the child")
		r:Run('Promise(function(){});');r:Run('new Promise(1);');r:Run('const detached=Promise.resolve(1).then;detached(function(){});')
		assert(#s.Reports==5,"Constructor and then receiver checks fail synchronously")
		r:Run('throw new RangeError("outside");');assert(s.Reports[6]:find("RangeError: outside",1,true))
		r:Run('Promise.resolve(8).then(function(v){record(v);});');assert(s.Values[#s.Values]=="8","Throwing code does not poison subsequent calls")
		r:Destroy()
	end
	do
		local s=fresh();local r=s.Runtime
		local getterCalls=0
		r.VM.Global.Bindings.getterThenable={Value={Get=function()
			getterCalls+=1;VM.throw(VM.error("TypeError","then getter"))
		end}}
		r:Run('Promise.resolve(getterThenable).catch(function(e){record(e.name);record(e.message);});')
		assert(getterCalls==1 and s.Values[1]=="TypeError" and s.Values[2]=="then getter" and #s.Reports==0)
		r:Run('let resolveLater;const p=new Promise(function(resolve){resolveLater=resolve;});p.then(function(v){record(v);});window.promise=p;window.done=resolveLater;')
		local retained=r.Window.Get("promise");local done=r.Window.Get("done")
		-- Allocate unrelated states so a live wrapper cannot lose its private
		-- state just because only weak registry references remain.
		for _=1,50 do r:Run('for(let i=0;i<100;i++){Promise.resolve(i);}');assert(#s.Reports==0,s.Reports[1]) end
		r:Run('resolveLater(19);');assert(s.Values[#s.Values]=="19")
		local detachedState=retained.Get("constructor");assert(detachedState==r.Promises.Constructor)
		r:Run('window.pending=new Promise(function(resolve){setTimeout(function(){resolve(20);},0);});window.pending.then(function(v){record(v);});')
		r:Destroy();done({21});assert(not pcall(function()retained.Get("then")end))
		assert(r.EventLoop.TimerCount==0 and #r.EventLoop.Microtasks==0 and r:PumpTasks()==0,"Disposed realm releases promise jobs and timers")
	end
	do
		local s=fresh({MaxSteps=1000});local r=s.Runtime
		r:Run('const loop={then:function(resolve){resolve(loop);}};Promise.resolve(loop);')
		assert(#s.Reports>0 and #r.EventLoop.Microtasks==0,"A self-resolving thenable is bounded by the shared microtask instruction budget")
		r:Run('Promise.resolve(2).then(function(v){record(v);});');assert(s.Values[#s.Values]=="2")
		r:Destroy()
	end
	print("JavaScript promises: "..#fixtures.." ECMAScript traces, synchronous executors, chained adoption/rejection/finally, one DOM batch, rejection diagnostics, weak state lifetime, bounded cycles and disposal passed")
end
