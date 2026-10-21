--!strict
return function(Parser,Node,Style,Computed,loadRenderTree,loadWordLayout,loadBlockLayout,reference,loadHTMLPage)
	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
		function api:Count()local count=0;for _,entry in listeners do if entry[1].Connected then count+=1 end end;return count end
		return api
	end
	local allocated={};local factory={create=function(class,parent,props)
		local gui=table.clone(props or{});gui.ClassName,gui.Parent=class,parent;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,600);gui.Visible=true
		gui.AnchorPoint=gui.AnchorPoint or Vector2.new(0,0);gui.Position=gui.Position or UDim2.fromOffset(0,0);gui.Destroying=signal()
		if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0);gui.ScrollBarThickness=gui.ScrollBarThickness or 10 end
		local signals,attributes,attributeSignals={},{},{}
		function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:GetAttributeChangedSignal(key)attributeSignals[key]=attributeSignals[key]or signal();return attributeSignals[key]end
		function gui:SetAttribute(key,value)local changed=attributes[key]~=value;attributes[key]=value;if changed and attributeSignals[key]then attributeSignals[key]:Fire()end end
		function gui:IsA(kind)return kind==self.ClassName or kind=='GuiObject'end
		function gui:Destroy()
			assert(not self.Destroyed,'Picker anchor double cleanup');self.Destroyed=true
			self.Destroying:Fire();for _,child in allocated do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil
		end
		table.insert(allocated,gui);return gui
	end};factory.modifier=factory.create
	local renderer=loadRenderTree(factory)
	local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
	local Popup=require('Input/SelectPopup');local Picker=require('Rendering/PickerFragments');local checked=0
	local function near(a,b,label)assert(math.abs(a-b)<.04,label..': '..tostring(a)..' != '..tostring(b))end
	local function syncGUI(tree,root)
		local function sync(box,x,y)
			if box.Gui and box.Gui~=root then box.Gui.AbsolutePosition=Vector2.new(x,y);box.Gui.AbsoluteSize=Vector2.new(box.OuterWidth or 0,box.OuterHeight or 0)end
			if box.ImageItem then local item=box.ImageItem;item.BoxGui.AbsolutePosition=Vector2.new(x,y);item.BoxGui.AbsoluteSize=Vector2.new(box.OuterWidth or 0,box.OuterHeight or 0)end
			for _,child in box.PositioningChildren or box.Children or{}do if child.Kind~='Words'then sync(child,x+(child.PaintX or child.LayoutX or 0),y+(child.PaintY or child.LayoutY or 0))end end
		end
		sync(tree,root.AbsolutePosition.X,root.AbsolutePosition.Y)
	end
	local keywords=Node.element('div',{})
	for _,word in {'normal','none','auto','AuTo','n\\6f rmal'}do
		keywords.Attributes.style='position-anchor:'..word
		local style=Style.resolve(keywords,{},error)
		assert(Computed.read(style,nil,{Width=800,Height=600}).Values['position-anchor']==(if word=='AuTo'then'auto'elseif word=='n\\6f rmal'then'normal'else word),'Anchor keyword syntax/computed serialization')
	end
	for _,word in {'auto none','normal --anchor','--one --two','invalid'}do assert(Style.compile('position-anchor:'..word).Normal[1].Error,'Invalid anchor references are rejected')end
	for _,case in reference.cases do
		local document=Parser.parseDocument(case.html);local parent=factory.create('Frame',nil,{});local root=factory.create('ScrollingFrame',parent,{})
		parent.AbsolutePosition=Vector2.new(11,19);root.AbsolutePosition=Vector2.new(43,67)
		local tree=renderer.build(document,root,error);tree.ViewportHeight=600
		local select=Node.findById(document,'s');local control=tree.Controls[1];local page={Alive=true,Root=root}
		local popup=Popup.new(page,function()end,factory,nil,Picker.new(page,tree,error,{PickerLayout=layout}))
		function page:SetControlPickerOpen(_,open)tree:SetCSSState('open',if open then select else nil)end
		local view,retained,options,saved,styleIdentity
		local function arrange()
			layout.arrange(tree,root.AbsoluteSize.X,0,0,function()return true end)
			syncGUI(tree,root)
		end
		for index,step in case.steps do
			local changes={}
			for id,css in step.styles or{}do local node=Node.findById(document,id);node.Attributes.style=css;changes[node]={Attributes={style=true}}end
			if step.picker then
				local sheet=Node.findById(document,'pickerChanges')
				if not sheet then sheet=Node.element('style',{id='pickerChanges'});Node.append(sheet,Node.text(''));Node.append(Node.findElement(document,function(n)return n.Name=='head'end),sheet);changes[sheet.Parent]={Children=true}end
				sheet.Children[1].Text='select::picker(select){'..step.picker..'}';changes[sheet]={Text=true}
			end
			if next(changes)then tree:ApplyDOMChanges(changes)end
			if step.viewport then root.AbsoluteSize=Vector2.new(step.viewport.width,step.viewport.height);tree.ViewportHeight=step.viewport.height end
			arrange()
			if index==1 then
				popup:Open(control);view=assert(popup.PickerView,'Actual custom picker mounted').Tree;retained=view.Gui;styleIdentity=view.Style
				options={};for _,option in control.Options do options[option.Node]=view.NodeBoxes[option.Node].Gui end
				saved={};for node,box in tree.NodeBoxes do saved[node]=box.Gui end
			else
				assert(case.expected[index].stayedOpen,'Native mutation/resize keeps the picker open')
				local published=false
				if step.viewport then root:GetPropertyChangedSignal('AbsoluteSize'):Fire();published=true
				elseif step.styles and step.styles.s then control.Item.BoxGui:GetPropertyChangedSignal('AbsolutePosition'):Fire();published=true
				else
					for node in changes do
						local box=tree.NodeBoxes[node];local gui=box and(if box.ImageItem then box.ImageItem.BoxGui else box.Gui)
						if gui and popup.PickerView.AnchorDependencies and popup.PickerView.AnchorDependencies[gui]then
							assert(gui:GetPropertyChangedSignal('AbsolutePosition'):Count()>0,'Referenced named anchor is subscribed while the select stays unchanged')
							gui:GetPropertyChangedSignal('AbsolutePosition'):Fire();published=true
						end
					end
				end
				if not published then popup:Refresh()end -- Shared page publication handles scope/rule changes.
				assert(popup.Control==control and popup.PickerView.Tree==view and view.Gui==retained and view.Style==styleIdentity and not retained.Destroyed,'Anchor change/resize retains picker, style and semantic open state')
				for node,gui in saved do assert(tree.NodeBoxes[node].Gui==gui,'Anchor placement preserves unrelated page surfaces')end
			end
			local expected=table.clone(case.expected[index]);for key,value in expected.normative or{}do expected[key]=value end
			local placed=assert(popup.PickerView.Placement,'Author picker CSS uses the normal positioned solver')
			near(placed.X,expected.x,case.name..' state '..index..' x');near(placed.Y,expected.y,case.name..' state '..index..' y')
			near(view.OuterWidth,expected.width,case.name..' width');near(view.OuterHeight,expected.height,case.name..' height')
			local host=view.Gui.Parent.Parent
			near(host.Position[1],expected.x+root.AbsolutePosition.X-parent.AbsolutePosition.X,'Retained host x');near(host.Position[2],expected.y+root.AbsolutePosition.Y-parent.AbsolutePosition.Y,'Retained host y')
			for _,option in control.Options do
				local box=view.NodeBoxes[option.Node];local wanted=expected.boxes[option.Node.Attributes.id]
				near(placed.X+(box.LayoutX or 0),wanted[1],'Option world x');near(placed.Y+(box.LayoutY or 0),wanted[2],'Option world y')
				near(box.OuterWidth,wanted[3],'Option width');near(box.OuterHeight,wanted[4],'Option height')
				assert(box.Gui==options[option.Node]and option.Node.Parent==select,'Option identity and author parent are preserved')
			end
			local computed=Computed.read(view.Style,nil,{Width=root.AbsoluteSize.X,Height=root.AbsoluteSize.Y}).Values
			assert(computed['position-anchor']==expected.positionAnchor and computed['position-area']==expected.positionArea,'Picker reference keywords serialize actual cascade')
			checked+=1
		end
		local watched=control.Item.BoxGui;local dependencies=popup.PickerView.AnchorDependencies;popup:Close();assert(retained.Destroyed and watched:GetPropertyChangedSignal('AbsolutePosition'):Count()==0 and root:GetPropertyChangedSignal('AbsoluteSize'):Count()==0,'Picker close releases surfaces and anchor/viewport subscriptions')
		for gui in dependencies or{}do assert(gui:GetPropertyChangedSignal('AbsolutePosition'):Count()==0 and gui:GetPropertyChangedSignal('AbsoluteSize'):Count()==0,'Picker close releases named-anchor subscriptions')end
		page.Alive=false;parent:Destroy()
	end
	assert(checked==26,'Native picker anchor coverage changed')
	-- Real page publication must refresh after layout. A DOM/style batch can
	-- refresh the popup earlier, before a foreign anchor's used GUI size exists.
	local time,jobs,tree,page,popup,request=0,{},nil,nil,nil,nil
	local tasks={defer=function(fn)table.insert(jobs,fn)end,delay=function(_,fn)table.insert(jobs,fn)end,cancel=function()end,wait=function()error('Small picker publication fixture unexpectedly yielded')end}
	local function drain()local rounds=0;while #jobs>0 do rounds+=1;assert(rounds<30,'Picker publication did not settle');time+=.02;table.remove(jobs,1)()end end
	local module=loadHTMLPage({
		['Rendering/GuiFactory']=factory,
		['Rendering/RenderTree']={build=function(document,root,diagnostic)tree=renderer.build(document,root,diagnostic,function(font)return font end);return tree end},
		['Layout/BlockLayout']={arrange=function(...)local height,width=layout.arrange(...);syncGUI(tree,page.Root);return height,width end},
		['Input/Controller']={start=function(owner,_,schedule)
			request=schedule;popup=Popup.new(owner,function()end,factory,nil,Picker.new(owner,tree,error,{PickerLayout=layout}))
			function owner:SetControlPickerOpen(c,open)tree:SetCSSState('open',if open then c.Node else nil)end
			function owner:RefreshControlPickers()if popup.Control then popup:Refresh()end end
			owner:AddCleanup(function()popup:Close();owner.RefreshControlPickers=nil end)
		end},
		['Rendering/HTMLScripts']={ShouldStart=function()return false end,hasScripts=function()return false end,start=function()end},
	},tasks,function()return time end)
	local case=reference.cases[3]
	page=module.mount(factory.create('Frame',nil,{}),case.html,{JavaScript=false,RenderWorkBudgetMS=0});drain()
	-- Real image/font jobs are covered by RichSelectRendering. This text-only
	-- fixture isolates page publication without invoking native resource APIs.
	local resourceHost=page.ResourceLoadHost;page.ResourceLoadHost=nil
	local control=tree.Controls[1];popup:Open(control);local retained=popup.PickerView.Tree.Gui
	near(popup.PickerView.Placement.X,case.expected[1].x,'Real page initial named anchor')
	local anchor=Node.findById(page.Document,'other');anchor.Attributes.style=case.steps[2].styles.other
	tree:ApplyDOMChanges({[anchor]={Attributes={style=true}}});popup:Refresh()
	near(popup.PickerView.Placement.X,case.expected[1].x,'Before layout the anchor GUI still has its previous used position')
	request(true,tree.NodeBoxes[anchor]);drain()
	near(popup.PickerView.Placement.X,case.expected[2].x,'Page publication updates the foreign anchor after layout')
	near(popup.PickerView.Placement.Y,case.expected[2].y,'Page publication updates the foreign anchor height after layout')
	assert(popup.PickerView.Tree.Gui==retained and popup.Control==control,'Page publication retains the open picker and its surface')
	page.ResourceLoadHost=resourceHost;page:Destroy();drain();assert(retained.Destroyed and not popup.Control,'Real page destruction closes its picker')
	print('Rich select anchors: '..checked..' native coordinate/size/scope/fallback/resize states, original DOM and retained popup surfaces passed')
end
