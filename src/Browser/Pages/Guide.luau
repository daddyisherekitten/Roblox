--!nonstrict
local Common = require(script.Parent.Common)

local Guide = {}

local sections = {
	{'A little direction', 'Wayline is a fictional in-game browser. Its own pages are native Roblox interfaces, with a local address scheme and a shared collection of bookmarks and visits. The host can separately register supported HTML pages. An arbitrary internet address is not a promise that Wayline can render that site.'},
	{'Addresses and local search', 'Enter home, bookmarks, history, settings, or guide to open an exact page alias. The same pages have addresses such as wayline://home. Other phrases search registered page titles, routes, descriptions, and keywords, plus your bookmarks and history. Suggestions under the address field combine local pages, bookmarks, and recent visits. Select a suggestion with a pointer, or submit your own text with Enter.'},
	{'Back, Forward, and Reload', 'Each window keeps its own navigation stack. Back and Forward return to saved page state and scroll positions. Navigating somewhere new after Back replaces the forward branch. Reload recreates the current page and resets its temporary inputs and scroll position, while keeping shared settings, Home customization, bookmarks, and global history. The host may hide the three navigation buttons in an auxiliary window; its address field stays available.'},
	{'Make Home yours', 'Use Customize at the bottom of Home to edit the greeting or background. Add shortcut creates one of up to twelve shortcuts. Each shortcut menu can edit its name and address, remove it, or move it earlier or later. Drag a shortcut onto another shortcut to change its position. Home changes are shared across your browser windows.'},
	{'Bookmarks that stay organized', 'The bookmark control beside the address saves or removes the current page. A canonical address has one bookmark across the collection; adding it again reveals that existing bookmark. Bookmarks can contain up to three hundred saved pages and fifty folders, with a maximum of five folder levels. Use New to add items. Item menus provide rename or edit, delete, visible Move, and manual ordering. Drag onto the center of a highlighted folder to move inside it. Drop near the upper or lower edge of a row to change its position; a horizontal line marks the insertion point. Folder-only collections can be reordered this way too. Moving a folder into itself or one of its descendants is refused. Sorting A to Z or Z to A changes the current folder\'s stored order; dragging can adjust it later. Deleting a non-empty folder requires confirmation and deletes its contents too.'},
	{'History is separate', 'History keeps the latest five hundred successful navigation visits, including Back and Forward. Reloading, restoring a session, and failed navigation do not create entries. Search by title or address, open a visit, remove one entry, or clear the full history with confirmation. Removing history does not alter the Back and Forward navigation stack.'},
	{'Settings and storage', 'Choose Light or Dark, a Blue, Purple, or Green accent, and bookmarks bar visibility in Settings. Changes update live pages without clearing your inputs. The storage status explains whether changes can survive rejoining. If server storage is unavailable, Wayline remains usable and keeps current changes in memory. It does not claim an unavailable permanent save succeeded.'},
	{'When a window closes', 'A host can retain an exported session snapshot and supply it when mounting another browser. That snapshot keeps the address, navigation stack, serializable page state, and scroll position. On a rejoin, a saved server session restores the current canonical address with a fresh one-entry stack. Temporary form edits are not restored across rejoins. An explicit host snapshot takes priority over the server session, followed by a default Home session. A late storage response never replaces newer local interactions.'},
	{'Pointer and touch', 'Wayline uses one browser-owned pointer router. Press on a control and release over the same control to activate it. Moving beyond the drag threshold cancels that click. A completed drag does not also open a link. On touch, swipe immediately to scroll a long page. To rearrange a quick link or bookmark inside a scroll region, hold it for about 0.28 seconds before dragging. Mouse dragging starts after its movement threshold. Hover tips are optional assistance; visible controls and menus provide the same actions on touch. Scroll long pages with the wheel, touch, or their draggable scrollbars. Browser actions do not add keyboard shortcuts.'},
	{'Local pages and future providers', 'Built-in pages are registered with a route, title, named image icon or Roblox image ID, description, optional keywords, and a render function. A page receives the shared GUI helper, input registration, theme, cleanup scope, current serializable state, and navigation access. A host can register another native page or connect a separate approved page provider. Native pages do not make their own global input listeners, window engines, or persistence requests.'},
}

function Guide.Render(ctx)
	local page = Common.page(ctx, 'The Wayline guide', 'A practical guide to local pages, navigation, personal organization, and storage.')
	local rows = {}
	for _, section in sections do
		table.insert(rows, {Title = Common.text(ctx.Controls, page.Content, section[1], 20),
			Body = Common.text(ctx.Controls, page.Content, section[2], 14, true)})
	end
	local links = {}
	for _, item in {{'Home', 'home'}, {'Bookmarks', 'bookmarks'}, {'History', 'history'}, {'Settings', 'settings'}} do
		table.insert(links, Common.button(ctx.Controls, page.Content, item[1], item[2], function() ctx.Navigate('wayline://' .. item[2]) end,
			'Open ' .. item[1], 140))
	end
	page.Layout = function(width)
		local y = 0
		for _, row in rows do
			local titleHeight = Common.height(row.Title.Text, width, 20)
			local bodyHeight = Common.height(row.Body.Text, width, 14)
			Common.place(row.Title, 0, y, width, titleHeight)
			Common.place(row.Body, 0, y + titleHeight + 12, width, bodyHeight)
			y += titleHeight + bodyHeight + 44
		end
		local columns = width >= 640 and 4 or 2
		local itemWidth = (width - (columns - 1) * 12) / columns
		for index, button in links do Common.place(button.Root, ((index - 1) % columns) * (itemWidth + 12), y + math.floor((index - 1) / columns) * 56, itemWidth, 44) end
		return y + math.ceil(#links / columns) * 56
	end
	page:Restore()
	return page
end

return Guide
