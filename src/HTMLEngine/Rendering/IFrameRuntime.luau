--!strict
local IFrameBox = require(script.Parent.IFrameBox)
local ElementNames = require(script.Parent.Parent.DOM.ElementNames)
local ShadowTree = require(script.Parent.Parent.DOM.ShadowTree)
local URLRecord = require(script.Parent.Parent.JavaScript.URLRecord)
local URL = require(script.Parent.Parent.Navigation.URL)
local IFrameRuntime = {}
local MAX_DEPTH = 4

local function copyOptions(source: any?): any
	return if source then table.clone(source) else {}
end

function IFrameRuntime.start(page: any, tree: any, diagnostic: any, mount: any, options: any?): any
	local items = tree.IFrameItems or {}
	local alive = true
	local depth = if options then options.IFrameDepth or 0 else 0
	local resolver = if options then options.IFrameResolver else nil
	local shown=if page.DocumentVisible~=nil then page.DocumentVisible else not(options and options.JavaScriptServices and options.JavaScriptServices.Visible==false)
	local registrations,byNode = {},{}
	local closingLifecycles=setmetatable({},{__mode="k"})
	local taskAPI=if options and options.Task then options.Task else task
	page.IFrames = items
	page.EmbeddedDocuments = items
	local function resourcesChanged()
		if not page.Alive then return end
		if page.DocumentResourcesChanged then page:DocumentResourcesChanged()
		elseif page.JavaScriptRuntime then page.JavaScriptRuntime:ResourcesChanged()end
	end
	local function childComplete(child)
		if child.IsDocumentComplete then return child:IsDocumentComplete()end
		return not child.ScriptInitializationPending and(not child.JavaScriptRuntime or child.JavaScriptRuntime:IsDocumentComplete())
	end
	local function elementName(item: any): string
		return ElementNames.htmlName(item.Node) or item.EmbeddedKind or "iframe"
	end
	local function registered(item,registration)
		return alive and page.Alive and registrations[item]==registration
	end
	local function currentRequest(item,registration,request)
		return registered(item,registration)and registration.Request==request
	end
	local function closeAttempt(closing,operation)
		local ok,value=pcall(operation)
		if not ok and not closing.Failed then closing.Failed=true;closing.Value=value end
	end
	local function closeLifecycle(operation)
		local thread=coroutine.running();local previous=closingLifecycles[thread];local closing=previous or{};closingLifecycles[thread]=closing
		closeAttempt(closing,function()operation(closing)end)
		closingLifecycles[thread]=previous
		if not previous and closing.Failed then error(closing.Value,0)end
	end
	local function destroyMount(mounting,closing)
		if not mounting then return end
		local realm,child=mounting.Runtime,mounting.Page;mounting.Runtime=nil;mounting.Page=nil
		if realm then closeAttempt(closing,function()realm:Destroy()end)end
		if child and child.Alive then closeAttempt(closing,function()child:Destroy()end)end
	end
	local function destroyChild(item: any,closing: any,unload: boolean?)
		local child=item.ChildPage;item.ChildPage=nil
		if unload and child and child.Alive and child.CommitLeave then closeAttempt(closing,function()child:CommitLeave()end)end
		if child and child.Alive then closeAttempt(closing,function()child:Destroy()end)end
	end
	local function unavailable(item,registration,request,message)
		if not currentRequest(item,registration,request)then return end
		closeLifecycle(function(closing)
			registration.Document=nil;destroyChild(item,closing)
			if not currentRequest(item,registration,request)then return end
			item.Loading=false;item.Error=message;IFrameBox.status(item,message)
			if item.ContentGui.SetAttribute then item.ContentGui:SetAttribute("Status","error");item.ContentGui:SetAttribute("Error",message)end
			closeAttempt(closing,function()diagnostic(message)end)
			if currentRequest(item,registration,request)then resourcesChanged()end
		end)
	end
	local function capture(item,base)
		local attributes=item.Node and item.Node.Attributes or{}
		local isFrame=elementName(item)=="iframe"
		local srcdoc=if isFrame then attributes.srcdoc else nil
		return {Reference=if srcdoc~=nil then "about:srcdoc"else if isFrame then attributes.src or "about:blank"else item.SelectedSource or "about:blank",
			HTML=srcdoc,IsSrcdoc=srcdoc~=nil,Base=base or page.BaseURL or page.DocumentURL or"",
			DocumentURL=page.DocumentURL,Sandbox=attributes.sandbox,SourceProcessing=isFrame}
	end
	local function address(intent)
		local reference=intent.Reference
		if intent.IsSrcdoc then return "about:srcdoc"end
		if intent.SourceProcessing and(reference==""or reference=="about:blank")then return "about:blank"end
		if reference:match("^[%a][%w+%.%-]*:")or intent.Base:match("^[%a][%w+%.%-]*:")then
			local ok,result=pcall(URLRecord.resolve,reference,if intent.Base:match("^[%a][%w+%.%-]*:")then intent.Base else nil)
			return if ok and type(result)=="string"then result else "about:blank"
		end
		return URL.resolve(intent.Base,reference).URL
	end
	local function ancestorAddress(url,documentURL)
		local compared=url:match("^[^#]*")
		if documentURL and documentURL:match("^[^#]*")==compared then return true end
		for _,old in options and options.IFrameAncestorURLs or{}do if old:match("^[^#]*")==compared then return true end end
		return false
	end
	local queueRequest
	local function retainDocument(item,registration,request,target,fragment)
		if not currentRequest(item,registration,request)then return end
		local document=registration.Document
		if document then document.Request=request end
		local child=item.ChildPage;item.CurrentURL=target
		if child.JavaScriptRuntime and child.JavaScriptRuntime.Navigation then
			child.JavaScriptRuntime.Navigation:SetLocation(target)
		else
			child.DocumentURL=target
			if child.Root.SetAttribute then child.Root:SetAttribute("Location",target)end
			child:ScrollToFragment(fragment or"")
		end
		if not currentRequest(item,registration,request)then return end
		item.Loading=false
		if document and document.Notify then document.Notify()else resourcesChanged()end
	end
	local function mountItem(item,registration,request,intent,force)
		if not currentRequest(item,registration,request)then return end
		local function current()return currentRequest(item,registration,request)end
		local name=elementName(item)
		if depth>=MAX_DEPTH then unavailable(item,registration,request,name.." nesting limit reached");return end
		local reference,directHTML=intent.Reference,intent.HTML
		local parsed=if intent.SourceProcessing then address(intent)else nil
		if not current()then return end
		-- The frozen shared processing algorithm returns null for an ancestor URL.
		-- The raw Chrome control is retained separately, including its nested load.
		if parsed and not intent.IsSrcdoc and ancestorAddress(parsed,intent.DocumentURL)then
			local document=registration.Document
			if document then document.Request=request end
			item.Loading=false
			if document and document.Notify then document.Notify()else resourcesChanged()end
			return
		end
		local committedURL=item.ChildPage and item.ChildPage.DocumentURL or item.CurrentURL
		if not force and intent.SourceProcessing and not intent.IsSrcdoc and parsed:find("#",1,true)and item.ChildPage and committedURL and committedURL:match("^[^#]*")==parsed:match("^[^#]*")then
			retainDocument(item,registration,request,parsed,parsed:match("#(.*)$"));return
		end
		local blank=intent.SourceProcessing and not intent.IsSrcdoc and(parsed=="about:blank"or parsed:match("^about:blank[?#]")~=nil)
		if blank then reference=parsed;directHTML="<!doctype html><html><head></head><body></body></html>"end
		local localSVG=false
		if directHTML==nil and(name=="object"or name=="embed")then
			local key=reference:match("^%s*(.-)%s*$")
			while key:sub(1,2)=="./"do key=key:sub(3)end
			local svg=options and options.SVGs and options.SVGs[key]
			if svg then localSVG=true;directHTML='<!doctype html><html><head><style>html,body{margin:0;width:100%;height:100%;overflow:hidden}svg{display:block;width:100%;height:100%}</style></head><body>'..svg..'</body></html>'end
		end
		item.Error=nil;IFrameBox.status(item,"Loading embedded page...")
		local destination,website
		if directHTML==nil then
			if not resolver then unavailable(item,registration,request,name.." resolver unavailable: "..reference);return end
			local ok,result=pcall(resolver,intent.Base,reference)
			if not current()then return end
			if not ok then unavailable(item,registration,request,name.." URL failed: "..tostring(result));return end
			destination=result
			if destination and destination.Kind=="external"then unavailable(item,registration,request,"external "..name.." unavailable: "..reference);return end
			website=destination and destination.Website
			if not destination or not website then unavailable(item,registration,request,name.." page unavailable: "..reference);return end
			local oldAddress=(committedURL or""):match("^[^#]*")
			local newAddress=(destination.URL or""):match("^[^#]*")
			-- An explicit fragment (also the unchanged fragment) navigates within
			-- the retained document. An exact src URL without # selects a new one.
			if not force and destination.URL and(name~="iframe"or destination.URL:find("#",1,true))and item.ChildPage and item.CurrentName==destination.Name and oldAddress==newAddress then
				retainDocument(item,registration,request,destination.URL,destination.Fragment or"");return
			end
		end
		local oldDocument,oldChild=registration.Document,item.ChildPage
		if oldChild and oldChild.Alive then
			local realm=oldChild.JavaScriptRuntime
			local leave={Reason=if force then 'reload'else 'navigate',URL=if destination then destination.URL else parsed or reference,PromptState={Shown=false}}
			local ok,accepted=pcall(function()
				if oldChild.RequestLeave then return oldChild:RequestLeave(leave)end
				return not realm or not realm.RequestLeave or realm:RequestLeave(leave)
			end)
			if not current()then return end
			if not ok or not accepted then
				-- The src attribute keeps its new value, but a canceled traversal
				-- retains the previous document and its resource notifications.
				if oldDocument and registration.Document==oldDocument then oldDocument.Request=request end
				item.Loading=false
				local notified,notifyError=pcall(function()if oldDocument and oldDocument.Notify then oldDocument.Notify()else resourcesChanged()end end)
				if not ok then error(accepted,0)elseif not notified then error(notifyError,0)end
				return
			end
		end
		local document={Request=request};registration.Document=document
		local function committedDocument()
			return registered(item,registration)and registration.Document==document
		end
		local function currentDocument()
			return committedDocument()and document.Request==registration.Request
		end
		local function navigate(href,node,data)
			if not committedDocument()then return end
			local target=string.lower(data.Target or"")
			if target=="_parent"or target=="_top"then
				if page.Navigate then local forwarded=table.clone(data);if target=="_parent"then forwarded.Target="_self"end;page.Navigate(href,node,forwarded)
				else diagnostic(name.." parent navigation handler unavailable: "..href)end
				return
			end
			local nextIntent=capture(item,item.ChildPage and item.ChildPage.BaseURL or item.CurrentURL or intent.Base)
			nextIntent.Reference=href;nextIntent.HTML=nil;nextIntent.IsSrcdoc=false;nextIntent.SourceProcessing=false
			queueRequest(item,nextIntent,data.Kind=="reload"or data.SameDocument==false,true)
		end
		local childOptions=copyOptions(if website then website.Options else nil)
		local sandbox=intent.Sandbox
		local scriptsAllowed,sameOriginAllowed,modalsAllowed=sandbox==nil,sandbox==nil,sandbox==nil
		for token in(sandbox or""):lower():gmatch("%S+")do if token=="allow-scripts"then scriptsAllowed=true elseif token=="allow-same-origin"then sameOriginAllowed=true elseif token=='allow-modals'then modalsAllowed=true end end
		if not scriptsAllowed or(options and options.JavaScript==false)then childOptions.JavaScript=false end
		childOptions.StorageOriginOpaque=not sameOriginAllowed or options and options.StorageOriginOpaque==true
		local origin=require(script.Parent.Parent.DOM.DocumentOrigin)
		page.DocumentOrigin=origin.ensure(page.Document,page.DocumentURL,options and options.DocumentOrigin,options and options.DocumentOriginOpaque)
		childOptions.TopLevelDocumentOrigin=page.TopLevelDocumentOrigin or page.DocumentOrigin
		childOptions.DocumentOriginOpaque=not sameOriginAllowed
		childOptions.DocumentOrigin=if sameOriginAllowed and(directHTML~=nil or reference=="about:blank")then page.DocumentOrigin else nil
		if directHTML~=nil or blank then childOptions.StorageDocumentURL=if options and options.StorageDocumentURL then options.StorageDocumentURL else page.DocumentURL end
		if localSVG then childOptions.ScrollBarThickness=0 end
		childOptions.IsSrcdoc=intent.IsSrcdoc
		childOptions.DocumentURL=if intent.IsSrcdoc then "about:srcdoc"else if destination then destination.URL else if blank then reference else intent.Base
		if intent.IsSrcdoc or blank then childOptions.FallbackBaseURL=intent.Base~=""and intent.Base or nil end
		if website and website.CSS~=nil then childOptions.CSS=website.CSS end
		if website and website.Stylesheets~=nil then childOptions.Stylesheets=website.Stylesheets end
		childOptions.Navigate=navigate
		childOptions.IFrameAncestorURLs=table.clone(options and options.IFrameAncestorURLs or{})
		if intent.DocumentURL then table.insert(childOptions.IFrameAncestorURLs,intent.DocumentURL)end
		childOptions.HasParentBlockingStylesheets=function()
			if page.HasOwnBlockingStylesheets then return page:HasOwnBlockingStylesheets()end
			return page.JavaScriptRuntime and page.JavaScriptRuntime:HasOwnBlockingStylesheets()or false
		end
		childOptions.SubscribeParentStylesheetChanges=function(callback)
			if page.SubscribeStylesheetChanges then return page:SubscribeStylesheetChanges(callback)end
			if page.JavaScriptRuntime then return page.JavaScriptRuntime:SubscribeStylesheetChanges(callback)end
			return function()end
		end
		local function notifyChildState(closing)
			if not currentDocument()then return end
			local child=item.ChildPage
			if child and child.Alive~=false and not item.Loading and childComplete(child)and not document.Completed then
				document.Completed=true
				if page.Events then
					if closing then closeAttempt(closing,function()page.Events:Emit(item.Node,"load",nil,{Bubbles=false,Cancelable=false})end)
					else page.Events:Emit(item.Node,"load",nil,{Bubbles=false,Cancelable=false})end
				end
				if not currentDocument()or item.ChildPage~=child then return end
			end
			resourcesChanged()
		end
		local previousChildState=childOptions.DocumentLoadStateChanged
		document.Notify=notifyChildState
		childOptions.DocumentLoadStateChanged=function(value)
			if not currentDocument()then return end
			if previousChildState then previousChildState(value)end
			if currentDocument()then notifyChildState()end
		end
		childOptions.IFrameDepth=depth+1;childOptions.IFrameResolver=resolver
		for _,key in{"DefaultFont","SVGCacheBytes","SVGCacheEntries","SVGPrewarmStates","StorageHost","JavaScriptServices","Stylesheets"}do if childOptions[key]==nil and options then childOptions[key]=options[key]end end
		local parentInput=options and options.InputServices
		if parentInput or childOptions.InputServices then
			local childInput=table.clone(parentInput or{})
			for key,value in childOptions.InputServices or{}do childInput[key]=value end
			-- Embedded documents share their containing viewport's input owner.
			-- Resource-specific factories/tasks may differ; an unfiltered native
			-- Input override must not bypass its window/modal focus boundary.
			if parentInput and parentInput.Input~=nil then childInput.Input=parentInput.Input end
			childOptions.InputServices=childInput
		end
		local ancestorServices=options and options.JavaScriptServices or{}
		local childServices=table.clone(childOptions.JavaScriptServices or{})
		for _,key in{'SimpleDialogHost','ConfirmLeave','IdleBudget'}do if childServices[key]==nil then childServices[key]=ancestorServices[key]end end
		local childPolicy,ancestorPolicy=childServices.ModalsAllowed,ancestorServices.ModalsAllowed
		local function allows(policy)return if type(policy)=='function'then policy()==true else policy~=false end
		-- Realm ownership callbacks belong to the document being mounted. A
		-- nested document must never replace its browser session's root realm.
		if childServices.RuntimeCreated==ancestorServices.RuntimeCreated then childServices.RuntimeCreated=nil end
		local runtimeCreated=childServices.RuntimeCreated
		local mounting={}
		childServices.RuntimeCreated=function(realm,child)
			mounting.Runtime=realm;mounting.Page=child
			if not currentDocument()or registration.Mounting~=mounting then
				closeLifecycle(function(closing)destroyMount(mounting,closing)end);return
			end
			if child.SetDocumentVisible then child:SetDocumentVisible(shown)end
			if runtimeCreated then runtimeCreated(realm,child)end
		end
		childServices.WindowHost=nil;childServices.Visible=shown
		-- This profile has no iframe camera/microphone delegation yet. Inherited
		-- script services must not grant a nested document its parent's devices.
		childServices.PermissionHost=false;childServices.MediaCaptureHost=nil
		childServices.PermissionStore=nil;childServices.PermissionRequestsAllowed=false
		childServices.ModalsAllowed=function()
			return modalsAllowed and allows(childPolicy)and(childPolicy==ancestorPolicy or allows(ancestorPolicy))
		end
		childOptions.JavaScriptServices=childServices
		childOptions.FullscreenAllowed=item.Node.Attributes.allowfullscreen~=nil or (item.Node.Attributes.allow or ''):find('fullscreen',1,true)~=nil
		closeLifecycle(function(closing)
			destroyChild(item,closing,true)
			if not current()or not currentDocument()then return end
			registration.Mounting=mounting
			local ok,child=pcall(mount,item.ContentGui,directHTML or website.HTML,childOptions)
			if registration.Mounting==mounting then registration.Mounting=nil end
			mounting.Runtime=nil;mounting.Page=nil
			if not current()or not currentDocument()then
				if ok and child and child.Alive then closeAttempt(closing,function()child:Destroy()end)end
				return
			end
			if not ok then unavailable(item,registration,request,name.." mount failed: "..tostring(child));return end
			item.ChildPage=child;item.CurrentURL=childOptions.DocumentURL;item.CurrentName=if destination then destination.Name else nil
			if child.SetVisible then child:SetVisible(shown)end
			item.Loading=false;item.Error=nil;IFrameBox.status(item,nil)
			if item.ContentGui.SetAttribute then item.ContentGui:SetAttribute("Status","ready");item.ContentGui:SetAttribute("URL",item.CurrentURL)end
			if destination and destination.Kind=="missing"then child.Root:SetAttribute("HTTPStatus",404)end
			if destination and destination.Fragment and destination.Fragment~=""then child:ScrollToFragment(destination.Fragment)end
			if currentDocument()then notifyChildState(closing)end
		end)
	end
	queueRequest=function(item,intent,force,deferred)
		local registration=registrations[item]
		if not registration or not registered(item,registration)then return end
		registration.Request+=1
		local request=registration.Request
		local mounting=registration.Mounting;registration.Mounting=nil
		if mounting then closeLifecycle(function(closing)destroyMount(mounting,closing)end)end
		if not currentRequest(item,registration,request)then return end
		item.Loading=true;resourcesChanged()
		if not currentRequest(item,registration,request)then return end
		local function run()
			if not currentRequest(item,registration,request)then return end
			if item.UnsupportedType then unavailable(item,registration,request,"unsupported "..elementName(item).." type: "..tostring(item.UnsupportedType))
			else mountItem(item,registration,request,intent,force)end
		end
		if deferred then taskAPI.defer(run)else run()end
	end
	local api={}
	page.IFrameRuntime=api
	function api:HasExecutingScripts()
		if not alive or not page.Alive then return false end
		for item,registration in registrations do
			for _,child in{item.ChildPage,registration.Mounting and registration.Mounting.Page}do
				if child and child.Alive then
					if child.HasExecutingScripts then if child:HasExecutingScripts()then return true end
					elseif child.JavaScriptRuntime and child.JavaScriptRuntime.Alive and child.JavaScriptRuntime:IsExecuting()then return true end
				end
			end
		end
		return false
	end
	function api:SetVisible(show)
		if not alive or not page.Alive then return end
		shown=show==true
		for item,registration in table.clone(registrations)do
			for _,child in{item.ChildPage,registration.Mounting and registration.Mounting.Page}do
				if registered(item,registration)and child and child.Alive and child.SetVisible then child:SetVisible(shown)end
			end
		end
	end
	function api:RequestLeave(request)
		if not alive or not page.Alive then return false end
		for item,registration in table.clone(registrations)do
			local child=item.ChildPage
			if registered(item,registration)and child and child.Alive then
				local realm=child.JavaScriptRuntime
				if child.RequestLeave then if not child:RequestLeave(request)then return false end
				elseif realm and realm.RequestLeave and not realm:RequestLeave(request)then return false end
			end
			if not alive or not page.Alive then return false end
		end
		return true
	end
	function api:CommitLeave()
		if not alive or not page.Alive then return end
		for item,registration in table.clone(registrations)do
			local child=item.ChildPage
			if registered(item,registration)and child and child.Alive then
				if child.CommitLeave then child:CommitLeave()
				elseif child.JavaScriptRuntime and child.JavaScriptRuntime.CommitLeave then child.JavaScriptRuntime:CommitLeave()end
			end
		end
	end
	function api:PendingCount()
		local count=0
		for item in registrations do local child=item.ChildPage;if item.Loading or child and child.Alive and not childComplete(child)then count+=1 end end
		return count
	end
	function api:Add(additions: {any})
		if not alive or not page.Alive then return end
		for _,item in additions do
			if not alive or not page.Alive then return end
			if registrations[item]then continue end
			registrations[item]={Request=0};if item.Node then byNode[item.Node]=item end
			queueRequest(item,capture(item),false,true)
		end
	end
	function api:Mutation(record,base)
		if record.Type~="attributes"or record.AttributeNamespace~=nil or not ElementNames.html(record.Target,"iframe")then return end
		if not ShadowTree.Connected(record.Target,page.Document)then return end
		local key=record.AttributeName
		if key~="src"and key~="srcdoc"then return end
		if key=="src"and record.Target.Attributes.srcdoc~=nil then return end
		local item=byNode[record.Target];if not item then return end
		queueRequest(item,capture(item,base),false,true)
	end
	-- Retire the complete old batch before any child/service callback. Only
	-- captured children are closed; a callback may publish a new same-item lease.
	local function retire(removals)
		local retired={}
		for _,item in removals do
			local registration=registrations[item]
			if not registration then continue end
			registrations[item]=nil
			if item.Node and byNode[item.Node]==item then byNode[item.Node]=nil end
			registration.Request+=1;registration.Document=nil
			local mounting=registration.Mounting;registration.Mounting=nil
			local child=item.ChildPage;item.ChildPage=nil;item.Loading=false
			table.insert(retired,{Child=child,Mounting=mounting})
		end
		return retired
	end
	local function closeRetired(retired,closing)
		for _,entry in retired do
			local mounting=entry.Mounting;entry.Mounting=nil;destroyMount(mounting,closing)
			local child=entry.Child;entry.Child=nil
			if child and child.Alive then closeAttempt(closing,function()child:Destroy()end)end
		end
		table.clear(retired)
		closeAttempt(closing,resourcesChanged)
	end
	function api:Remove(removals: {any})
		local thread=coroutine.running();local previous=closingLifecycles[thread];local closing=previous or{};closingLifecycles[thread]=closing
		closeRetired(retire(removals),closing)
		closingLifecycles[thread]=previous
		if not previous and closing.Failed then error(closing.Value,0)end
	end
	function api:Reload(item: any)
		assert(registrations[item],"Unknown iframe item")
		local intent=capture(item)
		if not intent.IsSrcdoc then intent.Reference=item.ChildPage and item.ChildPage.DocumentURL or item.CurrentURL or item.SelectedSource or"about:blank";intent.SourceProcessing=false end
		queueRequest(item,intent,true,false)
	end
	function api:Destroy()
		if not alive then return end;alive=false
		local thread=coroutine.running();local previous=closingLifecycles[thread];local closing=previous or{};closingLifecycles[thread]=closing
		local removals={};for item in registrations do table.insert(removals,item)end
		local retired=retire(removals)
		table.clear(registrations);table.clear(byNode)
		-- Take only this owner before callbacks. A new owner published by an old
		-- child's Destroy must remain the page's active resource owner.
		if page.IFrameRuntime==api then page.IFrameRuntime=nil end
		closeRetired(retired,closing)
		closingLifecycles[thread]=previous
		if not previous and closing.Failed then error(closing.Value,0)end
	end
	-- Cleanup belongs to the published API before its first external wake.
	if alive and page.Alive then page:AddCleanup(function()api:Destroy()end)end
	api:Add(items)
	return api
end

return IFrameRuntime
