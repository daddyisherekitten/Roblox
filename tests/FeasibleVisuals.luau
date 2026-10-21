--!strict
return function(Parser,Style,Groups,Shapes,Effects,loadRenderTree,loadWordLayout,reference)
 local fixtureElement=require('DOM/Node').element
 local function near(a,b)assert(math.abs(a-b)<.001,tostring(a)..' ~= '..tostring(b))end
 local function resolve(css,name)
  local node=fixtureElement(name or 'div',{style=css})
  local s=Style.resolve(node,{},error);s.Node=node;return s
 end
 local style=resolve('filter:brightness(50%) opacity(40%);opacity:.5')
 local group={Gui={}}
 Groups.paint(group,style);near(group.Gui.GroupColor3.R,.5);near(group.Gui.GroupTransparency,.8)
 Groups.paint(group,style,.8);near(group.Gui.GroupTransparency,.68);near(Groups.opacity(group,style),.8)
 style=resolve('filter:brightness(50%) opacity(40%);opacity:.5','img')
 Groups.paint(group,style);near(group.Gui.GroupColor3.R,1);near(group.Gui.GroupTransparency,.5)
 Groups.paint(group,resolve('filter:brightness(.2);filter:initial'));near(group.Gui.GroupColor3.R,1);near(group.Gui.GroupTransparency,0)
 local missingGeometry={Kind='Words',Gui={ZIndex=1},Style={},Items={{Kind='Word',Gui={Visible=true},Style={}}}}
 Groups.arrange(missingGeometry);assert(missingGeometry.OpacityBounds[3]==0,'Unarranged diagnostic-only words must not enter opacity bounds')
 local messages={};Style.resolve(fixtureElement('div',{style='filter:blur(2px)'}),{},function(m)table.insert(messages,m)end)
 assert(#messages==1,'Unavailable container filter must remain diagnosed')
 local circle=resolve('width:100px;height:100px;background:red;border:4px solid blue;border-shape:circle(50%)')
 local g=Shapes.geometry(circle,100,100);near(g.Radius,48);near(g.Outer,50);near(g.Left,0)
 local pixels=Shapes.render(circle,g,{Width=100,Height=100})
 local function channel(x,y,c)return buffer.readu8(pixels,(y*100+x)*4+c)end
 assert(channel(0,0,3)==0 and channel(50,50,0)==255 and channel(50,50,3)==255)
 assert(channel(50,1,2)==255 and channel(50,1,0)==0,'The circle border must have its own color and centered stroke')
 circle.BorderShape=resolve('border-shape:circle(45%)').BorderShape
 g=Shapes.geometry(circle,140,76);near(g.Radius,math.sqrt((136*136+72*72)/2)*.45)
 assert(g.Top<0,'The contour may extend outside the rectangular layout box')
 assert(resolve('border-shape:circle(40%);border-shape:initial').BorderShape==nil)
 local allocated={};local factory={}
 function factory.create(class,parent,props)
  local gui=table.clone(props or {});gui.Parent=parent;gui.ClassName=class;gui.BackgroundTransparency=gui.BackgroundTransparency or 1
  gui.Visible=true;gui.Destroy=function(self)self.Destroyed=true end;table.insert(allocated,gui);return gui
 end
 factory.modifier=factory.create
 local images={}
 local effects=Effects.new(error,function(size)
  local image={Size=size,Writes=0};function image:WritePixelsBuffer(_,_,data)self.Pixels=data;self.Writes+=1 end
  function image:Destroy()self.Destroyed=true end;table.insert(images,image);return image
 end)
 local box={Gui={BackgroundTransparency=0},Factory=factory,Style=circle}
 effects:Draw(box,140,76);local surface=box.BorderShapeSurface;local image=surface.ImageContent
 effects:Draw(box,140,76);assert(surface.ImageContent==image and image.Writes==1,'An unchanged circle reuses its raster')
 box.Style=resolve('background:red');effects:Draw(box,140,76)
 assert(surface.ImageTransparency==1 and box.Gui.BackgroundTransparency==0,'Removing the shape restores the ordinary background')
 effects:Destroy();for _,img in images do assert(img.Destroyed)end
 local renderer=loadRenderTree(factory)
 local layout=loadWordLayout({['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*10,Y=size}end}})
 local function build(mode)
  local tree=renderer.build(Parser.parse('<p><span style="box-decoration-break:'..mode..';padding:3px 6px;border:2px solid red;background:blue">aa bb cc</span> dd</p>'),{},error)
  return tree.Children[1].Children[1],tree
 end
 local clone,tree=build('clone');assert(clone.Kind=='Words','Explicit clone must remain a wrapping inline')
 local alive=function()return true end
 layout.arrange(clone,56,0,0,alive)
 assert(#clone.FragmentPool==3 and clone.Items[1].X==8 and clone.Items[2].X==8 and clone.Items[3].X==8)
 for _,slot in clone.FragmentPool do near(slot.Gui.Size[1],36);near(slot.Gui.BackgroundTransparency,0)end
 local count=#allocated
 layout.arrange(clone,56,0,0,alive);assert(#allocated==count,'Repeated layout must reuse fragment decorations')
 layout.arrange(clone,200,0,0,alive);assert(clone.FragmentPool[1].Gui.Visible and not clone.FragmentPool[2].Gui.Visible)
 layout.arrange(clone,56,0,0,alive);assert(#allocated==count)
 local slice=build('slice');layout.arrange(slice,56,0,0,alive)
 assert(slice.Items[1].X==8 and slice.Items[2].X==0 and slice.Items[3].X==0,'slice reserves only the unbroken outer edges')
 assert(slice.FragmentPool[1].Gui.Size[1]==28 and slice.FragmentPool[3].Gui.Size[1]==28)
 local wordWidths={[' ']=reference.space};for _,word in reference.words do wordWidths[word.text]=word.width end
 local nativeLayout=loadWordLayout({['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=assert(wordWidths[text],text),Y=size}end}})
 local nativeTree=renderer.build(Parser.parse('<p><span style="font:14px Arial;box-decoration-break:clone;padding:3px 6px;border:2px solid blue;background:orange">Alpha Beta Gamma Delta Epsilon</span></p>'),{},error)
 local nativeRun=nativeTree.Children[1].Children[1]
 nativeLayout.arrange(nativeRun,reference.contentWidth,0,0,alive)
 for i,word in reference.words do near(nativeRun.Items[i].X,word.x);assert(nativeRun.Items[i].LineIndex==word.line)end
 for i,width in reference.fragmentWidths do near(nativeRun.FragmentPool[i].Gui.Size[1],width)end
 local longTree=renderer.build(Parser.parse('<p><span style="box-decoration-break:slice;overflow-wrap:anywhere;padding:3px 6px;border:2px solid red;background:blue">abcdefghij</span></p>'),{},error)
 local longRun=longTree.Children[1].Children[1];layout.arrange(longRun,56,0,0,alive)
 assert(#longRun.FragmentPool==3 and longRun.DisplayItems[1].FragmentPaintLeft==8)
 assert(longRun.DisplayItems[1].FragmentPaintRight==0 and longRun.DisplayItems[2].FragmentPaintLeft==0 and longRun.DisplayItems[2].FragmentPaintRight==0 and longRun.DisplayItems[3].FragmentPaintRight==8,'Split words must preserve only the sliced outer edges')
 local liveTree=renderer.build(Parser.parse('<style>#fragment{box-decoration-break:clone;padding:3px 6px;border:2px solid red;background:blue}#fragment:hover{box-decoration-break:slice}#filtered:hover{filter:brightness(.5) opacity(.4)}</style><p><span id="fragment">aa bb cc</span></p><div id="filtered">Native</div>'),{},error)
 local liveRun=liveTree.Children[1].Children[1];local liveFragment=liveRun.Items[1].Style.Node
 layout.arrange(liveRun,56,0,0,alive);assert(liveTree:SetCSSState('hover',liveFragment))
 layout.arrange(liveRun,56,0,0,alive);assert(liveRun.Items[2].X==0 and liveRun.FragmentPool[2].Gui.Size[1]==20)
 local filterBox=liveTree.Children[2];assert(not filterBox.OpacityGroup)
 assert(liveTree:SetCSSState('hover',filterBox.Node));local filterGroup=assert(filterBox.OpacityGroup)
 near(filterGroup.Gui.GroupColor3.R,.5);near(filterGroup.Gui.GroupTransparency,.6)
 assert(liveTree:SetCSSState('hover',nil));assert(filterBox.OpacityGroup==filterGroup)
 near(filterGroup.Gui.GroupColor3.R,1);near(filterGroup.Gui.GroupTransparency,0)
 local filtered=renderer.build(Parser.parse('<div style="filter:brightness(.5) opacity(.4);opacity:.5">Native text</div>'),{},error)
 near(filtered.Children[1].OpacityGroup.Gui.GroupColor3.R,.5);near(filtered.Children[1].OpacityGroup.Gui.GroupTransparency,.8)
 print('Feasible visuals: subtree compositing, image filter isolation, circle raster/reuse/reset and cloned/sliced inline reflow passed')
end
