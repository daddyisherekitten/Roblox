--!strict
return function(Viewport,Parser,Viewports,Sources,Raster)
	local function near(a,b) assert(math.abs(a-b)<1e-8,tostring(a).." ~= "..tostring(b)) end
	local function checkPoint(t,x,y,ex,ey) local xx,yy=Viewport.point(t,x,y);near(xx,ex);near(yy,ey) end
	for ix,X in {"Min","Mid","Max"} do for iy,Y in {"Min","Mid","Max"} do
		local xf,yf=(ix-1)/2,(iy-1)/2
		for _,mode in {"meet","slice"} do
			local a={viewBox="0 0 100 100",preserveAspectRatio="x"..X.."Y"..Y.." "..mode}
			local wide=Viewport.resolve(a,10,20,200,100)
			local tall=Viewport.resolve(a,10,20,100,200)
			assert(#wide.Diagnostics==0 and #tall.Diagnostics==0)
			if mode=="meet" then
				checkPoint(wide.Transform,0,0,10+xf*100,20);checkPoint(wide.Transform,100,100,110+xf*100,120)
				checkPoint(tall.Transform,0,0,10,20+yf*100);checkPoint(tall.Transform,100,100,110,120+yf*100)
			else
				checkPoint(wide.Transform,0,0,10,20-yf*100);checkPoint(wide.Transform,100,100,210,220-yf*100)
				checkPoint(tall.Transform,0,0,10-xf*100,20);checkPoint(tall.Transform,100,100,210-xf*100,220)
			end
		end
	end end
	local none=Viewport.resolve({viewBox="-50 -50 100 100",preserveAspectRatio="none slice"},0,0,200,100)
	checkPoint(none.Transform,0,0,100,50);checkPoint(none.Transform,50,50,200,100)
	local negative=Viewport.resolve({viewBox="-50 -50 100 100"},0,0,200,100)
	checkPoint(negative.Transform,0,0,100,50)
	local missing=Viewport.resolve({preserveAspectRatio="xMaxYMax slice"},12,24,200,100)
	checkPoint(missing.Transform,0,0,12,24);checkPoint(missing.Transform,1,1,13,25)
	for _,value in {"0 0 -1 2","0 0 1","0,,0,1,2","0 0 1 2,","0 0 1e999 2"} do
		local invalid=Viewport.resolve({viewBox=value},0,0,100,100)
		assert(invalid.Diagnostics[1]=="invalid-viewBox" and not invalid.Disabled)
		checkPoint(invalid.Transform,1,1,1,1)
	end
	for _,value in {"","xmidymid","xMinYMax bad","none meet junk","defer xMidYMid"} do
		local invalid=Viewport.resolve({viewBox="0 0 100 100",preserveAspectRatio=value},0,0,200,100)
		assert(invalid.Diagnostics[1]=="invalid-preserveAspectRatio");checkPoint(invalid.Transform,0,0,50,0)
	end
	for _,value in {"0 0 0 100","0 0 100 0"} do assert(Viewport.resolve({viewBox=value},0,0,100,100).Disabled) end
	assert(Viewport.resolve({},0,0,0,100).Disabled)
	assert(Viewport.resolve({},0,0,100,-1).Disabled)
	assert(Viewport.resolve({viewBox="0 0 1e-310 1e-310"},0,0,100,100).Disabled)
	local parent=Viewport.resolve({viewBox="0 0 100 60",preserveAspectRatio="none"},20,180,200,120)
	local nested=Viewport.resolve({viewBox="0 0 100 100",preserveAspectRatio="none"},25,10,50,30,parent.Transform,parent.Clip)
	checkPoint(nested.Transform,0,0,70,200);checkPoint(nested.Transform,100,100,170,260)
	local overflow=Viewport.resolve({},60,20,80,60,parent.Transform,parent.Clip,true)
	assert(overflow.Clip==parent.Clip,'Visible child still inherits ancestor clip')
	local clipped=Viewport.resolve({},60,20,80,60,parent.Transform,parent.Clip)
	near(clipped.Clip.X,140);near(clipped.Clip.Y,220);near(clipped.Clip.Width,80);near(clipped.Clip.Height,80)
	local data=Viewports(Parser,Viewport,Sources,Raster)
	assert(#data.Scenes==4 and #data.Diagnostics==0)
	local function sample(bytes,width,x,y) local at=(y*width+x)*4;return buffer.readu8(bytes,at),buffer.readu8(bytes,at+1),buffer.readu8(bytes,at+2),buffer.readu8(bytes,at+3) end
	for _,width in {240,480,960} do
		local b,h=Raster.render(data.Scenes[1],{},width,nil);assert(h==320*width/480)
		local scale=width/480
		local r,g,bb,a=sample(b,width,math.floor(80*scale),math.floor(80*scale))
		assert(r==84 and g==110 and bb==122 and a==255,'Circle center')
		r,g,bb=sample(b,width,math.floor(185*scale),math.floor(25*scale))
		assert(r==219 and g==229 and bb==237,'meet leaves viewport background visible')
		r,g,bb=sample(b,width,math.floor(310*scale),math.floor(240*scale))
		assert(r==84 and g==110 and bb==122,'none ellipse center')
		local last=Raster.render(data.Scenes[4],{},width,nil)
		local _,_,_,outside=sample(last,width,math.floor(470*scale),math.floor(240*scale))
		assert(outside==0,'Nested overflow cannot escape parent clip')
		for yy=22,137,5 do for xx=22,217,5 do
			local x,y=math.floor(xx*scale),math.floor(yy*scale)
			local left=(y*width+x)*4;local right=(y*width+x+240*scale)*4
			for c=0,3 do assert(buffer.readu8(last,left+c)==buffer.readu8(last,right+c),'Negative origin must render identically') end
		end end
	end
	local ellipse={Width=480,Height=320,Shapes={{Kind="ellipse",x=10,y=10,width=20,height=20,Color={255,0,0}}}}
	local b=Raster.render(ellipse,{},480,nil)
	local partial=0
	for y=10,29 do for x=10,29 do
		local r,_,_,a=sample(b,480,x,y)
		if a>0 and a<255 then
			partial+=1;assert(r==255,'Straight alpha has no dark fringe')
			local reference=0
			for yy=0,127 do for xx=0,127 do
				if ((x+(xx+.5)/128-20)/10)^2+((y+(yy+.5)/128-20)/10)^2<=1 then reference+=1 end
			end end
			assert(math.abs(a-reference/16384*255)<=8,'Circle boundary alpha tolerance: 8/255 against dense area samples')
		end
	end end
	assert(partial>0)
	local calls=0;local cancelled=Raster.render(data.Scenes[1],{},480,function() calls+=1;return calls<3 end)
	assert(cancelled==nil,'Raster yields to cooperative cancellation')
	print('SVG S04: all alignments/modes, origin, nested transforms/clips, invalid/zero cases, three raster sizes and cancellation passed')
	return data
end
