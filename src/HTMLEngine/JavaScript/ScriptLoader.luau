--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Script preparation/execution shared by parsed documents and an active parser.
local VM=require(script.Parent.VM)
local Node=require(script.Parent.Parent.DOM.Node)
local AttributeStore=require(script.Parent.Parent.DOM.AttributeStore)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local ScriptLoader={}
local SVG='http://www.w3.org/2000/svg'
local XLINK='http://www.w3.org/1999/xlink'
local function attribute(node,namespace,localName)
 local key=AttributeStore.expanded(node,namespace,localName)
 return if key then node.Attributes[key]else nil
end
function ScriptLoader.sourceAttribute(node,key,namespace): boolean
 if not ElementNames.script(node)then return false end
 if node.NamespaceURI==SVG then return(namespace==nil and key=='href')or(namespace==XLINK and key:match('[^:]+$')=='href')end
 return namespace==nil and key=='src'
end
local CLASSIC={['']=true,['text/javascript']=true,['application/javascript']=true,['text/ecmascript']=true,['application/ecmascript']=true}
function ScriptLoader.installSupport(vm: any,globals: any)
 local constructor=globals.HTMLScriptElement;if not constructor then return end
 local method={Kind='native-function',Prototype=vm.Prototypes.Function,Values={name='supports',length=1},Call=function(args)
  if #args<1 then VM.throw(VM.error('TypeError','HTMLScriptElement.supports requires a type'))end
  local value=vm.ToPrimitive(args[1],'string')
  if type(value)=='table'and value.Kind=='symbol'then VM.throw(VM.error('TypeError','Cannot convert Symbol to DOMString'))end
  local kind=VM.string(value);return kind=='classic'or kind=='module'or kind=='importmap'
 end}
 vm.DefineProperty(constructor,'supports',vm.Object({value=method,writable=true,enumerable=true,configurable=true},VM.Null))
end
function ScriptLoader.new(vm: any,options: any): any
 options=table.clone(options)
 local api={Alive=true,Started=false,Jobs={},Pending=0,Generation=0}
 local blocking,deferred,ordered={},{},{}
 local blockIndex,deferIndex,orderedIndex=1,1,1
 local parsingDone,dclQueued,dclDone,loadQueued,loadDone,loadCompleted=false,false,false,false,false,false
 local cancellations={}
 local advanceBlocking,advanceDeferred,advanceOrdered,completeDocument
	local parser,parserBlocked,advanceParser
	local parserDepth=0
	local function sourceText(node)
		local parts={};for _,child in node.Children do if child.Kind=="Text" then table.insert(parts,child.Text) end end
		return table.concat(parts)
	end
 local function base()return if options.GetBaseURL then options.GetBaseURL()else options.BaseURL end
 local function href(source)return vm.Get(vm:Construct(options.URLConstructor,{source,base()}),'href')end
 local function emit(node,kind)if api.Alive then options.Emit(node,kind)end end
 local function queue(fn)if api.Alive then local generation=api.Generation;options.QueueTask(function()if api.Alive and generation==api.Generation then fn()end end)end end
 local function microtask(fn)if api.Alive then local generation=api.Generation;options.QueueMicrotask(function()if api.Alive and generation==api.Generation then fn()end end)end end
 local function report(value)if api.Alive and options.Report then options.Report(VM.string(value))end end
 local function stylesBlocked()return options.HasBlockingStylesheets and options.HasBlockingStylesheets()==true end
 local function finish(job)
  if job.Done or job.Generation~=api.Generation then return end;job.Done=true
  api.Pending-=1;completeDocument()
 end
 local function execute(job)
  if not api.Alive or job.Done or not job.Ready or job.Generation~=api.Generation then return end
  -- Preparation belongs to one document. Adoption after fetching must not
  -- execute its script in either realm; merely detaching keeps that owner.
  if job.Node.OwnerDocument and job.Node.OwnerDocument~=options.Document then finish(job);return end
  if job.Error then emit(job.Node,'error');report(job.Error);finish(job);return end
  if job.Module then
   api.IgnoreDestructiveWrites=(api.IgnoreDestructiveWrites or 0)+1
   local ok,result=pcall(options.Modules.Evaluate,options.Modules,job.Record)
   api.IgnoreDestructiveWrites-=1
   if ok then options.Promises:Await(result,function()end,function(args)report(args[1])end)else report(VM.exceptionValue(result))end
  else
		local activeParser=parser
		local parserExecution=activeParser and job.Parser and not job.Async and not job.Defer
		if parserExecution then api.ParserScriptNesting=(api.ParserScriptNesting or 0)+1 end
		if job.External then api.IgnoreDestructiveWrites=(api.IgnoreDestructiveWrites or 0)+1 end
		local previousPoint=activeParser and activeParser.InsertionPoint
		local ok,message=pcall(options.ExecuteClassic,job.Source,job.Node,job.URL)
		if job.External then api.IgnoreDestructiveWrites-=1 end
		if parserExecution then api.ParserScriptNesting-=1 end
		if parser==activeParser and activeParser and activeParser.Alive and previousPoint then parser.InsertionPoint=previousPoint end
		if not ok then report(VM.exceptionValue(message))end
	end
  if job.Generation~=api.Generation then return end
  if job.External then emit(job.Node,'load')end
  finish(job)
 end
 completeDocument=function()
  if not parsingDone then return end
  if deferIndex>#deferred and not dclQueued then
   dclQueued=true
   queue(function()
    dclDone=true;emit(options.Document,'DOMContentLoaded');completeDocument()
   end)
  end
  local resources=if options.GetPendingResources then options.GetPendingResources()else 0
  if dclDone and api.Pending==0 and resources==0 and not loadQueued and not loadDone then
   loadQueued=true
   queue(function()
    loadQueued=false
    -- DOMContentLoaded handlers and their microtasks can start new resources
    -- after this task was queued. A queued load is not permission to ignore it.
    if api.Pending~=0 or(options.GetPendingResources and options.GetPendingResources()~=0)then return end
    if loadDone then return end;loadDone=true
    local generation=api.Generation
    options.SetReadyState('complete');emit(options.Document,'readystatechange')
    if not api.Alive or api.Generation~=generation then return end
    emit(nil,'load')
    if not api.Alive or api.Generation~=generation then return end
    loadCompleted=true
    if options.DocumentLoaded then options.DocumentLoaded()end
   end)
  end
 end
 local function prepared(job,ok,value)
  if not api.Alive or job.Ready or job.Generation~=api.Generation then return end
  cancellations[job]=nil;job.Ready=true
  if ok then if job.Module then job.Record=value else job.Source=value end
  else job.Error=if type(value)=='table'then value else VM.error('TypeError',tostring(value))end
  if job.Async then execute(job)
  elseif job.Dynamic then advanceOrdered()
  elseif job.Defer then if parsingDone then advanceDeferred()end
  else advanceBlocking()end
 end
 local function prepare(job)
  if job.Module then
   local source=if job.External then nil else sourceText(job.Node)
   local specifier=if job.External then job.URL else (base()or'about:blank')..'#html-module-'..job.ID
   local promise=options.Modules:Prepare(specifier,base(),nil,source)
   options.Promises:Await(promise,function(args)prepared(job,true,args[1])end,function(args)prepared(job,false,args[1])end)
   return
  end
  if not job.External then job.Source=sourceText(job.Node);job.Ready=true;return end
  local completed=false
  local function callback(ok,value)
   if completed or not api.Alive then return end;completed=true
   cancellations[job]=nil
   queue(function()
    if ok and type(value)=='table'then
     local mime=value.MIME and value.MIME:lower():match('^%s*([^; ]+)')
     if mime and not CLASSIC[mime]then prepared(job,false,VM.error('TypeError','Invalid script MIME type'));return end
     value=value.Source
    end
    if ok and(type(value)~='string'or #value>65536)then prepared(job,false,VM.error('TypeError','Invalid or over-budget script source'));return end
    prepared(job,ok,value)
   end)
  end
  local source=options.Sources and options.Sources[job.URL]
  if source~=nil then callback(true,source)
  elseif options.LoadScript then
   local ok,cancel=pcall(options.LoadScript,job.URL,callback,{Type='javascript',Module=false})
   if not ok then callback(false,VM.exceptionValue(cancel))elseif not completed and type(cancel)=='function'then cancellations[job]=cancel end
  else callback(false,VM.error('NotSupportedError','External scripts require a host resource loader'))end
 end
 advanceBlocking=function()
  if parsingDone or not api.Alive then return end
		if parser then if parserDepth==0 then advanceParser()end;return end
		local generation=api.Generation
 while blockIndex<=#blocking do
   local job=blocking[blockIndex];if not job.Ready or stylesBlocked()then return end
   blockIndex+=1;execute(job)
			if not api.Alive or generation~=api.Generation then return end
   if job.External then microtask(advanceBlocking);return end
  end
  parsingDone=true;options.SetReadyState('interactive');emit(options.Document,'readystatechange');advanceDeferred()
 end
 advanceDeferred=function()
  if not parsingDone or not api.Alive then return end
  if deferIndex<=#deferred then
   local job=deferred[deferIndex];if not job.Ready or stylesBlocked()then return end
   deferIndex+=1;execute(job);microtask(advanceDeferred)
  else completeDocument()end
 end
 advanceOrdered=function()
  if not api.Alive then return end
  if orderedIndex<=#ordered then
   local job=ordered[orderedIndex];if not job.Ready then return end
   orderedIndex+=1;execute(job);microtask(advanceOrdered)
  end
 end
 local function add(node,dynamic)
  if api.Jobs[node] or node.ScriptStarted or node.Attributes['data-canvas-script']~=nil or(dynamic and node.ScriptParserPending)
   or not ElementNames.script(node)then return end
  local attrs=node.Attributes
  local kind=(attrs.type or ''):match('^%s*(.-)%s*$'):lower()
  if kind=='importmap'then
   if api.Jobs[node]then return end;api.Jobs[node]={Done=true,ImportMap=true}
   if attrs.src~=nil then report(VM.error('TypeError','Import maps cannot use a src attribute'));queue(function()emit(node,'error')end);return end
   local ok,message=pcall(options.RegisterImportMap,Node.textContent(node),base())
   if not ok then report(VM.exceptionValue(message));queue(function()emit(node,'error')end)end
   return
  end
  if kind~='module'and not CLASSIC[kind]then return end
  local source=if node.NamespaceURI==SVG then attribute(node,nil,'href')or attribute(node,XLINK,'href')else attribute(node,nil,'src')
  local external=source~=nil
  if not external and sourceText(node)==''then return end
  node.ScriptStarted=true
  if attrs.nomodule~=nil and kind~='module'and node.NamespaceURI~='http://www.w3.org/2000/svg'then return end
  if #api.Jobs>=(options.MaxScripts or 256)then report(VM.error('RangeError','HTML script count budget exceeded'));return end
  local job={ID=#api.Jobs+1,Generation=api.Generation,Node=node,Module=kind=='module',External=external,Dynamic=dynamic,
   Async=(kind=='module'or external)and(attrs.async~=nil or(dynamic and node.ScriptAsync~=false)),
   Defer=not dynamic and(kind=='module'or(external and attrs.defer~=nil and node.NamespaceURI~='http://www.w3.org/2000/svg')),Parser=parser~=nil and not dynamic,URL=base(),Ready=false,Done=false}
  api.Jobs[node]=job;table.insert(api.Jobs,job);api.Pending+=1
  if external then
   local ok,value=pcall(href,source)
   if not ok or source==''then job.Error=VM.error('TypeError','Invalid script URL');job.Ready=true else job.URL=value end
  end
  if not job.Async then
		if dynamic then table.insert(ordered,job)elseif job.Defer then table.insert(deferred,job)elseif not parser then table.insert(blocking,job)end
	end
  if not job.Ready then prepare(job)elseif job.Async then queue(function()execute(job)end)end
  if dynamic and not external and not job.Module then execute(job)end
		return job
 end
	advanceParser=function(stop)
		if not api.Alive or not parser or parser.Done then return end
		local activeParser,generation=parser,api.Generation
		parserDepth+=1;assert(parserDepth<=128,"HTML script nesting budget exceeded")
		local ok,message=pcall(function()
			while api.Alive and generation==api.Generation and parser==activeParser and activeParser.Alive and not activeParser.Done do
				if parserBlocked then
					if not parserBlocked.Ready or stylesBlocked()then return end
					local job=parserBlocked;parserBlocked=nil;execute(job)
					if not api.Alive or generation~=api.Generation or parser~=activeParser then return end
				end
				local node=parser:Advance(stop)
				if not node then break end
				if not ShadowTree.Connected(node,options.Document) then continue end
				node.ScriptAsync=false
				local job=add(node,false)
				if job and not job.Async and not job.Defer then
					if job.Ready and(not stylesBlocked()or(api.ParserScriptNesting or 0)>1)then execute(job)else parserBlocked=job;return end
				end
			end
		end)
		parserDepth-=1
		if not api.Alive or generation~=api.Generation or parser~=activeParser then return end
		if not ok then report(VM.exceptionValue(message));activeParser:Destroy();return end
		if activeParser.Done and not parsingDone then
			parsingDone=true;options.SetReadyState('interactive');emit(options.Document,'readystatechange');advanceDeferred()
		end
	end
	function api:StartParser(session,firstScript)
		if self.Started or not self.Alive then return end;self.Started=true;parser=session
		if firstScript then
			if ShadowTree.Connected(firstScript,options.Document) then
				firstScript.ScriptAsync=false
				local job=add(firstScript,false)
				if job and not job.Async and not job.Defer then parserBlocked=job end
			end
		end
		if parser.Done then
			parsingDone=true;options.SetReadyState('interactive');emit(options.Document,'readystatechange');advanceDeferred()
		else advanceParser()end
	end
	function api:WriteParser(value)
		if not self.Alive or not parser or parser.Done then return false end
		if not parser.ScriptCreated and(api.IgnoreDestructiveWrites or 0)>0 and(api.ParserScriptNesting or 0)==0 then return false end
		local point=parser.InsertionPoint;local stop=parser:Insert(value);advanceParser(stop)
		parser.InsertionPoint=point;return true
	end
	function api:CloseParser()
		if parser and parser.ScriptCreated and not parser.Done then parser:Close();advanceParser()end
	end
	function api:ReplaceParser(session)
		self.Generation+=1
		if parser then parser:Destroy()end
		for _,cancel in cancellations do pcall(cancel)end
		table.clear(cancellations);table.clear(blocking);table.clear(deferred);table.clear(ordered);table.clear(self.Jobs)
		self.Pending=0;blockIndex,deferIndex,orderedIndex=1,1,1
		parsingDone,dclQueued,dclDone,loadQueued,loadDone,loadCompleted=false,false,false,false,false,false
		parser=session;parserBlocked=nil
		options.SetReadyState('loading')
	end
 function api:Start(scripts)
  if self.Started or not self.Alive then return end;self.Started=true
  for _,node in scripts do node.ScriptAsync=false;add(node,false)end
  advanceBlocking()
 end
 function api:Connect(node)
  if not self.Alive or not ElementNames.script(node)then return end
  if not ShadowTree.Connected(node,options.Document)then return end
  add(node,true);advanceOrdered()
 end
 function api:ResourcesChanged()
  if not self.Alive then return end
  queue(function()
   if not parsingDone then advanceBlocking()elseif deferIndex<=#deferred then advanceDeferred()else completeDocument()end
  end)
 end
 function api:IsDocumentComplete(): boolean return self.Alive and loadCompleted end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
		if parser then parser:Destroy();parser=nil;parserBlocked=nil end
  for _,cancel in cancellations do pcall(cancel)end
  table.clear(cancellations);table.clear(self.Jobs);table.clear(blocking);table.clear(deferred);table.clear(ordered);table.clear(options)
 end
 return api
end
return ScriptLoader
