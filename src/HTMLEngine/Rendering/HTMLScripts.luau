--!strict
-- Adapter between the data-only JS/DOM runtime and the mounted page.
local Runtime=require(script.Parent.Parent.JavaScript.Runtime)
local VM=require(script.Parent.Parent.JavaScript.VM)
local DOM=require(script.Parent.Parent.DOM.Node)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local MediaContent=require(script.Parent.Parent.HTML.MediaContent)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Disclosure=require(script.Parent.Disclosure)
local View=require(script.Parent.Parent.Controls.View)
local TextSelection=require(script.Parent.Parent.Controls.TextSelection)
local Links=require(script.Parent.Parent.Input.Links)
local CanvasBackground=require(script.Parent.CanvasBackground)
local FormModel=require(script.Parent.Parent.Controls.FormModel)
local ScriptClock=require(script.Parent.ScriptClock)
local ScriptGeometry=require(script.Parent.ScriptGeometry)
local ScriptSelection=require(script.Parent.ScriptSelection)
local HTMLAnimations=require(script.Parent.HTMLAnimations)
local Dialog=require(script.Parent.Dialog)
local Popover=require(script.Parent.Popover)
local TopLayerLayout=require(script.Parent.TopLayerLayout)
local WorkerHost=require(script.Parent.WorkerHost)
local DocumentInfo=require(script.Parent.Parent.HTML.DocumentInfo)
local ResourceLoadHost=require(script.Parent.ResourceLoadHost)
local Editing=require(script.Parent.Parent.JavaScript.Editing)
local AudioHost=require(script.Parent.AudioHost)
local FullscreenHost=require(script.Parent.FullscreenHost)
local PermissionHost=require(script.Parent.PermissionHost)
local HTMLScripts={}
function HTMLScripts.hasScripts(document: any): boolean
	if #Runtime.scripts(document)>0 then return true end
	return DOM.findElement(document,function(node)return Editing.state(node)=="true"or Editing.state(node)=="plaintext-only"end)~=nil
end
function HTMLScripts.ShouldStart(page: any,options: any?): boolean
	return (not options or options.JavaScript~=false)and(page.ParserSession~=nil and not page.ParserSession.Done or HTMLScripts.hasScripts(page.Document)or options~=nil and options.JavaScriptServices~=nil and(options.JavaScriptServices.WindowHost~=nil or options.JavaScriptServices.LoadStylesheet~=nil and options.JavaScriptServices.LoadStylesheet~=false))
end
function HTMLScripts.start(page: any,tree: any,schedule: any,diagnostic: any,options: any?,afterFrame: any?): any
	if not HTMLScripts.ShouldStart(page,options)then return nil end
	local scriptServices=options and options.JavaScriptServices or {}
	local permissionHost=scriptServices.PermissionHost
	if permissionHost==nil and scriptServices.PermissionRequestsAllowed~=false and scriptServices.SimpleDialogHost then
		permissionHost=PermissionHost.new({Show=scriptServices.SimpleDialogHost.Show,
			CanRequest=function()return page.Alive and page.DocumentVisible~=false end,Report=diagnostic},scriptServices.PermissionStore)
		page:AddCleanup(function()permissionHost:Destroy()end)
	end
	local workerHost
	local nativeResources=page.ResourceLoadHost or ResourceLoadHost.new(page,tree,scriptServices.ResourceServices)
	if not page.ResourceLoadHost then page:AddCleanup(function()nativeResources:Destroy()end)end
	local imageResults={}
	local videoSourceSets=setmetatable({},{__mode="k"})
	local videoPosterSets=setmetatable({},{__mode="k"})
	-- Metadata reads inside one script must see earlier DOM mutations before
	-- the batched renderer flush. Ordinary text/paint changes keep this cache.
	local metadataDirty=true
	local metadataVersion=0
	local metadataNames={title=true,meta=true,base=true,link=true}
	local function metadataNode(node)
		return node.Kind=="Element"and(metadataNames[node.LocalName or node.Name]==true and(node.NamespaceURI==nil or node.NamespaceURI=="http://www.w3.org/1999/xhtml")or(node.LocalName or node.Name)=="title"and node.NamespaceURI=="http://www.w3.org/2000/svg")
	end
	local function metadataMutation(record)
		local node,withinMetadata=record.Target,false
		while node and node~=page.Document do
			withinMetadata=withinMetadata or metadataNode(node);node=node.Parent
		end
		-- Detached and shadow trees do not participate in document metadata.
		if node~=page.Document then return end
		if withinMetadata then metadataDirty=true;return end
		if record.Type=="childList"then
			local pending={}
			for _,list in {record.AddedNodes or{},record.RemovedNodes or{}}do for _,changed in list do table.insert(pending,changed)end end
			-- Inspect the edited subtrees, not the whole document. Ordinary
			-- text replacements and list edits retain the evaluated metadata.
			while #pending>0 do
				local changed=table.remove(pending)
				if metadataNode(changed)then metadataDirty=true;return end
				for _,child in changed.Children or{}do table.insert(pending,child)end
			end
		end
	end
	local function refreshMetadata()
		if not metadataDirty then return end;metadataDirty=false
		local info=DocumentInfo.collect(page.Document,page.DocumentURL,diagnostic)
		page.DocumentInfo,page.Title,page.BaseURL=info,info.Title,info.BaseURL
		page.DefaultTarget,page.Metadata=info.DefaultTarget,info.Metadata
		tree.BaseURL=info.BaseURL
		if page.Root.SetAttribute then
			for key,value in {Title=info.Title,BaseURL=info.BaseURL,DefaultTarget=info.DefaultTarget,Charset=info.Charset}do page.Root:SetAttribute(key,value)end
			page.Root:SetAttribute("ThemeColor",info.ThemeColor)
			page.Root:SetAttribute("ReferrerPolicy",info.ReferrerPolicy)
			metadataVersion+=1;page.Root:SetAttribute("MetadataVersion",metadataVersion)
		end
	end
	local getStorageArea=scriptServices.GetStorageArea
	if options and options.StorageOriginOpaque then
		getStorageArea=function() return nil end
	elseif not getStorageArea and options and options.StorageHost then
		local storageURL=options.StorageDocumentURL or page.DocumentURL
		getStorageArea=options.StorageHost:Prepare(storageURL)
		if not page.Alive then return nil end
		page:AddCleanup(options.StorageHost:Observe(storageURL,function(status,message)
			if page.Alive then page.Root:SetAttribute("StorageStatus",status);page.Root:SetAttribute("StorageError",message) end
		end))
	end
	local function spawnWorker(spec,callbacks)
		if not workerHost then
			local sources={};for key,value in scriptServices.ModuleSources or {}do sources[key]=value end
			for key,value in scriptServices.ScriptSources or {}do sources[key]=value end
			workerHost=WorkerHost.new(page.Root,sources)
		end
		return workerHost:Spawn(spec,callbacks)
	end
	local function control(node)return page.FormModel and page.FormModel:Resolve(node)end
	local function resolveControl(node)return control(node) or tree:UnrenderedControl(node)end
	local function repaintControl(node,kind)
		local c=control(node)
		if c and page.FormModel.NotifyChanged then page.FormModel:NotifyChanged(c,kind=="text" and c.Type=="output")
		elseif c and c.Item then View.paint(c.Item) end
	end
	local function setDetached(node,key,value)
		local c=resolveControl(node);assert(c,"Unknown form control")
		local temporary=FormModel.new(page.Document,{c},page.Events,function()end,true)
		if key=="checked" then temporary:SetChecked(c,value) else temporary:SetValue(c,value) end
		if key=="checked" then c.UnrenderedCheckedSet=true else c.UnrenderedValueSet=true end
		temporary:Destroy()
	end
	local function activate(node)
		local c=control(node)
		if c then page.FormModel:Activate(c,nil,true)
		elseif (ElementNames.html(node,'a')or ElementNames.html(node,'area'))and node.Attributes.href~=nil then Links.activate(page,page.Events,node,diagnostic,{isTrusted=false})
		else page.Events:Emit(node,"click",{isTrusted=false}) end
	end
	local controlAdapter={Events=page.Events,ResolveControl=resolveControl,ControlChanged=repaintControl,
		HasUserActivation=function()return (page.FormModel.UserActivationUntil or 0)>os.clock()end,
		IsRendered=function(node)
			if page.FlushScriptLayout then page:FlushScriptLayout()end
			if not ShadowTree.Connected(node,page.Document)then return false end
			local c=control(node);local box=tree.NodeBoxes[node]or(c and c.Item)
			if not box or box.Style.Hidden or box.Style.Display=='none'or box.Style.Display=='contents'then return false end
			local current=node;while current do local style=tree.NodeStyles[current];if style and style.Hidden or tree.CollapsedTableCells and tree.CollapsedTableCells[current]then return false end;current=ShadowTree.FlatParent(current)end
			return not Disclosure.hidden(node,tree.Disclosures)and not Dialog.hidden(tree,node)and not Popover.hidden(tree,node)
		end,
		ShowPicker=function(node)
			local c=control(node)
			page.FormModel.UserActivationUntil=0
			if c and c.Type=='select'and page.FormModel.OpenSelect then page.FormModel:OpenSelect(c)
			elseif c and c.Type=='color'and page.FormModel.OpenColor then page.FormModel:OpenColor(c)
			elseif c and page.FormModel.OpenTemporal then page.FormModel:OpenTemporal(c) end
		end,
		IsPickerCrossOrigin=function()return page.TopLevelDocumentOrigin~=nil and page.TopLevelDocumentOrigin~=page.DocumentOrigin end,
		GetActiveElement=function()return if page.FormModel.GetActiveElement then page.FormModel:GetActiveElement()elseif page.FormModel.Focused then page.FormModel.Focused.Node else nil end,
		SetControlValue=function(node,value)
			local c=control(node);if c then page.FormModel:SetValue(c,value)else setDetached(node,"value",value)end
		end,
		SetControlChecked=function(node,value)
			local c=control(node);if c then page.FormModel:SetChecked(c,value)else setDetached(node,"checked",value)end
		end,
		SetControlSelection=function(_,c)TextSelection.paint(c)end,
  FocusControl=function(node)
   local realm=page.JavaScriptRuntime
   if realm and realm:HasPending()and page.FlushScriptLayout then realm.Geometry:Flush()end
   if page.FocusDOMElement and page:FocusDOMElement(node)then return end
			local c=control(node);if c and page.FormModel.Focus then page.FormModel:Focus(c)end
		end,
  BlurControl=function(node)
   if page.BlurDOMElement and page:BlurDOMElement(node)then return end
			local c=control(node);if c and page.FormModel.Focused==c and page.FormModel.Focus then page.FormModel:Focus(nil)end
		end,
		ActivateControl=activate,
		ResetForm=function(form)return page.FormModel:Reset(form)end,
		RequestSubmit=function(form,submitter)local c=if submitter then control(submitter)else nil;if c and c.Type=="image" then c.ImagePoint={X=0,Y=0} end;page.FormModel:Submit(form,c,true)end,
		EventDispatch=function(node,kind,data,eventOptions)return page.Events:Emit(node,kind,data,eventOptions)end,
		RefreshControls=function()page.FormModel:RefreshControls()end,
		SaveControlState=function(node,c)tree:SaveControlState(node,c)end,
		ReportValidity=function(node,message)
			local c=control(node);if not c then if page.ReportDOMValidity then page:ReportDOMValidity(node,message)end;return end;c.UserInvalid=true;repaintControl(node,"state")
			if page.FormModel.Focus then page.FormModel:Focus(c)end
			if page.Alive and page.FormModel.ShowValidation then page.FormModel:ShowValidation(c,message)end
		end,
	}
 local runtime
	runtime=Runtime.new(page.Document,{
  BeforeRemove=function(node,preservingMove)if page.Media and page.Media.VideoBeforeRemove then page.Media:VideoBeforeRemove(node,preservingMove)end end,
  BeforeInsert=function(parent,index,count)if page.Media and page.Media.VideoBeforeInsert then page.Media:VideoBeforeInsert(parent,index,count)end end,
		HasParentBlockingStylesheets=options and options.HasParentBlockingStylesheets,
		SubscribeParentStylesheetChanges=options and options.SubscribeParentStylesheetChanges,
		DocumentLoadStateChanged=options and options.DocumentLoadStateChanged,
		GetPendingEmbeddedResources=function()return (page.IFrameRuntime and page.IFrameRuntime:PendingCount()or 0)+(page.PosterPendingCount or 0)+(page.Media and page.Media.GetPendingDocumentResources and page.Media:GetPendingDocumentResources()or 0)end,
  ParserSession=page.ParserSession,ParserFirstScript=page.ParserFirstScript,
  LoadingWork=page.LoadingWork,
  PointerCaptureAdapter=page.PointerCapture,
		URL=page.DocumentURL,Events=page.Events,States=tree.CSSStates,Schedule=schedule,ControlAdapter=controlAdapter,
		WindowHost=scriptServices.WindowHost,
		SimpleDialogHost=scriptServices.SimpleDialogHost,ConfirmLeave=scriptServices.ConfirmLeave,Visible=page.DocumentVisible,ModalsAllowed=scriptServices.ModalsAllowed,
		PermissionHost=permissionHost,MediaCaptureHost=scriptServices.MediaCaptureHost,PermissionRequestsAllowed=scriptServices.PermissionRequestsAllowed,
		DocumentOrigin=page.DocumentOrigin,
		Clock=options and options.JavaScriptServices and options.JavaScriptServices.Clock,
		IdleBudget=scriptServices.IdleBudget,
		PerformanceTimeOrigin=options and options.JavaScriptServices and options.JavaScriptServices.PerformanceTimeOrigin,
		Fetch=options and options.JavaScriptServices and options.JavaScriptServices.Fetch,
		LoadScript=options and options.JavaScriptServices and options.JavaScriptServices.LoadScript,
		LoadStylesheet=scriptServices.LoadStylesheet,Stylesheets=options and options.Stylesheets,
		ModuleSources=options and options.JavaScriptServices and options.JavaScriptServices.ModuleSources,
		ScriptSources=options and options.JavaScriptServices and options.JavaScriptServices.ScriptSources,
		ImportMap=options and options.JavaScriptServices and options.JavaScriptServices.ImportMap,
		SpawnWorker=scriptServices.SpawnWorker or spawnWorker,
		SupportsModuleWorkers=if scriptServices.SpawnWorker then scriptServices.SupportsModuleWorkers else true,
		GetStorageArea=getStorageArea,
		LoadImage=scriptServices.LoadImage or function(...)return nativeResources:LoadImage(...)end,
		LoadFont=scriptServices.LoadFont or function(...)return nativeResources:LoadFont(...)end,
		AudioAdapter=scriptServices.AudioAdapter,
		CreateAudioAdapter=function()
			return AudioHost.new(page,tree,scriptServices.AudioServices)
		end,
		AudioEmitEvent=function(node,kind)page.Events:Emit(node,kind,{}, {Bubbles=false,Cancelable=false})end,
		FontFaces=scriptServices.FontFaces,
		FontPreloadPending=page.FontPreloadPending,
		IsFontLayoutPending=function()
			local status=if page.Root.GetAttribute then page.Root:GetAttribute("Status")else nil
			return tree.LayoutInProgress==true or page.HasPendingLayout and page:HasPendingLayout()or status~=nil and status~="ready"
		end,
		DefaultLocale=scriptServices.DefaultLocale,DefaultTimeZone=scriptServices.DefaultTimeZone or scriptServices.TimeZone,
		DateNow=scriptServices.DateNow,DateLocalToUTC=scriptServices.DateLocalToUTC,TimezoneOffsetMinutes=scriptServices.TimezoneOffsetMinutes,
		ImageChanged=function(node,ok,data)
			imageResults[node]={Success=ok,Data=data}
			local record=runtime.Pending[node]or {Attributes={}};runtime.Pending[node]=record;record.ImageResource=true
		end,
		RenderedImageSize=function(node)
			local item=tree.FindImageItem and tree:FindImageItem(node)
			return if item and item.ContentWidth and item.ContentHeight then {Width=item.ContentWidth,Height=item.ContentHeight}else nil
		end,
		ImageIsRendered=function(node)return if page.ImageIsRendered then page:ImageIsRendered(node)else nil end,
		DeferImage=function(node,resume)return if page.LazyMedia then page.LazyMedia:Defer(node,'Image',resume)else nil end,
		FontChanged=function()
			-- This host maps faces to existing calibrated Roblox families. A
			-- loaded face's ordinary style consumers retain their own paint/layout.
			if page.FontResourcesChanged then page:FontResourcesChanged()end
		end,
		ResourceViewport=function()
			if page.GeometryViewport then return page:GeometryViewport()end
			local size=page.Root.AbsoluteSize;return {Width=if size then size.X else 1024,Height=if size then size.Y else 768}
		end,
		GetFiles=options and options.JavaScriptServices and options.JavaScriptServices.GetFiles,
		ObjectURLStore=options and options.JavaScriptServices and options.JavaScriptServices.ObjectURLStore,
		ObjectURLPartitionKey=options and options.JavaScriptServices and options.JavaScriptServices.ObjectURLPartitionKey,
		WebLockStore=scriptServices.WebLockStore,WebLockPartitionKey=scriptServices.WebLockPartitionKey,
		SecureContext=scriptServices.SecureContext,
		MaxObjectURLBytes=options and options.JavaScriptServices and options.JavaScriptServices.MaxObjectURLBytes,
		GetBaseURL=function()refreshMetadata();return page.BaseURL end,
		ElementGet=function(node,key)
			if ElementNames.html(node,'video')and(key=='videoWidth'or key=='videoHeight')then
				-- A src setter activates a new selection within this very script;
				-- native/GUI refresh remains batched, while exposed metadata is zero.
				if videoSourceSets[node]then return 0 end
				local w,h=0,0;if page.Media and page.Media.VideoDimensions then w,h=page.Media:VideoDimensions(node)end
				return if key=='videoWidth'then w else h
			end
			return nil
		end,
		Mutation=function(record)
   -- Source processing is semantic, including a same-value setter which has
   -- no ordinary renderer paint diff. Capture metadata before later writes.
   if page.IFrameRuntime and page.IFrameRuntime.Mutation and record.Type=='attributes'and not record.AttributeNamespace and ElementNames.html(record.Target,'iframe')and(record.AttributeName=='src'or record.AttributeName=='srcdoc')then
    -- Runtime already committed the first-base mutation before this hook.
    -- Read its evaluated URL without a metadata walk or renderer/layout flush.
    page.IFrameRuntime:Mutation(record,DocumentInfo.baseURL(page.Document,page.DocumentURL))
   end
   if page.Media and page.Media.VideoMutation then page.Media:VideoMutation(record)end
			if record.Type=='attributes'and not record.AttributeNamespace and record.AttributeName=='poster'and ElementNames.html(record.Target,'video')then
				local item=tree.MediaByNode[record.Target]
				if item and page.LoadVideoPoster then refreshMetadata();page:LoadVideoPoster(item,record.Target.Attributes.poster);videoPosterSets[record.Target]=true end
				local owner=page.JavaScriptRuntime
				if owner then local change=owner.Pending[record.Target]or{Attributes={}};owner.Pending[record.Target]=change;change.Attributes=change.Attributes or{};change.Attributes.poster=true end
			end
			if record.Type=="attributes"and not record.AttributeNamespace and record.AttributeName=="src"and ElementNames.html(record.Target,"video")and record.Target.Attributes.src~=nil then
				videoSourceSets[record.Target]=true
				-- A same-value setter still runs the media load algorithm even though
				-- the ordinary DOM renderer has no changed attribute value to paint.
				local owner=page.JavaScriptRuntime
				if owner then local change=owner.Pending[record.Target]or{Attributes={}};owner.Pending[record.Target]=change;change.Attributes=change.Attributes or{};change.Attributes.src=true end
			end
			if tree.ImageMapIndex then tree.ImageMapIndex:Mutation(record)end
			metadataMutation(record)
		end,
		Navigate=if page.Navigate then function(request)return page.Navigate(request.URL,nil,request)end else nil,
		URLChanged=function(url,kind)
			local old=page.DocumentURL;page.DocumentURL=url
			metadataDirty=true
			if page.BaseURL==old then page.BaseURL=url;tree.BaseURL=url end
			page.Root:SetAttribute("DocumentURL",url);page.Root:SetAttribute("Location",url)
			if options and options.URLChanged then options.URLChanged(url,kind)end
		end,
		ScrollToFragment=function(hash)if page.ScrollToFragment then page:ScrollToFragment(hash)end end,
		CaptureScroll=function()
			local position=page.Root.CanvasPosition;return {X=position.X,Y=position.Y}
		end,
		RestoreScroll=function(entry)
			if not page.Alive or not entry.Scroll then return end
			page.Root.CanvasPosition=Vector2.new(entry.Scroll.X,entry.Scroll.Y)
		end,
		CreateVideoAdapter=function()
   local adapter={}
   function adapter:Bind(node,state)return page.Media and page.Media.VideoBind and page.Media:VideoBind(node,state)or false end
   function adapter:Snapshot(node,state)if page.Media and page.Media.VideoSnapshot then page.Media:VideoSnapshot(node,state)end end
   function adapter:Set(node,state,key,value)return page.Media:VideoSet(node,state,key,value)end
   function adapter:SetSource(node,state,source)if page.Media and page.Media.VideoSetSource then return page.Media:VideoSetSource(node,state,source)end end
   function adapter:Command(node,state,kind)return page.Media:VideoCommand(node,state,kind)end
   function adapter:CanPlayType(value)return if page.Media and page.Media.VideoCanPlayType then page.Media:VideoCanPlayType(value)else ""end
   return adapter
  end,
		CreateGeometryAdapter=function(realm)return ScriptGeometry.new(page,tree,realm,options and options.JavaScriptServices)end,
		CreateFullscreenAdapter=function()return if tree.Factory then FullscreenHost.new(page,tree,tree.Factory,scriptServices.WindowHost,options and options.FullscreenAllowed)else nil end,
		CreateSelectionAdapter=function(realm)return ScriptSelection.new(page,tree,realm)end,
		CreateEditingAdapter=function(realm)
			local native=page.ContentEditableInput;if native then native:Bind(realm)end;return native
		end,
		CreateCSSOMAdapter=function(realm)
			local adapter={}
   function adapter:Sources(rawRoot)return tree:GetStylesheetSources(rawRoot)end
			function adapter:SetProvider(provider)tree:SetStylesheetProvider(provider)end
			function adapter:Changed()realm:StylesheetChanged()end
			function adapter:Destroy()tree:SetStylesheetProvider(nil)end
			return adapter
		end,
		CreateAnimationAdapter=function()return HTMLAnimations.scriptAdapter(page,tree,diagnostic)end,
		CreateTopLayerAdapter=function(realm)
			local adapter={}
			function adapter:Ensure()
				if page.FlushScriptLayout and (realm:HasPending() or (page.HasPendingLayout and page:HasPendingLayout()))then page:FlushScriptLayout()end
			end
			function adapter:UpdateDialog(node,state)
				local native=tree.DialogsByNode[node]
				if not native then return end
				for _,key in {"Open","Modal","ReturnValue","Order"}do native[key]=state[key]end
				Dialog.apply(tree);Dialog.arrange(tree,page.Root)
			end
			function adapter:UpdatePopover(node,state)
				local native=tree.PopoversByNode[node]
				if not native then return end
				if node.Attributes.popover==nil and node.Name~="dialog"then
					local box=native.Box;local outer=if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui
					box.TopLayer=nil;outer.Parent=box.TopLayerParent or page.Root;box.TopLayerParent=nil
					TopLayerLayout.flags(tree,box,false,false,false)
					box.TopLayerPaintX,box.TopLayerPaintY=nil,nil;outer.Visible=not box.Style.Hidden
				end
				for _,key in {"Open","Order","Mode"}do native[key]=state[key]end
				Popover.apply(tree);Popover.arrange(tree,page.Root)
			end
			function adapter:GetActiveElement()return page.FormModel:GetActiveElement()end
			function adapter:Focus(node,kind)if page.FocusTopLayer then page:FocusTopLayer(node,kind)end end
			function adapter:ContainsPoint(node,position)
				if tree.IsContentSkipped and tree:IsContentSkipped(node)then return false end
				local box=tree.NodeBoxes[node];local gui=box and box.Gui
				if not gui then return false end
				local origin,size=gui.AbsolutePosition,gui.AbsoluteSize
				return position.X>=origin.X and position.X<origin.X+size.X and position.Y>=origin.Y and position.Y<origin.Y+size.Y
			end
			function adapter:Changed(kind,node)
				if page.TopLayerChanged then page:TopLayerChanged(kind,node)end
			end
			return adapter
		end,
		CreateCanvasAdapter=function()
			local adapter={}
			local function native()return page:EnsureCanvasRuntime()end
			function adapter:Surface(node,create)
				if not page.CanvasRuntime and create==false then return nil end
				return native():Surface(node,create)
			end
			function adapter:Reset(node,w,h)return native():Reset(node,w,h)end
			function adapter:Publish(node)native():Publish(node)end
			function adapter:ImageSource(node)local owner=native();return if owner.ImageSource then owner:ImageSource(node)else nil end
			return adapter
		end,
		Diagnostic=diagnostic,Console=scriptServices.Console or function(level,message)
			if level=="error" or level=="warn" then warn("JavaScript: " .. message) else print("JavaScript: " .. message) end
		end,
		GetControl=function(node,key)
			local c=control(node) or tree:UnrenderedControl(node);if not c then return VM.Undefined end
			return if key=="checked" then c.Checked else c.Value
		end,
		SetControl=function(node,key,value)
			local c=control(node)
			if not c then
				c=tree:UnrenderedControl(node);assert(c,"Unknown form control")
				local temporary=FormModel.new(page.Document,{c},page.Events,function()end,true)
				if key=="checked" then temporary:SetChecked(c,VM.truth(value)) else temporary:SetValue(c,VM.string(value)) end
				if key=="checked" then c.UnrenderedCheckedSet=true else c.UnrenderedValueSet=true end
				temporary:Destroy()
				return
			end
			if key=="checked" then page.FormModel:SetChecked(c,VM.truth(value)) else page:SetValue(node,VM.string(value)) end
		end,
		Click=activate,
		ValidateAttribute=function(node,key)
			if not tree.NodeStyles[node] then return end
			if key=="hidden" and not tree.NodeBoxes[node] and not MediaContent.contents(node)and not ElementNames.html(node,'map')then
				local owner=tree:TextOwner(node)
				assert(owner and owner.CanRefreshText and owner:CanRefreshText(),"Changing inline visibility inside mixed/replaced content needs structural reconciliation")
			end
			-- Every valid attribute can affect selectors or generated content,
			-- including author-defined names. The data DOM validates syntax and
			-- specialized adapters validate their own state; an allowlist here
			-- would reject otherwise ordinary live HTML mutations.
		end,
		ValidateText=function(node)
			local element=if node.Kind=="Text" or node.Kind=="Comment" then node.Parent else node
			if element and not tree.NodeStyles[element] then return end
			local c=control(element)
			local name=ElementNames.htmlName(element)
			if c and (name=="button" or name=="output") then return end
			-- The DOM setter replaces element children through ValidateStructure
			-- and the resource-owning reconciler. Only a plain text replacement
			-- belongs to the inline fast path. Custom data-DOM host hooks retain
			-- their own preflight contract.
			if node.Kind=='Element'then for _,child in node.Children do if child.Kind=='Element'then return end end end
			tree:ValidateTextMutation(node)
		end,
		ValidateStructure=function(parent,node,oldParent)tree:ValidateStructure(parent,node,oldParent)end,
		ApplyChanges=function(changes)
			if page.SelectionCopyInput then page.SelectionCopyInput:Invalidate()end
			local mediaPublication=page.Media
			local publication=if mediaPublication and mediaPublication.BeginVideoPublication then mediaPublication:BeginVideoPublication()else nil
			local applied=table.pack(pcall(function()
			refreshMetadata()
			local content,controlItems={},{}
			local focusChanged,audioControlsChanged,inputTypesChanged=false,false,false
			for node,change in changes do
				local element=if node.Kind=="Text" or node.Kind=="Comment" then node.Parent else node
				local name=ElementNames.htmlName(element)
				local attributes=change.Attributes or{};if change.Children or attributes.contenteditable or attributes.tabindex or attributes.inert or attributes.href and(name=='a'or name=='area')or name=='img'and attributes.usemap or name=='map'and(attributes.name or attributes.id)then focusChanged=true end
				if name=='input'and attributes.type and not MediaContent.contents(element)then inputTypesChanged=true end
				local c=control(element)
				if change.Text and c and not c.Item.RichButton and (name=="button" or name=="output") then
					local previous=if name=="button" then c.Caption else c.Value
					if name=="button" then c.Caption=DOM.textContent(element):gsub("%s+"," "):match("^%s*(.-)%s*$")
					else c.Value=DOM.textContent(element) end
					View.paint(c.Item)
					local style=c.LayoutStyle or c.Item.Style
					local current=if name=="button" then c.Caption else c.Value
					if current~=previous or (name=="button" and style.WhiteSpaceCollapse~="collapse") then
						-- The measurement key already includes the rendered caption.
						controlItems[c.Item]=true
					end
					-- Text also changes :empty/:has and related selector state, even
					-- when native whitespace normalization paints the same caption.
					content[node]={Text=true,NativeControlText=true,Attributes=change.Attributes,OldAttributes=change.OldAttributes}
				else
					if c and name=="input" and attributes.value and (c.Type=="button" or c.Type=="submit" or c.Type=="reset") then
						local caption=node.Attributes.value or (if c.Type=="submit" then "Submit"elseif c.Type=="reset" then "Reset"else "")
						if caption~=c.Caption then c.Caption=caption;View.paint(c.Item);controlItems[c.Item]=true end
					end
					content[node]=change
				end
			end
			-- Showing audio controls adds a replaced box; hiding them removes it.
			-- This is a render reconciliation, not a DOM child mutation/observer.
			for node,change in changes do
				if ElementNames.html(node,"audio")and not MediaContent.contents(node)and change.Attributes and change.Attributes.controls and node.Parent then
					local parent=content[node.Parent]or {};content[node.Parent]=parent;parent.Children=true;parent.RenderChildren=true;audioControlsChanged=true
				end
			end
			local deferredContentRevision=tree.DeferredContentRevision
			local layout,items,transformOnly=tree:ApplyDOMChanges(content)
			local builtDeferredContents=deferredContentRevision~=tree.DeferredContentRevision
			for node,change in changes do
				local attributes=change.Attributes
				if ElementNames.html(node,"video")and attributes and(attributes.controls or attributes.src or attributes.loop or attributes.preload or attributes.autoplay or attributes.poster or attributes.loading or attributes.width or attributes.height or attributes.playsinline)then
					local sourceSet=videoSourceSets[node]==true;videoSourceSets[node]=nil
					local item=tree:RefreshMediaResource(node,attributes,sourceSet)
					if item and page.Media and page.Media.Refresh then page.Media:Refresh(item,attributes,sourceSet)end
					if item and attributes.poster and not videoPosterSets[node]and page.LoadVideoPoster then page:LoadVideoPoster(item,node.Attributes.poster)end
					videoPosterSets[node]=nil
				end
			end
			local images={}
			for node,change in changes do
				local name=ElementNames.htmlName(node)
				local onlyUseMap=change.Attributes and change.Attributes.usemap and not change.ImageResource
				if onlyUseMap then for key in change.Attributes do if key~='usemap'then onlyUseMap=false;break end end end
				if (name=="img"or name=="input"and(node.Attributes.type or ""):lower()=="image") and (change.Attributes or change.ImageResource)and not onlyUseMap then images[node]=true end
			end
			for node in images do
				local item,_,_,geometry
				if page.RefreshImageResource then item,geometry=page:RefreshImageResource(node)
				elseif tree.RefreshImageResource then item,_,_,geometry=tree:RefreshImageResource(node)end
				local result=imageResults[node];imageResults[node]=nil
				if item and result and result.Success then
					local data=result.Data
					geometry=geometry or item.IntrinsicWidth~=data.Width or item.IntrinsicHeight~=data.Height
					item.IntrinsicWidth,item.IntrinsicHeight=data.Width,data.Height
				end
				if item and geometry then items[item]=true;layout=true end
			end
			local topLayer=page.JavaScriptRuntime and page.JavaScriptRuntime.TopLayer
			if topLayer then
				-- DOM reconciliation may retain a native box, replace it, or create a
				-- new top-layer host. The realm remains the owner of API state.
				for _,native in tree.Dialogs do
					local state=topLayer:Snapshot(native.Node)
					native.Open,native.Modal,native.ReturnValue,native.Order=state.Open,state.Modal,state.ReturnValue,state.DialogOrder
				end
				for _,native in tree.Popovers do
					local state=topLayer:Snapshot(native.Node)
					native.Open,native.Mode,native.Order=state.PopoverOpen,state.Mode,state.Order
				end
				Dialog.apply(tree);Popover.apply(tree)
				if page.TopLayerChanged then page:TopLayerChanged("dialog");page:TopLayerChanged("popover")end
			end
			local structural=false;for node,change in changes do if change.Children and not change.ImageMapData and not MediaContent.data(node)then structural=true;break end end
			if structural or audioControlsChanged or inputTypesChanged or builtDeferredContents then
				if page.RefreshDOMResources then page:RefreshDOMResources()end
				if page.RefreshDOMControls then page:RefreshDOMControls() elseif page.FormModel.RefreshControls then page.FormModel:RefreshControls() end
				if page.JavaScriptRuntime and page.JavaScriptRuntime.DOM.Controls then page.JavaScriptRuntime.DOM.Controls:RefreshNativeRecords()end
			end
			if not structural and not audioControlsChanged and page.RefreshControlPickers then page:RefreshControlPickers()end
			if focusChanged and page.RefreshDOMFocus then page:RefreshDOMFocus()end
			if not focusChanged and page.RefreshImageMapFocus then page:RefreshImageMapFocus()end
			if page.ContentEditableInput then page.ContentEditableInput:Sync()end
			if page.RefreshPointerGeometry then page:RefreshPointerGeometry()end
			if page.LazyMedia then page.LazyMedia:Check()end
			if page.FullscreenPresentation then page.FullscreenPresentation:Refresh()end
			for item in controlItems do items[item]=true end
			if not transformOnly then CanvasBackground.apply(page.Root,page.Document,tree.NodeStyles,tree.CanvasBackgroundState) end
			if not layout and tree.SelectionCopyChanged then tree.SelectionCopyChanged()end
			return layout or next(controlItems)~=nil,items
			end))
			local closed=table.pack(pcall(function()
				if publication~=nil then mediaPublication:EndVideoPublication(publication)end
			end))
			-- Preserve the first original payload, including nil/false/table.
			if not applied[1]then error(applied[2],0)end
			if not closed[1]then error(closed[2],0)end
			return table.unpack(applied,2,applied.n)
		end,
	})
	page.FormModel.ValidateForm=function(form)
		return runtime:ReportFormValidity(form)
	end
	if page.Alive==false then runtime:Destroy();if workerHost then workerHost:Destroy()end;return nil end
	page.JavaScriptRuntime=runtime
	page:AddCleanup(function()page.FormModel.ValidateForm=nil;runtime:Destroy();if workerHost then workerHost:Destroy()end;tree:ForgetDetachedControlState()end)
	if scriptServices.RuntimeCreated then scriptServices.RuntimeCreated(runtime,page)end
	if not runtime.Alive or page.Alive==false then return nil end
	runtime:InitializeVisibility(page.DocumentVisible~=false)
	if game or (options and options.JavaScriptServices) then
		page.ScriptClock=ScriptClock.start(page,tree,runtime,options and options.JavaScriptServices,afterFrame)
	end
	runtime:Start()
	if not runtime.Alive or page.Alive==false then return nil end
	-- Initial patterns, radio peers and custom errors use the same validity
	-- flags for querying and the retained renderer, before the first frame.
	if page.RefreshDOMControls then page:RefreshDOMControls()end
	return runtime
end
return HTMLScripts
