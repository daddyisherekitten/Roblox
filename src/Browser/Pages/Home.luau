--!nonstrict
local Common = require(script.Parent.Common)
local Icons = require(script.Parent.Parent.Icons)

local Home = {}
local LEGACY_GREETING = 'A little direction for your day.'

function Home.Render(ctx)
	local page = Common.page(ctx, '', '', {Header = false, MaxWidth = 760, Top = 0})
	local services = ctx.Browser.Services or {}
	local inputService = services.Input or services.UserInputService or game:GetService('UserInputService')
	local touchOnly = inputService.TouchEnabled and not inputService.MouseEnabled
	local menuSize = touchOnly and 44 or 28
	local tileHeight, rowHeight = touchOnly and 140 or 108, touchOnly and 144 or 112
	local wordmark = ctx.Controls:Text(page.Content, 'Wayline', {Name = 'Wordmark', TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center}, {TextColor3 = 'Text'})
	local greeting = ctx.Controls:Text(page.Content, '', {Name = 'Greeting', TextSize = 13, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center}, {TextColor3 = 'Muted'})
	local searchBox = ctx.Gui:Make('Frame', page.Content, {Name = 'HomeSearch', BackgroundTransparency = 0}, {BackgroundColor3 = 'Omnibox'})
	ctx.Gui:Corner(searchBox, 24)
	local search = ctx.Controls:Field(searchBox, {Name = 'SearchField', Text = ctx.State.Query or '', Variant = 'Omnibox',
		TextSize = 14, Placeholder = 'Search or enter an address',
		OnChanged = function(text) ctx.State.Query = text end,
		OnSubmit = function(text) ctx.Navigate(text) end})
	local searchButton = ctx.Controls:Button(searchBox, {Name = 'Search', Icon = 'search', Width = 44, Height = 44,
		Variant = 'Shortcut', Tooltip = 'Search', OnClick = function() ctx.Navigate(search.Text) end})
	local list = Common.list(ctx, page.Content, 'Shortcuts')
	local rows = {}
	local dragID, dropID
	local addButton, customizeButton

	local function editLink(link)
		local overlay = Common.fieldForm(ctx, link and 'Edit shortcut' or 'Add shortcut', {
			{Id = 'Title', Label = 'Name', Value = link and link.Title or '', Placeholder = 'Page name'},
			{Id = 'Address', Label = 'Address', Value = link and link.Address or '', Placeholder = 'wayline://guide'},
		}, link and 'Save' or 'Add', function(values)
			local address, message = Common.address(ctx, values.Address)
			if not address then return false, message end
			if link then return ctx.Shared:EditQuickLink(link.ID, values.Title, address) end
			return ctx.Shared:AddQuickLink(values.Title, address)
		end)
		if link then Common.associate(ctx, overlay, function()
			for _, candidate in ctx.Shared.Home.QuickLinks do if candidate.ID == link.ID then return true end end
			return false
		end) end
	end

	local function updateDrop(point)
		dropID = nil
		local hit = point and ctx.Input:HitAt(point)
		for _, row in rows do
			local match = row.Link.ID ~= dragID and Common.inside(row.Root, point)
				and (hit == row.Open.Entry or hit == row.More.Entry)
			row.Highlight.Visible = match
			if match then dropID = row.Link.ID end
		end
	end

	local function shortcutArtwork(root, title, iconName, controls)
		local circle = ctx.Gui:Make('Frame', root, {Name = 'ShortcutIcon', BackgroundTransparency = 0,
			Position = UDim2.fromOffset(32, touchOnly and 44 or 12), Size = UDim2.fromOffset(48, 48)}, {BackgroundColor3 = 'ShortcutCircle'})
		ctx.Gui:Corner(circle, 24)
		local icon = Icons.draw(ctx.Gui, circle, iconName, 22, 'Text')
		icon.Position = UDim2.fromOffset(13, 13)
		return controls:Text(root, title, {Name = 'ShortcutTitle', Position = UDim2.fromOffset(6, touchOnly and 106 or 74),
			Size = UDim2.fromOffset(100, 18), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd}, {TextColor3 = 'Text'})
	end

	local function updateGreeting()
		local text = ctx.Shared.Home.Greeting
		greeting.Text = text ~= LEGACY_GREETING and text or ''
		greeting.Visible = greeting.Text ~= ''
	end

	local function redraw()
		local root, controls = list:Reset()
		table.clear(rows)
		dragID, dropID = nil, nil
		for index, link in ctx.Shared.Home.QuickLinks do
			local row = {Link = link}
			row.Root = Common.frame(ctx, root, 'Shortcut')
			row.Highlight = ctx.Gui:Make('Frame', row.Root, {Name = 'DropTarget', BackgroundTransparency = 0.82,
				BorderSizePixel = 0, Visible = false, Size = UDim2.fromScale(1, 1)}, {BackgroundColor3 = 'Accent'})
			ctx.Gui:Corner(row.Highlight, 8)
			row.Open = controls:Button(row.Root, {Name = 'OpenShortcut', Text = '', Variant = 'Shortcut',
				Width = 112, Height = tileHeight, Tooltip = link.Title .. '\n' .. link.Address,
				OnClick = function() ctx.Navigate(link.Address) end,
				DragBegin = function(event) dragID = link.ID; updateDrop(Common.point(event)) end,
				Drag = function(event) updateDrop(Common.point(event)) end,
				DragEnd = function(event, cancelled)
					if not cancelled then updateDrop(Common.point(event)) end
					local target = dropID
					dragID, dropID = nil, nil
					for _, candidate in rows do candidate.Highlight.Visible = false end
					if not cancelled and target then
						for targetIndex, candidate in ctx.Shared.Home.QuickLinks do
							if candidate.ID == target then
								local result, message = ctx.Shared:MoveQuickLink(link.ID, targetIndex)
								Common.result(ctx, result, message)
								break
							end
						end
					end
				end})
			local resolved = ctx.Address:Resolve(link.Address)
			shortcutArtwork(row.Open.Root, link.Title, resolved and resolved.Icon or 'page', controls)
			row.More = controls:Button(row.Root, {Name = 'ShortcutMenu', Icon = 'overflow', Variant = 'Shortcut',
				Width = menuSize, Height = menuSize, ZIndex = row.Root.ZIndex + 2, Tooltip = 'Edit ' .. link.Title,
				OnClick = function()
					ctx.Overlays:Menu(row.More.Root, {
						{Text = 'Edit shortcut', Icon = 'edit', Action = function() editLink(link) end},
						{Text = 'Move earlier', Icon = 'up', Disabled = index == 1, Action = function() ctx.Shared:MoveQuickLink(link.ID, index - 1) end},
						{Text = 'Move later', Icon = 'down', Disabled = index == #ctx.Shared.Home.QuickLinks, Action = function() ctx.Shared:MoveQuickLink(link.ID, index + 1) end},
						{Text = 'Remove shortcut', Icon = 'delete', Action = function() ctx.Shared:RemoveQuickLink(link.ID) end},
					})
				end})
			table.insert(rows, row)
		end
		addButton = nil
		if #rows < 12 then
			addButton = controls:Button(root, {Name = 'AddShortcut', Variant = 'Shortcut', Width = 112, Height = tileHeight,
				Tooltip = 'Add shortcut', OnClick = function() editLink(nil) end})
			shortcutArtwork(addButton.Root, 'Add shortcut', 'plus', controls)
		end
		page:Reflow()
	end

	customizeButton = ctx.Controls:Button(page.Scroll.Body, {Name = 'CustomizeHome', Text = 'Customize', Icon = 'edit',
		Width = 132, Height = 44, Variant = 'Shortcut', Tooltip = 'Customize this page', OnClick = function()
			ctx.Overlays:Menu(customizeButton.Root, {
				{Text = 'Add shortcut', Icon = 'plus', Disabled = #ctx.Shared.Home.QuickLinks >= 12, Action = function() editLink(nil) end},
				{Text = 'Edit greeting', Icon = 'edit', Action = function() Common.editGreeting(ctx) end},
				{Text = 'Background', Icon = 'settings', Action = function() Common.backgroundMenu(ctx, customizeButton.Root) end},
				{Text = 'Settings', Icon = 'settings', Action = function() ctx.Navigate('wayline://settings') end},
			})
		end})

	page.Layout = function(width)
		local viewportHeight = page.Scroll.Root.AbsoluteSize.Y
		local columns = math.clamp(math.floor(width / 112), 2, 6)
		local itemCount = #rows + (addButton and 1 or 0)
		local linksHeight = math.ceil(itemCount / columns) * rowHeight
		local greetingHeight = greeting.Visible and Common.height(greeting.Text, math.min(560, width), 13) + 12 or 0
		local blockHeight = 44 + 24 + greetingHeight + 48 + 24 + linksHeight
		local top = math.max(36, math.min(112, math.floor((viewportHeight - blockHeight - 64) * 0.35)))
		Common.place(wordmark, 0, top, width, 44)
		local searchY = top + 68 + greetingHeight
		Common.place(greeting, 0, top + 54, width, math.max(0, greetingHeight - 12))
		local searchWidth = math.min(560, width)
		Common.place(searchBox, (width - searchWidth) / 2, searchY, searchWidth, 48)
		Common.place(searchButton.Root, 4, 2, 44, 44)
		Common.place(search, 52, 0, searchWidth - 68, 48)
		local linksY = searchY + 72
		Common.place(list.Root, 0, linksY, width, linksHeight)
		for index, row in rows do
			local rowIndex, column = math.floor((index - 1) / columns), (index - 1) % columns
			local countInRow = math.min(columns, itemCount - rowIndex * columns)
			local x = (width - countInRow * 112) / 2 + column * 112
			Common.place(row.Root, x, rowIndex * rowHeight, 112, tileHeight)
			Common.place(row.Open.Root, 0, 0, 112, tileHeight)
			Common.place(row.More.Root, 112 - menuSize, 0, menuSize, menuSize)
		end
		if addButton then
			local rowIndex, column = math.floor(#rows / columns), #rows % columns
			local countInRow = math.min(columns, itemCount - rowIndex * columns)
			Common.place(addButton.Root, (width - countInRow * 112) / 2 + column * 112, rowIndex * rowHeight, 112, tileHeight)
		end
		local customizeY = math.max(linksY + linksHeight + 16, viewportHeight - 68)
		Common.place(customizeButton.Root, page.Scroll.Root.AbsoluteSize.X - 156, customizeY, 132, 44)
		return customizeY + 44
	end

	Common.background(ctx, page.Scroll.Root)
	Common.connection(ctx, ctx.Shared.Changed, function(kind)
		if kind == 'Replace' then
			updateGreeting()
			Common.background(ctx, page.Scroll.Root)
			redraw()
		elseif kind == 'Home' then
			updateGreeting()
			Common.background(ctx, page.Scroll.Root)
			page:Reflow()
		elseif kind == 'QuickLinks' then redraw()
		elseif kind == 'Settings' then Common.background(ctx, page.Scroll.Root) end
	end)
	updateGreeting()
	redraw()
	page:Restore()
	return page
end

return Home
