--!strict
return function(loadBrowser,fixture)
	local f=fixture();local parent=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local browser=loadBrowser(f).new(parent,{AutoOpen=false,PersistenceEnabled=false,Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task},
		ResolveExternal=function(url)if url:match('^http://localhost:8000/')then return {Kind='external',URL=url,Title=url}end end})
	local function point(object)return object.AbsolutePosition+object.AbsoluteSize/2 end
	local function click(object)
		object=object.Root or object;local p=point(object);f.Input.Mouse=p
		local event=f:Begin(object,nil,p.X,p.Y);f.Input.InputEnded:Fire(event);return event
	end
	local function move(object)local p=point(object);f.Input.Mouse=p;f:Hits(object);f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,p.X,p.Y))end
	local function named(root,name)for _,object in root:GetDescendants()do if object.Name==name then return object end end;error('Missing '..name)end
	local function descendants(root,name)local result={};for _,object in root:GetDescendants()do if object.Name==name then table.insert(result,object)end end;return result end
	local function shortcut(title)
		for _,object in descendants(browser.Native.Page.Content,'ShortcutTitle')do if object.Text==title then return object.Parent end end
		error('Missing shortcut '..title)
	end
	local requests,startRequests={},0
	browser:OnNavigate(function(tab,request)table.insert(requests,{Tab=tab,Request=request})end)
	browser:OnStartPage(function()startRequests+=1 end)
	local first=browser:Open();f:Drain()
	assert(browser:IsStartPage(first.URL)and first.Title=='Home'and not first.Loading and #requests==0,'Home is native and needs no HTML provider')
	assert(browser.Native and browser.Native.Page.Alive and browser.View.URL.Text==''and named(browser.Native.Page.Content,'Wordmark').Text=='Wayline')
	assert(not browser.View.Bookmarks.Root.Visible and browser.View.ChromeHeight==46 and browser.View.Content.Position.Y.Offset==46,'Empty bookmarks do not reserve a toolbar row')
	assert(browser.OpenTab==nil and browser.View.TabStrip==nil,"Home does not expose tab controls")
	local function visit(tab,url,title,icon)
		browser:SelectTab(tab);local request=browser:Navigate(tab,url);f:Drain()
		assert(browser:IsCurrent(tab,request)and browser.View.Loading.Visible and browser.View.Reload.Icon.Name=='Icon_close')
		assert(not browser.View.Bookmarks.Root.Visible and browser.View.ChromeHeight==46,'External content never shows the Home bookmark strip')
		assert(browser:CompleteNavigation(tab,request,{Title=title or url,Icon=icon}))
		assert(not browser.View.Loading.Visible and browser.View.Reload.Icon.Name=='Icon_reload'and browser.View.Content.Size.Y.Offset==-46)
	end
	local aURL,bURL='http://localhost:8000/a/index.html','http://localhost:8000/b/index.html'
	visit(first,aURL,'Page A','rbxassetid://123');click(browser.View.Star);f:Drain()
	local aBookmark=assert(browser.Shared:FindBookmark(aURL));assert(browser.View.Star.Selected)
	visit(first,bURL,'Page B');click(browser.View.Star);f:Drain();local bBookmark=assert(browser.Shared:FindBookmark(bURL))
	do
		local textService=f.Game:GetService('TextService');local measure=textService.GetTextSize;local measured=0
		textService.GetTextSize=function(...)measured+=1;return measure(...)end
		for _=1,8 do browser.View.Bookmarks:Sync()end
		textService.GetTextSize=measure
		assert(measured==0,'Hidden bookmark strip must not measure its first saved title')
	end
	local home=browser:Open();f:Drain()
	assert(browser.Native.Tab==home and browser.View.Bookmarks.Root.Visible and browser.View.ChromeHeight==80 and browser.View.Content.Position.Y.Offset==80,'Home alone gets the thin nonempty bookmark row')
	local aRow=assert(browser.View.Bookmarks.Rows[aBookmark.ID]);local sameButton=aRow.Button.Root
	do
		local textService=f.Game:GetService('TextService');local measure=textService.GetTextSize;local measured=0
		textService.GetTextSize=function(...)measured+=1;return measure(...)end
		for _=1,8 do browser:_Changed()end
		assert(measured==0,'Unchanged bookmark controls must retain their own text measurements')
		browser.Shared:EditItem(aBookmark.ID,'A renamed bookmark')
		assert(measured==1 and aRow.Button.Root==sameButton,'A title change remeasures just the matching bookmark and keeps its GUI')
		browser.Shared:EditItem(aBookmark.ID,'Page A')
		assert(measured==2)
		local font=browser.Theme.Tokens.Font;browser.Theme.Tokens.Font='ChangedFixtureFont';browser.View.Bookmarks:Sync()
		assert(measured==4,'A font change invalidates each affected bookmark measurement')
		browser.Theme.Tokens.Font=font;browser.View.Bookmarks:Sync();assert(measured==6)
		textService.GetTextSize=measure
		print('BrowserStartPage operations: 8 unchanged two-bookmark updates = 0 measures; rename = 1; font change = 2; 8 hidden syncs = 0')
	end
	assert(browser.View.Bookmarks.Rows[aBookmark.ID].Button.Root==sameButton,'Unchanged bookmarks retain controls and bindings')
	-- Home now owns saved quick links; recent visits remain in the History page.
	assert(browser.Shared:AddQuickLink('Page A',aURL));assert(browser.Shared:AddQuickLink('Page B',bURL));f:Drain()
	local link=shortcut('Page A');local oldNative=browser.Native.Page
	for _,button in {link,sameButton}do
		move(button);local hover=button.BackgroundColor3;local p=point(button);local held=f:Begin(button,nil,p.X,p.Y);local down=button.BackgroundColor3
		assert(down.R~=hover.R and button.BackgroundTransparency==0 and not home.Pending,'Dynamic Home controls have distinct pressed feedback')
		browser:_Changed();assert(button.BackgroundColor3==down,'Refresh keeps the current press')
		move(browser.View.Content);f.Input.InputEnded:Fire(held)
		assert(button.BackgroundTransparency==1 and not home.Pending and browser:IsStartPage(home.URL),'Release away never navigates')
	end
	click(link);f:Drain();local pending=assert(home.Pending)
	assert(pending.URL==aURL and not oldNative.Alive and not browser.View.Bookmarks.Root.Visible,'Quick link URL='..pending.URL..'; old native alive='..tostring(oldNative.Alive)..'; bookmarks visible='..tostring(browser.View.Bookmarks.Root.Visible))
	assert(browser:CompleteNavigation(home,pending,{Title='Page A'}));local count=#requests
	browser:Back(home);f:Drain();assert(browser:IsStartPage(home.URL)and browser.Native.Page.Alive and browser.View.Bookmarks.Root.Visible and #requests==count,'Back restores native Home without external loading')
	local bRow=assert(browser.View.Bookmarks.Rows[bBookmark.ID]);click(bRow.Button);f:Drain();pending=assert(home.Pending)
	assert(pending.URL==bURL and browser:CompleteNavigation(home,pending,{Title='Page B'}))
	local recent=browser.Model.Recent;assert(recent[1].URL==bURL,'Repeated visit moves its unique recent entry to the front')
	local occurrences=0;for _,entry in recent do if entry.URL==bURL then occurrences+=1 end end;assert(occurrences==1)
	local prior=assert(browser.Shared:FindBookmark(aURL));assert(prior.ID==aBookmark.ID,'Navigation preserves saved bookmarks')
	local version=browser.Model.RecentVersion
	local stale=browser:Navigate(home,'http://localhost:8000/stale');local failed=browser:Navigate(home,'http://localhost:8000/failed');f:Drain()
	assert(not browser:CompleteNavigation(home,stale,{Title='Stale'}));browser:FailNavigation(home,failed,'Expected failure')
	assert(browser.Model.RecentVersion==version,'Failed or stale loading is absent from history')
	local document=browser:GetPage();browser:Open();f:Drain();assert(browser:GetPage()==document and #browser:GetTabs()==1)
	for index=1,40 do visit(first,'http://localhost:8000/page'..index,'Page '..index);browser:ToggleBookmark()end
	assert(#browser.Model.Recent==32,'Recent unique links are bounded independently of full History')
	browser:Open();f:Drain();assert(browser.View.Bookmarks.Root.Visible and browser.View.Bookmarks.More.Root.Visible,'Crowded bookmarks use an overflow control')
	parent.Size=f.UDim2.fromOffset(480,360);f:Drain();assert(browser.View.Content.Visible and not browser.View.TooSmall)
	local content=browser.Native.Page.Content;local quick=descendants(content,'OpenShortcut')
	for _,button in quick do assert(button.AbsolutePosition.X>=content.AbsolutePosition.X and button.AbsolutePosition.X+button.AbsoluteSize.X<=content.AbsolutePosition.X+content.AbsoluteSize.X,'Home shortcuts stay within the narrow content width')end
	assert(#quick==6 and quick[4].Position.Y.Offset>=quick[1].Position.Y.Offset,'Saved shortcuts survive responsive reflow')
	local tabCount=#browser:GetTabs();parent.Size=f.UDim2.fromOffset(320,240);f:Drain()
	assert(browser.View.TooSmall and browser.View.SizeNotice.Visible and not browser.Input.Active and #browser:GetTabs()==tabCount,'Minimum-size notice preserves all tab data')
	parent.Size=f.UDim2.fromOffset(900,600);f:Drain();assert(browser.Input.Active and browser.View.Content.Visible)
	local entries=0;for _ in browser.Input.Entries do entries+=1 end
	for _=1,10 do browser:_Changed()end;local after=0;for _ in browser.Input.Entries do after+=1 end;assert(after==entries,'Repeated refresh does not accumulate input bindings')
	for _,object in browser.Window:GetDescendants()do if object:IsA('GuiObject')then assert(object.Active==false and object.Selectable==false,'Dynamic controls stay passive')end end
	browser:Destroy();parent:Destroy();f:Drain();assert(f:GlobalConnections()==0 and #browser.Model.Recent==0 and next(browser.Input.Entries)==nil)
	local g=fixture();local autoHost=g.Create('Frame',g.Screen,{Size=g.UDim2.fromScale(1,1)})
	local auto=loadBrowser(g).new(autoHost,{PersistenceEnabled=false,Services={Create=g.Create,Input=g.Input,PlayerGui=g.PlayerGui,Task=g.Task}});g:Drain()
	assert(auto.Native.Page.Alive);auto:CloseTab(auto:GetActiveTab());g:Drain();assert(auto.Native==nil and #auto:GetTabs()==0,'Closing never creates a replacement tab')
	auto:Destroy();autoHost:Destroy();g:Drain();assert(g:GlobalConnections()==0)
	print('BrowserStartPage: native Home, atlas controls, saved shortcuts, bookmarks, history, responsive bounds, passive input and cleanup passed')
end
