--!strict
return function(Style: any,Pixels: any,BackgroundImages: any)
 local fixtureElement=require('DOM/Node').element
	local parent={Font="Roboto",FontSize=16,RootFontSize=16,Color=Color3.new(0,0,0),ColorAlpha=1,ViewportWidth=800,ViewportHeight=600}
	local function resolve(css: string): any
		return Style.resolve(fixtureElement("div",{style=css}),parent,error)
	end
	local layered=resolve([[background-image:linear-gradient(to right, red 0%, rgba(0,0,255,.5) 100%),url("Case/Photo.PNG");background-size:calc(50% - 2px) 40px,cover;background-position:right 10px bottom 20%,center;background-repeat:repeat-x,no-repeat;background-origin:content-box,padding-box;background-clip:padding-box,border-box]])
	assert(#layered.BackgroundImages==2 and layered.BackgroundImages[1].Kind=="linear" and layered.BackgroundImages[1].Angle==90)
	assert(layered.BackgroundImages[2].Kind=="url" and layered.BackgroundImages[2].Source=="Case/Photo.PNG","URL paths retain browser case")
	assert(#layered.BackgroundSizes==2 and layered.BackgroundSizes[2].Kind=="cover")
	assert(layered.BackgroundRepeats[1].X=="repeat" and layered.BackgroundRepeats[1].Y=="no-repeat")
	assert(layered.BackgroundPositions[1].X.Anchor==1 and layered.BackgroundPositions[1].Y.Anchor==1)
	assert(layered.BackgroundOrigins[1]=="content-box" and layered.BackgroundClips[1]=="padding-box")
	local axes=resolve("background-position:left top;background-position-x:right 12px,25%;background-position-y:bottom 8px,top")
	assert(#axes.BackgroundPositions==2 and axes.BackgroundPositions[1].X.Anchor==1 and axes.BackgroundPositions[1].X.Offset.Value==12)
	assert(axes.BackgroundPositions[1].Y.Anchor==1 and axes.BackgroundPositions[1].Y.Offset.Value==8)
	assert(axes.BackgroundPositions[2].X.Offset.Percent and axes.BackgroundPositions[2].X.Offset.Value==25 and axes.BackgroundPositions[2].Y.Anchor==0)
	local axisCascade=resolve("background-position:right bottom;background-position-x:left 7px")
	assert(axisCascade.BackgroundPositions[1].X.Anchor==0 and axisCascade.BackgroundPositions[1].X.Offset.Value==7 and axisCascade.BackgroundPositions[1].Y.Anchor==1)
	local axisWarnings=0
	local invalidAxis=Style.resolve(fixtureElement("div",{style="background-position-x:right;background-position-x:top;background-position-y:bottom;background-position-y:left"}),parent,function()axisWarnings+=1 end)
	assert(axisWarnings==2 and invalidAxis.BackgroundPositions[1].X.Anchor==1 and invalidAxis.BackgroundPositions[1].Y.Anchor==1)

	local radial=resolve("color:#123456;background-image:radial-gradient(circle 30px at 25% 40%,currentcolor 0,transparent 100%);background-size:80px 60px;background-repeat:round space")
	assert(radial.BackgroundImages[1].Kind=="radial" and radial.BackgroundImages[1].Shape=="circle")
	assert(radial.BackgroundImages[1].Size[1].Value==30 and radial.BackgroundRepeats[1].X=="round" and radial.BackgroundRepeats[1].Y=="space")
	local conic=resolve("background-image:repeating-conic-gradient(#375886 0 25%,#193857 0 50%);background-size:34px 34px")
	assert(conic.BackgroundImages[1].Kind=="conic" and conic.BackgroundImages[1].Repeating and #conic.BackgroundImages[1].Stops==4)
	local conicPixels=Pixels.render(34,34,conic.BackgroundImages[1],conic,Pixels.plan(34,34))
	local function conicColor(x: number,y: number): (number,number,number)
		local offset=(y*34+x)*4
		return buffer.readu8(conicPixels,offset),buffer.readu8(conicPixels,offset+1),buffer.readu8(conicPixels,offset+2)
	end
	local firstR,firstG,firstB=conicColor(27,7)
	local repeatR,repeatG,repeatB=conicColor(7,27)
	local secondR,secondG,secondB=conicColor(27,27)
	assert(firstR==repeatR and firstG==repeatG and firstB==repeatB and (firstR~=secondR or firstG~=secondG or firstB~=secondB),"Repeating conic quadrants follow clockwise color stops")
	local shorthand=resolve("background:linear-gradient(red,blue) center / cover no-repeat padding-box content-box #102030")
	assert(shorthand.BackgroundImages[1].Kind=="linear" and shorthand.BackgroundSizes[1].Kind=="cover")
	assert(shorthand.BackgroundRepeats[1].X=="no-repeat" and shorthand.BackgroundOrigins[1]=="padding-box" and shorthand.BackgroundClips[1]=="content-box")
	assert(shorthand.Background==Color3.fromRGB(16,32,48))
	local color=resolve("background:rgba(10,20,30,.5)")
	assert(color.Background==Color3.fromRGB(10,20,30) and color.BackgroundAlpha==.5 and color.BackgroundImages[1].Kind=="none")
	local reset=resolve("background-image:linear-gradient(red,blue);background:initial")
	assert(reset.Background==nil and reset.BackgroundImages[1].Kind=="none")

	local gradient=layered.BackgroundImages[1]
	local plan=Pixels.plan(5,1)
	local data=Pixels.render(5,1,gradient,layered,plan)
	assert(buffer.readu8(data,0)>buffer.readu8(data,2),"Linear gradient starts red")
	local finish=(plan.Width-1)*4
	assert(buffer.readu8(data,finish+2)>buffer.readu8(data,finish),"Linear gradient ends blue")
	assert(buffer.readu8(data,finish+3)<255,"Alpha interpolates at the final stop")
	local blended=resolve("background-color:#808080;background-image:linear-gradient(#ff000080,#ff000080),linear-gradient(#0000ff80,#0000ff80);background-blend-mode:multiply,screen")
	assert(#blended.BackgroundBlendMode==2 and blended.BackgroundBlendMode[1]=="multiply" and blended.BackgroundBlendMode[2]=="screen")
	local blendPixels=Pixels.renderBlend(4,4,blended.BackgroundImages,blended.BackgroundBlendMode,blended,Pixels.plan(4,4))
	assert(math.abs(buffer.readu8(blendPixels,0)-128)<3 and math.abs(buffer.readu8(blendPixels,1)-64)<3 and math.abs(buffer.readu8(blendPixels,2)-96)<3,
		"Each gradient blends in CSS back-to-front order against the background color")

	local created,allocations,destroyed={},{0},0
	local factory={}
	function factory.create(class: string,parentGui: any,properties: any): any
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parentGui
		function gui:Destroy() self.Destroyed=true end
		table.insert(created,gui);return gui
	end
	function factory.modifier(class: string,parentGui: any,properties: any): any return factory.create(class,parentGui,properties) end
	local function createImage(size: any): any
		allocations[1]+=1
		local image={Size=size}
		function image:WritePixelsBuffer(_: any,_: any,pixels: buffer) self.Pixels=pixels end
		function image:Destroy() assert(not self.Destroyed,"Cached images must be destroyed exactly once");self.Destroyed=true;destroyed+=1 end
		return image
	end
	local diagnostics={}
	local renderer=BackgroundImages.new(function(message: string)table.insert(diagnostics,message)end,function(path: string)return if path=="Case/Photo.PNG" then "rbxassetid://1" else nil end,createImage)
	local blendRenderer=BackgroundImages.new(function(message: string)table.insert(diagnostics,message)end,nil,createImage)
	local blendBox={Gui={BackgroundTransparency=1},Style=blended,Factory=factory}
	blendRenderer:Draw(blendBox,4,4)
	assert(allocations[1]==1 and #diagnostics==0,"Blend layers use one retained composite image")
	blendRenderer:Draw(blendBox,4,4)
	assert(allocations[1]==1,"The composited background is reused on an unchanged layout")
	blendRenderer:Destroy()
	local box={Gui={BackgroundTransparency=1},Style=layered,Factory=factory}
	renderer:Draw(box,200,100)
	assert(allocations[1]==2 and #diagnostics==0,"One gradient layer allocates one cached image")
	renderer:Draw(box,200,100)
	assert(allocations[1]==2,"Unchanged background geometry reuses the gradient cache")
	renderer:Draw(box,100,50)
	assert(allocations[1]==3,"A new raster size gets its own cached image")
	local localStyle=table.clone(layered);localStyle.BackgroundAttachments={"local","scroll"}
	local localBox={Gui={BackgroundTransparency=1},ScrollContent={},ScrollRight=200,ScrollBottom=300,Style=localStyle,Factory=factory}
	renderer:Draw(localBox,200,100)
	local localLayer
	for _,gui in created do if gui.Parent==localBox.ScrollContent and gui.Name and gui.Name:find("BackgroundLayer_",1,true) then localLayer=gui end end
	assert(localLayer and localLayer.Size[1]==200 and localLayer.Size[2]==300,"local backgrounds must cover the complete scrollable canvas")
	renderer:Destroy();assert(destroyed==allocations[1],"Cached EditableImages are released")
	local function imageFor(target: any): any
		for _,gui in created do if gui.Name=="BackgroundImage"and not gui.Destroyed and gui.Parent and not gui.Parent.Destroyed and gui.Parent.Parent==target.Gui then return gui end end
		error("Expected a rendered background image")
	end
	local fixedCallback,fixedDisconnected
	local fixedGui={BackgroundTransparency=1,AbsolutePosition=Vector2.new(250,130)}
	function fixedGui:GetPropertyChangedSignal(name: string): any
		assert(name=="AbsolutePosition")
		return {Connect=function(_: any,callback: any): any
			fixedCallback=callback
			return {Disconnect=function() fixedDisconnected=true end}
		end}
	end
	local fixedStyle=resolve("background-image:repeating-linear-gradient(to bottom,#d9ecf8 0,#d9ecf8 24px,#91b9d7 24px,#91b9d7 48px);background-size:100% 48px;background-attachment:fixed")
	local fixedRenderer=BackgroundImages.new(function(message: string)table.insert(diagnostics,message)end,nil,createImage,
		{AbsolutePosition=Vector2.new(50,30)})
	local fixedBox={Gui=fixedGui,ScrollContent={},Style=fixedStyle,Factory=factory,OuterWidth=200,OuterHeight=100}
	fixedRenderer:Draw(fixedBox,200,100)
	local fixedImage=imageFor(fixedBox)
	assert(fixedCallback and fixedImage.Parent.Parent==fixedGui,
		"A fixed background stays on the box surface and observes its viewport position")
	local beforePhase=(fixedGui.AbsolutePosition.Y+fixedImage.Position[2])%48
	assert(beforePhase==30 and (fixedGui.AbsolutePosition.X+fixedImage.Position[1])%800==50,
		"Fixed background tiles are aligned to the page viewport, not the physical screen")
	local beforeRaster=fixedImage.ImageContent
	fixedGui.AbsolutePosition=Vector2.new(250,120)
	fixedCallback()
	assert((fixedGui.AbsolutePosition.Y+fixedImage.Position[2])%48==beforePhase
		and fixedImage.ImageContent==beforeRaster,
		"Page scrolling must preserve the fixed stripe phase without regenerating the gradient")
	fixedGui.AbsolutePosition=Vector2.new(250,109)
	fixedRenderer:RefreshFixed()
	assert((fixedGui.AbsolutePosition.Y+fixedImage.Position[2])%48==beforePhase
		and fixedImage.ImageContent==beforeRaster,
		"The page scroll listener must restore the same viewport-relative stripe phase")
	fixedRenderer:Destroy()
	assert(fixedDisconnected,"Fixed-background position observer is removed with the page")
	-- The two backdrop orbs have gradient children and percentage radii. A
	-- UICorner on the outer box alone cannot clip the child background image.
	local circles=BackgroundImages.new(error,nil,createImage)
	local function cornerFor(image: any): any
		for _,gui in created do if gui.ClassName=="UICorner" and gui.Parent==image.Parent then return gui end end
		return nil
	end
	for _,colors in {"#ffd069,#f77868","#67d9cb,#9caaf9"} do
		local orb={Gui={},Factory=factory,Style=resolve("width:180px;height:180px;border-radius:50%;background:linear-gradient(45deg,"..colors..")")}
		circles:Draw(orb,180,180)
		local image=imageFor(orb);local corner=cornerFor(image)
		assert(image.Parent.ClassName=="CanvasGroup" and corner and corner.CornerRadius.Offset==90,
			"A 180px percentage-rounded gradient must clip its own layer to a 90px circle")
		local before=allocations[1];circles:Draw(orb,180,180)
		assert(allocations[1]==before and imageFor(orb)==image,"Rounded backgrounds retain their image and clipping host")
		circles:Draw(orb,120,120)
		assert(cornerFor(imageFor(orb)).CornerRadius.Offset==60,"Percentage background radii update on resize")
	end
	local clippedOrb={Gui={},Factory=factory,Style=resolve("border:5px solid black;border-radius:50%;background:linear-gradient(red,blue);background-clip:padding-box")}
	circles:Draw(clippedOrb,180,180)
	assert(cornerFor(imageFor(clippedOrb)).CornerRadius.Offset==85,"Background clipping subtracts the border inset after resolving percent radii")
	local roundBlend={Gui={},Factory=factory,Style=resolve("background-color:#808080;background-image:linear-gradient(red,red),linear-gradient(blue,blue);background-blend-mode:multiply,screen;border-radius:50%")}
	circles:Draw(roundBlend,180,180)
	assert(cornerFor(imageFor(roundBlend)).CornerRadius.Offset==90,"Composited gradient layers share the same percentage-rounded clip")
	circles:Destroy()
	local stress=BackgroundImages.new(function(message: string)table.insert(diagnostics,message)end,nil,createImage)
	local stressStyle=resolve("background-image:linear-gradient(to right,red 80px,blue 100px);background-repeat:no-repeat")
	local pinned={Gui={},Style=stressStyle,Factory=factory}
	local resizing={Gui={},Style=stressStyle,Factory=factory}
	stress:Draw(pinned,60,1)
	local pinnedImage=imageFor(pinned).ImageContent
	for width=70,170 do
		stress:Draw(resizing,width,1)
		local current=imageFor(resizing)
		assert(current.Visible and current.ImageContent and not current.ImageContent.Destroyed,"Repeated resize must evict unused gradient variants instead of omitting the background")
		assert(not pinnedImage.Destroyed,"Gradient eviction must preserve images displayed by other boxes")
	end
	assert(allocations[1]-destroyed<=64 and #diagnostics==0,"Resize cache remains bounded without dropping visible gradients")
	stress:Draw(resizing,300,100)
	local small=imageFor(resizing).ImageContent
	local smallRed=buffer.readu8(small.Pixels,64*4)
	stress:Draw(resizing,600,200)
	local large=imageFor(resizing).ImageContent
	assert(small~=large and small.Size.X==large.Size.X and small.Size.Y==large.Size.Y,"Equal raster dimensions must not alias different CSS gradient geometries")
	assert(smallRed>240 and buffer.readu8(large.Pixels,64*4)<10,"Absolute gradient stops retain CSS pixel positions after downsampling")
	stress:Destroy();stress:Destroy()
	assert(destroyed==allocations[1],"Evicted and retained gradients are each destroyed once")
	-- Native image APIs and cooperative upload checkpoints can reenter the
	-- background owner. A retired draw must not publish or repopulate its cache.
	for _,stage in {'allocation','upload'}do for _,action in {'destroy','remove','replace'}do
		local target={Gui={},Factory=factory,Style=resolve('background-image:linear-gradient(red,red)')}
		local owner,triggered;local allocated={};local uploads=0
		local function retire()
			if triggered then return end;triggered=true
			if action=='destroy'then owner:Destroy()elseif action=='remove'then owner:Remove(target)
			else target.Style=resolve('background-image:linear-gradient(blue,blue)');owner:Draw(target,8,8)end
		end
		owner=BackgroundImages.new(error,nil,function(size)
			local image=createImage(size);table.insert(allocated,image)
			local write=image.WritePixelsBuffer
			function image:WritePixelsBuffer(...)uploads+=1;write(self,...);if stage=='upload'then retire()end end
			if stage=='allocation'then retire()end
			return image
		end)
		owner:Draw(target,8,8)
		assert(allocated[1].Destroyed,stage..' '..action..': abandoned allocation must be freed before returning')
		if stage=='allocation'then assert(uploads==(if action=='replace'then 1 else 0),'Retired allocation must not upload pixels')end
		if action=='replace'then
			local current=imageFor(target).ImageContent
			assert(current==allocated[2]and buffer.readu8(current.Pixels,2)==255,'A nested newer draw remains the visible image')
		elseif action=='remove'then
			target.Style=resolve('background-image:linear-gradient(blue,blue)');owner:Draw(target,8,8)
			assert(imageFor(target).ImageContent==allocated[2]and not allocated[2].Destroyed,'Retiring one draw does not disable later native allocations')
		else local count=#allocated;owner:Draw(target,8,8);assert(#allocated==count,'Destroyed renderer rejects later draws')
		end
		owner:Destroy();owner:Destroy()
		for _,image in allocated do assert(image.Destroyed,'Reentrant disposal leaves no background allocation alive')end
	end end
	for _,action in {'destroy','remove','replace'}do
		local target={Gui={},Factory=factory,Style=resolve('background-image:url(image.png)')}
		local owner,retired
		owner=BackgroundImages.new(error,function()
			retired=imageFor(target)
			if action=='destroy'then owner:Destroy()elseif action=='remove'then owner:Remove(target)
			else target.Style=resolve('background-image:linear-gradient(blue,blue)');owner:Draw(target,8,8)end
			return 'rbxassetid://1'
		end,createImage)
		owner:Draw(target,8,8)
		assert(retired.Image~='rbxassetid://1','Returning URL callback cannot publish into its retired image')
		if action=='replace'then assert(buffer.readu8(imageFor(target).ImageContent.Pixels,2)==255,'URL resolver reentry retains the newer gradient')end
		owner:Destroy();owner:Destroy()
	end
	assert(destroyed==allocations[1],'Reentrant background owners release every allocation exactly once')
	print("CSS backgrounds: parsing, raster alpha, retained layers, bounded resize cache, shared image lifetime, CSS pixel stops, 9 reentrant allocation/upload/URL retirement cases and cleanup passed")
end
