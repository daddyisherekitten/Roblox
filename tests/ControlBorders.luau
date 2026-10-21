--!strict
return function(Parser,Node,Style,View,loadRenderTree,loadWordLayout,loadBlockLayout,html,css)
 local fixtureElement=require('DOM/Node').element
	local parent={FontSize=16,Color=Color3.new(0,0,0),BorderRadius=5}
	local function resolve(value,author,name,kind,warn)
		return Style.resolve(fixtureElement(name or 'button',{style=value,type=kind}),parent,warn or error,false,author)
	end
	for _,kind in {'button','submit','reset'}do
		for _,name in {'button','input'}do
			assert(resolve('',nil,name,kind).ButtonNativeRadius and resolve('',nil,name,kind).BorderRadius==3,'Unstyled buttons retain the native theme approximation')
			for _,rule in {'border:1px solid red','border-bottom:0','border-left-color:red','border-inline-end-style:none','background:#d5dcd9','background-image:none','background-position:0 0','border-image-source:none','appearance:none'}do
				assert(resolve(rule,nil,name,kind).BorderRadius==0,'Authored button has no implicit CSS radius: '..rule)
			end
		end
	end
	assert(resolve('color:blue').ButtonNativeRadius,'Text color alone does not change native button geometry')
	for _,rule in {'border-radius:8px;border:1px solid red','border:1px solid red;border-radius:8px','border-radius:8px;border-bottom:0'}do
		assert(resolve(rule).BorderRadius==8,'Author radius is independent of declaration order')
	end
	local one=resolve('border-top-left-radius:7px')
	assert(one.BorderRadii[1].X.Value==7 and one.BorderRadii[2].X.Value==0 and one.BorderRadii[3].Y.Value==0 and one.BorderRadii[4].X.Value==0,'Unspecified authored corners start from the CSS initial zero radius')
	assert(resolve('border-radius:inherit').BorderRadius==5)
	assert(resolve('border:1px solid red;border-radius:revert').BorderRadius==0,'Reverting radius on a devolved button must not inherit the native theme rounding')
	assert(resolve('border:1px solid red;border:revert').ButtonNativeRadius)
	assert(resolve('background:red;background:revert').ButtonNativeRadius)
	assert(resolve('border-radius:9px;border-radius:revert').ButtonNativeRadius)
	assert(resolve('border-radius:8px!important;border:1px solid red;border-radius:0').BorderRadius==8)
	assert(resolve('--edge:1px solid red;border:var(--edge)').BorderRadius==0)
	assert(resolve('--edge:broken;border:var(--edge)').BorderRadius==0,'Invalid-at-computed-value-time border has author-origin unset semantics')
	local warnings=0
	local invalid=resolve('border:broken;background:broken;border-radius:broken',nil,nil,nil,function()warnings+=1 end)
	assert(warnings==3 and invalid.ButtonNativeRadius,'Invalid declarations do not suppress native appearance')
	local lower=table.clone(Style.compile('border:1px solid red'));lower.Normal=table.clone(lower.Normal)
	for index,entry in lower.Normal do local copy=table.clone(entry);copy.CascadeLayer={1};lower.Normal[index]=copy end
	assert(resolve('border:revert-layer',lower).BorderRadius==0,'A reverted inline rule still has a lower author border')
	assert(resolve('border:revert',lower).ButtonNativeRadius,'Origin revert removes the lower author border too')
	assert(resolve('border:revert;border-left-color:red').BorderRadius==0,'One remaining author component keeps the button devolved')
	assert(resolve('border-left-color:red;border-left-color:revert').ButtonNativeRadius,'Reverting the only authored border component restores the native theme')
	local dark=resolve('color-scheme:dark;background:red;background:revert;border:1px solid red;border:revert')
	assert(dark.ButtonNativeRadius and not dark.ControlBackgroundSpecified and not dark.ControlBorderSpecified
		and dark.Background==Color3.fromRGB(107,107,107)and dark.BorderColor==Color3.fromRGB(133,133,133),'Theme selection uses the reverted final origins')
	local objects={};local factory={}
	function factory.create(class,host,props)
		local gui=table.clone(props);gui.ClassName,gui.Parent=class,host;gui.Visible=gui.Visible~=false
		gui.Position,gui.Size=gui.Position or UDim2.fromOffset(0,0),gui.Size or UDim2.fromOffset(0,0)
		gui.BackgroundTransparency=gui.BackgroundTransparency or 1;gui.BackgroundColor3=gui.BackgroundColor3 or Color3.new(1,1,1)
		gui.AbsolutePosition,gui.AbsoluteSize=Vector2.new(0,0),Vector2.new(800,600)
		local attributes={};function gui:SetAttribute(key,value)attributes[key]=value end;function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=='GuiObject'end
		function gui:Destroy()self.Destroyed=true;self.Parent=nil end
		table.insert(objects,gui);return gui
	end
	factory.modifier=factory.create
	local renderer=loadRenderTree(factory)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
	local function build(markup,rules,dot)
		local doc=Parser.parseDocument(markup)
		local tree=renderer.build(doc,factory.create('Frame',nil,{}),error,function(font)return font end,nil,nil,function()return 'rbxassetid://1'end,rules,nil,nil,dot)
		layout.arrange(tree,800,0,0,function()return true end)
		local byId={};for _,c in tree.Controls do if c.Node.Attributes.id then byId[c.Node.Attributes.id]=c.Item end end
		return tree,doc,byId
	end
	local function globalY(gui)
		local y=0
		while gui do y+=gui.Position and gui.Position[2]or 0;gui=gui.Parent end
		return y
	end
	local tree,doc,items=build('<div class="tabs"><button id="tab">Tab</button><input id="submit" type="submit" value="Submit"></div><input id="field" value="Text" style="border:2px solid red;border-left:0"><button id="pattern" style="border:4px dashed rgba(255,0,0,.5)">Pattern</button><button id="corners" style="border:1px solid red;border-top-left-radius:7px">Corners</button><button id="rich" style="border:1px solid red;border-bottom:0"><span>Rich</span></button>',[[
		.tabs{display:flex;padding:9px 10px 0;border-bottom:1px solid #a6b1b5}
		.tabs button,.tabs input{padding:5px 9px;border:1px solid #a6b1b5;border-bottom:0;background:#d5dcd9}
		#tab:hover{border-left-color:blue;background:#ffffff}
	]])
	for _,id in {'tab','submit'}do
		local item=items[id];local edges=item.ControlBorderEdges
		assert(edges and not item.Stroke.Enabled and item.Corner.CornerRadius.Offset==0,'Open square control: '..id)
		assert(edges[1].Size[2]==1 and edges[2].Size[1]==1 and edges[3].Size[2]==0 and edges[4].Size[1]==1,'Only three tab border sides are painted')
		local bar=tree.NodeBoxes[item.Control.Node.Parent]
		assert(math.abs(globalY(item.BoxGui)+item.BoxHeight-(globalY(bar.Gui)+bar.Gui.Size[2]-1))<.01,'The tab ends where the single parent bottom border begins')
	end
	assert(items.field.Editor and not items.field.Stroke.Enabled and items.field.ControlBorderEdges[2].Size[1]==0,'Partial borders work on editable fields too')
	assert(items.pattern.ControlBorderEdges and #items.pattern.ControlBorderEdges.Pools[1]>1 and items.pattern.ControlBorderEdges.Pools[1][1].BackgroundTransparency==.5,'Patterned borders use the shared retained segment renderer')
	assert(items.corners.Corner.TopLeftRadius.Offset==7 and items.corners.Corner.TopRightRadius.Offset==0)
	local rich=tree.NodeBoxes[items.rich.Control.Node]
	assert(items.rich.RichButton and rich.InsetEdges[3].Size[2]==0 and rich.Style.BorderRadius==0,'Rich buttons and captions share CSS side and corner semantics')
	local item=items.tab;local host,caption,edges=item.BoxGui,item.Label,item.ControlBorderEdges;local before=#objects
	local changed,needsLayout=tree:SetCSSState('hover',item.Control.Node)
	assert(changed and not needsLayout and item.BoxGui==host and item.Label==caption and item.ControlBorderEdges==edges and #objects==before,'Paint-only hover retains the complete control and border geometry')
	assert(edges[2].BackgroundColor3==Color3.fromRGB(0,0,255)and host.BackgroundColor3==Color3.new(1,1,1))
	tree:SetCSSState('hover',nil)
	-- Change all the border representations on the same mounted control.
	for _,value in {'border:2px solid green;border-radius:8px','border:3px dotted red;border-bottom:0','border:0','border:2px solid green;border-radius:0'}do
		item.Control.Node.Attributes.style=value;tree:RefreshDOMStyles({[item.Control.Node]=true})
		layout.arrange(tree,800,0,0,function()return true end)
		assert(item.BoxGui==host and item.Label==caption,'CSS mutation keeps controls mounted')
		if value:find('dotted',1,true)then assert(not item.Stroke.Enabled and item.ControlBorderEdges)
		else assert(not item.ControlBorderEdges and item.Stroke.Enabled==(not value:find('border:0',1,true)))end
	end
	assert(edges[1].Destroyed and edges[2].Destroyed and edges[3].Destroyed and edges[4].Destroyed,'Switching to a uniform border releases the old strips')
	-- Old individual-corner overrides cannot survive a later square CSS rule.
	items.corners.Control.Node.Attributes.style='border:1px solid red;border-radius:0'
	tree:RefreshDOMStyles({[items.corners.Control.Node]=true})
	assert(items.corners.Corner.TopLeftRadius.Offset==0 and items.corners.Corner.TopRightRadius.Offset==0)
	local grayTree,_,grayItems=build('<button id="gray" style="border:1px solid rgb(118,118,118)">Gray</button>')
	local gray=grayItems.gray;local background=gray.BoxGui.BackgroundColor3
	gray.Control.Hovered=true;gray.Control.Pressed=true;View.paint(gray)
	assert(gray.Stroke.Color==Color3.fromRGB(118,118,118)and gray.BoxGui.BackgroundColor3==background,'CSS button paint does not inherit native hover/pressed theme overrides')
	gray.Control.Disabled=true;View.paint(gray)
	assert(gray.Stroke.Color==Color3.fromRGB(118,118,118),'Disabled state does not override an authored border color')
	View.release(items.pattern)
	assert(not items.pattern.ControlBorderEdges,'Removing a control releases owned patterned-border resources')
	local byteTree,byteDoc,byteItems=build(html,css)
	for _,id in {'tab-news','tab-links','tab-about'}do
		local button=byteItems[id];local bar=byteTree.NodeBoxes[button.Control.Node.Parent]
		assert(button.Style.BorderRadius==0 and button.ControlBorderEdges and button.ControlBorderEdges[3].Size[2]==0)
		assert(math.abs(globalY(button.BoxGui)+button.BoxHeight-(globalY(bar.Gui)+bar.Gui.Size[2]-1))<.01,'Actual Bytebude seam: '..id)
	end
	local radioItems={};for _,control in byteTree.Controls do if control.Type=='radio'then table.insert(radioItems,control.Item)end end
	assert(#radioItems==4)
	local radio=radioItems[1];local radioHost,radioRing,radioDot=radio.BoxGui,radio.RadioRing,radio.Dot
	local htmlNode=Node.findElement(byteDoc,function(element)return element.Name=='html'end)
	local originalClass=htmlNode.Attributes.class or ''
	radio.Control.Checked=true;View.paint(radio)
	for _,night in {true,false,true,false}do
		htmlNode.Attributes.class=if night then originalClass..' night'else originalClass
		local changed=byteTree:RefreshDOMStyles({[htmlNode]=true})
		assert(changed and radio.BoxGui==radioHost and radio.RadioRing==radioRing and radio.Dot==radioDot,'Bytebude theme changes reuse the mounted radio surfaces')
		for _,item in radioItems do
			assert(item.Style.DarkScheme==night and item.RadioRing.BackgroundColor3==(if night then Color3.fromRGB(59,59,59)else Color3.new(1,1,1)), 'Selected and unselected radio interiors follow inherited color-scheme')
		end
		assert(radio.Dot.Visible and radio.Dot.BackgroundColor3==(if night then Color3.fromRGB(153,200,255)else Color3.fromRGB(0,117,255)),'The automatic accent follows the native dark/light scheme')
	end
	local _,_,themeItems=build('<div style="color-scheme:dark"><input id="radio" type="radio" checked disabled><input id="check" type="checkbox" checked><input id="custom" type="radio" checked style="accent-color:red"><input id="plain" type="radio" checked style="appearance:none;background:red"><input id="hidden" type="radio" checked style="visibility:hidden"></div>',nil,{Get=function()return 'native-dot'end})
	assert(themeItems.radio.RadioRing.BackgroundColor3==Color3.fromRGB(59,59,59)and themeItems.radio.Dot.ImageColor3==Color3.fromRGB(118,118,118),'Disabled dark radio retains its field surface')
	assert(themeItems.check.BoxGui.BackgroundColor3==Color3.fromRGB(153,200,255),'Checkbox shares the native automatic accent')
	assert(themeItems.check.Ticks[1].BackgroundColor3==Color3.fromRGB(59,59,59),'The default dark checkbox mark uses the native field color')
	assert(themeItems.custom.Dot.ImageColor3==Color3.new(1,0,0),'Authored accent is preserved across themes')
	assert(not themeItems.plain.RadioRing.Visible and not themeItems.plain.Dot.Visible,'appearance:none suppresses the native radio ring and mark')
	assert(themeItems.plain.BoxGui.BackgroundColor3==Color3.new(1,0,0),'A devolved radio preserves its authored background')
	assert(not themeItems.hidden.RadioRing.Visible and not themeItems.hidden.Dot.Visible,'Hidden controls do not leak native child paint')
	local schemeTree,schemeDoc,schemeItems=build('<html><body><input id="r" type="radio" checked><input id="c" type="checkbox" checked><input id="text" value="Text"><div id="scroll" style="width:150px;height:60px;overflow:scroll"><div style="height:160px">Scroll</div></div></body></html>',':root{color-scheme:light}.night{color-scheme:dark}')
	local schemeRoot=Node.findElement(schemeDoc,function(element)return element.Name=='html'end)
	local scroll=schemeTree.NodeBoxes[Node.findById(schemeDoc,'scroll')]
	local scrollSize,canvas=scroll.ScrollGui.Size,scroll.ScrollGui.CanvasSize
	scroll.ScrollGui.CanvasPosition=Vector2.new(0,25)
	local allocated=#objects
	for _,night in {true,false,true}do
		schemeRoot.Attributes.class=if night then 'night'else ''
		local changed,needsLayout=schemeTree:RefreshDOMStyles({[schemeRoot]=true})
		assert(changed and not needsLayout and #objects==allocated,'A color-scheme change alone repaints controls without layout or allocations: changed='..tostring(changed)..' layout='..tostring(needsLayout)..' allocations='..(#objects-allocated))
		assert(schemeItems.r.RadioRing.BackgroundColor3==(if night then Color3.fromRGB(59,59,59)else Color3.new(1,1,1)))
		assert(scroll.ScrollGui.ScrollBarImageColor3==(if night then Color3.fromRGB(159,159,159)else Color3.fromRGB(139,139,139))and scroll.ScrollTrackY.BackgroundColor3==(if night then Color3.fromRGB(44,44,44)else Color3.fromRGB(225,225,225)), 'Native scroll surfaces follow the same inherited theme')
		assert(scroll.ScrollGui.Size==scrollSize and scroll.ScrollGui.CanvasSize==canvas and scroll.ScrollGui.CanvasPosition.Y==25,'Scrollbar paint preserves scroll geometry and position')
	end
	local mounted=schemeItems.r
	mounted.Control.Hovered=true;View.paint(mounted)
	assert(mounted.Dot.BackgroundColor3==Color3.fromRGB(209,230,255),'Automatic dark radio hover follows the Chromium reference')
	mounted.Control.Pressed=true;View.paint(mounted)
	assert(mounted.Dot.BackgroundColor3==Color3.fromRGB(97,169,255),'Automatic dark radio press follows the Chromium reference')
	print('ControlBorders: authored/native corners and sides, pattern cleanup, actual Bytebude, inherited light/dark controls, radio hover/press, scrollbar paint and retained geometry passed')
end
