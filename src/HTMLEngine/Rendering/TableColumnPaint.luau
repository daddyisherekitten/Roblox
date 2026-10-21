--!strict
-- Background stack below each originating cell: column group, column, row group,
-- row. Spans share one footprint; border-spacing gaps stay transparent.
local Paint = {}
local Work=require(script.Parent.Parent.WorkContext)

function Paint.create(box: any,factory: any,registry: any)
	local oldCells=box.TablePaintCells or {};local current={}
	box.TablePaintCells={}
	for _,e in box.TableGrid.Entries do
		Work.checkpoint()
		current[e.Cell]=true
		table.insert(box.TablePaintCells,e.Cell)
		local column=(box.TableColumns or {})[e.Column]
		local layers,records,used={},{},{}
		local previous=e.Cell.ColumnBackgroundRecords or {}
		local function layer(source: any, name: string)
			local s=source.Style
			if not s.Background or s.Visibility == "hidden" then return end
			local node=source.Node or source;local gui
			for _,record in previous do
				if not used[record]and record.Node==node and record.Name==name then gui=record.Gui;used[record]=true;break end
			end
			local parent=box.TableRows[e.Row].Box.Gui
			if not gui then gui=factory.create('Frame',parent,{Name=name,ZIndex=0,Visible=false})end
			if gui.Parent~=parent then gui.Parent=parent end
			if gui.BackgroundColor3~=s.Background then gui.BackgroundColor3=s.Background end
			local transparency=1-(s.BackgroundAlpha or 1)
			if gui.BackgroundTransparency~=transparency then gui.BackgroundTransparency=transparency end
			registry[gui]=e.Cell.Node
			table.insert(layers,gui)
			table.insert(records,{Node=node,Name=name,Gui=gui})
		end
		if column and column.Group then layer(column.Group,"ColumnBackground") end
		-- A childless colgroup is already painted by its group layer.
		if column and (not column.Group or column.Node ~= column.Group.Node) then layer(column,"ColumnBackground") end
		e.Cell.ColumnBackgrounds=layers
		local row=box.TableRows[e.Row]
		if row.Group then layer(row.Group,"RowGroupBackground") end
		layer(row.Box,"RowBackground")
		for _,record in previous do if not used[record]then registry[record.Gui]=nil;record.Gui:Destroy()end end
		e.Cell.ColumnBackgroundRecords=records
	end
	for _,cell in oldCells do
		Work.checkpoint()
		if current[cell]then continue end
		for _,gui in cell.ColumnBackgrounds or{}do registry[gui]=nil;gui:Destroy()end
		cell.ColumnBackgrounds=nil;cell.ColumnBackgroundRecords=nil
	end
end

function Paint.arrange(cell: any, gridHeight: number?)
	local height=gridHeight or cell.OuterHeight
	for _,gui in cell.ColumnBackgrounds or {} do
		-- Match the browser reference: empty-cells hides the cell's own paint,
		-- while row/column backgrounds underneath remain visible.
		gui.Visible = height > 0
		local position,size=UDim2.fromOffset(cell.LayoutX,cell.LayoutY),UDim2.fromOffset(cell.OuterWidth,height)
		if gui.Position ~= position then gui.Position=position end
		if gui.Size ~= size then gui.Size=size end
	end
end

-- Collapsed white space produces no items. Empty in-flow block boxes and breaks
-- still count as content; out-of-flow descendants do not make a cell nonempty.
function Paint.updateEmpty(cell: any)
	local content=false
	for _,child in cell.Children do
		if child.Kind == "Words" then
			for _,item in child.Items do
				if item.Kind ~= "Word" or (item.Text or "") ~= "" then content=true; break end
			end
		elseif child.Style.Position ~= "absolute" then content=true end
		if content then break end
	end
	cell.EmptyCellHidden = not cell.Style.CollapsedBorder and cell.Style.EmptyCells == "hide"
		and (not content or cell.Style.Visibility == "hidden")
	if cell.CellBorder then cell.CellBorder.Visible = not cell.EmptyCellHidden end
	cell.Gui.BackgroundTransparency = if not cell.EmptyCellHidden and cell.Style.Visibility ~= "hidden" and cell.Style.Background
		then 1-(cell.Style.BackgroundAlpha or 1) else 1
	if cell.EmptyCellHidden and cell.InsetRenderer then cell.Gui.ImageTransparency=1 end
end

return Paint
