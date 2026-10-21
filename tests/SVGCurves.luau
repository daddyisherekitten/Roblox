--!strict
return function(Path,Curves,Paint,Geometry,Raster,Length,Parser,Viewport,Viewports,Sources)
	local function parse(d) local p,e=Path.parse(d);assert(#e==0,d);return p end
	local function same(p,x,y) assert(p[1]==x and p[2]==y) end
	local p=parse('M10 20c10-10 20-10 30 0s20 10 30 0')
	same(p[1].Curves[2].Control1,20,10);same(p[1].Curves[3].Control1,50,30);same(p[1].Points[3],70,20)
	p=parse('M10 20q10-10 20 0t20 0 20 0')
	same(p[1].Curves[3].Control1,40,30);same(p[1].Curves[4].Control1,60,10)
	p=parse('M0 0C10 10 20 10 30 0L40 0S50 20 60 0Q70 20 80 0H90T100 0')
	same(p[1].Curves[4].Control1,40,0);same(p[1].Curves[7].Control1,90,0)
	p=parse('M0 0Q10 10 20 0S30 10 40 0T50 0')
	same(p[1].Curves[3].Control1,20,0);same(p[1].Curves[4].Control1,40,0)
	p=parse('M0 0C10 10 20 10 30 0ZS10 10 20 0');same(p[2].Curves[2].Control1,0,0)
	p=parse('M0 0C10 10 20 10 30 0M40 0S50 10 60 0');same(p[2].Curves[2].Control1,40,0)
	p=parse('M0 0C10 10 20 10 30 0 40-10 50-10 60 0');assert(#p[1].Points==3)
	for _,d in {'M0 0C1 2 3 4 5','M0 0S1 2 3','M0 0Q1 2 3','M0 0T1'} do
		local parts,errors=Path.parse(d);assert(#parts[1].Points==1 and #errors==1 and next(parts[1].Curves)==nil)
	end
	local _,errors=Path.parse('M1e9 0c1 0 0 0 0 0');assert(errors[1].Code=='path-coordinate-range')
	local function distance(q,a,b)
		local dx,dy=b[1]-a[1],b[2]-a[2];local l=dx*dx+dy*dy
		local t=if l==0 then 0 else math.clamp(((q[1]-a[1])*dx+(q[2]-a[2])*dy)/l,0,1)
		return math.sqrt((q[1]-a[1]-t*dx)^2+(q[2]-a[2]-t*dy)^2)
	end
	local samples={
		{{0,0},{0,100},{100,100},{100,0}},
		{{0,0},{100,100},{-100,100},{0,0}},
		{{0,0},{300,0},{-300,0},{20,0}},
	}
	for _,controls in samples do
		local a,b,c,d=unpack(controls)
		local parts={{Points={a,d},Curves={[2]={Kind='C',Control1=b,Control2=c}},Closed=false}}
		local before=0
		for _,scale in {.5,1,2,4} do
			local points=Curves.flatten(parts,scale,nil)[1].Points
			assert(#points>=before);before=#points
			for i=0,1000 do
				local t=i/1000;local u=1-t
				local q={u^3*a[1]+3*u*u*t*b[1]+3*u*t*t*c[1]+t^3*d[1],u^3*a[2]+3*u*u*t*b[2]+3*u*t*t*c[2]+t^3*d[2]}
				local nearest=math.huge;for j=2,#points do nearest=math.min(nearest,distance(q,points[j-1],points[j])) end
				assert(nearest*scale<=.125+1e-7,'Curve exceeds output tolerance')
			end
		end
		assert(#parts[1].Points==2,'Flatten must not mutate parsed geometry')
	end
	local quad=Curves.flatten(parse('M0 0Q50 100 100 0'),1,nil)[1].Points
	local midpoint=false;for _,point in quad do if math.abs(point[1]-50)<1e-8 and math.abs(point[2]-50)<1e-8 then midpoint=true end end;assert(midpoint)
	assert(#Curves.flatten(parse('M0 0C0 0 0 0 0 0'),1,nil)[1].Points==2)
	local calls=0;assert(Curves.flatten(parse('M0 0C0 1000 1000 1000 1000 0'),10,function()calls+=1;return calls<2 end)==nil)
	assert(not pcall(function()Curves.flatten(parse('M0 0C0 1e9 1e9 1e9 1e9 0'),1e10,nil)end),'Subdivision budget must fail explicitly')
	local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint)
	assert(data.Stage=='S09' and #data.Scenes==3 and #data.Diagnostics==0)
	for _,width in {240,480,960} do
		local pixels=Raster.render(data.Scenes[2],{},width,nil)
		for y=0,math.round(width/480*320)-1 do for x=0,width/2-1 do
			local a,b=(y*width+x)*4,(y*width+x+width/2)*4
			for c=0,3 do assert(math.abs(buffer.readu8(pixels,a+c)-buffer.readu8(pixels,b+c))<=1,'Explicit and reflected controls differ') end
		end end
		for _,index in {1,3} do local bytes=Raster.render(data.Scenes[index],{},width,nil);assert(buffer.len(bytes)==width*math.round(width/480*320)*4) end
	end
	print('SVG S09: C/S/Q/T, relative/repeated parameters, reflection resets, partial errors, analytic curve tolerance, loops/reversals, cancellation/budgets and raster equivalence at three sizes passed')
	return data
end
