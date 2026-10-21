--!strict
-- Whitespace is layout data, never a sentence-sized label.
local TextWords = {}

function TextWords.split(text: string): { any }
	local items, position, spaceBefore = {}, 1, false
	while position <= #text do
		local start = text:find("[ \t\r\n\f]", position)
		if not start or start > position then
			local last = if start then start - 1 else #text
			table.insert(items, { Kind = "Word", Text = text:sub(position, last), SpaceBefore = spaceBefore })
			position, spaceBefore = last + 1, false
		else
			if text:sub(position, position) == "\n" then
				table.insert(items, { Kind = "Break" })
				spaceBefore = false
			else spaceBefore = true end
			position += 1
		end
	end
	return items
end

return TextWords
