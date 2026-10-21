--!strict
return function(Parser,Node,loadRenderTree)
	local allocations={};local factory={}
	function factory.create(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName,gui.Parent=class,parent;gui.Visible=properties.Visible~=false
		function gui:Destroy()assert(not self.Destroyed);self.Destroyed=true;self.Parent=nil end
		table.insert(allocations,gui);return gui
	end
	factory.modifier=factory.create
	local renderer=loadRenderTree(factory);local diagnostics={}
	local document=Parser.parseDocument('<!doctype html><body><div><img id="photo" src="photo.png" alt="Original" width="100" height="50"><img id="missing" src="unmapped.png" alt="Not loaded"></div></body>')
	local sourceSVG=Node.findElement(Parser.parse('<svg width="200" height="100" viewBox="0 0 20 10"></svg>'),function(n)return n.Name=="svg"end)
	local root={AbsoluteSize={X=600,Y=400}}
	local tree=renderer.build(document,root,function(message)table.insert(diagnostics,message)end,function(font)return font end,nil,nil,
		function(src)return if src=="photo.png"then"rbxassetid://123"elseif src=="other.png"then"rbxassetid://456"else nil end,
		"",nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,function(src)return if src=="drawing.svg"then sourceSVG else nil end)
	local photo=Node.findElement(document,function(node)return node.Attributes and node.Attributes.id=="photo"end)
	local item=assert(tree:FindImageItem(photo));local gui,imageGui,box=item.Gui,item.ImageGui,tree.NodeBoxes[photo]
	assert(#tree.ImageItems==1 and #tree.SVGItems==0)
	local beforeCalls=0
	local function before(current,kind)
		beforeCalls+=1;assert(current==item)
		if beforeCalls==1 then assert(kind=="Image"and current.Source=="rbxassetid://123")
		elseif beforeCalls==2 then assert(kind=="SVG"and current.SVG==sourceSVG)
		elseif beforeCalls==3 then assert(kind=="Image"and current.Source=="rbxassetid://456")end
	end
	photo.Attributes.src="drawing.svg"
	local updated,oldKind,changed,geometry=tree:RefreshImageResource(photo,before)
	assert(updated==item and oldKind=="Image"and changed and geometry and item.SVG==sourceSVG and item.SVGExternal)
	assert(item.IntrinsicWidth==200 and item.IntrinsicHeight==100 and #tree.ImageItems==0 and tree.SVGItems[1]==item)
	assert(item.Gui==gui and item.ImageGui==imageGui and tree.NodeBoxes[photo]==box,"Source changes retain the GUI and CSS box")
	local uploaded={};item.ImageGui.ImageContent=uploaded
	photo.Attributes.width="80";photo.Attributes.alt="Updated"
	_,_,changed,geometry=tree:RefreshImageResource(photo,before)
	assert(not changed and geometry and beforeCalls==1 and item.AttributeWidth==80 and item.AltGui.Text=="Updated")
	assert(item.ImageGui.ImageContent==uploaded,"Stable-source dimension or alt changes retain the uploaded SVG texture")
	photo.Attributes.alt="Hidden replacement description";_,_,changed,geometry=tree:RefreshImageResource(photo,before)
	assert(not changed and not geometry and item.ImageGui.ImageContent==uploaded,"A loaded image's invisible alt change does not request layout or discard its texture")
	photo.Attributes.src="other.png";tree:RefreshImageResource(photo,before)
	assert(beforeCalls==2 and item.Source=="rbxassetid://456"and not item.SVG and #tree.SVGItems==0 and tree.ImageItems[1]==item)
	assert(item.IntrinsicWidth==nil and item.Gui==gui and item.ImageGui==imageGui)
	photo.Attributes.src="missing-again.png";photo.Attributes.alt=""
	tree:RefreshImageResource(photo,before)
	assert(beforeCalls==3 and not item.Source and not item.SVG and item.EmptyAlt and not item.FallbackGui.Visible)
	photo.Attributes.alt="A new description";tree:RefreshImageResource(photo,before)
	assert(beforeCalls==3 and item.TextFallback and item.FallbackGui.Visible and item.AltGui.Text=="A new description")
	local missing=Node.findElement(document,function(node)return node.Attributes and node.Attributes.id=="missing"end)
	local emptyItem=assert(tree:FindImageItem(missing));assert(not emptyItem.ImageGui)
	local emptyGui=emptyItem.Gui;missing.Attributes.src="photo.png";tree:RefreshImageResource(missing)
	assert(emptyItem.Gui==emptyGui and emptyItem.ImageGui and emptyItem.ImageGui.Image=="rbxassetid://123","Broken-to-loaded creates a missing paint surface, retaining its box")
	assert(not emptyItem.TextFallback and not emptyItem.FallbackGui.Visible)
	missing.ImageResourceState={Status='error'}
	local _,_,sourceChanged,geometry=tree:RefreshImageResource(missing)
	assert(not sourceChanged and geometry and emptyItem.TextFallback and emptyItem.ErrorGui.Visible and not emptyItem.ImageGui.Visible,
		'A host decode failure changes mapped-image fallback geometry even when its source stays the same')
	local blur={Visible=true};emptyItem.BlurGui=blur;emptyItem.BlurReady=true
	require('Rendering/ImageBox').updateFallback(emptyItem)
	assert(not blur.Visible and not emptyItem.ImageGui.Visible,'Failed requests cannot show stale decoded raster/filter surfaces')
	emptyItem.BlurGui=nil;emptyItem.BlurReady=nil
	missing.ImageResourceState.Status='loaded';_,_,sourceChanged,geometry=tree:RefreshImageResource(missing)
	assert(not sourceChanged and geometry and not emptyItem.TextFallback and not emptyItem.ErrorGui.Visible and emptyItem.ImageGui.Visible,'Same-source recovery retains and restores the native paint surface')
	do
		local doc=Parser.parseDocument('<picture><source id="s" media="(height >= 500px)" srcset="photo.png 400w" sizes="200px" width="90"><img id="i" src="other.png" width="60" height="30"></picture>')
		local i,s=Node.findById(doc,'i'),Node.findById(doc,'s');local frame={AbsoluteSize={X=800,Y=600}}
		local current=renderer.build(doc,frame,error,function(font)return font end,nil,nil,function(raw)return if raw=='photo.png'then'rbxassetid://123'else'rbxassetid://456'end,'',nil,nil,nil,nil,nil,nil,nil,{Resolution=2})
		local item=assert(current:FindImageItem(i));local outer,paint,box=item.Gui,item.ImageGui,current.NodeBoxes[i]
		assert(item.SelectedSource=='photo.png'and item.SourceDensity==2 and item.AttributeWidth==90 and item.AttributeHeight==nil,'Renderer uses height media, DPR and selected SOURCE dimension-attribute owner')
		item.PixelWidth,item.PixelHeight=200,100;item.IntrinsicWidth,item.IntrinsicHeight=100,50;local uploaded={};paint.ImageContent=uploaded
		s.Attributes.sizes='400px';local _,_,changed,geometry=current:RefreshImageResource(i)
		assert(not changed and geometry and item.SourceDensity==1 and item.IntrinsicWidth==200 and item.IntrinsicHeight==100,'Retained renderer rescales unchanged resource intrinsic geometry')
		assert(item.Gui==outer and item.ImageGui==paint and current.NodeBoxes[i]==box and paint.ImageContent==uploaded,'Density-only refresh preserves all retained boxes and paint content')
		i.ImageResourceState={Raw='other.png',SourceDensity=.5,Status='loaded',PixelWidth=200,PixelHeight=100,Width=400,Height=200}
		current:RefreshImageResource(i)
		assert(item.SelectedSource=='other.png'and item.SourceDensity==.5 and item.Source=='rbxassetid://456','Canonical request owner candidate takes precedence over an independently sampled viewport')
	end
	do
		local doc=Parser.parseDocument('<style>img{width:140px;height:70px}</style><picture><source id="s" srcset="photo.png" width="90" height="80"><img id="i" src="other.png" width="60" height="30"></picture>')
		local current=renderer.build(doc,{AbsoluteSize={X=800,Y=600}},error,function(font)return font end,nil,nil,function()return'rbxassetid://123'end)
		local i,s=Node.findById(doc,'i'),Node.findById(doc,'s');local item=assert(current:FindImageItem(i))
		assert(item.Style.Width.Value==140 and item.Style.Height.Value==70,'Author CSS overrides selected SOURCE dimension hints in the existing cascade')
		s.Attributes.width='120';s.Attributes.height='100';current:RefreshImageResource(i)
		assert(item.AttributeWidth==120 and item.AttributeHeight==100 and item.Style.Width.Value==140 and item.Style.Height.Value==70,'SOURCE dimension recascade retains author CSS precedence')
		local reverted=Parser.parseDocument('<picture><source srcset="photo.png" width="90" height="80"><img id="i" src="other.png" style="width:revert;height:revert"></picture>')
		local revertedTree=renderer.build(reverted,{AbsoluteSize={X=800,Y=600}},error,function(font)return font end,nil,nil,function()return'rbxassetid://123'end)
		local revertedItem=assert(revertedTree:FindImageItem(Node.findById(reverted,'i')))
		assert(not revertedItem.Style.Width and not revertedItem.Style.Height,'Author-origin revert skips selected SOURCE presentational hints as it skips IMG hints')
	end
	print("Image resource rendering: native/SVG/broken source changes, density/environment and selected SOURCE dimensions retain boxes and unchanged textures")
end
