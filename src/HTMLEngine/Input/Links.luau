--!strict
local Links = {}
local URL = require(script.Parent.Parent.Navigation.URL)
local Names=require(script.Parent.Parent.DOM.ElementNames)

function Links.find(node: any): any?
	while node do
		if (Names.html(node,"a")or Names.html(node,"area"))and node.Attributes.href~=nil then return node end
		node = node.Parent
	end
	return nil
end

function Links.data(node: any, page: any?): any
	local attributes = node.Attributes
	local href = attributes.href or ""
	return {
		Href = href,
		URL = if page and page.BaseURL then (URL.resolve(page.BaseURL, href).URL or href) else href,
		Target = if attributes.target ~= nil then attributes.target else (if page then page.DefaultTarget or "" else ""),
		Download = attributes.download,
		Rel = attributes.rel or "", HrefLang = attributes.hreflang, Type = attributes.type,
		ReferrerPolicy = attributes.referrerpolicy, Ping = attributes.ping,
	}
end

function Links.activate(page: any, events: any, node: any, diagnostic: any,nativeData: any?,clickTarget: any?)
	local data = Links.data(node, page)
	for key,value in nativeData or {} do data[key]=value end
	local event = events:Emit(clickTarget or node, "click", data)
	if event.DefaultPrevented or not page.Alive then return end
	if page.Navigate then
		local ok, message = pcall(page.Navigate, data.URL, node, data)
		if not ok then diagnostic("Link navigation: " .. tostring(message)) end
	elseif data.Href == "" or data.Href:sub(1, 1) == "#" then
		if page.ScrollToFragment then page:ScrollToFragment(data.Href:sub(2)) end
	else
		diagnostic("Navigation handler unavailable for link: " .. data.Href)
	end
end

return Links
