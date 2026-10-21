--!strict
local TextureUpload=require(script.Parent.TextureUpload)
local WorkContext=require(script.Parent.Parent.WorkContext)
local Color=require(script.Parent.Parent.CSS.Color)
local BorderGeometry = require(script.Parent.Parent.Layout.BorderGeometry)
-- One composited image per inset card, reused while geometry/style are unchanged.
local Pixels = require(script.Parent.InsetShadowPixels)
local InsetShadows = {}
function InsetShadows.new(diagnostic: (string) -> (), createImage: any?)
	local PIXEL_BUDGET = 4 * 1048576
	local entries, count, total = {}, 0, 0
	local alive, unavailable, warned = true, false, false
	local renderer = {}
	local function report(message: string)
		if warned then return end
		warned = true; diagnostic("box-shadow inset: " .. message .. "; affected inset shadow omitted.")
	end
	local function release(entry: any)
		if entry.Image then entry.Image:Destroy(); total -= entry.Pixels; entry.Image = nil end
	end
	function renderer:Draw(box: any, width: number, height: number)
		if not alive then return end
		local gui, style = box.InsetShadowSurface or box.TableSurface or box.Gui, box.Style
		local entry=entries[gui]
		local visible=false
		for _,shadow in style.BoxShadows or{}do if shadow.Inset and Color.opacity(shadow,style)>0 and style.Visibility~='hidden'then visible=true;break end end
		if not visible then if entry then entry.Generation=(entry.Generation or 0)+1 end;gui.ImageTransparency=1;return end
		local bt, br, bb, bl = BorderGeometry.sizes(style)
		local key = width .. ":" .. height .. ":" .. bt .. ":" .. br .. ":" .. bb .. ":" .. bl .. ":" .. (style.BorderRadius or 0)
		-- Recascade and held effects can produce equal new list/color objects.
		-- Cache the actual inset pixels, ignoring unrelated outer/foreground paint.
		for _,shadow in style.BoxShadows or{}do if shadow.Inset then
			local color=if shadow.Color=='currentcolor'then style.Color else shadow.Color
			key..=':'..shadow.X..':'..shadow.Y..':'..shadow.Blur..':'..shadow.Spread..':'..color.R..':'..color.G..':'..color.B..':'..Color.opacity(shadow,style)
		end end
		if entry and entry.Key == key and entry.Image then gui.ImageTransparency=0;return end
		if not entry or not entry.Image then gui.ImageTransparency=1 end
		if not entry then
			if count >= 32 then report("32-card image budget reached"); return end
			entry = {}; entries[gui] = entry; count += 1
		end
		entry.Generation=(entry.Generation or 0)+1;local generation=entry.Generation
		local function current()return alive and entries[gui]==entry and entry.Generation==generation end
		entry.Key = key
		if width <= 0 or height <= 0 then release(entry); gui.ImageTransparency=1; return end
		local plan = Pixels.plan(width, height, style)
		local size = plan.Width * plan.Height
		if entry.Width ~= plan.Width or entry.Height ~= plan.Height then release(entry) end
		if unavailable or total + (if entry.Image then 0 else size) > PIXEL_BUDGET then
			release(entry); gui.ImageTransparency=1; report("EditableImage unavailable or pixel budget reached"); return
		end
		local editable = entry.Image
		local allocated=editable==nil
		local ok, content = pcall(function()
			local bytes=Pixels.render(width,height,style,plan)
			if not current()then return nil end
			local dimensions = Vector2.new(plan.Width, plan.Height)
			if not editable then
				editable = if createImage then createImage(dimensions) else game:GetService("AssetService"):CreateEditableImage({Size = dimensions})
			end
			assert(editable, "EditableImage allocation unavailable")
			if not TextureUpload.write(editable,dimensions,bytes,current)then return nil end
			return Content.fromObject(editable)
		end)
		if not current()then if editable and allocated then editable:Destroy()end;return nil end
		if not ok and WorkContext.isCancelled(content)then
			if editable and allocated then editable:Destroy()end
			entry.Key=nil;error(content,0)
		end
		if not ok then
			if editable and allocated then editable:Destroy() end
			release(entry); gui.ImageTransparency=1; unavailable = true; report(tostring(content)); return
		end
		if not entry.Image then total += size end
		entry.Image, entry.Pixels, entry.Width, entry.Height = editable, size, plan.Width, plan.Height
		gui.ImageContent, gui.ImageTransparency = content, 0
	end
	function renderer:Remove(box: any)
		local gui=box.InsetShadowSurface or box.TableSurface or box.Gui
		local entry=entries[gui]
		if entry then entries[gui]=nil;entry.Generation=(entry.Generation or 0)+1;release(entry);count-=1 end
	end
	function renderer:Destroy()
		if not alive then return end
		alive = false
		for _, entry in entries do release(entry) end
		table.clear(entries)
	end
	return renderer
end

return InsetShadows
