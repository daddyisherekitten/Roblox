--!strict
local LengthExpression=require(script.Parent.LengthExpression)
local SVGPath=require(script.Parent.Parent.SVG.Path)
local Curves=require(script.Parent.Parent.SVG.Curves)
local MotionPath={}

function MotionPath.parse(source: string): any?
	local parts,diagnostics=SVGPath.parse(source)
	if #diagnostics>0 or #parts==0 then return nil end
	if #parts==1 and #parts[1].Points==2 and not parts[1].Closed and next(parts[1].Curves)==nil then
		local first,last=parts[1].Points[1],parts[1].Points[2]
		return {Kind="line",X1=first[1],Y1=first[2],X2=last[1],Y2=last[2]}
	end
	-- Use the same bounded adaptive flattening as SVG. Geometry and cumulative
	-- lengths are prepared once, never reparsed during layout or animation.
	local ok,flattened=pcall(Curves.flatten,parts,4)
	if not ok or not flattened then return nil end
	local segments,total={},0
	local function add(a: any,b: any)
		local dx,dy=b[1]-a[1],b[2]-a[2]
		local length=math.sqrt(dx*dx+dy*dy)
		if length<=1e-9 then return end
		table.insert(segments,{X=a[1],Y=a[2],DX=dx,DY=dy,Start=total,Length=length,Finish=total+length})
		total+=length
	end
	for _,part in flattened do
		for index=2,#part.Points do add(part.Points[index-1],part.Points[index]) end
		if part.Closed and #part.Points>1 then add(part.Points[#part.Points],part.Points[1]) end
	end
	return {Kind="path",Segments=segments,Length=total,Start=flattened[1].Points[1],Closed=source:match("[Zz]%s*$")~=nil}
end

function MotionPath.length(style: any,width: number,height: number): number
	local path=style.OffsetPath
	if not path then return 0 end
	if path.Kind=="path" then return path.Length end
	if path.Kind=="line" then return math.sqrt((path.X2-path.X1)^2+(path.Y2-path.Y1)^2) end
	return math.max(width,height)
end

local function rotation(style: any,dx: number,dy: number): number
	local rotate=style.OffsetRotate or {Auto=true,Angle=0}
	return (if rotate.Auto then math.deg(math.atan2(dy,dx))+(if rotate.Reverse then 180 else 0) else 0)+(rotate.Angle or 0)
end

function MotionPath.resolve(style: any,width: number,height: number,distanceOverride: any?): any
	local path=style.OffsetPath;if not path then return {X=0,Y=0,Rotation=0} end
	if path.Kind=="path" then
		if path.Length<=1e-9 then return {X=path.Start[1],Y=path.Start[2],Rotation=rotation(style,1,0)} end
		local distance=LengthExpression.resolve(distanceOverride or style.OffsetDistance,path.Length)
		distance=if path.Closed then distance%path.Length else math.clamp(distance,0,path.Length)
		local low,high=1,#path.Segments
		while low<high do
			local middle=math.floor((low+high)/2)
			if path.Segments[middle].Finish<distance then low=middle+1 else high=middle end
		end
		local segment=path.Segments[low]
		local t=math.clamp((distance-segment.Start)/segment.Length,0,1)
		return {X=segment.X+segment.DX*t,Y=segment.Y+segment.DY*t,Rotation=rotation(style,segment.DX,segment.DY)}
	end
	local x1,y1,x2,y2
	if path.Kind=="line" then x1,y1,x2,y2=path.X1,path.Y1,path.X2,path.Y2
	else
		local radians=math.rad(path.Angle or 0);local length=math.max(width,height)
		local position=style.OffsetPosition
		if position then
			x1=LengthExpression.resolve(position.X,width);y1=LengthExpression.resolve(position.Y,height)
		else x1,y1=width/2,height/2 end
		x2,y2=x1+math.cos(radians)*length,y1+math.sin(radians)*length
	end
	local dx,dy=x2-x1,y2-y1;local pathLength=math.sqrt(dx*dx+dy*dy)
	local distance=LengthExpression.resolve(distanceOverride or style.OffsetDistance,pathLength)
	local t=if pathLength>0 then (if path.Kind=="line" then math.clamp(distance/pathLength,0,1) else distance/pathLength) else 0
	return {X=x1+dx*t,Y=y1+dy*t,Rotation=rotation(style,dx,dy)}
end

return MotionPath
