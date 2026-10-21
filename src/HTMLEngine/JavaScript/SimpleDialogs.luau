--!strict
-- A synchronous JavaScript boundary over an optional, callback-based UI host.
-- No browser/window module, polling loop, Promise or native resource is owned here.
local SimpleDialogs={}
function SimpleDialogs.install(vm: any,globals: any,options: any): any
	options=table.clone(options)
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null
	local api={Alive=true,Pending=nil}
	local function check()assert(api.Alive and vm.Alive,'JavaScript simple dialogs disposed')end
	local function windowReceiver(receiver)
		if receiver~=nil and receiver~=U and receiver~=N and receiver~=options.Window then
			VM.throw(VM.error('TypeError','Illegal Window receiver'))
		end
	end
	local function report(message)if options.Report then options.Report('Simple dialog host: '..tostring(message))end end
	local function resume(thread)
		if coroutine.status(thread)~='suspended'then return end
		if options.Resume then options.Resume(thread)
		elseif task then task.defer(thread)
		else local ok,message=coroutine.resume(thread);if not ok then report(message)end end
	end
	local function finish(record,accepted,value,deferResume)
		if record.Done then return end
		record.Done=true;record.Accepted=accepted==true
		record.Value=if type(value)=='string'then value else ''
		record.Cancel=nil
		if api.Pending==record then api.Pending=nil end
		local thread=record.Thread;record.Thread=nil
		if thread and not deferResume then resume(thread)end
		return thread
	end
	local function cancel(record)
		if not record or record.Done then return end
		local cleanup=record.Cancel;record.Cancelled=true
		-- Settlement must precede native cleanup: closing a host dialog can
		-- synchronously call complete again with its dismissal result.
		local thread=finish(record,false,nil,true)
		if cleanup then local ok,message=pcall(cleanup);if not ok then report(message)end end
		if thread then resume(thread)end
	end
	function api:Cancel()cancel(self.Pending)end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		cancel(self.Pending);table.clear(options)
	end
	local function text(value)
		value=vm.ToPrimitive(value,'string')
		if type(value)=='table'and value.Kind=='symbol'then VM.throw(VM.error('TypeError','Cannot convert a Symbol value to a string'))end
		return VM.string(value)
	end
	local function wait(request)
		check();local host=options.Host
		if not host or type(host.Show)~='function'or api.Pending~=nil or options.CanShow and not options.CanShow()then return false,''end
		local record={Done=false,Accepted=false,Value=''};api.Pending=record
		local ok,cleanup=pcall(host.Show,request,function(accepted,value)finish(record,accepted,value)end)
		if not ok then cancel(record);report(cleanup)
		elseif type(cleanup)=='function'then
			if record.Cancelled then local cleaned,message=pcall(cleanup);if not cleaned then report(message)end
			elseif not record.Done then record.Cancel=cleanup end
		end
		if not record.Done then
			-- A host may complete immediately, so suspend only after Show has
			-- returned. Managed async/generator bodies forward this wait to the
			-- actual host task through Runtime's HostCall trampoline.
			if not coroutine.isyieldable()then cancel(record);return false,''end
			record.Thread=coroutine.running();coroutine.yield()
		end
		check();return record.Accepted,record.Value
	end
	local function invoke(kind,args)
		check()
		local first=args[1]
		local message=if first==nil or kind~='alert'and first==U then ''else text(first)
		local default=if kind=='prompt'and args[2]~=nil and args[2]~=U then text(args[2])else ''
		message=message:gsub('\r\n','\n'):gsub('\r','\n')
		-- Opaque origins retain private identity in the realm, but their UI
		-- serialization is the string "null", never the internal Luau table.
		local request={Kind=kind,Message=message,DefaultValue=default,URL=options.GetURL and options.GetURL()or'about:blank',
			Origin=if type(options.Origin)=='string'then options.Origin else 'null'}
		local result=options.HostCall(function()
			local accepted,value=wait(request);return {Accepted=accepted,Value=value}
		end)
		if kind=='alert'then return U elseif kind=='confirm'then return result.Accepted else return if result.Accepted then result.Value else N end
	end
	for _,name in {'alert','confirm','prompt'}do
		local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();windowReceiver(receiver);return invoke(name,args)end}
		vm.DefineProperty(value,'name',vm.Object({value=name,configurable=true}))
		vm.DefineProperty(value,'length',vm.Object({value=0,configurable=true}))
		globals[name]=value
		vm.GlobalEnvironment:Define(name,vm.Object({value=value,writable=true,enumerable=true,configurable=true}),true)
	end
	return api
end
return SimpleDialogs
