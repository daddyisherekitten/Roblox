--!strict
-- Inline CSSOM bridge. All writes still pass through the engine's CSS parser.
local Syntax = require(script.Parent.Parent.CSS.Syntax)
local InlineStyle = require(script.Parent.Parent.CSS.InlineStyle)
local VM = require(script.Parent.VM)
local Style = {}
local function property(key: string): string
	if key == "cssFloat" then return "float" end
	if key:sub(1,2) == "--" then return key end
	return (key:gsub("%u",function(c) return "-" .. c:lower() end))
end
local function declarations(source: string): any
	local result = {}
	for _, entry in Syntax.declarations(source) do
		local name,value = entry.Text:match("^%s*([%w_%-]+)%s*:%s*(.-)%s*$")
		if name then
			if name:sub(1,2) ~= "--" then name=name:lower() end
			local compiled = InlineStyle.compile(name .. ":" .. value)
			local valid = #compiled.Normal + #compiled.Important > 0
			for _, item in compiled.Normal do if item.Error then valid=false end end
			if valid then
				local old=result[name]
				if not old or entry.Important or not old.Important then result[name]={Value=value,Important=entry.Important} end
			end
		end
	end
	return result
end
function Style.new(node: any, attribute: any): any
	local expandos={}
	local function read(name) return declarations(node.Attributes.style or "")[name] end
	local function write(name,value,priority)
		if name:sub(1,2) ~= "--" then name=name:lower() end
		local entries=declarations(node.Attributes.style or "")
		local old=entries[name]
		if value == "" then entries[name]=nil
		else
			if priority ~= "" and priority:lower() ~= "important" then return end
			local parsed=declarations(name .. ":" .. value .. (if priority=="" then "" else " !important"))
			if not parsed[name] then return end
			entries[name]=parsed[name]
		end
		local keys,parts={},{}
		for key in entries do table.insert(keys,key) end
		table.sort(keys)
		for _,key in keys do local item=entries[key];table.insert(parts,key .. ": " .. item.Value .. (if item.Important then " !important" else "") .. ";") end
		attribute(node,"style",table.concat(parts," "))
		return if old then old.Value else ""
	end
	return {Get=function(key)
		if type(key)~="string" then return expandos[key]or VM.Undefined end
		if key=="cssText" then return node.Attributes.style or "" end
		if key=="getPropertyValue" then return function(args)local entry=read(VM.string(args[1]));return if entry then entry.Value else "" end end
		if key=="getPropertyPriority" then return function(args)local entry=read(VM.string(args[1]));return if entry and entry.Important then "important" else "" end end
		if key=="setProperty" then return function(args)
			write(VM.string(args[1]),if args[2]==VM.Null then "" else VM.string(args[2]),if args[3]==nil or args[3]==VM.Undefined or args[3]==VM.Null then "" else VM.string(args[3]))
		end end
		if key=="removeProperty" then return function(args)return write(VM.string(args[1]),"","") end end
		local entry=read(property(key));return if entry then entry.Value else ""
	end,Set=function(key,value)
		if type(key)~="string" then expandos[key]=value;return end
		if key=="cssText" then attribute(node,"style",VM.string(value)) else write(property(key),if value==VM.Null then "" else VM.string(value),"") end
	end}
end
return Style
