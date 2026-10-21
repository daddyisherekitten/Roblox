--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- One image request state per DOM node, independent of retained render boxes.
-- Host completion is queued into the owning realm; replacing src invalidates
-- old callbacks and decode promises without running JavaScript on host threads.
local ResponsiveSources=require(script.Parent.Parent.HTML.ResponsiveSources)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local ImageResources={}
function ImageResources.install(vm: any,globals: any,options: any): any
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null
	local api={Alive=true,Pending=0};local records=setmetatable({},{__mode="kv"});local active={}
	local document,host,bridge=options.Document,options.Host,options.Bridge
	local function image(node)return ElementNames.html(node,"img")or ElementNames.html(node,"input")and(node.Attributes.type or ""):lower()=="image"end
	local function check()assert(api.Alive and vm.Alive,"Image resources disposed")end
	local function errorValue(message)return options.Events:DOMException(message,"EncodingError")end
	local function queue(fn)options.QueueTask(function()if api.Alive then fn()end end)end
	local function native(name,length,fn)return {Kind="native-function",Prototype=vm.Prototypes.Function,Values={name=name,length=length},Call=function(args,self)check();return fn(args,self)end}end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,N))end
	local function connected(node)return ShadowTree.Connected(node,document)end
	local function notify()if options.LoadStateChanged then options.LoadStateChanged()end end
	local function blocking(record)
		return record.Status=="loading"and connected(record.Node)and record.Node.Attributes.loading~="lazy"
	end
	local function recount()
		local count=0;for record in active do if blocking(record)then count+=1 end end
		if count~=api.Pending then api.Pending=count;notify()end
	end
	local function settleDecodes(record,ok)
		local waiting=record.Decodes;record.Decodes={}
		for _,entry in waiting do(if ok then entry.Resolve else entry.Reject)({if ok then U else errorValue("The image could not be decoded")})end
	end
	local function cancel(record)
		if record.Cancel then pcall(record.Cancel);record.Cancel=nil end
		active[record]=nil;settleDecodes(record,false)
	end
	local function selected(node,record)
		if ResponsiveSources.allowsAuto(node)and connected(node)and options.ImageIsRendered then
			local generation=record.Generation;local size=options.ImageIsRendered(node)
			if not api.Alive or records[node]~=record or record.Generation~=generation then return nil end
			if size then ResponsiveSources.publishAutoSize(node,size.Width)end
		end
		local viewport=options.GetViewport and options.GetViewport()or {Width=1024}
		local source,density,dimensionSource=node.Attributes.src or "",1,node
		if not ElementNames.html(node,"input")then source,density,dimensionSource=ResponsiveSources.forImage(node,math.max(1,viewport.Width or 1024),ResponsiveSources.deviceDensity(viewport),viewport)end
		local href="";if source~=""then
			local ok,value=pcall(function()return vm.Get(vm:Construct(globals.URL,{source,if options.GetBaseURL then options.GetBaseURL()else options.URL or"about:blank"}),"href")end)
			if ok then href=value end
		end
		return source,href,density,dimensionSource
	end
	local function dimensions(record,data)
		record.Width,record.Height=ResponsiveSources.intrinsicSize(record.PixelWidth,record.PixelHeight,record.SourceDensity)
		local result=if type(data)=="table"then table.clone(data)else{};result.Width,result.Height=record.Width,record.Height
		return result
	end
	local function make(node)
		local record=records[node];if record then return record end
		record={Node=node,Generation=0,Status="empty",Raw=nil,URL="",Current="",Width=0,Height=0,Decodes={},Queued=false}
		records[node]=record;node.ImageResourceState=record;return record
	end
	local function finish(record,generation,ok,data)
		if not api.Alive or record.Generation~=generation or record.Status~="loading"then return end
		record.Cancel=nil;active[record]=nil
		local width,height=if type(data)=="table"then data.Width else nil,if type(data)=="table"then data.Height else nil
		ok=ok and type(width)=="number"and type(height)=="number"and width>=0 and height>=0 and width<math.huge and height<math.huge
		record.Status=if ok then"loaded"else"error"
		record.PixelWidth,record.PixelHeight=if ok then width else 0,if ok then height else 0
		local result=dimensions(record,data)
		record.Current=if record.URL~=""then record.URL else record.Raw or ""
		if options.ImageChanged then options.ImageChanged(record.Node,ok,if ok then result else nil)end
		-- decode() fulfillment is a promise reaction, before the queued load task.
		settleDecodes(record,ok)
		queue(function()
			if record.Generation~=generation then return end
			options.Events:Dispatch(options.TargetFor(record.Node),options.Events:NewEvent(if ok then"load"else"error"),true)
		end)
		recount()
	end
	local refresh
	local function start(record,generation,resumed)
		if not api.Alive or record.Generation~=generation then return end;record.Queued=false
		if record.Raw==""then
			record.Status="empty";record.Current="";record.Width,record.Height=0,0
			if record.Node.Attributes.src~=nil then
				queue(function()if record.Generation==generation then options.Events:Dispatch(options.TargetFor(record.Node),options.Events:NewEvent("error"),true)end end)
			end
			recount();return
		end
		if not resumed and options.DeferImage and(record.Node.Attributes.loading or''):lower()=='lazy'then
			local continued=false
			local cancelDefer=options.DeferImage(record.Node,function()
				if not api.Alive or record.Generation~=generation then return end
				continued=true;record.Cancel=nil
				refresh(record.Node,false)
				if api.Alive and record.Generation==generation then start(record,generation,true)end
			end)
			if not api.Alive or record.Generation~=generation then if type(cancelDefer)=='function'then cancelDefer()end;return end
			if continued then return end
			if type(cancelDefer)=='function'then record.Cancel=cancelDefer;record.Status='deferred';recount();return end
		end
		record.Status="loading";active[record]=true;recount()
		local called=false
		local function complete(ok,data)
			if called or not api.Alive then return end;called=true
			queue(function()finish(record,generation,ok,data)end)
		end
		if record.URL==""or not options.LoadImage then complete(false,"No image resource adapter");return end
		local ok,cancellation=pcall(options.LoadImage,record.URL,complete,{Source=record.Raw,Node=record.Node})
		if not ok then complete(false,cancellation)
		elseif not called and record.Generation==generation and type(cancellation)=="function"then record.Cancel=cancellation end
	end
	refresh=function(node,force)
		local record=make(node);local raw,url,density,dimensionSource=selected(node,record)
		if raw==nil then return record end
		local width,height=dimensionSource.Attributes.width,dimensionSource.Attributes.height
		local dimensionChanged=record.DimensionSource~=dimensionSource or record.AttributeWidth~=width or record.AttributeHeight~=height
		record.DimensionSource,record.AttributeWidth,record.AttributeHeight=dimensionSource,width,height
		local explicitEmpty=raw==""and node.Attributes.src~=nil
		if not force and record.Raw==raw and record.URL==url and record.ExplicitEmpty==explicitEmpty then
			if record.SourceDensity~=density or dimensionChanged then
				record.SourceDensity=density
				local loaded=record.Status=="loaded"
				local result=if loaded then dimensions(record)else nil
				if options.ImageChanged then options.ImageChanged(node,loaded,result)end
			end
			return record
		end
		cancel(record);record.Generation+=1;record.Raw,record.URL,record.ExplicitEmpty,record.SourceDensity=raw,url,explicitEmpty,density
		record.Status=if raw==""then"empty"else"loading"
		if raw==""then record.Current="";record.Width,record.Height=0,0 end
		record.Queued=true;local generation=record.Generation
		if record.Status=="loading"then active[record]=true end;recount()
		options.QueueMicrotask(function()start(record,generation)end)
		return record
	end
	function api:Get(node,key)
		if not image(node)or not ElementNames.html(node,"img")then return nil end
		if key=="complete"or key=="naturalWidth"or key=="naturalHeight"or key=="currentSrc"then
			local record=refresh(node,false)
			if key=="complete"then return record.Status~="loading"and record.Status~='deferred'elseif key=="currentSrc"then return record.Current
			elseif key=="naturalWidth"then return math.floor(record.Width)else return math.floor(record.Height)end
		end
		if key=="width"or key=="height"then
			local rendered=connected(node)and options.RenderedSize and options.RenderedSize(node)
			if rendered and connected(node)then return math.max(0,math.floor(rendered[if key=="width"then"Width"else"Height"]or 0))end
			local value=node.Attributes[key];local parsed=value and tonumber(value:match("^[\t\n\f\r ]*%+?(%d+)"))
			if parsed then return math.min(parsed,4294967295)end
			local record=refresh(node,false);return math.floor(if key=="width"then record.Width else record.Height)
		end
		if key=="decode"then return function()
			local record=refresh(node,false);local promise,resolve,reject=options.CreatePromise()
			local generation=record.Generation
			options.QueueMicrotask(function()
				if not api.Alive then return end
				if record.Generation~=generation or record.Status=="empty"or record.Status=="error"then reject({errorValue("The image could not be decoded")})
				elseif record.Status=="loaded"then resolve({U})
				else table.insert(record.Decodes,{Resolve=resolve,Reject=reject})end
			end)
			return promise
		end end
		return nil
	end
	function api:Set(node,key,value,strict)
		if not image(node)or not ElementNames.html(node,"img")then return false end
		if key=="complete"or key=="naturalWidth"or key=="naturalHeight"or key=="currentSrc"then
			if strict~=false then VM.throw(VM.error("TypeError","Read-only HTMLImageElement property"))end;return true
		end
		if key=="width"or key=="height"then
			local number=VM.number(vm.ToPrimitive(value,"number"));if number~=number or math.abs(number)==math.huge then number=0 end
			bridge.Attribute(node,key,tostring((if number<0 then math.ceil(number)else math.floor(number))%4294967296));return true
		end
		return false
	end
	function api:Visit(root)
		local pending={root};while #pending>0 do local node=table.remove(pending)
			if image(node)then refresh(node,false)end
			if ElementNames.html(node,"template")then continue end
			for _,child in node.Children or{}do table.insert(pending,child)end
			if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot)end
		end;recount()
	end
	function api:AttributeChanged(node,key,namespace)
		if namespace then return end
		if ElementNames.html(node,"input") and key=="type" then
			if image(node)then refresh(node,false)
			elseif records[node]then cancel(records[node]);records[node]=nil;node.ImageResourceState=nil;recount()end
			return
		end
		if image(node)and(key=="src"or key=="srcset"or key=="sizes"or key=="crossorigin"or key=="referrerpolicy")then refresh(node,key=="src"or key=="crossorigin"or key=="referrerpolicy")
		elseif ElementNames.html(node,"source")and node.Parent and ElementNames.html(node.Parent,"picture")then self:Visit(node.Parent)
		elseif image(node)and key=="loading"then
			local record=records[node]
			if record and record.Status=='deferred'then refresh(node,true)else recount()end
		end
	end
	function api:AfterLayout()
		if not self.Alive then return end
		local nodes={};for node in records do if ResponsiveSources.allowsAuto(node)and connected(node)then table.insert(nodes,node)end end
		for _,node in nodes do if not self.Alive then break end;refresh(node,false)end
	end
	function api:ViewportChanged()
		for node in records do if connected(node)and(node.Attributes.srcset or node.Parent and ElementNames.html(node.Parent,"picture"))then refresh(node,false)end end
	end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		for node,record in records do if record.Cancel then pcall(record.Cancel)end;if node.ImageResourceState==record then node.ImageResourceState=nil end;table.clear(record.Decodes)end
		table.clear(active);table.clear(records);self.Pending=0
	end
	local previousGet,previousSet,previousAttribute,previousInsert,previousMutation=host.ElementGet,host.ElementSet,host.AttributeChanged,host.PostInsert,host.Mutation
	host.ElementGet=function(node,key)local value=api:Get(node,key);return if value~=nil then value elseif previousGet then previousGet(node,key)else nil end
	host.ElementSet=function(node,key,value,strict)return api:Set(node,key,value,strict)or previousSet and previousSet(node,key,value,strict)==true end
	host.AttributeChanged=function(node,key,value,old,namespace,...)api:AttributeChanged(node,key,namespace);if previousAttribute then previousAttribute(node,key,value,old,namespace,...)end end
	host.PostInsert=function(additions)for _,node in additions do api:Visit(node)end;if previousInsert then previousInsert(additions)end end
	host.Mutation=function(record)
		if record.Type=="childList"and ElementNames.html(record.Target,"picture")then api:Visit(record.Target)end
		recount();if previousMutation then previousMutation(record)end
	end
	local proto=vm.Get(globals.HTMLImageElement,"prototype")
	for _,key in {"complete","naturalWidth","naturalHeight","currentSrc","width","height"}do
		define(proto,key,{get=native("get "..key,0,function(_,self)local node=bridge.Unwrap(self);if not image(node)or not ElementNames.html(node,"img")then VM.throw(VM.error("TypeError","Illegal HTMLImageElement receiver"))end;return api:Get(node,key)end),
			set=if key=="width"or key=="height"then native("set "..key,1,function(args,self)local node=bridge.Unwrap(self);if not image(node)or not ElementNames.html(node,"img")then VM.throw(VM.error("TypeError","Illegal HTMLImageElement receiver"))end;api:Set(node,key,args[1]or U,true);return U end)else U,enumerable=true,configurable=true})
	end
	define(proto,"decode",{value=native("decode",0,function(args,self)
		local ok,node=pcall(bridge.Unwrap,self)
		if not ok or not ElementNames.html(node,"img")then
			-- Web IDL promise-returning operations reject on a brand failure.
			local promise,_,reject=options.CreatePromise()
			reject({VM.error("TypeError","Illegal HTMLImageElement receiver")});return promise
		end
		return api:Get(node,"decode")(args,self)
	end),writable=true,enumerable=true,configurable=true})
	local factory=native("Image",0,function(args)
		local value=bridge.Document.Get("createElement")({"img"});local node=bridge.Unwrap(value)
		if args[1]~=nil then api:Set(node,"width",args[1],true)end;if args[2]~=nil then api:Set(node,"height",args[2],true)end;return value
	end);factory.Construct=function(args)return factory.Call(args)end
	define(factory,"prototype",{value=proto});globals.Image=factory;vm.Global.Bindings.Image={Value=factory}
	api:Visit(document)
	return api
end
return ImageResources
