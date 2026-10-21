--!strict
-- Fixture dimensions also exercised in build/layout-observers-reference.html
-- against Chromium. Rendering/scroll publication is injected, never polled.
return function(Parser,Node,DOM,VM,Events,Geometry,LayoutObservers)
	local document=Parser.parseDocument('<html><body><section id="root"><div id="clip"><div id="target"></div></div><div id="second"></div></section><div id="resize"></div><div id="zero"></div></body></html>')
	local events=Events.new(error);local vm;local tasks,requests,timers,errors={},{},{},{};local timestamp=10;local reads=0
	local bridge=DOM.new(document,{Events=events,Window={},ReadyState="complete",Changed=function()end,
		Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key)return vm.Get(value,key)end,
		GetControl=function()return VM.Undefined end,SetControl=function()end,Click=function()end})
	local globals={document=bridge.Document};vm=VM.new(globals,{MaxSteps=100000})
	local root,clip,target,second,resizable,zero=Node.findById(document,"root"),Node.findById(document,"clip"),Node.findById(document,"target"),Node.findById(document,"second"),Node.findById(document,"resize"),Node.findById(document,"zero")
	local rects={};local layout={NodeBoxes={},NodeStyles={}};local viewport={Width=300,Height=200,DevicePixelRatio=1}
	local function box(node,x,y,w,h,contentWidth,contentHeight,style)
		style=style or {};layout.NodeStyles[node]=style;layout.NodeBoxes[node]={OuterWidth=w,OuterHeight=h,ContentWidth=contentWidth or w,ContentHeight=contentHeight or h,Style=style}
		rects[node]={{X=x,Y=y,Width=w,Height=h}}
	end
	box(root,20,20,100,100,100,100,{Overflow="hidden"});box(clip,20,20,50,50,50,50);box(target,110,20,20,20);box(second,25,25,10,10)
	box(resizable,200,20,110,48,100,40,{Padding={2,3,4,5},BorderSize=1});box(zero,0,0,0,0)
	local geometry=vm:Install(function()return Geometry.install(vm,globals,{Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
		GetViewport=function()return viewport end,GetTree=function()return layout end,
		GetClientRects=function(node)reads+=1;return rects[node]or {}end})end)
	local observers=vm:Install(function()return LayoutObservers.install(vm,globals,{Geometry=geometry,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
		GetViewport=function()return viewport end,GetTree=function()return layout end,
		QueueTask=function(callback)table.insert(tasks,callback)end,RequestLayout=function(delay)table.insert(requests,delay)end,
		Schedule=function(callback,delay)table.insert(timers,{Callback=callback,Delay=delay})end,Now=function()return timestamp end,
		Report=function(failure)table.insert(errors,VM.string(failure))end,ReportResizeLoopError=function(message)table.insert(errors,message)end})end)
	local function call(value,key,...)return vm:Call(vm.Get(value,key),{...},value)end
	local function get(value,key)return vm.Get(value,key)end
	local function wrap(node)return bridge.Wrap(node)end
	local function options(values)return vm.Object(values or {})end
	local function construct(name,...)return vm:Construct(globals[name],{...})end
	local function drain()local count=0;while #tasks>0 do count+=1;assert(count<64);table.remove(tasks,1)()end end
	local function errorName(fn,name)local ok,failure=pcall(fn);assert(not ok,"Expected "..name);assert(VM.exceptionValue(failure).Get("name")==name,VM.string(VM.exceptionValue(failure)))end
	local function disconnect(value)call(value,"disconnect")end
	local deliveries={};local ro=construct("ResizeObserver",function(args,receiver)assert(args[2]==receiver);table.insert(deliveries,args[1].Items)end)
	call(ro,"observe",wrap(resizable));call(ro,"observe",wrap(zero));assert(#deliveries==0 and #requests==1 and reads==0,"observe only requests a rendering opportunity")
	observers:AfterLayout();assert(#deliveries==1 and #deliveries[1]==2)
	local entry=deliveries[1][1];local content=get(entry,"contentRect");assert(get(entry,"target")==wrap(resizable)and get(content,"x")==5 and get(content,"y")==2 and get(content,"width")==100 and get(content,"height")==40)
	local contentSize=get(get(entry,"contentBoxSize"),"0");local borderSize=get(get(entry,"borderBoxSize"),"0")
	assert(get(contentSize,"inlineSize")==100 and get(contentSize,"blockSize")==40 and get(borderSize,"inlineSize")==110 and get(borderSize,"blockSize")==48)
	assert(get(get(deliveries[1][2],"contentRect"),"width")==0,"Zero-size observations receive a first entry")
	errorName(function()vm.Set(contentSize,"inlineSize",5,true)end,"TypeError");vm.Set(contentSize,"inlineSize",5,false);assert(get(contentSize,"inlineSize")==100)
	errorName(function()vm.Set(get(entry,"contentBoxSize"),"0",VM.Null,true)end,"TypeError")
	call(ro,"observe",wrap(resizable));observers:AfterLayout();assert(#deliveries==1,"Repeated same-box observe does not reset the last size")
	rects[resizable][1].Width=220;observers:AfterLayout();assert(#deliveries==1,"CSS transforms do not change ResizeObserver boxes")
	local borders={};local borderObserver=construct("ResizeObserver",function(args)table.insert(borders,args[1].Items)end);call(borderObserver,"observe",wrap(resizable),options({box="border-box"}));observers:AfterLayout();assert(#borders==1)
	layout.NodeBoxes[resizable].OuterWidth=112;layout.NodeStyles[resizable].Padding[2]=5;observers:AfterLayout();assert(#borders==2 and #deliveries==1,"Box option controls activity while all box sizes remain available")
	layout.NodeStyles[resizable].WritingMode="vertical-rl";observers:AfterLayout();assert(#deliveries==2 and get(get(get(deliveries[2][1],"contentBoxSize"),"0"),"inlineSize")==40)
	call(ro,"observe",wrap(resizable),options({box="device-pixel-content-box"}));viewport.DevicePixelRatio=2;observers:AfterLayout();assert(get(get(get(deliveries[#deliveries][1],"devicePixelContentBoxSize"),"0"),"blockSize")==200)
	errorName(function()call(ro,"observe",wrap(resizable),options({box="other"}))end,"TypeError");observers:AfterLayout();assert(#deliveries==3,"Invalid reobserve preserves existing registration")
	disconnect(ro);disconnect(borderObserver)
	local round=0;local depthBatches={};local looping=construct("ResizeObserver",function(args)
		round+=1;local ids={};for _,e in args[1].Items do table.insert(ids,get(e,"target").Get("id"))end;table.insert(depthBatches,table.concat(ids,","))
		if round==1 then layout.NodeBoxes[root].ContentWidth=101;layout.NodeBoxes[target].ContentWidth=21;observers:AfterLayout()end
	end)
	call(looping,"observe",wrap(root));call(looping,"observe",wrap(target));observers:AfterLayout()
	assert(table.concat(depthBatches,";")=="root,target;target" and #errors==1 and errors[1]=="ResizeObserver loop completed with undelivered notifications.","Resize delivery admits deeper targets and reports skipped same-depth changes")
	observers:AfterLayout();assert(depthBatches[3]=="root");disconnect(looping)
	local failed=construct("ResizeObserver",function()error("resize callback failure")end);call(failed,"observe",wrap(zero));observers:AfterLayout();assert(#errors==2);disconnect(failed)
	local intersections={};local io=construct("IntersectionObserver",function(args,receiver)assert(args[2]==receiver);table.insert(intersections,args[1].Items)end,options({root=wrap(root),threshold=vm.Array({1,0.5,0,0.5})}))
	assert(get(io,"root")==wrap(root)and get(io,"rootMargin")=="0px 0px 0px 0px"and get(get(io,"thresholds"),"length")==4 and get(get(io,"thresholds"),"1")==0.5)
	errorName(function()vm.Set(get(io,"thresholds"),"0",1,true)end,"TypeError")
	call(io,"observe",wrap(target));call(io,"observe",wrap(second));observers:AfterLayout();assert(#intersections==0 and #tasks==1,"Intersection entries wait for a task")
	local queued=call(io,"takeRecords").Items;assert(#queued==2 and get(queued[1],"target")==wrap(target)and get(queued[1],"intersectionRatio")==0.5 and get(queued[1],"isIntersecting"))
	assert(get(get(queued[1],"intersectionRect"),"width")==10 and get(queued[1],"time")==timestamp)
	drain();assert(#intersections==0,"takeRecords drains the queued callback input")
	rects[target][1].X=120;timestamp+=10;observers:AfterLayout();drain();assert(get(intersections[1][1],"intersectionRatio")==0 and get(intersections[1][1],"isIntersecting"),"Edge-adjacent target intersects with zero area")
	rects[target][1].X=121;observers:ScrollChanged();assert(#intersections==1);timestamp+=10;observers:AfterLayout();drain();assert(not get(intersections[2][1],"isIntersecting"))
	rects[target][1].X=115;timestamp+=10;observers:AfterLayout();drain();assert(get(intersections[3][1],"intersectionRatio")==0.25)
	rects[target][1].X=114;timestamp+=10;observers:AfterLayout();drain();assert(#intersections==3,"Movement within a threshold interval does not notify")
	call(io,"unobserve",wrap(second));call(io,"observe",wrap(target));observers:AfterLayout();drain();assert(#intersections==3,"Duplicate IO observe does not queue another first entry")
	disconnect(io)
	local marginObserver=construct("IntersectionObserver",function()end,options({root=wrap(root),rootMargin="10% 20%",scrollMargin="0px"}));call(marginObserver,"observe",wrap(target));observers:AfterLayout()
	local marginEntry=call(marginObserver,"takeRecords").Items[1];assert(get(marginEntry,"intersectionRatio")==1 and get(get(marginEntry,"rootBounds"),"x")==0 and get(get(marginEntry,"rootBounds"),"y")==10,"All percentage margins resolve against root width")
	disconnect(marginObserver);drain()
	layout.NodeStyles[clip].Overflow="hidden";rects[target][1].X=90
	local clipped=construct("IntersectionObserver",function()end,options({root=wrap(root)}));call(clipped,"observe",wrap(target));observers:AfterLayout()
	local clippedEntry=call(clipped,"takeRecords").Items[1];assert(not get(clippedEntry,"isIntersecting")and get(clippedEntry,"intersectionRatio")==0,"Ancestor clips determine isIntersecting")
	disconnect(clipped);drain()
	local scrollMargin=construct("IntersectionObserver",function()end,options({root=wrap(root),scrollMargin="30px"}));call(scrollMargin,"observe",wrap(target));observers:AfterLayout()
	local scrollEntry=call(scrollMargin,"takeRecords").Items[1];assert(get(scrollEntry,"intersectionRatio")==0.5 and get(scrollEntry,"isIntersecting"),"Scroll margins expand each nested scrollport")
	disconnect(scrollMargin);drain();layout.NodeStyles[clip].Overflow="visible"
	local retainedEntries={};local retired=construct("IntersectionObserver",function(args)table.insert(retainedEntries,args[1].Items)end);call(retired,"observe",wrap(zero));observers:AfterLayout();disconnect(retired);drain()
	assert(#retainedEntries==1 and get(retainedEntries[1][1],"intersectionRatio")==1,"Disconnect preserves already queued entries; visible zero-area targets have ratio one")
	local outside=bridge.Document.Get("createElement")({"i"});local detached=construct("IntersectionObserver",function()end);call(detached,"observe",outside);observers:AfterLayout();local detachedEntry=call(detached,"takeRecords").Items[1]
	assert(not get(detachedEntry,"isIntersecting")and get(detachedEntry,"intersectionRatio")==0);disconnect(detached);drain()
	local delayed={};local delayObserver=construct("IntersectionObserver",function(args)table.insert(delayed,args[1].Items)end,options({delay=100}));call(delayObserver,"observe",wrap(target));timestamp=1000;observers:AfterLayout();drain();assert(#delayed==1)
	rects[target][1].X=400;timestamp=1020;observers:AfterLayout();drain();assert(#delayed==1 and timers[#timers].Delay==80,"Delay defers measurement until an eligible rendering opportunity")
	timestamp=1100;timers[#timers].Callback();observers:AfterLayout();drain();assert(#delayed==2);disconnect(delayObserver)
	local visibility=construct("IntersectionObserver",function()end,options({trackVisibility=true}));assert(get(visibility,"delay")==100);call(visibility,"observe",wrap(zero));observers:AfterLayout();assert(not get(call(visibility,"takeRecords").Items[1],"isVisible"),"A host without occlusion guarantees reports visibility conservatively");disconnect(visibility);drain()
	for _,margin in {"0","2em","1in","calc(1px)","1px 2px 3px 4px 5px"}do errorName(function()construct("IntersectionObserver",function()end,options({rootMargin=margin}))end,"SyntaxError")end
	errorName(function()construct("IntersectionObserver",function()end,options({threshold=0/0}))end,"TypeError")
	errorName(function()construct("IntersectionObserver",function()end,options({threshold=2}))end,"RangeError")
	errorName(function()call(io,"observe",bridge.Document)end,"TypeError")
	errorName(function()call(io,"observe",vm.Object({DOMNode=target}))end,"TypeError")
	local fabricated=construct("IntersectionObserverEntry",options({time=4,target=wrap(target),rootBounds=VM.Null,boundingClientRect=options({x=1,width=2}),intersectionRect=options({}),isIntersecting=false,intersectionRatio=0}))
	assert(get(fabricated,"time")==4 and get(fabricated,"rootBounds")==VM.Null and get(get(fabricated,"boundingClientRect"),"width")==2)
	vm:Run([[let observerOrder=[];let observerTypes=false;const dictionary={get delay(){observerOrder.push('delay');return 0},get root(){observerOrder.push('root');return null},get rootMargin(){observerOrder.push('rootMargin');return {toString(){observerOrder.push('string');return '0px'}}},get scrollMargin(){observerOrder.push('scrollMargin');return '0px'},get threshold(){observerOrder.push('threshold');return [0,1]},get trackVisibility(){observerOrder.push('visibility');return false}};const typed=new IntersectionObserver(()=>{},dictionary);observerTypes=typed instanceof IntersectionObserver&&Object.isFrozen(typed.thresholds);]])
	assert(table.concat(vm.Global.Bindings.observerOrder.Value.Items,",")=="delay,root,rootMargin,string,scrollMargin,threshold,visibility" and vm.Global.Bindings.observerTypes.Value)
	local before=reads;observers:AfterLayout();assert(reads==before,"Inactive observer publication does not scan or measure the document")
	observers:Destroy();drain();geometry:Destroy();bridge:Destroy();events:Destroy();vm:Destroy()
	print("JavaScript layout observers: rendering-phase resize depth/boxes, task-delivered intersections/thresholds/margins/clips, identity, validation, delays and lifetime passed")
end
