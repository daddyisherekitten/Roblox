--!strict
-- The shell fills a host Frame; window gestures are covered by WindowManager.
return function(loadBrowser,fixture)
	local f=fixture();local host=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local browser=loadBrowser(f).mount(host,{AutoOpen=false,PersistenceEnabled=false,ResolveExternal=function(url)return {URL=url,Kind='external'}end,
		Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task,Clock=function()return f:Clock()end}})
	-- Count native allocations, independently of animation timings/FPS. Settled
	-- paint requests should allocate nothing; an in-flight transition still
	-- has to be cancelled even when its starting value is requested again.
	do
		local tweenService=f.Game:GetService('TweenService');local createTween=tweenService.Create;local created=0
		tweenService.Create=function(service,...)created+=1;return createTween(service,...)end
		local paint=f.Create('Frame',host,{BackgroundTransparency=.5})
		for _=1,24 do assert(browser.Theme:Animate(paint,{BackgroundTransparency=.5})==nil)end
		assert(created==0 and browser.Theme.Tweens[paint]==nil,'Settled paints must not allocate native tweens/listeners')
		f.DeferTweens=true
		local pending=browser.Theme:Animate(paint,{BackgroundTransparency=.9});assert(pending and created==1)
		local rewind=browser.Theme:Animate(paint,{BackgroundTransparency=.5});assert(rewind and pending.Cancelled,'A pending different target must not survive equal-current-value paint')
		f:Drain();assert(paint.BackgroundTransparency==.5 and browser.Theme.Tweens[paint]==nil)
		pending=browser.Theme:Animate(paint,{BackgroundTransparency=.9});f:StepTweens(.5)
		assert(paint.BackgroundTransparency>.5 and paint.BackgroundTransparency<.9)
		local restore=browser.Theme:Animate(paint,{BackgroundTransparency=.5});assert(restore and pending.Cancelled)
		f:Drain();assert(paint.BackgroundTransparency==.5 and browser.Theme.Tweens[paint]==nil,'Reversing a sampled transition must reach its new target')
		local before=created
		for _=1,24 do browser.Theme:Animate(paint,{BackgroundTransparency=.5})end
		assert(created==before,'Completed animation must return to allocation-free settled paint')
		pending=browser.Theme:Animate(paint,{BackgroundTransparency=.9});paint:Destroy()
		assert(pending.Cancelled and browser.Theme.Tweens[paint]==nil,'Destroyed paint releases its pending transition')
		local invalid=setmetatable({},{__index=function()error('Unsupported property')end,__newindex=function()error('Unsupported property')end})
		tweenService.Create=function(service,object,...)if object==invalid then error('Unsupported tween target')end;return createTween(service,object,...)end
		local accepted,result=pcall(browser.Theme.Animate,browser.Theme,invalid,{Unsupported=.5})
		assert(accepted and result==nil,'Unsupported native goals retain the protected Create/write fallback')
		f.DeferTweens=false;tweenService.Create=createTween;f:Drain()
		print('BrowserShell operations: 24 + 24 settled paints = 0 native tweens; pending reversal and destruction preserved')
	end
	local function root(object)return object.Root or object end
	local function point(object)local node=root(object);local p,s=node.AbsolutePosition,node.AbsoluteSize;return p.X+s.X/2,p.Y+s.Y/2 end
	local function begin(object,kind)local x,y=point(object);return f:Begin(root(object),kind,x,y)end
	local function click(object)local event=begin(object);f.Input.InputEnded:Fire(event);return event end
	local function move(object)local x,y=point(object);f:Hits(root(object));f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,x,y));return x,y end
	local function releaseAt(event,object)local x,y=point(object);event.Position=f.Vector2.new(x,y);f:Hits(root(object));f.Input.InputEnded:Fire(event)end
	local function sameColor(a,b)return a.R==b.R and a.G==b.G and a.B==b.B end
	local function inactive()
		for _,object in browser.Window:GetDescendants()do if object:IsA('GuiObject')then assert(object.Active==false and object.Selectable==false,'Native input leaked: '..object.Name)end end
	end
	local tab=browser:Open();f:Drain();assert(tab.URL=='wayline://home'and #tab.History==1 and not tab.Loading)
	inactive();begin(browser.View.Back);assert(not browser.Input.Pressed,'Disabled back button captured a press')
	local function checkPressed(button)
		move(button);local hovered=button.Root.BackgroundColor3
		local held=begin(button);local down=button.Root.BackgroundColor3
		assert(button.Pressed and not sameColor(hovered,down),'Missing pressed color: '..button.Root.Name)
		browser:_Changed();assert(sameColor(button.Root.BackgroundColor3,down),'Refresh erased a held press')
		move(browser.View.Content);assert(not button.Pressed and button.Root.BackgroundTransparency==1,'Press stayed painted outside control')
		move(button);assert(button.Pressed and sameColor(button.Root.BackgroundColor3,down),'Reentry did not restore press')
		releaseAt(held,browser.View.Content);assert(not button.Pressed and not browser.Input.Pressed)
		move(button);begin(button);f.Input.WindowFocusReleased:Fire();assert(not button.Pressed and not browser.Input.Pressed and not button.Hovered,'Focus loss kept pointer state')
	end
	assert(browser.View.TabStrip==nil and browser.OpenTab==nil and browser.ReopenClosedTab==nil,'Removed tab features remain available')
	for _,button in {browser.View.Reload,browser.View.Star,browser.View.MenuButton}do checkPressed(button)end
	local close=browser.View.Reload;move(browser.View.Content);local finger=begin(close,f.Enum.UserInputType.Touch)
	assert(close.Pressed and not close.Hovered)
	f.Input.InputEnded:Fire(f:Event(f.Enum.UserInputType.Touch));assert(browser.Input.Pressed,'A different finger ended the press')
	local x,y=point(browser.View.Content);finger.Position=f.Vector2.new(x,y);f:Hits(browser.View.Content);f.Input.InputChanged:Fire(finger)
	assert(not close.Pressed);releaseAt(finger,browser.View.Content);assert(tab.Alive and not browser.Input.Pressed)
	local menu=browser.View.MenuButton
	local held=begin(menu);move(browser.View.Star);releaseAt(held,browser.View.Star);assert(#browser:GetTabs()==1 and not browser.Overlays.Current,'Release activated a different control')
	click(menu);local panel=assert(browser.Overlays.Current).Panel
	for _,node in panel:GetDescendants()do if node:IsA('TextLabel')then assert(not node.Text:lower():find('tab',1,true),'Menu exposed a removed tab action')end end
	browser.Overlays:Dismiss()
	local requests={};local auto=true
	local handler=browser:OnNavigate(function(current,request)table.insert(requests,request);if auto then browser:CompleteNavigation(current,request,{Title=request.URL})end end)
	assert(not browser:Back(tab)and not browser:Forward(tab))
	for _,url in {'https://test.invalid/a','https://test.invalid/b','https://test.invalid/c'}do browser:Navigate(tab,url);f:Drain()end
	assert(#tab.History==4 and tab.URL=='https://test.invalid/c')
	checkPressed(browser.View.Back);browser:Back();f:Drain();checkPressed(browser.View.Forward);browser:Forward();f:Drain();assert(tab.URL=='https://test.invalid/c')
	browser:Back();f:Drain();browser:Navigate(tab,'https://test.invalid/replacement');f:Drain();assert(#tab.History==4 and not browser:Forward())
	browser:Reload();f:Drain();assert(#tab.History==4)
	local content=tab.Content;local connections=f:GlobalConnections();local count=#tab.History;local height=browser.View.ChromeHeight
	held=begin(browser.View.Reload);browser:SetNavigationVisible(false)
	assert(not browser.View.Back.Root.Visible and not browser.View.Forward.Root.Visible and not browser.View.Reload.Root.Visible and browser.View.Bar.Visible and browser.View.URL.Visible)
	assert(not browser.Input.Pressed and browser.View.ChromeHeight==height and browser.View.Content.Position.Y.Offset==height)
	releaseAt(held,browser.View.Reload);local generation=tab.Generation;click(browser.View.Reload);f:Drain();assert(tab.Generation==generation,'Hidden reload stayed clickable')
	browser:SetNavigationVisible(true);browser:SetNavigationVisible(true);assert(f:GlobalConnections()==connections and tab.Content==content and #tab.History==count)
	click(browser.View.URL);browser.View.URL.Text='draft';browser:SetNavigationVisible(false)
	assert(browser.View.URL:IsFocused()and browser.View.URL.Text=='draft','Navigation-button toggle interrupted address editing')
	browser:SetNavigationVisible(true);browser.View.URL:ReleaseFocus(false)
	auto=false;local old=browser:Navigate(tab,'https://test.invalid/old');local newer=browser:Navigate(tab,'https://test.invalid/new');f:Drain()
	assert(requests[#requests]==newer and not browser:CompleteNavigation(tab,old,{Title='stale'}))
	click(browser.View.URL);browser.View.URL.Text='draft while pending'
	assert(browser:CompleteNavigation(tab,newer,{Title='New'})and tab.Title=='New')
	assert(browser.View.URL:IsFocused()and browser.View.URL.Text=='draft while pending','A background commit overwrote address editing')
	browser.View.URL:ReleaseFocus(false)
	local pending=browser:Navigate(tab,'https://test.invalid/cancel');assert(browser:CancelNavigation(tab));f:Drain();assert(not browser:CompleteNavigation(tab,pending))
	local failure=browser:Navigate(tab,'https://test.invalid/fail');f:Drain();assert(browser:FailNavigation(tab,failure,'fixture failure'))
	assert(tab.URL=='wayline://error'and browser.Native and not tab.Loading,'Provider failure did not publish the current error page')
	auto=true;click(browser.View.URL);browser.View.URL.Text='https://test.invalid/entered';browser.View.URL:ReleaseFocus(true);f:Drain();assert(tab.URL=='https://test.invalid/entered')
	click(browser.View.Star);assert(browser.Shared:FindBookmark(tab.URL));local saved=tab.URL
	browser:Navigate(tab,'https://test.invalid/elsewhere');f:Drain();assert(browser.Shared:FindBookmark(saved),'Navigation lost a bookmark')
	click(browser.View.URL);local key=f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.X);f.Input.InputBegan:Fire(key,false);assert(browser:ConsumesInput(key))
	browser.View.URL:ReleaseFocus(false);local keyup=f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.X);f.Input.InputEnded:Fire(keyup);assert(browser:ConsumesInput(keyup),'Consumed field key leaked on release')
	for index=1,24 do assert(browser:Open('https://test.invalid/open'..index)==tab)end;f:Drain()
	assert(browser:GetPage()==tab and #browser:GetTabs()==1 and tab.Content==content,'Opening another address created an additional document')
	host.Size=f.UDim2.fromOffset(480,400);f:Drain()
	assert(browser.View.Bar.Position.Y.Offset==0 and browser.View.Content.Position.Y.Offset==browser.View.ChromeHeight)
	host.Size=f.UDim2.fromOffset(900,600);f:Drain()
	local resize={};browser:OnResize(function(value)table.insert(resize,value)end);browser:SetResizing(true);browser:SetResizing(true);browser:SetResizing(false);assert(#resize==2 and resize[1]and not resize[2])
	inactive();handler:Disconnect();browser.Window:Destroy();f:Drain();assert(not browser.Alive and f:GlobalConnections()==0 and #browser:GetTabs()==0)
	browser:Destroy();assert(not browser:Back()and not browser:Navigate(tab,'late'))
	local g=fixture();local gh=g.Create('Frame',g.Screen,{Size=g.UDim2.fromScale(1,1)})
	local lastBrowser=loadBrowser(g).mount(gh,{PersistenceEnabled=false,Services={Create=g.Create,Input=g.Input,PlayerGui=g.PlayerGui,Task=g.Task}});g:Drain()
	lastBrowser:CloseTab(lastBrowser:GetActiveTab());g:Drain();assert(#lastBrowser:GetTabs()==0,'Closing a document automatically created a replacement tab')
	lastBrowser:Open();g:Drain()
	lastBrowser:OnCloseTab(function()lastBrowser:Destroy()end);lastBrowser:CloseTab(lastBrowser:GetActiveTab());g:Drain();assert(not lastBrowser.Alive and g:GlobalConnections()==0)
	local h=fixture();local hh=h.Create('Frame',h.Screen,{Size=h.UDim2.fromScale(1,1)})
	local popup=loadBrowser(h).mount(hh,{ShowNavigation=false,PersistenceEnabled=false,Services={Create=h.Create,Input=h.Input,PlayerGui=h.PlayerGui,Task=h.Task}});h:Drain()
	assert(not popup.View.TabStrip and not popup.View.Back.Root.Visible and popup.View.Bar.Visible)
	popup:SetNavigationVisible(true);assert(popup.View.Back.Root.Visible and popup.View.Bar.Visible)
	popup:SetFullscreen(true);popup:SetNavigationVisible(false);popup:_Changed();assert(popup.View.Content.Position.Y.Offset==0 and popup.View.Content.Size.Y.Offset==0)
	popup:SetFullscreen(false);assert(popup.Chrome.Visible and popup.View.Bar.Visible and not popup.View.Back.Root.Visible and popup.View.Content.Position.Y.Offset==popup.View.ChromeHeight)
	popup:Destroy();assert(h:GlobalConnections()==0)
	do
		-- A fresh play session must not restore a personal profile or contact a
		-- persistence transport, even when the caller supplies no storage options.
		local memory=fixture();local Browser=loadBrowser(memory)
		local original=Browser.PersistenceClient.new;local transportStarts=0
		Browser.PersistenceClient.new=function()transportStarts+=1;error('Unexpected persistent transport in the default browser')end
		local function mount()
			local content=memory.Create('Frame',memory.Screen,{Size=memory.UDim2.fromScale(1,1)})
			return Browser.mount(content,{ResolveExternal=function(url)return{URL=url,Kind='external'}end,
				Services={Create=memory.Create,Input=memory.Input,PlayerGui=memory.PlayerGui,Task=memory.Task}})
		end
		local first=mount();memory:Drain()
		assert(first.Persistence==nil and transportStarts==0)
		local originalTheme=first.Shared.Settings.Theme
		assert(first.Shared:SetSetting('Theme',if originalTheme=='Dark'then'Light'else'Dark'))
		assert(first.Shared:AddBookmark('Temporary bookmark','https://test.invalid/temporary'))
		first:OnNavigate(function(tab,request)first:CompleteNavigation(tab,request,{Title='Temporary page'})end)
		first:Navigate('https://test.invalid/temporary');memory:Drain()
		assert(#first.Shared.History>0 and first.Shared:FindBookmark('https://test.invalid/temporary'))
		first:Destroy();memory:Drain()
		local second=mount();memory:Drain()
		assert(second.Persistence==nil and transportStarts==0,'Reopening the browser cannot create a persistent transport')
		assert(second.Shared.Settings.Theme==originalTheme and #second.Shared.History==0
			and not second.Shared:FindBookmark('https://test.invalid/temporary'),'A new browser session starts with fresh settings, history and bookmarks')
		assert(second:GetPage().URL=='wayline://home','The previous play session address is not restored')
		second:Destroy();memory:Drain();Browser.PersistenceClient.new=original
		assert(memory:GlobalConnections()==0)
	end
	print('BrowserShell: single document, press/hover/touch, navigation tickets, history, removed tab creation and cleanup passed')
end
