return function(fixtures,Parser,Node,Style,loadRenderTree,loadWordLayout,loadBlockLayout,Dirty)
	local objects=0
	local factory={create=function(_,owner,props)local gui=table.clone(props);gui.Parent=owner;objects+=1;return gui end,modifier=function(_,_,props)return table.clone(props)end}
	local renderer=loadRenderTree(factory)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*size/2,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local block=loadBlockLayout(overrides)
	local comparisons,mutations=0,0;local failures={}
	local function near(a,b,label)
		comparisons+=1
		if math.abs(a-b)>.04 then table.insert(failures,label..': '..tostring(a)..' != '..tostring(b))end
	end
	local function layout(tree,items)
		Dirty.begin(tree,items);block.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
	end
	for _,scene in fixtures.cases do
		local doc=Parser.parse(scene.html)
		local tree=renderer.build(doc,{AbsoluteSize={X=800,Y=600}},function()end)
		layout(tree,nil)
		local saved,styles={},{}
		for node,box in tree.NodeBoxes do saved[node]=box.Gui;styles[node]=box.Style end
		local function compare(expectedList,label)
		local root=tree.NodeBoxes[Node.findById(doc,'root')]
		local positions={}
		local function visit(box,x,y)
			if box.Node and box.Node.Attributes and box.Node.Attributes.id then positions[box.Node.Attributes.id]={X=x,Y=y,Box=box}end
			for _,child in box.PositioningChildren or box.Children or{}do
				if child.Kind~='Words'then visit(child,x+(child.PaintX or child.LayoutX or 0),y+(child.PaintY or child.LayoutY or 0))end
			end
		end
		visit(root,0,0)
		for _,expected in expectedList do
			local native=expected;expected=table.clone(native);for key,value in native.normative or{}do expected[key]=value end
			if expected.skipGeometry then continue end -- Only anchor rejection is covered for skipped contents, not forced descendant measurement.
			local actual=positions[expected.id]
			if actual then
				near(actual.X,expected.x,label..'/'..expected.id..'/x');near(actual.Y,expected.y,label..'/'..expected.id..'/y')
				near(actual.Box.OuterWidth or 0,expected.width,label..'/'..expected.id..'/width');near(actual.Box.OuterHeight or 0,expected.height,label..'/'..expected.id..'/height')
			elseif expected.display=='contents'and expected.width==0 and expected.height==0 then
				assert(not tree.NodeBoxes[Node.findById(doc,expected.id)],'display:contents creates no principal anchor box')
			else table.insert(failures,scene.name..' missing '..expected.id)end
		end
		end
		compare(scene.expected,scene.name)
		for index,step in scene.steps or{}do
			local before=objects;local change=step.mutation;local node=assert(Node.findById(doc,change.target))
			local batch
			if change.append then node.Children[1].Text..=change.append;batch={[node]={Text=true}}
			else node.Attributes.style=change.style;batch={[node]={Attributes={style=true}}}end
			local _,targets=tree:ApplyDOMChanges(batch);layout(tree,targets)
			compare(step.expected,scene.name..'/mutation '..index);mutations+=1
			assert(objects==before,scene.name..': changing anchors/scopes/fallbacks must retain GUI objects')
			for candidate,gui in saved do assert(tree.NodeBoxes[candidate].Gui==gui and tree.NodeBoxes[candidate].Style==styles[candidate],scene.name..': surface and computed style identity are retained')end
		end
	end
	for _,probe in fixtures.syntax do
		local compiled=Style.compile(probe.property..':'..probe.value)
		local accepted=#compiled.Normal>0 and not compiled.Normal[1].Error
		local native=if probe.normativeAccepted~=nil then probe.normativeAccepted else probe.accepted
		if accepted~=native then table.insert(failures,'syntax '..probe.property..':'..probe.value..' '..tostring(accepted)..' != '..tostring(native))end
	end
	if #failures>0 then for i=1,math.min(#failures,50)do print(failures[i])end;error(tostring(#failures)..' anchor reference mismatches')end
	print('Anchors: '..#fixtures.cases..' native layouts, '..comparisons..' geometry comparisons, '..mutations..' retained mutations and '..#fixtures.syntax..' syntax outcomes passed')
end
