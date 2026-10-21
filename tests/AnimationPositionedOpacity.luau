--!strict
-- Compare actual native surface placement, not just CSSOM's logical rectangles.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLAnimations,fixtures)
	local states,nativeStates,normativeStates=0,0,0
	local function near(actual,expected,label)
		assert(type(actual)=='number'and math.abs(actual-expected)<.06,label..': '..tostring(actual)..' ~= '..tostring(expected))
	end
	for _,case in fixtures.records do
		local reference=case
		if case.normativeReference then
			assert(case.name=='percentage transform accumulate'and case.nativeDifference,'Every native difference is explicitly bounded and explained')
			for _,candidate in fixtures.records do if candidate.name==case.normativeReference then reference=candidate;break end end
			assert(reference~=case and reference.name=='matrix accumulation equivalent pixels accumulate','Independent native pixel reference is present')
		end
		local objects={};local factory={}
		function factory.create(class,parent,props)
			local gui=table.clone(props or{});gui.ClassName,gui.Parent=class,parent
			function gui:IsA(kind)return kind==class or kind=='GuiObject'or kind=='Instance'end
			function gui:Destroy()assert(not self.Destroyed);self.Destroyed=true;self.Parent=nil end
			table.insert(objects,gui);return gui
		end
		factory.modifier=factory.create
		local document=Parser.parseDocument('<!doctype html><style>'..case.css..'</style><div id=stage><div id=box></div></div>')
		local root={AbsoluteSize=Vector2.new(600,800),AbsolutePosition=Vector2.new(0,0),CanvasPosition=Vector2.new(0,0)}
		local tree=loadRenderTree(factory).build(document,root,error)
		local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*7,size)end}}
		overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
		local page={Alive=true,Root={SetAttribute=function()end},Cleanups={}};local realm;local pending=true;local targets={};local flushing=false
		function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
		function page:RequestAnimationLayout(box)pending=true;targets[box]=true end
		function page:HasPendingLayout()return pending end
		function page:FlushScriptLayout()
			if flushing or not realm then return end;flushing=true
			for attempt=1,5 do
				local needed=realm:Flush();if not needed and not pending then break end
				local dirty=targets;targets={};pending=false
				Dirty.begin(tree,if next(dirty)then dirty else nil);layout.arrange(tree,600,0,0,function()return true end);Dirty.finish(tree,true)
				page.MotionRuntime:AfterLayout();realm:AfterLayout();assert(attempt<5 or not pending,'Positioned effect layout did not converge')
			end
			flushing=false
		end
		page.MotionRuntime=HTMLAnimations.start(page,tree,error,{Clock=function()return 0 end,RunService={Heartbeat={Connect=function()return{Disconnect=function()end}end}}},0)
		realm=Runtime.new(document,{Clock=function()return 0 end,Events=Events.new(error),Diagnostic=error,
			CreateAnimationAdapter=function()return HTMLAnimations.scriptAdapter(page,tree,error)end,
			GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return{Width=600,Height=800,ClientWidth=600,ClientHeight=800}end,HasPending=function()return pending or realm:HasPending()end,Flush=function()page:FlushScriptLayout()end},
			ApplyChanges=function(changes)local needed,items=tree:ApplyDOMChanges(changes);pending=pending or needed;for item,reason in items or{}do targets[item]=reason end;return needed,items end})
		local function run(source)assert(realm:Run(source));page:FlushScriptLayout();realm:AfterLayout();assert(#realm.Diagnostics==0)end
		run(case.source) -- The effect is created while all native origins are still zero.
		local box=tree.NodeBoxes[Node.findById(document,'box')];local stage=tree.NodeBoxes[Node.findById(document,'stage')];local kept=box.Gui;local keptGroup=box.OpacityGroup.Gui
		local function axis(value,scale,basis)return(value and value[scale]or 0)*basis+(value and value[if scale=='XScale'then 1 else 2]or 0)end
		local function size(gui)
			if gui==root then return 600,800 end
			local pw,ph=if gui.Parent then size(gui.Parent)else 600,800
			return axis(gui.Size,'XScale',pw),axis(gui.Size,'YScale',ph)
		end
		local function nativePoint(gui,x,y)
			local guard=0
			while gui~=stage.Gui do
				guard+=1;assert(gui and guard<30,'The positioned native surface left its actual stage')
				local w,h=size(gui);local pw,ph=if gui.Parent then size(gui.Parent)else 600,800
				local scale=1;for _,object in objects do if object.Parent==gui and object.ClassName=='UIScale'and not object.Destroyed then scale*=object.Scale end end
				local a=gui.AnchorPoint or Vector2.new(0,0);local angle=math.rad(gui.Rotation or 0);local c,s=math.cos(angle),math.sin(angle)
				local dx,dy=x-w/2,y-h/2
				x=axis(gui.Position,'XScale',pw)+scale*(w/2-a.X*w+c*dx-s*dy)
				y=axis(gui.Position,'YScale',ph)+scale*(h/2-a.Y*h+s*dx+c*dy)
				gui=gui.Parent
			end
			return x,y
		end
		local resized=false
		for index,sample in case.expected do
			local expected=reference.expected[index];assert(expected.time==sample.time and expected.resized==sample.resized,'Reference sample correspondence')
			if sample.resized and not resized then run("document.getElementById('stage').style.width='460px';document.getElementById('stage').style.height='280px'");resized=true end
			run('effect.currentTime='..sample.time)
			local w,h=box.OuterWidth,box.OuterHeight;local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
			for _,point in {{0,0},{w,0},{0,h},{w,h}}do local x,y=nativePoint(box.Gui,point[1],point[2]);left=math.min(left,x);top=math.min(top,y);right=math.max(right,x);bottom=math.max(bottom,y)end
			for index,value in {left,top,right-left,bottom-top}do near(value,expected.rect[index],case.name..' time '..sample.time..' resized '..tostring(resized)..' rendered rect '..index)end
			assert(box.Gui==kept and box.OpacityGroup.Gui==keptGroup,'Scrubbing and resize retain both native surfaces')
			assert(realm.EventLoop.FrameCount==0,'A paused effect must not request an idle frame')
			states+=1
			if reference==case then nativeStates+=1 else normativeStates+=1 end
		end
		-- Cancellation restores the underlying author pose at the current position.
		run('effect.cancel()');assert(box.Gui==kept and box.OpacityGroup.Gui==keptGroup and not box.HasScriptTransformEffects)
		realm:Destroy();for _,cleanup in page.Cleanups do cleanup()end;page.Alive=false;tree.VisualEffects:Destroy()
		for _,object in objects do if not object.Destroyed then object:Destroy()end end
	end
	print('Positioned opacity animations: '..#fixtures.records..' cases / '..states..' states ('..nativeStates..' direct native, '..normativeStates..' independently captured normative pixel equivalents), initial/seek/resize/retention/cleanup passed')
end
