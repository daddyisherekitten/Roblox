--!strict
return function(html: string, css: string, Parser: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any, ScrollLayout: any, HitTest: any)
	local document=Parser.parse(html)
	local diagnostics={}
	local overrides={
		["Layout/FontProfiles"]={face=function(font: any) return font end},
		["Layout/TextMeasure"]={measure=function(value: string, _: any, size: number): any
			return {X=(utf8.len(value) or #value)*size*.5+(if value=="9" then size*.2 else 0),Y=size}
		end},
	}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local renderer=loadRenderTree({create=function(class: string, parent: any, props: any): any
		local gui=table.clone(props)
		gui.Parent=parent;gui.Visible=if props.Visible==nil then true else props.Visible
		gui.ClassName=class;gui.Attributes={}
		function gui:IsA(kind: string): boolean return kind==class or kind=="GuiObject" end
		function gui:SetAttribute(key: string,value: any) self.Attributes[key]=value end
		function gui:GetAttribute(key: string): any return self.Attributes[key] end
		if class=="TextButton" then
			gui.Activated={Connect=function(_: any,callback: any): any
				gui.Activate=callback
				return {Disconnect=function() end}
			end}
		end
		return gui
	end})
	local root={AbsoluteSize={X=1280,Y=800},Visible=true}
	function root:IsA(kind: string): boolean return kind=="GuiObject" end
	local tree=renderer.build(document,root,function(message: string)
		table.insert(diagnostics,message)
	end,nil,nil,nil,function() return "rbxassetid://1" end,nil,nil,nil,nil,nil,{["styles.css"]=css})
	for _,message in diagnostics do
		assert(not message:find("scroll-marker",1,true) and not message:find("font-variant-numeric",1,true),
			"Layout test page still reports an unsupported feature: "..message)
	end
	assert(layout.arrange(tree,1280,0,0,function() return true end)>0)
	local track
	for node,box in tree.NodeBoxes do
		if node.Attributes and (node.Attributes.class or ""):find("lab-snap-track",1,true) then track=box;break end
	end
	assert(track and track.ScrollMarkers and #track.ScrollMarkers==4 and track.ScrollMarkers[1].Text=="●",
		"Missing four CSS scroll markers: "..tostring(track and track.Style.ScrollMarkerGroup).." / "..tostring(track and #track.Children))
	assert(track.ScrollMarkerGui.Parent==track.Gui.Parent
		and track.ScrollMarkerGui.Position[1]==track.Gui.Position[1]
		and track.ScrollMarkerGui.Position[2]==track.Gui.Position[2]+track.OuterHeight+2,
		"Scroll markers must sit directly below the scrollport's left edge")
	assert(track.ScrollMarkers[1].TextColor3==Color3.fromRGB(36,111,168))
	assert(track.ScrollMarkers[2].TextColor3==Color3.fromRGB(143,165,183))
	local numberedLink
	for _,link in tree.Links do
		if link.Attributes.href=="#lab-slide-2" then numberedLink=link;break end
	end
	assert(numberedLink,"The snap navigation link is present")
	local linkText
	for _,item in tree.TextItems do
		if item.Style.Node==numberedLink then linkText=item;break end
	end
	assert(linkText,"The snap navigation link has a rendered text item")
	local label=linkText.TextGui or linkText.Gui
	assert(label.TextColor3==Color3.fromRGB(7,106,96))
	local changed,layoutNeeded=tree:SetCSSState("hover",numberedLink)
	assert(changed and layoutNeeded==false and label.TextColor3==Color3.fromRGB(151,67,24),
		"Hover color should repaint the link without relayout of the stress page: "..tostring(changed).."/"..tostring(layoutNeeded).."/"..tostring(label.TextColor3))
	changed,layoutNeeded=tree:SetCSSState("hover",nil)
	assert(changed and layoutNeeded==false and label.TextColor3==Color3.fromRGB(7,106,96),
		"Leaving the link should restore its color without relayout")
	for _,href in {"../html-css-stress/index.html","#layout-lab","#scroll-lab"} do
		local navLink
		for _,link in tree.Links do
			if link.Attributes.href==href and link.Parent and link.Parent.Attributes.class=="section-nav" then navLink=link;break end
		end
		assert(navLink,"Navigation link missing: "..href)
		local navText
		for _,item in tree.TextItems do if item.Style.Node==navLink then navText=item;break end end
		assert(navText,"Navigation link has no rendered text: "..href)
		local navLabel=navText.TextGui or navText.Gui
		changed,layoutNeeded=tree:SetCSSState("hover",navLink)
		assert(changed and layoutNeeded==false and navLabel.TextColor3==Color3.fromRGB(151,67,24),
			"Navigation hover must change text color without relayout: "..href)
		changed,layoutNeeded=tree:SetCSSState("hover",nil)
		assert(changed and layoutNeeded==false and navLabel.TextColor3==Color3.fromRGB(7,106,96),
			"Leaving navigation must restore its color without relayout: "..href)
	end
	for node,box in tree.NodeBoxes do
		if node.Attributes and node.Attributes.class=="hero" then
			assert(not box.RadiusRenderer,'Link hover must preserve the native rounded header')
		end
	end
	changed,layoutNeeded=tree:SetCSSState("focus",numberedLink)
	local focusBox
	for node,box in tree.NodeBoxes do
		if node.Attributes and (node.Attributes.class or ""):find("lab-demo",1,true)
			and node.Children and node.Children[2] and node.Children[2].Attributes
			and node.Children[2].Attributes.class=="lab-snap-links" then focusBox=box;break end
	end
	assert(changed and layoutNeeded==false and focusBox and focusBox.Outline and focusBox.Outline.Gui.Visible~=false,
		"Focusing a snap link should paint its container outline without a full layout")
	local outlineSurface=if focusBox.Outline.Edges then focusBox.Outline.Edges[1]else focusBox.Outline.Gui
	local picked=HitTest.pick({outlineSurface,label},tree.HitNodes,root,nil,tree.HitStyles)
	assert(picked==numberedLink,
		"The newly painted focus outline must not intercept the link's pointer release")
	changed,layoutNeeded=tree:SetCSSState("focus",nil)
	assert(changed and layoutNeeded==false and focusBox.Outline.Gui.Visible==false,
		"Blurring a snap link should hide the retained outline without a full layout")
	assert(not tree:SetCSSState("active",numberedLink),
		"The snap link has no active rule to recompute on pointer press")
	assert(not tree:SetCSSState("active",nil),
		"Pointer release should not recompute unused active styles")
	local destination,started,completed
	local completion={Connect=function(_: any,callback: any): any
		completed=callback
		return {Disconnect=function() end}
	end}
	track.TweenService={Create=function(_: any, _: any, _: any,goal: any): any
		destination=goal.CanvasPosition
		return {Completed=completion,Play=function() started=true end,Cancel=function() end}
	end}
	assert(track.Style.ScrollBehavior=="smooth" and track.ScrollMarkers[3].Activate)
	track.ScrollMarkers[3].Activate()
	assert(started and destination.X>0 and track.ScrollGui.CanvasPosition.X==0 and track.ScrollMarkerNavigating,
		"A marker click must start a smooth tween instead of jumping immediately")
	assert(not ScrollLayout.snap(track) and track.ScrollMarkerNavigating,
		"Pointer release must not start a competing snap while marker navigation runs")
	track.ScrollGui.CanvasPosition=destination
	completed()
	assert(not track.ScrollMarkerNavigating and track.ScrollMarkers[3].TextColor3==Color3.fromRGB(36,111,168))
	local numeric=0
	for _,item in tree.TextItems do
		if item.Style.TabularNums and item.Glyphs and item.Text:find("[0-9]") then
			numeric+=1
			for _,glyph in item.Glyphs do if glyph.Text:match("^[0-9]$") then assert(glyph.Width==item.Glyphs[1].Width) end end
		end
	end
	assert(numeric>=90,"Stress tiles must render tabular numeric glyphs")
	print("Stress layout: styled active scroll markers and equal-width numeric glyphs passed")
end
