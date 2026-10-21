--!strict
-- Exercise the actual page worker and CSS motion runtime with a clock that
-- advances during layout. Infinite keyframes must not spin inside publication.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLAnimations,Node)
	local function signal()
		local callbacks={};local api={}
		function api:Connect(fn)local entry={Connected=true,Callback=fn};function entry:Disconnect()self.Connected=false end;table.insert(callbacks,entry);return entry end
		function api:Fire(...)for _,entry in table.clone(callbacks)do if entry.Connected then entry.Callback(...)end end end
		function api:Count()local count=0;for _,entry in callbacks do if entry.Connected then count+=1 end end;return count end
		return api
	end
	local function gui(class,parent,props)
		local value=table.clone(props or{});value.ClassName=class;value.Parent=parent
		value.AbsoluteSize=Vector2.new(400,300);value.AbsolutePosition=Vector2.new(0,0)
		value.AnchorPoint=value.AnchorPoint or Vector2.new(0,0);value.Position=value.Position or UDim2.fromOffset(0,0)
		value.BackgroundColor3=value.BackgroundColor3 or Color3.new(1,1,1);value.BackgroundTransparency=value.BackgroundTransparency or 1
		value.Destroying=signal();local attributes,properties,attributeSignals={},{},{}
		if class=='ScrollingFrame'then value.CanvasPosition=Vector2.new(0,0);value.ScrollBarThickness=10 end
		function value:GetPropertyChangedSignal(key)properties[key]=properties[key]or signal();return properties[key]end
		function value:GetAttributeChangedSignal(key)attributeSignals[key]=attributeSignals[key]or signal();return attributeSignals[key]end
		function value:GetAttribute(key)return attributes[key]end
		function value:SetAttribute(key,nextValue)local changed=attributes[key]~=nextValue;attributes[key]=nextValue;if changed and attributeSignals[key]then attributeSignals[key]:Fire()end end
		function value:IsA(kind)return kind==class or kind=='GuiObject'end
		function value:Destroy()assert(not self.Destroyed,'Native page surface destroyed twice');self.Destroyed=true;self.Destroying:Fire();self.Parent=nil end
		return value
	end
	local factory={create=gui,modifier=gui};local renderer=loadRenderTree(factory)
	local layoutOverrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*size*.45,Y=size}end}}
	layoutOverrides['Layout/WordLayout']=loadWordLayout(layoutOverrides);local block=loadBlockLayout(layoutOverrides)
	local time,queue,passes,passLimit=0,{},0,6
	local function clock()time+=.00001;return time end
	local function enqueue(delay,callback)local entry={Due=time+delay,Callback=callback};table.insert(queue,entry);return entry end
	local tasks={defer=function(callback)return enqueue(0,callback)end,delay=enqueue,cancel=function(entry)entry.Cancelled=true end,wait=function()error('This small layout should not require a work-budget yield')end}
	local tree,document,viewport;local frames=signal()
	local inputSignal,preferenceSignal=signal(),signal()
	local input={MouseEnabled=false,TouchEnabled=false,GetPropertyChangedSignal=function()return inputSignal end}
	local preferences={ReducedMotionEnabled=false,GetPropertyChangedSignal=function()return preferenceSignal end}
	local hostGame={GetService=function(_,name)return if name=='UserInputService'then input elseif name=='GuiService'then preferences else nil end}
	local notifications=0
	local pageModule=loadHTMLPage({
		['Rendering/GuiFactory']={create=function(class,parent,props)local object=gui(class,parent,props);if class=='ScrollingFrame'then viewport=object end;return object end},
		['Rendering/RenderTree']={build=function(doc,root,diagnostic,resolveFont)
			document=doc;tree=renderer.build(doc,root,diagnostic,function(font)return font end);return tree
		end},
		['Layout/BlockLayout']={arrange=function(...)
			passes+=1;assert(passes<=passLimit,'Animation resampling spun inside HTMLPage publication without another frame')
			return block.arrange(...)
		end},
		['Input/Controller']={start=function()end},
		['Rendering/HTMLScripts']={ShouldStart=function()return true end,hasScripts=function()return false end,start=function(owner)
			owner.JavaScriptRuntime={HasOwnBlockingStylesheets=function()return false end,
				SubscribeStylesheetChanges=function()return function()end end,
				HasPending=function()return false end,FontLayoutCompleted=function()end,
				Geometry={ViewportChanged=function()notifications+=1 end}}
		end},
		['Rendering/HTMLAnimations']=HTMLAnimations,
	},tasks,clock,hostGame)
	local host=gui('Frame',nil,{})
	local page=pageModule.mount(host,[=[<!doctype html><html><head><style>
		html,body{margin:0;padding:0}html{container-type:scroll-state}#box{width:100px;height:40px}
		.running{animation:grow 2s linear infinite alternate}
		@keyframes grow{from{width:100px}to{width:200px}}
		@media (hover:hover){#box{color:blue}}
		@media (prefers-reduced-motion:reduce){#after{height:80px}}
		@media (scripting:none){#box{background:green}}
		@container scroll-state(scrollable:top){#after{color:blue}}
	</style></head><body><div id="box">Animated</div><div id="after">Following content</div></body></html>]=],
		-- Loading work has separate scheduler tests. This fixture deliberately
		-- advances its clock on every read to probe animation resampling alone.
		{JavaScript=false,RenderWorkBudgetMS=0,AnimationServices={Clock=clock,RunService={RenderStepped=frames}}})
	local function drain()
		passLimit=passes+6;local rounds=0
		while #queue>0 do rounds+=1;assert(rounds<=10,'Page worker did not return to the host queue')
			local entry=table.remove(queue,1);if not entry.Cancelled then time=math.max(time,entry.Due);entry.Callback()end
		end
	end
	local function flush()
		drain()
		assert(viewport:GetAttribute('Status')=='ready'and not page:HasPendingLayout(),'Animation layout did not settle within its frame: '..tostring(viewport:GetAttribute('Error')))
	end
	flush();assert(passes==1 and frames:Count()==0,'An idle page must not subscribe to animation frames')
	local node=assert(Node.findById(document,'box'));local box=assert(tree.NodeBoxes[node]);local original=box.Gui
	local function styleChange(class)
		node.Attributes.class=class
		local needed,items=tree:ApplyDOMChanges({[node]={Style=true,Attributes={class=true}}})
		assert(needed);for item in items do page:RequestAnimationLayout(item)end;flush()
	end
	styleChange('running');assert(frames:Count()==1,'An active keyframe must use exactly one frame subscription')
	local first=box.OuterWidth;time+=.4;page:RequestAnimationLayout(box);flush()
	assert(box.OuterWidth==first,'An unrelated layout advanced the CSS animation before its next frame')
	local before=passes;frames:Fire();flush()
	assert(passes<=before+2 and box.OuterWidth>first and box.Gui==original,'One frame must settle locally and keep the native box')
	local sampled=box.OuterWidth;time+=.2;page:RequestAnimationLayout(box);flush()
	assert(box.OuterWidth==sampled,'A geometry refresh must repaint the same frame sample')
	for _=1,8 do time+=.1;local count=passes;frames:Fire();flush();assert(passes<=count+2,'Infinite keyframes caused repeated work within a frame')end
	local heldPasses,heldWidth,heldNotifications=passes,box.OuterWidth,notifications
	host:SetAttribute('HTMLViewportResizing',true)
	for step=1,8 do
		viewport.AbsoluteSize=Vector2.new(400+step*20,300+step*10)
		viewport:GetPropertyChangedSignal('AbsoluteSize'):Fire()
		time+=.1;frames:Fire();drain()
		assert(passes==heldPasses and box.OuterWidth==heldWidth and notifications==heldNotifications
			and box.Gui==original,'Real keyframes and resize requests cannot reflow/publish while the grip is held')
	end
	host:SetAttribute('HTMLViewportResizing',false);flush()
	assert(passes>heldPasses and passes<=heldPasses+2 and box.Gui==original and notifications>heldNotifications,
		'Release settles the latest sampled keyframe and viewport with retained native surfaces')
	styleChange('');assert(box.OuterWidth==100 and frames:Count()==0,'Removing keyframes restores the author width and disconnects frame work')
	assert(box.Gui==original and tree.NodeBoxes[Node.findById(document,'after')],'Animation publication recreated retained page contents')
	local beforePreferences,notified=passes,notifications
	input.MouseEnabled=true;inputSignal:Fire();flush()
	assert(passes==beforePreferences and box.Style.Color.B==1 and box.Gui==original,
		'An input capability color change must paint without entering BlockLayout')
	assert(notifications>notified,'A skipped layout still publishes changed media-query truth values')
	assert(box.Style.Background.G==128/255,'The page scripting query reflects JavaScript=false')
	preferences.ReducedMotionEnabled=true;preferenceSignal:Fire();flush()
	local afterBox=tree.NodeBoxes[Node.findById(document,'after')]
	assert(passes>beforePreferences and afterBox.Style.Height.Value==80 and afterBox.OuterHeight==80,
		'A preference that changes geometry must still perform real layout')
	beforePreferences=passes;preferenceSignal:Fire();flush()
	assert(passes==beforePreferences,'Unchanged preference truth values must retain layout')
	local beforeScroll=passes;local afterGUI=afterBox.Gui
	page.Root.AbsoluteCanvasSize=Vector2.new(400,900);page.Root.CanvasPosition=Vector2.new(0,100)
	page.Root:GetPropertyChangedSignal('CanvasPosition'):Fire();page.Root:GetPropertyChangedSignal('CanvasPosition'):Fire();flush()
	assert(passes==beforeScroll and afterBox.Style.Color.B==1 and afterBox.Gui==afterGUI and frames:Count()==0,
		'Root scroll queries coalesce events and repaint without layout, recreation or an idle frame subscription')
	page.Root.CanvasPosition=Vector2.new(0,0);page.Root:GetPropertyChangedSignal('CanvasPosition'):Fire();flush()
	assert(passes==beforeScroll and afterBox.Style.Color.B~=1,'Returning to the first scroll position restores query styles')
	page.Root.CanvasPosition=Vector2.new(0,100);page.Root:GetPropertyChangedSignal('CanvasPosition'):Fire()
	page:Destroy();assert(frames:Count()==0,'Page teardown retained an animation callback')
	for _,job in queue do if not job.Cancelled then job.Callback()end end
	assert(inputSignal:Count()==0 and preferenceSignal:Count()==0,'Page teardown retained media environment callbacks')
	print('HTMLPage scheduling: real worker/runtime, infinite keyframes, local convergence, media paint/layout separation, scripting mode, notifications and teardown passed')
end
