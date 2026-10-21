--!strict
-- Pixel geometry captured from the same authored HTML in the native browser.
return function(Parser,Node,loadRenderTree,loadWordLayout,loadBlockLayout,Dialog,Popover,ViewportLayer,cases,references)
	local factory={}
	function factory.create(class,parent,props)
		local gui={ClassName=class,Parent=parent,Visible=true,ZIndex=1,Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(0,0)}
		for key,value in props do gui[key]=value end
		if class=="ScrollingFrame"then gui.CanvasPosition=gui.CanvasPosition or Vector2.new(0,0)end
		function gui:IsA(kind)return kind==self.ClassName or kind=="GuiObject"end
		function gui:SetAttribute(key,value)self[key]=value end
		function gui:GetAttribute(key)return self[key]end
		function gui:Destroy()self.Parent=nil;self.Destroyed=true end
		return gui
	end
	factory.modifier=factory.create
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*8,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local renderer=loadRenderTree(factory);local layout=loadBlockLayout(overrides)
	local byName={};for _,case in cases do byName[case.name]=case end
	local function offset(position,axis,index)
		return if position[axis]then position[axis].Offset else position[index]
	end
	local function nativePosition(gui)
		local x,y=0,0
		while gui do
			x+=offset(gui.Position,"X",1);y+=offset(gui.Position,"Y",2)
			if gui.AnchorPoint then x-=gui.AnchorPoint.X*offset(gui.Size,"X",1);y-=gui.AnchorPoint.Y*offset(gui.Size,"Y",2)end
			gui=gui.Parent
			if gui and gui.ClassName=="ScrollingFrame"then x-=gui.CanvasPosition.X;y-=gui.CanvasPosition.Y end
		end
		return x,y
	end
	local function near(a,b,label)assert(math.abs(a-b)<.025,label..": "..tostring(a).." != "..tostring(b))end
	for _,reference in references do
		local case=byName[reference.name]
		local base=case.base or 'width:120px;height:80px;padding:0;border:0;background:#ed963b;box-sizing:border-box'
		local html='<!doctype html><html><head><style>html,body{margin:0;padding:0}body{height:1800px}#target{'..base..'}</style></head><body><div id="host" style="'..(case.host or '')..'"><'..case.tag..' id="target" '..(if case.popover then 'popover="'..case.popover..'"'else '')..' style="'..(case.style or '')..'"></'..case.tag..'></div></body></html>'
		local document=Parser.parseDocument(html)
		local viewport=factory.create("Frame",nil,{AbsolutePosition=Vector2.new(0,0)})
		local width=reference.viewportWidth
		local root=factory.create("ScrollingFrame",viewport,{AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(reference.width,reference.height),AbsoluteWindowSize=Vector2.new(width,reference.viewportHeight),CanvasPosition=Vector2.new(0,0)})
		local tree=renderer.build(document,root,error,function(font)return font end)
		Dialog.attachViewport(tree,root);Popover.attachViewport(tree,root)
		tree:SetMediaEnvironment(reference.width,reference.height);tree.ViewportHeight=reference.viewportHeight
		local node=Node.findById(document,"target");local box=tree.NodeBoxes[node]
		if case.action=="show"or case.action=="showModal"then Dialog.open(tree,node,case.action=="showModal")
		elseif case.action=="showPopover"then Popover.show(tree,node)end
		layout.arrange(tree,width,0,0,function()return true end)
		Dialog.arrange(tree,root);Popover.arrange(tree,root);ViewportLayer.attach(tree,root,factory);ViewportLayer.update(tree,root)
		root.CanvasPosition=Vector2.new(0,reference.scroll);ViewportLayer.update(tree,root)
		local x,y=nativePosition(box.Gui)
		local label=reference.name.." ["..reference.width..", scroll="..reference.scroll.."]"
		near(x,reference.rect.x,label.." x");near(y,reference.rect.y,label.." y")
		near(box.OuterWidth,reference.rect.width,label.." width");near(box.OuterHeight,reference.rect.height,label.." height")
		assert(box.Style.Position==reference.position,label.." position: "..box.Style.Position.." != "..reference.position)
		assert(box.Style.OverflowX==reference.overflow and box.Style.OverflowY==reference.overflow,label.." overflow")
		for side,value in reference.padding do near(box.Style.Padding[side],value,label.." padding "..side) end
		if case.action=="showModal"then
			assert(box.Gui.Parent==tree.DialogHost.Layer and box.Gui.ZIndex>tree.DialogHost.Backdrop.ZIndex,label.." modal paints above its backdrop")
		elseif case.action=="show"then assert(not box.TopLayerActive,label.." nonmodal stays in ordinary CSS stacking")end
		Dialog.destroyHost(tree);Popover.destroyHost(tree);ViewportLayer.destroy(tree)
	end
	print('Top-layer positioning: '..#references..' native-browser pixel references, author CSS, ancestor containing blocks, scrollbars, scroll, static/fixed/absolute and short viewports passed')
end
