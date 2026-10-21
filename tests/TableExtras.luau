--!strict
return function(Parser,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout)
	local created={}
	local factory={create=function(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		local g=table.clone(props); g.Parent=parent; table.insert(created,g); return g
	end,modifier=function(_,_,props) return table.clone(props) end}
	local overrides={['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	local function build(html)
		local doc=Parser.parse('<style>td,th{padding:0}table{border-spacing:0}</style>'..html)
		assert(#doc.Diagnostics == 0)
		local tree=loadRenderTree(factory).build(doc,{},error,function(font) return font end)
		local boxes={}
		local function visit(b)
			if b.Node and b.Node.Attributes and b.Node.Attributes.id then boxes[b.Node.Attributes.id]=b end
			for _,child in b.Children or {} do visit(child) end
		end
		visit(tree); return tree,boxes
	end
	local function layout(tree,width) blocks.arrange(tree,width or 200,0,0,function() return true end) end
	local function near(a,b) assert(math.abs(a-b)<.001,tostring(a)..' != '..tostring(b)) end
	for _,mode in {'separate','collapse'} do
		local tree,b=build('<table id="t" style="width:120px;border:2px solid black;background:red;border-collapse:'..mode..'"><caption id="cap" style="padding:3px;border:1px solid blue;margin:2px 0">Title</caption><tr><td id="cell" style="border:2px solid black">A</td></tr></table><div id="after">After</div>')
		layout(tree)
		assert(#b.t.TableCaptions == 1 and #b.t.TableRows == 1)
		assert(not b.cap.Style.CollapsedBorder and b.cap.Style.BorderSize == 1,'Caption border stays independent of collapsed cell borders')
		near(b.t.TableSurface.Size[2],b.t.TableGridHeight)
		near(b.t.CaptionTop,b.cap.OuterHeight+4)
		near(b.t.OuterHeight,b.t.TableGridHeight+b.t.CaptionTop)
		near(b.after.LayoutY,b.t.OuterHeight)
		near(b.cap.OuterWidth,b.t.OuterWidth)
		assert(b.t.Gui.BackgroundTransparency == 1 and b.t.TableSurface.BackgroundTransparency == 0)
		assert(b.cap.Gui.Parent == b.t.Gui and b.t.TableRows[1].Box.Gui.Parent == b.t.TableSurface)
	end
	local bottom,b=build('<table id="t" style="caption-side:bottom;width:100%"><caption id="c">Caption with multiple words for wrapping</caption><tr><td>A</td></tr></table>')
	layout(bottom,180)
	assert(b.c.Style.CaptionSide == 'bottom'); near(b.c.LayoutY,b.t.TableGridHeight); near(b.t.CaptionTop,0)
	local wide=b.t.OuterHeight; layout(bottom,75); assert(b.t.OuterHeight>wide)
	local minimum,m=build('<table id="t"><caption id="c">LongUnbreakableTitle</caption><tr><td id="a">A</td><td>B</td></tr></table>')
	layout(minimum); near(m.t.OuterWidth,#'LongUnbreakableTitle'*5); near(m.a.OuterWidth,m.t.OuterWidth/2)
	local nested,n=build('<table id="t"><caption>Outer</caption><tr><td><table id="inner"><caption style="caption-side:bottom">Inner</caption><tr><td>A</td></tr></table></td></tr></table>')
	layout(nested); assert(#n.t.TableCaptions==1 and #n.inner.TableCaptions==1); assert(n.t.OuterHeight>n.inner.OuterHeight)
	local alone,a=build('<table id="t"><caption id="c">Caption only</caption></table>')
	layout(alone); near(a.t.OuterHeight,a.c.OuterHeight); near(a.t.TableGridHeight,0)
	local hidden,h=build('<table id="t"><caption style="display:none">Hidden</caption><tr><td>A</td></tr></table>')
	layout(hidden); assert(not h.t.TableSurface and #h.t.TableCaptions == 0)
	local layers,l=build('<table id="t" style="border-spacing:3px"><colgroup style="background:red"><col style="background:blue"></colgroup><tbody style="background:green"><tr style="background:rgba(0,0,0,.5)"><td id="span" rowspan="2">A</td><td>X</td></tr><tr style="background:yellow"><td>Y</td></tr></tbody></table>')
	layout(layers)
	local p=l.span.ColumnBackgrounds
	assert(#p==4 and p[3].Name=='RowGroupBackground' and p[4].Name=='RowBackground' and p[4].BackgroundTransparency==.5)
	near(p[4].Size[2],l.span.OuterHeight)
	near(p[4].Position[1],0);near(l.t.TableGroups[1].LayoutX,3)
	assert(l.t.TableGroups[1].Gui.BackgroundTransparency==1 and l.t.TableRows[1].Box.Gui.BackgroundTransparency==1,'Border-spacing gaps keep table background')
	local empty,e=build('<table id="t" style="empty-cells:hide;background:red"><col style="background:blue"><tbody style="background:green"><tr style="background:yellow"><td id="a" style="border:2px solid black;background:white"> \n </td><td id="b">X</td><td id="show" style="empty-cells:show;border:1px solid black"></td></tr><tr id="row"><td id="hidden" style="border:3px dashed red"></td></tr><tr><td id="br"><br></td><td id="block"><div></div></td><td id="pre" style="white-space:pre"> </td><td id="nbsp">&nbsp;</td><td id="none"><span style="display:none">X</span></td></tr></tbody></table>')
	layout(empty)
	assert(e.a.EmptyCellHidden and not e.a.CellBorder.Visible and e.a.Gui.BackgroundTransparency==1)
	for _,layer in e.a.ColumnBackgrounds do assert(layer.Visible,'Empty cells keep the backgrounds of their row/column groups') end
	assert(not e.b.EmptyCellHidden and not e.show.EmptyCellHidden)
	assert(e.hidden.EmptyCellHidden); near(e.row.OuterHeight,0)
	for _,layer in e.hidden.ColumnBackgrounds do assert(not layer.Visible and layer.Size[2]==0,'Zero-height rows must not leak background paint') end
	for _,id in {'br','block','pre','nbsp'} do assert(not e[id].EmptyCellHidden,id) end
	assert(e.none.EmptyCellHidden)
	local reference,ref=build('<table style="empty-cells:hide;background:#fff0ca"><tbody id="body" style="background:#dce6f4"><tr><td>Zellen</td><td id="gap" style="background:white;border:1px solid black"></td><td style="empty-cells:show"></td></tr></tbody></table>')
	layout(reference)
	assert(ref.gap.EmptyCellHidden and not ref.gap.CellBorder.Visible and ref.gap.Gui.BackgroundTransparency==1)
	assert(#ref.gap.ColumnBackgrounds==1 and ref.gap.ColumnBackgrounds[1].Visible)
	assert(ref.gap.ColumnBackgrounds[1].BackgroundColor3==ref.body.Style.Background,'Browser reference keeps the blue tbody color in the unbordered middle cell')
	local allEmpty,ae=build('<table id="t" style="empty-cells:hide"><tr style="height:40px"><td style="border:6px solid red;padding:20px"></td></tr></table><div id="after">After</div>')
	layout(allEmpty); near(ae.t.OuterHeight,0); near(ae.after.LayoutY,0); near(ae.t.LocalBottom,0)
	local mixed,me=build('<table id="t"><tr><td style="empty-cells:hide;height:60px"></td><td>X</td></tr></table>')
	layout(mixed); near(me.t.OuterHeight,60)
	local collapse,c=build('<table style="empty-cells:hide;border-collapse:collapse"><tr style="background:red"><td id="c" style="border:2px solid black;background:blue"></td></tr></table>')
	layout(collapse); assert(not c.c.EmptyCellHidden and c.c.Gui.BackgroundTransparency==0 and c.c.ColumnBackgrounds[1].Visible)
	local dirty,d=build('<table id="t"><caption><output>A</output></caption><tbody style="background:red"><tr><td>A</td></tr></tbody></table><div id="after">After</div>')
	Dirty.begin(dirty); layout(dirty); Dirty.finish(dirty,true)
	local control=dirty.Controls[1]; control.Value='Much longer caption'; control.Item.ControlMeasureKey=nil
	local count=#created
	Dirty.begin(dirty,{[control.Item]=true}); layout(dirty); Dirty.finish(dirty,true)
	local width,height,after=d.t.OuterWidth,d.t.OuterHeight,d.after.LayoutY
	Dirty.begin(dirty); layout(dirty); Dirty.finish(dirty,true)
	near(d.t.OuterWidth,width); near(d.t.OuterHeight,height); near(d.after.LayoutY,after)
	assert(#created==count,'Caption and background GUIs are retained during reflow')
	local scroll,s=build('<table id="t" style="width:120px;height:24px;overflow:auto"><caption id="c">Title</caption><tr><td><div style="height:70px">Tall</div></td></tr></table>')
	layout(scroll); assert(s.t.ScrollY==0 and s.t.TableGridHeight==70,'Table height is a minimum; tall cells expand the grid')
	near(s.t.ScrollGui.Size[2],70); near(s.t.OuterHeight,70+s.c.OuterHeight)
	assert(s.c.Gui.Parent==s.t.Gui,'Caption stays outside the native table scroll viewport')
	local positioned,pb=build('<div style="position:relative"><table id="t"><caption id="c">Title</caption><tr><td id="cell"><div id="abs" style="position:absolute;top:0;left:0;width:4px;height:4px"></div>A</td></tr></table></div>')
	layout(positioned)
	near(pb.abs.Gui.Position[2]+pb.cell.LayoutY+pb.t.TableRows[1].Box.LayoutY+pb.t.CaptionTop,0)
	local opacity,op=build('<table id="t" style="opacity:.5"><caption id="c" style="opacity:.5">Title</caption><tr><td>A</td></tr></table>')
	layout(opacity); assert(op.c.OpacityGroup.Gui.Parent==op.t.Gui)
	near(op.t.TableSurface.Position[2],op.t.CaptionTop)
	print('Table extras: captions outside borders, inheritance, wrapping/minimum width, nesting, layer order/spans, empty cells and retained partial layout passed')
end
