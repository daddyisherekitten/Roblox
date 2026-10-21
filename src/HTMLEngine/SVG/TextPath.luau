--!strict
-- Arc-length lookup shared by all glyphs on one textPath. Moveto gaps add no length.
local Geometry=require(script.Parent.Geometry)
local Curves=require(script.Parent.Curves)
local Length=require(script.Parent.Length)
local Matrix=require(script.Parent.Matrix)
local Transform=require(script.Parent.Transform)
local TextPath={}
function TextPath.resolve(doc: any,node: any,context: any,report: any): any?
 local a=node.Attributes;local target,scope
 if a.path then target={Name='path',Attributes={d=a.path}}
 else
  local href=a.href or (node.Source and node.Source.ExpandedAttributes and node.Source.ExpandedAttributes['http://www.w3.org/1999/xlink\0href'])
  if not href or not doc then report('missing-text-path',href);return nil end
  target,scope=doc.Resource(href,node)
  if not target then report('missing-text-path',href);return nil end
 end
 if not Geometry.Supported[target.Name] then report('invalid-text-path-target',target.Name);return nil end
 local attributes=if scope then doc.Compute(target,scope,context).Attributes else target.Attributes
 local geometry,issues=Geometry.build(target.Name,attributes,context)
 for _,issue in issues do report(issue.Code,issue.Attribute) end
 if not geometry then return nil end
 local parts=if geometry.Subpaths then Curves.flatten(geometry.Subpaths,16) else {{Points=Geometry.contour(geometry,16),Closed=geometry.Closed}}
 local points={};for _,part in parts do for _,p in part.Points do table.insert(points,p) end end
 local declarations=Transform.declarations(attributes)
 local box=if declarations.Box=='fill-box' or declarations.Box=='stroke-box' then Matrix.bounds(points) else {X=0,Y=0,Width=context.Width,Height=context.Height}
 local mapping,problems=Transform.resolve(declarations,box,context)
 for _,problem in problems do report(problem,'textPath') end
 local path={Segments={},Length=0,Closed=#parts==1 and parts[1].Closed,Right=a.side=='right'}
 local function edge(p: any,q: any)
  local x,y=Matrix.point(mapping,p[1],p[2]);local xx,yy=Matrix.point(mapping,q[1],q[2])
  local dx,dy=xx-x,yy-y;local length=math.sqrt(dx*dx+dy*dy)
  if length<=1e-12 then return end
  table.insert(path.Segments,{X=x,Y=y,DX=dx/length,DY=dy/length,Start=path.Length,Length=length})
  path.Length+=length
 end
 for _,part in parts do
  for i=2,#part.Points do edge(part.Points[i-1],part.Points[i]) end
  if part.Closed and #part.Points>1 then edge(part.Points[#part.Points],part.Points[1]) end
 end
 if path.Length==0 then report('empty-text-path',a.href);return nil end
 if a.method and a.method~='align' then report('text-path-method-unimplemented',a.method);return nil end
 if a.spacing and a.spacing~='exact' and a.spacing~='auto' then report('invalid-text-path-spacing',a.spacing);return nil end
 if a.side and a.side~='left' and a.side~='right' then report('invalid-text-path-side',a.side);return nil end
 local offsetContext=table.clone(context);offsetContext.Width=path.Length
 local offset=Length.resolve(a.startOffset or '0',offsetContext,'x',false)
 if not offset then report('invalid-text-path-offset',a.startOffset);return nil end
 path.Calibration=if geometry.PathLength and geometry.PathLength>0 then path.Length/geometry.PathLength else 1
 if geometry.PathLength==0 then report('zero-text-path-length','pathLength');return nil end
 local parsed=Length.parse(a.startOffset or '0')
 path.Offset=offset*(if parsed and parsed.Unit=='%' then 1 else path.Calibration)
 if path.Calibration~=path.Calibration or path.Calibration>1e9 or math.abs(path.Offset)>1e9 then report('text-path-distance-limit','startOffset/pathLength');return nil end
 return path
end
function TextPath.point(path: any,distance: number,extend: boolean?): (number?,number?,number?,number?)
 if path.Closed then distance=distance%path.Length
 elseif not extend and (distance<0 or distance>path.Length) then return nil,nil,nil,nil end
 if path.Right then distance=path.Length-distance end
 local segments=path.Segments;local low,high=1,#segments
 while low<high do local middle=math.floor((low+high)/2);local s=segments[middle];if distance>s.Start+s.Length then low=middle+1 else high=middle end end
 local s=segments[low];local step=distance-s.Start
 local sign=if path.Right then -1 else 1
 return s.X+s.DX*step,s.Y+s.DY*step,s.DX*sign,s.DY*sign
end
function TextPath.place(path: any,glyph: any): any?
 local half=glyph.Glyph.Advance*glyph.Scale*glyph.Stretch/2
 local distance=path.Offset+(glyph.X+half)*path.Calibration
 if path.Closed then
  local anchor=glyph.Chunk.Anchor
  local low=if anchor=='middle' then path.Offset-path.Length/2 elseif anchor=='end' then path.Offset-path.Length else path.Offset
  if distance<low or distance>low+path.Length then return nil end
 end
 local x,y,dx,dy=TextPath.point(path,distance)
 if not x then return nil end
 -- Use the tangent at the glyph midpoint; bearings/rotation remain glyph-local.
 local normal=glyph.Y+glyph.Shift
 return {X=x-dx*half-dy*normal,Y=y-dy*half+dx*normal,Angle=math.atan2(dy,dx)}
end
return TextPath
