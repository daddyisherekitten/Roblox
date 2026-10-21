--!strict
-- Resolves browser media paths to page-local Roblox assets without changing HTML.
local ElementNames = require(script.Parent.Parent.DOM.ElementNames)
local MediaSources = {}

local function path(source: string): string
	local value = source:match("^%s*(.-)%s*$") :: string
	while value:sub(1, 2) == "./" do value = value:sub(3) end
	return value
end

local function assetURI(value: any, label: string): string
	local digits
	if type(value) == "number" then
		assert(value > 0 and value <= 9007199254740991 and value % 1 == 0,
			label .. " asset IDs must be positive, exactly representable integers; use a string for larger IDs")
		digits = string.format("%.0f", value)
	elseif type(value) == "string" then
		digits = value:match("^rbxassetid://(%d+)$") or value:match("^(%d+)$")
	end
	assert(digits, "Expected a Roblox " .. label:lower() .. " asset ID or rbxassetid:// URI")
	digits = digits:gsub("^0+", "")
	assert(digits ~= "", label .. " asset ID must be greater than zero")
	return "rbxassetid://" .. digits
end

local function assets(values: any?, label: string): {[string]: string}
	local result = {}
	assert(values == nil or type(values) == "table", label .. " mappings must be a table")
	for source, asset in values or {} do
		assert(type(source) == "string" and path(source) ~= "", label .. " source paths must be nonempty strings")
		local key = path(source)
		assert(result[key] == nil, "Duplicate " .. label:lower() .. " source path: " .. key)
		result[key] = assetURI(asset, label)
	end
	return result
end

function MediaSources.new(audio: any?, videos: any?, tracks: any?): any
	local audioAssets, videoAssets = assets(audio, "Audio"), assets(videos, "Video")
	local trackSources = {}
	assert(tracks == nil or type(tracks) == "table", "Track mappings must be a table")
	for source, contents in tracks or {} do
		assert(type(source) == "string" and path(source) ~= "", "Track source paths must be nonempty strings")
		assert(type(contents) == "string", "Track mappings must contain WebVTT strings")
		local key = path(source)
		assert(trackSources[key] == nil, "Duplicate track source path: " .. key)
		trackSources[key] = contents
	end
	local resolver = {}
	function resolver:Asset(kind: string, source: string): string?
		return (if kind == "audio" then audioAssets else videoAssets)[path(source)]
	end
	function resolver:Track(source: string): string? return trackSources[path(source)] end
	return resolver
end

local function acceptedType(node: any, kind: string): boolean
	local value = (node.Attributes.type or ""):match("^%s*(.-)%s*$"):lower()
	if value == "" then return true end
	local mediaType = value:match("^([^;]+)")
	return mediaType ~= nil and mediaType:match("^" .. kind .. "/[a-z0-9.+%-]+$") ~= nil
end

function MediaSources.select(node: any, kind: string, resolver: any): (string, string?)
	local direct = node.Attributes.src
	if direct and direct:match("%S") then return direct, resolver:Asset(kind, direct) end
	local first: string? = nil
	for _, child in node.Children do
		if ElementNames.html(child, "source") and acceptedType(child, kind) then
			local source = child.Attributes.src
			if source and source:match("%S") then
				first = first or source
				local asset = resolver:Asset(kind, source)
				if asset then return source, asset end
			end
		end
	end
	return first or "", if first then resolver:Asset(kind, first) else nil
end

function MediaSources.tracks(node: any, resolver: any): {any}
	local result = {}
	for _, child in node.Children do
		if ElementNames.html(child, "track") then
			local source = child.Attributes.src or ""
			local kind = (child.Attributes.kind or "subtitles"):lower()
			if kind == "subtitles" or kind == "captions" or kind == "descriptions" or kind == "chapters" or kind == "metadata" then
				table.insert(result, {Node=child, Source=source, Contents=resolver:Track(source), Kind=kind,
					Label=child.Attributes.label or "", Language=child.Attributes.srclang or "", Default=child.Attributes.default ~= nil})
			end
		end
	end
	return result
end

return MediaSources
