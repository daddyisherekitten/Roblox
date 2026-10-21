return function(Container,Media,fixtures,Parser,Node,loadRenderTree,loadWordLayout,loadBlockLayout,Dirty)
	local comparisons=0
	for _,scene in fixtures.cases do
		local vertical=scene.writingMode~='horizontal-tb';local size=scene.type=='size';local inline=scene.type=='inline-size'
		local env={Width=scene.width,Height=scene.height,Names=scene.names,QueryFontSize=scene.fontSize,QueryWritingMode=scene.writingMode,
			ViewportWidth=scene.viewportWidth,ViewportHeight=scene.viewportHeight,Custom=scene.custom,
			WidthEligible=size or inline and not vertical,HeightEligible=size or inline and vertical}
		for _,probe in scene.matches do
			local query=Container.compile(probe.source)
			local actual=query and Container.matches({query},env)or false
			assert(actual==(if probe.normativeMatches~=nil then probe.normativeMatches else probe.matches),scene.type..' '..scene.writingMode..' '..scene.fontSize..' '..probe.source..' expected '..tostring(probe.matches))
			comparisons+=1
		end
	end
	assert(not Media.matches(assert(Media.compile('(inline-size:480px)')),{Width=480}),'Container-only aliases must not become media features')
	local a={Width=480,Height=200,Names={'card'},WidthEligible=true,HeightEligible=false}
	local b={Width=800,Height=600,Names={'card'},WidthEligible=true,HeightEligible=true}
	assert(Container.matches({assert(Container.compile('card (width:800px) and (height:600px)'))},{Ancestors={a,b}}),
		'All required axes select one eligible ancestor; a nearer partial container is skipped')
	assert(not Container.matches({assert(Container.compile('card (width:480px) and (height:600px)'))},{Ancestors={a,b}}))
	local doc=Parser.parseDocument([=[<!doctype html><html><head><style>
html,body{margin:0}#container{container-type:inline-size;container-name:--card;width:400px;font-size:16px;--limit:300px}
#target{height:20px;color:red}
#variable{height:20px;color:red}
@container --card (inline-size:20em){#target{color:blue}}
@container --card (width>var(--limit)){#variable{color:blue}}
</style></head><body><div id="container"><div id="target">Query</div><div id="variable">Variable</div></div></body></html>]=])
	local factory={create=function(_,_,props)return table.clone(props)end,modifier=function(_,_,props)return table.clone(props)end}
	local renderer=loadRenderTree(factory);local tree=renderer.build(doc,{AbsoluteSize={X=800,Y=600}},error)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*size/2,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local block=loadBlockLayout(overrides)
	local function layout(items)local stats=Dirty.begin(tree,items);block.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true);return stats end
	layout(nil);tree:RefreshContainerSizes()
	local parent=assert(Node.findById(doc,'container'));local target=assert(Node.findById(doc,'target'));local box=tree.NodeBoxes[target];local gui=box.Gui
	assert(box.Style.Color.R==1)
	parent.Attributes.style='font-size:20px'
	local _,needed,items=tree:RefreshDOMStyles({[parent]=true});assert(needed);layout(items)
	local _,queryLayout=tree:RefreshContainerSizes()
	assert(not queryLayout and box.Style.Color.B==1 and box.Gui==gui,
		'Changing query font size invalidates a fixed-width container and repaints its existing child')
	assert(not tree:RefreshContainerSizes(),'Stable query font/axis/size does not recascade again')
	local variable=tree.NodeBoxes[Node.findById(doc,'variable')];local variableGUI=variable.Gui;assert(variable.Style.Color.B==1)
	parent.Attributes.style='font-size:20px;--limit:500px'
	local variableChanged,variableLayout=tree:RefreshDOMStyles({[parent]=true})
	assert(variableChanged and not variableLayout and variable.Style.Color.R==1 and variable.Gui==variableGUI,
		'Changing a size-query threshold without changing the size repaints without a layout call or replacement')
	print('Container queries: '..comparisons..' native size/axis/font/name outcomes; single-ancestor selection and actual font invalidation passed')
end
