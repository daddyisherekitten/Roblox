--!strict
return function(Parser,Node,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout)
	local objects={}
	local factory={}
	function factory.create(class,parent,props)
		local gui=table.clone(props);gui.Parent=parent;gui.Visible=true;gui.ClassName=class
		function gui:Destroy()
			self.Destroyed=true
			for _,child in objects do if child.Parent==self and not child.Destroyed then child:Destroy()end end
			self.Parent=nil
		end
		table.insert(objects,gui);return gui
	end
	factory.modifier=factory.create
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},
		['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local function encode(value)
		if type(value)~='table'then return tostring(value)end
		local keys={};for key in value do table.insert(keys,key)end
		table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
		local result={};for _,key in keys do table.insert(result,tostring(key)..'='..encode(value[key]))end
		return '{'..table.concat(result,',')..'}'
	end
	local guiFields={'Position','Size','Visible','CanvasSize','CanvasPosition','ClipsDescendants','AnchorPoint',
		'BackgroundColor3','BackgroundTransparency','TextColor3','TextTransparency','Rotation','Text'}
	local boxFields={'OuterWidth','OuterHeight','ContentWidth','ContentHeight','LayoutX','LayoutY','LocalRight','LocalBottom',
		'UnclippedRight','UnclippedBottom','FirstBaseline','ColumnWidths','RowHeights','PaintedColumnWidths','PaintedRowHeights','CaptionTop','TableGridHeight'}
	local function snapshot(tree)
		local result={}
		for _,gui in objects do if not gui.Destroyed then
			local parts={};for _,field in guiFields do table.insert(parts,field..':'..encode(gui[field]))end
			result[gui]=table.concat(parts,'|')
		end end
		for _,box in tree.NodeBoxes do
			local parts={};for _,field in boxFields do table.insert(parts,field..':'..encode(box[field]))end
			result[box]=table.concat(parts,'|')
		end
		result[tree]=encode({tree.OuterWidth,tree.OuterHeight,tree.LocalRight,tree.LocalBottom})
		return result
	end
	local function arrange(tree,width,targets)
		local stats=Dirty.begin(tree,targets)
		layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)
		return stats
	end
	local function check(tree,width,targets,label,inspect)
		local partial=arrange(tree,width,targets)
		if inspect then inspect(partial)end
		local expected=snapshot(tree)
		local full=arrange(tree,width,nil);local actual=snapshot(tree)
		for object,geometry in expected do assert(actual[object]==geometry,label..' differs from full layout')end
		for object in actual do assert(expected[object],label..' allocated a missing full-layout surface')end
		return partial,full
	end
	local function build(extra,rows,columns,scrollStyle)
		local document=Parser.parse('<style>table{width:100%;border-spacing:3px}td,th{padding:3px;border:1px solid #314a32}'..(extra or '')..'</style>'..
			'<div id="scroll" style="'..(scrollStyle or 'overflow:auto')..'"><table id="table">'..(columns or '')..'<caption id="caption">Projects</caption><thead><tr><th colspan="2">Heading</th></tr></thead><tbody id="body">'..
			rows..'</tbody></table></div><p id="after">Following content</p><div id="other" style="height:40px">Unchanged branch</div>')
		local tree=loadRenderTree(factory).build(document,factory.create('Frame',nil,{}),error,function(font)return font end)
		arrange(tree,260,nil);return document,tree
	end
	local function move(document,tree,id,before)
		local row=assert(Node.findById(document,id));local body=assert(Node.findById(document,'body'))
		Node.insertBefore(body,row,if before then Node.findById(document,before)else nil)
		local needed,targets=tree:ApplyDOMChanges({[body]={Children=true}})
		assert(needed and targets and next(targets),'Moving a row must schedule its native table owners')
		return targets
	end
	local plainRows='<tr id="one"><td id="a">First project</td><td>Short note</td></tr><tr id="two"><td>Second project</td><td>Another note</td></tr>'
	for _,collapse in {'separate','collapse'}do
		local document,tree=build('table{border-collapse:'..collapse..'}#other.grown{padding:13px;font-size:19px}',plainRows,
			'<colgroup><col id="column"><col></colgroup>')
		local tableBox=tree.NodeBoxes[Node.findById(document,'table')]
		local cell=tree.NodeBoxes[Node.findById(document,'a')]
		local grid,natural,placement=tableBox.TableGrid,cell.TableNaturalSize,cell.TablePlacedLayout
		local other=Node.findById(document,'other');other.Attributes.class='grown'
		-- A class write forces the stylesheet scope to consider the whole tree.
		local needed,targets=tree:ApplyDOMChanges({[other]={Attributes={class=true}}})
		assert(needed and not targets[tableBox],'Geometry changes in another card must not invalidate an unchanged table')
		assert(tableBox.TableGrid==grid,'A global selector scope must not rebuild an unchanged table model')
		check(tree,260,targets,'Global cascade with geometry changes outside '..collapse..' table',function(stats)
			assert(stats.Reused>0 and cell.TableNaturalSize==natural and cell.TablePlacedLayout==placement,
				'An unrelated geometry change must leave native table measurements and placement untouched')
		end)
		for _,change in {{'a','font-size:24px;padding:11px'},{'one','height:80px'},
			{'column','width:140px'},{'table','height:240px;width:220px'}}do
			local node=Node.findById(document,change[1]);node.Attributes.style=change[2]
			local changed,items=tree:ApplyDOMChanges({[node]={Attributes={style=true}}});assert(changed)
			check(tree,260,items,'Genuine '..change[1]..' geometry change in '..collapse..' table')
		end
	end
	do
		local document,tree=build('td,th{border-color:currentcolor}#other.grown{padding:13px;font-size:19px}',plainRows,nil,'overflow:auto;border-collapse:collapse;color:#334455')
		local tableBox=tree.NodeBoxes[Node.findById(document,'table')]
		assert(tableBox.CollapsedBorders,'The table inherits border-collapse from its local ancestor')
		local scroll=Node.findById(document,'scroll');local color=Color3.fromRGB(204,0,170)
		local cell=tree.NodeBoxes[Node.findById(document,'a')];local natural=cell.TableNaturalSize
		scroll.Attributes.style='overflow:auto;border-collapse:collapse;color:#cc00aa'
		local needed,targets=tree:ApplyDOMChanges({[scroll]={Attributes={style=true}}})
		assert(not needed and not next(targets),'Inherited collapsed-border color changes must only repaint')
		assert(cell.TableNaturalSize==natural and tableBox.CollapsedBorders.Horizontal[1][1].Color==color)
		for _,edge in tableBox.TableBorderPaint.Pool do
			if edge.Gui.Visible then assert(edge.Gui.BackgroundColor3==color,'Inherited currentcolor must repaint native shared borders')end
		end
		-- Mixing unrelated reflow and table paint still preserves cell geometry.
		local other=Node.findById(document,'other');other.Attributes.class='grown'
		scroll.Attributes.style='overflow:auto;border-collapse:collapse;color:#115533'
		local changed,items=tree:ApplyDOMChanges({[scroll]={Attributes={style=true}},[other]={Attributes={class=true}}})
		assert(changed and not items[tableBox],'Unrelated reflow must not promote a table color change to table reflow')
		local placement=cell.TablePlacedLayout
		check(tree,260,items,'Mixed unrelated geometry and inherited collapsed-border paint',function()
			assert(cell.TableNaturalSize==natural and cell.TablePlacedLayout==placement)
			for _,edge in tableBox.TableBorderPaint.Pool do
				if edge.Gui.Visible then assert(edge.Gui.BackgroundColor3==Color3.fromRGB(17,85,51))end
			end
		end)
		scroll.Attributes.style='overflow:auto;border-collapse:separate;color:#cc00aa'
		changed,items=tree:ApplyDOMChanges({[scroll]={Attributes={style=true}}});assert(changed)
		check(tree,260,items,'Inherited border-collapse changes from a local ancestor')
		assert(not tableBox.CollapsedBorders)
	end
	for _,collapse in {'separate','collapse'}do
		local document,tree=build('table{border-collapse:'..collapse..'}',plainRows)
		local tableBox=tree.NodeBoxes[Node.findById(document,'table')]
		local width,height=tableBox.OuterWidth,tableBox.OuterHeight
		local p,f=check(tree,260,{[tableBox]='children'},'Unchanged ordinary cells in '..collapse..' scrolling table')
		assert(p.Recomputed<f.Recomputed and p.Reused>0 and(p.MeasurementReused or 0)>0,
			'Unchanged table cells must reuse actual natural measurements and final placement')
		for _=1,3 do
			local p,f=check(tree,260,move(document,tree,'one',nil),'Repeated '..collapse..' row reorder')
			assert(p.Recomputed<f.Recomputed and p.Reused>0 and(p.MeasurementReused or 0)>0,
				'Row reordering must preserve unchanged cell measurements and unaffected branches')
			assert(tableBox.OuterWidth==width and tableBox.OuterHeight==height)
			check(tree,260,move(document,tree,'one','two'),'Restored row order')
		end
		-- Content and changed available widths must invalidate their measurements.
		local cell=Node.findById(document,'a')
		for _,child in table.clone(cell.Children)do Node.removeChild(cell,child)end
		Node.append(cell,Node.text('An unbreakable much wider project name and a wrapped second line'))
		local needed,targets=tree:ApplyDOMChanges({[cell]={Children=true}});assert(needed)
		check(tree,260,targets,'Changed cell content')
		check(tree,180,{[tableBox]='children'},'Narrower table width')
		check(tree,420,{[tableBox]='children'},'Wider table width')
	end
	for _,collapse in {'separate','collapse'}do
		local document,tree=build('table{border-collapse:'..collapse..'}tbody tr:nth-child(odd) td{padding:9px 4px;border-top:7px solid red}'..
			'tbody tr:nth-child(even) td{font-size:22px}caption{caption-side:bottom}',plainRows)
		local cell=tree.NodeBoxes[Node.findById(document,'a')];local font=cell.Style.FontSize
		check(tree,260,move(document,tree,'one',nil),'Structural selectors and '..collapse..' border winners')
		assert(cell.Style.FontSize==22 and cell.Style.Padding[1]==3,'Moved cells must acquire the new nth-child geometry')
		check(tree,260,move(document,tree,'one','two'),'Restored structural selector geometry')
		assert(cell.Style.FontSize==font and cell.Style.Padding[1]==9)
	end
	local document,tree=build('table{border-collapse:collapse}',
		'<tr id="one"><td id="span" rowspan="2" style="vertical-align:baseline">A longer spanning cell with overflow</td><td>X</td></tr>'..
		'<tr id="two"><td style="height:45px">Y</td></tr><tr id="three"><td>Z</td><td>Last</td></tr>')
	check(tree,260,move(document,tree,'three','one'),'Moved rows around a spanning cell')
	check(tree,260,{[tree.NodeBoxes[Node.findById(document,'table')]]='children'},'Unchanged spanning cell reuse')
	check(tree,170,move(document,tree,'three',nil),'Changed rowspan placement and track widths')
	document,tree=build('table{height:140px}',
		'<tr id="one"><td><div style="height:50%;aspect-ratio:2">Percent</div></td><td>A</td></tr>'..
		'<tr id="two"><td><div style="position:relative;height:35px"><span style="position:absolute;left:7px">Positioned</span></div></td><td>B</td></tr>')
	check(tree,260,move(document,tree,'one',nil),'Height-dependent and positioned cell fallback')
	print('TableIncremental: actual row/cell reuse, separate/collapsed border paint, spans, structural selectors, content/width invalidation, captions, overflow and conservative dependency fallback match full layout')
end
