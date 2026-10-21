--!strict
-- HTML's byte prescan is deliberately distinct from tokenization: no entity
-- expansion, ASCII attribute folding, first duplicates, and a 1024-byte bound.
local Decoder=require(script.Parent.Parent.Encoding.Decoder)
local Sniff={}
local function lower(value)return(value:gsub('[A-Z]',string.lower))end
local function white(byte)return byte==9 or byte==10 or byte==12 or byte==13 or byte==32 end
function Sniff.content(value)
	local source=lower(value);local position=1
	while true do
		local found=source:find('charset',position,true);if not found then return nil end
		position=found+7;while white(source:byte(position))do position+=1 end
		if source:byte(position)~=61 then continue end
		position+=1;while white(source:byte(position))do position+=1 end
		local quote=source:byte(position);if not quote then return nil end
		if quote==34 or quote==39 then local finish=source:find(string.char(quote),position+1,true);return if finish then Decoder.label(source:sub(position+1,finish-1))else nil end
		local finish=position;while finish<=#source and not white(source:byte(finish))and source:byte(finish)~=59 do finish+=1 end
		return Decoder.label(source:sub(position,finish-1))
	end
end
local function declared(encoding)
	return if encoding=='utf-16le'or encoding=='utf-16be'then 'utf-8'elseif encoding=='x-user-defined'then 'windows-1252'else encoding
end
function Sniff.meta(attributes)
	local encoding=if attributes.charset~=nil then Decoder.label(attributes.charset)else nil
	if not encoding and lower(attributes['http-equiv']or'')=='content-type'and attributes.content then encoding=Sniff.content(attributes.content)end
	return declared(encoding)
end
local function xml(source)
	if source:sub(1,5)~='<?xml'then return nil end
	local finish=source:find('>',6,true);if not finish then return nil end
	local found=source:find('encoding',1,true);if not found or found>=finish then return nil end
	local position=found+8
	while position<=#source and source:byte(position)<=32 do position+=1 end
	if source:byte(position)~=61 then return nil end;position+=1
	while position<=#source and source:byte(position)<=32 do position+=1 end
	local quote=source:byte(position);if quote~=34 and quote~=39 then return nil end
	local after=source:find(string.char(quote),position+1,true);if not after then return nil end
	local label=source:sub(position+1,after-1);if label:find('[%z\1-\32]')then return nil end
	local encoding=Decoder.label(label)
	return if encoding=='utf-16le'or encoding=='utf-16be'then 'utf-8'else encoding
end
function Sniff.prescan(bytes)
	local source=bytes:sub(1,1024);local length=#source
	if source:sub(1,6)=='<\0?\0x\0'then return 'utf-16le'end
	if source:sub(1,6)=='\0<\0?\0x'then return 'utf-16be'end
	local position=1
	local function attribute()
		while white(source:byte(position))or source:byte(position)==47 do position+=1 end
		if position>length then return nil,nil,true end
		if source:byte(position)==62 then return nil end
		local start=position
		while position<=length do
			local byte=source:byte(position)
			if byte==61 and position>start or white(byte)or byte==47 or byte==62 then break end;position+=1
		end
		if position>length then return nil,nil,true end
		local name=lower(source:sub(start,position-1))
		while white(source:byte(position))do position+=1 end
		if position>length then return nil,nil,true end
		if source:byte(position)~=61 then return name,''end;position+=1
		while white(source:byte(position))do position+=1 end
		if position>length then return nil,nil,true end
		local quote=source:byte(position)
		if quote==34 or quote==39 then
			local after=source:find(string.char(quote),position+1,true);if not after then return nil,nil,true end
			local value=lower(source:sub(position+1,after-1));position=after+1;return name,value
		end
		start=position;while position<=length and not white(source:byte(position))and source:byte(position)~=62 do position+=1 end
		if position>length then return nil,nil,true end
		return name,lower(source:sub(start,position-1))
	end
	while position<=length do
		if source:sub(position,position+3)=='<!--'then
			local after=source:find('-->',position+2,true);if not after then return xml(source)end;position=after+2
		elseif lower(source:sub(position,position+4))=='<meta'and(white(source:byte(position+5))or source:byte(position+5)==47)then
			position+=5;local seen={};local gotPragma,needPragma,encoding=false,nil,nil
			while true do
				local name,value,incomplete=attribute();if incomplete then return xml(source)end;if not name then break end
				if seen[name]then continue end;seen[name]=true
				if name=='http-equiv'then gotPragma=value=='content-type'
				elseif name=='content'and encoding==nil then local candidate=Sniff.content(value);if candidate then encoding=candidate;needPragma=true end
				elseif name=='charset'then encoding=Decoder.label(value)or false;needPragma=false end
			end
			if needPragma~=nil and (not needPragma or gotPragma)and encoding then return declared(encoding)end
		elseif source:byte(position)==60 then
			local offset=if source:byte(position+1)==47 then 2 else 1;local first=source:byte(position+offset)
			if first and (first>=65 and first<=90 or first>=97 and first<=122)then
				position+=offset+1
				while position<=length and not white(source:byte(position))and source:byte(position)~=62 do position+=1 end
				while true do local name,_,incomplete=attribute();if incomplete then return xml(source)end;if not name then break end end
			elseif source:byte(position+1)==33 or source:byte(position+1)==47 or source:byte(position+1)==63 then
				local after=source:find('>',position+2,true);if not after then return xml(source)end;position=after
			end
		end
		position+=1
	end
	return xml(source)
end
function Sniff.detect(bytes,options)
	if bytes:sub(1,3)=='\239\187\191'then return 'utf-8','certain','bom'
	elseif bytes:sub(1,2)=='\255\254'then return 'utf-16le','certain','bom'
	elseif bytes:sub(1,2)=='\254\255'then return 'utf-16be','certain','bom'end
	local override=options.OverrideEncoding and Decoder.label(options.OverrideEncoding)
	if override then return override,'certain','override'end
	local transport=options.TransportEncoding and Decoder.label(options.TransportEncoding)
	if transport then return transport,'certain','transport'end
	local prescan=Sniff.prescan(bytes);if prescan then return prescan,'tentative','prescan'end
	local parent=options.ParentSameOrigin==true and options.ParentEncoding and Decoder.label(options.ParentEncoding)
	if parent and parent~='utf-16le'and parent~='utf-16be'then return parent,'tentative','parent'end
	local encoding=if options.DefaultEncoding then Decoder.label(options.DefaultEncoding)else 'windows-1252'
	assert(encoding,'Invalid DefaultEncoding');return encoding,'tentative','default'
end
return Sniff
