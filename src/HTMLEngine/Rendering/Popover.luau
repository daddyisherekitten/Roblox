--!strict
-- HTML popovers are hidden until invoked and paint in a viewport top layer.
local DOM = require(script.Parent.Parent.DOM.Node)
local BoxTransform=require(script.Parent.BoxTransform)
local TopLayerLayout=require(script.Parent.TopLayerLayout)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Popover = {}

local function stateFor(tree: any, target: any): any?
	local node = if type(target) == "string" then DOM.findById(tree.Node, target) else target
	return node and tree.PopoversByNode and tree.PopoversByNode[node] or nil
end

local function descendant(node: any, ancestor: any): boolean
	while node do
		if node == ancestor then return true end
		node = node.Parent
	end
	return false
end

local function rendered(tree: any, state: any): boolean
	return not state.Box.Style.Hidden and not state.Box.HiddenByAncestor
		and not (tree.IsContentSkipped and tree:IsContentSkipped(state.Node))
end

function Popover.host(root: any, factory: any): any
	local layer = factory.create("Frame", root, {
		Name = "PopoverTopLayer", BackgroundTransparency = 1, BorderSizePixel = 0,
		Visible = false, Active = false, ClipsDescendants = false, ZIndex = 1100,
	})
	if layer.SetAttribute then
		layer:SetAttribute("HTMLPageOverlay", true)
		layer:SetAttribute("HTMLHitTestPassthrough", true)
	end
	return {Layer = layer, Parent = root}
end

function Popover.attachViewport(tree: any, root: any)
	local host = tree.PopoverHost
	if not host or not root.Parent then return end
	host.Parent = root.Parent
	host.Layer.Parent = host.Parent
	Popover.apply(tree)
end

function Popover.destroyHost(tree: any)
	local host = tree.PopoverHost
	if host and host.Layer and host.Layer.Parent then host.Layer:Destroy() end
	tree.PopoverHost = nil
end

function Popover.new(node: any, box: any, host: any): any
	local mode = string.lower(node.Attributes.popover or "")
	local state = {Node = node, Box = box, Mode = if mode == "" or mode == "auto" then "auto" elseif mode == "hint" then "hint" else "manual", Open = false}
	box.TopLayer = true
	BoxTransform.target(box).Parent = host.Layer
	BoxTransform.target(box).Visible=false;box.Gui.Visible=false
	return state
end

function Popover.prune(tree: any)
	if not tree.NodeBoxes then return end
	for index=#(tree.Popovers or {}),1,-1 do
		local state=tree.Popovers[index];local node=state.Node
		local ancestor=ShadowTree.Connected(node,tree.Node)
		if not ancestor or tree.NodeBoxes[node]~=state.Box or node.Attributes.popover==nil then
			if tree.PopoversByNode and tree.PopoversByNode[node]==state then tree.PopoversByNode[node]=nil end
			table.remove(tree.Popovers,index)
		end
	end
end

function Popover.apply(tree: any)
	Popover.prune(tree)
	local open = {}
	local anyRendered=false
	local members={}
	for _,state in tree.Popovers or {}do
		local dialog=tree.DialogsByNode and tree.DialogsByNode[state.Node]
		local dialogOpen=dialog and dialog.Open==true
		local active=state.Open or(dialogOpen and dialog.Modal==true)or false
		TopLayerLayout.flags(tree,state.Box,active,active or not dialogOpen,not state.Open and not dialogOpen)
		if state.Open then members[state.Node]=true end
	end
	TopLayerLayout.syncState(tree,"popover-open",members)
	local layer=if tree.DialogHost then tree.DialogHost.Layer else tree.PopoverHost and tree.PopoverHost.Layer
	for _, state in tree.Popovers or {} do
		local surface=BoxTransform.target(state.Box)
		local dialog=tree.DialogsByNode and tree.DialogsByNode[state.Node]
		if layer then surface.Parent=if dialog and dialog.Open and not dialog.Modal and not state.Open then TopLayerLayout.home(tree,dialog,tree.DialogHost.Root or layer) else layer end
		local visible=(state.Open or(dialog and dialog.Open==true))and rendered(tree,state)
		surface.Visible=visible==true;state.Box.Gui.Visible=visible==true
		if state.Open then table.insert(open, state) end
		if state.Open and visible then anyRendered=true end
	end
	table.sort(open, function(a, b) return (a.Order or 0) < (b.Order or 0) end)
	for rank,state in open do local z=1000+(state.Order or rank)*2;BoxTransform.target(state.Box).ZIndex=z;state.Box.Gui.ZIndex=z end
	if layer then
		local modal=false;for _,state in tree.Dialogs or {}do if state.Open and state.Modal and rendered(tree,state) then modal=true;break end end
		layer.Visible=not tree.PresentationHidden and (anyRendered or modal);layer.ZIndex=1000
	end
	if tree.DialogHost and tree.PopoverHost then tree.PopoverHost.Layer.Visible=false end
end

function Popover.show(tree: any, target: any, source: any?): any?
	local state = stateFor(tree, target)
	if not state or state.Open then return nil end
	if state.Mode ~= "manual" then
		for _, other in tree.Popovers or {} do
			if other.Open and other.Mode ~= "manual" and (state.Mode == "auto" or other.Mode == "hint")
				and not descendant(state.Node, other.Node) and not descendant(source, other.Node) then
				other.Open = false
			end
		end
	end
	state.Open = true
	tree.TopLayerSequence = (tree.TopLayerSequence or 0) + 1
	state.Order = tree.TopLayerSequence
	Popover.apply(tree)
	return state
end

function Popover.hide(tree: any, target: any): any?
	local state = stateFor(tree, target)
	if not state or not state.Open then return nil end
	state.Open = false
	Popover.apply(tree)
	return state
end

function Popover.command(tree: any, control: any): any?
	local attributes = control.Node.Attributes
	local target = attributes.popovertarget
	if target == nil then return nil end
	local state = stateFor(tree, target)
	if not state then return nil end
	local action = string.lower(attributes.popovertargetaction or "toggle")
	if action == "show" then Popover.show(tree, state.Node, control.Node)
	elseif action == "hide" then Popover.hide(tree, state.Node)
	elseif action == "toggle" then
		if state.Open then Popover.hide(tree, state.Node) else Popover.show(tree, state.Node, control.Node) end
	else return nil end
	return state
end

function Popover.cancel(tree: any): any?
	local top
	for _, state in tree.Popovers or {} do
		if state.Open and state.Mode ~= "manual" and (not top or state.Order > top.Order) then top = state end
	end
	return if top then Popover.hide(tree, top.Node) else nil
end

function Popover.dismissAt(tree: any, position: any, target: any?): any?
	local top
	for _, state in tree.Popovers or {} do
		if state.Open and state.Mode ~= "manual" and (not top or state.Order > top.Order) then top = state end
	end
	if top then
		local state = top
			if descendant(target, state.Node) then return nil end
			if target and target.Attributes and target.Attributes.popovertarget and target.Attributes.popovertarget~=""and target.Attributes.popovertarget == state.Node.Attributes.id then return nil end
			if rendered(tree,state) then
				local gui = state.Box.Gui
				local origin, size = gui.AbsolutePosition, gui.AbsoluteSize
				if position.X >= origin.X and position.X < origin.X + size.X
					and position.Y >= origin.Y and position.Y < origin.Y + size.Y then return nil end
			end
			return Popover.hide(tree, state.Node)
	end
	return nil
end

function Popover.hidden(tree: any, node: any): boolean
	if node and tree.IsContentSkipped and tree:IsContentSkipped(node) then return true end
	while node do
		local state = tree.PopoversByNode and tree.PopoversByNode[node]
		if state then local dialog=tree.DialogsByNode and tree.DialogsByNode[node];return not state.Open and not(dialog and dialog.Open)end
		node = node.Parent
	end
	return false
end

function Popover.arrange(tree: any, root: any)
	local host = tree.PopoverHost
	if not host then return end
	local rootPosition = root.AbsolutePosition or Vector2.new(0, 0)
	local parentPosition = if host.Parent and host.Parent.AbsolutePosition then host.Parent.AbsolutePosition else Vector2.new(0, 0)
	local size = root.AbsoluteWindowSize or root.AbsoluteSize
	host.Layer.Position = UDim2.fromOffset(rootPosition.X - parentPosition.X, rootPosition.Y - parentPosition.Y)
	host.Layer.Size = UDim2.fromOffset(size.X, size.Y)
	for _, state in tree.Popovers or {} do
		local box = state.Box
		if box.OuterWidth==nil or box.OuterHeight==nil then continue end
		local dialog=tree.DialogsByNode and tree.DialogsByNode[state.Node]
		if dialog and dialog.Open and not state.Open then continue end
		TopLayerLayout.paint(box,root)
	end
	-- Layout paint order can update ZIndex; restore top-layer order afterward.
	Popover.apply(tree)
end

return Popover
