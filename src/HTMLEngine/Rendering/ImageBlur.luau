--!strict
local Raster=require(script.Parent.ImageBlurPixels)
local ImageBox=require(script.Parent.ImageBox)
local Blur={}
function Blur.start(items: any,alive: any,diagnostic: any,changed: any): (() -> ())?
	local targets={}
	for _,item in items or {} do if item.Source and item.Style and item.Style.Filter and item.Style.Filter.HasRaster then table.insert(targets,item) end end
	local registered={};for _,item in targets do registered[item]={} end
	local sources,cache,pending,failed={},{},{},{}
	local sourcePixels,resultPixels,count=0,0,0
	local disposed,running=false,false
	local lastYield=os.clock()
	local function live() return not disposed and alive() end
	local function check()
		if not live() then return false end
		if os.clock()-lastYield>=.004 then task.wait(); lastYield=os.clock() end
		return live()
	end
	local function load(source: string): any
		if sources[source]~=nil then return sources[source] or nil end
		local original
		local ok,result=pcall(function()
			original=game:GetService("AssetService"):CreateEditableImageAsync(Content.fromUri(source))
			assert(original,"EditableImage allocation unavailable")
			if not live() then return nil end
			local size=original.Size; local pixels=size.X*size.Y
			assert(size.X>0 and size.Y>0 and size.X<=1024 and size.Y<=1024 and sourcePixels+pixels<=4194304,"Raster filter source budget reached")
			local bytes=original:ReadPixelsBuffer(Vector2.new(0,0),size)
			sourcePixels+=pixels
			return {Size=size,Pixels=bytes}
		end)
		if original then original:Destroy() end
		if not live() then return nil end
		sources[source]=if ok then result or false else false
		if not ok then diagnostic("Image raster filter unavailable: "..source.."; original retained ("..tostring(result)..")") end
		return if ok then result else nil
	end
	local function room(pixels: number)
		for key,entry in cache do
			if count<16 and resultPixels+pixels<=4194304 then break end
			local referenced=false
			for _,item in targets do if item.BlurKey==key then referenced=true; break end end
			if not referenced then entry.Image:Destroy(); resultPixels-=entry.Pixels; count-=1; cache[key]=nil end
		end
		assert(count<16 and resultPixels+pixels<=4194304,"Raster filter result budget reached")
	end
	local function install(item: any,key: string,entry: any)
		local fallback=item.TextFallback
		item.FilterReady,item.BlurReady=true,true
		local ok,message=pcall(function() item.BlurGui.ImageContent=entry.Content end)
		if not ok then
			item.FilterReady,item.BlurReady=nil,nil
			ImageBox.arrange(item)
			error(message)
		end
		item.BlurKey=key; item.TextFallback=false
		ImageBox.updateFallback(item); ImageBox.arrange(item)
		if fallback then changed() end
	end
	local schedule
	local function refresh(item: any)
		if not live() or not registered[item] then return end
		local source=sources[item.Source]
		if source==false then return end
		if source then
			local plan=Raster.plan(item,source.Size)
			if not plan then return end
			local key=item.Source.."|"..plan.Key
			if key==item.BlurKey or failed[key] then return end
		end
		pending[item]=true; schedule()
	end
	schedule=function()
		if running or not live() then return end
		running=true
		task.defer(function()
			while live() and next(pending) do
				local item=next(pending); pending[item]=nil
				local registration=registered[item];if not registration then continue end
				local source=load(item.Source)
				if not source or not live() or registered[item]~=registration then continue end
				local plan=Raster.plan(item,source.Size)
				if not plan then continue end
				local key=item.Source.."|"..plan.Key
				if failed[key] then continue end
				local image
				local ok,message=pcall(function()
					local entry=cache[key]
					if not entry then
						local pixels=plan.Width*plan.Height
						room(pixels)
						local bytes=Raster.render(source.Pixels,source.Size,item.Style.Filter,plan,check)
						if not bytes or not live() or registered[item]~=registration then return end
						-- A resize during the cooperative job supersedes this result.
						local current=Raster.plan(item,source.Size)
						if not current or current.Key~=plan.Key then pending[item]=true; return end
						image=game:GetService("AssetService"):CreateEditableImage({Size=Vector2.new(plan.Width,plan.Height)})
						assert(image,"EditableImage allocation unavailable")
						if not live() or registered[item]~=registration then return end
						image:WritePixelsBuffer(Vector2.new(0,0),Vector2.new(plan.Width,plan.Height),bytes)
						entry={Image=image,Content=Content.fromObject(image),Pixels=pixels}
						cache[key]=entry; image=nil; resultPixels+=pixels; count+=1
					end
					if registered[item]==registration then install(item,key,entry) end
				end)
				if image then image:Destroy() end
				if not ok and live() and registered[item]==registration then
					failed[key]=true
					item.BlurReady,item.FilterReady,item.BlurKey=nil,nil,nil
					ImageBox.updateFallback(item); ImageBox.arrange(item)
					diagnostic("Image raster filter unavailable: "..item.Source.."; original retained ("..tostring(message)..")")
				end
			end
			running=false
		end)
	end
	for _,item in targets do item.UpdateBlur=function() refresh(item) end; refresh(item) end
	local api={}
	function api:Add(additions: {any})
		if disposed then return end
		for _,item in additions do
			if registered[item] or not item.Source or not (item.Style and item.Style.Filter and item.Style.Filter.HasRaster) then continue end
			registered[item]={};table.insert(targets,item);item.UpdateBlur=function()refresh(item)end;refresh(item)
		end
	end
	function api:Remove(removals: {any})
		for _,item in removals do
			registered[item]=nil;pending[item]=nil;item.UpdateBlur=nil
			local index=table.find(targets,item);if index then table.remove(targets,index) end
			item.BlurKey=nil;item.BlurReady=nil;item.FilterReady=nil
		end
		for key,entry in cache do
			local referenced=false;for _,item in targets do if item.BlurKey==key then referenced=true;break end end
			if not referenced then entry.Image:Destroy();resultPixels-=entry.Pixels;count-=1;cache[key]=nil end
		end
	end
	function api:Destroy()
		if disposed then return end
		disposed=true
		for _,item in targets do item.UpdateBlur=nil end
		for _,entry in cache do entry.Image:Destroy() end
		table.clear(cache); table.clear(sources); table.clear(pending); table.clear(targets); table.clear(failed);table.clear(registered)
	end
	return if next(registered) then function()api:Destroy()end else nil,api
end
return Blur
