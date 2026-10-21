--!strict
-- Preflight structural mutations, reconcile affected parents, release removed
-- resources and repair the shared DOM/control/paint indexes.
local Elements=require(script.Parent.Parent.HTML.Elements)
local GroupOpacity=require(script.Parent.GroupOpacity)
local DOMReconcile={}
local Stylesheet=require(script.Parent.Parent.CSS.Stylesheet)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local MediaContent=require(script.Parent.Parent.HTML.MediaContent)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local ControlView=require(script.Parent.Parent.Controls.View)
local CONTROL_FIELDS=table.freeze({"Value","EditText","Checked","UserEdited","UserInvalid","BadInput","SelectedIndex","SelectedIndices","DOMDirtyValue","DOMDirtyChecked","DOMCustomValidity","Indeterminate","SelectionStart","SelectionEnd","SelectionDirection","SelectionValue","TemporalParts","TemporalSegment","TemporalDigits","Files","ImagePoint"})
local COPY_FIELDS=table.freeze({SelectedIndices=true,TemporalParts=true,Files=true,ImagePoint=true})
function DOMReconcile.connected(document: any,node: any): boolean
	return ShadowTree.Connected(node,document)
end
function DOMReconcile.new(document: any,tree: any,host: any): any
	local bridge={}
	local function connected(node)return DOMReconcile.connected(document,node)end
	local controls,nodeBoxes,nodeStyles=tree.Controls,tree.NodeBoxes,tree.NodeStyles
	local textItems,textItemsByGui=tree.TextItems,tree.TextItemsByGui
	local hitNodes,hitStyles=tree.HitNodes,tree.HitStyles
	local fontTargets,links,viewportPositioned=tree.FontPreloadTargets,tree.Links,tree.ViewportPositioned
	local styleRecords,wordRuns,savedControlStates=host.StyleRecords,host.WordRuns,host.SavedControlStates
	local visualEffects,insets,backgrounds,corners=tree.VisualEffects,host.Insets,host.Backgrounds,host.Corners
	local structuralSpecial={html=true,head=true,body=true,style=true,script=true,link=true,base=true,slot=true,
		template=true,details=true,summary=true,dialog=true,table=true,thead=true,tbody=true,tfoot=true,tr=true,td=true,th=true,col=true,colgroup=true,
		select=true,option=true,optgroup=true,datalist=true,img=true,svg=true,canvas=true,iframe=true,object=true,embed=true,audio=true,video=true}
	local replaced={img=true,svg=true,canvas=true,iframe=true,embed=true,audio=true,video=true}
	local selectContent={select=true,option=true,optgroup=true}
	local tableContent={table=true,caption=true,thead=true,tbody=true,tfoot=true,tr=true,td=true,th=true,col=true,colgroup=true}
	local headContent={style=true,link=true,script=true,title=true,meta=true,base=true}
	function bridge:Validate(parent: any,child: any,oldParent: any)
		if not connected(parent) and not connected(oldParent) then return end
		local documentEdit=parent==document or oldParent==document
		local function htmlRoot(node: any): boolean return node~=nil and node.Parent==document and ElementNames.html(node,'html')end
		local rootEdit=documentEdit or htmlRoot(parent)or htmlRoot(oldParent)
		for _,start in {parent or false,oldParent or false} do
			if start and MediaContent.data(start)then continue end
			if start and Stylesheet.isMetadata(start) then
				-- Non-rendered style descendants can contain arbitrary DOM nodes;
				-- only direct Text/CDATA children supply the stylesheet source.
				if Stylesheet.styleAncestor(start)then continue end
				assert(start.Name=="head" or start.Name=="style" or start.Name=="script" or start.Name=="title" or start.Kind=="Text" or start.Kind=="Comment", "Dynamic children of this metadata element are not implemented yet")
				if start.Name=="style" or start.Name=="script" or start.Name=="title" then
					assert(child.Kind=="Text" or child.Kind=="Comment", "Style and script content supports text and comment nodes")
				elseif start.Name=="head" then
					assert(child.Kind=="Text" or child.Kind=="Comment" or headContent[child.Name]or ElementNames.style(child), "Dynamic head content supports style, link, script, title, meta and base nodes")
				end
				continue
			end
			if start and tree:SelectOwner(start) then
				-- Option contents are data for a native select; selectedcontent
				-- copies in a base-select button use the ordinary renderer below.
				continue
			end
			local current=start
			while current do
				assert(current==start or not structuralSpecial[current.Name] or tableContent[current.Name] or current.Name=="slot" or current.Name=="html" or current.Name=="body" or current.Name=="dialog","Dynamic children inside this specialized element are not implemented yet")
				if current==start then
					local entry=Elements[current.Name]
					assert(not entry or entry.Render~="control" or nodeBoxes[current] and nodeBoxes[current].RichButton,"Use textContent/value to change a form control")
					assert(current==document or htmlRoot(current)or current.Kind=="DocumentFragment" or current.Kind=="ShadowRoot" or (current.Kind=="Element" and (tableContent[current.Name] or current.Name=="slot" or current.Name=="body" or current.Name=="dialog" or not structuralSpecial[current.Name])),"Dynamic children of this element are not implemented yet")
				end
				current=current.Parent or(if current.Kind=="ShadowRoot"then current.Host else nil)
			end
		end
		-- Hidden fallback is ordinary DOM data. The data DOM still owns the
		-- hierarchy checks; only a rendered destination needs renderer preflight.
		if parent and MediaContent.data(parent)or not parent and oldParent and MediaContent.data(oldParent)then return end
		local pending={child}
		while #pending>0 do
			local current=table.remove(pending)
			if documentEdit and current.Kind=='DocumentType'then continue end
			if current.Kind=="Element" and (current.Name=="base" or current.Name=="meta" or current.Name=="title") then continue end
			if ElementNames.style(current)then continue end
			if current.Kind=="Element" and (current.Name=="link" or current.Name=="script") then
				-- The script loader owns execution; these nodes have no render box.
				for _,nested in current.Children do assert(nested.Kind=="Text" or nested.Kind=="Comment", "Style and script metadata supports text and comment nodes") end
				continue
			end
			local documentContainer=rootEdit and(ElementNames.html(current,'html')or ElementNames.html(current,'head')or ElementNames.html(current,'body'))
			assert(documentContainer or not structuralSpecial[current.Name] or tableContent[current.Name] or current.Name=="slot" or current.Name=="dialog" or replaced[current.Name] or selectContent[current.Name],"Dynamic insertion/removal of '"..tostring(current.Name).."' is not implemented yet")
			-- Replaced subtrees are consumed by their own renderer/resource session.
			if replaced[current.Name] then continue end
			for _,nested in current.Children do table.insert(pending,nested) end
			if current.InternalShadowRoot then table.insert(pending,current.InternalShadowRoot)end
		end
	end
	function bridge:Apply(changes: any): any
		local targets,ordered={},{}
		for node,change in changes do
			if change.Children and not change.ImageMapData and not change.MediaData and connected(node)and(not tree:SelectOwner(node)or tree:RichSelectContent(node))then
				local owner=tree:TextOwner(if node.Kind=="ShadowRoot"then node.Host else node)
				assert(owner and owner.RefreshText,"Missing structural render owner")
				if not targets[owner] then targets[owner]="children";table.insert(ordered,owner) end
			end
		end
		if #ordered==0 then return targets end
		local depths={}
		for _,owner in ordered do
			local node,value=owner.Node,0
			while node do value+=1;node=node.Parent end
			depths[owner]=value
		end
		table.sort(ordered,function(a,b)return depths[a]>depths[b]end)
		local oldReplaced={}
		for _,run in wordRuns do for _,item in run.Items or {} do if item.Kind=="Image" and item.Node and not item.Control then oldReplaced[item]=true end end end
		for _,box in nodeBoxes do if box.ImageItem and not box.ImageItem.Control then oldReplaced[box.ImageItem]=true end end
		host.Refresh(ordered)
		-- A row/cell edit changes the table's shared track and span model. Rebuild
		-- this metadata on retained boxes, rather than rebuilding other controls.
		local tables={}
		for _,owner in ordered do
			local layoutOwner=owner
			while layoutOwner do
				if layoutOwner.Style.TableRole=="table"and layoutOwner.RefreshTable then tables[layoutOwner]=true end
				layoutOwner=layoutOwner.LayoutParent
			end
			local node=owner.Node
			while node do
				local box=nodeBoxes[node]
				if box and box.Style.TableRole=="table" and box.RefreshTable then tables[box]=true end
				node=node.Parent
			end
		end
		for box in tables do box:RefreshTable();targets[box]="children" end
		local keptBoxes,keptRuns,keptItems={},{},{}
		local function keep(box)
			keptBoxes[box]=true
			if box.Kind=="Words" then
				keptRuns[box]=true;for _,item in box.Items or{}do keptItems[item]=true end
			end
			if box.ImageItem then keptItems[box.ImageItem]=true end
			if box.Control then keptItems[box.Control.Item]=true end
			for _,nested in box.AllChildren or box.Children or {} do keep(nested) end
		end
		keep(tree)
		if tree.CanvasBackgroundState then tree.CanvasBackgroundState:DetachRetiredRoot(keptBoxes)end
		local removedGuis={}
		for item in oldReplaced do if not keptItems[item]and item.Gui then removedGuis[item.Gui]=true;GroupOpacity.untrack(item) end end
		for node,box in nodeBoxes do
			if not keptBoxes[box] then
				removedGuis[if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui]=true
				if visualEffects.Remove then visualEffects:Remove(box) end
				for _,resource in {insets or false,backgrounds or false,corners or false} do
					if resource and resource.Remove then resource:Remove(box) end
				end
				nodeBoxes[node]=nil
			end
		end
		local function removedGui(gui)
			while gui do if removedGuis[gui] then return true end;gui=gui.Parent end
			return false
		end
		for i=#textItems,1,-1 do
			local item=textItems[i]
			if not keptBoxes[item.TextOwner] then GroupOpacity.untrack(item);table.remove(textItems,i) end
		end
		for i=#controls,1,-1 do
			local c=controls[i]
			if not connected(c.Node)or MediaContent.contents(c.Node)then
				ControlView.release(c.Item)
				local saved={}
				for _,field in CONTROL_FIELDS do
					local value=c[field];saved[field]=if COPY_FIELDS[field] and value then table.clone(value) else value
				end
				savedControlStates[c.Node]=saved
				if not removedGui(c.Item.Gui) then removedGuis[c.Item.Gui]=true end
				table.remove(controls,i)
			end
		end
		for i=#wordRuns,1,-1 do if not keptRuns[wordRuns[i]] then table.remove(wordRuns,i) end end
		for i=#fontTargets,1,-1 do if removedGui(fontTargets[i]) then table.remove(fontTargets,i) end end
		for gui,node in hitNodes do if not connected(node) or removedGui(gui) then hitNodes[gui]=nil;hitStyles[gui]=nil;textItemsByGui[gui]=nil end end
		for gui in textItemsByGui do if removedGui(gui) then textItemsByGui[gui]=nil end end
		for node in nodeStyles do if not connected(node)or MediaContent.contents(node)then nodeStyles[node]=nil end end
		for i=#styleRecords,1,-1 do if not connected(styleRecords[i].Node)or MediaContent.contents(styleRecords[i].Node)then table.remove(styleRecords,i) end end
		for i=#viewportPositioned,1,-1 do if not keptBoxes[viewportPositioned[i]] then table.remove(viewportPositioned,i) end end
		local roots={}
		-- Native sessions cancel pending work before their GUI roots are released.
		if tree.PruneStructuralResources then tree:PruneStructuralResources(keptItems)end
		for gui in removedGuis do if not removedGui(gui.Parent) then table.insert(roots,gui) end end
		for _,gui in roots do gui:Destroy() end
		-- Parent-first cascade and focus order follow the new document order.
		local domOrder,pending,sequence={},{document},0
		if tree.RefreshLinkIndex then tree:RefreshLinkIndex()else table.clear(links)end
		while #pending>0 do
			local node=table.remove(pending);sequence+=1;domOrder[node]=sequence
			local s=nodeStyles[node]
			if not tree.RefreshLinkIndex and node.Name=="a" and node.Attributes.href and s and not s.Hidden then table.insert(links,node) end
			for i=#node.Children,1,-1 do table.insert(pending,node.Children[i]) end
			if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot) end
		end
		table.sort(styleRecords,function(a,b)return (domOrder[a.Node] or math.huge)<(domOrder[b.Node] or math.huge)end)
		-- Anonymous disclosure bodies and other synthetic inherited styles do
		-- not have a document-order index. Keep their dependencies parent-first.
		local byStyle,orderedRecords,visited={},{},{}
		for _,record in styleRecords do byStyle[record.Style]=record end
		for _,record in styleRecords do
			local chain,current={},record
			while current and not visited[current] do
				visited[current]=true;table.insert(chain,current);current=byStyle[current.Inherited]
			end
			for i=#chain,1,-1 do table.insert(orderedRecords,chain[i]) end
		end
		table.clear(styleRecords);for _,record in orderedRecords do table.insert(styleRecords,record) end
		table.sort(controls,function(a,b)return (domOrder[a.Node] or math.huge)<(domOrder[b.Node] or math.huge)end)
		tree:SyncPositioning()
		if tree.MotionRuntime and tree.MotionRuntime.DOMChanged then tree.MotionRuntime:DOMChanged(keptBoxes) end
		return targets
	end
	return bridge
end
return DOMReconcile
