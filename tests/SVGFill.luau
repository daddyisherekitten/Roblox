--!strict
return function(PathMetrics,Dashes,Paint,Geometry,Raster,Length,Parser,Viewport,Viewports,Sources)
	local ctx={Width=100,Height=100,FontSize=16,RootFontSize=16}
	local state=Paint.resolve({['fill-rule']='evenodd'},nil,ctx)
	assert(Paint.resolve({},state,ctx).FillRule=='evenodd')
	assert(Paint.resolve({['fill-rule']='initial'},state,ctx).FillRule=='nonzero')
	local invalid,errors=Paint.resolve({['fill-rule']='bad',['stroke-dasharray']='1,,2'},state,ctx)
	assert(invalid.FillRule=='evenodd' and #errors==2)
	assert(PathMetrics.parse('0')==0 and PathMetrics.parse('1e2')==100)
	for _,value in {'-1','10px','10%','NaN','1e999'} do local n,e=PathMetrics.parse(value);assert(n==nil and e=='invalid-path-length') end
	local g,e=Geometry.build('rect',{width='10',height='10',pathLength='-1'},ctx);assert(g.PathLength==nil and #e==1)
	local parts={{Points={{0,0},{30,0},{30,40}},Closed=true},{Points={{100,0},{110,0}},Closed=false}}
	assert(PathMetrics.measure(parts)==130,'Include closure, exclude moveto gap')
	assert(PathMetrics.calibrate(2,false,100,10)==20)
	assert(PathMetrics.calibrate(2,true,100,10)==2)
	assert(PathMetrics.calibrate(0,false,100,0)==0 and PathMetrics.calibrate(1,false,100,0)==math.huge)
	local line={{Points={{0,0},{80,0}},Closed=false}}
	local function pattern(s) return Paint.dashes(Paint.resolve({['stroke-dasharray']=s},nil,ctx),ctx) end
	local runs=Dashes.split(line,pattern('1 1'),8,nil)
	assert(#runs==4 and runs[1].Points[2][1]==10 and runs[2].Points[1][1]==20)
	runs=Dashes.split(line,pattern('10% 10%'),8,nil);assert(#runs==4 and runs[1].Points[2][1]==10)
	runs=Dashes.split(line,pattern('10'),nil,nil);assert(#runs==4)
	assert(Dashes.split(line,pattern('0 0'),1,nil)==line)
	assert(#Dashes.split(line,pattern('0 1'),0,nil)==0)
	runs=Dashes.split(line,pattern('1 1'),0,nil);assert(#runs==1 and runs[1].Points[2][1]==80)
	runs=Dashes.split(parts,pattern('1000 0'),nil,nil);assert(runs[1].Closed and #runs==2)
	runs=Dashes.split({parts[1]},pattern('30 0'),nil,nil);assert(#runs==1 and runs[1].Closed,'Zero gaps preserve corner joins')
	local two={{Points={{0,0},{15,0}},Closed=false},{Points={{0,10},{15,10}},Closed=false}}
	runs=Dashes.split(two,pattern('10 10'),nil,nil);assert(#runs==2 and runs[2].Points[1][1]==0,'Pattern restarts after moveto')
	assert(Dashes.split(line,pattern('1 1'),nil,function()return false end)==nil)
	assert(not pcall(function() Dashes.split(line,pattern('.00001 .00001'),nil,nil) end),'Tiny dash patterns must hit explicit work budget')
	local function scene(d,rule,stroke)
		return {Width=10,Height=10,Shapes={{Geometry=Geometry.build('path',{d=d},ctx),Transform={SX=1,SY=1,TX=0,TY=0},Fill={30,136,229,1},FillRule=rule,Stroke=stroke,StrokeWidth=2}}}
	end
	local square='M1 1H9V9H1Z'
	local bytes=Raster.render(scene(square..square,'evenodd'),{},10,nil)
	for i=3,buffer.len(bytes)-1,4 do assert(buffer.readu8(bytes,i)==0,'Coincident evenodd contours cancel') end
	bytes=Raster.render(scene(square..'M1 1V9H9V1Z','nonzero'),{},10,nil)
	for i=3,buffer.len(bytes)-1,4 do assert(buffer.readu8(bytes,i)==0,'Opposite coincident winding cancels') end
	local outline=Raster.render(scene(square..square,'evenodd',{67,160,71,1}),{},10,nil)
	assert(buffer.readu8(outline,(5*10+1)*4+3)==255,'Fill rule must not punch holes in the stroke union')
	local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint)
	assert(data.Stage=='S11' and #data.Scenes==3 and #data.Diagnostics==0)
	for _,width in {240,480,960} do
		local scale=width/480
		local function alpha(b,x,y) return buffer.readu8(b,(math.floor(y*scale)*width+math.floor(x*scale))*4+3) end
		local donuts=Raster.render(data.Scenes[1],{},width,nil)
		assert(alpha(donuts,120,80)==255 and alpha(donuts,360,80)==0)
		assert(alpha(donuts,120,240)==0 and alpha(donuts,360,240)==0)
		assert(alpha(donuts,160,80)==255 and alpha(donuts,400,80)==255)
		local winding=Raster.render(data.Scenes[2],{},width,nil)
		assert(alpha(winding,120,85)==255 and alpha(winding,360,85)==0)
		assert(alpha(winding,80,240)==255 and alpha(winding,320,240)==0)
		assert(alpha(winding,360,240)==255 and alpha(winding,290,240)==255)
		local dashed=Raster.render(data.Scenes[3],{},width,nil)
		for x=0,width-1 do
			for _,y in {70,110} do
				local a,b=(math.floor(30*scale)*width+x)*4,(math.floor(y*scale)*width+x)*4
				for c=0,3 do assert(buffer.readu8(dashed,a+c)==buffer.readu8(dashed,b+c),'Calibrated straight dash patterns differ') end
			end
		end
		for y=math.floor(170*scale),math.floor(290*scale) do for x=0,width/2-1 do
			local a,b=(y*width+x)*4,(y*width+x+width/2)*4
			for c=0,3 do assert(math.abs(buffer.readu8(dashed,a+c)-buffer.readu8(dashed,b+c))<=1,`Calibrated circle patterns differ: width {width}, pixel {x},{y}, alpha {buffer.readu8(dashed,a+3)}/{buffer.readu8(dashed,b+3)}, channel {c}: {buffer.readu8(dashed,a+c)} vs {buffer.readu8(dashed,b+c)}`) end
		end end
	end
	print('SVG S11: fill-rule inheritance, winding/parity holes and intersections, coincident contours, stroke independence, pathLength metrics/zero/percentages, dash reset/seams/budgets and three-size visual fixtures passed')
	return data
end
