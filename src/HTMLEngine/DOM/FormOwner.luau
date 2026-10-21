--!strict
-- Explicit form IDs are resolved in the connected element's own tree scope.
-- Shadow hosts connect a scope; they never expand its ID lookup into another tree.
local Node=require(script.Parent.Node)
local ShadowTree=require(script.Parent.ShadowTree)
local Work=require(script.Parent.Parent.WorkContext)
local Names=require(script.Parent.ElementNames)
local Owner={}
local function form(node)return Names.html(node,"form")end
local associated={button=true,fieldset=true,input=true,object=true,output=true,select=true,textarea=true}
local function clear(node)
	local owner=node.ParserFormOwner
	if not owner then return end
	node.ParserFormOwner=nil
	local controls=owner.ParserAssociatedControls
	if controls then controls[node]=nil;if next(controls)==nil then owner.ParserAssociatedControls=nil end end
end
local function within(node,root)
	while node do Work.checkpoint();if node==root then return true end;node=node.Parent end
	return false
end
function Owner.beforeRemove(root: any,preservingMove: boolean?)
	-- Removing a shared subtree keeps its exceptional associations: owner and
	-- control still share that tree and the parser flag survives insertion.
	-- State-preserving moves also stay in their original connected tree.
	if preservingMove then return end
	local pending={root}
	while #pending>0 do
		Work.checkpoint();local node=table.remove(pending)
		if node.ParserFormOwner and not within(node.ParserFormOwner,root)then clear(node)end
		if node.ParserAssociatedControls then
			for control in node.ParserAssociatedControls do if not within(control,root)then clear(control)end end
		end
		for _,child in node.Children do table.insert(pending,child)end
	end
end
function Owner.afterMove(root: any)
	local pending={root}
	while #pending>0 do
		Work.checkpoint();local node=table.remove(pending)
		if node.ParserFormOwner and ShadowTree.Root(node)~=ShadowTree.Root(node.ParserFormOwner)then clear(node)end
		if node.ParserAssociatedControls then
			for control in node.ParserAssociatedControls do if ShadowTree.Root(control)~=ShadowTree.Root(node)then clear(control)end end
		end
		for _,child in node.Children do table.insert(pending,child)end
	end
end
function Owner.attributeChanged(node: any,key: string)
	if key=='form'then clear(node)end
end
function Owner.parserAssociate(node: any,owner: any,parent: any)
	if not associated[Names.htmlName(node)]or node.Attributes.form~=nil or not form(owner)or ShadowTree.Root(owner)~=ShadowTree.Root(parent)then return end
	-- Ordinary ancestor ownership is resolved directly. Keep only the parser's
	-- exceptional association to a nonancestor form (for example foster parenting).
	local current=parent
	while current do if form(current)then if current==owner then return end;break end;current=current.Parent end
	node.ParserFormOwner=owner
	owner.ParserAssociatedControls=owner.ParserAssociatedControls or setmetatable({},{__mode='k'})
	owner.ParserAssociatedControls[node]=true
end
function Owner.resolve(node: any): any?
	local explicit=node.Attributes.form
	local parserOwner=node.ParserFormOwner
	if parserOwner then
		if explicit==nil and ShadowTree.Root(node)==ShadowTree.Root(parserOwner)then return parserOwner end
		clear(node)
	end
	if explicit~=nil then
		if not ShadowTree.Connected(node)then return nil end
		local found=Node.findById(ShadowTree.Root(node),explicit)
		return if found and form(found)then found else nil
	end
	local current=node.Parent
	while current do
		Work.checkpoint()
		if form(current)then return current end
		current=current.Parent
	end
	return nil
end
return Owner
