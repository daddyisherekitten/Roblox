--!strict
local Filter={}
local Syntax=require(script.Parent.Syntax)
local Color=require(script.Parent.Color)
local NONE=table.freeze({Steps=table.freeze({}),Key="none"})
local supported={brightness=true,contrast=true,grayscale=true,invert=true,sepia=true,saturate=true,["hue-rotate"]=true,opacity=true,blur=true,["drop-shadow"]=true}
local bounded={grayscale=true,invert=true,sepia=true,opacity=true}
local function number(raw: string): number?
	if not (raw:match("^[+-]?%d+%.?%d*$") or raw:match("^[+-]?%.%d+$")) then return nil end
	local n=tonumber(raw)
	return if n and math.abs(n)<=100000 then n else nil
end
local function length(raw: string): number?
	local px=raw:sub(-2)=="px"
	local n=number(if px then raw:sub(1,-3) else raw)
	return if n and (px or n==0) and math.abs(n)<=1000 then n else nil
end
local function shadow(arg: string): any?
	local lengths,tint,alpha,afterColor={},nil,1,false
	local cursor=1
	while cursor<=#arg do
		local token,nextCursor=Syntax.scan(arg,cursor," \t\r\n")
		cursor=nextCursor
		if token=="" then continue end
		local n=length(token)
		if n~=nil then
			if #lengths>=3 or afterColor then return nil end
			table.insert(lengths,n)
		else
			if tint~=nil then return nil end
			tint,alpha=Color.parse(token)
			if not tint then return nil end
			afterColor=#lengths>0
		end
	end
	if #lengths<2 or (lengths[3] or 0)<0 or (lengths[3] or 0)>100 then return nil end
	return {Name="drop-shadow",X=lengths[1],Y=lengths[2],Value=lengths[3] or 0,Color=tint or "currentcolor",Alpha=alpha or 1}
end
local function key(step: any): string
	local n=string.format("%.17g",step.Value)
	if step.Name~="drop-shadow" then return step.Name.."("..n..")" end
	local tint=step.Color
	local color=if tint=="currentcolor" then tint else string.format("%.17g,%.17g,%.17g",tint.R,tint.G,tint.B)
	return string.format("drop-shadow(%.17g,%.17g,%s,%s,%.17g)",step.X,step.Y,n,color,step.Alpha)
end
local function functionParts(raw: string): (string?,string?,string?)
	local name=raw:match("^([a-z%-]+)%(")
	if not name then return nil,nil,nil end
	local depth=1
	for i=#name+2,#raw do
		local ch=raw:sub(i,i)
		if ch=="(" then depth+=1; if depth>4 then return nil,nil,nil end
		elseif ch==")" then
			depth-=1
			if depth==0 then return name,raw:sub(#name+2,i-1),raw:sub(i+1) end
		end
	end
	return nil,nil,nil
end
function Filter.parse(raw: string): any?
	raw=raw:lower():match("^%s*(.-)%s*$") :: string
	if raw=="none" then return NONE end
	local steps,keys={},{}
	local outset=0
	local hasBlur,hasShadow,hasCurrent=false,false,false
	while #raw>0 do
		local name,arg,rest=functionParts(raw)
		if not name or not supported[name] or #steps>=16 then return nil end
		arg=arg:match("^%s*(.-)%s*$")
		if name=="drop-shadow" then
			local step=shadow(arg)
			if not step then return nil end
			table.insert(steps,table.freeze(step)); table.insert(keys,key(step))
			outset+=math.max(math.abs(step.X),math.abs(step.Y))+3*step.Value
			hasShadow=true; hasCurrent=hasCurrent or step.Color=="currentcolor"
			raw=rest:match("^%s*(.-)%s*$")
			continue
		end
		local value
		if arg=="" then value=if name=="hue-rotate" or name=="blur" then 0 else 1
		elseif name=="blur" then
			local px=arg:sub(-2)=="px"
			value=number(if px then arg:sub(1,-3) else arg)
			if value==nil or value<0 or value>100 or (not px and value~=0) then return nil end
		elseif name=="hue-rotate" then
			local n,unit=arg:match("^(.-)([a-z]+)$")
			value=number(n or arg)
			if value==nil then return nil end
			local scale=({deg=1,grad=.9,rad=180/math.pi,turn=360})[unit or ""]
			if not scale and (unit~=nil or value~=0) then return nil end
			value*=scale or 1
		else
			local percent=arg:sub(-1)=="%"
			value=number(if percent then arg:sub(1,-2) else arg)
			if value==nil or value<0 then return nil end
			if percent then value/=100 end
			if bounded[name] then value=math.min(1,value) end
		end
		table.insert(steps,table.freeze({Name=name,Value=value}))
		if name=="blur" then outset+=3*value; hasBlur=hasBlur or value>0 end
		table.insert(keys,name.."("..string.format("%.17g",value)..")")
		raw=rest:match("^%s*(.-)%s*$")
	end
	if #steps==0 then return nil end
	return table.freeze({Steps=table.freeze(steps),Key=table.concat(keys," "),HasBlur=hasBlur,HasRaster=hasBlur or hasShadow,HasCurrent=hasCurrent,Outset=math.ceil(outset)})
end
function Filter.resolve(filter: any,color: any,alpha: number): any
	if not filter or not filter.HasCurrent then return filter end
	local result=table.clone(filter); local steps,keys={},{}
	for _,step in filter.Steps do
		if step.Color=="currentcolor" then step=table.clone(step); step.Color,step.Alpha=color,alpha; table.freeze(step) end
		table.insert(steps,step); table.insert(keys,key(step))
	end
	result.Steps,result.Key,result.HasCurrent=table.freeze(steps),table.concat(keys," "),false
	return table.freeze(result)
end
-- CanvasGroup can multiply the complete native subtree without replacing glyphs.
function Filter.native(value: any): (number?,number?)
 local brightness,alpha=1,1
 for _,step in value and value.Steps or {}do
  if step.Name=='brightness' and step.Value<=1 then brightness*=step.Value
  elseif step.Name=='opacity' then alpha*=step.Value
  else return nil,nil end
 end
 return brightness,alpha
end
return Filter
