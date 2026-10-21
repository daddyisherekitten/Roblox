--!strict
-- Author vertices and analytic endpoint tangents, independent of raster flattening.
local Arc=require(script.Parent.Arc)
local MarkerPositions={}
local function vector(a: any,b: any): any? local x,y=b[1]-a[1],b[2]-a[2];return if x==0 and y==0 then nil else {x,y} end
local function tangent(a: any,b: any,c: any,start: boolean): any?
 if not c then return vector(a,b) end
 if c.Kind=='C' then
  return if start then vector(a,c.Control1) or vector(a,c.Control2) or vector(a,b) else vector(c.Control2,b) or vector(c.Control1,b) or vector(a,b)
 elseif c.Kind=='Q' then return if start then vector(a,c.Control1) or vector(a,b) else vector(c.Control1,b) or vector(a,b)
 elseif c.Kind=='A' then
  local arc=Arc.resolve(a,b,c)
  if arc.Mode~='arc' then return vector(a,b) end
  local angle=arc.Start+(if start then 0 else arc.Delta);local sign=if arc.Delta<0 then -1 else 1
  local x,y=-arc.RX*math.sin(angle)*sign,arc.RY*math.cos(angle)*sign
  return {arc.Cos*x-arc.Sin*y,arc.Sin*x+arc.Cos*y}
 end
 return vector(a,b)
end
local function parts(g: any): any
 if g.Subpaths then return g.Subpaths end
 if g.Points then return {{Points=g.Points,Curves={},Closed=g.Closed}} end
 if g.Empty then return {} end
 if g.Kind=='circle' or g.Kind=='ellipse' then
  local x,y,rx,ry=g.CX,g.CY,g.RX,g.RY
  local curves={};for i=2,5 do curves[i]={Kind='A',RX=rx,RY=ry,Rotation=0,Large=0,Sweep=1} end
  return {{Points={{x+rx,y},{x,y+ry},{x-rx,y},{x,y-ry},{x+rx,y}},Curves=curves,Closed=true}}
 end
 if g.Kind=='rect' then
  local x,y,w,h,rx,ry=g.X,g.Y,g.Width,g.Height,g.RX,g.RY
  if rx==0 or ry==0 then return {{Points={{x,y},{x+w,y},{x+w,y+h},{x,y+h}},Curves={},Closed=true}} end
  local curves={};for _,i in {3,5,7,9} do curves[i]={Kind='A',RX=rx,RY=ry,Rotation=0,Large=0,Sweep=1} end
  return {{Points={{x+rx,y},{x+w-rx,y},{x+w,y+ry},{x+w,y+h-ry},{x+w-rx,y+h},{x+rx,y+h},{x,y+h-ry},{x,y+ry},{x+rx,y}},Curves=curves,Closed=true}}
 end
 return {}
end
function MarkerPositions.build(g: any): any
 local result={}
 for _,part in parts(g) do
  if #part.Points==0 then continue end
  local points=table.clone(part.Points);local curves=part.Curves or {}
  local implicit=part.Closed and not (g.Kind=='circle' or g.Kind=='ellipse' or (g.Kind=='rect' and g.RX>0 and g.RY>0))
  if implicit then table.insert(points,points[1]) end
  local starts,ends={},{}
  for i=2,#points do starts[i-1]=tangent(points[i-1],points[i],curves[i],true) or false;ends[i-1]=tangent(points[i-1],points[i],curves[i],false) or false end
  local segments=#points-1
  -- Resolve runs of zero-length segments once, avoiding quadratic scans.
  local forward,backward={},{};local nextVector,previousVector
  for i=segments,1,-1 do nextVector=starts[i] or nextVector;forward[i]=nextVector end
  for i=1,segments do previousVector=ends[i] or previousVector;backward[i]=previousVector end
  local function direction(index: number,ahead: boolean): any?
   if ahead then return forward[index] or (if part.Closed then nextVector else nil) end
   return backward[index] or (if part.Closed then previousVector else nil)
  end
  for i,p in points do
   local incoming=direction(i-1,false);local outgoing=direction(i,true)
   local v=incoming or outgoing;local angle=if v then math.atan2(v[2],v[1]) else 0
   if incoming and outgoing then
    local second=math.atan2(outgoing[2],outgoing[1]);local delta=(second-angle+math.pi)%(2*math.pi)-math.pi
    if math.abs(delta+math.pi)<1e-12 then delta=math.pi end
    angle+=delta/2
   end
   table.insert(result,{X=p[1],Y=p[2],Angle=angle,Kind='mid'})
  end
 end
 if #result>0 then result[1].Kind='start';result[#result].Kind='end' end
 if #result==1 then local first=table.clone(result[1]);first.Kind='start';table.insert(result,1,first) end
 return result
end
return MarkerPositions
