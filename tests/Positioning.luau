--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout, ViewportLayer)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css,parent,warn) return Style.resolve(fixtureElement('div',{style=css}),parent or {},warn or error) end
	local s=resolve('position:relative;left:-12.5px;top:25%;z-index:-2')
	assert(s.Position=='relative' and s.Insetleft.Value==-12.5 and s.Insettop.Percent and s.ZIndex==-2)
	local child=resolve('',s); assert(child.Position=='static' and child.Insetleft==nil and child.ZIndex==nil)
	assert(resolve('position:absolute!important;position:static').Position=='absolute')
	assert(resolve('left:5px;left:auto;z-index:2;z-index:auto').Insetleft==nil)
	assert(resolve('position:fixed').Position=='fixed' and resolve('position:sticky').Position=='sticky')
	assert(resolve('left:1ex').Insetleft.Value==8,'Font-relative inset uses the shared length parser')
	for _,css in {'right:100001px','top:1.2.3px','z-index:1.5','z-index:100001'} do
		local count=0; resolve(css,nil,function() count+=1 end); assert(count==1,css)
	end
	local objects,measurements=0,0
	local renderer=loadRenderTree({create=function(_,owner,props)
		objects+=1;local gui=table.clone(props);gui.Parent=owner
		function gui:Destroy()self.Parent=nil end
		return gui
	end})
	local overrides={['Layout/FontProfiles']={face=function(font) return font end},
		['Layout/TextMeasure']={measure=function(text,_,size) measurements+=1; return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local function near(a,b) assert(math.abs(a-b)<1e-5,tostring(a)..' != '..tostring(b)) end
	local function position(box,x,y) near(box.Gui.Position[1],x); near(box.Gui.Position[2],y) end
	local function arrange(tree,width) return layout.arrange(tree,width or 400,0,0,function() return true end) end
	local function build(html,width,resolveImage)
		local tree=renderer.build(Parser.parse(html),{},error,nil,nil,nil,resolveImage)
		tree.ViewportHeight=300
		local boxes={}
		local function collect(box,parent)
			box.TestParent=parent
			if box.Node and box.Node.Attributes and box.Node.Attributes.id then boxes[box.Node.Attributes.id]=box end
			for _,c in box.Children or {} do collect(c,box) end
		end
		collect(tree); arrange(tree,width); return tree,boxes
	end
	local function global(box)
		local x,y=box.Gui.Position[1],box.Gui.Position[2]
		local parent=box.TestParent
		while parent and parent.Node.Kind~='Document' do x+=parent.Gui.Position[1]; y+=parent.Gui.Position[2]; parent=parent.TestParent end
		return x,y
	end
	local tree,b=build('<div style="width:300px;height:100px;padding:10px;border:2px solid"><div id="relative" style="position:relative;left:10px;top:5px;width:20px;height:20px"></div><div id="next" style="height:10px"></div></div>')
	position(b.relative,22,17); position(b.next,12,32)
	local _,precedence=build('<div style="height:100px"><div id="x" style="position:relative;left:10%;right:90px;top:10%;bottom:80px;height:20px"></div></div>',200)
	position(precedence.x,20,10)
	local _,indefinite=build('<div><div id="x" style="position:relative;top:50%;right:10px;height:20px"></div></div>')
	position(indefinite.x,-10,0)
	local abs,a=build('<div id="card" style="position:relative;width:200px;height:100px;padding:10px;border:2px solid"><span id="badge" style="position:absolute;right:8px;top:6px;width:40px;height:20px">NEW</span><div id="flow" style="height:10px"></div></div>')
	position(a.badge,174,8); position(a.flow,12,12); near(a.card.OuterHeight,124)
	assert(#a.card.FlowChildren==1 and #a.card.Children==2)
	local count,reads=objects,measurements; arrange(abs,500); arrange(abs,400)
	assert(count==objects and reads==measurements); position(a.badge,174,8)
	local _,nested=build('<div style="position:relative;left:20px;width:200px;height:100px;padding:10px;border:2px solid"><div style="padding:5px"><div id="x" style="position:absolute;left:10px;top:15px;width:20px;height:10px"></div></div></div>')
	local gx,gy=global(nested.x); near(gx,32); near(gy,17)
	local _,stretch=build('<div style="position:relative;width:200px;height:100px;padding:10px;border:2px solid"><div id="x" style="position:absolute;left:10px;right:20px;top:5px;bottom:15px;padding:3px;border:1px solid"></div></div>')
	position(stretch.x,12,7); near(stretch.x.OuterWidth,190); near(stretch.x.OuterHeight,100)
	local _,center=build('<div style="position:relative;width:200px;height:100px"><div id="x" style="position:absolute;left:10px;right:10px;top:10px;bottom:10px;width:40px;height:20px;margin:auto"></div></div>')
	position(center.x,80,40)
	local _,shrink=build('<div style="position:relative;width:200px;height:100px"><div id="x" style="position:absolute;right:0;bottom:0;padding:5px;line-height:20px">AAAA</div></div>')
	near(shrink.x.OuterWidth,30); position(shrink.x,170,70)
	local _,limits=build('<div style="position:relative;width:200px;height:100px"><div id="x" style="position:absolute;left:0;right:0;top:0;bottom:0;max-width:60px;min-height:120px"></div></div>')
	near(limits.x.OuterWidth,60); near(limits.x.OuterHeight,120)
	local livePosition,live=build('<style>#x{width:40px;height:20px}#x:hover{position:absolute;left:10px;top:5px}#x:focus{position:absolute;left:auto;top:auto;right:12px;bottom:7px}</style><div style="position:relative;width:200px;height:100px"><div id="x"></div><div id="flow" style="height:10px"></div></div>')
	position(live.x,0,0);position(live.flow,0,20)
	local changed,reflow=livePosition:SetCSSState('hover',live.x.Node)
	assert(changed and reflow,'Changing position through a state must reflow')
	arrange(livePosition);position(live.x,10,5);position(live.flow,0,0)
	livePosition:SetCSSState('hover',nil)
	livePosition:SetCSSState('focus',live.x.Node)
	arrange(livePosition);position(live.x,148,73);position(live.flow,0,0)
	livePosition:SetCSSState('focus',nil)
	arrange(livePosition);position(live.x,0,0);position(live.flow,0,20)
	local viewport,v=build('<div id="x" style="position:absolute;right:10%;bottom:10%;width:40px;height:20px"></div>',200)
	position(v.x,140,250); viewport.ViewportHeight=400; arrange(viewport,300); position(v.x,230,340)
	local fixed,f=build('<div style="height:500px"></div><div id="x" style="position:fixed;right:10px;bottom:10px;width:40px;height:20px"></div>',200)
	position(f.x,150,270);local fh,fw=arrange(fixed,200);near(fh,500);near(fw,200)
	local stickyTree,sticky=build('<div style="height:20px"></div><div id="x" style="position:sticky;top:0;height:20px"></div><div style="height:500px"></div>',200)
	position(sticky.x,0,20)
	local function attachViewport(tree)
		local parent={AbsolutePosition=Vector2.new(0,0)}
		tree.Gui.Parent=parent;tree.Gui.AbsolutePosition=Vector2.new(0,0);tree.Gui.AbsoluteSize=Vector2.new(200,300)
		tree.Gui.AbsoluteWindowSize=tree.Gui.AbsoluteSize;tree.Gui.CanvasPosition=Vector2.new(0,0)
		local layer=ViewportLayer.attach(tree,tree.Gui,{create=function(class,owner,props)
			local object=table.clone(props);object.ClassName,object.Parent=class,owner;return object
		end})
		ViewportLayer.update(tree,tree.Gui);return layer
	end
	local stickyLayer=attachViewport(stickyTree)
	assert(stickyLayer==nil);position(sticky.x,0,20)
	stickyTree.Gui.CanvasPosition=Vector2.new(0,35)
	ViewportLayer.update(stickyTree,stickyTree.Gui);position(sticky.x,0,35)
	stickyTree.Gui.CanvasPosition=Vector2.new(0,5)
	ViewportLayer.update(stickyTree,stickyTree.Gui);position(sticky.x,0,20)
	local nestedStickyTree,nestedSticky=build('<div id="scroll" style="width:180px;height:100px;overflow:auto"><section style="height:160px"><div id="a" style="position:sticky;top:0;height:20px"></div></section><section style="height:160px"><div id="b" style="position:sticky;top:0;height:20px"></div></section></div>',200)
	attachViewport(nestedStickyTree)
	assert(nestedSticky.a.StickyScrollBox==nestedSticky.scroll and nestedSticky.b.StickyScrollBox==nestedSticky.scroll)
	nestedSticky.scroll.ScrollGui.CanvasPosition=Vector2.new(0,50)
	ViewportLayer.update(nestedStickyTree,nestedStickyTree.Gui)
	position(nestedSticky.a,0,50);position(nestedSticky.b,0,0)
	nestedSticky.scroll.ScrollGui.CanvasPosition=Vector2.new(0,150)
	ViewportLayer.update(nestedStickyTree,nestedStickyTree.Gui)
	position(nestedSticky.a,0,140);position(nestedSticky.b,0,0)
	nestedSticky.scroll.ScrollGui.CanvasPosition=Vector2.new(0,170)
	ViewportLayer.update(nestedStickyTree,nestedStickyTree.Gui)
	position(nestedSticky.a,0,140);position(nestedSticky.b,0,10)
	-- The page scroller must not move headings owned by a nested scrollport.
	nestedStickyTree.Gui.CanvasPosition=Vector2.new(0,40)
	ViewportLayer.update(nestedStickyTree,nestedStickyTree.Gui)
	position(nestedSticky.a,0,140);position(nestedSticky.b,0,10)
	local rows={}
	for index=1,20 do table.insert(rows,'<tr style="height:30px"><td>'..index..'</td></tr>') end
	local tableStickyTree,tableSticky=build('<div id="scroll" style="height:100px;overflow:auto"><table><caption>Measurements</caption><thead id="head" style="position:sticky;top:0"><tr><th>Case</th></tr></thead><tbody>'..table.concat(rows)..'</tbody></table></div>',200)
	attachViewport(tableStickyTree)
	assert(tableSticky.head.StickyScrollBox==tableSticky.scroll)
	tableSticky.scroll.ScrollGui.CanvasPosition=Vector2.new(0,200)
	ViewportLayer.update(tableStickyTree,tableStickyTree.Gui)
	near(tableSticky.head.StickyParentY+tableSticky.head.Gui.Position[2]-tableSticky.head.StickyScrollY-200,0)
	local fixedLayer=attachViewport(fixed)
	assert(f.x.Gui.Parent==fixedLayer);position(f.x,150,270)
	fixed.Gui.CanvasPosition=Vector2.new(7,40)
	ViewportLayer.update(fixed,fixed.Gui);position(f.x,150,270)
	local _,flex=build('<div style="display:flex;position:relative;gap:10px;height:100px;justify-content:center;align-items:center"><div id="a" style="width:40px;height:20px"></div><div id="x" style="position:absolute;width:30px;height:10px"></div><div id="b" style="width:40px;height:20px"></div></div>',200)
	position(flex.a,55,40); position(flex.b,105,40); position(flex.x,85,45)
	local _,fallback=build('<div style="height:20px"></div><div id="x" style="position:absolute;width:10px;height:10px"></div><div id="next" style="height:30px"></div>')
	position(fallback.x,0,20); position(fallback.next,0,20)
	local _,inline=build('<div id="text" style="position:relative;line-height:20px">A<span style="position:absolute;top:0;right:0">XX</span>B</div>')
	assert(#inline.text.FlowChildren==1 and inline.text.FlowChildren[1].Kind=='Words')
	assert(inline.text.FlowChildren[1].Items[1].Text=='AB')
	-- Replaced inline controls follow the same positioning rules as spans.
	-- Neither the initial build nor a retained DOM rebuild may split the line.
	local positionedControls,pc=build('<div id="text" style="position:relative;width:200px;line-height:20px">A<button id="drag" style="position:absolute;left:12px;top:6px;width:86px;height:48px;box-sizing:border-box">Drag</button>B<input id="pin" style="position:fixed;right:10px;bottom:8px;width:40px;height:20px;box-sizing:border-box"></div>',200)
	position(pc.drag,12,6);position(pc.pin,150,272)
	assert(#pc.text.FlowChildren==1 and pc.text.FlowChildren[1].Items[1].Text=='AB','Positioned controls split surrounding inline text')
	near(pc.text.OuterHeight,20)
	local dragItem=pc.drag.ImageItem;local dragGui=dragItem.Gui;local pinGui=pc.pin.ImageItem.Gui
	positionedControls:ReconcileChildren({[pc.text.Node]={Children=true}})
	arrange(positionedControls,200)
	assert(positionedControls.NodeBoxes[pc.drag.Node]==pc.drag and pc.drag.ImageItem==dragItem and dragItem.Gui==dragGui and pc.pin.ImageItem.Gui==pinGui,'Rebuilding flow replaces retained positioned controls')
	position(pc.drag,12,6);position(pc.pin,150,272)
	assert(#pc.text.FlowChildren==1 and pc.text.FlowChildren[1].Items[1].Text=='AB','Rebuilding positioned controls splits surrounding inline text')
	arrange(positionedControls,160);position(pc.drag,12,6);position(pc.pin,110,272)
	assert(dragItem.Gui==dragGui and pc.pin.ImageItem.Gui==pinGui,'Resizing recreates positioned controls')
	local percentControls,pct=build('<div id="card" style="position:relative;width:120px;aspect-ratio:1"><button id="fill" style="position:absolute;inset:0;width:100%;height:100%;padding:0;box-sizing:border-box">Card</button><img id="limited" src="rbxassetid://1" style="position:absolute;top:0;left:0;width:20px;height:50%"></div>',200,function()return 'rbxassetid://1'end)
	near(pct.card.OuterHeight,120);near(pct.fill.OuterHeight,120);near(pct.limited.OuterHeight,60)
	local fillGui=pct.fill.ImageItem.Gui
	pct.card.Node.Attributes.style='position:relative;width:180px;aspect-ratio:1'
	percentControls:ApplyDOMChanges({[pct.card.Node]={Attributes={style=true}}});arrange(percentControls,200)
	near(pct.fill.OuterHeight,180);near(pct.limited.OuterHeight,90)
	assert(pct.fill.ImageItem.Gui==fillGui,'Percentage height resize retains the control')
	local overflow=build('<div style="position:relative;height:20px"><div style="position:absolute;left:500px;top:100px;width:40px;height:30px"></div></div>')
	local h,w=arrange(overflow); near(h,130); near(w,540)
	local clipped=build('<div style="position:relative;height:20px;overflow:hidden"><div style="position:absolute;left:500px;top:100px;width:40px;height:30px"></div></div>')
	local ch,cw=arrange(clipped); near(ch,20); near(cw,400)
	local _,z=build('<div style="position:relative"><div id="a" style="position:absolute;z-index:2">A</div><div id="b" style="position:absolute;z-index:1">B</div><div id="c" style="z-index:99">C</div><div id="d" style="position:absolute;z-index:-1">D</div></div>')
	assert(z.a.Gui.ZIndex>z.b.Gui.ZIndex and z.b.Gui.ZIndex>z.c.Gui.ZIndex and z.c.Gui.ZIndex>z.d.Gui.ZIndex)
	local _,flexZ=build('<div style="display:flex"><div id="a" style="z-index:2">A</div><div id="b" style="z-index:1">B</div></div>')
	assert(flexZ.a.Gui.ZIndex>flexZ.b.Gui.ZIndex)
	for _,display in {'flex','inline-flex','grid','inline-grid'} do
		local _,ordered=build('<div style="display:'..display..';position:relative"><div id="a" style="display:flex;order:0;height:10px"></div><div id="b" style="order:1;height:10px"></div></div>')
		assert(ordered.b.Gui.ZIndex>ordered.a.Gui.ZIndex,display..' paints nested flex and block items in order-modified document order')
		local _,indexed=build('<div style="display:'..display..'"><div id="a" style="z-index:2;height:10px"></div><div id="b" style="z-index:1;height:10px"></div></div>')
		assert(indexed.a.Gui.ZIndex>indexed.b.Gui.ZIndex,display..' respects static item z-index')
	end
	for _,display in {'inline-flex','inline-grid','inline-block'} do
		local _,atomic=build('<div style="padding:10px"><div id="container" style="display:'..display..';position:relative;width:120px;height:40px;margin-left:7px"><div id="badge" style="position:absolute;right:4px;bottom:3px;width:20px;height:10px"></div></div></div>')
		position(atomic.badge,96,27)
		assert(atomic.container.HasPositioning,'Atomic inline descendants must participate in positioning')
	end
	local functionAnchorTree,functionAnchor=build('<div style="position:relative;width:200px;height:100px"><div style="height:70px"></div><div style="anchor-name:--source;width:40px;height:20px"></div><div id="target" style="position:absolute;position-anchor:--source;top:anchor(bottom);left:anchor(left);width:60px;height:30px;margin-top:5px;position-try-fallbacks:flip-block"></div></div>')
	position(functionAnchor.target,0,35)
	local fallbackTree,fallbackAnchor=build('<div style="position:relative;width:200px;height:100px"><div id="fallback" style="position:absolute;top:anchor(--missing bottom,20px);left:anchor(--missing left,15px);width:30px;height:10px"></div></div>')
	position(fallbackAnchor.fallback,15,20)
	local inlineAnchorTree,inlineAnchor=build('<div style="position:relative;width:200px;padding:10px"><div id="source" style="display:inline-block;anchor-name:--inline;width:40px;height:20px;margin-left:6px"></div><div id="target" style="position:absolute;position-anchor:--inline;position-area:right;width:20px;height:10px"></div></div>')
	assert(inlineAnchorTree.HasAnchors,'Anchor presence propagates through anonymous word runs')
	position(inlineAnchor.target,inlineAnchor.source.LayoutX+40,inlineAnchor.source.LayoutY+5)
	local _,relativeFlex=build('<div style="display:flex;align-items:baseline"><div id="a" style="position:relative;top:10px;width:40px;height:20px"></div><div id="b" style="width:40px;height:20px"></div></div>')
	position(relativeFlex.a,0,10); position(relativeFlex.b,40,0)
	local previous=a.badge.Gui.Position
	assert(layout.arrange(abs,200,0,0,function() return false end)==0 and a.badge.Gui.Position==previous)
	print('Positioning: cascade, relative flow, absolute containing blocks/sizing, inline blockification, flex exclusion, stacking, clipping, viewport resize and reuse passed')
end
