--!strict
local ImageFit=require(script.Parent.Parent.Layout.ImageFit)
local Responsive=require(script.Parent.Parent.HTML.ResponsiveSources)
local ImageDimensions={}
function ImageDimensions.start(items: {any}?,alive: ()->boolean,diagnostic: (string)->(),changed: ()->(),services: any?): (()->(),any)
	local groups,registrations,disposed={},{},false
	local taskAPI=if services and services.Task then services.Task else task
	local api={}
	local function assign(item,entry)
		item.PixelWidth,item.PixelHeight=entry.Width,entry.Height
		item.IntrinsicWidth,item.IntrinsicHeight=Responsive.intrinsicSize(entry.Width,entry.Height,item.SourceDensity)
	end
	local function request(source,entry)
		if disposed or not alive() or groups[source]~=entry or entry.State~="idle" then return end
		entry.State="loading"
		local function publish(ok,size)
			if disposed or not alive()or groups[source]~=entry then return end;entry.Cancel=nil
			entry.State=if ok then"ready"else"failed"
			if ok then
				entry.Width,entry.Height=size.X,size.Y;local resized=false
				for item in entry.Items do if registrations[item]==entry then
					local w,h=Responsive.intrinsicSize(entry.Width,entry.Height,item.SourceDensity)
					local different=item.IntrinsicWidth~=w or item.IntrinsicHeight~=h
					assign(item,entry);if different and not item.TextFallback then resized=true end
				end end
				if resized then changed()end
			else diagnostic("Image dimensions unavailable: "..source.."; using supplied dimensions or 300x150 fallback ("..tostring(size)..")")end
		end
		if services and services.LoadDimensions then
			local completed=false
			local function finish(ok,result)
				if completed then return end;completed=true
				if ok then
					local w,h=result and result.Width,result and result.Height
					if type(w)~="number"or type(h)~="number"or w~=w or h~=h or w<=0 or h<=0 or w>=math.huge or h>=math.huge then publish(false,"Invalid decoded image dimensions");return end
					publish(true,{X=w,Y=h})
				else publish(false,result)end
			end
			local ok,cancel=pcall(services.LoadDimensions,source,finish)
			if not ok then finish(false,cancel)elseif not completed and type(cancel)=="function"then entry.Cancel=cancel end
			return
		end
		taskAPI.defer(function()
			if disposed or not alive() or groups[source]~=entry then return end
			local editable
			local ok,size=pcall(function()
				local asset=if services and services.Asset then services.Asset else game:GetService("AssetService")
				editable=asset:CreateEditableImageAsync(Content.fromUri(source));assert(editable,"EditableImage allocation unavailable")
				local dimensions=editable.Size
				assert(dimensions.X>0 and dimensions.Y>0 and dimensions.X<math.huge and dimensions.Y<math.huge,"Invalid image dimensions")
				return dimensions
			end)
			if editable then editable:Destroy() end
			if disposed or not alive() or groups[source]~=entry then return end
			publish(ok,size)
		end)
	end
	function api:Add(additions: {any})
		if disposed then return end
		for _,item in additions do
			if registrations[item] or not item.Source then continue end
			-- DOM resources publish both pixel and density-corrected dimensions.
			-- Starting another metadata load would bypass lazy image deferral.
			if services and services.IsDOMOwned then
				local owned=services.IsDOMOwned(item)
				if disposed or not alive()then return end
				if owned then continue end
			end
			local source=item.Source;local entry=groups[source]
			if not entry then
				entry={Source=source,Items={},State="idle"};groups[source]=entry
				entry.Request=function()request(source,entry)end
			end
			registrations[item]=entry;entry.Items[item]=true;item.RequestDimensions=entry.Request
			if entry.State=="ready" then assign(item,entry) end
			if ImageFit.needsDimensions(item.Style) then entry.Request() end
		end
	end
	function api:Remove(removals: {any})
		for _,item in removals do
			local entry=registrations[item];registrations[item]=nil
			if not entry then continue end
			entry.Items[item]=nil;if item.RequestDimensions==entry.Request then item.RequestDimensions=nil end
			if not next(entry.Items) then groups[entry.Source]=nil;if entry.Cancel then pcall(entry.Cancel);entry.Cancel=nil end end
		end
	end
	function api:Destroy()
		if disposed then return end;disposed=true
		for _,entry in groups do if entry.Cancel then pcall(entry.Cancel);entry.Cancel=nil end end
		for item,entry in registrations do if item.RequestDimensions==entry.Request then item.RequestDimensions=nil end end
		table.clear(registrations);table.clear(groups)
	end
	api:Add(items or {})
	return if next(registrations) then function()api:Destroy()end else nil,api
end
return ImageDimensions
