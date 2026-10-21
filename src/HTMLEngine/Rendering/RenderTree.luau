--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local MediaContent=require(script.Parent.Parent.HTML.MediaContent)
local CanvasBackground=require(script.Parent.CanvasBackground)
local BorderBox = require(script.Parent.BorderBox)
local CornerRadii = require(script.Parent.CornerRadii)
local OutlineBox = require(script.Parent.OutlineBox)
local Factory = require(script.Parent.GuiFactory)
local Style = require(script.Parent.Parent.CSS.InlineStyle)
local AnimationColors=require(script.Parent.Parent.CSS.AnimationColors)
local BoxShadow=require(script.Parent.Parent.CSS.BoxShadow)
local ContainerStates=require(script.Parent.ContainerStates)
local Stylesheet = require(script.Parent.Parent.CSS.Stylesheet)
local Selectors=require(script.Parent.Parent.CSS.Selectors)
local selectStateSelectors={Disabled=Selectors.compile(':disabled'),Hovered=Selectors.compile(':hover'),Active=Selectors.compile(':active')}
local function selectPartState(node,states)
 if ElementNames.htmlName(node)~='select'and ElementNames.htmlName(node)~='option'and ElementNames.htmlName(node)~='optgroup'then return nil end
 local result={};for field,selector in selectStateSelectors do result[field]=Selectors.matches(node,selector,states)end
 if ElementNames.htmlName(node)=='option'and node.Parent and ElementNames.htmlName(node.Parent)=='optgroup'then result.GroupDisabled=Selectors.matches(node.Parent,selectStateSelectors.Disabled,states)end
 return result
end
local InlineWords = require(script.Parent.Parent.Layout.InlineWords)
local SpacingOwners = require(script.Parent.SpacingOwners)
local LanguageRange=require(script.Parent.Parent.CSS.LanguageRange)
local InlineFragments = require(script.Parent.Parent.Layout.InlineFragments)
local InlineGeometry=require(script.Parent.InlineGeometry)
local WhiteSpace=require(script.Parent.Parent.Layout.WhiteSpace)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local function emptyInlineText(node: any,style: any): boolean
	local children=ShadowTree.FlatChildren(node)
	if #children==0 then return true end
	local collapse=WhiteSpace.collapse(style)
	if collapse~='collapse'and collapse~='discard'and collapse~='preserve-breaks'then return false end
	for _,child in children do
		if child.Kind~='Text'or child.Text:find('[^ \t\r\n]')then return false end
		if collapse=='preserve-breaks'and child.Text:find('[\r\n]')then return false end
	end
	return true
end
local LetterSpacing = require(script.Parent.Parent.Layout.LetterSpacing)
local TextEmphasis=require(script.Parent.Parent.Layout.TextEmphasis)
local ElementProfile = require(script.Parent.Parent.HTML.ElementProfile)
local TextShadows = require(script.Parent.TextShadows)
local ImageBox = require(script.Parent.ImageBox)
local ReplacedElement = require(script.Parent.ReplacedElement)
local Color = require(script.Parent.Parent.CSS.Color)
local FontFamily = require(script.Parent.Parent.CSS.FontFamily)
local ControlState = require(script.Parent.Parent.Controls.State)
local Directionality=require(script.Parent.Parent.CSS.Directionality)
local BidiInline=require(script.Parent.Parent.Layout.BidiInline)
local ControlView = require(script.Parent.Parent.Controls.View)
local ControlDefaults = require(script.Parent.Parent.Controls.Defaults)
local SelectOptions = require(script.Parent.Parent.Controls.SelectOptions)
local SelectTree=require(script.Parent.Parent.HTML.SelectTree)
local AttributeValues=require(script.Parent.Parent.HTML.AttributeValues)
local StructuralResources = require(script.Parent.StructuralResources)
local RenderTree = {}
local WorkContext=require(script.Parent.Parent.WorkContext)
local GroupOpacity = require(script.Parent.GroupOpacity)
local Disclosure = require(script.Parent.Disclosure)
local TableLayout = require(script.Parent.Parent.Layout.TableLayout)
local TableBorderPaint = require(script.Parent.TableBorderPaint)
local TableColumns = require(script.Parent.Parent.Layout.TableColumns)
local TableColumnPaint = require(script.Parent.TableColumnPaint)
local TableCaptions = require(script.Parent.Parent.Layout.TableCaptions)
local ResponsiveSources = require(script.Parent.Parent.HTML.ResponsiveSources)
local ImageMap = require(script.Parent.Parent.Input.ImageMap)
local MediaSources = require(script.Parent.MediaSources)
local MediaBox = require(script.Parent.MediaBox)
local IFrameBox = require(script.Parent.IFrameBox)
local Dialog = require(script.Parent.Dialog)
local Popover = require(script.Parent.Popover)
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local VisualEffects = require(script.Parent.VisualEffects)
local MaskGradient=require(script.Parent.MaskGradient)
local BoxTransform=require(script.Parent.BoxTransform)
local Counters = require(script.Parent.Parent.CSS.Counters)
local AnimationValues=require(script.Parent.AnimationValues)
local GeneratedContent=require(script.Parent.GeneratedContent)
local PositionedLayout = require(script.Parent.Parent.Layout.PositionedLayout)
local ViewportLayer = require(script.Parent.ViewportLayer)
local DirtyLayout = require(script.Parent.Parent.Layout.DirtyLayout)
local ScrollLayout = require(script.Parent.Parent.Layout.ScrollLayout)
local TextMutation = require(script.Parent.Parent.Layout.TextMutation)
local ImageFallback = require(script.Parent.ImageFallback)
local DOMReconcile = require(script.Parent.DOMReconcile)
local InitialLetter=require(script.Parent.Parent.CSS.InitialLetter)
local FontMetrics=require(script.Parent.Parent.Layout.FontMetrics)
local ScriptTransforms = require(script.Parent.ScriptTransforms)

local function integer(value: string?): number?
	local parsed = if value then tonumber(value:match("^%s*([%+%-]?%d+)")) else nil
	return if parsed and math.abs(parsed) <= 2147483647 then parsed else nil
end

local function imageDimension(value: string?): number?
	local parsed = if value and value:match("^%s*%d+%s*$") then tonumber(value) else nil
	return if parsed and parsed <= 100000 then parsed else nil
end

local function embeddedDocumentType(value: string?): boolean
	if value == nil or value:match("^%s*$") then return true end
	local mime = string.lower((value:match("^%s*([^;]+)") or ""):gsub("%s+$", ""))
	return mime == "text/html" or mime == "application/xhtml+xml"
end

local function refreshListNumbers(box: any)
	local node = box.Node
	if not node or (ElementNames.htmlName(node) ~= "ul" and ElementNames.htmlName(node) ~= "ol" and ElementNames.htmlName(node) ~= "menu") then return end
	local reversed = ElementNames.htmlName(node) == "ol" and node.Attributes.reversed ~= nil
	local count = 0
	for _, child in box.Children do if child.Node and ElementNames.htmlName(child.Node) == "li" and child.Style.ListItem and not child.Style.Hidden then count += 1 end end
	local ordinal = (if ElementNames.htmlName(node) == "ol" then integer(node.Attributes.start) else nil) or (if reversed then count else 1)
	for _, child in box.Children do
		if child.Node and ElementNames.htmlName(child.Node) == "li" and child.Style.ListItem and not child.Style.Hidden then
			ordinal = integer(child.Node.Attributes.value) or ordinal
			if child.Marker and not child.Marker.NumberByCounter and child.Marker.Number~=ordinal then
				child.Marker.Number=ordinal
				child.CachedLayout=nil;child.LayoutMeasurements=nil
				if child.Style.ListStylePosition=="inside" then
					for _,run in child.Children do if run.Kind=="Words" then run.CachedLayout=nil;run.LayoutMeasurements=nil end end
				end
			end
			ordinal += if reversed then -1 else 1
		end
	end
end

function RenderTree.build(document: any, root: GuiObject, diagnostic: (string) -> (), resolveFont: any?, patterns: any?, insets: any?, resolveImage: any?, css: string?, defaultFont: any?, corners: any?, radioDot: any?, resizeGrip: any?, stylesheets: {[string]: string}?, baseURL: string?, mediaResolver: any?, mediaFeatures: any?, backgrounds: any?, disclosureIcons: any?, resolveSVG: any?, fragment: any?): any
	local canvasEnabled=not fragment and backgrounds
	local visualEffects = VisualEffects.new(diagnostic, Factory.createImage, Factory.Task, root)
	-- Until the completed tree transfers ownership to its page, a cancelled
	-- builder still owns any effect textures it has already allocated.
	local buildingCleanup=if root.Destroying then root.Destroying:Connect(function()visualEffects:Destroy()end)else nil
	local rules = if fragment then fragment.Rules else Stylesheet.collect(document, diagnostic, css, stylesheets, baseURL)
	local initialSize = root.AbsoluteSize
	local mediaBase = table.clone(mediaFeatures or {})
	local mediaEnvironment = table.clone(mediaBase)
	mediaEnvironment.Width = if initialSize then initialSize.X else 0
	mediaEnvironment.Height = if initialSize then initialSize.Y else 0
	local function selectedImage(node)
		local state=node.ImageResourceState
		-- The request owner and visual layer share one candidate even when a
		-- request selected under a different viewport is still pending.
		if state and type(state.Raw)=="string"and state.SourceDensity~=nil then return state.Raw,state.SourceDensity,state.DimensionSource or node end
		local width=math.max(1,root.AbsoluteSize and root.AbsoluteSize.X or 1)
		local selected,density,dimensionSource=ResponsiveSources.forImage(node,width,ResponsiveSources.deviceDensity(mediaEnvironment),mediaEnvironment)
		return selected,density,dimensionSource or node
	end
	local function imageHintSource(node)
		if ElementNames.html(node,"img")and ElementNames.html(node.Parent,"picture")then local _,_,source=selectedImage(node);return source end
		return nil
	end
	if not fragment then Stylesheet.setMediaEnvironment(rules, mediaEnvironment)end
	local cssStates = {}
	local styleRecords = {}
	local textOwner
	local shadowRuleSets = setmetatable({}, {__mode = "k"})
	local hostRuleSets = setmetatable({}, {__mode = "k"})
	local slottedRuleSets = setmetatable({}, {__mode = "k"})
	local rulesByShadow = setmetatable({}, {__mode = "k"})
	local slotAssignments = setmetatable({}, {__mode = "k"})
	local shadowRoots = {}
 local discovered = setmetatable({}, {__mode = "k"})
 local stylesheetProvider
 local propertyRegistry={}
 local hasStartingStyles=false
 local containerStyleNames={}
 local hasScrollContainers=false
 local function refreshShadowScopes()
  if fragment then return {}end
  local oldAssignments=table.clone(slotAssignments)
  table.clear(shadowRuleSets);table.clear(hostRuleSets);table.clear(slottedRuleSets);table.clear(slotAssignments);table.clear(shadowRoots);table.clear(discovered)
 local discovery = {document}
	while #discovery > 0 do
		WorkContext.checkpoint()
		local node = table.remove(discovery)
		local shadow = node.InternalShadowRoot
		if shadow and not discovered[shadow] then
			discovered[shadow] = true
			table.insert(shadowRoots, shadow)
			table.insert(discovery, shadow)
		end
		for index = #node.Children, 1, -1 do table.insert(discovery, node.Children[index]) end
	end
	for _, shadow in shadowRoots do
  ShadowTree.Distribute(shadow)
  local compiled = Stylesheet.collect(shadow,diagnostic,nil,stylesheets,baseURL,stylesheetProvider)
  local scopedRules=rulesByShadow[shadow]or compiled
  if scopedRules~=compiled then
   local keyframes=scopedRules.Keyframes;table.clear(keyframes);for name,definition in compiled.Keyframes do keyframes[name]=definition end
   table.clear(scopedRules);for key,value in compiled do scopedRules[key]=value end;scopedRules.Keyframes=keyframes;Stylesheet.invalidate(scopedRules)
  end
  setmetatable(scopedRules.CounterStyles,{__index=rules.CounterStyles})
		Stylesheet.setMediaEnvironment(scopedRules, mediaEnvironment)
		rulesByShadow[shadow] = scopedRules
		hostRuleSets[shadow.Host] = scopedRules
		local pending = {shadow}
  while #pending > 0 do
			local node = table.remove(pending)
			if node ~= shadow then shadowRuleSets[node] = scopedRules end
			if node.Kind == "Element" and ElementNames.htmlName(node) == "slot" then
    slotAssignments[node]=node.AssignedNodes or{}
			end
			for index = #node.Children, 1, -1 do table.insert(pending, node.Children[index]) end
		end
		for _, child in shadow.Host.Children do
			if child.Kind == "Element" or child.Kind == "Text" then
    local slot=child.AssignedSlot
   if slot then
				if child.Kind == "Element" then slottedRuleSets[child] = scopedRules end
			end
			end
		end
	end
  for shadow in rulesByShadow do if not discovered[shadow]then rulesByShadow[shadow]=nil end end
  table.clear(propertyRegistry)
  for name,registration in rules.PropertyRegistry or{}do propertyRegistry[name]=registration end
  for _,shadow in shadowRoots do for name,registration in rulesByShadow[shadow].PropertyRegistry or{}do propertyRegistry[name]=registration end end
  hasStartingStyles=false
  local sets={rules};for _,shadow in shadowRoots do table.insert(sets,rulesByShadow[shadow])end
  table.clear(containerStyleNames);for _,set in sets do for name in set.ContainerStyleNames or{}do containerStyleNames[name]=true end end
  hasScrollContainers=false;for _,set in sets do if set.HasScrollContainers then hasScrollContainers=true;break end end
  for _,set in sets do for index=1,#set do if set[index].Starting then hasStartingStyles=true;break end end;if hasStartingStyles then break end end
  local changedSlots={}
  for slot,assigned in slotAssignments do
   local old=oldAssignments[slot];local same=old~=nil and #old==#assigned
   if same then for i,node in assigned do if node~=old[i]then same=false;break end end end
   if not same then changedSlots[slot]=true end
  end
  return changedSlots
 end
 refreshShadowScopes()
 local fontTargets, seenFonts = {}, {}
	local imageItems, mediaItems, iframeItems, canvasItems, controls = {}, {}, {}, {}, {}
 local svgItems={}
	local disclosures, summaries = {}, {}
	local dialogs, dialogsByNode, dialogHost = {}, {}, nil
	local popovers, popoversByNode, popoverHost = {}, {}, nil
	local viewportPositioned={}
	-- Wrapped text fragments can be replaced without retaining destroyed GUI keys.
	local hitNodes = setmetatable({}, {__mode = "k"})
	local textItemsByGui = setmetatable({}, {__mode = "k"})
	local textItems = {}
	local wordRuns = {}
	local nodeBoxes = setmetatable({}, {__mode = "k"})
	local collapsedTableCells={}
	local nodeStyles={}
	local reconciling=false
	local retainedControls={}
	local controlReconcileStyles={}
	local retiredSelectWrappers={}
	local retainedReplaced={}
	local savedControlStates=setmetatable({},{__mode="k"})
	local pendingControlStates=setmetatable({},{__mode="k"})
	local function unrenderedState(node: any): any
		local c=ControlState.create(node)
		local saved=savedControlStates[node]
		local pending=pendingControlStates[node]
		for field,value in saved or {} do c[field]=value end
		if saved then c.UnrenderedValueSet=true;c.UnrenderedCheckedSet=true end
		if pending then
			for _,field in {"DOMCustomValidity","Indeterminate","DOMDirtyValue","DOMDirtyChecked","SelectionStart","SelectionEnd","SelectionDirection","SelectionValue"}do
				if pending[field]~=nil then c[field]=pending[field]end
			end
			if pending.UnrenderedValueSet then
				for _,field in {"Value","EditText","UserEdited","UserInvalid","BadInput","SelectedIndex","SelectedIndices","DOMDirtyValue","DOMCustomValidity","TemporalParts","TemporalSegment","TemporalDigits","Files","ImagePoint"} do c[field]=pending[field] end
				c.UnrenderedValueSet=true
			end
			if pending.UnrenderedCheckedSet or pending.DOMDirtyChecked then
				for _,field in {"Checked","DOMDirtyChecked","Indeterminate"} do c[field]=pending[field] end
				c.UnrenderedCheckedSet=true
			end
		end
		-- The renderer restored this record before native input can update it.
		-- DOM wrappers can now adopt it without replaying stale pending values.
		c.DOMStateRestored=true
		Directionality.bind(node,c)
		return c
	end
	local function retainStyle(node: any,inherited: any): any
		local current=nodeStyles[node]
		for _,record in styleRecords do
			if record.Node==node and record.Style==current then record.Inherited=inherited;record.TextOwner=textOwner;break end
		end
		return current
	end
	local imageMapItems=setmetatable({},{__mode="k"})
	local imageMapIndex=ImageMap.new(document,imageMapItems)
	local hitStyles=setmetatable({},{__mode="k"})
	local shadowsAvailable = true
	local function paintShadows(box: any,style: any)
		if box.SampledBoxShadows then style.BoxShadows=BoxShadow.resolve(box.SampledBoxShadows,{Color=style.Color,Alpha=style.ColorAlpha or 1})end
		local slots=box.ShadowGuis or {};box.ShadowGuis=slots
		local shadows=style.BoxShadows or {}
		for index=1,math.max(#slots,#shadows) do
			local shadow=shadows[index]
			if shadow and shadow.Inset then shadow=nil end
			local slot=slots[index]
			if shadow and not slot and shadowsAvailable then
				local ok,result=pcall(Factory.modifier,"UIShadow",box.ShadowHost or box.Gui,{
					Name="BoxShadow_"..index,Enabled=true,ZIndex=-index,
					Color=if shadow.Color=="currentcolor" then style.Color else shadow.Color,
					Transparency=1,BlurRadius=UDim.new(0,0),Offset=UDim2.fromOffset(0,0),Spread=UDim2.fromOffset(0,0),
				})
				if ok then slot=result;slots[index]=slot else shadowsAvailable=false;diagnostic("box-shadow unavailable: "..tostring(result)) end
			end
			if slot then
				slot.Color=if shadow then (if shadow.Color=="currentcolor" then style.Color else shadow.Color) else slot.Color
				slot.Transparency=if shadow and style.Visibility~="hidden" then 1-Color.opacity(shadow,style) else 1
				slot.BlurRadius=UDim.new(0,if shadow then shadow.Blur else 0)
				slot.Offset=UDim2.fromOffset(if shadow then shadow.X else 0,if shadow then shadow.Y else 0)
				slot.Spread=UDim2.fromOffset(if shadow then shadow.Spread else 0,if shadow then shadow.Spread else 0)
			end
		end
		if not box.OuterWidth or not box.OuterHeight then return end
		local hasInset=false
		for _,shadow in shadows do if shadow.Inset and Color.opacity(shadow,style)>0 then hasInset=true;break end end
		if hasInset and insets and not box.InsetRenderer then
			-- A Frame cannot change native class. Retain its background/editor and
			-- use one image child underneath its existing text and border layers.
			local host=box.PaintBackgroundGui or box.TableSurface or box.Gui
			box.InsetShadowSurface=Factory.create('ImageLabel',host,{Name='AnimatedInsetShadow',BackgroundTransparency=1,
				ImageTransparency=1,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,1,0),ScaleType=Enum.ScaleType.Stretch,
				ZIndex=0,Active=false})
			if box.InsetShadowSurface.SetAttribute then
				box.InsetShadowSurface:SetAttribute('HTMLHitTestPassthrough',true)
				box.InsetShadowSurface:SetAttribute('HTMLPaintOnlyOverlay',true)
			end
			box.InsetRenderer=insets
		end
		if box.InsetRenderer then box.InsetRenderer:Draw(box,box.OuterWidth,box.OuterHeight)end
	end
	local positioning, opacity = false, false
	local function needsMotionOpacity(style: any): boolean
		for index, name in style.TransitionProperty or {} do
			if (name == "all" or name == "opacity") and (style.TransitionDuration[index] or style.TransitionDuration[1] or 0) > 0 then return true end
		end
		for _, name in style.AnimationName or {} do
			local motionRules=shadowRuleSets[style.Node]or hostRuleSets[style.Node]or rules
   local definition = motionRules.Keyframes and motionRules.Keyframes[name]
			for _, keyframe in if definition then definition.Frames else {} do
				for _, entries in {keyframe.Declarations.Normal, keyframe.Declarations.Important} do
					for _, entry in entries do if not entry.Error and (entry.Field == "Opacity" or entry.VariableProperty == "opacity") then return true end end
				end
			end
		end
		return false
	end
	local function replacedBox(child: any, host: any, item: any, style: any): any
		local box = {Kind = "BlockImage", ImageItem = item, Gui = host, Style = style, Node = child, Children = {},
			Factory = Factory, PaintBackgroundGui = item.BoxGui, ShadowHost = item.BoxGui, Corner = item.BoxCorner or item.Corner}
		if (style.Opacity or 1) < 1 or needsMotionOpacity(style) then
			box.OpacityGroup = GroupOpacity.create(host.Parent, style.Opacity, Factory)
			host.Parent = box.OpacityGroup.Content
			opacity = true
		end
		nodeBoxes[child] = box
		if style.Position ~= "static" then positioning = true end
		if style.Position == "sticky" or style.Position == "fixed" then table.insert(viewportPositioned, box) end
		return box
	end
 local counterState=Counters.new()
 local rootInherited
 local counterLookahead={}
 local generatedRecords={};local generatedReady=false
 local containerKeys=setmetatable({},{__mode='k'})
	local function containerKey(environment)
		local key={};for _,candidate in if environment then environment.Ancestors else{}do
			table.insert(key,tostring(if candidate.WidthEligible then candidate.Width else false)..':'..tostring(if candidate.HeightEligible then candidate.Height else false)..':'..table.concat(candidate.Names,',')..':'..tostring(candidate.QueryFontSize)..':'..tostring(candidate.QueryWritingMode)..':'..tostring(candidate.QueryRootFontSize)..':'..tostring(candidate.ViewportWidth)..':'..tostring(candidate.ViewportHeight))
			for name in containerStyleNames do
				local own=(candidate.Custom or{})[name];local parent=(candidate.ParentCustom or{})[name]
				table.insert(key,name..':'..tostring(own and #own)..':'..tostring(own)..':'..tostring(parent and #parent)..':'..tostring(parent))
			end
			table.insert(key,if candidate.ScrollState then candidate.ScrollState.Key else '')
		end;return table.concat(key,';')
	end
	local function containerFor(node: any): any?
		local ancestor=node.AssignedSlot or node.Parent;local candidates={};local styles=next(containerStyleNames)~=nil
		while ancestor do
			local style=nodeStyles[ancestor]
			if style and ancestor.Kind=='Element'and(styles or style.ContainerType and style.ContainerType~="normal")then
				local box=nodeBoxes[ancestor]
				local width=box and box.ContentWidth or (style.Width and LengthExpression.resolve(style.Width,mediaEnvironment.Width)) or mediaEnvironment.Width
				local height=box and box.ContentHeight or (style.Height and LengthExpression.resolve(style.Height,mediaEnvironment.Height)) or mediaEnvironment.Height
				local kind=style.ContainerType or'normal';local vertical=style.WritingMode~='horizontal-tb';local size=kind=='size'or kind=='size scroll-state';local inline=kind=='inline-size'or kind=='inline-size scroll-state';local principal=style.Display~='none'and style.Display~='contents'
				local parentStyle=nodeStyles[ancestor.AssignedSlot or ancestor.Parent]
				table.insert(candidates,{Width=math.max(0,width),Height=math.max(0,height),Names=style.ContainerNames or {},WidthEligible=principal and(size or inline and not vertical),HeightEligible=principal and(size or inline and vertical),
					QueryFontSize=style.FontSize,QueryWritingMode=style.WritingMode,QueryRootFontSize=style.RootFontSize,
					ViewportWidth=mediaEnvironment.Width,ViewportHeight=mediaEnvironment.Height,StyleEligible=true,
					ScrollEligible=principal and kind:find('scroll-state',1,true)~=nil,ScrollState=box and box.ContainerScrollState,QueryDirection=style.Direction,
					Custom=style.Custom,ParentCustom=parentStyle and parentStyle.Custom,PropertyRegistry=propertyRegistry,Style=style})
			end
			ancestor=if ancestor.Kind=='ShadowRoot'then ancestor.Host else ancestor.AssignedSlot or ancestor.Parent
		end
		if #candidates==0 then return nil end
		local environment=table.clone(candidates[1]);environment.Ancestors=candidates;return environment
	end
 -- Encapsulation scopes cascade outward for normal declarations and inward
 -- for important declarations. Keep this order for elements and their pseudos.
 local function scopeCascade(sources: any,own: any): any
  local result=table.clone(own);result.Normal={};result.Important={}
  for _,source in sources do for _,entry in source.Normal do table.insert(result.Normal,entry)end end
  for index=#sources,1,-1 do for _,entry in sources[index].Important do table.insert(result.Important,entry)end end
  return result
 end
 local function appendPartScopes(sources:any,node:any,container:any,starting:boolean?,pseudo:string?)
  for _,root in Stylesheet.partScopes(node)do
   local scoped=if root.Kind=='ShadowRoot'then rulesByShadow[root]else rules
   if scoped then table.insert(sources,Stylesheet.matchPart(scoped,node,cssStates,container,starting,pseudo))end
  end
 end
	local function matched(node: any,starting: boolean?): any
		if fragment then return fragment.Match(node,starting)end
		local container = containerFor(node)
  containerKeys[node]=containerKey(container)
		local own = table.clone(Stylesheet.match(shadowRuleSets[node] or rules, node, cssStates, container,starting))
  for _,candidate in if container then container.Ancestors else{}do
   if own.ContainerWidth==nil and candidate.WidthEligible then own.ContainerWidth=candidate.Width end
   if own.ContainerHeight==nil and candidate.HeightEligible then own.ContainerHeight=candidate.Height end
  end
  own.CounterStyles=(shadowRuleSets[node]or rules).CounterStyles
  own.PropertyRegistry=propertyRegistry
  own.FocusVisible=cssStates["focus-visible"]==node
  own.SelectPartState=selectPartState(node,cssStates)
  -- Inline declarations belong to this element's tree scope. Applying them
  -- after all scopes would incorrectly outrank an outer part's normal rule or
  -- an inner host's important rule.
  local inline=Style.compile(node.Attributes.style or'')
  own.Normal=table.clone(own.Normal);own.Important=table.clone(own.Important)
  for _,entry in inline.Normal do local copy=table.clone(entry);copy.CascadeInline=true;table.insert(own.Normal,copy)end
  for _,entry in inline.Important do local copy=table.clone(entry);copy.CascadeInline=true;table.insert(own.Important,copy)end
  own.InlineIncluded=true
		if ElementNames.htmlName(node)=="dialog" or(node.Attributes and node.Attributes.popover~=nil)then
			own=table.clone(own)
			own.Modal=cssStates.modal and cssStates.modal[node]==true or false
			own.PopoverOpen=cssStates["popover-open"] and cssStates["popover-open"][node]==true or false
		end
		local specialRules = hostRuleSets[node] or slottedRuleSets[node]
  local sources={}
  if specialRules then table.insert(sources,Stylesheet.matchShadow(specialRules,node,if hostRuleSets[node]then 'host'else 'slotted',cssStates,container,starting))end
  table.insert(sources,own);appendPartScopes(sources,node,container,starting)
  return if #sources==1 then own else scopeCascade(sources,own)
	end
	local function richButton(node: any): boolean
		if ElementNames.htmlName(node)~="button" then return false end
		if ControlDefaults.selectButton(node)then return false end
		if nodeBoxes[node] and nodeBoxes[node].RichButton then return true end
		for _,child in node.Children or {} do if child.Kind=="Element" then return true end end
		return false
	end
	local function richSelect(node: any,style: any): boolean
		return ElementNames.htmlName(node)=='select'and style.Appearance=='base-select'
	end
	local function buttonDisplay(node: any,computed: any)
		-- Rich button contents form their own formatting context, never an
		-- inline text fragment or a flattened native control caption.
		if richButton(node) and computed.Display=="inline" then computed.Display="inline-block" end
	end
	local function resolve(node: any, inherited: any, inline: boolean?): any
		local declarations = if node.GeneratedSelectLabel then {Normal={},Important={}}else matched(node)
		local dimensionSource=imageHintSource(node)
		-- A stylesheet can blockify a normally inline element. Resolve that
		-- decision before applying the restrictions of inline text fragments.
		if inline then
			local candidate = Style.resolve(node, inherited, function() end, false, declarations,nil,nil,nil,dimensionSource)
			if candidate.Display ~= "inline" or candidate.Position == "absolute" or candidate.Position == "fixed" then inline = false end
		end
		local result = if fragment and node==fragment.Node then fragment.ResolveRoot(inherited)else Style.resolve(node, inherited, diagnostic, inline, declarations,nil,nil,nil,dimensionSource)
		buttonDisplay(node,result)
		result.Node = node
		result.HTMLDirectionality=Directionality.of(node)
		result.HyphenationLanguage=if result.Hyphens=="auto"then LanguageRange.language(node)else ""
		result.TextTransformLanguage=if result.TextTransform and result.TextTransform~='none'then LanguageRange.language(node)else ""
		result.AutoCursor=if (ElementNames.htmlName(node) == "a" and node.Attributes.href ~= nil) or ((ElementNames.htmlName(node) == "audio" or ElementNames.htmlName(node) == "video") and node.Attributes.controls ~= nil) then "pointer" else inherited.AutoCursor
		nodeStyles[node]=result
		result.TableBorderMode = if result.TableRole == "table" then result.BorderCollapse else inherited.TableBorderMode
		result.CollapsedBorder = result.TableRole ~= nil and result.TableRole ~= "caption" and result.TableBorderMode == "collapse"
		result.HitNode = if ElementNames.htmlName(node) == "label" then node else inherited.HitNode
		if result.Opacity < 1 then opacity = true end
		table.insert(styleRecords, {Node=node, Inherited=inherited, Inline=inline, Style=result, TextOwner=textOwner})
		return result
	end
	local function tableGeometry(s: any)
		-- These table-model overrides must be identical during construction and
		-- recascade. In particular, nil and zero row/group edges are not changes.
		if s.CollapsedBorder then s.BorderRadius=0 end
		if s.TableRole=="row"or s.TableRole=="group"then
			s.Margin,s.MarginValues,s.MarginAuto={0,0,0,0},{0,0,0,0},{false,false,false,false}
			s.Padding,s.PaddingValues={0,0,0,0},{0,0,0,0};s.BorderSize,s.BorderSizes=0,{0,0,0,0}
		elseif s.TableRole=="cell"then s.Margin,s.MarginValues,s.MarginAuto={0,0,0,0},{0,0,0,0},{false,false,false,false}
		elseif s.TableRole=="table"and s.CollapsedBorder then s.Padding,s.PaddingValues={0,0,0,0},{0,0,0,0}end
	end
	local function recascade(record:any,metricOverrides:any?,colorOverrides:any?,shadowOverride:any?):any
  local declarations=if record.Node.GeneratedSelectLabel then {Normal={},Important={}}else matched(record.Node);local computed
  local dimensionSource=imageHintSource(record.Node)
  if record.Inline then
   local candidate=Style.resolve(record.Node,record.Inherited,function()end,false,declarations,metricOverrides,colorOverrides,shadowOverride,dimensionSource)
   if candidate.Display~='inline'or candidate.Position=='absolute'or candidate.Position=='fixed'then record.Inline=false;computed=candidate end
  end
		computed=computed or (if fragment and record.Node==fragment.Node then fragment.ResolveRoot(record.Inherited)else Style.resolve(record.Node,record.Inherited,diagnostic,record.Inline,declarations,metricOverrides,colorOverrides,shadowOverride,dimensionSource))
		buttonDisplay(record.Node,computed)
		computed.HTMLDirectionality=Directionality.of(record.Node)
		computed.HyphenationLanguage=if computed.Hyphens=="auto"then LanguageRange.language(record.Node)else ""
		computed.TextTransformLanguage=if computed.TextTransform and computed.TextTransform~='none'then LanguageRange.language(record.Node)else ""
  computed.TableBorderMode=if computed.TableRole=='table'then computed.BorderCollapse else record.Inherited.TableBorderMode
  computed.CollapsedBorder=computed.TableRole~=nil and computed.TableRole~='caption'and computed.TableBorderMode=='collapse'
  tableGeometry(computed)
  return computed
 end
	local function contentText(parts: any,node: any): string
		local result={}
		for _,part in parts or {} do
			if part.Kind=="text" then table.insert(result,part.Value)
			elseif part.Kind=="attr" then table.insert(result,node.Attributes[part.Name] or "")
			elseif part.Kind=="counter" or part.Kind=="counters" then table.insert(result,Counters.render(counterState,part)) end
		end
		return table.concat(result)
	end
 local counterStyleFor
 local function resolvePseudo(node: any,inherited: any,name: string,targetCurrent: boolean?,force: boolean?,pickerPart: boolean?,pickerClosed: boolean?): any?
		if fragment and fragment.Pseudo then return fragment.Pseudo(node,inherited,name,targetCurrent,force)end
		-- Hidden data options have no generated boxes on the main page. Their
		-- computed pseudo can still be queried, and the popup owns its own view.
		if name=='checkmark'and not force and not pickerPart and not nodeBoxes[node]then return nil end
		local nativePart=name=='picker-icon'or name=='checkmark'or name=='picker(select)'
		if nativePart then
			local select=if name~='checkmark'then node else node.Parent
			if name=='checkmark'and ElementNames.htmlName(node)~='option'then return nil end
			while select and ElementNames.htmlName(select)~='select'do select=select.Parent end
			if not select then return nil end
			local controlStyle=if select==node then inherited else nodeStyles[select]or counterStyleFor(select)
			if controlStyle.Appearance~='base-select'then return nil end
			local list=select.Attributes.multiple~=nil or AttributeValues.positive(select.Attributes.size,1)>1
			if name=='picker-icon'and list then return nil end
			if name=='checkmark'and not list then
				local picker=resolvePseudo(select,controlStyle,'picker(select)')
				if not picker or picker.Appearance~='base-select'then return nil end
			end
		end
  local ruleSet=shadowRuleSets[node]or rules;local container=containerFor(node)
		local declarations=table.clone(Stylesheet.matchPseudo(ruleSet,node,name,cssStates,container,targetCurrent))
  declarations.CounterStyles=ruleSet.CounterStyles
  declarations.PropertyRegistry=propertyRegistry
  local sources={};local special=hostRuleSets[node]or slottedRuleSets[node]
  if special then table.insert(sources,Stylesheet.matchPseudo(special,node,name,cssStates,container,targetCurrent))end
  table.insert(sources,declarations);appendPartScopes(sources,node,container,nil,name)
  if #sources>1 then declarations=scopeCascade(sources,declarations)end
		if name=='picker(select)'then declarations.PositionTries=ruleSet.PositionTries end
		if not force and not nativePart and #declarations.Normal==0 and #declarations.Important==0 then return nil end
		local fake={Kind="Element",Name="span",Attributes={},Children={},Parent=node,GeneratedHost=node,GeneratedPseudo=name,
			PseudoChecked=if name=='checkmark'then Selectors.optionSelected(node,cssStates)else nil,PickerClosed=pickerClosed}
  local result=Style.resolve(fake,inherited,diagnostic,not nativePart and name~='first-letter'and name~='before'and name~='after'and name~="backdrop" and name~="scroll-marker",declarations)
		if nativePart and result.Display=='inline'and (inherited.Display=='flex'or inherited.Display=='inline-flex'or inherited.Display=='grid'or inherited.Display=='inline-grid')then result.Display='block'end
		result.Node=node;result.PseudoElement=name;result.ListItem=false
		return result
	end
 counterStyleFor=function(node)
  if not node or node.Kind=="Document"then return rootInherited end
  local current=nodeStyles[node]or counterLookahead[node];if current then return current end
  local inherited=counterStyleFor(ShadowTree.FlatParent(node))
  if node.Kind~="Element"then return inherited end
  -- Ordinal/reversed-counter scans can visit a later subtree before the
  -- renderer gets there. Resolve its whole inherited chain, without creating
  -- render/style records or substituting an empty parent for relative fonts.
  local computed=Style.resolve(node,inherited,function()end,false,matched(node))
  computed.Node=node;counterLookahead[node]=computed;return computed
 end
 counterState.StyleFor=counterStyleFor
 counterState.PseudoFor=resolvePseudo
 local function updateMarker(box,style)
  if not style.ListItem or ElementNames.htmlName(box.Node)=='summary'then return end
  local node=box.Node;local record=generatedReady and generatedRecords[node]and generatedRecords[node].marker
  local markerStyle=if record then record.Style else resolvePseudo(node,style,'marker')or GeneratedContent.markerStyle(style)
  local text
  if record then text=record.Text else
   counterState.Registry=markerStyle.CounterStyles
   if markerStyle~=style then Counters.enter(counterState,markerStyle)end
   text=contentText(markerStyle.GeneratedContent,node)
   if markerStyle~=style then Counters.leave(counterState)end
  end
  local custom=markerStyle~=style and #(markerStyle.GeneratedContent or{})>0
  local image=if not custom and style.ListStyleImage and resolveImage then resolveImage(style.ListStyleImage)else nil
  local kind=if markerStyle.GeneratedContent.Mode=='none'then 'none'elseif custom then 'custom'elseif image then 'image'else style.ListStyleType
  local class=if kind=='none'then nil elseif kind=='image'then 'ImageLabel'elseif kind=='disc'or kind=='circle'or kind=='square'then 'Frame'else 'TextLabel'
  local marker=box.Marker or{Number=integer(node.Attributes.value)or 1,ResolveFont=resolveFont}
  marker.Number=if record then record.Number else (if not custom then Counters.markerNumber(counterState,node,style)else nil)or Counters.value(counterState,'list-item');marker.NumberByCounter=true
  if not generatedReady then
   generatedRecords[node]=generatedRecords[node]or{};generatedRecords[node].marker={Style=markerStyle,Text=text,Number=marker.Number}
  end
  local replace=marker.Kind~=kind and (marker.Kind=='disc'or marker.Kind=='circle'or kind=='disc'or kind=='circle')or marker.Gui and marker.Gui.ClassName~=class
  if marker.Gui and(replace or not class)then marker.Gui:Destroy();marker.Gui=nil end
  marker.Kind,marker.CustomText,marker.Style=kind,if custom then text else nil,markerStyle
  if not class then box.Marker=nil;return end
  local properties={Name='ListMarker'}
  if class=='TextLabel'then
   local face=if resolveFont then resolveFont(markerStyle.Font,markerStyle.FontWeight,markerStyle.FontStyle)else nil
   properties.FontFace,properties.OpenTypeFeatures=face,markerStyle.OpenTypeFeatures
   properties.TextColor3,properties.TextTransparency=markerStyle.Color,1-(markerStyle.ColorAlpha or 1)
  elseif class=='ImageLabel'then properties.Image,properties.BackgroundTransparency,properties.ScaleType=image,1,Enum.ScaleType.Fit
   properties.ResampleMode=if style.ImageRendering=='pixelated'or style.ImageRendering=='crisp-edges'then Enum.ResamplerMode.Pixelated else Enum.ResamplerMode.Default
  else properties.BackgroundColor3,properties.BackgroundTransparency=markerStyle.Color,if kind=='circle'then 1 else 1-(markerStyle.ColorAlpha or 1)end
  if not marker.Gui then
   marker.Gui=Factory.create(class,box.Gui,properties)
   if class=='TextLabel'and properties.FontFace and not seenFonts[properties.FontFace]then seenFonts[properties.FontFace]=true;table.insert(fontTargets,marker.Gui)end
   if class=='Frame'and kind~='square'then Factory.modifier('UICorner',marker.Gui,{CornerRadius=UDim.new(.5,0)})end
   if kind=='circle'then Factory.modifier('UIStroke',marker.Gui,{Thickness=1,Color=markerStyle.Color,Transparency=1-(markerStyle.ColorAlpha or 1),ApplyStrokeMode=Enum.ApplyStrokeMode.Border,BorderStrokePosition=Enum.BorderStrokePosition.Inner,LineJoinMode=Enum.LineJoinMode.Round})end
  else for field,value in properties do marker.Gui[field]=value end end
  marker.Gui.Visible=not style.Hidden and style.Visibility~='hidden'
  box.Marker=marker
 end
	local tree
	local pendingContentReveals={}
	local wordPaintHosts=setmetatable({},{__mode='kv'})
	local pendingWordPaintHosts={}
	local pendingDisclosureReveals={}
	local function queueDisclosureReveal(value)
		value.Body.LayoutRevealPending=true;pendingDisclosureReveals[value]=true
	end
	local function wordPaintParent(parent)
		if not tree or not tree.PendingPresentationEnabled then return parent end
		local host=wordPaintHosts[parent]
		if not host then
			host=Factory.create('Frame',parent,{Name='WordPaintHost',BackgroundTransparency=1,
				Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),Visible=false})
			if host.SetAttribute then host:SetAttribute('HTMLHitTestPassthrough',true)end
			wordPaintHosts[parent]=host
		end
		if host.Visible~=false then host.Visible=false end;pendingWordPaintHosts[host]=true
		return host
	end
	-- Install the table model lazily, including a block which later becomes
	-- a table. Ordinary boxes do not allocate their own preparation closure.
	local function prepareTable(box)
		function box:RefreshTable(paintOnly:boolean?)
			local style,node=self.Style,self.Node
			local function tableStyle(current,parentStyle)
				local s=current.Style
				s.TableBorderMode=if s.TableRole=="table"then s.BorderCollapse else parentStyle.TableBorderMode
				s.CollapsedBorder=s.TableRole~=nil and s.TableRole~="caption"and s.TableBorderMode=="collapse"
				current.TableBorderSource=if s.CollapsedBorder then table.clone(s)else nil
				tableGeometry(s)
				for _,child in current.Children do
					if child.Style and child.Style.TableRole and child.Style.TableRole~="table"then tableStyle(child,s)end
				end
			end
			tableStyle(self,style)
			for _,entry in self.TableGrid and self.TableGrid.Entries or{}do collapsedTableCells[entry.Cell.Node]=nil end
			local function resolveColumn(column,inheritedStyle)
				-- Reuse recascaded column records instead of accumulating them.
				if nodeStyles[column]then return retainStyle(column,inheritedStyle)end
				return resolve(column,inheritedStyle)
			end
			self.TableColumns,self.TableColumnGroups=TableColumns.read(node,style,resolveColumn,diagnostic)
			TableLayout.prepare(self,diagnostic)
			for _,entry in self.TableGrid.Entries do
				if entry.VisibleRows==0 or entry.VisibleColumns==0 then collapsedTableCells[entry.Cell.Node]=true end
			end
			TableCaptions.create(self,Factory,hitNodes)
			TableColumnPaint.create(self,Factory,hitNodes)
			TableBorderPaint.create(self,Factory,hitNodes)
			if paintOnly and self.PaintedColumnWidths and self.PaintedRowHeights then
				for _,entry in self.TableGrid.Entries do TableColumnPaint.arrange(entry.Cell,entry.Cell.OuterHeight)end
				TableBorderPaint.arrange(self,self.PaintedColumnWidths,self.PaintedRowHeights,self.TablePaintLeft or 0,self.TablePaintTop or 0)
			end
		end
		box:RefreshTable()
	end
	local function build(node: any, gui: GuiObject, inherited: any, resolved: any?): any
		WorkContext.checkpoint()
		if reconciling and nodeBoxes[node] then
			local existing=nodeBoxes[node]
			local outer=if existing.OpacityGroup then existing.OpacityGroup.Gui else existing.Gui
			if outer.Parent~=gui then outer.Parent=gui;DirtyLayout.invalidate(existing) end
			retainStyle(node,inherited)
			return existing
		end
		local retainedSelect=if reconciling and ElementNames.htmlName(node)=='select'then retainedControls[node]else nil
		local style = resolved or (if node.Kind == "Document" then inherited elseif retainedSelect then retainStyle(node,inherited)else resolve(node, inherited))
		-- Ruby participates in the surrounding line height, but its base text
		-- uses a compact internal line box. Inheriting a tall paragraph line-height
		-- here separates the annotation from the base by half the extra leading.
		local rubyTextStyle
		if ElementNames.htmlName(node)=="ruby" then
			rubyTextStyle=table.clone(style)
			rubyTextStyle.LineHeight={Kind="normal"}
			style.RubyTextStyle=rubyTextStyle
		end
		-- Keep initially hidden block subtrees available for media/state changes.
		-- Their counters must not advance the visible document while hidden.
		local visibleCounters = if style.Hidden then counterState else nil
		if visibleCounters then
			counterState = {Depth = visibleCounters.Depth, Values = {}}
			for name, stack in visibleCounters.Values do
				local copied = {}; for _, entry in stack do table.insert(copied, table.clone(entry)) end
				counterState.Values[name] = copied
			end
		end
		Counters.enter(counterState,style)
		local borderSource = if style.CollapsedBorder then table.clone(style) else nil
		if style.CollapsedBorder then
			style.BorderRadius=0
			if style.TableRole == "table" then style.Padding,style.PaddingValues={0,0,0,0},{0,0,0,0} end
		end
		if style.TableRole == "cell" or style.TableRole == "row" or style.TableRole == "group" then
			style.Margin,style.MarginValues,style.MarginAuto={0,0,0,0},{0,0,0,0},{false,false,false,false}
			if style.TableRole ~= "cell" then
				style.Padding,style.PaddingValues={0,0,0,0},{0,0,0,0}
				style.BorderSize,style.BorderSizes=0,{0,0,0,0}
			end
		end
		local disclosure
		if ElementNames.htmlName(node) == "details" then
			disclosure=Disclosure.new(node)
			if tree and tree.PendingPresentationEnabled then disclosure.QueueReveal=queueDisclosureReveal end
			disclosures[node],summaries[disclosure.SummaryNode]=disclosure,disclosure
		end
		local summary=summaries[node]
		if summary then style.ListItem=false; style.ListStylePosition="inside" end
		if style.Position ~= "static" then positioning = true end
		local visible = style.Visibility ~= "hidden"
		local motionOpacity=false
		for index,name in style.TransitionProperty or {} do if (name=="all" or name=="opacity") and (style.TransitionDuration[index] or style.TransitionDuration[1] or 0)>0 then motionOpacity=true;break end end
		if not motionOpacity then for _,name in style.AnimationName or {} do
			local motionRules=shadowRuleSets[node]or hostRuleSets[node]or rules
   local definition=motionRules.Keyframes and motionRules.Keyframes[name]
			for _,keyframe in if definition then definition.Frames else {} do for _,entries in {keyframe.Declarations.Normal,keyframe.Declarations.Important} do for _,entry in entries do if not entry.Error and (entry.Field=="Opacity" or entry.VariableProperty=="opacity") then motionOpacity=true;break end end;if motionOpacity then break end end;if motionOpacity then break end end
			if motionOpacity then break end
		end end
		local opacityGroup
		if style.BackdropFilter and not style.Background then
			local brightness=math.clamp(style.BackdropFilter.Brightness or 1,0,1)
			style.Background=Color3.new(brightness,brightness,brightness)
			style.BackgroundAlpha=math.clamp(.16+(style.BackdropFilter.Blur or 0)/160,.16,.55)
		end
		local maskDefinition=style.MaskImage or style.MaskBorderSource
		local nativeFilter=ElementNames.htmlName(node)~='img' and style.Filter and #style.Filter.Steps>0
		if node.Kind ~= "Document" and ((style.Opacity or 1) < 1 or motionOpacity or maskDefinition~=nil or style.Isolation=="isolate" or nativeFilter) then
			opacityGroup = GroupOpacity.create(gui, style.Opacity, Factory)
			GroupOpacity.paint(opacityGroup,style)
			gui = opacityGroup.Content
			opacity = true
			if maskDefinition and maskDefinition.Kind=="linear" then
				local mask=maskDefinition
				opacityGroup.Mask=Factory.modifier("UIGradient",opacityGroup.Gui,{
					Rotation=mask.Rotation,Transparency=MaskGradient.sequence(style,mask,1,1)
				})
				opacityGroup.MaskClip=Factory.create("Frame",opacityGroup.Gui,{Name="MaskClip",ClipsDescendants=true})
				if opacityGroup.MaskClip.SetAttribute then opacityGroup.MaskClip:SetAttribute("HTMLHitTestPassthrough",true) end
				opacityGroup.Content.Parent=opacityGroup.MaskClip
			end
		end
		local hasInset = false
		for _, shadow in style.BoxShadows or {} do
			if visible and shadow.Inset and Color.opacity(shadow, style) > 0 then hasInset = true; break end
		end
		-- The inset image is the box's own image layer: above its background,
		-- below text/children and borders, without another overlay GuiObject.
		local frame = if node.Kind == "Document" then gui elseif retainedSelect then retainedSelect.Item.Gui else Factory.create(if hasInset then "ImageLabel" else "Frame", gui, {
			Name = node.Attributes.id or node.Name,
			Visible = style.Hidden ~= true,
			-- The container must remain visible for explicitly visible descendants.
			BackgroundTransparency = if visible and style.Background and style.TableRole ~= "row" and style.TableRole ~= "group" then 1 - (style.BackgroundAlpha or 1) else 1,
			BackgroundColor3 = style.Background or Color3.new(1, 1, 1),
			ClipsDescendants = (style.Overflow == "hidden" and style.OverflowX~="clip" and style.OverflowY~="clip") or style.Contain.Paint==true or style.ClipPath~=nil,
			ImageTransparency = if hasInset then 1 else nil,
			ScaleType = if hasInset then Enum.ScaleType.Stretch else nil,
		})
		if retainedSelect then
			ControlView.releaseSelectView(retainedSelect.Item);frame.Parent=gui
			local previous=retiredSelectWrappers[node];retiredSelectWrappers[node]=nil
			if previous then
				hitNodes[previous.Gui],hitStyles[previous.Gui]=nil,nil
				visualEffects:Remove(previous)
				for _,resource in {insets,backgrounds,corners}do if resource.Remove then resource:Remove(previous)end end
				(if previous.OpacityGroup then previous.OpacityGroup.Gui else previous.Gui):Destroy()
			end
		end
		hitNodes[frame] = node
		hitStyles[frame]=style
		if (style.TableRole == "row" or style.TableRole == "group") and frame.SetAttribute then frame:SetAttribute("HTMLTableStructure",true) end
		local nativeCornerRadii=CornerRadii.native(style)
		style.NativeCornerRadii=nativeCornerRadii
		local semanticRole = style.SemanticRole
		local semanticLabel = style.SemanticLabel
		local box: any = { Gui = frame, Style = style, Children = {}, Node = node, OpacityGroup = opacityGroup, MaskDefinition=maskDefinition, InsetRenderer = if hasInset then insets else nil,
			BackgroundRenderer=if node.Kind~="Document" then backgrounds else nil,Factory=Factory,
			VisualEffects=visualEffects,
			ResolveImage=resolveImage,
			SemanticRole = semanticRole, SemanticLabel = semanticLabel }
		if disclosure then disclosure.Box=box end
		if opacityGroup then opacityGroup.Gui.Visible = style.Hidden ~= true end
		local snapAlign=style.ScrollSnapAlign
		if node.Kind=="Element" and snapAlign and (snapAlign.Block~="none" or snapAlign.Inline~="none") then
			box.ScrollMarkerStyle=resolvePseudo(node,style,"scroll-marker")
			box.ScrollMarkerCurrentStyle=resolvePseudo(node,style,"scroll-marker",true) or box.ScrollMarkerStyle
			if box.ScrollMarkerStyle then box.ScrollMarkerText=contentText(box.ScrollMarkerStyle.GeneratedContent,node) end
			if box.ScrollMarkerCurrentStyle then box.ScrollMarkerCurrentText=contentText(box.ScrollMarkerCurrentStyle.GeneratedContent,node) end
			local markerStyle=box.ScrollMarkerStyle or box.ScrollMarkerCurrentStyle
			if markerStyle and resolveFont then box.ScrollMarkerFontFace=resolveFont(markerStyle.Font,markerStyle.FontWeight,markerStyle.FontStyle) end
		end
		if style.Position=="sticky" or style.Position=="fixed" then table.insert(viewportPositioned,box) end
		if style.BorderRadii and (style.BorderRadius==0 or style.CornerShape~="round") then
			box.NativeCornerRadii=nativeCornerRadii
			if not nativeCornerRadii then box.RadiusRenderer=corners end
		end
		nodeBoxes[node] = box
		if richButton(node)or richSelect(node,style) then
			local c=retainedSelect or unrenderedState(node);pendingControlStates[node]=nil
			box.RichButton=true;box.RichSelect=ElementNames.htmlName(node)=='select';box.Control=c;c.LayoutStyle=style
			box.RichSelectList=box.RichSelect and c.SelectList==true
			local item=c.Item or{};c.Item=item
			item.Control,item.Gui,item.BoxGui,item.Style,item.Factory,item.RichButton,item.RichSelect,item.Box=c,frame,frame,style,Factory,true,box.RichSelect,box
			if box.RichSelect then
				box.SelectRenderBox=true
				c.Item.FontResolver=resolveFont
				c.Item.FontFace=if resolveFont then resolveFont(style.Font,style.FontWeight,style.FontStyle)else nil
				c.PickerStyle=resolvePseudo(node,style,'picker(select)')
				c.Item.ResolvePickerStyle=function()return resolvePseudo(node,c.Item.Style,'picker(select)')end
			end
			if not retainedSelect then table.insert(controls,c)end;ControlView.paint(c.Item)
		end
		if frame.SetAttribute and semanticRole then
			frame:SetAttribute("HTMLTag", node.Name)
			frame:SetAttribute("HTMLSemanticRole", semanticRole)
			if semanticLabel and semanticLabel ~= "" then frame:SetAttribute("HTMLSemanticLabel", semanticLabel) end
		end
		local dialogState
		if ElementNames.htmlName(node) == "dialog" then
			box.TopLayerParent=(if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui).Parent
			dialogHost = dialogHost or Dialog.host(root, Factory)
			positioning = true
		end
		if node.Attributes and node.Attributes.popover ~= nil then
			box.TopLayerParent=(if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui).Parent
			popoverHost = popoverHost or Popover.host(root, Factory)
			positioning = true
		end
		box.TableBorderSource=borderSource
		if style.TableRole == "table" then box.TableColumns,box.TableColumnGroups=TableColumns.read(node,style,resolve,diagnostic) end
		if summary then
			local c={Node=node,Type="summary",Name="",Value="",Disabled=false,TabIndex=tonumber(node.Attributes.tabindex or "") or 0,Disclosure=summary}
			c.Item={Control=c,Gui=frame,Style=style}
			c.Item.FocusStroke=Factory.modifier("UIStroke",frame,{Thickness=1,Color=style.Color,Enabled=false,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
			table.insert(controls,c)
			summary.Control=c
			if style.ListStyleType ~= "none" then box.Marker=Disclosure.marker(summary,frame,Factory,disclosureIcons); box.Marker.Gui.Visible=visible end
		end
		updateMarker(box,style)
		if node.Kind ~= "Document" then
			if (style.BorderRadius or 0) > 0 and style.CornerShape=="round" then
				box.Corner=Factory.modifier("UICorner", frame, {CornerRadius = UDim.new(0, style.BorderRadius)})
			elseif style.BorderRadii then
				box.Corner=if nativeCornerRadii then Factory.modifier("UICorner",frame,{
					TopLeftRadius=UDim.new(0,0),TopRightRadius=UDim.new(0,0),
					BottomRightRadius=UDim.new(0,0),BottomLeftRadius=UDim.new(0,0),
				}) else Factory.modifier("UICorner",frame,{CornerRadius=UDim.new(0,0)})
			end
			paintShadows(box,style)
			if not style.CollapsedBorder then
				local borderHost = frame
				if style.TableRole == "cell" and style.EmptyCells == "hide" then
					borderHost = Factory.create("Frame", frame, {Name="CellBorder",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
					box.CellBorder = borderHost
					if (style.BorderRadius or 0) > 0 then Factory.modifier("UICorner",borderHost,{CornerRadius=UDim.new(0,style.BorderRadius)}) end
				end
				box.InsetEdges = BorderBox.create(style, borderHost, Factory, corners)
			end
			box.Outline = OutlineBox.create(style, frame, Factory, corners)
			if box.Outline then frame.ClipsDescendants = false end
		end
		if node.Kind ~= "Document" and (style.Contain.Paint==true or style.ClipPath~=nil) then
			-- Roblox's ordinary ClipsDescendants can ignore rotated descendants.
			-- A transparent CanvasGroup supplies a stable retained clip surface.
			-- Paint containment clips at the padding edge, inside any border.
			local border=style.BorderSizes or {style.BorderSize or 0,style.BorderSize or 0,style.BorderSize or 0,style.BorderSize or 0}
			local inset=style.Contain.Paint==true and (border[1]>0 or border[2]>0 or border[3]>0 or border[4]>0)
			box.PaintClip=Factory.create("CanvasGroup",frame,{
				Name="PaintContainment",BackgroundTransparency=1,GroupTransparency=0,
				Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),ClipsDescendants=true,
			})
			frame=box.PaintClip
			if inset then
				-- Descendant layout coordinates still refer to the border box.
				box.PaintContent=Factory.create("Frame",frame,{Name="PaintContent",BackgroundTransparency=1})
				frame=box.PaintContent
			end
		end
		if node.Kind ~= "Document" and (style.OverflowX=="clip" or style.OverflowY=="clip") then
			box.OverflowClip=Factory.create("CanvasGroup",frame,{
				Name="OverflowClip",BackgroundTransparency=1,GroupTransparency=0,
				Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(0,0),ClipsDescendants=true,
			})
			if (style.BorderRadius or 0)>0 or style.BorderRadii then
				box.OverflowClipCorner=Factory.modifier("UICorner",box.OverflowClip,{CornerRadius=UDim.new(0,0)})
			end
			box.OverflowContent=Factory.create("Frame",box.OverflowClip,{Name="OverflowContent",BackgroundTransparency=1})
			frame=box.OverflowContent
			if box.Marker then box.Marker.Gui.Parent=frame end
		end
		if node.Kind ~= "Document" and (style.OverflowX == "auto" or style.OverflowX == "scroll"
			or style.OverflowY == "auto" or style.OverflowY == "scroll" or ElementNames.htmlName(node)=="dialog") then
			local scrollbar=style.ScrollbarColor
			local scrollbarThickness=if style.ScrollbarWidth=="none" then 0 elseif style.ScrollbarWidth=="thin" then 6 else 10
			box.ScrollGui = Factory.create("ScrollingFrame", frame, {
				ClipsDescendants=style.OverflowX~="visible" or style.OverflowY~="visible",
				Name = "OverflowScroll", CanvasSize = UDim2.fromOffset(0, 0), CanvasPosition = Vector2.new(0, 0),
				ScrollingDirection = if style.TouchAction=="pan-x" then Enum.ScrollingDirection.X elseif style.TouchAction=="pan-y" then Enum.ScrollingDirection.Y
					elseif style.OverflowX == "hidden" then Enum.ScrollingDirection.Y
					elseif style.OverflowY == "hidden" then Enum.ScrollingDirection.X else Enum.ScrollingDirection.XY,
				ElasticBehavior = if style.OverscrollX=="auto" and style.OverscrollY=="auto" then Enum.ElasticBehavior.WhenScrollable else Enum.ElasticBehavior.Never, ScrollBarThickness = scrollbarThickness,
				ScrollBarImageColor3 = if scrollbar and not scrollbar.Auto then scrollbar.Thumb else Color3.fromRGB(139,139,139),
				ScrollBarImageTransparency = if visible and scrollbarThickness>0 then 1-(if scrollbar and not scrollbar.Auto then scrollbar.ThumbAlpha or 1 else 1) else 1,
			})
			-- An idle track keeps overflow:scroll visible without inventing scrollable pixels.
			for _, axis in {"X", "Y"} do
				if style["Overflow" .. axis] == "scroll" then
					box["ScrollTrack" .. axis] = Factory.create("Frame", frame, {
						Name = "IdleScrollTrack" .. axis,
						BackgroundColor3 = if scrollbar and not scrollbar.Auto then scrollbar.Track else Color3.fromRGB(225, 225, 225),
						BackgroundTransparency=if scrollbar and not scrollbar.Auto then 1-(scrollbar.TrackAlpha or 1) else 0,Visible = false, ZIndex = 2,
					})
				end
			end
			box.ScrollContent = Factory.create("Frame", box.ScrollGui, {Name = "ScrollContent"})
			frame = box.ScrollContent
			if box.Marker then box.Marker.Gui.Parent = frame end
		end
		if box.SelectRenderBox then
			-- The retained content closure follows this host when a mounted base
			-- dropdown first becomes a list. Later modes reuse the same scroll host.
			function box:SetSelectList(list)
				self.RichSelectList=list
				if list and not self.ScrollGui then
					self.ScrollGui=Factory.create('ScrollingFrame',self.Gui,{Name='OverflowScroll',BackgroundTransparency=1,CanvasSize=UDim2.fromOffset(0,0),CanvasPosition=Vector2.new(0,0),ScrollBarThickness=10,ScrollingDirection=Enum.ScrollingDirection.XY,ElasticBehavior=Enum.ElasticBehavior.Never})
					self.ScrollContent=Factory.create('Frame',self.ScrollGui,{Name='ScrollContent',BackgroundTransparency=1})
					frame=self.ScrollContent
				end
				if self.ScrollGui then self.ScrollGui.Visible=self.RichSelect==true end
			end
		end
		if style.Overflow == "hidden" and style.OverflowX~="clip" and style.OverflowY~="clip" and not box.ScrollGui then
			-- Keep contents clipped independently of the outline from the first
			-- render, so a later focus ring needs no child transfer or layout.
			box.Gui.ClipsDescendants = false
			box.ClipContent = Factory.create("Frame", frame, {Name = "OutlineContentClip", ClipsDescendants = true})
			frame = box.ClipContent
			if box.Marker then box.Marker.Gui.Parent = frame end
		end
		local ownedInlineGroups={}
		local previousTextOwner = textOwner
		textOwner = box
		local words = InlineWords.new(diagnostic)
		local wordCount = 0
		local hasFlow = false
		local initialAvailable=not node.GeneratedPseudo and(style.Display=='block'or style.Display=='flow-root'or style.ListItem==true)
		local function createWord(item: any)
			local wordParent=wordPaintParent(if item.Style.OpacityGroup then item.Style.OpacityGroup.Content else frame)
			if wordParent~=frame then item.PendingPaintHost=wordParent end
			WorkContext.checkpoint()
			item.TextOwner = box
			local frame = if item.Style.OpacityGroup then item.Style.OpacityGroup.Content else frame
			if item.Style.OpacityGroup then table.insert(item.Style.OpacityGroup.Members, item) end
			wordCount += 1
			local face = if resolveFont then resolveFont(item.Style.Font, item.Style.FontWeight, item.Style.FontStyle) else nil
			local preloadTarget
			local shadowed = not item.EmptyInline and TextShadows.enabled(item.Style)
			if SpacingOwners.glyphs(item) then
				item.Gui = Factory.create("Frame", wordParent, {Name = "Word_" .. wordCount})
				item.Glyphs = LetterSpacing.split(item.Text)
				for index, glyph in item.Glyphs do
					glyph.Gui = Factory.create("TextLabel", item.Gui, {
						Name = "Character_" .. index, Text = glyph.Text, TextColor3 = item.Style.Color, TextTransparency = if item.Style.FontSize==0 or item.Style.Visibility == "hidden" then 1 else 1 - (item.Style.ColorAlpha or 1),
						LineHeight = 1, FontFace = face, OpenTypeFeatures = item.Style.OpenTypeFeatures,
						TextXAlignment = if item.Style.TabularNums and glyph.Text:match("^[0-9]$") then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
						ZIndex = if shadowed then TextShadows.Foreground else nil,
					})
					preloadTarget = preloadTarget or glyph.Gui
				end
			else
				if shadowed then item.Gui = Factory.create("Frame", wordParent, {Name = "Word_" .. wordCount}) end
				local label = Factory.create("TextLabel", if shadowed then item.Gui else wordParent, {
					Name = "Word_" .. wordCount, Text = item.Text, TextColor3 = item.Style.Color, TextTransparency = if item.Style.FontSize==0 or item.Style.Visibility == "hidden" then 1 else 1 - (item.Style.ColorAlpha or 1),
					LineHeight = 1, FontFace = face, OpenTypeFeatures = item.Style.OpenTypeFeatures,
					ZIndex = if shadowed then TextShadows.Foreground else nil,
				})
				if shadowed then item.TextGui = label else item.Gui = label end
				preloadTarget = label
			end
			hitNodes[item.Gui] = item.Style.HitNode or item.Style.Node or node
			hitStyles[item.Gui]=item.Style
			textItemsByGui[item.Gui]=item
			if item.TextGui then textItemsByGui[item.TextGui]=item end
			item.SelectionOrder=#textItems+1
			table.insert(textItems,item)
			if not item.EmptyInline then TextShadows.create(item, Factory.create)end
			if not item.EmptyInline and face and not seenFonts[face] then
				seenFonts[face] = true
				table.insert(fontTargets, preloadTarget)
			end
		end
		local function flush()
			local items = words:take()
			if not hasFlow and box.Marker and style.ListStylePosition == "inside" then
				table.insert(items, 1, {Kind = "Marker", Marker = box.Marker, Gui = box.Marker.Gui, Style = style})
			end
			if #items == 0 then return end
			local onlyFloats=true
			for _,item in items do if item.Kind~='Float'then onlyFloats=false;break end end
			if onlyFloats then
				for _,item in items do item.FloatBox.InlineFloat=nil end
				return
			end
			local bidi;items,bidi=BidiInline.prepare(items,rubyTextStyle or style)
			local decorated = false
			for index, item in items do
				if item.Kind == "Break" or item.Kind == "Marker" or item.Kind == "Float" then continue end
				if #(item.Style.Decorations or {}) > 0 or (item.SpaceStyle and #(item.SpaceStyle.Decorations or {}) > 0) then decorated = true end
				if item.Style.InlineBackground or (item.SpaceStyle and item.SpaceStyle.InlineBackground) then decorated = true end
				if item.Kind == "Image" then
                    if item.InlineBox then continue end
					local face = if resolveFont then resolveFont(item.Style.Font, item.Style.FontWeight, item.Style.FontStyle) else nil
					item.FontFace = face
					if item.Gui then
						item.Gui.Parent=item.PendingPaintHost or (if item.Style.OpacityGroup then item.Style.OpacityGroup.Content else frame)
					elseif item.Control then
						ControlView.create(item, if item.Style.OpacityGroup then item.Style.OpacityGroup.Content else frame, Factory, face, radioDot, resizeGrip,corners)
					elseif item.MediaKind then MediaBox.create(item,if item.Style.OpacityGroup then item.Style.OpacityGroup.Content else frame,Factory,corners)
					elseif item.IFrame then IFrameBox.create(item,if item.Style.OpacityGroup then item.Style.OpacityGroup.Content else frame,Factory,corners)
					else ImageBox.create(item, if item.Style.OpacityGroup then item.Style.OpacityGroup.Content else frame, Factory, face, "Image_" .. index, corners) end
					hitNodes[item.Gui] = if item.Control then item.Control.Node else item.Style.HitNode or item.Style.Node or node
					hitStyles[item.Gui]=item.Style
					if item.Style.OpacityGroup then table.insert(item.Style.OpacityGroup.Members, item) end
					if item.MediaKind then
						table.insert(mediaItems,item)
						if item.PosterSVGItem then table.insert(svgItems,item.PosterSVGItem) end
					elseif item.IFrame then table.insert(iframeItems,item) elseif item.Source then table.insert(imageItems, item) end
     if item.SVG then table.insert(svgItems,item) end
					local target = item.Editor or item.Label or item.FileCaption or (item.TemporalLabels and item.TemporalLabels[1].Label)
					if target and face and not seenFonts[face] then seenFonts[face] = true; table.insert(fontTargets,target) end
					if item.AltGui and face and not seenFonts[face] then
						seenFonts[face] = true; table.insert(fontTargets, item.AltGui)
					end
					continue
				end
				if item.Kind == "Space" then
					item.Gui = Factory.create("Frame", if item.Style.OpacityGroup then item.Style.OpacityGroup.Content else frame, {Name = "Whitespace_" .. index})
					item.TextOwner=box;item.SelectionOrder=#textItems+1
					table.insert(textItems,item);textItemsByGui[item.Gui]=item
					if item.Style.OpacityGroup then table.insert(item.Style.OpacityGroup.Members, item) end
					continue
				end
				createWord(item)
			end
			table.insert(box.Children, { Kind = "Words", Items = items, Style = rubyTextStyle or style, ScrollBox = box, ResolveFont = resolveFont, DecorationPatterns = patterns,
				CreateWord = createWord, Decorated = decorated, IndentFirstLine = not hasFlow,Factory=Factory,FragmentHost=frame,HitNodes=hitNodes,HitStyles=hitStyles })
			box.Children[#box.Children].Bidi=bidi
            local run=box.Children[#box.Children];run.Children={}
            table.insert(wordRuns,run)
            for _,item in items do if item.InlineBox then table.insert(run.Children,item.InlineBox) end end
			hasFlow = true
		end
		local function preserveFloat(childStyle: any): boolean
			return childStyle.Float~=nil and childStyle.Float~='none'
				and childStyle.Position~='absolute' and childStyle.Position~='fixed'
				and style.Display~='flex' and style.Display~='inline-flex' and style.Display~='grid' and style.Display~='inline-grid'
		end
		local function beforeFlowChild(childStyle: any)
			if childStyle.Position~='absolute' and childStyle.Position~='fixed' and not preserveFloat(childStyle)then flush()end
		end
		local function appendFlowChild(childBox: any, childStyle: any)
			childBox.InlineFloat=if preserveFloat(childStyle)then true else nil
			table.insert(box.Children,childBox)
			if childBox.InlineFloat then words:float(childBox)
			elseif childStyle.Position~='absolute' and childStyle.Position~='fixed'then hasFlow=true end
		end
		local quoteDepth = 0
  local function contentChildren()
   if box.SelectRenderBox then
    if not box.RichSelect then return {}end
    if box.RichSelectList then
     box.SelectFallback=false
     local children={};for _,child in node.Children do if not ControlDefaults.selectButton(child)then table.insert(children,child)end end
     return children
    end
    for _,child in node.Children do if child.Kind=='Element'then
     if ControlDefaults.selectButton(child)then box.SelectFallback=false;return {child}end
     break
    end end
    box.SelectFallback=true
    local option=box.Control.Options[box.Control.SelectedIndex]
    local caption=if option then option.Caption else ''
    box.SelectCaption=caption
    return {{Kind='Text',Text=caption,Children={},Parent=node}}
   end
   if ElementNames.htmlName(node)=='optgroup'and style.SelectBaseContents then
    local first;for _,child in node.Children do if child.Kind=='Element'then first=child;break end end
    if first and ElementNames.htmlName(first)=='legend'then return node.Children end
    local label={Kind='Element',Name='span',Attributes={},Children={},Parent=node,GeneratedSelectLabel=true}
    label.Children={{Kind='Text',Text=node.Attributes.label or '',Children={},Parent=label}}
    local children={label};for _,child in node.Children do table.insert(children,child)end;return children
   end
   if ElementNames.htmlName(node)=='option'and (style.SelectBaseContents or fragment and node==fragment.Node)then
    local label=node.Attributes.label;local elements=false
    for _,child in node.Children do if child.Kind=='Element'then elements=true;break end end
    if label and label~=''or not elements then
     local text=if label and label~=''then label else SelectTree.text(node,true)
     return {{Kind='Text',Text=text,Children={},Parent=node}}
    end
   end
   return ShadowTree.FlatChildren(node)
  end
  local function generated(host: any,name: string,inheritedStyle: any)
			if host==node and box.SelectRenderBox and not box.RichSelect then return end
			local pseudo=resolvePseudo(host,inheritedStyle,name)
   if not pseudo or pseudo.Hidden or #(pseudo.GeneratedContent or{})==0 then return end
			counterState.Registry=pseudo.CounterStyles;Counters.enter(counterState,pseudo)
			local chunks={}
			for _,part in pseudo.GeneratedContent or {} do
				if part.Kind=="text" then table.insert(chunks,part.Value)
				elseif part.Kind=="attr" then table.insert(chunks,host.Attributes[part.Name] or "")
				elseif part.Kind=="counter" or part.Kind=="counters" then table.insert(chunks,Counters.render(counterState,part))
				elseif part.Kind=="quote" then
					local closing=part.Value=="close-quote" or part.Value=="no-close-quote"
					if closing then quoteDepth=math.max(0,quoteDepth-1) end
					if part.Value=="open-quote" or part.Value=="close-quote" then
						local pairs=pseudo.Quotes or {{"“","”"}};local pair=pairs[math.min(#pairs,quoteDepth+1)]
						if pair then table.insert(chunks,pair[if closing then 2 else 1]) end
					end
					if part.Value=="open-quote" or part.Value=="no-open-quote" then quoteDepth+=1 end
				end
			end
   local text=table.concat(chunks)
   if generatedReady then local cached=generatedRecords[host]and generatedRecords[host][name];if cached then pseudo=cached.Style;text=cached.Text end end
   generatedRecords[host]=generatedRecords[host]or{};generatedRecords[host][name]={Style=pseudo,Text=text}
   if pseudo.Display~='inline'or preserveFloat(pseudo)then
    local virtual={Kind='Element',Name='span',Attributes={},Children={},Parent=host,GeneratedHost=host,GeneratedPseudo=name}
    local textNode={Kind='Text',Text=text,Children={},Parent=virtual};virtual.Children={textNode}
    local paintStyle=table.clone(pseudo);paintStyle.CounterReset={};paintStyle.CounterIncrement={};paintStyle.CounterSet={};paintStyle.HitNode=host
    local atomic=pseudo.Display=='inline-block'or pseudo.Display=='inline-flex'or pseudo.Display=='inline-grid'
    if not atomic then beforeFlowChild(pseudo)end
    local built=build(virtual,frame,inheritedStyle,paintStyle)
    if built then
     hitNodes[built.Gui]=host
     if atomic and not preserveFloat(pseudo)then words:image({Kind='Image',InlineBox=built,Gui=built.Gui,Style=built.Style,ParentStyle=inheritedStyle})else appendFlowChild(built,built.Style)end
    end
   elseif text~="" then words:text(text,pseudo)end
			Counters.leave(counterState)
		end
		local function hiddenSplitsInlineFlow(child: any): boolean
			if #words.Items==0 and #words.Parts==0 and #(words.Pending or {})==0 then return false end
			local after=false
			for _,sibling in (node.InternalShadowRoot or node).Children do
				if sibling==child then after=true;continue end
				if not after then continue end
				if sibling.Kind=="Text" then
					local collapse=WhiteSpace.collapse(style)
					if sibling.Text:find('[^ \t\r\n]') or collapse=='preserve-breaks'and sibling.Text:find('[\r\n]')
						or collapse~='collapse'and collapse~='discard'and collapse~='preserve-breaks'and sibling.Text~='' then return true end
				elseif sibling.Kind=="Element" then
					local entry=ElementProfile.entry(sibling)
					if entry and entry.Render=="hidden" then continue end
					local candidate=Style.resolve(sibling,style,function()end,false,matched(sibling))
					if candidate.Hidden or candidate.Position=="absolute" or candidate.Position=="fixed" or candidate.Float~="none" then continue end
					return candidate.Display=="inline" or candidate.Display=="inline-block" or candidate.Display=="inline-flex" or candidate.Display=="inline-grid" or candidate.Display=="contents"
				end
			end
			return false
		end
		local function visit(child: any, textStyle: any)
			WorkContext.checkpoint()
			if child.Kind == "Text" then
				local source=child.SourceNode or child;local sourceOffset=child.SourceOffset or 0
				local first,last,offset
				-- Luau conditional expressions retain one return, so read the prefix
				-- explicitly before slicing source-bound fragments.
				if initialAvailable then first,last,offset=InitialLetter.prefix(child.Text)end
				local pseudo=if first then resolvePseudo(node,style,'first-letter')else nil
				if first then initialAvailable=false end
				if pseudo and textStyle.WritingMode=='horizontal-tb'then
					generatedRecords[node]=generatedRecords[node]or{};generatedRecords[node]['first-letter']={Style=pseudo,Text=''}
					local paintStyle=table.clone(pseudo);paintStyle.HitNode=textStyle.HitNode or node
					if type(paintStyle.InitialLetter)=='table'then
						local metrics=FontMetrics.resolve(textStyle);local line=FontMetrics.extents(textStyle,metrics);local height=line.Ascent+line.Descent
						local cap=math.max(1,metrics.Baseline-metrics.Top);local current=FontMetrics.resolve(paintStyle)
						paintStyle.FontSize*=(cap+(paintStyle.InitialLetter.Size-1)*height)/math.max(1,current.Baseline-current.Top)
						paintStyle.Float=if textStyle.Direction=='rtl'then 'right'else 'left'
						paintStyle.LineHeight={Kind='px',Value=paintStyle.InitialLetter.Sink*height}
					end
					if paintStyle.Float~='none'then
						paintStyle.Display='block'
						local virtual={Kind='Element',Name='span',Attributes={},Children={},Parent=node,GeneratedHost=node,GeneratedPseudo='first-letter'}
						local leading=child.Text:sub(1,first-1);local leadingOffset=0;for _,code in utf8.codes(leading)do leadingOffset+=if code>=0x10000 then 2 else 1 end
						virtual.Children={{Kind='Text',Text=child.Text:sub(first,last),Children={},Parent=virtual,SourceNode=source,SourceOffset=sourceOffset+leadingOffset}}
						local capBox=build(virtual,frame,textStyle,paintStyle);if capBox then
							capBox.InitialLetter=true;appendFlowChild(capBox,paintStyle)
							for _,run in capBox.Children do for _,item in run.Items or{}do item.TextOwner=box end end
						end
					else words:text(child.Text:sub(1,last),paintStyle,source,sourceOffset)end
					words:text(child.Text:sub(last+1),textStyle,source,sourceOffset+offset)
				else words:text(child.Text,textStyle,source,sourceOffset)end
			elseif child.Kind == "Element" then
				-- Scripting is a document capability, independent of script presence
				-- or successful execution. The no-script fallback has no render box.
				if ElementNames.htmlName(child)=='noscript'and document.ScriptingEnabled==true then return end
				if reconciling and retainedControls[child] and not retainedControls[child].Item.RichButton and not(nodeBoxes[child]and nodeBoxes[child].SelectRenderBox)and not richSelect(child,nodeStyles[child])then
					local c=retainedControls[child];local item=c.Item
					local s=retainStyle(child,textStyle);item.ParentStyle=textStyle
					item.Style=s;c.LayoutStyle=s;item.ControlMeasureKey=nil
					local participation=controlReconcileStyles[child]or s
					if participation.Hidden then
						item.Gui.Parent=frame;item.Gui.Visible=false;item.Box=nil
						return
					end
					item.Gui.Visible=true
					local block=participation.Display=="block" or participation.Display=="flex" or participation.Display=="grid" or participation.Display=="inline-grid"
						or style.Display=="flex" or style.Display=="inline-flex" or style.Display=="grid" or style.Display=="inline-grid"
					local existing=nodeBoxes[child]
					if block or preserveFloat(s)then
						beforeFlowChild(s)
						if existing then build(child,frame,textStyle);appendFlowChild(existing,s)
						else
							local host=Factory.create("Frame",frame,{Name=child.Attributes.id or "BlockControl"})
							item.Gui.Parent=host
							hitNodes[host],hitStyles[host]=child,s
							appendFlowChild(replacedBox(child,host,item,s),s)
						end
					else
						if existing then
							item.Gui.Parent=frame
							hitNodes[existing.Gui]=nil;hitStyles[existing.Gui]=nil
							existing.Gui:Destroy();nodeBoxes[child]=nil
						end
						words:image(item)
					end
					return
				end
				if reconciling and retainedReplaced[child] then
					local item=retainedReplaced[child]
					if item.MediaKind=="audio"then item.Controls=child.Attributes.controls~=nil end
					local s=retainStyle(child,textStyle);item.ParentStyle=textStyle;item.Style=s
					-- Audio without controls has no CSS box. The page's audio owner
					-- keeps playback alive while reconciliation releases the old GUI.
					if item.MediaKind=="audio" and not item.Controls then return end
					local block=s.Display=="block" or s.Display=="flex" or s.Display=="grid" or s.Display=="inline-grid"
						or style.Display=="flex" or style.Display=="inline-flex" or style.Display=="grid" or style.Display=="inline-grid"
					local existing=nodeBoxes[child]
					if block or preserveFloat(s)then
						beforeFlowChild(s)
						if existing then build(child,frame,textStyle);appendFlowChild(existing,s)
						else
							local host=Factory.create("Frame",frame,{Name=child.Attributes.id or "BlockReplaced"})
							item.Gui.Parent=host
							appendFlowChild(replacedBox(child,host,item,s),s)
						end
					else
						if existing then
							item.Gui.Parent=frame;hitNodes[existing.Gui]=nil;hitStyles[existing.Gui]=nil
							existing.Gui:Destroy();nodeBoxes[child]=nil
						end
						words:image(item)
					end
					return
				end
				if reconciling and nodeBoxes[child] then
					local existing=build(child,frame,textStyle)
					local s=existing.Style
					if (s.Display=="inline-block" or s.Display=="inline-flex" or s.Display=="inline-grid" or existing.SelectRenderBox and s.Display=='inline') and s.Position~="absolute" and s.Position~="fixed" and style.Display~="flex" and style.Display~="grid" and style.Display~="inline-flex" and style.Display~="inline-grid" and not preserveFloat(s)then
						words:image({Kind="Image",InlineBox=existing,Gui=existing.Gui,Style=s,ParentStyle=textStyle})
					else
						beforeFlowChild(s)
						appendFlowChild(existing,s)
					end
					return
				end
				local element = ElementProfile.entry(child)
				local render = if element then element.Render else "block"
				if box.RichSelect and child.Parent==node then
					if box.RichSelectList then
						if ControlDefaults.selectButton(child)then return end
					elseif ControlDefaults.selectButton(child)then render='inline'else return end
				end
				if style.SelectBaseContents and (ElementNames.htmlName(child)=='option'or ElementNames.htmlName(child)=='optgroup')then render='block'end
				if render~="image" and render~="svg" and render~="canvas" and render~="media" and render~="iframe" and render~="embedded" and render~="control" then
					local contentsStyle=Style.resolve(child,textStyle,function() end,true,matched(child))
					if contentsStyle.Display=="contents" then
						contentsStyle=resolve(child,textStyle,true)
						Counters.enter(counterState,contentsStyle)
						generated(child,"before",contentsStyle)
      for _,nested in ShadowTree.FlatChildren(child) do visit(nested,contentsStyle) end
						generated(child,"after",contentsStyle)
						Counters.leave(counterState)
						return
					end
				end
				if render == "column" then return end
				if render == "hidden" then return end
				if render == "contents" then
					for _, nested in child.Children do
						if nested.Kind == "Element" and ElementNames.htmlName(nested) == "img" then visit(nested, textStyle) end
					end
					return
				end
				if render == "slot" then
					local slotStyle = resolve(child, textStyle, true)
					if slotStyle.Hidden then return end
					local assigned = slotAssignments[child]
					local children = if assigned and #assigned > 0 then assigned else child.Children
					for _, nested in children do visit(nested, slotStyle) end
					return
				end
				local fragmentedInline=false
				if render~='svg' and render~='image' and render~='canvas' and render~='media' and render~='iframe' and render~='embedded' and render~='control' and style.Display~='flex' and style.Display~='inline-flex' and style.Display~='grid' and style.Display~='inline-grid' then
					local candidate=Style.resolve(child,textStyle,function() end,false,matched(child))
					local positionedInline=candidate.Display=='inline' and candidate.Position=='relative'
					local decoratedInline=candidate.Display=='inline' and candidate.Position=='static'
					local staticInline=decoratedInline
					local horizontalMargins=false
					if decoratedInline then
						decoratedInline=false
						for _,size in candidate.BorderSizes or {} do if size>0 then decoratedInline=true;break end end
						for side=1,4 do
							local padding=candidate.PaddingValues and candidate.PaddingValues[side] or candidate.Padding[side]
							if padding and (type(padding)=='table' or padding>0) then decoratedInline=true;break end
						end
						for _,side in {2,4}do
							local margin=candidate.MarginValues and candidate.MarginValues[side] or candidate.Margin[side]
							if margin and (type(margin)=='table' or margin~=0)then decoratedInline=true;horizontalMargins=true;break end
						end
					end
					fragmentedInline=staticInline and candidate.BoxDecorationSupported~=false and not horizontalMargins
						and(candidate.BoxDecorationSpecified or decoratedInline or candidate.Background~=nil)
					if (candidate.Display=='inline-grid' or candidate.Display=='inline-block' or candidate.Display=='inline-flex' or decoratedInline and not fragmentedInline or positionedInline) and candidate.Position~='absolute' and candidate.Position~='fixed' and not preserveFloat(candidate)then
						local inlineStyle=resolve(child,textStyle,false)
						if decoratedInline or positionedInline then
							-- An inline box with edges needs its own painted and measured GUI.
							-- The atomic representation keeps those edges with the content.
							inlineStyle.Display='inline-block'
							inlineStyle.AtomicInline = true
							inlineStyle.InlineBackground=nil
						end
						local built=build(child,frame,textStyle,inlineStyle)
						if built then words:image({Kind='Image',InlineBox=built,Gui=built.Gui,Style=candidate,ParentStyle=textStyle}) end
                        return
                    end
                end
				local selectStyle=if render=='control'and ElementNames.htmlName(child)=='select'then resolve(child,textStyle,false)else nil
				if render == "soft-break" then
					if not resolve(child, textStyle).Hidden then words:softBreak() end
				elseif render == "break" then
					local breakStyle=resolve(child,textStyle)
					if not breakStyle.Hidden then words:lineBreak(breakStyle) end
				elseif render == "control" and(richButton(child)or richSelect(child,selectStyle))then
					local s=selectStyle or resolve(child,textStyle,false)
					local built=build(child,frame,textStyle,s)
					if built then
						local inFlow=s.Position~="absolute" and s.Position~="fixed"
						if inFlow and (s.Display=="inline-block" or s.Display=="inline-flex" or s.Display=="inline-grid") and style.Display~="flex" and style.Display~="inline-flex" and style.Display~="grid" and style.Display~="inline-grid" and not preserveFloat(s)then
							words:image({Kind="Image",InlineBox=built,Gui=built.Gui,Style=s,ParentStyle=textStyle})
						else
							beforeFlowChild(s)
							appendFlowChild(built,s)
						end
					end
				elseif render == "control" then
					if ControlDefaults.kind(child) == "hidden" then return end
					local controlStyle = selectStyle or resolve(child, textStyle, false)
					if controlStyle.Hidden then return end
					local c = unrenderedState(child)
					pendingControlStates[child]=nil
					c.PlaceholderStyle = resolvePseudo(child, controlStyle, "placeholder")
					if c.Type=="select" then c.PickerStyle=resolvePseudo(child,controlStyle,"picker(select)") end
					c.LayoutStyle=controlStyle
					table.insert(controls,c)
					local item = {Kind="Image",Control=c,Style=controlStyle,ParentStyle=textStyle}
					if c.Type=='select'then item.FontResolver=resolveFont;item.ResolvePickerStyle=function()return resolvePseudo(child,c.Item.Style,'picker(select)')end end
					if c.Type=="image" then
						item.Node=child;item.SelectedSource=child.Attributes.src or ""
						item.Source=resolveImage and resolveImage(item.SelectedSource)
						item.SVG=not item.Source and resolveSVG and resolveSVG(item.SelectedSource) or nil
						item.SVGExternal=item.SVG~=nil;item.Alt=child.Attributes.alt or "Submit";item.EmptyAlt=false
						item.AttributeWidth,item.AttributeHeight=imageDimension(child.Attributes.width),imageDimension(child.Attributes.height)
						item.IntrinsicWidth,item.IntrinsicHeight=item.AttributeWidth,item.AttributeHeight
						if item.SVG then local w,h=require(script.Parent.Parent.SVG.Sizing).source(item.SVG);item.IntrinsicWidth,item.IntrinsicHeight=w,h end
					end
					if c.Type == "select" and #c.SelectRows > #c.Options and resolveFont then
						item.GroupFontFace=resolveFont(controlStyle.Font,700,controlStyle.FontStyle)
					end
					if controlStyle.Display == "block" or (controlStyle.Display == "flex" or controlStyle.Display == "grid" or controlStyle.Display == "inline-grid") or (style.Display == "flex" or style.Display == "inline-flex" or style.Display == "grid" or style.Display == "inline-grid") or preserveFloat(controlStyle)then
						beforeFlowChild(controlStyle)
						local host = Factory.create("Frame",frame,{Name=child.Attributes.id or "BlockControl"})
						local face = if resolveFont then resolveFont(controlStyle.Font,controlStyle.FontWeight,controlStyle.FontStyle) else nil
						item.FontFace=face
						ControlView.create(item,host,Factory,face,radioDot,resizeGrip,corners)
						if c.Type=="image" then item.Block=true;if item.Source then table.insert(imageItems,item) end;if item.SVG then table.insert(svgItems,item) end end
						hitNodes[host],hitNodes[item.Gui]=child,child
						hitStyles[host],hitStyles[item.Gui]=controlStyle,controlStyle
						local target=item.Editor or item.Label or item.FileCaption or (item.TemporalLabels and item.TemporalLabels[1].Label)
						if target and face and not seenFonts[face] then seenFonts[face]=true; table.insert(fontTargets,target) end
						appendFlowChild(replacedBox(child,host,item,controlStyle),controlStyle)
					else words:image(item) end
				elseif render == "iframe" or render == "embedded" then
					local embeddedKind = child.Name
					local reference = if embeddedKind == "object" then child.Attributes.data else child.Attributes.src
					local localSVG = reference and resolveSVG and resolveSVG(reference)
					local supportedType = render == "iframe" or embeddedDocumentType(child.Attributes.type) or localSVG ~= nil
					if embeddedKind == "object" and ((reference or "") == "" or not supportedType) then
						-- Browser object elements expose their descendants only when the
						-- selected resource cannot be represented.  Build that subtree as
						-- ordinary flow content instead of allocating an embedded session.
						local fallbackStyle = resolve(child, textStyle)
						if fallbackStyle.Hidden then return end
						if fallbackStyle.Display == "inline" and fallbackStyle.Position ~= "absolute" and not preserveFloat(fallbackStyle)
							and style.Display ~= "flex" and style.Display ~= "inline-flex" and style.Display ~= "grid" and style.Display ~= "inline-grid" then
							for _, nested in child.Children do visit(nested, fallbackStyle) end
							return
						end
						beforeFlowChild(fallbackStyle)
						local built = build(child, frame, textStyle, fallbackStyle)
						if built then
							appendFlowChild(built,fallbackStyle)
						end
						return
					end
					local iframeStyle=resolve(child,textStyle,(style.Display~="flex" and style.Display~="inline-flex" and style.Display~="grid" and style.Display~="inline-grid"))
					if iframeStyle.Hidden then return end
					local w,h=imageDimension(child.Attributes.width) or 300,imageDimension(child.Attributes.height) or 150
					local item={Kind="Image",IFrame=true,EmbeddedKind=embeddedKind,Style=iframeStyle,SelectedSource=reference or "about:blank",
						UnsupportedType=if supportedType then nil else child.Attributes.type or "unsupported",
						AttributeWidth=w,AttributeHeight=h,IntrinsicWidth=w,IntrinsicHeight=h,ParentStyle=textStyle,Node=child}
					if iframeStyle.Display=="block" or iframeStyle.Display=="flex" or iframeStyle.Display=="grid" or iframeStyle.Display=="inline-grid" or style.Display=="flex" or style.Display=="grid" or style.Display=="inline-grid" or preserveFloat(iframeStyle)then
						beforeFlowChild(iframeStyle)
						local host=Factory.create("Frame",frame,{Name=child.Attributes.id or "BlockEmbedded"})
						IFrameBox.create(item,host,Factory,corners)
						hitNodes[host],hitNodes[item.Gui]=child,child
						hitStyles[host],hitStyles[item.Gui]=iframeStyle,iframeStyle
						table.insert(iframeItems,item)
						appendFlowChild(replacedBox(child,host,item,iframeStyle),iframeStyle)
					else words:image(item) end
				elseif render == "media" then
					local mediaStyle=resolve(child,textStyle,(style.Display~="flex" and style.Display~="inline-flex" and style.Display~="grid" and style.Display~="inline-grid"))
					if mediaStyle.Hidden then return end
					local resolver=mediaResolver or MediaSources.new()
					local mediaKind=ElementNames.htmlName(child)
					local selectedSource,source=MediaSources.select(child,mediaKind,resolver)
					if selectedSource=="" then diagnostic(child.Name.." has no media source")
					elseif not source then diagnostic("No "..child.Name.." mapping for src: "..selectedSource) end
					local posterSource=if ElementNames.htmlName(child)=="video" then child.Attributes.poster else nil
					-- Preserve the renderer's prepared resource metadata. Presentation
					-- and natural dimensions wait for the independent page load lease.
					local poster=posterSource and resolveImage and resolveImage(posterSource)or nil
					local posterSVG=if posterSource and not poster and resolveSVG then resolveSVG(posterSource)else nil
					local w=if mediaKind=='audio'then imageDimension(child.Attributes.width)or 300 else nil
					local h=if mediaKind=='audio'then imageDimension(child.Attributes.height)or 54 else nil
					local item={Kind="Image",MediaKind=mediaKind,Style=mediaStyle,Source=source,SelectedSource=selectedSource,
						Poster=poster,PosterSVG=posterSVG,PosterReady=false,PosterSource=posterSource,ShowPoster=true,VideoWidth=0,VideoHeight=0,Tracks=MediaSources.tracks(child,resolver),
						AttributeWidth=w,AttributeHeight=h,IntrinsicWidth=w,IntrinsicHeight=h,ParentStyle=textStyle,Node=child,
						Controls=child.Attributes.controls~=nil}
					if mediaStyle.Display=="block" or mediaStyle.Display=="flex" or mediaStyle.Display=="grid" or mediaStyle.Display=="inline-grid" or style.Display=="flex" or style.Display=="grid" or style.Display=="inline-grid" or preserveFloat(mediaStyle)then
						beforeFlowChild(mediaStyle)
						local host=Factory.create("Frame",frame,{Name=child.Attributes.id or "BlockMedia"})
						MediaBox.create(item,host,Factory,corners)
						if item.PosterSVGItem then table.insert(svgItems,item.PosterSVGItem) end
						hitNodes[host],hitNodes[item.Gui]=child,child
						hitStyles[host],hitStyles[item.Gui]=mediaStyle,mediaStyle
						table.insert(mediaItems,item)
						appendFlowChild(replacedBox(child,host,item,mediaStyle),mediaStyle)
					else words:image(item) end
				elseif render == "image" or render == "svg" or render == "canvas" then
					local imageStyle = resolve(child, textStyle, (style.Display ~= "flex" and style.Display ~= "inline-flex" and style.Display ~= "grid" and style.Display ~= "inline-grid"))
					if imageStyle.Hidden then return end
					local isSVG = render == "svg"
					local isCanvas = render == "canvas"
					local selectedSource,sourceDensity,dimensionSource="",nil,child
					if not isSVG and not isCanvas then selectedSource,sourceDensity,dimensionSource=selectedImage(child)end
					local source = if not isSVG and not isCanvas and resolveImage then resolveImage(selectedSource) else nil
					local sourceSVG=if not isSVG and not isCanvas and not source and resolveSVG then resolveSVG(selectedSource) else nil
					if not isSVG and not isCanvas and not source and not sourceSVG then diagnostic("No image mapping for src: " .. selectedSource) end
					local w, h = imageDimension(dimensionSource.Attributes.width), imageDimension(dimensionSource.Attributes.height)
					if isCanvas then
						w=tonumber((child.Attributes.width or ""):match("^%s*%+?(%d+)"))or 300
						h=tonumber((child.Attributes.height or ""):match("^%s*%+?(%d+)"))or 150
					end
					local item = {Kind = "Image", SVG = if isSVG then child else sourceSVG, Canvas = if isCanvas then child else nil, Style = imageStyle, Source = source, Alt = if isSVG or isCanvas then "" else child.Attributes.alt or "",
						AttributeWidth = w, AttributeHeight = h, IntrinsicWidth = w, IntrinsicHeight = h, ParentStyle = textStyle, EmptyAlt = isSVG or isCanvas or child.Attributes.alt == "",
						TextFallback = not isSVG and not isCanvas and source == nil and sourceSVG == nil and (child.Attributes.alt or "") ~= "", SelectedSource = selectedSource, SourceDensity=sourceDensity, Node = child, FontResolver=resolveFont}
					if isSVG then
						item.SVGDeclarations=function(source,states)
							local effective=table.clone(cssStates);for key,value in states or{}do effective[key]=if type(value)=='table'then value.SourceElement or value else value end
							return Stylesheet.rawMatch(shadowRuleSets[child]or rules,source,effective,containerFor(child))
						end
					end
					if sourceSVG then
						item.SVGExternal=true
						local width,height=require(script.Parent.Parent.SVG.Sizing).source(sourceSVG)
						item.PixelWidth,item.PixelHeight=width,height
						item.IntrinsicWidth,item.IntrinsicHeight=ResponsiveSources.intrinsicSize(width,height,sourceDensity)
					end
					if not isSVG and not isCanvas then imageMapIndex:Bind(child,item)end
					if imageStyle.Display == "block" or (imageStyle.Display == "flex" or imageStyle.Display == "grid" or imageStyle.Display == "inline-grid") or (style.Display == "flex" or style.Display == "inline-flex" or style.Display == "grid" or style.Display == "inline-grid") or preserveFloat(imageStyle)then
						beforeFlowChild(imageStyle)
						local host = Factory.create("Frame", frame, {Name = child.Attributes.id or "BlockImage"})
						local face = if resolveFont then resolveFont(imageStyle.Font, imageStyle.FontWeight, imageStyle.FontStyle) else nil
						item.FontFace = face
						item.Block = true
						ImageBox.create(item, host, Factory, face, "Image", corners)
						hitNodes[host],hitNodes[item.Gui]=child,child
						hitStyles[host],hitStyles[item.Gui]=imageStyle,imageStyle
						if source then table.insert(imageItems, item) end
						if isCanvas then table.insert(canvasItems,item) end
      if item.SVG then table.insert(svgItems,item) end
						if item.AltGui and face and not seenFonts[face] then seenFonts[face] = true; table.insert(fontTargets, item.AltGui) end
						appendFlowChild(replacedBox(child,host,item,imageStyle),imageStyle)
					else words:image(item);if isCanvas then table.insert(canvasItems,item) end end
				elseif render == "inline" then
					if (style.Display == "flex" or style.Display == "inline-flex" or style.Display == "grid" or style.Display == "inline-grid") then
						local childStyle = resolve(child, textStyle)
						if childStyle.Hidden then return end
						-- Direct inline children of flex/grid containers are blockified flex/grid
						-- items. Their own background belongs to the item border box; retaining
						-- InlineBackground would paint a duplicate rectangle behind every word.
						childStyle.InlineBackground=nil;childStyle.InlineBackgroundAlpha=1
						if childStyle.Position ~= "absolute" then flush() end
						local built = build(child, frame, textStyle, childStyle)
						if built then table.insert(box.Children, built); if childStyle.Position ~= "absolute" and childStyle.Position~="fixed" then hasFlow = true end end
						return
					end
					local inlineStyle = resolve(child, textStyle, not fragmentedInline)
					if fragmentedInline then inlineStyle.InlineFragment={Style=inlineStyle};inlineStyle.InlineBackground=nil end
					if inlineStyle.Hidden then return end
					if inlineStyle.Position == "absolute" or inlineStyle.Position == "fixed" or inlineStyle.Display == "block" or (inlineStyle.Display == "flex" or inlineStyle.Display == "grid") or inlineStyle.TableRole or preserveFloat(inlineStyle)then
						beforeFlowChild(inlineStyle)
						local built = build(child, frame, textStyle, inlineStyle)
						if built then appendFlowChild(built,inlineStyle)end
						return
					end
					if (inlineStyle.Opacity or 1) < 1 then
						local parentGroup = textStyle.OpacityGroup
						local group = GroupOpacity.create(if parentGroup then parentGroup.Content else frame, inlineStyle.Opacity, Factory)
						box.InlineOpacityGroups = box.InlineOpacityGroups or {}
						table.insert(if parentGroup then parentGroup.Children else box.InlineOpacityGroups, group)
						inlineStyle.OpacityGroup = group
						group.ScriptParentGroup=parentGroup;table.insert(ownedInlineGroups,group)
					end
					Counters.enter(counterState,inlineStyle)
					if element.WarnInline then diagnostic("Tag-specific inline formatting not yet supported: " .. child.Name) end
					if ElementNames.htmlName(child) == "q" then
						local pairs=inlineStyle.Quotes or {};local pair=pairs[math.min(#pairs,quoteDepth+1)]
						generated(child,"before",inlineStyle);if pair then words:text(pair[1],inlineStyle) end
						quoteDepth += 1
						for _, nested in ShadowTree.FlatChildren(child) do visit(nested, inlineStyle) end
						quoteDepth -= 1
						if pair then words:text(pair[2],inlineStyle) end;generated(child,"after",inlineStyle)
					else
						generated(child,"before",inlineStyle)
						for _, nested in ShadowTree.FlatChildren(child) do visit(nested, inlineStyle) end
						if emptyInlineText(child,inlineStyle)then words:empty(inlineStyle)end
						generated(child,"after",inlineStyle)
					end
					Counters.leave(counterState)
				elseif render == "unsupported" then
					diagnostic("Element not rendered yet: " .. child.Name)
				else
					local childStyle = resolve(child, textStyle)
					-- Retain hidden blocks at flow boundaries so scripts can reveal them.
					-- A hidden block inside one uninterrupted inline run still needs
					-- structural regrouping and must not split the initial text line.
					if childStyle.Hidden and hiddenSplitsInlineFlow(child) then return end
					if ElementNames.htmlName(node) == "fieldset" and child.Parent == node and ElementNames.htmlName(child) == "legend" and childStyle.Display == "inline" then childStyle.Display = "block" end
					if childStyle.Display == "inline" and childStyle.Position ~= "absolute" and childStyle.Position~="fixed" and (style.Display ~= "flex" and style.Display~="inline-flex" and style.Display ~= "grid" and style.Display ~= "inline-grid") and not preserveFloat(childStyle)then
						Counters.enter(counterState,childStyle)
						generated(child,"before",childStyle)
						for _, nested in ShadowTree.FlatChildren(child) do visit(nested, childStyle) end
						generated(child,"after",childStyle)
						Counters.leave(counterState)
						return
					end
					beforeFlowChild(childStyle)
					local built = build(child, frame, textStyle, childStyle)
					if built then appendFlowChild(built,childStyle)end
				end
			end
		end
		-- Keep boxes and unrelated controls alive when rebuilding an inline flow.
		local populateContents
		local function skippedContents(): boolean
			-- Content visibility requires size containment. Internal table boxes
			-- and the table's inner display type do not support that containment.
			return style.ContentVisibility=="hidden"and(not style.TableRole or style.TableRole=="caption")
		end
		-- Allocate a passive gate only for an element whose contents are skipped.
		-- Its own background, border and canvas surface stay on the original box.
		function box:SyncContentVisibility()
			local skipped=skippedContents()
			if skipped and not self.ContentHost then
				local parent=frame
				local host=Factory.create("Frame",parent,{Name="SkippedContent",BackgroundTransparency=1,
					Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),Visible=false,ClipsDescendants=false})
				if host.SetAttribute then host:SetAttribute("HTMLHitTestPassthrough",true)end
				local function move(gui)
					local surface=gui
					while surface and surface~=host and surface.Parent and surface.Parent~=parent do surface=surface.Parent end
					if surface and surface~=host and surface~=parent and surface.Parent==parent then surface.Parent=host end
				end
				local function moveBox(child)
					local surface=if child.OpacityGroup then child.OpacityGroup.Gui else child.Gui
					if child.ViewportHome==parent then child.ViewportHome=host end
					if child.TopLayerParent==parent then child.TopLayerParent=host end
					local state=dialogsByNode[child.Node]or popoversByNode[child.Node]
					if state and state.NaturalParent==parent then state.NaturalParent=host end
					move(surface)
				end
				for _,child in self.AllChildren or self.Children do
					if child.Kind=="Words"then
						for _,item in child.Items do if item.InlineBox then moveBox(item.InlineBox)else move(item.Gui)end end
						for _,item in child.DisplayItems or{}do move(item.Gui)end
						for _,item in child.EllipsisPool or{}do move(item.Gui)end
						for _,slot in child.FragmentPool or{}do move(slot.Gui)end
						child.FragmentHost=host
					else moveBox(child)end
				end
				for _,group in ownedInlineGroups do move(group.Gui)end
				if self.Marker then move(self.Marker.Gui)end
				self.ContentHost=host;frame=host
			end
			self.HiddenContents=skipped
			if skipped then
				pendingContentReveals[self]=nil;self.ContentRevealPending=nil
				self.AllChildren=self.AllChildren or self.Children
				self.SkippedChildren=self.SkippedChildren or{}
				self.Children=self.SkippedChildren
				self.ContentHost.Visible=false
			else
				local deferred=self.ContentsBuilt==false
				self.Children=self.AllChildren or self.Children
				if deferred then
					populateContents()
					if style.TableRole=="table"then
						if self.RefreshTable then self:RefreshTable()else prepareTable(self)end
						self.AllChildren=self.Children
					end
					if tree then tree.DeferredContentRevision=(tree.DeferredContentRevision or 0)+1 end
				end
				if style.TableRole=="table"and not self.RefreshTable then
					prepareTable(self);if self.AllChildren then self.AllChildren=self.Children end
				end
				if disclosure then Disclosure.apply(disclosure)end
				if self.ContentHost then
					-- A newly built subtree stays blank until its first geometry commit.
					self.ContentRevealPending=deferred or self.ContentRevealPending
					if self.ContentRevealPending then pendingContentReveals[self]=true end
					self.ContentHost.Visible=not self.ContentRevealPending
				end
			end
		end
		function box:CanRefreshText(): boolean
   if disclosure then return false end
			for _,run in self.AllChildren or self.Children do
				if run.InitialLetter then continue end
				if run.Kind~="Words" then return false end
				for _,item in run.Items do if item.Kind=="Image" or item.InlineBox then return false end end
			end
			return true
		end
		function box:RefreshBidi(axes: boolean?): boolean
			local pending={}
			for _,run in self.AllChildren or self.Children do
				if run.Kind~='Words'or run.InitialLetter then return false end
				local items,bidi=BidiInline.refresh(run.Items,run.Style,axes)
				if not items then return false end
				table.insert(pending,{Run=run,Items=items,Bidi=bidi})
			end
			for _,entry in pending do
				for index,item in entry.Items do
					local target=entry.Run.Items[index];BidiInline.copy(item,target)
					if axes then target.VerticalOrientation,target.VerticalAlternate=item.VerticalOrientation,item.VerticalAlternate end
				end
				entry.Run.Bidi=entry.Bidi
			end
			return true
		end
		function box:RefreshText(allowLocalLayout: boolean?,structure: boolean?)
			assert(structure or self:CanRefreshText(),"Text update requires structural DOM reconciliation")
			if self.ContentsBuilt==false then
				-- A hidden, unbuilt subtree consumes the current DOM on first reveal.
				return
			end
			self.Children=self.AllChildren or self.Children
			table.clear(counterLookahead)
			self.PendingTextLayout = if allowLocalLayout then TextMutation.capture(self) else nil
			local oldRuns={}
			for _,run in self.Children do oldRuns[run]=true;if run.InitialLetter then for _,childRun in run.Children do oldRuns[childRun]=true end end end
			for i=#wordRuns,1,-1 do if oldRuns[wordRuns[i]] then table.remove(wordRuns,i) end end
			local removed,removedGuis={},{}
			for i=#textItems,1,-1 do
				local item=textItems[i]
				if item.TextOwner~=self then continue end
				removed[item]=true;GroupOpacity.untrack(item)
				for _,gui in {item.Gui,item.TextGui} do if gui then removedGuis[gui]=true;hitNodes[gui]=nil;hitStyles[gui]=nil;textItemsByGui[gui]=nil end end
				for _,glyph in item.Glyphs or {} do if glyph.Gui then removedGuis[glyph.Gui]=true end end
				if item.Gui then item.Gui:Destroy() end
				table.remove(textItems,i)
			end
			for i=#fontTargets,1,-1 do if removedGuis[fontTargets[i]] then table.remove(fontTargets,i) end end
			for _,run in self.Children do if run.InitialLetter then hitNodes[run.Gui]=nil;hitStyles[run.Gui]=nil;nodeBoxes[run.Node]=nil;run.Gui:Destroy()end end
			for _,run in self.Children do
				if run.Kind~="Words" then continue end
				for _,item in run.Items do
					if item.Kind=="Space" and item.Gui and not removed[item]then GroupOpacity.untrack(item);item.Gui:Destroy()
					elseif structure and item.Kind=="Image" and item.Gui and not item.InlineBox then GroupOpacity.untrack(item);item.Gui.Parent=frame
					elseif structure and item.InlineBox then
						local retained=item.InlineBox;local outer=if retained.OpacityGroup then retained.OpacityGroup.Gui else retained.Gui;outer.Parent=frame
					end
				end
				for _,fragment in run.FragmentPool or {} do hitNodes[fragment.Gui]=nil;hitStyles[fragment.Gui]=nil;fragment.Gui:Destroy() end
			end
			if style.OpacityGroup then
				for i=#style.OpacityGroup.Members,1,-1 do if removed[style.OpacityGroup.Members[i]] then table.remove(style.OpacityGroup.Members,i) end end
			end
			for _,group in ownedInlineGroups do
				local parentGroup=group.ScriptParentGroup
				if parentGroup then local index=table.find(parentGroup.Children,group);if index then table.remove(parentGroup.Children,index) end end
				group.Gui:Destroy()
			end
			table.clear(ownedInlineGroups)
			self.InlineOpacityGroups=nil
			local firstRecord=#styleRecords+1
			for i=#styleRecords,1,-1 do
				local record=styleRecords[i]
				if record.TextOwner==self and not (structure and (nodeBoxes[record.Node] or retainedControls[record.Node] or retainedReplaced[record.Node])) then
					firstRecord=i;nodeStyles[record.Node]=nil;table.remove(styleRecords,i)
				end
			end
			local existingCount=#styleRecords
			table.clear(self.Children)
			words=InlineWords.new(diagnostic);wordCount=0;hasFlow=false;quoteDepth=0
			initialAvailable=not node.GeneratedPseudo and(style.Display=='block'or style.Display=='flow-root'or style.ListItem==true)
			local savedOwner=textOwner;textOwner=self
			if ElementNames.htmlName(node)=='option'and (style.SelectBaseContents or fragment and node==fragment.Node)then generated(node,'checkmark',style)end
			generated(node,"before",style)
   for _,child in contentChildren()do visit(child,rubyTextStyle or style)end
			generated(node,"after",style);if box.RichSelect then generated(node,'picker-icon',style)end;flush()
			textOwner=savedOwner
			refreshListNumbers(self)
			local added={}
			while #styleRecords>existingCount do table.insert(added,table.remove(styleRecords,existingCount+1)) end
			for index,record in added do table.insert(styleRecords,math.min(firstRecord+index-1,#styleRecords+1),record) end
			table.clear(counterLookahead)
			if self.AllChildren then self.AllChildren=self.Children end
			self:SyncContentVisibility()
		end
		populateContents=function()
			local savedOwner=textOwner;textOwner=box
			box.ContentsBuilt=true
			if disclosure then
			local summaryStyle=resolve(disclosure.SummaryNode,style)
			local title=build(disclosure.SummaryNode,frame,style,summaryStyle)
			if title then table.insert(box.Children,title) end
			-- Anonymous content wrapper: author selectors still see the original DOM.
			local bodyStyle=Style.resolve(disclosure.BodyNode,style,diagnostic)
			local body=build(disclosure.BodyNode,frame,style,bodyStyle)
			table.insert(box.Children,body)
			disclosure.Box,disclosure.Summary,disclosure.Body=box,title,body
			box.AllChildren=box.Children
			Disclosure.apply(disclosure)
			else
   if ElementNames.htmlName(node)=='option'and (style.SelectBaseContents or fragment and node==fragment.Node)then generated(node,'checkmark',style)end
   generated(node,"before",style)
   for _, child in contentChildren()do
				-- Annotations inherit the live Ruby style; the compact clone belongs
				-- only to the base text and is refreshed during recascades below.
				visit(child,if ElementNames.htmlName(child)=="rt" then style else rubyTextStyle or style)
			end
			generated(node,"after",style);if box.RichSelect then generated(node,'picker-icon',style)end
			end
			flush()
			if box.AllChildren and not disclosure then box.AllChildren=box.Children end
			if ElementNames.htmlName(node)=="fieldset"then
				box.Legend=nil
				for _,child in box.Children do
					if child.Node and child.Node.Parent==node and ElementNames.htmlName(child.Node)=="legend"and not child.Style.Hidden and child.Style.Position~="absolute"and child.Style.Position~="fixed"then box.Legend=child;break end
				end
			end
			textOwner=savedOwner
		end
		if skippedContents()then box.ContentsBuilt=false;box:SyncContentVisibility()
		else populateContents()end
		refreshListNumbers(box)
		if style.TableRole=="table"then prepareTable(box)end
		if ElementNames.htmlName(node) == "dialog" then
			dialogState = Dialog.new(node, box, dialogHost)
			dialogState.BackdropStyle = resolvePseudo(node, style, "backdrop")
			table.insert(dialogs, dialogState)
			dialogsByNode[node] = dialogState
		end
		if node.Attributes and node.Attributes.popover ~= nil then
			local popoverState = Popover.new(node, box, popoverHost)
			table.insert(popovers, popoverState)
			popoversByNode[node] = popoverState
		end
		Counters.leave(counterState)
		if visibleCounters then counterState = visibleCounters end
		textOwner = previousTextOwner
		return box
	end
	rootInherited = {
		FontSize = 16, Font = defaultFont or FontFamily.Default, DefaultFont = defaultFont or FontFamily.Default, Color = Color3.new(0, 0, 0),
		LineHeight = { Kind = "normal" }, TextAlign = "start",
		Margin = { 0, 0, 0, 0 }, Padding = { 0, 0, 0, 0 },
		ViewportWidth=mediaEnvironment.Width,ViewportHeight=mediaEnvironment.Height,
		PreferredColorScheme=mediaEnvironment.PreferredColorScheme or 'light',ColorIsDefault=true,
	}
	tree = if fragment then build(fragment.Node,root,fragment.Inherited)else build(document, root, rootInherited)
	table.clear(counterLookahead)
	tree.VisualEffects = visualEffects
	tree.Controls, tree.HitNodes = controls, hitNodes
	tree.TextItems,tree.TextItemsByGui=textItems,textItemsByGui
	tree.NodeBoxes = nodeBoxes
	function tree:UnrenderedControl(node: any): any
		local entry=ElementProfile.entry(node)
		if not entry or entry.Render~="control" then return nil end
		if pendingControlStates[node] then return pendingControlStates[node] end
		local c=unrenderedState(node)
		pendingControlStates[node]=c
		return c
	end
	function tree:SaveControlState(node: any,c: any)
		pendingControlStates[node]=c
		Directionality.bind(node,c)
	end
	function tree:ForgetDetachedControlState()
		table.clear(pendingControlStates);table.clear(savedControlStates);table.clear(retainedControls)
	end
	local links={}
	function tree:RefreshLinkIndex()
		table.clear(links)
		local pending={if fragment then fragment.Node else document}
		while #pending > 0 do
		local node = table.remove(pending)
		local linkStyle = nodeStyles[node]
		if node.Kind == "Element" and node.Attributes.href ~= nil and ((ElementNames.htmlName(node) == "a" and not MediaContent.contents(node)and linkStyle and not linkStyle.Hidden and linkStyle.Visibility ~= "hidden") or ElementNames.htmlName(node) == "area") then
			table.insert(links, node)
		end
		for index = #node.Children, 1, -1 do table.insert(pending, node.Children[index]) end
		if node.InternalShadowRoot then table.insert(pending, node.InternalShadowRoot) end
		end
	end
	imageMapIndex:Refresh()
	tree:RefreshLinkIndex()
	tree.Links = links
	tree.CollapsedTableCells=collapsedTableCells
	tree.NodeStyles=nodeStyles
	local function ensureCanvasBackground(paintStyles: any?): boolean
		if not canvasEnabled or tree.CanvasBackgroundState or not CanvasBackground.isDocument(document)then return false end
		-- A real document owns its canvas before it has a documentElement.
		-- document.open can also convert a legacy fragment host in this tree.
		tree.CanvasBackgroundState=CanvasBackground.new(root,document,tree,backgrounds,Factory)
		for _,box in {tree.CanvasBackgroundState.RootBox or false,tree.CanvasBackgroundState.OwnerBox or false}do
			if box then box.Gui.BackgroundTransparency=1;if paintStyles then paintStyles[box.Style]=true end end
		end
		return true
	end
	ensureCanvasBackground()
	function tree:PublishCanvasBackground(width: number?,height: number?)
		if self.CanvasBackgroundState then self.CanvasBackgroundState:Publish(width,height)end
	end
	function tree:IsMediaFallback(node: any): boolean
		return MediaContent.contents(node)
	end
	function tree:IsContentSkipped(node: any): boolean
		local ancestor=ShadowTree.FlatParent(node)
		while ancestor do
			local box=nodeBoxes[ancestor]
			if box and box.HiddenContents then return true end
			ancestor=ShadowTree.FlatParent(ancestor)
		end
		return false
	end
	function tree:PublishContentVisibility()
		-- Reconciliation and cooperative text bounds can span several frames.
		-- New labels and newly opened details stay behind a passive local gate
		-- until the complete root geometry (including parent sizes) is committed.
		for host in pendingWordPaintHosts do
			pendingWordPaintHosts[host]=nil
			if host.Parent then host.Visible=true end
		end
		for d in pendingDisclosureReveals do
			pendingDisclosureReveals[d]=nil
			if disclosures[d.Node]==d and d.Body then
				d.Body.LayoutRevealPending=nil
				d.Body.Gui.Visible=d.Open and not d.Body.Style.Hidden
			end
		end
		-- Ordinary commits do not scan the document; only new deferred content
		-- has a blank gate waiting for geometry to be published.
		if not next(pendingContentReveals)then return end
		for box in pendingContentReveals do
			pendingContentReveals[box]=nil
			if nodeBoxes[box.Node]==box and box.ContentRevealPending and not box.HiddenContents then
				box.ContentRevealPending=nil;box.ContentHost.Visible=true
			end
		end
	end
	function tree:EnablePendingPresentation()
		self.PendingPresentationEnabled=true
		for _,d in disclosures do
			d.QueueReveal=queueDisclosureReveal
		end
	end
	function tree:DestroyCanvasBackground()
		if self.CanvasBackgroundState then self.CanvasBackgroundState:Destroy();self.CanvasBackgroundState=nil end
	end
	tree.ImageMapItems=imageMapItems
	tree.ImageMapIndex=imageMapIndex
	function tree:ImageMapCursor(area,image)
		-- A virtual shape matches the area's own selectors but inherits from
		-- its associated image. Only cursor participates in shape rendering.
		local cached=imageMapIndex.Cursor
		if cached and cached.Area==area and cached.Image==image then return cached.Value end
		local value=Style.resolve(area,nodeStyles[image],function()end,false,matched(area)).Cursor
		imageMapIndex.Cursor={Area=area,Image=image,Value=value}
		imageMapIndex.CursorResolves=(imageMapIndex.CursorResolves or 0)+1
		return value
	end
	tree.HitStyles=hitStyles
	tree.Disclosures=disclosures
	tree.Dialogs,tree.DialogsByNode,tree.DialogHost=dialogs,dialogsByNode,dialogHost
	tree.Popovers,tree.PopoversByNode,tree.PopoverHost=popovers,popoversByNode,popoverHost
	tree.ViewportPositioned=viewportPositioned
	Dialog.apply(tree)
	Popover.apply(tree)
	tree.FontPreloadTargets = fontTargets
	tree.ImageItems = imageItems
	tree.MediaItems=mediaItems
	tree.IFrameItems=iframeItems
	tree.CanvasItems=canvasItems
	tree.MediaByNode=setmetatable({},{__mode="k"})
	for _,item in mediaItems do tree.MediaByNode[item.Node]=item end
 tree.SVGItems=svgItems
	tree.Positioning, tree.HasOpacity = positioning, opacity
	tree.ShadowRoots, tree.SlotAssignments = shadowRoots, slotAssignments
	tree.CSSRules, tree.CSSStates = rules, cssStates
	tree.Factory=Factory
	local dynamicFields = {
		ListStyleType=true,
		QuirksBodyColor=true,QuirksBodyAlpha=true,QuirksBodyDefault=true,
		TableRole=true,TableGroupKind=true,TableBorderMode=true,CollapsedBorder=true,BorderCollapse=true,BorderSpacing=true,TableLayout=true,EmptyCells=true,CaptionSide=true,VisibilityCollapse=true,
		UAWidthFitContent=true,UAHeightFitContent=true,
		AutoImageSize=true,ContainIntrinsicWidth=true,ContainIntrinsicHeight=true,
		SelectBaseContents=true,
		Overflow=true,OverflowX=true,OverflowY=true,
		Display=true,Hidden=true,Float=true,Clear=true,Direction=true,UnicodeBidi=true,PointerEvents=true,UserSelect=true,TouchAction=true,
		Appearance=true,FieldSizing=true,ControlBackgroundSpecified=true,ControlBorderSpecified=true,ButtonNativeRadius=true,CaretColor=true,CaretColorAlpha=true,CaretShape=true,CaretAnimation=true,CaretCustom=true,
		ScrollSnapType=true,ScrollSnapAlign=true,ScrollSnapStop=true,ScrollBehavior=true,ScrollPadding=true,ScrollMargin=true,
		ScrollbarWidth=true,ScrollbarColor=true,ScrollbarGutter=true,OverscrollX=true,OverscrollY=true,
		FontFeatureSettings=true,FontVariantNumeric=true,FontVariantLigatures=true,FontKerning=true,FontVariantCaps=true,FontVariantPosition=true,FontSizeAdjust=true,FontStretch=true,
		OpenTypeFeatures=true,TabularNums=true,TextOverflow=true,MaxLines=true,TextJustify=true,UnderlinePosition=true,Hyphens=true,HyphenateCharacter=true,HyphenateLimitChars=true,HyphenationLanguage=true,
		WhiteSpace=true,WhiteSpaceCollapse=true,TextWrapMode=true,TextTransform=true,TextTransformLanguage=true,WordBreak=true,OverflowWrap=true,
		TextEmphasisStyle=true,TextEmphasisColor=true,TextEmphasisColorAlpha=true,TextEmphasisPosition=true,TextShadows=true,
		Decorations=true,DecorationColor=true,DecorationColorAlpha=true,DecorationThickness=true,DecorationStyle=true,DecorationSkipInk=true,UnderlineOffset=true,
		DarkScheme=true,ColorIsDefault=true,PreferredColorScheme=true,ControlColorSpecified=true,
		MarginTrim=true,MarginBreak=true,MinIntrinsicSizing=true,ColorScheme=true,AlignTracks=true,JustifyTracks=true,GridAutoPosition=true,ColumnRuleBreak=true,ColumnRuleVisibilityItems=true,
		ColumnRuleEdgeInsetStart=true,ColumnRuleEdgeInsetEnd=true,ColumnRuleInteriorInsetStart=true,ColumnRuleInteriorInsetEnd=true,
  Custom = true,Opacity=true,Filter=true,AccentColor=true,AccentColorAlpha=true,
  CounterReset=true,CounterIncrement=true,CounterSet=true,GeneratedContent=true,Quotes=true,
		Color=true,ColorAlpha=true,Background=true,BackgroundAlpha=true,InlineBackground=true,InlineBackgroundAlpha=true,BackgroundImages=true,BackgroundSizes=true,
		BorderSides=true,BorderSizes=true,BorderUniform=true,BorderWidth=true,BorderStyle=true,BorderColor=true,BorderColorAlpha=true,BorderSize=true,BorderRadius=true,BorderRadii=true,BoxShadows=true,
		OutlineWidth=true,OutlineStyle=true,OutlineColor=true,OutlineColorAlpha=true,OutlineOffset=true,
		BackgroundPositions=true,BackgroundRepeats=true,BackgroundOrigins=true,BackgroundClips=true,BackgroundAttachments=true,Cursor=true,Visibility=true,
		Font=true,FontSize=true,RootFontSize=true,UnadjustedFontSize=true,FontWeight=true,FontStyle=true,LineHeight=true,TextAlign=true,TextAlignLast=true,TextIndent=true,WordSpacing=true,LetterSpacing=true,
		Width=true,Height=true,MinWidth=true,MaxWidth=true,MinHeight=true,MaxHeight=true,BoxSizing=true,AspectRatio=true,
		Margin=true,MarginValues=true,MarginAuto=true,Padding=true,PaddingValues=true,
		FlexDirection=true,FlexWrap=true,FlexBalance=true,FlexLineCount=true,FlexGrow=true,FlexShrink=true,FlexBasis=true,Order=true,JustifyContent=true,AlignItems=true,AlignSelf=true,AlignContent=true,Gap=true,RowGapSpecified=true,GridGapSpecified=true,
		GridColumns=true,GridRows=true,GridAreas=true,GridAutoColumns=true,GridAutoRows=true,GridAutoFlow=true,
		LegacyGrid=true,LegacyGridColumns=true,LegacyGridRows=true,
		GridColumnStart=true,GridColumnEnd=true,GridRowStart=true,GridRowEnd=true,JustifyItems=true,JustifySelf=true,
		Position=true,Insettop=true,Insetright=true,Insetbottom=true,Insetleft=true,ZIndex=true,ObjectFit=true,ObjectPosition=true,ObjectViewBox=true,ImageOrientation=true,ImageResolution=true,ShapeOutside=true,ShapeMargin=true,ShapeImageThreshold=true,MaskType=true,VerticalAlign=true,
		Transform=true,TransformOrigin=true,Translate=true,Rotate=true,Scale=true,
		Contain=true,ContainerType=true,ContainerNames=true,ContentVisibility=true,ContainingDirection=true,AnchorNames=true,AnchorScope=true,PositionAnchor=true,PositionArea=true,PositionTryOrder=true,PositionTryFallbacks=true,PositionTryKey=true,ClipPath=true,MaskImage=true,BorderShape=true,BoxDecorationBreak=true,
		MaskBorderSource=true,MaskOrigins=true,MaskClips=true,MaskComposite=true,
		MaskBorderSlice=true,MaskBorderWidth=true,MaskBorderOutset=true,MaskBorderRepeat=true,MaskBorderMode=true,
		BorderImageSource=true,BorderImageSlice=true,BorderImageWidth=true,BorderImageOutset=true,BorderImageRepeat=true,CornerShape=true,CornerShapes=true,MixBlendMode=true,Isolation=true,BackgroundBlendMode=true,BackdropFilter=true,
		MaskPositions=true,MaskSizes=true,MaskRepeats=true,MaskMode=true,ClipRect=true,
		OffsetPath=true,OffsetDistance=true,OffsetRotate=true,OffsetAnchor=true,OffsetPosition=true,TransformBox=true,Perspective=true,PerspectiveOrigin=true,TransformStyle=true,BackfaceVisibility=true,
		TransitionProperty=true,TransitionDuration=true,TransitionTiming=true,TransitionDelay=true,TransitionBehavior=true,
		AnimationName=true,AnimationDuration=true,AnimationTiming=true,AnimationDelay=true,AnimationIteration=true,AnimationDirection=true,AnimationFill=true,AnimationPlay=true,
		AnimationTimeline=true,AnimationComposition=true,ScrollTimelineNames=true,ScrollTimelineAxes=true,ScrollTimelineAxis=true,ScrollMarkerGroup=true,
		AnimationRangeStart=true,AnimationRangeEnd=true,InterpolateSize=true,
		InitialLetter=true,TextBoxTrim=true,TextBoxEdge=true,
		ScrollInitialTarget=true,OverflowAnchor=true,OverflowClipMargins=true,
		LineBreak=true,HangingPunctuation=true,TextAutospace=true,WritingMode=true,TextOrientation=true,
		RubyPosition=true,RubyAlign=true,
		ColumnCount=true,ColumnWidth=true,ColumnHeight=true,ColumnWrap=true,ColumnFill=true,ColumnSpan=true,ColumnRuleWidth=true,ColumnRuleStyle=true,ColumnRuleColor=true,ColumnRuleColorAlpha=true,
		ColumnRuleInsetCapStart=true,ColumnRuleInsetCapEnd=true,ColumnRuleInsetJunctionStart=true,ColumnRuleInsetJunctionEnd=true,BreakBefore=true,BreakAfter=true,BreakInside=true,Orphans=true,Widows=true,
		ViewportWidth=true,ViewportHeight=true,UsesViewportUnits=true,UsesContainerUnits=true,
	}
 local pendingGeneratedChanges={}
 function tree:GeneratedChanges(fresh: boolean?,affected: any?): any
  local enabled=next(generatedRecords)~=nil
  if not enabled then
   local sets={rules};for _,scoped in rulesByShadow do table.insert(sets,scoped)end
   for _,set in sets do for index=1,#set do local rule=set[index];if rule.PseudoElement=='before'or rule.PseudoElement=='after'or rule.PseudoElement=='marker'or rule.PseudoElement=='first-letter'or rule.PseudoElement=='picker-icon'or rule.PseudoElement=='checkmark'then enabled=true;break end end;if enabled then break end end
  end
  if not enabled then return{}end
  local nextRecords,changed,interactions=GeneratedContent.update(document,generatedRecords,function(node,inherited)
   if not fresh and nodeStyles[node]then return nodeStyles[node]end
   local parent=inherited or self.Style
   local computed=Style.resolve(node,parent,function()end,false,matched(node))
   computed.HyphenationLanguage=if computed.Hyphens=='auto'then LanguageRange.language(node)else ''
   computed.TextTransformLanguage=if computed.TextTransform and computed.TextTransform~='none'then LanguageRange.language(node)else ''
   computed.TableBorderMode=if computed.TableRole=='table'then computed.BorderCollapse else parent.TableBorderMode
   computed.CollapsedBorder=computed.TableRole~=nil and computed.TableRole~='caption'and computed.TableBorderMode=='collapse'
   return computed
  end,resolvePseudo,dynamicFields,rules.CounterStyles,if fresh then nil else affected)
  generatedRecords=nextRecords;generatedReady=true
  if next(interactions)then
   -- Generated blocks/initial letters may hold a clone of their pseudo style.
   -- Publish interaction changes to those retained hit surfaces as well as the
   -- original inline/marker style, without replacing their text or GUI.
   for _,style in hitStyles do
    local updates=interactions[style.Node]
    local source=updates and updates[style.PseudoElement]
    if source and source~=style then
     for field in GeneratedContent.InteractionFields do style[field]=source[field]end
     style.ViewportWidth,style.ViewportHeight=source.ViewportWidth,source.ViewportHeight
    end
   end
  end
  return changed
 end
	local paintOnlyFields = {
		QuirksBodyColor=true,QuirksBodyAlpha=true,QuirksBodyDefault=true,
		-- Custom properties are cascade inputs. Their consumers below request
		-- geometry work only when a resolved geometry value actually changes.
		Custom=true,RootFontSize=true,ColorScheme=true,DarkScheme=true,PreferredColorScheme=true,ScrollbarColor=true,
		ColorIsDefault=true,ControlColorSpecified=true,Color=true,ColorAlpha=true,AccentColor=true,AccentColorAlpha=true,OutlineColor=true,OutlineColorAlpha=true,
		Cursor=true,PointerEvents=true,UserSelect=true,
		TextEmphasisColor=true,TextEmphasisColorAlpha=true,DecorationColor=true,DecorationColorAlpha=true,TextShadows=true,
		CaretColor=true,CaretColorAlpha=true,
		OutlineWidth=true,OutlineStyle=true,OutlineOffset=true,Background=true,BackgroundAlpha=true,InlineBackground=true,InlineBackgroundAlpha=true,ControlBackgroundSpecified=true,ControlBorderSpecified=true,ButtonNativeRadius=true,
		BackgroundImages=true,BackgroundSizes=true,BackgroundPositions=true,BackgroundRepeats=true,BackgroundOrigins=true,BackgroundClips=true,BackgroundAttachments=true,
		BorderRadius=true,BorderRadii=true,BoxShadows=true,Transform=true,TransformOrigin=true,OffsetDistance=true,
		Translate=true,Rotate=true,Scale=true,TransformBox=true,
		MixBlendMode=true,Isolation=true,BackgroundBlendMode=true}
	local imageEffectFields={Filter=true,ClipPath=true,MaskImage=true,MaskMode=true,MaskComposite=true,
		MaskOrigins=true,MaskClips=true,MaskPositions=true,MaskSizes=true,MaskRepeats=true,
		MaskBorderSource=true,MaskBorderSlice=true,MaskBorderWidth=true,MaskBorderOutset=true,MaskBorderRepeat=true,MaskBorderMode=true}
	local textPaintFields = {
		Color=true,ColorAlpha=true,ColorIsDefault=true,ControlColorSpecified=true,
		TextEmphasisColor=true,TextEmphasisColorAlpha=true,DecorationColor=true,DecorationColorAlpha=true,TextShadows=true,
		Cursor=true,PointerEvents=true,UserSelect=true,
	}
	local animationColorFields={Color=true,ColorAlpha=true,ColorIsDefault=true,ControlColorSpecified=true,
		Background=true,BackgroundAlpha=true,InlineBackground=true,InlineBackgroundAlpha=true,
		BorderSides=true,BorderUniform=true,BorderColor=true,BorderColorAlpha=true,OutlineColor=true,OutlineColorAlpha=true,
		DecorationColor=true,DecorationColorAlpha=true,Decorations=true,TextEmphasisColor=true,TextEmphasisColorAlpha=true,
		ColumnRuleColor=true,ColumnRuleColorAlpha=true,CaretColor=true,CaretColorAlpha=true,AccentColor=true,AccentColorAlpha=true,
		Filter=true,QuirksBodyColor=true,QuirksBodyAlpha=true,QuirksBodyDefault=true}
	local generatedInputs = {
		Custom=true,CounterReset=true,CounterIncrement=true,CounterSet=true,Quotes=true,
		Hidden=true,Display=true,GeneratedContent=true,
	}
	local function hasVisibleBorder(style: any): boolean
		if style.BorderSizes then
			for _, width in style.BorderSizes do if width > 0 then return true end end
			return false
		end
		return (style.BorderSize or 0) > 0
	end
	local function sameStyleValue(a: any,b: any,seen: any?): boolean
		if a==b then return true end
		if type(a)~="table" or type(b)~="table" then return false end
		seen=seen or {}
		if seen[a] then return seen[a]==b end
		seen[a]=b
		for key,value in a do
			if not sameStyleValue(value,b[key],seen) then return false end
		end
		for key in b do if a[key]==nil then return false end end
		return true
	end
	local function sameBorderGeometry(a: any, b: any): boolean
		for side = 1, 4 do
			local oldSize = if a.BorderSizes then a.BorderSizes[side] else a.BorderSize or 0
			local newSize = if b.BorderSizes then b.BorderSizes[side] else b.BorderSize or 0
			if oldSize ~= newSize then return false end
			local oldEdge, newEdge = a.BorderSides and a.BorderSides[side], b.BorderSides and b.BorderSides[side]
			if (oldEdge and oldEdge.Width or a.BorderWidth) ~= (newEdge and newEdge.Width or b.BorderWidth)
				or (oldEdge and oldEdge.Style or a.BorderStyle) ~= (newEdge and newEdge.Style or b.BorderStyle) then return false end
		end
		return true
	end
	local function sameDecorationGeometry(a: any, b: any): boolean
		a, b = a or {}, b or {}
		if #a ~= #b then return false end
		for index, old in a do
			for key, value in old do if key ~= "Color" and key ~= "Alpha" and not sameStyleValue(value, b[index][key]) then return false end end
			for key, value in b[index] do if key ~= "Color" and key ~= "Alpha" and not sameStyleValue(value, old[key]) then return false end end
		end
		return true
	end
	local function write(gui: any, key: string, value: any)
		if gui and gui[key] ~= value then gui[key] = value end
	end
	-- Background changes can switch native corners to raster corners without
	-- changing layout. Synchronize that representation before borders repaint,
	-- using the same contract as direct animation decoration updates.
	local function paintCornerRadius(box: any,style: any): boolean?
		local native=CornerRadii.native(style);style.NativeCornerRadii=native;box.NativeCornerRadii=native
		local cornerHost=if box.Kind=="BlockImage"then box.ImageItem.BoxGui else box.Gui
		if (style.BorderRadii or(style.BorderRadius or 0)>0)and not box.Corner and not(box.ImageItem and box.ImageItem.Control)then
			box.Corner=Factory.modifier("UICorner",cornerHost,{CornerRadius=UDim.new(0,style.BorderRadius or 0)})
			if box.Kind=="BlockImage"then box.ImageItem.BoxCorner=box.Corner end
		end
		if box.Corner and not(box.ImageItem and box.ImageItem.Control)then
			local resolved=CornerRadii.resolve(style,box.OuterWidth or 0,box.OuterHeight or 0)
			if native and resolved then CornerRadii.apply(box.Corner,resolved)
			else
				local radius=style.BorderRadius or 0
				if resolved then radius=math.huge;for _,value in resolved do radius=math.min(radius,value[1],value[2])end end
				if style.CornerShape~="round"then radius=0 end
				write(box.Corner,"CornerRadius",UDim.new(0,radius))
				local round={radius,radius};CornerRadii.apply(box.Corner,{round,round,round,round})
			end
		end
		if box.Kind~="BlockImage"and style.BorderRadii and not native then box.RadiusRenderer=corners end
		local rounded=box.ResolvedBorderRadii~=nil
		if box.RadiusRenderer and box.OuterWidth and box.OuterHeight then
			rounded=box.RadiusRenderer:DrawRadius(box,style,box.OuterWidth,box.OuterHeight)
			if rounded==nil then return nil end
			style.ResolvedBorderRadii=if rounded then box.ResolvedBorderRadii else nil
			if not rounded then box.ResolvedBorderRadii=nil;style.RasterBorderOverlay=nil end
		end
		return rounded
	end
	local function paintDynamic(onlyStyles: any?)
		local tables={}
		for node,style in nodeStyles do
			WorkContext.checkpoint()
			if onlyStyles and not onlyStyles[style]then continue end
			if style.TableRole~='row'and style.TableRole~='group'and ElementNames.htmlName(node)~='col'and ElementNames.htmlName(node)~='colgroup'then continue end
			local owner=tree:TextOwner(ShadowTree.FlatParent(node))
			while owner do
				if owner.TableGrid then tables[owner]=true;break end
				owner=owner.LayoutParent or(owner.Node and tree:TextOwner(ShadowTree.FlatParent(owner.Node)))
			end
		end
		for box in tables do
			TableColumnPaint.create(box,Factory,hitNodes)
			for _,entry in box.TableGrid.Entries do if entry.Cell.OuterHeight then TableColumnPaint.arrange(entry.Cell,entry.Cell.OuterHeight)end end
		end
		visualEffects:PrepareComposites(onlyStyles)
		local viewportChanged = tree.PositioningSurfacesDirty == true
		local paintBoundsChanged = {}
		local function boundsChanged(box: any)
			while box and not paintBoundsChanged[box] do
				paintBoundsChanged[box] = true
				local parent = box.LayoutParent or (box.Kind=="Words" and box.ScrollBox)
					or (box.Node and tree:TextOwner(ShadowTree.FlatParent(box.Node)))
				-- Bare render-tree callers may not have a DirtyLayout ownership
				-- index yet. Atomic inline boxes still contribute through their run.
				if parent and not box.LayoutParent then
					for _, run in parent.Children or {} do
						if run.Kind=="Words" and table.find(run.Children or {},box) then paintBoundsChanged[run]=true end
					end
				end
				box = parent
			end
		end
		local function controlOutset(item: any): number
			local outline=item.ControlOutline
			return if outline and outline.Gui.Visible~=false then math.max(0,outline.Style.BorderSize+outline.Offset) else 0
		end
		for nodeKey, box in nodeBoxes do
			local style = nodeStyles[nodeKey]
			if style and (not onlyStyles or onlyStyles[style]) then
				if box.ScrollGui then ScrollLayout.paint(box)end
				if box.ViewportKind == "fixed" or box.ViewportKind == "sticky" then viewportChanged = true end
				write(box.Gui, "Visible", style.Hidden ~= true and not box.LayoutRevealPending)
				if box.ClipContent then
					write(box.ClipContent,"ClipsDescendants",box.TableContentClipped==true
						or(style.Overflow=="hidden"and style.OverflowX~="clip"and style.OverflowY~="clip"))
				end
				local newGroup = not box.OpacityGroup and ((style.Opacity or 1)<1 or needsMotionOpacity(style))
				if newGroup then
					box.OpacityGroup = GroupOpacity.create(box.Gui.Parent, style.Opacity, Factory)
					box.Gui.Parent = box.OpacityGroup.Content
					box.TransformBaseX, box.TransformBaseY = nil, nil
				end
				if box.OpacityGroup then
					tree.HasOpacity = true
					write(box.OpacityGroup.Gui, "Visible", style.Hidden ~= true)
				end
				if box.Kind == "BlockImage" then
					local oldControlOutset=if box.ImageItem.Control then controlOutset(box.ImageItem) else nil
					ReplacedElement.paint(box)
					local item = box.ImageItem
					box.Corner = item.BoxCorner or box.Corner
					if not item.Control and item.BoxWidth and item.BoxHeight then item.BorderEdges=BorderBox.update(item.BorderEdges, style, item.BoxGui, item.BoxWidth, item.BoxHeight,Factory,corners) end
					if style.CornerShape == "round" and (style.BorderRadius or 0) > 0 and not box.Corner then
						box.Corner = Factory.modifier("UICorner", item.BoxGui, {CornerRadius = UDim.new(0, style.BorderRadius)})
						if not item.Control then item.BoxCorner = box.Corner end
					end
					if box.Corner and not item.Control then write(box.Corner, "CornerRadius", UDim.new(0, style.BorderRadius or 0)) end
					paintShadows(box, style)
					-- Controls own an outline on their zero-margin inner view. An
					-- additional wrapper outline would paint the same focus ring twice.
					if item.Control then
						if oldControlOutset~=controlOutset(item) then boundsChanged(box) end
					elseif OutlineBox.update(box, style, Factory, corners) then boundsChanged(box) end
					if box.OpacityGroup and box.OuterWidth and box.OuterHeight then GroupOpacity.arrange(box); GroupOpacity.paint(box.OpacityGroup, style) end
					if box.OuterWidth and box.OuterHeight then BoxTransform.apply(box,nil,true) end
					continue
				end
				local rounded=paintCornerRadius(box,style)
				if rounded==nil then continue end
				if box.OuterWidth and box.OuterHeight and not style.CollapsedBorder then
					local image = box.ImageItem
					if image and image.BoxGui and image.BoxWidth and image.BoxHeight then
						image.BorderEdges=BorderBox.update(image.BorderEdges, style, image.BoxGui, image.BoxWidth, image.BoxHeight,Factory,corners)
					else
						box.InsetEdges=BorderBox.update(box.InsetEdges, style, box.CellBorder or box.Gui, box.OuterWidth, box.OuterHeight,Factory,corners, box.LegendGap)
					end
				end
				if ElementNames.htmlName(box.Node)~='img' and style.Filter and #style.Filter.Steps>0 and not box.OpacityGroup then
					box.OpacityGroup=GroupOpacity.create(box.Gui.Parent,style.Opacity,Factory)
					box.Gui.Parent=box.OpacityGroup.Content
				end
				if box.OpacityGroup then GroupOpacity.paint(box.OpacityGroup,style) end
				if newGroup and box.OuterWidth and box.OuterHeight then GroupOpacity.arrange(box) end
				if OutlineBox.update(box,style,Factory,corners) then boundsChanged(box) end
				if box.Node.Kind~="Document" then
					paintShadows(box,style)
				end
				if box.Node.Kind~='Document'or not tree.CanvasBackgroundState then
					local used=CanvasBackground.usedStyle(box,style)
					write(box.Gui, "BackgroundColor3", used.Background or Color3.new(1,1,1))
					write(box.Gui, "BackgroundTransparency", if rounded or style.TableRole=='row'or style.TableRole=='group'then 1 elseif used.Visibility ~= "hidden" and used.Background then 1-(used.BackgroundAlpha or 1) else 1)
				end
				if box.BackgroundRenderer and box.OuterWidth and box.OuterHeight then box.BackgroundRenderer:Draw(box,box.OuterWidth,box.OuterHeight) end
				if box.VisualEffects and box.OuterWidth and box.OuterHeight then box.VisualEffects:Draw(box,box.OuterWidth,box.OuterHeight) end
				if box.OuterWidth and box.OuterHeight then BoxTransform.apply(box,nil,true) end
				if box.OpacityGroup then GroupOpacity.paint(box.OpacityGroup,style) end
				if box.Marker and box.Marker.Gui then
					if box.Marker.Repaint then box.Marker:Repaint(style)
					elseif box.Marker.Kind=="image" then continue
					elseif box.Marker.Kind ~= "disc" and box.Marker.Kind ~= "circle" and box.Marker.Kind ~= "square" then
						write(box.Marker.Gui,"TextColor3",style.Color);write(box.Marker.Gui,"TextTransparency",1-(style.ColorAlpha or 1))
					else write(box.Marker.Gui,"BackgroundColor3",style.Color) end
				end
			end
		end
		for _, control in controls do
			local item=control.Item
			if not onlyStyles or onlyStyles[item.Style] then
				local oldOutset=controlOutset(item)
				ControlView.paint(item)
				if oldOutset~=controlOutset(item) then
					local owner=tree.DirtyContext and tree.DirtyContext.Owners[item] or tree:TextOwner(control.Node)
					if owner and owner.Kind~="Words" and not nodeBoxes[control.Node] then
						for _, run in owner.Children or {} do
							if run.Kind=="Words" and table.find(run.Items or {},item) then boundsChanged(run);break end
						end
					end
					boundsChanged(owner)
				end
			end
		end
		for _,run in wordRuns do for _,item in run.Items or{}do
			if item.Kind=='Image'and not item.InlineBox and item.GeometryBox
				and(not onlyStyles or onlyStyles[item.Style])then
				BoxTransform.apply(item.GeometryBox,item.GeometryBox.Scene3DContext,true)
			end
		end end
		if tree.HasOpacity and next(paintBoundsChanged) then
			GroupOpacity.arrange(tree,nil,paintBoundsChanged)
			for box in paintBoundsChanged do
				if box.OpacityGroup and box.OuterWidth and box.OuterHeight then BoxTransform.apply(box,nil,true) end
			end
		end
		if viewportChanged and root.AbsoluteSize then
			ViewportLayer.attach(tree, root, Factory)
			ViewportLayer.update(tree, root)
		end
		visualEffects:UpdateComposites(tree,onlyStyles)
	end
	-- Numeric decoration effects already have a retained target box. Repaint
	-- that target directly rather than scanning the document each frame.
	local function positionOffset(value: any,axis: string,index: number): number
		local part=value and value[axis];return if part and part.Offset~=nil then part.Offset elseif value then value[index]or 0 else 0
	end
	function tree:RepaintAnimationBounds(boxes:any)
		local targets,poses={},{}
		for box in boxes do
			local current=box
			while current and not targets[current]do
				targets[current]=true
				if current.OpacityGroup and current.TransformApplied and not current.Scene3DRoot then
					local target=BoxTransform.target(current);local bounds=current.OpacityBounds or{0,0,current.OuterWidth,current.OuterHeight}
					local width,height=bounds[3]-bounds[1],bounds[4]-bounds[2]
					local ox,oy=(target.AnchorPoint and target.AnchorPoint.X or 0)*width,(target.AnchorPoint and target.AnchorPoint.Y or 0)*height
					local rotation=target.Rotation or 0;local radians=math.rad(rotation);local c,s=math.cos(radians),math.sin(radians)
					local scale=if current.TransformScale then current.TransformScale.Scale else 1;local dx,dy=width/2-ox,height/2-oy
					poses[current]={X=positionOffset(target.Position,"X",1)-(current.ViewportOffsetX or 0)-(current.TransformBaseX or 0)-ox-scale*((c-1)*dx-s*dy),
						Y=positionOffset(target.Position,"Y",2)-(current.ViewportOffsetY or 0)-(current.TransformBaseY or 0)-oy-scale*(s*dx+(c-1)*dy),Rotation=rotation,Scale=scale,OriginX=ox+bounds[1],OriginY=oy+bounds[2]}
				end
				current=current.LayoutParent or(current.Kind=="Words"and current.ScrollBox)or(current.Node and tree:TextOwner(ShadowTree.FlatParent(current.Node)))
			end
		end
			if tree.HasOpacity then GroupOpacity.arrange(tree,nil,targets)end
			for target in targets do
				if target.Scene3DRoot then BoxTransform.paint3D(target)
				elseif poses[target]then local pose=poses[target];BoxTransform.paint(target,pose.X,pose.Y,pose.Rotation,pose.Scale,pose.OriginX,pose.OriginY)end
			end
	end
	function tree:PaintAnimationDecorations(box: any)
		if not box or not box.OuterWidth or not box.OuterHeight then return end
		local style=box.Style;local changed=false
		paintShadows(box,style)
		local outsets={0,0,0,0}
		for _,shadow in style.BoxShadows or{}do if not shadow.Inset then
			local grow=(shadow.Spread or 0)+(shadow.Blur or 0)*2
			outsets[1]=math.min(outsets[1],shadow.X-grow);outsets[2]=math.min(outsets[2],shadow.Y-grow)
			outsets[3]=math.max(outsets[3],shadow.X+grow);outsets[4]=math.max(outsets[4],shadow.Y+grow)
		end end
		for index,value in outsets do if value~=(box.AnimationShadowOutsets and box.AnimationShadowOutsets[index]or 0)then changed=true;break end end
		box.AnimationShadowOutsets=outsets
		local rounded=paintCornerRadius(box,style)
		if rounded==nil then return end
		if box.RadiusRenderer then
			local used=CanvasBackground.usedStyle(box,style)
			write(box.Gui,"BackgroundTransparency",if rounded then 1 elseif used.Visibility~="hidden"and used.Background then 1-(used.BackgroundAlpha or 1)else 1)
		end
		if box.Kind=="BlockImage" then
			local item=box.ImageItem;local outline=item.ControlOutline
			local before=if outline and outline.Gui.Visible~=false then math.max(0,outline.Style.BorderSize+outline.Offset)else 0
			ReplacedElement.paint(box)
			if item.Control then
				outline=item.ControlOutline
				changed=changed or before~=(if outline and outline.Gui.Visible~=false then math.max(0,outline.Style.BorderSize+outline.Offset)else 0)
			else
				if item.BoxWidth and item.BoxHeight then item.BorderEdges=BorderBox.update(item.BorderEdges,style,item.BoxGui,item.BoxWidth,item.BoxHeight,Factory,corners)end
				changed=OutlineBox.update(box,style,Factory,corners)or changed
			end
		else
			if not style.CollapsedBorder then box.InsetEdges=BorderBox.update(box.InsetEdges,style,box.CellBorder or box.Gui,box.OuterWidth,box.OuterHeight,Factory,corners,box.LegendGap)end
			changed=OutlineBox.update(box,style,Factory,corners)or changed
		end
		if changed and tree.HasOpacity then tree:RepaintAnimationBounds({[box]=true})
		elseif box.Scene3DRoot then BoxTransform.paint3D(box)end
	end
	local function paintTextColor(onlyStyles: any)
		for _, item in textItems do
			local style=item.Style
			-- Preserved spaces are retained here for selection geometry, but their
			-- Frame has no text properties. Only Word items own painted glyphs.
			if item.Kind~="Word" or not onlyStyles[style] then continue end
			local transparency=if style.FontSize==0 or style.Visibility=="hidden" then 1 else 1-(style.ColorAlpha or 1)
			TextEmphasis.color(item)
			if item.VerticalAdvance then
				-- A color-only hover must not reveal the hidden horizontal source.
				for _, glyph in item.UprightPool or {} do
					write(glyph.TextGui,"TextColor3",style.Color)
					write(glyph.TextGui,"TextTransparency",transparency)
					TextShadows.arrange(glyph)
				end
				continue
			end
			if item.Glyphs then
				for _, glyph in item.Glyphs do
					write(glyph.Gui,"TextColor3",style.Color)
					write(glyph.Gui,"TextTransparency",transparency)
				end
			else
				local gui=item.TextGui or item.Gui
				write(gui,"TextColor3",style.Color)
				write(gui,"TextTransparency",transparency)
			end
			TextShadows.arrange(item)
		end
	end
	local function syncRubyTextStyle(style: any)
		local text=style.RubyTextStyle
		if not text then return end
		for field,value in style do if field~="RubyTextStyle" then text[field]=value end end
		text.LineHeight={Kind="normal"}
	end
	local function hasPositionedDescendant(box: any): boolean
		for _, child in box.Children or {} do
			local position = child.Style and child.Style.Position
			if position == "absolute" or position == "fixed" or hasPositionedDescendant(child) then return true end
		end
		return false
	end
	function tree:SyncPositioning()
		self.PositioningSurfacesDirty = true
		table.clear(viewportPositioned)
		self.Positioning = false
		for _, box in nodeBoxes do
			refreshListNumbers(box)
			local position = box.Style.Position
			box.HiddenByAncestor = false
			box.ContentSkipped=self:IsContentSkipped(box.Node)
			local ancestor = box.Node
			while ancestor do
				if nodeStyles[ancestor] and nodeStyles[ancestor].Hidden then box.HiddenByAncestor = true; break end
				ancestor = ShadowTree.FlatParent(ancestor)
			end
			if box.ContentSkipped then box.HiddenByAncestor=true end
			if (position ~= nil and position ~= "static") or box.Style.ZIndex ~= nil then self.Positioning = true end
			if not box.HiddenByAncestor and (position == "sticky" or position == "fixed") then table.insert(viewportPositioned, box) end
			if box.ViewportKind ~= position then
				box.ViewportKind, box.StickyScrollBox = nil, nil
				box.FixedViewportX, box.FixedViewportY = nil, nil
			end
		end
	end
	function tree:RefreshDOMStyles(affected: any, stateChange: boolean?, generatedStateChange: boolean?, work: (() -> boolean)?, animationMetrics: (boolean|string)?): (boolean, boolean, any, any, any, boolean)
		imageMapIndex.Cursor=nil
		table.clear(counterLookahead)
		-- Styles are updated in place; priority-only changes must invalidate animation samples too.
		if not animationMetrics then
			self.AnimationStyleRevision = (self.AnimationStyleRevision or 0) + 1
   if tree.MotionRuntime then tree.MotionRuntime:BeforeStyleChange(affected) end
   for node in affected do AnimationValues.beforeStyleChange(nodeBoxes[node])end
		end
		local changed = false
		local copyTextChanged=false
		local layoutNeeded = false
		local positioningChanged = false
		local ownershipChanged = false
		local layoutItems, textRefresh = {}, {}
		local regroupOwners,bidiOwners,axisOwners,effectOwners={},{},{},{}
		local spacingOwners = {}
		local contentOwners = {}
		local function requireLayout(record)
			layoutNeeded = true
			local owner = self:TextOwner(record.Node)
			layoutItems[owner or self] = true
		end
		local affectedStyles=setmetatable({},{__mode="k"})
		local boxPaintStyles, paintStyles, refreshedNodes = {}, {}, {}
		local controlStyles = {}
		for _, control in controls do controlStyles[control.Item.Style]=true end
		local generatedNeeded = not stateChange or generatedStateChange == true
		local decorationStyles = setmetatable({}, {__mode = "k"})
		local backgroundStyles = setmetatable({}, {__mode = "k"})
		local decorationGeometryStyles = {}
		local shadowGeometryStyles={}
		for _, record in styleRecords do
			if not affected[record.Node] and not affectedStyles[record.Inherited] then continue end
			if work then work() end
			refreshedNodes[record.Node]=true
			if generatedRecords[record.Node] then generatedNeeded=true end
			local current = record.Style
			local computed=recascade(record,if animationMetrics then self.AnimationMetricOverrides and self.AnimationMetricOverrides[record.Node]else nil,if animationMetrics then self.AnimationColorOverrides and self.AnimationColorOverrides[record.Node]else nil,if animationMetrics then self.AnimationTextShadowOverrides and self.AnimationTextShadowOverrides[record.Node]else nil)
			current.HTMLDirectionality,current.BidiContext=computed.HTMLDirectionality,computed.BidiContext
			local metricOwner=nodeBoxes[record.Node]
			if metricOwner and metricOwner.AnimationColorAuthor then
				metricOwner.AnimationColorAuthor=computed.AnimationColorBase or AnimationColors.snapshot(computed)
			end
			-- Identical RGB can still change inherited computed semantics: static
			-- currentColor stays symbolic; an effect sample is a resolved color.
			if current.AnimationColorSources~=computed.AnimationColorSources then affectedStyles[current]=true;changed=true end
			current.AnimationColorSources=computed.AnimationColorSources
			if metricOwner and metricOwner.AnimationTextShadowAuthor then metricOwner.AnimationTextShadowAuthor=computed.AnimationTextShadowBase or {Value=computed.TextShadows}end
			if animationMetrics=='colors'and computed.BorderSides then
				-- Color recascades may run beside held width/radius/font effects.
				-- Preserve their already sampled geometry on each physical edge.
				for side,edge in computed.BorderSides do
					local previous=current.BorderSides and current.BorderSides[side]
					edge.Width=if previous then previous.Width else current.BorderWidth
					edge.Style=if previous then previous.Style else current.BorderStyle
				end
				computed.BorderUniform=true;local first=computed.BorderSides[1]
				for _,edge in computed.BorderSides do if edge.Width~=first.Width or edge.Style~=first.Style or edge.Color~=first.Color or edge.Alpha~=first.Alpha then computed.BorderUniform=false;break end end
			end
			if metricOwner and metricOwner.AnimationMetricAuthor then
				local override=animationMetrics and self.AnimationMetricOverrides and self.AnimationMetricOverrides[record.Node]
				if override then
					-- An effect's underlying computed values use the author cascade;
					-- dependent rendered em dimensions use the sampled font instead.
					-- Cache that author context independently of the sampled clock.
					if metricOwner.AnimationMetricUnderlyingRevision~=self.AnimationStyleRevision
						or metricOwner.AnimationMetricParentSize~=record.Inherited.FontSize
						or metricOwner.AnimationMetricParentRootSize~=record.Inherited.RootFontSize
						or metricOwner.AnimationMetricParentLine~=record.Inherited.LineHeight then
						metricOwner.AnimationMetricUnderlyingStyle=recascade(record)
						metricOwner.AnimationMetricUnderlyingRevision=self.AnimationStyleRevision
						metricOwner.AnimationMetricParentSize,metricOwner.AnimationMetricParentRootSize=record.Inherited.FontSize,record.Inherited.RootFontSize
						metricOwner.AnimationMetricParentLine=record.Inherited.LineHeight
					end
				else metricOwner.AnimationMetricUnderlyingStyle=computed;metricOwner.AnimationMetricUnderlyingRevision=nil end
			end
			if metricOwner and metricOwner.AnimationMetricAuthor then
				metricOwner.AnimationMetricAuthor=computed.AnimationMetricBase or {FontSize=computed.UnadjustedFontSize or computed.FontSize,LineHeight=computed.LineHeight}
			end
			current.PositionTryResolve,current.PositionTryDefinitions=computed.PositionTryResolve,computed.PositionTryDefinitions
			current.HasAnchorFunctions=computed.HasAnchorFunctions
			if current.AtomicInline and computed.Display == "inline" then computed.Display = "inline-block" end
			-- Keep pixels usable by paint until layout resolves new expressions.
			-- Plain pixel values can update immediately; Values below request real
			-- spacing changes without comparing pixels with percentage/calc ASTs.
			for _,field in {"Margin","Padding"} do
				for _,value in computed[field] do
					if type(value)=="table" then computed[field]=current[field];break end
				end
			end
			local owner = nodeBoxes[record.Node]
			-- Collapsed-border widths belong to the shared grid, not the authored
			-- cell edge. Preserve them for a color/background-only recascade.
			if current.CollapsedBorder and owner and owner.TableBorderSource and computed.CollapsedBorder then
				local source=owner.TableBorderSource;local same=true
				for side=1,4 do
					local a,b=source.BorderSides and source.BorderSides[side],computed.BorderSides and computed.BorderSides[side]
					if (a and a.Width or source.BorderWidth)~=(b and b.Width or computed.BorderWidth)
						or(a and a.Style or source.BorderStyle)~=(b and b.Style or computed.BorderStyle)then same=false;break end
				end
				if same then computed.BorderSizes,computed.BorderSize=current.BorderSizes,current.BorderSize end
			end
			if owner and PositionedLayout.establishesFixedContainingBlock(current) ~= PositionedLayout.establishesFixedContainingBlock(computed)
				and hasPositionedDescendant(owner) then requireLayout(record) end
			local borderVisible = hasVisibleBorder(current) or hasVisibleBorder(computed)
			local borderPaintOnly = sameBorderGeometry(current, computed)
			local textOnly,paintChanged = true,false
			for field in dynamicFields do
				if animationMetrics=='colors'and not animationColorFields[field]then continue end
				if animationMetrics=='text-shadows'and field~='TextShadows'then continue end
				if not sameStyleValue(current[field],computed[field]) then
					if(field=="ContentVisibility"or field=="Display"or field=="TableRole")and owner and owner.SyncContentVisibility then contentOwners[owner]=true;positioningChanged=true end
					if field=='LetterSpacing'or field=='TabularNums'or field=='Font'or field=='FontSize'or field=='FontWeight'or field=='FontStyle'or field=='WordBreak'or field=='OverflowWrap'
						or field=='Hyphens'or field=='HyphenateCharacter'or field=='HyphenateLimitChars'or field=='LineBreak'then
						local textOwner=self:TextOwner(record.Node);if textOwner then spacingOwners[textOwner]=true end
					end
					if (not animationMetrics or animationMetrics=='text-shadows')and(field=='TextShadows'or field=='TextEmphasisStyle'or field=='TextEmphasisPosition'or field=='TextEmphasisColor'or field=='TextEmphasisColorAlpha')
						or animationMetrics=='colors'and(field=='TextEmphasisColor'or field=='TextEmphasisColorAlpha')then
						local textOwner=self:TextOwner(record.Node);if textOwner then effectOwners[textOwner]=true end
					end
					if field=="HyphenationLanguage"or field=='TextTransform'or field=='TextTransformLanguage'or field=='WhiteSpace'or field=='WhiteSpaceCollapse'or field=='TextWrapMode'
						or field=='TextAutospace'or field=='HangingPunctuation'or field=='Direction'or field=='UnicodeBidi'or field=='WritingMode'or field=='TextOrientation'then
						local textOwner=self:TextOwner(record.Node)
						if textOwner then
							if field=='WritingMode'or field=='TextOrientation'then bidiOwners[textOwner]=true;axisOwners[textOwner]=true
							elseif field=='Direction'then bidiOwners[textOwner]=true else regroupOwners[textOwner]=true end
						end
					end
					if not owner and (field=="Hidden" or field=="Display" or field=="Opacity") then
						local textOwner=self:TextOwner(record.Node)
						if textOwner and textOwner.CanRefreshText and textOwner:CanRefreshText() then textRefresh[textOwner]=true end
					end
					-- A transparent map can contain ordinary block and replaced
					-- children. Changing its participation must repartition its
					-- parent through the existing retained structural reconciler.
					if ElementNames.html(record.Node,'map')and(field=='Hidden'or field=='Display')then
						local parentOwner=self:TextOwner(record.Node.Parent)
						if parentOwner then regroupOwners[parentOwner]=true end
					end
					local decorationPaintOnly = field == "Decorations" and sameDecorationGeometry(current[field], computed[field])
					if field == "Decorations" then
						decorationStyles[current] = true
						if not decorationPaintOnly then decorationGeometryStyles[current]=true end
					end
					if field=='InlineBackground'or field=='InlineBackgroundAlpha'then backgroundStyles[current]=true end
					if field=='TextShadows'then
						local old,nextValue=current.TextShadows or {},computed.TextShadows or {};local geometry=#old~=#nextValue
						if not geometry then for index,value in old do local after=nextValue[index];if value.X~=after.X or value.Y~=after.Y or value.Blur~=after.Blur then geometry=true;break end end end
						if geometry then shadowGeometryStyles[current]=true end
					end
					if field == "Position" or field == "ZIndex" or field == "Hidden" then positioningChanged = true end
					if field == "Opacity" or field == "Position" or field == "ZIndex" then ownershipChanged = true end
					if field=='ContainerType'or field=='ScrollSnapType'or field=='OverflowX'or field=='OverflowY'then self.ContainerStateIndex=nil end
					current[field] = computed[field]
					if field=='Visibility'or field=='UserSelect'or field=='Hidden'then copyTextChanged=true end
					-- Viewport metadata can catch up after a resize which had no media
					-- queries/viewport units. It is not a new geometry or paint change.
					if field=="ViewportWidth" or field=="ViewportHeight" then continue end
					changed = true; affectedStyles[current]=true
					-- Custom properties feed the cascade and effects; only their
					-- changed resolved consumers need ordinary surface/text paint.
					-- SVG also has its own raw declaration/value pipeline.
					if field~='Custom'or owner and owner.ImageItem and owner.ImageItem.SVG then paintChanged=true end
					if generatedInputs[field] then generatedNeeded=true end
					local invisibleBorderColor = not borderVisible and (field == "BorderColor" or field == "BorderColorAlpha" or field == "BorderSides")
					local invisibleColumnRuleColor = (computed.ColumnRuleStyle=="none" or (computed.ColumnRuleWidth or 0)==0)
						and (field=="ColumnRuleColor" or field=="ColumnRuleColorAlpha")
					local borderColorOnly = borderPaintOnly and (field == "BorderColor" or field == "BorderColorAlpha" or field == "BorderSides" or field == "BorderSizes" or field == "BorderUniform")
					local opacityPaintOnly = field == "Opacity" and owner ~= nil
					local imageEffectPaintOnly=owner and owner.Kind=='BlockImage' and imageEffectFields[field]
					local invisibleOutlineColor = (computed.OutlineStyle == "none" or (computed.OutlineWidth or 0) == 0)
						and (field == "OutlineColor" or field == "OutlineColorAlpha")
					if field~='Custom'and not textPaintFields[field] and not invisibleBorderColor and not invisibleColumnRuleColor
						and not invisibleOutlineColor and not decorationPaintOnly then textOnly=false end
					if animationMetrics~='colors'and not paintOnlyFields[field] and not imageEffectPaintOnly and not decorationPaintOnly and not opacityPaintOnly and not invisibleBorderColor and not invisibleColumnRuleColor and not borderColorOnly then requireLayout(record) end
				end
			end
			current.InlineBackgroundSources=computed.InlineBackgroundSources
			current.AutoCursor = if (ElementNames.htmlName(record.Node) == "a" and record.Node.Attributes.href ~= nil)
				or ((ElementNames.htmlName(record.Node) == "audio" or ElementNames.htmlName(record.Node) == "video") and record.Node.Attributes.controls ~= nil)
				then "pointer" else record.Inherited.AutoCursor
			if current.RubyTextStyle and affectedStyles[current] then
				syncRubyTextStyle(current);affectedStyles[current.RubyTextStyle]=true
			end
			-- currentColor can also feed controls, markers, shadows and raster
			-- effects. Keep their general painter; plain text needs no box paint,
			-- transform resolution or SVG/image update on a color/cursor change.
			local backgroundPaint = false
			for _, layer in current.BackgroundImages or {} do if layer.Kind ~= "none" then backgroundPaint=true;break end end
			local dependentPaint = controlStyles[current] or owner and (owner.ImageItem or owner.Marker or #(current.BoxShadows or {}) > 0
				or backgroundPaint or current.BorderShape or current.BorderImageSource
				or current.ClipPath or current.MaskImage)
			if paintChanged then paintStyles[current]=true;if not textOnly or dependentPaint then boxPaintStyles[current]=true end end
		end
		local deferredRevision=self.DeferredContentRevision
		for owner in contentOwners do owner:SyncContentVisibility();layoutItems[owner]=true end
		local rebuiltContents=deferredRevision~=self.DeferredContentRevision
		if rebuiltContents then imageMapIndex:Refresh();self:RefreshLinkIndex()end
		if ensureCanvasBackground(boxPaintStyles)then changed=true end
		if self.CanvasBackgroundState and self.CanvasBackgroundState:Refresh(boxPaintStyles,backgroundStyles)then changed=true end
  if not animationMetrics then for target,reason in self:SyncSelectModes(affected)do changed=true;layoutNeeded=true;layoutItems[target]=reason;textRefresh[target]=nil end end
  local generatedAffected=table.clone(affected);for node in refreshedNodes do generatedAffected[node]=true end
  local generatedChanged=if generatedNeeded then self:GeneratedChanges(false,generatedAffected) else {}
  for node in pendingGeneratedChanges do generatedChanged[node]=true end;table.clear(pendingGeneratedChanges)
  local generatedOwners=regroupOwners
  -- Examine only affected owners after all source styles have been recascaded.
  -- Unchanged glyph modes/groups keep their native labels and measurements;
  -- necessary repartition uses the existing bounded tokenizer/reconcile path.
  for owner in spacingOwners do
   if not generatedOwners[owner]and SpacingOwners.needsRefresh(owner,WorkContext.checkpoint)then generatedOwners[owner]=true end
  end
  -- Uniform effect changes reuse the native word/frame. A merged word must
  -- be repartitioned only when one original inline source now has a distinct
  -- emphasis/shadow scope; no idle scan or animation recascade is introduced.
  if next(effectOwners)then for _,item in textItems do
   if not effectOwners[item.TextOwner]or item.Kind~='Word'then continue end
   for _,span in item.SourceSpans or {}do
    if span.SourceStyle and not InlineWords.sameTextEffects(item.Style,span.SourceStyle)then generatedOwners[item.TextOwner]=true;break end
   end
  end end
  for owner in bidiOwners do
   if not generatedOwners[owner]and not(owner.RefreshBidi and owner:RefreshBidi(axisOwners[owner]))then generatedOwners[owner]=true end
  end
  for node in generatedChanged do
   local box=nodeBoxes[node];if box then updateMarker(box,box.Style)end
   local owner=self:TextOwner(node);if owner then generatedOwners[owner]=true end
  end
  for owner in generatedOwners do
   -- Native select contents are anonymous control paint; retired rich word
   -- owners cannot tokenize them during a simultaneous mode recascade.
   if owner.SelectRenderBox and not owner.RichSelect then continue end
   changed=true;layoutNeeded=true
   if owner.CanRefreshText and owner:CanRefreshText()then owner:RefreshText(true);layoutItems[owner]='text';textRefresh[owner]=nil
   else for target,reason in self:ReconcileChildren({[owner.Node]={Children=true}})do layoutItems[target]=reason end end
  end
  if not changed then
			if not animationMetrics and tree.MotionRuntime then tree.MotionRuntime:StyleChanged({}) end
			if tree.SelectionPaintChanged then tree.SelectionPaintChanged()end
			if tree.SVGStyleChanged then tree.SVGStyleChanged(generatedAffected)end
			return false,false,layoutItems,textRefresh,affectedStyles,false
		end
		if positioningChanged then self:SyncPositioning() end
		if next(boxPaintStyles) then paintDynamic(boxPaintStyles) end
		if next(contentOwners)then
			Dialog.apply(self);Popover.apply(self)
			if self.ContentVisibilityChanged then self.ContentVisibilityChanged(rebuiltContents)end
		end
		self:PublishCanvasBackground()
		do
			-- A color-only sibling may retain its cached layout while another
			-- branch changes geometry in the same batch. Paint both kinds of edits.
			paintTextColor(paintStyles)
			if not layoutNeeded and next(shadowGeometryStyles)then
				local targets={}
				for _,run in wordRuns do for _,item in run.Items or {}do if shadowGeometryStyles[item.Style]then targets[run]=true;break end end end
				if next(targets)then tree:RepaintAnimationBounds(targets)end
			end
			for _, run in wordRuns do InlineFragments.repaint(run, paintStyles) end
			for _, run in wordRuns do
				if not run.RepaintStyles then continue end
				local needsPaint = decorationStyles[run.Style]
				local backgroundPaint=backgroundStyles[run.Style]
				local geometry = decorationGeometryStyles[run.Style]
				for _, item in run.Items do
					if decorationStyles[item.Style] or decorationStyles[item.SpaceStyle] then needsPaint = true end
					if backgroundStyles[item.Style]or backgroundStyles[item.SpaceStyle]then backgroundPaint=true end
					if decorationGeometryStyles[item.Style] or decorationGeometryStyles[item.SpaceStyle] then geometry = true end
				end
				if backgroundPaint and run.RepaintDecorations then run.RepaintDecorations()
				elseif needsPaint then
					if geometry or not run.RepaintDecorationColors then run.RepaintStyles()
					elseif not run.RepaintDecorationColors(decorationStyles) then run.RepaintDecorations() end
				end
			end
		end
		if not animationMetrics and tree.MotionRuntime then tree.MotionRuntime:StyleChanged(affected) end
		if not animationMetrics and not layoutNeeded and tree.MotionRuntime then tree.MotionRuntime:AfterLayout(refreshedNodes) end
		if not layoutNeeded and tree.SelectionPaintChanged then tree.SelectionPaintChanged(copyTextChanged)end
		if tree.SVGStyleChanged then tree.SVGStyleChanged(generatedAffected)end
		return true,layoutNeeded,layoutItems,textRefresh,affectedStyles,ownershipChanged
	end
	function tree:RefreshAnimationMetrics(box:any,overrides:any):any
		self.AnimationMetricOverrides=self.AnimationMetricOverrides or setmetatable({},{__mode='k'})
		if nodeBoxes[box.Node]~=box then
			self.AnimationMetricOverrides[box.Node]=nil
			box.AnimationMetricAuthor=nil;box.AnimationMetricsRevision=nil;box.AnimationMetricUnderlyingStyle=nil;box.AnimationMetricUnderlyingRevision=nil
			box.AnimationMetricParentSize,box.AnimationMetricParentRootSize,box.AnimationMetricParentLine=nil,nil,nil
			return {}
		end
		if sameStyleValue(self.AnimationMetricOverrides[box.Node],overrides)and box.AnimationMetricsRevision==self.AnimationStyleRevision then return {}end
		self.AnimationMetricOverrides[box.Node]=if next(overrides)then overrides else nil
		if not box.AnimationMetricAuthor then box.AnimationMetricAuthor={FontSize=box.Style.UnadjustedFontSize or box.Style.FontSize,LineHeight=box.Style.LineHeight}end
		local _,_,items=self:RefreshDOMStyles({[box.Node]=true},true,false,nil,true)
		box.AnimationMetricsRevision=self.AnimationStyleRevision
		if not next(overrides)then
			box.AnimationMetricAuthor=nil;box.AnimationMetricsRevision=nil;box.AnimationMetricUnderlyingStyle=nil;box.AnimationMetricUnderlyingRevision=nil
			box.AnimationMetricParentSize,box.AnimationMetricParentRootSize,box.AnimationMetricParentLine=nil,nil,nil
		end
		return items
	end
	function tree:RefreshAnimationTextShadows(box:any,values:any?):any
		self.AnimationTextShadowOverrides=self.AnimationTextShadowOverrides or setmetatable({},{__mode='k'})
		if nodeBoxes[box.Node]~=box then
			self.AnimationTextShadowOverrides[box.Node]=nil;box.AnimationTextShadowAuthor=nil;box.AnimationTextShadowRevision=nil;box.AnimationTextShadowInherited=nil;return {}
		end
		local parent=ShadowTree.FlatParent(box.Node)or box.Node.Parent;local inherited=parent and nodeStyles[parent]or self.Style
		local old=self.AnimationTextShadowOverrides[box.Node]
		if not old and values==nil and not box.AnimationTextShadowAuthor then return {}end
		if old and values~=nil and sameStyleValue(old.Value,values)and box.AnimationTextShadowRevision==self.AnimationStyleRevision and box.AnimationTextShadowInherited==inherited.TextShadows then return {}end
		if not box.AnimationTextShadowAuthor then box.AnimationTextShadowAuthor={Value=box.Style.TextShadows}end
		self.AnimationTextShadowOverrides[box.Node]=if values~=nil then {Value=values}else nil
		local _,_,items=self:RefreshDOMStyles({[box.Node]=true},true,false,nil,'text-shadows')
		box.AnimationTextShadowRevision=self.AnimationStyleRevision;box.AnimationTextShadowInherited=inherited.TextShadows
		if values==nil then box.AnimationTextShadowAuthor=nil;box.AnimationTextShadowRevision=nil;box.AnimationTextShadowInherited=nil end
		return items
	end
	function tree:RefreshAnimationColors(box:any,overrides:any):any
		self.AnimationColorOverrides=self.AnimationColorOverrides or setmetatable({},{__mode='k'})
		if nodeBoxes[box.Node]~=box then
			self.AnimationColorOverrides[box.Node]=nil;box.AnimationColorAuthor=nil;box.AnimationColorsRevision=nil;box.AnimationColorInherited=nil;box.AnimationColorInheritedAlpha=nil;box.AnimationColorInheritedEmphasis=nil;box.AnimationColorInheritedEmphasisAlpha=nil;box.AnimationColorInheritedSources=nil;return {}
		end
		local parent=ShadowTree.FlatParent(box.Node)or box.Node.Parent;local inherited=parent and nodeStyles[parent]or self.Style
		if sameStyleValue(self.AnimationColorOverrides[box.Node],overrides)and box.AnimationColorsRevision==self.AnimationStyleRevision
			and box.AnimationColorInherited==inherited.Color and box.AnimationColorInheritedAlpha==inherited.ColorAlpha
			and box.AnimationColorInheritedEmphasis==inherited.TextEmphasisColor and box.AnimationColorInheritedEmphasisAlpha==inherited.TextEmphasisColorAlpha
			and box.AnimationColorInheritedSources==inherited.AnimationColorSources then return {}end
		self.AnimationColorOverrides[box.Node]=if next(overrides)then overrides else nil
		if not box.AnimationColorAuthor then box.AnimationColorAuthor=AnimationColors.snapshot(box.Style)end
		local _,_,items=self:RefreshDOMStyles({[box.Node]=true},true,false,nil,'colors')
		box.AnimationColorsRevision=self.AnimationStyleRevision
		box.AnimationColorInherited,box.AnimationColorInheritedAlpha=inherited.Color,inherited.ColorAlpha
		box.AnimationColorInheritedEmphasis,box.AnimationColorInheritedEmphasisAlpha=inherited.TextEmphasisColor,inherited.TextEmphasisColorAlpha
		box.AnimationColorInheritedSources=inherited.AnimationColorSources
		if not next(overrides)then box.AnimationColorAuthor=nil;box.AnimationColorsRevision=nil;box.AnimationColorInherited=nil;box.AnimationColorInheritedAlpha=nil;box.AnimationColorInheritedEmphasis=nil;box.AnimationColorInheritedEmphasisAlpha=nil;box.AnimationColorInheritedSources=nil end
		return items
	end
	function tree:RefreshContainerSizes(): (boolean,boolean,any)
  local relevant=(rules.ContainerCount or 0)>0
  if not relevant then for _,record in styleRecords do if record.Style.UsesContainerUnits then relevant=true;break end end end
  if not relevant then for _,scoped in rulesByShadow do if(scoped.ContainerCount or 0)>0 then relevant=true;break end end end
  if not relevant then return false,false,{}end
		imageMapIndex.Cursor=nil
  local affected={}
  for _,record in styleRecords do
   if containerKeys[record.Node]~=containerKey(containerFor(record.Node))then affected[record.Node]=true end
  end
  if next(affected)==nil then return false,false,{}end
  return self:RefreshDOMStyles(affected,true,false)
 end
 function tree:HasScrollContainers(): boolean return hasScrollContainers end
 function tree:RecordRelativeScroll(node,dx,dy)
  local state={};if dx>0 then state.right=true elseif dx<0 then state.left=true end;if dy>0 then state.bottom=true elseif dy<0 then state.top=true end
  if next(state)==nil then return end
  if node then local box=self.NodeBoxes[node];if box then box.ContainerRelativeScroll=state end else self.ContainerRelativeScroll=state end
 end
 function tree:RecordUserScroll(node)
  while node do local box=self.NodeBoxes[node];if box and box.ScrollGui then box.ContainerUserScroll=true;return end;node=if node.Kind=='ShadowRoot'then node.Host else node.AssignedSlot or node.Parent end
  for _,box in self.NodeBoxes do if ElementNames.htmlName(box.Node)=='html'then box.ContainerUserScroll=true;return end end
 end
 function tree:RefreshContainerStates(root): (boolean,boolean,any)
  if not hasScrollContainers or self.LayoutInProgress or self.LayoutNeedsRecovery or not ContainerStates.snapshot(self,root)then return false,false,{}end
  return self:RefreshContainerSizes()
 end
	function tree:SetCSSState(name: string, node: any?): (boolean, boolean, any?)
		assert(name == "hover" or name == "active" or name == "focus" or name == "focus-visible" or name == "form-state" or name == "popover-open" or name == "modal"or name=='target'or name=='open'or name=='fullscreen', "Unknown CSS state")
		if self.LayoutInProgress or self.LayoutNeedsRecovery or self.PendingCSSStates then
			self.PendingCSSStates = self.PendingCSSStates or {}
			local queued = self.PendingCSSStates[name]
			local previous = if queued then queued.Node else cssStates[name]
			if previous == node then return false end
			-- A wrapper preserves queued nil (pointer/focus leaving the page).
			self.PendingCSSStates[name] = {Node = node}
			return true, not self.LayoutInProgress
		end
		if cssStates[name] == node then return false end
		local before = table.clone(cssStates)
		local after = table.clone(cssStates); after[name] = node
		local relevant, affected, generated = Stylesheet.stateChanges(rules, document, name, before, after)
		if name=='form-state'then
			-- A live value changes HTML auto-direction even without author :dir
			-- selectors. The existing queued state path handles layout recovery.
			local old,new=before[name]or{},after[name]or{}
			for target,entry in new do
				local previous=old[target]
				local oldDirection=if previous then previous.Directionality else nodeStyles[target]and nodeStyles[target].HTMLDirectionality
				if oldDirection and oldDirection~=entry.Directionality then relevant=true;affected[target]=true end
			end
		end
		if name=='hover'or name=='active'then
			-- Base controls carry UA interaction rules even without any author
			-- state selectors. Only the changed ancestor chains need recascade.
			for _,target in {before[name],after[name]}do
				while target do
					local style=nodeStyles[target]
					if style and (ElementNames.htmlName(target)=='option'and style.SelectBaseContents or ElementNames.htmlName(target)=='select'and style.Appearance=='base-select')then relevant=true;affected[target]=true end
					target=target.Parent
				end
			end
		end
		if name=="focus-visible" then
			-- The UA focus rule is present even without author state selectors.
			for _,target in {before[name],after[name]} do
				if target then relevant=true;affected[target]=true end
			end
		end
		if name=="modal" or name=="popover-open"or name=='fullscreen' then
			for changedNode in before[name] or {} do
				if not(after[name] and after[name][changedNode])then relevant=true;affected[changedNode]=true end
			end
			for changedNode in after[name] or {} do
				if not(before[name] and before[name][changedNode])then relevant=true;affected[changedNode]=true end
			end
		end
		for _, shadow in shadowRoots do
			local scoped = rulesByShadow[shadow]
			if scoped then
				local scopedRelevant, scopedAffected, scopedGenerated=Stylesheet.stateChanges(scoped, shadow, name, before, after)
				generated = generated or scopedGenerated
				if scopedRelevant then
					relevant=true
					for changedNode in scopedAffected do affected[changedNode]=true end
				end
			end
		end
		cssStates[name] = node
		if not relevant then return false end
		local changed, layoutNeeded, items,_,_,ownershipChanged = self:RefreshDOMStyles(affected, true, generated)
		if layoutNeeded or ownershipChanged then DirtyLayout.refresh(self) end
		return changed, layoutNeeded, items
	end
	function tree:FlushCSSStates(): (boolean, boolean, any?)
		if self.LayoutInProgress or self.LayoutNeedsRecovery then return false,false,{} end
		local queued = self.PendingCSSStates
		self.PendingCSSStates = nil
		local changed, layoutNeeded = false, false
		local items = {}
		for _, name in {"form-state", "popover-open", "modal", "fullscreen", "target", "open", "hover", "active", "focus", "focus-visible"} do
			local state = queued and queued[name]
			if state then
				local updated, layout, targets = self:SetCSSState(name, state.Node)
				changed, layoutNeeded = changed or updated, layoutNeeded or (updated and layout == true)
				for item in targets or {} do items[item] = true end
			end
		end
		local disclosuresChanged=self.PendingDisclosureChanges;self.PendingDisclosureChanges=nil
		local selectChanged=self.PendingRichSelectChanges;self.PendingRichSelectChanges=nil
		if selectChanged then disclosuresChanged=disclosuresChanged or{};for node,change in selectChanged do disclosuresChanged[node]=change end end
		if disclosuresChanged then
			local layout,targets=self:ApplyDOMChanges(disclosuresChanged)
			changed=true;layoutNeeded=layoutNeeded or layout
			for item,reason in targets do items[item]=reason end
		end
		return changed, layoutNeeded, items
	end
	function tree:SetMediaEnvironment(width: number, height: number, features: any?, work: (() -> boolean)?): (boolean, boolean, any)
		local environment = table.clone(mediaBase)
		for key, value in features or {} do environment[key] = value end
		environment.Width, environment.Height = math.max(0, width), math.max(0, height)
		local viewportChanged=environment.Width~=rootInherited.ViewportWidth or environment.Height~=rootInherited.ViewportHeight
		rootInherited.ViewportWidth,rootInherited.ViewportHeight=environment.Width,environment.Height
		local preferenceChanged=rootInherited.PreferredColorScheme~=(environment.PreferredColorScheme or 'light')
		rootInherited.PreferredColorScheme=environment.PreferredColorScheme or 'light'
		local relevant = Stylesheet.setMediaEnvironment(rules, environment) or (viewportChanged and tree.HasViewportUnits) or preferenceChanged
		for _, shadow in shadowRoots do
			local scoped = rulesByShadow[shadow]
			if scoped and Stylesheet.setMediaEnvironment(scoped, environment) then relevant = true end
		end
		mediaEnvironment = environment
		if relevant or viewportChanged then
			self.AnimationStyleRevision = (self.AnimationStyleRevision or 0) + 1
		end
		if not relevant then return false,false,{} end
		local mediaAffected=setmetatable({},{__mode="k"});for _,record in styleRecords do mediaAffected[record.Node]=true end
		-- Environment and DOM changes share effect/geometry classification,
		-- generated content, text refresh, control paint and retained ownership.
		local changed,layout,items,_,_,ownership=self:RefreshDOMStyles(mediaAffected,nil,nil,work)
		if ownership then DirtyLayout.refresh(self) end
		if changed then
			self.HasViewportUnits=false
			for _,record in styleRecords do if record.Style.UsesViewportUnits then self.HasViewportUnits=true;break end end
		end
		return changed,layout,items
	end
	function tree:TextOwner(node: any): any
		local current=node
  while current do local box=nodeBoxes[current];if box then return box end;current=if current.Kind=='ShadowRoot'then current.Host else ShadowTree.FlatParent(current)end
		return nil
	end
	function tree:InlineLayoutRects(node: any): any
		local owner=self:TextOwner(node);local style=nodeStyles[node]
		return if owner and style then InlineGeometry.collect(owner,node,style)else {}
	end
	function tree:SelectOwner(node: any): any
		if fragment then return nil end
		while node do if ElementNames.htmlName(node)=="select" then return node end;node=node.Parent end
		return nil
	end
	function tree:RichSelectContent(node: any): boolean
		if ElementNames.htmlName(node)=='select'then local box=nodeBoxes[node];return box and box.SelectRenderBox or false end
		local child=node
		while child and child.Parent do
			if ElementNames.htmlName(child.Parent)=='select'then
				local box=nodeBoxes[child.Parent]
				return box and box.RichSelect and (box.RichSelectList or ControlDefaults.selectButton(child))or false
			end
			child=child.Parent
		end
		return false
	end
	function tree:RefreshSelectContent(node: any): any
		local c;for _,control in controls do if control.Node==node then c=control;break end end
		if not c then return nil end
		local wasMultiple,wasList=c.SelectMultiple,c.SelectList
		local selected,known={},{}
		for index,option in c.Options do
			known[option.Node]=true
			if (c.SelectMultiple and c.SelectedIndices[index]) or (not c.SelectMultiple and c.SelectedIndex==index) then selected[option.Node]=true end
		end
		local options,defaultIndex,rows,content,defaults=SelectOptions.read(node)
		local optionsChanged=#options~=#c.Options
		if not optionsChanged then for index,option in options do if option.Node~=c.Options[index].Node then optionsChanged=true;break end end end
		local multiple=node.Attributes.multiple~=nil
		local size=math.clamp(AttributeValues.positive(node.Attributes.size,if multiple then 4 else 1),1,100)
		c.SelectMultiple,c.Multiple,c.SelectSize,c.SelectList=multiple,multiple,size,multiple or size>1
		local indices,last={},nil
		for index,option in options do
			if selected[option.Node] or (not known[option.Node] and option.Node.Attributes.selected~=nil) then indices[index]=true;if not(wasMultiple and not multiple and last)then last=index end end
		end
		c.Options,c.SelectRows,c.SelectedContent=options,rows,content;c.DefaultSelectedIndex,c.DefaultSelectedIndices=defaultIndex,defaults
		if c.SelectMultiple then SelectOptions.assignMultiple(c,indices)
		else
			if not last and c.SelectSize==1 and(optionsChanged or wasList)then for index,option in options do if not option.Disabled then last=index;break end end end
			SelectOptions.assign(c,last or 0,false)
		end
		c.ListActiveIndex=c.SelectedIndex
		ControlView.paint(c.Item)
		local _,targets=self:RefreshSelectFallback(c)
		return c.Item,targets
	end
	function tree:ValidateTextMutation(node: any)
		if Stylesheet.isMetadata(node)or MediaContent.data(node)then return end
		if self:SelectOwner(node) then return end
		local owner=self:TextOwner(node)
		assert(owner and owner.CanRefreshText and owner:CanRefreshText(),
			"textContent currently supports text/inline containers; structural or replaced content is not supported yet")
	end
	local structuralDOM=DOMReconcile.new(document,tree,{
		StyleRecords=styleRecords,WordRuns=wordRuns,SavedControlStates=savedControlStates,
		Insets=insets,Backgrounds=backgrounds,Corners=corners,
		Refresh=function(ordered)
			table.clear(retainedControls)
			for _,c in controls do retainedControls[c.Node]=c end
			table.clear(retainedReplaced)
			for _,items in {imageItems,mediaItems,iframeItems,canvasItems,svgItems} do
				for _,item in items do if item.Node then retainedReplaced[item.Node]=item end end
			end
			for _,run in wordRuns do for _,item in run.Items or {} do
				if item.Kind=="Image" and item.Node then retainedReplaced[item.Node]=item end
			end end
			for node,box in nodeBoxes do if box.ImageItem and not box.ImageItem.Control then retainedReplaced[node]=box.ImageItem end end
			reconciling=true
			local ok,message=pcall(function()
				for _,owner in ordered do owner:RefreshText(false,true) end
			end)
			reconciling=false;table.clear(retainedControls);table.clear(retainedReplaced)
			assert(ok,message)
			-- The initial tree can contain no compositors. Newly inserted opacity,
			-- mask/filter or animated surfaces need their clipping bounds fitted in
			-- the next layout just like surfaces present at the first build.
			tree.HasOpacity=tree.HasOpacity or opacity
		end,
	})
	function tree:ValidateStructure(parent: any,child: any,oldParent: any)
		structuralDOM:Validate(parent,child,oldParent)
	end
	function tree:ReconcileChildren(changes: any): any self.ContainerStateIndex=nil;return structuralDOM:Apply(changes) end
	-- Native and base appearance share the same public control and primary GUI.
	-- Only their anonymous layout contents and paint layers change participation.
	function tree:SyncSelectModes(affected: any): any
		local relevant=false;for node in affected do if ElementNames.htmlName(node)=='select'then relevant=true;break end end
		if not relevant then return {}end
		local changes={}
		for _,c in controls do
			if c.Type~='select'or not affected[c.Node]then continue end
			local node,s=c.Node,nodeStyles[c.Node];if not s then continue end
			local desired=richSelect(node,s);local box=nodeBoxes[node]
			local list=desired and (node.Attributes.multiple~=nil or AttributeValues.positive(node.Attributes.size,1)>1)
			if desired==(c.Item.RichSelect==true)and (not desired or box and box.RichSelectList==list)then continue end
			local item=c.Item
			if not box or not box.SelectRenderBox then
				if not desired then continue end
				-- The reconciler detaches the retained surface before releasing an
				-- old block-control wrapper. Inline controls need no old wrapper.
				if box then retiredSelectWrappers[node]=box end
				nodeBoxes[node]=nil
				if node.Parent then changes[node.Parent]={Children=true}end
			else
				local previousRich=c.Item.RichSelect==true
				box.RichSelect,box.RichButton=desired,desired
				item.FontFace=if resolveFont then resolveFont(s.Font,s.FontWeight,s.FontStyle)else nil
				if desired and not previousRich then
					ControlView.releaseSelectView(item)
					box.Corner=nil
					box.Kind,box.ImageItem,box.ImageStyle,box.ImageSizing=nil,nil,nil,nil
					box.PaintBackgroundGui,box.ShadowHost=nil,nil
					item.RichSelect,item.RichButton,item.BoxGui,item.Style=true,true,item.Gui,s
				elseif not desired then
					BorderBox.remove(box.InsetEdges,box.Gui);box.InsetEdges=nil
					if box.Outline then BorderBox.remove(box.Outline.Edges,box.Outline.Gui);box.Outline.Gui:Destroy();box.Outline=nil end
					if box.Corner then box.Corner:Destroy();box.Corner=nil end
					item.RichSelect,item.RichButton,item.Style=nil,nil,s
					ControlView.create(item,item.Gui,Factory,item.FontFace,radioDot,resizeGrip,corners,true)
					box.Kind,box.ImageItem='BlockImage',item
					box.PaintBackgroundGui,box.ShadowHost,box.Corner=item.BoxGui,item.BoxGui,item.Corner
					box.Gui.BackgroundTransparency=1
				end
				box:SetSelectList(list)
				item.Box,c.LayoutStyle=box,s
				changes[node]={Children=true}
				if node.Parent then changes[node.Parent]={Children=true}end
			end
		end
		if next(changes)==nil then return {}end
		return self:ReconcileChildren(changes)
	end
	function tree:RefreshSelectFallback(c: any): (boolean, any)
		local box=nodeBoxes[c.Node]
		if not box or not box.RichSelect or not box.SelectFallback then return false,{}end
		local option=c.Options[c.SelectedIndex];local caption=if option then option.Caption else ''
		if box.SelectCaption==caption then return false,{}end
		if self.LayoutInProgress or self.LayoutNeedsRecovery then
			self.PendingRichSelectChanges=self.PendingRichSelectChanges or{}
			self.PendingRichSelectChanges[c.Node]={Children=true,RenderChildren=true}
			return true,{[box]=true}
		end
		local targets=self:ReconcileChildren({[c.Node]={Children=true}})
		DirtyLayout.refresh(self)
		return true,targets
	end
	function tree:RevealSelectOption(c: any)
		local box=nodeBoxes[c.Node];local option=c.Options[c.ListActiveIndex or c.SelectedIndex]
		if not box or not box.RichSelectList or not box.ScrollGui or not option then return end
		local target=nodeBoxes[option.Node];if not target or not target.OuterHeight then return end
		local top,current=0,target
		while current and current~=box do
			top+=current.LayoutY or 0
			current=current.LayoutParent or current.Node and nodeBoxes[current.Node.Parent]
		end
		if current~=box then return end
		local edges=box.Style.BorderSizes or {0,0,0,0}
		top-=edges[1]
		local height=math.max(0,(box.OuterHeight or 0)-edges[1]-edges[3]-(box.ScrollX or 0))
		local position=box.ScrollGui.CanvasPosition;local y=position.Y
		if top<y then y=top elseif top+target.OuterHeight>y+height then y=top+target.OuterHeight-height end
		local size=box.ScrollGui.CanvasSize;local canvas=if size.Y then size.Y.Offset else size[2]or 0
		box.ScrollGui.CanvasPosition=Vector2.new(position.X,math.clamp(y,0,math.max(0,canvas-height)))
	end
	local function connected(node: any): boolean return DOMReconcile.connected(document,node) end
	local function transformRuntime()
  local transformRules={rules};for _,scoped in rulesByShadow do table.insert(transformRules,scoped) end
		return ScriptTransforms.new(tree,styleRecords,transformRules,{
			Fields=dynamicFields,Same=sameStyleValue,Matched=matched,Diagnostic=diagnostic,HasPositionedDescendant=hasPositionedDescendant,
		})
	end
	local scriptTransforms=transformRuntime()
 function tree:GetStylesheetSources(rawRoot: any?): any if fragment then return {}end;local owner=rawRoot or document;return Stylesheet.sources(owner,if owner==document then css else nil,stylesheets,self.BaseURL or baseURL)end
 local pickerBoxes=setmetatable({},{__mode='kv'})
 function tree:PickerBox(select:any):any return pickerBoxes[select]end
 function tree:ReleasePickerBox(select:any,view:any)
  if pickerBoxes[select]==view then pickerBoxes[select]=nil end
 end
 function tree:BuildPickerTree(select:any,gui:any):any
  -- The picker is an anonymous render box. Its children are original author
  -- nodes; their Parent, selectors, events and selectedness stay in the DOM.
  local pseudo={Kind='Element',Name='div',Attributes={},Children={},Parent=select,GeneratedHost=select,GeneratedPseudo='picker(select)'}
  local function sync()
   local children={};for _,child in select.Children do
    WorkContext.checkpoint();if not ControlDefaults.selectButton(child)then table.insert(children,child)end
   end
   pseudo.Children=children
  end
  sync()
  local constraints={AnchorWidth=0,MaxHeight=100000}
  local function rootStyle()
   local result=table.clone(resolvePseudo(select,nodeStyles[select]or counterStyleFor(select),'picker(select)',nil,true))
   if not constraints.Positioned then
    for _,field in {'MinWidth','MinHeight'}do if result[field]and result[field].PickerAnchor then result[field]={Value=constraints.AnchorWidth}end end
    for _,field in {'MaxWidth','MaxHeight'}do if result[field]and result[field].PickerStretch then result[field]={Value=constraints.MaxHeight}end end
   end
   result.SelectBaseContents=true;return result
  end
  local view=RenderTree.build(document,gui,diagnostic,resolveFont,patterns,insets,resolveImage,nil,defaultFont,corners,radioDot,resizeGrip,nil,baseURL,mediaResolver,mediaEnvironment,backgrounds,disclosureIcons,resolveSVG,
   {Node=pseudo,ResolveRoot=rootStyle,Inherited=nodeStyles[select]or counterStyleFor(select),Match=function(n,starting)return if n==pseudo then {}else matched(n,starting)end,Rules=rules,
    Pseudo=function(n,s,name,target,force)return resolvePseudo(n,s,name,target,force,true)end})
  function view:SyncPickerChildren()sync()end
  view.PickerConstraints=constraints
  view.PickerOwner=select
  -- SelectPopup already owns this top-layer surface. The regular fixed-box
  -- painter must not reparent its root into another anonymous viewport layer.
  view.TopLayerActive=true
  pickerBoxes[select]=view
  return view
 end
	function tree:AnimationDeclarations(node: any): any return matched(node) end
 function tree:StartingStyle(node:any):any
  if not hasStartingStyles then return nil end
  local parent=ShadowTree.FlatParent(node)
  local result=Style.resolve(node,nodeStyles[parent]or self.Style,function()end,false,matched(node,true))
  result.Node=node;return result
 end
 function tree:AnimationKeyframes(node:any):any return (shadowRuleSets[node]or hostRuleSets[node]or rules).Keyframes end
 function tree:ComputedElementStyle(node:any):any
  return counterStyleFor(node)
 end
 function tree:PseudoStyle(node:any,name:string):any
  return resolvePseudo(node,nodeStyles[node]or counterStyleFor(node)or self.Style,name,nil,true,nil,name=='picker(select)'and pickerBoxes[node]==nil)
 end
 function tree:HighlightStyle(node:any,name:string,inherited:any):any
  return resolvePseudo(node,inherited,name,nil,false)
 end
	function tree:SetStylesheetProvider(provider: any) stylesheetProvider=provider end
	local sourceSnapshot=tree:GetStylesheetSources()
	local function sameSources(nextSources)
		if #sourceSnapshot~=#nextSources then return false end
		for index,source in nextSources do
			local old=sourceSnapshot[index]
			if old.Node~=source.Node or old.Source~=source.Source or old.Media~=source.Media or old.Disabled~=source.Disabled or old.Href~=source.Href then return false end
		end
		return true
	end
	local renderChildren=setmetatable({},{__mode="k"})
 local function childrenOf(node)
		-- Luau weak keys are not ephemerons: a strong child would retain its
		-- parent/key through Parent after that subtree leaves the document.
		local result=setmetatable({},{__mode="v"})
  for _,child in ShadowTree.FlatChildren(node) do
			if child.Kind~="Comment" and not Stylesheet.isMetadata(child) then table.insert(result,child) end
		end
		return result
	end

	local function snapshot(node)
		local pending={node}
		while #pending>0 do
			local current=table.remove(pending);renderChildren[current]=childrenOf(current)
			if not Stylesheet.isMetadata(current) then for _,child in current.Children do table.insert(pending,child) end end
		end
	end
	snapshot(if fragment then fragment.Node else document)
	local function stylesheetChanges(changes)
		local content,recompile,scan={},false,false
		local selectorChanges={}
		local snapshots={}
		for node,change in changes do
			-- Stylesheet invalidation and ordinary DOM structure can share the
			-- document record (for example replacing a root containing a style).
			-- Recompile its sheets without discarding that structural mutation.
			if change.Stylesheet then recompile=true;scan=true end
			if Stylesheet.isMetadata(node) then
				scan=true
				-- Metadata can still affect relational selectors or :empty outside
				-- its own non-rendered subtree, even when its CSS source is unchanged.
				if change.Attributes or change.Text or change.Children then content[node]={StylesheetMetadata=true,Attributes=change.Attributes};selectorChanges[node]=content[node] end
			else
				local filtered=change
				if MediaContent.data(node)then
					-- Replaced media consumes source/track/fallback descendants as
					-- resource data. It has no ordinary child/text render owner.
					-- Keep a cascade marker for :has/:empty and source attributes;
					-- AudioElements retains the original DOM mutation/selection path.
					filtered=table.clone(change);filtered.Children=nil;filtered.Text=nil;filtered.RenderChildren=nil;filtered.MediaData=true
					-- Added fallback style/link nodes still enter the connected CSS
					-- source list, independently of their lack of presentation.
					scan=scan or change.Children==true
				elseif change.Children then
					scan=true
					local before,after=renderChildren[node],childrenOf(node)
     local same=not change.RenderChildren and not node.InternalShadowRoot and ElementNames.htmlName(node)~="slot"and before~=nil and #before==#after
					if same then for index,child in after do if before[index]~=child then same=false;break end end end
					if same then filtered=table.clone(change);filtered.Children=nil end
					table.insert(snapshots,node)
				end
				if next(filtered)then content[node]=filtered;selectorChanges[node]=if filtered.MediaData then change else filtered end
			end
		end
		-- A parent snapshot also includes its descendants. Compare the entire
		-- mutation batch first, so parent-first iteration cannot conceal a
		-- concurrent child edit from structural reconciliation.
		for _,node in snapshots do snapshot(node) end
		if scan then
			local sources=tree:GetStylesheetSources();recompile=recompile or not sameSources(sources);sourceSnapshot=sources
		end
		return content,recompile,selectorChanges
	end
 local function compileStylesheets()
		local compiled=Stylesheet.collect(document,diagnostic,css,stylesheets,tree.BaseURL or baseURL,stylesheetProvider)
		Stylesheet.setMediaEnvironment(compiled,mediaEnvironment)
		-- CSS motion and selector accelerators hold this rule-set identity.
		local keyframes=rules.Keyframes
		table.clear(keyframes);for key,value in compiled.Keyframes do keyframes[key]=value end
		table.clear(rules);for key,value in compiled do rules[key]=value end;rules.Keyframes=keyframes
		Stylesheet.invalidate(rules)
  refreshShadowScopes()
		scriptTransforms=transformRuntime()
		tree.HasMediaQueries=(rules.MediaCount or 0)>0
		if not tree.HasMediaQueries then for _,scoped in rulesByShadow do if (scoped.MediaCount or 0)>0 then tree.HasMediaQueries=true;break end end end
	end
	local structuralResources=StructuralResources.new(document,{Images=imageItems,SVG=svgItems,Canvas=canvasItems,Media=mediaItems,IFrames=iframeItems})
	local transformItems
	local function transformIndex(): any
		if not transformItems then
			transformItems={}
			for _,run in wordRuns do for _,item in run.Items or{}do
				if item.Kind=='Image'and not item.InlineBox then
					local target=item.Node or item.Control and item.Control.Node
					if target then transformItems[target]=item end
				end
			end end
		end
		return transformItems
	end
	function tree:TransformBox(node: any): any?
		local box=nodeBoxes[node];if box then return box end
		local item=transformIndex()[node];return item and item.GeometryBox
	end
	function tree:TransformBoxes(): any
		local targets=table.clone(nodeBoxes)
		-- Reuse the same lazy index and exclude undrawn/audio-without-controls
		-- items. This registry is paint ownership, never a second layout tree.
		for target,item in transformIndex()do if item.GeometryBox and not targets[target]then targets[target]=item.GeometryBox end end
		return targets
	end
	function tree:TakeStructuralResourceChanges(): any return structuralResources:Take() end
	function tree:FindImageItem(node: any): any
		local box=nodeBoxes[node];if box and box.ImageItem and box.ImageItem.Node==node then return box.ImageItem end
		for _,run in wordRuns do for _,item in run.Items or{}do if item.Kind=="Image"and item.Node==node then return item end end end
		return nil
	end
	function tree:SetVideoPoster(item: any,data: any?): boolean
		if self.MediaByNode[item.Node]~=item or item.MediaKind~='video'then return false end
		local previous=item.PosterSVGItem
		if previous then local at=table.find(svgItems,previous);if at then table.remove(svgItems,at)end end
		item.Poster,item.PosterSVG,item.PosterSVGItem=nil,nil,nil
		item.PosterReady=data~=nil
		item.PosterWidth,item.PosterHeight=if data then data.Width else nil,if data then data.Height else nil
		if data and data.SVG then
			item.PosterSVG=data.SVG
			item.PosterSVGItem={SVG=data.SVG,Style=item.Style,Node=item.Node,ImageGui=item.PosterGui}
			table.insert(svgItems,item.PosterSVGItem)
		elseif data then item.Poster=data.Source end
		item.PosterGui.Image=item.Poster or ''
		if Content then pcall(function()item.PosterGui.ImageContent=Content.fromUri(item.Poster or '')end)end
		return MediaBox.natural(item)
	end
	-- The before hook cancels native registrations while their old Source and
	-- SVG identity are still intact. Source and surface updates then retain the
	-- original item, CSS box, mouse target and unaffected neighboring content.
	function tree:RefreshMediaResource(node: any,attributes: any,sourceSet: boolean?): any
		if not ElementNames.html(node,"video")then return nil end
		local item=self.MediaByNode[node];if not item then return nil end
		if attributes.controls then
			item.Controls=node.Attributes.controls~=nil
			MediaBox.ensureControls(item,Factory)
			-- The runtime owns the retained fullscreen overlay dimensions. Avoid
			-- a temporary normal-size surface/poster update before its refresh.
			if not item.Fullscreen and item.ContentWidth and item.ContentHeight then MediaBox.arrange(item)else MediaBox.paint(item)end
		end
		-- Removing src does not invoke the media load algorithm. A present src,
		-- even empty or identical to its previous value, selects a new generation.
		if not item.VideoSelection and attributes.src and(sourceSet or node.Attributes.src~=nil)then
			item.SelectedSource=node.Attributes.src or ""
			item.Source=if node.Attributes.src~=nil then(mediaResolver or MediaSources.new()):Asset("video",item.SelectedSource)else nil
		end
		return item
	end
	function tree:RefreshImageResource(node: any,before: any?): (any,string?,boolean,boolean)
		if ElementNames.htmlName(node)~="img" and not(ElementNames.htmlName(node)=="input" and ControlDefaults.kind(node)=="image")then return nil,nil,false,false end
		local item=self:FindImageItem(node);if not item then return nil,nil,false,false end
		local selected,density,dimensionSource=selectedImage(node)
		local oldKind=if item.SVG then"SVG"elseif item.Source then"Image"else"Empty"
		local changed=selected~=item.SelectedSource
		local densityChanged=density~=item.SourceDensity
		local source,sourceSVG=item.Source,item.SVG
		if changed then
			source=resolveImage and resolveImage(selected)or nil
			sourceSVG=if not source and resolveSVG then resolveSVG(selected)else nil
			if before then before(item,oldKind)end
			item.SelectedSource,item.Source,item.SVG,item.SVGExternal=selected,source,sourceSVG,sourceSVG~=nil
			item.SourceDensity=density
			item.LoadFailed,item.FilterReady,item.BlurReady,item.BlurKey=nil,nil,nil,nil
			if item.BlurGui then item.BlurGui.Visible=false end
			item.IntrinsicWidth,item.IntrinsicHeight=nil,nil
			item.PixelWidth,item.PixelHeight=nil,nil
			if sourceSVG then
				local width,height=require(script.Parent.Parent.SVG.Sizing).source(sourceSVG)
				item.PixelWidth,item.PixelHeight=width,height
				item.IntrinsicWidth,item.IntrinsicHeight=ResponsiveSources.intrinsicSize(width,height,density)
			end
			for _,list in {imageItems,svgItems}do local index=table.find(list,item);if index then table.remove(list,index)end end
			if source then table.insert(imageItems,item)elseif sourceSVG then table.insert(svgItems,item)end
		end
		if not changed and densityChanged then
			-- Density-only changes preserve the native texture and its shared
			-- decoded pixels; only the per-element intrinsic geometry changes.
			local state=node.ImageResourceState
			if state and state.Status=="loaded"then
				item.PixelWidth,item.PixelHeight=state.PixelWidth,state.PixelHeight
				item.IntrinsicWidth,item.IntrinsicHeight=state.Width,state.Height
			elseif sourceSVG then
				local width,height=require(script.Parent.Parent.SVG.Sizing).source(sourceSVG)
				item.PixelWidth,item.PixelHeight=width,height
				item.IntrinsicWidth,item.IntrinsicHeight=ResponsiveSources.intrinsicSize(width,height,density)
			else item.IntrinsicWidth,item.IntrinsicHeight=ResponsiveSources.intrinsicSize(item.PixelWidth,item.PixelHeight,density)end
			item.SourceDensity=density
		end
		local w,h=imageDimension(dimensionSource.Attributes.width),imageDimension(dimensionSource.Attributes.height)
		local alt=node.Attributes.alt or"";local empty=node.Attributes.alt==""
		local fallback=ImageFallback.broken(item)and alt~=""
		local altGeometry=(item.TextFallback or fallback)and(alt~=item.Alt or empty~=item.EmptyAlt)
		local dimensionsChanged=w~=item.AttributeWidth or h~=item.AttributeHeight
		local geometry=changed or densityChanged or dimensionsChanged or altGeometry or fallback~=(item.TextFallback==true)
		item.AttributeWidth,item.AttributeHeight,item.Alt,item.EmptyAlt=w,h,alt,empty
		if dimensionsChanged and ElementNames.html(node.Parent,"picture")then self:RefreshDOMStyles({[node]=true},true)end
		item.TextFallback=fallback
		ImageBox.refreshResource(item,changed)
		return item,oldKind,changed,geometry
	end
	function tree:PruneStructuralResources(retained:any?)
		transformItems=nil
		structuralResources:Prune(self.StructuralResourcesRemoving,retained)
		Dialog.apply(self);Popover.apply(self)
		table.clear(self.MediaByNode)
		for _,item in mediaItems do self.MediaByNode[item.Node]=item end
		for node,item in imageMapItems do if not DOMReconcile.connected(document,node)or retained and not retained[item]then imageMapItems[node]=nil;item.ImageMap=nil;item.ImageNode=nil end end
	end
	function tree:SyncTopLayerResources(): any
		local targets={}
		-- Removing the attribute returns the original native box to its normal
		-- parent before pruning the old popover registry entry.
		for node,state in popoversByNode do
			local box=state.Box
			if node.Attributes.popover==nil and ElementNames.htmlName(node)~="dialog" and nodeBoxes[node]==box then
				local outer=if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui
				box.TopLayer=nil;outer.Parent=box.TopLayerParent or root;box.TopLayerParent=nil
				box.TopLayerActive,box.LayoutAsTopLayer,box.TopLayerHidden=false,false,false
				box.TopLayerPaintX,box.TopLayerPaintY=nil,nil
				outer.Visible=not box.Style.Hidden;targets[box]=true
			end
		end
		Dialog.prune(self);Popover.prune(self)
		for node,box in nodeBoxes do
			if ElementNames.htmlName(node)=="dialog"then
				local state=self.DialogsByNode[node]
				if not state then
					dialogHost=dialogHost or Dialog.host(root,Factory);self.DialogHost=dialogHost
					box.TopLayerParent=box.TopLayerParent or (if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui).Parent;state=Dialog.new(node,box,dialogHost)
					state.BackdropStyle=resolvePseudo(node,box.Style,"backdrop")
					table.insert(dialogs,state);dialogsByNode[node]=state;targets[box]=true
					Dialog.attachViewport(self,root)
				end
			end
			if node.Attributes and node.Attributes.popover~=nil then
				local state=self.PopoversByNode[node]
				if not state then
					popoverHost=popoverHost or Popover.host(root,Factory);self.PopoverHost=popoverHost
					box.TopLayerParent=box.TopLayerParent or (if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui).Parent;state=Popover.new(node,box,popoverHost)
					table.insert(popovers,state);popoversByNode[node]=state;targets[box]=true
					Popover.attachViewport(self,root)
				end

			end
		end
		if next(targets)then self:SyncPositioning();DirtyLayout.refresh(self)end
		Dialog.apply(self);Popover.apply(self)
		return targets
	end
 function tree:ApplyDOMChanges(changes: any): (boolean, any, boolean?)
  self.ContainerStateIndex=nil
  assert(not self.LayoutInProgress,"DOM rendering waits for the current layout job")
  local imageMapsChanged=imageMapIndex:Prepare(changes)
		imageMapIndex.Cursor=nil
  local linksChanged=imageMapsChanged
  for node,change in changes do if change.Attributes and change.Attributes.href and(ElementNames.html(node,'area')or ElementNames.html(node,'a'))then linksChanged=true end end
  for node,change in changes do
   if (ElementNames.htmlName(node)=='option'or ElementNames.htmlName(node)=='optgroup')and change.Attributes and change.Attributes.label and self:RichSelectContent(node)then change.Children=true;change.RenderChildren=true end
  end
  local shadowChanged=false
  for node,change in changes do
   -- Styles/classes/text do not change slot ownership or stylesheet scopes.
   -- Only structure and assignment inputs require rediscovery/distribution.
   local attributes=change.Attributes
   if change.Children and not change.ImageMapData or attributes and(attributes.slot or ElementNames.htmlName(node)=='slot'and attributes.name)then shadowChanged=true;break end
  end
  if shadowChanged then
   for slot in refreshShadowScopes()do local entry=changes[slot]or{};changes[slot]=entry;entry.Children=true end
  end
		local recompile,selectorChanges
		changes,recompile,selectorChanges=stylesheetChanges(changes)
		if recompile then compileStylesheets() end
		local mediaData=false;for _,change in changes do if change.MediaData then mediaData=true;break end end
		if not recompile and not mediaData and scriptTransforms:Try(changes) then return false,{},true end
  scriptTransforms:Invalidate()
  -- Type is a live form-control configuration, not an author subtree edit.
  -- Retain the public hit surface while reconciling its anonymous widget and
  -- its participation in the existing inline/block renderer.
  local inputParents={}
  table.clear(controlReconcileStyles)
  for node,change in changes do
   if ElementNames.htmlName(node)~='input'or MediaContent.contents(node)or not(change.Attributes and change.Attributes.type)then continue end
   local c;for _,candidate in controls do if candidate.Node==node then c=candidate;break end end
   if c and c.Item.ViewType~=c.Type then
    local item=c.Item
    -- The full cascade below still owns style identity, animation and paint
    -- invalidation. Preview the same cascade only to decide whether this
    -- retained widget belongs to its refreshed parent's inline/block flow.
    for _,record in styleRecords do if record.Node==node then controlReconcileStyles[node]=recascade(record);break end end
    if self.BeforeInputViewChange then self.BeforeInputViewChange(c)end
    -- Anonymous font targets do not survive replacement even though the
    -- public hit surface does. Drop these references before destroying it.
    for index=#fontTargets,1,-1 do
     local current=fontTargets[index]
     while current and current~=item.Gui do current=current.Parent end
     if current==item.Gui then table.remove(fontTargets,index)end
    end
    local removals={Images={},SVG={}}
    for _,entry in {{imageItems,removals.Images},{svgItems,removals.SVG}}do
     local index=table.find(entry[1],item);if index then table.remove(entry[1],index);table.insert(entry[2],item)end
    end
    if self.StructuralResourcesRemoving then self.StructuralResourcesRemoving(removals)end
    item.SelectedSource,item.Source,item.SVG,item.SVGExternal,item.AttributeWidth,item.AttributeHeight,item.Alt,item.EmptyAlt=nil,nil,nil,nil,nil,nil,nil,nil
    item.Node=if c.Type=='image'then node else nil
    if c.Type=='image'then
     item.SelectedSource=node.Attributes.src or'';item.Source=resolveImage and resolveImage(item.SelectedSource)
     item.SVG=not item.Source and resolveSVG and resolveSVG(item.SelectedSource)or nil;item.SVGExternal=item.SVG~=nil
     item.Alt,item.EmptyAlt=node.Attributes.alt or'Submit',false
     item.AttributeWidth,item.AttributeHeight=imageDimension(node.Attributes.width),imageDimension(node.Attributes.height)
    end
    ControlView.syncInput(item)
    if c.Type=='image'then
     item.IntrinsicWidth,item.IntrinsicHeight=item.AttributeWidth,item.AttributeHeight
     if item.SVG then item.IntrinsicWidth,item.IntrinsicHeight=require(script.Parent.Parent.SVG.Sizing).source(item.SVG)end
     if item.Source then table.insert(imageItems,item)elseif item.SVG then table.insert(svgItems,item)end
    end
    if node.Parent then inputParents[node.Parent]=true end
   elseif not c and node.Parent then
    -- An initially hidden input has no native widget yet. The existing
    -- renderer must create one if its new type participates in layout.
    inputParents[node.Parent]=true
   end
  end
  for parent in inputParents do local change=changes[parent]or{};changes[parent]=change;change.Children=true;change.RenderChildren=true;selectorChanges[parent]=change end
  local hasStructure=false;for _,change in changes do if change.Children then hasStructure=true;break end end
  if hasStructure then pendingGeneratedChanges=self:GeneratedChanges(true)end
  local structuralTargets=self:ReconcileChildren(changes)
  table.clear(controlReconcileStyles)
		local disclosureTargets={}
		for node,change in changes do
			local disclosure=disclosures[node]
			if disclosure and change.Attributes and change.Attributes.open then
				local open=node.Attributes.open~=nil
				if disclosure.Open~=open then
					disclosure.Open=open;Disclosure.apply(disclosure)
					disclosureTargets[disclosure.Box]=true
				end
			end
		end
		-- Selectors can affect descendants, siblings and :has ancestors.
		-- Inline style writes are local unless an attribute selector reads style.
		local affected=if recompile then nil else scriptTransforms:Scope(selectorChanges,true)
		if not affected then
			affected={};for _,record in styleRecords do affected[record.Node]=true end
		end
		for box in disclosureTargets do local disclosure=disclosures[box.Node];if disclosure then affected[disclosure.SummaryNode]=true end end
  local stylesChanged,needsLayout,items,refresh,changedStyles,ownershipChanged=self:RefreshDOMStyles(affected)
		for box in disclosureTargets do items[box]=true;needsLayout=true end
		local tablesToRefresh,tableModels={},{}
		local function touchTable(node,model)
			while node do
				local box=nodeBoxes[node]
				while box do
					if box.Style.TableRole=="table"and box.RefreshTable then tablesToRefresh[box]=true;if model then tableModels[box]=true end end
					box=box.LayoutParent
				end
				node=node.Parent
			end
		end
		for node,change in changes do
			local attrs=change.Attributes
			if attrs and (attrs.colspan or attrs.rowspan or attrs.span)then
				touchTable(node,true)
			end
		end
		-- Selector scope can include the whole page while only another card
		-- changes. Rebuild table models only for styles which actually changed.
		if stylesChanged then for node,style in nodeStyles do
			if style and style.TableRole and changedStyles[style] then touchTable(node)end
		end end
		local tableLayoutTargets={}
		for target in items do
			local owner=if self.DirtyContext then self.DirtyContext.Owners[target] or target else target
			while owner do
				if owner.Style and owner.Style.TableRole=="table"then tableLayoutTargets[owner]=true end
				owner=owner.LayoutParent
			end
		end
		for box in tablesToRefresh do
			local paintOnly=not tableLayoutTargets[box]and not tableModels[box]and not structuralTargets[box]
			box:RefreshTable(paintOnly)
			if not paintOnly then
				needsLayout=true
				-- Rebuilding tracks after a row/cell edit does not invalidate every
				-- retained cell. Keep narrower geometry targets from the cascade;
				-- a genuine change to the table itself already has a broad target.
				if not items[box] then items[box]=structuralTargets[box] or true end
			end
		end
		local topLayerResources=false
		for _,change in changes do if change.Children and not change.ImageMapData or (change.Attributes and change.Attributes.popover)then topLayerResources=true;break end end
		if topLayerResources then
			for box in self:SyncTopLayerResources()do items[box]=true;needsLayout=true end
		end
		local selectChanges={}
		for node,change in changes do
			if change.Text or change.Children or change.Attributes then local select=self:SelectOwner(node);if select then selectChanges[select]=true end end
		end
		for node in selectChanges do
			local item,targets=self:RefreshSelectContent(node)
			if item then items[item]=true;if not item.RichSelect then needsLayout=true end end
			for target,reason in targets or{}do items[target]=reason;needsLayout=true end
		end
		for owner,reason in structuralTargets do
			needsLayout=true
			if not items[owner] then items[owner]=reason end
			refresh[owner]=nil
		end
		-- Geometry-changing CSS in the same batch can change the available width.
		local allowLocalTextLayout = not needsLayout
		for node,change in changes do
			local owner=self:TextOwner(node)
			if change.Text and not change.MediaData and not change.NativeControlText and connected(node) and not structuralTargets[owner] and (not self:SelectOwner(node)or self:RichSelectContent(node)) then
				if owner and owner.CanRefreshText and owner:CanRefreshText() then refresh[owner]=true end
			end
		end
		for owner in refresh do
			owner:RefreshText(allowLocalTextLayout);needsLayout=true
			items[owner]=if allowLocalTextLayout then "text" else true
		end
		local order=0
		local function visitOrder(box)
			if box.Kind=="Words" then
				for _,item in box.Items do
					order+=1;item.SelectionOrder=order
					for _,fragment in item.WrapPool or {} do fragment.SelectionOrder=order end
				end
			end
			for _,child in box.AllChildren or box.Children or {} do visitOrder(child) end
		end
		if next(refresh) or next(structuralTargets) then visitOrder(self) end
		if next(refresh) or next(structuralTargets) or ownershipChanged or stylesChanged and needsLayout then DirtyLayout.refresh(self) end
		if next(structuralTargets) or stylesChanged then
			self.HasViewportUnits=false
			for _,record in styleRecords do if record.Style.UsesViewportUnits then self.HasViewportUnits=true;break end end
		end
		-- Opening/closing a disclosure already invalidates its whole retained
		-- subtree. Its UA summary marker can also change style in this batch;
		-- scheduling those covered descendants again creates duplicate passes.
		for item in items do
			if not disclosureTargets[item]then
				local owner=if self.DirtyContext then self.DirtyContext.Owners[item]or item else item
				local ancestor=owner
				while ancestor do
					if disclosureTargets[ancestor]then items[item]=nil;break end
					ancestor=ancestor.LayoutParent
				end
			end
		end
		if imageMapsChanged then imageMapIndex:Refresh(true)end
		if linksChanged then self:RefreshLinkIndex()end
		return needsLayout,items
	end
	function tree:CanKeepTextLayout(box: any, arrange: any, alive: () -> boolean): boolean
		return TextMutation.canKeepLayout(box,arrange,alive)
	end
	tree.HasMediaQueries = (rules.MediaCount or 0) > 0
	if not tree.HasMediaQueries then for _, shadow in shadowRoots do if (rulesByShadow[shadow].MediaCount or 0) > 0 then tree.HasMediaQueries=true; break end end end
	tree.HasViewportUnits=false
	for _,record in styleRecords do if record.Style.UsesViewportUnits then tree.HasViewportUnits=true;break end end
	tree:SyncPositioning()
	if buildingCleanup then buildingCleanup:Disconnect()end
	return tree
end

return RenderTree
