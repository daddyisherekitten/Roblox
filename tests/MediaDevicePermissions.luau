--!strict
return function(Parser,Runtime,Events)
	local function make(host,extra)
		local events=Events.new(error)
		local options={URL='https://media.test/check',Events=events,PermissionHost=host,
			Schedule=function()end,ApplyChanges=function()return false end}
		for key,value in extra or{}do options[key]=value end
		local realm=Runtime.new(Parser.parseDocument('<!doctype html><p>Media permission checks</p>'),options)
		local function run(source)local ok,message=realm:Run(source);assert(ok,tostring(message));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
		local function get(name)return realm.Window.Get(name)end
		local function pump()for _=1,4 do realm:PumpTasks()end end
		return realm,events,run,get,pump
	end
	local requests,listeners,states={},{},{camera='prompt',microphone='prompt'}
	local cancels,unsubscribes=0,0
	local host={}
	function host:Query(origin,name)assert(origin=='https://media.test');return states[name]end
	function host:Request(request,complete)
		local item={Request=request,Complete=complete};table.insert(requests,item)
		return function()cancels+=1;complete(false,'cancel callback must be ignored')end
	end
	function host:Subscribe(origin,callback)
		assert(origin=='https://media.test');table.insert(listeners,callback)
		return function()unsubscribes+=1 end
	end
	local realm,events,run,get,pump=make(host)
	run([=[
		var cameraStatus,microphoneStatus,changeTrace=[],rejections=[],unsupported;
		var mediaIdentity=navigator.mediaDevices===navigator.mediaDevices&&navigator.permissions===navigator.permissions;
		navigator.permissions.query({name:'camera'}).then(status=>{
			cameraStatus=status;status.onchange=()=>changeTrace.push('handler:'+status.state);
			status.addEventListener('change',event=>changeTrace.push('event:'+event.type+':'+(event.target===status)));
		});
		navigator.permissions.query({name:'microphone'}).then(status=>microphoneStatus=status);
		var returned=navigator.mediaDevices.getUserMedia({video:true,audio:{echoCancellation:true}});
		returned.catch(error=>{rejections.push(error.name);unsupported=error instanceof DOMException;});
		var returnsPromise=returned instanceof Promise;
	]=])
	run('var initial=cameraStatus.state;')
	assert(get('mediaIdentity')and get('returnsPromise')and get('initial')=='prompt')
	assert(#requests==0 and realm.MediaDevices.PendingCount==1,'The host request starts in a document task')
	pump();assert(#requests==1 and #listeners==1)
	local request=requests[1].Request
	assert(request.Origin=='https://media.test'and request.URL=='https://media.test/check')
	assert(#request.Names==2 and request.Names[1]=='microphone'and request.Names[2]=='camera')
	states.camera='granted';states.microphone='granted'
	for _,callback in listeners do callback('camera','granted');callback('microphone','granted')end
	requests[1].Complete(true);requests[1].Complete(false,'duplicate answer')
	pump()
	run([=[
		var result=rejections.join(','),changes=changeTrace.join('|');
		var statusInterface=cameraStatus instanceof PermissionStatus&&cameraStatus instanceof EventTarget;
		var statusTag=Object.prototype.toString.call(cameraStatus);
		var named=cameraStatus.name+':'+microphoneStatus.name;
		var descriptor=Object.getOwnPropertyDescriptor(PermissionStatus.prototype,'state');
		var readonly=typeof descriptor.get==='function'&&descriptor.set===undefined&&descriptor.enumerable&&descriptor.configurable;
		var errors=0;try{new PermissionStatus();}catch(e){if(e.name==='TypeError')errors++;}
		try{descriptor.get.call({});}catch(e){if(e.name==='TypeError')errors++;}
		try{(()=>{'use strict';cameraStatus.state='denied';})();}catch(e){if(e.name==='TypeError')errors++;}
	]=])
	assert(get('result')=='NotSupportedError'and get('unsupported')and realm.MediaDevices.PendingCount==0)
	assert(get('changes')=='handler:granted|event:change:true'and get('statusInterface'))
	assert(get('named')=='camera:microphone'and get('statusTag')=='[object PermissionStatus]'and get('readonly')and get('errors')==3)
	-- Persisted permission grants skip the UI but do not fake successful capture.
	run("navigator.mediaDevices.getUserMedia({video:true}).catch(e=>rejections.push(e.name));")
	pump();run("var persisted=rejections.join(',');")
	assert(#requests==1 and get('persisted')=='NotSupportedError,NotSupportedError')
	states.camera='denied';listeners[1]('camera','denied');pump()
	run("navigator.mediaDevices.getUserMedia({video:true}).catch(e=>rejections.push(e.name));")
	pump();run("var denied=rejections[rejections.length-1],deniedState=cameraStatus.state;")
	assert(#requests==1 and get('denied')=='NotAllowedError'and get('deniedState')=='denied')
	realm:Destroy();realm:Destroy();events:Destroy();assert(cancels==0 and unsubscribes==1)
	-- Invalid constraints/descriptors reject with JavaScript TypeErrors before
	-- any host call; throwing dictionary getters retain their original value.
	states.camera='prompt';states.microphone='prompt';table.clear(requests);table.clear(listeners)
	realm,events,run,get,pump=make(host)
	run([=[
		var typeErrors=0,invalidNames=0,getterReason,receiverErrors=0;
		for(const constraints of [undefined,null,{},false,5,'video',{video:false,audio:false}]){
			navigator.mediaDevices.getUserMedia(constraints).catch(e=>{if(e.name==='TypeError')typeErrors++;});
		}
		for(const descriptor of [undefined,null,{},false,{name:'geolocation'},{name:Symbol()}]){
			navigator.permissions.query(descriptor).catch(e=>{if(e.name==='TypeError')invalidNames++;});
		}
		const marker={};navigator.mediaDevices.getUserMedia({get audio(){throw marker;},video:true}).catch(e=>getterReason=e===marker);
		navigator.mediaDevices.getUserMedia.call({}, {video:true}).catch(e=>{if(e.name==='TypeError')receiverErrors++;});
		navigator.permissions.query.call({}, {name:'camera'}).catch(e=>{if(e.name==='TypeError')receiverErrors++;});
	]=])
	assert(get('typeErrors')==7 and get('invalidNames')==6 and get('getterReason')and get('receiverErrors')==2 and #requests==0)
	realm:Destroy();events:Destroy()
	-- Denial is separate from grant-without-backend; no prompt suppression is
	-- mistaken for a successful or invented media stream.
	realm,events,run,get,pump=make(host)
	run("var denial; navigator.mediaDevices.getUserMedia({audio:true}).catch(e=>denial=e.name);")
	pump();assert(#requests==1 and requests[1].Request.Names[1]=='microphone')
	states.microphone='denied';requests[1].Complete(false,'No microphone');pump();assert(get('denial')=='NotAllowedError')
	realm:Destroy();events:Destroy();table.clear(requests);states.microphone='prompt'
	-- A pending native prompt is cancelled exactly once on hide/navigation/
	-- disposal; late and reentrant callbacks cannot settle another document.
	for _,action in {'hide','navigate','destroy'}do
		realm,events,run,get,pump=make(host)
		run("var stopped; navigator.mediaDevices.getUserMedia({video:true}).catch(e=>stopped=e.name);")
		pump();local item=requests[#requests];local before=cancels
		assert(realm.MediaDevices.PendingCount==1)
		if action=='hide'then realm:SetVisible(false)
		elseif action=='navigate'then assert(realm:RequestLeave({Kind='navigate',URL='https://media.test/next'}))
		else realm:Destroy()end
		assert(cancels==before+1 and realm.MediaDevices.PendingCount==0)
		item.Complete(true);item.Complete(false)
		if action~='destroy'then pump();assert(get('stopped')=='AbortError')end
		realm:Destroy();events:Destroy();assert(cancels==before+1)
	end
	-- Explicitly disabled iframe access, an opaque origin and an absent host
	-- remain deterministic and never open a native permission prompt.
	for _,extra in {{},{URL='about:blank'},{PermissionRequestsAllowed=false}}do
		local useHost=if extra.URL or extra.PermissionRequestsAllowed==false then host else nil
		local previous=#requests
		realm,events,run,get,pump=make(useHost,extra)
		run("var unavailable,state; navigator.permissions.query({name:'camera'}).then(s=>state=s.state);navigator.mediaDevices.getUserMedia({video:true}).catch(e=>unavailable=e.name);")
		pump();assert(#requests==previous)
		assert(get('unavailable')=='NotAllowedError'and get('state')=='denied')
		realm:Destroy();events:Destroy()
	end
	-- Sync callbacks, asynchronous callbacks, denial and late answers share
	-- the same one-shot completion path.
	local synchronous={Query=function()return 'prompt'end,Request=function(_,_,complete)complete(true);complete(false);return function()error('completed prompt must not be cancelled')end end}
	realm,events,run,get,pump=make(synchronous)
	run("var sync; navigator.mediaDevices.getUserMedia({video:{width:640},audio:false}).catch(e=>sync=e.name);")
	pump();assert(get('sync')=='NotSupportedError'and realm.MediaDevices.PendingCount==0)
	realm:Destroy();events:Destroy()
	-- Web IDL's boolean/dictionary union accepts primitive boolean conversion
	-- and explicit null as an empty dictionary. undefined retains false default.
	local converted={};local subscriptions=0
	local conversions={Query=function()return 'prompt'end,Subscribe=function()subscriptions+=1 end,Request=function(_,request,complete)
		table.insert(converted,table.concat(request.Names,','));complete(false)
	end}
	realm,events,run,get,pump=make(conversions)
	run([=[
		var conversionFailures=0;
		for(const constraints of [{video:null},{video:1},{audio:'yes',video:undefined},{video:0,audio:''}]){
			navigator.mediaDevices.getUserMedia(constraints).catch(error=>{if(error.name==='TypeError')conversionFailures++;});
		}
		navigator.permissions.query({name:'camera'});navigator.permissions.query({name:'camera'});
	]=])
	pump();assert(#converted==3 and converted[1]=='camera'and converted[2]=='camera'and converted[3]=='microphone')
	assert(get('conversionFailures')==1 and subscriptions==1)
	realm:Destroy();events:Destroy()
	print('MediaDevices: permission states, combined requests, denial, status events and cancellation passed')
end
