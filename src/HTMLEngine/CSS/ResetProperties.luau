--!strict
-- One canonical declaration per stored field. Shorthands contribute through
-- their component properties; physical sides avoid order-dependent RTL aliases.
local Properties = require(script.Parent.Properties)
local composite = {
	All=true, FontShorthand=true, FontVariantShorthand=true, ListStyle=true,
	Flex=true, FlexFlow=true, Overflow=true, Inset=true, Border=true, Outline=true,
	ColumnRule=true, BackgroundShorthand=true, OffsetShorthand=true,
	TransitionShorthand=true, AnimationShorthand=true, TextWrapShorthand=true,PositionTryShorthand=true,
	TextEmphasisShorthand=true, OverscrollBehavior=true, ColumnsShorthand=true,
	ContainerShorthand=true, ContainIntrinsicShorthand=true, BorderImageShorthand=true,
	VisualShorthand=true,MaskShorthand=true,MaskBorderShorthand=true,BoxShadows=true,
	ScrollTimelineShorthand=true,OverflowClipMarginShorthand=true,OverflowClipMarginBlock=true,OverflowClipMarginInline=true,
}
local aliases = {
	['inline-size']=true,['block-size']=true,
	['min-inline-size']=true,['max-inline-size']=true,
	['min-block-size']=true,['max-block-size']=true,
	['overflow-inline']=true,['overflow-block']=true,
	['grid-gap']=true,['grid-row-gap']=true,['grid-column-gap']=true,
}
local names = {}
for name, property in Properties do
	if name~='direction' and name~='unicode-bidi' and not aliases[name]
		and not composite[property.Field] and property.Kind~='grid-shorthand' and property.Kind~='column-rule-inset-shorthand' and property.Kind~='layout-shorthand'
		and not property.Side and not property.BorderSide and not property.LogicalSides
		and not property.Corner and not property.LogicalCorner and not property.Axis
		and not property.ResetDecoration then
		table.insert(names,name)
	end
end
table.sort(names)
local fields, result = {}, {}
for _, name in names do
	local field=Properties[name].Field
	if not fields[field] then fields[field]=true;table.insert(result,name) end
end
return table.freeze(result)
