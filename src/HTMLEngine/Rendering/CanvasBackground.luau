--!strict
-- Transfer used paint; keep the DOM owners' computed styles intact.
local Accessors=require(script.Parent.Parent.DOM.DocumentAccessors)
local GroupOpacity=require(script.Parent.GroupOpacity)
local BoxTransform=require(script.Parent.BoxTransform)
local PaintLayer=require(script.Parent.PaintLayer)
local BorderGeometry=require(script.Parent.Parent.Layout.BorderGeometry)
local Color=require(script.Parent.Parent.CSS.Color)
local CanvasBackground={}
local originalSurfaces=setmetatable({},{__mode='k'})
local inlineOwners=setmetatable({},{__mode='kv'})
local inlineUsers=setmetatable({},{__mode='k'})
local fields={'Background','BackgroundAlpha','BackgroundImages','BackgroundSizes','BackgroundPositions','BackgroundOrigins','BackgroundClips','BackgroundAttachments','BackgroundRepeats','BackgroundBlendMode','ImageRendering'}
-- Only inputs consumed by BackgroundImages can change this synthetic paint.
-- Keep the complete used style for its consumers, but do not turn inherited
-- cursor/selection state or unrelated root styles into a new raster request.
local paintFields=table.clone(fields)
for _,key in {'Color','ColorAlpha','BorderSize','BorderSizes','Padding','ViewportWidth','ViewportHeight'}do table.insert(paintFields,key)end
local emptyImages={{Kind='none'}}
function CanvasBackground.isDocument(document: any): boolean return document.Kind=='Document'and not document.LegacyFragment end
function CanvasBackground.documentRoot(document: any): any return if CanvasBackground.isDocument(document)then Accessors.root(document)else nil end
local function images(style: any): boolean
	for _,image in style and style.BackgroundImages or{}do if image.Kind~='none'then return true end end;return false
end
local function colored(style: any): boolean return style~=nil and style.Background~=nil and(style.BackgroundAlpha or 1)>0 end
local function contained(style: any): boolean
	if not style then return false end
	for _,active in style.Contain or{}do if active then return true end end
	local kind=style.ContainerType or'normal'
	return style.ContentVisibility=='auto'or style.ContentVisibility=='hidden'or kind=='size'or kind=='inline-size'or kind=='size scroll-state'or kind=='inline-size scroll-state'
end
function CanvasBackground.plan(document: any,nodeStyles: any): any
	local root=CanvasBackground.documentRoot(document);local rootStyle=root and nodeStyles[root]
	local body=if Accessors.matches(root,'html',Accessors.HTML)then Accessors.child(root,'body',Accessors.HTML)else nil
	local bodyStyle=body and nodeStyles[body]
	local owner,style,source=root,rootStyle,'html'
	if not colored(rootStyle)and not images(rootStyle)and bodyStyle and not contained(rootStyle)and not contained(bodyStyle)then owner,style,source=body,bodyStyle,'body'end
	local displayed=style~=nil and style.Display~='none'and(not rootStyle or rootStyle.Display~='none')
	local paint=displayed and(colored(style)or images(style))
	local dark=CanvasBackground.isDocument(document)and(rootStyle or bodyStyle or nodeStyles[document]or{}).DarkScheme
	return {Root=root,RootStyle=rootStyle,Owner=owner,Style=style,Source=if paint then source elseif dark then'color-scheme'else nil,Paint=paint,Dark=dark==true}
end
function CanvasBackground.resolve(document: any,nodeStyles: any): (any?,number?,string?)
	local plan=CanvasBackground.plan(document,nodeStyles)
	if plan.Paint then return plan.Style.Background,plan.Style.BackgroundAlpha or 1,plan.Source end
	if plan.Dark then return Color3.fromRGB(18,18,18),1,'color-scheme'end;return nil,nil,nil
end
-- Stable projections also feed corner, shape and perspective raster sources.
function CanvasBackground.usedStyle(box: any,style: any?): any
	style=style or box.Style;if not box.CanvasBackgroundSuppressed then return style end
	local used=box.CanvasUsedBackgroundStyle;if not used then used={};box.CanvasUsedBackgroundStyle=used end
	table.clear(used);for key,value in style do used[key]=value end
	used.Background=nil;used.BackgroundAlpha=1;used.BackgroundImages=emptyImages;return used
end
function CanvasBackground.inlineBackground(style: any): (any?,number)
	if not style.InlineBackground or not style.InlineBackgroundSources then return style.InlineBackground,style.InlineBackgroundAlpha or 1 end
	local excluded=false;local covered=0;local source=style.InlineBackgroundSources
	while source do
		local node=source.Node;local parent=node.Parent
		-- Only the actual root and a direct HTML body can acquire canvas paint.
		-- Do not retain a user set for every colored inline ancestor.
		if parent and(parent.Kind=='Document'and CanvasBackground.documentRoot(parent)==node or Accessors.matches(node,'body',Accessors.HTML)and Accessors.matches(parent,'html',Accessors.HTML)and parent.Parent and parent.Parent.Kind=='Document'and CanvasBackground.documentRoot(parent.Parent)==parent)then
			local users=inlineUsers[node]
			if not users then users=setmetatable({},{__mode='k'});inlineUsers[node]=users end
			users[style]=true
		end
		local owner=inlineOwners[node]
		if owner and owner.Alive then excluded=true
		else covered+=(source.Alpha or 1)*(1-covered);if covered>=1 then break end end
		source=source.Parent
	end
	if not excluded then return style.InlineBackground,style.InlineBackgroundAlpha or 1 end
	local color,alpha=nil,0;source=style.InlineBackgroundSources
	while source do
		local owner=inlineOwners[source.Node]
		if not owner or not owner.Alive then
			if color then color,alpha=Color.over(color,alpha,source.Color,source.Alpha)
			else color,alpha=source.Color,source.Alpha end
			if alpha>=1 then break end
		end
		source=source.Parent
	end
	return color,alpha
end
function CanvasBackground.new(root: any,document: any,tree: any,renderer: any,factory: any): any
	local state={Alive=true,Dirty=true,PaintStyle={}}
	local original={Color=root.BackgroundColor3,Transparency=root.BackgroundTransparency}
	local plane=PaintLayer.create(factory,'Frame',root,{Name='CanvasBackground',BackgroundTransparency=1,ZIndex=0,ClipsDescendants=false})
	local paintBox={Gui=plane,Factory=factory,Style=state.PaintStyle}
	state.Gui,state.PaintBox=plane,paintBox
	function state:DetachRetiredRoot(keptBoxes: any)
		local box=self.RootBox
		if not self.Alive or not box or keptBoxes[box]then return end
		-- The canvas belongs to the document, even when it is temporarily
		-- composed inside the root's opacity/filter group. Rescue it before
		-- structural disposal destroys that retired group's descendants.
		self.Publication=(self.Publication or 0)+1
		plane.Parent=root;plane.Position=UDim2.fromOffset(0,0)
		box.CanvasPaintBounds=nil;box.CanvasPaintGui=nil;box.CanvasViewport=nil;box.EnsureCanvasCompositor=nil
		self.RootBox,self.Geometry,self.PaintParent=nil,nil,nil;self.Dirty=true
	end
	function state:Promote()
		local box=self.RootBox
		if not self.Alive or not box or box.OpacityGroup then return end
		box.OpacityGroup=GroupOpacity.create(box.Gui.Parent,box.Style.Opacity or 1,factory)
		box.Gui.Parent=box.OpacityGroup.Content;box.TransformBaseX,box.TransformBaseY=nil,nil
		tree.HasOpacity=true;GroupOpacity.paint(box.OpacityGroup,box.Style)
		GroupOpacity.arrange(tree,nil,{[tree]=true,[box]=true})
	end
	function state:Refresh(paintStyles: any?,inlineStyles: any?): boolean
		if not self.Alive then return false end
		local nextPlan=CanvasBackground.plan(document,tree.NodeStyles)
		local old=self.Plan;local nextRoot=tree.NodeBoxes[nextPlan.Root];local nextOwner=tree.NodeBoxes[nextPlan.Owner]
		if self.InlineOwner~=nextPlan.Owner then
			for _,node in {self.InlineOwner or false,nextPlan.Owner or false}do if node then
				for style in inlineUsers[node]or{}do if inlineStyles then inlineStyles[style]=true end end
			end end
			if self.InlineOwner and inlineOwners[self.InlineOwner]==self then inlineOwners[self.InlineOwner]=nil end
			self.InlineOwner=nextPlan.Owner
			if nextPlan.Owner then inlineOwners[nextPlan.Owner]=self end
		end
		local paintParent=if nextRoot and nextRoot.OpacityGroup then nextRoot.OpacityGroup.Content else root
		local changed=not old or old.Root~=nextPlan.Root or old.Owner~=nextPlan.Owner or old.Source~=nextPlan.Source
			or old.Paint~=nextPlan.Paint or old.Dark~=nextPlan.Dark or self.RootBox~=nextRoot or self.PaintParent~=paintParent
		for _,box in {self.RootBox or false,self.OwnerBox or false}do
			if box and box~=nextRoot and box~=nextOwner then box.CanvasBackgroundSuppressed=nil;box.CanvasPaintBounds=nil;box.CanvasPaintGui=nil;box.CanvasViewport=nil;box.EnsureCanvasCompositor=nil;if paintStyles then paintStyles[box.Style]=true end end
		end
		for _,box in {nextRoot or false,nextOwner or false}do if box then
			if not box.CanvasBackgroundSuppressed then changed=true;if paintStyles then paintStyles[box.Style]=true end end
			box.CanvasBackgroundSuppressed=true
		end end
		local used=self.PaintStyle;local nextStyle=table.clone(nextPlan.RootStyle or{})
		for _,key in fields do nextStyle[key]=(nextPlan.Style or{})[key]end
		-- Gradient currentColor remains a used color on the root positioning box;
		-- background-color has already resolved on its original computed owner.
		nextStyle.Visibility='visible';nextStyle.BorderRadius=0;nextStyle.BorderRadii=nil;nextStyle.CornerShape='round'
		if not nextPlan.Paint then nextStyle.Background=nil;nextStyle.BackgroundAlpha=1;nextStyle.BackgroundImages=emptyImages end
		for _,key in paintFields do if used[key]~=nextStyle[key]then changed=true end end
		table.clear(used);for key,value in nextStyle do used[key]=value end
		self.Plan,self.RootBox,self.OwnerBox,self.PaintParent=nextPlan,nextRoot,nextOwner,paintParent
		if nextRoot then nextRoot.CanvasPaintGui=plane;nextRoot.CanvasViewport=root;nextRoot.EnsureCanvasCompositor=self.EnsureCompositor end
		if changed then self.Dirty=true end;return changed
	end
	function state:Publish(width: number?,height: number?)
		if not self.Alive then return end
		if width and height and(width~=self.Width or height~=self.Height)then self.Width,self.Height=width,height;self.Dirty=true end
		local current=self.RootBox
		local geometry=if current then {current.LayoutX or 0,current.LayoutY or 0,current.OuterWidth or 0,current.OuterHeight or 0}else{}
		if current then
			local bt,br,bb,bl=BorderGeometry.sizes(current.Style)
			for _,value in {bt,br,bb,bl,unpack(current.Style.Padding or{0,0,0,0})}do table.insert(geometry,value)end
		end
		if self.Geometry then for index,value in geometry do if self.Geometry[index]~=value then self.Dirty=true;break end end else self.Dirty=true end
		self.Geometry=geometry
		if not self.Dirty or not self.Width or not self.Height then return end;self.Dirty=false
		self.Publication=(self.Publication or 0)+1;local publication=self.Publication;local plan=self.Plan
		root.BackgroundColor3=if self.Plan.Dark then Color3.fromRGB(18,18,18)else original.Color
		root.BackgroundTransparency=if self.Plan.Dark then 0 else original.Transparency
		local box=self.RootBox
		if box then
			plane.Parent=if box.OpacityGroup then box.OpacityGroup.Content else root
			local x,y=box.LayoutX or 0,box.LayoutY or 0;local w,h=math.max(1,self.Width),math.max(1,self.Height)
			plane.Position=UDim2.fromOffset(if box.OpacityGroup then -x else 0,if box.OpacityGroup then -y else 0);plane.Size=UDim2.fromOffset(w,h)
			paintBox.OuterWidth,paintBox.OuterHeight=w,h
			paintBox.CanvasPaintingArea={X=0,Y=0,W=w,H=h,Inset=0}
			paintBox.RootPositioningArea={X=x,Y=y,W=box.OuterWidth or 0,H=box.OuterHeight or 0}
			box.CanvasPaintBounds=if self.Plan.Paint then {-x,-y,w-x,h-y}else nil
			plane.Visible=self.Plan.Paint==true
			renderer:Draw(paintBox,w,h)
			if not self.Alive or self.Publication~=publication or self.Plan~=plan or self.RootBox~=box then return end
			if tree.HasOpacity then GroupOpacity.arrange(tree,nil,{[tree]=true,[box]=true})end
			BoxTransform.apply(box,nil,false)
		else plane.Parent=root;plane.Visible=false end
		if root.SetAttribute then root:SetAttribute('CanvasBackgroundSource',self.Plan.Source)end
	end
	function state:Destroy()
		if not self.Alive then return end;self.Alive=false
		if self.InlineOwner and inlineOwners[self.InlineOwner]==self then inlineOwners[self.InlineOwner]=nil end;self.InlineOwner=nil
		if renderer.Remove then renderer:Remove(paintBox)end;plane:Destroy()
		for _,box in {self.RootBox or false,self.OwnerBox or false}do if box then box.CanvasBackgroundSuppressed=nil;box.CanvasPaintBounds=nil;box.CanvasUsedBackgroundStyle=nil;box.CanvasPaintGui=nil;box.CanvasViewport=nil;box.EnsureCanvasCompositor=nil end end
		self.Plan,self.RootBox,self.OwnerBox,self.Gui,self.PaintBox,self.Geometry,self.PaintParent=nil,nil,nil,nil,nil,nil,nil;table.clear(self.PaintStyle)
	end
	state.EnsureCompositor=function()state:Promote()end
	state:Refresh();return state
end
function CanvasBackground.apply(root: any,document: any,nodeStyles: any?,state: any?)
	if nodeStyles==nil then return end;if state then state:Refresh();state:Publish();return end
	local color,alpha,source=CanvasBackground.resolve(document,nodeStyles);local original=originalSurfaces[root]
	if color==nil then
		if original then root.BackgroundColor3=original.Color;root.BackgroundTransparency=original.Transparency;originalSurfaces[root]=nil end
		if root.SetAttribute then root:SetAttribute('CanvasBackgroundSource',nil)end;return
	end
	if not original then originalSurfaces[root]={Color=root.BackgroundColor3,Transparency=root.BackgroundTransparency}end
	root.BackgroundColor3=color;root.BackgroundTransparency=1-(alpha or 1)
	if root.SetAttribute then root:SetAttribute('CanvasBackgroundSource',source)end
end
return CanvasBackground
