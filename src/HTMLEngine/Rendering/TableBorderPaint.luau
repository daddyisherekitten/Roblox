--!strict
local PaintLayer=require(script.Parent.PaintLayer)
local Geometry = require(script.Parent.Parent.Layout.BorderGeometry)
local Borders = require(script.Parent.Parent.Layout.TableBorders)
local Paint = require(script.Parent.BorderPaint)
local TableBorderPaint = {}

local function write(gui: any,key: string,value: any)
	if gui[key] ~= value then gui[key]=value end
end

local function same(a: any,b: any): boolean
	return a.Width == b.Width and a.Style == b.Style and a.Color == b.Color and a.Alpha == b.Alpha and a.Visible == b.Visible
		and a.Rank == b.Rank and a.Row == b.Row and a.Column == b.Column
end

local function intersection(a: any,b: any): any?
	local x,y=math.max(a[1],b[1]),math.max(a[2],b[2])
	local right,bottom=math.min(a[1]+a[3],b[1]+b[3]),math.min(a[2]+a[4],b[2]+b[4])
	return if right > x and bottom > y then {x,y,right-x,bottom-y} else nil
end

local function subtract(rectangles: any,mask: any): any
	local result={}
	for _,r in rectangles do
		local cut=intersection(r,mask)
		if not cut then table.insert(result,r); continue end
		local x,y,w,h=table.unpack(cut)
		if y > r[2] then table.insert(result,{r[1],r[2],r[3],y-r[2]}) end
		if y+h < r[2]+r[4] then table.insert(result,{r[1],y+h,r[3],r[2]+r[4]-y-h}) end
		if x > r[1] then table.insert(result,{r[1],y,x-r[1],h}) end
		if x+w < r[1]+r[3] then table.insert(result,{x+w,y,r[1]+r[3]-x-w,h}) end
	end
	return result
end

function TableBorderPaint.create(box: any,factory: any,registry: any)
	if box.TableBorderPaint then
		local previous=box.TableBorderPaint
		for _,entry in previous.Pool do
			registry[entry.Gui]=nil
		end
		previous.Host:Destroy();box.TableBorderPaint=nil
	end
	if not box.CollapsedBorders then return end
	-- Zero-size host: a transparent overlay covering the table would mask controls in hit tests.
	box.TableBorderPaint={Factory=factory,Registry=registry,Pool={},Host=PaintLayer.create(factory,"Frame",box.TableSurface or box.Gui,
		{Name="CollapsedTableBorders",BackgroundTransparency=1,Size=UDim2.fromOffset(0,0),ZIndex=#box.Children+1})}
end

function TableBorderPaint.arrange(box: any,widths: any,heights: any,left: number,top: number)
	local state,data=box.TableBorderPaint,box.CollapsedBorders
	if not state then return end
	local xs,ys={left},{top}
	for _,w in widths do table.insert(xs,xs[#xs]+w) end
	for _,h in heights do table.insert(ys,ys[#ys]+h) end
	local runs,vertices={},{}
	local function collect(edges: any,horizontal: boolean,positions: any,across: any,count: number,lines: number)
		for line=1,lines do
			local slots=edges[line]
			if not slots then continue end
			local first=1
			while first <= count do
				local value=slots[first]
				if not value or value.Width <= 0 or not value.Visible then first+=1; continue end
				local last=first
				while last < count and slots[last+1] and same(value,slots[last+1]) do last+=1 end
				local function crossing(at: number): number
					local perpendicular=if horizontal then data.Vertical[at] else data.Horizontal[at]
					if not perpendicular then return 0 end
					return math.max(if perpendicular[line-1] then perpendicular[line-1].Width else 0,if perpendicular[line] then perpendicular[line].Width else 0)/2
				end
				local run={Value=value,Horizontal=horizontal,Start=positions[first]-crossing(first),
					Length=positions[last+1]-positions[first]+crossing(first)+crossing(last+1),Across=across[line]-value.Width/2,Order=#runs+1,Masks={}}
				run.Rect=if horizontal then {run.Start,run.Across,run.Length,value.Width} else {run.Across,run.Start,value.Width,run.Length}
				table.insert(runs,run)
				for at=first,last+1 do
					local row,col=if horizontal then line else at,if horizontal then at else line
					if not vertices[row] then vertices[row]={} end
					if not vertices[row][col] then vertices[row][col]={} end
					table.insert(vertices[row][col],run)
				end
				first=last+1
			end
		end
	end
	collect(data.Vertical,false,ys,xs,#heights,#widths+1)
	collect(data.Horizontal,true,xs,ys,#widths,#heights+1)
	-- Stronger edges cover weaker intersections. Stable ties keep horizontal joins continuous.
	table.sort(runs,function(a,b)
		if Borders.wins(a.Value,b.Value) then return false end
		if Borders.wins(b.Value,a.Value) then return true end
		return a.Order < b.Order
	end)
	for order,run in runs do run.PaintOrder=order end
	-- Only edges sharing a grid vertex can overlap. Cut the losing edge before
	-- painting, so semi-transparent intersections are not composited twice.
	local seen={}
	for _,row in vertices do for _,neighbors in row do
		for i=1,#neighbors do for j=i+1,#neighbors do
			local a,b=neighbors[i],neighbors[j]
			local weak,strong=if a.PaintOrder < b.PaintOrder then a else b,if a.PaintOrder < b.PaintOrder then b else a
			local key=weak.Order..":"..strong.Order
			if not seen[key] then
				seen[key]=true
				local overlap=intersection(weak.Rect,strong.Rect)
				if overlap then table.insert(weak.Masks,overlap) end
			end
		end end
	end end
	local used=0
	for _,run in runs do
		local v=run.Value
		local kind=if v.Style == "inset" then "ridge" elseif v.Style == "outset" then "groove" else v.Style
		local style={BorderStyle=kind,BorderColor=v.Color,BorderColorAlpha=v.Alpha}
		for band,part in Geometry.pattern(kind,run.Length,v.Width) do
			local color=Paint.edge(style,v.Side,band)
			local along,cross=run.Start+part[1],run.Across+part[2]
			local rectangles={if run.Horizontal then {along,cross,part[3],part[4]} else {cross,along,part[4],part[3]}}
			for _,mask in run.Masks do rectangles=subtract(rectangles,mask) end
			for _,rect in rectangles do
				used+=1
				local item=state.Pool[used]
				if not item then
					item={Gui=state.Factory.create("Frame",state.Host,{Name="SharedBorder",BackgroundTransparency=1})}
					state.Pool[used]=item
				end
				local gui=item.Gui
				local drawX=if box.Style.Direction == "rtl" then left+xs[#xs]-rect[1]-rect[3] else rect[1]
				write(gui,"Position",UDim2.fromOffset(drawX,rect[2]))
				write(gui,"Size",UDim2.fromOffset(rect[3],rect[4]))
				write(gui,"BackgroundColor3",color)
				write(gui,"BackgroundTransparency",1-v.Alpha)
				write(gui,"ZIndex",used); write(gui,"Visible",true)
				if kind == "dotted" and not item.Corner then
					item.Corner=state.Factory.modifier("UICorner",gui,{CornerRadius=UDim.new(.5,0)})
				elseif item.Corner then write(item.Corner,"CornerRadius",UDim.new(if kind == "dotted" then .5 else 0,0)) end
				state.Registry[gui]=v.Node
			end
		end
	end
	for i=used+1,#state.Pool do write(state.Pool[i].Gui,"Visible",false) end
end

return TableBorderPaint
