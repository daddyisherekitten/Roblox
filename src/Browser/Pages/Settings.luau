--!nonstrict
local Common = require(script.Parent.Common)

local Settings = {}

function Settings.Render(ctx)
	local page = Common.page(ctx, 'Settings', 'Make Wayline comfortable. Changes apply immediately across your open browser windows.')
	local appearanceTitle = Common.text(ctx.Controls, page.Content, 'Appearance', 20)
	local themeTitle = Common.text(ctx.Controls, page.Content, 'Theme', 14, true)
	local themeButtons, accentButtons = {}, {}
	for _, name in {'Dark', 'Light'} do
		themeButtons[name] = Common.button(ctx.Controls, page.Content, name, nil, function()
			local result, message = ctx.Shared:SetSetting('Theme', name); Common.result(ctx, result, message)
		end, 'Use the ' .. name:lower() .. ' theme', 140)
	end
	local accentTitle = Common.text(ctx.Controls, page.Content, 'Accent color', 14, true)
	for _, name in {'Blue', 'Purple', 'Green'} do
		accentButtons[name] = Common.button(ctx.Controls, page.Content, name, nil, function()
			local result, message = ctx.Shared:SetSetting('Accent', name); Common.result(ctx, result, message)
		end, 'Use the ' .. name:lower() .. ' accent', 136)
	end
	local bookmarksTitle = Common.text(ctx.Controls, page.Content, 'Bookmarks bar', 14, true)
	local bookmarks = Common.button(ctx.Controls, page.Content, 'Show bookmarks bar', 'bookmark', function()
		local result, message = ctx.Shared:SetSetting('BookmarksBar', not ctx.Shared.Settings.BookmarksBar)
		Common.result(ctx, result, message)
	end, 'Show or hide root bookmarks below the address field', 280)
	local homeTitle = Common.text(ctx.Controls, page.Content, 'Home', 20)
	local greeting = Common.text(ctx.Controls, page.Content, '', 14, true)
	local greetingButton = Common.button(ctx.Controls, page.Content, 'Edit greeting', 'edit', function() Common.editGreeting(ctx) end, 'Edit the Home greeting', 156)
	local backgroundButton
	backgroundButton = Common.button(ctx.Controls, page.Content, 'Background', 'settings', function()
		Common.backgroundMenu(ctx, backgroundButton.Root)
	end, 'Choose the Home background', 184)
	local quickLinks = Common.button(ctx.Controls, page.Content, 'Manage quick links', 'home', function()
		ctx.Navigate('wayline://home')
	end, 'Add, edit, remove, and arrange quick links on Home', 220)
	local quickDescription = Common.text(ctx.Controls, page.Content, 'Home has room for twelve quick links. Its link menus include Edit, Remove, Move earlier, and Move later. You can also drag links to rearrange them.', 14, true)
	local persistenceTitle = Common.text(ctx.Controls, page.Content, 'Storage and restoration', 20)
	local persistence = Common.text(ctx.Controls, page.Content, '', 14, true)
	local storageDescription = Common.text(ctx.Controls, page.Content, 'Your settings, Home, bookmarks, and latest 500 visits are shared. A saved session restores your current address when you rejoin. Back and Forward navigation belongs to the current client session.', 14, true)
	local guide = Common.button(ctx.Controls, page.Content, 'Read the guide', 'guide', function() ctx.Navigate('wayline://guide') end, 'Learn how Wayline stores and restores your browsing', 180)
	local function update()
		for name, button in themeButtons do button:SetText(name .. (ctx.Shared.Settings.Theme == name and ' (selected)' or '')); button:SetSelected(ctx.Shared.Settings.Theme == name) end
		for name, button in accentButtons do button:SetText(name .. (ctx.Shared.Settings.Accent == name and ' (selected)' or '')); button:SetSelected(ctx.Shared.Settings.Accent == name) end
		bookmarks:SetText(ctx.Shared.Settings.BookmarksBar and 'Bookmarks bar: shown' or 'Bookmarks bar: hidden')
		greeting.Text = 'Greeting: ' .. ctx.Shared.Home.Greeting
		backgroundButton:SetText('Background: ' .. ctx.Shared.Home.Background)
		local status = ctx.Browser:GetPersistenceStatus()
		persistence.Text = type(status) == 'table' and (status.Message or 'Changes are available for this session.')
			or tostring(status or 'Changes are available for this session.')
		page:Reflow()
	end
	page.Layout = function(width)
		local y = 0
		local function textRow(label, size, gap)
			local height = Common.height(label.Text, width, size)
			Common.place(label, 0, y, width, height)
			y += height + (gap or 12)
		end
		textRow(appearanceTitle, 20, 24)
		textRow(themeTitle, 14, 10)
		Common.place(themeButtons.Dark.Root, 0, y, 166, 44)
		Common.place(themeButtons.Light.Root, 178, y, 166, 44)
		y += 64
		textRow(accentTitle, 14, 10)
		local columns = width >= 540 and 3 or 2
		local itemWidth = math.min(170, (width - 12 * (columns - 1)) / columns)
		for index, name in {'Blue', 'Purple', 'Green'} do
			Common.place(accentButtons[name].Root, ((index - 1) % columns) * (itemWidth + 12), y + math.floor((index - 1) / columns) * 56, itemWidth, 44)
		end
		y += math.ceil(3 / columns) * 56 + 8
		textRow(bookmarksTitle, 14, 10)
		Common.place(bookmarks.Root, 0, y, math.min(300, width), 44)
		y += 80
		textRow(homeTitle, 20, 18)
		textRow(greeting, 14, 12)
		Common.place(greetingButton.Root, 0, y, 156, 44)
		Common.place(backgroundButton.Root, 168, y, math.min(204, width - 168), 44)
		y += 56
		Common.place(quickLinks.Root, 0, y, 220, 44)
		y += 60
		textRow(quickDescription, 14, 36)
		textRow(persistenceTitle, 20, 18)
		textRow(persistence, 14, 18)
		textRow(storageDescription, 14, 18)
		Common.place(guide.Root, 0, y, 180, 44)
		return y + 44
	end
	Common.connection(ctx, ctx.Shared.Changed, function(kind)
		if kind == 'Settings' or kind == 'Home' or kind == 'Replace' then update() end
	end)
	if ctx.Browser.OnPersistenceStatus then ctx.Scope:Add(ctx.Browser:OnPersistenceStatus(update)) end
	update()
	page:Restore()
	return page
end

return Settings
