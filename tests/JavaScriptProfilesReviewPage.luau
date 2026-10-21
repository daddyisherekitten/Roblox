--!strict
-- Execute the shipped page and its resource files in independent page/worker VMs.
return function(Parser,Node,Runtime,WorkerRealm,html,services)
	local clock=0;local children={};local errors={};local mutations={}
	local document=Parser.parseDocument(html);local sources=table.clone(services.ScriptSources)
	for key,value in services.ModuleSources or {}do sources[key]=value end
	local realm=Runtime.new(document,{URL="http://localhost:8000/javascript-tests/index.html",Clock=function()return clock end,Schedule=function()end,
		ScriptSources=sources,ModuleSources=sources,SupportsModuleWorkers=true,Diagnostic=function(text)table.insert(errors,text)end,
		Mutation=function(node,kind)table.insert(mutations,{node,kind})end,
		SpawnWorker=function(spec,callbacks)
			local worker=WorkerRealm.new(spec,{Clock=function()return clock end,Sources=sources,Message=callbacks.Message,Error=callbacks.Error,Exit=callbacks.Exit})
			table.insert(children,worker);worker:Start();return {PostMessage=function(wire)worker:PostMessage(wire)end,Terminate=function()worker:Destroy()end}
		end})
	local function pump()
		for _=1,60 do clock+=.005;realm:PumpTasks();for _,worker in children do worker:Pump()end end
		assert(#errors==0,table.concat(errors," | "))
	end
	local function text(id)return Node.textContent(assert(Node.findById(document,id)))end
	local function click(id)
		local ok,message=realm:Run("document.getElementById('"..id.."').dispatchEvent(new MouseEvent('click',{bubbles:true}));")
		assert(ok,tostring(message));pump()
	end
	realm:Start();pump()
	assert(text("js-status")=="Bereit · Skripte, Listen, Canvas, Worker und Fenster sind verbunden.",text("js-status"))
	assert(text("list-output")=="Haus am Hang, Stadthaus und Gartenatelier")
	click("scripts-load");assert(text("script-result")=="Daten → Ansicht · zwei externe Skripte, genau einmal ausgeführt.",text("script-result"))
	click("scripts-load");assert(text("script-result")=="Bereits geladen · Daten → Ansicht bleiben einmalig.")
	click("scripts-inline");assert(text("script-result")=="Inline-Skript ausgeführt · Ansicht hervorgehoben.")
	click("scripts-inline");assert(Node.findById(document,"script-output").Attributes.class:find("highlighted"),"Re-inserting the same script preserves its started state")
	click("lists-language");assert(text("list-output")=="Haus am Hang, Stadthaus, and Gartenatelier")
	click("lists-type");assert(text("list-output")=="Haus am Hang, Stadthaus, or Gartenatelier")
	click("lists-language");assert(text("list-output")=="Haus am Hang, Stadthaus oder Gartenatelier")
	click("paths-rule");assert(text("path-result")=="Füllregel: evenodd · Fensteröffnung: frei · Anbau nur an der Kopie: nein")
	click("paths-copy");assert(text("path-result")=="Füllregel: evenodd · Fensteröffnung: frei · Anbau nur an der Kopie: ja")
	local expected="Summe: 264 · Mittelwert: 33\nZurück: 12, 18, 24, 30, 36, 42, 48, 54 · 8 Bytes\nOhne DOM: ja · Projektlabor"
	for _,id in {"worker-classic","worker-module"}do click(id);assert(text("worker-result")==expected,text("worker-result"))end
	local ok,message=realm:Run("document.getElementById('worker-module').dispatchEvent(new MouseEvent('click'));document.getElementById('worker-stop').dispatchEvent(new MouseEvent('click'));")
	assert(ok,tostring(message));pump();assert(text("worker-result")=="Beendet · spätere Nachrichten werden verworfen.")
	click("dialog-modal");assert(realm.TopLayer:Snapshot(Node.findById(document,"project-dialog")).Modal==true)
	local succeeded,err=realm:Run("document.getElementById('project-dialog').close('bestätigt');")
	assert(succeeded,tostring(err));pump();assert(text("dialog-result")=="Geschlossen · Rückgabe: bestätigt")
	click("dialog-nonmodal");assert(Node.findById(document,"project-dialog").Attributes.open~=nil and not realm.TopLayer:Snapshot(Node.findById(document,"project-dialog")).Modal)
	assert(#children==2 and not children[1].Alive and not children[2].Alive,"Completed and canceled worker instances retain no active execution owners")
	realm:Destroy()
	print("Comparison 07: shipped script resources, Intl parts, canvas geometry, classic/module workers, transfer/termination and dialog controls passed")
end
