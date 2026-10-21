--!strict
local Geometry = require(script.Parent.BorderGeometry)
local Spacing = require(script.Parent.BoxSpacing)
local Columns = {}
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)

local function span(node: any): number
	local raw=node.Attributes.span
	local n=if raw then tonumber(raw:match("^%s*%+?(%d+)")) else nil
	return if n and n > 0 then math.min(n,1000) else 1
end

-- Column definitions are metadata, never ordinary flow boxes or text containers.
function Columns.read(node: any,parent: any,resolve: any,diagnostic: any): (any,any)
	local columns,groups={},{}
	local function add(owner: any,group: any?)
		local count=span(owner.Node)
		assert(#columns+count <= 4096,"Table exceeds 4096 columns")
		for _=1,count do
			table.insert(columns,{Node=owner.Node,Style=owner.Style,Group=group,
				Width=owner.Style.Width or (if group then group.Style.Width else nil)})
		end
	end
	for _,child in node.Children do
		if child.Kind ~= "Element" or (child.Name ~= "col" and child.Name ~= "colgroup") then continue end
		local style=resolve(child,parent)
		if style.Hidden then continue end
		local owner={Node=child,Style=style,First=#columns+1}
		if child.Name == "col" then add(owner,nil)
		else
			local hasColumns=false
			for _,col in child.Children do
				if col.Kind == "Element" and (col.Name == "script" or col.Name == "template") then continue end
				if col.Kind == "Element" and col.Name == "col" then
					hasColumns=true
					local s=resolve(col,style)
					if not s.Hidden then add({Node=col,Style=s},owner) end
				elseif col.Kind == "Element" or (col.Kind == "Text" and col.Text:find("%S")) then
					diagnostic("table: only col children are supported inside colgroup")
				end
			end
			if not hasColumns then add(owner,owner) end
			owner.Count=#columns-owner.First+1
			if owner.Count > 0 then table.insert(groups,owner) end
		end
	end
	return columns,groups
end

function Columns.length(value: any,width: number): number
	return LengthExpression.resolve(value,width)
end

function Columns.fixed(box: any,width: number,gap: number): any
	local count=box.TableGrid.Columns
	local values,known=table.create(count,0),{}
	for i,column in box.TableColumns or {} do
		if column.Width then values[i]=Columns.length(column.Width,width); known[i]=true end
	end
	for _,e in box.TableGrid.Entries do
		if e.Row ~= 1 then break end
		local s=e.Cell.Style
		if not s.Width then continue end
		Spacing.resolve(s,width)
		local _,r,_,l=Geometry.sizes(s)
		local edges=r+l+s.Padding[2]+s.Padding[4]
		local outer=Columns.length(s.Width,width)+(if s.BoxSizing == "border-box" then 0 else edges)
		local share=math.max(0,outer-gap*(e.ColSpan-1))/e.ColSpan
		for i=e.Column,e.Column+e.ColSpan-1 do if not known[i] then values[i]=share; known[i]=true end end
	end
	local gaps=if count > 0 then (count+1)*gap else 0
	local total=gaps
	for _,w in values do total+=w end
	return {Min=total,Max=total,Minimum=values,Preferred=values,Gaps=gaps,Fixed=true,Known=known}
end

function Columns.distribute(measured: any,width: number): any
	local result=table.clone(measured.Minimum)
	local extra=math.max(0,width-measured.Min)
	local missing=0
	for i in result do if not measured.Known[i] then missing+=1 end end
	for i in result do
		if missing == 0 then result[i]+=extra/#result
		elseif not measured.Known[i] then result[i]+=extra/missing end
	end
	return result
end

return Columns
