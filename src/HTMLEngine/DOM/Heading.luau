--!strict
-- HTML's semantic heading level follows the DOM ancestry, crossing a shadow
-- root through its host. A slot's flat-tree parent and ARIA level are separate.
local Names=require(script.Parent.ElementNames)
local Values=require(script.Parent.Parent.HTML.AttributeValues)
local Work=require(script.Parent.Parent.WorkContext)
local Heading={}
function Heading.level(node: any): number?
	local name=Names.htmlName(node)
	local rank=name and name:match('^h([1-6])$')
	if not rank then return nil end
	local level=tonumber(rank)::number
	local ancestor=node
	while ancestor and ancestor.Kind=='Element'do
		Work.checkpoint()
		if Names.html(ancestor)then
			level=math.min(9,level+Values.clampedNonnegative(ancestor.Attributes.headingoffset,0,9))
			if ancestor.Attributes.headingreset~=nil then break end
		end
		local parent=ancestor.Parent
		ancestor=if parent and parent.Kind=='ShadowRoot'then parent.Host else parent
	end
	return level
end
return Heading
