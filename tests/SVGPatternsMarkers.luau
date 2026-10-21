--!strict
return function(Resources: any,Pattern: any,Positions: any,Document: any,Parser: any,Viewport: any,Viewports: any,Raster: any,Length: any,Geometry: any,Paint: any,Transform: any,Bounds: any,Rendering: any,Gradient: any,Sources: any,Matrix: any): any
 local ctx={Width=480,Height=320,FontSize=16,RootFontSize=16}
 local function near(a: number,b: number,e: number?) assert(math.abs(a-b)<(e or .001),'expected '..b..', got '..a) end
 local function points(d: string): any return Positions.build(Geometry.build('path',{d=d},ctx)) end
 local p=points('M0 0L10 0L10 10');assert(#p==3 and p[1].Kind=='start' and p[2].Kind=='mid' and p[3].Kind=='end');near(p[2].Angle,math.pi/4)
 p=points('M0 0C0 10 20 20 20 0');assert(#p==2);near(p[1].Angle,math.pi/2);near(p[2].Angle,-math.pi/2)
 p=points('M0 0C0 0 0 0 10 0');near(p[1].Angle,0)
 p=points('M0 0Q10 20 20 0');near(p[1].Angle,math.atan2(20,10));near(p[2].Angle,math.atan2(-20,10))
 p=points('M0 0A10 10 0 0 1 20 0');near(p[1].Angle,-math.pi/2);near(p[2].Angle,math.pi/2)
 p=points('M0 0L0 0L10 0');near(p[1].Angle,0);near(p[2].Angle,0)
 p=points('M0 0L10 0Z M20 0L30 0Z');assert(#p==6);assert(p[3].Kind=='mid' and p[4].Kind=='mid' and p[6].Kind=='end')
 p=Positions.build(Geometry.build('circle',{cx='10',cy='10',r='5'},ctx));assert(#p==5);near(p[1].X,15);near(p[1].Angle,math.pi/2)
 p=points('M1 1');assert(#p==2);near(p[1].Angle,0)
 local function build(body: string,documents: any?): any
  return Viewports(Parser,Viewport,{Stage='S19_S20',Documents=documents,Cases={{Name='unit',SVG='<svg xmlns="http://www.w3.org/2000/svg" width="480" height="320">'..body..'</svg>'}}},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources)
 end
 local function pixel(bytes: buffer,width: number,x: number,y: number): any
  local at=(y*width+x)*4;return {buffer.readu8(bytes,at),buffer.readu8(bytes,at+1),buffer.readu8(bytes,at+2),buffer.readu8(bytes,at+3)}
 end
 local tile='<pattern id="p" patternUnits="userSpaceOnUse" x="5" y="7" width="20" height="20"><rect width="10" height="20" fill="red"/></pattern>'
 local data=build('<defs>'..tile..'</defs><rect width="100" height="100" fill="url(#p)"/>')
 assert(#data.Diagnostics==0)
 local bytes=Raster.render(data.Scenes[1],nil,480,function() return true end)
 assert(pixel(bytes,480,7,12)[1]==255 and pixel(bytes,480,7,12)[4]==255)
 assert(pixel(bytes,480,17,12)[4]==0)
 assert(pixel(bytes,480,2,2)[4]==0 and pixel(bytes,480,7,2)[4]==255)
 for _,x in {7,27,47,67,87} do assert(pixel(bytes,480,x,12)[4]==255) end
 -- A second render is fresh and must not reuse a raster tile at an obsolete density.
 local high=Raster.render(data.Scenes[1],nil,960,function() return true end);assert(pixel(high,960,14,24)[4]==255)
 data=build('<defs><pattern id="p" width=".5" height=".5" patternContentUnits="objectBoundingBox"><rect width=".25" height=".5" fill="blue"/></pattern></defs><rect x="10" y="10" width="100" height="80" fill="url(#p)"/><rect x="130" y="10" width="200" height="80" fill="url(#p)"/>')
 bytes=Raster.render(data.Scenes[1],nil,480,function() return true end)
 assert(pixel(bytes,480,20,20)[3]==255 and pixel(bytes,480,45,20)[4]==0 and pixel(bytes,480,170,20)[3]==255 and pixel(bytes,480,190,20)[4]==0)
 data=build('<defs><pattern id="p" patternUnits="userSpaceOnUse" width="20" height="20" viewBox="0 0 10 10"><rect width="5" height="10" fill="green"/></pattern></defs><rect width="100" height="100" fill="url(#p)"/>')
 bytes=Raster.render(data.Scenes[1],nil,480,function() return true end);assert(pixel(bytes,480,5,5)[2]==128 and pixel(bytes,480,15,5)[4]==0)
 data=build('<defs><pattern id="p" href="#q"/><pattern id="q" href="#p"/></defs><rect width="100" height="100" fill="url(#p) red"/>')
 assert(data.Diagnostics[1].Code=='cyclic-pattern-reference');assert(data.Scenes[1].Shapes[1].Fill[1]==255)
 data=build('<defs><pattern id="p" patternUnits="userSpaceOnUse" width="20" height="20"><rect width="20" height="20" fill="url(#p) red"/></pattern></defs><rect width="100" height="100" fill="url(#p)"/>')
 assert(data.Diagnostics[1].Code=='cyclic-pattern-content');bytes=Raster.render(data.Scenes[1],nil,480,function() return true end);assert(pixel(bytes,480,5,5)[1]==255)
 data=build('<defs><pattern id="p" width="0" height="1"><rect width="10" height="10"/></pattern></defs><rect width="100" height="100" fill="url(#p)"/>');assert(data.Scenes[1].Shapes[1].Fill==nil)
 local marker='<marker id="m" markerUnits="userSpaceOnUse" markerWidth="20" markerHeight="20" viewBox="0 0 10 10" refX="10" refY="5" orient="auto"><path d="M0 0L10 5L0 10Z" fill="context-stroke"/></marker>'
 data=build('<defs>'..marker..'</defs><path d="M20 50H100" stroke="blue" stroke-width="4" stroke-opacity="0" marker-end="url(#m)"/>')
 assert(#data.Diagnostics==0)
 bytes=Raster.render(data.Scenes[1],nil,480,function() return true end)
 assert(pixel(bytes,480,89,50)[3]==255 and pixel(bytes,480,89,50)[4]==255);assert(pixel(bytes,480,50,50)[4]==0)
 -- Ref point is the tip, independently of viewport scaling.
 local markerShape=data.Scenes[1].Shapes[1].Markers[1].Children[1]
 local x,y=Matrix.point(markerShape.Transform,10,5);near(x,100);near(y,50)
 data=build('<defs>'..marker..'</defs><path d="M20 50H100" stroke="blue" stroke-width="4" opacity=".5" marker-end="url(#m)"/>')
 bytes=Raster.render(data.Scenes[1],nil,480,function() return true end);near(pixel(bytes,480,89,50)[4],128,1)
 -- Markers obey paint-order; painting the stroke last covers the marker center.
 local over='<marker id="m" markerUnits="userSpaceOnUse" markerWidth="20" markerHeight="20" refX="10" refY="10"><rect width="20" height="20" fill="red"/></marker>'
 data=build('<defs>'..over..'</defs><path d="M20 50H100" stroke="blue" stroke-width="6" marker-end="url(#m)" paint-order="markers stroke fill"/>')
 bytes=Raster.render(data.Scenes[1],nil,480,function() return true end);assert(pixel(bytes,480,95,50)[3]==255)
 data=build('<defs><marker id="m" markerWidth="20" markerHeight="20"><path d="M0 0H5" marker-end="url(#m)"/></marker></defs><path d="M0 50H100" marker-end="url(#m)"/>')
 assert(data.Diagnostics[1].Code=='cyclic-marker-content')
 data=build('<path d="M0 0H100" marker-end="url(#missing)"/>');assert(data.Diagnostics[1].Code=='invalid-marker-reference')
 data=build('<defs><pattern id="p" href="library.svg#base"/></defs><rect width="100" height="100" fill="url(#p)"/>',{['library.svg']='<svg xmlns="http://www.w3.org/2000/svg"><pattern id="base" patternUnits="userSpaceOnUse" width="20" height="20"><rect width="10" height="20" fill="green"/></pattern></svg>'})
 assert(#data.Diagnostics==0);bytes=Raster.render(data.Scenes[1],nil,480,function() return true end);assert(pixel(bytes,480,5,5)[2]==128)
 data=build('<defs>'..marker:gsub('orient="auto"','orient="auto-start-reverse"')..'</defs><path d="M20 50H100" stroke="blue" marker-start="url(#m)" marker-end="url(#m)"/>')
 local markers=data.Scenes[1].Shapes[1].Markers
 local startShape=markers[1].Children[1];local endShape=markers[2].Children[1]
 local sx,sy=Matrix.point(startShape.Transform,0,5);local ex,ey=Matrix.point(endShape.Transform,0,5)
 near(sx,40);near(sy,50);near(ex,80);near(ey,50)
 data=build('<rect width="100" height="100" fill="context-stroke"/>');assert(data.Scenes[1].Shapes[1].Fill==nil)
 local emptyContext=Paint.used(Paint.resolve({fill='context-stroke'},nil,ctx),ctx)
 local manual={Width=480,Height=320,Shapes={{Geometry=Geometry.build('rect',{width='100',height='100'},ctx),Fill=emptyContext,Transform=Matrix.identity(),StrokeWidth=0}}}
 bytes=Raster.render(manual,nil,480,function() return true end);assert(pixel(bytes,480,5,5)[4]==0)
 data=build('<defs>'..marker:gsub('markerUnits="userSpaceOnUse"','markerUnits="strokeWidth"')..'</defs><path d="M20 50H100" stroke="blue" vector-effect="non-scaling-stroke" marker-end="url(#m)"/>')
 assert(data.Diagnostics[1].Code=='non-scaling-marker-units-approximation')
 -- Regression: referenced pattern content keeps its original CSS inheritance,
 -- including across template chains; own replacement content uses its own parent.
 local base='<pattern id="base" patternUnits="userSpaceOnUse" width="20" height="20" style="--tile:red"><rect width="20" height="20" style="fill:var(--tile)"/></pattern>'
 for _,reference in {
  '<pattern id="p" href="#base" style="--tile:green"/>',
  '<pattern id="p" href="#middle" style="--tile:green"/><pattern id="middle" href="#base" style="--tile:blue"/>'
 } do
  data=build('<defs>'..base..reference..'</defs><rect width="100" height="100" fill="url(#p)" fill-opacity=".6"/>')
  assert(#data.Diagnostics==0)
  bytes=Raster.render(data.Scenes[1],nil,480,function() return true end)
  local c=pixel(bytes,480,5,5);assert(c[1]==255 and c[2]==0 and c[3]==0 and c[4]==153)
 end
 data=build('<defs>'..base..'<pattern id="p" href="#base" style="--tile:green"><rect width="20" height="20" style="fill:var(--tile)"/></pattern></defs><rect width="100" height="100" fill="url(#p)"/>')
 bytes=Raster.render(data.Scenes[1],nil,480,function() return true end);assert(pixel(bytes,480,5,5)[2]==128)
 local all=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources)
 for _,problem in all.Diagnostics do print(problem.Case,problem.Code,problem.Value) end
 assert(#all.Diagnostics==0,'Unexpected S19/S20 fixture diagnostics')
 for _,width in {240,480,960} do
  for index,scene in all.Scenes do
   local b,h=Raster.render(scene,nil,width,function() return true end);assert(b and h==math.round(width*2/3))
   if index==3 then
    local c=pixel(b,width,math.floor(280*width/480),math.floor(210*width/480))
    assert(c[1]==239 and c[2]==68 and c[3]==68 and c[4]==153,'Referenced fixture pattern must remain red at 60% opacity')
   end
  end
 end
 local n=0;local cancelled=Raster.render(all.Scenes[1],nil,480,function() n+=1;return n<30 end);assert(cancelled==nil)
 print('SVG S19/S20: tile phase/units/viewBox, templates and cycles, tangents, author vertices, marker refs/context/opacity/order, three raster sizes and cancellation passed')
 return all
end
