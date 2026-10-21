--!strict
--!optimize 2
--!native
local WorkContext=require(script.Parent.Parent.WorkContext)
local LengthExpression = require(script.Parent.Parent.CSS.LengthExpression)
local Pixels = {}

function Pixels.plan(width: number, height: number): any
	-- ImageLabel filtering keeps large gradients smooth while bounding the initial
	-- synchronous raster work to one small texture per unique state.
	local scale=math.min(1,256/math.max(1,width,height),math.sqrt(65536/math.max(1,width*height)))
	return {Width=math.max(1,math.ceil(width*scale)),Height=math.max(1,math.ceil(height*scale)),Scale=scale}
end

local function stops(gradient: any, length: number, style: any): {any}
	local result: any={}
	for _,source in gradient.Stops do
		local raw=source.Positions[1]
		table.insert(result,{Color=if source.Color=="currentcolor" then style.Color else source.Color,
			Alpha=if source.Color=="currentcolor" then style.ColorAlpha or 1 else source.Alpha or 1,
			Position=if raw then LengthExpression.resolve(raw,length)/math.max(1e-6,length) else nil})
	end
	if result[1].Position==nil then result[1].Position=0 end
	if result[#result].Position==nil then result[#result].Position=1 end
	local previous: number=result[1].Position
	for index=2,#result do
		local current=result[index].Position
		if current~=nil then current=math.max(previous,current);result[index].Position=current;previous=current end
	end
	local index=1
	while index<#result do
		if result[index].Position~=nil and result[index+1].Position==nil then
			local finish=index+1
			while finish<=#result and result[finish].Position==nil do finish+=1 end
			local left,right=result[index].Position,result[finish].Position
			for cursor=index+1,finish-1 do result[cursor].Position=left+(right-left)*(cursor-index)/(finish-index) end
			index=finish
		else index+=1 end
	end
	return result
end

local function sample(entries: {any}, t: number, repeating: boolean): (Color3,number)
	local first,last=entries[1],entries[#entries]
	if repeating then
		local span=last.Position-first.Position
		if span>1e-6 then t=first.Position+(t-first.Position-span*math.floor((t-first.Position)/span)) end
	end
	if t<=first.Position then return first.Color,first.Alpha end
	if t>=last.Position then return last.Color,last.Alpha end
	for index=2,#entries do
		local right=entries[index]
		if t<=right.Position then
			local left=entries[index-1]
			local amount=if right.Position>left.Position then (t-left.Position)/(right.Position-left.Position) else 1
			local a=left.Alpha+(right.Alpha-left.Alpha)*amount
			if a<=1e-6 then return left.Color,0 end
			-- Interpolate premultiplied colors so transparent stops do not create dark fringes.
			local lr,lg,lb=left.Color.R*left.Alpha,left.Color.G*left.Alpha,left.Color.B*left.Alpha
			local rr,rg,rb=right.Color.R*right.Alpha,right.Color.G*right.Alpha,right.Color.B*right.Alpha
			return Color3.new((lr+(rr-lr)*amount)/a,(lg+(rg-lg)*amount)/a,(lb+(rb-lb)*amount)/a),a
		end
	end
	return last.Color,last.Alpha
end

local function axis(anchor: any, size: number): number
	local free=size
	local offset=anchor.Offset and LengthExpression.resolve(anchor.Offset,free) or 0
	if anchor.Anchor==1 then offset=-offset end
	return anchor.Anchor*size+offset
end

local function radialGeometry(gradient: any,width: number,height: number): (number,number,number,number)
	local cx,cy=axis(gradient.Position.X,width),axis(gradient.Position.Y,height)
	local size=gradient.Size
	if type(size)=="table" then
		local rx=math.max(1e-6,LengthExpression.resolve(size[1],width))
		local ry=if gradient.Shape=="circle" then rx else math.max(1e-6,LengthExpression.resolve(size[2] or size[1],height))
		return cx,cy,rx,ry
	end
	local left,right,top,bottom=math.max(0,cx),math.max(0,width-cx),math.max(0,cy),math.max(0,height-cy)
	local nearX,farX=math.min(left,right),math.max(left,right)
	local nearY,farY=math.min(top,bottom),math.max(top,bottom)
	if gradient.Shape=="circle" then
		local radius
		if size=="closest-side" then radius=math.min(nearX,nearY)
		elseif size=="farthest-side" then radius=math.max(farX,farY)
		else
			local distances={math.sqrt(left*left+top*top),math.sqrt(right*right+top*top),math.sqrt(left*left+bottom*bottom),math.sqrt(right*right+bottom*bottom)}
			radius=if size=="closest-corner" then math.min(table.unpack(distances)) else math.max(table.unpack(distances))
		end
		return cx,cy,math.max(1e-6,radius),math.max(1e-6,radius)
	end
	local rx,ry=if size=="closest-side" or size=="closest-corner" then nearX else farX,
		if size=="closest-side" or size=="closest-corner" then nearY else farY
	rx,ry=math.max(1e-6,rx),math.max(1e-6,ry)
	if size=="closest-corner" or size=="farthest-corner" then
		local factors={math.sqrt((left/rx)^2+(top/ry)^2),math.sqrt((right/rx)^2+(top/ry)^2),math.sqrt((left/rx)^2+(bottom/ry)^2),math.sqrt((right/rx)^2+(bottom/ry)^2)}
		local factor=if size=="closest-corner" then math.min(table.unpack(factors)) else math.max(table.unpack(factors))
		rx,ry=rx*factor,ry*factor
	end
	return cx,cy,math.max(1e-6,rx),math.max(1e-6,ry)
end

function Pixels.sampler(width: number,height: number,gradient: any,style: any): any
	local angle=math.rad(gradient.Angle or 180)
	local dx,dy=math.sin(angle),-math.cos(angle)
	local lineLength=math.max(1e-6,math.abs(dx)*width+math.abs(dy)*height)
	local cx,cy,rx,ry
	if gradient.Kind=="radial" then cx,cy,rx,ry=radialGeometry(gradient,width,height);lineLength=math.max(rx,ry) end
	if gradient.Kind=="conic" then
		cx,cy=axis(gradient.Position.X,width),axis(gradient.Position.Y,height)
		lineLength=360
	end
	local entries=stops(gradient,lineLength,style)
	return function(px,py)
		local t
		if gradient.Kind=='linear'then t=.5+(dx*(px-width/2)+dy*(py-height/2))/lineLength
		elseif gradient.Kind=='radial'then t=math.sqrt(((px-cx)/rx)^2+((py-cy)/ry)^2)
		else t=(math.atan2(px-cx,cy-py)/(2*math.pi)-(gradient.Angle or 0)/360)%1 end
		return sample(entries,t,gradient.Repeating)
	end
end
function Pixels.render(width: number,height: number,gradient: any,style: any,plan: any): buffer
	local result=buffer.create(plan.Width*plan.Height*4)
	local at=Pixels.sampler(width,height,gradient,style)
	for y=0,plan.Height-1 do
		local py=(y+.5)/plan.Height*height
		for x=0,plan.Width-1 do
			if x%64==0 then WorkContext.checkpoint()end
			local px=(x+.5)/plan.Width*width
			local color,alpha=at(px,py)
			local offset=(y*plan.Width+x)*4
			buffer.writeu8(result,offset,math.round(color.R*255));buffer.writeu8(result,offset+1,math.round(color.G*255))
			buffer.writeu8(result,offset+2,math.round(color.B*255));buffer.writeu8(result,offset+3,math.round(alpha*255))
		end
	end
	return result
end

function Pixels.renderBlend(width: number,height: number,images: {any},modes: {string},style: any,plan: any): buffer
	local result=buffer.create(plan.Width*plan.Height*4)
	local base=style.Background or Color3.new(0,0,0)
	for pixel=0,plan.Width*plan.Height-1 do
		local offset=pixel*4
		buffer.writeu8(result,offset,math.round(base.R*255))
		buffer.writeu8(result,offset+1,math.round(base.G*255))
		buffer.writeu8(result,offset+2,math.round(base.B*255))
		buffer.writeu8(result,offset+3,255)
	end
	-- CSS lists the topmost background first, so compose from the last image up.
	for index=#images,1,-1 do
		local source=Pixels.render(width,height,images[index],style,plan)
		local mode=modes[(index-1)%#modes+1]
		for pixel=0,plan.Width*plan.Height-1 do
			local offset=pixel*4
			local alpha=buffer.readu8(source,offset+3)/255
			for channel=0,2 do
				local top=buffer.readu8(source,offset+channel)/255
				local bottom=buffer.readu8(result,offset+channel)/255
				local blended=if mode=="multiply" then top*bottom elseif mode=="screen" then top+bottom-top*bottom else top
				buffer.writeu8(result,offset+channel,math.round(math.clamp(bottom*(1-alpha)+blended*alpha,0,1)*255))
			end
		end
	end
	return result
end

return Pixels
