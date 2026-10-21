--!strict
-- A restored multi-page snapshot must mount only its formerly selected document.
return function(loadBrowser,fixture)
	local f=fixture()
	local parent=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local legacy={Version=1,Selected=8,Tabs={
		{ID=3,URL='wayline://home',Title='Background',History={{URL='wayline://home',Title='Background'}},HistoryIndex=1},
		{ID=8,URL='wayline://settings',Title='Settings',History={
			{URL='wayline://home',Title='Home',State={Scroll={X=0,Y=17}}},
			{URL='wayline://settings',Title='Settings',State={Scroll={X=0,Y=23}}},
		},HistoryIndex=2},
	},Closed={{ID=11,URL='wayline://guide',Title='Closed',History={},HistoryIndex=0}}}
	local browser=loadBrowser(f).mount(parent,{Session=legacy,PersistenceEnabled=false,
		Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task}})
	f:Drain()
	local page=assert(browser:GetPage())
	assert(page.URL=='wayline://settings' and #browser:GetTabs()==1 and #page.History==2)
	assert(browser.Native and browser.Native.Tab==page and browser.View.TabStrip==nil)
	assert(page.History[1].State.Scroll.Y==17 and page.HistoryIndex==2)
	local targets=0
	for _,child in browser.View.Content:GetChildren()do
		if child.Name:match('^PageContent_')then
			targets+=1
			assert(child:GetAttribute('HTMLInputBlocker')==nil,'The document target cannot block its own HTML input')
		end
	end
	assert(targets==1,'Restoration created hidden background documents')
	browser:Back();f:Drain();assert(page.URL=='wayline://home' and browser:GetPage()==page)
	browser:Forward();f:Drain();assert(page.URL=='wayline://settings' and browser:GetPage()==page)
	local exported=browser:ExportSession()
	assert(exported.Version==2 and exported.Page.URL==page.URL and exported.Tabs==nil and exported.Closed==nil)
	local oldContent=page.Content
	assert(browser:RestoreSession(legacy,false));f:Drain()
	assert(not page.Alive and oldContent.Destroyed and page.Content==nil and #browser:GetTabs()==1)
	assert(browser:GetPage().URL=='wayline://settings')
	local current=browser:GetPage()
	local bad={Version=2,Page={URL='javascript:bad()'}}
	assert(not browser:RestoreSession(bad,false) and browser:GetPage()==current and current.Alive)
	browser:Destroy();f:Drain()
	assert(f:GlobalConnections()==0)
	print('BrowserSingleSession: selected legacy page, retained history, one native content target, restoration disposal and input isolation passed')
end
