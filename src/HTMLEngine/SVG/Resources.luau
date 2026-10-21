--!strict
local Gradient=require(script.Parent.Gradient)
local Pattern=require(script.Parent.Pattern)
local Marker=require(script.Parent.Marker)
local Image=require(script.Parent.Image)
local ClipPath=require(script.Parent.ClipPath)
local Mask=require(script.Parent.Mask)
local Filter=require(script.Parent.Filter)
local Resources={}
function Resources.new(doc: any,render: any,report: any): any
 local active={};local depth,count,diagnostics=0,0,0
 local emit=report
 report=function(code: string,value: any) if diagnostics<100 then diagnostics+=1;emit(code,value) end end
 local function enter(): boolean
  count+=1
  if depth>=12 or count>4096 then report('resource-expansion-limit','SVG resource');return false end
  depth+=1;return true
 end
 local function content(...)
  if not enter() then return {RenderTree={},Shapes={}} end
  local scene=render(...)
  depth-=1;return scene
 end
 local function contextual(value: any,context: any): any
  if not value or not value.Context then return value end
  local source=context and (if value.Context=='context-fill' then context.Fill else context.Stroke)
  if not source then return nil end
  local copy=table.clone(source)
  if copy.Sample or copy.Prepare then
   copy.Opacity=(copy.Opacity or 1)*value.Opacity
   if copy.Average then copy.Average=table.clone(copy.Average);copy.Average[4]*=value.Opacity end
  else copy[4]=(copy[4] or 1)*value.Opacity end
  return copy
 end
 return {
  ImageBox=function(node: any,context: any): any
   local measured=Image.measure(doc,node,context,function() end)
   return if measured then measured.Box else {X=0,Y=0,Width=0,Height=0}
  end,
  Image=function(node: any,context: any,state: any): any return Image.build(doc,node,context,state,content,report,active) end,
  Filter=function(node: any,box: any,context: any,t: any,clip: any?): any return Filter.build(doc,node,box,context,t,report,clip) end,
  Mask=function(node: any,box: any,context: any,t: any): any return Mask.build(doc,node,box,context,t,content,report,active) end,
  Clip=function(node: any,box: any,context: any,t: any): any return ClipPath.build(doc,node,box,context,t,content,report,active) end,
  Bind=function(node: any,value: any,box: any,context: any,t: any,contextPaint: any): any
   value=contextual(value,contextPaint)
   if not value or not value.URL then return value end
   local target=doc.Resource(value.URL,node)
   if target and target.Name=='pattern' then return Pattern.bind(doc,node,value,box,context,t,content,report,active) end
   return Gradient.bind(doc,node,value,box,context,t,report)
  end,
  Markers=function(node: any,shape: any,context: any): any return Marker.build(doc,node,shape,context,content,report,active) end,
 }
end
return Resources
