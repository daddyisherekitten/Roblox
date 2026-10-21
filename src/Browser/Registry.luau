--!strict
-- Internal pages and explicitly registered content providers share metadata.
local Registry={};Registry.__index=Registry
function Registry.new(definitions)
	local self=setmetatable({Routes={},Entries={}},Registry)
	for _,definition in definitions or{}do self:Register(definition)end
	return self
end
function Registry:Register(definition)
	assert(type(definition)=='table'and type(definition.Title)=='string','A page needs a title')
	local route=(definition.Route or''):lower()
	local address=definition.Address or('wayline://'..route)
	assert(type(address)=='string'and #address>0,'A page needs an address')
	assert(not self:FindAddress(address),'This page address is already registered')
	local page=table.clone(definition);page.Route=route;page.Address=address
	page.Icon=page.Icon or'page';page.Description=page.Description or'';page.Keywords=page.Keywords or{}
	if page.Render then assert(route:match('^[a-z][a-z0-9%-]*$'),'Invalid page route');assert(not self.Routes[route],'Duplicate page route');self.Routes[route]=page end
	table.insert(self.Entries,page);return page
end
function Registry:Get(route)return self.Routes[(route or''):lower()]end
function Registry:FindAddress(address)
	for _,entry in self.Entries do if entry.Address==address then return entry end end
	return nil
end
function Registry:List()
	local entries={};for _,entry in self.Entries do if not entry.Hidden then table.insert(entries,entry)end end;return entries
end
return Registry
