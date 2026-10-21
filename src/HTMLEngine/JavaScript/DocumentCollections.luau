--!strict
-- HTML document lists share the existing HTMLCollection wrapper. Snapshots are
-- document-owned so weak registry keys cannot root detached document cycles.
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Names=require(script.Parent.DOMNames)
local Collections={}
local tag={images='img',embeds='embed',forms='form',scripts='script'}
function Collections.new(ctx: any): any
	local token={};local documents=setmetatable({},{__mode='k'});local alive=true
	local function state(document)
		assert(alive,'Document collections disposed')
		local snapshots=document.DOMCollectionSnapshots
		if not snapshots then snapshots={};document.DOMCollectionSnapshots=snapshots end
		local value=snapshots[token]
		if not value then value={Entries={},Views=setmetatable({},{__mode='v'}),Revision=0};snapshots[token]=value;documents[document]=true end
		return value
	end
	local api={}
	function api:Entries(document,key)
		local current=state(document)
		while true do
			if current.Entries[key]then return current.Entries[key]end
			local revision=current.Revision;local entries,pending={}, {document}
			while #pending>0 do
				if ctx.Step then ctx.Step()end
				local node=table.remove(pending)
				if node.Kind=='Element'and(node.NamespaceURI==nil or node.NamespaceURI==Names.HTML)then
					local name=node.LocalName or node.Name
					local info=node.AttributeNamespaces and node.AttributeNamespaces.href
					local href=node.Attributes.href~=nil and(not info or not info.Namespace or info.Namespace=='')
					if name==tag[key]or(key=='links'and(name=='a'or name=='area')and href)then table.insert(entries,node)end
				end
				for index=#node.Children,1,-1 do table.insert(pending,node.Children[index])end
			end
			assert(alive,'Document collections disposed')
			if revision~=current.Revision then continue end
			current.Entries[key]=entries;return entries
		end
	end
	function api:Get(document,key)
		if key=='plugins'then key='embeds'end
		if not tag[key]and key~='links'then return false end
		local current=state(document)
		if not current.Views[key]then current.Views[key]=ctx.Collection(function()return self:Entries(document,key)end,true)end
		return true,current.Views[key]
	end
	function api:Mutation(record)
		local root=ShadowTree.Root(record.Target)
		if not root or root.Kind~='Document'then return end
		local snapshots=root.DOMCollectionSnapshots;local current=snapshots and snapshots[token]
		if not current then return end
		if record.Type=='childList'then
			local changed=false
			for _,nodes in {record.AddedNodes or{},record.RemovedNodes or{}}do
				for _,node in nodes do if node.Kind=='Element'then changed=true;break end end
			end
			if changed then current.Revision+=1;table.clear(current.Entries)end
		elseif record.Type=='attributes'and record.AttributeName=='href'and not record.AttributeNamespace then
			local node=record.Target;local name=node.LocalName or node.Name
			if node.Kind=='Element'and(name=='a'or name=='area')then current.Revision+=1;current.Entries.links=nil end
		end
	end
	function api:Destroy()
		alive=false
		for document in documents do
			local snapshots=document.DOMCollectionSnapshots;local current=snapshots and snapshots[token]
			if current then table.clear(current.Entries);table.clear(current.Views);snapshots[token]=nil;if next(snapshots)==nil then document.DOMCollectionSnapshots=nil end end
		end
		table.clear(documents)
	end
	return api
end
return Collections
