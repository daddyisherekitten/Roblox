--!strict
local TextService = game:GetService("TextService")
local TextMeasure = {}

-- A new request for every element. No cross-element measurement cache.
-- Width = 0 means unwrapped text. This does NOT return font baselines.
function TextMeasure.measure(text: string, font: Font, size: number, width: number): (Vector2?, string?)
	assert(size >= 0, "Text size cannot be negative")
	assert(width >= 0, "Text width cannot be negative")
	if size==0 then return Vector2.new(0,0),nil end
	local params = Instance.new("GetTextBoundsParams")
	local success, result = pcall(function()
		params.Text = text
		params.Font = font
		params.Size = size
		params.Width = width
		params.RichText = false
		return TextService:GetTextBoundsAsync(params)
	end)
	params:Destroy()
	if not success then return nil, tostring(result) end
	return result, nil
end

return TextMeasure
