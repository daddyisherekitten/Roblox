--!strict
local Events=require(script.Parent.Events)
local HitTest=require(script.Parent.HitTest)
local FormModel=require(script.Parent.Parent.Controls.FormModel)
local SelectOptions=require(script.Parent.Parent.Controls.SelectOptions)
local View=require(script.Parent.Parent.Controls.View)
local DOM=require(script.Parent.Parent.DOM.Node)
local SelectPopup=require(script.Parent.SelectPopup)
local PickerFragments=require(script.Parent.Parent.Rendering.PickerFragments)
local TemporalPopup=require(script.Parent.TemporalPopup)
local ColorPopup=require(script.Parent.ColorPopup)
local Temporal=require(script.Parent.Parent.Controls.TemporalValue)
local TemporalEdit=require(script.Parent.Parent.Controls.TemporalEdit)
local RangeDrag=require(script.Parent.RangeDrag)
local RangeValue=require(script.Parent.Parent.Controls.RangeValue)
local NumberView=require(script.Parent.Parent.Controls.NumberView)
local GaugeView=require(script.Parent.Parent.Controls.GaugeView)
local TextareaResize=require(script.Parent.TextareaResize)
local TextSelection=require(script.Parent.TextSelection)
local ControlSelection=require(script.Parent.Parent.Controls.TextSelection)
local ValidationPopup=require(script.Parent.ValidationPopup)
local Disclosure=require(script.Parent.Parent.Rendering.Disclosure)
local DetailsState=require(script.Parent.Parent.DOM.DetailsState)
local SelectedContent=require(script.Parent.Parent.HTML.SelectedContent)
local WorkContext=require(script.Parent.Parent.WorkContext)
local CursorController=require(script.Parent.CursorController)
local Links=require(script.Parent.Links)
local ImageMap=require(script.Parent.ImageMap)
local MediaRuntime=require(script.Parent.MediaRuntime)
local MediaBox=require(script.Parent.Parent.Rendering.MediaBox)
local Dialog=require(script.Parent.Parent.Rendering.Dialog)
local Popover=require(script.Parent.Parent.Rendering.Popover)
local ScrollLayout=require(script.Parent.Parent.Layout.ScrollLayout)
local EventData=require(script.Parent.EventData)
local PointerCapture=require(script.Parent.PointerCapture)
local NativeTextEdit=require(script.Parent.NativeTextEdit)
local NativeContentEditable=require(script.Parent.NativeContentEditable)
local NativeSelectionCopy=require(script.Parent.NativeSelectionCopy)
local ScriptSelection=require(script.Parent.Parent.Rendering.ScriptSelection)
local ContentEditing=require(script.Parent.Parent.JavaScript.Editing)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local Directionality=require(script.Parent.Parent.CSS.Directionality)
local function inclusiveParent(node)return node.Parent or (if node.Kind=="ShadowRoot"then node.Host else nil)end
local Controller={}
function Controller.start(page: any,tree: any,requestLayout: any,diagnostic: any,services: any?): any
	local input=if services and services.Input then services.Input else game:GetService("UserInputService")
	local playerGui=if services and services.PlayerGui then services.PlayerGui else game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local taskAPI=if services and services.Task then services.Task else task
	local eventData=EventData.new(page,input)
	local compatibilitySuppressed=false
	if not page.Alive then return nil end
	local cursor=CursorController.start(page,tree,input,playerGui)
	local connections,alive,writing={},true,false
	local suppressDatalistOpen=false
	local gaugeCleanups={}
	local boundControls={}
	local events=Events.new(diagnostic)
	page.Events=events
	local nativeDetails,nativeDetailChanges
	local function detailsAttribute(node,key,value)
		local old=node.Attributes[key];node.Attributes[key]=value
		if nativeDetailChanges then nativeDetailChanges[node]={Attributes={[key]=true}}end
		nativeDetails:AttributeChanged(node,key,value,old)
	end
	nativeDetails=DetailsState.new({Attribute=detailsAttribute})
	nativeDetails:Start(page.Document,{
		QueueTask=if taskAPI then function(callback)return taskAPI.defer(callback)end else nil,
		CancelTask=function(handle)if handle and taskAPI.cancel then pcall(taskAPI.cancel,handle)end end,
		Fire=function(node,old,new)if alive and page.Alive then
			events:Emit(node,"toggle",{oldState=old,newState=new,isTrusted=true},{Bubbles=false,Cancelable=false})
		end end,
	})
	local captures=PointerCapture.new(page.Document,function(node,kind,data,options)return events:Emit(node,kind,data,options)end)
	page.PointerCapture=captures
	local editHint
	local blockedEdit,blockedKey
	local auxiliaryPresses={}
	local media=MediaRuntime.start(page,tree,events,diagnostic,services)
	local function connect(signal: any,fn: any) table.insert(connections,signal:Connect(fn)) end
	local popup,temporalPopup,colorPopup
	local colorPickerKeys={}
	local validation=ValidationPopup.new(page,services)
	local formStates={}
	local model
	local function applyCSSState(name: string, state: any)
		if not tree.SetCSSState then return end
		local changed, layoutNeeded, items = tree:SetCSSState(name, state)
		if changed and layoutNeeded ~= false then
			if items and next(items) then
				for item in items do requestLayout(true,item) end
			else requestLayout(true) end
		end
	end
	function page:SetControlPickerOpen(c:any,open:boolean)
		if not alive or not self.Alive then return end
		if open then applyCSSState('open',c.Node)
		elseif tree.CSSStates and tree.CSSStates.open==c.Node then applyCSSState('open',nil)end
		if not open and model and model.TopLayerFocusedNode then
			local option=model.TopLayerFocusedNode;local parent=option
			while parent and parent~=c.Node do parent=parent.Parent end
			if parent==c.Node then
				model.TopLayerFocusedNode=nil;applyCSSState('focus',nil);applyCSSState('focus-visible',nil)
				events:Emit(option,'blur',nil,{Bubbles=false,Cancelable=false})
				if alive and self.Alive and model.Focus then model:Focus(c)end
			end
		end
	end
	local function formSnapshot(c: any): any
		local selectedOptions
		local realm=page.JavaScriptRuntime
		local name=c.Node.Name
		local validity
		if name=='input'or name=='textarea'or name=='select'or name=='button'then
			validity=if realm and realm.DOM and realm.DOM.Controls then realm.DOM.Controls:Validity(c.Node)elseif model then model:Validity(c)else nil
		end
		if c.Type=='select'then
			selectedOptions={}
			for i,option in c.Options do
				if (if c.Multiple then c.SelectedIndices[i]else i==c.SelectedIndex)then selectedOptions[option.Node]=true end
			end
		end
		return {Type=c.Type,Value=c.Value,Directionality=Directionality.of(c.Node),Checked=c.Checked,Indeterminate=c.Indeterminate,DOMCustomValidity=c.DOMCustomValidity,Validity=validity,Disabled=c.Disabled,ReadOnly=c.ReadOnly,Required=c.Required,
			UserEdited=c.UserEdited,UserInvalid=c.UserInvalid,BadInput=c.BadInput,Number=c.Number,Range=c.Range,Multiple=c.Multiple,
			MinLength=c.MinLength,Options=c.Options,SelectedOptions=selectedOptions,SelectedIndex=c.SelectedIndex,SelectList=c.SelectList,Temporal=c.Temporal}
	end
	model=FormModel.new(page.Document,tree.Controls,events,function(c: any,layout: boolean)
		if not alive or not page.Alive then return end
		if c.Type=='select'and not c.UpdateSelectedContent then
			local option=c.Options[c.SelectedIndex];local changes={}
			SelectedContent.update(c.Node,option and option.Node,function(node)
				local copy=DOM.cloneNode(node,true);local pending={copy}
				while #pending>0 do WorkContext.checkpoint();local child=table.remove(pending);child.OwnerDocument=c.Node.OwnerDocument or page.Document
					for _,nested in child.Children do table.insert(pending,nested)end;if child.Content then table.insert(pending,child.Content)end
					if child.InternalShadowRoot then table.insert(pending,child.InternalShadowRoot)end
				end;return copy
			end,function(mirror,children)
				local removed=table.clone(mirror.Children)
				for _,child in removed do DOM.removeChild(mirror,child)end;for _,child in children do DOM.append(mirror,child)end
				changes[mirror]={Children=true}
			end,true)
			if c.Item.RichSelect and next(changes)then
				if tree.LayoutInProgress or tree.LayoutNeedsRecovery then
					tree.PendingRichSelectChanges=tree.PendingRichSelectChanges or{};for node,change in changes do tree.PendingRichSelectChanges[node]=change end
					requestLayout(false,c.Item.Box)
				else local needed,items=tree:ApplyDOMChanges(changes);if needed then for item in items do requestLayout(false,item)end end end
			end
		end
		if c.Type=='select'then
			local needed,items=tree:RefreshSelectFallback(c)
			if needed then for item in items do requestLayout(false,item)end end
		end
		if validation.Control == c then validation:Close() end
		writing=true
		local text=ControlSelection.nativeText(if c.Type == "number" then c.EditText else c.Value)
		if c.Item.Editor and c.Item.Editor.Text ~= text then c.Item.Editor.Text=text end
		writing=false
		ControlSelection.paint(c)
		View.paint(c.Item)
		if colorPopup and colorPopup.Control==c then colorPopup:Refresh()end
		local nextStates=table.clone(formStates)
		nextStates[c.Node]=formSnapshot(c)
		if c.Type=='radio'then for _,peer in model:RadioPeers(c)do
			if peer~=c then nextStates[peer.Node]=formSnapshot(peer)end
		end end
		formStates=nextStates
		applyCSSState("form-state",formStates)
		if c.Type=='select'and c.SelectList and tree.RevealSelectOption then tree:RevealSelectOption(c)end
		if popup and popup.Control == c and not c.Datalist then popup:Refresh() end
		if layout or c.Type=='select'and not c.Item.RichSelect and c.Item.Style.FieldSizing=='content'then
			if layout then c.Item.ControlMeasureKey=nil end
			requestLayout(true,c.Item)
		end
	end)
	page.FormModel=model
	for _,c in tree.Controls do formStates[c.Node]=formSnapshot(c) end
	applyCSSState("form-state",formStates)
	popup=SelectPopup.new(page,function(c,index)
		if c.Datalist then
			local option=c.Options[index]
			if option then
				model:SetValue(c,option.Value,true)
				if c.Item.Editor and c.Item.Editor.Text~=c.Value then
					writing=true; c.Item.Editor.Text=c.Value; writing=false
				end
			end
		else model:Select(c,index,true) end
	end,if services then services.Factory else nil,if services then services.Clock else nil,PickerFragments.new(page,tree,diagnostic,services))
	function page:RefreshControlPickers()if alive and self.Alive and popup.Control then popup:Refresh()end end
	temporalPopup=TemporalPopup.new(page,function(c,value)
		local before=c.Value;if model.CommitTemporal then model:CommitTemporal(c,value) end;model:SetValue(c,value,true)
		if alive and page.Alive and before~=c.Value then model:Emit(c,"change",{Value=c.Value}) end
	end,if services then services.Factory else nil)
	colorPopup=ColorPopup.new(page,function(c,value)
		model:SetValue(c,value,true)
	end,function(c)
		if alive and page.Alive then
			if model.CommitTemporal then model:CommitTemporal(c,c.Value)end
			model:Emit(c,'change',{Value=c.Value})
		end
	end,if services then services.Factory else nil)
	function model:OpenColor(c:any)
		if not alive or not page.Alive or c.Disabled or c.Type~='color' then return end
		if self.Focus then self:Focus(c)end
		if not alive or not page.Alive then return end
		self.UserActivationUntil=0;popup:Close();temporalPopup:Close();colorPopup:Open(c);cursor:Refresh()
	end
	function model:OpenTemporal(c: any)
		if c.Disabled or c.ReadOnly then return end
		if self.Focus then self:Focus(c) end
		self.UserActivationUntil=0;popup:Close();colorPopup:Close();temporalPopup:Open(c);cursor:Refresh()
	end
	function model:ActivateTemporal(c: any,data: any,scripted: boolean?)
		if scripted or c.Disabled or c.ReadOnly then return end
		local box=c.Item.BoxGui;local x=if data and data.screenX then data.screenX-box.AbsolutePosition.X else box.AbsoluteSize.X
		if x>=box.AbsoluteSize.X-25 then self:OpenTemporal(c)
		else
			for index,entry in c.Item.TemporalLabels or {} do if x<(c.Item.TemporalLeft or 3)+entry.Right then c.TemporalSegment=index;c.TemporalDigits=nil;break end end
			View.paint(c.Item)
		end
	end
	cursor.Popup=function(objects,position) return if colorPopup:Hit(position)~=nil then colorPopup.Control elseif temporalPopup:Hit(position)~=nil then temporalPopup.Control elseif popup:Hit(objects,position) ~= nil then popup.Control else nil end
	function model:ToggleSelect(c: any)
		if c.SelectList then return end
		colorPopup:Close()
		temporalPopup:Close()
		if popup.Control == c then popup:Commit() else popup:Open(c) end
		cursor:Refresh()
	end
	function model:OpenDatalist(c: any)
		colorPopup:Close()
		temporalPopup:Close()
		popup:Filter(c,c.Value,true)
		cursor:Refresh()
	end
	local rangeDrag=RangeDrag.new(model,function() return alive and page.Alive end)
	local textareaResize=TextareaResize.new(function() return alive and page.Alive end,function(item) requestLayout(false,item) end,function(node,css)
		local runtime=page.JavaScriptRuntime
		if runtime and runtime.DOM then runtime.DOM.Attribute(node,"style",css) else node.Attributes.style=css end
	end)
	local textSelection=TextSelection.new(tree)
	local copyEligible=false
	local copyGeneration=0
	local copyAdapter
	local selectionCopy=NativeSelectionCopy.new(page,tree,services,function()
		if not copyEligible or textSelection.Dragging or tree.LayoutInProgress then return nil end
		local realm=page.JavaScriptRuntime
		if realm and realm.SimpleDialogs and realm.SimpleDialogs.Pending then return nil end
		if realm and realm.Selection and realm.SelectionAdapter then
			local range=realm.Selection:Snapshot()
			if not range then return nil end
			return realm.SelectionAdapter:CopyText(range.StartNode,range.StartOffset,range.EndNode,range.EndOffset,true)
		end
		local a,b=textSelection:Point(textSelection.Anchor),textSelection:Point(textSelection.EndPoint)
		if not a or not b then return nil end
		-- Text-only pages share the source mapper without installing a JS realm
		-- or replacing the pointer painter's change/paint callbacks.
		if not copyAdapter then copyAdapter=ScriptSelection.new(page,tree,nil,{ExtractOnly=true})end
		return copyAdapter:CopyText(a.Node,a.Offset,b.Node,b.Offset,true)
	end)
	page.SelectionCopyInput=selectionCopy
	tree.SelectionCopyChanged=function(reason)
		-- Reconciliation may update a range without moving its endpoints.
		-- Refresh only an already-owned native focus; paint never acquires it.
		if reason=='paint'and not selectionCopy.Invalidated then return end
		if selectionCopy:IsEditor(input:GetFocusedTextBox())then selectionCopy:Arm()end
	end
	local function copyModifier(key)
		return key==Enum.KeyCode.LeftControl or key==Enum.KeyCode.RightControl or key==Enum.KeyCode.LeftMeta or key==Enum.KeyCode.RightMeta
	end
	local focus
	local editableInput=NativeContentEditable.new(page,tree,services,function(node)
		if alive and page.Alive and model.TopLayerFocusedNode==node and focus then focus(nil)end
	end)
	page.ContentEditableInput=editableInput
	local focused,focusedLink,focusedMedia,hovered,pressed,pressedLink,pressedMedia,pointer,startPosition,keyDown
	local pressedNode
	local touchScrollLocks={}
	local wheelScrollLocks={}
	local refreshPointerGeometry
	local geometryWatches={}
	local wheelSnapGeneration=0
	local wheelSnapTimer
	local function cancelWheelSnap()
		wheelSnapGeneration+=1
		if wheelSnapTimer then
			if taskAPI and taskAPI.cancel then taskAPI.cancel(wheelSnapTimer) end
			wheelSnapTimer=nil
		end
	end
	local function releaseTouchScrolls()
		for scroll,wasEnabled in touchScrollLocks do pcall(function()scroll.ScrollingEnabled=if wheelScrollLocks[scroll]~=nil then false else wasEnabled end)end
		table.clear(touchScrollLocks)
	end
	local function releaseWheelScrolls()
		for scroll,wasEnabled in wheelScrollLocks do pcall(function()scroll.ScrollingEnabled=if touchScrollLocks[scroll]~=nil then false else wasEnabled end)end
		table.clear(wheelScrollLocks)
	end
	local function preventWheelScroll(node)
		local function lock(scroll)
			if not scroll or wheelScrollLocks[scroll]~=nil then return end
			pcall(function()local wasEnabled=touchScrollLocks[scroll];if wasEnabled==nil then wasEnabled=scroll.ScrollingEnabled end;wheelScrollLocks[scroll]=wasEnabled;scroll.ScrollingEnabled=false end)
		end
		local current=node;while current do local box=tree.NodeBoxes and tree.NodeBoxes[current];lock(box and box.ScrollGui);current=ShadowTree.FlatParent(current)end
		lock(page.Root)
		-- Keep the native scrolling widget gated through this input dispatch.
		-- This does not invent an OS-level wheel cancellation signal.
		if not(taskAPI and taskAPI.defer)then releaseWheelScrolls()elseif not pcall(taskAPI.defer,releaseWheelScrolls)then releaseWheelScrolls()end
	end
	local function applyTouchAction(node: any?,prevented: boolean?)
		local current,blocked=node,prevented==true
		while current do
			local style=tree.NodeStyles and tree.NodeStyles[current]
			if style and style.TouchAction=="none" then blocked=true;break end
			current=ShadowTree.FlatParent(current)
		end
		if not blocked then return end
		local seen={}
		current=node
		while current do
			local box=tree.NodeBoxes and tree.NodeBoxes[current]
			local scroll=box and box.ScrollGui
			if scroll and not seen[scroll]then seen[scroll]=true;if touchScrollLocks[scroll]==nil then touchScrollLocks[scroll]=if wheelScrollLocks[scroll]~=nil then wheelScrollLocks[scroll]else scroll.ScrollingEnabled end;scroll.ScrollingEnabled=false end
			current=ShadowTree.FlatParent(current)
		end
		if page.Root and not seen[page.Root]then if touchScrollLocks[page.Root]==nil then touchScrollLocks[page.Root]=if wheelScrollLocks[page.Root]~=nil then wheelScrollLocks[page.Root]else page.Root.ScrollingEnabled end;page.Root.ScrollingEnabled=false end
	end
	local cssStateNodes={}
	local function cssState(name: string,node: any?)
		if cssStateNodes[name]==node then return end
		cssStateNodes[name]=node
		applyCSSState(name,node)
	end
	function model:OpenSelect(c:any)
		if not alive or not page.Alive or c.Disabled or c.SelectList then return end
		colorPopup:Close()
		temporalPopup:Close()
		if popup.Control~=c and c.Item.Style.Appearance=='base-select'and self.PreparePickerFocus then self:PreparePickerFocus(c)end
		if popup.Control~=c then popup:Open(c)end
		if popup.Control==c and popup.CustomPicker and self.FocusPickerOption then self:FocusPickerOption(c,popup.Highlight)end
		cursor:Refresh()
	end
	popup.StateChanged=cssState
	local function sameStateMembers(current,nextState)
		if current then for node,enabled in current do if enabled and not nextState[node]then return false end end end
		for node,enabled in nextState do if enabled and not(current and current[node])then return false end end
		return true
	end
	local function effectiveState(name)
		local pending=tree.PendingCSSStates and tree.PendingCSSStates[name]
		return if pending then pending.Node else tree.CSSStates and tree.CSSStates[name]
	end
	local function popoverCSS()
		if not tree.SetCSSState then return end
		local open = setmetatable({}, {__mode = "k"})
		for _, state in tree.Popovers or {} do if state.Open then open[state.Node] = true end end
		if tree.CSSStates and not tree.CSSStates['popover-open']then tree.CSSStates['popover-open']=setmetatable({},{__mode='k'})end
		if not sameStateMembers(effectiveState('popover-open'),open)then applyCSSState("popover-open",open)end
	end
	local focusValue=""
	function model:CommitTemporal(c: any,value: string)if self.Focused==c then focusValue=value end end
	local focusRevision=0
	local interacted=false
	local function hiddenNode(node: any): boolean
		if not ShadowTree.Connected(node,page.Document)then return true end
		-- An area's virtual shape is anchored at a rendered associated image.
		-- Its map's CSS/inert ancestry is not the shape's rendered ancestry.
		if ElementNames.html(node,'area')then
			return node.Attributes.href==nil or not tree.ImageMapIndex or tree.ImageMapIndex:Owner(node,function(image)return not hiddenNode(image)end)==nil
		end
		if tree.IsMediaFallback and tree:IsMediaFallback(node)then return true end
		if tree.IsContentSkipped and tree:IsContentSkipped(node)then return true end
		local style=tree.NodeStyles and tree.NodeStyles[node]
		if style and (style.Visibility == "hidden" or style.Visibility == "collapse") then return true end
		local target=node
		while node do
			if node.Kind=="Element"and node.Attributes.inert~=nil then return true end
			local ancestorStyle = tree.NodeStyles and tree.NodeStyles[node]
			if ancestorStyle and ancestorStyle.Hidden then return true end
			if tree.CollapsedTableCells and tree.CollapsedTableCells[node] then return true end
			node=ShadowTree.FlatParent(node)
		end
		return Disclosure.hidden(target,tree.Disclosures) or Dialog.hidden(tree,target) or Popover.hidden(tree,target) or not Dialog.allows(tree,target)
	end
	local function hidden(c: any): boolean return hiddenNode(c.Node) end
	local function destroy()
		if not alive then return end
		alive=false
		tree.ContentVisibilityChanged=nil
		nativeDetails:Destroy()
		captures:Destroy();page.PointerCapture=nil;eventData:Reset()
		cancelWheelSnap()
		releaseTouchScrolls()
		releaseWheelScrolls()
		for gui,entries in geometryWatches do for _,entry in entries do entry:Disconnect()end;geometryWatches[gui]=nil end
		cursor:Destroy()
		copyGeneration+=1;selectionCopy:Destroy();page.SelectionCopyInput=nil;tree.SelectionCopyChanged=nil
		if copyAdapter then copyAdapter:Destroy()end
		editableInput:Destroy();page.ContentEditableInput=nil
		textSelection:Destroy()
		textareaResize:Cancel()
		validation:Close()
		popup:Close()
		temporalPopup:Close()
		colorPopup:Close(false)
		if tree.CSSStates then tree.CSSStates.open=nil end
		if tree.PendingCSSStates then tree.PendingCSSStates.open=nil end
		for _,cleanup in gaugeCleanups do cleanup() end
		table.clear(gaugeCleanups)
		for _,c in connections do c:Disconnect() end
		if focused and focused.Item.Editor then focused.Item.Editor:ReleaseFocus() end
		model:Destroy(); events:Destroy(); table.clear(connections)
		table.clear(boundControls);tree.BeforeInputViewChange=nil;page.RefreshDOMControls=nil;page.RefreshDOMFocus=nil;page.RefreshImageMapFocus=nil;page.ReportDOMValidity=nil;page.RefreshPointerGeometry=nil;page.FocusDOMElement=nil;page.BlurDOMElement=nil;page.SetControlPickerOpen=nil;page.RefreshControlPickers=nil
	end
	page:AddCleanup(destroy)
	focus=function(c: any?, keyboard: boolean?)
		if not alive or not page.Alive then return end
		if c and textareaResize:IsActive() then return end
		if c and (c.Disabled or c.DisplayOnly or c.Type == "output" or c.Item.Style.Visibility == "hidden" or hidden(c)) then return end
		if focused~=c then editHint=nil;blockedEdit,blockedKey=nil,nil end
		if c and c.Type == "summary" then
			c.FocusVisible=keyboard == true
			if focused == c then View.paint(c.Item) end
		end
		if model.TopLayerFocusedNode then
			local oldGeneric=model.TopLayerFocusedNode;model.TopLayerFocusedNode=nil
			editableInput:Blur()
			focusRevision+=1;local revision=focusRevision
			cssState("focus",nil);cssState("focus-visible",nil)
			events:Emit(oldGeneric,"blur",nil,{Bubbles=false,Cancelable=false})
			if not alive or not page.Alive or focusRevision~=revision then return end
		end
		if focused == c and not focusedLink and not focusedMedia then
			cssState("focus-visible",if c and (keyboard == true or c.Item.Editor ~= nil or Temporal.applies(c.Type)) then c.Node else nil)
			return
		end
		validation:Close()
		popup:Close();temporalPopup:Close();colorPopup:Close()
		focusRevision+=1
		local revision=focusRevision
		if focusedMedia then
			local oldMedia=focusedMedia;focusedMedia=nil;oldMedia.FocusVisible=false;MediaBox.paint(oldMedia);events:Emit(oldMedia.Node,"blur")
		end
		if focusedLink then local oldLink=focusedLink; focusedLink=nil; if page.Root.SetAttribute then page.Root:SetAttribute("FocusedLink",nil) end; events:Emit(oldLink,"blur",Links.data(oldLink)) end
		local old=focused; focused=c; model.Focused=c
		cssState("focus",c and c.Node or nil)
		cssState("focus-visible",if c and (keyboard == true or c.Item.Editor ~= nil or Temporal.applies(c.Type)) then c.Node else nil)
		if old then
			old.Focused=false
			View.paint(old.Item)
			if old.Item.Editor and old.Item.Editor:IsFocused() then old.Item.Editor:ReleaseFocus() end
			if not alive or not page.Alive or focusRevision ~= revision then return end
			if (old.Item.Editor or Temporal.applies(old.Type)) and old.Value ~= focusValue then model:Emit(old,"change",{Value=old.Value}) end
			if not alive or not page.Alive or focusRevision ~= revision then return end
			model:Emit(old,"blur")
		end
		if not alive or not page.Alive or focusRevision ~= revision then return end
		if c then
			focusValue=c.Value; c.Focused=true
			if c.Item.Editor and not c.Item.Editor:IsFocused() then c.Item.Editor:CaptureFocus() end
			if not alive or not page.Alive or focusRevision ~= revision then return end
			ControlSelection.paint(c)
			View.paint(c.Item); model:Emit(c,"focus")
		end
	end
	local function focusMedia(item: any?,keyboard: boolean?)
		if item and hiddenNode(item.Node) then return end
		if focusedMedia==item and not focused and not focusedLink then
			if item then cssState("focus-visible",if keyboard then item.Node else nil);item.FocusVisible=keyboard==true;MediaBox.paint(item) end
			return
		end
		focus(nil)
		if not alive or not page.Alive or not item or focused or focusedLink or focusedMedia then return end
		focusedMedia=item;cssState("focus",item.Node);cssState("focus-visible",if keyboard then item.Node else nil);item.FocusVisible=keyboard==true;MediaBox.paint(item);events:Emit(item.Node,"focus")
	end
	local function focusLink(link: any?,keyboard: boolean?)
		if not alive or not page.Alive or focusedLink == link or (link and hiddenNode(link)) then return end
		focus(nil)
		if not alive or not page.Alive or focused or focusedLink or focusedMedia then return end
		focusedLink=link
		cssState("focus",link)
		cssState("focus-visible",if keyboard then link else nil)
		if page.Root.SetAttribute then page.Root:SetAttribute("FocusedLink",if link then link.Attributes.href or "" else nil) end
		if link then events:Emit(link,"focus",Links.data(link)) end
	end
	local function focusCandidate(entry: any,keyboard: boolean?)
		if entry.Control then focus(entry.Control,keyboard)
		elseif entry.Link then focusLink(entry.Link,keyboard)
		elseif entry.Media then focusMedia(entry.Media,keyboard)
		elseif page.FocusDOMElement then page:FocusDOMElement(entry.Node,keyboard)end
	end
	local focusCandidates: any
	function model:Focus(c: any) focus(c) end
	function model:GetActiveElement()
		return if focused then focused.Node elseif focusedLink then focusedLink elseif focusedMedia then focusedMedia.Node else model.TopLayerFocusedNode
	end
	function model:PreparePickerFocus(c:any)
		if hiddenNode(c.Node)then return end
		focus(nil)
	end
	function model:FocusPickerOption(c:any,index:number)
		if not popup.PickerView or popup.Control~=c or hiddenNode(c.Node)then return end
		local option=c.Options[index];local box=option and popup.PickerView.Tree.NodeBoxes[option.Node]
		if not box or box.Style.Hidden or box.Style.Visibility=='hidden'or box.Style.Visibility=='collapse'or option.Disabled then return end
		if self.TopLayerFocusedNode==option.Node then return end
		local previous=self.TopLayerFocusedNode;self.TopLayerFocusedNode=option.Node
		cssState('focus',option.Node);cssState('focus-visible',option.Node)
		if previous then events:Emit(previous,'blur',nil,{Bubbles=false,Cancelable=false})end
		events:Emit(option.Node,'focus',nil,{Bubbles=false,Cancelable=false})
	end
	function model:ToggleDetails(c: any)
		if not alive or not page.Alive or hidden(c) then return end
		popup:Close(); validation:Close()
		local runtime=page.JavaScriptRuntime
		if runtime and runtime.ToggleDetails then runtime:ToggleDetails(c.Disclosure.Node);return end
		nativeDetailChanges={}
		local node=c.Disclosure.Node
		detailsAttribute(node,"open",if node.Attributes.open==nil then ""else nil)
		local changes=nativeDetailChanges;nativeDetailChanges=nil
		if tree.LayoutInProgress or tree.LayoutNeedsRecovery then
			-- Keep the DOM state immediate, but leave the active render pass intact.
			tree.PendingDisclosureChanges=tree.PendingDisclosureChanges or {}
			for changed,record in changes do
				tree.PendingDisclosureChanges[changed]=record
				local disclosure=tree.Disclosures[changed]
				if disclosure then requestLayout(false,disclosure.Box)end
			end
			return
		end
		-- Native activation changes an attribute just like author DOM writes.
		-- Reevaluate [open]/:open, including related ancestors and siblings.
		local _,items=tree:ApplyDOMChanges(changes)
		items[c.Disclosure.Box]=true
		for item in items do requestLayout(false,item) end
	end
	local function focusDialog(state: any?)
		if not state then return end
		local first
		for _,candidate in focusCandidates(true) do
			if not ShadowTree.InclusiveDescendant(candidate.Node,state.Node)then continue end
			if candidate.Node.Attributes.autofocus~=nil then focusCandidate(candidate,true);return end
			if candidate.TabIndex>=0 and not first then first=candidate end
		end
		if first then focusCandidate(first,true) else focus(nil) end
	end
	function page:FocusTopLayer(node: any,kind: string)
		if not alive or not page.Alive then return end
		if node==nil then focus(nil);return end
		local modal=tree.DialogsByNode and tree.DialogsByNode[node]
		local active=model:GetActiveElement()
		if kind=="dialog"and modal and modal.Modal and hiddenNode(node)and active and hiddenNode(active)then
			-- Opening an invisible modal still makes the old background focus inert.
			focus(nil)
			if not alive or not page.Alive then return end
		end
		if model.TopLayerFocusedNode==node and not focused and not focusedLink and not focusedMedia then return end
		local first
		for _,candidate in focusCandidates(true)do
			if kind=="restore"then
				if candidate.Node==node then focusCandidate(candidate,true);return end
			else
				if not ShadowTree.InclusiveDescendant(candidate.Node,node)then continue end
				if candidate.Node.Attributes.autofocus~=nil then focusCandidate(candidate,true);return end
				if candidate.TabIndex>=0 and not first then first=candidate end
			end
		end
		if kind=="popover"then return end
		if first and node.Attributes.autofocus==nil then focusCandidate(first,true);return end
		if node.Name=="dialog"and not hiddenNode(node)then
			local previous=model.TopLayerFocusedNode
			focus(nil)
			if not alive or not page.Alive or focused or focusedLink or focusedMedia or model.TopLayerFocusedNode or hiddenNode(node)then return end
			model.TopLayerFocusedNode=node;cssState("focus",node);cssState("focus-visible",node)
			if previous~=node then events:Emit(node,"focus",nil,{Bubbles=false,Cancelable=false})end
		end
	end
	function page:TopLayerChanged(kind: string,_node: any)
		local pending=tree.TopLayerLayoutItems;tree.TopLayerLayoutItems=nil
		for item in pending or {}do requestLayout(true,item)end
		if kind=="popover"then popoverCSS();if tree.PopoverHost then Popover.arrange(tree,page.Root)end
		else
			local modal=setmetatable({},{__mode="k"})
			for _,state in tree.Dialogs or {}do if state.Open and state.Modal then modal[state.Node]=true end end
			if tree.CSSStates and not tree.CSSStates.modal then tree.CSSStates.modal=setmetatable({},{__mode='k'})end
			if not sameStateMembers(effectiveState('modal'),modal)then applyCSSState("modal",modal)end
			if tree.DialogHost then Dialog.arrange(tree,page.Root)end
		end
	end
	local function topLayer()return page.JavaScriptRuntime and page.JavaScriptRuntime.TopLayer end
	function model:Command(c: any): boolean
		local api=topLayer()
		if api then
			local attributes=c.Node.Attributes
			local popoverTarget=attributes.popovertarget and DOM.findById(page.Document,attributes.popovertarget)
			if popoverTarget then
				local action=(attributes.popovertargetaction or "toggle"):lower()
				if action~="show"and action~="hide"then action="toggle"end
				return api:NativeAction(action.."-popover",popoverTarget,nil,c.Node)
			end
			local target=attributes.commandfor and DOM.findById(page.Document,attributes.commandfor)
			return if target then api:NativeAction((attributes.command or ""):lower(),target,c.Value,c.Node)else false
		end
		local popoverState=Popover.command(tree,c)
		if popoverState then popoverCSS();Popover.arrange(tree,page.Root);return true end
		local state=Dialog.command(tree,c)
		if not state then return false end
		if state.Open then focusDialog(state) else focus(nil) end
		page:TopLayerChanged("dialog")
		return true
	end
	function model:CloseDialogFromForm(form: any,submitter: any?): boolean
		local api=topLayer()
		if api then
			local node=form.Parent;while node and node.Name~="dialog"do node=node.Parent end
			return if node then api:NativeAction("close",node,if submitter then submitter.Value else nil,submitter and submitter.Node)else false
		end
		local state=Dialog.closeForm(tree,form,submitter)
		if not state then return false end
		focus(nil);page:TopLayerChanged("dialog");return true
	end
	local function topLayerTarget(target)return if type(target)=="string"then DOM.findById(page.Document,target)else target end
	function page:ShowModal(target: any): boolean local api=topLayer();if api then return api:NativeAction("show-modal",topLayerTarget(target))end;local state=Dialog.open(tree,target,true);focusDialog(state);page:TopLayerChanged("dialog");return state~=nil end
	function page:ShowDialog(target: any): boolean local api=topLayer();if api then return api:NativeAction("show",topLayerTarget(target))end;local state=Dialog.open(tree,target,false);focusDialog(state);page:TopLayerChanged("dialog");return state~=nil end
	function page:CloseDialog(target: any,returnValue: any?): boolean local api=topLayer();if api then return api:NativeAction("close",topLayerTarget(target),returnValue)end;local state=Dialog.close(tree,target,returnValue);if state then focus(nil);page:TopLayerChanged("dialog") end;return state~=nil end
	function page:ShowPopover(target: any): boolean local api=topLayer();if api then return api:NativeAction("show-popover",topLayerTarget(target))end;local state=Popover.show(tree,target);if state then popoverCSS();Popover.arrange(tree,page.Root) end;return state~=nil end
	function page:HidePopover(target: any): boolean local api=topLayer();if api then return api:NativeAction("hide-popover",topLayerTarget(target))end;local state=Popover.hide(tree,target);if state then popoverCSS() end;return state~=nil end
	function page:TogglePopover(target: any): boolean
		local api=topLayer();if api then return api:NativeAction("toggle-popover",topLayerTarget(target))end
		local state=if type(target)=="string" then tree.PopoversByNode[DOM.findById(tree.Node,target)] else tree.PopoversByNode[target]
		if not state then return false end
		if state.Open then return self:HidePopover(state.Node) end
		return self:ShowPopover(state.Node)
	end
	function model:ShowValidation(c: any,message: string)
		if alive and page.Alive and focused == c then validation:Open(c,message) end
	end
	function page:ReportDOMValidity(node: any,message: string)
		if not alive or not self.Alive or hiddenNode(node)then return end
		self:FocusDOMElement(node)
		local box=tree.NodeBoxes and tree.NodeBoxes[node];local gui=box and box.Gui
		if gui then validation:Open({Node=node,Item={BoxGui=gui},Disabled=false},message)end
	end
	function model:CommitNumber(c: any,value: string) if focused == c then focusValue=value end end
	local function hit(position: any): any
		local node=HitTest.pick(playerGui:GetGuiObjectsAtPosition(position.X,position.Y),tree.HitNodes,page.Root,position,tree.HitStyles)
		return ImageMap.hit(tree.ImageMapItems,node,position)
	end
	local function hoverTarget(position)
		local record=captures:Record(1);return record and record.Captured or hit(position)
	end
	local function touchEvent(event,phase,node,data,record)
		local target,init=eventData:Touch(event,phase,node,data)
		if not target then return end
		local emitted=events:Emit(target,if phase=="down"then "touchstart"elseif phase=="move"then "touchmove"elseif phase=="cancel"then "touchcancel"else "touchend",init,{Cancelable=phase~="cancel",Composed=true})
		if emitted.DefaultPrevented and record then record.CancelClick=true;applyTouchAction(target,true)end
	end
	local function control(node: any): any
		while node do
			local c=model:Resolve(node)
			if c then return if not c.DisplayOnly and c.Item.Style.Visibility ~= "hidden" and not hidden(c) then c else nil end
			if node.Name == "label" then
				local labeled=model:Label(node)
				return if labeled and not labeled.DisplayOnly and labeled.Item.Style.Visibility ~= "hidden" and not hidden(labeled) then labeled else nil
			end
			node=inclusiveParent(node)
		end
		return nil
	end
	local function listOption(c: any,objects: any): number?
		local indexes=c and c.Item.OptionIndexByGui
		for _,object in objects do
			local gui=object
			while gui and gui~=c.Item.Gui do
				if indexes and indexes[gui] then return indexes[gui] end
				if c.Item.RichSelect then
					local node=tree.HitNodes[gui]
					while node and node~=c.Node do
						if node.Name=='option'then for index,option in c.Options do if option.Node==node then return index end end;break end
						node=node.Parent
					end
				end
				gui=gui.Parent
			end
		end
		return nil
	end
	local function hover(node: any,position: any?)
		cssState("hover",node)
		media:Hover(media:Resolve(node),position)
		local nextControl=control(node)
		if nextControl and nextControl.Type == "range" then
			nextControl.RangePointer=if node == nextControl.Node then position else nil
		end
		if nextControl and nextControl.Type == "number" then nextControl.NumberHovered=if node == nextControl.Node then NumberView.direction(nextControl,position) else nil end
		if nextControl == hovered then
			if hovered and (hovered.Type == "range" or hovered.Type == "number") then View.paint(hovered.Item) end
			return
		end
		if hovered then hovered.Hovered=false; hovered.RangePointer=nil; hovered.NumberHovered=nil; View.paint(hovered.Item)end
		hovered=nextControl
		if hovered then hovered.Hovered=true; View.paint(hovered.Item)end
	end
	do
		local queued=false
		local function refresh()
			queued=false;if not alive or not page.Alive then return end
			local record=captures:Record(1);if not record then return end
			local data=eventData:Stationary(record.Data);local position=Vector2.new(data.screenX,data.screenY)
			local target=captures:Refresh(hit(position),data);hover(target,position)
		end
		local function queue()
			if queued or not alive or not page.Alive then return end;queued=true
			if taskAPI and taskAPI.defer then taskAPI.defer(refresh)else refresh()end
		end
		local function watch(gui,seen)
			if not gui or not gui.GetPropertyChangedSignal then return end;seen[gui]=true
			if geometryWatches[gui]then return end
			local entries={};geometryWatches[gui]=entries
			for _,key in {"AbsolutePosition","AbsoluteSize","CanvasPosition"}do
				if key~="CanvasPosition"or gui:IsA("ScrollingFrame")then table.insert(entries,gui:GetPropertyChangedSignal(key):Connect(queue))end
			end
		end
		refreshPointerGeometry=function()
			local seen={};watch(page.Root,seen)
			for _,box in tree.NodeBoxes or {}do if box.ScrollGui then watch(box.ScrollGui,seen)end end
			for gui,entries in geometryWatches do if not seen[gui]then for _,entry in entries do entry:Disconnect()end;geometryWatches[gui]=nil end end
			queue()
		end
		page.RefreshPointerGeometry=function()refreshPointerGeometry()end
		refreshPointerGeometry()
	end
	local function cancelPress()
		cssState("active",nil)
		if pressed then pressed.Pressed=false; pressed.NumberPressed=nil; View.paint(pressed.Item) end
		pressed,pressedLink,pressedMedia,pointer,startPosition,keyDown=nil,nil,nil,nil,nil,nil
		pressedNode=nil
		rangeDrag:Finish()
		media:Cancel()
	end
	-- The initial scripting profile preserves the interactive element structure. Index focus candidates
	-- once so links, controls and media share document order without rescanning
	-- every text node on each Tab key press.
	local focusOrder,genericFocusNodes={},{}
	local function refreshFocusOrder()
		table.clear(focusOrder)
		table.clear(genericFocusNodes)
		for _,c in tree.Controls do focusOrder[c.Node]=false end
		for _,link in tree.Links or {} do focusOrder[link]=false end
		for _,item in tree.MediaItems or {} do focusOrder[item.Node]=false end
		do
			local pending,sequence={page.Document},0
			while #pending>0 do
				local node=table.remove(pending)
				if node.Kind=="Element"and not ElementNames.html(node,'area')and focusOrder[node]==nil and(node.Attributes.tabindex~=nil or ContentEditing.host(node)==node)then
					focusOrder[node]=false;table.insert(genericFocusNodes,node)
				end
				if focusOrder[node]~=nil then sequence+=1;focusOrder[node]=sequence end
				for index=#(node.Children or {}),1,-1 do table.insert(pending,node.Children[index]) end
				if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot) end
			end
		end
	end
	refreshFocusOrder()
	function page:RefreshDOMFocus()
		if not alive or not self.Alive then return end;refreshFocusOrder()
		local active=model:GetActiveElement();if active and hiddenNode(active)then focus(nil)end
	end
	function page:RefreshImageMapFocus()
		-- Revalidate just the active shape after a recascade; no focus-order or
		-- map scan is needed for unrelated color/style changes.
		if not alive or not self.Alive then return end
		if focusedLink and ElementNames.html(focusedLink,'area')and hiddenNode(focusedLink)then focus(nil)end
	end
	tree.ContentVisibilityChanged=function(rebuiltContents: boolean?)
		if not alive or not page.Alive then return end
		if rebuiltContents then refreshFocusOrder()end
		local active=model:GetActiveElement();if active and hiddenNode(active)then focus(nil)end
	end
	focusCandidates=function(includeProgrammatic: boolean?): any
		local order,eligible,radioGroups={},{},{}
		for i,c in tree.Controls do
			if c.Disabled or c.DisplayOnly or (c.TabIndex < 0 and not includeProgrammatic) or c.Type == "output" or c.Item.Style.Visibility == "hidden" or hidden(c) then continue end
			table.insert(eligible,{Node=c.Node,Control=c,TabIndex=c.TabIndex,Order=focusOrder[c.Node] or i})
			if c.Type == "radio" and c.Name ~= "" then
				local owner=c.Form or tree
				local groups=radioGroups[owner]
				if not groups then groups={};radioGroups[owner]=groups end
				if not groups[c.Name] or c.Checked then groups[c.Name]=c end
			end
		end
		for _,entry in eligible do
			local c=entry.Control
			if not includeProgrammatic and c.Type == "radio" and c.Name ~= "" and radioGroups[c.Form or tree][c.Name] ~= c then continue end
			table.insert(order,entry)
		end
		for index,link in tree.Links or {} do
			local area=ElementNames.html(link,'area')
			local tabIndex=if area then tonumber((link.Attributes.tabindex or''):match('^[\t\n\f\r ]*([%+%-]?%d+)'))or 0 else tonumber(link.Attributes.tabindex or "")or 0
			if area and(tabIndex < -2147483648 or tabIndex > 2147483647)then tabIndex=0 end
			if (tabIndex >= 0 or includeProgrammatic) and not hiddenNode(link) then
				-- Native sequential ordering follows area tree placement. The
				-- associated image owns eligibility, separately from that ordering.
				table.insert(order,{Node=link,Link=link,TabIndex=tabIndex,Order=focusOrder[link]or #tree.Controls+index})
			end
		end
		for index,item in tree.MediaItems or {} do
			local tabIndex=tonumber(item.Node.Attributes.tabindex or "") or 0
			if item.Controls and MediaBox.canControl(item) and (tabIndex>=0 or includeProgrammatic) and not hiddenNode(item.Node) then table.insert(order,{Node=item.Node,Media=item,TabIndex=tabIndex,Order=focusOrder[item.Node] or #tree.Controls+#(tree.Links or {})+index}) end
		end
		for _,node in genericFocusNodes do
			local editable=ContentEditing.host(node)==node
			local tabIndex=tonumber(node.Attributes.tabindex or"")or(if editable then 0 else -1)
			if (editable or node.Attributes.tabindex~=nil)and(tabIndex>=0 or includeProgrammatic)and not hiddenNode(node)then
				table.insert(order,{Node=node,Generic=true,TabIndex=tabIndex,Order=focusOrder[node]})
			end
		end
		table.sort(order,function(a,b)
			if includeProgrammatic then return a.Order < b.Order end
			local x=if a.TabIndex > 0 then a.TabIndex else math.huge
			local y=if b.TabIndex > 0 then b.TabIndex else math.huge
			return if x == y then a.Order<b.Order else x < y
		end)
		return order
	end
	function page:FocusDOMElement(node: any,keyboard: boolean?): boolean
		if not alive or not self.Alive or hiddenNode(node)then return false end
		local candidates=focusCandidates(true);local indexed={};for _,candidate in candidates do indexed[candidate.Node]=candidate end
		local shadow=node.InternalShadowRoot
		if shadow and shadow.DelegatesFocus then
			local active=model:GetActiveElement()
			if active and ShadowTree.InclusiveDescendant(active,shadow)and indexed[active]then return true end
			local pending,seen,first={shadow},{},nil
			while #pending>0 do
				local current=table.remove(pending)
				if seen[current]then continue end;seen[current]=true
				local candidate=indexed[current]
				if candidate then
					if current.Attributes.autofocus~=nil then focusCandidate(candidate);return true end
					if not first then first=candidate end
				end
				local children=ShadowTree.FlatChildren(current)
				for i=#children,1,-1 do table.insert(pending,children[i])end
			end
			if first then focusCandidate(first);return true end
		else local candidate=indexed[node];if candidate then
			if not candidate.Generic then focusCandidate(candidate,keyboard);return true end
			if model.TopLayerFocusedNode==node then if ContentEditing.host(node)==node then return editableInput:Focus(node)end;return true end
			focus(nil);if not alive or not self.Alive or model:GetActiveElement()then return false end
			if ContentEditing.host(node)==node and not editableInput:Focus(node)then return false end
			model.TopLayerFocusedNode=node;focusRevision+=1;cssState("focus",node);cssState("focus-visible",if keyboard or editableInput.Host then node else nil)
			events:Emit(node,"focus",nil,{Bubbles=false,Cancelable=false});return true
		end end
		return false
	end
	function page:BlurDOMElement(node: any)
		local active=model:GetActiveElement();local shadow=node.InternalShadowRoot
		if active==node or(shadow and shadow.DelegatesFocus and active and ShadowTree.InclusiveDescendant(active,shadow))then focus(nil);return true end
		return false
	end
	local function tab(reverse: boolean)
		local order=focusCandidates()
		if #order == 0 then return end
		local index=if reverse then 1 else 0
		for i,entry in order do
			if (entry.Control and entry.Control == focused) or (entry.Link and entry.Link == focusedLink) or (entry.Media and entry.Media == focusedMedia)or(entry.Generic and entry.Node==model.TopLayerFocusedNode)then index=i; break end
		end
		local nextEntry=order[(index-1+(if reverse then -1 else 1))%#order+1]
		focusCandidate(nextEntry,true)
	end
	local function unbindControl(c:any)
		local binding=boundControls[c];if not binding then return end
		boundControls[c]=nil
		for _,connection in binding.Connections do
			connection:Disconnect();local index=table.find(connections,connection);if index then table.remove(connections,index)end
		end
		if binding.Gauge then binding.Gauge();local index=table.find(gaugeCleanups,binding.Gauge);if index then table.remove(gaugeCleanups,index)end end
	end
	tree.BeforeInputViewChange=function(c:any)
		unbindControl(c)
		if focused==c then focusValue=c.Value;if c.Type=='hidden'then focus(nil)end end
		if popup.Control==c then popup:Close()end
		if temporalPopup.Control==c then temporalPopup:Close()end
		if colorPopup.Control==c then colorPopup:Close(false)end
		if validation.Control==c then validation:Close()end
		rangeDrag:Cancel(c)
		c.Pressed,c.NumberPressed,c.NumberHovered,c.RangePointer=nil,nil,nil,nil
	end
	local function bindControl(c: any)
		if boundControls[c] then return end
		local binding={Connections={}}
		boundControls[c]=binding
		local firstConnection=#connections+1
		if c.DisplayOnly then binding.Gauge=GaugeView.bind(c.Item,services);table.insert(gaugeCleanups,binding.Gauge) end
		View.paint(c.Item)
		local editor=c.Item.Editor
		if not editor then return end
		local selectionQueued=false
		local function readSelection()
			if writing or c.SelectionWriting or not alive or not page.Alive then return end
			-- Roblox writes cursor and anchor separately. Coalesce their property
			-- signals once at the end of the native action, without a frame loop.
			if selectionQueued then return end;selectionQueued=true
			local function settled()
				selectionQueued=false
				if alive and page.Alive and boundControls[c]==binding and not writing and not c.SelectionWriting then
					ControlSelection.read(c)
					if c.Item.Caret then View.updateCaret(c.Item)end
				end
			end
			if taskAPI and taskAPI.defer then taskAPI.defer(settled)else settled()end
		end
		connect(editor:GetPropertyChangedSignal("CursorPosition"),readSelection)
		connect(editor:GetPropertyChangedSignal("SelectionStart"),readSelection)
		connect(editor:GetPropertyChangedSignal("Text"),function()
			if writing or not alive or not page.Alive then return end
			if blockedEdit==c then writing=true;editor.Text=ControlSelection.nativeText(if c.Type=="number"then c.EditText else c.Value);writing=false;ControlSelection.paint(c);return end
			if c.Disabled or c.ReadOnly or hidden(c) or textareaResize:IsActive() then writing=true; editor.Text=ControlSelection.nativeText(if c.Type == "number" then c.EditText else c.Value); writing=false; return end
			local before=if c.Type=="number"then c.EditText else c.Value
			local proposed=editor.Text;if proposed==before then return end
			local data=NativeTextEdit.describe(ControlSelection.nativeText(before),proposed,editHint);editHint=nil
			local previousStart,previousEnd,previousDirection=c.SelectionStart,c.SelectionEnd,c.SelectionDirection
			local emitted=model:Emit(c,"beforeinput",data,{Cancelable=true})
			if not alive or not page.Alive then return end
			if emitted.DefaultPrevented then
				writing=true;editor.Text=ControlSelection.nativeText(if c.Type=="number"then c.EditText else c.Value);writing=false
				ControlSelection.set(c,previousStart or 0,previousEnd or previousStart or 0,previousDirection or "none");ControlSelection.paint(c);return
			end
			-- Author handlers may write a value or remove the editor. Do not replace
			-- that synchronous mutation with a stale native edit snapshot.
			if boundControls[c]~=binding or not ShadowTree.Connected(c.Node,page.Document)or (if c.Type=="number"then c.EditText else c.Value)~=before then return end
			data.Value=proposed;model:SetValue(c,proposed,true,data)
			local text=ControlSelection.nativeText(if c.Type == "number" then c.EditText else c.Value)
			if alive and page.Alive and editor.Text ~= text then writing=true; editor.Text=text; writing=false end
			if alive and page.Alive and c.Datalist then popup:Filter(c,c.Value,true) end
		end)
		if c.Datalist and editor.InputBegan then
			connect(editor.InputBegan,function(event: any)
				local kind=event.UserInputType
				if alive and page.Alive and not c.Disabled and not c.ReadOnly and not hidden(c)
					and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
					-- ControlText is a native TextBox and owns its pointer event. Forward
					-- that click to the surrounding HTML input/control box.
					model:OpenDatalist(c)
				end
			end)
		end
		connect(editor.Focused,function()
			-- Native events may be delivered after a newer focus operation.
			-- Replaying an obsolete Focused signal would steal focus back.
			if not editor:IsFocused()then return end
			if alive then
				if c.Disabled or hidden(c) or textareaResize:IsActive() then editor:ReleaseFocus()
				else if not c.Focused then ControlSelection.read(c)end;focus(c); if alive and page.Alive and c.Datalist and not suppressDatalistOpen then model:OpenDatalist(c) end end
			end
		end)
		connect(editor.FocusLost,function(enter: boolean)
			if not alive then return end
			-- Only a pointer press already captured by a suggestion may postpone
			-- blur. Any ordinary loss of the blinking caret closes the list.
			if c.Datalist and popup:IsPressing(c) then return end
			if focused == c and not editor:IsFocused() then focus(nil) end
			if enter and c.Type ~= "textarea" and c.Form then
				for _,submitter in tree.Controls do
					if submitter.Form == c.Form and (submitter.Type == "submit" or submitter.Type=="image") then model:Activate(submitter); return end
				end
				model:Submit(c.Form)
			end
		end)
		for i=firstConnection,#connections do table.insert(binding.Connections,connections[i]) end
		if focused==c and not editor:IsFocused()then
			editor:CaptureFocus();ControlSelection.paint(c)
		end
	end
	for _,c in tree.Controls do bindControl(c) end
	function page:RefreshDOMControls()
		if not alive or not self.Alive then return end
		model:RefreshControls()
		local current={};for _,c in tree.Controls do current[c]=true end
		for c,binding in boundControls do
			if current[c] then continue end
			unbindControl(c)
		end
		if focused and not current[focused] then focus(nil) end
		if focusedLink and hiddenNode(focusedLink) then focusLink(nil) end
		if popup.Control and not current[popup.Control] then popup:Close() end
		if temporalPopup.Control and (not current[temporalPopup.Control] or temporalPopup.Control.Disabled or temporalPopup.Control.ReadOnly) then temporalPopup:Close() end
		if colorPopup.Control and (not current[colorPopup.Control] or colorPopup.Control.Disabled or colorPopup.Control.Type~='color' or hidden(colorPopup.Control))then colorPopup:Close(false)end
		if popup.Control then popup:Refresh() end
		if validation.Control and not current[validation.Control] then validation:Close() end
		formStates={}
		for _,c in tree.Controls do bindControl(c);formStates[c.Node]=formSnapshot(c) end
		refreshFocusOrder()
		applyCSSState("form-state",formStates)
		if refreshPointerGeometry then refreshPointerGeometry()end
	end
	connect(input.InputBegan,function(event: any,processed: boolean)
		if not alive or not page.Alive then return end
		interacted=true
		if textareaResize:IsActive() then return end
		local kind=event.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind==Enum.UserInputType.MouseButton2 or kind==Enum.UserInputType.MouseButton3 or kind == Enum.UserInputType.Touch then
			copyGeneration+=1;copyEligible=false;selectionCopy:Release()
			if not event.Position then return end
			validation:Close()
			local objects=playerGui:GetGuiObjectsAtPosition(event.Position.X,event.Position.Y)
			if kind==Enum.UserInputType.MouseButton1 or kind==Enum.UserInputType.Touch then
				if colorPopup:Begin(event)then return end
				if temporalPopup:Begin(event) then return end
				model.UserActivationUntil=os.clock()+5
			end
			local hitNode,hitObject=HitTest.pick(objects,tree.HitNodes,page.Root,event.Position,tree.HitStyles)
			local node=ImageMap.hit(tree.ImageMapItems,hitNode,event.Position)
			if kind==Enum.UserInputType.Touch then applyTouchAction(node) end
			local api=topLayer()
			if api then api:PointerDown(event.Position,node)
			else
				if Dialog.dismissAt(tree,event.Position) then focus(nil);page:TopLayerChanged("dialog");return end
				if Popover.dismissAt(tree,event.Position,node) then popoverCSS() end
			end
			local c=control(node)
			local pointerData=eventData:Pointer(event,"down")
			if kind~=Enum.UserInputType.Touch or pointerData.isPrimary then cssState("active",node)end
			local target,_,record=captures:Dispatch(if kind~=Enum.UserInputType.Touch and pointerData.previousButtons~=0 then "pointermove"else "pointerdown",node,pointerData)
			if kind==Enum.UserInputType.Touch then touchEvent(event,"down",node,pointerData,record)end
			if not pointer then compatibilitySuppressed=record and record.Suppressed or false end
			local mouseEvent=if target and kind~=Enum.UserInputType.Touch and record and not record.Suppressed then events:Emit(target,"mousedown",pointerData)else nil
			local allowFocus=not(record and record.Suppressed)and not(mouseEvent and mouseEvent.DefaultPrevented)
			if not alive or not page.Alive then return end
			if kind==Enum.UserInputType.MouseButton2 or kind==Enum.UserInputType.MouseButton3 then auxiliaryPresses[pointerData.button]=target;return end
			local popupIndex=if popup.Control then popup:Hit(objects,event.Position) else nil
			if popup.Control and not (popup.Control.Datalist and c == popup.Control and popupIndex == nil) then
				local popupControl=popup.Control
				if popup:Begin(event,objects) then
					-- An outside click closes a datalist popup. Its earlier FocusLost may
					-- have been deliberately deferred, so finish the blur here.
					if popupControl.Datalist and popup.Control == nil and focused == popupControl then focus(nil) end
					return
				end
			end
			if pointer then return end
			local link=Links.find(node)
			local mediaItem=media:Resolve(node)
			local editableOwner=if node and not c then ContentEditing.host(node)else nil
			if editableOwner then link=nil end
			if textareaResize:Begin(if c and node == c.Node then c else nil,event) then cursor:Capture(c,event); focus(nil); return end
			if allowFocus and kind==Enum.UserInputType.MouseButton1 and Dialog.allows(tree,node) then
				local selectionNode=node
				if hitObject and (not selectionNode or selectionNode.Kind=="Document") then
					selectionNode=DOM.findElement(page.Document,function(element)return element.Name=="body"end)
				end
				local style=selectionNode and tree.NodeStyles[selectionNode]
				if selectionNode and (not c or c.Type=="summary") and not link and not mediaItem and (not style or style.UserSelect~="none") then
					copyEligible=textSelection:Begin(objects,event.Position,selectionNode)
				elseif c and (c.Item.Editor or Temporal.applies(c.Type)) and not c.Disabled and (not style or style.UserSelect~="none") then
					-- The native editor owns its own caret/selection. Collapse the
					-- document range immediately before the field, as in Chromium.
					local parent=c.Node.Parent
					if parent then textSelection:Collapse(parent,(table.find(parent.Children,c.Node)or 1)-1)end
				end
			end
			if c and not c.Disabled then
				if allowFocus and (kind == Enum.UserInputType.MouseButton1 or c.Type == "range") then focus(c) end
				if not alive or not page.Alive then return end
				pressed,pointer,startPosition=c,event,event.Position
				c.NumberPressed=if node == c.Node then NumberView.direction(c,event.Position) else nil
				c.OptionPressed=if c.SelectList then listOption(c,objects) else nil
				c.OptionAdditive=c.SelectMultiple and (input:IsKeyDown(Enum.KeyCode.LeftControl) or input:IsKeyDown(Enum.KeyCode.RightControl)
					or input:IsKeyDown(Enum.KeyCode.LeftMeta) or input:IsKeyDown(Enum.KeyCode.RightMeta))
				c.OptionRange=c.SelectMultiple and (input:IsKeyDown(Enum.KeyCode.LeftShift) or input:IsKeyDown(Enum.KeyCode.RightShift))
				c.Pressed=true; View.paint(c.Item)
				if not compatibilitySuppressed and node == c.Node and alive and page.Alive then rangeDrag:Begin(c,event) end
			elseif link then
				if allowFocus then focusLink(link) end;pressedLink,pointer,startPosition=link,event,event.Position
			elseif mediaItem then
				if allowFocus then focusMedia(mediaItem,false) end;pressedMedia,pointer,startPosition=mediaItem,event,event.Position
				if not compatibilitySuppressed then media:Begin(mediaItem,event.Position) end
			else
				if allowFocus then if editableOwner then page:FocusDOMElement(editableOwner)else focus(nil)end end
				if node and not c then
					pressedNode,pointer,startPosition=node,event,event.Position
				end
			end
		elseif kind == Enum.UserInputType.Keyboard then
			local nativeEditor=input:GetFocusedTextBox()
			local ownCopy=selectionCopy:IsEditor(nativeEditor)
			if nativeEditor and not ownCopy and not editableInput:IsEditor(nativeEditor)and(not focused or nativeEditor~=focused.Item.Editor)then return end
			local shortcut=input:IsKeyDown(Enum.KeyCode.LeftControl)or input:IsKeyDown(Enum.KeyCode.RightControl)or input:IsKeyDown(Enum.KeyCode.LeftMeta)or input:IsKeyDown(Enum.KeyCode.RightMeta)
			if copyEligible and not editableInput.Host and (copyModifier(event.KeyCode)or shortcut and event.KeyCode==Enum.KeyCode.C)then
				selectionCopy:Arm()
			elseif ownCopy then
				-- The proxy is only a native copy source; ordinary keys still use
				-- the document's existing defaults (including Tab navigation).
				selectionCopy:Release();processed=false
			end
			if colorPopup.Control then
				colorPickerKeys[event.KeyCode]=true
				local reverse=input:IsKeyDown(Enum.KeyCode.LeftShift)or input:IsKeyDown(Enum.KeyCode.RightShift)
				local key=if type(event.KeyCode)=='string'then event.KeyCode else event.KeyCode.Name
				if not colorPopup:Key(key,reverse)and key=='Tab'then tab(reverse)end
				return
			end
			if event.KeyCode~=Enum.KeyCode.Escape and not input:IsKeyDown(Enum.KeyCode.LeftControl) and not input:IsKeyDown(Enum.KeyCode.RightControl) and not input:IsKeyDown(Enum.KeyCode.LeftAlt) and not input:IsKeyDown(Enum.KeyCode.RightAlt) and not input:IsKeyDown(Enum.KeyCode.LeftMeta) and not input:IsKeyDown(Enum.KeyCode.RightMeta) then model.UserActivationUntil=os.clock()+5 end
			if editableInput.Host then
				local shift=input:IsKeyDown(Enum.KeyCode.LeftShift)or input:IsKeyDown(Enum.KeyCode.RightShift)
				local shortcut=input:IsKeyDown(Enum.KeyCode.LeftControl)or input:IsKeyDown(Enum.KeyCode.RightControl)or input:IsKeyDown(Enum.KeyCode.LeftMeta)or input:IsKeyDown(Enum.KeyCode.RightMeta)
				editableInput:Hint(event.KeyCode,shift,shortcut)
			end
			if focused and focused.Item.Editor then
				editHint=if event.KeyCode==Enum.KeyCode.Backspace then "deleteContentBackward"elseif event.KeyCode==Enum.KeyCode.Delete then "deleteContentForward"elseif event.KeyCode==Enum.KeyCode.Return and focused.Type=="textarea"then "insertLineBreak"else nil
			end
			local keyTarget=model:GetActiveElement()or page.Document
			local keyEvent=events:Emit(keyTarget,"keydown",eventData:Keyboard(event,"down"))
			if keyEvent.DefaultPrevented then
				selectionCopy:Release()
				if focused and focused.Item.Editor then blockedEdit,blockedKey=focused,event.KeyCode end
				if editableInput.Host then editableInput:Block(event.KeyCode)end
				editHint=nil;return
			end
			if not alive or not page.Alive then return end
			if event.KeyCode == Enum.KeyCode.Escape then
				local fullscreen=page.JavaScriptRuntime and page.JavaScriptRuntime.Fullscreen
				if fullscreen and fullscreen.Element then fullscreen:ExitForHost();return end
				if media:ExitFullscreen() then return end
				local api=topLayer()
				if api then if api:Escape()then return end
				else
					if Popover.cancel(tree) then popoverCSS();return end
					if Dialog.cancel(tree) then focus(nil);page:TopLayerChanged("dialog");return end
				end
				validation:Close()
			end
			local editor=input:GetFocusedTextBox()
			if editor and not selectionCopy:IsEditor(editor)and not editableInput:IsEditor(editor)and(not focused or editor ~= focused.Item.Editor)then return end
			if editableInput.Host then
				local shift=input:IsKeyDown(Enum.KeyCode.LeftShift)or input:IsKeyDown(Enum.KeyCode.RightShift)
				local shortcut=input:IsKeyDown(Enum.KeyCode.LeftControl)or input:IsKeyDown(Enum.KeyCode.RightControl)or input:IsKeyDown(Enum.KeyCode.LeftMeta)or input:IsKeyDown(Enum.KeyCode.RightMeta)
				if editableInput:Navigate(event.KeyCode,shift,shortcut)then return end
			end
			local code=event.KeyCode.Value
			local openSelect=popup.Control
			if openSelect and not openSelect.Datalist and openSelect~=focused then
				if event.KeyCode==Enum.KeyCode.Escape then popup:Close();cancelPress();return
				elseif event.KeyCode==Enum.KeyCode.Up or event.KeyCode==Enum.KeyCode.Down then
					popup:MoveSelection(openSelect,if event.KeyCode==Enum.KeyCode.Up then -1 else 1);model:FocusPickerOption(openSelect,popup.Highlight);return
				elseif event.KeyCode==Enum.KeyCode.Return or event.KeyCode==Enum.KeyCode.Space then popup:Commit();return end
			end
			local printable=event.KeyCode == Enum.KeyCode.Space or (type(code) == "number" and code >= 32 and code <= 126)
			if printable and focused and focused.Type == "select" and not focused.Disabled and not processed and not pointer and not keyDown then
				local shortcut=false
				for _,modifier in {Enum.KeyCode.LeftControl,Enum.KeyCode.RightControl,Enum.KeyCode.LeftAlt,Enum.KeyCode.RightAlt,Enum.KeyCode.LeftMeta,Enum.KeyCode.RightMeta} do
					if input:IsKeyDown(modifier) then shortcut=true; break end
				end
				if not shortcut then
					local character=if event.KeyCode == Enum.KeyCode.Space then " " else input:GetStringForKeyCode(event.KeyCode)
					if popup:Type(focused,character) then return end
				end
			end
			if event.KeyCode == Enum.KeyCode.Tab then
				if temporalPopup:Tab(input:IsKeyDown(Enum.KeyCode.LeftShift) or input:IsKeyDown(Enum.KeyCode.RightShift)) then return end
				popup:Close();temporalPopup:Close()
				tab(input:IsKeyDown(Enum.KeyCode.LeftShift) or input:IsKeyDown(Enum.KeyCode.RightShift))
			elseif focused and Temporal.applies(focused.Type) then
				local name=if type(event.KeyCode)=="string" then event.KeyCode else event.KeyCode.Name
				local digits={Zero="0",One="1",Two="2",Three="3",Four="4",Five="5",Six="6",Seven="7",Eight="8",Nine="9"}
				local key=digits[name:gsub("^Keypad","")] or name
				if temporalPopup:Key(key) then return end
				if key=="Space" or key=="Return" then model:OpenTemporal(focused)
				elseif TemporalEdit.change(focused,key,model) then View.paint(focused.Item) end
			elseif focusedMedia and not processed and not pointer and media:Key(focusedMedia,event.KeyCode) then
				return
			elseif focusedLink and event.KeyCode == Enum.KeyCode.Return and not processed and not pointer and not keyDown then
				pressedLink,keyDown=focusedLink,event.KeyCode
			elseif focused and focused.Datalist and event.KeyCode == Enum.KeyCode.Escape then popup:Close(); cancelPress()
			elseif focused and focused.Datalist and (event.KeyCode == Enum.KeyCode.Up or event.KeyCode == Enum.KeyCode.Down) then
				if popup.Control ~= focused then popup:Filter(focused,focused.Value,true) end
				popup:MoveSelection(focused,if event.KeyCode == Enum.KeyCode.Up then -1 else 1)
			elseif focused and focused.Datalist and event.KeyCode == Enum.KeyCode.Return and popup.Control == focused then
				popup:Commit()
			elseif focused and focused.Type == "number" and not pointer and (event.KeyCode == Enum.KeyCode.Up or event.KeyCode == Enum.KeyCode.Down) then
				model:StepNumber(focused,if event.KeyCode == Enum.KeyCode.Up then 1 else -1)
			elseif focused and focused.Type == "select" and event.KeyCode == Enum.KeyCode.Escape then popup:Close(); cancelPress()
			elseif focused and focused.Type == "select" and (event.KeyCode == Enum.KeyCode.Up or event.KeyCode == Enum.KeyCode.Down) then
				if focused.SelectList then
					local index=SelectOptions.next(focused,focused.ListActiveIndex or focused.SelectedIndex,if event.KeyCode == Enum.KeyCode.Up then -1 else 1)
					focused.ListActiveIndex=index
					local controlHeld=input:IsKeyDown(Enum.KeyCode.LeftControl) or input:IsKeyDown(Enum.KeyCode.RightControl)
						or input:IsKeyDown(Enum.KeyCode.LeftMeta) or input:IsKeyDown(Enum.KeyCode.RightMeta)
					if not controlHeld then model:Select(focused,index,true,false,input:IsKeyDown(Enum.KeyCode.LeftShift) or input:IsKeyDown(Enum.KeyCode.RightShift))
					else View.paint(focused.Item);if tree.RevealSelectOption then tree:RevealSelectOption(focused)end end
				else popup:MoveSelection(focused,if event.KeyCode == Enum.KeyCode.Up then -1 else 1) end
			elseif focused and focused.Type == "range" and not focused.Disabled and not processed and not pointer then
				local key=event.KeyCode
				local r=focused.Range
				local before=focused.Value
				local value=tonumber(before) or r.Min
				if key == Enum.KeyCode.Left or key == Enum.KeyCode.Down then value-=r.Step or (r.Max/100-r.Min/100)
				elseif key == Enum.KeyCode.Right or key == Enum.KeyCode.Up then value+=r.Step or (r.Max/100-r.Min/100)
				elseif key == Enum.KeyCode.Home then value=r.Min
				elseif key == Enum.KeyCode.End then value=r.Max
				else return end
				local c=focused
				model:SetValue(c,RangeValue.normalize(r,value),true)
				if alive and page.Alive and c.Value ~= before then model:Emit(c,"change",{Value=c.Value}) end
			elseif focused and not focused.Item.Editor and (event.KeyCode == Enum.KeyCode.Space or event.KeyCode == Enum.KeyCode.Return) then
				if processed or keyDown then return end
				if focused.Type == "select" and focused.SelectList then
					if event.KeyCode == Enum.KeyCode.Space and focused.SelectMultiple then
						local index=focused.ListActiveIndex or focused.SelectedIndex
						if index and index>0 then model:Select(focused,index,true,true) end
					end
					return
				end
				if focused.Type == "summary" then focused.FocusVisible=true end
				pressed,keyDown=focused,event.KeyCode; pressed.Pressed=true; View.paint(pressed.Item)
			elseif focused and focused.Type == "radio" and (event.KeyCode == Enum.KeyCode.Left or event.KeyCode == Enum.KeyCode.Right or event.KeyCode == Enum.KeyCode.Up or event.KeyCode == Enum.KeyCode.Down) then
				local group={}; local index=1
				for _,c in tree.Controls do if c.Type == "radio" and c.Form == focused.Form and ((c.Name ~= "" and c.Name == focused.Name) or c == focused) and not c.Disabled and c.Item.Style.Visibility ~= "hidden" and not hidden(c) then table.insert(group,c); if c == focused then index=#group end end end
				local step=if event.KeyCode == Enum.KeyCode.Left or event.KeyCode == Enum.KeyCode.Up then -1 else 1
				local nextControl=group[(index-1+step)%#group+1]; focus(nextControl); model:SetChecked(nextControl,true,true)
			end
		end
	end)
	connect(input.InputChanged,function(event: any)
		if not alive or not page.Alive then return end
		if colorPopup.Control and event.Position then
			local kind=event.UserInputType
			if kind==Enum.UserInputType.MouseMovement or kind==Enum.UserInputType.Touch then
				if colorPopup:Move(event)then cursor:Refresh(event.Position);return end
			elseif kind==Enum.UserInputType.MouseWheel and colorPopup:Hit(event.Position)~=nil then return end
		end
		if temporalPopup.Control and event.Position then
			local kind=event.UserInputType
			if kind==Enum.UserInputType.MouseMovement or kind==Enum.UserInputType.Touch then
				temporalPopup:Move(event)
				-- Native picker surfaces own their input; do not dispatch pointer
				-- moves or CSS hover changes to the document underneath the popup.
				if temporalPopup:Hit(event.Position)~=nil then return end
			elseif kind==Enum.UserInputType.MouseWheel and temporalPopup:Hit(event.Position)~=nil then return end
		end
		if event.UserInputType==Enum.UserInputType.MouseWheel and event.Position then
			local node=hit(event.Position);if not node then return end
			local data=eventData:Wheel(event);local emitted=events:Emit(node,"wheel",data,{Cancelable=true,Composed=true})
			if not alive or not page.Alive then return end
			cancelWheelSnap()
			if emitted.DefaultPrevented then preventWheelScroll(node)
			elseif taskAPI and taskAPI.delay then
				if tree.RecordUserScroll then tree:RecordUserScroll(node)end
				local generation=wheelSnapGeneration
				wheelSnapTimer=taskAPI.delay(.12,function()if generation~=wheelSnapGeneration then return end;wheelSnapTimer=nil;if alive and page.Alive then ScrollLayout.snapTree(tree)end end)
			end
			return
		end
		if event.Position and (event.UserInputType==Enum.UserInputType.MouseMovement or event.UserInputType==Enum.UserInputType.Touch) then
			local node=hit(event.Position);local data=eventData:Pointer(event,"move")
			if not data then return end
			local target,_,record=captures:Dispatch("pointermove",node,data)
			if event.UserInputType==Enum.UserInputType.Touch then touchEvent(event,"move",node,data,record)
			elseif target and not(record and record.Suppressed)then events:Emit(target,"mousemove",data)end
			if not alive or not page.Alive then return end
		end
		if textareaResize:Move(event) then return end
		if rangeDrag:Move(event) then
			if alive and page.Alive and event.UserInputType == Enum.UserInputType.MouseMovement then hover(hoverTarget(event.Position),event.Position)end
			return
		end
		local mediaMove=pressedMedia and pointer and (event==pointer
			or (pointer.UserInputType==Enum.UserInputType.MouseButton1 and event.UserInputType==Enum.UserInputType.MouseMovement))
		if mediaMove and media:Move(event.Position) then
			if alive and page.Alive and event.UserInputType==Enum.UserInputType.MouseMovement then hover(hoverTarget(event.Position),event.Position)end
			return
		end
		if popup.Control then
			popup:Move(event,playerGui:GetGuiObjectsAtPosition(event.Position.X,event.Position.Y))
		elseif event.UserInputType == Enum.UserInputType.MouseMovement then hover(hoverTarget(event.Position),event.Position)end
		if textSelection.Dragging and event.UserInputType == Enum.UserInputType.MouseMovement then
			textSelection:Move(playerGui:GetGuiObjectsAtPosition(event.Position.X,event.Position.Y),event.Position)
		end
		if pointer and pointer.UserInputType == Enum.UserInputType.Touch and event == pointer and startPosition then
			if (event.Position-startPosition).Magnitude > 6 then cancelPress() end
		end
	end)
	connect(input.InputEnded,function(event: any)
		if not alive or not page.Alive then return end
		if event.UserInputType==Enum.UserInputType.Keyboard and colorPickerKeys[event.KeyCode]then
			colorPickerKeys[event.KeyCode]=nil;return
		end
		if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
			if colorPopup:Finish(event)then return end
		end
		local activationData
		local clickTarget,cancelClick
		if event.UserInputType==Enum.UserInputType.Keyboard then
			local editor=input:GetFocusedTextBox()
			if editor and not selectionCopy:IsEditor(editor)and not editableInput:IsEditor(editor)and(not focused or editor~=focused.Item.Editor)then return end
			if copyModifier(event.KeyCode)then selectionCopy:Release()end
			editHint=nil
			editableInput:EndKey(event.KeyCode)
			if event.KeyCode==blockedKey then blockedEdit,blockedKey=nil,nil end
			local keyTarget=model:GetActiveElement()or page.Document
			local up=eventData:Keyboard(event,"up");activationData={detail=0,isTrusted=true,composed=true,altKey=up.altKey,ctrlKey=up.ctrlKey,metaKey=up.metaKey,shiftKey=up.shiftKey}
			local emitted=events:Emit(keyTarget,"keyup",up)
			if emitted.DefaultPrevented then cancelPress();return end
		elseif event.Position and (event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.MouseButton2 or event.UserInputType==Enum.UserInputType.MouseButton3 or event.UserInputType==Enum.UserInputType.Touch)then
			local canceled=Enum.UserInputState and event.UserInputState==Enum.UserInputState.Cancel
			local node=hit(event.Position);local up=eventData:Pointer(event,if canceled then "cancel"else "up");if not up then return end
			activationData=table.clone(up);activationData.detail=1
			local target,_,record=captures:Dispatch(if canceled then "pointercancel"elseif up.pointerType=="mouse"and up.buttons~=0 then "pointermove"else "pointerup",node,up)
			if event.UserInputType==Enum.UserInputType.Touch then touchEvent(event,if canceled then "cancel"else "up",node,up,record)end
			clickTarget=record and (record.UpCapture or record.Captured);cancelClick=canceled or(record and record.CancelClick)
			if target and not canceled and record and not record.Suppressed then
				if event.UserInputType~=Enum.UserInputType.Touch then events:Emit(target,"mouseup",up)
				elseif up.isPrimary and not cancelClick and pointer==event then local down=table.clone(up);down.buttons=1;events:Emit(target,"mousedown",down);events:Emit(target,"mouseup",up)end
			end
			local api=topLayer();if api then api:PointerUp(event.Position,node)end
			if event.UserInputType==Enum.UserInputType.MouseButton2 or event.UserInputType==Enum.UserInputType.MouseButton3 then
				local down=auxiliaryPresses[up.button];auxiliaryPresses[up.button]=nil
				if down and target and not canceled then local ancestors,n={},down;while n do ancestors[n]=true;n=inclusiveParent(n)end;n=clickTarget or target;while n and not ancestors[n]and not clickTarget do n=inclusiveParent(n)end;if n then events:Emit(n,"auxclick",activationData)end end;return
			end
		end
		if not alive or not page.Alive then return end
		if event.UserInputType==Enum.UserInputType.Touch and eventData:TouchCount()==0 then releaseTouchScrolls()end
		if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
			if temporalPopup:Finish(event)then return end
		end
		if event.UserInputType==Enum.UserInputType.MouseButton1 then
			local selected=textSelection.Dragging and copyEligible and not cancelClick
			textSelection:Finish()
			if selected then
				local generation=copyGeneration
				-- Let mouseup/click handlers finish before taking native focus.
				-- Preparing before C is pressed preserves the first native copy.
				taskAPI.defer(function()
					if alive and page.Alive and generation==copyGeneration and not editableInput.Host then selectionCopy:Arm()end
				end)
			end
		end
		-- A fragment link starts its own targeted scroll tween. Snapping every
		-- scrollport first scans the whole document and can start a competing tween.
		if (event.UserInputType==Enum.UserInputType.Touch or event.UserInputType==Enum.UserInputType.MouseButton1)
			and not pressedLink then ScrollLayout.snapTree(tree) end
		if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch and pointer==event then cssState("active",nil) end
		if textareaResize:Finish(event) then if not textareaResize:IsActive() then cursor:Release() end; return end
		if popup.Control and (event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch) then
			local popupControl=popup.Control
			if popup:Finish(event,playerGui:GetGuiObjectsAtPosition(event.Position.X,event.Position.Y)) then
				-- Native browser datalist selection keeps the input focused. Restore
				-- Roblox focus without reopening the just-closed suggestion popup.
				local editor=popupControl and popupControl.Item.Editor
				if popupControl and popupControl.Datalist and editor and not editor:IsFocused() then
					suppressDatalistOpen=true; editor:CaptureFocus(); suppressDatalistOpen=false
				end
				cursor:Refresh(event.Position); return
			end
		end
		if pointer == event or (pointer and pointer.UserInputType == Enum.UserInputType.MouseButton1 and event.UserInputType == Enum.UserInputType.MouseButton1) then
			rangeDrag:Finish(event)
			if not alive or not page.Alive then return end
			if pressed and pressed.Type == "range" and event.UserInputType == Enum.UserInputType.MouseButton1 then hover(hit(event.Position),event.Position) end
			if not alive or not page.Alive then return end
			local releasedNode=clickTarget or hit(event.Position)
			local generic=pressedNode
			local c=pressed; local target=control(releasedNode)
			local link=pressedLink; local targetLink=Links.find(releasedNode)
			local mediaItem=pressedMedia;local targetMedia=media:Resolve(releasedNode)
			local mediaDragged=if mediaItem then media:Finish(mediaItem,event.Position) else false
			local direction=if c and c.NumberPressed == NumberView.direction(c,event.Position) then c.NumberPressed else nil
			local optionIndex=if c and c.SelectList then listOption(c,playerGui:GetGuiObjectsAtPosition(event.Position.X,event.Position.Y)) else nil
			local optionPressed=if c then c.OptionPressed else nil
			local additive,range=if c then c.OptionAdditive else false,if c then c.OptionRange else false
			cancelPress()
			if cancelClick then return end
			if clickTarget then
				-- Capture controls the click target even after implicit release and
				-- when it differs from the original down target. Keep preactivation
				-- and canceled native defaults in the ordinary control/link path.
				if target then model:Activate(target,if target==c then direction else nil,false,activationData,clickTarget)
				elseif targetLink then Links.activate(page,events,targetLink,diagnostic,activationData,clickTarget)
				elseif targetMedia then local click=events:Emit(clickTarget,"click",activationData);if not click.DefaultPrevented and not mediaDragged then media:Activate(targetMedia,event.Position)end
				else events:Emit(clickTarget,"click",activationData)end
				return
			end
			if c then if c == target then
				if c.SelectList then
					if optionPressed and optionPressed==optionIndex then model:Select(c,optionIndex,true,additive,range) end
				else model:Activate(c,direction,false,activationData) end
			end
			elseif link then
				if link == targetLink then Links.activate(page,events,link,diagnostic,activationData)
				elseif ElementNames.html(link,'area')and ShadowTree.Connected(link,page.Document)and releasedNode then
					-- A live map can change between down and up. The click targets
					-- their common ancestor, or the same now href-less area; removed
					-- down shapes do not dispatch a late click.
					local ancestors,current={},link
					while current do ancestors[current]=true;current=inclusiveParent(current)end
					current=releasedNode;while current and not ancestors[current]do current=inclusiveParent(current)end
					if current then events:Emit(current,'click',activationData)end
				end
			elseif mediaItem then if not mediaDragged and mediaItem==targetMedia then local click=events:Emit(mediaItem.Node,"click",activationData);if not click.DefaultPrevented then media:Activate(mediaItem,event.Position) end end
			elseif generic and releasedNode then
				local ancestors,current={},generic
				while current do ancestors[current]=true;current=inclusiveParent(current)end
				current=releasedNode
				while current and not ancestors[current] do current=inclusiveParent(current)end
				if current and alive and page.Alive then events:Emit(current,"click",activationData) end
			end
		elseif keyDown and event.KeyCode == keyDown then
			local c,link=pressed,pressedLink; cancelPress()
			if c and c == focused then model:Activate(c,nil,false,activationData) elseif link and link == focusedLink then Links.activate(page,events,link,diagnostic,activationData) end
		end
	end)
	connect(input.WindowFocusReleased,function()
		copyGeneration+=1;copyEligible=false;selectionCopy:Release()
		table.clear(colorPickerKeys)
		captures:CancelAll()
		for _,item in eventData:CancelTouches()do events:Emit(item.Target,"touchcancel",item.Data,{Cancelable=false,Composed=true})end
		eventData:Reset();compatibilitySuppressed=false
		editHint=nil;blockedEdit,blockedKey=nil,nil;table.clear(auxiliaryPresses)
		interacted=true
		releaseTouchScrolls()
		releaseWheelScrolls()
		textSelection:Finish()
		validation:Close()
		textareaResize:Cancel()
		popup:Close();temporalPopup:Close();colorPopup:Close(); cancelPress()
		if alive and page.Alive then hover(nil); focus(nil) end
	end)
	function page:On(target: any,kind: any,callback: any?): any
		if type(kind) == "function" then
			-- Keep the Lua page observer API while DOM listeners use native phases.
			local capture=target=="focus" or target=="blur" or target=="pointerenter" or target=="pointerleave" or target=="invalid"
			return events:On(nil,target,kind,capture)
		end
		local node=if type(target) == "string" then DOM.findById(self.Document,target) else target
		assert(node,"Unknown event target")
		return events:On(node,kind,callback)
	end
	function page:GetValue(id: string): any local c=model:Resolve(id); return if c then c.Value else nil end
	function page:SetValue(id: string,value: any) local c=model:Resolve(id); assert(c,"Unknown control"); if c.Type == "select" then popup:ResetSearch() end; model:SetValue(c,value) end
	function page:GetChecked(id: string): any local c=model:Resolve(id); return if c then c.Checked else nil end
	function page:SetChecked(id: string,value: boolean) local c=model:Resolve(id); assert(c,"Unknown control"); model:SetChecked(c,value) end
	function page:Focus(id: string) local c=model:Resolve(id); assert(c,"Unknown control"); focus(c) end
	function page:SnapScrolls(): boolean return ScrollLayout.snapTree(tree) end
	function page:GetFormData(id: string): any local form=DOM.findById(self.Document,id); assert(form and form.Name == "form","Unknown form"); return model:Data(form) end
	function page:Reset(id: string)
		local form=DOM.findById(self.Document,id);assert(form and form.Name=="form","Unknown form")
		popup:ResetSearch();if model:Reset(form)then popup:Close()end
	end
	-- Wait for measured geometry once. Later ready notifications are resize/dirty passes.
	local hasAutofocus=false
	for _,c in tree.Controls do if c.Node.Attributes.autofocus ~= nil then hasAutofocus=true; break end end
	if hasAutofocus then
		local consumed=false
		local readyConnection
		local presentedConnection
		local function applyAutofocus()
			if consumed or not alive or not page.Alive or page.Root:GetAttribute("Status") ~= "ready"
				or page.Root:GetAttribute("Presented") == false then return end
			consumed=true
			if readyConnection then readyConnection:Disconnect() end
			if presentedConnection then presentedConnection:Disconnect() end
			-- Preserve user/API focus, including a TextBox outside this page.
			if interacted or focusRevision > 0 or focused or input:GetFocusedTextBox() then return end
			for _,c in tree.Controls do
				if c.Node.Attributes.autofocus == nil or c.Disabled or c.DisplayOnly or c.Type == "output" or c.Type == "hidden"
					or c.Item.Style.Visibility == "hidden" or hidden(c) then continue end
				local gui,visible=c.Item.Gui,true
				while gui do
					if (gui:IsA("GuiObject") and not gui.Visible) or (gui:IsA("LayerCollector") and not gui.Enabled) then visible=false; break end
					gui=gui.Parent
				end
				if visible then focus(c); break end
			end
		end
		readyConnection=page.Root:GetAttributeChangedSignal("Status"):Connect(applyAutofocus)
		presentedConnection=page.Root:GetAttributeChangedSignal("Presented"):Connect(applyAutofocus)
		table.insert(connections,readyConnection)
		table.insert(connections,presentedConnection)
		applyAutofocus()
	end
	return destroy
end
return Controller
