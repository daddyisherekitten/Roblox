--!strict
-- Convert complete dimension tokens only; quoted family names and functions stay intact.
local RelativeLengths = {}

function RelativeLengths.convert(value: string, em: number, rem: number, validate: boolean?): (string, boolean)
	if not value:find("em", 1, true) then return value, false end
	local result, changed, cursor = {}, false, 1
	local quote, depth = nil, 0
	while cursor <= #value do
		local char = value:sub(cursor, cursor)
		if quote then
			table.insert(result, char)
			if char == "\\" and cursor < #value then
				cursor += 1; table.insert(result, value:sub(cursor, cursor))
			elseif char == quote then quote = nil end
		elseif char == "\"" or char == "'" then
			quote = char; table.insert(result, char)
		elseif char == "(" then depth += 1; table.insert(result, char)
		elseif char == ")" then depth = math.max(0, depth - 1); table.insert(result, char)
		elseif depth == 0 and char:match("[%w_.%+%-]") then
			local token = value:sub(cursor):match("^[%w_.%+%-]+") :: string
			local length = #token
			local number = token:match("^([%+%-]?%d*%.?%d+)rem$")
			local unit = "rem"
			if not number then number, unit = token:match("^([%+%-]?%d*%.?%d+)em$"), "em" end
			local factor = if number then tonumber(number) else nil
			if factor and math.abs(factor) <= 100000 then
				changed = true
				local pixels = if validate then (if factor == 0 then 0 elseif factor < 0 then -1 else 1) else factor * (if unit == "em" then em else rem)
				-- Decimal output also works for tiny values; no scientific notation.
				token = string.format("%.9f", pixels) .. "px"
			end
			table.insert(result, token)
			cursor += length - 1
		else table.insert(result, char) end
		cursor += 1
	end
	return table.concat(result), changed
end

return RelativeLengths
