--!strict
-- Light-tree ownership and the composed tree are deliberately separate.
-- Distribution writes only assignment metadata, never Parent or Children.
local ElementNames=require(script.Parent.ElementNames)
local ShadowTree = {}

function ShadowTree.Root(node: any, composed: boolean?): any
	while node do
		if node.Parent then node = node.Parent
		elseif composed and node.Kind == "ShadowRoot" and node.Host then node = node.Host
		else return node end
	end
	return nil
end

function ShadowTree.Connected(node: any, document: any?): boolean
	local root = ShadowTree.Root(node, true)
	return root ~= nil and (if document then root == document else root.Kind == "Document")
end

function ShadowTree.InclusiveDescendant(node: any, ancestor: any): boolean
	while node do
		if node == ancestor then return true end
		node = node.Parent or (if node.Kind == "ShadowRoot" then node.Host else nil)
	end
	return false
end

function ShadowTree.Slots(root: any): any
	local slots, pending = {}, {root}
	while #pending > 0 do
		local node = table.remove(pending)
		if node.Kind == "Element" and ElementNames.htmlName(node) == "slot" and (not node.NamespaceURI or node.NamespaceURI == "http://www.w3.org/1999/xhtml") then table.insert(slots, node) end
		for i = #(node.Children or {}), 1, -1 do table.insert(pending, node.Children[i]) end
	end
	return slots
end

function ShadowTree.Distribute(root: any, signal: any?): boolean
	if not root or root.Kind ~= "ShadowRoot" or not root.Host then return false end
	local slots, first, nextAssignments = ShadowTree.Slots(root), {}, {}
	for _, slot in slots do
		nextAssignments[slot] = {}
		local name = slot.Attributes.name or ""
		if first[name] == nil then first[name] = slot end
	end
	local oldSlots = root.DistributedSlots or {}
	for _, slot in oldSlots do for _, node in slot.AssignedNodes or {} do if node.AssignedSlot == slot then node.AssignedSlot = nil end end end
	for _, slot in slots do for _, node in slot.AssignedNodes or {} do if node.AssignedSlot == slot then node.AssignedSlot = nil end end end
	if root.SlotAssignment == "manual" then
		for _, slot in slots do
			for _, child in slot.ManualAssignedNodes or {} do
				if child.Parent == root.Host and (child.Kind == "Element" or child.Kind == "Text") and child.ManualSlot == slot then table.insert(nextAssignments[slot], child); child.AssignedSlot = slot end
			end
		end
	else
		for _, child in root.Host.Children do
			if child.Kind == "Element" or child.Kind == "Text" then
				local slot = first[if child.Kind == "Element" then child.Attributes.slot or "" else ""]
				if slot then table.insert(nextAssignments[slot], child); child.AssignedSlot = slot end
			end
		end
	end
	local changed, seen = false, {}
	local function update(slot: any, assignments: any)
		if seen[slot] then return end; seen[slot] = true
		local previous = slot.AssignedNodes or {}
		local different = #previous ~= #assignments
		if not different then for i, node in assignments do if previous[i] ~= node then different = true; break end end end
		slot.AssignedNodes = assignments
		if different then changed = true; if signal then signal(slot) end end
	end
	for _, slot in slots do update(slot, nextAssignments[slot]) end
	for _, slot in oldSlots do if not nextAssignments[slot] then update(slot, {}) end end
	root.DistributedSlots = slots
	return changed
end

function ShadowTree.Assigned(slot: any, flatten: boolean?): any
	if ShadowTree.Root(slot).Kind ~= "ShadowRoot" then return {} end
	local result, active = {}, {}
	local function visit(current: any)
		if active[current] then return end; active[current] = true
		local values = current.AssignedNodes or {}
		if flatten and #values == 0 then values = current.Children or {} end
		for _, node in values do
			if flatten and node.Kind == "Element" and ElementNames.htmlName(node) == "slot" and ShadowTree.Root(node).Kind == "ShadowRoot" then visit(node)
			else table.insert(result, node) end
		end
		active[current] = nil
	end
	visit(slot)
	return result
end

function ShadowTree.FlatChildren(node: any): any
	if node.InternalShadowRoot then return node.InternalShadowRoot.Children end
	if node.Kind == "Element" and ElementNames.htmlName(node) == "slot" and ShadowTree.Root(node).Kind == "ShadowRoot" then
		local assigned = node.AssignedNodes or {}
		return if #assigned > 0 then assigned else node.Children
	end
	return node.Children or {}
end

function ShadowTree.FlatParent(node: any): any
	if node.AssignedSlot then return node.AssignedSlot end
	local parent = node.Parent
	if parent and parent.Kind == "ShadowRoot" then return parent.Host end
	if parent and parent.InternalShadowRoot then return nil end
	if parent and ElementNames.htmlName(parent) == "slot" and #(parent.AssignedNodes or {}) > 0 then return nil end
	return parent
end

function ShadowTree.EventParent(node: any, composed: boolean, originalTarget: any): any
	if node.AssignedSlot then return node.AssignedSlot end
	if node.Kind == "ShadowRoot" then
		if not composed and ShadowTree.Root(originalTarget) == node then return nil end
		return node.Host
	end
	return node.Parent
end

function ShadowTree.Retarget(target: any, current: any): any
	while target do
		local root = ShadowTree.Root(target)
		if not root or root.Kind ~= "ShadowRoot" or (current and ShadowTree.InclusiveDescendant(current, root)) then return target end
		target = root.Host
	end
	return nil
end

function ShadowTree.VisiblePath(path: any, current: any): any
	local result = {}
	for _, node in path do
		local visible, root = true, ShadowTree.Root(node)
		while root and root.Kind == "ShadowRoot" do
			if root.Mode == "closed" and not ShadowTree.InclusiveDescendant(current, root) then visible = false; break end
			root = ShadowTree.Root(root.Host)
		end
		if visible then table.insert(result, node) end
	end
	return result
end

return ShadowTree
