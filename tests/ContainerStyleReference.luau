return function(Container,fixtures,Parser,Node,Stylesheet,Style,loadRenderTree,loadWordLayout,loadBlockLayout,Dirty)
	local comparisons=0
	for _,scene in fixtures.cases do
		local doc=Parser.parseDocument('<!doctype html><style>'..fixtures.registration..'</style>')
		local registry=Stylesheet.collect(doc,error).PropertyRegistry
		local author={Normal={},Important={},PropertyRegistry=registry}
		local parent=Style.resolve({Name='div',Kind='Element',Attributes={style='--theme:light'}},{},error,nil,author)
		local css=fixtures.values..';display:block;font-size:'..scene.fontSize..'px;container-type:'..scene.type
		local style=Style.resolve({Name='div',Kind='Element',Attributes={style=css}},parent,error,nil,author)
		local env={Width=480,Height=200,Names={'card','--card'},QueryFontSize=scene.fontSize,QueryRootFontSize=16,StyleEligible=true,
			WidthEligible=scene.type~='normal',HeightEligible=scene.type=='size',Custom=style.Custom,ParentCustom=parent.Custom,PropertyRegistry=registry,Style=style}
		for _,probe in scene.matches do
			local query=Container.compile(probe.source);local actual=query and Container.matches({query},env)or false
			assert(actual==(if probe.normativeMatches~=nil then probe.normativeMatches else probe.matches),scene.type..' '..scene.fontSize..' '..probe.source..' expected '..tostring(probe.matches))
			comparisons+=1
		end
	end
	local allocations=0
	local function create(class,parent,props)local gui=table.clone(props);gui.Parent=parent;gui.ClassName=class;gui.Destroy=function()end;allocations+=1;return gui end
	local renderer=loadRenderTree({create=create,modifier=create})
	local document=Parser.parseDocument([=[<!doctype html><style>
html,body{margin:0}#container{width:400px;--theme:light}#target{height:20px;color:red}#unrelated{height:20px;background:blue}
@container style(--theme:dark){#target{color:blue}}
@container style(--tokens:a/**/b){#target{background:green}}
</style><div id="container" style="--tokens:a b"><div id="target">Hello</div><div id="unrelated">Stable</div></div>]=])
	local tree=renderer.build(document,{AbsoluteSize={X=800,Y=600}},error)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*size/2,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
	Dirty.begin(tree,nil);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true);tree:RefreshContainerSizes()
	local container=Node.findById(document,'container');local target=tree.NodeBoxes[Node.findById(document,'target')];local unrelated=tree.NodeBoxes[Node.findById(document,'unrelated')]
	local gui,other,count=target.Gui,unrelated.Gui,allocations
	assert(target.Style.Color.R==1 and(not target.Style.Background or target.Style.BackgroundAlpha==0),'Comment boundaries are not manufactured spaces in stylesheet query values')
	container.Attributes.style='--theme:dark;--tokens:a b'
	local changed,needsLayout=tree:RefreshDOMStyles({[container]=true})
	assert(changed and not needsLayout and target.Style.Color.B==1 and target.Gui==gui and unrelated.Gui==other and allocations==count,
		'A normal ancestor is a style-query container: a custom-property change repaints retained children without allocating or laying out')
	assert(not tree:RefreshContainerSizes(),'An already applied custom-property change must not cause another query pass')
	print('Container style queries: '..comparisons..' native comparisons; normal ancestors, computed registrations and retained paint invalidation passed')
end
