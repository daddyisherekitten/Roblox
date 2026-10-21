--!strict
-- Plan every affected sibling list before touching the data DOM. Renderer
-- guards run for the complete batch, including removals and source parents.
local Node = require(script.Parent.Parent.DOM.Node)
local Attributes = require(script.Parent.Parent.DOM.AttributeStore)
local Tree = {}

function Tree.root(node: any): any
	while node.Parent do node = node.Parent end
	return node
end

function Tree.contains(parent: any, child: any): boolean
	while child do
		if child == parent then return true end
		child = child.Parent
	end
	return false
end

function Tree.descendants(root: any, elementsOnly: boolean?): any
	local result, pending = {}, {}
	for index = #root.Children, 1, -1 do table.insert(pending, root.Children[index]) end
	while #pending > 0 do
		local node = table.remove(pending)
		if not elementsOnly or node.Kind == "Element" then table.insert(result, node) end
		for index = #node.Children, 1, -1 do table.insert(pending, node.Children[index]) end
	end
	return result
end

-- Model conversion to a temporary fragment without prematurely moving nodes.
-- Repeating a node moves it to its last position; a consumed fragment is empty.
function Tree.flatten(nodes: any): any
	local result, consumed, positions = {}, {}, {}
	local function add(node: any)
		local index = positions[node]
		if index then result[index] = false end
		table.insert(result, node)
		positions[node] = #result
	end
	for _, node in nodes do
		if node.Kind == "DocumentFragment" or node.Kind == "ShadowRoot" then
			if not consumed[node] then
				consumed[node] = true
				for _, child in node.Children do if not positions[child] then add(child) end end
			end
		else add(node) end
	end
	-- Marking old occurrences preserves the move order without searching and
	-- shifting the growing array for each argument. Compact just once.
	local size = 0
	for index = 1, #result do
		local node = result[index]
		if node then size += 1; result[size] = node end
	end
	for index = #result, size + 1, -1 do result[index] = nil end
	return result
end

function Tree.plan(parent: any, additions: any, before: any?, removals: any?, validityReference: any?): any
	assert(parent.Kind == "Document" or parent.Kind == "Element" or parent.Kind == "DocumentFragment" or parent.Kind == "ShadowRoot", "DOM insertion requires a container")
	assert(before == nil or before.Parent == parent, "Reference node is not a child of this parent")
	removals = removals or {}
	local omitted, oldParents = {}, {}
	for _, child in removals do
		assert(child.Parent == parent, "Node is not a child of this parent")
		omitted[child] = true
	end
	for _, child in additions do
		Node.validateInsert(parent, child, validityReference or before, removals)
		omitted[child] = true
		if child.Parent then oldParents[child.Parent] = true end
	end
	local index = if before then table.find(parent.Children, before) else #parent.Children + 1
	assert(index, "Inconsistent DOM reference")
	local final, added = {}, false
	for position, child in parent.Children do
		if position >= index and not added then
			for _, addition in additions do table.insert(final, addition) end
			added = true
		end
		if not omitted[child] then table.insert(final, child) end
	end
	if not added then for _, addition in additions do table.insert(final, addition) end end
	Node.validateChildren(parent, final)
	local changed = #final ~= #parent.Children
	if not changed then for position, child in final do if parent.Children[position] ~= child then changed = true; break end end end
	return {Parent = parent, Additions = additions, Removals = removals, Final = final, OldParents = oldParents, Changed = changed}
end

function Tree.validate(plan: any, host: any)
	if not host.ValidateStructure then return end
	for _, child in plan.Additions do host.ValidateStructure(plan.Parent, child, child.Parent) end
	for _, child in plan.Removals do
		if not table.find(plan.Additions, child) then host.ValidateStructure(nil, child, plan.Parent) end
	end
end

function Tree.ancestors(node: any): any
	local nodes={};while node do table.insert(nodes,node);node=node.Parent end;return nodes
end

function Tree.remove(parent: any,child: any,host: any,suppress: boolean?,preservingMove: boolean?)
	local index=table.find(parent.Children,child)
	assert(index and child.Parent==parent,"Node is not a child of this parent")
	if host.BeforeRemove then host.BeforeRemove(child,preservingMove)end
	local mutation=if host.Mutation and not suppress then {Type="childList",Target=parent,RemovedNodes={child},AddedNodes={},
		PreviousSibling=parent.Children[index-1],NextSibling=parent.Children[index+1],Ancestors=Tree.ancestors(parent),Move=preservingMove==true} else nil
	Node.removeChild(parent,child)
	if mutation then host.Mutation(mutation) end
end

function Tree.commit(plan: any, host: any, connected: any)
	if not plan.Changed and not host.Mutation then return end
	local dirty = {}
	for parent in plan.OldParents do if plan.Changed and connected(parent) then dirty[parent] = true end end
	if plan.Changed and connected(plan.Parent) then dirty[plan.Parent] = true end
	-- A descendant can precede its ancestor in a batch. Detach every addition
	-- before rebuilding the target, keeping each retained node and wrapper.
	for _, child in plan.Additions do if child.Parent then
		local source=child.Parent
		if (source.Kind=="DocumentFragment" or source.Kind=="ShadowRoot") and host.Mutation then
			local removed={};for _,candidate in source.Children do if table.find(plan.Additions,candidate)then table.insert(removed,candidate)end end
			local ancestors=Tree.ancestors(source)
			for _,candidate in removed do Tree.remove(source,candidate,host,true)end
			if #removed>0 then host.Mutation({Type="childList",Target=source,AddedNodes={},RemovedNodes=removed,Ancestors=ancestors})end
		else Tree.remove(source,child,host,false,plan.Move)end
	end end
	local removed,first,last={},nil,nil
	for index,child in plan.Parent.Children do if table.find(plan.Removals,child)then first=first or index;last=index;table.insert(removed,child)end end
	local previous=if first then plan.Parent.Children[first-1]else nil
	local nextSibling=if last then plan.Parent.Children[last+1]else nil
	local ancestors=if host.Mutation then Tree.ancestors(plan.Parent)else nil
	for _, child in removed do Tree.remove(plan.Parent,child,host,true,plan.Move) end
	if host.BeforeInsert and #plan.Additions>0 then host.BeforeInsert(plan.Parent,table.find(plan.Final,plan.Additions[1])-1,#plan.Additions)end
	table.clear(plan.Parent.Children)
	for _, child in plan.Final do child.Parent = plan.Parent; table.insert(plan.Parent.Children, child) end
	if host.Mutation and(#plan.Additions>0 or #removed>0)then
		if #plan.Additions>0 then
			local at=table.find(plan.Final,plan.Additions[1]);previous=plan.Final[at-1];nextSibling=plan.Final[at+#plan.Additions]
		end
		host.Mutation({Type="childList",Target=plan.Parent,AddedNodes=table.clone(plan.Additions),RemovedNodes=removed,
			PreviousSibling=previous,NextSibling=nextSibling,Ancestors=ancestors,Move=plan.Move==true})
	end
	for parent in dirty do host.Changed(parent, "children") end
	-- Post-connection steps run after the complete atomic insertion. Earlier
	-- scripts may remove later additions; the host checks connection again.
	if host.PostInsert then host.PostInsert(plan.Additions) end
end

function Tree.equal(left: any, right: any): boolean
	local function namespace(node)
		return if node.NamespaceURI==nil and node.Kind=="Element"then "http://www.w3.org/1999/xhtml"elseif node.NamespaceURI==""then nil else node.NamespaceURI
	end
	local pending = {{left, right}}
	while #pending > 0 do
		local pair = table.remove(pending)
		local a, b = pair[1], pair[2]
		if a.Kind ~= b.Kind or #a.Children ~= #b.Children then return false end
		if a.Kind=="Element"then
			if namespace(a)~=namespace(b)or(a.LocalName or a.Name)~=(b.LocalName or b.Name)or a.Prefix~=b.Prefix then return false end
			local aKeys,bKeys=Attributes.keys(a),Attributes.keys(b)
			if #aKeys~=#bKeys then return false end
			local values={}
			for _,key in bKeys do
				local uri=Attributes.namespace(b,key)or"";values[uri]=values[uri]or{}
				local info=b.AttributeNamespaces and b.AttributeNamespaces[key]
				values[uri][info and info.LocalName or key]=b.Attributes[key]
			end
			for _,key in aKeys do
				local uri=Attributes.namespace(a,key)or"";local info=a.AttributeNamespaces and a.AttributeNamespaces[key]
				if not values[uri]or values[uri][info and info.LocalName or key]~=a.Attributes[key]then return false end
			end
		elseif a.Kind=="Attr"then
			if namespace(a)~=namespace(b)or(a.LocalName or a.Name)~=(b.LocalName or b.Name)or a.Text~=b.Text then return false end
		elseif a.Kind=="DocumentType"then
			if a.Name~=b.Name or a.PublicId~=b.PublicId or a.SystemId~=b.SystemId then return false end
		elseif a.Kind=="ProcessingInstruction"then
			if a.Target~=b.Target or a.Text~=b.Text then return false end
		elseif a.Text~=b.Text then return false end
		for index, child in a.Children do table.insert(pending, {child, b.Children[index]}) end
	end
	return true
end

return Tree
