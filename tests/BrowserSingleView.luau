--!strict
-- A browser window has one address toolbar and one document, on desktop and touch.
return function(loadBrowser,fixture)
	local function run(touch)
		local f=fixture();f.Input.MouseEnabled=not touch;f.Input.TouchEnabled=touch
		local parent=f.Create('Frame',f.Screen,{Size=f.UDim2.fromOffset(900,600)})
		local browser=loadBrowser(f).mount(parent,{PersistenceEnabled=false,ShowHomeButton=true,
			ResolveExternal=function(url)return {Kind='external',URL=url}end,
			Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task,Clock=function()return f:Clock()end}})
		f:Drain();local page=assert(browser:GetPage());local content=page.Content
		local function root(object)return object.Root or object end
		local function point(object)local node=root(object);return node.AbsolutePosition+node.AbsoluteSize/2 end
		local function move(object)
			local node=root(object);local p=point(node);f.Input.Mouse=p;f:Hits(node)
			f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,p.X,p.Y))
		end
		local function begin(object)
			local p=point(object);return f:Begin(root(object),nil,p.X,p.Y)
		end
		local function release(event,object)
			event.Position=point(object);f:Hits(root(object));f.Input.InputEnded:Fire(event)
		end
		local function click(object)local event=begin(object);release(event,object);f:Drain()end
		local function assertPassive()
			for _,node in browser.Window:GetDescendants()do
				assert(not node.Name:match('^[Tt]ab')and node.Name~='NewTab'and node.Name~='CloseTab','Removed tab UI exists: '..node.Name)
				if node:IsA('GuiObject')then assert(node.Active==false and node.Selectable==false,'Control uses native active input: '..node.Name)end
			end
		end
		local height=if touch then 52 else 46
		assert(browser.View.Bar.Position.Y.Offset==0 and browser.View.ChromeHeight==height,'A removed tab strip left empty header space')
		assert(browser.View.Content.Position.Y.Offset==height and browser.View.Content.Size.Y.Offset==-height)
		assert(browser.View.Home.Root.Visible and browser.View.Back.Root.Visible and browser.View.Reload.Root.Visible)
		assertPassive()
		local visit=browser:OnNavigate(function(current,request)browser:CompleteNavigation(current,request,{Title='External page'})end)
		browser:Navigate('https://example.invalid/first');f:Drain()
		assert(browser:GetPage()==page and page.Content==content and page.URL=='https://example.invalid/first')
		assert(browser.View.URL.Text==page.URL and browser.View.Back.Enabled and not browser.View.Forward.Enabled)
		for _,button in {browser.View.Back,browser.View.Reload,browser.View.Star,browser.View.MenuButton}do
			move(button);local hover=button.Root.BackgroundColor3;local event=begin(button)
			local pressed=button.Root.BackgroundColor3
			assert(button.Pressed and(hover.R~=pressed.R or hover.G~=pressed.G or hover.B~=pressed.B),'No distinct pressed state')
			browser:_Changed();assert(button.Pressed)
			move(browser.View.Content);assert(not button.Pressed,'Pressed state remains after pointer leaves')
			release(event,browser.View.Content)
		end
		click(browser.View.Star);assert(browser.Shared:FindBookmark(page.URL)and browser.View.Star.Selected)
		assert(not browser.View.Bookmarks.Root.Visible,'A website unexpectedly gained the Home bookmarks row')
		click(browser.View.MenuButton);local menu=assert(browser.Overlays.Current);local rows={}
		for _,node in menu.Panel:GetDescendants()do
			if node:IsA('TextLabel')then
				assert(not node.Text:lower():find('tab',1,true),'Browser menu still offers a tab action: '..node.Text)
				rows[node.Text]=node.Parent
			end
		end
		for _,name in {'Home','Bookmark this page','Bookmarks','History','Settings'}do assert(rows[name],'Missing menu action: '..name)end
		click(rows.Settings);assert(page.URL=='wayline://settings'and browser:GetPage()==page and page.Content==content)
		click(browser.View.Home);assert(page.URL=='wayline://home'and browser:GetPage()==page and browser.Native.Page.Alive)
		assert(browser.View.Bookmarks.Root.Visible and browser.View.ChromeHeight==height+(if touch then 42 else 34))
		click(browser.View.URL);browser.View.URL.Text='https://example.invalid/entered';browser.View.URL:ReleaseFocus(true);f:Drain()
		assert(page.URL=='https://example.invalid/entered'and browser:GetPage()==page)
		local held=begin(browser.View.Reload);browser:SetNavigationVisible(false)
		assert(not browser.View.Back.Root.Visible and not browser.View.Forward.Root.Visible and not browser.View.Reload.Root.Visible)
		assert(browser.View.Bar.Visible and browser.View.URL.Visible and browser.View.Bar.Position.Y.Offset==0)
		assert(not browser.Input.Pressed,'Hiding a pressed navigation button kept the capture')
		release(held,browser.View.Content);browser:SetNavigationVisible(true)
		parent.Size=f.UDim2.fromOffset(480,360);f:Drain();assert(browser.View.Content.Visible and not browser.View.TooSmall)
		parent.Size=f.UDim2.fromOffset(320,240);f:Drain()
		assert(browser.View.TooSmall and browser.View.SizeNotice.Visible and not browser.Input.Active and browser:GetPage()==page and page.Content==content)
		parent.Size=f.UDim2.fromOffset(900,600);f:Drain();assert(browser.View.Content.Visible and browser.Input.Active)
		browser:SetFullscreen(true);assert(browser.View.Content.Position.Y.Offset==0 and browser.View.Content.Size.Y.Offset==0 and not browser.Chrome.Visible)
		browser:SetFullscreen(false);assert(browser.Chrome.Visible and browser.View.Content.Position.Y.Offset==height)
		assertPassive();visit:Disconnect();browser:Destroy();f:Drain();assert(f:GlobalConnections()==0)
	end
	run(false);run(true)
	print('BrowserSingleView: desktop/touch toolbar, no tab controls/actions, passive press routing, single document, bookmarks, resize and fullscreen passed')
end
