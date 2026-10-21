--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local WorkContext=require(script.Parent.Parent.WorkContext)
-- One persistent realm per HTML document. Layout never runs a script again.
local VM = require(script.Parent.VM)
local DOM = require(script.Parent.DOM)
local CustomElements = require(script.Parent.CustomElements)
local PointerCapture = require(script.Parent.PointerCapture)
local ShadowTree = require(script.Parent.Parent.DOM.ShadowTree)
local DOMTraversal = require(script.Parent.DOMTraversal)
local DOMRanges = require(script.Parent.DOMRanges)
local RangeContents = require(script.Parent.RangeContents)
local Selection = require(script.Parent.Selection)
local Editing = require(script.Parent.Editing)
local EventLoop = require(script.Parent.EventLoop)
local Promises = require(script.Parent.Promises)
local CSSOM = require(script.Parent.CSSOM)
local CSSNamespace = require(script.Parent.CSSNamespace)
local TypedOM = require(script.Parent.TypedOM)
local Highlights = require(script.Parent.Highlights)
local AsyncFunctions = require(script.Parent.AsyncFunctions)
local HostEvents = require(script.Parent.HostEvents)
local EventHandlerAttributes=require(script.Parent.EventHandlerAttributes)
local DOMNamedProperties=require(script.Parent.DOMNamedProperties)
local NetworkData = require(script.Parent.NetworkData)
local Geometry = require(script.Parent.Geometry)
local MutationObserver = require(script.Parent.MutationObserver)
local LayoutObservers = require(script.Parent.LayoutObservers)
local StructuredClone = require(script.Parent.StructuredClone)
local Performance = require(script.Parent.Performance)
local TopLayer = require(script.Parent.TopLayer)
local Messaging = require(script.Parent.Messaging)
local WorkerAdapter = require(script.Parent.WorkerAdapter)
local Storage = require(script.Parent.Storage)
local Navigation = require(script.Parent.Navigation)
local BrowsingWindows=require(script.Parent.BrowsingWindows)
local SimpleDialogs=require(script.Parent.SimpleDialogs)
local MediaDevices=require(script.Parent.MediaDevices)
local MediaStreams=require(script.Parent.MediaStreams)
local IdleCallbacks=require(script.Parent.IdleCallbacks)
local Scheduler=require(script.Parent.Scheduler)
local WebLocks=require(script.Parent.WebLocks)
local DocumentLifecycle=require(script.Parent.DocumentLifecycle)
local RealmAccess=require(script.Parent.RealmAccess)
local DocumentOrigin=require(script.Parent.Parent.DOM.DocumentOrigin)
local Fullscreen=require(script.Parent.Fullscreen)
local Modules = require(script.Parent.Modules)
local ScriptLoader = require(script.Parent.ScriptLoader)
local StylesheetResources=require(script.Parent.StylesheetResources)
local DocumentInfo=require(script.Parent.Parent.HTML.DocumentInfo)
local WebAnimations = require(script.Parent.WebAnimations)
local FormDataDOM = require(script.Parent.FormDataDOM)
local DOMCanvas = require(script.Parent.DOMCanvas)
local CanvasSurface = require(script.Parent.Parent.Rendering.CanvasSurface)
local ImageResources = require(script.Parent.ImageResources)
local FontLoading = require(script.Parent.FontLoading)
local AudioElements = require(script.Parent.AudioElements)
local Runtime = {}
local TYPES = {["text/javascript"]=true,["application/javascript"]=true,["text/ecmascript"]=true,["application/ecmascript"]=true,[""]=true}
function Runtime.scripts(document: any): any
	local result,pending={},{document}
	while #pending>0 do
		local node=table.remove(pending)
		if ElementNames.html(node,"template") then continue end
		if node.Kind=="Element" and ElementNames.script(node) and node.Attributes["data-canvas-script"]==nil then
			local kind=(node.Attributes.type or ""):match("^%s*(.-)%s*$"):lower()
			if TYPES[kind] or kind=="module" or kind=="importmap" then table.insert(result,node) end
		end
		for i=#node.Children,1,-1 do table.insert(pending,node.Children[i]) end
	end
	return result
end
local function createRuntime(document: any, options: any): any
	options=table.clone(options)
	if not options.LoadScript and (options.ScriptSources or options.ModuleSources) then
		options.LoadScript=function(url,complete)
			local source=options.ScriptSources and options.ScriptSources[url] or options.ModuleSources and options.ModuleSources[url]
			complete(source~=nil,source or "Packaged script resource is unavailable")
		end
	end
	local runtime={Alive=true,Started=false,Pending={},Diagnostics={},ScriptsRun=0,Flushes=0,Document=document,
		DocumentOrigin=DocumentOrigin.ensure(document,options.URL,options.DocumentOrigin,options.DocumentOriginOpaque)}
	local vm,bridge,window,loop,promises,eventHost,network,geometry,mutationObservers,layoutObservers,structuredClone,messaging,workers,storage,navigation,modules
	local eventConnection
	local scriptLoader
	local imageResources,fontLoading,audioElements,stylesheetResources,ensureStylesheetResources
	local stylesheetListeners={};local parentStylesheetSubscription
	local eventHandlerAttributes
	local fontLayoutPending=false
	local animations,animationAdapter
	local formDataDOM
	local canvas,canvasAdapter
	local ranges,selection,selectionAdapter
	local editing,editingAdapter
	local cssom,cssomAdapter
	local typedOM
	local highlights
	local performance
	local topLayer,topLayerAdapter
	local fullscreen
	local lifecycle
	local customElements,pointerCapture
	local memoryStorageAreas={}
	local host=table.clone(options)
	local function getBaseURL()
		return if options.GetBaseURL then options.GetBaseURL()else DocumentInfo.baseURL(document,if navigation then navigation:GetURL()else options.URL)
	end
	host.ReadyState="loading"
	host.ParserController=function(node)return if node==document then scriptLoader else nil end
	local function report(message)
		if not runtime.Alive or #runtime.Diagnostics>=100 then return end
		local detail="JavaScript " .. (options.URL or "document") .. ": " .. tostring(message)
		table.insert(runtime.Diagnostics,detail)
		if options.Diagnostic then options.Diagnostic(detail) end
	end
	local depth,batch=0,0
	local entryThreads,waitingEntries={},{}
	local function releaseEntries()
		if #waitingEntries==0 then return end
		local waiting=waitingEntries;waitingEntries={}
		for _,thread in waiting do
			if coroutine.status(thread)~="suspended" then continue end
			if options.ResumeEntry then options.ResumeEntry(thread)
			elseif task then task.defer(thread)
			else local ok,message=coroutine.resume(thread);if not ok then report(message) end end
		end
	end
	local function notify()
		if depth==0 and batch==0 and runtime.Alive and not (loop and loop.Draining) then
			if next(runtime.Pending) and options.Schedule then options.Schedule() end
			if runtime.WakeTasks then runtime.WakeTasks() end
			releaseEntries()
		end
	end
	local function entry(fn)
		if not runtime.Alive then return end
		local thread=coroutine.running()
		while depth>0 and not entryThreads[thread] and not(vm and vm:IsExecutingOnCurrentThread()) do
			-- A synchronous geometry read may wait on Roblox's text service. User
			-- input keeps its native default action suspended until that JS stack
			-- finishes; it must never mutate the realm concurrently with the read.
			assert(coroutine.isyieldable(),"Concurrent JavaScript entry requires a yieldable host task")
			assert(#waitingEntries<1024,"JavaScript entry queue budget exceeded")
			table.insert(waitingEntries,thread);coroutine.yield()
			if not runtime.Alive then return end
		end
		entryThreads[thread]=(entryThreads[thread]or 0)+1
		local previousSteps=if vm and vm:IsExecuting()then vm.Steps else 0
		depth+=1;local ok,message=pcall(WorkContext.runFor,runtime,fn);depth-=1
		entryThreads[thread]-=1;if entryThreads[thread]==0 then entryThreads[thread]=nil end
		local steps=if vm then vm.Steps-previousSteps else 0
		if not ok then report(message) end
		if depth==0 and loop and runtime.Alive then loop:Checkpoint() end
		notify()
		return steps
	end
	local function fontEnvironmentChanged()
		if not runtime.Alive or not fontLoading or host.ReadyState~="complete"
			or not fontLoading:NeedsEnvironmentCheck()then return end
		-- This completed DOM/document boundary already opens the remaining
		-- environment gate. Settle in a budgeted entry, with normal promise
		-- checkpoints and separate font-event tasks, rather than adding a wake.
		entry(function()vm:ExecuteHost(function()fontLoading:EnvironmentChanged()end)end)
	end
	local function controlEntry(action)
		-- Native reads/default actions must wait for an active author stack and
		-- start a fresh budget only at an independent realm boundary. Keep all
		-- results and propagate failures instead of returning a stale snapshot.
		local result
		entry(function()vm:ExecuteHost(function()result=table.pack(pcall(action))end)end)
		assert(result,"Document has been disposed")
		if not result[1]then error(result[2],0)end
		return table.unpack(result,2,result.n)
	end
	runtime.Access=function(_,action)return controlEntry(action)end
	host.Changed=function(node,kind,key,oldValue,knownOldValue)
		local record=runtime.Pending[node]
		if not record then record={Attributes={}};runtime.Pending[node]=record end
		if kind=='language'then record.Language=true
		elseif kind=='editing'then record.Editing=true
		elseif kind=="text" then record.Text=true elseif kind=="children" then record.Children=true else
			if knownOldValue and not record.Attributes[key]then
				record.OldAttributes=record.OldAttributes or {};record.OldAttributes[key]=if oldValue==nil then false else oldValue
			end
			record.Attributes[key]=true
		end
		if scriptLoader and ElementNames.script(node) and (kind=="children" or kind=="text") then scriptLoader:Connect(node) end
		if scriptLoader and kind=="text" and node.Parent and ElementNames.script(node.Parent) then scriptLoader:Connect(node.Parent) end
	end
	host.PostInsert=function(additions)
		if customElements then customElements:Drain()end
		if not scriptLoader then return end
		local scripts,pending={},{}
		for index=#additions,1,-1 do table.insert(pending,additions[index]) end
		while #pending>0 do
			local node=table.remove(pending)
			if ElementNames.html(node,"template") then continue end
			if ElementNames.script(node) then table.insert(scripts,node) end
			for index=#node.Children,1,-1 do table.insert(pending,node.Children[index]) end
		end
		for _,node in scripts do scriptLoader:Connect(node) end
	end
	host.Call=function(fn,args,receiver)entry(function()vm:Call(fn,args,receiver)end)end
	host.CallDirect=function(fn,args,receiver)return vm:Call(fn,args,receiver)end
	host.DOMException=function(message,name)return eventHost:DOMException(message,name)end
	if host.ControlAdapter then
		host.ControlAdapter=table.clone(host.ControlAdapter)
		local origin=require(script.Parent.Parent.DOM.DocumentOrigin).ensure(document,options.URL,options.DocumentOrigin,options.DocumentOriginOpaque)
		if not host.ControlAdapter.IsPickerCrossOrigin then host.ControlAdapter.IsPickerCrossOrigin=function()return options.TopLevelDocumentOrigin~=nil and options.TopLevelDocumentOrigin~=origin end end
		host.ControlAdapter.QueueTask=function(callback)loop:QueueTask(callback)end
		host.ControlAdapter.GetVM=function()return vm end
		host.ControlAdapter.NativeRead=controlEntry
		if not host.ControlAdapter.PatternMismatch then host.ControlAdapter.PatternMismatch=function(node,value)
			return vm.RegExp:PatternMismatch(node.Attributes.pattern,value,(node.Attributes.type or ''):lower()=='email'and node.Attributes.multiple~=nil)
		end end
		host.ControlAdapter.DOMException=function(message,name)return eventHost:DOMException(message,name)end
		host.ControlAdapter.ToString=function(value)
			local primitive=vm.ToPrimitive(value,"string")
			if type(primitive)=="table"and primitive.Kind=="symbol"then VM.throw(VM.error("TypeError","Cannot convert Symbol to DOMString"))end
			return VM.string(primitive)
		end
	end
	host.CreateInlineStyle=function(node,attribute)return cssom:InlineDeclaration(node,function()return node.Attributes.style or ""end,function(source)attribute(node,"style",source)end)end
	host.BeforeInsert=function(parent,index,count)
		if options.BeforeInsert then return options.BeforeInsert(parent,index,count)end
	end
	host.BeforeRemove=function(node,preservingMove)
		if fullscreen and not preservingMove then fullscreen:BeforeRemove(node)end
		if options.PointerCaptureAdapter and options.PointerCaptureAdapter.BeforeRemove then options.PointerCaptureAdapter:BeforeRemove(node,preservingMove)end
		if options.BeforeRemove then options.BeforeRemove(node,preservingMove)end
	end
	host.Get=function(object,key)return vm.Get(object,key)end
	host.Step=function()vm.Step()end
	local globals={}
	local windowOverrides={}
	local windowMethods={}
	window={Get=function(key)
		if windowOverrides[key]~=nil then return windowOverrides[key]end
		if geometry then local value=geometry.WindowGet(key);if value~=nil then return value end end
		if windowMethods[key] then return windowMethods[key] end
		local method=bridge.WindowMethod(key);if method then windowMethods[key]=method;return method end
		return if vm and vm.GlobalEnvironment then vm.GlobalEnvironment:Read(key)else globals[key] or VM.Undefined
	end,Set=function(key,value,strict)
		if geometry and geometry.WindowGet(key)~=nil then windowOverrides[key]=value;return end
		if not vm then globals[key]=value;return end
		return vm.GlobalEnvironment:Write(key,value,strict)
	end,GetOwnPropertyDescriptor=function(key)
		return if vm then vm.GlobalEnvironment:Own(key)else nil
	end,DefineProperty=function(key,descriptor,strict)return vm.GlobalEnvironment:Define(key,descriptor,strict)
	end,Delete=function(key,strict)
		local result=vm.GlobalEnvironment:Delete(key,strict)
		if result then windowOverrides[key]=nil;windowMethods[key]=nil end
		return result
	end,Keys=function(enumerable)return vm.GlobalEnvironment:Keys(enumerable)
	end,Has=function(key)return vm.GlobalEnvironment:Has(key)
	end,IsExtensible=function()return vm.ObjectModel.IsExtensible(vm.GlobalEnvironment.Properties)
	end,PreventExtensions=function()return vm.ObjectModel.PreventExtensionsInternal(vm.GlobalEnvironment.Properties)
	end,GetPrototype=function()return vm.GlobalEnvironment.Properties.Prototype
	end,SetPrototype=function(value)
		vm.GlobalEnvironment.PrototypeSet=true
		return vm.ObjectModel.SetPrototypeInternal(vm.GlobalEnvironment.Properties,value)
	end}
	host.Window=window
	host.AnimationMethod=function(node,key)
		if not animations then return nil end
		return if node==document then animations:DocumentMethod(key)else animations:ElementMethod(node,key)
	end
	host.AnimationGet=function(key)return if animations then animations:DocumentGet(key)else nil end
	host.ElementGet=function(node,key)
		if lifecycle then local value=lifecycle:ElementGet(node,key);if value~=nil then return value end end
		if fullscreen then local value=fullscreen:ElementGet(node,key);if value~=nil then return value end end
		if typedOM then local value=typedOM:ElementGet(node,key);if value~=nil then return value end end
		if editing then local handled,value=editing:Get(node,key);if handled then return value end end
		if pointerCapture then local value=pointerCapture:ElementMethod(node,key);if value~=nil then return value end end
		if topLayer then local value=topLayer:ElementGet(node,key);if value~=nil then return value end end
		if cssom then
			local value=if node==document or node.Kind=="ShadowRoot"then cssom:DocumentGet(node,key)else cssom:NodeGet(node,key)
			if value~=nil then return value end
		end
		if canvas then local method=canvas:Method(node,key);if method then return method end;local handled,value=canvas:Get(node,key);if handled then return value end end
		if node.Kind=="Document" or node.Kind=="ShadowRoot" then
			if ranges and node.Kind=="Document" then local method=ranges.DocumentMethod(key);if method then return method end end
			if selection then local method=selection:DocumentMethod(key);if method then return method end end
		end
		if node==document and navigation then
			if key=="URL" or key=="documentURI" then return navigation:GetURL()end
			if key=="location" then return navigation.WindowGet("location")end
			if key=="baseURI" then return getBaseURL()end
		end
		if geometry then local value=geometry.ElementGet(node,key);if value~=nil then return value end end
		return if options.ElementGet then options.ElementGet(node,key)else nil
	end
	host.Mutation=function(record)
		DocumentInfo.baseMutation(document,if navigation then navigation:GetURL()else options.URL,record)
		if eventHandlerAttributes and record.Type=='childList'then eventHandlerAttributes:Inserted(record.AddedNodes or{})end
		if topLayer then topLayer:NotifyMutation(record)end
		if stylesheetResources then stylesheetResources:NotifyMutation(record)end
		if cssom then cssom:NotifyMutation(record)end
		if mutationObservers then mutationObservers:Notify(record)end
		if options.Mutation then options.Mutation(record)end
	end
	host.ValidateDataAttribute=function(node,key,value)
		if canvas then canvas:ValidateAttribute(node,key,value)end
		if options.ValidateDataAttribute then options.ValidateDataAttribute(node,key,value)end
	end
	host.AttributeChanged=function(node,key,value,oldValue,namespace)
		if eventHandlerAttributes then eventHandlerAttributes:AttributeChanged(node,key,value,oldValue,namespace)end
		if topLayer and not namespace then topLayer:AttributeChanged(node,key,value,oldValue)end
		if canvas and not namespace then canvas:AttributeChanged(node,key)end
		if ElementNames.script(node) then
			if not namespace and key=="async" and value~=nil then node.ScriptAsync=false end
			if scriptLoader and ScriptLoader.sourceAttribute(node,key,namespace)then scriptLoader:Connect(node)end
		end
		if options.AttributeChanged then options.AttributeChanged(node,key,value,oldValue,namespace)end
	end
	host.ElementSet=function(node,key,value,strict)
		if lifecycle and lifecycle:ElementSet(node,key,value,strict)then return true end
		if editing and editing:Set(node,key,value)then return true end
		if topLayer and topLayer:ElementSet(node,key,value,strict)then return true end
		if cssom and (if node==document or node.Kind=="ShadowRoot"then cssom:DocumentSet(node,key,value,strict)else cssom:NodeSet(node,key,value,strict))then return true end
		if canvas and canvas:Set(node,key,value,strict)then return true end
		if node==document and navigation then
			if key=="location" then navigation:SetLocation(value);return true end
			if key=="URL" or key=="documentURI" or key=="baseURI" then
				if strict then VM.throw(VM.error("TypeError","Document URL is read-only"))end;return true
			end
		end
		if geometry and geometry.ElementSet(node,key,value,strict)then return true end
		return options.ElementSet and options.ElementSet(node,key,value,strict)==true
	end
	bridge=DOM.new(document,host)
	globals.window,globals.self,globals.globalThis,globals.document=window,window,window,bridge.Document
	local methods={}
	for _,level in {"log","info","warn","error"} do
		methods[level]=function(args)
			local parts={};for _,v in args do table.insert(parts,VM.string(v)) end
			if options.Console then options.Console(level,table.concat(parts," ")) end
		end
	end
	globals.console={Get=function(key)return methods[key] or VM.Undefined end}
	local mathValues={PI=math.pi,E=math.exp(1)}
	for key,fn in {min=math.min,max=math.max,floor=math.floor,ceil=math.ceil,abs=math.abs,sqrt=math.sqrt,pow=math.pow,round=function(x)return math.floor(x+0.5)end} do
		mathValues[key]=function(args)local numbers={};for i,v in args do numbers[i]=VM.number(v) end;return fn(table.unpack(numbers))end
	end
	globals.Math={Get=function(key)return mathValues[key] or VM.Undefined end}
	loop=EventLoop.new({Clock=options.Clock,MaxSteps=options.MaxSteps or 30000,Report=report,Wake=notify,
		AfterCheckpoint=function()
			if promises then promises:AfterCheckpoint()end
			if audioElements and audioElements.Alive then audioElements:AfterCheckpoint()end
		end,
		Invoke=function(fn,args,kind)
			return entry(function()
				if type(fn)=="string" then vm:Run(fn)
				else vm:Call(fn,args,if kind=="timer" then window else VM.Undefined) end
			end)
		end})
	for key,method in loop.Methods do globals[key]=method end
	promises=Promises.new({Enqueue=function(fn)loop:QueueMicrotask(fn,true)end,Report=report,
		CaptureContext=function()return loop.ContinuationState end,WithContext=function(state,callback)return loop:WithContinuation(state,callback)end,
		QueueTask=function(fn)loop:QueueTask(fn)end,
		RejectionEvent=function(kind,promise,reason)
			return not eventHost:Dispatch(window,eventHost:NewEvent(kind,{promise=promise,reason=reason,cancelable=kind=='unhandledrejection'},'PromiseRejectionEvent'))
		end,
		Construct=function(fn,args)return vm:Construct(fn,args)end,
		Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(object,key,receiver)return vm.Get(object,key,receiver)end,
		Iterator=function(value)return vm.Iterator(value)end,
		Array=function(items)return vm.Array(items)end,Object=function(values)return vm.Object(values)end})
	globals.Promise=promises.Constructor
	local asyncFunctions=AsyncFunctions.new({Create=function()return promises:CreateCapability()end,
		Wait=function(value,fulfilled,rejected)promises:Await(value,fulfilled,rejected)end,
		Resume=function(record,rejected,value)
			-- Only a resumed top-level module body inherits the module-script
			-- destructive-write counter; unrelated timers keep normal semantics.
			local loader=if record.Context and record.Context.ModuleScript then scriptLoader else nil
			if loader then loader.IgnoreDestructiveWrites=(loader.IgnoreDestructiveWrites or 0)+1 end
			local result=table.pack(pcall(vm.ResumeAsync,vm,record,rejected,value))
			if loader then loader.IgnoreDestructiveWrites-=1 end
			if not result[1]then error(result[2],0)end
			return table.unpack(result,2,result.n)
		end})
	vm=VM.new(globals,{MaxSteps=options.MaxSteps or 30000,Async=asyncFunctions,LoadingWork=options.LoadingWork,
		DefaultLocale=options.DefaultLocale,DefaultTimeZone=options.DefaultTimeZone or options.TimeZone,
		DateNow=options.DateNow,DateLocalToUTC=options.DateLocalToUTC,TimezoneOffsetMinutes=options.TimezoneOffsetMinutes})
	bridge.AttachVM(vm)
	vm:Install(function()promises:Attach(vm)end)
	vm:Install(function()vm.Generators:AttachPromises(promises)end)
	vm:Install(function()vm.ResourceStacks:AttachPromises({CreatePromise=function()return promises:CreateCapability()end,
		Await=function(value,fulfilled,rejected)promises:Await(value,function(args)fulfilled(args[1])end,function(args)rejected(args[1])end)end})end)
	eventHost=vm:Install(function()return HostEvents.install(vm,globals,{Report=report,Clock=function()return loop:Timestamp()end,
		AfterCallback=function()if not vm:IsRunningScript()and not loop.Draining then loop:Checkpoint()end end,
		SetTimeout=function(callback,ms)return loop.Methods.setTimeout({callback,ms})end,
		ClearTimeout=function(id)loop.Methods.clearTimeout({id})end})end)
	if eventHost.SetNodeWrapper then eventHost:SetNodeWrapper(bridge.Wrap)end
	local traversal=vm:Install(function()return DOMTraversal.install(vm,globals,{Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,Events=eventHost})end)
	bridge.AttachTraversal(traversal)
	runtime.Traversal=traversal
	ranges=vm:Install(function()return DOMRanges.install(vm,globals,{Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
		Events=eventHost,Context=bridge.RangeContext(),Contents=RangeContents,Changed=function(range,kind)if selection then selection:RangeChanged(range,kind)end;if highlights then highlights:RangeChanged(range)end end,
		RangeRects=function(s)
			if geometry then geometry:Flush()end
			local raw=if selectionAdapter then selectionAdapter:RangeRects(s.StartNode,s.StartOffset,s.EndNode,s.EndOffset)else {}
			return geometry:RectList(raw)
		end,
		RangeBoundingRect=function(s)
			if geometry then geometry:Flush()end
			local raw=if selectionAdapter then selectionAdapter:RangeRects(s.StartNode,s.StartOffset,s.EndNode,s.EndOffset)else {}
			if #raw==0 then return geometry:Rect(0,0,0,0)end
			local area=false;for _,r in raw do if r.Width~=0 and r.Height~=0 then area=true;break end end
			if not area then local r=raw[1];return geometry:Rect(r.X,r.Y,r.Width,r.Height)end
			local first=raw[1];for _,r in raw do if r.Width~=0 or r.Height~=0 then first=r;break end end
			local left,top,right,bottom=first.X,first.Y,first.X+first.Width,first.Y+first.Height
			for _,r in raw do vm.Step();if r.Width~=0 or r.Height~=0 then
				left=math.min(left,r.X);top=math.min(top,r.Y);right=math.max(right,r.X+r.Width);bottom=math.max(bottom,r.Y+r.Height)
			end end
			return geometry:Rect(left,top,right-left,bottom-top)
		end})end)
	bridge.AttachRanges(ranges);runtime.Ranges=ranges
	eventHost:SetRangeFactory(ranges.NewStatic)
	function runtime:StylesheetChanged()
		if not self.Alive then return end
		local record=self.Pending[document]
		if not record then record={Attributes={}};self.Pending[document]=record end
		record.Stylesheet=true
	end
	cssomAdapter=if options.CreateCSSOMAdapter then options.CreateCSSOMAdapter(runtime)else options.CSSOMAdapter
	cssom=vm:Install(function()return CSSOM.install(vm,globals,{Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
		Sources=options.Stylesheets,URL=options.URL,GetBaseURL=getBaseURL,
		InsertImport=function(parent,imported,index,node)return ensureStylesheetResources(false):InsertImport(parent,imported,index,node)end,
		RemoveImport=function(parent,resource)if stylesheetResources then stylesheetResources:RemoveImport(parent,resource)end end,
		Events=eventHost,Adapter=cssomAdapter,Changed=function()runtime:StylesheetChanged()end,CreatePromise=function()return promises:CreateCapability()end,
		QueueTask=function(fn)loop:QueueTask(fn)end})end)
	runtime.CSSOM=cssom
	vm:Install(function()CSSNamespace.install(vm,globals)end)
	network=vm:Install(function()return NetworkData.install(vm,globals,{
		HostEvents=eventHost,BaseURL=options.URL,NativeLineEnding=options.NativeLineEnding or '\r\n',Now=options.Now,
		Fetch=options.Fetch,MaxBytes=options.MaxBytes,
		Origin=options.Origin,ObjectURLStore=options.ObjectURLStore,ObjectURLPartitionKey=options.ObjectURLPartitionKey,MaxObjectURLBytes=options.MaxObjectURLBytes,
		FormDataEntries=function(form,submitter)return formDataDOM:Entries(form,submitter)end,
		FormDataConstructed=function(form,value)formDataDOM:Constructed(form,value)end,
		CreatePromise=function()return promises:CreateCapability()end,
		Enqueue=function(fn)loop:QueueMicrotask(fn)end,
		EnqueueTask=function(fn,delay)return loop:QueueTask(fn,delay)end,CancelTask=function(id)loop:CancelTask(id)end,RequestNow=function()return loop:Timestamp()end,
		Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end,
	})end)
	structuredClone=vm:Install(function()return StructuredClone.install(vm,globals,{HostEvents=eventHost,Binary=network.Binary,NetworkData=network})end)
	performance=vm:Install(function()return Performance.install(vm,globals,{Loop=loop,HostEvents=eventHost,Clone=structuredClone,
		Call=host.Call,Report=report,TimeOrigin=options.PerformanceTimeOrigin})end)
	runtime.Performance=performance
	local origin,documentURL="null","about:blank"
	vm:Install(function()
		local ok,url=pcall(vm.Construct,vm,globals.URL,{options.URL or "about:blank"})
		if ok then origin,documentURL=vm.Get(url,"origin"),vm.Get(url,"href")end
	end)
	messaging=vm:Install(function()return Messaging.install(vm,globals,{HostEvents=eventHost,Clone=structuredClone,Origin=origin,
		EnqueueTask=function(fn)loop:QueueTask(fn)end})end)
	workers=vm:Install(function()return WorkerAdapter.install(vm,globals,{HostEvents=eventHost,Messaging=messaging,Clone=structuredClone,
		BaseURL=documentURL,Origin=origin,Report=report,LoadScript=options.LoadScript,SpawnWorker=options.SpawnWorker,
		SupportsModuleWorkers=options.SupportsModuleWorkers,
		EnqueueTask=function(fn)loop:QueueTask(fn)end})end)
	navigation=vm:Install(function()return Navigation.install(vm,globals,{URL=documentURL,Events=eventHost,Window=window,Clone=structuredClone,
		IsUnloading=function()return lifecycle and lifecycle:IsUnloading()or false end,
		QueueTask=function(fn)loop:QueueTask(fn)end,Navigate=if options.Navigate then function(...)
			if lifecycle and lifecycle:IsUnloading()then return end;return options.Navigate(...)
		end else nil,URLChanged=options.URLChanged,
		ScrollToFragment=options.ScrollToFragment,CaptureScroll=options.CaptureScroll,RestoreScroll=options.RestoreScroll,
		IsFullyActive=function()return runtime.Alive end})end)
	DocumentInfo.baseURL(document,documentURL,true)
	local windowHost=if options.WindowHost then table.clone(options.WindowHost)else nil
	if windowHost and windowHost.Open then local open=windowHost.Open;windowHost.Open=function(...)
		if lifecycle and lifecycle:IsUnloading()then return nil end;return open(...)
	end end
	runtime.BrowsingWindows=vm:Install(function()return BrowsingWindows.install(vm,globals,{Host=windowHost,Window=window,Runtime=runtime,
		GetViewport=function()return if options.ResourceViewport then options.ResourceViewport()else {Width=geometry and geometry.WindowGet('innerWidth')or 0,Height=geometry and geometry.WindowGet('innerHeight')or 0}end,
		GetURL=function()return navigation:GetURL()end,GetBaseURL=getBaseURL,Events=eventHost,Clone=structuredClone,
		HostCall=function(fn)
			-- An async host action can resume inside an enclosing generator.
			-- Recheck there until the actual native entry owns the popup build.
			local function invoke()return if vm.Generators:IsActive()then vm.Generators:HostCall(invoke)else fn()end
			return if vm.Generators:IsActive()then vm.Generators:HostCall(invoke)else asyncFunctions:HostCall(invoke)
		end})end)
	runtime.SimpleDialogs=vm:Install(function()return SimpleDialogs.install(vm,globals,{Host=options.SimpleDialogHost,Window=window,
		GetURL=function()return navigation:GetURL()end,Origin=runtime.DocumentOrigin,Report=report,Resume=options.ResumeEntry,
		CanShow=function()
			return not(lifecycle and lifecycle:IsUnloading())and(if type(options.ModalsAllowed)=='function'then options.ModalsAllowed()else options.ModalsAllowed~=false)
		end,
		HostCall=function(fn)return if vm.Generators:IsActive()then vm.Generators:HostCall(fn)else asyncFunctions:HostCall(fn)end})end)
	runtime.MediaStreams=vm:Install(function()return MediaStreams.install(vm,globals,{Events=eventHost,Report=report,QueueTask=function(fn)loop:QueueTask(fn)end})end)
	runtime.MediaDevices=vm:Install(function()return MediaDevices.install(vm,globals,{Events=eventHost,PermissionHost=options.PermissionHost,MediaCaptureHost=options.MediaCaptureHost,Streams=runtime.MediaStreams,
		Origin=runtime.DocumentOrigin,Allowed=options.PermissionRequestsAllowed~=false,GetURL=function()return navigation:GetURL()end,Report=report,
		CreatePromise=function()return promises:CreateCapability()end,QueueTask=function(fn)loop:QueueTask(fn)end,
		CanRequest=function()return runtime.Alive and not(lifecycle and(lifecycle:IsUnloading()or lifecycle:ElementGet(document,'hidden')))end})end)
	runtime.WebLocks=vm:Install(function()return WebLocks.install(vm,globals,{Store=options.WebLockStore,PartitionKey=options.WebLockPartitionKey,
		Origin=runtime.DocumentOrigin,URL=documentURL,SecureContext=options.SecureContext,Events=eventHost,
		CreatePromise=function()return promises:CreateCapability()end,
		Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end,
		EnqueueTask=function(fn)return loop:QueueTask(fn)end,CancelTask=function(id)loop:CancelTask(id)end,
		IsFullyActive=function()return runtime.Alive and not(lifecycle and lifecycle:IsUnloading())end})end)
	storage=vm:Install(function()return Storage.install(vm,globals,{Events=eventHost,Window=window,
		QueueTask=function(fn)loop:QueueTask(fn)end,GetURL=function()return navigation:GetURL()end,
		GetArea=function(kind)
			if options.GetStorageArea then return options.GetStorageArea(kind)end
			-- The default HTML host has no persistent storage backend. Give a
			-- tuple-origin document a bounded, document-owned memory area; an
			-- explicit denied adapter and opaque origins still throw SecurityError.
			if not origin:match('^https?://')then return nil end
			local area=memoryStorageAreas[kind];if not area then area=Storage.createArea();memoryStorageAreas[kind]=area end;return area
		end})end)
	modules=vm:Install(function()return Modules.install(vm,globals,{BaseURL=documentURL,Promises=promises,
		GetBaseURL=getBaseURL,
		Sources=options.ModuleSources,ImportMap=options.ImportMap,LoadScript=options.LoadScript,
		QueueTask=function(fn)loop:QueueTask(fn)end})end)
	local parseImportMapJSON=vm.Get(globals.JSON,'parse')
	local targetFor
	targetFor=function(node)
		local owner=node and bridge.OwnerBridge(node)
		if owner and owner~=bridge and owner.Host.EventTargetFor then return owner.Host.EventTargetFor(node)end
		local target=if node then bridge.Wrap(node)else window
		eventHost:WrapTarget(target,{Handlers=EventHandlerAttributes.names(node)~=nil,GlobalErrorHandler=node==nil,HandlerNames=EventHandlerAttributes.names(node),
			HandlerTarget=function(key)return if eventHandlerAttributes then eventHandlerAttributes:Target(node,key)else nil end,Parent=function(_,event)
			if not node then return nil elseif node==document then return window end
			local targetNode=vm.Get(event,"target");targetNode=if type(targetNode)=="table"then targetNode.DOMNode else nil
			local parent=ShadowTree.EventParent(node,vm.Get(event,"composed")==true,targetNode)
			if parent then return targetFor(parent)end
			return nil
		end})
		if eventHandlerAttributes then if node then eventHandlerAttributes:Bind(node,target)else eventHandlerAttributes:SyncBody()end end
		return target
	end
	host.EventTargetFor=targetFor;host.EventHost=eventHost
	lifecycle=vm:Install(function()return DocumentLifecycle.install(vm,globals,{Document=document,Window=window,Events=eventHost,
		TargetFor=targetFor,Access=controlEntry,QueueTask=function(fn)loop:QueueTask(fn)end,Visible=options.Visible~=false,
		BeforeTransition=function()runtime.SimpleDialogs:Cancel();runtime.MediaDevices:CancelPending()end,ConfirmLeave=options.ConfirmLeave,ModalsAllowed=options.ModalsAllowed})end)
	runtime.Lifecycle=lifecycle
	runtime.Scheduler=vm:Install(function()return Scheduler.install(vm,globals,{Loop=loop,Events=eventHost,Promises=promises})end)
	runtime.IdleCallbacks=vm:Install(function()return IdleCallbacks.install(vm,globals,{Loop=loop,Window=window,GetBudget=options.IdleBudget,
		CanRun=function()return runtime.Alive and not lifecycle:IsUnloading()and not lifecycle:ElementGet(document,'hidden')end,
		Wake=notify,Report=report,
		Invoke=function(callback,deadline)return entry(function()loop:WithContinuation(runtime.Scheduler:IdleState(),function()vm:Call(callback,{deadline},VM.Undefined)end)end)end})end)
	function runtime:SetVisible(show)if self.Alive then if not show then runtime.MediaDevices:CancelPending()end;lifecycle:SetVisible(show)end end
	function runtime:InitializeVisibility(show)return self.Alive and lifecycle:InitializeVisibility(show)or false end
	function runtime:RequestLeave(request)
		if not self.Alive then return false end
		local ok,result=pcall(lifecycle.RequestLeave,lifecycle,request);notify()
		if not ok then error(result,0)end;return result
	end
	function runtime:CommitLeave()if self.Alive then lifecycle:CommitLeave()end end
	host.EraseListeners=function(node)eventHost:EraseListeners(targetFor(node))end
	bridge.Details:Start(document,{
		QueueTask=function(fn)return loop:QueueTask(fn)end,
		CancelTask=function(id)loop:CancelTask(id)end,
		Fire=function(node,old,new)
			eventHost:Dispatch(targetFor(node),eventHost:NewEvent("toggle",{oldState=old,newState=new},"ToggleEvent"),true)
		end,
	})
	host.Adopted=function(node,oldDocument,newDocument,destination)
		if eventHandlerAttributes then eventHandlerAttributes:Adopted(node,destination)end
		if destination.Host.EventHost then
			eventHost:TransferTarget(bridge.Wrap(node),destination.Host.EventHost)
			destination.Host.EventTargetFor(node)
		end
		if audioElements then audioElements:Adopted(node,destination.Host.AudioElements)end
		if options.Adopted then options.Adopted(node,oldDocument,newDocument,destination)end
	end
	targetFor(nil)
	vm:Install(function()
		bridge.AttachShadow(vm,{Events=eventHost,TargetFor=targetFor,Enqueue=function(fn)loop:QueueMicrotask(fn)end})
		local context=bridge.CustomContext();context.Events=eventHost;context.Report=report;context.CreatePromise=function()return promises:CreateCapability()end
		context.Network=network;context.TargetFor=targetFor;context.ReportValidity=options.ReportValidity or(host.ControlAdapter and host.ControlAdapter.ReportValidity)
		customElements=CustomElements.install(vm,globals,context);bridge.AttachCustomElements(customElements)
		bridge.InstallInterfaces(vm,globals)
		network.XMLHttpRequest:AttachDocumentIntrinsics(globals.DOMParser,globals.XMLSerializer)
		local windowConstructor,namedObject=DOMNamedProperties.window(vm,document,bridge.NamedProperties,vm.GlobalEnvironment,vm.Get(globals.EventTarget,'prototype'))
		globals.Window=windowConstructor;vm.Global.Bindings.Window={Value=windowConstructor};runtime.WindowNamedProperties=namedObject
		ScriptLoader.installSupport(vm,globals)
		pointerCapture=PointerCapture.install(vm,{Wrap=bridge.Wrap,Events=eventHost,Adapter=options.PointerCaptureAdapter})
	end)
	runtime.CustomElements=customElements;runtime.ElementInternals=customElements.Internals;runtime.ShadowDOM=bridge.Shadow;runtime.PointerCapture=pointerCapture
	formDataDOM=FormDataDOM.new(vm,bridge,document,{Network=network,Events=eventHost,TargetFor=targetFor,
		GetFiles=options.GetFiles,Direction=options.FormDataDirection})
	host.EventMethod=function(node,key)
		if key~='addEventListener'and key~='removeEventListener'and key~='dispatchEvent'then return nil end
		return eventHost:TargetMethods(targetFor(node),key)
	end
	host.EventGet=function(node,key)
		local names=EventHandlerAttributes.names(node)
		return if names and names[key]then eventHost:HandlerGet(targetFor(node),key)else nil
	end
	host.EventSet=function(node,key,value,strict)
		local names=EventHandlerAttributes.names(node)
		if not names or not names[key]then return false end
		eventHost:HandlerSet(targetFor(node),key,value);return true
	end
	eventHandlerAttributes=vm:Install(function()return EventHandlerAttributes.install(vm,{Document=document,Bridge=bridge,Window=window,
		Events=eventHost,TargetFor=targetFor,Report=report,GetURL=function()return navigation:GetURL()end,ScriptingEnabled=options.ScriptingEnabled})end)
	host.EventHandlerAttributes=eventHandlerAttributes;runtime.EventHandlerAttributes=eventHandlerAttributes
	vm:Install(function()eventHandlerAttributes:Inserted({document})end)
	if options.Events and options.Events.BeforeEmit then
		eventConnection=options.Events:BeforeEmit(function(nativeEvent)
			entry(function()
				vm:ExecuteHost(function()
					local init=table.clone(nativeEvent.Data)
					if init.isTrusted~=false and(nativeEvent.Type=='mousedown'or nativeEvent.Type=='touchend'or nativeEvent.Type=='click'
						or nativeEvent.Type=='keydown'and init.key~='Escape'and init.key~='Shift'and init.key~='Control'and init.key~='Alt'and init.key~='Meta'
						and not init.altKey and not init.ctrlKey and not init.metaKey)then lifecycle:NotifyUserActivation()end
					init.bubbles,init.cancelable,init.composed=nativeEvent.Bubbles,nativeEvent.Cancelable,nativeEvent.Data.composed==true
					if init.relatedTarget then init.relatedTarget=bridge.Wrap(init.relatedTarget)end
					if nativeEvent.Type:sub(1,5)=="touch"then init=eventHost:NativeTouchInit(init,bridge.Wrap)end
					init.submitter=if init.Submitter then bridge.Wrap(init.Submitter)else VM.Null
					init.view=window
					local event=eventHost:NewEvent(nativeEvent.Type,init,eventHost:EventClassForType(nativeEvent.Type))
					for _,key in {'key','code','repeat','altKey','ctrlKey','metaKey','shiftKey','button','buttons','clientX','clientY','pageX','pageY','screenX','screenY','pointerId','pointerType','isPrimary','deltaX','deltaY','deltaZ','deltaMode','inputType','data','oldState','newState','source'}do
						local value=init[key]
						if value~=nil then vm.DefineProperty(event,key,vm.Object({value=value,enumerable=true,configurable=true},VM.Null))end
					end
					if not eventHost:Dispatch(targetFor(nativeEvent.Target),event,nativeEvent.Data.isTrusted~=false)then nativeEvent:PreventDefault()end
				end)
			end)
		end)
	end
	runtime.VM,runtime.DOM,runtime.Window,runtime.EventLoop,runtime.Promises=vm,bridge,window,loop,promises
	runtime.HostEvents=eventHost
	runtime.Network=network
	runtime.StructuredClone,runtime.Messaging=structuredClone,messaging
	runtime.Workers,runtime.Storage,runtime.Navigation=workers,storage,navigation
	runtime.Modules=modules
	fullscreen=vm:Install(function()return Fullscreen.install(vm,{Document=document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
		Events=eventHost,TargetFor=targetFor,Promise=function()
			local promise,resolve,reject=promises:CreateCapability()
			return {Promise=promise,Resolve=function(value)resolve({value})end,Reject=function(value)reject({value})end}
		end,
		QueueTask=function(fn)return loop:QueueTask(fn)end,Access=controlEntry,
		HasUserActivation=host.ControlAdapter and host.ControlAdapter.HasUserActivation,
		Adapter=if options.CreateFullscreenAdapter then options.CreateFullscreenAdapter(runtime)else options.FullscreenAdapter})end)
	runtime.Fullscreen=fullscreen
	topLayerAdapter=if options.CreateTopLayerAdapter then options.CreateTopLayerAdapter(runtime)else options.TopLayerAdapter
	topLayer=vm:Install(function()return TopLayer.install(vm,globals,{Document=document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
		Events=eventHost,TargetFor=targetFor,QueueTask=function(fn)return loop:QueueTask(fn)end,
		CancelTask=function(id)loop:CancelTask(id)end,Adapter=topLayerAdapter})end)
	-- Native default actions share the same serialized entry and instruction
	-- budget as author callbacks, including geometry reads which may yield.
	for _,name in {"NativeAction","Escape","PointerDown","PointerUp"}do
		local action=topLayer[name]
		topLayer[name]=function(self,...)
			local args=table.pack(...);local result=false
			entry(function()result=vm:ExecuteHost(function()return action(self,table.unpack(args,1,args.n))end)end)
			return result
		end
	end
	runtime.TopLayer=topLayer
	function runtime:ReportFormValidity(form)
		return controlEntry(function()return bridge.Controls:Method(form,"reportValidity")({})end)
	end
	function runtime:ToggleDetails(node)
		-- Serialize native default actions with author callbacks and deliver the
		-- normal attribute mutation record before the batched renderer flush.
		entry(function()vm:ExecuteHost(function()
			bridge.Attribute(node,"open",if node.Attributes.open==nil then "" else nil)
		end)end)
	end
	canvasAdapter=if options.CreateCanvasAdapter then options.CreateCanvasAdapter(runtime)else options.CanvasAdapter
	if not canvasAdapter then
		local surfaces=setmetatable({},{__mode='k'})
		canvasAdapter={Surface=function(_,node,create)
			local value=surfaces[node];if not value and create~=false then local _,w=canvas:Get(node,'width');local _,h=canvas:Get(node,'height');value=CanvasSurface.new(w,h);surfaces[node]=value end;return value
		end,Reset=function(_,node,w,h)local value=CanvasSurface.new(w,h);surfaces[node]=value;return value end,
			Destroy=function()table.clear(surfaces)end}
	end
	canvas=vm:Install(function()return DOMCanvas.install(vm,globals,{
		Binary=network.Binary,HostEvents=eventHost,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
		Surface=function(node,create)return canvasAdapter:Surface(node,create)end,
		Reset=function(node,w,h)return canvasAdapter:Reset(node,w,h)end,
		Publish=if canvasAdapter.Publish then function(node)canvasAdapter:Publish(node)end else nil,
		ImageSource=if canvasAdapter.ImageSource then function(node)return canvasAdapter:ImageSource(node)end else nil,
		Attribute=function(node,key,value)local target=bridge.Wrap(node);vm:Call(vm.Get(target,'setAttribute'),{key,value},target)end,
		CreateBlob=function(state)return network:CreateBlob(state)end,QueueTask=function(fn)loop:QueueTask(fn)end,
		Call=host.CallDirect,
		HostCall=function(fn)return if vm.Generators:IsActive()then vm.Generators:HostCall(fn)else asyncFunctions:HostCall(fn)end,
	})end)
	runtime.Canvas=canvas
	function runtime:IsExecuting()return depth>0 or lifecycle:IsUnloading()end
	function runtime:PumpTasks(): number
		if depth>0 or not self.Alive or lifecycle:IsUnloading()then return 0 end
		batch+=1;local count=loop:PumpTasks();batch-=1;notify();return count
	end
	function runtime:PumpFrame(): number
		if depth>0 or not self.Alive or lifecycle:IsUnloading()then return 0 end
		batch+=1;local count=loop:PumpFrame();batch-=1;notify();return count
	end
	function runtime:HasPending(): boolean return self.Alive and next(self.Pending)~=nil end
	function runtime:Flush(): (boolean, any?)
		if not self:HasPending() then return false end
		local changes=self.Pending;self.Pending={};self.Flushes+=1
		local ok,layout,items=pcall(options.ApplyChanges,changes)
		if not ok then report("DOM update: " .. tostring(layout));return true end
		-- The caller schedules layout after Flush returns. Retain that dependency
		-- here before checking fonts; a later paint batch cannot release it.
		if layout==true then fontLayoutPending=true end
		-- Paint-only batches can release font-environment dependencies too.
		-- Recheck on this boundary rather than waiting for another layout/frame.
		fontEnvironmentChanged()
		-- A successful paint-only recascade republishes author pixels too.
		-- Restore held script samples before a same-script computed-style read,
		-- without waiting for another frame or rerunning normal flow layout.
		if layout~=true and animations then animations:AfterLayout()end
		return layout==true,items
	end
	local geometryAdapter=if options.CreateGeometryAdapter then options.CreateGeometryAdapter(runtime)else table.clone(options.GeometryAdapter or {})
	if geometryAdapter.Flush then
		local nativeFlush=geometryAdapter.Flush
		geometryAdapter.Flush=function()return if vm.Generators:IsActive()then vm.Generators:HostCall(nativeFlush)else asyncFunctions:HostCall(nativeFlush)end
	end
	geometryAdapter.Wrap=bridge.Wrap
	geometryAdapter.Unwrap=function(value)return bridge.Unwrap(value)end
	geometryAdapter.Events=eventHost
	geometryAdapter.Binary=network.Binary
	geometryAdapter.QueueTask=function(fn)loop:QueueTask(fn)end
	geometryAdapter.CreatePromise=function()return promises:CreateCapability()end
	geometryAdapter.Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end
	geometryAdapter.StyleDeclarations=cssom.Declarations
	geometry=vm:Install(function()return Geometry.install(vm,globals,geometryAdapter)end)
	structuredClone.Geometry=geometry
	runtime.Geometry=geometry
	typedOM=vm:Install(function()return TypedOM.install(vm,globals,{Wrap=bridge.Wrap,Unwrap=bridge.Unwrap})end)
	selectionAdapter=if options.CreateSelectionAdapter then options.CreateSelectionAdapter(runtime)else options.SelectionAdapter
	local selectionPaintQueued=false
	local function queueSelectionPaint()
		if selectionPaintQueued or not runtime.Alive then return end;selectionPaintQueued=true
		local ok,message=pcall(function()loop:QueueTask(function()
			selectionPaintQueued=false
			if runtime.Alive then geometry:Flush();selection:FlushPaint();if editingAdapter and editingAdapter.Sync then editingAdapter:Sync()end end
		end)end)
		if not ok then selectionPaintQueued=false;error(message,0)end
	end
	selection=vm:Install(function()return Selection.install(vm,globals,{Ranges=ranges,Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
		Events=eventHost,TargetFor=targetFor,QueueTask=function(fn)loop:QueueTask(fn)end,Adapter=selectionAdapter,SchedulePaint=queueSelectionPaint,
		StyleFor=function(node)local tree=geometryAdapter.GetTree and geometryAdapter.GetTree();return tree and tree.NodeStyles and tree.NodeStyles[node]end,
		MoveVisual=if selectionAdapter and selectionAdapter.MoveVisual then function(...)geometry:Flush();return selectionAdapter:MoveVisual(...)end else nil,
		ControlText=function()
			local adapter=host.ControlAdapter;local active=adapter and adapter.GetActiveElement and adapter.GetActiveElement()
			if not active or not bridge.Controls then return nil end
			return bridge.Controls:SelectionText(active)
		end,
		RenderedText=if selectionAdapter and selectionAdapter.RenderedText then function(s)
			geometry:Flush();return selectionAdapter:RenderedText(s.StartNode,s.StartOffset,s.EndNode,s.EndOffset,s.TrailingBlockBreaks)
	end else nil})end)
	runtime.Selection=selection;runtime.SelectionAdapter=selectionAdapter
	highlights=vm:Install(function()return Highlights.install(vm,globals,{Ranges=ranges,QueueTask=function(fn)loop:QueueTask(fn)end,Flush=function()geometry:Flush()end,
		Paint=if selectionAdapter and selectionAdapter.PaintHighlights then function(records)selectionAdapter:PaintHighlights(records)end else nil})end)
	editingAdapter=if options.CreateEditingAdapter then options.CreateEditingAdapter(runtime)else options.EditingAdapter
	editing=vm:Install(function()return Editing.install(vm,{Document=document,DOM=bridge,Ranges=ranges,Selection=selection,
		Changed=function(node)
			host.Changed(node,'editing')
			if editingAdapter then if editingAdapter.EditingChanged then editingAdapter:EditingChanged()elseif editingAdapter.Sync then editingAdapter:Sync()end end
		end,
		Emit=function(node,kind,data,targetRange)
			local init=table.clone(data);if targetRange then init.targetRanges={targetRange}end
			return eventHost:Dispatch(targetFor(node),eventHost:NewEvent(kind,init,"InputEvent"),true)
		end})end)
	runtime.Editing=editing;runtime.EditingAdapter=editingAdapter
	local function editingEntry(action)
		local result;entry(function()vm:ExecuteHost(function()result=action()end)end);return result
	end
	function runtime:EditingSnapshot(node)return editingEntry(function()return editing:Snapshot(node)end)end
	function runtime:CommitEditing(node,text,inputType,cursor,anchor)return editingEntry(function()return editing:Commit(node,text,inputType,cursor,anchor)end)end
	function runtime:SelectEditing(node,cursor,anchor)return editingEntry(function()return editing:Select(node,cursor,anchor)end)end
	function runtime:NavigateEditing(node,extend,direction,granularity)return editingEntry(function()return editing:Navigate(node,extend,direction,granularity)end)end
	if selectionAdapter and selectionAdapter.SetNativeChange then selectionAdapter:SetNativeChange(function(anchor,ao,focus,fo)
		local accepted=false
		entry(function()vm:ExecuteHost(function()accepted=selection:NativeChange(anchor,ao,focus,fo)end)end)
		queueSelectionPaint();return accepted
	end)end
	for _,key in {'innerWidth','innerHeight','scrollX','scrollY','pageXOffset','pageYOffset','devicePixelRatio'}do
		vm.Global.Bindings[key]={Get=function()return if windowOverrides[key]~=nil then windowOverrides[key]else geometry.WindowGet(key)end,
			Set=function(value)windowOverrides[key]=value end}
	end
	mutationObservers=vm:Install(function()return MutationObserver.install(vm,globals,{Wrap=bridge.Wrap,Unwrap=geometryAdapter.Unwrap,Report=report,
		Enqueue=function(fn)loop:QueueMicrotask(fn)end})end)
	runtime.MutationObservers=mutationObservers
	local function observerCall(fn,args,receiver)
		local result=VM.Undefined
		entry(function()result=vm:Call(fn,args,receiver)end)
		-- Observer delivery is a native callback boundary. Its measurement gate
		-- and task wrapper are not author-script frames: drain before the next
		-- observer, while synchronous events inside the callback stay nested.
		if runtime.Alive and not vm:IsRunningScript()and not loop.Draining then loop:Checkpoint()end
		return result
	end
	local observerLayoutQueued=false
	local observerLayoutTime=nil
	local function queueObserverLayout(timestamp)
		if not runtime.Alive then return end
		observerLayoutTime=timestamp
		if observerLayoutQueued then return end
		observerLayoutQueued=true
		loop:QueueTask(function()
			observerLayoutQueued=false
			local time=observerLayoutTime;observerLayoutTime=nil
			-- Tasks already run inside a realm entry. Deliver directly here;
			-- applying the public entry guard again would reschedule forever.
			if runtime.Alive and layoutObservers then layoutObservers:AfterLayout(time)end
		end)
	end
	function runtime:AfterLayout(timestamp)
		if self.Alive then fontLayoutPending=false end
		if self.Alive and (imageResources or fontLoading) then
			entry(function()vm:ExecuteHost(function()
				if imageResources then imageResources:ViewportChanged()end
				if fontLoading then fontLoading:AfterLayout()end
			end)end)
		end
		if animations then animations:AfterLayout()end
		if editingAdapter and editingAdapter.AfterLayout then editingAdapter:AfterLayout()end
		if not self.Alive or not layoutObservers then return end
		if depth>0 or loop.Draining then queueObserverLayout(timestamp)
		else
			-- Measurement and entry construction also consume VM instructions.
			-- Give each independent publication its own budget, while callbacks
			-- share that budget and native measurement yields keep the realm gated.
			entry(function()vm:ExecuteHost(layoutObservers.AfterLayout,layoutObservers,timestamp)end)
		end
	end
	function runtime:ImageLayoutCompleted()
		if not self.Alive or not imageResources then return end
		-- This native publication may wait behind a suspended author entry.
		-- Disposal cancels the message; strict live-object Access stays strict.
		entry(function()vm:ExecuteHost(function()
			if self.Alive and imageResources then imageResources:AfterLayout()end
		end)end)
	end
	function runtime:FontLayoutCompleted()
		if not self.Alive then return end
		fontLayoutPending=false;fontEnvironmentChanged()
	end
	layoutObservers=vm:Install(function()return LayoutObservers.install(vm,globals,{
		Geometry=geometry,Wrap=bridge.Wrap,Unwrap=geometryAdapter.Unwrap,
		GetViewport=geometryAdapter.GetViewport,GetTree=geometryAdapter.GetTree,
		GetBox=geometryAdapter.GetBox,GetResizeBoxes=geometryAdapter.GetResizeBoxes,GetIntersectionClips=geometryAdapter.GetIntersectionClips,
		GetVisibility=geometryAdapter.GetVisibility,Call=observerCall,Report=report,
		QueueTask=function(fn)loop:QueueTask(fn)end,Now=function()return loop:Timestamp()end,
		Schedule=function(callback,ms)return loop.Methods.setTimeout({callback,ms})end,
		RequestLayout=function()queueObserverLayout(nil)end,
		ReportResizeLoopError=report,
	})end)
	runtime.LayoutObservers=layoutObservers
	animationAdapter=if options.CreateAnimationAdapter then options.CreateAnimationAdapter(runtime)else options.AnimationAdapter
	animations=vm:Install(function()return WebAnimations.install(vm,globals,{
		HostEvents=eventHost,Document=bridge.Document,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,TargetFor=targetFor,
		CreatePromise=function()return promises:CreateCapability()end,Now=function()return loop:Timestamp()end,
		MarkPromiseHandled=function(promise)promises:MarkHandled(promise)end,
		RequestFrame=function(callback)return loop.Methods.requestAnimationFrame({function(args)callback(args[1])end})end,
		CancelFrame=function(id)loop.Methods.cancelAnimationFrame({id})end,
		QueueTask=function(callback)loop:QueueTask(callback)end,Report=report,
		PrepareCommit=function()geometry:Flush()end,
		SampleCommit=if animationAdapter and animationAdapter.SampleCommit then function(node,stack,properties)return animationAdapter:SampleCommit(node,stack,properties)end else nil,
		WriteCommittedStyle=function(node,declarations,force)
			cssom.Declarations:CommitProperties(vm.Get(bridge.Wrap(node),"style"),declarations,force)
		end,
		NormalizeFrames=if animationAdapter and animationAdapter.NormalizeFrames then function(frames)return animationAdapter:NormalizeFrames(frames)end else nil,
		TargetedProperties=if animationAdapter and animationAdapter.TargetedProperties then function(frames)return animationAdapter:TargetedProperties(frames)end else nil,
		Validate=if animationAdapter and animationAdapter.Validate then function(node,frames,composite)return animationAdapter:Validate(node,frames,composite)end else nil,
		Apply=if animationAdapter then function(node,frames,timing,animation,composite,iterationComposite)animationAdapter:Apply(node,frames,timing,animation,composite,iterationComposite)end else nil,
		Release=if animationAdapter then function(node,animation)animationAdapter:Release(node,animation)end else nil,
		GetCSSRecords=if animationAdapter and animationAdapter.GetCSSRecords then function()return animationAdapter:GetCSSRecords()end else nil,
		AcquireCSSRecord=if animationAdapter and animationAdapter.AcquireCSSRecord then function(record)animationAdapter:AcquireCSSRecord(record)end else nil,
		ApplyCSSRecord=if animationAdapter and animationAdapter.ApplyCSSRecord then function(record,frames,timing,animation,composite,iterationComposite)animationAdapter:ApplyCSSRecord(record,frames,timing,animation,composite,iterationComposite)end else nil,
		ReleaseCSSRecord=if animationAdapter and animationAdapter.ReleaseCSSRecord then function(record,cancel)animationAdapter:ReleaseCSSRecord(record,cancel)end else nil,
		SubscribeCSSRecords=if animationAdapter and animationAdapter.SubscribeCSSRecords then function(callback)return animationAdapter:SubscribeCSSRecords(function()if runtime.Alive then entry(function()vm:ExecuteHost(callback)end)end end)end else nil,
	})end)
	runtime.Animations=animations
	local scrollTargets={}
	function runtime:ScrollChanged(node)
		if not self.Alive then return end
		local target=node or document
		if scrollTargets[target] then return end;scrollTargets[target]=true
		loop:QueueTask(function()
			if not self.Alive then return end;scrollTargets[target]=nil
			options.Events:Emit(target,"scroll",nil,{Bubbles=target==document,Cancelable=false})
			layoutObservers:ScrollChanged()
		end)
	end
	function runtime:Run(source: string,scriptNode: any?,sourceURL: string?)
		local succeeded,message=false,nil
		entry(function()
			local previous=host.CurrentScript;host.CurrentScript=if scriptNode and ShadowTree.Root(scriptNode).Kind~='ShadowRoot'then scriptNode else nil
			local ok,failure=pcall(vm.ExecuteHost,vm,function()return vm:Run(source,sourceURL or navigation:GetURL())end)
			-- Classic-script cleanup performs its microtask checkpoint before
			-- the HTML execution algorithm restores document.currentScript.
			if not vm:IsRunningScript() then loop:Checkpoint() end;host.CurrentScript=previous
			succeeded,message=ok,failure
			if not ok then error(failure,0) end
		end)
		return succeeded,message
	end
	function runtime:RunModule(specifier,attributes,inlineSource)
		local result
		entry(function()result=vm:ExecuteHost(function()return modules:Run(specifier,navigation:GetURL(),attributes,inlineSource)end)end)
		return result
	end
	function runtime:HasOwnBlockingStylesheets(): boolean return self.Alive and stylesheetResources~=nil and stylesheetResources:HasBlockingScripts()end
	function runtime:HasBlockingStylesheets(): boolean
		return self.Alive and (self:HasOwnBlockingStylesheets()or(options.HasParentBlockingStylesheets and options.HasParentBlockingStylesheets()==true))or false
	end
	function runtime:IsDocumentComplete(): boolean return self.Alive and scriptLoader~=nil and scriptLoader:IsDocumentComplete()end
	function runtime:ResourcesChanged()if self.Alive and scriptLoader then scriptLoader:ResourcesChanged()end end
	function runtime:SubscribeStylesheetChanges(callback)
		assert(self.Alive and type(callback)=='function','Stylesheet subscription requires a live realm and callback')
		stylesheetListeners[callback]=true
		return function()stylesheetListeners[callback]=nil end
	end
	local function stylesheetsChanged()
		if not runtime.Alive then return end
		if scriptLoader then scriptLoader:ResourcesChanged()end
		local listeners={};for callback in stylesheetListeners do table.insert(listeners,callback)end
		for _,callback in listeners do if stylesheetListeners[callback]then callback()end end
	end
	function runtime:Start()
		if self.Started or not self.Alive then return end;self.Started=true
		scriptLoader=ScriptLoader.new(vm,{Document=document,BaseURL=navigation:GetURL(),GetBaseURL=getBaseURL,
			URLConstructor=globals.URL,Modules=modules,Promises=promises,LoadScript=options.LoadScript,
		Sources=options.ScriptSources,Report=report,
			HasBlockingStylesheets=function()return runtime:HasBlockingStylesheets()end,
			GetPendingResources=function()return (if imageResources then imageResources.Pending else 0)+(if audioElements then audioElements.Pending else 0)+(if stylesheetResources then stylesheetResources.Pending else 0)+(if options.GetPendingEmbeddedResources then options.GetPendingEmbeddedResources()else 0)end,
			RegisterImportMap=function(source,baseURL)
				local parsed=vm:Call(parseImportMapJSON,{source},globals.JSON)
				if not vm.ObjectModel.IsObject(parsed)or vm.IsArray(parsed)then VM.throw(VM.error('TypeError','Import map must be an object'))end
				local function entries(value)
					if not vm.ObjectModel.IsObject(value)or vm.IsArray(value)then VM.throw(VM.error('TypeError','Import map entries must be an object'))end
					local result={};for _,key in vm.OwnKeys(value,true)do if type(key)=='string'then result[key]=vm.Get(value,key)end end;return result
				end
				local imports,scopes=vm.Get(parsed,'imports'),vm.Get(parsed,'scopes');local map={Imports={},Scopes={}}
				if imports~=VM.Undefined then map.Imports=entries(imports)end
				if scopes~=VM.Undefined then for scope,value in entries(scopes)do map.Scopes[scope]=entries(value)end end
				modules:RegisterImportMap(map,baseURL)
			end,
			QueueTask=function(fn)loop:QueueTask(fn)end,QueueMicrotask=function(fn)loop:QueueMicrotask(fn)end,
			SetReadyState=function(value)host.ReadyState=value;fontEnvironmentChanged();if value~='complete'and options.DocumentLoadStateChanged then options.DocumentLoadStateChanged(value)end end,
			DocumentLoaded=function()
				lifecycle:Loaded()
				if options.DocumentLoadStateChanged then options.DocumentLoadStateChanged('complete')end
			end,
			Emit=function(node,kind)eventHost:Dispatch(targetFor(node),eventHost:NewEvent(kind,{},'Event'),true,if node==nil and kind=='load'then targetFor(document)else nil)end,
			ExecuteClassic=function(source,node,url)
				self.ScriptsRun+=1;return self:Run(source,node,url)
			end})
		self.ScriptLoader=scriptLoader
		if options.SubscribeParentStylesheetChanges then parentStylesheetSubscription=options.SubscribeParentStylesheetChanges(stylesheetsChanged)end
		local parser=options.ParserSession
		if parser then
			parser:SetElementHook(bridge.ParserElement)
			parser:SetShadowHook(function(root)if self.Alive then host.Changed(root.Host,'children')end end)
			parser:SetMutationHook(function(record)
				if not self.Alive then return end
				host.Mutation(record)
				host.Changed(record.Target,if record.Type=="characterData"then"text"else"children")
				if record.Type=="childList"then host.PostInsert(record.AddedNodes or{})end
			end)
			scriptLoader:StartParser(parser,options.ParserFirstScript)
		else scriptLoader:Start(Runtime.scripts(document))end
	end
	function runtime:Destroy()
		if not self.Alive then return end;lifecycle:Destroy();self.Alive=false
		RealmAccess.destroy(self)
		runtime.MediaDevices:Destroy()
		runtime.MediaStreams:Destroy()
		if fullscreen then fullscreen:Destroy()end
		if parentStylesheetSubscription then parentStylesheetSubscription();parentStylesheetSubscription=nil end;table.clear(stylesheetListeners)
		releaseEntries()
		if eventConnection then eventConnection:Disconnect();eventConnection=nil end
		if topLayer then topLayer:Destroy()end
		if customElements then customElements:Destroy()end
		if pointerCapture then pointerCapture:Destroy()end
		if topLayerAdapter and topLayerAdapter.Destroy then topLayerAdapter:Destroy()end
		if cssom then cssom:Destroy()end
		if typedOM then typedOM:Destroy()end
		if highlights then highlights:Destroy()end
		if cssomAdapter and cssomAdapter.Destroy then cssomAdapter:Destroy()end
		if selection then selection:Destroy()end
		if editing then editing:Destroy()end
		if editingAdapter and editingAdapter.Destroy then editingAdapter:Destroy()end
		if selectionAdapter and selectionAdapter.Destroy then selectionAdapter:Destroy()end
		mutationObservers:Destroy()
		layoutObservers:Destroy();table.clear(scrollTargets)
		modules:Destroy()
		if scriptLoader then scriptLoader:Destroy()end
		if stylesheetResources then stylesheetResources:Destroy()end
		if eventHandlerAttributes then eventHandlerAttributes:Destroy()end
		if imageResources then imageResources:Destroy()end
		if audioElements then audioElements:Destroy()end
		if fontLoading then fontLoading:Destroy()end
		if animations then animations:Destroy()end
		if performance then performance:Destroy()end
		if animationAdapter and animationAdapter.Destroy then animationAdapter:Destroy()end
		if formDataDOM then formDataDOM:Destroy()end
		if canvas then canvas:Destroy()end
		if canvasAdapter and canvasAdapter.Destroy then canvasAdapter:Destroy()end
		workers:Destroy();storage:Destroy();navigation:Destroy();messaging:Destroy();structuredClone:Destroy()
		for _,area in memoryStorageAreas do table.clear(area.Values);table.clear(area.Order);area.Bytes=0 end;table.clear(memoryStorageAreas)
		geometry:Destroy();if geometryAdapter.Destroy then geometryAdapter.Destroy()end
		runtime.WebLocks:Destroy();runtime.Scheduler:Destroy();network:Destroy()
		eventHost:Destroy()
		asyncFunctions:Destroy()
		runtime.IdleCallbacks:Destroy();promises:Destroy();loop:Destroy();if self.WakeTasks then self.WakeTasks() end;self.WakeTasks=nil
		bridge:Destroy();vm:Destroy();runtime.SimpleDialogs:Destroy();table.clear(self.Pending);table.clear(windowMethods);table.clear(windowOverrides);table.clear(globals);table.clear(host);table.clear(options)
	end
	ensureStylesheetResources=function(scan)
		if stylesheetResources then return stylesheetResources end
		local create=function()return StylesheetResources.install(vm,globals,{
			Document=document,URL=options.URL,GetBaseURL=getBaseURL,
			Scan=scan,
			Sources=options.Stylesheets,LoadStylesheet=options.LoadStylesheet,Environment=options.ResourceViewport or geometryAdapter.GetViewport,
			QueueTask=function(fn)loop:QueueTask(fn)end,
			Changed=function()cssom:ResourceChanged()end,
			Emit=function(node,kind)eventHost:Dispatch(targetFor(node),eventHost:NewEvent(kind,{},'Event'),true)end,
			LoadStateChanged=stylesheetsChanged,
		})end
		stylesheetResources=if vm:IsExecuting()then create()else vm:Install(create)
		runtime.StylesheetResources=stylesheetResources
		return stylesheetResources
	end
	if options.LoadStylesheet or options.Stylesheets then ensureStylesheetResources(true)end
	audioElements=vm:Install(function()return AudioElements.install(vm,globals,{
		Document=document,Host=host,Bridge=bridge,Events=eventHost,TargetFor=targetFor,
		CreatePromise=function()return promises:CreateCapability()end,
		QueueTask=function(fn)loop:QueueTask(fn)end,QueueMicrotask=function(fn)loop:QueueMicrotask(fn)end,
		URL=options.URL,GetBaseURL=getBaseURL,
		GetViewport=options.ResourceViewport or geometryAdapter.GetViewport,
		Adapter=options.AudioAdapter or (options.CreateAudioAdapter and options.CreateAudioAdapter(runtime)),
		VideoAdapter=options.VideoAdapter or(options.CreateVideoAdapter and options.CreateVideoAdapter(runtime)),
		Streams=runtime.MediaStreams,
		EmitEvent=options.AudioEmitEvent,
		LoadStateChanged=function()if scriptLoader then scriptLoader:ResourcesChanged()end end,
	})end)
	runtime.AudioElements=audioElements
	imageResources=vm:Install(function()return ImageResources.install(vm,globals,{
		DeferImage=options.DeferImage,ImageIsRendered=options.ImageIsRendered,
		Document=document,Host=host,Bridge=bridge,Events=eventHost,TargetFor=targetFor,
		CreatePromise=function()return promises:CreateCapability()end,
		QueueTask=function(fn)loop:QueueTask(fn)end,QueueMicrotask=function(fn)loop:QueueMicrotask(fn)end,
		LoadImage=options.LoadImage,URL=options.URL,GetBaseURL=getBaseURL,
		GetViewport=options.ResourceViewport or geometryAdapter.GetViewport,
		RenderedSize=if options.RenderedImageSize then function(node)geometry:Flush();return options.RenderedImageSize(node)end else nil,ImageChanged=options.ImageChanged,
		LoadStateChanged=function()if scriptLoader then scriptLoader:ResourcesChanged()end end,
	})end)
	fontLoading=vm:Install(function()return FontLoading.install(vm,globals,{
		Document=document,Host=host,Bridge=bridge,Events=eventHost,
		CreatePromise=function()return promises:CreateCapability()end,QueueTask=function(fn)loop:QueueTask(fn)end,
		Await=function(p,yes,no)promises:Await(p,function(a)yes(a[1])end,function(a)no(a[1])end)end,
		LoadFont=options.LoadFont,FontChanged=options.FontChanged,FontFaces=options.FontFaces,
		IsLayoutPending=function()return host.ReadyState~="complete"or fontLayoutPending or next(runtime.Pending)~=nil or options.IsFontLayoutPending and options.IsFontLayoutPending()end,
	})end)
	if options.FontPreloadPending then vm:Install(function()fontLoading:BeginHostLoad()end)end
	function runtime:FontPreloadCompleted()
		if self.Alive and options.FontPreloadPending then
			options.FontPreloadPending=false
			loop:QueueTask(function()fontLoading:EndHostLoad()end)
		end
	end
	runtime.ImageResources,runtime.FontLoading=imageResources,fontLoading
	return runtime
end
function Runtime.new(document: any,options: any): any
	return WorkContext.completeConstruction(function()
		local runtime=createRuntime(document,options)
		runtime.LoadingWork=options.LoadingWork
		if options.LoadingWork and not options.LoadingWork.Active then runtime:Destroy()end
		return runtime
	end)
end
return Runtime
