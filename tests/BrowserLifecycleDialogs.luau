--!strict
-- Actual HTMLPage/JS realms behind Browser and WindowManager, with controlled
-- native services. UI response, staging and disposal exercise the full adapter.
return function(loadWindows,loadHost,loadBrowser,loadBinding,fixture,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages,loadIFrameRuntime,nativeCloseReference)
	local f=fixture();local services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,RunService=f.Run,Task=f.Task}
	local function click(object)
		local p,s=object.AbsolutePosition,object.AbsoluteSize;local down=f:Begin(object,nil,p.X+s.X/2,p.Y+s.Y/2);f.Input.InputEnded:Fire(down)
	end
	local factory={create=f.Create,modifier=f.Create};local renderer=loadRenderTree(factory)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local pageModule=loadHTMLPage({['Rendering/GuiFactory']=factory,['Rendering/RenderTree']={build=function(doc,root,diagnostic)return renderer.build(doc,root,diagnostic,function(font)return font end)end},
		['Layout/BlockLayout']=loadBlockLayout(overrides),['Input/Controller']=Controller,['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/IFrameRuntime']=loadIFrameRuntime(f.Task),
		['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,{GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then {GetPropertyChangedSignal=function()return f.Signal()end}else nil end},f)
	local trace,diagnostics,realms={},{},{}
	local prefix='<!doctype html><html><head><title>Lifecycle</title></head><body><button id="activate">Activate</button><script>'
	local hooks=[=[
	var protectPage=false;
	addEventListener('beforeunload',function(e){console.log('before');if(protectPage){e.preventDefault();e.returnValue='edited';}});
	addEventListener('pagehide',function(e){console.log('hide:'+e.persisted);});
	document.addEventListener('visibilitychange',function(){console.log('visibility:'+document.visibilityState);});
	addEventListener('unload',function(){console.log('unload');});
	]=]
	local sources={A=prefix.."var answer=prompt('Name?','Default');console.log('answer:'+answer);"..hooks..'</script></body></html>',
		B=prefix..hooks..'</script></body></html>',Held=prefix.."try{prompt('Held');console.log('late continuation');}catch(e){console.log('late catch');}finally{console.log('late finally');}"..'</script></body></html>',
		Frame=prefix..hooks..'</script><iframe id="child" src="/b/index.html"></iframe></body></html>'}
	local engine={URL=URL,Websites={}}
	function engine.Websites.names()return {}end
	function engine.Websites.url()return 'http://localhost:8000/a/index.html'end
	function engine.Websites.resolveURL(base,href)
		local result=URL.resolve(base,href)
		for name in sources do if result.Path=='/'..name:lower()..'/index.html'then result.Kind='internal';result.Name=name;break end end
		return result
	end
	function engine.Websites.get(name)return {HTML=assert(sources[name]),Options={RenderWorkBudgetMS=0,Task=f.Task,InputServices={Task=f.Task,Input=f.Input,PlayerGui=f.PlayerGui},
		IFrameResolver=function(base,href)local resolved=engine.Websites.resolveURL(base,href);if resolved.Name then resolved.Website=engine.Websites.get(resolved.Name)end;return resolved end,
		JavaScriptServices={Task=f.Task,RunService=f.Run,Clock=function()return f:Clock()end,RuntimeCreated=function(realm,child)table.insert(realms,{Realm=realm,Page=child,Name=name})end,
		Console=function(_,message)table.insert(trace,name..':'..message)end}}}end
	function engine.mountHTML(target,html,options)return pageModule.mount(target,html,options)end
	local manager=loadWindows(f).new(f.Screen,{Animations=false,Services=services})
	local host=loadHost(f).new(manager,loadBrowser(f),loadBinding(f),engine,{Services=services,PersistenceEnabled=false,Diagnostic=function(message)table.insert(diagnostics,tostring(message))end})
	local main=host:Open(engine.Websites.url());f:Drain()
	local browser=main.Browser;local tab=browser:GetActiveTab()
	assert(not main.Binding:GetPage(tab)and tab.Loading and browser.Overlays.Current.Kind=='ScriptDialog','A parser script prompt must be available before its pending page has mounted')
	local panel=browser.Overlays.Current.Panel
	assert(panel:FindFirstChild('DialogValue').Text=='Default')
	panel:FindFirstChild('DialogValue').Text='Tobias'
	click(panel:FindFirstChild('DialogAccept'));f:Drain()
	local page=assert(main.Binding:GetPage(tab),'The accepted prompt did not release the page mount')
	assert(#page.JavaScriptRuntime.Diagnostics==0,table.concat(page.JavaScriptRuntime.Diagnostics,' | '))
	assert(page.Root.Visible and not tab.Loading and page.JavaScriptRuntime.Window.Get('answer')=='Tobias'and trace[1]=='A:answer:Tobias')
	local function run(p,source)local ok,message=p.JavaScriptRuntime:Run(source);assert(ok,tostring(message));f:Drain()end
	local function activate(p)
		p.Events:Emit(Node.findById(p.Document,'activate'),'mousedown',{isTrusted=true,button=0});f:Drain()
	end
	local function begin(action)f.Task.spawn(action);f:Drain()end
	local function respond(accepted,targetBrowser)
		local dialog=assert((targetBrowser or browser).Overlays.Current,'No dialog is waiting')
		click(assert(dialog.Panel:FindFirstChild(if accepted then 'DialogAccept'else 'DialogCancel')));f:Drain()
	end
	activate(page);run(page,'protectPage=true;');table.clear(trace)
	begin(function()browser:Navigate(tab,'http://localhost:8000/b/index.html')end)
	assert(browser.Overlays.Current and page.Alive and page.Root.Visible and main.Binding:GetPage(tab)==page and #trace==1 and trace[1]=='A:before','An undecided leave guard must retain the existing page without a visibility transition: '..table.concat(trace,'|')..' overlay='..tostring(browser.Overlays.Current~=nil)..' alive='..tostring(page.Alive)..' visible='..tostring(page.Root.Visible)..' / '..table.concat(diagnostics,'|'))
	respond(false)
	assert(not tab.Pending and not tab.Loading and page.Alive and page.Root.Visible and main.Binding:GetPage(tab)==page,'Rejecting beforeunload must cancel navigation without replacing the document')
	table.clear(trace)
	begin(function()browser:Navigate(tab,'#activate',{Source='address'})end)
	assert(browser.Overlays.Current and #trace==1 and trace[1]=='A:before','An omnibox search must not bypass beforeunload by looking like a raw fragment')
	respond(false);assert(page.Alive and main.Binding:GetPage(tab)==page)
	table.clear(trace)
	begin(function()browser:Navigate(tab,engine.Websites.url(),{Source='address'})end)
	assert(browser.Overlays.Current and #trace==1,'A full navigation to the same URL is a new document, not a fragment change')
	respond(false);table.clear(trace)
	begin(function()browser:Navigate(tab,engine.Websites.url()..'#activate',{Source='content'})end)
	assert(not browser.Overlays.Current and main.Binding:GetPage(tab)==page and #trace==0,'A fragment-only navigation must not request beforeunload: '..table.concat(trace,'|')..' overlay='..tostring(browser.Overlays.Current~=nil)..' url='..tostring(tab.URL)..' / '..table.concat(diagnostics,'|'))
	table.clear(trace)
	begin(function()browser:Navigate(tab,'http://localhost:8000/b/index.html')end)
	respond(true)
	local replacement=assert(main.Binding:GetPage(tab))
	assert(replacement~=page and not page.Alive and replacement.Root.Visible)
	assert(table.concat(trace,'|')=='A:before|A:hide:false|A:visibility:hidden|A:unload','The old page must commit pagehide, hidden and unload once, after approval: '..table.concat(trace,'|'))
	-- Minimizing and restoring changes visibility without unloading the document.
	table.clear(trace)
	main.Window:Minimize();f:Drain()
	assert(replacement.JavaScriptRuntime.Window.Get('document').Get('visibilityState')=='hidden')
	main.Window:Restore();f:Drain()
	assert(replacement.Alive and #trace==2 and table.find(trace,'B:visibility:hidden')and table.find(trace,'B:visibility:visible'),'Retained window visibility: '..table.concat(trace,'|'))
	assert(not replacement.JavaScriptRuntime.Window.Get('document').Get('hidden')and #browser:GetTabs()==1,'Restoring retains the single document realm')
	-- window.close returns immediately; its queued native close still honors
	-- beforeunload, including Promise/async callers and a rejected close.
	run(replacement,"var popup=open('http://localhost:8000/b/index.html','guarded-popup','popup');")
	local popupWindow=assert(manager:GetWindows()[2]);local popup=assert(host.Windows[popupWindow])
	local popupPage=assert(popup.Binding:GetPage(popup.Browser:GetActiveTab()))
	activate(popupPage);run(popupPage,'protectPage=true;');table.clear(trace)
	begin(function()run(popupPage,"Promise.resolve().then(function(){var result=close();console.log('close result:'+String(result));});")end)
	assert(popup.Browser.Overlays.Current and popupPage.Alive and popupWindow.Alive and trace[1]=='B:close result:undefined'and trace[2]=='B:before','JS close returns before its queued leave confirmation')
	respond(false,popup.Browser);assert(popupWindow.Alive and popupPage.Alive)
	table.clear(trace)
	begin(function()run(popupPage,"async function requestClose(){close();return 'async returned';}requestClose().then(function(value){console.log(value);});")end)
	assert(trace[1]=='B:async returned'and popup.Browser.Overlays.Current and popupPage.Alive,'An async close caller must resolve normally before the native close guard')
	respond(true,popup.Browser);assert(not popupWindow.Alive and not popupPage.Alive and main.Window.Alive)
 -- Additive logical-closing controls; original guard/Stay/retry checks above remain unchanged.
 do
  local controls,checks=0,0
  local function check(value,label)checks+=1;assert(value,label)end
  local function global(p,key)return p.JavaScriptRuntime.Window.Get(key)end
  local function direct(p,source)local ok,message=p.JavaScriptRuntime:Run(source);check(ok,tostring(message));check(#p.JavaScriptRuntime.Diagnostics==0,table.concat(p.JavaScriptRuntime.Diagnostics,' | '))end
  local function fresh(name,isPopup)
   run(replacement,"var closingTarget=open('http://localhost:8000/b/index.html','"..name.."','"..(if isPopup then'popup'else'').."');")
   local context=assert(host.Names[name]);local record=context.Record;local child=assert(record.Binding:GetPage(context.Tab))
   return {Window=record.Window,Record=record,Page=child,Tab=context.Tab,Context=context,Handle=context.Handle,Popup=isPopup}
  end
  local function guard(h,callback)
	  local old=h.Window.CloseGuard;h.Window:SetCloseGuard(function(...)return callback(old,...)end);return function()if h.Window.Alive then h.Window:SetCloseGuard(old)end end
  end
  for _,popupMode in{true,false}do
   local h=fresh(if popupMode then'immediate-popup'else'immediate-tab',popupMode);local calls=0
   local restore=guard(h,function(old,...)
    calls+=1;check(h.Handle.IsClosed()and not h.Handle.IsDiscarded(),'Guard begins with logical closing and physical document alive');return old(...)
   end)
   direct(replacement,[=[
    closingTarget.close();closingTarget.close();var immediateClosed=closingTarget.closed;
    var immediateDocument=closingTarget.document.body!==null;var immediateName=closingTarget.name;var immediateURL=closingTarget.location.href;
    queueMicrotask(()=>{window.microClosed=closingTarget.closed;window.microDocument=closingTarget.document.body!==null;closingTarget.close();});
   ]=])
   check(global(replacement,'immediateClosed')and global(replacement,'microClosed'),'Close synchronously exposes closed to same stack and microtasks')
   check(global(replacement,'immediateDocument')and global(replacement,'microDocument')and global(replacement,'immediateName')==h.Context.Name and global(replacement,'immediateURL')=='http://localhost:8000/b/index.html','Same-origin document/name/location remain physically available')
   check(h.Page.Alive and h.Tab.Alive and calls==0,'Author stack and microtasks precede deferred native guard')
   f:Drain();check(calls==1 and not h.Page.Alive and not h.Tab.Alive and h.Handle.IsClosed()and h.Handle.IsDiscarded(),'Repeated close calls coalesce into one native close')
   check(main.Window.Alive and replacement.Alive,'Closing target preserves caller document');restore();controls+=1
  end
  do
   local h=fresh('self-closing',true);table.clear(trace)
   direct(h.Page,"close();close();opener.selfSyncClosed=closed;opener.selfSyncDocument=document.body!==null;queueMicrotask(()=>{opener.selfMicroClosed=closed;opener.selfMicroDocument=document.body!==null;close();});")
   check(global(replacement,'selfSyncClosed')and global(replacement,'selfMicroClosed')and global(replacement,'selfSyncDocument')and global(replacement,'selfMicroDocument'),'Self close retains its author stack and microtasks with logical state visible')
   check(h.Page.Alive,'Self realm waits for queued close');f:Drain();check(not h.Page.Alive and h.Handle.IsDiscarded(),'Self close physically disposes after author checkpoint');controls+=1
  end
  for _,popupMode in{true,false}do
   local name=if popupMode then'stay-popup'else'stay-tab';local h=fresh(name,popupMode);activate(h.Page);run(h.Page,'protectPage=true;');table.clear(trace)
   direct(replacement,"closingTarget.close();closingTarget.close();var reusedWhileQueued=open('', '"..name.."')===closingTarget;")
   check(global(replacement,'reusedWhileQueued')and h.Handle.IsClosed()and not h.Handle.IsDiscarded(),'Empty named open reuses physically live closing context before its task')
   f:Drain();check(h.Record.Browser.Overlays.Current and h.Page.Alive and h.Handle.IsClosed(),'Pending confirmation retains closing flag')
   direct(replacement,"var pendingClosed=closingTarget.closed;var pendingDocument=closingTarget.document.body!==null;closingTarget.close();")
   check(global(replacement,'pendingClosed')and global(replacement,'pendingDocument'),'Pending guard does not prematurely discard same-origin proxy access')
   check(#trace==1 and trace[1]=='B:before','Only one beforeunload is dispatched for repeated queued/pending close')
   respond(false,h.Record.Browser)
   check(not h.Handle.IsClosed()and not h.Handle.IsDiscarded()and h.Page.Alive,'Host Stay resets logical closing without disposing document')
   run(replacement,"var reusedAfterStay=open('', '"..name.."')===closingTarget;")
   check(global(replacement,'reusedAfterStay')and h.Record.Binding:GetPage(h.Tab)==h.Page and host.Names[name]==h.Context,'Stay preserves named context, proxy and page identity')
   direct(replacement,'closingTarget.close();');f:Drain();check(h.Handle.IsClosed()and h.Record.Browser.Overlays.Current,'A later explicit close can retry after Stay')
   respond(true,h.Record.Browser);check(h.Handle.IsClosed()and h.Handle.IsDiscarded()and not h.Page.Alive,'Approved retry physically closes once');controls+=1
  end
  do
   local h=fresh('force-closing-pending',true);activate(h.Page);run(h.Page,'protectPage=true;');direct(replacement,'closingTarget.close();');f:Drain()
   check(h.Record.Browser.Overlays.Current and h.Handle.IsClosed(),'Actual beforeunload is pending before forced close')
   h.Window:Close();f:Drain();check(not h.Page.Alive and h.Handle.IsDiscarded()and h.Handle.IsClosed()and host.Names['force-closing-pending']==nil,'Forced physical close retires pending guard, context and realm');controls+=1
  end
  do
   local h=fresh('force-closing-queued',true);direct(replacement,'closingTarget.close();');h.Window:Close();f:Drain()
   check(h.Handle.IsDiscarded()and not h.Page.Alive and host.Names['force-closing-queued']==nil,'Forced close before native close task leaves its later callback inert');controls+=1
  end
  do
   local h=fresh('close-guard-reentry',true);local calls=0
   local restore=guard(h,function()
    calls+=1;h.Handle.close();check(h.Handle.IsClosed()and not h.Handle.IsDiscarded(),'Reentrant guard observes current logical closing');return false
   end)
   h.Handle.close();h.Handle.close();f:Drain();check(calls==1 and h.Page.Alive and not h.Handle.IsClosed(),'Rejected guard reentry creates no second queued request')
   restore();h.Handle.close();f:Drain();check(not h.Page.Alive,'Reentry rejection permits a later normal close');controls+=1
  end
  for _,failure in{'guard','defer','defer reentry','forced guard'}do for _,kind in{'nil','false','table'}do
   local token=if kind=='false'then false elseif kind=='table'then{}else nil
   local h=fresh(failure..'-'..kind,true);local restore
   if failure=='guard'or failure=='forced guard'then restore=guard(h,function()if failure=='forced guard'then h.Window:Close()end;error(token,0)end)end
   local defer=f.Task.defer;local queued
   if failure=='defer'or failure=='defer reentry'then f.Task.defer=function()if failure=='defer reentry'then h.Handle.close();check(h.Handle.IsClosed(),'Reentrant scheduler sees the existing closing request')end;error(token,0)end
   else f.Task.defer=function(callback,...)queued={Callback=callback,Arguments=table.pack(...)};return {}end end
   local requested,reason=pcall(h.Handle.close);f.Task.defer=defer
   local completed,value
   if failure=='defer'or failure=='defer reentry'then completed,value=requested,reason
   else check(requested and queued~=nil,'Close request returns before executing erroring native guard');completed,value=pcall(queued.Callback,table.unpack(queued.Arguments,1,queued.Arguments.n))end
   check(not completed and value==token,'First original '..failure..' '..kind..' payload preserved')
   if failure=='forced guard'then
    check(h.Handle.IsClosed()and h.Handle.IsDiscarded()and not h.Page.Alive,'Guard destruction/error cannot resurrect forgotten context')
   else
    check(not h.Handle.IsClosed()and not h.Handle.IsDiscarded()and h.Page.Alive,'Failed scheduling/guard releases logical flag for live context')
    if restore then restore()end;h.Handle.close();f:Drain();check(not h.Page.Alive,'Failed request remains retryable')
   end
   f:Drain();controls+=1
  end end
  do
   local h=fresh('caption-already-pending',true);activate(h.Page);run(h.Page,'protectPage=true;');table.clear(trace)
   begin(function()click(h.Window.CloseButton)end)
   check(h.Window.CloseRequestPending and h.Record.Browser.Overlays.Current and not h.Handle.IsClosed(),'Native caption guard is already pending before JS request')
   direct(replacement,'closingTarget.close();closingTarget.close();');check(h.Handle.IsClosed(),'JS request marks closing before its own native task')
   f:Drain();check(h.Window.CloseRequestPending and not h.Handle.IsClosed()and #trace==1,'Already-busy caption guard declines the queued JS request without another guard')
   respond(false,h.Record.Browser);check(h.Page.Alive and not h.Handle.IsClosed(),'Caption Stay keeps the context retryable')
   h.Handle.close();f:Drain();respond(true,h.Record.Browser);check(not h.Page.Alive and h.Handle.IsDiscarded(),'Later JS retry may close after caption Stay');controls+=1
  end
  for _,accepted in{false,true}do
   local h=fresh(if accepted then'navigate-guard-accept'else'navigate-guard-stay',true);local original=h.Window.CloseGuard
   h.Window:SetCloseGuard(function()
    h.Record.Browser:Navigate(h.Tab,'http://localhost:8000/frame/index.html',{Source='host'});return accepted
   end)
   h.Handle.close();f:Drain()
   if accepted then
    check(h.Handle.IsDiscarded()and not h.Page.Alive and host.Names['navigate-guard-accept']==nil,'Accepted close cancels the guard-created deferred navigation without resurrection')
   else
    local current=assert(h.Record.Binding:GetPage(h.Tab));check(current~=h.Page and not h.Page.Alive and current.Alive and not h.Handle.IsClosed(),'Rejected close retains its navigated context and resets only logical closing')
    h.Window:SetCloseGuard(original);h.Handle.close();f:Drain();check(h.Handle.IsDiscarded()and not current.Alive,'Navigated context closes through the original guard after retry')
   end
   controls+=1
  end
  check(controls==23,'Exact additive closing-state control inventory')
  check(nativeCloseReference.target.commit=='ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c'and nativeCloseReference.target.sha256=='49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f'and#nativeCloseReference.cases==5,'Independent native capture retains frozen source pin and exact case inventory')
  local function phase(row,label)for _,entry in row do if entry.phase==label then return entry end end;error('Missing native phase '..label)end
  local raw=nativeCloseReference.cases
  local sync,micro=phase(raw[1].trace,'opener sync'),phase(raw[1].trace,'opener microtask')
  check(sync.closed and micro.closed and sync.documentAvailable and micro.documentAvailable and not raw[1].physicallyOpen,'Raw Chrome logical closed retains same-task/microtask document access')
  local before=0;for _,entry in raw[1].trace do if entry.phase=='beforeunload'then before+=1 end end
  check(before==2 and raw[1].trace[1].childClosed==false,'Raw Chrome repeated-close and beforeunload ordering deltas stay unmodified')
  check(phase(raw[2].trace,'self sync').childClosed and phase(raw[2].trace,'self microtask').ownDocumentAvailable and not raw[2].physicallyOpen,'Raw self-close stack/microtask values are preserved')
  check(raw[3].dialogHandled and not raw[3].closedAfterAnswer and raw[3].physicallyOpenAfterAnswer and raw[3].closedAfterRetry and not raw[3].physicallyOpenAfterRetry,'Native Stay/reset/retry reference grounds the explicit host profile')
  check(not phase(raw[3].trace,'guard sync').closed and raw[4].dialogHandled and raw[4].closedAfterAnswer and not raw[4].physicallyOpenAfterAnswer,'Chrome guard-before-return ordering remains separate from queued frozen target')
  check(raw[5].targetClose.success and raw[5].closed and not raw[5].physicallyOpen,'Raw forced CDP disposal is retained as harness behavior')

  print('BrowserClosingState: '..controls..' additive mounted controls; '..checks..' assertions')
 end
	-- Programmatic and native caption close share the same leave guard.
	activate(replacement);run(replacement,'protectPage=true;');table.clear(trace)
	local closed
	begin(function()closed=main.Window:RequestClose()end)
	assert(browser.Overlays.Current and main.Window.Alive and replacement.Alive)
	respond(false);assert(closed==false and main.Window.Alive and replacement.Alive)
	begin(function()click(main.Window.CloseButton)end)
	assert(browser.Overlays.Current and main.Window.Alive and replacement.Alive)
	respond(true)
	assert(not main.Window.Alive and not replacement.Alive and not browser.Alive and #manager:GetWindows()==0)
	-- A suspended, never-committed parser script is destroyed before dismissal
	-- can resume it. A second host completion cannot execute retired author code.
	table.clear(trace)
	local held=host:Open('http://localhost:8000/held/index.html');f:Drain()
	local heldTab=held.Browser:GetActiveTab();local pending=assert(held.Binding.Owners[heldTab].Pending)
	local heldRealm=assert(pending.Runtime);assert(held.Browser.Overlays.Current and heldRealm.Alive)
	assert(held.Window:RequestClose());f:Drain()
	assert(not heldRealm.Alive and not held.Window.Alive and #trace==0,'Closing a staged document must abandon the author stack without unload or a late continuation')
	-- Forced native termination has no leave-approval phase. Committed root,
	-- retained child and not-yet-returned child mounts must all become dead
	-- before dismissing a prompt can resume author catch/finally blocks.
	for _,kind in{'root','child','pending child'}do
		local entry=host:Open('http://localhost:8000/'..(if kind=='root'then 'b'else 'frame')..'/index.html');f:Drain()
		local root=assert(entry.Binding:GetPage(entry.Browser:GetActiveTab()))
		local author=if kind=='root'then root else assert(root.IFrames[1].ChildPage,tostring(root.IFrames[1].Error)..' / '..table.concat(diagnostics,'|'))
		assert(not root:HasExecutingScripts(),'An idle committed page is not executing')
		if kind=='pending child'then
			run(root,"document.getElementById('child').src='/held/index.html';")
			author=assert(realms[#realms].Page);assert(realms[#realms].Name=='Held'and root.IFrames[1].ChildPage==nil)
		else
			begin(function()author.JavaScriptRuntime:Run("try{prompt('Committed waiting');console.log('late author');}catch(e){console.log('late catch');}finally{console.log('late finally');}")end)
		end
		local realm=author.JavaScriptRuntime
		assert(entry.Browser.Overlays.Current and realm.Alive and root:HasExecutingScripts(),'A suspended '..kind..' author must be visible to the recursive busy check')
		if kind~='root'then assert(not root.JavaScriptRuntime:IsExecuting(),'Only the descendant is suspended')end
		table.clear(trace)
		begin(function()entry.Window:Close()end)
		assert(not entry.Window.Alive and not root.Alive and not author.Alive and not realm.Alive and not entry.Browser.Alive,'Forced '..kind..' teardown must destroy the entire owned realm tree')
		assert(#trace==0,'Forced '..kind..' termination must skip unload and abandon suspended author code: '..table.concat(trace,'|'))
	end
	-- Source supersession retires a suspended mount without retiring its
	-- committed parent or publishing a late returned child into the new slot.
	local replaced=host:Open('http://localhost:8000/frame/index.html');f:Drain()
	local parent=assert(replaced.Binding:GetPage(replaced.Browser:GetActiveTab()))
	run(parent,"document.getElementById('child').src='/held/index.html';")
	local pendingChild=assert(realms[#realms].Page);local pendingRealm=pendingChild.JavaScriptRuntime
	assert(parent:HasExecutingScripts()and replaced.Browser.Overlays.Current)
	table.clear(trace)
	run(parent,"document.getElementById('child').src='/b/index.html';")
	local nextChild=assert(parent.IFrames[1].ChildPage)
	assert(parent.Alive and nextChild~=pendingChild and nextChild.Alive and not pendingChild.Alive and not pendingRealm.Alive and not parent:HasExecutingScripts()and not replaced.Browser.Overlays.Current,'Replacing a pending child must cancel its realm and retain only the newest child')
	assert(#trace==0,'A superseded child cannot execute author continuation/catch/finally: '..table.concat(trace,'|'))
	run(parent,"document.getElementById('child').src='/held/index.html';")
	local hiddenChild=assert(realms[#realms].Page)
	assert(replaced.Browser.Overlays.Current and parent.IFrames[1].ChildPage==nil)
	parent:SetDocumentVisible(false)
	assert(hiddenChild.DocumentVisible==false,'Parent visibility reaches the owned child before its suspended mount returns')
	f:Drain()
	assert(hiddenChild.Alive and parent.IFrames[1].ChildPage==hiddenChild and hiddenChild.JavaScriptRuntime.Window.Get('document').Get('hidden')and not replaced.Browser.Overlays.Current,'Hiding a pending child cancels its live dialog and retains a hidden document')
	parent:SetDocumentVisible(true);f:Drain()
	begin(function()replaced.Window:Close()end)
	host:Destroy();manager:Destroy();f:Drain()
	assert(f:GlobalConnections()==0 and #diagnostics==0,table.concat(diagnostics,' | '))
	print('BrowserLifecycleDialogs: actual parser prompt, synchronous result, guarded navigation/close, visibility and forced root/retained/pending child disposal passed')
end
