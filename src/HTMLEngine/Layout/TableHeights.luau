--!strict
local Grid=require(script.Parent.TableGrid)
local Heights={}
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local Work=require(script.Parent.Parent.WorkContext)
function Heights.empty(box,requested)
	local result,total={},0
	for _,group in box.TableGroups do
		Work.checkpoint()
		if not group.TableEmpty or not group.Style.Height then continue end
		local value=group.Style.Height
		local height=if not value.Percent or requested then math.max(0,LengthExpression.resolve(value,requested or 0))else 0
		total+=height
		table.insert(result,{Group=group,First=group.TableFirstRow,Height=if group.Style.VisibilityCollapse then 0 else height})
	end
	return result,total
end
local function growGroup(box,heights,range,gap,target)
	local extra=target-Grid.extent(heights,range.First,range.Count,gap)
	if extra<=0 then return end
	local automatic={};local weight=0
	for i=range.First,range.First+range.Count-1 do
		if not box.TableRows[i].Box.Style.Height then table.insert(automatic,i);weight+=heights[i]end
	end
	if #automatic==0 then Grid.ensure(heights,range.First,range.Count,gap,target);return end
	for _,i in automatic do heights[i]+=extra*(if weight>0 then heights[i]/weight else 1/#automatic)end
end

-- Preserve intrinsic row minima, satisfy percentage goals within the available
-- surplus, then give remaining space to auto rows before explicitly sized rows.
function Heights.distribute(box: any, heights: any, gap: number, requested: number?)
	local groups={}
	for i,row in box.TableRows do
		Work.checkpoint()
		if not row.Group then continue end
		local range=groups[row.Group]
		if not range then range={First=i,Count=0};groups[row.Group]=range end
		range.Count+=1
	end
	-- Row-group height constrains its complete span, including internal gaps.
	-- The table grid owns these rows; no independent group reflow is needed.
	for group,range in groups do
		local value=group.Style.Height
		if value and not value.Percent then growGroup(box,heights,range,gap,LengthExpression.resolve(value,0))end
	end
	local total=0
	for _,h in heights do total+=h end
	local target=math.max(total,(requested or 0)-(if #heights > 0 then (#heights+1)*gap else 0))
	local desired=table.clone(heights)
	local constrained,groupConstrained={},{}
	for group,range in groups do
		local value=group.Style.Height
		if not value then continue end
		for i=range.First,range.First+range.Count-1 do constrained[i]=true;groupConstrained[i]=true end
		if value.Percent then growGroup(box,desired,range,gap,LengthExpression.resolve(value,target))end
	end
	for i,row in box.TableRows do
		local value=row.Box.Style.Height
		if value then
			constrained[i]=true
			if value.Percent then desired[i]=math.max(desired[i],LengthExpression.resolve(value,target)) end
		end
	end
	for _,entry in box.TableGrid.Entries do
		local value=entry.Cell.Style.Height
		if value then
			for i=entry.Row,entry.Row+entry.RowSpan-1 do constrained[i]=true end
			if value.Percent then Grid.ensure(desired,entry.Row,entry.RowSpan,gap,LengthExpression.resolve(value,target)) end
		end
	end
	local demand=0
	for i,h in desired do demand+=h-heights[i] end
	local available=target-total
	local fraction=if demand > 0 then math.min(1,available/demand) else 0
	for i,h in desired do heights[i]+=(h-heights[i])*fraction end
	available-=demand*fraction
	if available <= .0001 or #heights == 0 then return end
	local recipients,weight={},0
	for i,h in heights do if not constrained[i] then table.insert(recipients,i); weight+=h end end
	if #recipients==0 then for i,h in heights do if not groupConstrained[i]then table.insert(recipients,i);weight+=h end end end
	if #recipients == 0 then for i,h in heights do table.insert(recipients,i); weight+=h end end
	for _,i in recipients do heights[i]+=available*(if weight > 0 then heights[i]/weight else 1/#recipients) end
end

return Heights
