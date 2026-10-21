--!strict
-- Local background SVGs share the retained, budgeted SVG raster queue.
local SVG={}
function SVG.new(resolve,root,options,report)
	options=options or {};local queue,Embedded;local live={};local alive=true;local api={}
	local function initialize(current)
		if queue then return true end
		local Queue=require(script.Parent.Parent.SVG.RenderQueue)
		local Raster=require(script.Parent.Parent.SVG.Raster);Embedded=require(script.Parent.Parent.SVG.Embedded)
		if not current()then return false end
		if queue then return true end
		queue=Queue.new(options.Asset or game:GetService('AssetService'),Raster,options.Task or task,{LoadingWork=options.LoadingWork,CacheBytes=options.CacheBytes,CacheEntries=options.CacheEntries,Report=report,VisibleChanged=function(ready)
			if root and root.SetAttribute then root:SetAttribute('BackgroundVisibleReady',ready)end
		end})
		return true
	end
	function api:Draw(slot,source,width,height,fit,ownerCurrent)
		if not alive then return false end
		local request={Image=slot.Image,Current=ownerCurrent};live[slot]=request
		local function current()return alive and live[slot]==request and(not ownerCurrent or ownerCurrent())end
		local ok,node=pcall(function()return resolve and resolve(source)end)
		if not current()then return false end
		if not ok then
			self:Remove(slot)
			if alive and(not ownerCurrent or ownerCurrent())and slot.Image==request.Image then
				slot.Image.Image='';slot.Image.ImageTransparency=1
				report('background-image: invalid SVG source '..source..': '..tostring(node))
			end
			return true
		end
		if not node then self:Remove(slot);return false end
		if not initialize(current)or not current()then return false end
		if fit=='cover'or fit=='contain'then
			local a=node.Attributes;local nw,nh=tonumber(a.width),tonumber(a.height)
			if not nw or not nh then local parts={};for value in (a.viewBox or''):gmatch('[%+%-]?[%d%.]+')do table.insert(parts,tonumber(value))end;if #parts==4 then nw,nh=parts[3],parts[4]end end
			if nw and nh and nw>0 and nh>0 then height=width*nh/nw end
		end
		width,height=math.max(1,math.round(width)),math.max(1,math.round(height))
		local key=source..':'..width..'x'..height;request.Key=key
		queue:Request(slot,key,function()return Embedded.build(Embedded.document(node,true),width,height)end,function(image)
			local latest=live[slot]
			-- An unchanged redraw can reuse the queued request/its install closure.
			if alive and latest and latest.Key==key and latest.Image==slot.Image and(not latest.Current or latest.Current())then
				slot.Image.Image='';slot.Image.ImageContent=Content.fromObject(image);slot.Image.ImageTransparency=0
			end
		end,true)
		return true
	end
	function api:Remove(slot)if queue and live[slot]then queue:Remove(slot)end;live[slot]=nil end
	function api:Destroy()if not alive then return end;alive=false;if queue then queue:Destroy();queue=nil end;table.clear(live)end
	return api
end
return SVG
