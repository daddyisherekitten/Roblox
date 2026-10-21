--!strict
return function(Parser,Dirty,Grid,loadRenderTree,loadWordLayout,loadBlockLayout)
	local created={}
	local factory={create=function(class,parent,props)
		assert(class~='TextButton' and class~='ImageButton')
		local g=table.clone(props); g.Parent=parent; table.insert(created,g); return g
	end,modifier=function(_,_,props) return table.clone(props) end}
	local overrides={['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	local function build(html)
		local doc=Parser.parse('<style>table{border-spacing:0}td,th{padding:0}</style>'..html)
		assert(#doc.Diagnostics==0)
		local tree=loadRenderTree(factory).build(doc,{},error,function(font) return font end)
		local boxes={}
		local function visit(b)
			if b.Node and b.Node.Attributes and b.Node.Attributes.id then boxes[b.Node.Attributes.id]=b end
			for _,child in b.Children or {} do visit(child) end
		end
		visit(tree); return tree,boxes
	end
	local function layout(tree,width) blocks.arrange(tree,width or 300,0,0,function() return true end) end
	local function near(a,b) assert(math.abs(a-b)<.001,tostring(a)..' != '..tostring(b)) end
	local height,h=build('<div style="height:400px"><table id="t" style="height:50%;width:180px"><caption id="cap">Height</caption><tr id="a" style="height:25%"><td>A</td></tr><tr id="b"><td>B</td></tr></table></div>')
	layout(height); near(h.t.TableGridHeight,200); near(h.a.OuterHeight,50); near(h.b.OuterHeight,150)
	near(h.t.OuterHeight,200+h.cap.OuterHeight)
	local cell,c=build('<table id="t" style="height:160px"><tr id="a"><td style="height:75%">A</td></tr><tr id="b"><td>B</td></tr></table>')
	layout(cell); near(c.a.OuterHeight,120); near(c.b.OuterHeight,40)
	local auto,a=build('<div><table id="t" style="height:50%"><tr><td>A</td></tr></table></div>')
	layout(auto); assert(a.t.OuterHeight>0 and a.t.OuterHeight<40,'Unresolved percentages behave as auto')
	local children,ch=build('<table id="t" style="height:120px"><tr><td><div id="fill" style="height:50%">Fill</div></td></tr></table>')
	layout(children); near(ch.fill.OuterHeight,60); near(ch.t.OuterHeight,120)
	local minimum,mi=build('<table id="t" style="height:20px"><tr><td><div style="height:80px">Tall</div></td></tr></table>')
	layout(minimum); near(mi.t.OuterHeight,80)
	local excess,ex=build('<table id="t" style="height:100px"><tr id="a" style="height:90%"><td>A</td></tr><tr id="b" style="height:90%"><td>B</td></tr></table>')
	layout(excess); near(ex.a.OuterHeight+ex.b.OuterHeight,100)
	local ratioHeight,rh=build('<table id="t" style="height:200px"><tr><td><div style="height:50%;aspect-ratio:2/1">AA</div></td></tr></table>')
	layout(ratioHeight); local initialWidth=rh.t.OuterWidth
	layout(ratioHeight); near(rh.t.OuterWidth,initialWidth)
	layout(ratioHeight,500); near(rh.t.OuterWidth,initialWidth)
	local fixedBasis,fb=build('<table id="t"><tr><td><div style="height:100px"><div style="height:50%;aspect-ratio:2/1">AA</div></div></td></tr></table>')
	layout(fixedBasis); near(fb.t.OuterWidth,100)
	layout(fixedBasis); near(fb.t.OuterWidth,100)
	local css,d=build('<div id="t" style="display:table;width:180px"><span id="cap" style="display:table-caption">CSS</span><div style="display:table-row"><span id="a" style="display:table-cell">A</span><div id="b" style="display:table-cell">B</div></div><div style="display:table-row"><div id="c" style="display:table-cell">Longer</div><div style="display:table-cell">D</div></div></div>')
	layout(css); assert(#d.t.TableRows==2 and #d.t.TableCaptions==1); near(d.a.OuterWidth,d.c.OuterWidth); near(d.t.OuterWidth,180)
	assert(d.a.Node.Name=='span' and d.a.Node.Parent.Name=='div','CSS table layout preserves original DOM nodes')
	local groups,g=build('<div id="t" style="display:table"><div id="foot" style="display:table-footer-group"><div style="display:table-row"><div style="display:table-cell">F</div></div></div><div id="head" style="display:table-header-group"><div style="display:table-row"><div style="display:table-cell">H</div></div></div></div>')
	layout(groups); assert(g.head.LayoutY<g.foot.LayoutY)
	local override,ov=build('<table id="t" style="display:block"><tr style="display:block"><td style="display:block">Normal block</td></tr></table>')
	layout(override); assert(ov.t.TableRows==nil)
	local implied,im=build('<table id="t" style="height:180px"><tbody><tr><td id="span" rowspan="3">A</td><td rowspan="0">All</td></tr></tbody><tfoot id="foot"><tr><td>Footer</td></tr></tfoot></table>')
	local count=#created; layout(implied)
	assert(#im.t.TableRows==4 and im.t.TableRows[2].Implicit and im.t.TableRows[3].Implicit)
	assert(im.t.TableGrid.Entries[2].RowSpan==3 and im.t.TableGrid.Entries[3].Row==4)
	assert(im.t.TableRows[2].Box.Gui==nil and #created==count)
	near(im.span.OuterHeight,im.t.RowHeights[1]+im.t.RowHeights[2]+im.t.RowHeights[3])
	for _,mode in {'separate','collapse'} do
		local collapse,b=build('<table id="t" style="width:240px;height:120px;table-layout:fixed;border-collapse:'..mode..'"><col style="width:80px"><col style="width:80px;visibility:collapse"><col style="width:80px"><tr id="r1"><td id="a">A</td><td id="hidden">Hidden</td><td id="b">B</td></tr><tr id="gone" style="visibility:collapse"><td>C</td><td>D</td><td>E</td></tr><tr id="r3"><td id="c">C</td><td>X</td><td id="d">D</td></tr></table>')
		layout(collapse); near(b.t.OuterWidth,160); near(b.t.OuterHeight,80)
		near(b.gone.OuterHeight,0); near(b.r3.LayoutY,40); assert(not b.hidden.Gui.Visible)
		near(b.b.LayoutX,80); assert(b.a.Gui.Visible and b.b.Gui.Visible)
		if mode=='collapse' then assert(b.t.CollapsedBorders.Rows==2 and b.t.CollapsedBorders.Columns==2) end
	end
	local spacing,sp=build('<table id="t" style="width:158px;table-layout:fixed;border-spacing:2px"><col style="width:50px"><col style="width:50px;visibility:collapse"><col style="width:50px"><tr><td>A</td><td>X</td><td id="last">B</td></tr></table>')
	layout(spacing); near(sp.t.OuterWidth,106); near(sp.last.LayoutX,52);near(sp.t.TableRows[1].Box.LayoutX,2)
	local span,cs=build('<table id="t" style="width:180px;table-layout:fixed"><col><col style="visibility:collapse"><col><tr><td id="span" colspan="2">Long unchanged content</td><td>A</td></tr></table>')
	layout(span); near(cs.span.OuterWidth,60); assert(cs.span.Gui.ClipsDescendants)
	for _,mode in {'separate','collapse'} do
		for _,overflowStyle in {'visible','hidden'} do
			local rowSpan,rs=build('<table id="t" style="width:240px;table-layout:fixed;border-collapse:'..mode..'"><col><col style="visibility:collapse"><col><tr><td id="span" rowspan="3" style="overflow:'..overflowStyle..'">rowspan<br>3</td><td>Gone</td><td>Visible</td></tr><tr style="visibility:collapse"><td>Gone</td><td>Gone</td></tr></table>')
			layout(rowSpan)
			assert(rs.span.OuterHeight<rs.span.UnclippedBottom,'Collapsed row keeps the smaller border box')
			if overflowStyle=='visible' then
				assert(not rs.span.Gui.ClipsDescendants,'Row collapse preserves visible rowspan overflow, matching the browser reference')
				assert(rs.t.LocalBottom>rs.t.OuterHeight,'Visible rowspan overflow contributes to scroll bounds without stretching the table')
			else
				local clip=assert(rs.span.ClipContent)
				assert(clip.ClipsDescendants and clip.Parent==rs.span.Gui and not rs.span.Gui.ClipsDescendants,
					'Explicit overflow:hidden clips rowspan content inside the border box')
				near(clip.Size[1],rs.span.OuterWidth);near(clip.Size[2],rs.span.OuterHeight)
				local overflowing=false
				for _,run in rs.span.Children do for _,item in run.Items or {} do if item.Gui then
					assert(item.Gui.Parent==clip,'Rowspan glyphs belong to the content clipping host')
					if item.Gui.Position[2]+item.Gui.Size[2]>clip.Size[2]then overflowing=true end
				end end end
				assert(overflowing,'The full rowspan content extends beyond the retained clip region')
				near(rs.t.LocalBottom,rs.t.OuterHeight)
			end
		end
	end
	local group,gr=build('<table id="t"><colgroup style="visibility:collapse"><col><col></colgroup><col><tbody style="visibility:collapse"><tr><td>A</td></tr></tbody><tbody><tr><td>X</td><td>Y</td><td id="last">Z</td></tr></tbody></table>')
	layout(group); assert(#gr.t.PaintedColumnWidths==1 and #gr.t.PaintedRowHeights==1 and gr.last.Gui.Visible)
	local rtl,r=build('<table id="t" style="width:200px;table-layout:fixed;direction:rtl;border-collapse:collapse"><col style="width:60px"><col><tr><td id="a" style="border-left:4px solid red;border-right:2px solid blue">A</td><td id="b" style="border:1px solid black">B</td></tr></table>')
	layout(rtl); assert(r.a.LayoutX>r.b.LayoutX); near(r.a.LayoutX+r.a.OuterWidth,r.t.ContentWidth)
	near(r.a.Style.BorderSizes[4],2); near(r.a.Style.BorderSizes[2],1)
	assert(r.t.ColumnWidths[1]<r.t.ColumnWidths[2],'RTL preserves the logical col definitions')
	local texts,tx=build('<table style="direction:rtl;width:100px"><tr><td id="a">A</td></tr></table>')
	layout(texts); assert(tx.a.Children[1].Items[1].X>50,'Default start alignment follows RTL')
	local rtlClip,rc=build('<table style="direction:rtl;width:180px;table-layout:fixed"><col><col style="visibility:collapse"><col><tr><td id="span" colspan="2">A</td><td>B</td></tr></table>')
	layout(rtlClip); near(rc.span.OuterWidth,60)
	local run=rc.span.Children[1]
	assert(run.LayoutX+run.Items[1].X>=0 and run.LayoutX+run.Items[1].X<60,'RTL clipping preserves the right side of spanned content')
	local overflow,of=build('<div style="position:relative"><table id="t" style="width:120px;table-layout:fixed"><col style="visibility:collapse"><col><tr><td><div style="position:absolute;top:900px;width:10px;height:10px"></div></td><td>A</td></tr></table></div>')
	layout(overflow); assert(of.t.LocalBottom<100 and overflow.LocalBottom<100,'Collapsed positioned content cannot enlarge scrolling bounds')
	local dirty,db=build('<div id="parent" style="height:200px"><table id="t" style="height:50%;direction:rtl"><tr><td><output>A</output></td><td>B</td></tr></table></div>')
	local clippedPosition,cp=build('<table style="width:180px;table-layout:fixed"><col><col style="visibility:collapse"><col><tr><td id="span" colspan="2" style="position:relative;opacity:.5">A<div style="position:absolute;left:900px;top:900px;width:10px;height:10px"></div></td><td>B</td></tr></table>')
	local _,clipRight,clipBottom=blocks.arrange(clippedPosition,300,0,0,function() return true end)
	assert(clipRight<400 and clipBottom<100,'Clipped colspan descendants must not enlarge positioned scroll bounds')
	assert(cp.span.OpacityBounds[3]<100 and cp.span.OpacityBounds[4]<100,'Clipped colspan descendants must not inflate opacity textures')
	Dirty.begin(clippedPosition); blocks.arrange(clippedPosition,300,0,0,function() return true end); Dirty.finish(clippedPosition,true)
	Dirty.begin(clippedPosition,{[cp.span]=true})
	local _,partialRight,partialBottom=blocks.arrange(clippedPosition,300,0,0,function() return true end)
	Dirty.finish(clippedPosition,true); near(partialRight,clipRight); near(partialBottom,clipBottom)
	Dirty.begin(dirty); layout(dirty); Dirty.finish(dirty,true)
	local control=dirty.Controls[1]; control.Value='Changed'; control.Item.ControlMeasureKey=nil
	Dirty.begin(dirty,{[control.Item]=true}); layout(dirty); Dirty.finish(dirty,true)
	local w,hgt=db.t.OuterWidth,db.t.OuterHeight
	Dirty.begin(dirty); layout(dirty); Dirty.finish(dirty,true); near(db.t.OuterWidth,w); near(db.t.OuterHeight,hgt)
	db.parent.Style.Height.Value=400
	Dirty.begin(dirty,{[db.parent]=true}); layout(dirty); Dirty.finish(dirty,true); near(db.t.OuterHeight,200)
	print('Advanced tables: pixel/percentage heights, CSS display roles, implicit rows, collapse projection/clipping, RTL borders/alignment and partial/full layout passed')
end
