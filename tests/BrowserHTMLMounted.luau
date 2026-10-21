--!strict
-- Real renderer, layout, input controller and JS realm behind the independent shell.
return function(loadBrowser,loadBinding,fixture,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages)
	local f=fixture();local host=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	f.Input.MouseIcon='host cursor'
	local browser=loadBrowser(f).mount(host,{AutoOpen=false,PersistenceEnabled=false,ExternalBaseURL='http://localhost:8000/a/index.html',ResolveExternal=function(url,base)return {URL=URL.resolve(if base and base:match('^https?://')then base else 'http://localhost:8000/a/index.html',url).URL,Kind='external'}end,Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task}})
	local function click(control)local object=control.Root or control;local p,s=object.AbsolutePosition,object.AbsoluteSize;local e=f:Begin(object,nil,p.X+s.X/2,p.Y+s.Y/2);f.Input.InputEnded:Fire(e)end
	local factory={create=f.Create,modifier=f.Create};local renderer=loadRenderTree(factory)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local block=loadBlockLayout(overrides)
	local mounted,ready,controllerCalls=0,0,0
	local retainedDuringMount,retainedMountObservations=nil,0
	local trees={}
	local guiService={ReducedMotionEnabled=false,GetPropertyChangedSignal=function()return f.Signal()end}
	local hostGame={GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then guiService else nil end}
	local pageModule=loadHTMLPage({
		['Rendering/GuiFactory']=factory,
		['Rendering/RenderTree']={build=function(doc,root,diagnostic)local tree=renderer.build(doc,root,diagnostic,function(font)return font end);trees[doc]=tree;return tree end},
		['Layout/BlockLayout']=block,
		['Input/Controller']={start=function(page,tree,schedule,diagnostic,services)
			controllerCalls+=1;assert(services and services.Input~=f.Input and services.PlayerGui==f.PlayerGui,'Actual HTMLPage did not forward scoped InputServices')
			return Controller.start(page,tree,schedule,diagnostic,services)
		end},
		['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,hostGame,f)
	local engine={URL=URL,Websites={url=function()return 'http://localhost:8000/a/index.html'end}}
	local sources={A=[=[<!doctype html><html><head><title>A</title><link rel="icon" href="site-logo.png"><style>body{margin:0}div{height:40px}button{height:30px}</style></head><body>
		<button id="increment">Plus</button><div id="value">0</div><script>
		var count=0; document.getElementById('increment').addEventListener('click',function(){count++;document.getElementById('value').textContent=String(count);});
		window.addEventListener('keydown',function(){count++;document.getElementById('value').textContent=String(count);});
		requestAnimationFrame(function(){document.title='A frame';});
		</script></body></html>]=],B='<!doctype html><html><head><title>B</title></head><body><div id="other">Other tab</div><script>requestAnimationFrame(function(){document.title="B frame";});</script></body></html>'}
	function engine.Websites.resolveURL(base,href)local result=URL.resolve(base,href);if result.Path=='/a/index.html'then result.Name='A';result.Kind='internal'elseif result.Path=='/b/index.html'then result.Name='B';result.Kind='internal'end;return result end
	function engine.Websites.get(name)return {HTML=assert(sources[name]),Options={Images={['site-logo.png']='rbxassetid://123456'},RenderWorkBudgetMS=0,InputServices={Task=f.Task},JavaScriptServices={Task=f.Task,Clock=function()return f:Clock()end}}}end
	function engine.mountHTML(target,html,options)return pageModule.mount(target,html,options)end
	local diagnostics={}
	local webLockStore=require('JavaScript/WebLocks').createStore()
	local binding=loadBinding(f).new(browser,engine,{Services={Create=f.Create,Input=f.Input,RunService=f.Run,PlayerGui=f.PlayerGui,Task=f.Task},Diagnostic=function(message)table.insert(diagnostics,tostring(message))end,
		WebLockStore=webLockStore,
		PageMounted=function(_,candidate)
			mounted+=1
			if retainedDuringMount then
				assert(retainedDuringMount.Alive and retainedDuringMount.Root.Visible and retainedDuringMount.Root.Parent.Visible and not candidate.Root.Parent.Visible,'Actual HTML mount must keep the previous presented page painted while its new target is hidden')
				retainedMountObservations+=1
			end
		end,PageReady=function()ready+=1 end})
	local tab=browser:Open('http://localhost:8000/a/index.html');f:Drain();local page=assert(binding:GetPage(tab),'Actual initial page failed: '..tostring(tab.Error))
	assert(page.Alive and page.Root.Visible and page.Root:GetAttribute('Status')=='ready'and page.Root:GetAttribute('Presented')and mounted==1 and ready==1)
	assert(not browser.View.Bookmarks.Root.Visible and browser.View.Content.Position.Y.Offset==browser.View.ChromeHeight)
	assert(tab.Icon=='rbxassetid://123456'and browser.View.TabStrip==nil,'HTML favicon metadata resolves without creating a tab surface')
	-- Link metadata changes update the current tab without a new HTML mount.
	local ok,message=page.JavaScriptRuntime:Run("document.querySelector('link').setAttribute('href','rbxassetid://456789');");assert(ok,tostring(message));f:Drain()
	assert(tab.Icon=='rbxassetid://456789'and mounted==1,'Dynamic favicon metadata was not published')
	local value=assert(Node.findById(page.Document,'value'));local firstGui=trees[page.Document].NodeBoxes[value].Gui
	-- The engine's Dialog backdrop uses this native marker outside HitNodes.
	local backdrop=f.Create('Frame',page.Root.Parent,{Size=f.UDim2.fromScale(1,1)})
	backdrop:SetAttribute('HTMLCursorSurface',true)
	f.Input.Mouse=f.Vector2.new(50,200);f:Hits(backdrop)
	f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,50,200))
	local cursor=f.Input.MouseIcon
	local otherHost=f.Create('Frame',f.Screen,{Name='SecondBrowserHost',Size=f.UDim2.fromScale(1,1)})
	local otherBrowser=loadBrowser(f).mount(otherHost,{AutoOpen=false,PersistenceEnabled=false,Visible=false,Focused=false,ExternalBaseURL='http://localhost:8000/a/index.html',ResolveExternal=browser.Options.ResolveExternal,Services=browser.Services})
	local otherBinding=loadBinding(f).new(otherBrowser,engine,{Services={Create=f.Create,Input=f.Input,RunService=f.Run,PlayerGui=f.PlayerGui,Task=f.Task},WebLockStore=webLockStore,Diagnostic=function(message)table.insert(diagnostics,tostring(message))end,PageMounted=function()mounted+=1 end,PageReady=function()ready+=1 end})
	otherBinding:SetVisible(false);otherBinding:SetInputActive(false)
	local other=otherBrowser:Open('http://localhost:8000/b/index.html');f:Drain();local otherPage=assert(otherBinding:GetPage(other))
	local backgroundPage=otherPage
	backgroundPage.Root:GetPropertyChangedSignal('AbsolutePosition'):Fire()
	assert(f.Input.MouseIcon==cursor and browser:GetActiveTab()==tab,'Background mount/geometry changed the foreground cursor')
	assert(backgroundPage.Alive and not backgroundPage.Root.Visible and browser:GetActiveTab()==tab and #browser:GetTabs()==1)
	backdrop:Destroy();f:Hits();f.Input.Mouse=f.Vector2.new(2000,2000);f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,2000,2000));f:Drain()
	local button=assert(Node.findById(page.Document,'increment'))
	page.Events:Emit(button,'click',{},{Bubbles=true,Cancelable=true});f:Drain();assert(Node.textContent(value)=='1')
	f.Run.RenderStepped:Fire();f:Drain();assert(tab.Title=='A frame'and page.DocumentURL==tab.URL)
	local key=f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.X);f.Input.InputBegan:Fire(key,false);f:Drain();assert(Node.textContent(value)=='2')
	click(browser.View.URL);f.Input.InputBegan:Fire(key,false);f:Drain();assert(Node.textContent(value)=='2','Chrome address typing entered the document')
	browser.View.URL:ReleaseFocus(false)
	-- Native prompt editing stays scoped away from document key handlers.
	local dismiss=browser.Overlays:ScriptDialog({Kind='prompt',Message='Scoped native input'},function()end)
	local prompt=assert(browser.Overlays.Current).Panel:FindFirstChild('DialogValue');assert(prompt and prompt:IsFocused())
	f.Input.InputBegan:Fire(key,false);f:Drain();assert(Node.textContent(value)=='2','Native prompt typing entered the HTML realm')
	dismiss();browser.Input:ReleaseFocus();f:Drain()
	assert(binding:GetPage(tab)==page and page.Alive and mounted==2 and not browser.Overlays.Current,'Dismissing chrome must retain the existing document')
	local escape=f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.Escape);f.Input.InputBegan:Fire(escape,false);f:Drain()
	assert(not browser:ConsumesInput(escape)and Node.textContent(value)=='3','Chrome swallowed content Escape: consumed='..tostring(browser:ConsumesInput(escape))..'; value='..Node.textContent(value)..'; focused='..tostring(f.Input:GetFocusedTextBox()))
	local lockOK,lockError=page.JavaScriptRuntime:Run("var lockLog=[];navigator.locks.request('shared-tab-job',()=>{lockLog.push('held');return new Promise(resolve=>globalThis.releaseTabLock=resolve);});")
	assert(lockOK,tostring(lockError));f:Drain()
	lockOK,lockError=otherPage.JavaScriptRuntime:Run("var lockSeen=false;navigator.locks.request('shared-tab-job',()=>{lockSeen=true;});")
	assert(lockOK,tostring(lockError));f:Drain();assert(otherPage.JavaScriptRuntime.Window.Get('lockSeen')==false,'Same-origin windows must wait on the explicitly shared host lock store')
	assert(page.JavaScriptRuntime:Run('releaseTabLock();'));f:Drain()
	assert(otherPage.JavaScriptRuntime.Window.Get('lockSeen')==true,'Lock release must wake the retained waiting window realm')
	browser:SetFocused(false);binding:SetInputActive(false);binding:SetVisible(false)
	otherBrowser:SetVisible(true);otherBinding:SetVisible(true);otherBrowser:SetFocused(true);otherBinding:SetInputActive(true)
	assert(otherPage.Root.Visible and not page.Root.Visible and page.Alive)
	f.Input.InputBegan:Fire(key,false);f:Drain();assert(Node.textContent(value)=='3','Hidden real HTML controller still received keys')
	-- A pending rAF stays suspended while its real page is hidden.
	otherBrowser:SetVisible(false);otherBinding:SetVisible(false);f.Run.RenderStepped:Fire();f:Drain();assert(other.Title=='B')
	otherBrowser:SetVisible(true);otherBinding:SetVisible(true);f.Run.RenderStepped:Fire();f:Drain();assert(other.Title=='B frame')
	otherBrowser:SetFocused(false);otherBinding:SetInputActive(false);otherBrowser:SetVisible(false);otherBinding:SetVisible(false)
	browser:SetFocused(true);binding:SetInputActive(true);binding:SetVisible(true);assert(page.Root.Visible and trees[page.Document].NodeBoxes[value].Gui==firstGui)
	browser:SetResizing(true)
	local before=page.LastLayoutStats
	f:Drain()
	assert(page.LastLayoutStats==before and page.Root.Parent:GetAttribute('HTMLViewportResizing'),'Browser grip bypassed actual HTML layout hold')
	browser:SetResizing(false);f:Drain();assert(not page.Root.Parent:GetAttribute('HTMLViewportResizing')and page.Root:GetAttribute('Status')=='ready')
	browser:Navigate(tab,'#value');f:Drain();assert(binding:GetPage(tab)==page and page.DocumentURL==tab.URL and page.JavaScriptRuntime.Navigation:GetURL()==tab.URL)
	local history=#tab.History;retainedDuringMount=page
	page:AddCleanup(function()
		local shown=binding:GetPage(tab)
		assert(shown and shown~=page and shown.Root.Visible and shown.Root.Parent.Visible,'Actual old-page cleanup must follow presentation of its completed replacement')
	end)
	browser:Reload(tab);f:Drain();retainedDuringMount=nil
	local replacement=assert(binding:GetPage(tab));assert(replacement~=page and not page.Alive and #tab.History==history and retainedMountObservations==1)
	assert(controllerCalls==3 and mounted==3 and ready==3 and #diagnostics==0)
	click(browser.View.Star);assert(browser.Shared:FindBookmark(tab.URL),'Bookmark action did not save the HTML URL')
	local htmlURL=tab.URL;local native=browser:Open();f:Drain()
	assert(native==tab and #browser:GetTabs()==1 and browser:IsStartPage(native.URL)and not binding:GetPage(native)and mounted==3 and browser.Native and browser.Native.Tab==native and browser.View.Bookmarks.Root.Visible)
	-- Native Home owns quick links; navigating to an actual history URL mounts HTML.
	browser:Navigate(native,htmlURL);f:Drain();local recentPage=assert(binding:GetPage(native))
	assert(recentPage.Alive and mounted==4 and controllerCalls==4 and not browser.Native and not browser.View.Bookmarks.Root.Visible)
	browser:Navigate(native,'wayline://home');f:Drain();assert(not recentPage.Alive and not binding:GetPage(native)and mounted==4)
	browser:Back(native);f:Drain();local afterNative=assert(binding:GetPage(native))
	assert(afterNative.Alive and controllerCalls==5 and mounted==5 and #diagnostics==0)
	-- Repeated host Open replaces the current document exactly once.
	ok,message=afterNative.JavaScriptRuntime:Run("document.title='Restored page';");assert(ok,tostring(message));f:Drain()
	local count=mounted;local opened=browser:Open('http://localhost:8000/b/index.html');f:Drain()
	assert(opened==native and #browser:GetTabs()==1 and not afterNative.Alive and browser.OpenTab==nil,'Opening another address replaces the single context')
	local reopened=assert(binding:GetPage(browser:GetActiveTab()))
	assert(reopened.Alive and mounted==count+1 and not browser.Overlays.Current)
	f:Hits();f.Input.Mouse=f.Vector2.new(2000,2000);f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,2000,2000));f:Drain()
	otherBrowser:Destroy();otherHost:Destroy();browser:Destroy();f:Drain();assert(not replacement.Alive and not otherPage.Alive and f:GlobalConnections()==0)
	assert(not afterNative.Alive)
	assert(not reopened.Alive)
	assert(f.Input.MouseIcon=='host cursor'and f.Input.MouseIconEnabled,'Window visibility/disposal leaked a cursor lease: '..tostring(f.Input.MouseIcon)..'/'..tostring(f.Input.MouseIconEnabled))
	print('BrowserHTMLMounted: real HTML/CSS/JS windows, scoped controller/frames, retained DOM, resize and cleanup passed')
end
