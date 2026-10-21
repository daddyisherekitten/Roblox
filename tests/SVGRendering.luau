--!strict
return function(Rendering,Compositing,Transform,TransformBounds,Paint,Geometry,Raster,Length,Parser,Viewport,Viewports,Sources)
	local state,errors=Rendering.resolve({opacity='50%',['paint-order']='stroke',visibility='hidden',['shape-rendering']='crispEdges'})
	assert(#errors==0 and state.Opacity==.5 and state.PaintOrder[1]=='stroke' and state.PaintOrder[2]=='fill')
	local child=Rendering.resolve({},state);assert(child.Opacity==1 and child.Visibility=='hidden' and child.ShapeRendering=='crispEdges')
	child=Rendering.resolve({opacity='inherit',visibility='initial',['paint-order']='unset'},state)
	assert(child.Opacity==.5 and child.Visibility=='visible' and child.PaintOrder[1]=='stroke')
	assert(Rendering.resolve({},nil,true).Overflow=='hidden')
	assert(Rendering.resolve({overflow='initial'},nil,true).Overflow=='visible')
	assert(Rendering.resolve({style='shape-rendering: CRISPEDGES'}).ShapeRendering=='crispEdges')
	state,errors=Rendering.resolve({opacity='bad',['paint-order']='fill fill',visibility='bad'})
	assert(#errors==3 and state.Opacity==1 and state.Visibility=='visible')
	assert(Rendering.resolve({opacity='2'}).Opacity==1 and Rendering.resolve({opacity='-2'}).Opacity==0)
	state=Rendering.resolve({opacity='.9',style='opacity:.25!important; opacity:.8;paint-order:stroke;paint-order:bad'})
	assert(state.Opacity==.25 and state.PaintOrder[1]=='stroke','Important and invalid-declaration fallback')
	local function observe(svg)
		return Viewports(Parser,Viewport,{Stage='S14',Cases={{Name='probe',SVG='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 320">'..svg..'</svg>'}}},Raster,Length,Geometry,Paint,Transform,TransformBounds,Rendering)
	end
	local function pixel(bytes,w,x,y)
		local at=(math.floor(y*w/480)*w+math.floor(x*w/480))*4
		return {buffer.readu8(bytes,at),buffer.readu8(bytes,at+1),buffer.readu8(bytes,at+2),buffer.readu8(bytes,at+3)}
	end
	local function expect(actual,expected)
		for i,n in expected do assert(math.abs(actual[i]-n)<=1,`channel {i}: {actual[i]} ~= {n}`) end
	end
	local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,TransformBounds,Rendering)
	assert(#data.Scenes==4 and #data.Diagnostics==0)
	for _,w in {240,480,960} do
		local opacity=Raster.render(data.Scenes[1],{},w,nil)
		expect(pixel(opacity,w,100,80),{85,0,170,192})
		expect(pixel(opacity,w,340,80),{0,0,255,128})
		expect(pixel(opacity,w,100,240),{0,0,255,64})
		expect(pixel(opacity,w,390,245),{255,0,0,128})
		local order=Raster.render(data.Scenes[2],{},w,nil)
		expect(pixel(order,w,145,80),{94,53,177,255})
		expect(pixel(order,w,385,80),{255,202,40,255})
		local visible=Raster.render(data.Scenes[3],{},w,nil)
		assert(pixel(visible,w,145,60)[4]==0 and pixel(visible,w,295,60)[4]==0)
		expect(pixel(visible,w,385,60),{67,160,71,255})
		assert(pixel(visible,w,110,180)[4]==0 and pixel(visible,w,350,180)[4]==255)
		local hints=Raster.render(data.Scenes[4],{},w,nil)
		local partial=0
		for y=0,math.floor(150*w/480)-1 do for x=0,math.floor(230*w/480)-1 do
			local a=buffer.readu8(hints,(y*w+x)*4+3);if a>0 and a<255 then partial+=1 end
			local aa=buffer.readu8(hints,(y*w+x+math.floor(240*w/480))*4+3)
			assert(aa==0 or aa==255,'crispEdges has binary coverage')
		end end
		assert(partial>0,'auto retains antialiasing')
	end
	local hidden=observe('<g visibility="hidden"><rect width="20" height="20"/><g visibility="visible"><rect x="40" width="20" height="20"/></g></g>')
	assert(hidden.Scenes[1].Shapes[1].Hidden and not hidden.Scenes[1].Shapes[2].Hidden)
	assert(observe('<rect width="20" height="20" visibility="collapse"/>').Scenes[1].Shapes[1].Hidden)
	local removed=observe('<g display="none"><rect display="inline" width="20" height="20"/></g><rect width="20" height="20"/>')
	assert(#removed.Scenes[1].Shapes==1)
	local bounds=Parser.parse('<svg xmlns="http://www.w3.org/2000/svg"><g><rect width="20" height="20"/><rect x="80" width="20" height="20" style="display:none"/></g></svg>')
	local box=TransformBounds.reference(bounds.Root.Children[1],{Width=480,Height=320,FontSize=16,RootFontSize=16});assert(box.Width==20)
	local bytes=buffer.create(4);local called=0
	assert(Compositing.draw(bytes,{{Opacity=0}},function() called+=1;return true end,1));assert(called==0)
	assert(not Compositing.over(bytes,buffer.create(4),.5,1,function() return false end))
	local active=true
	assert(not Compositing.draw(bytes,{{Children={{}},Opacity=.5}},function() active=false;return true end,1,function() return active end),'Cancel between child drawing and group composite')
	local chain={Opacity=.5};local root=chain
	for _=1,33 do local c={Opacity=.5};chain.Children={c};chain=c end
	local ok,message=pcall(function() Compositing.draw(buffer.create(1024*1024),{root},function() return true end,512) end)
	assert(not ok and tostring(message):find('opacity buffer budget'),'Bound nested temporary memory')
	local cancel=observe('<g opacity=".5"><rect width="200" height="200"/></g>')
	assert(Raster.render(cancel.Scenes[1],{},480,function() return false end)==nil)
	print('SVG S14: inherited rendering state, isolated element/nested group alpha, paint order, visibility overrides, removed subtrees/bounds, overflow, binary/AA hints, cancellation and opacity memory budget passed')
	return data
end
