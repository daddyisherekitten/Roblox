--!strict
local Matrix=require(script.Parent.Matrix)
local Geometry=require(script.Parent.Geometry)
local Curves=require(script.Parent.Curves)
local PathMetrics=require(script.Parent.PathMetrics)
local Queries={}
-- Scene geometry is immutable. Weak keys release metrics with old scenes;
-- repeated script queries reuse flattening and accumulated segment lengths.
local metrics=setmetatable({},{__mode='k'})
local function measure(scene: any,node: any): any
 local entry=assert(scene.Nodes[node],'Element has no rendered geometry');local g=assert(entry.Geometry,'Expected a shape')
 local cached=metrics[g];if cached then return cached end
 local parts=if g.Subpaths then Curves.flatten(g.Subpaths,64) else {{Points=Geometry.contour(g,64),Closed=g.Closed}}
 local result={Parts=parts,Segments={},Length=0,Last={0,0}}
 for _,part in parts do
  local points=part.Points
  if #points>0 then result.Last=points[1] end
  for i=1,#points-(if part.Closed then 0 else 1) do
   local a,b=points[i],points[i%#points+1];local length=PathMetrics.distance(a,b)
   if length>0 then
    table.insert(result.Segments,{A=a,B=b,Start=result.Length,Finish=result.Length+length})
    result.Length+=length
   end
   result.Last=b
  end
 end
 metrics[g]=result;return result
end
function Queries.box(scene: any,node: any): any
 local entry=assert(scene.Nodes[node],'Element has no rendered geometry')
 return table.clone(entry.Box)
end
function Queries.matrix(scene: any,node: any,screen: any?): any
 local entry=assert(scene.Nodes[node],'Element has no rendered coordinate system')
 return if screen then Matrix.multiply(screen,entry.Transform) else table.clone(entry.Transform)
end
function Queries.path(scene: any,node: any): any
 local parts={}
 for _,part in measure(scene,node).Parts do
  local points={};for _,p in part.Points do table.insert(points,table.clone(p)) end
  table.insert(parts,{Points=points,Closed=part.Closed})
 end
 return parts
end
function Queries.length(scene: any,node: any): number return measure(scene,node).Length end
function Queries.point(scene: any,node: any,distance: number): any
 assert(distance==distance,'Finite path distance required')
 local data=measure(scene,node);local at=math.clamp(distance,0,data.Length)
 local low,high=1,#data.Segments
 while low<high do local mid=math.floor((low+high)/2);if data.Segments[mid].Finish<at then low=mid+1 else high=mid end end
 local segment=data.Segments[low]
 if not segment then return {X=data.Last[1],Y=data.Last[2]} end
 local a,b=segment.A,segment.B;local f=(at-segment.Start)/(segment.Finish-segment.Start)
 return {X=a[1]+(b[1]-a[1])*f,Y=a[2]+(b[2]-a[2])*f}
end
return Queries
