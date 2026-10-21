--!strict
-- Parser completion initializes selectedcontent before the document is exposed.
-- Control interaction continues through the existing select state/host bridge.
local Node=require(script.Parent.Parent.DOM.Node)
local WorkContext=require(script.Parent.Parent.WorkContext)
local AttributeValues=require(script.Parent.AttributeValues)
local SelectTree=require(script.Parent.SelectTree)
local Selected={}
Selected.mirrors=SelectTree.mirrors
function Selected.update(select: any,option: any?,clone: any,replace: any,force: boolean?): any
	local changed={};if select.Attributes.multiple~=nil then return changed end
	for _,mirror in Selected.mirrors(select)do
		local snapshot=mirror.SelectedContentSnapshot
		if not force and snapshot and snapshot.HadOption==(option~=nil)and snapshot.Source[1]==option then continue end
		local children={};for _,child in if option then option.Children else{}do table.insert(children,clone(child))end
		replace(mirror,children);table.insert(changed,mirror)
		-- The snapshot must not keep a removed option/tree alive. HadOption
		-- distinguishes a collected old source from an explicitly empty copy.
		mirror.SelectedContentSnapshot={HadOption=option~=nil,Source=setmetatable({option},{__mode='v'})}
	end
	return changed
end
function Selected.initialize(c: any)
	local pending={c.Document}
	while #pending>0 do
		WorkContext.checkpoint(); local node=table.remove(pending)
		for i=#node.Children,1,-1 do table.insert(pending,node.Children[i]) end
		if node.Content then table.insert(pending,node.Content) end
		if not SelectTree.html(node,'select')or node.Attributes.multiple~=nil then continue end
		if #Selected.mirrors(node)==0 then continue end
		local selected,first=nil,nil
		SelectTree.options(node,function(child,disabled)
			if child.Attributes.selected~=nil then selected=child end
			if not first and not disabled and child.Attributes.disabled==nil then first=child end
		end)
		local size=AttributeValues.nonnegative(node.Attributes.size,2147483647) or 0
		selected=selected or (if size<=1 then first else nil)
		Selected.update(node,selected,function(child)
				local root=nil;local copies={{Source=child,Parent=nil}}
				while #copies>0 do
					WorkContext.checkpoint(); local entry=table.remove(copies)
					local copy=c:allocate(Node.cloneNode(entry.Source,false));if entry.Parent then c:attach(copy,entry.Parent)else root=copy end
					if copy.Content then c:allocate(copy.Content) end
					for i=#entry.Source.Children,1,-1 do table.insert(copies,{Source=entry.Source.Children[i],Parent=copy}) end
					if copy.Content then for i=#entry.Source.Content.Children,1,-1 do table.insert(copies,{Source=entry.Source.Content.Children[i],Parent=copy.Content}) end end
				end
				return root
		end,function(mirror,children)
			for _,child in table.clone(mirror.Children)do Node.removeChild(mirror,child)end
			for _,child in children do c:attach(child,mirror)end
		end,true)
	end
end
return Selected
