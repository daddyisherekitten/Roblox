--!strict
return function(Parser,DOM,State,Model,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout)
	local document=Parser.parse([[<form id="f"><fieldset disabled>
		<legend style="display:none"><span><input id="exempt" name="exempt" value="yes"></span><input id="own" disabled></legend>
		<input id="blocked" name="blocked" required><legend><input id="second"></legend>
		<fieldset><legend><input id="nested"></legend></fieldset>
	</fieldset><fieldset disabled><legend><fieldset disabled><legend><input id="twice"></legend><input id="inner"></fieldset></legend></fieldset>
	<input id="outside" name="outside" value="ok"></form>]])
	local controls,byId={},{}
	for id,disabled in {exempt=false,own=true,blocked=true,second=true,nested=true,twice=false,inner=true,outside=false} do
		local c=State.create(DOM.findById(document,id)); byId[id]=c; table.insert(controls,c)
		assert(c.Disabled == disabled,'Disabled fieldset/first legend: '..id)
	end
	local events={Emit=function() return {DefaultPrevented=false} end}
	local model=Model.new(document,controls,events,function() end)
	model:SetValue(byId.blocked,'no',true); assert(byId.blocked.Value == '')
	model:SetValue(byId.exempt,'allowed',true); assert(byId.exempt.Value == 'allowed')
	local data=model:Data(DOM.findById(document,'f'))
	assert(#data == 2,'Disabled fields must be excluded from form data')
	for _,entry in data do assert(entry.Name == 'exempt' or entry.Name == 'outside') end
	model:Destroy()
	local created=0
	local factory={create=function(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		created+=1
		local gui=table.clone(props); gui.Parent=parent; return gui
	end,modifier=function(_,_,props) return table.clone(props) end}
	local overrides={['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	local function build(html)
		local tree=loadRenderTree(factory).build(Parser.parse(html),{},error,function(font) return font end)
		local boxes={}
		local function visit(box)
			if box.Node and box.Node.Attributes and box.Node.Attributes.id then boxes[box.Node.Attributes.id]=box end
			for _,child in box.Children or {} do visit(child) end
		end
		visit(tree)
		return tree,boxes
	end
	local tree,boxes=build([[<fieldset id="group" style="font-family:Roboto; font-size:20px; min-width:0">
		<div id="before" style="height:10px"></div><legend id="title">Options</legend>
		<div id="content" style="height:30px"></div><legend id="other">Second</legend>
	</fieldset><div id="after" style="height:5px"></div>]])
	blocks.arrange(tree,300,0,0,function() return true end)
	local group,title=boxes.group,boxes.title
	assert(group.Legend == title and #group.FlowChildren == 3)
	assert(group.Style.Padding[1] == 7 and group.Style.Padding[2] == 15 and group.Style.Padding[3] == 12.5)
	assert(group.Style.Margin[4] == 2 and group.Style.BorderSize == 2 and group.Style.BorderStyle == 'groove')
	assert(title.OuterWidth == 39 and title.LayoutX == 17 and title.LayoutY == 0)
	assert(boxes.before.LayoutY == title.OuterHeight+7,'Legend must precede content even when later in the DOM')
	assert(boxes.content.LayoutY == boxes.before.LayoutY+10 and boxes.other.LayoutY >= boxes.content.LayoutY+30)
	assert(group.LegendGap.Left == 17 and group.LegendGap.Right == 56 and group.LegendGap.Top == (title.OuterHeight-2)/2)
	local regions=group.InsetEdges.FieldsetRegions
	assert(regions[1].Clip.Size[1] == 17 and regions[2].Clip.Position[1] == 56)
	assert(regions[3].Clip.Position[2] == group.LegendGap.Top+2,'Only the border below the legend gap stays visible')
	for _,region in regions do assert(region.Clip.ClipsDescendants and region.Clip.BackgroundTransparency == 1) end
	local count=created
	blocks.arrange(tree,180,0,0,function() return true end)
	assert(group.OuterWidth == 176 and title.OuterWidth == 39 and created == count,'Resizing must reuse border/legend objects')
	local flex,fb=build([[<fieldset id="flex" style="display:flex; padding:0; gap:10px; min-width:0">
		<legend id="legend" style="display:inline">Label</legend><div id="one" style="width:20px; height:10px"></div><div id="two" style="width:20px; height:10px"></div>
	</fieldset>]])
	blocks.arrange(flex,200,0,0,function() return true end)
	assert(fb.flex.Legend == fb.legend and #fb.flex.FlowChildren == 2)
	assert(fb.one.LayoutY >= fb.legend.OuterHeight and fb.two.LayoutX-fb.one.LayoutX == 30,'Legend is not a flex item')
	assert(fb.flex.Style.Padding[1] == 0 and fb.flex.OuterHeight == fb.legend.OuterHeight+12)
	local fixed,fx=build([[<fieldset id="fixed" style="height:60px; box-sizing:border-box; padding:0; border:8px solid red"><legend id="small" style="height:2px; font-size:1px"></legend><div style="height:5px"></div></fieldset>
	<fieldset id="hidden"><legend style="display:none">Hidden</legend><legend id="visible">Visible</legend></fieldset>
	<fieldset id="none"><legend style="position:absolute">Absolute</legend></fieldset>]])
	blocks.arrange(fixed,300,0,0,function() return true end)
	assert(fx.fixed.OuterHeight == 60 and fx.small.LayoutY == 3)
	assert(fx.hidden.Legend == fx.visible and fx.none.Legend == nil)
	assert(fx.none.InsetEdges.FieldsetRegions[1].Clip.Size[1] == fx.none.OuterWidth)
	local wrapped,wb=build([[<fieldset id="wrap" style="width:70px; min-width:0; padding-left:5px; font-size:20px"><legend id="long">Several words wrap here</legend><div id="body" style="height:10px"></div></fieldset>]])
	blocks.arrange(wrapped,300,0,0,function() return true end)
	assert(wb.wrap.Style.Padding[4] == 5 and wb.wrap.Style.Padding[2] == 15,'Author longhand must preserve other em defaults')
	assert(wb.long.OuterWidth <= 70 and wb.long.OuterHeight > title.OuterHeight)
	assert(wb.body.LayoutY == wb.long.OuterHeight+7,'Multiline legends reserve their full height')
	local dirty,db=build([[<fieldset id="g" style="min-width:0"><legend>Title</legend><output id="out">Old</output></fieldset><div id="below">Below</div>]])
	Dirty.begin(dirty); blocks.arrange(dirty,200,0,0,function() return true end); Dirty.finish(dirty,true)
	local legendY=db.g.Legend.LayoutY
	local c=dirty.Controls[1]; c.Value='Changed output with several words that wraps'; c.Item.Text=c.Value
	local stats=Dirty.begin(dirty,{[c.Item]=true}); blocks.arrange(dirty,200,0,0,function() return true end); Dirty.finish(dirty,true)
	assert(stats.Mode == 'partial' and db.g.Legend.LayoutY == legendY and db.below.LayoutY >= db.g.OuterHeight)
	local height,below=db.g.OuterHeight,db.below.LayoutY
	Dirty.begin(dirty); blocks.arrange(dirty,200,0,0,function() return true end); Dirty.finish(dirty,true)
	assert(db.g.OuterHeight == height and db.below.LayoutY == below,'Partial and full fieldset layout must agree')
	print('Fieldsets: legend gap/flow/flex/sizing, border reuse, disabled ancestry/legend exceptions, form data and dirty layout passed')
end
