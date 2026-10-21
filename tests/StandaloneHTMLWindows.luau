--!strict
-- Actual engine entry/HTMLPage/VM, with native GUI/input/task doubles only.
return function(loadHost,fixture,loadEngine,WorkContext,Parser,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages,loadIFrames)
	local f=fixture();local diagnostics,output={},{}
	local services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,RunService=f.Run,Task=f.Task}
	local factory={create=f.Create,modifier=f.Create};local renderer=loadRenderTree(factory)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local pageModule=loadHTMLPage({['Rendering/GuiFactory']=factory,['Rendering/RenderTree']={build=function(doc,root,diagnostic)return renderer.build(doc,root,diagnostic,function(font)return font end)end},
		['Layout/BlockLayout']=loadBlockLayout(overrides),['Input/Controller']=Controller,['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/IFrameRuntime']=loadIFrames(f.Task),
		['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,{GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then {GetPropertyChangedSignal=function()return f.Signal()end}else nil end},f)
	local hostModule=loadHost(f)
	local sources={
		['http://local.test/a']='<title>Alpha</title><button id="activate">Activate</button><script>var protect=false;addEventListener("beforeunload",e=>{if(protect){e.preventDefault();e.returnValue="edited";}});</script>',
		['http://local.test/b']='<title>Beta</title><p id="beta">Second document</p><script>window.marker="B";</script>',
		['http://other.test/c']='<title>Other origin</title><p>Different origin</p>',
		['http://local.test/held']='<p>Waiting</p><script>try{prompt("Held");console.log("late continuation");}catch(e){console.log("late catch");}finally{console.log("late finally");}</script>',
		['http://local.test/shared']='<p>Shared modal</p><script>window.childPointerdowns=0;addEventListener("pointerdown",()=>childPointerdowns++);window.childRejected=prompt("Child waiting")===null;window.childContinued=true;</script>',
	}
	local staged={}
	local function resolver(base,reference)
		local address=URL.resolve(base,reference).URL;local source=sources[address]
		if not source then return nil end
		return {Kind='internal',URL=address,Website={HTML=source,Options={RenderWorkBudgetMS=0,Task=f.Task,InputServices={Input=f.Input,PlayerGui=f.PlayerGui,Factory=factory,Task=f.Task},AnimationServices={RunService=f.Run},JavaScriptServices={Task=f.Task,RunService=f.Run,
			Console=function(_,value)table.insert(output,value)end,RuntimeCreated=function(realm,page)table.insert(staged,{Realm=realm,Page=page})end}}}}
	end
	local engine=loadEngine(function(id)
		assert(not id:find('Browser',1,true)and not id:find('WindowManager',1,true),'Standalone engine never imports optional top-level modules')
		if id=='HTML/Parser'then return Parser elseif id=='WorkContext'then return WorkContext elseif id=='Rendering/HTMLPage'then return pageModule
		elseif id=='Rendering/StandaloneHost'then return hostModule elseif id=='Websites'then return {resolveURL=function()return{}end}else return{}end
	end)
	local target=f.Create('Frame',f.Screen,{Name='StandaloneTarget',Size=f.UDim2.fromOffset(1100,760),BackgroundTransparency=1})
	local rootCreated=0
	local options={DocumentURL='http://local.test/a',RenderWorkBudgetMS=0,FallbackServices=services,IFrameResolver=resolver,
		FallbackWindow={Title='HTML',Size=f.Vector2.new(740,510),Position=f.Vector2.new(10,10)},
		Diagnostic=function(message)table.insert(diagnostics,tostring(message))end,
		JavaScriptServices={Task=f.Task,RunService=f.Run,Clock=function()return f:Clock()end,Console=function(_,value)table.insert(output,value)end,RuntimeCreated=function()rootCreated+=1 end}}
	local main=engine.mountHTML(target,sources[options.DocumentURL],options);f:Drain()
	local host=assert(main.FallbackHost);local window=assert(main.FallbackWindow)
	assert(host.Manager and host.Manager:GetWindows()[1]==window and main.Root.Visible and main.Alive,'Public mountHTML creates its default functional shell')
	local function run(page,source,drain)
		local ok,message=page.JavaScriptRuntime:Run(source);assert(ok,tostring(message));if drain~=false then f:Drain()end
		assert(#page.JavaScriptRuntime.Diagnostics==0,table.concat(page.JavaScriptRuntime.Diagnostics,' | '))
	end
	local function value(page,key)return page.JavaScriptRuntime.Window.Get(key)end
	local function click(gui)
		local p,s=gui.AbsolutePosition,gui.AbsoluteSize;local down=f:Begin(gui,nil,p.X+s.X/2,p.Y+s.Y/2);f.Input.InputEnded:Fire(down);f:Drain()
	end
	local function respond(accepted,text)
		local dialog=assert(host.Manager.Dialogs[#host.Manager.Dialogs],'No fallback dialog is pending')
		if text~=nil then dialog.Field.Text=text end;click(if accepted then dialog.Accept else dialog.Reject)
	end
	run(main,[[var gotDown=0,gotUp=0;document.getElementById('activate').addEventListener('pointerdown',e=>{gotDown++;e.target.setPointerCapture(e.pointerId);});addEventListener('pointerup',()=>gotUp++);]])
	local control=main.FormModel:Resolve(Node.findById(main.Document,'activate'));local controlGui=control.Item.Gui;local cp,cs=controlGui.AbsolutePosition,controlGui.AbsoluteSize
	local gesture=f:Begin(controlGui,nil,cp.X+cs.X/2,cp.Y+cs.Y/2);f:Drain();assert(value(main,'gotDown')==1,'Native content pointerdown required')
	local title=window.Titlebar.AbsolutePosition;gesture.Position=f.Vector2.new(title.X+150,title.Y+15);f:Hits(window.Titlebar);f.Input.InputEnded:Fire(gesture);f:Drain()
	assert(value(main,'gotUp')==1,'Content-owned pointer capture receives its terminal release over shell chrome')
	local layouts=0;local layoutListener=main.Root:GetAttributeChangedSignal('Status'):Connect(function()if main.Root:GetAttribute('Status')=='ready'then layouts+=1 end end)
	local wp,ws=window.Root.AbsolutePosition,window.Root.AbsoluteSize
	local resize=f:Begin(window.Root,nil,wp.X+ws.X-2,wp.Y+ws.Y-2)
	assert(window.Content:GetAttribute('HTMLViewportResizing')and host.Main.Current.Target:GetAttribute('HTMLViewportResizing'),'The held native grip reaches the actual HTML mount target')
	f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,wp.X+ws.X+26,wp.Y+ws.Y+18));f:Drain()
	assert(layouts==0,'A live grip defers document reflow while native shell geometry changes')
	f.Input.InputEnded:Fire(f:Event(f.Enum.UserInputType.Touch,0,0));assert(window.Content:GetAttribute('HTMLViewportResizing'),'Unrelated pointer release cannot end the resize hold')
	resize.Position=f.Vector2.new(wp.X+ws.X+26,wp.Y+ws.Y+18);f.Input.InputEnded:Fire(resize);f:Drain()
	assert(not host.Main.Current.Target:GetAttribute('HTMLViewportResizing')and layouts==1,'Exact release forwards the final viewport and arranges once');layoutListener:Disconnect()
	main:SetVisible(false);target.Size=f.UDim2.fromOffset(1080,740);f:Drain()
	assert(not window.Root.Visible and not window.Dock.Visible and not main.DocumentVisible,'A parent resize cannot reveal an externally hidden shell')
	main:SetVisible(true);window:Focus();f:Drain();assert(window.Root.Visible and main.DocumentVisible,'Showing the page restores its shell visibility')
	main.FormModel.UserActivationUntil=os.clock()+10
	run(main,'var fullscreenReady=false;document.documentElement.requestFullscreen().then(()=>{fullscreenReady=document.fullscreenElement===document.documentElement;});')
	assert(value(main,'fullscreenReady')and window.Fullscreen and not window.Titlebar.Visible,'The actual Fullscreen API uses the internal shell host seam')
	run(main,'document.exitFullscreen();');assert(not window.Fullscreen and window.Titlebar.Visible,'Fullscreen exit restores the same shell')
	run(main,[[var child=open('', 'preview', 'popup,width=420,height=300,left=80,top=70');child.document.body.innerHTML='<p id="authored">Authored synchronously</p><a id="relative" href="relative">Relative</a>';var blankBase=child.document.baseURI;var blankRelative=child.document.getElementById('relative').href;var reused=open('', 'preview')===child;var childName=child.name;]],false)
	local context=assert(host.Names.preview);local childWindow=context.Window;local blank=host:GetPage(childWindow)
	assert(blank and value(main,'reused')and value(main,'childName')=='preview'and Node.findById(blank.Document,'authored'),'Initial blank DOM and named reuse work before a queued task')
	assert(value(main,'blankBase')=='http://local.test/a'and value(main,'blankRelative')=='http://local.test/relative','Initial blank inherits the creator base for immediate relative DOM/resources')
	f:Drain();assert(host:GetPage(childWindow)==blank and Node.findById(blank.Document,'authored'),'No queued about:blank load replaces synchronous author content')
	assert(rootCreated==1,'Child mounts do not reuse the main owner RuntimeCreated callback')
	run(main,[[document.body.insertAdjacentHTML('beforeend','<a id="jump" href="#activate">Jump</a><a id="download" href="/b" download>Save</a>');var hashEvents=0;addEventListener('hashchange',()=>hashEvents++);document.getElementById('jump').click();]])
	assert(host:GetPage()==main and main.DocumentURL=='http://local.test/a#activate'and value(main,'hashEvents')==1,'Native HTML fragment links update URL/history and scroll without replacing the page')
	run(main,"history.back();")
	assert(host:GetPage()==main and main.DocumentURL=='http://local.test/a','Same-document history traversal keeps the live page')
	run(main,"document.getElementById('download').click();")
	assert(host:GetPage()==main and main.DocumentURL=='http://local.test/a','An unsupported download never becomes an accidental document navigation')
	run(main,"child.name='renamed';child.moveTo(90,80);child.resizeTo(430,310);var geometry=[child.screenX,child.screenY,child.outerWidth,child.outerHeight];")
	assert(host.Names.preview==nil and host.Names.renamed==context and childWindow:GetSize().X==430 and childWindow:GetSize().Y==310,'Name and geometry operations update the actual independent window')
	run(blank,"addEventListener('message',e=>{window.received=e.data;window.messageOrigin=e.origin;window.sourceMatches=e.source===opener;});")
	run(main,"child.postMessage('hello','http://local.test');")
	assert(value(blank,'received')=='hello'and value(blank,'messageOrigin')=='http://local.test'and value(blank,'sourceMatches'),'postMessage uses real realms, source handles and origins')
	run(main,"child.location.href='http://other.test/c';")
	local foreign=host:GetPage(childWindow);assert(foreign~=blank and not blank.Alive and foreign.Alive,'Full navigation replaces the document in the same shell')
	run(main,"var denied=false;try{child.document;}catch(e){denied=e.name==='SecurityError';}var stillOpen=!child.closed;")
	assert(value(main,'denied')and value(main,'stillOpen'),'Cross-origin document access is denied while the window remains open')
	run(main,"child.location='http://local.test/b';")
	local child=host:GetPage(childWindow);assert(child~=foreign and not foreign.Alive and value(child,'marker')=='B','A writable cross-origin location can return to an allowed document')
	childWindow:Minimize();f:Drain();assert(child.Alive and child.DocumentVisible==false and childWindow.State=='minimized','Minimize preserves the page and VM while updating document visibility')
	childWindow:Restore();childWindow:Maximize();f:Drain();assert(child.Alive and child.DocumentVisible and childWindow.State=='maximized','Restore/maximize keep the live document')
	childWindow:Restore()
	run(main,'window.dialogFinished=false;')
	f.Task.spawn(function()run(main,"var answer=prompt('Name?','Default');var confirmed=confirm('Continue?');alert('Done');window.dialogFinished=true;",false)end);f:Drain()
	assert(host.Manager.Dialogs[1].Kind=='prompt'and host.Manager.Dialogs[1].Field.Text=='Default'and value(main,'dialogFinished')==false,'Prompt suspends author code and shows the requested default')
	respond(true,'Tobias');assert(host.Manager.Dialogs[1].Kind=='confirm');respond(false);assert(host.Manager.Dialogs[1].Kind=='alert');respond(true)
	assert(value(main,'answer')=='Tobias'and value(main,'confirmed')==false and value(main,'dialogFinished'),'Dialog controls return synchronous JavaScript values in order')
	f.Task.spawn(function()run(main,'var minimizedWasNull=prompt("Minimize pending")===null;window.afterMinimize=true;',false)end);f:Drain()
	assert(host.Manager.Dialogs[1],'A real author prompt is waiting before minimize')
	window:Minimize();f:Drain()
	assert(#host.Manager.Dialogs==0 and value(main,'minimizedWasNull')and value(main,'afterMinimize')and not main.JavaScriptRuntime:IsExecuting(),'Minimize rejects the live prompt and releases its author waiter exactly once')
	window:Restore();f:Drain();assert(main.Alive and main.DocumentVisible)
	main.Events:Emit(Node.findById(main.Document,'activate'),'mousedown',{isTrusted=true,button=0});f:Drain()
	run(main,"protect=true;location.href='http://local.test/b';")
	assert(host.Manager.Dialogs[1]and host:GetPage()==main and main.Alive,'A beforeunload prompt retains the existing main document')
	respond(false);assert(host:GetPage()==main and main.Alive,'Stay cancels navigation without replacing its page')
	run(main,"protect=false;var unsupported=open('https://unmapped.invalid/');var unavailable=unsupported===null;")
	assert(value(main,'unavailable'),'No transport or fabricated document is provided for unresolved URLs')
	run(main,"var held=open('http://local.test/held','held','popup');")
	local heldContext=assert(host.Names.held);local heldWindow=heldContext.Window
	assert(host.Manager.Dialogs[1]and heldContext.Pending and heldContext.Pending.Runtime,'A pending parser prompt has an owned runtime before mount completes')
	heldWindow:Close();f:Drain()
	assert(host.Names.held==nil and not heldWindow.Alive and not table.find(output,'late continuation')and not table.find(output,'late catch')and not table.find(output,'late finally'),'Forced pending-window teardown abandons the suspended author stack')
	run(main,"child.close();child.close();var immediateClosed=child.closed;var sameTaskDocument=child.document.body!==null;",false)
	assert(value(main,'immediateClosed')and value(main,'sameTaskDocument')and child.Alive,'Logical close precedes deferred physical disposal')
	f:Drain();assert(not child.Alive and not childWindow.Alive and host.Names.renamed==nil,'Repeated close calls dispose once and release named ownership')
	local manager=host.Manager
	main:Destroy();f:Drain()
	assert(not host.Alive and not manager.Alive and not main.Alive and #manager:GetWindows()==0,'The original mount handle owns the full window family')
	target:Destroy();assert(f:GlobalConnections()==0,'All native window, document and modal input/frame subscriptions are released')
	local function mountMore(source,extra)
		local parent=f.Create('Frame',f.Screen,{Size=f.UDim2.fromOffset(1000,700),BackgroundTransparency=1})
		local prepared=table.clone(options);prepared.InputServices={Input=f.Input,PlayerGui=f.PlayerGui,Factory=factory,Task=f.Task}
		for key,value in extra or{}do prepared[key]=value end
		local page=engine.mountHTML(parent,source,prepared);f:Drain();return page,parent
	end
	do
		local embedded,parent=mountMore('<p id="spot">Embedded</p><a href="#spot">Anchor</a>',{FallbackWindow=false,JavaScript=false})
		local owner=embedded.FallbackHost
		assert(owner and embedded.FallbackWindow==nil and embedded.JavaScriptRuntime==nil and #owner.Manager:GetWindows()==0,'Explicit embedding creates no shell and JavaScript=false creates no realm')
		embedded.Navigate('#spot',nil,{Href='#spot'})
		assert(owner:GetPage()==embedded and embedded.DocumentURL=='http://local.test/a#spot','No-VM fragment navigation stays embedded')
		embedded:Destroy();parent:Destroy();f:Drain();assert(not owner.Alive and f:GlobalConnections()==0,'No-VM embedding releases the same host/input ownership')
	end
	do
		local opened,shown=0,0
		local native={Open=function()opened+=1;return nil end,IsClosed=function()return false end}
		local configured,parent=mountMore('<script>var answer=prompt("Provided");var denied=open()===null;</script>',{JavaScriptServices={Task=f.Task,RunService=f.Run,WindowHost=native,
			SimpleDialogHost={Show=function(_,complete)shown+=1;complete(true,'provided');return function()end end}}})
		assert(configured.FallbackHost==nil and configured.FallbackWindow==nil and opened==1 and shown==1 and value(configured,'answer')=='provided'and value(configured,'denied'),'Actual external window/dialog hosts retain precedence without allocating fallback UI')
		configured:Destroy();parent:Destroy();f:Drain();assert(f:GlobalConnections()==0,'External host precedence does not add internal native subscriptions')
	end
	do
		local resizing,parent=mountMore(sources[options.DocumentURL]);local owner=resizing.FallbackHost;local shell=resizing.FallbackWindow
		local p,s=shell.Root.AbsolutePosition,shell.Root.AbsoluteSize
		local hold=f:Begin(shell.Root,nil,p.X+s.X-2,p.Y+s.Y-2)
		run(resizing,"location.href='http://local.test/b';")
		local pending=assert(owner.Main.Pending)
		assert(pending.Page and pending.Target:GetAttribute('HTMLViewportResizing')and owner:GetPage()==resizing and resizing.Alive and resizing.Root.Visible and resizing.Root.Parent.Visible,'A replacement mounted during a held resize inherits the hold and keeps the previous document painted')
		local waiting=pending.Page;local old=resizing
		local observedLayoutBarrier=false
		local barrier=waiting.Root:GetAttributeChangedSignal('Status'):Connect(function()
			if waiting.Root:GetAttribute('Status')=='ready'and waiting.Root:GetAttribute('Presented')==false then
				observedLayoutBarrier=true
				assert(owner:GetPage()==old and old.Alive and old.Root.Visible and old.Root.Parent.Visible and not pending.Target.Visible,'Layout readiness alone must not retire the old standalone page before its replacement finishes presentation')
			end
		end)
		old:AddCleanup(function()
			assert(owner:GetPage()==waiting and waiting.Root:GetAttribute('Presented')and waiting.Root.Visible and pending.Target.Visible,'The completed standalone replacement must paint before old-page cleanup')
		end)
		f.Input.InputEnded:Fire(hold);f:Drain()
		barrier:Disconnect()
		assert(observedLayoutBarrier and owner:GetPage()==waiting and waiting.Alive and not old.Alive and not pending.Target:GetAttribute('HTMLViewportResizing'),'Release atomically publishes the newly arranged replacement after both real layout and presentation barriers')
		old:Destroy();f:Drain();assert(not waiting.Alive and not owner.Alive,'The original mount handle still owns the family after full main-document replacement')
		parent:Destroy();assert(f:GlobalConnections()==0)
	end
	do
		local guarded,parent=mountMore(sources[options.DocumentURL]);local owner=guarded.FallbackHost;local shell=guarded.FallbackWindow
		guarded.Events:Emit(Node.findById(guarded.Document,'activate'),'mousedown',{isTrusted=true,button=0});run(guarded,'protect=true;')
		local result;local leave=coroutine.create(function()result=shell:RequestClose()end)
		local ok,message=coroutine.resume(leave);assert(ok,tostring(message));assert(coroutine.status(leave)=='suspended'and owner.Manager.Dialogs[1],'The native close guard can wait on beforeunload')
		shell:Close();f:Drain()
		assert(coroutine.status(leave)=='dead'and result==false and not guarded.Alive and not owner.Alive,'Forced close settles the native guard waiter without reviving author code')
		parent:Destroy();assert(f:GlobalConnections()==0)
	end
	do
		local framed,parent=mountMore('<iframe src="http://local.test/held"></iframe>')
		local owner=framed.FallbackHost;local shell=framed.FallbackWindow
		assert(owner.Manager.Dialogs[1]and framed.IFrameRuntime and framed.IFrames[1].Loading,'A pending raw iframe uses the containing host dialog without another window wrapper')
		local childRealm=staged[#staged].Realm
		shell:Close();f:Drain()
		assert(not framed.Alive and not childRealm.Alive and not owner.Alive and not table.find(output,'late continuation')and not table.find(output,'late catch')and not table.find(output,'late finally'),'Force-closing the parent retires a dialog-waiting iframe realm and abandons its author continuation')
		parent:Destroy();assert(f:GlobalConnections()==0)
	end
	do
		local framed,parent=mountMore('<iframe src="http://local.test/shared"></iframe>')
		local owner=framed.FallbackHost
		assert(owner.Manager.Dialogs[1]and owner.Manager.Dialogs[1].Kind=='prompt','Child realm owns the first pending modal')
		local childRecord=staged[#staged]
		run(framed,"var sibling=open('', 'sibling-input', 'popup,width=300,height=200,left=600,top=350');")
		local sibling=assert(owner.Names['sibling-input']);local siblingWindow=sibling.Window
		click(siblingWindow.CloseButton)
		assert(not siblingWindow.Alive and childRecord.Realm.Window.Get('childPointerdowns')==0 and childRecord.Realm.SimpleDialogs.Pending~=nil and owner.Manager.Dialogs[1],'A native sibling-window click never enters the dialog-waiting iframe or dismisses its modal')
		f.Task.spawn(function()run(framed,'var parentConfirmed=confirm("Parent replaces child");window.parentContinued=true;',false)end);f:Drain()
		assert(owner.Manager.Dialogs[1]and owner.Manager.Dialogs[1].Kind=='confirm'and childRecord.Realm.Window.Get('childRejected')==true and childRecord.Realm.Window.Get('childContinued')==true and childRecord.Realm.SimpleDialogs.Pending==nil,'A new live realm modal rejects and resumes the displaced child instead of abandoning its waiter')
		click(owner.Manager.Dialogs[1].Accept)
		assert(value(framed,'parentConfirmed')and value(framed,'parentContinued')and #owner.Manager.Dialogs==0 and not childRecord.Realm:IsExecuting(),'The replacing modal returns and both nested author entries unwind')
		framed:Destroy();parent:Destroy();f:Drain();assert(f:GlobalConnections()==0)
	end
	assert(#diagnostics==0,table.concat(diagnostics,' | '))
	print('Standalone HTML windows: actual engine entry, blank identity, geometry, origins/messages, modal results, guarded navigation, logical close and pending teardown passed')
end
