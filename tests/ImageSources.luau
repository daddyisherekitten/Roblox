--!strict
return function(Sources)
	-- These synthetic IDs only exercise lookup; no image is requested or rendered.
	local mapping = {["bilder/landschaft.png"] = "rbxassetid://123", ["bilder/icon.png"] = 456,
		["https://example.test/a.png?v=2"] = "789", ["large.png"] = "12345678901234567890"}
	local resolve = Sources.newResolver(mapping)
	assert(resolve("bilder/landschaft.png") == "rbxassetid://123")
	assert(resolve(" ./bilder/landschaft.png ") == "rbxassetid://123")
	assert(resolve("bilder/icon.png") == "rbxassetid://456")
	assert(resolve("https://example.test/a.png?v=2") == "rbxassetid://789")
	assert(resolve("large.png") == "rbxassetid://12345678901234567890")
	assert(resolve("landschaft.png") == nil and resolve("Bilder/landschaft.png") == nil)
	assert(resolve("https://example.test/a.png?v=3") == nil and resolve("") == nil)
	mapping["bilder/landschaft.png"] = "321"
	assert(resolve("bilder/landschaft.png") == "rbxassetid://123", "Existing resolvers keep their own snapshot")
	assert(Sources.newResolver(mapping)("bilder/landschaft.png") == "rbxassetid://321")
	for _, value in {0, -1, 1.5, math.huge, 9007199254740992, "0", "000", "rbxassetid://", "rbxassetid://0", "1e3", "https://example.test/image.png", false} do
		assert(not pcall(Sources.newResolver, {["image.png"] = value}))
	end
	assert(not pcall(Sources.newResolver, {[""] = 1}))
	assert(not pcall(Sources.newResolver, {["image.png"] = 1, ["./image.png"] = 2}))
	assert(Sources.newResolver({["image.png"] = "000123"})("image.png") == "rbxassetid://123")
	local svg='<svg xmlns="http://www.w3.org/2000/svg" width="320" height="180"><circle cx="20" cy="20" r="10"/></svg>'
	local svgMapping={['sample.svg']=svg}
	local resolveSVG=Sources.newSVGResolver(svgMapping)
	svgMapping['sample.svg']='<svg></svg>'
	local first=resolveSVG('./sample.svg')
	local second=resolveSVG('sample.svg')
	assert(first and first.Name=='svg' and first.Attributes.width=='320' and first~=second
		and first.Children[1].Name=='circle' and resolveSVG('other.svg')==nil,
		'Local SVG sources must preserve exact paths and give each image an independent DOM')
	assert(not pcall(Sources.newSVGResolver,{['sample.svg']=false})
		and not pcall(Sources.newSVGResolver,{['sample.svg']=svg,['./sample.svg']=svg}))
	local calls=0
	local function firstPixels(url)
		calls+=1;return if url=='pixels/source' then {Width=1,Height=1,Pixels=buffer.create(4)}else nil
	end
	local descriptor={SVG=svg,ResolveImage=firstPixels}
	local packaged=Sources.newSVGResolver({['photo.png']=descriptor})
	descriptor.SVG='<svg width="1" height="1"/>'
	descriptor.ResolveImage=function()error('Changed descriptor must not affect a retained page')end
	local packagedFirst,packagedSecond=packaged('./photo.png'),packaged('photo.png')
	assert(packagedFirst~=packagedSecond and packagedFirst.Attributes.width=='320'
		and packagedFirst.PackagedImageResolver==firstPixels and packagedSecond.PackagedImageResolver==firstPixels,
		'Packaged images snapshot trusted source/resolver fields and retain independent author DOM trees')
	assert(calls==0 and packagedFirst.Attributes.PackagedImageResolver==nil,
		'Parsing must neither decode pixels eagerly nor place host callbacks into SVG attributes')
	assert(packagedFirst.PackagedImageResolver('missing')==nil and calls==1)
	local function otherPixels()return nil end
	local other=Sources.newSVGResolver({['photo.png']={SVG=svg,ResolveImage=otherPixels}})('photo.png')
	assert(other.PackagedImageResolver==otherPixels and packagedFirst.PackagedImageResolver==firstPixels,
		'Two pages with an identical image URL must retain their own trusted resolver')
	assert(first.PackagedImageResolver==nil,'Plain SVG strings never inherit a previous page resolver')
	for _,invalid in {{}, {SVG=''}, {SVG=svg}, {SVG=svg,ResolveImage=true},
		{SVG=17,ResolveImage=firstPixels}, {SVG=svg,ResolveImage='function()end'}} do
		assert(not pcall(Sources.newSVGResolver,{['image.png']=invalid}),'Invalid packaged-image descriptor')
	end
	local author=Sources.newSVGResolver({['plain.svg']='<svg PackagedImageResolver="function() return nil end"/>'})('plain.svg')
	assert(author.PackagedImageResolver==nil,'Author attributes cannot create host image callbacks')
	print("Image sources: exact paths/URLs, optional leading ./, asset validation and independent snapshots passed")
end
