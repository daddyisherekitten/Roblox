--!strict
return function(Parser: any, Style: any, Properties: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any, ScrollLayout: any)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css: string): any
		return Style.resolve(fixtureElement("div",{style=css}), {Font="Roboto",FontSize=20,Color=Color3.new(0,0,0)}, error)
	end
	local text=resolve([[hyphens:auto;hyphenate-character:"~";hyphenate-limit-chars:6 2 3;text-emphasis:filled sesame #663399;text-emphasis-position:under left;quotes:"<" ">" "[" "]";writing-mode:vertical-rl]])
	assert(text.Hyphens=="auto" and text.HyphenateCharacter=="~" and text.HyphenateLimitChars[1]==6)
	assert(text.TextEmphasisStyle and text.TextEmphasisPosition.Vertical=="under" and text.WritingMode=="vertical-rl")
	assert(text.Quotes[1][1]=="<" and text.Quotes[2][2]=="]")
	local scrolling=resolve("overscroll-behavior:contain none;scroll-snap-type:y mandatory;scroll-snap-align:center end;scroll-padding:4px 5px;scroll-margin-block:6px 7px")
	assert(scrolling.OverscrollX=="contain" and scrolling.OverscrollY=="none")
	assert(scrolling.ScrollSnapType.Axis=="y" and scrolling.ScrollSnapType.Strictness=="mandatory")
	assert(scrolling.ScrollSnapAlign.Block=="center" and scrolling.ScrollSnapAlign.Inline=="end")
	local function px(value: any): number return if type(value)=="number" then value else value.Value end
	assert(px(scrolling.ScrollPadding[1])==4 and px(scrolling.ScrollPadding[2])==5 and px(scrolling.ScrollMargin[3])==7)
	local control=resolve("appearance:none;caret:#ff0000 block")
	assert(control.Appearance=="none" and control.CaretShape=="block" and control.CaretColor==Color3.new(1,0,0))
	local flow=resolve("float:right;clear:both;columns:3 80px;column-rule:2px solid blue;column-span:all;line-clamp:2")
	assert(flow.Float=="right" and flow.Clear=="both" and flow.ColumnCount==3 and px(flow.ColumnWidth)==80)
	assert(flow.ColumnRuleWidth==2 and flow.ColumnRuleStyle=="solid" and flow.ColumnSpan=="all" and flow.MaxLines==2)
	local browserClamp=resolve("line-clamp:3;-webkit-line-clamp:3;display:-webkit-box;-webkit-box-orient:vertical")
	assert(browserClamp.MaxLines==3 and browserClamp.Display=="block")
	local containment=resolve("container:card / inline-size;contain:layout paint;content-visibility:auto;contain-intrinsic-size:120px")
	assert(containment.ContainerType=="inline-size" and containment.ContainerNames[1]=="card" and containment.Contain.Paint)
	local effects=resolve('clip-path:circle(45% at center);mask-image:linear-gradient(to right,transparent,black);mix-blend-mode:multiply;backdrop-filter:blur(8px) brightness(90%)')
	assert(effects.ClipPath.Kind=="circle" and effects.MaskImage.EndAlpha==1 and effects.MixBlendMode=="multiply" and effects.BackdropFilter.Blur==8)
	local polygon=resolve('clip-path:polygon(20% 0,80% 0,100% 35%,85% 100%,15% 100%,0 35%)')
	assert(polygon.ClipPath.Kind=="polygon" and #polygon.ClipPath.Points==6)
	local gradientBorder=resolve('border-image-source:linear-gradient(105deg,#7541c3,#e85188,#f59249)')
	assert(gradientBorder.BorderImageSource.Kind=="gradient" and gradientBorder.BorderImageSource.Angle==105
		and #gradientBorder.BorderImageSource.Stops==3)
	local blended=Style.resolve(fixtureElement("div",{style="color:white;background:#7140bd;mix-blend-mode:multiply"}), {Font="Roboto",FontSize=20,Color=Color3.new(0,0,0),Background=Color3.fromRGB(240,170,119)}, error)
	assert(blended.Color==Color3.new(1,1,1) and blended.Background==Color3.fromRGB(113,64,189),"Computed colors must retain their specified values; blending belongs to painting")
	local difference=Style.resolve(fixtureElement("div",{style="color:white;mix-blend-mode:difference"}),
		{Font="Roboto",FontSize=20,Color=Color3.new(0,0,0),Background=Color3.fromRGB(240,170,119)},error)
	assert(difference.MixBlendMode=="difference" and difference.Color==Color3.new(1,1,1),
		"difference must not substitute the computed text color with the parent's backdrop")
	local advancedMotion=resolve('offset-path:path("M 0 0 L 100 0");offset-distance:50%;offset-rotate:auto;perspective:500px;transform:rotateY(30deg);animation-timeline:scroll()')
	assert(advancedMotion.OffsetPath.Kind=="line" and advancedMotion.OffsetDistance.Value==50 and advancedMotion.Perspective.Value==500 and advancedMotion.AnimationTimeline[1]=="scroll()")
	assert(advancedMotion.Transform[1].Kind=="tilt" and advancedMotion.Transform[1].Axis=="y" and advancedMotion.Transform[1].Value==30)
	local extended=resolve('background-attachment:local,fixed;scroll-behavior:smooth;scrollbar-gutter:stable both-edges;shape-outside:circle(50% at center);shape-margin:8px;mask-position:center;mask-size:50% 100%;mask-repeat:no-repeat;ruby-align:start;ruby-position:under;font-size:20px;font-size-adjust:.6;font-kerning:none;font-variant-caps:small-caps;font-variant-position:super;transform-box:content-box;animation-composition:add;transition-behavior:allow-discrete')
	assert(extended.BackgroundAttachments[1]=="local" and extended.BackgroundAttachments[2]=="fixed")
	assert(extended.ScrollBehavior=="smooth" and extended.ScrollbarGutter.Stable and extended.ScrollbarGutter.BothEdges)
	assert(extended.ShapeOutside.Kind=="circle" and extended.ShapeMargin.Value==8)
	assert(extended.MaskPositions[1].X.Anchor==.5 and extended.MaskSizes[1].X.Percent and extended.MaskRepeats[1].X=="no-repeat")
	assert(extended.RubyAlign=="start" and extended.RubyPosition=="under")
	assert(extended.UnadjustedFontSize==20 and extended.FontSize==24 and extended.FontKerning==false)
	assert(extended.OpenTypeFeatures:find("smcp 1",1,true) and extended.OpenTypeFeatures:find("sups 1",1,true) and extended.OpenTypeFeatures:find("kern 0",1,true))
	assert(extended.TransformBox=="content-box" and extended.AnimationComposition[1]=="add" and extended.TransitionBehavior[1]=="allow-discrete")
	local offset=resolve('offset:path("M 0 0 L 100 0") 25% auto / left top;offset-position:right bottom')
	assert(offset.OffsetPath.Kind=="line" and offset.OffsetDistance.Value==25 and offset.OffsetAnchor.X.Value==0 and offset.OffsetPosition.X.Value==100)
	local nextFeatures=resolve('anchor-name:--card;position-anchor:--card;position-area:right span-bottom;line-break:anywhere;hanging-punctuation:last;text-autospace:no-autospace;mask-origin:content-box;mask-clip:padding-box;mask-composite:exclude;mask-border:linear-gradient(to right,transparent,black);border-image-outset:2 3 4 5;corner-shape:squircle;scroll-marker-group:after;animation-trigger:scroll()')
	assert(nextFeatures.AnchorNames[1]=="--card" and nextFeatures.PositionAnchor=="--card" and nextFeatures.PositionArea=="right span-bottom")
	assert(nextFeatures.LineBreak=="anywhere" and nextFeatures.HangingPunctuation=="last" and nextFeatures.TextAutospace=="no-autospace")
	assert(nextFeatures.MaskOrigins[1]=="content-box" and nextFeatures.MaskClips[1]=="padding-box" and nextFeatures.MaskComposite=="exclude" and nextFeatures.MaskBorderSource)
	local webkitMask=resolve('-webkit-mask-box-image:linear-gradient(to right,transparent,black)')
	assert(webkitMask.MaskBorderSource and webkitMask.MaskBorderSource.EndAlpha==1,"WebKit mask-box-image must map to the supported mask-border source")
	local filledMask=resolve('mask-border-source:linear-gradient(to right,transparent,black);mask-border-slice:0 fill;mask-border-width:0;mask-border-repeat:stretch')
	assert(filledMask.MaskBorderSource and filledMask.MaskBorderSlice.Fill and filledMask.MaskBorderSlice[1]==0 and filledMask.MaskBorderWidth[1]==0 and filledMask.MaskBorderRepeat=="stretch",
		"The zero-width filled mask border uses the existing full-surface alpha mask")
	assert(nextFeatures.BorderImageOutset[1]==2 and nextFeatures.BorderImageOutset[4]==5 and nextFeatures.CornerShape=="squircle")
	assert(nextFeatures.ScrollMarkerGroup=="after" and nextFeatures.AnimationTimeline[1]=="scroll()")
	for _,name in {"hyphens","quotes","writing-mode","scroll-snap-type","overscroll-behavior","appearance","caret","columns","float","clear","line-clamp","contain","container","content-visibility","clip-path","mask-image","border-image","mix-blend-mode","backdrop-filter","offset-path","perspective","animation-timeline","background-attachment","scroll-behavior","scrollbar-gutter","shape-outside","shape-margin","mask-position","mask-size","mask-repeat","ruby-align","ruby-position","font-size-adjust","font-kerning","font-variant-caps","font-variant-position","transform-box","offset","offset-anchor","offset-position","animation-composition","transition-behavior","anchor-name","position-anchor","position-area","line-break","hanging-punctuation","text-autospace","mask-origin","mask-clip","mask-composite","mask-border-source","mask-border","border-image-outset","corner-shape","scroll-marker-group","animation-trigger"} do
		assert(Properties[name] and Properties[name].Support=="supported")
	end

	local function create(class: string,host: any,props: any): any
		local gui=table.clone(props);gui.ClassName=class;gui.Parent=host
		function gui:Destroy() self.Destroyed=true end
		return gui
	end
	local rasterAllocations=0
	local function createImage(size: any): any
		rasterAllocations+=1
		local image={Size=size}
		function image:WritePixelsBuffer(_: any,_: any,pixels: buffer) self.Pixels=pixels end
		function image:Destroy() self.Destroyed=true end
		return image
	end
	local measure={measure=function(value: string, _: any, size: number): any return {X=(utf8.len(value) or 0)*5,Y=size} end}
	local overrides={ ["Layout/TextMeasure"]=measure, ["Layout/FontProfiles"]={face=function(font: any)return font end} }
	local words=loadWordLayout(overrides);overrides["Layout/WordLayout"]=words
	local blocks=loadBlockLayout(overrides)
	local renderer=loadRenderTree({create=create,modifier=create,createImage=createImage})
	local function build(source: string): (any,{[string]:any})
		local tree=renderer.build(Parser.parse('<div style="font-family:Roboto;font-size:20px;line-height:20px">'..source..'</div>'),{},error,function(font: any)return font end)
		local ids={};local pending={tree}
		while #pending>0 do local box=table.remove(pending);if box.Node and box.Node.Attributes and box.Node.Attributes.id then ids[box.Node.Attributes.id]=box end;for _,child in box.Children or {} do table.insert(pending,child) end end
		return tree,ids
	end
	local function arrange(tree: any,width: number): number return blocks.arrange(tree,width,0,0,function()return true end) end

	local floatTree,floatIds=build('<div id="host"><div id="float" style="float:left;width:30px;height:30px"></div><div id="beside" style="height:10px">AB</div><div id="clear" style="clear:both;height:10px">CD</div></div>')
	arrange(floatTree,100)
	assert(floatIds.float.LayoutX==0 and floatIds.beside.LayoutX==0 and floatIds.beside.Children[1].Items[1].X>=30,"ordinary block boxes stay full-width while their inline text uses the remaining float band")
	assert(floatIds.clear.LayoutY>=30,"clear:both must move below the active float")
	local shapeTree,shapeIds=build('<div><div style="float:left;width:100px;height:100px;shape-outside:circle(50% at center);shape-margin:4px"></div><div id="shape-top" style="height:10px">top</div><div id="shape-middle" style="height:45px"></div><div id="shape-band" style="height:10px">middle</div></div>')
	arrange(shapeTree,240)
	assert(shapeIds["shape-top"].Children[1].Items[1].X<shapeIds["shape-band"].Children[1].Items[1].X and shapeIds["shape-band"].Children[1].Items[1].X>=99,"circle shape must use each complete line band, exposing corners while reserving the middle")
	local gutterTree,gutterIds=build('<div id="gutter" style="width:100px;height:60px;overflow:auto;scrollbar-gutter:stable both-edges"><div style="height:20px"></div></div>')
	arrange(gutterTree,150);assert(gutterIds.gutter.ScrollY==20,"stable both-edges must reserve two thin-side gutters")
	local rubyTree,rubyIds=build('<p><ruby id="ruby-under" style="ruby-position:under;ruby-align:start">漢<rt id="ruby-note">kan</rt></ruby></p>')
	arrange(rubyTree,200);assert(rubyIds["ruby-under"].Style.TextAlign=="start" and rubyIds["ruby-note"].Style.GridRowStart.Number==2)
	local columnTree,columnIds=build('<div id="columns" style="column-count:2;column-gap:10px;column-rule:2px solid blue"><div id="a" style="height:20px"></div><div id="b" style="height:20px"></div><div id="c" style="height:20px"></div><div id="d" style="height:20px"></div></div>')
	arrange(columnTree,110)
	assert(columnIds.a.LayoutX==0 and columnIds.c.LayoutX>columnIds.a.LayoutX,"direct blocks must distribute over columns")
	assert(columnIds.columns.ColumnRules and columnIds.columns.ColumnRules[1].Visible)
	local clampTree,clampIds=build('<div id="clamp" style="line-clamp:2">AA BB CC DD EE FF</div>')
	arrange(clampTree,30)
	local clampRun=clampIds.clamp.Children[1]
	for _,item in clampRun.DisplayItems or clampRun.Items do assert(item.LineIndex<=2) end
	assert(clampRun.EllipsisPool and clampRun.EllipsisPool[2] and clampRun.EllipsisPool[2].Gui.Visible)
	local verticalTree,verticalIds=build('<div id="vertical" style="writing-mode:vertical-rl;width:40px;height:20px">AB</div>')
	arrange(verticalTree,100);assert((verticalIds.vertical.Gui.Rotation or 0)==0 and verticalIds.vertical.Children[1].Items[1].Gui.Rotation==90)
	local atomicTree,atomicIds=build('<div id="atomic-host" style="width:200px"><span id="atomic-a" style="display:inline-block;width:44%;box-sizing:border-box;padding:8px">A</span><span id="atomic-b" style="display:inline-block;width:44%;box-sizing:border-box;padding:8px">B</span></div>')
	arrange(atomicTree,240)
	assert(math.abs(atomicIds["atomic-a"].OuterWidth-88)<.01 and math.abs(atomicIds["atomic-b"].OuterWidth-88)<.01,"inline-block percentage width must resolve once against its containing line")
	assert(atomicIds["atomic-b"].LayoutX>=atomicIds["atomic-a"].LayoutX+88,"percentage inline-block siblings must retain their horizontal placement")
	local overTree,overIds=build('<div id="over" style="overflow:auto;overscroll-behavior:none;width:50px;height:20px"><div style="height:100px"></div></div>')
	arrange(overTree,100);assert(overIds.over.ScrollGui and overIds.over.ScrollGui.ElasticBehavior==Enum.ElasticBehavior.Never)
	local snapTree,snapIds=build('<div id="snap" style="overflow:auto;scroll-snap-type:y mandatory;width:60px;height:20px"><div id="s1" style="height:20px;scroll-snap-align:start"></div><div id="s2" style="height:20px;scroll-snap-align:start"></div></div>')
	arrange(snapTree,100);snapIds.snap.ScrollGui.CanvasPosition=Vector2.new(0,17);assert(ScrollLayout.snap(snapIds.snap,true));assert(snapIds.snap.ScrollGui.CanvasPosition.Y==20)
	local tweenTarget
	snapIds.snap.ScrollGui.CanvasPosition=Vector2.new(0,17)
	snapIds.snap.TweenService={Create=function(_: any,gui: any,_: any,goal: any): any tweenTarget=goal.CanvasPosition;return {Play=function()gui.CanvasPosition=goal.CanvasPosition end,Cancel=function()end} end}
	assert(ScrollLayout.snap(snapIds.snap) and tweenTarget.Y==20 and snapIds.snap.ScrollGui.CanvasPosition.Y==20)
	local markerTree,markerIds=build('<style>#markers>div::scroll-marker{content:"●";color:#8fa5b7;padding:4px}#markers>div::scroll-marker:target-current{color:#246fa8}</style><div id="markers" style="overflow:auto;scroll-snap-type:y mandatory;scroll-marker-group:after;width:60px;height:20px"><div style="height:20px;scroll-snap-align:start"></div><div style="height:20px;scroll-snap-align:start"></div></div>')
	arrange(markerTree,100);assert(markerIds.markers.ScrollMarkerGui and #markerIds.markers.ScrollMarkers==2 and markerIds.markers.ScrollMarkers[1].Visible)
	assert(markerIds.markers.ScrollMarkers[1].Text=="●" and markerIds.markers.ScrollMarkers[1].TextColor3==Color3.fromRGB(36,111,168))
	assert(markerIds.markers.ScrollMarkers[2].TextColor3==Color3.fromRGB(143,165,183))
	markerIds.markers.ScrollGui.CanvasPosition=Vector2.new(0,20);ScrollLayout.refreshMarkers(markerIds.markers)
	assert(markerIds.markers.ScrollMarkers[2].TextColor3==Color3.fromRGB(36,111,168))
	local anchorTree,anchorIds=build('<div style="position:relative;width:200px;height:80px"><div id="anchor" style="anchor-name:--card;width:40px;height:20px"></div><div id="anchored" style="position:absolute;position-anchor:--card;position-area:right;width:20px;height:10px"></div></div>')
	arrange(anchorTree,220);assert(math.abs(anchorIds.anchored.PaintX-40)<.01 and math.abs(anchorIds.anchored.PaintY-5)<.01,"position-area right must center the box beside the anchor")
	local spanTree,spanIds=build('<div style="position:relative;width:200px;height:80px"><div id="span-anchor" style="anchor-name:--span;width:40px;height:20px"></div><div id="span-positioned" style="position:absolute;position-anchor:--span;position-area:right span-bottom;width:20px;height:10px"></div></div>')
	arrange(spanTree,220);assert(math.abs(spanIds["span-positioned"].PaintY)<.01,"right span-bottom must align to the anchor top edge")
	local textTree,textIds=build('<p id="autospace">東京HTML</p><p id="hanging" style="hanging-punctuation:first">&quot;quote</p>')
	arrange(textTree,180);local autoItems=textIds.autospace.Children[1].Items;assert(#autoItems==2 and autoItems[2].AutoSpaceBefore and autoItems[2].SpaceWidth>0)
	assert(textIds.hanging.Children[1].Items[1].HangingFirst and textIds.hanging.Children[1].Items[1].X<0)
	local containerTree,containerIds=build('<style>@container card (min-width:200px){#inside{background:#ff0000}}</style><div id="query" style="container:card / inline-size;width:240px"><div id="inside" style="height:10px"></div></div>')
	arrange(containerTree,300);assert(containerIds.inside.Style.Background==Color3.new(1,0,0))
	local hiddenTree,hiddenIds=build('<div id="hidden" style="contain:size paint;content-visibility:hidden;contain-intrinsic-width:80px;contain-intrinsic-height:30px"><div id="never-built"></div></div>')
	arrange(hiddenTree,200);assert(hiddenIds.hidden.OuterWidth==80 and hiddenIds.hidden.OuterHeight==30 and hiddenIds["never-built"]==nil)
	local paintTree,paintIds=build('<div id="paint" style="position:relative;contain:paint;width:100px;height:60px;border:2px solid green;padding:4px"><span id="label" style="position:relative;z-index:1">Label</span><i id="shape" style="position:absolute;right:-10px;bottom:-10px;width:30px;height:30px;background:orange;transform:rotate(24deg)"></i></div>')
	arrange(paintTree,150)
	assert(paintIds.paint.PaintContent and paintIds.paint.PaintClip.Position[1]==2 and paintIds.paint.PaintClip.Position[2]==2,"paint containment must start inside the border")
	assert(paintIds.paint.PaintClip.Size[1]==paintIds.paint.OuterWidth-4 and paintIds.paint.PaintClip.Size[2]==paintIds.paint.OuterHeight-4,"paint containment must end inside the opposite border")
	assert(paintIds.shape.Gui.Parent==paintIds.paint.PaintContent and paintIds.paint.PaintContent.Position[1]==-2,"clipped descendants must retain border-box layout coordinates")
	assert(paintIds.label.Gui.ZIndex>paintIds.shape.Gui.ZIndex,"positioned inline text must paint over a later absolute sibling")
	local effectTree,effectIds=build('<div id="clip" style="width:80px;height:40px;padding:4px;clip-path:ellipse(50% 50% at center);mask-image:linear-gradient(to right,transparent,black);mask-origin:content-box;mask-clip:padding-box;mask-composite:exclude"><div id="clipped-child" style="position:absolute;left:60px;top:20px;width:100px;height:60px;transform:rotate(18deg)"></div></div><div id="shape-row" style="display:flex"><div id="squircle" style="width:80px;height:40px;background:green;border:2px solid blue;border-radius:18px;corner-shape:squircle"></div></div><div id="border-image" style="width:100px;height:40px;border:2px solid transparent;border-image-source:linear-gradient(to right,red,blue);border-image-slice:1;border-image-width:6;border-image-outset:4"></div>')
	arrange(effectTree,200);assert(effectIds.clip.Gui.ClipsDescendants and effectIds.clip.PaintClip and effectIds.clip.ClipPathMask and not effectIds.clip.ClipCorner and effectIds.clip.OpacityGroup and effectIds.clip.OpacityGroup.Mask)
	assert(effectIds["clipped-child"].Gui.Parent==effectIds.clip.PaintClip,"rotated descendants must remain under the CanvasGroup clip surface")
	assert(effectIds["border-image"].BorderImageGradient and effectIds["border-image"].BorderImageGradient.ImageContent,"gradient border-image must use a raster image")
	assert(effectIds["border-image"].BorderImageGradient.Position[1]==-8 and effectIds["border-image"].BorderImageGradient.Size[1]==effectIds["border-image"].OuterWidth+16,"unitless border-image-outset must scale the corresponding border widths")
	assert(effectIds["shape-row"].Gui.ZIndex>effectIds["border-image"].Gui.ZIndex,"flex contents must paint above an overlapping in-flow border-image outset")
	assert(effectIds.squircle.Style.CornerShape=="squircle" and not effectIds.squircle.Style.NativeCornerRadii,"corner-shape must select the raster rounded-surface path")
	assert(rasterAllocations>=2,"clip-path and gradient border-image must allocate EditableImages")
	local clipGui,borderGui=effectIds.clip.ClipPathMask,effectIds["border-image"].BorderImageGradient
	effectIds.clip.VisualEffects:Draw(effectIds.clip,90,45);effectIds["border-image"].VisualEffects:Draw(effectIds["border-image"],110,45)
	assert(effectIds.clip.ClipPathMask==clipGui and not clipGui.Destroyed and effectIds["border-image"].BorderImageGradient==borderGui and not borderGui.Destroyed,"effect resize must retain its ImageLabels while replacing pixel allocations")
	local perspectiveTree,perspectiveIds=build('<div style="perspective:420px;transform-style:preserve-3d"><div id="perspective-front" style="display:inline-block;width:80px;height:40px;background:blue;color:white;transform:rotateY(48deg)">front</div><div id="perspective-back" style="display:inline-block;width:80px;height:40px;background:red;transform:rotateY(190deg);backface-visibility:hidden">back</div></div>')
	arrange(perspectiveTree,240)
	assert(perspectiveIds["perspective-front"].Scene3DRoot.Scene3DSurface and perspectiveIds["perspective-front"].Gui.Visible==false,"visible rotateY content must use the raster perspective surface")
	local perspectivePixels=perspectiveIds["perspective-front"].Scene3DRoot.Scene3DSurface.ImageContent.Pixels
	local antialiased=false
	for offset=3,buffer.len(perspectivePixels)-1,4 do local alpha=buffer.readu8(perspectivePixels,offset);if alpha>0 and alpha<255 then antialiased=true;break end end
	assert(antialiased,"perspective raster edges must contain antialiasing coverage")
	assert(perspectiveIds["perspective-back"].Gui.Visible==false,"backface-visibility hidden must hide a reversed atomic inline box")
	local originLeftTree,originLeftIds=build('<div style="width:240px;perspective:420px;perspective-origin:left center;transform-style:preserve-3d"><div id="origin-left" style="display:inline-block;width:80px;height:40px;background:blue;transform:rotateY(48deg)"></div></div>')
	local originRightTree,originRightIds=build('<div style="width:240px;perspective:420px;perspective-origin:right center;transform-style:preserve-3d"><div id="origin-right" style="display:inline-block;width:80px;height:40px;background:blue;transform:rotateY(48deg)"></div></div>')
	arrange(originLeftTree,240);arrange(originRightTree,240)
	local leftSurface,rightSurface=originLeftIds["origin-left"].Scene3DRoot.Scene3DSurface,originRightIds["origin-right"].Scene3DRoot.Scene3DSurface
	assert(leftSurface and rightSurface and rightSurface.Position[1]<leftSurface.Position[1],"perspective-origin must move the projected raster around the parent vanishing point")
	assert(leftSurface.Size[1]~=80 and rightSurface.Size[1]~=80,"perspective raster must use its projected bounds instead of the untransformed box bounds")
	local pathTree,pathIds=build('<div id="path" style="width:20px;height:20px;offset-path:path(&quot;M 0 0 L 100 0&quot;);offset-distance:50%;offset-rotate:auto"></div>')
	arrange(pathTree,200)
	assert(pathIds.path.TransformApplied and math.abs(pathIds.path.Gui.Position[1]-50)<.001 and math.abs(pathIds.path.Gui.Position[2])<.001,"offset-path must place the element anchor directly on the path point")
	print("CSS expansion: text, scrolling, flow, containment, effects and advanced motion passed")
end
