--!strict
-- Real realm bridges, including a host measurement that suspends its Lua task.
return function(Parser,Node,Runtime,VM,Events,ScriptGeometry)
	local document=Parser.parseDocument('<html><body><button id="button">Click</button><div id="target">Box</div></body></html>')
	local target=Node.findById(document,"target");local button=Node.findById(document,"button")
	local output,diagnostics,resumes={},{},{}
	local events=Events.new(error);local realm,flushes,suspend=nil,0,false
	local view={Width=800,Height=600,ClientWidth=790,ClientHeight=600,ScrollWidth=790,ScrollHeight=1000,ScrollX=0,ScrollY=0}
	local box={Node=target,Style={Display="block",Position="static",Padding={0,0,0,0},BorderSizes={0,0,0,0}},
		LayoutX=20,LayoutY=30,OuterWidth=100,OuterHeight=40,ContentWidth=100,ContentHeight=40,Children={}}
	local tree={NodeBoxes={[target]=box},NodeStyles={[target]=box.Style}}
	local function apply(changes)
		for node in changes do
			if node==target then local width=tonumber((node.Attributes.style or ""):match("width:%s*(%d+)px"));if width then box.OuterWidth,box.ContentWidth=width,width end end
		end
		return false
	end
	realm=Runtime.new(document,{Events=events,URL="https://example.test/page",Schedule=function()end,
		Console=function(_,value)table.insert(output,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end,
		ApplyChanges=apply,ResumeEntry=function(thread)table.insert(resumes,thread)end,
		GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return view end,
			HasPending=function()return realm:HasPending()end,
			Flush=function()
				flushes+=1
				if suspend then coroutine.yield("native-measurement")end
				realm:Flush()
			end}})
	realm:Run([=[
const button=document.getElementById('button');
const target=document.getElementById('target');
button.onclick=function(event){
  console.log(event instanceof MouseEvent,event.clientX,event.isTrusted);
  event.preventDefault();queueMicrotask(()=>console.log('microtask'));
};
console.log(button.onclick===button.onclick);
]=])
	local clicked=events:Emit(button,"click",{clientX=12})
	assert(clicked.DefaultPrevented and output[1]=="true" and output[2]=="true 12 true" and output[3]=="microtask",
		"Handler properties work before addEventListener and native cancellation survives realm dispatch")
	-- Web IDL operation functions substitute their own realm's global object
	-- for null/undefined this, including strict/extracted EventTarget methods.
	local globalEventsOK,globalEventsError=realm:Run([=[
globalThis.globalEventTrace=[];
function globalEventListener(event){if(this!==window||event.currentTarget!==window||event.target!==window)throw Error('Global receiver');globalEventTrace.push(event.type);event.preventDefault();}
addEventListener('bare-target',globalEventListener);
if(dispatchEvent(new Event('bare-target',{cancelable:true}))!==false)throw Error('Bare dispatch result');
removeEventListener('bare-target',globalEventListener);
dispatchEvent(new Event('bare-target'));
(function(){'use strict';
 const add=window.addEventListener,remove=window.removeEventListener,dispatch=window.dispatchEvent;
 add('strict-target',globalEventListener);
 dispatch(new Event('strict-target'));
 remove('strict-target',globalEventListener);
 dispatch(new Event('strict-target'));
 for(const receiver of [null,undefined]){
  add.call(receiver,'nullable-target',globalEventListener);
  dispatch.call(receiver,new Event('nullable-target'));
  remove.call(receiver,'nullable-target',globalEventListener);
  dispatch.call(receiver,new Event('nullable-target'));
 }
 for(const receiver of [{},0,'text']){
  for(const name of ['addEventListener','removeEventListener','dispatchEvent']){
   let rejected=false;try{if(name==='dispatchEvent')window[name].call(receiver,new Event('bad'));else window[name].call(receiver,'bad',null);}catch(error){rejected=error.name==='TypeError';}
   if(!rejected)throw Error('Invalid EventTarget receiver '+name);
  }
 }
 const target=new EventTarget();let ordinary=0;
 const listener=function(event){if(this!==target||event.target!==target)throw Error('Ordinary receiver');ordinary++;};
 add.call(target,'ordinary-target',listener);dispatch.call(target,new Event('ordinary-target'));remove.call(target,'ordinary-target',listener);dispatch.call(target,new Event('ordinary-target'));
 if(ordinary!==1)throw Error('Ordinary branded EventTarget');
 const fromTarget=target.addEventListener;fromTarget('prototype-global',globalEventListener);
 dispatch(new Event('prototype-global'));remove('prototype-global',globalEventListener);
 let eventBrand=false;try{Event.prototype.preventDefault.call(null);}catch(error){eventBrand=error.name==='TypeError';}
 if(!eventBrand)throw Error('Event operations must keep their own brand');
})();
if(globalEventTrace.join('|')!=='bare-target|strict-target|nullable-target|nullable-target|prototype-global')throw Error('Global target registrations/removals');
]=])
	assert(globalEventsOK,tostring(globalEventsError))
	realm:Run([=[
target.style.width='123px';
console.log(target.getBoundingClientRect().width,target.offsetWidth,innerWidth,window.innerWidth);
target.style[Symbol.for('private')]='value';console.log(target.style[Symbol.for('private')]);
]=])
	assert(flushes==1 and output[4]=="123 123 800 800" and output[5]=="value","Geometry flushes dirty writes once; bare and Window globals agree")
	view.Width=640
	realm:Run('console.log(innerWidth,window.innerWidth);innerWidth=321;console.log(innerWidth,window.innerWidth);')
	assert(output[6]=="640 640" and output[7]=="321 321","Replaceable viewport globals retain their assigned value")
	-- A second physical host task must wait, while synchronous calls originating
	-- inside the current JS stack continue to work normally.
	suspend=true
	local reading=coroutine.create(function()realm:Run("target.style.width='140px';console.log('read',target.offsetWidth);")end)
	local ok,reason=coroutine.resume(reading);assert(ok and reason=="native-measurement" and realm:IsExecuting())
	local queuedClick
	local input=coroutine.create(function()queuedClick=events:Emit(button,"click",{clientX=13})end)
	assert(coroutine.resume(input) and coroutine.status(input)=="suspended" and queuedClick==nil,
		"Input does not enter a JS realm while native text measurement has suspended its active stack")
	suspend=false;assert(coroutine.resume(reading) and coroutine.status(reading)=="dead" and #resumes==1)
	assert(output[8]=="read 140" and queuedClick==nil)
	local resumed=table.remove(resumes,1);assert(coroutine.resume(resumed))
	assert(queuedClick.DefaultPrevented and output[9]=="true 13 true" and output[10]=="microtask")
	suspend=true
	local asyncRead=coroutine.create(function()realm:Run([=[
async function measure(){target.style.width='145px';return target.getBoundingClientRect().width;}
measure().then(width=>console.log('async-read',width));
]=])end)
	local asyncOK,asyncReason=coroutine.resume(asyncRead)
	assert(asyncOK and asyncReason=="native-measurement" and realm:IsExecuting(),"Async JS keeps synchronous geometry reads in the owning host entry")
	suspend=false;assert(coroutine.resume(asyncRead) and coroutine.status(asyncRead)=="dead")
	assert(output[11]=="async-read 145","A native measurement yield does not reject or lose an async function continuation")
	-- The gate also releases blocked input when its page disappears.
	suspend=true
	local disposedRead=coroutine.create(function()realm:Run("target.style.width='150px';console.log(target.offsetWidth);")end)
	assert(coroutine.resume(disposedRead))
	local disposedInput=coroutine.create(function()events:Emit(button,"click",{clientX=14})end)
	assert(coroutine.resume(disposedInput) and coroutine.status(disposedInput)=="suspended")
	local prior=#output;realm:Destroy();assert(#resumes==1)
	assert(coroutine.resume(table.remove(resumes,1)) and #output==prior)
	suspend=false;assert(coroutine.resume(disposedRead) and #output==prior)
	assert(#diagnostics==0,table.concat(diagnostics,"\n"));events:Destroy()
	local observerOutput={}
	box.ContentWidth,box.OuterWidth=150,150
	local observerEvents=Events.new(error)
	local observerRealm=Runtime.new(document,{Events=observerEvents,URL="https://example.test/page",Schedule=function()end,
		Console=function(_,value)table.insert(observerOutput,value)end,Diagnostic=error,ApplyChanges=apply,
		GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return view end}})
	observerRealm:Run([=[
const observed=document.getElementById('target');
const resizeObserver=new ResizeObserver(entries=>console.log('resize',entries[0].contentRect.width));
resizeObserver.observe(observed);
]=])
	assert(observerRealm.EventLoop.TaskCount==1,"Initial observations coalesce one render notification")
	observerRealm:PumpTasks()
	assert(observerOutput[1]=="resize 150" and observerRealm.EventLoop.TaskCount==0,
		"The real runtime delivers observers without endlessly requeueing its active task")
	observerRealm:Run('resizeObserver.observe(observed);resizeObserver.observe(observed);')
	observerRealm:PumpTasks()
	assert(#observerOutput==1 and observerRealm.EventLoop.TaskCount==0,"Unchanged observation produces no extra notification")
	box.ContentWidth,box.OuterWidth=160,160
	observerRealm:AfterLayout();assert(observerOutput[2]=="resize 160")
	observerRealm:Destroy();observerEvents:Destroy()
	-- A completed tween can have queued its task before a newer scroll cancels
	-- it. The old task must not emit scrollend for the replacement operation.
	local tasks,tweens,scrollEnds,resolved={},{},0,0
	local gui={CanvasPosition=Vector2.new(0,0)}
	local fakePage={Root=gui,Document={},Alive=true,Events={Emit=function()scrollEnds+=1 end}}
	local fakeRealm={Alive=true,EventLoop={QueueTask=function(_,callback)table.insert(tasks,callback)end},
		Promises={CreateCapability=function()return {},function()resolved+=1 end end}}
	local service={Create=function(_,_,_,goals)
		local callbacks={};local tween={Goal=goals.CanvasPosition,Completed={Connect=function(_,callback)
			local connected=true;table.insert(callbacks,function()if connected then callback()end end)
			return {Disconnect=function()connected=false end}
		end}}
		function tween:Play()end
		function tween:Cancel()for _,callback in callbacks do callback()end end
		function tween:Finish()for _,callback in callbacks do callback()end end
		table.insert(tweens,tween);return tween
	end}
	local adapter=ScriptGeometry.new(fakePage,{NodeBoxes={}},fakeRealm,{TweenService=service})
	adapter.Scroll(nil,0,100,"smooth");tweens[1]:Finish();assert(#tasks==1)
	adapter.Scroll(nil,0,200,"smooth");table.remove(tasks,1)()
	assert(resolved==1 and scrollEnds==0,"Aborted tween completion cannot finish the next scroll")
	tweens[2]:Finish();table.remove(tasks,1)();assert(resolved==2 and scrollEnds==1)
	adapter.Scroll(nil,0,300,"smooth");adapter.Destroy();tweens[3]:Finish()
	assert(#tasks==0 and resolved==2,"Disposed scroll adapters never resume promises or queue new events")
	print("JavaScript host integration: handler identity, native events/defaults, geometry flush/globals, concurrent host tasks and scroll cancellation/lifetime passed")
end
