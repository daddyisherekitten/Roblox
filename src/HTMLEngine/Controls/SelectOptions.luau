--!strict
local Options = {}
local AttributeValues=require(script.Parent.Parent.HTML.AttributeValues)
local SelectedContent=require(script.Parent.Parent.HTML.SelectedContent)
local SelectTree=require(script.Parent.Parent.HTML.SelectTree)
Options.Indent = 12
local function groupLegend(node: any): any?
	for _,child in node.Children do
		if child.Kind=='Element'then return if SelectTree.html(child,'legend')then child else nil end
	end
	return nil
end
local function selectedContent(node: any): any?
	if node.Attributes.multiple ~= nil then return nil end
	return SelectedContent.mirrors(node)[1]
end
function Options.read(node: any): (any, number, any, any?, any)
	local items, rows, selected, mirror, defaults = {}, {}, 0, selectedContent(node), {}
	SelectTree.options(node,function(child,disabled,grouped)
				local a = child.Attributes
				local caption = SelectTree.text(child,true)
				local option = {Node=child, Caption=if a.label and a.label~=''then a.label else caption, ContentCaption=caption, Value=a.value or SelectTree.text(child,false),
					Disabled=disabled or a.disabled ~= nil, Grouped=grouped, OptionIndex=#items+1}
				table.insert(items, option)
				table.insert(rows, option)
				if a.selected ~= nil then selected = #items; defaults[#items]=true end
	end,function(child,disabled)
		local legend=groupLegend(child)
		table.insert(rows,{Node=child,Legend=legend,Caption=if legend then SelectTree.text(legend,true)else child.Attributes.label or "",IsGroup=true,Disabled=disabled})
	end)
	local size=AttributeValues.nonnegative(node.Attributes.size) or 0
	if selected == 0 and node.Attributes.multiple == nil and size<=1 then
		for index, item in items do if not item.Disabled then selected=index; break end end
	end
	return items, selected, rows, mirror, defaults
end
function Options.assignMultiple(c: any, selected: any)
	c.SelectedIndices=table.clone(selected)
	c.SelectedIndex=0
	for index=1,#c.Options do if c.SelectedIndices[index] then c.SelectedIndex=index;break end end
	local option=c.Options[c.SelectedIndex]
	c.Value=if option then option.Value else ""
	c.Caption=if option then option.Caption else ""
end
function Options.assign(c: any, index: number, force: boolean?)
	c.SelectedIndex = index
	local option = c.Options[index]
	c.Value = if option then option.Value else ""
	c.Caption = if option then (if c.SelectedContent then option.ContentCaption else option.Caption) else ""
	if c.UpdateSelectedContent then c.UpdateSelectedContent(force~=false)end
end
function Options.next(c: any, index: number, step: number): number
	if index == 0 and step < 0 then index = #c.Options + 1 end
	for candidate = index + step, if step > 0 then #c.Options else 1, step do
		if not c.Options[candidate].Disabled then return candidate end
	end
	return index
end
return Options
