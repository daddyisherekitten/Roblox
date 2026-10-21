--!strict
--!optimize 2
local Geometry = require(script.Parent.BorderGeometry)
local Grid = require(script.Parent.TableGrid)
local BoxSpacing = require(script.Parent.BoxSpacing)
local TableBorders = require(script.Parent.TableBorders)
local TableBorderPaint = require(script.Parent.Parent.Rendering.TableBorderPaint)
local TableColumns = require(script.Parent.TableColumns)
local TableColumnPaint = require(script.Parent.Parent.Rendering.TableColumnPaint)
local Captions = require(script.Parent.TableCaptions)
local Heights = require(script.Parent.TableHeights)
local Tracks = require(script.Parent.TableTracks)
local TableLayout = {}
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local Style=require(script.Parent.Parent.CSS.InlineStyle)

-- Table cells have two sizing phases. Keep their natural measurements apart
-- from the live, stretched geometry; a reused probe must not undo placement.
-- Ordinary cells remain reusable inside a scrolling table, while descendants
-- with positioning, scrolling, opacity or percentage-height dependencies keep
-- the normal path.
local function context(cell: any): any?
	local c=cell.DirtyContext
	return if c and c.Active and cell.CanTranslateLayout and not cell.UsesHeightBasis then c else nil
end
local function edges(cell: any): any
	local t,r,b,l=Geometry.sizes(cell.Style)
	local p=cell.Style.Padding
	return {t,r,b,l,p[1],p[2],p[3],p[4]}
end
local function same(a: any,b: any): boolean
	for key,value in a do if b[key]~=value then return false end end
	for key,value in b do if a[key]~=value then return false end end
	return true
end
local function reusable(cell: any,c: any,cache: any,input: any): boolean
	return c~=nil and c.Reuse and not c.Dirty[cell] and cache~=nil and cache.Generation==c.Generation
		and same(cache.Input,input) and same(cache.Edges,edges(cell))
end
local function save(cell: any,c: any,input: any,result: any): any?
	return if c then {Generation=c.Generation,Input=input,Edges=edges(cell),Result=result} else nil
end
local function naturalWidths(cell: any,available: number,natural: any,alive: any): (number,number)
	BoxSpacing.resolve(cell.Style,available)
	local c=context(cell);local input={Available=available,QuirksMode=cell.QuirksMode==true};local cache=cell.TableIntrinsicWidths
	if reusable(cell,c,cache,input) then
		c.Stats.MeasurementReused=(c.Stats.MeasurementReused or 0)+2
		return cache.Result.Min,cache.Result.Max
	end
	-- An automatic column may shrink below a preferred cell width, but not
	-- below its content minimum. Explicit widths are preferences, except for
	-- the legacy nowrap/nonzero-length minimum-width rule.
	local lo=natural(cell,available,alive,true,true)
	local hi=if alive() then natural(cell,available,alive,false,true) else lo
	local s=cell.Style;local value=s.Width
	if value and not value.Intrinsic then
		local _,r,_,l=Geometry.sizes(s)
		local outer=LengthExpression.resolve(value,available)+(if s.BoxSizing=='border-box'then 0 else r+l+s.Padding[2]+s.Padding[4])
		hi=math.max(hi,outer)
		local node=cell.Node
		if cell.QuirksMode and node and(node.Name=='td'or node.Name=='th')and node.Attributes.nowrap~=nil
			and(node.NamespaceURI==nil or node.NamespaceURI=='http://www.w3.org/1999/xhtml')and not value.Percent and LengthExpression.resolve(value,0)~=0 then
			lo=math.max(lo,outer)
		end
	end
	if alive() then cell.TableIntrinsicWidths=save(cell,c,input,{Min=lo,Max=hi}) end
	return lo,hi
end

local function anonymous(parent,role,children)
	local node={Kind='Element',Name='div',Attributes={},Children={},Parent=parent.Node}
	local style=Style.resolve(node,parent.Style,function()end)
	style.TableRole=role;style.Display=if role=='row'then 'table-row'else 'table-cell'
	style.Margin,style.MarginValues,style.Padding,style.PaddingValues={0,0,0,0},{0,0,0,0},{0,0,0,0},{0,0,0,0}
	style.TableBorderMode=parent.Style.TableBorderMode or parent.Style.BorderCollapse
	style.CollapsedBorder=style.TableBorderMode=='collapse'
	local gui=parent.Factory.create('Frame',parent.ContentHost or parent.Gui,{Name='AnonymousTable_'..role,BackgroundTransparency=1})
	local box={Node=node,Kind='Block',Style=style,Children=children,Gui=gui,Factory=parent.Factory,AnonymousTable=true}
	for _,child in children do
		if child.Kind=='Words'then
			for _,item in child.Items do if item.Gui then item.Gui.Parent=gui end end
		elseif child.Gui then child.Gui.Parent=gui end
	end
	return box
end
-- CSS display fixup changes only the box tree, preserving original DOM ancestry.
local function normalize(parent,role)
	local result,pending={},{}
	local function flush()
		if #pending==0 then return end
		local wrapper=anonymous(parent,if role=='row'then 'cell'else 'row',pending)
		if role~='row'then normalize(wrapper,'row')end
		table.insert(result,wrapper);pending={}
	end
	for _,child in parent.Children do
		local childRole=child.Style.TableRole
		local proper=if role=='row'then childRole=='cell'else childRole=='row' or role=='table'and (childRole=='group'or childRole=='caption')
		if child.Kind=='Words'and #child.Items==0 then continue end
		if proper then
			flush();table.insert(result,child)
			if childRole=='row'or childRole=='group'then normalize(child,childRole)end
		else table.insert(pending,child)end
	end
	flush();parent.Children=result
end

function TableLayout.prepare(box: any, diagnostic: any)
	box.CollapsedBorders=nil
	normalize(box,'table')
	local rows, groups, captions = {}, {}, {}
	for _,child in box.Children do
		if child.Style.TableRole == "caption" then table.insert(captions,child) end
	end
	local directScope={}
	local function addRow(row: any, group: any?)
		local cells={}
		for _,cell in row.Children do
			if cell.Style.TableRole == "cell" then
				table.insert(cells,cell)
			elseif cell.Kind ~= "Words" or #cell.Items > 0 then diagnostic("table: non-cell row content is not supported") end
		end
		table.insert(rows,{Box=row,Group=group,Scope=group or directScope,Cells=cells})
	end
	-- Header/footer order is visual only; event and selector ancestry stays intact.
	for _,phase in {"head","body","foot"} do
		for _,child in box.Children do
			if child.Style.TableRole == "caption" then continue end
			local name=if child.Node then child.Node.Name else ""
			local category=child.Style.TableGroupKind or (if name == "thead" then "head" elseif name == "tfoot" then "foot" else "body")
			if category ~= phase then continue end
			if child.Style.TableRole == "row" then addRow(child,nil)
			elseif child.Style.TableRole == "group" then
				directScope={}
				table.insert(groups,child)
				child.TableFirstRow=#rows+1
				for _,row in child.Children do
					if row.Style.TableRole == "row" then addRow(row,child)
					elseif row.Kind ~= "Words" or #row.Items > 0 then diagnostic("table: non-row group content is not supported") end
				end
				child.TableEmpty=#rows<child.TableFirstRow
			elseif child.Kind ~= "Words" or #child.Items > 0 then diagnostic("table: non-row content outside a caption is not supported") end
		end
	end
	box.TableRows,box.TableGroups,box.TableCaptions=rows,groups,captions
	box.TableGrid=Grid.build(rows,diagnostic)
	box.TableGrid.Columns=math.max(box.TableGrid.Columns,#(box.TableColumns or {}))
	local projected=Tracks.prepare(box)
	TableBorders.prepare(projected)
	box.CollapsedBorders=projected.CollapsedBorders
end

function TableLayout.measure(box: any, available: number, natural: any, alive: any): any
	local spacing=if box.CollapsedBorders then {0,0} else box.Style.BorderSpacing or {2,2}
	if box.Style.TableLayout == "fixed" and box.Style.Width then return TableColumns.fixed(box,available,spacing[1]) end
	local minimum,preferred=table.create(box.TableGrid.Columns,0),table.create(box.TableGrid.Columns,0)
	local spans={}
	for index,entry in box.TableGrid.Entries do
		local lo,hi=naturalWidths(entry.Cell,available,natural,alive)
		if not alive() then return nil end
		local i=entry.Column
		if entry.ColSpan == 1 then
			minimum[i]=math.max(minimum[i],lo)
			preferred[i]=math.max(preferred[i],lo,hi)
		else table.insert(spans,{Entry=entry,Min=lo,Max=math.max(lo,hi),Order=index}) end
	end
	table.sort(spans,function(a,b) return if a.Entry.ColSpan == b.Entry.ColSpan then a.Order < b.Order else a.Entry.ColSpan < b.Entry.ColSpan end)
	for _,s in spans do Grid.ensure(minimum,s.Entry.Column,s.Entry.ColSpan,spacing[1],s.Min) end
	for i,lo in minimum do preferred[i]=math.max(preferred[i],lo) end
	for _,s in spans do Grid.ensure(preferred,s.Entry.Column,s.Entry.ColSpan,spacing[1],s.Max) end
	for i,column in box.TableColumns or {} do
		if column.Width then
			minimum[i]=math.max(minimum[i],TableColumns.length(column.Width,available))
			preferred[i]=math.max(preferred[i],minimum[i])
		end
	end
	local gaps=if #minimum > 0 then (#minimum+1)*spacing[1] else 0
	local lo,hi=gaps,gaps
	for i,value in minimum do lo+=value; hi+=preferred[i] end
	return Captions.measure(box,{Min=lo,Max=hi,Minimum=minimum,Preferred=preferred,Gaps=gaps},available,natural,alive)
end

function TableLayout.columns(measured: any, width: number): any
	if measured.Fixed then return TableColumns.distribute(measured,width) end
	local widths={}
	local count=#measured.Minimum
	local lo,hi=measured.GridMin or measured.Min,measured.GridMax or measured.Max
	local room=math.max(measured.Min,width)-lo
	local flexibility=hi-lo
	for i,lo in measured.Minimum do
		local share=if room <= flexibility and flexibility > 0 then (measured.Preferred[i]-lo)/flexibility
			elseif count > 0 then 1/count else 0
		widths[i]=if room <= flexibility then lo+room*share else measured.Preferred[i]+(room-flexibility)*share
	end
	return widths
end

local function place(box: any,x: number,y: number,width: number,height: number)
	if box.Gui then
		local position,size=UDim2.fromOffset(x,y),UDim2.fromOffset(width,height)
		if box.Gui.Position~=position then box.Gui.Position=position end
		if box.Gui.Size~=size then box.Gui.Size=size end
	end
	box.LayoutX,box.LayoutY=x,y
	box.OuterWidth,box.OuterHeight=width,height
	box.ContentWidth,box.ContentHeight=width,height
	box.LocalRight,box.LocalBottom,box.OwnBottom=width,height,height
	box.UnclippedRight,box.UnclippedBottom=width,height
end

function TableLayout.arrange(box: any,width: number,measured: any,arrange: any,alive: any,requestedHeight: number?): (number,number,number,number?)
	local spacing=if box.CollapsedBorders then {0,0} else box.Style.BorderSpacing or {2,2}
	local widths=TableLayout.columns(measured,width)
	box.ColumnWidths=widths
	local _,_,_,bl=Geometry.sizes(box.Style)
	local left=bl+box.Style.Padding[4]
	local top=box.ContentTop
	box.TablePaintLeft,box.TablePaintTop=left,top
	local starts=Tracks.positions(widths,spacing[1])
	local paintedWidths=Tracks.values(box.ColumnTracks,widths)
	local columnStarts,paintedWidth=Tracks.positions(paintedWidths,spacing[1])
	if #paintedWidths == #widths then paintedWidth=width end
	box.PaintedColumnWidths=paintedWidths
	local heights,baselines,descents,sizes={},{},{},{}
	local visibleRows={}
	for i,row in box.TableRows do
		heights[i]=if row.Box.Style.Height and not row.Box.Style.Height.Percent then LengthExpression.resolve(row.Box.Style.Height,0) else 0
		if #row.Cells == 0 then visibleRows[i]=true end
		baselines[i],descents[i]=0,0
	end
	-- Measure every cell once at its complete spanned width, including inner gaps.
	for i,entry in box.TableGrid.Entries do
		if not alive() then return 0,0,0 end
		local cell=entry.Cell
		cell.HeightBasis=nil
		TableColumnPaint.updateEmpty(cell)
		if not cell.EmptyCellHidden then
			for row=entry.Row,entry.Row+entry.RowSpan-1 do visibleRows[row]=true end
		end
		local cellWidth=Grid.extent(widths,entry.Column,entry.ColSpan,spacing[1])
		BoxSpacing.resolve(cell.Style,width)
		local t,r,b,l=Geometry.sizes(cell.Style)
		local vertical=t+b+cell.Style.Padding[1]+cell.Style.Padding[3]
		local content=math.max(0,cellWidth-r-l-cell.Style.Padding[2]-cell.Style.Padding[4])
		local c=context(cell)
		local input={Width=cellWidth,SpacingWidth=width,ContentWidth=content,QuirksMode=cell.QuirksMode==true}
		local cache=cell.TableNaturalSize
		local h,base
		if reusable(cell,c,cache,input) then
			h,base=cache.Result.Height,cache.Result.Baseline
			c.Stats.MeasurementReused=(c.Stats.MeasurementReused or 0)+1
		else
			cell.TablePlacedLayout=nil
			arrange(cell,cellWidth,starts[entry.Column],0,alive,true,{TableCell=true,SpacingWidth=width,ContentWidth=content})
			if not alive() then return 0,0,0 end
			h=cell.OuterHeight
			base=cell.FirstBaseline or h-b-cell.Style.Padding[3]
			cell.TableNaturalSize=save(cell,c,input,{Height=h,Baseline=base})
		end
		local row=entry.Row
		if cell.Style.VerticalAlign == "baseline" then
			baselines[row]=math.max(baselines[row],base)
			if entry.RowSpan == 1 then descents[row]=math.max(descents[row],h-base) end
		end
		if entry.RowSpan == 1 then heights[row]=math.max(heights[row],h) end
		sizes[i]={Height=h,Baseline=base,Edges=vertical,Content=content,Width=cellWidth}
	end
	for i,height in heights do heights[i]=if visibleRows[i] then math.max(height,baselines[i]+descents[i]) else 0 end
	local spans={}
	for i,entry in box.TableGrid.Entries do if entry.RowSpan > 1 then table.insert(spans,{Index=i,Entry=entry}) end end
	table.sort(spans,function(a,b) return if a.Entry.RowSpan == b.Entry.RowSpan then a.Index < b.Index else a.Entry.RowSpan < b.Entry.RowSpan end)
	for _,span in spans do
		local e,size=span.Entry,sizes[span.Index]
		local anyVisible=false
		for row=e.Row,e.Row+e.RowSpan-1 do if visibleRows[row] then anyVisible=true; break end end
		if not anyVisible then continue end
		local offset=if e.Cell.Style.VerticalAlign == "baseline" then baselines[e.Row]-size.Baseline else 0
		local zero=true;for row=e.Row,e.Row+e.RowSpan-1 do if heights[row]>0 then zero=false;break end end
		if zero then
			local last=e.Row+e.RowSpan-1
			heights[last]=math.max(0,size.Height+offset-(e.RowSpan-1)*spacing[2])
		else Grid.ensure(heights,e.Row,e.RowSpan,spacing[2],size.Height+offset)end
	end
	local emptyGroups,emptyHeight=Heights.empty(box,requestedHeight)
	Heights.distribute(box,heights,spacing[2],if requestedHeight then math.max(0,requestedHeight-emptyHeight)else nil)
	local paintedHeights=Tracks.values(box.RowTracks,heights)
	local paintedTops,y=Tracks.positions(paintedHeights,spacing[2])
	local rowTops={}
	for i in box.TableRows do rowTops[i]=paintedTops[box.RowTracks.Before[i-1]+1] or y end
	local emptyOffset,emptyIndex=0,1
	for i=1,#box.TableRows+1 do
		local origin=math.max(0,(if i<=#box.TableRows then rowTops[i]else y)-spacing[2])
		while emptyGroups[emptyIndex]and emptyGroups[emptyIndex].First==i do
			local empty=emptyGroups[emptyIndex];empty.Top=origin+emptyOffset
			emptyOffset+=empty.Height;emptyIndex+=1
		end
		if i<=#box.TableRows then rowTops[i]+=emptyOffset end
	end
	y+=emptyOffset
	local _,fullHeight=Tracks.positions(heights,spacing[2])
	box.CollapsedTrackHeightLoss=fullHeight+emptyHeight-y
	box.RowHeights,box.PaintedRowHeights=heights,paintedHeights
	local groupBounds={}
	for _,empty in emptyGroups do groupBounds[empty.Group]={Top=top+empty.Top,Bottom=top+empty.Top+empty.Height}end
	local farRight,farBottom=paintedWidth,0
	for i,entry in box.TableGrid.Entries do
		local cell,size=entry.Cell,sizes[i]
		local visible=entry.VisibleRows > 0 and entry.VisibleColumns > 0
		cell.CollapsedByTable=not visible
		cell.Gui.Visible=visible
		if not visible then
			for _,gui in cell.ColumnBackgrounds or {} do gui.Visible=false end
			continue
		end
		local height=Grid.extent(paintedHeights,entry.VisibleRow,entry.VisibleRows,spacing[2])
		local cellWidth=Grid.extent(paintedWidths,entry.VisibleColumn,entry.VisibleColumns,spacing[1])
		local collapsed=entry.VisibleRows ~= entry.RowSpan or entry.VisibleColumns ~= entry.ColSpan
		local align=cell.Style.VerticalAlign
		local offset=if align == "top" then 0 elseif align == "bottom" then height-size.Height
			elseif align == "baseline" then baselines[entry.Row]-size.Baseline else (height-size.Height)/2
		local cellX=columnStarts[entry.VisibleColumn]
		if box.Style.Direction == "rtl" then cellX=paintedWidth-cellX-cellWidth end
		local tableCellX=cellX
		cellX-=spacing[1]
		local _,r,_,l=Geometry.sizes(cell.Style)
		local content=math.max(0,cellWidth-r-l-cell.Style.Padding[2]-cell.Style.Padding[4])
		local sizing={TableCell=true,TableCollapsed=collapsed,TableFlowWidth=if collapsed then size.Content else nil,SpacingWidth=width,ContentWidth=content,ContentHeight=math.max(0,height-size.Edges),ContentOffset=math.max(0,offset)}
		local input=table.clone(sizing);input.Width,input.X=cellWidth,cellX
		local c=context(cell);local cache=cell.TablePlacedLayout
		local right,bottom
		if reusable(cell,c,cache,input) then
			right,bottom=cache.Result.Right,cache.Result.Bottom
			c.Stats.Reused+=1
		else
			local _,r,b=arrange(cell,cellWidth,cellX,0,alive,true,sizing)
			right,bottom=r,b
			if alive() then cell.TablePlacedLayout=save(cell,c,input,{Right=right,Bottom=bottom}) end
		end
		-- Removing rows reduces the border box, but visible overflow may still
		-- extend below it (for example wrapped text in a rowspan cell).
		cell.TableContentClipped=entry.VisibleColumns ~= entry.ColSpan
		local clipped=cell.TableContentClipped or cell.Style.Overflow == "hidden"
		-- A hidden-overflow cell owns a separate retained content clip so its
		-- outline can paint outside. Column projection still clips bare cells.
		cell.Gui.ClipsDescendants=clipped and cell.ClipContent==nil
		if cell.ClipContent then cell.ClipContent.ClipsDescendants=clipped end
		if clipped then right,bottom=cellWidth,height end
		if not alive() then return 0,0,0 end
		TableColumnPaint.updateEmpty(cell)
		TableColumnPaint.arrange(cell,height)
		farRight=math.max(farRight,tableCellX+right)
		if not cell.EmptyCellHidden then
			farBottom=math.max(farBottom,rowTops[entry.Row]+bottom)
			if box.FirstBaseline == nil then box.FirstBaseline=top+rowTops[entry.Row]+(cell.FirstBaseline or height) end
		end
	end
	for i,row in box.TableRows do
		local height=if box.RowTracks.Hidden[i] then 0 else heights[i]
		local rowY=top+rowTops[i]
		if row.Group then
			local bounds=groupBounds[row.Group]
			if not bounds then bounds={Top=rowY,Bottom=rowY}; groupBounds[row.Group]=bounds end
			bounds.Bottom=rowY+height
			place(row.Box,0,rowY-bounds.Top,math.max(0,paintedWidth-2*spacing[1]),height)
		else place(row.Box,left+spacing[1],rowY,math.max(0,paintedWidth-2*spacing[1]),height) end
	end
	for _,group in box.TableGroups do
		local bounds=groupBounds[group]
		place(group,left+spacing[1],if bounds then bounds.Top else top,math.max(0,paintedWidth-2*spacing[1]),if bounds then bounds.Bottom-bounds.Top else 0)
	end
	TableBorderPaint.arrange(box,paintedWidths,paintedHeights,left,top)
	return y,farRight,math.max(y,farBottom),paintedWidth
end

return TableLayout
