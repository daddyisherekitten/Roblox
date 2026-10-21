--!strict
return function(Parser,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout)
	local created={}
	local factory={create=function(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		local gui=table.clone(props); gui.Parent=parent; table.insert(created,gui); return gui
	end,modifier=function(_,_,props) return table.clone(props) end}
	local overrides={['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	local css='<style>table{border-spacing:0}td,th{padding:0}</style>'
	local function build(html)
		local doc=Parser.parse(css..html); assert(#doc.Diagnostics == 0)
		local tree=loadRenderTree(factory).build(doc,{},error,function(font) return font end)
		local boxes={}
		local function visit(b)
			if b.Node and b.Node.Attributes and b.Node.Attributes.id then boxes[b.Node.Attributes.id]=b end
			for _,child in b.Children or {} do visit(child) end
		end
		visit(tree); return tree,boxes
	end
	local function layout(tree,width) blocks.arrange(tree,width or 300,0,0,function() return true end) end
	local function near(a,b) assert(math.abs(a-b) < .001,tostring(a)..' != '..tostring(b)) end
	local tree,b=build('<table id="t" style="table-layout:fixed;width:240px"><tr><td id="a" style="width:60px">A<td id="b">B<tr><td id="c" style="width:900px">AnUnbreakableVeryLongWordThatMustNotWidenTheColumn<td>D</table>')
	layout(tree)
	near(b.t.OuterWidth,240); near(b.a.OuterWidth,60); near(b.b.OuterWidth,180); near(b.c.OuterWidth,60)
	assert(b.c.UnclippedRight > b.c.OuterWidth,'Unbreakable text overflows instead of changing fixed columns')
	local columns,cb=build('<table id="t" style="table-layout:fixed;width:100%"><colgroup id="g" span="9" style="width:50px"><col id="c1" style="width:25%"><col span="2"></colgroup><tr><td style="width:300px">A<td>B<td>C</table>')
	layout(columns,200)
	assert(#cb.t.TableColumns == 3 and cb.c1 == nil and cb.g == nil,'Explicit col children replace colgroup span without flow boxes')
	near(cb.t.ColumnWidths[1],200/3); near(cb.t.ColumnWidths[2],200/3)
	layout(columns,400)
	near(cb.t.ColumnWidths[1],100+200/3); near(cb.t.ColumnWidths[2],50+200/3)
	local mixed,mb=build('<table id="t" style="table-layout:fixed;width:200px"><col style="width:50px"><col style="width:25%"><col><tr><td>A<td>B<td>C</table>')
	layout(mixed); near(mb.t.ColumnWidths[1],50); near(mb.t.ColumnWidths[2],50); near(mb.t.ColumnWidths[3],100)
	local spans,sb=build('<table id="t" style="table-layout:fixed;width:300px;border-spacing:2px"><tr><td id="a" colspan="2" style="width:120px">A<td id="b">B<tr><td>C<td>D<td>E</table>')
	layout(spans); near(sb.a.OuterWidth,120); near(sb.t.ColumnWidths[1],59); near(sb.b.OuterWidth,174)
	local over,ob=build('<table id="t" style="table-layout:fixed;width:100px"><colgroup span="2" style="width:80px"></colgroup><tr><td>A<td>B</table>')
	layout(over); near(ob.t.OuterWidth,160); near(ob.t.ColumnWidths[1],80)
	local auto,ab=build('<table id="t" style="table-layout:fixed"><tr><td>LongWord<td>B</table>')
	layout(auto); near(ab.t.OuterWidth,45)
	local automatic,au=build('<table id="t"><colgroup span="2" style="width:70px"></colgroup><tr><td>A<td>B</table>')
	layout(automatic); near(au.t.OuterWidth,140)
	local nested,nb=build('<table id="outer"><tr><td><table id="inner" style="table-layout:fixed;width:100px"><col style="width:100%"><tr><td>LongUnbreakableWord</table></table>')
	layout(nested); near(nb.inner.OuterWidth,100); near(nb.outer.OuterWidth,100)
	local wrap,wb=build('<table id="t" style="table-layout:fixed;width:100%"><colgroup><col style="width:25%"><col></colgroup><tr><td id="a">one two three four<td>B</table>')
	layout(wrap,240); local h=wb.t.OuterHeight
	layout(wrap,120); near(wb.a.OuterWidth,30); assert(wb.t.OuterHeight > h)
	local background,bg=build('<table id="t" style="border-collapse:collapse;table-layout:fixed;width:200px"><colgroup style="background:red;border:2px solid red"><col id="col" style="background:rgba(0,0,255,.5);border:3px solid blue;color:green"><col></colgroup><tr><td id="a" colspan="2">A<tr style="border:3px solid black"><td id="b">B<td>C</table>')
	layout(background)
	assert(#bg.a.ColumnBackgrounds == 2 and bg.a.ColumnBackgrounds[2].BackgroundTransparency == .5)
	near(bg.a.ColumnBackgrounds[1].Size[1],bg.a.OuterWidth)
	assert(bg.a.Style.Color ~= bg.t.TableColumns[1].Style.Color,'Column text styles must not leak into cell styles')
	assert(bg.t.CollapsedBorders.Vertical[2][1] == nil,'Column border does not divide colspan')
	assert(bg.t.CollapsedBorders.Vertical[1][1].Node.Name == 'col')
	assert(bg.t.CollapsedBorders.Vertical[1][2].Node.Name == 'tr','Row outranks column on equal edges')
	local omitted,om=build('<table id="t" style="table-layout:fixed;width:180px"><colgroup span="2"><colgroup><col><tbody><tr><td>A<td>B<td>C</table>')
	layout(omitted); assert(#om.t.TableColumns == 3 and #om.t.TableRows == 1)
	local hidden,hb=build('<table id="t"><colgroup style="display:none"><col span="9"></colgroup><col span="0"><col span="-2"><tr><td>A<td>B</table>')
	layout(hidden); assert(#hb.t.TableColumns == 2)
	local inert,ib=build('<table id="t"><colgroup><script>ignored()</script><col></colgroup><tr><td>A</table>')
	layout(inert); assert(#ib.t.TableColumns == 1,'Inert script content does not close the column group or become a column')
	local valid=pcall(function() build('<table>'..string.rep('<col span="1000">',5)..'</table>') end)
	assert(not valid,'Column definitions share the 4096-column limit')
	local dirty,db=build('<table id="t" style="table-layout:fixed;width:200px"><colgroup span="2" style="background:#ddd"></colgroup><tr><td><output>A</output><td>B</table><div id="after">After</div>')
	Dirty.begin(dirty); layout(dirty); Dirty.finish(dirty,true)
	local control=dirty.Controls[1]; local count=#created
	control.Value='one two three four five six seven eight'; control.Item.ControlMeasureKey=nil
	Dirty.begin(dirty,{[control.Item]=true}); layout(dirty); Dirty.finish(dirty,true)
	near(db.t.ColumnWidths[1],100); assert(#created == count,'Content reflow retains column backgrounds')
	local height,after=db.t.OuterHeight,db.after.LayoutY
	Dirty.begin(dirty); layout(dirty); Dirty.finish(dirty,true)
	near(db.t.OuterHeight,height); near(db.after.LayoutY,after)
	print('Fixed tables/columns: priority, first-row spans, px/percent/auto widths, overflow, wrapping, nesting, column backgrounds/borders, parser spans and retained partial layout passed')
end
