--!strict
--!optimize 2
local WorkContext=require(script.Parent.Parent.WorkContext)
local Geometry=require(script.Parent.Geometry)
local Curves=require(script.Parent.Curves)
local Dashes=require(script.Parent.Dashes)
local Matrix=require(script.Parent.Matrix)
local Compositing=require(script.Parent.Compositing)
local Mask=require(script.Parent.Mask)
local Filter=require(script.Parent.Filter)
local Raster={}
Raster.createWork=Compositing.createWork
Raster.releaseWork=Compositing.releaseWork
local function paint(bytes: buffer,width: number,height: number,contours: any,t: any,clip: any?,scale: number,color: any,check: any,rule: string?,hint: string?,work: any?,dirty: any?): boolean
	if color.URL then color=color.Fallback end
	if not color or color.Context then return true end
	if (color[4] or 1)<=0 then return true end
	local edges={};local top,bottom=math.huge,-math.huge
	for _,points in contours do
		if #points<3 then continue end
		for i,a in points do
			local b=points[i%#points+1]
			local x,y=Matrix.point(t,a[1],a[2]);x*=scale;y*=scale
			local xx,yy=Matrix.point(t,b[1],b[2]);xx*=scale;yy*=scale
			assert(math.abs(x)<1e12 and math.abs(y)<1e12 and math.abs(xx)<1e12 and math.abs(yy)<1e12,"SVG raster coordinate budget exceeded")
			top,bottom=math.min(top,y),math.max(bottom,y)
			if y~=yy then table.insert(edges,{X=x,Y=y,DX=xx-x,DY=yy-y,Low=math.min(y,yy),High=math.max(y,yy),Sign=if yy>y then 1 else -1}) end
		end
	end
	local left,right=0,width
 if dirty then left=dirty.X;right=dirty.X+dirty.Width;top=math.max(top,dirty.Y);bottom=math.min(bottom,dirty.Y+dirty.Height) end
	if clip then
		left,right=math.max(left,clip.X*scale),math.min(right,(clip.X+clip.Width)*scale)
		top,bottom=math.max(top,clip.Y*scale),math.min(bottom,(clip.Y+clip.Height)*scale)
	end
	top,bottom=math.max(0,top),math.min(height,bottom)
	if #edges==0 or bottom<=top or right<=left then return true end
 if color.Prepare then color=color.Prepare(color,scale,check,work,Raster.render);if not color then return false end end
 local opacity=color[4] or 1
 if opacity<=0 then return true end
 local solid=if not color.Sample and opacity==1 then bit32.bor(math.round(color[1]),bit32.lshift(math.round(color[2]),8),bit32.lshift(math.round(color[3]),16),0xff000000) else nil
	for py=math.floor(top),math.ceil(bottom)-1 do
		if check and not check() then return false end
		local coverage,interiors={},{}
		local firstPixel,lastPixel=width,-1
		local low,high=math.max(py,top),math.min(py+1,bottom)
		local samples=if hint=='crispEdges' then 1 elseif hint=='optimizeSpeed' then 4 else 16
		local weight=(high-low)/samples
		for sample=0,samples-1 do
			local y=if hint=='crispEdges' then py+.5 else low+(sample+.5)*weight
			if y<top or y>=bottom then continue end
			local sampleLeft,sampleRight=left,right
			for _,polygon in (clip and clip.Polygons) or {} do
				local lo,hi=math.huge,-math.huge
				for i,a in polygon do
					local b=polygon[i%#polygon+1];local ay,by=a[2]*scale,b[2]*scale
					if y>=math.min(ay,by) and y<math.max(ay,by) then
						local x=(a[1]+(y/scale-a[2])/(b[2]-a[2])*(b[1]-a[1]))*scale
						lo=math.min(lo,x);hi=math.max(hi,x)
					end
				end
				sampleLeft=math.max(sampleLeft,lo);sampleRight=math.min(sampleRight,hi)
			end
			if sampleRight<=sampleLeft then continue end
			local hits={}
			for _,edge in edges do
				if y>=edge.Low and y<edge.High then table.insert(hits,{edge.X+(y-edge.Y)/edge.DY*edge.DX,edge.Sign}) end
			end
			table.sort(hits,function(a,b) return a[1]<b[1] end)
			local winding,start=0,0
			for _,hit in hits do
				if (if rule=='evenodd' then winding%2 else winding)==0 then start=hit[1] end
				winding+=hit[2]
				if (if rule=='evenodd' then winding%2 else winding)==0 then
					local x1,x2=math.max(sampleLeft,start),math.min(sampleRight,hit[1])
					if x2>x1 then
						local first,last=math.floor(x1),math.ceil(x2)-1
						firstPixel,lastPixel=math.min(firstPixel,first),math.max(lastPixel,last)
						-- Accumulate complete interior spans once, rather than visiting every
						-- interior pixel for each of the 16 edge-antialiasing samples.
						if hint=='crispEdges' then
						 for px=first,last do coverage[px]=(coverage[px] or 0)+(if px+.5>=x1 and px+.5<x2 then 1 else 0) end
						elseif first==last then coverage[first]=(coverage[first] or 0)+(x2-x1)*weight
						else
						 coverage[first]=(coverage[first] or 0)+(first+1-x1)*weight
						 coverage[last]=(coverage[last] or 0)+(x2-last)*weight
						 if last>first+1 then
						  interiors[first+1]=(interiors[first+1] or 0)+weight
						  interiors[last]=(interiors[last] or 0)-weight
						 end
						end
					end
				end
			end
		end
		local interior=0
		for px=firstPixel,lastPixel do
			interior+=interiors[px] or 0
			local area=interior+(coverage[px] or 0)
			if area<=0 then continue end
			local pixel=if color.Sample then color.Sample(color,(px+.5)/scale,(py+.5)/scale,1/scale) else color
			local alpha=math.clamp(area,0,1)*(pixel[4] or 1)
			local at=(py*width+px)*4
   if alpha==1 then
    if solid then buffer.writeu32(bytes,at,solid)
    else for c=0,2 do buffer.writeu8(bytes,at+c,math.round(pixel[c+1])) end;buffer.writeu8(bytes,at+3,255) end
    continue
   end
			local old=buffer.readu8(bytes,at+3)/255
			local combined=alpha+old*(1-alpha)
			if combined>0 then
				for c=0,2 do buffer.writeu8(bytes,at+c,math.round((pixel[c+1]*alpha+buffer.readu8(bytes,at+c)*old*(1-alpha))/combined)) end
				buffer.writeu8(bytes,at+3,math.round(combined*255))
			end
		end
	end
	return true
end
function Raster.render(scene: any,_glyphs: any,width: number,check: any,work: any?): (buffer?,number)
	work=work or {Patterns={},PatternBytes=0,PatternDepth=0}
 -- Prepared paints and recursion budgets are render-local. Only exact completed
 -- isolated layers survive in the owner's bounded retained cache.
 if work.Retain and not work.Owner then work={Owner=work,Retain=true,Patterns={},PatternBytes=0,PatternDepth=0} end
	local scale=width/scene.Width;local height=math.round(scene.Height*scale)
	assert(width>=1 and height>=1 and width<=1024 and height<=1024,"SVG raster size budget exceeded")
	local root=(work.RasterDepth or 0)==0;work.RasterDepth=(work.RasterDepth or 0)+1
	local frame,dirty
	if root then frame,dirty=Compositing.dirty(work,scene,width,height,scale) end
	local bytes=buffer.create(width*height*4)
	if frame then
  buffer.copy(bytes,0,frame.Bytes)
  for y=dirty.Y,dirty.Y+dirty.Height-1 do buffer.fill(bytes,(y*width+dirty.X)*4,0,dirty.Width*4) end
 end
	local function clipper(destination: buffer,clipScene: any,descriptor: any?,backdrop: buffer?,region: any?): boolean
  clipScene.Width=clipScene.Width or scene.Width;clipScene.Height=clipScene.Height or scene.Height
  work.ClipDepth=(work.ClipDepth or 0)+1;assert(work.ClipDepth<=12,'SVG clip raster depth exceeded')
  local cached=Compositing.cached(work,'clip',clipScene,width,height,scale)
  local mask
  if cached then
   mask=buffer.create(width*height*4);local region=cached.Region
   for y=0,region.Height-1 do buffer.copy(mask,((region.Y+y)*width+region.X)*4,cached.Bytes,y*region.Width*4,region.Width*4) end
  else
   mask=Raster.render(clipScene,nil,width,check,work)
   if mask then
    local _,completed=Compositing.remember(work,'clip',clipScene,mask,width,scale,check)
    if completed==false then mask=nil end
   end
  end
  work.ClipDepth-=1
  if not mask then return false end
  local x0,y0,x1,y1=0,0,width,height
  if region then x0=region.X;y0=region.Y;x1=x0+region.Width;y1=y0+region.Height end
  for y=y0,y1-1 do
   if check and not check() then return false end
   for x=x0,x1-1 do
    if x%64==0 then WorkContext.checkpoint()end
   local at=(y*width+x)*4
   local amount=if descriptor then Mask.alpha(mask,at,descriptor.Mode,descriptor.Linear) else buffer.readu8(mask,at+3)/255
   if backdrop then
    -- Clipping alone is not an isolation boundary. Interpolate the complete
    -- composited result with its real original backdrop in premultiplied space.
    local a=buffer.readu8(destination,at+3)/255*amount
    local old=buffer.readu8(backdrop,at+3)/255*(1-amount);local alpha=a+old
    if alpha>0 then for c=0,2 do buffer.writeu8(destination,at+c,math.round((buffer.readu8(destination,at+c)*a+buffer.readu8(backdrop,at+c)*old)/alpha)) end end
    if alpha==0 then buffer.writeu32(destination,at,0) else buffer.writeu8(destination,at+3,math.round(alpha*255)) end
   else buffer.writeu8(destination,at+3,math.round(buffer.readu8(destination,at+3)*amount)) end
  end end
  return true
 end
 local drawShape
	drawShape=function(bytes: buffer,shape: any,region: any?): boolean
		if check and not check() then return false end
		local t,g=shape.Transform,shape.Geometry
		if Matrix.determinant(t)==0 then return true end
		local detailScale=scale*Matrix.scale(t)
		local subpaths=if g.Subpaths then Curves.flatten(g.Subpaths,detailScale,check) else {{Points=Geometry.contour(g,detailScale),Closed=g.Closed}}
		if not subpaths then return false end
		local fills,strokes={},{}
		for _,part in subpaths do table.insert(fills,part.Points) end
		local strokeTransform,strokeScale,strokeWidth=t,detailScale,shape.StrokeWidth
		local dashArray,dashOffset=shape.DashArray,shape.DashOffset
		if shape.NonScalingStroke then
			strokeTransform=Matrix.identity();strokeScale=scale;strokeWidth/=scale
			local mapped={}
			for _,part in subpaths do table.insert(mapped,{Points=Matrix.polygon(t,part.Points),Closed=part.Closed}) end
			subpaths=mapped
			local function adjusted(entry: any): any
				return {Value=entry.Value/(if not entry.Percent and g.PathLength~=nil then 1 else scale),Percent=entry.Percent}
			end
			if dashArray then dashArray={};for _,entry in shape.DashArray do table.insert(dashArray,adjusted(entry)) end end
			if dashOffset then dashOffset=adjusted(dashOffset) end
		end
		if shape.Stroke and shape.StrokeWidth>0 then
			subpaths=Dashes.split(subpaths,dashArray,g.PathLength,check,dashOffset,shape.LineCap)
			if not subpaths then return false end
		end
		for _,part in subpaths do
			if shape.Stroke and shape.StrokeWidth>0 then
				for _,contour in Geometry.stroke(part.Points,part.Closed,strokeWidth,{LineCap=shape.LineCap,LineJoin=shape.LineJoin,MiterLimit=shape.MiterLimit,Scale=strokeScale,Direction=part.Direction}) do table.insert(strokes,contour) end
			end
		end
		for _,operation in shape.PaintOrder or {'fill','stroke','markers'} do
			if operation=='fill' and shape.Fill and g.Kind~='line' then
				if not paint(bytes,width,height,fills,t,shape.Clip,scale,shape.Fill,check,shape.FillRule,shape.ShapeRendering,work,region) then return false end
			elseif operation=='markers' and shape.Markers then
				if not Compositing.draw(bytes,shape.Markers,drawShape,width,check,work,clipper,function(b,f) return Filter.apply(b,f,width,scale,check,work) end,scale,region) then return false end
			elseif operation=='stroke' and shape.Stroke and shape.StrokeWidth>0 then
				if not paint(bytes,width,height,strokes,strokeTransform,shape.Clip,scale,shape.Stroke,check,nil,shape.ShapeRendering,work,region) then return false end
			end
		end
		return true
	end
	local completed=Compositing.draw(bytes,scene.RenderTree or scene.Shapes,drawShape,width,check,work,clipper,function(b,f) return Filter.apply(b,f,width,scale,check,work) end,scale,dirty)
	work.RasterDepth-=1
	if not completed then return nil,height end
	if root then Compositing.storeFrame(work,scene,bytes,width,scale) end
	return bytes,height
end
return Raster
