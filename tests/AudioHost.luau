--!strict
return function(AudioHost,Parser,Runtime,Events,loadMediaRuntime,MediaBox,loadRenderTree,HTMLScripts,FormModel)
	local function signal()
		local callbacks={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(callbacks,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(callbacks)do if entry[1].Connected then entry[2](...)end end end
		function api:Count()local n=0;for _,entry in callbacks do if entry[1].Connected then n+=1 end end;return n end
		return api
	end
	local function backend(page,tree)
		local tasks,sounds={},{};local heartbeat=signal();local calls=0
		local services={RunService={Heartbeat=heartbeat},Task={spawn=function(fn)table.insert(tasks,fn)end}}
		services.Instance={new=function(kind)
			assert(kind=="Sound");local sound={Playing=false,SoundId="",IsLoaded=false,TimePosition=0,TimeLength=12,DestroyCalls=0,StopCalls=0,Played=signal(),Paused=signal(),Ended=signal(),DidLoop=signal(),Loaded=signal()}
			function sound:Play()self.TimePosition=0;self.Playing=true;self.Played:Fire()end
			function sound:Pause()self.Playing=false;self.Paused:Fire()end
			function sound:Stop()self.Playing=false;self.TimePosition=0;self.StopCalls+=1 end
			function sound:Destroy()self.DestroyCalls+=1 end
			table.insert(sounds,sound);return sound
		end}
		services.ContentProvider={PreloadAsync=function(_,objects,callback)
			for _,object in objects do
				if object.SoundId==nil then continue end;calls+=1
				if object.SoundId=="rbxassetid://bad"then if callback then callback(object.SoundId,"Enum.AssetFetchStatus.Failure")end
				elseif object.SoundId=="rbxassetid://unloaded"then -- A successful return alone must not fake a loaded resource.
				else object.IsLoaded=true end
			end
		end}
		local adapter=AudioHost.new(page,tree,services)
		local function drain()while #tasks>0 do table.remove(tasks,1)()end end
		return adapter,services,drain,sounds,heartbeat,function()return calls end,tasks
	end
	do
		local page={Alive=true,Root={},ResolveAudio=function(raw)return ({['tone.ogg']='rbxassetid://good',['bad.ogg']='rbxassetid://bad',['unloaded.ogg']='rbxassetid://unloaded'})[raw]end}
		local adapter,_,drain,sounds,heartbeat,calls,tasks=backend(page,{MediaByNode={}})
		local node=Parser.parse('<audio/>').Children[1];local notifications={};local h=adapter:Open(node,function(e)table.insert(notifications,e)end)
		h:Load('https://audio.test/tone.ogg','tone.ogg',1);assert(#tasks==1 and #sounds==1);drain()
		assert(notifications[#notifications].Kind=='loaded'and calls()==1 and h.Sound.Parent==page.Root)
		h:Set('volume',.4);h:Set('muted',true);assert(h.Sound.Volume==0);h:Set('muted',false);assert(h.Sound.Volume==.4)
		h:Set('currentTime',5);h:Play(10);assert(h.Sound.Playing and h.Sound.TimePosition==5 and notifications[#notifications].Intent==10)
		h:Pause();h:Play(11);assert(h.Sound.TimePosition==5,'Play resumes instead of invoking Sound:Play and resetting the cursor')
		heartbeat:Fire(.1);local count=#notifications;heartbeat:Fire(.2);assert(#notifications==count+1 and notifications[#notifications].Kind=='timeupdate')
		h:Load('','tone.ogg',2);assert(#tasks==0 and calls()==1,'An already loaded mapped asset is reused without another preload')
		h:Load('','bad.ogg',3);drain();assert(notifications[#notifications].Kind=='error'and notifications[#notifications].Code==4)
		h.Sound.IsLoaded=false;h:Load('','unloaded.ogg',4);drain();assert(notifications[#notifications].Kind=='error')
		h:Load('','missing.ogg',5);assert(notifications[#notifications].Kind=='error'and #tasks==0)
		h:Load('','tone.ogg',6);h:Load('','tone.ogg',7);count=#notifications;drain();assert(#notifications==count+1 and notifications[#notifications].Generation==7,'Obsolete loads do not publish success')
		local item={Node=node};h:Attach(item);assert(item.Sound==sounds[1]);h:Detach(item);assert(item.Sound==nil and sounds[1].DestroyCalls==0)
		h:Load('','tone.ogg',8);adapter:Destroy();drain();adapter:Destroy()
		assert(sounds[1].DestroyCalls==1 and heartbeat:Count()==0 and node.AudioHostSession==nil and sounds[1].Ended:Count()==0)
	end
	for _,preload in {'auto','none'}do
		local document=Parser.parseDocument('<!doctype html><html><body><audio id="a" src="tone.ogg" controls preload="'..preload..'"></audio></body></html>')
		local node=require('DOM/Node').findById(document,'a')
		local item={Node=node,MediaKind='audio',Source='rbxassetid://good',SelectedSource='tone.ogg',Controls=true,Tracks={},Gui={},ControlsGui={AbsolutePosition={X=100,Y=50},AbsoluteSize={X=640,Y=44}},ControlsFocusStroke={},PlayGui={},PauseLeftGui={},PauseRightGui={},TimeGui={},ProgressGui={},SeekKnobGui={},SpeedGui={},MuteButtonGui={},MuteGui={},VolumeGui={},VolumeFillGui={},VolumeKnobGui={},MissingGui={}}
		local events=Events.new(error);local page={Alive=true,Root={},Document=document,Cleanups={},ResolveAudio=function(raw)return if raw=='tone.ogg'then'rbxassetid://good'else nil end}
		function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
		local tree={MediaItems={item},MediaByNode={[node]=item}}
		local adapter,services,drain,sounds,heartbeat,calls=backend(page,tree)
		local MediaRuntime=loadMediaRuntime(services.Task)
		local media=MediaRuntime.start(page,tree,events,error,services);drain()
		local original=assert(item.Sound);local initialLoads=if preload=='auto'then 1 else 0;assert(calls()==initialLoads and #sounds==1)
		local clock=0;local output={}
		local realm=Runtime.new(document,{URL='https://audio.test/index.html',Events=events,AudioAdapter=adapter,AudioEmitEvent=function(n,kind)events:Emit(n,kind,{}, {Bubbles=false,Cancelable=false})end,
			Clock=function()return clock end,Schedule=function()end,ApplyChanges=function()return false end,Console=function(_,message)table.insert(output,message)end})
		local function run(source)local ok,message=realm:Run(source);assert(ok,tostring(message))end
		local function pump()for _=1,16 do drain();clock+=.01;realm:PumpTasks();realm.EventLoop:Checkpoint()end end
		realm:Start();pump();assert(item.Sound==original and original.Parent==page.Root and calls()==initialLoads)
		local layoutPending=realm:HasPending()
		run([[var a=document.getElementById('a');var playCount=0,pauseCount=0;a.onplay=()=>playCount++;a.onpause=()=>pauseCount++;a.currentTime=3;]])
		if preload=='none'then media:Activate(item,{X=110,Y=60});pump();assert(calls()==1 and original.Playing,'Native Play overrides preload=none')end
		run([[a.play().then(()=>console.log('played',a.currentTime));]])
		pump();assert(original.Playing and item.Playing and item.HasPlayed and output[1]=='played 3')
		media:Activate(item,{X=110,Y=60});pump();run([[console.log(a.paused,a.currentTime,playCount,pauseCount);]])
		assert(output[2]=='true 3 1 1'and not original.Playing)
		media:Activate(item,{X=110,Y=60});pump();assert(original.Playing and original.TimePosition==3)
		page:SetMediaVolume('a',.25);page:SetMediaPlaybackRate('a',1.5);pump();run([[console.log(a.volume,a.playbackRate);a.muted=true;]])
		pump();assert(output[3]=='0.25 1.5'and original.Volume==0 and item.Muted and item.Volume==.25)
		page:PauseMedia('a');pump();page:PlayMedia('a');pump();assert(original.Playing)
		original.TimePosition=4;node.AudioHostSession:Control('seeking',{CurrentTime=8,PreviousTime=4});original.TimePosition=8;pump();original.TimePosition=9
		run([[if(a.played.length!==2||a.played.end(0)!==4||a.played.start(1)!==8||a.played.end(1)!==9)throw new Error('Native seeking cannot mark skipped time as played');]])
		assert(realm:HasPending()==layoutPending,'Playback, seek and volume do not enqueue DOM/layout changes')
		original.TimePosition=0;original.DidLoop:Fire(original.SoundId);pump();run([[if(a.played.end(1)!==12)throw new Error('A completed native loop retains the played tail');]])
		original.Playing=false;original.TimePosition=0;original.Ended:Fire(original.SoundId);pump();run([[console.log(a.ended,a.currentTime);]])
		assert(output[4]=='true 12'and item.Ended and item.CurrentTime==12,'Native cursor reset on ending cannot reset the browser media time')
		assert(page:GetMediaState('a').CurrentTime==12,'State reads preserve the ended cursor')
		run([[a.play().catch(()=>{});]]);pump();assert(original.Playing and original.TimePosition==0)
		original.Playing=false;original.TimePosition=0;original.Ended:Fire(original.SoundId);pump()
		media:Activate(item,{X=228,Y=70});pump();run([[if(a.ended||a.currentTime>=12)throw new Error('Seeking from the controls clears the ended state');]])
		local selectedTime=original.TimePosition;run([[a.play().catch(()=>{});]]);pump();assert(original.Playing and original.TimePosition==selectedTime)
		media:Remove({item});assert(item.Sound==nil and original.DestroyCalls==0 and original.Playing,'Detaching controls keeps playing Audio alive')
		local replacement={Node=node};node.AudioHostSession:Attach(replacement);assert(replacement.Sound==original)
		realm:Destroy();for _,cleanup in page.Cleanups do cleanup()end;events:Destroy()
		assert(original.DestroyCalls==1 and #realm.Diagnostics==0 and heartbeat:Count()==0)
	end
	for _,prefixed in {false,true}do
		local guis={};local factory={}
		function factory.create(kind,parent,properties)
			local gui=table.clone(properties);gui.Parent=parent;gui.Visible=gui.Visible~=false;gui.AbsoluteSize={X=640,Y=500};gui.AbsolutePosition={X=0,Y=0}
			function gui:Destroy()self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
			function gui:SetAttribute()end
			function gui:GetAttribute()return nil end
			table.insert(guis,gui);return gui
		end
		factory.modifier=factory.create
		local document=Parser.parseDocument('<!doctype html><html><body><audio id="a" '..(if prefixed then ''else 'src="tone.ogg"')..' style="display:block!important;width:200px;height:90px"></audio><p>Unchanged</p><script>window.audioPage=true;</script></body></html>')
		local renderer=loadRenderTree(factory);local tree=renderer.build(document,{AbsoluteSize={X=640,Y=500}},function()end,function(font)return font end)
		assert(#tree.MediaItems==0,'Audio without controls is invisible even when author CSS requests a box')
		local events=Events.new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
		local page={Alive=true,Root=tree.Gui,Document=document,DocumentURL='https://audio.test/index.html',Events=events,FormModel=model,Cleanups={},ResolveAudio=function(raw)return if raw=='tone.ogg'then'rbxassetid://good'else nil end}
		function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
		local adapter,services,drain,sounds,heartbeat,calls=backend(page,tree)
		local MediaRuntime=loadMediaRuntime(services.Task);local media=MediaRuntime.start(page,tree,events,error,services)
		tree.StructuralResourcesRemoving=function(removals)media:Remove(removals.Media or {})end
		function page:RefreshDOMResources()local changes=tree:TakeStructuralResourceChanges();media:Remove(changes.Media.Removed);media:Add(changes.Media.Added)end
		local realm=HTMLScripts.start(page,tree,function()end,error,{JavaScriptServices={AudioAdapter=adapter,Clock=function()return 0 end,Task={delay=function(_,fn)return {Callback=fn}end,cancel=function()end},RunService={Heartbeat=heartbeat,RenderStepped=signal()}}})
		local function pump()drain();for _=1,16 do realm:PumpTasks();realm.EventLoop:Checkpoint()end end
		local function run(source)local ok,message=realm:Run(source);assert(ok,tostring(message));realm:Flush();pump();assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,'\n'))end
		pump()
		if prefixed then run([[var original=document.getElementById('a'),replacement=document.createElementNS('http://www.w3.org/1999/xhtml','h:audio');replacement.id='a';replacement.src='tone.ogg';replacement.style.cssText=original.style.cssText;original.replaceWith(replacement);]])end
		assert(#sounds==1 and calls()==1)
		run([[var a=document.getElementById('a');a.play().catch(()=>{});a.controls=true;]])
		local audioNode=require('DOM/Node').findById(document,'a')
		assert(audioNode.Attributes.controls~=nil,'The reflected controls attribute is present')
		assert(#tree.MediaItems==1 and tree.MediaItems[1].Sound==sounds[1]and tree.MediaItems[1].ControlsGui and sounds[1].Playing,'Adding controls adopts the detached playing sound')
		run([[a.controls=false;]])
		assert(tree.NodeStyles[require('DOM/Node').findById(document,'a')].Hidden and sounds[1].Playing and #sounds==1)
		assert(#tree.MediaItems==0 and tree.MediaByNode[audioNode]==nil,'Audio controls off must remove its visual resource while preserving the shared playing Sound')
		run([[a.controls=true;]])
		assert(tree.MediaItems[1].Controls and tree.MediaItems[1].Sound==sounds[1]and #sounds==1 and calls()==1,'Repeated control toggles do not reload or replace the sound')
		run([[a.remove();]])
		assert(not sounds[1].Playing and sounds[1].DestroyCalls==0 and #sounds==1,'Stable DOM removal pauses the retained Sound without destroying or replacing it')
		run([[document.body.append(a);a.pause();]])
		assert(#tree.MediaItems==1 and tree.MediaItems[1].Sound==sounds[1]and not sounds[1].Playing)
		assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,'\n'))
		for _,cleanup in page.Cleanups do cleanup()end;events:Destroy();assert(sounds[1].DestroyCalls==1)
	end
	print('Audio host: loaded asset reuse, cursor-preserving play, honest failures, cancellation, shared native controls, detached playback, no layout invalidation and cleanup passed')
end
