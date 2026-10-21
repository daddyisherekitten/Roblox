--!strict
local CanvasBackground=require(script.Parent.CanvasBackground)
local WorkContext=require(script.Parent.Parent.WorkContext)
local TextureUpload=require(script.Parent.TextureUpload)
local Pixels = require(script.Parent.BorderCornerPixels)
local Paint = require(script.Parent.BorderPaint)
local Geometry = require(script.Parent.Parent.Layout.BorderGeometry)
local CornerRadii=require(script.Parent.CornerRadii)
local PaintLayer=require(script.Parent.PaintLayer)
local Corners = {}
local function write(gui: any, key: string, value: any)
	if gui[key] ~= value then gui[key] = value end
end
function Corners.new(diagnostic: any, createImage: any?): any
	local entries, count, total = {}, 0, 0
	-- Rounded surfaces are much larger than the small corner atlas used by Draw().
	-- Give them an independent, bounded cache so ordinary borders cannot consume
	-- the entire budget before an elliptically rounded box is rendered.
	local RADIUS_PIXEL_BUDGET = 1572864 -- 6 MiB at four bytes per pixel
	local radiusTotal = 0
	local radiusEntries=setmetatable({},{__mode="k"})
	local ownedRadiusEntries={}
	local alive, unavailable, warned = true, false, false
	local renderer = {}
	local function hide(entry: any)
		if entry then for _, label in entry.Labels do write(label, "Visible", false) end end
	end
	local function hideRadius(entry: any)
		if not entry then return end
		if entry.Surface then write(entry.Surface,"Visible",false) end
		if entry.Mask then write(entry.Mask,"Visible",false) end
		if entry.Border then write(entry.Border,"Visible",false) end
		for _,label in entry.Labels do write(label,"Visible",false) end
		for _,label in entry.Masks or {} do write(label,"Visible",false) end
		for _,piece in entry.Pieces do write(piece,"Visible",false) end
	end
	local function release(entry: any)
		if entry.Image then entry.Image:Destroy(); total -= entry.Pixels; entry.Image = nil end
	end
	local function report(message: string)
		if not warned then warned = true; diagnostic("border corners: " .. message .. "; using rectangular joins.") end
	end
	function renderer:Draw(edges: any, style: any, width: number, height: number): boolean
		local entry = entries[edges]
		local plan = Pixels.plan(style, width, height)
		if not alive or not plan then hide(entry); return false end
		local key = table.concat(plan.Sizes, ":")
		for side = 1, 4 do
			local _, _, kind = Paint.edge(style, side)
			if kind == "dashed" or kind == "dotted" then key ..= ":" .. width .. ":" .. height; break end
		end
		if not entry then
			if count >= 64 then report("64-box budget reached"); return false end
			entry = {Labels = {}}; entries[edges] = entry; count += 1
		end
		if entry.Key ~= key or entry.Style ~= style or not entry.Image then
			local size = plan.Width * plan.Height
			if entry.Width ~= plan.Width or entry.Height ~= plan.Height then release(entry) end
			if unavailable or total + (if entry.Image then 0 else size) > 262144 then
				hide(entry); report("EditableImage unavailable or pixel budget reached"); return false
			end
			local editable = entry.Image
			local allocated=editable==nil
			local ok, content = pcall(function()
				local dimensions = Vector2.new(plan.Width, plan.Height)
				if not editable then editable = if createImage then createImage(dimensions) else game:GetService("AssetService"):CreateEditableImage({Size = dimensions}) end
				assert(editable, "EditableImage allocation unavailable")
				TextureUpload.write(editable,dimensions,Pixels.render(style,plan))
				return Content.fromObject(editable)
			end)
			if not ok then
				if editable and allocated then editable:Destroy() end
				release(entry); hide(entry); unavailable = true; report(tostring(content)); return false
			end
			if not entry.Image then total += size end
			entry.Image, entry.Pixels, entry.Content = editable, size, content
			entry.Width, entry.Height, entry.Key, entry.Style = plan.Width, plan.Height, key, style
		end
		for index, tile in plan.Tiles do
			local label = entry.Labels[index]
			local visible = tile[3] > 0 and tile[4] > 0
			if visible then
				if not label then
					label = edges.Factory.create("ImageLabel", edges.Host, {Name = "BorderCorner_" .. index, ScaleType = Enum.ScaleType.Stretch})
					entry.Labels[index] = label
				end
				write(label, "ImageContent", entry.Content)
				write(label, "ImageRectOffset", Vector2.new(tile[1], tile[2]))
				write(label, "ImageRectSize", Vector2.new(tile[3], tile[4]))
				write(label, "Position", UDim2.fromOffset(tile[5], tile[6]))
				write(label, "Size", UDim2.fromOffset(tile[7], tile[8]))
			end
			if label then write(label, "Visible", visible) end
		end
		return true
	end
	function renderer:CanUseNative(style: any): boolean return CornerRadii.native(style) end
	local function insideShape(shape: string,u: number,v: number,rx: number,ry: number): boolean
		if rx<=0 or ry<=0 then return false end
		local x,y=(u-rx)/rx,(v-ry)/ry
		if shape=='square'then return true
		elseif shape=="bevel" then return u/rx+v/ry>=1
		elseif shape=="scoop" then return (u/rx)^2+(v/ry)^2>=1
		elseif shape=='notch'then return u>=rx or v>=ry
		elseif shape=="squircle" then return x^4+y^4<=1 end
		local k=tonumber(shape:match('^superellipse%((.-)%)$'))
		if k then local power=2^math.clamp(math.abs(k),0,10)
			return if k<0 then (u/rx)^power+(v/ry)^power>=1 else math.abs(x)^power+math.abs(y)^power<=1
		end
		return x^2+y^2<=1
	end
	local function pixelColor(style: any,sizes: {number},cornerIndex: number,u: number,v: number,rx: number,ry: number): (any,number,boolean,boolean)
		local shape=if style.CornerShapes then style.CornerShapes[cornerIndex]else style.CornerShape or "round"
		if not insideShape(shape,u,v,rx,ry) then return nil,0,false,false end
		local horizontalSide=if cornerIndex<=2 then 1 else 3
		local verticalSide=if cornerIndex==1 or cornerIndex==4 then 4 else 2
		local hs=sizes[horizontalSide]
		local vs=sizes[verticalSide]
		local innerX,innerY=math.max(0,rx-vs),math.max(0,ry-hs)
		local inside=innerX>0 and innerY>0 and u>=vs and v>=hs and insideShape(shape,u-vs,v-hs,innerX,innerY)
		if inside or (hs==0 and vs==0) then return style.Background,style.BackgroundAlpha or 1,false,true end
		local side=if v*rx<=u*ry then horizontalSide else verticalSide
		local color,alpha=Paint.edge(style,side)
		return color,alpha,true,true
	end
	local function outsideBackground(gui: any): any?
		local parent=gui and gui.Parent
		while parent do
			local transparency=parent.BackgroundTransparency
			if type(transparency)=="number" and transparency<=0 and parent.BackgroundColor3 then return parent.BackgroundColor3 end
			parent=parent.Parent
		end
		return nil
	end
	function renderer:DrawRadius(box: any,style: any,width: number,height: number): boolean?
		style=CanvasBackground.usedStyle(box,style)
		local entry=radiusEntries[box]
		if entry then entry.Generation=(entry.Generation or 0)+1 end
		if not alive or not style.BorderRadii or style.Visibility=="hidden" or width<=0 or height<=0
			or (style.CornerShape=="round" and ((style.BorderRadius or 0)>0 or CornerRadii.native(style))) then hideRadius(entry);return false end
		for _,image in style.BackgroundImages or {} do if image.Kind~="none" then hideRadius(entry);return false end end
		local resolved=CornerRadii.resolve(style,width,height);if not resolved then hideRadius(entry);return false end
		local maxRadius=0;for _,r in resolved do maxRadius=math.max(maxRadius,r[1],r[2]) end
		if maxRadius<=0 then hideRadius(entry);return false end
		local clipColor=if style.OverflowX=="hidden" or style.OverflowY=="hidden" then outsideBackground(box.Gui) else nil
		local sizes={Geometry.sizes(style)}
		if not style.Background and not clipColor and sizes[1]==0 and sizes[2]==0 and sizes[3]==0 and sizes[4]==0 then hideRadius(entry);return false end
		if not entry then entry={Labels={},Masks={},Pieces={},Generation=1};radiusEntries[box]=entry;table.insert(ownedRadiusEntries,entry) end
		local generation=entry.Generation
		local function current(): boolean return alive and radiusEntries[box]==entry and entry.Generation==generation end
		local layers=if clipColor then 3 else 2
		local available=math.max(0,RADIUS_PIXEL_BUDGET-radiusTotal+(entry.Pixels or 0))
		local scale=math.min(1,512/math.max(1,width),512/math.max(1,height),math.sqrt(available/math.max(1,width*height*layers)))
		-- The size limit applies to the complete atlas, not each plane. Keep
		-- tall clipped surfaces at the same resolution by packing their planes
		-- across columns; account for an unused cell in the bounded pixel cache.
		local columns,rows=1,layers
		if math.floor(height*scale+.5)*layers>1024 then
			columns=if math.floor(width*scale+.5)*layers<=1024 then layers else 2
			rows=math.ceil(layers/columns)
			scale=math.min(scale,math.sqrt(available/math.max(1,width*height*columns*rows)))
		end
		local surfaceWidth,surfaceHeight=math.max(1,math.floor(width*scale+.5)),math.max(1,math.floor(height*scale+.5))
		local atlasWidth,atlasHeight=surfaceWidth*columns,surfaceHeight*rows
		local pixels=atlasWidth*atlasHeight
		local key=string.format("%d:%d:%d:%d:%d:%d:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f:%s:%s:%s:%s",width,height,surfaceWidth,surfaceHeight,columns,rows,
			resolved[1][1],resolved[1][2],resolved[2][1],resolved[2][2],resolved[3][1],resolved[3][2],resolved[4][1],resolved[4][2],
			tostring(style.Background),tostring(style.BackgroundAlpha),tostring(clipColor),if style.CornerShapes then table.concat(style.CornerShapes,',')else style.CornerShape or "round")
		-- Styles are recascaded in place. Border paint belongs in the cache key
		-- even when the background and radius do not change on hover.
		for side=1,4 do
			local color,alpha,kind=Paint.edge(style,side)
			key..=string.format(":%s:%s:%s:%s:%s:%s",tostring(sizes[side]),tostring(color.R),tostring(color.G),tostring(color.B),tostring(alpha),kind)
		end
		if entry.Key~=key or entry.Style~=style or not entry.Image then
			local reusable=entry.Image and entry.AtlasWidth==atlasWidth and entry.AtlasHeight==atlasHeight
			if unavailable or radiusTotal-(entry.Pixels or 0)+pixels>RADIUS_PIXEL_BUDGET then hideRadius(entry);report("rounded-corner pixel budget reached");return false end
			local data=buffer.create(pixels*4)
			local borderTop,borderRight,borderBottom,borderLeft=table.unpack(sizes)
			local borderLayer=if clipColor then 2 else 1
			local borderColumn,borderRow=(borderLayer%columns)*surfaceWidth,math.floor(borderLayer/columns)*surfaceHeight
			local maskColumn,maskRow=(1%columns)*surfaceWidth,math.floor(1/columns)*surfaceHeight
			local pixelWidth,pixelHeight=width/surfaceWidth,height/surfaceHeight
			local function sampleAt(x: number,y: number): (any,number,boolean,boolean)
				local color,alpha,isBorder,inside=style.Background,style.BackgroundAlpha or 1,false,true
				if x<resolved[1][1] and y<resolved[1][2] then color,alpha,isBorder,inside=pixelColor(style,sizes,1,x,y,resolved[1][1],resolved[1][2])
				elseif x>width-resolved[2][1] and y<resolved[2][2] then color,alpha,isBorder,inside=pixelColor(style,sizes,2,width-x,y,resolved[2][1],resolved[2][2])
				elseif x>width-resolved[3][1] and y>height-resolved[3][2] then color,alpha,isBorder,inside=pixelColor(style,sizes,3,width-x,height-y,resolved[3][1],resolved[3][2])
				elseif x<resolved[4][1] and y>height-resolved[4][2] then color,alpha,isBorder,inside=pixelColor(style,sizes,4,x,height-y,resolved[4][1],resolved[4][2])
				elseif y<borderTop then color,alpha=Paint.edge(style,1);isBorder=true
				elseif x>width-borderRight then color,alpha=Paint.edge(style,2);isBorder=true
				elseif y>height-borderBottom then color,alpha=Paint.edge(style,3);isBorder=true
				elseif x<borderLeft then color,alpha=Paint.edge(style,4);isBorder=true end
				return color,alpha,isBorder,inside
			end
			local function writeAverage(at: number,r: number,g: number,b: number,a: number,samples: number)
				if a<=0 then return end
				buffer.writeu8(data,at,math.round(r/a*255));buffer.writeu8(data,at+1,math.round(g/a*255));buffer.writeu8(data,at+2,math.round(b/a*255))
				buffer.writeu8(data,at+3,math.round(a/samples*255))
			end
			for py=0,surfaceHeight-1 do for px=0,surfaceWidth-1 do
				if px%64==0 then WorkContext.checkpoint();if not current()then return nil end end
				local x,y=(px+.5)/surfaceWidth*width,(py+.5)/surfaceHeight*height
				local antialias=(x<resolved[1][1]+pixelWidth and y<resolved[1][2]+pixelHeight)
					or (x>width-resolved[2][1]-pixelWidth and y<resolved[2][2]+pixelHeight)
					or (x>width-resolved[3][1]-pixelWidth and y>height-resolved[3][2]-pixelHeight)
					or (x<resolved[4][1]+pixelWidth and y>height-resolved[4][2]-pixelHeight)
				local grid=if antialias then 4 else 1
				local samples=grid*grid
				local sr,sg,sb,sa,mr,mg,mb,ma,br,bg,bb,ba=0,0,0,0,0,0,0,0,0,0,0,0
				for sy=0,grid-1 do for sx=0,grid-1 do
					local sampleX=(px+(sx+.5)/grid)*pixelWidth
					local sampleY=(py+(sy+.5)/grid)*pixelHeight
					local color,alpha,isBorder,inside=sampleAt(sampleX,sampleY)
					if inside then
						if style.Background then
							local surfaceAlpha=style.BackgroundAlpha or 1
							sr+=style.Background.R*surfaceAlpha;sg+=style.Background.G*surfaceAlpha;sb+=style.Background.B*surfaceAlpha;sa+=surfaceAlpha
						end
						if isBorder and color and alpha>0 then br+=color.R*alpha;bg+=color.G*alpha;bb+=color.B*alpha;ba+=alpha end
					elseif clipColor then mr+=clipColor.R;mg+=clipColor.G;mb+=clipColor.B;ma+=1 end
				end end
				local at=(py*atlasWidth+px)*4
				writeAverage(at,sr,sg,sb,sa,samples)
				if clipColor then writeAverage(((py+maskRow)*atlasWidth+px+maskColumn)*4,mr,mg,mb,ma,samples) end
				writeAverage(((py+borderRow)*atlasWidth+px+borderColumn)*4,br,bg,bb,ba,samples)
			end end
			if not current()then return nil end
			if entry.Image and not reusable then entry.Image:Destroy();radiusTotal-=entry.Pixels;entry.Image=nil;entry.Pixels=nil end
			local editable=if reusable then entry.Image else nil
			local ok,content=pcall(function()
				local dimensions=Vector2.new(atlasWidth,atlasHeight)
				if not editable then editable=if createImage then createImage(dimensions) else game:GetService("AssetService"):CreateEditableImage({Size=dimensions})end
				assert(editable,"EditableImage allocation unavailable");if not TextureUpload.write(editable,dimensions,data,current)then return nil end;return Content.fromObject(editable)
			end)
			if not current()then if editable and not reusable and entry.Image~=editable then editable:Destroy()end;return nil end
			if not ok and WorkContext.isCancelled(content)then if editable and not reusable then editable:Destroy()end;error(content,0)end
			if not ok then
				if editable then editable:Destroy()end
				if reusable then radiusTotal-=entry.Pixels;entry.Image=nil;entry.Pixels=nil end
				hideRadius(entry);unavailable=true;report(tostring(content));return false
			end
			entry.Image,entry.Content,entry.Pixels,entry.Key,entry.Style=editable,content,pixels,key,style
			entry.AtlasWidth,entry.AtlasHeight=atlasWidth,atlasHeight
			entry.MaskOffset=Vector2.new(maskColumn,maskRow);entry.BorderOffset=Vector2.new(borderColumn,borderRow)
			entry.SurfaceWidth,entry.SurfaceHeight,entry.MaskColor=surfaceWidth,surfaceHeight,clipColor;if not reusable then radiusTotal+=pixels end
		end
		for _,label in entry.Labels do write(label,"Visible",false) end;for _,piece in entry.Pieces do write(piece,"Visible",false) end;for _,mask in entry.Masks do write(mask,"Visible",false) end
		if not entry.Surface then entry.Surface=PaintLayer.create(box.Factory,"ImageLabel",box.Gui,{Name="RoundedSurface",ScaleType=Enum.ScaleType.Stretch,ZIndex=0}) end
		write(entry.Surface,"ImageContent",entry.Content);write(entry.Surface,"ImageRectOffset",Vector2.new(0,0));write(entry.Surface,"ImageRectSize",Vector2.new(entry.SurfaceWidth,entry.SurfaceHeight))
		write(entry.Surface,"Position",UDim2.fromOffset(0,0));write(entry.Surface,"Size",UDim2.fromOffset(width,height));write(entry.Surface,"Visible",true)
		if clipColor and not entry.Mask then entry.Mask=PaintLayer.create(box.Factory,"ImageLabel",box.Gui,{Name="RoundedClipMask",ScaleType=Enum.ScaleType.Stretch,ZIndex=100000}) end
		if entry.Mask then
			write(entry.Mask,"ImageContent",entry.Content);write(entry.Mask,"ImageRectOffset",entry.MaskOffset);write(entry.Mask,"ImageRectSize",Vector2.new(entry.SurfaceWidth,entry.SurfaceHeight))
			write(entry.Mask,"Position",UDim2.fromOffset(0,0));write(entry.Mask,"Size",UDim2.fromOffset(width,height));write(entry.Mask,"Visible",clipColor~=nil)
		end
		if not entry.Border then entry.Border=PaintLayer.create(box.Factory,"ImageLabel",box.Gui,{Name="RoundedBorder",ScaleType=Enum.ScaleType.Stretch,ZIndex=100001}) end
		box.RasterBorderGui=entry.Border
		local overlayBorder=true
		for side=1,4 do local _,_,kind=Paint.edge(style,side);if kind~="solid" and kind~="none" then overlayBorder=false;break end end
		write(entry.Border,"ImageContent",entry.Content);write(entry.Border,"ImageRectOffset",entry.BorderOffset);write(entry.Border,"ImageRectSize",Vector2.new(entry.SurfaceWidth,entry.SurfaceHeight))
		write(entry.Border,"Position",UDim2.fromOffset(0,0));write(entry.Border,"Size",UDim2.fromOffset(width,height));write(entry.Border,"Visible",overlayBorder)
		style.RasterBorderOverlay=overlayBorder
		entry.Radii=resolved;box.ResolvedBorderRadii=resolved
		return true
	end
	function renderer:RemoveEdges(edges: any)
		local entry=entries[edges]
		if not entry then return end
		for _,label in entry.Labels do label:Destroy()end
		release(entry);entries[edges]=nil;count-=1
	end
	function renderer:Remove(box: any)
		for _,edges in {box.InsetEdges or false,box.Outline and box.Outline.Edges or false} do
			local entry=edges and entries[edges]
			if entry then release(entry);entries[edges]=nil;count-=1 end
		end
		local radius=radiusEntries[box]
		if radius then
			if radius.Image then radius.Image:Destroy();radius.Image=nil;radiusTotal-=radius.Pixels end
			local index=table.find(ownedRadiusEntries,radius)
			if index then table.remove(ownedRadiusEntries,index) end
			radiusEntries[box]=nil
		end
	end
	function renderer:Destroy()
		if not alive then return end
		alive = false
		for _, entry in entries do hide(entry); release(entry) end
		table.clear(entries)
		-- Radius lookup keys are weak; their EditableImages still need explicit
		-- destruction even if the render-box table was already collected.
		for _,entry in ownedRadiusEntries do if entry.Image then entry.Image:Destroy();entry.Image=nil end end
		radiusTotal=0
		table.clear(radiusEntries)
		table.clear(ownedRadiusEntries)
	end
	return renderer
end
return Corners

