--!strict
local Pixels=require(script.Parent.ImageFilterPixels)
local ImageBox=require(script.Parent.ImageBox)
local ImageBlur=require(script.Parent.ImageBlur)
local ImageFilters={}
local MAX_PIXELS,MAX_RESULTS=8388608,16

-- One source read per asset; each ordered filter chain shares one immutable
-- output image across its labels. Jobs yield in bounded pixel batches.
local function startBatch(items: any, alive: () -> boolean, diagnostic: (string) -> (), changed: () -> (), budget: any): any
	local stopBlur,blur=ImageBlur.start(items,alive,diagnostic,changed)
	local groups,order={},{}
	for _,item in items or {} do
		local filter=item.Style and item.Style.Filter
		if item.Source and filter and #filter.Steps>0 and not filter.HasRaster then
			local group=groups[item.Source]
			if not group then group={Variants={},Order={}}; groups[item.Source]=group; table.insert(order,item.Source) end
			local variant=group.Variants[filter.Key]
			if not variant then variant={Filter=filter,Items={}}; group.Variants[filter.Key]=variant; table.insert(group.Order,variant) end
			table.insert(variant.Items,item)
		end
	end
	local disposed=false
	local outputs={}
	local function live() return not disposed and alive() end
	local lastYield=os.clock()
	local function checkpoint()
		if not live() then return false end
		if os.clock()-lastYield>=.004 then task.wait(); lastYield=os.clock() end
		return live()
	end
	task.defer(function()
		for _,source in order do
			if not live() then break end
			local group=groups[source]
			local original
			local ok,result=pcall(function()
				original=game:GetService("AssetService"):CreateEditableImageAsync(Content.fromUri(source))
				assert(original,"EditableImage allocation unavailable")
				if not live() then return nil end
				local size=original.Size
				assert(size.X>0 and size.Y>0 and size.X<=1024 and size.Y<=1024,"Unsupported image size")
				return {Size=size,Pixels=original:ReadPixelsBuffer(Vector2.new(0,0),size)}
			end)
			if original then original:Destroy() end
			if not live() then break end
			if not ok then diagnostic("Image filter unavailable: "..source.."; original retained ("..tostring(result)..")")
			elseif result then
				for _,variant in group.Order do
					if not live() then break end
					local image
					local reserved=0
					local success,message=pcall(function()
						local pixels=result.Size.X*result.Size.Y
						local buffer=Pixels.render(result.Pixels,variant.Filter,checkpoint)
						if not buffer or not live() then return end
						if #variant.Items==0 then return end
						assert(budget.Count<MAX_RESULTS and budget.Used+pixels<=MAX_PIXELS,"Image filter cache budget reached")
						reserved=pixels;budget.Count+=1;budget.Used+=pixels
						image=game:GetService("AssetService"):CreateEditableImage({Size=result.Size})
						assert(image,"EditableImage allocation unavailable")
						if not live() or #variant.Items==0 then return end
						image:WritePixelsBuffer(Vector2.new(0,0),result.Size,buffer)
						local content=Content.fromObject(image)
						local resized=false
						local assigned={}
						local assignedOK,assignedError=pcall(function()
							for _,item in variant.Items do
								table.insert(assigned,{Item=item,TextFallback=item.TextFallback})
								item.FilterReady=true
								item.ImageGui.ImageContent=content
								if item.TextFallback then item.TextFallback=false; resized=true end
								ImageBox.updateFallback(item)
							end
						end)
						if not assignedOK then
							for _,previous in assigned do
								local item=previous.Item
								item.FilterReady=nil; item.TextFallback=previous.TextFallback
								pcall(function() item.ImageGui.ImageContent=Content.fromUri(item.Source); ImageBox.updateFallback(item) end)
							end
							error(assignedError)
						end
						table.insert(outputs,{Image=image,Pixels=reserved});image=nil;reserved=0
						if resized then changed() end
					end)
					if image then image:Destroy() end
					if reserved>0 then budget.Count-=1;budget.Used-=reserved end
					if not success and live() then diagnostic("Image filter unavailable: "..source.." "..variant.Filter.Key.."; original retained ("..tostring(message)..")") end
				end
			end
			groups[source]=nil
		end
		table.clear(groups); table.clear(order)
	end)
	local api={}
	function api:Remove(removals: {any})
		if blur then blur:Remove(removals) end
		local removed={};for _,item in removals do removed[item]=true end
		for _,group in groups do for _,variant in group.Order do
			for i=#variant.Items,1,-1 do if removed[variant.Items[i]] then table.remove(variant.Items,i) end end
		end end
	end
	function api:Destroy()
		if disposed then return end
		disposed=true
		if stopBlur then stopBlur() end
		for _,output in outputs do output.Image:Destroy();budget.Count-=1;budget.Used-=output.Pixels end
		table.clear(outputs)
	end
	return api
end
function ImageFilters.start(items: any,alive: ()->boolean,diagnostic: (string)->(),changed: ()->()): (()->(),any)
	local registrations,batches={},{};local disposed=false;local budget={Count=0,Used=0};local api={}
	function api:Add(additions: {any})
		if disposed then return end
		local fresh={};for _,item in additions do
			if not registrations[item] and item.Source and item.Style and item.Style.Filter and #item.Style.Filter.Steps>0 then table.insert(fresh,item) end
		end
		if #fresh==0 then return end
		local batch={Items={}};batches[batch]=true
		for _,item in fresh do registrations[item]=batch;batch.Items[item]=true end
		batch.Runtime=startBatch(fresh,alive,diagnostic,changed,budget)
	end
	function api:Remove(removals: {any})
		local affected={}
		for _,item in removals do
			local batch=registrations[item];registrations[item]=nil
			if batch then batch.Items[item]=nil;affected[batch]=true end
		end
		for batch in affected do
			batch.Runtime:Remove(removals)
			if not next(batch.Items) then batch.Runtime:Destroy();batches[batch]=nil end
		end
	end
	function api:Destroy()
		if disposed then return end;disposed=true
		for batch in batches do batch.Runtime:Destroy() end
		table.clear(batches);table.clear(registrations)
	end
	local needed=false
	for _,item in items or {} do if item.Source and item.Style and item.Style.Filter and #item.Style.Filter.Steps>0 then needed=true;break end end
	api:Add(items or {})
	return if needed then function()api:Destroy()end else nil,api
end
return ImageFilters
