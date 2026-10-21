--!nonstrict
local Common = require(script.Parent.Common)

local Bookmarks = {}

local function folderPath(shared, id)
	local parts, seen = {}, {}
	while id and id ~= 'root' and not seen[id] do
		seen[id] = true
		local item = shared.Bookmarks[id]
		if not item then break end
		table.insert(parts, 1, item.Title)
		id = item.Parent
	end
	return #parts > 0 and ('Bookmarks / ' .. table.concat(parts, ' / ')) or 'Bookmarks'
end

local function subtreeHeight(shared, id, visited)
	if visited[id] then return 6 end
	visited[id] = true
	local result = 1
	for _, child in shared:GetChildren(id) do
		if child.Kind == 'folder' then result = math.max(result, 1 + subtreeHeight(shared, child.ID, visited)) end
	end
	visited[id] = nil
	return result
end

local function eligible(shared, item, parent, itemHeight)
	if parent == item.ID then return false end
	local level, current, seen = 0, parent, {}
	while current and current ~= 'root' do
		if current == item.ID or seen[current] then return false end
		seen[current] = true
		local folder = shared.Bookmarks[current]
		if not folder or folder.Kind ~= 'folder' then return false end
		level += 1
		current = folder.Parent
	end
	return level + (itemHeight or (item.Kind == 'folder' and subtreeHeight(shared, item.ID, {}) or 0)) <= 5
end

function Bookmarks.Render(ctx)
	local page = Common.page(ctx, 'Bookmarks', 'Save useful places. Organize folders by dragging an item or choosing Move from its menu.')
	ctx.State.Folder = ctx.State.Folder or (ctx.Query and ctx.Query.folder) or 'root'
	local currentFolder, rows = 'root', {}
	local redraw, updatingFilter
	local locationButton, parentButton, addButton, organizeButton
	local matches, renderRow = {}, nil
	local list = Common.virtual(ctx, page.Content, 'BookmarkRows', page, 88, function(...) renderRow(...) end)
	list.OnReset = function() table.clear(rows) end
	local filter = ctx.Controls:Field(page.Content, {Name = 'BookmarkFilter', Text = ctx.State.Filter or '', Placeholder = 'Filter this folder',
		OnChanged = function(text) ctx.State.Filter = text; if redraw and not updatingFilter then redraw() end end})
	local summary = Common.text(ctx.Controls, page.Content, '', 12, true)
	local empty = Common.text(ctx.Controls, page.Content, '', 15, true)
	local function setFolder(id)
		ctx.State.Folder, ctx.State.Filter, ctx.State.Highlight = id, '', nil
		updatingFilter = true
		filter.Text = ''
		updatingFilter = false
		redraw()
		page.Scroll:ScrollTo(0)
	end
	parentButton = Common.button(ctx.Controls, page.Content, '', 'back', function()
		local item = ctx.Shared.Bookmarks[currentFolder]
		setFolder(item and item.Parent or 'root')
	end, 'Go to the parent folder', 44)
	locationButton = Common.button(ctx.Controls, page.Content, 'Bookmarks', 'folder', function()
		local chain, id = {}, currentFolder
		while id ~= 'root' and ctx.Shared.Bookmarks[id] do
			table.insert(chain, 1, ctx.Shared.Bookmarks[id])
			id = ctx.Shared.Bookmarks[id].Parent
		end
		local items = {{Text = 'Bookmarks', Icon = 'folder', Action = function() setFolder('root') end}}
		for _, folder in chain do
			table.insert(items, {Text = folder.Title, Icon = 'folder', Action = function() setFolder(folder.ID) end})
		end
		ctx.Overlays:Menu(locationButton.Root, items)
	end, 'Choose a parent folder', 180)
	local function addBookmark()
		local destination = currentFolder
		local overlay = Common.fieldForm(ctx, 'Add bookmark', {
			{Id = 'Title', Label = 'Title', Value = '', Placeholder = 'A useful page'},
			{Id = 'Address', Label = 'Address or search', Value = '', Placeholder = 'wayline://guide'},
		}, 'Add bookmark', function(values)
			local address, message = Common.address(ctx, values.Address)
			if not address then return false, message end
			local result, reason = ctx.Shared:AddBookmark(values.Title, address, destination)
			if not result then return false, reason end
			ctx.State.Folder, ctx.State.Highlight, ctx.State.Filter = result.Parent, result.ID, ''
			updatingFilter = true
			filter.Text = ''
			updatingFilter = false
			redraw()
			for index, candidate in matches do
				if candidate.Item.ID == result.ID then
					page.Scroll:ScrollTo(page.Body.Position.Y.Offset + page.Content.Position.Y.Offset + 210 + (index - 1) * 88)
					break
				end
			end
			return true
		end)
		Common.associate(ctx, overlay, function() return destination == 'root' or ctx.Shared.Bookmarks[destination] ~= nil end)
	end
	local function addFolder()
		local destination = currentFolder
		local overlay = Common.fieldForm(ctx, 'New folder', {{Id = 'Title', Label = 'Folder name', Value = '', Placeholder = 'A collection'}},
			'Create folder', function(values) return ctx.Shared:AddFolder(values.Title, destination) end)
		Common.associate(ctx, overlay, function() return destination == 'root' or ctx.Shared.Bookmarks[destination] ~= nil end)
	end
	addButton = Common.button(ctx.Controls, page.Content, 'New', 'plus', function()
		ctx.Overlays:Menu(addButton.Root, {{Text = 'Add bookmark', Icon = 'bookmark', Action = addBookmark},
			{Text = 'New folder', Icon = 'folder', Action = addFolder}})
	end, 'Create a bookmark or folder', 96)
	organizeButton = Common.button(ctx.Controls, page.Content, 'Organize', 'menu', function()
		ctx.Overlays:Menu(organizeButton.Root, {
			{Text = 'Sort titles A to Z', Icon = 'down', Action = function() ctx.Shared:SortFolder(currentFolder, 'asc') end},
			{Text = 'Sort titles Z to A', Icon = 'up', Action = function() ctx.Shared:SortFolder(currentFolder, 'desc') end},
			{Text = 'Add bookmark', Icon = 'bookmark', Action = addBookmark},
			{Text = 'New folder', Icon = 'folder', Action = addFolder},
		})
	end, 'Sort and organize this folder', 132)
	local function editItem(item)
		local fields = {{Id = 'Title', Label = item.Kind == 'folder' and 'Folder name' or 'Title', Value = item.Title}}
		if item.Kind == 'bookmark' then table.insert(fields, {Id = 'Address', Label = 'Address or search', Value = item.Address}) end
		local overlay = Common.fieldForm(ctx, item.Kind == 'folder' and 'Rename folder' or 'Edit bookmark', fields, 'Save changes', function(values)
			local address
			if item.Kind == 'bookmark' then
				local message
				address, message = Common.address(ctx, values.Address)
				if not address then return false, message end
			end
			return ctx.Shared:EditItem(item.ID, values.Title, address)
		end)
		Common.associate(ctx, overlay, function() return ctx.Shared.Bookmarks[item.ID] ~= nil end)
	end
	local function removeItem(item)
		local contents = item.Kind == 'folder' and ctx.Shared:GetChildren(item.ID) or {}
		local message = item.Kind == 'folder' and #contents > 0
			and 'This folder is not empty. All bookmarks and folders inside it will also be deleted.'
			or 'This item will be removed from your bookmarks.'
		local overlay = ctx.Overlays:Confirm('Delete ' .. item.Title .. '?', message, function()
			local result, reason = ctx.Shared:DeleteItem(item.ID)
			Common.result(ctx, result, reason)
		end)
		Common.associate(ctx, overlay, function() return ctx.Shared.Bookmarks[item.ID] ~= nil end)
	end
	local function moveItem(item, anchor)
		local destinations = {}
		local itemHeight = item.Kind == 'folder' and subtreeHeight(ctx.Shared, item.ID, {}) or 0
		if eligible(ctx.Shared, item, 'root', itemHeight) and item.Parent ~= 'root' then
			table.insert(destinations, {Text = 'Bookmarks', Icon = 'folder', Action = function()
				local result, message = ctx.Shared:MoveItem(item.ID, 'root'); Common.result(ctx, result, message)
			end})
		end
		local folders = {}
		for _, folder in ctx.Shared.Bookmarks do
			if folder.Kind == 'folder' and folder.ID ~= item.Parent and eligible(ctx.Shared, item, folder.ID, itemHeight) then table.insert(folders, folder) end
		end
		table.sort(folders, function(a, b) return folderPath(ctx.Shared, a.ID):lower() < folderPath(ctx.Shared, b.ID):lower() end)
		for _, folder in folders do
			table.insert(destinations, {Text = folderPath(ctx.Shared, folder.ID), Icon = 'folder', Action = function()
				local result, message = ctx.Shared:MoveItem(item.ID, folder.ID); Common.result(ctx, result, message)
			end})
		end
		if #destinations == 0 then ctx.Overlays:Notice('No other eligible folders. Create a folder to move this item into it.')
		else ctx.Overlays:Menu(anchor, destinations) end
	end
	local dragItem, dragHeight, dragIndex, dropItem, dropIndex
	local function paintDrop(point)
		dropItem, dropIndex = nil, nil
		local hit = point and ctx.Input:HitAt(point)
		for _, row in rows do
			local localY = point and (point.Y - row.Root.AbsolutePosition.Y) or 22
			local before, after = localY < 12, localY > 32
			local insertion = before or after or row.Item.Kind ~= 'folder'
			local destination = not insertion and row.Item.ID or currentFolder
			local valid = dragItem and row.Item.ID ~= dragItem.ID and eligible(ctx.Shared, dragItem, destination, dragHeight)
			local over = valid and Common.inside(row.Root, point) and (hit == row.Open.Entry or hit == row.More.Entry)
			row.Drop.Visible = dragItem and row.Item.ID ~= dragItem.ID and row.Item.Kind == 'folder'
				and eligible(ctx.Shared, dragItem, row.Item.ID, dragHeight) or false
			row.Drop.BackgroundTransparency = over and not insertion and 0 or 0.65
			row.Insert.Visible = over and insertion or false
			if over then
				if insertion then
					local index = row.ChildIndex
					if before and dragIndex < index then index -= 1
					elseif after and dragIndex > index then index += 1 end
					local insertAfter = after or not before and dragIndex < row.ChildIndex
					row.Insert.Position = UDim2.fromOffset(0, insertAfter and 73 or 0)
					dropItem, dropIndex = {ID = row.Item.ID, Kind = 'position'}, index
				else dropItem, dropIndex = row.Item, nil end
			end
		end
		local canGoUp = dragItem and currentFolder ~= 'root' and eligible(ctx.Shared, dragItem,
			ctx.Shared.Bookmarks[currentFolder] and ctx.Shared.Bookmarks[currentFolder].Parent or 'root', dragHeight)
		if canGoUp and hit == parentButton.Entry then dropItem = {ID = '__parent', Kind = 'folder'} end
	end
	renderRow = function(root, controls, record, _, width, y)
		local item, childIndex = record.Item, record.Index
		local row = {Item = item, ChildIndex = childIndex}
		row.Root = Common.frame(ctx, root, 'BookmarkRow')
		row.Drop = ctx.Gui:Make('Frame', row.Root, {Name = 'DropTarget', BorderSizePixel = 0, Visible = false}, {BackgroundColor3 = 'Accent'})
		row.Insert = ctx.Gui:Make('Frame', row.Root, {Name = 'InsertTarget', BorderSizePixel = 0, Visible = false,
			Size = UDim2.new(1, 0, 0, 3), ZIndex = row.Root.ZIndex + 3, BackgroundTransparency = 0}, {BackgroundColor3 = 'Accent'})
		row.Open = controls:Button(row.Root, {Text = item.Title, Icon = item.Kind == 'folder' and 'folder' or 'bookmark',
			Tooltip = item.Kind == 'folder' and 'Open folder' or item.Address, Width = 260, Height = 44,
			OnClick = function() if item.Kind == 'folder' then setFolder(item.ID) else ctx.Navigate(item.Address) end end,
			DragBegin = function(event)
				dragItem, dragHeight, dragIndex = item, item.Kind == 'folder' and subtreeHeight(ctx.Shared, item.ID, {}) or 0, childIndex
				paintDrop(Common.point(event))
			end,
			Drag = function(event) paintDrop(Common.point(event)) end,
			DragEnd = function(event, cancelled)
				if not cancelled then paintDrop(Common.point(event)) end
				local target, index = dropItem, dropIndex
				dragItem, dragHeight, dragIndex, dropItem, dropIndex = nil, nil, nil, nil, nil
				for _, candidateRow in rows do candidateRow.Drop.Visible = false; candidateRow.Insert.Visible = false end
				if cancelled or not target then return end
				local parent = currentFolder
				if target.ID == '__parent' then parent = ctx.Shared.Bookmarks[currentFolder].Parent; index = nil
				elseif target.Kind == 'folder' then parent = target.ID; index = nil end
				local result, message = ctx.Shared:MoveItem(item.ID, parent, index)
				Common.result(ctx, result, message)
			end})
		row.Open:SetSelected(ctx.State.Highlight == item.ID)
		row.Detail = Common.text(controls, row.Root, item.Kind == 'folder' and (tostring(#ctx.Shared:GetChildren(item.ID)) .. ' items') or item.Address, 12, true)
		row.More = Common.button(controls, row.Root, '', 'overflow', function()
			ctx.Overlays:Menu(row.More.Root, {
				{Text = item.Kind == 'folder' and 'Rename folder' or 'Edit bookmark', Icon = 'edit', Action = function() editItem(item) end},
				{Text = 'Move to folder', Icon = 'move', Action = function() moveItem(item, row.More.Root) end},
				{Text = 'Move earlier', Icon = 'up', Disabled = childIndex == 1, Action = function() ctx.Shared:MoveItem(item.ID, currentFolder, childIndex - 1) end},
				{Text = 'Move later', Icon = 'down', Disabled = childIndex == record.Total, Action = function() ctx.Shared:MoveItem(item.ID, currentFolder, childIndex + 1) end},
				{Text = 'Delete', Icon = 'delete', Action = function() removeItem(item) end},
			})
		end, 'Organize ' .. item.Title, 44)
		table.insert(rows, row)
		Common.place(row.Root, 0, y, width, 76)
		Common.place(row.Drop, 0, 0, 4, 76)
		Common.place(row.Open.Root, 12, 0, width - 64, 44)
		Common.place(row.Detail, 24, 48, width - 76, 24)
		row.Detail.TextWrapped, row.Detail.TextTruncate = false, Enum.TextTruncate.AtEnd
		Common.place(row.More.Root, width - 44, 0, 44, 44)
	end
	redraw = function()
		local candidate = ctx.State.Folder
		currentFolder = (candidate == 'root' or (ctx.Shared.Bookmarks[candidate] and ctx.Shared.Bookmarks[candidate].Kind == 'folder')) and candidate or 'root'
		ctx.State.Folder = currentFolder
		parentButton:SetEnabled(currentFolder ~= 'root')
		locationButton:SetText(folderPath(ctx.Shared, currentFolder))
		table.clear(matches)
		local children = ctx.Shared:GetChildren(currentFolder)
		local query = (ctx.State.Filter or ''):lower()
		for childIndex, item in children do
			if query == '' or item.Title:lower():find(query, 1, true) or (item.Address or ''):lower():find(query, 1, true) then
				table.insert(matches, {Item = item, Index = childIndex, Total = #children})
			end
		end
		summary.Text = tostring(#children) .. ' items in this folder' .. (query ~= '' and (' / ' .. #matches .. ' matches') or '')
		empty.Visible = #matches == 0
		empty.Text = query ~= '' and 'No matching items in this folder. Try a different filter.'
			or 'This folder is empty. Add a bookmark or create a folder from New.'
		list:SetData(matches)
		page:Reflow()
	end
	page.Layout = function(width)
		Common.place(parentButton.Root, 0, 0, 44, 44)
		Common.place(locationButton.Root, 52, 0, width - 52, 44)
		Common.place(addButton.Root, 0, 56, 96, 44)
		Common.place(organizeButton.Root, 108, 56, 132, 44)
		Common.place(filter, 0, 116, width, 44)
		Common.place(summary, 0, 174, width, 22)
		list:Place(0, 210, width, 64)
		Common.place(empty, 0, 210, width, 64)
		return 210 + math.max(64, #matches * 88)
	end
	Common.connection(ctx, ctx.Shared.Changed, function(kind)
		if kind == 'Bookmarks' or kind == 'Replace' then redraw() end
	end)
	redraw()
	page:Restore()
	return page
end

return Bookmarks
