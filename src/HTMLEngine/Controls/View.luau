--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local TextValue = require(script.Parent.TextValue)
local TextSelection = require(script.Parent.TextSelection)
local Strings = require(script.Parent.Parent.JavaScript.Strings)
local SelectOptions = require(script.Parent.SelectOptions)
local ColorValue = require(script.Parent.ColorValue)
local Geometry = require(script.Parent.Parent.Layout.BorderGeometry)
local BorderBox = require(script.Parent.Parent.Rendering.BorderBox)
local OutlineBox = require(script.Parent.Parent.Rendering.OutlineBox)
local Metrics = require(script.Parent.Parent.Layout.FontMetrics)
local LengthExpression = require(script.Parent.Parent.CSS.LengthExpression)
local RangeView = require(script.Parent.RangeView)
local NumberView = require(script.Parent.NumberView)
local GaugeView = require(script.Parent.GaugeView)
local TextareaView = require(script.Parent.TextareaView)
local OutputView = require(script.Parent.OutputView)
local CornerRadii = require(script.Parent.Parent.Rendering.CornerRadii)
local ColorScheme = require(script.Parent.Parent.CSS.ColorScheme)
local Temporal=require(script.Parent.TemporalValue)
local TemporalEdit=require(script.Parent.TemporalEdit)
local TemporalView=require(script.Parent.TemporalView)
local FileView=require(script.Parent.FileView)
local ImageBox=require(script.Parent.Parent.Rendering.ImageBox)
local View = {}
local AttributeValues=require(script.Parent.Parent.HTML.AttributeValues)
-- A mode change replaces only the anonymous select contents. The DOM record,
-- outer GUI, border, focus target and form association keep their identities.
function View.syncSelect(item: any)
	if item.RichButton or item.Control.Type~='select' then return end
	local c,s,factory=item.Control,item.Style,item.Factory
	local list=c.SelectList==true
	if item.SelectListMode==list then return end
	if item.SelectScroll then item.SelectScroll:Destroy();item.SelectScroll=nil end
	if item.Label then item.Label:Destroy();item.Label=nil end
	if item.SelectArrowGui then item.SelectArrowGui:Destroy();item.SelectArrowGui=nil end
	item.SelectArrow,item.SelectRowsByNode,item.SelectListRows,item.OptionIndexByGui=nil,nil,nil,nil
	item.SelectListMode=list;item.ControlMeasureKey=nil
	if list then
		item.SelectRowHeight=math.max(20,View.metrics(item).TextSize+6)
		item.SelectScroll=factory.create('ScrollingFrame',item.BoxGui,{Name='SelectList',BackgroundTransparency=1,
			ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=6,ElasticBehavior=Enum.ElasticBehavior.Never})
		View.refreshSelectRows(item,factory)
	else
		item.Label=factory.create('TextLabel',item.BoxGui,{Name='ControlText',FontFace=item.FontFace,OpenTypeFeatures=s.OpenTypeFeatures,
			TextSize=View.metrics(item).TextSize,Text=c.Caption,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
		local arrow=factory.create('Frame',item.BoxGui,{Name='SelectArrow',Position=UDim2.new(1,-14,.5,-3),Size=UDim2.fromOffset(10,6),BackgroundTransparency=1})
		item.SelectArrowGui=arrow;item.SelectArrow={}
		for _,part in {{1,1,45},{4,1,-45}}do
			table.insert(item.SelectArrow,factory.create('Frame',arrow,{Name='Chevron',Position=UDim2.fromOffset(part[1],part[2]),Size=UDim2.fromOffset(5,1),Rotation=part[3],BackgroundTransparency=0,BackgroundColor3=s.Color}))
		end
	end
end
-- Appearance changes replace anonymous contents, never the focusable select
-- surface or its form record. The rich renderer owns the replacement content.
function View.releaseSelectView(item: any)
	if item.Control.Type~='select'then return end
	View.release(item)
	if item.ControlOutline then
		BorderBox.remove(item.ControlOutline.Edges,item.ControlOutline.Gui)
		item.ControlOutline.Gui:Destroy();item.ControlOutline,item.ControlOutlineSpec=nil,nil
	end
	if item.BoxGui and item.BoxGui~=item.Gui then item.BoxGui:Destroy()end
	for _,key in {'BoxGui','Corner','Stroke','Label','SelectScroll','SelectArrowGui','SelectArrow','SelectRowsByNode','SelectListRows','OptionIndexByGui','SelectListMode','SelectFactory','ControlMeasureKey','ControlOutline','ControlOutlineSpec','GeometryBox'}do item[key]=nil end
end
-- The control and scroll host remain stable; option/optgroup DOM nodes own rows.
function View.refreshSelectRows(item: any,factory: any?)
	if not item.SelectScroll then return end
	factory=factory or item.SelectFactory
	local c,s=item.Control,item.Style
	local old=item.SelectRowsByNode or {};local kept={}
	item.SelectRowHeight=math.max(20,View.metrics(item).TextSize+6)
	item.SelectListRows=item.SelectListRows or {};table.clear(item.SelectListRows)
	item.OptionIndexByGui=item.OptionIndexByGui or {};table.clear(item.OptionIndexByGui)
	for rowIndex,option in c.SelectRows or c.Options do
		local entry=old[option.Node];local top=(rowIndex-1)*item.SelectRowHeight
		if not entry then
			if option.IsGroup then
				local label=factory.create("TextLabel",item.SelectScroll,{Name="SelectGroup_"..rowIndex,BackgroundTransparency=1,TextYAlignment=Enum.TextYAlignment.Center})
				entry={Gui=label,Label=label}
			else
				local row=factory.create("Frame",item.SelectScroll,{Name="SelectOption_"..(option.OptionIndex or rowIndex)})
				local label=factory.create("TextLabel",row,{Name="SelectOptionText_"..(option.OptionIndex or rowIndex),TextYAlignment=Enum.TextYAlignment.Center,BackgroundTransparency=1})
				entry={Gui=row,Label=label}
			end
		end
		kept[option.Node]=entry;entry.Option=option
		local label=entry.Label;label.Text=option.Caption;label.TextSize=View.metrics(item).TextSize
		label.FontFace=if option.IsGroup then item.GroupFontFace or item.FontFace else item.FontFace
		label.OpenTypeFeatures=s.OpenTypeFeatures
		if option.IsGroup then
			label.Position=UDim2.fromOffset(3,top);label.Size=UDim2.new(1,-9,0,item.SelectRowHeight)
			label.TextColor3=if option.Disabled or c.Disabled then Color3.fromRGB(153,153,153) else s.Color
		else
			entry.Gui.Position=UDim2.fromOffset(0,top);entry.Gui.Size=UDim2.new(1,0,0,item.SelectRowHeight)
			local indent=if option.Grouped then SelectOptions.Indent else 0
			label.Position=UDim2.fromOffset(3+indent,0);label.Size=UDim2.new(1,-9-indent,1,0)
			local index=option.OptionIndex or rowIndex
			item.SelectListRows[index]=entry;item.OptionIndexByGui[entry.Gui],item.OptionIndexByGui[label]=index,index
		end
	end
	for node,entry in old do if not kept[node] then entry.Gui:Destroy() end end
	item.SelectRowsByNode=kept;item.SelectFactory=factory
	item.SelectScroll.CanvasSize=UDim2.fromOffset(0,#(c.SelectRows or c.Options)*item.SelectRowHeight)
	local position=item.SelectScroll.CanvasPosition
	if position then item.SelectScroll.CanvasPosition=Vector2.new(position.X,math.max(0,math.min(position.Y,#(c.SelectRows or c.Options)*item.SelectRowHeight))) end
end
function View.metrics(item: any): any
	-- Shared by measurement and both layout paths so the displayed size stays consistent.
	local offset = if item.Control.Type == "textarea" and item.Style.Font == "Roboto Mono" then -3
		elseif item.Control.Type ~= "output" and item.Style.Font == Enum.Font.Arial then -2 else nil
	return Metrics.resolve(item.Style, offset)
end
local function singleLineInput(item: any): boolean
	local kind = item.Control.Type
	return (TextValue.applies(kind) and kind ~= "textarea") or kind == "number" or Temporal.applies(kind) or (kind == "select" and not item.Control.SelectList)
end
local function textTop(item: any, metrics: any): number
	local bt,_,bb=Geometry.sizes(item.Style)
	local offset=0
	if item.Control.Type=='output'and (item.Style.Display=='flex'or item.Style.Display=='inline-flex')then
		local s=item.Style
		local alignment=if s.FlexDirection=='column'or s.FlexDirection=='column-reverse'then s.JustifyContent else s.AlignItems
		local free=math.max(0,item.ContentHeight-metrics.TextSize)
		offset=if alignment=='center'then free/2 elseif alignment=='end'or alignment=='flex-end'then free else 0
	elseif item.Control.Type=='button'or item.Control.Type=='submit'or item.Control.Type=='reset'then
		-- Browser buttons center their content in the available content box.
		-- Use font geometry, not the ink of a particular caption, so switching
		-- between text with/without descenders never moves the baseline.
		local s=item.Style
		local alignment=s.AlignContent or 'center'
		if s.Display=='flex'or s.Display=='inline-flex'then
			alignment=if s.FlexDirection=='column'or s.FlexDirection=='column-reverse'then s.JustifyContent else s.AlignItems
		end
		local free=math.max(0,item.ContentHeight-metrics.TextSize)
		offset=if alignment=='center'then free/2 elseif alignment=='end'or alignment=='flex-end'then free else 0
	elseif singleLineInput(item) then
		local s=item.Style
		local naturalHeight=item.IntrinsicHeight+bt+bb+s.Padding[1]+s.Padding[3]
		if s.Font == Enum.Font.Arial and s.Padding[1]==1 and s.Padding[3]==1 and math.abs(item.BoxHeight-naturalHeight)<0.01 then
			-- Native fields were calibrated to this browser baseline. Keep it stable
			-- when the independently measured Arial glyph guides are refitted.
			return math.max(bt+s.Padding[1],item.BoxHeight-bb-5-metrics.Baseline)
		end
		-- Explicit padding or height defines a real content box. Center the native
		-- editor there instead of carrying over the calibrated default-field baseline.
		offset=math.max(0,math.floor((item.ContentHeight-metrics.TextSize)/2))
	end
	return bt+item.Style.Padding[1]+offset
end
local BLUE, BLUE_HOVER, GRAY = Color3.fromRGB(0,117,255), Color3.fromRGB(0,95,204), Color3.fromRGB(118,118,118)
local BLUE_PRESSED = Color3.fromRGB(57,147,255)
local function checkmarkColor(background: any): any
	local function linear(channel: number): number
		return if channel <= .04045 then channel/12.92 else ((channel+.055)/1.055)^2.4
	end
	local brightness=.2126*linear(background.R)+.7152*linear(background.G)+.0722*linear(background.B)
	-- Native controls choose a dark mark for light accent colors. The higher
	-- threshold keeps the standard saturated blue control white.
	return if brightness >= .3 then Color3.new(0,0,0) else Color3.new(1,1,1)
end
-- Reference geometry for the native 13px checkbox. The final control size
-- determines both stroke thickness and placement during every layout.
local CHECKMARK_PARTS={{3.25,8.5,3,1,45},{4.3,6.7,7,1,-55}}
local function write(gui: any, key: string, value: any) if gui[key] ~= value then gui[key]=value end end
local function paintOutline(item: any)
	local s=item.Style
	local box={Gui=item.Gui,OuterWidth=item.BoxWidth,OuterHeight=item.BoxHeight,Outline=item.ControlOutline}
	OutlineBox.update(box,s,item.Factory)
	item.ControlOutline=box.Outline
	local outline=item.ControlOutline
	if outline and outline.Gui.Visible~=false and item.BoxWidth and item.BoxHeight then
		OutlineBox.arrange(outline,item.BoxWidth,item.BoxHeight)
		local dx=math.max(-item.BoxWidth/2,outline.Offset)+outline.Style.BorderSize
		local dy=math.max(-item.BoxHeight/2,outline.Offset)+outline.Style.BorderSize
		write(outline.Gui,"Position",UDim2.fromOffset(s.Margin[4]-dx,s.Margin[1]-dy))
	end
end
function View.paint(item: any)
	-- The DOM state changes synchronously; anonymous native contents are rebuilt
	-- by render reconciliation before paint/layout touches their new type.
	if ElementNames.htmlName(item.Control.Node)=='input'and item.ViewType and item.ViewType~=item.Control.Type then return end
	if item.Control.Type=='hidden'then return end
	if item.Control.Type=='select'and item.FontResolver then
		local s=item.Control.LayoutStyle or item.Style
		local groups=#(item.Control.SelectRows or{})>#item.Control.Options
		if item.SelectFontFamily~=s.Font or item.SelectFontWeight~=s.FontWeight or item.SelectFontStyle~=s.FontStyle or item.SelectGroupFontMode~=groups then
			item.FontFace=item.FontResolver(s.Font,s.FontWeight,s.FontStyle)
			item.GroupFontFace=if groups then item.FontResolver(s.Font,700,s.FontStyle)else nil
			item.SelectFontFamily,item.SelectFontWeight,item.SelectFontStyle,item.SelectGroupFontMode=s.Font,s.FontWeight,s.FontStyle,groups
		end
	end
	View.syncSelect(item)
	if item.RichButton then
		local c,s=item.Control,item.Style
		local background=s.Background or Color3.new(1,1,1)
		if not item.RichSelect and not s.ControlBackgroundSpecified and s.ButtonNativeRadius~=false then
			if c.Disabled then background=if s.DarkScheme then Color3.fromRGB(45,45,45)else Color3.fromRGB(245,245,245)
			elseif c.Pressed then background=if s.DarkScheme then Color3.fromRGB(80,80,80)else Color3.fromRGB(245,245,245)
			elseif c.Hovered then background=if s.DarkScheme then Color3.fromRGB(125,125,125)else Color3.fromRGB(229,229,229)end
		end
		item.AuthorBackground=background
		item.AuthorBackgroundAlpha=if s.Visibility=="hidden" or s.Appearance=="none" and not s.ControlBackgroundSpecified then 0 else s.BackgroundAlpha or 1
		if not item.TransitioningBackground then
			write(item.BoxGui,"BackgroundColor3",background)
			write(item.BoxGui,"BackgroundTransparency",1-item.AuthorBackgroundAlpha)
		end
		for _,part in item.SelectArrow or{}do write(part,'BackgroundColor3',if c.Disabled then Color3.fromRGB(153,153,153)else s.Color)end
		return
	end
	if item.Control.Type=="image" then if item.BoxWidth and item.BoxHeight then ImageBox.arrange(item) else ImageBox.updateFallback(item) end;return end
	if item.Corner and item.Control.Type~="output"then
		local s=item.Style
		local width,height=item.BoxWidth or 0,item.BoxHeight or 0
		local resolved=if width>0 and height>0 then CornerRadii.resolve(s,width,height)else nil
		local radius=s.BorderRadius or 0
		if resolved then
			radius=math.huge;for _,corner in resolved do radius=math.min(radius,corner[1],corner[2])end
		end
		if s.CornerShape and s.CornerShape~="round"then radius=0 end
		write(item.Corner,"CornerRadius",UDim.new(0,math.max(0,radius)))
		if resolved and CornerRadii.native(s)then
			CornerRadii.apply(item.Corner,resolved);item.IndividualCorners=true
		elseif item.IndividualCorners then
			local corner={radius,radius};CornerRadii.apply(item.Corner,{corner,corner,corner,corner})
		end
	end
	local c,s=item.Control,item.Style
	if c.Type == "summary" then item.FocusStroke.Enabled=c.Focused == true and c.FocusVisible == true; return end
	paintOutline(item)
	local toggle=c.Type == "radio" or c.Type == "checkbox"
	local nativeToggle=toggle and s.Appearance~="none"
	local marked=c.Checked or (c.Type=="checkbox" and c.Indeterminate==true)
	local accent=s.AccentColor or (if s.DarkScheme then ColorScheme.Dark.Accent else BLUE)
	local accentHover=if s.AccentColor then Color3.new(accent.R*.8,accent.G*.8,accent.B*.8)elseif s.DarkScheme then ColorScheme.Dark.AccentHover else BLUE_HOVER
	local accentPressed=if s.AccentColor then Color3.new(math.min(1,accent.R+.2),math.min(1,accent.G+.2),math.min(1,accent.B+.2))elseif s.DarkScheme then ColorScheme.Dark.AccentPressed else BLUE_PRESSED
	local blue=if c.Type == "radio" and c.Pressed then accentPressed
		elseif c.Type == "radio" and c.Hovered then accentHover else accent
	local disabledToggle=if s.DarkScheme then ColorScheme.Dark.DisabledToggle else Color3.fromRGB(198,198,198)
	local border = if c.Disabled and not s.ControlBorderSpecified then (if toggle then disabledToggle else Color3.fromRGB(198,198,198))
		elseif nativeToggle and marked then blue
		elseif c.Type == "radio" and c.Pressed and s.BorderColor == GRAY then Color3.fromRGB(163,163,163)
		elseif c.Hovered and s.BorderColor == GRAY and s.ButtonNativeRadius~=false then Color3.fromRGB(79,79,79)
		else s.BorderColor
	write(item.Stroke,"Color",border)
	write(item.Stroke,"Thickness",s.BorderSize or 1)
	write(item.Stroke,"Transparency",1-(s.BorderColorAlpha or 1))
	write(item.Stroke,"LineJoinMode",if (s.BorderRadius or 0)>0 or CornerRadii.native(s)then Enum.LineJoinMode.Round else Enum.LineJoinMode.Miter)
	local borderVisible=(s.Appearance~="none"or s.ControlBorderSpecified)and c.Type~="output"and s.Visibility~="hidden"
	local separateBorder=borderVisible and (s.BorderUniform==false or s.BorderStyle~='solid'and s.BorderStyle~='none')
	write(item.Stroke,"Enabled",borderVisible and not separateBorder and (s.BorderSize or 0)>0 and s.BorderStyle~="none")
	if separateBorder and item.BoxWidth and item.BoxHeight then
		-- Layout already uses the four effective widths. Paint those same widths
		-- instead of adding a full perimeter stroke to open-sided controls.
		s.NativeCornerRadii=CornerRadii.native(s)
		item.ControlBorderEdges=BorderBox.update(item.ControlBorderEdges,s,item.BoxGui,item.PaintWidth or item.BoxWidth,
			item.PaintHeight or item.BoxHeight,item.Factory,item.BorderCorners)
	elseif item.ControlBorderEdges then
		BorderBox.remove(item.ControlBorderEdges,item.BoxGui);item.ControlBorderEdges=nil
	end
	local background=s.Background or Color3.new(1,1,1)
	if c.Disabled then background=if nativeToggle and marked then disabledToggle
		elseif s.ControlBackgroundSpecified then s.Background or Color3.fromRGB(245,245,245)
		else if s.DarkScheme then (if nativeToggle then ColorScheme.Dark.Field else ColorScheme.Dark.Disabled) else Color3.fromRGB(245,245,245)
	elseif nativeToggle and marked then background=blue
	elseif not s.ControlBackgroundSpecified and s.ButtonNativeRadius~=false and (c.Type == "button" or c.Type == "submit" or c.Type == "reset") then
		if c.Pressed then background=if s.DarkScheme then Color3.fromRGB(80,80,80) else Color3.fromRGB(245,245,245) elseif c.Hovered then background=if s.DarkScheme then Color3.fromRGB(125,125,125) else Color3.fromRGB(229,229,229) end
	end
	item.AuthorBackground=background
	item.AuthorBackgroundAlpha=if (c.Type=="output" and not s.Background) or s.Visibility=="hidden" or (c.Type=="range" and s.Appearance~="none") or (s.Appearance=="none" and not s.ControlBackgroundSpecified) then 0 else s.BackgroundAlpha or 1
	if not item.TransitioningBackground then
		write(item.BoxGui,"BackgroundColor3",background)
		write(item.BoxGui,"BackgroundTransparency",1-item.AuthorBackgroundAlpha)
	end
	if item.ColorSwatch then write(item.ColorSwatch,"BackgroundColor3",ColorValue.color(c.Value)) end
	if item.RadioRing then
		write(item.RadioRing,"Visible",s.Appearance~="none"and s.Visibility~="hidden")
		write(item.RadioRing,"BackgroundColor3",if s.DarkScheme then ColorScheme.Dark.Field else Color3.new(1,1,1))
	end
	if item.Dot then
		write(item.Dot,"Visible",c.Checked and s.Appearance~="none"and s.Visibility~="hidden")
		write(item.Dot,if item.DotImage then "ImageColor3" else "BackgroundColor3",if c.Disabled then disabledToggle else blue)
	end
	if item.Ticks then
		local tickColor=if s.DarkScheme and (not s.AccentColor or c.Disabled)then ColorScheme.Dark.Field else checkmarkColor(background)
		for _, tick in item.Ticks do
			write(tick,"Visible",c.Checked and not c.Indeterminate and s.Appearance~="none"and s.Visibility~="hidden")
			write(tick,"BackgroundColor3",tickColor)
		end
	end
	if item.MixedMark then
		write(item.MixedMark,"Visible",c.Indeterminate==true and s.Appearance~="none"and s.Visibility~="hidden")
		write(item.MixedMark,"BackgroundColor3",if s.DarkScheme and (not s.AccentColor or c.Disabled)then ColorScheme.Dark.Field else checkmarkColor(background))
	end
	for _, part in item.SelectArrow or {} do write(part,"Visible",s.Appearance~="none");write(part,"BackgroundColor3",if c.Disabled then Color3.fromRGB(153,153,153) else s.Color) end
	if item.SelectScroll then View.refreshSelectRows(item) end
	for index,row in item.SelectListRows or {} do
		local selected=if c.SelectMultiple then c.SelectedIndices[index]==true else c.SelectedIndex==index
		local active=c.Focused and c.ListActiveIndex==index
		write(row.Gui,"BackgroundColor3",if selected then (if c.Focused then BLUE else Color3.fromRGB(206,206,206)) else Color3.fromRGB(220,235,250))
		write(row.Gui,"BackgroundTransparency",if selected then 0 elseif active then .15 else 1)
		write(row.Label,"TextColor3",if row.Option.Disabled or c.Disabled then Color3.fromRGB(153,153,153) elseif selected then (if c.Focused then Color3.new(1,1,1) else Color3.fromRGB(16,16,16)) else s.Color)
	end
	if item.Label then
		local codepoints=0;if c.Type=="password"then for _ in Strings.codes(c.Value)do codepoints+=1 end end
		local value=if c.Type == "output" then c.Value elseif c.Type == "password" then (if c.Value == "" then c.Node.Attributes.placeholder or "" else string.rep("•",codepoints)) else c.Caption
		write(item.Label,"Text",value)
		write(item.Label,"TextColor3",if c.Disabled then Color3.fromRGB(153,153,153) elseif c.Type == "password" and c.Value == "" then Color3.fromRGB(117,117,117) else s.Color)
		write(item.Label,"TextTransparency",if s.Visibility == "hidden" then 1 else 1-(s.ColorAlpha or 1))
	end
	if item.Editor then
		write(item.Editor,"TextEditable",not c.Disabled and not c.ReadOnly)
		write(item.Editor,"TextColor3",if c.Disabled then Color3.fromRGB(153,153,153) else s.Color)
	end
	if c.Type=='output'then
		OutputView.paint(item)
		if item.Label then
			local alignment=s.TextAlign
			if s.Display=='flex'or s.Display=='inline-flex'then
				alignment=if s.FlexDirection=='column'or s.FlexDirection=='column-reverse'then s.AlignItems else s.JustifyContent
			end
			write(item.Label,'TextXAlignment',if alignment=='center'then Enum.TextXAlignment.Center elseif alignment=='right'or alignment=='end'or alignment=='flex-end'then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left)
		end
	end
	View.updateCaret(item)
	if item.RangeThumb then RangeView.paint(item) end
	if item.NumberArrows then NumberView.paint(item);if s.Appearance=="none" then for _,arrow in item.NumberArrows do arrow.Visible=false end end end
	if item.GaugeTrack then GaugeView.paint(item) end
	if item.ResizeGrip then TextareaView.paint(item) end
	if item.TemporalIcon then TemporalView.paint(item) end
	if item.FileButton then FileView.paint(item) end
end
function View.create(item: any, host: any, factory: any, face: any, radioDot: any?, resizeGrip: any?, corners: any?, retainedSelect: boolean?)
	item.FontFace=face
	local c,s=item.Control,item.Style
	item.Factory=factory
	item.BorderCorners=corners
	item.ViewType=c.Type;item.ViewSpec={RadioDot=radioDot,ResizeGrip=resizeGrip}
	if c.Type=="image" then ImageBox.create(item,host,factory,face,"ImageSubmit",corners,retainedSelect);c.Item=item;return end
	if not retainedSelect then item.Gui=factory.create("Frame",host,{Name="Control_" .. (c.Node.Attributes.id or c.Type)})end
	if c.Type=='hidden'then c.Item=item;return end
	item.BoxGui=factory.create("Frame",item.Gui,{Name="ControlBox",ClipsDescendants=true})
	item.Corner=factory.modifier("UICorner",item.BoxGui,{CornerRadius=UDim.new(0,s.BorderRadius or 0)})
	item.Stroke=factory.modifier("UIStroke",item.BoxGui,{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,BorderStrokePosition=Enum.BorderStrokePosition.Inner,LineJoinMode=Enum.LineJoinMode.Round,Thickness=1,Color=GRAY})
	if c.Type=='output'then OutputView.create(item,corners)end
	if Temporal.applies(c.Type) then TemporalView.create(item,factory)
	elseif c.Type=="file" then FileView.create(item,factory)
	elseif c.DisplayOnly then
		GaugeView.create(item,factory)
	elseif c.Type == "color" then
		item.ColorSwatch=factory.create("Frame",item.BoxGui,{Name="ColorSwatch",BackgroundTransparency=0})
	elseif c.Type == "range" then
		RangeView.create(item,factory)
	elseif c.Type == "radio" then
		local ring=factory.create("Frame",item.BoxGui,{Name="RadioRing",Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),BackgroundTransparency=0})
		item.RadioRing=ring
		factory.modifier("UICorner",ring,{CornerRadius=UDim.new(.5,0)})
		local content=if radioDot then radioDot:Get() else nil
		item.DotImage=content ~= nil
		if content then
			item.Dot=factory.create("ImageLabel",ring,{Name="BlueDot",Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),
				ImageContent=content,ImageColor3=BLUE,BackgroundTransparency=1,ScaleType=Enum.ScaleType.Stretch})
		else
			item.Dot=factory.create("Frame",ring,{Name="BlueDot",Position=UDim2.fromOffset(2,2),Size=UDim2.new(1,-4,1,-4),BackgroundTransparency=0,BackgroundColor3=BLUE})
			factory.modifier("UICorner",item.Dot,{CornerRadius=UDim.new(.5,0)})
		end
	elseif c.Type == "checkbox" then
		item.MixedMark=factory.create("Frame",item.BoxGui,{Name="MixedMark",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.55,0,0,2),BackgroundTransparency=0,Visible=false})
		item.Ticks={}
		for _, part in CHECKMARK_PARTS do
			table.insert(item.Ticks,factory.create("Frame",item.BoxGui,{Name="Checkmark",Position=UDim2.fromOffset(part[1],part[2]),Size=UDim2.fromOffset(part[3],part[4]),Rotation=part[5],BackgroundTransparency=0,BackgroundColor3=Color3.new(1,1,1)}))
		end
	elseif c.Type=='select' then View.syncSelect(item)
	else
		local editable=TextValue.applies(c.Type) or c.Type == "number"
		local props={Name="ControlText",FontFace=face,OpenTypeFeatures=s.OpenTypeFeatures,TextSize=View.metrics(item).TextSize,Text=TextSelection.nativeText(if editable or c.Type == "output" then c.Value else c.Caption),
			TextXAlignment=if editable or c.Type == "output" or c.Type == "select" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=c.Type == "textarea"}
		if editable then
			props.ClearTextOnFocus,props.MultiLine=false,c.Type == "textarea"
			props.PlaceholderText,props.PlaceholderColor3=c.Node.Attributes.placeholder or "",if c.PlaceholderStyle then c.PlaceholderStyle.Color else Color3.fromRGB(117,117,117)
			props.TextEditable=not c.Disabled and not c.ReadOnly
			if c.Type == "password" then props.ShowNativeInput=false end
			props.TextTransparency=if c.Type == "password" or s.Visibility == "hidden" then 1 else 0
		end
		local text=factory.create(if editable then "TextBox" else "TextLabel",item.BoxGui,props)
		if editable then
			item.Editor=text
			if s.CaretCustom then item.Caret=factory.create("Frame",item.BoxGui,{Name="CSSCaret",BackgroundColor3=s.CaretColor,BackgroundTransparency=1-(s.CaretColorAlpha or 1),Visible=false}) end
		else item.Label=text end
		if c.Type == "textarea" then TextareaView.create(item,factory,resizeGrip) end
		if c.Type == "number" then NumberView.create(item,factory) end
		if c.Type == "password" then
			item.Label=factory.create("TextLabel",item.BoxGui,{Name="PasswordMask",FontFace=face,OpenTypeFeatures=s.OpenTypeFeatures,TextSize=props.TextSize,Text="",TextXAlignment=Enum.TextXAlignment.Left})
		end
	end
	c.Item=item
	View.paint(item)
end
function View.measure(item: any, measure: any, alive: any)
	local c,s=item.Control,item.Style
	item.MeasureText=measure
	local metrics=View.metrics(item)
	if c.Type=="image" then item.TextSize=metrics.TextSize;return true end
	if Temporal.applies(c.Type) or c.Type=="file" then
		local caption=if c.Type=="datetime-local" then "00.00.0000, 00:00:00" elseif c.Type=="date" then "00.00.0000" elseif c.Type=="month" then "September 0000" elseif c.Type=="week" then "Woche 00, 0000" elseif c.Type=="time" then "00:00:00" else "Keine Dateien ausgewählt"
		if Temporal.applies(c.Type) then for _,field in TemporalEdit.fields(c) do if field.Key=="millisecond" then caption..=".000" end end end
		local key=caption..":"..metrics.TextSize..":"..tostring(item.FontFace)
		if item.ControlMeasureKey~=key then
			local measured,reason=measure(caption,item.FontFace,metrics.TextSize,0);if not alive() then return false end;assert(measured,reason)
			item.IntrinsicWidth=measured.X+25
			if c.Type=="file" then local button=measure("Dateien auswählen",item.FontFace,metrics.TextSize,0);if not alive() then return false end;item.FileButtonWidth=button.X;item.IntrinsicWidth+=button.X+12 end
			item.IntrinsicHeight=if c.Type=="file" then metrics.TextSize+6 else Metrics.resolve(s).TextSize+1
			item.InputLineBaseline=Metrics.resolve(s).Baseline+1;item.ControlMeasureKey=key
		end
		item.TextSize=metrics.TextSize;return true
	end
	if c.DisplayOnly then
		item.IntrinsicWidth,item.IntrinsicHeight,item.TextSize=s.FontSize*(if c.Type == "progress" then 10 else 5),s.FontSize,metrics.TextSize
		return true
	end
	if c.Type == "range" then
		item.IntrinsicWidth,item.IntrinsicHeight,item.TextSize=129,16,metrics.TextSize
		return true
	end
	if c.Type == "color" then
		item.IntrinsicWidth,item.IntrinsicHeight,item.TextSize=44,21,metrics.TextSize
		return true
	end
	local caption=if c.Type == "output" then c.Value else c.Caption
	local contentKey=caption
	if c.Type=="select" then
		-- Selection/disabled changes need paint, not a fresh measurement of every
		-- option. Caption/group records are replaced together when DOM content
		-- changes; repeated intrinsic probes reuse the same bounded signature.
		local rows=c.SelectRows or c.Options
		if item.SelectCaptionRows~=rows then
			local parts={}
			for _,option in rows do
				-- Prefix lengths distinguish arbitrary caption contents safely.
				table.insert(parts,(if option.IsGroup then "g"elseif option.Grouped then "i"else "o")..#option.Caption..":"..option.Caption)
			end
			item.SelectCaptionRows,item.SelectCaptionKey=rows,table.concat(parts,"|")
		end
		local contentSized=s.FieldSizing=='content'and not c.SelectList
		local option=c.Options[c.SelectedIndex]
		caption=if option then option.Caption else ''
		contentKey="select:"..tostring(c.SelectList)..":"..tostring(c.SelectSize)..":"..(s.FieldSizing or 'fixed')..":"..tostring(item.GroupFontFace)..":"..(if contentSized then caption else item.SelectCaptionKey)
	end
	local key=contentKey .. ":" .. metrics.TextSize .. ":" .. tostring(item.FontFace)
	if item.ControlMeasureKey ~= key then
		local a=c.Node.Attributes
		local width=0
		if c.Type == "select" then
			local rows=if s.FieldSizing=='content'and not c.SelectList then {{Caption=caption}}else c.SelectRows or c.Options
			for _,option in rows do
				local bounds,reason=measure(option.Caption,if option.IsGroup then item.GroupFontFace or item.FontFace else item.FontFace,metrics.TextSize,0)
				if not alive() then return false end
				assert(bounds,reason); width=math.max(width,bounds.X+(if option.Grouped then SelectOptions.Indent else 0))
			end
		else
			local contentSized=c.Type == "button" or c.Type == "submit" or c.Type == "reset" or c.Type == "output"
			local text,message=measure(if contentSized then caption else "0",item.FontFace,metrics.TextSize,0)
			if not alive() then return false end
			assert(text,message); width=text.X
		end
		item.IntrinsicWidth=if c.Type == "number" then width*20+NumberView.ReservedWidth elseif c.Type == "select" then width+(if c.SelectList then 8 else 18) elseif c.Type == "checkbox" or c.Type == "radio" then 11 elseif TextValue.applies(c.Type) then width * math.clamp(AttributeValues.positive(if c.Type=="textarea" then a.cols else a.size,20),1,1000) else width
		-- Keep logical input size/baseline independent of the local glyph correction.
		local lineMetrics=if singleLineInput(item) then Metrics.resolve(s) else nil
		item.InputLineBaseline=if lineMetrics then lineMetrics.Baseline+1 else nil
		local rows=if c.Type=='select'and s.FieldSizing=='content'then math.max(1,#(c.SelectRows or c.Options))else c.SelectSize
		item.IntrinsicHeight=if c.SelectList then (item.SelectRowHeight or math.max(20,metrics.TextSize+6))*rows elseif lineMetrics then lineMetrics.TextSize+1 elseif c.Type == "checkbox" or c.Type == "radio" then 11 elseif c.Type == "output" and caption == "" then 0 else metrics.TextSize * (if c.Type == "textarea" then math.clamp(AttributeValues.positive(a.rows,2),1,1000) else 1)
		item.ControlMeasureKey=key
	end
	item.TextSize=metrics.TextSize
	return true
end
local function definiteControlWidth(item: any): number?
	-- Flex/grid may temporarily replace item.Style with an allocated width.
	-- Only an authored, percentage-independent size can constrain caption growth.
	local s=item.Control.LayoutStyle or item.Style
	local width=s.Width
	if not width or width.Percent or width.Intrinsic then return nil end
	local resolved=math.max(0,LengthExpression.resolve(width,0))
	local actual=if s.BoxSizing=="border-box" then item.BoxWidth else item.ContentWidth
	-- A shrinking flex item can still depend on the caption's automatic minimum.
	if not actual or actual+0.00001<resolved then return nil end
	return resolved
end
function View.canKeepLayout(item: any, measure: any, alive: any): boolean
	local c=item.Control
	local placed=item.PlacedControlMetrics
	if not c or not placed or (c.Type ~= "output" and c.Type ~= "button" and c.Type ~= "submit" and c.Type ~= "reset" and c.Type~="select") then return false end
	local value=if c.Type=="output" then c.Value else c.Caption
	local rows,size,list=c.SelectRows,c.SelectSize,c.SelectList
	if not View.measure(item,measure,alive) or not alive() or (if c.Type=="output" then c.Value else c.Caption) ~= value
		or rows~=c.SelectRows or size~=c.SelectSize or list~=c.SelectList then return false end
	local fixedWidth=definiteControlWidth(item)
	local sameWidth=item.IntrinsicWidth == placed.Width or (fixedWidth~=nil and fixedWidth==placed.DefiniteWidth)
	return sameWidth and item.IntrinsicHeight == placed.Height
		and item.TextSize == placed.TextSize and item.FontFace == placed.FontFace
		and (c.Type~="select" or (item.GroupFontFace==placed.GroupFontFace and size==placed.SelectSize and list==placed.SelectList))
end
function View.align(item: any)
	local c,s=item.Control,item.Style
	local metrics=View.metrics(item)
	local baseline=if c.DisplayOnly or c.Type == "image" or c.Type == "checkbox" or c.Type == "radio" or c.Type == "range" then item.Height-s.Margin[3] else s.Margin[1]+textTop(item,metrics)+metrics.Baseline
	if s.VerticalAlign == "baseline" then item.Baseline,item.Ascent,item.Descent=baseline,baseline,item.Height-baseline end
end
function View.arrange(item: any)
	if item.Control.Type=='hidden'or ElementNames.htmlName(item.Control.Node)=='input'and item.ViewType and item.ViewType~=item.Control.Type then return end
	if item.Control.Type=="image" then ImageBox.arrange(item);return end
	local c,s=item.Control,item.Style
	write(item.BoxGui,"Visible",s.Visibility ~= "hidden")
	local bt,br,bb,bl=Geometry.sizes(s)
	local metrics=View.metrics(item)
	local top=textTop(item,metrics)
	local captionButton=c.Type=='button'or c.Type=='submit'or c.Type=='reset'
	local textHeight=if singleLineInput(item)or captionButton then math.min(metrics.TextSize,math.max(0,item.BoxHeight-bb-s.Padding[3]-top)) else item.ContentHeight
	local nativeToggle=(c.Type=="checkbox" or c.Type=="radio") and s.Appearance~="none"
	local visualSize=math.max(0,math.min(item.BoxWidth,item.BoxHeight))
	local visualWidth=if nativeToggle then visualSize else item.BoxWidth
	local visualHeight=if nativeToggle then visualSize else item.BoxHeight
	item.PaintWidth,item.PaintHeight=visualWidth,visualHeight
	write(item.BoxGui,"Position",UDim2.fromOffset(s.Margin[4]+(item.BoxWidth-visualWidth)/2,s.Margin[1]+(item.BoxHeight-visualHeight)/2))
	write(item.BoxGui,"Size",UDim2.fromOffset(visualWidth,visualHeight))
	if item.Ticks then
		local size=math.max(0,math.min(visualWidth,visualHeight))
		local scale=size/13
		local left,top=(visualWidth-size)/2,(visualHeight-size)/2
		for index,tick in item.Ticks do
			local part=CHECKMARK_PARTS[index]
			write(tick,"Position",UDim2.fromOffset(left+part[1]*scale,top+part[2]*scale))
			write(tick,"Size",UDim2.fromOffset(part[3]*scale,part[4]*scale))
		end
	end
	if item.SelectScroll then
		write(item.SelectScroll,"Position",UDim2.fromOffset(bl+s.Padding[4],bt+s.Padding[1]))
		write(item.SelectScroll,"Size",UDim2.fromOffset(item.ContentWidth,item.ContentHeight))
		write(item.SelectScroll,"CanvasSize",UDim2.fromOffset(0,#(item.Control.SelectRows or item.Control.Options)*item.SelectRowHeight))
	end
	if item.ColorSwatch then
		write(item.ColorSwatch,"Position",UDim2.fromOffset(bl+s.Padding[4],bt+s.Padding[1]))
		write(item.ColorSwatch,"Size",UDim2.fromOffset(item.ContentWidth,item.ContentHeight))
	end
	if item.TemporalIcon then TemporalView.arrange(item,bl+s.Padding[4],top,textHeight) end
	if item.FileButton then FileView.arrange(item,bl+s.Padding[4],bt+s.Padding[1]) end
	for _, text in {item.Editor or false,item.Label or false} do
		if text then
			write(text,"Position",UDim2.fromOffset(bl+s.Padding[4],top))
			write(text,"Size",UDim2.fromOffset(math.max(0,item.ContentWidth-(if item.Control.Type == "select" then 18 elseif item.Control.Type == "number" then NumberView.ReservedWidth else 0)),textHeight))
			write(text,"FontFace",item.FontFace); write(text,"TextSize",item.TextSize); write(text,"OpenTypeFeatures",s.OpenTypeFeatures)
		end
	end
	View.paint(item)
	-- Compare future changes with the actual layout, never a speculative measurement.
	if c.Type=="output" or c.Type=="button" or c.Type=="submit" or c.Type=="reset" or c.Type=="select" then
		local owner=item.PaintOwner or item
		local placed=owner.PlacedControlMetrics or {}
		placed.Width,placed.Height,placed.TextSize,placed.FontFace=item.IntrinsicWidth,item.IntrinsicHeight,item.TextSize,item.FontFace
		placed.DefiniteWidth=definiteControlWidth(item)
		placed.GroupFontFace,placed.SelectSize,placed.SelectList=item.GroupFontFace,c.SelectSize,c.SelectList
		owner.PlacedControlMetrics=placed
	end
end

function View.updateCaret(item: any)
	local caret,editor=item.Caret,item.Editor
	if not caret or not editor then return end
	local position=editor.CursorPosition or -1
	local visible=item.Control.Focused and position>=1 and item.Style.Visibility~="hidden"
	write(caret,"Visible",visible);if not visible then return end
	local text=editor.Text or ""
	local prefix=text:sub(1,math.clamp(position-1,0,#text));local width=0
	if item.Control.Type=="password"then
		local count=0;for _ in Strings.codes(prefix)do count+=1 end
		prefix=string.rep("•",count)
	end
	if item.MeasureText then local bounds=item.MeasureText(prefix,item.FontFace,item.TextSize,0);if bounds then width=bounds.X end end
	local p=editor.Position;local x=(p.X and p.X.Offset or p[1] or 0)+math.min(width,math.max(0,item.ContentWidth-1))
	local y=(p.Y and p.Y.Offset or p[2] or 0);local shape=item.Style.CaretShape
	local w,h,dy=1,math.max(1,item.TextSize),0
	if shape=="block" then w=math.max(2,item.TextSize*.55) elseif shape=="underscore" then w,h,dy=math.max(2,item.TextSize*.55),2,math.max(0,item.TextSize-2) end
	write(caret,"Position",UDim2.fromOffset(x,y+dy));write(caret,"Size",UDim2.fromOffset(w,h));write(caret,"BackgroundColor3",item.Style.CaretColor);write(caret,"BackgroundTransparency",1-(item.Style.CaretColorAlpha or 1))
end
-- Input type changes replace only anonymous widget content. The form state,
-- author element, primary hit GUI and containing layout records stay retained.
function View.syncInput(item:any):boolean
	local c=item.Control
	if ElementNames.htmlName(c.Node)~='input'or item.ViewType==c.Type then return false end
	local spec=item.ViewSpec or{};local previous=item.ViewType
	View.release(item)
	if item.ControlOutline then BorderBox.remove(item.ControlOutline.Edges,item.ControlOutline.Gui);item.ControlOutline.Gui:Destroy()end
	if item.Outline then BorderBox.remove(item.Outline.Edges,item.Outline.Gui);item.Outline.Gui:Destroy()end
	if item.BorderEdges then BorderBox.remove(item.BorderEdges,item.BoxGui)end
	if item.BoxGui then item.BoxGui:Destroy()end
	if item.OpacityGroup then item.OpacityGroup.Gui:Destroy()end
	for _,key in {'BoxGui','Corner','Stroke','Editor','Label','Caret','ColorSwatch','RadioRing','Dot','DotImage','Ticks','MixedMark',
		'RangeTrack','RangeTrackStroke','RangeFill','RangeThumb','NumberArrows','NumberGlyphs','FileButton','FileCaption','FileButtonWidth',
		'TemporalIcon','TemporalLabels','TemporalFactory','TemporalLeft','TemporalTop','TemporalHeight','ResizeGrip','ControlOutline','ControlOutlineSpec',
		'Outline','BorderEdges','BoxCorner','ImageFactory','ImageGui','ImageClip','ImageCorner','FallbackGui','AltGui','ErrorGui','OpacityGroup',
		'BlurGui','BlurReady','SVGEffectGui','SVGEffectReady','SVGEffectPlan','SVGEffectPixels','AltWidth','AltHeight','AltInkHeight','AltSize','AltMeasuredText','AltMeasuredFace',
		'IndividualCorners','ControlMeasureKey','PlacedControlMetrics','IntrinsicWidth','IntrinsicHeight','InputLineBaseline','TextFallback'}do item[key]=nil end
	item.Gui.Visible=not item.Style.Hidden
	View.create(item,item.Gui,item.Factory,item.FontFace,spec.RadioDot,spec.ResizeGrip,item.BorderCorners,true)
	return previous~=c.Type
end
function View.release(item: any)
	OutputView.release(item)
	if item.ControlBorderEdges then BorderBox.remove(item.ControlBorderEdges,item.BoxGui);item.ControlBorderEdges=nil end
end
return View
