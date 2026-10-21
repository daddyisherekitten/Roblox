--!strict
return function(loadBrowser,loadBinding,fixture,URL)
	local f=fixture();local host=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local browser=loadBrowser(f).mount(host,{AutoOpen=false,PersistenceEnabled=false,ExternalBaseURL='http://localhost:8000/a/index.html',ResolveExternal=function(url,base)return {URL=URL.resolve(if base and base:match('^https?://')then base else 'http://localhost:8000/a/index.html',url).URL,Kind='external'}end,Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task}})
	local function click(control)local object=control.Root or control;local p,s=object.AbsolutePosition,object.AbsoluteSize;local e=f:Begin(object,nil,p.X+s.X/2,p.Y+s.Y/2);f.Input.InputEnded:Fire(e)end
	local pages,waits,diagnostics={},{},{}
	local sources={A='<title>A</title>',B='<title>B</title>',Slow='<title>Slow</title>',Error='<title>Error</title>',Throw='<title>Throw</title>',NotFound='<title>404</title>'}
	local urls={A='/a/index.html',B='/b/index.html',Slow='/slow/index.html',Error='/error/index.html',Throw='/throw/index.html'}
	local engine={URL=URL,Websites={url=function()return 'http://localhost:8000/a/index.html'end}}
	function engine.Websites.resolveURL(base,href)
		local result=URL.resolve(base,href)
		for name,path in urls do if URL.routeKey(result.URL)=='http://localhost:8000'..path then result.Kind='internal';result.Name=name;return result end end
		if result.Origin==URL.origin(base)then result.Kind='missing'end;return result
	end
	function engine.Websites.get(name)return {HTML=assert(sources[name]),Options={RenderWorkBudgetMS=0,InputServices={Task=f.Task},JavaScriptServices={Clock=function()return f:Clock()end}},CSS='body{margin:0}',Stylesheets={['x.css']='p{color:blue}'}}end
	function engine.mountHTML(target,html,options)
		local root=f.Create('ScrollingFrame',target,{Name='Document',CanvasPosition=f.Vector2.new(0,0)})
		local page={Alive=true,Root=root,Title=html:match('<title>(.-)</title>')or'Blank',Document={Diagnostics={}},Options=options,DestroyCalls=0,InputCount=0,FrameCount=0,Connections={}}
		table.insert(pages,page)
		root:SetAttribute('Title',page.Title);root:SetAttribute('Status','loading');root:SetAttribute('Presented',false)
		function page:SetVisible(value)self.Visible=value;self.Root.Visible=value end
		function page:ScrollToFragment(hash)self.Fragment=hash end
		function page:Destroy()if self.BeforeDestroy then self.BeforeDestroy()end;self.Alive=false;self.DestroyCalls+=1;assert(self.DestroyCalls==1,'Page destroyed twice');for _,c in self.Connections do c:Disconnect()end;root:Destroy()end
		page.Connections={options.InputServices.Input.InputBegan:Connect(function()page.InputCount+=1 end),options.JavaScriptServices.RunService.RenderStepped:Connect(function()page.FrameCount+=1 end)}
		if page.Title=='Slow'then table.insert(waits,coroutine.running());coroutine.yield()end
		if page.Title=='Throw'then for _,c in page.Connections do c:Disconnect()end;root:Destroy();error('mount failed')end
		return page
	end
	local mounted,ready=0,0
	local callbackErrors=false
	local storage={}
	local binding=loadBinding(f).new(browser,engine,{StorageHost=storage,Services={Create=f.Create,Input=f.Input,RunService=f.Run,PlayerGui=f.PlayerGui,Task=f.Task},Diagnostic=function(message)table.insert(diagnostics,tostring(message))end,
		PageMounted=function()mounted+=1;if callbackErrors then error('Mounted observer failed')end end,
		PageReady=function()ready+=1;if callbackErrors then error('Ready observer failed')end end})
	local function finish(page)
		page.Root:SetAttribute('Status','ready');assert(not page.Visible,'Status alone revealed an unfinished document')
		page.Root:SetAttribute('Presented',true)
	end
	local tab=browser:Open('http://localhost:8000/a/index.html');f:Drain();local a=assert(pages[#pages])
	assert(tab.Loading and a.Root.Parent.Visible==false and mounted==1 and ready==0)
	assert(browser.View.Loading.Visible and not a.Root.Parent.Visible,'Pending mount was presented before ready')
	assert(a.Options.StorageHost==storage and a.Options.CSS and a.Options.Stylesheets and a.Options.InputServices.Task==f.Task)
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.X),false);f.Run.RenderStepped:Fire();assert(a.InputCount==0 and a.FrameCount==1,'Pending documents must finish scripts without receiving input')
	finish(a);assert(binding:GetPage(tab)==a and a.Visible and not tab.Loading and ready==1)
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.X),false);assert(a.InputCount==1)
	for surface in browser.Surfaces do assert(surface:GetAttribute('HTMLInputBlocker')==true)end
	local initial=#pages;browser:Navigate(tab,'#part');f:Drain();assert(#pages==initial and a.Fragment=='part'and tab.URL:match('#part$'))
	a.Root.CanvasPosition=f.Vector2.new(3,44)
	browser:Navigate(tab,'../b/index.html');f:Drain();local b=pages[#pages]
	assert(a.Visible and a.Root.Parent.Visible and a.DestroyCalls==0 and not b.Root.Parent.Visible,'Loading a replacement must retain the completed old page and hide the unfinished candidate')
	local oldInput=a.InputCount
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.X),false)
	assert(a.InputCount==oldInput and b.InputCount==0,'Neither the retained old page nor its hidden replacement may receive input during navigation')
	a.BeforeDestroy=function()assert(b.Visible and b.Root.Parent.Visible and binding:GetPage(tab)==b,'The ready replacement must cover the viewport before old-page unload/disposal')end
	finish(b);assert(b.Visible and a.DestroyCalls==1 and tab.HistoryIndex==3)
	browser:Back(tab);f:Drain();local back=pages[#pages];finish(back);assert(back.Title=='A'and back.Root.CanvasPosition.Y==44 and back.Fragment=='part')
	local count=#tab.History;browser:Reload(tab);f:Drain();local reloaded=pages[#pages];finish(reloaded);assert(#tab.History==count and back.DestroyCalls==1 and reloaded.Root.CanvasPosition.Y==44)
	local queuedKeys,queuedFrames=f.Input.InputBegan:Snapshot(),f.Run.RenderStepped:Snapshot()
	binding:SetVisible(false);assert(not reloaded.Visible)
	local inputCount,frameCount=reloaded.InputCount,reloaded.FrameCount
	for _,callback in queuedKeys do callback(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.X),false)end
	for _,callback in queuedFrames do callback()end
	assert(reloaded.InputCount==inputCount and reloaded.FrameCount==frameCount,'Previously queued native callbacks entered a hidden document')
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.X),false);f.Run.RenderStepped:Fire()
	assert(reloaded.InputCount==inputCount and reloaded.FrameCount==frameCount)
	binding:SetVisible(true);f.Run.RenderStepped:Fire();assert(reloaded.Visible and reloaded.FrameCount==frameCount+1)
	-- Native address editing is scoped away from the HTML controller.
	click(browser.View.URL);inputCount=reloaded.InputCount
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.X),false)
	assert(reloaded.InputCount==inputCount and browser.View.URL:IsFocused());browser.View.URL:ReleaseFocus(false)
	-- Held resize state is applied to loaded AND newly staging document targets.
	browser:SetResizing(true)
	assert(reloaded.Root.Parent:GetAttribute('HTMLViewportResizing')==true)
	browser:Navigate(tab,'http://localhost:8000/slow/index.html');f:Drain();local slow=pages[#pages]
	assert(slow.Root.Parent:GetAttribute('HTMLViewportResizing')==true)
	browser:SetResizing(false);assert(slow.Root.Parent:GetAttribute('HTMLViewportResizing')==false)
	callbackErrors=true
	browser:Navigate(tab,'http://localhost:8000/b/index.html');f:Drain();local winner=pages[#pages];finish(winner)
	callbackErrors=false;assert(#diagnostics==2 and winner.Visible and not tab.Loading,'Host observer failures interrupted publication')
	f:Resume(table.remove(waits,1));assert(slow.DestroyCalls==1 and binding:GetPage(tab)==winner and winner.Visible)
	-- Cancellation and failed replacement keep the already presented document.
	browser:Navigate(tab,'http://localhost:8000/slow/index.html');f:Drain();local cancelled=pages[#pages];browser:CancelNavigation(tab)
	assert(winner.Visible);f:Resume(table.remove(waits,1));assert(cancelled.DestroyCalls==1 and binding:GetPage(tab)==winner)
	local retainedURL,retainedHistory=tab.URL,#tab.History
	browser:Navigate(tab,'http://localhost:8000/error/index.html');f:Drain();local failed=pages[#pages];failed.Root:SetAttribute('Error','Bad layout');failed.Root:SetAttribute('Status','error')
	assert(failed.DestroyCalls==1 and winner.DestroyCalls==0 and winner.Visible and binding:GetPage(tab)==winner and tab.URL==retainedURL and #tab.History==retainedHistory and not browser.Native and not tab.Loading)
	browser:Navigate(tab,'http://localhost:8000/throw/index.html');f:Drain();assert(tab.URL==retainedURL and binding:GetPage(tab)==winner and winner.Visible and not tab.Loading)
	browser:Navigate(tab,'https://example.com/');f:Drain();assert(tab.URL==retainedURL and binding:GetPage(tab)==winner and winner.Visible and not tab.Loading)
	browser:Navigate(tab,'http://localhost:8000/missing/index.html');f:Drain();local missing=pages[#pages];finish(missing);assert(missing.Root:GetAttribute('HTTPStatus')==404)
	missing.Root:SetAttribute('Title','Changed title');assert(tab.Title=='Changed title')
	missing.Options.URLChanged('http://localhost:8000/missing/index.html#new','pushState');assert(tab.URL:match('#new$')and tab.History[#tab.History].URL==tab.URL)
	missing.Options.Navigate('../b/index.html',nil,{Target='_blank'});f:Drain();assert(#browser:GetTabs()==1,'An embedded browser without a window provider navigates its one document')
	local newTab=browser:GetActiveTab();finish(pages[#pages]);assert(binding:GetPage(newTab).Title=='B')
	-- An edited address uses the catalog normalizer, including missing routes.
	click(browser.View.URL);browser.View.URL.Text='localhost:8000/a/index.html';browser.View.URL:ReleaseFocus(true);f:Drain();finish(pages[#pages]);assert(newTab.URL=='http://localhost:8000/a/index.html')
	browser:Navigate(newTab,'http://localhost:8000/slow/index.html');f:Drain();local closing=pages[#pages];browser:CancelNavigation(newTab);f:Resume(table.remove(waits,1));assert(closing.DestroyCalls==1 and binding:GetPage(newTab),'Cancelling an unfinished document retains the committed page')
	a.Options.Navigate('/a/index.html');f:Drain();assert(not tab.Loading,'Destroyed page handler loaded a document')
	-- Native Home owns no HTML mount; navigating back restores the saved scroll.
	browser:SelectTab(tab);local prior=assert(binding:GetPage(tab));prior.Root.CanvasPosition=f.Vector2.new(0,55)
	local nativeCount=#pages;browser:Navigate(tab,'wayline://home');f:Drain()
	assert(browser.Native and browser.Native.Tab==tab and browser.Native.Page and not binding:GetPage(tab)and prior.DestroyCalls==1 and #pages==nativeCount)
	local retainedNative=browser.Native
	browser:Back(tab);f:Drain();local restored=pages[#pages]
	assert(browser.Native==retainedNative and not restored.Root.Parent.Visible,'Native Home must remain painted while the restored HTML document loads')
	finish(restored)
	assert(restored.Root.CanvasPosition.Y==55 and not browser.Native)
	local native=browser:Open();f:Drain();assert(native==tab and #browser:GetTabs()==1 and browser:IsStartPage(native.URL)and not binding:GetPage(native)and #pages==nativeCount+1)
	-- A slow document replaced by the native page cannot appear after it finishes.
	browser:Navigate(native,'http://localhost:8000/slow/index.html');f:Drain();local abandoned=pages[#pages]
	browser:Navigate(native,'wayline://home');f:Drain();f:Resume(table.remove(waits,1))
	assert(abandoned.DestroyCalls==1 and not binding:GetPage(native)and browser.Native and browser.Native.Tab==native)
	-- Typed text uses browser search; content/host relative navigation above uses the document base.
	local beforeSearch=#pages
	click(browser.View.URL);browser.View.URL.Text='../a/index.html';browser.View.URL:ReleaseFocus(true);f:Drain()
	assert(native.URL=='wayline://search?q=..%2Fa%2Findex.html'and #pages==beforeSearch and not binding:GetPage(native)and browser.Native)
	-- With no completed document, failure still has a usable native error page.
	local emptyHost=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local emptyBrowser=loadBrowser(f).mount(emptyHost,{AutoOpen=false,PersistenceEnabled=false,ResolveExternal=browser.Options.ResolveExternal,Services=browser.Services})
	local emptyBinding=loadBinding(f).new(emptyBrowser,engine,{Services={Create=f.Create,Input=f.Input,RunService=f.Run,PlayerGui=f.PlayerGui,Task=f.Task}})
	local initialFailure=emptyBrowser:Open('http://localhost:8000/throw/index.html');f:Drain()
	assert(initialFailure.URL=='wayline://error'and emptyBrowser.Native and not emptyBinding:GetPage(initialFailure),'An initial load failure still needs the standalone browser error fallback')
	emptyBrowser:Destroy();f:Drain()
	browser.Window:Destroy();f:Drain();assert(not binding.Alive and f:GlobalConnections()==0)
	for _,page in pages do if page.Title~='Throw'then assert(page.DestroyCalls==1,'Unreleased document '..page.Title)end end
	print('BrowserHTMLBinding: staging, history, stale loads, scoped input/frames, resize, errors and disposal passed')
end
