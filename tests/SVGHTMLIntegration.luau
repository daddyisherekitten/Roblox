--!strict
return function(Parser,loadRenderTree,loadWordLayout,loadBlockLayout,source)
 local allocated=0;local objects={};local diagnostics={}
 local renderer=loadRenderTree({create=function(class,parent,props)
  assert(class~='ImageButton' and class~='TextButton' and class~='TextBox')
  local o=table.clone(props);o.Parent=parent;o.Class=class;allocated+=1;table.insert(objects,o);return o
 end})
 local measure={measure=function(text,_,size)return {X=#text*size*.5,Y=size}end}
 local words=loadWordLayout({['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']=measure})
 local blocks=loadBlockLayout({['Layout/WordLayout']=words,['Layout/TextMeasure']=measure})
 local tree=renderer.build(Parser.parse(source),{},function(m)table.insert(diagnostics,m)end)
 assert(#tree.SVGItems==11 and #tree.ImageItems==0,'All eleven SVG viewports are local raster targets')
 local count=allocated
 for _,width in {480,240,960,480} do
  blocks.arrange(tree,width,0,0,function()return true end)
  for _,item in tree.SVGItems do assert(item.ImageGui and item.ContentWidth>0 and item.ContentHeight>0 and item.ImageGui.Parent==item.BoxGui) end
  assert(allocated==count,'Viewport resize retains HTML and SVG GUI objects')
 end
 local groups,clips,scrolls=0,0,0
 for _,o in objects do
  if o.Class=='CanvasGroup' then groups+=1;assert(o.GroupTransparency==.5) end
  if o.ClipsDescendants then clips+=1 end
  if o.Class=='ScrollingFrame' then scrolls+=1 end
 end
 assert(groups>0 and clips>0 and scrolls>0,'SVG shares real HTML opacity, clip and scroll containers')
 assert(#diagnostics==0,diagnostics[1]);print('SVG S43/S44 HTML fixture: eleven raster targets, 3 widths, nested opacity/clipping/scrolling and no GUI churn passed')
end
