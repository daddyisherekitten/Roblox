--!strict
-- Actual page scheduling with delayed Roblox signals and work-budget pauses.
return function(loadHTMLPage,ScriptGeometry,Geometry,VM)
	local function fixture(deferred)
		local time,queue,signals=0,{},{}
		local function signal(delayed)
			local entries={};local api={}
			function api:Connect(fn)
				local entry={Connected=true,Callback=fn};function entry:Disconnect()self.Connected=false end
				table.insert(entries,entry);return entry
			end
			function api:Fire()
				for _,entry in entries do if entry.Connected then
					if delayed then table.insert(signals,function()if entry.Connected then entry.Callback()end end)
					else entry.Callback()end
				end end
			end
			return api
		end
		local function gui(class)
			local properties,attributes,attributeSignals={},{},{}
			local object={ClassName=class,AbsoluteSize=Vector2.new(400,300),CanvasPosition=Vector2.new(0,0),
				ScrollBarThickness=10,Destroying=signal(false)}
			function object:GetPropertyChangedSignal(key)properties[key]=properties[key]or signal(deferred);return properties[key]end
			function object:GetAttributeChangedSignal(key)attributeSignals[key]=attributeSignals[key]or signal(deferred);return attributeSignals[key]end
			function object:GetAttribute(key)return attributes[key]end
			function object:SetAttribute(key,value)
				local changed=attributes[key]~=value;attributes[key]=value
				if changed and attributeSignals[key]then attributeSignals[key]:Fire()end
			end
			function object:Destroy()self.Destroying:Fire();self.Parent=nil end
			return object
		end
		local host,root=gui('Frame'),gui('ScrollingFrame')
		local document={Kind='Document',Children={}}
		local node={Kind='Element',Name='div',Attributes={},Children={},Parent=document};table.insert(document.Children,node)
		local style={Display='block',Position='static',Padding={0,0,0,0},BorderSizes={0,0,0,0},Margin={0,0,0,0}}
		local box={Node=node,Style=style,LayoutX=0,LayoutY=0,OuterWidth=0,OuterHeight=0,Children={}}
		local tree={Positioning=true,Children={},NodeBoxes={[node]=box},NodeStyles={[node]=style}}
		local counts={Layouts=0,Publications=0,Waits=0,Flushes=0,Media=0}
		local onWait,onCSS,onScript,force,wake,page
		local pending=false
		local function enqueue(delay,fn)local job={Due=time+delay,Callback=fn};table.insert(queue,job);return job end
		local tasks={defer=function(fn)return enqueue(0,fn)end,delay=enqueue,cancel=function(job)job.Cancelled=true end,
			wait=function()
				counts.Waits+=1;time+=.016
				if onWait then local fn=onWait;onWait=nil;fn()end
			end}
		function tree:SetMediaEnvironment(width,height)counts.Media+=1;self.LastMediaWidth,self.LastMediaHeight=width,height;return false end
		function tree:FlushCSSStates()if onCSS then local fn=onCSS;onCSS=nil;fn()end;return false,false end
		page=loadHTMLPage({
			['Rendering/GuiFactory']={create=function(class,parent,props)
				local object=if class=='ScrollingFrame'then root else gui(class);object.Parent=parent
				for key,value in props do object[key]=value end;return object
			end},
			['Rendering/RenderTree']={build=function()return tree end},
			['Input/Controller']={start=function()end},
			['Rendering/ImageDimensions']={start=function(_,_,_,changed)force=changed end},
			['Layout/BlockLayout']={arrange=function(_,width,_,_,check)
				counts.Layouts+=1
				for _=1,20 do time+=.001;check()end
				box.OuterWidth,box.OuterHeight=width,tree.ViewportHeight
				return tree.ViewportHeight,width
			end},
			['Rendering/HTMLScripts']={ShouldStart=function()return true end,hasScripts=function()return false end,start=function(owner,_,schedule)
				wake=schedule
				owner.JavaScriptRuntime={HasOwnBlockingStylesheets=function()return false end,
					SubscribeStylesheetChanges=function()return function()end end,
					Alive=true,HasPending=function()return pending end,Flush=function()
						counts.Flushes+=1;pending=false
						if onScript then local fn=onScript;onScript=nil;fn()end
						return true
					end,
					AfterLayout=function()counts.Publications+=1 end}
			end},
		},tasks,function()return time end).mount(host,'', {RenderWorkBudgetMS=4})
		local api={Page=page,Root=root,Host=host,Tree=tree,Counts=counts,Node=node}
		function api:Drain()
			local rounds=0
			while #queue>0 do
				rounds+=1;assert(rounds<100,'A held resize must return to the scheduler without polling')
				local job=table.remove(queue,1);if not job.Cancelled then time=math.max(time,job.Due);job.Callback()end
			end
		end
		function api:DeliverSignals()while #signals>0 do table.remove(signals,1)()end end
		function api:Hold()host:SetAttribute('HTMLViewportResizing',true)end
		function api:Release()host:SetAttribute('HTMLViewportResizing',false);self:DeliverSignals();self:Drain()end
		function api:Resize(width,height)root.AbsoluteSize=Vector2.new(width,height);root:GetPropertyChangedSignal('AbsoluteSize'):Fire()end
		function api:Force()force()end
		function api:DuringWait(fn)onWait=fn end
		function api:DuringCSS(fn)onCSS=fn end
		function api:DuringScript(fn)onScript=fn end
		function api:ChangeScript()pending=true;wake()end
		function api:ScriptPending()return pending end
		return api
	end
	for _,deferred in {false,true}do
		local f=fixture(deferred);f:Drain()
		assert(f.Counts.Layouts==1 and f.Counts.Publications==1 and f.Root.Visible)
		local canvas=f.Root.CanvasSize
		-- Attribute value is live before its deferred callback. No resize signal
		-- is delivered here to incidentally invalidate the current revision.
		f:DuringWait(function()f:Hold()end);f:Force();f:Drain()
		assert(f.Counts.Layouts==2 and f.Counts.Publications==1 and f.Counts.Waits>0
			and f.Tree.LayoutNeedsRecovery and f.Root.CanvasSize==canvas,
			'A grip acquired during a suspended pass cancels before publication, even with deferred signals')
		f:Resize(710,460);f:Force();f:Drain();f:DeliverSignals();f:Drain()
		assert(f.Counts.Layouts==2 and f.Counts.Publications==1,'Held recovery cannot start another pass')
		f:Release()
		assert(f.Counts.Layouts==3 and f.Counts.Publications==2 and f.Tree.LastMediaWidth==710
			and f.Tree.LastMediaHeight==460 and f.Root.CanvasSize[2]==460 and not f.Tree.LayoutNeedsRecovery)
		-- Beginning a drag while pending CSS states flush must also prevent
		-- the already calculated result from being published.
		canvas=f.Root.CanvasSize
		f:DuringCSS(function()f:Hold()end);f:Force();f:Drain()
		assert(f.Counts.Publications==2 and f.Tree.LayoutNeedsRecovery and f.Root.CanvasSize==canvas,
			'A deferred grip event between layout and publication cannot commit intermediate geometry')
		f:Resize(690,420);f:DeliverSignals();f:Release()
		assert(f.Counts.Publications==3 and f.Tree.LastMediaWidth==690 and f.Tree.LastMediaHeight==420)
		f.Page:Destroy();f:DeliverSignals();f:Drain()
	end
	for _,deferred in {false,true}do
		local f=fixture(deferred);f:Drain()
		local layouts,media,flushes=f.Counts.Layouts,f.Counts.Media,f.Counts.Flushes
		local vm=VM.new({},{MaxSteps=100000})
		local adapter=ScriptGeometry.new(f.Page,f.Tree,f.Page.JavaScriptRuntime)
		local geometry=Geometry.install(vm,{},adapter)
		assert(geometry.ElementGet(f.Node,'offsetWidth')==390)
		f:Hold();f:Resize(500,360);f:ChangeScript()
		-- The explicit geometry path must share the held-grip gate. Its pending
		-- DOM batch and layout remain queued, then settle once after release.
		for _=1,8 do
			f.Page:FlushScriptLayout()
			assert(geometry.ElementGet(f.Node,'offsetWidth')==390,'Held geometry reads retain the measured box width')
		end
		f:Drain()
		assert(f.Counts.Layouts==layouts and f.Counts.Media==media and f.Counts.Flushes==flushes
			and f:ScriptPending(),
			'Synchronous geometry demands cannot bypass a held resize or consume its pending script batch')
		f:Resize(800,520);f:DeliverSignals();f:Drain()
		assert(f.Counts.Layouts==layouts and f.Counts.Flushes==flushes and f.Page:HasPendingLayout(),
			'Delivering resize signals while held queues the final layout without consuming scripts')
		f:Release()
		assert(f.Counts.Layouts==layouts+1 and f.Counts.Publications==2 and not f:ScriptPending()
			and f.Counts.Flushes==flushes+1 and f.Tree.LastMediaWidth==800 and f.Tree.LastMediaHeight==520)
		assert(geometry.ElementGet(f.Node,'offsetWidth')==790,'The real geometry bridge observes the final width after release')
		-- Outside the custom host gesture, reads still synchronously force layout.
		f:Resize(450,310);f:DeliverSignals();f.Page:FlushScriptLayout()
		assert(f.Counts.Layouts==layouts+2 and f.Counts.Publications==3 and f.Tree.LastMediaWidth==450)
		f:DeliverSignals();f:Drain();assert(f.Counts.Layouts==layouts+2,'No duplicate after the synchronous flush')
		-- A gesture can start while a geometry flush applies a DOM batch or
		-- flushes pending CSS. Neither case may proceed/publish in its sync path.
		for _,phase in {'script','css'}do
			local beforeLayouts,beforePublications=f.Counts.Layouts,f.Counts.Publications
			if phase=='script'then
				f:DuringScript(function()f:Hold();f:Resize(720,480)end);f:ChangeScript()
			else f:DuringCSS(function()f:Hold()end);f:Force()end
			f.Page:FlushScriptLayout();f:Drain()
			assert(f.Counts.Publications==beforePublications and f.Counts.Layouts==beforeLayouts+(if phase=='css'then 1 else 0),
				'A resize beginning inside a synchronous '..phase..' flush suppresses further layout/publication')
			if phase=='css'then assert(f.Tree.LayoutNeedsRecovery and f.Page:HasPendingLayout())end
			f:Resize(760,510);f:DeliverSignals();f:Release()
			assert(f.Counts.Publications==beforePublications+1 and geometry.ElementGet(f.Node,'offsetWidth')==750
				and not f.Tree.LayoutNeedsRecovery,'A cancelled synchronous flush preserves work for release')
		end
		geometry:Destroy();adapter.Destroy();vm:Destroy()
		f.Page:Destroy();f:DeliverSignals();f:Drain()
	end
	print('Page resize: immediate/deferred signals, suspended work, final publication gate, held script flush and release recovery passed')
end
