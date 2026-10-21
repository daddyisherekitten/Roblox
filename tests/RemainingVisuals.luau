--!strict
return function(Parser,Style,Fit,ImageBox,ImageLayout,ShapeImage,Floats,loadShapeImages,loadRenderTree,reference)
 local fixtureElement=require('DOM/Node').element
 local function near(a,b)assert(math.abs(a-b)<1e-5,tostring(a)..' ~= '..tostring(b))end
 local function style(css,parent)return Style.resolve(fixtureElement('img',{style=css}),parent or {},error,true)end
 local function item(css)return {Style=style(css),IntrinsicWidth=200,IntrinsicHeight=100,ContentWidth=100,ContentHeight=80,BoxWidth=100,BoxHeight=80,Source='rbxassetid://1',Alt='',EmptyAlt=true}end
 local cropped=item('object-view-box:inset(10% 20% 30% 40%);object-fit:contain')
 local x,y,w,h=Fit.viewRectangle(cropped);near(x,0);near(y,2.5);near(w,100);near(h,75)
 x,y,w,h=Fit.rectangle(cropped);near(x,-100);near(y,-10);near(w,250);near(h,125)
 cropped.Style=style('object-view-box:xywh(40px 20px 50% 60px);object-fit:cover;object-position:top right')
 x,y,w,h=Fit.viewRectangle(cropped);near(x,-100/3);near(y,0);near(w,400/3);near(h,80)
 x,y,w,h=Fit.rectangle(cropped);near(x,-260/3);near(y,-80/3);near(w,800/3);near(h,400/3)
 cropped.Style=style('object-view-box:rect(10px 160px 90px 20px);object-fit:none')
 x,y,w,h=Fit.rectangle(cropped);near(x,-40);near(y,-10);near(w,200);near(h,100)
 assert(Fit.needsDimensions(style('width:100px;height:80px;object-view-box:inset(10%)')))
 assert(style('object-view-box:inset(10%);object-view-box:initial').ObjectViewBox==nil)
 local warnings={}
 for _,value in {'circle(40%)','xywh(1px 2px -3px 4px)','inset(1px round 4px)','rect(0 2px)'} do
  local s=Style.resolve(fixtureElement('img',{style='object-view-box:inset(20%);object-view-box:'..value}),{},function(m)table.insert(warnings,m)end,true)
  assert(s.ObjectViewBox.Kind=='inset')
 end
 assert(#warnings==4)
 local factory={}
 function factory.create(class,parent,props)local gui=table.clone(props or {});gui.ClassName=class;gui.Parent=parent;return gui end
 factory.modifier=factory.create
 local image=item('object-fit:contain;object-view-box:inset(10% 20% 30% 40%)')
 ImageBox.create(image,{},factory,nil,'test');ImageBox.arrange(image)
 assert(image.ImageClip and image.ImageGui.Parent==image.ImageClip)
 near(image.ImageGui.Position[1],-100);near(image.ImageGui.Position[2],-10)
 near(image.ImageGui.Position[1]+image.ImageGui.Size[1]/2,25)
 image.Style=style('object-fit:contain');ImageBox.arrange(image)
 near(image.ImageClip.Size[1],100);near(image.ImageClip.Size[2],80);near(image.ImageGui.Size[1],100);near(image.ImageGui.Size[2],50)
 local lazy=item('');ImageBox.create(lazy,{},factory,nil,'lazy');assert(not lazy.ImageClip)
 lazy.Style=style('object-view-box:inset(20%)');ImageBox.arrange(lazy);assert(lazy.ImageClip)
 local auto=item('object-view-box:inset(10% 20% 30% 40%)')
 ImageLayout.size(auto,300);near(auto.ContentWidth,reference.auto.width);near(auto.ContentHeight,reference.auto.height)
 auto.Style=style('width:100px;object-view-box:inset(10% 20% 30% 40%)')
 ImageLayout.size(auto,300);near(auto.ContentWidth,100);near(auto.ContentHeight,75)
 assert(style('image-orientation:initial;image-resolution:initial;mask-type:initial').ImageOrientation=='from-image')
 assert(style('mask-type:alpha').MaskType=='alpha' and style('mask-type:initial').MaskType=='luminance')
 assert(style('shape-image-threshold:150%').ShapeImageThreshold==1)
 assert(style('shape-image-threshold:-.5').ShapeImageThreshold==0)
 assert(style('shape-image-threshold:.5;shape-image-threshold:initial').ShapeImageThreshold==0)
 local rgba=buffer.create(8*4*4)
 local function alpha(x,y,a)buffer.writeu8(rgba,(y*8+x)*4+3,a)end
 alpha(1,0,128);alpha(4,1,255);alpha(5,2,255);alpha(1,3,255)
 local bytes=ShapeImage.alpha(rgba,8,4)
 local rows=ShapeImage.rows(bytes,8,4,128/255)
 assert(rows.Rows[1]==false,'Threshold is strictly greater, not greater-or-equal')
 assert(rows.Rows[2][1]==4 and rows.Rows[3][2]==6)
 local s=Style.resolve(fixtureElement('div',{style='float:left;shape-outside:url("alpha.png");shape-image-threshold:.5;shape-margin:0;padding:2px;border:1px solid black;margin:4px'}),{},error)
 local box={Style=s,ContentWidth=80,ContentHeight=40,ShapeImageProvider=function(src,t)assert(src=='alpha.png' and t==.5);return rows end}
 local flow={Floats={}};local rect=Floats.add(flow,box,'left',0,0,94,54,300)
 near(rect.ImageX,7);near(rect.ImageY,7)
 local left,right=Floats.bounds(flow,0,7,300,10);near(left,0);near(right,300)
 left=Floats.bounds(flow,0,17,300,10);near(left,57)
 left=Floats.bounds(flow,0,17,300,20);near(left,67)
 rect.ImageRows=ShapeImage.rows(bytes,8,4,.5)
 for _,line in reference.lines do near(Floats.bounds(flow,0,line.y,300,10),line.x) end
 rect.ImageRows=rows
 rect.Margin=5;left=Floats.bounds(flow,0,13,300,2);near(left,57+math.sqrt(21))
 local rightFlow={Floats={}};Floats.add(rightFlow,box,'right',206,0,94,54,300)
 local _,edge=Floats.bounds(rightFlow,0,17,300,10);near(edge,253)
 box.ShapeImageProvider=nil;local missing={Floats={}};Floats.add(missing,box,'left',0,0,94,54,300)
 left=Floats.bounds(missing,0,7,300,10);near(left,94,'Unreadable source preserves the normal float')
 -- One asynchronous asset read, shared thresholds, deterministic cleanup.
 local pending,cleanups,messages={}, {},{};local alive={Alive=true}
 function alive:AddCleanup(fn)table.insert(cleanups,fn)end
 alive.ResolveImage=function(src)return if src=='alpha.png' then 'rbxassetid://1' else nil end
 local reads,destroyed,changed=0,0,0
 local api={CreateEditableImageAsync=function()
  reads+=1;return {Size=Vector2.new(8,4),ReadPixelsBuffer=function()return rgba end,Destroy=function()destroyed+=1 end}
 end}
 local scheduler={defer=function(fn)table.insert(pending,fn)end,wait=function()error('Unexpected wait')end}
 local root={Children={box}}
 local loader=loadShapeImages().start(alive,root,function(m)table.insert(messages,m)end,function()changed+=1 end,{Task=scheduler,Asset=api,WorkBudgetMS=0})
 local probe=require('Layout/LayoutMeasurement').new(root,function()return true end).Root.Children[1]
 for index=1,40 do assert(probe.ShapeImageProvider('cold-'..index..'.png',0)==nil)end
 assert(#pending==0 and reads==0 and #messages==0,'Owned shape measurements must not allocate, request, consume source budgets or diagnose resources')
 assert(loader.Get('alpha.png',.5)==nil and reads==0)
 pending[1]();local loaded=loader.Get('alpha.png',.5);assert(loaded and reads==1 and destroyed==1 and changed==1)
 assert(probe.ShapeImageProvider('alpha.png',.5)==loaded and probe.ShapeImageProvider('alpha.png',.25)==nil and #pending==1,'Shape measurements read completed threshold data without requesting missing variants')
 assert(loader.Get('alpha.png',.25)==nil);pending[2]();assert(reads==1 and loader.Get('alpha.png',.25))
 loader.Get('missing.png',0);pending[3]();assert(#messages==1 and loader.Get('missing.png',0)==nil)
 loader.Get('alpha.png',.75);cleanups[1]();pending[4]();assert(changed==2 and not box.ShapeImageProvider and not box.ShapeImageMeasurement and probe.ShapeImageProvider('alpha.png',.5)==nil)
 -- External SVG keeps its own natural ratio before fill stretches the raster.
 local renderer=loadRenderTree(factory)
 local tree=renderer.build(Parser.parse('<p><img src="shape.svg" width="100" height="80" style="object-view-box:inset(10%)"></p>'),{},error,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,function()
  return Parser.parse('<svg width="200" height="100" viewBox="0 0 200 100"><rect width="200" height="100"/></svg>').Children[1]
 end)
 local svg=tree.SVGItems[1];assert(svg.SVGExternal and svg.IntrinsicWidth==200 and svg.IntrinsicHeight==100)
 ImageLayout.size(svg,300);near(svg.ContentWidth,100);near(svg.ContentHeight,80)
 svg.UpdateSVG=function()end;ImageBox.arrange(svg);near(svg.SVGRasterWidth/svg.SVGRasterHeight,2)
 local ratioOnly=renderer.build(Parser.parse('<img src="square.svg">'),{},error,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,function()
  return Parser.parse('<svg viewBox="0 0 10 10"></svg>').Children[1]
 end).SVGItems[1]
 near(ratioOnly.IntrinsicWidth,150);near(ratioOnly.IntrinsicHeight,150)
 print('RemainingVisuals: crop/fit/reset, SVG natural ratio, alpha threshold/float/margin, shared async loading and cleanup passed')
end
