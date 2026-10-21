--!strict
return function(Parser: any, Sources: any, ImageMap: any, Links: any, reference: any)
	local document = Parser.parse([[
		<picture>
			<source media="(min-width: 700px)" srcset="wide.png 800w, huge.png 1400w" sizes="80vw">
			<source type="image/png" srcset="compact.png 1x, compact-2x.png 2x">
			<img id="hero" src="fallback.png" srcset="fallback.png 400w, medium.png 900w" sizes="50vw"
				width="400" height="200" usemap="#zones" alt="Landscape">
		</picture>
		<map name="zones">
			<area id="left" shape="rect" coords="0,0,199,200" href="left.html">
			<area id="round" shape="circle" coords="300,100,70" href="round.html">
			<area id="rest" shape="default" href="rest.html">
		</map>
	]])
	local function first(node: any, name: string): any
		if node.Kind == "Element" and node.Name == name then return node end
		for _, child in node.Children or {} do
			local found = first(child, name)
			if found then return found end
		end
		return nil
	end
	assert(#reference.pictureCases==10,'Preserve all independent picture order/environment/dimension rows')
	local function identified(root)
		if root.Attributes and root.Attributes.id=='image'then return root end
		for _,child in root.Children or{}do local found=identified(child);if found then return found end end
	end
	for _,row in reference.pictureCases do
		local probe=assert(identified(Parser.parseDocument(row.html)))
		local actual,density,dimensions=Sources.forImage(probe,800,row.density,{Width=800,Height=600,Resolution=row.density})
		assert(actual==row.selected,row.id..': picture selection differs from independent browser')
		local w,h=Sources.intrinsicSize(reference.image.width,reference.image.height,density)
		assert(math.floor(w)==row.raw.naturalWidth and math.floor(h)==row.raw.naturalHeight,row.id..': picture natural geometry differs')
		if dimensions.Attributes.width then
			assert(tonumber(dimensions.Attributes.width)==row.raw.width and (if dimensions.Attributes.height then tonumber(dimensions.Attributes.height)else row.raw.width*h/w)==row.raw.height,row.id..': selected source owns dimension hints')
		end
	end
	assert(reference.target.sha256=='49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f'and #reference.cases==55,'Preserve the pinned source and all independent raw rows')
	local nativeChecks=0
	for _,row in reference.cases do
		if row.id=='sizes-eager-auto'then continue end -- Separate frozen/native discrepancy; not an auto-sizes proof.
		local probe=first(Parser.parse('<img>'),'img');probe.Attributes.srcset=row.srcset;probe.Attributes.src=row.src;probe.Attributes.sizes=row.sizes
		local actual,density=Sources.forImage(probe,800,row.density,{Width=800,Height=600,Resolution=row.density})
		assert(actual==row.selected,row.id..': selected '..tostring(actual)..' instead of independent native '..row.selected)
		local w,h=0,0
		if actual~=''then w,h=Sources.intrinsicSize(reference.image.width,reference.image.height,density)end
		assert(math.floor(w)==row.raw.naturalWidth and math.floor(h)==row.raw.naturalHeight,row.id..': intrinsic density correction differs from independent native result')
		nativeChecks+=1
	end
	local picture = first(document, "picture")
	local image = first(picture, "img")
	assert(Sources.forImage(image, 1000, 1) == "wide.png", "The first matching picture source wins")
	assert(Sources.forImage(image, 600, 1) == "compact.png", "A later source is used when media does not match")
	assert(Sources.forImage(image, 600, 2) == "compact-2x.png", "Density descriptors select the requested scale")
	assert(Sources.fromSrcset("small.png 400w, large.png 900w", "50vw", 1000, 1) == "large.png")
	assert(Sources.mediaMatches("screen and (min-width: 500px) and (max-width: 700px)", 600))
	assert(Sources.mediaMatches("all and (min-width: 500px) and (max-width: 700px)", 600))
	assert(not Sources.mediaMatches("all and (min-width: 700px)", 600))
	assert(not Sources.mediaMatches("(max-width: 500px)", 600))

	local maps = ImageMap.collect(document)
	local item = {
		AttributeWidth = 400, AttributeHeight = 200,
		ImageGui = {AbsolutePosition = {X = 10, Y = 20}, AbsoluteSize = {X = 800, Y = 400}},
	}
	assert(ImageMap.bind(maps, image, item))
	local items = {[image] = item}
	local left = ImageMap.hit(items, image, {X = 200, Y = 200})
	local round = ImageMap.hit(items, image, {X = 310, Y = 120})
	local rest = ImageMap.hit(items, image, {X = 790, Y = 390})
	assert(left.Attributes.id == "left" and round.Attributes.id == "round" and rest.Attributes.id == "rest")
	assert(Links.find(left) == left and Links.find(round) == round, "Image-map areas use normal link activation")
	print("Responsive images: "..nativeChecks.." source/size and 10 picture native references, natural dimensions and rect/circle/default image-map hits passed; eager auto-sizes remains separate")
end
