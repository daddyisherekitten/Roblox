--!strict
-- Optional browser/HTML integration using supplied public APIs; no engine import.
local InputScope=require(script.InputScope)
local Binding={}
function Binding.new(browser,engine,options)
	options=options or{};local services=options.Services or{}
	local tasks=services.Task or task
	local create=services.Create or function(class,parent,props)
		local object=Instance.new(class);for key,value in props do object[key]=value end;object.Parent=parent;return object
	end
	local input=services.Input or game:GetService('UserInputService')
	local run=services.RunService or game:GetService('RunService')
	local self={Alive=true,InputActive=true,Shown=true,Owners={},Connections={}}
	local permissionStore=options.PermissionStore or{}
	local nextDocumentID=0
	local function inputScope(session)
		return InputScope.new(input,run,function(event)
			return browser:ConsumesInput(event)or options.ConsumesInput and options.ConsumesInput(event)
		end,function(event,paired)
			if browser.Input and browser.Input.Modal then return false end
			if options.ConsumesInput and options.ConsumesInput(event)then return false end
			local page=session.Page
			-- The shell consumes native field typing. Only this document's exact
			-- copy proxy passes through, retaining keyup after Tab/modifier blur.
			return paired or page and page.OwnsSelectionCopyEditor and page:OwnsSelectionCopyEditor(input:GetFocusedTextBox())or false
		end)
	end
	local externalBase=options.BaseURL or browser.Options and browser.Options.ExternalBaseURL or 'http://localhost:8000/'
	local function diagnostic(message)if options.Diagnostic then options.Diagnostic(message)else warn('Browser: '..tostring(message))end end
	local function notify(callback,...)
		if not callback then return end
		local ok,message=pcall(callback,...);if not ok then diagnostic(message)end
	end
	local function current(tab,session)
		local owner=self.Owners[tab]
		return self.Alive and owner and owner.Current==session and not owner.Pending and tab.Alive
	end
	local function release(session)
		if not session or not session.Alive then return end;session.Alive=false
		local page=session.Page
		local realm=session.Runtime or page and page.JavaScriptRuntime;session.Runtime=nil
		local executing=if page and page.HasExecutingScripts then page:HasExecutingScripts()else realm and realm.IsExecuting and realm:IsExecuting()
		-- A forced host teardown must retire suspended author stacks before its
		-- dialog is dismissed. Entering unload would cancel and resume them.
		if session.Committed and not executing then
			if page and page.CommitLeave then notify(function()page:CommitLeave()end)
			elseif realm and realm.CommitLeave then notify(function()realm:CommitLeave()end)end
		end
		if realm then notify(function()realm:Destroy()end)end
		if page then notify(function()page:Destroy()end)end
		if session.DialogCancel then local cancel=session.DialogCancel;session.DialogCancel=nil;notify(cancel)end
		for _,connection in session.Connections do notify(function()connection:Disconnect()end)end;table.clear(session.Connections)
		notify(function()session.Scope:Destroy()end)
		session.Page=nil
		if session.Target.Parent then notify(function()session.Target:Destroy()end)end
	end
	local function visible(tab,session,show,documentVisible,interactive)
		if not session or not session.Alive then return end
		local realm=session.Runtime or session.Page and session.Page.JavaScriptRuntime
		local documentShown=if documentVisible==nil then show else documentVisible
		if session.Page and session.Page.SetDocumentVisible then session.Page:SetDocumentVisible(documentShown)
		elseif realm and realm.SetVisible then realm:SetVisible(documentShown)end
		if not session.Page then return end
		if not show and session.Page.JavaScriptRuntime and session.Page.JavaScriptRuntime.Fullscreen and session.Page.JavaScriptRuntime.Fullscreen.Element then session.Page.JavaScriptRuntime.Fullscreen:ExitForHost()end
		if not show then session.Scope:SetActive(false)end
		session.Target.Visible=show;session.Page:SetVisible(show,true)
		session.Scope:SetFrames(show)
		if show then session.Scope:SetActive(self.InputActive and interactive~=false)end
	end
	local function refreshVisibility()
		local active=browser:GetActiveTab()
		for tab,owner in self.Owners do
			-- Keep the committed document painted while its replacement loads.
			-- Only the replacement's ready/presented barrier retires that surface.
			visible(tab,owner.Current,self.Shown and tab==active,self.Shown and tab==active,owner.Pending==nil)
			visible(tab,owner.Pending,false,self.Shown and tab==active)
		end
	end
	local function clearPending(owner)
		local old=owner.Pending;owner.Pending=nil;release(old)
	end
	local function failNavigation(tab,request,message)
		local owner=self.Owners[tab]
		local retained=owner and owner.Current or browser.Native and browser.Native.Tab==tab
		browser:FailNavigation(tab,request,message,{RetainDocument=retained~=nil and retained~=false})
		refreshVisibility()
	end
	local function dialogHost(tab,session)
		local host={}
		function host.Show(request,complete)
			local owner=self.Owners[tab]
			if not self.Alive or not session.Alive or not tab.Alive or not self.Shown or not self.InputActive or browser:GetActiveTab()~=tab or not owner or(owner.Current~=session and owner.Pending~=session)then
				tasks.defer(function()complete(false)end);return function()end
			end
			if session.DialogCancel then session.DialogCancel()end
			local cancel
			cancel=browser.Overlays:ScriptDialog(request,function(accepted,value)
				if session.DialogCancel==cancel then session.DialogCancel=nil end
				complete(accepted,value)
			end)
			session.DialogCancel=cancel
			return function()
				if session.DialogCancel==cancel then session.DialogCancel=nil end
				cancel()
			end
		end
		return host
	end
	local function connectRuntime(tab,session,scriptServices)
		scriptServices.PermissionStore=permissionStore
		if scriptServices.WebLockStore==nil then scriptServices.WebLockStore=options.WebLockStore end
		if scriptServices.WebLockPartitionKey==nil then scriptServices.WebLockPartitionKey=options.WebLockPartitionKey end
		if scriptServices.MediaCaptureHost==nil then scriptServices.MediaCaptureHost=options.MediaCaptureHost end
		scriptServices.SimpleDialogHost=dialogHost(tab,session)
		scriptServices.Visible=self.Shown and browser:GetActiveTab()==tab
		scriptServices.ConfirmLeave=function(request)
			if not session.Alive or not browser.Alive then return false end
			if browser:GetActiveTab()~=tab then browser:SelectTab(tab)end
			local thread=coroutine.running();local waiting=false;local done=false;local accepted=false
			scriptServices.SimpleDialogHost.Show({Kind='confirm',Title='Leave this page?',Message='Changes you made may not be saved.',URL=session.URL,AcceptText='Leave',CancelText='Stay'},function(value)
				if done then return end;done=true;accepted=value==true
				if waiting then tasks.defer(function()if coroutine.status(thread)=='suspended'then local ok,message=coroutine.resume(thread,accepted);if not ok then diagnostic(message)end end end)end
			end)
			if done then return accepted end
			waiting=true;return coroutine.yield()
		end
		local prior=scriptServices.RuntimeCreated
		scriptServices.RuntimeCreated=function(realm,page)
			session.Runtime=realm
			if not session.Alive then
				if page and page.Alive then page:Destroy()else realm:Destroy()end
				return
			end
			if page then session.Page=page;visible(tab,session,false,self.Shown and browser:GetActiveTab()==tab)end
			if prior then prior(realm,page)end
		end
	end
	local function imageIcon(value)
		if type(value)=='number'then
			if value~=value or value<=0 or value>9007199254740991 or value%1~=0 then return nil end
			value=string.format('%.0f',value)
		end
		if type(value)~='string'then return nil end
		local digits=value:match('^rbxassetid://(%d+)$')or value:match('^(%d+)$')
		if not digits then return nil end
		digits=digits:gsub('^0+','');return if digits~=''then 'rbxassetid://'..digits else nil
	end
	local function siteIcon(page,website)
		local configured=options.Icon or website and website.Options and website.Options.BrowserIcon
		local icon=imageIcon(configured)
		if icon then return icon end
		if type(configured)=='string'and configured:match('^[%a][%w_%-]*$')then return configured end
		for _,link in page.DocumentInfo and page.DocumentInfo.Links or{}do
			if not link.Disabled and(' '..link.Rel..' '):find('%sicon%s')and(link.Media==''or link.Media=='all')then
				icon=imageIcon(link.Href)
				if not icon and page.ResolveImage then
					local ok,mapped=pcall(page.ResolveImage,link.Href)
					if ok then icon=imageIcon(mapped)end
					if not icon and link.URL~=link.Href then ok,mapped=pcall(page.ResolveImage,link.URL);if ok then icon=imageIcon(mapped)end end
				end
				if icon then return icon end
			end
		end
		return 'page'
	end
	local function metadata(page,url,website,resolved)
		local icon=siteIcon(page,website)
		local title=page.Root:GetAttribute('Title')or page.Title
		if type(title)~='string'or title==''then title=if url=='about:blank'then 'Blank page'else url end
		return {URL=url,Title=title,Icon=icon,Error=resolved and resolved.Kind=='missing' or false}
	end
	local function capture(tab,session)
		local entry=session and session.Entry
		if entry and session and session.Page then
			local position=session.Page.Root.CanvasPosition
			entry.State={Scroll={X=position.X,Y=position.Y},DocumentID=session.ID}
		end
	end
	local function address(tab,request)
		local url=request.URL
		if request.Source=='address'then
			if url:match('^localhost[:/]')or url:match('^127%.0%.0%.1[:/]')then url='http://'..url
			elseif not url:match('^[%a][%w+%.%-]*:')and url:sub(1,1)~='/'and url:sub(1,1)~='#'and url:sub(1,2)~='./'and url:sub(1,3)~='../'and url:find('%.')and not url:find('%s')then url='https://'..url end
		end
		local base=if tab.URL=='about:blank'or browser:IsStartPage(tab.URL)then externalBase else tab.URL
		return engine.Websites.resolveURL(base,url)
	end
	local function sameDocument(session,request,url)
		if not session or request.Kind=='reload'or request.Data and request.Data.SameDocument==false then return false end
		if session.URL:gsub('#.*$','')~=url:gsub('#.*$','')then return false end
		return url:find('#',1,true)~=nil or request.Data and request.Data.SameDocument==true
			or request.Kind=='traverse'and request.Entry and request.Entry.State and request.Entry.State.DocumentID==session.ID or false
	end
	local function requestLeave(tab,request)
		local owner=self.Owners[tab];local session=owner and owner.Current
		if not session then return true end
		local realm=session and(session.Runtime or session.Page and session.Page.JavaScriptRuntime)
		if not(session.Page and session.Page.RequestLeave)and not(realm and realm.RequestLeave)then return true end
		if request then
			local resolved=request.Resolution
			if not resolved then local ok,value=pcall(address,tab,request);if ok then resolved=value end end
			if resolved and sameDocument(session,request,resolved.URL)then return true end
		end
		local leave={Reason=if not request then 'close'elseif request.Kind=='reload'then 'reload'else 'navigate',URL=request and request.URL}
		if session.Page and session.Page.RequestLeave then return session.Page:RequestLeave(leave)end
		return realm:RequestLeave(leave)
	end
	local navigationGuard=function(tab,request)return requestLeave(tab,request)end
	local closeGuard=function(tab)return requestLeave(tab,nil)end
	browser.BeforeNavigate=navigationGuard;browser.BeforeCloseTab=closeGuard
	function self:RequestClose()
		for _,tab in table.clone(browser:GetTabs())do if not requestLeave(tab,nil)then return false end end
		return self.Alive and browser.Alive
	end
	local function navigationCallbacks(tab,session,mountOptions,windowHost)
		mountOptions.URLChanged=function(url,kind)
			if not current(tab,session)then return end
			capture(tab,session);session.URL=url;browser:SetLocation(tab,url,kind)
			session.Entry=tab.History[tab.HistoryIndex];capture(tab,session)
		end
		mountOptions.Navigate=function(href,node,linkData)
			tasks.defer(function()
				if not current(tab,session)then return end
				linkData=linkData or{}
				if linkData.Download~=nil then diagnostic('Downloads need a separate host provider: '..href);return end
				if node and node.Attributes and node.Attributes['data-history-back']~=nil then browser:Back(tab);return end
				local base=if session.URL=='about:blank'then externalBase else session.URL
				local destination=engine.URL.resolve(base,href)
				local target=linkData.Target or'';local lower=target:lower()
				if windowHost and target~=''and lower~='_self'and lower~='_top'and lower~='_parent'then
					local rel=' '..(node and node.Attributes and node.Attributes.rel or ''):lower()..' '
					windowHost.Open({URL=destination.URL,Target=target,Features={NoOpener=lower=='_blank'and not rel:find(' opener ',1,true)or rel:find(' noopener ',1,true)~=nil or rel:find(' noreferrer ',1,true)~=nil}})
				elseif lower=='_blank'and options.OpenWindow then options.OpenWindow(destination.URL,linkData)
				else browser:Navigate(tab,destination.URL,{Kind=linkData.Kind or'assign',Source='content',Data=linkData})end
			end)
		end
	end
	local function navigation(tab,request)
		if not self.Alive or not browser:IsCurrent(tab,request)then return end
		local owner=self.Owners[tab]or{};self.Owners[tab]=owner
		capture(tab,owner.Current);clearPending(owner)
		local resolved,website
		if request.URL=='about:blank'then resolved={Kind='internal',URL='about:blank',Fragment=''};website={HTML='<!doctype html><html><head><title>Blank page</title></head><body></body></html>',Options={JavaScript=false}}
		else
			local ok,value=pcall(address,tab,request)
			if not ok then failNavigation(tab,request,value);return end
			resolved=value
			if resolved.Kind=='external'then failNavigation(tab,request,'This address is not registered in the local page catalog: '..resolved.URL);return end
			if resolved.Kind=='missing'then resolved.Name='NotFound'end
			local loaded,value=pcall(engine.Websites.get,resolved.Name)
			if not loaded then failNavigation(tab,request,value);return end;website=value
		end
		local previous=owner.Current
		if sameDocument(previous,request,resolved.URL)then
			previous.URL=resolved.URL;previous.Page.Root:SetAttribute('Location',resolved.URL)
			local realm=previous.Page.JavaScriptRuntime
			if realm and realm.Navigation and realm.Navigation:GetURL()~=resolved.URL then
				-- Keep the realm's location coherent with a host address/fragment move.
				-- Full shared History state/traversal is a separate host contract.
				realm.Navigation:CommitNavigation(resolved.URL,request.Kind=='replace'or request.Kind=='traverse')
			elseif not realm then
				previous.Page.DocumentURL=resolved.URL;previous.Page.Document.URL=resolved.URL
				previous.Page.Root:SetAttribute('DocumentURL',resolved.URL)
			end
			previous.Page:ScrollToFragment(resolved.Fragment or'')
			if request.Entry and request.Entry.State and request.Entry.State.Scroll then local scroll=request.Entry.State.Scroll;previous.Page.Root.CanvasPosition=Vector2.new(scroll.X,scroll.Y)end
			if browser:CompleteNavigation(tab,request,metadata(previous.Page,resolved.URL,website,resolved))then
				previous.Entry=tab.History[tab.HistoryIndex];capture(tab,previous)
			end
			refreshVisibility();return
		end
		nextDocumentID+=1
		local target=create('Frame',tab.Content,{Name='HTMLDocument_'..nextDocumentID,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=0,BorderSizePixel=0,Active=false,Selectable=false,Visible=false})
		target:SetAttribute('HTMLViewportResizing',browser:IsResizing())
		local session={ID=nextDocumentID,Alive=true,Target=target,Connections={},URL=resolved.URL,Request=request}
		session.Scope=inputScope(session)
		owner.Pending=session
		refreshVisibility()
		local mountOptions=table.clone(website.Options or{})
		mountOptions.DocumentURL=resolved.URL;mountOptions.StorageHost=options.StorageHost;mountOptions.FallbackWindow=false
		if website.CSS~=nil then mountOptions.CSS=website.CSS end
		if website.Stylesheets~=nil then mountOptions.Stylesheets=website.Stylesheets end
		local controlServices=table.clone(mountOptions.InputServices or{});controlServices.Input=session.Scope.Input;mountOptions.InputServices=controlServices
		controlServices.Task=controlServices.Task or services.Task
		if services.PlayerGui then controlServices.PlayerGui=services.PlayerGui end
		local scriptServices=table.clone(mountOptions.JavaScriptServices or{});scriptServices.RunService=session.Scope.Run;mountOptions.JavaScriptServices=scriptServices
		scriptServices.Task=scriptServices.Task or services.Task;scriptServices.Clock=scriptServices.Clock or services.Clock
		connectRuntime(tab,session,scriptServices)
		local windowHost=if options.WindowHost then options.WindowHost(tab,session)else nil
		if windowHost then
			scriptServices.WindowHost=windowHost
			if windowHost.DocumentOrigin~=nil then mountOptions.DocumentOrigin=windowHost.DocumentOrigin end
			if resolved.URL=='about:blank'then mountOptions.JavaScript=true end
		end
		local animationServices=table.clone(mountOptions.AnimationServices or{});animationServices.RunService=session.Scope.Run;mountOptions.AnimationServices=animationServices
		navigationCallbacks(tab,session,mountOptions,windowHost)
		local function settle()
			if not session.Alive or not browser:IsCurrent(tab,request)then return end
			local page=session.Page;local state=page.Root:GetAttribute('Status')
			if state=='error'then
				local message=page.Root:GetAttribute('Error')or'Page layout failed'
				clearPending(owner);failNavigation(tab,request,message);return
			end
			if state~='ready'or page.Root:GetAttribute('Presented')==false then return end
			owner.Pending=nil;owner.Current=session
			for _,connection in session.ReadyConnections or{}do connection:Disconnect()end;session.ReadyConnections=nil
			if resolved.Kind=='missing'then page.Root:SetAttribute('HTTPStatus',404)end
			page:ScrollToFragment(resolved.Fragment or'')
			if request.Entry and request.Entry.State and request.Entry.State.Scroll then local scroll=request.Entry.State.Scroll;page.Root.CanvasPosition=Vector2.new(scroll.X,scroll.Y)end
			session.Committed=true
			-- Present the completed replacement before callbacks or unload work
			-- can suspend. The previous document still covers the viewport until
			-- this point; input is enabled only after the history commit succeeds.
			visible(tab,session,self.Shown and browser:GetActiveTab()==tab,self.Shown and browser:GetActiveTab()==tab,false)
			if not browser:CompleteNavigation(tab,request,metadata(page,resolved.URL,website,resolved))then session.Committed=false;owner.Current=previous;release(session);refreshVisibility();return end
			session.Entry=tab.History[tab.HistoryIndex];capture(tab,session)
			refreshVisibility();release(previous)
			notify(options.PageReady,tab,page)
		end
		tasks.spawn(function()
			local began=os.clock();local ok,page=pcall(engine.mountHTML,target,website.HTML,mountOptions)
			if not session.Alive or not self.Alive or not browser:IsCurrent(tab,request)then if ok and page then page:Destroy()end;release(session);return end
			if not ok then clearPending(owner);failNavigation(tab,request,page);return end
			session.Page=page;page:SetVisible(false,true);page.Root:SetAttribute('Website',resolved.Name)
			page.Root:SetAttribute('Location',resolved.URL);session.MountMS=(os.clock()-began)*1000
			notify(options.PageMounted,tab,page,session.MountMS)
			if not session.Alive or not self.Alive or not browser:IsCurrent(tab,request)then release(session);return end
			local status=page.Root:GetAttributeChangedSignal('Status'):Connect(settle)
			local presented=page.Root:GetAttributeChangedSignal('Presented'):Connect(settle)
			session.ReadyConnections={status,presented};table.insert(session.Connections,status);table.insert(session.Connections,presented)
			local function updateMetadata()
				if current(tab,session)then local info=metadata(page,session.URL,website,resolved);if tab.Title~=info.Title or tab.Icon~=info.Icon then browser:SetTitle(tab,info.Title,info.Icon)end end
			end
			table.insert(session.Connections,page.Root:GetAttributeChangedSignal('Title'):Connect(updateMetadata))
			table.insert(session.Connections,page.Root:GetAttributeChangedSignal('MetadataVersion'):Connect(updateMetadata))
			settle()
		end)
	end
	table.insert(self.Connections,browser:OnNavigate(navigation))
	if browser.OnCapture then table.insert(self.Connections,browser:OnCapture(function(tab)
		if tab then local owner=self.Owners[tab];if owner then capture(tab,owner.Current)end
		else for currentTab,owner in self.Owners do capture(currentTab,owner.Current)end end
	end))end
	table.insert(self.Connections,browser:OnStartPage(function(tab,request)
		if not browser:IsCurrent(tab,request)then return end
		local owner=self.Owners[tab];self.Owners[tab]=nil
		if owner then capture(tab,owner.Current);clearPending(owner);release(owner.Current)end
		refreshVisibility()
	end))
	table.insert(self.Connections,browser:OnSelectTab(refreshVisibility))
	table.insert(self.Connections,browser:OnCloseTab(function(tab)
		local owner=self.Owners[tab];self.Owners[tab]=nil;if owner then capture(tab,owner.Current);clearPending(owner);release(owner.Current);owner.Current=nil end
	end))
	table.insert(self.Connections,browser:OnCancelNavigation(function(tab)local owner=self.Owners[tab];if owner then clearPending(owner)end;refreshVisibility()end))
	table.insert(self.Connections,browser:OnResize(function(active)
		for _,owner in self.Owners do for _,field in {'Current','Pending'}do local session=owner[field];if session and session.Alive then session.Target:SetAttribute('HTMLViewportResizing',active)end end end
	end))
	table.insert(self.Connections,browser:OnChromeSurface(function(surface)surface:SetAttribute('HTMLInputBlocker',true)end))
	function self:GetPage(tab)local owner=self.Owners[tab];return owner and owner.Current and owner.Current.Page end
	function self:EnsureInitialDocument(tab,origin)
		if not self.Alive or not tab.Alive or self.Owners[tab]then return end
		nextDocumentID+=1
		local target=create('Frame',tab.Content,{Name='InitialDocument_'..nextDocumentID,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Active=false,Selectable=false,Visible=false})
		local session={ID=nextDocumentID,Alive=true,Target=target,Connections={},URL='about:blank'}
		session.Scope=inputScope(session)
		local owner={Current=session};self.Owners[tab]=owner
		local host=if options.WindowHost then options.WindowHost(tab,session)else nil
		local mountOptions={DocumentURL='about:blank',DocumentOrigin=origin,JavaScript=true,StorageHost=options.StorageHost,FallbackWindow=false,
			InputServices={Input=session.Scope.Input,PlayerGui=services.PlayerGui,Task=services.Task},
			JavaScriptServices={WindowHost=host,RunService=session.Scope.Run,Task=services.Task,Clock=services.Clock},
			AnimationServices={RunService=session.Scope.Run}}
		connectRuntime(tab,session,mountOptions.JavaScriptServices)
		navigationCallbacks(tab,session,mountOptions,host)
		local ok,page=pcall(engine.mountHTML,target,'<!doctype html><html><head><title></title></head><body></body></html>',mountOptions)
		if not ok then self.Owners[tab]=nil;release(session);error(page)end
		if not session.Alive then page:Destroy();return end;session.Page=page;session.Committed=true
		local function updateMetadata()
			if current(tab,session)then local info=metadata(page,session.URL);if tab.Title~=info.Title or tab.Icon~=info.Icon then browser:SetTitle(tab,info.Title,info.Icon)end end
		end
		table.insert(session.Connections,page.Root:GetAttributeChangedSignal('Title'):Connect(updateMetadata))
		table.insert(session.Connections,page.Root:GetAttributeChangedSignal('MetadataVersion'):Connect(updateMetadata))
		refreshVisibility()
	end
	function self:SetInputActive(active)self.InputActive=active;refreshVisibility()end
	function self:SetVisible(show)self.Shown=show;refreshVisibility()end
	function self:Destroy()
		if not self.Alive then return end
		for tab,owner in self.Owners do capture(tab,owner.Current)end
		self.Alive=false
		if browser.BeforeNavigate==navigationGuard then browser.BeforeNavigate=nil end
		if browser.BeforeCloseTab==closeGuard then browser.BeforeCloseTab=nil end
		for _,connection in self.Connections do connection:Disconnect()end;table.clear(self.Connections)
		for tab,owner in self.Owners do clearPending(owner);release(owner.Current);self.Owners[tab]=nil end
	end
	table.insert(self.Connections,browser:OnDestroy(function()self:Destroy()end))
	return self
end
return Binding
