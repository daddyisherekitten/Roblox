--!strict
-- Native resource bridge. Browser URLs remain author-facing; the page's explicit
-- asset/SVG mappings decide which resources Roblox can really decode.
local Sizing=require(script.Parent.Parent.SVG.Sizing)
local FontFamily=require(script.Parent.Parent.CSS.FontFamily)
local FontProfiles=require(script.Parent.Parent.Layout.FontProfiles)
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local ResourceLoadHost={}
function ResourceLoadHost.new(page: any,tree: any,services: any?): any
	services=services or{};local taskAPI=services.Task or task
	local api={Alive=true};local lifetime={Alive=true,Page=page};page=nil
	local requests={};local completed={};local completedOrder={};local subscribers={}
	local function alive()return lifetime.Alive and lifetime.Page~=nil and lifetime.Page.Alive end
	local function clear(listener)
		listener.Active=false;listener.Callback=nil;listener.Result=nil
	end
	local function cancel(listener)
		clear(listener);subscribers[listener]=nil
	end
	local function release(state)
		local target=state.Target;state.Target=nil
		if target then return pcall(function()target:Destroy()end)end
		return true
	end
	local function abandon(state)
		for _,subscriber in state.Listeners do cancel(subscriber)end
		table.clear(state.Listeners);state.Start=nil
	end
	local function defer(fn)taskAPI.defer(function()if alive()then fn()end end)end
	local function entry(key,start,callback)
		if not alive()then return function()end end
		local listener={Callback=callback,Active=true};subscribers[listener]=true
		local cached=completed[key]
		if cached then
			listener.Result=cached
			defer(function()
				local notify,result=listener.Callback,listener.Result
				cancel(listener)
				if notify and result and alive()then notify(result.Success,result.Value)end
			end)
			-- Retained cancellation handles own only their small subscription.
			return function()clear(listener)end
		end
		local state=requests[key]
		if not state then state={Listeners={},Key=key,Start=start};requests[key]=state end
		table.insert(state.Listeners,listener)
		if not state.Started then
			state.Started=true
			defer(function()
				local run=state.Start;state.Start=nil
				local ok,value=pcall(run,state)
				local released,releaseError=release(state)
				if not released then
					if requests[key]==state then requests[key]=nil end;abandon(state)
					error(releaseError,0)
				end
				if not alive()or requests[key]~=state then abandon(state);return end;requests[key]=nil
				-- Failure is not an available decoded resource. A later retry may
				-- succeed after asset permissions or the host's budget change.
				if ok then completed[key]={Success=true,Value=value};table.insert(completedOrder,key)
					if #completedOrder>128 then completed[table.remove(completedOrder,1)]=nil end
				end
				for _,subscriber in state.Listeners do
					local notify=subscriber.Callback;cancel(subscriber)
					if notify and alive()then
						local delivered,message=pcall(notify,ok,value)
						-- Preserve fail-fast exceptions after releasing the whole batch.
						if not delivered then abandon(state);error(message,0)end
					end
				end
				table.clear(state.Listeners)
			end)
		end
		return function()clear(listener)end
	end
	function api:LoadRasterDimensions(resolved,callback)
		if not alive()then return function()end end
		return entry("image\0"..resolved,function(state)
			assert(type(resolved)=="string"and resolved:match("^rbxassetid://%d+$"),"Expected a permitted Roblox raster asset URI")
			local native=services.CreateImageLabel and services.CreateImageLabel()or Instance.new("ImageLabel")
			state.Target=native;assert(alive(),"Resource host was disposed during image allocation");native.Image=resolved
			local provider=services.ContentProvider or game:GetService("ContentProvider");local failed=false
			local successStatus=services.AssetFetchSuccess or Enum.AssetFetchStatus.Success
			assert(alive(),"Resource host was disposed before image preload")
			provider:PreloadAsync({native},function(_,status)if status~=successStatus then failed=true end end)
			assert(not failed,"Roblox image asset preload failed")
			assert(alive(),"Resource host was disposed during image preload")
			local editable;local ok,size=pcall(function()
				local asset=services.AssetService or game:GetService("AssetService")
				editable=asset:CreateEditableImageAsync(Content.fromUri(resolved));assert(editable,"Native image decoding is unavailable")
				assert(alive(),"Resource host was disposed during image decoding")
				local dimensions=editable.Size;assert(dimensions.X>0 and dimensions.Y>0,"Decoded image has no dimensions");return dimensions
			end)
			if editable then editable:Destroy()end
			assert(ok,tostring(size))
			return {Width=size.X,Height=size.Y,Source=resolved}
		end,callback)
	end
	function api:LoadImage(url,callback,spec)
		if not alive()then return function()end end
		local owner=lifetime.Page
		local source=spec and spec.Source or url
		local resolved=owner.ResolveImage and owner.ResolveImage(source)
		if not alive()then return function()end end
		if not resolved and type(url)=="string"and url:match("^rbxassetid://%d+$")then resolved=url end
		if resolved then return self:LoadRasterDimensions(resolved,callback)end
		local sourceSVG=owner.ResolveSVG and owner.ResolveSVG(source)
		if not alive()then return function()end end
		return entry(if sourceSVG then"svg\0"..source else"missing\0"..url,function()
			assert(sourceSVG,"Image URL is not mapped to a permitted Roblox asset or packaged SVG")
			local w,h=Sizing.source(sourceSVG);return {Width=w,Height=h,SVG=sourceSVG,Source=source,URL=url}
		end,callback)
	end
	local function unquote(value)
		value=value:match("^%s*(.-)%s*$");local quote=value:sub(1,1)
		if (quote=='"'or quote=="'")and value:sub(-1)==quote then return value:sub(2,-2)end;return value
	end
	function api:LoadFont(spec,callback)
		if not alive()then return function()end end
		local requested=FontFamily.parse('"'..unquote(spec.Family):lower()..'"')
		local descriptors=spec.Descriptors or{};local source=spec.Source
		local name
		if type(source)=="string"then
			local cursor=1;while cursor<=#source do
				local part,nextCursor=Syntax.scan(source,cursor,",");cursor=nextCursor
				local localName=part:match("^%s*local%s*%((.-)%)%s*$")
				if localName then local candidate=FontFamily.parse('"'..unquote(localName):lower()..'"');if candidate and candidate==requested then name=candidate;break end end
			end
		end
		local weight=tonumber(descriptors.weight)or(if descriptors.weight=="bold"then 700 else 400)
		local style=descriptors.style or"normal";local key="font\0"..tostring(name).."\0"..weight.."\0"..style
		return entry(key,function(state)
			assert(name,"FontFace source needs a supported local family matching its CSS family; arbitrary WOFF/TTF decoding has no native adapter")
			assert(style=="normal"or style=="italic","Native font adapter supports normal and italic styles")
			assert(not tostring(descriptors.weight or""):find(" ",1,true),"Native font adapter does not decode variable font ranges")
			local face=if services.ResolveFont then services.ResolveFont(name,weight,style)else FontProfiles.face(name,weight,style)
			assert(alive(),"Resource host was disposed during font resolution")
			local label=services.CreateTextLabel and services.CreateTextLabel()or Instance.new("TextLabel");state.Target=label
			assert(alive(),"Resource host was disposed during font allocation");label.FontFace=face
			local provider=services.ContentProvider or game:GetService("ContentProvider");local failed=false
			local successStatus=services.AssetFetchSuccess or Enum.AssetFetchStatus.Success
			assert(alive(),"Resource host was disposed before font preload")
			provider:PreloadAsync({label},function(_,status)if status~=successStatus then failed=true end end)
			assert(not failed,"Roblox font asset preload failed");assert(alive(),"Resource host was disposed during font preload");return {Family=name,FontFace=face}
		end,callback)
	end
	function api:Destroy()
		if not self.Alive then return end;self.Alive=false
		lifetime.Alive=false;lifetime.Page=nil
		for listener in subscribers do clear(listener)end;table.clear(subscribers)
		local pending=requests;requests={}
		table.clear(completed);table.clear(completedOrder)
		-- An external destructor may throw. Try every owned target, then retain
		-- the existing observable exception instead of swallowing it.
		local hadError,firstError=false,nil
		for _,state in pending do
			state.Start=nil;table.clear(state.Listeners)
			local released,message=release(state);if not released and not hadError then hadError=true;firstError=message end
		end
		table.clear(pending)
		if hadError then error(firstError,0)end
	end
	return api
end
return ResourceLoadHost
