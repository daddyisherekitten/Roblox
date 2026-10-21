--!strict
return function(Parser, Style, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, parent, warn) return Style.resolve(fixtureElement('div',{style=css}), parent or {}, warn or error) end
	local s = resolve('margin:10px auto 20px; margin-left:4px')
	assert(s.Margin[1] == 10 and s.Margin[2] == 0 and s.Margin[3] == 20 and s.Margin[4] == 4)
	assert(s.MarginAuto[2] and not s.MarginAuto[4])
	assert(resolve('margin-left:auto!important;margin:0').MarginAuto[4])
	assert(not resolve('margin:auto;margin:3px').MarginAuto[4])
	assert(not resolve('', resolve('margin:auto')).MarginAuto[1])
	for css, expected in {['column wrap']={'column','wrap'}, ['wrap-reverse row-reverse']={'row-reverse','wrap-reverse'}, ['wrap']={'row','wrap'}, ['column']={'column','nowrap'}} do
		local flow = resolve('flex-direction:column-reverse;flex-wrap:wrap-reverse;flex-flow:' .. css)
		assert(flow.FlexDirection == expected[1] and flow.FlexWrap == expected[2])
	end
	assert(resolve('flex-flow:column wrap!important;flex-direction:row').FlexDirection == 'column')
	assert(resolve('flex-flow:column wrap;flex-wrap:nowrap').FlexWrap == 'nowrap')
	for _, css in {'padding:auto', 'padding-left:auto', 'padding:-1px', 'flex-flow:row column', 'flex-flow:wrap wrap', 'flex-flow:row wrap bad'} do
		local count=0; resolve(css,nil,function() count+=1 end); assert(count==1,css)
	end
	local objects, measurements = 0, 0
	local renderer=loadRenderTree({create=function(_,_,props) objects+=1; return table.clone(props) end})
	local overrides={['Layout/FontProfiles']={face=function(font) return font end},['Layout/TextMeasure']={measure=function(text,_,size) measurements+=1; return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local function near(a,b) assert(math.abs(a-b)<1e-5,tostring(a)..' != '..tostring(b)) end
	local function position(box,x,y) near(box.Gui.Position[1],x); near(box.Gui.Position[2],y) end
	local function arrange(tree,width) return layout.arrange(tree,width or 300,0,0,function() return true end) end
	local function build(css,children,width)
		local tree=renderer.build(Parser.parse('<div style="display:flex;'..css..'">'..children..'</div>'),{},error)
		arrange(tree,width); return tree,tree.Children[1].Children
	end
	local function card(css) return '<div style="width:40px;height:20px;'..css..'">AA</div>' end
	local tree,items=build('gap:10px',card('')..card('margin-left:auto'))
	position(items[1],0,0); position(items[2],260,0)
	local alloc,measured=objects,measurements
	arrange(tree,200); position(items[2],160,0); arrange(tree,300)
	assert(alloc==objects and measured==measurements and items[2].Style.Margin[4]==0 and items[2].LayoutMargin[4]==0)
	local _,center=build('height:100px',card('margin:auto')); position(center[1],130,40)
	local _,share=build('',card('margin-left:auto')..card('margin-left:auto'))
	position(share[1],110,0); position(share[2],260,0)
	local _,grow=build('',card('flex-grow:1')..card('margin-left:auto'))
	near(grow[1].OuterWidth,260); position(grow[2],260,0)
	local _,limited=build('',card('flex-grow:1;max-width:100px')..card('margin-left:auto'))
	near(limited[1].OuterWidth,100); position(limited[2],260,0)
	local _,over=build('justify-content:center',card('width:400px;flex:none;margin-left:auto'))
	position(over[1],-50,0)
	local _,crossOver=build('height:10px;align-items:center',card('margin-top:auto;margin-bottom:auto'))
	position(crossOver[1],0,0)
	local _,crossReverse=build('height:100px;flex-wrap:wrap-reverse',card('margin-top:auto'))
	position(crossReverse[1],0,80)
	local _,ignoreAlign=build('height:100px;align-items:flex-end',card('margin-bottom:auto;align-self:center'))
	position(ignoreAlign[1],0,0)
	local _,natural=build('height:100px','<div style="margin-top:auto;line-height:20px">AA</div>')
	near(natural[1].OuterHeight,20); position(natural[1],0,80)
	local _,column=build('height:100px;flex-flow:column',card('')..card('margin-top:auto'))
	position(column[2],0,80)
	local _,columnAutoWidth=build('height:100px;flex-flow:column','<div style="margin-left:auto;line-height:20px">AA</div>')
	near(columnAutoWidth[1].OuterWidth,10); position(columnAutoWidth[1],290,0)
	local _,reverse=build('flex-flow:row-reverse',card('margin-left:auto')..card(''))
	position(reverse[1],260,0); position(reverse[2],0,0)
	local _,columnReverse=build('height:100px;flex-flow:column-reverse',card('margin-top:auto')..card(''))
	position(columnReverse[1],0,80); position(columnReverse[2],0,0)
	local _,wrap=build('flex-flow:wrap;gap:10px',card('width:100px;margin-left:auto')..card('width:100px;margin-left:auto')..card('width:100px;margin-left:auto'),250)
	position(wrap[1],20,0); position(wrap[2],150,0); position(wrap[3],150,30)
	local _,fixed=build('height:100px',card('padding:5px;border:2px solid;margin:3px auto 7px 9px'))
	position(fixed[1],9,3)
	local _,physical=build('height:100px;flex-flow:row-reverse wrap-reverse',card('margin:10px 20px auto auto'))
	position(physical[1],240,10)
	local block=renderer.build(Parser.parse('<div style="width:100px;margin:10px auto;height:20px"></div><div style="max-width:120px;margin-left:auto;height:10px"></div>'),{},error)
	arrange(block); position(block.Children[1],100,10); position(block.Children[2],180,40)
	local large=renderer.build(Parser.parse('<div style="width:400px;margin: auto;height:20px"></div>'),{},error)
	arrange(large); position(large.Children[1],0,0)
	local overflowing=renderer.build(Parser.parse('<div style="width:100px;margin:0 auto"><div style="width:400px;height:20px"></div></div>'),{},error)
	local _, right = arrange(overflowing)
	near(right,500)
	local rule=renderer.build(Parser.parse('<hr style="width:100px;margin-right:auto">'),{},error)
	arrange(rule); near(rule.Children[1].Gui.Position[1],99)
	local _, flexRule=build('','<hr style="width:100px">')
	near(flexRule[1].Gui.Position[1],99)
	print('Auto margins/flex-flow: cascade, physical sides, post-flex sharing, cross alignment, nowrap/wrap/reverse, normal blocks and resize reuse passed')
end
