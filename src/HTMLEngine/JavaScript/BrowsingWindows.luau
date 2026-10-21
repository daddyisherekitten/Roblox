--!strict
-- A host contract, not native GUI: standalone HTML needs no window manager.
local RealmAccess=require(script.Parent.RealmAccess)
local Windows={}
function Windows.features(source)
	local values={}
	for name,value in source:lower():gmatch('([%w_-]+)%s*=?%s*([^,%s]*)')do values[name]=value end
	local function enabled(name)local v=values[name];return v~=nil and v~='0'and v~='no'and v~='false'end
	local result={NoOpener=enabled('noopener')or enabled('noreferrer'),NoReferrer=enabled('noreferrer')}
	for key,names in {Width={'width','innerwidth'},Height={'height','innerheight'},Left={'left','screenx'},Top={'top','screeny'}}do
		for _,name in names do local n=tonumber(values[name]);if n and n==n and math.abs(n)<1000000 then result[key]=math.round(n);break end end
	end
	if values.popup~=nil then result.Popup=enabled('popup')
	else
		local legacy=false;for key in values do if key~='noopener'and key~='noreferrer'and key~='attributionsrc'then legacy=true end end
		result.Popup=legacy and(not enabled('location')and not enabled('toolbar')or not enabled('menubar')or values.resizable~=nil and not enabled('resizable')or not enabled('scrollbars')or not enabled('status'))
	end
	return result
end
function Windows.install(vm,globals,options)
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local host=options.Host;local handles=setmetatable({},{__mode='kv'})
	local runtime=options.Runtime;local api={}
	local function fail(name,message)VM.throw(if options.Events then options.Events:DOMException(message,name)else VM.error(name,message))end
	local function text(value)
		value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then VM.throw(VM.error('TypeError','Cannot convert Symbol to window text'))end
		local s=VM.string(value);if #s>65536 then VM.throw(VM.error('TypeError','Window request text budget exceeded'))end;return s
	end
	local function method(name,length,fn)
		local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=fn}
		vm.DefineProperty(value,'name',vm.Object({value=name,configurable=true}));vm.DefineProperty(value,'length',vm.Object({value=length,configurable=true}));return value
	end
	local function integer(value)
		local n=VM.number(vm.ToPrimitive(if value==nil then U else value,'number'))
		if n~=n or math.abs(n)==math.huge then return 0 end
		n=(if n<0 then math.ceil(n)else math.floor(n))%4294967296;return if n>=2147483648 then n-4294967296 else n
	end
	local function realm(handle)
		local other=handle.GetRealm and handle.GetRealm();if not other or not other.Alive then fail('InvalidStateError','The target document is unavailable')end
		return other
	end
	local function discarded(handle)return if handle.IsDiscarded then handle.IsDiscarded()else handle.IsClosed()end
	local function same(handle)
		if discarded(handle)then fail('InvalidStateError','The target window has been closed')end
		if handle.CanAccess and not handle.CanAccess(runtime.DocumentOrigin)then fail('SecurityError','Cross-origin window access is denied')end
	end
	local function geometry(handle,name,args)
		if #args<2 then fail('TypeError',name..' requires two arguments')end
		local a,b=integer(args[1]),integer(args[2]);same(handle)
		if not discarded(handle)and handle.Geometry then handle.Geometry(name,a,b)end;return U
	end
	local function post(handle,args)
		if #args<1 then fail('TypeError','postMessage requires a message')end
		local origin,transfer=args[2],args[3]
		if type(origin)=='table'and origin~=U and origin~=N then transfer=vm.Get(origin,'transfer');origin=vm.Get(origin,'targetOrigin')end
		origin=if origin==nil or origin==U then '/'else text(origin)
		if origin=='/'then origin=runtime.DocumentOrigin
		elseif origin~='*'then
			local ctor=vm.Global.Bindings.URL.Value;local ok,url=pcall(vm.Construct,vm,ctor,{origin});if not ok then fail('SyntaxError','Invalid postMessage target origin')end;origin=vm.Get(url,'origin')
		end
		local wire=options.Clone:Serialize(args[1],transfer)
		local other=handle.GetRealm and handle.GetRealm()
		if not other or not other.Alive then options.Clone:Discard(wire);return U end
		local source=host and host.GetSelfHandle and host.GetSelfHandle()
		other:Access(function()other.Messaging:ReceiveWindow(wire,if type(runtime.DocumentOrigin)=='string'then runtime.DocumentOrigin else 'null',
			function()return if source then other.BrowsingWindows.Proxy(source)else N end,origin,
			function()return other.DocumentOrigin end)end)
		return U
	end
	local function location(handle)
		local value={};local methods={}
		local function navigate(v,kind)
			local converted=text(v);if handle.Navigate then handle.Navigate(converted,kind,options.GetBaseURL and options.GetBaseURL()or options.GetURL())end
		end
		for _,name in {'assign','replace','reload','toString'}do methods[name]=method(name,if name=='assign'or name=='replace'then 1 else 0,function(args)
			if name~='replace'then same(handle)end
			if name=='toString'then return realm(handle).Navigation:GetURL()
			elseif name=='reload'then if handle.Navigate then handle.Navigate(nil,'reload',options.GetURL())end
			else if #args<1 then fail('TypeError',name..' requires a URL')end;navigate(args[1],name)end;return U
		end)end
		value.Get=function(key)
			if key=='replace'then return methods.replace end;same(handle)
			if methods[key]then return methods[key]end
			local other=realm(handle);return other:Access(function()return other.VM.Get(other.Navigation.WindowGet('location'),key)end)
		end
		value.Set=function(key,v,strict)
			if key=='href'then navigate(v,'assign');return true end;same(handle)
			local other=realm(handle);return other:Access(function()return other.VM.Set(other.Navigation.WindowGet('location'),key,v,strict)end)
		end
		return value
	end
	local function proxy(handle)
		if handle.Self or host and host.GetSelfHandle and handle==host.GetSelfHandle()then return options.Window end
		if handles[handle]then return handles[handle]end
		local value={};handles[handle]=value;local loc=location(handle);local methods={}
		for _,name in {'close','focus','blur'}do methods[name]=method(name,0,function()
			if not(if name=='close'then handle.IsClosed()else discarded(handle))and handle[name]then handle[name]()end;return U
		end)end
		for _,name in {'moveTo','moveBy','resizeTo','resizeBy'}do methods[name]=method(name,2,function(args)return geometry(handle,name,args)end)end
		methods.postMessage=method('postMessage',1,function(args)return post(handle,args)end)
		value.Get=function(key)
			if key=='closed'then return handle.IsClosed()end
			if key=='window'or key=='self'or key=='top'or key=='parent'or key=='frames'then return value end
			if key=='length'then return 0 end
			if key=='location'then return loc end
			if key=='opener'then local opener=handle.GetOpener and handle.GetOpener();return if opener then proxy(opener)else N end
			if key=='close'or key=='focus'or key=='blur'or key=='postMessage'then return methods[key]end
			same(handle)
			if key=='name'then return handle.Name or ''end
			if methods[key]then return methods[key]end
			if key=='document'then local other=realm(handle);return RealmAccess.wrap(runtime,other,other.DOM.Wrap(other.Document))end
			if handle.Metrics then local metric=handle.Metrics(key);if metric~=nil then return metric end end
			if key=='then'then return U end
			return U
		end
		value.Set=function(key,v)
			if key=='location'then loc.Set('href',v);return true end;same(handle)
			if key=='name'and handle.SetName then handle.SetName(text(v));return true end
			if key=='opener'and v==N and handle.ClearOpener then handle.ClearOpener();return true end
			return false
		end
		return value
	end
	api.Proxy=proxy
	api.SelfHandle=host and host.GetSelfHandle and host.GetSelfHandle()
	local function binding(name,value)globals[name]=value;vm.Global.Bindings[name]={Value=value}end
	-- The virtual desktop belongs to the window host, not the document viewport.
	-- In particular a short page must not collapse popup movement to one axis.
	local screen=vm.Object({})
	for _,key in {'width','height','availWidth','availHeight','availLeft','availTop','colorDepth','pixelDepth'}do
		local getter=method('get '..key,0,function()
			local value=host and host.ScreenMetrics and host.ScreenMetrics(key)
			if type(value)=='number'then return value end
			if key=='colorDepth'or key=='pixelDepth'then return 24 end
			local viewport=options.GetViewport and options.GetViewport()or{}
			return if key=='width'or key=='availWidth'then viewport.Width or 0 elseif key=='height'or key=='availHeight'then viewport.Height or 0 else 0
		end)
		vm.DefineProperty(screen,key,vm.Object({get=getter,enumerable=true,configurable=true}))
	end
	globals.screen=screen;vm.Global.Bindings.screen={Get=function()return screen end}
	binding('open',method('open',0,function(args)
		local url=if args[1]==nil or args[1]==U then ''else text(args[1])
		local target=if args[2]==nil or args[2]==U then '_blank'else text(args[2]);if target==''then target='_blank'end
		local features=Windows.features(if args[3]==nil or args[3]==U or args[3]==N then ''else text(args[3]))
		if not host or not host.Open then return N end
		local request={URL=url,Target=target,Features=features}
		-- A synchronous host can cooperatively build the initial blank page.
		-- That suspension belongs to the native entry, never to author yield/await.
		local handle=if options.HostCall then options.HostCall(function()return host.Open(request)end)else host.Open(request)
		return if handle and not features.NoOpener then proxy(handle)else N
	end))
	for _,name in {'close','focus','blur'}do binding(name,method(name,0,function()
		if host and host[name]then host[name]()end;return U
	end))end
	for _,name in {'moveTo','moveBy','resizeTo','resizeBy'}do binding(name,method(name,2,function(args)
		if #args<2 then fail('TypeError',name..' requires two arguments')end
		if host and host.GetSelfHandle then return geometry(host.GetSelfHandle(),name,args)end;integer(args[1]);integer(args[2]);return U
	end))end
	if host and host.GetSelfHandle then
		binding('postMessage',method('postMessage',1,function(args)return post(host.GetSelfHandle(),args)end))
		vm.Global.Bindings.opener={Get=function()local other=host.GetOpener and host.GetOpener();return if other then proxy(other)else N end,
			Set=function(v)if v==N and host.ClearOpener then host.ClearOpener()end end}
	else vm.Global.Bindings.opener={Value=N}end
	for _,key in {'outerWidth','outerHeight','screenX','screenY','screenLeft','screenTop'}do vm.Global.Bindings[key]={Get=function()return host and host.Metrics and host.Metrics(key)or 0 end}end
	vm.Global.Bindings.closed={Get=function()return host~=nil and host.IsClosed and host.IsClosed()or false end}
	vm.Global.Bindings.name={Get=function()return host and host.GetName and host.GetName()or ''end,Set=function(value)if host and host.SetName then host.SetName(text(value))end end}
	return api
end
return Windows
