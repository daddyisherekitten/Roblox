--!strict
-- Small browser-style URL resolver for the local website catalog.
local URL = {}

local function trim(value: string): string
	return value:match("^%s*(.-)%s*$") or ""
end

local function splitSuffix(value: string): (string, string, string)
	local fragment = ""
	local hash = value:find("#", 1, true)
	if hash then fragment, value = value:sub(hash + 1), value:sub(1, hash - 1) end
	local query = ""
	local question = value:find("?", 1, true)
	if question then query, value = value:sub(question + 1), value:sub(1, question - 1) end
	return value, query, fragment
end

local function normalize(path: string): string
	local parts = {}
	for part in path:gmatch("[^/]+") do
		if part == ".." then if #parts > 0 then table.remove(parts) end
		elseif part ~= "." and part ~= "" then table.insert(parts, part) end
	end
	local result = "/" .. table.concat(parts, "/")
	if path:sub(-1) == "/" and result ~= "/" then result ..= "/" end
	return result
end

local function absoluteParts(value: string): any?
	local scheme, rest = value:match("^([%a][%w+%.%-]*)://(.*)$")
	if not scheme then return nil end
	local authority, suffix = rest:match("^([^/%?#]*)(.*)$")
	if not authority or authority == "" then return nil end
	local path, query, fragment = splitSuffix(if suffix == "" then "/" else suffix)
	local origin = scheme:lower() .. "://" .. authority:lower()
	return {Scheme = scheme:lower(), Origin = origin, Path = normalize(path), Query = query, Fragment = fragment}
end

function URL.canonical(path: string): string
	path = trim(path:gsub("\\", "/"))
	if path == "" then return "/" end
	if path:sub(1, 1) ~= "/" then path = "/" .. path end
	return normalize(path)
end

function URL.resolve(basePath: string, reference: string): any
	assert(type(basePath) == "string" and type(reference) == "string", "URL paths must be strings")
	local href = trim(reference)
	local scheme = href:match("^([%a][%w+%.%-]*):")
	if scheme then
		local absolute = absoluteParts(href)
		if absolute then
			absolute.Kind, absolute.Href = "external", href
			absolute.URL = absolute.Origin .. absolute.Path .. (if absolute.Query ~= "" then "?" .. absolute.Query else "") .. (if absolute.Fragment ~= "" then "#" .. absolute.Fragment else "")
			return absolute
		end
		return {Kind = "external", Href = href, URL = href, Scheme = scheme:lower()}
	end
	local base = absoluteParts(trim(basePath))
	if href:sub(1, 2) == "//" then
		if base then return URL.resolve(base.Origin .. base.Path, base.Scheme .. ":" .. href) end
		return {Kind = "external", Href = href, URL = href}
	end
	local path, query, fragment = splitSuffix(href)
	local current, currentQuery
	if base then current, currentQuery = base.Path, base.Query
	else current, currentQuery = splitSuffix(URL.canonical(basePath)) end
	if path == "" then
		path = current
		if not href:find("?", 1, true) then query = currentQuery end
	elseif path:sub(1, 1) ~= "/" then
		local directory = current:match("^(.*)/") or ""
		path = directory .. "/" .. path
	end
	path = URL.canonical(path)
	local full = (if base then base.Origin else "") .. path .. (if query ~= "" then "?" .. query else "") .. (if fragment ~= "" then "#" .. fragment else "")
	return {
		Kind = if base then "external" else "internal", Href = href, Path = path, Query = query, Fragment = fragment,
		Scheme = if base then base.Scheme else nil, Origin = if base then base.Origin else nil, URL = full,
	}
end

function URL.routeKey(path: string): string
	local absolute = absoluteParts(trim(path))
	local clean = splitSuffix(URL.canonical(if absolute then absolute.Path else path))
	if clean ~= "/" and clean:sub(-1) == "/" then clean ..= "index.html" end
	return (if absolute then absolute.Origin else "") .. clean
end

function URL.path(address: string): string
	local absolute = absoluteParts(trim(address))
	return URL.canonical(if absolute then absolute.Path else address)
end

function URL.origin(address: string): string?
	local absolute = absoluteParts(trim(address))
	return if absolute then absolute.Origin else nil
end

function URL.decodeFragment(value: string): string
	return (value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16) :: number) end))
end

return URL
