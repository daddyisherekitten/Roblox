--!strict
return function(PermissionHost)
	local count=0
	local function check(value,label)count+=1;assert(value,label)end
	local function fixture(store)
		local prompts,replies,cancels,diagnostics={},{},0,{}
		local visible=true
		local host=PermissionHost.new({Show=function(request,complete)
			table.insert(prompts,request);table.insert(replies,complete)
			return function()cancels+=1 end
		end,CanRequest=function()return visible end,Report=function(message)table.insert(diagnostics,message)end},store)
		return host,{Prompts=prompts,Replies=replies,Diagnostics=diagnostics,Hide=function()visible=false end,Cancels=function()return cancels end}
	end
	local origin='https://camera.example'
	local store={}
	local host,ui=fixture(store)
	check(host:Query(origin,'camera')=='prompt','camera starts undecided')
	check(host:Query(origin,'microphone')=='prompt','microphone starts undecided')
	check(host:Query(origin,'geolocation')=='denied','unknown permission denied')
	check(host:Query('null','camera')=='denied','opaque origin denied')
	local events={}
	local unsubscribe=host:Subscribe(origin,function(name,value)
		check(host:Query(origin,'camera')=='granted'and host:Query(origin,'microphone')=='granted','combined state is atomic before every notification')
		table.insert(events,name..'='..value)
	end)
	local completions={}
	local cancel=host:Request({Origin=origin,URL=origin..'/page',Names={'camera','microphone','camera'}},function(ok,message)table.insert(completions,{ok,message})end)
	check(#ui.Prompts==1,'combined request opens one prompt')
	check(ui.Prompts[1].Kind=='permission'and ui.Prompts[1].Origin==origin and ui.Prompts[1].URL==origin..'/page','prompt carries only permission metadata')
	check(#ui.Prompts[1].Names==2 and ui.Prompts[1].Names[1]=='camera'and ui.Prompts[1].Names[2]=='microphone','duplicate permission omitted')
	check(#completions==0 and #events==0,'no decision before user answer')
	ui.Replies[1](true,'granted')
	check(#completions==1 and completions[1][1]==true,'allow completes once')
	check(#events==2 and events[1]=='camera=granted'and events[2]=='microphone=granted','both status changes notified')
	ui.Replies[1](false,'denied');cancel();cancel()
	check(#completions==1 and #events==2 and ui.Cancels()==0,'late answers and cancel are idempotent')
	local replacement,replacementUI=fixture(store)
	check(replacement:Query(origin,'camera')=='granted','same family survives realm replacement')
	replacement:Request({Origin=origin,Names={'camera','microphone'}},function(ok)check(ok==true,'saved grant resolves')end)
	check(#replacementUI.Prompts==0,'saved grant does not show another prompt')
	check(replacement:Query('https://elsewhere.example','camera')=='prompt','different origin remains isolated')
	unsubscribe();unsubscribe();host:Destroy();host:Destroy();replacement:Destroy()
	check(next(store.Listeners)==nil,'destroy and unsubscribe release shared listeners')

	local blocked,blockedUI=fixture({})
	local statusEvents={}
	blocked:Subscribe(origin,function(name,value)table.insert(statusEvents,name..'='..value)end)
	local blockedResults={}
	blocked:Request({Origin=origin,Names={'microphone'}},function(ok,message)table.insert(blockedResults,{ok,message})end)
	blockedUI.Replies[1](false,'denied')
	check(blocked:Query(origin,'microphone')=='denied'and blocked:Query(origin,'camera')=='prompt','explicit block affects requested permission only')
	check(#statusEvents==1 and statusEvents[1]=='microphone=denied','block notifies status')
	check(#blockedResults==1 and blockedResults[1][1]==false and blockedResults[1][2]=='Permission request denied.','block reports access rejection')
	blocked:Request({Origin=origin,Names={'camera','microphone'}},function(ok)check(ok==false,'saved denial rejects combined request')end)
	check(#blockedUI.Prompts==1 and blocked:Query(origin,'camera')=='prompt','saved denial does not mutate other permission')
	blocked:Destroy()

	for _,answer in{{false},{true},{false,'closed'}}do
		local dismissed,dismissUI=fixture({});local answered=0
		dismissed:Request({Origin=origin,Names={'camera'}},function(ok,message)answered+=1;check(ok==false and message=='Permission request dismissed.','dismissal rejects without permanent block')end)
		dismissUI.Replies[1](table.unpack(answer))
		check(answered==1 and dismissed:Query(origin,'camera')=='prompt','dismissed permission remains undecided')
		dismissed:Destroy()
	end
	local hidden,hiddenUI=fixture({});local hiddenResults=0
	hidden:Request({Origin=origin,Names={'camera'}},function(ok)hiddenResults+=1;check(ok==false,'hidden request rejected')end)
	hiddenUI.Hide();hiddenUI.Replies[1](true,'granted')
	check(hiddenResults==1 and hidden:Query(origin,'camera')=='prompt','late click on hidden UI cannot persist grant')
	hidden:Request({Origin=origin,Names={'camera'}},function(ok)check(ok==false,'hidden page cannot open permission prompt')end)
	check(#hiddenUI.Prompts==1,'hidden page prompt not created')
	hidden:Destroy()

	local canceled,canceledUI=fixture({});local canceledResults=0
	local cancelRequest=canceled:Request({Origin=origin,Names={'camera'}},function()canceledResults+=1 end)
	cancelRequest();cancelRequest();canceledUI.Replies[1](true,'granted')
	check(canceledResults==0 and canceledUI.Cancels()==1 and canceled:Query(origin,'camera')=='prompt','explicit cancellation retires UI and ignores answer')
	canceled:Destroy()
	local closing,closingUI=fixture({});local closingResults=0
	closing:Subscribe(origin,function()error('closed subscription ran')end)
	closing:Request({Origin=origin,Names={'camera'}},function()closingResults+=1 end)
	closing:Destroy();closing:Destroy();closingUI.Replies[1](true,'granted')
	check(closingUI.Cancels()==1 and closingResults==0 and closing:Query(origin,'camera')=='prompt','teardown never resumes a closed realm or persists late access')

	local unavailable=PermissionHost.new({},{})
	for _,request in{{Origin=origin,Names={'camera'}},{Origin='null',Names={'camera'}},{Origin=origin,Names={'unknown'}},{Origin=origin,Names={}}, {Names={'camera'}}}do
		local answered=0;local done=unavailable:Request(request,function(ok,message)answered+=1;check(ok==false and type(message)=='string','invalid/unavailable request deterministically rejected')end)
		done();check(answered==1,'invalid/unavailable completion once')
	end
	unavailable:Destroy()
	local synchronousCancel=0
	local synchronous=PermissionHost.new({Show=function(_,complete)complete(true,'granted');return function()synchronousCancel+=1 end end},{})
	local answered=0
	synchronous:Request({Origin=origin,Names={'camera'}},function(ok)answered+=1;check(ok==true,'synchronous UI answer accepted')end)
	check(answered==1 and synchronousCancel==1,'synchronous answer releases returned UI cancellation')
	synchronous:Destroy()
	local failed=PermissionHost.new({Show=function()error('UI failed')end},{})
	failed:Request({Origin=origin,Names={'camera'}},function(ok,message)check(ok==false and message=='Permission prompt failed.','UI failure completes deterministic access error')end)
	check(failed:Query(origin,'camera')=='prompt','UI failure does not store denial');failed:Destroy()
	local retired=PermissionHost.new({Show=function(_,complete)complete(true,'granted')end},{})
	retired:Subscribe(origin,function()retired:Destroy()end)
	local retiredResults=0
	retired:Request({Origin=origin,Names={'camera'}},function()retiredResults+=1 end)
	check(retiredResults==0,'state notification may destroy realm before completion')
	print('PermissionHost: '..count..' origin/session, combined access, dismissal and teardown controls passed')
end
