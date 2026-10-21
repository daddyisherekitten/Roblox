--!strict
-- Editing ownership shared by DOM, selectors and native input. This module
-- reads the live tree only: no ranges, VM, paint surfaces or cached ancestry.
local Names=require(script.Parent.ElementNames)
local EditingHost={}
function EditingHost.state(node: any): string
	local value=Names.html(node)and node.Attributes.contenteditable
	if type(value)~="string"then return"inherit"end;value=value:lower()
	return if value==""or value=="true"then"true"elseif value=="false"or value=="plaintext-only"then value else"inherit"
end
function EditingHost.host(node: any): (any?,string?)
	local current=if node.Kind=="Element"then node else node.Parent
	local owner,mode=nil,nil
	while current and current.Kind=="Element"do
		local state=EditingHost.state(current)
		if state=="false"then break end
		if state=="true"or state=="plaintext-only"then owner,mode=current,state end
		current=current.Parent
	end
	if owner then return owner,mode end
	local document=node.OwnerDocument
	if current and current.Kind=="Document"and document and document.DesignMode=="on"then
		local root=current.Children[1];for _,child in current.Children do if child.Kind=="Element"then root=child;break end end
		return root,"true"
	end
	return nil,nil
end
function EditingHost.isEditable(node: any): boolean
	return Names.html(node)and EditingHost.host(node)~=nil
end
return EditingHost
