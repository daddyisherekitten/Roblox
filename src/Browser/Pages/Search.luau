--!nonstrict
local Common = require(script.Parent.Common)

local Search = {}

local function score(query, title, address)
	if query == '' then return 1 end
	title, address = title:lower(), address:lower()
	if title == query or address == query then return 100 end
	if title:sub(1, #query) == query or address:sub(1, #query) == query then return 70 end
	if title:find(query, 1, true) or address:find(query, 1, true) then return 30 end
	return 0
end

function Search.Render(ctx)
	local address = ctx.Address:Resolve(ctx.AddressValue or ctx.URL or ('wayline://search?q=' .. tostring(ctx.State.Query or '')))
	local initial = ctx.Query and ctx.Query.q or address and address.Query and address.Query.q or ''
	ctx.State.Query = ctx.State.Query or initial
	local page = Common.page(ctx, 'Search results', 'Search the Wayline page registry, your bookmarks, and your recent history. Everything here is local.')
	local rows = {}
	local search = ctx.Controls:Field(page.Content, {Name = 'LocalSearch', Text = ctx.State.Query, Placeholder = 'Search local pages',
		OnChanged = function(text) ctx.State.Query = text end,
		OnSubmit = function(text) ctx.Navigate('wayline://search?q=' .. ctx.Address.Encode(text)) end})
	local button = Common.button(ctx.Controls, page.Content, 'Search', 'search', function()
		ctx.Navigate('wayline://search?q=' .. ctx.Address.Encode(search.Text))
	end, 'Search local pages', 108)
	local summary = Common.text(ctx.Controls, page.Content, '', 14, true)
	local list = Common.virtual(ctx, page.Content, 'SearchResults', page, 132, function(root, controls, match, _, width, y)
		local row = Common.frame(ctx, root, 'SearchResult')
		Common.place(row, 0, y, width, 120)
		local open = Common.button(controls, row, match.Title, match.Icon, function() ctx.Navigate(match.Address) end, match.Address)
		local addressLabel = Common.text(controls, row, match.Address, 12, true)
		local description = Common.text(controls, row, match.Description, 14, true)
		Common.place(open.Root, 0, 0, width, 44)
		Common.place(addressLabel, 12, 49, width - 24, 20)
		addressLabel.TextWrapped, addressLabel.TextTruncate = false, Enum.TextTruncate.AtEnd
		Common.place(description, 12, 75, width - 24, 44)
		description.TextTruncate = Enum.TextTruncate.AtEnd
	end)
	local empty = Common.text(ctx.Controls, page.Content, 'No local results. Try a page name such as Home, Bookmarks, History, Settings, or Guide.', 15, true)
	local function redraw()
		table.clear(rows)
		local query, byAddress, results = ctx.State.Query:lower(), {}, {}
		local function insert(record)
			local current = byAddress[record.Address]
			if current then
				if record.Score > current.Score then current.Score = record.Score end
				if record.Bookmark then current.Bookmark = true end
				return
			end
			byAddress[record.Address] = record
			table.insert(results, record)
		end
		for _, match in ctx.Address:Search(ctx.State.Query) do
			insert({Title = match.Title, Address = match.Address or match.URL, Description = match.Description or 'Registered local page',
				Icon = match.Icon or 'home', Score = match.Score or 1, Source = 'Wayline page'})
		end
		for _, item in ctx.Shared.Bookmarks do
			if item.Kind == 'bookmark' then
				local rank = score(query, item.Title, item.Address)
				if rank > 0 then insert({Title = item.Title, Address = item.Address, Description = 'Saved in your bookmarks.',
					Icon = 'bookmark', Score = rank, Bookmark = true, Source = 'Bookmark'}) end
			end
		end
		for _, item in ctx.Shared.History do
			local rank = score(query, item.Title, item.Address)
			if rank > 0 then insert({Title = item.Title, Address = item.Address, Description = 'Visited ' .. Common.time(item.Time),
				Icon = 'history', Score = rank, Time = item.Time, Source = 'History'}) end
		end
		table.sort(results, function(a, b)
			if a.Score ~= b.Score then return a.Score > b.Score end
			if a.Bookmark ~= b.Bookmark then return a.Bookmark == true end
			if (a.Time or 0) ~= (b.Time or 0) then return (a.Time or 0) > (b.Time or 0) end
			return a.Title:lower() < b.Title:lower()
		end)
		rows = results
		summary.Text = #rows == 1 and '1 local result' or (tostring(#rows) .. ' local results')
		empty.Visible = #rows == 0
		list:SetData(rows)
		page:Reflow()
	end
	page.Layout = function(width)
		Common.place(search, 0, 0, width - 120, 44)
		Common.place(button.Root, width - 108, 0, 108, 44)
		Common.place(summary, 0, 64, width, 24)
		list:Place(0, 108, width, 80)
		Common.place(empty, 0, 108, width, 80)
		return 108 + math.max(80, #rows * 132)
	end
	Common.connection(ctx, ctx.Shared.Changed, function(kind)
		if kind == 'History' or kind == 'Bookmarks' or kind == 'Replace' then redraw() end
	end)
	redraw()
	page:Restore()
	return page
end

return Search
