--!strict
-- Parsed nodes and installed DOM nodes retain their node document when detached.
-- Do not cache this lookup: adoption can change the mode of detached subtrees.
local Work=require(script.Parent.Parent.WorkContext)
local Mode={}
function Mode.document(node: any): any?
	if node.Kind=='Document'then return node end
	if node.OwnerDocument then return node.OwnerDocument end
	local current=node
	while current do
		Work.checkpoint()
		if current.Kind=='Document'then return current end
		current=if current.Kind=='ShadowRoot'then current.Host else current.Parent
	end
	return nil
end
function Mode.quirks(node: any): boolean
	local document=Mode.document(node)
	return document~=nil and document.Mode=='quirks'
end
function Mode.fold(value: string): string return (value:gsub('[A-Z]',string.lower))end
return Mode
