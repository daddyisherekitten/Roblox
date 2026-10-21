--!strict
return function(Blend,Mask,Compositing,Resources,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Gradient,Sources,SVGStyle)
 local function dataFor(body: string,documents: any?): any
  return Viewports(Parser,Viewport,{Cases={{Name='test',SVG='<svg xmlns="http://www.w3.org/2000/svg" width="480" height="320">'..body..'</svg>'}},Documents=documents},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources)
 end
 local function expect(b: buffer,x: number,y: number,values: any)
  local at=(y*480+x)*4
  for i,value in values do local got=buffer.readu8(b,at+i-1);assert(math.abs(got-value)<=1,`pixel {x},{y} channel {i}: {got} / {value}`) end
 end
 local function render(body: string): (buffer,any)
  local d=dataFor(body);return Raster.render(d.Scenes[1],nil,480),d
 end
 local sample=buffer.create(4);buffer.writeu8(sample,0,255);buffer.writeu8(sample,3,128)
 assert(math.abs(Mask.alpha(sample,0,'luminance')-.2125*128/255)<1e-9)
 assert(Mask.alpha(sample,0,'alpha')==128/255)
 for i=0,2 do buffer.writeu8(sample,i,128) end;buffer.writeu8(sample,3,255)
 assert(math.abs(Mask.alpha(sample,0,'luminance',true)-.2158605)<1e-6)
 -- Separable edge cases and analytical channel values, independent of rendering.
 local expected={normal=.75,multiply=.1875,screen=.8125,overlay=.375,darken=.25,lighten=.75,['color-dodge']=1,['color-burn']=0,['hard-light']=.625,['soft-light']=.375,difference=.5,exclusion=.625}
 for mode,v in expected do assert(math.abs(Blend.channel(mode,.25,.75)-v)<1e-9,mode) end
 assert(Blend.channel('color-dodge',0,1)==0 and Blend.channel('color-burn',1,0)==1)
 for mode in Blend.Modes do
  for _,b in {{0,0,0},{1,1,1},{1,0,0},{.2,.8,.4}} do for _,s in {{0,0,0},{1,1,1},{0,0,1},{.7,.2,.6}} do
   local out=Blend.rgb(mode,b,s)
   for _,c in out do assert(c==c and c>=-1e-8 and c<=1+1e-8,mode) end
  end end
 end
 local hue=Blend.rgb('hue',{1,0,0},{0,0,1});assert(math.abs(.3*hue[1]+.59*hue[2]+.11*hue[3]-.3)<1e-9)
 local a=buffer.create(4);local b=buffer.create(4)
 buffer.writeu8(a,0,255);buffer.writeu8(a,3,128);buffer.writeu8(b,2,255);buffer.writeu8(b,3,128)
 assert(Compositing.over(a,b,1,1,nil,'multiply'))
 assert(math.abs(buffer.readu8(a,0)-85)<=1 and math.abs(buffer.readu8(a,2)-85)<=1 and buffer.readu8(a,3)==192,'partial-alpha blend')
 local defs='<defs><mask id="m" maskContentUnits="objectBoundingBox"><rect width=".5" height="1" fill="white"/><rect x=".5" width=".5" height="1" fill="black"/></mask></defs>'
 b=render(defs..'<rect x="20" y="20" width="100" height="80" fill="red" mask="url(#m)"/>')
 expect(b,40,40,{255,0,0,255});expect(b,100,40,{0,0,0,0})
 b=render(defs..'<rect x="20" y="20" width="100" height="80" fill="red" style="mask:url(#m);mask-mode:alpha"/>')
 expect(b,100,40,{255,0,0,255})
 b=render('<defs><mask id="m" x="25%" y="25%" width="50%" height="50%" maskContentUnits="objectBoundingBox"><rect width="1" height="1" fill="white"/></mask></defs><g transform="translate(20 20) scale(2)"><rect width="50" height="50" fill="red" mask="url(#m)"/></g>')
 expect(b,60,60,{255,0,0,255});expect(b,30,60,{0,0,0,0});expect(b,100,60,{0,0,0,0})
 -- use x/y moves user-space mask content/region; bounding-box masks must not
 -- receive the offset twice. Compare against an explicitly translated group.
 for _,units in {'objectBoundingBox','userSpaceOnUse'} do
  for _,contentUnits in {'objectBoundingBox','userSpaceOnUse'} do
   local region=if units=='userSpaceOnUse' then ' x="0" y="0" width="60" height="60"' else ''
   local maskRect=if contentUnits=='objectBoundingBox' then '<rect width=".5" height="1" fill="white"/>' else '<rect width="60" height="60" fill="white"/>'
   local shape='<rect x="-30" y="-30" width="80" height="80" fill="red"/>'
   local prefix='<defs><g id="shape">'..shape..'</g><mask id="m" maskUnits="'..units..'" maskContentUnits="'..contentUnits..'"'..region..'>'..maskRect..'</mask></defs>'
   local usePixels=render(prefix..'<g transform="translate(20 15) scale(1.5)"><use href="#shape" x="90" y="65" mask="url(#m)"/></g>')
   local groupPixels=render(prefix..'<g transform="translate(20 15) scale(1.5)"><g transform="translate(90 65)" mask="url(#m)">'..shape..'</g></g>')
   assert(buffer.tostring(usePixels)==buffer.tostring(groupPixels),'use mask coordinate parity: '..units..'/'..contentUnits)
  end
 end
 -- Default 120% region includes strokes slightly outside the fill box.
 b=render('<defs><mask id="m"><rect width="200" height="200" fill="white"/></mask></defs><rect x="40" y="40" width="100" height="100" fill="red" stroke="blue" stroke-width="10" mask="url(#m)"/>')
 expect(b,37,70,{0,0,255,255});expect(b,70,70,{255,0,0,255})
 local background='<rect width="200" height="160" fill="yellow"/>'
 local children='<rect width="100" height="100" fill="blue" style="mix-blend-mode:multiply"/>'
 b=render(background..'<g>'..children..'</g>');expect(b,50,50,{0,0,0,255})
 b=render(background..'<g style="isolation:isolate">'..children..'</g>');expect(b,50,50,{0,0,255,255})
 b=render(background..'<defs><clipPath id="c"><rect x="10" y="10" width="80" height="80"/></clipPath></defs><g clip-path="url(#c)">'..children..'</g>')
 expect(b,50,50,{0,0,0,255});expect(b,5,5,{255,255,0,255})
 b=render(background..'<g opacity=".5">'..children..'</g>');expect(b,50,50,{128,128,128,255})
 b=render(background..defs..'<g mask="url(#m)">'..children..'</g>');expect(b,25,25,{0,0,255,255});expect(b,75,25,{255,255,0,255})
 -- Nested masks multiply coverage. Clip -> mask -> opacity is applied once to a group.
 b=render('<defs><mask id="a"><rect width="200" height="200" fill="white" opacity=".5"/></mask><mask id="b"><rect width="200" height="200" fill="white" opacity=".5" mask="url(#a)"/></mask><clipPath id="c"><rect width="50" height="100"/></clipPath></defs><g opacity=".5" mask="url(#b)" clip-path="url(#c)"><rect width="100" height="100" fill="red"/><rect x="25" width="75" height="100" fill="blue"/></g>')
 expect(b,10,20,{255,0,0,32});expect(b,40,20,{0,0,255,32});expect(b,75,20,{0,0,0,0})
 local d
 b,d=render('<defs><mask id="cycle"><rect width="100" height="100" fill="white" mask="url(#cycle)"/></mask></defs><rect width="100" height="100" fill="red" mask="url(#cycle)"/><rect x="150" width="50" height="50" fill="blue"/>')
 expect(b,10,10,{0,0,0,0});expect(b,170,20,{0,0,255,255});assert(#d.Diagnostics>0,'mask cycle')
 b,d=render('<rect width="100" height="100" fill="red" mask="url(#missing)"/><rect x="150" width="50" height="50" fill="blue"/>')
 expect(b,10,10,{0,0,0,0});expect(b,170,20,{0,0,255,255});assert(#d.Diagnostics>0,'missing mask')
 local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources)
 for _,issue in data.Diagnostics do print('S23_S24_DIAGNOSTIC',issue.Case,issue.Code,issue.Value) end
 assert(#data.Diagnostics==0,'visual source diagnostics')
 for _,scene in data.Scenes do for _,width in {240,480,960} do
  local pixels,h=Raster.render(scene,nil,width,function()return true end);assert(pixels and h==width*2/3)
 end end
 local work={Patterns={},PatternBytes=0,PatternDepth=0};local count=0
 assert(Raster.render(data.Scenes[7],nil,480,function()count+=1;return count<120 end,work)==nil)
 assert(work.CompositeLive==0 and (work.ClipDepth or 0)==0,'cancel restores resource counters')
 print('SVG S23/S24: mask modes/regions/units, nested masks, alpha, color spaces, 16 blend modes, isolation, clip backdrop, errors, cancellation and seven fixtures at three sizes passed')
 return data
end
