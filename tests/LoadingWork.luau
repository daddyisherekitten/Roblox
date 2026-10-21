--!strict
-- Deterministic scheduler/clock checks, not a native FPS benchmark.
return function(Context,loadContext,Parser,DOM,Stylesheet,Style,loadRenderTree,Runtime)
	local time,waits=0,0
	local gate={Owners={}}
	local clock=function()time+=.00004;return time end
	local tasks={wait=function()waits+=1;time+=.016;gate.Deadline=nil;coroutine.yield('loading-slice')end}
	local function drive(fn)
		local thread=coroutine.create(fn);local rounds=0
		while coroutine.status(thread)~='dead'do
			rounds+=1;assert(rounds<20000,'Loading did not settle')
			local ok,value=coroutine.resume(thread);assert(ok,tostring(value))
			if coroutine.status(thread)~='dead'then assert(value=='loading-slice','CPU pauses must remain host suspensions')end
		end
	end
	local services={Task=tasks,Clock=clock,FrameGate=gate}
	local work=Context.new(2,services)
	local nestedChecks=0
	Context.with(function()nestedChecks+=1 end,function()
		Context.checkpoint()
		assert(not pcall(function()Context.with(function()error('inner')end,Context.checkpoint)end))
		Context.checkpoint()
		Context.with(nil,Context.checkpoint)
	end)
	Context.checkpoint();assert(nestedChecks==2 and waits==0,'Scopes restore on errors and can be disabled locally')
	local html={'<html><head><title>Loading</title><style>.row {padding: 4px;color:#123456} .row em {font-size:18px}</style></head><body>'}
	for i=1,160 do table.insert(html,'<p class="row" id="r'..i..'">Row '..i..' <em>same pixels</em></p>')end
	table.insert(html,'</body></html>');html=table.concat(html)
	local renderer=loadRenderTree({create=function(_,_,props)return table.clone(props)end})
	local function build()
		local document=Parser.parseDocument(html)
		local tree=renderer.build(document,{},error,function(font)return font end)
		return document,tree
	end
	local baseline,baselineTree=build();local document,tree
	drive(function()document,tree=work:Run(build)end)
	assert(waits>0 and document.NodeCount==baseline.NodeCount and DOM.textContent(document)==DOM.textContent(baseline),'Parsing yields without changing the DOM')
	local function geometrySummary(value)
		local pending={value};local out={}
		while #pending>0 do
			local box=table.remove(pending)
			table.insert(out,tostring(box.Kind)..':'..tostring(box.Node and box.Node.Name)..':'..tostring(box.Style and box.Style.FontSize)..':'..tostring(box.Style and box.Style.Padding[1]))
			for i=#(box.Children or{}),1,-1 do table.insert(pending,box.Children[i])end
		end
		return table.concat(out,'|')
	end
	assert(geometrySummary(tree)==geometrySummary(baselineTree),'CSS and render-tree construction preserve every box in order')
	tree.VisualEffects:Destroy();baselineTree.VisualEffects:Destroy()
	assert(work.Runs==1 and work.WaitMS>0 and work.ActiveMS>0 and work.MaxSliceMS<3,'One shared scope owns the nested parsing/build slices')
	work:Finish();assert(next(gate.Owners)==nil and services.Task==tasks,'Finishing releases gate ownership without modifying caller services')
	local before=waits;Context.checkpoint();work:Run(build);assert(waits==before,'Completed leases do not make ordinary parsing asynchronous')
	-- One large declaration block must yield as well as a tree of small nodes.
	local declarations=string.rep('color:blue;padding:1em;border:1px solid red;',100)..'color:green'
	local compiled=Style.compile(declarations);local scoped,computed
	local cssLease=Context.new(2,{Task=tasks,Clock=clock,FrameGate=gate});before=waits
	drive(function()scoped=cssLease:Run(Style.compile,declarations)end)
	assert(waits>before and #scoped.Normal==#compiled.Normal,'CSS compilation yields inside a single declaration block')
	local element={Kind='Element',Name='div',Attributes={},Children={}}
	local parent={FontSize=20,Font=Enum.Font.Arial,Color=Color3.new(0,0,0)}
	local expectedStyle=Style.resolve(element,parent,error,false,compiled);before=waits
	drive(function()computed=cssLease:Run(Style.resolve,element,parent,error,false,scoped)end)
	assert(waits>before and computed.Color==expectedStyle.Color and computed.Padding[1]==20 and computed.Border==expectedStyle.Border,
		'Large matched cascades yield without changing the computed style')
	cssLease:Finish();assert(next(gate.Owners)==nil)

	-- Two loaders that start in one frame consume the same remaining allowance.
	time=0;local shared={Owners={}};local sharedWaits=0
	local sharedTasks={wait=function()sharedWaits+=1;time+=.016;shared.Deadline=nil end}
	local a=Context.new(2,{Task=sharedTasks,Clock=function()return time end,FrameGate=shared})
	local b=Context.new(2,{Task=sharedTasks,Clock=function()return time end,FrameGate=shared})
	a:Run(function()time=.0015;Context.checkpoint()end)
	b:Run(function()time=.0021;Context.checkpoint()end)
	assert(sharedWaits==1,'A new loader cannot reset the frame deadline of an existing loader')
	a:Finish();b:Finish();assert(next(shared.Owners)==nil)

	local source=[=[
console.log('start');
async function read(){let total=0;for(let i=0;i<160;i++)total+=i;await Promise.resolve();for(let i=0;i<160;i++)total+=i;return total;}
read().then(value=>console.log('async',value));
function* rows(){let total=0;for(let i=0;i<160;i++)total+=i;yield total;for(let i=0;i<160;i++)total+=i;return total;}
const iterator=rows(),first=iterator.next(),last=iterator.next();console.log('generator',first.value,last.value,last.done);
queueMicrotask(()=>console.log('microtask'));console.log('end');
]=]
	local function realm(lease,output,diagnostics)
		return Runtime.new(Parser.parseDocument('<html><body></body></html>'),{LoadingWork=lease,Schedule=function()end,
			Console=function(_,value)table.insert(output,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
	end
	local expected,errors={},{};local normal=realm(nil,expected,errors);normal:Run(source);assert(#errors==0);normal:Destroy()
	local output,diagnostics={},{};local startup=Context.new(2,{Task=tasks,Clock=clock,FrameGate=gate});local runtime
	local initializationWaits=waits
	drive(function()runtime=startup:Run(function()return realm(startup,output,diagnostics)end)end)
	assert(waits>initializationWaits,'Library/prototype installation shares the loading budget')
	local scriptWaits=waits;drive(function()startup:Run(function()runtime:Run(source)end)end)
	assert(waits>scriptWaits and #diagnostics==0,table.concat(diagnostics,'\n'))
	assert(table.concat(output,'|')==table.concat(expected,'|'),'Async/generator CPU pauses preserve promise and microtask ordering')
	startup:Finish();scriptWaits=waits;runtime:Run('let ordinary=0;for(let i=0;i<160;i++)ordinary+=i;');assert(waits==scriptWaits)
	runtime:Destroy()

	-- Cancelling during construction still wires and invokes the realm destructor.
	local alive=true;local cancelled;local cancelWaits=0;local abandoned
	cancelled=Context.new(2,{Clock=clock,Alive=function()return alive end,Task={wait=function()
		cancelWaits+=1;time+=.016;if cancelWaits==1 then alive=false;cancelled:Finish()end;coroutine.yield('loading-slice')
	end}})
	drive(function()
		local ok,message=pcall(function()cancelled:Run(function()
			abandoned=realm(cancelled,{},{});Context.checkpoint()
		end)end)
		assert(not ok and tostring(message):find('cancelled',1,true))
	end)
	assert(abandoned and not abandoned.Alive and cancelWaits>1,'A cancelled constructor finishes in slices and destroys its unpublished realm')

	-- Native gate is lazy and disconnects after its last page leaves.
	local callbacks={};local signal={Connect=function(_,fn)
		local connection={Connected=true};callbacks[connection]=fn
		function connection:Disconnect()self.Connected=false;callbacks[self]=nil end
		return connection
	end}
	local nativeTasks={wait=function()for _,fn in callbacks do fn()end end}
	local native=loadContext({GetService=function()return {Heartbeat=signal}end},nativeTasks,{clock=function()return time end})
	local first=native.new(2);local second=native.new(2);local count=0;for _ in callbacks do count+=1 end;assert(count==1)
	first:Finish();assert(next(callbacks)~=nil);second:Finish();assert(next(callbacks)==nil,'No heartbeat connection remains after loading')
	local remaining=native.new(2)
	remaining:Run(function()
		remaining:Finish();assert(next(callbacks)~=nil,'Presentation retains the gate of a currently suspended private job')
		time+=.003;native.checkpoint()
	end)
	assert(next(callbacks)==nil and remaining.Yields==1,'The final private job disconnects its gate as it returns')
	print('Loading work: cooperative DOM/CSS/GUI and JS initialization, shared frame deadlines, async/generator ordering, cancellation and idle cleanup passed')
end
