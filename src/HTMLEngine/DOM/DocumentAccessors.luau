--!strict
-- Shared expanded-name and child-text rules for DOM accessors and host metadata.
local Node=require(script.Parent.Node)
local WorkContext=require(script.Parent.Parent.WorkContext)
local Names=require(script.Parent.ElementNames)
local Accessors={HTML=Names.HTML,SVG="http://www.w3.org/2000/svg",matches=Names.matches}
function Accessors.root(document: any): any
	for _,child in document.Children do if child.Kind=="Element"then return child end end
	return nil
end
function Accessors.child(parent: any,name: string,namespace: string,step: any?,alternative: string?): any
	step=step or WorkContext.checkpoint
	if parent then for _,child in parent.Children do
		step()
		if Accessors.matches(child,name,namespace)or(alternative and Accessors.matches(child,alternative,namespace))then return child end
	end end
	return nil
end
function Accessors.head(document: any,step: any?): any
	local root=Accessors.root(document)
	return if Accessors.matches(root,"html",Accessors.HTML)then Accessors.child(root,"head",Accessors.HTML,step)else nil
end
function Accessors.body(document: any,step: any?): any
	local root=Accessors.root(document)
	return if Accessors.matches(root,"html",Accessors.HTML)then Accessors.child(root,"body",Accessors.HTML,step,"frameset")else nil
end
function Accessors.title(document: any,step: any?): any
	step=step or WorkContext.checkpoint
	local root=Accessors.root(document)
	if Accessors.matches(root,"svg",Accessors.SVG)then return Accessors.child(root,"title",Accessors.SVG,step)end
	return Node.findElement(document,function(child)step();return Accessors.matches(child,"title",Accessors.HTML)end)
end
function Accessors.titleCandidate(root: any,node: any): boolean
	return if Accessors.matches(root,"svg",Accessors.SVG)then node.Parent==root and Accessors.matches(node,"title",Accessors.SVG)else Accessors.matches(node,"title",Accessors.HTML)
end
function Accessors.childText(parent: any,step: any?): string
	step=step or WorkContext.checkpoint
	local parts={}
	if parent then for _,child in parent.Children do
		step()
		if child.Kind=="Text"or child.Kind=="CDATASection"then table.insert(parts,child.Text)end
	end end
	return table.concat(parts)
end
function Accessors.normalizedTitle(title: any,step: any?): string
	return Accessors.childText(title,step):gsub("[\t\n\f\r ]+"," "):match("^ *(.-) *$")or""
end
function Accessors.titleText(document: any,step: any?): string
	return Accessors.normalizedTitle(Accessors.title(document,step),step)
end
return Accessors
