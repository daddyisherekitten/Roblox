--!strict
return function(Parser, loadRenderTree, loadWordLayout, loadBlockLayout)
	local renderer=loadRenderTree({create=function(_,parent,props)local gui=table.clone(props);gui.Parent=parent;return gui end,modifier=function(_,_,props)return table.clone(props) end})
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local function near(actual,expected,label)assert(math.abs(actual-expected)<.001,(label or '')..': '..tostring(actual)..' != '..tostring(expected))end
	local function image(css,minimum,maximum)
		local tree=renderer.build(Parser.parse('<img width="1000" height="800" src="image.png" style="display:block;'..css..'">'),{},error,nil,nil,nil,function()return 'rbxassetid://1' end)
		local box=tree.Children[1]
		near(layout.naturalWidth(box,300,function()return true end,true),minimum)
		near(layout.naturalWidth(box,300,function()return true end,false),maximum)
		return tree,box
	end
	image('width:100%;height:auto',0,1000)
	image('width:50%;height:auto',0,1000)
	image('max-width:100%;height:auto',0,1000)
	image('width:calc(20px + 100%);height:auto',20,1000)
	image('width:100%;min-width:80px;height:auto',80,1000)
	image('width:100%;min-width:40%;height:auto',0,1000)
	image('width:100%;min-height:80px;height:auto',100,1000)
	image('width:100%;aspect-ratio:2;min-height:80px;height:auto',160,1000)
	image('width:100%;min-height:80px;height:auto;box-sizing:border-box;padding:10px;border:2px solid',94,1024)
	image('width:100%;aspect-ratio:2;min-height:80px;height:auto;box-sizing:border-box;padding:10px;border:2px solid',160,1024)
	image('width:200px;height:auto',200,200)
	image('height:auto',1000,1000)
	local tree,box=image('width:100%;height:auto',0,1000)
	local originalWidth=box.Style.Width
	for _,width in {800,300,150,600,300} do
		layout.arrange(tree,width,0,0,function()return true end)
		near(box.OuterWidth,width);near(box.OuterHeight,width*.8)
		assert(box.Style.Width==originalWidth,'Intrinsic probes preserve the authored percentage')
	end
	-- Independent Chromium probes of the actual percentage/min-height
	-- combination: the ratio must not force the first Grid track to 345px.
	for _,entry in {
		{'1fr 1fr','width:100%;height:100%;min-height:230px',181.5,181.5},
		{'min-content 1fr','width:100%;height:100%;min-height:230px',0,0},
		{'minmax(0,1fr) 1fr','width:100%;height:100%;min-height:230px',181.5,181.5},
		{'1fr 1fr','width:100%;height:100%;min-height:230px;min-width:210px',210,210},
		{'1fr 1fr','max-width:100%;height:100%;min-height:230px',181.5,181.5},
		{'1fr 1fr','width:calc(100% + 20px);height:100%;min-height:230px',181.5,201.5},
		{'1fr 1fr','width:100%;height:100%;min-height:230px;overflow:hidden',181.5,181.5},
		{'1fr 1fr','width:100%;height:auto;min-height:230px',181.5,181.5},
		{'1fr 1fr','width:100%;height:230px;min-height:230px',181.5,181.5},
		{'min-content 1fr','width:100%;height:auto;min-height:230px',0,0},
		{'min-content 1fr','width:100%;height:230px;min-height:230px',0,0},
	}do
		local document=Parser.parse('<div style="display:grid;width:385px;grid-template-columns:'..entry[1]..';gap:22px;align-items:center"><img src="image.png" style="'..entry[2]..'"><div>Small words with several lines.</div></div>')
		local gridTree=renderer.build(document,{},error,nil,nil,nil,function()return 'rbxassetid://1'end)
		gridTree.ImageItems[1].IntrinsicWidth,gridTree.ImageItems[1].IntrinsicHeight=480,320
		layout.arrange(gridTree,600,0,0,function()return true end)
		local grid=gridTree.Children[1];local imageBox,textBox=grid.Children[1],grid.Children[2]
		near(grid.GridLayout.Columns.Tracks[1].Size,entry[3]);near(imageBox.OuterWidth,entry[4])
		near(textBox.LayoutX,entry[3]+22);near(textBox.OuterWidth,363-entry[3])
		near(imageBox.OuterHeight,230,entry[2]);near(grid.OuterHeight,230,entry[2])
		local imageGui,textGui=imageBox.Gui,textBox.Gui
		for _,width in {480,385,600,385}do
			grid.Style.Width={Value=width,Percent=false}
			layout.arrange(gridTree,600,0,0,function()return true end)
			assert(imageBox.Gui==imageGui and textBox.Gui==textGui,'Percentage Grid images resize without replacing retained surfaces')
		end
		near(grid.GridLayout.Columns.Tracks[1].Size,entry[3]);near(imageBox.OuterWidth,entry[4])
	end
	print('Responsive images: cyclic min/max-content, calc, explicit and transferred minimums, borders, natural sizes, aspect ratio and repeated resize passed')
end
