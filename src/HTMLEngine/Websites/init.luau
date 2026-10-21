--!strict
-- Website modules keep page content separate from the reusable renderer.
local Websites = {}
local URL = require(script.Parent.Navigation.URL)
local NotFound = require(script.Parent.Navigation.NotFound)
local loaded = {}
local DEVELOPMENT_ORIGIN = "http://localhost:8000"

local function childSource(name: string, module: ModuleScript, childName: string): string?
	local child = module:FindFirstChild(childName)
	if child == nil then return nil end
	assert(child:IsA("ModuleScript"), "Website " .. name .. " child " .. childName .. " must be a ModuleScript")
	local source = require(child)
	assert(type(source) == "string", "Website " .. name .. " child " .. childName .. " must return a string")
	return source
end

local function validate(name: string, module: ModuleScript, website: any): any
	assert(type(website) == "table", "Website " .. name .. " must return a table")
	website = table.clone(website)

	-- Structured websites use their child modules as the canonical source. This
	-- also lets pages created directly in Studio omit HTML/CSS from init.luau.
	local html = childSource(name, module, "HTML")
	local css = childSource(name, module, "CSS")
	if html ~= nil then website.HTML = html end
	if css ~= nil then
		local stylesheets = table.clone(website.Stylesheets or {})
		stylesheets["styles.css"] = css
		website.Stylesheets = stylesheets
	end

	assert(type(website.HTML) == "string", "Website " .. name .. " must provide HTML")
	assert(website.CSS == nil or type(website.CSS) == "string", "Website " .. name .. " CSS must be a string")
	assert(website.Stylesheets == nil or type(website.Stylesheets) == "table", "Website " .. name .. " Stylesheets must be a table")
	for href, source in website.Stylesheets or {} do
		assert(type(href) == "string" and href ~= "" and type(source) == "string", "Website " .. name .. " stylesheet entries must map non-empty href strings to CSS strings")
	end
	assert(website.Options == nil or type(website.Options) == "table", "Website " .. name .. " Options must be a table")
	assert(website.URL == nil or type(website.URL) == "string", "Website " .. name .. " URL must be a string")
	if website.URL ~= nil then assert(website.URL:match("^https?://") and URL.origin(website.URL) ~= nil, "Website " .. name .. " URL must be an absolute http(s) address") end
	assert(website.Path == nil or type(website.Path) == "string", "Website " .. name .. " Path must be a string")
	local javascript = childSource(name, module, "JavaScript")
	if javascript ~= nil then
		local scriptPath = website.ScriptPath or "app.js"
		assert(type(scriptPath) == "string" and scriptPath ~= "", "Website " .. name .. " ScriptPath must be a non-empty string")
		local base = website.URL or (DEVELOPMENT_ORIGIN .. URL.canonical(website.Path or ("/" .. name .. "/index.html")))
		local options = table.clone(website.Options or {})
		assert(options.JavaScriptServices == nil or type(options.JavaScriptServices) == "table", "Website JavaScriptServices must be a table")
		local services = table.clone(options.JavaScriptServices or {})
		assert(services.ScriptSources == nil or type(services.ScriptSources) == "table", "Website ScriptSources must be a table")
		local sources = table.clone(services.ScriptSources or {})
		sources[URL.resolve(base, scriptPath).URL] = javascript
		services.ScriptSources = sources
		options.JavaScriptServices = services
		website.Options = options
	end
	return website
end

function Websites.get(name: string): any
	assert(type(name) == "string" and name ~= "", "Website name must be a non-empty string")
	if name == "NotFound" then return NotFound end
	local module = script:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "Unknown website " .. name .. ". Available: " .. table.concat(Websites.names(), ", "))
	if not loaded[name] then loaded[name] = validate(name, module, require(module)) end
	return loaded[name]
end

function Websites.names(): {string}
	local names = {}
	for _,child in script:GetChildren() do if child:IsA("ModuleScript") then table.insert(names, child.Name) end end
	table.sort(names)
	return names
end

function Websites.path(name: string): string
	return URL.path(Websites.url(name))
end

function Websites.url(name: string): string
	local website = Websites.get(name)
	return website.URL or (DEVELOPMENT_ORIGIN .. URL.canonical(website.Path or ("/" .. name .. "/index.html")))
end

function Websites.resolve(currentName: string, href: string): any
	return Websites.resolveURL(Websites.url(currentName), href)
end

function Websites.resolveURL(currentURL: string, href: string): any
	local result = URL.resolve(currentURL, href)
	local wanted = URL.routeKey(result.URL or result.Path or href)
	for _, name in Websites.names() do
		if URL.routeKey(Websites.url(name)) == wanted then result.Kind = "internal"; result.Name = name; return result end
	end
	if result.Origin == URL.origin(currentURL) then result.Kind = "missing" end
	return result
end

return Websites
