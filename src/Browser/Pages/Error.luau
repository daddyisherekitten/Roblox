--!nonstrict
local Common = require(script.Parent.Common)
local Icons = require(script.Parent.Parent.Icons)

local ErrorPage = {}

function ErrorPage.Render(ctx)
	local failure = ctx.State.Error or ctx.Error or {}
	if type(failure) == 'string' then failure = {Message = failure} end
	if type(failure) ~= 'table' then failure = {} end
	local page = Common.page(ctx, failure.Title or 'This page is unavailable',
		failure.Message or 'Wayline could not open this address. Choose Home to continue with a registered local page.')
	local artwork = Common.frame(ctx, page.Content, 'ErrorArtwork')
	Icons.draw(ctx.Gui, artwork, 'warning', 56, 'TextMuted')
	local address = Common.text(ctx.Controls, page.Content, failure.Address or '', 13, true)
	local back = Common.button(ctx.Controls, page.Content, 'Go back', 'back', function() ctx.Browser:Back() end, 'Return to the previous page', 140)
	local home = Common.button(ctx.Controls, page.Content, 'Go Home', 'home', function() ctx.Navigate('wayline://home') end, 'Open Wayline Home', 140)
	local retry
	if failure.Retry then retry = Common.button(ctx.Controls, page.Content, 'Try again', 'reload', function()
		if failure.Address then ctx.Navigate(failure.Address) else ctx.Browser:Reload() end
	end,
		'Retry preparing this page', 140) end
	if ctx.Browser.CanGoBack then back:SetEnabled(ctx.Browser:CanGoBack()) end
	page.Layout = function(width)
		Common.place(artwork, 0, 0, 56, 56)
		local height = failure.Address and Common.height(failure.Address, width, 13) or 0
		Common.place(address, 0, 76, width, height)
		Common.place(back.Root, 0, 100 + height, 140, 44)
		Common.place(home.Root, 152, 100 + height, 140, 44)
		if retry then Common.place(retry.Root, 0, 156 + height, 140, 44) end
		return (retry and 200 or 144) + height
	end
	page:Restore()
	return page
end

return ErrorPage
