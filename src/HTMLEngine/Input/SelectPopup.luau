--!strict
local Options = require(script.Parent.Parent.Controls.SelectOptions)
local View=require(script.Parent.Parent.Controls.View)
local TypeAhead = require(script.Parent.SelectTypeAhead)
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Popup = {}
function Popup.new(page: any, choose: any, factory: any?, clock: any?, fragments: any?): any
	local self = {Control=nil, Highlight=0,CustomPicker=false}
	local search = TypeAhead.new(clock)
	local host, scroll, nativeScroll, rows, labels, rowIndexes, connections = nil, nil, nil, {}, {}, {}, {}
	local wholeView,wholeHost
	local optionTops = {}
	local optionHeights,rowRanges,totalHeight={},{},0
	local rowsByNode,rowSources={},{}
	local revision=0
	local refreshingRevision,pendingRefresh=nil,nil
	local pointer, downIndex, origin = nil, nil, nil
	local rowHeight = 20
	local popupWidth=0
	local viewHeight = 0
	local popupBackground,popupText,popupHighlight=Color3.new(1,1,1),Color3.new(0,0,0),Color3.fromRGB(0,117,255)
	local pickerStates={}
	local function state(name,index)
		if not wholeView then return end
		local c=self.Control;local node=if c and index and index>0 and c.Options[index]then c.Options[index].Node else nil
		if pickerStates[name]==node then return end;pickerStates[name]=node
		if self.StateChanged then self.StateChanged(name,node)end
		if wholeView and wholeView:RefreshState()then self:Refresh()end
	end
	local watchedAnchor,watchedDependencies=nil,{}
	local function watchAnchor(c)
		local box=c.Item.BoxGui
		local dependencies=if wholeView then wholeView.AnchorDependencies or{}else{}
		local same=watchedAnchor==box
		if same then
			for gui in dependencies do if gui~=box and gui~=page.Root and not watchedDependencies[gui]then same=false;break end end
			for gui in watchedDependencies do if not dependencies[gui]then same=false;break end end
		end
		if same then return end
		for _,connection in connections do connection:Disconnect()end;table.clear(connections)
		watchedAnchor=box
		table.clear(watchedDependencies)
		local entries={{box,'AbsolutePosition'},{box,'AbsoluteSize'},{page.Root,'AbsoluteSize'}}
		for gui in dependencies do
			if gui~=box and gui~=page.Root then
				watchedDependencies[gui]=true;table.insert(entries,{gui,'AbsolutePosition'});table.insert(entries,{gui,'AbsoluteSize'})
			end
		end
		for _,entry in entries do
			table.insert(connections,entry[1]:GetPropertyChangedSignal(entry[2]):Connect(function()
				-- An appearance change can retire the anonymous native face while
				-- the public control and open picker remain. Ignore its late signal.
				if self.Control==c and c.Item.BoxGui~=box then return end
				if self.CustomPicker then self:Refresh()else self:Close()end
			end))
		end
	end
	local function customPicker(c)
		if c.Item.ResolvePickerStyle then c.PickerStyle=c.Item.ResolvePickerStyle()end
		return fragments~=nil and fragments.MountPicker~=nil and c.Item.Style.Appearance=='base-select' and c.PickerStyle~=nil and c.PickerStyle.Appearance=='base-select'
	end
	local function positionedPicker(c)
		local s=c.PickerStyle
		return s and ((s.PositionAnchor or 'normal')~='normal'or(s.PositionArea or 'none')~='none'or s.Insettop~=nil or s.Insetright~=nil or s.Insetbottom~=nil or s.Insetleft~=nil)
	end
	local function palette(c)
		local style=c.Item.Style;local pickerStyle=if self.CustomPicker then c.PickerStyle else nil
		popupBackground=if pickerStyle and pickerStyle.Background then pickerStyle.Background elseif style.ControlBackgroundSpecified and style.Background then style.Background else Color3.new(1,1,1)
		popupText=if pickerStyle then pickerStyle.Color else style.Color or Color3.new(0,0,0)
		if scroll and not wholeView then scroll.BackgroundColor3=popupBackground end
	end
	local function fit(c)
		local root,box=page.Root,c.Item.BoxGui
		local p,size,viewport,bounds=box.AbsolutePosition,box.AbsoluteSize,root.AbsolutePosition,root.AbsoluteSize
		if wholeView and wholeView.Placement then
			local placed=wholeView.Placement
			viewHeight=placed.Height
			host.Size=UDim2.fromOffset(placed.Width,placed.Height)
			host.Position=UDim2.fromOffset(viewport.X+placed.X-host.Parent.AbsolutePosition.X,viewport.Y+placed.Y-host.Parent.AbsolutePosition.Y)
			return true
		end
		local desired=if wholeView then wholeView.Tree.OuterHeight else math.min(math.max(totalHeight,rowHeight),rowHeight*8)+2
		local below=math.max(0,viewport.Y+bounds.Y-p.Y-size.Y);local above=math.max(0,p.Y-viewport.Y)
		local useAbove=below<desired and above>below
		local height=math.min(desired,if useAbove then above else below)
		if height<3 then self:Close();return false end
		viewHeight=if wholeView then height else height-2
		local x=math.clamp(p.X,viewport.X,viewport.X+bounds.X-popupWidth)
		local y=if useAbove then p.Y-height else p.Y+size.Y
		host.Size=UDim2.fromOffset(popupWidth,height)
		host.Position=UDim2.fromOffset(x-host.Parent.AbsolutePosition.X,y-host.Parent.AbsolutePosition.Y)
		return true
	end
	function self:Close()
		local previous=self.Control
		for name,node in pickerStates do if node and self.StateChanged then self.StateChanged(name,nil)end end;table.clear(pickerStates)
		revision+=1
		search:Reset()
		self.Control, self.Highlight, self.CustomPicker = nil, 0, false
		watchedAnchor=nil
		table.clear(watchedDependencies)
		pointer, downIndex, origin = nil, nil, nil
		for _,connection in connections do connection:Disconnect() end
		if wholeView then wholeView:Destroy();wholeView=nil end;wholeHost=nil;self.PickerView=nil
		table.clear(connections); table.clear(rows); table.clear(labels);  table.clear(rowIndexes)
		table.clear(optionTops)
		table.clear(optionHeights);table.clear(rowRanges)
		table.clear(rowsByNode);table.clear(rowSources)
		if host then host:Destroy(); host=nil; scroll=nil;nativeScroll=nil end
		if previous and page.SetControlPickerOpen then page:SetControlPickerOpen(previous,false)end
	end
	function self:HighlightRow(index: number)
		local c=self.Control
		if not c or not c.Options[index] or c.Options[index].Disabled then return end
		self.Highlight=index
		if wholeView then return end
		for i,row in rows do
			local highlighted=i==index
			row.BackgroundTransparency=if highlighted then 0 else 1
			labels[i].TextColor3=if c.Options[i].Disabled then Color3.fromRGB(153,153,153)
				elseif highlighted then Color3.new(1,1,1) else popupText
		end
	end
	local function refreshRows(c,entries)
		local currentRevision=revision
		local function current()return revision==currentRevision and self.Control==c end
		if self.CustomPicker and fragments and fragments.MountPicker then
			for _,entry in rowsByNode do entry.Gui:Destroy()end
			table.clear(rowsByNode);table.clear(rows);table.clear(labels);table.clear(rowIndexes);table.clear(optionTops);table.clear(optionHeights);table.clear(rowRanges);table.clear(rowSources)
			nativeScroll.Visible=false;host.BackgroundTransparency=1;host.ClipsDescendants=false
			local p,size,bounds,viewport=c.Item.BoxGui.AbsolutePosition,c.Item.BoxGui.AbsoluteSize,page.Root.AbsoluteSize,page.Root.AbsolutePosition
			local below=math.max(0,viewport.Y+bounds.Y-p.Y-size.Y);local above=math.max(0,p.Y-viewport.Y)
			local availableWidth=math.max(0,if c.Item.Style.Direction=='rtl'then p.X+size.X-viewport.X else viewport.X+bounds.X-p.X)
			local minimum=if c.PickerStyle.MinHeight then Length.resolve(c.PickerStyle.MinHeight,below)else 0
			local availableHeight=if below<minimum and above>=minimum then above else below
			if not wholeView then
				local mountHost=factory.create('Frame',host,{Name='PickerContent',BackgroundTransparency=1})
				wholeHost=mountHost
				local mounted=fragments.MountPicker(c.Node,mountHost,bounds.X,function()if current()then self:Refresh()end end)
				if not current()then if mounted then mounted:Destroy()end;if mountHost.Parent then mountHost:Destroy()end;return false end
				if not mounted then self:Close();return false end
				wholeView=mounted;self.PickerView=mounted
			end
			local positioned=positionedPicker(c)
			wholeView:Arrange(if positioned then bounds.X else availableWidth,{AnchorWidth=math.min(size.X,bounds.X),MaxHeight=availableHeight,ViewportHeight=bounds.Y,Positioned=positioned,
				ViewportOrigin={X=viewport.X,Y=viewport.Y},Implicit={X=p.X-viewport.X,Y=p.Y-viewport.Y,Width=size.X,Height=size.Y,Style=c.Item.Style}})
			if not current()then return false end
			local view=wholeView.Tree;popupWidth=if positioned then view.OuterWidth else math.min(bounds.X,view.OuterWidth);totalHeight=view.OuterHeight
			wholeHost.Size=UDim2.fromOffset(view.OuterWidth,view.OuterHeight);wholeHost.Position=UDim2.fromOffset(0,0)
			scroll=view.ScrollGui
			local optionIndexes={};for index,option in c.Options do optionIndexes[option.Node]=index end
			local function walk(box,x,y)
				for _,child in box.Children do
					if child.Kind=='Words'then continue end
					local left,top=x+(child.LayoutX or 0),y+(child.LayoutY or 0);local index=optionIndexes[child.Node]
					if index then
						rows[index],rowSources[index]=child.Gui,child.Node;rowIndexes[child.Gui]=index
						optionTops[index],optionHeights[index]=top,child.OuterHeight
						table.insert(rowRanges,{Left=left,Width=child.OuterWidth,Top=top,Height=child.OuterHeight,Index=index})
					end
					walk(child,left,top)
				end
			end
			walk(view,view.LayoutX or 0,view.LayoutY or 0)
			return true
		end
		if wholeView then wholeView:Destroy();wholeView=nil;wholeHost:Destroy();wholeHost=nil;self.PickerView=nil end
		scroll=nativeScroll;nativeScroll.Visible=true;host.BackgroundTransparency=0;host.ClipsDescendants=true;palette(c)
		local old,kept=rowsByNode,{}
		rowsByNode=kept
		table.clear(rows);table.clear(labels);table.clear(rowIndexes);table.clear(optionTops);table.clear(rowSources)
		table.clear(optionHeights);table.clear(rowRanges);totalHeight=0
		for rowIndex,option in entries do
			if not current()then return false end
			local key=option.Node or option;local entry=old[key];local top=totalHeight;local height=rowHeight
			if not entry then
				if option.IsGroup then
					local row=factory.create("Frame",scroll,{Name="Group_"..rowIndex,BackgroundTransparency=1})
					local label=factory.create("TextLabel",row,{Name="GroupText_"..rowIndex,BackgroundTransparency=1,TextYAlignment=Enum.TextYAlignment.Center})
					entry={Gui=row,Label=label}
				else
					local row=factory.create("Frame",scroll,{Name="Option_"..(option.OptionIndex or rowIndex),BackgroundTransparency=1,
						Position=UDim2.fromOffset(0,top),Size=UDim2.new(1,0,0,rowHeight)})
					local label=factory.create("TextLabel",row,{Name="OptionText_"..(option.OptionIndex or rowIndex),BackgroundTransparency=1,TextYAlignment=Enum.TextYAlignment.Center})
					entry={Gui=row,Label=label}
				end
			end
			kept[key]=entry;entry.Option=option
			local label=entry.Label;label.Text=option.Caption;label.TextSize=View.metrics(c.Item).TextSize;label.OpenTypeFeatures=c.Item.Style.OpenTypeFeatures
			label.FontFace=if option.IsGroup then c.Item.GroupFontFace or c.Item.FontFace else c.Item.FontFace
			label.TextColor3=if option.Disabled then Color3.fromRGB(153,153,153) else popupText
			if option.IsGroup then
				entry.Gui.Position=UDim2.fromOffset(0,top);entry.Gui.Size=UDim2.new(1,0,0,height)
				label.Position=UDim2.fromOffset(3,0);label.Size=UDim2.new(1,-9,1,0)
				table.insert(rowRanges,{Top=top,Height=height,Index=0});totalHeight+=height;continue
			end
			local index=option.OptionIndex or rowIndex;local indent=if option.Grouped then Options.Indent else 0
			entry.Gui.Position=UDim2.fromOffset(0,top);entry.Gui.Size=UDim2.new(1,0,0,rowHeight)
			entry.Gui.BackgroundColor3=popupHighlight
			rows[index],labels[index],rowSources[index]=entry.Gui,label,key
			rowIndexes[entry.Gui],rowIndexes[label]=index,index;optionTops[index]=top
			label.Position=UDim2.fromOffset(3+indent,0);label.Size=UDim2.new(1,-9-indent,1,0)
			entry.Gui.Size=UDim2.new(1,0,0,height);optionHeights[index]=height
			table.insert(rowRanges,{Top=top,Height=height,Index=index});totalHeight+=height
		end
		for key,entry in old do if not kept[key] then entry.Gui:Destroy() end end
		scroll.CanvasSize=UDim2.fromOffset(0,totalHeight);return true
	end
	local buildRows=refreshRows
	refreshRows=function(c,entries)
		local token=revision
		if refreshingRevision==token then pendingRefresh=token;return false end
		refreshingRevision=token
		local ok,result=pcall(function()
			repeat
				pendingRefresh=nil
				if not buildRows(c,entries)then return false end
				entries=c.SelectRows or c.Options
			until pendingRefresh~=token or revision~=token
			return revision==token and self.Control==c
		end)
		if refreshingRevision==token then refreshingRevision=nil end
		if not ok then if revision==token then self:Close()end;error(result,0)end
		return result
	end
	function self:Refresh()
		local c=self.Control
		if not c then return end
		local entries=c.SelectRows or c.Options
		if not page.Alive or c.Disabled or c.SelectList or #entries==0 and c.Datalist then self:Close();return end
		-- Keep the popup and semantic open state through a live appearance change.
		-- Reopening would briefly match :not(:open), breaking state-dependent rules.
		self.CustomPicker=customPicker(c);palette(c)
		local highlighted=rowSources[self.Highlight]
		pointer,downIndex,origin=nil,nil,nil;search:Reset()
		rowHeight=math.max(20,View.metrics(c.Item).TextSize+6);if not refreshRows(c,entries)or not fit(c)then return end
		watchAnchor(c)
		local index=0
		for candidate,option in c.Options do if (option.Node or option)==highlighted and not option.Disabled then index=candidate;break end end
		if index==0 then index=if c.SelectedIndex>0 and c.Options[c.SelectedIndex] and not c.Options[c.SelectedIndex].Disabled then c.SelectedIndex else Options.next(c,0,1) end
		self.Highlight=0;self:HighlightRow(index);self:Reveal()
	end
	function self:Open(c: any)
		self:Close()
		local entries=c.SelectRows or c.Options
		if not page.Alive or c.Disabled or c.SelectList or #entries==0 and c.Datalist then return end
		factory = factory or require(script.Parent.Parent.Rendering.GuiFactory)
		local root, box = page.Root, c.Item.BoxGui
		local p,size=box.AbsolutePosition,box.AbsoluteSize
		local viewport, bounds=root.AbsolutePosition,root.AbsoluteSize
		self.CustomPicker=customPicker(c)
		if not self.CustomPicker and(size.X<=0 or size.Y<=0)then return end
		local positioned=self.CustomPicker and positionedPicker(c)
		if (not positioned and (p.Y+size.Y <= viewport.Y or p.Y >= viewport.Y+bounds.Y))or bounds.X <= 0 or bounds.Y <= 2 then return end
		local parent=root.Parent
		if not parent then return end
		local style=c.Item.Style
		palette(c)
		popupHighlight=Color3.fromRGB(0,117,255)
		rowHeight=math.max(20,View.metrics(c.Item).TextSize+6)
		local desired=math.min(8,math.max(1,#entries))*rowHeight+2
		local below=math.max(0,viewport.Y+bounds.Y-p.Y-size.Y)
		local above=math.max(0,p.Y-viewport.Y)
		local useAbove=below < desired and above > below
		local height=math.min(desired,if useAbove then above else below)
		if height < 3 then
			if not positioned then return end
			-- The temporary host is replaced by the ordinary positioned solver.
			-- Author insets can place it independently of an offscreen/large select.
			height=3
		end
		viewHeight=height-2
		local width=math.min(bounds.X,size.X)
		popupWidth=width
		local x=math.clamp(p.X,viewport.X,viewport.X+bounds.X-width)
		local y=if useAbove then p.Y-height else p.Y+size.Y
		host=factory.create("Frame",parent,{Name=if c.Datalist then "DatalistPopup" else "SelectPopup",ZIndex=1000000,Position=UDim2.fromOffset(x-parent.AbsolutePosition.X,y-parent.AbsolutePosition.Y),
			Size=UDim2.fromOffset(width,height),BackgroundTransparency=0,BackgroundColor3=Color3.fromRGB(118,118,118),ClipsDescendants=true})
		scroll=factory.create("ScrollingFrame",host,{Name="Options",Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),
			BackgroundTransparency=0,BackgroundColor3=popupBackground,CanvasSize=UDim2.fromOffset(0,#entries*rowHeight),CanvasPosition=Vector2.new(0,0),
			ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=6,ElasticBehavior=Enum.ElasticBehavior.Never})
		nativeScroll=scroll
		self.Control=c
		if not refreshRows(c,entries)then return end
		if not fit(c)then return end
		local initial=if c.Datalist then (if entries[1] then entries[1].OptionIndex else 0)
			elseif c.SelectedIndex > 0 and not c.Options[c.SelectedIndex].Disabled then c.SelectedIndex else Options.next(c,0,1)
		self:HighlightRow(initial)
		self:Reveal()
		-- Custom pickers keep their CSS tree through anchor/viewport movement.
		watchAnchor(c)
		if page.SetControlPickerOpen then page:SetControlPickerOpen(c,true)end
		if self.Control==c and page.SetControlPickerOpen then self:Refresh()end
	end
	function self:Filter(c: any,value: string,open: boolean?)
		if not c.Datalist then return end
		local query=string.lower(value):match("^%s*(.-)%s*$")
		local matches={}
		for _,option in c.Options do
			local searchable=string.lower(option.Value.." "..option.Caption)
			if not option.Disabled and (query=="" or searchable:find(query,1,true)) then table.insert(matches,option) end
		end
		c.SelectRows=matches
		if self.Control == c or open then
			if #matches == 0 then self:Close() else self:Open(c) end
		end
	end
	function self:Reveal()
		if not scroll or self.Highlight == 0 then return end
		local top=optionTops[self.Highlight]
		if top == nil then return end
		local y=scroll.CanvasPosition.Y
		local height=optionHeights[self.Highlight]or rowHeight
		if top < y then y=top elseif top+height > y+viewHeight then y=top+height-viewHeight end
		scroll.CanvasPosition=Vector2.new(0,math.max(0,y))
	end
	function self:Hit(objects: any,position: any): number?
		if not host then return nil end
		local p,size=host.AbsolutePosition,host.AbsoluteSize
		if position.X < p.X or position.X >= p.X+size.X or position.Y < p.Y or position.Y >= p.Y+size.Y then return nil end
		for _,object in objects do
			local gui,index=object,nil
			while gui do
				index=index or rowIndexes[gui]
				if gui == host then return index or 0 end
				gui=gui.Parent
			end
			if object.Active then break end
		end
		-- Roblox can report the focused TextBox instead of a popup descendant
		-- while focus is changing. Geometry is authoritative inside the popup.
		local canvasY=if scroll then scroll.CanvasPosition.Y else 0
		local localY=position.Y-p.Y-(if wholeView then 0 else 1)+canvasY
		local localX=position.X-p.X+(if scroll then scroll.CanvasPosition.X else 0)
		for _,range in rowRanges do if localY>=range.Top and localY<range.Top+range.Height
			and (not range.Left or localX>=range.Left and localX<range.Left+range.Width)then return range.Index end end
		return 0
	end
	function self:Begin(event: any,objects: any): boolean
		if not self.Control then return false end
		local index=self:Hit(objects,event.Position)
		if index == nil then self:Close()
		elseif not pointer and index > 0 then pointer,downIndex,origin=event,index,event.Position;state('active',index)end
		return true
	end
	function self:IsPressing(c: any): boolean
		return self.Control == c and pointer ~= nil
	end
	function self:Move(event: any,objects: any)
		if not self.Control then return end
		if event.UserInputType == Enum.UserInputType.MouseMovement then
			local index=self:Hit(objects,event.Position);state('hover',index);if index then self:HighlightRow(index) end
		elseif event == pointer and origin and (event.Position-origin).Magnitude > 6 then downIndex=nil end
	end
	function self:Finish(event: any,objects: any): boolean
		if not pointer or not (event == pointer or (pointer.UserInputType == Enum.UserInputType.MouseButton1 and event.UserInputType == Enum.UserInputType.MouseButton1)) then return false end
		local index=self:Hit(objects,event.Position)
		local c,selected=self.Control,downIndex
		pointer,downIndex,origin=nil,nil,nil
		state('active',nil)
		if c and selected and selected == index and not c.Options[selected].Disabled then
			local token=revision;choose(c,selected);if revision==token then self:Close()end
		end
		return true
	end
	function self:Commit()
		local c,index=self.Control,self.Highlight
		local token=revision
		if c and index > 0 then choose(c,index) end
		if revision==token then self:Close()end
	end
	function self:MoveSelection(c: any,step: number)
		search:Reset()
		local index
		if c.Datalist then
			local available={}
			for _,option in c.SelectRows or {} do table.insert(available,option.OptionIndex) end
			local at=table.find(available,if self.Control == c then self.Highlight else c.SelectedIndex)
			if #available>0 then index=available[math.clamp((at or (if step>0 then 0 else #available+1))+step,1,#available)] end
		else index=Options.next(c,if self.Control == c then self.Highlight else c.SelectedIndex,step) end
		if self.Control == c then self:HighlightRow(index); self:Reveal() else choose(c,index) end
	end
	function self:ResetSearch() search:Reset() end
	function self:Type(c: any,character: string): boolean
		local handled,index=search:Find(c,if self.Control == c then self.Highlight else c.SelectedIndex,character)
		if index then
			if self.Control == c then self:HighlightRow(index); self:Reveal() else choose(c,index) end
		end
		return handled
	end
	return self
end
return Popup
