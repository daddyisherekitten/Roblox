--!strict
return function(Geometry,Raster,Length,Parser,Viewport,Viewports,Sources)
	local context={Width=400,Height=100,FontSize=16,RootFontSize=16}
	local function build(name,a) return Geometry.build(name,a,context) end
	local function near(a,b) assert(math.abs(a-b)<1e-8,tostring(a)..' ~= '..tostring(b)) end
	local g=build('rect',{width='100',height='40',rx='30'})
	near(g.RX,30);near(g.RY,20)
	g=build('rect',{width='100',height='40',ry='10'});near(g.RX,10);near(g.RY,10)
	g=build('rect',{width='100',height='40',rx='20%',ry='25%'});near(g.RX,20);near(g.RY,10)
	g=build('rect',{width='100',height='40',rx='30',ry='0'});assert(#Geometry.contour(g,1)==4)
	assert(build('rect',{width='0',height='40'}).Empty)
	local bad,diagnostics=build('rect',{width='-1',height='40'});assert(bad.Empty and diagnostics[1].Code=='negative-length')
	bad,diagnostics=build('circle',{r='1e20'});assert(bad.Empty and diagnostics[1].Code=='geometry-range')
	g=build('circle',{r='10%',cx='50%',cy='50%'});near(g.RX,Length.diagonal(400,100)*.1);near(g.CX,200);near(g.CY,50)
	g=build('ellipse',{rx='10'});near(g.RY,10)
	g=build('ellipse',{ry='20'});near(g.RX,20)
	g=build('polyline',{points='1e1,20 30,40 50'});assert(#g.Points==2 and not g.Closed);near(g.Points[1][1],10)
	bad,diagnostics=build('polygon',{points='0,0 10,0 10,10 oops'});assert(#bad.Points==3 and diagnostics[1].Code=='invalid-points')
	bad,diagnostics=build('polygon',{points='0,0 10px,20'});assert(#bad.Points==1 and #diagnostics==1)
	bad,diagnostics=build('polygon',{points=string.rep('0 0 ',4097)});assert(bad==nil and diagnostics[1].Code=='point-limit')
	assert(#Geometry.stroke({{1,1},{1,1}},false,8)==0)
	assert(#Geometry.stroke({{1,1},{1,1},{4,1}},false,8)==1)
	g=build('circle',{r='40'});assert(#Geometry.contour(g,2)>#Geometry.contour(g,.5))
	for _,scale in {.5,1,2,10} do local n=#Geometry.contour(g,scale);assert(40*scale*(1-math.cos(math.pi/n))<=.125) end
	local function rgba(b,w,x,y) local i=(y*w+x)*4;return buffer.readu8(b,i),buffer.readu8(b,i+1),buffer.readu8(b,i+2),buffer.readu8(b,i+3) end
	local function color(b,w,x,y,r,g,blue) local rr,gg,bb,aa=rgba(b,w,x,y);assert(rr==r and gg==g and bb==blue and aa==255,`Pixel {x},{y}: {rr},{gg},{bb},{aa}`) end
	local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry)
	assert(data.Stage=='S06' and #data.Scenes==3 and #data.Diagnostics==0)
	for _,width in {240,480,960} do
		local scale=width/480
		local function at(b,x,y,r,g,blue) color(b,width,math.floor(x*scale),math.floor(y*scale),r,g,blue) end
		local shapes=Raster.render(data.Scenes[1],{},width,nil)
		at(shapes,60,60,30,136,229);at(shapes,230,60,67,160,71);at(shapes,390,60,142,36,170)
		at(shapes,80,230,30,136,229)
		local rounding=Raster.render(data.Scenes[2],{},width,nil)
		at(rounding,31,36,238,242,247);at(rounding,120,70,30,136,229)
		at(rounding,31,196,238,242,247);at(rounding,120,230,142,36,170)
		at(rounding,272,197,229,57,53)
		local closure=Raster.render(data.Scenes[3],{},width,nil)
		at(closure,100,109,238,242,247);at(closure,340,109,67,160,71)
		at(closure,100,269,209,179,224);at(closure,100,271,238,242,247)
		at(closure,300,210,238,242,247)
	end
	-- Fractional clipping and source-over retain straight RGB at transparent edges.
	local scene={Width=10,Height=10,Shapes={{Geometry=build('rect',{x='1.25',y='1.5',width='4',height='4'}),Transform={SX=1,SY=1,TX=0,TY=0},Fill={30,136,229}}}}
	local pixels=Raster.render(scene,{},10,nil)
	local r,green,b,a=rgba(pixels,10,1,1);assert(r==30 and green==136 and b==229 and a==96)
	scene.Shapes[1].Clip={X=2.5,Y=2.5,Width=2,Height=2}
	pixels=Raster.render(scene,{},10,nil)
	assert(select(4,rgba(pixels,10,2,2))==64);assert(select(4,rgba(pixels,10,1,1))==0)
	local calls=0
	assert(Raster.render(data.Scenes[1],{},480,function() calls+=1;return calls<3 end)==nil)
	print('SVG S06: six shapes, radius copying/clamping, curve accuracy, point diagnostics/budgets, open/closed contours, fractional coverage, clipping, cancellation and three raster sizes passed')
	return data
end
