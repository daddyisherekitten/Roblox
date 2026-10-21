--!strict
-- Keep renderer arrays stable, and report identity changes independently from
-- their order. Moving an item must not restart its native resource session.
local StructuralResources={}
function StructuralResources.new(document: any,collections: any): any
	local published={}
	local function connected(item)
		local node=item.Node or item.Canvas or (item.Style and item.Style.Node)
		while node and node.Parent do node=node.Parent end
		return node==document
	end
	local function census()
		local result={}
		for kind,items in collections do
			local found={}
			for i=#items,1,-1 do
				local item=items[i]
				if found[item] or not connected(item) then table.remove(items,i) else found[item]=true end
			end
			result[kind]=found
		end
		return result
	end
	published=census()
	local api={}
	function api:Take(): any
		local current=census();local changes={}
		for kind,items in collections do
			local added,removed={},{}
			for _,item in items do if not published[kind][item] then table.insert(added,item) end end
			for item in published[kind] do if not current[kind][item] then table.insert(removed,item) end end
			changes[kind]={Added=added,Removed=removed}
		end
		published=current
		return changes
	end
	function api:Prune(beforeDestroy: any?,retained: any?)
		local removals={}
		for kind,items in collections do
			local removed,seen={},{}
			for i=#items,1,-1 do
				local item=items[i]
				if not connected(item)or retained and not retained[item]then
					if not seen[item] then seen[item]=true;table.insert(removed,item) end
					table.remove(items,i)
				end
			end
			removals[kind]=removed
		end
		if beforeDestroy then beforeDestroy(removals) end
		return removals
	end
	return api
end
return StructuralResources
