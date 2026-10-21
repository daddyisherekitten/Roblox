--!strict
local DOM = require(script.Parent.Parent.DOM.Node)
local BoxTransform=require(script.Parent.BoxTransform)
local TopLayerLayout=require(script.Parent.TopLayerLayout)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Dialog = {}
local DEFAULT_BACKDROP_COLOR = Color3.new(0, 0, 0)
local DEFAULT_BACKDROP_TRANSPARENCY = 0.9

local function stateFor(tree: any, target: any): any?
	local node = if type(target) == "string" then DOM.findById(tree.Node, target) else target
	return node and tree.DialogsByNode and tree.DialogsByNode[node] or nil
end

local function descendant(node: any, ancestor: any): boolean
	return ShadowTree.InclusiveDescendant(node,ancestor)
end

local function rendered(tree: any, state: any): boolean
	return not state.Box.Style.Hidden and not state.Box.HiddenByAncestor
		and not (tree.IsContentSkipped and tree:IsContentSkipped(state.Node))
end

local function topModal(tree: any, renderedOnly: boolean?): any?
	local top
	for index,state in tree.Dialogs or {} do
		if state.Open and state.Modal and (not renderedOnly or rendered(tree,state))
			and(not top or(state.Order or index)>(top.Order or 0))then top=state end
	end
	return top
end

function Dialog.prune(tree: any)
	if not tree.NodeBoxes then return end
	for index=#(tree.Dialogs or {}),1,-1 do
		local state=tree.Dialogs[index];local node=state.Node
		if not ShadowTree.Connected(node,tree.Node) or tree.NodeBoxes[node]~=state.Box then
			if tree.DialogsByNode and tree.DialogsByNode[node]==state then tree.DialogsByNode[node]=nil end
			table.remove(tree.Dialogs,index)
		end
	end
end

function Dialog.host(root: any, factory: any): any
	local backdrop = factory.create("Frame", root, {
		Name = "DialogBackdrop", BackgroundColor3 = DEFAULT_BACKDROP_COLOR, BackgroundTransparency = DEFAULT_BACKDROP_TRANSPARENCY,
		BorderSizePixel = 0, Visible = false, Active = false, ZIndex = 1000,
	})
	if backdrop.SetAttribute then
		backdrop:SetAttribute("HTMLInputBlocker",true)
		backdrop:SetAttribute("HTMLPageOverlay",true)
		backdrop:SetAttribute("HTMLCursorSurface",true)
	end
	local layer = factory.create("Frame", root, {
		Name = "DialogTopLayer", BackgroundTransparency = 1, BorderSizePixel = 0,
		Visible = false, Active = false, ZIndex = 1001,
	})
	if layer.SetAttribute then layer:SetAttribute("HTMLHitTestPassthrough", true);layer:SetAttribute("HTMLPageOverlay",true) end
	return {Backdrop = backdrop, Layer = layer, Parent = root}
end

function Dialog.attachViewport(tree: any, root: any)
	local host = tree.DialogHost
	if not host or not root.Parent then return end
	host.Parent, host.Root = root.Parent, root
	host.Backdrop.Parent = host.Parent
	host.Layer.Parent = host.Parent
	Dialog.apply(tree)
end

function Dialog.destroyHost(tree: any)
	local host = tree.DialogHost
	if not host then return end
	for _, object in {host.Layer,host.Backdrop} do
		if object and object.Parent then object:Destroy() end
	end
	tree.DialogHost=nil
end

function Dialog.new(node: any, box: any, host: any): any
	local state = {Node = node, Box = box, Open = node.Attributes.open ~= nil, Modal = false, ReturnValue = "",NaturalParent=box.TopLayerParent or BoxTransform.target(box).Parent}
	box.TopLayer = true
	BoxTransform.target(box).Parent = host.Layer
	BoxTransform.target(box).Visible = state.Open;box.Gui.Visible=state.Open
	return state
end

function Dialog.apply(tree: any)
	Dialog.prune(tree)
	local modal = topModal(tree)
	local host=tree.DialogHost
	local members={}
	for _,state in tree.Dialogs or {}do
		local popover=tree.PopoversByNode and tree.PopoversByNode[state.Node]
		local popoverOpen=popover and popover.Open==true
		local active=(state.Open and state.Modal)or popoverOpen==true
		TopLayerLayout.flags(tree,state.Box,active,active or(popover~=nil and not state.Open),not state.Open and not popoverOpen)
		if state.Open and state.Modal then members[state.Node]=true end
	end
	TopLayerLayout.syncState(tree,"modal",members)
	for index, state in tree.Dialogs or {} do
		local surface=BoxTransform.target(state.Box)
		local popover=tree.PopoversByNode and tree.PopoversByNode[state.Node]
		local popoverOpen=popover and popover.Open
		if host then
			surface.Parent=if state.Open and not state.Modal and not popoverOpen then TopLayerLayout.home(tree,state,host.Root or host.Layer) else host.Layer
		end
		local visible=(state.Open or popoverOpen==true)and rendered(tree,state)
		surface.Visible=visible;state.Box.Gui.Visible=visible
		if state.Box.TopLayerActive then surface.ZIndex=1000+(state.Order or index)*2;state.Box.Gui.ZIndex=surface.ZIndex end
	end
	if host then
		-- Rendering suppression leaves HTML modal membership and inertness intact.
		local paintedModal=topModal(tree,true)
		local style = paintedModal and paintedModal.BackdropStyle
		host.Backdrop.Parent=host.Layer
		host.Backdrop.BackgroundColor3=if style and style.Background then style.Background else DEFAULT_BACKDROP_COLOR
		host.Backdrop.BackgroundTransparency=if style and style.Background then 1-(style.BackgroundAlpha or 1)else DEFAULT_BACKDROP_TRANSPARENCY
		host.Backdrop.Visible=paintedModal~=nil
		local anyPopover=false
		for _,state in tree.Popovers or {}do
			local dialog=tree.DialogsByNode and tree.DialogsByNode[state.Node]
			BoxTransform.target(state.Box).Parent=if dialog and dialog.Open and not dialog.Modal and not state.Open then TopLayerLayout.home(tree,dialog,host.Root or host.Layer) else host.Layer
			if state.Open and rendered(tree,state) then anyPopover=true end
		end
		if tree.PopoverHost then tree.PopoverHost.Layer.Visible=false end
		host.Layer.Visible=not tree.PresentationHidden and (paintedModal~=nil or anyPopover);host.Layer.ZIndex=1000
		if paintedModal then host.Backdrop.ZIndex=999+(paintedModal.Order or 1)*2 end
	end
	tree.ActiveModal = modal
end

function Dialog.surfaceAt(tree: any, objects: any): string?
	local host = tree.DialogHost
	if not host or not host.Layer.Visible then return nil end
	for _, object in objects do
		if object == host.Backdrop and host.Backdrop.Visible then return "backdrop" end
		if object == host.Layer then return "top-layer" end
	end
	return nil
end

function Dialog.open(tree: any, target: any, modal: boolean?): any?
	local state = stateFor(tree, target)
	if not state then return nil end
	state.Open, state.Modal = true, modal == true
	tree.TopLayerSequence=(tree.TopLayerSequence or 0)+1;state.Order=tree.TopLayerSequence
	state.Node.Attributes.open = ""
	Dialog.apply(tree)
	return state
end

function Dialog.close(tree: any, target: any, returnValue: any?): any?
	local state = stateFor(tree, target)
	if not state or not state.Open then return nil end
	state.Open, state.Modal = false, false
	state.ReturnValue = if returnValue == nil then state.ReturnValue else tostring(returnValue)
	state.Node.Attributes.open = nil
	Dialog.apply(tree)
	return state
end

function Dialog.command(tree: any, control: any): any?
	local attributes = control.Node.Attributes
	local command, target = string.lower(attributes.command or ""), attributes.commandfor
	if target == nil or command == "" then return nil end
	if command == "show-modal" then return Dialog.open(tree, target, true)
	elseif command == "show" then return Dialog.open(tree, target, false)
	elseif command == "close" or command == "request-close" then return Dialog.close(tree, target, control.Value) end
	return nil
end

function Dialog.closeForm(tree: any, form: any, submitter: any?): any?
	local node = form.Parent
	while node and node.Name ~= "dialog" do node = node.Parent end
	if not node then return nil end
	return Dialog.close(tree, node, if submitter then submitter.Value else "")
end

function Dialog.cancel(tree: any): any?
	local state = topModal(tree)
	if not state or string.lower(state.Node.Attributes.closedby or "") == "none" then return nil end
	return Dialog.close(tree, state.Node)
end

function Dialog.dismissAt(tree: any, position: any): any?
	local state = topModal(tree)
	if not state or string.lower(state.Node.Attributes.closedby or "") ~= "any" then return nil end
	if rendered(tree,state) then
		local gui = state.Box.Gui
		local origin, size = gui.AbsolutePosition, gui.AbsoluteSize
		if position.X >= origin.X and position.X <= origin.X + size.X
			and position.Y >= origin.Y and position.Y <= origin.Y + size.Y then return nil end
	end
	return Dialog.close(tree, state.Node)
end

function Dialog.hidden(tree: any, node: any): boolean
	if node and tree.IsContentSkipped and tree:IsContentSkipped(node) then return true end
	local branch = node
	while branch do
		local state = tree.DialogsByNode and tree.DialogsByNode[branch]
		if state then local popover=tree.PopoversByNode and tree.PopoversByNode[branch];return not state.Open and not(popover and popover.Open)end
		branch = branch.Parent
	end
	return false
end

function Dialog.allows(tree: any, node: any): boolean
	if node and tree.IsContentSkipped and tree:IsContentSkipped(node) then return false end
	local modal = tree.ActiveModal or topModal(tree)
	return modal == nil or descendant(node, modal.Node)
end

function Dialog.arrange(tree: any, root: any)
	local host = tree.DialogHost
	if not host then return end
	local rootPosition=root.AbsolutePosition or Vector2.new(0,0)
	local parentPosition=if host.Parent and host.Parent.AbsolutePosition then host.Parent.AbsolutePosition else Vector2.new(0,0)
	local position=Vector2.new(rootPosition.X-parentPosition.X,rootPosition.Y-parentPosition.Y)
	local size=root.AbsoluteWindowSize or root.AbsoluteSize
	host.Backdrop.Position, host.Backdrop.Size = UDim2.fromOffset(0,0), UDim2.fromOffset(size.X, size.Y)
	host.Layer.Position, host.Layer.Size = UDim2.fromOffset(position.X, position.Y), UDim2.fromOffset(size.X, size.Y)
	for _, state in tree.Dialogs or {} do
		local box = state.Box
		if box.OuterWidth==nil or box.OuterHeight==nil then continue end
		local popover=tree.PopoversByNode and tree.PopoversByNode[state.Node]
		if popover and popover.Open then continue end
		TopLayerLayout.paint(box,root)
	end
	-- Normal layout assigns document paint ranks, including to the dialog's
	-- composed surface. Restore its top-layer rank above the modal backdrop.
	Dialog.apply(tree)
end

return Dialog
