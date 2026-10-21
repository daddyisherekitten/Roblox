--!nonstrict
local Tokens=require(script.Parent.Tokens)
local Signal=require(script.Parent.Signal)
local Theme={}
local function readProperty(instance,property)return instance[property]end
function Theme.new(settings,services)
	services=services or {};settings=settings or {}
	local tweenService=services.Tween or services.TweenService or game:GetService('TweenService')
	local self={Alive=true,Tokens=Tokens.resolve(settings.Theme or settings.theme,settings.Accent or settings.accent),Changed=Signal.new(),Bindings={},Tweens={}}
	local function stop(instance,property)
		local propertyTweens=self.Tweens[instance]
		local record=propertyTweens and propertyTweens[property]
		if not record then return end
		for key,value in propertyTweens do if value==record then propertyTweens[key]=nil end end
		if record.Connection then record.Connection:Disconnect() end
		if record.Destroying then record.Destroying:Disconnect() end
		record.Tween:Cancel()
		if next(propertyTweens)==nil then self.Tweens[instance]=nil end
	end
	function self:Animate(instance,properties,duration)
		if not self.Alive or not instance then return nil end
		-- Repainting settled state needs neither a Tween nor its two connections.
		-- Pending transitions still pass through stop(): an equal current value
		-- may be heading somewhere else, so it must not bypass cancellation.
		local current=self.Tweens[instance];local settled=true
		for property,value in properties do
			local ok,actual=pcall(readProperty,instance,property)
			if not ok or current and current[property] or actual~=value then settled=false;break end
		end
		if settled then return nil end
		for property in properties do stop(instance,property) end
		local ok,tween=pcall(function()return tweenService:Create(instance,TweenInfo.new(duration or self.Tokens.DurationHover,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties)end)
		if not ok then for property,value in properties do pcall(function()instance[property]=value end) end;return nil end
		local record={Tween=tween};local map=self.Tweens[instance] or {};self.Tweens[instance]=map
		for property in properties do map[property]=record end
		record.Connection=tween.Completed:Connect(function()
			if record.Connection then record.Connection:Disconnect();record.Connection=nil end
			if record.Destroying then record.Destroying:Disconnect();record.Destroying=nil end
			for property,value in map do if value==record then map[property]=nil end end
			if next(map)==nil and self.Tweens[instance]==map then self.Tweens[instance]=nil end
		end)
		record.Destroying=instance.Destroying:Connect(function()for property in properties do stop(instance,property) end end)
		tween:Play();return tween
	end
	function self:Bind(instance,property,key)
		assert(self.Tokens[key]~=nil,'Unknown Wayline theme token: '..tostring(key))
		local record={Instance=instance,Property=property,Key=key,Alive=true}
		self.Bindings[record]=true;instance[property]=self.Tokens[key]
		local function unbind()
			if not record.Alive then return end
			record.Alive=false;self.Bindings[record]=nil;stop(instance,property)
			if record.Connection then record.Connection:Disconnect();record.Connection=nil end
			record.Instance=nil
		end
		record.Connection=instance.Destroying:Connect(unbind)
		return unbind
	end
	function self:Set(theme,accent)
		if not self.Alive then return end
		local nextTokens=Tokens.resolve(theme,accent)
		if nextTokens.Theme==self.Tokens.Theme and nextTokens.AccentName==self.Tokens.AccentName then return end
		for key,value in nextTokens do self.Tokens[key]=value end
		for record in self.Bindings do if record.Alive then self:Animate(record.Instance,{[record.Property]=self.Tokens[record.Key]},self.Tokens.DurationTheme) end end
		self.Changed:Fire(self.Tokens)
	end
	function self:Destroy()
		if not self.Alive then return end
		self.Alive=false
		for record in self.Bindings do if record.Connection then record.Connection:Disconnect() end;record.Instance=nil;record.Alive=false end
		table.clear(self.Bindings)
		local records={}
		for _,map in self.Tweens do for _,record in map do records[record]=true end end
		for record in records do if record.Connection then record.Connection:Disconnect() end;if record.Destroying then record.Destroying:Disconnect() end;record.Tween:Cancel() end
		table.clear(self.Tweens);self.Changed:Destroy()
	end
	return self
end
return Theme
