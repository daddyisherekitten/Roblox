--!strict
-- Match-parent is a current normative requirement which this Chromium build
-- does not yet parse. Keep raw browser rejection and native equivalent geometry
-- separate; never label the tested lookup algorithm as a native comparison.
return function(Parser,Node,Style,Computed,Declarations,Runtime,Events,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
	assert(reference.supports==false,'Re-evaluate the normative/native split when the capture browser supports match-parent')
	local objects=0
	local function create(class,parent,props)objects+=1;local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,600);function gui:Destroy()self.Destroyed=true end;return gui end
	local renderer=loadRenderTree({create=create,modifier=create})
	local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*size/2,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local Dirty=require('Layout/DirtyLayout')
	local checked=0
	for _,case in reference.cases do
		local doc=Parser.parseDocument(case.html);local tree=renderer.build(doc,{AbsoluteSize=Vector2.new(800,600)},error);tree.ViewportHeight=600
		local probe=Node.findById(doc,'t');local surface,style
		for index,step in case.steps do
			local changes={};for id,css in step.styles or{}do local n=Node.findById(doc,id);n.Attributes.style=css;changes[n]={Attributes={style=true}}end
			local targets;if next(changes)then local _,items=tree:ApplyDOMChanges(changes);targets=items end
			local allocations=objects;Dirty.begin(tree,targets);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
			local expected=case.expected[index]
			assert(expected.native.computed=='normal'and expected.standardAnchor=='match-parent'and expected.deviation,'Raw native unsupported value and standard expectation remain distinct')
			local x,y
			local function visit(box,left,top)
				if box.Node==probe then x,y=left,top end
				for _,child in box.PositioningChildren or box.Children or{}do if child.Kind~='Words'then visit(child,left+(child.PaintX or child.LayoutX or 0),top+(child.PaintY or child.LayoutY or 0))end end
			end
			visit(tree,0,0)
			local box=tree.NodeBoxes[probe];local actual={x,y,box.OuterWidth,box.OuterHeight}
			for k,value in actual do assert(math.abs(value-expected.equivalent.rect[k])<.04,case.name..' state '..index..' geometry '..k..': '..value..' != '..expected.equivalent.rect[k])end
			assert(Computed.read(box.Style,box,{Width=800,Height=600}).Values['position-anchor']=='match-parent','Computed match-parent remains specified; actual target is a separate layout result')
			if index==1 then surface,style=box.Gui,box.Style else assert(box.Gui==surface and box.Style==style and objects==allocations,'Changing the parent default retains child GUI/style and allocations')end
			checked+=1
		end
	end
	-- An anonymous picker follows its originating element's actual default.
	-- A normal/static select has no default, even with an author anchor name.
	local pickerCase=reference.picker
	local pickerDoc=Parser.parseDocument(pickerCase.html);local root=create('Frame',{},{});root.AbsoluteSize=Vector2.new(800,600)
	local pickerTree=renderer.build(pickerDoc,root,error);pickerTree.ViewportHeight=600
	local select=Node.findById(pickerDoc,'s');local page={Alive=true,Root=root}
	local mount=require('Rendering/PickerFragments').new(page,pickerTree,error,{PickerLayout=layout})
	local picker,retained,optionSurfaces
	for index,step in pickerCase.steps do
		select.Attributes.style=step.style;pickerTree:ApplyDOMChanges({[select]={Attributes={style=true}}})
		layout.arrange(pickerTree,800,0,0,function()return true end)
		for box,record in pickerTree.AnchorRegistry.Boxes do
			local gui=if box.ImageItem then box.ImageItem.BoxGui else box.Gui
			gui.AbsolutePosition=Vector2.new(record.X,record.Y);gui.AbsoluteSize=Vector2.new(record.Width,record.Height)
		end
		if not picker then
			picker=mount.MountPicker(select,create('Frame',root,{}),800,function()end);retained=picker.Tree.Gui
			optionSurfaces={};for _,option in select.Children do optionSurfaces[option]=picker.Tree.NodeBoxes[option].Gui end
		end
		picker:Arrange(800,{Positioned=true,ViewportHeight=600,ViewportOrigin=Vector2.new(0,0)})
		local placed=picker.Placement;local wanted=step.equivalentGeometry.rect
		for k,value in {placed.X,placed.Y,picker.Tree.OuterWidth,picker.Tree.OuterHeight}do assert(math.abs(value-wanted[k])<.04,'Originating select default state '..index..' geometry '..k..': '..value..' != '..wanted[k])end
		assert(step.native.anchor=='normal'and picker.Tree.Style.PositionAnchor=='match-parent','Raw browser rejection remains separate from normative picker behavior')
		assert(picker.Tree.Gui==retained,'Changing the originating default retains the actual picker root')
		for option,surface in optionSurfaces do assert(picker.Tree.NodeBoxes[option].Gui==surface and option.Parent==select,'Picker match-parent retains original option DOM and surfaces')end
	end
	picker:Destroy();assert(retained.Destroyed,'Match-parent picker releases its retained surface')
	local parent=Node.element('div',{style='position:absolute;position-anchor:--parent'});local parentStyle=Style.resolve(parent,{},error)
	for _,case in reference.resets do
		local child=Node.element('div',{style=case.css});Node.append(parent,child)
		local resolved=Style.resolve(child,parentStyle,function()end)
		assert(resolved.PositionAnchor==case.anchor,'Normative position reset: '..case.css..': '..tostring(resolved.PositionAnchor)..' != '..case.anchor)
		assert(case.native.computed~=nil,'Raw browser reset state must stay available')
	end
	for _,source in {'match-parent','MATCH-PARENT','m\\61 tch-parent'}do
		local node=Node.element('div',{style='position-anchor:'..source});assert(Style.resolve(node,{},error).PositionAnchor=='match-parent','Shared identifier grammar accepts case/escapes')
		local entries=Declarations.parse('position-anchor:'..source);assert(#entries==1 and entries[1].Value=='match-parent','CSSOM serializes the same parsed identifier')
	end
	for _,source in {'match-parent none','match-parent --a','matchparent','--a match-parent'}do assert(Style.compile('position-anchor:'..source).Normal[1].Error,'Invalid match-parent syntax is rejected')end
	local doc=Parser.parseDocument('<html><head><style id=sheet></style></head><body><div id=target></div></body></html>')
	local tree=renderer.build(doc,{AbsoluteSize=Vector2.new(800,600)},error);tree.ViewportHeight=600
	local function arrange(targets)Dirty.begin(tree,targets);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)end
	arrange()
	local runtime
	runtime=Runtime.new(doc,{Events=Events.new(error),Diagnostic=error,
		ApplyChanges=function(changes)return tree:ApplyDOMChanges(changes)end,
		GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return {Width=800,Height=600}end,
			HasPending=function()return runtime:HasPending()end,Flush=function()local changed,targets=runtime:Flush();if changed then arrange(targets)end end}})
	runtime:Run([=[
		function verify(ok,message){if(!ok)throw new Error(message)}
		let t=document.getElementById('target');
		t.style.positionAnchor='--one';t.style.position='FIXED';
		verify(t.style.position==='fixed'&&t.style.positionAnchor==='normal','CSSOM assignment resets the anchor and canonicalizes position');
		verify(getComputedStyle(t).positionAnchor==='normal','Assignment resets the actual computed anchor');
		t.style.positionAnchor='MATCH-PARENT';
		verify(t.style.positionAnchor==='match-parent'&&getComputedStyle(t).positionAnchor==='match-parent','Setter accepts and serializes the shared match-parent grammar: '+t.style.cssText+' / '+getComputedStyle(t).positionAnchor);
		verify(t.style.removeProperty('position')==='fixed'&&t.style.positionAnchor==='', 'Removing position removes its reset-only subproperty');
		t.style.setProperty('position-anchor','--strong','important');t.style.setProperty('position','absolute');
		verify(t.style.positionAnchor==='normal'&&t.style.getPropertyPriority('position-anchor')==='', 'CSSOM setter replaces the reset subproperty, including old important declarations');
		let sheet=new CSSStyleSheet();sheet.replaceSync('div{position-anchor:--one;position:fixed}');
		let style=sheet.cssRules[0].style;
		verify(style.positionAnchor==='normal'&&style.position==='fixed','Rule CSSOM uses the same reset storage');
		style.positionAnchor='--restored';verify(style.cssText.indexOf('--restored')>=0,'An explicit later longhand is serialized instead of the reset marker');
		style.position='relative';verify(style.positionAnchor==='normal','A later rule setter resets it again');
	]=])
	runtime:Destroy()
	assert(checked==12,'Normative parent geometry coverage changed')
	print('Anchor parent: '..checked..' normative parent/chain/scope/eligibility cases and 4 originating-picker cases against native equivalent geometry, 8 raw/native reset records, shared syntax, CSSOM mutation and retained surfaces passed')
end
