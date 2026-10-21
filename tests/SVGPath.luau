--!strict
return function(Path,Paint,Geometry,Raster,Length,Parser,Viewport,Viewports,Sources)
	local function parse(text) local p,d=Path.parse(text);assert(#d==0,text);return p end
	local function point(p,i,x,y) assert(p.Points[i][1]==x and p.Points[i][2]==y) end
	local p=parse('M10 20 30 40l5-10h10 5v-5 10z')
	assert(#p==1 and p[1].Closed);point(p[1],1,10,20);point(p[1],3,35,30);point(p[1],7,50,35)
	p=parse('m10 20 30 40 m5-10 10 20');assert(#p==2);point(p[1],2,40,60);point(p[2],1,45,50);point(p[2],2,55,70)
	p=parse('M.5.6L1e2-2E1 3. 4.');point(p[1],1,.5,.6);point(p[1],2,100,-20);point(p[1],3,3,4)
	p=parse('M10 20L30 40Zl5 6');assert(#p==2 and p[1].Closed and not p[2].Closed);point(p[2],1,10,20);point(p[2],2,15,26)
	p=parse('M10 20L30 40Zm5 6');point(p[2],1,15,26)
	p=parse('M10,20L30,40,50,60zZ');assert(#p[1].Points==3 and p[1].Closed)
	assert(#parse(' \t\r\n')==0)
	assert(#parse('none')==0)
	for _,text in {'L10 20','Z','M','M,1 2','M1,,2','M1 2,','M1 2L3','M1 2L3 4,','M1 2Z3 4','M1e 2','M1 2LNaN 3'} do
		local _,d=Path.parse(text);assert(#d==1,text)
	end
	local d
	p,d=Path.parse('M1 2L3 4 5');assert(#p[1].Points==2 and #d==1)
	p,d=Path.parse('M1 2L3 4R5 6');assert(#p[1].Points==2 and d[1].Code=='unsupported-path-command')
	p,d=Path.parse('M1e9 0l1 0');assert(#p[1].Points==1 and d[1].Code=='path-coordinate-range')
	p,d=Path.parse('M0 0'..string.rep(' 1 1',4096));assert(#p[1].Points==4096 and d[1].Code=='path-point-limit')
	p,d=Path.parse(string.rep(' ',262145));assert(#p==0 and d[1].Code=='path-size-limit')
	local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint)
	assert(data.Stage=='S08' and #data.Scenes==3 and #data.Diagnostics==0)
	local function pixel(bytes,w,x,y) local i=(y*w+x)*4;return {buffer.readu8(bytes,i),buffer.readu8(bytes,i+1),buffer.readu8(bytes,i+2),buffer.readu8(bytes,i+3)} end
	for _,width in {240,480,960} do
		local scale=width/480
		local houses=Raster.render(data.Scenes[1],{},width,nil)
		for y=0,math.floor(320*scale)-1 do for x=0,math.floor(160*scale)-1 do
			local a=pixel(houses,width,x,y)
			for _,offset in {160,320} do local b=pixel(houses,width,x+offset*scale,y);for c=1,4 do assert(math.abs(a[c]-b[c])<=1,'Path and basic shape must match') end end
		end end
		local function at(bytes,x,y) return pixel(bytes,width,math.floor(x*scale),math.floor(y*scale)) end
		local closure=Raster.render(data.Scenes[2],{},width,nil)
		assert(at(closure,100,119)[4]==0);assert(at(closure,340,119)[4]==255)
		local inside=at(closure,100,275);assert(inside[1]==209 and inside[4]==255)
		assert(at(closure,100,281)[4]==0)
		local subpaths=Raster.render(data.Scenes[3],{},width,nil)
		assert(at(subpaths,120,75)[4]==0,'No line between subpaths')
		assert(at(subpaths,50,60)[4]==128);assert(at(subpaths,360,75)[4]==128,'One stroke paint for all subpaths')
		assert(at(subpaths,360,50)[4]==128)
		assert(at(subpaths,300,200)[4]==0,'Moveto adds no segment')
	end
	-- Multiple contours share a nonzero fill operation; overlap does not double alpha.
	local geometry=Geometry.build('path',{d='M1 1H7V7H1Z M3 3H9V9H3Z'}, {})
	local scene={Width=10,Height=10,Shapes={{Geometry=geometry,Transform={SX=1,SY=1,TX=0,TY=0},Fill={30,136,229,.5}}}}
	local pixels=Raster.render(scene,{},10,nil);assert(pixel(pixels,10,4,4)[4]==128)
	assert(Raster.render(data.Scenes[1],{},480,function()return false end)==nil)
	print('SVG S08: absolute/relative/repeated commands, compact numeric syntax, closepath continuation, partial error recovery, budgets, exact house equivalence, independent subpaths and shared-alpha raster passed')
	return data
end
