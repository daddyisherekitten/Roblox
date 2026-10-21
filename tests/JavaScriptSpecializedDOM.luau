--!strict
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel)
	local guis={}
	local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.Parent=parent;gui.ClassName=class;gui.Visible=true
		gui.AbsoluteSize=Vector2.new(520,500);gui.AbsolutePosition=Vector2.new(0,0)
		if class=="ScrollingFrame" then gui.CanvasPosition=Vector2.new(0,0) end
		function gui:Destroy()
			assert(not self.Destroyed,"GUI destroyed twice");self.Destroyed=true
			for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy() end end
			self.Parent=nil
		end
		table.insert(guis,gui);return gui
	end}
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},
		["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text) or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local function snapshot(tree)
		local parts={}
		local function add(value)table.insert(parts,if type(value)=="number" then string.format("%.4f",value) else tostring(value))end
		local function visit(box)
			add(box.Kind);add(box.Node and box.Node.Name)
			for _,key in {"LayoutX","LayoutY","OuterWidth","OuterHeight","ContentWidth","ContentHeight"} do add(box[key]) end
			for _,item in box.Items or {} do
				add(item.Text);add(item.Node and item.Node.Name)
				for _,key in {"X","Y","Width","Height","Baseline"} do add(item[key]) end
			end
			for _,child in box.Children or {} do visit(child) end
		end
		visit(tree);return table.concat(parts,"|")
	end
	for _,display in {"block","flex","grid"} do
		local css='body{margin:0}section{display:'..display..';gap:8px;grid-template-columns:1fr 1fr}img,canvas,svg,iframe,video{width:70px;height:30px}#fade{opacity:.5}'
		local doc=Parser.parseDocument('<!doctype html><html><body><section id="left"><span id="fade">before <img id="image" src="missing.png" alt="Missing"> after</span><canvas id="canvas" width="20" height="10"></canvas><svg id="vector" width="20" height="10"><rect width="5" height="5"></rect></svg><iframe id="frame" srcdoc="test"></iframe><video id="video"></video></section><section id="right">right</section><p>unchanged</p><script>window.booted=true;</script></body></html>')
		local function build(document)return renderer.build(document,{},function()end,function(font)return font end,nil,nil,function()return "rbxassetid://1"end,css)end
		local tree=build(doc);local events=Events.new(error);local model=FormModel.new(doc,tree.Controls,events,function()end)
		local page={Alive=true,Document=doc,DocumentURL="special.html",Root=tree.Gui,Events=events,FormModel=model,Cleanups={}}
		function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
		local realm=HTMLScripts.start(page,tree,function()end,error)
		local function arrange(t,targets)
			t:SetMediaEnvironment(520,500);t.ViewportHeight=500;Dirty.begin(t,targets)
			local h=layout.arrange(t,520,0,0,function()return true end);Dirty.finish(t,true);return h
		end
		arrange(tree)
		local image=tree.ImageItems[1];local imageGui=image.Gui
		local canvas,svg,iframe,media=tree.CanvasItems[1],tree.SVGItems[1],tree.IFrameItems[1],tree.MediaItems[1]
		local canvasGui,svgGui,iframeGui,mediaGui=canvas.Gui,svg.Gui,iframe.Gui,media.Gui
		local function run(source,mutationOrder)
			realm:Run(source);assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,"\n"))
			local apply=tree.ApplyDOMChanges
			if mutationOrder then
				-- A mutation batch is unordered. Force parent-first iteration to
				-- verify its snapshot cannot erase a descendant's pending edit.
				tree.ApplyDOMChanges=function(self,changes)
					local order,seen={},{}
					for _,id in mutationOrder do
						local node=Node.findById(doc,id)
						if changes[node] then table.insert(order,node);seen[node]=true end
					end
					for node in changes do if not seen[node] then table.insert(order,node) end end
					setmetatable(changes,{__iter=function(batch)
						local index=0
						return function()
							index+=1;local node=order[index]
							if node then return node,rawget(batch,node) end
						end
					end})
					return apply(self,changes)
				end
			end
			local needed,targets=realm:Flush();tree.ApplyDOMChanges=apply;assert(needed)
			local actual=arrange(tree,targets);local fresh=build(Node.cloneNode(doc,true));local expected=arrange(fresh)
			assert(actual==expected and snapshot(tree)==snapshot(fresh),"Specialized "..display.." structural layout matches a fresh render")
		end
		run('document.getElementById("right").append(document.getElementById("canvas"),document.getElementById("vector"),document.getElementById("frame"),document.getElementById("video"));document.getElementById("fade").append(" more");',{"left","fade","right"})
		assert(tree.CanvasItems[1]==canvas and tree.SVGItems[1]==svg and tree.IFrameItems[1]==iframe and tree.MediaItems[1]==media)
		assert(canvas.Gui==canvasGui and svg.Gui==svgGui and iframe.Gui==iframeGui and media.Gui==mediaGui,"Moves preserve native replaced items")
		assert(not canvasGui.Destroyed and not svgGui.Destroyed and not iframeGui.Destroyed and not mediaGui.Destroyed)
		assert(tree.ImageItems[1]==image and image.Gui==imageGui and not imageGui.Destroyed,"Images survive their inline opacity host refresh")
		for _,delta in tree:TakeStructuralResourceChanges() do assert(#delta.Added==0 and #delta.Removed==0,"Moves do not restart resource sessions") end
		local notified=false
		tree.StructuralResourcesRemoving=function(removals)
			if #removals.Canvas>0 then assert(removals.Canvas[1]==canvas and not canvasGui.Destroyed);notified=true end
		end
		run('document.getElementById("canvas").remove();document.getElementById("vector").remove();document.getElementById("frame").remove();document.getElementById("video").remove();document.getElementById("image").remove();')
		assert(notified and imageGui.Destroyed and canvasGui.Destroyed and svgGui.Destroyed and iframeGui.Destroyed and mediaGui.Destroyed)
		local removed=tree:TakeStructuralResourceChanges()
		assert(removed.Canvas.Removed[1]==canvas and removed.SVG.Removed[1]==svg and removed.IFrames.Removed[1]==iframe and removed.Media.Removed[1]==media)
		run('const added=document.createElement("canvas");added.width=20;added.height=10;document.getElementById("right").append(added);')
		local added=tree:TakeStructuralResourceChanges();assert(#added.Canvas.Added==1 and #added.Canvas.Removed==0)
		realm:Destroy();page.Alive=false
	end
	do
		local doc=Parser.parseDocument('<!doctype html><html><body><select id="list" multiple size="4"><optgroup id="group" label="Group"><option id="a" value="a">Alpha</option><option id="b" value="b" selected>Beta</option></optgroup><option id="c" value="c">Gamma</option></select><select id="dropdown"><option id="short">One</option></select><script>window.ready=true;</script></body></html>')
		local function build(document)return renderer.build(document,{},function()end,function(font)return font end,nil,nil,nil,'body{margin:0}')end
		local tree=build(doc);local events=Events.new(error);local model=FormModel.new(doc,tree.Controls,events,function()end)
		local page={Alive=true,Document=doc,DocumentURL="select.html",Root=tree.Gui,Events=events,FormModel=model}
		function page:AddCleanup()end
		local realm=HTMLScripts.start(page,tree,function()end,error)
		local list=model:Resolve(Node.findById(doc,"list"));local item=list.Item
		local optionA,optionB=Node.findById(doc,"a"),Node.findById(doc,"b")
		local rowA,rowB=item.SelectRowsByNode[optionA],item.SelectRowsByNode[optionB]
		local native,scroll=item.Gui,item.SelectScroll;scroll.CanvasPosition=Vector2.new(0,7)
		local function arrange(t,targets)
			t:SetMediaEnvironment(520,500);t.ViewportHeight=500;Dirty.begin(t,targets)
			local height=layout.arrange(t,520,0,0,function()return true end);Dirty.finish(t,true);return height
		end
		arrange(tree)
		local function run(source)
			realm:Run(source);assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,"\n"))
			local needed,targets=realm:Flush();assert(needed)
			local actual=arrange(tree,targets);local fresh=build(Node.cloneNode(doc,true));local expected=arrange(fresh)
			assert(actual==expected and snapshot(tree)==snapshot(fresh),"Dynamic select layout matches a fresh native control")
			assert(item.Gui==native and item.SelectScroll==scroll and not native.Destroyed,"Select DOM updates preserve the control and scroll host")
		end
		run('document.getElementById("group").prepend(document.getElementById("b"));document.getElementById("a").textContent="A much longer option";const opt=document.createElement("option");opt.id="added";opt.textContent="Added";document.getElementById("list").append(opt);')
		assert(item.SelectRowsByNode[optionA]==rowA and item.SelectRowsByNode[optionB]==rowB,"Option reorder/text updates preserve their native rows")
		assert(rowA.Label.Text=="A much longer option" and list.Options[list.SelectedIndex].Node==optionB,"Text and selectedness stay aligned with DOM option identity")
		assert(scroll.CanvasPosition.Y==7,"Option changes preserve list scroll position")
		run('document.getElementById("a").remove();document.getElementById("short").textContent="A wider dropdown option";')
		assert(rowA.Gui.Destroyed and item.SelectRowsByNode[optionB]==rowB and not rowB.Gui.Destroyed,"Only removed option rows are disposed")
		realm:Destroy();events:Destroy();model:Destroy()
	end
	print("Specialized DOM: replaced item/resource identity, cancellation order, fresh layout parity and select row reconciliation passed")
	return true
end
