--!strict
return function(Parser,Runtime,WorkerRealm,fixtures)
	for _,fixture in fixtures do
		local clock=0;local children,output,errors={},{},{};local sources={};local url="http://worker.test/"
		for key,value in fixture.sources do sources[url..key]=value end
		local parent=Runtime.new(Parser.parseDocument('<!doctype html><html></html>'),{URL=url.."index.html",ScriptSources=sources,SupportsModuleWorkers=true,Clock=function()return clock end,Schedule=function()end,
			Console=function(_,text)table.insert(output,text)end,Diagnostic=function(text)table.insert(errors,text)end,
			SpawnWorker=function(spec,callbacks)
				local realm=WorkerRealm.new(spec,{Sources=sources,Clock=function()return clock end,Message=callbacks.Message,Error=callbacks.Error,Exit=callbacks.Exit})
				table.insert(children,realm);realm:Start();return {PostMessage=function(wire)realm:PostMessage(wire)end,Terminate=function()realm:Destroy()end}
			end})
		local ok,message=parent:Run(fixture.source);assert(ok,fixture.name..": "..tostring(message))
		for _=1,100 do clock+=.002;parent:PumpTasks();for _,realm in children do realm:Pump()end end
		assert(#errors==0,fixture.name..": "..table.concat(errors,"|"))
		assert(table.concat(output,"|")==fixture.expected,fixture.name..": "..table.concat(output,"|"))
		parent:Destroy();for _,realm in children do assert(not realm.Alive and not realm.VM.Alive)end
	end
	print("Worker references: "..#fixtures.." actual-browser startup/await/error/close/transfer traces passed")
end
