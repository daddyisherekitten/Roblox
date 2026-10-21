--!strict
local WorkContext=require(script.Parent.Parent.WorkContext)
local Parser = require(script.Parent.Parent.HTML.Parser)
local DocumentInfo = require(script.Parent.Parent.HTML.DocumentInfo)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local NativeMediaResources=require(script.Parent.NativeMediaResources)
local NativeImageResources=require(script.Parent.NativeImageResources)
local Factory = require(script.Parent.GuiFactory)
local RenderTree = require(script.Parent.RenderTree)
local BlockLayout = require(script.Parent.Parent.Layout.BlockLayout)
local ScrollLayout = require(script.Parent.Parent.Layout.ScrollLayout)
local LengthExpression = require(script.Parent.Parent.CSS.LengthExpression)
local PageSession = require(script.Parent.Parent.PageSession)
local FontProfiles = require(script.Parent.Parent.Layout.FontProfiles)
local FontPreload = require(script.Parent.FontPreload)
local ResourceLoadHost = require(script.Parent.ResourceLoadHost)
local MediaBox = require(script.Parent.MediaBox)
local DecorationPatterns = require(script.Parent.DecorationPatterns)
local InsetShadows = require(script.Parent.InsetShadows)
local BackgroundImages = require(script.Parent.BackgroundImages)
local BorderCorners = require(script.Parent.BorderCorners)
local ImageSources = require(script.Parent.ImageSources)
local MediaSources = require(script.Parent.MediaSources)
local ImageLoad = require(script.Parent.ImageLoad)
local ImageDimensions = require(script.Parent.ImageDimensions)
local ShapeImages = require(script.Parent.ShapeImages)
local ImageFilters = require(script.Parent.ImageFilters)
local FontFamily = require(script.Parent.Parent.CSS.FontFamily)
local WordLayout = require(script.Parent.Parent.Layout.WordLayout)
local GroupOpacity = require(script.Parent.GroupOpacity)
local InputController = require(script.Parent.Parent.Input.Controller)
local CursorPreload = require(script.Parent.Parent.Input.CursorPreload)
local DirtyLayout = require(script.Parent.Parent.Layout.DirtyLayout)
local DOM = require(script.Parent.Parent.DOM.Node)
local ShadowTree = require(script.Parent.Parent.DOM.ShadowTree)
local URL = require(script.Parent.Parent.Navigation.URL)
local ControlView = require(script.Parent.Parent.Controls.View)
local RadioDot = require(script.Parent.RadioDot)
local DisclosureIcons = require(script.Parent.DisclosureIcons)
local ResizeGrip = require(script.Parent.ResizeGrip)
local IFrameRuntime = require(script.Parent.IFrameRuntime)
local CanvasBackground = require(script.Parent.CanvasBackground)
local Dialog = require(script.Parent.Dialog)
local Popover = require(script.Parent.Popover)
local TextMeasure = require(script.Parent.Parent.Layout.TextMeasure)
local HTMLAnimations = require(script.Parent.HTMLAnimations)
local ViewportLayer = require(script.Parent.ViewportLayer)
local LayoutJob = require(script.Parent.LayoutJob)
local HTMLScripts = require(script.Parent.HTMLScripts)
local LazyMedia = require(script.Parent.LazyMedia)
local HTMLPage = {}
local RESIZE_INTERVAL = 1 / 60
local VIEWPORT_RESIZE_ATTRIBUTE = "HTMLViewportResizing"

local function mountDocument(target: GuiObject, html: string, options: any?,work: any?,mountOwner: any)
	local documentURL = if options then options.DocumentURL else nil
	assert(not options or options.JavaScript==nil or type(options.JavaScript)=="boolean","options.JavaScript must be a boolean")
	assert(not options or options.ByteSource==nil or type(options.ByteSource)=='boolean','options.ByteSource must be a boolean')
	assert(not options or options.DocumentEncoding==nil or type(options.DocumentEncoding)=='table','options.DocumentEncoding must be a dictionary')
	assert(documentURL == nil or (type(documentURL) == "string" and documentURL ~= ""), "options.DocumentURL must be a non-empty URL string")
	assert(not options or options.IsSrcdoc==nil or type(options.IsSrcdoc)=='boolean','options.IsSrcdoc must be a boolean')
	assert(not options or options.FallbackBaseURL==nil or(type(options.FallbackBaseURL)=='string'and options.FallbackBaseURL~=''),'options.FallbackBaseURL must be a non-empty URL string')
	local css = if options then options.CSS else nil
	assert(css == nil or type(css) == "string", "options.CSS must be a CSS string")
	local stylesheets = if options then options.Stylesheets else nil
	assert(stylesheets == nil or type(stylesheets) == "table", "options.Stylesheets must map href strings to CSS strings")
	for href, source in stylesheets or {} do
		assert(type(href) == "string" and href ~= "" and type(source) == "string", "options.Stylesheets must map non-empty href strings to CSS strings")
	end
	local navigate = if options then options.Navigate else nil
	assert(navigate == nil or type(navigate) == "function", "options.Navigate must be a function")
	local iframeResolver = if options then options.IFrameResolver else nil
	assert(iframeResolver == nil or type(iframeResolver) == "function", "options.IFrameResolver must be a function")
	local iframeDepth = if options then options.IFrameDepth else nil
	assert(iframeDepth == nil or (type(iframeDepth) == "number" and iframeDepth == math.floor(iframeDepth) and iframeDepth >= 0 and iframeDepth <= 4), "options.IFrameDepth must be an integer from 0 to 4")
	local svgCacheBytes=if options then options.SVGCacheBytes else nil
	local svgCacheEntries=if options then options.SVGCacheEntries else nil
	local svgPrewarmStates=if options then options.SVGPrewarmStates else nil
	local renderWorkBudgetMS=if options and options.RenderWorkBudgetMS~=nil then options.RenderWorkBudgetMS else 4
	local configuredMediaFeatures=if options then options.MediaFeatures else nil
	assert(configuredMediaFeatures==nil or type(configuredMediaFeatures)=="table","options.MediaFeatures must be a table")
	assert(svgCacheBytes==nil or (type(svgCacheBytes)=='number' and svgCacheBytes==math.floor(svgCacheBytes) and svgCacheBytes>=0 and svgCacheBytes<=256*1024*1024),'options.SVGCacheBytes must be an integer from 0 to 268435456')
	assert(svgCacheEntries==nil or (type(svgCacheEntries)=='number' and svgCacheEntries==math.floor(svgCacheEntries) and svgCacheEntries>=0 and svgCacheEntries<=256),'options.SVGCacheEntries must be an integer from 0 to 256')
	assert(svgPrewarmStates==nil or (type(svgPrewarmStates)=='number' and svgPrewarmStates==math.floor(svgPrewarmStates) and svgPrewarmStates>=0 and svgPrewarmStates<=64),'options.SVGPrewarmStates must be an integer from 0 to 64')
	assert(type(renderWorkBudgetMS)=='number'and renderWorkBudgetMS==renderWorkBudgetMS and renderWorkBudgetMS>=0 and renderWorkBudgetMS<=16,'options.RenderWorkBudgetMS must be a number from 0 to 16')
	CursorPreload.start()
	local defaultFont = FontFamily.default(if options then options.DefaultFont else nil)
	local resolveImage = ImageSources.newResolver(if options then options.Images else nil)
	local resolveSVG = ImageSources.newSVGResolver(if options then options.SVGs else nil)
	local mediaSources=MediaSources.new(if options then options.Audio else nil,if options then options.Videos else nil,if options then options.Tracks else nil)
	local document
	local root = Factory.create("ScrollingFrame", target, {
		Name = "WebsiteScrollingFrame", Size = UDim2.fromScale(1, 1),
		Visible = false,
		BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1),
		CanvasSize = UDim2.fromOffset(0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always,
	}) :: ScrollingFrame
	if options and options.ScrollBarThickness ~= nil then
		local thickness = options.ScrollBarThickness
		assert(type(thickness) == "number" and thickness % 1 == 0 and thickness >= 0 and thickness <= 50,
			"options.ScrollBarThickness must be an integer from 0 to 50")
		root.ScrollBarThickness = thickness
	end
	local page = PageSession.new(root)
	page.DocumentVisible=not(options and options.JavaScriptServices and options.JavaScriptServices.Visible==false)
	local stylesheetListeners={};local stylesheetSubscription
	page.ScriptInitializationPending=true
 -- Document completion is separate from atomic initial presentation. A
 -- page without a VM still owns media/poster/frame load contributions.
 local nativeDocumentComplete=false
 local documentLoadQueued=false
 local documentLoadGeneration=1
 local documentLoadCallback=options and options.DocumentLoadStateChanged
 local function pendingDocumentResources()
  return (page.NativeMediaResources and page.NativeMediaResources.Pending or 0)
   +(page.Media and page.Media.GetPendingDocumentResources and page.Media:GetPendingDocumentResources()or 0)
   +(page.NativeImageResources and(page.NativeImageResources.Pending+(if page.NativeImageResources.DiscoveryDepth>0 then 1 else 0))or 0)
   +(page.PosterPendingCount or 0)
   +(page.IFrameRuntime and page.IFrameRuntime:PendingCount()or 0)
 end
 function page:IsDocumentComplete(): boolean
  if not self.Alive then return false end
  if self.JavaScriptRuntime then return self.JavaScriptRuntime:IsDocumentComplete()end
  return nativeDocumentComplete
 end
 function page:DocumentResourcesChanged()
  if not self.Alive then return end
  if self.JavaScriptRuntime then self.JavaScriptRuntime:ResourcesChanged();return end
  if self.ScriptInitializationPending or nativeDocumentComplete or documentLoadQueued or pendingDocumentResources()>0 then return end
  documentLoadQueued=true;local generation=documentLoadGeneration
  task.defer(function()
   if not page.Alive or documentLoadGeneration~=generation then return end
   documentLoadQueued=false
   if page.JavaScriptRuntime then page.JavaScriptRuntime:ResourcesChanged();return end
   -- A newer source or nested frame can start after this task was queued.
   if page.ScriptInitializationPending or nativeDocumentComplete or pendingDocumentResources()>0 then return end
   nativeDocumentComplete=true
   if documentLoadCallback then documentLoadCallback('complete')end
  end)
 end
 page:AddCleanup(function()documentLoadGeneration+=1;documentLoadQueued=false;documentLoadCallback=nil end)
	function page:HasOwnBlockingStylesheets()
		if not self.Alive then return false end
		if self.ScriptInitializationPending then return true end
		if self.JavaScriptRuntime then return self.JavaScriptRuntime:HasOwnBlockingStylesheets()end
		return false
	end
	function page:SubscribeStylesheetChanges(callback)
		stylesheetListeners[callback]=true;return function()stylesheetListeners[callback]=nil end
	end
	local function notifyStylesheets()
		local listeners={};for callback in stylesheetListeners do table.insert(listeners,callback)end
		for _,callback in listeners do if page.Alive and stylesheetListeners[callback]then callback()end end
	end
	page:AddCleanup(function()if stylesheetSubscription then stylesheetSubscription();stylesheetSubscription=nil end;table.clear(stylesheetListeners)end)
	page.BuildStats={ParseMS=0,MetadataMS=0,TreeMS=0,ScriptsMS=0}
	mountOwner.Page=page
	page.LoadingWork=work
	if work then page:AddCleanup(function()work:Finish()end)end
	-- Staging is local to a newly mounted document. Keep its measured viewport
	-- intact, but hide unfinished descendants before any builder can yield.
	local blankOK, blank = pcall(Factory.create, "Frame", target, {
		Name = "HTMLLoadingSurface", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1),
		Active = false, Visible = true,
	})
	if not blankOK then page:Destroy(); error(blank) end
	page:AddCleanup(function() if blank then blank:Destroy(); blank = nil end end)
	root:SetAttribute("Presented", false)
	root:SetAttribute("Status", "loading")
	local parseStarted=os.clock()
	local parserOptions=if options and options.ByteSource then table.clone(options.DocumentEncoding or{})else{}
	parserOptions.ScriptingEnabled=not options or options.JavaScript~=false
	if options then parserOptions.IsSrcdoc=options.IsSrcdoc;parserOptions.FallbackBaseURL=options.FallbackBaseURL end
	if options and options.ContentLanguage~=nil then parserOptions.ContentLanguage=options.ContentLanguage end
	if options and options.ByteSource then
		local parser=if parserOptions.ScriptingEnabled then Parser.newDocumentBytes(html,parserOptions)else nil
		if parser then
			page.ParserFirstScript=parser:Advance();page.ParserSession=parser;document=parser.Document
			page:AddCleanup(function()parser:Destroy()end)
		else document=Parser.parseDocumentBytes(html,parserOptions)end
	elseif parserOptions.ScriptingEnabled then
		local parser=Parser.newDocument(html,parserOptions)
		page.ParserFirstScript=parser:Advance();page.ParserSession=parser;document=parser.Document
		page:AddCleanup(function()parser:Destroy()end)
	else document=Parser.parseDocument(html,parserOptions)end
	page.BuildStats.ParseMS=(os.clock()-parseStarted)*1000
	page.Document = document
	page.Navigate = navigate
	page.ResolveImage = resolveImage
	page.ResolveSVG = resolveSVG
	page.ResolveAudio=function(source: string): string? return mediaSources:Asset("audio",source) end
	page.ResolveVideo=function(source: string): string? return mediaSources:Asset("video",source) end
	page.ResolveTrack=function(source: string): string? return mediaSources:Track(source) end
	local function diagnostic(message: string)
		if #document.Diagnostics < 100 then
			table.insert(document.Diagnostics, { Code = "render-subset", Message = message, Position = 0 })
		else document.DiagnosticsTruncated = true end
	end
	local metadataStarted=os.clock()
	local info = DocumentInfo.collect(document, documentURL, diagnostic)
	page.BuildStats.MetadataMS=(os.clock()-metadataStarted)*1000
	page.DocumentInfo = info
	page.Title = info.Title
	page.DocumentURL = info.DocumentURL
	page.DocumentOrigin=require(script.Parent.Parent.DOM.DocumentOrigin).ensure(document,page.DocumentURL,options and options.DocumentOrigin,options and options.DocumentOriginOpaque)
	page.TopLevelDocumentOrigin=if options and options.TopLevelDocumentOrigin~=nil then options.TopLevelDocumentOrigin else page.DocumentOrigin
	page.BaseURL = info.BaseURL
	page.DefaultTarget = info.DefaultTarget
	page.Metadata = info.Metadata
	root:SetAttribute("Title", info.Title)
	root:SetAttribute("DocumentURL", info.DocumentURL)
	root:SetAttribute("BaseURL", info.BaseURL)
	root:SetAttribute("DefaultTarget", info.DefaultTarget)
	root:SetAttribute("Charset", info.Charset)
	if info.ThemeColor then root:SetAttribute("ThemeColor", info.ThemeColor) end
	if info.ReferrerPolicy then root:SetAttribute("ReferrerPolicy", info.ReferrerPolicy) end
	local resolveFont = FontProfiles.newResolver()
	local patterns = DecorationPatterns.new(function(message) diagnostic(message); warn(message) end)
	page:AddCleanup(function() patterns:Destroy() end)
	local insets = InsetShadows.new(function(message) diagnostic(message); warn(message) end)
	page:AddCleanup(function() insets:Destroy() end)
	local backgrounds = BackgroundImages.new(function(message) diagnostic(message); warn(message) end,resolveImage,nil,root,{ResolveSVG=resolveSVG,LoadingWork=work,CacheBytes=svgCacheBytes,CacheEntries=svgCacheEntries,Resolution=configuredMediaFeatures and configuredMediaFeatures.Resolution or 1})
	page:AddCleanup(function() backgrounds:Destroy() end)
	local fixedBackgroundScroll=root:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if page.Alive then backgrounds:RefreshFixed() end
	end)
	page:AddCleanup(function() fixedBackgroundScroll:Disconnect() end)
	local corners = BorderCorners.new(function(message) diagnostic(message); warn(message) end)
	page:AddCleanup(function() corners:Destroy() end)
	local radioDot = RadioDot.new(diagnostic)
	page:AddCleanup(function() radioDot:Destroy() end)
	local disclosureIcons = DisclosureIcons.new(diagnostic)
	page:AddCleanup(function() disclosureIcons:Destroy() end)
	local resizeGrip = ResizeGrip.new(diagnostic)
	page:AddCleanup(function() resizeGrip:Destroy() end)
	local inputService: any? = nil
	pcall(function() inputService = game:GetService("UserInputService") end)
	local function currentMediaFeatures(): any
		local mouse = inputService and inputService.MouseEnabled == true
		local touch = inputService and inputService.TouchEnabled == true
		local result = {
			Hover = mouse, AnyHover = mouse,
			Pointer = if mouse then "fine" elseif touch then "coarse" else "none",
			AnyPointers = {fine = mouse, coarse = touch},
			ReducedMotion=false,PreferredColorScheme='light',
			Scripting=if options and options.JavaScript==false then 'none'else 'enabled',
		}
		pcall(function() result.ReducedMotion=game:GetService('GuiService').ReducedMotionEnabled end)
		for key,value in configuredMediaFeatures or {} do result[key]=value end
		return result
	end
	local mediaFeatures=currentMediaFeatures()
	local treeStarted=os.clock()
	local success, tree = pcall(RenderTree.build, document, root, diagnostic, resolveFont, patterns, insets, resolveImage, css, defaultFont, corners, radioDot, resizeGrip, stylesheets, info.BaseURL,mediaSources,mediaFeatures,backgrounds,disclosureIcons,resolveSVG)
	page.BuildStats.TreeMS=(os.clock()-treeStarted)*1000
	if not success then page:Destroy(); error(tree) end
	page.LazyMedia=LazyMedia.new(page,tree,{Task=task,ScriptingEnabled=not options or options.JavaScript~=false,Margin=options and options.LazyMediaMargin})
	page:AddCleanup(function()page.LazyMedia:Destroy()end)
	page:AddCleanup(function()if tree.ImageMapIndex then tree.ImageMapIndex:Destroy()end end)
	page:AddCleanup(function()if tree.DestroyCanvasBackground then tree:DestroyCanvasBackground()end end)
	tree.PresentationHidden = true
	if tree.EnablePendingPresentation then tree:EnablePendingPresentation()end
	page:AddCleanup(function() ScrollLayout.destroyTree(tree) end)
	if tree.VisualEffects then page:AddCleanup(function() tree.VisualEffects:Destroy() end) end
	Dialog.attachViewport(tree,root)
	if tree.DialogHost then page:AddCleanup(function() Dialog.destroyHost(tree) end) end
	Popover.attachViewport(tree,root)
	if tree.PopoverHost then page:AddCleanup(function() Popover.destroyHost(tree) end) end
	ViewportLayer.attach(tree,root,Factory)
	page:AddCleanup(function() ViewportLayer.destroy(tree) end)
	CanvasBackground.apply(root, document, tree.NodeStyles,tree.CanvasBackgroundState)
	local pendingWidth: number? = nil
	local requestedWidth: number? = nil
	local requestedHeight: number? = nil
	local running,forcedLayout = false,false
	local lastLayout = -math.huge
	local function viewportResizing(): boolean
		return target:GetAttribute(VIEWPORT_RESIZE_ATTRIBUTE) == true
	end
	local resizeActive = viewportResizing()
	local function resizeHeld(): boolean
		-- The live attribute leads deferred Roblox signals; the cached value
		-- keeps workers waiting until the release callback has queued recovery.
		return resizeActive or viewportResizing()
	end
	local pendingImmediate = false
	local pendingFull = false
	local pendingDirty = {}
	local layoutRevision = 0
	local requestLayout
	local resizeTimer: thread? = nil
	page:AddCleanup(function()
		if resizeTimer then task.cancel(resizeTimer); resizeTimer = nil end
	end)
	local function alive() return page.Alive end
	-- Resource selection reads committed content geometry only; it never forces
	-- reflow from inside selection, and transforms/object-fit do not change it.
	function page:ImageIsRendered(node)
		if not self.Alive or not ShadowTree.Connected(node,document)then return nil end
		if not self.ImageLayoutReady or tree.LayoutInProgress or tree.LayoutNeedsRecovery then return false end
		local current=node
		while current and current~=document do
			local style=tree.NodeStyles[current]
			if style and(style.Hidden or style.Display=='none')then return nil end
			current=ShadowTree.FlatParent(current)or current.Parent
		end
		local item=tree:FindImageItem(node)
		return if item and item.ContentWidth~=nil and item.ContentHeight~=nil then{Width=item.ContentWidth,Height=item.ContentHeight}else nil
	end
	local function publishImageLayout()
		page.ImageLayoutReady=true
		local runtime=page.JavaScriptRuntime
		local images=runtime and runtime.ImageResources or page.NativeImageResources
		if images and images.AfterLayout then
			if runtime then runtime:ImageLayoutCompleted()else images:AfterLayout()end
		end
	end
	local canvasServices=table.clone(if options then options.CanvasServices or {}else {})
	canvasServices.HostOnly=(not options or options.JavaScript~=false)and HTMLScripts.hasScripts(document)
	function page:EnsureCanvasRuntime()
		assert(self.Alive,'Canvas page disposed')
		if not self.CanvasRuntime then require(script.Parent.CanvasRuntime).start(self,tree,diagnostic,canvasServices,renderWorkBudgetMS)end
		return self.CanvasRuntime
	end
 local svgRuntime=nil
 -- RenderTree-only consumers retain prepared poster metadata. The actual
 -- page registers only decoded posters, through its independent image lease.
 local function discardPreparedPosterSVG()
  for at=#(tree.SVGItems or{}),1,-1 do if tree.SVGItems[at].PreparedPoster then table.remove(tree.SVGItems,at)end end
 end
 discardPreparedPosterSVG()
 if tree.TakeStructuralResourceChanges then tree:TakeStructuralResourceChanges()end
 if tree.SVGItems and #tree.SVGItems>0 then
  local ok,err=pcall(function() svgRuntime=require(script.Parent.SVGImages).start(page,tree,diagnostic,{CacheBytes=svgCacheBytes,CacheEntries=svgCacheEntries,PrewarmStates=svgPrewarmStates,WorkBudgetMS=renderWorkBudgetMS}) end)
  if not ok then page:Destroy();error(err) end
 end
	if tree.CanvasItems and #tree.CanvasItems>0 then
		local ok,err=pcall(function()page:EnsureCanvasRuntime()end)
		if not ok then page:Destroy();error(err) end
	end
	-- Asset/script initialization may yield while the owner is destroyed.
	if not page.Alive then return page end
	local syncViewport=ViewportLayer.start(page,tree,root,if options then options.AnimationServices else nil)
	local motionRuntime=HTMLAnimations.start(page,tree,diagnostic,if options then options.AnimationServices else nil,renderWorkBudgetMS,syncViewport)
	page.FontPreloadPending=tree.FontPreloadTargets~=nil and #tree.FontPreloadTargets>0
	FontPreload.start(tree.FontPreloadTargets, alive, diagnostic,function()
		page.FontPreloadPending=false
		if page.JavaScriptRuntime then page.JavaScriptRuntime:FontPreloadCompleted()end
	end)
	local pendingPaint = {}
	local pendingFragment: string? = nil
	local fragmentTween: any?=nil
	local function fragmentPosition(position: Vector2)
		if fragmentTween then fragmentTween:Cancel();fragmentTween=nil end
		local smooth=false
		for node,style in tree.NodeStyles or {} do if node.Name=="html" then smooth=style.ScrollBehavior=="smooth";break end end
		if smooth then
			local ok,service=pcall(function()return game:GetService("TweenService")end)
			if ok and service then
				fragmentTween=service:Create(root,TweenInfo.new(.24,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{CanvasPosition=position})
				fragmentTween:Play();return
			end
		end
		root.CanvasPosition=position
	end
	page:AddCleanup(function()if fragmentTween then fragmentTween:Cancel();fragmentTween=nil end end)
	local function fragmentGui(node: any): any?
		local box = tree.NodeBoxes and tree.NodeBoxes[node]
		if box then return box.Gui end
		for gui, hitNode in tree.HitNodes do
			local current = hitNode
			while current do if current == node then return gui end; current = current.Parent end
		end
		return nil
	end
	local function fragmentSpacing(value: any,basis: number): number
		if type(value)=="number" then return value end
		return if value then LengthExpression.resolve(value,basis) else 0
	end
	local function scrollRootToFragment(node: any,gui: any)
		local rootStyle
		for candidate,style in tree.NodeStyles or {} do
			if candidate.Name=="html" then rootStyle=style;break end
		end
		local rootPadding=fragmentSpacing(rootStyle and rootStyle.ScrollPadding and rootStyle.ScrollPadding[1],root.AbsoluteSize.Y)
		local targetStyle=tree.NodeStyles and tree.NodeStyles[node]
		local targetMargin=fragmentSpacing(targetStyle and targetStyle.ScrollMargin and targetStyle.ScrollMargin[1],root.AbsoluteSize.Y)
		local y=root.CanvasPosition.Y+gui.AbsolutePosition.Y-root.AbsolutePosition.Y-rootPadding-targetMargin
		local canvas=root.CanvasSize
		local canvasHeight=if canvas.Y then canvas.Y.Offset else canvas[2] or 0
		fragmentPosition(Vector2.new(root.CanvasPosition.X,math.clamp(y,0,math.max(0,canvasHeight-root.AbsoluteSize.Y))))
	end
	local function applyFragment()
		if pendingFragment == nil or tree.LayoutInProgress or root:GetAttribute("Status") ~= "ready" then return end
		local fragment = pendingFragment; pendingFragment = nil
		if fragment == "" then
			if tree.SetCSSState then local _,needed,items=tree:SetCSSState('target',nil);if needed then for item in items or{[tree]=true}do requestLayout(true,item)end end end
			fragmentPosition(Vector2.new(0, 0));root:SetAttribute("Fragment", "");return
		end
		fragment = URL.decodeFragment(fragment)
		local node = DOM.findById(document, fragment)
		if not node then
			local pending = {document}
			while #pending > 0 do
				local candidate = table.remove(pending)
				if candidate.Kind == "Element" and candidate.Name == "a" and candidate.Attributes.name == fragment then node = candidate; break end
				for index = #candidate.Children, 1, -1 do table.insert(pending, candidate.Children[index]) end
			end
		end
		if tree.SetCSSState then local _,needsLayout,items=tree:SetCSSState('target',node);if needsLayout then for item in items or{[tree]=true}do requestLayout(true,item)end end end
		local gui = node and fragmentGui(node)
		if not gui then diagnostic("Unknown link fragment: #" .. fragment); return end
		local targetBox=tree.NodeBoxes and tree.NodeBoxes[node]
		if targetBox then
			local ancestor=node.Parent
			while ancestor do
				local scrollBox=tree.NodeBoxes[ancestor]
				if scrollBox and scrollBox.ScrollGui and scrollBox.ScrollMarkerChildren then
					for index,child in scrollBox.ScrollMarkerChildren do
						if child==targetBox then
							ScrollLayout.scrollToMarker(scrollBox,index)
							scrollRootToFragment(node,gui)
							root:SetAttribute("Fragment",fragment)
							return
						end
					end
				end
				ancestor=ancestor.Parent
			end
		end
		scrollRootToFragment(node,gui)
		root:SetAttribute("Fragment", fragment)
	end
	function page:ScrollToFragment(fragment: string): boolean
		assert(type(fragment) == "string", "Fragment must be a string")
		pendingFragment = fragment:gsub("^#", "")
		applyFragment()
		return true
	end
	local function flushScripts()
		if page.JavaScriptRuntime and page.JavaScriptRuntime:HasPending() and not tree.LayoutInProgress then
			local needsLayout,items=WorkContext.runFor(page,function()return page.JavaScriptRuntime:Flush()end)
			if needsLayout then
				if items and next(items) then
					for item,reason in items do requestLayout(true,item,reason) end
				else requestLayout(true) end
			end
		end
	end
	local function selectionPaint()
		local adapter=page.JavaScriptRuntime and page.JavaScriptRuntime.SelectionAdapter
		if adapter and adapter.AfterPaint then adapter:AfterPaint()end
	end
	local function calculateLayout(width,viewportHeight,dirtyItems,layoutAlive,styleAlive,tracking)
		local stats
		local mediaChanged,mediaLayout,mediaItems=false,false,nil
		if tree.SetMediaEnvironment then mediaChanged,mediaLayout,mediaItems=tree:SetMediaEnvironment(width,viewportHeight,mediaFeatures,styleAlive)end
		if mediaChanged then
			CanvasBackground.apply(root,document,tree.NodeStyles,tree.CanvasBackgroundState)
			if mediaLayout==nil then dirtyItems=nil
			elseif mediaLayout and dirtyItems then
				if not mediaItems or not next(mediaItems)then dirtyItems=nil
				else for item,reason in mediaItems do dirtyItems[item]=reason end end
			end
		end
		layoutAlive()
		if dirtyItems and tree.DirtyContext and tree.DirtyContext.Ready then
			local remaining = {}
			for item in dirtyItems do
				local measured, sameSize = pcall(function()
					if tree.CanKeepTextLayout and tree:CanKeepTextLayout(item,WordLayout.arrange,layoutAlive) then return true end
					return ControlView.canKeepLayout(item,TextMeasure.measure,layoutAlive)
					end)
				layoutAlive()
				if not measured or not sameSize then remaining[item] = dirtyItems[item] end
			end
			dirtyItems = remaining
			if not next(remaining) then return {Skipped = true},nil end
		end
		table.clear(pendingPaint)
		lastLayout = os.clock()
		root:SetAttribute("Status", "layout")
		local windowSize=root.AbsoluteWindowSize
		tree.ViewportHeight = if windowSize and windowSize.Y>0 then math.min(viewportHeight,windowSize.Y) else viewportHeight
		stats = DirtyLayout.begin(tree, dirtyItems)
		tracking.Stats=stats
		local height, canvasWidth = BlockLayout.arrange(tree,math.max(1,width-root.ScrollBarThickness),0,0,layoutAlive)
		layoutAlive()
		return {Height = height, Width = canvasWidth},stats
	end
	local function flushCSSStates()
		if not tree.FlushCSSStates then return end
		local _,needsLayout,items=tree:FlushCSSStates()
		if needsLayout then
			if items and next(items) then for item in items do requestLayout(true,item) end
			else requestLayout(true) end
		end
	end
	local presentationQueued = false
	local posterPublicationDepth = 0
	local svgPresentation
	local displayEnabled = true
	local function syncPresentation()
		local visible = displayEnabled and page.Presented == true
		tree.PresentationHidden = not visible
		root.Visible = visible
		if blank then blank.Visible = displayEnabled end
		Dialog.apply(tree)
		Popover.apply(tree)
		ViewportLayer.attach(tree, root, Factory)
		ViewportLayer.update(tree, root)
	end
	function page:SetDocumentVisible(visible: boolean)
		if not self.Alive then return end
		self.DocumentVisible=visible
		if not visible and self.SelectionCopyInput then self.SelectionCopyInput:Release()end
		if self.JavaScriptRuntime and self.JavaScriptRuntime.SetVisible then self.JavaScriptRuntime:SetVisible(visible)end
		if self.IFrameRuntime and self.IFrameRuntime.SetVisible then self.IFrameRuntime:SetVisible(visible)end
	end
	function page:OwnsSelectionCopyEditor(editor: any): boolean
		if not self.Alive or not editor then return false end
		if self.SelectionCopyInput and self.SelectionCopyInput:IsEditor(editor)then return true end
		for _,item in self.IFrames or{}do
			local child=item.ChildPage
			if child and child.OwnsSelectionCopyEditor and child:OwnsSelectionCopyEditor(editor)then return true end
		end
		return false
	end
	function page:SetVisible(visible: boolean,presentationOnly: boolean?)
		assert(type(visible) == "boolean", "Page visibility must be a boolean")
		if not self.Alive then return end
		displayEnabled = visible
		if not presentationOnly then
			self:SetDocumentVisible(visible)
		end
		syncPresentation()
	end
	function page:HasExecutingScripts(): boolean
		if not self.Alive then return false end
		local realm=self.JavaScriptRuntime
		if realm and realm.Alive and realm:IsExecuting()then return true end
		return self.IFrameRuntime~=nil and self.IFrameRuntime:HasExecutingScripts()
	end
	function page:RequestLeave(request: any?): boolean
		if not self.Alive then return false end
		request=table.clone(request or{})
		request.PromptState=request.PromptState or{Shown=false}
		local realm=self.JavaScriptRuntime
		if realm and realm.RequestLeave and not realm:RequestLeave(request)then return false end
		if not self.Alive then return false end
		return not self.IFrameRuntime or not self.IFrameRuntime.RequestLeave or self.IFrameRuntime:RequestLeave(request)
	end
	function page:CommitLeave()
		if not self.Alive then return end
		if self.IFrameRuntime and self.IFrameRuntime.CommitLeave then self.IFrameRuntime:CommitLeave()end
		local realm=self.JavaScriptRuntime
		if self.Alive and realm and realm.CommitLeave then realm:CommitLeave()end
	end
	local function presentWhenReady()
		if page.Presented or presentationQueued or not page.Alive then return end
		presentationQueued = true
		-- Publication may run scripts/observers which queue another initial pass.
		-- Reveal only after those callbacks and the current layout worker settle.
		task.defer(function()
			presentationQueued = false
			if not page.Alive or page.Presented or root:GetAttribute("Status") ~= "ready"
				or page.ScriptInitializationPending
				or running or forcedLayout or posterPublicationDepth > 0
				or tree.LayoutInProgress or tree.LayoutNeedsRecovery or pendingWidth ~= nil
				or root:GetAttribute("SVGVisibleReady") == false
				or root:GetAttribute("BackgroundVisibleReady") == false
				or root:GetAttribute("CompositeVisibleReady") == false
				or (page.PosterPendingCount or 0)>0
				or (page.JavaScriptRuntime and page.JavaScriptRuntime:HasPending()) then return end
			page.Presented = true
			-- Presentation is one atomic visibility commit. Loading work has
			-- finished; user input must not see partially published GUI layers.
			if work then work:Finish();page.LoadStats=work end
			syncPresentation()
			if blank then blank:Destroy(); blank = nil end
			root:SetAttribute("Presented", true)
			if svgPresentation then svgPresentation:Disconnect(); svgPresentation = nil end
			if page.RefreshPointerGeometry then page:RefreshPointerGeometry() end
		end)
	end
	svgPresentation = root:GetAttributeChangedSignal("SVGVisibleReady"):Connect(presentWhenReady)
	local backgroundPresentation=root:GetAttributeChangedSignal('BackgroundVisibleReady'):Connect(presentWhenReady)
	page:AddCleanup(function()backgroundPresentation:Disconnect()end)
	local compositePresentation=root:GetAttributeChangedSignal('CompositeVisibleReady'):Connect(presentWhenReady)
	page:AddCleanup(function()compositePresentation:Disconnect()end)
	page:AddCleanup(function() if svgPresentation then svgPresentation:Disconnect(); svgPresentation = nil end end)
	local containerStatesQueued=false
	local function queueContainerStates()
		if containerStatesQueued or not page.Alive or not tree.HasScrollContainers or not tree:HasScrollContainers()then return end
		containerStatesQueued=true
		task.defer(function()
			containerStatesQueued=false;if not page.Alive then return end
			local changed,needed,items=WorkContext.runFor(page,function()return tree:RefreshContainerStates(root)end)
			if needed then for item in items do requestLayout(true,item)end end
			if changed and motionRuntime then motionRuntime:AfterLayout()end
		end)
	end
	local function publishLayout(result,stats,work,width)
		if result.Skipped then
			publishImageLayout();if not page.Alive then return end;page.LazyMedia:Check(true)
			if tree.PublishContentVisibility then tree:PublishContentVisibility()end
			if tree.PublishCanvasBackground then tree:PublishCanvasBackground()end
			-- Stable local measurements have completed the requested geometry
			-- work too. Release font readiness without rerunning all observers.
			if page.JavaScriptRuntime and page.JavaScriptRuntime.FontLayoutCompleted then page.JavaScriptRuntime:FontLayoutCompleted()end
			if page.JavaScriptRuntime and page.JavaScriptRuntime.Geometry then page.JavaScriptRuntime.Geometry:ViewportChanged()end
			if page.RefreshControlPickers then page:RefreshControlPickers()end
			queueContainerStates();selectionPaint();return
		end
		tree.LayoutNeedsRecovery = false
		publishImageLayout();if not page.Alive then return end;page.LazyMedia:Check(true)
		if tree.RefreshContainerSizes then local _,needed,items=tree:RefreshContainerSizes();if needed then for item in items or{[tree]=true}do requestLayout(true,item)end end end
		local height, canvasWidth = result.Height, result.Width
		local viewportWidth = math.max(1,width-root.ScrollBarThickness)
		page.LastLayoutWork = work
		local horizontalOverflow = canvasWidth > viewportWidth + 0.01
		local direction = if horizontalOverflow then Enum.ScrollingDirection.XY else Enum.ScrollingDirection.Y
		if root.ScrollingDirection ~= direction then root.ScrollingDirection = direction end
		local canvas = UDim2.fromOffset(if horizontalOverflow then canvasWidth else 0, height)
		if root.CanvasSize ~= canvas then root.CanvasSize = canvas end
		if tree.PublishCanvasBackground then tree:PublishCanvasBackground(math.max(viewportWidth,canvasWidth),math.max(root.AbsoluteSize.Y,height))end
		Dialog.arrange(tree, root)
		Popover.arrange(tree, root)
		if page.FullscreenPresentation then page.FullscreenPresentation:Refresh()end
		ViewportLayer.attach(tree,root,Factory)
		ViewportLayer.update(tree,root)
		-- Explicit picker anchors may move while their originating select stays
		-- unchanged. Publish after the shared registry and GUI geometry settle.
		if page.RefreshControlPickers then page:RefreshControlPickers()end
		queueContainerStates()
		if motionRuntime then motionRuntime:AfterLayout() end
		page.LastLayoutStats = stats
		root:SetAttribute("LayoutMode", stats.Mode)
		root:SetAttribute("LayoutRecomputed", stats.Recomputed)
		root:SetAttribute("LayoutReused", stats.Reused)
		root:SetAttribute("Error", nil)
		root:SetAttribute("Status", "ready")
		if tree.ScrollSnapPending then tree.ScrollSnapPending = nil; ScrollLayout.snapTree(tree) end
		applyFragment()
		if page.JavaScriptRuntime and page.JavaScriptRuntime.Geometry then page.JavaScriptRuntime.Geometry:ViewportChanged()end
		if page.JavaScriptRuntime and page.JavaScriptRuntime.AfterLayout then page.JavaScriptRuntime:AfterLayout()end
		if page.JavaScriptRuntime and page.JavaScriptRuntime.SelectionAdapter then page.JavaScriptRuntime.SelectionAdapter:AfterLayout()end
		if page.RefreshPointerGeometry then page:RefreshPointerGeometry()end
		presentWhenReady()
	end
	local function schedule()
		if running or forcedLayout then return end
		running = true
		task.defer(function()
			while (pendingWidth or next(pendingPaint) or (page.JavaScriptRuntime and page.JavaScriptRuntime:HasPending())) and page.Alive do
				if forcedLayout then break end
				if not resizeHeld() then flushScripts() end
				local now = os.clock()
				-- The resize owner signals the actual gesture. A stationary held grip
				-- still waits for release; only local control changes use a timer.
				-- Deferred attribute events may leave the cached gesture active until
				-- its release callback runs. Keep waiting rather than retrying in a loop.
				local dragging = resizeHeld()
				local remaining = if pendingImmediate then 0 else lastLayout + RESIZE_INTERVAL - now
				local resizeWaiting = pendingWidth ~= nil and (dragging or remaining > 0)
				if resizeWaiting and not dragging and not resizeTimer then
					resizeTimer = task.delay(remaining, function()
						resizeTimer = nil
						if page.Alive then schedule() end
					end)
				end
				if not pendingWidth or resizeWaiting then
					if not next(pendingPaint) then break end
					local box = next(pendingPaint)
					pendingPaint[box] = nil
					local ok, message = pcall(function()
						for _, child in box.Children or {} do
							if child.Kind == "Words" then WordLayout.repaint(child, alive) end
							if not page.Alive then return end
						end
						if tree.HasOpacity then GroupOpacity.arrange(box,alive) end
						selectionPaint()
					end)
					if not page.Alive then break end
					if not ok then diagnostic("Ellipsis repaint failed: " .. tostring(message)) end
					continue
				end
				local width = pendingWidth
				local viewportHeight = requestedHeight or root.AbsoluteSize.Y
				local dirtyItems = if pendingFull then nil else pendingDirty
				pendingFull, pendingDirty = false, {}
				pendingWidth, pendingImmediate = nil, false
				if resizeTimer then task.cancel(resizeTimer); resizeTimer = nil end
				if width <= 0 then root:SetAttribute("Status", "waiting-size"); break end
				local revision = layoutRevision
				local stats;local tracking={}
		local ok, result, cancelled, work = LayoutJob.run(page,tree,renderWorkBudgetMS,
					function() return revision == layoutRevision and not resizeHeld() end,
					function(layoutAlive, styleAlive)
						local result;result,stats=calculateLayout(width,viewportHeight,dirtyItems,layoutAlive,styleAlive,tracking)
						return result
					end, task, os.clock)
				stats=tracking.Stats
				if stats then DirtyLayout.finish(tree,ok and page.Alive) end
				if not page.Alive then break end
				if not ok and not cancelled then
					tree.LayoutNeedsRecovery = true
					if tree.DirtyContext then tree.DirtyContext.Ready = false end
					root:SetAttribute("Error", tostring(result)); root:SetAttribute("Status", "error")
					if pendingWidth then pendingFull = true; continue end
					break
				end
				if cancelled then
					-- Keep queued CSS until all boxes have valid geometry again.
					-- In particular, a cancelled first layout may have unmeasured boxes.
					if tree.DirtyContext then tree.DirtyContext.Ready = false end
					tree.LayoutNeedsRecovery = true
					root:SetAttribute("Status", "layout")
					pendingWidth, pendingFull = requestedWidth, true
					continue
				end
				-- All geometry is valid at this point, so pending CSS can safely paint.
				tree.LayoutNeedsRecovery = false
				if tree.FlushCSSStates then
					local flushed, stateResult = pcall(flushCSSStates)
					if not flushed then
						tree.LayoutNeedsRecovery = true
						if tree.DirtyContext then tree.DirtyContext.Ready = false end
						root:SetAttribute("Error", tostring(stateResult)); root:SetAttribute("Status", "error")
						break
					end
				end
				if not page.Alive then break end
				if revision ~= layoutRevision or resizeHeld() then
					-- A suspended pass may have changed intermediate sizes. Retry the
					-- latest request in full; never cache/publish an incomplete result.
					if tree.DirtyContext then tree.DirtyContext.Ready = false end
					tree.LayoutNeedsRecovery = true
					root:SetAttribute("Status", "layout")
					pendingWidth, pendingFull = requestedWidth, true
					continue
				end
				WorkContext.runFor(page,publishLayout,result,stats,work,width)
			end
			running = false
			presentWhenReady()
		end)
	end
	requestLayout = function(force: boolean?, item: any?, reason: any?)
		if not page.Alive then return end
		local width, viewportHeight = root.AbsoluteSize.X, root.AbsoluteSize.Y
		local initial = requestedWidth == nil
		local viewportChanged = width ~= requestedWidth or ((tree.Positioning or tree.HasMediaQueries or tree.HasViewportUnits) and viewportHeight ~= requestedHeight)
		requestedWidth, requestedHeight = width, viewportHeight
		if not force and not item and not viewportChanged then return end
		layoutRevision += 1
		pendingWidth = width
		if item and not viewportChanged then
			-- A queued style/control change takes precedence over a narrower text
			-- invalidation of the same owner, irrespective of callback order.
			local previous=pendingDirty[item]
			pendingDirty[item] = if previous==true or (reason~="text" and reason~="children") then true
				elseif previous=="children" or reason=="children" then "children" else "text"
		elseif initial or viewportChanged or reason~='media' then pendingFull = true end
		pendingImmediate = pendingImmediate or initial or viewportChanged or force == true
		schedule()
	end
 function page:HasPendingLayout(): boolean
		return pendingWidth~=nil or tree.LayoutNeedsRecovery==true or not (tree.DirtyContext and tree.DirtyContext.Ready)
 end
 function page:RequestAnimationLayout(box: any)
  requestLayout(true,box)
 end
	function page:GeometryViewport(): any
		local size,position=root.AbsoluteSize,root.CanvasPosition
		return {Width=size.X,Height=size.Y,ClientWidth=math.max(0,size.X-root.ScrollBarThickness),ClientHeight=size.Y,
			ScrollX=position.X,ScrollY=position.Y,ScrollWidth=math.max(size.X-root.ScrollBarThickness,tree.LocalRight or tree.OuterWidth or 0),
			ScrollHeight=math.max(size.Y,tree.LocalBottom or tree.OuterHeight or 0),Environment=mediaFeatures}
	end
	function page:FlushScriptLayout()
		assert(page.Alive,"Geometry reads require an available page layout")
		-- This host explicitly defers reflow until its resize grip is released.
		-- Reads use retained box geometry during that gesture; pending DOM/layout
		-- work stays queued. Ordinary geometry reads remain synchronous.
		if resizeHeld() then return end
		assert(not tree.LayoutInProgress and not forcedLayout,"Geometry reads require an available page layout")
		forcedLayout=true
		local ok,message=pcall(function()
			flushScripts()
			if not page:HasPendingLayout() then return end
			-- A geometry read is an explicit demand for current geometry. It uses
			-- the same dirty targets, measurement guards and publication as a frame.
			-- A resize beginning during this flush still takes precedence.
			for attempt=1,4 do
				if resizeHeld() then return end
				local width,height=root.AbsoluteSize.X,root.AbsoluteSize.Y
				if width<=0 then error("Geometry reads require a nonzero viewport width",0) end
				local dirty=if pendingFull or tree.LayoutNeedsRecovery then nil else pendingDirty
				if not next(dirty or {}) then dirty=nil end
				pendingWidth,pendingImmediate,pendingFull,pendingDirty=nil,false,false,{}
				requestedWidth,requestedHeight=width,height
				if resizeTimer then task.cancel(resizeTimer);resizeTimer=nil end
				local revision,stats=layoutRevision,nil;local tracking={}
				local success,result,cancelled,work=LayoutJob.run(page,tree,0,
					function()return revision==layoutRevision and not resizeHeld() end,
					function(layoutAlive,styleAlive)
						local value;value,stats=calculateLayout(width,height,dirty,layoutAlive,styleAlive,tracking);return value
					end,task,os.clock)
				stats=tracking.Stats
				if stats then DirtyLayout.finish(tree,success and page.Alive)end
				if not page.Alive then error("Page was disposed during a geometry read",0)end
				if cancelled then
					tree.LayoutNeedsRecovery=true;if tree.DirtyContext then tree.DirtyContext.Ready=false end
					pendingWidth,pendingFull=requestedWidth,true
					if resizeHeld() then return end
					continue
				end
				if not success then error(result,0)end
				tree.LayoutNeedsRecovery=false
				flushCSSStates()
				if revision~=layoutRevision or resizeHeld() then
					tree.LayoutNeedsRecovery=true;if tree.DirtyContext then tree.DirtyContext.Ready=false end
					pendingWidth,pendingFull=requestedWidth,true
					if resizeHeld() then return end
					continue
				end
				publishLayout(result,stats,work,width)
				return
			end
			error("Viewport changed repeatedly during the geometry read",0)
		end)
		forcedLayout=false
		if not ok then
			tree.LayoutNeedsRecovery=true;pendingWidth,pendingFull=requestedWidth,true
			if tree.DirtyContext then tree.DirtyContext.Ready=false end
		end
		schedule()
		if not ok then error(message,0)end
	end
	local resizeGesture = target:GetAttributeChangedSignal(VIEWPORT_RESIZE_ATTRIBUTE):Connect(function()
		if not page.Alive then return end
		local active = viewportResizing()
		if active == resizeActive then return end
		resizeActive = active
		if active then
			-- Invalidate a suspended pass even before the grip has moved.
			layoutRevision += 1
			if resizeTimer then task.cancel(resizeTimer); resizeTimer = nil end
		else
			if pendingWidth ~= nil or tree.LayoutInProgress then pendingImmediate = true end
			requestLayout()
			schedule()
		end
	end)
	page:AddCleanup(function() resizeGesture:Disconnect() end)
	local function watchEllipsis(box: any)
		if box.ScrollGui and box.Style.TextOverflow == "ellipsis" then
			local lastX = box.ScrollGui.CanvasPosition.X
			local changed = box.ScrollGui:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
				local x = box.ScrollGui.CanvasPosition.X
				if page.Alive and x ~= lastX then lastX = x; pendingPaint[box] = true; schedule() end
			end)
			page:AddCleanup(function() changed:Disconnect() end)
		end
		for _, child in box.AllChildren or box.Children or {} do watchEllipsis(child) end
	end
	watchEllipsis(tree)
	ShapeImages.start(page,tree,diagnostic,function() requestLayout(true) end,{WorkBudgetMS=renderWorkBudgetMS})
	page.ResourceLoadHost=ResourceLoadHost.new(page,tree,options and options.JavaScriptServices and options.JavaScriptServices.ResourceServices)
	page:AddCleanup(function()page.ResourceLoadHost:Destroy()end)
	-- The same gate used by HTMLScripts selects one DOM image request owner.
	-- The initial DOM census runs while ScriptInitializationPending is true.
	local managedImageStartup=HTMLScripts.ShouldStart(page,options)
	if not managedImageStartup then
		NativeImageResources.new(page,{Task=task,ScriptingEnabled=not options or options.JavaScript~=false,
			ImageIsRendered=function(node)return page:ImageIsRendered(node)end,
			DeferImage=function(node,resume)return page.LazyMedia:Defer(node,'Image',resume)end,
			GetViewport=function()if page.GeometryViewport then return page:GeometryViewport()end;return {Width=root.AbsoluteSize.X,Density=1}end,
			Changed=function(node,ok,data)
				if not page.Alive then return end
				local record=node.ImageResourceState;local generation=record and record.Generation
				local item,geometry
				if page.RefreshImageResource then item,geometry=page:RefreshImageResource(node)
				else local _,_,_,changed=tree:RefreshImageResource(node);item=tree:FindImageItem(node);geometry=changed end
				if not page.Alive or node.ImageResourceState~=record or record and record.Generation~=generation then return end
				if item and ok and data then
					local changed=item.IntrinsicWidth~=data.Width or item.IntrinsicHeight~=data.Height
					item.IntrinsicWidth,item.IntrinsicHeight=data.Width,data.Height;geometry=geometry or changed
				end
				if item and geometry then requestLayout(false,item)end
			end})
	end
	-- A poster is an independent image request, including on no-script pages.
	-- Native cancellation may leave preload work running; its lease releases
	-- the item immediately and prevents a stale completion from publishing.
	local function posterPublication(operation,...)
		posterPublicationDepth+=1
		local result=table.pack(pcall(operation,...))
		posterPublicationDepth-=1
		presentWhenReady()
		if not result[1]then error(result[2],0)end
		return table.unpack(result,2,result.n)
	end
	local posterLeases={}
	page.PosterPendingCount=0
	local function posterFinished(lease)
		if lease.Pending then lease.Pending=false;page.PosterPendingCount-=1 end
		page:DocumentResourcesChanged()
		presentWhenReady()
	end
	local function cancelPoster(item)
		local lease=posterLeases[item];if not lease then return end
		posterLeases[item]=nil;lease.Item=nil
		local cancel=lease.Cancel;lease.Cancel=nil
		local cancelled=table.pack(pcall(function()if cancel then cancel()end end))
		local finished=table.pack(pcall(posterFinished,lease))
		if not cancelled[1]then error(cancelled[2],0)end
		if not finished[1]then error(finished[2],0)end
	end
	function page:MediaPresentationChanged(item)
		if not self.Alive or tree.MediaByNode[item.Node]~=item or not ShadowTree.Connected(item.Node,document)then return end
		local changed=MediaBox.natural(item)
		if self.Media and self.Media.RefreshPresentation then self.Media:RefreshPresentation(item)
		elseif item.ContentWidth and item.ContentHeight then MediaBox.arrange(item)else MediaBox.paint(item)end
		if changed then requestLayout(false,item)end
	end
	local function publishPoster(item,data)
		local previous=item.PosterSVGItem
		if previous and svgRuntime then svgRuntime:RemoveItems({previous})end
		local changed=tree:SetVideoPoster(item,data)
		if page.RefreshDOMResources then page:RefreshDOMResources()
		elseif item.PosterSVGItem then
			if not svgRuntime then svgRuntime=require(script.Parent.SVGImages).start(page,tree,diagnostic,{CacheBytes=svgCacheBytes,CacheEntries=svgCacheEntries,PrewarmStates=svgPrewarmStates,WorkBudgetMS=renderWorkBudgetMS})
			else svgRuntime:AddItems({item.PosterSVGItem})end
		end
		-- SetVideoPoster already updated the represented natural dimensions.
		page:MediaPresentationChanged(item)
		if changed then requestLayout(false,item)end
	end
	local function loadVideoPoster(self,item,raw)
		if not self.Alive or tree.MediaByNode[item.Node]~=item or not ShadowTree.Connected(item.Node,document)then return end
		local pending=raw~=nil and raw~=''
		local lease={Item=item,Pending=false}
		cancelPoster(item);posterLeases[item]=lease;item.PosterSource=raw
		if not pending then publishPoster(item,nil);if posterLeases[item]==lease then posterLeases[item]=nil end;lease.Item=nil;posterFinished(lease);return end
		local owner=item.Node.OwnerDocument
		local base=if owner and owner~=document then DocumentInfo.baseURL(owner,owner.URL,true)else DocumentInfo.baseURL(document,self.DocumentURL,true)
		local url=DocumentInfo.resolveURL(base or self.BaseURL,raw)
		item.PosterURL=url
		local source=if resolveImage(raw)or resolveSVG(raw)then raw else url
		local function complete(ok,data)
			local current=lease.Item
			if not self.Alive or not current or posterLeases[current]~=lease or tree.MediaByNode[current.Node]~=current then return end
			posterLeases[current]=nil;lease.Item=nil;lease.Cancel=nil
			local published=table.pack(pcall(function()if ShadowTree.Connected(current.Node,document)then publishPoster(current,if ok then data else nil)end end))
			local finished=table.pack(pcall(posterFinished,lease))
			if not published[1]then error(published[2],0)end
			if not finished[1]then error(finished[2],0)end
		end
		local function fetch()
			if not self.Alive or lease.Item~=item or posterLeases[item]~=lease then return end
			lease.Cancel=nil;lease.Pending=true;self.PosterPendingCount+=1
			local started=table.pack(pcall(function()
				self:DocumentResourcesChanged()
				if not self.Alive or lease.Item~=item or posterLeases[item]~=lease then return end
				local cancel=self.ResourceLoadHost:LoadImage(url,complete,{Source=source})
				if lease.Item then lease.Cancel=cancel else cancel()end
			end))
			if not started[1]then
				if posterLeases[item]==lease then posterLeases[item]=nil;lease.Item=nil;pcall(posterFinished,lease)end
				error(started[2],0)
			end
		end
		lease.Cancel=self.LazyMedia:Defer(item.Node,'Poster',fetch)
		if not lease.Cancel then fetch()end
	end
	function page:LoadVideoPoster(item,raw)
		return posterPublication(loadVideoPoster,self,item,raw)
	end
	local function removeVideoPoster(self,item)
		cancelPoster(item)
		local previous=item.PosterSVGItem
		if previous and svgRuntime then svgRuntime:RemoveItems({previous})end
		if previous then local at=table.find(tree.SVGItems,previous);if at then table.remove(tree.SVGItems,at)end end
		item.PosterSVGItem=nil
		item.PosterSVG,item.Poster,item.PosterWidth,item.PosterHeight=nil,nil,nil,nil
		item.PosterReady=false
	end
	function page:RemoveVideoPoster(item)
		return posterPublication(removeVideoPoster,self,item)
	end
	page:AddCleanup(function()
		local items={};for item in posterLeases do table.insert(items,item)end
		for _,item in items do cancelPoster(item)end
		if tree.TakeStructuralResourceChanges then tree:TakeStructuralResourceChanges()end
		page.LoadVideoPoster=nil;page.RemoveVideoPoster=nil;page.MediaPresentationChanged=nil
	end)
	local function imageDOMOwned(item)
		-- The visual and metadata consumers share the DOM owner's lazy gate,
		-- including the interval before a planned realm has been installed.
		local node=item.Node
		if managedImageStartup and(page.ScriptInitializationPending or page.JavaScriptRuntime and page.JavaScriptRuntime.ImageResources)then
			return ElementNames.html(node,'img')or ElementNames.html(node,'input')and(node.Attributes.type or''):lower()=='image'
		end
		return page.NativeImageResources~=nil and page.JavaScriptRuntime==nil and page.NativeImageResources:Manages(node)
	end
	local stopDimensions,dimensionRuntime = ImageDimensions.start(tree.ImageItems, alive, diagnostic, function() requestLayout(true) end,
		{IsDOMOwned=imageDOMOwned,LoadDimensions=function(source,complete)return page.ResourceLoadHost:LoadRasterDimensions(source,complete)end})
	page:AddCleanup(stopDimensions or function()if dimensionRuntime then dimensionRuntime:Destroy()end end)
	local stopFilters,filterRuntime=ImageFilters.start(tree.ImageItems,alive,function(message) diagnostic(message); warn(message) end,function() requestLayout(true) end)
	page:AddCleanup(stopFilters or function()if filterRuntime then filterRuntime:Destroy()end end)
	local stopImages,imageRuntime = ImageLoad.start(tree.ImageItems, alive, function(message) diagnostic(message); warn(message) end,
		function() requestLayout(true) end,{IsDOMOwned=imageDOMOwned})
	page:AddCleanup(stopImages or function()if imageRuntime then imageRuntime:Destroy()end end)
	local resized = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		page.LazyMedia:Check()
		if page.NativeImageResources then page.NativeImageResources:ViewportChanged()end
		requestLayout()
	end)
	page:AddCleanup(function() resized:Disconnect() end)
	local scrollbarResized = root:GetPropertyChangedSignal("ScrollBarThickness"):Connect(function() requestLayout(true) end)
	page:AddCleanup(function() scrollbarResized:Disconnect() end)
	do
		local lastCanvasPosition=root.CanvasPosition
		local scrolled=root:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			local current=root.CanvasPosition
			if page.Alive and current~=lastCanvasPosition then
				lastCanvasPosition=current
				page.LazyMedia:Check()
				ViewportLayer.update(tree,root)
				queueContainerStates()
				if page.JavaScriptRuntime and page.JavaScriptRuntime.ScrollChanged then page.JavaScriptRuntime:ScrollChanged()end
			end
		end)
		page:AddCleanup(function() scrolled:Disconnect() end)
		-- Sticky boxes track the nearest scrolling ancestor, which may be an
		-- overflow frame several levels below the page scroller.
		local observed={}
		local function watchStickyScrolls(box: any,seen: any)
			if box.ScrollGui then
				seen[box.ScrollGui]=true
				local record=observed[box.ScrollGui]
				if record then record.Box=box else
					record={Box=box};observed[box.ScrollGui]=record
					record.Connection=box.ScrollGui:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
					if page.Alive then
						page.LazyMedia:Check()
						ViewportLayer.update(tree,root,record.Box)
						queueContainerStates()
						if page.JavaScriptRuntime and page.JavaScriptRuntime.ScrollChanged then page.JavaScriptRuntime:ScrollChanged(record.Box.Node)end
					end
				end)
				end
			end
			for _,child in box.AllChildren or box.Children or {} do
				if child.Kind~="Words" then watchStickyScrolls(child,seen) end
			end
		end
		function page:RefreshDOMScrolls()
			local seen={};watchStickyScrolls(tree,seen)
			for gui,record in observed do if not seen[gui] then record.Connection:Disconnect();observed[gui]=nil end end
		end
		page:RefreshDOMScrolls()
		page:AddCleanup(function()
			for _,record in observed do record.Connection:Disconnect()end
			table.clear(observed);page.RefreshDOMScrolls=nil
		end)
	end
	if inputService then
		for _,property in {"MouseEnabled","TouchEnabled"} do
			local ok,signal=pcall(function() return inputService:GetPropertyChangedSignal(property) end)
			if ok and signal then
				local connection=signal:Connect(function() mediaFeatures=currentMediaFeatures();requestLayout(true,nil,'media') end)
				page:AddCleanup(function() connection:Disconnect() end)
			end
		end
	end
	page.VideoSourceServices=options and options.JavaScriptServices and options.JavaScriptServices.VideoServices
	page.ManagedAudioStartup=HTMLScripts.ShouldStart and HTMLScripts.ShouldStart(page,options)==true
	if not page.ManagedAudioStartup then
		NativeMediaResources.new(page,tree,{Task=task,AudioServices=options and options.JavaScriptServices and options.JavaScriptServices.AudioServices})
	end
	local inputReady, inputError = pcall(InputController.start,page,tree,requestLayout,diagnostic,options and options.InputServices)
	local preferenceReady,preferenceSignal=pcall(function() return game:GetService('GuiService'):GetPropertyChangedSignal('ReducedMotionEnabled')end)
	if preferenceReady and preferenceSignal then
	 local connection=preferenceSignal:Connect(function()mediaFeatures=currentMediaFeatures();requestLayout(true,nil,'media')end)
	 page:AddCleanup(function()connection:Disconnect()end)
	end
	if not inputReady then page:Destroy(); error(inputError) end
	if page.NativeMediaResources then page.NativeMediaResources:Start()end
	if page.NativeImageResources then page.NativeImageResources:Start()end
	local iframeReady, iframeError = pcall(IFrameRuntime.start,page,tree,diagnostic,function(container: GuiObject, source: string, childOptions: any)
		return HTMLPage.mount(container, source, childOptions)
	end,options)
	if not iframeReady then page:Destroy(); error(iframeError) end
	local iframeRuntime=iframeError
	local function removeResources(removals)
		if removals.Images then
			dimensionRuntime:Remove(removals.Images);filterRuntime:Remove(removals.Images);imageRuntime:Remove(removals.Images)
		end
		if svgRuntime and removals.SVG then svgRuntime:RemoveItems(removals.SVG)end
		if page.CanvasRuntime and removals.Canvas then page.CanvasRuntime:Remove(removals.Canvas)end
		if page.Media and removals.Media then page.Media:Remove(removals.Media)end
		if iframeRuntime and removals.IFrames then iframeRuntime:Remove(removals.IFrames)end
	end
	tree.StructuralResourcesRemoving=removeResources
	function page:RefreshDOMResources()
		discardPreparedPosterSVG()
		local changes=tree:TakeStructuralResourceChanges()
		-- Removal has already cancelled resources before native destruction;
		-- Remove is idempotent and also covers any future census-only removal.
		local removals={};for kind,change in changes do removals[kind]=change.Removed end;removeResources(removals)
		if not self.Alive then return end
		local added=changes.Images.Added
		dimensionRuntime:Add(added);filterRuntime:Add(added);imageRuntime:Add(added)
		if #changes.SVG.Added>0 then
			if not svgRuntime then
				svgRuntime=require(script.Parent.SVGImages).start(page,tree,diagnostic,{CacheBytes=svgCacheBytes,CacheEntries=svgCacheEntries,PrewarmStates=svgPrewarmStates,WorkBudgetMS=renderWorkBudgetMS})
			else svgRuntime:AddItems(changes.SVG.Added)end
		end
		if not self.Alive then return end
		if #changes.Canvas.Added>0 then
			if not self.CanvasRuntime then self:EnsureCanvasRuntime()
			else self.CanvasRuntime:Add(changes.Canvas.Added)end
		end
		if not self.Alive then return end
		if self.Media then self.Media:Add(changes.Media.Added)end
		if iframeRuntime then iframeRuntime:Add(changes.IFrames.Added)end
		if self.RefreshDOMScrolls then self:RefreshDOMScrolls()end
	end
	function page:RefreshImageResource(node: any): (any,boolean)
		if self.NativeImageResources then self.NativeImageResources:Refresh(node,false)end
		local item,_,changed,geometry=tree:RefreshImageResource(node,function(previous,kind)
			if kind=="Image"then
				dimensionRuntime:Remove({previous});filterRuntime:Remove({previous});imageRuntime:Remove({previous})
			elseif kind=="SVG"and svgRuntime then svgRuntime:RemoveItems({previous})end
		end)
		if item and changed and self.Alive then
			-- A source switch retains the box. Rebind only its asset registrations;
			-- the census also handles raster/SVG/empty changes without recreating DOM.
			self:RefreshDOMResources()
			if item.Source then dimensionRuntime:Add({item});filterRuntime:Add({item});imageRuntime:Add({item})
			elseif item.SVG and svgRuntime then svgRuntime:AddItems({item})end
		end
		return item,geometry
	end
	page:AddCleanup(function()tree.StructuralResourcesRemoving=nil;page.RefreshDOMResources=nil;page.RefreshImageResource=nil end)
	local scriptsStarted=os.clock()
	local function pendingPresentationCanWait():boolean
		local changes=page.JavaScriptRuntime and page.JavaScriptRuntime.Pending
		if not changes or not next(changes)then return false end
		for node,change in changes do
			for kind in change do
				if kind~='Attributes'and kind~='OldAttributes'and kind~='Text'then return false end
			end
			for attribute in change.Attributes or{}do
				if attribute~='style'and attribute~='class'then return false end
			end
			if change.Text and (not tree.TextOwner or not tree:TextOwner(node))then return false end
		end
		return true
	end
	local scriptsReady,scriptsError=pcall(HTMLScripts.start,page,tree,function()
		-- Style/class and retained text writes are queued; the compiled layout
		-- still owns its previous snapshot until Flush. Let it finish so a stream
		-- of input cannot repeatedly cancel every cooperative pass. Structure,
		-- semantic attributes and viewport changes retain ordinary invalidation.
		if tree.LayoutInProgress and pendingPresentationCanWait()then return end
		layoutRevision+=1
		if tree.LayoutInProgress then requestLayout(true) else schedule() end
	end,diagnostic,options,flushScripts)
	page.BuildStats.ScriptsMS=(os.clock()-scriptsStarted)*1000
	if not scriptsReady then page:Destroy();error(scriptsError) end
	if not page.Alive then return page end
	if page.JavaScriptRuntime and page.NativeImageResources then page.NativeImageResources:Destroy()end
	page.ScriptInitializationPending=false
 page.VideoSelectionStarted=true;if page.Media and page.Media.VideoScriptsReady then page.Media:VideoScriptsReady(page.JavaScriptRuntime)end
	if page.JavaScriptRuntime then stylesheetSubscription=page.JavaScriptRuntime:SubscribeStylesheetChanges(notifyStylesheets)
	elseif options and options.SubscribeParentStylesheetChanges then stylesheetSubscription=options.SubscribeParentStylesheetChanges(notifyStylesheets)end
	notifyStylesheets()
	requestLayout()
 if not page.JavaScriptRuntime and page.Alive then
  if documentLoadCallback then documentLoadCallback('interactive')end
  page:DocumentResourcesChanged()
 end
	-- A cooperative constructor may have allowed an intermediate layout to
	-- settle at this size already. Retry the presentation barrier even when
	-- requestLayout has no new geometry to schedule.
	presentWhenReady()
	return page
end

function HTMLPage.mount(target: GuiObject,html: string,options: any?)
	local milliseconds=if options and options.RenderWorkBudgetMS~=nil then options.RenderWorkBudgetMS else 4
	assert(type(milliseconds)=="number"and milliseconds==milliseconds and milliseconds>=0 and milliseconds<=16,"options.RenderWorkBudgetMS must be a number from 0 to 16")
	local owner={}
	-- Loading may be slower; do not spend the full normal paint budget per
	-- subsystem. The shared native frame gate also covers concurrent SVG work.
	local work=WorkContext.new(math.min(2,milliseconds),{Task=task,Clock=os.clock,Alive=function()return not owner.Page or owner.Page.Alive end})
	local ok,result=pcall(function()
		return if work then work:Run(mountDocument,target,html,options,work,owner)else mountDocument(target,html,options,nil,owner)
	end)
	if not ok then
		if work then work:Finish()end
		if owner.Page and not owner.Page.Alive and WorkContext.isCancelled(result)then return owner.Page end
		if owner.Page then owner.Page:Destroy()end
		error(result,0)
	end
	return result
end

return HTMLPage
