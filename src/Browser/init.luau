--!strict
-- Wayline owns browser content only. Rendering and window engines are optional adapters.
local Model=require(script.Model)
local Signal=require(script.Signal)
local Lifetime=require(script.Lifetime)
local Gui=require(script.Gui)
local Input=require(script.Input)
local Theme=require(script.Theme)
local Controls=require(script.Controls)
local Overlay=require(script.Overlay)
local Registry=require(script.Registry)
local Address=require(script.Address)
local SharedData=require(script.SharedData)
local Session=require(script.Session)
local PersistenceClient=require(script.Persistence.Client)
local Pages=require(script.Pages)
local ErrorPage=require(script.Pages.Error)
local View=require(script.View)
local Browser={};Browser.__index=Browser
Browser.SharedData=SharedData;Browser.PersistenceClient=PersistenceClient
local function nativeError(address,message,retry)
	return {URL='wayline://error',Kind='error',Route='error',Title='Page unavailable',Icon='warning',Error={Title='This page is unavailable',Message=message,Address=address,Retry=retry==true}}
end
function Browser.mount(parentFrame,options)
	assert(parentFrame and parentFrame:IsA('GuiObject'),'Wayline needs a host content Frame')
	options=options or{};local services=options.Services or{}
	local hostSession=if options.Session then Session.Validate(options.Session,false)else nil
	local self=setmetatable({Alive=true,Focused=options.Focused~=false,Shown=options.Visible~=false,ExplicitSession=hostSession~=nil,Options=options,Services=services,Scope=Lifetime.new(),Signals={},Work={},Prepared=setmetatable({},{__mode='k'}),Surfaces=setmetatable({},{__mode='k'}),InteractionGeneration=0,Resizing=false,Restoring=false,Task=services.Task or task},Browser)
	for _,name in {'Navigate','StartPage','Close','Select','Cancel','Resize','Surface','Destroy','Persistence','Capture','Changed'}do self.Signals[name]=Signal.new()end
	self.Registry=Registry.new(Pages)
	self.Registry:Register({Route='error',Address='wayline://error',Title='Page unavailable',Icon='warning',Hidden=true,Render=ErrorPage.Render})
	for _,definition in options.Pages or{}do self.Registry:Register(definition)end
	for _,definition in options.ExternalPages or{}do local item=table.clone(definition);item.Kind='external';self.Registry:Register(item)end
	self.Address=Address.new(self.Registry,options.ResolveExternal)
	local addressResolver=self.Address
	self.OwnShared=options.SharedData==nil
	self.Shared=options.SharedData or SharedData.new(options.SharedSnapshot,{NormalizeAddress=function(text)return addressResolver:Resolve(text)end})
	self.Shared.NormalizeAddress=function(text)return addressResolver:Resolve(text)end
	self.Model=Model.new(Address.Home,services.Clock,self.Shared)
	self.Theme=Theme.new(self.Shared.Settings,services)
	self.Gui=Gui.new(self.Theme,{Create=services.Create,IconAtlasImage=options.IconAtlasImage,OnCreate=function(object)
		if not object:IsA('GuiObject')then return end
		local name=object.Name
		if name~='Wayline'and name~='BrowserContent'and name~='WaylineOverlays'and name~='ScrollTrack'and not name:match('^PageContent_')then
			object:SetAttribute('HTMLInputBlocker',true);self.Surfaces[object]=true;self.Signals.Surface:Fire(object)
		end
	end})
	self.View=View.new(self,self.Gui,parentFrame,options,self.Scope)
	self.Window,self.Chrome=self.View.Window,self.View.Chrome
	self.Input=Input.new(self.Window,{Services=services,CanReceivePointer=options.CanReceivePointer,CursorSurface=function(object)return self.Surfaces[object]==true end,MouseDragThreshold=options.MouseDragThreshold,TouchDragThreshold=options.TouchDragThreshold})
	self:_ApplyInputState()
	self.Overlays=Overlay.new(self.Gui,self.Input,self.Theme,self.View.OverlayRoot,{Task=self.Task,Touch=self.View.Touch,InputService=services.Input or services.UserInputService})
	self.Scope:Add(self.Input:OnPointerDown(function()self.InteractionGeneration+=1 end))
	self.View:Attach()
	self.Scope:Add(self.Shared.Changed:Connect(function(kind)
		if not self.Alive then return end
		if kind=='Settings'or kind=='Replace'then self.Theme:Set(self.Shared.Settings.Theme,self.Shared.Settings.Accent)end
		self:_Changed()
	end))
	self.Scope:Add(self.Window.Destroying:Connect(function()self:Destroy(true)end))
	self.Persistence=options.Persistence
	-- Browser data stays in memory unless a host explicitly installs persistence.
	if not self.Persistence and options.PersistenceEnabled==true then self.Persistence=PersistenceClient.new();self.OwnPersistence=true end
	if self.Persistence then
		self.Scope:Add(self.Persistence.Changed:Connect(function(status)self.Signals.Persistence:Fire(status.Message)end))
		self.Scope:Add(self.Persistence:Attach(self.Shared,function(snapshot)
			if not self.Alive or options.PersistSession==false or self.ExplicitSession or self.InteractionGeneration>0 then return end
			self:RestoreSession(snapshot,true)
		end))
	end
	if hostSession then self:RestoreSession(hostSession,false)
	elseif options.AutoOpen~=false then self:Open(Address.Home,{Source='restore'})end
	self.Window.Visible=self.Shown;self:_Changed()
	return self
end
Browser.new=Browser.mount
function Browser:ControlsFor(scope)return Controls.new(self.Gui,self.Input,self.Theme,scope,self.Overlays)end
function Browser:_ApplyInputState()
	if self.Input then self.Input:SetActive(self.Alive and self.Shown and self.Focused and not self.View.TooSmall)end
end
function Browser:_Changed()if self.Alive and self.View then self.View:Update(self.Model);self.Signals.Changed:Fire(self.Model.Active)end end
function Browser:_CaptureNative()
	self.Signals.Capture:Fire()
	local native=self.Native
	if not native then return end
	local entry=native.Entry
	if entry then
		local ok,state=pcall(function()return if native.Page and native.Page.Capture then native.Page:Capture()else native.State end)
		if ok then entry.State=Session.Clone(state or native.State)end
	end
end
function Browser:_DropNative()
	local native=self.Native;if not native then return end
	self:_CaptureNative();self.Native=nil;native.Scope:Destroy()
end
function Browser:_RenderNative(tab,resolution,state)
	if not self.Alive or tab~=self.Model.Active then return true end
	self:_DropNative()
	local scope=self.Scope:Child();local root=self.Gui:Make('Frame',tab.Content,{Name='NativePage',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants=true});scope:Add(root)
	state=Session.Clone(state)or{}
	if resolution.Error then state.Error=if type(resolution.Error)=='table'then resolution.Error else {Message=resolution.Error,Address=resolution.URL}end
	local definition=resolution.Definition or self.Registry:Get(resolution.Route)
	if not definition then definition=self.Registry:Get('error');state.Error={Message='This saved page is no longer registered. Return Home to choose another page.',Address=tab.URL}end
	local native={Tab=tab,Entry=tab.History[tab.HistoryIndex],Scope=scope,State=state,Resolution=resolution};self.Native=native
	local generation=tab.Generation
	local context={Browser=self,Shared=self.Shared,Registry=self.Registry,Address=self.Address,Gui=self.Gui,Controls=self:ControlsFor(scope),Input=self.Input,Theme=self.Theme,Overlays=self.Overlays,Scope=scope,Root=root,State=state,Query=resolution.Query or{},URL=resolution.URL,Prepared=resolution.Prepared,Generation=generation,
		IsCancelled=function()return not self.Alive or not tab.Alive or tab.Generation~=generation or self.Native~=native end,
		Navigate=function(address)self:Navigate(address)end,Refresh=function()if self.Alive and self.Native==native then self:_CaptureNative();self:_RenderNative(tab,resolution,tab.History[tab.HistoryIndex].State)end end}
	local prepared=self.Prepared[native.Entry]
	context.Prepared=if resolution.Prepared~=nil then resolution.Prepared else prepared and prepared.Value
	local ok,page=pcall(definition.Render,context)
	if not self.Alive or self.Native~=native or not tab.Alive or tab.Generation~=generation then
		if ok and page and page.Destroy then pcall(function()page:Destroy()end)end
		scope:Destroy();return false
	end
	if not ok then
		warn('Wayline page preparation: '..tostring(page));scope:Destroy();self.Native=nil
		if resolution.Route~='error'then
			local failure=nativeError(resolution.URL,'This page could not be prepared. You can retry or return Home.',true)
			local entry=tab.History[tab.HistoryIndex];tab.URL=failure.URL;tab.Title=failure.Title;tab.Icon=failure.Icon
			if entry then entry.URL=failure.URL;entry.Title=failure.Title;entry.Icon=failure.Icon;entry.State={Error=failure.Error}end
			self:_RenderNative(tab,failure,{Error=failure.Error})
		end
		return false
	end
	native.Page=page
	if page and page.Destroy then scope:Add(function()page:Destroy()end)end
	return true
end
function Browser:_Resolve(address,tab,allowRelative)
	local result=self.Address:Resolve(address,tab and tab.URL,allowRelative)
	if result.Kind=='error'then return nativeError(address,result.Error or'This address cannot be opened.',false)end
	return result
end
function Browser:_CancelWork(tab)
	local work=self.Work[tab];self.Work[tab]=nil
	if work and work.Thread then pcall(self.Task.cancel,work.Thread)end
end
function Browser:_Dispatch(tab,request)
	if not request then return nil end
	self:_CancelWork(tab)
	local resolution=self:_Resolve(request.URL,tab,request.Source~='address')
	if not self:IsCurrent(tab,request)then return request end
	request.Resolution=resolution
	if self.BeforeNavigate then
		local ok,accepted=pcall(self.BeforeNavigate,tab,request)
		if not ok or not accepted then
			if self:IsCurrent(tab,request)then self:CancelNavigation(tab)end
			if not ok then warn('Browser navigation guard: '..tostring(accepted))end
			return request
		end
	end
	if not self:IsCurrent(tab,request)then return request end
	request.Dispatched=true
	if tab==self.Model.Active then self:_CaptureNative();self.Overlays:Dismiss();self.Input:ReleaseFocus()end
	request.URL=resolution.URL
	self:_Changed()
	if resolution.Kind=='external'then
		local work={};self.Work[tab]=work
		work.Thread=self.Task.defer(function()
			if self.Work[tab]==work then self.Work[tab]=nil end
			if not self:IsCurrent(tab,request)then return end
			if self.Signals.Navigate:Count()==0 then self:FailNavigation(tab,request,'The host has not connected a provider for this page.')
			else self.Signals.Navigate:Fire(tab,request)end
		end)
		return request
	end
	self.Signals.StartPage:Fire(tab,request)
	local function finish()
		if not self:IsCurrent(tab,request)then return end
		local state=if request.Kind=='reload'then{}else request.Entry and request.Entry.State or{}
		local committed=self.Model:Commit(tab,request,{URL=resolution.URL,Title=resolution.Title,Icon=resolution.Icon,State=state,Error=resolution.Kind=='error',Remember=false})
		if committed then self.Prepared[tab.History[tab.HistoryIndex]]={Value=resolution.Prepared};local rendered=self:_RenderNative(tab,resolution,state);self.Model:Remember(tab,{Error=not rendered});self:_Changed();self:_Save()end
	end
	local definition=resolution.Definition or self.Registry:Get(resolution.Route)
	if definition and definition.Prepare then
		local work={};self.Work[tab]=work
		work.Thread=self.Task.spawn(function()
			local ok,result=pcall(definition.Prepare,{URL=resolution.URL,Query=resolution.Query,IsCancelled=function()return not self:IsCurrent(tab,request)end})
			if self.Work[tab]==work then self.Work[tab]=nil end
			if not self:IsCurrent(tab,request)then return end
			if not ok then self:FailNavigation(tab,request,'This page could not be prepared.');return end
			resolution.Prepared=result;finish()
		end)
	else finish()end
	return request
end
-- Each browser owns one document. Reopening an address navigates that document;
-- additional browsing contexts belong to an optional window host.
function Browser:Open(address,intent)
	if not self.Alive then return nil end
	local page=self.Model.Active or self.Model:Open()
	if not page then return nil end
	if not page.Content then self.View:AddPage(page)end
	if self.Model.Active~=page then self:SelectTab(page,true)end
	self:Navigate(page,address or Address.Home,intent or{Source='host'});self:_Changed();return page
end
function Browser:SelectTab(tab,initial)
	if not self.Alive or not self.Model:Contains(tab)then return false end
	if not initial then self.InteractionGeneration+=1 end
	if self.Model.Active~=tab or self.Native and self.Native.Tab~=tab then self:_DropNative();self.Overlays:Dismiss();self.Input:ReleaseFocus()end
	self.Model:Select(tab);self:_Changed();self.Signals.Select:Fire(tab)
	if not tab.Pending and tab.HistoryIndex>0 and(not self.Native or self.Native.Tab~=tab)then
		local result=self:_Resolve(tab.URL,tab)
		if result.Kind~='external'then
			if tab.Restored then self.Model:SetTitle(tab,result.Title,result.Icon);tab.Restored=nil end
			local definition=result.Definition or self.Registry:Get(result.Route)
			if definition and definition.Prepare and self.Prepared[tab.History[tab.HistoryIndex]]==nil then self:_Dispatch(tab,self.Model:Request(tab,tab.URL,{Kind='restore',Source='restore'}))
			else self:_RenderNative(tab,result,tab.History[tab.HistoryIndex].State)end
		elseif tab.Restored then self:_Dispatch(tab,self.Model:Request(tab,tab.URL,{Kind='restore',Source='restore'}))end
	end
	self:_Changed();self:_Save();return true
end
function Browser:CloseTab(tab)
	tab=tab or self.Model.Active
	if not self.Alive or not self.Model:Contains(tab)then return false end
	if self.BeforeCloseTab then
		local ok,accepted=pcall(self.BeforeCloseTab,tab)
		if not ok or not accepted then if not ok then warn('Browser close guard: '..tostring(accepted))end;return false end
	end
	if not self.Alive or not self.Model:Contains(tab)then return false end
	self.InteractionGeneration+=1
	self.Signals.Capture:Fire(tab);self:_CancelWork(tab)
	if self.Native and self.Native.Tab==tab then self:_DropNative()end
	self.Overlays:Dismiss();self.Input:ReleaseFocus()
	self.Input:Cancel()
	if not self.Model:Close(tab)then return false end
	self.Signals.Close:Fire(tab)
	if not self.Alive then return true end
	self.View:RemovePage(tab)
	self:_Changed();self:_Save();return true
end
function Browser:Navigate(first,second,third)
	if not self.Alive then return nil end
	local tab,address,intent
	if type(first)=='table'then tab,address,intent=first,second,third or{}else tab,address,intent=self.Model.Active,first,second or{Source='address'}end
	if not tab then return self:Open(address,intent)end
	if intent.Source~='restore'then self.InteractionGeneration+=1 end
	return self:_Dispatch(tab,self.Model:Request(tab,address or'',intent))
end
function Browser:Back(tab)
	if not self.Alive then return nil end;self.InteractionGeneration+=1
	return self:_Dispatch(tab or self.Model.Active,self.Model:Traversal(tab or self.Model.Active,-1))
end
function Browser:Forward(tab)
	if not self.Alive then return nil end;self.InteractionGeneration+=1
	return self:_Dispatch(tab or self.Model.Active,self.Model:Traversal(tab or self.Model.Active,1))
end
function Browser:Reload(tab)
	tab=tab or self.Model.Active;if not self.Alive or not self.Model:Contains(tab)then return nil end
	return self:Navigate(tab,tab.URL,{Kind='reload',Source='toolbar'})
end
function Browser:CanGoBack()return self.Model:CanBack(self.Model.Active)end
function Browser:IsCurrent(tab,request)return self.Alive and self.Model:IsCurrent(tab,request)end
function Browser:IsStartPage(url)local result=self.Address:Resolve(url);return result.Kind=='internal'end
function Browser:CompleteNavigation(tab,request,metadata)
	if not self:IsCurrent(tab,request)then return false end
	local result=self.Model:Commit(tab,request,metadata or{});if result then
		if self.Native and self.Native.Tab==tab then self:_DropNative()end
		self:_Changed();self:_Save()
	end;return result
end
function Browser:FailNavigation(tab,request,message,options)
	if not self:IsCurrent(tab,request)then return false end
	warn('Wayline content provider: '..tostring(message))
	if options and options.RetainDocument and tab.HistoryIndex>0 then
		self.Model:Fail(tab,request,message);self:_CancelWork(tab);self.Signals.Cancel:Fire(tab)
		self.Overlays:Notice('This page could not be opened. The previous page is still available.')
		self:_Changed();return true
	end
	local resolution=nativeError(request.URL,'This page could not be opened. The host content provider may be unavailable.',true)
	self.Signals.StartPage:Fire(tab,request)
	self.Model:Commit(tab,request,{URL=resolution.URL,Title=resolution.Title,State={Error=resolution.Error},Error=true})
	self:_RenderNative(tab,resolution,{Error=resolution.Error});self:_Changed();return true
end
function Browser:CancelNavigation(tab)
	tab=tab or self.Model.Active;if not self.Alive or not self.Model:Cancel(tab)then return false end
	self:_CancelWork(tab)
	self.Signals.Cancel:Fire(tab)
	if tab.HistoryIndex>0 then self:SelectTab(tab,true)else self:Navigate(tab,Address.Home,{Source='restore'})end
	self:_Changed();return true
end
function Browser:SetTitle(tab,title,icon)if self.Alive and self.Model:SetTitle(tab,title,icon)then self:_Changed()end end
function Browser:SetLocation(tab,url,kind)if not self.Alive then return end;self.Signals.Capture:Fire(tab);if self.Model:SetLocation(tab,url,kind)then self:_Changed();self:_Save()end end
function Browser:GetTabs()return table.clone(self.Model.Tabs)end
function Browser:GetPage()return self.Model.Active end
function Browser:GetActiveTab()return self.Model.Active end
function Browser:IsResizing()return self.Resizing end
function Browser:SetResizing(value)if self.Alive and self.Resizing~=value then self.Resizing=value;self.Signals.Resize:Fire(value)end end
function Browser:SetFocused(value)
	if not self.Alive then return end;self.Focused=value==true
	if not self.Focused then self.Overlays:Dismiss()end
	self:_ApplyInputState()
end
Browser.SetInputActive=Browser.SetFocused
function Browser:SetVisible(value)
	if not self.Alive then return end;self.Shown=value==true
	if not self.Shown then self:_CaptureNative();self.Overlays:Dismiss();self.Input:Cancel();self.Input:ReleaseFocus()end
	self.Window.Visible=self.Shown;self:_ApplyInputState()
end
function Browser:SetFullscreen(value)if self.Alive then self.Overlays:Dismiss();self.View:SetFullscreen(value==true)end end
function Browser:SetNavigationVisible(value)
	if not self.Alive then return end
	self.Input:Cancel();self.Overlays:Dismiss();self.View:SetNavigationVisible(value~=false)
end
function Browser:SetDesktopHeaderInset(value)
	if not self.Alive then return end
	value=math.max(0,math.round(value or 0))
	if self.View.DesktopHeaderInset==value then return end
	self.Input:Cancel();self.Overlays:Dismiss();self.View.DesktopHeaderInset=value
end
function Browser:ConsumesInput(event)return self.Input:Consumes(event)end
function Browser:ToggleBookmark()
	local tab=self.Model.Active;if not tab or tab.Loading then return end
	local existing=self.Shared:FindBookmark(tab.URL)
	if existing then self.Shared:DeleteItem(existing.ID)
	else local value,message=self.Shared:AddBookmark(tab.Title,tab.URL);if not value then self.Overlays:Notice(message)end end
end
function Browser:Suggestions(text)
	local query=text:lower();local result,byAddress={},{}
	local function add(title,address,icon,extra)
		local lower=title:lower();local raw=address:lower();local score=if lower==query or raw==query then 100 elseif lower:sub(1,#query)==query or raw:sub(1,#query)==query then 60 elseif lower:find(query,1,true)or raw:find(query,1,true)then 30 else 0
		if score==0 then return end
		score+=extra or 0;local old=byAddress[address]
		if old and old.Score>=score then return end
		local item={Title=title,Address=address,Icon=icon or'page',Score=score};byAddress[address]=item
	end
	for _,entry in self.Registry:List()do add(entry.Title,entry.Address,entry.Icon,0)end
	for _,entry in self.Shared.Bookmarks do if entry.Kind=='bookmark'then add(entry.Title,entry.Address,'bookmark',5)end end
	for index,entry in self.Shared.History do add(entry.Title,entry.Address,'history',math.max(0,3-index/500))end
	for _,entry in byAddress do table.insert(result,entry)end
	table.sort(result,function(a,b)if a.Score~=b.Score then return a.Score>b.Score end;return a.Title<b.Title end)
	while #result>8 do table.remove(result)end;return result
end
function Browser:_Save(includeSession)
	if not self.Persistence or not self.Alive then return end
	local session=if includeSession~=false and self.Options.PersistSession~=false and(self.Persistence.Loaded or self.InteractionGeneration>0)then self.Model:ExportServerSession()else nil
	self.Persistence:Update(self.Shared:Export(),session)
end
function Browser:ExportSession()self:_CaptureNative();return self.Model:ExportSession()end
function Browser:RestoreSession(snapshot,serverOnly)
	if not self.Alive then return false end
	local safe,message=Session.Validate(snapshot,serverOnly);if not safe then return false,message end
	self.Restoring=true;self:_DropNative();self.Overlays:Dismiss();self.Input:ReleaseFocus()
	for _,tab in table.clone(self.Model.Tabs)do self:_CancelWork(tab);self.Signals.Close:Fire(tab);self.View:RemovePage(tab)end
	local ok=self.Model:ImportSession(safe,serverOnly)
	for _,tab in self.Model.Tabs do
		local resolution=self:_Resolve(tab.URL,tab)
		if resolution.Kind~='external'then self.Model:SetTitle(tab,resolution.Title,resolution.Icon)end
		self.View:AddPage(tab)
	end
	self.Restoring=false
	if ok then self:SelectTab(self.Model.Active,true);self:_Changed()end
	return ok
end
function Browser:GetPersistenceStatus()
	return if self.Persistence then self.Persistence.Status.Message else 'Changes are kept only for this play session.'
end
function Browser:OnPersistenceStatus(fn)return self.Signals.Persistence:Connect(fn)end
function Browser:RegisterPage(definition)local result=self.Registry:Register(definition);self:_Changed();return result end
function Browser:OnNavigate(fn)return self.Signals.Navigate:Connect(fn)end
function Browser:OnCapture(fn)return self.Signals.Capture:Connect(fn)end
function Browser:OnChanged(fn)return self.Signals.Changed:Connect(fn)end
function Browser:OnStartPage(fn)return self.Signals.StartPage:Connect(fn)end
function Browser:OnCloseTab(fn)return self.Signals.Close:Connect(fn)end
function Browser:OnSelectTab(fn)return self.Signals.Select:Connect(fn)end
function Browser:OnCancelNavigation(fn)return self.Signals.Cancel:Connect(fn)end
function Browser:OnResize(fn)return self.Signals.Resize:Connect(fn)end
function Browser:OnDestroy(fn)return self.Signals.Destroy:Connect(fn)end
function Browser:OnChromeSurface(fn)
	local connection=self.Signals.Surface:Connect(fn)
	for object in self.Surfaces do if object.Parent then fn(object)end end;return connection
end
function Browser:Destroy(external)
	if not self.Alive then return end
	self:_CaptureNative();self:_Save();self.Alive=false
	for tab in self.Work do self:_CancelWork(tab)end
	self.Signals.Destroy:Fire();self.Input:Destroy();self.Overlays:Destroy();self:_DropNative();self.Scope:Destroy()
	self.Model:Destroy();self.View:Destroy();self.Theme:Destroy()
	if self.OwnPersistence and self.Persistence then self.Persistence:Destroy()end
	if self.OwnShared then self.Shared:Destroy()end
	for _,signal in self.Signals do signal:Destroy()end;table.clear(self.Signals);table.clear(self.Surfaces)
end
return Browser
