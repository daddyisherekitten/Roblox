--!strict
return function(Parser,Runtime,Events)
	local events=Events.new(error);local output={};local clock=0;local requests={}
	local doc=Parser.parseDocument([[<!doctype html><body><script>
document.addEventListener('DOMContentLoaded',()=>{console.log('dcl');queueMicrotask(()=>{var script=document.createElement('script');script.src='late.js';document.body.append(script);});});
window.addEventListener('load',()=>console.log('load'));
</script></body>]])
	local realm=Runtime.new(doc,{URL="https://scripts.test/index.html",Events=events,Clock=function()return clock end,Schedule=function()end,ApplyChanges=function()return false end,
		Console=function(_,value)table.insert(output,value)end,LoadScript=function(url,complete)requests[url]=complete end})
	local function pump()for _=1,10 do clock+=.01;realm:PumpTasks();realm.EventLoop:Checkpoint()end end
	local supported=realm:Run([[if(!HTMLScriptElement.supports('classic')||!HTMLScriptElement.supports('module')||!HTMLScriptElement.supports('importmap')||HTMLScriptElement.supports('Module')||HTMLScriptElement.supports('text/javascript'))throw new Error('Script supports follows exact type tokens');
try{HTMLScriptElement.supports();throw new Error('Missing type should fail');}catch(e){if(e.name!=='TypeError')throw e;}
try{HTMLScriptElement.supports(Symbol());throw new Error('Symbol type should fail');}catch(e){if(e.name!=='TypeError')throw e;}]])
	assert(supported)
	realm:Start();pump();assert(table.concat(output," ")=="dcl","Late resource postpones an already queued load task")
	requests["https://scripts.test/late.js"](true,"console.log('late');");pump();assert(table.concat(output," ")=="dcl late load")
	local ok=realm:Run("var s=document.createElement('script');s.src='after.js';document.body.append(s);");assert(ok)
	requests["https://scripts.test/after.js"](true,"console.log('after');");pump();assert(table.concat(output," ")=="dcl late load after","Document load only fires once")
	assert(realm:Run([[var detached=document.createElement('script');detached.src='detached.js';document.body.append(detached);detached.remove();
var adopted=document.createElement('script');adopted.src='adopted.js';document.body.append(adopted);document.implementation.createHTMLDocument('Other').adoptNode(adopted);]]))
	requests["https://scripts.test/detached.js"](true,"console.log('detached',document.currentScript===detached);")
	requests["https://scripts.test/adopted.js"](true,"console.log('must-not-run');");pump()
	assert(table.concat(output," ")=="dcl late load after detached true","Removing preserves the prepared owner; adopting suppresses execution")
	assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,"\n"));realm:Destroy();events:Destroy()
	-- An inline document.open replaces the script loader's parser while the
	-- original blocking-script continuation is still on the host stack.
	do
		local source=[[<script>document.open();document.write('<p id="replacement">Replacement</p>');window.replacementReached=true;</script><script>throw new Error('discarded old document script')</script>]]
		local document=Parser.parseDocument(source)
		local bus=Events.new(error);local states={}
		local replacement=Runtime.new(document,{URL="https://scripts.test/replaced.html",Events=bus,Schedule=function()end,ApplyChanges=function()return false end,
			DocumentLoadStateChanged=function(state)table.insert(states,state)end})
		replacement:Start()
		assert(replacement.Window.Get("replacementReached")==true and replacement.ScriptLoader.Generation==1,"The initial script synchronously replaced its parser and continued")
		assert(table.concat(states," ")=="loading","The retired blocking continuation must not prematurely mark the replacement interactive")
		assert(replacement:Run("if(document.readyState!=='loading'||!document.getElementById('replacement'))throw new Error('Replacement parser is still loading');document.close();"))
		for _=1,5 do replacement:PumpTasks()end
		assert(replacement.ScriptLoader:IsDocumentComplete()and table.concat(states," ")=="loading interactive complete","Only document.close completes the replacement document")
		assert(#replacement.Diagnostics==0,table.concat(replacement.Diagnostics,"\n"))
		replacement:Destroy();bus:Destroy()
	end
	print("Script lifecycle: resources created in DOMContentLoaded microtasks postpone window.load; late scripts do not repeat it")
end
