--!strict
-- Real engine entry, HTMLPage, standalone host and VM. Only native GUI/input,
-- clock/task services and one controlled cooperative mount checkpoint differ.
return function(loadHost,fixture,loadEngine,WorkContext,Parser,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages)
	local f=fixture();local diagnostics={};local checkpoint={Armed=false,Entered=0,Resumed=0}
	local factory={create=f.Create,modifier=f.Create};local renderer=loadRenderTree(factory)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local pageModule=loadHTMLPage({['Rendering/GuiFactory']=factory,['Rendering/RenderTree']={build=function(doc,root,diagnostic)
		if checkpoint.Armed then checkpoint.Armed=false;checkpoint.Entered+=1;coroutine.yield('cooperative-blank-mount');checkpoint.Resumed+=1 end
		return renderer.build(doc,root,diagnostic,function(font)return font end)
	end},['Layout/BlockLayout']=loadBlockLayout(overrides),['Input/Controller']=Controller,['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,{GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then {GetPropertyChangedSignal=function()return f.Signal()end}else nil end},f)
	local hostModule=loadHost(f)
	local engine=loadEngine(function(id)
		assert(not id:find('Browser',1,true)and not id:find('WindowManager',1,true),'Cooperative HTML windows import no optional browser/window manager')
		if id=='HTML/Parser'then return Parser elseif id=='WorkContext'then return WorkContext elseif id=='Rendering/HTMLPage'then return pageModule
		elseif id=='Rendering/StandaloneHost'then return hostModule elseif id=='Websites'then return {resolveURL=function()return{}end}else return{}end
	end)
	local target=f.Create('Frame',f.Screen,{Name='CooperativeTarget',Size=f.UDim2.fromOffset(900,600),BackgroundTransparency=1})
	local page=engine.mountHTML(target,'<title>Cooperative parent</title><p>Parent</p>',{DocumentURL='http://cooperative.test/parent',RenderWorkBudgetMS=0,
		FallbackServices={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,RunService=f.Run,Task=f.Task},
		Diagnostic=function(message)table.insert(diagnostics,message)end,
		JavaScriptServices={Task=f.Task,RunService=f.Run,Clock=function()return f:Clock()end}})
	f:Drain();local host=assert(page.FallbackHost);local runtime=assert(page.JavaScriptRuntime)
	local assertions=0
	local function check(value,message)assertions+=1;assert(value,message)end
	local function value(key)return runtime.Window.Get(key)end
	local function source(code)local ok,message=runtime:Run(code);check(ok,tostring(message))end
	local function openWithCheckpoint(code,name,result)
		checkpoint.Armed=true
		local before=checkpoint.Entered;local finished=false
		local thread=coroutine.create(function()source(code);finished=true end)
		local ok,pause=coroutine.resume(thread)
		check(ok,tostring(pause));check(pause=='cooperative-blank-mount'and not finished,'Native popup construction suspends its native entry')
		check(checkpoint.Entered==before+1 and checkpoint.Resumed==before,'Each popup mounts through exactly one controlled cooperative checkpoint')
		check(runtime:IsExecuting()and runtime:PumpTasks()==0,'Suspended synchronous open retains the author execution gate')
		check(host.Names[name]and host.Names[name].Pending,'The in-flight blank document belongs to its named window')
		local resumed,message=coroutine.resume(thread);check(resumed,tostring(message))
		check(coroutine.status(thread)=='dead'and finished and checkpoint.Resumed==checkpoint.Entered,'Native resumption completes the suspended author entry once')
		f:Drain();check(value(result)==true,'The author receives its own generator/async result after blank DOM availability')
		local context=assert(host.Names[name]);local child=assert(host:GetPage(context.Window))
		check(child.Alive and child.DocumentURL=='about:blank'and child.JavaScriptRuntime.Alive,'The synchronous result refers to a live actual blank document')
		context.Window:Close();f:Drain();check(host.Names[name]==nil and not child.Alive,'The child context and runtime retire after each control')
	end
	openWithCheckpoint([[var plain=open('','plain');var plainResult=plain.document.body!==null;]],'plain','plainResult')
	openWithCheckpoint([[
		var generator=(function*(){var popup=open('','generator');yield popup.document.body!==null;return 'completed';})();
		var first=generator.next();var last=generator.next();
		var generatorResult=first.value===true&&!first.done&&last.value==='completed'&&last.done;
	]],'generator','generatorResult')
	openWithCheckpoint([[
		var asyncResult=false;(async function(){var popup=open('','async');return popup.document.body!==null;})().then(v=>asyncResult=v);
	]],'async','asyncResult')
	openWithCheckpoint([[
		var asyncGeneratorResult=false;var asyncGenerator=(async function*(){var popup=open('','async-generator');yield popup.document.body!==null;})();
		asyncGenerator.next().then(step=>asyncGeneratorResult=step.value===true&&!step.done);
	]],'async-generator','asyncGeneratorResult')
	openWithCheckpoint([[
		var asyncInGeneratorResult=false;var outerGenerator=(function*(){
			var promise=(async function(){var popup=open('','async-in-generator');return popup.document.body!==null;})();yield promise;
		})();outerGenerator.next().value.then(value=>asyncInGeneratorResult=value);
	]],'async-in-generator','asyncInGeneratorResult')
	openWithCheckpoint([[
		var generatorInAsyncResult=false;(async function(){
			var innerGenerator=(function*(){var popup=open('','generator-in-async');yield popup.document.body!==null;})();return innerGenerator.next().value;
		})().then(value=>generatorInAsyncResult=value);
	]],'generator-in-async','generatorInAsyncResult')
	openWithCheckpoint([[
		var outer=(function*(){var inner=(function*(){var popup=open('','nested-generators');yield popup.document.body!==null;})();yield inner.next().value;})();
		var nestedGeneratorsResult=outer.next().value===true;
	]],'nested-generators','nestedGeneratorsResult')
	local before=checkpoint.Entered;checkpoint.Armed=true
	source([[var conversionOrder=[];var symbolRejected=false;try{open({toString(){conversionOrder.push('url');return '';}},Symbol());}catch(e){symbolRejected=e.name==='TypeError';}var conversionResult=symbolRejected&&conversionOrder.join(',')==='url';]])
	check(value('conversionResult')and checkpoint.Armed and checkpoint.Entered==before,'DOMString conversion and Symbol rejection happen before entering the host')
	checkpoint.Armed=false
	page:Destroy();f:Drain();target:Destroy()
	check(not host.Alive and not runtime.Alive and f:GlobalConnections()==0,'Final disposal releases all windows, VMs, inputs and native frame subscriptions')
	check(#diagnostics==0,'No host/VM errors are hidden by the cooperative controls')
	print('Cooperative window.open: '..assertions..' actual mounted synchronous, generator/async/nested stacks, conversion and teardown assertions passed')
end
