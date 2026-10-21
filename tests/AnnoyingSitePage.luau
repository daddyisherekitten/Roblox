--!strict
-- Current website sources through the actual engine/HTMLPage/VM. Only Roblox
-- GUI, media assets, capture hardware and wall time are deterministic doubles.
return function(loadHost,fixture,loadEngine,WorkContext,Parser,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages,loadIFrames,source,loadWindows,loadManagedHost,loadBrowser,loadBinding)
	for _,mode in {'standalone','managed'}do
	local f=fixture();local diagnostics,observed={},{}
	f.Screen.AbsoluteSize=f.Vector2.new(1280,900);f.PlayerGui.AbsoluteSize=f.Vector2.new(1280,900)
	-- Native fixture Drain intentionally runs every queued future task. Keep
	-- author timers outside that queue so an author's interval is advanced
	-- explicitly instead of silently running forever during a click.
	local nativeDelay=f.Task.delay;local delayed={}
	f.Task.delay=function(seconds,callback,...)
		local args=table.pack(...)
		if seconds<.075 then return nativeDelay(math.max(0,seconds),function()callback(table.unpack(args,1,args.n))end)end
		local job={Due=f:Clock()+seconds,Callback=function()callback(table.unpack(args,1,args.n))end}
		table.insert(delayed,job);return job
	end
	local function advance(seconds)
		local goal=f:Clock()+seconds;while f:Clock()<goal do f.Task.wait()end
		local due={}
		for index=#delayed,1,-1 do
			local job=delayed[index]
			if job.Cancelled or job.Due<=f:Clock()then table.remove(delayed,index);if not job.Cancelled then table.insert(due,job)end end
		end
		table.sort(due,function(a,b)return a.Due<b.Due end)
		for _,job in due do if not job.Cancelled then f.Task.defer(job.Callback)end end
		f:Drain()
	end
	local sounds,videos={},{ }
	local peakVideoPlaying,videoLimitViolations=0,0
	local function playingVideoCount()
		local count=0;for _,video in videos do if not video.Destroyed and video.Playing then count+=1 end end;return count
	end
	local function mediaObject(class,parent,properties)
		if class=='VideoPlayer'then error('Native VideoFrame profile')end
		local object=f.Create(class,parent,properties)
		if class=='Sound'or class=='VideoFrame'then
			object.Playing=false;object.TimePosition=0;object.TimeLength=12;object.IsLoaded=true
			object.Resolution=f.Vector2.new(640,360)
			for _,name in {'Loaded','Played','Paused','Ended','DidLoop'}do object[name]=f.Signal()end
			-- BrowserNative has a shared no-op GUI :Play method, so these native
			-- transport methods must precede its metatable's method lookup.
			rawset(object,'Play',function(self)
				if class=='VideoFrame'and not self.Playing and playingVideoCount()>=2 then
					videoLimitViolations+=1;error('Native profile: at most two videos can play simultaneously')
				end
				self.Playing=true
				if class=='VideoFrame'then peakVideoPlaying=math.max(peakVideoPlaying,playingVideoCount())end
				self.Played:Fire()
			end)
			rawset(object,'Pause',function(self)self.Playing=false;self.Paused:Fire()end)
			rawset(object,'Stop',function(self)self.Playing=false;self.TimePosition=0 end)
			table.insert(if class=='Sound'then sounds else videos,object)
		end
		return object
	end
	local provider={PreloadAsync=function(_,objects)for _,object in objects do object.IsLoaded=true end end}
	local nativeInstance={new=function(class)return mediaObject(class)end}
	local factory={create=mediaObject,modifier=mediaObject}
	local services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,RunService=f.Run,Task=f.Task}
	local mediaServices={Task=f.Task,RunService=f.Run,ContentProvider=provider,Instance=nativeInstance,
		Content={none='content:none',fromUri=function(uri)return uri end},Input=f.Input,PlayerGui=f.PlayerGui,Factory=factory}
	local captures,stops,views=0,0,0
	local captureHost={}
	function captureHost:Capture(request)
		for _,name in request.Names do assert(name~='microphone','This page only asks for the configured camera')end
		captures+=1
		local descriptor={Kind='video',Id='annoying-camera-'..captures,Label='Fixture camera',Settings={width=640,height=360,frameRate=30}}
		local listeners={};local feed={Width=640,Height=360};descriptor.Source=feed
		descriptor.Subscribe=function(callback)listeners[callback]=true;return function()listeners[callback]=nil end end
		descriptor.Stop=function()
			if descriptor.Stopped then return end;descriptor.Stopped=true;stops+=1
			for callback in table.clone(listeners)do callback('ended')end;table.clear(listeners)
		end
		function feed:Mount(parent)
			local root=f.Create('Frame',parent,{Name='HTMLVirtualCamera',Size=f.UDim2.fromScale(1,1),BackgroundTransparency=0})
			local view={Root=root,Alive=true,Playing=false};views+=1
			function view:SetPlaying(value)self.Playing=value end
			function view:Destroy()if not self.Alive then return end;self.Alive=false;views-=1;root:Destroy()end
			return view
		end
		return {Tracks={descriptor}}
	end
	local renderer=loadRenderTree(factory);local trees={}
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local pageModule=loadHTMLPage({['Rendering/GuiFactory']=factory,
		['Rendering/RenderTree']={build=function(doc,root,diagnostic)local tree=renderer.build(doc,root,diagnostic,function(font)return font end);trees[doc]=tree;return tree end},
		['Layout/BlockLayout']=loadBlockLayout(overrides),['Input/Controller']=Controller,['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/IFrameRuntime']=loadIFrames(f.Task),['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,{GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then {GetPropertyChangedSignal=function()return f.Signal()end}else nil end},f)
	local hostModule=loadHost(f)
	local base='http://localhost:8000/annoying-site/index.html'
	local function site()
		local options=table.clone(source.Options or{})
		options.RenderWorkBudgetMS=0;options.Task=f.Task;options.InputServices=mediaServices
		options.Diagnostic=function(message)table.insert(diagnostics,tostring(message))end
		options.JavaScriptServices={Task=f.Task,RunService=f.Run,Clock=function()return f:Clock()end,
			AudioServices=mediaServices,VideoServices=mediaServices,MediaCaptureHost=captureHost,ScriptSources={['http://localhost:8000/annoying-site/app.js']=source.JavaScript},
			RuntimeCreated=function(_,page)table.insert(observed,page)end}
		return {HTML=source.HTML,Stylesheets={['styles.css']=source.CSS},Options=options}
	end
	local function resolver(address,reference)
		local resolved=URL.resolve(address,reference)
		if resolved.Path~='/annoying-site/index.html'then return nil end
		return {Kind='internal',URL=resolved.URL,Website=site()}
	end
	local engine=loadEngine(function(id)
		assert(not id:find('Browser',1,true)and not id:find('WindowManager',1,true),'Standalone page must remain independent of optional root modules')
		if id=='HTML/Parser'then return Parser elseif id=='WorkContext'then return WorkContext elseif id=='Rendering/HTMLPage'then return pageModule
		elseif id=='Rendering/StandaloneHost'then return hostModule elseif id=='Websites'then return {resolveURL=function()return{}end}else return{}end
	end)
	local function mountFamily()
		if mode=='standalone'then
			local target=f.Create('Frame',f.Screen,{Name='AnnoyingDesktop',Size=f.UDim2.fromOffset(1280,900),BackgroundTransparency=1})
			local website=site();local options=website.Options
			options.DocumentURL=base;options.Stylesheets=website.Stylesheets;options.IFrameResolver=resolver;options.FallbackServices=services
			options.FallbackWindow={Size=f.Vector2.new(620,460),Position=f.Vector2.new(30,30)}
			local main=engine.mountHTML(target,source.HTML,options);f:Drain();local host=assert(main.FallbackHost)
			return {Main=main,Host=host,Manager=host.Manager,Window=main.FallbackWindow,
				Children=function()
					local children={};for context in host.Contexts do if context~=host.Main then local page=host:GetPage(context.Window);if page and page.Alive then table.insert(children,{Page=page,Window=context.Window})end end end;return children
				end,
				Dialog=function()return host.Manager.Dialogs[1]end,
				ResponseGUI=function(accepted)local dialog=assert(host.Manager.Dialogs[1]);return if accepted then dialog.Accept else dialog.Reject end,
				Destroy=function()main:Destroy();target:Destroy();f:Drain()end}
		end
		local catalogEngine={URL=URL,Websites={}}
		function catalogEngine.Websites.names()return {'AnnoyingSite'}end
		function catalogEngine.Websites.url()return base end
		function catalogEngine.Websites.resolveURL(address,reference)local resolved=URL.resolve(address,reference);if resolved.Path=='/annoying-site/index.html'then resolved.Kind='internal';resolved.Name='AnnoyingSite'end;return resolved end
		function catalogEngine.Websites.get(name)assert(name=='AnnoyingSite');return site()end
		function catalogEngine.mountHTML(target,html,options)return pageModule.mount(target,html,options)end
		local manager=loadWindows(f).new(f.Screen,{Animations=false,Services=services})
		local host=loadManagedHost(f).new(manager,loadBrowser(f),loadBinding(f),catalogEngine,
			{Services=services,MediaCaptureHost=captureHost,PersistenceEnabled=false,HomeWebsite='AnnoyingSite',Diagnostic=function(message)table.insert(diagnostics,tostring(message))end})
		local record=host:Open(base,{Size=f.Vector2.new(620,460),Position=f.Vector2.new(30,30)});f:Drain()
		local main=assert(record.Binding:GetPage(record.Browser:GetActiveTab()))
		return {Main=main,Host=host,Manager=manager,Window=record.Window,
			Children=function()
				local children={};for window,candidate in host.Windows do if candidate~=record then local page=candidate.Binding:GetPage(candidate.Browser:GetActiveTab());if page and page.Alive then table.insert(children,{Page=page,Window=window})end end end;return children
			end,
			Dialog=function()
				local dialog=record.Browser.Overlays.Current;if not dialog then return nil end
				local title=dialog.Panel:FindFirstChild('DialogTitle');return {Kind=if title and title.Text=='Zugriff auf Geräte'then 'permission'else 'alert',Native=dialog}
			end,
			ResponseGUI=function(accepted)local dialog=assert(record.Browser.Overlays.Current);return assert(dialog.Panel:FindFirstChild(if accepted then 'DialogAccept'else 'DialogCancel'))end,
			Destroy=function()host:Destroy();manager:Destroy();f:Drain()end}
	end
	local family=mountFamily();local main,host=family.Main,family.Host
	local function run(page,js,drain)
		local ok,message=page.JavaScriptRuntime:Run(js);assert(ok,tostring(message));if drain~=false then f:Drain()end
		assert(#page.JavaScriptRuntime.Diagnostics==0,table.concat(page.JavaScriptRuntime.Diagnostics,' | '))
	end
	local function expect(page,js,message)
		run(page,'window.__siteCheck=('..js..');');assert(page.JavaScriptRuntime.Window.Get('__siteCheck')==true,message)
	end
	local function click(page,id)
		assert(Node.findById(page.Document,id),'Missing actual page control: '..id)
		run(page,'document.getElementById("'..id..'").click();')
	end
	local function clickNative(page,id)
		-- Match the real user route, including transient activation, release
		-- ownership and focus changes while Start opens its first popup.
		run(page,'document.getElementById("'..id..'").scrollIntoView({block:"center"});')
		local control=assert(page.FormModel:Resolve(assert(Node.findById(page.Document,id))))
		local gui=assert(control.Item.BoxGui or control.Item.Gui)
		local point=gui.AbsolutePosition+f.Vector2.new(gui.AbsoluteSize.X/2,gui.AbsoluteSize.Y/2)
		f.Input.Mouse=point;local input=f:Begin(gui,nil,point.X,point.Y)
		f.Input.InputEnded:Fire(input);f:Drain()
		assert(#page.JavaScriptRuntime.Diagnostics==0,table.concat(page.JavaScriptRuntime.Diagnostics,' | '))
	end
	local function activate(page)page.FormModel.UserActivationUntil=os.clock()+10 end
	local function respond(accepted)
		assert(family.Dialog(),'Expected a real native dialog')
		local gui=family.ResponseGUI(accepted)
		local p,s=gui.AbsolutePosition,gui.AbsoluteSize;local input=f:Begin(gui,nil,p.X+s.X/2,p.Y+s.Y/2);f.Input.InputEnded:Fire(input);f:Drain()
	end
	local function liveChildren()
		return family.Children()
	end
	assert(main.Alive and main.Root.Visible,'Current page mounts through the actual engine')
	expect(main,'typeof annoyingSite.start === "function" && !annoyingSite.getState().running','The shipped page exposes its integration API and starts idle')
	assert(#liveChildren()==0 and captures==0,'Loading the page cannot open windows or request a camera')
	clickNative(main,'start-button')
	expect(main,'annoyingSite.getState().running','Start enters the active state')
	expect(main,'!document.getElementById("soundtrack").paused && !document.getElementById("clip").paused','The actual Start handler begins the mapped sound and video')
	local soundAsset,videoAsset=false,false
	for _,sound in sounds do if sound.SoundId=='rbxassetid://93424997719572'and sound.Playing then soundAsset=true end end
	for _,video in videos do if video.Video=='rbxassetid://5608384572'and video.Playing then videoAsset=true end end
	local nativeAssets={}
	for _,sound in sounds do table.insert(nativeAssets,'sound='..tostring(sound.SoundId)..'/'..tostring(sound.Playing))end
	for _,video in videos do table.insert(nativeAssets,'video='..tostring(video.Video)..'/'..tostring(video.Playing))end
	run(main,'window.__mediaProbe=JSON.stringify({ready:document.getElementById("clip").readyState,network:document.getElementById("clip").networkState,error:document.getElementById("clip").error,status:document.getElementById("media-status").textContent});')
	local clipItem=trees[main.Document].MediaByNode[Node.findById(main.Document,'clip')]
	assert(soundAsset and videoAsset,'Actual media hosts receive the user-selected Roblox sound and mapped video IDs: '..table.concat(nativeAssets,', ')..'; '..tostring(main.JavaScriptRuntime.Window.Get('__mediaProbe'))..'; delayed='..#delayed..'; status='..tostring(main.Root:GetAttribute('Status'))..'; pending='..tostring(clipItem.PendingPlay)..'; itemplaying='..tostring(clipItem.Playing)..'; hasplayed='..tostring(clipItem.HasPlayed))
	local children=liveChildren();assert(#children==2,'Start opens exactly two owned real popups')
	assert(playingVideoCount()==2 and peakVideoPlaying==2 and videoLimitViolations==0,'Main and first popup use exactly two native video slots without a rejected third start: '..playingVideoCount()..'/'..peakVideoPlaying..'/'..videoLimitViolations)
	for _,popup in children do
		expect(popup.Page,'document.getElementById("clip").paused === (new URLSearchParams(location.search).get("n") !== "1")','Only the first numbered popup plays the clip')
		expect(popup.Page,'new URLSearchParams(location.search).get("n") === "1" || !document.getElementById("video-placeholder").hidden','Further popups retain the static cat preview')
	end
	local firstPosition,secondPosition=children[1].Window:GetPosition(),children[2].Window:GetPosition()
	assert(firstPosition.X~=secondPosition.X or firstPosition.Y~=secondPosition.Y,'The two initial popups are not stacked at the identical position')
	for _,popup in children do assert(popup.Window.Root.Visible and popup.Page.Root.Visible,'Both initial windows and their actual documents are painted')end
	local child=children[1].Page;local shell=children[1].Window
	expect(child,'annoyingSite.getState().child === true','The same actual source selects its compact popup view')
	assert(family.Dialog()and family.Dialog().Kind=='permission'and captures==0,'Start automatically opens one real camera permission dialog before capture')
	assert(family.Manager:GetFocused()==family.Window,'The automatic permission prompt owns the focused main window')
	advance(.11)
	assert(family.Dialog()and captures==0 and family.Manager:GetFocused()==family.Window,'A jumping-window tick cannot steal focus or dismiss a pending camera prompt')
	respond(false)
	expect(main,'!annoyingSite.getState().cameraActive','Blocked automatic permission does not invent an active camera')
	assert(captures==0 and views==0,'Blocked permission never reaches native capture')
	expect(main,'screen.availWidth > outerWidth && screen.availHeight > outerHeight','Screen metrics describe the desktop rather than the smaller browser viewport')
	local p=shell:GetPosition()
	family.Window:Focus();f:Drain()
	run(main,'window.__oldRandom=Math.random;Math.random=function(){return 0.9;};')
	advance(.11);local moved=shell:GetPosition()
	run(main,'window.__movementError=annoyingSite.getState().lastError;')
	assert(p.X~=moved.X and p.Y~=moved.Y and moved.X>500 and moved.Y>200,'The 100ms interval jumps on both axes across the desktop rather than the small browser: '..p.X..','..p.Y..' -> '..moved.X..','..moved.Y..'; '..tostring(main.JavaScriptRuntime.Window.Get('__movementError'))..'; native delayed='..#delayed..'; timers='..main.JavaScriptRuntime.EventLoop.TimerCount)
	for _,popup in children do assert(popup.Window.Root.ZIndex>family.Window.Root.ZIndex,'Every popup returns in front of the main window after it was focused')end
	assert(family.Manager:GetFocused()~=family.Window,'Jumping popups reclaim focus')
	run(main,'Math.random=function(){return 0.1;};')
	advance(.11);local jumpedAgain=shell:GetPosition()
	assert(math.abs(moved.X-jumpedAgain.X)>100 and math.abs(moved.Y-jumpedAgain.Y)>100,'The next 100ms tick makes another large jump on both axes')
	run(main,'Math.random=window.__oldRandom;')
	advance(4.1)
	expect(main,'annoyingSite.getState().tick > 0 && location.hash.length > 0','Author timer updates history/title on the actual page')
	assert(captures==0,'A denied automatic camera request never silently becomes a capture')
	activate(main);click(main,'popup-button');assert(#liveChildren()==3,'Manual popup control adds a third owned window')
	for _=1,6 do click(main,'popup-button')end
	assert(#liveChildren()==4,'The page enforces its four-popup limit independently of timer activity')
	assert(playingVideoCount()==2 and videoLimitViolations==0,'Additional manually opened windows do not request another native video slot')
	family.Window:Focus();f:Drain();activate(main)
	f.Task.spawn(function()run(main,'document.getElementById("alert-button").click();',false)end);f:Drain()
	assert(family.Dialog()and family.Dialog().Kind=='alert','The page alert handler reaches the native modal')
	respond(true)
	activate(main);click(main,'fullscreen-button')
	expect(main,'document.fullscreenElement === document.getElementById("activity")','The shipped fullscreen control uses the actual native host')
	click(main,'fullscreen-button');expect(main,'document.fullscreenElement === null','Fullscreen can be exited from the same page')
	activate(main);click(main,'camera-button')
	assert(not family.Dialog()and captures==0,'The explicit camera control respects the previously denied decision')
	-- A second fresh page family exercises the allow path independently of the
	-- intentional per-origin denied state above.
	click(main,'stop-button');assert(#liveChildren()==0,'Stop closes every popup owned by this page')
	assert(playingVideoCount()==0,'Stop releases both native video slots')
	expect(main,'!annoyingSite.getState().running && location.href === "'..base..'"','Stop restores the original same-document address')
	local before=main.DocumentURL;advance(35)
	assert(main.DocumentURL==before and #liveChildren()==0 and not family.Dialog(),'Stopped timers cannot later move history, reopen windows or show alerts')
	family.Destroy()
	assert(not host.Alive and not main.Alive and f:GlobalConnections()==0,'Stopped source releases the entire fallback family and native subscriptions')
	family=mountFamily();main=family.Main;host=family.Host
	activate(main);click(main,'start-button')
	assert(playingVideoCount()==2 and videoLimitViolations==0,'A fresh family starts the main clip and first popup clip')
	assert(family.Dialog()and family.Dialog().Kind=='permission'and captures==0,'A fresh family gets the automatic camera question on Start')
	respond(true)
	expect(main,'annoyingSite.getState().cameraActive','Allow resolves the actual page camera handler')
	assert(captures==1 and stops==0 and views==1,'Allow creates one live native feed view')
	click(main,'stop-button');assert(stops==1 and views==0,'Stop releases the running camera and native view')
	assert(playingVideoCount()==0,'Stopping camera playback also releases the two encoded clips')
	activate(main);click(main,'start-button')
	assert(playingVideoCount()==2 and videoLimitViolations==0,'Restart assigns the first numbered popup video slot again')
	assert(not family.Dialog()and captures==2 and views==1,'Saved permission automatically reopens capture on Start without a duplicate prompt')
	family.Destroy();advance(35)
	assert(stops==captures and views==0 and f:GlobalConnections()==0,'Page teardown stops every source and native listener')
	assert(playingVideoCount()==0 and peakVideoPlaying==2 and videoLimitViolations==0,'The full page lifecycle never exceeds the two-video native profile')
	for _,page in observed do assert(not page.Alive,'No mounted author realm survives family teardown')end
	assert(#diagnostics==0,'Actual page diagnostics: '..table.concat(diagnostics,' | '))
	print('AnnoyingSite actual Engine/HTMLPage/VM '..mode..': two popups, desktop jumps on both axes, focus, automatic camera, media, dialogs and teardown passed')
	end
end
