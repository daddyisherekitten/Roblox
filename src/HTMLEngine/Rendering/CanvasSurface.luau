--!strict
--!optimize 2
-- Bounded CPU implementation of the first CanvasRenderingContext2D subset.
local Color = require(script.Parent.Parent.CSS.Color)
local Path = require(script.Parent.Parent.SVG.Path)
local TextFont = require(script.Parent.Parent.SVG.TextFont)
local CanvasPNG = require(script.Parent.CanvasPNG)
local CanvasSurface = {}
local paintCache,paintCacheSize={},0
local MAX_PATH_POINTS = 65536

local function finite(value: any): number
	assert(type(value) == "number" and value == value and math.abs(value) < math.huge, "Canvas argument must be a finite number")
	return value
end

local function truncate(value: any): number
	value=finite(value)
	return if value<0 then math.ceil(value) else math.floor(value)
end

local function clampByte(value: any): number
	if type(value)~="number"or value~=value or value<=0 then return 0 end
	if value>=255 then return 255 end
	local lower=math.floor(value);local fraction=value-lower
	if fraction>.5 or(fraction==.5 and lower%2==1)then return lower+1 end
	return lower
end

local function makeImageData(width: number,height: number,pixels: buffer?): any
	assert(width>0 and height>0,"ImageData dimensions must be greater than zero")
	assert(width<=2048 and height<=2048 and width*height<=4194304,"ImageData exceeds the Roblox pixel limit")
	local storage=pixels or buffer.create(width*height*4)
	local data={Kind="Uint8ClampedArray",Length=width*height*4,Pixels=storage}
	data.Get=function(key)
		if key=="length"or key=="byteLength"then return data.Length end
		local index=tonumber(key);if not index or index~=math.floor(index)or index<0 or index>=data.Length then return nil end
		return buffer.readu8(storage,index)
	end
	data.Set=function(key,value)
		local index=tonumber(key);if not index or index~=math.floor(index)or index<0 or index>=data.Length then return end
		buffer.writeu8(storage,index,clampByte(value))
	end
	local result={Kind="ImageData",Width=width,Height=height,Pixels=storage,Data=data}
	result.Get=function(key)
		if key=="width"then return width elseif key=="height"then return height elseif key=="data"then return data elseif key=="colorSpace"then return"srgb"end
		return nil
	end
	return result
end

local function paint(value: any): (Color3, number)
	assert(type(value) == "string", "Canvas color must be a CSS color string")
	local normalized = string.lower(value:match("^%s*(.-)%s*$") :: string)
	local cached=paintCache[normalized];if cached then return cached[1],cached[2]end
	local color, alpha = Color.parse(normalized)
	assert(color and color ~= "currentcolor" and alpha ~= nil, "Unsupported Canvas color: " .. value)
	if paintCacheSize>=256 then table.clear(paintCache);paintCacheSize=0 end
	paintCache[normalized]={color,alpha};paintCacheSize+=1
	return color, alpha
end

local function cloneState(state: any): any
	return {FillStyle=state.FillStyle,StrokeStyle=state.StrokeStyle,LineWidth=state.LineWidth,GlobalAlpha=state.GlobalAlpha,CompositeOperation=state.CompositeOperation,ShadowColor=state.ShadowColor,ShadowBlur=state.ShadowBlur,ShadowOffsetX=state.ShadowOffsetX,ShadowOffsetY=state.ShadowOffsetY,Font=state.Font,FontFace=state.FontFace,FontSize=state.FontSize,TextAlign=state.TextAlign,TextBaseline=state.TextBaseline,Direction=state.Direction,ImageSmoothingEnabled=state.ImageSmoothingEnabled,ImageSmoothingQuality=state.ImageSmoothingQuality,Transform=table.clone(state.Transform),Clip=table.clone(state.Clip)}
end

local glyphPaths=setmetatable({},{__mode="k"})
local function glyphPath(glyph: any): any
	local cached=glyphPaths[glyph]
	if cached and cached.Source==glyph.Path then return cached.Parts end
	local parts=Path.parse(glyph.Path or "")
	glyphPaths[glyph]={Source=glyph.Path,Parts=parts}
	return parts
end

local function kern(font: any,left: number?,right: number): number
	if not left then return 0 end
	for _,rule in font.Kern or {} do
		if rule.Coverage then
			if rule.Coverage[left] then return rule.Pairs[tostring(rule.Class1[left] or 0)..":"..tostring(rule.Class2[right] or 0)] or 0 end
		else
			local value=rule.Pairs[tostring(left)..":"..tostring(right)];if value then return value end
		end
	end
	return 0
end

local function parseFont(value: any): (any?,number?)
	if type(value)~="string" then return nil end
	local lowered=string.lower(value)
	local size=tonumber(lowered:match("(%d+%.?%d*)px"))
	if not size or size<=0 or size>2048 then return nil end
	local bold=lowered:match("%f[%w]bold%f[%W]")~=nil
	local numeric=tonumber(lowered:match("%f[%d](%d%d%d)%f[%D]"));if numeric and numeric>=600 then bold=true end
	local italic=lowered:match("%f[%w]italic%f[%W]")~=nil or lowered:match("%f[%w]oblique%f[%W]")~=nil
	local face=if bold and italic then TextFont.Faces.BoldIt elseif bold then TextFont.Faces.Bold elseif italic then TextFont.Faces.It else TextFont
	return face,size
end

local BLEND_OPERATIONS = {multiply=true,screen=true,overlay=true,darken=true,lighten=true,['color-dodge']=true,['color-burn']=true,['hard-light']=true,['soft-light']=true,difference=true,exclusion=true}
local NON_SEPARABLE_OPERATIONS = {hue=true,saturation=true,color=true,luminosity=true}
local COMPOSITE_OPERATIONS = {['source-over']=true,['source-in']=true,['source-out']=true,['source-atop']=true,['destination-over']=true,['destination-in']=true,['destination-out']=true,['destination-atop']=true,lighter=true,copy=true,xor=true,multiply=true,screen=true,overlay=true,darken=true,lighten=true,['color-dodge']=true,['color-burn']=true,['hard-light']=true,['soft-light']=true,difference=true,exclusion=true,hue=true,saturation=true,color=true,luminosity=true}

local function blendChannel(operation: string,source: number,destination: number): number
	if operation=="multiply"then return source*destination
	elseif operation=="screen"then return source+destination-source*destination
	elseif operation=="overlay"then return if destination<=.5 then 2*source*destination else 1-2*(1-source)*(1-destination)
	elseif operation=="darken"then return math.min(source,destination)
	elseif operation=="lighten"then return math.max(source,destination)
	elseif operation=="color-dodge"then return if source>=1 then 1 else math.min(1,destination/(1-source))
	elseif operation=="color-burn"then return if source<=0 then 0 else 1-math.min(1,(1-destination)/source)
	elseif operation=="hard-light"then return if source<=.5 then 2*source*destination else 1-2*(1-source)*(1-destination)
	elseif operation=="soft-light"then
		if source<=.5 then return destination-(1-2*source)*destination*(1-destination)end
		local curve=if destination<=.25 then ((16*destination-12)*destination+4)*destination else math.sqrt(destination)
		return destination+(2*source-1)*(curve-destination)
	elseif operation=="difference"then return math.abs(destination-source)
	else return destination+source-2*destination*source end
end

local function luminosity(r: number,g: number,b: number): number return .3*r+.59*g+.11*b end
local function saturation(r: number,g: number,b: number): number return math.max(r,g,b)-math.min(r,g,b) end
local function clipColor(r: number,g: number,b: number): (number,number,number)
	local light=luminosity(r,g,b);local minimum,maximum=math.min(r,g,b),math.max(r,g,b)
	if minimum<0 then local divisor=light-minimum;if divisor~=0 then r,g,b=light+(r-light)*light/divisor,light+(g-light)*light/divisor,light+(b-light)*light/divisor end end
	maximum=math.max(r,g,b);if maximum>1 then local divisor=maximum-light;if divisor~=0 then r,g,b=light+(r-light)*(1-light)/divisor,light+(g-light)*(1-light)/divisor,light+(b-light)*(1-light)/divisor end end
	return math.clamp(r,0,1),math.clamp(g,0,1),math.clamp(b,0,1)
end
local function setLuminosity(r: number,g: number,b: number,light: number): (number,number,number)
	local delta=light-luminosity(r,g,b);return clipColor(r+delta,g+delta,b+delta)
end
local function setSaturation(r: number,g: number,b: number,value: number): (number,number,number)
	local minimum,maximum=math.min(r,g,b),math.max(r,g,b);if maximum==minimum then return 0,0,0 end
	local function adjust(channel)return if channel==minimum then 0 elseif channel==maximum then value else (channel-minimum)*value/(maximum-minimum)end
	return adjust(r),adjust(g),adjust(b)
end
local function blendNonSeparable(operation: string,sr: number,sg: number,sb: number,dr: number,dg: number,db: number): (number,number,number)
	if operation=="hue"then sr,sg,sb=setSaturation(sr,sg,sb,saturation(dr,dg,db));return setLuminosity(sr,sg,sb,luminosity(dr,dg,db))
	elseif operation=="saturation"then local light=luminosity(dr,dg,db);dr,dg,db=setSaturation(dr,dg,db,saturation(sr,sg,sb));return setLuminosity(dr,dg,db,light)
	elseif operation=="color"then return setLuminosity(sr,sg,sb,luminosity(dr,dg,db))
	else return setLuminosity(dr,dg,db,luminosity(sr,sg,sb))end
end

local function compositeByte(operation: string,source: number,destination: number,alpha: number,destinationAlpha: number,sourceFactor: number,destinationFactor: number,outputAlpha: number,isBlend: boolean,mixed: number?): number
	if outputAlpha<=0 then return 0 end
	local premultiplied
	if isBlend then
		local blended=if mixed~=nil then mixed else blendChannel(operation,source,destination)
		premultiplied=(1-alpha)*destination*destinationAlpha+(1-destinationAlpha)*source*alpha+alpha*destinationAlpha*blended
	else
		premultiplied=source*alpha*sourceFactor+destination*destinationAlpha*destinationFactor
	end
	return math.round(math.clamp(premultiplied/outputAlpha,0,1)*255)
end

local function shadowRadii(blur: number): {number}
	local sigma=blur/2;local lower=math.floor(math.sqrt(4*sigma*sigma+1));if lower%2==0 then lower-=1 end
	local count=math.clamp(math.round((12*sigma*sigma-3*lower*lower-12*lower-9)/(-4*lower-4)),0,3)
	return {(lower-1+(if count>=1 then 0 else 2))/2,(lower-1+(if count>=2 then 0 else 2))/2,(lower-1+(if count>=3 then 0 else 2))/2}
end

local function shadowFilter(source: buffer,target: buffer,width: number,height: number,radius: number,vertical: boolean,checkpoint: any?)
	local length,lines=if vertical then height else width,if vertical then width else height;local stride,step=if vertical then width else 1,if vertical then 1 else width;local divisor=radius*2+1
	for line=0,lines-1 do if checkpoint then checkpoint()end;local base,sum=line*step,0;for index=0,math.min(radius,length-1)do sum+=buffer.readu8(source,base+index*stride)end
		for index=0,length-1 do buffer.writeu8(target,base+index*stride,math.round(sum/divisor));local remove,add=index-radius,index+radius+1;if remove>=0 then sum-=buffer.readu8(source,base+remove*stride)end;if add<length then sum+=buffer.readu8(source,base+add*stride)end end
	end
end

function CanvasSurface.new(width: number, height: number,checkpoint: any?): any
	assert(width == math.floor(width) and height == math.floor(height) and width >= 0 and height >= 0, "Canvas dimensions must be non-negative integers")
	assert(width <= 2048 and height <= 2048 and width * height <= 4194304, "Canvas bitmap exceeds the Roblox limit")
	local self = {Width=width,Height=height,Pixels=buffer.create(width*height*4),Dirty=true,DirtyFull=true,DirtyBounds=nil,Checkpoint=checkpoint,
		State={FillStyle="#000000",StrokeStyle="#000000",LineWidth=1,GlobalAlpha=1,CompositeOperation="source-over",ShadowColor="rgba(0, 0, 0, 0)",ShadowBlur=0,ShadowOffsetX=0,ShadowOffsetY=0,Font="10px sans-serif",FontFace=TextFont,FontSize=10,TextAlign="start",TextBaseline="alphabetic",Direction="ltr",ImageSmoothingEnabled=true,ImageSmoothingQuality="low",Transform={1,0,0,1,0,0},Clip={}},Stack={},Path={},Current=nil,PathPointCount=0}
	local function point(x,y)
		x,y=finite(x),finite(y);local m=self.State.Transform
		return {X=m[1]*x+m[3]*y+m[5],Y=m[2]*x+m[4]*y+m[6],UX=x,UY=y}
	end
	local function multiply(a,b,c,d,e,f)
		a,b,c,d,e,f=finite(a),finite(b),finite(c),finite(d),finite(e),finite(f);local m=self.State.Transform
		self.State.Transform={m[1]*a+m[3]*b,m[2]*a+m[4]*b,m[1]*c+m[3]*d,m[2]*c+m[4]*d,m[1]*e+m[3]*f+m[5],m[2]*e+m[4]*f+m[6]}
	end
	local function inverse(matrix)
		local determinant=matrix[1]*matrix[4]-matrix[2]*matrix[3]
		if math.abs(determinant)<1e-12 then return nil end
		return {matrix[4]/determinant,-matrix[2]/determinant,-matrix[3]/determinant,matrix[1]/determinant,(matrix[3]*matrix[6]-matrix[4]*matrix[5])/determinant,(matrix[2]*matrix[5]-matrix[1]*matrix[6])/determinant}
	end
	local function gradient(kind,values)
		local result={Kind="CanvasGradient",GradientKind=kind,Values=values,Inverse=inverse(self.State.Transform),Stops={}}
		function result:AddColorStop(offset,color)
			offset=finite(offset);assert(offset>=0 and offset<=1,"Canvas gradient color-stop offset must be between 0 and 1")
			local parsed,alpha=paint(color);table.insert(self.Stops,{Offset=offset,Color=parsed,Alpha=alpha});table.sort(self.Stops,function(a,b)return a.Offset<b.Offset end)
		end
		result.Get=function(key)
			if key=="addColorStop" then return function(args)result:AddColorStop(args[1],args[2])end end
			return nil
		end
		return result
	end
	local function gradientSample(value,x,y)
		local stops=value.Stops;if #stops==0 or not value.Inverse then return Color3.new(),0 end
		local m=value.Inverse;local ux=m[1]*x+m[3]*y+m[5];local uy=m[2]*x+m[4]*y+m[6];local v=value.Values;local t
		if value.GradientKind=="linear" then
			local dx,dy=v[3]-v[1],v[4]-v[2];local denominator=dx*dx+dy*dy
			if denominator==0 then return Color3.new(),0 end
			t=((ux-v[1])*dx+(uy-v[2])*dy)/denominator
		else
			local qx,qy=ux-v[1],uy-v[2];local dx,dy,dr=v[4]-v[1],v[5]-v[2],v[6]-v[3]
			local a=dx*dx+dy*dy-dr*dr;local b=-2*(qx*dx+qy*dy+v[3]*dr);local c=qx*qx+qy*qy-v[3]*v[3]
			if math.abs(a)<1e-12 then
				if math.abs(b)<1e-12 then return Color3.new(),0 end;t=-c/b
			else
				local discriminant=b*b-4*a*c;if discriminant<0 then return Color3.new(),0 end
				local root=math.sqrt(discriminant);t=math.max((-b-root)/(2*a),(-b+root)/(2*a))
			end
		end
		if t<=stops[1].Offset then return stops[1].Color,stops[1].Alpha end
		if t>=stops[#stops].Offset then return stops[#stops].Color,stops[#stops].Alpha end
		for i=2,#stops do
			local right=stops[i];if t<=right.Offset then local left=stops[i-1];local span=right.Offset-left.Offset;local f=if span==0 then 1 else (t-left.Offset)/span
				return Color3.new(left.Color.R+(right.Color.R-left.Color.R)*f,left.Color.G+(right.Color.G-left.Color.G)*f,left.Color.B+(right.Color.B-left.Color.B)*f),left.Alpha+(right.Alpha-left.Alpha)*f end
		end
		return stops[#stops].Color,stops[#stops].Alpha
	end
	local imageSample: any
	local function imageSource(value: any): any?
		local source=if type(value)=="table"then value.CanvasSource or value.CanvasImageSource or value else nil
		if source and type(source.Width)=="number"and type(source.Height)=="number"and typeof(source.Pixels)=="buffer"and source.Width>=0 and source.Height>=0 and buffer.len(source.Pixels)>=source.Width*source.Height*4 then return source end
		return nil
	end
	local function sampler(value)
		if type(value)=="string" then local color,alpha=paint(value);return function()return color,alpha end end
		assert(type(value)=="table"and(value.Kind=="CanvasGradient"or value.Kind=="CanvasPattern"),"Canvas paint must be a CSS color, CanvasGradient or CanvasPattern")
		if value.Kind=="CanvasGradient"then return function(x,y)return gradientSample(value,x+.5,y+.5)end end
		local source=value.Source;if source.Pixels==self.Pixels then local snapshot=buffer.create(buffer.len(source.Pixels));buffer.copy(snapshot,0,source.Pixels);source={Width=source.Width,Height=source.Height,Pixels=snapshot}end
		local repeatX=value.Repetition=="repeat"or value.Repetition=="repeat-x";local repeatY=value.Repetition=="repeat"or value.Repetition=="repeat-y"
		return function(x,y)
			local base,patternMatrix=value.Inverse,value.PatternInverse;if not base or not patternMatrix or source.Width==0 or source.Height==0 then return Color3.new(),0 end
			local dx,dy=x+.5,y+.5;local ux=base[1]*dx+base[3]*dy+base[5];local uy=base[2]*dx+base[4]*dy+base[6];local px=patternMatrix[1]*ux+patternMatrix[3]*uy+patternMatrix[5];local py=patternMatrix[2]*ux+patternMatrix[4]*uy+patternMatrix[6]
			if(not repeatX and(px<0 or px>=source.Width))or(not repeatY and(py<0 or py>=source.Height))then return Color3.new(),0 end
			if repeatX then px=(px%source.Width+source.Width)%source.Width end;if repeatY then py=(py%source.Height+source.Height)%source.Height end
			if px<0 or py<0 or px>=source.Width or py>=source.Height then return Color3.new(),0 end
			if self.State.ImageSmoothingEnabled then px=math.clamp(px,.5,source.Width-.5);py=math.clamp(py,.5,source.Height-.5)end
			return imageSample(source,px,py,self.State.ImageSmoothingEnabled)
		end
	end
	local function winding(points,x,y)
		local value=0
		for i=1,#points do local a,b=points[i],points[if i==#points then 1 else i+1];local side=(b.X-a.X)*(y-a.Y)-(x-a.X)*(b.Y-a.Y)
			if a.Y<=y then if b.Y>y and side>0 then value+=1 end elseif b.Y<=y and side<0 then value-=1 end end
		return value
	end
	local function contains(region,x,y)
		local value=0;for _,points in region.Polygons do value+=winding(points,x,y)end
		return if region.Rule=="evenodd" then math.abs(value)%2==1 else value~=0
	end
	local function insideClip(x,y)
		for _,region in self.State.Clip do if not contains(region,x+.5,y+.5)then return false end end;return true
	end

	local function blend(x: number,y: number,color: Color3,alpha: number,rawAlpha: boolean?)
		x,y=math.floor(x),math.floor(y)
		if x<0 or y<0 or x>=width or y>=height or(#self.State.Clip>0 and not insideClip(x,y))then return end
		alpha=math.clamp(alpha*(if rawAlpha then 1 else self.State.GlobalAlpha),0,1)
		local offset=(y*width+x)*4
		if self.DrawingSource then
			local existingAlpha=buffer.readu8(self.DrawingSource,offset+3)/255;local outputAlpha=alpha+existingAlpha*(1-alpha)
			local keep=existingAlpha*(1-alpha);local denominator=if outputAlpha>0 then 255/outputAlpha else 0
			local oldR=buffer.readu8(self.DrawingSource,offset)/255;local oldG=buffer.readu8(self.DrawingSource,offset+1)/255;local oldB=buffer.readu8(self.DrawingSource,offset+2)/255
			buffer.writeu8(self.DrawingSource,offset,math.round(math.clamp(color.R*alpha+oldR*keep,0,outputAlpha)*denominator));buffer.writeu8(self.DrawingSource,offset+1,math.round(math.clamp(color.G*alpha+oldG*keep,0,outputAlpha)*denominator));buffer.writeu8(self.DrawingSource,offset+2,math.round(math.clamp(color.B*alpha+oldB*keep,0,outputAlpha)*denominator));buffer.writeu8(self.DrawingSource,offset+3,math.round(outputAlpha*255));local bounds=self.DrawingBounds;if x<bounds[1]then bounds[1]=x end;if y<bounds[2]then bounds[2]=y end;if x>bounds[3]then bounds[3]=x end;if y>bounds[4]then bounds[4]=y end;return
		end
		local destinationPixels=self.CompositeBackdrop or self.Pixels;local destinationAlpha=buffer.readu8(destinationPixels,offset+3)/255
		local destinationR=buffer.readu8(destinationPixels,offset)/255;local destinationG=buffer.readu8(destinationPixels,offset+1)/255;local destinationB=buffer.readu8(destinationPixels,offset+2)/255
		local sourceFactor,destinationFactor=1,1-alpha;local operation=self.State.CompositeOperation
		if operation=="source-in"then sourceFactor,destinationFactor=destinationAlpha,0
		elseif operation=="source-out"then sourceFactor,destinationFactor=1-destinationAlpha,0
		elseif operation=="source-atop"then sourceFactor,destinationFactor=destinationAlpha,1-alpha
		elseif operation=="destination-over"then sourceFactor,destinationFactor=1-destinationAlpha,1
		elseif operation=="destination-in"then sourceFactor,destinationFactor=0,alpha
		elseif operation=="destination-out"then sourceFactor,destinationFactor=0,1-alpha
		elseif operation=="destination-atop"then sourceFactor,destinationFactor=1-destinationAlpha,alpha
		elseif operation=="lighter"then sourceFactor,destinationFactor=1,1
		elseif operation=="copy"then sourceFactor,destinationFactor=1,0
		elseif operation=="xor"then sourceFactor,destinationFactor=1-destinationAlpha,1-alpha end
		local isNonSeparable=NON_SEPARABLE_OPERATIONS[operation]==true;local nonR,nonG,nonB
		if isNonSeparable then nonR,nonG,nonB=blendNonSeparable(operation,color.R,color.G,color.B,destinationR,destinationG,destinationB)end
		local isBlend=BLEND_OPERATIONS[operation]==true or isNonSeparable;local outputAlpha=if isBlend then alpha+destinationAlpha-alpha*destinationAlpha else math.clamp(alpha*sourceFactor+destinationAlpha*destinationFactor,0,1)
		buffer.writeu8(self.Pixels,offset,compositeByte(operation,color.R,destinationR,alpha,destinationAlpha,sourceFactor,destinationFactor,outputAlpha,isBlend,nonR));buffer.writeu8(self.Pixels,offset+1,compositeByte(operation,color.G,destinationG,alpha,destinationAlpha,sourceFactor,destinationFactor,outputAlpha,isBlend,nonG));buffer.writeu8(self.Pixels,offset+2,compositeByte(operation,color.B,destinationB,alpha,destinationAlpha,sourceFactor,destinationFactor,outputAlpha,isBlend,nonB));buffer.writeu8(self.Pixels,offset+3,math.round(outputAlpha*255));if not self.DirtyFull then self.Dirty,self.DirtyFull,self.DirtyBounds=true,true,nil end
	end
	local function shadowActive()
		local _,alpha=paint(self.State.ShadowColor);return alpha>0
	end
	local function sampleMask(mask,maskWidth,maskHeight,x,y)
		local ix,iy=math.floor(x),math.floor(y);local fx,fy=x-ix,y-iy;local value=0
		for dy=0,1 do for dx=0,1 do local px,py=ix+dx,iy+dy;if px>=0 and py>=0 and px<maskWidth and py<maskHeight then value+=buffer.readu8(mask,py*maskWidth+px)*(if dx==0 then 1-fx else fx)*(if dy==0 then 1-fy else fy)end end end
		return value/255
	end
	local function finishShadow()
		local source,bounds=self.DrawingSource,self.DrawingBounds;self.DrawingSource,self.DrawingBounds=nil,nil;if not source or bounds[1]==math.huge then return end
		local x0,y0,x1,y1=bounds[1],bounds[2],bounds[3],bounds[4];local sourceWidth,sourceHeight=x1-x0+1,y1-y0+1;local radii=shadowRadii(self.State.ShadowBlur);local pad=radii[1]+radii[2]+radii[3];local maskWidth,maskHeight=sourceWidth+2*pad,sourceHeight+2*pad;local mask,temp=buffer.create(maskWidth*maskHeight),buffer.create(maskWidth*maskHeight)
		for y=y0,y1 do if checkpoint then checkpoint()end;for x=x0,x1 do buffer.writeu8(mask,(y-y0+pad)*maskWidth+x-x0+pad,buffer.readu8(source,(y*width+x)*4+3))end end
		for _,radius in radii do if radius>0 then shadowFilter(mask,temp,maskWidth,maskHeight,radius,false,checkpoint);shadowFilter(temp,mask,maskWidth,maskHeight,radius,true,checkpoint)end end
		local shadowColor,shadowAlpha=paint(self.State.ShadowColor);local offsetX,offsetY=self.State.ShadowOffsetX,self.State.ShadowOffsetY;local full=self.State.CompositeOperation=="source-in"or self.State.CompositeOperation=="source-out"or self.State.CompositeOperation=="destination-in"or self.State.CompositeOperation=="destination-atop"or self.State.CompositeOperation=="copy"
		local firstX,lastX,firstY,lastY=0,width-1,0,height-1;if not full then firstX=math.max(0,math.floor(math.min(x0,x0+offsetX-pad)));lastX=math.min(width-1,math.ceil(math.max(x1,x1+offsetX+pad)));firstY=math.max(0,math.floor(math.min(y0,y0+offsetY-pad)));lastY=math.min(height-1,math.ceil(math.max(y1,y1+offsetY+pad)))end
		for y=firstY,lastY do if checkpoint then checkpoint()end;for x=firstX,lastX do local at=(y*width+x)*4;local backAlpha=sampleMask(mask,maskWidth,maskHeight,x-offsetX-x0+pad,y-offsetY-y0+pad)*shadowAlpha;local sourceAlpha=buffer.readu8(source,at+3)/255;local outputAlpha=sourceAlpha+backAlpha*(1-sourceAlpha);local color=Color3.new()
			if outputAlpha>0 then local shadowWeight=backAlpha*(1-sourceAlpha);local inverse=1/outputAlpha;color=Color3.new(math.clamp((buffer.readu8(source,at)/255*sourceAlpha+shadowColor.R*shadowWeight)*inverse,0,1),math.clamp((buffer.readu8(source,at+1)/255*sourceAlpha+shadowColor.G*shadowWeight)*inverse,0,1),math.clamp((buffer.readu8(source,at+2)/255*sourceAlpha+shadowColor.B*shadowWeight)*inverse,0,1))end
			blend(x,y,color,outputAlpha,true)
		end end
	end
	local function beginComposite()
		local operation=self.State.CompositeOperation
		if operation~="source-in"and operation~="source-out"and operation~="destination-in"and operation~="destination-atop"and operation~="copy"then return end
		self.CompositeBackdrop=buffer.create(width*height*4);buffer.copy(self.CompositeBackdrop,0,self.Pixels)
		for y=0,height-1 do if checkpoint then checkpoint()end;for x=0,width-1 do if insideClip(x,y)then blend(x,y,Color3.new(),0)end end end
	end
	local function endComposite()self.CompositeBackdrop=nil end
	local function beginDraw()if shadowActive()then self.DrawingSource=buffer.create(width*height*4);self.DrawingBounds={math.huge,math.huge,-math.huge,-math.huge}else beginComposite()end end
	local function endDraw()if self.DrawingSource then finishShadow()else endComposite()end end
	local function pixelBounds(x,y,w,h)
		x,y,w,h=finite(x),finite(y),finite(w),finite(h)
		local x1,x2=math.floor(math.min(x,x+w)),math.ceil(math.max(x,x+w))-1
		local y1,y2=math.floor(math.min(y,y+h)),math.ceil(math.max(y,y+h))-1
		x1,x2,y1,y2=math.max(0,x1),math.min(width-1,x2),math.max(0,y1),math.min(height-1,y2)
		if x2<x1 or y2<y1 then return nil end;return x1,y1,x2,y2
	end
	local function identityTransform(): boolean local m=self.State.Transform;return m[1]==1 and m[2]==0 and m[3]==0 and m[4]==1 and m[5]==0 and m[6]==0 end
	local function line(a,b,sample)
		local m=self.State.Transform;local scale=math.sqrt((m[1]*m[1]+m[2]*m[2]+m[3]*m[3]+m[4]*m[4])/2)
		local half=self.State.LineWidth*scale/2;local dx,dy=b.X-a.X,b.Y-a.Y;local length2=dx*dx+dy*dy
		for y=math.max(0,math.floor(math.min(a.Y,b.Y)-half)),math.min(height-1,math.ceil(math.max(a.Y,b.Y)+half)) do if checkpoint then checkpoint()end
			for x=math.max(0,math.floor(math.min(a.X,b.X)-half)),math.min(width-1,math.ceil(math.max(a.X,b.X)+half)) do
				local px,py=x+.5,y+.5;local t=if length2==0 then 0 else math.clamp(((px-a.X)*dx+(py-a.Y)*dy)/length2,0,1);local qx,qy=a.X+t*dx,a.Y+t*dy
				if (px-qx)^2+(py-qy)^2<=half^2 then local color,alpha=sample(x,y);blend(x,y,color,alpha) end
			end
		end
	end
	local function scanPolygon(points,callback)
		if #points<3 then return end;local minY,maxY=math.huge,-math.huge;for _,p in points do minY,maxY=math.min(minY,p.Y),math.max(maxY,p.Y)end
		for y=math.max(0,math.floor(minY)),math.min(height-1,math.ceil(maxY)-1) do if checkpoint then checkpoint()end
			local scan,intersections=y+.5,{};for i=1,#points do local q,r=points[i],points[if i==#points then 1 else i+1];if(q.Y<=scan and r.Y>scan)or(r.Y<=scan and q.Y>scan)then table.insert(intersections,q.X+(scan-q.Y)*(r.X-q.X)/(r.Y-q.Y))end end;table.sort(intersections)
			for i=1,#intersections-1,2 do for x=math.max(0,math.ceil(intersections[i]-.5)),math.min(width-1,math.floor(intersections[i+1]-.5))do callback(x,y)end end
		end
	end
	local function pathRegion(rule)
		rule=if rule==nil then "nonzero" else rule;assert(rule=="nonzero" or rule=="evenodd","Unsupported Canvas fill rule: "..tostring(rule))
		local polygons={};for _,path in self.Path do if #path.Points>=3 then local copy={};for _,p in path.Points do table.insert(copy,{X=p.X,Y=p.Y})end;table.insert(polygons,copy)end end
		return {Rule=rule,Polygons=polygons}
	end
	local function scanRegion(region,callback)
		local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
		for _,points in region.Polygons do for _,p in points do minX,minY,maxX,maxY=math.min(minX,p.X),math.min(minY,p.Y),math.max(maxX,p.X),math.max(maxY,p.Y)end end
		if minX==math.huge then return end
		for y=math.max(0,math.floor(minY)),math.min(height-1,math.ceil(maxY)-1)do if checkpoint then checkpoint()end;for x=math.max(0,math.floor(minX)),math.min(width-1,math.ceil(maxX)-1)do if contains(region,x+.5,y+.5)then callback(x,y)end end end
	end
	local function quadrilateral(x,y,w,h)return {point(x,y),point(x+w,y),point(x+w,y+h),point(x,y+h)}end
	local function textLayout(value: any,x: any,y: any,maxWidth: any?): any
		value=tostring(value);x,y=finite(x),finite(y);assert(#value<=16384,"Canvas text exceeds the string limit")
		local font,size=self.State.FontFace,self.State.FontSize;local scale=size/font.Units
		local codepoints={};for _,codepoint in utf8.codes(value)do table.insert(codepoints,codepoint);assert(#codepoints<=4096,"Canvas text exceeds the glyph limit")end
		local glyphs={};local advance,previous,index=0,nil,1
		while index<=#codepoints do if checkpoint and index%128==1 then checkpoint()end
			local codepoint=codepoints[index];local composed=if index<#codepoints then font.Compose[tostring(codepoint)..":"..tostring(codepoints[index+1])]else nil;local consumed=1
			if composed then codepoint=composed;consumed=2 end
			local id=font.Cmap[codepoint]or 0
			if consumed==1 then
				for _,ligature in font.Ligatures or {}do
					if ligature.Sequence[1]~=id or index+#ligature.Sequence-1>#codepoints then continue end
					local matches=true;for offset=2,#ligature.Sequence do if font.Cmap[codepoints[index+offset-1]]~=ligature.Sequence[offset]then matches=false;break end end
					if matches then id=ligature.Glyph;consumed=#ligature.Sequence;break end
				end
			end
			local glyph=font.Glyphs[id]or font.Glyphs[0];advance+=kern(font,previous,id)*scale;table.insert(glyphs,{Glyph=glyph,X=advance});advance+=glyph.Advance*scale;previous=id;index+=consumed
		end
		local stretch=1;if maxWidth~=nil then local limit=finite(maxWidth);if limit>0 and advance>limit then stretch=limit/advance end end
		local widthValue=advance*stretch;local align=self.State.TextAlign
		if align=="start"then align=if self.State.Direction=="rtl"then"right"else"left"elseif align=="end"then align=if self.State.Direction=="rtl"then"left"else"right"end
		local originX=x-(if align=="center"then widthValue/2 elseif align=="right"then widthValue else 0)
		local ascent,descent=font.Ascent*scale,-font.Descent*scale;local baseline=y;local mode=self.State.TextBaseline
		if mode=="top"then baseline=y+ascent elseif mode=="hanging"then baseline=y+ascent*.8 elseif mode=="middle"then baseline=y+(font.Ascent+font.Descent)*scale/2 elseif mode=="bottom"or mode=="ideographic"then baseline=y-descent end
		return {Glyphs=glyphs,Font=font,Scale=scale,Stretch=stretch,Width=widthValue,OriginX=originX,Baseline=baseline,InputX=x,InputY=y,Ascent=ascent,Descent=descent}
	end
	local function textBounds(layout: any): (number,number,number,number)
		local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
		local function include(x,y)local px=layout.OriginX+x*layout.Scale*layout.Stretch;local py=layout.Baseline-y*layout.Scale;if px<minX then minX=px end;if py<minY then minY=py end;if px>maxX then maxX=px end;if py>maxY then maxY=py end end
		for _,entry in layout.Glyphs do local offset=entry.X/layout.Scale;for _,part in glyphPath(entry.Glyph)do for index,position in part.Points do include(position[1]+offset,position[2]);local curve=part.Curves[index];if curve then include(curve.Control1[1]+offset,curve.Control1[2]);if curve.Control2 then include(curve.Control2[1]+offset,curve.Control2[2])end end end end end
		if minX==math.huge then return layout.OriginX,layout.Baseline,layout.OriginX,layout.Baseline end;return minX,minY,maxX,maxY
	end
	local function appendTextPath(layout: any)
		for _,entry in layout.Glyphs do
			local offset=entry.X/layout.Scale
			local function map(position)return layout.OriginX+(offset+position[1])*layout.Scale*layout.Stretch,layout.Baseline-position[2]*layout.Scale end
			for _,part in glyphPath(entry.Glyph)do
				local first=part.Points[1];if not first then continue end;self:MoveTo(map(first))
				for index=2,#part.Points do local destination=part.Points[index];local curve=part.Curves[index]
					if curve and curve.Kind=="Q"then local cx,cy=map(curve.Control1);local dx,dy=map(destination);self:QuadraticCurveTo(cx,cy,dx,dy)
					elseif curve and curve.Kind=="C"then local c1x,c1y=map(curve.Control1);local c2x,c2y=map(curve.Control2);local dx,dy=map(destination);self:BezierCurveTo(c1x,c1y,c2x,c2y,dx,dy)
					else self:LineTo(map(destination))end
				end
				if part.Closed then self:ClosePath()end
			end
		end
	end
	imageSample=function(source: any,x: number,y: number,smooth: boolean): (Color3,number)
		local sourceWidth,sourceHeight=source.Width,source.Height
		if not smooth then
			local ix,iy=math.floor(x),math.floor(y);if ix<0 or iy<0 or ix>=sourceWidth or iy>=sourceHeight then return Color3.new(),0 end
			local offset=(iy*sourceWidth+ix)*4;return Color3.fromRGB(buffer.readu8(source.Pixels,offset),buffer.readu8(source.Pixels,offset+1),buffer.readu8(source.Pixels,offset+2)),buffer.readu8(source.Pixels,offset+3)/255
		end
		local ix,iy=math.floor(x-.5),math.floor(y-.5);local fx,fy=x-.5-ix,y-.5-iy;local alpha,red,green,blue=0,0,0,0
		for oy=0,1 do for ox=0,1 do local px,py=ix+ox,iy+oy;if px>=0 and py>=0 and px<sourceWidth and py<sourceHeight then local weight=(if ox==0 then 1-fx else fx)*(if oy==0 then 1-fy else fy);local offset=(py*sourceWidth+px)*4;local a=buffer.readu8(source.Pixels,offset+3)/255*weight;alpha+=a;red+=buffer.readu8(source.Pixels,offset)/255*a;green+=buffer.readu8(source.Pixels,offset+1)/255*a;blue+=buffer.readu8(source.Pixels,offset+2)/255*a end end end
		if alpha<=0 then return Color3.new(),0 end;return Color3.new(red/alpha,green/alpha,blue/alpha),alpha
	end
	function self:Set(key,value)
		if key=="fillStyle" or key=="strokeStyle" then sampler(value);self.State[if key=="fillStyle" then "FillStyle" else "StrokeStyle"]=value
		elseif key=="lineWidth" then local n=finite(value);if n>0 then self.State.LineWidth=math.min(n,2048) end
		elseif key=="globalAlpha" then local n=finite(value);if n>=0 and n<=1 then self.State.GlobalAlpha=n end
		elseif key=="globalCompositeOperation" then if type(value)=="string"and COMPOSITE_OPERATIONS[value]then self.State.CompositeOperation=value end
		elseif key=="shadowColor"then paint(value);self.State.ShadowColor=value
		elseif key=="shadowBlur"then local n=finite(value);if n>=0 then self.State.ShadowBlur=math.min(n,128)end
		elseif key=="shadowOffsetX"then self.State.ShadowOffsetX=finite(value)
		elseif key=="shadowOffsetY"then self.State.ShadowOffsetY=finite(value)
		elseif key=="font"then local face,size=parseFont(value);if face and size then self.State.Font,self.State.FontFace,self.State.FontSize=value,face,size end
		elseif key=="textAlign"then if value=="left"or value=="right"or value=="center"or value=="start"or value=="end"then self.State.TextAlign=value end
		elseif key=="textBaseline"then if value=="top"or value=="hanging"or value=="middle"or value=="alphabetic"or value=="ideographic"or value=="bottom"then self.State.TextBaseline=value end
		elseif key=="direction"then if value=="ltr"or value=="rtl"or value=="inherit"then self.State.Direction=if value=="inherit"then"ltr"else value end
		elseif key=="imageSmoothingEnabled"then if type(value)=="boolean"then self.State.ImageSmoothingEnabled=value end
		elseif key=="imageSmoothingQuality"then if value=="low"or value=="medium"or value=="high"then self.State.ImageSmoothingQuality=value end
		else error("Unsupported writable Canvas 2D property: "..key) end
	end
	function self:Get(key)
		if key=="fillStyle" then return self.State.FillStyle elseif key=="strokeStyle" then return self.State.StrokeStyle elseif key=="lineWidth" then return self.State.LineWidth elseif key=="globalAlpha" then return self.State.GlobalAlpha elseif key=="globalCompositeOperation"then return self.State.CompositeOperation elseif key=="shadowColor"then return self.State.ShadowColor elseif key=="shadowBlur"then return self.State.ShadowBlur elseif key=="shadowOffsetX"then return self.State.ShadowOffsetX elseif key=="shadowOffsetY"then return self.State.ShadowOffsetY elseif key=="font"then return self.State.Font elseif key=="textAlign"then return self.State.TextAlign elseif key=="textBaseline"then return self.State.TextBaseline elseif key=="direction"then return self.State.Direction elseif key=="imageSmoothingEnabled"then return self.State.ImageSmoothingEnabled elseif key=="imageSmoothingQuality"then return self.State.ImageSmoothingQuality end
		return nil
	end
	function self:FillRect(x,y,w,h)
		local style=self.State.FillStyle
		if type(style)=="string"and identityTransform()and#self.State.Clip==0 and self.State.GlobalAlpha==1 and self.State.CompositeOperation=="source-over"then
			local color,alpha=paint(style);local _,shadowAlpha=paint(self.State.ShadowColor)
			if alpha==1 and shadowAlpha==0 then local x1,y1,x2,y2=pixelBounds(x,y,w,h);if not x1 then return end;local packed=math.round(color.R*255)+math.round(color.G*255)*256+math.round(color.B*255)*65536+4278190080;for py=y1,y2 do if checkpoint then checkpoint()end;for px=x1,x2 do buffer.writeu32(self.Pixels,(py*width+px)*4,packed)end end;self:MarkDirty(x1,y1,x2,y2);return end
		end
		local sample=sampler(style);beginDraw();scanPolygon(quadrilateral(x,y,w,h),function(px,py)local c,a=sample(px,py);blend(px,py,c,a)end);endDraw()
	end
	function self:ClearRect(x,y,w,h)
		if identityTransform()and#self.State.Clip==0 then local x1,y1,x2,y2=pixelBounds(x,y,w,h);if not x1 then return end;local bytes=(x2-x1+1)*4;for py=y1,y2 do if checkpoint then checkpoint()end;buffer.fill(self.Pixels,(py*width+x1)*4,0,bytes)end;self:MarkDirty(x1,y1,x2,y2);return end
		scanPolygon(quadrilateral(x,y,w,h),function(px,py)if insideClip(px,py)then buffer.writeu32(self.Pixels,(py*width+px)*4,0);if not self.DirtyFull then self.Dirty,self.DirtyFull,self.DirtyBounds=true,true,nil end end end)
	end
	function self:StrokeRect(x,y,w,h) local sample=sampler(self.State.StrokeStyle);local p=quadrilateral(x,y,w,h);beginDraw();for i=1,4 do line(p[i],p[if i==4 then 1 else i+1],sample)end;endDraw() end
	function self:DrawImage(value,a,b,c,d,e,f,g,h)
		local source=if type(value)=="table"then value.CanvasSource or value.CanvasImageSource or value else nil
		assert(source and type(source.Width)=="number"and type(source.Height)=="number"and typeof(source.Pixels)=="buffer","drawImage source is not a loaded image or canvas")
		local sourceWidth,sourceHeight=source.Width,source.Height;assert(sourceWidth>=0 and sourceHeight>=0 and buffer.len(source.Pixels)>=sourceWidth*sourceHeight*4,"drawImage source pixels are incomplete")
		local sx,sy,sw,sh,dx,dy,dw,dh
		if e~=nil then sx,sy,sw,sh,dx,dy,dw,dh=finite(a),finite(b),finite(c),finite(d),finite(e),finite(f),finite(g),finite(h)
		elseif c~=nil then sx,sy,sw,sh,dx,dy,dw,dh=0,0,sourceWidth,sourceHeight,finite(a),finite(b),finite(c),finite(d)
		else sx,sy,sw,sh,dx,dy,dw,dh=0,0,sourceWidth,sourceHeight,finite(a),finite(b),sourceWidth,sourceHeight end
		if sw<0 then sx+=sw;sw=-sw end;if sh<0 then sy+=sh;sh=-sh end;if dw<0 then dx+=dw;dw=-dw end;if dh<0 then dy+=dh;dh=-dh end
		if sw==0 or sh==0 or dw==0 or dh==0 or sourceWidth==0 or sourceHeight==0 then return end
		if source.Pixels==self.Pixels then local snapshot=buffer.create(buffer.len(source.Pixels));buffer.copy(snapshot,0,source.Pixels);source={Width=sourceWidth,Height=sourceHeight,Pixels=snapshot}end
		local matrix=inverse(self.State.Transform);if not matrix then return end;local polygon=quadrilateral(dx,dy,dw,dh);local smooth=self.State.ImageSmoothingEnabled
		beginDraw();scanPolygon(polygon,function(px,py)
			local x,y=px+.5,py+.5;local ux=matrix[1]*x+matrix[3]*y+matrix[5];local uy=matrix[2]*x+matrix[4]*y+matrix[6];local u,v=(ux-dx)/dw,(uy-dy)/dh
			if u<0 or v<0 or u>=1 or v>=1 then return end;local imageX,imageY=sx+u*sw,sy+v*sh;if imageX<0 or imageY<0 or imageX>=sourceWidth or imageY>=sourceHeight then return end
			if smooth then imageX=math.clamp(imageX,.5,sourceWidth-.5);imageY=math.clamp(imageY,.5,sourceHeight-.5)end
			local color,alpha=imageSample(source,imageX,imageY,smooth);if alpha>0 then blend(px,py,color,alpha)end
		end);endDraw()
	end
	local function pathPoint(x,y)
		assert(self.PathPointCount < MAX_PATH_POINTS,"Canvas path exceeds the 65536 point limit")
		if checkpoint and self.PathPointCount%128==0 then checkpoint()end
		local value=point(x,y);self.PathPointCount+=1;return value
	end
	function self:BeginPath() self.Path,self.Current,self.PathPointCount={},nil,0 end
	function self:MoveTo(x,y) local p={Points={pathPoint(x,y)},Closed=false};table.insert(self.Path,p);self.Current=p end
	local function reopen()
		if self.Current and self.Current.Closed then local p=self.Current.Points[1];self:MoveTo(p.UX,p.UY)end
	end
	function self:LineTo(x,y) reopen();if not self.Current then self:MoveTo(x,y);return end;table.insert(self.Current.Points,pathPoint(x,y)) end
	function self:ClosePath() if self.Current then self.Current.Closed=true end end
	function self:Rect(x,y,w,h) self:MoveTo(x,y);self:LineTo(x+w,y);self:LineTo(x+w,y+h);self:LineTo(x,y+h);self:ClosePath() end
	local function curveSteps(length)return math.max(8,math.min(256,math.ceil(length/4)))end
	function self:QuadraticCurveTo(cpx,cpy,x,y)
		reopen()
		if not self.Current then self:MoveTo(cpx,cpy)end;local p0=self.Current.Points[#self.Current.Points];cpx,cpy,x,y=finite(cpx),finite(cpy),finite(x),finite(y)
		local steps=curveSteps(math.sqrt((p0.UX-cpx)^2+(p0.UY-cpy)^2)+math.sqrt((x-cpx)^2+(y-cpy)^2));for i=1,steps do local t=i/steps;local u=1-t;self:LineTo(u*u*p0.UX+2*u*t*cpx+t*t*x,u*u*p0.UY+2*u*t*cpy+t*t*y)end
	end
	function self:BezierCurveTo(cp1x,cp1y,cp2x,cp2y,x,y)
		reopen()
		if not self.Current then self:MoveTo(cp1x,cp1y)end;local p0=self.Current.Points[#self.Current.Points];cp1x,cp1y,cp2x,cp2y,x,y=finite(cp1x),finite(cp1y),finite(cp2x),finite(cp2y),finite(x),finite(y)
		local length=math.sqrt((p0.UX-cp1x)^2+(p0.UY-cp1y)^2)+math.sqrt((cp1x-cp2x)^2+(cp1y-cp2y)^2)+math.sqrt((cp2x-x)^2+(cp2y-y)^2);local steps=curveSteps(length)
		for i=1,steps do local t=i/steps;local u=1-t;self:LineTo(u^3*p0.UX+3*u*u*t*cp1x+3*u*t*t*cp2x+t^3*x,u^3*p0.UY+3*u*u*t*cp1y+3*u*t*t*cp2y+t^3*y)end
	end
	local function appendEllipse(cx,cy,rx,ry,rotation,startAngle,endAngle,counterclockwise)
		cx,cy,rx,ry,rotation,startAngle,endAngle=finite(cx),finite(cy),finite(rx),finite(ry),finite(rotation),finite(startAngle),finite(endAngle);assert(rx>=0 and ry>=0,"Canvas ellipse radii must be non-negative")
		local tau=math.pi*2;local sweep=endAngle-startAngle
		-- Full turns apply only in the requested direction. Modulo avoids an
		-- unbounded normalization loop (large finite angles can round 2pi away).
		if counterclockwise==true and sweep<=-tau then sweep=-tau
		elseif counterclockwise~=true and sweep>=tau then sweep=tau
		else
			if math.abs(sweep)==math.huge then sweep=(endAngle%tau)-(startAngle%tau)end
			sweep=if counterclockwise==true then -((-sweep)%tau)else sweep%tau
		end
		startAngle%=tau
		local count=math.max(4,math.ceil(math.abs(sweep)*math.max(4,rx,ry)/4));local cosr,sinr=math.cos(rotation),math.sin(rotation)
		assert(count+1<=MAX_PATH_POINTS-self.PathPointCount,"Canvas ellipse exceeds the 65536 point limit")
		for i=0,count do local angle=startAngle+sweep*i/count;local ex,ey=math.cos(angle)*rx,math.sin(angle)*ry;local x,y=cx+ex*cosr-ey*sinr,cy+ex*sinr+ey*cosr;if i==0 and not self.Current then self:MoveTo(x,y)else self:LineTo(x,y)end end
	end
	function self:Arc(cx,cy,radius,startAngle,endAngle,counterclockwise)
		appendEllipse(cx,cy,radius,radius,0,startAngle,endAngle,counterclockwise)
	end
	function self:Ellipse(cx,cy,rx,ry,rotation,startAngle,endAngle,counterclockwise)appendEllipse(cx,cy,rx,ry,rotation,startAngle,endAngle,counterclockwise)end
	function self:ArcTo(x1,y1,x2,y2,radius)
		reopen()
		x1,y1,x2,y2,radius=finite(x1),finite(y1),finite(x2),finite(y2),finite(radius);assert(radius>=0,"Canvas arcTo radius must be non-negative");if not self.Current then self:MoveTo(x1,y1);return end
		local p0=self.Current.Points[#self.Current.Points];local ax,ay=p0.UX-x1,p0.UY-y1;local bx,by=x2-x1,y2-y1;local al,bl=math.sqrt(ax*ax+ay*ay),math.sqrt(bx*bx+by*by);if al==0 or bl==0 or radius==0 then self:LineTo(x1,y1);return end;ax,ay,bx,by=ax/al,ay/al,bx/bl,by/bl
		local dot=math.clamp(ax*bx+ay*by,-1,1);local angle=math.acos(dot);local cross=ax*by-ay*bx;if math.abs(cross)<1e-8 or angle==0 or angle==math.pi then self:LineTo(x1,y1);return end
		local distance=radius/math.tan(angle/2);local t1x,t1y=x1+ax*distance,y1+ay*distance;local t2x,t2y=x1+bx*distance,y1+by*distance;local bisx,bisy=ax+bx,ay+by;local bisl=math.sqrt(bisx*bisx+bisy*bisy);bisx,bisy=bisx/bisl,bisy/bisl;local centerDistance=radius/math.sin(angle/2);local cx,cy=x1+bisx*centerDistance,y1+bisy*centerDistance
		self:LineTo(t1x,t1y);appendEllipse(cx,cy,radius,radius,0,math.atan2(t1y-cy,t1x-cx),math.atan2(t2y-cy,t2x-cx),cross>0)
	end
	function self:Stroke() local sample=sampler(self.State.StrokeStyle);beginDraw();for _,p in self.Path do for i=2,#p.Points do line(p.Points[i-1],p.Points[i],sample)end;if p.Closed and #p.Points>1 then line(p.Points[#p.Points],p.Points[1],sample)end end;endDraw() end
	function self:Fill(rule)
		local sample=sampler(self.State.FillStyle);beginDraw();scanRegion(pathRegion(rule),function(x,y)local c,a=sample(x,y);blend(x,y,c,a)end);endDraw()
	end
	function self:IsPointInPath(x,y,rule)
		local region=pathRegion(rule)
		for _,points in region.Polygons do for i,a in points do
			local b=points[if i==#points then 1 else i+1];local dx,dy=b.X-a.X,b.Y-a.Y
			local cross=(x-a.X)*dy-(y-a.Y)*dx
			if math.abs(cross)<=1e-9 and x>=math.min(a.X,b.X)and x<=math.max(a.X,b.X)and y>=math.min(a.Y,b.Y)and y<=math.max(a.Y,b.Y)then return true end
		end end
		return contains(region,x,y)
	end
	local function drawText(value,x,y,maxWidth,stroke)
		local layout=textLayout(value,x,y,maxWidth);local oldPath,oldCurrent,oldCount=self.Path,self.Current,self.PathPointCount
		local ok,message=pcall(function()self:BeginPath();appendTextPath(layout);if stroke then self:Stroke()else self:Fill()end end)
		self.Path,self.Current,self.PathPointCount=oldPath,oldCurrent,oldCount
		if not ok then error(message,0)end
	end
	function self:FillText(value,x,y,maxWidth)drawText(value,x,y,maxWidth,false)end
	function self:StrokeText(value,x,y,maxWidth)drawText(value,x,y,maxWidth,true)end
	function self:MeasureText(value)
		local layout=textLayout(value,0,0,nil);local minX,minY,maxX,maxY=textBounds(layout)
		local metrics={width=layout.Width,actualBoundingBoxLeft=-minX,actualBoundingBoxRight=maxX,actualBoundingBoxAscent=-minY,actualBoundingBoxDescent=maxY,fontBoundingBoxAscent=layout.Ascent,fontBoundingBoxDescent=layout.Descent,emHeightAscent=layout.Ascent,emHeightDescent=layout.Descent}
		metrics.Get=function(first,second)local key=if second~=nil then second else first;return metrics[key]end;return metrics
	end
	function self:Clip(rule)table.insert(self.State.Clip,pathRegion(rule))end
	function self:CreateLinearGradient(x0,y0,x1,y1)return gradient("linear",{finite(x0),finite(y0),finite(x1),finite(y1)})end
	function self:CreateRadialGradient(x0,y0,r0,x1,y1,r1)
		x0,y0,r0,x1,y1,r1=finite(x0),finite(y0),finite(r0),finite(x1),finite(y1),finite(r1);assert(r0>=0 and r1>=0,"Canvas radial-gradient radii must be non-negative")
		return gradient("radial",{x0,y0,r0,x1,y1,r1})
	end
	function self:CreatePattern(value,repetition)
		local source=imageSource(value);assert(source,"createPattern source is not a loaded image or canvas");repetition=if repetition==nil or repetition==""then"repeat"else repetition;assert(repetition=="repeat"or repetition=="repeat-x"or repetition=="repeat-y"or repetition=="no-repeat","Unsupported Canvas pattern repetition: "..tostring(repetition))
		local result={Kind="CanvasPattern",Source=source,Repetition=repetition,Inverse=inverse(self.State.Transform),PatternInverse={1,0,0,1,0,0}}
		result.Get=function(key)
			if key=="setTransform"then return function(args)
				local value=args[1];assert(type(value)=="table","CanvasPattern.setTransform expects a matrix object")
				local function component(name,default)
					local current=if self.ReadProperty then self.ReadProperty(value,name)elseif value.Get then value.Get(name)elseif value.Values then value.Values[name]else value[name]
					return if type(current)=="number"then finite(current)else default
				end
				result.PatternInverse=inverse({component("a",1),component("b",0),component("c",0),component("d",1),component("e",0),component("f",0)})
			end end
			return nil
		end
		return result
	end
	function self:CreateImageData(value,height)
		if type(value)=="table"and value.Kind=="ImageData"then return makeImageData(value.Width,value.Height)end
		return makeImageData(math.abs(truncate(value)),math.abs(truncate(height)))
	end
	function self:GetImageData(sx,sy,sw,sh)
		sx,sy,sw,sh=truncate(sx),truncate(sy),truncate(sw),truncate(sh)
		assert(sw~=0 and sh~=0,"getImageData width and height must be non-zero")
		if sw<0 then sx+=sw;sw=-sw end;if sh<0 then sy+=sh;sh=-sh end
		local result=makeImageData(sw,sh)
		local left,top=math.max(0,sx),math.max(0,sy);local right,bottom=math.min(width,sx+sw),math.min(height,sy+sh)
		if right>left and bottom>top then
			local count=right-left
			for sourceY=top,bottom-1 do if checkpoint then checkpoint()end;buffer.copy(result.Pixels,((sourceY-sy)*sw+left-sx)*4,self.Pixels,(sourceY*width+left)*4,count*4)end
		end
		return result
	end
	function self:PutImageData(value,dx,dy,dirtyX,dirtyY,dirtyWidth,dirtyHeight)
		assert(type(value)=="table"and value.Kind=="ImageData"and typeof(value.Pixels)=="buffer","putImageData expects ImageData")
		dx,dy=truncate(dx),truncate(dy)
		local sourceWidth,sourceHeight=value.Width,value.Height
		local x,y,w,h
		if dirtyX==nil then x,y,w,h=0,0,sourceWidth,sourceHeight else x,y,w,h=truncate(dirtyX),truncate(dirtyY),truncate(dirtyWidth),truncate(dirtyHeight)end
		if w<0 then x+=w;w=-w end;if h<0 then y+=h;h=-h end
		local sourceLeft,sourceTop=math.max(0,x,-dx),math.max(0,y,-dy)
		local sourceRight=math.min(sourceWidth,x+w,width-dx);local sourceBottom=math.min(sourceHeight,y+h,height-dy)
		if sourceRight<=sourceLeft or sourceBottom<=sourceTop then return end
		local count=sourceRight-sourceLeft
		for sourceY=sourceTop,sourceBottom-1 do if checkpoint then checkpoint()end;buffer.copy(self.Pixels,((dy+sourceY)*width+dx+sourceLeft)*4,value.Pixels,(sourceY*sourceWidth+sourceLeft)*4,count*4)end
		self:MarkDirty(dx+sourceLeft,dy+sourceTop,dx+sourceRight-1,dy+sourceBottom-1)
	end
	function self:EncodePNG()return if width==0 or height==0 then nil else CanvasPNG.encode(width,height,self.Pixels,checkpoint)end
	function self:ToDataURL()return CanvasPNG.dataURL(width,height,self.Pixels,checkpoint)end
	function self:Translate(x,y)multiply(1,0,0,1,x,y)end
	function self:Scale(x,y)y=if y==nil then x else y;multiply(x,0,0,y,0,0)end
	function self:Rotate(angle)angle=finite(angle);local c,s=math.cos(angle),math.sin(angle);multiply(c,s,-s,c,0,0)end
	function self:Transform(a,b,c,d,e,f)multiply(a,b,c,d,e,f)end
	function self:SetTransform(a,b,c,d,e,f)self.State.Transform={finite(a),finite(b),finite(c),finite(d),finite(e),finite(f)}end
	function self:ResetTransform()self.State.Transform={1,0,0,1,0,0}end
	function self:Save() assert(#self.Stack<64,"Canvas state stack limit exceeded");table.insert(self.Stack,cloneState(self.State)) end
	function self:Restore() if #self.Stack>0 then self.State=table.remove(self.Stack) end end
	function self:MarkDirty(x0,y0,x1,y1)
		x0,y0,x1,y1=math.max(0,math.floor(x0)),math.max(0,math.floor(y0)),math.min(width-1,math.floor(x1)),math.min(height-1,math.floor(y1));if x1<x0 or y1<y0 then return end
		self.Dirty=true;if self.DirtyFull then return end;if x0==0 and y0==0 and x1==width-1 and y1==height-1 then self.DirtyFull,self.DirtyBounds=true,nil;return end;local bounds=self.DirtyBounds;if not bounds then self.DirtyBounds={x0,y0,x1,y1};return end
		if x0<bounds[1]then bounds[1]=x0 end;if y0<bounds[2]then bounds[2]=y0 end;if x1>bounds[3]then bounds[3]=x1 end;if y1>bounds[4]then bounds[4]=y1 end
		if bounds[1]==0 and bounds[2]==0 and bounds[3]==width-1 and bounds[4]==height-1 then self.DirtyFull,self.DirtyBounds=true,nil end
	end
	function self:TakeDirtyRegion()
		local dirty,bounds=self.Dirty,self.DirtyBounds;self.Dirty,self.DirtyFull,self.DirtyBounds=false,false,nil;return dirty,bounds
	end
	function self:TakeDirty() local dirty=self.Dirty;self.Dirty,self.DirtyFull,self.DirtyBounds=false,false,nil;return dirty end
	return self
end
return CanvasSurface
