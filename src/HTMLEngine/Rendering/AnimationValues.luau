--!strict
-- Numeric layout values share the CSS parser and retained layout boxes. Author
-- fields are kept separately from sampled values, so cancellation and later
-- style edits never turn a sampled frame into the new underlying declaration.
local Properties=require(script.Parent.Parent.CSS.Properties)
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local CornerRadii=require(script.Parent.CornerRadii)
local Variables=require(script.Parent.Parent.CSS.Variables)
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local BoxShadow=require(script.Parent.Parent.CSS.BoxShadow)
local Values={}
local names={'width','height','min-width','max-width','min-height','max-height','inline-size','block-size','min-inline-size','max-inline-size','min-block-size','max-block-size','top','right','bottom','left','flex-basis','flex-grow','flex-shrink','row-gap','column-gap','letter-spacing','word-spacing','order','column-count','column-width','outline-width','outline-offset','font-size','line-height','box-shadow','transform-origin','text-shadow'}
for _,family in {'margin','padding'}do for _,side in {'top','right','bottom','left'}do table.insert(names,family..'-'..side)end end
for _,side in {'top','right','bottom','left'}do table.insert(names,'border-'..side..'-width')end
local cornerIndices={['top-left']=1,['top-right']=2,['bottom-right']=3,['bottom-left']=4}
for corner in cornerIndices do table.insert(names,'border-'..corner..'-radius')end
Values.Properties={};Values.Fields={}
for _,name in names do local spec=Properties[name];if spec then Values.Properties[name]=spec;Values.Fields[spec.Field]=name end end
local decorationFields={BorderSides=true,BorderSizes=true,BorderSize=true,BorderUniform=true,BorderWidth=true,OutlineWidth=true,OutlineOffset=true,BorderRadii=true,BorderRadius=true,NativeCornerRadii=true,BoxShadows=true}
local paintFields={OutlineWidth=true,OutlineOffset=true,BorderRadii=true,BorderRadius=true,NativeCornerRadii=true,BorderUniform=true,BoxShadows=true,TransformOrigin=true}
local borderFields={'BorderSides','BorderSizes','BorderSize','BorderUniform','BorderWidth'}
local radiusFields={'BorderRadii','BorderRadius','NativeCornerRadii'}
local function pixelWidth(value)
 return if value<=0 then 0 else math.max(1,math.floor(value))
end
local function radiusLength(value)
 if type(value)=='number'then return math.max(0,value)end
 if type(value)=='table'and not value.Expression and type(value.Value)=='number'and value.Value<0 then local result=table.clone(value);result.Value=0;return result end
 return value
end
function Values.matches(spec,entry,property)
 return entry.VariableProperty==property or entry.VariableProperty=='border-width'and spec.BorderSide~=nil or (property=='font-size'or property=='line-height')and(entry.Field=='FontShorthand'or entry.VariableProperty=='font')or entry.Field==spec.Field
  and(not spec.Side or not entry.Side or spec.Side==entry.Side)
  and(not spec.BorderSide or not entry.BorderSide or spec.BorderSide==entry.BorderSide)
  and(not spec.Corner or not entry.Corner or spec.Corner==entry.Corner)
end
local integers={order=-math.huge,['column-count']=1}
local numbers={order=true,['column-count']=true,['flex-grow']=true,['flex-shrink']=true}
local function equal(a,b)
 if a==b then return true end;if type(a)~='table'or type(b)~='table'then return false end
 for k,v in a do if not equal(v,b[k])then return false end end;for k in b do if a[k]==nil then return false end end;return true
end
local function authorField(style,authors,name)local author=authors and authors[name];return if author then author.Value else style[name]end
local function read(style,spec,authors)
 if spec.Field=='Gap'then
  local flag=if spec.Side==1 then 'RowGapSpecified'else 'GridGapSpecified'
  local specified=authorField(style,authors,flag)
  if specified==false then return {Keyword='normal'}end
 end
 if spec.Corner then
  local radii=authorField(style,authors,'BorderRadii');local radius=authorField(style,authors,'BorderRadius')or 0
  return if radii then radii[cornerIndices[spec.Corner]]else {X={Value=radius,Percent=false},Y={Value=radius,Percent=false}}
 elseif spec.BorderSide then
  local sides=authorField(style,authors,'BorderSides');local edge=sides and sides[spec.BorderSide]
  return if edge then edge.Width else authorField(style,authors,'BorderWidth')or 0
 end
 local auto=if spec.Side and spec.Field=='Margin'then authorField(style,authors,'MarginAuto')else nil
 if auto and auto[spec.Side]then return {Auto=true}end
 local source=if spec.Side then authorField(style,authors,spec.Field..'Values')else nil
 local value=if source~=nil then source else authorField(style,authors,spec.Field)
 return if spec.Side and type(value)=='table'then value[spec.Side]else value
end
function Values.base(box,property)
 if property=='text-shadow'and box.AnimationTextShadowAuthor then return box.AnimationTextShadowAuthor.Value or {}end
 local style=box.AnimationMetricUnderlyingStyle or box.Style
 local authors=if box.AnimationMetricUnderlyingStyle then nil else box.AnimationAuthorFields
 if property=='font-size'or property=='line-height'then
  if box.AnimationMetricUnderlyingStyle then return if property=='font-size'then style.UnadjustedFontSize or style.FontSize else style.LineHeight end
  local fields=box.AnimationMetricAuthor;return if fields then fields[if property=='font-size'then'FontSize'else'LineHeight']else style[if property=='font-size'then'UnadjustedFontSize'else'LineHeight']or style.FontSize
 end
 local spec=Values.Properties[property]
 if spec.BorderSide then
  local sizes=authorField(style,authors,'BorderSizes')
  return pixelWidth(if sizes then sizes[spec.BorderSide]else authorField(style,authors,'BorderSize')or 0)
 elseif property=='outline-width'then return pixelWidth(read(style,spec,authors)or 0)end
 local result=read(style,Values.Properties[property],authors);return if result==nil then(if property=='box-shadow'or property=='text-shadow'then {}else {Auto=true})else result
end
function Values.fromStyle(style,property)local result=read(style,Values.Properties[property]);return if result==nil then(if property=='box-shadow'or property=='text-shadow'then {}else {Auto=true})else result end
-- A line-height number inherits as a multiplier; lengths inherit the resolved
-- length. Relative length stops keep their font coefficient until publication.
function Values.metricStop(frame,property,box,parentStyle,resolve)
 local spec=Values.Properties[property];local entries={}
 for _,entry in frame.Declarations.Normal do if not entry.Error and Values.matches(spec,entry,property)then table.insert(entries,entry)end end
 if #entries==0 then return nil end
 frame.MetricCache=frame.MetricCache or setmetatable({},{__mode='k'})
 local cache=frame.MetricCache[box.Style];if not cache then cache={};frame.MetricCache[box.Style]=cache end
 local parent=parentStyle or box.Style
 if not parentStyle and box.Node and box.Node.Name=='html'then parent=table.clone(parent);parent.FontSize,parent.UnadjustedFontSize,parent.RootFontSize=16,16,16 end
 local nonlinear,wide,invalidVariable=false,nil,false
 for _,entry in entries do
  local source=if entry.VariableProperty then Variables.substitute(entry.Raw,box.Style.Custom)else entry.Relative
  if not source and type(entry.Value)=='table'and entry.Value.Kind=='length'then source=Length.serialize(entry.Value.Length)end
  if entry==entries[#entries]then invalidVariable=entry.VariableProperty~=nil and source==nil end
  if source then
   nonlinear=nonlinear or Syntax.findFunction(source,1,'min')~=nil or Syntax.findFunction(source,1,'max')~=nil or Syntax.findFunction(source,1,'clamp')~=nil
   if entry==entries[#entries]then local name,ending=Syntax.identifier(source);if name and ending>#source then wide=name:lower()end end
  end
 end
 local record=cache[property]
 if record and record.ParentSize==parent.FontSize and record.RootSize==box.Style.RootFontSize and record.Custom==box.Style.Custom and record.ParentLine==parent.LineHeight and(not nonlinear or record.OwnSize==box.Style.FontSize)then return record.Value end
 local function remember(value)cache[property]={ParentSize=parent.FontSize,RootSize=box.Style.RootFontSize,Custom=box.Style.Custom,ParentLine=parent.LineHeight,OwnSize=if nonlinear then box.Style.FontSize else nil,Value=value};return value end
 local fake={Kind='Element',Name=if box.Node and box.Node.Name=='html'then'html'else'div',Attributes={}};local rules={Normal=entries,Important={}}
 if property=='font-size'then local context=table.clone(parent);context.Custom=box.Style.Custom;return remember(resolve(fake,context,function()end,false,rules).FontSize)end
 local winner=entries[#entries]
 if winner.Wide=='inherit'or winner.Wide=='unset'or wide=='inherit'or wide=='unset'or invalidVariable then return remember(parent.LineHeight or {Kind='normal'})end
 if nonlinear then return remember(resolve(fake,box.Style,function()end,false,rules).LineHeight)end
 local zero=table.clone(box.Style);zero.FontSize,zero.UnadjustedFontSize=0,0
 local one=table.clone(zero);one.FontSize,one.UnadjustedFontSize=1,1
 local a=resolve(fake,zero,function()end,false,rules).LineHeight
 if a.Kind~='px'then return remember(a)end
 local b=resolve(fake,one,function()end,false,rules).LineHeight
 return remember({Kind='relative',Pixels=a.Value,Em=b.Value-a.Value})
end
local function lineLength(value)
 if value.Kind=='px'then return value.Value,0 elseif value.Kind=='relative'then return value.Pixels,value.Em end
 return nil,nil
end
local function linear(value,basis)
 if type(value)=='number'then return value,0 end
 if type(value)~='table'then return nil,nil end
 if value.Auto or value.Intrinsic then return nil,nil end
 if value.Kind=='length'and value.Op=='linear'then return value.Pixels,value.PercentValue end
 if value.Expression and value.Expression.Op=='linear'then return value.Expression.Pixels,value.Expression.PercentValue end
 if value.Value~=nil and type(value.Value)=='number'then return if value.Percent then 0 else value.Value,if value.Percent then value.Value else 0 end
 if value.Kind=='length'then return Length.resolve(value,basis),0 end
 return nil,nil
end
local function length(px,pct,number)
 if number then return px end
 if pct==0 then return {Value=px,Percent=false}elseif px==0 then return {Value=pct,Percent=true}end
 return Length.linear(px,pct)
end
local function numeric(value)
 return type(value)=='number'or type(value)=='table'and not value.Auto and not value.Intrinsic and(type(value.Value)=='number'or value.Kind=='length')
end
-- The retained block layout records its natural content extent before applying
-- fixed/animated height. Read that extent, never the preceding sampled height:
-- otherwise an auto endpoint would shrink again on each publication.
local function intrinsic(value,property,box)
 local spec=property and Values.Properties[property]
 if not spec or spec.Field~='Height'or type(value)~='table'or not value.Auto then return nil end
 if property=='block-size'and box.Style.WritingMode~='horizontal-tb'or property=='inline-size'then return nil end
 local height=box.AutoContentHeight;if type(height)~='number'then return nil end
 if box.Style.BoxSizing=='border-box'then height+=math.max(0,(box.OuterHeight or 0)-(box.ContentHeight or 0))end
 return {Value=height,Percent=false,ResolvedKeyword=value}
end
function Values.mix(a,b,t,box,property,interpolateSize)
	if property=='box-shadow'or property=='text-shadow'then return BoxShadow.mix(a,b,t)end
 if property=='transform-origin'then local zero={Value=0,Percent=false};return {X=Values.mix(a.X,b.X,t,box),Y=Values.mix(a.Y,b.Y,t,box),Z=Values.mix(a.Z or zero,b.Z or zero,t,box)}end
	if property=='line-height'then
	 if a.Kind=='number'and b.Kind=='number'then return {Kind='number',Value=a.Value+(b.Value-a.Value)*t}end
	 local ap,ar=lineLength(a);local bp,br=lineLength(b)
	 if ap~=nil and bp~=nil then return {Kind='relative',Pixels=ap+(bp-ap)*t,Em=ar+(br-ar)*t}end
	 return if t<.5 then a else b
	end
	if property and Values.Properties[property]and Values.Properties[property].Corner then return {X=Values.mix(a.X,b.X,t,box),Y=Values.mix(a.Y,b.Y,t,box)}end
	local allowance=interpolateSize or (box.Style and box.Style.InterpolateSize)
	if allowance=='allow-keywords'and numeric(a)~=numeric(b)then
	 local resolved=intrinsic(if numeric(a)then b else a,property,box)
	 if resolved then if numeric(a)then b=resolved else a=resolved end end
	end
	if t==0 and type(a)=='table'and a.ResolvedKeyword then return a.ResolvedKeyword end
	if t==1 and type(b)=='table'and b.ResolvedKeyword then return b.ResolvedKeyword end
 if type(a)=='table'and a.Expression or type(b)=='table'and b.Expression then
  local interpolated=Length.interpolate(a,b,t);if interpolated then return interpolated end
 end
 local ap,ar=linear(a,box.ContentWidth or box.OuterWidth or 0);local bp,br=linear(b,box.ContentWidth or box.OuterWidth or 0)
 if ap==nil or bp==nil then return if t<.5 then a else b end
 local result=length(ap+(bp-ap)*t,ar+(br-ar)*t,type(a)=='number'and type(b)=='number')
 if integers[property]and type(result)=='number'then return math.max(integers[property],math.floor(result+.5))end
 return result
end
function Values.add(a,b,box,count,property,interpolateSize,composition)
 if property=='box-shadow'or property=='text-shadow'then return BoxShadow.add(a,b,composition,count)end
 if property=='transform-origin'then local zero={Value=0,Percent=false};return {X=Values.add(a.X,b.X,box,count),Y=Values.add(a.Y,b.Y,box,count),Z=Values.add(a.Z or zero,b.Z or zero,box,count)}end
 if property=='line-height'then
  count=count or 1
  if a.Kind=='number'and b.Kind=='number'then return {Kind='number',Value=a.Value+b.Value*count}end
  local ap,ar=lineLength(a);local bp,br=lineLength(b)
  if ap~=nil and bp~=nil then return {Kind='relative',Pixels=ap+bp*count,Em=ar+br*count}end
  return b
 end
 if property and Values.Properties[property]and Values.Properties[property].Corner then return {X=Values.add(a.X,b.X,box,count),Y=Values.add(a.Y,b.Y,box,count)}end
 count=count or 1
 local allowance=interpolateSize or(box.Style and box.Style.InterpolateSize)
 if allowance=='allow-keywords'and numeric(a)~=numeric(b)then
  if numeric(a)then b=intrinsic(b,property,box)or b else a=intrinsic(a,property,box)or a end
 end
 if type(a)=='table'and a.Expression or type(b)=='table'and b.Expression then
  -- A weighted sum preserves min/max/clamp and the percentage reference axis.
  local total=1+count;local combined=Length.interpolate(a,b,count/total)
  if combined then combined.Expression={Kind='length',Op='multiply',Left=combined.Expression,Scalar=total,HasPercent=combined.Expression.HasPercent,UsesViewport=combined.Expression.UsesViewport};return combined end
 end
 local ap,ar=linear(a,box.ContentWidth or box.OuterWidth or 0);local bp,br=linear(b,box.ContentWidth or box.OuterWidth or 0)
 if ap==nil or bp==nil then return b end;count=count or 1
 return length(ap+bp*count,ar+br*count,type(a)=='number'and type(b)=='number')
end
function Values.beforeStyleChange(box)
 if not box then return end
 box.SampledBackgroundColor=nil
 box.SampledIndividualTransforms=nil;box.SampledTransformPropertyOperations=nil
 box.SampledBoxShadows=nil
 for field,author in box.AnimationAuthorFields or {}do box.Style[field]=author.Value end
 box.AnimationAuthorFields=nil
end
function Values.write(box,properties,changed,request,paint,metrics)
 box.SampledBoxShadows=if changed['box-shadow']then properties['box-shadow']else nil
 local metricValues={}
 for _,property in {'font-size','line-height'}do if changed[property]then metricValues[if property=='font-size'then'FontSize'else'LineHeight']=if property=='font-size'then math.max(0,properties[property])else properties[property]end end
 if metrics and(next(metricValues)or box.AnimationMetricAuthor)then metrics(box,metricValues)end
 local previous={};local fields={}
 local function capture(field)fields[field]=true;previous[field]=box.Style[field]end
 for field in box.AnimationAuthorFields or {}do capture(field)end
 for property in changed do local spec=Values.Properties[property];if spec and property~='font-size'and property~='line-height'and property~='text-shadow'then
  if spec.BorderSide then for _,field in borderFields do capture(field)end elseif spec.Corner then for _,field in radiusFields do capture(field)end else capture(spec.Field)end
  if spec.Side and(spec.Field=='Margin'or spec.Field=='Padding')then capture(spec.Field..'Values');if spec.Field=='Margin'then capture('MarginAuto')end end
  if spec.Field=='Gap'then capture(if spec.Side==1 then'RowGapSpecified'else'GridGapSpecified')end
 end end
 local authors=box.AnimationAuthorFields or {};box.AnimationAuthorFields=authors
 for field in fields do
  if not authors[field]then authors[field]={Value=box.Style[field]}end
  box.Style[field]=authors[field].Value
 end
 local used={}
 for property in changed do
  local spec=Values.Properties[property];if not spec or property=='font-size'or property=='line-height'or property=='text-shadow'then continue end;used[spec.Field]=true
  local value=properties[property];if type(value)=='table'and value.Auto and spec.Field~='Margin'and spec.Field~='FlexBasis'then value=nil end
  if spec.Corner then
   for _,field in radiusFields do used[field]=true end
   local radii=table.clone(box.Style.BorderRadii or{})
   for corner=1,4 do radii[corner]=radii[corner]or{X={Value=box.Style.BorderRadius or 0,Percent=false},Y={Value=box.Style.BorderRadius or 0,Percent=false}}end
   radii[cornerIndices[spec.Corner]]={X=radiusLength(value.X),Y=radiusLength(value.Y)};box.Style.BorderRadii=radii
  elseif spec.BorderSide then
   for _,field in borderFields do used[field]=true end
   local sides=table.clone(box.Style.BorderSides or{})
   for side=1,4 do sides[side]=table.clone(sides[side]or{Width=box.Style.BorderWidth or 0,Style=box.Style.BorderStyle or'none',Color=box.Style.BorderColor,Alpha=box.Style.BorderColorAlpha or 1})end
   sides[spec.BorderSide].Width=pixelWidth(if type(value)=='number'then value else Length.resolve(value,0))
   box.Style.BorderSides=sides
  elseif spec.Side then
   local nextValue=table.clone(box.Style[spec.Field]or{})
   if spec.Field=='Gap'then
    local flag=if spec.Side==1 then'RowGapSpecified'else'GridGapSpecified';used[flag]=true
    local normal=type(value)=='table'and value.Keyword=='normal';box.Style[flag]=not normal
    if normal then value=0 end
   end
   if spec.Field=='Margin'or spec.Field=='Padding'then
    local valuesField=spec.Field..'Values';used[valuesField]=true
    local source=table.clone(box.Style[valuesField]or{});source[spec.Side]=if type(value)=='table'and value.Auto then 0 else value;box.Style[valuesField]=source
    local basis=box.ContainingWidth or (box.Parent and box.Parent.ContentWidth)or box.ContentWidth or 0
    nextValue[spec.Side]=if type(source[spec.Side])=='table'then Length.resolve(source[spec.Side],basis)else source[spec.Side]
    if spec.Field=='Margin'then used.MarginAuto=true;local auto=table.clone(box.Style.MarginAuto or{});auto[spec.Side]=type(value)=='table'and value.Auto==true;box.Style.MarginAuto=auto end
   else nextValue[spec.Side]=value end
   box.Style[spec.Field]=nextValue
  elseif property=='box-shadow'then box.Style[spec.Field]=BoxShadow.resolve(value,{Color=box.Style.Color,Alpha=box.Style.ColorAlpha or 1})
  elseif property=='outline-width'then box.Style[spec.Field]=pixelWidth(if type(value)=='number'then value else Length.resolve(value,0))
  else box.Style[spec.Field]=value end
 end
 if used.BorderSides then
  local style=box.Style;local first=style.BorderSides[1];style.BorderSizes={};style.BorderUniform=true
  for side,edge in style.BorderSides do
   -- Width effects share their edge records with independently sampled colors.
   -- Restore geometry from the author basis without erasing that held paint.
   local tint=box.AnimationColorAuthor and previous.BorderSides and previous.BorderSides[side]
   if tint then edge.Color,edge.Alpha=tint.Color,tint.Alpha end
   style.BorderSizes[side]=if edge.Style=='none'or edge.Style=='hidden'then 0 else pixelWidth(edge.Width)
   if not equal(edge,first)then style.BorderUniform=false end
  end
 style.BorderSize,style.BorderWidth=style.BorderSizes[1],first.Width
 end
 if used.BorderRadii then
  local radii=box.Style.BorderRadii;local first=radii[1];local uniform=type(first.X.Value)=='number'and not first.X.Percent and not first.Y.Percent and first.X.Value==first.Y.Value
  for _,radius in radii do uniform=uniform and equal(radius,first)end
  box.Style.BorderRadius=if uniform then math.max(0,first.X.Value)else 0
  box.Style.NativeCornerRadii=CornerRadii.native(box.Style)
 end
 local differs,layoutDiffers,decorationDiffers=false,false,false
 for field in fields do
  if not equal(previous[field],box.Style[field])then
   differs=true
   local geometryChanged=true
   if field=='BorderSides'and previous[field]and box.Style[field]then
    geometryChanged=false
    for side=1,4 do local before,after=previous[field][side],box.Style[field][side]
     if not before or not after or before.Width~=after.Width or before.Style~=after.Style then geometryChanged=true;break end
    end
   end
   if not paintFields[field]and geometryChanged then layoutDiffers=true end
   if decorationFields[field]then decorationDiffers=true end
  end
  if not used[field]then authors[field]=nil end
 end
 if next(authors)==nil then box.AnimationAuthorFields=nil end
 if layoutDiffers and request then request(box)end
 local decorationUsed=false;for field in used do if decorationFields[field]then decorationUsed=true;break end end
 local geometry=box.AnimationDecorationGeometry
 if paint and(decorationDiffers or decorationUsed and(not geometry or geometry.Width~=box.OuterWidth or geometry.Height~=box.OuterHeight))then paint(box);box.AnimationDecorationGeometry={Width=box.OuterWidth,Height=box.OuterHeight}end
 if not decorationUsed then box.AnimationDecorationGeometry=nil end
 return differs
end
local function number(value)return (string.format('%.6f',value):gsub('0+$',''):gsub('%.$',''))end
function Values.serialize(value,property,box)
 if property=='box-shadow'or property=='text-shadow'then return BoxShadow.serialize(value,{Color=box.Style.Color,Alpha=box.Style.ColorAlpha or 1},property=='text-shadow')end
 if property=='transform-origin'then local z=Length.resolve(value.Z or {Value=0},0);return number(Length.resolve(value.X,box.OuterWidth or 0))..'px '..number(Length.resolve(value.Y,box.OuterHeight or 0))..'px'..(if z==0 then ''else ' '..number(z)..'px')end
 if property=='font-size'and type(value)=='number'then return number(math.max(0,value))..'px'end
 if property=='line-height'then
  if value.Kind=='normal'then return'normal'elseif value.Kind=='number'then return number(math.max(0,value.Value))end
  local px,em=lineLength(value);return number(math.max(0,(px or 0)+(em or 0)*(box and box.Style.FontSize or 16)))..'px'
 end
 if property and Values.Properties[property]and Values.Properties[property].Corner then
  local function component(value)local radius=radiusLength(value);return if type(radius)=='table'and radius.Percent and radius.Value==0 and not radius.Expression then '0%'else Values.serialize(radius)end
  local x,y=component(value.X),component(value.Y);return if x==y then x else x..' '..y
 end
 if value==nil then return 'auto'elseif type(value)=='number'then return number(if property=='outline-width'or Values.Properties[property]and Values.Properties[property].BorderSide then pixelWidth(value)else value)..(if numbers[property]then''else'px')elseif type(value)=='string'then return value end
 if value.Auto then return 'auto'elseif value.Keyword then return value.Keyword end
 if value.Expression and value.Expression.Op~='linear'then return Length.serialize(value)end
 local px,pct=linear(value,0);if not px then return 'auto'end
 if pct==0 then return number(px)..'px'elseif px==0 then return number(pct)..'%'end
 return 'calc('..number(pct)..'% '..(if px<0 then '- 'else '+ ')..number(math.abs(px))..'px)'
end
return Values
