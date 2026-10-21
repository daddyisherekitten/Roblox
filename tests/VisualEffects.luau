--!strict
return function(Pixels: any)
	local ellipse={Kind="ellipse",X={Value=50,Percent=true},Y={Value=45,Percent=true}}
	local clipPlan=Pixels.plan(100,60)
	local clip=Pixels.renderClip(ellipse,100,60,Color3.new(1,1,1),clipPlan)
	local function alpha(data: buffer,x: number,y: number,width: number): number return buffer.readu8(data,(y*width+x)*4+3) end
	assert(alpha(clip,0,0,clipPlan.Width)>200,"ellipse corners must be covered")
	assert(alpha(clip,math.floor(clipPlan.Width/2),math.floor(clipPlan.Height/2),clipPlan.Width)==0,"ellipse center must remain visible")
	-- A circle's percentage radius uses the normalized diagonal, unlike an
	-- ellipse's independent axes. These interior probes are away from edges.
	for _,size in{{200,100},{100,200}}do
		local w,h=unpack(size);local plan=Pixels.plan(w,h);local circle={Kind='circle',Radius={Value=45,Percent=true}}
		local erased=Pixels.renderClip(circle,w,h,Color3.new(1,1,1),plan)
		local covered=Pixels.clipAlpha(circle,w,h,plan)
		local x,y=if w>h then 35 else 50,if h>w then 35 else 50
		assert(alpha(erased,x,y,w)==0 and buffer.readu8(covered,y*w+x)==255,'Non-square circle coverage keeps the native diagonal-radius interior')
		assert(alpha(erased,0,0,w)==255 and buffer.readu8(covered,0)==0,'Non-square circle coverage excludes its far corner')
	end
	local polygon={Kind="polygon",Points={{X={Value=20,Percent=true},Y={Value=0,Percent=true}},
		{X={Value=80,Percent=true},Y={Value=0,Percent=true}},
		{X={Value=100,Percent=true},Y={Value=100,Percent=true}},
		{X={Value=0,Percent=true},Y={Value=100,Percent=true}}}}
	local polygonMask=Pixels.renderClip(polygon,100,60,Color3.new(1,1,1),clipPlan)
	assert(alpha(polygonMask,0,0,clipPlan.Width)==255 and alpha(polygonMask,50,30,clipPlan.Width)==0,
		"Polygon clip hides the outer corner while keeping the center visible")
	local definition={Direction="to right",Color1=Color3.fromRGB(112,64,189),Alpha1=1,Color2=Color3.fromRGB(238,124,69),Alpha2=1}
	local borderPlan=Pixels.plan(100,40)
	local border=Pixels.renderBorder(definition,100,40,{7,7,7,7},borderPlan)
	assert(alpha(border,0,20,borderPlan.Width)==255 and alpha(border,50,20,borderPlan.Width)==0,"border image must paint only the border area")
	assert(buffer.readu8(border,0)<buffer.readu8(border,(borderPlan.Width-1)*4),"gradient border must change from purple to orange")
	local threeStops={Direction="105deg",Angle=105,Stops={
		{Color=Color3.fromRGB(117,65,195),Alpha=1},{Color=Color3.fromRGB(232,81,136),Alpha=1},
		{Color=Color3.fromRGB(245,146,73),Alpha=1}}}
	local angled=Pixels.renderBorder(threeStops,100,40,{7,7,7,7},borderPlan)
	local leftRed=buffer.readu8(angled,(20*borderPlan.Width+1)*4)
	local rightRed=buffer.readu8(angled,(20*borderPlan.Width+borderPlan.Width-2)*4)
	assert(leftRed<rightRed and leftRed>=117 and rightRed<=245,"Angled three-color border interpolates all stops")
	print("Visual effects: raster clip-path and border-image passed")
end
