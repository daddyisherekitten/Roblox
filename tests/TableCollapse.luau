--!strict
return function(Parser,Dirty,HitTest,loadRenderTree,loadWordLayout,loadBlockLayout)
	local created,modifiers={},{}
	local factory={create=function(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		local gui=table.clone(props); gui.Parent=parent; gui.Visible=true
		gui.IsA=function(_,kind) return kind == 'GuiObject' or kind == class end
		table.insert(created,gui); return gui
	end,modifier=function(class,parent,props)
		local object=table.clone(props); object.Parent=parent; object.Class=class
		table.insert(modifiers,object); return object
	end}
	local overrides={['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	local function build(html)
		local doc=Parser.parse(html); assert(#doc.Diagnostics == 0)
		local warnings={}
		local root={IsA=function() return false end}
		local tree=loadRenderTree(factory).build(doc,root,function(s) table.insert(warnings,s) end,function(font) return font end)
		assert(#warnings == 0,table.concat(warnings,'; '))
		local boxes={}
		local function visit(b)
			if b.Node and b.Node.Attributes and b.Node.Attributes.id then boxes[b.Node.Attributes.id]=b end
			for _,child in b.Children or {} do visit(child) end
		end
		visit(tree)
		return tree,boxes
	end
	local css='<style>table{border-collapse:collapse}td{border:1px solid black;padding:0}</style>'
	local function layout(tree,width) blocks.arrange(tree,width or 300,0,0,function() return true end) end
	local function near(a,b) assert(math.abs(a-b) < .001,tostring(a)..' != '..tostring(b)) end
	local tree,b=build(css..'<table id="t" style="border-spacing:20px;padding:30px;border-radius:5px"><tr id="r"><td id="a">A<td id="b">B</table>')
	layout(tree)
	near(b.t.OuterWidth,13)
	near(b.a.OuterWidth,6); near(b.b.LayoutX,6)
	near(b.r.LayoutX,.5); near(b.r.LayoutY,.5)
	near(b.t.OuterHeight,b.a.OuterHeight+1)
	assert(b.a.Style.BorderSizes[2] == .5 and b.b.Style.BorderSizes[4] == .5)
	assert(b.t.Style.Padding[1] == 0 and b.t.Style.BorderRadius == 0)
	local paint=b.t.TableBorderPaint
	assert(paint.Host.Size[1] == 0 and paint.Host.Size[2] == 0,'Border host must not cover the interactive table interior')
	local function coverage(pool,x,y)
		local count=0
		for _,item in pool do
			local g=item.Gui
			if g.Visible and x >= g.Position[1] and y >= g.Position[2] and x < g.Position[1]+g.Size[1] and y < g.Position[2]+g.Size[2] then count+=1 end
		end
		return count
	end
	for x=0,b.t.OuterWidth-1 do for y=0,b.t.OuterHeight-1 do
		local edge=x == 0 or x == 6 or x == 12 or y == 0 or y == b.t.OuterHeight-1
		assert(coverage(paint.Pool,x+.5,y+.5) == (if edge then 1 else 0),'Each border pixel, including intersections, is painted exactly once')
	end end
	for _,m in modifiers do assert(m.Parent ~= b.a.Gui and m.Parent ~= b.b.Gui,'Collapsed cells have no individual strokes/corners') end
	for _,part in paint.Pool do
		assert(part.Gui.Position[1] >= 0 and part.Gui.Position[2] >= 0)
		assert(part.Gui.Position[1]+part.Gui.Size[1] <= b.t.OuterWidth+.001)
		assert(part.Gui.Position[2]+part.Gui.Size[2] <= b.t.OuterHeight+.001)
	end
	local conflict,cb=build(css..'<table id="t" style="border:3px solid green"><tbody style="border:3px solid blue"><tr style="border:3px solid red"><td id="a" style="border-right:2px solid red">A<td id="b" style="border-left:4px dashed blue">B</table>')
	layout(conflict)
	local edges=cb.t.CollapsedBorders
	assert(edges.Vertical[2][1].Width == 4 and edges.Vertical[2][1].Style == 'dashed','Wider edge wins regardless of style')
	assert(edges.Horizontal[1][1].Node.Name == 'tr','Row wins tied row/group/table edges')
	assert(cb.a.Style.BorderSizes[2] == 2 and cb.b.Style.BorderSizes[4] == 2)
	local tied,tb=build(css..'<table id="t"><tr><td id="a" style="border:3px solid red">A<td id="b" style="border:3px solid blue">B<tr><td id="c" style="border:3px solid green">C<td id="d" style="border:3px double green">D</table>')
	layout(tied)
	assert(tb.t.CollapsedBorders.Vertical[2][1].Node == tb.a.Node,'Equal left cell wins')
	assert(tb.t.CollapsedBorders.Horizontal[2][1].Node == tb.a.Node,'Equal upper cell wins')
	assert(tb.t.CollapsedBorders.Vertical[2][2].Style == 'double','Style priority resolves equal widths')
	local hidden,hb=build(css..'<table id="t"><tr><td id="a" style="border-right:hidden;border-bottom:none">A<td id="b" style="border-left:12px solid blue">B<tr><td>C<td>D</table><div id="outside" style="border:5px hidden">X</div>')
	layout(hidden)
	assert(hb.t.CollapsedBorders.Vertical[2][1].Style == 'hidden' and hb.a.Style.BorderSizes[2] == 0 and hb.b.Style.BorderSizes[4] == 0)
	assert(hb.t.CollapsedBorders.Horizontal[2][1].Width == 1,'None still allows the neighbor border')
	assert(hb.outside.Style.BorderSize == 0,'Hidden outside collapsed tables consumes no border space')
	local spans,sb=build(css..'<table id="t"><tr style="border-bottom:8px solid red"><td id="a" rowspan="2">A<td id="b" colspan="2">B<tr><td>C<td>D</table>')
	layout(spans)
	assert(sb.t.CollapsedBorders.Horizontal[2][1] == nil,'Row borders cannot cut through rowspan interiors')
	assert(sb.t.CollapsedBorders.Vertical[3][1] == nil,'No internal line inside colspan')
	near(sb.b.OuterWidth,sb.t.ColumnWidths[2]+sb.t.ColumnWidths[3])
	local nested,nb=build(css..'<table id="outer"><tr><td id="cell" style="border-collapse:separate"><table id="inner" style="border-collapse:separate"><tr><td>A<td>B</table></td></tr></table>')
	layout(nested)
	assert(nb.outer.CollapsedBorders and nb.cell.Style.CollapsedBorder and not nb.inner.CollapsedBorders,'The owning table selects the border model; nested tables can override it')
	local dirty,db=build(css..'<div id="before" style="height:8px"></div><table id="t" style="width:100%"><tr><td><output id="out">A</output></td><td>one two three four</td></tr></table><div id="after">After</div>')
	Dirty.begin(dirty); layout(dirty,130); Dirty.finish(dirty,true)
	local count=#created; local original=db.t.TableBorderPaint.Pool[1].Gui
	layout(dirty,220); layout(dirty,130)
	assert(#created == count and db.t.TableBorderPaint.Pool[1].Gui == original,'Resizing reuses the border objects')
	local control=dirty.Controls[1]
	control.Value='longer output'; control.Item.ControlMeasureKey=nil
	Dirty.begin(dirty,{[control.Item]=true}); layout(dirty,130); Dirty.finish(dirty,true)
	local width,height,after=db.t.OuterWidth,db.t.OuterHeight,db.after.LayoutY
	Dirty.begin(dirty); layout(dirty,130); Dirty.finish(dirty,true)
	near(db.t.OuterWidth,width); near(db.t.OuterHeight,height); near(db.after.LayoutY,after)
	assert(HitTest.pick({control.Item.Gui},dirty.HitNodes,dirty.Gui) == control.Node,'Cell controls retain their DOM hit targets')
	local empty,eb=build('<table id="t" style="border-collapse:collapse"></table>')
	layout(empty); assert(eb.t.OuterWidth == 0 and eb.t.OuterHeight == 0)
	print('Collapsed tables: shared half-borders, conflict priority/hidden, spans, spacing/padding, nested models, border reuse, hit targets and partial/full layout passed')
end
