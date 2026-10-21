--!strict
return function(Parser,Style,BorderPixels,MaskPixels,Clip,loadRenderTree,loadWordLayout,loadBlockLayout,Properties,fixtureHTML,fixtureCSS)
 local fixtureElement=require('DOM/Node').element
 local function near(a,b)assert(math.abs(a-b)<.001,tostring(a)..' ~= '..tostring(b))end
 local function resolve(css,parent)return Style.resolve(fixtureElement('div',{style=css}),parent or {FontSize=20,Color=Color3.new()},error)end
 local shadow=resolve('box-shadow:1px 2px 3px red;box-shadow-offset:4px,8px 9px;box-shadow-color:blue;box-shadow-position:inset,outset')
 assert(#shadow.BoxShadows==2 and shadow.BoxShadows[1].X==4 and shadow.BoxShadows[1].Y==4 and shadow.BoxShadows[1].Inset)
 assert(shadow.BoxShadows[2].X==8 and shadow.BoxShadows[2].Y==9 and shadow.BoxShadows[2].Blur==3 and not shadow.BoxShadows[2].Inset)
 assert(shadow.BoxShadows[2].Color==Color3.fromRGB(0,0,255))
 assert(#resolve('box-shadow:1px 2px red;box-shadow:initial').BoxShadows==0)
 assert(#resolve('box-shadow-color:red').BoxShadows==0,'Color alone must not create a shadow')
 local inherited=resolve('box-shadow:inherit',shadow);assert(#inherited.BoxShadows==2 and inherited.BoxShadows[2].X==8)
 local corners=resolve('corner:12px 18px / 6px 9px bevel round notch scoop;corner-top-right-shape:squircle')
 assert(corners.CornerShape=='mixed' and table.concat(corners.CornerShapes,',')=='bevel,squircle,notch,scoop')
 assert(corners.BorderRadii[1].X.Value==12 and corners.BorderRadii[2].Y.Value==9)
 local side=resolve('direction:rtl;corner-inline-start:8px 12px bevel notch')
 assert(side.BorderRadii[2].X.Value==8 and side.BorderRadii[3].X.Value==12 and side.CornerShapes[2]=='bevel' and side.CornerShapes[3]=='notch')
 for _,invalid in {'corner:2px/nope bevel','corner:1px 2px 3px 4px 5px bevel','corner-top-left:1px / 2px notch'}do
  local warnings={};local s=Style.resolve(fixtureElement('div',{style='corner:9px round;'..invalid}),{},function(m)table.insert(warnings,m)end)
  assert(#warnings==1 and s.BorderRadii[1].X.Value==9 and s.CornerShape=='round','Invalid corner shorthand must be atomic')
 end
 local logical=resolve('-webkit-border-end:initial');for _,edge in logical.BorderSides do assert(type(edge.Width)=='number')end
 local mask=resolve('-webkit-mask:linear-gradient(black,black) center / 20px 10px no-repeat content-box')
 assert(mask.MaskImage.Kind=='layers' and mask.MaskSizes[1].X.Value==20 and mask.MaskClips[1]=='content-box')
 assert(resolve('mask-image:linear-gradient(black,black);mask:none').MaskImage==nil,'none must remove an existing mask')
 assert(resolve('-webkit-mask-image:linear-gradient(black,black);-webkit-mask:initial').MaskImage==nil)
 local xor=resolve('-webkit-mask-composite:xor');assert(xor.MaskComposite=='exclude')
 local dark=resolve('mask-image:linear-gradient(black,black);mask-mode:luminance')
 local alpha=MaskPixels.render(dark,dark.MaskImage,10,10,{Width=10,Height=10});assert(buffer.readu8(alpha,55)==0,'Black luminance mask must hide the content')
 dark.MaskMode='alpha';alpha=MaskPixels.render(dark,dark.MaskImage,10,10,{Width=10,Height=10});assert(buffer.readu8(alpha,55)==255)
 local image=resolve('font-size:20px;border:2px solid transparent;border-image:linear-gradient(to right,red,blue) 25% fill / 1em / 3px stretch')
 assert(image.BorderImageSlice.Fill and image.BorderImageSlice.Percent[1] and image.BorderImageWidth[1].Value==20 and image.BorderImageOutset[1].Value==3)
 assert(resolve('border-image:linear-gradient(red,blue) round').BorderImageRepeat=='round')
 local border=resolve('border-image:linear-gradient(to right,red,blue) 20% / 1 stretch')
 local function bytes(fill)
  border.BorderImageSlice.Fill=fill;return BorderPixels.render(border.BorderImageSource,100,60,{6,8,10,12},border,{Width=100,Height=60})
 end
 local unfilled=bytes(false);assert(buffer.readu8(unfilled,(30*100+50)*4+3)==0)
 assert(buffer.readu8(unfilled,(30*100+11)*4+3)==255 and buffer.readu8(unfilled,(30*100+12)*4+3)==0,'Nine-slice left edge must stop at the requested width')
 assert(buffer.readu8(bytes(true),(30*100+50)*4+3)==255,'fill must paint the center')
 local borderMask=resolve('-webkit-mask-box-image:linear-gradient(black,black) 20% / 6px stretch')
 local maskBytes=MaskPixels.render(borderMask,borderMask.MaskBorderSource,100,60,{Width=100,Height=60})
 assert(buffer.readu8(maskBytes,30*100+2)==255 and buffer.readu8(maskBytes,30*100+50)==0,'Mask border must retain only nine-slice edge paint without fill')
 borderMask=resolve('mask-border:linear-gradient(to right,transparent,black) 0 fill / 0 stretch')
 maskBytes=MaskPixels.render(borderMask,borderMask.MaskBorderSource,100,60,{Width=100,Height=60})
 assert(buffer.readu8(maskBytes,30*100+2)<15 and buffer.readu8(maskBytes,30*100+97)>240,'Zero-slice fill must keep the full gradient')
 assert(resolve('mask-border:linear-gradient(black,black) 10% / 3px;mask:initial').MaskBorderSource==nil,'mask shorthand must also reset mask-border')
 local created={}
 local function create(class,parent,props)local g=table.clone(props or {});g.ClassName=class;g.Parent=parent;g.ZIndex=g.ZIndex or 1;g.Destroy=function()end;table.insert(created,g);return g end
 local factory={create=create,modifier=create}
 local renderer=loadRenderTree(factory)
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*6,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local tree=renderer.build(Parser.parse('<div id="table" style="display:table;width:140px;border-spacing:6px"><div id="a" style="display:table-cell">A</div><div id="b" style="display:table-cell">B</div></div><div style="position:relative"><div id="clip" style="position:absolute;width:100px;height:60px;left:10px;top:12px;clip:rect(5px,80px,auto,8px);background:red">Clip</div></div>'),{},error)
 local ids={};for node,box in tree.NodeBoxes do if node.Attributes and node.Attributes.id then ids[node.Attributes.id]=box end end
 local realParent=ids.a.Node.Parent
 for _,width in {300,180,300}do
  layout.arrange(tree,width,0,0,function()return true end)
  assert(ids.a.Node.Parent==realParent and ids.b.Node.Parent==realParent,'Anonymous CSS rows must preserve the DOM parent')
  assert(#ids.table.TableRows==1 and ids.table.TableRows[1].Box.AnonymousTable,'Direct cells must generate one anonymous row')
  near(ids.a.LayoutY,ids.b.LayoutY);near(ids.b.LayoutX-(ids.a.LayoutX+ids.a.OuterWidth),6)
  local c=ids.clip;local view=assert(c.ClipRectViewport)
  near(view.Size[1],72);near(view.Size[2],55);near(c.Gui.Position[1],-8);near(c.Gui.Position[2],-5)
 end
 local c=ids.clip;local view=c.ClipRectViewport;local count=#created
 Clip.apply(c,10,12);near(view.Position[1],18);near(view.Position[2],17)
 c.Style.ClipRect=nil;Clip.apply(c,10,12);assert(not view.ClipsDescendants);near(c.Gui.Position[1],0);near(view.Size[1],100)
 c.Style=resolve('position:fixed;clip:rect(auto,auto,auto,auto)');Clip.apply(c,15,20);near(view.Position[1],15);near(view.Size[2],60)
 assert(#created==count,'Clip changes must reuse the existing viewport')
 local messages={}
 renderer.build(Parser.parse(fixtureHTML),{},function(message)table.insert(messages,message)end,nil,nil,nil,nil,nil,nil,nil,nil,nil,{['styles.css']=fixtureCSS})
 for _,message in messages do
  local name=message:match('^Unsupported style: ([%w%-]+):')
  local knownImageLimit=name=='shape-outside'and message:find('url(',1,true)
  assert(not name or not Properties[name]or knownImageLimit,'A supported visual catalog probe still reports '..message)
  assert(not message:find('non-row content outside a caption',1,true),'Anonymous row repair must remove the original table warning')
 end
 local l,t,w,h,enabled=Clip.bounds(resolve('clip:rect(1px,3px,4px,2px)'),100,60);assert(not enabled);near(w,100);near(h,60)
 print('Visual completeness: atomic corners, shadow cascade, WebKit aliases, mask reset/luminance, nine-slice fill/widths, anonymous tables and retained rectangular clipping passed')
end
