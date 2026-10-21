--!strict
local Matrix=require(script.Parent.Matrix)
local Viewport = {}
local function finite(n: number): boolean return n==n and math.abs(n)<math.huge end

function Viewport.viewBox(value: string?): (any?,string?)
	if value==nil then return nil,nil end
	if value:match("^%s*,") or value:match(",%s*$") or value:match(",%s*,") then return nil,"invalid-viewBox" end
	local numbers={}
	for word in value:gmatch("[^,%s]+") do
		local n=tonumber(word)
		if #numbers==4 or not word:match("^[+%-]?[%d%.]+[eE]?[+%-]?%d*$") or not n or not finite(n) then return nil,"invalid-viewBox" end
		table.insert(numbers,n)
	end
	if #numbers~=4 or numbers[3]<0 or numbers[4]<0 then return nil,"invalid-viewBox" end
	return {X=numbers[1],Y=numbers[2],Width=numbers[3],Height=numbers[4]},nil
end

function Viewport.aspect(value: string?): (any,string?)
	local default={X=.5,Y=.5,Mode="meet",Align="xMidYMid"}
	if value==nil then return default,nil end
	local words={};for word in value:gmatch("%S+") do table.insert(words,word) end
	local align,mode=words[1],words[2] or "meet"
	if #words<1 or #words>2 or (mode~="meet" and mode~="slice") then return default,"invalid-preserveAspectRatio" end
	if align=="none" then return {X=0,Y=0,Mode="none",Align=align},nil end
	local x,y=align:match("^x(%a+)Y(%a+)$")
	local factors={Min=0,Mid=.5,Max=1}
	if factors[x]==nil or factors[y]==nil then return default,"invalid-preserveAspectRatio" end
	return {X=factors[x],Y=factors[y],Mode=mode,Align=align},nil
end

function Viewport.compose(parent: any,child: any): any
	return Matrix.multiply(parent,child)
end
function Viewport.point(t: any,x: number,y: number): (number,number) return Matrix.point(t,x,y) end
function Viewport.intersect(a: any?,b: any): any
	if not a then return table.clone(b) end
	local x,y=math.max(a.X,b.X),math.max(a.Y,b.Y)
	local polygons=table.clone(a.Polygons or {});for _,polygon in b.Polygons or {} do table.insert(polygons,polygon) end
	return {X=x,Y=y,Width=math.max(0,math.min(a.X+a.Width,b.X+b.Width)-x),Height=math.max(0,math.min(a.Y+a.Height,b.Y+b.Height)-y),Polygons=polygons}
end

-- x/y/width/height are already resolved in parent user units by layout/length code.
-- Clip rectangles are in final output coordinates, before raster resolution scaling.
function Viewport.resolve(attributes: any,x: number,y: number,width: number,height: number,parent: any?,parentClip: any?,overflowVisible: boolean?): any
	for _,n in {x,y,width,height} do assert(finite(n),"Non-finite SVG viewport") end
	parent=parent or {SX=1,SY=1,TX=0,TY=0}
	assert(Matrix.valid(parent),"Viewport parent must be finite")
	local box,boxError=Viewport.viewBox(attributes.viewBox)
	local aspect,aspectError=Viewport.aspect(attributes.preserveAspectRatio)
	local result={Diagnostics={},Disabled=width<=0 or height<=0 or (box~=nil and (box.Width==0 or box.Height==0))}
	if boxError then table.insert(result.Diagnostics,boxError) end
	if aspectError then table.insert(result.Diagnostics,aspectError) end
	local sx,sy,tx,ty=1,1,x,y
	if box and not result.Disabled then
		sx,sy=width/box.Width,height/box.Height
		if aspect.Mode~="none" then
			local scale=if aspect.Mode=="slice" then math.max(sx,sy) else math.min(sx,sy)
			sx,sy=scale,scale
		end
		tx=x-box.X*sx+(width-box.Width*sx)*aspect.X
		ty=y-box.Y*sy+(height-box.Height*sy)*aspect.Y
	end
	result.Transform=Viewport.compose(parent,{SX=sx,SY=sy,TX=tx,TY=ty})
	for _,n in result.Transform do
		if not finite(n) then result.Disabled=true;table.insert(result.Diagnostics,"viewport-overflow");break end
	end
	if Matrix.determinant(result.Transform)==0 then result.Disabled=true;table.insert(result.Diagnostics,"viewport-underflow") end
	local polygon=Matrix.rectangle(parent,{X=x,Y=y,Width=math.max(0,width),Height=math.max(0,height)})
	result.Bounds=Matrix.bounds(polygon)
	local clip=table.clone(result.Bounds)
	if (parent.KX or 0)~=0 or (parent.KY or 0)~=0 then clip.Polygons={polygon} end
	result.Clip=if overflowVisible then parentClip else Viewport.intersect(parentClip,clip)
	result.UserX=if box then box.X else 0;result.UserY=if box then box.Y else 0
	result.UserWidth=if box then box.Width else width
	result.UserHeight=if box then box.Height else height
	return result
end
return Viewport
