--!strict
-- Per-layout anchor lookup. Names are shared only inside their CSS scope;
-- an earlier positioned anchor is updated after its used layout is known.
local Work=require(script.Parent.Parent.WorkContext)
local AnchorPosition=require(script.Parent.Parent.CSS.AnchorPosition)
local Registry={}
local function parent(node)
	if not node then return nil end
	return if node.Kind=='ShadowRoot'then node.Host else node.AssignedSlot or node.Parent
end
local function treeScope(node)
	while node and node.Parent do node=node.Parent end
	return node
end
local function contains(ancestor,node)
	while node do if node==ancestor then return true end;node=parent(node)end
	return false
end
function Registry.new(root,relative,fixedBlock,alive)
	local self={Names={},Boxes={},Key='',Relative=relative}
	if not root.HasAnchors then return self end
	local order=0
	local function collect(box,owner,x,y,normalCB,absoluteCB,fixedCB)
		Work.checkpoint();if not alive()or box.Kind=='Words'or box.CollapsedByTable or box.Style.Hidden or box.TopLayerHidden then return end
		order+=1
		local s=box.Style
		if s.Position=='relative'then local dx,dy=relative(box,owner);x+=dx;y+=dy end
		local positioned=s.Position=='absolute'or s.Position=='fixed'or box.LayoutAsTopLayer
		local cb=if s.Position=='fixed'then fixedCB elseif positioned then absoluteCB else normalCB
		local record={Box=box,Node=box.Node,Owner=owner,Order=order,CB=cb,Positioned=positioned,
			X=x,Y=y,Width=box.OuterWidth or 0,Height=box.OuterHeight or 0,Style=s,Tree=treeScope(box.Node)}
		self.Boxes[box]=record
		for _,name in s.AnchorNames or{}do local entries=self.Names[name]or{};self.Names[name]=entries;table.insert(entries,record)end
		local fixed=box==root or fixedBlock(s,box)
		if box==root or s.Position~='static'and s.Position~=nil or fixed then absoluteCB=record end
		if fixed then fixedCB=record end
		for _,child in box.PositioningChildren or box.Children or{}do
			local offset=if box.TableSurface and child.Style.TableRole=='caption'then 0 else box.CaptionTop or 0
			collect(child,record,x+(child.LayoutX or 0),y+offset+(child.LayoutY or 0),record,absoluteCB,fixedCB)
		end
	end
	collect(root,nil,0,0,nil,nil,nil)
	local keys={}
	for name,entries in self.Names do for _,a in entries do
		table.insert(keys,#name..':'..name..':'..a.Order..':'..a.X..':'..a.Y..':'..a.Width..':'..a.Height)
	end end
	table.sort(keys);self.Key=table.concat(keys,';')
	return self
end
function Registry.scope(root,node,name,tree)
	while node do
		local style=root.NodeStyles and root.NodeStyles[node]
		if style and treeScope(node)==tree then
			local scope=style.AnchorScope
			if scope=='all'then return node end
			if type(scope)=='table'then for _,entry in scope do if entry==name then return node end end end
		end
		node=parent(node)
	end
	return nil
end
local function layoutAcceptable(query,a,depth)
		if not a or depth>64 or a==query or contains(query.Node,a.Node)then return false end
		-- A generated picker is laid out above the existing page. Its anchors
		-- need not precede the originating select in DOM tree order.
		if query.ExternalTopLayer and not a.Box.LayoutAsTopLayer then return true end
		if a==query.CB then return true end
		if a.CB==query.CB then return not a.Positioned or a.Order<query.Order end
		return layoutAcceptable(query,a.CB,depth+1)
end
local function skipped(root,node)
		node=parent(node)
		while node do local style=root.NodeStyles and root.NodeStyles[node];if style and style.ContentVisibility=='hidden'then return node end;node=parent(node)end
		return nil
end
local function acceptable(root,query,a)
	return a and (a.Tree==query.Tree or contains(a.Tree,query.Node))
		and skipped(root,a.Node)==skipped(root,query.Node)and layoutAcceptable(query,a,0)
end
function Registry.find(self,root,box,name,external)
	if not name then return nil end
	local query=external or self.Boxes[box];if not query then return nil end
	local scope=Registry.scope(root,query.Node,name,query.Tree)
	local nearest,last,nearestDepth=nil,nil,math.huge
	for _,a in self.Names[name]or{}do
		Work.checkpoint()
		-- A reference may look into its own or an outer shadow tree, never an inner one.
		if Registry.scope(root,a.Node,name,a.Tree)==scope and acceptable(root,query,a)then
			last=a
			local at,depth=parent(query.Node),0
			while at do
				if at==a.Node and depth<nearestDepth then nearest,nearestDepth=a,depth;break end
				at=parent(at);depth+=1
			end
		end
	end
	return nearest or last
end
function Registry.default(self,root,box,external,depth)
	depth=depth or 0;if depth>64 then return nil end;Work.checkpoint()
	local query=external or self.Boxes[box];if not query then return nil end
	local style=query.Style or box.Style
	if style.Position~='absolute'and style.Position~='fixed'and not box.LayoutAsTopLayer then return nil end
	local reference=AnchorPosition.defaultName(style)
	if reference=='match-parent'then
		local origin=parent(query.Node)
		local parentBox=root.NodeBoxes and root.NodeBoxes[origin]
		local candidate=parentBox and Registry.default(self,root,parentBox,nil,depth+1)
		-- Carry the actual selected element, not its name: child scopes must
		-- not substitute another element with the same author anchor-name.
		return if acceptable(root,query,candidate)then candidate else nil
	elseif reference=='auto'then return query.Implicit
	elseif reference then return Registry.find(self,root,box,reference,query)end
	return nil
end
function Registry.external(self,root,box,implicit,geometry)
	local query={Node=box.Node,Box=box,Style=box.Style,Tree=treeScope(box.Node),CB=self.Boxes[root],Order=math.huge,ExternalTopLayer=true,Implicit=implicit}
	return setmetatable({},{__index=function(cache,name)
		if not name then return nil end
		local found=if name=='auto'then implicit elseif name=='match-parent'then Registry.default(self,root,box,query)else Registry.find(self,root,box,name,query)
		if found and name~='auto'and geometry then found=geometry(found)end
		rawset(cache,name,found or false);return found
	end})
end
function Registry.update(self,box,x,y)
	local a=self.Boxes[box]
	if not a then return end
	local changed=a.X~=x or a.Y~=y or a.Width~=(box.OuterWidth or 0)or a.Height~=(box.OuterHeight or 0)
	a.X,a.Y,a.Width,a.Height=x,y,box.OuterWidth or 0,box.OuterHeight or 0
	if not changed or not box.HasAnchors then return end
	local function flow(owner)
		Work.checkpoint()
		for _,child in owner.Box.PositioningChildren or owner.Box.Children or{}do
			local c=self.Boxes[child]
			if not c or c.Positioned or not child.HasAnchors then continue end
			local dx,dy=0,0;if child.Style.Position=='relative'then dx,dy=self.Relative(child,owner)end
			local offset=if owner.Box.TableSurface and child.Style.TableRole=='caption'then 0 else owner.Box.CaptionTop or 0
			c.X,c.Y=owner.X+(child.LayoutX or 0)+dx,owner.Y+offset+(child.LayoutY or 0)+dy
			c.Width,c.Height=child.OuterWidth or 0,child.OuterHeight or 0
			flow(c)
		end
	end
	flow(a)
end
return Registry
