--!strict
return function(Parser,Style,Values,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
 local function near(a,b) assert(a and math.abs(a-b)<.001,tostring(a)..' != '..tostring(b)) end
 local count=0
 local renderer=loadRenderTree({create=function(_,_,p) count+=1;return table.clone(p) end})
 local overrides={['Layout/FontProfiles']={face=function(f) return f end},['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local function resolve(s) return Style.resolve(fixtureElement('div',{style=s}),{},error) end
 local function build(css,content,width)
  local tree=renderer.build(Parser.parse('<div style="display:grid;'..css:gsub('"','&quot;')..'">'..content..'</div><div style="height:5px"></div>'),{},error)
  layout.arrange(tree,width or 300,0,0,function() return true end)
  return tree.Children[1],tree
 end
 local function pos(b,x,y,w,h) near(b.LayoutX,x);near(b.LayoutY,y);if w then near(b.OuterWidth,w) end;if h then near(b.OuterHeight,h) end end
 local cards='<div style="height:20px">A</div><div style="height:30px">B</div><div style="height:25px">C</div>'
 for _,css in {
  'grid-gap:8px 12px',
  'grid-row-gap:8px;grid-column-gap:12px',
  'gap:50px;grid-gap:8px 12px',
  'grid-gap:50px;gap:8px 12px',
  'grid-gap:50px;row-gap:8px;column-gap:12px',
  '--space:8px 12px;grid-gap:var(--space)',
  'gap:8px 12px!important;grid-gap:50px',
  'grid-gap:8px 12px!important;gap:50px',
 } do
  local aliasGrid=build('grid-template-columns:100px 1fr;'..css,cards)
  pos(aliasGrid.Children[2],112,0,188,30);pos(aliasGrid.Children[3],0,38,100,25)
 end
 for _,css in {'grid-gap:normal','grid-gap:8px 12px;grid-gap:initial','gap:8px 12px;grid-row-gap:unset;grid-column-gap:initial'} do
  local aliasGrid=build('grid-template-columns:100px 1fr;'..css,cards)
  pos(aliasGrid.Children[2],100,0,200,30);pos(aliasGrid.Children[3],0,30,100,25)
 end
 local inherited=Style.resolve(fixtureElement('div',{style='grid-row-gap:inherit;grid-column-gap:inherit'}),resolve('gap:8px 12px'),error)
 near(inherited.Gap[1],8);near(inherited.Gap[2],12)
 local warnings={}
 local invalid=Style.resolve(fixtureElement('div',{style='grid-gap:8px 12px;grid-gap:-2px'}),{},function(message) table.insert(warnings,message) end)
 near(invalid.Gap[1],8);near(invalid.Gap[2],12);assert(#warnings==1,'Invalid alias retains the preceding gap and reports a warning')
 local g,tree=build('grid-template-columns:100px 1fr;gap:10px',cards)
 pos(g.Children[1],0,0,100,20);pos(g.Children[2],110,0,190,30);pos(g.Children[3],0,40,100,25);near(g.OuterHeight,65);pos(tree.Children[2],0,65)
 local allocated=count;layout.arrange(tree,500,0,0,function() return true end);near(g.Children[2].OuterWidth,390);assert(count==allocated,'Resize reuses GUI')
 g=build('grid-template-columns:1fr 2fr;gap:12px',cards);near(g.Children[1].OuterWidth,96);near(g.Children[2].OuterWidth,192)
 g=build('grid-template-columns:repeat(3,minmax(0,1fr));gap:6px','<div style="grid-column:span 2;height:20px">A</div><div style="height:20px">B</div>')
 pos(g.Children[1],0,0,198);pos(g.Children[2],204,0,96)
 g=build('grid-template-columns:[Start] 90px [Middle] 1fr [End];grid-template-rows:20px 40px;gap:10px','<div style="grid-column:Middle / End;grid-row:2">A</div>')
 pos(g.Children[1],100,30,200,40)
 g=build('grid-template:"Header Header" 30px "Side Main" 70px / 80px 1fr;gap:10px', '<div style="grid-area:Main">M</div><div style="grid-area:Header">H</div><div style="grid-area:Side">S</div>')
 pos(g.Children[1],90,40,210,70);pos(g.Children[2],0,0,300,30);pos(g.Children[3],0,40,80,70)
 g=build('grid-template-columns:repeat(3,1fr);grid-auto-rows:20px;gap:5px;grid-auto-flow:row dense','<div style="grid-column:span 2"></div><div style="grid-column:span 2"></div><div></div>')
 pos(g.Children[3],610/3,0)
 g=build('grid-template-rows:20px 30px;grid-auto-columns:50px;grid-auto-flow:column;gap:10px',cards)
 pos(g.Children[1],0,0,50);pos(g.Children[2],0,30,50);pos(g.Children[3],60,0,50)
 for _,mode in {'auto-fill','auto-fit'} do
  g=build('grid-template-columns:repeat('..mode..',minmax(80px,1fr));gap:10px','<div style="height:20px"></div><div style="height:20px"></div>')
  near(g.Children[1].OuterWidth,if mode=='auto-fit' then 145 else 280/3)
 end
 g=build('grid-template-columns:50px 60px;grid-auto-columns:30px;gap:10px','<div style="grid-column:-4 / -3;height:10px"></div><div style="grid-column:2 / -1;height:10px"></div>')
 pos(g.Children[1],0,0,30);pos(g.Children[2],100,0,60)
 g=build('grid-template-columns:repeat(2,50px);grid-template-rows:60px;height:100px;place-content:center;place-items:center;gap:10px','<div style="width:20px;height:10px"></div><div style="width:20px;height:10px"></div>')
 pos(g.Children[1],110,45,20,10);pos(g.Children[2],170,45,20,10)
 g=build('grid-template-columns:repeat(2,1fr);direction:rtl;gap:10px',cards)
 pos(g.Children[1],155,0,145);pos(g.Children[2],0,0,145)
 g=build('grid-template-columns:1fr 2fr;grid-template-rows:40px 50px;gap:10px','<div style="display:grid;grid-column:1 / -1;grid-template-columns:subgrid"><div>A</div><div>B</div></div>')
 pos(g.Children[1].Children[1],0,0,290/3);pos(g.Children[1].Children[2],290/3+10,0,580/3)
 local subcards=''
 for _,heights in {{20,10,8},{40,30,12},{25,20,10}}do
  subcards..='<div style="display:grid;grid-row:span 3;grid-template-rows:subgrid;gap:16px;padding:22px;border:1px solid black">'
  for _,h in heights do subcards..='<div style="height:'..h..'px"></div>'end
  subcards..='</div>'
 end
 g,tree=build('grid-template-columns:repeat(3,minmax(0,1fr));gap:18px',subcards,600)
 for _,w in {600,390,800,600,600}do
  Dirty.begin(tree);layout.arrange(tree,w,0,0,function()return true end);Dirty.finish(tree,true)
  near(g.OuterHeight,160);near(g.GridLayout.Rows.Tracks[1].Size,62)
  near(g.GridLayout.Rows.Tracks[2].Size,28);near(g.GridLayout.Rows.Tracks[3].Size,34)
  for _,card in g.Children do
   near(card.OuterHeight,160);near(card.Children[1].LayoutY,23)
   near(card.Children[2].LayoutY,79);near(card.Children[3].LayoutY,125)
   near(card.GridLayout.Rows.Used,114)
  end
 end
 local changed=g.Children[2].Children[2];local cardGui=g.Children[2].Gui
 for _,height in {50,30,50,30}do
  changed.Style.Height={Value=height,Percent=false}
  local stats=Dirty.begin(tree,{[changed]='style'});layout.arrange(tree,600,0,0,function()return true end);Dirty.finish(tree,true)
  near(g.OuterHeight,130+height);near(tree.Children[2].LayoutY,130+height)
  assert(stats.Mode=='partial'and g.Children[2].Gui==cardGui,'A changed subgrid row reflows without replacing its card')
 end
 for _,case in {{'',164,81,129},{'row-gap:normal;column-gap:0',164,81,129},{'row-gap:0',128,63,93},{'row-gap:30px',188,93,153}}do
  local content=subcards:gsub('gap:16px',case[1])
  g=build('grid-template-columns:repeat(3,minmax(0,1fr));gap:18px',content,600)
  near(g.OuterHeight,case[2])
  for _,card in g.Children do
   near(card.OuterHeight,case[2]);near(card.Children[1].LayoutY,23)
   near(card.Children[2].LayoutY,case[3]);near(card.Children[3].LayoutY,case[4])
  end
 end
 -- Subgrid declarations on an ordinary block have no layout effect.
 g=build('grid-template-columns:1fr;gap:18px','<div style="grid-template-rows:subgrid"><div style="height:20px"></div></div>')
 near(g.OuterHeight,20)
 -- Contributions propagate through nested row subgrids. Local gutters and
 -- padding must not become extra parent rows or get added again on resize.
 local nested='<div style="display:grid;grid-row:span 3;grid-template-rows:subgrid;gap:14px;padding:10px;border:1px solid black"><div style="display:grid;grid-row:span 3;grid-template-rows:subgrid;gap:6px;padding:4px;border:1px solid black"><div style="height:20px"></div><div style="height:10px"></div><div style="height:8px"></div></div></div>'
 local second='<div style="display:grid;grid-row:span 3;grid-template-rows:subgrid;gap:16px;padding:22px;border:1px solid black"><div style="height:40px"></div><div style="height:30px"></div><div style="height:12px"></div></div>'
 g,tree=build('grid-template-columns:repeat(2,minmax(0,1fr));gap:18px',nested..second,600)
 local nestedGui=g.Children[1].Children[1].Gui
 for _,w in {390,600,600}do
  Dirty.begin(tree);layout.arrange(tree,w,0,0,function()return true end);Dirty.finish(tree,true)
  near(g.OuterHeight,160);near(g.Children[1].OuterHeight,160)
  local inner=g.Children[1].Children[1];near(inner.OuterHeight,138)
  near(inner.Children[1].LayoutY,5);near(inner.Children[2].LayoutY,63);near(inner.Children[3].LayoutY,109)
  assert(inner.Gui==nestedGui,'Nested subgrid retains its GUI')
 end
 g=build('grid-template-columns:1fr;gap:10px','<div style="display:grid;grid-row:span 3;grid-template-rows:subgrid;padding:10px;row-gap:10px"><div style="grid-row:span 2;height:60px"></div><div style="height:20px"></div></div>')
 near(g.OuterHeight,110);near(g.Children[1].Children[1].LayoutY,10);near(g.Children[1].Children[2].LayoutY,80)
 g=build('grid-template-columns:1fr;gap:10px','<div style="display:grid;grid-row:span 3;grid-template-rows:subgrid;padding:20px;row-gap:10px"><div style="grid-row:2;height:50px"></div></div>')
 near(g.OuterHeight,110);near(g.Children[1].Children[1].LayoutY,30)
 g=build('grid-template-columns:1fr;gap:10px','<div style="display:grid;grid-row:span 3;grid-template-rows:subgrid;padding:20px;row-gap:10px"></div>')
 near(g.OuterHeight,60)
 g=build('grid-template-columns:100px 1fr;gap:10px','<div style="display:grid;grid-column:span 2;grid-template-columns:subgrid;padding:10px;column-gap:30px"><div style="height:20px"></div><div style="height:20px"></div></div>')
 pos(g.Children[1].Children[1],10,10,80);pos(g.Children[1].Children[2],120,10,170)
 g=build('grid-template-columns:min-content max-content;justify-content:start;gap:10px','<div>AAAA BB</div><div>AAAA BB</div>')
 near(g.Children[1].OuterWidth,20);near(g.Children[2].OuterWidth,35)
 g=build('grid-template-columns:fit-content(50px) 1fr;gap:10px','<div>AAAA BBBB CCCC</div><div>B</div>')
 near(g.Children[1].OuterWidth,50);near(g.Children[2].OuterWidth,240)
 g=build('grid-template-columns:1fr','<div style="min-width:0;overflow:hidden;white-space:nowrap;padding:10px">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA</div>',120)
 near(g.GridLayout.Columns.Used,120);near(g.Children[1].OuterWidth,120)
 g=build('grid-template-columns:1fr','<div style="overflow:hidden;white-space:nowrap;padding:10px">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA</div>',90)
 near(g.GridLayout.Columns.Used,90);near(g.Children[1].OuterWidth,90)
 g,tree=build('grid-template-columns:repeat(2,1fr);gap:10px','<div><progress value="1" style="display:block;width:100%"></progress></div><div><meter value=".5" style="display:block;width:100%"></meter></div>',400)
 pos(g.Children[1],0,0,195);pos(g.Children[2],205,0,195)
 layout.arrange(tree,500,0,0,function() return true end);pos(g.Children[1],0,0,245);pos(g.Children[2],255,0,245)
 g=build('grid-template-columns:100px 100px;grid-auto-rows:40px;gap:10px','<span style="order:2">A</span><div style="order:1">B</div>')
 pos(g.Children[2],0,0);pos(g.Children[1],110,0)
 g=build('position:relative;grid-template-columns:100px 1fr;grid-template-rows:50px;gap:10px','<div></div><div style="position:absolute;grid-column:2 / 3;top:0;left:0;right:0;bottom:0"></div>')
 near(g.Children[2].Gui.Position[1],110);near(g.Children[2].OuterWidth,190);near(g.Children[2].OuterHeight,50)
 assert(resolve('grid-column:2 / span 3').GridColumnEnd.Number==3)
 assert(resolve('grid:auto-flow dense 30px / 1fr 2fr').GridAutoFlow.Dense)
 assert(resolve('grid-template-columns:1fr!important;grid:20px / 40px').GridColumns.Items[1].Kind=='fr')
 assert(resolve('grid-column:2 / 4;grid-column:initial').GridColumnStart==nil)
 for _,bad in {'repeat(0,1fr)','repeat(auto-fill,1fr)','minmax(1fr,10px)','-5px','repeat(600,1px)','10px garbage'} do assert(not Values.tracks(bad),bad) end
 assert(not Values.areas('"a a" "a b"'),'Nonrectangular areas invalid')
 assert(not Values.line('0') and not Values.line('span -2'))
 print('CSS Grid: tracks, fractions, placement, names, areas, dense/column flow, repeat/auto-fit, implicit tracks, alignment, RTL, subgrid, intrinsic sizes, positioned items and GUI reuse passed')
end
