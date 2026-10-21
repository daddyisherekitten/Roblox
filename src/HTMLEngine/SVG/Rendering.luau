--!strict
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Length=require(script.Parent.Length)
local Blend=require(script.Parent.Blend)
local Rendering={}
local defaults={BlendMode="normal",Isolation="auto",Opacity=1,Display='inline',Visibility='visible',Overflow='visible',PaintOrder={'fill','stroke','markers'},ShapeRendering='auto',ColorRendering='auto',TextRendering='auto',ImageRendering='auto'}
local keys={["mix-blend-mode"]="BlendMode",isolation="Isolation",opacity='Opacity',display='Display',visibility='Visibility',overflow='Overflow',['paint-order']='PaintOrder',['shape-rendering']='ShapeRendering',['color-rendering']='ColorRendering',['text-rendering']='TextRendering',['image-rendering']='ImageRendering'}
local inherited={Visibility=true,PaintOrder=true,ShapeRendering=true,ColorRendering=true,TextRendering=true,ImageRendering=true}
local choices={BlendMode=Blend.Modes,Isolation={auto=true,isolate=true},Display={none=true,inline=true,block=true,['inline-block']=true,['list-item']=true,table=true,['inline-table']=true,['table-row']=true,['table-cell']=true,['table-row-group']=true,['table-column']=true,['table-column-group']=true,['table-header-group']=true,['table-footer-group']=true,['table-caption']=true,flex=true,['inline-flex']=true,grid=true,['inline-grid']=true,contents=true},Visibility={visible=true,hidden=true,collapse=true},Overflow={visible=true,hidden=true,clip=true,scroll=true,auto=true},ShapeRendering={auto=true,optimizeSpeed=true,crispEdges=true,geometricPrecision=true},ColorRendering={auto=true,optimizeSpeed=true,optimizeQuality=true},TextRendering={auto=true,optimizeSpeed=true,optimizeLegibility=true,geometricPrecision=true},ImageRendering={auto=true,optimizeSpeed=true,optimizeQuality=true,['crisp-edges']=true,pixelated=true}}
local function parse(key: string,value: string): any
	value=string.lower(value)
	if key=='Opacity' then
		local n=Length.parse(value)
		if n and (n.Unit=='' or n.Unit=='%') then return math.clamp(n.Value/(if n.Unit=='%' then 100 else 1),0,1) end
	elseif key=='PaintOrder' then
		if value=='normal' then return defaults.PaintOrder end
		local result,seen={},{}
		for word in value:gmatch('%S+') do
			if (word~='fill' and word~='stroke' and word~='markers') or seen[word] then return nil end
			seen[word]=true;table.insert(result,word)
		end
		if #result==0 then return nil end
		for _,word in defaults.PaintOrder do if not seen[word] then table.insert(result,word) end end
		return result
	else
		for choice in choices[key] do if string.lower(choice)==value then return choice end end
	end
	return nil
end
function Rendering.resolve(a: any,parent: any?,nestedSVG: boolean?): (any,any)
	parent=parent or defaults
	local result=table.clone(defaults);local errors={}
	for key in inherited do result[key]=parent[key] end
	-- The SVG user-agent rule clips inner viewports unless explicitly overridden.
	if nestedSVG then result.Overflow='hidden' end
	local important={}
	local function set(attribute: string,value: string,priority: boolean?)
		local key=keys[attribute];if not key or (important[key] and not priority) then return end
		value=string.lower(value:match('^%s*(.-)%s*$') :: string)
		local parsed
		if value=='inherit' then parsed=parent[key]
		elseif value=='initial' then parsed=defaults[key]
		elseif value=='unset' then parsed=if inherited[key] then parent[key] else defaults[key]
		else parsed=parse(key,value) end
		if parsed==nil then table.insert(errors,{Code='invalid-rendering-property',Attribute=attribute,Value=value});return end
		result[key]=parsed;important[key]=priority
	end
	for attribute in keys do if a[attribute] then set(attribute,a[attribute]) end end
	for _,item in Syntax.declarations(a.style or '') do
		local name,value=item.Text:match('^%s*([%a%-]+)%s*:%s*(.-)%s*$')
		if name then set(string.lower(name),value,item.Important) end
	end
	return result,errors
end
return Rendering
