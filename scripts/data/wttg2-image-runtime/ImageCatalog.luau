--!strict
-- Host-only, lossless packaged originals. No Browser/WindowManager dependency.
local Manifest = require(script.Parent.ImageManifest)
local Decoder = require(script.Parent.PixelDecoder)
local Catalog = {}
local cache: any = setmetatable({}, {__mode="v"})
local descriptors: any = setmetatable({}, {__mode="v"})
local origin = "http://localhost:8000"
local byPath, byRoot = {}, {}
for _, image in Manifest do
	byPath[image.Path] = image
	local site = image.Path:match("^/([^/]+)/") or ""
	if not byRoot[site] then byRoot[site] = {} end
	table.insert(byRoot[site], image)
end

local function tilePixels(name: string): any
	if cache[name] then return cache[name] end
	local packed = require(script.Parent.Pixels[name])
	local pixels = Decoder.decode(packed)
	local resource = {Width=packed.Width,Height=packed.Height,Pixels=pixels}
	cache[name] = resource
	return resource
end

local function descriptor(image: any): any
	if descriptors[image.Path] then return descriptors[image.Path] end
	local definitions, pictures = {}, {}
	local byURL = {}
	for index, tile in image.Tiles do
		local id = "tile" .. index
		local href = "pixels/" .. tile.Name
		byURL[href] = tile.Name
		table.insert(definitions, `<clipPath id="{id}"><rect shape-rendering="crispEdges" x="{tile.X}" y="{tile.Y}" width="{tile.Width}" height="{tile.Height}"/></clipPath>`)
		table.insert(pictures, `<image shape-rendering="crispEdges" href="{href}" x="{tile.Left}" y="{tile.Top}" width="{tile.PixelWidth}" height="{tile.PixelHeight}" clip-path="url(#{id})"/>`)
	end
	local item = {
		SVG = `<svg width="{image.Width}" height="{image.Height}" viewBox="0 0 {image.Width} {image.Height}"><defs>{table.concat(definitions)}</defs>{table.concat(pictures)}</svg>`,
		ResolveImage = function(url: string): any
			local name = byURL[url]
			return if name then tilePixels(name) else nil
		end,
	}
	descriptors[image.Path] = item
	return item
end

local function parts(path: string): {string}
	local result = {}
	for part in path:gmatch("[^/]+") do table.insert(result, part) end
	return result
end

local function relativePath(directory: string, target: string): string
	local from, to = parts(directory), parts(target)
	local shared = 0
	while shared < math.min(#from, #to) and from[shared+1] == to[shared+1] do shared += 1 end
	local result = {}
	for _ = shared+1, #from do table.insert(result, "..") end
	for index = shared+1, #to do table.insert(result, to[index]) end
	return table.concat(result, "/")
end

-- Explicit source paths include CSS/shared dependencies discovered by the
-- publisher. The compatible default only builds descriptors for the own site
-- and shared root images; it never allocates every site's SVGs per document.
function Catalog.forPage(pageURL: string, sourcePaths: {string}?): any
	local directory = pageURL:match("^https?://[^/]+(/.*/)") or "/"
	local siteRoot = directory:match("^/([^/]+)/")
	local sources, selected = {}, {}
	if sourcePaths then
		for _, sourcePath in sourcePaths do
			local imagePath = sourcePath:match("^https?://[^/]+(/[^?#]*)") or sourcePath
			local image = byPath[imagePath]
			if image then selected[image.Path] = image end
		end
	else
		for _, image in byRoot[siteRoot or ""] or {} do selected[image.Path] = image end
		if siteRoot then
			for _, image in byRoot[""] or {} do selected[image.Path] = image end
		end
	end
	for _, image in selected do
		-- Keep per-page aliases private and unambiguous. Same basename in another
		-- site never wins; absolute URLs remain available for linked resources.
		local item = descriptor(image)
		sources[image.Path] = item
		sources[origin .. image.Path] = item
		sources[relativePath(directory, image.Path)] = item
	end
	return sources
end
return Catalog
