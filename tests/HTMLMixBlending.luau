--!strict
return function(Parser,Node,Pixels,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local jobs,images,guis={},{},{}
 local tasks={defer=function(fn)table.insert(jobs,coroutine.create(fn))end,wait=function()coroutine.yield()end}
 local function drain()
  local count=0;while #jobs>0 do count+=1;assert(count<10000)
   local co=table.remove(jobs,1);local ok,e=coroutine.resume(co);assert(ok,e)
   if coroutine.status(co)~='dead'then table.insert(jobs,co)end
  end
 end
 local function create(class,parent,props)
  local object={ClassName=class,Parent=parent,Children={},Visible=true,BackgroundTransparency=1,Position={0,0},Size={0,0},ZIndex=1}
  for key,value in props do object[key]=value end
  function object:GetChildren()return self.Children end
  function object:IsA(kind)return kind==self.ClassName or kind=='GuiObject'and (self.ClassName=='Frame'or self.ClassName=='ImageLabel'or self.ClassName=='TextLabel')end
  function object:Destroy()assert(not self.Destroyed);self.Destroyed=true;if self.Parent then local index=table.find(self.Parent.Children,self);if index then table.remove(self.Parent.Children,index)end end;self.Parent=nil end
  if parent then parent.Children=parent.Children or {};table.insert(parent.Children,object)end;table.insert(guis,object);return object
 end
 local function createImage(size)
  local image={Size=size,Writes=0};function image:WritePixelsBuffer(_,_,bytes)self.Pixels=bytes;self.Writes+=1 end
  function image:Destroy()assert(not self.Destroyed);self.Destroyed=true end;table.insert(images,image);return image
 end
 local overrides={['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*7,Y=size}end},['Layout/FontProfiles']={face=function(font)return font end}}
 local words=loadWordLayout(overrides);overrides['Layout/WordLayout']=words;local layout=loadBlockLayout(overrides)
 local renderer=loadRenderTree({create=create,modifier=create,createImage=createImage,Task=tasks})
 local tree=renderer.build(Parser.parse('<style>body{margin:0}#stage{position:relative;width:340px;height:170px;isolation:isolate;background:#f0f3fa;border-radius:6px}#stage>span{position:absolute;width:135px;height:135px;top:17px;border-radius:50%;left:calc(50% - 110px);background:#dc654c}#stage>span+span{left:calc(50% - 25px);background:#4164c8;mix-blend-mode:multiply}</style><div id="stage"><span id="red"></span><span id="blue"></span></div>'),{},error)
 local function box(id)return tree.NodeBoxes[Node.findById(tree.Node,id)]end
 local stage,red,blue=box('stage'),box('red'),box('blue')
 layout.arrange(tree,400,0,0,function()return true end);drain()
 assert(red.PaintX==60 and blue.PaintX==145 and red.PaintY==17 and blue.PaintY==17,'Absolutely positioned circles use painted offsets, independent of flow layout coordinates')
 local stageGui,redGui,blueGui=stage.Gui,red.Gui,blue.Gui
 local function checkRecord(record)
  blue.Style.MixBlendMode=record.mode;blue.Style.Opacity=record.alpha
  tree.VisualEffects:UpdateComposites(tree,{[blue.Style]=true});drain()
  local node=Pixels.flat(stage,true);local captured=Pixels.snapshot(node)
  local planes=Pixels.scene(captured);local out=Pixels.renderScene(planes,{Left=0,Top=0,Width=340,Height=170},{Width=340,Height=170})
  for _,point in record.points do for channel=1,4 do
   local actual=buffer.readu8(out,(point.y*340+point.x)*4+channel-1)
   assert(math.abs(actual-point.rgba[channel])<=1,record.mode..' alpha='..record.alpha..' x='..point.x..' channel='..channel..' '..actual..' != '..point.rgba[channel])
  end end
  if record.mode~='normal'then
   local surface=assert(stage.CompositeSurface);local image=surface.ImageContent
   for _,point in record.points do for channel=1,4 do assert(math.abs(buffer.readu8(image.Pixels,(point.y*340+point.x)*4+channel-1)-point.rgba[channel])<=1,'Uploaded composition must equal browser reference')end end
   assert(stage.Gui.BackgroundTransparency==1 and red.Gui.Visible and blue.Gui.Visible and red.Gui.BackgroundTransparency==1 and blue.Gui.BackgroundTransparency==1,'Native hit surfaces stay visible while only their paint becomes transparent')
   assert(buffer.readu8(image.Pixels,3)<255,'The stage retains rounded transparent corners')
  else assert(not stage.CompositeSurface and red.Gui.Visible and blue.Gui.Visible,'Normal restores native sibling paints')end
 end
 for _,record in reference.records do checkRecord(record)end
 blue.Style.Opacity=1;blue.Style.MixBlendMode='multiply';tree.VisualEffects:UpdateComposites(tree);drain()
 local surface=stage.CompositeSurface;local image=surface.ImageContent;local writes=image.Writes
 tree.VisualEffects:UpdateComposites(tree);drain();assert(image.Writes==writes,'Unchanged groups do no raster/upload work')
 -- Repeated style requests coalesce and keep the native cards and hit targets.
 for _,mode in {'screen','difference','multiply','difference'}do blue.Style.MixBlendMode=mode;tree.VisualEffects:UpdateComposites(tree,{[blue.Style]=true})end
 drain();assert(stage.CompositeSurface==surface and surface.ImageContent==image)
 local result=buffer.readu8(image.Pixels,(85*340+170)*4);assert(result==155,'Only the latest captured mode is installed')
 assert(stage.Gui==stageGui and red.Gui==redGui and blue.Gui==blueGui and stage.OuterWidth==340 and stage.OuterHeight==170)
 stage.Node.Attributes.style='width:300px';tree:ApplyDOMChanges({[stage.Node]={Attributes={style=true}}})
 layout.arrange(tree,400,0,0,function()return true end);drain()
 assert(stage.CompositeSurface==surface and surface.Size[1]==300 and red.PaintX==40 and blue.PaintX==125,'Resize updates painted offsets while retaining the surface')
 stage.Node.Attributes.style='width:300px;background:transparent';red.Node.Attributes.style='background:transparent'
 local needed=tree:ApplyDOMChanges({[stage.Node]={Attributes={style=true}},[red.Node]={Attributes={style=true}}})
 assert(not needed);drain()
 blue.Node.Attributes.style='mix-blend-mode:normal'
 needed=tree:ApplyDOMChanges({[blue.Node]={Attributes={style=true}}});assert(not needed);drain()
 assert(not stage.CompositeSurface and stage.Gui.BackgroundTransparency==1 and red.Gui.BackgroundTransparency==1 and blue.Gui.BackgroundTransparency==0,'Removing composition restores current transparent author values rather than old opaque saved paints')
 stage.Node.Attributes.style='width:300px';red.Node.Attributes.style='';blue.Node.Attributes.style='mix-blend-mode:multiply'
 tree:ApplyDOMChanges({[stage.Node]={Attributes={style=true}},[red.Node]={Attributes={style=true}},[blue.Node]={Attributes={style=true}}});drain()
 assert(stage.CompositeSurface and stage.Gui==stageGui and red.Gui==redGui,'Transparent reset and subsequent blending retain native input owners')
 -- Auto containers between the blended leaf and isolated owner do not create
 -- accidental isolation. A nested isolate does start with transparent pixels.
 local outer={Style={Background=Color3.new(1,0,0)},OuterWidth=20,OuterHeight=20,Children={}}
 local inner={Style={Isolation='isolate'},OuterWidth=20,OuterHeight=20,Children={},PaintX=0,PaintY=0}
 local leaf={Style={Background=Color3.new(0,0,1),MixBlendMode='multiply'},OuterWidth=20,OuterHeight=20,Children={}}
 outer.Children={inner};inner.Children={leaf}
 local function center()local planes=Pixels.scene(Pixels.flat(outer,true));return Pixels.renderScene(planes,{Left=0,Top=0,Width=20,Height=20},{Width=20,Height=20})end
 local bytes=center();assert(buffer.readu8(bytes,(10*20+10)*4+2)==255,'Nested isolation must not blend blue against the outer red background')
 inner.Style.Isolation='auto';bytes=center();assert(buffer.readu8(bytes,(10*20+10)*4+2)==0,'Transparent auto containers retain the underlying sibling/ancestor backdrop')
 tree.VisualEffects:Destroy();drain();for _,value in images do assert(value.Destroyed,'Composition allocations and cached work are disposed')end
 assert(red.Gui.Visible and blue.Gui.Visible)
 print('HTML blending: Chromium colors/alpha, positioned circle overlap, isolation, rounded edges, actual upload, coalescing, cache, retained layout, resize and disposal passed')
end
