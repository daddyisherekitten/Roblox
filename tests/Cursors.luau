--!strict
return function(Parser,CSS,Icons,Lease,CursorController,InputController,HitTest,loadRenderTree,PaintLayer)
	for name in CSS.Keywords do assert(CSS.parse(name) == name) end
	assert(Icons.pointerIcon == Icons.pointer and Icons.textCursorIcon == Icons.text and Icons.defaultCursorIcon == Icons.default)
	assert(Icons.grab == Icons.pointer,'The unavailable grab artwork uses the established pointer asset')
	assert(Icons['se-resize'] == Icons['nwse-resize'])
	assert(CSS.parse('url') == nil and CSS.parse('pointerIcon') == nil and CSS.parse('wait') == nil)
	assert(CSS.parse('url("x")') == nil and CSS.parse('url("x") 2 3, pointer') == nil and CSS.parse('pointer,') == nil)
	assert(CSS.resolve(CSS.parse('url("missing"), url("url"), pointer'),'default') == Icons.url)
	assert(CSS.resolve(CSS.parse('url("rbxassetid://119334102167665"), default'),'text') == Icons.url)
	assert(CSS.resolve(CSS.parse('url("https://invalid.example/x.png"), text'),'default') == 'text')
	local function signal()
		local entries={}; local s={}
		function s:Connect(fn)
			local c={Connected=true}; function c:Disconnect() self.Connected=false end
			table.insert(entries,{fn,c}); return c
		end
		function s:Fire(...) for _,e in table.clone(entries) do if e[2].Connected then e[1](...) end end end
		function s:Count() local n=0; for _,e in entries do if e[2].Connected then n+=1 end end; return n end
		return s
	end
	local function gui(class,parent,props)
		local g=table.clone(props or {}); g.Parent=parent; g.Visible=true; g.Enabled=true
		g.AbsolutePosition=Vector2.new(0,0); g.AbsoluteSize=Vector2.new(100,100)
		function g:IsA(name) return name == class or name == 'GuiObject' end
		local attributes,signals={},{}
		function g:GetAttribute(name) return attributes[name] end
		function g:GetPropertyChangedSignal(name) signals[name]=signals[name] or signal(); return signals[name] end
		function g:GetAttributeChangedSignal(name) return self:GetPropertyChangedSignal(name) end
		function g:SetAttribute(name,value) attributes[name]=value; self:GetAttributeChangedSignal(name):Fire() end
		return g
	end
	local factory={create=gui,modifier=function(_,_,props) return table.clone(props) end}
	local root=gui('ScrollingFrame',nil,{ScrollingEnabled=true})
	local document=Parser.parse('<div style="cursor:help"><span id="inherited">Help</span><span id="reset" style="cursor:initial">Text</span></div><div id="hide" style="cursor:none">Hidden cursor</div><span id="plain">Plain</span><span id="noselect" style="user-select:none">No selection</span><div id="touchstop" style="touch-action:none">No touch pan</div><a id="link" href="#">Link</a><label id="label" style="cursor:help"><span style="cursor:copy">Copy</span></label>')
	local tree=loadRenderTree(factory).build(document,root,function(message) assert(message == 'Tag-specific inline formatting not yet supported: a',message) end,function(font) return font end)
	local targets={}
	for g,node in tree.HitNodes do
		if node.Attributes and node.Attributes.id and g:IsA('TextLabel') then targets[node.Attributes.id]=g end
	end
	local hits={}; local location=Vector2.new(20,20)
	local input={MouseEnabled=true,MouseIcon='original',MouseIconEnabled=true,
		InputChanged=signal(),InputBegan=signal(),InputEnded=signal(),WindowFocusReleased=signal(),WindowFocused=signal()}
	function input:GetMouseLocation() return location end
	local playerGui={GetGuiObjectsAtPosition=function() return hits end}
	local cleanups={}
	local page={Alive=true,Root=root,Document=document}
	function page:AddCleanup(fn) table.insert(cleanups,fn) end
	local cssStates={}
	function tree:SetCSSState(name,node) cssStates[name]=node; return false end
	local stop=InputController.start(page,tree,function() error('Cursor must not request layout') end,error,{Input=input,PlayerGui=playerGui})
	assert(stop and #tree.Controls == 0,'Cursor input starts on pages without controls')
	local function move(target,x,y)
		hits=if target then {target} else {}; location=Vector2.new(x or 20,y or 20)
		input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=location})
	end
	move(targets.inherited); assert(input.MouseIcon == Icons.help)
	move(targets.reset); assert(input.MouseIcon == Icons.text,'Initial auto chooses text over a text run')
	move(targets.link); assert(input.MouseIcon == Icons.pointer)
	move(targets.plain); assert(input.MouseIcon == Icons.text and cssStates.hover.Attributes.id=='plain','Hover reaches HTML CSS state without requesting layout when no rule changes')
	move(targets.noselect);assert(input.MouseIcon==Icons.default,'user-select:none keeps the normal cursor over text labels')
	move(targets.touchstop);local touchStop={UserInputType=Enum.UserInputType.Touch,Position=location};input.InputBegan:Fire(touchStop,false)
	assert(not root.ScrollingEnabled,'touch-action:none suspends native ancestor panning for the active touch')
	input.InputEnded:Fire(touchStop,false);assert(root.ScrollingEnabled,'touch scrolling is restored when the gesture ends')
	move(targets.plain)
	local overlay=PaintLayer.create(factory,'ImageLabel',root,{Name='RoundedBorder'})
	hits={overlay,targets.link}
	input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=location})
	assert(input.MouseIcon==Icons.pointer,'Transparent border images must leave links reachable')
	local navigationCount=0
	page.Navigate=function()navigationCount+=1 end
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position=location},false)
	input.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position=location})
	assert(navigationCount==1,'A link under a decorative overlay must activate once')
	hits={overlay,targets.plain}
	input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=location})
	assert(input.MouseIcon==Icons.text,'Transparent border images must preserve text cursors')
	move(targets.plain)
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position=location},false)
	assert(cssStates.active and cssStates.active.Attributes.id=='plain',':active receives the raw HTML hit target')
	input.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position=location})
	assert(cssStates.active==nil,':active clears on pointer release')
	move(targets.label); assert(input.MouseIcon == Icons.copy,'A label hit target preserves its nested visual cursor style')
	move(targets.hide); assert(not input.MouseIconEnabled and input.MouseIcon == Icons.none)
	move(nil); assert(input.MouseIconEnabled and input.MouseIcon == 'original')
	local cursorSurface=gui('Frame',root,{})
	cursorSurface:SetAttribute('HTMLInputBlocker',true);cursorSurface:SetAttribute('HTMLCursorSurface',true)
	move(cursorSurface);assert(input.MouseIconEnabled and input.MouseIcon==Icons.default,'HTML modal surfaces retain the engine default cursor')
	move(targets.inherited); root.Visible=false; root:GetPropertyChangedSignal('Visible'):Fire()
	assert(input.MouseIcon == 'original','Hiding the page releases its cursor without mouse movement')
	root.Visible=true; root:GetPropertyChangedSignal('Visible'):Fire(); assert(input.MouseIcon == Icons.help)
	move(targets.inherited); hits={targets.link}; root:SetAttribute('Status','ready')
	assert(input.MouseIcon == Icons.pointer,'Completed layout refreshes a stationary pointer')
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.Touch})
	assert(input.MouseIcon == 'original')
	root:GetPropertyChangedSignal('CanvasPosition'):Fire(); assert(input.MouseIcon == 'original')
	move(targets.inherited); input.WindowFocusReleased:Fire(); assert(input.MouseIcon == 'original')
	input.WindowFocused:Fire(); assert(input.MouseIcon == Icons.help)
	local high=Lease.new(input,100)
	high:Set('grab');assert(input.MouseIcon==Icons.pointer,'Grab resolves to the usable pointer fallback through the real cursor lease')
	high:Set('nesw-resize'); move(targets.link); assert(input.MouseIcon == Icons['nesw-resize'])
	high:Destroy(); assert(input.MouseIcon == Icons.pointer,'Releasing a resize lease reveals the page cursor')
	input.MouseIcon='external'; move(nil); assert(input.MouseIcon == 'external','Another script cursor must not be overwritten on release')
	stop(); stop()
	assert(input.InputChanged:Count() == 0 and input.WindowFocusReleased:Count() == 0)
	assert(root:GetAttributeChangedSignal('Status'):Count() == 0)
	local blocker=gui('Frame',nil,{})
	blocker:SetAttribute('HTMLInputBlocker',true)
	assert(HitTest.pick({blocker,targets.link},tree.HitNodes,root,location) == nil,'Passive resize grips block the page hit test')
	local passthrough=gui('Frame',root,{})
	passthrough:SetAttribute('HTMLHitTestPassthrough',true)
	location=Vector2.new(20,20)
	local underlying=gui('TextLabel',root,{})
	local underlyingNode={Name='a',Attributes={id='underlying'}}
	local passedNode=HitTest.pick({passthrough,underlying},{[underlying]=underlyingNode},root,location)
	assert(passedNode == underlyingNode,
		'Structural overlay empty space passes through to the page below: '..tostring(passedNode and passedNode.Attributes and passedNode.Attributes.id))
	local ancestorNode={Name='div',Attributes={id='ancestor'}}
	assert(HitTest.pick({passthrough,underlying},{[root]=ancestorNode,[underlying]=underlyingNode},root,location)==underlyingNode,
		'A structural shell remains transparent when its native ancestor has a DOM registration')
	local Groups=require('Rendering/GroupOpacity')
	local group=Groups.create(root,.5,factory)
	local groupChild=gui('Frame',group.Content,{})
	local childNode={Name='button',Attributes={id='composited-button'}}
	local hitNodes={[root]=ancestorNode,[groupChild]=childNode,[underlying]=underlyingNode}
	for _,opacity in {0,.5,1,0,1}do
		Groups.paint(group,{Opacity=opacity})
		assert(HitTest.pick({group.Gui,group.Content,groupChild,underlying},hitNodes,root,location)==childNode,
			'Opacity shells never steal hits, including fully transparent DOM boxes')
	end
	assert(HitTest.pick({groupChild,group.Content,group.Gui,underlying},hitNodes,root,location,{[groupChild]={PointerEvents='none'}})==underlyingNode,
		'pointer-events:none passes through composited content and its anonymous shells')
	local interactive=gui('Frame',groupChild,{})
	local interactiveNode={Name='button',Attributes={id='explicit-auto'}};hitNodes[interactive]=interactiveNode
	assert(HitTest.pick({interactive,groupChild,group.Content,group.Gui,underlying},hitNodes,root,location,
		{[interactive]={PointerEvents='auto'},[groupChild]={PointerEvents='none'}})==interactiveNode,
		'A pointer-events:auto descendant remains interactive inside a composited pointer-events:none ancestor')
	local pointerOverlay=gui('Frame',root,{})
	local overlayNode={Name='span',Attributes={id='pointer-overlay'}}
	local pointerNode=HitTest.pick({pointerOverlay,underlying},{[pointerOverlay]=overlayNode,[underlying]=underlyingNode},root,location,{[pointerOverlay]={PointerEvents='none'}})
	assert(pointerNode==underlyingNode,'pointer-events:none exposes the underlying HTML target')
	local rounded=gui('Frame',root,{ClipsDescendants=true});rounded.AbsoluteSize=Vector2.new(100,60)
	local roundedNode={Name='div',Attributes={id='rounded'}}
	local roundedStyle={ResolvedBorderRadii={{40,20},{10,10},{30,15},{5,5}}}
	assert(HitTest.pick({rounded},{[rounded]=roundedNode},root,Vector2.new(1,1),{[rounded]=roundedStyle})==nil,'rounded overflow excludes hits outside its exact corner ellipse')
	assert(HitTest.pick({rounded},{[rounded]=roundedNode},root,Vector2.new(50,30),{[rounded]=roundedStyle})==roundedNode)
	for _,point in {Vector2.new(99,1),Vector2.new(99,59),Vector2.new(.1,59.9)}do
		assert(HitTest.pick({rounded},{[rounded]=roundedNode},root,point,{[rounded]=roundedStyle})==nil,'Each elliptical clipped corner rejects points outside the arc')
	end
	local node={Name='textarea',Attributes={}}
	local box=gui('Frame',root,{})
	local style={Resize='both',BorderSize=0,Cursor='crosshair'}
	local control={Node=node,Type='textarea',Item={Style=style,Editor={},BoxGui=box,BoxWidth=100,BoxHeight=100}}
	local controlled={Controls={control},HitNodes={[box]=node},NodeStyles={[node]=style},Children={}}
	local cursor=CursorController.start(page,controlled,input,playerGui)
	move(box); assert(input.MouseIcon == Icons.crosshair)
	move(box,95,95); assert(input.MouseIcon == Icons['nwse-resize'])
	cursor:Capture(control,{UserInputType=Enum.UserInputType.MouseButton1,Position=location})
	move(nil,500,500); assert(input.MouseIcon == Icons['nwse-resize'],'Resize cursor persists outside its starting field')
	cursor:Release(); assert(input.MouseIcon == 'external')
	style.Cursor='auto'; move(box); assert(input.MouseIcon == Icons.text)
	style.Resize='horizontal'; move(box,95,95); assert(input.MouseIcon == Icons['ew-resize'])
	style.Resize='vertical'; move(box,95,95); assert(input.MouseIcon == Icons['ns-resize'])
	cursor:Destroy(); assert(input.MouseIcon == 'external')
	for _,cleanup in cleanups do cleanup() end
	print('Cursors: asset aliases, CSS/inheritance/URL fallback, no-control pages, auto targets, none, resize capture, touch, focus, stationary refresh, ownership and cleanup passed')
end
