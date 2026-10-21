--!strict
-- Logical tracks retain their measurements. Projection removes collapsed tracks
-- only from painted geometry and the collapsed-border model.
local Tracks={}
local function mapTracks(count: number, hidden: any): any
	local indices,before={}, {[0]=0}
	for i=1,count do if not hidden[i] then table.insert(indices,i) end; before[i]=#indices end
	return {Indices=indices,Before=before,Hidden=hidden}
end
function Tracks.span(map: any, first: number, count: number): (number,number)
	return map.Before[first-1]+1,map.Before[first+count-1]-map.Before[first-1]
end
function Tracks.prepare(box: any): any
	local rows,cols={},{}
	for i,row in box.TableRows do rows[i]=row.Box.Style.VisibilityCollapse or (row.Group and row.Group.Style.VisibilityCollapse) or false end
	for i,column in box.TableColumns or {} do cols[i]=column.Style.VisibilityCollapse or (column.Group and column.Group.Style.VisibilityCollapse) or false end
	local rm,cm=mapTracks(#box.TableRows,rows),mapTracks(box.TableGrid.Columns,cols)
	box.RowTracks,box.ColumnTracks=rm,cm
	local proxy={Style=box.Style,Node=box.Node,TableBorderSource=box.TableBorderSource,TableRows={},TableColumns={},TableColumnGroups={},TableGrid={Entries={},Columns=#cm.Indices}}
	for _,i in rm.Indices do table.insert(proxy.TableRows,box.TableRows[i]) end
	for _,i in cm.Indices do table.insert(proxy.TableColumns,box.TableColumns[i] or {Style={},Node={Name=""}}) end
	for _,group in box.TableColumnGroups or {} do
		local first,count=Tracks.span(cm,group.First,group.Count)
		if count > 0 then local g=table.clone(group); g.First,g.Count=first,count; table.insert(proxy.TableColumnGroups,g) end
	end
	for _,e in box.TableGrid.Entries do
		local r,rs=Tracks.span(rm,e.Row,e.RowSpan)
		local c,cs=Tracks.span(cm,e.Column,e.ColSpan)
		e.VisibleRow,e.VisibleRows,e.VisibleColumn,e.VisibleColumns=r,rs,c,cs
		if rs > 0 and cs > 0 then table.insert(proxy.TableGrid.Entries,{Cell=e.Cell,Row=r,RowSpan=rs,Column=c,ColSpan=cs}) end
	end
	return proxy
end
function Tracks.values(map: any, original: any): any
	local result={}
	for _,i in map.Indices do table.insert(result,original[i]) end
	return result
end
function Tracks.positions(values: any, gap: number): (any,number)
	local starts={}; local at=if #values > 0 then gap else 0
	for i,size in values do starts[i]=at; at+=size+gap end
	starts[#values+1]=at
	return starts,at
end
return Tracks
