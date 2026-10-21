--!strict
return function(Parser, Style, Color, Names, loadRenderTree, loadWordLayout, loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css,parent,warn) return Style.resolve(fixtureElement('div',{style=css}),parent or {FontSize=20},warn or error) end
	local function near(a,b) assert(math.abs(a-b)<1e-5,tostring(a)..' != '..tostring(b)) end
	local s=resolve('gap:5px 7px;row-gap:12px;column-gap:9px!important;gap:1px')
	assert(s.Gap[1]==1 and s.Gap[2]==9)
	local a=resolve('row-gap:12px;column-gap:7px'); local b=resolve('',a)
	assert(b.Gap[1]==0 and b.Gap[2]==0)
	assert(resolve('gap:9px;row-gap:normal').Gap[1]==0)
	assert(resolve('gap:normal 8px').Gap[2]==8)
	local percentage=resolve('row-gap:10%')
	assert(percentage.Gap[1].Percent and percentage.Gap[1].Value==10 and percentage.Gap[2]==0,'Author percentage gaps remain computed values until the layout axis is definite')
	local inset=resolve('inset:1px auto -3px 20%;right:4px!important;inset:9px auto')
	assert(inset.Insettop.Value==9 and inset.Insetbottom.Value==9 and inset.Insetleft==nil and inset.Insetright.Value==4)
	local reset=resolve('left:5px;right:9px;inset:auto')
	assert(reset.Insetleft==nil and reset.Insetright==nil and reset.Insettop==nil and reset.Insetbottom==nil)
	local triple=resolve('inset:2px auto 4px'); assert(triple.Insetbottom.Value==4 and triple.Insetleft==nil)
	assert(resolve('left:3px!important;inset:0').Insetleft.Value==3)
	for _,css in {'inset:0 1px 2px 3px 4px','inset:-+2px','left:-+2px','column-gap:-1px','border-radius:thin','padding-left:thick','tab-size:medium'} do
		local count=0; resolve(css,nil,function() count+=1 end); assert(count==1,css)
	end
	for keyword,size in {thin=1,medium=3,thick=5} do
		assert(resolve('border:solid orange;border-width:'..keyword).BorderSize==size)
		assert(resolve('border:'..keyword..' solid navy').BorderSize==size)
	end
	near(resolve('font-size:larger').FontSize,24)
	near(resolve('font-size:larger',resolve('font-size:larger')).FontSize,28.8)
	near(resolve('font-size:larger',{FontSize=95}).FontSize,100)
	local count=0
	for name,hex in Names do count+=1; assert(Color.parse(name)==Color.parse(hex),name) end
	assert(count==148 and Color.parse('rebeccapurple')==Color3.fromRGB(102,51,153))
	assert(Color.parse('grey')==Color.parse('gray') and Color.parse('aqua')==Color.parse('cyan'))
	assert(Color.parse('notacolor')==nil)
	assert(resolve('color:ORANGE').Color==Color3.fromRGB(255,165,0))
	local objects,measurements=0,0
	local renderer=loadRenderTree({create=function(_,_,props) objects+=1; return table.clone(props) end})
	local overrides={['Layout/FontProfiles']={face=function(font) return font end},
		['Layout/TextMeasure']={measure=function(text,_,size) measurements+=1; return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local function build(html,width)
		local tree=renderer.build(Parser.parse(html),{},error)
		layout.arrange(tree,width or 200,0,0,function() return true end); return tree
	end
	local text=build('<div><ins>Neu</ins> <kbd>Taste</kbd> <samp>Ausgabe</samp> <var>x</var> <cite>Buch</cite> <dfn>Begriff</dfn></div>',500)
	local items=text.Children[1].Children[1].Items
	assert(#items==6 and items[1].Style.Decorations[1].Underline)
	assert(items[2].Style.Font=='Roboto Mono' and items[3].Style.Font=='Roboto Mono')
	for i=4,6 do assert(items[i].Style.FontStyle=='italic') end
	local overridden=build('<div><ins style="text-decoration:none">A</ins><kbd style="font-family:Roboto">B</kbd><var style="font-style:normal">C</var></div>')
	local o=overridden.Children[1].Children[1].Items
	assert(#o[1].Style.Decorations==0 and o[2].Style.Font=='Roboto' and o[3].Style.FontStyle=='normal')
	for _,align in {'start','end'} do
		local aligned=build('<div style="text-align:'..align..'">AA<br>BB</div>',100)
		local run=aligned.Children[1].Children[1]
		near(run.Items[1].X,if align=='start' then 0 else 90)
		near(run.Items[3].X,if align=='start' then 0 else 90)
	end
	local flex=build('<div style="display:flex;flex-wrap:wrap;row-gap:7px;column-gap:11px"><div style="width:40px;height:20px"></div><div style="width:40px;height:20px"></div><div style="width:40px;height:20px"></div></div>',100)
	local boxes=flex.Children[1].Children
	near(boxes[2].LayoutX,51); near(boxes[3].LayoutY,27)
	local abs=build('<div style="position:relative;height:100px"><span style="position:absolute;inset:10px 20px auto auto;width:40px;height:20px">AA</span></div>',200)
	local badge=abs.Children[1].Children[1]
	near(badge.Gui.Position[1],140); near(badge.Gui.Position[2],10)
	local allocated,measured=objects,measurements
	layout.arrange(abs,300,0,0,function() return true end)
	near(badge.Gui.Position[1],240)
	assert(objects==allocated and measurements==measured)
	print('Simple features: gap/inset cascade and layout, keyword borders, larger, LTR start/end, 148 named colors, six inline tags and resize reuse passed')
end
