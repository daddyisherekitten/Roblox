--!strict
--!optimize 2
-- Resolve supported declarations from author rules and inline attributes.
local ElementProfile = require(script.Parent.Parent.HTML.ElementProfile)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local DocumentAccessors=require(script.Parent.Parent.DOM.DocumentAccessors)
local Properties = require(script.Parent.Properties)
local ResetProperties = require(script.Parent.ResetProperties)
local Syntax = require(script.Parent.Syntax)
local QuirkyValues=require(script.Parent.QuirkyValues)
local DocumentMode=require(script.Parent.Parent.DOM.DocumentMode)
local WorkContext=require(script.Parent.Parent.WorkContext)
local InitialLetter=require(script.Parent.InitialLetter)
local WhiteSpace=require(script.Parent.Parent.Layout.WhiteSpace)
local TextIndent=require(script.Parent.TextIndent)
local TextTransform=require(script.Parent.Parent.Layout.TextTransform)
local Directionality=require(script.Parent.Directionality)
local WritingMode=require(script.Parent.WritingMode)
local FontMetrics = require(script.Parent.Parent.Layout.FontMetrics)
local BoxShadow = require(script.Parent.BoxShadow)
local ObjectPosition = require(script.Parent.ObjectPosition)
local ObjectViewBox = require(script.Parent.ObjectViewBox)
local Color = require(script.Parent.Color)
local AnimationColors=require(script.Parent.AnimationColors)
local FontFamily = require(script.Parent.FontFamily)
local CompositeValues = require(script.Parent.CompositeValues)
local LengthExpression = require(script.Parent.LengthExpression)
local LengthUnits = require(script.Parent.LengthUnits)
local ControlDefaults = require(script.Parent.Parent.Controls.Defaults)
local AttributeValues=require(script.Parent.Parent.HTML.AttributeValues)
local AttributeStore=require(script.Parent.Parent.DOM.AttributeStore)
local Cursor = require(script.Parent.Cursor)
local Filter = require(script.Parent.Filter)
local Variables = require(script.Parent.Variables)
local Background = require(script.Parent.Background)
local Transform2D = require(script.Parent.Transform2D)
local Motion = require(script.Parent.Motion)
local AdvancedVisual = require(script.Parent.AdvancedVisual)
local FontFeatures = require(script.Parent.FontFeatures)
local Counters = require(script.Parent.Counters)
local CounterStyles = require(script.Parent.CounterStyles)
local InlineStyle = {}
local GridValues = require(script.Parent.GridValues)
local ColumnRuleInsets = require(script.Parent.ColumnRuleInsets)
local LayoutValues = require(script.Parent.LayoutValues)
local AlignmentValues=require(script.Parent.AlignmentValues)
local ColorScheme = require(script.Parent.ColorScheme)
local VisualValues = require(script.Parent.VisualValues)
local ScrollValues = require(script.Parent.ScrollValues)
local ScrollTimeline = require(script.Parent.ScrollTimeline)
local AnchorPosition = require(script.Parent.AnchorPosition)
local CascadeLayers=require(script.Parent.CascadeLayers)
local tableRoles={table="table",["table-row"]="row",["table-cell"]="cell",["table-row-group"]="group",
	["table-header-group"]="group",["table-footer-group"]="group",["table-caption"]="caption"}
local tableDisplays={table="table",row="table-row",cell="table-cell",group="table-row-group",caption="table-caption",column="table-column",["column-group"]="table-column-group"}
local NO_DECORATIONS = table.freeze({})
local BORDER_WIDTHS = table.freeze({thin = 1, medium = 3, thick = 5})
local BORDER_STYLES = table.freeze({solid = true, inset = true, outset = true, groove = true, ridge = true, none = true, hidden = true, dashed = true, dotted = true, double = true})
local OUTLINE_STYLES = table.freeze({auto = true, solid = true, none = true, dashed = true, dotted = true, double = true})
local INSET_FIELDS = table.freeze({"Insettop", "Insetright", "Insetbottom", "Insetleft"})
local DECORATION_STYLES = table.freeze({solid = true, double = true, dotted = true, dashed = true, wavy = true})
local OVERFLOW_VALUES = table.freeze({visible = true, hidden = true, clip = true, auto = true, scroll = true})
-- The catalog is immutable. Select inherited fields once, not for every node.
local inheritedFields = {}
for _, property in Properties do
	if property.Inherited then table.insert(inheritedFields, property.Field) end
end
local function decimal(value: string): number?
	if not value:match("^%+?%d+$") and not value:match("^%+?%d*%.%d+$") then return nil end
	local parsed = tonumber(value)
	return if parsed and parsed <= 100000 then parsed else nil
end

function InlineStyle.length(value: string, context: any?, allowNegative: boolean?): any
	local parsed=LengthExpression.parse(value, context)
	if parsed and not allowNegative and ((not parsed.Percent and parsed.Value<0)
		or (parsed.Percent and parsed.Expression==nil and parsed.Value<0)) then return nil end
	return parsed
end

local function gapLength(value: string,context: any?): any
 local parsed=InlineStyle.length(value,context,true);if not parsed then return nil end
 local fn=value:match('^%s*([%a]+)%s*%(')
 if not parsed.Expression and parsed.Value<0 then
  -- Negative literals are invalid; a valid math function is clamped in the
  -- property's nonnegative range after computation.
  if fn~='calc'and fn~='min'and fn~='max'and fn~='clamp'then return nil end
  parsed=table.clone(parsed);parsed.Value=0
 end
 return if parsed.Percent then parsed else math.max(0,parsed.Value)
end

local function contextualLength(value: string): boolean
	local lower=value:lower()
	for unit in lower:gmatch('[%d%.]([%a]+)%f[%W]')do if LengthUnits.font(unit)or LengthUnits.contextual(unit)then return true end end
	return false
end

local function splitTokens(value: string): any
	local result, cursor = {}, 1
	while cursor <= #value do
		local token, nextCursor = Syntax.scan(value, cursor, " \t\r\n")
		cursor = nextCursor
		if token ~= "" then table.insert(result, token) end
	end
	return result
end

local function spacing(value: string, allowAuto: boolean?, context: any?): any
	local values = {}
	for _, part in splitTokens(value) do
		if allowAuto and part == "auto" then table.insert(values, "auto"); continue end
		local length = InlineStyle.length(part, context, allowAuto)or (allowAuto and AnchorPosition.expression(part,context,false,true))
		if not length then return nil end
		if not allowAuto and LengthExpression.resolve(length,100) < 0 then return nil end
		table.insert(values, if length.Percent or length.Kind=='anchor-expression'then length else length.Value)
	end
	if #values < 1 or #values > 4 then return nil end
	return { values[1], values[2] or values[1], values[3] or values[1], values[4] or values[2] or values[1] }
end

local function lineHeight(value: string, context: any?): any
	if value == "normal" then return { Kind = "normal" } end
	local parsedNumber = decimal(value)
	if parsedNumber then return {Kind="number",Value=parsedNumber} end
	local parsed=InlineStyle.length(value,context)
	if not parsed then return nil end
	if parsed.Percent then
		return if parsed.Expression then {Kind="length",Length=parsed} else {Kind="percent",Value=parsed.Value}
	end
	local pixels=LengthExpression.resolve(parsed,if context then context.FontSize or 16 else 16)
	return if pixels >= 0 then {Kind="px",Value=pixels} else nil
end

local function axisSpacing(value: string, allowAuto: boolean?, context: any?): any
	local values = {}
	for _, part in splitTokens(value) do
		if allowAuto and part == "auto" then table.insert(values, "auto")
		else
			local length = InlineStyle.length(part, context, allowAuto)or (allowAuto and AnchorPosition.expression(part,context,false,true))
			if not length or (not allowAuto and LengthExpression.resolve(length, 100) < 0) then return nil end
			table.insert(values, if length.Percent or length.Kind=='anchor-expression'then length else length.Value)
		end
	end
	if #values < 1 or #values > 2 then return nil end
	return {values[1], values[2] or values[1]}
end

local function radiusLength(value: string,context: any?): any
	local parsed=InlineStyle.length(value,context)
	-- A zero percentage is still a percentage computed value; losing its
	-- lexical type makes commit/cancel turn an animated 0% corner into 0px.
	if parsed and parsed.Value==0 and not parsed.Expression and value:sub(-1)=="%"then parsed.Percent=true end
	return parsed
end
local function radiusParts(value: string, context: any?): any
	local horizontalText, verticalText = value:match("^(.-)%s*/%s*(.-)$")
	if not horizontalText then horizontalText = value end
	if verticalText and verticalText:find("/", 1, true) then return nil end
	local function read(text: string): any
		local values = {}
		for _, token in splitTokens(text) do
			local length = radiusLength(token, context)
			if not length or LengthExpression.resolve(length,100)<0 then return nil end
			table.insert(values, length)
		end
		if #values < 1 or #values > 4 then return nil end
		return {values[1], values[2] or values[1], values[3] or values[1], values[4] or values[2] or values[1]}
	end
	local x = read(horizontalText)
	local y = read(verticalText or horizontalText)
	if not x or not y then return nil end
	local result = {}
	for index = 1, 4 do result[index] = {X=x[index], Y=y[index]} end
	return result
end
local function copyRadii(value: any): any
	local result={}
	for index,corner in value do
		result[index]={X=table.clone(corner.X),Y=table.clone(corner.Y)}
	end
	return result
end

local function generatedContent(value: string): any
	local trimmed = value:match("^%s*(.-)%s*$") or ""
	if trimmed == "normal" or trimmed == "none" then return {Mode=trimmed} end
	local result, index = {}, 1
	while index <= #trimmed do
		local spaces = trimmed:match("^%s*", index) or ""; index += #spaces
		if index > #trimmed then break end
		local quote = trimmed:sub(index,index)
		if quote == '"' or quote == "'" then
			local finish = index + 1
			while finish <= #trimmed and trimmed:sub(finish,finish) ~= quote do finish += 1 end
			if finish > #trimmed then return nil end
			table.insert(result,{Kind="text",Value=trimmed:sub(index+1,finish-1)})
			index = finish + 1
		else
			local counter,nextCounter=Counters.content(trimmed,index)
			if counter then table.insert(result,counter);index=nextCounter :: number;continue end
			local name, finish = trimmed:match("^attr%(%s*([%w_:%-]+)%s*%)()", index)
			if name then table.insert(result,{Kind="attr",Name=name:lower()}); index = finish
			else
				local token,nextIndex=trimmed:match("^(open%-quote)()",index)
				if not token then token,nextIndex=trimmed:match("^(close%-quote)()",index) end
				if not token then token,nextIndex=trimmed:match("^(no%-open%-quote)()",index) end
				if not token then token,nextIndex=trimmed:match("^(no%-close%-quote)()",index) end
				if not token then return nil end
				table.insert(result,{Kind="quote",Value=token});index=nextIndex
			end
		end
		if #result > 16 then return nil end
	end
	return if #result > 0 then result else nil
end

local function borderWidth(value: string, context: any?): number?
	local parsed = InlineStyle.length(value, context)
	return if parsed and not parsed.Percent then parsed.Value else nil
end

local function border(value: string, context: any?, styles: any?): any
	local parsed, seen = {Width = 3, Style = "none", Color = "currentcolor"}, {}
	local cursor = 1
	while cursor <= #value do
		local token, nextCursor = Syntax.scan(value, cursor, " \t\r\n")
		cursor = nextCursor
		if token == "" then continue end
		local width = BORDER_WIDTHS[token] or borderWidth(token, context)
		local shade, alpha = Color.parse(token)
		local field, result
		if width then field, result = "Width", width
		elseif (styles or BORDER_STYLES)[token] then field, result = "Style", token
		elseif shade then field, result = "Color", shade; parsed.Alpha = alpha
		else return nil end
		if seen[field] then return nil end
		seen[field], parsed[field] = true, result
	end
	return if next(seen) then parsed else nil
end

local function flexBasis(value: string, context: any?): any
	if value == "auto" or value == "content" then return value end
	return InlineStyle.length(value, context)
end

local function flex(value: string, context: any?): any
	if value == "none" then return {Grow = 0, Shrink = 0, Basis = "auto"} end
	if value == "auto" then return {Grow = 1, Shrink = 1, Basis = "auto"} end
	if value == "initial" then return {Grow = 0, Shrink = 1, Basis = "auto"} end
	local tokens = {}
	for _, token in splitTokens(value) do table.insert(tokens, token) end
	if #tokens == 0 or #tokens > 3 then return nil end
	local grow, shrink, basis = nil, nil, nil
	local index = 1
	while index <= #tokens do
		local number = decimal(tokens[index])
		if number and grow == nil then
			grow = number
			local nextNumber = if tokens[index + 1] then decimal(tokens[index + 1]) else nil
			if nextNumber then shrink = nextNumber; index += 1 end
		elseif basis == nil then
			basis = flexBasis(tokens[index], context)
			if basis == nil then return nil end
		else return nil end
		index += 1
	end
	return {Grow = grow or 1, Shrink = shrink or 1, Basis = basis or {Value = 0, Percent = true}}
end

local function parseValue(property: any, value: string, context: any?): (any, boolean)
	if property.Kind=='corner-shapes' or property.Kind=='repeat-axis' or property.Kind=='clip-rect' or property.Kind=='mask-shorthand' or property.Kind:match('^shadow%-')then
		return VisualValues.parse(property.Kind,value,function(part,negative)return InlineStyle.length(part,context,negative)end)
	end
	if property.BorderComponents then
		local single = table.clone(property)
		single.BorderComponents = false
		local parts, cursor = {}, 1
		while cursor <= #value do
			local token, nextCursor = Syntax.scan(value, cursor, " \t\r\n")
			cursor = nextCursor
			if token == "" then continue end
			local parsed, accepted = parseValue(single, token, context)
			if not accepted or #parts == 4 then return nil, false end
			table.insert(parts, parsed)
		end
		if #parts == 0 then return nil, false end
		return {parts[1], parts[2] or parts[1], parts[3] or parts[1], parts[4] or parts[2] or parts[1]}, true
	end
	local kind = property.Kind
	if kind=='text-box-edge'then
		if value=='auto'then return {Start='text',End='text'},true end
		local parts=splitTokens(value);local first,last=parts[1],parts[2]or parts[1]
		if (first=='text'or first=='cap'or first=='ex')and #parts<=2 then
			if #parts==1 and first~='text'then last='alphabetic'end
			if last=='text'or last=='alphabetic'then return {Start=first,End=last},true end
		end;return nil,false
	end
	if kind=='initial-letter'then local result=InitialLetter.parse(value);return result,result~=nil end
	if kind=='margin-trim' or kind=='min-intrinsic-sizing' or kind=='color-scheme' or kind=='tracks-alignment' or kind=='grid-auto-position' then
		return LayoutValues.parse(kind,value)
	elseif kind == "accent-color" then
		if value == "auto" then return {Auto=true},true end
		local shade,alpha=Color.parse(value)
		return if shade then {Color=shade,Alpha=alpha} else nil,shade~=nil
	elseif kind == "scrollbar-color" then
		if value == "auto" then return {Auto=true},true end
		local parts=splitTokens(value)
		if #parts~=2 then return nil,false end
		local thumb,thumbAlpha=Color.parse(parts[1]);local track,trackAlpha=Color.parse(parts[2])
		return if thumb and track then {Thumb=thumb,ThumbAlpha=thumbAlpha,Track=track,TrackAlpha=trackAlpha} else nil,thumb~=nil and track~=nil
	elseif kind == "text-wrap" then
		local mode,wrapStyle=nil,nil
		for _,token in splitTokens(value) do
			if (token=="wrap" or token=="nowrap") and not mode then mode=token
			elseif (token=="auto" or token=="stable") and not wrapStyle then wrapStyle=token
			else return nil,false end
		end
		return {Mode=mode or "wrap",Style=wrapStyle or "auto"},mode~=nil or wrapStyle~=nil
	elseif kind == "list-style-image" then
		if value=="none" then return nil,true end
		local quote,source=value:match("^url%(%s*(['\"]?)(.-)%1%s*%)$")
		return source,quote~=nil and source~=""
	elseif kind == "caret-color" then
		if value=="auto" then return {Auto=true},true end
		local shade,alpha=Color.parse(value)
		return if shade then {Color=shade,Alpha=alpha} else nil,shade~=nil
	elseif kind == "hyphen-character" then
		if value=="auto" then return "-",true end
		local text=Syntax.string(value)
		return text,text~=nil
	elseif kind == "hyphen-limit" then
		if value=="auto" then return {5,2,2},true end
		local values={}
		for _,token in splitTokens(value)do
			if token=="auto"then table.insert(values,"auto")else
				local n=tonumber(token);if not token:match("^[+%-]?%d+$")or not n or n<0 or n>=math.huge then return nil,false end
				table.insert(values,n)
			end
		end
		if #values<1 or #values>3 then return nil,false end
		return {values[1],values[2] or "auto",values[3] or values[2] or "auto"},true
	elseif kind == "emphasis-style" then
		if value=="none" then return nil,true end
		local text=Syntax.string(value)
		if text~=nil then local _,last=utf8.graphemes(text)();return {Mark=if last then text:sub(1,last)else '',String=text},true end
		local fill,shape=nil,nil
		for _,token in splitTokens(value:lower()) do
			if (token=="filled" or token=="open") and not fill then fill=token
			elseif ({dot=true,circle=true,["double-circle"]=true,triangle=true,sesame=true})[token] and not shape then shape=token
			else return nil,false end
		end
		if not fill and not shape then return nil,false end
		local automatic=shape==nil;shape=shape or "circle";fill=fill or "filled"
		local marks={dot={filled="•",open="◦"},circle={filled="●",open="○"},["double-circle"]={filled="◉",open="◎"},triangle={filled="▲",open="△"},sesame={filled="﹅",open="﹆"}}
		return {Fill=fill,Shape=shape,Mark=marks[shape][fill],AutomaticShape=automatic},true
	elseif kind == "text-emphasis" then
		local color,colorAlpha,styleParts=nil,nil,{}
		for _,token in splitTokens(value) do
			local shade,alpha=Color.parse(token)
			if shade and not color then color,colorAlpha=shade,alpha else table.insert(styleParts,token) end
		end
		local emphasis,accepted=parseValue({Kind="emphasis-style"},table.concat(styleParts," "),context)
		if #styleParts==0 and color then accepted=true end
		return if accepted then {Style=emphasis,Color=color or 'currentcolor',Alpha=colorAlpha or 1} else nil,accepted
	elseif kind == "emphasis-position" then
		local vertical,horizontal=nil,nil
		for _,token in splitTokens(value) do
			if (token=="over" or token=="under") and not vertical then vertical=token
			elseif (token=="left" or token=="right") and not horizontal then horizontal=token
			else return nil,false end
		end
		return {Vertical=vertical or "over",Horizontal=horizontal or "right"},vertical~=nil
	elseif kind == "quotes" then
		if value=="auto" then return {{"“","”"},{"‘","’"}},true elseif value=="none" then return {},true end
		local strings,index={},1
		while index<=#value do
			local spaces=value:match("^%s*",index) or "";index+=#spaces;if index>#value then break end
			local quote=value:sub(index,index);if quote~="'" and quote~='"' then return nil,false end
			local finish=index+1;while finish<=#value and value:sub(finish,finish)~=quote do finish+=1 end
			if finish>#value then return nil,false end;table.insert(strings,value:sub(index+1,finish-1));index=finish+1
		end
		if #strings<2 or #strings%2~=0 or #strings>16 then return nil,false end
		local pairs={};for i=1,#strings,2 do table.insert(pairs,{strings[i],strings[i+1]}) end;return pairs,true
	elseif kind == "axis-enum" then
		local parts=splitTokens(value);if #parts<1 or #parts>2 then return nil,false end
		for _,token in parts do if not property.Allowed[token] then return nil,false end end
		return {parts[1],parts[2] or parts[1]},true
	elseif kind == "snap-type" then
		if value=="none" then return {Axis="none",Strictness="proximity"},true end
		local axis,strictness=nil,"proximity"
		for _,token in splitTokens(value) do if ({x=true,y=true,block=true,inline=true,both=true})[token] and not axis then axis=token elseif (token=="mandatory" or token=="proximity") then strictness=token else return nil,false end end
		return if axis then {Axis=axis,Strictness=strictness} else nil,axis~=nil
	elseif kind == "snap-align" then
		local parts=splitTokens(value);if #parts<1 or #parts>2 then return nil,false end
		for _,token in parts do if not ({none=true,start=true,center=true,["end"]=true})[token] then return nil,false end end
		return {Block=parts[1],Inline=parts[2] or parts[1]},true
	elseif kind == "scroll-spacing" then
		local parsed=spacing(value,false,context)
		if not parsed then
			local values={};for _,part in splitTokens(value) do local length=InlineStyle.length(part,context,property.AllowNegative);if not length then return nil,false end;table.insert(values,length) end
			if #values<1 or #values>4 then return nil,false end;parsed={values[1],values[2] or values[1],values[3] or values[1],values[4] or values[2] or values[1]}
		end
		return parsed,true
	elseif kind == "scroll-axis-spacing" then
		local values={};for _,part in splitTokens(value) do local length=InlineStyle.length(part,context,property.AllowNegative);if not length then return nil,false end;table.insert(values,length) end
		if #values<1 or #values>2 then return nil,false end;return {values[1],values[2] or values[1]},true
	elseif kind == "scroll-length" then
		local parsed=InlineStyle.length(value,context,property.AllowNegative)
		return parsed,parsed~=nil and (property.AllowPercent or not parsed.Percent)
	elseif kind == "positive-integer" then
		local n=tonumber(value);return n,n~=nil and n%1==0 and n>=1 and n<=1000
	elseif kind == "column-count" then
		if value=="auto" then return nil,true end;local n=tonumber(value);return n,n~=nil and n%1==0 and n>=1 and n<=32
	elseif kind == "column-width" then
		if value=="auto" then return nil,true end;local parsed=InlineStyle.length(value,context);return parsed,parsed~=nil and LengthExpression.resolve(parsed,100)>0
	elseif kind == "column-height" then
		if value=="auto" then return nil,true end
		local parsed=InlineStyle.length(value,context)
		return parsed,parsed~=nil and not parsed.Percent and LengthExpression.resolve(parsed,100)>=0
	elseif kind == "column-rule-inset" then
		local parsed=ColumnRuleInsets.parse(value,context)
		return parsed,parsed~=nil
	elseif kind == "columns" then
		local base,heightPart=value:match('^(.-)%s*/%s*(.-)$')
		local parts=splitTokens(base or value)
		if #parts<1 or #parts>2 then return nil,false end
		local count,columnWidth,columnHeight=nil,nil,nil
		for _,token in parts do
			if token=='auto' then continue end
			local n=tonumber(token)
			if n and n%1==0 and n>=1 and n<=32 and not count then count=n
			else local parsed=InlineStyle.length(token,context);if not parsed or parsed.Percent or LengthExpression.resolve(parsed,100)<=0 or columnWidth then return nil,false end;columnWidth=parsed end
		end
		if heightPart then
			local accepted;columnHeight,accepted=parseValue({Kind='column-height'},heightPart,context)
			if not accepted then return nil,false end
		end
		return {Count=count,Width=columnWidth,Height=columnHeight},true
	elseif kind == "line-clamp" then
		if value=="none" then return nil,true end;local n=tonumber(value);return n,n~=nil and n%1==0 and n>=1 and n<=100
	elseif kind == "caret" then
		local color,alpha,shape=nil,nil,nil
		for _,token in splitTokens(value) do
			if ({auto=true,bar=true,block=true,underscore=true})[token] and not shape then shape=token
			else local shade,a=Color.parse(token);if not shade or color then return nil,false end;color,alpha=shade,a end
		end
		return {Color=color,Alpha=alpha,Shape=shape or "auto"},color~=nil or shape~=nil
	elseif kind == "background-image" then
		local parsed=Background.images(value,function(part: string, allowNegative: boolean?) return InlineStyle.length(part,context,allowNegative) end)
		return parsed,parsed~=nil
	elseif kind == "background-size" then
		local parsed=Background.sizes(value,function(part: string, allowNegative: boolean?) return InlineStyle.length(part,context,allowNegative) end)
		return parsed,parsed~=nil
	elseif kind == "background-position" then
		local parsed=Background.positions(value,function(part: string, allowNegative: boolean?) return InlineStyle.length(part,context,allowNegative) end)
		return parsed,parsed~=nil
	elseif kind == "background-position-axis" then
		local parsed=Background.axisPositions(value,property.Axis,function(part: string,allowNegative: boolean?) return InlineStyle.length(part,context,allowNegative) end)
		return parsed,parsed~=nil
	elseif kind == "background-repeat" then
		local parsed=Background.repeats(value);return parsed,parsed~=nil
	elseif kind == "background-box" then
		local parsed=Background.boxes(value);return parsed,parsed~=nil
	elseif kind == "enum-list" then
		local result={}
		for part in value:gmatch("[^,]+") do
			part=part:match("^%s*(.-)%s*$") or ""
			if not property.Allowed[part] then return nil,false end
			table.insert(result,part)
		end
		return result,#result>0 and #result<=16
	elseif kind == "background" then
		local parsed=Background.shorthand(value,function(part: string, allowNegative: boolean?) return InlineStyle.length(part,context,allowNegative) end)
		return parsed,parsed~=nil
	elseif kind == "transform" then
		local parsed=Transform2D.parse(value,function(part: string,allowNegative: boolean?) return InlineStyle.length(part,context,allowNegative) end)
		return parsed,parsed~=nil
	elseif kind == "transform-origin" then
		local parsed=Transform2D.parseOrigin(value,function(part: string,allowNegative: boolean?) return InlineStyle.length(part,context,allowNegative) end)
		return parsed,parsed~=nil and not (property.NoZ and parsed.Z)
	elseif kind == "individual-transform" then
		return Transform2D.parseIndividual(property.TransformKind,value,function(part: string,allowNegative: boolean?) return InlineStyle.length(part,context,allowNegative) end)
	elseif kind == "transition" then local parsed=Motion.transition(value);return parsed,parsed~=nil
	elseif kind == "animation" then local parsed=Motion.animation(value);return parsed,parsed~=nil
	elseif kind == "transition-property" then local parsed=Motion.list(value,"transition-property");return parsed,parsed~=nil
	elseif kind == "animation-name" then local parsed=Motion.list(value,"animation-name");return parsed,parsed~=nil
	elseif kind == "motion-time" then local parsed=Motion.list(value,"time");return parsed,parsed~=nil
	elseif kind == "motion-delay" then local parsed=Motion.list(value,"delay");return parsed,parsed~=nil
	elseif kind == "motion-timing" then local parsed=Motion.list(value,"timing");return parsed,parsed~=nil
	elseif kind == "motion-iteration" then local parsed=Motion.list(value,"iteration");return parsed,parsed~=nil
	elseif kind == "motion-direction" then local parsed=Motion.list(value,"direction");return parsed,parsed~=nil
	elseif kind == "motion-fill" then local parsed=Motion.list(value,"fill");return parsed,parsed~=nil
	elseif kind == "motion-play" then local parsed=Motion.list(value,"play");return parsed,parsed~=nil
	elseif kind == "motion-composition" then local parsed=Motion.list(value,"composition");return parsed,parsed~=nil
	elseif kind == "transition-behavior" then local parsed=Motion.list(value,"transition-behavior");return parsed,parsed~=nil
	elseif kind == "contain" then local parsed=AdvancedVisual.contain(value);return parsed,parsed~=nil
	elseif kind == "ident-list" then local parsed=AdvancedVisual.names(value);return parsed,parsed~=nil
	elseif kind == 'anchor-names'or kind=='anchor-scope'then local parsed=AnchorPosition.names(value,kind=='anchor-scope');return parsed,parsed~=nil
	elseif kind == "scroll-timeline-names" then local parsed=ScrollValues.names(value);return parsed,parsed~=nil
	elseif kind == "scroll-timeline-axes" then local parsed=ScrollValues.axes(value);return parsed,parsed~=nil
	elseif kind == "clip-margin" then return ScrollValues.clip(value,context)
	elseif kind == "scroll-timeline-shorthand" or kind == "clip-margin-shorthand" then return nil,false
	elseif kind == "anchor-ref" then local parsed=AnchorPosition.reference(value);return parsed,parsed~=nil
	elseif kind == "position-area" then local parsed=AdvancedVisual.positionArea(value);return parsed,parsed~=nil
	elseif kind == "container" then local parsed=AdvancedVisual.container(value);return parsed,parsed~=nil
	elseif kind == "container-type"then local parsed=AdvancedVisual.containerType(value);return parsed,parsed~=nil
	elseif kind == "clip-path" or kind=='border-shape' then
		local parsed=AdvancedVisual.clipPath(value,function(part: string,allowNegative: boolean?)return InlineStyle.length(part,context,allowNegative)end)
		if kind=='border-shape' and parsed then
			if parsed.Kind~='circle' then return nil,false end
			parsed.ClosestSide=value:find('closest-side',1,true)~=nil
		end
		return parsed,value=="none" or parsed~=nil
	elseif kind == "mask" then local parsed=AdvancedVisual.mask(value);return parsed,value=="none" or parsed~=nil
	elseif kind == 'mask-border-source'then local parsed=AdvancedVisual.maskBorderSource(value);return parsed,value=='none'or parsed~=nil
	elseif kind == 'mask-border-shorthand'then local parsed=AdvancedVisual.maskBorder(value,function(part)return InlineStyle.length(part,context)end);return parsed,parsed~=nil
	elseif kind == "mask-border-fill" then
		local normalized=(value:lower():gsub("%s+"," "):match("^%s*(.-)%s*$"))
		return if normalized=="0 fill" or normalized=="fill 0" then "0 fill" else nil,normalized=="0 fill" or normalized=="fill 0"
	elseif kind == "mask-border-zero" then return if value=="0" then 0 else nil,value=="0"
	elseif kind == "border-image-source" then local parsed=AdvancedVisual.borderImageSource(value);return parsed,value=="none" or parsed~=nil
	elseif kind == "border-image" then local parsed=AdvancedVisual.borderImage(value,function(part)return InlineStyle.length(part,context)end);return parsed,parsed~=nil
	elseif kind == 'border-image-slice' then local parsed=AdvancedVisual.imageSlice(value);return parsed,parsed~=nil
	elseif kind == 'border-image-repeat'then local parsed=AdvancedVisual.imageRepeat(value);return parsed,parsed~=nil
	elseif kind == 'border-image-width' or kind=='border-image-outset'then local parsed=AdvancedVisual.imageWidths(value,kind=='border-image-outset',function(part)return InlineStyle.length(part,context)end);return parsed,parsed~=nil
	elseif kind == "number-sides" then local parsed=AdvancedVisual.numberSides(value);return parsed,parsed~=nil
	elseif kind == "offset-path" then local parsed=AdvancedVisual.offsetPath(value,function(part: string,allowNegative: boolean?)return InlineStyle.length(part,context,allowNegative)end);return parsed,value:lower()=="none" or parsed~=nil
	elseif kind == "offset-rotate" then local parsed=AdvancedVisual.offsetRotate(value);return parsed,parsed~=nil
	elseif kind == "offset-anchor" then
		if value=="auto" then return nil,true end
		local parsed=Transform2D.parseOrigin(value,function(part: string,allowNegative: boolean?)return InlineStyle.length(part,context,allowNegative)end);return parsed,parsed~=nil
	elseif kind == "offset-position" then
		if value=="normal" then return nil,true end
		local parsed=Transform2D.parseOrigin(value,function(part: string,allowNegative: boolean?)return InlineStyle.length(part,context,allowNegative)end);return parsed,parsed~=nil
	elseif kind == "offset" then
		local parsed=AdvancedVisual.offset(value,function(part: string,allowNegative: boolean?)return InlineStyle.length(part,context,allowNegative)end,function(part: string)return Transform2D.parseOrigin(part,function(token: string,allowNegative: boolean?)return InlineStyle.length(token,context,allowNegative)end)end)
		return parsed,parsed~=nil
	elseif kind == "timeline-list" then local parsed=AdvancedVisual.timelineList(value);return parsed,parsed~=nil
	elseif kind=='timeline-range'then local parsed=ScrollTimeline.ranges(value);return parsed,parsed~=nil
	elseif kind=='timeline-range-start'or kind=='timeline-range-end'then local parsed=ScrollTimeline.endpoints(value,kind=='timeline-range-end');return parsed,parsed~=nil
	elseif kind=='position-try-fallbacks'then local parsed=AnchorPosition.tries(value);return parsed,parsed~=nil
	elseif kind=='position-try-order'then local parsed=AnchorPosition.order(value);return parsed,parsed~=nil
	elseif kind=='position-try'then local parsed=AnchorPosition.shorthand(value);return parsed,parsed~=nil
	elseif kind == "shape-outside" then local parsed=AdvancedVisual.shape(value,function(part: string,allowNegative: boolean?)return InlineStyle.length(part,context,allowNegative)end);return parsed,value=="none" or parsed~=nil
	elseif kind == 'shape-threshold' then
		local percent=value:match('^(.-)%%$');local number=tonumber(percent or value)
		return if number then math.clamp(number/(if percent then 100 else 1),0,1) else nil,number~=nil
	elseif kind == 'object-view-box' then
		local parsed=ObjectViewBox.parse(value,function(part: string,negative: boolean?)return InlineStyle.length(part,context,negative)end)
		return parsed,value=='none' or parsed~=nil
	elseif kind == "scrollbar-gutter" then local parsed=AdvancedVisual.scrollbarGutter(value);return parsed,parsed~=nil
	elseif kind == "backdrop-filter" then local parsed=AdvancedVisual.backdrop(value);return parsed,value=="none" or parsed~=nil
	elseif kind == "length-none" then
		if value=="none" then return nil,true end;local parsed=InlineStyle.length(value,context);return parsed,parsed~=nil and not parsed.Percent and parsed.Value>0
	elseif kind == "length-pair" then
		local parts=splitTokens(value);if #parts<1 or #parts>2 then return nil,false end
		local first=InlineStyle.length(parts[1],context);local second=if parts[2] then InlineStyle.length(parts[2],context) else first
		return if first and second then {Width=first,Height=second} else nil,first~=nil and second~=nil
	end
	if kind == "grid" then local v=GridValues.parse(property.GridField or property.Field,value);return v,v~=nil end
	if kind == "composite" then
		local parsed = CompositeValues.parse(property.Field, value, function(p: any, v: string) return parseValue(p, v, context) end, Properties)
		return parsed, parsed ~= nil
	elseif kind == "opacity" then
		local percent = value:sub(-1) == "%"
		local raw = if percent then value:sub(1, -2) else value
		local negative = raw:sub(1, 1) == "-"
		local number = decimal(if negative then raw:sub(2) else raw)
		return if number then math.clamp(number * (if negative then -1 else 1) / (if percent then 100 else 1), 0, 1) else nil, number ~= nil
	elseif kind == "inset-shorthand" then
		local values = {}
		for _, token in splitTokens(value) do
			local parsed, accepted = parseValue({Kind = "inset"}, token, context)
			if not accepted then return nil, false end
			table.insert(values, parsed or false)
		end
		local n = #values
		return {values[1], values[if n >= 2 then 2 else 1], values[if n >= 3 then 3 else 1], values[if n == 4 then 4 elseif n >= 2 then 2 else 1]}, n >= 1 and n <= 4
	elseif kind == "inset" then
		if value == "auto" then return nil, true end
		if value:match('^anchor%(')then local parsed=AnchorPosition.inset(value,function(v)return InlineStyle.length(v,context,true)or AnchorPosition.expression(v,context,true,true)end);return parsed,parsed~=nil end
		local parsed = InlineStyle.length(value, context, true)or AnchorPosition.expression(value,context,true,true)
		return parsed, parsed ~= nil
	elseif kind == "logical-inset" then
		local values = {}
		for _, token in splitTokens(value) do
			local parsed, accepted = parseValue({Kind="inset"},token,context)
			if not accepted then return nil,false end
			table.insert(values,parsed or false)
		end
		return {values[1],values[2] or values[1]}, #values >= 1 and #values <= 2
	elseif kind == "z-index" then
		if value == "auto" then return nil, true end
		local number = if value:match("^[%+%-]?%d+$") then tonumber(value) else nil
		return number, number ~= nil and math.abs(number) <= 100000
	elseif kind == "flex-wrap" then
		local wrap,balance=nil,false
		for _,token in splitTokens(value) do
			if token=='balance' and not balance then balance=true
			elseif (token=='wrap' or token=='wrap-reverse' or token=='nowrap') and not wrap then wrap=token
			else return nil,false end
		end
		if wrap=='nowrap' and balance then return nil,false end
		return {Wrap=wrap or 'wrap',Balance=balance},wrap~=nil or balance
	elseif kind == "flex-flow" then
		local direction, parts = nil, {}
		for token in value:gmatch("%S+") do
			if Properties["flex-direction"].Allowed[token] and not direction then direction = token
			else table.insert(parts,token) end
		end
		local parsed,ok=parseValue({Kind='flex-wrap'},table.concat(parts,' '),context)
		if #parts>0 and not ok then return nil,false end
		return {Direction=direction or 'row',Wrap=if #parts>0 then parsed.Wrap else 'nowrap',Balance=#parts>0 and parsed.Balance or false},direction~=nil or #parts>0
	elseif kind == "order" then
		local number = if value:match("^[%+%-]?%d+$") then tonumber(value) else nil
		return number, number ~= nil and math.abs(number) <= 100000
	elseif kind == "flex-factor" then
		local number = decimal(value)
		return number, number ~= nil
	elseif kind == "flex-basis" then
		local basis = flexBasis(value, context)
		return basis, basis ~= nil
	elseif kind == "flex" then
		local parsed = flex(value, context)
		return parsed, parsed ~= nil
	elseif kind == "enum" then
		if property.Alignment then local parsed=AlignmentValues.parse(value,property.Field,property.Allowed);return parsed,parsed~=nil end
		return value, property.Allowed[value] == true
	elseif kind == "gap-side" then
		if value == "normal" then return 0, true end
		local parsed = gapLength(value, context)
		return parsed, parsed ~= nil
	elseif kind == "gap" or kind == "border-spacing" then
		local values = {}
		for _, token in splitTokens(value) do
			local length = if kind=='gap'then (if token=='normal'then 0 else gapLength(token,context))else InlineStyle.length(token, context)
			if length==nil or kind=='border-spacing'and length.Percent then return nil, false end
			table.insert(values, if kind=='gap'then length else length.Value)
		end
		return {values[1], values[2] or values[1]}, #values >= 1 and #values <= 2
	elseif kind == "overflow-wrap" then
		return value, value == "normal" or value == "break-word" or value == "anywhere"
	elseif kind == "visibility" then
		return value, value == "visible" or value == "hidden" or value == "collapse"
	elseif kind == "aspect-ratio" then
		if value == "auto" then return nil, true end
		local auto = false
		local ratio = value:match("^auto%s+(.+)$") or value:match("^(.+)%s+auto$")
		if ratio then auto, value = true, ratio end
		local first, second = value:match("^(.-)%s*/%s*(.-)$")
		local numerator = decimal((first or value):match("^%s*(.-)%s*$") :: string)
		local denominator = if second then decimal(second:match("^%s*(.-)%s*$") :: string) else 1
		if numerator == nil or denominator == nil then return nil, false end
		-- Degenerate ratios behave as auto, but remain valid declarations.
		if numerator == 0 or denominator == 0 then return nil, true end
		local quotient = numerator / denominator
		if quotient < 1 / 100000 or quotient > 100000 then return nil, false end
		return {Value = quotient, Auto = auto}, true
	elseif kind == "object-fit" then
		return value, value == "fill" or value == "contain" or value == "cover" or value == "none" or value == "scale-down"
	elseif kind == "object-position" then
		local parsed = ObjectPosition.parse(value, function(part: string) return InlineStyle.length(part, context, true) end)
		return parsed, parsed ~= nil
	elseif kind == "box-shadow" or kind == "text-shadow" then
		local parsed = BoxShadow.parse(value, function(part: string) return InlineStyle.length(part, context) end, kind == "text-shadow")
		return parsed, parsed ~= nil
	elseif kind == "box-sizing" then
		return value, value == "content-box" or value == "border-box"
	elseif kind == "vertical-align" then
		if value == "baseline" or value == "super" or value == "sub" or value == "middle"
			or value == "top" or value == "bottom" or value == "text-top" or value == "text-bottom" then return value, true end
		local parsed = InlineStyle.length(value, context, true)
		return parsed, parsed ~= nil
	elseif kind == "text-align-last" then
		return value, value == "auto" or value == "left" or value == "right" or value == "center" or value == "justify" or value == "start" or value == "end"
	elseif kind == "list-style-type" then
		local parsed=CounterStyles.value(value,true);return parsed,parsed~=nil
	elseif kind == "white-space" then
		local collapse,wrap=WhiteSpace.parse(value)
		return if collapse then WhiteSpace.serialize(collapse,wrap)else nil,collapse~=nil
	elseif kind == "tab-size" then
		local number = decimal(value)
		if number then return {Kind = "number", Value = number}, true end
		local pixels = borderWidth(value, context)
		return if pixels then {Kind = "px", Value = pixels} else nil, pixels ~= nil
	elseif kind == "overflow" then
		if property.Field ~= "Overflow" then return value, OVERFLOW_VALUES[value] == true end
		local parts = {}
		for token in value:gmatch("%S+") do
			if not OVERFLOW_VALUES[token] then return nil, false end
			table.insert(parts, token)
		end
		return parts, #parts >= 1 and #parts <= 2
	elseif kind == "min-size" or kind == "max-size" then
		if value == (if kind == "min-size" then "auto" else "none") then return nil, true end
		if value=='min-content'or value=='max-content'or value=='fit-content'then return {Intrinsic=value,Percent=false},true end
		local parsed = InlineStyle.length(value, context)or AnchorPosition.expression(value,context,false,false)
		return parsed, parsed ~= nil and (property.AllowPercent == true or not parsed.Percent)
	elseif kind == "filter" then
		local parsed=Filter.parse(value)
		return parsed,parsed ~= nil
	elseif kind == "cursor" then
		local parsed=Cursor.parse(value)
		return parsed,parsed ~= nil
	elseif kind == "outline" then
		local parsed = border(value, context, OUTLINE_STYLES)
		return parsed, parsed ~= nil
	elseif kind == "outline-style" then
		return value, OUTLINE_STYLES[value] == true
	elseif kind == "border" then
		local parsed = border(value, context)
		return parsed, parsed ~= nil
	elseif kind == "border-radius" then
		local parsed=radiusParts(value,context);return parsed,parsed~=nil
	elseif kind == "corner-radius" then
		local tokens=splitTokens(value)
		if #tokens<1 or #tokens>2 or value:find("/",1,true) then return nil,false end
		local x,y=radiusLength(tokens[1],context),radiusLength(tokens[2] or tokens[1],context)
		return if x and y then {X=x,Y=y} else nil,x~=nil and y~=nil
	elseif kind == "content" then
		local parsed=generatedContent(value);return parsed,parsed~=nil
	elseif kind == "counter-reset" then
		local parsed=Counters.parse(value,0,true);return parsed,parsed~=nil
	elseif kind == "counter-increment" then
		local parsed=Counters.parse(value,1);return parsed,parsed~=nil
	elseif kind == "counter-set" then
		local parsed=Counters.parse(value,0);return parsed,parsed~=nil
	elseif kind == "logical-spacing" then
		local parsed=axisSpacing(value,property.Field=="Margin",context);return parsed,parsed~=nil
	elseif kind == "logical-border-width" or kind == "logical-border-style" or kind == "logical-border-color" then
		local result={}
		for _,token in splitTokens(value) do
			if #result==2 then return nil,false end
			if kind=="logical-border-width" then
				local parsed=BORDER_WIDTHS[token] or borderWidth(token,context)
				if not parsed then return nil,false end
				table.insert(result,parsed)
			elseif kind=="logical-border-style" then
				if not BORDER_STYLES[token] then return nil,false end
				table.insert(result,token)
			else
				local shade,alpha=Color.parse(token)
				if not shade then return nil,false end
				table.insert(result,{Color=shade,Alpha=alpha})
			end
		end
		return result,#result>=1
	elseif kind == "border-width" or kind == "spacing-side" then
		if kind == "spacing-side" then
			local parsed = spacing(value, property.Field == "Margin", context)
			return if parsed then parsed[1] else nil, parsed ~= nil and #splitTokens(value)==1
		end
		local parsed = if property.Field == "BorderWidth" or property.Field == "OutlineWidth" then BORDER_WIDTHS[value] or borderWidth(value, context) else borderWidth(value, context)
		return parsed, parsed ~= nil
	elseif kind == "border-style" then
		return value, BORDER_STYLES[value] == true
	elseif kind == "decoration-style" then
		return value, DECORATION_STYLES[value] == true
	elseif kind == "border-color" or kind == "decoration-color" or kind == "color" then
		local shade, alpha = Color.parse(value)
		return if shade then {Color = shade, Alpha = alpha} else nil, shade ~= nil
	elseif kind == "length" then
		if value == "auto" then return nil, true end
		if (property.Field=='Width'or property.Field=='Height')and(value=='min-content'or value=='max-content'or value=='fit-content')then return {Intrinsic=value,Percent=false},true end
		local sizeField=property.Field=='Width'or property.Field=='Height'
		local parsed = InlineStyle.length(value, context, property.AllowNegative)or (if sizeField then AnchorPosition.expression(value,context,false,false)else nil)
		return parsed, parsed ~= nil and (property.AllowPercent == true or not parsed.Percent)
	elseif kind == "font-size" then
		if value == "smaller" or value == "larger" then return value, true end
		local fontContext=if context then {FontSize=context.ParentFontSize,RootFontSize=context.FontRootSize,
			ViewportWidth=context.ViewportWidth,ViewportHeight=context.ViewportHeight,ContainerWidth=context.ContainerWidth,ContainerHeight=context.ContainerHeight,WritingMode=context.WritingMode} else nil
		local parsed = InlineStyle.length(value, fontContext)
		return if parsed then parsed.Value else nil, parsed ~= nil and not parsed.Percent and parsed.Value >= 0 and parsed.Value <= 100
	elseif kind == "spacing" then
		local parsed = spacing(value, property.Field == "Margin", context)
		return parsed, parsed ~= nil
	elseif kind == "line-height" then
		local parsed = lineHeight(value, context)
		return parsed, parsed ~= nil
	elseif kind == "text-align" then
		return value, value == "left" or value == "center" or value == "right" or value == "justify" or value == "start" or value == "end"
	elseif kind == "text-transform" then
		local parsed=TextTransform.parse(value);return parsed,parsed~=nil
	elseif kind=='text-indent'then
		local parsed=TextIndent.parse(splitTokens(value),function(part)return InlineStyle.length(part,context,true)end)
		return parsed,parsed~=nil
	elseif kind=='underline-position'then
		if value=='auto'then return value,true end
		local base,side=nil,nil
		for _,token in splitTokens(value)do
			if (token=='under'or token=='from-font')and not base then base=token
			elseif (token=='left'or token=='right')and not side then side=token
			else return nil,false end
		end
		return if base then base..(if side then ' '..side else '')else side,base~=nil or side~=nil
	elseif kind == "word-spacing" or kind == "letter-spacing" or kind == "underline-offset" or kind == "outline-offset" then
		if kind == "underline-offset" and value == "auto" then return nil, true end
		if (kind == "word-spacing" or kind == "letter-spacing") and value == "normal" then return 0, true end
		local parsed = InlineStyle.length(value, context, true)
		if kind == "word-spacing" or kind == "letter-spacing" or kind == "outline-offset" then
			return if parsed then parsed.Value else nil, parsed ~= nil and not parsed.Percent
		end
		return parsed, parsed ~= nil
	elseif kind == "font-weight" then
		if value=='bold' then return 700,true elseif value=='normal' then return 400,true end
		local n=decimal(value)
		return n,n~=nil and n>=1 and n<=1000
	elseif kind == "font-style" then
		return value, value == "normal" or value == "italic"
	elseif kind == "font-feature-settings" then
		local parsed=FontFeatures.settings(value)
		return parsed,parsed~=nil
	elseif kind == "font-variant-numeric" then
		local parsed=FontFeatures.numeric(value)
		return parsed,parsed~=nil
	elseif kind == "font-variant-ligatures" then
		local parsed=FontFeatures.ligatures(value)
		return parsed,parsed~=nil
	elseif kind == "font-kerning" then local parsed=FontFeatures.kerning(value);return parsed,parsed~=nil
	elseif kind == "font-variant-caps" then local parsed=FontFeatures.caps(value);return parsed,parsed~=nil
	elseif kind == "font-variant-position" then local parsed=FontFeatures.position(value);return parsed,parsed~=nil
	elseif kind == "font-size-adjust" then local parsed=AdvancedVisual.fontSizeAdjust(value);return parsed,parsed~=nil
	elseif kind == "font-variant" then
		return value,FontFeatures.expand("font-variant",value)~=nil
	elseif kind == "skip-ink" then
		return value, value == "auto" or value == "none"
	elseif kind == "text-decoration" then
		local lines, parsed, seen = {}, {}, {}
		local cursor = 1
		while cursor <= #value do
			local token, nextCursor = Syntax.scan(value, cursor, " \t\r\n")
			cursor = nextCursor
			if token == "" then continue end
			local key = if token == "underline" then "Underline" elseif token == "line-through" then "Strike" elseif token == "overline" then "Overline" else nil
			if key then
				if seen.None or lines[key] then return nil, false end
				lines[key] = true; seen.Line = true
			elseif token == "none" then
				if seen.None or seen.Line then return nil, false end
				seen.None = true
			elseif property.ResetDecoration then
				local field, result
				if DECORATION_STYLES[token] then field, result = "Style", token
				elseif token == "auto" then field, result = "Thickness", false
				else
					local thickness = InlineStyle.length(token, context)
					local shade, alpha = Color.parse(token)
					if thickness then field, result = "Thickness", thickness
					elseif shade then field, result = "Color", shade; parsed.Alpha = alpha
					else return nil, false end
				end
				if seen[field] then return nil, false end
				seen[field], parsed[field] = true, result
			else return nil, false end
		end
		parsed.Lines = lines
		return if property.ResetDecoration then parsed else lines, next(seen) ~= nil
	elseif kind == "display" then
		if value == "-webkit-box" then return "block", true end
		return value, value == "none" or value == "block" or value == "list-item" or value == "flow-root" or value == "flex" or value == "inline" or value == "inline-block" or value == "inline-flex" or value == "contents"
			or value == "grid" or value == "inline-grid" or value == "-ms-grid" or value == "-ms-inline-grid" or value == "table" or value == "table-row" or value == "table-cell" or value == "table-row-group"
			or value == "table-header-group" or value == "table-footer-group" or value == "table-caption"
	elseif kind == "font-family" then
		local font = FontFamily.parse(value)
		return font, font ~= nil
	end
	return nil, false
end

local EMPTY = table.freeze({ Normal = table.freeze({}), Important = table.freeze({}) })
local allResets = {}

-- Absolute values are parsed once; relative lengths retain source for per-element resolution.
-- Diagnostics stay deferred until a declaration actually matches an element.
function InlineStyle.compile(source: string,quirks: boolean?): any
	WorkContext.checkpoint()
	if source == "" then return EMPTY end
	local result = { Normal = {}, Important = {} }
	for _, declaration in Syntax.declarations(source) do
		WorkContext.checkpoint()
		local entry: any = {}
		local source=declaration.Text:match('^%s*(.-)%s*$');local key,after=Syntax.identifier(source)
		local value=if key then source:sub(after):match('^%s*:%s*(.-)%s*$')else nil
		if not value then key=nil end
		if not key then entry.Error = "Invalid CSS declaration"
		else
			if key:sub(1,2)=='--'and #key>2 then
				-- Custom property names and their token streams are case-sensitive.
				local raw=declaration.Raw
				if raw then local _,nextValue,colon=Syntax.scan(raw,1,':');if colon==':'then value=Syntax.scan(raw:sub(nextValue),1,'',nil,true);value=value:match('^%s*(.-)%s*$')or''end end
				entry.Custom, entry.Raw = key, value
				table.insert(if declaration.Important then result.Important else result.Normal, table.freeze(entry))
				continue
			end
			key = key:lower()
			-- Browser line-clamp fallbacks commonly travel in the same stylesheet as
			-- the standard declaration. Treat the legacy alias as line-clamp and the
			-- orient hint as consumed compatibility syntax.
			if key == "-webkit-line-clamp" then key = "line-clamp"
			elseif key == "-webkit-mask-box-image" then key = "mask-border"
			elseif key == "grid-gap" then key = "gap"
			elseif key == "grid-row-gap" then key = "row-gap"
			elseif key == "grid-column-gap" then key = "column-gap"
			elseif key == "-webkit-box-orient" then
				local orient = value:lower()
				if orient == "vertical" or orient == "horizontal" then continue end
			end
			key=LayoutValues.Aliases[key] or key
			local webkitComposite=key=='-webkit-mask-composite'
			key=VisualValues.Aliases[key] or key
			if webkitComposite then value=({xor='exclude',['source-over']='add',['source-out']='subtract',['source-in']='intersect'})[value:lower()] or value end
			local property = Properties[key]
			value=QuirkyValues.value(key,value,quirks)
			-- CSS-wide identifiers are case-insensitive even when a property's
			-- ordinary values contain case-sensitive strings or grid line names.
			local identifier,ending=Syntax.identifier(value);local keyword=(if identifier and ending>#value then identifier else value):lower()
			local cssWide=keyword=="initial"or keyword=="inherit"or keyword=="unset"or keyword=="revert"or keyword=="revert-layer"
			if cssWide then value=keyword end
			if key=="font" and cssWide then
				-- CSS-wide font resets include the supported variant/reset-only
				-- components, not just the five values parsed from ordinary font text.
				for _, name in {"font-family","font-style","font-weight","font-size","line-height",
					"font-variant-caps","font-variant-position","font-variant-numeric","font-variant-ligatures",
					"font-feature-settings","font-kerning","font-size-adjust"} do
					for _, part in InlineStyle.compile(name..":"..value).Normal do
						table.insert(if declaration.Important then result.Important else result.Normal,part)
					end
				end
				continue
			end
			if property and Syntax.findFunction(value,1,'var') then
				-- Parsing waits until the winning custom properties have inherited and
				-- var() has produced the actual declaration value.
				if Variables.valid(value)then entry.VariableProperty, entry.Raw,entry.Quirks = key, value,quirks
				else entry.Error='Invalid CSS variable reference: '..value end
				table.insert(if declaration.Important then result.Important else result.Normal, table.freeze(entry))
				continue
			end
			if key == "all" then
				local wide=value:lower()
				if cssWide then
					local reset=allResets[wide]
					if not reset then
						reset={}
						for _, name in ResetProperties do
							for _, part in InlineStyle.compile(name..":"..wide).Normal do
								local copy=table.clone(part)
								-- Initial box values have no unsupported inline decoration.
								if wide=="initial" or (wide=="unset" and not copy.Inherited) then copy.InlineError=nil end
								table.insert(reset,table.freeze(copy))
							end
						end
						allResets[wide]=table.freeze(reset)
					end
					for _, part in reset do table.insert(if declaration.Important then result.Important else result.Normal,part) end
					continue
				end
			end
			local rollbackValue=value=='revert'or value=='revert-layer'
			local expansionValue=if rollbackValue then 'inherit'else value
			local expanded=VisualValues.expand(key,expansionValue) or LayoutValues.expand(key,expansionValue) or ColumnRuleInsets.expand(key,expansionValue) or GridValues.expand(key,expansionValue,Properties) or ScrollValues.expand(key,expansionValue)
            if expanded then
                for _,part in expanded do
                    local compiled=InlineStyle.compile(part.Name..":"..(if rollbackValue then value else part.Value))
                    for _,e in compiled.Normal do table.insert(if declaration.Important then result.Important else result.Normal,e) end
                end
                continue
            end
			local fontExpanded=FontFeatures.expand(key,expansionValue)
			if fontExpanded then
				for _,part in fontExpanded do
					local compiled=InlineStyle.compile(part.Name..":"..(if rollbackValue then value else part.Value))
					for _,e in compiled.Normal do table.insert(if declaration.Important then result.Important else result.Normal,e) end
				end
				continue
			end
			if not GridValues.Fields[key] and not (property and (property.Kind=="grid" or property.CaseSensitive))and not Syntax.findFunction(value,1,'anchor')and not Syntax.findFunction(value,1,'anchor-size')then value=value:lower() end
			if property then
				local wide = cssWide
				local parsed, accepted
				local relative = contextualLength(value)
				if wide then accepted = true else parsed, accepted = parseValue(property, value, if relative then
					{FontSize = 16, ParentFontSize = 16, RootFontSize = 16, FontRootSize = 16,
						ViewportWidth=100,ViewportHeight=100,Validate = true} else nil) end
				if relative and accepted then entry.Relative, entry.Property = value, property end
				entry.Wide = if wide then value else nil
				entry.Inherited = property.Inherited
				entry.Field = property.Field
				entry.ColorValue = property.Kind == "color" or property.Kind == "border-color" or property.Kind == "decoration-color"
				entry.Side = property.Side
				if property.Field=='Gap' and not wide then
					local parts=splitTokens(value)
					entry.GapNormal={parts[1]=='normal',(parts[2] or parts[1])=='normal'}
				end
				entry.BorderSide = property.BorderSide
				entry.BorderComponents = property.BorderComponents
				entry.LogicalSides = property.LogicalSides
				entry.LogicalValues = property.LogicalValues
				entry.Corner = property.Corner
				entry.LogicalCorner = property.LogicalCorner
				entry.LogicalDimension = property.LogicalDimension
				entry.DimensionPrefix = property.DimensionPrefix
				entry.Dimension = property.Dimension
				entry.Axis = property.Axis
				entry.ResetDecoration = property.ResetDecoration
				entry.Replaced = property.Replaced
				entry.Value = if type(parsed) == "table" then table.freeze(table.clone(parsed)) else parsed
				if not accepted then entry.Error = "Unsupported style: " .. key .. ": " .. value end
				if not property.Inherited and not property.Inline and not (key == "display") then
					entry.InlineError = "Unsupported style on inline element: " .. key .. ": " .. value
				end
			else entry.Error = "Unsupported style: " .. key .. ": " .. value end
		end
		table.insert(if declaration.Important then result.Important else result.Normal, table.freeze(entry))
		local property=key and Properties[key]
		if property and property.ResetOnly and not entry.Error then
			for _,name in property.ResetOnly do
				for _,reset in InlineStyle.compile(name..':'..(entry.Wide or 'initial')).Normal do
					table.insert(if declaration.Important then result.Important else result.Normal,reset)
				end
			end
		end
	end
	table.freeze(result.Normal); table.freeze(result.Important)
	return table.freeze(result)
end

function InlineStyle.resolve(node: any, parent: any, warnStyle: (string) -> (), inline: boolean?, author: any?, metricOverrides: any?, colorOverrides: any?, shadowOverride: any?, dimensionSource: any?): any
	local documentRoot=node.Kind=='Element'and node.Parent~=nil and node.Parent.Kind=='Document'and not node.Parent.LegacyFragment and DocumentAccessors.root(node.Parent)==node
	if documentRoot then inline=false end
	WorkContext.checkpoint()
	local quirks=DocumentMode.quirks(node)
	local style: any = {
		DefaultFont = parent.DefaultFont or FontFamily.Default,
		Font = parent.Font or parent.DefaultFont or FontFamily.Default,
		Color = Color3.new(0, 0, 0), FontSize = 16, ColorAlpha = 1,
		FontWeight = 400,
		FontStyle = "normal",
		FontFeatureSettings = {},
		FontVariantNumeric = false,
		FontVariantLigatures = {Liga=true,Calt=true},
		FontKerning=true,FontVariantCaps={Smcp=false,C2sc=false},FontVariantPosition={Sups=false,Subs=false},FontSizeAdjust={Kind="none"},
		SkipInk = "auto",
		TextAlign = "start",
		TextOverflow = "clip",
		Cursor = "auto",
		Filter = Filter.parse("none"),
		TableLayout = "auto",
		CaptionSide = "top", EmptyCells = "show",
		Direction = "ltr",
		UnicodeBidi = "normal",
		TextAlignLast = "auto", VerticalAlign = "baseline", TextJustify = "auto",
		WhiteSpace = "normal", WhiteSpaceCollapse = "collapse", TextWrapMode = "wrap", TextWrapStyle = "auto",
		UnderlinePosition = "auto", ImageRendering = "auto", ImageOrientation='from-image',ImageResolution='1dppx',MaskType='luminance',ShapeImageThreshold=0, ScrollbarWidth = "auto",
		Hyphens="manual",HyphenateCharacter="-",HyphenateLimitChars={5,2,2},
		TextEmphasisStyle=nil,TextEmphasisColor="currentcolor",TextEmphasisColorAlpha=1,TextEmphasisPosition={Vertical="over",Horizontal="right"},
		Quotes={{"“","”"},{"‘","’"}},WritingMode="horizontal-tb",TextOrientation="mixed",RubyAlign="center",RubyPosition="over",
		OverscrollX="auto",OverscrollY="auto",ScrollSnapType={Axis="none",Strictness="proximity"},ScrollSnapAlign={Block="none",Inline="none"},ScrollSnapStop="normal",ScrollBehavior="auto",ScrollbarGutter={Stable=false,BothEdges=false},
		ScrollPadding={0,0,0,0},ScrollMargin={0,0,0,0},OverflowClipMargins={{Box="padding-box",Offset={Value=0}}, {Box="padding-box",Offset={Value=0}}, {Box="padding-box",Offset={Value=0}}, {Box="padding-box",Offset={Value=0}}},
		ScrollInitialTarget="none",OverflowAnchor="auto",Appearance="auto",CaretColor={Auto=true},CaretShape="auto",CaretAnimation="auto",
		Float="none",Clear="none",ShapeOutside=nil,ShapeMargin=0,ColumnFill="balance",ColumnSpan="none",ColumnWrap="auto",ColumnRuleWidth=3,ColumnRuleStyle="none",ColumnRuleColor="currentcolor",ColumnRuleColorAlpha=1,Orphans=2,Widows=2,BreakInside="auto",BreakBefore="auto",BreakAfter="auto",
		ColumnRuleInsetCapStart=0,ColumnRuleInsetCapEnd=0,ColumnRuleInsetJunctionStart=0,ColumnRuleInsetJunctionEnd=0,
		ColumnRuleBreak='normal',ColumnRuleVisibilityItems='normal',MarginTrim={},MarginBreak='auto',MinIntrinsicSizing={},ColorScheme={Light=true,Normal=true},AlignTracks={'normal'},JustifyTracks={'normal'},GridAutoPosition={Row={Number=1},Column={Number=1}},
		Contain={},ContainerType="normal",ContainerNames={},ContentVisibility="visible",AnchorNames={},AnchorScope={},PositionAnchor='normal',PositionArea="none",PositionTryFallbacks={},PositionTryOrder='normal',
		InterpolateSize='numeric-only',
		InitialLetter='normal',
		TextBoxTrim='none',TextBoxEdge={Start='text',End='text'},
		MaskMode="alpha",MaskPositions={Background.DefaultPosition},MaskSizes={{Kind="explicit",X=false,Y=false}},MaskRepeats={{X="repeat",Y="repeat"}},MaskOrigins={"border-box"},MaskClips={"border-box"},MaskComposite="add",
		MaskBorderMode='alpha',MaskBorderSlice={0,0,0,0,Percent={false,false,false,false},Fill=false},MaskBorderWidth={'auto','auto','auto','auto'},MaskBorderOutset={0,0,0,0},MaskBorderRepeat='stretch',
		CornerShapes={'round','round','round','round'},ShadowColors={{Color='currentcolor',Alpha=1}},ShadowOffsets={false},ShadowBlurs={0},ShadowSpreads={0},ShadowPositions={'outset'},
		BorderImageSlice={100,100,100,100,Percent={true,true,true,true},Fill=false},BorderImageWidth={1,1,1,1},BorderImageOutset={0,0,0,0},BorderImageRepeat="stretch",CornerShape="round",
		MixBlendMode="normal",BackgroundBlendMode="normal",Isolation="auto",
		OffsetDistance={Value=0,Percent=false},OffsetRotate={Auto=true,Reverse=false,Angle=0},OffsetAnchor=nil,OffsetPosition=nil,TransformBox="view-box",
		PerspectiveOrigin={X={Value=50,Percent=true},Y={Value=50,Percent=true}},TransformStyle="flat",BackfaceVisibility="visible",
		AnimationTimeline={"auto"},AnimationComposition={"replace"},TransitionBehavior={"normal"},ScrollTimelineNames={"none"},ScrollTimelineAxes={"block"},ScrollTimelineAxis="block",ScrollMarkerGroup="none",
		OverflowWrap = "normal",LineBreak="auto",HangingPunctuation="none",TextAutospace="normal",
		WordBreak = "normal", Opacity = 1, ListStylePosition = "outside",
		ListStyleType = "disc", ListItem = ElementNames.htmlName(node) == "li",
		TabSize = { Kind = "number", Value = 8 },
		TextTransform = "none",
		TextIndent = { Value = 0, Percent = false },
		WordSpacing = 0,
		LetterSpacing = 0,
		LineHeight = { Kind = "normal" },
		Margin = { 0, 0, 0, 0 }, Padding = { 0, 0, 0, 0 },
		BorderSpacing = {0,0}, BorderCollapse = "separate",
		MarginAuto = {false, false, false, false},
		Hidden = false, BoxDecorationBreak='slice',BoxDecorationSpecified=false,InlineFragment=parent.InlineFragment,
		JustifyItems = "normal", JustifySelf = "auto",
		Display = "block", FlexDirection = "row", JustifyContent = "flex-start", AlignItems = "stretch", Gap = {0, 0},
		FlexGrow = 0, FlexShrink = 1, FlexBasis = "auto",
		FlexWrap = "nowrap", FlexBalance=false, FlexLineCount=1, AlignContent = "stretch",
		Order = 0, AlignSelf = "auto",
		Position = "static", FieldSizing = 'fixed',
		Visibility = "visible",
		BoxSizing = "content-box",
		Overflow = "visible", Resize = "none",
		OverflowX = "visible", OverflowY = "visible",
		ObjectFit = "fill",
		ObjectPosition = ObjectPosition.Default,
		BackgroundImages = {{Kind="none"}},
		BackgroundSizes = {{Kind="explicit",X=false,Y=false}},
		BackgroundPositions = {Background.DefaultPosition},BackgroundAttachments={"scroll"},
		BackgroundRepeats = {{X="repeat",Y="repeat"}},
		BackgroundOrigins = {"padding-box"}, BackgroundClips = {"border-box"},
		Transform = {}, TransformOrigin = {X={Value=50,Percent=true},Y={Value=50,Percent=true}},
		TransitionProperty={"all"},TransitionDuration={0},TransitionTiming={"ease"},TransitionDelay={0},
		AnimationName={"none"},AnimationDuration={0},AnimationTiming={"ease"},AnimationDelay={0},
		AnimationIteration={1},AnimationDirection={"normal"},AnimationFill={"none"},AnimationPlay={"running"},
		BorderWidth = 3, BorderStyle = "none", BorderColor = "currentcolor", BorderRadius = 0,
		BorderRadii = nil, PointerEvents="auto", UserSelect="auto", TouchAction="auto", GeneratedContent={},
		CounterReset={},CounterIncrement={},CounterSet={},
		OutlineWidth = 3, OutlineStyle = "none", OutlineColor = "currentcolor", OutlineOffset = 0,
	}
	style.ViewportWidth,style.ViewportHeight=parent.ViewportWidth or 0,parent.ViewportHeight or 0
	style.PreferredColorScheme=parent.PreferredColorScheme or 'light'
	style.ColorIsDefault=parent.ColorIsDefault==true or (parent.ColorIsDefault==nil and parent.Color==nil)
	local initial = table.clone(style)
	for field, value in initial do if type(value) == "table" then initial[field] = table.clone(value) end end
	initial.Font, initial.Display = style.DefaultFont, "inline"
	initial.TextDecoration = {}
	style.ColorAlpha = parent.ColorAlpha or 1
	local replacedInline = ElementNames.htmlName(node) == "img" or ElementNames.matches(node,"svg",ElementProfile.SVG) or ElementNames.htmlName(node) == "canvas"
		or ElementNames.htmlName(node) == "audio" or ElementNames.htmlName(node) == "video" or ElementNames.htmlName(node) == "iframe"
		or ElementNames.htmlName(node) == "object" or ElementNames.htmlName(node) == "embed"
	local initialEntry=ElementProfile.entry(node)
	style.Display = if replacedInline or node.NamespaceURI==ElementProfile.SVG or not initialEntry or initialEntry.Render == "inline" or initialEntry.Render=="slot" then "inline" else "block"
	for _, field in inheritedFields do
		local value = parent[field]
		if field=='Visibility'and parent.VisibilityCollapse then value='collapse'end
		if field=='TextEmphasisColor'then local tint=AnimationColors.fromStyle(parent,'text-emphasis-color');value=tint.Color;style.TextEmphasisColorAlpha=tint.Alpha end
		if value ~= nil then style[field] = if type(value) == "table" then table.clone(value) else value end
	end
	-- Keep the computed CSS font size separate from the adjusted Roblox draw size
	-- so inherited font-size-adjust is applied once per element rather than compounded.
	if parent.UnadjustedFontSize then style.FontSize=parent.UnadjustedFontSize end
	local element = ElementProfile.entry(node)
	if element and element.Defaults then
		for key, value in element.Defaults do
			style[key] = if type(value) == "table" then table.clone(value) else value
		end
		if element.Defaults.WhiteSpace=="pre" then style.WhiteSpaceCollapse,style.TextWrapMode="preserve","nowrap"
		elseif element.Defaults.WhiteSpace=="pre-wrap" then style.WhiteSpaceCollapse,style.TextWrapMode="preserve","wrap"
		elseif element.Defaults.WhiteSpace=="pre-line" then style.WhiteSpaceCollapse,style.TextWrapMode="preserve-breaks","wrap"
		elseif element.Defaults.WhiteSpace=="nowrap" then style.WhiteSpaceCollapse,style.TextWrapMode="collapse","nowrap"
		elseif element.Defaults.WhiteSpace=="break-spaces" then style.WhiteSpaceCollapse,style.TextWrapMode="break-spaces","wrap" end
	end
	style.SemanticRole = node.Attributes.role or (if element then element.SemanticRole else nil)
	style.SemanticLabel = node.Attributes["aria-label"] or node.Attributes.title
	if element and element.ValueAttribute then style.SemanticValue = node.Attributes[element.ValueAttribute] end
	if (node.NamespaceURI==nil or node.NamespaceURI=='http://www.w3.org/1999/xhtml')and(node.Attributes.dir~=nil or ElementNames.htmlName(node)=='bdi'or ElementNames.htmlName(node)=='input'and(node.Attributes.type or ''):lower()=='tel')then style.Direction=Directionality.of(node)end
	style.UnicodeBidi=Directionality.ua(node)
	-- An anchor without href is a placeholder, not a hyperlink.
	if ElementNames.htmlName(node) == "a" and node.Attributes.href == nil then
		style.Color, style.ColorAlpha = parent.Color, parent.ColorAlpha or 1
		style.TextDecoration = {}
	end
	if element and element.Defaults and element.Defaults.Color then style.ColorAlpha = 1;style.ColorIsDefault=false end
	if tableDisplays[style.TableRole] then
		style.Display=if ElementNames.htmlName(node) == "thead" then "table-header-group" elseif ElementNames.htmlName(node) == "tfoot" then "table-footer-group" else tableDisplays[style.TableRole]
	end
	if element and element.FontSizeScale then style.FontSize = math.max(1, (parent.UnadjustedFontSize or parent.FontSize) * element.FontSizeScale) end
	if ElementProfile.summary(node)then
		style.Display="list-item";style.ListStyleType=if node.Parent.Attributes.open~=nil then "disclosure-open"else "disclosure-closed"
	end
	local controlInherited=if ElementNames.htmlName(node)=='select'then table.clone(style)else nil
	ControlDefaults.apply(node, style,parent)
	local selectPartMetrics=ControlDefaults.selectPart(node,style,parent,author and author.SelectPartState)
	ControlDefaults.pseudo(node,style)
	-- UA :focus-visible precedes author declarations. A styled border does not
	-- replace the native focus ring; authors can override any outline component.
	if type(author)=="table" and author.FocusVisible==true then
		style.OutlineStyle,style.OutlineWidth="auto",1
		style.OutlineColor,style.OutlineColorAlpha=Color3.fromRGB(16,16,16),1
	end
	local htmlNamespace=node.NamespaceURI==nil or node.NamespaceURI=='http://www.w3.org/1999/xhtml'
	-- HTML hidden is a UA declaration, so an author's display/content-visibility
	-- can override it. Table groups/rows have their later UA collapse rule.
	local hiddenKey=if node.AttributeNamespaces then AttributeStore.expanded(node,nil,'hidden')else 'hidden'
	local hiddenValue=hiddenKey and node.Attributes[hiddenKey]
	if htmlNamespace and hiddenValue~=nil then
		if ElementNames.htmlName(node)=='embed'then
			style.Display='inline';style.Width={Value=0};style.Height={Value=0}
		elseif hiddenValue:lower()=='until-found'then style.ContentVisibility='hidden'
		else style.Display='none';style.Hidden=true end
		if ElementNames.htmlName(node)=='col'or ElementNames.htmlName(node)=='colgroup'or ElementNames.htmlName(node)=='thead'or ElementNames.htmlName(node)=='tbody'or ElementNames.htmlName(node)=='tfoot'or ElementNames.htmlName(node)=='tr'then
			style.Display=tableDisplays[style.TableRole];style.Hidden=false;style.Visibility='collapse'
		end
	end
	style.QuirksBodyColor,style.QuirksBodyAlpha,style.QuirksBodyDefault=parent.QuirksBodyColor,parent.QuirksBodyAlpha,parent.QuirksBodyDefault
	if quirks and htmlNamespace and ElementNames.htmlName(node)=='table' then
		-- UA rules reset typography at actual HTML tables, before author CSS.
		for _,field in {'FontSize','FontWeight','FontStyle','FontVariantLigatures','FontVariantNumeric','FontVariantCaps','FontVariantPosition',
			'LineHeight','WhiteSpace','WhiteSpaceCollapse','TextWrapMode','TextWrapStyle','TextAlign'}do style[field]=initial[field]end
		if parent.QuirksBodyColor then
			style.Color,style.ColorAlpha,style.ColorIsDefault=parent.QuirksBodyColor,parent.QuirksBodyAlpha,parent.QuirksBodyDefault
		end
	end
	-- Chromium treats nowrap as a presentational hint, including revert.
	if htmlNamespace and(ElementNames.htmlName(node)=='td'or ElementNames.htmlName(node)=='th')and node.Attributes.nowrap~=nil
		and not(author and author.SkipPresentationalHints)then
		style.WhiteSpace,style.WhiteSpaceCollapse,style.TextWrapMode='nowrap','collapse','nowrap'
	end
	local modal=type(author)=="table" and author.Modal==true
	local popover=node.Attributes.popover~=nil
	local topLayer=modal or(type(author)=="table" and author.PopoverOpen==true)
	local uaMaxWidth,uaMaxHeight=modal,modal
	if ElementNames.htmlName(node)=="dialog" or popover then
		style.MarginAuto={true,true,true,true}
		style.Insetleft={Value=0};style.Insetright={Value=0}
		style.UAWidthFitContent,style.UAHeightFitContent=true,true
		if modal then
			style.Position="fixed";style.Insettop={Value=0};style.Insetbottom={Value=0}
			style.Overflow,style.OverflowX,style.OverflowY="auto","auto","auto"
		end
		if popover then
			style.Position="fixed";style.Insettop={Value=0};style.Insetbottom={Value=0}
			style.Overflow,style.OverflowX,style.OverflowY="auto","auto","auto"
			style.Padding={4,4,4,4};style.BorderWidth=3;style.BorderStyle="solid"
			style.Background=Color3.new(1,1,1);style.BackgroundAlpha=1
		end
	end
	if htmlNamespace and ElementNames.htmlName(node)=='video'then style.ObjectFit='contain'end
	if htmlNamespace and not(author and author.SkipPresentationalHints)then
	 local cell=ElementNames.htmlName(node)=='td'or ElementNames.htmlName(node)=='th'
	 local image=ElementNames.htmlName(node)=='img'or(ElementNames.htmlName(node)=='input'and ControlDefaults.kind(node)=='image')
	 local dimensionAttributes=if ElementNames.htmlName(node)=='img'and dimensionSource then dimensionSource.Attributes else node.Attributes
	 local video=ElementNames.htmlName(node)=='video'
	 local width=image or video or cell or ElementNames.htmlName(node)=='table'or ElementNames.htmlName(node)=='col'or ElementNames.htmlName(node)=='colgroup'or ElementNames.htmlName(node)=='hr'
	 local height=image or video or cell or ElementNames.htmlName(node)=='table'or ElementNames.htmlName(node)=='tr'or ElementNames.htmlName(node)=='thead'or ElementNames.htmlName(node)=='tbody'or ElementNames.htmlName(node)=='tfoot'
		for attribute, field in {width = "Width", height = "Height"} do
		 if (attribute=='width'and width)or(attribute=='height'and height)then
			local value=AttributeValues.dimension(dimensionAttributes[attribute],cell or attribute=='width'and ElementNames.htmlName(node)=='table')
			if value then style[field]=value end
		 end
		end
		if video then
			local w,h=AttributeValues.dimension(node.Attributes.width),AttributeValues.dimension(node.Attributes.height)
			if w and h and not w.Percent and not h.Percent then style.AspectRatio={Auto=true,Value=if h.Value>0 and w.Value>0 then w.Value/h.Value else nil}end
		end
	end
	-- HTML's auto-size UA defaults precede author declarations. In particular,
	-- initial/unset restore contain-intrinsic:none, while revert returns here.
	local sizes=node.Attributes.sizes
	local autoImage=ElementNames.html(node,'img')and sizes~=nil and(sizes:lower()=='auto'or sizes:sub(1,5):lower()=='auto,')
	if autoImage then
		style.AutoImageSize=true
		style.ContainIntrinsicWidth,style.ContainIntrinsicHeight={Value=300,Percent=false},{Value=150,Percent=false}
	end
	local authorRules = if type(author) == "string" then InlineStyle.compile(author,quirks) else author or EMPTY
	local isList = ElementNames.htmlName(node) == "ul" or ElementNames.htmlName(node) == "ol" or ElementNames.htmlName(node) == "menu"
	local listContainer = isList or ElementNames.htmlName(node) == "dl"
	local listDepth, ancestor = 0, node.Parent
	if listContainer then
		while ancestor do
			if ElementNames.htmlName(ancestor) == "ul" or ElementNames.htmlName(ancestor) == "ol" or ElementNames.htmlName(ancestor) == "menu" or ElementNames.htmlName(ancestor) == "dl" then listDepth += 1 end
			ancestor = ancestor.Parent
		end
		if isList then style.ListStyleType = if ElementNames.htmlName(node) == "ol" then "decimal" elseif listDepth == 0 then "disc" elseif listDepth == 1 then "circle" else "square" end
	end
	local marginSpecified: {[number]: boolean}? = nil
	local paddingSpecified: {[number]: boolean}? = nil
	local localRules = InlineStyle.compile(if author and author.InlineIncluded then ''else node.Attributes.style or "",quirks)
	local orderedRules = {authorRules.Normal, localRules.Normal, authorRules.Important, localRules.Important}
	-- Reverting a component reads the lower cascade, not the current layer's
	-- earlier declaration. The ordinary resolver restores compound/side values.
	-- Cache each lower cascade once per element; nested rollbacks are bounded.
	local rollbackCache={}
	local resolvedSelectAppearance
	local function rollback(entry,group,fontBasis,modeBasis)
		local origin=entry.Wide=='revert';local attached=group==2 or group==4 or entry.CascadeInline==true
		local cacheKey=(if origin then 'origin'else tostring(entry.CascadeLayer)..':'..tostring(attached)..':'..tostring(group>2))..':'..tostring(fontBasis)..':'..tostring(modeBasis)
		if rollbackCache[cacheKey]then return rollbackCache[cacheKey]end
		local reduced=table.clone(authorRules);reduced.Normal={};reduced.Important={};reduced.InlineIncluded=true
		reduced.SkipPresentationalHints=origin or authorRules.SkipPresentationalHints
		if ElementNames.htmlName(node)=='select'and entry.Field~='Appearance'then reduced.SelectUAAppearance=resolvedSelectAppearance end
		reduced.RollbackDepth=(authorRules.RollbackDepth or 0)+1
		if reduced.RollbackDepth>64 then warnStyle('CSS cascade rollback depth exceeded');return initial end
		if not origin then
			for index,entries in orderedRules do for _,candidate in entries do
				local own=index==2 or index==4 or candidate.CascadeInline==true
				local include=false
				if attached then include=not own and(index<3 or group>2)
				elseif not own then
					local order=CascadeLayers.compare(candidate.CascadeLayer,entry.CascadeLayer)
					include=if group<3 then index<3 and order<0 else order>0
				end
				if include then table.insert(if index>2 then reduced.Important else reduced.Normal,candidate)end
			end end
		end
		-- Revert selects a lower declaration; em lengths still use this
		-- element's final computed font, not the lower layer's old font size.
		if fontBasis then for _,part in InlineStyle.compile('font-size:'..tostring(fontBasis)..'px').Normal do local copy=table.clone(part);copy.CascadeInline=true;table.insert(reduced.Important,copy)end end
		-- A logical reset rolls back its paired size declaration while retaining
		-- this element's final mapping, even if a lower layer has another mode.
		if modeBasis then for _,part in InlineStyle.compile('writing-mode:'..modeBasis).Normal do local copy=table.clone(part);copy.CascadeInline=true;table.insert(reduced.Important,copy)end end
		local result=InlineStyle.resolve(node,parent,warnStyle,inline,reduced,nil,nil,nil,dimensionSource);rollbackCache[cacheKey]=result;return result
	end
	local customRaw = {}
	for group, entries in orderedRules do
		for _, entry in entries do
			if entry.Custom then
				local keyword=entry.Raw:match('^%s*(.-)%s*$'):lower()
				if keyword=='revert'or keyword=='revert-layer'then local source=table.clone(entry);source.Wide=keyword;customRaw[entry.Custom]=rollback(source,group).Custom[entry.Custom]or'unset'
				else customRaw[entry.Custom]=entry.Raw end
			end
		end
	end
	local propertyRegistry=authorRules.PropertyRegistry
	style.CounterStyles=authorRules.CounterStyles or parent.CounterStyles
	local unresolvedAuthorRules,unresolvedLocalRules=authorRules,localRules
	local customContext={FontSize=style.FontSize,RootFontSize=parent.RootFontSize or 16,ViewportWidth=style.ViewportWidth,ViewportHeight=style.ViewportHeight,Color=style.Color,ColorAlpha=style.ColorAlpha}
	for _,entries in orderedRules do for _,entry in entries do
		if entry.VariableProperty=='font-size'or entry.VariableProperty=='font'then customContext.FontSizeDependencies=entry.Raw
		elseif entry.Field=='FontSize'or entry.Field=='FontShorthand'then customContext.FontSizeDependencies=nil end
	end end
	style.Custom = Variables.compute(customRaw,parent.Custom,propertyRegistry,customContext)
	local function resolvedEntries(entries: any): any
		local resolved = {}
		for _, entry in entries do
			if entry.VariableProperty then
				local value = Variables.substitute(entry.Raw, style.Custom)
				local compiled = InlineStyle.compile(entry.VariableProperty .. ":" .. (value or "unset"),entry.Quirks)
				local replacement = compiled.Normal
				local invalid = #replacement == 0
				for _, candidate in replacement do if candidate.Error then invalid = true; break end end
				if invalid then replacement = InlineStyle.compile(entry.VariableProperty .. ":unset").Normal end
					for _, candidate in replacement do local copy=table.clone(candidate);copy.CascadeLayer=entry.CascadeLayer;copy.CascadeInline=entry.CascadeInline;table.insert(resolved,copy)end
			elseif not entry.Custom then
				table.insert(resolved, entry)
			end
		end
		return resolved
	end
	local resolvedAuthor=table.clone(authorRules);resolvedAuthor.Normal=resolvedEntries(authorRules.Normal);resolvedAuthor.Important=resolvedEntries(authorRules.Important);authorRules=resolvedAuthor
	localRules = {Normal = resolvedEntries(localRules.Normal), Important = resolvedEntries(localRules.Important)}
	orderedRules = {authorRules.Normal, localRules.Normal, authorRules.Important, localRules.Important}
	local rollbackGroups={};for group,entries in orderedRules do for _,entry in entries do rollbackGroups[entry]=group end end
	-- Positioned and floating text containers accept box properties before their
	-- computed display is blockified below.
	if inline and ElementNames.htmlName(node) ~= "img" then
		local position, display, float = "static", nil, "none"
		for _, entries in orderedRules do
			for _, entry in entries do
				if entry.Field == "Position" and not entry.Error then position = entry.Value end
				if entry.Field == "Float" and not entry.Error then float = if entry.Wide then CompositeValues.wide(entry, if entry.Wide == "inherit" then parent else initial) else entry.Value end
				if entry.Field == "Display" and not entry.Error then display = if entry.Wide then CompositeValues.wide(entry, if entry.Wide == "inherit" then parent else initial) else entry.Value end
			end
		end
		if position == "absolute" or position == "fixed" or float ~= "none" or display == "block" or display == "flow-root" or display == "flex" or display == "grid" or display == "-ms-grid" or tableRoles[display] then inline = false end
	end
	local context = {FontSize = style.FontSize, ParentFontSize = parent.FontSize or 16,
		RootFontSize = parent.RootFontSize or 16, FontRootSize = if ElementNames.htmlName(node) == "html" then 16 else parent.RootFontSize or 16,
		ViewportWidth=style.ViewportWidth,ViewportHeight=style.ViewportHeight,
		ContainerWidth=authorRules.ContainerWidth,ContainerHeight=authorRules.ContainerHeight,WritingMode=style.WritingMode}
	local dimensionMapping
	local function entryValue(entry: any): (any, boolean)
		if entry.Wide then
			local source = if entry.Wide=='revert'or entry.Wide=='revert-layer'then rollback(entry,rollbackGroups[entry]or 1,if entry.Field=='FontSize'or entry.Field=='FontShorthand'then nil else context.FontSize,if entry.Dimension then dimensionMapping.WritingMode else nil)elseif entry.Wide == "inherit" or (entry.Wide == "unset" and entry.Inherited) then parent else initial
			if (entry.Wide=='revert'or entry.Wide=='revert-layer')and source.SelectUAColorBackgroundAlpha
				and (entry.Field=='Background'or entry.Field=='BackgroundShorthand')then
				-- UA hover paint refers to this element's final currentColor. A
				-- lower cascade resolved before its authored color must retain that
				-- dependency, rather than copy the lower cascade's old RGB value.
				source=table.clone(source);source.Background={SelectUAAlpha=source.SelectUAColorBackgroundAlpha}
			end
			if entry.Field=='BorderRadius'and source.ButtonNativeRadius then
				-- The native theme's rounding is paint, not an inherited CSS radius.
				source=table.clone(source);source.BorderRadius,source.BorderRadii=0,nil
			end
			if entry.Field=='Visibility'and source.VisibilityCollapse then return 'collapse',true end
			if entry.Field == "TransitionShorthand" then return {Property=source.TransitionProperty,Duration=source.TransitionDuration,Timing=source.TransitionTiming,Delay=source.TransitionDelay,Behavior=source.TransitionBehavior},true end
			if entry.Field == "AnimationShorthand" then return {Name=source.AnimationName,Duration=source.AnimationDuration,Timing=source.AnimationTiming,Delay=source.AnimationDelay,Iteration=source.AnimationIteration,Direction=source.AnimationDirection,Fill=source.AnimationFill,Play=source.AnimationPlay},true end
			if entry.Field == "TextWrapShorthand" then return {Mode=source.TextWrapMode,Style=source.TextWrapStyle},true end
			if entry.Field == 'PositionTryShorthand'then return {Order=source.PositionTryOrder,Fallbacks=source.PositionTryFallbacks},true end
			if entry.Field=='TextEmphasisColor'then return AnimationColors.fromStyle(source,'text-emphasis-color'),true end
			if entry.Field == "TextEmphasisShorthand" then local tint=AnimationColors.fromStyle(source,'text-emphasis-color');return {Style=source.TextEmphasisStyle,Color=tint.Color,Alpha=tint.Alpha},true end
			if entry.Field == "OverscrollBehavior" then return {source.OverscrollX,source.OverscrollY},true end
			if entry.Field == "ColumnsShorthand" then return {Count=source.ColumnCount,Width=source.ColumnWidth,Height=source.ColumnHeight},true end
			if entry.Field == "ContainIntrinsicShorthand" then return {Width=source.ContainIntrinsicWidth,Height=source.ContainIntrinsicHeight},true end
			if entry.Field == "FlexWrap" then return {Wrap=source.FlexWrap,Balance=source.FlexBalance},true end
			if entry.Field == "ColumnRule" then return {Width=source.ColumnRuleWidth,Style=source.ColumnRuleStyle,Color=source.ColumnRuleColor,Alpha=source.ColumnRuleColorAlpha},true end
			if entry.Field == "CaretColor" then return if source.CaretCustom then {Color=source.CaretColor,Alpha=source.CaretColorAlpha} else {Auto=true},true end
			if entry.Field == "CaretShorthand" then return {Color=source.CaretColor,Alpha=source.CaretColorAlpha,Shape=source.CaretShape},true end
			if entry.Field == "BackgroundShorthand" then
				return {
					Color=source.Background,Alpha=source.BackgroundAlpha or 1,
					Images=source.BackgroundImages or {{Kind="none"}},Sizes=source.BackgroundSizes or {{Kind="explicit",X=false,Y=false}},
					Positions=source.BackgroundPositions or {Background.DefaultPosition},Repeats=source.BackgroundRepeats or {{X="repeat",Y="repeat"}},
					Origins=source.BackgroundOrigins or {"padding-box"},Clips=source.BackgroundClips or {"border-box"},Attachments=source.BackgroundAttachments or {"scroll"},
				},true
			end
			if entry.Field == "OffsetShorthand" then return {Path=source.OffsetPath,Distance=source.OffsetDistance,Rotate=source.OffsetRotate,Anchor=source.OffsetAnchor},true end
			return CompositeValues.wide(entry, if source == parent then setmetatable(table.clone(parent), {__index = initial}) else source), true
		end
		if entry.Relative then return parseValue(entry.Property, entry.Relative, context) end
		return entry.Value, true
	end
	local baseListHeight,baseSelectMetrics
	if ElementNames.htmlName(node)=='select'then
		local appearance=style.Appearance
		for _,entries in orderedRules do for _,entry in entries do
			if entry.Field=='Appearance'and not entry.Error then appearance=entryValue(entry)end
		end end
		appearance=authorRules.SelectUAAppearance or appearance
		resolvedSelectAppearance=appearance
		if appearance=='base-select'then
			local list=node.Attributes.multiple~=nil or AttributeValues.positive(node.Attributes.size,1)>1
			baseSelectMetrics=ControlDefaults.baseSelect(style,controlInherited,list,authorRules.SelectPartState)
			if list then baseListHeight={Value=0};style.Height=baseListHeight end
		end
	end
	-- Resolve font size before other lengths. A shorthand outside the engine's
	-- computed limits must not leave a font/root size that the normal cascade rejects.
	local rejected, retry = {}, true
	while retry do
		retry = false
		context.FontSize, context.RootFontSize = style.FontSize, parent.RootFontSize or 16
		for _, entries in orderedRules do
			for _, entry in entries do
				if not entry.Error and not rejected[entry] and (entry.Field == "FontSize" or entry.Field == "FontShorthand") then
					local value, accepted = entryValue(entry)
					if accepted then
						local size = if entry.Field == "FontShorthand" then value.FontSize else value
						context.FontSize = if size == "smaller" then math.max(1, context.ParentFontSize / 1.2)
							elseif size == "larger" then math.min(100, context.ParentFontSize * 1.2) else size
					end
				end
			end
		end
		if ElementNames.htmlName(node) == "html" then context.RootFontSize = context.FontSize end
		for _, entries in orderedRules do
			for _, entry in entries do
				if entry.Relative and entry.Field == "FontShorthand" and not entry.Error and not rejected[entry] then
					local _, accepted = entryValue(entry)
					if not accepted then rejected[entry], retry = true, true end
				end
			end
		end
	end
	-- Sampled inherited metrics participate before dependent em/rem lengths are
	-- resolved. Keep the authored font separate from this cascade's sample.
	if metricOverrides and metricOverrides.FontSize~=nil then
		context.FontSize=metricOverrides.FontSize
		if ElementNames.htmlName(node)=='html'then context.RootFontSize=context.FontSize end
	end
	style.RootFontSize = context.RootFontSize
	if propertyRegistry and next(propertyRegistry)then
		customContext.FontSize,customContext.RootFontSize=context.FontSize,context.RootFontSize
		style.Custom=Variables.compute(customRaw,parent.Custom,propertyRegistry,customContext)
		authorRules=table.clone(unresolvedAuthorRules);authorRules.Normal=resolvedEntries(unresolvedAuthorRules.Normal);authorRules.Important=resolvedEntries(unresolvedAuthorRules.Important)
		localRules={Normal=resolvedEntries(unresolvedLocalRules.Normal),Important=resolvedEntries(unresolvedLocalRules.Important)}
		orderedRules={authorRules.Normal,localRules.Normal,authorRules.Important,localRules.Important}
		for group,entries in orderedRules do for _,entry in entries do rollbackGroups[entry]=group end end
	end
	-- Logical sides use the final computed direction, independent of declaration order.
	for _, entries in orderedRules do
		for _, entry in entries do
			if not entry.Error and (entry.Field=="Direction" or entry.Field=="WritingMode") then
				local value,accepted=entryValue(entry);if accepted then style[entry.Field]=value end
			end
		end
	end
	if node.GeneratedPseudo=='picker(select)'then ControlDefaults.preparePicker(style)end
	dimensionMapping={WritingMode=style.WritingMode}
	local function apply(entries: any)
		context.WritingMode=style.WritingMode
		for index, entry in entries do
			if index%16==1 then WorkContext.checkpoint()end
			local replaced = ElementNames.htmlName(node) == "img" or ElementNames.matches(node,"svg",ElementProfile.SVG) or ElementNames.htmlName(node) == "audio" or ElementNames.htmlName(node) == "video"
				or ElementNames.htmlName(node) == "canvas" or ElementNames.htmlName(node) == "iframe" or ElementNames.htmlName(node) == "object" or ElementNames.htmlName(node) == "embed"
				or ControlDefaults.kind(node)
			local message = if inline and entry.InlineError and not (replaced and entry.Replaced) then entry.InlineError else entry.Error
			if not message and entry.Field=="Filter" and ElementNames.htmlName(node)~="img" and not entry.Wide and #entry.Value.Steps>0 then
				if not Filter.native(entry.Value)then message="Container filter supports brightness(0–100%) and opacity(); other functions require image pixels"end
			end
			if message then warnStyle(message)
			else
				local value, accepted = entryValue(entry)
				if not accepted or rejected[entry] then
					warnStyle("Relative CSS length exceeds supported bounds: " .. tostring(entry.Relative))
					continue
				end
				-- The mapping prerequisites were already cascaded above. Replaying
				-- an earlier declaration here would temporarily change the axes of
				-- intervening logical sides, corners and dimensions.
				if entry.Field=='Direction'or entry.Field=='WritingMode'then continue end
				if entry.LogicalDimension then
					local original=entry;entry=table.clone(entry)
					entry.Field=WritingMode.dimension(dimensionMapping,entry.LogicalDimension,entry.DimensionPrefix)
					rollbackGroups[entry]=rollbackGroups[original]
				end
				if entry.Field == "Font" and value == false then value = style.DefaultFont end
				if style.ButtonAppearanceOrigins and ControlDefaults.appearanceField(entry.Field)then
					local lower=if entry.Wide=='revert'or entry.Wide=='revert-layer'then rollback(entry,rollbackGroups[entry]or 1,context.FontSize)else nil
					ControlDefaults.cascadeAppearance(style,entry,lower)
				end
				if entry.Field == "MaxWidth" then uaMaxWidth=false end
				if entry.Field == "MaxHeight" then uaMaxHeight=false end
				if baseSelectMetrics and entry.Field=='BorderRadius'then baseSelectMetrics.RadiusAuthored=true end
				if entry.Relative and LengthExpression.usesViewport(entry.Relative) then style.UsesViewportUnits=true;if entry.Relative:lower():match('[%d%.]cq[%a]+')then style.UsesContainerUnits=true end end
				if entry.Field=='Gap' then
					if not entry.Side or entry.Side==2 then style.GridGapSpecified=if entry.Wide then entry.Wide=='inherit' and parent.GridGapSpecified or false else not entry.GapNormal[if entry.Side then 1 else 2] end
					if not entry.Side or entry.Side==1 then style.RowGapSpecified=if entry.Wide then entry.Wide=='inherit' and parent.RowGapSpecified or false else not entry.GapNormal[1] end
				end
				if (entry.Field == "Background" or entry.Field == "BackgroundShorthand") and ControlDefaults.kind(node) then style.ControlBackgroundSpecified = true end
				if entry.Field=='Color' and ControlDefaults.kind(node) then style.ControlColorSpecified=true end
				if entry.Field=='Color' then style.ColorIsDefault=entry.Wide=='initial' or (entry.Wide=='unset' or entry.Wide=='inherit') and (parent.ColorIsDefault==true or (parent.ColorIsDefault==nil and parent.Color==nil)) end
				if entry.Field=='BoxShadows' or entry.Field:match('^Shadow')then style.ShadowSpecified=true end
				if ControlDefaults.kind(node) and (entry.Field=="Border" or entry.Field=="BorderWidth" or entry.Field=="BorderStyle" or entry.Field=="BorderColor") then
					style.ControlBorderSpecified=true
				end
				if entry.Field == "Margin" then
					marginSpecified = marginSpecified or {}
					if entry.Side then marginSpecified[entry.Side] = true
					else for side = 1, 4 do marginSpecified[side] = true end end
				end
				if entry.Field == "Padding" then
					paddingSpecified = paddingSpecified or {}
					if entry.Side then paddingSpecified[entry.Side] = true
					else for side = 1, 4 do paddingSpecified[side] = true end end
				end
				if entry.Field == "Display" then
					style.Hidden = value == "none"
					if value ~= "none" then style.ListItem = value=='list-item' end
				end
				if entry.Field=='CounterReset'then style.CounterResetSpecified=true end
				if entry.Field=='CounterSet'then style.CounterSetSpecified=true end
				if entry.Field=='BoxDecorationBreak' then style.BoxDecorationSpecified=true end
				if entry.ResetDecoration then
					-- Supported shorthand resets its omitted components, not underline offset.
					style.DecorationColor, style.DecorationColorAlpha = value.Color, value.Alpha
					style.DecorationThickness = if value.Thickness then table.clone(value.Thickness) else nil
					style.DecorationStyle = value.Style
					value = value.Lines
				end
				local function logicalIndex(name: string): number
					return WritingMode.side(style,name)
				end
				local logical = entry.LogicalSides
				if entry.Field == "Border" or entry.Field == "BorderWidth" or entry.Field == "BorderStyle" or entry.Field == "BorderColor" then
					if not style.BorderSides then
						style.BorderSides = {}
						for side = 1, 4 do
							style.BorderSides[side] = {Width = style.BorderWidth, Style = style.BorderStyle, Color = style.BorderColor, Alpha = style.BorderColorAlpha or 1}
						end
					end
					local sides = if logical then {} else nil
					if logical then for _,name in logical do table.insert(sides,logicalIndex(name)) end end
					for order, side in if sides then sides else {entry.BorderSide or 1,entry.BorderSide or 2,entry.BorderSide or 3,entry.BorderSide or 4} do
						if entry.BorderSide and not logical and side~=entry.BorderSide then continue end
						local edge = style.BorderSides[side]
						local part = if logical and(entry.LogicalValues or entry.Wide)then value[math.min(order,#value)]
								elseif entry.BorderComponents or (entry.Wide and not entry.BorderSide) then value[side] else value
						if entry.Field == "Border" then
							edge.Width, edge.Style, edge.Color, edge.Alpha = part.Width, part.Style, part.Color, part.Alpha or 1
						elseif entry.Field == "BorderColor" then edge.Color, edge.Alpha = part.Color, part.Alpha
						elseif entry.Field == "BorderWidth" then edge.Width = part
						else edge.Style = part end
					end
				elseif entry.Field == "BackgroundShorthand" then
					style.Background,style.BackgroundAlpha=value.Color,value.Alpha or 1
					style.BackgroundImages=table.clone(value.Images);style.BackgroundSizes=table.clone(value.Sizes)
					style.BackgroundPositions=table.clone(value.Positions);style.BackgroundRepeats=table.clone(value.Repeats)
					style.BackgroundOrigins=table.clone(value.Origins);style.BackgroundClips=table.clone(value.Clips)
					style.BackgroundAttachments=table.clone(value.Attachments or {"scroll"})
				elseif entry.Field == "OffsetShorthand" then
					style.OffsetPath,style.OffsetDistance,style.OffsetRotate,style.OffsetAnchor=value.Path,value.Distance,value.Rotate,value.Anchor
				elseif (entry.Field=="BackgroundPositions" or entry.Field=='MaskPositions') and entry.Axis then
					local axisValues={}
					if entry.Wide then for _,position in value do table.insert(axisValues,position[entry.Axis]) end else axisValues=value end
					local current=style[entry.Field] or {Background.DefaultPosition};local merged={}
					for index=1,math.max(#current,#axisValues) do
						local previous=current[math.min(index,#current)] or Background.DefaultPosition
						local axis=axisValues[math.min(index,#axisValues)]
						merged[index]={X=if entry.Axis=="X" then table.clone(axis) else table.clone(previous.X),Y=if entry.Axis=="Y" then table.clone(axis) else table.clone(previous.Y)}
					end
					style[entry.Field]=merged
				elseif (entry.Field=='BackgroundRepeats' or entry.Field=='MaskRepeats') and entry.Axis then
					local axisValues={};if entry.Wide then for _,repeatValue in value do table.insert(axisValues,repeatValue[entry.Axis])end else axisValues=value end
					local current=style[entry.Field];local merged={}
					for index=1,math.max(#current,#axisValues)do local previous=current[(index-1)%#current+1];local part=axisValues[(index-1)%#axisValues+1]
						merged[index]={X=if entry.Axis=='X'then part else previous.X,Y=if entry.Axis=='Y'then part else previous.Y}
					end;style[entry.Field]=merged
				elseif entry.Field=='MaskShorthand'then
					style.MaskImage=value.MaskImage
					style.MaskBorderSource=nil;style.MaskBorderSlice=AdvancedVisual.imageSlice('0');style.MaskBorderWidth={'auto','auto','auto','auto'};style.MaskBorderOutset={0,0,0,0};style.MaskBorderRepeat='stretch';style.MaskBorderMode='alpha'
					for field,part in value do style[field]=if type(part)=='table'then table.clone(part)else part end
				elseif entry.Field=='MaskBorderShorthand'then
					style.MaskBorderSource=value.Source;style.MaskBorderSlice=value.Slice;style.MaskBorderWidth=value.Width;style.MaskBorderOutset=value.Outset;style.MaskBorderRepeat=value.Repeat;style.MaskBorderMode=value.Mode
				elseif entry.Field=='BoxShadows'then
					style.ShadowColors,style.ShadowOffsets,style.ShadowBlurs,style.ShadowSpreads,style.ShadowPositions={},{},{},{},{}
					for _,shadow in value or {}do
						table.insert(style.ShadowColors,{Color=shadow.Color,Alpha=shadow.Alpha});table.insert(style.ShadowOffsets,{X=shadow.X,Y=shadow.Y})
						table.insert(style.ShadowBlurs,shadow.Blur);table.insert(style.ShadowSpreads,shadow.Spread);table.insert(style.ShadowPositions,if shadow.Inset then 'inset'else 'outset')
					end
					if #style.ShadowOffsets==0 then style.ShadowOffsets={false};style.ShadowColors={{Color='currentcolor',Alpha=1}};style.ShadowBlurs={0};style.ShadowSpreads={0};style.ShadowPositions={'outset'}end
				elseif entry.Field=='CornerShapes'then
					if entry.Corner or entry.LogicalCorner then
						local name=entry.Corner or entry.LogicalCorner;local rtl=style.Direction=='rtl'
						local indices={['top-left']=1,['top-right']=2,['bottom-right']=3,['bottom-left']=4,['start-start']=if rtl then 2 else 1,['start-end']=if rtl then 1 else 2,['end-start']=if rtl then 3 else 4,['end-end']=if rtl then 4 else 3}
						style.CornerShapes[indices[name]]=if entry.Wide then value[indices[name]]else value[1]
					else style.CornerShapes=table.clone(value)end
				elseif entry.Field == "WhiteSpace" then
					style.WhiteSpaceCollapse,style.TextWrapMode=WhiteSpace.parse(value)
				elseif entry.Field == "TextWrapShorthand" then
					style.TextWrapMode,style.TextWrapStyle=value.Mode,value.Style
				elseif entry.Field == 'PositionTryShorthand'then
					style.PositionTryOrder,style.PositionTryFallbacks=value.Order,value.Fallbacks
				elseif entry.Field == "TextEmphasisShorthand" then
					style.TextEmphasisStyle=value.Style
					if value.Color then style.TextEmphasisColor,style.TextEmphasisColorAlpha=value.Color,value.Alpha or 1 end
				elseif entry.Field == "OverscrollBehavior" then
					style.OverscrollX,style.OverscrollY=value[1],value[2]
				elseif entry.Field == "OverscrollInline" then
					style.OverscrollX=value
				elseif entry.Field == "OverscrollBlock" then
					style.OverscrollY=value
				elseif entry.Field == "CaretColor" then
					style.CaretColor=if value and not value.Auto then value.Color else {Auto=true}
					style.CaretColorAlpha=if value and not value.Auto then value.Alpha or 1 else 1
					style.CaretCustom=value and not value.Auto or false
				elseif entry.Field == "CaretShorthand" then
					if value.Color then style.CaretColor,style.CaretColorAlpha=value.Color,value.Alpha or 1 end
					style.CaretShape=value.Shape;style.CaretCustom=true
				elseif entry.Field == "ColumnsShorthand" then
					style.ColumnCount,style.ColumnWidth,style.ColumnHeight=value.Count,value.Width,value.Height
				elseif entry.Field == "ContainerShorthand" then
					style.ContainerNames,style.ContainerType=if value then table.clone(value.Names) else {},if value then value.Type else "normal"
				elseif entry.Field == "ContainIntrinsicShorthand" then
					style.ContainIntrinsicWidth=if value then value.Width else nil;style.ContainIntrinsicHeight=if value then value.Height else nil
				elseif entry.Field == "BorderImageShorthand" then
					style.BorderImageSource=if value then value.Source else nil
					style.BorderImageSlice=if value then table.clone(value.Slice) else {100,100,100,100}
					style.BorderImageWidth=if value then table.clone(value.Width) else {1,1,1,1}
					style.BorderImageRepeat=if value then value.Repeat else "stretch"
					style.BorderImageOutset=if value and value.Outset then table.clone(value.Outset)else {0,0,0,0}
				elseif entry.Field == "ColumnRule" then
					style.ColumnRuleWidth,style.ColumnRuleStyle=value.Width,value.Style
					style.ColumnRuleColor,style.ColumnRuleColorAlpha=value.Color,value.Alpha or 1
				elseif entry.Field == "AccentColor" then
					if not value or value.Auto then style.AccentColor,style.AccentColorAlpha=nil,nil
					else style.AccentColor,style.AccentColorAlpha=value.Color,value.Alpha end
				elseif entry.Field == "FontShorthand" or entry.Field == "ListStyle" then
					for field, part in value do style[field] = if type(part) == "table" then table.clone(part) else part end
					if style.Font == false then style.Font = style.DefaultFont end
				elseif entry.Field == "Outline" then
					style.OutlineWidth, style.OutlineStyle = value.Width, value.Style
					style.OutlineColor, style.OutlineColorAlpha = value.Color, value.Alpha
				elseif entry.Field == "TransitionShorthand" then
					style.TransitionProperty,style.TransitionDuration=value.Property,value.Duration
					style.TransitionTiming,style.TransitionDelay=value.Timing,value.Delay
					style.TransitionBehavior=value.Behavior or {"normal"}
				elseif entry.Field == "AnimationShorthand" then
					style.AnimationTimeline={'auto'};style.AnimationRangeStart=nil;style.AnimationRangeEnd=nil
					style.AnimationName,style.AnimationDuration=value.Name,value.Duration
					style.AnimationTiming,style.AnimationDelay=value.Timing,value.Delay
					style.AnimationIteration,style.AnimationDirection=value.Iteration,value.Direction
					style.AnimationFill,style.AnimationPlay=value.Fill,value.Play
				elseif entry.Field=='AnimationRange'then
					style.AnimationRangeStart={};style.AnimationRangeEnd={}
					for _,range in value or{}do table.insert(style.AnimationRangeStart,range.Start);table.insert(style.AnimationRangeEnd,range.Finish)end
				elseif entry.ColorValue then
					style[entry.Field], style[entry.Field .. "Alpha"] = value.Color, value.Alpha
				elseif entry.Field == "Margin" then
					local sides = if logical then {} else nil
					if logical then for _,name in logical do table.insert(sides,logicalIndex(name)) end end
					for order,side in if sides then sides else {entry.Side or 1,entry.Side or 2,entry.Side or 3,entry.Side or 4} do
						if entry.Side and not logical and side~=entry.Side then continue end
						local part = if logical then value[math.min(order,#value)] elseif entry.Side then value else value[side]
						style.MarginAuto[side] = part == "auto"
						style.Margin[side] = if part == "auto" then 0 else part
					end
				elseif entry.Field == "Padding" and logical then
					for order,name in logical do style.Padding[logicalIndex(name)]=value[math.min(order,#value)] end
				elseif (entry.Field=="ScrollPadding" or entry.Field=="ScrollMargin") and logical then
					for order,name in logical do
						local side=logicalIndex(name)
						style[entry.Field][side]=if entry.Wide or entry.LogicalValues then value[math.min(order,#value)]else value
					end
				elseif entry.Field=="OverflowClipMargins" and logical then
					for order,name in logical do
						local side=logicalIndex(name)
						style.OverflowClipMargins[side]=if entry.Wide then value[order] else value
					end
				elseif entry.Field == "Inset" and logical then
					for order,name in logical do
						local part=value[math.min(order,#value)];style[INSET_FIELDS[logicalIndex(name)]]=if part then table.clone(part) else nil
					end
				elseif entry.Field == "BorderRadius" then
					if type(value)~="table" then style.BorderRadius=value or 0;style.BorderRadii=nil;continue end
					style.BorderRadii=style.BorderRadii or {
						{X={Value=style.BorderRadius},Y={Value=style.BorderRadius}},{X={Value=style.BorderRadius},Y={Value=style.BorderRadius}},
						{X={Value=style.BorderRadius},Y={Value=style.BorderRadius}},{X={Value=style.BorderRadius},Y={Value=style.BorderRadius}},
					}
					if entry.Corner or entry.LogicalCorner then
						local corner=entry.Corner
						if entry.LogicalCorner then
							corner=({'top-left','top-right','bottom-right','bottom-left'})[WritingMode.corner(style,entry.LogicalCorner)]
						end
						local index=if corner=="top-left" then 1 elseif corner=="top-right" then 2 elseif corner=="bottom-right" then 3 else 4
						style.BorderRadii[index]=value
					else style.BorderRadii=copyRadii(value) end
				elseif entry.Side then
					style[entry.Field][entry.Side] = value
				elseif entry.Field == "Inset" then
					for side, field in INSET_FIELDS do style[field] = if value[side] then table.clone(value[side]) else nil end
				elseif entry.Field == "Overflow" then
					style.OverflowX, style.OverflowY = value[1], value[2] or value[1]
				elseif entry.Field == "FlexFlow" then
					style.FlexDirection, style.FlexWrap,style.FlexBalance = value.Direction, value.Wrap,value.Balance or false
				elseif entry.Field == "FlexWrap" then
					style.FlexWrap,style.FlexBalance=value.Wrap,value.Balance or false
				elseif entry.Field == "Flex" then
					style.FlexGrow, style.FlexShrink = value.Grow, value.Shrink
					style.FlexBasis = if type(value.Basis) == "table" then table.clone(value.Basis) else value.Basis
				elseif entry.Field=="Width" or entry.Field=="Height" then
					style["UA"..entry.Field.."FitContent"]=false
					style[entry.Field]=if type(value)=="table" then table.clone(value) else value
				else
					style[entry.Field] = if type(value) == "table" then table.clone(value) else value
				end
			end
		end
	end
	-- SVG geometry attributes are presentation hints below every author rule.
	if ElementNames.matches(node,"svg",ElementProfile.SVG) then
		for _,axis in {"width","height"} do
			local value=node.Attributes[axis]
			if value then
				value=value:match("^%s*(.-)%s*$")
				if value:match("^[+]?%d*%.?%d+$") then value=value.."px" end
				-- Do not allow an attribute to inject additional CSS declarations.
				if not value:find("[;{}!]") then apply(InlineStyle.compile(axis..":"..value).Normal) end
			end
		end
	end
	apply(authorRules.Normal); apply(localRules.Normal)
	apply(authorRules.Important); apply(localRules.Important)
	-- This UA declaration is important: author contain:paint/strict must not
	-- retain extra containment effects on an auto-sized image.
	if autoImage then style.Contain={Size=true}end
	style.CornerShape=style.CornerShapes[1]
	for _,shape in style.CornerShapes do if shape~=style.CornerShape then style.CornerShape='mixed';break end end
	if style.BorderRadii then
		local first=style.BorderRadii[1]
		local uniform=not first.X.Percent and not first.Y.Percent and first.X.Value==first.Y.Value
		for index=2,4 do local radius=style.BorderRadii[index];uniform=uniform and not radius.X.Percent and not radius.Y.Percent and radius.X.Value==first.X.Value and radius.Y.Value==first.Y.Value end
		style.BorderRadius=if uniform then first.X.Value else 0
		if uniform and style.BorderRadius==0 then style.BorderRadii=nil end
	end
	ControlDefaults.finishAppearance(style)
	-- The base dropdown's UA-important rule sizes its displayed button content,
	-- even when an author asks for fixed preferred sizing.
	if ElementNames.htmlName(node)=='select'and style.Appearance=='base-select'and node.Attributes.multiple==nil and AttributeValues.positive(node.Attributes.size,1)==1 then style.FieldSizing='content' end
	ColorScheme.apply(node,style)
    for _,entries in orderedRules do
        for _,entry in entries do
            if not entry.Error and entry.Field=='JustifyContent' then style.GridJustifySpecified=true end
        end
    end
	-- Preserve both axes; uncommon pairs are not approximated by another mode.
	style.WhiteSpace=WhiteSpace.serialize(style.WhiteSpaceCollapse or 'collapse',style.TextWrapMode or 'wrap')
	-- A visible axis computes to auto when the other axis establishes a scroll container.
	if style.OverflowX == "visible" and style.OverflowY ~= "visible" and style.OverflowY ~= "clip" then style.OverflowX = "auto" end
	if style.OverflowY == "visible" and style.OverflowX ~= "visible" and style.OverflowX ~= "clip" then style.OverflowY = "auto" end
	if style.OverflowX == "clip" and style.OverflowY ~= "visible" and style.OverflowY ~= "clip" then style.OverflowX = "hidden" end
	if style.OverflowY == "clip" and style.OverflowX ~= "visible" and style.OverflowX ~= "clip" then style.OverflowY = "hidden" end
	-- Preserve the existing combined clipping flag for box/flex sizing.
	style.Overflow = if style.OverflowX == "visible" and style.OverflowY == "visible" then "visible" else "hidden"
	style.ScrollTimelineAxis=style.ScrollTimelineAxes[1] or "block"
	if style.FontSize == "smaller" then style.FontSize = math.max(1, (parent.UnadjustedFontSize or parent.FontSize) / 1.2) end
	if style.FontSize == "larger" then style.FontSize = math.min(100, (parent.UnadjustedFontSize or parent.FontSize) * 1.2) end
	if metricOverrides then
		style.AnimationMetricBase={FontSize=style.FontSize}
		if metricOverrides.FontSize~=nil then style.FontSize=metricOverrides.FontSize end
	end
	style.UnadjustedFontSize=style.FontSize
	if style.FontSize>0 and style.FontSizeAdjust and style.FontSizeAdjust.Kind=="number" then
		style.FontSize=math.clamp(style.FontSize*(style.FontSizeAdjust.Value/.5),1,100)
	end
	style.OpenTypeFeatures=FontFeatures.compile(style)
	style.TabularNums=FontFeatures.tabular(style)
	if ElementNames.htmlName(node)=="dialog" or popover then
		local padding=style.UnadjustedFontSize*(if popover then .25 else 1)
		for side=1,4 do if not paddingSpecified or not paddingSpecified[side] then style.Padding[side]=padding end end
		if uaMaxWidth then style.MaxWidth=InlineStyle.length("calc(100% - 6px - 2em)",style) end
		if uaMaxHeight then style.MaxHeight=InlineStyle.length("calc(100% - 6px - 2em)",style) end
	end
	if ElementNames.htmlName(node) == "fieldset" then
		for side, factor in {.35, .75, .625, .75} do
			if not paddingSpecified or not paddingSpecified[side] then style.Padding[side] = style.FontSize * factor end
		end
	end
	-- Relative default margins depend on the final font size. Only fill sides
	-- untouched by valid author declarations; longhands must not erase other defaults.
	local vertical: number? = nil
	local horizontal = if element then element.MarginInlinePx or 0 else 0
	if element and element.MarginBlockEm then vertical = style.FontSize * element.MarginBlockEm
	elseif ElementNames.htmlName(node) == "hr" then
		vertical = style.FontSize / 2
		-- Native HTML defaults; share normal auto-margin layout, including Flex.
		for _, side in {2, 4} do
			if not marginSpecified or not marginSpecified[side] then style.MarginAuto[side] = true end
		end
	elseif ElementNames.htmlName(node) == "pre" or ElementNames.htmlName(node) == "blockquote" then
		vertical = style.FontSize
		horizontal = if ElementNames.htmlName(node) == "blockquote" then 40 else 0
	elseif listContainer then vertical = if listDepth == 0 then style.FontSize else 0 end
	if vertical and not popover and ElementNames.htmlName(node)~="dialog" then
		for side = 1, 4 do
			if not marginSpecified or not marginSpecified[side] then
				style.Margin[side] = if side == 1 or side == 3 then vertical else horizontal
			end
		end
	end
	style.LegacyGrid=style.Display=="-ms-grid" or style.Display=="-ms-inline-grid"
	if style.LegacyGrid then style.Display=if style.Display=="-ms-grid" then "grid" else "inline-grid" end
	if style.TableRole ~= "column" and style.TableRole ~= "column-group" then style.TableRole=tableRoles[style.Display] end
	style.TableGroupKind=if style.Display == "table-header-group" then "head" elseif style.Display == "table-footer-group" then "foot" else "body"
	style.VisibilityCollapse=style.Visibility == "collapse"
	if style.VisibilityCollapse then style.Visibility="hidden" end
	-- Positioned inline boxes become independent block-level boxes, just like
	-- floats. In particular, a positioned control must leave the text run so
	-- its insets and transforms apply to its own retained native surface.
	if documentRoot and style.Display=='contents'then style.Display='block'end
	if documentRoot or style.Float ~= "none" or style.Position == "absolute" or style.Position == "fixed" then
		if style.Display=="inline" or style.Display=="inline-block" then style.Display="block"
		elseif documentRoot and style.Display=='inline-table'then style.Display='table'
		elseif style.Display=="inline-grid" then style.Display="grid"
		elseif style.Display=="inline-flex" then style.Display="flex" end
	end
	inline = inline or style.Display == "inline"
	style.OpacityGroup = if inline then parent.OpacityGroup else nil
	style.InlineShift = if inline then parent.InlineShift or 0 else 0
	AnimationColors.prepare(style,parent,colorOverrides)
	if shadowOverride then style.AnimationTextShadowBase={Value=style.TextShadows};style.TextShadows=shadowOverride.Value end
	if style.Color == "currentcolor" then style.Color, style.ColorAlpha = parent.Color, parent.ColorAlpha or 1 end
	style.BoxShadows=if style.ShadowSpecified then {}else nil
	if style.MaskImage and (style.MaskMode=='luminance'or style.MaskBorderSource)then style.MaskImage=table.clone(style.MaskImage);style.MaskImage.Kind='layers'end
	if style.MaskImage then for _,repeatMode in style.MaskRepeats do if repeatMode.X=='space'or repeatMode.X=='round'or repeatMode.Y=='space'or repeatMode.Y=='round'then style.MaskImage=table.clone(style.MaskImage);style.MaskImage.Kind='layers';break end end end
	local function shadowPart(values,index)return values[(index-1)%#values+1]end
	for index,offset in style.ShadowOffsets do if offset then
		local tint=shadowPart(style.ShadowColors,index)
		table.insert(style.BoxShadows,{X=offset.X,Y=offset.Y,Blur=shadowPart(style.ShadowBlurs,index),Spread=shadowPart(style.ShadowSpreads,index),Color=tint.Color,Alpha=tint.Alpha,Inset=shadowPart(style.ShadowPositions,index)=='inset'})
	end end
	style.Filter=Filter.resolve(style.Filter,style.Color,style.ColorAlpha or 1)
	if style.Background == "currentcolor" then style.Background, style.BackgroundAlpha = style.Color, style.ColorAlpha end
	if type(style.Background)=='table'and style.Background.SelectUAAlpha then
		style.SelectUAColorBackgroundAlpha=style.Background.SelectUAAlpha
		style.Background,style.BackgroundAlpha=style.Color,(style.ColorAlpha or 1)*style.SelectUAColorBackgroundAlpha
	end
	if topLayer then
		if style.Position~="fixed" and style.Position~="absolute" then style.Position="absolute" end
		if style.Display=="inline" or style.Display=="contents" then style.Display="block" end
	end
	if style.TextEmphasisStyle and style.TextEmphasisStyle.AutomaticShape then
		local emphasis=table.clone(style.TextEmphasisStyle)
		local vertical=style.WritingMode=='vertical-rl'or style.WritingMode=='vertical-lr'
		emphasis.Shape=if vertical then 'sesame'else 'circle'
		emphasis.Mark=if vertical then(if emphasis.Fill=='open'then '﹆'else '﹅')else(if emphasis.Fill=='open'then '○'else '●')
		emphasis.AutomaticShape=nil;style.TextEmphasisStyle=emphasis
	end
	if style.TextEmphasisColor == "currentcolor" then style.TextEmphasisColor,style.TextEmphasisColorAlpha=style.Color,style.ColorAlpha end
	if style.ColumnRuleColor == "currentcolor" then style.ColumnRuleColor,style.ColumnRuleColorAlpha=style.Color,style.ColorAlpha end
	if type(style.CaretColor)=="table" and style.CaretColor.Auto then style.CaretColor,style.CaretColorAlpha=style.Color,style.ColorAlpha end
	if style.CaretColor=="currentcolor" then style.CaretColor,style.CaretColorAlpha=style.Color,style.ColorAlpha end
	style.CaretCustom=style.CaretCustom or style.CaretShape~="auto" or style.CaretAnimation=="manual"
	if style.BackgroundAlpha == 0 then style.Background = nil end
	if style.ContentVisibility=="hidden" and (style.Contain.Size or style.Contain.InlineSize) then
		if not style.Width and style.ContainIntrinsicWidth then style.Width=style.ContainIntrinsicWidth end
		if style.Contain.Size and not style.Height and style.ContainIntrinsicHeight then style.Height=style.ContainIntrinsicHeight end
	end
	local ownBackground = if style.Visibility ~= "hidden" then style.Background else nil
	-- Retain the original inline color calculation for style/layout consumers.
	-- Paint can omit a propagated document-canvas owner without changing these
	-- computed records or losing a descendant's separately authored background.
	style.InlineBackgroundSources=if inline then(if ownBackground then {Node=node,Color=ownBackground,Alpha=style.BackgroundAlpha or 1,Parent=parent.InlineBackgroundSources}else parent.InlineBackgroundSources)else nil
	style.InlineBackground = if inline then ownBackground or parent.InlineBackground else nil
	style.InlineBackgroundAlpha = if inline and ownBackground then style.BackgroundAlpha or 1 else parent.InlineBackgroundAlpha or 1
	if inline and ownBackground and style.InlineBackgroundAlpha < 1 and parent.InlineBackground then
		style.InlineBackground, style.InlineBackgroundAlpha = Color.over(style.Background, style.InlineBackgroundAlpha,
			parent.InlineBackground, parent.InlineBackgroundAlpha or 1)
	end
	if inline and (style.VerticalAlign == "super" or style.VerticalAlign == "sub") then
		local divisor = if style.VerticalAlign == "super" then 3 else 5
		local shift = math.floor((parent.FontSize / divisor + 1) * 64) / 64
		style.InlineShift += if style.VerticalAlign == "super" then -shift else shift
	elseif inline and not replacedInline and not ControlDefaults.kind(node)and style.VerticalAlign~='baseline'and style.VerticalAlign~='top'and style.VerticalAlign~='bottom'then
		local align=style.VerticalAlign;local parentMetrics={Font=parent.Font or style.Font,FontSize=parent.FontSize or 16};local own,ancestor=FontMetrics.resolve(style),FontMetrics.resolve(parentMetrics)
		if align=='text-top'then style.InlineShift+=own.Baseline-ancestor.Baseline
		elseif align=='text-bottom'then style.InlineShift+=own.Baseline+ancestor.TextSize-ancestor.Baseline-own.TextSize
		elseif align=='middle'then style.InlineShift+=own.Baseline-own.TextSize/2-(ancestor.Baseline-ancestor.XHeight)/2
		elseif type(align)=='table'then local extents=FontMetrics.extents(style,own);style.InlineShift-=LengthExpression.resolve(align,extents.Ascent+extents.Descent)end
	end
	if style.OutlineColor == "currentcolor" then style.OutlineColor, style.OutlineColorAlpha = style.Color, style.ColorAlpha end
	local function usedBorderWidth(value)
		return if value<=0 then 0 else math.max(1,math.floor(value))
	end
	if style.BorderSides then
		style.BorderSizes, style.BorderUniform = {}, true
		local first = style.BorderSides[1]
		for side, edge in style.BorderSides do
			if edge.Color == "currentcolor" then edge.Color, edge.Alpha = style.Color, style.ColorAlpha end
			style.BorderSizes[side] = if edge.Style == "none" or edge.Style == "hidden" then 0 else usedBorderWidth(edge.Width)
			if edge.Width ~= first.Width or edge.Style ~= first.Style or edge.Color ~= first.Color or edge.Alpha ~= first.Alpha then style.BorderUniform = false end
		end
		style.BorderWidth, style.BorderStyle, style.BorderColor, style.BorderColorAlpha = first.Width, first.Style, first.Color, first.Alpha
		style.BorderSize = style.BorderSizes[1]
	else
		style.BorderSize = if style.BorderStyle == "none" or style.BorderStyle == "hidden" then 0 else usedBorderWidth(style.BorderWidth)
		if style.BorderColor == "currentcolor" then style.BorderColor, style.BorderColorAlpha = style.Color, style.ColorAlpha end
	end
	-- Percentages inherit as computed pixels; unitless numbers remain multipliers.
	-- Resolve after every declaration so font-size/line-height order is irrelevant.
	if metricOverrides then
		local authored=style.LineHeight
		if authored.Kind=='percent'then authored={Kind='px',Value=style.FontSize*authored.Value/100}
		elseif authored.Kind=='length'then authored={Kind='px',Value=LengthExpression.resolve(authored.Length,style.FontSize)}end
		style.AnimationMetricBase.LineHeight=authored
		if metricOverrides.LineHeight then
			local value=metricOverrides.LineHeight
			style.LineHeight=if value.Kind=='relative'then {Kind='px',Value=math.max(0,value.Pixels+value.Em*style.FontSize)}elseif value.Kind=='number'or value.Kind=='px'then {Kind=value.Kind,Value=math.max(0,value.Value)}else value
		end
	end
	if style.LineHeight.Kind == "percent" then
		style.LineHeight = { Kind = "px", Value = style.FontSize * style.LineHeight.Value / 100 }
	elseif style.LineHeight.Kind == "length" then
		style.LineHeight = {Kind="px",Value=LengthExpression.resolve(style.LineHeight.Length,style.FontSize)}
	end
	ControlDefaults.finishSelectPart(style,selectPartMetrics,paddingSpecified)
	ControlDefaults.finishBaseSelect(style,baseSelectMetrics,paddingSpecified)
	if baseListHeight and style.Height==baseListHeight then
		local lh=style.LineHeight;local line=if lh.Kind=='px'then lh.Value elseif lh.Kind=='number'then lh.Value*style.FontSize else style.FontSize*1.2
		style.Height={Value=math.max(24,line)*math.clamp(AttributeValues.positive(node.Attributes.size,4),1,100)}
		if style.FieldSizing=='content'then style.Height=nil end
	end
	-- Decorations propagate through descendants. A child's 'none' cannot remove
	-- an ancestor's line; color and thickness belong to the originating element.
	style.Decorations = if quirks and htmlNamespace and ElementNames.htmlName(node)=='table'then NO_DECORATIONS else parent.Decorations or NO_DECORATIONS
	if style.Visibility ~= "hidden" and style.TextDecoration and next(style.TextDecoration) then
		-- Shared auto approximation fitted to 41/62/82 px transitions.
		-- Use CSS size, without Roblox's per-font text-size correction.
		local thickness = math.floor(style.FontSize * 0.049)
		if style.DecorationThickness then
			local value = style.DecorationThickness
			thickness = LengthExpression.resolve(value,style.FontSize)
		end
		local originMetrics=FontMetrics.resolve(style)
		local position=style.UnderlinePosition or 'auto'
		local under=position:match('^under')~=nil
		local offset = math.max(1, math.round(style.FontSize / 14))
		local rawOffset=0
		if style.UnderlineOffset then
			local value = style.UnderlineOffset
			rawOffset=math.round(LengthExpression.resolve(value,style.FontSize));offset=rawOffset
		end
		-- Under positions use the content edge as zero, even with a specified
		-- zero/negative offset. Font-dependent edge metrics remain estimated.
		if under then offset=originMetrics.TextSize-originMetrics.Baseline+1+(if style.UnderlineOffset then rawOffset else 0)end
		style.Decorations = table.clone(style.Decorations)
		table.insert(style.Decorations, table.freeze({
			Underline = style.TextDecoration.Underline, Strike = style.TextDecoration.Strike, Overline = style.TextDecoration.Overline,
			SkipInk = style.SkipInk,
			Style = style.DecorationStyle or "solid",
			Color = if style.DecorationColor and style.DecorationColor ~= "currentcolor" then style.DecorationColor else style.Color,
			Alpha = if style.DecorationColor and style.DecorationColor ~= "currentcolor" then style.DecorationColorAlpha or 1 else style.ColorAlpha,
			Thickness = math.max(1, math.round(thickness)),
			OriginFontSize=style.FontSize,OriginBaseline=originMetrics.Baseline,OriginShift=style.InlineShift or 0,
			OriginOrientation=style.TextOrientation,UnderlinePosition=position,RawUnderlineOffset=rawOffset,
			UnderlineOffset = offset, StrikeOffset = -math.round(style.FontSize / 4),
			-- Keep the originating font's estimated ascent across nested font changes.
			OverlineOffset = if style.TextDecoration.Overline then -originMetrics.Baseline else nil,
		}))
	end
	-- Keep Ruby's derived placement in the computed style, so media/state
	-- recascades produce the same layout as the initial render-tree build.
	if ElementNames.htmlName(node)=="ruby" then
		style.TextAlign=if style.RubyAlign=="start" then "start" else "center"
	elseif ElementNames.htmlName(node)=="rt" then
		local row=if style.RubyPosition=="under" then 2 else 1
		style.GridRowStart,style.GridRowEnd=GridValues.line(tostring(row)),GridValues.line(tostring(row+1))
	end
	style.MarginValues, style.PaddingValues = table.clone(style.Margin), table.clone(style.Padding)
	style.PositionTryDefinitions={};local tryKeys={}
	for _,recipe in style.PositionTryFallbacks do
		local definition=recipe.Name and authorRules.PositionTries and authorRules.PositionTries[recipe.Name]
		if definition then style.PositionTryDefinitions[recipe.Name]=definition;table.insert(tryKeys,#recipe.Name..':'..recipe.Name..':'..#definition.Source..':'..definition.Source)end
	end
	style.PositionTryKey=table.concat(tryKeys,';')
	if next(style.PositionTryDefinitions)then
		style.PositionTryResolve=function(declarations)
			local override=table.clone(unresolvedAuthorRules)
			override.Normal=table.clone(unresolvedAuthorRules.Normal);override.Important=table.clone(unresolvedAuthorRules.Important);override.InlineIncluded=true
			for _,entry in unresolvedLocalRules.Normal do table.insert(override.Normal,entry)end
			for _,entry in declarations.Normal do table.insert(override.Normal,entry)end
			for _,entry in unresolvedLocalRules.Important do table.insert(override.Important,entry)end
			return InlineStyle.resolve(node,parent,warnStyle,false,override,nil,nil,nil,dimensionSource)
		end
	end
	style.ContainingDirection=parent.Direction or 'ltr'
	style.HasAnchorFunctions=false
	for _,field in {'Width','Height','MinWidth','MaxWidth','MinHeight','MaxHeight','Insettop','Insetright','Insetbottom','Insetleft'}do
		local length=style[field]
		if type(length)=='table'and (length.Kind=='anchor-expression'or length.Kind=='anchor')then style.HasAnchorFunctions=true;break end
	end
	for _,length in style.MarginValues do if type(length)=='table'and length.Kind=='anchor-expression'then style.HasAnchorFunctions=true;break end end
	if style.HasAnchorFunctions and style.Position~='absolute'and style.Position~='fixed'then
		local containing={Width=0,Height=0,Style=parent}
		style=AnchorPosition.usedStyle(style,{},containing,false)
		for _,side in {'top','right','bottom','left'}do style['Inset'..side]=AnchorPosition.resolve(style['Inset'..side],side,{},containing,style,nil,false)end
	end
	if style.Display=='inline' then
		local supported=(style.BorderRadius or 0)==0 and #(style.BoxShadows or {})==0 and (style.Opacity or 1)==1 and not parent.InlineFragment
		for _,image in style.BackgroundImages or {} do if image.Kind~='none' then supported=false end end
		style.BoxDecorationSupported=supported
		if style.BoxDecorationSpecified and not supported then warnStyle('box-decoration-break: inline fragments currently require plain backgrounds, straight borders and no nested decoration or inline opacity')end
	end
	-- The fragment owner clears its own word background when RenderTree binds
	-- it. A descendant's separate background must still paint above that box.
	if style.BorderShape then
		local incompatible=style.BorderUniform==false or (style.BorderStyle~='solid' and style.BorderStyle~='none') or style.BorderImageSource or #(style.BoxShadows or {})>0 or style.Overflow=='hidden'
		for _,image in style.BackgroundImages or {} do if image.Kind~='none' then incompatible=true end end
		if incompatible then warnStyle('border-shape: circle currently requires a uniform solid border, plain background and visible overflow');style.BorderShape=nil end
	end
	-- An audio element without exposed controls has no visual box, even when
	-- author CSS requests one. Playback is owned separately from the renderer.
	if ElementNames.htmlName(node)=="audio"and node.Attributes.controls==nil then style.Display="none";style.Hidden=true end
	-- SVG2 style text is never rendered, with UA priority over author display.
	if ElementNames.matches(node,'style',ElementNames.SVG)then style.Display='none';style.Hidden=true end
	-- Unlike the normal [hidden] rule, input[type=hidden] is UA !important.
	if htmlNamespace and ElementNames.htmlName(node)=='input'and ControlDefaults.kind(node)=='hidden'then style.Display='none';style.Hidden=true end
	if quirks and htmlNamespace and ElementNames.htmlName(node)=='body'and node.Parent and ElementNames.htmlName(node.Parent)=='html'
		and node.Parent.Parent and node.Parent.Parent.Kind=='Document'then
		style.QuirksBodyColor,style.QuirksBodyAlpha,style.QuirksBodyDefault=style.Color,style.ColorAlpha,style.ColorIsDefault
	end
	-- Scope links are semantic boundaries, not inherited unicode-bidi values.
	-- A block's root inline context is trimmed by BidiInline at each word run.
	style.BidiContext=parent.BidiContext
	if style.UnicodeBidi~='normal'then style.BidiContext={Node=node,Mode=style.UnicodeBidi,Direction=style.Direction,Parent=parent.BidiContext}end
	if node.FullscreenFlag then
		-- Fullscreen UA-important geometry; author paint and content remain live.
		style.Position='fixed';style.Insettop,style.Insetright,style.Insetbottom,style.Insetleft={Value=0},{Value=0},{Value=0},{Value=0}
		style.Margin={0,0,0,0};style.MarginAuto={false,false,false,false};style.BoxSizing='border-box'
		style.Width=InlineStyle.length('100%',style);style.Height=InlineStyle.length('100%',style)
		style.MinWidth,style.MinHeight={Value=0},{Value=0};style.MaxWidth,style.MaxHeight=nil,nil;style.Transform=nil
		if style.Display=='inline'or style.Display=='inline-block'then style.Display='block'end
	end
	return style
end

return InlineStyle
