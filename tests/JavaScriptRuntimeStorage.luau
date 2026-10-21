--!strict
-- The default HTML host owns bounded storage for its current HTTP(S) origin.
-- Explicit denied adapters and opaque origins retain their security behavior.
return function(Parser,Runtime,Events,Storage)
	local function create(url,getArea)
		local output={};local events=Events.new(error)
		local realm=Runtime.new(Parser.parseDocument('<html><body></body></html>'),{URL=url,Events=events,Schedule=function()end,
			GetStorageArea=getArea,Console=function(_,value)table.insert(output,value)end})
		return realm,output,events
	end
	local first,output,events=create("https://example.test/page")
	first:Run([[localStorage.setItem('draft','kept');sessionStorage.setItem('session','one');console.log(localStorage.getItem('draft'),sessionStorage.getItem('session'));history.pushState(null,'','#step');console.log(localStorage.getItem('draft'));]])
	assert(output[1]=="kept one"and output[2]=="kept")
	local localArea=first.Storage:Get("local").StorageState.Area;local sessionArea=first.Storage:Get("session").StorageState.Area
	assert(localArea~=sessionArea and localArea.Bytes>0 and localArea.QuotaBytes==1048576 and localArea.MaxEntries==4096,"Default memory storage areas are distinct and bounded")
	local second,other,otherEvents=create("https://example.test/other")
	second:Run([[console.log(localStorage.getItem('draft'),sessionStorage.getItem('session'));]])
	assert(other[1]=="null null","Default HTML storage is document owned and does not imply cross-document persistence")
	second:Destroy();otherEvents:Destroy()
	first:Destroy();events:Destroy()
	assert(next(localArea.Values)==nil and #localArea.Order==0 and localArea.Bytes==0 and #localArea.Subscribers==0)
	assert(next(sessionArea.Values)==nil and #sessionArea.Order==0 and sessionArea.Bytes==0 and #sessionArea.Subscribers==0,"Destroy clears owned values/order/bytes after unsubscribing")
	for _,url in {"about:blank","data:text/html,test"}do
		local realm,denied,ownedEvents=create(url)
		realm:Run([[try{localStorage.setItem('x','x')}catch(error){console.log(error.name)}try{sessionStorage.getItem('x')}catch(error){console.log(error.name)}]])
		assert(denied[1]=="SecurityError"and denied[2]=="SecurityError","Opaque origins cannot obtain storage: "..url)
		realm:Destroy();ownedEvents:Destroy()
	end
	local deniedRealm,denied,deniedEvents=create("https://example.test/denied",function()return nil end)
	deniedRealm:Run([[try{localStorage.setItem('x','x')}catch(error){console.log(error.name)}]])
	assert(denied[1]=="SecurityError","An explicitly denied backend is never replaced by the memory fallback")
	deniedRealm:Destroy();deniedEvents:Destroy()
	local external=Storage.createArea({QuotaBytes=256});local externalRealm,externalOutput,externalEvents=create("https://example.test/external",function()return external end)
	externalRealm:Run([[localStorage.setItem('host','persistent');console.log(localStorage.getItem('host'));]])
	assert(externalOutput[1]=="persistent");externalRealm:Destroy();externalEvents:Destroy()
	assert(external.Values.host=="persistent"and external.Bytes>0 and #external.Subscribers==0,"Disposal releases subscriptions while preserving host-owned backend data")
	print("HTML runtime storage: bounded document memory areas, opaque/explicit denial, host override and disposal passed")
end
