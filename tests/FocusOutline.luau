--!strict
return function(Parser,Node,Controller,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
	local samples={};for _,sample in reference.samples do samples[sample.name]=sample end
	local function outlineVisible(item)return item.ControlOutline and item.ControlOutline.Gui.Visible~=false end
	local function measured(sample)
		local r,g,b,style,width=sample.outline:match("rgb%((%d+), (%d+), (%d+)%) (%a+) ([%d.]+)px")
		assert(style=="auto"and sample.visible)
		return {Color=Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b)),Width=tonumber(width),Offset=tonumber(sample.offset:match("([%d.]+)px"))or 0}
	end
	local ua,wide,zero,explicit=measured(samples.Standard),measured(samples.Breit),measured(samples.Null),measured(samples.Auto)
	local paint=reference.paint
	-- Use native focus signals as in Autofocus, so input clicks exercise the
	-- Controller path instead of toggling a private control flag.
	local function signal()
		local entries={};local api={}
		function api:Connect(fn)
			local c={Connected=true,Fn=fn};function c:Disconnect()self.Connected=false end
			table.insert(entries,c);return c
		end
		function api:Fire(...)for _,c in table.clone(entries)do if c.Connected then c.Fn(...)end end end
		return api
	end
	local overrides={
		["Layout/FontProfiles"]={face=function(font)return font end},
		["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*5,Y=size}end},
	}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local function setup(html,css,shadowHTML)
		local native,objects,hitObjects=nil,{},{}
		local factory={}
		function factory.create(class,parent,props)
			local gui=table.clone(props);gui.Parent=parent;gui.ClassName=class;gui.Visible=true;gui.Enabled=true
			gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(400,300)
			if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
			function gui:IsA(kind)return kind==class or(kind=="GuiObject"and class~="ScreenGui")or(kind=="LayerCollector"and class=="ScreenGui")end
			local properties,attributes,attributeSignals={},{},{}
			function gui:GetPropertyChangedSignal(name)properties[name]=properties[name]or signal();return properties[name]end
			function gui:GetAttributeChangedSignal(name)attributeSignals[name]=attributeSignals[name]or signal();return attributeSignals[name]end
			function gui:GetAttribute(name)return attributes[name]end
			function gui:SetAttribute(name,value)
				local old=attributes[name];attributes[name]=value
				if old~=value then self:GetAttributeChangedSignal(name):Fire()end
			end
			gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal()
			function gui:IsFocused()return native==self end
			function gui:CaptureFocus()if native and native~=self then native:ReleaseFocus()end;native=self;self.Focused:Fire()end
			function gui:ReleaseFocus()if native==self then native=nil;self.FocusLost:Fire(false)end end
			function gui:Destroy()self.Destroyed=true;self.Parent=nil end
			table.insert(objects,gui);return gui
		end
		factory.modifier=factory.create
		local screen=factory.create("ScreenGui",nil,{})
		local root=factory.create("ScrollingFrame",screen,{})
		root:SetAttribute("Status","ready")
		local document=Parser.parse(html)
		if shadowHTML then
			local host=assert(Node.findById(document,"host"))
			local shadow=Node.shadowRoot("open",host);host.InternalShadowRoot=shadow
			local fragment=Parser.parse(shadowHTML)
			for _,child in table.clone(fragment.Children)do child.Parent=nil;Node.append(shadow,child)end
		end
		local tree=loadRenderTree(factory).build(document,root,error,function(font)return font end,nil,nil,nil,css)
		layout.arrange(tree,400,0,0,function()return true end)
		local byId={};for _,c in tree.Controls do byId[c.Node.Attributes.id]=c end
		local input={InputBegan=signal(),InputEnded=signal(),InputChanged=signal(),WindowFocusReleased=signal()}
		function input:GetFocusedTextBox()return native end
		function input:IsKeyDown()return false end
		local page={Document=document,Root=root,Alive=true}
		function page:AddCleanup(fn)self.Cleanup=fn end
		local requests=0
		Controller.start(page,tree,function()requests+=1 end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return hitObjects end},Factory=factory})
		local function outlineCount(c)
			local owner=tree.NodeBoxes[c.Node];local ownerGui=owner and owner.Gui or c.Item.Gui
			local count=0
			for _,gui in objects do
				if gui.Name=="Outline"and not gui.Destroyed and gui.Visible~=false then
					local parent=gui.Parent
					while parent and parent~=ownerGui do if parent.Destroyed or parent.Visible==false then parent=nil;break end;parent=parent.Parent end
					if parent==ownerGui then count+=1 end
				end
			end
			return count
		end
		local function geometry()
			local values={tree.LocalRight,tree.LocalBottom}
			for _,c in tree.Controls do
				local item=c.Item
				for _,v in {item.BoxWidth,item.BoxHeight,item.Gui.Position[1],item.Gui.Position[2],item.Gui.Size[1],item.Gui.Size[2]}do table.insert(values,v)end
			end
			local after=Node.findById(document,"after");local box=after and tree.NodeBoxes[after]
			if box then for _,v in {box.OuterWidth,box.OuterHeight,box.Gui.Position[1],box.Gui.Position[2]}do table.insert(values,v)end end
			return values
		end
		return {Page=page,Tree=tree,Controls=byId,Input=input,OutlineCount=outlineCount,Geometry=geometry,
			Requests=function()return requests end,ObjectCount=function()return #objects end,Click=function(c)
				hitObjects={c.Item.BoxGui};local event={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(2,2)}
				input.InputBegan:Fire(event,false);input.InputEnded:Fire(event,false);hitObjects={}
			end}
	end
	local dark,green,red=ua.Color,Color3.fromRGB(8,127,104),measured(samples.Rot).Color
	local offset=measured(samples.Versetzt).Offset
	local function equalGeometry(before,after)
		assert(#before==#after)
		for i,v in before do assert(v==after[i],"Focus outline changed layout, following content or scroll geometry")end
	end
	local function autoRing(c,offset,color)
		local item=c.Item;local outline=assert(item.ControlOutline,"Focused native field needs the UA focus outline")
		assert(outline.Gui.Visible~=false,'The retained focus outline must actually be painted')
		assert(item.Style.OutlineStyle=="auto"and outline.Style.BorderStyle=="solid"and outline.Style.BorderSize==paint.width)
		assert(outline.Style.BorderColor==(color or dark)and outline.Offset==(offset or 0)-paint.inside)
		assert(outline.Style.BorderRadius==math.max(paint.minimumInnerRadius,item.Style.BorderRadius or 0))
		assert(outline.Gui.Position[1]==item.Style.Margin[4]-(offset or 0)-paint.outside
			and outline.Gui.Size[1]==item.BoxWidth+2*((offset or 0)+paint.outside),"Auto outline matches the measured native outside/inside split")
		assert(outline.Gui:GetAttribute("HTMLPaintOnlyOverlay")==true)
	end
	local fixture=setup([[<input id="inline" style="color:#c030e8"><input id="block" style="display:block">
		<div style="display:flex;flex-direction:column"><input id="flex"></div>
		<input id="password" type="password" value="Secret"><input id="appearance" style="appearance:none">
		<textarea id="area">Edit</textarea><button id="button" type="button">Button</button><p id="after">After</p>]],
		"input,textarea,button{border:1px solid #087f68;margin:5px}")
	local original=fixture.Geometry()
	for _,id in {"inline","block","flex","password","appearance","area"}do
		local c=fixture.Controls[id]
		assert(not outlineVisible(c.Item))
		c.Item.Editor:CaptureFocus()
		assert(c.Focused and c.Item.Editor:IsFocused())
		autoRing(c)
		assert(c.Item.Style.OutlineWidth==ua.Width and c.Item.Style.OutlineColor==dark,"UA color is independent of authored text color and appearance")
		assert(c.Item.Stroke.Thickness==1 and c.Item.Stroke.Color==green,"UA outline must preserve the authored 1px green border")
		assert(fixture.OutlineCount(c)==1,"Inline, block and flex controls must own exactly one focus outline")
		equalGeometry(original,fixture.Geometry())
		assert(fixture.Requests()==0,"Default focus and blur must only repaint")
		c.Item.Editor:ReleaseFocus()
		assert(not c.Focused and not outlineVisible(c.Item) and fixture.OutlineCount(c)==0)
		local retained=c.Item.ControlOutline.Gui;local allocated=fixture.ObjectCount()
		for _=1,3 do
			c.Item.Editor:CaptureFocus();autoRing(c)
			assert(c.Item.ControlOutline.Gui==retained and fixture.ObjectCount()==allocated,'Repeated focus reuses its native outline and stroke')
			c.Item.Editor:ReleaseFocus();assert(not outlineVisible(c.Item)and fixture.OutlineCount(c)==0)
		end
		equalGeometry(original,fixture.Geometry());assert(fixture.Requests()==0,'Repeated focus and blur never request layout')
	end
	-- Tab moves from the textarea to the button; pointer focus removes the ring.
	fixture.Page:Focus("area")
	fixture.Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Tab},false)
	local button=fixture.Controls.button
	assert(button.Focused and not outlineVisible(fixture.Controls.area.Item));autoRing(button);assert(fixture.OutlineCount(button)==1)
	fixture.Click(button)
	assert(button.Focused and not outlineVisible(button.Item),"Pointer-focused buttons do not match focus-visible")
	equalGeometry(original,fixture.Geometry());assert(fixture.Requests()==0)
	fixture.Page.Cleanup()
	fixture=setup([[<input id="none" style="outline:none"><input id="zero" style="outline:0 solid red">
		<input id="initial" style="outline:initial"><input id="important" style="outline:3px dashed red">
		<input id="auto-zero" style="outline-width:0"><input id="color" style="outline-color:red;outline-offset:]]..offset..[[px">
		<input id="width" style="outline-width:]]..wide.Width..[[px"><input id="explicit-auto" style="outline:auto;color:rgb(34,60,52)"><input id="custom">]],
		"input{border:1px solid #087f68}#custom:focus-visible{outline:3px dashed #b44409;outline-offset:4px}#important:focus-visible{outline:none!important}")
	for _,id in {"none","zero","initial","important"}do
		fixture.Page:Focus(id)
		local c=fixture.Controls[id]
		assert(c.Focused and not outlineVisible(c.Item) and fixture.OutlineCount(c)==0,"Authored none, initial, zero-width solid and important rules suppress the default outline")
	end
	fixture.Page:Focus("auto-zero");autoRing(fixture.Controls["auto-zero"])
	assert(paint.autoIgnoresWidth and fixture.Controls["auto-zero"].Item.Style.OutlineWidth==zero.Width,"Auto profile keeps the computed width while choosing its native stroke")
	fixture.Page:Focus("color");autoRing(fixture.Controls.color,offset,red)
	assert(not outlineVisible(fixture.Controls["auto-zero"].Item),"Focus moves must clear the previous UA outline")
	assert(fixture.Controls.color.Item.Style.OutlineColor==red and fixture.Controls.color.Item.Style.OutlineOffset==offset)
	fixture.Page:Focus("width");autoRing(fixture.Controls.width)
	assert(not outlineVisible(fixture.Controls.color.Item))
	assert(fixture.Controls.width.Item.Style.OutlineWidth==wide.Width,"Authored width is retained in computed style")
	fixture.Page:Focus("explicit-auto");autoRing(fixture.Controls["explicit-auto"],explicit.Offset,explicit.Color)
	assert(fixture.Controls["explicit-auto"].Item.Style.OutlineWidth==explicit.Width,"Author auto shorthand uses its own width and currentcolor")
	fixture.Page:Focus("custom")
	local custom=fixture.Controls.custom;local outline=assert(custom.Item.ControlOutline)
	assert(custom.Item.Style.OutlineStyle=="dashed"and outline.Style.BorderStyle=="dashed"
		and outline.Style.BorderSize==3 and outline.Style.BorderColor==Color3.fromRGB(180,68,9)and outline.Offset==4)
	assert(custom.Item.Stroke.Thickness==1 and custom.Item.Stroke.Color==green and fixture.OutlineCount(custom)==1)
	custom.Item.Editor:ReleaseFocus();assert(not outlineVisible(custom.Item))
	fixture.Page.Cleanup()
	fixture=setup([[<input id="block" style="display:block;outline:3px dashed red;outline-offset:4px">
		<div style="display:flex"><input id="flex" style="outline:3px dashed red;outline-offset:4px"></div><p id="after">After</p>]],
		"input{border:1px solid #087f68}")
	original=fixture.Geometry()
	for _,id in {"block","flex"}do
		local c=fixture.Controls[id]
		assert(c.Item.ControlOutline and fixture.OutlineCount(c)==1,"Initial authored outline needs one control painter")
		fixture.Page:Focus(id)
		assert(c.Item.ControlOutline.Style.BorderStyle=="dashed"and c.Item.ControlOutline.Style.BorderSize==3
			and c.Item.ControlOutline.Style.BorderColor==red and fixture.OutlineCount(c)==1)
		c.Item.Editor:ReleaseFocus()
		assert(c.Item.ControlOutline and fixture.OutlineCount(c)==1,"Blur preserves an authored outline that does not depend on focus")
		equalGeometry(original,fixture.Geometry())
	end
	assert(fixture.Requests()==0);fixture.Page.Cleanup()
	fixture=setup('<div id="generic" tabindex="0" style="width:100px;height:20px;border:1px solid #087f68">Generic</div><p id="after">After</p>')
	local generic=assert(Node.findById(fixture.Page.Document,"generic"));local box=fixture.Tree.NodeBoxes[generic]
	original=fixture.Geometry()
	assert(fixture.Page:FocusDOMElement(generic,true))
	assert(box.Style.OutlineStyle=="auto"and box.Outline and box.Outline.Gui.Visible~=false
		and box.Outline.Style.BorderSize==paint.width and box.Outline.Style.BorderColor==dark,"Keyboard focus applies the UA rule to generic focusable elements")
	assert(fixture.Page:BlurDOMElement(generic))
	assert(not box.Outline or box.Outline.Gui.Visible==false)
	equalGeometry(original,fixture.Geometry());assert(fixture.Requests()==0);fixture.Page.Cleanup()
	fixture=setup('<div id="host"></div><p id="after">After</p>',nil,
		'<style>input{border:1px solid #087f68}</style><input id="shadow">')
	local shadow=fixture.Controls.shadow
	assert(shadow,"Shadow-tree control must be rendered")
	shadow.Item.Editor:CaptureFocus();assert(shadow.Focused);autoRing(shadow)
	assert(shadow.Item.Stroke.Thickness==1 and shadow.Item.Stroke.Color==green and fixture.OutlineCount(shadow)==1)
	shadow.Item.Editor:ReleaseFocus();assert(not outlineVisible(shadow.Item) and fixture.Requests()==0)
	fixture.Page.Cleanup()
	print("FocusOutline: UA cascade, native focus/blur, border preservation, auto profile, author overrides, keyboard/pointer, inline/block/flex geometry and shadow targets passed")
end
