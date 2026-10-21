--!strict
return function(Filter,Lighting,Hit,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Gradient,Resources,Sources,Text)
 local function near(a,b,why) assert(math.abs(a-b)<1e-6,why..': '..a..' ~= '..b) end
 local region={X=0,Y=0,Width=20,Height=20}
 local nx,ny,nz=Lighting.normal(function() return .4 end,10,10,1,1,region,10)
 near(nx,0,'flat normal x');near(ny,0,'flat normal y');near(nz,1,'flat normal z')
 -- A linear plane has the same derivative at interior, edge and corner.
 for _,point in {{10,10},{.5,.5},{19.5,19.5},{.5,10},{10,19.5}} do
  nx,ny,nz=Lighting.normal(function(x,y) return .01*x+.02*y end,point[1],point[2],1,1,region,5)
  local n=math.sqrt(1+.1^2+.2^2)
  near(nx,-.1/n,'Sobel plane x');near(ny,-.2/n,'Sobel plane y');near(nz,1/n,'Sobel plane z')
 end
 local s={Kind='feDiffuseLighting',Constant=.8,Exponent=4,LightColor={1,.5,.25,1},Light={Kind='feDistantLight',X=0,Y=0,Z=1}}
 local c=Lighting.shade(s,0,0,0,0,0,1);near(c[1],.8,'diffuse Lambert');near(c[4],1,'diffuse opaque even outside source alpha')
 s.Kind='feSpecularLighting';c=Lighting.shade(s,0,0,0,0,0,1);near(c[4],.8,'specular alpha maximum');near(c[2]*c[4],.4,'premultiplied specular color')
 s.Kind='feDiffuseLighting';s.Light={Kind='fePointLight',X=0,Y=0,Z=10};c=Lighting.shade(s,0,0,0,0,0,1);near(c[1],.8,'point overhead')
 c=Lighting.shade(s,10,0,0,0,0,1);near(c[1],.8/math.sqrt(2),'point cosine')
 s.Light={Kind='feSpotLight',X=0,Y=0,Z=10,DX=0,DY=0,DZ=-1,Exponent=2,Cone=math.cos(math.rad(20))}
 c=Lighting.shade(s,10,0,0,0,0,1);near(c[1],0,'outside spot cone');near(c[4],1,'diffuse darkness is opaque')
 c=Lighting.shade(s,0,0,0,0,0,1);near(c[1],.8,'spot axis')
 -- Skia's cone fade spans .016 in cosine space, independently of image scale.
 local cutoff=s.Light.Cone
 for _,fraction in {0,.25,.5,1,2} do
  local cosine=cutoff+.016*fraction
  local x=10*math.sqrt(1/(cosine*cosine)-1)
  c=Lighting.shade(s,x,0,0,0,0,1)
  near(c[1],.8*cosine^3*math.min(fraction,1),'diffuse spot edge fade')
  near(c[4],1,'spot fade changes illumination, not diffuse alpha')
  s.Kind='feSpecularLighting'
  c=Lighting.shade(s,x,0,0,0,0,1)
  local expected=.8*((1+cosine)/2)^2*cosine^2*math.min(fraction,1)
  near(c[4],expected,'specular spot edge alpha')
  near(c[2]*c[4],expected*.5,'specular spot fade preserves premultiplied color')
  s.Kind='feDiffuseLighting'
 end
 local function scene(body)
  local data=Viewports(Parser,Viewport,{ResolveImage=Sources.ResolveImage,Cases={{Name='lighting-hit-test',SVG='<svg xmlns="http://www.w3.org/2000/svg">'..body..'</svg>'}}},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
  return data.Scenes[1],data.Diagnostics
 end
 local flat,errors=scene('<defs><filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="20" height="20" color-interpolation-filters="sRGB"><feDiffuseLighting lighting-color="currentColor" color="#804020" diffuseConstant=".5"><feDistantLight elevation="90"/></feDiffuseLighting></filter></defs><rect width="20" height="20" filter="url(#f)"/>')
 assert(#errors==0);local b=Raster.render(flat,nil,480);local at=(10*480+10)*4
 assert(buffer.readu8(b,at)==64 and buffer.readu8(b,at+1)==32 and buffer.readu8(b,at+2)==16 and buffer.readu8(b,at+3)==255,'CSS lighting-color actual raster')
 local _,bad=scene('<defs><filter id="f"><feSpecularLighting specularExponent="200"><fePointLight/></feSpecularLighting></filter></defs><rect width="20" height="20" filter="url(#f)"/>')
 assert(bad[1].Code=='invalid-lighting-parameter','invalid lighting exponent diagnosed')
 local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
 for _,d in data.Diagnostics do print('LIGHT_HIT_DIAGNOSTIC',d.Case,d.Code,d.Value) end
 assert(#data.Scenes==8 and #data.Diagnostics==0,'eight lighting/hit boards clean')
 for _,sc in data.Scenes do
  assert(Raster.render(sc,nil,120),'lighting/hit raster')
  for _,scale in {.5,1,2} do
   local snapshot=Hit.prepare(sc,scale)
   for i,p in sc.Probes or {} do local target=Hit.query(snapshot,p.X,p.Y);local id=if target then target.SourceId or '' else '';assert(id==p.Expected,sc.Name..' probe '..i..': '..id..' ~= '..p.Expected) end
  end
 end
 local hidden=scene('<g pointer-events="none"><rect id="override" width="100" height="100" style="pointer-events:ALL" visibility="hidden"/></g><rect id="display" width="100" height="100" display="none" pointer-events="all"/>')
 assert(Hit.query(Hit.prepare(hidden),50,50).SourceId=='override','inherited none can be overridden; display none excluded')
 local none=scene('<rect width="100" height="100" visibility="hidden"/>');assert(not Hit.query(Hit.prepare(none),50,50),'visiblePainted requires visibility')
 local box=scene('<circle id="bbox" cx="100" cy="100" r="50" pointer-events="bounding-box"/>');assert(Hit.query(Hit.prepare(box),55,55).SourceId=='bbox','bounding box corner outside circle')
 local zero=scene('<rect id="zero" width="100" height="100" opacity="0"/>');assert(Hit.query(Hit.prepare(zero),50,50).SourceId=='zero','opacity does not suppress shape hit')
 local round=scene('<path id="round" d="M50 50h100" stroke="black" stroke-width="20" stroke-linecap="round" fill="none"/>');assert(Hit.query(Hit.prepare(round),43,50).SourceId=='round','round cap geometry');assert(not Hit.query(Hit.prepare(round),39,50),'outside round cap')
 local nested=scene('<svg x="20" y="20" width="50" height="50"><rect width="100" height="100"/></svg>');assert(not Hit.query(Hit.prepare(nested),80,40),'nested viewport clips hits')
 local image=scene('<image id="image" href="S21-source.png" width="200" height="100" preserveAspectRatio="none"/>')
 local snapshot=Hit.prepare(image)
 assert(not Hit.query(snapshot,100,50),'transparent raster image hole is not painted')
 assert(Hit.query(snapshot,20,20).SourceId=='image','opaque raster image pixel is painted')
 image=scene('<image id="image" href="S21-source.png" width="200" height="100" preserveAspectRatio="none" pointer-events="all"/>')
 assert(Hit.query(Hit.prepare(image),100,50).SourceId=='image','image all includes transparent pixels')
 local count=0;local work={FilterLive=7};local f=flat.RenderTree[1].Children[1].Filter
 assert(not Filter.apply(buffer.create(20*20*4),f,20,1,function() count+=1;return count<25 end,work));assert(work.FilterLive==7,'lighting cancellation restores buffer budget')
 print('SVG S35/S36: analytic normals, light equations, color/alpha, cone limits, raster, pointer-event modes, clips/masks, stroke geometry, three-size probe targets and cancellation passed')
 return data
end
