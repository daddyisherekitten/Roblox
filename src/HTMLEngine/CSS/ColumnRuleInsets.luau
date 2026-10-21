--!strict
local Tokens = require(script.Parent.GridValues)
local Length = require(script.Parent.LengthExpression)
local Insets = {}
local names = {'column-rule-inset-cap-start','column-rule-inset-cap-end','column-rule-inset-junction-start','column-rule-inset-junction-end'}
Insets.Fields = {
	[names[1]]='ColumnRuleInsetCapStart',[names[2]]='ColumnRuleInsetCapEnd',
	[names[3]]='ColumnRuleInsetJunctionStart',[names[4]]='ColumnRuleInsetJunctionEnd',
}
Insets.Shorthands = {
	['column-rule-inset']=true,['column-rule-inset-start']=true,['column-rule-inset-end']=true,
	['column-rule-inset-cap']=true,['column-rule-inset-junction']=true,
}
function Insets.parse(value: string,context: any?): any?
	if value=='overlap-join' then return value end
	return Length.parse(value,context)
end
function Insets.expand(name: string,value: string): any?
	if not Insets.Shorthands[name] then return nil end
	value=value:lower()
	local wide=value=='initial' or value=='inherit' or value=='unset'
	local indexes=if name=='column-rule-inset-start' then {1,3}
		elseif name=='column-rule-inset-end' then {2,4}
		elseif name=='column-rule-inset-cap' then {1,2}
		elseif name=='column-rule-inset-junction' then {3,4} else {1,2,3,4}
	if wide then
		local result={};for _,index in indexes do table.insert(result,{Name=names[index],Value=value}) end
		return result
	end
	local groups=Tokens.tokens(value,'/')
	if not groups or #groups<1 or #groups>(if name=='column-rule-inset' then 2 else 1) then return nil end
	local pairs={}
	for _,group in groups do
		local parts=Tokens.tokens(group)
		local maxCount=if name=='column-rule-inset-start' or name=='column-rule-inset-end' then 1 else 2
		if not parts or #parts<1 or #parts>maxCount then return nil end
		for _,part in parts do
			if not Insets.parse(part,{Validate=true,FontSize=16,RootFontSize=16,ViewportWidth=100,ViewportHeight=100}) then return nil end
		end
		table.insert(pairs,{parts[1],parts[2] or parts[1]})
	end
	local values={pairs[1][1],pairs[1][2]}
	if name=='column-rule-inset' then
		local junction=pairs[2] or pairs[1];values[3],values[4]=junction[1],junction[2]
	elseif name=='column-rule-inset-start' or name=='column-rule-inset-end' then values[2]=values[1] end
	local result={};for order,index in indexes do table.insert(result,{Name=names[index],Value=values[order]}) end
	return result
end
-- Container edges have no crossing gap; percentages there resolve to zero.
function Insets.offset(value: any,crossingGap: number,junction: boolean): number
	if value=='overlap-join' then return if junction then -crossingGap/2 else 0 end
	return if type(value)=='table' then Length.resolve(value,crossingGap) else value or 0
end
return Insets
