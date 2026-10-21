--!strict
-- Classify an affected owner's existing words after every source style has
-- been recascaded. Actual regrouping remains the InlineWords tokenizer's job.
local InlineWords = require(script.Parent.Parent.Layout.InlineWords)
local SpacingOwners = {}

function SpacingOwners.glyphs(item: any): boolean
	return item.Kind == "Word" and not item.EmptyInline and ((item.Style.LetterSpacing or 0) ~= 0
		or item.Style.TabularNums == true and item.Text:find("[0-9]") ~= nil)
end

function SpacingOwners.needsRefresh(owner: any, checkpoint: (() -> ())?): boolean
	local inspected = 0
	local function step()
		inspected += 1
		if checkpoint and inspected % 32 == 0 then checkpoint() end
	end
	for _, run in owner.AllChildren or owner.Children or {} do
		if run.Kind ~= "Words" or run.InitialLetter then continue end
		local previous
		for _, item in run.Items do
			step()
			-- Preserved whitespace has an intentionally empty native frame;
			-- letter spacing changes its width, never its glyph-label mode.
			if item.Kind ~= "Word" then previous = nil; continue end
			if SpacingOwners.glyphs(item) ~= (item.Glyphs ~= nil) then return true end
			local sourceStyles
			for _, span in item.SourceSpans or {} do
				step()
				local sourceStyle = span.SourceStyle
				if sourceStyle and sourceStyle ~= item.Style and (not sourceStyles or not sourceStyles[sourceStyle]) then
					sourceStyles = sourceStyles or {}
					sourceStyles[sourceStyle] = true
					if not InlineWords.sameStyle(sourceStyle, item.Style) then return true end
				end
			end
			-- A former styled lexical boundary can disappear before the first
			-- layout, so use tokenizer boundaries rather than layout-only Joined.
			if item.Kind == "Word" and not item.EmptyInline then
				if previous and previous.Style ~= item.Style and not item.SpaceBefore
					and not item.AutoSpaceBefore and not item.SoftBefore
					and InlineWords.sameStyle(previous.Style, item.Style) then return true end
				previous = item
			else previous = nil end
		end
	end
	return false
end

return SpacingOwners
