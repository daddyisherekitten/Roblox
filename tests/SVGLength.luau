--!strict
return function(Length,Parser,Viewport,Viewports,Sources,Raster)
	local context={Width=400,Height=100,FontSize=24,RootFontSize=16,XHeight=12,ZeroAdvance=13,LineHeight=30,RootLineHeight=20,CapHeight=17,IdeographicAdvance=24,CSSViewportWidth=1000,CSSViewportHeight=600}
	local function near(a,b) assert(a and math.abs(a-b)<1e-8,tostring(a).." ~= "..tostring(b)) end
	for _,text in {"96","96px","1in","2.54cm","25.4mm","101.6Q","72pt","6pc","4em","6rem","8ex","9.6e1PX","+.96e2"} do
		local n,problem=Length.resolve(text,context,"x");near(n,96);assert(problem==nil,text)
	end
	for text,expected in {["2ch"]=26,["2lh"]=60,["2rlh"]=40,["2cap"]=34,["2ic"]=48,["10vw"]=100,["10vh"]=60,["10vmin"]=60,["10vmax"]=100} do near(Length.resolve(text,context,"x"),expected) end
	near(Length.resolve("50%",context,"x"),200);near(Length.resolve("50%",context,"y"),50)
	near(Length.resolve("15%",context,"diagonal"),.15*math.sqrt(85000))
	near(Length.resolve("200%",context,"font"),48)
	near(Length.resolve("-20",context,"x"),-20)
	local n,problem=Length.resolve("-20",context,"x",true);assert(n==nil and problem=="negative-length")
	for _,text in {"","NaN","Infinity","1e999","12 px","1.2.3px","10%junk","2px;3px","--1","1e+"} do assert(Length.parse(text)==nil,text) end
	assert(select(2,Length.resolve("2quux",context,"x"))=="unsupported-length-unit")
	assert(select(2,Length.resolve("1vw",{},"x"))=="missing-length-context")
	assert(select(2,Length.resolve("2cap",{},"x"))=="missing-length-context")
	local fallback,notice=Length.resolve("2ex",{FontSize=20},"x");near(fallback,20);assert(notice=="font-metric-fallback")
	assert(select(2,Length.resolve("1em",{FontSize=-1},"x"))=="invalid-length-context")
	assert(select(2,Length.resolve("1e308in",context,"x"))=="length-overflow")
	near(Length.diagonal(0,0),0);assert(Length.diagonal(1e300,1e300)==1e300)
	near(Length.attribute(nil,context,"x",7),7);near(Length.attribute("oops",context,"x",7),7)
	local data=Viewports(Parser,Viewport,Sources,Raster,Length)
	assert(data.Stage=="S05" and #data.Scenes==3 and #data.Diagnostics==4)
	local ids={}
	for _,scene in data.Scenes do for _,shape in scene.Shapes do if shape.SourceId then ids[shape.SourceId]=shape end end end
	for name,shape in ids do if name:match('^unit%-') then near(shape.width,96);near(shape.height,20) end end
	near(ids['wide-circle'].width,2*.15*math.sqrt(85000));near(ids['narrow-circle'].width,2*.15*math.sqrt(25000))
	near(ids['wide-circle'].x+ids['wide-circle'].width/2,240);near(ids['wide-circle'].y+ids['wide-circle'].height/2,70)
	near(ids['wide-rect'].width,200);near(ids['wide-rect'].height,50)
	for _,id in {'zero-width','negative-width','unknown-unit'} do near(ids[id].width,0) end
	for _,id in {'zero-radius','negative-radius'} do near(ids[id].width,0);near(ids[id].height,0) end
	near(ids['invalid-height'].height,0)
	local function rgba(b,width,x,y) local at=(y*width+x)*4;return buffer.readu8(b,at),buffer.readu8(b,at+1),buffer.readu8(b,at+2),buffer.readu8(b,at+3) end
	for _,width in {240,480,960} do
		local scale=width/480
		local units=Raster.render(data.Scenes[1],{},width,nil)
		for name,shape in ids do if name:match('^unit%-') then
			local r,g,b=rgba(units,width,math.floor((shape.x+48)*scale),math.floor((shape.y+10)*scale))
			assert(r==shape.Color[1] and g==shape.Color[2] and b==shape.Color[3])
		end end
		local percent=Raster.render(data.Scenes[2],{},width,nil)
		local r,g,b=rgba(percent,width,math.floor(240*scale),math.floor(80*scale));assert(r==30 and g==136 and b==229)
		local invalid=Raster.render(data.Scenes[3],{},width,nil)
		for i=0,buffer.len(invalid)-4,4 do
			assert(not (buffer.readu8(invalid,i)==229 and buffer.readu8(invalid,i+1)==57 and buffer.readu8(invalid,i+2)==53),'Invalid red shapes must never be drawn')
		end
		for _,point in {{320,70},{120,240},{320,240}} do
			local rr,gg,bb=rgba(invalid,width,math.floor(point[1]*scale),math.floor(point[2]*scale));assert(rr==67 and gg==160 and bb==71,'Valid neighbors survive')
		end
	end
	-- Shape percentages use the nearest nested viewBox, not its parent's pixels.
	local nested={SourceSHA256='test',Cases={{Name='nested',SVG='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 320"><svg x="20" y="30" width="200" height="100" viewBox="0 0 100 50"><rect id="nested" x="25%" y="20%" width="50%" height="40%" fill="#000000"/></svg></svg>'}}}
	local shape=Viewports(Parser,Viewport,nested,Raster,Length).Scenes[1].Shapes[1]
	near(shape.x,70);near(shape.y,50);near(shape.width,100);near(shape.height,40)
	print('SVG S05: physical/font/context units, numeric syntax, percentage axes/diagonal, nested viewBox, invalid dimensions and three raster sizes passed')
	return data
end
