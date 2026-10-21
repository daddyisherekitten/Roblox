--!strict
return function(Parser: any,loadRenderTree: any,loadWordLayout: any,loadBlockLayout: any,HTMLAnimations: any,ViewportLayer: any,effectsHTML: string,effectsCSS: string)
	local factory={}
	function factory.create(class: string,parent: any,props: any)local object=table.clone(props);object.ClassName=class;object.Parent=parent;object.AnchorPoint=object.AnchorPoint or Vector2.new(0,0);object.Position=object.Position or UDim2.fromOffset(0,0);object.BackgroundColor3=object.BackgroundColor3 or Color3.new(1,1,1);object.BackgroundTransparency=object.BackgroundTransparency or 1;return object end
	function factory.modifier(class: string,parent: any,props: any)local object=table.clone(props);object.ClassName=class;object.Parent=parent;return object end
	local renderer=loadRenderTree(factory)
	local words=loadWordLayout({["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=#text*8,Y=size} end}})
	local layout=loadBlockLayout({["Layout/WordLayout"]=words,["Layout/TextMeasure"]={measure=function(text,_,size)return {X=#text*8,Y=size} end}})
	local document=Parser.parse('<style>@keyframes demo{from{transform:translateX(0px) scale(1);opacity:.4;background-color:#000}to{transform:translateX(40px) scale(1.5);opacity:1;background-color:#fff}}#box{width:100px;height:40px;animation:demo 1s linear 1 forwards}</style><div id="box"></div>')
	local tree=renderer.build(document,{},error)
	layout.arrange(tree,400,0,0,function()return true end)
	local node=document.Children[2];local box=tree.NodeBoxes[node];assert(box and box.OpacityGroup)
	local clock=0;local callback
	local signal={Connect=function(_,fn)callback=fn;return {Disconnect=function()callback=nil end}end}
	local attributes={};local root={SetAttribute=function(_,key,value)attributes[key]=value end}
	local cleanups={};local page={Alive=true,Root=root,AddCleanup=function(_,fn)table.insert(cleanups,fn)end}
	local runtime=HTMLAnimations.start(page,tree,error,{RunService={Heartbeat=signal},Clock=function()return clock end},4)
	assert(runtime and not callback,"No frame listener is needed before layout installs motion");runtime:AfterLayout();assert(#runtime.Animations==1 and callback)
	clock=.5;callback()
	local target=box.OpacityGroup.Gui
	assert(target.Position[1]>69 and target.Position[1]<71)
	assert(box.TransformScale and box.TransformScale.Parent==target and math.abs(box.TransformScale.Scale-1.25)<.001,"scale transforms the outer opacity surface instead of being clipped inside it")
	assert(box.OpacityGroup.Gui.GroupTransparency>.29 and box.OpacityGroup.Gui.GroupTransparency<.31)
	clock=1;callback();assert(#runtime.Animations==0 and math.abs(target.Position[1]-90)<.001 and math.abs(box.TransformScale.Scale-1.5)<.001)
	cleanups[1]();assert(not runtime.Alive and callback==nil and attributes.CSSAnimationFrames==2)

	-- Delayed step easing must distinguish the fill phase from t=0 in the
	-- active interval. Exercise the real runtime, including its initial paint.
	local function stepFixture(css: string): any
		local doc=Parser.parse('<style>#step{display:block}'..css..'</style><button id="step">Step</button>')
		local stepTree=renderer.build(doc,{},error);layout.arrange(stepTree,300,0,0,function()return true end)
		local stepNode=doc.Children[2];local stepBox=stepTree.NodeBoxes[stepNode]
		local time=0;local onFrame;local cleanup
		local stepRuntime=HTMLAnimations.start({Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)cleanup=fn end},stepTree,error,
			{RunService={Heartbeat={Connect=function(_,fn)onFrame=fn;return {Disconnect=function()onFrame=nil end}end}},Clock=function()return time end},4)
		stepRuntime:AfterLayout()
		return {Tree=stepTree,Node=stepNode,Paint=stepBox.PaintBackgroundGui or stepBox.Gui,Runtime=stepRuntime,At=function(value)time=value;assert(onFrame);onFrame()end,Close=function()cleanup()end}
	end
	for _,timing in {"step-start","steps(1,start)","step-end","steps(1,end)"} do
		local jumpsAtStart=timing=="step-start" or timing=="steps(1,start)"
		local transition=stepFixture('#step{width:100px;height:30px;background:#000;transition:background-color 1s '..timing..' 1s}#step:hover{background:#fff}')
		assert(transition.Tree:SetCSSState("hover",transition.Node))
		transition.At(.5);assert(transition.Paint.BackgroundColor3.R==0,"Positive transition delay must retain its starting color: "..timing)
		transition.At(1);assert(transition.Paint.BackgroundColor3.R==(if jumpsAtStart then 1 else 0),"Step transition samples t=0 at the exact delay boundary")
		transition.At(1.5);assert(transition.Paint.BackgroundColor3.R==(if jumpsAtStart then 1 else 0))
		transition.At(2);assert(transition.Paint.BackgroundColor3.R==1);transition.Close()
		for _,direction in {"normal","reverse","alternate-reverse"} do
			local reverse=direction~="normal"
			local animation=stepFixture('@keyframes jump{from{background-color:#000}to{background-color:#fff}}#step{width:100px;height:30px;background:red;animation:jump 1s '..timing..' 1s 1 '..direction..' both}')
			local function expect(value: number,message: string)
				local color=animation.Paint.BackgroundColor3
				assert(color.R==value and color.G==value and color.B==value,message..": "..timing.." / "..direction)
			end
			expect(if reverse then 1 else 0,"Backwards fill paints immediately at initial layout")
			animation.At(.5);expect(if reverse then 1 else 0,"Backwards fill holds the directed starting endpoint during delay")
			animation.At(1);expect(if reverse or jumpsAtStart then 1 else 0,"Animation enters the active interval at the exact delay boundary")
			animation.At(1.5);expect(if jumpsAtStart then 1 else 0,"Step animation holds its active interval value")
			animation.At(2);expect(if reverse then 0 else 1,"A reverse final iteration uses the lower side of the final step")
			animation.Close()
		end
	end
	local pausedStep=stepFixture('@keyframes jump{from{background-color:#000}to{background-color:#fff}}#step{background:red;animation:jump 1s step-start 1s both paused}')
	assert(pausedStep.Paint.BackgroundColor3==Color3.new(0,0,0),"Paused backwards fill also paints before the positive delay")
	pausedStep.Close()

	-- When a costly paint consumes the entire frame budget, later animations
	-- must still advance on subsequent frames without hover/layout assistance.
	local crowdedDocument=Parser.parse('<style>@keyframes steps{from{transform:translateX(0)}to{transform:translateX(180px)}}.moving{display:inline-block;width:70px;height:30px;animation:steps 3s steps(6,end) infinite alternate}button{display:block;transition:transform 1s linear}button:hover{transform:translateX(40px)}</style><span class="moving">steps(6)</span><span class="moving">A</span><span class="moving">B</span><span class="moving">C</span><button>Hover</button>')
	local crowdedTree=renderer.build(crowdedDocument,{},error);layout.arrange(crowdedTree,400,0,0,function()return true end)
	local busyTime=0;local busyTick;local busyCleanup
	local busyRuntime=HTMLAnimations.start({Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)busyCleanup=fn end},crowdedTree,error,
		{RunService={Heartbeat={Connect=function(_,fn)busyTick=fn;return {Disconnect=function()busyTick=nil end}end}},Clock=function()busyTime+=.005;return busyTime end},4)
	busyRuntime:AfterLayout();assert(#busyRuntime.Animations==4 and busyTick)
	busyTime=1.1
	for _=1,4 do busyTick() end
	for _,item in busyRuntime.Animations do
		assert(item.LastProgress~=nil,"A frame-budget overrun must not permanently starve another animation")
		assert(item.Box.TransformPositionX>item.Box.TransformBaseX,"steps(6) advances autonomously without style changes")
	end
	local busyButton,busyNode
	for node,box in crowdedTree.NodeBoxes do if node.Name=="button" then busyButton,busyNode=box,node end end
	local buttonStart=busyButton.Gui.Position[1]
	assert(crowdedTree:SetCSSState("hover",busyNode))
	busyTime+=.3
	for _=1,5 do busyTick() end
	assert(busyButton.Gui.Position[1]>buttonStart,"Transitions must also get serviced while animations exhaust the frame budget")
	busyCleanup()

	local scrollDocument=Parser.parse('<style>@keyframes scrollmove{from{transform:translateX(0px)}to{transform:translateX(100px)}}#scroller{width:200px;height:100px;overflow-y:auto;scroll-timeline-name:--demo;scroll-timeline-axis:block}#space{height:300px}#scrollBox{width:20px;height:20px;animation:scrollmove 1s linear both;animation-timeline:--demo}</style><div id="scroller"><div id="space"><div id="scrollBox"></div></div></div>')
	local scrollTree=renderer.build(scrollDocument,{},error);layout.arrange(scrollTree,400,0,0,function()return true end)
	local ids={};for node,item in scrollTree.NodeBoxes do if node.Attributes and node.Attributes.id then ids[node.Attributes.id]=item end end
	local scrollGui=ids.scroller.ScrollGui;scrollGui.AbsoluteSize=Vector2.new(200,100);scrollGui.AbsoluteCanvasSize=Vector2.new(200,300);scrollGui.CanvasPosition=Vector2.new(0,0)
	local scrollClock=0;local scrollCallback
	local scrollSignal={Connect=function(_,fn)scrollCallback=fn;return {Disconnect=function()scrollCallback=nil end}end}
	local scrollCleanups={};local scrollPage={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(scrollCleanups,fn)end}
	local scrollRuntime=HTMLAnimations.start(scrollPage,scrollTree,error,{RunService={Heartbeat=scrollSignal},Clock=function()return scrollClock end},4)
	assert(scrollRuntime,"scroll keyframes must start a runtime")
	scrollRuntime:AfterLayout();assert(#scrollRuntime.Animations==1 and scrollCallback,"scroll animation must connect when layout installs it")
	assert(scrollRuntime.Animations[1].Scroll==scrollGui,"named timeline must resolve its scrolling ancestor")
	local scrollTarget=ids.scrollBox.Gui;scrollCallback();local startX=scrollTarget.Position[1]
	scrollGui.CanvasPosition=Vector2.new(0,100);scrollCallback();assert(math.abs(scrollTarget.Position[1]-startX-50)<.001,"named scroll timeline must map half of the scroll extent to half of the keyframes")
	scrollCleanups[1]();assert(not scrollRuntime.Alive and scrollCallback==nil)

 -- Match the effects-page Scroll Timeline marker: sticky and animated in the
 -- same nested scrollport. Check both event orders, independent of frame timing.
 local stickyDocument=Parser.parse('<style>@keyframes progress{from{transform:translateX(0);opacity:.35}to{transform:translateX(95px);opacity:1}}#scroller{width:240px;height:220px;overflow:auto;border:1px solid blue;scroll-timeline-name:--progress}#content{min-height:620px;padding:20px}#marker{position:sticky;top:14px;display:block;width:145px;padding:14px;animation:progress 1s linear both;animation-timeline:--progress}</style><div id="scroller"><div id="content"><span id="marker">Scrollfortschritt</span></div></div>')
 local stickyTree=renderer.build(stickyDocument,{},error);layout.arrange(stickyTree,400,0,0,function()return true end)
 local stickyIds={};for node,item in stickyTree.NodeBoxes do if node.Attributes and node.Attributes.id then stickyIds[node.Attributes.id]=item end end
 local marker,owner=stickyIds.marker,stickyIds.scroller
 local stickyScroll=owner.ScrollGui;stickyScroll.AbsoluteSize=Vector2.new(238,218);stickyScroll.AbsoluteWindowSize=stickyScroll.AbsoluteSize;stickyScroll.AbsoluteCanvasSize=Vector2.new(238,owner.ScrollBottom);stickyScroll.CanvasPosition=Vector2.new(0,100)
 stickyTree.Gui.AbsoluteSize=Vector2.new(400,600);stickyTree.Gui.AbsoluteWindowSize=stickyTree.Gui.AbsoluteSize;stickyTree.Gui.CanvasPosition=Vector2.new(0,0)
 ViewportLayer.update(stickyTree,stickyTree.Gui)
 local stickyCallback;local stickyCleanup
 local stickyPage={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)stickyCleanup=fn end}
 local stickyRuntime=HTMLAnimations.start(stickyPage,stickyTree,error,{RunService={Heartbeat={Connect=function(_,fn)stickyCallback=fn;return {Disconnect=function()stickyCallback=nil end} end}},Clock=function()return 0 end},4)
 stickyRuntime:AfterLayout();stickyCallback()
 local function pinned()
  local gui=if marker.OpacityGroup then marker.OpacityGroup.Gui else marker.Gui
  local bounds=marker.OpacityGroup and marker.OpacityBounds
  local left,top=if bounds then bounds[1] else 0,if bounds then bounds[2] else 0
  local width,height=if bounds then bounds[3]-left else marker.OuterWidth,if bounds then bounds[4]-top else marker.OuterHeight
  local x=gui.Position[1]-gui.AnchorPoint.X*width-left
  local y=gui.Position[2]-gui.AnchorPoint.Y*height-top
  local viewY=marker.StickyParentY+y-marker.StickyScrollY-1-stickyScroll.CanvasPosition.Y
  assert(math.abs(viewY-14)<.001,"The animated marker stays 14px below its own scrollport, including CanvasGroup opacity")
  local extent=stickyScroll.AbsoluteCanvasSize.Y-stickyScroll.AbsoluteWindowSize.Y
  local expectedX=marker.StickyNormalX+95*stickyScroll.CanvasPosition.Y/extent
  assert(math.abs(x-expectedX)<.001,"Sticky updates preserve horizontal scroll progress")
 end
 pinned()
 stickyScroll.CanvasPosition=Vector2.new(0,200);ViewportLayer.update(stickyTree,stickyTree.Gui,owner);stickyCallback();pinned()
 stickyScroll.CanvasPosition=Vector2.new(0,250);stickyCallback();ViewportLayer.update(stickyTree,stickyTree.Gui,owner);pinned()
 stickyCallback();pinned()
 stickyTree.Gui.CanvasPosition=Vector2.new(0,60);ViewportLayer.update(stickyTree,stickyTree.Gui,stickyTree);pinned()
 -- Rebuilding at a new viewport must not apply the scroll offset twice.
 layout.arrange(stickyTree,360,0,0,function()return true end);ViewportLayer.update(stickyTree,stickyTree.Gui);stickyRuntime:AfterLayout();stickyCallback();pinned()
 stickyCleanup()
 -- Fractional scroll changes and native coordinate rounding cannot accumulate
 -- into the retained transform anchor. Render sampling works without signals.
 local frameCallback;local frameCleanups={}
 local framePage={Alive=true,AddCleanup=function(_,fn)table.insert(frameCleanups,fn)end}
 local refresh=ViewportLayer.start(framePage,stickyTree,stickyTree.Gui,{RunService={PreRender={Connect=function(_,fn)frameCallback=fn;return {Disconnect=function()frameCallback=nil end}end}}})
 assert(refresh and frameCallback)
 for i=1,160 do
  stickyScroll.CanvasPosition=Vector2.new(0,100+(i%80)*.137)
  local gui=marker.OpacityGroup.Gui
  gui.Position=UDim2.fromOffset(math.floor(gui.Position[1]+.5),math.floor(gui.Position[2]+.5))
  frameCallback()
  local bounds=marker.OpacityBounds;local height=bounds[4]-bounds[2]
  local viewY=marker.StickyParentY+gui.Position[2]-gui.AnchorPoint.Y*height-bounds[2]-marker.StickyScrollY-1-stickyScroll.CanvasPosition.Y
  assert(math.abs(viewY-14)<.001,"Fractional scroll sampling must recover the absolute sticky position after native rounding")
 end
 frameCleanups[1]();assert(frameCallback==nil,"The sticky render listener is disposed with its page")

 -- Use the actual HTML/CSS fixture so the motion switch's default paused
 -- state cannot accidentally be omitted from the regression test.
 local effectsDocument=Parser.parse(effectsHTML)
 local effectsTree=renderer.build(effectsDocument,{},function()end,nil,nil,nil,nil,effectsCSS)
 layout.arrange(effectsTree,720,0,0,function()return true end)
 local fixtureMarker
 for n,b in effectsTree.NodeBoxes do if n.Attributes and (n.Attributes.class or ""):find("lab%-timeline%-marker") then fixtureMarker=b end end
 assert(fixtureMarker and fixtureMarker.Style.AnimationPlay[1]=="paused","The real fixture starts with scroll animation paused")
 local fixtureOwner=fixtureMarker.StickyScrollBox;local fixtureScroll=fixtureOwner.ScrollGui
 fixtureScroll.AbsoluteSize=Vector2.new(238,218);fixtureScroll.AbsoluteWindowSize=fixtureScroll.AbsoluteSize
 fixtureScroll.AbsoluteCanvasSize=Vector2.new(238,fixtureOwner.ScrollBottom);fixtureScroll.CanvasPosition=Vector2.new(0,0)
 effectsTree.Gui.AbsoluteSize=Vector2.new(720,600);effectsTree.Gui.AbsoluteWindowSize=effectsTree.Gui.AbsoluteSize;effectsTree.Gui.CanvasPosition=Vector2.zero
 ViewportLayer.update(effectsTree,effectsTree.Gui)
 local fixtureCleanups={};local fixtureTick
 local fixturePage={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(fixtureCleanups,fn)end}
 local fixtureRuntime=HTMLAnimations.start(fixturePage,effectsTree,function()end,{RunService={Heartbeat={Connect=function(_,fn)fixtureTick=fn;return {Disconnect=function()fixtureTick=nil end}end}},Clock=function()return 0 end},20)
 fixtureRuntime:AfterLayout();assert(fixtureTick==nil,"The real page's paused animations do not start a frame listener")
 local function fixturePosition(expectedProgress: number)
  local gui=fixtureMarker.OpacityGroup.Gui;local bounds=fixtureMarker.OpacityBounds
  local x=gui.Position[1]-gui.AnchorPoint.X*(bounds[3]-bounds[1])-bounds[1]
  local y=gui.Position[2]-gui.AnchorPoint.Y*(bounds[4]-bounds[2])-bounds[2]
  assert(math.abs(x-fixtureMarker.StickyNormalX-95*expectedProgress)<.001,"Paused scroll animations keep their held horizontal position")
  assert(math.abs(fixtureMarker.StickyParentY+y-fixtureMarker.StickyScrollY-1-fixtureScroll.CanvasPosition.Y-14)<.001,"The actual effects marker stays pinned while paused")
  assert(math.abs(gui.GroupTransparency-(1-(.35+.65*expectedProgress)))<.001,"Paused scroll animations retain their keyframe opacity")
 end
 fixtureScroll.CanvasPosition=Vector2.new(0,100);ViewportLayer.update(effectsTree,effectsTree.Gui,fixtureOwner);fixturePosition(0)
 layout.arrange(effectsTree,640,0,0,function()return true end);ViewportLayer.update(effectsTree,effectsTree.Gui);fixtureRuntime:AfterLayout();fixturePosition(0)
 fixtureMarker.Style.AnimationPlay={"running"};fixtureRuntime:AfterLayout();assert(fixtureTick);fixtureTick()
 local held=100/(fixtureScroll.AbsoluteCanvasSize.Y-fixtureScroll.AbsoluteWindowSize.Y)
 fixtureMarker.Style.AnimationPlay={"paused"};fixtureRuntime:AfterLayout();assert(fixtureTick==nil)
 fixtureScroll.CanvasPosition=Vector2.new(0,150);ViewportLayer.update(effectsTree,effectsTree.Gui,fixtureOwner);fixturePosition(held)
 layout.arrange(effectsTree,600,0,0,function()return true end);ViewportLayer.update(effectsTree,effectsTree.Gui);fixtureRuntime:AfterLayout();fixturePosition(held)
 fixtureCleanups[1]()

 -- Activate the switch in the real page fixture, then only dispatch frames.
 -- No hover, focus, relayout, or CSS refresh may be needed to animate steps(6).
 local enabledHTML=effectsHTML:gsub('id="run%-motion" type="checkbox"','id="run-motion" type="checkbox" checked',1)
 local enabledTree=renderer.build(Parser.parse(enabledHTML),{},function()end,nil,nil,nil,nil,effectsCSS)
 layout.arrange(enabledTree,720,0,0,function()return true end)
 for _,box in enabledTree.NodeBoxes do if box.ScrollGui then
  box.ScrollGui.AbsoluteSize=Vector2.new(box.OuterWidth,box.OuterHeight)
  box.ScrollGui.AbsoluteCanvasSize=Vector2.new(box.ScrollRight or box.OuterWidth,box.ScrollBottom or box.OuterHeight)
  box.ScrollGui.CanvasPosition=Vector2.new(0,0)
 end end
 local enabledClock=0;local enabledTick;local enabledCleanup
 local enabledRuntime=HTMLAnimations.start({Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)enabledCleanup=fn end},enabledTree,function()end,
  {RunService={Heartbeat={Connect=function(_,fn)enabledTick=fn;return {Disconnect=function()enabledTick=nil end}end}},Clock=function()enabledClock+=.005;return enabledClock end},4)
 enabledRuntime:AfterLayout();assert(enabledTick)
 local stepsItem
 for _,item in enabledRuntime.Animations do if item.Name=="lab-steps" then stepsItem=item end end
 assert(stepsItem and stepsItem.Play=="running","The real animation switch starts steps(6)")
 local stepsStart=stepsItem.Box.TransformPositionX
 enabledClock=1.1
 for _=1,#enabledRuntime.WorkQueue do enabledTick() end
 assert(stepsItem.LastProgress~=nil and stepsItem.Box.TransformPositionX>stepsStart,"Real steps(6) advances without hovering or focusing another control")
 enabledClock=3.1
 for _=1,#enabledRuntime.WorkQueue do enabledTick() end
 local outbound=stepsItem.Box.TransformPositionX
 enabledClock=4.1
 for _=1,#enabledRuntime.WorkQueue do enabledTick() end
 assert(stepsItem.Box.TransformPositionX<outbound,"Real steps(6) reverses direction on its alternate iteration")
 enabledCleanup();assert(enabledTick==nil and #enabledRuntime.WorkQueue==0)
	-- Reconstruct Roblox's visible point: Rotation always pivots at the GUI
	-- center, even when AnchorPoint is on the left edge of the path guide.
	local function visiblePoint(item: any,x: number,y: number): (number,number)
		local gui=item.Gui;local cx,cy=item.OuterWidth/2,item.OuterHeight/2
		local angle=math.rad(gui.Rotation or 0);local c,s=math.cos(angle),math.sin(angle)
		local scale=if item.TransformScale then item.TransformScale.Scale else 1
		return gui.Position[1]+scale*(cx-gui.AnchorPoint.X*item.OuterWidth+c*(x-cx)-s*(y-cy)),
			gui.Position[2]+scale*(cy-gui.AnchorPoint.Y*item.OuterHeight+s*(x-cx)+c*(y-cy))
	end
	local pathDocument=Parser.parse('<style>@keyframes travel{from{offset-distance:25px}to{offset-distance:calc(100% - 25px)}}#stage{position:relative;width:440px;height:110px;padding:32px;box-sizing:border-box}#guide{position:absolute;left:32px;top:31px;width:233.45235px;border-top:2px dashed blue;transform:rotate(9.865807deg);transform-origin:left center}#marker{position:relative;width:50px;height:50px;offset-path:path("M 0 0 L 230 40");offset-distance:25px;offset-rotate:auto;animation:travel 1s linear infinite alternate}</style><div id="stage"><div id="guide"></div><div id="marker"></div></div>')
	local pathTree=renderer.build(pathDocument,{},error);layout.arrange(pathTree,500,0,0,function()return true end)
	local pathIds={};for n,item in pathTree.NodeBoxes do if n.Attributes and n.Attributes.id then pathIds[n.Attributes.id]=item end end
	local pathClock=0;local pathCallback;local pathCleanups={}
	local pathPage={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(pathCleanups,fn)end}
	local pathSignal={Connect=function(_,fn)pathCallback=fn;return {Disconnect=function()pathCallback=nil end}end}
	local pathRuntime=HTMLAnimations.start(pathPage,pathTree,error,{RunService={Heartbeat=pathSignal},Clock=function()return pathClock end},4)
	pathRuntime:AfterLayout()
	for _,time in {0,.25,.5,.75,1,1.25,1.5,1.75,2,2.5,3,3.5,4} do
		pathClock=time;pathCallback()
		local cycle=time%2;local progress=if cycle<=1 then cycle else 2-cycle
		local pathLength=math.sqrt(230^2+40^2)
		local distance=(25+(pathLength-50)*progress)/pathLength
		local x,y=visiblePoint(pathIds.marker,25,25)
		assert(math.abs(x-(32+230*distance))<.001 and math.abs(y-(32+40*distance))<.001,"animated offset-distance must put the visible marker center on the CSS path at every frame: "..time.." "..x..","..y.." expected "..(32+230*distance)..","..(32+40*distance))
		local gx,gy=visiblePoint(pathIds.guide,0,1)
		assert(math.abs(gx-32)<.001 and math.abs(gy-32)<.001,"rotating the guide must leave its CSS left-center origin fixed")
		local ex,ey=visiblePoint(pathIds.guide,233.45235,1)
		local separation=math.abs((x-gx)*(ey-gy)-(y-gy)*(ex-gx))/233.45235
		assert(separation<.001,"visible marker must lie on the dashed guide throughout the animation")
		local rearX,rearY=visiblePoint(pathIds.marker,0,25)
		local frontX,frontY=visiblePoint(pathIds.marker,50,25)
		local rearDistance=((rearX-gx)*230+(rearY-gy)*40)/pathLength
		local frontDistance=((frontX-gx)*230+(frontY-gy)*40)/pathLength
		assert(rearDistance>=-.001 and frontDistance<=pathLength+.001,"marker edges must remain within the path endpoints")
		if progress==0 then assert(math.abs(rearDistance)<.001,"rear edge must reach the path start") end
		if progress==1 then assert(math.abs(frontDistance-pathLength)<.001,"front edge must reach the path end") end
		layout.arrange(pathTree,if time<1 then 501 else 500,0,0,function()return true end)
		pathRuntime:AfterLayout();pathCallback()
		local resizedX,resizedY=visiblePoint(pathIds.marker,25,25)
		assert(math.abs(resizedX-x)<.001 and math.abs(resizedY-y)<.001,"relayout during motion must not accumulate the previous animated position")
	end
	pathCleanups[1]()

	local curveSource='M 28 85 C 28 10 250 10 250 85 C 250 160 28 160 28 85 Z'
	local curveDocument=Parser.parse('<style>@keyframes curve{from{offset-distance:0%}to{offset-distance:100%}}#curveStage{position:relative;width:280px;height:170px}#curveMarker{position:absolute;left:0;top:0;width:28px;height:28px;display:grid;offset-path:path("'..curveSource..'");offset-distance:0%;offset-rotate:auto;animation:curve 5s linear infinite;animation-play-state:paused}#curveMarker:hover{animation-play-state:running}</style><div id="curveStage"><span id="curveMarker">o</span></div>')
	local curveTree=renderer.build(curveDocument,{},error);layout.arrange(curveTree,400,0,0,function()return true end)
	local curveNode,curveBox
	for n,item in curveTree.NodeBoxes do if n.Attributes and n.Attributes.id=="curveMarker" then curveNode,curveBox=n,item end end
	assert(curveBox.Style.OffsetPath.Kind=="path","Closed cubic paths must be parsed without lowercasing their absolute commands")
	local initialX,initialY=visiblePoint(curveBox,14,14)
	assert(math.abs(initialX-28)<.001 and math.abs(initialY-85)<.001,"The paused marker center starts at the left-middle path origin, not at the stage corner")
	local curveClock=0;local curveCallback;local curveCleanups={}
	local curvePage={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(curveCleanups,fn)end}
	local curveSignal={Connect=function(_,fn)curveCallback=fn;return {Disconnect=function()curveCallback=nil end}end}
	local curveRuntime=HTMLAnimations.start(curvePage,curveTree,error,{RunService={Heartbeat=curveSignal},Clock=function()return curveClock end},4)
	curveRuntime:AfterLayout();assert(not curveCallback,"A paused curve must not schedule animation work")
	curveClock=2;assert(curveTree:SetCSSState("hover",curveNode))
	layout.arrange(curveTree,400,0,0,function()return true end);curveRuntime:AfterLayout()
	assert(curveCallback,"Changing animation-play-state resumes the existing path animation")
	for _,sample in {{0,28,85},{.25,139,28.75},{.5,250,85},{.75,139,141.25},{1,28,85},{1.25,139,28.75}} do
		curveClock=2+sample[1]*5;curveCallback()
		local x,y=visiblePoint(curveBox,14,14)
		assert(math.abs(x-sample[2])<.15 and math.abs(y-sample[3])<.15,"offset-distance samples arc length around the curve, including the closed seam")
	end
	assert(curveTree:SetCSSState("hover",nil))
	layout.arrange(curveTree,400,0,0,function()return true end);curveRuntime:AfterLayout()
	assert(not curveCallback,"Pausing the curve disconnects its frame listener")
	curveClock+=1
	layout.arrange(curveTree,401,0,0,function()return true end);curveRuntime:AfterLayout()
	local heldX,heldY=visiblePoint(curveBox,14,14)
	assert(math.abs(heldX-139)<.15 and math.abs(heldY-28.75)<.15,"A resize preserves the paused position instead of resetting the marker to the path origin")
	assert(curveTree:SetCSSState("hover",curveNode))
	layout.arrange(curveTree,400,0,0,function()return true end);curveRuntime:AfterLayout();curveCallback()
	local resumedX,resumedY=visiblePoint(curveBox,14,14)
	assert(math.abs(resumedX-heldX)<.001 and math.abs(resumedY-heldY)<.001,"Resuming excludes the paused time and starts at the held curve position")
	curveCleanups[1]()
	curveBox.Style.OffsetDistance={Value=-25,Percent=true}
	layout.arrange(curveTree,401,0,0,function()return true end)
	local wrappedX,wrappedY=visiblePoint(curveBox,14,14)
	assert(math.abs(wrappedX-139)<.15 and math.abs(wrappedY-141.25)<.15,"Negative distances wrap around a closed path after resize")
	curveBox.Style.OffsetDistance={Value=125,Percent=true}
	layout.arrange(curveTree,400,0,0,function()return true end)
	local loopX,loopY=visiblePoint(curveBox,14,14)
	assert(math.abs(loopX-139)<.15 and math.abs(loopY-28.75)<.15,"Distances over 100% wrap without changing the path anchor")

	local combinedDocument=Parser.parse('<style>@keyframes combined{from{offset-distance:0%;transform:rotate(0deg)}to{offset-distance:100%;transform:rotate(18deg)}}#combined{position:relative;width:20px;height:20px;transform:translateX(10px);offset:path("M 0 45 L 100 45") 0% auto / center;animation:combined 1s linear infinite alternate;animation-composition:add}</style><div id="combined"></div>')
	local combinedTree=renderer.build(combinedDocument,{},error);layout.arrange(combinedTree,200,0,0,function()return true end)
	local combinedBox;for n,item in combinedTree.NodeBoxes do if n.Attributes and n.Attributes.id=="combined" then combinedBox=item end end
	local combinedClock=0;local combinedCallback;local combinedCleanups={}
	local combinedPage={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(combinedCleanups,fn)end}
	local combinedSignal={Connect=function(_,fn)combinedCallback=fn;return {Disconnect=function()combinedCallback=nil end}end}
	local combinedRuntime=HTMLAnimations.start(combinedPage,combinedTree,error,{RunService={Heartbeat=combinedSignal},Clock=function()return combinedClock end},4)
	combinedRuntime:AfterLayout();combinedClock=.5;combinedCallback()
	assert(combinedBox.Gui.Position[1]>50 and math.abs(combinedBox.Gui.Position[2]-45)<.001 and math.abs(combinedBox.Gui.Rotation-9)<.001,"composed transform and offset-distance must move and rotate without duplicating the path origin")
	combinedCleanups[1]()

	local transitionDocument=Parser.parse('<style>#fade{width:40px;height:20px;opacity:.4;background:#000;transform:translateX(0px);transition:transform 1s linear,opacity 1s linear,background-color 1s linear}#fade:hover{opacity:1;background:#fff;transform:translateX(40px)}</style><div id="fade"></div>')
	local transitionTree=renderer.build(transitionDocument,{},error);layout.arrange(transitionTree,200,0,0,function()return true end)
	local transitionNode,transitionBox
	for n,item in transitionTree.NodeBoxes do if n.Attributes and n.Attributes.id=="fade" then transitionNode,transitionBox=n,item end end
	local transitionClock=0;local transitionCallback;local transitionCleanups={}
	local transitionPage={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(transitionCleanups,fn)end}
	local transitionSignal={Connect=function(_,fn)transitionCallback=fn;return {Disconnect=function()transitionCallback=nil end}end}
	local transitionRuntime=HTMLAnimations.start(transitionPage,transitionTree,error,{RunService={Heartbeat=transitionSignal},Clock=function()return transitionClock end},4)
	transitionRuntime:AfterLayout();assert(not transitionCallback,"An idle transition-only page must not scan on every frame")
	local transitionGui=transitionBox.OpacityGroup.Gui;local baseX=transitionGui.Position[1]
	assert(transitionTree:SetCSSState("hover",transitionNode));layout.arrange(transitionTree,200,0,0,function()return true end);transitionRuntime:AfterLayout()
	assert(transitionCallback and transitionRuntime.Transitions[transitionBox].Target.X==baseX+40,"Transition targets retain immutable visual values, not a live GuiObject")
	transitionClock=.5;transitionCallback()
	assert(math.abs(transitionGui.Position[1]-baseX-20)<.001 and math.abs(transitionGui.GroupTransparency-.3)<.001,"Transform and opacity transitions interpolate the captured final state")
	assert(math.abs(transitionBox.Gui.BackgroundColor3.R-.5)<.001,"Color transitions use the painted box background even inside an opacity group")
	transitionClock=1;transitionCallback()
	assert(not transitionCallback and next(transitionRuntime.Transitions)==nil,"Completed transitions disconnect the idle frame listener")
	assert(transitionTree:SetCSSState("hover",nil));layout.arrange(transitionTree,200,0,0,function()return true end);transitionRuntime:AfterLayout()
	assert(transitionCallback,"A later state change resumes the transition listener")
	transitionClock=1.5;transitionCallback()
	assert(math.abs(transitionGui.Position[1]-baseX-20)<.001,"Reverse hover transitions start from the completed visual state")
	transitionCleanups[1]();assert(not transitionCallback and next(transitionRuntime.Pending)==nil and next(transitionRuntime.Snapshots)==nil)

	-- Sample a real paint-only hover: at half the elapsed time CSS ease has
	-- already reached 80.24%, then decelerates toward the exact endpoint.
	local easedTree=renderer.build(Parser.parse('<style>#eased{width:100px;height:40px;background:#000;opacity:.4;transition:transform 1s ease,opacity 1s ease,background-color 1s ease}#eased:hover{transform:translateY(-100px);opacity:1;background:#fff}</style><div id="eased"></div>'),{},error)
	layout.arrange(easedTree,200,0,0,function()return true end)
	local easedNode,easedBox
	for n,b in easedTree.NodeBoxes do if n.Attributes and n.Attributes.id=="eased" then easedNode,easedBox=n,b end end
	local easedClock,easedTick,easedCleanup=0,nil,nil
	local easedRuntime=HTMLAnimations.start({Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)easedCleanup=fn end},easedTree,error,
		{RunService={Heartbeat={Connect=function(_,fn)easedTick=fn;return {Disconnect=function()easedTick=nil end}end}},Clock=function()return easedClock end},4)
	easedRuntime:AfterLayout()
	local easedGui=easedBox.OpacityGroup.Gui;local easedX,easedY=easedGui.Position[1],easedGui.Position[2]
	local changed,reflow=easedTree:SetCSSState("hover",easedNode);assert(changed and not reflow and easedTick)
	easedClock=.5;easedTick()
	assert(easedGui.Position[1]==easedX and math.abs(easedGui.Position[2]-(easedY-80.2403387584857))<.00001,"Hover paint uses the actual CSS ease displacement")
	assert(math.abs(easedBox.Gui.BackgroundColor3.R-.802403387584857)<.000001 and math.abs(easedGui.GroupTransparency-.118557967449086)<.000001,"Color and opacity follow the same CSS easing curve")
	easedClock=.98;easedTick();local lateY=easedGui.Position[2]
	easedClock=.99;easedTick();assert(math.abs(easedGui.Position[2]-lateY)<.1,"The last part of the hover decelerates instead of moving linearly")
	easedClock=1;easedTick();assert(easedGui.Position[2]==easedY-100 and not easedTick,"The eased hover completes exactly and disconnects")
	easedCleanup()
	local retained=stepFixture('#step{width:100px;height:30px;background:#000;opacity:.4;transform:translateY(0px);transition:transform 2s linear,opacity 2s linear,background-color 2s linear}#step:hover{background:#fff;opacity:1;transform:translateY(-20px)}#step:focus-visible{color:green}')
	local retainedBox=retained.Tree.NodeBoxes[retained.Node]
	local changed,layoutNeeded=retained.Tree:SetCSSState('hover',retained.Node);assert(changed and not layoutNeeded)
	retained.At(.5);local running=retained.Runtime.Transitions[retainedBox];local preserved={}
	for _,property in {'transform','opacity','background-color'}do preserved[property]=running.Properties[property]end
	changed,layoutNeeded=retained.Tree:SetCSSState('focus-visible',retained.Node)
	assert(changed and not layoutNeeded,'Unrelated focus color remains paint-only')
	for _,property in {'transform','opacity','background-color'}do assert(retained.Runtime.Transitions[retainedBox].Properties[property]==preserved[property],'Unrelated style change restarted '..property)end
	retained.At(1);assert(math.abs(retained.Paint.BackgroundColor3.R-.5)<.000001 and math.abs(retainedBox.OpacityGroup.Gui.GroupTransparency-.3)<.000001,'Retained paint effects continue on their original clock')
	retained.Tree:SetCSSState('hover',nil);local reversePaint=retained.Runtime.Transitions[retainedBox]
	for _,property in {'transform','opacity','background-color'}do assert(reversePaint.Properties[property].Duration==1,'Interrupted paint reversal must shorten '..property)end
	retained.At(1.5);assert(math.abs(retained.Paint.BackgroundColor3.R-.25)<.000001,'Paint reversal starts from the current sample and uses the shortened duration')
	retained.Close()
	local alphaTransition=stepFixture('#step{width:100px;height:30px;background:rgba(255,0,0,0);transition:background-color 2s linear}#step:hover{background:rgba(0,0,255,1)}')
	alphaTransition.Tree:SetCSSState('hover',alphaTransition.Node);alphaTransition.At(1)
	assert(alphaTransition.Paint.BackgroundColor3.R==0 and alphaTransition.Paint.BackgroundColor3.B==1 and math.abs(alphaTransition.Paint.BackgroundTransparency-.5)<.000001,'CSS transition color interpolation is premultiplied; transparent red must not bleed into blue')
	alphaTransition.Close()
	local piecewise=stepFixture('@keyframes segmented{from{transform:translateX(0px);background:#000}to{transform:translateX(100px);background:#fff}}#step{width:100px;height:30px;animation:segmented 1s linear(0,.25 25% 75%,1) both}')
	local piecewiseBox=piecewise.Tree.NodeBoxes[piecewise.Node];local piecewiseStart=piecewiseBox.TransformPositionX
	piecewise.At(.5)
	assert(math.abs(piecewiseBox.TransformPositionX-piecewiseStart-25)<.000001 and math.abs(piecewise.Paint.BackgroundColor3.R-.25)<.000001,'Piecewise linear keyframes paint the same actual displacement and color as native easing: '..tostring(piecewiseBox.TransformPositionX-piecewiseStart)..' / '..tostring(piecewise.Paint.BackgroundColor3.R))
	piecewise.At(.75);assert(math.abs(piecewiseBox.TransformPositionX-piecewiseStart-25)<.000001,'The duplicated output stops create a visible hold without extra layout')
	piecewise.At(1);assert(math.abs(piecewiseBox.TransformPositionX-piecewiseStart-100)<.000001);piecewise.Close()
	local variablePaint=stepFixture('@keyframes custom{from{transform:var(--from);opacity:var(--low);background:var(--dark)}to{transform:var(--to);opacity:var(--high);background:var(--light)}}#step{--from:translateX(0px);--to:translateX(100px);--low:.2;--high:.8;--dark:#000;--light:#fff;width:100px;height:30px;animation:custom 1s linear both}')
	local variableBox=variablePaint.Tree.NodeBoxes[variablePaint.Node];local variableStart=variableBox.TransformPositionX
	variablePaint.At(.5)
	assert(math.abs(variableBox.TransformPositionX-variableStart-50)<.000001 and math.abs(variablePaint.Paint.BackgroundColor3.R-.5)<.000001
		and math.abs(variableBox.OpacityGroup.Gui.GroupTransparency-.5)<.000001,'Paint keyframes resolve custom-property values before interpolating actual transform, alpha and color')
	variablePaint.Close()
	local importantBackground=stepFixture('@keyframes backgroundImportant{from{background:#000}to{background:#fff}}#step{width:100px;height:30px;background:red!important;animation:backgroundImportant 1s linear both}')
	importantBackground.At(.5);assert(importantBackground.Paint.BackgroundColor3==Color3.fromRGB(255,0,0),'An important background shorthand blocks the color longhand supplied by keyframes');importantBackground.Close()
	local invisiblePaint=stepFixture('#step{width:100px;height:30px;background:transparent;transition:background-color .2s ease}#step:focus-visible{color:green}')
	invisiblePaint.Tree:SetCSSState('focus-visible',invisiblePaint.Node)
	assert(next(invisiblePaint.Runtime.Transitions)==nil,'Transparent author and sampled backgrounds cannot create invisible transitions on unrelated changes');invisiblePaint.Close()

	local hoverDocument=Parser.parse('<style>#hover{display:block;width:120px;height:40px;border-radius:4px;background:#e4f1fb;transition:transform .6s cubic-bezier(.2,.7,.2,1),background-color .4s linear,border-radius .8s ease,box-shadow .5s ease}#hover:is(:hover,:focus-visible){transform:translateX(12px) rotate(-2deg);background:#b8e7dc;border-radius:24px;box-shadow:7px 9px 0 #2b786a25}</style><button id="hover">Hover</button>')
	local hoverTree=renderer.build(hoverDocument,{},error);layout.arrange(hoverTree,200,0,0,function()return true end)
	local hoverNode,hoverBox
	for n,item in hoverTree.NodeBoxes do if n.Attributes and n.Attributes.id=="hover" then hoverNode,hoverBox=n,item end end
	local hoverClock=0;local hoverCallback;local hoverCleanups={}
	local hoverPage={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(hoverCleanups,fn)end}
	local hoverSignal={Connect=function(_,fn)hoverCallback=fn;return {Disconnect=function()hoverCallback=nil end}end}
	local hoverRuntime=HTMLAnimations.start(hoverPage,hoverTree,error,{RunService={Heartbeat=hoverSignal},Clock=function()return hoverClock end},4)
	hoverRuntime:AfterLayout()
	local startX=hoverBox.Gui.Position[1]
	local changed,needsLayout=hoverTree:SetCSSState("hover",hoverNode)
	assert(changed and needsLayout==false and hoverCallback,"Paint-only hover transitions must start without a full page relayout")
	assert(hoverBox.ShadowGuis and hoverBox.ShadowGuis[1] and math.abs(hoverBox.Corner.CornerRadius.Offset-4)<.001)
	hoverClock=.3;hoverCallback()
	local visibleX=hoverBox.Gui.Position[1]-hoverBox.Gui.AnchorPoint.X*hoverBox.OuterWidth
	assert(visibleX>startX and visibleX<startX+12,"Hover transform interpolates the visible control position instead of jumping")
	assert(hoverBox.Corner.CornerRadius.Offset>4 and hoverBox.Corner.CornerRadius.Offset<24,"Corner radius changes over its own duration: "..tostring(hoverBox.Corner.CornerRadius.Offset))
	assert(hoverBox.ShadowGuis[1].Transparency<1 and hoverBox.ShadowGuis[1].Transparency>0,"Shadow fades in over its own duration")
	assert(hoverBox.Gui.BackgroundColor3~=Color3.fromRGB(228,241,251) and hoverBox.Gui.BackgroundColor3~=Color3.fromRGB(184,231,220),"Background color interpolates during hover")
	assert(hoverTree:SetCSSState("hover",nil));assert(hoverCallback,"Leaving hover starts the reverse transition")
	hoverClock=1.2;hoverCallback()
	local restoredX=hoverBox.Gui.Position[1]-hoverBox.Gui.AnchorPoint.X*hoverBox.OuterWidth
	assert(math.abs(restoredX-startX)<.001 and math.abs(hoverBox.Corner.CornerRadius.Offset-4)<.001 and hoverBox.ShadowGuis[1].Transparency==1,
		"Reversing mid-flight returns position, radius and shadow to their original state")
	assert(hoverTree:SetCSSState("focus-visible",hoverNode) and hoverCallback,"Keyboard focus uses the same transition as hover")
	hoverCleanups[1]()
	-- Script effects use the same retained boxes, including a compositing
	-- group introduced after layout. Canceling an upper effect reveals the
	-- lower effect; removing the last restores current author declarations.
	local scriptDoc=Parser.parse('<style>#script{display:block;width:100px;height:30px;background:#000}</style><button id="script">Animate</button>')
	local scriptTree=renderer.build(scriptDoc,{},error);layout.arrange(scriptTree,300,0,0,function()return true end)
	local scriptNode=scriptDoc.Children[2];local scriptBox=scriptTree.NodeBoxes[scriptNode];local nativeGui=scriptBox.Gui
	local scriptAdapter=HTMLAnimations.scriptAdapter({Alive=true},scriptTree,error)
	local frames={{ComputedOffset=0,Easing="linear",Composite="auto",Values={opacity="0",transform="translateX(0px)",["background-color"]="#000"}},
		{ComputedOffset=1,Easing="linear",Composite="auto",Values={opacity="1",transform="translateX(40px)",["background-color"]="#fff"}}}
	local animation={AnimationState={Sequence=1}};local upper={AnimationState={Sequence=2}}
	assert(scriptAdapter:Validate(scriptNode,frames,"replace"));scriptAdapter:Apply(scriptNode,frames,{progress=.5,Phase="active"},animation,"replace")
	assert(scriptBox.Gui==nativeGui and scriptBox.OpacityGroup and nativeGui.Parent==scriptBox.OpacityGroup.Content,"WAAPI opacity retains the native button and descendants")
	assert(math.abs(scriptBox.OpacityGroup.Gui.GroupTransparency-.5)<.001 and math.abs((scriptBox.PaintBackgroundGui or nativeGui).BackgroundColor3.R-.5)<.001)
	local x=scriptBox.OpacityGroup.Gui.Position[1];local expectedX=(scriptBox.TransformBaseX or 0)+(scriptBox.OuterWidth or 0)/2+20
	assert(math.abs(x-expectedX)<.001,"Script transform uses the retained CSS pivot: "..tostring(x).." / "..tostring(expectedX))
	local upperFrames={{ComputedOffset=0,Easing="linear",Composite="auto",Values={opacity=".8"}},{ComputedOffset=1,Easing="linear",Composite="auto",Values={opacity=".8"}}}
	scriptAdapter:Apply(scriptNode,upperFrames,{progress=.5,Phase="active"},upper,"replace");assert(math.abs(scriptBox.OpacityGroup.Gui.GroupTransparency-.2)<.001)
	scriptAdapter:Release(scriptNode,upper);assert(math.abs(scriptBox.OpacityGroup.Gui.GroupTransparency-.5)<.001,"Releasing an upper effect reveals the remaining effect")
	scriptBox.Style.Opacity=.6;scriptAdapter:Release(scriptNode,animation)
	assert(scriptBox.Gui==nativeGui and math.abs(scriptBox.OpacityGroup.Gui.GroupTransparency-.4)<.001 and (scriptBox.PaintBackgroundGui or nativeGui).BackgroundColor3.R==0)
	assert(scriptAdapter:Validate(scriptNode,{{Composite="auto",Values={width="20px"}}},"replace"));assert(scriptAdapter:Validate(scriptNode,frames,"add"))
	local widthFrames={{ComputedOffset=0,Easing="linear",Composite="auto",Values={width="100px"}},{ComputedOffset=1,Easing="linear",Composite="auto",Values={width="200px"}}}
	scriptAdapter:Apply(scriptNode,widthFrames,{progress=.5,Phase="active"},animation,"replace")
	assert(scriptBox.Style.Width.Value==150 and scriptBox.Gui==nativeGui,"WAAPI layout width uses the same native control")
	scriptAdapter:Release(scriptNode,animation);assert(scriptBox.Style.Width.Value==100,"Releasing a layout effect restores the author width")
	scriptAdapter:Destroy()
	local mixedDoc=Parser.parse('<style>@keyframes under{from{opacity:.2}to{opacity:.8}}#mixed{width:100px;height:20px;animation:under 1s linear forwards}</style><div id="mixed"></div>')
	local mixedTree=renderer.build(mixedDoc,{},error);layout.arrange(mixedTree,300,0,0,function()return true end)
	local mixedNode=mixedDoc.Children[2];local mixedBox=mixedTree.NodeBoxes[mixedNode];local mixedClock=0;local mixedTick;local mixedCleanup
	local mixedPage={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)mixedCleanup=fn end}
	local cssRuntime=HTMLAnimations.start(mixedPage,mixedTree,error,{Clock=function()return mixedClock end,RunService={Heartbeat={Connect=function(_,fn)mixedTick=fn;return {Disconnect=function()mixedTick=nil end}end}}},4)
	cssRuntime:AfterLayout();mixedClock=.5;mixedTick()
	local mixedAdapter=HTMLAnimations.scriptAdapter(mixedPage,mixedTree,error);mixedAdapter:Apply(mixedNode,upperFrames,{progress=.5,Phase="active"},upper,"replace")
	assert(math.abs(mixedBox.OpacityGroup.Gui.GroupTransparency-.2)<.001);mixedAdapter:Release(mixedNode,upper)
	assert(math.abs(mixedBox.OpacityGroup.Gui.GroupTransparency-.5)<.001,"Last script release exposes active CSS paint immediately")
	mixedClock=1;mixedTick();assert(not mixedTick and #cssRuntime.Animations==0)
	mixedAdapter:Apply(mixedNode,frames,{progress=.2,Phase="active"},animation,"replace");mixedAdapter:Release(mixedNode,animation)
	assert(math.abs(mixedBox.OpacityGroup.Gui.GroupTransparency-.2)<.001 and not mixedTick,"Filled CSS effects survive script release without an idle connection")
	mixedAdapter:Destroy();mixedCleanup()
	print("CSS/script animation runtime: bounded updates, retained paint identity, effect release, idle suspension, timing, transforms, opacity, color and cleanup passed")
end
