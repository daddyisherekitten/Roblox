--!strict
-- Permission decisions precede capture. The optional native capture host owns
-- the source; the JS realm owns its MediaStream/MediaStreamTrack wrappers.
local MediaDevices={}
function MediaDevices.install(vm: any,globals: any,options: any): any
	options=table.clone(options)
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null
	local api={Alive=true,PendingCount=0};local pending={}
	local statuses=setmetatable({},{__mode='k'});local unsubscribe;local subscribed=false
	local permissionHost=options.PermissionHost
	local captureHost=options.MediaCaptureHost
	local origin=options.Origin
	local function check()assert(api.Alive and vm.Alive,'JavaScript media permissions disposed')end
	local function fail(message)VM.throw(VM.error('TypeError',message))end
	local function report(message)if options.Report then options.Report('Media permission host: '..tostring(message))end end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,N))end
	local function native(name,length,action)
		local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return action(args,receiver)end}
		define(value,'name',{value=name,configurable=true});define(value,'length',{value=length,configurable=true});return value
	end
	local function object(value)return value~=nil and value~=U and value~=N and vm.ObjectModel.IsObject(value)end
	local function exception(name,message)return options.Events:DOMException(message,name)end
	local function constraintsValue(value)
		if value==N then return {}end
		if not object(value)then return VM.truth(value)end
		local result={}
		for _,key in {'width','height','frameRate','aspectRatio','facingMode','deviceId','groupId','echoCancellation','noiseSuppression','autoGainControl','sampleRate','sampleSize','channelCount','latency'}do
			local item=vm.Get(value,key)
			if item~=U then
				if object(item)then
					local range={};for _,part in {'exact','ideal','min','max'}do local entry=vm.Get(item,part);if type(entry)=='string'or type(entry)=='number'or type(entry)=='boolean'then range[part]=entry end end;result[key]=range
				elseif type(item)=='string'or type(item)=='number'or type(item)=='boolean'then result[key]=item end
			end
		end
		return result
	end
	local function capability()
		local promise,resolve,reject=options.CreatePromise()
		return {Promise=promise,Resolve=function(value)resolve({value})end,Reject=function(value)reject({value})end}
	end
	local function queue(action)
		if api.Alive then options.QueueTask(function()if api.Alive then action()end end)end
	end
	local function query(name)
		if options.Allowed==false or type(origin)~='string'or origin=='null'or not permissionHost or type(permissionHost.Request)~='function'then return 'denied'end
		if type(permissionHost.Query)~='function'then return 'prompt'end
		local state=permissionHost:Query(origin,name)
		assert(state=='prompt'or state=='granted'or state=='denied','PermissionHost.Query returned an invalid state')
		return state
	end
	local function statusState(receiver)
		local record=statuses[receiver];if not record then fail('Illegal PermissionStatus receiver')end;return record
	end
	local statusPrototype=vm.Object({},vm.Get(globals.EventTarget,'prototype'))
	for _,name in {'name','state'}do define(statusPrototype,name,{get=native('get '..name,0,function(_,receiver)
		local record=statusState(receiver);return if name=='name'then record.Name else record.State
	end),enumerable=true,configurable=true})end
	if vm.SymbolToStringTag then define(statusPrototype,vm.SymbolToStringTag,{value='PermissionStatus',configurable=true})end
	local constructor=native('PermissionStatus',0,function()fail('Illegal PermissionStatus constructor')end)
	constructor.Construct=function()check();fail('Illegal PermissionStatus constructor')end
	define(constructor,'prototype',{value=statusPrototype});define(statusPrototype,'constructor',{value=constructor,writable=true,configurable=true})
	globals.PermissionStatus=constructor
	vm.GlobalEnvironment:Define('PermissionStatus',vm.Object({value=constructor,writable=true,enumerable=false,configurable=true},N),true)
	local function changed(name,state)
		if name~='camera'and name~='microphone'or state~='prompt'and state~='granted'and state~='denied'then return end
		for status,record in statuses do
			if record.Name==name and record.State~=state then
				record.State=state
				options.Events:Dispatch(status,options.Events:NewEvent('change',{},'Event'),true)
			end
		end
	end
	local function refresh(names)
		for _,name in names do local ok,state=pcall(query,name);if ok then changed(name,state)else report(state)end end
	end
	local function subscribe()
		if subscribed or not permissionHost or type(permissionHost.Subscribe)~='function'or type(origin)~='string'or origin=='null'then return end
		subscribed=true
		local ok,cleanup=pcall(permissionHost.Subscribe,permissionHost,origin,function(name,state)queue(function()changed(name,state)end)end)
		if not ok then report(cleanup)elseif type(cleanup)=='function'then unsubscribe=cleanup end
	end
	local function retire(record)
		if record.Done then return false end
		record.Done=true;pending[record]=nil;api.PendingCount-=1;record.Cancel=nil;return true
	end
	local function cancel(record,reject)
		local cleanup=record.Cancel
		if not retire(record)then return end
		record.Cancelled=true
		if reject then record.Cap.Reject(exception('AbortError','The media permission request was cancelled'))end
		if cleanup then local ok,message=pcall(cleanup);if not ok then report(message)end end
	end
	function api:CancelPending()
		for record in table.clone(pending)do cancel(record,true)end
	end
	function api:Destroy()
		if not self.Alive then return end
		self.Alive=false
		for record in table.clone(pending)do cancel(record,false)end
		if unsubscribe then local cleanup=unsubscribe;unsubscribe=nil;local ok,message=pcall(cleanup);if not ok then report(message)end end
		for status in statuses do options.Events:EraseListeners(status)end
		table.clear(statuses);if self.InventoryRoots then table.clear(self.InventoryRoots)end;table.clear(options)
	end
	local mediaDevices=vm.Object({});local permissions=vm.Object({})
	-- Native inventory traverses these exact installed objects without invoking
	-- author-observable Navigator getters. This table is never exposed to JS.
	api.InventoryRoots={['navigator.mediaDevices']=mediaDevices,['navigator.permissions']=permissions}
	define(mediaDevices,'getUserMedia',{value=native('getUserMedia',1,function(args,receiver)
		local cap=capability()
		local ok,names,constraints=pcall(function()
			if receiver~=mediaDevices then fail('Illegal MediaDevices receiver')end
			local constraints=args[1]
			if constraints==nil or constraints==U or constraints==N then fail('At least one of audio or video must be requested')end
			if not object(constraints)then fail('MediaStreamConstraints must be a dictionary')end
			local names={};local normalized={}
			for _,entry in {{'audio','microphone'},{'video','camera'}}do
				-- The union is (boolean or MediaTrackConstraints). undefined uses
				-- the dictionary member's false default; explicit null selects an
				-- empty constraint dictionary, while other primitives use ToBoolean.
				local value=vm.Get(constraints,entry[1]);if value==N or VM.truth(value)then table.insert(names,entry[2]);normalized[entry[1]]=constraintsValue(value)else normalized[entry[1]]=false end
			end
			if #names==0 then fail('At least one of audio or video must be requested')end
			return names,normalized
		end)
		if not ok then cap.Reject(VM.exceptionValue(names));return cap.Promise end
		if api.PendingCount>=32 then cap.Reject(exception('AbortError','Too many pending media permission requests'));return cap.Promise end
		local record={Cap=cap,Names=names,Done=false};pending[record]=true;api.PendingCount+=1
		queue(function()
			if record.Done then return end
			if options.CanRequest and not options.CanRequest()then retire(record);cap.Reject(exception('InvalidStateError','The document is not active'));return end
			local success,states=pcall(function()
				local result={};for _,name in names do result[name]=query(name)end;return result
			end)
			if not success then retire(record);report(states);cap.Reject(exception('AbortError','The permission service failed'));return end
			local needsRequest=false
			for _,name in names do
				if states[name]=='denied'then retire(record);refresh(names);cap.Reject(exception('NotAllowedError','Access to the requested media was denied'));return end
				if states[name]=='prompt'then needsRequest=true end
			end
			local function complete(granted,message)
				if record.Done or record.Completing then return end;record.Completing=true
				queue(function()
					if record.Done then return end;refresh(names);if record.Done then return end
					if granted~=true then retire(record);cap.Reject(exception('NotAllowedError',if type(message)=='string'then message else 'Access to the requested media was denied'));return end
					if not captureHost or type(captureHost.Capture)~='function'or not options.Streams then retire(record);cap.Reject(exception('NotSupportedError','Permission granted; no media capture source is configured'));return end
					local captured,value,problem=pcall(captureHost.Capture,captureHost,{Origin=origin,URL=if options.GetURL then options.GetURL()else 'about:blank',Names=table.clone(names),Constraints=constraints})
					if record.Done or not api.Alive or not vm.Alive or options.CanRequest and not options.CanRequest()then
						for _,track in if captured and type(value)=='table'then value.Tracks or{}else{}do if type(track.Stop)=='function'then pcall(track.Stop)end end
						if not record.Done and api.Alive and vm.Alive then retire(record);cap.Reject(exception('AbortError','The document left the media capture request'))end;return
					end
					retire(record)
					if not captured then report(value);cap.Reject(exception('NotReadableError','The media capture source failed'));return end
					if not value then cap.Reject(exception(if type(problem)=='table'and type(problem.Name)=='string'then problem.Name else 'NotReadableError',if type(problem)=='table'and type(problem.Message)=='string'then problem.Message else 'The requested media source is unavailable'));return end
					local wrapped,stream=pcall(options.Streams.FromCapture,options.Streams,value)
					if wrapped then cap.Resolve(stream)else
						for _,track in if type(value)=='table'then value.Tracks or{}else{}do if type(track.Stop)=='function'then pcall(track.Stop)end end
						report(stream);cap.Reject(exception('NotReadableError','The media capture source returned invalid tracks'))
					end
				end)
			end
			if not needsRequest then complete(true);return end
			local request={Origin=origin,URL=if options.GetURL then options.GetURL()else 'about:blank',Names=table.clone(names)}
			local requested,cleanup=pcall(permissionHost.Request,permissionHost,request,complete)
			if not requested then
				if retire(record)then report(cleanup);cap.Reject(exception('AbortError','The permission service failed'))end
			elseif type(cleanup)=='function'then
				if record.Cancelled then local cleaned,message=pcall(cleanup);if not cleaned then report(message)end
				elseif not record.Done then record.Cancel=cleanup end
			end
		end)
		return cap.Promise
	end),writable=true,enumerable=true,configurable=true})
	define(permissions,'query',{value=native('query',1,function(args,receiver)
		local cap=capability()
		local ok,value=pcall(function()
			if receiver~=permissions then fail('Illegal Permissions receiver')end
			local descriptor=args[1];if not object(descriptor)then fail('A permission descriptor is required')end
			local name=VM.string(vm.ToPrimitive(vm.Get(descriptor,'name'),'string'))
			if name~='camera'and name~='microphone'then fail('Only camera and microphone permissions are supported')end
			local status=vm.Object({},statusPrototype);statuses[status]={Name=name,State=query(name)}
			options.Events:WrapTarget(status,{Handlers=true,HandlerNames={onchange=true},Parent=function()return nil end})
			subscribe();return status
		end)
		if ok then cap.Resolve(value)else cap.Reject(VM.exceptionValue(value))end
		return cap.Promise
	end),writable=true,enumerable=true,configurable=true})
	local navigator=globals.navigator
	if not object(navigator)then
		navigator=vm.Object({});globals.navigator=navigator
		vm.GlobalEnvironment:Define('navigator',vm.Object({value=navigator,writable=false,enumerable=true,configurable=true},N),true)
	end
	define(navigator,'mediaDevices',{get=native('get mediaDevices',0,function(_,receiver)if receiver~=navigator then fail('Illegal Navigator receiver')end;return mediaDevices end),enumerable=true,configurable=true})
	define(navigator,'permissions',{get=native('get permissions',0,function(_,receiver)if receiver~=navigator then fail('Illegal Navigator receiver')end;return permissions end),enumerable=true,configurable=true})
	return api
end
return MediaDevices
