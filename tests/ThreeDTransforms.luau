--!strict
return function(Parser: any,Style: any,Transform: any,Matrix: any,Pixels: any,loadRenderTree: any,loadWordLayout: any,loadBlockLayout: any,Animations: any,composition: any)
 local fixtureElement=require('DOM/Node').element
	local parent={Font="Roboto",FontSize=16,RootFontSize=16,Color=Color3.new(),ColorAlpha=1,ViewportWidth=800,ViewportHeight=600}
	local function style(css: string): any return Style.resolve(fixtureElement("div",{style=css}),parent,error) end
	local function near(a: number,b: number,tolerance: number?) assert(math.abs(a-b)<(tolerance or .00001),tostring(a).." differs from "..b) end
	local function matrix(css: string): any return Transform.matrix(style("transform:"..css).Transform,100,80) end
	for _,record in composition.records do
		local combined=Transform.compose(style("transform:"..record.base).Transform,style("transform:"..record.effect).Transform,record.mode,100,80)
		local actual=Transform.matrix(combined,100,80)
		for i,expected in record.matrix do near(actual[i],expected,.00005)end
	end
	local repeated=Transform.compose(style("transform:translateX(40px) rotate(25deg)").Transform,style("transform:translateX(30px)").Transform,"accumulate",100,80,3)
	near(Transform.matrix(repeated,100,80)[13],130);near(Transform.matrix(repeated,100,80)[14],0)
	local inverse=Matrix.inverse;local inverseCalls=0
	Matrix.inverse=function(value)inverseCalls+=1;return inverse(value)end
	for _,css in {"none","translate(12px,8px)","rotate(73deg)","scale(-1,2)","scale(0)","skew(18deg,7deg)","matrix(1,2,3,4,5,6)"} do
		local value=matrix(css);local expected=inverse(value)
		assert(Matrix.backFacing(value)==(expected~=nil and expected[11]<0),"2D culling agrees with the complete inverse: "..css)
	end
	assert(inverseCalls==0,"Two-dimensional paint does not invert matrices")
	Matrix.backFacing(matrix("rotateY(180deg)"));assert(inverseCalls==1,"3D culling retains the complete inverse")
	Matrix.inverse=inverse
	local translated=Matrix.point(matrix("rotateY(90deg) translateZ(50px)"),0,0)
	near(translated.X,50);near(translated.Z,0)
	local ordered=Matrix.point(matrix("translateZ(50px) rotateY(90deg)"),0,0);near(ordered.Z,50)
	local scaled=Matrix.point(matrix("translate3d(10%,25%,30px) scale3d(2,3,-4)"),2,3,4)
	near(scaled.X,14);near(scaled.Y,29);near(scaled.Z,14)
	assert(style("rotate:x 30deg;translate:1px 2px 3px;scale:2 3 4").Rotate.Axis=="x")
	assert(Matrix.equal(matrix("rotate3d(0,2,0,45deg)"),matrix("rotateY(45deg)")))
	assert(Matrix.equal(matrix("matrix(1,0,0,1,10,20)"),matrix("translate(10px,20px)")))
	assert(Matrix.equal(matrix("matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,10,20,30,1)"),matrix("translate3d(10px,20px,30px)")))
	near(Matrix.point(matrix("skewX(45deg) scaleY(2)"),0,3).X,6)
	near(matrix("scale(50%,200%)")[1],.5)
	local origin=style("transform-origin:top left 20px").TransformOrigin;assert(origin.Z.Value==20 and origin.X.Value==0)
	assert(style("transform-origin:bottom").TransformOrigin.Y.Value==100)
	assert(not Matrix.native(matrix("scaleX(-1)")),"A reflected GUI needs a projected surface")
	local tilted=matrix("rotateX(-18deg) rotateY(28deg)")
	-- Chromium computed matrix for the effects-page cube, rounded to 6 decimals.
	for i,expected in { .882948,-.145075,-.446494,0,0,.951057,-.309017,0,.469472,.272846,.839733,0,0,0,0,1 } do near(tilted[i],expected,.000001) end
	local perspective=Matrix.around(Matrix.perspective(650),126.45,77)
	local cube=Matrix.multiply(perspective,Matrix.multiply(Matrix.translate(90.5,60),Matrix.around(tilted,50,50)))
	local front=Matrix.multiply(cube,Matrix.around(matrix("translateZ(50px)"),50,50))
	local geometry=Pixels.project(100,100,front)
	local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
	for _,p in geometry.Points do minX,minY=math.min(minX,p.X),math.min(minY,p.Y);maxX,maxY=math.max(maxX,p.X),math.max(maxY,p.Y) end
	-- Browser getBoundingClientRect relative to the perspective stage.
	near(minX,118.89969,.02);near(minY,68.36951,.02);near(maxX-minX,93.88504,.02);near(maxY-minY,118.32507,.02)
	local faces={"translateZ(50px)","rotateY(180deg) translateZ(50px)","rotateY(90deg) translateZ(50px)","rotateY(-90deg) translateZ(50px)","rotateX(90deg) translateZ(50px)","rotateX(-90deg) translateZ(50px)"}
	for i,face in faces do local composed=Matrix.multiply(cube,Matrix.around(matrix(face),50,50));assert(Matrix.backFacing(composed)==(i==2 or i==3 or i==6),"Cull the accumulated matrix, including parent rotation") end
	local behind=Pixels.project(100,80,matrix("perspective(100px) translateZ(101px)"));assert(#behind.Points==0,"Discard planes behind the eye")
	local crossing=Pixels.project(100,80,Matrix.around(matrix("perspective(20px) rotateY(80deg)"),50,40));assert(#crossing.Points>=3,"Clip planes crossing the eye without NaN or inverted projection")
	for _,p in crossing.Points do assert(p.X==p.X and p.Y==p.Y and p.Q>0) end
	local aa=style("transform:rotateX(-18deg) rotateY(28deg)").Transform
	local bb=style("transform:rotateX(342deg) rotateY(388deg)").Transform
	local midpoint=Transform.interpolate(aa,bb,.5,100,100);near(midpoint[1].Value,162);near(midpoint[2].Value,208)
	local interpolated=Matrix.interpolate(matrix("translate3d(0px,0px,0px) rotateY(0deg)"),matrix("translate3d(20px,40px,60px) rotateY(120deg)"),.5)
	near(interpolated[13],10);near(interpolated[14],20);near(interpolated[15],30);near(interpolated[1],.5)
	local original=matrix("perspective(400px) translateZ(30px) rotateX(30deg) scale3d(2,3,4)")
	local normalized=Matrix.interpolate(original,original,.5);for i=1,16 do near(normalized[i],original[i]/original[16]) end
	local function plane(css: string,m: any): any
		return {Box={Style=style(css),OuterWidth=80,OuterHeight=40,Children={}},Matrix=m,Children={},Preserve=true}
	end
	local intersect=plane("",Matrix.identity())
	local hiddenPlane=plane("display:none;background:red",Matrix.identity())
	hiddenPlane.Children={plane("background:blue",Matrix.identity())}
	local hiddenPlanes=Pixels.scene(hiddenPlane)
	assert(#hiddenPlanes==0,"display:none suppresses a retained 3D plane and its entire subtree")
	local hiddenKey=Pixels.sceneKey(hiddenPlane)
	hiddenPlane.Box.Style.Hidden=false
	assert(#Pixels.scene(hiddenPlane)==2 and Pixels.sceneKey(hiddenPlane)~=hiddenKey,"Revealing a plane invalidates the retained scene key")
	local flatOwner={Style=style(""),OuterWidth=80,OuterHeight=40,Children={hiddenPlane.Box}}
	hiddenPlane.Box.Style.Hidden=true
	assert(#Pixels.flat(flatOwner).Children==0,"A retained hidden subtree must not enter a two-dimensional mask composition")
	intersect.Children={plane("background:red",Matrix.around(matrix("rotateY(45deg)"),40,20)),plane("background:blue",Matrix.around(matrix("rotateY(-45deg)"),40,20))}
	local planes,bounds=Pixels.scene(intersect);assert(#planes==2)
	local pixelPlan={Width=bounds.Width,Height=bounds.Height};local depthPixels=Pixels.renderScene(planes,bounds,pixelPlan)
	local function pixel(data: buffer,x: number,y: number,channel: number): number return buffer.readu8(data,((y-bounds.Top)*pixelPlan.Width+x-bounds.Left)*4+channel) end
	assert(pixel(depthPixels,20,20,0)>240 and pixel(depthPixels,20,20,2)<15 and pixel(depthPixels,60,20,2)>240,"Intersecting planes need different front faces on each side of the crossing")
	intersect.Preserve=false;intersect.Box.Style.Opacity=.5
	local flatPlanes,flatBounds=Pixels.scene(intersect);assert(#flatPlanes==1,"flat composites descendants before the parent projection")
	local flatPixels=Pixels.renderScene(flatPlanes,flatBounds,{Width=flatBounds.Width,Height=flatBounds.Height})
	assert(buffer.readu8(flatPixels,((20-flatBounds.Top)*flatBounds.Width+20-flatBounds.Left)*4+3)==128,"Group opacity is applied once to overlapping descendants")
	local images={};local factory={}
	function factory.create(class: string,owner: any,props: any): any
		local gui=table.clone(props);gui.ClassName=class;gui.Parent=owner;gui.AnchorPoint=gui.AnchorPoint or Vector2.new(0,0);gui.Position=gui.Position or UDim2.fromOffset(0,0);gui.BackgroundTransparency=gui.BackgroundTransparency or 1;gui.BackgroundColor3=gui.BackgroundColor3 or Color3.new(1,1,1);function gui:Destroy() self.Destroyed=true end;return gui
	end
	function factory.modifier(class: string,owner: any,props: any): any return factory.create(class,owner,props) end
	function factory.createImage(size: any): any
		local image={Size=size,Writes=0};function image:WritePixelsBuffer(_: any,_: any,pixels: buffer) self.Pixels=pixels;self.Writes+=1 end;function image:Destroy() assert(not self.Destroyed);self.Destroyed=true end;table.insert(images,image);return image
	end
	local renderer=loadRenderTree(factory)
	local words=loadWordLayout({["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=#text*7,Y=size} end}})
	local layout=loadBlockLayout({["Layout/WordLayout"]=words,["Layout/TextMeasure"]={measure=function(text,_,size)return {X=#text*7,Y=size} end}})
	local html='<style>*{box-sizing:border-box}@keyframes turn{from{transform:rotateX(-18deg) rotateY(28deg)}to{transform:rotateX(342deg) rotateY(388deg)}}#stage{width:281px;height:220px;display:grid;place-items:center;perspective:650px;perspective-origin:45% 35%;background:#e7eff9;overflow:hidden}#cube{position:relative;width:100px;height:100px;transform-style:preserve-3d;transform:rotateX(-18deg) rotateY(28deg);animation:turn 9s linear infinite;animation-play-state:paused}#cube>span{position:absolute;inset:0;display:grid;place-items:center;border:1px solid #ffffffb3;background:#2976bfcc;color:white;font-size:12px;font-weight:bold;backface-visibility:hidden}#cube>span:nth-child(2n){background:#9957bacc}</style><div id="stage"><div id="cube">'
	for i,face in faces do html..='<span id="face'..i..'" style="transform:'..face..'">'..({"VORN","HINTEN","RECHTS","LINKS","OBEN","UNTEN"})[i]..'</span>' end
	html..='</div></div>'
	local document=Parser.parse(html);local tree=renderer.build(document,{},error);layout.arrange(tree,400,0,0,function()return true end)
	local ids={};for node,box in tree.NodeBoxes do if node.Attributes and node.Attributes.id then ids[node.Attributes.id]=box end end
	assert(ids.cube.Scene3DSurface and ids.cube.Scene3DRoot==ids.cube and ids.face1.Scene3DRoot==ids.cube)
	assert(ids.face1.OuterWidth==100 and ids.face1.OuterHeight==100,"Transforming never changes the flow or absolute layout size")
	local initial=ids.cube.Scene3DSurface.ImageContent;local writes=initial.Writes
 local preview={Width=initial.Size.X,Height=initial.Size.Y,Pixels=initial.Pixels}
	layout.arrange(tree,400,0,0,function()return true end);assert(ids.cube.Scene3DSurface.ImageContent==initial and initial.Writes==writes,"Unchanged layout reuses the projected image")
	local clock=0;local callback;local cleanups={}
	local page={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(cleanups,fn)end}
	local signal={Connect=function(_,fn)callback=fn;return {Disconnect=function()callback=nil end} end}
	local runtime=Animations.start(page,tree,error,{RunService={Heartbeat=signal},Clock=function()return clock end},20)
	runtime:AfterLayout();assert(callback==nil,"Paused cube is idle")
	ids.cube.Style.AnimationPlay={"running"};runtime:AfterLayout();clock=2.25;callback()
	near(ids.cube.TransformOverride[1].Value,72);near(ids.cube.TransformOverride[2].Value,118)
	assert(ids.cube.Scene3DSurface.ImageContent~=initial or initial.Writes>writes,"A frame redraws the composed 3D scene")
	ids.cube.Style.AnimationPlay={"paused"};runtime:AfterLayout();assert(callback==nil)
	local pausedPixels=ids.cube.Scene3DSurface.ImageContent.Pixels
	clock=5;runtime:AfterLayout();assert(ids.cube.Scene3DSurface.ImageContent.Pixels==pausedPixels,"Paused animation does not rasterize again")
	for _,cleanup in cleanups do cleanup() end;tree.VisualEffects:Destroy();for _,image in images do assert(image.Destroyed,"All retained scene images are released") end
	local hoverDoc=Parser.parse('<style>#card{width:80px;height:40px;background:blue;transform:rotateY(20deg);transition:transform 1s linear}#card:hover{transform:rotateY(60deg)}</style><div id="card">TEST</div>')
	local hoverTree=renderer.build(hoverDoc,{},error);layout.arrange(hoverTree,200,0,0,function()return true end)
	local card=hoverTree.Children[1];local hoverClock=0;local hoverCallback;local hoverCleanup
	local hoverRuntime=Animations.start({Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)hoverCleanup=fn end},hoverTree,error,{RunService={Heartbeat={Connect=function(_,fn)hoverCallback=fn;return {Disconnect=function()hoverCallback=nil end} end}},Clock=function()return hoverClock end},20)
	hoverRuntime:AfterLayout();hoverTree:SetCSSState("hover",card.Node);assert(hoverCallback)
	hoverClock=.5;hoverCallback();near(card.TransformOverride[1].Value,40)
	hoverTree:SetCSSState("hover",nil)
	near(hoverRuntime.Transitions[card].Properties.transform.Duration,.5)
	hoverClock=.75;hoverCallback();near(card.TransformOverride[1].Value,30)
	hoverClock=1;hoverCallback();near(card.TransformOverride[1].Value,20);assert(hoverCallback==nil,'Mid-flight 3D reversals shorten their duration like native CSS transitions')
	hoverCleanup();hoverTree.VisualEffects:Destroy()
	local hiddenTree=renderer.build(Parser.parse('<style>#stage{width:80px;height:40px;transform:rotateY(20deg)}#ink{width:40px;height:40px;background:red}#stage:hover #ink{display:none}</style><div id="stage"><div id="ink"></div></div>'),{},error)
	layout.arrange(hiddenTree,200,0,0,function()return true end)
	local stage=hiddenTree.Children[1]
	for _,shown in {false,true,false,true} do
		hiddenTree:SetCSSState("hover",if shown then nil else stage.Node)
		layout.arrange(hiddenTree,200,0,0,function()return true end)
		local data=stage.Scene3DSurface.ImageContent.Pixels;local alpha=0
		for offset=3,buffer.len(data)-1,4 do alpha+=buffer.readu8(data,offset) end
		assert((alpha>0)==shown,"Projected surfaces must remove hidden retained children and restore them on repeated state changes")
	end
	hiddenTree.VisualEffects:Destroy()
	local flipHTML='<style>#flip{display:block;position:relative;width:280px;height:210px;background:transparent;border:0;padding:0;transform-style:preserve-3d}#flip.turned{transform:rotateY(180deg)}#flip>span{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;flex-direction:column;gap:5px;backface-visibility:hidden;border-radius:10px;background:#4164c8;color:white;pointer-events:none}#flip>span>span{font:60px/1.3 Georgia,serif}#flip small{font-size:12px}#flip .back{transform:rotateY(180deg);background:#dc654c}</style><div style="perspective:800px"><button id="flip" type="button"><span id="front"><span>FORM</span><small>Vorderseite</small></span><span id="back" class="back"><span>FLOW</span><small>Rückseite</small></span></button></div>'
	local flipTree=renderer.build(Parser.parse(flipHTML),{},error);layout.arrange(flipTree,400,0,0,function()return true end)
	local flip,front,back
	for node,box in flipTree.NodeBoxes do local id=node.Attributes and node.Attributes.id;if id=="flip"then flip=box elseif id=="front"then front=box elseif id=="back"then back=box end end
	assert(flip and front and back and flip.RichButton and flip.Control.Item.RichButton and not flip.Control.Item.Label,"Buttons retain styled descendants instead of flattening their caption")
	assert(front.OuterWidth==280 and front.OuterHeight==210 and back.OuterHeight==210,"Both faces fill the same positioned button")
	assert(front.Children[1].Style.FontSize==60 and front.Children[2].Style.FontSize==12,"Nested face typography remains independently styled")
	local flipGui,frontGui,control=flip.Gui,front.Gui,flip.Control
	for _,turned in {false,true,false,true}do
		flip.Node.Attributes.class=if turned then "turned"else ""
		local needed=flipTree:ApplyDOMChanges({[flip.Node]={Attributes={class=true}}})
		if needed then layout.arrange(flipTree,400,0,0,function()return true end)end
		local image=assert(flip.Scene3DSurface).ImageContent;local center=(math.floor(image.Size.Y/2)*image.Size.X+math.floor(image.Size.X/2))*4
		assert(buffer.readu8(image.Pixels,center+3)>240,"A visible face fills the center of the projected card")
		assert(buffer.readu8(image.Pixels,center+(if turned then 0 else 2))>180,"The visible face has the correct front/back color")
		assert(flip.Gui==flipGui and front.Gui==frontGui and flip.Control==control,"Flipping retains the control and descendant GUIs")
	end
	flipTree.VisualEffects:Destroy()
	print("3D transforms: CSS matrices, Chromium cube bounds, nested composition, perspective, backfaces, eye clipping, interpolation, retained raster, pause/resume and cleanup passed")
 do
  local html='<style>#snapshot{width:64px;height:32px;font:7px/9px Arial;background:linear-gradient(135deg,currentColor,#b0dcc0);color:#17324a;border-radius:4px}</style><div id="snapshot">'
  for index=1,12 do html..='<span>word'..index..' </span>'end;html..='</div>'
  local snapshotTree=renderer.build(Parser.parse(html),{},error);layout.arrange(snapshotTree,100,0,0,function()return true end)
  local owner
  for node,box in snapshotTree.NodeBoxes do if node.Attributes and node.Attributes.id=='snapshot'then owner=box end end
  assert(owner and owner.Children[1].Kind=='Words')
  local resource=newproxy();local shared={Owner=owner.Node,Value='before'};shared.Self=shared
  local function tag(s)s.SnapshotResource=resource;s.SnapshotLink=shared end
  tag(owner.Style);for _,run in owner.Children do tag(run.Style);for _,word in run.Items or{}do tag(word.Style)end end
  local canvasBytes=buffer.create(16);for at=0,12,4 do buffer.writeu32(canvasBytes,at,0xff403020)end
  local childStyle=table.clone(owner.Style);childStyle.Background=nil;childStyle.BackgroundImages={};childStyle.Isolation='auto';childStyle.MixBlendMode='normal';childStyle.Opacity=1
  local canvasChild={Style=childStyle,OuterWidth=8,OuterHeight=8,PaintX=44,PaintY=6,Children={},ImageItem={CanvasSurface={Width=2,Height=2,Pixels=canvasBytes}}}
  table.insert(owner.Children,canvasChild)
  local a=Pixels.snapshot(Pixels.flat(owner,true))
  local word=a.Box.Children[1].Items[1]
  assert(word.Style.SnapshotLink==a.Box.Style.SnapshotLink and a.Children[1].Box.Style.SnapshotLink==a.Box.Style.SnapshotLink,'One snapshot copies shared owners once across words and child planes')
  assert(a.Box.Style~=owner.Style and a.Box.Style.SnapshotLink~=shared and a.Box.Style.SnapshotLink.Self==a.Box.Style.SnapshotLink,'Snapshot preserves isolated owner cycles')
  assert(word.Style.SnapshotResource==resource and a.Children[1].Box.Style.SnapshotResource==resource,'Snapshot retains native resource identity')
  local function freeze(value,seen)
   if type(value)~='table'or seen[value]then return end;seen[value]=true
   for _,child in value do freeze(child,seen)end;if not table.isfrozen(value)then table.freeze(value)end
  end
  local function freezeStyles(node,seen)
   seen=seen or{};freeze(node.Box.Style,seen)
   for _,run in node.Box.Children do freeze(run.Style,seen);for _,item in run.Items do freeze(item.Style,seen)end end
   for _,child in node.Children do freezeStyles(child,seen)end
  end
  local function draw(node)
   freezeStyles(node)
   return Pixels.renderScene(Pixels.scene(node),{Left=0,Top=0,Width=64,Height=32},{Width=64,Height=32})
  end
  local before=draw(a);local width=a.Box.OuterWidth
  local center=(10*64+48)*4
  assert(buffer.readu8(before,center)==32 and buffer.readu8(before,center+1)==48 and buffer.readu8(before,center+2)==64 and buffer.readu8(before,center+3)==255,'Captured canvas pixels paint their exact RGBA sample')
  owner.Style.Color=Color3.fromRGB(240,180,20);owner.Style.BackgroundImages[1].Stops[1].Color=Color3.fromRGB(210,30,90)
  owner.OuterWidth=60;shared.Value='after';owner.Node.Attributes['data-snapshot']='changed'
  for _,run in owner.Children do for _,item in run.Items or{}do item.Text='changed';item.Style.Color=Color3.fromRGB(30,180,230);if item.Gui then item.Gui.Position=UDim2.fromOffset(1,2)end end end
  buffer.writeu32(canvasBytes,0,0xffbbccdd)
  local b=Pixels.snapshot(Pixels.flat(owner,true));local after=draw(b)
  assert(a.Box.OuterWidth==width and b.Box.OuterWidth==60 and a.Box.Style.SnapshotLink.Value=='before'and b.Box.Style.SnapshotLink.Value=='after','Pending captures retain independent geometry/style/DOM owner graphs')
  assert(a.Box.Style.SnapshotLink~=b.Box.Style.SnapshotLink and a.Box.Style.SnapshotResource==b.Box.Style.SnapshotResource,'Captures isolate copied tables while retaining native resources')
  assert(a.Children[1].Box.ImageItem.CanvasSurface.Pixels~=canvasBytes and buffer.readu32(a.Children[1].Box.ImageItem.CanvasSurface.Pixels,0)==0xff403020 and buffer.readu32(b.Children[1].Box.ImageItem.CanvasSurface.Pixels,0)==0xffbbccdd,'Pending captures isolate canvas bytes')
  assert(buffer.tostring(before)==buffer.tostring(draw(a))and buffer.tostring(before)~=buffer.tostring(after),'Rendering another capture cannot mutate an outstanding frame')
  snapshotTree.VisualEffects:Destroy()
 end

 return preview
end
