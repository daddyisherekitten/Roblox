--!strict
-- Count actual work, not FPS or wall-clock time, on a large retained page.
return function(Parser, DOM, Selectors, Stylesheet, Generated, BoxTransform, loadRenderTree, loadWordLayout, loadBlockLayout, HTMLAnimations)
	local matches, generatedUpdate, resolve, apply = Selectors.matches, Generated.update, BoxTransform.resolve, BoxTransform.apply
	local ok, message = xpcall(function()
		local parts={'<main id="main"><nav id="nav"><a id="one" class="link" href="#"><span id="inside">One</span></a><a id="two" class="link" href="#">Two</a></nav>'}
		for index=1,300 do table.insert(parts,'<section id="unrelated-'..index..'"><p>Unrelated content</p></section>') end
		table.insert(parts,'</main>')
		local document=Parser.parse(table.concat(parts))
		local one, inside, two = DOM.findById(document,'one'), DOM.findById(document,'inside'), DOM.findById(document,'two')
		local checks=0
		Selectors.matches=function(...) checks+=1;return matches(...) end
		local rules=Stylesheet.collect(document,error,'.link:hover{color:red}nav a:is(:hover,:active){color:blue}a:not(:hover){color:green}')
		local changed, affected=Stylesheet.stateChanges(rules,document,'hover',{}, {hover=inside})
		assert(changed and affected[one] and not affected[two])
		assert(checks<80,'Subject hover must not test selectors against hundreds of unrelated elements')
		checks=0
		changed=Stylesheet.stateChanges(rules,document,'hover',{hover=one},{hover=inside})
		assert(not changed and checks<80,'Moving between a link and its text does not restyle the link')
		DOM.removeChild(inside.Parent,inside)
		assert(not Stylesheet.stateChanges(rules,document,'hover',{}, {hover=inside}),'Detached elements are outside the invalidation scope')
		DOM.append(one,inside)
		assert(Stylesheet.stateChanges(rules,document,'hover',{}, {hover=inside}),'Reattached elements use their current ancestors')

		-- Compare optimized invalidation with exhaustive matching, including
		-- nested/relational dependencies which intentionally use the full path.
		local selectors={'.link:hover','nav a:is(:hover,:active)','a:not(:hover)',
			'nav:hover a','a:hover + a','nav:has(a:hover)','nav:has(a:hover) a',
			'a:is(nav:hover a,#two)','nav:not(:has(a:hover))','a:focus','nav:focus-within','a:focus-visible'}
		for _, source in selectors do
			local set=Stylesheet.collect(document,error,source..'{color:red}')
			for _, state in {'hover','active','focus','focus-visible'} do
				for _, pair in {{false,inside},{inside,two},{one,inside},{inside,one},{two,false}} do
					local before, after = {[state]=if pair[1] then pair[1] else nil},{[state]=if pair[2] then pair[2] else nil}
					local _, actual=Stylesheet.stateChanges(set,document,state,before,after)
					local pending={document}
					while #pending>0 do
						local node=table.remove(pending)
						if node.Kind=='Element' then
							local expected=matches(node,set[1],before)~=matches(node,set[1],after)
							assert((actual[node]==true)==expected,'State invalidation mismatch: '..source..' / '..state)
						end
						for _, child in node.Children do table.insert(pending,child) end
					end
				end
			end
		end
		Selectors.matches=matches

		local created, measured, painted, svgUpdates, generatedPasses = 0,0,{},0,0
		local function create(class,parent,props)
			created+=1
			local values={ClassName=class,Parent=parent,AnchorPoint=Vector2.new(0,0)}
			for key,value in props do values[key]=value end
			values.Destroy=function() end
			return setmetatable({}, {__index=values,__newindex=function(_,key,value)
				if values[key]~=value then painted[key]=(painted[key]or 0)+1 end
				values[key]=value
			end})
		end
		local renderer=loadRenderTree({create=create,modifier=create})
		local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)measured+=1;return {X=#text*size*.5,Y=size}end}}
		overrides['Layout/WordLayout']=loadWordLayout(overrides)
		local layout=loadBlockLayout(overrides)
		local css='a{display:block;color:black;cursor:pointer}a:hover{color:red}'
			..'#scene{display:block;width:40px;height:40px;animation:turn 2s linear infinite}'
			..'@keyframes turn{from{transform:translateX(0)}to{transform:translateX(20px)}}'
		local markup=table.concat(parts)..'<ol><li>Unrelated marker</li></ol><svg id="scene" width="40" height="40"><rect width="40" height="40"/></svg>'
		local doc=Parser.parse(markup)
		local tree=renderer.build(doc,{},error,nil,nil,nil,function()return 'rbxassetid://1'end,css)
		layout.arrange(tree,600,0,0,function()return true end)
		local node=DOM.findById(doc,'one')
		local scene=tree.NodeBoxes[DOM.findById(doc,'scene')]
		scene.ImageItem.UpdateSVG=function()svgUpdates+=1 end
		local clock, frame, cleanup = 0,nil,nil
		local runtime=HTMLAnimations.start({Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)cleanup=fn end},tree,error,
			{RunService={Heartbeat={Connect=function(_,fn)frame=fn;return {Disconnect=function()frame=nil end}end}},Clock=function()return clock end},0)
		runtime:AfterLayout()
		assert(frame,'Fixture includes a running unrelated SVG animation')
		local beforeCreated,beforeMeasured=created,measured
		local boxPaints,otherTransforms=0,0
		Generated.update=function(...)generatedPasses+=1;return generatedUpdate(...)end
		BoxTransform.apply=function(...)boxPaints+=1;return apply(...)end
		BoxTransform.resolve=function(box,...)
			if box.Node~=node then otherTransforms+=1 end
			return resolve(box,...)
		end
		for _=1,30 do
			table.clear(painted);clock+=.01
			local didChange,needsLayout=tree:SetCSSState('hover',node)
			assert(didChange and needsLayout==false)
			assert((painted.TextColor3 or 0)>0,'The visible glyphs receive their hover color')
			assert(not painted.Position and not painted.Size and not painted.AnchorPoint,'Color hover must not touch geometry')
			local target=tree.NodeStyles[DOM.findById(doc,'inside')]
			assert(target.Color==Color3.fromRGB(255,0,0),'Nested text inherits the hovered link color')
			local run=tree.NodeBoxes[node].Children[1]
			for _,item in run.DisplayItems or run.Items do
				for index,binding in item.DecorationBindings or {} do
					if item.DecorationFrames[index].Visible~=false then
						assert(item.DecorationFrames[index].BackgroundColor3==binding.Style.Decorations[binding.Index].Color,'Retained underline segments receive the hover color')
					end
				end
			end
			tree:SetCSSState('hover',nil)
			assert(target.Color==Color3.fromRGB(0,0,0),'Leaving restores the inherited color')
		end
		assert(created==beforeCreated and measured==beforeMeasured,'Repeated color hover retains GUI and measurements')
		assert(boxPaints==0 and otherTransforms==0,'Plain color hover never repaints box transforms or touches unrelated animation geometry')
		assert(svgUpdates==0 and generatedPasses==0,'Unrelated SVGs and list counters remain untouched')
		clock=.5;frame();assert(scene.TransformBaseX~=nil,'Unrelated animation continues on its own frame callback')
		cleanup()
		BoxTransform.apply,BoxTransform.resolve=apply,resolve
		Generated.update=generatedUpdate

		-- State-only filtering must still discover newly generated output and
		-- inherited currentColor on generated descendants and inline controls.
		local pseudoDoc=Parser.parse('<div id="pseudo">Text</div><div id="parent"><span id="generated">Child</span></div><input id="input" value="Color">')
		local pseudoTree=renderer.build(pseudoDoc,{},error,nil,nil,nil,nil,
			'#pseudo:hover::before{content:"New"}#parent:hover{color:red}#generated::after{content:"Tail"}#input:hover{color:red}')
		layout.arrange(pseudoTree,600,0,0,function()return true end)
		local _,needsLayout=pseudoTree:SetCSSState('hover',DOM.findById(pseudoDoc,'pseudo'))
		assert(needsLayout,'A new hover pseudo still enters generated-content reconciliation')
		pseudoTree:SetCSSState('hover',nil)
		local _,inheritedLayout=pseudoTree:SetCSSState('hover',DOM.findById(pseudoDoc,'parent'))
		assert(inheritedLayout,'Generated descendants still receive inherited style updates')
		pseudoTree:SetCSSState('hover',DOM.findById(pseudoDoc,'input'))
		for _,control in pseudoTree.Controls do
			if control.Node.Attributes.id=='input' then assert(control.Item.Editor.TextColor3==Color3.fromRGB(255,0,0),'Inline controls retain their color painter') end
		end
		for _,doctype in {'','<!doctype html>','<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">'}do
			local doc=Parser.parseDocument(doctype..'<html><body><div id="target"><span id="child">Point</span></div><div id="qualified">Qualified</div></body></html>')
			local view=renderer.build(doc,{},error,nil,nil,nil,nil,'*{color:black}:hover{color:red}#qualified:hover{color:blue}')
			layout.arrange(view,600,0,0,function()return true end)
			local target,qualified=DOM.findById(doc,'target'),DOM.findById(doc,'qualified')
			local gui=view.NodeBoxes[target].Gui;local count=created
			local _,needs=view:SetCSSState('hover',DOM.findById(doc,'child'))
			assert(view.NodeStyles[target].Color==(if doctype==''then Color3.fromRGB(0,0,0)else Color3.fromRGB(255,0,0)),'Mounted bare hover follows the document mode')
			assert(not needs and view.NodeBoxes[target].Gui==gui and created==count,'Bare hover only paints retained surfaces')
			view:SetCSSState('hover',qualified)
			assert(view.NodeStyles[qualified].Color==Color3.fromRGB(0,0,255),'Qualified hover works in every mode')
			view:SetCSSState('hover',nil);assert(view.NodeStyles[target].Color==Color3.fromRGB(0,0,0),'Hover exit restores the original cascade')
		end
	end,debug.traceback)
	Selectors.matches,Generated.update,BoxTransform.resolve,BoxTransform.apply=matches,generatedUpdate,resolve,apply
	assert(ok,message)
	print('Hover work: local subject invalidation, exhaustive complex-selector equivalence, retained color painting, untouched SVG/animation/counters, generated content and controls passed')
end
