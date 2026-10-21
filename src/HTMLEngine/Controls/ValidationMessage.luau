--!strict
local TextValue = require(script.Parent.TextValue)
local State = require(script.Parent.State)
local Message = {}
function Message.get(c: any, reason: string): string
	if reason == "missing" then
		if c.Type == "checkbox" then return "Please check this box to continue." end
		if c.Type == "radio" or c.Type == "select" then return "Please choose an option." end
		return "Please fill out this field."
	elseif reason == "email" then
		local value = c.Value
		if c.Multiple then
			for _, entry in string.split(value, ",") do
				if not TextValue.email(entry) then value = entry; break end
			end
		end
		if value == "" then return "An email address is missing from the list." end
		if not value:find("@", 1, true) then
			local excerpt = State.limit(value, 60)
			if excerpt ~= value then excerpt ..= "…" end
			return "Please include an '@' in the email address. '" .. excerpt .. "' is missing an '@'."
		end
		if value:sub(1,1) == "@" then return "Enter the part of the email address before '@'." end
		if value:sub(-1) == "@" then return "Enter a domain name after '@'." end
		return "This email address has an invalid format. Check the address and try again."
	elseif reason == "url" then
		return "Enter a complete URL, for example https://example.com."
	elseif reason == "short" then
		local length = TextValue.length(c.Value)
		return "Use at least " .. c.MinLength .. " characters. You have entered " .. length .. (if length == 1 then " character." else " characters.")
	elseif reason=="temporal" then
		if c.BadInput then return "Bitte geben Sie einen vollständigen, gültigen Wert ein." end
		return "Bitte beachten Sie den zulässigen Zeitraum und die Schrittweite."
	elseif reason == "number" then
		local value, limits = tonumber(c.Value), c.Number
		if not value or c.BadInput then return "Enter a number to continue." end
		if limits.Min and value < limits.Min then return "Enter a number of " .. limits.Min .. " or greater." end
		if limits.Max and value > limits.Max then return "Enter a number of " .. limits.Max .. " or less." end
		return "This number does not match the allowed step of " .. tostring(limits.Step or 1) .. "."
	end
	return "Check this value and try again."
end
return Message
