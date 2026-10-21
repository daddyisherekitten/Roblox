--!strict
-- Parsers for the bounded containment, compositing and motion-path profile.
local Syntax=require(script.Parent.Syntax)
local ScrollTimeline=require(script.Parent.ScrollTimeline)
local Color=require(script.Parent.Color)
local MotionPath=require(script.Parent.MotionPath)
local Background=require(script.Parent.Background)
local LengthExpression=require(script.Parent.LengthExpression)
local PositionArea=require(script.Parent.PositionArea)
local Advanced={}

local function trim(value: string): string return value:match("^%s*(.-)%s*$") or "" end
local function tokens(value: string): {string}
	local result,index={},1
	while index<=#value do local part,nextIndex=Syntax.scan(value,index," \t\r\n");index=nextIndex;part=trim(part);if part~="" then table.insert(result,part) end end
	return result
end
local function ident(value: string): boolean
	local ordinary=value:match("^%-?[%a_][%w_%-]*$")~=nil
	local dashed=value:match("^%-%-[%a_][%w_%-]*$")~=nil
	return (ordinary or dashed) and value~="none" and value~="normal"
end

function Advanced.contain(value: string): any?
	if value=="none" then return {} end
	if value=="strict" then return {Size=true,Layout=true,Paint=true,Style=true} end
	if value=="content" then return {Layout=true,Paint=true,Style=true} end
	local result={}
	for _,token in tokens(value) do
		local field=if token=="size" then "Size" elseif token=="inline-size" then "InlineSize" elseif token=="layout" then "Layout" elseif token=="paint" then "Paint" elseif token=="style" then "Style" else nil
		if not field or result[field] or (field=="Size" and result.InlineSize) or (field=="InlineSize" and result.Size) then return nil end
		result[field]=true
	end
	return if next(result) then result else nil
end

function Advanced.names(value: string): any?
	if value=="none" then return {} end
	local result={};for _,token in tokens(value) do if not ident(token) then return nil end;table.insert(result,token) end
	return if #result>0 and #result<=8 then result else nil
end

function Advanced.anchorReference(value: string): string?
	if value=="auto" then return nil end
	return if value:match("^%-%-[%a_][%w_%-]*$") then value else nil
end

function Advanced.positionArea(value: string): string?
	return PositionArea.parse(value)
end

function Advanced.containerType(value: string): string?
	local size,scroll=nil,false
	for part in value:lower():gmatch('%S+')do
		if part=='scroll-state'then if scroll then return nil end;scroll=true
		elseif part=='size'or part=='inline-size'then if size then return nil end;size=part
		elseif part=='normal'and value:lower()=='normal'then return 'normal'
		else return nil end
	end
	return if size and scroll then size..' scroll-state'elseif size then size elseif scroll then 'scroll-state'else nil
end
function Advanced.container(value: string): any?
	local name,typeValue=value:match("^(.-)%s*/%s*(.-)$")
	if not name then
		if value=="normal" or value=="size" or value=="inline-size" then return {Names={},Type=value} end
		local names=Advanced.names(value);return if names then {Names=names,Type="normal"} else nil
	end
	local names=Advanced.names(trim(name));typeValue=trim(typeValue)
	local parsedType=Advanced.containerType(typeValue)
	if not names or not parsedType then return nil end
	return {Names=names,Type=parsedType}
end

local function length(value: string, parseLength: (string,boolean?)->any?, allowPercent: boolean?): any?
	local parsed=parseLength(trim(value));if not parsed or (parsed.Percent and not allowPercent) then return nil end;return parsed
end

function Advanced.clipPath(value: string,parseLength: (string,boolean?)->any?): any?
	if value=="none" then return nil end
	local name,body=value:match("^([%a%-]+)%((.*)%)$");if not name then return nil end
	name=name:lower();body=trim(body)
	if name=="circle" then
		local radius,at=body:match("^(.-)%s+at%s+(.+)$");radius=trim(radius or body)
		if at and trim(at)~="center" and trim(at)~="50% 50%" then return nil end
		local r=if radius=="closest-side" then {Value=50,Percent=true} else length(radius,parseLength,true)
		return if r then {Kind="circle",Radius=r} else nil
	elseif name=="ellipse" then
		local radii,at=body:match("^(.-)%s+at%s+(.+)$");radii=trim(radii or body)
		if at and trim(at)~="center" and trim(at)~="50% 50%" then return nil end
		local parts=tokens(radii);if #parts~=2 then return nil end
		local x,y=length(parts[1],parseLength,true),length(parts[2],parseLength,true)
		return if x and y then {Kind="ellipse",X=x,Y=y} else nil
	elseif name=="inset" then
		local inset,radius=body:match("^(.-)%s+round%s+(.+)$");inset=trim(inset or body)
		local parts=tokens(inset);if #parts<1 or #parts>4 then return nil end
		for _,part in parts do local v=length(part,parseLength,true);if not v or v.Value~=0 then return nil end end
		local r=if radius then length(radius,parseLength,true) else {Value=0,Percent=false}
		return if r then {Kind="inset",Radius=r} else nil
	elseif name=="polygon" then
		local points,index={},1
		while index<=#body do
			local pair,nextIndex,separator=Syntax.scan(body,index,",")
			local coordinates=tokens(trim(pair))
			if #coordinates~=2 then return nil end
			local x,y=length(coordinates[1],parseLength,true),length(coordinates[2],parseLength,true)
			if not x or not y then return nil end
			table.insert(points,{X=x,Y=y})
			if #points>32 or (separator~="" and nextIndex>#body) then return nil end
			index=nextIndex
			if separator=="" then break end
		end
		return if #points>=3 then {Kind="polygon",Points=points,Key=body} else nil
	end
	return nil
end

function Advanced.mask(value: string): any?
	if value=="none" then return nil end
	local layers=Background.images(value,function(part) return LengthExpression.parse(part) end)
	if not layers or #layers>8 then return nil end
	for _,layer in layers do if layer.Kind~="linear" and layer.Kind~="radial" and layer.Kind~="conic" and layer.Kind~="none" then return nil end end
	local result={Kind="layers",Layers=layers,Key=value}
	local body=value:match("^linear%-gradient%((.*)%)$");if not body then return result end
	local direction,first,last=body:match("^%s*(to%s+[%a%-]+)%s*,%s*(.-)%s*,%s*(.-)%s*$")
	if not direction then first,last=body:match("^%s*(.-)%s*,%s*(.-)%s*$");direction="to bottom" end
	if not first or not last then return result end
	first=trim((first:gsub("%s+[%d%.]+%%$","")));last=trim((last:gsub("%s+[%d%.]+%%$","")))
	local _,a1=Color.parse(first);local _,a2=Color.parse(last);if a1==nil or a2==nil then return result end
	local rotation=if direction=="to right" then 0 elseif direction=="to left" then 180 elseif direction=="to top" then 270 elseif direction=="to bottom" then 90 else nil
	if rotation and #layers==1 and #layers[1].Stops==2 and not layers[1].Stops[1].Positions[1] and not layers[1].Stops[2].Positions[1] then
		result.Kind,result.Rotation,result.StartAlpha,result.EndAlpha="linear",rotation,a1,a2
	end
	return result
end

function Advanced.borderImageSource(value: string): any?
	if value=="none" then return nil end
	local source=value:match("^url%(%s*['\"]?(.-)['\"]?%s*%)$")
	if source and source~="" then return {Kind="url",Source=source} end
	local layers=Background.images(value,function(part)return LengthExpression.parse(part)end)
	if layers and #layers==1 and (layers[1].Kind=='linear'or layers[1].Kind=='radial'or layers[1].Kind=='conic')then
		local g=layers[1];local first,last=g.Stops[1],g.Stops[#g.Stops]
		return {Kind='gradient',Gradient=g,Key=value,Direction=tostring(g.Angle or 180),Angle=g.Angle,Stops=g.Stops,Color1=first.Color,Alpha1=first.Alpha,Color2=last.Color,Alpha2=last.Alpha}
	end
	local body=value:match("^linear%-gradient%((.*)%)$");if not body then return nil end
	local parts,index={},1
	while index<=#body do
		local part,nextIndex,separator=Syntax.scan(body,index,",")
		part=trim(part)
		if part=="" or #parts>=9 then return nil end
		table.insert(parts,part)
		if separator~="" and nextIndex>#body then return nil end
		index=nextIndex
		if separator=="" then break end
	end
	local angles={["to top"]=0,["to right"]=90,["to bottom"]=180,["to left"]=270}
	local direction,angle,first="to bottom",180,1
	if angles[parts[1]] then direction,angle,first=parts[1],angles[parts[1]],2
	else
		local degrees=parts[1]:match("^([+%-]?%d*%.?%d+)deg$")
		if degrees then direction,angle,first=parts[1],tonumber(degrees),2 end
	end
	if #parts-first+1<2 or #parts-first+1>8 then return nil end
	local stops={}
	for at=first,#parts do
		local color,alpha=Color.parse(parts[at])
		if not color then return nil end
		table.insert(stops,{Color=color,Alpha=alpha or 1})
	end
	return {Kind="gradient",Direction=direction,Angle=angle,Stops=if #stops>2 then stops else nil,
		Color1=stops[1].Color,Alpha1=stops[1].Alpha,Color2=stops[#stops].Color,Alpha2=stops[#stops].Alpha}
end

function Advanced.numberSides(value: string,maxValue: number?): any?
	local values={};for _,token in tokens(value) do
		local raw=token:match("^([%d%.]+)%%$") or token:match("^([%d%.]+)$");local number=tonumber(raw or "")
		if not number or number<0 or number>(maxValue or 100000) then return nil end;table.insert(values,number)
	end
	if #values<1 or #values>4 then return nil end
	return {values[1],values[2] or values[1],values[3] or values[1],values[4] or values[2] or values[1]}
end

function Advanced.maskBorderSource(value)
	local source=Advanced.mask(value);if source and #source.Layers==1 then source.Kind='layers';source.BorderMask=true;return source end
	return nil
end
function Advanced.maskBorder(value,parseLength)
	local mode=value:match('([%a]+)%s*$')
	if mode=='alpha'or mode=='luminance'then value=trim(value:sub(1,#value-#mode))else mode='alpha'end
	local result=Advanced.borderImage(value,parseLength)
	if not result or result.Source and result.Source.Kind~='gradient'then return nil end
	if result.Source then result.Source=Advanced.maskBorderSource(result.Source.Key)end
	local rest=value:match('^[%a%-]+%b()%s*(.*)$')or ''
	if not rest:find('%d')then result.Slice=Advanced.imageSlice('0')end
	if not rest:find('/',1,true)then result.Width={'auto','auto','auto','auto'}end
	result.Mode=mode;return result
end
function Advanced.imageRepeat(value)
	local parts=tokens(value);if #parts<1 or #parts>2 then return nil end
	for _,part in parts do if not ({stretch=true,round=true,['repeat']=true,space=true})[part]then return nil end end
	return table.concat(parts,' ')
end
function Advanced.borderImage(value: string,parseLength): any?
	if value=="none" then return {Source=nil,Slice=Advanced.imageSlice('100%'),Width={1,1,1,1},Outset={0,0,0,0},Repeat="stretch"} end
	local url,rest=value:match("^([%a%-]+%b())%s*(.-)%s*$");if not url then return nil end
	local source=Advanced.borderImageSource(url);if not source then return nil end
	local repeatValue=nil
	for _=1,2 do local token=rest:match('([%a%-]+)%s*$');if token and Advanced.imageRepeat(token)then repeatValue=token..(if repeatValue then ' '..repeatValue else '');rest=trim(rest:sub(1,#rest-#token))else break end end
	if rest:sub(-1)=='/'then return nil end
	local pieces,index={},1
	while index<=#rest do local part,nextIndex=Syntax.scan(rest,index,'/');table.insert(pieces,trim(part));index=nextIndex end
	if #pieces>3 then return nil end
	local slice=Advanced.imageSlice(pieces[1]or '100%')
	local width=if pieces[2]and pieces[2]~=''then Advanced.imageWidths(pieces[2],false,parseLength)else {1,1,1,1}
	local outset=if pieces[3]then Advanced.imageWidths(pieces[3],true,parseLength)else {0,0,0,0}
	return if slice and width and outset then {Source=source,Slice=slice,Width=width,Outset=outset,Repeat=repeatValue or 'stretch'}else nil
end

function Advanced.imageSlice(value)
	local fill=false;local parts={};for _,token in tokens(value)do if token=='fill'then if fill then return nil end;fill=true else table.insert(parts,token)end end
	local result=Advanced.numberSides(table.concat(parts,' '));if not result then return nil end
	local flags={};for _,token in parts do table.insert(flags,token:sub(-1)=='%')end
	result.Percent={flags[1],if flags[2]~=nil then flags[2]else flags[1],if flags[3]~=nil then flags[3]else flags[1],if flags[4]~=nil then flags[4]elseif flags[2]~=nil then flags[2]else flags[1]};result.Fill=fill
	return result
end
function Advanced.imageWidths(value,outset,parseLength)
	local result={};for _,token in tokens(value)do
		local n=tonumber(token)
		if n and n>=0 and n<=100000 then table.insert(result,n)
		elseif token=='auto'and not outset then table.insert(result,'auto')
		else local v=if parseLength then parseLength(token)else LengthExpression.parse(token)
			if not v or (outset and v.Percent)or LengthExpression.resolve(v,100)<0 then return nil end;table.insert(result,v)
		end
	end
	if #result<1 or #result>4 then return nil end
	return {result[1],result[2]or result[1],result[3]or result[1],result[4]or result[2]or result[1]}
end

function Advanced.offsetPath(value: string,parseLength: (string,boolean?)->any?): any?
	if value:lower()=="none" then return nil end
	local _,quoted=value:match("^[Pp][Aa][Tt][Hh]%(%s*(['\"])(.-)%1%s*%)$")
	if quoted then
		return MotionPath.parse(quoted)
	end
	local body=value:lower():match("^ray%((.*)%)$");if body then
		local angle=body:match("^%s*([%+%-]?[%d%.]+)deg%s*$");if not angle then return nil end
		return {Kind="ray",Angle=tonumber(angle),Length={Value=100,Percent=true}}
	end
	return nil
end

function Advanced.offsetRotate(value: string): any?
	if value=="auto" then return {Auto=true,Reverse=false,Angle=0} elseif value=="reverse" then return {Auto=true,Reverse=true,Angle=0} end
	local auto,angle=value:match("^(auto)%s+([%+%-]?[%d%.]+)deg$");if auto then return {Auto=true,Reverse=false,Angle=tonumber(angle)} end
	local number=value:match("^([%+%-]?[%d%.]+)deg$");return if number then {Auto=false,Reverse=false,Angle=tonumber(number)} else nil
end

function Advanced.shape(value: string,parseLength: (string,boolean?)->any?): any?
	if value=="none" then return nil end
	local source=value:match('^url%(%s*"(.-)"%s*%)$') or value:match("^url%(%s*'(.-)'%s*%)$") or value:match('^url%(%s*([^%s"\'()]+)%s*%)$')
	if source and source~='' then return {Kind='image',Source=source} end
	local shape=Advanced.clipPath(value,parseLength)
	if not shape or (shape.Kind~="circle" and shape.Kind~="ellipse") then return nil end
	return shape
end

function Advanced.scrollbarGutter(value: string): any?
	if value=="auto" then return {Stable=false,BothEdges=false} end
	local stable,both=false,false
	for _,token in tokens(value) do
		if token=="stable" and not stable then stable=true
		elseif token=="both-edges" and not both then both=true
		else return nil end
	end
	return if stable then {Stable=true,BothEdges=both} else nil
end

function Advanced.fontSizeAdjust(value: string): any?
	if value=="none" then return {Kind="none"} end
	if value=="from-font" then return {Kind="from-font"} end
	local number=tonumber(value)
	return if number and number>=0 and number<=4 then {Kind="number",Value=number} else nil
end

function Advanced.offset(value: string,parseLength: (string,boolean?)->any?,parsePosition: (string)->any?): any?
	local before,after=Syntax.scan(value,1,"/")
	local left=trim(before);local anchor=if after<=#value then parsePosition(trim(value:sub(after)):lower()) else nil
	if after<=#value and not anchor then return nil end
	local pathText=left:match("^([Pp][Aa][Tt][Hh]%b())") or left:match("^([Rr][Aa][Yy]%b())") or (left:lower():match("^none") and "none")
	if not pathText then return nil end
	local path=Advanced.offsetPath(pathText,parseLength);if pathText~="none" and not path then return nil end
	local rest=trim(left:sub(#pathText+1)):lower();local distance={Value=0,Percent=false};local rotate={Auto=true,Reverse=false,Angle=0}
	if rest~="" then
		local parts=tokens(rest)
		local parsedDistance=parseLength(parts[1],true)
		if parsedDistance then distance=parsedDistance;table.remove(parts,1) end
		if #parts>0 then rotate=Advanced.offsetRotate(table.concat(parts," ")) or nil end
		if not rotate then return nil end
	end
	return {Path=path,Distance=distance,Rotate=rotate,Anchor=anchor}
end

function Advanced.timelineList(value: string): any?
	local result={};for part in value:gmatch("[^,]+") do
		part=trim(part);if not ScrollTimeline.parse(part)then return nil end;table.insert(result,part)
	end
	return if #result>0 and #result<=16 then result else nil
end

function Advanced.backdrop(value: string): any?
	if value=="none" then return nil end
	local blur,brightness=0,1
	for _,token in tokens(value) do
		local raw=token:match("^blur%(([%d%.]+)px%)$")
		if raw then blur=tonumber(raw) or 0;if blur>100 then return nil end
		else
			local percent=token:match("^brightness%(([%d%.]+)%%%)$") or token:match("^brightness%(([%d%.]+)%)$")
			if not percent then return nil end;brightness=tonumber(percent) or 1;if token:find("%",1,true) then brightness/=100 end
			if brightness<0 or brightness>4 then return nil end
		end
	end
	return {Blur=blur,Brightness=brightness}
end

return Advanced
