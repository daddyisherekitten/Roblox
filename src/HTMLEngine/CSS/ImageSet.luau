--!strict
-- CSS density candidates. Selection is separate from parsing and resource IO.
local Syntax=require(script.Parent.Syntax)
local Prelude=require(script.Parent.StylesheetPrelude)
local Set={}
function Set.parse(source,parseImage)
	local name,body=source:match('^([%a%-]+)%((.*)%)$');if not name or(name:lower()~='image-set'and name:lower()~='-webkit-image-set')then return nil end
	local candidates={};local cursor=1
	while cursor<=#body do
		local part,after,delimiter=Syntax.scan(body,cursor,',');cursor=after;part=part:match('^%s*(.-)%s*$')
		local image,rest
		if part:sub(1,1)=='"'or part:sub(1,1)=="'"then local url;url,rest=Prelude.url(part);if url then image={Kind='url',Source=url}end
		else local value,index=Syntax.scan(part,1,' \t\r\n');image=parseImage(value);rest=part:sub(index):match('^%s*(.-)%s*$')end
		if not image or image.Kind=='none'or image.Kind=='image-set'then return nil end
		local density,mime=1,nil;local seenDensity=false
		while rest~=''do
			local token,index=Syntax.scan(rest,1,' \t\r\n');rest=rest:sub(index):match('^%s*(.-)%s*$')
			local kind=token:match('^[Tt][Yy][Pp][Ee]%((.*)%)$')
			if kind then if mime then return nil end;local remaining;mime,remaining=Prelude.url(kind);if not mime or remaining~=''or not kind:match('^%s*["\']')then return nil end;mime=mime:lower()
			else local n,unit=token:lower():match('^([%d%.]+)(%a+)$');n=tonumber(n);if seenDensity or not n or n<=0 then return nil end
				if unit=='x'or unit=='dppx'then density=n elseif unit=='dpi'then density=n/96 elseif unit=='dpcm'then density=n*2.54/96 else return nil end;seenDensity=true
			end
		end
		table.insert(candidates,{Image=image,Density=density,Type=mime});if #candidates>16 then return nil end
		if delimiter~=''and cursor>#body then return nil end
	end
	return if #candidates>0 then {Kind='image-set',Candidates=candidates}else nil
end
function Set.select(value,resolution,supportsType)
	if value.Kind~='image-set'then return value,1 end
	resolution=resolution or 1;local best,largest
	for _,candidate in value.Candidates do
		if candidate.Type and (not supportsType or not supportsType(candidate.Type))then continue end
		if not largest or candidate.Density>largest.Density then largest=candidate end
		if candidate.Density>=resolution and (not best or candidate.Density<best.Density)then best=candidate end
	end
	best=best or largest;return if best then best.Image else {Kind='none'},if best then best.Density else 1
end
return Set
