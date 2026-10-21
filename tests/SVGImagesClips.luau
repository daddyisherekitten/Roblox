--!strict
return function(Resources,Image,ImageAssets,ClipPath,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Gradient,Sources,Matrix)
 local function dataFor(svg: string,resolve: any?,documents: any?): any
  return Viewports(Parser,Viewport,{Stage='S21_S22',Cases={{Name='test',SVG='<svg xmlns="http://www.w3.org/2000/svg" width="480" height="320">'..svg..'</svg>'}},ResolveImage=resolve,Documents=documents},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources)
 end
 local function pixel(bytes: buffer,width: number,x: number,y: number): any
  local at=(y*width+x)*4;return {buffer.readu8(bytes,at),buffer.readu8(bytes,at+1),buffer.readu8(bytes,at+2),buffer.readu8(bytes,at+3)}
 end
 local function expect(bytes: buffer,width: number,x: number,y: number,expected: any)
  local actual=pixel(bytes,width,x,y)
  for i,v in expected do assert(math.abs(actual[i]-v)<=1,`pixel {x},{y} channel {i}: {actual[i]} vs {v}`) end
 end
 local loads=0;local rgba=buffer.create(16)
 for i,v in {255,0,0,255,0,255,0,255,0,0,255,255,255,255,0,0} do buffer.writeu8(rgba,i-1,v) end
 local function resolve(url) loads+=1;assert(url=='test.png');return {Width=2,Height=2,Pixels=rgba} end
 local d=dataFor('<image href="test.png" x="10" y="10" width="20" height="20" image-rendering="pixelated"/><image href="test.png" x="50" y="10" height="20" image-rendering="pixelated"/>',resolve)
 assert(loads==1,'source cache')
 local b=Raster.render(d.Scenes[1],nil,480)
 expect(b,480,14,14,{255,0,0,255});expect(b,480,24,14,{0,255,0,255});expect(b,480,14,24,{0,0,255,255});expect(b,480,24,24,{0,0,0,0});expect(b,480,54,14,{255,0,0,255})
 -- Fully transparent yellow must not contaminate blue interpolation.
 local sampled=Image.sample({Pixels=rgba,Width=2,Height=2,Inverse=Matrix.identity()},1,1.5)
 assert(sampled[1]==0 and sampled[2]==0 and sampled[3]==255 and sampled[4]==.5)
 -- Union, holes, and intersection on the clipping path itself.
 d=dataFor('<defs><clipPath id="half"><rect width="60" height="100"/></clipPath><clipPath id="cut" clip-path="url(#half)"><path clip-rule="evenodd" d="M0 0H100V100H0Z M20 20H40V40H20Z"/></clipPath></defs><rect width="100" height="100" fill="red" clip-path="url(#cut)"/>')
 assert(#d.Diagnostics==0,'clip diagnostics')
 b=Raster.render(d.Scenes[1],nil,480)
 expect(b,480,10,10,{255,0,0,255});expect(b,480,30,30,{0,0,0,0});expect(b,480,80,50,{0,0,0,0})
 d=dataFor('<defs><clipPath id="c" clipPathUnits="objectBoundingBox"><rect x=".25" y=".25" width=".5" height=".5"/></clipPath></defs><g clip-path="url(#c)" transform="translate(20 30)" opacity=".5"><rect width="100" height="80" fill="red"/><rect x="50" width="50" height="80" fill="blue"/></g>')
 b=Raster.render(d.Scenes[1],nil,480)
 expect(b,480,50,60,{255,0,0,128});expect(b,480,80,60,{0,0,255,128});expect(b,480,30,60,{0,0,0,0})
 -- Clip silhouettes ignore fill, stroke, and opacity, but honor visibility.
 d=dataFor('<defs><clipPath id="c"><rect width="50" height="50" fill="none" opacity="0" stroke="red" stroke-width="20"/><rect x="50" width="50" height="50" visibility="hidden"/></clipPath></defs><rect width="100" height="100" fill="red" clip-path="url(#c)"/>')
 b=Raster.render(d.Scenes[1],nil,480)
 expect(b,480,25,25,{255,0,0,255});expect(b,480,55,25,{0,0,0,0})
 -- Cycles and unavailable assets cannot remove a valid neighbor or throw.
 d=dataFor('<defs><clipPath id="c" clip-path="url(#c)"><rect width="40" height="40"/></clipPath></defs><rect width="40" height="40" clip-path="url(#c)"/><image href="no.png" width="40" height="40"/><rect x="100" width="20" height="20" fill="blue"/>')
 b=Raster.render(d.Scenes[1],nil,480);expect(b,480,110,10,{0,0,255,255})
 assert(#d.Diagnostics>=2)
 local disposed=0
 local resolver=ImageAssets.resolver({['a.png']='rbxassetid://1'},{CreateEditableImageAsync=function() return {Size={X=2,Y=2},ReadPixelsBuffer=function() return rgba end,Destroy=function() disposed+=1 end} end},{fromUri=function(x)return x end},{new=function()return {} end})
 assert(resolver('a.png').Pixels==rgba and disposed==1)
 resolver=ImageAssets.resolver({['a.png']='rbxassetid://1'},{CreateEditableImageAsync=function() return {Size={X=2,Y=2},ReadPixelsBuffer=function()error('denied')end,Destroy=function()disposed+=1 end}end},{fromUri=function(x)return x end},{new=function()return {}end})
 assert(not pcall(resolver,'a.png') and disposed==2,'release on read failure')
 -- Root viewBox clipping uses the viewBox coordinate system.
 d=Viewports(Parser,Viewport,{Cases={{Name='rootclip',SVG='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160" clip-path="url(#c)"><defs><clipPath id="c"><rect width="50" height="50"/></clipPath></defs><rect width="240" height="160" fill="red"/></svg>'}}},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources)
 b=Raster.render(d.Scenes[1],nil,480);expect(b,480,80,80,{255,0,0,255});expect(b,480,120,80,{0,0,0,0})
 d=Viewports(Parser,Viewport,{Cases={{Name='rootbbox',SVG='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160" clip-path="url(#c)"><defs><clipPath id="c" clipPathUnits="objectBoundingBox"><rect width=".5" height="1"/></clipPath></defs><rect x="20" y="20" width="100" height="60" fill="red"/></svg>'}}},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources)
 b=Raster.render(d.Scenes[1],nil,480);expect(b,480,100,80,{255,0,0,255});expect(b,480,160,80,{0,0,0,0})
 -- Intrinsic dimensions contribute to objectBoundingBox on a containing group.
 d=dataFor('<defs><clipPath id="c" clipPathUnits="objectBoundingBox"><rect width=".5" height="1"/></clipPath></defs><g clip-path="url(#c)"><image href="test.png" x="20" y="20" height="40" image-rendering="pixelated"/></g>',resolve)
 b=Raster.render(d.Scenes[1],nil,480);expect(b,480,25,25,{255,0,0,255});expect(b,480,45,25,{0,0,0,0})
 -- All nine meet/slice alignments share the existing tested viewport mapping.
 for _,mode in {'meet','slice'} do for _,xx in {'Min','Mid','Max'} do for _,yy in {'Min','Mid','Max'} do
  d=dataFor(`<image href="test.png" width="100" height="50" preserveAspectRatio="x{xx}Y{yy} {mode}"/>`,resolve)
  local inv=d.Scenes[1].Shapes[1].Fill.Inverse
  local fit=Viewport.resolve({viewBox='0 0 2 2',preserveAspectRatio=`x{xx}Y{yy} {mode}`},0,0,100,50)
  local point=Matrix.inverse(fit.Transform)
  assert(inv.SX==point.SX and inv.SY==point.SY and inv.TX==point.TX and inv.TY==point.TY)
 end end end
 d=dataFor('<image href="a.svg" width="80" height="80"/><rect x="100" width="20" height="20" fill="blue"/>',nil,{['a.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><image href="a.svg" width="80" height="80"/></svg>'})
 b=Raster.render(d.Scenes[1],nil,480);expect(b,480,110,10,{0,0,255,255});assert(#d.Diagnostics>0,'cyclic image diagnostic')
 d=dataFor('<image href="bad.png" width="80" height="80"/><rect x="100" width="20" height="20" fill="blue"/>',function() return {Width=2,Height=2,Pixels=buffer.create(1)} end)
 b=Raster.render(d.Scenes[1],nil,480);expect(b,480,110,10,{0,0,255,255});assert(#d.Diagnostics>0,'invalid decoded image')
 local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources)
 for _,issue in data.Diagnostics do print('S21_S22_DIAGNOSTIC',issue.Case,issue.Code,issue.Value) end
 assert(#data.Diagnostics==0,'visual source diagnostics')
 for _,scene in data.Scenes do for _,width in {240,480,960} do
  local bytes,h=Raster.render(scene,nil,width,function() return true end)
  assert(bytes and h==width*2/3 and buffer.len(bytes)==width*h*4)
 end end
 local calls=0
 assert(Raster.render(data.Scenes[6],nil,480,function()calls+=1;return calls<20 end)==nil,'cancel clip raster')
 print('SVG S21/S22: images, cache, alpha, automatic size, clip units, holes, nested clips, opacity, resource errors, cleanup, cancellation and six visual sources at three sizes passed')
 return data
end
