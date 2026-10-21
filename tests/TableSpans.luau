--!strict
return function(Parser,Grid,Dirty,HitTest,loadRenderTree,loadWordLayout,loadBlockLayout)
	local factory={create=function(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		local gui=table.clone(props); gui.Parent=parent; return gui
	end,modifier=function(_,_,props) return table.clone(props) end}
	local overrides={['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	local function build(html)
		-- These row/grid regressions exercise standards sizing; all three
		-- document modes are compared separately in QuirksLayoutRendering.
		local document=Parser.parse('<!doctype html>'..html); assert(#document.Diagnostics == 0)
		local warnings={}
		local tree=loadRenderTree(factory).build(document,{},function(s) table.insert(warnings,s) end,function(font) return font end)
		local boxes={}
		local function visit(box)
			if box.Node and box.Node.Attributes and box.Node.Attributes.id then boxes[box.Node.Attributes.id]=box end
			for _,child in box.Children or {} do visit(child) end
		end
		visit(tree); return tree,boxes,warnings
	end
	local tree,b,w=build('<table id="t" style="width:200px;border-spacing:3px 5px"><thead><tr><th id="title" colspan="3">Combined heading</th></tr></thead><tbody><tr id="r1"><td id="span" rowspan="2" colspan="2">Both axes</td><td id="a">A</td></tr><tr id="r2"><td id="b">B</td></tr></tbody></table>')
	assert(#w == 0 and b.t.TableGrid.Columns == 3)
	local entries=b.t.TableGrid.Entries
	assert(entries[1].Column == 1 and entries[1].ColSpan == 3)
	assert(entries[2].ColSpan == 2 and entries[2].RowSpan == 2)
	assert(entries[3].Column == 3 and entries[4].Column == 3,'Rowspan reserves both covered columns on the next row')
	blocks.arrange(tree,300,0,0,function() return true end)
	assert(math.abs(b.title.OuterWidth-194) < .001,'Colspan includes all inner gaps, excluding the two outer gaps')
	assert(math.abs(b.span.OuterWidth-(b.t.ColumnWidths[1]+b.t.ColumnWidths[2]+3)) < .001)
	assert(math.abs(b.span.OuterHeight-(b.r1.OuterHeight+b.r2.OuterHeight+5)) < .001)
	assert(b.a.LayoutX == b.b.LayoutX and b.a.LayoutX >= b.span.LayoutX+b.span.OuterWidth+3-.001)
	assert(b.span.Gui.Parent == b.r1.Gui,'Spanning cells keep their original GUI and hit-test ancestry')
	local zero,zb,zw=build('<table id="t"><tbody id="g1"><tr><td id="zero" rowspan="0">Through group</td><td>A</td></tr><tr><td>B</td></tr><tr><td>C</td></tr></tbody><tbody id="g2"><tr><td id="next">Next group</td></tr></tbody></table>')
	assert(#zw == 0 and zb.t.TableGrid.Entries[1].RowSpan == 3 and zb.t.TableGrid.Entries[5].Column == 1)
	blocks.arrange(zero,300,0,0,function() return true end)
	assert(math.abs(zb.zero.OuterHeight-zb.g1.OuterHeight) < .001 and zb.g2.LayoutY >= zb.g1.LayoutY+zb.g1.OuterHeight)
	local tall,tb=build('<table id="t" style="width:100%;border-spacing:4px"><tr id="r1"><td id="tall" rowspan="2" style="vertical-align:bottom;padding:3px;border:1px solid black">Long text that needs more than one line at small widths</td><td id="small">X</td></tr><tr id="r2"><td>Y</td></tr></table>')
	blocks.arrange(tall,120,0,0,function() return true end)
	local narrow=tb.t.OuterHeight
	assert(math.abs(tb.tall.OuterHeight-(tb.r1.OuterHeight+tb.r2.OuterHeight+4)) < .001)
	assert(tb.tall.LocalBottom <= tb.tall.OuterHeight+.001,'A tall rowspan grows its covered rows without clipping')
	blocks.arrange(tall,350,0,0,function() return true end)
	assert(tb.t.OuterHeight < narrow)
	local only,ob=build('<table id="t" style="border-spacing:2px"><tr id="r1"><td id="cell" rowspan="2" style="height:90px"></td></tr><tr id="r2"></tr></table>')
	blocks.arrange(only,200,0,0,function() return true end)
	assert(ob.cell.OuterHeight == 92 and ob.r1.OuterHeight+ob.r2.OuterHeight == 90,'Rows containing only a rowspan still receive height')
	local baseline,bb=build('<table><tr><td id="spanned" rowspan="2" style="vertical-align:baseline;font-size:10px">Small</td><td id="peer" style="vertical-align:baseline;font-size:24px">Large</td></tr><tr><td>Bottom</td></tr></table>')
	blocks.arrange(baseline,300,0,0,function() return true end)
	assert(math.abs(bb.spanned.FirstBaseline-bb.peer.FirstBaseline) < .001)
	local constraints,cb=build('<table id="t"><tr><td id="wide" colspan="2">UnbreakableHeading</td></tr><tr><td>A</td><td>B</td></tr></table>')
	blocks.arrange(constraints,30,0,0,function() return true end)
	assert(cb.wide.OuterWidth >= #'UnbreakableHeading'*5+2 and cb.t.OuterWidth >= cb.wide.OuterWidth+4)
	local dirty,db=build('<table id="t"><tr><td rowspan="2"><output id="out">A</output></td><td>X</td></tr><tr><td>Y</td></tr><tr><td id="wide" colspan="2">Z</td></tr></table><p id="after">After</p>')
	Dirty.begin(dirty); blocks.arrange(dirty,180,0,0,function() return true end); Dirty.finish(dirty,true)
	local c=dirty.Controls[1]; local gui=c.Item.Gui; c.Value='Changed text with several words'; c.Item.ControlMeasureKey=nil
	local stats=Dirty.begin(dirty,{[c.Item]=true}); blocks.arrange(dirty,180,0,0,function() return true end); Dirty.finish(dirty,true)
	local width,height,after=db.t.OuterWidth,db.t.OuterHeight,db.after.LayoutY
	assert(stats.Mode == 'partial' and c.Item.Gui == gui)
	Dirty.begin(dirty); blocks.arrange(dirty,180,0,0,function() return true end); Dirty.finish(dirty,true)
	assert(math.abs(db.t.OuterWidth-width) < .001 and math.abs(db.t.OuterHeight-height) < .001 and math.abs(db.after.LayoutY-after) < .001)
	local _,limited,lw=build('<table id="t"><tbody><tr><td rowspan="99">A</td></tr></tbody><tbody><tr><td>B</td></tr></tbody></table>')
	assert(#lw == 0 and limited.t.TableGrid.Entries[1].RowSpan == 99 and limited.t.TableGrid.Entries[2].Column == 1)
	assert(#limited.t.TableRows == 100 and limited.t.TableRows[2].Implicit and limited.t.TableRows[2].Box.Gui == nil)
	local _,invalid=build('<table id="t"><tr><td colspan="0" rowspan="-1">A</td><td colspan="bad">B</td><td colspan=" +2x">C</td></tr></table>')
	assert(invalid.t.TableGrid.Columns == 4 and invalid.t.TableGrid.Entries[1].ColSpan == 1 and invalid.t.TableGrid.Entries[3].ColSpan == 2)
	local function rawCell(colspan) return {Node={Attributes={colspan=colspan}}} end
	local scope={}
	local capped=Grid.build({{Scope=scope,Cells={rawCell('999999999999999999999')}}},error)
	assert(capped.Columns == 1000)
	local ok,message=pcall(Grid.build,{{Scope=scope,Cells={rawCell('1000'),rawCell('1000'),rawCell('1000'),rawCell('1000'),rawCell('1000')}}},error)
	assert(not ok and tostring(message):find('4096',1,true),'Excessive table grids fail explicitly without unbounded slot allocation')
	local root={IsA=function() return false end}
	local transparentRow={Parent=root,Visible=true,IsA=function(_,kind) return kind == 'GuiObject' end}
	local spanningControl={Parent=root,Visible=true,IsA=transparentRow.IsA}
	local controlNode={Name='input'}
	assert(HitTest.pick({transparentRow,spanningControl},{[transparentRow]={Name='tr'},[spanningControl]=controlNode},root) == controlNode,
		'A later transparent row must not intercept a control inside an earlier rowspan')
	print('Table spans: combined axes, occupied slots, group boundaries/zero, sizing, wrapping, baseline, dirty layout and attribute limits passed')
end
