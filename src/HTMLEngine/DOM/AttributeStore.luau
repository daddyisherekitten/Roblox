--!strict
-- Storage keys stay private. HTML's unqualified attributes keep their direct
-- lookup; expanded names can coexist even when their qualified names coincide.
local Store={}
local Work=require(script.Parent.Parent.WorkContext)
function Store.keys(node: any): any
	local names=node.AttributeOrder
	if not names then names={};node.AttributeOrder=names end
	local present={}
	for index=#names,1,-1 do
		Work.checkpoint()
		if node.Attributes[names[index]]==nil then table.remove(names,index)else present[names[index]]=true end
	end
	local added={};for name in node.Attributes do Work.checkpoint();if not present[name]then table.insert(added,name)end end
	table.sort(added);for _,name in added do table.insert(names,name)end
	return names
end
function Store.name(node: any,key: string): string
	local info=node.AttributeNamespaces and node.AttributeNamespaces[key]
	if not info then return key end
	return info.QualifiedName or(if info.Prefix then info.Prefix..':'..info.LocalName else info.LocalName or key)
end
function Store.namespace(node: any,key: string): string?
	local info=node.AttributeNamespaces and node.AttributeNamespaces[key]
	local namespace=info and(info.Namespace or info.NamespaceURI)
	return if namespace~=''then namespace else nil
end
function Store.qualified(node: any,name: string): string?
	if not node.AttributeNamespaces then return if node.Attributes[name]~=nil then name else nil end
	for _,key in Store.keys(node)do Work.checkpoint();if Store.name(node,key)==name then return key end end
	return nil
end
function Store.expanded(node: any,namespace: string?,localName: string): string?
	if namespace==''then namespace=nil end
	if not node.AttributeNamespaces then return if not namespace and node.Attributes[localName]~=nil then localName else nil end
	for _,key in Store.keys(node)do
		Work.checkpoint()
		local info=node.AttributeNamespaces and node.AttributeNamespaces[key]
		if Store.namespace(node,key)==namespace and(info and info.LocalName or key)==localName then return key end
	end
	return nil
end
function Store.destination(node: any,namespace: string?,localName: string,prefix: string?): string
	local name=if prefix then prefix..':'..localName else localName
	if namespace and not prefix or node.Attributes[name]~=nil and Store.expanded(node,namespace,localName)~=name then
		return '\0'..(namespace or'')..'\0'..localName
	end
	return name
end
return Store
