--!strict
return function(WorkerHost)
	local created={};local listeners={};local failClass
	local function create(class)
		if class==failClass then error("Injected allocation failure")end
		local object={ClassName=class,Destroyed=0,Messages={}}
		function object:Destroy()self.Destroyed+=1 end
		function object:SendMessage(kind,payload)table.insert(self.Messages,{kind,payload})end
		if class=="BindableEvent"then
			object.Event={Connect=function(_,callback)
				local connection={Alive=true};listeners[object]={Callback=callback,Connection=connection}
				function connection:Disconnect()self.Alive=false end;return connection
			end}
			function object:Fire(...)
				local record=listeners[self];if record.Connection.Alive then record.Callback(...)end
			end
		end
		table.insert(created,object);return object
	end
	local template={Clone=function()return create("LocalScript")end}
	local host=WorkerHost.new({}, {['https://worker.test/helper.js']={Source="function helper(){}"}}, {Create=create,Template=template,Module={}})
	local received={};local exits=0
	local callbacks={Message=function(wire)table.insert(received,wire)end,Error=function(details)table.insert(received,details.message)end,Exit=function()exits+=1 end}
	local spec={url="https://worker.test/main.js",source="postMessage(1)",type="classic"}
	local handle=host:Spawn(spec,callbacks);local actor,bridge=created[1],created[2]
	local first,second={ByteLength=3},{ByteLength=4};handle.PostMessage(first);handle.PostMessage(second)
	assert(#actor.Messages==0,"Messages wait for the actual Actor bootstrap")
	bridge:Fire("ready");bridge:Fire("ready")
	assert(#actor.Messages==3 and actor.Messages[1][1]=="start"and actor.Messages[2][2]==first and actor.Messages[3][2]==second,"Startup runs once and preserves the startup message order")
	assert(actor.Messages[1][2].sources[spec.url]==spec.source and actor.Messages[1][2].sources['https://worker.test/helper.js']=="function helper(){}","Actor receives a separate immutable source package")
	assert(spec.sources==nil,"Packaging never mutates the caller's launch specification")
	handle.PostMessage(first);assert(#actor.Messages==4,"Ready workers use the Actor mailbox")
	bridge:Fire("message",first);bridge:Fire("error",{message="failure"});bridge:Fire("exit");bridge:Fire("message",second)
	handle.Terminate();assert(actor.Destroyed==1 and exits==1 and #received==2,"Exit destroys and disconnects exactly once; late deliveries are ignored")
	host:Spawn(spec,callbacks);local abandonedActor=created[5]
	failClass="ObjectValue";local ok=pcall(host.Spawn,host,spec,callbacks);failClass=nil
	assert(not ok and created[9].Destroyed==1,"Allocation failure cleans up the partially allocated Actor")
	host:Destroy();host:Destroy();assert(abandonedActor.Destroyed==1,"Page destruction terminates outstanding workers exactly once")
	assert(not pcall(host.Spawn,host,spec,callbacks),"A disposed host cannot launch new workers")
	local oversized=WorkerHost.new({}, {large=string.rep("x",4194305)}, {Create=create,Template=template,Module={}})
	local count=#created;assert(not pcall(oversized.Spawn,oversized,spec,callbacks)and #created==count,"Invalid packages are rejected before allocating native instances")
	oversized:Destroy()
	print("Worker host: Actor bootstrap, ordered startup queues, isolated resource packages, allocation recovery and exact-once teardown passed")
end
