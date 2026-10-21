--!strict
local ElementNames=require(script.Parent.ElementNames)
local SourceDocument=require(script.Parent.MediaSourceDocument)
-- Data only: no GUI instances, connections, timers or shared text measurements.
local Node = {}
local WorkContext=require(script.Parent.Parent.WorkContext)
local Template=require(script.Parent.TemplateDocument)

function Node.document(): any
	return { Kind = "Document", Children = {}, Parent = nil, Diagnostics = {}, IsHTML=true, ContentType="text/html" }
end

function Node.documentType(name: string,publicId: string,systemId: string): any
	return {Kind="DocumentType",Name=name,PublicId=publicId,SystemId=systemId,Children={},Parent=nil}
end
function Node.cdata(value: string): any return {Kind="CDATASection",Text=value,Children={},Parent=nil}end
function Node.processingInstruction(target: string,value: string): any return {Kind="ProcessingInstruction",Target=target,Text=value,Children={},Parent=nil}end

function Node.documentFragment(): any
	return { Kind = "DocumentFragment", Children = {}, Parent = nil }
end

function Node.shadowRoot(mode: string, host: any, clonable: boolean?, serializable: boolean?, delegatesFocus: boolean?): any
	assert(mode == "open" or mode == "closed", "Shadow root mode must be open or closed")
	return {
		Kind = "ShadowRoot", Children = {}, Parent = nil, Host = host, Mode = mode,
		Clonable = clonable == true, Serializable = serializable == true, DelegatesFocus = delegatesFocus == true,
	}
end

function Node.element(name: string, attributes: { [string]: string }): any
	return { Kind = "Element", Name = name, Attributes = attributes, Children = {}, Parent = nil }
end

function Node.text(value: string): any
	return { Kind = "Text", Text = value, Children = {}, Parent = nil }
end

function Node.comment(value: string): any
	return { Kind = "Comment", Text = value, Children = {}, Parent = nil }
end

function Node.append(parent: any, child: any)
	assert(parent.Kind == "Document" or parent.Kind == "DocumentFragment" or parent.Kind == "ShadowRoot" or parent.Kind == "Element", "Only containers can have children")
	assert(child.Kind ~= "Document", "Cannot insert a document")
	assert(child.Parent == nil, "Child already has a parent")
	local current = parent
	while current do
		assert(current ~= child, "Cannot create a cycle")
		current = current.Parent
	end
	child.Parent = parent
	table.insert(parent.Children, child)
end

-- Validate before detaching: a failed insertion must leave both trees intact.
function Node.validateInsert(parent: any, child: any, before: any?, childrenToExclude: any?)
	assert(parent.Kind == "Document" or parent.Kind == "DocumentFragment" or parent.Kind == "ShadowRoot" or parent.Kind == "Element", "DOM insertion requires a container")
	local current = parent
	while current do
		assert(current ~= child, "Cannot create a DOM cycle")
		current = current.Parent or (if current.Kind == "ShadowRoot" or current.Kind == "DocumentFragment" then current.Host else nil)
	end
	assert(before == nil or before.Parent == parent, "Reference node is not a child of this parent")
	local character = child.Kind == "Text" or child.Kind == "CDATASection" or child.Kind == "Comment" or child.Kind == "ProcessingInstruction"
	local fragment = child.Kind == "DocumentFragment" or child.Kind == "ShadowRoot"
	assert(child.Kind == "Element" or child.Kind == "DocumentType" or character or fragment, "Cannot insert this node type")
	if parent.Kind ~= "Document" then assert(child.Kind ~= "DocumentType", "Doctypes require a document parent"); return end
	assert(child.Kind ~= "Text" and child.Kind ~= "CDATASection", "Documents cannot contain Text children")
	if character then return end
	if fragment then
		local elements = 0
		for _, entry in child.Children do
			assert(entry.Kind ~= "Text" and entry.Kind ~= "CDATASection", "Documents cannot contain Text children")
			if entry.Kind == "Element" then elements += 1 end
		end
		assert(elements <= 1, "Documents cannot contain multiple elements")
		if elements == 0 then return end
	end
	local referenceIndex = if before then assert(table.find(parent.Children, before), "Inconsistent DOM reference") else #parent.Children + 1
	local function excluded(entry: any): boolean return childrenToExclude ~= nil and table.find(childrenToExclude, entry) ~= nil end
	for position, entry in parent.Children do
		if fragment or child.Kind == "Element" then
			assert(entry.Kind ~= "Element" or excluded(entry), "Document already has an element")
			assert(entry.Kind ~= "DocumentType" or position < referenceIndex or (entry == before and excluded(entry)), "Document element must follow its doctype")
		else
			assert(entry.Kind ~= "DocumentType" or excluded(entry), "Document already has a doctype")
			assert(entry.Kind ~= "Element" or (if before then position >= referenceIndex else excluded(entry)), "Document doctype must precede its element")
		end
	end
end

-- A complete batch also needs one final-tree check: individually valid nodes
-- can otherwise introduce two document elements without any intermediate write.
function Node.validateChildren(parent: any, children: any)
	if parent.Kind ~= "Document" then return end
	local element, doctype = false, false
	for _, child in children do
		assert(child.Kind ~= "Text" and child.Kind ~= "CDATASection", "Documents cannot contain Text children")
		if child.Kind == "Element" then assert(not element, "Documents cannot contain multiple elements"); element = true
		elseif child.Kind == "DocumentType" then assert(not doctype and not element, "Document doctype must be unique and precede its element"); doctype = true
		else assert(child.Kind == "Comment" or child.Kind == "ProcessingInstruction", "Invalid document child") end
	end
end

function Node.removeChild(parent: any, child: any): any
	assert(child.Parent == parent, "Node is not a child of this parent")
	local index = table.find(parent.Children, child)
	assert(index, "Inconsistent DOM parent")
	table.remove(parent.Children, index)
	child.Parent = nil
	return child
end

function Node.insertBefore(parent: any, child: any, before: any?): boolean
	Node.validateInsert(parent, child, before)
	if child.Kind == "DocumentFragment" or child.Kind == "ShadowRoot" then
		local children = table.clone(child.Children)
		for _, entry in children do Node.validateInsert(parent, entry, before) end
		for _, entry in children do Node.insertBefore(parent, entry, before) end
		return #children > 0
	end
	if child == before then return false end
	local oldIndex = if child.Parent == parent then table.find(parent.Children, child) else nil
	if oldIndex and parent.Children[oldIndex + 1] == before then return false end
	if child.Parent then Node.removeChild(child.Parent, child) end
	local index = if before then table.find(parent.Children, before) else #parent.Children + 1
	assert(index, "Missing reference node")
	table.insert(parent.Children, index, child)
	child.Parent = parent
	return true
end

local function cloneShallow(source: any,created: any?,owner: any?): any
	local copy
	if source.Kind == "Document" then
		copy = Node.document()
		copy.IsHTML,copy.ContentType,copy.Mode,copy.URL=source.IsHTML,source.ContentType,source.Mode,source.URL
		copy.PlainDocument=source.PlainDocument
		copy.LegacyFragment=source.LegacyFragment
		if created then created(copy,source)end
	elseif source.Kind=="DocumentType"then copy=Node.documentType(source.Name,source.PublicId or"",source.SystemId or"")
	elseif source.Kind=="CDATASection"then copy=Node.cdata(source.Text)
	elseif source.Kind=="ProcessingInstruction"then copy=Node.processingInstruction(source.Target,source.Text)
	elseif source.Kind=="Attr"then copy={Kind="Attr",Name=source.Name,Text=if source.OwnerElement then source.OwnerElement.Attributes[source.StorageKey or source.Name]or source.Text else source.Text,NamespaceURI=source.NamespaceURI,Prefix=source.Prefix,LocalName=source.LocalName,Children={},Parent=nil}
	elseif source.Kind == "DocumentFragment" then
		copy = Node.documentFragment()
	elseif source.Kind == "ShadowRoot" then
		copy = Node.shadowRoot(source.Mode, nil, source.Clonable, source.Serializable, source.DelegatesFocus)
	elseif source.Kind == "Element" then
		copy = Node.element(source.Name, {})
		copy.NamespaceURI = source.NamespaceURI
		copy.LocalName,copy.Prefix=source.LocalName,source.Prefix
		copy.OwnerDocument=owner
		if created then created(copy,source)end
		copy.Attributes=table.clone(source.Attributes)
		copy.AttributeOrder=if source.AttributeOrder then table.clone(source.AttributeOrder)else nil
		copy.AttributeNamespaces=if source.AttributeNamespaces then table.clone(source.AttributeNamespaces)else nil
		SourceDocument.seed(copy,copy.OwnerDocument,true)
		if ElementNames.script(source) then copy.ScriptStarted=source.ScriptStarted end
		if source.Content then
			if copy.OwnerDocument then Template.contents(copy,copy.OwnerDocument)
			else copy.Content=Node.documentFragment();copy.Content.Host=copy end
		end
	elseif source.Kind == "Text" then copy = Node.text(source.Text)
	elseif source.Kind == "Comment" then copy = Node.comment(source.Text)
	else error("Unknown DOM node kind: " .. tostring(source.Kind)) end
	if copy.Kind~='Document'and not copy.OwnerDocument then copy.OwnerDocument=owner end
	return copy
end

-- Browser-shaped deep cloning for the engine's data DOM. Template contents
-- live in their own fragment and are cloned into the new template fragment.
function Node.cloneNode(source: any, deep: boolean?,created: any?,document: any?): any
	assert(type(source) == "table" and type(source.Kind) == "string", "cloneNode expects a DOM node")
	local root = cloneShallow(source,created,document or source.OwnerDocument)
	local pending = {{Source = source, Target = root, Deep=deep==true}}
	while #pending > 0 do
		WorkContext.checkpoint()
		local entry = table.remove(pending)
		local function copyChildren(sourceParent: any, targetParent: any)
			for _, child in sourceParent.Children or {} do
				WorkContext.checkpoint()
				local owner=if targetParent.Kind=='Document'then targetParent else targetParent.OwnerDocument
				local cloned = cloneShallow(child,created,owner)
				Node.append(targetParent, cloned)
				table.insert(pending, {Source = child, Target = cloned, Deep=true})
			end
		end
		if entry.Deep then copyChildren(entry.Source, entry.Target)end
		if entry.Deep and entry.Source.Content and entry.Target.Content then
			copyChildren(entry.Source.Content, entry.Target.Content)
		end
		local sourceShadow = entry.Source.InternalShadowRoot
		if sourceShadow and sourceShadow.Clonable then
			local clonedShadow = cloneShallow(sourceShadow,nil,entry.Target.OwnerDocument)
			clonedShadow.Host = entry.Target
			clonedShadow.SlotAssignment = sourceShadow.SlotAssignment
			clonedShadow.Declarative = sourceShadow.Declarative
			clonedShadow.CustomElementRegistry=sourceShadow.CustomElementRegistry
			clonedShadow.CustomElementRegistryInitialized=sourceShadow.CustomElementRegistryInitialized
			clonedShadow.KeepCustomElementRegistryNull=sourceShadow.KeepCustomElementRegistryNull
			entry.Target.InternalShadowRoot = clonedShadow
			if clonedShadow.Mode == "open" then entry.Target.ShadowRoot = clonedShadow end
			copyChildren(sourceShadow, clonedShadow)
		end
	end
	return root
end

-- Iterative traversal avoids recursive Lua calls for nested documents.
function Node.findById(root: any, id: string): any
	local pending = { root }
	while #pending > 0 do
		WorkContext.checkpoint()
		local node = table.remove(pending)
		if node.Kind == "Element" and node.Attributes.id == id then return node end
		for index = #node.Children, 1, -1 do table.insert(pending, node.Children[index]) end
	end
	return nil
end

function Node.textContent(root: any): string
	local pending, parts = { root }, {}
	while #pending > 0 do
		local node = table.remove(pending)
		if node.Kind == "Text"or node.Kind=="CDATASection" then table.insert(parts, node.Text) end
		for index = #node.Children, 1, -1 do table.insert(pending, node.Children[index]) end
	end
	return table.concat(parts)
end

function Node.findElement(root: any,test: any): any
	local pending={root};while #pending>0 do local node=table.remove(pending)
		if node.Kind=="Element"and test(node)then return node end
		for index=#node.Children,1,-1 do table.insert(pending,node.Children[index])end
	end;return nil
end

return Node
