--!strict
return function(Gradient: any,Document: any,Parser: any,Viewport: any,Viewports: any,Raster: any,Length: any,Geometry: any,Paint: any,Transform: any,Bounds: any,Rendering: any,Sources: any,Matrix: any): any
 local function near(a: number,b: number,epsilon: number?) assert(math.abs(a-b)<(epsilon or .01),'expected '..b..', got '..a) end
 local ctx={Width=480,Height=320,FontSize=16,RootFontSize=16}
 local function compile(defs: string,extra: string?,options: any?): (any,any,any)
  local original=Parser.parse('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><defs>'..defs..'</defs><rect id="shape" width="100" height="100" fill="url(#G) red" '..(extra or '')..'/></svg>')
  local doc=Document.prepare(original,options)
  local node=doc.Root.Children[2];local diagnostics={}
  local state=Paint.resolve(node.Attributes,nil,ctx);local fill=Paint.used(state,ctx)
  local bound=Gradient.bind(doc,node,fill,{X=0,Y=0,Width=100,Height=100},ctx,Matrix.identity(),function(code,value) table.insert(diagnostics,{Code=code,Value=value}) end)
  return bound,diagnostics,doc
 end
 local stops='<stop stop-color="red"/><stop offset="1" stop-color="blue"/>'
 local g,d=compile('<linearGradient id="G">'..stops..'</linearGradient>')
 assert(#d==0);local c=Gradient.sample(g,50,50);near(c[1],127.5);near(c[3],127.5)
 c=Gradient.sample(g,-10,0);near(c[1],255)
 g=compile('<linearGradient id="G" spreadMethod="repeat">'..stops..'</linearGradient>');c=Gradient.sample(g,-25,0);near(c[1],63.75)
 g=compile('<linearGradient id="G" spreadMethod="reflect">'..stops..'</linearGradient>');c=Gradient.sample(g,125,0);near(c[1],63.75)
 g=compile('<linearGradient id="G" gradientTransform="rotate(90 .5 .5)">'..stops..'</linearGradient>');c=Gradient.sample(g,20,25);near(c[1],191.25)
 g=compile('<linearGradient id="G" gradientUnits="userSpaceOnUse" x1="100" x2="200">'..stops..'</linearGradient>');c=Gradient.sample(g,150,10);near(c[1],127.5)
 g=compile('<linearGradient id="G" x1="1" x2="1" spreadMethod="repeat">'..stops..'</linearGradient>');c=Gradient.sample(g,10,10);near(c[3],255)
 g=compile('<linearGradient id="G" color-interpolation="linearRGB"><stop stop-color="black"/><stop offset="1" stop-color="white"/></linearGradient>');c=Gradient.sample(g,50,0);near(c[1],187.516,.01)
 g=compile('<linearGradient id="G"><stop stop-color="red" stop-opacity="0"/><stop offset="1" stop-color="blue"/></linearGradient>','fill-opacity=".5"');c=Gradient.sample(g,50,0);near(c[1],127.5);near(c[4],.25)
 g=compile('<linearGradient id="G"><stop offset=".5" stop-color="red"/><stop offset=".2" stop-color="blue"/><stop offset="1" stop-color="blue"/></linearGradient>');c=Gradient.sample(g,50,0);near(c[3],255)
 g=compile('<linearGradient id="G" href="#B" x2="50%"/><linearGradient id="B">'..stops..'</linearGradient>');c=Gradient.sample(g,25,0);near(c[1],127.5)
 g=compile('<linearGradient id="G" href="#B" style="--stop:green"/><linearGradient id="B" style="--stop:red"><stop style="stop-color:var(--stop)"/></linearGradient>');c=Gradient.sample(g,50,0);near(c[2],128)
 g=compile('<linearGradient id="G" xlink:href="#B"/><linearGradient id="B">'..stops..'</linearGradient>');c=Gradient.sample(g,50,0);near(c[1],127.5)
 g,d=compile('<linearGradient id="G" href="#B"/><linearGradient id="B" href="#G"/>');assert(d[1].Code=='cyclic-gradient-reference');near(g[1],255)
 g,d=compile('');assert(d[1].Code=='missing-gradient-target');near(g[1],255)
 g,d=compile('<linearGradient id="G"/>');assert(g==nil and #d==0)
 g=compile('<linearGradient id="G" gradientTransform="scale(0)">'..stops..'</linearGradient>');assert(g==nil)
 local calls=0
 g,d=compile('<linearGradient id="G" href="library.svg#B"/>',nil,{URL='/assets/main.svg',Resolve=function(url)
  calls+=1;assert(url=='/assets/library.svg');return '<svg xmlns="http://www.w3.org/2000/svg"><linearGradient id="B">'..stops..'</linearGradient></svg>'
 end});assert(calls==1 and #d==0);c=Gradient.sample(g,50,0);near(c[1],127.5)
 g=compile('<radialGradient id="G">'..stops..'</radialGradient>');c=Gradient.sample(g,50,50);near(c[1],255);c=Gradient.sample(g,75,50);near(c[1],127.5)
 g=compile('<radialGradient id="G" fx="25%" fy="50%">'..stops..'</radialGradient>');c=Gradient.sample(g,25,50);near(c[1],255);c=Gradient.sample(g,62.5,50);near(c[1],127.5)
 g=compile('<radialGradient id="G" fr="25%">'..stops..'</radialGradient>');c=Gradient.sample(g,60,50);near(c[1],255);c=Gradient.sample(g,87.5,50);near(c[1],127.5)
 g=compile('<radialGradient id="G" fr="50%">'..stops..'</radialGradient>');c=Gradient.sample(g,50,50);near(c[4],0)
 g,d=compile('<radialGradient id="G" r="-1">'..stops..'</radialGradient>');assert(d[1].Code=='invalid-gradient-length');near(g[1],255)
 g=compile('<radialGradient id="G" fx="150%">'..stops..'</radialGradient>');c=Gradient.sample(g,150,0);near(c[4],0);c=Gradient.sample(g,50,50);assert(c[4]>0)
 g=compile('<radialGradient id="G" fx="100%" spreadMethod="repeat">'..stops..'</radialGradient>');c=Gradient.sample(g,150,50);near(c[1],127.5);near(c[3],127.5)
 g=compile('<linearGradient id="G"><stop offset=".5" stop-color="red"/><stop offset=".5" stop-color="blue"/></linearGradient>')
 c=Gradient.pixel(g,50,25,1);near(c[1],127.5);near(c[3],127.5)
 g=compile('<linearGradient id="G" gradientTransform="rotate(90 .5 .5)" style="transform:none">'..stops..'</linearGradient>')
 c=Gradient.sample(g,25,80);near(c[1],191.25)
 g=compile('<radialGradient id="G" r=".000001">'..stops..'</radialGradient>')
 c=Gradient.sample(g,50.00005,50);near(c[1],127.5,.01)
 g=compile('<linearGradient id="G" color="green"><stop stop-color="currentColor"/></linearGradient>','color="red"')
 c=Gradient.sample(g,50,50);near(c[2],128);near(c[1],0)
 g,d=compile('<linearGradient id="G">'..string.rep('<stop/>',1025)..'</linearGradient>');assert(d[1].Code=='gradient-stop-limit')
 g,d=compile('<linearGradient xmlns="urn:foreign" id="G"><stop/></linearGradient>');assert(d[1].Code=='invalid-gradient-target')
 local inv=Matrix.inverse({SX=2,SY=3,KX=.4,KY=.2,TX=10,TY=-5});assert(inv)
 local x,y=Matrix.point({SX=2,SY=3,KX=.4,KY=.2,TX=10,TY=-5},12,18);x,y=Matrix.point(inv,x,y);near(x,12);near(y,18)
 local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient)
 for _,problem in data.Diagnostics do print(problem.Case,problem.Code,problem.Value) end
 assert(#data.Diagnostics==0,'Unexpected gradient fixture diagnostics')
 near(data.Scenes[3].Shapes[2].Fill.Stops[1].Color[1],245)
 near(data.Scenes[3].Shapes[3].Fill.Stops[1].Color[1],245)
 for _,width in {240,480,960} do
  for index,scene in data.Scenes do
   local bytes,height=Raster.render(scene,nil,width,function() return true end);assert(bytes and height==math.round(width*2/3))
   if index==1 then
    local function pixel(x: number,y: number): any local at=(math.floor(y*width/480)*width+math.floor(x*width/480))*4;return {buffer.readu8(bytes,at),buffer.readu8(bytes,at+1),buffer.readu8(bytes,at+2),buffer.readu8(bytes,at+3)} end
    local green=pixel(240,50);assert(green[2]>250 and green[1]<4 and green[3]<4)
    local alpha=pixel(125,140);assert(math.abs(alpha[4]-128)<=2)
    local rgb,light=pixel(125,230),pixel(355,230);assert(light[1]>rgb[1]+50)
   end
  end
 end
 local cancelled=Raster.render(data.Scenes[1],nil,480,function() return false end);assert(cancelled==nil)
 print('SVG S17/S18: stops, CSS, references, spread, alpha, color spaces, transforms, focal cones, fr, three raster sizes and cancellation passed')
 return data
end
