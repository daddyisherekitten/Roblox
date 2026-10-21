--!strict
return function(Parser,Style,MaskPixels,loadRenderTree,loadWordLayout,loadBlockLayout,css)
 local fixtureElement=require('DOM/Node').element
 local function resolve(value) return Style.resolve(fixtureElement("div",{style=value}),{Font="Roboto",FontSize=13,Color=Color3.new()},error) end
 local chain='linear-gradient(black,black),radial-gradient(circle at center,black 0 24%,transparent 25%)'
 local composite=resolve('mask-image:'..chain..';mask-composite:exclude;mask-repeat:no-repeat')
 assert(composite.MaskImage.Kind=="layers" and #composite.MaskImage.Layers==2,'Both mask layers must survive CSS parsing')
 local function near(a,b) assert(math.abs(a-b)<.00001,tostring(a)..' ~= '..b) end
 near(MaskPixels.compose(.3,.6,'add'),.72)
 near(MaskPixels.compose(.3,.6,'subtract'),.12)
 near(MaskPixels.compose(.3,.6,'intersect'),.18)
 near(MaskPixels.compose(.3,.6,'exclude'),.54)
 local alpha=MaskPixels.render(composite,composite.MaskImage,328,60,{Width=328,Height=60})
 assert(buffer.readu8(alpha,30*328+164)==0 and buffer.readu8(alpha,30*328+20)==255,'Exclude must cut a transparent centered hole, retaining both sides')
 assert(buffer.readu8(alpha,0*328+164)==0 and buffer.readu8(alpha,30*328+120)==255,'CSS farthest-corner radial size must exceed the box height')
 local rgba=buffer.create(328*60*4);buffer.fill(rgba,0,255)
 local masked=MaskPixels.apply(rgba,alpha)
 assert(buffer.readu8(masked,(30*328+164)*4+3)==0 and buffer.readu8(masked,(30*328+20)*4+3)==255)
 assert(buffer.readu8(rgba,(30*328+164)*4+3)==255,'Mask application must preserve the source pixels')
 local allocated={}
 local function create(class,parent,properties)
  local object={ClassName=class,Parent=parent,Children={},Visible=true,BackgroundTransparency=1,Position={0,0},Size={0,0},ZIndex=1}
  for k,v in properties or {} do object[k]=v end
  function object:Destroy() self.Destroyed=true end
  if parent and parent.Children then table.insert(parent.Children,object) end
  return object
 end
 local function createImage(size)
  local image={Size=size,Writes=0}
  function image:WritePixelsBuffer(_,_,bytes) self.Pixels=bytes;self.Writes+=1 end
  function image:Destroy() assert(not self.Destroyed);self.Destroyed=true end
  table.insert(allocated,image);return image
 end
 local measure={measure=function(text,_,size)return {X=#text*7,Y=size} end}
 local overrides={['Layout/TextMeasure']=measure,['Layout/FontProfiles']={face=function(font)return font end}}
 local words=loadWordLayout(overrides);overrides['Layout/WordLayout']=words
 local layout=loadBlockLayout(overrides)
 local renderer=loadRenderTree({create=create,modifier=create,createImage=createImage})
 local maskCSS='*{box-sizing:border-box}body{font-size:13px;line-height:20px}'
 for selector,body in css:gmatch('([^{}]+){([^{}]+)}') do if selector:find('.lab-mask-',1,true) then maskCSS..=selector..'{'..body..'}' end end
 local tree=renderer.build(Parser.parse('<style>'..maskCSS..'</style><article style="width:328px;max-width:100%"><div id="content" class="lab-mask-content">CONTENT MASK</div><div id="composite" class="lab-mask-composite">ZWEI MASKEN</div></article>'),{},error)
 local ids={};for node,box in tree.NodeBoxes do if node.Attributes and node.Attributes.id then ids[node.Attributes.id]=box end end
 local function arrange(width) layout.arrange(tree,width,0,0,function()return true end) end
 arrange(400)
 local content=ids.content;local clip=content.OpacityGroup.MaskClip
 assert(clip and clip.Size[2]==content.OuterHeight-40 and clip.Position[2]==20,'content-box must clip the vertical padding as well as the horizontal padding')
 assert(clip.Size[2]==20 and content.OuterHeight==60,'The visible content mask is one line high; its CSS layout box stays 60px high')
 assert(content.OpacityGroup.Content.Position[2]==-20,'Clipping must preserve the original text coordinates')
 local box=ids.composite;local surface=assert(box.CSSMaskSurface,'Multiple masks must create a raster-composited paint surface')
 local output=surface.ImageContent;local width,height=output.Size.X,output.Size.Y
 local preview={Width=width,Height=height,Pixels=output.Pixels}
 assert(buffer.readu8(output.Pixels,(math.floor(height/2)*width+math.floor(width/2))*4+3)==0,'The actual renderer must upload transparent pixels in the hole')
 assert(buffer.readu8(output.Pixels,(math.floor(height/2)*width+5)*4+3)==255,'Paint outside the hole must remain opaque')
 local writes=output.Writes;arrange(400)
 assert(box.CSSMaskSurface==surface and surface.ImageContent==output and output.Writes==writes,'Unchanged layout must reuse the masked texture')
 assert(box.Gui.BackgroundTransparency==1,'Transform cleanup must not restore the unmasked background after composition')
 box.Style.MaskComposite='add';box.VisualEffects:DrawMask(box)
 assert(buffer.readu8(output.Pixels,(math.floor(height/2)*width+math.floor(width/2))*4+3)==255,'Changing the composition invalidates the cached alpha surface')
 box.Style.MaskComposite='exclude';arrange(280)
 assert(content.OpacityGroup.MaskClip==clip and box.CSSMaskSurface==surface,'Resize must retain GUI mask surfaces')
 assert(box.OuterWidth==280 and surface.Size[1]==280 and clip.Size[1]==240,'A real resize must recompute mask geometry against the narrower box')
 box.VisualEffects:ClearMask(box);assert(box.Gui.BackgroundTransparency==0 and surface.ImageTransparency==1,'Mask removal restores native painting')
 box.VisualEffects:Destroy();for _,image in allocated do assert(image.Destroyed,'Mask pixel allocations must be destroyed with the renderer') end
 print('HTML masks: actual effects CSS, two-axis content clipping, radial exclude, four alpha operators, retained cache, resize, restore and disposal passed')
 return preview
end
