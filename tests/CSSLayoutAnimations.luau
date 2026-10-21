--!strict
return function(Parser,Node,loadRenderTree,loadWordLayout,loadBlockLayout,Dirty,HTMLAnimations,AnimationValues,BoxTransform,fontTransitions,colorTransitions,cssDOMFixtures)
	local factory={}
	function factory.create(class,parent,props)
		local gui=table.clone(props);gui.ClassName=class;gui.Parent=parent;gui.AnchorPoint=gui.AnchorPoint or Vector2.new(0,0);gui.Position=gui.Position or UDim2.fromOffset(0,0)
		gui.BackgroundColor3=gui.BackgroundColor3 or Color3.new(1,1,1);gui.BackgroundTransparency=gui.BackgroundTransparency or 1
		function gui:Destroy()self.Destroyed=true;self.Parent=nil end
		return gui
	end
	factory.modifier=factory.create
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*size*.5,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local renderer=loadRenderTree(factory);local layout=loadBlockLayout(overrides)
	local function fixture(css,prepare,clockStep)
		local doc=Parser.parseDocument('<html><head><style>'..css..'</style></head><body><div id="before" style="height:10px">Before</div><div id="box"><input id="field" value="kept"></div><div id="after" style="height:20px">After</div></body></html>')
		if prepare then prepare(doc)end
		local tree=renderer.build(doc,{},error);local time=0;local clockReads=0;local frame;local cleanups={};local pending={};local requests=0;local layouts=0
		local page={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(cleanups,fn)end}
		function page:RequestAnimationLayout(box)pending[box]=true;requests+=1 end
		local function arrange(items)layouts+=1;Dirty.begin(tree,items);layout.arrange(tree,400,0,0,function()return true end);Dirty.finish(tree,true)end
		arrange()
		local runtime=HTMLAnimations.start(page,tree,error,{Clock=function()local current=time+clockReads*(clockStep or 0);clockReads+=1;return current end,RunService={Heartbeat={Connect=function(_,fn)frame=fn;return {Disconnect=function()frame=nil end}end}}},20)
		local function flush()
			for i=1,5 do if not next(pending)then return end;local items=pending;pending={};arrange(items);runtime:AfterLayout()end
			assert(not next(pending),'Layout animation publication must converge without resampling feedback')
		end
		runtime:AfterLayout();flush()
		local box=tree.NodeBoxes[Node.findById(doc,'box')];local input;for _,control in tree.Controls do if control.Node==Node.findById(doc,'field')then input=control;break end end;assert(input)
		local value={Tree=tree,Document=doc,Box=box,Input=input,Runtime=runtime,Page=page,Flush=flush,Pending=function()return next(pending)~=nil end,Requests=function()return requests end,Layouts=function()return layouts end}
		function value:At(t)time=t;clockReads=0;assert(frame,'An active effect must have one frame callback');frame();flush()end
		function value:Rules(cssText)
			local style=doc.Children[1].Children[1].Children[1];style.Children[1].Text=cssText
			local needed,items=tree:ApplyDOMChanges({[style]={Stylesheet=true,Text=true}})
			if needed then arrange(items)end;runtime:AfterLayout();flush()
		end
		function value:Change(changes)
			local needed,items=tree:ApplyDOMChanges(changes)
			if needed then arrange(items)end;runtime:AfterLayout();flush()
			return needed
		end
		function value:AssertIdle(label)assert(frame==nil,label..': paused/removed CSS effects retain no native frame subscription')end
		function value:Close()for i=#cleanups,1,-1 do cleanups[i]()end;assert(frame==nil,'Cleanup disconnects the frame callback');assert(not next(runtime.Snapshots)and not next(runtime.Pending)and not next(runtime.AnimationRecords)and not next(runtime.Transitions)and not next(runtime.CompletedTransitions)and not next(runtime.OwnedCSSRecords),'Cleanup releases animation records, owning elements and transition snapshots')end
		return value
	end
	local keyframeNative,keyframeNormative=0,0
	for _,reference in cssDOMFixtures and cssDOMFixtures.cases or{}do
		if not reference.paintSamples then continue end
		local effect=fixture(reference.css..'#box{width:100px;height:50px;animation-play-state:running}#field{width:20px;height:10px}')
		local boxGui,inputGui,afterCache=effect.Box.Gui,effect.Input.Item.Gui,effect.Tree.NodeBoxes[Node.findById(effect.Document,'after')].CachedLayout
		inputGui.Text='live selection';inputGui.CursorPosition=4;inputGui.SelectionStart=2
		local layouts,requests=effect.Layouts(),effect.Requests()
		local expected=reference.enginePaintSamples or reference.paintSamples
		local function matches(sample)
			local opacity=if effect.Box.OpacityGroup then 1-effect.Box.OpacityGroup.Gui.GroupTransparency else effect.Box.Style.Opacity
			assert(math.abs(opacity-tonumber(sample.opacity))<.00001,reference.name..': actual CSS opacity '..tostring(opacity)..' ~= '..sample.opacity)
			local x,y=0,0
			if sample.transform~='none'then local values={};for raw in sample.transform:match('%((.*)%)'):gmatch('[^, ]+')do table.insert(values,tonumber(raw))end;x,y=values[5],values[6]end
			local surface=BoxTransform.target(effect.Box)
			local actualX=if effect.Box.TransformApplied then effect.Box.TransformPositionX-effect.Box.TransformBaseX-surface.AnchorPoint.X*effect.Box.OuterWidth else 0
			local actualY=if effect.Box.TransformApplied then effect.Box.TransformPositionY-effect.Box.TransformBaseY-surface.AnchorPoint.Y*effect.Box.OuterHeight else 0
			assert(math.abs(actualX-x)<.00001 and math.abs(actualY-y)<.00001,reference.name..': real CSS transform '..tostring(actualX)..','..tostring(actualY)..' ~= '..tostring(x)..','..tostring(y))
			assert(effect.Box.Gui==boxGui and effect.Input.Item.Gui==inputGui and inputGui.Text=='live selection'and inputGui.CursorPosition==4 and inputGui.SelectionStart==2,reference.name..': keyframe sampling retains the box and real native editor selection')
			assert(effect.Layouts()==layouts and effect.Requests()==requests and effect.Tree.NodeBoxes[Node.findById(effect.Document,'after')].CachedLayout==afterCache,reference.name..': opacity/transform keyframes retain unrelated flow and request no layout '..tostring(effect.Layouts())..'/'..tostring(layouts)..' requests '..tostring(effect.Requests())..'/'..tostring(requests)..' cache '..tostring(effect.Tree.NodeBoxes[Node.findById(effect.Document,'after')].CachedLayout==afterCache))
		end
		for _,sample in expected.values do
			effect:At(sample.time/1000)
			matches(sample);effect.Runtime:AfterLayout();effect.Flush();matches(sample)
		end
		effect.Box.Node.Attributes.style='animation-name:none'
		effect:Change({[effect.Box.Node]={Attributes={style=true}}})
		-- Removing authored animation metadata may use the general recascade
		-- path; animation frames themselves must never arrange paint-only flow.
		layouts=effect.Layouts();matches(expected.restored);effect:AssertIdle(reference.name);effect:Close()
		if reference.enginePaintSamples then keyframeNormative+=1 else keyframeNative+=1 end
	end
	assert(keyframeNative==5 and keyframeNormative==3,'All frozen CSS-keyframe references execute through the native CSS paint path')
	for _,reference in colorTransitions and colorTransitions.cases or{}do
		local color=fixture(reference.css..'#field{color:inherit;width:40px;height:10px}',function(doc)Node.append(Node.findById(doc,'box'),Node.element('div',{id='leaf'}))end)
		local leaf=color.Tree.NodeBoxes[Node.findById(color.Document,'leaf')]
		local boxGui,leafGui,fieldGui,outlineGui=color.Box.Gui,leaf.Gui,color.Input.Item.Editor,color.Box.Outline.Gui
		fieldGui.Text='kept';fieldGui.CursorPosition=3;fieldGui.SelectionStart=1
		local before=color.Layouts();local requests=color.Requests()
		color.Box.Node.Attributes.class='active';assert(not color:Change({[color.Box.Node]={Attributes={class=true}}}),'A color transition starts without layout')
		color:At(1)
		local adapter,animation
		if reference.waapi then
			adapter=HTMLAnimations.scriptAdapter(color.Page,color.Tree,error);animation={}
			adapter:Apply(color.Box.Node,{{ComputedOffset=0,Easing='linear',Composite='auto',Values={color='rgb(10,20,30)'}},{ComputedOffset=1,Easing='linear',Composite='auto',Values={color='rgb(30,40,50)'}}},{progress=.5,Phase='active',IsCurrent=true},animation,'replace')
		end
		local function nearColor(actual,alpha,source,label)
			local channels={};for value in source:gmatch('[%d.]+')do table.insert(channels,tonumber(value))end
			assert(actual and math.abs(actual.R*255-channels[1])<.001 and math.abs(actual.G*255-channels[2])<.001 and math.abs(actual.B*255-channels[3])<.001 and math.abs((alpha or 1)-(channels[4]or 1))<.001,label..' agrees with held native color')
		end
		local function matches(sample)
			local style=color.Box.Style
			nearColor(style.Color,style.ColorAlpha,sample.colors.color,'foreground')
			nearColor(style.Background or Color3.new(0,0,0),if style.Background then style.BackgroundAlpha else 0,sample.colors['background-color'],'background')
			for side,name in {'top','right','bottom','left'}do local edge=style.BorderSides[side];nearColor(edge.Color,edge.Alpha,sample.colors['border-'..name..'-color'],name..' border')end
			nearColor(style.OutlineColor,style.OutlineColorAlpha,sample.colors['outline-color'],'outline')
			nearColor(if style.DecorationColor and style.DecorationColor~='currentcolor'then style.DecorationColor else style.Color,if style.DecorationColor and style.DecorationColor~='currentcolor'then style.DecorationColorAlpha else style.ColorAlpha,sample.colors['text-decoration-color'],'decoration')
			nearColor(leaf.Style.Color,leaf.Style.ColorAlpha,sample.leaf,'retained descendant')
			nearColor(fieldGui.TextColor3,1-fieldGui.TextTransparency,sample.leaf,'native editor')
			assert(color.Box.Gui==boxGui and leaf.Gui==leafGui and color.Input.Item.Editor==fieldGui and color.Box.Outline.Gui==outlineGui and fieldGui.Text=='kept'and fieldGui.CursorPosition==3 and fieldGui.SelectionStart==1,'Color transitions retain rendered boxes, outline, native editor and selection')
			assert(color.Layouts()==before and color.Requests()==requests,'Color transition samples never request layout')
		end
		matches(reference.values[1]);color.Runtime:AfterLayout();color.Flush();matches(reference.values[1])
		if adapter then
			local frames={{ComputedOffset=0,Easing='linear',Composite='auto',Values={color='rgb(10,20,30)'}},{ComputedOffset=1,Easing='linear',Composite='auto',Values={color='rgb(30,40,50)'}}}
			local entries=adapter:SampleCommit(color.Box.Node,{{Animation=animation,Frames=frames,Timing={progress=.5,Phase='active'},Composite='replace'}},{Frames=frames,Properties={color=true}})
			assert(entries and entries[1].Value==reference.values[2].committed,'Color commit samples its own WAAPI effect under the held CSS transition')
			adapter:Release(color.Box.Node,animation);adapter:Destroy()
			-- Native commit + authored transition retarget is preserved in this
			-- fixture, but its complete retarget timing is still an open case.
		else
			color.Box.Node.Attributes.class=nil;assert(not color:Change({[color.Box.Node]={Attributes={class=true}}}),'Color reversal remains paint-only')
			for _,duration in reference.values[2].durations do assert(color.Runtime.Transitions[color.Box].Properties[duration[1]].Duration==duration[2]/1000,'Color reversal preserves native shortened duration')end
			color:At(1.5);matches(reference.values[2]);color:At(2)
			assert(not color.Box.AnimationColorAuthor and(not color.Tree.AnimationColorOverrides or next(color.Tree.AnimationColorOverrides)==nil),'Completed color transitions release their override and author snapshots')
		end
		color:Close()
		assert(not color.Box.AnimationColorAuthor and not color.Box.AnimationColorInherited and(not color.Tree.AnimationColorOverrides or next(color.Tree.AnimationColorOverrides)==nil),'Disposed color transitions release every retained author/parent snapshot')
	end
	for _,reference in fontTransitions and fontTransitions.cases or{}do
		local font=fixture(reference.css..'#field{position:absolute;font-size:inherit;width:2em;height:1em;padding:0;border:0}',function(doc)
			Node.append(Node.findById(doc,'box'),Node.element('div',{id='leaf'}))
		end)
		local leaf=font.Tree.NodeBoxes[Node.findById(font.Document,'leaf')]
		local boxGui,leafGui,inputGui=font.Box.Gui,leaf.Gui,font.Input.Item.Editor
		inputGui.Text='live';inputGui.CursorPosition=3;inputGui.SelectionStart=1
		font.Box.Node.Attributes.class='active';font:Change({[font.Box.Node]={Attributes={class=true}}})
		local transitions=font.Runtime.Transitions[font.Box]
		assert(transitions and transitions.Properties['font-size']and transitions.Properties['line-height'],'Font metric transitions target both retained channels')
		local function matches(sample)
			assert(math.abs(font.Box.Style.FontSize-tonumber(sample.font:match('[%d.]+')))<.001,'Sampled CSS font agrees with native transition')
			local line=font.Box.Style.LineHeight;local pixels=if line.Kind=='number'then line.Value*font.Box.Style.FontSize else line.Value
			assert(math.abs(pixels-tonumber(sample.line:match('[%d.]+')))<.001,'Typed line-height transition agrees with native '..reference.name)
			assert(math.abs(leaf.OuterWidth-sample.width)<.001 and math.abs(leaf.OuterHeight-sample.height)<.001,'Transition refreshes real descendant em geometry')
			assert(font.Box.Gui==boxGui and leaf.Gui==leafGui and font.Input.Item.Editor==inputGui and inputGui.Text=='live'and inputGui.CursorPosition==3 and inputGui.SelectionStart==1,'Font transitions retain descendant and native editor identities/state')
		end
		font:At(1);matches(reference.values[1])
		local start=font.Runtime.Transitions[font.Box].Properties['font-size'].Start;local count=font.Requests();local before=font.Layouts()
		font.Runtime:AfterLayout();font.Flush()
		assert(font.Requests()==count and font.Layouts()==before and font.Runtime.Transitions[font.Box].Properties['font-size'].Start==start,'Held font sample converges without restarting its transition or requesting another layout')
		font.Box.Node.Attributes.class=nil;font:Change({[font.Box.Node]={Attributes={class=true}}})
		for _,duration in reference.values[2].durations do assert(font.Runtime.Transitions[font.Box].Properties[duration[1]].Duration==duration[2]/1000,'Font metric reversal uses the native shortened duration')end
		font:At(1.5);matches(reference.values[2]);font:At(2)
		assert(not font.Runtime.Transitions[font.Box]and not font.Box.AnimationMetricAuthor and(not font.Tree.AnimationMetricOverrides or next(font.Tree.AnimationMetricOverrides)==nil),'Completed font transition releases metric overrides and clock work')
		font:Close()
	end
	local fontRemoval=fixture('#box{font-size:20px;height:20px;animation:fontRemoval 100s linear -50s both paused}@keyframes fontRemoval{from{font-size:20px}to{font-size:40px}}')
	local retiredFont=fontRemoval.Box;local parent=retiredFont.Node.Parent
	Node.removeChild(parent,retiredFont.Node);fontRemoval:Change({[parent]={Children=true}})
	assert(not retiredFont.AnimationMetricAuthor and not retiredFont.AnimationMetricUnderlyingStyle and next(fontRemoval.Tree.AnimationMetricOverrides)==nil,'Removing a CSS font target releases its metric snapshots and overrides')
	fontRemoval:Close()
	local containing=fixture('#box{width:200px;height:100px;margin-left:50px}#field{position:fixed;left:10px;top:15px;width:20px;height:10px;padding:0;border:0}#box.active{animation:move 2s linear 1s}@keyframes move{from{translate:none}to{translate:40px}}')
	local fieldBox=containing.Tree.NodeBoxes[Node.findById(containing.Document,'field')]
	assert(fieldBox and not fieldBox.FixedContainingBox,'Unanimated CSS fixed input uses the viewport containing block')
	local nativeField=containing.Input.Item.Gui;nativeField.Text='live';nativeField.CursorPosition=3;nativeField.SelectionStart=1
	local originalContainingGui=containing.Box.Gui;local layoutsBefore,requestsBefore=containing.Layouts(),containing.Requests()
	containing.Box.Node.Attributes.class='active';local authorLayout=containing:Change({[containing.Box.Node]={Attributes={class=true}}})
	assert(fieldBox.FixedContainingBox==containing.Box and containing.Layouts()==layoutsBefore+(if authorLayout then 1 else 0)+1 and containing.Requests()==requestsBefore+1,'CSS before-phase transform effect adds exactly one local positioning publication after its author-style batch')
	local enteredLayouts,enteredRequests=containing.Layouts(),containing.Requests()
	for _,time in {.5,1,1.5,2,2.5}do containing:At(time)end
	assert(containing.Layouts()==enteredLayouts and containing.Requests()==enteredRequests,'CSS delay and ordinary transform samples leave flow layout intact')
	containing:At(3)
	assert(not fieldBox.FixedContainingBox and containing.Layouts()==enteredLayouts+1 and containing.Requests()==enteredRequests+1,'Unfilled CSS completion releases its fixed block exactly once')
	assert(containing.Box.Gui==originalContainingGui and containing.Input.Item.Gui==nativeField and nativeField.Text=='live'and nativeField.CursorPosition==3 and nativeField.SelectionStart==1,'CSS effect lifecycle retains input, selection and original container GUI')
	containing:Close()
	local automatic=fixture('#box{width:200px;height:0px;overflow:clip;interpolate-size:allow-keywords;transition:height 2s linear}#box.active{height:auto}input{width:40px;height:60px}')
	local retainedAuto=automatic.Box.Gui;automatic.Box.Node.Attributes.class='active';automatic:Change({[automatic.Box.Node]={Attributes={class=true}}})
	local endHeight=automatic.Runtime.Transitions[automatic.Box].Properties.height.To.Value;assert(endHeight>0,'Auto endpoint measures the original content')
	automatic:At(1);assert(math.abs(automatic.Box.Style.Height.Value-endHeight/2)<.001 and automatic.Box.Gui==retainedAuto,'Intrinsic transition interpolates through retained local layout')
	automatic:At(2);assert(automatic.Box.Style.Height==nil and automatic.Box.Gui==retainedAuto,'Auto author sizing is restored after completion')
	automatic.Box.Node.Attributes.class=nil;automatic:Change({[automatic.Box.Node]={Attributes={class=true}}});automatic:At(3)
	assert(math.abs(automatic.Box.Style.Height.Value-endHeight/2)<.001,'Auto to numeric closes through the same intrinsic endpoint');automatic:Close()
	local individual=fixture('#box{width:200px;height:100px;transform-origin:0 0;translate:10px 20px;rotate:0deg;scale:1;transform:translateX(0);transition:translate 2s linear,rotate 2s linear,scale 2s linear,transform 2s linear}#box.active{translate:30px 40px;rotate:180deg;scale:3;transform:translateX(10px)}#field{position:absolute}')
	local keptIndividual=individual.Box.Gui;local keptInput=individual.Input.Item.Gui
	individual.Box.Node.Attributes.class='active';individual:Change({[individual.Box.Node]={Attributes={class=true}}})
	local initialLayouts=individual.Layouts()
	local running=individual.Runtime.Transitions[individual.Box]
	assert(running and running.Properties.translate and running.Properties.rotate and running.Properties.scale and running.Properties.transform,'Individual transforms have independent CSS transition channels')
	individual:At(1);local pose=BoxTransform.resolve(individual.Box,individual.Box.TransformOverride)
	assert(math.abs(pose.X-20)<.001 and math.abs(pose.Y-40)<.001 and math.abs(pose.Rotation-90)<.001 and math.abs(pose.Scale-2)<.001,'Individual midpoint orders translate, rotate, scale then the simultaneous transform list')
	assert(individual.Box.Gui==keptIndividual and individual.Input.Item.Gui==keptInput and individual.Layouts()==initialLayouts,'Individual transition frames retain controls and do not arrange normal flow')
	individual.Box.Node.Attributes.class=nil;individual:Change({[individual.Box.Node]={Attributes={class=true}}})
	assert(individual.Runtime.Transitions[individual.Box].Properties.translate.Duration==1,'Individual reversal shares the native shortening factor')
	individual:At(1.5);assert(individual.Box.SampledIndividualTransforms.translate.Operation.X.Value==15,'Interrupted reverse begins at the painted individual value')
	individual:At(2);assert(not individual.Runtime.Transitions[individual.Box],'Finished individual transitions release their frame work');individual:Close()
	local separate=fixture('#box{width:200px;height:100px;translate:10px;transform:translateX(5px);transition:transform 2s linear}#box.active{translate:30px}#field{position:absolute}')
	separate.Box.Node.Attributes.class='active';separate:Change({[separate.Box.Node]={Attributes={class=true}}})
	assert(not separate.Runtime.Transitions[separate.Box],'Changing translate cannot spuriously start transition:transform');separate:Close()
	for _,mode in {'replace','add','accumulate'}do
		local cssIndividual=fixture('@keyframes individual{from{translate:0px 0px;rotate:0deg;scale:1}to{translate:40px 20px;rotate:60deg;scale:3}}#box{width:200px;height:100px;translate:10px 20px;rotate:30deg;scale:2;animation:individual 100s linear -50s both paused;animation-composition:'..mode..'}#field{position:absolute}')
		local sample={};local author={translate=true,rotate=true,scale=true};assert(cssIndividual.Runtime:SampleUnderlying(cssIndividual.Box.Node,sample,author),'Individual CSS lower effects are available to the script stack')
		assert(sample.translate.Operation.X.Value==(if mode=='replace'then 20 else 30)and sample.rotate.Operation.Value==(if mode=='replace'then 30 else 60)and sample.scale.Operation.Value==(if mode=='replace'then 2 else 4),'Individual CSS composition is independent from transform-list composition')
		local before=cssIndividual.Layouts();local surface=cssIndividual.Box.Gui;cssIndividual.Runtime:AfterLayout();cssIndividual.Flush()
		assert(cssIndividual.Layouts()==before and cssIndividual.Box.Gui==surface,'Paused individual CSS effects retain their native surface without layout');cssIndividual:Close()
	end
	local lower=fixture('@keyframes low{from{translate:0px;rotate:0deg;scale:1}to{translate:40px;rotate:60deg;scale:3}}#box{width:200px;height:100px;animation:low 100s linear -50s both paused}#field{position:absolute}')
	local upper=HTMLAnimations.scriptAdapter(lower.Page,lower.Tree,error);local effect={AnimationState={Sequence=1}}
	local frames={{ComputedOffset=0,Easing='linear',Values={translate='0px',rotate='0deg',scale='1'}},{ComputedOffset=1,Easing='linear',Values={translate='20px',rotate='20deg',scale='2'}}}
	local layoutBefore=lower.Layouts();upper:Apply(lower.Box.Node,frames,{progress=.5,currentIteration=0,Phase='active'},effect,'add','replace')
	assert(lower.Box.SampledIndividualTransforms.translate.Operation.X.Value==30 and lower.Box.SampledIndividualTransforms.rotate.Operation.Value==40 and lower.Box.SampledIndividualTransforms.scale.Operation.Value==3,'Script individual composition uses the lower CSS properties once')
	local committed=upper:SampleCommit(lower.Box.Node,{{Animation=effect,Frames=frames,Timing={progress=.5,currentIteration=0,Phase='active'},Composite='add',IterationComposite='replace'}},{Frames=frames,Properties={translate=true,rotate=true,scale=true}})
	local values={};for _,entry in committed do values[entry.Name]=entry.Value end
	assert(values.translate=='30px'and values.rotate=='40deg'and values.scale=='3','Individual commit samples the same CSS/script stack as paint')
	upper:Release(lower.Box.Node,effect)
	assert(lower.Box.SampledIndividualTransforms.translate.Operation.X.Value==20 and lower.Box.SampledIndividualTransforms.rotate.Operation.Value==30 and lower.Box.SampledIndividualTransforms.scale.Operation.Value==2,'Cancellation immediately exposes held lower CSS transforms')
	assert(lower.Layouts()==layoutBefore,'Combined paint and commit do not request normal flow layout');upper:Destroy();lower:Close()
	-- Captured CSS cases in animation-intrinsic-native.json use the same 120px
	-- block content and a paused midpoint. No probe may rewrite native controls.
	for _,case in {
		{'0px','auto','linear','replace',60},
		{'auto','20px','linear','replace',70},
		{'0px','auto','linear','add',140},
		{'0px','auto','linear','accumulate',140},
		{'0px','auto','linear(0,1.5,1)','replace',180},
		{'auto','20px','linear(0,-0.5,1)','replace',170},
	}do
		local css='@keyframes intrinsic{from{height:'..case[1]..'}to{height:'..case[2]..'}}#box{width:200px;height:80px;interpolate-size:allow-keywords;animation:intrinsic 100s '..case[3]..' -50s both paused;animation-composition:'..case[4]..'}#field{position:absolute;visibility:hidden}'
		local content
		local sample=fixture(css,function(doc)
			content=Node.element('div',{style='display:block;width:20px;height:120px;margin:0;padding:0'});Node.append(Node.findById(doc,'box'),content)
		end)
		local kept=sample.Box.Gui;local keptControl=sample.Input.Item.Gui
		assert(math.abs(sample.Box.OuterHeight-case[5])<.001,'CSS intrinsic midpoint matches captured native '..case[4]..' / '..case[3])
		local requests=sample.Requests();sample.Runtime:AfterLayout();sample.Flush()
		assert(sample.Requests()==requests,'Stable natural endpoint does not feed another layout publication')
		if case[1]=='0px'and case[3]=='linear'and case[4]=='replace'then
			content.Attributes.style='display:block;width:20px;height:200px;margin:0;padding:0';sample:Change({[content]={Attributes={style=true}}})
			assert(sample.Box.OuterHeight==100,'A paused CSS intrinsic effect follows a live natural content change')
			sample.Box.Node.Attributes.style='interpolate-size:numeric-only';sample:Change({[sample.Box.Node]={Attributes={style=true}}})
			assert(sample.Box.OuterHeight==100,'Interpolation allowance is captured at animation start')
		end
		assert(sample.Box.Gui==kept and sample.Input.Item.Gui==keptControl,'Intrinsic keyframes retain surfaces and controls');sample:Close()
	end
	local rules='@keyframes grow{from{width:100px;height:30px;padding:0px;margin-top:0px}to{width:200px;height:70px;padding:10px;margin-top:20px}}#box{box-sizing:content-box;width:90px;height:20px;animation:grow 2s linear both}input{width:40px;height:12px}'
	local f=fixture(rules);local original=f.Box.Gui;local fieldGui=f.Input.Item.Gui;local before=f.Tree.NodeBoxes[Node.findById(f.Document,'before')];local after=f.Tree.NodeBoxes[Node.findById(f.Document,'after')];local beforeY=before.LayoutY
	f.Input.Value='live value';fieldGui.Text='live value';fieldGui.CursorPosition=4;fieldGui.SelectionStart=2
	f:At(1)
	assert(f.Box.Style.Width.Value==150 and f.Box.Style.Height.Value==50,'CSS keyframes interpolate both layout dimensions in one effect')
	assert(f.Box.Style.Padding[1]==5 and f.Box.Style.Margin[1]==10,'Shorthand padding and a margin side participate in the same local layout stack')
	assert(f.Box.OuterWidth==160 and after.LayoutY>=f.Box.LayoutY+f.Box.OuterHeight,'Native geometry and following flow reflect the animated border box')
	assert(before.LayoutY==beforeY and f.Box.Gui==original and f.Input.Item.Gui==fieldGui and fieldGui.Text=='live value'and fieldGui.CursorPosition==4 and fieldGui.SelectionStart==2,'Animation retains preceding geometry, native inputs, value and selection')
	local started=f.Runtime.Animations[1].Start
	f:Rules(rules:gsub('width:200px','width:300px'))
	assert(f.Runtime.Animations[1].Start==started and f.Box.Style.Width.Value==200,'Editing an active keyframe preserves its clock and immediately samples the replacement')
	f:At(2);assert(f.Box.Style.Width.Value==300 and #f.Runtime.Animations==0,'Forwards fill keeps the final layout value after its frame work ends')
	f:Rules('#box{width:90px;height:20px}');assert(f.Box.Style.Width.Value==90 and f.Box.Style.Height.Value==20 and f.Box.Gui==original,'Removing animation-name restores current author values without replacing the box');f:Close()
	local absent=fixture('#box{width:100px;height:20px;animation:late 2s linear both}')
	assert(#absent.Runtime.Animations==0,'A missing keyframe has no running clock')
	absent:Rules('@keyframes late{from{width:100px}to{width:300px}}#box{width:100px;height:20px;animation:late 2s linear both}')
	absent:At(1);assert(absent.Box.Style.Width.Value==200,'A newly introduced keyframe starts from the beginning');absent:Close()
	local t=fixture('#box{width:100px;height:20px;transition:width 2s linear,height 2s linear}#box:hover{width:200px;height:60px}')
	local changed,needed,items=t.Tree:SetCSSState('hover',t.Box.Node);assert(changed and needed)
	Dirty.begin(t.Tree,items);layout.arrange(t.Tree,400,0,0,function()return true end);Dirty.finish(t.Tree,true);t.Runtime:AfterLayout();t.Flush()
	assert(t.Box.Style.Width.Value==100 and t.Box.Style.Height.Value==20,'A layout transition starts at the previous rendered pose')
	t:At(1);assert(t.Box.Style.Width.Value==150 and t.Box.Style.Height.Value==40,'CSS transitions interpolate retained layout fields')
	local count=t.Requests();t.Runtime:AfterLayout();t.Flush();assert(t.Requests()==count,'Republishing an unchanged sample requests no further layout')
	t:At(2);assert(t.Box.Style.Width.Value==200 and t.Box.Style.Height.Value==60,'The final transition returns to its author target');t:Close()
	-- Chromium's paused CSSTransition reference is captured in
	-- fixtures/css-transition-reversal-native.json. A reversal shortens by the
	-- eased progress already travelled, rather than starting another full run.
	local reversal=fixture('#box{width:100px;height:20px;transition:width 2s linear}#box.active{width:300px}')
	local function state(value)
		reversal.Box.Node.Attributes.class=value;reversal:Change({[reversal.Box.Node]={Attributes={class=true}}})
	end
	state('active');reversal:At(.5);assert(reversal.Box.Style.Width.Value==150,'Native reference first progress is 150px')
	local held=reversal.Runtime.Transitions[reversal.Box].Properties.width
	reversal.Box.Node.Attributes.style='color:red';reversal:Change({[reversal.Box.Node]={Attributes={style=true}}})
	assert(reversal.Runtime.Transitions[reversal.Box].Properties.width==held and held.Start==0,'Unrelated paint mutation must retain the running transition and start time')
	state(nil);local reversed=reversal.Runtime.Transitions[reversal.Box].Properties.width
	assert(reversed.Duration==.5 and reversed.Delay==0 and reversed.ReversingFactor==.25,'First reversal duration agrees with native 500ms')
	reversal:At(.75);assert(reversal.Box.Style.Width.Value==125,'Half the shortened reverse interval agrees with native 125px')
	state('active');assert(reversal.Runtime.Transitions[reversal.Box].Properties.width.Duration==1.75,'Repeated reversal factor agrees with native 1750ms')
	reversal:At(1.625);assert(reversal.Box.Style.Width.Value==212.5,'A repeated reversal starts from its current visual value')
	reversal.Box.Node.Attributes.style='transition-property:none';reversal:Change({[reversal.Box.Node]={Attributes={style=true}}})
	assert(not reversal.Runtime.Transitions[reversal.Box]and reversal.Box.Style.Width.Value==300,'Removing the matching transition cancels and restores the current author width')
	reversal:Close()
	local easedReverse=fixture('#box{width:100px;height:20px;transition:width 2s ease}#box.active{width:300px}')
	easedReverse.Box.Node.Attributes.class='active';easedReverse:Change({[easedReverse.Box.Node]={Attributes={class=true}}});easedReverse:At(1)
	easedReverse.Box.Node.Attributes.class=nil;easedReverse:Change({[easedReverse.Box.Node]={Attributes={class=true}}})
	assert(math.abs(easedReverse.Runtime.Transitions[easedReverse.Box].Properties.width.Duration-1.6048067821196873)<.000001,'Reversal shortening uses the easing output rather than elapsed fraction');easedReverse:Close()
	local negativeReverse=fixture('#box{width:100px;height:20px;transition:width 2s linear -.5s}#box.active{width:300px}')
	negativeReverse.Box.Node.Attributes.class='active';negativeReverse:Change({[negativeReverse.Box.Node]={Attributes={class=true}}});negativeReverse:At(.5)
	assert(negativeReverse.Box.Style.Width.Value==200,'Negative transition delay advances the initial interval')
	negativeReverse.Box.Node.Attributes.class=nil;negativeReverse:Change({[negativeReverse.Box.Node]={Attributes={class=true}}})
	local negativeData=negativeReverse.Runtime.Transitions[negativeReverse.Box].Properties.width
	assert(negativeData.Duration==1 and negativeData.Delay==-.25 and negativeReverse.Box.Style.Width.Value==175,'Reversal scales negative delay together with duration exactly like Chromium');negativeReverse:Close()
	local lastProperty=fixture('#box{width:100px;height:20px;transition:width 4s linear,all 2s linear}#box.active{width:300px}')
	lastProperty.Box.Node.Attributes.class='active';lastProperty:Change({[lastProperty.Box.Node]={Attributes={class=true}}});lastProperty:At(.5)
	assert(lastProperty.Runtime.Transitions[lastProperty.Box].Properties.width.Duration==2 and lastProperty.Box.Style.Width.Value==150,'Last matching transition-property entry supplies timing');lastProperty:Close()
	local shorthand=fixture('#box{width:100px;height:20px;padding:0px;transition:padding 2s linear}#box.active{padding:10px}')
	shorthand.Box.Node.Attributes.class='active';shorthand:Change({[shorthand.Box.Node]={Attributes={class=true}}});shorthand:At(1)
	for _,value in shorthand.Box.Style.Padding do assert(value==5,'Transition shorthand targets every supported longhand')end;shorthand:Close()
	local important=fixture('@keyframes grow{from{width:100px}to{width:300px}}#box{width:80px!important;height:20px;animation:grow 2s linear both}')
	important:At(1);assert(important.Box.Style.Width.Value==80,'Author !important defeats a CSS animation');important:Close()
	for _,mode in {'add','accumulate'}do
		local combined=fixture('@keyframes scaleup{from{transform:scale(1)}to{transform:scale(3)}}#box{width:100px;height:20px;translate:10px 0px;scale:2;transform:scale(2);transform-origin:0px 0px;animation:scaleup 2s linear both;animation-composition:'..mode..'}')
		combined:At(1);local expected=if mode=='add'then 8 else 6
		assert(math.abs(combined.Box.TransformScale.Scale-expected)<.001,'CSS '..mode..' composes transform operation lists and applies individual scale once')
		assert(math.abs(combined.Box.TransformPositionX-combined.Box.TransformBaseX-10)<.001,'Individual translate is present once in CSS '..mode..' composition')
		local properties={transform={PropertyOperations=combined.Box.Style.Transform,Operations=combined.Box.Style.Transform}}
		assert(combined.Runtime:SampleUnderlying(combined.Box.Node,properties,{transform=true}),'Additive CSS can be sampled underneath a script effect')
		assert(#properties.transform.PropertyOperations==(if mode=='add'then 2 else 1),'Lower CSS stack keeps property-only transform operations')
		combined:Close()
	end
	for _,mode in {'add','accumulate'}do
		local f=fixture('@keyframes slide{from{transform:translateX(0)}to{transform:translateX(60px)}}#box{width:100px;height:20px;transform:translateX(40px) rotate(25deg);animation:slide 2s linear both;animation-composition:'..mode..'}')
		f:At(1)
		local resolved=BoxTransform.resolve(f.Box,f.Box.TransformOverride)
		assert(math.abs(resolved.X-(if mode=='add'then 40+30*math.cos(math.rad(25))else 70))<.001,'Unequal transform lists preserve CSS '..mode..' semantics')
		assert(math.abs(resolved.Y-(if mode=='add'then 30*math.sin(math.rad(25))else 0))<.001,'Accumulation follows the original axis; addition follows the rotated axis')
		f:Close()
	end
	local stacked=fixture('@keyframes low{from{width:100px}to{width:200px}}@keyframes high{from{width:10px}to{width:30px}}#box{width:80px;height:20px;animation:low 2s linear both,high 2s linear both;animation-composition:replace,add}')
	stacked:At(1);assert(stacked.Box.Style.Width.Value==170,'A later additive CSS effect uses the preceding animated width')
	local sampled={width=AnimationValues.base(stacked.Box,'width')};assert(stacked.Runtime:SampleUnderlying(stacked.Box.Node,sampled,{width=true})and sampled.width.Value==170,'CSS lower-stack sampling follows animation-name order')
	stacked:Close()
	local oneAdd=fixture('@keyframes addwidth{from{width:10px}to{width:30px}}#box{width:80px;height:20px;animation:addwidth 2s linear both;animation-composition:add}')
	oneAdd:At(1);local underlying={width=oneAdd.Box.CSSAnimationLayoutProperties.width}
	assert(oneAdd.Runtime:SampleUnderlying(oneAdd.Box.Node,underlying,{width=true})and underlying.width.Value==100,'Sampling a previously published additive lower value starts from the author value exactly once');oneAdd:Close()
	local segments=fixture('@keyframes staged{0%{width:100px;animation-timing-function:step-start}50%{width:200px;animation-timing-function:linear}100%{width:300px}}#box{width:90px;height:20px;animation:staged 2s ease-in both}')
	segments:At(.5);assert(segments.Box.Style.Width.Value==200,'A keyframe timing function applies to its own segment')
	segments:At(1.5);assert(segments.Box.Style.Width.Value==250,'The next segment uses its own easing instead of easing the whole timeline');segments:Close()
	local enteringCSS='#box{width:200px;height:40px;opacity:1;transform:translateX(20px);transition:width 2s linear,height 2s linear,opacity 2s linear,transform 2s linear;@starting-style{width:100px;height:20px;opacity:0;transform:translateX(0px)}}input{width:40px;height:12px}#box.hidden{display:none}'
	local entering=fixture(enteringCSS);local retained=entering.Box.Gui;local retainedInput=entering.Input.Item.Gui
	assert(entering.Box.Style.Width.Value==100 and entering.Box.Style.Height.Value==20 and entering.Box.OpacityGroup.Gui.GroupTransparency==1,'Nested @starting-style supplies the initial before-change pose')
	entering:At(1)
	assert(entering.Box.Style.Width.Value==150 and entering.Box.Style.Height.Value==30 and math.abs(entering.Box.OpacityGroup.Gui.GroupTransparency-.5)<.001,'Entering dimensions and opacity interpolate together')
	local enteringSurface=entering.Box.OpacityGroup.Gui
	assert(math.abs(entering.Box.TransformPositionX-entering.Box.TransformBaseX-enteringSurface.AnchorPoint.X*entering.Box.OuterWidth-10)<.001,'Entering transform shares the retained CSS reference geometry: '..tostring(entering.Box.TransformPositionX)..'|'..tostring(entering.Box.TransformBaseX)..'|'..tostring(enteringSurface.AnchorPoint.X)..'|'..tostring(entering.Box.OuterWidth))
	entering:At(2);assert(entering.Box.Style.Width.Value==200 and entering.Box.Gui==retained and entering.Input.Item.Gui==retainedInput,'Entering transitions complete without rebuilding native controls')
	entering:Rules(enteringCSS:gsub('width:200px','width:240px'))
	assert(entering.Runtime.Transitions[entering.Box].Before.Layout.width.Value==200,'Already rendered elements use their actual prior pose, never starting-style again')
	entering:At(4);assert(entering.Box.Style.Width.Value==240)
	entering.Box.Node.Attributes.class='hidden';entering:Change({[entering.Box.Node]={Attributes={class=true}}})
	assert(not entering.Runtime.Transitions[entering.Box],'Becoming non-rendered cancels the entering/ordinary transition')
	entering.Box.Node.Attributes.class=nil;entering:Change({[entering.Box.Node]={Attributes={class=true}}})
	assert(entering.Box.Style.Width.Value==100 and entering.Box.OpacityGroup.Gui.GroupTransparency==1,'Display none to rendered receives a fresh starting style')
	entering:At(5);assert(entering.Box.Style.Width.Value==170 and math.abs(entering.Box.OpacityGroup.Gui.GroupTransparency-.5)<.001,'A re-entered box starts a new transition clock');entering:Close()
	local cascade=fixture('@starting-style{#box{width:100px;opacity:0}}#box{width:200px;height:20px;opacity:1;transition:width 2s linear,opacity 2s linear}')
	assert(not cascade.Runtime.Transitions[cascade.Box]and cascade.Box.Style.Width.Value==200,'Ordinary later declarations defeat equal-specificity starting rules through normal cascade order');cascade:Close()
	local standalone=fixture('#box{width:200px;height:20px;transition:width 2s linear} @starting-style{#box{width:100px}}')
	standalone:At(1);assert(standalone.Box.Style.Width.Value==150,'Standalone starting-style rules supply an entering width');standalone:Close()
	local startingImportant=fixture('#box{width:220px!important;height:20px;transition:width 2s linear}@starting-style{#box{width:100px}}')
	assert(not startingImportant.Runtime.Transitions[startingImportant.Box]and startingImportant.Box.Style.Width.Value==220,'Important author declarations also defeat normal starting style');startingImportant:Close()
	local stillRendered=fixture('#box{width:200px;height:20px;transition:width 2s linear}@starting-style{#box{width:100px}}#box.hidden{visibility:hidden}')
	stillRendered:At(2);stillRendered.Box.Node.Attributes.class='hidden';stillRendered:Change({[stillRendered.Box.Node]={Attributes={class=true}}})
	stillRendered.Box.Node.Attributes.style='width:240px';stillRendered.Box.Node.Attributes.class=nil
	stillRendered:Change({[stillRendered.Box.Node]={Attributes={style=true,class=true}}})
	assert(stillRendered.Runtime.Transitions[stillRendered.Box].Before.Layout.width.Value==200,'Visibility hidden retains the prior rendered style, unlike display none')
	stillRendered:At(3);assert(stillRendered.Box.Style.Width.Value==220,'A visibility-only hidden element transitions from its actual before pose');stillRendered:Close()
	local inserted=fixture('#box{width:100px;height:20px}#fresh{width:200px;height:20px;opacity:1;transition:width 2s linear,opacity 2s linear}@starting-style{#fresh{width:80px;opacity:0}}')
	local body=inserted.Box.Node.Parent;local fresh=Node.element('div',{id='fresh'});Node.append(body,fresh)
	inserted:Change({[body]={Children=true}});local freshBox=assert(inserted.Tree.NodeBoxes[fresh],'Inserted ordinary node has a native box')
	assert(freshBox.Style.Width.Value==80 and freshBox.OpacityGroup.Gui.GroupTransparency==1,'New structural insertion participates in entering transitions')
	inserted:At(1);assert(freshBox.Style.Width.Value==140 and math.abs(freshBox.OpacityGroup.Gui.GroupTransparency-.5)<.001,'New structural insertion samples retained dimensions and opacity');inserted:Close()
	local relative=fixture('#box{width:200px;height:20px;transform:translateX(100%);transform-origin:0px 0px;transition:width 2s linear,transform 2s linear}@starting-style{#box{width:100px;transform:translateX(50%)}}')
	assert(relative.Box.Style.Width.Value==100 and math.abs(relative.Box.TransformPositionX-relative.Box.TransformBaseX-50)<.001,'Starting percentages resolve against the currently animated width')
	relative:At(1);assert(relative.Box.Style.Width.Value==150 and math.abs(relative.Box.TransformPositionX-relative.Box.TransformBaseX-112.5)<.001,'Transition operation percentages interpolate and resolve against live geometry at midpoint')
	relative:At(1.5);assert(relative.Box.Style.Width.Value==175 and math.abs(relative.Box.TransformPositionX-relative.Box.TransformBaseX-153.125)<.001,'Following width layout preserves the current eased transform sample and clock')
	relative:At(2);assert(relative.Box.Style.Width.Value==200 and math.abs(relative.Box.TransformPositionX-relative.Box.TransformBaseX-200)<.001,'A percentage transition completes on its current reference box');relative:Close()
	local dynamicFade=fixture('#box{width:100px;height:20px}')
	assert(not dynamicFade.Box.OpacityGroup,'Initial ordinary opaque box needs no opacity surface')
	local fadeInput=dynamicFade.Input.Item.Gui
	dynamicFade:Rules('#box{width:100px;height:20px;opacity:1;transition:opacity 2s linear}#box.hidden{display:none}@starting-style{#box{opacity:0}}')
	assert(dynamicFade.Box.OpacityGroup and dynamicFade.Input.Item.Gui==fadeInput,'Installing an opacity transition creates a retained surface even when target opacity is one')
	dynamicFade.Box.Node.Attributes.class='hidden';dynamicFade:Change({[dynamicFade.Box.Node]={Attributes={class=true}}})
	dynamicFade.Box.Node.Attributes.class=nil;dynamicFade:Change({[dynamicFade.Box.Node]={Attributes={class=true}}})
	assert(dynamicFade.Box.OpacityGroup.Gui.GroupTransparency==1,'Dynamically introduced entering opacity paints the starting pose')
	dynamicFade:At(1);assert(math.abs(dynamicFade.Box.OpacityGroup.Gui.GroupTransparency-.5)<.001 and dynamicFade.Input.Item.Gui==fadeInput,'Dynamic entering fade samples the retained surface and native control');dynamicFade:Close()
	local shadow,animated,shadowEntry
	local scoped=fixture('@keyframes scopedgrow{from{width:100px}to{width:300px}}#box{width:300px}',function(doc)
		local host=Node.findById(doc,'box');shadow=Node.shadowRoot('open',host);host.InternalShadowRoot=shadow;host.ShadowRoot=shadow
		local style=Node.element('style',{});Node.append(style,Node.text('@keyframes scopedgrow{from{width:100px}to{width:200px}}#animated{width:80px;height:20px;animation:scopedgrow 2s linear both}#entering{width:260px;height:20px;transition:width 2s linear}@starting-style{#entering{width:140px}}'))
		animated=Node.element('div',{id='animated'});shadowEntry=Node.element('div',{id='entering'})
		Node.append(shadow,style);Node.append(shadow,animated);Node.append(shadow,shadowEntry);Node.append(shadow,Node.element('slot',{}))
	end)
	local scopedAnimated=assert(scoped.Tree.NodeBoxes[animated]);local scopedEntry=assert(scoped.Tree.NodeBoxes[shadowEntry])
	assert(scopedEntry.Style.Width.Value==140,'Shadow scoped starting styles establish a before-change pose')
	scoped:At(1);assert(scopedAnimated.Style.Width.Value==150 and scopedEntry.Style.Width.Value==200,'Scoped keyframes and entering rules use shadow CSS rather than same-name document definitions');scoped:Close()
	-- Real clocks advance while layout runs. A fixed-clock fixture conceals the
	-- layout -> AfterLayout -> later sample -> layout feedback that froze Studio.
	local feedbackCSS='@property --panel-size{syntax:"<length>";inherits:false;initial-value:140px}@keyframes rulegrow{from{width:140px}to{width:220px}}#box{width:var(--panel-size);height:40px}.running{animation:rulegrow 2s ease-in-out infinite alternate}'
	local feedback=fixture(feedbackCSS,nil,.0005);local feedbackGui=feedback.Input.Item.Gui
	feedback.Input.Value='retained during scheduling';feedbackGui.Text=feedback.Input.Value;feedbackGui.CursorPosition=4;feedbackGui.SelectionStart=2
	feedback.Box.Node.Attributes.class='running';feedback:Change({[feedback.Box.Node]={Attributes={class=true}}})
	local feedbackStart=feedback.Runtime.Animations[1].Start;local beforeLayouts=feedback.Layouts()
	local recordCount=0;for box,records in feedback.Runtime.AnimationRecords do recordCount+=1;assert(box==feedback.Box and next(records),'Static page boxes must not become animation work records')end
	assert(recordCount==1,'Only the animated target has an effect record')
	local resolveCount=0;local originalResolve=BoxTransform.resolve
	BoxTransform.resolve=function(...)resolveCount+=1;return originalResolve(...)end
	local ran,message=pcall(function()feedback:At(1)end);BoxTransform.resolve=originalResolve;assert(ran,message)
	assert(resolveCount==0,'A width-only frame must not resolve unrelated paint transforms: '..resolveCount)
	assert(feedback.Layouts()-beforeLayouts<=2 and not feedback.Pending(),'An advancing clock must settle animation layout in the current frame')
	local frameWidth=feedback.Box.Style.Width.Value;local beforeRequests=feedback.Requests()
	assert(frameWidth>160 and frameWidth<200,'The next rendering frame must still advance keyframe progress')
	for _=1,8 do feedback.Runtime:AfterLayout();feedback.Flush()end
	assert(feedback.Box.Style.Width.Value==frameWidth and feedback.Requests()==beforeRequests,'Repeated publication must reuse one frame sample even though Clock advances')
	feedback:Rules(feedbackCSS:gsub('width:220px','width:280px'))
	assert(feedback.Runtime.Animations[1].Start==feedbackStart and feedback.Box.Style.Width.Value>frameWidth and not feedback.Pending(),'Live keyframe editing preserves the clock and settles with the current sample')
	local lower={width=AnimationValues.base(feedback.Box,'width')}
	assert(feedback.Runtime:SampleUnderlying(feedback.Box.Node,lower,{width=true})and lower.width.Value==feedback.Box.Style.Width.Value,'CSS lower-stack repaint reuses the frame time')
	local live={width=AnimationValues.base(feedback.Box,'width')}
	assert(feedback.Runtime:SampleUnderlying(feedback.Box.Node,live,{width=true},true)and live.width.Value>lower.width.Value,'A direct commit can sample the current time without advancing the publication sample')
	feedback:At(1.2)
	assert(feedback.Box.Style.Width.Value>lower.width.Value and feedback.Input.Item.Gui==feedbackGui and feedbackGui.Text=='retained during scheduling'and feedbackGui.CursorPosition==4 and feedbackGui.SelectionStart==2,'Next-frame animation advances while retaining the native editor and selection')
	feedback.Box.Node.Attributes.class=nil;feedback:Change({[feedback.Box.Node]={Attributes={class=true}}})
	assert(not feedback.Runtime.AnimationRecords[feedback.Box]and not next(feedback.Runtime.RestoreBoxes)and feedback.Box.Style.Width.Value==140,'Removing the final effect restores the author width once and releases publication work')
	feedback:Close()
	local paintRestore=fixture('@keyframes paint{from{width:100px;transform:translateX(0px);opacity:.3;background-color:#aa0000}to{width:200px;transform:translateX(40px);opacity:.7;background-color:#00aa00}}#box{width:80px;height:20px;transform:translateX(7px);transform-origin:0px 0px;opacity:.9;background-color:#0000ff;animation:paint 2s linear infinite}')
	paintRestore:At(1)
	assert(paintRestore.Box.Style.Width.Value==150 and math.abs(paintRestore.Box.OpacityGroup.Gui.GroupTransparency-.5)<.001,'Compound layout/paint effect publishes its midpoint')
	paintRestore:Rules('#box{width:90px;height:20px;transform:translateX(11px);transform-origin:0px 0px;opacity:.8;background-color:#4466aa}')
	assert(not paintRestore.Runtime.AnimationRecords[paintRestore.Box]and not next(paintRestore.Runtime.RestoreBoxes)and not paintRestore.Box.AnimationAuthorFields,'Removing compound effects releases author overlays and restore work')
	assert(paintRestore.Box.Style.Width.Value==90 and math.abs(paintRestore.Box.TransformPositionX-paintRestore.Box.TransformBaseX-11)<.001 and math.abs(paintRestore.Box.OpacityGroup.Gui.GroupTransparency-.2)<.001,'One-shot restore uses current author width/transform/opacity')
	assert((paintRestore.Box.PaintBackgroundGui or paintRestore.Box.Gui).BackgroundColor3==Color3.fromRGB(68,102,170),'One-shot restore paints the current author background')
	paintRestore:Close()
	print('CSS layout animations: retained controls/selection, compound dimensions, local flow, keyframe edits/missing rules, fill/cancel, transitions, advancing-clock convergence and importance passed')
end
