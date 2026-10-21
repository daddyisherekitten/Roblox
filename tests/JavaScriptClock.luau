--!strict
-- Deterministic functional tests: no sleeping and no native FPS measurements.
return function(Runtime,Parser,Node,Events,HTMLScripts,loadRenderTree,loadWordLayout,loadBlockLayout,Dirty,FormModel,demoHTML,demoCSS,Style,CanvasBackground)
	local function fresh()
		local state={Time=100,Reports={},Schedules=0,Flushes=0}
		state.Document=Parser.parseDocument('<!doctype html><html><body><p id="result">Before</p><button id="button">Click</button></body></html>')
		state.Events=Events.new(error)
		state.Runtime=Runtime.new(state.Document,{Events=state.Events,Clock=function()return state.Time end,
			Click=function(node)state.Events:Emit(node,"click")end,
			Diagnostic=function(message)table.insert(state.Reports,message)end,
			Schedule=function()state.Schedules+=1 end,
			ApplyChanges=function(changes)state.Flushes+=1;state.Changes=changes;return false end})
		function state:Read(key)return self.Runtime.Window.Get(key)end
		function state:Run(source)self.Runtime:Run(source)end
		function state:Destroy()self.Runtime:Destroy();self.Events:Destroy()end
		return state
	end
	do
		local s=fresh();local r=s.Runtime
		-- A parsed trailing script exercises Start's actual placement/cleanup.
		local bootDoc=Parser.parseDocument('<!doctype html><html><body><script id="boot">window.current=document.currentScript.id;queueMicrotask(function(){window.afterScript=document.currentScript===null;});</script></body></html>')
		local boot=Runtime.new(bootDoc,{Events=s.Events,ApplyChanges=function()return false end,Diagnostic=error})
		boot:Start();assert(boot.Window.Get("current")=="boot" and boot.Window.Get("afterScript")==false,"Classic-script checkpoints retain currentScript, matching Chromium")
		boot:Destroy()
		s:Run([=["use strict";window.order="A";
setTimeout(function(){window.order+="T";window.timerThis=this===window;},0);
queueMicrotask(function(){window.order+="B";queueMicrotask(function(){window.order+="D";});});
queueMicrotask(function(){window.order+="C";});window.order+="S";]=])
		assert(s:Read("order")=="ASBCD","Microtasks run FIFO after the current script, including nested microtasks")
		assert(r:PumpTasks()==1 and s:Read("order")=="ASBCDT" and s:Read("timerThis"),"Timer is a later task with Window as this")
		s:Run([=[const result=document.getElementById("result");result.textContent="One";
queueMicrotask(function(){result.textContent="Two";queueMicrotask(function(){result.textContent="Final";});});]=])
		assert(Node.textContent(Node.findById(s.Document,"result"))=="Final" and s.Schedules==1,"A task and all its microtasks schedule one DOM batch")
		r:Flush();assert(s.Flushes==1 and s.Changes[Node.findById(s.Document,"result")].Text)
		s:Destroy()
	end
	do
		local s=fresh();local r=s.Runtime
		s:Run([=[window.order="";window.got="";
setTimeout(function(a,b){window.got=a+":"+b;window.order+="A";},10,"argument",7);
setTimeout(function(){window.order+="B";},10);
const cancelled=setTimeout(function(){window.order+="BAD";},10);clearInterval(cancelled);
setTimeout("window.stringRan = 1;", 10);
window.interval=setInterval(function(){window.order+="I";queueMicrotask(function(){clearTimeout(window.interval);});},10);]=])
		s.Time+=.009;assert(r:PumpTasks()==0)
		s.Time+=.002;assert(r:PumpTasks()==4)
		assert(s:Read("order")=="ABI" and s:Read("got")=="argument:7" and s:Read("stringRan")==1,"Timer args/source, equal-deadline order and shared cancellation map")
		s.Time+=1;assert(r:PumpTasks()==0 and r.EventLoop.TimerCount==0,"Microtask cancellation prevents interval rearming")
		s:Run('window.count=0;window.repeat=setInterval(function(){window.count+=1;if(window.count===2){clearInterval(window.repeat);}},20);')
		s.Time+=1;r:PumpTasks();assert(s:Read("count")==1,"A delayed interval does not replay missed ticks")
		s.Time+=.021;r:PumpTasks();assert(s:Read("count")==2 and r.EventLoop.TimerCount==0)
		s:Destroy()
	end
	do
		local s=fresh();local r=s.Runtime
		s:Run('window.n=0;function next(){window.n+=1;if(window.n<8){setTimeout(next,0);}}setTimeout(next,0);')
		assert(r:PumpTasks()==6 and s:Read("n")==6,"Nested timers clamp after nesting level five")
		assert(math.abs(r.EventLoop:NextDue()-100.004)<.000001)
		s.Time=100.003;assert(r:PumpTasks()==0)
		s.Time=100.005;r:PumpTasks();assert(s:Read("n")==7)
		s.Time=100.010;r:PumpTasks();assert(s:Read("n")==8)
		s:Run('window.converted=0;setTimeout(function(){window.converted+=1;},-2);setTimeout(function(){window.converted+=1;},2147483648);')
		r:PumpTasks();assert(s:Read("converted")==2,"Timer delays use signed long conversion then clamp negatives")
		s:Destroy()
	end
	do
		local s=fresh();local r=s.Runtime
		s:Run([=["use strict";window.frames="";
requestAnimationFrame(function(t){window.frames+="A";window.first=t;window.frameThis=this===undefined;
  queueMicrotask(function(){window.frames+="M";});requestAnimationFrame(function(t2){window.frames+="N";window.next=t2;});cancelAnimationFrame(window.cancelled);});
requestAnimationFrame(function(t){window.frames+="B";window.second=t;window.now=performance.now();});
window.cancelled=requestAnimationFrame(function(){window.frames+="BAD";});]=])
		s.Time=100.020;assert(r:PumpFrame()==2)
		assert(s:Read("frames")=="AMB" and s:Read("frameThis"),"Frame callbacks have a snapshot, cancellation and microtask checkpoints")
		assert(s:Read("first")==s:Read("second") and math.abs(s:Read("first")-20)<.000001 and s:Read("now")==s:Read("first"),"Same-frame timestamps and performance.now share a realm time origin")
		s.Time=100.036;assert(r:PumpFrame()==1 and s:Read("frames")=="AMBN" and s:Read("next")>s:Read("first"))
		assert(r.EventLoop.FrameCount==0)
		s.Time=99;s:Run('window.monotonic=performance.now();');assert(s:Read("monotonic")>=s:Read("next"))
		s:Destroy()
	end
	do
		local s=fresh();local r=s.Runtime
		s:Run([=[window.order="";const b=document.getElementById("button");
b.addEventListener("click",function(){window.order+="L";queueMicrotask(function(){window.order+="M";});});
b.addEventListener("click",function(){window.order+="R";});
b.click();window.order+="S";]=])
		assert(s:Read("order")=="LRSM","Nested synchronous event dispatch keeps microtasks behind the outer script")
		s.Events:Emit(Node.findById(s.Document,"button"),"click")
		assert(s:Read("order")=="LRSMLMR","Native listener callbacks checkpoint when the JS stack empties")
		s:Run('queueMicrotask(function(){missingFunction();});queueMicrotask(function(){window.recovered=1;});setTimeout(function(){missingFunction();},0);setTimeout(function(){window.recovered=2;},0);')
		assert(s:Read("recovered")==1);r:PumpTasks();assert(s:Read("recovered")==2 and #s.Reports==2,"A throwing callback cannot poison later work")
		s:Run('queueMicrotask(null);');s:Run('requestAnimationFrame(1);');assert(#s.Reports==4)
		s:Run('function spin(){queueMicrotask(spin);}queueMicrotask(spin);')
		assert(#s.Reports==5 and s.Reports[5]:find("checkpoint budget",1,true) and #r.EventLoop.Microtasks==0,"Self-queuing microtasks are bounded and released")
		s:Run('queueMicrotask(function(){window.afterBudget=1;});');assert(s:Read("afterBudget")==1)
		s:Run('setTimeout(function(){while(true){}},0);setTimeout(function(){window.afterTimerError=1;},0);')
		r:PumpTasks();r:PumpTasks();assert(s:Read("afterTimerError")==1 and #s.Reports==6)
		s:Run('setTimeout(function(){window.dead=1;},0);requestAnimationFrame(function(){window.dead=2;});')
		s:Destroy();assert(r:PumpTasks()==0 and r:PumpFrame()==0 and r.EventLoop.TimerCount==0 and r.EventLoop.FrameCount==0,"Disposal clears callbacks and prevents further execution")
	end
	-- Real HTMLScripts/RenderTree + deterministic Roblox clock substitutes.
	local function signal()
		local entries={};local s={}
		function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function s:Fire()for _,e in table.clone(entries) do if e[1].Connected then e[2]() end end end
		function s:Count()local n=0;for _,e in entries do if e[1].Connected then n+=1 end end;return n end
		return s
	end
	local time,jobs=0,{}
	local tasks={delay=function(wait,fn)local job={Due=time+wait,Call=fn,Active=true};table.insert(jobs,job);return job end,cancel=function(job)job.Active=false end}
	local frames=signal();local services={Clock=function()return time end,Task=tasks,RunService={RenderStepped=frames}}
	local function activeJobs()local n=0;for _,job in jobs do if job.Active then n+=1 end end;return n end
	local function advance(seconds)
		time+=seconds
		-- One host wake: newly armed callbacks are future host tasks.
		for _,job in table.clone(jobs) do if job.Active and job.Due<=time then job.Active=false;job.Call() end end
	end
	local root={AbsoluteSize=Vector2.new(600,800),AbsolutePosition=Vector2.new(0,0),CanvasPosition=Vector2.new(0,0),Status="loading",Changed=signal()}
	function root:IsA(kind)return kind=="ScrollingFrame"end
	function root:GetAttribute()return self.Status end
	function root:GetAttributeChangedSignal()return self.Changed end
	function root:SetStatus(status)self.Status=status;self.Changed:Fire()end
	local factory={create=function(_,parent,props)local g=table.clone(props);g.Parent=parent;function g:Destroy()self.Destroyed=true;self.Parent=nil end;return g end}
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text) or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local document=Parser.parseDocument(demoHTML)
	local tree=loadRenderTree(factory).build(document,root,error,function(font)return font end,nil,nil,nil,demoCSS)
	tree.ViewportHeight=800;layout.arrange(tree,600,0,0,function()return true end)
	local page={Alive=true,Document=document,Root=root,Events=Events.new(error),Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	page.FormModel=FormModel.new(document,tree.Controls,page.Events,function()end)
	function page:SetValue(node,value)self.FormModel:SetValue(self.FormModel:Resolve(node),value)end
	local layoutRequests,appliedFrames=0,0
	local function apply()
		local needed,items=page.JavaScriptRuntime:Flush()
		if needed then
			local pending={}
			for item,reason in items or {} do if not tree:CanKeepTextLayout(item,overrides["Layout/WordLayout"].arrange,function()return true end) then pending[item]=reason end end
			if next(pending) then layoutRequests+=1;Dirty.begin(tree,pending);layout.arrange(tree,600,0,0,function()return true end);Dirty.finish(tree,true) end
		end
	end
	local realm=HTMLScripts.start(page,tree,function()end,error,{JavaScriptServices=services},function()appliedFrames+=1;apply()end)
	apply();local function read(id)return Node.textContent(Node.findById(document,id))end
	local function click(id)page.FormModel:Activate(page.FormModel:Resolve(id));apply()end
	assert(activeJobs()==0 and frames:Count()==0,"An idle page has no timer/frame work")
	click("timeout-start");assert(activeJobs()==0,"Timers wait for initial layout readiness")
	root:SetStatus("ready");assert(activeJobs()==1)
	advance(.5);assert(read("timeout-result")=="Die Meldung ist geplant …")
	advance(.51);apply();assert(read("timeout-result")=="Eine Sekunde später: Hallo!" and activeJobs()==0)
	click("timeout-start");click("timeout-start");assert(activeJobs()==1,"Only one native wake even when a timer is replaced")
	click("timeout-cancel");advance(2);assert(read("timeout-result")=="Die Meldung wurde abgebrochen." and activeJobs()==0)
	click("interval-start");click("interval-start");assert(realm.EventLoop.TimerCount==1)
	advance(.5);apply();advance(.5);apply();assert(read("timer-count")=="2")
	click("interval-stop");advance(2);assert(read("timer-count")=="2" and activeJobs()==0)
	click("queue-test");assert(read("queue-result")=="Start → synchron → Microtask → weitere Microtask")
	advance(0);apply();assert(read("queue-result")=="Start → synchron → Microtask → weitere Microtask → Timer")
	click("promise-order");assert(read("promise-order-result")=="Start → synchron → then(7) → Microtask → then(8)")
	click("promise-start");assert(read("promise-result")=="Start → Executor → synchron" and activeJobs()==1)
	advance(.75);apply();assert(read("promise-result")=="Start → Executor → synchron → Wert: 7 → Ergebnis: 14 → Aufgeräumt" and activeJobs()==0)
	click("promise-fail");advance(.75);apply();assert(read("promise-result")=="Start → Executor → synchron → Abgefangen: Beispiel-Ablehnung → Aufgeräumt")
	click("promise-throw");advance(.75);apply();assert(read("promise-result")=="Start → Executor → synchron → Abgefangen: Beispiel-Fehler im Handler → Aufgeräumt")
	click("promise-start");click("promise-start");assert(activeJobs()==1,"A restart cancels the old timer and settles the old promise without changing the current run")
	click("promise-cancel");advance(1);apply();assert(read("promise-result")=="Abgebrochen. Kein späterer Schritt verändert diese Meldung." and activeJobs()==0)
	click("frame-start");local baseline=layoutRequests
	assert(frames:Count()==1);frames:Fire();advance(1);frames:Fire()
	assert(layoutRequests==baseline and appliedFrames==2,"Transform frames apply in the render callback without requesting layout")
	local resolve,refresh,canvas=Style.resolve,Dirty.refresh,CanvasBackground.apply
	local resolves,refreshes,canvases,paintDraws=0,0,0,0
	Style.resolve=function(...)resolves+=1;return resolve(...)end
	Dirty.refresh=function(...)refreshes+=1;return refresh(...)end
	CanvasBackground.apply=function(...)canvases+=1;return canvas(...)end
	local frameBox=tree.NodeBoxes[Node.findById(document,"frame-box")]
	frameBox.BackgroundRenderer={Draw=function()paintDraws+=1 end}
	for _=1,10 do advance(.01);frames:Fire() end
	Style.resolve,Dirty.refresh,CanvasBackground.apply=resolve,refresh,canvas
	frameBox.BackgroundRenderer=nil
	assert(resolves<=10,"Each transform frame may resolve only the animated element; got "..resolves)
	assert(refreshes==0 and canvases==0 and paintDraws==0,"Transform frames keep layout ownership, canvas and background paint untouched")
	local box=tree.NodeBoxes[Node.findById(document,"frame-box")]
	local x=box.Gui.Position[1];assert(x>60,"Frame transform reaches the live GUI")
	local remaining=realm.EventLoop.FrameCount
	click("interval-start");tree.LayoutInProgress=true;root:SetStatus("layout")
	assert(activeJobs()==0 and frames:Count()==0,"A yielding layout disconnects driver work without deleting queued tasks")
	advance(1);assert(realm.EventLoop.FrameCount==remaining and box.Gui.Position[1]==x)
	tree.LayoutInProgress=false;root:SetStatus("ready");assert(frames:Count()==1 and activeJobs()==1)
	frames:Fire();apply();assert(read("frame-result")=="Am Ziel. Die Animation ist beendet." and frames:Count()==0)
	click("frame-start");frames:Fire();advance(.25);frames:Fire();click("frame-stop")
	x=box.Gui.Position[1];advance(1);frames:Fire();assert(box.Gui.Position[1]==x and frames:Count()==0,"Cancelled animation does not move again")
	click('interval-stop');assert(activeJobs()==0)
	realm:Run("window.idleOrder='';requestIdleCallback(()=>{window.idleOrder+='A';requestIdleCallback(()=>{window.idleOrder+='C';});});requestIdleCallback(()=>{window.idleOrder+='B';});")
	assert(activeJobs()==1 and frames:Count()==0,'Idle requests share the existing one-shot clock without a frame driver')
	advance(0);assert(realm.Window.Get('idleOrder')=='A'and activeJobs()==1)
	advance(0);assert(realm.Window.Get('idleOrder')=='A','A recursively scheduled idle callback cannot drain the same host turn')
	advance(.002);assert(realm.Window.Get('idleOrder')=='AB'and activeJobs()==1)
	advance(.002);assert(realm.Window.Get('idleOrder')=='ABC'and activeJobs()==0 and frames:Count()==0,'Idle completion disconnects every native wake')
	tree.LayoutInProgress=true;root:SetStatus('layout')
	realm:Run("requestIdleCallback(()=>{window.idleOrder+='D';});")
	assert(activeJobs()==0,'A yielding layout parks idle work')
	tree.LayoutInProgress=false;root:SetStatus('ready');assert(activeJobs()==1)
	advance(.002);assert(realm.Window.Get('idleOrder')=='ABCD'and activeJobs()==0)
	realm:Run("var removedIdle=requestIdleCallback(()=>{window.idleOrder+='BAD';},{timeout:30});cancelIdleCallback(removedIdle);")
	assert(activeJobs()==0,'Canceling an idle request also removes its delayed timeout and native wake')
	click('interval-start')
	click("frame-start");assert(activeJobs()==1 and frames:Count()==1)
	page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]() end
	assert(activeJobs()==0 and frames:Count()==0 and root.Changed:Count()==0,"Page teardown releases timers, frame connection and readiness listener")
	advance(5);frames:Fire();page.FormModel:Destroy();page.Events:Destroy()
	print("JavaScript clock: task/microtask order, timer conversion/nesting/args/cancellation, frame snapshots/time, bounded errors, local paint, layout exclusion, idle and page cleanup passed")
end
