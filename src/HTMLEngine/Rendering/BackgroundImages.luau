--!strict
local TextureUpload=require(script.Parent.TextureUpload)
-- Retained CSS background layers. Gradient images are cached across state switches.
local BorderGeometry = require(script.Parent.Parent.Layout.BorderGeometry)
local LengthExpression = require(script.Parent.Parent.CSS.LengthExpression)
local Pixels = require(script.Parent.BackgroundPixels)
local CornerRadii = require(script.Parent.CornerRadii)
local ImageSet=require(script.Parent.Parent.CSS.ImageSet)
local BackgroundSVG=require(script.Parent.BackgroundSVG)
local CanvasBackground=require(script.Parent.CanvasBackground)

local BackgroundImages = {}
local MAX_LAYERS,MAX_IMAGES,PIXEL_BUDGET=8,64,4*1048576

local function write(gui: any,key: string,value: any) if gui[key]~=value then gui[key]=value end end
local function paints(image: any): boolean
	return image.Kind~='none'and not(image.Kind=='url'and image.Source=='')
end

local function rect(style: any,width: number,height: number,kind: string): any
	local bt,br,bb,bl=BorderGeometry.sizes(style)
	if kind=="border-box" then return {X=0,Y=0,W=width,H=height,Inset=0} end
	local x,y,w,h=bl,bt,math.max(0,width-bl-br),math.max(0,height-bt-bb)
	if kind=="content-box" then
		local p=style.Padding;x+=p[4];y+=p[1];w=math.max(0,w-p[4]-p[2]);h=math.max(0,h-p[1]-p[3])
		return {X=x,Y=y,W=w,H=h,Inset=math.max(bt,br,bb,bl,p[1],p[2],p[3],p[4])}
	end
	return {X=x,Y=y,W=w,H=h,Inset=math.max(bt,br,bb,bl)}
end

local function list(value: any,index: number,default: any): any
	if not value or #value==0 then return default end
	return value[(index-1)%#value+1]
end

-- Background images live on child surfaces, outside the outer UICorner's
-- clipping. Resolve percentages against the border box before subtracting
-- the background-clip inset. The shared safe radius keeps circular corners
-- exact and retains the existing fallback for unequal/elliptical corners.
local function clipRadius(style: any,width: number,height: number,clip: any): number
	local radius=style.BorderRadius or 0
	local resolved=CornerRadii.resolve(style,width,height)
	if resolved then
		radius=math.huge
		for _,corner in resolved do radius=math.min(radius,corner[1],corner[2]) end
	end
	return math.max(0,math.min(radius-clip.Inset,clip.W/2,clip.H/2))
end

local function resolveSize(value: any,origin: any): (number,number,string)
	if value.Kind=="cover" or value.Kind=="contain" then return origin.W,origin.H,value.Kind end
	local width=if value.X then math.max(0,LengthExpression.resolve(value.X,origin.W)) else origin.W
	local height=if value.Y then math.max(0,LengthExpression.resolve(value.Y,origin.H)) else origin.H
	return width,height,"stretch"
end

local function coordinate(axis: any,originStart: number,originSize: number,imageSize: number): number
	local free=originSize-imageSize
	local offset=if axis.Offset then LengthExpression.resolve(axis.Offset,free) else 0
	if axis.Anchor==1 then offset=-offset end
	return originStart+axis.Anchor*free+offset
end

function BackgroundImages.new(diagnostic: (string)->(),resolveImage: ((string)->string?)?,createImage: any?,viewportRoot: any?,options: any?): any
	local alive,unavailable=true,false
	local entries: any=setmetatable({},{__mode="k"})
	local fixedBoxes: any=setmetatable({},{__mode="k"})
	-- EditableImages require explicit destruction. Weak gradient keys could drop
	-- the only cleanup handle while the image and its budget remained allocated.
	local gradientCache: any={}
	local cachedImages: any={}
	local sequence=0
	local imageCount,totalPixels=0,0
	local warned,missing={},{}
	local renderer={}
	local svg=BackgroundSVG.new(options and options.ResolveSVG,viewportRoot,options,diagnostic)
	local function report(key: string,message: string)
		if warned[key] then return end;warned[key]=true;diagnostic("background-image: "..message)
	end
	local function releaseBinding(slot: any)
		if slot.Cached then slot.Cached.Users[slot]=nil;slot.Cached=nil end
	end
	local function destroySlot(slot: any)
		svg:Remove(slot)
		releaseBinding(slot)
		if slot.Gui then slot.Gui:Destroy();slot.Gui=nil end
	end
	local function entry(box: any): any
		local found=entries[box]
		if not found then found={Slots={}};entries[box]=found end
		return found
	end
	local function makeRoom(pixels: number): boolean
		while imageCount>=MAX_IMAGES or totalPixels+pixels>PIXEL_BUDGET do
			local oldest,oldestIndex
			for index,cached in cachedImages do
				if next(cached.Users)==nil and (not oldest or cached.Used<oldest.Used) then oldest,oldestIndex=cached,index end
			end
			if not oldest then return false end
			oldest.Image:Destroy();imageCount-=1;totalPixels-=oldest.Pixels
			local variants=gradientCache[oldest.Gradient];variants[oldest.Key]=nil
			if next(variants)==nil then gradientCache[oldest.Gradient]=nil end
			table.remove(cachedImages,oldestIndex)
		end
		return true
	end
	local function bind(slot: any,cached: any): any
		sequence+=1;cached.Used=sequence;cached.Users[slot]=true;slot.Cached=cached
		return cached.Content
	end
	local function gradientContent(slot: any,gradient: any,width: number,height: number,style: any,current: ()->boolean): any?
		if not current()then return nil end
		local plan=Pixels.plan(width,height)
		local color=style.Color or Color3.new(0,0,0);local alpha=style.ColorAlpha or 1
		-- CSS pixel stops depend on the original box even when two large boxes
		-- downsample to the same texture dimensions.
		local key=width..":"..height..":"..color.R..":"..color.G..":"..color.B..":"..alpha
		if slot.Cached and slot.Cached.Gradient==gradient and slot.Cached.Key==key then return slot.Cached.Content end
		releaseBinding(slot)
		local variants=gradientCache[gradient]
		if variants and variants[key] then return bind(slot,variants[key]) end
		local pixels=plan.Width*plan.Height
		if unavailable or not makeRoom(pixels) then
			report("budget","EditableImage unavailable or cache budget reached; affected gradient omitted") return nil
		end
		if not current()then return nil end
		local editable
		local ok,content=pcall(function()
			local dimensions=Vector2.new(plan.Width,plan.Height)
			editable=if createImage then (createImage :: any)(dimensions) else game:GetService("AssetService"):CreateEditableImage({Size=dimensions})
			assert(editable,"EditableImage allocation unavailable")
			if not current()then return nil end
			local bytes=if gradient.Kind=="blend" then Pixels.renderBlend(width,height,gradient.Images,gradient.Modes,style,plan) else Pixels.render(width,height,gradient,style,plan)
			if not TextureUpload.write(editable,dimensions,bytes,current)then return nil end
			return Content.fromObject(editable)
		end)
		if not ok or not current()or content==nil then
			if editable then editable:Destroy()end
			if current()then unavailable=true;report("editable",tostring(content).."; affected gradient omitted")end
			return nil
		end
		-- Eviction may have removed the old variant table for this gradient.
		variants=gradientCache[gradient] or {};gradientCache[gradient]=variants
		local cached={Image=editable,Content=content,Pixels=pixels,Gradient=gradient,Key=key,Users=setmetatable({},{__mode="k"})}
		variants[key]=cached;table.insert(cachedImages,cached);imageCount+=1;totalPixels+=pixels
		return bind(slot,cached)
	end
	local function ensureSlot(box: any,index: number,rounded: boolean,customHost: any?): any
		local e=entry(box);local slot=e.Slots[index];local host=customHost or box.TableSurface or box.Gui
		if slot and (slot.Rounded~=rounded or slot.Host~=host) then destroySlot(slot);slot=nil end
		if not slot then
			local class=if rounded then "CanvasGroup" else "Frame"
			local gui=box.Factory.create(class,host,{Name="BackgroundLayer_"..index,ClipsDescendants=true,ZIndex=0})
			slot={Gui=gui,Rounded=rounded,Host=host};e.Slots[index]=slot
			if rounded then slot.Corner=box.Factory.modifier("UICorner",gui,{CornerRadius=UDim.new(0,0)}) end
		end
		return slot
	end
	local function hideExtra(e: any,first: number)
		for index=first,#e.Slots do local slot=e.Slots[index];if slot and slot.Gui then releaseBinding(slot);svg:Remove(slot);write(slot.Gui,"Visible",false) end end
	end
	function renderer:Draw(box: any,width: number,height: number)
		if not alive or width<=0 or height<=0 then return end
		local previous=entries[box];if previous then previous.Generation=(previous.Generation or 0)+1 end
		local style=CanvasBackground.usedStyle(box);local images={}
		for index,candidate in style.BackgroundImages or{{Kind='none'}}do images[index]=ImageSet.select(candidate,options and options.Resolution or 1,function(mime)return mime=='image/svg+xml'or mime=='image/png'or mime=='image/jpeg'or mime=='image/webp'end)end
		local visible=style.Visibility~="hidden"
		local colorClip=list(style.BackgroundClips,#images,"border-box")
		local customColor=visible and style.Background~=nil and colorClip~="border-box"
		local hasImages=false
		local hasFixed=false
		for index,image in images do
			if paints(image) then
				hasImages=true
				if list(style.BackgroundAttachments,index,"scroll")=="fixed" then hasFixed=true end
			end
		end
		local existing=entries[box]
		fixedBoxes[box]=if hasFixed then true else nil
		if hasFixed and not (existing and existing.FixedConnection) and box.Gui.GetPropertyChangedSignal then
			local ok,connection=pcall(function()
				return box.Gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
					if alive then renderer:Draw(box,box.OuterWidth or width,box.OuterHeight or height) end
				end)
			end)
			if ok and connection then entry(box).FixedConnection=connection end
		elseif not hasFixed and existing and existing.FixedConnection then
			existing.FixedConnection:Disconnect();existing.FixedConnection=nil
		end
		local host=box.TableSurface or box.Gui
		if not hasImages and not customColor then
			write(host,"BackgroundColor3",style.Background or Color3.new(1,1,1))
			write(host,"BackgroundTransparency",if box.ResolvedBorderRadii then 1 elseif visible and style.Background then 1-(style.BackgroundAlpha or 1) else 1)
			local e=entries[box];if e then hideExtra(e,1) end
			return
		end
		write(host,"BackgroundTransparency",1)
		local e=entry(box);local generation=e.Generation or 0;local slotIndex=0
		local function current(): boolean return alive and entries[box]==e and(e.Generation or 0)==generation end
		local modes=style.BackgroundBlendMode
		local blendable=type(modes)=="table" and #modes>0 and #images>=2 and #images<=4
			and style.Background~=nil and (style.BackgroundAlpha or 1)==1
			and not hasFixed and not box.CanvasPaintingArea
		if blendable then
			local top,right,bottom,left=BorderGeometry.sizes(style)
			blendable=top==0 and right==0 and bottom==0 and left==0
			for index,image in images do
				local size=list(style.BackgroundSizes,index,{Kind="explicit",X=false,Y=false})
				local position=list(style.BackgroundPositions,index,{X={Anchor=0},Y={Anchor=0}})
				if (image.Kind~="linear" and image.Kind~="radial" and image.Kind~="conic")
					or size.Kind~="explicit" or size.X or size.Y
					or position.X.Anchor~=0 or position.Y.Anchor~=0 or position.X.Offset or position.Y.Offset
					or list(style.BackgroundOrigins,index,"padding-box")~="padding-box"
					or list(style.BackgroundClips,index,"border-box")~="border-box"
					or list(style.BackgroundAttachments,index,"scroll")~="scroll" then blendable=false;break end
			end
		end
		if blendable then
			if e.BlendStyle~=style then e.BlendStyle=style;e.BlendDefinition={Kind="blend",Images=images,Modes=modes} end
			local radius=clipRadius(style,width,height,{W=width,H=height,Inset=0})
			local slot=ensureSlot(box,1,radius>0)
			if slot.Corner then write(slot.Corner,"CornerRadius",UDim.new(0,radius)) end
			write(slot.Gui,"Visible",visible);write(slot.Gui,"Position",UDim2.fromOffset(0,0));write(slot.Gui,"Size",UDim2.fromOffset(width,height));write(slot.Gui,"BackgroundTransparency",1)
			if slot.LayerKind~="blend" and slot.Image then slot.Image:Destroy();slot.Image=nil end
			if not slot.Image then slot.Image=box.Factory.create("ImageLabel",slot.Gui,{Name="BackgroundImage",ZIndex=0});slot.LayerKind="blend" end
			write(slot.Image,"Position",UDim2.fromOffset(0,0));write(slot.Image,"Size",UDim2.fromOffset(width,height))
			write(slot.Image,"Image","");write(slot.Image,"ImageTransparency",0);write(slot.Image,"ImageColor3",Color3.new(1,1,1))
			write(slot.Image,"ScaleType",Enum.ScaleType.Stretch)
			local content=gradientContent(slot,e.BlendDefinition,width,height,style,current)
			if not current()then return end
			if content then slot.Image.ImageContent=content end
			write(slot.Image,"Visible",visible and content~=nil)
			hideExtra(e,2)
			return
		elseif type(modes)=="table" and #modes>1 then report("blend","mixed background-blend-mode requires full-size gradient layers; normal layer composition used") end
		if visible and style.Background then
			slotIndex+=1;local clip=box.CanvasPaintingArea or rect(style,width,height,colorClip);local radius=if box.CanvasPaintingArea then 0 else clipRadius(style,width,height,clip)
			local slot=ensureSlot(box,slotIndex,radius>0)
			releaseBinding(slot)
			write(slot.Gui,"Visible",clip.W>0 and clip.H>0);write(slot.Gui,"Position",UDim2.fromOffset(clip.X,clip.Y));write(slot.Gui,"Size",UDim2.fromOffset(clip.W,clip.H))
			write(slot.Gui,"BackgroundColor3",style.Background);write(slot.Gui,"BackgroundTransparency",1-(style.BackgroundAlpha or 1))
			if slot.Corner then write(slot.Corner,"CornerRadius",UDim.new(0,radius)) end
			if slot.Image then write(slot.Image,"Visible",false) end
		end
		-- CSS's first image is topmost; create lower layers first for stable equal-Z ordering.
		local start=math.min(#images,MAX_LAYERS)
		if #images>MAX_LAYERS then report("layers","more than "..MAX_LAYERS.." layers; extra layers omitted") end
		for imageIndex=start,1,-1 do
			local image=images[imageIndex];if not paints(image) then continue end
			slotIndex+=1
			local attachment=list(style.BackgroundAttachments,imageIndex,"scroll")
			local layerHost=if attachment=="local" and box.ScrollContent then box.ScrollContent else host
			-- A local background belongs to the entire scrollable canvas. The
			-- scrollport clips it; sizing it to the viewport left white content
			-- behind after scrolling past the first visible screen.
			local surfaceWidth,surfaceHeight=width,height
			if layerHost==box.ScrollContent then
				surfaceWidth=math.max(width,box.ScrollRight or width)
				surfaceHeight=math.max(height,box.ScrollBottom or height)
			end
			local positioning=box.RootPositioningArea
			local origin=rect(style,if positioning then positioning.W else surfaceWidth,if positioning then positioning.H else surfaceHeight,list(style.BackgroundOrigins,imageIndex,"padding-box"))
			if positioning then origin.X+=positioning.X;origin.Y+=positioning.Y end
			if attachment=="fixed" then
				local absolute=box.Gui.AbsolutePosition or {X=0,Y=0}
				local viewport=viewportRoot and viewportRoot.AbsolutePosition or {X=0,Y=0}
				origin={X=viewport.X-absolute.X,Y=viewport.Y-absolute.Y,
					W=math.max(1,style.ViewportWidth or width),H=math.max(1,style.ViewportHeight or height),Inset=0}
			end
			local clip=box.CanvasPaintingArea or rect(style,surfaceWidth,surfaceHeight,list(style.BackgroundClips,imageIndex,"border-box"))
			local radius=if box.CanvasPaintingArea then 0 else clipRadius(style,surfaceWidth,surfaceHeight,clip)
			local slot=ensureSlot(box,slotIndex,radius>0,layerHost)
			write(slot.Gui,"Visible",visible and clip.W>0 and clip.H>0);write(slot.Gui,"BackgroundTransparency",1)
			local bt,_,_,bl=BorderGeometry.sizes(style);local hostX,hostY=if layerHost==box.ScrollContent then bl else 0,if layerHost==box.ScrollContent then bt else 0
			write(slot.Gui,"Position",UDim2.fromOffset(clip.X+hostX,clip.Y+hostY));write(slot.Gui,"Size",UDim2.fromOffset(clip.W,clip.H))
			if slot.Corner then write(slot.Corner,"CornerRadius",UDim.new(0,radius)) end
			local layerKind=if image.Kind=="url" then "url" else "gradient"
			if slot.LayerKind~=layerKind and slot.Image then slot.Image:Destroy();slot.Image=nil end
			if not slot.Image then slot.Image=box.Factory.create("ImageLabel",slot.Gui,{Name="BackgroundImage",ZIndex=0});slot.LayerKind=layerKind end
			write(slot.Image,"ResampleMode",if style.ImageRendering=="pixelated" or style.ImageRendering=="crisp-edges" then Enum.ResamplerMode.Pixelated else Enum.ResamplerMode.Default)
			write(slot.Image,"ImageColor3",if (style.BackgroundBlendMode=="multiply" or type(style.BackgroundBlendMode)=="table" and style.BackgroundBlendMode[1]=="multiply" and #style.BackgroundBlendMode==1) and style.Background then style.Background else Color3.new(1,1,1))
			local size=list(style.BackgroundSizes,imageIndex,{Kind="explicit",X=false,Y=false})
			local imageWidth,imageHeight,fit=resolveSize(size,origin)
			local position=list(style.BackgroundPositions,imageIndex,{X={Anchor=0},Y={Anchor=0}})
			local x=coordinate(position.X,origin.X,origin.W,imageWidth)-clip.X
			local y=coordinate(position.Y,origin.Y,origin.H,imageHeight)-clip.Y
			local repeatValue=list(style.BackgroundRepeats,imageIndex,{X="repeat",Y="repeat"})
			local repeatX,repeatY=repeatValue.X~="no-repeat",repeatValue.Y~="no-repeat"
			if repeatValue.X=="round" and imageWidth>0 then imageWidth=origin.W/math.max(1,math.round(origin.W/imageWidth)) end
			if repeatValue.Y=="round" and imageHeight>0 then imageHeight=origin.H/math.max(1,math.round(origin.H/imageHeight)) end
			if fit~="stretch" then repeatX,repeatY=false,false;x,y=origin.X-clip.X,origin.Y-clip.Y end
			if repeatX and imageWidth>0 then x-=math.ceil((x)/imageWidth)*imageWidth end
			if repeatY and imageHeight>0 then y-=math.ceil((y)/imageHeight)*imageHeight end
			local drawWidth=if repeatX then clip.W-x else imageWidth
			local drawHeight=if repeatY then clip.H-y else imageHeight
			write(slot.Image,"Position",UDim2.fromOffset(x,y));write(slot.Image,"Size",UDim2.fromOffset(math.max(0,drawWidth),math.max(0,drawHeight)))
			write(slot.Image,"Visible",visible and imageWidth>0 and imageHeight>0)
			if image.Kind=="url" then
				releaseBinding(slot)
				local source=if resolveImage then (resolveImage :: any)(image.Source) else nil
				if not current()then return end
				if not source then
					local drawn=svg:Draw(slot,image.Source,imageWidth,imageHeight,fit,current)
					if not current()then return end
					if drawn then continue end
				end
				svg:Remove(slot)
				if not source and not missing[image.Source] then missing[image.Source]=true;report("url:"..image.Source,"no options.Images mapping for url("..image.Source.."); layer omitted") end
				write(slot.Image,"Image",source or "");write(slot.Image,"ImageTransparency",if source then 0 else 1)
			else
				svg:Remove(slot)
				write(slot.Image,"Image","");write(slot.Image,"ImageTransparency",0)
				local content=gradientContent(slot,image,imageWidth,imageHeight,style,current)
				if not current()then return end
				if content then slot.Image.ImageContent=content else write(slot.Image,"Visible",false) end
			end
			if repeatX or repeatY then
				write(slot.Image,"ScaleType",Enum.ScaleType.Tile);write(slot.Image,"TileSize",UDim2.fromOffset(math.max(1,imageWidth),math.max(1,imageHeight)))
			else
				write(slot.Image,"ScaleType",if fit=="cover" then Enum.ScaleType.Crop elseif fit=="contain" then Enum.ScaleType.Fit else Enum.ScaleType.Stretch)
			end
		end
		hideExtra(e,slotIndex+1)
	end
	function renderer:RefreshFixed()
		if not alive then return end
		for box in fixedBoxes do
			if box.OuterWidth and box.OuterHeight then self:Draw(box,box.OuterWidth,box.OuterHeight) end
		end
	end
	function renderer:Remove(box: any)
		local e=entries[box]
		if e then
			if e.FixedConnection then e.FixedConnection:Disconnect();e.FixedConnection=nil end
			for _,slot in e.Slots do destroySlot(slot) end
			entries[box]=nil
		end
		fixedBoxes[box]=nil
	end
	function renderer:Destroy()
		if not alive then return end;alive=false
		for _,e in entries do
			if e.FixedConnection then e.FixedConnection:Disconnect();e.FixedConnection=nil end
			for _,slot in e.Slots do destroySlot(slot) end
		end
		for _,cached in cachedImages do cached.Image:Destroy() end
		svg:Destroy()
		table.clear(entries);table.clear(fixedBoxes);table.clear(gradientCache);table.clear(cachedImages)
	end
	return renderer
end

return BackgroundImages
