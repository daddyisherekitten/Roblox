--!strict
return function(Parser,Node,Runtime,Events,Storage,html,css,app,loadRenderTree,loadWordLayout,loadBlockLayout,loadCatalog,hubHTML,hubCSS,hubApp,HitTest,HTMLAnimations,svgSources)
	for source,value in svgSources do svgSources[source]=Parser.parse(value).Children[1]end
	local document=Parser.parseDocument(html);assert(#document.Diagnostics==0)
	local time=100;local diagnostics={};local events=Events.new(function(v)table.insert(diagnostics,v)end)
	local area=Storage.createArea()
	local difficulty=require('Controls/State').create(Node.findById(document,'difficulty'))
	local model=require('Controls/FormModel').new(document,{difficulty},events,function()end)
	local renderChanges,paintFrame
	local runtime=Runtime.new(document,{Clock=function()return time end,Events=events,
		URL='http://localhost:8000/memory/index.html',
		LoadImage=function(reference,complete,spec)
			local asset=svgSources[spec.Source or reference];assert(asset,'Memory image is packaged: '..reference)
			local width,height=require('SVG/Sizing').source(asset);complete(true,{Width=width,Height=height,SVG=asset})
		end,
		ScriptSources={['http://localhost:8000/memory/app.js']=app},
		ControlAdapter={Events=events,FocusControl=function()end,
			ResolveControl=function(node)return if node==difficulty.Node then difficulty else nil end,
			SetControlValue=function(node,value)assert(node==difficulty.Node);model:SetValue(difficulty,value)end},
		GetControl=function(node)return if node==difficulty.Node then difficulty.Value else nil end,
		SetControl=function(node,_,value)assert(node==difficulty.Node);model:SetValue(difficulty,value)end,
		GetStorageArea=function()return area end,Click=function(node)events:Emit(node,'click')end,
		Schedule=function()end,ApplyChanges=function(changes)if renderChanges then renderChanges(changes)end;return false end,Diagnostic=function(v)table.insert(diagnostics,v)end})
	local function run(source)local ok,message=runtime:Run(source);assert(ok,tostring(message));runtime:Flush();assert(#diagnostics==0,table.concat(diagnostics,' | '))end
	run('Math.random=function(){return .999999;};');runtime:Start();runtime:PumpTasks();runtime:Flush()
	assert(runtime.ScriptsRun==1 and #diagnostics==0,'The actual HTML defer script starts once')
	local function text(id)return Node.textContent(assert(Node.findById(document,id),id))end
	local function buttons()
		local out={};local function visit(node)
			if node.Attributes and node.Attributes.class=='tile-button'then table.insert(out,node)end
			for _,child in node.Children do visit(child)end
		end;visit(document);return out
	end
	local function clickCard(index)events:Emit(buttons()[index+1],'click');runtime:Flush();assert(#diagnostics==0,table.concat(diagnostics,' | '))end
	local function click(id)run("document.getElementById('"..id.."').click();")end
	local function open(index)return buttons()[index+1].Attributes['aria-pressed']=='true'end
	local function advance(seconds)
		time+=seconds
		if paintFrame then paintFrame()end
		for _=1,32 do local tasks=runtime:PumpTasks();runtime:Flush();if tasks==0 then break end end
		if paintFrame then paintFrame()end
		assert(#diagnostics==0,table.concat(diagnostics,' | '))
	end
	assert(#buttons()==16 and text('pairs')=='0 / 8'and text('time')=='00:00')
	assert(runtime.EventLoop.TimerCount==0,'Untouched board has no timer')
	local retained=buttons()[1].Parent
	clickCard(0);clickCard(0);assert(text('moves')=='0'and open(0),'No self-pair')
	advance(.4);clickCard(2);clickCard(4)
	assert(text('moves')=='1'and open(0)and open(2)and not open(4),'Mismatch prevents third card')
	advance(.2);click('pause');advance(5)
	assert(Node.findById(document,'board').Attributes.inert~=nil and open(0)and open(2),'Pause freezes mismatch')
	assert(text('time')=='00:00'and runtime.EventLoop.TimerCount==0,'Pause stops timers')
	click('resume');advance(.64);assert(open(0)and open(2))
	advance(.02);assert(not open(0)and not open(2),'Resume uses remaining delay')
	clickCard(0);assert(open(0),'A previously mismatched card can reopen');clickCard(1)
	assert(text('pairs')=='1 / 8'and text('moves')=='2','Reopened cards can subsequently form a pair')
	click('restart');assert(buttons()[1].Parent==retained,'Restart retains card nodes')
	clickCard(0);clickCard(1);assert(text('pairs')=='1 / 8'and text('moves')=='1')
	clickCard(0);assert(text('moves')=='1','Matched cards stay inert')
	clickCard(2);clickCard(4);click('restart');advance(2)
	assert(text('moves')=='0'and not open(0)and runtime.EventLoop.TimerCount==0,'No stale restart tasks')
	local function size(count)run("document.getElementById('difficulty').value='"..count.."';document.getElementById('difficulty').dispatchEvent(new Event('change'));")end
	size(6);assert(#buttons()==12)
	for i=0,10,2 do clickCard(i);advance(.2);clickCard(i+1)end
	assert(text('pairs')=='6 / 6'and text('moves')=='6'and runtime.EventLoop.TimerCount==0,'Win stops the clock')
	assert(Node.findById(document,'result').Attributes.hidden==nil and text('result-title')=='Deine neue Bestmarke.')
	run("window.savedMoves=JSON.parse(localStorage.getItem('spielraum.memory.records.v1'))['6'].moves;")
	assert(runtime.Window.Get('savedMoves')==6,'Actual storage saves the record')
	click('clear-record');assert(text('best-moves')=='Noch ganz offen.'and Node.findById(document,'clear-record').Attributes.hidden~=nil)
	run("window.clearedRecord=JSON.parse(localStorage.getItem('spielraum.memory.records.v1'))['6']===undefined;")
	assert(runtime.Window.Get('clearedRecord')==true and text('moves')=='6','Record deletion preserves the round')
	local finishedTime=text('time');advance(10);assert(text('time')==finishedTime)
	click('play-again');assert(text('moves')=='0'and #buttons()==12)
	size(12);assert(#buttons()==24)
	for _=1,5 do click('restart')end
	assert(runtime.EventLoop.TimerCount==0,'Idle restarts retain no timers');size(8)
	local factory={create=function(class,parent,props)
		local gui=table.clone(props);gui.Parent=parent;gui.ClassName=class;gui.Visible=gui.Visible~=false;gui.Destroy=function()end
		gui.Position=gui.Position or UDim2.fromOffset(0,0);gui.AnchorPoint=gui.AnchorPoint or Vector2.new(0,0)
		gui.BackgroundColor3=gui.BackgroundColor3 or Color3.new(1,1,1);gui.BackgroundTransparency=gui.BackgroundTransparency or 1
		gui.ZIndex=gui.ZIndex or 1
		local attributes={};function gui:SetAttribute(key,value)attributes[key]=value end;function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=='GuiObject'end
		return gui
	end}
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(value,_,size)return {X=(utf8.len(value)or 0)*size*.45,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local Dirty=require('Layout/DirtyLayout')
	for _,count in {8,12}do
		size(count)
	for _,width in {320,480,1080}do
		local warnings={};local tree=renderer.build(document,factory.create('Frame',nil,{AbsoluteSize=Vector2.new(width,900)}),function(v)table.insert(warnings,v)end,nil,nil,nil,nil,nil,nil,nil,nil,nil,{['styles.css']=css},'http://localhost:8000/memory/index.html',nil,nil,nil,nil,function(source)return svgSources[source]end)
		assert(#warnings==0,table.concat(warnings,' | '));Dirty.begin(tree);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)
		local boardBox=assert(tree.NodeBoxes[Node.findById(document,'board')])
		for _,button in buttons()do
			local tileBox=assert(tree.NodeBoxes[button.Parent]);local buttonBox=assert(tree.NodeBoxes[button])
			assert(tileBox.OuterWidth>20 and math.abs(tileBox.OuterWidth-tileBox.OuterHeight)<.01,'Square at '..width..': '..tileBox.OuterWidth..'x'..tileBox.OuterHeight)
			assert(buttonBox.OuterWidth>20 and math.abs(buttonBox.OuterWidth-tileBox.OuterWidth)<.01,'Button fits tile')
			assert(math.abs(buttonBox.OuterHeight-tileBox.OuterHeight)<.01,'Button fills square height at '..width)
			assert(Node.textContent(button)=='','Card symbols do not depend on font glyphs')
			local back=button.Parent.Children[3];assert(back.Attributes.class=='tile-back'and back.Children[1].Attributes.src=='assets/spark.svg')
		end
		assert(boardBox.OuterWidth<=width+.01,'Board fits viewport')
		local cleanups={};local onFrame
		local motion=HTMLAnimations.start({Alive=true,Root=tree.Gui,AddCleanup=function(_,fn)table.insert(cleanups,fn)end},tree,error,
			{RunService={Heartbeat={Connect=function(_,fn)onFrame=fn;return {Disconnect=function()onFrame=nil end}end}},Clock=function()return time end},4)
		assert(motion,'The actual Memory opacity/background/transform transitions are installed');motion:AfterLayout()
		paintFrame=function()if onFrame then onFrame()end end
		-- Exercise actual hit testing after the opacity painter has created and
		-- retained a compositor for the card back. Direct JS event dispatch alone
		-- cannot detect an anonymous native GUI stealing the next mouse click.
		renderChanges=function(changes)
			local needed,items=tree:ApplyDOMChanges(changes)
			if needed then Dirty.begin(tree,items);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true);motion:AfterLayout()end
		end
		click('restart')
		local retainedButton=tree.NodeBoxes[buttons()[1]].Gui
		local function pointerClick(index)
			local button=buttons()[index+1];local tile=button.Parent
			local back=tree.NodeBoxes[tile.Children[3]];local face=tree.NodeBoxes[tile.Children[1]]
			local objects={}
			for _,box in {back,face}do
				if box.OpacityGroup and box.OpacityGroup.Gui.GroupTransparency<1 then table.insert(objects,box.OpacityGroup.Content);table.insert(objects,box.OpacityGroup.Gui)end
				table.insert(objects,box.Gui)
			end
			table.insert(objects,tree.NodeBoxes[button].ImageItem.BoxGui)
			local picked=HitTest.pick(objects,tree.HitNodes,tree.Gui,nil,tree.HitStyles)
			assert(picked==button,'The retained card back must pass the pointer to its button at '..width..', picked '..tostring(picked and picked.Attributes.class))
			events:Emit(picked,'click');runtime:Flush();assert(#diagnostics==0,table.concat(diagnostics,' | '))
		end
		local function visibleFace(index)
			local button=buttons()[index+1];local faceNode=button.Parent.Children[1]
			local face=tree.NodeBoxes[faceNode];local image=tree:FindImageItem(faceNode.Children[1])
			assert(face.Style.Opacity==1 and face.OpacityGroup.Gui.GroupTransparency<.001,'Open card front is opaque')
			assert(tree.NodeBoxes[button].ImageItem.BoxGui.BackgroundTransparency>.999,'Open card button does not cover its front')
			assert(image.SVG==svgSources[faceNode.Children[1].Attributes.src]and image.ImageGui.Visible and image.ContentWidth>0 and image.ContentHeight>0,'Open card has a visible SVG image surface: source='..tostring(image.SVG==svgSources[faceNode.Children[1].Attributes.src])..', visible='..tostring(image.ImageGui.Visible)..', size='..tostring(image.ContentWidth)..'x'..tostring(image.ContentHeight))
			local cursor=image.ImageGui
			while cursor do
				assert(cursor.Visible~=false and (cursor.ClassName~='CanvasGroup'or cursor.GroupTransparency<.999),'Open motif is not hidden by a compositing ancestor')
				cursor=cursor.Parent
			end
			local tile=tree.NodeBoxes[button.Parent];local gui=face.OpacityGroup.Gui
			local left=gui.Position[1]-gui.AnchorPoint.X*gui.Size[1]
			local top=gui.Position[2]-gui.AnchorPoint.Y*gui.Size[2]
			assert(math.abs(left-face.LayoutX)<1 and math.abs(top-face.LayoutY)<1,'Open front stays at its layout origin: '..left..','..top..' expected '..face.LayoutX..','..face.LayoutY)
			assert(math.abs(gui.Size[1]-tile.OuterWidth)<1 and math.abs(gui.Size[2]-tile.OuterHeight)<1,'Front compositor fills the tile')
		end
		for _=1,3 do
			pointerClick(0);advance(.2);visibleFace(0);pointerClick(2);advance(.2);visibleFace(2);advance(.7)
			assert(not open(0)and not open(2),'Mismatch recloses both cards: '..tostring(open(0))..'/'..tostring(open(2))..', '..text('moves')..' moves, '..text('status'))
			assert(tree.NodeBoxes[buttons()[1]].Gui==retainedButton,'Reclosing preserves the clickable button')
		end
		pointerClick(0);advance(.2);visibleFace(0);assert(open(0),'Mouse can reopen a repeatedly mismatched card')
		pointerClick(1);advance(.2);visibleFace(1);assert(text('pairs')=='1 / '..count,'Mouse can match a reopened card')
		renderChanges=nil;paintFrame=nil;click('restart');for _,cleanup in cleanups do cleanup()end
		if tree.VisualEffects then tree.VisualEffects:Destroy()end
	end
	end
	local hubDocument=Parser.parseDocument(hubHTML);assert(#hubDocument.Diagnostics==0)
	for _,width in {320,480,1080}do
		local warnings={};local tree=renderer.build(hubDocument,{AbsoluteSize=Vector2.new(width,900)},function(v)table.insert(warnings,v)end,nil,nil,nil,function()return 'rbxassetid://1'end,nil,nil,nil,nil,nil,{['styles.css']=hubCSS},'http://localhost:8000/main/index.html')
		assert(#warnings==0,table.concat(warnings,' | '));layout.arrange(tree,width,0,0,function()return true end)
		local games=assert(tree.NodeBoxes[Node.findById(hubDocument,'spiele')]);assert(games.OuterWidth<=width+.01,'Hub fits viewport')
		if tree.VisualEffects then tree.VisualEffects:Destroy()end
	end
	runtime:Destroy();model:Destroy();events:Destroy()
	local function module(name,value,children)
		local item={Name=name,Value=value,Children=children or {}}
		function item:IsA(class)return class=='ModuleScript'end
		function item:FindFirstChild(wanted)for _,child in self.Children do if child.Name==wanted then return child end end end
		function item:GetChildren()return self.Children end;return item
	end
	local metadata={URL='http://localhost:8000/main/index.html',Options={JavaScriptServices={ScriptSources={keep='preserved'}}}}
	local main=module('Main',metadata,{module('HTML',hubHTML),module('CSS',hubCSS),module('JavaScript',hubApp)})
	local memory=module('Memory',{URL='http://localhost:8000/memory/index.html',ScriptPath='app.js'},{module('HTML',html),module('CSS',css),module('JavaScript',app)})
	local catalog=loadCatalog(module('Websites',nil,{main,memory}))
	local page=catalog.get('Main');assert(page.Options.JavaScriptServices.ScriptSources['http://localhost:8000/main/app.js']==hubApp)
	assert(page.Options.JavaScriptServices.ScriptSources.keep=='preserved'and metadata.Options.JavaScriptServices.ScriptSources['http://localhost:8000/main/app.js']==nil,'Options remain independent')
	assert(catalog.get('Memory').Options.JavaScriptServices.ScriptSources['http://localhost:8000/memory/app.js']==app)
	assert(catalog.resolve('Main','../memory/index.html').Name=='Memory'and #catalog.names()==2)
	print('Memory: real JS, difficulty, mismatches, pause, restart races, win/storage, timer cleanup, native responsive tiles and separate JavaScript modules passed')
end
