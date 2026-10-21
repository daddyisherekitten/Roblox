--!strict
local Syntax=require(script.Parent.Syntax)
local Components=require(script.Parent.MediaSyntax)
local Length=require(script.Parent.LengthExpression)
local PositionArea=require(script.Parent.PositionArea)
local WritingMode=require(script.Parent.WritingMode)
local Anchor={}
local sides={top=true,right=true,bottom=true,left=true,center=true,start=true,['end']=true,['self-start']=true,['self-end']=true,inside=true,outside=true}
local sizes={width=true,height=true,block=true,inline=true,['self-block']=true,['self-inline']=true}
local orders={normal=true,['most-width']=true,['most-height']=true,['most-block-size']=true,['most-inline-size']=true}
function Anchor.order(value)
	local items=Components.parse(value)
	return if items and #items==1 and items[1].Kind=='ident'and orders[items[1].Value]then items[1].Value else nil
end
function Anchor.shorthand(value)
	local items=Components.parse(value);if not items or #items==0 then return nil end
	local first=items[1];local order='normal'
	if first.Kind=='ident'and orders[first.Value]then order=first.Value;value=value:sub(first.After)end
	local recipes=Anchor.tries(value)
	return if recipes then {Order=order,Fallbacks=recipes}else nil
end
function Anchor.serializeTries(recipes,computed)
	local parts={}
	for _,recipe in recipes do
		if recipe.Area then table.insert(parts,PositionArea.serialize(recipe.Area,computed));continue end
		local tokens={};if recipe.Name then table.insert(tokens,Syntax.serializeIdentifier(recipe.Name))end
		for _,tactic in {'flip-block','flip-inline','flip-start','flip-x','flip-y'}do if recipe[tactic]then table.insert(tokens,tactic)end end
		table.insert(parts,table.concat(tokens,' '))
	end
	return if #parts>0 then table.concat(parts,', ')else 'none'
end
function Anchor.acceptedProperty(name)
	return name=='top'or name=='right'or name=='bottom'or name=='left'or name=='inset'or name:match('^inset%-block')~=nil or name:match('^inset%-inline')~=nil
		or name=='margin'or name:match('^margin%-')~=nil
		or ({width=true,height=true,['block-size']=true,['inline-size']=true,['min-width']=true,['min-height']=true,['max-width']=true,['max-height']=true,
			['min-block-size']=true,['min-inline-size']=true,['max-block-size']=true,['max-inline-size']=true,
			['align-self']=true,['justify-self']=true,['place-self']=true,['position-anchor']=true,['position-area']=true})[name]==true
end
function Anchor.name(value)
	local items=Components.parse(value)
	if not items or #items~=1 or items[1].Kind~='ident'then return nil end
	local name=items[1].Decoded
	return if name:sub(1,2)=='--'then name else nil
end
function Anchor.reference(value)
	local items=Components.parse(value)
	if not items or #items~=1 or items[1].Kind~='ident'then return nil end
	local word=items[1].Value
	return if word=='normal'or word=='none'or word=='auto'or word=='match-parent'then word else Anchor.name(value)
end
function Anchor.defaultName(style)
	local name=style.PositionAnchor
	if name=='none'then return nil end
	return if name=='normal'then(if style.PositionArea and style.PositionArea~='none'then 'auto'else nil)else name
end
function Anchor.names(value,scope)
	local items=Components.parse(value);if not items then return nil end
	if #items==1 and items[1].Kind=='ident'then
		if items[1].Value=='none'then return {}end
		if scope and items[1].Value=='all'then return 'all'end
	end
	local result={};local expect=true
	for _,item in items do
		if expect then
			local name=if item.Kind=='ident'then Anchor.name(item.Raw)else nil
			if not name then return nil end;table.insert(result,name);expect=false
		else if item.Kind~='delim'or item.Value~=','then return nil end;expect=true end
	end
	return if not expect and #result<=64 then result else nil
end
local function arguments(body,parseLength,kind)
	local head,after,delimiter=Syntax.scan(body,1,',');local fallback
	if delimiter~=''then fallback=parseLength(body:sub(after));if not fallback then return nil end end
	local items=Components.parse(head);if not items then return nil end
	local name,axis=nil,nil
	for _,item in items do
		local candidate=if item.Kind=='ident'then Anchor.name(item.Raw)else nil
		if candidate then if name then return nil end;name=candidate
		elseif not axis and item.Kind=='ident'and (if kind=='anchor'then sides[item.Value]else sizes[item.Value])then axis=item.Value
		elseif not axis and kind=='anchor'and item.Kind=='percentage'then axis=item.Value/100
		else return nil end
	end
	if kind=='anchor'and axis==nil then return nil end
	return {Kind=kind,Name=name,Side=axis,Fallback=fallback}
end
function Anchor.inset(value,parseLength)
	local body=value:match('^[Aa][Nn][Cc][Hh][Oo][Rr]%((.*)%)$');if not body then return nil end
	return arguments(body,parseLength,'anchor')
end
-- Preserve the expression until the positioned box's containing block and
-- acceptable anchors are known. Other length-bearing properties do not opt in.
function Anchor.expression(source,context,allowCoordinate,allowNegative,depth)
	depth=depth or 0;if #source>2048 or depth>16 then return nil end
	local items=Components.parse(source);if not items then return nil end
	local functions={};local valid=true
	local function scan(tokens)
		for _,token in tokens do
			if token.Kind=='function'and (token.Value=='anchor-size'or token.Value=='anchor')then
				if not token.Closed or token.Value=='anchor'and not allowCoordinate then valid=false;return end
				local open=token.Raw:find('(',1,true)
				local parsed=arguments(token.Raw:sub(open+1,-2),function(v)return Length.parse(v,context)or Anchor.expression(v,context,allowCoordinate,true,depth+1)end,token.Value)
				if not parsed then valid=false;return end
				table.insert(functions,{Start=token.Start,After=token.After,Value=parsed})
			elseif token.Items then scan(token.Items)end
		end
	end
	scan(items);if not valid or #functions==0 then return nil end
	local function substitute(resolve)
		local parts,start={},1
		for _,entry in functions do table.insert(parts,source:sub(start,entry.Start-1));table.insert(parts,resolve(entry.Value));start=entry.After end
		table.insert(parts,source:sub(start));return table.concat(parts)
	end
	if not Length.parse(substitute(function()return '0px'end),context)then return nil end
	return {Kind='anchor-expression',Source=source,Functions=functions,Context=context and table.clone(context)or {},Value=0,Percent=false,AllowNegative=allowNegative==true}
end
function Anchor.resolve(length,field,lookup,containing,style,offset,positioned,depth)
	if not length then return nil end
	depth=depth or 0;if depth>32 then return nil end
	if length.Kind=='anchor'then
		local resolved=if positioned then Anchor.coordinate(length,field,lookup,Anchor.defaultName(style),containing,style,offset)else length.Fallback
		return Anchor.resolve(resolved,field,lookup,containing,style,offset,positioned,depth+1)
	end
	if length.Kind~='anchor-expression'then return length end
	local parts,start={},1
	for _,entry in length.Functions do
		local fn=entry.Value;local a=positioned and lookup[fn.Name or Anchor.defaultName(style)]or nil;local result
		if fn.Kind=='anchor'then
			if positioned then result=Anchor.coordinate(fn,field,lookup,Anchor.defaultName(style),containing,style,offset)else result=fn.Fallback end
		elseif a then
			local side=fn.Side
			if not side then side=if field:find('Height')or field:find('Top')or field:find('Bottom')or field=='top'or field=='bottom'then 'height'else 'width'end
			if side~='width'and side~='height'then
				local self=side:sub(1,5)=='self-';local mode=if self then style.WritingMode else containing.Style and containing.Style.WritingMode
				local inline=side=='inline'or side=='self-inline';side=if inline~=(mode~='horizontal-tb'and mode~=nil)then 'width'else 'height'
			end
			result={Value=if side=='width'then a.Width else a.Height,Percent=false}
		else result=fn.Fallback end
		result=Anchor.resolve(result,field,lookup,containing,style,offset,positioned,depth+1)
		if not result then return nil end
		local serialized=Length.serialize(result)or string.format('%.12g',result.Value)..(if result.Percent then '%'else 'px')
		table.insert(parts,length.Source:sub(start,entry.Start-1));table.insert(parts,'('..serialized..')');start=entry.After
	end
	table.insert(parts,length.Source:sub(start))
	local result=Length.parse(table.concat(parts),length.Context)
	if result and not length.AllowNegative and Length.resolve(result,0)<0 then return {Value=0,Percent=false}end
	return result
end
function Anchor.usedStyle(style,lookup,containing,positioned,offset)
	local used=style
	local function copy()
		if used==style then used=table.clone(style);used.Margin=table.clone(style.Margin);used.Padding=table.clone(style.Padding)end
	end
	for _,field in {'Width','Height','MinWidth','MaxWidth','MinHeight','MaxHeight'}do
		local length=style[field]
		if length and length.Kind=='anchor-expression'then copy();used[field]=Anchor.resolve(length,field,lookup,containing,style,offset,positioned)end
		if length and length.PickerAnchor then
			local a=positioned and lookup[Anchor.defaultName(style)]or nil
			copy();used[field]={Value=if a then(if style.WritingMode and style.WritingMode~='horizontal-tb'then a.Height else a.Width)else 0}
		end
	end
	for index,length in style.MarginValues or{}do
		if type(length)=='table'and length.Kind=='anchor-expression'then
			copy();if used.MarginValues==style.MarginValues then used.MarginValues=table.clone(style.MarginValues)end
			local field=({'MarginTop','MarginRight','MarginBottom','MarginLeft'})[index]
			local result=Anchor.resolve(length,field,lookup,containing,style,offset,positioned)
			used.MarginValues[index]=result or 0
			used.Margin[index]=if result then Length.resolve(result,containing.Width)else 0
		end
	end
	return used
end
function Anchor.tries(value)
	local first=Components.parse(value)
	if first and #first==1 and first[1].Kind=='ident'and first[1].Value=='none'then return {}end
	local result,index={},1
	while index<=#value do
		local group,after,comma=Syntax.scan(value,index,',');index=after
		local items=Components.parse(group);if not items or #items==0 then return nil end
		local entry={}
		local area=PositionArea.parse(group)
		if area and area~='none'then entry.Area=area else for _,item in items do
			if item.Kind~='ident'then return nil end
			local name=Anchor.name(item.Raw);local token=item.Value
			if name then if entry.Name then return nil end;entry.Name=name
			elseif ({['flip-block']=true,['flip-inline']=true,['flip-start']=true,['flip-x']=true,['flip-y']=true})[token]and not entry[token]then entry[token]=true
			else return nil end
		end end
		table.insert(result,entry);if #result>8 or comma~=''and index>#value then return nil end
	end
	return if #result>0 then result else nil
end
function Anchor.variant(base,recipe,containing)
	local style=base
	if recipe.Name then
		local definition=base.PositionTryDefinitions and base.PositionTryDefinitions[recipe.Name]
		if not definition or not base.PositionTryResolve then return nil end
		style=base.PositionTryResolve(definition.Declarations)
	end
	local result=table.clone(style);result.Margin=table.clone(style.Margin);result.MarginAuto=table.clone(style.MarginAuto)
	result.MarginValues=table.clone(style.MarginValues)
	if recipe.Area then result.PositionArea=recipe.Area;return result end
	local map={top='top',right='right',bottom='bottom',left='left'}
	local function swap(a,b)
		for side,target in map do if target==a then map[side]=b elseif target==b then map[side]=a end end
	end
	local sidesByIndex={'top','right','bottom','left'}
	local blockStart=sidesByIndex[WritingMode.side(containing.Style,'block-start')]
	local inlineStart=sidesByIndex[WritingMode.side(containing.Style,'inline-start')]
	local opposite={top='bottom',bottom='top',left='right',right='left'}
	if recipe['flip-block']then swap(blockStart,opposite[blockStart])end
	if recipe['flip-inline']then swap(inlineStart,opposite[inlineStart])end
	if recipe['flip-start']then swap(blockStart,inlineStart);swap(opposite[blockStart],opposite[inlineStart])end
	if recipe['flip-x']then swap('left','right')end
	if recipe['flip-y']then swap('top','bottom')end
	result.PositionArea=PositionArea.flip(style.PositionArea or 'none',containing.Style or{},style,map)
	local indices={top=1,right=2,bottom=3,left=4}
	local function length(value,source,target)
		if type(value)~='table'then return value end
		local function transform(fn)
			local copy=table.clone(fn)
			if type(copy.Side)=='number'then
				if map[source]==opposite[source]then copy.Side=1-copy.Side end
			elseif copy.Side and map[copy.Side]then copy.Side=map[copy.Side]end
			return copy
		end
		if value.Kind=='anchor'then return transform(value)end
		if value.Kind=='anchor-expression'then
			local copy=table.clone(value);copy.Functions={}
			for _,fn in value.Functions do local entry=table.clone(fn);entry.Value=transform(fn.Value)
				if fn.Value.Kind=='anchor-size'and (source=='top'or source=='bottom')~=(target=='top'or target=='bottom')then
					local axis=entry.Value.Side
					entry.Value.Side=({width='height',height='width',block='inline',inline='block',['self-block']='self-inline',['self-inline']='self-block'})[axis]or axis
				end
				table.insert(copy.Functions,entry)
			end
			return copy
		end
		return value
	end
	for source,target in map do
		result['Inset'..target]=length(style['Inset'..source],source,target)
		local a,b=indices[source],indices[target]
		result.Margin[b]=style.Margin[a];result.MarginAuto[b]=style.MarginAuto[a];result.MarginValues[b]=length(style.MarginValues[a],source,target)
	end
	if (map.top=='left'or map.top=='right')then
		for _,prefix in {'','Min','Max'}do
			result[prefix..'Width']=length(style[prefix..'Height'],'top','left')
			result[prefix..'Height']=length(style[prefix..'Width'],'left','top')
		end
	end
	return result
end
function Anchor.tryKey(style)
	local function serialize(value,depth)
		if type(value)~='table'then return tostring(value)end
		if value.Source then
			local parts={value.Source}
			for _,field in {'FontSize','RootFontSize','ViewportWidth','ViewportHeight','ContainerWidth','ContainerHeight','WritingMode'}do table.insert(parts,tostring(value.Context and value.Context[field]))end
			return table.concat(parts,':')
		end
		if depth>32 then return ''end
		local entries={}
		for key,child in value do if key~='Context'then table.insert(entries,tostring(key)..':'..serialize(child,depth+1))end end
		table.sort(entries);return '{'..table.concat(entries,';')..'}'
	end
	local parts={style.PositionTryKey or '',style.Position or ''}
	for _,field in {'PositionAnchor','PositionArea','PositionTryOrder','PositionTryFallbacks','AlignSelf','JustifySelf','Width','Height','MinWidth','MaxWidth','MinHeight','MaxHeight','MarginValues','MarginAuto','Insettop','Insetright','Insetbottom','Insetleft'}do
		table.insert(parts,serialize(style[field],0))
	end
	return table.concat(parts,'|')
end
function Anchor.coordinate(length,inset,anchors,defaultName,containing,style,viewportOffset)
	if not length or length.Kind~='anchor'then return nil,false end
	local anchor=anchors[length.Name or defaultName];if not anchor then return length.Fallback,false end
	local horizontal=inset=='left'or inset=='right';local side=length.Side;local fraction
	local function reverse(source)
		return PositionArea.reverse(source,if horizontal then 'x'else 'y')
	end
	if type(side)=='number'then fraction=if reverse(anchor.Style or style)then 1-side else side
	elseif side=='center'then fraction=.5
	elseif side=='left'and horizontal or side=='top'and not horizontal then fraction=0
	elseif side=='right'and horizontal or side=='bottom'and not horizontal then fraction=1
	elseif side=='inside'then fraction=if inset=='left'or inset=='top'then 0 else 1
	elseif side=='outside'then fraction=if inset=='left'or inset=='top'then 1 else 0
	elseif side=='start'or side=='end'or side=='self-start'or side=='self-end'then
		local source=if side:sub(1,5)=='self-'then style else anchor.Style or style;local start=side=='start'or side=='self-start';fraction=if start~=reverse(source)then 0 else 1
	else return length.Fallback,false end
	local origin=if horizontal then containing.X else containing.Y;local space=if horizontal then containing.Width else containing.Height
	local coordinate=(if horizontal then anchor.X else anchor.Y)-(viewportOffset or 0)+(if horizontal then anchor.Width else anchor.Height)*fraction-origin
	return {Value=if inset=='right'or inset=='bottom'then space-coordinate else coordinate,Percent=false},true
end
return Anchor
