--!strict
-- Timing/normalization cases shared with build/web-animations-reference.html.
-- Frame, microtask and task queues are independently drained to verify order.
local function verifyShadowAnimationConnectivity(Parser,DOM,VM,Promises,WebAnimations)
 local function realm()
  local document=Parser.parseDocument('<!doctype html><body><main id="outer"><div id="open"></div><div id="closed"></div></main></body>')
  local vm,animations;local microtasks,tasks,frames={},{},{}
  local bridge=DOM.new(document,{Window={},ReadyState='complete',Changed=function()end,
   Step=function()vm.Step()end,
   AnimationMethod=function(node,key)return if animations then(if node.Kind=='Document'then animations:DocumentMethod(key)else animations:ElementMethod(node,key))else nil end})
  local globals={document=bridge.Document};vm=VM.new(globals);bridge.AttachVM(vm)
  bridge.AttachShadow(vm,{Enqueue=function(fn)table.insert(microtasks,fn)end})
  local promises=Promises.new({Enqueue=function(fn)table.insert(microtasks,fn)end,QueueTask=function(fn)table.insert(tasks,fn)end,
   Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key,receiver)return vm.Get(value,key,receiver)end,
   Construct=function(fn,args)return vm:Construct(fn,args)end,Iterator=vm.Iterator,Object=vm.Object,Array=vm.Array,Report=error})
  vm:Install(function()promises:Attach(vm)end)
  animations=vm:Install(function()return WebAnimations.install(vm,globals,{Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
   CreatePromise=function()return promises:CreateCapability()end,Now=function()return 0 end,
   RequestFrame=function(fn)table.insert(frames,fn);return #frames end,CancelFrame=function(id)frames[id]=nil end,
   QueueTask=function(fn)table.insert(tasks,fn)end,Apply=function()end,Release=function()end})end)
  local function run(source)vm:Run(source)end
  local function value(key)return vm.Global.Bindings[key].Value end
  return {VM=vm,Bridge=bridge,Animations=animations,Run=run,Value=value,Destroy=function()animations:Destroy();promises:Destroy();bridge:Destroy();vm:Destroy()end}
 end
 local first,second=realm(),realm()
 first.Run([=[
var outer=document.getElementById('outer'),openHost=document.getElementById('open'),closedHost=document.getElementById('closed');
var openRoot=openHost.attachShadow({mode:'open'}),closedRoot=closedHost.attachShadow({mode:'closed'});
var openTarget=document.createElement('i'),closedTarget=document.createElement('i');openRoot.append(openTarget);closedRoot.append(closedTarget);
var openAnimation=openTarget.animate([{opacity:0},{opacity:1}],{duration:1000,fill:'both'});
var closedAnimation=closedTarget.animate([{opacity:0},{opacity:1}],{duration:1000,fill:'both'});
var documentCount=document.getAnimations().length;
var ownLists=openTarget.getAnimations()[0]===openAnimation&&closedTarget.getAnimations()[0]===closedAnimation;
var lightScope=outer.getAnimations({subtree:true}).length===0&&openHost.getAnimations({subtree:true}).length===0;
]=])
 assert(first.Value('documentCount')==0,'Document.getAnimations keeps the light-tree scope and excludes both open and closed shadow targets, as native Chrome does')
 assert(first.Value('ownLists') and first.Value('lightScope'),'Element animation subtree queries keep their separate light-tree scope')
 first.Run("openHost.remove();var detached=document.getAnimations().length;")
 assert(first.Value('detached')==0,'Detached shadow targets stay outside document queries')
 first.Run("outer.append(openHost);var reconnected=document.getAnimations().length;")
 assert(first.Value('reconnected')==0,'Reconnected shadow targets retain their separate tree scope')
 second.VM.Global.Bindings.openHost={Value=first.Value('openHost')}
 second.Run('document.body.append(openHost);')
 first.Run('var adoptedAway=document.getAnimations().length;')
 assert(first.Value('adoptedAway')==0,'Adopted shadow targets remain outside original document light-tree queries')
 first.Run('outer.append(openHost);var adoptedBack=document.getAnimations().length;')
 assert(first.Value('adoptedBack')==0,'Adoption back does not cross the document query tree scope')
 first.Run([=[
openAnimation.finish();closedAnimation.finish();
var openCover=openTarget.animate([{opacity:0},{opacity:1}],{duration:1000,fill:'both'});
var closedCover=closedTarget.animate([{opacity:0},{opacity:1}],{duration:1000,fill:'both'});openCover.finish();closedCover.finish();
]=])
 first.Animations:Tick(0)
 first.Run("var replaced=openAnimation.replaceState==='removed'&&closedAnimation.replaceState==='removed';var coversActive=openCover.replaceState==='active'&&closedCover.replaceState==='active';")
 assert(first.Value('replaced') and first.Value('coversActive'),'Finished covered animations in connected open and closed shadow roots are replaceable, as native Chrome does')
 first.Run([=[
openHost.remove();var detachedFirst=openTarget.animate([{width:'1px'},{width:'2px'}],{duration:1000,fill:'both'});
var detachedCover=openTarget.animate([{width:'1px'},{width:'2px'}],{duration:1000,fill:'both'});detachedFirst.finish();detachedCover.finish();
]=])
 first.Animations:Tick(0)
 first.Run("var detachedActive=detachedFirst.replaceState==='active';outer.append(openHost);")
 assert(first.Value('detachedActive'),'A covered animation with detached shadow host is not replaceable')
 first.Animations:Tick(0)
 first.Run("var reconnectedRemoved=detachedFirst.replaceState==='removed';")
 assert(first.Value('reconnectedRemoved'),'Reconnecting the host restores replacement eligibility')
 first.Destroy();second.Destroy()
 print('Web Animations shadow replacement: open/closed, detached/reconnected, native document/element light-tree scopes passed; no cross-realm animation-registry transfer claimed')
end

return function(Parser,Node,DOM,VM,Events,HostEvents,Promises,WebAnimations,zeroFixtures,cssDOMFixtures)
	local document=Parser.parseDocument('<html><body><div id="target"><span id="child"></span></div></body></html>')
	local time=0;local microtasks,tasks,frames,reports,paint,releases={},{},{},{},{},{}
	local frameSequence=0;local vm,animations
	local bridge=DOM.new(document,{Events=Events.new(error),Window={},Changed=function()end,
		GetControl=function()return VM.Undefined end,SetControl=function()end,
		AnimationMethod=function(node,key)return if animations then (if node.Kind=="Document"then animations:DocumentMethod(key)else animations:ElementMethod(node,key))else nil end,
		AnimationGet=function(key)return animations and animations:DocumentGet(key)end,
		Get=function(value,key)return vm.Get(value,key)end,Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end})
	local globals={document=bridge.Document};vm=VM.new(globals,{MaxSteps=100000});bridge.AttachVM(vm)
	local promises=Promises.new({Enqueue=function(fn)table.insert(microtasks,fn)end,QueueTask=function(fn)table.insert(tasks,fn)end,
		Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key,receiver)return vm.Get(value,key,receiver)end,
		Construct=function(fn,args)return vm:Construct(fn,args)end,Iterator=vm.Iterator,Object=vm.Object,Array=vm.Array,Report=error})
	vm:Install(function()promises:Attach(vm)end)
	local host=vm:Install(function()return HostEvents.install(vm,globals,{Clock=function()return time end,Report=function(e)table.insert(reports,VM.string(e))end})end)
	animations=vm:Install(function()return WebAnimations.install(vm,globals,{HostEvents=host,Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
		CreatePromise=function()return promises:CreateCapability()end,Now=function()return time end,
		RequestFrame=function(callback)frameSequence+=1;frames[frameSequence]=callback;return frameSequence end,CancelFrame=function(id)frames[id]=nil end,
		QueueTask=function(callback)table.insert(tasks,callback)end,
		Apply=function(node,keyframes,timing,value,composite)paint[node]={Frames=keyframes,Timing=timing,Value=value,Composite=composite}end,
		Release=function(node,value)table.insert(releases,{Node=node,Value=value});paint[node]=nil end})end)
	local function get(value,key)return vm.Get(value,key)end
	local function set(value,key,v)return vm.Set(value,key,v,true)end
	local function call(value,key,...)return vm:Call(get(value,key),{...},value)end
	local function construct(name,...)return vm:Construct(globals[name],{...})end
	local function obj(values)return vm.Object(values or {})end
	local function array(values)return vm.Array(values)end
	local function drain(queue)local limit=0;while #queue>0 do limit+=1;assert(limit<1000);local fn=table.remove(queue,1);fn()end end
	local function frame(ms)
		time=ms;local snapshot=frames;frames={};for _,callback in snapshot do callback(ms)end
	end
	local function errorName(fn,name)local ok,err=pcall(fn);assert(not ok,"Expected "..name);assert(get(VM.exceptionValue(err),"name")==name,VM.string(VM.exceptionValue(err)))end
	local function near(a,b)assert(type(a)=="number"and math.abs(a-b)<.000001,tostring(a).." ~= "..tostring(b))end
	local target=bridge.Wrap(Node.findById(document,"target"));local child=bridge.Wrap(Node.findById(document,"child"))
	local eventNativeCount=0
	for _,reference in cssDOMFixtures and cssDOMFixtures.cases or{}do
		if reference.name~='event constructor values'and reference.name~='event conversion and receivers'and reference.name:sub(1,16)~='pending playback'then continue end
		vm:Run('var cssEventNativeResult=(function(){'..reference.source..'})();')
		local result=vm.Global.Bindings.cssEventNativeResult.Value
		assert(vm.IsArray(result)and #result.Items==#reference.expected,'CSS event constructor produces the native result count')
		for index,expected in reference.expected do assert(VM.string(result.Items[index])==expected,reference.name..' ['..index..']: '..VM.string(result.Items[index])..' ~= '..expected)end
		eventNativeCount+=1
	end
	drain(microtasks);drain(tasks);assert(next(frames)==nil,'Constructor and pending-rate references leave no live frame request')
	local animationEvent=construct('AnimationEvent','animationend',obj({animationName='move',elapsedTime=1,pseudoElement='',bubbles=true}))
	local transitionEvent=construct('TransitionEvent','transitionend',obj({propertyName='opacity',elapsedTime=.5}))
	assert(get(animationEvent,'animationName')=='move'and get(transitionEvent,'propertyName')=='opacity','CSS event types preserve their distinct branded readonly fields')
	errorName(function()set(animationEvent,'animationName','changed')end,'TypeError')
	errorName(function()set(transitionEvent,'elapsedTime',2)end,'TypeError')
	local authoredEventTarget=construct('EventTarget')
	local cssEventCount=0
	call(authoredEventTarget,'addEventListener','animationend',function(args)cssEventCount+=1;assert(args[1]==animationEvent and get(args[1],'target')==authoredEventTarget and not get(args[1],'isTrusted'),'Authored AnimationEvent keeps event identity and target through dispatch')end)
	assert(call(authoredEventTarget,'dispatchEvent',animationEvent)==true and cssEventCount==1,'Authored CSS event uses the real EventTarget path')
	local foreignGlobals={};local foreignVM=VM.new(foreignGlobals,{MaxSteps=10000})
	local foreignHost=foreignVM:Install(function()return HostEvents.install(foreignVM,foreignGlobals,{Clock=function()return time end,Report=error})end)
	local foreignAnimations=foreignVM:Install(function()return WebAnimations.install(foreignVM,foreignGlobals,{HostEvents=foreignHost,Now=function()return time end})end)
	local foreignEvent=foreignVM:Construct(foreignGlobals.AnimationEvent,{'animationend',foreignVM.Object({animationName='foreign',elapsedTime=2})})
	local localAnimationNameGetter=vm.Get(vm.GetOwnPropertyDescriptor(vm.Get(globals.AnimationEvent,'prototype'),'animationName'),'get')
	local foreignAnimationNameGetter=foreignVM.Get(foreignVM.GetOwnPropertyDescriptor(foreignVM.Get(foreignGlobals.AnimationEvent,'prototype'),'animationName'),'get')
	assert(vm:Call(localAnimationNameGetter,{},foreignEvent)=='foreign'and foreignVM:Call(foreignAnimationNameGetter,{},animationEvent)=='move','AnimationEvent getters accept genuine foreign-realm brands in both directions')
	local foreignPropertyGetter=foreignVM.Get(foreignVM.GetOwnPropertyDescriptor(foreignVM.Get(foreignGlobals.TransitionEvent,'prototype'),'propertyName'),'get')
	assert(foreignVM:Call(foreignPropertyGetter,{},transitionEvent)=='opacity','TransitionEvent getter accepts a genuine event from another realm')
	errorName(function()vm:Call(localAnimationNameGetter,{},transitionEvent)end,'TypeError')
	foreignAnimations:Destroy();foreignHost:Destroy();foreignVM:Destroy()
	local trace={};local a=call(target,"animate",array({obj({opacity=0}),obj({opacity=1})}),obj({duration=100,fill="both",id="demo"}))
	assert(get(a,"id")=="demo"and get(a,"pending")and get(a,"playState")=="running"and get(a,"currentTime")==0 and get(a,"startTime")==VM.Null)
	local ready=get(a,"ready");local finished=get(a,"finished")
	call(ready,"then",function(args)assert(args[1]==a);table.insert(trace,"ready")end)
	call(finished,"then",function(args)assert(args[1]==a);table.insert(trace,"finished")end)
	set(a,"onfinish",function(args)
		local event=args[1];assert(get(event,"target")==a and get(event,"isTrusted")and get(event,"currentTime")==100 and get(event,"timelineTime")==110)
		assert(get(event,"constructor")==globals.AnimationPlaybackEvent);table.insert(trace,"finish")
	end)
	assert(#trace==0);frame(10);drain(microtasks);assert(table.concat(trace,",")=="ready"and not get(a,"pending")and get(a,"startTime")==10)
	call(a,"play");assert(get(a,"ready")==ready and not get(a,"pending"),"Playing an already running animation is a no-op")
	frame(60);near(get(a,"currentTime"),50);near(get(call(get(a,"effect"),"getComputedTiming"),"progress"),.5)
	time=110;for _=1,3 do animations:AfterLayout()end
	local finalFrames=0;for _ in frames do finalFrames+=1 end
	assert(finalFrames==1 and table.concat(trace,",")=="ready","Endpoint layout publication preserves exactly one final timing update before finished settles")
	frame(110);assert(get(a,"playState")=="finished"and get(a,"currentTime")==100 and next(frames)==nil)
	assert(table.concat(trace,",")=="ready"and #tasks==1);drain(microtasks);assert(table.concat(trace,",")=="ready,finished");drain(tasks);assert(table.concat(trace,",")=="ready,finished,finish")
	animations:AfterLayout();assert(next(frames)==nil,"A settled finished effect does not resubscribe after a later layout publication")
	assert(call(target,"getAnimations").Items[1]==a and call(bridge.Document,"getAnimations").Items[1]==a,"Filled finished effects remain relevant")
	set(a,"currentTime",25);assert(get(a,"finished")~=finished and get(a,"playState")=="running");frame(135);near(get(a,"currentTime"),50)
	call(a,"pause");local pauseReady=get(a,"ready");assert(get(a,"playState")=="paused"and get(a,"pending"));frame(150);assert(not get(a,"pending")and next(frames)==nil)
	local held=get(a,"currentTime");time=500;assert(get(a,"currentTime")==held);call(a,"play");assert(get(a,"ready")~=pauseReady);frame(510);frame(535);near(get(a,"currentTime"),held+25)
	call(a,"updatePlaybackRate",2);local seamless=get(a,"currentTime");assert(get(a,'playbackRate')==1 and get(a,'pending'),'A running seamless update waits for ready');frame(540);near(get(a,"currentTime"),seamless+5);frame(542);near(get(a,'currentTime'),seamless+9)
	call(a,"pause");frame(543);set(a,"currentTime",25);set(a,"playbackRate",-1);call(a,"play");frame(550);frame(560);near(get(a,"currentTime"),15)
	call(a,"reverse");near(get(a,"currentTime"),15);assert(get(a,"pending")and get(a,'playbackRate')==-1);frame(561);near(get(a,'currentTime'),14);frame(566);near(get(a,"currentTime"),19)
	local canceledFinished=get(a,"finished");local cancelTrace={}
	call(canceledFinished,"catch",function(args)assert(get(args[1],"name")=="AbortError");table.insert(cancelTrace,"rejected")end)
	set(a,"oncancel",function(args)assert(get(args[1],"currentTime")==VM.Null);table.insert(cancelTrace,"cancel")end)
	call(a,"cancel");assert(get(a,"playState")=="idle"and get(a,"currentTime")==VM.Null and next(frames)==nil and #call(target,"getAnimations").Items==0)
	drain(microtasks);assert(table.concat(cancelTrace,",")=="rejected");drain(tasks);assert(table.concat(cancelTrace,",")=="rejected,cancel")
	local pending=call(child,"animate",array({obj({opacity=0}),obj({opacity=1})}),100);local pendingReady=get(pending,"ready");local rejection
	call(pendingReady,"catch",function(args)rejection=get(args[1],"name")end);call(get(pending,"finished"),"catch",function()end);call(pending,"cancel");drain(microtasks);assert(rejection=="AbortError"and get(pending,"ready")~=pendingReady and next(frames)==nil);drain(tasks)
	local effect=construct("KeyframeEffect",target,array({obj({opacity=0}),obj({opacity=.3}),obj({opacity=1})}),obj({duration=100,iterations=2,direction="alternate",fill="both"}))
	local normalized=call(effect,"getKeyframes").Items;assert(#normalized==3 and get(normalized[1],"offset")==VM.Null and get(normalized[1],"computedOffset")==0 and get(normalized[2],"computedOffset")==.5 and get(normalized[3],"computedOffset")==1)
	local loop=construct("Animation",effect);call(loop,"pause");frame(570)
	for _,case in {{0,0,0},{25,.25,0},{100,1,1},{125,.75,1},{200,0,1}}do set(loop,"currentTime",case[1]);local c=call(effect,"getComputedTiming");near(get(c,"progress"),case[2]);assert(get(c,"currentIteration")==case[3])end
	call(effect,"updateTiming",obj({iterationStart=.5,direction="normal",iterations=1,endDelay=-25}));set(loop,"currentTime",75);local cut=call(effect,"getComputedTiming");near(get(cut,"progress"),.25);assert(get(cut,"endTime")==75 and get(cut,"activeDuration")==100)
	call(effect,"updateTiming",obj({duration=0,iterations=3,iterationStart=0,endDelay=0,direction="alternate"}));set(loop,"currentTime",0);local zero=call(effect,"getComputedTiming");assert(get(zero,"currentIteration")==2 and get(zero,"progress")==1)
	call(effect,"updateTiming",obj({duration=100,iterations=math.huge}));call(loop,"play");errorName(function()call(loop,"finish")end,"InvalidStateError");set(loop,"playbackRate",0);errorName(function()call(loop,"finish")end,"InvalidStateError")
	call(get(loop,"finished"),"catch",function()end);call(loop,"cancel");drain(microtasks);drain(tasks)
	local mixed=construct("KeyframeEffect",target,obj({opacity=array({0,.5,1}),transform=array({"none","translateX(10px)"})}),100)
	local merged=call(mixed,"getKeyframes").Items;assert(#merged==3 and get(merged[1],"computedOffset")==0 and get(merged[2],"computedOffset")==.5 and get(merged[3],"computedOffset")==1 and get(merged[2],"opacity")=="0.5"and get(merged[2],"transform")==VM.Undefined)
	call(mixed,"setKeyframes",obj({opacity=array({0,.5,1}),offset=array({.2})}));local redistributed=call(mixed,"getKeyframes").Items
	near(get(redistributed[2],"computedOffset"),.6);assert(get(redistributed[2],"offset")==VM.Null and get(redistributed[3],"computedOffset")==1)
	local iteratorReads=0;local iterable=obj({["0"]=obj({opacity=0}),["1"]=obj({opacity=1}),length=2})
	vm.DefineProperty(iterable,vm.SymbolIterator,obj({get=function()iteratorReads+=1;return get(vm.Prototypes.Array,vm.SymbolIterator)end,configurable=true}))
	call(mixed,"setKeyframes",iterable);assert(iteratorReads==1,"Keyframe iterable method getter is read once")
	local getterOrder={};local orderFrame=obj({});local orderOptions=obj({})
	for key,value in {composite="auto",easing="linear",offset=VM.Null,opacity="1",transform="none"}do local member=key;local result=value
		vm.DefineProperty(orderFrame,member,obj({get=function()table.insert(getterOrder,member);return result end,enumerable=true,configurable=true}))
	end
	local optionOrder={};for key,value in {delay=0,direction="normal",duration=100,easing="linear",endDelay=0,fill="none",iterationStart=0,iterations=1,composite="replace",pseudoElement=VM.Null,id="test",timeline=animations.Timeline}do local member=key;local result=value
		vm.DefineProperty(orderOptions,member,obj({get=function()table.insert(optionOrder,member);return result end,enumerable=true,configurable=true}))
	end
	local orderedAnimation=call(target,"animate",array({orderFrame}),orderOptions)
	assert(table.concat(getterOrder,",")=="composite,easing,offset,opacity,transform")
	assert(table.concat(optionOrder,",")=="delay,direction,duration,easing,endDelay,fill,iterationStart,iterations,composite,pseudoElement,id,timeline","Web IDL inherited dictionary conversion order agrees with Chromium")
	call(get(orderedAnimation,"finished"),"catch",function()end);call(get(orderedAnimation,"ready"),"catch",function()end);call(orderedAnimation,"cancel");drain(microtasks);drain(tasks)
	local eagerReads=0;local bad=obj({easing="invalid"});vm.DefineProperty(bad,"opacity",obj({get=function()eagerReads+=1;return "1"end,enumerable=true}))
	errorName(function()call(mixed,"setKeyframes",array({bad}))end,"TypeError");assert(eagerReads==1,"Easing parse errors happen after property reads")
	local nonEnumerable=obj({opacity=".5"});vm.DefineProperty(nonEnumerable,"transform",obj({get=function()error("Non-enumerable keyframe property read")end}));call(mixed,"setKeyframes",array({nonEnumerable}));assert(get(call(mixed,"getKeyframes").Items[1],"transform")==VM.Undefined)
	call(mixed,"setKeyframes",array({obj({opacity=.5})}));assert(get(call(mixed,"getKeyframes").Items[1],"computedOffset")==1)
	call(mixed,"setKeyframes",array({obj({offset=0,opacity=0}),obj({offset=.2,opacity=.2}),obj({opacity=.6}),obj({offset=.8,opacity=.8}),obj({opacity=1})}))
	near(get(call(mixed,"getKeyframes").Items[3],"computedOffset"),.5)
	local before=call(mixed,"getKeyframes");errorName(function()call(mixed,"setKeyframes",array({obj({offset=.8}),obj({offset=.1})}))end,"TypeError");assert(#call(mixed,"getKeyframes").Items==#before.Items)
	errorName(function()call(mixed,"updateTiming",obj({delay=5,duration=-1}))end,"TypeError");assert(get(call(mixed,"getTiming"),"delay")==0,"Invalid updateTiming is atomic")
	errorName(function()call(mixed,"updateTiming",obj({iterations=0/0}))end,"TypeError")
	errorName(function()vm:Call(get(mixed,"getTiming"),{},a)end,"TypeError")
	errorName(function()vm:Call(globals.Animation,{})end,"TypeError")
	errorName(function()construct("KeyframeEffect",bridge.Document,array({}))end,"TypeError")
	local copy=construct("KeyframeEffect",mixed);assert(get(copy,"target")==target and #call(copy,"getKeyframes").Items==5);call(copy,"setKeyframes",array({}));assert(#call(mixed,"getKeyframes").Items==5)
	local first=construct("Animation",mixed);local second=construct("Animation",mixed);assert(get(first,"effect")==VM.Null and get(second,"effect")==mixed,"An effect has one animation owner")
	local inactive=construct("Animation",construct("KeyframeEffect",target,array({}),100),VM.Null);call(inactive,"play")
	assert(get(inactive,"pending")and get(inactive,"currentTime")==0 and next(frames)==nil,"An inactive timeline keeps play pending without an idle frame connection")
	call(get(inactive,"finished"),"catch",function()end);call(get(inactive,"ready"),"catch",function()end);call(inactive,"cancel");drain(microtasks);drain(tasks)
	local past=call(target,"animate",array({}),100);call(past,"finish");set(past,"currentTime",500);assert(get(past,"currentTime")==500)
	set(past,"playbackRate",-1);assert(get(past,"currentTime")==500 and get(past,"playState")=="running");frame(time+10);near(get(past,"currentTime"),490)
	call(get(past,"finished"),"catch",function()end);call(past,"cancel");drain(microtasks);drain(tasks)
	local timeline=construct("DocumentTimeline",obj({originTime=10}));assert(get(timeline,"currentTime")==time-10)
	assert(get(bridge.Document,"timeline")==animations.Timeline);errorName(function()set(bridge.Document,"timeline",VM.Null)end,"TypeError")
	local playback=construct("AnimationPlaybackEvent","finish",obj({currentTime=12,timelineTime=33}));assert(get(playback,"currentTime")==12 and get(playback,"timelineTime")==33 and not get(playback,"isTrusted"))
	local c=call(child,"animate",array({obj({opacity=0}),obj({opacity=1})}),100);frame(600)
	assert(#call(target,"getAnimations").Items==0 and #call(target,"getAnimations",obj({subtree=true})).Items==1)
	call(get(c,"finished"),"catch",function()end);call(c,"cancel");drain(microtasks);drain(tasks)
	-- A layout publication can occur later in the same frame. Restore the
	-- sampled effect, rather than advancing the wall clock and requesting a
	-- further layout before the next frame callback.
	local steady=call(target,"animate",array({obj({width="100px"}),obj({width="200px"})}),obj({duration=1000,iterations=math.huge}))
	frame(700);frame(950)
	local targetNode=Node.findById(document,"target");local sampled=paint[targetNode].Timing.progress
	time=1000;animations:AfterLayout();near(paint[targetNode].Timing.progress,sampled)
	set(steady,"currentTime",400);near(paint[targetNode].Timing.progress,.4)
	time=1050;animations:AfterLayout();near(paint[targetNode].Timing.progress,.4)
	frame(1100);assert(paint[targetNode].Timing.progress>.4,"A new animation frame must advance the retained sample")
	call(get(steady,"finished"),"catch",function()end);call(get(steady,"ready"),"catch",function()end);call(steady,"cancel");drain(microtasks);drain(tasks)
	for _,case in zeroFixtures or{}do
		local effect=construct("KeyframeEffect",target,array({obj({opacity=.2}),obj({opacity=.8})}),obj({duration=0,iterations=if case.iterations=="Infinity"then math.huge else tonumber(case.iterations),iterationStart=case.iterationStart,fill="both"}))
		local animation=construct("Animation",effect);call(animation,"pause");set(animation,"currentTime",case.time)
		local computed=call(effect,"getComputedTiming")
		near(get(computed,"progress"),case.progress)
		local expectedIteration=if case.currentIteration=="Infinity"then math.huge else tonumber(case.currentIteration)
		assert(get(computed,"currentIteration")==expectedIteration,"Zero-duration iteration disagrees with captured browser timing")
		assert(get(computed,"activeDuration")==case.activeDuration and get(computed,"endTime")==case.endTime)
		call(get(animation,"finished"),"catch",function()end);call(get(animation,"ready"),"catch",function()end);call(animation,"cancel");drain(microtasks);drain(tasks)
	end
	assert(#reports==0);animations:Destroy();assert(next(frames)==nil);host:Destroy();promises:Destroy();bridge:Destroy();vm:Destroy()
	verifyShadowAnimationConnectivity(Parser,DOM,VM,Promises,WebAnimations)
	print("JavaScript Web Animations normalization, timing, promises, events and lifetime tests passed; "..eventNativeCount..' native CSS event/pending-rate cases')
end
