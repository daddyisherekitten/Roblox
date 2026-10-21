--!strict
return function(Parser: any,Style: any,Stylesheet: any,Motion: any,MotionPath: any)
 local fixtureElement=require('DOM/Node').element
	local transition=Motion.transition("transform 240ms ease-out 40ms, background-color .5s linear")
	assert(transition and transition.Property[1]=="transform" and transition.Duration[1]==.24 and transition.Delay[1]==.04)
	assert(transition.Property[2]=="background-color" and transition.Duration[2]==.5 and transition.Timing[2]=="linear")
	local discrete=Motion.transition('box-shadow 1s linear allow-discrete, opacity .5s normal')
	assert(discrete and discrete.Behavior[1]=='allow-discrete'and discrete.Behavior[2]=='normal'and transition.Behavior[1]=='normal','Transition shorthand parses its behavior per list member and resets it to normal')
	assert(Motion.transition('box-shadow 1s allow-discrete normal')==nil,'Duplicate transition behavior invalidates a shorthand')
	local hover=Motion.transition("transform .6s cubic-bezier(.2,.7,.2,1),background-color .4s linear,border-radius .8s ease,box-shadow .5s ease")
	assert(hover and #hover.Property==4 and hover.Property[3]=="border-radius" and hover.Property[4]=="box-shadow")
	assert(Motion.ease("cubic-bezier(.2,.7,.2,1)",0)==0 and Motion.ease("cubic-bezier(.2,.7,.2,1)",1)==1)
	assert(Motion.ease("cubic-bezier(.2,.7,.2,1)",.5)>.5,"Cubic Bezier easing advances the hover transform smoothly")
	-- Independent numerical references for the W3C keyword curves, sampled
	-- at elapsed progress .25/.5/.75. The old smoothstep/quadratics fail these.
	for name,expected in {
		ease={.408510591355396,.802403387584857,.960458978348974},
		["ease-in"]={.093464650718825,.315356812572539,.62186186917489},
		["ease-out"]={.37813813082511,.684643187427461,.906535349281175},
		["ease-in-out"]={.12916193104732,.5,.87083806895268},
	} do
		assert(Motion.ease(name,0)==0 and Motion.ease(name,1)==1,"Bezier endpoints must finish exactly")
		for index,t in {.25,.5,.75} do
			assert(math.abs(Motion.ease(name,t)-expected[index])<1e-8,"CSS keyword curve must match the browser: "..name)
		end
	end
	assert(Motion.ease("ease",.99)-Motion.ease("ease",.98)<Motion.ease("ease",.5)-Motion.ease("ease",.49),"CSS ease visibly decelerates at its end")
	assert(Motion.ease("cubic-bezier(1,0,0,1)",.5)==.5,"A flat internal x tangent cannot destabilize the solver")
	assert(math.abs(Motion.ease("cubic-bezier(0,0,0,1)",1e-9)-.000002998)<1e-10,"Flat endpoint tangents preserve very small progress")
	assert(Motion.ease("cubic-bezier(.3,0,.7,2)",.8)>1,"Legal overshooting curves must not be clamped")
	local animation=Motion.animation("pulse 1.2s ease-in-out 100ms 3 alternate both paused")
	assert(animation and animation.Name[1]=="pulse" and animation.Iteration[1]==3 and animation.Direction[1]=="alternate")
	assert(animation.Fill[1]=="both" and animation.Play[1]=="paused")
	local named=Motion.animation('CaseSensitive 1S EASE-IN BOTH PAUSED')
	assert(named and named.Name[1]=='CaseSensitive'and named.Duration[1]==1 and named.Timing[1]=='ease-in'and named.Fill[1]=='both'and named.Play[1]=='paused','Animation names keep their case while CSS keywords and time units are case-insensitive')
	local namedStyle=Style.resolve(fixtureElement('div',{style='animation:CaseSensitive 1s linear'}),{FontSize=16,RootFontSize=16},error,false)
	assert(namedStyle.AnimationName[1]=='CaseSensitive','The CSS compiler must retain the actual @keyframes name')
	local disabled=Motion.animation("none")
	assert(disabled and disabled.Name[1]=="none" and disabled.Duration[1]==0 and disabled.Fill[1]=="none")
	assert(Motion.list("120ms, .4s","time")[2]==.4 and Motion.list("infinite, 2.5","iteration")[1]==math.huge)
	assert(Motion.list("-2s, -150ms","delay")[1]==-2 and Motion.list("-2s, -150ms","delay")[2]==-.15)
	assert(Motion.list("-2s","time")==nil and Motion.transition("transform .6s -200ms").Delay[1]==-.2)
	assert(Motion.animation("orbit 5s ease-in-out infinite alternate -2s").Delay[1]==-2)
	assert(Motion.transition('width -1s')==nil and Motion.animation('orbit -1s')==nil,'The first time component is duration and must not be interpreted as a negative delay')
	assert(Motion.list('none,opacity','transition-property')==nil and Motion.transition('none,opacity 1s')==nil,'none is the entire transition-property value, not one list member')
	local steps=Motion.animation("lab-steps 3s steps(6,end) infinite alternate")
	assert(steps and steps.Timing[1]=="steps(6,end)" and steps.Iteration[1]==math.huge)
	assert(Motion.ease("steps(6,end)",.49)==2/6 and Motion.ease("steps(6,end)",1)==1)
	assert(Motion.ease("steps(6,start)",0)==1/6 and Motion.list("steps(0,end)","timing")==nil)
	for _,sample in {{0,1,0},{.5,1,0},{1,1,1}} do
		local t=sample[1]
		assert(Motion.ease("step-start",t)==sample[2] and Motion.ease("steps(1,start)",t)==sample[2],"step-start is the steps(1,start) alias, including t=0")
		assert(Motion.ease("step-end",t)==sample[3] and Motion.ease("steps(1,end)",t)==sample[3],"step-end is the steps(1,end) alias")
	end
	assert(Motion.ease("step-start",0,true)==0 and Motion.ease("steps(4,start)",.5,true)==.5,"The before flag selects the lower side at a step discontinuity")
	assert(Motion.ease("steps(4,start)",.51,true)==.75,"The before flag does not shift progress between discontinuities")
	assert(Motion.ease("ease",.5,true)==Motion.ease("ease",.5),"Before flags leave continuous easing curves unchanged")
	assert(Motion.ease("linear",.25)==.25 and Motion.progress(.25,1,2,"normal")==.25)
	-- These progress vectors were captured from a paused native Chromium
	-- KeyframeEffect (css-easing-native.json), including stop normalization.
	for _,sample in {
		{'steps(4)',{0,.25,.5,.75,1}},
		{'steps(+4)',{0,.25,.5,.75,1}},
		{'steps(4,jump-start)',{.25,.5,.75,1,1}},
		{'steps(4,jump-end)',{0,.25,.5,.75,1}},
		{'steps(4,jump-none)',{0,1/3,2/3,1,1}},
		{'steps(4,jump-both)',{.2,.4,.6,.8,1}},
		{'steps(1,jump-both)',{.5,.5,.5,.5,1}},
		{'linear(0,.25,1)',{0,.125,.25,.625,1}},
		{'linear(0,.25 25% 75%,1)',{0,.25,.25,.25,1}},
		{'linear(0 20%,.5 10%,1)',{.5,.53125,.6875,.84375,1}},
		{'linear(0,0 50%,1 50%,1)',{0,0,1,1,1}},
		{'linear(0 50%,1 50%)',{1,1,1,1,1}},
		{'linear(0e0,1e0)',{0,.25,.5,.75,1}},
	}do
		assert(Motion.list(sample[1],'timing'),'Native-valid easing must be accepted: '..sample[1])
		for index,t in {0,.25,.5,.75,1}do assert(math.abs(Motion.ease(sample[1],t)-sample[2][index])<1e-8,'Native easing mismatch: '..sample[1])end
	end
	for _,invalid in {'steps(1,jump-none)','steps(4,unknown)','steps(4,,end)','linear(0)','linear(0,1,)','linear(0,,1)','linear(0 10% 20% 30%,1)'}do assert(Motion.list(invalid,'timing')==nil,'Invalid complete easing declaration must reject: '..invalid)end
	assert(Motion.ease('linear(0 0%,1 0%,1)',0,true)==0 and Motion.ease('linear(0 0%,1 0%,1)',0)==1,'Linear discontinuity observes the before flag at its first stop')
	assert(Motion.ease('linear(0,2)',1.25)==2.5 and Motion.ease('linear(0,2)',-.5)==-1,'Linear easing extrapolates for chained script effects')
	assert(Motion.ease('cubic-bezier(.5,1,.5,0)',-.25)==-.5 and Motion.ease('cubic-bezier(.5,1,.5,0)',1.25)==1.5,'Bezier easing extrapolates with the endpoint tangents')
	local mixed=Motion.transition('transform 1s linear(0,.25 25% 75%,1),opacity 2s steps(4,jump-both)')
	assert(mixed and mixed.Timing[1]=='linear(0,.25 25% 75%,1)'and mixed.Timing[2]=='steps(4,jump-both)','Functional easing commas must remain inside their shorthand component')
	local reverse=Motion.progress(.25,1,2,"reverse");assert(reverse==.75)
	local alternating=Motion.progress(1.25,1,2,"alternate");assert(alternating==.75)
	for _,case in {{2.5,'normal',.5},{1.25,'normal',.25},{1.25,'reverse',.75},
		{1.25,'alternate',.75},{1.25,'alternate-reverse',.25},{2,'alternate',0},{0,'normal',0}} do
		local endpoint,finished=Motion.progress(10,1,case[1],case[2])
		assert(finished and endpoint==case[3],'Final fractional iteration keeps its progress and direction')
	end

	local document=Parser.parse('<style>@keyframes pulse { from { opacity:.2; transform:translateX(0px) } 50%, 75% { opacity:1 } to { opacity:.4; transform:translateX(20px) } } .box { transition:transform .2s linear; animation:pulse 1s 2 alternate both; } @media (max-width:900px) { .box { animation:none } }</style><div class="box"></div>')
	local diagnostics={};local rules=Stylesheet.collect(document,function(message)table.insert(diagnostics,message)end)
	assert(#diagnostics==0 and rules.Keyframes.pulse and #rules.Keyframes.pulse.Frames==4)
	local early=Stylesheet.collect(Parser.parse('<style>@keyframes early { from {opacity:0} 1% {opacity:.1} 100% {opacity:1} }</style>'),error)
	assert(#early.Keyframes.early.Frames==3 and early.Keyframes.early.Frames[2].Offset==.01
		and early.Keyframes.early.Frames[3].Offset==1,'1% is an early keyframe, not the final endpoint')
	local node=document.Children[2];local parent={Font="Roboto",FontSize=16,RootFontSize=16,Color=Color3.new(0,0,0),ColorAlpha=1,ViewportWidth=800,ViewportHeight=600}
	local computed=Style.resolve(node,parent,error,false,Stylesheet.match(rules,node,{}))
	assert(computed.TransitionProperty[1]=="transform" and computed.TransitionDuration[1]==.2)
	assert(computed.AnimationName[1]=="none" and computed.AnimationDuration[1]==0 and computed.AnimationFill[1]=="none")
	local delayed=Style.resolve(Parser.parse('<div style="animation-delay:-2s;transition-delay:-150ms"></div>').Children[1],parent,error,false)
	assert(delayed.AnimationDelay[1]==-2 and delayed.TransitionDelay[1]==-.15)
	local function pathStyle(css: string): any
		return Style.resolve(fixtureElement("div",{style=css}),parent,error,false)
	end
	local absolute=pathStyle('offset-path:path("M 28 85 C 28 10 250 10 250 85 C 250 160 28 160 28 85 Z");offset-distance:25%')
	local relative=pathStyle('offset:PATH("m 28 85 c 0 -75 222 -75 222 0 c 0 75 -222 75 -222 0 z") 25% auto / center')
	local a,b=MotionPath.resolve(absolute,28,28),MotionPath.resolve(relative,28,28)
	assert(math.abs(a.X-139)<.15 and math.abs(a.Y-28.75)<.15 and math.abs(a.X-b.X)<.001 and math.abs(a.Y-b.Y)<.001,
		"CSS longhand and shorthand preserve absolute and relative SVG commands")
	local open=pathStyle('offset-path:path("m 10 20 l 100 0");offset-distance:150%')
	assert(open.OffsetPath.X2==110 and MotionPath.resolve(open,10,10).X==110,"Relative lines use their actual endpoint and open paths clamp at the end")
	local arc=pathStyle('offset-path:path("M 0 0 A 50 50 0 0 1 100 0");offset-distance:50%')
	local arcPoint=MotionPath.resolve(arc,10,10)
	assert(math.abs(arcPoint.X-50)<.15 and math.abs(arcPoint.Y+50)<.15,"CSS path sampling reuses SVG elliptical arcs")
	assert(MotionPath.parse("M 0 0 C 1 2 broken")==nil,"Invalid paths reject incomplete geometry instead of silently moving the marker")
	local widthTransition=Motion.transition("width 1s")
	assert(widthTransition and widthTransition.Property[1]=="width" and widthTransition.Duration[1]==1,
		"Layout transitions retain the width property and its declared duration")
	assert(Motion.transition("width 1s 2s 3s")==nil and Motion.animation("1s")==nil and Motion.list("-1s","time")==nil)
	print("CSS motion: transition/animation lists, shorthands, easing, progress and @keyframes passed")
end
