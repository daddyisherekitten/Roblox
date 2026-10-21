--!strict
return function(Paint,Geometry,Raster,Length,Parser,Viewport,Viewports,Sources)
	local context={Width=480,Height=320,FontSize=20,RootFontSize=16}
	local function near(a,b) assert(math.abs(a-b)<1e-7,`{a} ~= {b}`) end
	local function used(a,parent,ctx) return Paint.used(Paint.resolve(a,parent,ctx or context),ctx or context) end
	local f,s,w=used({});near(f[1],0);near(f[4],1);assert(s==nil);near(w,1)
	local parent=Paint.resolve({color='blue',fill='currentColor',stroke='currentColor',['stroke-width']='2em'},nil,context)
	local child=Paint.resolve({color='red'},parent,context)
	f,s,w=Paint.used(child,context);near(f[1],255);near(f[3],0);near(s[1],255);near(w,40)
	f=Paint.used(parent,context);near(f[3],255)
	f=used({color='red'});near(f[1],0)
	f=used({fill='initial'},parent);near(f[3],0)
	f=used({fill='none'},parent);assert(f==nil)
	f=used({fill='unset'},parent);near(f[3],255)
	for _,value in {'#1e88e5','#1E88E5','rgb(30,136,229)','rgb(11.7647058824%,53.3333333333%,89.8039215686%)'} do
		f=used({fill=value});near(f[1],30);near(f[2],136);near(f[3],229)
	end
	f=used({fill='hsl(120,100%,50%)'});near(f[2],255)
	f=used({fill='#1234'});near(f[1],17);near(f[4],68/255)
	f=used({fill='rgba(30,136,229,.5)',['fill-opacity']='50%'});near(f[4],.25)
	f=used({fill='transparent'});near(f[4],0)
	f=used({['fill-opacity']='-2'});near(f[4],0)
	f=used({['fill-opacity']='200%'});near(f[4],1)
	local state,errors=Paint.resolve({fill='oops',['fill-opacity']='1x',['stroke-width']='-2'},parent,context)
	assert(#errors==3);f,s,w=Paint.used(state,context);near(f[3],255);near(w,40)
	local percent=Paint.resolve({['stroke-width']='10%'},nil,context)
	local nested={Width=100,Height=100,FontSize=40,RootFontSize=16}
	f,s,w=Paint.used(percent,nested);near(w,10)
	f,s,w=used({},parent,nested);near(w,40)
	-- Inherited opacities replace, rather than multiply, when a child overrides them.
	parent=Paint.resolve({['fill-opacity']='.5'},nil,context)
	f=used({},parent);near(f[4],.5)
	f=used({['fill-opacity']='.5'},parent);near(f[4],.5)
	f=used({['fill-opacity']='1'},parent);near(f[4],1)
	local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint)
	assert(data.Stage=='S07' and #data.Scenes==3 and #data.Diagnostics==0)
	local function pixel(bytes,width,x,y) local i=(y*width+x)*4;return {buffer.readu8(bytes,i),buffer.readu8(bytes,i+1),buffer.readu8(bytes,i+2),buffer.readu8(bytes,i+3)} end
	local function expect(bytes,width,x,y,expected)
		local p=pixel(bytes,width,math.floor(x*width/480),math.floor(y*width/480))
		for i=1,4 do assert(math.abs(p[i]-expected[i])<=1,`Pixel {x},{y} channel {i}: {p[i]} ~= {expected[i]}`) end
	end
	for _,width in {240,480,960} do
		local matrix=Raster.render(data.Scenes[1],{},width,nil)
		expect(matrix,width,80,70,{0,0,0,255});expect(matrix,width,240,70,{30,136,229,255})
		expect(matrix,width,400,70,{0,0,0,0});expect(matrix,width,240,230,{0,0,0,0})
		expect(matrix,width,400,230,{0,0,0,0});expect(matrix,width,400,190,{229,57,53,255})
		local inherited=Raster.render(data.Scenes[2],{},width,nil)
		expect(inherited,width,80,70,{30,136,229,255});expect(inherited,width,240,70,{67,160,71,255})
		expect(inherited,width,400,70,{0,0,0,0});expect(inherited,width,400,30,{142,36,170,255})
		expect(inherited,width,80,230,{0,0,0,255});expect(inherited,width,400,230,{0,0,0,255})
		local alpha=Raster.render(data.Scenes[3],{},width,nil)
		expect(alpha,width,80,80,{30,136,229,128});expect(alpha,width,150,80,{30,136,229,128})
		expect(alpha,width,360,80,{30,136,229,128});expect(alpha,width,360,36,{229,57,53,128})
		expect(alpha,width,360,44,{163,83,112,192})
		expect(alpha,width,110,240,{96,110,170,192});expect(alpha,width,360,240,{142,36,170,64})
		-- Every nonzero edge pixel of the isolated blue circle retains its unpremultiplied RGB.
		local edges=0
		for y=math.floor(40*width/480),math.floor(120*width/480)-1 do for x=math.floor(40*width/480),math.floor(120*width/480)-1 do
			local p=pixel(alpha,width,x,y)
			if p[4]>0 and p[4]<128 then edges+=1;assert(p[1]==30 and p[2]==136 and p[3]==229) end
		end end
		assert(edges>0)
	end
	print('SVG S07: inherited/default paint, currentColor, shared sRGB syntax, alpha multiplication/clamping, invalid fallback, widths, exact overlap pixels and clean transparent edges at three sizes passed')
	return data
end
