--!strict
local CanvasBackground=require(script.Parent.CanvasBackground)
local PaintLayer=require(script.Parent.PaintLayer)
local TextureUpload=require(script.Parent.TextureUpload)
-- Retained raster effects for the bounded HTML effects profile.
local Pixels = require(script.Parent.VisualEffectPixels)
local PerspectivePixels = require(script.Parent.PerspectivePixels)
local ProjectiveHit = require(script.Parent.ProjectiveHit)
local BorderGeometry = require(script.Parent.Parent.Layout.BorderGeometry)
local MaskPixels = require(script.Parent.MaskPixels)
local BorderImages = require(script.Parent.BorderImagePixels)
local BorderShapes = require(script.Parent.BorderShapePixels)
local BlendGroups = require(script.Parent.BlendGroups)
local VisualEffects = {}
local MAX_IMAGES, PIXEL_BUDGET = 64, 2 * 1048576

local function write(object: any, key: string, value: any) if object[key] ~= value then object[key] = value end end

local function backdropColor(gui: any): Color3
	local parent = gui.Parent
	while parent do
		if type(parent.BackgroundTransparency) == "number" and parent.BackgroundTransparency < 1 and parent.BackgroundColor3 then return parent.BackgroundColor3 end
		parent = parent.Parent
	end
	return Color3.new(1, 1, 1)
end

function VisualEffects.new(diagnostic: (string) -> (), createImage: any?, taskAPI: any?, host: any?): any
	local alive, unavailable = true, false
	local entries: any = setmetatable({}, {__mode = "k"})
	-- GUI owners may be collected before renderer teardown; keep destruction
	-- handles separately from the weak owner lookup.
	local ownedSlots: any = {}
	local imageCount, totalPixels = 0, 0
	local warned = false
	local renderer = {}
	local composites=BlendGroups.new(diagnostic,createImage,taskAPI,host)
	function renderer:UpdateComposites(tree,onlyStyles)composites:Update(tree,onlyStyles)end
	function renderer:PrepareComposites(onlyStyles)composites:Prepare(onlyStyles)end
	function renderer:CompositeStats()return composites:Stats()end
	local function report(message: string)
		if warned then return end
		warned = true; diagnostic("visual effects: " .. message)
	end
	local function releaseImage(slotValue: any)
		if slotValue.Image then slotValue.Image:Destroy(); imageCount -= 1; totalPixels -= slotValue.Pixels or 0; slotValue.Image = nil end
		slotValue.Pixels, slotValue.Width, slotValue.Height, slotValue.Key = nil, nil, nil, nil
		slotValue.SourceWidth,slotValue.SourceHeight=nil,nil
	end
	local function release(slotValue: any)
		ProjectiveHit.detach(slotValue.Gui)
		releaseImage(slotValue)
		if slotValue.Gui then slotValue.Gui:Destroy(); slotValue.Gui = nil end
	end
	local function getSlot(box: any, name: string, zIndex: number): any
		local entry = entries[box]
		if not entry then entry = {}; entries[box] = entry end
		local found = entry[name]
		if not found then
			found = {Gui = PaintLayer.create(box.Factory,"ImageLabel", box.Gui, {Name=name, BackgroundTransparency=1, ImageTransparency=1, ZIndex=zIndex, Position=UDim2.fromOffset(0,0)})}
			entry[name] = found
			table.insert(ownedSlots,found)
		end
		return found
	end
	local function draw(slotValue: any, width: number, height: number, key: string, makePixels: (any) -> buffer): boolean
		local plan = Pixels.plan(width, height); local pixels = plan.Width * plan.Height
		if slotValue.Key == key and slotValue.SourceWidth == width and slotValue.SourceHeight == height then return true end
		-- A resize invalidates only the pixel allocation. The retained ImageLabel
		-- remains part of the render tree and receives the replacement image below.
		if slotValue.Image and (slotValue.Width ~= plan.Width or slotValue.Height ~= plan.Height) then releaseImage(slotValue) end
		if unavailable or imageCount + (if slotValue.Image then 0 else 1) > MAX_IMAGES or totalPixels + (if slotValue.Image then 0 else pixels) > PIXEL_BUDGET then
			report("EditableImage unavailable or pixel budget reached; affected effect omitted"); return false
		end
		local editable = slotValue.Image
		local allocated=editable==nil
		local ok, content = pcall(function()
			local dimensions = Vector2.new(plan.Width, plan.Height)
			if not editable then editable = if createImage then createImage(dimensions) else game:GetService("AssetService"):CreateEditableImage({Size=dimensions}) end
			assert(editable, "EditableImage allocation unavailable")
			TextureUpload.write(editable,dimensions,makePixels(plan))
			return Content.fromObject(editable)
		end)
		if not ok then
			if editable and allocated then editable:Destroy() end
			unavailable = true; report(tostring(content)); return false
		end
		if not slotValue.Image then imageCount += 1; totalPixels += pixels end
		slotValue.Image, slotValue.Pixels = editable, pixels
		slotValue.Width, slotValue.Height, slotValue.Key = plan.Width, plan.Height, key
		slotValue.SourceWidth,slotValue.SourceHeight=width,height
		write(slotValue.Gui, "ImageContent", content)
		return true
	end
	local function restoreBorder(box)
		for _,saved in box.BorderImageHidden or {}do write(saved.Object,saved.Key,saved.Value)end;box.BorderImageHidden=nil
	end
	local function hideBorder(box)
		local saved={};box.BorderImageHidden=saved
		local function hide(object,key,value)if object then table.insert(saved,{Object=object,Key=key,Value=object[key]});write(object,key,value)end end
		local function edges(parts)
			if not parts then return end
			hide(parts.Stroke,'Transparency',1)
			for i=1,4 do hide(parts[i],'Visible',false)end
			for _,region in parts.FieldsetRegions or {}do edges(region.Edges)end
		end
		edges(box.InsetEdges);hide(box.RasterBorderGui,'Visible',false)
		if box.Gui.GetChildren then for _,child in box.Gui:GetChildren()do if child:IsA('UIStroke')then hide(child,'Transparency',1)end end end
	end
	function renderer:Draw(box: any, width: number, height: number)
		restoreBorder(box)
		if not alive or width <= 0 or height <= 0 then return end
		local style = CanvasBackground.usedStyle(box); local entry = entries[box]
		if box.BorderShapeBackground~=nil then write(box.Gui,'BackgroundTransparency',if style.Visibility~='hidden' and style.Background then 1-(style.BackgroundAlpha or 1) else 1);box.BorderShapeBackground=nil end
		if style.BorderShape then
			local slot=getSlot(box,'BorderShapeSurface',0)
			local g=BorderShapes.geometry(style,width,height)
			local c=style.BorderColor or style.Color;local bg=style.Background or Color3.new(0,0,0)
			local key=table.concat({g.Radius,g.Stroke,c.R,c.G,c.B,style.BorderColorAlpha or 1,bg.R,bg.G,bg.B,if style.Background then style.BackgroundAlpha or 1 else 0},':')
			local visible=draw(slot,g.Width,g.Height,key,function(plan)return BorderShapes.render(style,g,plan)end)
			write(slot.Gui,'Position',UDim2.fromOffset(g.Left,g.Top));write(slot.Gui,'Size',UDim2.fromOffset(g.Width,g.Height))
			write(slot.Gui,'ImageTransparency',if visible and style.Visibility~='hidden' then 0 else 1)
			box.BorderShapeSurface=slot.Gui
			if visible then
				box.BorderShapeBackground=box.Gui.BackgroundTransparency;write(box.Gui,'BackgroundTransparency',1);hideBorder(box)
				return
			end
		elseif entry and entry.BorderShapeSurface then write(entry.BorderShapeSurface.Gui,'ImageTransparency',1)end
		if style.ClipPath then
			local clipSlot = getSlot(box, "ClipPathMask", 100003); local color = backdropColor(box.Gui); local clip = style.ClipPath
			local key = clip.Kind .. ":" .. tostring(clip.Key or clip.Radius or clip.X) .. ":" .. tostring(clip.Y) .. ":" .. color.R .. ":" .. color.G .. ":" .. color.B
			local visible = draw(clipSlot, width, height, key, function(plan) return Pixels.renderClip(clip, width, height, color, plan) end)
			write(clipSlot.Gui,"Size",UDim2.fromOffset(width,height)); write(clipSlot.Gui,"ImageTransparency",if visible and style.Visibility~="hidden" then 0 else 1)
			box.ClipPathMask = clipSlot.Gui
		elseif entry and entry.ClipPathMask then write(entry.ClipPathMask.Gui,"ImageTransparency",1) end
		local definition = style.BorderImageSource
		local baseTop,baseRight,baseBottom,baseLeft=BorderGeometry.sizes(style)
		-- Unitless border-image-width and border-image-outset values are factors of
		-- the corresponding computed border width, not CSS pixel lengths.
		local outset=style.BorderImageOutset or {0,0,0,0}
		local outTop,outRight,outBottom,outLeft=BorderImages.width(outset[1],baseTop,height),BorderImages.width(outset[2],baseRight,width),BorderImages.width(outset[3],baseBottom,height),BorderImages.width(outset[4],baseLeft,width)
		local borderWidth,borderHeight=width+outLeft+outRight,height+outTop+outBottom
		if definition and definition.Kind == "gradient" then
			local borderSlot = getSlot(box,"BorderImageGradient",100002); local factors = style.BorderImageWidth or {1,1,1,1}
			local slice=style.BorderImageSlice or {100,100,100,100};local auto={}
			for i=1,4 do auto[i]=if slice.Percent and slice.Percent[i]then slice[i]/100*(if i%2==1 then borderHeight else borderWidth)else slice[i]end
			local widths={BorderImages.width(factors[1],baseTop,borderHeight,auto[1]),BorderImages.width(factors[2],baseRight,borderWidth,auto[2]),BorderImages.width(factors[3],baseBottom,borderHeight,auto[3]),BorderImages.width(factors[4],baseLeft,borderWidth,auto[4])}
			local colors={}
			for _,stop in definition.Stops or {{Color=definition.Color1,Alpha=definition.Alpha1},{Color=definition.Color2,Alpha=definition.Alpha2}} do
				local tint=if stop.Color=='currentcolor'then style.Color else stop.Color
				table.insert(colors,tint.R..":"..tint.G..":"..tint.B..":"..(stop.Alpha or 1))
			end
			local flags={};for i=1,4 do flags[i]=if slice.Percent and slice.Percent[i]then '%'else 'n'end
			local key = definition.Direction..":"..(definition.Key or '')..":"..table.concat(colors,":")..":"..widths[1]..":"..widths[2]..":"..widths[3]..":"..widths[4]..":"..outTop..":"..outRight..":"..outBottom..":"..outLeft..':'..table.concat(slice,':')..':'..tostring(slice.Fill)..':'..table.concat(flags)..':'..tostring(style.BorderImageRepeat)
			local visible = draw(borderSlot,borderWidth,borderHeight,key,function(plan) return if definition.Gradient then BorderImages.render(definition,borderWidth,borderHeight,widths,style,plan)else Pixels.renderBorder(definition,borderWidth,borderHeight,widths,plan)end)
			write(borderSlot.Gui,"Position",UDim2.fromOffset(-outLeft,-outTop));write(borderSlot.Gui,"Size",UDim2.fromOffset(borderWidth,borderHeight)); write(borderSlot.Gui,"ImageTransparency",if visible and style.Visibility~="hidden" then 0 else 1)
			box.BorderImageGradient = borderSlot.Gui
			if visible then hideBorder(box)end
			if box.BorderImage then write(box.BorderImage,"Visible",false) end
		elseif definition then
			entry = entries[box]; if entry and entry.BorderImageGradient then write(entry.BorderImageGradient.Gui,"ImageTransparency",1) end
			local source = box.ResolveImage and box.ResolveImage(definition.Source)
			if source then
				if not box.BorderImage then box.BorderImage=PaintLayer.create(box.Factory,"ImageLabel",box.Gui,{Name="BorderImage",BackgroundTransparency=1,ZIndex=100002,ScaleType=Enum.ScaleType.Slice}) end
				local slice=style.BorderImageSlice or {100,100,100,100};local top,right,bottom,left=slice[1],slice[2],slice[3],slice[4]
				write(box.BorderImage,"Image",source);write(box.BorderImage,"Visible",style.Visibility~="hidden");write(box.BorderImage,"Position",UDim2.fromOffset(-outLeft,-outTop));write(box.BorderImage,"Size",UDim2.fromOffset(borderWidth,borderHeight))
				write(box.BorderImage,"ScaleType",if style.BorderImageRepeat=="round" then Enum.ScaleType.Tile else Enum.ScaleType.Slice)
				if style.BorderImageRepeat=="round" then write(box.BorderImage,"TileSize",UDim2.fromOffset(math.max(1,width/4),math.max(1,height/4))) end
				write(box.BorderImage,"SliceCenter",Rect.new(left,top,math.max(left+1,100-right),math.max(top+1,100-bottom)))
				local widths=style.BorderImageWidth or {1,1,1,1};local total=0;for i=1,4 do total+=if type(widths[i])=='number'then widths[i]else 1 end;write(box.BorderImage,"SliceScale",math.max(.01,total/4))
				hideBorder(box)
			elseif box.BorderImage then write(box.BorderImage,"Visible",false) end
		else
			entry = entries[box]; if entry and entry.BorderImageGradient then write(entry.BorderImageGradient.Gui,"ImageTransparency",1) end
			if box.BorderImage then write(box.BorderImage,"Visible",false) end
		end
	end
	local function restoreScene(box: any)
		for _,saved in box.Scene3DHidden or {} do write(saved.Object,saved.Key,saved.Value) end
		box.Scene3DHidden=nil
	end
	function renderer:DrawScene(box: any,node: any): boolean
		if not alive then return false end
		local slot=getSlot(box,"Scene3DSurface",100004)
		local key=PerspectivePixels.sceneKey(node)
		local bounds=slot.SceneBounds
		if key~=slot.Key or not bounds then
			local planes;planes,bounds=PerspectivePixels.scene(node)
			if #planes==0 then bounds={Left=0,Top=0,Width=1,Height=1} end
			local visible=draw(slot,bounds.Width,bounds.Height,key,function(plan)
				return PerspectivePixels.renderScene(planes,bounds,plan)
			end)
			if not visible then return false end
			slot.SceneBounds=bounds
		end
		restoreScene(box)
		local saved={};box.Scene3DHidden=saved
		local function hide(object: any,keyName: string,value: any)
			if not object then return end
			table.insert(saved,{Object=object,Key=keyName,Value=object[keyName]});write(object,keyName,value)
		end
		hide(box.Gui,"BackgroundTransparency",1)
		if box.Gui.GetChildren then
			for _,child in box.Gui:GetChildren() do
				if child~=slot.Gui then
					if child:IsA("GuiObject") then hide(child,"Visible",false)
					elseif child:IsA("UIStroke") then hide(child,"Transparency",1) end
				end
			end
		else
			for _,child in box.Children or {} do
				if child.Kind=="Words" then for _,item in child.Items or {} do hide(item.Gui,"Visible",false);if item.TextGui~=item.Gui then hide(item.TextGui,"Visible",false) end end
				else hide(child.Gui,"Visible",false) end
			end
		end
		write(slot.Gui,"Position",UDim2.fromOffset(bounds.Left,bounds.Top));write(slot.Gui,"Size",UDim2.fromOffset(bounds.Width,bounds.Height));write(slot.Gui,"ImageTransparency",0)
		if slot.Gui.SetAttribute then slot.Gui:SetAttribute("HTMLPaintOnlyOverlay",false)end
		box.Scene3DHit=ProjectiveHit.attach(slot.Gui,node,bounds)
		box.Scene3DSurface=slot.Gui
		return true
	end
	function renderer:ClearScene(box: any)
		restoreScene(box)
		local entry=entries[box];if entry and entry.Scene3DSurface then
			local gui=entry.Scene3DSurface.Gui
			write(gui,"ImageTransparency",1)
			if gui.SetAttribute then gui:SetAttribute("HTMLPaintOnlyOverlay",true)end
		end
		ProjectiveHit.detach(box.Scene3DSurface)
		box.Scene3DHit=nil;box.Scene3DSurface=nil
	end
	local function restoreMask(box: any)
		for _,saved in box.MaskHidden or {} do write(saved.Object,saved.Key,saved.Value) end
		box.MaskHidden=nil
	end
	function renderer:DrawMask(box: any): boolean
		local width,height=box.OuterWidth or 0,box.OuterHeight or 0
		if not alive or width<=0 or height<=0 then return false end
		local definition=box.Style.MaskImage or box.Style.MaskBorderSource
		if not definition or definition.Kind~="layers" then return false end
		local node=PerspectivePixels.flat(box)
		local key=PerspectivePixels.sceneKey(node)..":"..definition.Key..":"..tostring(box.Style.MaskComposite)..':'..tostring(box.Style.MaskMode)..':'..tostring(box.Style.MaskBorderMode)..':'..tostring(box.Style.MaskBorderRepeat)
		if box.Style.MaskBorderSource then key..=':'..box.Style.MaskBorderSource.Key end
		for _,field in {'MaskBorderSlice','MaskBorderWidth','MaskBorderOutset'}do local values=box.Style[field];for _,value in values or {}do key..=':'..tostring(value)end end
		for _,field in {"MaskOrigins","MaskClips","MaskSizes","MaskPositions","MaskRepeats","Padding"} do
			for _,value in box.Style[field] or {} do key..=":"..tostring(value) end
		end
		local slot=getSlot(box,"CSSMaskSurface",100004)
		local visible=draw(slot,width,height,key,function(plan)
			local planes=PerspectivePixels.scene(node)
			local pixels=PerspectivePixels.renderScene(planes,{Left=0,Top=0,Width=width,Height=height},plan)
			local result=MaskPixels.apply(pixels,MaskPixels.render(box.Style,definition,width,height,plan))
			if box.Style.MaskImage and box.Style.MaskBorderSource then result=MaskPixels.apply(result,MaskPixels.render(box.Style,box.Style.MaskBorderSource,width,height,plan))end
			return result
		end)
		if not visible then return false end
		-- Native content remains in the layout and event tree while its paint is
		-- replaced by the alpha-composited surface.
		restoreMask(box)
		local saved={};box.MaskHidden=saved
		local function hide(object,keyName,value)
			table.insert(saved,{Object=object,Key=keyName,Value=object[keyName]});write(object,keyName,value)
		end
		hide(box.Gui,"BackgroundTransparency",1)
		if box.Gui.GetChildren then for _,child in box.Gui:GetChildren() do
			if child~=slot.Gui then
				if child:IsA("GuiObject") then hide(child,"Visible",false)
				elseif child:IsA("UIStroke") then hide(child,"Transparency",1) end
			end
		end else for _,child in box.Children or {} do
			if child.Kind=="Words" then for _,item in child.Items or {} do
				if item.Gui then hide(item.Gui,"Visible",false) end
				if item.TextGui and item.TextGui~=item.Gui then hide(item.TextGui,"Visible",false) end
			end elseif child.Gui then hide(child.Gui,"Visible",false) end
		end end
		write(slot.Gui,"Size",UDim2.fromOffset(width,height));write(slot.Gui,"ImageTransparency",if box.Style.Visibility=="hidden" then 1 else 0)
		box.CSSMaskSurface=slot.Gui
		return true
	end
	function renderer:ClearMask(box: any)
		restoreMask(box)
		local entry=entries[box];if entry and entry.CSSMaskSurface then write(entry.CSSMaskSurface.Gui,"ImageTransparency",1) end
		box.CSSMaskSurface=nil
	end
	function renderer:Remove(box: any)
		self:ClearScene(box)
		composites:Remove(box)
		local entry=entries[box]
		if not entry then return end
		for _,slotValue in entry do
			local index=table.find(ownedSlots,slotValue)
			if index then table.remove(ownedSlots,index) end
			release(slotValue)
		end
		entries[box]=nil
	end
	function renderer:Destroy()
		if not alive then return end; alive=false
		composites:Destroy()
		for box in entries do box.Scene3DHit=nil end
		for _,slotValue in ownedSlots do release(slotValue) end
		table.clear(entries);table.clear(ownedSlots)
	end
	return renderer
end
return VisualEffects
