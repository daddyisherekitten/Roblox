--!strict
return function(Matrix,Transform,TransformBounds,Paint,Geometry,Raster,Length,Parser,Viewport,Viewports,Sources)
	local ctx={X=0,Y=0,Width=480,Height=320,FontSize=16,RootFontSize=16}
	local function near(a,b) assert(math.abs(a-b)<1e-7,`{a} ~= {b}`) end
	local function point(text,x,y,xx,yy,css)
		local t,err=Transform.parse(text,ctx,nil,css);assert(not err,err)
		local a,b=Matrix.point(t,x,y);near(a,xx);near(b,yy);return t
	end
	point('translate(10,20) scale(2 3)',5,6,20,38)
	point('scale(2 3) translate(10 20)',5,6,30,78)
	point('rotate(90 10 20)',11,20,10,21)
	point('matrix(1 2 3 4 5 6)',7,8,36,52)
	point('translate(-1e1 .5) scale(-2)',3,4,-16,-7.5)
	point('skewX(45)',0,10,10,10);point('skewY(45)',10,0,10,10)
	point('translateX(10px) translateY(20px) rotate(.25turn)',1,0,10,21,true)
	point('translate(50%,25%)',0,0,240,80,true)
	point('scaleX(2) scaleY(3)',2,3,4,9,true)
	point('TRANSLATEX(10px) ROTATE(90deg)',1,0,10,1,true)
	for _,text in {'translate(1,,2)','translate(1,)','translate(1-2)','rotate(1 2)','matrix(1 2)','scale(1px)','junk','rotate(0)junk','scale(1),','translate(1e999)'} do
		local _,err=Transform.parse(text,ctx);assert(err,text)
	end
	local _,err=Transform.parse('translate(10)',ctx,nil,true);assert(err)
	local _,limit=Transform.parse(string.rep('scale(1) ',129),ctx);assert(limit=='transform-limit')
	near(Matrix.scale(point('rotate(35) scale(-2 3)',0,0,0,0)),3)
	local box={X=20,Y=30,Width=100,Height=50}
	local x,y=Transform.origin('right bottom',box,ctx);near(x,120);near(y,80)
	x,y=Transform.origin('top left',box,ctx);near(x,20);near(y,30)
	x,y=Transform.origin('center',box,ctx);near(x,70);near(y,55)
	local declarations=Transform.declarations({transform='scale(9)',style='transform: scale(2) !important; transform: scale(3);transform-origin:center;transform-box:fill-box'})
	assert(declarations.Transform=='scale(2)' and declarations.CSS and declarations.Box=='fill-box')
	local t=Transform.resolve(declarations,box,ctx);x,y=Matrix.point(t,70,55);near(x,70);near(y,55)
	local function observe(svg)
		return Viewports(Parser,Viewport,{Stage='S13',Cases={{Name='probe',SVG='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 320">'..svg..'</svg>'}}},Raster,Length,Geometry,Paint,Transform,TransformBounds)
	end
	local group=observe('<g style="transform:rotate(90deg);transform-box:fill-box;transform-origin:center"><rect width="20" height="20"/><rect x="80" width="20" height="20"/></g>')
	x,y=Matrix.point(group.Scenes[1].Shapes[1].Transform,50,10);near(x,50);near(y,10)
	local negative=observe('<svg width="100" height="100" viewBox="-10 -10 100 100"><rect width="10" height="10" transform="rotate(90)"/></svg>')
	x,y=Matrix.point(negative.Scenes[1].Shapes[1].Transform,0,0);near(x,10);near(y,10)
	local em=observe('<rect width="2em" height="1em" font-size="200%" style="transform:rotate(90deg);transform-box:fill-box;transform-origin:center"/>')
	x,y=Matrix.point(em.Scenes[1].Shapes[1].Transform,32,16);near(x,32);near(y,16)
	local singular=observe('<g transform="scale(0)"><rect width="100" height="100"/></g>')
	local b=Raster.render(singular.Scenes[1],{},480,nil);assert(buffer.tostring(b)==string.rep('\0',buffer.len(b)))
	local invalid=observe('<rect width="100" height="100" transform="bad(1)"/>');assert(#invalid.Diagnostics==1)
	local root=Viewports(Parser,Viewport,{Cases={{Name='root',SVG='<svg xmlns="http://www.w3.org/2000/svg" width="480" height="320" transform="rotate(180)"><rect x="20" y="20" width="40" height="30"/></svg>'}}},Raster,Length,Geometry,Paint,Transform,TransformBounds)
	x,y=Matrix.point(root.Scenes[1].Shapes[1].Transform,20,20);near(x,460);near(y,300)
	local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,TransformBounds)
	assert(#data.Scenes==4 and #data.Diagnostics==0,'Four diagnostic-free transform scenes')
	local function pixel(bytes,w,xp,yp)
		local at=(math.floor(yp*w/480)*w+math.floor(xp*w/480))*4
		return buffer.readu8(bytes,at),buffer.readu8(bytes,at+1),buffer.readu8(bytes,at+2),buffer.readu8(bytes,at+3)
	end
	for _,width in {240,480,960} do
		for _,scene in data.Scenes do assert(Raster.render(scene,{},width,nil)) end
		local origins=Raster.render(data.Scenes[3],{},width,nil)
		for yy=0,319 do for xx=0,239 do
			local r,g,bb,a=pixel(origins,width,xx,yy);local rr,gg,bbb,aa=pixel(origins,width,xx+240,yy)
			assert(math.abs(r-rr)<=1 and math.abs(g-gg)<=1 and math.abs(bb-bbb)<=1 and math.abs(a-aa)<=1,'Equivalent origin pairs')
		end end
		local clipped=Raster.render(data.Scenes[2],{},width,nil)
		local _,_,_,outside=pixel(clipped,width,60,210);assert(outside==0,'Rotated clip must exclude bounding-box corners')
		local thickness=observe('<path d="M20 50H100" transform="scale(2)" fill="none" stroke="blue" stroke-width="8" vector-effect="non-scaling-stroke"/>')
		local pixels=Raster.render(thickness.Scenes[1],{},width,nil);local sum=0
		for py=0,math.round(320*width/480)-1 do sum+=buffer.readu8(pixels,(py*width+math.floor(80*width/480))*4+3)/255 end
		near(sum,8)
	end
	assert(Raster.render(data.Scenes[1],{},480,function() return false end)==nil)
	print('SVG S13: affine order/pivots/skews/reflection, invalid lists/budgets, CSS units/origins, group bounds, singular transforms, rotated viewport clips, constant physical stroke width and four three-size fixtures passed')
	return data
end
