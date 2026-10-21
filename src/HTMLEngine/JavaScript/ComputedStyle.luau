--!strict
-- Serialization of the engine's supported computed/used style fields. Complex
-- CSS values remain the renderer adapter's responsibility; unsupported values
-- are omitted instead of reporting author text as a computed value.
local Properties=require(script.Parent.Parent.CSS.Properties)
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Transform=require(script.Parent.Parent.CSS.Transform2D)
local Individuals=require(script.Parent.Parent.CSS.IndividualTransformValues)
local Anchor=require(script.Parent.Parent.CSS.AnchorPosition)
local PositionArea=require(script.Parent.Parent.CSS.PositionArea)
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)
local Borders=require(script.Parent.Parent.Layout.BorderGeometry)
local BoxShadow=require(script.Parent.Parent.CSS.BoxShadow)
local ComputedStyle={}
local function decimal(n: number): string
 if n==0 or math.abs(n)<1e-12 then return '0' end
 return string.format('%.12g',n)
end
local function px(n: number): string return decimal(n)..'px' end
-- These properties expose computed lengths, unlike width/height's used box
-- dimensions. Keep percentages and math responsive to their containing block.
local function computedLength(value: any): string?
 if type(value)=='number'then return px(value)elseif type(value)=='string'then return value end
 if type(value)~='table'then return nil end
 if value.PickerStretch then return 'stretch'end
 if value.Intrinsic then return value.Intrinsic end
 local expression=value.Expression
 if not expression then return if type(value.Value)=='number'then decimal(value.Value)..(if value.Percent then '%'else 'px')else nil end
 local emit
 emit=function(node)
  if node.Op=='linear'then
   if node.PercentValue==0 then return px(node.Pixels)elseif node.Pixels==0 then return decimal(node.PercentValue)..'%'end
   return decimal(node.PercentValue)..'% '..(if node.Pixels<0 then '- 'else '+ ')..px(math.abs(node.Pixels))
  elseif node.Op=='number'then return decimal(node.Value)
  elseif node.Op=='add'or node.Op=='subtract'then return '('..emit(node.Left)..')'..(if node.Op=='add'then ' + 'else ' - ')..'('..emit(node.Right)..')'
  elseif node.Op=='multiply'then return '('..emit(node.Left)..') * '..decimal(node.Scalar)end
  local parts={};for _,child in node.Values do table.insert(parts,emit(child))end
  return node.Op..'('..table.concat(parts,', ')..')'
 end
 local text=emit(expression)
 return if expression.Op=='min'or expression.Op=='max'or expression.Op=='clamp'then text else 'calc('..text..')'
end
local function color(value: any,alpha: any): string?
 if value==nil then return nil end
 if type(value)=='string' then return value end
 local r,g,b=value.R,value.G,value.B
 if r==nil or g==nil or b==nil then return nil end
 r,g,b=math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5)
 alpha=alpha or 1
 return if alpha==1 then 'rgb('..r..', '..g..', '..b..')' else 'rgba('..r..', '..g..', '..b..', '..decimal(alpha)..')'
end
local function pixels(value: any,basis: number): number
 return if type(value)=='number' then value elseif type(value)=='table'then Length.resolve(value,basis)else 0
end
local function compressed(parts: any): string
 if parts[2]==parts[4]then table.remove(parts,4);if parts[1]==parts[3]then table.remove(parts,3);if parts[1]==parts[2]then table.remove(parts,2)end end end
 return table.concat(parts,' ')
end
local function cssString(value: string): string
 -- CSSOM strings use escaped code points for ASCII controls, including DEL.
 -- Attribute substitution can contain these even when author CSS strings do not.
 local escaped=value:gsub('[%z\1-\31\127"\\]',function(character)
  if character=='\0'then return utf8.char(0xfffd)end
  if character=='"'or character=='\\'then return '\\'..character end
  return '\\'..string.format('%x',string.byte(character))..' '
 end)
 return '"'..escaped..'"'
end
-- Serialize parsed values, never authored declarations or the canvas's used
-- paint projection. In particular currentColor belongs to this DOM element.
local function backgroundImages(images: any,style: any): string?
 local function axis(value: any): string?
  if not value.Offset then return decimal((value.Anchor or 0)*100)..'%'end
  if (value.Anchor or 0)==0 then return computedLength(value.Offset)end
  local offset=value.Offset
  if offset.Expression and offset.Expression.Op~='linear'then return nil end
  local percent=(value.Anchor or 0)*100-(if offset.Expression then offset.Expression.PercentValue elseif offset.Percent then offset.Value else 0)
  local pixels=-(if offset.Expression then offset.Expression.Pixels elseif offset.Percent then 0 else offset.Value)
  if pixels==0 then return decimal(percent)..'%'end
  return 'calc('..decimal(percent)..'% '..(if pixels<0 then '- 'else '+ ')..px(math.abs(pixels))..')'
 end
 local function position(value: any): string?
  value=value or {X={Anchor=.5},Y={Anchor=.5}}
  local x,y=axis(value.X),axis(value.Y);if not x or not y then return nil end
  return if x=='50%'and y=='50%'then ''else 'at '..x..' '..y
 end
 local image
 image=function(value: any): string?
  local kind=value.Kind
  if kind=='none'then return 'none'end
  if kind=='url'then
   -- Relative stylesheet URLs need their own captured declaration base. That
   -- separate loader/cascade requirement must not report a fabricated URL.
   if value.Source~=''and not value.Source:match('^[%a][%w+%.%-]*:')then return nil end
   return 'url('..cssString(value.Source)..')'
  end
  if kind=='image-set'then
   local parts={}
   for _,candidate in value.Candidates do
    local serialized=image(candidate.Image);if not serialized then return nil end
    table.insert(parts,serialized..' '..decimal(candidate.Density)..'dppx'..(if candidate.Type then ' type('..cssString(candidate.Type)..')'else ''))
   end
   return 'image-set('..table.concat(parts,', ')..')'
  end
  if kind~='linear'and kind~='radial'and kind~='conic'then return nil end
  local parts={}
  if kind=='linear'then
   if value.Direction and value.Direction~='to bottom'then table.insert(parts,value.Direction)
   elseif not value.Direction and value.Angle~=180 then table.insert(parts,decimal(value.Angle)..'deg')end
  else
   local prelude={}
   if kind=='radial'then
    if type(value.Size)=='table'then
     for _,size in value.Size do local length=computedLength(size);if not length then return nil end;table.insert(prelude,length)end
    else
     if value.Shape=='circle'then table.insert(prelude,'circle')end
     if value.Size and value.Size~='farthest-corner'then table.insert(prelude,value.Size)end
    end
   elseif value.Angle~=0 then table.insert(prelude,'from '..decimal(value.Angle)..'deg')end
   local at=position(value.Position);if at==nil then return nil end;if at~=''then table.insert(prelude,at)end
   if #prelude>0 then table.insert(parts,table.concat(prelude,' '))end
  end
  for _,stop in value.Stops do
   local current=stop.Color=='currentcolor'
   local alpha=if current then style.ColorAlpha or 1 else stop.Alpha or 1
   local shade=color(if current then style.Color else stop.Color,math.floor(alpha*1000+.5)/1000)
   if not shade then return nil end
   for _,offset in stop.Positions do
    local length=if kind=='conic'and(offset.ConicAngle or not offset.Percent)then decimal(offset.Value*3.6)..'deg'else computedLength(offset)
    if not length then return nil end;shade..=' '..length
   end
   table.insert(parts,shade)
  end
  return (if value.Repeating then 'repeating-'else '')..kind..'-gradient('..table.concat(parts,', ')..')'
 end
 local parts={}
 for _,value in images or {{Kind='none'}}do local serialized=image(value);if not serialized then return nil end;table.insert(parts,serialized)end
 return table.concat(parts,', ')
end
function ComputedStyle.read(style: any,box: any?,viewport: any): any
 if not style then return {Names={},Values={}} end
 if box and box.AnchorUsedStyle then
  local base=table.clone(style)
  for _,field in {'Width','Height','MinWidth','MaxWidth','MinHeight','MaxHeight','Margin','MarginValues','MarginAuto','Insettop','Insetright','Insetbottom','Insetleft','PositionAnchor','PositionArea','AlignSelf','JustifySelf'}do
   local raw=style[field]
   -- The UA stretch bound is a computed keyword; its trial-layout pixel limit
   -- determines geometry without replacing the CSSOM computed constraint.
   if not(type(raw)=='table'and raw.PickerStretch)then base[field]=box.AnchorUsedStyle[field]end
  end
  style=base
 end
 local values={}
 local width=if box then box.OuterWidth or 0 else 0
 local height=if box then box.OuterHeight or 0 else 0
 local basis=style.ContainingWidth or viewport.Width or 0
 for name,spec in Properties do
  local value=style[spec.Field]
  if spec.Side and type(value)=='table'then value=value[spec.Side]end
  if value==nil then continue end
  if (spec.Kind=='enum'or spec.Kind=='container-type'or spec.Kind=='underline-position')and type(value)=='string'then values[name]=value
  elseif (spec.Kind=='number'or spec.Kind=='opacity'or spec.Kind=='order'or spec.Kind=='column-count')and type(value)=='number'then values[name]=decimal(value)
  elseif spec.Kind=='color'then values[name]=color(value,style[spec.Field..'Alpha'])
  elseif spec.Kind=='length'and type(value)=='number'then values[name]=px(value)
  end
 end
 values.display=style.Display or values.display
 values.position=style.Position or values.position
 values['position-try-order']=style.PositionTryOrder or 'normal'
 values['position-try-fallbacks']=Anchor.serializeTries(style.PositionTryFallbacks or {},true)
 values['position-anchor']=style.PositionAnchor or 'normal'
 values['position-area']=PositionArea.serialize(style.PositionArea or 'none',true)
 for _,side in {'top','right','bottom','left'}do values[side]=computedLength(style['Inset'..side])or 'auto'end
 values.visibility=if style.VisibilityCollapse then 'collapse'else style.Visibility or values.visibility
 local scheme=style.ColorScheme
 if scheme then
  local order=scheme.Order
  if not order then order={};for _,entry in{{'Light','light'},{'Dark','dark'},{'Only','only'}}do if scheme[entry[1]]then table.insert(order,entry[2])end end end
  values['color-scheme']=if scheme.Normal then 'normal'else table.concat(order,' ')
 end
 values.opacity=decimal(style.Opacity or 1)
 values.order=decimal(style.Order or 0)
 values['column-count']=if style.ColumnCount==nil then 'auto'else decimal(style.ColumnCount)
 values['column-width']=if style.ColumnWidth==nil then 'auto'else px(pixels(style.ColumnWidth,basis))
 if box and box.OpacityGroup and box.OpacityGroup.SampledOpacity~=nil then values.opacity=decimal(box.OpacityGroup.SampledOpacity)end
 values.color=color(style.Color,style.ColorAlpha)
 values['background-color']=color(style.Background,style.BackgroundAlpha)or 'rgba(0, 0, 0, 0)'
 values['background-image']=backgroundImages(style.BackgroundImages,style)
 values['box-shadow']=BoxShadow.serialize(box and box.SampledBoxShadows or style.BoxShadows,{Color=style.Color,Alpha=style.ColorAlpha or 1})
 values['text-shadow']=BoxShadow.serialize(style.TextShadows,{Color=style.Color,Alpha=style.ColorAlpha or 1},true)
 if box and box.SampledBackgroundColor then values['background-color']=color(box.SampledBackgroundColor.Color,box.SampledBackgroundColor.Alpha)end
 if style.FontSize then values['font-size']=px(style.FontSize)end
 if style.FontWeight then values['font-weight']=tostring(style.FontWeight)end
 if style.FontStyle then values['font-style']=style.FontStyle end
 if style.Font then values['font-family']=style.Font end
 if style.GeneratedContent then
  local parts,strings={},{}
  local function flushStrings()
   if #strings>0 then table.insert(parts,cssString(table.concat(strings)));strings={}end
  end
  for _,part in style.GeneratedContent do
   if part.Kind=='text'then table.insert(strings,part.Value)
   elseif part.Kind=='attr'then table.insert(strings,style.Node and style.Node.Attributes[part.Name]or'')
   else
    flushStrings()
    if part.Kind=='quote'then table.insert(parts,part.Value)
    elseif part.Kind=='counter'or part.Kind=='counters'then
     local format=if type(part.Style)=='string'then part.Style else 'decimal'
     local args=part.Name..(if part.Kind=='counters'then', '..cssString(part.Separator)else'')
     if format~='decimal'then args..=', '..format end
     table.insert(parts,part.Kind..'('..args..')')
    end
   end
  end
  flushStrings()
  local mode=style.GeneratedContent.Mode or 'normal'
  if mode=='normal'and(style.PseudoElement=='before'or style.PseudoElement=='after')then mode='none'end
  values.content=if #parts==0 then mode else table.concat(parts,' ')
 end
 if style.LineHeight then
  local line=style.LineHeight
  values['line-height']=if line.Kind=='normal'then 'normal'elseif line.Kind=='number'then px(line.Value*(style.FontSize or 16))elseif line.Kind=='percent'then px(line.Value*(style.FontSize or 16)/100)elseif line.Kind=='length'then px(pixels(line.Length,style.FontSize or 16))else px(line.Value or 0)
 end
 for _,entry in {{'letter-spacing','LetterSpacing'},{'word-spacing','WordSpacing'}}do
  if style[entry[2]]~=nil then values[entry[1]]=if style[entry[2]]==0 then 'normal'else px(style[entry[2]])end
 end
 local bt,br,bb,bl=Borders.sizes(style);local border={bt,br,bb,bl}
 local sides={'top','right','bottom','left'}
 for _,entry in {{'padding','Padding'},{'margin','Margin'}}do
  local parts={}
  for i,side in sides do
   local raw=style[entry[2]]and style[entry[2]][i]
   -- Layout resolves percentage padding/margins into these side arrays.
   parts[i]=px(pixels(raw,basis));values[entry[1]..'-'..side]=parts[i]
  end
  values[entry[1]]=compressed(parts)
 end
 local widths,styles,colors={},{},{}
 for i,side in sides do
  local edge=style.BorderSides and style.BorderSides[i]
  widths[i]=px(border[i]);styles[i]=if edge then edge.Style else style.BorderStyles and style.BorderStyles[i]or style.BorderStyle or 'none'
  colors[i]=color(if edge then edge.Color else style.BorderColors and style.BorderColors[i]or style.BorderColor or style.Color,
   if edge then edge.Alpha elseif style.BorderColorAlphas then style.BorderColorAlphas[i]else style.BorderColorAlpha or style.ColorAlpha)or 'rgb(0, 0, 0)'
  values['border-'..side..'-width']=widths[i];values['border-'..side..'-style']=styles[i];values['border-'..side..'-color']=colors[i]
 end
 values['border-width']=compressed(widths);values['border-style']=compressed(styles);values['border-color']=compressed(colors)
 local radiusX,radiusY={},{}
 for i,corner in {'top-left','top-right','bottom-right','bottom-left'}do
  local radius=style.BorderRadii and style.BorderRadii[i]
  local x,y=if radius then computedLength(radius.X)or'0px'else px(style.BorderRadius or 0),if radius then computedLength(radius.Y)or'0px'else px(style.BorderRadius or 0)
  radiusX[i],radiusY[i]=x,y;values['border-'..corner..'-radius']=if x==y then x else x..' '..y
 end
 local x,y=compressed(radiusX),compressed(radiusY);values['border-radius']=if x==y then x else x..' / '..y
 if box and style.Display~='inline'and style.Display~='contents'then
  values.width=px(if style.BoxSizing=='border-box'then width else box.ContentWidth or math.max(0,width-bl-br-pixels(style.Padding and style.Padding[2],basis)-pixels(style.Padding and style.Padding[4],basis)))
  values.height=px(if style.BoxSizing=='border-box'then height else box.ContentHeight or math.max(0,height-bt-bb-pixels(style.Padding and style.Padding[1],basis)-pixels(style.Padding and style.Padding[3],basis)))
 else
  for _,name in {'width','height'}do local raw=style[if name=='width'then 'Width'else 'Height'];values[name]=computedLength(raw)or 'auto'end
 end
 values['box-sizing']=style.BoxSizing or 'content-box'
 values['outline-width']=px(if (style.OutlineWidth or 0)<=0 then 0 else math.max(1,math.floor(style.OutlineWidth)))
 values['outline-style']=style.OutlineStyle or 'none'
 values['outline-offset']=px(style.OutlineOffset or 0)
 values['outline-color']=color(style.OutlineColor,style.OutlineColorAlpha)or values.color
 values['text-decoration-color']=if style.DecorationColor==nil or style.DecorationColor=='currentcolor'then values.color else color(style.DecorationColor,style.DecorationColorAlpha)
 values['text-emphasis-color']=if style.TextEmphasisColor==nil or style.TextEmphasisColor=='currentcolor'then values.color else color(style.TextEmphasisColor,style.TextEmphasisColorAlpha)
 local emphasis=style.TextEmphasisStyle
 values['text-emphasis-style']=if not emphasis then 'none'elseif emphasis.String~=nil then cssString(emphasis.String)else (emphasis.Fill or 'filled')..' '..(emphasis.Shape or 'circle')
 local emphasisPosition=style.TextEmphasisPosition or {Vertical='over',Horizontal='right'}
 values['text-emphasis-position']=(emphasisPosition.Vertical or 'over')..(if emphasisPosition.Horizontal=='left'then ' left'else '')
 local parentDisplay=box and box.LayoutParent and box.LayoutParent.Style.Display
 local automaticMinimum=if style.Position~='absolute'and style.Position~='fixed'and (parentDisplay=='flex'or parentDisplay=='inline-flex'or parentDisplay=='grid'or parentDisplay=='inline-grid')then 'auto'else '0px'
 for _,entry in {{'min-width','MinWidth'},{'min-height','MinHeight'},{'max-width','MaxWidth'},{'max-height','MaxHeight'}}do
  values[entry[1]]=computedLength(style[entry[2]])or (if entry[1]:sub(1,3)=='min'then automaticMinimum else 'none')
 end
 for _,prefix in {'','min-','max-'}do
  values[prefix..'inline-size']=values[prefix..(if WritingMode.vertical(style)then 'height'else 'width')]
  values[prefix..'block-size']=values[prefix..(if WritingMode.vertical(style)then 'width'else 'height')]
 end
 if type(style.ListStyleType)=='string'then values['list-style-type']=style.ListStyleType end
 values['flex-grow']=decimal(style.FlexGrow or 0);values['flex-shrink']=decimal(style.FlexShrink or 1)
 values['flex-basis']=computedLength(style.FlexBasis)or'auto'
 local gap=style.Gap or {0,0}
 for i,name in {'row-gap','column-gap'}do
  local specified=if i==1 then style.RowGapSpecified else style.GridGapSpecified
  values[name]=if specified==false or specified==nil and pixels(gap[i],0)==0 and not (type(gap[i])=='table'and gap[i].Percent)then 'normal'else computedLength(gap[i])or 'normal'
 end
 values.gap=if values['row-gap']==values['column-gap']then values['row-gap']else values['row-gap']..' '..values['column-gap']
 values['overflow-x']=style.OverflowX or style.Overflow or 'visible';values['overflow-y']=style.OverflowY or style.Overflow or 'visible'
 values.overflow=if values['overflow-x']==values['overflow-y']then values['overflow-x']else values['overflow-x']..' '..values['overflow-y']
 if style.ZIndex==nil then values['z-index']='auto'else values['z-index']=tostring(style.ZIndex)end
 for property in Individuals.Fields do values[property]=Individuals.serialize(property,box and box.SampledIndividualTransforms and box.SampledIndividualTransforms[property]or Individuals.fromStyle(style,property))end
 local operations=if box and box.SampledTransformPropertyOperations then box.SampledTransformPropertyOperations elseif box and box.TransformOverride then box.TransformOverride else style.Transform or{}
 if box and box.TransformOverride and not box.SampledTransformPropertyOperations then
  local skip=0;for _,field in {'Translate','Rotate','Scale'}do if style[field]then skip+=1 end end
  local property={};for i,op in operations do if i>skip then table.insert(property,op)end end;operations=property
 end
 if #operations==0 then values.transform='none'else
  local m=Transform.matrix(operations,width,height);local parts={}
  if math.abs(m[3])+math.abs(m[4])+math.abs(m[7])+math.abs(m[8])+math.abs(m[9])+math.abs(m[10])+math.abs(m[11]-1)+math.abs(m[12])+math.abs(m[15])+math.abs(m[16]-1)<1e-10 then
   for _,i in {1,2,5,6,13,14}do table.insert(parts,decimal(m[i]))end;values.transform='matrix('..table.concat(parts,', ')..')'
  else for i=1,16 do table.insert(parts,decimal(m[i]))end;values.transform='matrix3d('..table.concat(parts,', ')..')'end
 end
 if style.TransformOrigin then local x,y=Transform.origin(style.TransformOrigin,width,height);values['transform-origin']=px(x)..' '..px(y);local z=pixels(style.TransformOrigin.Z,0);if z~=0 then values['transform-origin']..=' '..px(z)end end
 for name,value in style.Custom or {}do if type(value)=='string'then values[name]=value end end
 local names={};for name,value in values do if type(value)=='string'then table.insert(names,name)else values[name]=nil end end;table.sort(names)
 return {Names=names,Values=values}
end
ComputedStyle.decimal=decimal
return ComputedStyle
