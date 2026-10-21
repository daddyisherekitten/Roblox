--!strict
-- CSS font feature subset backed by Roblox GuiText.OpenTypeFeatures.
local FontFeatures = {}

local SUPPORTED = table.freeze({zero=true,ss03=true,liga=true,calt=true,kern=true,smcp=true,c2sc=true,sups=true,subs=true,tnum=true})
local ORDER = table.freeze({"zero","ss03","liga","calt","kern","smcp","c2sc","sups","subs"})

local function trim(value: string): string
	return value:match("^%s*(.-)%s*$") or ""
end

function FontFeatures.settings(value: string): any?
	if value == "normal" then return {} end
	local result,seen={},{}
	for part in value:gmatch("[^,]+") do
		part=trim(part)
		local quote,tag,suffix=part:match("^(['\"])(....)%1%s*(.-)%s*$")
		if not quote or not SUPPORTED[tag] then return nil end
		local enabled
		if suffix=="" then enabled=true
		elseif suffix:match("^%d+$") then
			local number=tonumber(suffix)
			if not number or number>65535 then return nil end
			enabled=number~=0
		else return nil end
		if seen[tag] then return nil end
		seen[tag]=true
		table.insert(result,{Tag=tag,Enabled=enabled})
	end
	return if #result>0 then result else nil
end

function FontFeatures.numeric(value: string): any?
	if value=="normal" then return false end
	if value=="slashed-zero" then return true end
	local result={SlashedZero=false,TabularNums=false,LiningNums=false}
	local seen={}
	for token in value:gmatch("%S+") do
		local field=if token=="slashed-zero" then "SlashedZero" elseif token=="tabular-nums"or token=='proportional-nums' then "TabularNums" elseif token=="lining-nums" then "LiningNums" else nil
		if not field or seen[field] then return nil end
		seen[field],result[field]=true,token~='proportional-nums'
	end
	return if next(seen) then result else nil
end

function FontFeatures.tabular(style: any): boolean
	local numeric=style.FontVariantNumeric
	local enabled=type(numeric)=="table" and numeric.TabularNums==true
	for _,feature in style.FontFeatureSettings or {} do
		if feature.Tag=="tnum" then enabled=feature.Enabled end
	end
	return enabled
end

function FontFeatures.ligatures(value: string): any?
	if value=="normal" then return {Liga=true,Calt=true} end
	if value=="none" then return {Liga=false,Calt=false} end
	local result={Liga=true,Calt=true}
	local seen={}
	for token in value:gmatch("%S+") do
		local field,enabled
		if token=="common-ligatures" then field,enabled="Liga",true
		elseif token=="no-common-ligatures" then field,enabled="Liga",false
		elseif token=="contextual" then field,enabled="Calt",true
		elseif token=="no-contextual" then field,enabled="Calt",false
		else return nil end
		if seen[field] then return nil end
		seen[field],result[field]=true,enabled
	end
	return if next(seen) then result else nil
end

function FontFeatures.kerning(value: string): any?
	if value=="auto" or value=="normal" then return true end
	if value=="none" then return false end
	return nil
end

function FontFeatures.caps(value: string): any?
	if value=="normal" then return {Smcp=false,C2sc=false} end
	if value=="small-caps" then return {Smcp=true,C2sc=false} end
	if value=="all-small-caps" then return {Smcp=true,C2sc=true} end
	return nil
end

function FontFeatures.position(value: string): any?
	if value=="normal" then return {Sups=false,Subs=false} end
	if value=="super" then return {Sups=true,Subs=false} end
	if value=="sub" then return {Sups=false,Subs=true} end
	return nil
end

function FontFeatures.expand(name: string,value: string): any?
	if name~="font-variant" then return nil end
	if value=="inherit" or value=="initial" or value=="unset" then
		return {{Name="font-variant-ligatures",Value=value},{Name="font-variant-numeric",Value=value},
			{Name="font-variant-caps",Value=value},{Name="font-variant-position",Value=value}}
	end
	if value=="normal" then
		return {{Name="font-variant-ligatures",Value="normal"},{Name="font-variant-numeric",Value="normal"},
			{Name="font-variant-caps",Value="normal"},{Name="font-variant-position",Value="normal"}}
	end
	if value=="none" then
		return {{Name="font-variant-ligatures",Value="none"},{Name="font-variant-numeric",Value="normal"}}
	end
	local ligatures,numeric={},{}
	for token in value:gmatch("%S+") do
		if token=="slashed-zero" or token=="tabular-nums" or token=="lining-nums" then
			table.insert(numeric,token)
		elseif token=="common-ligatures" or token=="no-common-ligatures" or token=="contextual" or token=="no-contextual" then
			table.insert(ligatures,token)
		else return nil end
	end
	local ligatureValue=if #ligatures>0 then table.concat(ligatures," ") else "normal"
	if not FontFeatures.ligatures(ligatureValue) then return nil end
	local numericValue=if #numeric>0 then table.concat(numeric," ") else "normal"
	if FontFeatures.numeric(numericValue)==nil then return nil end
	return {{Name="font-variant-ligatures",Value=ligatureValue},{Name="font-variant-numeric",Value=numericValue}}
end

function FontFeatures.compile(style: any): string
	local values={
		zero=style.FontVariantNumeric==true or (type(style.FontVariantNumeric)=="table" and style.FontVariantNumeric.SlashedZero==true),
		liga=not style.FontVariantLigatures or style.FontVariantLigatures.Liga~=false,
		calt=not style.FontVariantLigatures or style.FontVariantLigatures.Calt~=false,
		kern=style.FontKerning~=false,
		smcp=style.FontVariantCaps and style.FontVariantCaps.Smcp or false,
		c2sc=style.FontVariantCaps and style.FontVariantCaps.C2sc or false,
		sups=style.FontVariantPosition and style.FontVariantPosition.Sups or false,
		subs=style.FontVariantPosition and style.FontVariantPosition.Subs or false,
	}
	local present={zero=true,liga=true,calt=true,kern=true,smcp=true,c2sc=true,sups=true,subs=true}
	for _,feature in style.FontFeatureSettings or {} do
		values[feature.Tag]=feature.Enabled
		present[feature.Tag]=true
	end
	local parts={}
	for _,tag in ORDER do
		if present[tag] then table.insert(parts,tag.." "..(if values[tag] then "1" else "0")) end
	end
	return table.concat(parts,", ")
end

return FontFeatures
