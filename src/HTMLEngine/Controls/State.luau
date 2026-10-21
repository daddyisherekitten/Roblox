--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local DOM = require(script.Parent.Parent.DOM.Node)
local FormOwner = require(script.Parent.Parent.DOM.FormOwner)
local Defaults = require(script.Parent.Defaults)
local SelectOptions = require(script.Parent.SelectOptions)
local RangeValue = require(script.Parent.RangeValue)
local NumberValue = require(script.Parent.NumberValue)
local GaugeValue = require(script.Parent.GaugeValue)
local ColorValue = require(script.Parent.ColorValue)
local TextValue = require(script.Parent.TextValue)
local TextSelection = require(script.Parent.TextSelection)
local Temporal = require(script.Parent.TemporalValue)
local Strings = require(script.Parent.Parent.JavaScript.Strings)
local State = {}
local AttributeValues=require(script.Parent.Parent.HTML.AttributeValues)
-- Each disabled ancestor applies independently. Only its first direct legend is exempt.
function State.disabled(node: any): boolean
	if node.Attributes.disabled ~= nil then return true end
	local branch, ancestor = node, node.Parent
	while ancestor do
		if ElementNames.htmlName(ancestor) == "fieldset" and ancestor.Attributes.disabled ~= nil then
			local firstLegend
			for _, child in ancestor.Children do
				if ElementNames.htmlName(child) == "legend" then firstLegend = child; break end
			end
			if branch ~= firstLegend then return true end
		end
		branch, ancestor = ancestor, ancestor.Parent
	end
	return false
end
function State.create(node: any): any
	local a, kind = node.Attributes, Defaults.kind(node)
	local value = if ElementNames.htmlName(node) == "textarea" or ElementNames.htmlName(node) == "output" then DOM.textContent(node) else a.value or ""
	local multiple = (kind == "email" or kind == "file") and a.multiple ~= nil
	if TextValue.applies(kind) then value = TextValue.sanitize(kind,value,multiple) end
	local caption = if ElementNames.htmlName(node) == "button" then DOM.textContent(node):gsub("%s+", " "):match("^%s*(.-)%s*$") else a.value or (if kind == "submit" then "Submit" elseif kind == "reset" then "Reset" else "")
	local maxlength = if TextValue.applies(kind) then TextValue.minimum(a.maxlength) else nil
	local form = FormOwner.resolve(node)
	local checked = a.checked ~= nil
	local control = {Node=node, Type=kind, Value=value, DefaultValue=value, Caption=caption, Checked=checked, DefaultChecked=checked,
		MinLength=if TextValue.applies(kind) then TextValue.minimum(a.minlength) else nil, UserEdited=false, Multiple=multiple,
		Disabled=State.disabled(node), ReadOnly=(TextValue.applies(kind) or kind=="number" or Temporal.applies(kind)) and a.readonly ~= nil, Required=a.required ~= nil, Name=a.name or "", Form=form,
		MaxLength=maxlength, TabIndex=tonumber(a.tabindex or "") or 0}
	if Temporal.applies(kind) then
		control.Temporal=Temporal.read(kind,a)
		control.Value=Temporal.sanitize(kind,value);control.DefaultValue=control.Value;control.BadInput=false
	elseif kind=="file" then
		control.Value,control.DefaultValue,control.Files="","",{}
	elseif kind == "progress" or kind == "meter" then
		control.DisplayOnly=true
		control.Form,control.Disabled,control.ReadOnly,control.Required=nil,false,false,false
		control.Gauge=GaugeValue.read(kind,a)
		GaugeValue.assign(control,a.value)
	elseif kind == "number" then
		control.Number=NumberValue.read(a)
		control.Value=NumberValue.sanitize(value)
		control.DefaultValue,control.EditText=control.Value,control.Value
		control.BadInput=false
	elseif kind == "range" then
		control.Range=RangeValue.read(a)
		control.Value=RangeValue.normalize(control.Range,value)
		control.DefaultValue=control.Value
	elseif kind == "color" then
		control.Value=ColorValue.normalize(value)
		control.DefaultValue=control.Value
	elseif kind == "select" then
		local selectMultiple=a.multiple~=nil
		local size=math.clamp(AttributeValues.positive(a.size,if selectMultiple then 4 else 1),1,100)
		control.SelectMultiple,control.SelectSize,control.SelectList=selectMultiple,size,selectMultiple or size>1
		control.Multiple=selectMultiple
		local options, selected, rows, selectedContent, defaults = SelectOptions.read(node)
		control.Options, control.DefaultSelectedIndex = options, selected
		control.SelectRows, control.SelectedContent = rows, selectedContent
		control.DefaultSelectedIndices=defaults
		if selectMultiple then SelectOptions.assignMultiple(control,defaults) else SelectOptions.assign(control, selected) end
		control.ListActiveIndex=control.SelectedIndex
		control.DefaultValue = control.Value
	end
	if ElementNames.htmlName(node) == "input" and a.list and kind ~= "password" and (TextValue.applies(kind) or kind == "number") then
		local root = node
		while root.Parent do root = root.Parent end
		local list = DOM.findById(root,a.list)
		if list and ElementNames.htmlName(list) == "datalist" then
			local options = SelectOptions.read(list)
			for _,option in options do if option.Caption=="" then option.Caption=option.Value end end
			control.Datalist, control.Options, control.SelectRows, control.SelectedIndex = list, options, options, 0
		end
	end
	control.SelectionApplies=TextSelection.applies(node)
	if TextSelection.selectable(node)then TextSelection.ensure(control)end
	return control
end
-- HTML maxlength counts UTF-16 code units, never splits a code point.
function State.limit(value: string, maximum: number?): string
	if not maximum then return value end
	local used, last = 0, 0
	for cp in Strings.codes(value)do
		local cost = if cp > 65535 then 2 else 1
		if used + cost > maximum then break end
		used += cost
		last += if cp<0x80 then 1 elseif cp<0x800 then 2 elseif cp<0x10000 then 3 else 4
	end
	return value:sub(1,last)
end
return State
