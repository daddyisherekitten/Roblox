--!strict
-- Unlike MemoryGame, build the empty HTML board first. The delivered defer
-- script must insert, register and paint its cards into a live native tree.
return function(Parser,Node,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,HTMLAnimations,html,css,app,svgSources)
	local function signal()
		local entries={};local api={}
		function api:Connect(fn)
			local connection={Connected=true};function connection:Disconnect()self.Connected=false end
			table.insert(entries,{connection,fn});return connection
		end
		function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		return api
	end
	local svgNodes={}
	for reference,source in svgSources do svgNodes[reference]=assert(Node.findElement(Parser.parse(source),function(n)return n.Name=="svg"end))end
	local url="http://localhost:8000/memory/index.html"
	local function resolveSVG(reference)return svgNodes[reference]or svgNodes[reference:gsub("^http://localhost:8000/memory/","")]end
	for _,width in {320,480,1080}do
		local guis={};local factory={}
		function factory.create(class,parent,properties)
			local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=gui.Visible~=false
			gui.Position=gui.Position or UDim2.fromOffset(0,0);gui.Size=gui.Size or UDim2.fromOffset(100,100)
			gui.AnchorPoint=gui.AnchorPoint or Vector2.new(0,0);gui.ZIndex=gui.ZIndex or 1
			gui.BackgroundTransparency=gui.BackgroundTransparency or 1;gui.BackgroundColor3=gui.BackgroundColor3 or Color3.new(1,1,1)
			gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(width,900)
			if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
			gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
			function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
			function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
			function gui:SetAttribute(key,value)attributes[key]=value;if signals["attribute:"..key]then signals["attribute:"..key]:Fire()end end
			function gui:GetAttribute(key)return attributes[key]end
			function gui:IsA(kind)return kind==class or kind=="GuiObject"and not class:match("^UI")end
			function gui:IsFocused()return false end
			function gui:Destroy()
				assert(not self.Destroyed,"GUI disposed twice");self.Destroyed=true
				for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end
				self.Parent=nil
			end
			table.insert(guis,gui);return gui
		end
		factory.modifier=factory.create
		local measure={measure=function(value,_,size)return {X=(utf8.len(value)or 0)*size*.45,Y=size}end}
		local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]=measure}
		local words=loadWordLayout(overrides);overrides["Layout/WordLayout"]=words
		local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
		local document=Parser.parseDocument(html,{ScriptingEnabled=true});assert(#document.Diagnostics==0)
		local root=factory.create("ScrollingFrame",nil,{Size=UDim2.fromOffset(width,900)})
		local messages={};local function diagnostic(message)table.insert(messages,message)end
		local tree=renderer.build(document,root,diagnostic,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,{["styles.css"]=css},url,nil,nil,nil,nil,resolveSVG)
		local board=assert(Node.findById(document,"board"));assert(#board.Children==0,"The native tree initially has no cards")
		local events=require("Input/Events").new(diagnostic)
		local model=FormModel.new(document,tree.Controls,events,function()end)
		local page={Alive=true,Document=document,DocumentURL=url,BaseURL=url,Root=root,Events=events,FormModel=model,Cleanups={}}
		function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
		function page:RefreshDOMControls()model:RefreshControls()end
		function page:GeometryViewport()return {Width=width,Height=900,ClientWidth=width,ClientHeight=900,ScrollWidth=width,ScrollHeight=tree.OuterHeight or 900,ScrollX=0,ScrollY=0}end
		function page:HasPendingLayout()return false end
		local clock,realm,motion,flushing=0,nil,nil,false;local frame=signal()
		local callbacks={};local svgRegistrations={};local uploads={}
		local sounds={}
		page.ResolveAudio=function(source)return if source=="https://assetdelivery.roblox.com/v1/asset/?id=117006292434032"then"rbxassetid://117006292434032"else nil end
		local audioServices={RunService={Heartbeat=signal()},Task={spawn=function(fn)table.insert(callbacks,fn)end},
			Instance={new=function(kind)
				assert(kind=="Sound");local sound={Playing=false,TimePosition=0,TimeLength=60,IsLoaded=false,Ended=signal(),DidLoop=signal(),DestroyCalls=0}
				function sound:Pause()self.Playing=false end
				function sound:Stop()self.Playing=false;self.TimePosition=0 end
				function sound:Destroy()self.DestroyCalls+=1 end
				table.insert(sounds,sound);return sound
			end},ContentProvider={PreloadAsync=function(_,objects)for _,object in objects do object.IsLoaded=true end end}}
		local function removeSVG(items)
			for _,item in items do local registration=svgRegistrations[item];if registration then registration.Alive=false end;svgRegistrations[item]=nil;item.UpdateSVG=nil end
		end
		local function addSVG(items)
			for _,item in items do
				if svgRegistrations[item]then continue end
				local registration={Alive=true,Source=item.SVG};svgRegistrations[item]=registration
				item.UpdateSVG=function()
					if not registration.Alive or not page.Alive then return end
					local w,h=item.SVGRasterWidth or item.ContentWidth or 0,item.SVGRasterHeight or item.ContentHeight or 0
					if w<=0 or h<=0 then return end
					local key=tostring(w).."x"..tostring(h)
					if registration.Key==key then return end;registration.Key=key
					table.insert(uploads,function()
						if registration.Alive and page.Alive and registration.Key==key then
							assert(item.ImageGui and not item.ImageGui.Destroyed,"SVG upload targets a live retained image surface")
							item.ImageGui.ImageContent={Source=registration.Source,Width=w,Height=h}
							registration.Uploaded=true
						end
					end)
				end
			end
		end
		-- The HTML page's resource census and retained-source rebind hooks. Pixel
		-- rendering is covered by the SVG suites; here an upload sentinel proves
		-- that real image layout schedules the registered dynamic paint surface.
		addSVG(tree.SVGItems)
		tree.StructuralResourcesRemoving=function(removals)removeSVG(removals.SVG or {})end
		function page:RefreshDOMResources()
			local changes=tree:TakeStructuralResourceChanges();removeSVG(changes.SVG.Removed);addSVG(changes.SVG.Added)
		end
		function page:RefreshImageResource(node)
			local item,_,changed,geometry=tree:RefreshImageResource(node,function(previous,kind)if kind=="SVG"then removeSVG({previous})end end)
			if item and changed then self:RefreshDOMResources();if item.SVG then addSVG({item})end end
			return item,geometry
		end
		local function arrange(targets)
			tree:SetMediaEnvironment(width,900);tree.ViewportHeight=900
			Dirty.begin(tree,targets);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)
			if motion then motion:AfterLayout()end
		end
		function page:FlushScriptLayout()
			if flushing or not realm then return end;flushing=true
			local needed,targets=realm:Flush()
			if needed then
				local remaining={};for item,reason in targets or {}do if not tree:CanKeepTextLayout(item,words.arrange,function()return true end)then remaining[item]=reason end end
				if next(remaining)then arrange(remaining)end
			end
			flushing=false
		end
		arrange();root:SetAttribute("Status","ready")
		motion=assert(HTMLAnimations.start(page,tree,diagnostic,{RunService={Heartbeat=frame},Clock=function()return clock end},4))
		motion:AfterLayout()
		local storage=require("JavaScript/Storage").createArea()
		-- CSS DOM controllers use the JavaScript clock as their one timing owner.
		-- Fire the same rendering signal for both hosts, as native RunService does.
		local services={Clock=function()return clock end,AudioServices=audioServices,RunService={RenderStepped=frame},Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Cancelled=true end},
			ScriptSources={[url:gsub("index.html$","app.js")]="Math.random=function(){return .999999;};\n"..app},GetStorageArea=function()return storage end,
			LoadImage=function(reference,complete,spec)
				table.insert(callbacks,function()
					local source=resolveSVG(spec.Source or reference)
					if source then local w,h=require("SVG/Sizing").source(source);complete(true,{Width=w,Height=h,SVG=source})else complete(false,"Missing image")end
				end)
			end}
		realm=assert(HTMLScripts.start(page,tree,function()end,diagnostic,{JavaScriptServices=services}))
		local function settle()
			for attempt=1,60 do
				local pending=callbacks;callbacks={};for _,complete in pending do complete()end
				page:FlushScriptLayout();realm:AfterLayout()
				local paints=uploads;uploads={};for _,upload in paints do upload()end
				local tasks=realm:PumpTasks()
				if #callbacks==0 and #uploads==0 and tasks==0 and not realm:HasPending()then break end
				assert(attempt<60,"Dynamic Memory tasks did not converge")
			end
			page:FlushScriptLayout();assert(#messages==0,table.concat(messages," | "))
		end
		local function advance(seconds)clock+=seconds;frame:Fire();settle();frame:Fire()end
		local function card(index)return assert(board.Children[index+1],"Missing dynamic card")end
		local function clickCard(index)events:Emit(card(index).Children[2],"click");settle()end
		local function run(source)local ok,message=realm:Run(source);assert(ok,tostring(message));settle()end
		local function part(value,axis,index)
			local dimension=value and value[axis]
			return if dimension then dimension.Offset or 0 else value and value[index]or 0,
				if dimension then dimension.Scale or 0 else value and value[axis.."Scale"]or 0
		end
		local function rectangle(gui)
			assert(gui and not gui.Destroyed,"Painting must not retain a disposed GUI")
			if gui==root then return {X=0,Y=0,W=width,H=900,Scale=1}end
			local parent=assert(gui.Parent,"A live paint surface must be attached to the page")
			local bounds=rectangle(parent)
			local x,xs=part(gui.Position,"X",1);local y,ys=part(gui.Position,"Y",2)
			local w,ws=part(gui.Size,"X",1);local h,hs=part(gui.Size,"Y",2)
			local ownScale=1;for _,modifier in guis do if not modifier.Destroyed and modifier.Parent==gui and modifier.ClassName=="UIScale"then ownScale*=modifier.Scale end end
			local scale=bounds.Scale*ownScale
			local usedW,usedH=(w+ws*bounds.W/bounds.Scale)*scale,(h+hs*bounds.H/bounds.Scale)*scale
			local scroll=parent.CanvasPosition or Vector2.new(0,0);local anchor=gui.AnchorPoint or Vector2.new(0,0)
			return {X=bounds.X+(x-scroll.X)*bounds.Scale+xs*bounds.W-anchor.X*usedW,Y=bounds.Y+(y-scroll.Y)*bounds.Scale+ys*bounds.H-anchor.Y*usedH,W=usedW,H=usedH,Scale=scale}
		end
		local function intersects(a,b)return math.min(a.X+a.W,b.X+b.W)>math.max(a.X,b.X)and math.min(a.Y+a.H,b.Y+b.H)>math.max(a.Y,b.Y)end
		local function painted(gui)
			local bounds=rectangle(gui);assert(bounds.W>0 and bounds.H>0,"Paint surface has positive dimensions")
			local current=gui
			while current do
				assert(not current.Destroyed and current.Visible~=false,"Paint surface has only live, visible ancestors")
				if current.ClassName=="CanvasGroup"then assert((current.GroupTransparency or 0)<.999,"Open front is not hidden inside an opaque compositor")end
				if current.ClipsDescendants then assert(intersects(bounds,rectangle(current)),"Open image/name intersects every native clip rectangle")end
				if current==root then break end;current=current.Parent
			end
			assert(current==root,"Open paint remains inside its original page")
			return bounds
		end
		local function front(index)
			local tile=card(index);local tileBox=assert(tree.NodeBoxes[tile]);local face=assert(tree.NodeBoxes[tile.Children[1]])
			local image=assert(tree:FindImageItem(tile.Children[1].Children[1]));local button=assert(tree.NodeBoxes[tile.Children[2]])
			assert(face.Style.Opacity==1 and face.OpacityGroup.Gui.GroupTransparency<.001,"Open card front is fully opaque")
			assert(button.ImageItem.BoxGui.BackgroundTransparency>.999,"Open button does not cover its motif/name")
			assert(image.ImageGui.Visible and image.ImageGui.ImageContent and image.ImageGui.ImageContent.Source==image.SVG,"The actual dynamic SVG image was registered and uploaded")
			local tileBounds=rectangle(tileBox.Gui);local faceBounds=painted(face.OpacityGroup.Gui)
			assert(math.abs(faceBounds.X-tileBounds.X)<1 and math.abs(faceBounds.Y-tileBounds.Y)<1,"Open compositor remains at its card's position")
			assert(math.abs(faceBounds.W-tileBounds.W)<1 and math.abs(faceBounds.H-tileBounds.H)<1,"Open compositor fits the card after the scale transition")
			assert(intersects(painted(image.ImageGui),tileBounds),"The motif lies inside its card")
			local name=tile.Children[1].Children[2];local expected=Node.textContent(name);local found=false
			for _,item in tree.TextItems do
				if item.Style.Node==name and item.Kind=="Word"then
					assert(item.Gui.Text==expected and (item.Gui.TextTransparency or 0)<.001,"Motif name has its real visible native text")
					assert(intersects(painted(item.Gui),tileBounds),"Motif name lies inside its card");found=true
				end
			end
			assert(found,"The native text index retains the motif name after dynamic insertion")
			local back=assert(tree.NodeBoxes[tile.Children[3]])
			assert(back.Style.Opacity==0 and back.OpacityGroup.Gui.GroupTransparency>.999,"An open card hides its back")
		end
		local function closed(index)
			local tile=card(index);local face=assert(tree.NodeBoxes[tile.Children[1]]);local back=assert(tree.NodeBoxes[tile.Children[3]])
			assert(face.Style.Opacity==0 and face.OpacityGroup.Gui.GroupTransparency>.999,"A closed card hides its front")
			assert(back.Style.Opacity==1 and(not back.OpacityGroup or back.OpacityGroup.Gui.GroupTransparency<.001),"A reclosed card restores its back")
			assert(tree.NodeBoxes[tile.Children[2]].ImageItem.BoxGui.BackgroundTransparency<.001,"A closed card restores its purple button")
			painted(assert(tree:FindImageItem(tile.Children[3].Children[1])).ImageGui)
		end
		settle();assert(#board.Children==16 and realm.ScriptsRun==1,"Actual defer script populated the live empty board once")
		assert(#sounds==1 and sounds[1].Playing and sounds[1].Looped and sounds[1].Volume==.35 and sounds[1].SoundId=="rbxassetid://117006292434032","Page music starts once through the native audio host")
		assert(tree.HasOpacity==true,"Dynamically inserted opacity surfaces enable the retained tree's compositor layout pass")
		for index=0,15 do
			local face=assert(tree.NodeBoxes[card(index).Children[1]])
			local w=part(face.OpacityGroup.Gui.Size,"X",1);local h=part(face.OpacityGroup.Gui.Size,"Y",2)
			local contentW=part(face.OpacityGroup.Content.Size,"X",1);local contentH=part(face.OpacityGroup.Content.Size,"Y",2)
			assert(w>0 and h>0 and contentW>0 and contentH>0,"Closed fronts already own a nonempty compositing viewport before their first reveal")
			assert(math.abs(w-face.OuterWidth)<1 and math.abs(h-face.OuterHeight)<1,"Initial dynamic compositor viewport fits its laid out card")
		end
		for index=0,15 do closed(index)end
		for _=1,3 do
			clickCard(0)
			local opening=assert(tree.NodeBoxes[card(0).Children[1]]);local retainedGroup=opening.OpacityGroup.Gui
			assert(opening.Style.Opacity==1 and retainedGroup.GroupTransparency>.999,"Opening retains the zero-opacity transition start")
			advance(.08)
			assert(opening.OpacityGroup.Gui==retainedGroup and retainedGroup.GroupTransparency>.001 and retainedGroup.GroupTransparency<.999,"The shared CSS/JavaScript rendering clock paints a real intermediate opacity")
			advance(.12);front(0);clickCard(2);advance(.2);front(2);advance(.7);advance(.2);closed(0);closed(2)
		end
		clickCard(0);advance(.2);front(0);clickCard(1);advance(.2);front(0);front(1)
		run("document.getElementById('restart').click();");advance(.2);closed(0)
		run("document.getElementById('difficulty').value='12';document.getElementById('difficulty').dispatchEvent(new Event('change'));")
		advance(.2);assert(#board.Children==24,"Difficulty rebuilds dynamic cards through the same mounted path")
		clickCard(0);advance(.2);front(0)
		for _,item in tree.TextItems do if item.Gui then assert(not item.Gui.Destroyed,"Text indexes contain no destroyed card name GUIs")end end
		page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end
		assert(sounds[1].DestroyCalls==1 and not sounds[1].Playing,"Page disposal stops and destroys background music")
		model:Destroy();events:Destroy();removeSVG(tree.SVGItems);root:Destroy()
	end
	print("Memory rendering: empty-board defer insertion, SVG registration/upload surfaces, native motif/name clips, transitions, mismatch/reopen, retained restart and dynamic difficulty passed")
end
