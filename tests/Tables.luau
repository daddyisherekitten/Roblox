--!strict
return function(Parser,DOM,Style,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout)
	local factory={create=function(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		local gui=table.clone(props); gui.Parent=parent; return gui
	end,modifier=function(_,_,props) return table.clone(props) end}
	local overrides={['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	local function build(html)
		local doc=Parser.parse(html); assert(#doc.Diagnostics == 0,'Valid table end-tag omission must parse')
		local warnings={}
		local tree=loadRenderTree(factory).build(doc,{},function(s) table.insert(warnings,s) end,function(font) return font end)
		local boxes={}
		local function visit(b)
			if b.Node and b.Node.Attributes and b.Node.Attributes.id then boxes[b.Node.Attributes.id]=b end
			for _,c in b.AllChildren or b.Children or {} do visit(c) end
		end
		visit(tree)
		return tree,boxes,warnings,doc
	end
	local tree,b,w=build('<table id="t"><thead><tr id="head"><th id="h1">A<th id="h2">BB</thead><tbody><tr id="r1"><td id="a">CCCC<td id="b">D<tr id="r2"><td id="c">E<td id="d">FFFFFF</tbody></table><div id="after" style="height:10px"></div>')
	assert(#w == 0)
	blocks.arrange(tree,300,0,0,function() return true end)
	assert(b.h1.Style.FontWeight == 700 and b.h1.Style.TextAlign == 'center' and b.a.Style.Padding[1] == 1)
	assert(b.a.OuterWidth == b.c.OuterWidth and b.a.OuterWidth == b.h1.OuterWidth)
	assert(b.b.OuterWidth == b.d.OuterWidth and b.b.OuterWidth == b.h2.OuterWidth)
	assert(b.t.OuterWidth == 22+32+6,'Auto table shrink-wraps max-content columns and three 2px gaps')
	assert(b.a.LayoutX==0 and b.b.LayoutX==24 and b.t.TableGroups[2].LayoutX==2,'Cells are relative to the row box; the group starts after outer spacing')
	assert(b.after.LayoutY == b.t.OuterHeight)
	local originalHeight=b.t.OuterHeight
	local percent,pb=build('<table id="t" style="width:100%;border-spacing:0"><tr><td id="a" style="padding:2% 5%">A<td id="b" style="padding:2% 5%">B</table>')
	for _,available in {200,100,200} do
		blocks.arrange(percent,available,0,0,function() return true end)
		assert(math.abs(pb.a.OuterWidth-pb.t.ColumnWidths[1]) < .001,'Percentage padding must not change the allocated column width')
		assert(pb.a.Style.Padding[4] == available*.05 and pb.a.Style.Padding[1] == available*.02,'Cell percentage padding uses the table width on both layout passes')
		assert(math.abs(pb.a.ContentWidth+pb.a.Style.Padding[2]+pb.a.Style.Padding[4]-pb.a.OuterWidth) < .001)
	end
	blocks.arrange(tree,30,0,0,function() return true end)
	assert(b.t.OuterWidth == 60 and b.t.OuterHeight == originalHeight,'Unbreakable content preserves table minimum width')
	local wrapped,wb=build('<table id="t" style="width:100%;border-spacing:4px 6px;padding:3px;border:1px solid black"><tr id="r"><td id="a" style="padding:2px;border:1px solid black">one two three four<td id="b" style="vertical-align:bottom">X</table>')
	blocks.arrange(wrapped,100,0,0,function() return true end)
	assert(wb.t.OuterWidth == 100 and wb.a.OuterHeight == wb.b.OuterHeight)
	assert(wb.r.LayoutX == 8 and wb.r.LayoutY == 10 and wb.a.LayoutX == 0)
	assert(wb.t.OuterHeight == wb.r.OuterHeight+20,'Table edges and vertical border-spacing are independent of row height')
	local first=wb.a.Children[1].LayoutY
	assert(wb.b.Children[1].LayoutY > first,'Bottom-aligned short content moves within the stretched cell')
	local narrowHeight=wb.t.OuterHeight
	blocks.arrange(wrapped,250,0,0,function() return true end)
	assert(wb.t.OuterWidth == 250 and wb.t.OuterHeight < narrowHeight,'Wider tables unwrap cells and reduce row height')
	local alignment,ab=build('<table id="t" style="border-spacing:0"><tr><td id="a" style="vertical-align:baseline;font-size:10px">Small<td id="b" style="vertical-align:baseline;font-size:24px">Large<td id="c" style="vertical-align:middle">Middle</table>')
	blocks.arrange(alignment,300,0,0,function() return true end)
	assert(math.abs(ab.a.FirstBaseline-ab.b.FirstBaseline) < .001 and ab.a.OuterHeight == ab.b.OuterHeight)
	assert(ab.c.Children[1].LayoutY > 1,'Default middle alignment centers shorter cell content')
	local nested,nb=build('<table id="outer"><tfoot id="foot"><tr><td>Foot</tfoot><tbody id="body"><tr><td><table id="inner"><tr><td>A<td>B</table></td><td>C</td></tr></tbody><thead id="head"><tr><th>Head</thead></table>')
	blocks.arrange(nested,300,0,0,function() return true end)
	assert(nb.head.LayoutY < nb.body.LayoutY and nb.body.LayoutY < nb.foot.LayoutY)
	assert(#nb.outer.ColumnWidths == 2 and #nb.inner.ColumnWidths == 2,'Nested table rows are independent')
	local minTree,mb=build('<table id="t" style="min-width:160px"><tr><td>A<tfoot><tr><td>B</table>')
	blocks.arrange(minTree,300,0,0,function() return true end)
	assert(mb.t.OuterWidth == 160 and #mb.t.TableRows == 2,'Auto width respects explicit minimums and direct-row/group transitions')
	local dirty,db=build('<div id="before" style="height:8px"></div><table id="t"><tr><td><output id="out">A</output></td><td id="other">B</td></tr><tr><td id="belowcell">C</td><td>D</td></tr></table><div id="after">After</div>')
	Dirty.begin(dirty); blocks.arrange(dirty,300,0,0,function() return true end); Dirty.finish(dirty,true)
	local oldWidth=db.t.OuterWidth
	local c=dirty.Controls[1]; local gui=c.Item.Gui
	c.Value='A much longer output'; c.Item.ControlMeasureKey=nil
	local stats=Dirty.begin(dirty,{[c.Item]=true}); blocks.arrange(dirty,300,0,0,function() return true end); Dirty.finish(dirty,true)
	assert(stats.Mode == 'partial' and db.t.OuterWidth > oldWidth and c.Item.Gui == gui)
	assert(db.belowcell.OuterWidth == db.t.ColumnWidths[1])
	local width,height,after=db.t.OuterWidth,db.t.OuterHeight,db.after.LayoutY
	Dirty.begin(dirty); blocks.arrange(dirty,300,0,0,function() return true end); Dirty.finish(dirty,true)
	assert(db.t.OuterWidth == width and db.t.OuterHeight == height and db.after.LayoutY == after,'Partial and full table layout must agree')
	local empty,eb=build('<table id="empty"></table><table id="row"><tr></tr></table><table id="cells"><tr><td id="cell"></td></tr></table>')
	blocks.arrange(empty,300,0,0,function() return true end)
	assert(eb.empty.OuterWidth == 0 and eb.empty.OuterHeight == 0 and eb.cell.OuterWidth == 2)
	local _,_,supported=build('<table style="border-collapse:collapse"><tr><td colspan="2">A</td></tr></table>')
	assert(#supported == 0,'Collapsed borders support merged cells')
	local parent=Style.resolve(DOM.element('div',{}),{FontSize=20},error)
	local s=Style.resolve(DOM.element('table',{style='border-spacing:.5em 3px'}),parent,error)
	assert(s.BorderSpacing[1] == s.FontSize*.5 and s.BorderSpacing[2] == 3)
	print('Tables: shared columns, intrinsic widths, spacing/borders, wrapping, vertical alignment, groups, nesting, dirty layout, empty cells and diagnostics passed')
end
