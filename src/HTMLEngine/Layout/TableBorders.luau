--!strict
-- Resolve shared grid edges once; text reflow only changes their coordinates.
local Borders = {}
local STYLE_RANK = {none=0,inset=1,groove=2,outset=3,ridge=4,dotted=5,dashed=6,solid=7,double=8,hidden=9}

function Borders.wins(a: any, b: any?): boolean
	if not b then return true end
	if a.Style == "hidden" or b.Style == "hidden" then return a.Style == "hidden" and b.Style ~= "hidden" end
	if a.Width ~= b.Width then return a.Width > b.Width end
	if STYLE_RANK[a.Style] ~= STYLE_RANK[b.Style] then return STYLE_RANK[a.Style] > STYLE_RANK[b.Style] end
	if a.Rank ~= b.Rank then return a.Rank > b.Rank end
	if a.Column ~= b.Column then return a.Column < b.Column end
	return a.Row < b.Row
end

local function candidate(box: any, side: number, rank: number, row: number, column: number): any?
	local s=box.TableBorderSource or box.Style
	local e=if s.BorderSides then s.BorderSides[side] else nil
	local kind=if e then e.Style else s.BorderStyle or "none"
	local width=if e then e.Width else s.BorderWidth or 0
	if kind == "none" or (width == 0 and kind ~= "hidden") then return nil end
	return {Style=kind,Width=if kind == "hidden" then 0 else width,
		Color=if e then e.Color else s.BorderColor,Alpha=if e then e.Alpha else s.BorderColorAlpha or 1,
		Rank=rank,Row=row,Column=column,Side=side,Node=box.Node,Visible=s.Visibility ~= "hidden"}
end

local function offer(edges: any, line: number, first: number, last: number, value: any?)
	if not value then return end
	local slots=edges[line]
	if not slots then slots={}; edges[line]=slots end
	for i=first,last do if Borders.wins(value,slots[i]) then slots[i]=value end end
end

local function widest(slots: any?, first: number, last: number): number
	local width=0
	if slots then for i=first,last do if slots[i] then width=math.max(width,slots[i].Width) end end end
	return width
end

function Borders.prepare(box: any)
	if not box.Style.CollapsedBorder then return end
	local rows,cols=#box.TableRows,box.TableGrid.Columns
	assert(rows*cols <= 1000000,"Collapsed table exceeds 1000000 raster slots")
	local rtl=box.Style.Direction == "rtl"
	local h,v={},{}
	local function perimeter(owner: any,row: number,col: number,rs: number,cs: number,rank: number)
		offer(h,row,col,col+cs-1,candidate(owner,1,rank,row,col))
		offer(h,row+rs,col,col+cs-1,candidate(owner,3,rank,row,col))
		offer(v,col,row,row+rs-1,candidate(owner,if rtl then 2 else 4,rank,row,col))
		offer(v,col+cs,row,row+rs-1,candidate(owner,if rtl then 4 else 2,rank,row,col))
	end
	if rows > 0 and cols > 0 then
		perimeter(box,1,1,rows,cols,1)
		for _,group in box.TableColumnGroups or {} do perimeter(group,1,group.First,rows,group.Count,2) end
		for c,column in box.TableColumns or {} do
			if column.Node.Name == "col" then perimeter(column,1,c,rows,1,3) end
		end
		local groups={}
		for i,row in box.TableRows do
			perimeter(row.Box,i,1,1,cols,5)
			if row.Group then
				local bounds=groups[row.Group]
				if not bounds then bounds={First=i,Last=i}; groups[row.Group]=bounds end
				bounds.Last=i
			end
		end
		for group,bounds in groups do perimeter(group,bounds.First,1,bounds.Last-bounds.First+1,cols,4) end
		for _,e in box.TableGrid.Entries do perimeter(e.Cell,e.Row,e.Column,e.RowSpan,e.ColSpan,6) end
		-- A row border must not cut across the interior of a merged cell.
		for _,e in box.TableGrid.Entries do
			for line=e.Row+1,e.Row+e.RowSpan-1 do
				if h[line] then for c=e.Column,e.Column+e.ColSpan-1 do h[line][c]=nil end end
			end
			for line=e.Column+1,e.Column+e.ColSpan-1 do
				if v[line] then for r=e.Row,e.Row+e.RowSpan-1 do v[line][r]=nil end end
			end
		end
	end
	for _,e in box.TableGrid.Entries do
		local s=e.Cell.Style
		s.BorderSizes={widest(h[e.Row],e.Column,e.Column+e.ColSpan-1)/2,
			widest(v[e.Column+e.ColSpan],e.Row,e.Row+e.RowSpan-1)/2,
			widest(h[e.Row+e.RowSpan],e.Column,e.Column+e.ColSpan-1)/2,
			widest(v[e.Column],e.Row,e.Row+e.RowSpan-1)/2}
		s.BorderSize=s.BorderSizes[1]
		if rtl then s.BorderSizes[2],s.BorderSizes[4]=s.BorderSizes[4],s.BorderSizes[2] end
	end
	box.Style.BorderSizes={widest(h[1],1,cols)/2,widest(v[cols+1],1,rows)/2,
		widest(h[rows+1],1,cols)/2,widest(v[1],1,rows)/2}
	box.Style.BorderSize=box.Style.BorderSizes[1]
	if rtl then box.Style.BorderSizes[2],box.Style.BorderSizes[4]=box.Style.BorderSizes[4],box.Style.BorderSizes[2] end
	box.CollapsedBorders={Horizontal=h,Vertical=v,Rows=rows,Columns=cols}
end

return Borders
