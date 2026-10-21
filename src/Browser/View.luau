--!strict
-- Wayline fills a host-owned Frame; window geometry belongs to the host.
local BookmarksBar=require(script.Parent.BookmarksBar)
local View={};View.__index=View
function View.new(browser,gui,parent,options,scope)
	local input=browser.Services.Input or browser.Services.UserInputService or game:GetService('UserInputService')
	local self=setmetatable({Browser=browser,Gui=gui,Scope=scope,Pages={},Touch=input.TouchEnabled and not input.MouseEnabled,NavigationVisible=options.ShowNavigation~=false,ShowHomeButton=options.ShowHomeButton==true,Fullscreen=false},View)
	self.Window=gui:Make('Frame',parent,{Name='Wayline',Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),Visible=browser.Shown,ClipsDescendants=true,BorderSizePixel=0,BackgroundTransparency=0},{BackgroundColor3='Background'})
	self.Chrome=gui:Make('Frame',self.Window,{Name='BrowserChrome',Size=UDim2.new(1,0,0,46),ZIndex=20,BackgroundTransparency=0},{BackgroundColor3='Toolbar'})
	self.Content=gui:Make('Frame',self.Window,{Name='BrowserContent',Position=UDim2.fromOffset(0,46),Size=UDim2.new(1,0,1,-46),ClipsDescendants=true,ZIndex=1,BackgroundTransparency=0},{BackgroundColor3='Background'})
	self.Separator=gui:Make('Frame',self.Chrome,{Name='ContentSeparator',Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),ZIndex=22,BackgroundTransparency=0},{BackgroundColor3='Border'})
	self.OverlayRoot=gui:Make('Frame',self.Window,{Name='WaylineOverlays',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=200})
	self.SizeNotice=gui:Make('Frame',self.Window,{Name='MinimumSizeNotice',Size=UDim2.fromScale(1,1),Visible=false,ZIndex=300,BackgroundTransparency=0},{BackgroundColor3='Background'})
	gui:Make('TextLabel',self.SizeNotice,{Text='Window too small',TextSize=20,TextWrapped=true,Position=UDim2.new(0,24,.5,-60),Size=UDim2.new(1,-48,0,60),BackgroundTransparency=1},{TextColor3='Text'})
	gui:Make('TextLabel',self.SizeNotice,{Text='Resize the content area to at least 480 by 360 pixels. Your page is kept.',TextSize=14,TextWrapped=true,Position=UDim2.new(0,24,.5,8),Size=UDim2.new(1,-48,0,60),BackgroundTransparency=1},{TextColor3='Muted'})
	self.Loading=gui:Make('Frame',self.Window,{Name='LoadingLine',Visible=false,Size=UDim2.new(1,0,0,2),ZIndex=30,ClipsDescendants=true,BackgroundTransparency=0},{BackgroundColor3='AccentSoft'})
	self.LoadingFill=gui:Make('Frame',self.Loading,{Name='LoadingMotion',Size=UDim2.new(.3,0,1,0),BackgroundTransparency=0},{BackgroundColor3='Accent'})
	return self
end
function View:Attach()
	local browser=self.Browser;local controls=browser:ControlsFor(self.Scope);self.Controls=controls
	self.Bar=self.Gui:Make('Frame',self.Chrome,{Name='AddressBar',Size=UDim2.new(1,0,0,46),BackgroundTransparency=0},{BackgroundColor3='Toolbar'})
	local function action(name,icon,tooltip,callback)
		return controls:Button(self.Bar,{Name=name,Icon=icon,IconSize=20,Variant='Toolbar',Tooltip=tooltip,Width=34,Height=34,OnClick=callback})
	end
	self.Back=action('Back','back','Go back',function()browser:Back()end)
	self.Forward=action('Forward','forward','Go forward',function()browser:Forward()end)
	self.Reload=action('Reload','reload','Reload this page',function()local page=browser:GetPage();if page and page.Loading then browser:CancelNavigation(page)else browser:Reload()end end)
	self.Home=action('Home','home','Open Home',function()browser:Navigate('wayline://home')end)
	self.Address=self.Gui:Make('Frame',self.Bar,{Name='AddressField',Position=UDim2.fromOffset(118,7),Size=UDim2.new(1,-166,0,32),BackgroundTransparency=0},{BackgroundColor3='Omnibox'})
	self.Gui:Corner(self.Address,20);self.AddressStroke=self.Gui:Stroke(self.Address,'Accent',1);self.AddressStroke.Transparency=1
	local function addressHover(value)self.AddressHovered=value;self:PaintAddress()end
	self.SiteInfo=controls:Button(self.Address,{Name='PageInformation',Icon='search',IconSize=16,Variant='Toolbar',Tooltip='Search or enter address',Width=26,Height=26,Hover=addressHover,OnClick=function()
		local page=browser:GetPage()
		if not page or browser.Model:IsStartPage(page.URL)then browser.Input:CaptureFocus(self.URL);return end
		browser.Overlays:Menu(self.SiteInfo.Root,{{Text=page.Title or 'Current page',Detail=page.URL,Icon=page.Icon or 'page'},
			{Text=if browser.Address:Resolve(page.URL).Kind=='external'then 'Rendered by the HTML provider'else 'Built-in browser page',Icon='guide'}})
	end})
	self.SiteInfo.Root.AnchorPoint=Vector2.new(0,.5);self.SiteInfo.Root.Position=UDim2.new(0,4,.5,0)
	self.URL=controls:Field(self.Address,{Name='Address',Variant='Omnibox',TextSize=14,Placeholder='Search or enter address',OnSubmit=function(value)browser:Navigate(value)end,
		Hover=addressHover,OnChanged=function(value)if self.URL and self.URL:IsFocused()then browser.InteractionGeneration+=1;self:Suggest(value)end end})
	self.URL.Position=UDim2.fromOffset(36,0);self.URL.Size=UDim2.new(1,-74,1,0)
	self.Star=controls:Button(self.Address,{Name='Bookmark',Icon='bookmark',IconSize=20,Variant='Toolbar',Tooltip='Bookmark this page',Width=28,Height=28,Hover=addressHover,OnClick=function()browser:ToggleBookmark()end})
	self.Star.Root.AnchorPoint=Vector2.new(1,.5);self.Star.Root.Position=UDim2.new(1,-3,.5,0)
	self.MenuButton=action('BrowserMenu','vertical-menu','Browser actions',function()self:Menu()end)
	self.Bookmarks=BookmarksBar.new(browser,self.Chrome,self.Gui,self.Scope)
	self.Scope:Add(self.Window:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()browser.Overlays:Dismiss();self:Layout();browser:_Changed()end))
	self.Scope:Add(self.URL.FocusLost:Connect(function()browser.Overlays:DismissSuggestions();self:UpdateAddress()end))
	self.Scope:Add((browser.Input:Bind(self.Address,{Begin=function()browser.Input:CaptureFocus(self.URL)end,Hover=addressHover})))
	local function focusRing()self:PaintAddress()end
	self.Scope:Add(self.URL.Focused:Connect(focusRing));self.Scope:Add(self.URL.FocusLost:Connect(focusRing))
	self.Scope:Add(browser.Theme.Changed:Connect(focusRing))
	self:Layout()
end
function View:PaintAddress()
	if not self.URL then return end
	local focused=self.URL:IsFocused();local theme=self.Browser.Theme
	theme:Animate(self.AddressStroke,{Transparency=if focused then 0 else 1})
	theme:Animate(self.Address,{BackgroundColor3=theme.Tokens[if focused then 'OmniboxFocused'elseif self.AddressHovered then 'OmniboxHover'else 'Omnibox']})
end
function View:Suggest(text)
	if not self.Browser.Overlays then return end
	if text==''then self.Browser.Overlays:DismissSuggestions();return end
	self.Browser.Overlays:Suggestions(self.Address,self.Browser:Suggestions(text),function(item)self.URL:ReleaseFocus(false);self.Browser:Navigate(item.Address or item.URL)end)
end
function View:Menu()
	local browser=self.Browser;local items={
		{Text='Home',Icon='home',Action=function()browser:Navigate('wayline://home')end},
		{Text='Bookmark this page',Icon='bookmark',Action=function()browser:ToggleBookmark()end},
		{Text='Bookmarks',Icon='folder',Action=function()browser:Navigate('wayline://bookmarks')end},
		{Text='History',Icon='history',Action=function()browser:Navigate('wayline://history')end},
		{Separator=true},
		{Text='Settings',Icon='settings',Action=function()browser:Navigate('wayline://settings')end},
		{Text=if browser.Shared.Settings.BookmarksBar then 'Hide bookmarks bar'else 'Show bookmarks bar',Icon='bookmark',Action=function()browser.Shared:SetSetting('BookmarksBar',not browser.Shared.Settings.BookmarksBar)end}}
	browser.Overlays:Menu(self.MenuButton.Root,items)
end
function View:Layout()
	if not self.Bar then return end
	local size=self.Window.AbsoluteSize;local narrow=size.X<640;local tokens=self.Browser.Theme.Tokens
	self.TooSmall=size.X<480 or size.Y<360;self.SizeNotice.Visible=self.TooSmall
	local buttonSize=if self.Touch then tokens.ChromeTouchButtonSize else tokens.ChromeButtonSize
	local barHeight=if self.Touch then 52 else tokens.ChromeToolbarHeight
	local top=0
	self.Bar.Position=UDim2.fromOffset(0,top);self.Bar.Size=UDim2.new(1,0,0,barHeight)
	local gap=if self.Touch then 2 else tokens.ChromeToolbarGap
	local x=6;local buttonY=math.floor((barHeight-buttonSize)/2)
	for _,button in {self.Back,self.Forward,self.Reload}do
		button.Root.Visible=self.NavigationVisible;button.Root.Position=UDim2.fromOffset(x,buttonY);button.Root.Size=UDim2.fromOffset(buttonSize,buttonSize)
		if self.NavigationVisible then x+=buttonSize+gap end
	end
	local showHome=self.ShowHomeButton and not narrow
	self.Home.Root.Visible=showHome;self.Home.Root.Position=UDim2.fromOffset(x,buttonY);self.Home.Root.Size=UDim2.fromOffset(buttonSize,buttonSize)
	if showHome then x+=buttonSize+gap end
	local margin=if self.Touch then 4 else tokens.ChromeLocationMargin
	x+=margin-(if self.NavigationVisible or showHome then gap else 0)
	local addressHeight=if self.Touch then 44 else tokens.ChromeAddressHeight
	self.Address.Position=UDim2.fromOffset(x,math.floor((barHeight-addressHeight)/2));self.Address.Size=UDim2.new(1,-x-buttonSize-6-margin,0,addressHeight)
	self.MenuButton.Root.Position=UDim2.new(1,-buttonSize-6,0,buttonY);self.MenuButton.Root.Size=UDim2.fromOffset(buttonSize,buttonSize)
	local starSize=if self.Touch then 40 else 28;self.Star.Root.Size=UDim2.fromOffset(starSize,starSize)
	local leading=if self.Touch then 44 else 36;self.SiteInfo.Root.Size=UDim2.fromOffset(if self.Touch then 40 else 26,if self.Touch then 40 else 26)
	self.URL.Position=UDim2.fromOffset(leading,0);self.URL.Size=UDim2.new(1,-leading-starSize-8,1,0)
	local active=self.Browser:GetPage()
	local address=active and(if active.Pending and active.Pending.Dispatched then active.Pending.URL else active.URL)
	local showBookmarks=self.Browser.Shared.Settings.BookmarksBar==true and address~=nil and self.Browser.Model:IsStartPage(address) and next(self.Browser.Shared.Bookmarks)~=nil
	local bookmarkHeight=if self.Touch then 42 else tokens.ChromeBookmarkHeight
	self.Bookmarks.Root.Visible=showBookmarks;self.Bookmarks.Root.Position=UDim2.fromOffset(0,top+barHeight);self.Bookmarks.Root.Size=UDim2.new(1,0,0,bookmarkHeight)
	self.ChromeHeight=top+barHeight+(if showBookmarks then bookmarkHeight else 0)
	self.Chrome.Size=UDim2.new(1,0,0,self.ChromeHeight);self.Chrome.Visible=not self.Fullscreen and not self.TooSmall
	local inset=if self.Fullscreen then 0 else self.ChromeHeight
	self.Content.Position=UDim2.fromOffset(0,inset);self.Content.Size=UDim2.new(1,0,1,-inset);self.Content.Visible=not self.TooSmall
	self.Loading.Position=UDim2.fromOffset(0,top+barHeight-2);self.Loading.Visible=self.LoadingActive==true and not self.Fullscreen and not self.TooSmall;self.OverlayRoot.Visible=not self.TooSmall
	self.Bookmarks:Sync();self.Browser:_ApplyInputState()
end
function View:AddPage(page)
	if self.Pages[page]then return end
	local target=self.Gui:Make('Frame',self.Content,{Name='PageContent_'..page.ID,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants=true,Visible=false})
	self.Pages[page]={Content=target};page.Content=target
end
function View:RemovePage(page)
	local row=self.Pages[page];if not row then return end;row.Content:Destroy();self.Pages[page]=nil;page.Content=nil
end
function View:Update(model)
	if not self.Bar then return end
	for page,row in self.Pages do row.Content.Visible=page==model.Active end
	local active=model.Active
	self:UpdateAddress()
	self.Back:SetEnabled(model:CanBack(active));self.Forward:SetEnabled(model:CanForward(active))
	self.Reload:SetIcon(if active and active.Loading then 'close'else 'reload');self.Reload.Entry.Tooltip=if active and active.Loading then 'Stop loading'else 'Reload this page'
	self.Star:SetSelected(active~=nil and self.Browser.Shared:FindBookmark(active.URL)~=nil)
	self:SetLoading(active~=nil and active.Loading==true);self:Layout()
end
function View:UpdateAddress()
	local active=self.Browser:GetPage()
	local address=if active then(active.Pending and active.Pending.URL or active.URL)else ''
	local start=address=='' or self.Browser.Model:IsStartPage(address)
	if not self.URL:IsFocused()then self.URL.Text=if start then ''else address end
	self.SiteInfo:SetIcon(if start then 'search'else 'site-controls');self.SiteInfo.Entry.Tooltip=if start then 'Search or enter address'else 'View page information'
end
function View:SetLoading(active)
	if self.LoadingActive==active then return end;self.LoadingActive=active;self.Loading.Visible=active and not self.Fullscreen and not self.TooSmall
	if self.LoadingTween then self.LoadingTween:Cancel();self.LoadingTween=nil end
	if active then
		local service=self.Browser.Services.TweenService or game:GetService('TweenService')
		self.LoadingFill.Position=UDim2.new(-.3,0,0,0)
		self.LoadingTween=service:Create(self.LoadingFill,TweenInfo.new(.9,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1),{Position=UDim2.new(1,0,0,0)})
		self.LoadingTween:Play()
	end
end
function View:SetNavigationVisible(visible)self.NavigationVisible=visible;self:Layout()end
function View:SetFullscreen(enabled)self.Fullscreen=enabled;self:Layout()end
function View:Destroy()
	if self.LoadingTween then self.LoadingTween:Cancel();self.LoadingTween=nil end
	if self.Bookmarks then self.Bookmarks:Destroy()end
	for page in table.clone(self.Pages)do self:RemovePage(page)end;self.Window:Destroy()
end
return View
