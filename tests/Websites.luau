--!strict
return function(mainHTML: string,mainCSS: string,backgroundHTML: string,backgroundCSS: string,transformsHTML: string,transformsCSS: string,visualHTML: string,visualCSS: string,textHTML: string,textCSS: string,scrollHTML: string,scrollCSS: string,flowHTML: string,flowCSS: string,containmentHTML: string,containmentCSS: string,effectsHTML: string,effectsCSS: string,motionHTML: string,motionCSS: string,fontHTML: string,fontCSS: string,counterHTML: string,counterCSS: string,extendedHTML: string,extendedCSS: string,nextHTML: string,nextCSS: string,notFoundHTML: string,notFoundCSS: string,Parser: any,loadRenderTree: any)
	local renderer=loadRenderTree({create=function(_,_,props)return table.clone(props)end,modifier=function(_,_,props)return table.clone(props)end})
	local function build(source: string,sheet: string): (any,any)
		local document=Parser.parse(source);assert(#document.Diagnostics==0)
		local diagnostics={}
		local tree=renderer.build(document,{AbsoluteSize={X=800,Y=600}},function(message)table.insert(diagnostics,message)end,nil,nil,nil,function()return "rbxassetid://1" end,nil,nil,nil,nil,nil,{["styles.css"]=sheet})
		assert(#diagnostics==0,diagnostics[1])
		local boxes={};local pending={tree}
		while #pending>0 do
			local box=table.remove(pending)
			if box.Node and box.Node.Attributes and box.Node.Attributes.id then boxes[box.Node.Attributes.id]=box end
			for _,child in box.Children or {} do table.insert(pending,child) end
		end
		return boxes,tree
	end

	local mainBoxes,mainTree=build(mainHTML,mainCSS)
	assert(mainBoxes.top and mainBoxes["css-background-position-card"] and mainBoxes["css-individual-transforms-card"] and mainBoxes["css-visual-properties-card"] and mainBoxes["css-text-advanced-card"] and mainBoxes["css-scroll-input-card"] and mainBoxes["css-flow-layout-card"])
	assert(mainBoxes["css-containment-card"] and mainBoxes["css-effects-card"] and mainBoxes["css-advanced-motion-card"] and mainBoxes["css-font-features-card"] and mainBoxes["css-counters-card"] and mainBoxes["css-extended-card"] and mainBoxes["css-next-features-card"])
	assert(#mainTree.Links==16 and #mainTree.Controls==0)

	local backgroundBoxes,backgroundTree=build(backgroundHTML,backgroundCSS)
	assert(backgroundBoxes["right-center"] and backgroundBoxes["center-bottom"] and backgroundBoxes["left-top"])
	assert(backgroundBoxes["right-center"].Style.BackgroundPositions[1].X.Anchor==1)
	assert(backgroundBoxes["center-bottom"].Style.BackgroundPositions[1].Y.Anchor==1)
	assert(#backgroundTree.Links==5 and #backgroundTree.Controls==0)

	local transformBoxes,transformTree=build(transformsHTML,transformsCSS)
	assert(transformBoxes.translated.Style.Translate and transformBoxes.translated.Style.Translate.Kind=="translate")
	assert(transformBoxes.rotated.Style.Rotate and transformBoxes.rotated.Style.Rotate.Kind=="rotate")
	assert(transformBoxes.scaled.Style.Scale and transformBoxes.scaled.Style.Scale.Kind=="scale")
	assert(transformBoxes.combined.Style.Transform and #transformBoxes.combined.Style.Transform==1)
	assert(#transformTree.Links==5 and #transformTree.Controls==0)

	local visualBoxes,visualTree=build(visualHTML,visualCSS)
	assert(visualBoxes["accent-sample"].Style.AccentColor==Color3.fromRGB(192,38,211))
	assert(visualBoxes["scrollbar-sample"].Style.ScrollbarWidth=="thin" and visualBoxes["scrollbar-sample"].Style.ScrollbarColor.Thumb==Color3.fromRGB(109,40,217))
	local pixelated
	for _,item in visualTree.ImageItems do if item.Node.Attributes.id=="pixelated-image" then pixelated=item end end
	assert(pixelated and pixelated.Style.ImageRendering=="pixelated")
	assert(visualBoxes["wrapped-text"].Style.WhiteSpace=="normal" and visualBoxes["nowrap-text"].Style.WhiteSpace=="nowrap")
	assert(visualBoxes["justified-text"].Style.TextJustify=="inter-word" and visualBoxes["underlined-text"].Style.UnderlinePosition=="under")
	assert(#visualTree.Links==5 and #visualTree.Controls==4)

	local textBoxes,textTree=build(textHTML,textCSS)
	assert(textBoxes["hyphen-auto"].Style.Hyphens=="auto" and textBoxes["hyphen-custom"].Style.HyphenateCharacter=="~")
	assert(textBoxes["emphasis-over"].Style.TextEmphasisStyle and textBoxes["quote-sample"].Style.Quotes[1][1]=="«")
	assert(textBoxes["vertical-rl"].Style.WritingMode=="vertical-rl" and #textTree.Links==5)
	local scrollBoxes,scrollTree=build(scrollHTML,scrollCSS)
	assert(scrollBoxes["vertical-snap"].Style.ScrollSnapType.Axis=="y" and scrollBoxes["horizontal-snap"].Style.ScrollSnapType.Axis=="x")
	assert(scrollBoxes["overscroll-sample"].Style.OverscrollX=="none" and scrollBoxes["custom-control"].Style.Appearance=="none")
	local customInput
	for _,control in scrollTree.Controls do if control.Node.Attributes.id=="custom-control" then customInput=control end end
	assert(customInput and customInput.Type=="text" and customInput.Item.Editor,"appearance:none must retain the real editable TextBox")
	assert(#scrollTree.Links==5 and #scrollTree.Controls==3)
	local flowBoxes,flowTree=build(flowHTML,flowCSS)
	assert(flowBoxes["columns-sample"].Style.ColumnCount==2 and flowBoxes["float-sample"])
	assert(flowBoxes["clamp-sample"].Style.MaxLines==3 and #flowTree.Links==5)

	local containmentBoxes,containmentTree=build(containmentHTML,containmentCSS)
	assert(containmentBoxes["query-container"].Style.ContainerType=="inline-size")
	assert(containmentBoxes["query-result"].Style.Background==Color3.fromRGB(215,226,223),"matching named max-width query must use the gray result color")
	assert(containmentBoxes["paint-container"].Style.Contain.Paint and containmentBoxes["paint-container"].Gui.ClipsDescendants)
	assert(containmentBoxes["paint-container"].PaintClip and containmentBoxes["paint-container"].PaintClip.ClipsDescendants)
	assert(containmentBoxes["hidden-content"].Style.ContentVisibility=="hidden" and #containmentTree.Links==5)

	local effectsBoxes,effectsTree=build(effectsHTML,effectsCSS)
	assert(effectsBoxes["border-image-sample"].Style.BorderImageSource.Kind=="gradient")
	assert(effectsBoxes["clip-sample"].Style.ClipPath.Kind=="ellipse" and effectsBoxes["clip-sample"].Gui.ClipsDescendants)
	assert(effectsBoxes["mask-sample"].Style.MaskImage and effectsBoxes["blend-sample"].Style.MixBlendMode=="multiply")
	assert(effectsBoxes["backdrop-sample"].Style.BackdropFilter.Blur==12 and #effectsTree.Links==5)

	local motionBoxes,motionTree=build(motionHTML,motionCSS)
	assert(motionBoxes["path-sample"].Style.OffsetPath.Kind=="line" and motionBoxes["path-sample"].Style.OffsetDistance.Value==25)
	assert(motionBoxes["path-sample"].Style.AnimationName[1]=="path-travel","motion path example must visibly animate its distance")
	assert(motionBoxes["perspective-stage"].Style.Perspective,"perspective property must reach the stage")
	assert(motionBoxes["perspective-sample"].Style.Transform and motionBoxes["perspective-sample"].Style.Transform[1],"rotateY declaration must reach the card")
	assert(motionBoxes["perspective-sample"].Style.Transform[1].Kind=="tilt" and motionBoxes["perspective-sample"].Style.Transform[1].Axis=="y")
	assert(motionBoxes["backface-sample"].Style.BackfaceVisibility=="hidden")
	assert(motionBoxes["timeline-scroll"].Style.ScrollTimelineNames[1]=="--card-scroll")
	assert(motionBoxes["timeline-sample"].Style.AnimationTimeline[1]=="--card-scroll" and #motionTree.Links==5)

	local fontBoxes,fontTree=build(fontHTML,fontCSS)
	assert(fontBoxes["numeric-zero"].Style.OpenTypeFeatures:find("zero 1",1,true))
	assert(fontBoxes["style-set"].Style.OpenTypeFeatures:find("ss03 1",1,true))
	assert(fontBoxes["no-ligatures"].Style.OpenTypeFeatures:find("liga 0",1,true) and fontBoxes["no-ligatures"].Style.OpenTypeFeatures:find("calt 0",1,true))
	local featureInput
	for _,control in fontTree.Controls do if control.Node.Attributes.id=="feature-input" then featureInput=control end end
	assert(featureInput and featureInput.Item.Editor.OpenTypeFeatures:find("zero 1",1,true) and featureInput.Item.Editor.OpenTypeFeatures:find("liga 0",1,true))
	assert(#fontTree.Links==5 and #fontTree.Controls==1)

	local counterBoxes,counterTree=build(counterHTML,counterCSS)
	assert(counterBoxes["chapter-sample"].Style.CounterReset[1].Name=="chapter")
	assert(counterBoxes["nested-sample"].Style.CounterReset[1].Name=="item")
	assert(counterBoxes["set-sample"].Style.CounterReset[1].Name=="step")
	assert(counterBoxes["marker-sample"] and #counterTree.Links==5 and #counterTree.Controls==0)

	local extendedBoxes,extendedTree=build(extendedHTML,extendedCSS)
	assert(extendedBoxes["attachment-sample"].Style.BackgroundAttachments[1]=="local")
	assert(extendedBoxes["gutter-sample"].Style.ScrollBehavior=="smooth" and extendedBoxes["gutter-sample"].Style.ScrollbarGutter.BothEdges)
	local shapeFloat=extendedBoxes["shape-sample"].Children[1]
	assert(shapeFloat.Style.ShapeOutside.Kind=="circle" and shapeFloat.Style.ShapeMargin.Value==8)
	assert(extendedBoxes["mask-advanced"].Style.MaskPositions[1].X.Anchor==.5 and extendedBoxes["mask-advanced"].Style.MaskRepeats[1].X=="no-repeat")
	assert(extendedBoxes["ruby-under"].Style.RubyPosition=="under" and extendedBoxes["ruby-under"].Style.RubyAlign=="start")
	assert(extendedBoxes["font-advanced"].Style.FontKerning==false and extendedBoxes["font-advanced"].Style.OpenTypeFeatures:find("smcp 1",1,true))
	assert(extendedBoxes["motion-advanced"].Style.TransformBox=="content-box" and extendedBoxes["motion-advanced"].Style.AnimationComposition[1]=="add")
	assert(#extendedTree.Links==6 and #extendedTree.Controls==0)

	local nextBoxes,nextTree=build(nextHTML,nextCSS)
	assert(nextBoxes["anchor-source"].Style.AnchorNames[1]=="--sample" and nextBoxes["anchor-popover"].Style.PositionAnchor=="--sample")
	assert(nextBoxes["autospace-sample"].Style.TextAutospace=="normal" and nextBoxes["hanging-sample"].Style.HangingPunctuation=="first" and nextBoxes["line-break-sample"].Style.LineBreak=="anywhere")
	assert(nextBoxes["mask-box-sample"].Style.MaskOrigins[1]=="content-box" and nextBoxes["mask-box-sample"].Style.MaskComposite=="exclude")
	assert(nextBoxes["mask-border-sample"].Style.MaskBorderSource and nextBoxes["squircle-sample"].Style.CornerShape=="squircle")
	assert(nextBoxes["border-outset-sample"].Style.BorderImageOutset[1]==8 and nextBoxes["marker-scroll"].Style.ScrollMarkerGroup=="after")
	assert(nextBoxes["trigger-sample"].Style.AnimationTimeline[1]=="scroll()" and #nextTree.Links==5 and #nextTree.Controls==0)

	local errorBoxes,errorTree=build(notFoundHTML,notFoundCSS)
	assert(errorBoxes["error-page"] and errorBoxes["error-home"] and errorBoxes["error-links"])
	assert(#errorTree.Links==2)
	print("Websites: Main, thirteen CSS subtests and the internal error page render from browser-native HTML/CSS")
end
