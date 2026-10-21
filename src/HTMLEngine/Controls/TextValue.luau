--!strict
-- Text constraints are independent of calibrated label metrics and layout.
local TextValue = {}
local Strings=require(script.Parent.Parent.JavaScript.Strings)
local AttributeValues=require(script.Parent.Parent.HTML.AttributeValues)
function TextValue.applies(kind: string): boolean
	return kind == "text" or kind == "search" or kind == "tel" or kind == "password" or kind == "textarea" or kind == "email" or kind == "url"
end
local function trim(value: string): string
	return (value:gsub("^[ \t\n\r\f]+", ""):gsub("[ \t\n\r\f]+$", ""))
end
function TextValue.sanitize(kind: string, value: string, multiple: boolean?): string
	if kind == "textarea" then return (value:gsub("\r\n", "\n"):gsub("\r", "\n")) end
	value = value:gsub("[\r\n]", "")
	if kind == "email" and multiple then
		local values = string.split(value, ",")
		for index, entry in values do values[index] = trim(entry) end
		return table.concat(values, ",")
	end
	return if kind == "email" or kind == "url" then trim(value) else value
end
function TextValue.length(value: string): number
	return Strings.length(value)
end
function TextValue.minimum(raw: string?): number?
	return AttributeValues.nonnegative(raw,2147483647)
end
local function email(value: string): boolean
	local user, host = value:match("^([^@]+)@([^@]+)$")
	if not user or not host or user:find("[^a-zA-Z0-9.!#$%%&'*+/=?^_`{|}~%-]") then return false end
	for _, label in string.split(host, ".") do
		if #label == 0 or #label > 63 or label:find("[^a-zA-Z0-9%-]")
			or not label:match("^[a-zA-Z0-9]") or not label:match("[a-zA-Z0-9]$") then return false end
	end
	return true
end
function TextValue.email(value: string, multiple: boolean?): boolean
	if not multiple then return email(value) end
	if value == "" then return true end
	for _, entry in string.split(value, ",") do if not email(trim(entry)) then return false end end
	return true
end
return TextValue
