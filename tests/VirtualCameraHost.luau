--!strict
-- Controlled scene/service ownership checks, not a Roblox pixel renderer.
return function(loadHost)
	local assertions=0
	local function check(value,label)assertions+=1;assert(value,label)end
	local function signal()
		local listeners={};local api={}
		function api:Connect(callback)
			local connection={Connected=true};listeners[connection]=callback
			function connection:Disconnect()self.Connected=false;listeners[self]=nil end
			return connection
		end
		function api:Fire(...)for connection,callback in table.clone(listeners)do if connection.Connected then callback(...)end end end
		function api:Count()local count=0;for _ in listeners do count+=1 end;return count end
		return api
	end
	local methods={};local made={};local shallowCopies=0
	local partClasses={Part=true,MeshPart=true,WedgePart=true}
	local function create(class)
		local data={ClassName=class,Name=class,Children={},Parent=nil,Attrs={},Visible=true,Enabled=true,Destroying=signal(),DescendantAdded=signal(),DescendantRemoving=signal(),
			CFrame='origin',WorldCFrame='world-origin',FieldOfView=70,Size=1,Color='white',Material='plastic',MaterialVariant='',Transparency=0,
			LocalTransparencyModifier=0,Reflectance=0,CastShadow=true,Shape='Block',Archivable=true}
		local object=setmetatable({_Instance=true,Data=data},{__index=function(_,key)return methods[key]or data[key]end,
			__newindex=function(self,key,value)
				if key=='Parent'then
					local old=data.Parent;if old==value then return end
					local moving={self};for _,child in self:GetDescendants()do table.insert(moving,child)end
					local ancestor=old;while ancestor do for _,node in moving do ancestor.DescendantRemoving:Fire(node)end;ancestor=ancestor.Parent end
					if old then local at=table.find(old.Children,self);if at then table.remove(old.Children,at)end end
					data.Parent=value;if value then table.insert(value.Children,self)end
					ancestor=value;while ancestor do for _,node in moving do ancestor.DescendantAdded:Fire(node)end;ancestor=ancestor.Parent end
				else data[key]=value end
			end})
		table.insert(made,object);return object
	end
	function methods:IsA(class)return class==self.ClassName or(class=='BasePart'and partClasses[self.ClassName]==true)or(class=='GuiObject'and(self.ClassName=='Frame'or self.ClassName=='ViewportFrame'))or(class=='LayerCollector'and self.ClassName=='ScreenGui')end
	function methods:IsDescendantOf(ancestor)local parent=self.Parent;while parent do if parent==ancestor then return true end;parent=parent.Parent end;return false end
	function methods:GetChildren()return table.clone(self.Children)end
	function methods:GetDescendants()local children={};local function walk(node)for _,child in node.Children do table.insert(children,child);walk(child)end end;walk(self);return children end
	function methods:GetAttribute(name)return self.Attrs[name]end
	function methods:SetAttribute(name,value)self.Attrs[name]=value end
	function methods:Clone()
		check(self.Archivable==true,'templates remain cloneable even if original is not archivable')
		local copy=create(self.ClassName)
		for key,value in self.Data do if key~='Parent'and key~='Children'and key~='Attrs'and type(value)~='table'then copy[key]=value end end
		for _,child in self:GetChildren()do local childCopy=child:Clone();childCopy.Parent=copy end
		return copy
	end
	function methods:Destroy()
		if self.Destroyed then return end;self.Destroyed=true;self.Destroying:Fire()
		for _,child in self:GetChildren()do child:Destroy()end
		self.Parent=nil
	end
	local datamodel=create('DataModel');local workspace=create('Workspace');workspace.Parent=datamodel
	local heartbeat=signal()
	local env={Game={GetService=function(_,name)return if name=='Workspace'then workspace else {Heartbeat=heartbeat}end},
		Instance={new=create,fromExisting=function(original)
			shallowCopies+=1
			check(original:IsA('BasePart')or original.ClassName=='Decal'or original.ClassName=='SpecialMesh','only visual whitelist is ever shallow copied')
			local copy=create(original.ClassName)
			for key,value in original.Data do if key~='Parent'and key~='Children'and key~='Attrs'and type(value)~='table'then copy[key]=value end end
			return copy
		end},Typeof=function(value)return if type(value)=='table'and value._Instance then 'Instance'else typeof(value)end,
		UDim2={fromScale=function(x,y)return {x,y}end},Color3={new=function(...)return {...}end,fromRGB=function(...)return {...}end},Vector3={new=function(...)return {...}end}}
	local Host=loadHost(env)
	local folder=create('Folder');folder.Parent=workspace
	local camera=create('Part');camera.Name='MyCamera';camera.CFrame='camera-one';camera.Parent=folder
	local part=create('MeshPart');part.Name='VisiblePart';part.Archivable=false;part.Parent=folder
	local childPart=create('Part');childPart.Parent=part
	local scriptChild=create('Script');scriptChild.Parent=part
	local sound=create('Sound');sound.Parent=part
	local decal=create('Decal');decal.Texture='first-texture';decal.Parent=part
	local scene=create('Folder');scene.Parent=workspace
	local selected=camera
	local host=Host.new({Camera=function()return selected end,Scene=folder,MaxParts=2,BuildBudget=2,FrameRate=30})
	local result,err=host:Capture({Names={'camera'},Constraints={video=true}})
	check(result and err==nil and #result.Tracks==1,'configured nested reference creates one video track')
	local track=result.Tracks[1];local source=track.Source
	check(track.Kind=='video'and track.ReadyState=='live'and not track.Stopped,'track has honest live state')
	check(track.Settings.width==640 and track.Settings.height==360 and track.Settings.frameRate==30,'resolution and frame rate metadata supplied')
	check(source.Width==640 and source.Height==360,'native source supplies renderer aspect metadata')
	local screen=create('ScreenGui');screen.Parent=datamodel
	local parent=create('Frame');parent.Parent=screen
	local view=source:Mount(parent)
	check(view.Root.ClassName=='ViewportFrame'and view.Root.Parent==parent,'mount creates one viewport in requested parent')
	check(view.Root.CurrentCamera~=camera and view.Camera.CFrame=='camera-one','isolated viewport camera copies configured camera pose')
	check(workspace.CurrentCamera==nil,'game camera is never reassigned')
	check(heartbeat:Count()==1,'one host heartbeat owns all views')
	for _=1,8 do heartbeat:Fire(1/30)end
	check(#view.World:GetChildren()==2,'part budget is enforced and both nested parts render')
	local copy=view.Copies[part]
	check(copy and copy.ClassName=='MeshPart'and copy.Archivable,'nonarchivable source can render safely')
	check(copy.Anchored and not copy.CanCollide and not copy.CanTouch and not copy.CanQuery,'copies never simulate or receive touch/query input')
	check(#copy:GetChildren()==1 and copy:GetChildren()[1].ClassName=='Decal','scripts sounds and unrelated descendants are absent')
	check(copy:GetChildren()[1].Texture=='first-texture','safe visual children copied')
	local copiesBefore=shallowCopies
	for _=1,8 do heartbeat:Fire(1/30)end
	check(shallowCopies==copiesBefore,'stable frames never reclone source scene')
	part.CFrame='moving-part';part.Color='red';part.Size=7;part.Transparency=.2;part.LocalTransparencyModifier=.5
	decal.Texture='second-texture';camera.CFrame='camera-two';camera:SetAttribute('FieldOfView',85)
	heartbeat:Fire(1/30)
	check(copy.CFrame=='moving-part'and copy.Color=='red'and copy.Size==7,'moving geometry and appearance update in place')
	check(math.abs(copy.Transparency-.6)<.000001,'local and ordinary transparency are combined')
	check(copy:GetChildren()[1].Texture=='second-texture','existing visual textures update without rebuilding')
	check(view.Camera.CFrame=='camera-two'and view.Camera.FieldOfView==85,'camera pose and local field of view update')
	view:SetPlaying(false);part.CFrame='paused-change';camera.CFrame='paused-camera';heartbeat:Fire(1/30)
	check(copy.CFrame=='moving-part'and view.Camera.CFrame=='camera-two','paused view remains frozen')
	local other=source:Mount(parent);heartbeat:Fire(1/30)
	check(heartbeat:Count()==1 and other.Camera.CFrame=='paused-camera','second view shares tracker and native heartbeat')
	check(other.Copies[part]and other.Copies[part]~=copy,'views own their independent world copies')
	view:SetPlaying(true);heartbeat:Fire(1/30)
	check(copy.CFrame=='paused-change'and view.Camera.CFrame=='paused-camera','resuming catches up from cached live scene')
	parent.Visible=false;part.CFrame='hidden-change';camera.CFrame='hidden-camera';heartbeat:Fire(1/30)
	check(copy.CFrame=='paused-change'and view.Camera.CFrame=='paused-camera','hidden GUI ancestry freezes sampling even when media keeps playing')
	parent.Visible=true;heartbeat:Fire(1/30)
	check(copy.CFrame=='hidden-change'and view.Camera.CFrame=='hidden-camera','revealing native view catches up')
	screen.Enabled=false;part.CFrame='disabled-screen';heartbeat:Fire(1/30)
	check(copy.CFrame=='hidden-change','disabled ScreenGui stops sampling without an invalid Visible member access')
	screen.Enabled=true;heartbeat:Fire(1/30)
	check(copy.CFrame=='disabled-screen','enabled ScreenGui resumes sampling')
	decal.Parent=nil;heartbeat:Fire(1/30)
	check(#view.Copies[part]:GetChildren()==0,'removed decorations are removed from views')
	local late=create('Decal');late.Texture='late';late.Parent=part;heartbeat:Fire(1/30)
	check(view.Copies[part]:GetChildren()[1].Texture=='late','added decorations appear')
	part.Parent=scene;for _=1,8 do heartbeat:Fire(1/30)end
	check(view.Copies[part]==nil and source.Count==0,'scene departures remove rigid parts and descendants')
	local added=create('Part');added.Parent=folder;for _=1,8 do heartbeat:Fire(1/30)end
	check(view.Copies[added]~=nil,'newly added scene geometry appears without a world rebuild')
	local ended=0;local off=track.Subscribe(function(reason)ended+=1;check(reason=='ended','ended callback reason')end)
	view:Destroy();view:Destroy();check(view.Root.Destroyed and not source.Stopped,'destroying one view does not stop its stream')
	other.Root:Destroy();check(not other.Alive,'external viewport destruction releases native view')
	local replacement=source:Mount(parent);check(replacement~=nil,'live track can mount again after its views disappear')
	camera.Parent=nil;heartbeat:Fire(1/30)
	check(track.ReadyState=='ended'and track.Stopped and source.Stopped and ended==1,'removing configured camera ends the capture once')
	check(replacement.Root.Destroyed and source:Mount(parent)==nil,'end retires views and prevents further mounting')
	check(heartbeat:Count()==0 and folder.DescendantAdded:Count()==0 and folder.DescendantRemoving:Count()==0,'end releases all host and scene connections')
	track.Stop();source:Stop();off();check(ended==1,'stop and unsubscribe are idempotent')
	local lateEnded=0;track.Subscribe(function()lateEnded+=1 end);check(lateEnded==1,'late subscribers observe ended state')
	local absent,absentError=host:Capture({Names={'camera'},Constraints={video=true}})
	check(not absent and absentError.Name=='NotFoundError','missing configured camera is an actionable error')
	camera.Parent=folder
	local audio,audioError=host:Capture({Names={'microphone'},Constraints={audio=true}})
	check(not audio and audioError.Name=='NotFoundError','microphone has no fake capture implementation')
	local combined,combinedError=host:Capture({Names={'camera','microphone'},Constraints={video=true,audio=true}})
	check(not combined and combinedError.Name=='NotFoundError'and heartbeat:Count()==0,'combined request fails atomically before opening video')
	local constrained=host:Capture({Names={'camera'},Constraints={video={width={exact=800},height={ideal=450},frameRate={ideal=60},deviceId={exact='roblox-camera'}}}})
	check(constrained.Tracks[1].Settings.width==800 and constrained.Tracks[1].Settings.height==450 and constrained.Tracks[1].Settings.frameRate==30,'supported constraints select bounded settings')
	constrained.Tracks[1].Stop()
	for _,constraints in{ {width={exact=9000}},{width={exact=800.5}},{frameRate={min=40}},{deviceId={exact='other'}},{facingMode={exact='user'}},{exposureTime={exact=1}},{aspectRatio={exact=9}} }do
		local rejected,rejection=host:Capture({Names={'camera'},Constraints={video=constraints}})
		check(not rejected and rejection.Name=='OverconstrainedError'and rejection.Constraint~=nil,'impossible required constraint rejects explicitly')
	end
	local final=host:Capture({Names={'camera'},Constraints={video=true}});host:Destroy();host:Destroy()
	check(final.Tracks[1].Stopped and heartbeat:Count()==0,'host teardown stops its remaining captures')
	local retired,retiredError=host:Capture({Names={'camera'},Constraints={video=true}})
	check(not retired and retiredError.Name=='InvalidStateError','destroyed host cannot capture')
	local missingSceneHost=Host.new({Camera=camera,Scene=function()return nil end})
	local missingScene,missingSceneError=missingSceneHost:Capture({Names={'camera'},Constraints={video=true}})
	check(not missingScene and missingSceneError.Name=='NotFoundError','explicit missing scene never silently broadens access to Workspace')
	missingSceneHost:Destroy()
	local rootHost=Host.new({Camera=camera,Scene=folder})
	local rootTrack=rootHost:Capture({Names={'camera'},Constraints={video=true}}).Tracks[1]
	folder.Parent=nil;heartbeat:Fire(1/30)
	check(rootTrack.Stopped and heartbeat:Count()==0,'removing an ancestor of the camera and scene ends track')
	rootHost:Destroy()
	print('PASS VirtualCameraHost ('..assertions..' assertions)')
end
