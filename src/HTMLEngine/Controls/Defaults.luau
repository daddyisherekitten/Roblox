--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)
local Defaults = {}
local INPUT_TYPES=table.freeze({text=true,search=true,tel=true,email=true,url=true,password=true,number=true,color=true,checkbox=true,radio=true,range=true,submit=true,reset=true,button=true,hidden=true,date=true,['datetime-local']=true,month=true,week=true,time=true,file=true,image=true})
function Defaults.kind(node: any): string?
	local name=ElementNames.htmlName(node)
	if name == "textarea" or name == "output" or name == "select" or name == "progress" or name == "meter" then return name end
	if name == "button" then
		local value = (node.Attributes.type or "submit"):lower()
		return if value == "reset" or value == "button" then value else "submit"
	end
	if name ~= "input" then return nil end
	local kind = (node.Attributes.type or "text"):lower()
	return if INPUT_TYPES[kind]then kind else "text"
end
function Defaults.selectButton(node: any): boolean
	local parent=node.Parent;if ElementNames.htmlName(node)~='button'or not parent or ElementNames.htmlName(parent)~='select'then return false end
	for _,child in parent.Children do if child.Kind=='Element'then return child==node end end;return false
end
function Defaults.apply(node: any, s: any, parentStyle: any?)
	local kind = Defaults.kind(node)
	if not kind then return end
	if Defaults.selectButton(node)and parentStyle and parentStyle.Appearance=='base-select'then s.Display='contents';s.Appearance='none';return end
	s.Display = if kind=='output'then 'inline'else 'inline-block'
	if kind == "output" then return end
	if kind == "progress" or kind == "meter" then
		s.Padding,s.Margin={0,0,0,0},{0,0,0,0}
		s.BorderWidth,s.BorderStyle,s.BorderRadius,s.BackgroundAlpha=0,"none",0,0
		return
	end
	s.Font, s.FontSize, s.FontWeight, s.FontStyle = Enum.Font.Arial, 13.333333, 400, "normal"
	s.Color, s.ColorAlpha = Color3.fromRGB(0, 0, 0), 1
	s.LineHeight = {Kind = "normal"}
	s.Background, s.BackgroundAlpha = Color3.new(1, 1, 1), 1
	s.BorderWidth, s.BorderStyle, s.BorderColor, s.BorderRadius = 1, "solid", Color3.fromRGB(118,118,118), 3
	s.Padding = {1,2,1,2}
	if kind == "image" or kind == "file" then
		s.Padding={0,0,0,0};s.BorderWidth,s.BorderStyle,s.BorderRadius,s.BackgroundAlpha=0,"none",0,0
	elseif kind == "checkbox" or kind == "radio" then
		s.Padding = {0,0,0,0}
		s.Width, s.Height, s.BoxSizing = {Value=13,Percent=false}, {Value=13,Percent=false}, "border-box"
		s.Margin = if kind == "radio" then {3,3,0,5} else {3,3,3,4}
		s.BorderRadius = if kind == "radio" then 999 else 3
	elseif kind == "range" then
		s.Padding,s.Margin={0,0,0,0},{2,2,2,2}
		s.BorderWidth,s.BorderStyle,s.BorderRadius,s.BackgroundAlpha=0,"none",0,0
	elseif kind == "color" then
		s.Padding={2,2,2,2}
		s.Width,s.Height,s.BoxSizing={Value=50,Percent=false},{Value=27,Percent=false},"border-box"
		s.BorderColor,s.BorderRadius=Color3.fromRGB(0,0,0),2
		s.Background=Color3.fromRGB(241,244,239)
	elseif kind == "button" or kind == "submit" or kind == "reset" then
		s.Padding, s.Background = {2,6,2,6}, Color3.fromRGB(239,239,239)
		s.AlignContent = "center"
		-- Theme rounding is not the initial CSS radius. Apply it only after the
		-- author cascade, so individual authored corners start from zero.
		s.BorderRadius,s.ButtonAppearanceOrigins=0,{}
	elseif kind == "textarea" then s.Font, s.Padding, s.Resize = "Roboto Mono", {2,2,2,2}, "both" end
end
function Defaults.selectState(s: any,state: any?)
	if not state then return end
	if state.Disabled then s.ColorAlpha=(s.ColorAlpha or 1)*.5
	elseif state.Active or state.Hovered then s.Background={SelectUAAlpha=if state.Active then .2 else .1}end
end
function Defaults.baseSelect(s: any,inherited: any,list: boolean?,state: any?)
	for _,key in {'Font','FontSize','FontWeight','FontStyle','Color','ColorAlpha','LineHeight'}do s[key]=inherited[key]end
	local size=s.FontSize
	s.Display,s.Padding,s.Gap,s.BorderRadius=if list then 'inline-block'else 'inline-flex',if list then {0,0,0,0}else {size*.25,size*.5,size*.25,size*.5},if list then {0,0}else {size*.5,size*.5},if list then 0 else size*.5
	s.Background,s.BackgroundAlpha=nil,0
	s.BoxSizing,s.BorderColor,s.UserSelect='border-box','currentcolor','none'
	if list then s.Overflow,s.OverflowX,s.OverflowY='auto','auto','auto' end
	Defaults.selectState(s,if list and state then {Disabled=state.Disabled}else state)
	s.SelectBaseContents=list==true
	return {List=list,Padding=table.clone(s.Padding),Gap=s.Gap,Radius=s.BorderRadius}
end
function Defaults.selectPart(node: any,s: any,parent: any,state: any?)
	s.SelectBaseContents=ElementNames.htmlName(node)~='select'and parent.SelectBaseContents==true
	if not s.SelectBaseContents then return end
	local size=s.FontSize
	if ElementNames.htmlName(node)=='option'then
		if state and state.GroupDisabled then state=table.clone(state);state.Disabled=false;state.Active=false;state.Hovered=false end
		Defaults.selectState(s,state)
		s.Display,s.AlignItems,s.Gap='flex','center',{size*.5,size*.5}
		s.Padding={0,size*.5,0,size*.5};s.MinWidth={Value=24};s.MinHeight={Value=math.max(24,size*1.2)}
		s.WhiteSpace,s.WhiteSpaceCollapse,s.TextWrapMode='nowrap','collapse','nowrap'
		if ElementNames.html(node.Parent,'optgroup')then s.FontWeight=400 end
	elseif ElementNames.htmlName(node)=='optgroup'then
		s.Display,s.FontWeight='block',math.min(900,if s.FontWeight<400 then 400 elseif s.FontWeight<700 then 700 else 900)
		Defaults.selectState(s,if state then {Disabled=state.Disabled}else nil)
	elseif ElementNames.htmlName(node)=='legend'and ElementNames.html(node.Parent,'optgroup')or node.GeneratedSelectLabel then
		s.Display='block';s.Padding={0,size*.5,0,size*.5};s.MinHeight={Value=size*1.2}
	end
	if ElementNames.htmlName(node)=='option'or ElementNames.htmlName(node)=='legend'or node.GeneratedSelectLabel then return {Padding=table.clone(s.Padding),MinHeight=s.MinHeight,Gap=s.Gap,Option=ElementNames.htmlName(node)=='option'}end
end
function Defaults.finishBaseSelect(s: any,ua: any,paddingSpecified: any?)
	if not ua or ua.List then return end
	for side=1,4 do if not(paddingSpecified and paddingSpecified[side])and s.Padding[side]==ua.Padding[side]then s.Padding[side]=s.FontSize*(if side%2==0 then .5 else .25)end end
	if s.Gap==ua.Gap then s.Gap={s.FontSize*.5,s.FontSize*.5}end
	if not ua.RadiusAuthored and s.BorderRadius==ua.Radius then s.BorderRadius=s.FontSize*.5 end
end
function Defaults.finishSelectPart(s: any,ua: any,paddingSpecified: any?)
	if not ua then return end
	for _,side in {2,4}do if not(paddingSpecified and paddingSpecified[side])and s.Padding[side]==ua.Padding[side]then s.Padding[side]=s.FontSize*.5 end end
	if ua.Option and s.Gap==ua.Gap then s.Gap={s.FontSize*.5,s.FontSize*.5}end
	if s.MinHeight==ua.MinHeight then
		local lh=s.LineHeight;local line=if lh.Kind=='px'then lh.Value elseif lh.Kind=='number'then lh.Value*s.FontSize else s.FontSize*1.2
		s.MinHeight={Value=if ua.Option then math.max(24,line)else line}
	end
end

function Defaults.pseudo(node: any,s: any)
	if node.GeneratedPseudo=='picker(select)'then
		s.Display=if node.PickerClosed then 'none'else 'block';s.Position='fixed';s.BoxSizing='border-box';s.SelectBaseContents=true;s.UserSelect='none'
		s.Margin,s.Padding={0,0,0,0},{0,0,0,0}
		s.BorderWidth,s.BorderStyle,s.BorderColor,s.BorderRadius=1,'solid',Color3.new(0,0,0),0
		s.Color,s.ColorAlpha=Color3.new(0,0,0),1;s.Background,s.BackgroundAlpha=Color3.new(1,1,1),1
		s.Width={Intrinsic='fit-content',Value=0,Percent=false}
		s.MinWidth={Value=0,PickerAnchor=true};s.MaxHeight={Value=0,PickerStretch=true}
		s.PositionArea='self-block-end span-self-inline-end';s.PositionTryOrder='most-block-size'
		s.PositionTryFallbacks={{Area='self-block-start span-self-inline-end'},{Area='self-block-end span-self-inline-start'},{Area='self-block-start span-self-inline-start'}}
		s.Overflow,s.OverflowX,s.OverflowY='auto','auto','auto'
	elseif node.GeneratedPseudo=='picker-icon'then
		s.Display='block'
		s.GeneratedContent={{Kind='counter',Name='fake-counter-name',Style='disclosure-open'}}
		s.MarginAuto={false,s.Direction=='rtl',false,s.Direction~='rtl'}
	elseif node.GeneratedPseudo=='checkmark'then
		s.GeneratedContent={{Kind='text',Value='✓'}}
		s.Visibility=if node.PseudoChecked then s.Visibility else 'hidden'
	end
end
function Defaults.preparePicker(s:any)
	-- Writing mode has been cascaded before normal declarations. Place logical
	-- UA bounds on their final physical axis, then let every author origin win.
	for _,field in {'MinWidth','MinHeight','MaxWidth','MaxHeight'}do
		local value=s[field];if value and(value.PickerAnchor or value.PickerStretch)then s[field]=nil end
	end
	local vertical=WritingMode.vertical(s)
	s[if vertical then 'MinHeight'else 'MinWidth']={Value=0,PickerAnchor=true}
	s[if vertical then 'MaxWidth'else 'MaxHeight']={Value=0,PickerStretch=true}
end
local BACKGROUND={Background=true,BackgroundImages=true,BackgroundSizes=true,BackgroundPositions=true,
	BackgroundOrigins=true,BackgroundClips=true,BackgroundAttachments=true}
local IMAGE_BORDER={BorderImageSource=true,BorderImageSlice=true,BorderImageWidth=true,BorderImageOutset=true,BorderImageRepeat=true}
function Defaults.appearanceField(field: string): boolean
	return field=='Border'or field=='BorderWidth'or field=='BorderStyle'or field=='BorderColor'or field=='BorderRadius'
		or field=='BackgroundShorthand'or field=='BorderImageShorthand'or BACKGROUND[field]==true or IMAGE_BORDER[field]==true
end
-- Track the winning origin of each component, not merely whether any earlier
-- declaration existed. A reverted border must restore native button rounding;
-- revert-layer must retain author appearance from a lower layer when present.
function Defaults.cascadeAppearance(s: any,entry: any,source: any?)
	local origins=s.ButtonAppearanceOrigins
	if not origins then return end
	local lower=source and source.ButtonAppearanceOrigins
	local function mark(key: string)origins[key]=if source then lower and lower[key]or nil else true end
	local field=entry.Field
	if field=='Border'or field=='BorderWidth'or field=='BorderStyle'or field=='BorderColor'then
		local sides={}
		if entry.LogicalSides then
			for _,name in entry.LogicalSides do
				table.insert(sides,if name=='block-start'then 1 elseif name=='block-end'then 3
					elseif name=='inline-start'then (if s.Direction=='rtl'then 2 else 4)else (if s.Direction=='rtl'then 4 else 2))
			end
		elseif entry.BorderSide then sides={entry.BorderSide}else sides={1,2,3,4}end
		for _,side in sides do
			for _,component in if field=='Border'then {'BorderWidth','BorderStyle','BorderColor'}else {field}do mark(component..side)end
		end
	elseif field=='BorderRadius'then
		local corner=entry.Corner or entry.LogicalCorner
		if corner then
			local rtl=s.Direction=='rtl'
			local indices={['top-left']=1,['top-right']=2,['bottom-right']=3,['bottom-left']=4,
				['start-start']=if rtl then 2 else 1,['start-end']=if rtl then 1 else 2,
				['end-start']=if rtl then 3 else 4,['end-end']=if rtl then 4 else 3}
			mark('BorderRadius'..indices[corner])
		else for side=1,4 do mark('BorderRadius'..side)end end
	elseif field=='BackgroundShorthand'then
		for component in BACKGROUND do
			if component=='BackgroundPositions'then mark(component..'X');mark(component..'Y')else mark(component)end
		end
	elseif field=='BackgroundPositions'then
		if entry.Axis then mark(field..entry.Axis)else mark(field..'X');mark(field..'Y')end
	elseif BACKGROUND[field]or IMAGE_BORDER[field]then mark(field)
	elseif field=='BorderImageShorthand'then for component in IMAGE_BORDER do mark(component)end end
end
function Defaults.finishAppearance(s: any)
	local origins=s.ButtonAppearanceOrigins
	if not origins then return end
	s.ButtonNativeRadius=s.Appearance~='none'and next(origins)==nil
	if s.ButtonNativeRadius then
		s.BorderRadius=3
		-- Rolled-back side entries are the uniform UA border. Let theme selection
		-- color that default instead of later reintroducing the light-scheme copy.
		s.BorderSides=nil
	end
	s.ControlBackgroundSpecified=origins.Background==true
	s.ControlBorderSpecified=false
	for key in origins do if key:match('^Border[WSC]')then s.ControlBorderSpecified=true;break end end
end
return Defaults
