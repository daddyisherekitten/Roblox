--!strict
-- Slot assignment is independent of text measurement and GUI geometry.
local Grid = {}
local MAX_COLUMNS = 4096

local function span(raw: string?, maximum: number, zero: boolean): number
	local digits=if raw then raw:match("^[ \t\r\n\f]*%+?(%d+)") else nil
	local value=if digits then tonumber(digits) else nil
	if not value or (value == 0 and not zero) then return 1 end
	return math.min(maximum,value)
end

function Grid.build(rows: any, diagnostic: any): any
	-- Finish each group with numeric raster rows required by positive rowspans.
	-- No DOM nodes or GUIs are needed for these implicit rows.
	local expanded={}
	local at=1
	while at <= #rows do
		local last=at
		while last < #rows and rows[last+1].Scope == rows[at].Scope do last+=1 end
		local count=last-at+1
		for i=at,last do
			table.insert(expanded,rows[i])
			for _,cell in rows[i].Cells do
				count=math.max(count,i-at+span(cell.Node.Attributes.rowspan,65534,true))
			end
		end
		assert(#expanded+count-(last-at+1) <= 65534,"Table exceeds 65534 raster rows")
		for _=last-at+2,count do
			table.insert(expanded,{Implicit=true,Scope=rows[at].Scope,Group=rows[at].Group,Cells={},
				Box={Style={TableRole="row",BorderSize=0,BorderWidth=0,BorderStyle="none",Padding={0,0,0,0}}}})
		end
		at=last+1
	end
	table.clear(rows)
	for _,row in expanded do table.insert(rows,row) end
	local entries,columns={},0
	local first=1
	while first <= #rows do
		local last=first
		while last < #rows and rows[last+1].Scope == rows[first].Scope do last+=1 end
		local occupied={}
		for rowIndex=first,last do
			local column=1
			for _,cell in rows[rowIndex].Cells do
				local cols=span(cell.Node.Attributes.colspan,1000,false)
				local requested=span(cell.Node.Attributes.rowspan,65534,true)
				local remaining=last-rowIndex+1
				local count=if requested == 0 then remaining else math.min(requested,remaining)
				-- Valid tables never overlap slots. For malformed overlaps, move to
				-- the next free run rather than painting two cells into the same slot.
				while column+cols-1 <= MAX_COLUMNS do
					local conflict
					for i=column,column+cols-1 do if (occupied[i] or 0) >= rowIndex then conflict=i; break end end
					if not conflict then break end
					column=conflict+1
				end
				assert(column+cols-1 <= MAX_COLUMNS,"Table exceeds 4096 columns")
				local entry={Cell=cell,Row=rowIndex,Column=column,ColSpan=cols,RowSpan=count}
				table.insert(entries,entry)
				for i=column,column+cols-1 do occupied[i]=rowIndex+count-1 end
				column+=cols
				columns=math.max(columns,column-1)
			end
		end
		first=last+1
	end
	return {Entries=entries,Columns=columns}
end

function Grid.extent(values: any, first: number, count: number, gap: number): number
	local result=gap*(count-1)
	for i=first,first+count-1 do result+=values[i] end
	return result
end

-- Monotone constraints: enlarging a span never invalidates an earlier one.
function Grid.ensure(values: any, first: number, count: number, gap: number, target: number)
	local extra=target-Grid.extent(values,first,count,gap)
	if extra <= 0 then return end
	local sum=0
	for i=first,first+count-1 do sum+=values[i] end
	for i=first,first+count-1 do values[i]+=extra*(if sum > 0 then values[i]/sum else 1/count) end
end

return Grid
