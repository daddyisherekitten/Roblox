--!strict
-- A virtual Roblox scene source. This never opens a physical device or changes
-- Workspace.CurrentCamera. Shallow copies keep scripts out of the render tree.
local VirtualCameraHost={}
local partProperties={'CFrame','Size','Color','Material','MaterialVariant','Transparency','Reflectance','CastShadow'}
local decorationProperties={
	Decal={'Texture','Color3','Transparency','Face'},
	Texture={'Texture','Color3','Transparency','Face','StudsPerTileU','StudsPerTileV','OffsetStudsU','OffsetStudsV'},
	SpecialMesh={'MeshType','MeshId','TextureId','Scale','Offset','VertexColor'},
	BlockMesh={'Scale','Offset','VertexColor'},CylinderMesh={'Scale','Offset','VertexColor'},
	SurfaceAppearance={'ColorMap','MetalnessMap','RoughnessMap','NormalMap','AlphaMode','Color'},
}
-- Sampling uses the same guarded whitelist without allocating a closure for
-- every property of every part on every sampled frame.
local function readProperty(object,key)return object[key]end
local function writeProperty(object,key,value)object[key]=value end
local function finite(value)return type(value)=='number'and value==value and math.abs(value)<math.huge end
local function bounded(value,default,minimum,maximum)
	return if finite(value)then math.clamp(value,minimum,maximum)else default
end
local function resolve(value)
	if type(value)=='function'then local ok,result=pcall(value);return if ok then result else nil end
	return value
end
local function instance(value)return typeof(value)=='Instance'end
local function attached(value)return instance(value)and value.Parent~=nil end
local function rootOf(value)
	local current=value
	while current.Parent do current=current.Parent end
	return current
end
local function descendant(value,root)return value==root or value:IsDescendantOf(root)end
local function cameraFrame(camera)
	if camera:IsA('Attachment')then return camera.WorldCFrame end
	return camera.CFrame
end
local function cameraKind(camera)
	return attached(camera)and(camera:IsA('BasePart')or camera:IsA('Camera')or camera:IsA('Attachment'))
end
local function visible(root)
	local current=root
	while current do
		if current:IsA('GuiObject')and not current.Visible then return false end
		if current:IsA('LayerCollector')and not current.Enabled then return false end
		current=current.Parent
	end
	return root.Parent~=nil
end
local function failure(name,message,constraint)return nil,{Name=name,Message=message,Constraint=constraint}end
local function constrain(value,default,minimum,maximum,name)
	local exact,ideal,low,high
	if finite(value)then ideal=value elseif type(value)=='table'then exact=value.exact;ideal=value.ideal;low=value.min;high=value.max end
	if finite(low)then minimum=math.max(minimum,low)end
	if finite(high)then maximum=math.min(maximum,high)end
	if minimum>maximum or(exact~=nil and(not finite(exact)or exact<minimum or exact>maximum))then
		return nil,{Name='OverconstrainedError',Message='The virtual camera cannot satisfy '..name..'.',Constraint=name}
	end
	return bounded(exact or ideal,math.clamp(default,minimum,maximum),minimum,maximum)
end
local function exactString(value)
	return if type(value)=='table'then value.exact else nil
end
local function accepts(value,wanted)
	if value==nil then return true end
	if type(value)=='table'then return table.find(value,wanted)~=nil end
	return value==wanted
end

function VirtualCameraHost.new(options)
	options=options or{}
	local workspaceService=game:GetService('Workspace')
	local runService=game:GetService('RunService')
	local self={Alive=true,Sources={}}
	local heartbeat=nil
	local function idle()
		if next(self.Sources)==nil and heartbeat then heartbeat:Disconnect();heartbeat=nil end
	end
	local function report(message)if type(options.Report)=='function'then pcall(options.Report,message)end end
	function self:Capture(request)
		if not self.Alive then return failure('InvalidStateError','The virtual camera host has been destroyed.')end
		if type(request)~='table'then return failure('TypeError','A camera capture request is required.')end
		local wantsVideo=false
		for _,name in request.Names or{}do
			if name=='microphone'then return failure('NotFoundError','No microphone capture source is configured.')end
			if name=='camera'then wantsVideo=true end
		end
		if not wantsVideo then return failure('TypeError','No video source was requested.')end
		local camera=resolve(options.Camera)
		if not cameraKind(camera)then return failure('NotFoundError','The configured Roblox camera was not found. Check Camera in the LocalScript.')end
		local scene=if options.Scene==nil then workspaceService else resolve(options.Scene)
		if not attached(scene)then return failure('NotFoundError','The configured Roblox camera scene is unavailable.')end
		local cameraRoot,sceneRoot=rootOf(camera),rootOf(scene)
		if type(Instance.fromExisting)~='function'then return failure('NotSupportedError','This Roblox version does not support safe shallow instance copies.')end
		local constraints=request.Constraints and request.Constraints.video
		constraints=if type(constraints)=='table'then constraints else{}
		local supported={width=true,height=true,aspectRatio=true,frameRate=true,deviceId=true,facingMode=true,resizeMode=true,advanced=true}
		for key,value in constraints do
			if not supported[key]and type(value)=='table'and(value.exact~=nil or value.min~=nil or value.max~=nil)then
				return failure('OverconstrainedError','The virtual camera does not implement '..key..'.',key)
			end
		end
		local id=tostring(options.DeviceId or'roblox-camera')
		for key,wanted in{deviceId=id,facingMode='environment',resizeMode='none'}do
			if not accepts(exactString(constraints[key]),wanted)then return failure('OverconstrainedError','The virtual camera cannot satisfy '..key..'.',key)end
		end
		local width,widthError=constrain(constraints.width,bounded(options.Width,640,16,4096),16,4096,'width')
		if not width then return nil,widthError end
		local height,heightError=constrain(constraints.height,bounded(options.Height,360,16,4096),16,4096,'height')
		if not height then return nil,heightError end
		for key,value in{width=width,height=height}do
			local constraint=constraints[key]
			if type(constraint)=='table'and constraint.exact~=nil and value%1~=0 then return failure('OverconstrainedError','The virtual camera requires integer '..key..'.',key)end
		end
		local frameRate,rateError=constrain(constraints.frameRate,bounded(options.FrameRate,30,1,60),1,bounded(options.FrameRate,30,1,60),'frameRate')
		if not frameRate then return nil,rateError end
		width,height=math.floor(width+.5),math.floor(height+.5)
		if constraints.aspectRatio~=nil then
			local ratio,ratioError=constrain(constraints.aspectRatio,width/height,width/height,width/height,'aspectRatio')
			if not ratio then return nil,ratioError end
		end
		local maxParts=math.floor(bounded(options.MaxParts,1500,1,10000))
		local budget=math.floor(bounded(options.BuildBudget,64,1,512))
		local source={Width=width,Height=height,Views={},Records={},Listeners={},Stopped=false,Elapsed=0,Count=0,Queue={},Queued={},Cursor=1}
		local descriptor={Kind='video',Id=id,Label=tostring(options.Label or camera.Name),Width=width,Height=height,ReadyState='live',Stopped=false,
			Settings={width=width,height=height,aspectRatio=width/height,frameRate=frameRate,deviceId=id,facingMode='environment',resizeMode='none'},Source=source}
		local connections={}
		local function queue(node)
			if source.Stopped or source.Queued[node]then return end
			source.Queued[node]=true;table.insert(source.Queue,node)
		end
		local function rescan()
			source.Queue={};source.Queued={};source.Cursor=1;queue(scene)
		end
		local function remove(part)
			local record=source.Records[part];if not record then return end
			source.Records[part]=nil;source.Count-=1;record.Template:Destroy()
			for view in source.Views do view.Removed[part]=true end
		end
		local function copyProperties(original,copy,properties,values)
			local changed=nil
			for _,key in properties do
				local ok,value=pcall(readProperty,original,key)
				if ok and value~=values[key]then
					values[key]=value
					local wrote=pcall(writeProperty,copy,key,value)
					if wrote then changed=changed or{};changed[key]=value end
				end
			end
			return changed
		end
		local function decorate(record)
			for _,child in record.Template:GetChildren()do child:Destroy()end
			record.Decorations={}
			for _,child in record.Original:GetChildren()do
				local properties=decorationProperties[child.ClassName]
				if properties then
					local ok,copy=pcall(Instance.fromExisting,child)
					if ok then
						copy.Archivable=true
						copy.Parent=record.Template
						table.insert(record.Decorations,{Original=child,Template=copy,Properties=properties,Values={}})
					end
				end
			end
			for view in source.Views do view.DirtyCopies[record.Original]=true end
		end
		local function add(part)
			if source.Records[part]or source.Count>=maxParts or part==camera or not part:IsA('BasePart')or not descendant(part,scene)then return end
			local ok,template=pcall(Instance.fromExisting,part)
			if not ok then report('Virtual camera could not copy '..part.Name);return end
			template.Archivable=true;template.Anchored=true;template.CanCollide=false;template.CanTouch=false;template.CanQuery=false;template.LocalTransparencyModifier=0
			local properties=table.clone(partProperties)
			if part:IsA('Part')then table.insert(properties,'Shape')elseif part:IsA('MeshPart')then table.insert(properties,'TextureID')end
			local record={Original=part,Template=template,Properties=properties,Values={},Decorations={}}
			source.Records[part]=record;source.Count+=1;decorate(record)
		end
		local function fieldOfView()
			local supplied=options.FieldOfView
			if supplied==nil then supplied=camera:GetAttribute('FieldOfView')end
			if supplied==nil and camera:IsA('Camera')then supplied=camera.FieldOfView end
			return bounded(supplied,70,1,120)
		end
		local function subscribe(callback)
			if source.Stopped then callback('ended');return function()end end
			local listener={Callback=callback};source.Listeners[listener]=true
			return function()source.Listeners[listener]=nil end
		end
		descriptor.Subscribe=subscribe
		function source:Subscribe(callback)return subscribe(callback)end
		function source:Stop()
			if self.Stopped then return end
			self.Stopped=true;descriptor.Stopped=true;descriptor.ReadyState='ended'
			for _,connection in connections do connection:Disconnect()end;table.clear(connections)
			for view in table.clone(self.Views)do view:Destroy()end
			for _,record in self.Records do record.Template:Destroy()end
			table.clear(self.Records);table.clear(self.Queue);table.clear(self.Queued);self.Count=0
			local listeners=self.Listeners;self.Listeners={}
			-- Retire first: an ended listener may synchronously create a new stream.
			for listener in listeners do local ok,message=pcall(listener.Callback,'ended');if not ok then report(message)end end
		end
		local host=self
		local stopSource=source.Stop
		function source:Stop()
			if self.Stopped then return end
			host.Sources[self]=nil;stopSource(self);idle()
		end
		descriptor.Stop=function()source:Stop()end
		function source:Mount(parent)
			if self.Stopped then return nil end
			local root=Instance.new('ViewportFrame');root.Name='HTMLVirtualCamera';root.Size=UDim2.fromScale(1,1)
			root.BackgroundColor3=Color3.new(0,0,0);root.BackgroundTransparency=0;root.BorderSizePixel=0;root.Active=false
			root.Ambient=options.Ambient or Color3.fromRGB(200,200,200)
			root.LightColor=options.LightColor or Color3.fromRGB(140,140,140)
			root.LightDirection=options.LightDirection or Vector3.new(-1,-1,-1)
			local viewportCamera=Instance.new('Camera');viewportCamera.CFrame=cameraFrame(camera);viewportCamera.FieldOfView=fieldOfView();viewportCamera.Parent=root
			root.CurrentCamera=viewportCamera
			local world=Instance.new('WorldModel');world.Name='CameraScene';world.Parent=root
			local view={Root=root,Camera=viewportCamera,World=world,Copies={},Decorations={},DirtyCopies={},Removed={},Playing=true,NeedsSync=true,Alive=true}
			local destroyedConnection
			function view:SetPlaying(value)
				if not self.Alive then return end
				local playing=value==true
				if playing and not self.Playing then self.NeedsSync=true end
				self.Playing=playing
			end
			function view:Destroy(external)
				if not self.Alive then return end
				self.Alive=false;source.Views[self]=nil
				if destroyedConnection then destroyedConnection:Disconnect();destroyedConnection=nil end
				table.clear(self.Copies);table.clear(self.Decorations);table.clear(self.DirtyCopies);table.clear(self.Removed)
				if not external then root:Destroy()end
			end
			destroyedConnection=root.Destroying:Connect(function()view:Destroy(true)end)
			self.Views[view]=true;root.Parent=parent
			return view
		end
		function source:Step(delta)
			if self.Stopped then return end
			if not cameraKind(camera)or not attached(scene)or rootOf(camera)~=cameraRoot or rootOf(scene)~=sceneRoot then self:Stop();return end
			self.Elapsed+=delta
			if self.Elapsed<1/frameRate then return end
			self.Elapsed=self.Elapsed%(1/frameRate)
			local playing=false
			for view in self.Views do
				local active=view.Playing and visible(view.Root)
				if active and not view.Active then view.NeedsSync=true end
				view.Active=active
				if active then playing=true end
			end
			if not playing then return end
			for view in self.Views do if view.Active then
				for part in view.Removed do
					local copy=view.Copies[part];if copy then copy:Destroy()end
					view.Copies[part]=nil;view.Decorations[part]=nil;view.DirtyCopies[part]=nil
				end
				table.clear(view.Removed)
			end end
			local work=0
			while self.Cursor<=#self.Queue and work<budget and self.Count<maxParts do
				local node=self.Queue[self.Cursor];self.Queue[self.Cursor]=false;self.Cursor+=1;work+=1
				if attached(node)and descendant(node,scene)then
					add(node)
					for _,child in node:GetChildren()do queue(child)end
				end
			end
			if self.Cursor>#self.Queue or self.Count>=maxParts then self.Queue={};self.Queued={};self.Cursor=1 end
			for part,record in self.Records do
				if not attached(part)or not descendant(part,scene)then remove(part)else
					if record.Dirty then record.Dirty=nil;decorate(record)end
					local changed=copyProperties(part,record.Template,record.Properties,record.Values)
					local transparency=1-(1-part.Transparency)*(1-part.LocalTransparencyModifier)
					if record.Template.Transparency~=transparency then record.Template.Transparency=transparency;changed=changed or{};changed.Transparency=transparency end
					local changedDecorations=nil
					for index,decoration in record.Decorations do
						local delta=copyProperties(decoration.Original,decoration.Template,decoration.Properties,decoration.Values)
						if delta then changedDecorations=changedDecorations or{};changedDecorations[index]=delta end
					end
					for view in self.Views do if view.Active then
						local copy=view.Copies[part]
						if copy and not view.DirtyCopies[part]then
							if view.NeedsSync then
								for _,key in record.Properties do copy[key]=record.Template[key]end
								copy.Transparency=record.Template.Transparency
							elseif changed then for key,value in changed do copy[key]=value end end
							local children=view.Decorations[part]
							for index,decoration in record.Decorations do
								local child=children and children[index]
								if child then
									local values=if view.NeedsSync then decoration.Values else changedDecorations and changedDecorations[index]
									if values then for key,value in values do pcall(writeProperty,child,key,value)end end
								end
							end
						end
					end end
				end
			end
			for view in self.Views do if view.Active then
				view.Camera.CFrame=cameraFrame(camera);view.Camera.FieldOfView=fieldOfView()
				local built=0
				for part,record in self.Records do
					local copy=view.Copies[part]
					if view.DirtyCopies[part]and built<budget then
						view.DirtyCopies[part]=nil
						if copy then copy:Destroy();copy=nil;view.Copies[part]=nil;view.Decorations[part]=nil end
					end
					if not copy and built<budget then
						copy=record.Template:Clone();copy.Parent=view.World;view.Copies[part]=copy;view.Decorations[part]=copy:GetChildren();built+=1
					end
				end
				view.NeedsSync=false
			end end
		end
		table.insert(connections,scene.DescendantAdded:Connect(function(node)
			if source.Count<maxParts then queue(node)end
			local record=source.Records[node.Parent];if record and decorationProperties[node.ClassName]then decorate(record)end
		end))
		table.insert(connections,scene.DescendantRemoving:Connect(function(node)
			if source.Records[node]then remove(node);rescan()end
			local record=source.Records[node.Parent]
			if record and decorationProperties[node.ClassName]then
				-- DescendantRemoving fires before Parent changes; defer the rebuild
				-- to the next sampled frame via a dirty record.
				record.Dirty=true
			end
		end))
		rescan();self.Sources[source]=true
		if not heartbeat then heartbeat=runService.Heartbeat:Connect(function(delta)
			for current in table.clone(self.Sources)do
				local ok,message=pcall(current.Step,current,delta)
				if not ok then report(message);current:Stop()end
			end
		end)end
		return {Tracks={descriptor}}
	end
	function self:Destroy()
		if not self.Alive then return end;self.Alive=false
		for source in table.clone(self.Sources)do source:Stop()end
		idle()
	end
	return self
end

return VirtualCameraHost
