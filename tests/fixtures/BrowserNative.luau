--!strict
-- Controlled native services, explicit hit ordering and coroutine mount pauses.
-- This checks ownership and interaction; it is not a Roblox pixel renderer.
local function signal()
	local entries={};local api={}
	function api:Connect(fn)
		local entry={Connected=true,Callback=fn};table.insert(entries,entry)
		function entry:Disconnect()if not self.Connected then return end;self.Connected=false;self.Callback=nil;local at=table.find(entries,self);if at then table.remove(entries,at)end end
		return entry
	end
	function api:Fire(...)for _,entry in table.clone(entries)do if entry.Connected then entry.Callback(...)end end end
	function api:Count()return #entries end
	function api:Snapshot()local list={};for _,entry in entries do table.insert(list,entry.Callback)end;return list end
	function api:Clear()for _,entry in table.clone(entries)do entry:Disconnect()end end
	return api
end
return function()
	local UDim2={new=function(xs,xo,ys,yo)return {X={Scale=xs or 0,Offset=xo or 0},Y={Scale=ys or 0,Offset=yo or 0}}end}
	function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
	function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
	local Vector2={};local vectorMeta={}
	function Vector2.new(x,y)return setmetatable({X=x,Y=y},vectorMeta)end
	vectorMeta.__add=function(a,b)return Vector2.new(a.X+b.X,a.Y+b.Y)end
	vectorMeta.__sub=function(a,b)return Vector2.new(a.X-b.X,a.Y-b.Y)end
	vectorMeta.__mul=function(a,b)if type(a)=='number'then a,b=b,a end;return Vector2.new(a.X*b,a.Y*b)end
	vectorMeta.__div=function(a,b)return Vector2.new(a.X/b,a.Y/b)end
	vectorMeta.__index=function(a,key)if key=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y)end end
	Vector2.zero=Vector2.new(0,0)
	local Color3={};local colorMeta={__index={}}
	function Color3.new(r,g,b)return setmetatable({R=r,G=g,B=b},colorMeta)end
	function Color3.fromRGB(r,g,b)return Color3.new(r/255,g/255,b/255)end
	function colorMeta.__index:Lerp(other,alpha)return Color3.new(self.R+(other.R-self.R)*alpha,self.G+(other.G-self.G)*alpha,self.B+(other.B-self.B)*alpha)end
	local Enum=setmetatable({},{__index=function(t,k)local group=setmetatable({},{__index=function(s,name)rawset(s,name,name);return name end});rawset(t,k,group);return group end})
	local input={MouseIconEnabled=true,MouseEnabled=true,TouchEnabled=true,Mouse={X=0,Y=0},Keys={}}
	for _,name in {'InputBegan','InputChanged','InputEnded','WindowFocusReleased','WindowFocused'}do input[name]=signal()end
	function input:GetFocusedTextBox()return self.Focused end
	function input:IsKeyDown(key)return self.Keys[key]==true end
	function input:GetMouseLocation()return self.Mouse end
	function input:GetPropertyChangedSignal()return signal()end
	local run={RenderStepped=signal(),Heartbeat=signal()}
	local objects={};local methods={};local queue={};local time=0
	local tasks={}
	local function enqueue(fn,delay)local job={Callback=fn,Due=time+(delay or 0)};table.insert(queue,job);return job end
	function tasks.defer(fn,...)local args=table.pack(...);return enqueue(function()fn(table.unpack(args,1,args.n))end)end
	function tasks.spawn(fn,...)return tasks.defer(fn,...)end
	function tasks.delay(delay,fn)return enqueue(fn,delay)end
	function tasks.cancel(job)job.Cancelled=true end
	function tasks.wait()time+=.016;return .016 end
	local function isGui(object)return object.ClassName=='Frame'or object.ClassName=='ScrollingFrame'or object.ClassName:match('^Text')~=nil or object.ClassName:match('^Image')~=nil end
	local function dimension(value,axis,index,parent)
		local entry=value[axis]
		return if entry then parent*entry.Scale+entry.Offset else parent*(value[axis..'Scale']or 0)+(value[index]or 0)
	end
	local function size(object)
		local d=object.Data;if d.AbsoluteSize then return d.AbsoluteSize end
		local parent=if d.Parent then size(d.Parent)else Vector2.new(900,600)
		local value=d.Size or UDim2.new();return Vector2.new(dimension(value,'X',1,parent.X),dimension(value,'Y',2,parent.Y))
	end
	local function position(object)
		local d=object.Data;if d.AbsolutePosition then return d.AbsolutePosition end
		local parent=if d.Parent then position(d.Parent)else Vector2.new(0,0)
		local parentSize=if d.Parent then size(d.Parent)else Vector2.new(900,600)
		local value=d.Position or UDim2.new();local anchor=d.AnchorPoint or Vector2.new(0,0);local dim=size(object)
		local scroll=if d.Parent and d.Parent.ClassName=='ScrollingFrame'then d.Parent.CanvasPosition else Vector2.new(0,0)
		return Vector2.new(parent.X+dimension(value,'X',1,parentSize.X)-dim.X*anchor.X-scroll.X,parent.Y+dimension(value,'Y',2,parentSize.Y)-dim.Y*anchor.Y-scroll.Y)
	end
	local function notifySize(object)
		local s=object.Data.Props.AbsoluteSize;if s then s:Fire()end
		for _,child in table.clone(object.Data.Children)do notifySize(child)end
	end
	local function sameValue(a,b)
		if a==b then return true end
		if type(a)~='table'or type(b)~='table'then return false end
		if type(a.X)=='number'and type(b.X)=='number'then return a.X==b.X and a.Y==b.Y end
		if type(a.X)=='table'and type(b.X)=='table'then return a.X.Scale==b.X.Scale and a.X.Offset==b.X.Offset and a.Y.Scale==b.Y.Scale and a.Y.Offset==b.Y.Offset end
		if a.Scale~=nil and b.Scale~=nil then return a.Scale==b.Scale and a.Offset==b.Offset end
		return false
	end
	local function create(class,parent,props)
		local d={ClassName=class,Name=class,Children={},Attrs={},Props={},AttrSignals={},Visible=true,Enabled=true,Position=UDim2.new(),Size=UDim2.new(),AnchorPoint=Vector2.new(0,0),CanvasPosition=Vector2.new(0,0),ScrollBarThickness=10,Text='',BackgroundTransparency=1,BackgroundColor3=Color3.new(1,1,1)}
		for _,name in {'Destroying','FocusLost','Focused','InputBegan'}do d[name]=signal()end
		local object=setmetatable({Data=d},{__index=function(self,key)
			if methods[key]then return methods[key]end
			if key=='AbsoluteSize'then return size(self)elseif key=='AbsolutePosition'then return position(self)end
			if key=='AbsoluteCanvasSize'then local view=size(self);local canvas=d.CanvasSize or UDim2.new();return Vector2.new(dimension(canvas,'X',1,view.X),dimension(canvas,'Y',2,view.Y))end
			return d[key]
		end,__newindex=function(self,key,value)
			local old=d[key];if sameValue(old,value)then return end
			if key=='Parent'then
				if old then local at=table.find(old.Data.Children,self);if at then table.remove(old.Data.Children,at)end end
				if value then table.insert(value.Data.Children,self)end
			end
			d[key]=value;if d.Props[key]then d.Props[key]:Fire()end
			if key=='Size'or key=='AbsoluteSize'or key=='Parent'then notifySize(self)end
		end})
		table.insert(objects,object);for key,value in props or{}do object[key]=value end;object.Parent=parent;return object
	end
	function methods:IsA(class)return class==self.ClassName or (class=='GuiObject'and isGui(self))or(class=='LayerCollector'and self.ClassName=='ScreenGui')end
	function methods:GetChildren()return table.clone(self.Data.Children)end
	function methods:GetDescendants()local found={};local function walk(node)for _,child in node:GetChildren()do table.insert(found,child);walk(child)end end;walk(self);return found end
	function methods:FindFirstChild(name)for _,child in self:GetChildren()do if child.Name==name then return child end end end
	function methods:FindFirstChildOfClass(class)for _,child in self:GetChildren()do if child:IsA(class)then return child end end end
	function methods:IsDescendantOf(root)local current=self.Parent;while current do if current==root then return true end;current=current.Parent end;return false end
	function methods:GetFullName()return if self.Parent then self.Parent:GetFullName()..'.'..self.Name else self.Name end
	function methods:Play()self.Played=true end
	function methods:GetPropertyChangedSignal(name)local d=self.Data;d.Props[name]=d.Props[name]or signal();return d.Props[name]end
	function methods:GetAttributeChangedSignal(name)local d=self.Data;d.AttrSignals[name]=d.AttrSignals[name]or signal();return d.AttrSignals[name]end
	function methods:GetAttribute(name)return self.Data.Attrs[name]end
	function methods:SetAttribute(name,value)local d=self.Data;if d.Attrs[name]==value then return end;d.Attrs[name]=value;if d.AttrSignals[name]then d.AttrSignals[name]:Fire()end end
	function methods:IsFocused()return input.Focused==self end
	function methods:CaptureFocus()if input.Focused and input.Focused~=self then input.Focused:ReleaseFocus(false)end;input.Focused=self;self.Focused:Fire()end
	function methods:ReleaseFocus(enter)if input.Focused~=self then return end;input.Focused=nil;self.FocusLost:Fire(enter==true)end
	function methods:Destroy()
		if self.Destroyed then return end;self.Destroyed=true;self.DestroyCalls=(self.DestroyCalls or 0)+1;self.Destroying:Fire()
		if input.Focused==self then input.Focused=nil end
		for _,child in self:GetChildren()do child:Destroy()end
		for _,s in self.Data.Props do s:Clear()end;for _,s in self.Data.AttrSignals do s:Clear()end
		for _,name in {'Destroying','FocusLost','Focused','InputBegan'}do self.Data[name]:Clear()end;self.Parent=nil
	end
	local playerGui=create('PlayerGui',nil,{AbsoluteSize=Vector2.new(900,600)})
	local screen=create('ScreenGui',playerGui,{Name='Screen',AbsoluteSize=Vector2.new(900,600)})
	local hits={}
	function playerGui:GetGuiObjectsAtPosition()return hits end
	local api={Create=create,Input=input,Run=run,Task=tasks,Screen=screen,PlayerGui=playerGui,Signal=signal,Color3=Color3,UDim={new=function(s,o)return {Scale=s,Offset=o}end},UDim2=UDim2,Vector2=Vector2,Enum=Enum,Objects=objects}
	api.Instance={new=function(class)return create(class)end}
	api.TweenInfo={new=function(duration)return {Time=duration}end}
	local tweenService={}
	local activeTweens={}
	local function tweenValue(a,b,alpha)
		if type(a)=='number'and type(b)=='number'then return a+(b-a)*alpha end
		if type(a)=='table'and type(b)=='table'then
			if type(a.X)=='table'and type(b.X)=='table'then
				return UDim2.new(tweenValue(a.X.Scale,b.X.Scale,alpha),tweenValue(a.X.Offset,b.X.Offset,alpha),tweenValue(a.Y.Scale,b.Y.Scale,alpha),tweenValue(a.Y.Offset,b.Y.Offset,alpha))
			elseif type(a.X)=='number'and type(b.X)=='number'then return Vector2.new(tweenValue(a.X,b.X,alpha),tweenValue(a.Y,b.Y,alpha))
			elseif a.R and b.R then return a:Lerp(b,alpha)end
		end
		return if alpha>=1 then b else a
	end
	function tweenService:Create(object,info,goals)
		local tween={Completed=signal(),Starts={}}
		function tween:Sample(alpha)for key,value in goals do object[key]=tweenValue(self.Starts[key],value,alpha)end end
		function tween:Play()
			for key in goals do self.Starts[key]=object[key]end
			if api.DeferTweens then activeTweens[self]=true else self:Sample(1)end
			self.Job=tasks.delay(info.Time or 0,function()if not self.Cancelled then activeTweens[self]=nil;self:Sample(1);self.Completed:Fire('Completed')end end)
		end
		function tween:Cancel()if self.Cancelled then return end;self.Cancelled=true;activeTweens[self]=nil;if self.Job then tasks.cancel(self.Job)end;self.Completed:Fire('Cancelled')end
		return tween
	end
	function api:StepTweens(alpha)for tween in table.clone(activeTweens)do if activeTweens[tween]then tween:Sample(alpha)end end end
	local guid=0
	local nativeServices={TweenService=tweenService,ContentProvider={PreloadAsync=function()end},SoundService=create('SoundService'),
		HttpService={GenerateGUID=function()guid+=1;return 'fixture-guid-'..guid end},GuiService={GetGuiInset=function()return Vector2.zero end},
		ReplicatedStorage=create('ReplicatedStorage'),
		AssetService={CreateEditableImage=function()error('EditableImage unavailable in the headless fixture')end},
		TextService={GetTextSize=function(_,text,size,_font,bounds)local width=#text*size*.5;return Vector2.new(math.min(width,bounds.X),math.max(1,math.ceil(width/math.max(1,bounds.X)))*size*1.4)end},
		UserInputService=input,RunService=run,Players={LocalPlayer={WaitForChild=function()return playerGui end}},
	}
	api.Game={GetService=function(_,name)return nativeServices[name]end}
	function api:Hits(...)hits={...}end
	function api:Drain()
		local rounds=0;while #queue>0 do rounds+=1;assert(rounds<=1000,'Unbounded task loop');local job=table.remove(queue,1)
			if not job.Cancelled then time=math.max(time,job.Due);job.Thread=coroutine.create(job.Callback);local ok,message=coroutine.resume(job.Thread);assert(ok,message)end
		end
	end
	function api:Resume(thread)local ok,message=coroutine.resume(thread);assert(ok,message)end
	function api:Clock()return time end
	function api:Event(kind,x,y,key)return {UserInputType=kind,Position=Vector2.new(x or 0,y or 0),KeyCode=key}end
	function api:Begin(object,kind,x,y)local e=self:Event(kind or Enum.UserInputType.MouseButton1,x,y);self:Hits(object);input.InputBegan:Fire(e,false);return e end
	function api:Click(object)local e=self:Begin(object);input.InputEnded:Fire(e);return e end
	function api:GlobalConnections()local count=0;for _,name in {'InputBegan','InputChanged','InputEnded','WindowFocusReleased','WindowFocused'}do count+=input[name]:Count()end;return count+run.RenderStepped:Count()+run.Heartbeat:Count()end
	return api
end
