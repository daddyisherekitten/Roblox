--!strict
return function(Path,Arc,Curves,Paint,Geometry,Raster,Length,Parser,Viewport,Viewports,Sources)
	local function parse(d) local p,e=Path.parse(d);assert(#e==0,d);return p end
	local function near(a,b) assert(math.abs(a-b)<1e-7,`{a} ~= {b}`) end
	local p=parse('M10 20a30 40 25 01100-20 30 40 25 10-100 20')
	assert(#p[1].Points==3);near(p[1].Points[2][1],110);near(p[1].Points[2][2],0)
	local c=p[1].Curves[2];near(c.RX,30);near(c.RY,40);near(c.Rotation,25);assert(c.Large==0 and c.Sweep==1)
	for _,d in {'M0 0A1 2 3 2 0 4 5','M0 0A1 2 3 0 -1 4 5','M0 0A1 2 3 0 1 4','M0 0A1 2 3 0.0 1 4 5'} do
		local parts,errors=Path.parse(d);assert(#errors==1 and #parts[1].Points==1 and next(parts[1].Curves)==nil)
	end
	p=parse('M0 0C1 2 3 4 5 6A10 10 0 0 1 20 20S30 30 40 40')
	near(p[1].Curves[4].Control1[1],20);near(p[1].Curves[4].Control1[2],20)
	local base={Kind='A',RX=45,RY=35,Rotation=0,Large=0,Sweep=0}
	for _,large in {0,1} do for _,sweep in {0,1} do
		local curve=table.clone(base);curve.Large=large;curve.Sweep=sweep
		local arc=Arc.resolve({90,80},{150,80},curve)
		assert((arc.Delta>0)==(sweep==1));assert((math.abs(arc.Delta)>math.pi)==(large==1))
		local a,b=Arc.point(arc,arc.Start),Arc.point(arc,arc.Start+arc.Delta)
		near(a[1],90);near(a[2],80);near(b[1],150);near(b[2],80)
	end end
	local corrected=Arc.resolve({40,80},{200,80},{RX=20,RY=10,Rotation=0,Large=0,Sweep=1})
	near(corrected.RX,80);near(corrected.RY,40);near(corrected.CX,120);near(corrected.CY,80)
	local tiny=Arc.resolve({13,27},{191,88},{RX=.0001,RY=.0002,Rotation=29,Large=0,Sweep=1})
	near(tiny.CX,102);near(tiny.CY,57.5)
	assert(Arc.resolve({1,1},{1,1},base).Mode=='empty')
	assert(Arc.resolve({1,1},{2,2},{RX=0,RY=3}).Mode=='line')
	local negative=Arc.resolve({40,80},{200,80},{RX=-20,RY=-10,Rotation=360,Large=0,Sweep=1})
	near(negative.RX,corrected.RX);near(negative.Start,corrected.Start)
	local function distance(q,a,b)
		local dx,dy=b[1]-a[1],b[2]-a[2];local l=dx*dx+dy*dy
		local t=if l==0 then 0 else math.clamp(((q[1]-a[1])*dx+(q[2]-a[2])*dy)/l,0,1)
		return math.sqrt((q[1]-a[1]-t*dx)^2+(q[2]-a[2]-t*dy)^2)
	end
	p=parse('M10 20A100 30 35 1 0 120 90')
	local arc=Arc.resolve(p[1].Points[1],p[1].Points[2],p[1].Curves[2])
	for _,scale in {.5,1,2,4} do
		local points=Curves.flatten(p,scale,nil)[1].Points
		near(points[#points][1],120);near(points[#points][2],90)
		for i=0,1000 do
			local q=Arc.point(arc,arc.Start+arc.Delta*i/1000);local nearest=math.huge
			for j=2,#points do nearest=math.min(nearest,distance(q,points[j-1],points[j])) end
			assert(nearest*scale<=.125+1e-7)
		end
	end
	local calls=0;assert(Curves.flatten(parse('M0 0A1000 1000 0 0 1 2000 0'),10,function()calls+=1;return calls<2 end)==nil)
	assert(not pcall(function()Curves.flatten(p,1e10,nil)end),'Arc point budget must fail explicitly')
	local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint)
	assert(data.Stage=='S10' and #data.Scenes==3 and #data.Diagnostics==0)
	for _,width in {240,480,960} do
		for _,index in {2,3} do
			local pixels=Raster.render(data.Scenes[index],{},width,nil)
			for y=0,math.round(width/480*320)-1 do for x=0,width/2-1 do
				local a,b=(y*width+x)*4,(y*width+x+width/2)*4
				for channel=0,3 do assert(math.abs(buffer.readu8(pixels,a+channel)-buffer.readu8(pixels,b+channel))<=1,'Arc reference differs') end
			end end
		end
		local pixels=Raster.render(data.Scenes[1],{},width,nil);assert(buffer.len(pixels)==width*math.round(width/480*320)*4)
	end
	print('SVG S10: A/a grammar and compact flags, relative/repeated arcs, sweep/large choices, rotated endpoints, radius correction, degenerates, analytic tolerance, cancellation/budgets and three-size raster equivalence passed')
	return data
end
