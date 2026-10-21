--!strict
local Icons=require(script.Parent.Parent.Input.CursorIcons)
local Syntax=require(script.Parent.Syntax)
local Cursor={}
local keywords={auto=true}
for name in Icons do if name ~= "url" and not name:find("Icon$") then keywords[name]=true end end
Cursor.Keywords=table.freeze(keywords)

function Cursor.parse(value: string): any?
	local parts,index={},1
	while index <= #value do
		local part,nextIndex=Syntax.scan(value,index,",")
		table.insert(parts,part:match("^%s*(.-)%s*$")); index=nextIndex
	end
	local fallback=parts[#parts]
	if not fallback or not keywords[fallback] or value:match(",%s*$") then return nil end
	if #parts == 1 then return fallback end
	local sources={}
	for i=1,#parts-1 do
		local source=parts[i]:match('^url%(%s*"([^"\n]+)"%s*%)$') or parts[i]:match("^url%(%s*'([^'\n]+)'%s*%)$")
			or parts[i]:match("^url%(%s*([^%s'\"()]+)%s*%)$")
		if not source then return nil end
		table.insert(sources,source)
	end
	return {Sources=sources,Fallback=fallback}
end

function Cursor.resolve(value: any,automatic: string): string
	if type(value) == "table" then
		for _,source in value.Sources do
			if source:match("^rbxassetid://%d+$") then return source end
			if Icons[source] then return Icons[source] end
			for name,asset in Icons do if name:lower() == source:lower() then return asset end end
		end
		value=value.Fallback
	end
	return if not value or value == "auto" then automatic else value
end
return Cursor
