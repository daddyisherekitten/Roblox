--!strict
return function(Parser,Style,Insets,loadRenderTree,loadWordLayout,loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
 local function near(a,b)assert(math.abs(a-b)<.01,tostring(a)..' differs from '..tostring(b))end
 local function resolve(css,parent,warn)return Style.resolve(fixtureElement('div',{style=css}),parent or {},warn or error)end
 local fields={'ColumnRuleInsetCapStart','ColumnRuleInsetCapEnd','ColumnRuleInsetJunctionStart','ColumnRuleInsetJunctionEnd'}
 local function values(css,expected,parent)
  local s=resolve(css,parent)
  for i,field in fields do near(Insets.offset(s[field],10,false),expected[i])end
  return s
 end
 values('column-rule-inset:2px 4px / 6px 8px',{2,4,6,8})
 values('column-rule-inset:3px',{3,3,3,3})
 values('column-rule-inset:3px 5px',{3,5,3,5})
 values('column-rule-inset:2px / 6px 8px',{2,2,6,8})
 values('column-rule-inset:9px;column-rule-inset-start:1px;column-rule-inset-end:2px',{1,2,1,2})
 values('column-rule-inset-cap:1px 2px;column-rule-inset-junction:3px 4px',{1,2,3,4})
 values('column-rule-inset:calc(8px / 2) calc(2px + 50%) / -3px 0',{4,7,-3,0})
 values('--cut:2px 4px / 6px 8px;column-rule-inset:var(--cut)',{2,4,6,8})
 values('font-size:20px;column-rule-inset:.5em',{10,10,10,10})
 local parent=values('column-rule-inset:2px 4px / 6px 8px',{2,4,6,8})
 values('',{0,0,0,0},parent)
 values('column-rule-inset:inherit',{2,4,6,8},parent)
 values('column-rule-inset:9px;column-rule-inset:INITIAL',{0,0,0,0})
 values('column-rule-inset:9px;column-rule-inset:unset',{0,0,0,0},parent)
 values('column-rule-inset:9px;all:initial',{0,0,0,0})
 values('column-rule-inset:9px;column-rule-inset-cap:initial',{0,0,9,9})
 for _,css in {'1px 2px 3px','1px /','/ 1px','1px / 2px / 3px','auto','3','1px bad'} do
  local warnings=0
  local s=resolve('column-rule-inset:7px;column-rule-inset:'..css,nil,function()warnings+=1 end)
  assert(warnings==1,'Invalid shorthand must warn once: '..css)
  for _,field in fields do near(Insets.offset(s[field],10,false),7)end
 end
 local function create(class,parentGui,props)local g=table.clone(props);g.ClassName=class;g.Parent=parentGui;g.Destroy=function()end;return g end
 local renderer=loadRenderTree({create=create,modifier=create})
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*6,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local blocks=''
 for _=1,4 do blocks..='<div style="height:40px">A</div>'end
 local base='columns:2;column-gap:10px;column-height:40px;row-gap:10px;column-rule:2px dotted blue;'
 local function build(css,html)
  local tree=renderer.build(Parser.parse('<div style="'..base..css..'">'..(html or blocks)..'</div>'),{},error)
  layout.arrange(tree,110,0,0,function()return true end)
  return tree.Children[1]
 end
 local function rule(box,index,y,h)
  local r=box.ColumnRules[index];near(r.Position[2],y);near(r.Size[2],h)
  assert(r.Visible==(h>0));return r
 end
 local box=build('column-rule-inset:2px 4px / 6px 8px')
 rule(box,1,2,30);rule(box,2,56,30);near(box.OuterHeight,90)
 near(box.Children[3].LayoutY,50) -- Decoration must not move text or change column height.
 local percent=build('column-rule-inset:50%')
 rule(percent,1,0,35);rule(percent,2,55,35) -- Percentage basis is crossing row-gap; edges have zero gap.
 local joined=build('column-rule-inset:overlap-join')
 rule(joined,1,0,45);rule(joined,2,45,45)
 local negative=build('column-rule-inset:-2px -4px')
 rule(negative,1,-2,46);rule(negative,2,48,46)
 local clipped=build('column-rule-inset:25px')
 rule(clipped,1,25,0);rule(clipped,2,75,0)
 -- A last row with only one column has no continuing separator: use cap-end at the preceding crossing.
 local partial=build('column-rule-inset:2px 50% / 6px 8px',blocks..'<div style="height:40px">E</div>')
 rule(partial,1,2,30);rule(partial,2,56,29)
 local edge=build('column-rule-inset:50%', '<div style="height:40px">A</div><div style="height:40px">B</div>')
 rule(edge,1,0,40)
 local dynamic=renderer.build(Parser.parse('<style>#c{'..base..'}#c:hover{column-rule-inset:5px}</style><div id="c">'..blocks..'</div>'),{},error)
 layout.arrange(dynamic,110,0,0,function()return true end)
 local c=dynamic.Children[1];local retained=rule(c,1,0,40)
 dynamic:SetCSSState('hover',c.Node);layout.arrange(dynamic,110,0,0,function()return true end)
 assert(c.ColumnRules[1]==retained);rule(c,1,5,30);rule(c,2,55,30)
 dynamic:SetCSSState('hover',nil);layout.arrange(dynamic,110,0,0,function()return true end)
 rule(c,1,0,40)
 c.Style.Direction='rtl';layout.arrange(dynamic,110,0,0,function()return true end)
 rule(c,1,0,40)
 print('Column rule insets: shorthand/longhand cascade, variables, units, resets, rejection, cap/junction geometry, percentages, overlap joins and live state passed')
end
