--!strict
return function(Parser,Node,Style,Computed,Declarations,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
	local Area=require('CSS/PositionArea');local Dirty=require('Layout/DirtyLayout')
	local allocations=0;local function create(class,parent,props)allocations+=1;local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent;function gui:Destroy()self.Destroyed=true end;return gui end
	local renderer=loadRenderTree({create=create,modifier=create})
	local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=#text*size/2,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
	local compared=0
	local cases=table.clone(reference.cases);for _,case in reference.fallbacks or{}do table.insert(cases,case)end
	for _,case in cases do
		local document=Parser.parseDocument(case.html);local tree=renderer.build(document,{AbsoluteSize=Vector2.new(800,600)},error);tree.ViewportHeight=600
		local tip=Node.findById(document,'tip');local surface,identity,count
		for stepIndex,step in case.steps or{{}}do
		local targets
		if step.left~=nil then local anchor=Node.findById(document,'anchor');anchor.Attributes.style='left:'..step.left..'px;top:'..step.top..'px';local _,items=tree:ApplyDOMChanges({[anchor]={Attributes={style=true}}});targets=items end
		Dirty.begin(tree,targets);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
		local box=tree.NodeBoxes[tip];local x,y
		local function visit(owner,left,top)
			if owner.Node==tip then x,y=left,top end
			for _,child in owner.PositioningChildren or owner.Children or{}do if child.Kind~='Words'then visit(child,left+(child.PaintX or child.LayoutX or 0),top+(child.PaintY or child.LayoutY or 0))end end
		end
		visit(tree,0,0)
		local expected=if case.steps then case.expected[stepIndex]else case.expected
		for index,value in {x,y,box.OuterWidth,box.OuterHeight}do assert(math.abs(value-expected.rect[index])<.04,case.name..' state '..stepIndex..' geometry '..index..': '..value..' != '..expected.rect[index])end
		local computed=Computed.read(box.Style,box,{Width=800,Height=600}).Values
		assert(computed['position-area']==expected.area,case.name..' computed area: '..tostring(computed['position-area'])..' != '..expected.area)
		if expected.tries then assert(computed['position-try-fallbacks']==expected.tries and computed['position-try-order']==expected.order,case.name..' computed fallback list/order')end
		if not surface then surface,identity,count=box.Gui,box.Style,allocations end
		Dirty.begin(tree,{});layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
		assert(box.Gui==surface and box.Style==identity and allocations==count,'An area/anchor change reuses its existing surface and style')
		compared+=1
		end
	end
	for _,case in reference.syntaxTries or{}do
		local value=require('CSS/AnchorPosition').shorthand(case.source)
		assert((value~=nil)==case.supported,'Native area fallback grammar: '..case.source)
		local compiled=Style.compile('position-try:'..case.source);local entries=Declarations.parse('position-try:'..case.source)
		if case.supported then
			assert(not compiled.Normal[1].Error and Declarations.serialize(entries)=='position-try: '..case.declared..';','Canonical area fallback declaration: '..case.source..': '..Declarations.serialize(entries)..' != '..case.declared)
			local node=Node.element('div',{style='position-try:'..case.source});local computed=Computed.read(Style.resolve(node,{},error),nil,{Width=800,Height=600}).Values
			assert(computed['position-try-fallbacks']==case.fallbacks and computed['position-try-order']==case.order,'Computed area fallback serialization: '..case.source..': '..computed['position-try-fallbacks']..' != '..case.fallbacks)
		else assert(compiled.Normal[1].Error and #entries==0,'Invalid area fallback does not enter CSSOM/cascade')end
	end
	for _,case in reference.syntax do
		local value=Area.parse(case.source)
		assert((value~=nil)==case.supported,'Native area grammar: '..case.source)
		local compiled=Style.compile('position-area:'..case.source);local entries=Declarations.parse('position-area:'..case.source)
		if case.supported then
			assert(not compiled.Normal[1].Error and value==case.declared and entries[1].Value==case.declared,'Canonical area declaration: '..case.source..': '..tostring(value)..' != '..case.declared)
			assert(Area.serialize(value,true)==case.computed,'Computed logical area serialization: '..case.source..': '..tostring(Area.serialize(value,true))..' != '..case.computed)
		else assert(compiled.Normal[1].Error and #entries==0,'Invalid area does not silently enter CSSOM/cascade')end
	end
	print('Position areas: '..compared..' native physical/logical/self-writing-mode/sizing/inset/alignment geometries, '..#reference.syntax..' area and '..#(reference.syntaxTries or{})..' fallback syntax/serialization cases and retained surfaces passed')
end
