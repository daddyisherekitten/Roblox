--!strict
-- Real runtime and retained paint adapter, with native-reference fixtures.
return function(Parser,Node,Runtime,VM,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLAnimations,fixtures)
	local created=0;local factory={create=function(class,parent,props)
		created+=1;local gui=table.clone(props);gui.ClassName=class;gui.Parent=parent
		function gui:Destroy()self.Destroyed=true;self.Parent=nil end;return gui
	end}
	local renderer=loadRenderTree(factory);local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=#text*8,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
	local failures={}
	local function fixture(extra)
		local document=Parser.parseDocument('<html><head></head><body><div id="parent"><div id="box"></div></div><div id="outside">Unchanged</div></body></html>')
		local root={AbsoluteSize=Vector2.new(600,800)};local messages={}
		local tree=renderer.build(document,root,function(s)table.insert(messages,s)end,nil,nil,nil,nil,'html,body{margin:0;padding:0}#box{width:200px;height:100px;background:white}'..(extra or''))
		local s={Document=document,Tree=tree,Layouts=0,Diagnostics={},Values={},Flushing=false};local pending=false
		local function arrange()Dirty.begin(tree);layout.arrange(tree,600,0,0,function()return true end);Dirty.finish(tree,true)end
		arrange();local runtime
		local page={Alive=true,Root={SetAttribute=function()end},Cleanups={}}
		function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
		if extra and extra:find('@keyframes',1,true)then
			s.Motion=HTMLAnimations.start(page,tree,error,{Clock=function()return 0 end,RunService={RenderStepped={Connect=function()error('Paused CSS animations should not request a frame')end}}},0)
			s.Motion:AfterLayout()
		end
		function page:FlushScriptLayout()
			if s.Flushing or not runtime then return end;s.Flushing=true
			local needed=runtime:Flush();if needed then s.Layouts+=1;arrange();runtime:AfterLayout()end
			s.Flushing=false;pending=false
		end
		runtime=Runtime.new(document,{Events=Events.new(error),Clock=function()return 0 end,Diagnostic=function(v)table.insert(s.Diagnostics,v)end,Console=function(_,v)table.insert(s.Values,v)end,
			CreateAnimationAdapter=function()s.Adapter=HTMLAnimations.scriptAdapter(page,tree,error);return s.Adapter end,
			GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return {Width=600,Height=800,ClientWidth=600,ClientHeight=800}end,HasPending=function()return runtime:HasPending()or pending end,Flush=function()page:FlushScriptLayout()end},
			ApplyChanges=function(changes)local needed,targets=tree:ApplyDOMChanges(changes);pending=pending or needed;return needed,targets end})
		s.Runtime=runtime;s.Page=page;s.Messages=messages;s.BoxNode=Node.findById(document,'box');s.Box=tree.NodeBoxes[s.BoxNode];s.Outside=tree.NodeBoxes[Node.findById(document,'outside')]
		function s:Run(source)runtime:Run(source);page:FlushScriptLayout();runtime:AfterLayout();runtime:PumpTasks();page:FlushScriptLayout()end
		function s:Destroy()runtime:Destroy();for _,cleanup in page.Cleanups do cleanup()end;page.Alive=false;assert(runtime.EventLoop.FrameCount==0,'Disposed commit animations leave no requested frames')end
		return s
	end
	local function near(a,b,label)assert(type(a)=='number'and math.abs(a-b)<.001,(label or'number')..': '..tostring(a)..' ~= '..tostring(b))end
	local function paintedPosition(box)
		local gui=if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui
		return gui.Position[1]-(gui.AnchorPoint and gui.AnchorPoint.X or 0)*gui.Size[1],gui.Position[2]-(gui.AnchorPoint and gui.AnchorPoint.Y or 0)*gui.Size[2]
	end
	for _,case in fixtures do
		if case.browserOnly then continue end
		local s=fixture(case.css);local outsideGUI=s.Outside.Gui;local outsideCache=s.Outside.CachedLayout
		s:Run('function record(value){console.log(String(value));}\n'..case.source)
		if #s.Diagnostics>0 or #s.Values~=#case.expected then table.insert(failures,case.name..': '..table.concat(s.Diagnostics,' / ')..' actual='..table.concat(s.Values,' | '))
		else for i,value in s.Values do if value~=case.expected[i]then table.insert(failures,case.name..' ['..i..']: '..value..' ~= '..case.expected[i])end end end
		if #s.Diagnostics==0 then
			local p=case.paint;local box=s.Tree.NodeBoxes[s.BoxNode]
			if p and box then
				if p.opacity then near(if box.OpacityGroup then box.OpacityGroup.Gui.GroupTransparency else 1-(box.Style.Opacity or 1),1-p.opacity,case.name..' opacity')end
				if p.background then local value=(box.PaintBackgroundGui or box.Gui).BackgroundColor3;near(value.R,p.background[1]/255,'red');near(value.G,p.background[2]/255,'green');near(value.B,p.background[3]/255,'blue')end
				if p.alpha then near((box.PaintBackgroundGui or box.Gui).BackgroundTransparency,1-p.alpha,'alpha')end
				if p.x then local x,y=paintedPosition(box);near(x,p.x,'x');near(y,p.y or 0,'y')end
			end
			if not case.geometry then assert(s.Layouts==0,case.name..': committing supported paint does not arrange');assert(s.Outside.Gui==outsideGUI and s.Outside.CachedLayout==outsideCache,'Commit retains unrelated surfaces and layout caches')end
			assert(#s.Messages==0,table.concat(s.Messages,' / '));assert(s.Runtime.EventLoop.FrameCount==0,case.name..': paused/finished commit does not retain a frame callback')
		end
		s:Destroy()
	end
	for _,failure in failures do print('Animation commit mismatch: '..failure)end;assert(#failures==0,'Animation commit fixture failures: '..#failures)
	-- Individual transforms and motion distance must not be baked twice into
	-- the committed transform declaration.
	local s=fixture('#box{translate:10px 0;offset-path:path("M 0 0 L 100 0");offset-anchor:0 0;offset-rotate:0deg;transform-origin:0 0}')
	s:Run([=[const box=document.getElementById('box');const a=box.animate({transform:['translate(0px, 0px)','translate(40px, 0px)'],offsetDistance:['0%','100%']},100);a.pause();a.currentTime=50;a.commitStyles();a.finished.catch(()=>{});a.ready.catch(()=>{});a.cancel();if(box.style.transform!=='translate(20px)'||box.style.offsetDistance!=='50%')throw new Error('double transform channels');]=])
	assert(#s.Diagnostics==0,table.concat(s.Diagnostics,' / '));local x,y=paintedPosition(s.Box);near(x,80,'separate transform/path/individual channel');near(y,0);assert(s.Layouts==0,'motion distance commit requested '..s.Layouts..' layouts');s:Destroy()
	-- Important cascade and variable references remain live after CSSOM or
	-- class changes mutate the retained Style table in place.
	s=fixture('#box{--end:.2}.blocked{opacity:.6!important}')
	s:Run([=[const box=document.getElementById('box');const a=box.animate({opacity:['0','var(--end)']},100);a.pause();a.currentTime=50;]=])
	near(s.Box.OpacityGroup.Gui.GroupTransparency,.9,'initial contextual effect')
	s:Run("box.style.setProperty('--end','.8');")
	near(s.Box.OpacityGroup.Gui.GroupTransparency,.6,'fresh variable effect')
	s:Run("box.className='blocked';")
	near(s.Box.OpacityGroup.Gui.GroupTransparency,.4,'important cascade wins animated paint')
	s:Run("box.className='';a.commitStyles();a.finished.catch(()=>{});a.ready.catch(()=>{});a.cancel();")
	assert(#s.Diagnostics==0,table.concat(s.Diagnostics,' / '));near(s.Box.Style.Opacity,.4,'commit fresh variable effect');s:Destroy()
	s=fixture();s:Run("const a=document.getElementById('box').animate({opacity:[0,1]},100);a.pause();a.currentTime=50;")
	local raw=Node.element('test',{});raw.NamespaceURI='http://example.org/test';local vm=s.Runtime.VM
	vm:Install(function()
		local a=vm.Global.Bindings.a.Value;vm.Set(vm.Get(a,'effect'),'target',s.Runtime.DOM.Wrap(raw),true)
		local ok,errorValue=pcall(function()vm:Call(vm.Get(a,'commitStyles'),{},a)end)
		assert(not ok and vm.Get(VM.exceptionValue(errorValue),'name')=='NoModificationAllowedError','Foreign namespace fails before disconnected rendering check')
	end);s:Destroy()
	print('JavaScript Animation.commitStyles: '..#fixtures..' native-reference fixtures, retained paint, one mutation, importance, context, transform/path channels, rendered errors and lifetime passed')
end
