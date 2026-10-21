--!strict
return function(Parser: any,loadMediaRuntime: any,MediaBox: any)
	local spawned=0
	local MediaRuntime=loadMediaRuntime({spawn=function(callback)spawned+=1;callback()end})
	local function signal()
		local callbacks={}
		return {
			Connect=function(_,callback)
				local connection={Connected=true}
				function connection:Disconnect() self.Connected=false end
				table.insert(callbacks,{Connection=connection,Callback=callback})
				return connection
			end,
			Fire=function(_,...) for _,entry in callbacks do if entry.Connection.Connected then entry.Callback(...) end end end,
		}
	end
	local heartbeat=signal()
	-- Both Sound and VideoFrame expose Playing. Deliberately omit IsPlaying so
	-- false/paused states catch accidental reads of that nonexistent property.
	local sound={Playing=false,TimePosition=0,TimeLength=10,Loaded=signal(),Played=signal(),Paused=signal(),Ended=signal(),DestroyCalls=0}
	function sound:Play() self.Playing=true;self.Played:Fire() end
	function sound:Pause() self.Playing=false;self.Paused:Fire() end
	function sound:Destroy() self.DestroyCalls+=1 end
	local document=Parser.parse('<audio id="tone" controls><source src="tone.mp3"><track src="captions.vtt" kind="captions" srclang="en" label="English" default><track src="captions-de.vtt" kind="captions" srclang="de" label="Deutsch"></audio>')
	local node=document.Children[1]
	local item={Node=node,MediaKind='audio',Source='rbxassetid://12',SelectedSource='tone.mp3',Controls=true,Tracks={{Source='captions.vtt',Contents='WEBVTT\n\n00:00.500 --> 00:02.000\nCaption',Language='en',Label='English',Default=true},{Source='captions-de.vtt',Contents='WEBVTT\n\n00:00.500 --> 00:02.000\nUntertitel',Language='de',Label='Deutsch',Default=false}},
		Gui={},ControlsGui={AbsolutePosition={X=100,Y=50},AbsoluteSize={X=640,Y=44}},ControlsFocusStroke={},PlayGui={},PauseLeftGui={},PauseRightGui={},TimeGui={},ProgressGui={},SeekKnobGui={},SpeedGui={},MuteButtonGui={},MuteGui={},CaptionsGui={},VolumeGui={},VolumeFillGui={},VolumeKnobGui={},CaptionGui={},MissingGui={}}
	local eventsSeen={}
	local events={Emit=function(_,_,kind,data)table.insert(eventsSeen,{Kind=kind,Data=data})end}
	local cleanups={}
	local page={Alive=true,Document=document,AddCleanup=function(_,callback)table.insert(cleanups,callback)end}
	local preloadCalls=0
	local api=MediaRuntime.start(page,{MediaItems={item},MediaByNode={[node]=item}},events,function(message) error(message) end,
		{RunService={Heartbeat=heartbeat},ContentProvider={PreloadAsync=function(_,objects)preloadCalls+=1;assert(#objects==1 and objects[1]==sound)end},Instance={new=function(className)assert(className=='Sound');return sound end}})
	assert(spawned==1 and preloadCalls==1)
	assert(api:Resolve(node)==item and item.Sound==sound and sound.SoundId=='rbxassetid://12')
	assert(item.MuteGui.Image=='rbxassetid://96465568269125')
	assert(item.Captions and item.CaptionGui.Visible==false)
	api:Hover(item,{X=110,Y=60});assert(item.HoverAction=='toggle' and item.PlayGui.BackgroundTransparency==.86)
	local originalPaint,hoverPaints=MediaBox.paint,0
	MediaBox.paint=function(target)hoverPaints+=1;originalPaint(target)end
	for index=1,100 do api:Hover(item,{X=110+index%10,Y=60})end
	MediaBox.paint=originalPaint
	assert(hoverPaints==0,'Pointer motion within the same media action must not repaint unchanged controls')
	assert(not api:Begin(item,{X=110,Y=60}) and item.PressedAction=='toggle' and item.PlayGui.BackgroundTransparency==.72)
	api:Cancel();assert(item.PressedAction==nil)
	api:Activate(item,{X=110,Y=60})
	assert(sound.Playing and item.Playing and item.HasPlayed and eventsSeen[#eventsSeen].Kind=='play')
	assert(item.PlayGui.Text=='' and item.PauseLeftGui.Visible and item.PauseRightGui.Visible)
	sound.TimePosition=1;heartbeat:Fire(.11)
	assert(item.CaptionGui.Visible and item.CaptionGui.Text=='Caption' and item.ProgressGui.Size[1]==.1)
	api:Activate(item,{X=278,Y=60})
	assert(sound.TimePosition==5 and eventsSeen[#eventsSeen].Kind=='seeking')
	api:Activate(item,{X=530,Y=60})
	assert(sound.PlaybackSpeed==1.5 and item.PlaybackRate==1.5 and item.SpeedGui.Text=='1.5x' and eventsSeen[#eventsSeen].Kind=='ratechange')
	api:Activate(item,{X=580,Y=60})
	assert(item.Captions and item.ActiveTrackIndex==2)
	api:Activate(item,{X=580,Y=60})
	assert(not item.Captions and not item.CaptionGui.Visible)
	assert(api:Begin(item,{X=652,Y=60}))
	assert(api:Move({X=692,Y=60}))
	assert(api:Finish(item,{X=692,Y=60}))
	assert(sound.Volume==.5 and item.Volume==.5 and not item.Muted and eventsSeen[#eventsSeen].Kind=='volumechange')
	api:Activate(item,{X=620,Y=60})
	assert(item.Muted and sound.Volume==0 and item.Volume==.5 and item.VolumeFillGui.Size[1]==0 and item.MuteGui.Image=='rbxassetid://89066326142104' and eventsSeen[#eventsSeen].Kind=='volumechange')
	api:Activate(item,{X=620,Y=60})
	assert(not item.Muted and sound.Volume==.5 and item.VolumeFillGui.Size[1]==.5 and item.MuteGui.Image=='rbxassetid://96465568269125')
	api:Activate(item,{X=110,Y=60})
	assert(not sound.Playing and not item.Playing and eventsSeen[#eventsSeen].Kind=='pause')
	local playEvents,pauseEvents=0,0
	for _,entry in eventsSeen do if entry.Kind=='play' then playEvents+=1 elseif entry.Kind=='pause' then pauseEvents+=1 end end
	assert(playEvents==1 and pauseEvents==1,'Native media signals must not be emitted twice')
	page:PlayMedia('tone');assert(sound.Playing and page:GetMediaState('tone').Source=='tone.mp3')
	page:SetMediaPlaybackRate('tone',2);assert(sound.PlaybackSpeed==2 and page:GetMediaState('tone').PlaybackRate==2)
	page:SetMediaVolume('tone',.25);assert(sound.Volume==.25 and page:GetMediaState('tone').Volume==.25 and not item.Muted and item.MuteGui.Image=='rbxassetid://96465568269125')
	page:SetMediaTextTrack('tone','Deutsch');assert(page:GetMediaState('tone').TextTrack.Language=='de' and item.Captions)
	page:PauseMedia('tone');assert(not sound.Playing)
	sound.TimePosition=2;assert(api:Key(item,'Right') and sound.TimePosition==7)
	assert(api:Key(item,'Left') and sound.TimePosition==2)
	assert(api:Key(item,'Up') and math.abs(sound.Volume-.35)<.001)
	assert(api:Key(item,'M') and item.Muted and sound.Volume==0)
	assert(api:Key(item,'M') and not item.Muted and math.abs(sound.Volume-.35)<.001)
	sound.TimePosition=10;sound.Ended:Fire();assert(item.Ended and eventsSeen[#eventsSeen].Kind=='ended')
	api:Activate(item,{X=110,Y=60});assert(sound.Playing and sound.TimePosition==0 and not item.Ended)
	page:PauseMedia('tone')
	cleanups[1]();assert(sound.DestroyCalls==1 and item.Sound==nil)
	heartbeat:Fire(.2);assert(playEvents==1)

	local videoPlayingChanged=signal()
	local videoLoadedChanged=signal()
	local videoPlayer={IsPlaying=false,IsLoaded=false,TimePosition=0,TimeLength=20,DidEnd=signal(),PlayFailed=signal(),DestroyCalls=0,UnloadCalls=0,LoadCalls=0}
	function videoPlayer:GetPropertyChangedSignal(property)
		if property=='IsPlaying' then return videoPlayingChanged end
		assert(property=='IsLoaded');return videoLoadedChanged
	end
	function videoPlayer:LoadAsync() self.LoadCalls+=1;self.IsLoaded=true end
	function videoPlayer:Play() self.IsPlaying=true;videoPlayingChanged:Fire() end
	function videoPlayer:Pause() self.IsPlaying=false;videoPlayingChanged:Fire() end
	function videoPlayer:Unload() self.UnloadCalls+=1 end
	function videoPlayer:Destroy() self.DestroyCalls+=1 end
	local made={}
	local videoDocument=Parser.parse('<video id="film" controls preload="none" src="film.webm"></video>')
	local videoNode=videoDocument.Children[1]
	local fallback={Playing=false,Pause=function(self)self.Playing=false end}
	local layer={AbsoluteSize={X=1280,Y=720}}
	function layer:IsA(className)return className=='LayerCollector'end
	local originalPosition=UDim2.fromOffset(17,23)
	local originalSize=UDim2.fromOffset(640,360)
	local videoGui={Parent=layer,Position=originalPosition,Size=originalSize}
	function videoGui:IsA()return false end
	local videoItem={Node=videoNode,MediaKind='video',Source='rbxassetid://34',SelectedSource='film.webm',Controls=true,Tracks={},Gui=videoGui,AllowFullscreen=true,
		Style={Padding={0,0,0,0},Margin={0,0,0,0},BorderSize=0,Visibility='visible'},BoxWidth=640,BoxHeight=360,ContentWidth=640,ContentHeight=360,BoxGui={},
		VideoGui=fallback,VideoDisplay={Visible=false},ControlsGui={AbsolutePosition={X=0,Y=0},AbsoluteSize={X=640,Y=44}},ControlsFocusStroke={},PlayGui={},PauseLeftGui={},PauseRightGui={},TrackGui={},TimeGui={},ProgressGui={},SeekKnobGui={},SpeedGui={},MuteButtonGui={},MuteGui={},CaptionsGui={},FullscreenGui={},VolumeGui={},VolumeTrackGui={},VolumeFillGui={},VolumeKnobGui={},CaptionGui={},MissingGui={}}
	local videoCleanups={}
	local videoPage={Alive=true,Document=videoDocument,AddCleanup=function(_,callback)table.insert(videoCleanups,callback)end}
	local videoEvents={Emit=function()end}
	local videoApi=MediaRuntime.start(videoPage,{MediaItems={videoItem},MediaByNode={[videoNode]=videoItem}},videoEvents,function(message) error(message) end,
		{RunService={Heartbeat=signal()},ContentProvider={PreloadAsync=function()error('VideoPlayer must load itself')end},Content={fromUri=function(uri)return 'content:'..uri end},Instance={new=function(className)
			if className=='VideoPlayer' then return videoPlayer end
			if className=='Frame' then
				local sizeChanged=signal()
				local object={ClassName=className,AbsoluteSize={X=1280,Y=720},Destroyed=false}
				function object:GetPropertyChangedSignal(property)assert(property=='AbsoluteSize');return sizeChanged end
				function object:Destroy()self.Destroyed=true end
				return object
			end
			local object={ClassName=className,DestroyCalls=0};function object:Destroy()self.DestroyCalls+=1 end;table.insert(made,object);return object
		end}})
	assert(videoItem.UsingVideoPlayer and videoItem.VideoPlayer==videoPlayer and videoPlayer.VideoContent=='content:rbxassetid://34')
	assert(videoPlayer.PlaybackSpeed==1 and videoItem.VideoDisplay.Visible and not fallback.Visible and videoPlayer.LoadCalls==0 and not videoPage:GetMediaState('film').Loading)
	videoItem.Captions=true;videoItem.CaptionText='Bewegtes Testvideo.';MediaBox.paint(videoItem)
	assert(not videoItem.CaptionGui.Visible,'Captions must not cover an unplayed video poster')
	videoItem.Captions=false;videoItem.CaptionText=nil
	videoPage:SetMediaPlaybackRate('film',.5)
	assert(videoPlayer.PlaybackSpeed==.5 and videoPage:GetMediaState('film').PlaybackRate==.5)
	videoPage:PlayMedia('film');assert(videoPlayer.LoadCalls==1 and videoPlayer.IsPlaying and videoPage:GetMediaState('film').Playing)
	videoItem.Captions=true;videoItem.CaptionText='Bewegtes Testvideo.';MediaBox.paint(videoItem)
	assert(videoItem.CaptionGui.Visible,'Captions become visible after playback starts')
	videoItem.Captions=false;videoItem.CaptionText=nil
	videoPlayer.IsPlaying=false;videoPlayer.TimePosition=20;videoPlayer.DidEnd:Fire();assert(videoItem.Ended)
	videoPage:PlayMedia('film');assert(videoPlayer.IsPlaying and videoPlayer.TimePosition==0 and not videoItem.Ended)
	assert(videoPage:EnterMediaFullscreen('film') and videoPage:GetMediaState('film').Fullscreen and videoItem.Gui.Parent.ClassName=='Frame')
	assert(videoPage:ExitMediaFullscreen() and not videoPage:GetMediaState('film').Fullscreen and videoItem.Gui.Parent==layer and videoItem.Gui.Position==originalPosition and videoItem.Gui.Size==originalSize)
	videoCleanups[1]();assert(videoPlayer.DestroyCalls==1 and videoPlayer.UnloadCalls==1 and videoItem.VideoPlayer==nil)
	assert(#made==3 and made[1].ClassName=='Wire' and made[2].ClassName=='AudioDeviceOutput' and made[3].ClassName=='Wire')
	videoItem.Captions=true;videoItem.CaptionText='Ein absichtlich langer Untertitel, der bei einer schmalen Videobox innerhalb der Fläche bleiben muss.'
	for _,width in {320,328,430,480,560} do
		MediaBox.fullscreen(videoItem,width,180)
		videoItem.ControlsGui.AbsoluteSize={X=width,Y=44}
		local captionLeft=videoItem.CaptionGui.Position[1]
		local captionTop=videoItem.CaptionGui.Position[2]
		assert(videoItem.CaptionGui.Visible and videoItem.CaptionGui.Size[2]==26 and captionLeft>=0 and captionLeft+videoItem.CaptionGui.Size[1]<=width
			and captionTop>=0 and captionTop+videoItem.CaptionGui.Size[2]<=180-44,
			'Caption box must remain compact and inside the resized video above its controls')
		local trackEnd=videoItem.TrackGui.Position[1]+videoItem.TrackGui.Size[1]
		local timeStart=videoItem.TimeGui.Position[1]
		local timeEnd=timeStart+videoItem.TimeGui.Size[1]
		local speedStart=videoItem.SpeedGui.Position[1]
		local muteStart=videoItem.MuteButtonGui.Position[1]
		assert(timeStart-trackEnd==12 and videoItem.TimeGui.Size[1]==100,
			'Narrow media controls need a stable gap and readable time width')
		assert(videoItem.SpeedGui.Visible==(width>=430),
			'Playback speed must disappear when its allocated width is zero')
		assert(speedStart-timeEnd==(if width>=430 then 8 else 0) and muteStart>=speedStart+videoItem.SpeedGui.Size[1],
			'Time, speed and mute controls must have non-overlapping bounds')
		assert(videoItem.VolumeGui.Position[1]+videoItem.VolumeGui.Size[1]<=width,
			'Media controls must stay inside their bar')
		assert(MediaBox.action(videoItem,{X=trackEnd+4,Y=20})=='none',
			'The gap between timeline and time must not seek')
	end
	MediaBox.fullscreen(videoItem,80,90)
	assert(not videoItem.CaptionGui.Visible,'Captions must hide when there is not enough room to read them')
	print('Media runtime: audio/video play, pause, preload, hover/press, keyboard, draggable seek/volume, speed, mute, captions, fullscreen, time updates, API and cleanup passed')
end
