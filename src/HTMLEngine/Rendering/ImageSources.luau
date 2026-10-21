--!strict
local ImageSources = {}
local Parser = require(script.Parent.Parent.HTML.Parser)
local function path(source: string): string
	local value = source:match("^%s*(.-)%s*$") :: string
	while value:sub(1, 2) == "./" do value = value:sub(3) end
	return value
end

local function assetURI(value: any): string
	local digits
	if type(value) == "number" then
		assert(value > 0 and value <= 9007199254740991 and value % 1 == 0, "Image asset IDs must be positive, exactly representable integers; use a string for larger IDs")
		digits = string.format("%.0f", value)
	elseif type(value) == "string" then
		digits = value:match("^rbxassetid://(%d+)$") or value:match("^(%d+)$")
	end
	assert(digits, "Expected a Roblox image asset ID or rbxassetid:// URI")
	digits = digits:gsub("^0+", "")
	assert(digits ~= "", "Image asset ID must be greater than zero")
	return "rbxassetid://" .. digits
end

-- A private snapshot keeps one page's source mapping stable. No downloads,
-- basename guessing or substitution of unrelated images for missing entries.
function ImageSources.newResolver(assets: any?): (string) -> string?
	local resolved = {}
	assert(assets == nil or type(assets) == "table", "Image mappings must be a table")
	for source, asset in assets or {} do
		assert(type(source) == "string" and path(source) ~= "", "Image source paths must be nonempty strings")
		local key = path(source)
		assert(resolved[key] == nil, "Duplicate image source path: " .. key)
		resolved[key] = assetURI(asset)
	end
	return function(source: string): string? return resolved[path(source)] end
end

-- Local SVG files packaged with a website can use the existing SVG rasterizer;
-- their browser paths remain unchanged and need no published Roblox image ID.
-- A trusted host may also supply decoded image resources for an SVG wrapper.
-- Author markup never creates callbacks; snapshot their host descriptor per page.
function ImageSources.newSVGResolver(sources: any?): (string) -> any?
	local resolved = {}
	assert(sources == nil or type(sources) == "table", "SVG mappings must be a table")
	for source, value in sources or {} do
		assert(type(source) == "string" and path(source) ~= "", "SVG source paths must be nonempty strings")
		local markup,resolver=value,nil
		if type(value)=="table"then
			markup,resolver=value.SVG,value.ResolveImage
			assert(type(resolver)=="function","Packaged SVG mappings must contain a trusted ResolveImage function")
		end
		assert(type(markup) == "string" and markup ~= "", "SVG mappings must contain SVG markup")
		local key = path(source)
		assert(resolved[key] == nil, "Duplicate SVG source path: " .. key)
		resolved[key] = {SVG=markup,ResolveImage=resolver}
	end
	return function(source: string): any?
		local value = resolved[path(source)]
		if not value then return nil end
		local document = Parser.parse(value.SVG)
		for _, child in document.Children do
			if child.Kind == "Element" and child.Name == "svg" then
				child.PackagedImageResolver=value.ResolveImage
				return child
			end
		end
		error("SVG mapping does not contain an svg root: " .. source)
	end
end

return ImageSources
