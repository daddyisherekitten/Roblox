--!strict
return function(Parser, Dirty, loadRenderTree, loadWordLayout, loadBlockLayout, demoHTML, ControlView)
	local wordCalls, allocations = {}, 0
	local function create(class, parent, props)
		allocations += 1
		local gui=table.clone(props); gui.Parent,gui.ClassName=parent,class
		function gui:Destroy() self.Destroyed=true end
		return gui
	end
	local overrides={["Layout/FontProfiles"]={face=function(font) return font end},
		["Layout/TextMeasure"]={measure=function(text,_,size) return {X=(utf8.len(text) or 0)*5,Y=size} end}}
	local words=loadWordLayout(overrides)
	overrides["Layout/WordLayout"]={arrange=function(run,...)
		wordCalls[run]=(wordCalls[run] or 0)+1
		return words.arrange(run,...)
	end}
	local layout,renderer=loadBlockLayout(overrides),loadRenderTree({create=create,modifier=create})
	local function build(html)
		return renderer.build(Parser.parse(html),{},error,function(font) return font end,nil,nil,function() return "rbxassetid://1" end)
	end
	local function change(tree, id, value)
		for _,c in tree.Controls do if c.Node.Attributes.id == id then c.Value=value; c.Item.ControlMeasureKey=nil; return c.Item end end
		error("Missing output " .. id)
	end
	local function update(tree,width,items)
		tree.ViewportHeight=300
		local stats=Dirty.begin(tree,items)
		local ok,h,w,b=pcall(layout.arrange,tree,width,0,0,function() return true end)
		Dirty.finish(tree,ok)
		assert(ok,h)
		return stats,h,w,b
	end
	local function snapshot(tree)
		local result={}
		local function number(v) table.insert(result,if type(v) == "number" then string.format("%.4f",v) else tostring(v)) end
		local function gui(g)
			if not g then return end
			for _,key in {"Position","Size","CanvasSize","CanvasPosition"} do
				local v=g[key]
				if v then number(v.x or v.X); number(v.y or v.Y) else number(nil) end
			end
			number(g.TextSize)
		end
		local function visit(box)
			for _,key in {"LayoutX","LayoutY","OuterWidth","OuterHeight","ContentWidth","ContentHeight","LocalRight","LocalBottom","FirstBaseline","ScrollX","ScrollY"} do number(box[key]) end
			gui(box.Gui); gui(box.ScrollGui)
			if box.OpacityGroup then gui(box.OpacityGroup.Gui); gui(box.OpacityGroup.Content) end
			for _,group in box.InlineOpacityGroups or {} do gui(group.Gui); gui(group.Content) end
			for _,item in box.Items or (if box.ImageItem then {box.ImageItem} else {}) do
				for _,key in {"X","Y","Width","Height","Baseline","TextSize","BoxWidth","BoxHeight"} do number(item[key]) end
				gui(item.Gui); gui(item.Editor or item.Label)
			end
			for _,child in box.Children or {} do visit(child) end
		end
		visit(tree)
		return table.concat(result,"|")
	end
	local html='<div style="font-family:Roboto"><div id="before">Unchanged above</div><form><output id="out" style="display:block"></output><div id="after">Following text</div></form><p>Last sibling</p></div>'
	local tree=build(html)
	local initial,initialHeight=update(tree,300)
	assert(initial.Mode == "full" and initial.Reused == 0)
	local upper
	for run in wordCalls do if run.Items[1].Text == "Unchanged" then upper=run end end
	assert(upper)
	local oldCalls,oldAlloc=wordCalls[upper],allocations
	local item=change(tree,"out","Result")
	local stats,height=update(tree,300,{[item]=true})
	assert(stats.Mode == "partial" and stats.Reused > 0 and stats.Recomputed < initial.Recomputed)
	assert(wordCalls[upper] == oldCalls and allocations == oldAlloc,"Earlier text is not laid out again and no GUIs are replaced")
	assert(height > initialHeight,"Output growth updates parent and document extent")
	local saved=snapshot(tree)
	local full,fullHeight=update(tree,300)
	assert(saved == snapshot(tree) and height == fullHeight and full.Mode == "full","Partial result must equal a full layout including following siblings")
	item=change(tree,"out","")
	local _,shrunk=update(tree,300,{[item]=true})
	assert(shrunk == initialHeight,"Reset shrinks parent and scroll extent again")
	-- Compare against an independently laid out tree through repeated changes.
	local cases={
		'<div style="display:flex;flex-wrap:wrap;gap:5px"><output id="out"></output><div>Other flex item</div></div>',
		'<div style="width:110px;height:40px;overflow:auto"><output id="out" style="display:block"></output><p>Scrolling content</p></div>',
		'<div style="position:relative"><output id="out" style="display:block"></output><div style="position:absolute;bottom:0;right:0">Pinned</div></div>',
		'<div style="opacity:.5"><output id="out" style="display:block"></output><p>Group</p></div>',
		'<blockquote><p>Margin</p><output id="out" style="display:block;margin:8px 0"></output></blockquote>',
		'<div style="width:60%;padding:5%;margin:auto"><output id="out" style="display:block"></output></div>',
		'<div style="position:relative;opacity:.5"><div style="height:40px;overflow:auto"><output id="out" style="display:block"></output><div style="position:absolute;right:0;bottom:0">Pinned</div></div></div>',
		'<div style="height:40px;overflow:auto"><div style="height:30px;overflow:auto"><output id="out" style="display:block"></output></div><p>Outer scroll</p></div>',
	}
	for _,part in cases do
		local source='<div style="font-family:Roboto"><p>Before</p>' .. part .. '<p>After</p></div>'
		local partialTree,reference=build(source),build(source)
		update(partialTree,300); update(reference,300)
		for _,value in {"A",string.rep("Long result ",20),""} do
			local changed=change(partialTree,"out",value); change(reference,"out",value)
			local _,ph,pw=update(partialTree,300,{[changed]=true})
			local _,rh,rw=update(reference,300)
			assert(ph == rh and pw == rw and snapshot(partialTree) == snapshot(reference),"Dirty/full mismatch: " .. part)
		end
		update(partialTree,180); update(reference,180)
		assert(snapshot(partialTree) == snapshot(reference),"Resize remains a full layout")
	end
	-- Unchanged special branches retain native scroll positions and do no text work.
	local specialHTML='<div style="font-family:Roboto"><div id="scroll" style="width:90px;height:35px;overflow:auto"><p style="white-space:nowrap">A long scrolling line</p><p>More content</p></div><div id="position" style="position:relative;width:160px;height:45px;opacity:.7"><span style="opacity:.5">Nested group</span><div style="position:absolute;right:0;bottom:0">Pinned</div></div><output id="out" style="display:block"></output></div>'
	local special,reference=build(specialHTML),build(specialHTML)
	local function findBox(box,id)
		if box.Node and box.Node.Attributes and box.Node.Attributes.id == id then return box end
		for _,child in box.Children or {} do local found=findBox(child,id); if found then return found end end
	end
	update(special,300); update(reference,300)
	local scroll,refScroll=findBox(special,"scroll"),findBox(reference,"scroll")
	scroll.ScrollGui.CanvasPosition,refScroll.ScrollGui.CanvasPosition=Vector2.new(12,7),Vector2.new(12,7)
	local callsBefore=table.clone(wordCalls)
	local specialItem=change(special,"out","Result"); change(reference,"out","Result")
	local specialStats=update(special,300,{[specialItem]=true}); update(reference,300)
	assert(snapshot(special) == snapshot(reference))
	assert(scroll.ScrollParticipated == false and scroll.ScrollGui.CanvasPosition.X == 12 and scroll.ScrollGui.CanvasPosition.Y == 7,"Unchanged native scroll state must not be reset or committed")
	assert(specialStats.PositionReused > 0 and specialStats.OpacityReused > 0,"Special postpasses must actually be skipped")
	local function unchangedRuns(box)
		if box.Kind == "Words" then assert(wordCalls[box] == callsBefore[box],"Unchanged special branch must not arrange text") end
		for _,child in box.Children or {} do unchangedRuns(child) end
	end
	unchangedRuns(scroll); unchangedRuns(findBox(special,"position"))
	-- The initial position-anchor:normal has no external dependency with
	-- position-area:none. It must not prevent an ordinary relative subtree
	-- from closing its intrinsic/layout inputs.
	for _,declaration in {'','position-anchor:none','position-anchor:normal;position-area:none'}do
		local closed=build('<div id="closed"><div style="position:relative;'..declaration..'"><div style="position:absolute;left:0;top:0;width:20px;height:10px"></div></div></div>')
		update(closed,300);assert(findBox(closed,'closed').CanReuseLayout,'An inactive default anchor preserves relative subtree reuse')
	end
	for _,declaration in {'position-anchor:--external','position-anchor:auto','position-anchor:normal;position-area:bottom','left:anchor(--external left,0px)'}do
		local dependent=build('<div id="external"><div style="position:relative;'..declaration..'"><div style="position:absolute;left:0;top:0;width:20px;height:10px"></div></div></div>')
		update(dependent,300);assert(not findBox(dependent,'external').CanReuseLayout,'Active named/implicit/area/function anchors retain external dependency checks')
	end
	-- A changed ancestor can move a cached relative/opacity branch in global coordinates.
	local movingHTML='<div style="font-family:Roboto"><output id="out" style="display:block"></output><div><div style="position:relative;opacity:.5;width:120px;height:40px"><div style="position:absolute;right:0;bottom:0">Moved</div></div><div style="height:20px;overflow:auto"><p>Scroll</p><p>More</p></div></div></div>'
	local moving,movingReference=build(movingHTML),build(movingHTML)
	update(moving,300); update(movingReference,300)
	for _,value in {"New text",""} do
		local changed=change(moving,"out",value); change(movingReference,"out",value)
		update(moving,300,{[changed]=true}); update(movingReference,300)
		assert(snapshot(moving) == snapshot(movingReference),"Moving a containing branch must refresh postpass dependencies")
	end
	local demo=build(demoHTML)
	update(demo,456)
	local result=change(demo,"preview-result","Button geklickt.")
	local demoStats,dh,dw=update(demo,456,{[result]=true})
	local demoSnapshot=snapshot(demo)
	local _,fh,fw=update(demo,456)
	assert(demoStats.Reused > 0 and dh == fh and dw == fw and demoSnapshot == snapshot(demo),"The actual demo must match full layout")
	assert(demoStats.Recomputed < 20 and demoStats.PositionReused > 0 and demoStats.OpacityReused > 0,"Stage 2 must reduce actual demo work, not just relabel counters")
	Dirty.begin(tree,{[item]=true}); Dirty.finish(tree,false)
	assert(update(tree,300,{[item]=true}).Mode == "full","Failure invalidates reuse")
	assert(update(tree,300,{[{}]=true}).Mode == "full","Unknown dependencies fall back to full layout")
	-- Paint-only decisions compare native widths with the placed layout, not string length.
	local sized=build('<div style="font-family:Roboto"><output id="out">A</output><span> Following</span></div>')
	update(sized,300)
	local sizedItem=change(sized,"out","B")
	local geometry=snapshot(sized)
	local measureCalls=0
	local function measured(text,_,size)
		measureCalls+=1
		return {X=if text == "W" then 10 else #text*5,Y=size}
	end
	ControlView.paint(sizedItem)
	assert(ControlView.canKeepLayout(sizedItem,measured,function() return true end))
	assert(measureCalls == 1 and sizedItem.Label.Text == "B" and snapshot(sized) == geometry,"Equal native size paints text without geometry changes or a second measurement")
	change(sized,"out","W")
	assert(not ControlView.canKeepLayout(sizedItem,measured,function() return true end),"Equal character count is insufficient when glyph widths differ")
	change(sized,"out","C")
	assert(ControlView.canKeepLayout(sizedItem,measured,function() return true end),"Compare with the placed width, not the last speculative width")
	change(sized,"out","")
	assert(not ControlView.canKeepLayout(sizedItem,measured,function() return true end),"Empty output changes line height")
	change(sized,"out","A")
	local once=false
	local function changedDuringMeasurement(text,font,size)
		if not once then once=true; change(sized,"out","W") end
		return measured(text,font,size)
	end
	assert(not ControlView.canKeepLayout(sizedItem,changedDuringMeasurement,function() return true end),"A newer value cannot be declared unchanged using old bounds")
	assert(not ControlView.canKeepLayout(sizedItem,measured,function() return false end),"Destroy during a measurement must stop the fast path")
	print(string.format("Dirty layout: growth/reset, unchanged branches, full-layout equivalence, flex/scroll/position/opacity, resize and failure recovery passed; demo %d layout calls, %d cache hits, %d position hits, %d opacity hits",demoStats.Recomputed,demoStats.Reused,demoStats.PositionReused,demoStats.OpacityReused))
end
