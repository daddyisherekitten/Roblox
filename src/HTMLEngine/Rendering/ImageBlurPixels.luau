--!strict
--!optimize 2
--!native
-- Rasterize the fitted image at CSS size, with transparent room for blur/shadows.
-- Filtering uses premultiplied float RGBA to avoid dark/colored alpha fringes.
local ImageFit=require(script.Parent.Parent.Layout.ImageFit)
local Geometry=require(script.Parent.Parent.Layout.BorderGeometry)
local Colors=require(script.Parent.ImageFilterPixels)
local Blur={}
function Blur.plan(item: any, sourceSize: any): any?
	local width,height=item.ContentWidth,item.ContentHeight
	if not width or not height or width<=0 or height<=0 or item.TextFallback then return nil end
	local probe=table.clone(item)
	probe.IntrinsicWidth,probe.IntrinsicHeight=sourceSize.X,sourceSize.Y
	local x,y,w,h=ImageFit.rectangle(probe)
	local pad=item.Style.Filter.Outset
	local totalW,totalH=width+2*pad,height+2*pad
	local scale=math.min(1,512/math.max(totalW,totalH))
	local iw,ih=math.max(1,math.ceil(totalW*scale)),math.max(1,math.ceil(totalH*scale))
	local t,r,b,l=Geometry.sizes(item.Style)
	local p=item.Style.Padding
	local radius=math.max(0,(item.Style.BorderRadius or 0)-math.max(t,r,b,l)-math.max(p[1],p[2],p[3],p[4]))
	radius=math.min(radius,width/2,height/2)
	return {Width=iw,Height=ih,ScaleX=iw/totalW,ScaleY=ih/totalH,Pad=pad,
		CSSWidth=width,CSSHeight=height,X=x,Y=y,FitWidth=w,FitHeight=h,Radius=radius,
		Key=table.concat({item.Style.Filter.Key,width,height,x,y,w,h,radius},"|")}
end
local function radii(sigma: number): any
	local lo=math.max(1,math.floor(math.sqrt(4*sigma*sigma+1)))
	if lo%2==0 then lo-=1 end
	local count=math.clamp(math.round((12*sigma*sigma-3*lo*lo-12*lo-9)/(-4*lo-4)),0,3)
	return {(lo-1+(if count>=1 then 0 else 2))/2,(lo-1+(if count>=2 then 0 else 2))/2,(lo-1+(if count>=3 then 0 else 2))/2}
end
local function pass(src: buffer,dst: buffer,w: number,h: number,r: number,vertical: boolean,check: any,edge: number?): boolean
	local length,lines=if vertical then h else w,if vertical then w else h
	local stride,step=if vertical then w else 1,if vertical then 1 else w
	for line=0,lines-1 do
		if check and not check() then return false end
		local base=line*step
		for channel=0,3 do
			local sum=0
			if not edge then for i=0,math.min(r,length-1) do sum+=buffer.readf32(src,(base+i*stride)*16+channel*4) end end
			for i=0,length-1 do
				local offset=(base+i*stride)*16+channel*4
				if edge then
					local value=buffer.readf32(src,offset)*(1-2*edge)
					if i>0 then value+=buffer.readf32(src,offset-stride*16)*edge end
					if i+1<length then value+=buffer.readf32(src,offset+stride*16)*edge end
					buffer.writef32(dst,offset,value)
				else
					buffer.writef32(dst,offset,sum/(2*r+1))
					if i-r>=0 then sum-=buffer.readf32(src,(base+(i-r)*stride)*16+channel*4) end
					if i+r+1<length then sum+=buffer.readf32(src,(base+(i+r+1)*stride)*16+channel*4) end
				end
			end
		end
	end
	return true
end
local function gaussian(data: buffer,temp: buffer,plan: any,value: number,check: any): (buffer?,buffer)
	if value<=0 then return data,temp end
	for _,vertical in {false,true} do
		local sigma=value*(if vertical then plan.ScaleY else plan.ScaleX)
		local rs=radii(sigma)
		if rs[1]+rs[2]+rs[3]==0 then
			local weight=math.exp(-.5/(sigma*sigma)); weight/=1+2*weight
			if not pass(data,temp,plan.Width,plan.Height,1,vertical,check,weight) then return nil,temp end
			data,temp=temp,data
		else for _,r in rs do if r>0 then
			if not pass(data,temp,plan.Width,plan.Height,r,vertical,check) then return nil,temp end
			data,temp=temp,data
		end end end
	end
	return data,temp
end
local function shadow(data: buffer,temp: buffer,plan: any,step: any,check: any,spare: buffer?): (boolean,buffer,buffer?)
	local w,h=plan.Width,plan.Height
	local layer=spare or buffer.create(w*h*16)
	local dx,dy=step.X*plan.ScaleX,step.Y*plan.ScaleY
	local color=step.Color
	for y=0,h-1 do
		if check and not check() then return false,temp,layer end
		for x=0,w-1 do
			local sx,sy=x-dx,y-dy
			local x0,y0=math.floor(sx),math.floor(sy)
			local fx,fy=sx-x0,sy-y0
			local alpha=0
			for yy=0,1 do for xx=0,1 do
				local ix,iy=x0+xx,y0+yy
				if ix>=0 and iy>=0 and ix<w and iy<h then
					alpha+=buffer.readf32(data,(iy*w+ix)*16+12)*(if xx==0 then 1-fx else fx)*(if yy==0 then 1-fy else fy)
				end
			end end
			alpha=math.clamp(alpha,0,1)*step.Alpha
			local at=(y*w+x)*16
			buffer.writef32(layer,at,color.R*alpha); buffer.writef32(layer,at+4,color.G*alpha)
			buffer.writef32(layer,at+8,color.B*alpha); buffer.writef32(layer,at+12,alpha)
		end
	end
	-- The padded canvas permits translating before blurring. Preserve the current
	-- chain input separately and composite it over the colored alpha silhouette.
	layer,temp=gaussian(layer,temp,plan,step.Value,check)
	if not layer then return false,temp,nil end
	for at=0,w*h*16-16,16 do
		if check and at%32768==0 and not check() then return false,temp,layer end
		local remaining=1-math.clamp(buffer.readf32(data,at+12),0,1)
		for c=0,3 do
			buffer.writef32(data,at+c*4,buffer.readf32(data,at+c*4)+buffer.readf32(layer,at+c*4)*remaining)
		end
	end
	return true,temp,layer
end
function Blur.render(source: buffer,sourceSize: any,filter: any,plan: any,check: any): buffer?
	local w,h=plan.Width,plan.Height
	local data,temp=buffer.create(w*h*16),buffer.create(w*h*16)
	local shadowBuffer: buffer?=nil
	local sw,sh=sourceSize.X,sourceSize.Y
	assert(buffer.len(source)==sw*sh*4,"Invalid source pixels")
	for y=0,h-1 do
		if check and not check() then return nil end
		for x=0,w-1 do
			local cx,cy=(x+.5)/plan.ScaleX-plan.Pad,(y+.5)/plan.ScaleY-plan.Pad
			if cx<0 or cy<0 or cx>=plan.CSSWidth or cy>=plan.CSSHeight or cx<plan.X or cy<plan.Y or cx>=plan.X+plan.FitWidth or cy>=plan.Y+plan.FitHeight then continue end
			local radius=plan.Radius
			if radius>0 then
				local dx,dy=cx-math.clamp(cx,radius,plan.CSSWidth-radius),cy-math.clamp(cy,radius,plan.CSSHeight-radius)
				if dx*dx+dy*dy>radius*radius then continue end
			end
			local sx,sy=math.clamp((cx-plan.X)/plan.FitWidth*sw-.5,0,sw-1),math.clamp((cy-plan.Y)/plan.FitHeight*sh-.5,0,sh-1)
			local x0,y0=math.floor(sx),math.floor(sy)
			local fx,fy=sx-x0,sy-y0
			local out=(y*w+x)*16
			for yy=0,1 do for xx=0,1 do
				local at=(math.min(sh-1,y0+yy)*sw+math.min(sw-1,x0+xx))*4
				local weight=(if xx==0 then 1-fx else fx)*(if yy==0 then 1-fy else fy)
				local alpha=buffer.readu8(source,at+3)/255*weight
				for c=0,2 do buffer.writef32(data,out+c*4,buffer.readf32(data,out+c*4)+buffer.readu8(source,at+c)/255*alpha) end
				buffer.writef32(data,out+12,buffer.readf32(data,out+12)+alpha)
			end end
		end
	end
	for _,step in filter.Steps do
		if step.Name=="blur" and step.Value>0 then
			data,temp=gaussian(data,temp,plan,step.Value,check)
			if not data then return nil end
		elseif step.Name=="drop-shadow" then
			local ok
			ok,temp,shadowBuffer=shadow(data,temp,plan,step,check,shadowBuffer)
			if not ok then return nil end
		else
			local m=Colors.matrix(step)
			for at=0,w*h*16-16,16 do
				if check and at%32768==0 and not check() then return nil end
				local a=math.clamp(buffer.readf32(data,at+12),0,1)
				if a<=1e-8 then continue end
				local r,g,b=buffer.readf32(data,at)/a,buffer.readf32(data,at+4)/a,buffer.readf32(data,at+8)/a
				a*=m[11]
				buffer.writef32(data,at,math.clamp(m[1]*r+m[2]*g+m[3]*b+m[10],0,1)*a)
				buffer.writef32(data,at+4,math.clamp(m[4]*r+m[5]*g+m[6]*b+m[10],0,1)*a)
				buffer.writef32(data,at+8,math.clamp(m[7]*r+m[8]*g+m[9]*b+m[10],0,1)*a)
				buffer.writef32(data,at+12,a)
			end
		end
	end
	local output=buffer.create(w*h*4)
	for i=0,w*h-1 do
		if check and i%2048==0 and not check() then return nil end
		local a=math.clamp(buffer.readf32(data,i*16+12),0,1)
		for c=0,2 do buffer.writeu8(output,i*4+c,if a>1e-8 then math.round(math.clamp(buffer.readf32(data,i*16+c*4)/a,0,1)*255) else 0) end
		buffer.writeu8(output,i*4+3,math.round(a*255))
	end
	return output
end
return Blur
