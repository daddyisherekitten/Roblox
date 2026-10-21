--!strict
return function(Parser,Style,Properties,Media,Canvas,loadRenderTree,loadWordLayout,loadBlockLayout,fixtureHTML,fixtureCSS)
 local fixtureElement=require('DOM/Node').element
 local function near(a,b)assert(math.abs(a-b)<.01,tostring(a)..' differs from '..tostring(b))end
 local function resolve(css,parent,node)
  if node then local raw=Parser.parse('<'..node.Name..'></'..node.Name..'>').Children[1];raw.Attributes=node.Attributes;node=raw
  else node=Parser.parse('<div></div>').Children[1];node.Attributes.style=css end
  return Style.resolve(node,parent or {},error)
 end
 local function create(class,parent,props)local g=table.clone(props);g.ClassName=class;g.Parent=parent;g.Destroy=function()end;return g end
 local renderer=loadRenderTree({create=create,modifier=create})
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*6,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local function build(css,content)
  local document=Parser.parse('<div style="'..css..'">'..(content or '')..'</div>')
  local tree=renderer.build(document,{},error)
  layout.arrange(tree,110,0,0,function()return true end);return tree.NodeBoxes[document.Children[1]],tree
 end
 local names={'color-scheme','-ms-grid-columns','-ms-grid-rows','align-tracks','column-rule-break','column-rule-edge-inset','column-rule-edge-inset-end','column-rule-edge-inset-start','column-rule-interior-inset','column-rule-interior-inset-end','column-rule-interior-inset-start','column-rule-outset','column-rule-visibility-items','grid-auto-position','inset-area','justify-tracks','margin-break','margin-trim','max-size','min-intrinsic-sizing','min-size'}
 for _,name in names do
  assert(Properties[name],name..' is missing');resolve(name..':initial');resolve(name..':unset')
 end
 local minmax=build('min-size:50px 30px;max-size:80px 40px;width:100px;height:100px')
 near(minmax.OuterWidth,80);near(minmax.OuterHeight,40)
 local smaller=build('max-size:80px 40px;min-size:90px 50px')
 near(smaller.OuterWidth,90);near(smaller.OuterHeight,50)
 local reset=resolve('min-size:20px;max-size:30px;min-size:initial;max-size:initial')
 assert(reset.MinWidth==nil and reset.MinHeight==nil and reset.MaxWidth==nil and reset.MaxHeight==nil)
 for _,css in {'max-size:auto','min-size:none','max-size:20px -1px','min-size:10px 20px 30px','align-tracks:baseline'}do
  local warnings={}
  local invalid=Style.resolve(fixtureElement('div',{style='min-size:12px;max-size:50px;'..css}),{},function(message)table.insert(warnings,message)end)
  assert(#warnings==1,'An invalid shorthand must produce one diagnostic')
  assert(invalid.MinWidth.Value==12 and invalid.MinHeight.Value==12 and invalid.MaxWidth.Value==50 and invalid.MaxHeight.Value==50,'Invalid declarations must preserve both prior size components')
 end
 local children='<div style="height:20px;margin:8px 0">A</div><div style="height:20px;margin:8px 0">B</div>'
 local normal=build('padding:1px',children);local trim,trimTree=build('padding:1px;margin-trim:block',children)
 near(normal.OuterHeight,66);near(trim.OuterHeight,50);near(trim.Children[1].LayoutY,1);near(trim.Children[2].LayoutY,29)
 for _,w in {200,90,200}do layout.arrange(trimTree,w,0,0,function()return true end);near(trim.OuterHeight,50)end
 local nested=build('margin-trim:block;padding:1px','<section><p style="height:20px;margin:8px 0">A</p></section>')
 near(nested.OuterHeight,22);near(nested.Children[1].LayoutMargin[1],0);near(nested.Children[1].Children[1].LayoutMargin[1],0)
 local onlyStart=build('padding:1px;margin-trim:block-start',children);near(onlyStart.OuterHeight,58)
 local compressed=build('overflow:auto;min-intrinsic-sizing:zero-if-scroll;padding:2px;border:1px solid red','UnbreakableLongWord')
 near(layout.naturalWidth(compressed,110,function()return true end,true),6)
 compressed.Style.MinWidth={Value=30,Percent=false};near(layout.naturalWidth(compressed,110,function()return true end,true),36)
 for _,display in {'-ms-grid','-ms-inline-grid'}do
  local legacy=build('display:'..display..';width:110px;-ms-grid-columns:40px 50px;-ms-grid-rows:20px','<div>A</div><div>B</div>')
  near(legacy.Children[2].LayoutX,40);near(legacy.Children[1].OuterHeight,20)
 end
 -- Vendor declarations cannot overwrite modern tracks, in either cascade order.
 local modernTracks='grid-template-columns:40px 50px;grid-template-rows:58px;'
 local oldTracks='-ms-grid-columns:10px 20px;-ms-grid-rows:24px 32px;'
 for _,display in {'grid','inline-grid'}do
  for _,tracks in {modernTracks..oldTracks,oldTracks..modernTracks}do
   local modern=build('display:'..display..';width:110px;'..tracks,'<div>A</div><div>B</div>')
   near(modern.Children[2].LayoutX,40);near(modern.Children[1].OuterHeight,58)
  end
 end
 local legacyParent=resolve('display:-ms-grid;'..modernTracks..oldTracks)
 local inheritedTracks=resolve('display:inherit;-ms-grid-columns:inherit;-ms-grid-rows:inherit',legacyParent)
 assert(inheritedTracks.LegacyGrid and inheritedTracks.Display=='grid')
 near(inheritedTracks.LegacyGridRows.Items[1].Value,24)
 local modernInherited=resolve('display:grid;grid-template-rows:inherit;grid-template-columns:inherit',legacyParent)
 near(modernInherited.GridRows.Items[1].Value,58)
 local legacyReset=resolve('display:-ms-grid;'..oldTracks..'-ms-grid-columns:initial;-ms-grid-rows:initial')
 assert(legacyReset.LegacyGridColumns==nil and legacyReset.LegacyGridRows==nil)
 local hover=renderer.build(Parser.parse('<style>#legacy{display:-ms-grid;width:110px;-ms-grid-columns:40px 50px;-ms-grid-rows:20px}#legacy:hover{-ms-grid-rows:30px}</style><div id="legacy"><div>A</div><div>B</div></div>'),{},error)
 local hoverBox=hover.Children[1]
 layout.arrange(hover,110,0,0,function()return true end);near(hoverBox.Children[1].OuterHeight,20)
 local changed,reflow=hover:SetCSSState('hover',hoverBox.Node);assert(changed and reflow)
 layout.arrange(hover,110,0,0,function()return true end);near(hoverBox.Children[1].OuterHeight,30)
 hover:SetCSSState('hover',nil)
 layout.arrange(hover,110,0,0,function()return true end);near(hoverBox.Children[1].OuterHeight,20)
 local placement=build('display:grid;grid-template-columns:20px 30px 40px;grid-template-rows:10px 20px;grid-auto-flow:none;grid-auto-position:3 / 2','<div>A</div><div>B</div>')
 near(placement.Children[1].LayoutX,50);near(placement.Children[1].LayoutY,10);near(placement.Children[2].LayoutX,50)
 local explicit=build('display:grid;grid-template-columns:20px 30px 40px;grid-auto-flow:none;grid-auto-position:3 / 1','<div style="grid-column:2">A</div>')
 near(explicit.Children[1].LayoutX,20)
 -- A historical default must never change modern row/column auto-placement.
 -- The shared catalog uses modern flow because Chromium ignores this property.
 for _,flow in {'row','column','row dense','column dense'}do
  local auto=build('display:grid;grid-template-columns:40px 40px;grid-template-rows:20px 20px;grid-auto-flow:'..flow..';grid-auto-position:2 / 1','<div>Alpha</div><div>Beta</div>')
  near(auto.Children[1].LayoutX,0);near(auto.Children[1].LayoutY,0)
  near(auto.Children[2].LayoutX,if flow:find('column',1,true)then 0 else 40)
  near(auto.Children[2].LayoutY,if flow:find('column',1,true)then 20 else 0)
 end
 assert(resolve('inset-area:top').PositionArea=='top')
 local blocks='';for _=1,4 do blocks..='<div style="height:40px">A</div>'end
 local base='columns:2;column-height:40px;row-gap:10px;column-gap:10px;column-rule:2px solid blue;'
 local continuous=build(base..'column-rule-break:none',blocks)
 assert(#continuous.ColumnRules==1);near(continuous.ColumnRules[1].Size[2],90)
 local separated=build(base..'column-rule-break:intersection',blocks)
 assert(#separated.ColumnRules==2);near(separated.ColumnRules[1].Size[2],40)
 local edge=build(base..'column-rule-edge-inset:2px 4px;column-rule-interior-inset:6px 8px',blocks)
 near(edge.ColumnRules[1].Position[2],2);near(edge.ColumnRules[1].Size[2],30);near(edge.ColumnRules[2].Position[2],56);near(edge.ColumnRules[2].Size[2],30)
 local outset=build(base..'column-rule-outset:2px',blocks)
 near(outset.ColumnRules[1].Position[2],-2);near(outset.ColumnRules[1].Size[2],44)
 for _,mode in {'auto','keep','discard'}do
  local margin=build('columns:2;height:40px;column-fill:auto','<div style="height:30px;margin-top:8px;margin-break:'..mode..'">A</div><div style="height:30px;margin-top:8px;margin-break:'..mode..'">B</div>')
  near(margin.Children[1].LayoutY,if mode=='discard'then 0 else 8)
  near(margin.Children[2].LayoutY,if mode=='keep'then 8 else 0)
 end
 local forcedMargin=build('columns:2;height:40px;column-fill:auto','<div style="height:20px">A</div><div style="height:20px;margin-top:8px;break-before:column">B</div>')
 near(forcedMargin.Children[2].LayoutY,8)
 for _,mode in {'normal','all','around','between'}do
  local single=build('columns:3;column-height:40px;column-rule:2px solid blue;column-rule-visibility-items:'..mode,'<div style="height:40px">A</div>')
  assert(#single.ColumnRules==(if mode=='all'then 2 elseif mode=='around'then 1 else 0),mode)
 end
 local masonry=build('display:grid;grid-template-columns:50px 50px;grid-template-rows:masonry;height:100px;align-tracks:center,end','<div style="height:20px">A</div><div style="height:40px">B</div><div style="height:20px">C</div>')
 near(masonry.Children[1].LayoutX,0);near(masonry.Children[2].LayoutX,50);near(masonry.Children[1].LayoutY,30);near(masonry.Children[2].LayoutY,60);near(masonry.Children[3].LayoutY,50)
 local horizontal=build('display:grid;grid-template-columns:masonry;grid-template-rows:20px 20px;width:110px;justify-tracks:end','<div style="width:20px;height:20px">A</div><div style="width:30px;height:20px">B</div>')
 near(horizontal.Children[1].LayoutX,90);near(horizontal.Children[2].LayoutX,80);near(horizontal.Children[2].LayoutY,20)
 local distributed=build('display:grid;grid-template-columns:50px;grid-template-rows:masonry;height:100px;align-tracks:space-between','<div style="height:20px">A</div><div style="height:20px">B</div>')
 near(distributed.Children[2].LayoutY,80)
 local noMotion=Media.compile('(prefers-reduced-motion:reduce)');assert(noMotion)
 assert(not Media.matches(noMotion,{}));assert(Media.matches(noMotion,{ReducedMotion=true}))
 assert(Media.matches(Media.compile('(prefers-reduced-motion:no-preference)'),{}))
 assert(Media.matches(Media.compile('(prefers-color-scheme:dark)'),{PreferredColorScheme='dark'}))
 local motion=renderer.build(Parser.parse('<style>@media(prefers-reduced-motion:reduce){#a{width:20px}}</style><div id="a" style="height:10px">A</div>'),{},error)
 assert(motion:SetMediaEnvironment(110,100,{ReducedMotion=true}));assert(motion.Children[1].Style.Width.Value==20)
 local dark=resolve('color-scheme:dark',nil,{Name='input',Attributes={style='color-scheme:dark'}})
 assert(dark.DarkScheme and dark.Background==Color3.fromRGB(59,59,59)and dark.Color==Color3.fromRGB(238,238,238))
 local custom=resolve('',nil,{Name='input',Attributes={style='color-scheme:dark;background:red;color:blue;border:2px solid green'}})
 assert(custom.Background==Color3.new(1,0,0)and custom.Color==Color3.new(0,0,1))
 local inherited=resolve('color-scheme:dark',{Color=Color3.new(0,0,1)})
 assert(inherited.Color==Color3.new(0,0,1),'External inherited colors without internal metadata must remain authored colors')
 assert(resolve('color-scheme:light',inherited).Color==Color3.new(0,0,1))
 assert(resolve('color-scheme:dark;color:initial',inherited).Color==Color3.fromRGB(238,238,238),'An explicit initial color uses the selected scheme')
 local scheme=renderer.build(Parser.parseDocument('<html style="color-scheme:light dark"><body><input></body></html>'),{},error)
 assert(scheme:SetMediaEnvironment(110,100,{PreferredColorScheme='dark'}))
 local canvas=Canvas.resolve(scheme.Node,scheme.NodeStyles);assert(canvas==Color3.fromRGB(18,18,18))
 local diagnostics={}
 local fixture=renderer.build(Parser.parse(fixtureHTML),{AbsoluteSize={X=1280,Y=800}},function(message)table.insert(diagnostics,message)end,nil,nil,nil,nil,nil,nil,nil,nil,nil,{['styles.css']=fixtureCSS})
 assert(#diagnostics==0,diagnostics[1])
 local catalogGrid,alignProbe,justifyProbe,msRowsProbe,msColumnsProbe
 for node,box in fixture.NodeBoxes do
  local card=node.Parent and node.Parent.Parent
  local name=card and card.Attributes and card.Attributes['data-property']
  if name=='grid-auto-position'then catalogGrid=box elseif name=='align-tracks'then alignProbe=box elseif name=='justify-tracks'then justifyProbe=box end
  if name=='-ms-grid-rows'then msRowsProbe=box elseif name=='-ms-grid-columns'then msColumnsProbe=box end
 end
 assert(catalogGrid,'The real grid-auto-position probe must exist')
 assert(alignProbe and justifyProbe,'Both shared track-alignment probes must exist')
 assert(msRowsProbe and msColumnsProbe,'Both vendor track probes must exist')
 local original
 for _,w in {1280,800,390,1280}do
  local h=layout.arrange(fixture,w,0,0,function()return true end)
  assert(h>0 and h<1000000,'Layout fixture must remain finite')
  local first,second=catalogGrid.GridLayout.Items[1].Box,catalogGrid.GridLayout.Items[2].Box
  near(first.LayoutX,9);near(second.LayoutX,70);near(first.LayoutY,9);near(second.LayoutY,9)
  near(first.OuterWidth,61);near(second.OuterWidth,61);near(first.OuterHeight,58);near(second.OuterHeight,58)
  assert(not alignProbe.MasonryLayout and not justifyProbe.MasonryLayout,'Browser reference probes must use normal Grid, not legacy masonry')
  local a,b=alignProbe.GridLayout.Items[1].Box,alignProbe.GridLayout.Items[2].Box
  near(a.LayoutX,9);near(b.LayoutX,72);near(a.LayoutY,9);near(b.LayoutY,9)
  near(a.OuterWidth,59);near(b.OuterWidth,59);near(a.OuterHeight,20);near(b.OuterHeight,30)
  a,b=justifyProbe.GridLayout.Items[1].Box,justifyProbe.GridLayout.Items[2].Box
  near(a.LayoutX,9);near(b.LayoutX,9);near(a.LayoutY,9);near(b.LayoutY,33)
  near(a.OuterWidth,30);near(b.OuterWidth,40)
  for _,probe in {msRowsProbe,msColumnsProbe}do
   a,b=probe.GridLayout.Items[1].Box,probe.GridLayout.Items[2].Box
   near(a.LayoutX,9);near(b.LayoutX,70);near(a.LayoutY,9);near(b.LayoutY,9)
   near(a.OuterWidth,61);near(b.OuterWidth,61);near(a.OuterHeight,58);near(b.OuterHeight,58)
  end
  if not original then original=h elseif w==1280 then near(h,original)end
 end
 print('Remaining layout: all 21 logged properties, resets, size clamps, margin trim/nesting/resize, compressed sizing, legacy Grid placement, rule geometry/visibility, two-axis masonry and motion/theme cascade passed')
end
