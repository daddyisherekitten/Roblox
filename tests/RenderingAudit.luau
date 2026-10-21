--!strict
return function(Surface: any, Runtime: any, CanvasBackground: any, MediaBox: any)
	local function fails(callback: () -> (), fragment: string)
		local ok,message=pcall(callback)
		assert(not ok and tostring(message):find(fragment,1,true),"Expected "..fragment..", got "..tostring(message))
	end
	local visits=0
	local surface=Surface.new(20,20,function()visits+=1 end)
	surface:Arc(10,10,8,0,math.pi*2)
	assert(visits>0 and #surface.Current.Points>4,"Host path generation participates in the cooperative budget")
	local last=surface.Current.Points[#surface.Current.Points]
	assert(math.abs(last.X-18)<1e-6 and math.abs(last.Y-10)<1e-6,"Clockwise full turns close at their starting coordinate")
	surface:BeginPath();surface:Arc(10,10,8,0,-math.pi*2,true)
	assert(surface.Current.Points[2].Y<10,"Anticlockwise full turns preserve their direction")
	surface:BeginPath();surface:Arc(10,10,8,0,math.pi/2,true)
	last=surface.Current.Points[#surface.Current.Points]
	assert(surface.Current.Points[2].Y<10 and math.abs(last.X-10)<1e-6 and math.abs(last.Y-18)<1e-6,"An anticlockwise partial arc reaches the same endpoint along the longer direction")
	surface:BeginPath();surface:Arc(0,0,1,0,-1e20)
	assert(surface.PathPointCount<=8,"Huge reverse angles normalize in constant time")
	surface:BeginPath();surface:Arc(0,0,1,-1e308,1e308)
	assert(surface.PathPointCount<=8,"Finite endpoints whose difference overflows still produce one bounded turn")
	surface:BeginPath();surface:MoveTo(2,3)
	fails(function()surface:Arc(0,0,100000,0,math.pi*2)end,"point limit")
	assert(surface.PathPointCount==1,"An over-budget ellipse is rejected before appending partial geometry")
	for index=2,65536 do surface:LineTo(index,0)end
	fails(function()surface:LineTo(0,0)end,"point limit")
	assert(surface.PathPointCount==65536)
	surface:BeginPath();surface:LineTo(1,2)
	assert(surface.PathPointCount==1 and #surface.Path==1,"beginPath resets path storage accounting")
	local cancelled=Surface.new(8,8,function()error("cancelled path work")end)
	fails(function()cancelled:Arc(0,0,100,0,math.pi*2)end,"cancelled path work")
	assert(cancelled.PathPointCount==0,"A cancelled point checkpoint does not append geometry")
	local textSurface=Surface.new(8,8);textSurface:MoveTo(1,2);textSurface:LineTo(3,4)
	local originalPath=textSurface.Path
	textSurface:FillText("Hi",0,5)
	assert(textSurface.Path==originalPath and textSurface.PathPointCount==2,"Text drawing preserves the caller's path and its point budget")

	local function fixture(options: any)
		local node={Kind="Element",Name="canvas",Attributes={id="c",width="2",height="2"},Children={}}
		local stats={Created=0,Destroyed=0,SourceDestroyed=0,SourceReads=0,Writes=0,Assignments=0}
		local callbacks={}
		local page={Alive=not options.Dead,Document={Kind="Document",Children={node}}}
		function page:AddCleanup(callback)if self.Alive then table.insert(callbacks,callback)else callback()end end
		function page:Destroy()if not self.Alive then return end;self.Alive=false;for _,callback in callbacks do callback()end end
		local item={Node=node,ImageGui=setmetatable({},{__newindex=function(target,key,value)stats.Assignments+=1;rawset(target,key,value)end})}
		local imageItem={Node={Attributes={id="source"}},Source="rbxassetid://1"}
		local asset={}
		function asset:CreateEditableImage()
			stats.Created+=1
			if options.CancelCreate then page:Destroy()end
			return {WritePixelsBuffer=function()stats.Writes+=1;if options.FailUpload then error("injected upload failure")end end,Destroy=function()stats.Destroyed+=1 end}
		end
		function asset:CreateEditableImageAsync()
			if options.CancelSource then page:Destroy()end
			return {Size={X=2,Y=2},ReadPixelsBuffer=function()stats.SourceReads+=1;return buffer.create(16)end,Destroy=function()stats.SourceDestroyed+=1 end}
		end
		local ok,result=pcall(function()return Runtime.start(page,{CanvasItems={item},ImageItems=if options.Source then{imageItem}else{}},error,{Asset=asset})end)
		return page,stats,ok,result,item
	end
	local page,stats,ok,message=fixture({FailUpload=true})
	assert(not ok and tostring(message):find("injected upload failure",1,true) and stats.Destroyed==1,"Startup upload failure rolls back its allocated image immediately")
	page:Destroy();assert(stats.Destroyed==1,"Later page cleanup does not destroy a rolled-back image twice")
	page,stats,ok,message=fixture({Source=true,CancelSource=true})
	assert(not ok and tostring(message):find("cancelled",1,true) and stats.Destroyed==1 and stats.SourceDestroyed==1 and stats.SourceReads==0,"Cancellation during source acquisition releases both images without reading dead-page pixels")
	page,stats,ok,message=fixture({CancelCreate=true})
	assert(not ok and stats.Destroyed==1 and stats.Writes==0 and stats.Assignments==0,"A resource returned after page destruction is released before GUI publication")
	page,stats,ok,message=fixture({Dead=true})
	assert(not ok and stats.Created==0,"Already-dead pages cannot allocate new canvas resources")
	local item
	page,stats,ok,message,item=fixture({})
	assert(ok and page:GetCanvasContext("c")==item.CanvasSurface)
	page:Destroy();message:Destroy()
	assert(stats.Destroyed==1 and item.CanvasImage==nil and item.CanvasSurface==nil and page:GetCanvasContext("c")==nil,"Normal cleanup releases image, bitmap and id lookup ownership exactly once")

	local body={Kind="Element",Name="body",Children={}}
	local html={Kind="Element",Name="html",Children={body}}
	local document={Kind="Document",Children={html}}
	local original=Color3.fromRGB(10,20,30);local red=Color3.fromRGB(200,0,0)
	local root={BackgroundColor3=original,BackgroundTransparency=.4,Attributes={}}
	function root:SetAttribute(key,value)self.Attributes[key]=value end
	CanvasBackground.apply(root,document,{[html]={Background=red},[body]={Background=original}})
	assert(root.BackgroundColor3==red and root.Attributes.CanvasBackgroundSource=="html")
	CanvasBackground.apply(root,document,{[body]={Background=original,BackgroundAlpha=.7}})
	assert(root.BackgroundColor3==original and math.abs(root.BackgroundTransparency-.3)<1e-6 and root.Attributes.CanvasBackgroundSource=="body")
	CanvasBackground.apply(root,document,{})
	assert(root.BackgroundColor3==original and root.BackgroundTransparency==.4 and root.Attributes.CanvasBackgroundSource==nil,"Removing propagated backgrounds restores the configured root surface")
	CanvasBackground.apply(root,document,{[html]={DarkScheme=true}});CanvasBackground.apply(root,document,{})
	assert(root.BackgroundColor3==original and root.BackgroundTransparency==.4,"Leaving dark scheme also restores the custom root")
	root.BackgroundColor3=red;CanvasBackground.apply(root,document,{})
	assert(root.BackgroundColor3==red,"An inactive propagator leaves externally configured surface changes intact")

	local assignments,scalarAssignments=0,0
	local function gui()
		local values={AbsoluteSize={X=640,Y=44}}
		return setmetatable({},{__index=values,__newindex=function(_,key,value)
			assignments+=1;if key~="Size" and key~="Position" then scalarAssignments+=1 end;values[key]=value
		end})
	end
	local media={Duration=10,CurrentTime=2,Volume=1,ControlsWidth=640,ControlsHeight=44,AllowFullscreen=true,Source="asset",Tracks={}}
	for _,name in {"PlayGui","SpeedGui","CaptionsGui","FullscreenGui","MuteButtonGui","VolumeGui","ControlsFocusStroke","PauseLeftGui","PauseRightGui","TimeGui","ProgressGui","MuteGui","VolumeFillGui","TrackGui","SeekKnobGui","ControlsGui","VolumeKnobGui","CaptionGui","PosterGui","VideoDisplay","VideoGui","MissingGui"}do media[name]=gui()end
	MediaBox.paint(media);assignments,scalarAssignments=0,0;MediaBox.paint(media)
	-- CLI UDim2 tables lack native value equality; allow the four geometry fields.
	assert(scalarAssignments==0 and assignments<=4,"Identical media paints must avoid unchanged scalar property assignments")
	media.Playing=true;media.CurrentTime=5;media.HoverAction="toggle";media.Muted=true
	MediaBox.paint(media)
	assert(media.PlayGui.Text=="" and media.PlayGui.BackgroundTransparency==.86 and media.PauseLeftGui.Visible and media.TimeGui.Text=="0:05 / 0:10" and media.MuteGui.Image=="rbxassetid://89066326142104","Retained paint guards still apply changed playback, hover, time and mute states")
	print("Rendering audit: bounded cooperative paths, canvas startup rollback/cancellation, original canvas background and unchanged media paint passed")
end
