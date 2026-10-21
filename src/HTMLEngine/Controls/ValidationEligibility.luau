--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Validation eligibility is independent of whether this widget has an editable
-- native text surface. In particular readonly bars every HTML input, while it
-- does not turn a radio or a slider into a read-only UI control.
local Defaults=require(script.Parent.Defaults)
local Work=require(script.Parent.Parent.WorkContext)
local Eligibility={}
function Eligibility.applies(node:any,state:any):boolean
	if node.Kind~='Element'or node.NamespaceURI and node.NamespaceURI~='http://www.w3.org/1999/xhtml'then return false end
	local name=ElementNames.htmlName(node)
	if name~='input'and name~='textarea'and name~='select'and name~='button'then return false end
	if state.Disabled or (name=='input'or name=='textarea')and node.Attributes.readonly~=nil then return false end
	local parent=node.Parent
	while parent do
		Work.checkpoint()
		if ElementNames.htmlName(parent)=='datalist'and(not parent.NamespaceURI or parent.NamespaceURI=='http://www.w3.org/1999/xhtml')then return false end
		parent=parent.Parent
	end
	local kind=state.Type or Defaults.kind(node)
	return kind~='hidden'and kind~='reset'and kind~='button'and kind~='image'and not Defaults.selectButton(node)
end
return Eligibility
