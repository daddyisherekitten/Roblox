--!strict
local BorderGeometry = require(script.Parent.Parent.Layout.BorderGeometry)
local BorderBox = require(script.Parent.BorderBox)
local OutlineBox = require(script.Parent.OutlineBox)
-- Separate margin, border/padding and image content so native fitting sees only content.
local ImageFit = require(script.Parent.Parent.Layout.ImageFit)
local ImageBox = {}
local ImageFallback = require(script.Parent.ImageFallback)
local GroupOpacity = require(script.Parent.GroupOpacity)
local ERROR_IMAGE = "rbxassetid://112299903593689"

function ImageBox.updateFallback(item: any)
	local broken=ImageFallback.broken(item)
	local visible=not item.Style or item.Style.Visibility~="hidden"
	local failed=broken and not item.EmptyAlt and visible
	if item.FallbackGui then item.FallbackGui.Visible = failed end
	if item.AltGui then item.AltGui.Visible = failed end
	if item.ErrorGui then item.ErrorGui.Visible = failed end
	if item.ImageGui then item.ImageGui.Visible=not broken and visible and not item.BlurReady and not item.SVGEffectReady end
	if item.SVGEffectGui then item.SVGEffectGui.Visible=not broken and visible and item.SVGEffectReady==true end
	if broken and item.BlurGui then item.BlurGui.Visible=false end
end

function ImageBox.create(item: any, parent: any, factory: any, font: any, name: string, corners: any?, retainedOuter: boolean?)
	local style = item.Style
	item.ImageFactory=factory
	if not retainedOuter then item.Gui = factory.create("Frame", parent, {Name = name})end
	if (style.Opacity or 1) < 1 and not item.Block then item.OpacityGroup = GroupOpacity.create(item.Gui, style.Opacity, factory) end
	item.BoxGui = factory.create("Frame", if item.OpacityGroup then item.OpacityGroup.Content else item.Gui, {Name = "ImageBox", Visible = style.Visibility ~= "hidden",
		BackgroundTransparency = if style.Background then 1 - (style.BackgroundAlpha or 1) else 1,
		BackgroundColor3 = style.Background or Color3.new(1, 1, 1)})
	if style.BorderRadius > 0 then item.BoxCorner = factory.modifier("UICorner", item.BoxGui, {CornerRadius = UDim.new(0, style.BorderRadius)}) end
	item.BorderEdges = BorderBox.create(style, item.BoxGui, factory, corners)
	item.Outline = OutlineBox.create(style, item.BoxGui, factory, corners)
	if item.Source or item.SVG or item.Canvas then
		if (not item.SVG or item.SVGExternal or style.ObjectViewBox) and (ImageFit.custom(style) or item.SVGExternal) then
			-- Frame cannot clip children to UICorner. Only rounded custom fits need a render texture.
			item.ImageClip = factory.create(if style.BorderRadius > 0 then "CanvasGroup" else "Frame", item.BoxGui,
				{Name = "ImageContent", ClipsDescendants = true})
		end
		item.ImageGui = factory.create("ImageLabel", item.ImageClip or item.BoxGui, {Name = "Image", Image = item.Source,
			ScaleType = if item.ImageClip then Enum.ScaleType.Stretch elseif style.ObjectFit == "contain" then Enum.ScaleType.Fit elseif style.ObjectFit == "cover" then Enum.ScaleType.Crop else Enum.ScaleType.Stretch,
			ResampleMode=if style.ImageRendering=="pixelated" or style.ImageRendering=="crisp-edges" then Enum.ResamplerMode.Pixelated else Enum.ResamplerMode.Default})
		if style.BorderRadius > 0 then item.ImageCorner = factory.modifier("UICorner", item.ImageClip or item.ImageGui, {CornerRadius = UDim.new(0, 0)}) end
		if not item.SVG and style.Filter and style.Filter.HasRaster then
			item.BlurGui=factory.create("ImageLabel",item.BoxGui,{Name="BlurredImage",Visible=false,ScaleType=Enum.ScaleType.Stretch})
		end
	end
	if not item.EmptyAlt then
		item.FallbackGui = factory.create("Frame", item.BoxGui, {Name = "ImageFallback", ClipsDescendants = true, Visible = item.Source == nil and not item.SVG})
		item.ErrorGui = factory.create("ImageLabel", item.FallbackGui, {Name = "BrokenImageIcon", Image = ERROR_IMAGE,
			Size = UDim2.fromOffset(ImageFallback.IconSize, ImageFallback.IconSize), Position = UDim2.fromOffset(style.Padding[4], style.Padding[1]), ScaleType = Enum.ScaleType.Stretch,
			Visible = item.Source == nil and not item.SVG})
	end
	if item.Alt ~= "" then
		item.AltGui = factory.create("TextLabel", item.FallbackGui or item.BoxGui, {Name = "Alt", Text = item.Alt,
			TextColor3 = style.Color, TextTransparency = 1 - (style.ColorAlpha or 1), FontFace = font, OpenTypeFeatures = style.OpenTypeFeatures,
			Visible = item.Source == nil and not item.SVG, ClipsDescendants = true})
	end
	ImageBox.updateFallback(item)
end

-- Source/alt changes retain the CSS box and hit target. Create only the paint
-- surfaces that an initially empty/broken image did not need yet.
function ImageBox.refreshResource(item: any,sourceChanged: boolean?)
	local factory,style=item.ImageFactory,item.Style
	local created=false
	if (item.Source or item.SVG)and not item.ImageGui then
		created=true
		item.ImageGui=factory.create("ImageLabel",item.BoxGui,{Name="Image",Image=item.Source or"",ScaleType=Enum.ScaleType.Stretch,
			ResampleMode=if style.ImageRendering=="pixelated"or style.ImageRendering=="crisp-edges"then Enum.ResamplerMode.Pixelated else Enum.ResamplerMode.Default})
	end
	if item.SVGExternal and item.ImageGui and not item.ImageClip then
		item.ImageClip=factory.create(if style.BorderRadius>0 then"CanvasGroup"else"Frame",item.BoxGui,{Name="ImageContent",ClipsDescendants=true})
		item.ImageGui.Parent=item.ImageClip
	end
	if item.ImageGui then
		if sourceChanged or created then
			item.ImageGui.Image=item.Source or""
			if Content then pcall(function()item.ImageGui.ImageContent=Content.fromUri(item.Source or"")end)end
		end
		item.ImageGui.Visible=style.Visibility~="hidden"and(item.Source~=nil or item.SVG~=nil)
	end
	if not item.EmptyAlt and not item.FallbackGui then
		item.FallbackGui=factory.create("Frame",item.BoxGui,{Name="ImageFallback",ClipsDescendants=true,Visible=false})
		item.ErrorGui=factory.create("ImageLabel",item.FallbackGui,{Name="BrokenImageIcon",Image=ERROR_IMAGE,Size=UDim2.fromOffset(ImageFallback.IconSize,ImageFallback.IconSize),Position=UDim2.fromOffset(style.Padding[4],style.Padding[1]),ScaleType=Enum.ScaleType.Stretch,Visible=false})
	end
	if item.Alt~=""and not item.AltGui then
		item.AltGui=factory.create("TextLabel",item.FallbackGui or item.BoxGui,{Name="Alt",Text=item.Alt,TextColor3=style.Color,
			TextTransparency=1-(style.ColorAlpha or 1),FontFace=item.FontFace,OpenTypeFeatures=style.OpenTypeFeatures,Visible=false,ClipsDescendants=true})
	end
	if item.AltGui then item.AltGui.Text=item.Alt end
	ImageBox.updateFallback(item)
	if item.EmptyAlt then
		if item.FallbackGui then item.FallbackGui.Visible=false end
		if item.AltGui then item.AltGui.Visible=false end
		if item.ErrorGui then item.ErrorGui.Visible=false end
	end
end

local function write(gui: any, key: string, value: any)
	if gui[key] ~= value then gui[key] = value end
end

function ImageBox.arrangeSVGEffect(item: any)
 if not item.SVGEffectGui or not item.SVGEffectPlan then return end
 local t,_,_,l=BorderGeometry.sizes(item.Style);local p=item.Style.Padding;local pad=item.SVGEffectPlan.Pad
 write(item.SVGEffectGui,'Position',UDim2.fromOffset(l+p[4]-pad,t+p[1]-pad))
 write(item.SVGEffectGui,'Size',UDim2.fromOffset(item.ContentWidth+pad*2,item.ContentHeight+pad*2))
end
function ImageBox.arrange(item: any)
	local style = item.Style
	if (style.BorderRadius or 0) > 0 then
		if not item.BoxCorner then item.BoxCorner = item.ImageFactory.modifier("UICorner", item.BoxGui, {CornerRadius = UDim.new(0, style.BorderRadius)}) end
		if item.ImageClip and item.ImageClip.ClassName == "Frame" then
			local oldClip = item.ImageClip
			item.ImageClip = item.ImageFactory.create("CanvasGroup", item.BoxGui, {Name = "ImageContent", ClipsDescendants = true})
			item.ImageGui.Parent = item.ImageClip
			if item.ImageCorner then item.ImageCorner.Parent = item.ImageClip end
			oldClip:Destroy()
		end
		if item.ImageGui and not item.ImageCorner then item.ImageCorner = item.ImageFactory.modifier("UICorner", item.ImageClip or item.ImageGui, {CornerRadius = UDim.new(0, 0)}) end
	end
	if item.BoxCorner then item.BoxCorner.CornerRadius = UDim.new(0, style.BorderRadius or 0) end
	if item.RequestDimensions and ImageFit.needsDimensions(style) then item.RequestDimensions() end
	-- State/media changes may introduce or remove the crop after initial creation.
	if item.ImageGui and not item.ImageClip and ImageFit.custom(style) and (not item.SVG or item.SVGExternal or style.ObjectViewBox) then
		item.ImageClip=item.ImageFactory.create(if style.BorderRadius>0 then 'CanvasGroup' else 'Frame',item.BoxGui,{Name='ImageContent',ClipsDescendants=true})
		item.ImageGui.Parent=item.ImageClip
		if item.ImageCorner then item.ImageCorner.Parent=item.ImageClip end
	end
	write(item.BoxGui, "Visible", style.Visibility ~= "hidden")
	local margin, padding = style.Margin, style.Padding
	local bt, br, bb, bl = BorderGeometry.sizes(style)
	write(item.BoxGui, "Position", UDim2.fromOffset(margin[4], margin[1]))
	write(item.BoxGui, "Size", UDim2.fromOffset(item.BoxWidth, item.BoxHeight))
	local position = UDim2.fromOffset(bl + padding[4], bt + padding[1])
	local size = UDim2.fromOffset(item.ContentWidth, item.ContentHeight)
	if item.ImageClip then
		write(item.ImageClip, "Position", position); write(item.ImageClip, "Size", size)
		write(item.ImageGui,'ScaleType',Enum.ScaleType.Stretch)
		local x, y, width, height = ImageFit.rectangle(item)
		-- object-view-box defines the fitted reference; original pixels outside
		-- that reference remain ink overflow, clipped only at the content box.
		write(item.ImageGui, "Position", UDim2.fromOffset(x, y))
		write(item.ImageGui, "Size", UDim2.fromOffset(width, height))
	elseif item.ImageGui then
		write(item.ImageGui, "Position", position); write(item.ImageGui, "Size", size)
		write(item.ImageGui, "ScaleType", if style.ObjectFit == "contain" then Enum.ScaleType.Fit elseif style.ObjectFit == "cover" then Enum.ScaleType.Crop else Enum.ScaleType.Stretch)
	end
	if item.FallbackGui then
		local innerWidth, innerHeight = math.max(0, item.BoxWidth - br - bl), math.max(0, item.BoxHeight - bt - bb)
		write(item.FallbackGui, "Position", UDim2.fromOffset(bl, bt))
		write(item.FallbackGui, "Size", UDim2.fromOffset(innerWidth, innerHeight))
		if item.ErrorGui then
			write(item.ErrorGui,"Position",UDim2.fromOffset(padding[4],padding[1]))
			write(item.ErrorGui,"Size",UDim2.fromOffset(ImageFallback.IconSize,ImageFallback.IconSize))
		end
		if item.AltGui then
			local left=padding[4]+ImageFallback.IconSize
			write(item.AltGui,"TextColor3",style.Color)
			write(item.AltGui,"TextTransparency",1-(style.ColorAlpha or 1))
			if item.FontFace then write(item.AltGui,"FontFace",item.FontFace)end
			write(item.AltGui, "Position", UDim2.fromOffset(left, padding[1]))
			write(item.AltGui, "Size", UDim2.fromOffset(math.max(0, innerWidth - left - padding[2]), item.ContentHeight))
		end
	elseif item.AltGui then write(item.AltGui, "Position", position); write(item.AltGui, "Size", size) end
	if item.ImageCorner then
		local outer = math.min(style.BorderRadius, item.BoxWidth / 2, item.BoxHeight / 2)
		-- Exact for uniform padding; elliptical inner corners from unequal padding
		-- are approximated by a smaller circular radius.
		local inner = math.max(0, outer - math.max(bt, br, bb, bl) - math.max(padding[1], padding[2], padding[3], padding[4]))
		write(item.ImageCorner, "CornerRadius", UDim.new(0, inner))
	end
	if item.BorderEdges then
		BorderBox.arrange(item.BorderEdges, style, item.BoxWidth, item.BoxHeight)
	end
	if item.Outline then OutlineBox.arrange(item.Outline, item.BoxWidth, item.BoxHeight) end
	if item.OpacityGroup then
		GroupOpacity.image(item)
	end
	if item.BlurGui then
		local pad=style.Filter.Outset
		write(item.BlurGui,"Position",UDim2.fromOffset(bl+padding[4]-pad,bt+padding[1]-pad))
		write(item.BlurGui,"Size",UDim2.fromOffset(item.ContentWidth+2*pad,item.ContentHeight+2*pad))
		write(item.BlurGui,"Visible",item.BlurReady==true and item.ContentWidth>0 and item.ContentHeight>0)
		write(item.ImageGui,"Visible",not item.BlurReady)
		if item.UpdateBlur then item.UpdateBlur() end
	end
 ImageBox.arrangeSVGEffect(item)
 if item.UpdateSVG then
  if item.SVGExternal or style.ObjectViewBox then
   local nw,nh=ImageFit.natural(item)
   local _,_,w,h=ImageFit.rectangle(item)
   local scale=if nw>0 and nh>0 then math.max(w/nw,h/nh) else 0
   item.SVGRasterWidth,item.SVGRasterHeight=nw*scale,nh*scale
  else item.SVGRasterWidth,item.SVGRasterHeight=nil,nil end
  item.UpdateSVG()
 end
	ImageBox.updateFallback(item)
end

return ImageBox
