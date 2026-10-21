--!strict
-- Native transparent text avoids any dependence on platform glyph pixels.
-- Compare actual retained GUI background paint with independent Chromium RGBA.
return function(Parser,Node,Canvas,BackgroundImages,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,fixture)
	local function signal()local api={};function api:Connect()return {Disconnect=function()end}end;function api:Fire()end;return api end
	local guis={};local factory={}
	function factory.create(class,parent,properties)
		local gui={ClassName=class,Parent=parent,Visible=true,BackgroundTransparency=1,BackgroundColor3=Color3.new(1,1,1),Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(0,0),AbsoluteSize=Vector2.new(800,600),AbsolutePosition=Vector2.new(0,0),ZIndex=1,Destroying=signal(),Focused=signal(),FocusLost=signal(),InputBegan=signal()}
		for key,value in properties do gui[key]=value end
		function gui:GetChildren()local children={};for _,child in guis do if child.Parent==self and not child.Destroyed then table.insert(children,child)end end;return children end
		function gui:IsA(kind)return kind==class or kind=='GuiObject'end
		function gui:SetAttribute()end;function gui:GetAttribute()return nil end
		function gui:GetPropertyChangedSignal()return signal()end
		function gui:Destroy()assert(not self.Destroyed,'Inline canvas GUI freed twice');self.Destroyed=true;for _,child in self:GetChildren()do child:Destroy()end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new((utf8.len(text)or 0)*size*.45,size)end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local function component(value,index)local part=if index==1 then value.X else value.Y;return if part then part.Offset else value[index]or 0 end
	local function dimension(gui,index)local d=gui.Size;local scale=if index==1 then d.XScale or 0 else d.YScale or 0;return component(d,index)+scale*(if gui.Parent then dimension(gui.Parent,index)else 0)end
	local function over(a,b)local alpha=a[4]+b[4]*(1-a[4]);if alpha==0 then return {0,0,0,0}end;return{(a[1]*a[4]+b[1]*b[4]*(1-a[4]))/alpha,(a[2]*a[4]+b[2]*b[4]*(1-a[4]))/alpha,(a[3]*a[4]+b[3]*b[4]*(1-a[4]))/alpha,alpha}end
	local function sample(gui,x,y)
		if gui.Destroyed or not gui.Visible then return {0,0,0,0}end
		local w,h=dimension(gui,1),dimension(gui,2);local inside=x>=0 and y>=0 and x<w and y<h
		if gui.ClipsDescendants and not inside then return{0,0,0,0}end
		local c=gui.BackgroundColor3;local color=if inside then{c.R*255,c.G*255,c.B*255,1-gui.BackgroundTransparency}else{0,0,0,0}
		local children=gui:GetChildren();table.sort(children,function(a,b)if a.ZIndex~=b.ZIndex then return a.ZIndex<b.ZIndex end;return table.find(guis,a)<table.find(guis,b)end)
		for _,child in children do local p=child.Position;color=over(sample(child,x-component(p,1)-(p.XScale or 0)*w,y-component(p,2)-(p.YScale or 0)*h),color)end
		if gui.ClassName=='CanvasGroup'then color[4]*=1-(gui.GroupTransparency or 0)end;return color
	end
	local states=0
	for _,reference in fixture.rows do
		local document=Parser.parseDocument(reference.html);local viewport=factory.create('ScrollingFrame',nil,{Size=UDim2.fromOffset(800,600),BackgroundTransparency=0})
		local backgrounds=BackgroundImages.new(error,nil,function()error('Solid inline backgrounds must not allocate raster images')end,viewport)
		local tree=renderer.build(document,viewport,error,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,backgrounds)
		local layouts=0
		local function arrange(items)layouts+=1;tree:SetMediaEnvironment(800,600);tree.ViewportHeight=600;Dirty.begin(tree,items);local h=layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true);tree:PublishCanvasBackground(800,math.max(600,h))end
		arrange();local plane=tree.CanvasBackgroundState.Gui;local root=Canvas.documentRoot(document);local retained={}
		for _,item in tree.TextItems do retained[item]=item.Gui end
		local events=Events.new(error);local realm=Runtime.new(document,{Events=events,Diagnostic=error,ApplyChanges=function(changes)return tree:ApplyDOMChanges(changes)end,
			GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return{Width=800,Height=600}end}})
		local function run(code)local ok,message=realm:Run(code);assert(ok,tostring(message));local needed,items=realm:Flush();if needed then arrange(items)end end
		local function check(state,label)
			for _,pair in{{'root','document.documentElement'},{'body','document.body'},{'span','document.querySelector("span")'}}do if state.snapshot[pair[1]]then for _,property in{'display','backgroundColor','backgroundImage'}do run('if(getComputedStyle('..pair[2]..').'..property..'!=='..string.format('%q',state.snapshot[pair[1]][property])..')throw Error('..string.format('%q',label..' '..pair[1]..' '..property)..');')end end end
			assert(tree.CanvasBackgroundState.Gui==plane and not plane.Destroyed,label..': inline owner changes retained canvas')
			for item,gui in retained do assert(item.Gui==gui and not gui.Destroyed,label..': background owner changes must retain native word GUIs')end
			local originals={};for _,style in tree.NodeStyles do originals[style]={style.Background,style.BackgroundAlpha,style.BackgroundImages,style.InlineBackground,style.InlineBackgroundAlpha}end
			for style,before in originals do Canvas.inlineBackground(style);assert(style.Background==before[1]and style.BackgroundAlpha==before[2]and style.BackgroundImages==before[3]and style.InlineBackground==before[4]and style.InlineBackgroundAlpha==before[5],label..': used inline projection changed computed source backgrounds')end
			-- Chromium paints an inline BODY twice. Keep those raw observations
			-- separate and compare the frozen single-paint canvas counterpart.
			for _,pixel in state.normativeSinglePaint.pixels do local actual=sample(viewport,pixel.point[1],pixel.point[2]);for channel=1,3 do assert(math.abs(actual[channel]-pixel.rgba[channel])<=2,label..' double/absent background channel '..channel..' at '..pixel.point[1]..','..pixel.point[2]..': '..actual[channel]..' ~= '..pixel.rgba[channel])end end
			states+=1
		end
		check(reference.initial,reference.id..' initial')
		for index,state in reference.dynamic do
			local before=layouts;run(state.script);check(state,reference.id..' mutation '..index)
			if reference.id=='inline-body-late-background'then assert(layouts==before,'First background, removal and warm restoration repaint retained words without layout')end
		end
		realm:Destroy();events:Destroy();tree:DestroyCanvasBackground();backgrounds:Destroy();tree.VisualEffects:Destroy();viewport:Destroy()
	end
	assert(states==16,'Every inline native state must run')
	local fragmentStates=0
	for _,display in {'inline','inline-block','actual-root'}do
		local document
		local css='font-size:20px;line-height:30px;color:transparent;background:rgba(20,80,140,.5);width:80px;height:30px;display:'..(if display=='actual-root'then'inline-block'else display)
		if display=='actual-root'then document=Node.document();local span=Node.element('span',{id='local',style=css});Node.append(span,Node.text('AAAA'));Node.append(document,span)
		else document=Parser.parse('<span id="local" style="'..css..'">AAAA</span>')end
		local span=Node.findById(document,'local');local whole=display=='actual-root'
		local viewport=factory.create('ScrollingFrame',nil,{Size=UDim2.fromOffset(800,600),BackgroundTransparency=0})
		local backgrounds=BackgroundImages.new(error,nil,function()error('Local solid paint must not rasterize')end,viewport)
		local tree=renderer.build(document,viewport,error,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,backgrounds)
		local function arrange(items)tree:SetMediaEnvironment(800,600);tree.ViewportHeight=600;Dirty.begin(tree,items);local h=layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true);tree:PublishCanvasBackground(800,math.max(600,h))end
		arrange();local retained={};for _,item in tree.TextItems do retained[item]=item.Gui end
		local box=tree.NodeBoxes[span];local boxGui=box and box.Gui;local plane=tree.CanvasBackgroundState and tree.CanvasBackgroundState.Gui
		assert((plane~=nil)==whole,display..': only an actual document may create a canvas plane')
		assert(tree.NodeStyles[span].Display==(if whole then'block'else display),display..': fragment display and actual-root blockification remain distinct')
		local events=Events.new(error);local realm=Runtime.new(document,{Events=events,Diagnostic=error,ApplyChanges=function(changes)return tree:ApplyDOMChanges(changes)end})
		local function check(expected)
			for item,gui in retained do assert(item.Gui==gui and not gui.Destroyed,display..': repaint retains each word GUI')end
			assert((box and box.Gui)==boxGui and(not box or box.CanvasBackgroundSuppressed==whole or not whole and box.CanvasBackgroundSuppressed==nil),display..': local paint cannot acquire canvas suppression')
			for _,point in{{5,10},{400,300}}do local actual=sample(viewport,point[1],point[2]);for channel=1,3 do local wanted=if whole or point[1]==5 then expected[channel]else 255;assert(math.abs(actual[channel]-wanted)<=2,display..': local/canvas alpha at '..point[1]..','..point[2]..' channel '..channel..': '..actual[channel]..' ~= '..wanted)end end
			fragmentStates+=1
		end
		check({137.5,167.5,197.5})
		for _,change in{{'rgba(200,10,10,.25)',{241.25,193.75,193.75}},{'transparent',{255,255,255}},{'rgba(20,80,140,.5)',{137.5,167.5,197.5}}}do
			local ok,message=realm:Run('document.getElementById("local").style.backgroundColor='..string.format('%q',change[1]));assert(ok,tostring(message));local needed,items=realm:Flush();if needed then arrange(items)end;check(change[2])
		end
		realm:Destroy();events:Destroy();tree:DestroyCanvasBackground();backgrounds:Destroy();tree.VisualEffects:Destroy();viewport:Destroy()
	end
	assert(fragmentStates==12,'All local fragment and actual-root paint states must run')
	local acquisitionStates=0
	for _,origin in {'initially-empty','legacy-open'}do
		local document=if origin=='initially-empty'then Node.document()else Parser.parse('<span style="display:inline-block;width:80px;height:30px;color:transparent;background:rgba(20,80,140,.5)">AAAA</span>')
		local viewport=factory.create('ScrollingFrame',nil,{Size=UDim2.fromOffset(800,600),BackgroundTransparency=0})
		local backgrounds=BackgroundImages.new(error,nil,function()error('Acquiring solid canvas paint must not rasterize')end,viewport)
		local tree=renderer.build(document,viewport,error,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,backgrounds)
		local function arrange(candidate,items)candidate:SetMediaEnvironment(800,600);candidate.ViewportHeight=600;Dirty.begin(candidate,items);local h=layout.arrange(candidate,800,0,0,function()return true end);Dirty.finish(candidate,true);candidate:PublishCanvasBackground(800,math.max(600,h))end
		arrange(tree);local documentGui=tree.Gui;local initialPlane=tree.CanvasBackgroundState and tree.CanvasBackgroundState.Gui
		assert((initialPlane~=nil)==(origin=='initially-empty'),origin..': an empty actual document owns a hidden plane; a legacy host owns none')
		assert(not initialPlane or not initialPlane.Visible,origin..': the initially empty canvas stays hidden')
		assert(sample(viewport,400,300)[1]==255 and viewport.BackgroundTransparency==0,origin..': initial canvas acquisition preserves the host surface')
		local events=Events.new(error);local realm=Runtime.new(document,{Events=events,Diagnostic=error,ApplyChanges=function(changes)return tree:ApplyDOMChanges(changes)end})
		local function run(code)local ok,message=realm:Run(code);assert(ok,tostring(message));local needed,items=realm:Flush();if needed then arrange(tree,items)end end
		if origin=='initially-empty'then
			local root=Node.element('span',{style='display:inline-block;width:80px;height:30px;color:transparent;background:rgba(20,80,140,.5)'});Node.append(root,Node.text('AAAA'));Node.append(document,root)
			local _,items=tree:ApplyDOMChanges({[document]={Children=true}});arrange(tree,items)
		else
			run([=[document.open();document.write('<html style="background:rgba(20,80,140,.5);color:transparent"><body>AAAA</body></html>');document.close();]=])
			assert(not document.LegacyFragment,'document.open must convert its legacy host into an actual parsed document')
		end
		local root=Canvas.documentRoot(document);local plane=assert(tree.CanvasBackgroundState,'First actual root must acquire document canvas state').Gui
		assert(not initialPlane or plane==initialPlane,origin..': first root insertion retains the initially empty document plane')
		local function check(expected,present)
			assert(tree.Gui==documentGui and tree.CanvasBackgroundState.Gui==plane and not plane.Destroyed,origin..': root edits retain the document GUI and canvas plane')
			assert(plane.Visible==present,origin..': a missing root hides the plane')
			local freshViewport=factory.create('ScrollingFrame',nil,{Size=UDim2.fromOffset(800,600),BackgroundTransparency=0})
			local freshBackgrounds=BackgroundImages.new(error,nil,function()error('Fresh solid canvas paint must not rasterize')end,freshViewport)
			local fresh=renderer.build(Node.cloneNode(document,true),freshViewport,error,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,freshBackgrounds);arrange(fresh)
			for _,point in{{5,10},{400,300}}do local actual=sample(viewport,point[1],point[2]);local full=sample(freshViewport,point[1],point[2]);for channel=1,3 do
				assert(math.abs(actual[channel]-expected[channel])<=2,origin..': acquired/restored whole-canvas alpha at '..point[1]..','..point[2]..' channel '..channel)
				assert(math.abs(actual[channel]-full[channel])<=.01,origin..': retained root edits must match a fresh complete render')
			end end
			fresh:DestroyCanvasBackground();freshBackgrounds:Destroy();fresh.VisualEffects:Destroy();freshViewport:Destroy();acquisitionStates+=1
		end
		check({137.5,167.5,197.5},true)
		local oldBox=assert(tree.NodeBoxes[root]);local oldGui=oldBox.Gui;local oldWords={};for _,item in tree.TextItems do oldWords[item.Gui]=true end
		Node.removeChild(document,root);local _,items=tree:ApplyDOMChanges({[document]={Children=true}});arrange(tree,items)
		assert(oldGui.Destroyed,origin..': removing the root retires its old native box')
		for gui in oldWords do assert(gui.Destroyed,origin..': removing the root retires its old native word GUIs')end
		check({255,255,255},false)
		Node.append(document,root);local _,restored=tree:ApplyDOMChanges({[document]={Children=true}});arrange(tree,restored)
		local restoredGui=tree.NodeBoxes[root].Gui;assert(restoredGui~=oldGui and not restoredGui.Destroyed,origin..': reinsertion uses a new live root box')
		check({137.5,167.5,197.5},true)
		local words={};for _,item in tree.TextItems do words[item]=item.Gui end
		run('document.documentElement.style.backgroundColor="rgba(200,10,10,.25)";')
		assert(tree.NodeBoxes[root].Gui==restoredGui and tree.NodeBoxes[root].CanvasBackgroundSuppressed,origin..': later paint retains and suppresses the actual root box')
		for item,gui in words do assert(item.Gui==gui and not gui.Destroyed,origin..': later alpha edits retain restored word GUIs')end
		check({241.25,193.75,193.75},true)
		realm:Destroy();events:Destroy();tree:DestroyCanvasBackground();backgrounds:Destroy();tree.VisualEffects:Destroy();viewport:Destroy()
	end
	assert(acquisitionStates==8,'Both empty-document and document.open canvas acquisition must run through removal, reinsertion and repaint')
	assert(not Canvas.isDocument(Node.documentFragment()),'The explicit renderer fragment adapter cannot acquire document canvas state')
	print('Canvas inline backgrounds: 16 independent native states plus 12 retained local-fragment/actual-root alpha states and 8 empty/conversion lifetime states passed')
end
