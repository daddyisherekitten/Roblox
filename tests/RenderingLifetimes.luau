--!strict
return function(VisualEffects: any,BorderCorners: any,Style: any,WorkContext: any,InsetShadows: any)
 local fixtureElement=require('DOM/Node').element
	local images={}
	local function createImage(size: any): any
		local image={Size=size,Writes=0,Destroyed=false}
		function image:WritePixelsBuffer(_: any,_: any,pixels: buffer) self.Pixels=pixels;self.Writes+=1 end
		function image:Destroy() assert(not self.Destroyed,"EditableImage destroyed twice");self.Destroyed=true end
		table.insert(images,image);return image
	end
	local factory={}
	function factory.create(class: string,parent: any,properties: any): any
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent
		function gui:Destroy() self.Destroyed=true end
		return gui
	end
	local function style(css: string): any
		return Style.resolve(fixtureElement("div",{style=css}),{Font="Roboto",FontSize=16,Color=Color3.new(0,0,0)},error)
	end
	local effects=VisualEffects.new(error,createImage)
	local border={Gui={},Factory=factory,Style=style("border:2px solid transparent;border-image-source:linear-gradient(to right,red,blue);border-image-slice:1")}
	effects:Draw(border,100,40)
	local borderImage=border.BorderImageGradient.ImageContent
	assert(buffer.readu8(borderImage.Pixels,99*4+3)==255)
	border.Style.BorderImageSource.Stops[2].Alpha=0
	effects:Draw(border,100,40)
	assert(borderImage.Writes==2 and buffer.readu8(borderImage.Pixels,99*4+3)<=2,"Changing only the second gradient stop alpha must repaint the retained border image")
	local circle={Gui={},Factory=factory,Style=style("clip-path:circle(40px at center)")}
	effects:Draw(circle,600,300)
	local clipImage=circle.ClipPathMask.ImageContent
	local offset=(128*512+278)*4+3
	assert(buffer.readu8(clipImage.Pixels,offset)==0)
	effects:Draw(circle,1200,600)
	assert(circle.ClipPathMask.ImageContent==clipImage and clipImage.Writes==2,"An equal-size texture is reused and rerasterized when CSS geometry changes")
	assert(buffer.readu8(clipImage.Pixels,offset)==255,"Absolute clip radii must keep their CSS pixel size after downsampling")

	local corners=BorderCorners.new(error,createImage)
	-- Loading scopes can yield while a radius buffer or texture is prepared.
	-- Newer paint, native fallback, removal and teardown must invalidate the
	-- older job before it can publish pixels or restore its obsolete key.
	for _,checkpoint in {1,17,18}do
		local racing=BorderCorners.new(error,createImage);local box={Gui={},Factory=factory}
		assert(racing:DrawRadius(box,style('background:blue;border-radius:8px / 4px'),24,16))
		local kept=box.RasterBorderGui.ImageContent;local writes=kept.Writes;local count=0;local switched=false
		local obsolete=style('background:blue;border-radius:16px / 6px')
		local result=WorkContext.with(function()
			count+=1
			if count==checkpoint and not switched then
				switched=true;WorkContext.with(nil,function()assert(racing:DrawRadius(box,style('background:blue;border-radius:6px / 3px'),24,16))end)
			end
		end,function()return racing:DrawRadius(box,obsolete,24,16)end)
		assert(switched and result==nil and box.RasterBorderGui.ImageContent==kept and not kept.Destroyed,'Obsolete radius work cannot replace a newer retained image at checkpoint '..checkpoint)
		assert(kept.Writes==writes+(if checkpoint==18 then 2 else 1)and box.ResolvedBorderRadii[1][1]==6,'Only the latest radius probe is published after interleaving')
		assert(buffer.readu8(kept.Pixels,(24+3)*4+3)>200,'The surviving native image contains the newer, smaller ellipse')
		racing:Destroy();assert(kept.Destroyed,'The retained image is disposed after obsolete work returns')
	end
	for _,action in {'native','remove','destroy'}do
		local racing=BorderCorners.new(error,createImage);local box={Gui={},Factory=factory}
		assert(racing:DrawRadius(box,style('background:blue;border-radius:8px / 4px'),24,16))
		local kept=box.RasterBorderGui.ImageContent;local writes=kept.Writes;local switched=false
		local obsolete=style('background:blue;border-radius:16px / 6px')
		local result=WorkContext.with(function()
			if switched then return end;switched=true
			WorkContext.with(nil,function()
				if action=='native'then assert(racing:DrawRadius(box,style('background:blue;border-radius:4px'),24,16)==false)
				elseif action=='remove'then racing:Remove(box)else racing:Destroy()end
			end)
		end,function()return racing:DrawRadius(box,obsolete,24,16)end)
		assert(result==nil and kept.Writes==writes,'Obsolete radius work cannot upload after '..action)
		if action=='native'then assert(box.RasterBorderGui.Visible==false and not kept.Destroyed,'Native fallback hides and retains its cached image')else assert(kept.Destroyed,'Removal/teardown disposes the in-flight owner once')end
		racing:Destroy()
	end
	for _,phase in {'render','upload','published'}do
		local racing=InsetShadows.new(error,createImage);local box={Gui={},Style=style('box-shadow:inset 0 0 0 12px red')}
		if phase=='published'then racing:Draw(box,24,16);box.Style=style('box-shadow:inset 0 0 0 10px black')end
		local before=#images;local kept=box.Gui.ImageContent;local switched=false
		local result=WorkContext.with(function()
			if switched or phase=='upload'and #images==before then return end;switched=true
			WorkContext.with(nil,function()box.Style=style('box-shadow:inset 0 0 0 12px blue');racing:Draw(box,24,16)end)
		end,function()return racing:Draw(box,24,16)end)
		local latest=assert(box.Gui.ImageContent)
		assert(switched and result==nil and not latest.Destroyed and buffer.readu8(latest.Pixels,(24+1)*4+2)==255,'Obsolete inset '..phase..' work never publishes over the newer blue surface')
		if kept then assert(latest==kept,'An interrupted published inset reuses its native allocation')end
		if phase=='upload'then assert(images[before+1].Destroyed and latest==images[before+2],'An unpublished obsolete inset image is disposed once')end
		racing:Destroy();assert(latest.Destroyed,'The surviving inset image releases its lifetime owner')
	end
	for _,action in {'remove','destroy'}do
		local racing=InsetShadows.new(error,createImage);local box={Gui={},Style=style('box-shadow:inset 0 0 0 12px red')}
		local before=#images;local switched=false
		local result=WorkContext.with(function()
			if switched or #images==before then return end;switched=true
			if action=='remove'then racing:Remove(box)else racing:Destroy()end
		end,function()return racing:Draw(box,24,16)end)
		assert(switched and result==nil and images[before+1].Destroyed and box.Gui.ImageContent==nil,'Inset '..action..' disposes an unpublished image without late native publication')
		racing:Destroy()
	end
	local removed={Gui={},Factory=factory,Style=style("clip-path:ellipse(50% 50% at center)")}
	effects:Draw(removed,24,16)
	local removedImage=removed.ClipPathMask.ImageContent
	effects:Remove(removed);effects:Remove(removed)
	assert(removedImage.Destroyed,"DOM removal releases the owner's raster image immediately")
	local removedCorner={Gui={},Factory=factory}
	assert(corners:DrawRadius(removedCorner,style("background:blue;border:1px solid red;border-radius:8px;corner-shape:squircle"),24,16))
	local removedCornerImage=removedCorner.RasterBorderGui.ImageContent
	corners:Remove(removedCorner);corners:Remove(removedCorner)
	assert(removedCornerImage.Destroyed,"DOM removal releases radius atlases before page destruction")
	local orphaned=setmetatable({},{__mode="k"})
	local function transientOwners()
		local a={Gui={},Factory=factory,Style=style("clip-path:ellipse(50% 50% at center)")}
		local b={Gui={},Factory=factory}
		orphaned[a],orphaned[b]=true,true
		effects:Draw(a,24,16)
		assert(corners:DrawRadius(b,style("background:blue;border:1px solid red;border-radius:8px;corner-shape:squircle"),24,16))
	end
	-- A discarded coroutine also retires its VM/native-call stack slots. The
	-- active main stack can retain a finished raster callback's temporary owner;
	-- the same weak sentinels below must test the renderer's ownership instead.
	coroutine.wrap(transientOwners)()
	local function ownersCollected(): boolean
		-- Do not return a weak-table key into the allocating caller's stack.
		-- That temporary itself can otherwise root an owner during a GC cycle.
		return next(orphaned) == nil
	end
	-- Luau only exposes collectgarbage("count"). Bounded temporary allocation
	-- advances its normal collector; the weak sentinels verify that this fixture
	-- actually exercised owner collection before testing explicit image cleanup.
	for _=1,128 do
		if ownersCollected() then break end
		local temporary=table.create(2048)
		for index=1,2048 do temporary[index]={index,index+1} end
	end
	assert(ownersCollected(),"Renderer cleanup records must not retain their render-box owners")
	effects:Destroy();effects:Destroy();corners:Destroy();corners:Destroy()
	for _,image in images do assert(image.Destroyed,"Collected GUI owners must not lose their EditableImage cleanup handles") end
	print("Rendering lifetime: collected owners, exactly-once image cleanup, border alpha invalidation and downsampled clip geometry passed")
end
