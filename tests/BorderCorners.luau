--!strict
return function(Style, Pixels, Corners, BorderBox, Parser, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local function style(css)
		return Style.resolve(fixtureElement('div',{style = css}), {Font = 'Roboto', FontSize = 20, Color = Color3.new(0,0,0)}, error)
	end
	local s = style('border-width:6px 10px 8px 12px;border-style:solid;border-color:rgba(255,0,0,.5) rgba(0,255,0,.5) rgba(0,0,255,.5) rgba(255,255,0,.5)')
	local plan = Pixels.plan(s, 100, 60)
	local data = Pixels.render(s, plan)
	local function pixel(x,y)
		local offset = (y*plan.Width+x)*4
		return buffer.readu8(data,offset), buffer.readu8(data,offset+1), buffer.readu8(data,offset+2), buffer.readu8(data,offset+3)
	end
	local red, green, blue, alpha = pixel(10,0)
	assert(red == 255 and green == 0 and blue == 0 and alpha == 128)
	red, green = pixel(0,4); assert(red == 255 and green == 255, 'Unequal widths move the diagonal to the inner corner')
	for offset = 3, buffer.len(data)-1, 4 do assert(buffer.readu8(data,offset) == 128, 'Joining translucent sides must not overlap or leave seams') end
	for _, kind in {'groove','ridge','double','dashed','dotted','inset','outset'} do
		local parsed = style('border:8px ' .. kind .. ' #80a0c0')
		local p = Pixels.plan(parsed,100,60)
		assert(buffer.len(Pixels.render(parsed,p)) == p.Width*p.Height*4)
	end
	assert(Pixels.plan(s,10,10) == nil)
	local big = Pixels.plan(style('border:100000px groove red'),200000,200000)
	assert(big.Width <= 130 and big.Height <= 130)
	local images, writes, destroyed, objects, notices = 0,0,0,0,0
	local failWrite = false
	local function createImage(size)
		assert(size.X<=1024 and size.Y<=1024,'Complete EditableImage atlas must respect the native dimensions')
		images += 1
		return {Size=size,WritePixelsBuffer = function(self, _, dims, bytes)
			if failWrite then error('write failed') end
			writes += 1; assert(dims.X == size.X and dims.Y == size.Y and buffer.len(bytes) == size.X*size.Y*4)
			self.Pixels=bytes
		end, Destroy = function() destroyed += 1 end}
	end
	local labels,masks = {},{}
	local factory = {create = function(class, parent, props)
		objects += 1; local gui = table.clone(props); gui.Parent, gui.ClassName = parent, class
		local attributes={}
		function gui:SetAttribute(key,value)attributes[key]=value end
		function gui:GetAttribute(key)return attributes[key]end
		if gui.Name:find('BorderCorner_',1,true) then table.insert(labels,gui) end
		if gui.Name:find('RoundedClipMask',1,true) then table.insert(masks,gui) end
		return gui
	end, modifier = function(class,parent,props)
		local object=table.clone(props or {});object.ClassName,object.Parent=class,parent;return object
	end}
	local renderer = Corners.new(function() notices += 1 end,createImage)
	local edges = BorderBox.create(s,{},factory,renderer)
	BorderBox.arrange(edges,s,100,60)
	assert(images == 1 and #labels == 4 and edges[1].Position[1] == 12 and edges[1].Size[1] == 78)
	assert(edges[1].ClipsDescendants and labels[2].Position[1] == 90 and labels[4].Position[2] == 52)
	local created, drawn = objects,writes
	BorderBox.arrange(edges,s,180,80)
	assert(images == 1 and writes == drawn and objects == created and labels[2].Position[1] == 170)
	local pattern = style('border:6px dashed red')
	local patterned = BorderBox.create(pattern,{},factory,renderer)
	BorderBox.arrange(patterned,pattern,100,60)
	assert(patterned.Pools[1].Length == 100 and patterned.Pools[1].Offset == 6 and patterned.Pools[2].Length == 60)
	local before = writes
	BorderBox.arrange(patterned,pattern,100,60); assert(writes == before)
	BorderBox.arrange(patterned,pattern,90,60); assert(writes == before+1 and images == 2)
	failWrite = true
	BorderBox.arrange(patterned,pattern,80,60)
	assert(notices == 1 and destroyed == 1 and patterned[1].Position[1] == 0 and patterned[1].Size[1] == 80)
	for index = 5,8 do assert(not labels[index].Visible) end
	renderer:Destroy(); renderer:Destroy(); assert(destroyed == 2)
	local fallback = Corners.new(function() notices += 1 end,function() return nil end)
	local old = BorderBox.create(s,{},factory,fallback)
	BorderBox.arrange(old,s,100,60); BorderBox.arrange(old,s,110,60)
	assert(old[1].Position[1] == 0 and notices == 2)
	fallback:Destroy()
	failWrite = false
	local radiusRenderer=Corners.new(error,createImage)
	local nativeStyle=style('background:#dfcff2;border:3px solid #6d3bb2;border-radius:34px 8px 28px 15px')
	assert(radiusRenderer:CanUseNative(nativeStyle),'four absolute circular corner values use native UICorner properties')
	assert(not radiusRenderer:CanUseNative(style('background:#dfcff2;border:3px solid #6d3bb2;border-radius:42px 12% / 18px 45%')),'elliptical and percentage radii stay on the raster path')
	local radiusStyle=style('overflow:hidden;background:#dfcff2;border:3px solid #6d3bb2;border-radius:34px 8px 28px 15px')
	assert(not radiusRenderer:CanUseNative(radiusStyle),'overflow clipping stays on the raster path')
	local radiusBox={Factory=factory,Gui={Parent={BackgroundTransparency=0,BackgroundColor3=Color3.new(1,1,1)}}}
	local radiusWrites,radiusDestroyed=writes,destroyed
	assert(radiusRenderer:DrawRadius(radiusBox,radiusStyle,240,100))
	assert(radiusBox.RasterBorderGui:GetAttribute('HTMLPaintOnlyOverlay')==true,
		'The full-box raster border must not capture pointer events')
	assert(masks[#masks]:GetAttribute('HTMLPaintOnlyOverlay')==true,
		'The transparent center of a clipping mask must not cover links')
	assert(writes==radiusWrites+1 and radiusBox.ResolvedBorderRadii[1][1]==34 and radiusBox.ResolvedBorderRadii[2][1]==8)
	assert(#masks==1 and masks[1].ZIndex==100000 and masks[1].Visible,'overflow children use the same independent rounded surface as the border')
	local squircleStyle=style('background:#dfcff2;border:3px solid #6d3bb2;border-radius:28px;corner-shape:squircle')
	assert(not radiusRenderer:CanUseNative(squircleStyle),'non-round corner-shape must stay on the antialiased raster path')
	local squircleEdges=BorderBox.create(squircleStyle,{},factory,radiusRenderer)
	assert(squircleEdges and squircleEdges[1],"a raster corner shape must not leave a native rectangular UIStroke behind")
	local squircleBox={Factory=factory,Gui={Parent={BackgroundTransparency=0,BackgroundColor3=Color3.new(1,1,1)}}}
	local squircleWrites=writes;assert(radiusRenderer:DrawRadius(squircleBox,squircleStyle,160,72))
	squircleStyle.ResolvedBorderRadii=squircleBox.ResolvedBorderRadii
	BorderBox.arrange(squircleEdges,squircleStyle,160,72)
	assert(writes==squircleWrites+1 and squircleBox.ResolvedBorderRadii[1][1]==28,'squircle raster must retain its CSS radius')
	for index=1,4 do assert(not squircleEdges[index].Visible,"raster corner border must hide every rectangular edge strip") end
	radiusRenderer:Destroy();assert(destroyed==radiusDestroyed+2)
	local live = Corners.new(error,createImage)
	local treeRenderer = loadRenderTree(factory)
	local words = loadWordLayout({['Layout/FontProfiles']={face=function(font) return font end},
		['Layout/TextMeasure']={measure=function(_,_,size) return {X=10,Y=size} end}})
	local layout = loadBlockLayout({['Layout/WordLayout']=words})
	local tree = treeRenderer.build(Parser.parse('<div style="border:6px ridge blue;height:20px"></div><img src="a" width="30" height="20" style="border:4px groove red;outline:3px double blue">'),{},error,nil,nil,nil,function() return 'rbxassetid://1' end,nil,nil,live)
	layout.arrange(tree,200,0,0,function() return true end)
	assert(tree.Children[1].InsetEdges[1].Position[1] == 6 and tree.Children[1].OuterHeight == 32)
	assert(tree.ImageItems[1].BorderEdges[1].Position[1] == 4 and tree.ImageItems[1].Outline.Edges[1].Position[1] == 3)
	local nativeTree=treeRenderer.build(Parser.parse('<div style="height:100px;background:#dfcff2;border:3px solid #6d3bb2;border-radius:34px 8px 28px 15px"></div>'),{},error,nil,nil,nil,nil,nil,nil,live)
	layout.arrange(nativeTree,240,0,0,function() return true end)
	local nativeBox=nativeTree.Children[1]
	assert(nativeBox.NativeCornerRadii and not nativeBox.RadiusRenderer and not nativeBox.InsetEdges)
	assert(nativeBox.Corner.TopLeftRadius.Offset==34 and nativeBox.Corner.TopRightRadius.Offset==8
		and nativeBox.Corner.BottomRightRadius.Offset==28 and nativeBox.Corner.BottomLeftRadius.Offset==15,
		'native UICorner receives all four CSS corner values')
	live:Destroy()
	-- A transparent link still owns its rounded border. No background fill is
	-- needed to draw a circle/ellipse, nor may a clipping mask fill its center.
	local transparent=Corners.new(error,createImage)
	local transparentTree=treeRenderer.build(Parser.parse('<a id="round" href="#" style="display:inline-flex;justify-content:center;align-items:center;width:35px;height:35px;box-sizing:border-box;border:1px solid #9aa88f;border-radius:50%;color:black">↗</a>'),{},error,nil,nil,nil,nil,
		'#round:hover{border-color:red!important}',nil,transparent)
	layout.arrange(transparentTree,200,0,0,function()return true end)
	local round
	for node,box in transparentTree.NodeBoxes do if node.Attributes and node.Attributes.id=='round' then round=box;break end end
	assert(round,'Atomic inline-flex link owns a retained layout box')
	assert(round.Style.Background==nil and round.OuterWidth==35 and round.OuterHeight==35)
	assert(round.ResolvedBorderRadii[1][1]==17.5 and round.ResolvedBorderRadii[1][2]==17.5)
	assert(round.RasterBorderGui and round.RasterBorderGui.Visible,'Transparent percentage circle paints its border')
	for index=1,4 do assert(round.InsetEdges[index].Visible==false,'The circle has no rectangular edge strips') end
	local function atlasPixel(gui,x,y)
		local image=gui.ImageContent
		local row=gui.ImageRectOffset.Y
		local at=((row+y)*image.Size.X+gui.ImageRectOffset.X+x)*4
		return buffer.readu8(image.Pixels,at),buffer.readu8(image.Pixels,at+1),buffer.readu8(image.Pixels,at+2),buffer.readu8(image.Pixels,at+3)
	end
	local _,_,_,center=atlasPixel(round.RasterBorderGui,17,17)
	local _,_,_,outside=atlasPixel(round.RasterBorderGui,0,0)
	local _,_,_,top=atlasPixel(round.RasterBorderGui,17,0)
	assert(center==0 and outside==0 and top>200,'Circle center/corners remain transparent while the rim is painted')
	local nativeBorder=round.RasterBorderGui
	local initialWrites=writes
	assert(transparentTree:SetCSSState('hover',round.Node),'Circle border color changes on hover')
	assert(writes==initialWrites+1 and round.RasterBorderGui==nativeBorder,'Mutable border color refreshes the retained raster border')
	local r,g,b,a=atlasPixel(nativeBorder,17,0)
	assert(r==255 and g==0 and b==0 and a>200,'Hover changes the raster rim to red')
	transparentTree:SetCSSState('hover',nil)
	local retainedWrites=writes
	layout.arrange(transparentTree,200,0,0,function()return true end)
	assert(writes==retainedWrites,'An unchanged rounded border reuses its image')
	local ellipseStyle=style('border:2px solid blue;border-radius:50%;overflow:hidden')
	local ellipse={Factory=factory,Gui={Parent={BackgroundTransparency=0,BackgroundColor3=Color3.new(1,1,1)}}}
	assert(transparent:DrawRadius(ellipse,ellipseStyle,60,30))
	assert(ellipse.ResolvedBorderRadii[1][1]==30 and ellipse.ResolvedBorderRadii[1][2]==15)
	local mask=masks[#masks]
	local _,_,_,maskCenter=atlasPixel(mask,30,15)
	local _,_,_,maskOutside=atlasPixel(mask,0,0)
	assert(maskCenter==0 and maskOutside==255,'Transparent interiors are inside the ellipse, not part of the outside clip mask')
	local outputTree=treeRenderer.build(Parser.parse('<style>output{display:inline-flex;align-items:center;justify-content:center;width:28px;height:28px;box-sizing:border-box;border:1px solid #aab8a7;border-radius:50%;font-size:11px}output:hover{border-radius:8px;background:rgba(255,0,0,.5);border-color:rgba(0,0,255,.5)}</style><output>0</output>'),{},error,function(font)return font end,nil,nil,nil,nil,nil,transparent)
	layout.arrange(outputTree,200,0,0,function()return true end)
	local output=outputTree.Controls[1].Item
	local outputBox=output.OutputBox
	assert(outputBox.RasterBorderGui and outputBox.RasterBorderGui.Visible,'Transparent output paints a percentage circle')
	local outputBorder=outputBox.RasterBorderGui
	local _,_,_,outputCenter=atlasPixel(outputBorder,14,14)
	local _,_,_,outputRim=atlasPixel(outputBorder,14,0)
	assert(outputCenter==0 and outputRim>200 and output.Label.TextXAlignment==Enum.TextXAlignment.Center,'Output center stays clear and its text is centered')
	local circleWrites=writes
	assert(outputTree:SetCSSState('hover',output.Control.Node))
	layout.arrange(outputTree,200,0,0,function()return true end)
	assert(not outputBorder.Visible and not output.Style.ResolvedBorderRadii and not outputBox.InsetEdges,'Absolute circular corners switch to the native border path without a duplicate raster border')
	assert(output.Corner.CornerRadius.Offset==8 and output.BoxGui.BackgroundTransparency==.5,'Output native radius and authored alpha are preserved')
	assert(writes==circleWrites,'A native output radius does not allocate or upload a raster')
	outputTree:SetCSSState('hover',nil);layout.arrange(outputTree,200,0,0,function()return true end)
	assert(outputBox.RasterBorderGui==outputBorder and outputBorder.Visible,'Returning to a percentage circle retains the existing border object')
	local emptyWrites=writes
	assert(not transparent:DrawRadius({Factory=factory,Gui={}},style('border-radius:50%'),28,28)and writes==emptyWrites,'A transparent borderless box needs no raster image')
	transparent:Destroy()
	local packed=Corners.new(error,createImage)
	local packedStyle=style('background:rgba(0,128,0,.5);border:2px solid blue;border-radius:40% / 30%;overflow:hidden')
	local packedBox={Factory=factory,Gui={Parent={BackgroundTransparency=0,BackgroundColor3=Color3.new(1,1,1)}}}
	assert(packed:DrawRadius(packedBox,packedStyle,512,512))
	local packedBorder=packedBox.RasterBorderGui;local packedMask=masks[#masks]
	assert(packedBorder.ImageContent.Size.X==1024 and packedBorder.ImageContent.Size.Y==1024
		and packedBorder.ImageRectSize.X==512 and packedBorder.ImageRectSize.Y==512,
		'A tall three-plane surface packs without losing its existing per-plane resolution')
	local _,_,packedBlue,packedRim=atlasPixel(packedBorder,256,0)
	local _,_,_,packedCenter=atlasPixel(packedBorder,256,256)
	local _,_,_,packedMaskCenter=atlasPixel(packedMask,256,256)
	local _,_,_,packedMaskOutside=atlasPixel(packedMask,0,0)
	assert(packedBlue==255 and packedRim==255 and packedCenter==0 and packedMaskCenter==0 and packedMaskOutside==255,
		'Packed mask/border planes retain their distinct transparent centers and painted edges')
	local packedWrites=writes;assert(packed:DrawRadius(packedBox,packedStyle,512,512)and writes==packedWrites,
		'An unchanged packed surface is reused')
	assert(packed:DrawRadius(packedBox,packedStyle,80,512))
	assert(packedBorder.ImageContent.Size.X==240 and packedBorder.ImageContent.Size.Y==512
		and packedBorder.ImageRectOffset.X==160 and packedMask.ImageRectOffset.X==80,
		'A narrow tall surface packs all three planes horizontally within the image limit')
	local _,_,_,tallCenter=atlasPixel(packedMask,40,256);local _,_,_,tallOutside=atlasPixel(packedMask,0,0)
	assert(tallCenter==0 and tallOutside==255)
	assert(packed:DrawRadius(packedBox,packedStyle,80,100))
	assert(packedBorder.ImageContent.Size.X==80 and packedBorder.ImageContent.Size.Y==300
		and packedBorder.ImageRectOffset.X==0 and packedBorder.ImageRectOffset.Y==200,
		'Resize back to a small box restores the compact vertical atlas')
	packed:Destroy()
	local cappedNotices = 0
	local capped = Corners.new(function() cappedNotices += 1 end,createImage)
	local capStart = images
	for index = 1,65 do
		local e = BorderBox.create(s,{},factory,capped)
		BorderBox.arrange(e,s,100,60)
		assert(e[1].Position[1] == (if index <= 64 then 12 else 0))
	end
	assert(images-capStart == 64 and cappedNotices == 1)
	capped:Destroy()
	print('Border corners: diagonal ownership/alpha, relief, patterns, corner shapes, atlas bounds, resize reuse, fallback, cleanup, blocks/images/outlines passed')
end
