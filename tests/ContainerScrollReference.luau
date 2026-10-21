return function(Container,fixture,Parser,Node,Style,loadRenderTree,loadWordLayout,loadBlockLayout,Dirty,Viewport,Scroll)
 local fixtureElement=require('DOM/Node').element
	local allocations=0
	local function create(class,parent,props)local gui=table.clone(props);gui.ClassName=class;gui.Parent=parent;gui.Destroy=function()end;allocations+=1;return gui end
	local renderer=loadRenderTree({create=create,modifier=create})
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*size/2,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local block=loadBlockLayout(overrides)
	local comparisons,deviations=0,0;local trees={}
	for _,scene in fixture.cases do
		local group=scene.scenario..scene.direction;local entry=trees[group]
		if not entry then
			local portQuery=scene.scenario=='scrollable'or scene.scenario=='relative'
			local content=if portQuery then '<div id="target"><div id="paint"></div><div style="width:400px;height:300px"></div></div>'elseif scene.scenario=='sticky'then '<div style="height:40px"></div><div id="target"><div id="paint"></div></div><div style="height:300px"></div>'else '<div id="one"><div id="paint"></div></div><div id="two"></div><div id="three"></div>'
			local css='html,body{margin:0}#port{width:200px;height:100px;overflow:auto;direction:'..scene.direction..'}#paint{color:red;height:0}'
			css..=if portQuery then '#port{container-type:scroll-state}@container scroll-state(scrollable:top){#paint{color:blue}}'elseif scene.scenario=='sticky'then '#target{container-type:scroll-state;position:sticky;top:0;height:20px}@container scroll-state(stuck:top){#paint{color:blue}}'else '#port{scroll-snap-type:y mandatory}#port>div{container-type:scroll-state;height:100px;scroll-snap-align:start}@container scroll-state(snapped:y){#paint{color:blue}}'
			local doc=Parser.parseDocument('<!doctype html><style>'..css..'</style><div id="port">'..content..'</div>')
			local tree=renderer.build(doc,{},error);Dirty.begin(tree,nil);block.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
			entry={Tree=tree,Doc=doc,Port=tree.NodeBoxes[Node.findById(doc,'port')],Paint=tree.NodeBoxes[Node.findById(doc,'paint')]};trees[group]=entry
			entry.Root={AbsoluteSize=Vector2.new(800,600),CanvasPosition=Vector2.new(0,0)};Viewport.update(tree,entry.Root)
			entry.PaintGUI=entry.Paint.Gui;entry.Allocations=allocations
		end
		local tree,port=entry.Tree,entry.Port;local gui=port.ScrollGui
		gui.AbsoluteWindowSize=Vector2.new(scene.clientWidth,scene.clientHeight);gui.AbsoluteCanvasSize=Vector2.new(scene.scrollWidth,scene.scrollHeight)
		-- Native RTL uses a negative origin; these reference frames provide its
		-- equivalent physical offset explicitly instead of claiming the engine's
		-- entire native RTL scroll-origin implementation is covered here.
		local x=scene.scrollLeft;if scene.direction=='rtl'then x=scene.scrollWidth-scene.clientWidth+x end
		local previous=gui.CanvasPosition;gui.CanvasPosition=Vector2.new(x,scene.scrollTop)
		if scene.scenario=='relative'and scene.requested~=0 then tree:RecordRelativeScroll(port.Node,0,scene.scrollTop-previous.Y)end
		Viewport.update(tree,entry.Root,port)
		local _,layoutNeeded=tree:RefreshContainerStates();assert(not layoutNeeded,'Scroll-state color queries must stay on the paint path')
		for _,target in scene.targets do
			local owner=if scene.scenario=='scrollable'or scene.scenario=='relative'then port else tree.NodeBoxes[Node.findById(entry.Doc,target.id)]
			local environment={Names={},ScrollEligible=true,QueryWritingMode=owner.Style.WritingMode,QueryDirection=owner.Style.Direction,ScrollState=owner.ContainerScrollState}
			for _,probe in target.matches do
				local query=Container.compile(probe.source);local actual=query and Container.matches({query},environment)or false
				local expected=if probe.normativeMatches~=nil then probe.normativeMatches else probe.matches
				assert(actual==expected,group..' '..scene.scrollTop..' '..target.id..' '..probe.source..' expected '..tostring(expected))
				comparisons+=1;if probe.normativeMatches~=nil then deviations+=1 end
			end
		end
		assert(entry.Paint.Gui==entry.PaintGUI and allocations==entry.Allocations,'No GUI allocation/replacement during repeated snapshots')
		assert(not tree:RefreshContainerStates(),'Unchanged post-layout snapshots do not recascade')
	end
	local valid=Style.resolve(fixtureElement('div',{style='display:block;container-type:scroll-state inline-size'}),{},error)
	assert(valid.ContainerType=='inline-size scroll-state')
	local warnings={};local invalid=Style.resolve(fixtureElement('div',{style='display:block;container-type:normal scroll-state'}),{},function(message)table.insert(warnings,message)end)
	assert(invalid.ContainerType=='normal'and #warnings==1)
	local vertical={ScrollEligible=true,QueryWritingMode='vertical-rl',QueryDirection='rtl',ScrollState={stuck={right=true,bottom=true},scrollable={left=true,top=true}}}
	assert(Container.matches({assert(Container.compile('scroll-state((stuck:block-start) and (stuck:inline-start))'))},vertical))
	assert(Container.matches({assert(Container.compile('scroll-state((scrollable:block-end) and (scrollable:inline-end))'))},vertical))
	print('Container scroll states: '..comparisons..' mounted-layout reference comparisons, '..deviations..' explicit native/spec differences; stable snapshots and retained paint passed')
end
