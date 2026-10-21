--!strict
return function(Filter,Kernel,Noise,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Gradient,Resources,Sources,Text)
 local function near(a,b,why) assert(math.abs(a-b)<1e-5,why..': '..a..' ~= '..b) end
 local identity={SX=1,SY=1,TX=0,TY=0}
 local function graph(steps,w,h)
  local region={X=0,Y=0,Width=w or 11,Height=h or 11}
  for _,s in steps do s.Region=s.Region or region;s.Input=s.Input or 0;s.Space=s.Space or 'sRGB' end
  return {Spatial=true,Steps=steps,Region=region,Inverse=identity,Transform=identity}
 end
 local function impulse()
  local b=buffer.create(11*11*4);buffer.writeu8(b,(5*11+5)*4,255);buffer.writeu8(b,(5*11+5)*4+3,255);return b
 end
 local function alpha(b,x,y) return buffer.readu8(b,(y*11+x)*4+3) end
 local b=impulse();Filter.apply(b,graph({{Kind='feMorphology',Operator='dilate',RadiusX=2,RadiusY=1}}),11,1)
 for y=0,10 do for x=0,10 do assert(alpha(b,x,y)==(if x>=3 and x<=7 and y>=4 and y<=6 then 255 else 0),'dilate impulse rectangle') end end
 Filter.apply(b,graph({{Kind='feMorphology',Operator='erode',RadiusX=2,RadiusY=1}}),11,1)
 assert(buffer.tostring(b)==buffer.tostring(impulse()),'erosion restores isolated impulse after dilation')
 local k={Kind='feConvolveMatrix',OrderX=3,OrderY=1,Kernel={1,0,0},TargetX=1,TargetY=0,Divisor=1,Bias=0,EdgeMode='none'}
 b=impulse();Filter.apply(b,graph({k}),11,1)
 assert(alpha(b,4,5)==255 and alpha(b,6,5)==0,'asymmetric kernel is reversed, input sampled at x+1')
 k=table.clone(k);k.Kernel={1,1,1};k.Divisor=3;b=impulse();Filter.apply(b,graph({k}),11,1)
 for x=4,6 do assert(alpha(b,x,5)==85 and buffer.readu8(b,(5*11+x)*4)==255,'convolution premultiplied red impulse') end
 k.PreserveAlpha=true;b=impulse();Filter.apply(b,graph({k}),11,1)
 assert(alpha(b,5,5)==255 and alpha(b,4,5)==0 and buffer.readu8(b,(5*11+5)*4)==85,'preserveAlpha convolves straight color only')
 -- Three taps at the left boundary: [0,red,blue], [red,red,blue], [green,red,blue].
 for mode,want in {none={1/3,0,1/3,2/3},duplicate={2/3,0,1/3,1},wrap={1/3,1/3,1/3,1}} do
  local bytes=buffer.create(3*4)
  for i,c in {{255,0,0,255},{0,0,255,255},{0,255,0,255}} do for j,n in c do buffer.writeu8(bytes,(i-1)*4+j-1,n) end end
  local s=table.clone(k);s.PreserveAlpha=false;s.EdgeMode=mode
  Filter.apply(bytes,graph({s},3,1),3,1)
  local a=buffer.readu8(bytes,3)/255
  for channel=1,3 do assert(math.abs(buffer.readu8(bytes,channel-1)/255*a-want[channel])<1/255,'edge '..mode) end
  near(a,want[4],'edge alpha')
 end
 -- Tile repeats the input subregion, even when half its pixels are transparent.
 local bytes=buffer.create(8*4);local tile=graph({{Kind='feFlood',Flood={1,0,0,1},Region={X=0,Y=0,Width=1,Height=1}},{Kind='feOffset',Input=1,DX=0,DY=0,Region={X=0,Y=0,Width=2,Height=1}},{Kind='feTile',Input=2}},8,1)
 Filter.apply(bytes,tile,8,1)
 for x=0,7 do assert(buffer.readu8(bytes,x*4+3)==(if x%2==0 then 255 else 0),'tile transparent interval') end
 local dis={Kind='feDisplacementMap',Input=0,Input2=1,MapSpace='sRGB',ScaleX=4,ScaleY=4,ChannelX=1,ChannelY=2}
 b=impulse();Filter.apply(b,graph({{Kind='feFlood',Flood={1,.5,0,1}},dis}),11,1)
 assert(alpha(b,3,5)==255,'positive red map samples right and moves visible source left')
 dis.ScaleX=3;b=impulse();Filter.apply(b,graph({{Kind='feFlood',Flood={1,.5,0,1}},dis}),11,1)
 assert(alpha(b,3,5)==128 and alpha(b,4,5)==128 and buffer.readu8(b,(5*11+3)*4)==255,'fractional displacement without dark fringes')
 -- Park-Miller's published 10000th value is independent of the filter code.
 local seed=1;for _=1,10000 do seed=Noise.random(seed) end;assert(seed==1043618065,'Park-Miller reference sequence')
 local n={Noise=Noise.new(7),FrequencyX=.043,FrequencyY=.067,Octaves=3,NoiseType='fractalNoise',Stitch=true,NoiseTile={X=0,Y=0,Width=80,Height=60}}
 for _,point in {{0,0},{7.5,11.5},{79.5,59.5}} do
  local a=Noise.sample(n,point[1],point[2]);local bx=Noise.sample(n,point[1]+80,point[2]);local by=Noise.sample(n,point[1],point[2]+60)
  for i=1,4 do near(a[i],bx[i],'stitched x periodicity');near(a[i],by[i],'stitched y periodicity') end
 end
 n.Octaves=0;for _,v in Noise.sample(n,2,3) do assert(v==.5,'zero octave fractalNoise') end
 n.NoiseType='turbulence';for _,v in Noise.sample(n,2,3) do assert(v==0,'zero octave turbulence') end
 local a,c=Noise.new(-7.9),Noise.new(8)
 for i=0,255 do assert(a.Permutation[i]==c.Permutation[i],'negative seed truncation and normalization') end
 local function parse(body,attrs)
  local xml=Parser.parse('<svg xmlns="http://www.w3.org/2000/svg"><defs><filter id="f" '..(attrs or '')..'>'..body..'</filter></defs><rect width="100" height="60" filter="url(#f)"/></svg>')
  local doc=Document.prepare(xml,{ResolveImage=Sources.ResolveImage});local errors={}
  local node=doc.Root.Children[#doc.Root.Children]
  local f=Filter.build(doc,node,{X=0,Y=0,Width=100,Height=60},{Width=480,Height=320,FontSize=16,RootFontSize=16},identity,function(code,value) table.insert(errors,{Code=code,Value=value}) end)
  return f,errors
 end
 local f,errors=parse('<feConvolveMatrix order="2" kernelMatrix="1 2 3 4"/>')
 assert(f.Steps[1].Divisor==10 and f.Steps[1].TargetX==1 and f.Steps[1].TargetY==1 and #errors==0,'convolution defaults')
 f,errors=parse('<feConvolveMatrix order="2" kernelMatrix="1"/>');assert(f.Steps[1].PassThrough and errors[1].Code=='invalid-convolution-kernel','malformed kernel passes through with diagnostic')
 f,errors=parse('<feConvolveMatrix order="0"/>');assert(not f and errors[1].Code=='invalid-filter-parameter')
 f=parse('<feMorphology radius="0 3"/>');assert(f.Steps[1].RadiusX==0 and f.Steps[1].RadiusY==0,'zero radius disables primitive')
 f=parse('<feMorphology radius=".02 .1"/>','primitiveUnits="objectBoundingBox"');assert(f.Steps[1].RadiusX==2 and f.Steps[1].RadiusY==6,'morphology object units')
 f,errors=parse('<feImage href="S21-source.png" preserveAspectRatio="none"/>');assert(f.Steps[1].Sampler and #errors==0,'resolved raster feImage')
 f,errors=parse('<feImage href="#local"/>');assert(not f.Steps[1].Sampler and errors[1].Code=='unsupported-filter-image-reference','vector feImage rest is explicit')
 f,errors=parse('<feTurbulence numOctaves="1000"/>');assert(f.Steps[1].Octaves==9 and errors[1].Code=='turbulence-octave-limit','bounded octave count')
 f,errors=parse('<feTurbulence baseFrequency="-1"/>');assert(not f and errors[1].Code=='invalid-filter-parameter')
 local calls=0;local work={FilterLive=29}
 assert(not Filter.apply(impulse(),graph({{Kind='feMorphology',Operator='dilate',RadiusX=2,RadiusY=2}}),11,1,function() calls+=1;return calls<25 end,work));assert(work.FilterLive==29,'morphology cancellation restores accounting')
 local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
 for _,d in data.Diagnostics do print('KERNEL_DIAGNOSTIC',d.Case,d.Code,d.Value) end
 assert(#data.Scenes==8 and #data.Diagnostics==0,'eight kernel/noise boards clean')
 for _,s in data.Scenes do assert(Raster.render(s,nil,120),'kernel fixture raster') end
 print('SVG S33/S34: impulse morphology/convolution, boundary modes, alpha, tile intervals, displacement, seeded noise/stitching, diagnostics, cancellation and eight boards passed')
 return data
end
