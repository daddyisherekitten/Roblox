--!strict
-- Optional browser/window/HTML integration. The LocalScript supplies dependencies.
local Host={}
function Host.new(manager,Browser,Binding,engine,options)
	options=options or{};local services=options.Services or{};local tasks=services.Task or task
	local self={Alive=true,Windows={},Contexts={},Names={},Connections={}}
	local permissionStore=options.PermissionStore or{}
	local externalPages={};local externalByAddress={}
	for _,name in engine.Websites.names()do
		local address=engine.Websites.url(name)
		local page=if type(engine.Websites.get)=='function'then engine.Websites.get(name)else nil
		local definition={Route='catalog-'..name:lower(),Address=address,Title=if page then page.Name or name else name,Icon='page',Description='A page provided by the HTML engine.',Keywords={name,'html'}}
		if not page or not page.CatalogHidden then table.insert(externalPages,definition)end
		externalByAddress[address:gsub('[?#].*$','')]=definition
	end
	local externalBase=options.BaseURL or(if options.HomeWebsite and options.HomeWebsite~=''then engine.Websites.url(options.HomeWebsite)else 'http://localhost:8000/')
	local function resolveExternal(address,base)
		if address=='about:blank'then return {Kind='external',URL=address,Title='Blank page',Icon='page'}end
		local resolved=engine.Websites.resolveURL(if base and base:match('^https?://')then base else externalBase,address)
		if resolved.Kind~='internal'and resolved.Kind~='missing'then return nil end
		local definition=externalByAddress[resolved.URL:gsub('[?#].*$','')]
		return {Kind='external',URL=resolved.URL,Title=if definition then definition.Title else 'Page not found',Icon='page',Definition=definition}
	end
	self.Shared=options.SharedData or Browser.SharedData.new(options.SharedSnapshot)
	self.OwnShared=options.SharedData==nil
	self.Persistence=options.Persistence
	if not self.Persistence and options.PersistenceEnabled==true then self.Persistence=Browser.PersistenceClient.new();self.OwnPersistence=true end
	local input=services.Input or services.UserInputService or game:GetService('UserInputService')
	local desktopInset=if input.TouchEnabled and not input.MouseEnabled then 0 else options.DesktopHeaderInset or 0
	local function inputState()
		for window,record in self.Windows do
			local visible=window.State~='minimized';local active=manager:GetFocused()==window and visible and window:IsInputEnabled()
			if record.Browser then
				local inset=if window.State=='maximized' then desktopInset else 0
				window:SetTitleInset(inset);record.Browser:SetDesktopHeaderInset(inset)
				record.Browser:SetFocused(active);record.Browser:SetVisible(visible)
			end
			if record.Binding then record.Binding:SetInputActive(active);record.Binding:SetVisible(visible)end
		end
	end
	local function closed(context)return context.Closed==true or not self.Alive or not context.Tab.Alive or not context.Record.Window.Alive end
	local function forget(context)
		if context.Name~=''and self.Names[context.Name]==context then self.Names[context.Name]=nil end
		if context.Tab then self.Contexts[context.Tab]=nil end
		-- A retained JS handle needs only closed/name after close, not the GUI graph.
		context.Closed=true;context.Closing=false;context.CloseRequest=nil;context.Tab=nil;context.Record=nil
	end
	local function context(record,tab,scriptOpened,name)
		local existing=self.Contexts[tab];if existing then return existing end
		local value={Record=record,Tab=tab,ScriptOpened=scriptOpened==true,Name=name or ''}
		self.Contexts[tab]=value;if value.Name~=''then self.Names[value.Name]=value end;return value
	end
	local function closeContext(value)
		if closed(value)or not value.ScriptOpened or value.Closing then return end
		-- Closing is observable before the native task; physical liveness stays
		-- separate so author microtasks and the deferred guard retain the realm.
		local request={};value.CloseRequest=request;value.Closing=true
		local scheduled,message=pcall(tasks.defer,function()
			if value.CloseRequest~=request or closed(value)then return end
			local record=value.Record
			local ok,accepted=pcall(function()return record.Window:RequestClose()end)
			if value.CloseRequest==request then
				value.CloseRequest=nil
				-- Host profile: an actual Stay/failed guard permits a later retry.
				-- Native Chrome confirms this; frozen HTML lacks an explicit reset.
				if not closed(value)and(not ok or accepted~=true)then value.Closing=false end
			end
			if not ok then error(accepted,0)end
		end)
		if not scheduled then
			if value.CloseRequest==request then value.CloseRequest=nil;value.Closing=false end
			error(message,0)
		end
	end
	local function pageFor(value)return if closed(value)then nil else value.Record.Binding:GetPage(value.Tab)end
	local function commitInitialBlank(record,tab)
		-- A new context already owns its initial blank document. Finish only
		-- the tab's URL/history request; its queued provider must not replace
		-- synchronous author writes with another about:blank document.
		local request=tab.Pending
		if request and request.URL=='about:blank'then
			record.Browser:CompleteNavigation(tab,request,{URL='about:blank',Title='Blank page',Icon='page'})
		end
	end
	local function originFor(value)
		local page=pageFor(value);return if page then page.DocumentOrigin else value.InheritedOrigin
	end
	local function setName(value,name)
		if closed(value)then return end
		if self.Names[value.Name]==value then self.Names[value.Name]=nil end
		value.Name=name;if name~=''then self.Names[name]=value end;if value.Handle then value.Handle.Name=name end
	end
	local function metrics(value,key)
		if closed(value)then return 0 end
		local root=value.Record.Window.Root;local p,s=root.AbsolutePosition,root.AbsoluteSize
		local map={outerWidth=s.X,outerHeight=s.Y,screenX=p.X,screenLeft=p.X,screenY=p.Y,screenTop=p.Y}
		if map[key]~=nil then return map[key]end
		local page=pageFor(value);local viewport=page and page.GeometryViewport and page:GeometryViewport()
		if key=='innerWidth'then return viewport and viewport.Width elseif key=='innerHeight'then return viewport and viewport.Height end
		return nil
	end
	local function handle(value,isSelf)
		if not value.Handle then value.Handle={Name=value.Name,IsClosed=function()return value.Closing==true or closed(value)end,IsDiscarded=function()return closed(value)end,
			close=function()closeContext(value)end,focus=function()if not closed(value)then value.Record.Window:Focus();value.Record.Browser:SelectTab(value.Tab)end end,
			blur=function()end,GetRealm=function()local page=pageFor(value);return page and page.JavaScriptRuntime end,
			CanAccess=function(origin)return not closed(value)and origin~=nil and origin==originFor(value)end,
			SetName=function(name)setName(value,name)end,Metrics=function(key)return metrics(value,key)end,
			Geometry=function(kind,a,b)
				if closed(value)or not value.ScriptOpened then return end
				local window=value.Record.Window;if window.Fullscreen then return end
				if window.State~='normal'then window:Restore()end
				local p,s=window:GetPosition(),window:GetSize()
				if kind=='moveTo'then window:SetPosition(Vector2.new(a,b))elseif kind=='moveBy'then window:SetPosition(Vector2.new(p.X+a,p.Y+b))
				elseif kind=='resizeTo'then window:SetSize(Vector2.new(a,b))elseif kind=='resizeBy'then window:SetSize(Vector2.new(s.X+a,s.Y+b))end
			end,
			Navigate=function(url,kind,base)
				if closed(value)then return end
				local destination=if kind=='reload'then nil else engine.URL.resolve(base or value.Tab.URL,url).URL
				tasks.defer(function()if not closed(value)then if kind=='reload'then value.Record.Browser:Reload(value.Tab)
					else value.Record.Browser:Navigate(value.Tab,destination,{Kind=if kind=='replace'then 'replace'else 'assign',Source='window-location'})end end end)
			end,
			ClearOpener=function()value.Opener=nil end,
			GetOpener=function()return if value.Opener then handle(value.Opener,false)else nil end}end
		return if isSelf then {Self=true}else value.Handle
	end
	local openBrowser,openTarget
	local function windowHost(record,tab,session)
		local own=context(record,tab,false)
		local function live()return self.Alive and session.Alive and tab.Alive and record.Window.Alive end
		return {
			SetFullscreen=function(enabled)
				if not live()then return false end
				record.Window:SetFullscreen(enabled);record.Browser:SetFullscreen(enabled);return true
			end,
			SubscribeFullscreenExit=function(callback)return manager.FullscreenChanged:Connect(function(window,enabled)if window==record.Window and not enabled then callback()end end)end,
			GetSelfHandle=function()return handle(own,false)end,
			GetOpener=function()return if own.Opener then handle(own.Opener,false)else nil end,
			ClearOpener=function()own.Opener=nil end,
			DocumentOrigin=if session.URL=='about:blank'then own.InheritedOrigin else nil,
			Metrics=function(key)return metrics(own,key)end,
			ScreenMetrics=function(key)
				local area=manager:GetWorkArea()
				return if key=='width'or key=='availWidth'then area.X elseif key=='height'or key=='availHeight'then area.Y else nil
			end,
			Open=function(request)
				if not live()then return nil end
				local base=if session.Page then session.Page.BaseURL or session.URL else session.URL
				return openTarget(own,base,request)
			end,
			close=function()if live()then closeContext(own)end end,
			focus=function()if live()then record.Window:Focus();record.Browser:SelectTab(tab)end end,
			blur=function()end,IsClosed=function()return own.Closing==true or closed(own)end,IsDiscarded=function()return closed(own)end,
			GetName=function()return own.Name end,
			SetName=function(name)if live()then setName(own,name)end end,
		}
	end
	openBrowser=function(url,settings,scriptOpened,name,opener)
		if not self.Alive or not manager.Alive or #manager:GetWindows()>=(options.MaxWindows or 16)then return nil end
		settings=table.clone(settings or{});settings.Title=settings.Title or'Wayline';settings.MinSize=Vector2.new(480,392)
		local window=manager:Open(settings)
		local primary=not settings.Popup and self.Primary==nil
		local record={Window=window,Connections={},ScriptOpened=scriptOpened==true,Primary=primary};self.Windows[window]=record
		if primary then self.Primary=record end
		local ok,message=pcall(function()
			record.Browser=Browser.mount(window.Content,{AutoOpen=false,ShowNavigation=not settings.Popup or options.ShowPopupNavigation==true,IconAtlasImage=options.IconAtlasImage,Services=services,
				SharedData=self.Shared,Persistence=self.Persistence,PersistenceEnabled=false,PersistSession=primary and options.PersistSession~=false,
				Session=if primary and not url then self.LastSession or options.Session else nil,
				Pages=options.Pages,ExternalPages=externalPages,ExternalBaseURL=externalBase,ResolveExternal=resolveExternal,
				CanReceivePointer=function(position)return window.Alive and window.State~='minimized'and manager:CanReceivePointer(window,position)end})
			record.Browser:SetResizing(window.Root:GetAttribute('HTMLViewportResizing')==true)
			record.Binding=Binding.new(record.Browser,engine,{Services=services,StorageHost=options.StorageHost,PermissionStore=permissionStore,MediaCaptureHost=options.MediaCaptureHost,WebLockStore=options.WebLockStore,WebLockPartitionKey=options.WebLockPartitionKey,Diagnostic=options.Diagnostic,
				BaseURL=externalBase,
				ConsumesInput=function(event)return manager:ConsumesInput(event)end,
				WindowHost=function(tab,session)return windowHost(record,tab,session)end,
				PageMounted=options.PageMounted,PageReady=function(tab,page)
					if record.Browser:GetActiveTab()==tab then window:SetTitle(page.Title or tab.URL)end
					if options.PageReady then options.PageReady(tab,page)end
				end})
			window:SetCloseGuard(function()return record.Binding:RequestClose()end)
			record.Connections[1]=window:OnClose(function()
				if record.Primary then self.LastSession=record.Browser:ExportSession();self.Primary=nil end
				self.Windows[window]=nil
				for _,tab in record.Browser:GetTabs()do local value=self.Contexts[tab];if value then forget(value)end end
				for _,connection in record.Connections do connection:Disconnect()end;table.clear(record.Connections)
				record.Binding:Destroy();record.Browser:Destroy()
			end)
			record.Connections[2]=record.Browser:OnCloseTab(function(tab)
				local value=self.Contexts[tab];if value then forget(value)end
				if #record.Browser:GetTabs()==0 and window.Alive then window:Close()end
			end)
			record.Connections[3]=record.Browser:OnChanged(function(tab)if tab then window:SetTitle((tab.Title or'Home')..' - Wayline')end end)
			record.Connections[4]=record.Browser:OnDestroy(function()if window.Alive then window:Close()end end)
			local tab=record.Browser:GetActiveTab()
			if url or not tab then tab=record.Browser:Open(url or'wayline://home',{Source=if scriptOpened then 'window-open'elseif url then 'host'else 'restore'})end
			assert(tab,'Wayline could not open the initial document')
			local value=context(record,tab,scriptOpened,name)
			value.Opener=opener;value.InheritedOrigin=if opener then originFor(opener)else {}
			if scriptOpened and url=='about:blank'then commitInitialBlank(record,tab)end
			if scriptOpened and not record.Browser:IsStartPage(url or'wayline://home')and record.Binding.EnsureInitialDocument then record.Binding:EnsureInitialDocument(tab,value.InheritedOrigin)end
		end)
		if not ok then
			self.Windows[window]=nil
			if self.Primary==record then self.Primary=nil end
			if record.Binding then record.Binding:Destroy()end;if record.Browser then record.Browser:Destroy()end
			for _,connection in record.Connections do connection:Disconnect()end
			window:Close();error(message)
		end
		inputState();return record
	end
	openTarget=function(own,base,request)
		local features=request.Features or{};local target=request.Target or '_blank';local lower=target:lower()
		local url=if request.URL==''or request.URL==nil then 'about:blank'else engine.URL.resolve(base,request.URL).URL
		-- The current adapter supports local catalog documents only.
		if url~='about:blank'and not own.Record.Browser:IsStartPage(url)then
			local resolved=engine.Websites.resolveURL(base,url);if resolved.Kind=='external'then return nil end
		end
		local value
		if lower=='_self'or lower=='_parent'or lower=='_top'then value=own
		elseif not features.NoOpener and lower~='_blank'then value=self.Names[target];if value and closed(value)then forget(value);value=nil end end
		if value then
			if request.URL and request.URL~=''then tasks.defer(function()if not closed(value)then value.Record.Browser:Navigate(value.Tab,url,{Source='window-open'})end end)end
			value.Record.Window:Focus();value.Record.Browser:SelectTab(value.Tab);return handle(value,value==own)
		end
		local name=if lower=='_blank'or features.NoOpener then ''else target
		local size=Vector2.new(math.max(480,features.Width or 640),math.max(360,features.Height or 400))
		-- Every auxiliary browsing context owns a window. Features describe
		-- document content; add the native titlebar and address toolbar.
		local record=openBrowser(url,{Title='Wayline',Popup=features.Popup==true,Size=Vector2.new(size.X,size.Y+88),
			Position=if features.Left~=nil or features.Top~=nil then Vector2.new(features.Left or 0,features.Top or 0)else nil},true,name,if features.NoOpener then nil else own)
		if not record then return nil end;value=self.Contexts[record.Browser:GetActiveTab()]
		return handle(value,false)
	end
	self.Connections[1]=manager.FocusChanged:Connect(inputState)
	self.Connections[2]=manager.VisibilityChanged:Connect(inputState)
	self.Connections[3]=manager.Resizing:Connect(function(window,active)local record=self.Windows[window];if record and record.Browser then record.Browser:SetResizing(active)end end)
	function self:Open(url,settings)return openBrowser(url,settings,false,'')end
	function self:Destroy()
		if not self.Alive then return end;self.Alive=false
		for _,connection in self.Connections do connection:Disconnect()end;table.clear(self.Connections)
		local list={};for window in self.Windows do table.insert(list,window)end;for _,window in list do window:Close()end
		table.clear(self.Contexts);table.clear(self.Names)
		if self.OwnPersistence and self.Persistence then self.Persistence:Destroy()end
		if self.OwnShared then self.Shared:Destroy()end
	end
	return self
end
return Host
