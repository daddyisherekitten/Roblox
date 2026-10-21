--!strict
-- One Actor per dedicated worker. JavaScript VM state never crosses this boundary.
local WorkerHost={}
function WorkerHost.new(parent: any,sources: any?,services: any?): any
	services=services or {}
	local create=services.Create or function(class)return Instance.new(class)end
	local template=services.Template or script.Parent.WorkerRunner
	local module=services.Module or script.Parent.Parent.JavaScript.WorkerRealm
	local owned={};local alive=true
	local api={}
	function api:Spawn(spec,callbacks)
		assert(alive,"Worker host disposed")
		assert(type(spec.url)=="string"and type(spec.source)=="string","Worker launch requires a URL and source string")
		local launched=table.clone(spec);launched.sources={};local sourceBytes=0
		for url,value in sources or {}do
			local source=if type(value)=="table" then value.Source else value
			assert(type(url)=="string" and type(source)=="string","Worker resources must contain source strings")
			sourceBytes+=#url+#source;assert(sourceBytes<=4194304,"Worker packaged-resource budget exceeded")
			launched.sources[url]=source
		end
		local previous=launched.sources[spec.url]
		if previous then sourceBytes-=#spec.url+#previous end
		sourceBytes+=#spec.url+#spec.source;assert(sourceBytes<=4194304,"Worker packaged-resource budget exceeded")
		launched.sources[spec.url]=spec.source
		local actor=create("Actor");actor.Name="HTMLWorker"
		local bridge
		local queue={};local bytes=0;local ready,closed=false,false
		local connection;local handle={}
		function handle.Terminate()
			if closed then return end;closed=true;owned[handle]=nil
			if connection then connection:Disconnect();connection=nil end
			table.clear(queue);bytes=0;actor:Destroy()
		end
		function handle.PostMessage(wire)
			if closed then return end
			if ready then actor:SendMessage("message",wire) else
				assert(#queue<1024 and bytes+(wire.ByteLength or 0)<=4194304,"Worker startup queue budget exceeded")
				bytes+=wire.ByteLength or 0;table.insert(queue,wire)
			end
		end
		local ok,message=pcall(function()
			bridge=create("BindableEvent");bridge.Name="Bridge";bridge.Parent=actor
			local reference=create("ObjectValue");reference.Name="WorkerModule";reference.Value=module;reference.Parent=actor
			connection=bridge.Event:Connect(function(kind,payload)
			if closed or not alive then return end
			if kind=="ready" then
				if ready then return end;ready=true;actor:SendMessage("start",launched)
				local pending=queue;queue={};bytes=0;for _,wire in pending do actor:SendMessage("message",wire)end
			elseif kind=="message" then callbacks.Message(payload)
			elseif kind=="error" then callbacks.Error(payload)
			elseif kind=="exit" then handle.Terminate();callbacks.Exit()end
			end)
			local runner=template:Clone();runner.Name="WorkerRunner";runner.Parent=actor
			owned[handle]=true;actor.Parent=parent
		end)
		if not ok then handle.Terminate();error(message,0)end
		return handle
	end
	function api:Destroy()
		if not alive then return end;alive=false
		for handle in owned do handle.Terminate()end;table.clear(owned)
	end
	return api
end
return WorkerHost
