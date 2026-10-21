--!strict
-- Count actual renderer work, not wall-clock time or native FPS.
return function(Parser,Node,Runtime,Style,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLAnimations)
	local created=0
	local factory={create=function(class,parent,props)
		created+=1;local gui=table.clone(props);gui.ClassName=class;gui.Parent=parent
		function gui:Destroy()self.Parent=nil;self.Destroyed=true end
		return gui
	end}
	local renderer=loadRenderTree(factory)
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},
		["Layout/TextMeasure"]={measure=function(text,_,size)return {X=#text*8,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local base='html,body{margin:0;padding:0}#stage{display:flex;justify-content:center;width:100%;height:120px}#box{width:48px;height:48px;background:#b6643e}#other{height:20px}'
	local function fixture(css,markup,doctype)
		local document=Parser.parseDocument((doctype or '')..'<html><body><div id="stage"><div id="box">'..(markup or '')..'</div></div><div id="other">Unchanged text</div></body></html>')
		local root={AbsoluteSize=Vector2.new(600,800)}
		local tree=renderer.build(document,root,error,nil,nil,nil,nil,base..(css or ''))
		local function arrange(width)
			root.AbsoluteSize=Vector2.new(width,800);tree:SetMediaEnvironment(width,800)
			Dirty.begin(tree);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)
		end
		arrange(600)
		local state={Tree=tree,Document=document,Root=root,Arrange=arrange,Layouts=0,Fast=0}
		state.Runtime=Runtime.new(document,{Diagnostic=error,ApplyChanges=function(changes)
			local needed,items,fast=tree:ApplyDOMChanges(changes)
			if needed then state.Layouts+=1 end
			if fast then state.Fast+=1 end
			return needed,items
		end})
		state.Node=Node.findById(document,"box");state.Box=tree.NodeBoxes[state.Node]
		function state:Write(script)self.Runtime:Run(script);return self.Runtime:Flush()end
		function state:Move(x)return self:Write('document.getElementById("box").style.transform="translateX('..x..'px)";')end
		return state
	end
	local function left(box)
		local gui=if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui
		return gui.Position[1]-(gui.AnchorPoint and gui.AnchorPoint.X or 0)*(gui.Size and gui.Size[1] or 0)
	end
	local function pixels(value)return if type(value)=="table" then value.Value else value end
	local s=fixture(nil,'<p>Child text</p>')
	local other=s.Tree.NodeBoxes[Node.findById(s.Document,"other")]
	local cache,owners,childGui=other.CachedLayout,s.Tree.DirtyContext.Owners,other.Children[1].Items[1].Gui
	local allocations=created;local resolves,refreshes=0,0
	local resolve,refresh=Style.resolve,Dirty.refresh
	Style.resolve=function(...)resolves+=1;return resolve(...)end
	Dirty.refresh=function(...)refreshes+=1;return refresh(...)end
	for i=1,100 do assert(not s:Move(i));assert(math.abs(left(s.Box)-(276+i))<.001,"Incorrect translated position: "..left(s.Box)) end
	Style.resolve,Dirty.refresh=resolve,refresh
 assert(resolves==100 and refreshes==0 and s.Fast==100 and s.Layouts==0,"Only one element is resolved per frame; no layout ownership rebuild: "..resolves..'/'..refreshes..'/'..s.Fast..'/'..s.Layouts)
	assert(created==allocations and other.CachedLayout==cache and s.Tree.DirtyContext.Owners==owners and other.Children[1].Items[1].Gui==childGui,
		"Transform frames allocate no surfaces and retain unrelated layout/text caches")
	for _,width in {320,800,280,600} do
		s.Arrange(width);assert(not s:Move(110))
		assert(math.abs(left(s.Box)-((width-48)/2+110))<.001,"A resized centered box uses its new layout anchor")
		assert(not s:Write('{const el=document.getElementById("box");el.style.transform="translateX(111px)";el.style.transform="translateX(112px)";}'))
		assert(math.abs(left(s.Box)-((width-48)/2+112))<.001,"Multiple CSSOM writes repaint the final batched transform")
	end
	s.Runtime:Destroy()
	s=fixture(nil,'Before')
	local boxTransform=require('Rendering/BoxTransform');local originalApply=boxTransform.apply;local boxPaints=0
	boxTransform.apply=function(...)boxPaints+=1;return originalApply(...)end
	local wrote,writeError=pcall(function()s:Write('document.getElementById("box").style.setProperty("--unused","red");')end)
	boxTransform.apply=originalApply;assert(wrote,writeError)
	assert(boxPaints==0 and s.Box.Style.Custom['--unused']=='red','An unused custom property changes cascade inputs without repainting native box geometry')
	s.Runtime:Destroy()
	for _,css in {'#box{opacity:.6}','#box{transform-origin:left top}','#box{transform:translateX(0px)}'} do
		s=fixture(css);assert(not s:Move(17) and s.Fast==1 and math.abs(left(s.Box)-293)<.001)
		s.Arrange(320);assert(not s:Move(22) and math.abs(left(s.Box)-158)<.001,"Opacity groups and custom origins keep their new resize base")
		assert(not s:Write('document.getElementById("box").style.transform="none";') and math.abs(left(s.Box)-136)<.001,"Removing a transform restores the flow anchor")
		s.Runtime:Destroy()
	end
	s=fixture();s:Move(5)
	s:Write('const child=document.createElement("div");child.id="child";child.style.transform="inherit";child.textContent="Child";document.getElementById("box").appendChild(child);')
	local previousFast=s.Fast;s:Move(30)
	assert(s.Fast==previousFast and s.Tree.NodeStyles[Node.findById(s.Document,"child")].Transform[1].X.Value==30,
		"Inserted transform inheritance invalidates the direct-path dependency index")
	s:Write('document.getElementById("box").removeChild(document.getElementById("child"));')
	s:Move(40);assert(s.Fast==previousFast+1,"Removing an inheriting descendant permits local transforms again")
	s.Runtime:Destroy()
	-- Inline style selectors can affect a sibling or a :has ancestor. They must
	-- retain full selector invalidation even though the write names transform.
	for _,css in {
		'#box[style]~p{height:31px}#stage:has([style]){height:151px}',
		'#stage:not(:has([style])){height:99px}#box:is([style]){width:72px}',
		'#stage:has([style*="translate"]){height:151px}',
		'#stage:has(:nth-child(1 of [style])){height:151px}',
		'@scope (#stage:has([style])){#box{width:72px}}',
	} do
		s=fixture(css);s:Move(10)
		assert(s.Fast==0,"Nested attribute selectors use the ordinary cascade")
		local stage=s.Tree.NodeStyles[Node.findById(s.Document,"stage")]
		assert(pixels(stage.Height)==151 or (pixels(stage.Height)==120 and pixels(s.Box.Style.Width)==72),"Dependent ancestor and target rules update")
		s.Runtime:Destroy()
	end
	-- Fold identifier dependencies in exactly the same mode as matching. A
	-- missed folded token would incorrectly limit sibling/:has work to its source.
	for _,doctype in {'','<!doctype html>'}do
		s=fixture('.ON p{color:blue}#STAGE:has(.TONE){background:red}#STAGE.on+#OTHER{color:blue}#STAGE>div:nth-child(1 of .TONE){background:blue}','<p>Child text</p>',doctype)
		local stage,other=Node.findById(s.Document,'stage'),Node.findById(s.Document,'other')
		local stageGui,otherGui=s.Tree.NodeBoxes[stage].Gui,s.Tree.NodeBoxes[other].Gui
		s:Write('document.getElementById("stage").className="cold";document.getElementById("box").className="cold";')
		s:Write('document.getElementById("stage").className="ON";document.getElementById("box").className="ToNe";')
		if doctype==''then
			assert(s.Tree.NodeStyles[stage].Background==Color3.fromRGB(255,0,0)and s.Tree.NodeStyles[other].Color==Color3.fromRGB(0,0,255)and s.Box.Style.Background==Color3.fromRGB(0,0,255),'Quirks changes reach folded sibling, :has and nth filters')
			local layouts=s.Layouts
			s:Write('document.getElementById("stage").className="on";document.getElementById("box").className="tOnE";')
			assert(s.Tree.NodeStyles[stage].Background==Color3.fromRGB(255,0,0)and s.Tree.NodeStyles[other].Color==Color3.fromRGB(0,0,255)and s.Layouts==layouts,'Case-only quirks changes retain paint without layout')
		else
			assert(s.Tree.NodeStyles[other].Color~=Color3.fromRGB(0,0,255)and s.Box.Style.Background~=Color3.fromRGB(0,0,255),'Standards documents keep exact identifier matching')
		end
		assert(s.Tree.NodeBoxes[stage].Gui==stageGui and s.Tree.NodeBoxes[other].Gui==otherGui,'Quirks matching never replaces retained surfaces')
		s.Runtime:Destroy()
	end
	-- Class/attribute scope must preserve relational selector invalidation.
	for _,entry in {
		{'#stage:has(.on){height:151px}',151,48},
		{'#stage:not(:has(.on)){height:151px}',120,48},
		{'#stage:has(:nth-child(1 of .on)){height:151px}',151,48},
		{'#stage>div:nth-child(1 of .on){width:72px}',120,72},
		{'@scope (#stage:has(.on)){#box{width:72px}}',120,72},
	}do
		s=fixture(entry[1]);s:Write('document.getElementById("box").classList.add("on");')
		assert(s.Fast==0 and pixels(s.Tree.NodeStyles[Node.findById(s.Document,'stage')].Height)==entry[2]
			and pixels(s.Box.Style.Width)==entry[3],'Class scope preserves :has, nth filters and scope boundaries')
		s.Runtime:Destroy()
	end
	s=fixture('#stage.on+#other{height:31px}')
	s:Write('document.getElementById("stage").classList.add("on");')
	assert(pixels(s.Tree.NodeStyles[Node.findById(s.Document,'other')].Height)==31,'Class changes invalidate related siblings outside the subtree')
	s.Runtime:Destroy()
	s=fixture('.on p{color:blue}#stage>div:nth-child(1 of .unrelated){color:red}','<p>Child text</p>')
	local unrelatedNode=Node.findById(s.Document,'other');local unrelatedResolves=0
	Style.resolve=function(node,...)if node==unrelatedNode then unrelatedResolves+=1 end;return resolve(node,...)end
	local classChanged,classError=pcall(function()assert(not s:Write('document.getElementById("box").classList.add("on");'))end)
	Style.resolve=resolve;assert(classChanged,classError)
	local paragraph=Node.findElement(s.Node,function(n)return n.Name=='p'end)
	assert(s.Tree.NodeStyles[paragraph].Color==Color3.fromRGB(0,0,255)and unrelatedResolves==0 and s.Fast==0,
		'Local class selectors reach descendants without resolving unrelated branches or using transform-only paint')
	s.Runtime:Destroy()
	-- Compare local invalidation with a separate full build after each write.
	-- Include changed/unchanged filter tokens and selectors whose subject lives
	-- outside the edited subtree; these must never use stale computed styles.
	local markup=require('JavaScript/DOMMarkup')
	for _,css in {
		'.on p{color:blue}',
		'#box:not(.on){background:blue}',
		'#box:is(.on,.other-state){width:72px}',
		'#box:where(.on){background:blue}',
		'#box[class~="on"]{width:72px}',
		'#stage:has(.on){background:blue}',
		'#stage:not(:has(.on)){height:151px}',
		'#stage:has(:is(.on)){background:blue}',
		'#box.on~p{height:31px}',
		'#box.on+p{color:blue}',
		'#stage:has(.on)+#other{height:31px}',
		'#stage>div:nth-child(1 of .on){width:72px}',
		'#stage>div:nth-last-child(1 of :is(.on)){background:blue}',
		'.on p{color:blue}#stage>div:nth-child(1 of .unrelated){color:red}',
		'@scope (#box.on){p{color:blue}}',
		'@scope (#stage) to (.on){p{color:blue}}',
	}do
		s=fixture(css,'<p id="child">Child</p>')
		for _,write in {
			'document.getElementById("box").classList.add("on");',
			'document.getElementById("box").classList.remove("on");',
			'const b=document.getElementById("box");b.className="temporary";b.className="on";',
		}do
			s:Write('{'..write..'}')
			local referenceDocument=Parser.parseDocument(markup.serialize(s.Document))
			local reference=renderer.build(referenceDocument,{AbsoluteSize=Vector2.new(600,800)},error,nil,nil,nil,nil,base..css)
			for _,id in {'stage','box','other','child'}do
				local actual=s.Tree.NodeStyles[Node.findById(s.Document,id)]
				local expected=reference.NodeStyles[Node.findById(referenceDocument,id)]
				assert(actual.Color==expected.Color and actual.Background==expected.Background
					and pixels(actual.Width)==pixels(expected.Width)and pixels(actual.Height)==pixels(expected.Height),
					'Local class invalidation differs from a full cascade for '..id..' in '..css)
			end
		end
		s.Runtime:Destroy()
	end
	s=fixture()
	s:Write('class Probe extends HTMLElement {static get observedAttributes(){return ["class"];}attributeChangedCallback(name,old,value){if(value==="middle")this.className="final";}}customElements.define("scope-probe",Probe);var probe=document.createElement("scope-probe");probe.className="old";document.getElementById("stage").appendChild(probe);')
	s.Runtime:Run('probe.className="middle";')
	local probe=s.Runtime.VM.Global.Bindings.probe.Value.DOMNode
	assert(s.Runtime.Pending[probe].OldAttributes.class=='old'and probe.Attributes.class=='final',
		'Attribute batches retain the original class before reentrant custom-element reactions')
	s.Runtime:Flush();s.Runtime:Destroy()
	-- A style/text batch shares cascade scope, but never the transform-only
	-- painter: the mounted text must refresh in the same flush.
	s=fixture(nil,'Before')
	assert(s:Write('const b=document.getElementById("box");b.style.transform="translateX(5px)";b.textContent="After";')and s.Fast==0)
	assert(s.Box.Children[1].Items[1].Text=='After'and s.Box.Children[1].Items[1].Gui.Text=='After','A mixed transform/text batch must not swallow the rendered text mutation')
	s.Runtime:Destroy()
	for _,entry in {
		{'#stage:has(#box:empty){height:151px}#stage:not(:has(#box:empty)){height:99px}',99,48},
		{'@scope (#stage:has(#box:empty)){#box{width:72px}}',120,48},
	}do
		s=fixture(entry[1])
		s:Write('document.getElementById("box").textContent="Filled";')
		local stage=s.Tree.NodeStyles[Node.findById(s.Document,'stage')]
		assert(pixels(stage.Height)==entry[2]and pixels(s.Box.Style.Width)==entry[3],'Text mutations preserve :empty invalidation in ancestors and scope boundaries')
		s.Runtime:Destroy()
	end
	s=fixture('#stage:has(:dir(rtl)){height:151px}','<span id="auto-dir" dir="auto">Hello</span>')
	s:Write('document.getElementById("auto-dir").textContent="مرحبا";')
	assert(pixels(s.Tree.NodeStyles[Node.findById(s.Document,'stage')].Height)==151,'Automatic text direction invalidates ancestor selectors')
	s.Runtime:Destroy()
	for _,write in {'b.textContent="After"','b.firstChild.data="After"'}do
		s=fixture('#box{color:var(--ink,blue)}','Before')
		local visited={};local originalResolve=Style.resolve
		Style.resolve=function(element,...)visited[element]=true;return originalResolve(element,...)end
		local ok,err=pcall(function()s:Write('const b=document.getElementById("box");document.getElementById("stage").style.setProperty("--ink","#112233");'..write..';')end)
		Style.resolve=originalResolve;assert(ok,err)
		assert(not visited[Node.findById(s.Document,'other')],'Mixed inline variable and text batches must not recascade an unrelated sibling')
		assert(math.abs(s.Box.Style.Color.R-17/255)<.0001 and s.Box.Children[1].Items[1].Gui.Text=='After','Local batches update inherited custom properties and both text mutation forms')
		s.Runtime:Destroy()
	end
	for _,entry in {'#child{transform:inherit}','#child{transform:var(--motion, inherit)}',''} do
		local markup=if entry=='' then '<div id="child" style="transform:inherit">Child</div>' else '<div id="child">Child</div>'
		s=fixture(entry,markup);s:Move(15)
		local child=s.Tree.NodeStyles[Node.findById(s.Document,"child")]
		assert(s.Fast==0 and child.Transform[1].X.Value==15,"Explicit transform inheritance updates descendants")
		s.Runtime:Destroy()
	end
	s=fixture(nil,'<div style="position:fixed;top:0;left:0">Fixed</div>')
	assert(s:Move(10) and s.Fast==0,"Creating a transformed containing block relayouts positioned descendants")
	s.Runtime:Destroy()
	s=fixture('#box{transform:translateX(7px)!important}')
	assert(not s:Move(20) and math.abs(left(s.Box)-283)<.001,"The direct path preserves stylesheet importance")
	assert(not s:Write('document.getElementById("box").style.setProperty("transform","translateX(21px)","important");'))
	assert(math.abs(left(s.Box)-297)<.001,"Inline important transforms win through the same cascade")
	s.Runtime:Destroy()
	s=fixture('#box{--width:48px;width:var(--width)}')
	assert(s:Write('const b=document.getElementById("box");b.style.setProperty("--width","80px");b.style.transform="translateX(5px)";') and s.Fast==0)
	assert(pixels(s.Box.Style.Width)==80,"A mixed geometry/transform batch keeps normal sizing invalidation")
	s.Runtime:Destroy()
	-- An independently running CSS transition on the same box keeps its normal
	-- snapshots, easing and render connection instead of being overwritten.
	s=fixture('#box{transition:transform 1s linear}')
	local time,tick,cleanup=0,nil,nil
	local motion=HTMLAnimations.start({Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)cleanup=fn end},s.Tree,error,
		{RunService={Heartbeat={Connect=function(_,fn)tick=fn;return {Disconnect=function()tick=nil end}end}},Clock=function()return time end},0)
	motion:AfterLayout();assert(not s:Move(100) and s.Fast==0 and motion.Transitions[s.Box])
	time=.5;tick();assert(math.abs(left(s.Box)-326)<1.001,"CSS easing still supplies the intermediate position")
	time=1.1;tick();assert(math.abs(left(s.Box)-376)<1.001)
	cleanup();s.Runtime:Destroy()
	print("Script transforms: 100 local frames, retained geometry/resources, resize anchors, variable/text batching, nested/scope/empty/direction selector guards, inheritance/positioning, cascade importance, mixed sizing and CSS motion passed")
end
