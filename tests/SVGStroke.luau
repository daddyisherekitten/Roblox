--!strict
return function(Stroke,Dashes,Paint,Geometry,Raster,Length,Parser,Viewport,Viewports,Sources)
	local ctx={Width=100,Height=100,FontSize=16,RootFontSize=16}
	local parent=Paint.resolve({['stroke-linecap']='round',['stroke-linejoin']='bevel',['stroke-miterlimit']='8',['stroke-dashoffset']='-10%'},nil,ctx)
	local state=Paint.resolve({},parent,ctx);assert(state.LineCap=='round' and state.LineJoin=='bevel' and state.MiterLimit==8)
	local offset=Paint.offset(state,ctx);assert(offset.Value==-10 and offset.Percent)
	state=Paint.resolve({['stroke-linecap']='initial'},parent,ctx);assert(state.LineCap=='butt')
	local _,errors=Paint.resolve({['stroke-linecap']='bad',['stroke-linejoin']='bad',['stroke-miterlimit']='.5'},nil,ctx);assert(#errors==3)
	local function bounds(contours)
		local x,y,xx,yy=math.huge,math.huge,-math.huge,-math.huge
		for _,polygon in contours do for _,p in polygon do x=math.min(x,p[1]);y=math.min(y,p[2]);xx=math.max(xx,p[1]);yy=math.max(yy,p[2]) end end
		return x,y,xx,yy
	end
	local function near(a,b) assert(math.abs(a-b)<1e-7,`{a} ~= {b}`) end
	for _,cap in {'butt','round','square'} do
		local x,y,xx,yy=bounds(Stroke.build({{20,20},{80,20}},false,20,{LineCap=cap}))
		near(x,if cap=='butt' then 20 else 10);near(xx,if cap=='butt' then 80 else 90);near(y,10);near(yy,30)
	end
	assert(#Stroke.build({{20,20}},false,20,{LineCap='round'})==0,'Moveto alone is invisible')
	assert(#Stroke.build({{20,20},{20,20}},false,20,{LineCap='butt'})==0)
	near(select(1,bounds(Stroke.build({{20,20},{20,20}},false,20,{LineCap='round'}))),10)
	local sharp={{0,100},{50,0},{100,100}}
	local _,miter=bounds(Stroke.build(sharp,false,20,{LineJoin='miter'}))
	local _,round=bounds(Stroke.build(sharp,false,20,{LineJoin='round'}))
	local _,bevel=bounds(Stroke.build(sharp,false,20,{LineJoin='bevel'}))
	assert(miter<round and round<bevel)
	local _,clipped=bounds(Stroke.build(sharp,false,20,{LineJoin='miter',MiterLimit=1}));near(clipped,bevel)
	local _,_,_,shortBottom=bounds(Stroke.build({{-1,2},{0,0},{1,2}},false,20,{LineJoin='miter',MiterLimit=4}))
	assert(shortBottom<7,'Inner miter must not protrude beyond short segment ends')
	local line={{Points={{0,0},{100,0}},Closed=false}}
	local pattern={{Value=30},{Value=20}}
	local runs=Dashes.split(line,pattern,nil,nil,{Value=10},'butt');near(runs[1].Points[2][1],20)
	runs=Dashes.split(line,pattern,nil,nil,{Value=-10},'butt');near(runs[1].Points[1][1],10)
	runs=Dashes.split(line,{{Value=10}},nil,nil,{Value=25},'butt');near(runs[1].Points[2][1],5)
	runs=Dashes.split(line,{{Value=0},{Value=20}},nil,nil,nil,'round');assert(#runs==6,'Include zero dashes at both endpoints')
	for i,run in runs do near(run.Points[1][1],(i-1)*20);assert(#run.Points==2) end
	local zero={{Points={{20,20},{20,20}},Closed=false}}
	assert(#Dashes.split(zero,{{Value=0},{Value=20}},nil,nil,nil,'round')==1)
	assert(#Dashes.split(zero,pattern,nil,nil,{Value=35},'round')==0,'A zero segment in a gap is invisible')
	runs=Dashes.split({{Points={{0,0},{10,10}},Closed=false}},{{Value=0},{Value=30}},nil,nil,nil,'square')
	local x,y,xx,yy=bounds(Stroke.build(runs[1].Points,false,10,{LineCap='square',Direction=runs[1].Direction}))
	near(xx,5*math.sqrt(2));near(yy,xx);near(x,-xx);near(y,-yy)
	local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint)
	assert(data.Stage=='S12' and #data.Scenes==4 and #data.Diagnostics==0)
	local function pixel(b,w,x,y) local at=(math.floor(y*w/480)*w+math.floor(x*w/480))*4;return {buffer.readu8(b,at),buffer.readu8(b,at+1),buffer.readu8(b,at+2),buffer.readu8(b,at+3)} end
	for _,width in {240,480,960} do
		local caps=Raster.render(data.Scenes[1],{},width,nil)
		assert(pixel(caps,width,94,60)[4]==0)
		assert(pixel(caps,width,94,150)[4]==255)
		assert(pixel(caps,width,90,230)[4]==255)
		local joins=Raster.render(data.Scenes[2],{},width,nil)
		assert(pixel(joins,width,80,213)[4]==0 and pixel(joins,width,240,213)[4]==0 and pixel(joins,width,400,213)[4]==255)
		local dashes=Raster.render(data.Scenes[3],{},width,nil)
		assert(pixel(dashes,width,85,35)[1]==30 and pixel(dashes,width,85,80)[1]~=30 and pixel(dashes,width,85,125)[1]==30)
		local zeros=Raster.render(data.Scenes[4],{},width,nil)
		assert(pixel(zeros,width,80,60)[4]==0 and pixel(zeros,width,240,60)[4]==255 and pixel(zeros,width,400,60)[4]==255)
		assert(pixel(zeros,width,420,225)[4]==255 and pixel(zeros,width,420,285)[4]==255)
	end
	print('SVG S12: inherited caps/joins/miter/offset, exact cap bounds, degenerate segments, miter clipping, signed and odd-pattern offsets, endpoint zero dashes, oriented squares and four three-size raster fixtures passed')
	return data
end
