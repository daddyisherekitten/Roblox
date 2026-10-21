--!strict
return function(Filter,Raster,loadBlur,Parser,loadRenderTree,loadWordLayout,ImageBox)
	assert(Filter.parse('blur()').Steps[1].Value==0 and not Filter.parse('blur(0)').HasBlur)
	assert(Filter.parse('blur(2.5px)').Outset==8)
	for _,bad in {'blur(1)','blur(-1px)','blur(1%)','blur(101px)','blur(2em)'} do assert(Filter.parse(bad)==nil,bad) end
	local renderer=loadRenderTree({create=function(_,_,props) return table.clone(props) end,modifier=function(_,_,props) return table.clone(props) end})
	local words=loadWordLayout({['Layout/FontProfiles']={face=function(font) return font end},['Layout/TextMeasure']={measure=function(_,_,size) return {X=10,Y=size} end}})
	local function build(css,width,height)
		local tree=renderer.build(Parser.parse('<p><img src="x" width="'..(width or 3)..'" height="'..(height or 3)..'" style="filter:'..css..'"></p>'),{},error,nil,nil,nil,function() return 'rbxassetid://1' end)
		words.arrange(tree.Children[1].Children[1],300,0,0,function() return true end)
		return tree.ImageItems[1]
	end
	local source=buffer.create(36)
	for i=0,8 do buffer.writeu8(source,i*4+2,255) end -- hidden blue must never pollute the red dot
	buffer.writeu8(source,16,255); buffer.writeu8(source,18,0); buffer.writeu8(source,19,255)
	local size={X=3,Y=3}
	local function render(css)
		local item=build(css); local plan=Raster.plan(item,size)
		return Raster.render(source,size,item.Style.Filter,plan,function() return true end),plan
	end
	local identity=render('blur(0px)')
	assert(buffer.readu8(identity,16)==255 and buffer.readu8(identity,19)==255)
	local bytes,p=render('blur(1px)')
	assert(p.Width==9 and p.Height==9)
	local sum=0
	for y=0,8 do for x=0,8 do
		local at=(y*9+x)*4; local alpha=buffer.readu8(bytes,at+3); sum+=alpha
		assert(alpha==buffer.readu8(bytes,(y*9+8-x)*4+3),'Blur symmetry')
		if alpha>0 then assert(buffer.readu8(bytes,at)==255 and buffer.readu8(bytes,at+2)==0,'Premultiplied blur preserves red at transparent edges') end
	end end
	assert(math.abs(sum-255)<10 and buffer.readu8(bytes,(4*9+4)*4+3)<255)
	local sub=render('blur(.5px)'); assert(buffer.readu8(sub,(3*7+3)*4+3)<255,'Subpixel blur must not disappear')
	local huge=build('blur(100px)',1000,500); local bounded=Raster.plan(huge,size)
	assert(bounded.Width<=512 and bounded.Height<=512 and bounded.ScaleX<1)
	assert(Raster.render(source,size,huge.Style.Filter,bounded,function() return false end)==nil)
	local fitted=build('blur(1px)',12,6); fitted.Style.ObjectFit='contain'
	local fit=Raster.plan(fitted,size); assert(fit.FitWidth==6 and fit.X==3)
	local a=build('contrast(4) blur(1px)'); local b=build('blur(1px) contrast(4)')
	local opaque=buffer.create(36)
	for i=0,8 do for c=0,2 do buffer.writeu8(opaque,i*4+c,if i==4 then 255 else 80) end; buffer.writeu8(opaque,i*4+3,255) end
	local first=Raster.render(opaque,size,a.Style.Filter,Raster.plan(a,size),nil)
	local second=Raster.render(opaque,size,b.Style.Filter,Raster.plan(b,size),nil)
	assert(buffer.tostring(first)~=buffer.tostring(second),'Blur obeys filter order')
	local queue,reads,creates,frees,diagnostics={},0,0,0,{}
	local mode='ok'
	local sourceHook
	local api={CreateEditableImageAsync=function()
		reads+=1; if sourceHook then sourceHook() end
		if mode=='denied' then error('denied') end
		return {Size=size,ReadPixelsBuffer=function() return source end,Destroy=function() frees+=1 end}
	end,CreateEditableImage=function()
		creates+=1; if mode=='budget' then return nil end
		return {WritePixelsBuffer=function(self,_,_,pixels) self.Pixels=pixels end,Destroy=function() frees+=1 end}
	end}
	local service=loadBlur({GetService=function() return api end},{defer=function(fn) table.insert(queue,fn) end,wait=function() end})
	local function drain() while #queue>0 do table.remove(queue,1)() end end
	local function start(items) return service.start(items,function() return true end,function(m) table.insert(diagnostics,m) end,function() end) end
	a,b=build('blur(1px)'),build('blur(1px)')
	local items={a,b}; local stop=start(items); table.clear(items)
	assert(reads==0); drain()
	assert(reads==1 and creates==1 and a.BlurReady and b.BlurReady and not a.ImageGui.Visible)
	assert(a.BlurGui.ImageContent==b.BlurGui.ImageContent and a.BlurGui.Size[1]==9)
	a.UpdateBlur(); b.UpdateBlur(); drain(); assert(creates==1,'Stable layout reuses the cache')
	a.ContentWidth=6; ImageBox.arrange(a); drain(); assert(creates==2 and a.BlurGui.Size[1]==12)
	a.ContentWidth=3; ImageBox.arrange(a); drain(); assert(creates==2,'Returning to a cached size reuses output')
	for i=4,23 do a.ContentWidth=i; ImageBox.arrange(a); drain() end
	assert(a.BlurReady and #diagnostics==0,'Unused resize variants are evicted instead of exhausting the cache')
	stop(); stop(); assert(frees==creates+1 and a.UpdateBlur==nil,'Free every output/source exactly once')
	local before=reads; stop=start({build('blur(1px)')}); stop(); drain(); assert(reads==before)
	stop=start({build('blur(1px)')}); sourceHook=stop; drain(); sourceHook=nil
	for _,failure in {'denied','budget'} do
		mode=failure; a=build('blur(1px)'); stop=start({a}); drain()
		assert(not a.BlurReady and a.ImageGui.Visible and not a.BlurGui.Visible,'Failure keeps original visible')
		local old=creates; a.UpdateBlur(); drain(); assert(creates==old,'Failed variant is not retried on every layout'); stop()
	end
	print('Image blur: CSS units, alpha-safe Gaussian approximation, subpixels, fit/scaling, filter order, resize cache, eviction, cancellation and fallback passed')
end
