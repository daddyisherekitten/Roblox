--!strict
-- Keep public qualified names and the exported catalog intact. Rendering and
-- UA behavior select an entry by namespace plus local name.
local Names=require(script.Parent.Parent.DOM.ElementNames)
local Elements=require(script.Parent.Elements)
local Profile={SVG="http://www.w3.org/2000/svg"}
function Profile.entry(node: any): any
	local name=Names.htmlName(node)
	-- These local names only select foreign renderers in their actual namespace.
	if name and name~="svg"and name~="math"then return Elements[name]end
	if Names.matches(node,"svg",Profile.SVG)then return Elements.svg end
	if Names.matches(node,"style",Profile.SVG)then return Elements.style end
	return nil
end
function Profile.summary(node: any): boolean
	if not Names.html(node,"summary")or not Names.html(node.Parent,"details")then return false end
	for _,child in node.Parent.Children do if Names.html(child,"summary")then return child==node end end
	return false
end
return Profile
