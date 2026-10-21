--!strict
--!optimize 2
--!native
local Length=require(script.Parent.Length)
local Path=require(script.Parent.Path)
local PathMetrics=require(script.Parent.PathMetrics)
local Stroke=require(script.Parent.Stroke)
local Geometry={}
Geometry.Supported={rect=true,circle=true,ellipse=true,line=true,polyline=true,polygon=true,path=true}
function Geometry.build(name: string,a: any,context: any,outlineSubpaths: any?): (any?,any)
	local authorLength,lengthIssue=PathMetrics.parse(a.pathLength)
	if name=='path' then
		local parts,problems
  if outlineSubpaths then parts,problems=outlineSubpaths,{} else parts,problems=Path.parse(a.d or '') end
		if lengthIssue then table.insert(problems,{Code=lengthIssue,Attribute='pathLength'}) end
		return {Kind='path',Subpaths=parts,PathLength=authorLength},problems
	end
	local diagnostics={}
	if lengthIssue then table.insert(diagnostics,{Code=lengthIssue,Attribute='pathLength'}) end
	local function read(key: string,axis: string,default: any,nonNegative: boolean?,basis: any?): any
		if a[key]==nil or a[key]=="auto" then return default end
		local value,problem=Length.resolve(a[key],basis or context,axis,nonNegative)
		if value and math.abs(value)>1e9 then value=nil;problem="geometry-range" end
		if problem then table.insert(diagnostics,{Code=problem,Attribute=key}) end
		return if value==nil then default else value
	end
	local g={Kind=name,PathLength=authorLength,Closed=name~="line" and name~="polyline"}
	if name=="rect" then
		g.X,g.Y=read("x","x",0),read("y","y",0)
		g.Width,g.Height=read("width","x",0,true),read("height","y",0,true)
		local radiusContext=table.clone(context);radiusContext.Width=g.Width;radiusContext.Height=g.Height
		local rx,ry=read("rx","x",nil,true,radiusContext),read("ry","y",nil,true,radiusContext)
		g.RX,g.RY=math.min(rx or ry or 0,g.Width/2),math.min(ry or rx or 0,g.Height/2)
		g.Empty=g.Width<=0 or g.Height<=0
	elseif name=="circle" or name=="ellipse" then
		g.CX,g.CY=read("cx","x",0),read("cy","y",0)
		if name=="circle" then g.RX=read("r","diagonal",0,true);g.RY=g.RX
		else
			local rx,ry=read("rx","x",nil,true),read("ry","y",nil,true)
			g.RX,g.RY=rx or ry or 0,ry or rx or 0
		end
		g.Empty=g.RX<=0 or g.RY<=0
	elseif name=="line" then
		g.Points={{read("x1","x",0),read("y1","y",0)},{read("x2","x",0),read("y2","y",0)}}
	elseif name=="polyline" or name=="polygon" then
		local text=a.points or ""
		local numbers={}
		local malformed=text:match("^%s*,") or text:match(",%s*,")
		if not malformed then
			for token in text:gmatch("[^,%s]+") do
				local value=Length.parse(token)
				if not value or value.Unit~="" or math.abs(value.Value)>1e9 then malformed=true;break end
				if #numbers>=8192 then return nil,{{Code="point-limit",Attribute="points"}} end
				table.insert(numbers,value.Value)
			end
		end
		if malformed or #numbers%2~=0 then table.insert(diagnostics,{Code="invalid-points",Attribute="points"}) end
		g.Points={};for i=1,#numbers-1,2 do table.insert(g.Points,{numbers[i],numbers[i+1]}) end
	else return nil,{{Code="unsupported-shape"}} end
	return g,diagnostics
end

-- Curve chord deviation <= 0.125 output pixels, subject to the explicit segment cap.
function Geometry.contour(g: any,scale: number): any
	if g.Empty then return {} end
	if g.Points then return g.Points end
	local radius=math.max(g.RX,g.RY)*scale
	local count=if radius<=.125 then 16 else math.clamp(math.ceil(math.pi/math.acos(math.max(-1,1-.125/radius))),16,2048)
	count=math.ceil(count/4)*4
	local points={}
	if g.Kind=="rect" then
		local x,y,w,h,rx,ry=g.X,g.Y,g.Width,g.Height,g.RX,g.RY
		if rx==0 or ry==0 then return {{x,y},{x+w,y},{x+w,y+h},{x,y+h}} end
		for index,center in {{x+w-rx,y+ry},{x+w-rx,y+h-ry},{x+rx,y+h-ry},{x+rx,y+ry}} do
			for step=0,count/4 do
				local angle=(index-2)*math.pi/2+step/(count/4)*math.pi/2
				table.insert(points,{center[1]+math.cos(angle)*rx,center[2]+math.sin(angle)*ry})
			end
		end
	else
		for i=0,count-1 do local angle=i/count*2*math.pi;table.insert(points,{g.CX+math.cos(angle)*g.RX,g.CY+math.sin(angle)*g.RY}) end
	end
	return points
end

function Geometry.stroke(points: any,closed: boolean,width: number,options: any?): any
	return Stroke.build(points,closed,width,options)
end
return Geometry
