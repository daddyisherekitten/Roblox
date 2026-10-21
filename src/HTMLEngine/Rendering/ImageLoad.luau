--!strict
local ImageBox = require(script.Parent.ImageBox)
local ImageFallback = require(script.Parent.ImageFallback)
local ImageLoad = {}

-- Callers keep ownership of their arrays. Per-item registrations make late
-- completion harmless after removal, including a remove/reinsert of one item.
function ImageLoad.start(items: {any}?, alive: () -> boolean, diagnostic: (string) -> (), changed: (() -> ())?, services: any?): (()->(),any)
	local taskAPI=if services and services.Task then services.Task else task
	local registrations,disposed={},false
	local api={}
	local function managed(item)
		return services~=nil and services.IsDOMOwned~=nil and services.IsDOMOwned(item)==true
	end
	local function update(item,registration)
		if disposed or not alive() or registrations[item]~=registration then return end
		local resized=ImageFallback.refresh(item)
		ImageBox.updateFallback(item)
		if resized and changed then changed() end
	end
	function api:Add(additions: {any})
		if disposed then return end
		local captured={}
		for _,item in additions do
			if registrations[item] or not item.Source or not item.ImageGui then continue end
			local registration={Managed=managed(item)};if disposed or not alive()then return end;registrations[item]=registration;captured[item]=registration
			registration.Connection=item.ImageGui:GetPropertyChangedSignal("IsLoaded"):Connect(function()update(item,registration)end)
			update(item,registration)
		end
		if not next(captured) then return end
		taskAPI.defer(function()
			if disposed or not alive() then return end
			local targets,seen={},{}
			for item,registration in captured do
				if not registration.Managed and managed(item)then registration.Managed=true end
				if disposed or not alive()then return end
				if registrations[item]==registration and not registration.Managed and not seen[item.Source] then seen[item.Source]=true;table.insert(targets,item.ImageGui) end
			end
			if #targets==0 then return end
			local reported={}
			local provider=if services and services.ContentProvider then services.ContentProvider else game:GetService("ContentProvider")
			local ok,message=pcall(function()
				provider:PreloadAsync(targets,function(uri,status)
					if disposed or not alive() or status==Enum.AssetFetchStatus.Success or reported[uri] then return end
					reported[uri]=true;diagnostic("Image load failed: "..tostring(uri).." ("..status.Name.."); check the image asset ID and access permissions")
				end)
			end)
			if disposed or not alive() then return end
			for item,registration in captured do
				if registrations[item]==registration then if not registration.Managed then item.LoadFailed=reported[item.Source]==true end;update(item,registration) end
			end
			if not ok then diagnostic("Image preload failed: "..tostring(message)) end
		end)
	end
	function api:Remove(removals: {any})
		for _,item in removals do
			local registration=registrations[item];registrations[item]=nil
			if registration and registration.Connection then registration.Connection:Disconnect() end
		end
	end
	function api:Destroy()
		if disposed then return end;disposed=true
		for _,registration in registrations do if registration.Connection then registration.Connection:Disconnect() end end
		table.clear(registrations)
	end
	api:Add(items or {})
	return if next(registrations) then function()api:Destroy()end else nil,api
end
return ImageLoad
