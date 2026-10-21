--!strict
return function(html, css, Parser, loadRenderTree, loadWordLayout, loadBlockLayout, HTMLAnimations)
	local function create(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent
		function gui:Destroy() end
		return gui
	end
	local renderer=loadRenderTree({create=create,modifier=create})
	local overrides={
		["Layout/FontProfiles"]={face=function(font) return font end},
		["Layout/TextMeasure"]={measure=function(text,_,size) return {X=#text*size*.5,Y=size} end},
	}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	for _,width in {360,800,1280} do
		local document=Parser.parse(html)
		assert(#document.Diagnostics==0,"Hover laboratory must parse without errors")
		local warnings={}
		local tree=renderer.build(document,{AbsoluteSize={X=width,Y=800}},function(message) table.insert(warnings,message) end,
			nil,nil,nil,nil,nil,nil,nil,nil,nil,{["styles.css"]=css})
		tree:SetMediaEnvironment(width,800)
		layout.arrange(tree,width,0,0,function() return true end)
		assert(#warnings==0,table.concat(warnings,"\n"))
		assert(tree.OuterHeight>2000 and tree.OuterHeight<20000,"Laboratory has a finite long document")
		local cases={}
		for node,box in tree.NodeBoxes do if node.Attributes and node.Attributes.id then cases[node.Attributes.id]=box end end
		for index=1,14 do assert(cases[string.format("fall-%02d",index)],"All fourteen test cards must render") end
		if width<740 then
			assert(cases["fall-02"].Gui.Position[2]>cases["fall-01"].Gui.Position[2],"Narrow layouts stack cards")
		else
			assert(cases["fall-02"].Gui.Position[1]>cases["fall-01"].Gui.Position[1],"Wide layouts display pairs")
		end
		local exercised=0
		for _,node in tree.Links do
			if node.Attributes.href~="#auswertung" then continue end
			local _,needsLayout=tree:SetCSSState("hover",node)
			assert(not needsLayout,"Test-button hover must not require page layout")
			tree:SetCSSState("hover",nil)
			exercised+=1
		end
		assert(exercised==15,"Fourteen cases include the pair of reversal buttons")
	end
	-- Keep the same live page across desktop/mobile media changes. Earlier
	-- checks rebuilt every width and could not detect a stale transform base.
	local document=Parser.parse(html)
	local tree=renderer.build(document,{AbsoluteSize={X=1280,Y=800}},error,nil,nil,nil,nil,nil,nil,nil,nil,nil,{["styles.css"]=css})
	tree:SetMediaEnvironment(1280,800);layout.arrange(tree,1280,0,0,function()return true end)
	local clock,tick,cleanup=0,nil,nil
	local runtime=HTMLAnimations.start({Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)cleanup=fn end},tree,error,
		{RunService={Heartbeat={Connect=function(_,fn)tick=fn;return {Disconnect=function()tick=nil end}end}},Clock=function()return clock end},0)
	runtime:AfterLayout()
	local function left(box)
		local gui=if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui
		local bounds=box.OpacityGroup and box.OpacityBounds
		local width=if bounds then bounds[3]-bounds[1] else box.OuterWidth
		return gui.Position[1]-(gui.AnchorPoint and gui.AnchorPoint.X or 0)*width*(if box.TransformScale then box.TransformScale.Scale else 1)
	end
	local checks=0
	for _,width in {800,360,1280,360} do
		tree:SetMediaEnvironment(width,800);layout.arrange(tree,width,0,0,function()return true end);runtime:AfterLayout()
		assert(next(runtime.Transitions)==nil,"Responsive flow changes alone cannot start CSS transform transitions")
		for _,node in tree.Links do
			local class=node.Attributes.class or ""
			if node.Attributes.href~="#auswertung" or class:find("scale%-only") or class:find("rotate%-only") then continue end
			local box=tree.NodeBoxes[node];assert(box)
			local x=left(box)
			tree:SetCSSState("hover",node)
			for _=1,27 do
				clock+=.04;if tick then tick() end
				assert(math.abs(left(box)-x)<.001,"The actual hover page cannot shift horizontally after a resize: "..class.." at "..tostring(width).." left "..tostring(left(box)).." expected "..tostring(x).." base "..tostring(box.TransformBaseX).." anchor "..tostring(box.Gui.AnchorPoint and box.Gui.AnchorPoint.X).." size "..tostring(box.OuterWidth))
			end
			tree:SetCSSState("hover",nil)
			clock+=1.1;if tick then tick() end
			assert(math.abs(left(box)-x)<.001,"Hover-out restores the current responsive position")
			checks+=1
		end
	end
	cleanup();assert(not tick)
	print("Hover laboratory: browser/Roblox source parity, fourteen cases, three responsive widths, paint-only hover and "..checks.." live-resize comparisons passed")
end
