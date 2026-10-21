--!strict
-- Optional, engine-owned window integration. The UI and raw page mount are
-- independent dependencies; importing this module opens nothing.
local Windows=require(script.Parent.FallbackWindows)
local Scope=require(script.InputScope)
local URL=require(script.Parent.Parent.Navigation.URL)
local Factory=require(script.Parent.GuiFactory)
local Host={}
local BLANK='<!doctype html><html><head><title></title></head><body></body></html>'
local function attempt(errors,callback)
	local ok,value=pcall(callback);if not ok and not errors.Failed then errors.Failed,errors.Value=true,value end
end
local function finish(errors)if errors.Failed then error(errors.Value,0)end end

function Host.mount(target,html,options,mount)
	options=options or{}
	local services=table.clone(options.FallbackServices or{})
	local originalInput=options.InputServices or{}
	local originalScripts=options.JavaScriptServices or{}
	local permissionStore=originalScripts.PermissionStore or{}
	local input=services.Input or originalInput.Input or game:GetService('UserInputService')
	local run=services.RunService or originalScripts.RunService or game:GetService('RunService')
	local tasks=services.Task or originalScripts.Task or task
	local create=services.Create or services.Factory and services.Factory.create or Factory.create
	services.Input,services.RunService,services.Task,services.Create=input,run,tasks,create
	local manager=Windows.new(options.WindowParent or target,services)
	local self={Alive=true,Manager=manager,Contexts={},Names={},Connections={}}
	local function diagnostic(message)if options.Diagnostic then options.Diagnostic(message)else warn('HTML window: '..tostring(message))end end
	local function discarded(context)return not self.Alive or not context.Alive or context.Window~=nil and not context.Window.Alive end
	local function pageFor(context)
		if discarded(context)then return nil end
		local record=context.Current or context.Pending
		return record and record.Page
	end
	local function origin(context)local page=pageFor(context);return page and page.DocumentOrigin or context.Origin end
	local function clearName(context)
		if self.Names[context.Name]==context then self.Names[context.Name]=nil end
	end
	local function setName(context,name)
		if discarded(context)then return end;clearName(context);context.Name=name
		if context.Handle then context.Handle.Name=name end
		if name~=''then self.Names[name]=context end
	end
	local refresh,close,open,navigate,mountContext
	local function release(record,unload)
		if not record or not record.Alive then return end;record.Alive=false
		local errors={}
		local page,realm=record.Page,record.Runtime;record.Page=nil;record.Runtime=nil
		local executing=false
		attempt(errors,function()executing=page and page.HasExecutingScripts and page:HasExecutingScripts()or realm and realm.IsExecuting and realm:IsExecuting()end)
		if unload and not executing and page and page.CommitLeave then attempt(errors,function()page:CommitLeave()end)end
		if realm then attempt(errors,function()realm:Destroy()end)end
		if page then attempt(errors,function()record.NativeDestroy(page)end)end
		if record.Dialog then local dialog=record.Dialog;record.Dialog=nil;attempt(errors,dialog.Cancel);if dialog.Leave then attempt(errors,function()dialog.Complete(false)end)end end
		for _,key in{'Ready','Presented','Title','Resize'}do if record[key]then local connection=record[key];record[key]=nil;attempt(errors,function()connection:Disconnect()end)end end
		if record.Scope then attempt(errors,function()record.Scope:Destroy()end)end
		if record.Target and record.Target.Parent then attempt(errors,function()record.Target:Destroy()end)end
		finish(errors)
	end
	local function cancelDialog(record)
		if record and record.Dialog then
			local dialog=record.Dialog;record.Dialog=nil;dialog.Cancel()
			-- Hiding or displacing a live modal is a rejected answer. Forced
			-- teardown uses release(), after retiring all executing realms.
			dialog.Complete(false)
		end
	end
	local function show(context,record,request,complete)
		if discarded(context)or not record.Alive or not context.Visible or context.Window and context.Window.State=='minimized'then
			tasks.defer(function()complete(false)end);return function()end
		end
		cancelDialog(record)
		if discarded(context)or not record.Alive or record.Dialog then complete(false);return function()end end
		local dialog={Complete=complete,Leave=request.Leave==true,Done=false}
		record.Dialog=dialog
		local cancel
		dialog.Cancel=function()
			if dialog.Done then return end;dialog.Done=true
			if cancel then cancel()end;refresh()
		end
		local function finish(accepted,value)
			if dialog.Done then return end;dialog.Done=true
			if record.Dialog==dialog then record.Dialog=nil end
			refresh();complete(accepted,value)
		end
		cancel=manager:ShowDialog(context.Content,request,finish)
		if dialog.Done then cancel()end
		refresh()
		return function()if record.Dialog==dialog then record.Dialog=nil end;dialog.Cancel()end
	end
	local function confirmLeave(context,record,request)
		if discarded(context)or not record.Alive then return false end
		local thread=coroutine.running();local waiting,done,accepted=false,false,false
		show(context,record,{Kind='confirm',Title='Leave this page?',Message='Changes you made may not be saved.',AcceptText='Leave',CancelText='Stay',Leave=true,URL=request.URL},function(value)
			if done then return end;done=true;accepted=value==true
			if waiting then tasks.defer(function()
				if coroutine.status(thread)=='suspended'then local ok,message=coroutine.resume(thread,accepted);if not ok then diagnostic(message)end end
			end)end
		end)
		if done then return accepted end;waiting=true;return coroutine.yield()
	end
	refresh=function()
		if not self.Alive then return end
		local focused=manager:GetFocused()
		for context in self.Contexts do
			local shown=context.Visible and(not context.Window or context.Window.State~='minimized')
			local documentShown=shown and context.DocumentVisible~=false
			local focusedHere=if context.Window then focused==context.Window else focused==nil
			for _,record in {context.Current,context.Pending}do if record and record.Alive then
				local current=record==context.Current
				local modal=record.Dialog~=nil
				record.Scope:SetActive(documentShown and focusedHere and current and context.Pending==nil and not modal)
				record.Scope:SetFrames(documentShown)
				local page=record.Page
				if page and page.Alive then
					record.NativeDocumentVisible(page,documentShown)
					record.NativeVisible(page,shown and current,true)
				end
			end end
		end
	end
	local function focus(context)
		if discarded(context)then return end
		if context.Window then context.Window:Focus()else manager:Focus(nil)end;refresh()
	end
	close=function(context)
		if not context.Alive then return end;context.Alive=false;context.Closing=false;context.CloseRequest=nil;clearName(context)
		local errors={}
		self.Contexts[context]=nil
		local pending,current=context.Pending,context.Current;context.Pending=nil;context.Current=nil
		attempt(errors,function()release(pending,false)end);attempt(errors,function()release(current,true)end)
		local window=context.Window;context.Window=nil;context.Content=nil
		if window and window.Alive then attempt(errors,function()window:Close()end)end
		attempt(errors,refresh);finish(errors)
	end
	function self:Destroy()
		if not self.Alive then return end;self.Alive=false
		local errors={}
		for _,connection in self.Connections do attempt(errors,function()connection:Disconnect()end)end;table.clear(self.Connections)
		local list={};for context in self.Contexts do table.insert(list,context)end
		for _,context in list do attempt(errors,function()close(context)end)end
		attempt(errors,function()manager:Destroy()end);table.clear(self.Names)
		open,navigate,mountContext=nil,nil,nil
		finish(errors)
	end
	local function requestClose(context)
		if discarded(context)or not context.ScriptOpened or context.Closing then return end
		local request={};context.Closing=true;context.CloseRequest=request
		local ok,message=pcall(tasks.defer,function()
			if discarded(context)or context.CloseRequest~=request then return end
			local accepted
			local success,result=pcall(function()
				if context.Window then return context.Window:RequestClose()end
				local page=pageFor(context);if page and page.RequestLeave and not page:RequestLeave({Kind='close'})then return false end
				close(context);return true
			end)
			accepted=success and result==true
			if context.CloseRequest==request then context.CloseRequest=nil;if not discarded(context)and not accepted then context.Closing=false end end
			if not success then error(result,0)end
		end)
		if not ok then if context.CloseRequest==request then context.CloseRequest=nil;context.Closing=false end;error(message,0)end
	end
	local function metrics(context,key)
		if discarded(context)then return 0 end
		local gui=context.Window and context.Window.Root or context.Content
		local p,s=gui.AbsolutePosition,gui.AbsoluteSize
		local values={outerWidth=s.X,outerHeight=s.Y,screenX=p.X,screenLeft=p.X,screenY=p.Y,screenTop=p.Y}
		if values[key]~=nil then return values[key]end
		local page=pageFor(context);local viewport=page and page.GeometryViewport and page:GeometryViewport()
		return if viewport and key=='innerWidth'then viewport.Width elseif viewport and key=='innerHeight'then viewport.Height else nil
	end
	local function handle(context)
		if context.Handle then return context.Handle end
		context.Handle={Name=context.Name,IsClosed=function()return context.Closing==true or discarded(context)end,IsDiscarded=function()return discarded(context)end,
			GetRealm=function()local page=pageFor(context);return page and page.JavaScriptRuntime or(context.Current or context.Pending or{}).Runtime end,
			CanAccess=function(value)return not discarded(context)and value~=nil and value==origin(context)end,
			close=function()requestClose(context)end,focus=function()focus(context)end,blur=function()if manager:GetFocused()==context.Window then manager:Focus(nil)end end,
			SetName=function(name)setName(context,name)end,Metrics=function(key)return metrics(context,key)end,
			Geometry=function(kind,a,b)
				if discarded(context)or not context.ScriptOpened or not context.Window or context.Window.Fullscreen then return end
				local window=context.Window;if window.State~='normal'then window:Restore()end
				local p,s=window:GetPosition(),window:GetSize()
				if kind=='moveTo'then window:SetPosition(Vector2.new(a,b))elseif kind=='moveBy'then window:SetPosition(Vector2.new(p.X+a,p.Y+b))
				elseif kind=='resizeTo'then window:SetSize(Vector2.new(a,b))elseif kind=='resizeBy'then window:SetSize(Vector2.new(s.X+a,s.Y+b))end
			end,
			Navigate=function(url,kind,base)if not discarded(context)then return navigate(context,url,kind,base)end;return false end,
			GetOpener=function()return context.Opener and handle(context.Opener)end,ClearOpener=function()context.Opener=nil end}
		return context.Handle
	end
	local function windowHost(context,record)
		local value=handle(context)
		return {GetSelfHandle=function()return value end,GetOpener=value.GetOpener,ClearOpener=value.ClearOpener,GetName=function()return context.Name end,
			SetName=value.SetName,Metrics=value.Metrics,IsClosed=value.IsClosed,IsDiscarded=value.IsDiscarded,close=value.close,focus=value.focus,blur=value.blur,
			ScreenMetrics=function(key)
				local area=manager.Layer.AbsoluteSize
				return if key=='width'or key=='availWidth'then area.X elseif key=='height'or key=='availHeight'then area.Y else nil
			end,
			Open=function(request)if discarded(context)or not record.Alive then return nil end;return open(context,request)end,
			SetFullscreen=function(enabled)if discarded(context)or not context.Window then return false end;context.Window:SetFullscreen(enabled);return true end,
			SubscribeFullscreenExit=function(callback)return manager.FullscreenChanged:Connect(function(window,enabled)if window==context.Window and not enabled then callback()end end)end}
	end
	local function resolve(context,reference,base)
		base=base or(pageFor(context)and pageFor(context).BaseURL)or context.URL or'about:blank'
		if reference==''or reference=='about:blank'then return {URL='about:blank',Website={HTML=BLANK,Options={}}}end
		local resolver=options.WindowResolver or options.IFrameResolver
		if not resolver then return nil end
		local result=resolver(base,reference)
		if not result or not result.Website or type(result.Website.HTML)~='string'then return nil end
		result=table.clone(result);result.URL=result.URL or URL.resolve(base,reference).URL;return result
	end
	mountContext=function(context,website,address,isInitial,missing)
		if discarded(context)then return nil end
		context.Generation+=1
		local record={Alive=true,Generation=context.Generation}
		local oldPending=context.Pending;context.Pending=record;release(oldPending,false)
		record.Target=create('Frame',context.Content,{Name='HTMLDocument',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false,Selectable=false,Visible=false})
		local function resized()
			if record.Alive then record.Target:SetAttribute('HTMLViewportResizing',context.Content:GetAttribute('HTMLViewportResizing')==true)end
		end
		resized();record.Resize=context.Content:GetAttributeChangedSignal('HTMLViewportResizing'):Connect(resized)
		record.Scope=Scope.new(input,run,function(event)
			if manager:ConsumesInput(event)then return true end
			local kind=tostring(event.UserInputType)
			return event.Position~=nil and(kind:find('Mouse',1,true)~=nil or kind:find('Touch',1,true)~=nil)
				and not manager:CanReceivePointer(context.Window,Vector2.new(event.Position.X,event.Position.Y))
		end,diagnostic)
		refresh()
		local prepared=table.clone(options)
		for key,value in website.Options or{}do prepared[key]=value end
		prepared.FallbackWindow=false;prepared.DocumentURL=address
		if not isInitial then prepared.CSS=website.CSS;prepared.Stylesheets=website.Stylesheets or prepared.Stylesheets end
		if address=='about:blank'then prepared.DocumentOrigin=context.Origin;prepared.FallbackBaseURL=context.CreatorBase or prepared.FallbackBaseURL
		elseif not isInitial then prepared.DocumentOrigin=nil;prepared.DocumentOriginOpaque=nil;prepared.FallbackBaseURL=website.Options and website.Options.FallbackBaseURL end
		prepared.Navigate=function(url,node,data)
			local configured=if isInitial then options.Navigate else website.Options and website.Options.Navigate
			if configured then return configured(url,node,data)end
			if data and data.Download~=nil then return false end
			if data and data.Href=='#'then url=url:gsub('#.*$','')..'#'end
			local targetName=data and data.Target or''
			if targetName~=''and targetName:lower()~='_self'and targetName:lower()~='_top'and targetName:lower()~='_parent'then return open(context,{URL=url,Target=targetName,Features={}})~=nil end
			return navigate(context,url,data and data.Kind or'assign')
		end
		local controls=table.clone(prepared.InputServices or{});prepared.InputServices=controls;controls.Input=record.Scope.Input;controls.Task=tasks;controls.PlayerGui=controls.PlayerGui or services.PlayerGui
		local scripts=table.clone(prepared.JavaScriptServices or{});prepared.JavaScriptServices=scripts
		scripts.PermissionStore=permissionStore
		if scripts.MediaCaptureHost==nil then scripts.MediaCaptureHost=originalScripts.MediaCaptureHost end
		scripts.WindowHost=windowHost(context,record);scripts.Task=tasks;scripts.RunService=record.Scope.Run
		scripts.Visible=context.Visible and context.DocumentVisible~=false
		if scripts.SimpleDialogHost==nil then scripts.SimpleDialogHost={Show=function(request,complete)return show(context,record,request,complete)end}end
		if scripts.ConfirmLeave==nil then scripts.ConfirmLeave=function(request)return confirmLeave(context,record,request)end end
		local prior=if isInitial then scripts.RuntimeCreated else website.Options and website.Options.JavaScriptServices and website.Options.JavaScriptServices.RuntimeCreated
		scripts.RuntimeCreated=function(runtime,page)
			record.Runtime=runtime
			if page then record.Page=page;record.NativeDestroy=page.Destroy;record.NativeVisible=page.SetVisible;record.NativeDocumentVisible=page.SetDocumentVisible end
			if discarded(context)or not record.Alive or context.Pending~=record then if page then record.NativeDestroy(page)else runtime:Destroy()end;return end
			if page then record.NativeVisible(page,false,true)end
			if prior then prior(runtime,page)end
		end
		local animations=table.clone(prepared.AnimationServices or{});prepared.AnimationServices=animations;animations.RunService=record.Scope.Run
		local ok,page=pcall(mount,record.Target,website.HTML,prepared)
		if not ok then
			local current=not discarded(context)and record.Alive and context.Pending==record
			if context.Pending==record then context.Pending=nil end
			local cleaned,failure=pcall(release,record,false)
			if current then error(page,0)elseif not cleaned then error(failure,0)end;return nil
		end
		if not record.Page then record.Page=page;record.NativeDestroy=page.Destroy;record.NativeVisible=page.SetVisible;record.NativeDocumentVisible=page.SetDocumentVisible end
		if discarded(context)or not record.Alive or context.Pending~=record or not page.Alive then release(record,false);return nil end
		if missing then page.Root:SetAttribute('HTTPStatus',404)end
		page.FallbackHost=self;page.FallbackWindow=context.Window
		page.SetDocumentVisible=function(_,visible)
			if discarded(context)then return end;context.DocumentVisible=visible==true;refresh()
		end
		page.SetVisible=function(_,visible,presentationOnly)
			if presentationOnly then return record.NativeVisible(page,visible,true)end
			assert(type(visible)=='boolean','Page visibility must be a boolean')
			if discarded(context)then return end;context.Visible=visible
			if context.Window then context.Window:SetVisible(visible)end
			if not visible then cancelDialog(context.Current);cancelDialog(context.Pending)end;refresh()
		end
		if context.Window and page.Root.GetAttributeChangedSignal then record.Title=page.Root:GetAttributeChangedSignal('Title'):Connect(function()
			if record.Alive and context.Current==record then context.Window:SetTitle(page.Title or'HTML')end
		end)end
		page:AddCleanup(function()
			if record.Alive then record.Alive=false;if context==self.Main then self:Destroy()else close(context)end end
		end)
		local function commit()
			if discarded(context)or not record.Alive or context.Pending~=record then return end
			if page.Root.GetAttribute then
				local status=page.Root:GetAttribute('Status')
				if status=='error'and context.Current then
					context.Pending=nil
					local message=page.Root:GetAttribute('Error')or'Page layout failed'
					release(record,false);refresh();diagnostic(message);return
				end
				if status~='ready'or page.Root:GetAttribute('Presented')==false then return end
			end
			if record.Ready then record.Ready:Disconnect();record.Ready=nil end
			if record.Presented then record.Presented:Disconnect();record.Presented=nil end
			local previous=context.Current;context.Current=record;context.Pending=nil;context.URL=page.DocumentURL or address
			record.Target.Visible=true
			-- Initial resource publication can finish after layout becomes ready.
			-- Paint that complete replacement before old-page unload can suspend.
			refresh()
			local retired,retirementError=pcall(release,previous,true)
			if context.Window then context.Window:SetTitle(page.Title or'HTML')end;refresh()
			if not retired then error(retirementError,0)end
		end
		if page.Root.GetAttributeChangedSignal then
			record.Ready=page.Root:GetAttributeChangedSignal('Status'):Connect(commit)
			record.Presented=page.Root:GetAttributeChangedSignal('Presented'):Connect(commit)
		end
		commit();refresh();return page
	end
	navigate=function(context,reference,kind,base)
		if discarded(context)then return false end
		local current=pageFor(context)
		local address=current and current.DocumentURL or context.URL or'about:blank'
		if kind~='reload'and type(reference)=='string'and reference:find('#',1,true)then
			local destination=URL.resolve(base or address,reference).URL
			if reference:sub(-1)=='#'and not destination:find('#',1,true)then destination..='#'end
			if destination:gsub('#.*$','')==address:gsub('#.*$','')then
				context.Navigation={}
				if current and current.JavaScriptRuntime then current.JavaScriptRuntime:Access(function()current.JavaScriptRuntime.Navigation:SetLocation(destination)end)
				elseif current then
					current.DocumentURL=destination;current.Document.URL=destination;current.Root:SetAttribute('DocumentURL',destination)
					current:ScrollToFragment(destination:match('#(.*)$')or'')
				end
				context.URL=destination;return true
			end
		end
		local destination=resolve(context,if kind=='reload'then address else reference,base)
		if not destination or discarded(context)then return false end
		local request={};context.Navigation=request
		tasks.defer(function()
			if discarded(context)or context.Navigation~=request then return end
			local old=pageFor(context)
			if old and old.RequestLeave and not old:RequestLeave({Kind=kind,URL=destination.URL})then return end
			if discarded(context)or context.Navigation~=request then return end
			mountContext(context,destination.Website,destination.URL,false,destination.Kind=='missing')
		end)
		return true
	end
	local function newContext(name,scriptOpened,opener,settings)
		local context={Alive=true,Name=name,ScriptOpened=scriptOpened,Opener=opener,Generation=0,Visible=settings==nil or settings.Visible~=false,DocumentVisible=true,Origin=opener and origin(opener)or{}}
		self.Contexts[context]=true;if name~=''then self.Names[name]=context end
		if settings then
			context.Window=manager:Open(settings);context.Content=context.Window.Content
			context.Window:SetCloseGuard(function()
				local page=pageFor(context);return not page or not page.RequestLeave or page:RequestLeave({Kind='close'})
			end)
			context.Window:OnClose(function()if context==self.Main then self:Destroy()else close(context)end end)
		else context.Content=target end
		return context
	end
	open=function(owner,request)
		if discarded(owner)then return nil end
		local features=request.Features or{};local name=request.Target or'_blank';local lower=name:lower()
		local destination=resolve(owner,request.URL or'')
		if not destination or discarded(owner)then return nil end
		local context=if lower=='_self'or lower=='_parent'or lower=='_top'then owner elseif lower~='_blank'and not features.NoOpener then self.Names[name]else nil
		if context and discarded(context)then clearName(context);context=nil end
		if context then if request.URL and request.URL~=''then navigate(context,destination.URL,'assign')end;focus(context);return handle(context)end
		local count=0;for _ in self.Contexts do count+=1 end;if count>=(options.MaxFallbackWindows or 16)then return nil end
		local settings={Title='HTML',Size=Vector2.new(features.Width or 640,features.Height or 420),MinSize=Vector2.new(240,160),
			Position=if features.Left~=nil or features.Top~=nil then Vector2.new(features.Left or 0,features.Top or 0)else nil}
		context=newContext(if lower=='_blank'or features.NoOpener then''else name,true,if features.NoOpener then nil else owner,settings)
		context.CreatorBase=(pageFor(owner)and pageFor(owner).BaseURL)or owner.URL
		local ok,result=pcall(function()
			-- The initial blank document is synchronously available to the caller.
			mountContext(context,{HTML=BLANK,Options={}},'about:blank',false)
			if destination.URL~='about:blank'then navigate(context,destination.URL,'assign')end
		end)
		if not ok then pcall(close,context);error(result,0)end
		focus(context);return handle(context)
	end
	self.Connections[1]=manager.FocusChanged:Connect(refresh)
	self.Connections[2]=manager.StateChanged:Connect(function(window,state)
		for context in self.Contexts do if context.Window==window and state=='minimized'then cancelDialog(context.Current);cancelDialog(context.Pending)end end;refresh()
	end)
	if input.InputBegan then table.insert(self.Connections,input.InputBegan:Connect(function(event)
		local main=self.Main;if not main or main.Window or discarded(main)or not event.Position then return end
		local kind=tostring(event.UserInputType);if not kind:find('MouseButton1',1,true)and not kind:find('Touch',1,true)then return end
		local point=Vector2.new(event.Position.X,event.Position.Y);local p,s=main.Content.AbsolutePosition,main.Content.AbsoluteSize
		if point.X>=p.X and point.Y>=p.Y and point.X<p.X+s.X and point.Y<p.Y+s.Y and manager:CanReceivePointer(nil,point)and not manager:ConsumesInput(event)then manager:Focus(nil);refresh()end
	end))end
	if target.Destroying then table.insert(self.Connections,target.Destroying:Connect(function()self:Destroy()end))end
	local settings
	if options.FallbackWindow~=false then
		settings=if type(options.FallbackWindow)=='table'then table.clone(options.FallbackWindow)else{}
		settings.Title=settings.Title or'HTML'
		local size=target.AbsoluteSize
		settings.Size=settings.Size or Vector2.new(math.max(240,size and size.X-24 or 640),math.max(180,size and size.Y-24 or 420))
		settings.Position=settings.Position or Vector2.new(12,12)
	end
	self.Main=newContext('',options.ScriptOpened==true,nil,settings)
	self.Main.DocumentVisible=originalScripts.Visible~=false
	self.Main.Origin=options.DocumentOrigin or self.Main.Origin
	local ok,page=pcall(mountContext,self.Main,{HTML=html,Options=options},options.DocumentURL or'about:blank',true)
	if not ok then pcall(function()self:Destroy()end);error(page,0)end
	if not page then self:Destroy();error('HTML window disposed during initial mount',0)end
	-- The original mount handle continues to own the family after its document
	-- navigates. Internal retirement uses the captured PageSession destructor.
	page.Destroy=function()self:Destroy()end
	function self:GetPage(window)
		if window==nil then return pageFor(self.Main)end
		for context in self.Contexts do if context.Window==window then return pageFor(context)end end
		return nil
	end
	focus(self.Main);return page
end
return Host
