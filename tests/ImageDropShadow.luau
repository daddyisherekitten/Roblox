--!strict
return function(Filter,Raster,Parser,loadRenderTree,loadWordLayout,loadBlur)
	for _,bad in {'drop-shadow()','drop-shadow(3px)','drop-shadow(0 0 -1px)','drop-shadow(0 0 101px)','drop-shadow(1001px 0)','drop-shadow(0 2%)','drop-shadow(0 0 1px 2px)','drop-shadow(inset 0 0)','drop-shadow(0 red 0)','drop-shadow(red blue 0 0)','drop-shadow(0 0 rgb(1,2))','drop-shadow(0 0), drop-shadow(0 0)'} do
		assert(Filter.parse(bad)==nil,bad)
	end
	for _,valid in {'drop-shadow(red -2px 3px)','drop-shadow(0 0 rgba(0, 0, 0, .5))','drop-shadow(hsl(120, 100%, 50%) 0 0)','drop-shadow(0 0 #0008)','drop-shadow(0 0 currentcolor)'} do assert(Filter.parse(valid),valid) end
	local renderer=loadRenderTree({create=function(_,_,props) return table.clone(props) end,modifier=function(_,_,props) return table.clone(props) end})
	local words=loadWordLayout({['Layout/FontProfiles']={face=function(font) return font end},['Layout/TextMeasure']={measure=function(_,_,size) return {X=10,Y=size} end}})
	local function build(css,color)
		local tree=renderer.build(Parser.parse('<p style="color:'..(color or 'black')..'"><img src="x" width="3" height="3" style="filter:'..css..'"></p>'),{},error,nil,nil,nil,function() return 'rbxassetid://1' end)
		words.arrange(tree.Children[1].Children[1],300,0,0,function() return true end)
		return tree.ImageItems[1]
	end
	local source=buffer.create(36)
	for i=0,8 do buffer.writeu8(source,i*4+2,255) end
	buffer.writeu8(source,16,255); buffer.writeu8(source,18,0); buffer.writeu8(source,19,255)
	local size={X=3,Y=3}
	local function render(css,pixels)
		local item=build(css); local plan=Raster.plan(item,size)
		return Raster.render(pixels or source,size,item.Style.Filter,plan,nil),plan
	end
	local function pixel(bytes,p,x,y,c) return buffer.readu8(bytes,((y+p.Pad)*p.Width+x+p.Pad)*4+(c or 3)) end
	local b,p=render('drop-shadow(2px 0 blue)')
	assert(pixel(b,p,1,1)==255 and pixel(b,p,1,1,0)==255,'Source remains in front')
	assert(pixel(b,p,3,1)==255 and pixel(b,p,3,1,2)==255,'Shadow follows the opaque dot')
	assert(pixel(b,p,2,0)==0 and pixel(b,p,2,2)==0,'No rectangular shadow from transparent source pixels')
	b,p=render('drop-shadow(-2px -1px blue)'); assert(pixel(b,p,-1,0)==255)
	b,p=render('drop-shadow(.5px 0 blue)'); assert(math.abs(pixel(b,p,2,1)-128)<=1)
	local partial=buffer.create(36); buffer.copy(partial,0,source); buffer.writeu8(partial,19,128)
	b,p=render('drop-shadow(2px 0 rgba(0,0,255,.5))',partial); assert(math.abs(pixel(b,p,3,1)-64)<=1)
	b,p=render('drop-shadow(0 0 blue)',partial)
	assert(math.abs(pixel(b,p,1,1)-192)<=1 and math.abs(pixel(b,p,1,1,0)-170)<=1,'Premultiplied source-over composition')
	b,p=render('drop-shadow(4px 0 1px blue)')
	assert(pixel(b,p,5,1)>0 and pixel(b,p,5,1)<255 and pixel(b,p,5,1,2)==255,'Soft colored alpha silhouette')
	b,p=render('drop-shadow(2px 0 blue) drop-shadow(2px 0 lime)')
	assert(pixel(b,p,5,1)==255 and pixel(b,p,5,1,1)==255,'Later shadows include previous shadows')
	b,p=render('drop-shadow(2px 0 blue) invert(1)'); assert(pixel(b,p,3,1,0)==255 and pixel(b,p,3,1,2)==0)
	b,p=render('invert(1) drop-shadow(2px 0 blue)'); assert(pixel(b,p,3,1,0)==0 and pixel(b,p,3,1,2)==255)
	local red,blue=build('drop-shadow(2px 0)','red'),build('drop-shadow(2px 0)','blue')
	assert(red.Style.Filter.HasRaster and not red.Style.Filter.HasBlur and red.BlurGui,'Sharp shadows also use raster output')
	assert(red.Style.Filter.Steps[1].Color.R==1 and blue.Style.Filter.Steps[1].Color.B==1)
	assert(red.Style.Filter.Key~=blue.Style.Filter.Key,'Inherited currentcolor participates in the cache key')
	local alpha=build('drop-shadow(2px 0)','rgba(0,0,0,.5)'); assert(alpha.Style.Filter.Steps[1].Alpha==.5)
	local plan=Raster.plan(red,size)
	assert(Raster.render(source,size,red.Style.Filter,plan,function() return false end)==nil)
	local queue,reads,creates,frees={},0,0,0
	local api={CreateEditableImageAsync=function()
		reads+=1; return {Size=size,ReadPixelsBuffer=function() return source end,Destroy=function() frees+=1 end}
	end,CreateEditableImage=function()
		creates+=1; return {WritePixelsBuffer=function() end,Destroy=function() frees+=1 end}
	end}
	local service=loadBlur({GetService=function() return api end},{defer=function(fn) table.insert(queue,fn) end,wait=function() end})
	local stop=service.start({red,blue},function() return true end,error,function() end)
	while #queue>0 do table.remove(queue,1)() end
	assert(reads==1 and creates==2 and red.BlurReady and blue.BlurReady,'Source shared, differently colored shadows separate')
	stop(); assert(frees==3)
	print('Image drop shadows: alpha silhouette, offsets, subpixels, blur, source-over, ordered chains, currentcolor cache and cleanup passed')
end
