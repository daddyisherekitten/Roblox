--!nonstrict
local function definition(route, title, icon, description, keywords, module)
	return {Route = route, Address = 'wayline://' .. route, Title = title, Icon = icon,
		Description = description, Keywords = keywords, Render = require(module).Render}
end

return {
	definition('home', 'Home', 'home', 'Your welcome page, local search, and personal quick links.', {'start', 'greeting', 'quick links', 'background'}, script.Home),
	definition('search', 'Search Results', 'search', 'Find registered local pages, saved bookmarks, and recent visits.', {'find', 'local', 'results'}, script.Search),
	definition('bookmarks', 'Bookmarks', 'bookmark', 'Save and organize your useful pages into folders.', {'favorites', 'folders', 'saved', 'organize'}, script.Bookmarks),
	definition('history', 'History', 'history', 'Find or remove your latest five hundred navigation visits.', {'recent', 'visited', 'clear', 'privacy'}, script.History),
	definition('settings', 'Settings', 'settings', 'Choose themes, accent colors, Home customization, and bookmark visibility.', {'preferences', 'theme', 'dark', 'light', 'accent', 'storage'}, script.Settings),
	definition('guide', 'Guide', 'guide', 'Learn Wayline navigation, bookmarks, storage, and local pages.', {'help', 'instructions', 'about', 'documentation'}, script.Guide),
}
