--!strict
return function(Parser, Job, Dirty, loadRenderTree, loadWordLayout, loadBlockLayout)
	local allocations = 0
	local function create(class,parent,props)
		allocations+=1
		local gui=table.clone(props); gui.ClassName,gui.Parent=class,parent
		function gui:Destroy() self.Parent=nil end
		return gui
	end
	local overrides={
		["Layout/FontProfiles"]={face=function(font) return font end},
		["Layout/TextMeasure"]={measure=function(text,_,size) return {X=(utf8.len(text) or 0)*size*.45,Y=size} end},
	}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local renderer,layout=loadRenderTree({create=create,modifier=create}),loadBlockLayout(overrides)
	local html='<style>body{margin:0;font:16px/1.3 Arial}p{margin:6px 0}.flex{display:flex;flex-wrap:wrap;gap:7px}.flex>div{flex:1 1 65px;min-width:40px;padding:3px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:5px}.columns{column-count:2;column-gap:12px}.scroll{height:75px;overflow:auto}.float{float:left;width:50px;height:50px;shape-outside:circle(50%)}#hover:hover{font-size:20px;color:red}@media(max-width:220px){.grid{grid-template-columns:1fr}}</style><div class="flex">'
	for i=1,14 do html..='<div>Item '..i..' text for wrapping and sizing.</div>' end
	html..='</div><div class="grid"><p>Grid text with several words and a long line.</p><p>Another grid cell with more words.</p></div><div class="columns"><p>'
	for _=1,20 do html..='Multiple column text for balanced flowing. ' end
	html..='</p></div><div class="scroll"><div class="float"></div><p>'
	for _=1,20 do html..='Text flows around the floating shape and continues below it. ' end
	html..='</p></div><p id="hover">Hover text and retained painting callbacks.</p>'
	local function build() return renderer.build(Parser.parse(html),{AbsoluteSize=Vector2.new(400,300)},error) end
	local function snapshot(tree)
		local values={}
		local function visit(box)
			table.insert(values,table.concat({box.Kind or "",box.LayoutX or 0,box.LayoutY or 0,box.OuterWidth or 0,box.OuterHeight or 0,box.FirstBaseline or 0},","))
			for _,item in box.Items or {} do
				table.insert(values,table.concat({item.Text or "",item.X or 0,item.Y or 0,item.Width or 0,item.Height or 0,item.LineBaseline or 0},","))
			end
			for _,child in box.AllChildren or box.Children or {} do visit(child) end
		end
		visit(tree)
		return table.concat(values,"\n")
	end
	local page, tree = {Alive=true}, build()
	local time, waits = 0,0
	local afterYield
	local runtime={wait=function()
		waits+=1;time+=.016
		if afterYield then local callback=afterYield;afterYield=nil;callback() end
	end}
	local function clock() time+=.0003;return time end
	local function update(target,width,cooperative,current)
		target.ViewportHeight=300
		local stats=Dirty.begin(target)
		local ok,result,cancelled=Job.run(page,target,if cooperative then 4 else 0,current or function() return true end,function(check,styleCheck)
			target:SetMediaEnvironment(width,300,nil,styleCheck)
			local h,w,b=layout.arrange(target,width,0,0,check)
			check();return {h,w,b}
		end,runtime,clock)
		Dirty.finish(target,ok)
		return ok,result,cancelled,stats
	end
	for _,width in {360,180,280,180} do
		local reference=build()
		local expected,dimensions=update(reference,width,false)
		local ok,result=update(tree,width,true)
		assert(expected and ok and result[1] == dimensions[1] and result[2] == dimensions[2] and snapshot(tree)==snapshot(reference), "Cooperative layout matches uninterrupted flex/grid/columns/scroll/float geometry")
	end
	assert(waits > 0)
	local node,box
	for candidate,owner in tree.NodeBoxes do if candidate.Attributes and candidate.Attributes.id=="hover" then node,box=candidate,owner end end
	local oldSize=box.Style.FontSize
	afterYield=function()
		local changed,needsLayout=tree:SetCSSState("hover",node)
		assert(changed and not needsLayout and box.Style.FontSize == oldSize, "Input queues CSS without mutating a suspended layout")
	end
	assert(update(tree,280,true))
	local changed,needsLayout=tree:FlushCSSStates()
	assert(changed and needsLayout and box.Style.FontSize==20)
	assert(update(tree,280,true))
	tree.LayoutInProgress=true
	tree:SetCSSState("hover",node);tree:SetCSSState("hover",nil)
	tree.LayoutInProgress=false;tree:FlushCSSStates()
	assert(box.Style.FontSize==oldSize,"Queued pointer leave retains nil and the final CSS state")
	local revision=1
	afterYield=function() tree:SetCSSState("hover",node);revision=2 end
	local ok,_,cancelled=update(tree,200,true,function() return revision==1 end)
	assert(not ok and cancelled and not tree.DirtyContext.Ready and not tree.LayoutInProgress)
	changed,needsLayout=tree:SetCSSState("hover",nil)
	assert(changed and needsLayout and box.Style.FontSize==oldSize,"Input updates queued CSS across an interrupted pass without restoring stale hover")
	local reference=build();assert(update(reference,200,false));assert(update(tree,200,true))
	tree:FlushCSSStates()
	assert(snapshot(tree)==snapshot(reference),"A cancelled pass recovers with the exact final geometry")
	tree.LayoutNeedsRecovery=true
	changed,needsLayout=tree:SetCSSState("hover",node)
	assert(changed and needsLayout and box.Style.FontSize==oldSize,"CSS also waits while cancelled geometry is awaiting recovery")
	tree.LayoutNeedsRecovery=false;tree:FlushCSSStates()
	tree:SetCSSState("hover",nil);assert(update(tree,200,true))
	local before=allocations
	assert(update(tree,200,true))
	assert(allocations==before,"Pauses and repeated layout reuse existing GUI instances")
	for _,child in tree.Children do if child.RepaintStyles then assert(child.RepaintStyles()) end end
	print("Cooperative layout: uninterrupted geometry parity at four widths, flex/grid/columns/floats/scrollbars, queued hover, cancellation recovery and GUI reuse passed")
 do
  local queuedTree=renderer.build(Parser.parse('<style>p{font-size:16px}p:target{font-size:31px}select{font-size:16px}select:open{font-size:29px}</style><p id="queued-target">Target</p><select id="queued-open"><option>Option</option></select>'),{AbsoluteSize=Vector2.new(400,300)},error)
  local target,picker
  for node,style in queuedTree.NodeStyles do
   if node.Attributes and node.Attributes.id=='queued-target'then target=node elseif node.Attributes and node.Attributes.id=='queued-open'then picker=node end
  end
  assert(target and picker)
  for _,mode in {'LayoutInProgress','LayoutNeedsRecovery'}do
   queuedTree[mode]=true
   assert(queuedTree:SetCSSState('target',target));assert(queuedTree:SetCSSState('open',picker))
   assert(queuedTree.NodeStyles[target].FontSize==16 and queuedTree.NodeStyles[picker].FontSize==16,'Suspended layout does not recascade target/open')
   queuedTree[mode]=false
   local updated,needed=queuedTree:FlushCSSStates()
   assert(updated and needed and queuedTree.NodeStyles[target].FontSize==31 and queuedTree.NodeStyles[picker].FontSize==29,'Queued target and open styles publish on the real retained render tree')
   queuedTree[mode]=true;queuedTree:SetCSSState('target',nil);queuedTree:SetCSSState('open',nil);queuedTree[mode]=false
   queuedTree:FlushCSSStates()
   assert(queuedTree.NodeStyles[target].FontSize==16 and queuedTree.NodeStyles[picker].FontSize==16,'Queued target/open clearing restores underlying styles')
  end
 end

 do
  -- A cooperative pause can expose the new list before shadow-scope discovery returns.
  local Node=require('DOM/Node');local Style=require('CSS/InlineStyle')
  local Stylesheet=require('CSS/Stylesheet');local Work=require('WorkContext')
  local document=Parser.parse('<style id="reentry-sheet">.reentry {color:red}</style><p id="reentry-probe" class="reentry"></p>')
  local retained=renderer.build(document,{},error)
  local probe=Node.findById(document,'reentry-probe');local source=Node.findById(document,'reentry-sheet').Children[1]
  local function color()return Style.resolve(probe,{FontSize=16},error,false,Stylesheet.match(retained.CSSRules,probe)).Color end
  assert(color()==Color3.fromRGB(255,0,0))
  source.Text='.reentry {color:blue}'
  local checkpoints,stale,inside=0,0,false
  Work.with(function()
   if inside then return end
   local first=retained.CSSRules[1]
   local declaration=first and first.RawDeclarations and first.RawDeclarations.Normal[1]
   if not declaration or declaration.Value~='blue'then return end
   inside=true;checkpoints+=1
   if color()~=Color3.fromRGB(0,0,255)then stale+=1 end
   inside=false
  end,function()retained:ApplyDOMChanges({[source]={Text=true}})end)
  print('Stylesheet reentry: new-source checkpoints='..checkpoints..'; stale candidate colors='..stale)
  assert(checkpoints>0,'Recompile must reach an actual shadow-discovery checkpoint after replacing the stylesheet list')
  assert(stale==0,'A replaced stylesheet must invalidate candidates before any cooperative checkpoint')
  assert(color()==Color3.fromRGB(0,0,255),'Final cascade uses the replacement stylesheet')
  retained.VisualEffects:Destroy()
 end

end
