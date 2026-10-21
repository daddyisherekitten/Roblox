--!strict
-- Range content algorithms operate on private boundary snapshots. Every tree
-- and CharacterData write goes through the owning DOM bridge and its hooks.
local Strings = require(script.Parent.Strings)
local RangeContents = {}
local HTML = "http://www.w3.org/1999/xhtml"

function RangeContents.install(c: any): any
	local U = c.VM.Undefined
	local function step() c.Check(); c.Step() end
	local function text(node: any): boolean return node.Kind == "Text" or node.Kind == "CDATASection" end
	local function character(node: any): boolean
		return node.Kind == "Text" or node.Kind == "Comment" or node.Kind == "CDATASection" or node.Kind == "ProcessingInstruction"
	end
	local function snapshot(range: any): any
		c.Check()
		local state = c.State(range)
		return {StartNode=state.StartNode, StartOffset=state.StartOffset, EndNode=state.EndNode, EndOffset=state.EndOffset}
	end
	local function collapsed(state: any): boolean
		return state.StartNode == state.EndNode and state.StartOffset == state.EndOffset
	end
	local function slice(node: any, offset: number, count: number): string
		local units, result = Strings.units(node.Text or ""), {}
		for index = offset + 1, math.min(offset + count, #units) do step(); table.insert(result, units[index]) end
		return Strings.fromUnits(result)
	end
	local function clone(node: any, deep: boolean): any
		-- Existing allocation guards charge copies; charge the traversal as well
		-- before the bridge's iterative clone can allocate a large subtree.
		local pending, count = {node}, 0
		while #pending > 0 do
			step(); count += 1
			if count > 8192 then c.Fail("RangeError", "Range clone node budget exceeded") end
			local current = table.remove(pending)
			if deep then
				for _, child in current.Children or {} do table.insert(pending, child) end
				if current.Content then table.insert(pending, current.Content) end
				local shadow = current.InternalShadowRoot
				if shadow and shadow.Clonable then table.insert(pending, shadow) end
			end
		end
		return c.Clone(node, deep)
	end
	local function append(parent: any, node: any) step(); c.Insert(parent, node, nil) end
	local function contained(state: any, node: any): boolean
		return c.Compare(state.StartNode, state.StartOffset, node, 0) < 0
			and c.Compare(state.EndNode, state.EndOffset, node, c.Length(node)) > 0
	end
	local function collapsePoint(state: any): (any, number)
		if c.Contains(state.StartNode, state.EndNode) then return state.StartNode, state.StartOffset end
		local reference = state.StartNode
		while reference.Parent and not c.Contains(reference.Parent, state.EndNode) do step(); reference = reference.Parent end
		return reference.Parent, c.Index(reference) + 1
	end
	local function classify(state: any): (any, any, any, any)
		local common = c.CommonAncestor(state.StartNode, state.EndNode)
		local first, last, children = nil, nil, {}
		for _, child in common.Children or {} do
			step()
			local startInside, endInside = c.Contains(child, state.StartNode), c.Contains(child, state.EndNode)
			if startInside ~= endInside then
				if not c.Contains(state.StartNode, state.EndNode) and first == nil then first = child end
				if not c.Contains(state.EndNode, state.StartNode) then last = child end
			elseif contained(state, child) then
				if child.Kind == "DocumentType" then c.Fail("HierarchyRequestError", "Range contents cannot contain a doctype") end
				table.insert(children, child)
			end
		end
		return common, first, last, children
	end
	local copyContents
	copyContents = function(state: any, extract: boolean, range: any?, depth: number): any
		step()
		if depth > 256 then c.Fail("RangeError", "Range partial subtree depth exceeded") end
		local fragment = c.Fragment(state.StartNode)
		if collapsed(state) then return fragment end
		local sn, so, en, eo = state.StartNode, state.StartOffset, state.EndNode, state.EndOffset
		if sn == en and character(sn) then
			local copied = clone(sn, false); c.SetData(copied, slice(sn, so, eo - so)); append(fragment, copied)
			if extract then step(); c.ReplaceData(sn, so, eo - so, "") end
			return fragment
		end
		local _, first, last, children = classify(state)
		if extract and range then
			local node, offset = collapsePoint(state)
			c.Set(range, node, offset, node, offset)
		end
		if first then
			local copied = clone(first, false)
			if character(first) then
				local count = c.Length(sn) - so
				c.SetData(copied, slice(sn, so, count)); append(fragment, copied)
				if extract then step(); c.ReplaceData(sn, so, count, "") end
			else
				append(fragment, copied)
				local part = copyContents({StartNode=sn, StartOffset=so, EndNode=first, EndOffset=c.Length(first)}, extract, nil, depth + 1)
				append(copied, part)
			end
		end
		for _, child in children do append(fragment, if extract then child else clone(child, true)) end
		if last then
			local copied = clone(last, false)
			if character(last) then
				c.SetData(copied, slice(en, 0, eo)); append(fragment, copied)
				if extract then step(); c.ReplaceData(en, 0, eo, "") end
			else
				append(fragment, copied)
				local part = copyContents({StartNode=last, StartOffset=0, EndNode=en, EndOffset=eo}, extract, nil, depth + 1)
				append(copied, part)
			end
		end
		return fragment
	end
	local function insert(range: any, node: any)
		local state = snapshot(range); step()
		local start = state.StartNode
		if start.Kind == "Comment" or start.Kind == "ProcessingInstruction" or (text(start) and not start.Parent) or start == node then
			c.Fail("HierarchyRequestError", "Node cannot be inserted at this range boundary")
		end
		local reference = if text(start) then start else start.Children[state.StartOffset + 1]
		local parent = if reference then reference.Parent else start
		c.ValidateInsert(parent, node, reference)
		if text(start) then reference = c.SplitText(start, state.StartOffset) end
		if node == reference then reference = parent.Children[c.Index(reference) + 2] end
		if node.Parent then step(); c.Remove(node) end
		local offset = if reference then c.Index(reference) else c.Length(parent)
		offset += if node.Kind == "DocumentFragment" or node.Kind == "ShadowRoot" then c.Length(node) else 1
		step(); c.Insert(parent, node, reference)
		if collapsed(c.State(range)) then c.SetEnd(range, parent, offset) end
	end
	local api = {}
	function api.cloneContents(range: any, _args: any): any return copyContents(snapshot(range), false, nil, 0) end
	function api.extractContents(range: any, _args: any): any return copyContents(snapshot(range), true, range, 0) end
	function api.deleteContents(range: any, _args: any): any
		local state = snapshot(range); step()
		if collapsed(state) then return U end
		local sn, so, en, eo = state.StartNode, state.StartOffset, state.EndNode, state.EndOffset
		if sn == en and character(sn) then c.ReplaceData(sn, so, eo - so, ""); return U end
		local common = c.CommonAncestor(sn, en)
		local pending, removed = {}, {}
		for index = #common.Children, 1, -1 do table.insert(pending, common.Children[index]) end
		while #pending > 0 do
			step(); local node = table.remove(pending)
			if contained(state, node) then table.insert(removed, node)
			else for index = #node.Children, 1, -1 do table.insert(pending, node.Children[index]) end end
		end
		local node, offset = collapsePoint(state); c.Set(range, node, offset, node, offset)
		if character(sn) then step(); c.ReplaceData(sn, so, c.Length(sn) - so, "") end
		for _, child in removed do step(); c.Remove(child) end
		if character(en) then step(); c.ReplaceData(en, 0, eo, "") end
		return U
	end
	function api.insertNode(range: any, args: any): any insert(range, args[1]); return U end
	function api.surroundContents(range: any, args: any): any
		local state = snapshot(range); local common = c.CommonAncestor(state.StartNode, state.EndNode)
		for _, endpoint in {state.StartNode, state.EndNode} do
			local node = endpoint
			while node and node ~= common do
				step()
				if not text(node) and c.Contains(node, state.StartNode) ~= c.Contains(node, state.EndNode) then
					c.Fail("InvalidStateError", "A non-Text node is partially contained in the range")
				end
				node = node.Parent
			end
		end
		local parent = args[1]
		if parent.Kind == "Document" or parent.Kind == "DocumentType" or parent.Kind == "DocumentFragment" or parent.Kind == "ShadowRoot" then
			c.Fail("InvalidNodeTypeError", "Range surround parent has an invalid node type")
		end
		local fragment = copyContents(state, true, range, 0)
		if #parent.Children > 0 then step(); c.Clear(parent) end
		insert(range, parent); append(parent, fragment)
		local owner, index = parent.Parent, c.Index(parent)
		c.Set(range, owner, index, owner, index + 1)
		return U
	end
	function api.createContextualFragment(range: any, args: any): any
		local state = snapshot(range); step(); local node = state.StartNode
		local element = if node.Kind == "Element" then node elseif text(node) or node.Kind == "Comment" then node.Parent else nil
		if element and element.Kind ~= "Element" then element = nil end
		if not element or element.Name == "html" and (element.NamespaceURI == nil or element.NamespaceURI == HTML) then element = c.Element("body") end
		return c.Parse(element, args[1], node)
	end
	return api
end
return RangeContents
