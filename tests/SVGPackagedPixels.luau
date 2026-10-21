--!strict
return function(Sources,Embedded,Raster,Queue,loadImages,Hit,loadBackground)
	local function bytes(values)
		local result=buffer.create(#values)
		for i,value in values do buffer.writeu8(result,i-1,value)end
		return result
	end
	local pixels=bytes({255,0,255,255, 0,255,0,128, 0,0,255,0, 255,255,255,255})
	local markup='<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2" viewBox="0 0 2 2"><image href="pixels/tile" width="2" height="2" image-rendering="pixelated"/></svg>'
	local calls=0
	local function resolvePixels(url)
		calls+=1;assert(url=='pixels/tile')
		return {Width=2,Height=2,Pixels=pixels}
	end
	local resolve=Sources.newSVGResolver({['photo.png']={SVG=markup,ResolveImage=resolvePixels}})
	local function expect(actual,width,x,y,expected)
		local at=(y*width+x)*4
		for channel,value in expected do
			local read=buffer.readu8(actual,at+channel-1)
			assert(math.abs(read-value)<=1,`Packaged pixel {x},{y} channel {channel}: {read} vs {value}`)
		end
	end
	local document=Embedded.document(resolve('photo.png'),true)
	assert(document.ResolveImage==resolvePixels and document.Root.PackagedImageResolver==nil,
		'Trusted resolver belongs to the host document, not the cloned author SVG DOM')
	local scene,errors=Embedded.build(document,2,2)
	assert(#errors==0 and calls==1,'Embedded build must decode through the actual SVG resource bridge once')
	local actual,height=Raster.render(scene,nil,2)
	assert(height==2 and buffer.len(actual)==16)
	expect(actual,2,0,0,{255,0,255,255});expect(actual,2,1,0,{0,255,0,128})
	expect(actual,2,0,1,{0,0,0,0});expect(actual,2,1,1,{255,255,255,255})
	assert(buffer.tostring(pixels)==buffer.tostring(bytes({255,0,255,255, 0,255,0,128, 0,0,255,0, 255,255,255,255})),
		'Rendering must preserve original immutable straight-alpha pixels')
	-- One source can contain multiple lossless tiles while preserving full intrinsic size.
	local tileSVG='<svg width="4" height="2" viewBox="0 0 4 2"><image href="pixels/left" width="2" height="2" image-rendering="pixelated"/><image href="pixels/right" x="2" width="2" height="2" image-rendering="pixelated"/></svg>'
	local tiled=Sources.newSVGResolver({['large.png']={SVG=tileSVG,ResolveImage=function(url)
		assert(url=='pixels/left'or url=='pixels/right');return {Width=2,Height=2,Pixels=pixels}
	end}})
	local tiledScene,tiledErrors=Embedded.build(Embedded.document(tiled('large.png'),true),4,2)
	assert(#tiledErrors==0)
	local tiledBytes=Raster.render(tiledScene,nil,4)
	expect(tiledBytes,4,0,0,{255,0,255,255});expect(tiledBytes,4,2,0,{255,0,255,255})
	expect(tiledBytes,4,1,0,{0,255,0,128});expect(tiledBytes,4,3,0,{0,255,0,128})
	-- Pixel ownership clips and image geometry both need crisp edges when a
	-- source tile boundary falls inside a target pixel after strong downscaling.
	local solid=buffer.create(6*4*4)
	for at=0,buffer.len(solid)-1,4 do buffer.writeu32(solid,at,0xffff00ff)end
	local paddedSVG='<svg width="10" height="4"><defs><clipPath id="left"><rect shape-rendering="crispEdges" width="5" height="4"/></clipPath><clipPath id="right"><rect shape-rendering="crispEdges" x="5" width="5" height="4"/></clipPath></defs><image shape-rendering="crispEdges" href="left" width="6" height="4" clip-path="url(#left)"/><image shape-rendering="crispEdges" href="right" x="4" width="6" height="4" clip-path="url(#right)"/></svg>'
	local padded=Sources.newSVGResolver({['padded.png']={SVG=paddedSVG,ResolveImage=function()
		return {Width=6,Height=4,Pixels=solid}
	end}})
	local paddedScene,paddedErrors=Embedded.build(Embedded.document(padded('padded.png'),true),10,4)
	assert(#paddedErrors==0)
	local paddedBytes=Raster.render(paddedScene,nil,3)
	expect(paddedBytes,3,1,0,{255,0,255,255})
	-- Invalid decoded buffers keep existing SVG diagnostics and leave valid neighbors visible.
	local invalidSVG='<svg width="4" height="2"><image href="pixels/bad" width="2" height="2"/><rect x="2" width="2" height="2" fill="#ff00ff"/></svg>'
	local invalid=Sources.newSVGResolver({['bad.png']={SVG=invalidSVG,ResolveImage=function()
		return {Width=2,Height=2,Pixels=buffer.create(1)}
	end}})
	local badScene,badErrors=Embedded.build(Embedded.document(invalid('bad.png'),true),4,2)
	local invalidResource=false
	for _,issue in badErrors do if issue.Code=='invalid-image-resource'then invalidResource=true end end
	assert(invalidResource,'Existing decoded-image validators must remain authoritative')
	local badBytes=Raster.render(badScene,nil,4)
	expect(badBytes,4,0,0,{0,0,0,0});expect(badBytes,4,3,0,{255,0,255,255})
	-- Exercise the real retained <img> and CSS-background consumers, including resize and disposal.
	local jobs,images,cleanups,diagnostics={},{},{},{}
	local tasks={defer=function(fn)table.insert(jobs,coroutine.create(fn))end,wait=function()coroutine.yield()end}
	local function drain()
		local count=0
		while #jobs>0 do
			count+=1;assert(count<10000)
			local co=table.remove(jobs,1);local ok,message=coroutine.resume(co);assert(ok,message)
			if coroutine.status(co)~='dead'then table.insert(jobs,co)end
		end
	end
	local asset={CreateEditableImage=function(_,options)
		local image={Size=options.Size}
		function image:WritePixelsBuffer(_,_,value)self.Pixels=value end
		function image:Destroy()assert(not self.Dead);self.Dead=true end
		table.insert(images,image);return image
	end}
	local root={SetAttribute=function()end}
	local page={Alive=true,Root=root,AddCleanup=function(_,fn)table.insert(cleanups,fn)end}
	local item={SVG=resolve('photo.png'),SVGExternal=true,ContentWidth=4,ContentHeight=4,Style={FontSize=16},ImageGui={}}
	local tree={SVGItems={item}}
	local queue=loadImages(Embedded,Queue,Raster,Hit).start(page,tree,function(message)table.insert(diagnostics,message)end,
		{Asset=asset,Task=tasks,PrewarmStates=0})
	item.UpdateSVG();drain()
	local retained=item.ImageGui.ImageContent
	assert(retained and not retained.Dead and #diagnostics==0,diagnostics[1])
	expect(retained.Pixels,4,0,0,{255,0,255,255});expect(retained.Pixels,4,3,0,{0,255,0,128})
	expect(retained.Pixels,4,0,3,{0,0,0,0});expect(retained.Pixels,4,3,3,{255,255,255,255})
	local before=queue.Stats.Rasters;item.UpdateSVG();drain()
	assert(queue.Stats.Rasters==before and item.ImageGui.ImageContent==retained,'Unchanged packaged images reuse their retained pixels')
	local background=loadBackground().new(resolve,root,{Asset=asset,Task=tasks},function(message)table.insert(diagnostics,message)end)
	local slot={Image={}}
	assert(background:Draw(slot,'photo.png',4,4,'stretch'));drain()
	local backgroundImage=slot.Image.ImageContent
	assert(backgroundImage and not backgroundImage.Dead and #diagnostics==0,diagnostics[1])
	assert(buffer.tostring(backgroundImage.Pixels)==buffer.tostring(retained.Pixels),
		'The CSS-background path must produce the same scaled source as the retained image path')
	assert(background:Draw({Image={}},'large.png',8,4,'stretch')==false,'Absent URLs do not silently reuse other page images')
	assert(background:Draw(slot,'photo.png',2,2,'stretch'));drain()
	assert(backgroundImage.Dead and slot.Image.ImageContent~=backgroundImage,'Changing background raster dimensions releases the obsolete texture')
	expect(slot.Image.ImageContent.Pixels,2,0,0,{255,0,255,255})
	background:Destroy();page.Alive=false
	for _,cleanup in cleanups do cleanup()end;drain()
	assert(not item.UpdateSVG and queue.CacheBytes==0)
	for _,image in images do assert(image.Dead,'All image/background EditableImages must be destroyed with their owners')end
	print('Packaged SVG pixels: actual RGBA/alpha, source tiles, decoder errors, retained images, scaled backgrounds, cache and disposal passed')
end
