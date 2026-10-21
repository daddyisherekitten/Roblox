--!strict
return function(Filter,Ops,Blur,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Gradient,Resources,Sources,Text)
 local function near(a,b,why) assert(math.abs(a-b)<1e-5,why..': '..a..' ~= '..b) end
 local red,blue={1,0,0,.5},{0,0,1,.25}
 local expected={over={2/3,0,1/3,.625},['in']={1,0,0,.125},out={1,0,0,.375},atop={.5,0,.5,.25},xor={.75,0,.25,.5},lighter={2/3,0,1/3,.75}}
 -- Over: source premultiplied red=.5, blue=.125; unassociated red=.8.
 expected.over={.8,0,.2,.625}
 for op,values in expected do local c=Ops.composite(op,red,blue);for i=1,4 do near(c[i],values[i],op..' channel '..i) end end
 local c=Ops.composite('arithmetic',red,blue,{0,.5,.5,0});near(c[1],2/3,'arithmetic premultiplied red');near(c[4],.375,'arithmetic alpha')
 c=Ops.composite('arithmetic',{0,0,0,0},{0,0,0,0},{0,0,0,.25});assert(c[1]==1 and c[4]==.25,'arithmetic constant creates white alpha')
 local merged=Ops.point({Kind='feMerge',Inputs={1,2},Space='sRGB'},function(i) return if i==1 then red else blue end)
 near(merged[3],.4,'merge later node above');assert(Ops.point({Kind='feMerge',Inputs={},Space='sRGB'},function() error('empty merge has no input') end)[4]==0)
 local kernel,radius=Blur.kernel(1);local sum=0;for _,v in kernel do sum+=v end
 near(sum,1,'normalized Gaussian');assert(radius==3);near(kernel[1],kernel[#kernel],'Gaussian symmetry')
 near(kernel[4],.3990502796524549,'independent Gaussian center')
 local function pixelGraph(kind,extra)
  local step={Kind=kind,Space='sRGB',Input=0,Region={X=0,Y=0,Width=11,Height=11}}
  for k,v in extra do step[k]=v end
  return {Spatial=true,Steps={step},Region=step.Region,Inverse={SX=1,SY=1,TX=0,TY=0},Transform={SX=1,SY=1,TX=0,TY=0}}
 end
 local function impulse()
  local b=buffer.create(11*11*4);local at=(5*11+5)*4;buffer.writeu8(b,at,255);buffer.writeu8(b,at+3,255);return b
 end
 local graph=pixelGraph('feOffset',{DX=1.5,DY=-1});local bytes=impulse();local work={FilterLive=17}
 assert(Filter.apply(bytes,graph,11,1,nil,work));assert(work.FilterLive==17 and work.FilterPeak>17,'filter lifetime restores shared budget')
 for x=6,7 do local at=(4*11+x)*4;assert(buffer.readu8(bytes,at)==255 and buffer.readu8(bytes,at+3)==128,'fractional offset preserves premultiplied red') end
 assert(buffer.readu8(bytes,(5*11+5)*4+3)==0,'original location vacated')
 graph=pixelGraph('feGaussianBlur',{SigmaX=1,SigmaY=0});bytes=impulse();Filter.apply(bytes,graph,11,1)
 assert(buffer.readu8(bytes,(5*11+5)*4+3)==102 and buffer.readu8(bytes,(5*11+4)*4+3)==62,'1D Gaussian impulse oracle')
 assert(buffer.readu8(bytes,(4*11+5)*4+3)==0,'zero y deviation stays one row')
 assert(buffer.readu8(bytes,(5*11+4)*4)==255,'blur has no dark RGB fringe')
 local calls=0;work={FilterLive=23};assert(not Filter.apply(impulse(),graph,11,1,function() calls+=1;return calls<25 end,work));assert(work.FilterLive==23,'cancellation restores filter memory accounting')
 work={FilterLive=64*1024*1024};assert(not pcall(Filter.apply,impulse(),graph,11,1,nil,work));assert(work.FilterLive==64*1024*1024,'budget exception restores shared accounting')
 local function scene(svg)
  local data=Viewports(Parser,Viewport,{Cases={{Name='spatial-test',SVG='<svg xmlns="http://www.w3.org/2000/svg">'..svg..'</svg>'}}},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
  return data.Scenes[1],data.Diagnostics
 end
 local source='<circle cx="50" cy="50" r="20" fill="#2563eb" fill-opacity=".5"/>'
 local function filtered(body) return scene('<defs><filter id="f" x="-100%" y="-100%" width="300%" height="300%" color-interpolation-filters="sRGB">'..body..'</filter></defs><g filter="url(#f)">'..source..'</g>') end
 local shadow=filtered('<feDropShadow dx="8" dy="6" stdDeviation="2" flood-color="#7c3aed" flood-opacity=".7"/>')
 local manual=filtered('<feGaussianBlur in="SourceAlpha" stdDeviation="2"/><feOffset dx="8" dy="6" result="blur"/><feFlood flood-color="#7c3aed" flood-opacity=".7"/><feComposite in2="blur" operator="in"/><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>')
 local a,b=Raster.render(shadow,nil,240),Raster.render(manual,nil,240)
 local largest=0;for i=0,buffer.len(a)-1 do largest=math.max(largest,math.abs(buffer.readu8(a,i)-buffer.readu8(b,i))) end
 assert(largest<=1,'drop shadow equals expanded primitive graph')
 local zero=filtered('<feGaussianBlur stdDeviation="0"/><feOffset dx="0" dy="0"/>');local plain=scene(source)
 for _,width in {120,240,480} do
  local filtered,unfiltered=Raster.render(zero,nil,width),Raster.render(plain,nil,width)
  for at=0,buffer.len(filtered)-4,4 do
   assert(buffer.readu8(filtered,at+3)==buffer.readu8(unfiltered,at+3),'zero filters preserve alpha')
   if buffer.readu8(filtered,at+3)>0 then
    for channel=0,2 do assert(buffer.readu8(filtered,at+channel)==buffer.readu8(unfiltered,at+channel),'zero filters preserve visible RGB') end
   end
  end
 end
 local object=scene('<defs><filter id="f" primitiveUnits="objectBoundingBox"><feOffset dx=".25" dy=".5"/></filter></defs><rect width="100" height="60" filter="url(#f)"/>')
 local step=object.RenderTree[1].Children[1].Filter.Steps[1];assert(step.DX==25 and step.DY==30,'offset object units')
 local _,errors=filtered('<feGaussianBlur stdDeviation="-1"/>');assert(errors[1].Code=='invalid-filter-deviation')
 _,errors=filtered('<feGaussianBlur edgeMode="wrap"/>');assert(errors[1].Code=='unsupported-blur-edge-mode','unsupported edge mode diagnosed')
 local flood=filtered('<feFlood style="flood-color:rgba(255,0,0,.5);flood-opacity:.5"/>');bytes=Raster.render(flood,nil,480)
 assert(buffer.readu8(bytes,(50*480+50)*4)==255 and buffer.readu8(bytes,(50*480+50)*4+3)==64,'flood CSS and color alpha multiply')
 local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
 for _,d in data.Diagnostics do print('SPATIAL_DIAGNOSTIC',d.Case,d.Code,d.Value) end
 assert(#data.Scenes==8 and #data.Diagnostics==0,'eight spatial/composite boards clean')
 for _,s in data.Scenes do assert(Raster.render(s,nil,120),'spatial fixture raster') end
 print('SVG S31/S32: Gaussian impulse, offsets, premultiplied operators, shadow expansion, flood, regions, budgets, cancellation and eight boards passed')
 return data
end
