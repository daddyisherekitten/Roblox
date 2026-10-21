--!strict
-- Native PNGs are independent references. These checks sample the actual
-- retained background GUIs and uploaded buffers, not a second CSS parser.
return function(Parser,Node,Canvas,BackgroundImages,Runtime,Events,HTMLScripts,Dirty,Controller,HTMLAnimations,loadRenderTree,loadWordLayout,loadBlockLayout,fixture,loadHTMLPage,loadBackgroundSVG,loadBackgroundImages,BorderCorners)
	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,e in table.clone(listeners)do if e[1].Connected then e[2](...)end end end
		function api:Count()local count=0;for _,e in listeners do if e[1].Connected then count+=1 end end;return count end
		return api
	end
	local guis,images={},{};local factory={}
	function factory.create(class,parent,properties)
		local gui={ClassName=class,Parent=parent,Visible=true,BackgroundTransparency=1,BackgroundColor3=Color3.new(1,1,1),Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(0,0),AbsoluteSize=Vector2.new(800,600),AbsolutePosition=Vector2.new(0,0),ZIndex=1,Destroying=signal()}
		for key,value in properties do gui[key]=value end
		if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0);gui.ScrollBarThickness=0 end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
		function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals['attribute:'..key]then signals['attribute:'..key]:Fire()end end
		function gui:GetChildren()local result={};for _,child in guis do if child.Parent==self and not child.Destroyed then table.insert(result,child)end end;return result end
		function gui:IsA(kind)return kind==class or kind=='GuiObject'end
		function gui:IsFocused()return self.FocusedNow==true end
		function gui:CaptureFocus()self.FocusedNow=true;self.Focused:Fire()end
		function gui:ReleaseFocus()self.FocusedNow=false;self.FocusLost:Fire()end
		function gui:Destroy()assert(not self.Destroyed,'Canvas GUI disposed twice');self.Destroyed=true;self.Destroying:Fire();for _,child in self:GetChildren()do child:Destroy()end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	function factory.createImage(size)
		local image={Size=size};function image:WritePixelsBuffer(_,_,pixels)self.Pixels=pixels end
		function image:Destroy()assert(not self.Destroyed,'Canvas texture disposed twice');self.Destroyed=true end
		table.insert(images,image);return image
	end
	local measurements=0
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)measurements+=1;return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local function over(a,b)
		local alpha=a[4]+b[4]*(1-a[4]);if alpha==0 then return {0,0,0,0}end
		return {(a[1]*a[4]+b[1]*b[4]*(1-a[4]))/alpha,(a[2]*a[4]+b[2]*b[4]*(1-a[4]))/alpha,(a[3]*a[4]+b[3]*b[4]*(1-a[4]))/alpha,alpha}
	end
	local function guiColor(gui)
		local c=gui.BackgroundColor3 or Color3.new();return {c.R*255,c.G*255,c.B*255,1-(gui.BackgroundTransparency or 1)}
	end
	local function component(value,index)return if value then value[index]or(if index==1 then value.X.Offset else value.Y.Offset)else 0 end
	local function dimension(gui,index)
		local value=gui.Size;local scale=if index==1 then value.XScale or 0 else value.YScale or 0
		return component(value,index)+scale*(if gui.Parent then dimension(gui.Parent,index)else 0)
	end
	local function sample(gui,x,y)
		if gui.Destroyed or gui.Visible==false then return {0,0,0,0}end
		if gui.ClassName=='UIStroke'then
			local w,h=component(gui.Parent.Size,1),component(gui.Parent.Size,2);local t=gui.Thickness or 0
			if x>=0 and y>=0 and x<w and y<h and(x<t or y<t or x>=w-t or y>=h-t)then local c=gui.Color;return {c.R*255,c.G*255,c.B*255,1-(gui.Transparency or 0)}end
			return {0,0,0,0}
		end
		local width,height=dimension(gui,1),dimension(gui,2)
		if gui.ClipsDescendants and(x<0 or y<0 or x>=width or y>=height)then return {0,0,0,0}end
		local color=if x>=0 and y>=0 and x<width and y<height then guiColor(gui)else {0,0,0,0}
		if gui.ClassName=='ImageLabel'and gui.ImageContent and gui.ImageContent.Pixels and gui.ImageTransparency~=1 and width>0 and height>0 then
			local image=gui.ImageContent;local tile=gui.ScaleType==Enum.ScaleType.Tile
			local w,h=if tile then component(gui.TileSize,1)else width,if tile then component(gui.TileSize,2)else height
			if x>=0 and y>=0 and x<width and y<height then
				local u,v=((x+.5)%w)/w*image.Size.X-.5,((y+.5)%h)/h*image.Size.Y-.5
				local px,py=math.floor(u),math.floor(v);local fx,fy=u-px,v-py;local rgba={0,0,0,0}
				for dy=0,1 do for dx=0,1 do
					local at=(math.clamp(py+dy,0,image.Size.Y-1)*image.Size.X+math.clamp(px+dx,0,image.Size.X-1))*4
					local weight=(if dx==0 then 1-fx else fx)*(if dy==0 then 1-fy else fy);local alpha=buffer.readu8(image.Pixels,at+3)/255
					for channel=1,3 do rgba[channel]+=buffer.readu8(image.Pixels,at+channel-1)*alpha*weight end;rgba[4]+=alpha*weight
				end end
				if rgba[4]>0 then for channel=1,3 do rgba[channel]/=rgba[4]end end;color=over(rgba,color)
			end
		end
		local children=gui:GetChildren();table.sort(children,function(a,b)if a.ZIndex~=b.ZIndex then return (a.ZIndex or 1)<(b.ZIndex or 1)end;return table.find(guis,a)<table.find(guis,b)end)
		for _,child in children do
			local position=child.Position;local xs,ys=position.XScale or 0,position.YScale or 0
			color=over(sample(child,x-component(position,1)-xs*width,y-component(position,2)-ys*height),color)
		end
		if gui.ClassName=='CanvasGroup'then
			local tint=gui.GroupColor3;if tint then color[1]*=tint.R;color[2]*=tint.G;color[3]*=tint.B end
			color[4]*=1-(gui.GroupTransparency or 0)
		end
		return color
	end
	local function canvasPixel(s,x,y)
		local color=sample(s.Tree.CanvasBackgroundState.Gui,x,y)
		-- Sample local DOM/background/border/marker paint above the canvas. The
		-- native root group alpha is then applied to that combined result once.
		local rootBox=s.Tree.NodeBoxes[s.Html]
		color=over(sample(rootBox.Gui,x-(rootBox.LayoutX or 0),y-(rootBox.LayoutY or 0)),color)
		if rootBox.OpacityGroup then color[4]*=1-rootBox.OpacityGroup.Gui.GroupTransparency end
		return over(color,guiColor(s.Root))
	end
	local function mount(html,prepare,corners,options)
		options=options or{}
		local document=Parser.parseDocument(html);if prepare then prepare(document)end
		local h=Canvas.documentRoot(document);local b=Node.findById(document,'audit-body')or Node.findElement(h,function(node)return node.LocalName=='body'or node.Name=='body'end)
		local viewport=factory.create('ScrollingFrame',nil,{BackgroundTransparency=options.CanvasTransparency or 0,BackgroundColor3=options.CanvasColor or Color3.new(1,1,1)})
		local messages={};local background=(options.BackgroundImages or BackgroundImages).new(function(m)table.insert(messages,m)end,options.ResolveImage,factory.createImage,viewport,options.BackgroundOptions)
		local draws,canvasDraws=0,0;local draw=background.Draw;function background:Draw(box,...)draws+=1;if box.CanvasPaintingArea then canvasDraws+=1 end;return draw(self,box,...)end
		-- The CLI shim's fromScale drops scale metadata. Preserve the real
		-- declaration while building this mount, then restore the shared shim.
		local fromScale=UDim2.fromScale;UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
		local ok,tree=pcall(renderer.build,document,viewport,function(m)table.insert(messages,m)end,function(font)return font end,nil,nil,nil,nil,nil,corners,nil,nil,nil,nil,nil,nil,background)
		UDim2.fromScale=fromScale;assert(ok,tostring(tree))
		local s={Document=document,Html=h,Body=b,Root=viewport,Tree=tree,Background=background,Messages=messages,Layouts=0,FirstImage=#images+1}
		function s:Arrange(width,height,targets)
			width,height=width or 800,height or 600;self.Layouts+=1;tree:SetMediaEnvironment(width,height);tree.ViewportHeight=height
			Dirty.begin(tree,targets);local contentHeight=layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)
			tree:PublishCanvasBackground(math.max(width,tree.LocalRight or width),math.max(height,contentHeight));return contentHeight
		end
		function s:DrawCount()return draws end
		function s:CanvasDrawCount()return canvasDraws end
		function s:Destroy()
			tree:DestroyCanvasBackground();background:Destroy();if corners then corners:Destroy()end;tree.VisualEffects:Destroy();viewport:Destroy()
			assert(#messages==(options.ExpectedDiagnostics or 0),table.concat(messages,' | '))
			for _,message in messages do assert(message=='background-image: no options.Images mapping for url(about:invalid#canvas-missing); layer omitted','Unexpected canvas diagnostic: '..message)end
		end
		s:Arrange();return s
	end
	local pixels,cases,dynamicSnapshots=0,0,0
	local function checkPixels(s,points,label)
		for _,point in points do
			local actual=canvasPixel(s,point.point[1],point.point[2]);for channel=1,3 do assert(math.abs(actual[channel]-point.rgba[channel])<=3,label..' retained pixel '..channel..' at '..point.point[2]..': '..actual[channel]..' ~= '..point.rgba[channel])end;pixels+=1
		end
	end
	local function scriptRealm(s,validateStructure)
		local events=Events.new(error);local realm
		local function flush()local needed,items=realm:Flush();if needed then s:Arrange(nil,nil,items)end end
		realm=Runtime.new(s.Document,{Events=events,Diagnostic=error,ApplyChanges=function(changes)return s.Tree:ApplyDOMChanges(changes)end,
			ValidateStructure=if validateStructure then function(parent,node,oldParent)s.Tree:ValidateStructure(parent,node,oldParent)end else nil,
			GeometryAdapter={GetTree=function()return s.Tree end,GetViewport=function()return{Width=800,Height=600}end,HasPending=function()return realm:HasPending()end,Flush=flush}})
		local function run(source)local ok,err=realm:Run(source);assert(ok,tostring(err));flush()end
		local function cssom(snapshot,label)
			for _,key in {'root','body'}do local expected=snapshot[key];if expected then
				local expression=if key=='root'then'document.documentElement'else'document.body'
				for _,property in {'color','backgroundColor','backgroundImage'}do
					run('if(getComputedStyle('..expression..').'..property..'!=='..string.format('%q',expected[property])..')throw Error('..string.format('%q',label..' '..key..' computed '..property)..'+": "+getComputedStyle('..expression..').'..property..');')
				end
			end end
		end
		return run,cssom,function()realm:Destroy();events:Destroy()end
	end
	-- Independently captured computed values use parsed images rather than
	-- repeating author text. Hidden connected content still has computed CSS.
	for _,reference in fixture.computedImages.rows do
		local escaped=reference.input:gsub('&','&amp;'):gsub('"','&quot;')
		local s=mount('<html style="margin:0"><body style="display:none;color:rgba(12,34,56,.5);font-size:20px;background-image:'..escaped..'"></body></html>')
		local run,_,dispose=scriptRealm(s)
		run('var imageStyle=getComputedStyle(document.body);if(imageStyle.backgroundImage!=='..string.format('%q',reference.computed)..')throw Error('..string.format('%q',reference.input)..'+": "+imageStyle.backgroundImage);')
		run('if(imageStyle.getPropertyValue("background-image")!==imageStyle.backgroundImage)throw Error("background-image aliases");')
		local source=s.Body.Attributes.style;local parsed=s.Tree.NodeStyles[s.Body].BackgroundImages
		run('if(imageStyle.backgroundImage!=='..string.format('%q',reference.computed)..')throw Error("Repeated image read changed the result");')
		assert(s.Body.Attributes.style==source and s.Tree.NodeStyles[s.Body].BackgroundImages==parsed,'Computed image reads do not mutate declarations or parsed images')
		dispose();s:Destroy()
	end
	-- Append-only independent captures cover actual non-HTML roots, including
	-- the replaced SVG root, and structural first-body changes. These probes
	-- concern the canvas outside the local root/frameset/SVG content boxes.
	local ownerStates=0
	for _,reference in fixture.ownerSelection.rows do
		local function make(spec)
			local node=Node.element(spec.name,{style=spec.style})
			node.NamespaceURI=spec.namespace or'';node.LocalName=spec.name:match('^[^:]+:(.+)$')or spec.name
			if spec.id then node.Attributes.id=spec.id end
			for _,child in spec.children do Node.append(node,make(child))end
			return node
		end
		local s=mount('<!doctype html><html><body></body></html>',function(d)local old=Canvas.documentRoot(d);Node.removeChild(d,old);Node.append(d,make(reference.root))end)
		local plane=s.Tree.CanvasBackgroundState.Gui
		local run,_,dispose=scriptRealm(s,true)
		local function owner(expected,snapshot,points,label)
			s.Html=Canvas.documentRoot(s.Document)
			local state=s.Tree.CanvasBackgroundState;local selected=if expected=='root'then s.Html else Node.findById(s.Document,expected)
			assert(state.Plan.Root==s.Html and state.Plan.Owner==selected,label..': actual expanded-name owner')
			assert(s.Tree.NodeBoxes[s.Html],label..': actual root has no retained layout/paint box; display='..tostring(s.Tree.NodeStyles[s.Html]and s.Tree.NodeStyles[s.Html].Display)..', style='..tostring(s.Html.Attributes.style))
			assert(state.Gui==plane,label..': owner changes reuse the canvas surface')
			checkPixels(s,points,label)
			for _,property in {'backgroundColor','backgroundImage'}do run('if(getComputedStyle(document.documentElement).'..property..'!=='..string.format('%q',snapshot.root[property])..')throw Error('..string.format('%q',label..': root computed '..property)..');')end
			local authored,computed={},{ }
			for node,style in s.Tree.NodeStyles do authored[node]=node.Attributes and node.Attributes.style;computed[node]={style,style.Background,style.BackgroundAlpha,style.BackgroundImages}end
			state:Refresh();s.Tree:PublishCanvasBackground(800,600)
			for node,before in computed do local style=s.Tree.NodeStyles[node];assert(style==before[1]and style.Background==before[2]and style.BackgroundAlpha==before[3]and style.BackgroundImages==before[4]and(not node.Attributes or node.Attributes.style==authored[node]),label..': used-owner refresh changed source/computed background')end
			ownerStates+=1
		end
		owner(reference.expectedOwner,reference.initial.snapshot,reference.initial.pixels,reference.id)
		if reference.id=='document-element-replacement'then
			run("var sameRoot=document.documentElement;var invalidRoot=false;try{document.appendChild(document.createElement('body'));}catch(e){invalidRoot=e.name==='HierarchyRequestError';}if(!invalidRoot||document.documentElement!==sameRoot)throw Error('Invalid root insertion mutated document');")
		end
		for index,step in reference.dynamic do
			run(step.operation.script)
			owner(step.operation.owner,step.snapshot,step.pixels,reference.id..' mutation '..index)
		end
		dispose();s:Destroy()
	end
	assert(ownerStates==20,'All independent owner initial and structural mutation states must run')
	for _,case in fixture.cases do
		local spec=case.mount;local html=case.html
		if not html then html='<html style="'..spec.rootCSS..'"><head></head><body id="audit-body" style="'..spec.bodyCSS..'"></body></html>'end
		local s=mount(html,function(d)
			if not case.constructed then return end;local h=Canvas.documentRoot(d);local b=Node.findById(d,'audit-body')
			if spec.rootName~='html'then h.Name,h.LocalName,h.NamespaceURI=spec.rootName,'html','http://www.w3.org/1999/xhtml'end
			if spec.bodyName~='body'then b.Name,b.LocalName=spec.bodyName,'body'end
			if spec.bodyNamespace~='http://www.w3.org/1999/xhtml'then b.NamespaceURI=spec.bodyNamespace or''end
			if spec.kind=='nested'then Node.removeChild(b.Parent,b);local div=Node.element('div',{});Node.append(h,div);Node.append(div,b)end
			if spec.kind=='frameset-only'then b.Name,b.LocalName='frameset','frameset'end
			if spec.kind=='two-bodies'then local later=Node.element('body',{id='later-body',style='display:block;margin:0;height:40px;background:rgb(200,10,10)'});later.NamespaceURI,later.LocalName='http://www.w3.org/1999/xhtml','body';Node.append(h,later)end
			if spec.kind=='frameset-before-body'then
				Node.removeChild(h,b);local frameset=Node.element('frameset',{style='display:block;margin:0;height:30px;background:rgb(200,10,10)'});frameset.NamespaceURI,frameset.LocalName='http://www.w3.org/1999/xhtml','frameset';Node.append(h,frameset);Node.append(h,b)
			end
		end,nil,{ExpectedDiagnostics=case.expectedDiagnostics})
		local rootBox=s.Tree.NodeBoxes[s.Html]
		local initiallyTransformed=#(rootBox.Style.Transform or{})>0
		if not case.id:find('translate')then
			local points=case.initial.pixels
			if case.id=='owner-frameset-only'then
				-- Chromium has a special nonpainting frameset host. This slice
				-- accepts only canvas ownership outside the local frameset box;
				-- retain its inside raw pixels without claiming that host profile.
				local outside={};for _,point in points do if point.point[2]>=120 then table.insert(outside,point)end end;points=outside
				assert(s.Tree.CanvasBackgroundState.Plan.Owner==s.Html and not s.Tree.CanvasBackgroundState.Plan.Paint,'Frameset never becomes a canvas-body owner')
			end
			checkPixels(s,points,case.id);cases+=1
		end
		if case.id=='owner-two-bodies'or case.id=='owner-frameset-before-body'then
			assert(s.Tree.CanvasBackgroundState.Plan.Owner==s.Body and s.Tree.CanvasBackgroundState.Plan.Source=='body','Only the first eligible direct HTML body owns the canvas')
			local later=Node.findById(s.Document,'later-body');if later then assert(not s.Tree.NodeBoxes[later].CanvasBackgroundSuppressed,'Later body retains its ordinary local background')end
		end
		if #case.dynamic>0 then
			local run,cssom,dispose=scriptRealm(s);cssom(case.initial.snapshot,case.id..' initial')
			local plane,paintBox=s.Tree.CanvasBackgroundState.Gui,s.Tree.CanvasBackgroundState.PaintBox
			local originalStyles,originalImages={},{ }
			for _,node in{s.Html,s.Body}do originalStyles[node]=s.Tree.NodeStyles[node];originalImages[node]=s.Tree.NodeStyles[node].BackgroundImages end
			local previousImages=#images
			for _,step in case.dynamic do
				local operation=step.operation
				if operation.loadHTML then
					local fresh=mount(operation.loadHTML);local _,freshCSS,freshDispose=scriptRealm(fresh);freshCSS(step.snapshot,case.id..' '..step.id);checkPixels(fresh,step.pixels,case.id..' '..step.id);freshDispose();fresh:Destroy()
				else
					local layouts=s.Layouts
					if operation.selector then run('document.querySelector('..string.format('%q',operation.selector)..').style.'..operation.property..'='..string.format('%q',operation.value)..';')end
					cssom(step.snapshot,case.id..' '..step.id)
					for _,node in{s.Html,s.Body}do
						assert(s.Tree.NodeStyles[node]==originalStyles[node],case.id..': live mutation preserves original source/style identity')
						if operation.property~='backgroundImage'then assert(s.Tree.NodeStyles[node].BackgroundImages==originalImages[node],case.id..': unrelated mutation preserves source image identity')end
					end
					local points=step.pixels
					if case.id=='root-gradient-currentcolor'then
						-- Raw changed/delayed Chromium stays red. Compare the standard's
						-- fresh-color expectation to the separately captured fresh control.
						for _,controlStep in case.dynamic do if controlStep.id=='fresh-changed'then points=controlStep.pixels end end
					end
					if case.id:find('translate%-pattern')then
						-- Baseline restoration exercises live transform cleanup. The
						-- existing bounded gradient raster interpolates hard edges; these
						-- phase probes compare interior colors, not edge antialiasing.
						local interior={};for _,point in points do local y=point.point[2]%20;if point.point[1]~=400 or(y>2 and y<18)then table.insert(interior,point)end end;points=interior
					end
					checkPixels(s,points,case.id..' '..step.id)
					if case.group=='image-eligibility'or case.group=='source-state-reversal'then
						local diagnostic=if operation.property=='backgroundImage'and operation.value:find('canvas%-missing')then 1 else 0
						local fresh=mount('<!doctype html>'..step.snapshot.serializedRoot,nil,nil,{ExpectedDiagnostics=diagnostic})
						checkPixels(fresh,points,case.id..' '..step.id..' fresh')
						assert(s.Tree.CanvasBackgroundState.Plan.Source==fresh.Tree.CanvasBackgroundState.Plan.Source and s.Tree.CanvasBackgroundState.Plan.Paint==fresh.Tree.CanvasBackgroundState.Plan.Paint,case.id..': warm/fresh canvas source parity')
						local freshBody=fresh.Tree.NodeBoxes[fresh.Body]
						assert(s.Tree.NodeBoxes[s.Body].CanvasBackgroundSuppressed==(freshBody and freshBody.CanvasBackgroundSuppressed),case.id..': warm/fresh body local paint ownership')
						fresh:Destroy()
						if case.group=='image-eligibility'then
							assert(s.Layouts==layouts,case.id..': invalid image changes are paint-only')
							local image=s.Tree.NodeStyles[s.Html].BackgroundImages[1]
							if operation.value=='url()'or operation.value=='url("")'then assert(image.Kind=='url'and image.Source=='',case.id..': preserve the empty URL layer')end
						end
					end
					assert(s.Tree.CanvasBackgroundState.Gui==plane and s.Tree.CanvasBackgroundState.PaintBox==paintBox,case.id..' live mutation retains canvas owners')
					if operation.property=='color'then
						assert(s.Layouts==layouts,case.id..': color-only canvas publication does not lay out')
						if operation.selector=='body'then assert(#images==previousImages,'Body gradient currentColor change reuses root-used raster')else assert(#images==previousImages+1,'Root-used currentColor creates exactly one new raster')end
					end
					previousImages=#images
				end
				dynamicSnapshots+=1
			end
			dispose()
		end
		if (rootBox.Style.Opacity or 1)==1 and #(rootBox.Style.Filter and rootBox.Style.Filter.Steps or{})==0 and not rootBox.Style.MaskImage and not initiallyTransformed then assert(not rootBox.OpacityGroup,case.id..': ordinary root does not allocate a CanvasGroup texture')end
		if case.id=='dark-transparent-root-half'then assert(not rootBox.CanvasPaintBounds and component(rootBox.OpacityGroup.Gui.Size,2)<=rootBox.OuterHeight,'Transparent dark UA surface adds no canvas-size compositor texture')end
		assert(not s.Tree.HitNodes[s.Tree.CanvasBackgroundState.Gui]and not s.Tree.NodeBoxes[s.Tree.CanvasBackgroundState.PaintBox],'Synthetic canvas does not enter DOM/hit/layout indexes')
		s:Destroy()
	end
	-- Independent browser captures exercise every previously missing live
	-- publication trigger with the actual retained runtime/controller/editor.
	local liveStates=0
	do
		for _,reference in fixture.liveCanvas.computedSchemes do
			local s=mount('<html style="margin:0;color-scheme:'..reference.input..'"><body style="display:none"></body></html>');local run,_,dispose=scriptRealm(s)
			run('if(getComputedStyle(document.documentElement).colorScheme!=='..string.format('%q',reference.computed)..'||getComputedStyle(document.body).getPropertyValue("color-scheme")!=='..string.format('%q',reference.computed)..')throw Error("Computed/inherited color-scheme order");')
			dispose();s:Destroy()
		end
		for _,reference in fixture.liveCanvas.rows do
			local s=mount(reference.html,nil,BorderCorners.new(error,factory.createImage));local tree=s.Tree
			local width,height=800,600;local realm,flushing;local page={Alive=true,Root=s.Root,Document=s.Document,DocumentURL='https://canvas.test/live',BaseURL='https://canvas.test/live',Cleanups={}}
			function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
			function page:GeometryViewport()return{Width=width,Height=height,ClientWidth=width,ClientHeight=height,ScrollWidth=width,ScrollHeight=math.max(height,tree.LocalBottom or 0),ScrollX=0,ScrollY=0}end
			function page:HasPendingLayout()return false end
			function page:FlushScriptLayout()
				if flushing or not realm then return end;flushing=true
				local needed,items=realm:Flush();if needed then s:Arrange(width,height,items)end
				flushing=false
			end
			local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
			function input:GetFocusedTextBox()for _,gui in guis do if gui.ClassName=='TextBox'and not gui.Destroyed and gui:IsFocused()then return gui end end;return nil end
			function input:IsKeyDown()return false end;function input:GetStringForKeyCode()return ''end
			local stop=Controller.start(page,tree,function()end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=function()return 0 end,PickerLayout=layout})
			local services={Clock=function()return 0 end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return{Callback=fn}end,cancel=function(ticket)ticket.Cancelled=true end}}
			realm=HTMLScripts.start(page,tree,function()end,error,{JavaScriptServices=services})
			local function run(code)local ok,err=realm:Run(code);assert(ok,tostring(err));for _=1,4 do page:FlushScriptLayout();realm:AfterLayout();local count=realm:PumpTasks();if count==0 and not realm:HasPending()then break end end;page:FlushScriptLayout()end
			run('var notes=document.getElementById("notes");notes.value="edited😀";notes.focus();notes.setSelectionRange(1,8,"backward");')
			local node=Node.findById(s.Document,'notes');local control=page.FormModel:Resolve(node);local editor=control.Item.Editor
			local box,bodyBox,plane,paint=tree.NodeBoxes[s.Html],tree.NodeBoxes[s.Body],tree.CanvasBackgroundState.Gui,tree.CanvasBackgroundState.PaintBox
			local rootGui,bodyGui,editorGui=box.Gui,bodyBox.Gui,control.Item.Gui
			local rootStyle,bodyStyle=tree.NodeStyles[s.Html],tree.NodeStyles[s.Body]
			local focused,text=editor.Focused:Count(),editor:GetPropertyChangedSignal('Text'):Count()
			local function verify(state,label,hover)
				local authoredRoot,authoredBody=s.Html.Attributes.style,s.Body.Attributes.style
				for _,pair in{{s.Html,'root'},{s.Body,'body'}}do
					local expression=if pair[2]=='root'then'document.documentElement'else'document.body'
					for _,property in{'backgroundColor','backgroundImage','opacity','colorScheme'}do run('if(getComputedStyle('..expression..').'..property..'!=='..string.format('%q',state.snapshot[pair[2]][property])..')throw Error('..string.format('%q',label..' '..pair[2]..' '..property)..'+": "+getComputedStyle('..expression..').'..property..');')end
				end
				checkPixels(s,state.pixels,label)
				if state.effectPixels then checkPixels(s,state.effectPixels,label..' inside effect owner')end
				assert(tree.NodeBoxes[s.Html]==box and box.Gui==rootGui and tree.NodeBoxes[s.Body]==bodyBox and bodyBox.Gui==bodyGui and tree.CanvasBackgroundState.Gui==plane and tree.CanvasBackgroundState.PaintBox==paint,label..': retained paint owners')
				assert(tree.NodeStyles[s.Html]==rootStyle and tree.NodeStyles[s.Body]==bodyStyle and s.Html.Attributes.style==authoredRoot and s.Body.Attributes.style==authoredBody,label..': preserve computed style identity and authored declarations')
				assert(page.FormModel:Resolve(node)==control and control.Item.Gui==editorGui and control.Item.Editor==editor and editor.Text=='edited😀'and editor:IsFocused()and input:GetFocusedTextBox()==editor,label..': retained focused editor/value')
				assert(editor.Focused:Count()==focused and editor:GetPropertyChangedSignal('Text'):Count()==text,label..': unchanged editor connections')
				run('if(document.activeElement!==notes||notes.selectionStart!==1||notes.selectionEnd!==8||notes.selectionDirection!=="backward")throw Error("Live canvas selection");')
				local fresh=mount('<!doctype html>'..state.snapshot.html,nil,BorderCorners.new(error,factory.createImage));if hover then fresh.Tree:SetCSSState('hover',if hover=='body'then fresh.Body else fresh.Html)end
				fresh:Arrange(width,height);checkPixels(fresh,state.pixels,label..' fresh')
				if state.effectPixels then checkPixels(fresh,state.effectPixels,label..' inside fresh effect owner')end
				assert(tree.CanvasBackgroundState.Plan.Source==fresh.Tree.CanvasBackgroundState.Plan.Source and tree.CanvasBackgroundState.Plan.Paint==fresh.Tree.CanvasBackgroundState.Plan.Paint,label..': fresh owner/presentation parity')
				fresh:Destroy();liveStates+=1
			end
			verify(reference.initial,reference.id..' initial')
			for index,state in reference.dynamic do
				local operation=state.operation;local before,measured=s.Layouts,measurements
				if operation.script then run(operation.script)end
				if operation.viewport then width,height=unpack(operation.viewport);s.Root.AbsoluteSize=Vector2.new(width,height);s:Arrange(width,height)end
				local hover=operation.hover
				if reference.id:find('hover',1,true)then local _,needed,items=tree:SetCSSState('hover',if not hover then nil elseif hover=='body'then s.Body else s.Html);if needed then s:Arrange(width,height,items)end end
				if not operation.viewport and reference.id~='live-document-growth'then assert(s.Layouts==before and measurements==measured,reference.id..': paint change must not arrange or measure text')end
				if reference.id=='live-document-growth'then assert(component(plane.Size,2)==(if Node.findById(s.Document,'grow')then math.max(600,tree.LocalBottom or 0)else 600)and (not Node.findById(s.Document,'grow')or component(plane.Size,2)>=900),'Live descendant overflow grows and restores the retained canvas')end
				verify(state,reference.id..' '..index,if hover==false then nil else hover)
			end
			for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;stop();s:Destroy()
			assert(not realm.Alive and editor.Focused:Count()==0 and editor:GetPropertyChangedSignal('Text'):Count()==0,'Live canvas releases runtime/editor listeners')
		end
		assert(liveStates==24,'Run every independent initial/live canvas state')
		for _,reference in fixture.liveCanvas.groupedReplacement.rows do
			local s=mount(reference.html);local state=s.Tree.CanvasBackgroundState;local plane=state.Gui
			local run,_,dispose=scriptRealm(s)
			assert(s.Tree.NodeBoxes[s.Html].OpacityGroup,'Grouped-root replacement must begin with an actual compositor')
			run(reference.operation);s.Html=Canvas.documentRoot(s.Document)
			assert(not plane.Destroyed and state.Gui==plane and plane.Parent,'Retiring the root compositor must not destroy the shared canvas plane')
			assert(state.RootBox==s.Tree.NodeBoxes[s.Html]and state.RootBox and not state.RootBox.OpacityGroup,'The new ungrouped root takes over the same canvas')
			checkPixels(s,reference.pixels,'replacement after '..reference.effect)
			run('document.removeChild(document.documentElement);')
			assert(not plane.Destroyed and plane.Parent==s.Root and not plane.Visible and state.RootBox==nil,'A temporarily empty document retains only its hidden document-owned canvas')
			run('document.appendChild(freshRoot);');s.Html=Canvas.documentRoot(s.Document)
			assert(not plane.Destroyed and state.RootBox==s.Tree.NodeBoxes[s.Html]and state.Gui==plane,'Reinserting a root restores the original document canvas')
			checkPixels(s,reference.pixels,'reinserted root after '..reference.effect)
			dispose();s:Destroy()
		end
		local original=Color3.fromRGB(210,190,150)
		local s=mount('<html style="margin:0"><body style="margin:0;height:120px;background:rgba(20,80,140,.5)"></body></html>',nil,nil,{CanvasColor=original,CanvasTransparency=.2})
		local plane=s.Tree.CanvasBackgroundState.Gui;local run,_,dispose=scriptRealm(s)
		assert(s.Root.BackgroundColor3==original and s.Root.BackgroundTransparency==.2 and plane.BackgroundTransparency==.5,'Author alpha is applied once over the original host canvas surface')
		run('document.body.style.backgroundColor="transparent"');assert(s.Root.BackgroundColor3==original and s.Root.BackgroundTransparency==.2 and not plane.Visible,'Removing author paint restores the exact original host color and alpha')
		run('document.documentElement.style.colorScheme="dark"');assert(s.Root.BackgroundColor3==Color3.fromRGB(18,18,18)and s.Root.BackgroundTransparency==0,'Dark used root scheme chooses the UA canvas surface')
		run('document.documentElement.style.colorScheme="light"');assert(s.Root.BackgroundColor3==original and s.Root.BackgroundTransparency==.2,'Leaving dark scheme restores the saved host surface')
		dispose();s:Destroy()
	end
	-- Empty image values pass through the actual style parser, shorthand and
	-- variable substitution. Invalid syntax still keeps the earlier declaration.
	do
		local resolverCalls,svgCalls=0,0;local svg=loadBackgroundSVG({})
		local backgrounds=loadBackgroundImages({['Rendering/BackgroundSVG']={new=function(...)
			local api=svg.new(...);local draw=api.Draw
			function api:Draw(slot,source,...)
				assert(source~='','Empty URL must not enter SVG Draw');svgCalls+=1;return draw(self,slot,source,...)
			end
			return api
		end}})
		local options={BackgroundImages=backgrounds,ResolveImage=function(source)assert(source~='','Empty URL must not enter image resolution');resolverCalls+=1;return nil end,
			BackgroundOptions={ResolveSVG=function(source)error('Unexpected SVG resolution: '..source)end}}
		local values={'url("")',"url('')",'url()','url(  )'}
		for _,value in values do
			for _,declaration in {'background-image:'..value,'background:'..value,'--empty:'..value..';background-image:var(--empty)'}do
				local s=mount('<html style="margin:0;'..declaration:gsub('"','&quot;')..'"><body style="margin:0;height:120px;background:blue"></body></html>',nil,nil,options)
				local style=s.Tree.NodeStyles[s.Html];assert(style.BackgroundImages[1].Kind=='url'and style.BackgroundImages[1].Source=='','Valid empty URL remains a layer through shorthand/variables')
				assert(s.Tree.CanvasBackgroundState.Plan.Owner==s.Html,'Empty URL blocks body propagation');s:Destroy()
			end
		end
		for _,value in {'image-set(url("") 1x)','image-set("" 1x)'}do
			local s=mount('<html style="margin:0;background-image:'..value:gsub('"','&quot;')..'"><body style="margin:0;height:120px;background:blue"></body></html>',nil,nil,options)
			local image=s.Tree.NodeStyles[s.Html].BackgroundImages[1]
			assert(image.Kind=='image-set'and image.Candidates[1].Image.Kind=='url'and image.Candidates[1].Image.Source=='','Image-set URL/string paths retain an empty invalid image')
			assert(s.Tree.CanvasBackgroundState.Plan.Owner==s.Html,'Empty image-set candidate blocks propagation');s:Destroy()
		end
		local parser=require('CSS/Background')
		for _,value in {'url("unterminated)','url("line\nbreak")','image-set(url("") 0x)'}do
			assert(parser.images(value,function()return nil end)==nil,'Malformed URL/descriptor grammar remains invalid: '..value)
		end
		local s=mount('<html style="margin:0;height:120px;background-image:linear-gradient(red,red)"><body style="margin:0;height:120px;background:blue"></body></html>',nil,nil,options)
		local run,_,dispose=scriptRealm(s);local plane,box=s.Tree.CanvasBackgroundState.Gui,s.Tree.CanvasBackgroundState.PaintBox;local before=#images
		for _,value in values do
			run('document.documentElement.style.backgroundImage='..string.format('%q',value)..';')
			assert(s.Tree.CanvasBackgroundState.Gui==plane and s.Tree.CanvasBackgroundState.PaintBox==box and #images==before,'Empty image keeps owner and hides existing raster without allocation')
			local rgba=canvasPixel(s,400,300);assert(rgba[1]==255 and rgba[2]==255 and rgba[3]==255,'Removed raster cannot paint through an empty root URL')
		end
		assert(resolverCalls==0 and svgCalls==0,'Every empty URL path has no image resolution, SVG Draw, IO or warning')
		dispose();s:Destroy()
		local layered=mount('<html style="margin:0;height:120px;background-color:blue;background-image:url(&quot;&quot;),linear-gradient(red,red);background-size:1px 1px,20px 30px;background-position:left top,right bottom;background-repeat:no-repeat"><body style="margin:0;height:120px"></body></html>',nil,nil,options)
		local red,blue=canvasPixel(layered,790,110),canvasPixel(layered,770,110)
		assert(red[1]==255 and red[2]==0 and red[3]==0 and blue[1]==0 and blue[3]==255,'Skipping empty URL preserves the later image longhand index and position')
		local runLayered,_,disposeLayered=scriptRealm(layered)
		runLayered('document.documentElement.style.backgroundImage="none,linear-gradient(red,red)";')
		local restored=canvasPixel(layered,790,110)
		assert(restored[1]==255 and restored[3]==0 and resolverCalls==0 and svgCalls==0,'Empty-to-none retains later image geometry without URL IO')
		disposeLayered();layered:Destroy()
	end
	-- A background-image change is paint-only even when it changes how four
	-- unequal circular corners and their border are represented. Compare cold
	-- final builds; then retain the original box/modifier through warm reversals.
	do
		local base='width:80px;height:60px;background-color:red;border:2px solid blue;'
		local circle=base..'border-radius:8px 16px 24px 32px;'
		local ellipse=base..'border-radius:8px 16px 24px 32px / 4px 8px 12px 16px;'
		local function html(style)return '<html style="margin:0"><body style="margin:0"><div id="rounded" style="'..style..'"></div></body></html>'end
		local probe=mount(html(circle),nil,BorderCorners.new(error,factory.createImage))
		local node=Node.findById(probe.Document,'rounded');local box=probe.Tree.NodeBoxes[node];local gui,corner=box.Gui,box.Corner
		assert(box.NativeCornerRadii and box.Style.NativeCornerRadii,'Four independent circular corners initially use native modifiers')
		local layouts=probe.Layouts;local run,_,dispose=scriptRealm(probe)
		local function parity(style,label)
			run('document.getElementById("rounded").style.cssText='..string.format('%q',style)..';')
			assert(probe.Layouts==layouts and probe.Tree.NodeBoxes[node]==box and box.Gui==gui and box.Corner==corner,label..': paint-only retained box and native modifier')
			local fresh=mount(html(style),nil,BorderCorners.new(error,factory.createImage));local other=fresh.Tree.NodeBoxes[Node.findById(fresh.Document,'rounded')]
			assert(box.NativeCornerRadii==other.NativeCornerRadii and box.Style.NativeCornerRadii==other.Style.NativeCornerRadii,label..': cold corner representation parity')
			assert((box.ResolvedBorderRadii~=nil)==(other.ResolvedBorderRadii~=nil)and box.Style.RasterBorderOverlay==other.Style.RasterBorderOverlay,label..': cold raster ownership parity')
			assert((box.InsetEdges and box.InsetEdges.Overlay~=nil or false)==(other.InsetEdges and other.InsetEdges.Overlay~=nil or false)
				and(box.InsetEdges and box.InsetEdges[1]~=nil or false)==(other.InsetEdges and other.InsetEdges[1]~=nil or false),label..': cold border representation parity')
			if box.NativeCornerRadii then for index,property in{'TopLeftRadius','TopRightRadius','BottomRightRadius','BottomLeftRadius'}do
				assert(corner[property].Offset==({8,16,24,32})[index]and corner[property].Offset==other.Corner[property].Offset,label..': independent native radii restored')
			end end
			fresh:Destroy()
		end
		parity(circle..'background-image:linear-gradient(red,red);','native to image')
		assert(not box.NativeCornerRadii and box.InsetEdges and box.InsetEdges[1],'Image switches border away from stale native/overlay representation')
		parity(circle,'image to native');assert(box.InsetEdges==nil,'Native stroke replaces obsolete edge surfaces')
		parity(ellipse,'native to ellipse');assert(box.RasterBorderGui and box.RasterBorderGui.Visible and box.ResolvedBorderRadii,'Actual radius raster becomes visible')
		local texture=box.RasterBorderGui.ImageContent;local raster=box.RasterBorderGui;local surface
		for _,child in gui:GetChildren()do if child.Name=='RoundedSurface'then surface=child end end
		assert(surface and surface.Visible and texture.Pixels,'Ellipse has an uploaded raster surface')
		parity(ellipse..'background-image:linear-gradient(red,red);','ellipse to image')
		assert(not raster.Visible and not surface.Visible and not box.ResolvedBorderRadii and not box.Style.RasterBorderOverlay,'Image hides old radius texture and clears raster flags')
		parity(ellipse,'image to ellipse');assert(raster.Visible and surface.Visible and raster.ImageContent==texture,'Warm restoration reuses original radius texture')
		parity(circle,'ellipse to native');assert(not raster.Visible and not surface.Visible and not box.ResolvedBorderRadii and not box.Style.RasterBorderOverlay,'Native restoration hides cached raster and clears its border ownership')
		parity(circle..'background-image:linear-gradient(red,red);','warm native to image');parity(circle,'warm image to native')
		dispose();probe:Destroy();assert(gui.Destroyed and corner.Destroyed and texture.Destroyed,'Retained corner owner, modifier and cached raster dispose once')
	end
	-- Real script/CSSOM paint publications with a mounted native editor.
	local s=mount('<html><head><style id="rules">html,body{margin:0;padding:0}body{height:120px;background:rgb(20,80,140)}#marker{position:absolute;left:5px;top:5px;width:10px;height:10px;background:rgb(200,10,10)}#notes{width:100px;height:20px}</style></head><body id="audit-body"><div id="marker"></div><input id="notes" value="original"><script>void 0;</script></body></html>')
	local tree=s.Tree;local page={Alive=true,Root=s.Root,Document=s.Document,DocumentURL='https://canvas.test/page',BaseURL='https://canvas.test/page',Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local realm;local flushing=false
	function page:GeometryViewport()return {Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollWidth=800,ScrollHeight=600,ScrollX=0,ScrollY=0}end
	function page:HasPendingLayout()return false end
	function page:FlushScriptLayout()if flushing or not realm then return end;flushing=true;local needed,items=realm:Flush();if needed then s:Arrange(nil,nil,items)end;flushing=false end
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()for _,gui in guis do if gui.ClassName=='TextBox'and not gui.Destroyed and gui:IsFocused()then return gui end end;return nil end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode()return ''end
	local stop=Controller.start(page,tree,function()end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=function()return 0 end,PickerLayout=layout})
	local services={Clock=function()return 0 end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return{Callback=fn}end,cancel=function(ticket)ticket.Cancelled=true end}}
	realm=HTMLScripts.start(page,tree,function()end,error,{JavaScriptServices=services})
	local function run(code)local ok,err=realm:Run(code);assert(ok,tostring(err));page:FlushScriptLayout();realm:AfterLayout();realm:PumpTasks();page:FlushScriptLayout()end
	local field=Node.findById(s.Document,'notes');local control=page.FormModel:Resolve(field);local editor=control.Item.Editor
	assert(editor,'Mounted canvas test has an actual native editor')
	run('const root=document.documentElement,body=document.body,notes=document.getElementById("notes"),rules=document.getElementById("rules");notes.value="edited😀";notes.focus();notes.setSelectionRange(1,8,"backward");')
	assert(editor:IsFocused()and input:GetFocusedTextBox()==editor,'Actual mounted editor is focused before compositor promotion')
	local box,gui,plane,paintBox=tree.NodeBoxes[s.Html],tree.NodeBoxes[s.Html].Gui,tree.CanvasBackgroundState.Gui,tree.CanvasBackgroundState.PaintBox
	local inputGui=control.Item.Gui;local focusCount,textCount=editor.Focused:Count(),editor:GetPropertyChangedSignal('Text'):Count();local layouts=s.Layouts
	local function retained(label)
		assert(tree.NodeBoxes[s.Html]==box and box.Gui==gui and tree.CanvasBackgroundState.Gui==plane and tree.CanvasBackgroundState.PaintBox==paintBox,label..': stable root/canvas identities')
		assert(page.FormModel:Resolve(field)==control and control.Item.Gui==inputGui and control.Item.Editor==editor and editor.Text=='edited😀',label..': native edited value and identity')
		assert(editor.Focused:Count()==focusCount and editor:GetPropertyChangedSignal('Text'):Count()==textCount,label..': original editor connections')
		assert(editor:IsFocused()and input:GetFocusedTextBox()==editor,label..': native adapter focus survives paint/reparent')
		run('if(document.activeElement!==notes||notes.selectionStart!==1||notes.selectionEnd!==8||notes.selectionDirection!=="backward")throw Error("Canvas editor focus/selection");')
	end
	-- Hover handlers commonly set the inherited cursor on the document root.
	-- Its background is a separate retained surface; input-only style changes
	-- must not replace or republish that surface while the pointer is over it.
	local cursorDraws=s:CanvasDrawCount();local cursorMeasurements=measurements
	for _,change in {{'cursor','pointer'},{'cursor','default'},{'cursor',''},{'pointerEvents','none'},{'pointerEvents','auto'},{'userSelect','none'},{'userSelect','auto'}}do
		run('root.style.'..change[1]..'='..string.format('%q',change[2])..';if(root.style.'..change[1]..'!=='..string.format('%q',change[2])..')throw Error("Input style was not committed");')
		if change[1]=='cursor'then
			local cursor=if change[2]==''then'auto'else change[2]
			assert(tree.NodeStyles[s.Html].Cursor==cursor and tree.NodeStyles[s.Body].Cursor==cursor,'The effective pointer styles must retain live cursor inheritance')
		end
		assert(s.Layouts==layouts and measurements==cursorMeasurements,'Root input style changes must not measure or lay out the document')
		assert(s:CanvasDrawCount()==cursorDraws,'Root '..change[1]..' must not republish unchanged canvas paint')
		retained('root '..change[1])
	end
	run('body.style.backgroundColor="rgba(20,80,140,.5)";')
	assert(s:CanvasDrawCount()>cursorDraws,'A real background edit must still republish canvas paint')
	assert(s.Layouts==layouts and plane.BackgroundTransparency==.5 and box.Gui.BackgroundTransparency==1 and tree.NodeBoxes[s.Body].Gui.BackgroundTransparency==1,'Alpha source update is paint-only and paints once');retained('alpha')
	run('root.style.backgroundColor="red";')
	assert(s.Layouts==layouts and s.Root:GetAttribute('CanvasBackgroundSource')=='html'and tree.NodeBoxes[s.Body].Gui.BackgroundTransparency==.5,'Owner change repaints former body without layout');retained('root ownership')
	run('root.style.backgroundColor="transparent";body.style.backgroundColor="rgb(20,80,140)";body.style.opacity=".5";')
	assert(s.Root:GetAttribute('CanvasBackgroundSource')=='body'and not box.OpacityGroup and plane.Parent==s.Root,'Body group does not own propagated canvas');retained('body opacity')
	run('body.style.opacity="1";const first=root.animate({opacity:[1,0]},{duration:100,fill:"both"});first.finished.catch(()=>{});first.ready.catch(()=>{});first.pause();first.currentTime=50;')
	assert(box.OpacityGroup and plane.Parent==box.OpacityGroup.Content and gui.Parent==plane.Parent and math.abs(box.OpacityGroup.Gui.GroupTransparency-.5)<.001 and s.Layouts==layouts,'First direct WAAPI opacity promotes original root and canvas together without layout');retained('first WAAPI promotion')
	run('first.cancel();');assert(box.OpacityGroup.Gui.GroupTransparency==0,'First WAAPI cancellation restores author group opacity')
	run('body.style.opacity="1";root.style.opacity=".5";')
	assert(box.OpacityGroup and plane.Parent==box.OpacityGroup.Content and gui.Parent==plane.Parent,'Root opacity composites canvas and content together')
	local marker=tree.NodeBoxes[Node.findById(s.Document,'marker')];assert(marker.Gui.Parent==tree.NodeBoxes[s.Body].Gui,'Marker remains in original descendant tree')
	local markerPixel=canvasPixel(s,7,7);assert(math.abs(markerPixel[1]-227)<=3 and math.abs(markerPixel[2]-131)<=3,'Overlapping opaque marker is mixed once with UA white');retained('root opacity')
	run('root.style.opacity="1";const anim=root.animate({opacity:[1,0]},{duration:100,fill:"both"});anim.finished.catch(()=>{});anim.ready.catch(()=>{});anim.pause();anim.currentTime=50;')
	assert(math.abs(box.OpacityGroup.Gui.GroupTransparency-.5)<.001 and plane.Parent==box.OpacityGroup.Content and s.Layouts==layouts,'WAAPI direct opacity publication shares existing compositor without layout');retained('WAAPI')
	run('anim.cancel();')
	assert(box.OpacityGroup.Gui.GroupTransparency==0 and realm.EventLoop.FrameCount==0,'Cancellation restores author group opacity and has no idle animation work')
	local before=s:CanvasDrawCount();s:Arrange();assert(s:CanvasDrawCount()==before,'Unchanged local layout does not redraw canvas')
	tree:PublishCanvasBackground(800,600);assert(s:CanvasDrawCount()==before,'Repeated unchanged canvas publication draws nothing')
	s:Arrange(720,500);assert(component(plane.Size,1)==720 and component(plane.Size,2)==500,'Warm viewport resize publishes retained canvas geometry');retained('resize')
	s:Arrange();retained('restored viewport')
	run('root.style.backgroundImage="linear-gradient(red,red)";')
	assert(s.Root:GetAttribute('CanvasBackgroundSource')=='html'and tree.NodeBoxes[s.Body].Gui.BackgroundTransparency==0,'Root image blocks body propagation and restitutes local body paint');retained('root image')
	run('if(root.style.backgroundImage!=="linear-gradient(red,red)"||getComputedStyle(body).backgroundColor!=="rgb(20, 80, 140)")throw Error("Original CSSOM background owners");')
	assert(box.Style==tree.NodeStyles[s.Html]and box.Style.BackgroundImages[1].Kind=='linear'and tree.CanvasBackgroundState.PaintStyle~=box.Style,'Used paint leaves original DOM image style intact')
	for _,change in {{'root','contain','paint','none'},{'body','contain','style','none'},{'root','contentVisibility','auto','visible'},{'body','containerType','inline-size','normal'},{'root','backgroundImage','url("")','none'}}do
		local object,property,value,restore=unpack(change)
		run(object..'.style.'..property..'='..string.format('%q',value)..';');retained('editor '..object..' '..property)
		run(object..'.style.'..property..'='..string.format('%q',restore)..';');retained('editor restored '..object..' '..property)
	end
	run('root.style.backgroundImage="none";body.style.backgroundColor="transparent";')
	assert(s.Root:GetAttribute('CanvasBackgroundSource')==nil and plane.Visible==false and s.Root.BackgroundTransparency==0 and s.Root.BackgroundColor3==Color3.new(1,1,1),'Removing author canvas restores UA surface')
	for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;stop();s:Destroy()
	assert(not realm.Alive and editor.Focused:Count()==0 and editor:GetPropertyChangedSignal('Text'):Count()==0,'Dispose cancels realm and retained editor bindings')
	for _,image in images do assert(image.Destroyed,'All canvas raster textures were disposed')end
	-- The real HTMLPage worker publishes canvas geometry after layout and owns
	-- teardown before the existing background renderer; queued resizes stay stale.
	do
		local queue,time,tree,viewport={},0,nil,nil
		local function enqueue(delay,fn)local job={Due=time+delay,Callback=fn};table.insert(queue,job);return job end
		local tasks={defer=function(fn)return enqueue(0,fn)end,delay=enqueue,cancel=function(job)job.Cancelled=true end,wait=function()error('Small canvas mount should not yield')end}
		-- Only the raster backend is synthetic here. The actual BackgroundSVG,
		-- RenderQueue, BackgroundImages and PageSession own request generations,
		-- texture uploads, ready signals and disposal. SVG suites test real raster.
		local imageResolutions,svgResolutions,svgDraws=0,0,0
		local resolveHook,rasterHook,nativeHook,nativeFault,lastBackground
		local builds,rasters=0,0
		local svgBackend=loadBackgroundSVG({
			['SVG/Embedded']={document=function(node)return node end,build=function(node,w,h)
				builds+=1;local fill=node.Children[1].Attributes.fill;assert(fill=='red'or fill=='blue','Lifecycle resource retains the requested SVG source');return {Width=w,Height=h,Fill=fill}
			end},
			['SVG/Raster']={render=function(scene,_,width,check)
				rasters+=1;if not check()then return nil end;local pixels=buffer.create(width*scene.Height*4)
				for at=0,buffer.len(pixels)-4,4 do buffer.writeu8(pixels,at+(if scene.Fill=='blue'then 2 else 0),255);buffer.writeu8(pixels,at+3,255)end
				if rasterHook then local callback=rasterHook;rasterHook=nil;callback(scene)end;return pixels
			end},
		})
		local newSVG=svgBackend.new
		function svgBackend.new(...)
			local api=newSVG(...);local draw=api.Draw
			function api:Draw(slot,source,...)assert(source~='','Empty URL cannot schedule SVG Draw');svgDraws+=1;return draw(self,slot,source,...)end
			return api
		end
		local resourceBackgrounds=loadBackgroundImages({['Rendering/BackgroundSVG']=svgBackend})
		local module=loadHTMLPage({
			['Rendering/GuiFactory']=factory,['Layout/WordLayout']=overrides['Layout/WordLayout'],['Layout/TextMeasure']=overrides['Layout/TextMeasure'],['Layout/BlockLayout']=layout,
			['Rendering/RenderTree']={build=function(...)local args={...};viewport=args[2];tree=renderer.build(...);return tree end},
			['Rendering/BackgroundImages']={new=function(diagnostic,resolveImage,_,root,options)
				options=table.clone(options);options.Task=tasks;options.Asset={CreateEditableImage=function(_,config)
					if nativeFault=='allocation'then nativeFault=nil;error('expected canvas allocation failure')end
					local image=factory.createImage(config.Size)
					if nativeHook then local callback=nativeHook;nativeHook=nil;callback(image)end
					if nativeFault=='upload'then nativeFault=nil;image.WritePixelsBuffer=function()error('expected canvas upload failure')end end
					return image
				end}
				local resolveSVG=options.ResolveSVG;options.ResolveSVG=function(source)
					assert(source~='','Empty URL cannot resolve a packaged SVG');svgResolutions+=1
					local node=resolveSVG(source);if resolveHook then local callback=resolveHook;resolveHook=nil;callback(source)end;return node
				end
				lastBackground=resourceBackgrounds.new(diagnostic,function(source)assert(source~='','Empty URL cannot resolve an image');imageResolutions+=1;return resolveImage(source)end,factory.createImage,root,options);return lastBackground
			end},
			['Input/Controller']={start=function()end},
		},tasks,function()return time end)
		local host=factory.create('Frame',nil,{})
		local page=module.mount(host,'<!doctype html><html style="margin:0"><head></head><body style="margin:0;height:2000px;background:linear-gradient(red,blue)"></body></html>',{JavaScript=false,RenderWorkBudgetMS=0,ScrollBarThickness=0})
		local function step()local job=table.remove(queue,1);assert(job,'Expected queued page/background work');if not job.Cancelled then time=math.max(time,job.Due);job.Callback()end end
		local function drain()local rounds=0;while #queue>0 do rounds+=1;assert(rounds<20,'Canvas page worker did not settle');step()end end
		drain();assert(page.Alive and page.Presented and viewport:GetAttribute('Status')=='ready','Actual PageSession paints the canvas before presentation')
		local state=tree.CanvasBackgroundState;local plane=state.Gui;local rootBox=tree.NodeBoxes[Canvas.documentRoot(page.Document)]
		assert(not rootBox.OpacityGroup and component(plane.Size,2)>=2000,'Ordinary long page keeps canvas without a full-page CanvasGroup')
		local identity=state.PaintBox;local sourceStyle=tree.NodeStyles[rootBox.Node];local cacheBefore=#images
		viewport.AbsoluteSize=Vector2.new(720,500);viewport:GetPropertyChangedSignal('AbsoluteSize'):Fire();drain()
		assert(state.Gui==plane and state.PaintBox==identity and component(plane.Size,1)==720 and tree.NodeStyles[rootBox.Node]==sourceStyle,'HTMLPage resize publishes retained plane after final geometry')
		assert(#images==cacheBefore+1,'Resized positioning area creates one bounded new gradient texture')
		viewport.AbsoluteSize=Vector2.new(650,450);viewport:GetPropertyChangedSignal('AbsoluteSize'):Fire()
		page:Destroy();drain()
		assert(not page.Alive and not state.Alive and plane.Destroyed and viewport.Destroyed,'PageSession disposes canvas and invalidates a queued publication')
		assert(viewport:GetPropertyChangedSignal('AbsoluteSize'):Count()==0 and viewport:GetPropertyChangedSignal('CanvasPosition'):Count()==0,'PageSession releases canvas viewport and fixed-background listeners')
		for _,image in images do assert(image.Destroyed,'PageSession releases every retained canvas raster once')end
		host:Destroy()
		-- Queue the real SVG background worker behind the first layout. Removing
		-- its owner before raster/upload must not publish the obsolete resource;
		-- PageSession destruction must also invalidate a later pending resize.
		local svgHost=factory.create('Frame',nil,{})
		local svgPage=module.mount(svgHost,'<!doctype html><html style="margin:0"><head></head><body style="margin:0;height:120px;background-color:blue;background-image:url(small.svg);background-size:12px 12px;background-repeat:no-repeat"></body></html>',
			{JavaScript=false,RenderWorkBudgetMS=0,ScrollBarThickness=0,SVGs={['small.svg']='<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12"><rect width="12" height="12" fill="red"/></svg>'}})
		local rounds=0;while viewport:GetAttribute('BackgroundVisibleReady')~=false do rounds+=1;assert(rounds<10,'Canvas SVG did not queue');step()end
		assert(not svgPage.Presented and not viewport.Visible,'Page remains blank while the actual canvas SVG is queued')
		local svgState=tree.CanvasBackgroundState;local svgPlane=svgState.Gui;local body=svgState.OwnerBox.Node;local beforeSVG=#images
		local beforeImageResolution,beforeSVGResolution,beforeSVGDraw=imageResolutions,svgResolutions,svgDraws
		body.Attributes.style='margin:0;height:120px;background-color:blue;background-image:url("")'
		assert(not tree:ApplyDOMChanges({[body]={Attributes={style=true}}}),'Removing a canvas image is paint-only')
		drain();assert(svgPage.Presented and #images==beforeSVG,'Removed queued SVG never allocates/uploads and releases initial presentation')
		assert(imageResolutions==beforeImageResolution and svgResolutions==beforeSVGResolution and svgDraws==beforeSVGDraw,'Pending SVG replaced by empty URL is cancelled without resolver/Draw work')
		body.Attributes.style='margin:0;height:120px;background-color:blue;background-image:url(small.svg);background-size:12px 12px;background-repeat:no-repeat'
		assert(not tree:ApplyDOMChanges({[body]={Attributes={style=true}}}),'Restoring a canvas SVG is paint-only');drain()
		assert(#images==beforeSVG+1 and images[#images].Pixels,'Live canvas SVG installs one actual raster buffer')
		local svgImage=images[#images];assert(buffer.readu8(svgImage.Pixels,0)==255 and buffer.readu8(svgImage.Pixels,1)==0,'Installed canvas SVG contains the source red pixel')
		local svgRoot=Canvas.documentRoot(svgPage.Document);local savedRootStyle=svgRoot.Attributes.style
		local hoverResolutions,hoverDraws,hoverBuilds,hoverRasters,hoverImages=imageResolutions+svgResolutions,svgDraws,builds,rasters,#images
		for _,cursor in {'pointer','default','pointer','auto'}do
			svgRoot.Attributes.style=savedRootStyle..';cursor:'..cursor
			assert(not tree:ApplyDOMChanges({[svgRoot]={Attributes={style=true}}}),'Cursor changes on a page with an SVG background are paint-only')
			drain()
			assert(svgPage.Presented and viewport:GetAttribute('BackgroundVisibleReady')==true and not svgImage.Destroyed,'Cursor changes retain the ready SVG surface')
			assert(imageResolutions+svgResolutions==hoverResolutions and svgDraws==hoverDraws and builds==hoverBuilds and rasters==hoverRasters and #images==hoverImages,'Cursor changes must not resolve, queue, raster or upload an unchanged canvas SVG')
		end
		body.Attributes.style='margin:0;height:120px;background-color:blue;background-image:url(small.svg);background-size:20px 20px;background-repeat:no-repeat'
		assert(not tree:ApplyDOMChanges({[body]={Attributes={style=true}}}),'Canvas SVG resize remains paint-only')
		assert(viewport:GetAttribute('BackgroundVisibleReady')==false and #queue>0,'New canvas SVG positioning size is actually pending')
		svgPage:Destroy();drain()
		assert(not svgState.Alive and svgPlane.Destroyed and svgImage.Destroyed and #images==beforeSVG+1,'Disposed pending SVG cannot upload/revive canvas or allocate another image')
		assert(viewport:GetAttributeChangedSignal('BackgroundVisibleReady'):Count()==0,'PageSession removes canvas background readiness listeners')
		svgHost:Destroy()
		local redSVG='<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12"><rect width="12" height="12" fill="red"/></svg>'
		local blueSVG=redSVG:gsub('fill="red"','fill="blue"')
		local function style(source,size)return 'margin:0;height:120px;background-color:white;background-image:url('..source..');background-size:'..(size or 12)..'px '..(size or 12)..'px;background-repeat:no-repeat'end
		local function mounted(source,rootOwned,existingHost)
			local target=existingHost or factory.create('Frame',nil,{})
			local html='<html style="'..(if rootOwned then style(source)else'margin:0')..'"><head></head><body style="'..(if rootOwned then 'margin:0;height:120px'else style(source))..'"></body></html>'
			local first=#images+1
			local page=module.mount(target,'<!doctype html>'..html,{JavaScript=false,RenderWorkBudgetMS=0,ScrollBarThickness=0,SVGs={['red.svg']=redSVG,['blue.svg']=blueSVG,['invalid.svg']='<div>no svg root</div>'}})
			return {Page=page,Host=target,Tree=tree,Root=viewport,First=first,Background=lastBackground}
		end
		local function capture(p)
			p.State=p.Tree.CanvasBackgroundState;p.Plane=p.State.Gui;p.PaintBox=p.State.PaintBox
			p.Html=Canvas.documentRoot(p.Page.Document);p.Body=Node.findElement(p.Html,function(node)return node.Name=='body'end)
		end
		local function pending(p)
			local turns=0;while p.Root:GetAttribute('BackgroundVisibleReady')~=false do turns+=1;assert(turns<10,'Expected a real pending canvas SVG');step()end;capture(p)
		end
		local function repaint(p,node,value)
			node.Attributes.style=value;assert(not p.Tree:ApplyDOMChanges({[node]={Attributes={style=true}}}),'Resource mutation must remain paint-only')
		end
		local function content(p)
			for _,gui in guis do
				if gui.Name=='BackgroundImage'and not gui.Destroyed and gui.Parent and gui.Parent.Parent==p.Plane and gui.ImageContent and not gui.ImageContent.Destroyed then return gui.ImageContent end
			end
			return nil
		end
		local function settled(p,color,size)
			assert(p.Page.Alive and p.Page.Presented and p.Root:GetAttribute('BackgroundVisibleReady')==true,'Current page presents after all background work settles')
			assert(p.Tree.CanvasBackgroundState==p.State and p.State.Gui==p.Plane and p.State.PaintBox==p.PaintBox,'Resource completion retains current canvas identities')
			local image=assert(content(p),'Current resource must install an image')
			assert(image.Size.X==size and image.Size.Y==size and buffer.readu8(image.Pixels,if color=='blue'then 2 else 0)==255,'Only the latest source and size may install')
			return image
		end
		local function dispose(p,destroyHost)
			p.Page:Destroy();p.Page:Destroy();drain()
			for i=p.First,#images do assert(images[i].Destroyed,'Retired page releases every native canvas texture exactly once')end
			assert(not p.State.Alive and p.Plane.Destroyed and p.Root:GetAttributeChangedSignal('BackgroundVisibleReady'):Count()==0,'Retired page releases plane and readiness observers')
			if destroyHost~=false then p.Host:Destroy()end
		end
		-- A resolver can call author/host code before the SVG queue owns its slot.
		-- Its returning node is obsolete after removal, page teardown or a nested draw.
		for _,action in {'remove','replace','owner','destroy'}do
			local p=mounted('red.svg',action=='owner');pending(p);drain();settled(p,'red',12)
			local before=#images;local abandoned
			resolveHook=function()
				if action=='destroy'then p.Page:Destroy()
				elseif action=='remove'then repaint(p,p.Body,'margin:0;height:120px;background:none')
				elseif action=='owner'then
					p.Html.Attributes.style='margin:0;height:120px;background:none';p.Body.Attributes.style=style('blue.svg',20)
					assert(not p.Tree:ApplyDOMChanges({[p.Html]={Attributes={style=true}},[p.Body]={Attributes={style=true}}}))
				else repaint(p,p.Body,style('blue.svg',20))end
			end
			repaint(p,if action=='owner'then p.Html else p.Body,style('red.svg',16));drain()
			if action=='owner'then
				settled(p,'blue',20);assert(p.State.Plan.Owner==p.Body and p.Root:GetAttribute('CanvasBackgroundSource')=='body','Outer publication cannot restore the obsolete root owner')
			elseif action=='replace'then settled(p,'blue',20);assert(#images==before+1,'Only the nested replacement may allocate')
			else assert(#images==before,'Retired SVG resolution must not create another queue/image')end
			dispose(p)
		end
		-- Coalescing before rasterization must keep only the latest source, size
		-- and html/body paint owner. Missing loads also release initial readiness.
		for _,change in {'source','size','owner','missing','invalid'}do
			local p=mounted('red.svg',change=='owner');pending(p);local before=#images
			if change=='owner'then
				p.Html.Attributes.style='margin:0;height:120px;background:none';p.Body.Attributes.style=style('blue.svg',20)
				assert(not p.Tree:ApplyDOMChanges({[p.Html]={Attributes={style=true}},[p.Body]={Attributes={style=true}}}))
			else repaint(p,p.Body,style(if change=='missing'then 'absent.svg'elseif change=='invalid'then'invalid.svg'elseif change=='source'then 'blue.svg'else'red.svg',20))end
			drain()
			if change=='missing'or change=='invalid'then
				assert(p.Page.Presented and p.Root:GetAttribute('BackgroundVisibleReady')==true and #images==before,'Missing source cancels pending raster and cannot hold presentation')
				assert(#p.Page.Document.Diagnostics==1 and p.Page.Document.Diagnostics[1].Message:find(if change=='missing'then'absent.svg'else'invalid.svg',1,true),'Failed source is diagnosed on its own page')
			else
				settled(p,if change=='size'then'red'else'blue',20);assert(#images==before+1,'Pending changes coalesce to one native image')
				if change=='owner'then assert(p.State.Plan.Owner==p.Body and p.Root:GetAttribute('CanvasBackgroundSource')=='body','Nested canvas owner publishes the current plan')end
			end
			dispose(p)
		end
		-- These callbacks return a completed old raster deliberately. The real
		-- queue must reject it after source/size/owner changes or page replacement.
		for _,change in {'source','size','owner','remove','destroy','page-replacement'}do
			local p=mounted('red.svg',change=='owner');pending(p);local before=#images;local replacement
			rasterHook=function(scene)
				assert(scene.Fill=='red','Late callback belongs to the old red request')
				if change=='page-replacement'then p.Page:Destroy();replacement=mounted('blue.svg',false,p.Host)
				elseif change=='destroy'then p.Page:Destroy()
				elseif change=='remove'then repaint(p,p.Body,'margin:0;height:120px;background:none')
				elseif change=='owner'then
					p.Html.Attributes.style='margin:0;height:120px;background:none';p.Body.Attributes.style=style('blue.svg',20)
					assert(not p.Tree:ApplyDOMChanges({[p.Html]={Attributes={style=true}},[p.Body]={Attributes={style=true}}}))
				else repaint(p,p.Body,style(if change=='source'then'blue.svg'else'red.svg',20))end
			end
			drain()
			if replacement then
				capture(replacement);local current=settled(replacement,'blue',12)
				assert(not p.Page.Alive and not p.State.Alive and p.Plane.Destroyed and current==images[#images]and #images==before+1,'Late old page cannot publish into or allocate alongside its replacement')
				dispose(replacement,false);dispose(p)
			elseif change=='destroy'or change=='remove'then
				assert(#images==before,'Removed late raster never allocates a texture');dispose(p)
			else
				settled(p,if change=='size'then'red'else'blue',20);assert(#images==before+1,'Only latest late-raster replacement uploads')
				if change=='owner'then assert(p.State.Plan.Owner==p.Body and p.Root:GetAttribute('CanvasBackgroundSource')=='body')end
				dispose(p)
			end
		end
		-- Native allocation returns after its owner can already have been retired.
		for _,change in {'destroy','remove','replace'}do
			local p=mounted('red.svg');pending(p);local before=#images;local abandoned
			nativeHook=function(image)
				abandoned=image
				if change=='destroy'then p.Page:Destroy()
				elseif change=='remove'then repaint(p,p.Body,'margin:0;height:120px;background:none')
				else repaint(p,p.Body,style('blue.svg',20))end
			end
			drain();assert(abandoned and abandoned.Destroyed and not abandoned.Pixels,'Retired native SVG allocation must free once before any upload')
			if change=='replace'then settled(p,'blue',20);assert(#images==before+2,'Only the replacement allocation may upload')
			else assert(#images==before+1,'Retired native allocation cannot requeue itself')end
			dispose(p)
		end
		for _,fault in {'allocation','upload'}do
			local p=mounted('red.svg');pending(p);drain();local old=settled(p,'red',12);local before=#images
			nativeFault=fault;repaint(p,p.Body,style('blue.svg',20));drain()
			assert(p.Page.Alive and p.Page.Presented and p.Root:GetAttribute('BackgroundVisibleReady')==true,'Failed native work settles without trapping its current page')
			assert(old.Destroyed and not content(p),'A failed replacement releases the former image and publishes no failed texture')
			assert(#images==before+(if fault=='upload'then 1 else 0),'Failed allocation creates none; failed upload owns one cleanup handle')
			if fault=='upload'then assert(images[#images].Destroyed,'Failed native upload frees its own allocation once')end
			local diagnostics=p.Page.Document.Diagnostics;assert(#diagnostics==1 and diagnostics[1].Message:find('expected canvas '..fault..' failure',1,true),'Failed native work is diagnosed on its current page')
			-- Same source/key retry uses RenderQueue.Failed, without a second cache.
			p.Background:Draw(p.PaintBox,p.PaintBox.OuterWidth,p.PaintBox.OuterHeight);drain();settled(p,'blue',20)
			dispose(p)
		end
		-- Retain a single native texture and the existing CPU queue frames. An
		-- unchanged pending draw must not invalidate its original install closure.
		do
			local p=mounted('red.svg');pending(p);local before=#images;local beforeBuild,beforeRaster=builds,rasters
			for _=1,3 do p.Background:Draw(p.PaintBox,p.PaintBox.OuterWidth,p.PaintBox.OuterHeight)end
			drain();local first=settled(p,'red',12)
			assert(#images==before+1 and builds==beforeBuild+1 and rasters==beforeRaster+1,'Unchanged pending draws share one scene, raster and allocation')
			repaint(p,p.Body,style('blue.svg'));drain();assert(settled(p,'blue',12)==first,'Equal dimensions reuse the existing native texture')
			local afterBuild,afterRaster=builds,rasters
			repaint(p,p.Body,style('red.svg'));drain();assert(settled(p,'red',12)==first and builds==afterBuild and rasters==afterRaster,'Returning source reuses the existing bounded queue frame')
			assert(#images==before+1,'Source switching never creates a parallel native cache');dispose(p)
		end
		print('Canvas image resources: 4 resolver retirements, 5 pending mutations, 6 deliberately late raster completions, 3 retired native allocations, 2 native failures/retries and retained cache controls passed')
	end
	print('Canvas backgrounds: '..cases..' native initial cases, '..dynamicSnapshots..' mounted dynamic snapshots, '..ownerStates..' actual-root/first-body states, '..liveStates..' independent live states, 3 grouped-root replacements/removal/reinsertion, '..pixels..' retained-buffer pixel probes, '..#fixture.computedImages.rows..' independent computed-image references; 4 transformed initial captures and 2 local frameset pixels remain unchecked; live CSSOM/focused editor/WAAPI/resize ownership and cleanup passed')
end
