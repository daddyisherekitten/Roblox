--!strict
return function(Parser,Style,loadRenderTree,loadWordLayout,loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
 local function resolve(css,parent,warn)return Style.resolve(fixtureElement('div',{style=css}),parent or {},warn or error)end
 local function near(a,b)assert(math.abs(a-b)<.01,tostring(a)..' differs from '..tostring(b))end
 local function create(class,parent,props)local g=table.clone(props);g.ClassName=class;g.Parent=parent;g.Destroy=function()end;return g end
 local renderer=loadRenderTree({create=create,modifier=create})
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*6,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local function build(css,html)
  local tree=renderer.build(Parser.parse('<div style="'..css..'">'..html..'</div>'),{},error)
  layout.arrange(tree,110,0,0,function()return true end)
  return tree,tree.Children[1]
 end
 local blocks='<div style="height:20px">A</div><div style="height:20px">B</div><div style="height:20px">C</div><div style="height:20px">D</div><div style="height:20px">E</div>'
 local _,box=build('columns:2;column-gap:10px;column-height:40px;row-gap:7px;column-rule:2px dotted blue',blocks)
 assert(box.ColumnLayout.Rows==2)
 near(box.Children[3].LayoutX,60);near(box.Children[3].LayoutY,0)
 near(box.Children[5].LayoutX,0);near(box.Children[5].LayoutY,47)
 near(box.OuterHeight,87);near(box.UnclippedRight,110)
 assert(#box.ColumnRules==1 and box.ColumnRules[1].Size[2]==40 and #box.ColumnLayout.Segments==2)
 box.Style.Direction='rtl';layout.arrange(box,110,0,0,function()return true end)
 near(box.Children[1].LayoutX,60);near(box.Children[3].LayoutX,0)
 local _,nowrap=build('columns:2;column-gap:10px;column-height:40px;column-wrap:nowrap',blocks)
 near(nowrap.OuterHeight,40);near(nowrap.Children[5].LayoutX,120);near(nowrap.Children[5].LayoutY,0)
 local _,single=build('column-height:40px;row-gap:5px',blocks)
 assert(single.ColumnLayout.Count==1);near(single.OuterHeight,130);near(single.Children[3].LayoutY,45)
 local _,zero=build('columns:2;column-height:0;row-gap:3px',blocks)
 assert(zero.ColumnLayout.Rows==3,'Zero height must make finite progress through indivisible items')
 local _,forced=build('columns:2;column-gap:10px',
  '<div style="height:20px">A</div><div style="height:20px;break-before:column">B</div><div style="height:20px;break-after:column">C</div><div style="height:20px">D</div>')
 near(forced.Children[1].LayoutX,0);near(forced.Children[2].LayoutX,60)
 near(forced.Children[3].LayoutX,60);near(forced.Children[4].LayoutX,120)
 near(forced.OuterHeight,40)
 local _,adjacent=build('columns:2;column-gap:10px;height:100px',
  '<div style="height:20px;break-after:column">A</div><div style="height:20px;break-before:column">B</div>')
 near(adjacent.Children[2].LayoutX,60)
 local _,nested=build('columns:2;column-gap:10px',
  '<section><p style="margin:0;line-height:20px">A</p><p style="margin:0;line-height:20px;break-before:column">B</p></section>')
 local a=nested.Children[1].Children[1].Children[1].Items[1]
 local b=nested.Children[1].Children[2].Children[1].Items[1]
 near(b.X-a.X,60)
 local inherited=resolve('column-height:40px;column-wrap:wrap;break-before:column;break-after:column')
 local initial=resolve('',inherited)
 assert(initial.ColumnHeight==nil and initial.ColumnWrap=='auto' and initial.BreakBefore=='auto' and initial.BreakAfter=='auto')
 assert(resolve('column-height:inherit',inherited).ColumnHeight.Value==40)
 assert(resolve('column-height:40px;column-height:initial').ColumnHeight==nil)
 local shorthand=resolve('columns:2 45px / 40px')
 assert(shorthand.ColumnCount==2 and shorthand.ColumnWidth.Value==45 and shorthand.ColumnHeight.Value==40)
 assert(resolve('column-height:40px;columns:2').ColumnHeight==nil)
 assert(resolve('columns:inherit',shorthand).ColumnHeight.Value==40)
 assert(resolve('columns:auto / 40px').ColumnHeight.Value==40)
 for _,css in {'column-height:-1px','column-height:20%','column-wrap:bad','break-before:bad','break-after:bad'} do
  local warnings=0;resolve(css,nil,function()warnings+=1 end);assert(warnings==1)
 end
 local gap=resolve('gap:7px 10px;row-gap:normal;column-gap:normal')
 assert(not gap.RowGapSpecified and not gap.GridGapSpecified)
 local dynamic=renderer.build(Parser.parse('<style>#c{columns:2;column-height:40px;row-gap:7px}#c:hover{column-wrap:nowrap}</style><div id="c">'..blocks..'</div>'),{},error)
 layout.arrange(dynamic,110,0,0,function()return true end)
 local c=dynamic.Children[1];assert(c.ColumnLayout.Rows==2)
 dynamic:SetCSSState('hover',c.Node);layout.arrange(dynamic,110,0,0,function()return true end)
 assert(c.Style.ColumnWrap=='nowrap' and c.ColumnLayout.Rows==1)
 print('Column features: forced/adjacent/nested breaks, fixed-height rows, gap, RTL, nowrap, zero-height progress, inheritance, invalid values and live state passed')
end
