--!nonstrict
local Common = require(script.Parent.Common)

local History = {}

function History.Render(ctx)
	local page = Common.page(ctx, 'History', 'Your recent successful visits. Removing history leaves your Back and Forward navigation intact.')
	local matches, redraw = {}, nil
	local search = ctx.Controls:Field(page.Content, {Name = 'HistorySearch', Text = ctx.State.Filter or '', Placeholder = 'Search titles and addresses',
		OnChanged = function(text) ctx.State.Filter = text; if redraw then redraw() end end})
	local clear = Common.button(ctx.Controls, page.Content, 'Clear history', 'delete', function()
		ctx.Overlays:Confirm('Clear browsing history?', 'All recorded visits will be removed. Your bookmarks and Back and Forward navigation will stay available.', function()
			local result, message = ctx.Shared:ClearHistory(); Common.result(ctx, result, message)
		end)
	end, 'Clear all recorded visits', 156)
	local summary = Common.text(ctx.Controls, page.Content, '', 12, true)
	local list = Common.virtual(ctx, page.Content, 'HistoryRows', page, 108, function(root, controls, visit, _, width, y)
		local row = Common.frame(ctx, root, 'HistoryEntry')
		Common.place(row, 0, y, width, 96)
		local open = Common.button(controls, row, visit.Title, 'history', function() ctx.Navigate(visit.Address) end, visit.Address)
		local address = Common.text(controls, row, visit.Address, 12, true)
		local date = Common.text(controls, row, Common.time(visit.Time), 12, true)
		local delete = Common.button(controls, row, '', 'delete', function()
			local result, message = ctx.Shared:DeleteHistory(visit.ID); Common.result(ctx, result, message)
		end, 'Remove this visit', 44)
		Common.place(open.Root, 0, 0, width - 56, 44)
		Common.place(delete.Root, width - 44, 0, 44, 44)
		Common.place(address, 12, 49, width - 24, 20)
		address.TextWrapped, address.TextTruncate = false, Enum.TextTruncate.AtEnd
		Common.place(date, 12, 73, width - 24, 20)
	end)
	local empty = Common.text(ctx.Controls, page.Content, '', 15, true)
	redraw = function()
		table.clear(matches)
		local query = (ctx.State.Filter or ''):lower()
		for _, visit in ctx.Shared.History do
			if query == '' or visit.Title:lower():find(query, 1, true) or visit.Address:lower():find(query, 1, true) then table.insert(matches, visit) end
		end
		clear:SetEnabled(#ctx.Shared.History > 0)
		summary.Text = tostring(#ctx.Shared.History) .. ' of 500 retained visits' .. (query ~= '' and (' / ' .. #matches .. ' matches') or '')
		empty.Visible = #matches == 0
		empty.Text = #ctx.Shared.History == 0
			and 'No visits yet. Open a page to start your history. Reloads and restored sessions do not create visits.'
			or 'No visits match your search. Try another title or address.'
		list:SetData(matches)
		page:Reflow()
	end
	page.Layout = function(width)
		Common.place(search, 0, 0, width, 44)
		Common.place(clear.Root, 0, 56, 156, 44)
		Common.place(summary, 0, 116, width, 22)
		list:Place(0, 154, width, 90)
		Common.place(empty, 0, 154, width, 90)
		return 154 + math.max(90, #matches * 108)
	end
	Common.connection(ctx, ctx.Shared.Changed, function(kind)
		if kind == 'History' or kind == 'Replace' then redraw() end
	end)
	redraw()
	page:Restore()
	return page
end

return History
