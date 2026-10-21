--!strict
local Transform = require(script.Parent.Parent.Layout.TextTransform)
local TypeAhead = {}
function TypeAhead.new(clock: any?): any
	local now = clock or os.clock
	local control, prefix, last = nil, "", -math.huge
	local search = {}
	function search:Reset() control, prefix, last = nil, "", -math.huge end
	function search:Find(c: any, current: number, character: string): (boolean, number?)
		if c.Disabled or c.Type ~= "select" or utf8.len(character) ~= 1 or character:find("[%z\1-\31\127]") then return false, nil end
		local time = now()
		if control ~= c or time-last >= 1 then self:Reset() end
		-- Space still opens/commits the popup unless it extends an active search.
		if character == " " and prefix == "" then return false, nil end
		character = Transform.word(character, "lowercase")
		local cycle = prefix == "" or prefix == character
		prefix = if cycle then character else prefix .. character
		if #prefix > 256 then prefix=character; cycle=true end
		control, last = c, time
		local count = #c.Options
		if count == 0 then return true, nil end
		local start = if cycle or current == 0 then current+1 else current
		for offset = 0, count-1 do
			local index = (start+offset-1)%count+1
			local option = c.Options[index]
			if option.Disabled then continue end
			if not option.SearchCaption then option.SearchCaption=Transform.word(option.Caption:gsub("^%s+", ""), "lowercase") end
			if option.SearchCaption:sub(1,#prefix) == prefix then return true, index end
		end
		return true, nil
	end
	return search
end
return TypeAhead
