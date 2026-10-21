--!strict
-- Existing layout algorithms operate on a connected, owned measurement graph.
-- Native surfaces and resource/callback owners never belong to that graph.
local Measurement={}
local omitted={DirtyContext=true,CachedLayout=true,LayoutMeasurements=true,LayoutParent=true,
 BackgroundRenderer=true,InsetRenderer=true,RadiusRenderer=true,CornerRenderer=true,VisualEffects=true,
 TranslateLayout=true,RepaintStyles=true,RepaintDecorationColors=true,RepaintDecorations=true,
 MeasureGrid=true,ArrangeGrid=true,InlineMeasurement=true,LayoutInProgress=true,
 FlowPaintState=true,PaintState=true,DisplayItems=true,PendingTextLayout=true,
 RequestDimensions=true,UpdateSVG=true,UpdateBlur=true,RefreshResources=true,
 StructuralResourcesRemoving=true,RefreshDOMResources=true,Scene3DRoot=true,Scene3DSurface=true,ShapeImageProvider=true,
 MotionRuntime=true,JavaScriptRuntime=true,CanvasRuntime=true,IFrameRuntime=true,
 NativeImageResources=true,NativeMediaResources=true,ResourceLoadHost=true,ImageMapIndex=true}
local registries={HitNodes=true,HitStyles=true,TextItemsByGui=true,NodeBoxes=true,NodeStyles=true}
local nodeKinds={Document=true,Element=true,Text=true,Comment=true,Doctype=true,DocumentType=true,CDATASection=true,ProcessingInstruction=true,ShadowRoot=true,DocumentFragment=true}
local measuredFunctions={FontResolver=true,ResolveFont=true,ShapeImageMeasurement=true,Measure=true,Arrange=true}
local guiFields={'ClassName','Name','Position','Size','Visible','ZIndex','CanvasPosition','CanvasSize','AbsolutePosition','AbsoluteSize','AbsoluteWindowSize',
 'ClipsDescendants','ScrollingEnabled','ScrollBarThickness','BackgroundTransparency','TextTransparency','ImageTransparency'}
local function nativeSurface(value: any): boolean
 if typeof(value)=='Instance'then return true end
 return type(value)=='table'and value.ClassName~=nil and(type(value.IsA)=='function'or type(value.Destroy)=='function')
end
local function fontValue(value: any): boolean
 -- Font is an immutable native value. The headless host represents the same
 -- value with Family/Weight/Style records; native bounds key its identity.
 return typeof(value)=='Font'or type(value)=='table'and value.Family~=nil and value.Weight~=nil and value.Style~=nil
end
function Measurement.new(root: any,alive: ()->boolean): any
 local context={Originals={},Copies={},Items={},Markers={},Root=nil,Aborted=false}
 local visits=0
 local copy
 local function record(class: string,parent: any,properties: any): any
  local gui=table.clone(properties or{});gui.ClassName,gui.Parent=class,parent
  function gui:Destroy()self.Parent=nil end
  function gui:IsA(kind)return kind==class or kind=='GuiObject'end
  return gui
 end
 local factory={create=record,modifier=record}
 copy=function(value: any,key: any?): any
  if type(value)~='table'and not nativeSurface(value)then return value end
  if fontValue(value)then return value end
  if type(value)=='table'and nodeKinds[value.Kind]then return value end
  if context.Copies[value]then return context.Copies[value]end
  visits+=1
  if context.Aborted or visits%16==0 and not alive()then context.Aborted=true;return nil end
  local out={};context.Copies[value]=out;context.Originals[out]=value
  if nativeSurface(value)then
   -- Plain value records absorb incidental positioning in Flex/Grid/Table.
   -- They cannot forward a write, method, connection or allocation to an Instance.
   for _,field in guiFields do local ok,v=pcall(function()return value[field]end);if ok then out[field]=v end end
   function out:Destroy()self.Parent=nil end
   function out:IsA(kind)return kind==self.ClassName or kind=='GuiObject'end
   return out
  end
  for field,entry in value do
   if omitted[field]then continue end
   if registries[field]then out[field]={}
   elseif field=='Factory'or field=='ImageFactory'then out[field]=factory
   elseif field=='Node'or field=='HitNode'or field=='SourceNode'or field=='IFrame'or field=='MediaRuntime'or field=='Sound'
    or field=='AudioSession'or field=='VideoSelection'or field=='ChildPage'or field=='ImageResourceState'then out[field]=entry
   elseif type(entry)=='function'then
    -- Preserve only callbacks explicitly used by the geometry algorithms.
    -- Font resolution/cache reads are pure; custom markers use MeasureOnly.
    -- Text/resource/paint callbacks can capture live registries and Instances.
    if measuredFunctions[field]then out[field]=entry end
   else out[field]=copy(entry,field)end
  end
  if value.Kind=='Block'or value.Kind=='BlockImage'or value.Kind=='Words'then
   out.GeometryOnly=true
   if value.Kind=='Words'then out.MeasureOnly=true;out.PaintState=nil;out.FlowPaintState=nil;out.DisplayItems=nil end
  end
  if value.Kind=="Words"and value.Items and out.Items then for i,item in value.Items do table.insert(context.Items,{Original=item,Probe=out.Items[i]})end end
  if value.Kind=="BlockImage"and value.ImageItem then table.insert(context.Items,{Original=value.ImageItem,Probe=out.ImageItem})end
  if(value.Kind=="Block"or value.Kind=="BlockImage"or value.Kind=="Marker")and value.Marker and out.Marker then out.Marker.MeasureOnly=true;table.insert(context.Markers,{Original=value.Marker,Probe=out.Marker})end
  if value.ShapeImageMeasurement then out.ShapeImageProvider=value.ShapeImageMeasurement end
  return out
 end
 context.Root=copy(root)
 local links=0
 for probe,original in context.Originals do
  links+=1;if links%16==0 and not alive()then context.Aborted=true;break end
  -- Copies includes inert GUI records as well as layout boxes. Instances do
  -- not expose our synthetic parent field; only geometry records own it.
  if not nativeSurface(original) and original.LayoutParent then probe.LayoutParent=context.Copies[original.LayoutParent]or original.LayoutParent end
 end
 function context:KeepMeasurements()
  if self.Aborted or not alive()then return end
  local work=0
  local function checkpoint(): boolean work+=1;return work%32~=0 or alive()end
  for _,pair in self.Items do
   if not checkpoint()then return end
   local original,probe=pair.Original,pair.Probe
   if not probe then continue end
   local glyphsReady=true
   for _,glyph in probe.Glyphs or{}do
    if not checkpoint()then return end
    if glyph.Width==nil or glyph.Height==nil then glyphsReady=false;break end
   end
   local cached=probe.NativeGlyphBounds
   local cacheReady=cached~=nil and cached.Text==probe.Text and cached.Font==probe.FontFace and cached.Size==probe.TextSize
    and cached.Tabular==probe.Style.TabularNums
    and cached.Family==probe.MeasuredFont and cached.Weight==probe.MeasuredWeight and cached.Variant==probe.MeasuredStyle and cached.Bidi==probe.MeasuredBidiText
   if cacheReady then for i in probe.Glyphs or{}do
    if not checkpoint()then return end
    local bounds=cached.Bounds[i];if not bounds or bounds.Width==nil or bounds.Height==nil then cacheReady=false;break end
   end end
   -- Retained glyphs can still display the previous font after an earlier pure
   -- probe completed new bounds. Even non-nil painted widths then belong to a
   -- different font. Prefer the matching completed cache for unvisited items.
   if not glyphsReady and not cacheReady then continue end
   local completedGlyphs
   if original.Glyphs and probe.Glyphs and glyphsReady and not cacheReady then
    local bounds={};for i,glyph in probe.Glyphs do
     if not checkpoint()then return end
     bounds[i]={Width=glyph.Width,Height=glyph.Height}
    end
    completedGlyphs={Text=probe.Text,Font=self.Originals[probe.FontFace]or probe.FontFace,Size=probe.TextSize,Tabular=probe.Style.TabularNums,Bounds=bounds,
     Family=probe.MeasuredFont,Weight=probe.MeasuredWeight,Variant=probe.MeasuredStyle,Bidi=probe.MeasuredBidiText}
   end
   local measuredAgain=original.MeasuredText~=probe.MeasuredText or original.MeasuredSize~=probe.MeasuredSize
    or original.MeasuredFont~=probe.MeasuredFont or original.MeasuredWeight~=probe.MeasuredWeight or original.MeasuredStyle~=probe.MeasuredStyle
    or original.MeasuredTabular~=probe.MeasuredTabular
   for field,v in probe do
    if type(field)=='string'and(field:match('^Measured')or field:match('^Native')or field:match('^TabBase')
      or field=='TabMinimum'or field=='WrapCache'or field=='HyphenPoints'or field=='HyphenAtEnd'
      or field=='FontFace'or field=='TextSize'or field=='ControlMeasureKey'or field=='IntrinsicWidth'or field=='IntrinsicHeight'
      or field=='InputLineBaseline'or field=='FileButtonWidth'or field=='SelectCaptionKey'or field=='SelectCaptionRows'
      or field=='AltWidth'or field=='AltHeight'or field=='AltInkHeight'or field=='AltSize'or field=='AltMeasuredText'or field=='AltMeasuredFace')then
     original[field]=if field=='SelectCaptionRows'or field=='FontFace'then self.Originals[v]or v else v
    end
   end
   if measuredAgain then original.SkipInkCuts=nil end
   if probe.EmphasisMeasure then
    local cache=table.clone(probe.EmphasisMeasure);cache.Font=self.Originals[cache.Font]or cache.Font
    original.EmphasisMeasure=cache
   end
   if completedGlyphs then original.NativeGlyphBounds=completedGlyphs end
  end
  for _,pair in self.Markers do
   if not checkpoint()then return end
   local marker=pair.Probe
   if marker.Text~=nil and marker.Width~=nil and marker.Height~=nil then
    pair.Original.NativeMarkerBounds={Text=marker.Text,Font=self.Originals[marker.Font]or marker.Font,Size=marker.Size,Weight=marker.Weight,Variant=marker.Variant,Width=marker.Width,Height=marker.Height}
   end
  end
 end
 return context
end
return Measurement
