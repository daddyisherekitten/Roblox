--!strict
return function(Filter,Color,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Gradient,Resources,Sources,Text)
 local function near(a,b,why) assert(math.abs(a-b)<1e-6,why..': '..tostring(a)..' ~= '..tostring(b)) end
 local c={.2,.4,.8,.5}
 local function matrix(a) return Color.apply({Matrix=assert(Color.matrix(a))},c) end
 local out=matrix({});for i=1,4 do near(out[i],c[i],'identity') end
 out=matrix({type='saturate',values='0'});near(out[1],.213*.2+.715*.4+.072*.8,'luminance');near(out[1],out[2],'gray')
 out=matrix({type='hueRotate',values='360'});for i=1,4 do near(out[i],c[i],'hue full turn') end
 out=matrix({type='luminanceToAlpha'});near(out[4],.2125*.2+.7154*.4+.0721*.8,'luminance alpha');assert(out[1]==0)
 assert(Color.matrix({values='1 2'})==nil and Color.matrix({type='wat'})==nil and Color.matrix({values='nan'})==nil)
 assert(Color.numbers('1,,2')==nil and Color.numbers('0xff')==nil,'invalid numeric grammar')
 local f=Color.transfer({type='table',tableValues='0 .2 1'});near(Color.channel(f,.25),.1,'table interpolation');near(Color.channel(f,1),1,'table endpoint')
 f=Color.transfer({type='discrete',tableValues='0 .5 1'});near(Color.channel(f,1/3),.5,'discrete boundary');near(Color.channel(f,1),1,'discrete endpoint')
 near(Color.channel(Color.transfer({type='gamma',exponent='2'}),.5),.25,'gamma');near(Color.channel(Color.transfer({type='linear',slope='2',intercept='-.1'}),.2),.3,'linear')
 near(Color.channel(Color.transfer({type='table'}),.7),.7,'empty table identity')
 near(Color.channel(Color.transfer({type='table',tableValues='.3'}),.7),.3,'single table entry')
 local converted=Color.convert(Color.convert(c,'sRGB','linearRGB'),'linearRGB','sRGB');for i=1,4 do near(converted[i],c[i],'color roundtrip') end
 local ctx={Width=480,Height=320,FontSize=16,RootFontSize=16}
 local function build(markup,attrs)
  local d=Document.prepare(Parser.parse('<svg xmlns="http://www.w3.org/2000/svg"><defs>'..markup..'</defs><rect '..(attrs or 'x="10" y="20" width="100" height="60"')..' filter="url(#f)"/></svg>'))
  local problems={};local n=d.Root.Children[#d.Root.Children]
  local g=Filter.build(d,n,{X=10,Y=20,Width=100,Height=60},ctx,{SX=1,SY=1,TX=0,TY=0},function(code) table.insert(problems,code) end)
  return g,problems
 end
 local g=build('<filter id="f"><feColorMatrix result="a"/><feColorMatrix in="SourceAlpha" result="b"/><feBlend in="a" in2="b"/></filter>')
 assert(#g.Steps==3 and g.Steps[3].Input==1 and g.Steps[3].Input2==2,'named branch inputs')
 near(g.Region.X,0,'default x');near(g.Region.Y,14,'default y');near(g.Region.Width,120,'default width')
 g=build('<filter id="f" primitiveUnits="objectBoundingBox"><feColorMatrix x=".25" width=".5" result="a"/><feColorMatrix result="a"/><feColorMatrix in="a"/></filter>')
 near(g.Steps[1].Region.X,35,'primitive object x');near(g.Steps[2].Region.Width,50,'default inherits previous subregion');assert(g.Steps[3].Input==2,'nearest result wins')
 local problems;g,problems=build('<filter id="f"><feColorMatrix in="later"/><feColorMatrix result="later"/></filter>')
 assert(g.Steps[1].Input==0 and problems[1]=='unknown-filter-result','forward reference defaults to previous input')
 g=build('<filter id="base" x="0" width="1"><feColorMatrix/></filter><filter id="f" href="#base"/>');assert(#g.Steps==1 and g.Region.X==10 and g.Region.Width==100,'filter template inheritance')
 g=build('<filter id="f" filterUnits="userSpaceOnUse" x="5%" y="10%" width="50%" height="25%"><feColorMatrix x="30" width="80"/></filter>');assert(g.Region.X==24 and g.Region.Y==32 and g.Region.Width==240 and g.Steps[1].Region.Width==80,'user-space percentages and primitive region')
 g,problems=build('<filter id="f" href="#f"/>');assert(not g and problems[1]=='cyclic-filter-reference')
 g,problems=build('<filter id="f"><feUnsupported/></filter>');assert(not g and problems[1]=='unsupported-filter-primitive','future primitive diagnosed')
 g=build('<filter id="f"/>');local b=buffer.create(4);buffer.writeu32(b,0,0xffffffff);Filter.apply(b,g,1,1);assert(buffer.readu32(b,0)==0,'empty filter hides output')
 -- Pixel evaluator: sRGB half-white=128, linearRGB half-white=188, alpha unchanged.
 local function pixel(steps,rgba)
  local bytes=buffer.create(4);for i=1,4 do buffer.writeu8(bytes,i-1,rgba[i]) end
  local region={X=0,Y=0,Width=1,Height=1};for _,step in steps do step.Region=region end
  Filter.apply(bytes,{Steps=steps,Region=region,Inverse={SX=1,SY=1,TX=0,TY=0}},1,1)
  local p={};for i=1,4 do p[i]=buffer.readu8(bytes,i-1) end;return p
 end
 local functions={};for i=1,3 do functions[i]=Color.transfer({type='linear',slope='.5'}) end
 for space,expected in {sRGB=128,linearRGB=188} do
  out=pixel({{Kind='feComponentTransfer',Input=0,Space=space,Functions=functions}},{255,255,255,128})
  assert(out[1]==expected and out[2]==expected and out[3]==expected and out[4]==128,'numeric color space oracle')
 end
 out=pixel({{Input=0,Space='sRGB',Functions={[4]=Color.transfer({type='linear',intercept='.5'})}}},{255,0,0,0})
 assert(out[1]==0 and out[2]==0 and out[3]==0 and out[4]==128,'transparent source is black before alpha creation')
 out=pixel({{Kind='feBlend',Mode='screen',Input=0,Input2=-1,Space='sRGB'}},{255,0,0,128})
 assert(out[1]==170 and out[4]==192,'SourceAlpha branch composite oracle')
 local function scene(svg)
  local data=Viewports(Parser,Viewport,{Cases={{Name='filter-test',SVG='<svg xmlns="http://www.w3.org/2000/svg">'..svg..'</svg>'}}},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
  assert(#data.Diagnostics==0,'unexpected filter diagnostic');return data.Scenes[1]
 end
 local source='<rect x="30" y="40" width="80" height="50" fill="#804020"/>'
 local plain=Raster.render(scene(source),nil,120)
 local filtered=Raster.render(scene('<defs><filter id="f"><feColorMatrix/></filter></defs><g filter="url(#f)">'..source..'</g>'),nil,120)
 assert(buffer.tostring(plain)==buffer.tostring(filtered),'identity group equals unfiltered source')
 -- Filter must execute once on text group, before clipping and group opacity.
 local textScene=scene('<defs><filter id="f"><feComponentTransfer><feFuncA type="linear" slope=".5"/></feComponentTransfer></filter></defs><text x="20" y="90" font-size="70" filter="url(#f)">AA</text>')
 local group=textScene.RenderTree[1].Children[1];assert(group.Filter and group.Children[1].Filter==nil,'text filter once, not once per glyph')
 local clipped=scene('<defs><filter id="f"><feColorMatrix values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 1"/></filter><clipPath id="c"><rect x="30" y="40" width="40" height="50"/></clipPath></defs><g filter="url(#f)" clip-path="url(#c)" opacity=".5">'..source..'</g>')
 b=Raster.render(clipped,nil,480);local a=(50*480+40)*4;assert(buffer.readu8(b,a+2)==255 and buffer.readu8(b,a+3)==128,'filter before opacity');assert(buffer.readu8(b,(50*480+90)*4+3)==0,'clip after filter')
 local cancel=0;g=build('<filter id="f"><feColorMatrix/></filter>');b=buffer.create(480*320*4)
 assert(not Filter.apply(b,g,480,1,function() cancel+=1;return cancel<3 end) and cancel==3,'scanline cancellation')
 local viewportScene=scene('<defs><filter id="f" x="-100%" y="-100%" width="300%" height="300%"><feComponentTransfer><feFuncA type="linear" intercept="1"/></feComponentTransfer></filter></defs><svg x="100" y="100" width="100" height="100"><rect x="0" y="0" width="100" height="100" fill="blue" filter="url(#f)"/></svg>')
 b=Raster.render(viewportScene,nil,480);assert(buffer.readu8(b,(110*480+90)*4+3)==0 and buffer.readu8(b,(110*480+110)*4+3)==255,'alpha-creating filter respects ancestor viewport')
 local data=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
 for _,d in data.Diagnostics do print('FILTER_DIAGNOSTIC',d.Case,d.Code,d.Value) end
 assert(#data.Scenes==8 and #data.Diagnostics==0,'eight filter fixtures without unexpected diagnostics')
 for _,s in data.Scenes do assert(Raster.render(s,nil,120),'filter fixture raster') end
 print('SVG filters: graph, regions, references, color matrices, channel transfer, numeric RGBA, text, clipping and cancellation passed')
 return data
end
