--!strict
-- Reproduce native integer UDim offsets, which the usual GUI test doubles do
-- not round. A fractional AnchorPoint must never introduce horizontal motion
-- into a vertical CSS transition, including interrupted reversals.
return function(Parser, loadRenderTree, loadWordLayout, loadBlockLayout, HTMLAnimations, DirtyLayout)
	local function create(class, parent, props)
		local values={ClassName=class,Parent=parent,AnchorPoint=Vector2.new(0,0)}
		local object=setmetatable({}, {
			__index=values,
			__newindex=function(_,key,value)
				if key=="Position" or key=="Size" then
					value=UDim2.fromOffset(math.floor(value[1]),math.floor(value[2]))
				end
				values[key]=value
			end,
		})
		for key,value in props do object[key]=value end
		return object
	end
	local renderer=loadRenderTree({create=create,modifier=create})
	local overrides={
		["Layout/FontProfiles"]={face=function(font)return font end},
		["Layout/TextMeasure"]={measure=function(text,_,size)return {X=#text*8,Y=size} end},
	}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local function fixture(base,hover,timing,responsive)
		local stageCSS=if responsive then '#stage{display:flex;box-sizing:border-box;align-items:center;justify-content:center;width:100%;height:144px;padding:16px}#stage #button{margin:0;max-width:100%}' else ''
		local markup=if responsive then '<div id="stage"><button id="button">Hover</button></div><div id="other" style="height:20px"></div>' else '<button id="button">Hover</button>'
		local document=Parser.parse('<style>#button{display:block;box-sizing:border-box;border:0;width:270px;height:53px;margin:45px 0 0 93px;transition:transform 1s '..(timing or 'ease')..';'..base..'}#button:hover{'..hover..'}'..stageCSS..'</style>'..markup)
		local tree=renderer.build(document,{},error)
		layout.arrange(tree,600,0,0,function()return true end)
		local node,box
		for n,b in tree.NodeBoxes do if n.Attributes and n.Attributes.id=="button" then node,box=n,b end end
		local clock,tick,cleanup=0,nil,nil
		local runtime=HTMLAnimations.start({Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)cleanup=fn end},tree,error,
			{RunService={Heartbeat={Connect=function(_,fn)tick=fn;return {Disconnect=function()tick=nil end}end}},Clock=function()return clock end},0)
		runtime:AfterLayout()
		return tree,node,box,runtime,function(time)clock=time;if tick then tick() end end,function()cleanup();assert(not tick)end
	end
	local function topLeft(box)
		local gui=if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui
		local scale=if box.TransformScale then box.TransformScale.Scale else 1
		return gui.Position[1]-gui.AnchorPoint.X*gui.Size[1]*scale,gui.Position[2]-gui.AnchorPoint.Y*gui.Size[2]*scale
	end
	for _,base in {"", "transform:translateY(0px)", "transform-origin:20% 80%", "opacity:.6"} do
		local tree,node,box,runtime,step,dispose=fixture(base,"transform:translateY(-2px)")
		local startX,startY=topLeft(box)
		local time=0
		local function sample(to,direction)
			local _,previousY=topLeft(box)
			while time<to do
				time=math.min(to,time+1/120);step(time)
				local x,y=topLeft(box)
				assert(math.abs(x-startX)<.001,"Native offset rounding must not move a translateY transition sideways")
				assert(y>=startY-3 and y<=startY+1,"An odd-height control stays on its vertical path")
				assert((y-previousY)*direction>=-.001,"The vertical transition must not jitter against its direction")
				previousY=y
			end
		end
		for _=1,4 do
			local changed,needsLayout=tree:SetCSSState("hover",node)
			assert(changed and not needsLayout,"The regression must run through autonomous paint-only CSS updates")
			assert(runtime.Transitions[box],"Hover starts a transition without a page layout")
			sample(time+.137,-1)
			local interruptedX,interruptedY=topLeft(box)
			tree:SetCSSState("hover",nil)
			local reversedX,reversedY=topLeft(box)
			assert(interruptedX==reversedX and interruptedY==reversedY,"Reversing a partially rounded frame cannot jump")
			sample(time+1.01,1)
			local x,y=topLeft(box);assert(x==startX and y==startY,"Repeated reversals do not accumulate pixel drift: "..tostring(x)..","..tostring(y).." vs "..tostring(startX)..","..tostring(startY).." retained "..tostring(box.TransformPositionY))
		end
		tree:SetCSSState("hover",node);sample(time+1.01,-1)
		local x,y=topLeft(box);assert(x==startX and math.abs(y-(startY-2))<1.001,"The completed hover reaches its CSS translation")
		tree:SetCSSState("hover",nil);sample(time+1.01,1)
		assert(next(runtime.Transitions)==nil,"Completed motion is idle")
		dispose()
	end
	-- A completed hover retains its transform base. Resizing a centered Flex
	-- child must replace that base before the next paint-only hover uses it.
	for _,base in {"", "opacity:.6", "transform:translateY(0px)"} do
		local tree,node,box,runtime,step,dispose=fixture(base,"transform:translateY(-2px)","linear",true)
		local time=0
		for _,width in {600,400,320,800,280,600} do
			layout.arrange(tree,width,0,0,function()return true end);runtime:AfterLayout()
			local x,y=topLeft(box)
			local expectedX=(width-box.OuterWidth)/2
			assert(math.abs(x-expectedX)<1.001,"Resize centers the retained button before hover: "..base.." width "..tostring(width).." x "..tostring(x).." expected "..tostring(expectedX).." base "..tostring(box.TransformBaseX))
			tree:SetCSSState("hover",node)
			for frame=1,125 do
				step(time+frame/120)
				local hoverX=topLeft(box)
				assert(math.abs(hoverX-x)<.001,"Hover after resizing must not reuse the old horizontal transform base")
			end
			time+=1.05;tree:SetCSSState("hover",nil);step(time+1.05);time+=1.05
			local restoredX,restoredY=topLeft(box)
			assert(restoredX==x and math.abs(restoredY-y)<1.001,"Reverse hover returns to the newly centered flow position")
		end
		dispose()
	end
	-- A layout can also finish while a hover is still in flight. Later frames
	-- must follow the new flow position without restarting the transition.
	for _,hover in {"transform:translateY(-2px)", "transform:scale(1.2) rotate(20deg)"} do
		local tree,node,box,runtime,step,dispose=fixture("",hover,"linear",true)
		tree:SetCSSState("hover",node);step(.25)
		layout.arrange(tree,320,0,0,function()return true end);runtime:AfterLayout();step(.5)
		local transition=runtime.Transitions[box]
		assert(transition and transition.Start==0,"Resize preserves the active transition's timing")
		local x=topLeft(box)
		if hover=="transform:translateY(-2px)" then
			assert(math.abs(x-(320-box.OuterWidth)/2)<1.001,"Active translateY follows the resized center")
		else
			local gui=box.Gui;local scale=box.TransformScale.Scale
			local centerX=x+gui.Size[1]*scale/2
			assert(math.abs(centerX-160)<1.001,"Scale/rotation keep their CSS pivot at the resized center")
			assert(math.abs(scale-1.1)<.001 and math.abs(gui.Rotation-10)<.001,"Resize preserves interpolated scale and rotation")
		end
		step(1.01);tree:SetCSSState("hover",nil);step(2.02)
		local restoredX=topLeft(box)
		assert(math.abs(restoredX-(320-box.OuterWidth)/2)<1.001,"Resize during motion cannot restore the old layout")
		dispose()
	end
	-- Partial layout may reuse a transformed branch while a sibling changes.
	-- Its native position is paint, not a fresh flow base to capture again.
	do
		local tree,node,box,runtime,step,dispose=fixture("","transform:scale(1.2) rotate(20deg)","linear",true)
		DirtyLayout.begin(tree);layout.arrange(tree,600,0,0,function()return true end);runtime:AfterLayout();DirtyLayout.finish(tree,true)
		tree:SetCSSState("hover",node);step(.25)
		local other
		for n,b in tree.NodeBoxes do if n.Attributes and n.Attributes.id=="other" then other=b end end
		assert(other);other.Style.Height=table.clone(other.Style.Height);other.Style.Height.Value=40
		local stats=DirtyLayout.begin(tree,{[other]=true});layout.arrange(tree,600,0,0,function()return true end);runtime:AfterLayout();DirtyLayout.finish(tree,true)
		assert(stats.Reused>0,"The regression must actually reuse an unchanged transformed branch")
		step(.5)
		local x=topLeft(box);local center=x+box.Gui.Size[1]*box.TransformScale.Scale/2
		assert(math.abs(center-300)<1.001,"Reusing a transformed subtree cannot count its painted displacement twice")
		step(1.01);tree:SetCSSState("hover",nil);step(2.02)
		local restoredX=topLeft(box);assert(restoredX==165,"Partial layout preserves the retained flow base on hover-out")
		dispose()
	end
	-- A stable anchor must preserve the CSS pivot when scale and rotation join
	-- the translation. Compare painted corners against an immediate CSS paint.
	for _,origin in {"center", "left top", "20% 80%"} do
		local base="transform-origin:"..origin..";opacity:.6"
		local hover="transform:translate(12px,-8px) rotate(20deg) scale(1.2)"
		local tree,node,box,_,step,dispose=fixture(base,hover,"linear")
		local reference,refNode,refBox,_,refStep,refDispose=fixture(base,hover,"linear")
		refBox.Style.TransitionDuration={0};reference:SetCSSState("hover",refNode);refStep(1)
		tree:SetCSSState("hover",node);step(.5)
		assert(math.abs(box.TransformScale.Scale-1.1)<.001 and math.abs(box.OpacityGroup.Gui.Rotation-10)<.001)
		step(1.01)
		local function corner(item)
			local gui=item.OpacityGroup.Gui;local scale=item.TransformScale.Scale
			local cx,cy=gui.Size[1]/2,gui.Size[2]/2
			local c,s=math.cos(math.rad(gui.Rotation)),math.sin(math.rad(gui.Rotation))
			return gui.Position[1]+scale*(cx-gui.AnchorPoint.X*gui.Size[1]-c*cx+s*cy),
				gui.Position[2]+scale*(cy-gui.AnchorPoint.Y*gui.Size[2]-s*cx-c*cy)
		end
		local x,y=corner(box);local rx,ry=corner(refBox)
		assert(math.abs(x-rx)<1.01 and math.abs(y-ry)<1.01,"Fixed-anchor transitions preserve rotated/scaled endpoint geometry within native pixel rounding")
		tree:SetCSSState("hover",nil);step(2.02)
		local bx,by=topLeft(box);assert(bx==93 and by==45,"Composed transitions return to their original flow position")
		dispose();refDispose()
	end
	print("Hover transition geometry: native rounding, constant X, monotonic Y, reversals, live resize, preserved timing/pivots, partial-layout reuse and opacity surfaces passed")
end
