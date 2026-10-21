--!strict
local Names=require(script.Parent.Parent.DOM.ElementNames)
-- The HTML select algorithms traverse the data tree, not the rendered tree.
local WorkContext=require(script.Parent.Parent.WorkContext)
local Tree={}
Tree.html=Names.html
-- HTML-aware option/legend text differs from DOM textContent: scripts do
-- not contribute, images contribute alt text only when requested, and only
-- ASCII whitespace is stripped/collapsed. Value and .text never include alt.
function Tree.text(node: any,includeAltText: boolean?): string
	local chunks,pending={},{}
	for i=#node.Children,1,-1 do table.insert(pending,node.Children[i])end
	while #pending>0 do
		WorkContext.checkpoint();local child=table.remove(pending)
		if Tree.html(child,'script')or Names.matches(child,'script','http://www.w3.org/2000/svg')then continue end
		if child.Kind=='Text'then table.insert(chunks,child.Text)
		elseif Tree.html(child,'img')then if includeAltText then table.insert(chunks,child.Attributes.alt or'')end;continue end
		for i=#child.Children,1,-1 do table.insert(pending,child.Children[i])end
	end
	return (table.concat(chunks):gsub('[ \t\r\n\f]+',' '):gsub('^ +',''):gsub(' +$',''))
end
local function push(pending,parent,disabled,grouped)
	for i=#parent.Children,1,-1 do table.insert(pending,{Node=parent.Children[i],Disabled=disabled,Grouped=grouped})end
end
function Tree.options(select: any,option: any,group: any?)
	local pending={};push(pending,select,false,false)
	while #pending>0 do
		WorkContext.checkpoint();local entry=table.remove(pending);local node=entry.Node
		if Tree.html(node,'option')then option(node,entry.Disabled,entry.Grouped)
		elseif Tree.html(node,'select')or Tree.html(node,'hr')or Tree.html(node,'datalist')then continue
		elseif Tree.html(node,'optgroup')then
			if entry.Grouped then continue end
			local disabled=entry.Disabled or node.Attributes.disabled~=nil
			if group then group(node,disabled)end
			push(pending,node,disabled,true)
		else push(pending,node,entry.Disabled,entry.Grouped)end
	end
end
function Tree.mirrors(select: any): any
	local result={};local ancestor=select.Parent
	while ancestor do WorkContext.checkpoint();if Tree.html(ancestor,'select')then return result end;ancestor=ancestor.Parent end
	local pending={};push(pending,select,false,false)
	while #pending>0 do
		WorkContext.checkpoint();local node=table.remove(pending).Node
		if Tree.html(node,'selectedcontent')then table.insert(result,node)
		elseif not Tree.html(node,'option')and not Tree.html(node,'select')then push(pending,node,false,false)end
	end
	return result
end
return Tree
