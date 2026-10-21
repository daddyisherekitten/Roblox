--!strict
return function(Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css: string, report: any?): any
		return Style.resolve(fixtureElement("div",{style=css}), {FontSize=16}, report or error)
	end
	local timeline=resolve("scroll-timeline: --first x, --second y")
	assert(timeline.ScrollTimelineNames[1]=="--first" and timeline.ScrollTimelineNames[2]=="--second")
	assert(timeline.ScrollTimelineAxes[1]=="x" and timeline.ScrollTimelineAxes[2]=="y")
	assert(resolve("scroll-timeline: --first x; scroll-timeline: initial").ScrollTimelineNames[1]=="none")
	assert(resolve("scroll-timeline: --first x; scroll-timeline-axis: inline").ScrollTimelineAxis=="inline")
	local warnings=0
	local invalid=resolve("scroll-timeline: --first x; scroll-timeline: bogus",function() warnings+=1 end)
	assert(warnings==1 and invalid.ScrollTimelineNames[1]=="--first")
	warnings=0
	resolve("scroll-timeline: , --first; scroll-timeline-name: --first,,--second",function() warnings+=1 end)
	assert(warnings==2,"Malformed timeline lists are rejected")
	assert(resolve("overflow: clip").OverflowX=="clip")
	assert(resolve("overflow-anchor:none;scroll-initial-target:nearest").OverflowAnchor=="none")
	assert(resolve("overflow-anchor:none;scroll-initial-target:nearest").ScrollInitialTarget=="nearest")
	assert(resolve("overflow-x: clip; overflow-y: scroll").OverflowX=="hidden")
	local margins=resolve("direction: rtl; overflow-clip-margin: 4px; overflow-clip-margin-inline-start: 7px")
	assert(margins.OverflowClipMargins[1].Offset.Value==4 and margins.OverflowClipMargins[2].Offset.Value==7)
	assert(margins.OverflowClipMargins[4].Offset.Value==4)
	local vertical=resolve("overflow-clip-margin: 4px; overflow-clip-margin-block-start: 9px; writing-mode: vertical-rl")
	assert(vertical.OverflowClipMargins[2].Offset.Value==9 and vertical.OverflowClipMargins[4].Offset.Value==4)
	assert(resolve("overflow-clip-margin: calc(2px + 2px) border-box").OverflowClipMargins[1].Offset.Value==4)
	for _,name in {"overflow-clip-margin","overflow-clip-margin-top","overflow-clip-margin-right",
		"overflow-clip-margin-bottom","overflow-clip-margin-left","overflow-clip-margin-block",
		"overflow-clip-margin-inline","overflow-clip-margin-block-start","overflow-clip-margin-block-end",
		"overflow-clip-margin-inline-start","overflow-clip-margin-inline-end"} do
		local count=0
		resolve("overflow:clip;"..name..":4px",function() count+=1 end)
		assert(count==0,name.." must be accepted without a warning")
	end
	local reset=resolve("overflow-clip-margin: 4px; overflow-clip-margin-left: initial")
	assert(reset.OverflowClipMargins[4].Offset.Value==0 and reset.OverflowClipMargins[1].Offset.Value==4)
	local renderer=loadRenderTree({create=function(class, parent, props)
		local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent;return gui
	end})
	local words=loadWordLayout({["Layout/FontProfiles"]={face=function(font)return font end},
		["Layout/TextMeasure"]={measure=function(text,_,size)return {X=utf8.len(text)*size*.5,Y=size}end}})
	local layout=loadBlockLayout({["Layout/WordLayout"]=words})
	local function build(html: string): any return renderer.build(Parser.parse(html),{},error) end
	local function arrange(tree: any): any return layout.arrange(tree,200,0,0,function()return true end) end
	local clip=build('<div style="width:100px;height:60px;box-sizing:border-box;padding:5px;border:2px solid;overflow:clip;overflow-clip-margin:4px"><div style="height:120px"></div></div>')
	arrange(clip)
	local box=clip.Children[1]
	assert(box.ScrollGui==nil and box.OverflowClip and box.OverflowContent)
	assert(box.OverflowClip.Position[1]==-2 and box.OverflowClip.Position[2]==-2)
	assert(box.OverflowClip.Size[1]==104 and box.OverflowClip.Size[2]==64)
	assert(box.Children[1].Gui.Parent==box.OverflowContent)
	local initial=build('<div style="height:40px;overflow:auto"><div style="height:70px"></div><div style="height:20px;scroll-initial-target:nearest"></div><div style="height:80px"></div></div>')
	arrange(initial)
	box=initial.Children[1]
	assert(box.ScrollGui.CanvasPosition.Y==70,"Initial target aligns at the block start")
	box.ScrollGui.CanvasPosition=Vector2.new(0,10)
	arrange(initial)
	assert(box.ScrollGui.CanvasPosition.Y==10,"An initial target only applies once")
	local nested=build('<div style="height:40px;overflow:auto"><div style="height:45px"></div><div><div style="height:25px;scroll-initial-target:nearest"></div></div><div style="height:100px"></div></div>')
	arrange(nested)
	assert(nested.Children[1].ScrollGui.CanvasPosition.Y==45,"Nested initial target uses the nearest outer scroll container")
	local anchored=build('<div style="height:40px;overflow:auto"><div style="height:60px"></div><div style="height:20px"></div><div style="height:100px"></div></div>')
	arrange(anchored)
	box=anchored.Children[1]
	box.ScrollGui.CanvasPosition=Vector2.new(0,70)
	box.Children[1].Style.Height.Value=80
	arrange(anchored)
	assert(box.ScrollGui.CanvasPosition.Y==90,"Reflow above the visible anchor keeps its screen position")
	box.Style.OverflowAnchor="none"
	box.Children[1].Style.Height.Value=100
	arrange(anchored)
	assert(box.ScrollGui.CanvasPosition.Y==90,"overflow-anchor:none disables compensation")
	local excluded=build('<div style="height:40px;overflow:auto"><div style="height:60px"></div><div style="overflow-anchor:none;height:20px"></div><div style="height:100px"></div></div>')
	arrange(excluded)
	box=excluded.Children[1]
	box.ScrollGui.CanvasPosition=Vector2.new(0,70)
	box.Children[1].Style.Height.Value=80
	arrange(excluded)
	assert(box.ScrollGui.CanvasPosition.Y==90,"An excluded subtree cannot be chosen as anchor, but another visible node can")
	print("Scroll features: shorthand, clip geometry, initial target and reflow anchor passed")
end
