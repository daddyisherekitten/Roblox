--!strict
-- Popup views share normal rendering, but own their GUI/resources independently
-- of the page. No DOM clone, script execution, idle scanner or element reparenting.
local Work=require(script.Parent.Parent.WorkContext)
local Positioned=require(script.Parent.Parent.Layout.PositionedLayout)
local Picker={}
local function snapshot(root)
	local result,pending={},{root}
	while #pending>0 do
		Work.checkpoint();local node=table.remove(pending)
		result[node]={Text=node.Text,Attributes=if node.Attributes then table.clone(node.Attributes)else nil,Children=table.clone(node.Children)}
		for _,child in node.Children do table.insert(pending,child)end
	end
	return result
end
local function changes(before,after)
	local result={}
	for node,entry in after do
		local old=before[node];if not old then continue end
		local change={};local dirty=false
		if old.Text~=entry.Text then change.Text=true;dirty=true end
		if #old.Children~=#entry.Children then change.Children=true;dirty=true
		else for i,child in entry.Children do if old.Children[i]~=child then change.Children=true;dirty=true;break end end end
		local attrs={};for name,value in entry.Attributes or{}do if not old.Attributes or old.Attributes[name]~=value then attrs[name]=true end end
		for name in old.Attributes or{}do if not entry.Attributes or entry.Attributes[name]==nil then attrs[name]=true end end
		if next(attrs)then change.Attributes=attrs;dirty=true end
		if dirty then result[node]=change end
	end
	return result
end
function Picker.new(page,tree,diagnostic,services)
	local function mount(select,gui,width,changed)
		local Layout=services and services.PickerLayout or require(script.Parent.Parent.Layout.BlockLayout)
		local localPage={Alive=true,Root=gui,Cleanups={}};function localPage:AddCleanup(fn)table.insert(self.Cleanups,fn)end
		local view,previous,svg,dimensions,images;local svgItems,imageSources,fonts={},{},{};local record={}
		local function alive()return localPage.Alive and page.Alive and gui.Parent~=nil end
		local function resourceChanged()if alive()and changed then changed()end end
		local function budget(operation)
			local work=if services and services.PickerLayout then nil else Work.new(4,{Alive=alive})
			local result=table.pack(pcall(function()return if work then work:Run(operation)else operation()end));if work then work:Finish()end
			if not result[1]then if Work.isCancelled(result[2])then return nil end;error(result[2],0)end
			return table.unpack(result,2,result.n)
		end
		local function affected()
			local result={[view.Node]=true}
			-- The render-only root deliberately does not reparent the original
			-- options. Include those retained style owners explicitly: a state
			-- change may leave every inherited root value unchanged.
			for node in view.NodeStyles do Work.checkpoint();result[node]=true end
			return result
		end
		local function arrange(nextWidth,constraints)
			if not alive()then return 0 end
			view:SyncPickerChildren()
			for key,value in constraints or{}do view.PickerConstraints[key]=value end
			local current=snapshot(view.Node);local changed=changes(previous,current);previous=current
			if next(changed)then view:ApplyDOMChanges(changed)end
			local labels={}
			for node,change in changed do
				if change.Attributes and change.Attributes.label and(node.Name=='option'or node.Name=='optgroup')then labels[node]={Children=true}end
				if change.Attributes then view:RefreshImageResource(node)end
			end
			if next(labels)then view:ReconcileChildren(labels)end
			view:RefreshDOMStyles(affected(),false)
			view.ViewportHeight=if constraints then constraints.ViewportHeight else gui.AbsoluteSize.Y
			if constraints and constraints.Positioned then
				local containing={X=0,Y=0,Width=nextWidth,Height=constraints.ViewportHeight,Style=tree.Style,Owner=tree}
				local dependencies={}
				local lookup=Positioned.externalAnchors(tree,view,constraints.Implicit, constraints.ViewportOrigin,dependencies)
				local function layout(box,available,x,y,living,_,sizing)return Layout.arrange(box,available,x,y,living,nil,sizing)end
				local placed=Positioned.place(view,view.Style,containing,lookup,layout,Layout.naturalWidth,alive)
				view.AnchorUsedStyle=if placed.Style~=view.Style then placed.Style else nil
				record.Placement=placed
				record.AnchorDependencies=dependencies
			else record.Placement,record.AnchorDependencies=nil,nil;Layout.arrange(view,nextWidth,0,0,alive)end
			if not svg and #view.SVGItems>0 then svg=require(script.Parent.SVGImages).start(localPage,view,diagnostic,services and services.SVG)end
			if svg then
				local nextItems,added,removed={},{},{}
				for _,item in view.SVGItems do nextItems[item]=true;if not svgItems[item]then table.insert(added,item)end end
				for item in svgItems do if not nextItems[item]then table.insert(removed,item)end end
				svg:RemoveItems(removed);svg:AddItems(added);svgItems=nextItems
			end
			if dimensions then
				local nextSources,added,removed={},{},{}
				for _,item in view.ImageItems do
					nextSources[item]=item.Source
					if imageSources[item]~=item.Source then table.insert(added,item)end
				end
				for item,source in imageSources do if nextSources[item]~=source then table.insert(removed,item)end end
				dimensions:Remove(removed);images:Remove(removed);imageSources=nextSources
				dimensions:Add(added);images:Add(added)
				local targets={}
				for _,target in view.FontPreloadTargets do
					local face=target.FontFace
					local key=if type(face)=='string'then face else face.Family..'|'..tostring(face.Weight)..'|'..tostring(face.Style)
					if not fonts[key]then fonts[key]=true;table.insert(targets,target)end
				end
				table.clear(view.FontPreloadTargets)
				if #targets>0 then
					local preloader=services and services.PickerFontPreload or require(script.Parent.FontPreload)
					preloader.start(targets,alive,diagnostic,resourceChanged,services and services.ResourceServices)
				end
			end
			return view.OuterHeight
		end
		function record:Arrange(nextWidth,constraints)return budget(function()return arrange(nextWidth,constraints)end)or 0 end
		function record:RefreshState()
			if not alive()then return false end
			local _,layoutNeeded=view:RefreshDOMStyles(affected(),true,true)
			return layoutNeeded
		end
		function record:Destroy()
			if not localPage.Alive then return end;localPage.Alive=false
			if view then tree:ReleasePickerBox(select,view)end
			for i=#localPage.Cleanups,1,-1 do localPage.Cleanups[i]()end;table.clear(localPage.Cleanups)
			if view then view.VisualEffects:Destroy();if view.Gui.Parent then view.Gui:Destroy()end end
			if previous then table.clear(previous)end;table.clear(svgItems);table.clear(imageSources);table.clear(fonts)
			record.AnchorDependencies=nil
		end
		local ok,message=pcall(function()
			return budget(function()
				view=tree:BuildPickerTree(select,gui);record.Tree=view;previous=snapshot(view.Node)
				if page.ResourceLoadHost then
					local dimensionLoader=services and services.PickerImageDimensions or require(script.Parent.ImageDimensions)
					local imageLoader=services and services.PickerImageLoad or require(script.Parent.ImageLoad)
					local _,dimensionAPI=dimensionLoader.start({},alive,diagnostic,resourceChanged,{LoadDimensions=function(source,complete)return page.ResourceLoadHost:LoadRasterDimensions(source,complete)end})
					local _,imageAPI=imageLoader.start({},alive,diagnostic,resourceChanged,services and services.ResourceServices)
					dimensions,images=dimensionAPI,imageAPI
					localPage:AddCleanup(function()dimensions:Destroy();images:Destroy()end)
				end
				arrange(width);return true
			end)
		end)
		if not ok or not message then record:Destroy();if not ok then error(message,0)end;return nil end
		return record
	end
	return {MountPicker=mount}
end
return Picker
