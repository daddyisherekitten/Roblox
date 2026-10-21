--!strict
-- Inherited presentation paint, before the full SVG CSS cascade is connected.
local Color=require(script.Parent.Parent.CSS.Color)
local Length=require(script.Parent.Length)
local Paint={}
local defaults={Color={0,0,0,1},Fill={0,0,0,1},Stroke="none",FillOpacity=1,StrokeOpacity=1,StrokeWidth=1,FillRule='nonzero',DashArray='none',DashOffset=0,LineCap='butt',LineJoin='miter',MiterLimit=4}
local function normalized(value: string): string return string.lower(value:match('^%s*(.-)%s*$') :: string) end
local function shade(value: string): any
	if value=='none' or value=='currentcolor' or value=='context-fill' or value=='context-stroke' then return value end
	local rgb,alpha=Color.parse(value)
	if not rgb then return nil end
	return {rgb.R*255,rgb.G*255,rgb.B*255,alpha}
end
-- Keep URL fragments case-sensitive. Only solid color keywords are normalized.
function Paint.reference(value: string): any?
 local url,tail=value:match('^[Uu][Rr][Ll]%(%s*(.-)%s*%)%s*(.-)%s*$')
 if not url then return nil end
 if url:sub(1,1)=='"' or url:sub(1,1)=="'" then
  if url:sub(-1)~=url:sub(1,1) then return nil end
  url=url:sub(2,-2)
 elseif url:find([=[[%s"'()]]=]) then return nil end
 if url=='' then return nil end
 local fallback=if tail=='' then 'none' else shade(normalized(tail))
 if not fallback or fallback=='context-fill' or fallback=='context-stroke' or type(fallback)=='table' and fallback.URL then return nil end
 return {URL=url,Fallback=fallback}
end
function Paint.resolve(a: any,parent: any?,context: any): (any,any)
	parent=parent or defaults
	local state=table.clone(parent)
	local diagnostics={}
	for attribute,key in {color='Color',fill='Fill',stroke='Stroke',['fill-opacity']='FillOpacity',['stroke-opacity']='StrokeOpacity',['stroke-width']='StrokeWidth',['fill-rule']='FillRule',['stroke-dasharray']='DashArray',['stroke-dashoffset']='DashOffset',['stroke-linecap']='LineCap',['stroke-linejoin']='LineJoin',['stroke-miterlimit']='MiterLimit'} do
		if a[attribute]==nil then continue end
		local value=normalized(a[attribute])
		if value=='inherit' or value=='unset' then continue end
		if value=='initial' then state[key]=defaults[key];continue end
		local parsed,problem
		if key=='LineCap' or key=='LineJoin' then
			local allowed=if key=='LineCap' then {butt=true,round=true,square=true} else {miter=true,round=true,bevel=true}
			if allowed[value] then parsed=value else problem='unsupported-stroke-style' end
		elseif key=='MiterLimit' then
			local token=Length.parse(value)
			if token and token.Unit=='' and token.Value>=1 and token.Value<=1e9 then parsed=token.Value else problem='invalid-miterlimit' end
		elseif key=='DashOffset' then
			parsed,problem=Length.resolve(value,context,'diagonal',false)
			if parsed and math.abs(parsed)>1e9 then parsed=nil;problem='geometry-range' end
			if parsed and value:sub(-1)=='%' then parsed=value end
		elseif key=='FillRule' then
			if value=='nonzero' or value=='evenodd' then parsed=value else problem='invalid-fill-rule' end
		elseif key=='DashArray' then
			if value=='none' then parsed='none'
			else
				parsed={}
				if value:match('^,') or value:match(',$') or value:match(',%s*,') then problem='invalid-dasharray' end
				for token in value:gmatch('[^,%s]+') do
					local numeric,issue=Length.resolve(token,context,'diagonal',true)
					if not numeric or issue or numeric>1e9 or #parsed>=64 then problem='invalid-dasharray';break end
					table.insert(parsed,if token:sub(-1)=='%' then token else numeric)
				end
				if #parsed==0 then problem='invalid-dasharray' end
				if problem then parsed=nil end
			end
		elseif key=='Color' or key=='Fill' or key=='Stroke' then
			parsed=if key~='Color' then Paint.reference(a[attribute]:match('^%s*(.-)%s*$')) or shade(value) else shade(value)
			if key=='Color' then
				if parsed=='none' or parsed=='context-fill' or parsed=='context-stroke' then parsed=nil elseif parsed=='currentcolor' then parsed=parent.Color end
			end
			if parsed==nil then problem='invalid-paint' end
		elseif key=='StrokeWidth' then
			local token=Length.parse(value)
			parsed,problem=Length.resolve(value,context,'diagonal',true)
			if parsed and parsed>1e9 then parsed=nil;problem='geometry-range' end
			-- Computed absolute/font lengths inherit as numbers; percentages keep their basis until use.
			if parsed and token and token.Unit=='%' then parsed=value end
		else
			local token=Length.parse(value)
			if token and (token.Unit=='' or token.Unit=='%') then parsed=math.clamp(token.Value/(if token.Unit=='%' then 100 else 1),0,1)
			else problem='invalid-opacity' end
		end
		if parsed~=nil then state[key]=parsed end
		if problem then table.insert(diagnostics,{Code=problem,Attribute=attribute,Value=a[attribute]}) end
	end
	return state,diagnostics
end
function Paint.used(state: any,context: any): (any,any,number)
	local rgba
	rgba=function(value: any,opacity: number): any
		if value=='none' then return nil end
		if value=='context-fill' or value=='context-stroke' then return {Context=value,Opacity=opacity} end
		if value=='currentcolor' then value=state.Color end
		if type(value)=='table' and value.URL then return {URL=value.URL,Fallback=rgba(value.Fallback,opacity),Opacity=opacity} end
		return {value[1],value[2],value[3],value[4]*opacity}
	end
	local width=state.StrokeWidth
	if type(width)=='string' then width=Length.resolve(width,context,'diagonal',true) or 0 end
	return rgba(state.Fill,state.FillOpacity),rgba(state.Stroke,state.StrokeOpacity),width
end
function Paint.dashes(state: any,context: any): any
	if state.DashArray=='none' or state.DashArray==nil then return nil end
	local result={}
	for _,value in state.DashArray do
		table.insert(result,{Value=if type(value)=='string' then Length.resolve(value,context,'diagonal',true) or 0 else value,Percent=type(value)=='string'})
	end
	return result
end
function Paint.offset(state: any,context: any): any
	local value=state.DashOffset or 0
	return {Value=if type(value)=='string' then Length.resolve(value,context,'diagonal',false) or 0 else value,Percent=type(value)=='string'}
end
return Paint
