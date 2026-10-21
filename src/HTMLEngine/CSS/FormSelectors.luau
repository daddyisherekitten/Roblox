--!strict
-- HTML form selector semantics shared by querying and the renderer cascade.
local Names=require(script.Parent.Parent.DOM.ElementNames)
local FormOwner=require(script.Parent.Parent.DOM.FormOwner)
local Numeric=require(script.Parent.Parent.Controls.NumericValue)
local Range=require(script.Parent.Parent.Controls.RangeValue)
local Number=require(script.Parent.Parent.Controls.NumberValue)
local Temporal=require(script.Parent.Parent.Controls.TemporalValue)
local Work=require(script.Parent.Parent.WorkContext)
local Forms={}
local html=Names.html
local function root(node)while node.Parent do Work.checkpoint();node=node.Parent end;return node end
local owner=FormOwner.resolve
local function submit(node)
	if html(node,'input')then local kind=(node.Attributes.type or''):lower();return kind=='submit'or kind=='image'end
	if not html(node,'button')then return false end
	local kind=(node.Attributes.type or''):lower()
	if kind=='submit'then return true end
	return kind~='button'and kind~='reset'and node.Attributes.command==nil and node.Attributes.commandfor==nil and not(node.Parent and html(node.Parent,'select'))
end
function Forms.default(node)
	if html(node,'option')then return node.Attributes.selected~=nil end
	if html(node,'input')then
		local kind=(node.Attributes.type or''):lower()
		if kind=='checkbox'or kind=='radio'then return node.Attributes.checked~=nil end
	end
	if not submit(node)then return false end
	local form=owner(node);if not form then return false end
	local pending={root(form)}
	while #pending>0 do
		Work.checkpoint();local candidate=table.remove(pending)
		if candidate.Kind=='Element'and submit(candidate)and owner(candidate)==form then return candidate==node end
		for i=#candidate.Children,1,-1 do table.insert(pending,candidate.Children[i])end
	end
	return false
end
function Forms.range(node,state)
	if not html(node,'input')or state.Disabled or node.Attributes.readonly~=nil then return nil end
	local ancestor=node.Parent;while ancestor do Work.checkpoint();if html(ancestor,'datalist')then return nil end;ancestor=ancestor.Parent end
	local kind,value=state.Type,state.Value or''
	if kind=='number'or kind=='range'then
		local limits=if kind=='range'then state.Range or Range.read(node.Attributes)else state.Number or Number.read(node.Attributes)
		if limits.Min==nil and limits.Max==nil then return nil end
		if kind=='range'then value=Range.normalize(limits,value)end
		local n=Numeric.parse(value)
		return n~=nil and(limits.Min~=nil and n<limits.Min or limits.Max~=nil and n>limits.Max)or false
	elseif Temporal.applies(kind)then
		local limits=state.Temporal or Temporal.read(kind,node.Attributes)
		if limits.Min==nil and limits.Max==nil then return nil end
		local under,over=Temporal.flags({Type=kind,Value=value,Temporal=limits});return under or over
	end
	return nil
end
return Forms
