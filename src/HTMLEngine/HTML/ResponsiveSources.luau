--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local Queries=require(script.Parent.Parent.CSS.MediaQueries)
local Tokens=require(script.Parent.Parent.CSS.MediaSyntax)
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Work=require(script.Parent.Parent.WorkContext)
-- Source parsing follows the frozen HTML algorithm. Candidate choice remains
-- deterministic: first duplicate wins, then smallest density meeting the target.
local ResponsiveSources = {}
-- Only primitive sizes belong to these weak node keys, never a page or realm.
-- A hidden/adopted image retains its last observed auto width; clones start empty.
local autoWidths=setmetatable({},{__mode='k'})
function ResponsiveSources.autoKeyword(value: string?): boolean
	if value==nil then return false end
	local folded=value:gsub('[A-Z]',string.lower)
	return folded=='auto'or folded:sub(1,5)=='auto,'
end
function ResponsiveSources.allowsAuto(image: any): boolean
	return ElementNames.html(image,'img')and(image.Attributes.loading or''):gsub('[A-Z]',string.lower)=='lazy'
		and ResponsiveSources.autoKeyword(image.Attributes.sizes)
end
function ResponsiveSources.publishAutoSize(image: any,width: number?): boolean
	if type(width)~='number'or width~=width or width<0 or width==math.huge then return false end
	local changed=autoWidths[image]~=width;autoWidths[image]=width;return changed
end
function ResponsiveSources.autoSize(image: any): number? return autoWidths[image]end
function ResponsiveSources.deviceDensity(view: any?): number
	view=view or{};local env=view.Environment or{}
	return view.Density or view.Resolution or env.Density or env.Resolution or 1
end
-- Decoded resource pixels are shared; each IMG applies its own source density.
-- Keep the Chromium-compatible finite intrinsic-size cap for valid zero-x
-- candidates instead of introducing infinities into the retained layout.
function ResponsiveSources.intrinsicSize(width: number?,height: number?,density: number?): (number?,number?)
	local scale=density or 1
	local function axis(value)
		if value==nil then return nil end
		if value==0 or scale==math.huge then return 0 end
		if scale==0 then return 33554431 end
		return math.min(33554431,value/scale)
	end
	return axis(width),axis(height)
end
local function trim(value: string): string return value:match("^%s*(.-)%s*$") :: string end
local function asciiSpace(char: string): boolean return char==' 'or char=='\t'or char=='\n'or char=='\r'or char=='\f'end
local function environment(width: number,view: any?): any
	view=view or{};local result=table.clone(view.Environment or view)
	result.Width=width;result.Height=view.Height or result.Height or 0
	result.Resolution=view.Density or result.Resolution or 1
	return result
end
function ResponsiveSources.mediaMatches(media: string?,viewportWidth: number,view: any?): boolean
	if media==nil then return true end
	return Queries.matches(Queries.compile(media),environment(viewportWidth,view))
end
local mathFunctions={calc=true,min=true,max=true,clamp=true}
local function mathValue(token: any): string?
	if token.Kind=='percentage'then return nil end
	if token.Kind=='number'then return tostring(token.Value)end
	if token.Kind=='dimension'then return tostring(token.Value)..token.Unit end
	if token.Kind=='delim'and(token.Value=='+'or token.Value=='-'or token.Value=='*'or token.Value=='/'or token.Value==',')then return token.Value end
	local functionBody=token.Kind=='function'and mathFunctions[token.Value]
	if functionBody or token.Kind=='block'and token.Open=='('then
		local parts={};for _,part in token.Items do local value=mathValue(part);if not value then return nil end;table.insert(parts,value)end
		return (if functionBody then token.Value else '')..'('..table.concat(parts,' ')..')'
	end
	return nil
end
local function slotSize(sizes: string?,width: number,view: any?,image: any?): number
	local tokens=Tokens.parse(sizes or'');if not tokens then return width end
	local env=environment(width,view)
	local context={ViewportWidth=width,ViewportHeight=env.Height,FontSize=env.InitialFontSize or 16,RootFontSize=env.InitialFontSize or 16}
	for _,prefix in {'Small','Large','Dynamic'}do for _,axis in {'Width','Height'}do context[prefix..'Viewport'..axis]=env[prefix..'Viewport'..axis]end end
	for _,parts in Tokens.parts(tokens)do
		local last=parts[#parts];if not last then continue end
		local pixels
		if last.Kind=='ident'and last.Value=='auto'then
			if image and ResponsiveSources.allowsAuto(image)then pixels=autoWidths[image]end
		else
			local value=mathValue(last);if not value then continue end
			local parsed=Length.parse(value,context);if not parsed or parsed.Percent then continue end
			pixels=Length.resolve(parsed,0)
			if pixels<0 then if last.Kind=='function'then pixels=0 else continue end end
		end
		if pixels==nil then continue end
		table.remove(parts)
		if #parts==0 then return pixels end
		local condition=Queries.compileCondition(Tokens.raw(parts));if condition and Queries.matchesCondition(condition,env)then return pixels end
	end
	return width
end
local function floating(raw: string): number?
	local significand=raw
	if raw:find('[eE]')then
		local first=raw:match('^(.-)[eE][+%-]?%d+$');if not first then return nil end;significand=first
	end
	if not significand:match('^%-?%d+$')and not significand:match('^%-?%d*%.%d+$')then return nil end
	local value=tonumber(raw);return if value and value>=0 and value<math.huge then value else nil
end
local function candidate(source: string): any?
	local index=1
	while index<=#source and not asciiSpace(source:sub(index,index))do index+=1 end
	local url=source:sub(1,index-1);if url==''then return nil end
	local width,density,height
	for descriptor in source:sub(index):gmatch('[^ \t\n\r\f]+')do
		local raw,kind=descriptor:match('^(.-)([wxh])$');if not raw then return nil end
		if kind=='x'then
			local value=floating(raw);if value==nil or width~=nil or density~=nil or height~=nil then return nil end;density=value
		else
			if not raw:match('^%d+$')then return nil end;local value=tonumber(raw)
			if not value or value<=0 or value==math.huge then return nil end
			if kind=='w'then if width~=nil or density~=nil then return nil end;width=value
			else if height~=nil or density~=nil then return nil end;height=value end
		end
	end
	if height~=nil and width==nil then return nil end
	return {URL=url,Width=width,Density=density}
end
local function candidateParts(source: string): {string}
	-- URL commas are collected until ASCII whitespace. Only trailing commas or
	-- descriptor-state commas separate candidates; parens preserve recovery.
	local parts,index={},1
	while index<=#source do
		Work.checkpoint()
		while index<=#source and(asciiSpace(source:sub(index,index))or source:sub(index,index)==',')do index+=1 end
		if index>#source then break end
		local start=index
		while index<=#source and not asciiSpace(source:sub(index,index))do if index%256==0 then Work.checkpoint()end;index+=1 end
		local url=source:sub(start,index-1)
		if url:sub(-1)==','then table.insert(parts,(url:gsub(',+$','')))
		else
			local descriptorStart=index;local parenthesized=false
			while index<=#source do
				if index%256==0 then Work.checkpoint()end
				local char=source:sub(index,index)
				if char==','and not parenthesized then break end
				if char=='('then parenthesized=true elseif char==')'then parenthesized=false end;index+=1
			end
			table.insert(parts,url..source:sub(descriptorStart,index-1));index+=1
		end
	end
	return parts
end
function ResponsiveSources.fromSrcset(srcset: string?,sizes: string?,viewportWidth: number,density: number?,defaultSource: string?,view: any?,image: any?): (string?,number?)
	local choices={};local hasWidth,hasOne=false,false
	for _,part in candidateParts(srcset or'')do
		local entry=candidate(part)
		if entry then table.insert(choices,entry);hasWidth=hasWidth or entry.Width~=nil;hasOne=hasOne or entry.Density==1 end
	end
	if defaultSource and defaultSource~=''and not hasWidth and not hasOne then table.insert(choices,{URL=defaultSource})end
	if #choices==0 then return nil end
	local size=slotSize(sizes,viewportWidth,view,image);local wanted=density or 1
	local seen={};local best,largest
	for _,entry in choices do
		local normalized=entry.Density or(if entry.Width then entry.Width/size else 1)
		if seen[normalized]then continue end;seen[normalized]=true;entry.Density=normalized
		if not largest or normalized>largest.Density then largest=entry end
		if normalized>=wanted and(not best or normalized<best.Density)then best=entry end
	end
	local selected=best or largest;return selected.URL,selected.Density
end

-- Qualification profile for mapped static images and prepared SVG. This
-- table describes recognized source hints, not native decoding of every format.
-- Missing/empty hints retain the native Chromium compatibility behavior.
local imageTypes={
	["image/png"]=true,["image/jpeg"]=true,["image/jpg"]=true,
	["image/svg+xml"]=true,["image/gif"]=true,["image/webp"]=true,
	["image/avif"]=true,["image/bmp"]=true,["image/x-icon"]=true,
	["image/vnd.microsoft.icon"]=true,
}
local function supportedType(value: string?): boolean
	if value == nil or trim(value) == "" then return true end
	local mediaType = trim(value):lower():match("^([^;]+)")
	return mediaType ~= nil and imageTypes[trim(mediaType)]==true
end

function ResponsiveSources.forImage(image: any, viewportWidth: number, density: number?,view: any?): (string,number?,any?)
	local parent = image.Parent
	if parent and ElementNames.html(parent,"picture") then
		for _, node in parent.Children do
			if node == image then break end
			if node.Kind == "Element" and ElementNames.html(node,"source") and supportedType(node.Attributes.type)
				and ResponsiveSources.mediaMatches(node.Attributes.media, viewportWidth,view) then
				local sizes=node.Attributes.sizes
				if sizes==nil and ResponsiveSources.allowsAuto(image)then sizes='auto'end
				local selected,sourceDensity = ResponsiveSources.fromSrcset(node.Attributes.srcset, sizes, viewportWidth, density,nil,view,image)
				if selected then return selected,sourceDensity,if node.Attributes.width~=nil or node.Attributes.height~=nil then node else image end
			end
		end
	end
	local selected,sourceDensity=ResponsiveSources.fromSrcset(image.Attributes.srcset,image.Attributes.sizes,viewportWidth,density,image.Attributes.src,view,image)
	return selected or "",sourceDensity,image
end

return ResponsiveSources
