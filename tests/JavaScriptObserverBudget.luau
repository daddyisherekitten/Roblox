--!strict
-- Direct native rendering publication is a realm entry just like a script or
-- native input event. No production execution limits are raised in this test.
return function(Parser,Node,Runtime,Events)
	local function fixture()
		local document=Parser.parseDocument('<html><body><button id="button">Click</button><div id="target">Box</div></body></html>')
		local target,button=Node.findById(document,"target"),Node.findById(document,"button")
		local diagnostics,resumes={},{};local events=Events.new(error)
		local style={Display="block",Position="static",Padding={0,0,0,0},BorderSizes={0,0,0,0}}
		local box={Node=target,Style=style,LayoutX=20,LayoutY=30,OuterWidth=100,OuterHeight=40,ContentWidth=100,ContentHeight=40,Children={}}
		local tree={NodeBoxes={[target]=box},NodeStyles={[target]=style}}
		local realm;local suspend=false
		realm=Runtime.new(document,{Events=events,URL="https://example.test/page",Schedule=function()end,
			Diagnostic=function(value)table.insert(diagnostics,value)end,ResumeEntry=function(thread)table.insert(resumes,thread)end,
			ApplyChanges=function(changes)
				for node in changes do if node==target then local width=tonumber((node.Attributes.style or ""):match("width:%s*(%d+)px"));if width then box.OuterWidth,box.ContentWidth=width,width end end end
				return false
			end,
			GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return {Width=800,Height=600}end,
				HasPending=function()return realm:HasPending()end,
				Flush=function()if suspend then coroutine.yield("native-observer-measurement")end;realm:Flush()end}})
		local function run(source)local succeeded=realm:Run(source);assert(succeeded,table.concat(diagnostics," | "))end
		local function value(name)return realm.VM.Global.Bindings[name].Value end
		local function healthy()assert(#diagnostics==0,table.concat(diagnostics," | "))end
		local function budgetFailure()assert(#diagnostics>0 and table.concat(diagnostics," | "):find("instruction budget exceeded",1,true),"Expected the shared production instruction budget to bound observer work")end
		local function destroy()realm:Destroy();events:Destroy()end
		return {Realm=realm,Events=events,Button=button,Box=box,Run=run,Value=value,Healthy=healthy,BudgetFailure=budgetFailure,
			Diagnostics=diagnostics,Resumes=resumes,SetSuspended=function(value)suspend=value end,Destroy=destroy}
	end
	local normal=fixture();local realm=normal.Realm
	normal.Run([=[
let scriptTotal=0;let microtaskTotal=0;
queueMicrotask(()=>{for(let index=0;index<1000;index++){microtaskTotal+=index;}});
for(let index=0;index<1000;index++){scriptTotal+=index;}
]=])
	assert(normal.Value("scriptTotal")==499500 and normal.Value("microtaskTotal")==499500,"Independent post-script microtask jobs retain their own execution budgets")
	normal.Run([=[
const target=document.getElementById('target');const button=document.getElementById('button');
let resized=0;let clicked=0;let warmup=0;
const resize=new ResizeObserver(()=>{resized++;});resize.observe(target);
button.onclick=()=>{for(let index=0;index<20;index++){warmup+=index;}clicked++;};
for(let index=0;index<1000;index++){warmup+=index;}
]=])
	realm:PumpTasks();assert(normal.Value("resized")==1)
	for _=1,40 do normal.Events:Emit(normal.Button,"click",{})end
	assert(normal.Value("clicked")==40);normal.Healthy()
	for _=1,10000 do realm:AfterLayout()end
	normal.Healthy();assert(normal.Value("resized")==1 and realm.VM.Steps<128 and not realm:IsExecuting(),"Unchanged direct host rounds have fresh budgets and do not invent resize entries")
	local succeeded=realm:Run("while(true){}")
	assert(not succeeded);normal.BudgetFailure();table.clear(normal.Diagnostics)
	normal.Events:Emit(normal.Button,"click",{});normal.Healthy()
	assert(normal.Value("clicked")==41,"Native event construction and dispatch start fresh after an exhausted script")
	succeeded=realm:Run("while(true){}");assert(not succeeded);normal.BudgetFailure();table.clear(normal.Diagnostics)
	realm:AfterLayout();normal.Healthy();assert(realm.VM.Steps<128,"Exhausted script work does not poison the next host entry")
	normal.Box.OuterWidth,normal.Box.ContentWidth=140,140;realm:AfterLayout()
	assert(normal.Value("resized")==2);normal.Healthy()
	-- A native measurement suspension holds the same input gate as script-driven
	-- geometry. The queued native event cannot modify JS state during that pause.
	normal.Run("target.style.width='160px';");assert(realm:HasPending());normal.SetSuspended(true)
	local layout=coroutine.create(function()realm:AfterLayout()end)
	local ok,reason=coroutine.resume(layout)
	assert(ok and reason=="native-observer-measurement" and realm:IsExecuting(),"Direct observer delivery owns its realm entry during native measurement")
	local inputDone=false;local input=coroutine.create(function()normal.Events:Emit(normal.Button,"click",{});inputDone=true end)
	assert(coroutine.resume(input) and coroutine.status(input)=="suspended" and not inputDone and normal.Value("clicked")==41,"Native input waits for suspended observer publication")
	normal.SetSuspended(false);assert(coroutine.resume(layout) and coroutine.status(layout)=="dead" and #normal.Resumes==1)
	assert(normal.Value("resized")==3 and not inputDone)
	assert(coroutine.resume(table.remove(normal.Resumes,1)) and inputDone and normal.Value("clicked")==42)
	for _=1,1000 do normal.Box.ContentWidth+=1;normal.Box.OuterWidth+=1;realm:AfterLayout()end
	assert(normal.Value("resized")==1003,"Changed independent publications each deliver exactly once without accumulating callback budgets")
	normal.Healthy();normal.Destroy()
	local ordered=fixture()
	ordered.Run([=[
const target=document.getElementById('target');let trace=[];
const first=new ResizeObserver(()=>{trace.push('A');queueMicrotask(()=>trace.push('microtask'));});
const second=new ResizeObserver(()=>trace.push('B'));first.observe(target);second.observe(target);
]=])
	ordered.Realm:PumpTasks();assert(table.concat(ordered.Value("trace").Items,",")=="A,microtask,B","Initially queued native resize callbacks checkpoint microtasks between observers")
	ordered.Run("trace=[];");ordered.Box.ContentWidth+=1;ordered.Box.OuterWidth+=1
	ordered.Realm:AfterLayout();assert(table.concat(ordered.Value("trace").Items,",")=="A,microtask,B","Direct host resize callbacks checkpoint microtasks between observers")
	ordered.Healthy();ordered.Destroy()
	local dispatchOrder=fixture()
	dispatchOrder.Run([=[
const target=document.getElementById('target');const button=document.getElementById('button');let trace=[];
button.onclick=()=>{trace.push('event');queueMicrotask(()=>trace.push('event-microtask'));};
const first=new ResizeObserver(()=>{
 trace.push('A');queueMicrotask(()=>trace.push('callback-microtask'));
 button.dispatchEvent(new Event('click'));trace.push('A-end');
});
const second=new ResizeObserver(()=>trace.push('B'));first.observe(target);second.observe(target);
]=])
	local dispatchExpected="A,event,A-end,callback-microtask,event-microtask,B"
	dispatchOrder.Realm:PumpTasks();assert(table.concat(dispatchOrder.Value("trace").Items,",")==dispatchExpected,"Authored nested dispatch returns to the full observer callback before checkpointing")
	dispatchOrder.Run("trace=[];");dispatchOrder.Box.ContentWidth+=1;dispatchOrder.Box.OuterWidth+=1
	dispatchOrder.Realm:AfterLayout();assert(table.concat(dispatchOrder.Value("trace").Items,",")==dispatchExpected,"Direct publication preserves the same authored dispatch and callback checkpoint order")
	dispatchOrder.Healthy();dispatchOrder.Destroy()
	-- Each callback is individually finite. Together they must share the one
	-- rendering opportunity's budget; resetting at every callback permits an
	-- unbounded amount of synchronous work to escape the outer host limit.
	local shared=fixture()
	shared.Run([=[
const target=document.getElementById('target');let completed=0;const observers=[];
for(let index=0;index<8;index++){
 const observer=new ResizeObserver(()=>{let total=0;for(let turn=0;turn<1000;turn++){total+=turn;}if(total===499500)completed++;});
 observers.push(observer);observer.observe(target);
}
]=])
	shared.Realm:AfterLayout();shared.BudgetFailure()
	assert(shared.Value("completed")>0 and shared.Value("completed")<8,"Nested observer callbacks cannot reset the outer rendering budget")
	table.clear(shared.Diagnostics);shared.Run("for(const observer of observers)observer.disconnect();let recovered=true;")
	shared.Realm:AfterLayout();shared.Healthy();assert(shared.Value("recovered"));shared.Destroy()
	local nested=fixture()
	nested.Run([=[
const target=document.getElementById('target');const button=document.getElementById('button');let entered=0;let escaped=0;
button.onclick=()=>{while(true){}};
const observer=new ResizeObserver(()=>{entered++;button.dispatchEvent(new Event('click'));escaped++;});observer.observe(target);
]=])
	nested.Realm:AfterLayout();nested.BudgetFailure()
	assert(nested.Value("entered")==1 and nested.Value("escaped")==0,"Endless synchronous events inside observer callbacks remain in the outer budget")
	table.clear(nested.Diagnostics);nested.Run("observer.disconnect();button.onclick=null;let recovered=true;")
	nested.Realm:AfterLayout();nested.Healthy();assert(nested.Value("recovered"));nested.Destroy()
	print("Observer execution budgets: repeated unchanged host rounds, real page work/input, recovery, suspended native measurement gate and shared nested callback/event limits passed")
end
