--!strict
return function(Hit,Matrix,NativeHit)
	local function gui(parent,position,size)
		local attributes={}
		return {Parent=parent,Visible=true,AbsolutePosition=position or Vector2.new(0,0),AbsoluteSize=size or Vector2.new(100,100),
			IsA=function(_,name)return name=="GuiObject"end,GetAttribute=function(_,name)return attributes[name]end,SetAttribute=function(_,name,value)attributes[name]=value end}
	end
	local nativeRoot=gui(nil,Vector2.new(0,0),Vector2.new(500,500))
	local surface=gui(nativeRoot,Vector2.new(100,80),Vector2.new(200,200))
	local owner=gui(nativeRoot)
	local function node(id,matrix,preserve,width,height)
		local dom={Kind="Element",Name="button",Attributes={id=id},Children={}}
		local box={Node=dom,Gui=gui(owner),OuterWidth=width or 100,OuterHeight=height or 100,Style={Background=Color3.new(1,0,0)},Children={}}
		return {Box=box,Matrix=matrix or Matrix.identity(),Children={},Preserve=preserve~=false}
	end
	local bounds={Left=0,Top=0,Width=200,Height=200}
	local scene=node("root",Matrix.identity(),true,200,200)
	local button=node("child",Matrix.translate(20,30))
	scene.Children={button}
	local registry={[owner]=scene.Box.Node};local styles={}
	local retained=Hit.attach(surface,scene,bounds)
	local hit,object,point=Hit.pick(surface,Vector2.new(135,125),registry,styles)
	assert(hit==button.Box.Node and object==button.Box.Gui and math.abs(point.X-15)<.0001 and math.abs(point.Y-15)<.0001)
	local picked,pickedGui=NativeHit.pick({surface,owner},registry,nativeRoot,Vector2.new(135,125),styles)
	assert(picked==button.Box.Node and pickedGui==button.Box.Gui,"Native scene surfaces route to hidden descendant identities")
	assert(Hit.pick(scene.Box.Gui,Vector2.new(135,125),registry,styles)==button.Box.Node,"The unpainted native owner uses the same projected hit geometry")
	local outside=NativeHit.pick({surface},registry,nativeRoot,Vector2.new(350,350),styles)
	assert(outside==nil,"Raster rectangle padding is not a DOM hit")
	-- Positive depth is in front, matching the rasterizer's per-pixel order.
	local front=node("front",Matrix.translate(20,30,20));local back=node("back",Matrix.translate(20,30,-20))
	scene.Children={front,back};retained=Hit.attach(surface,scene,bounds)
	assert(Hit.pick(surface,Vector2.new(135,125),registry,styles)==front.Box.Node)
	front.Box.Style.PointerEvents="none";assert(Hit.pick(surface,Vector2.new(135,125),registry,styles)==scene.Box.Node)
	scene.Box.Style.PointerEvents="none";assert(Hit.pick(surface,Vector2.new(135,125),registry,styles)==back.Box.Node,"Descendant auto can override pointer-events:none")
	scene.Box.Style.PointerEvents=nil
	-- A flat group's descendants are picked in its local projection before
	-- the complete group is compared with other outer planes.
	scene.Matrix=Matrix.translate(0,0,40);scene.Preserve=false;scene.Children={button}
	retained=Hit.attach(surface,scene,bounds)
	assert(Hit.pick(surface,Vector2.new(135,125),registry,styles)==button.Box.Node)
	scene.Matrix=Matrix.multiply(Matrix.perspective(200),Matrix.around(Matrix.rotate(0,1,0,35),100,100))
	button.Matrix=Matrix.translate(20,30)
	local projected=Matrix.point(scene.Matrix,35,45)
	retained=Hit.attach(surface,scene,bounds)
	hit,object,point=Hit.pick(surface,Vector2.new(100+projected.X/projected.W,80+projected.Y/projected.W),registry,styles)
	assert(hit==button.Box.Node and math.abs(point.X-15)<.0001 and math.abs(point.Y-15)<.0001,"Perspective inverse returns local coordinates")
	scene.Matrix=Matrix.identity();scene.Clip=true;scene.Box.OuterWidth=40;scene.Box.OuterHeight=40
	retained=Hit.attach(surface,scene,bounds)
	assert(Hit.pick(surface,Vector2.new(135,125),registry,styles)==nil,"Overflow clipping applies before child hits")
	scene.Clip=false;retained=Hit.attach(surface,scene,bounds)
	assert(Hit.pick(surface,Vector2.new(135,125),registry,styles)==button.Box.Node)
	scene.Clip=true;scene.Box.OuterWidth=100;scene.Box.OuterHeight=100;scene.Box.Style.BorderRadius=30
	retained=Hit.attach(surface,scene,bounds)
	assert(Hit.pick(surface,Vector2.new(101,81),registry,styles)==nil,"Rounded clips reject clipped corners")
	scene.Clip=false;scene.Box.Style.BorderRadius=0;scene.Box.Style.BackfaceVisibility="hidden"
	scene.Matrix=Matrix.rotate(0,1,0,180);retained=Hit.attach(surface,scene,bounds)
	assert(Hit.pick(surface,Vector2.new(90,90),registry,styles)==nil,"Flat hidden backfaces suppress descendants")
	scene.Box.Style.BackfaceVisibility=nil;scene.Matrix=Matrix.multiply(Matrix.perspective(100),Matrix.translate(0,0,150))
	retained=Hit.attach(surface,scene,bounds)
	assert(Hit.pick(surface,Vector2.new(90,90),registry,styles)==nil,"Planes behind the eye are not interactive")
	scene.Matrix=Matrix.scale(0,1,1);retained=Hit.attach(surface,scene,bounds)
	assert(Hit.pick(surface,Vector2.new(110,90),registry,styles)==nil,"Singular projections have no plane hit")
	scene.Matrix=Matrix.identity();scene.Children={button};scene.Box.OuterWidth=200;scene.Box.OuterHeight=200
	surface.AbsoluteSize=Vector2.new(400,400);retained=Hit.attach(surface,scene,bounds)
	assert(Hit.pick(surface,Vector2.new(170,170),registry,styles)==button.Box.Node,"Native ancestor scaling is inverted")
	surface.AbsoluteSize=Vector2.new(200,200);surface.AbsoluteRotation=90;retained=Hit.attach(surface,scene,bounds)
	assert(Hit.pick(surface,Vector2.new(255,115),registry,styles)==button.Box.Node,"Native ancestor rotation is inverted")
	Hit.detach(surface);assert(not Hit.has(surface)and not Hit.has(scene.Box.Gui)and Hit.pick(surface,Vector2.new(135,125),registry,styles)==nil)
	assert(retained.Scene.Box==scene.Box,"Scene metadata retains the original box identity")
	print("ProjectiveHit: native dispatch, descendants, depth, flat/preserve, perspective coordinates, clips/corners, pointer overrides, eye/backface/singular, scaling/rotation and disposal passed")
end
