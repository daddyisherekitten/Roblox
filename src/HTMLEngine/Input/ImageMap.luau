--!strict
-- Resolves pointer positions over img[usemap] to the first matching area.
local ImageMap = {}
local Names=require(script.Parent.Parent.DOM.ElementNames)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)

local function visit(node: any, callback: (any) -> ())
	callback(node)
	for _, child in node.Children or {} do visit(child, callback) end
end

function ImageMap.collect(document: any): {[string]: any}
	local maps = {}
	visit(document, function(node)
		if Names.html(node,"map")then
			for _,key in {"id","name"}do local name=node.Attributes[key]
				if name and name~=""and maps[name]==nil then maps[name]=node end
			end
		end
	end)
	return maps
end

function ImageMap.bind(maps: {[string]: any}, image: any, item: any): boolean
	local reference = image.Attributes.usemap
	local hash=reference and reference:find("#",1,true)
	local name=if hash then reference:sub(hash+1)else nil
	item.ImageMap=if name and name~=""then maps[name]else nil
	item.ImageNode = image
	return item.ImageMap~=nil
end

local function renderedChildren(node)
	-- Weak values avoid child.Parent -> weak key cycles in Luau (weak-key
	-- tables do not have ephemeron semantics). Connected DOM owns the list.
	local list=setmetatable({},{__mode='v'});for _,child in node.Children or{}do
		if child.Kind~="Comment"and not Names.html(child,"area")then table.insert(list,child)end
	end;return list
end
-- A root cache is invalidated by association/structural inputs, never by an
-- idle frame or an unrelated paint attribute. Items include unassociated imgs
-- so assigning useMap later does not recreate their image/resource surfaces.
function ImageMap.new(document: any,items: any): any
	local index={Roots=setmetatable({},{__mode="k"}),Owners=setmetatable({},{__mode="k"}),Snapshots=setmetatable({},{__mode="k"}),Mutations=setmetatable({},{__mode='k'}),Items=items,Revision=0,Scans=0}
	local function scope(root)
		local maps=index.Roots[root];if maps then return maps end
		maps=ImageMap.collect(root);index.Roots[root]=maps;index.Scans+=1
		-- One light-tree pass also covers nested/duplicate-name maps; visiting
		-- every map subtree separately would multiply work for nested maps.
		local function snapshots(node,inMap)
			inMap=inMap or Names.html(node,'map')
			if inMap and index.Snapshots[node]==nil then index.Snapshots[node]=renderedChildren(node)end
			for _,child in node.Children or{}do snapshots(child,inMap)end
		end;snapshots(root,false)
		return maps
	end
	function index:Bind(image,item)
		items[image]=item
		return ImageMap.bind(scope(ShadowTree.Root(image,false)),image,item)
	end
	function index:Mutation(record)
		if record.Type~='childList'then return end
		local info=self.Mutations[record.Target]or{Relevant=false,PureData=true};self.Mutations[record.Target]=info
		local pending={};local queued=0
		local function enqueue(node)
			if queued==256 then info.Relevant=true;info.PureData=false;return false end
			queued+=1;table.insert(pending,node);return true
		end
		for _,list in {record.AddedNodes or{},record.RemovedNodes or{}}do for _,node in list do
			if not enqueue(node)then break end
			if node.Kind~='Comment'and not Names.html(node,'area')then info.PureData=false end
		end end
		while #pending>0 and not info.Relevant do
			local node=table.remove(pending)
			local name=Names.htmlName(node)
			if name=='map'or name=='area'or name=='img'then info.Relevant=true;break end
			for _,child in node.Children or{}do if not enqueue(child)then break end end
			if node.InternalShadowRoot then enqueue(node.InternalShadowRoot)end
		end
	end
	function index:Prepare(changes)
		local relevant=false
		for node,change in changes do
			local attrs=change.Attributes or{};local name=Names.htmlName(node)
			local mutation=self.Mutations[node]
			if change.Children and(not mutation or mutation.Relevant)or name=="map"and(attrs.id or attrs.name)or name=="img"and attrs.usemap then relevant=true end
			if change.Children and self.Snapshots[node]then
				local before,current=self.Snapshots[node],renderedChildren(node);local same=#before==#current
				if same then for i,child in current do if before[i]~=child then same=false;break end end end
				change.ImageMapData=same and not change.RenderChildren
				self.Snapshots[node]=current
			end
			if change.Children and not self.Snapshots[node]and mutation and mutation.PureData and not change.RenderChildren then
				local ancestor=node;while ancestor and not Names.html(ancestor,'map')do ancestor=ancestor.Parent end
				if ancestor then change.ImageMapData=true;self.Snapshots[node]=renderedChildren(node)end
			end
		end
		table.clear(self.Mutations)
		return relevant
	end
	function index:Refresh(invalidate: boolean?)
		self.Cursor=nil
		if invalidate then table.clear(self.Roots);self.Revision+=1 end
		for node in self.Snapshots do if not ShadowTree.Connected(node,document)then self.Snapshots[node]=nil end end
		table.clear(self.Owners)
		local areaLists={}
		for image,item in items do
			if not ShadowTree.Connected(image,document)then items[image]=nil;item.ImageMap=nil;item.ImageNode=nil;continue end
			self:Bind(image,item)
			local map=item.ImageMap;if not map then continue end
			local areas=areaLists[map]
			if not areas then areas={};areaLists[map]=areas;visit(map,function(node)if Names.html(node,"area")then table.insert(areas,node)end end)end
			for _,area in areas do local owners=self.Owners[area];if not owners then owners={};self.Owners[area]=owners end;table.insert(owners,item)end
		end
	end
	function index:Owner(area,predicate,order)
		local first,position=nil,math.huge
		for _,item in self.Owners[area]or{}do
			local node=item.ImageNode
			if predicate and not predicate(node)then continue end
			local rank=if order then order[node]or math.huge else 0
			if not first or rank<position then first,position=item,rank end
		end;return first
	end
	function index:Destroy()
		self.Cursor=nil
		for image,item in items do item.ImageMap=nil;item.ImageNode=nil;items[image]=nil end
		table.clear(self.Roots);table.clear(self.Owners);table.clear(self.Snapshots);table.clear(self.Mutations)
	end
	return index
end

local function numbers(value: string?): {number}
	local result = {}
	-- HTML's recovering floating-point-list algorithm, not a strict CSV or
	-- Lua number parser: semicolon is a delimiter, leading garbage is skipped,
	-- prefixes are parsed, and an erroneous token contributes zero.
	for token in (value or ""):gmatch("[^,; \t\n\f\r]+")do
		local part=token:gsub("^[^%d%.%-]*","")
		local mantissa=part:match("^[+-]?%d+%.?%d*")or part:match("^[+-]?%.%d+")
		local exponent=mantissa and part:sub(#mantissa+1):match("^[eE][+-]?%d+")
		local number=mantissa and tonumber(mantissa..(exponent or""))
		table.insert(result,if number and number==number and math.abs(number)<math.huge then number else 0)
	end
	return result
end

local function contains(area: any, x: number, y: number): boolean
	local shape = (area.Attributes.shape or "rect"):lower()
	if shape=="circ"then shape="circle"elseif shape=="polygon"then shape="poly"elseif shape~="circle"and shape~="poly"and shape~="default"then shape="rect"end
	local coords = numbers(area.Attributes.coords)
	if shape == "default" then return true end
	if shape == "rect" and #coords >= 4 then
		local left, right = math.min(coords[1], coords[3]), math.max(coords[1], coords[3])
		local top, bottom = math.min(coords[2], coords[4]), math.max(coords[2], coords[4])
		return left<right and top<bottom and x >= left and x <= right and y >= top and y <= bottom
	elseif shape == "circle" and #coords >= 3 and coords[3] > 0 then
		local dx, dy = x - coords[1], y - coords[2]
		return dx * dx + dy * dy <= coords[3] * coords[3]
	elseif shape == "poly" and #coords >= 6 then
		local count=#coords-#coords%2
		local inside, j = false, count - 1
		for i = 1, count, 2 do
			local xi, yi, xj, yj = coords[i], coords[i + 1], coords[j], coords[j + 1]
			if (x-xi)*(yj-yi)==(y-yi)*(xj-xi)and x>=math.min(xi,xj)and x<=math.max(xi,xj)and y>=math.min(yi,yj)and y<=math.max(yi,yj)then return true end
			if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then inside = not inside end
			j = i
		end
		return inside
	end
	return false
end

function ImageMap.hit(items: {[any]: any}?, node: any, position: any): any
	local item = items and items[node]
	if not item then return node end
	-- Inert images have no virtual shape. Native hit testing falls through the
	-- inert subtree to its first non-inert ancestor, independent of map styles.
	local ancestor,blocked=node,nil
	while ancestor do if ancestor.Attributes and ancestor.Attributes.inert~=nil then blocked=ancestor end;ancestor=ShadowTree.FlatParent(ancestor)end
	if blocked then return ShadowTree.FlatParent(blocked)end
	if not item.ImageMap then return node end
	-- Native loaded/broken-image controls locate coords at the img border box,
	-- including authored padding. There is no bitmap-natural-size scaling.
	local gui = item.BoxGui or item.ImageClip or item.ImageGui
	if not gui or not gui.AbsolutePosition or not gui.AbsoluteSize then return node end
	local width, height = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	if width <= 0 or height <= 0 then return node end
	-- area coordinates are CSS-pixel distances from the displayed image edges;
	-- they do not use the source bitmap's natural pixel dimensions.
	local x = position.X - gui.AbsolutePosition.X
	local y = position.Y - gui.AbsolutePosition.Y
	if x<0 or y<0 or x>=width or y>=height then return node end
	local function pick(current)
		if Names.html(current,'area')and contains(current,x,y)then return current end
		for _,child in current.Children or{}do local match=pick(child);if match then return match end end
		return nil
	end
	return pick(item.ImageMap)or node
end

return ImageMap
