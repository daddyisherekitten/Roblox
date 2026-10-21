--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, parent) return Style.resolve(fixtureElement('div',{style=css}),parent or {},error) end
	assert(resolve('align-items:baseline').AlignItems == 'baseline')
	assert(resolve('align-self:baseline!important;align-self:center').AlignSelf == 'baseline')
	local defaults=resolve('',resolve('align-items:baseline;align-self:baseline'))
	assert(defaults.AlignItems == 'stretch' and defaults.AlignSelf == 'auto')
	local objects, measurements=0,0
	local renderer=loadRenderTree({create=function(_,_,props) objects+=1; return table.clone(props) end})
	local overrides={['Layout/FontProfiles']={face=function(font) return font end},
		['Layout/TextMeasure']={measure=function(text,_,size) measurements+=1; return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local function near(a,b) assert(math.abs(a-b)<1e-5,tostring(a)..' != '..tostring(b)) end
	local function arrange(tree,width) return layout.arrange(tree,width or 300,0,0,function() return true end) end
	local function build(css,children,width)
		local tree=renderer.build(Parser.parse('<div style="display:flex;align-items:baseline;'..css..'">'..children..'</div>'),{},error)
		arrange(tree,width); return tree,tree.Children[1].Children
	end
	local function card(css,text) return '<div style="flex:none;width:60px;line-height:1;'..css..'">'..(text or 'Hx')..'</div>' end
	local function baseline(item) return item.Gui.Position[2]+(item.FirstBaseline or item.OuterHeight) end
	local pair=card('font-size:12px;padding:3px 0 25px;border:2px solid;margin-top:4px')..card('font-size:32px;padding-top:10px;margin-bottom:6px')
	local tree,items=build('gap:10px',pair)
	near(baseline(items[1]),baseline(items[2]))
	local maxBefore=math.max(items[1].FirstBaseline+4,items[2].FirstBaseline)
	near(baseline(items[1]),maxBefore)
	local maxAfter=math.max(items[1].OuterHeight-items[1].FirstBaseline,items[2].OuterHeight-items[2].FirstBaseline+6)
	near(tree.Children[1].OuterHeight,maxBefore+maxAfter)
	near(tree.Children[1].FirstBaseline,maxBefore)
	local alloc,measured=objects,measurements
	arrange(tree,180); arrange(tree,300)
	assert(objects==alloc and measurements==measured)
	near(baseline(items[1]),baseline(items[2]))
	for _, direction in {'row','row-reverse'} do
		for _, wrap in {'wrap','wrap-reverse'} do
			local wrapped,boxes=build('flex-flow:'..direction..' '..wrap..';height:200px;gap:8px;align-content:flex-start',pair..pair,150)
			near(baseline(boxes[1]),baseline(boxes[2])); near(baseline(boxes[3]),baseline(boxes[4]))
			assert(baseline(boxes[1])~=baseline(boxes[3]))
			if wrap=='wrap-reverse' then
				near(math.max(boxes[1].Gui.Position[2]+boxes[1].OuterHeight,boxes[2].Gui.Position[2]+boxes[2].OuterHeight+6),200)
			end
			local count,reads=objects,measurements
			arrange(wrapped,300); near(baseline(boxes[1]),baseline(boxes[4]))
			arrange(wrapped,150); near(baseline(boxes[3]),baseline(boxes[4]))
			assert(objects==count and measurements==reads)
		end
	end
	local _,self=build('align-items:flex-start',card('align-self:baseline;font-size:12px')..card('align-self:baseline;font-size:32px')..card('font-size:50px'))
	near(baseline(self[1]),baseline(self[2])); near(self[3].Gui.Position[2],0)
	local _,auto=build('height:100px',card('font-size:12px')..card('font-size:50px;margin-top:auto'))
	near(auto[1].Gui.Position[2],0); near(auto[2].Gui.Position[2]+auto[2].OuterHeight,100)
	local _,empty=build('',card('height:40px;border:2px solid;margin-top:3px','')..card('font-size:12px'))
	near(baseline(empty[1]),baseline(empty[2])); near(baseline(empty[1]),47)
	local _,multi=build('',card('font-size:12px','AA<br>BB')..card('font-size:32px'))
	near(baseline(multi[1]),baseline(multi[2]))
	local _,nested=build('', '<div style="display:flex;padding:7px;align-items:baseline">'..card('align-self:flex-start;font-size:10px')..card('font-size:32px')..'</div>'..card('font-size:12px'))
	near(baseline(nested[1]),baseline(nested[2]))
	near(nested[1].FirstBaseline,baseline(nested[1].Children[2]))
	local _,anonymous=build('font-size:12px;line-height:1','AA'..card('font-size:32px'))
	near(anonymous[1].Items[1].Gui.Position[2]+anonymous[1].Items[1].Baseline,baseline(anonymous[2]))
	local _,short=build('height:5px',pair)
	near(baseline(short[1]),baseline(short[2]))
	for _, direction in {'column','column-reverse'} do
		local _,columns=build('height:100px;flex-direction:'..direction,pair)
		near(columns[1].Gui.Position[1],0); near(columns[2].Gui.Position[1],0)
	end
	print('Flex baseline: cascade, first lines, margins/box edges, line height, wrap/reverse, auto precedence, empty/nested/anonymous items and resize reuse passed')
end
