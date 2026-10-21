--!strict
return function(Parser,Node,loadRenderTree,loadWordLayout,loadBlockLayout,Animations,Timeline)
	local connections={};local factory={}
	function factory.create(class,parent,props)
		local gui=table.clone(props);gui.ClassName=class;gui.Parent=parent;gui.AnchorPoint=Vector2.new(0,0);gui.Position=gui.Position or UDim2.fromOffset(0,0);gui.BackgroundColor3=Color3.new(1,1,1)
		if class=='ScrollingFrame'then
			gui.CanvasPosition=Vector2.new(0,0);local signals={};gui.Signals=signals
			function gui:GetPropertyChangedSignal(key)
				if not signals[key]then
					local signal={Callbacks={}};signals[key]=signal
					function signal:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(self.Callbacks,{c,fn});table.insert(connections,c);return c end
					function signal:Fire()for _,entry in self.Callbacks do if entry[1].Connected then entry[2]()end end end
				end;return signals[key]
			end
		end;return gui
	end
	factory.modifier=factory.create
	local overrides={['Layout/FontProfiles']={face=function(v)return v end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*8,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local doc=Parser.parseDocument('<html><head><style>@keyframes move{from{transform:translateX(0)}to{transform:translateX(100px)}}#port{width:200px;height:100px;overflow:auto}#before{height:100px}#subject{height:20px;width:20px;animation:move 1s linear both;animation-timeline:view();animation-range:cover 0% cover 100%}#after{height:200px}</style></head><body><div id="port"><div id="before"></div><div id="subject"></div><div id="after"></div></div></body></html>')
	local tree=loadRenderTree(factory).build(doc,{},error);loadBlockLayout(overrides).arrange(tree,400,0,0,function()return true end)
	local subject=tree.NodeBoxes[Node.findById(doc,'subject')];local owner=tree.NodeBoxes[Node.findById(doc,'port')];local port=owner.ScrollGui
	port.AbsoluteWindowSize=Vector2.new(200,100);port.AbsoluteCanvasSize=Vector2.new(200,320);port.AbsoluteSize=port.AbsoluteWindowSize
	local cleanup;local frameConnections=0;local runtime=Animations.start({Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)cleanup=fn end},tree,error,{Clock=function()return 0 end,RunService={Heartbeat={Connect=function()frameConnections+=1;error('Idle scroll animation subscribed to frames')end}}})
	runtime:AfterLayout();assert(frameConnections==0 and runtime.Animations[1].ViewSubject==subject)
	local base=subject.TransformPositionX or 0;port.CanvasPosition=Vector2.new(0,60);port.Signals.CanvasPosition:Fire()
	assert(math.abs(subject.TransformPositionX-base-50)<.001,'View timeline cover midpoint uses subject geometry rather than total scroll extent')
	local frames=runtime.Frames;port.Signals.CanvasPosition:Fire();assert(runtime.Frames==frames+1,'Changed signal publishes one sample')
	assert(Timeline.parse('view(inline 10% 20%)')and Timeline.parse('scroll(root x)')and not Timeline.parse('scroll(root self)'))
	local a,b=Timeline.bounds('entry',100,20,100,0,0);assert(a==0 and b==20)
	a,b=Timeline.bounds('contain',100,20,100,0,0);assert(a==20 and b==100)
	cleanup();for _,c in connections do assert(not c.Connected,'Scroll signals released')end
	print('View timelines: real layout ranges, event-only sampling, no idle frame connection and disposal passed')
end
