--!strict
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local Fullscreen={}
function Fullscreen.install(vm,options)
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null
	local api={Alive=true,Element=nil,Sequence=0};local adapter=options.Adapter
	local function native(name,length,callback)
		local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=callback}
		vm.DefineProperty(value,'name',vm.Object({value=name}));vm.DefineProperty(value,'length',vm.Object({value=length}));return value
	end
	local function fire(kind,node)
		options.QueueTask(function()
			if not api.Alive then return end
			local target=if node and ShadowTree.Connected(node,options.Document)then node else options.Document
			options.Events:Dispatch(options.TargetFor(target),options.Events:NewEvent(kind,{bubbles=true,composed=true},'Event'),true)
		end)
	end
	local function exit()
		api.Sequence+=1
		local old=api.Element;if not old then return end;api.Element=nil;old.FullscreenFlag=nil
		if adapter then adapter:Exit(old)end;fire('fullscreenchange',old)
	end
	function api:ExitForHost()options.Access(exit)end
	local request=native('requestFullscreen',0,function(_,receiver)
		local node=options.Unwrap(receiver)
		if not node or node.Kind~='Element'then VM.throw(VM.error('TypeError','requestFullscreen requires an Element'))end
		local cap=options.Promise();local allowed=adapter and adapter.Allowed~=false and ShadowTree.Connected(node,options.Document)
			and not ElementNames.html(node,'dialog')and(not options.HasUserActivation or options.HasUserActivation())
		if not allowed then cap.Reject(VM.error('TypeError','Fullscreen requires an active, allowed document and user activation'));fire('fullscreenerror',node);return cap.Promise end
		api.Sequence+=1;local sequence=api.Sequence
		options.QueueTask(function()
			if not api.Alive then return end
			if sequence~=api.Sequence or not ShadowTree.Connected(node,options.Document)then cap.Reject(VM.error('TypeError','Fullscreen request was cancelled'));return end
			if api.Element==node then cap.Resolve(U);return end
			local old=api.Element;if old then old.FullscreenFlag=nil;api.Element=nil;adapter:Exit(old)end
			node.FullscreenFlag=true;api.Element=node
			local ok,result=pcall(adapter.Enter,adapter,node)
			if not ok or result==false then
				node.FullscreenFlag=nil;api.Element=nil;adapter:Exit(node);cap.Reject(VM.error('TypeError','The fullscreen element cannot be displayed'));fire('fullscreenerror',node);return
			end
			fire('fullscreenchange',node);cap.Resolve(U)
		end)
		return cap.Promise
	end)
	local leave=native('exitFullscreen',0,function(_,receiver)
		if options.Unwrap(receiver)~=options.Document then VM.throw(VM.error('TypeError','exitFullscreen requires a Document'))end
		local cap=options.Promise()
		if not api.Element then cap.Reject(VM.error('TypeError','Document is not fullscreen'));return cap.Promise end
		options.QueueTask(function()if api.Alive then exit();cap.Resolve(U)end end);return cap.Promise
	end)
	function api:ElementGet(node,key)
		if node.Kind=='Element'and key=='requestFullscreen'then return request end
		if node==options.Document then
			if key=='fullscreenElement'then return options.Wrap(api.Element)end
			if key=='fullscreenEnabled'then return adapter~=nil and adapter.Allowed~=false end
			if key=='exitFullscreen'then return leave end
		end
		return nil
	end
	function api:BeforeRemove(node)
		if self.Element and ShadowTree.InclusiveDescendant(self.Element,node)then exit()end
	end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		if self.Element then self.Element.FullscreenFlag=nil;self.Element=nil end
		if adapter then adapter:Destroy()end
	end
	if adapter and adapter.SubscribeExit then adapter:SubscribeExit(function()if api.Alive then api:ExitForHost()end end)end
	local proto=vm.Get(vm.Global.Bindings.Element.Value,'prototype')
	vm.DefineProperty(proto,'requestFullscreen',vm.Object({value=request,writable=true,configurable=true,enumerable=true}))
	local documentProto=vm.Get(vm.Global.Bindings.Document.Value,'prototype')
	vm.DefineProperty(documentProto,'exitFullscreen',vm.Object({value=leave,writable=true,configurable=true,enumerable=true}))
	for _,name in {'fullscreenEnabled','fullscreenElement'}do
		vm.DefineProperty(documentProto,name,vm.Object({get=native('get '..name,0,function(_,receiver)
			if options.Unwrap(receiver)~=options.Document then VM.throw(VM.error('TypeError','Illegal Document receiver'))end
			return api:ElementGet(options.Document,name)
		end),enumerable=true,configurable=true}))
	end
	return api
end
return Fullscreen
