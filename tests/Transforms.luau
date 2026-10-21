--!strict
return function(Parser: any,Style: any,Transform2D: any,loadRenderTree: any,loadWordLayout: any,loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local parent={Font="Roboto",FontSize=16,RootFontSize=16,Color=Color3.new(0,0,0),ColorAlpha=1,ViewportWidth=800,ViewportHeight=600}
	local function resolve(css: string,warn: any?): any return Style.resolve(fixtureElement("div",{style=css}),parent,warn or error) end
	local style=resolve("transform:translate(10px,25%) rotate(90deg) scale(1.5);transform-origin:left top")
	assert(#style.Transform==3 and style.TransformOrigin.X.Value==0 and style.TransformOrigin.Y.Value==0)
	local result=Transform2D.resolve(style.Transform,100,40)
	assert(math.abs(result.X-10)<.001 and math.abs(result.Y-10)<.001 and math.abs(result.Scale-1.5)<.001 and math.abs(result.Rotation-90)<.001)
	local individual=resolve("translate:10px 25%;rotate:90deg;scale:1.5;transform:translateX(4px)")
	local operations=Transform2D.operations(individual)
	assert(#operations==4 and operations[1].Kind=="translate" and operations[2].Kind=="rotate" and operations[3].Kind=="scale")
	local individualResult=Transform2D.resolve(operations,100,40)
	assert(math.abs(individualResult.X-10)<.001 and math.abs(individualResult.Y-16)<.001 and math.abs(individualResult.Scale-1.5)<.001 and math.abs(individualResult.Rotation-90)<.001)
	assert(resolve("translate:8px;translate:none;rotate:20deg;rotate:none;scale:2;scale:none").Translate==nil)
	local warnings=0
	local invalid=resolve("transform:translateX(4px);transform:scale(2,bad)",function()warnings+=1 end)
	assert(#invalid.Transform==1 and warnings==1,"Invalid transform declarations preserve the earlier winner")
	for _,value in {'0 0 20%','0 0 calc(10%)','0 0 calc(10px + 1%)','0 0 min(10px, 20%)'}do
		local errors=0;local result=resolve('transform-origin:20px 30px;transform-origin:'..value,function()errors+=1 end)
		assert(errors==1 and result.TransformOrigin.X.Value==20 and result.TransformOrigin.Y.Value==30,'The Z origin requires a length even inside math: '..value)
	end

	local modifiers={}
	local renderer=loadRenderTree({
		create=function(class: string,owner: any,props: any)local object=table.clone(props);object.ClassName=class;object.Parent=owner;return object end,
		modifier=function(class: string,owner: any,props: any)local object=table.clone(props);object.ClassName=class;object.Parent=owner;table.insert(modifiers,object);return object end,
	})
	local layoutOverrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=#text*8,Y=size} end}}
	layoutOverrides["Layout/WordLayout"]=loadWordLayout(layoutOverrides)
	local layout=loadBlockLayout(layoutOverrides)
	local document=Parser.parse('<style>#card:hover{transform:translateX(20px) rotate(30deg) scale(1.25)}</style><div id="card" style="width:100px;height:40px;transform-origin:left top"></div>')
	local tree=renderer.build(document,{},error)
	layout.arrange(tree,300,0,0,function()return true end)
	local box=tree.Children[1]
	local function visibleTopLeft(item: any): (number,number)
		local gui=item.Gui;local cx,cy=item.OuterWidth/2,item.OuterHeight/2
		local angle=math.rad(gui.Rotation or 0);local c,s=math.cos(angle),math.sin(angle)
		local scale=if item.TransformScale then item.TransformScale.Scale else 1
		return gui.Position[1]+scale*(cx-gui.AnchorPoint.X*item.OuterWidth-c*cx+s*cy),
			gui.Position[2]+scale*(cy-gui.AnchorPoint.Y*item.OuterHeight-s*cx-c*cy)
	end
	assert(box.Gui.Position[1]==0 and (box.Gui.Rotation==nil or box.Gui.Rotation==0) and box.TransformScale==nil)
	assert(tree:SetCSSState("hover",box.Node))
	layout.arrange(tree,300,0,0,function()return true end)
	local paintedX,paintedY=visibleTopLeft(box)
	assert(math.abs(paintedX-20)<.001 and math.abs(paintedY)<.001 and math.abs(box.Gui.Rotation-30)<.001,"CSS left-top rotation must keep the visible origin at its translated position")
	assert(box.TransformScale and math.abs(box.TransformScale.Scale-1.25)<.001 and box.TransformScale.Parent==box.Gui)
	assert(tree:SetCSSState("hover",nil));layout.arrange(tree,300,0,0,function()return true end)
	assert(box.Gui.Position[1]==0 and box.Gui.Rotation==0 and box.TransformScale.Scale==1,"Leaving restores the retained GUI objects")
	local individualDocument=Parser.parse('<style>#individual:hover{translate:18px 6px;rotate:25deg;scale:1.2}</style><div id="individual" style="width:100px;height:40px;transform-origin:left top"></div>')
	local individualTree=renderer.build(individualDocument,{},error);layout.arrange(individualTree,300,0,0,function()return true end)
	local individualBox=individualTree.Children[1]
	assert(individualTree:SetCSSState("hover",individualBox.Node));layout.arrange(individualTree,300,0,0,function()return true end)
	local individualX,individualY=visibleTopLeft(individualBox)
	assert(math.abs(individualX-18)<.001 and math.abs(individualY-6)<.001 and math.abs(individualBox.Gui.Rotation-25)<.001)
	assert(individualBox.TransformScale and math.abs(individualBox.TransformScale.Scale-1.2)<.001)
	local imageDocument=Parser.parse('<style>a:hover img{transform:scale(1.04)}</style><a href="#"><img src="house.png" width="200" height="120" style="display:block"></a>')
	local imageTree=renderer.build(imageDocument,{},error,nil,nil,nil,function()return "rbxassetid://1" end)
	layout.arrange(imageTree,300,0,0,function()return true end)
	local imageBox
	local function findImage(box)
		if box.Kind=='BlockImage' and box.Node.Name=='img' then imageBox=box end
		for _,child in box.Children or {} do findImage(child) end
	end
	findImage(imageTree);assert(imageBox)
	local imageChanged,imageReflow=imageTree:SetCSSState('hover',imageTree.Links[1])
	assert(imageChanged and not imageReflow,'Image hover transforms do not change flow dimensions')
	layout.arrange(imageTree,300,0,0,function()return true end)
	assert(imageBox.TransformScale and math.abs(imageBox.TransformScale.Scale-1.04)<.001,'Block images receive a working scale modifier')
	local scaleModifier=imageBox.TransformScale
	imageTree:SetCSSState('hover',nil)
	layout.arrange(imageTree,300,0,0,function()return true end)
	assert(imageBox.TransformScale==scaleModifier and scaleModifier.Scale==1,'Image hover reset reuses its scale modifier')
	print("CSS transforms: parsing, ordered composition, origin, layout-neutral paint, live state, block images and scale reuse passed")
end
