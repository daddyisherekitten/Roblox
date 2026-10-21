--!strict
-- Mandatory auto-size normalization is separate from Chromium's optional
-- candidate reuse and its previously frozen eager/whitespace discrepancies.
return function(Parser,Node,Sources,loadRenderTree,loadWordLayout,loadBlockLayout)
 local checks=0
 local function check(value,label)checks+=1;assert(value,label)end
 local doc=Parser.parseDocument('<!doctype html><picture><source id="s" srcset="small.png 200w, medium.png 400w, large.png 800w"><img id="i" loading="lazy" sizes="auto" width="200" height="100"></picture>')
 local image,source=Node.findById(doc,'i'),Node.findById(doc,'s')
 check(Sources.allowsAuto(image),'Lazy image with exact auto prefix allows auto sizing')
 check(Sources.forImage(image,800,1)=='large.png','No concrete/remembered width uses the source-size fallback')
 check(Sources.publishAutoSize(image,200)and not Sources.publishAutoSize(image,200),'Publishing identical committed width is a no-op')
 local selected,density=Sources.forImage(image,800,1)
 check(selected=='small.png'and density==1,'Omitted picture source sizes becomes auto for an eligible image')
 selected,density=Sources.forImage(image,800,2)
 check(selected=='medium.png'and density==2,'DPR uses committed source size, not viewport width')
 source.Attributes.sizes='auto, 10px';Sources.publishAutoSize(image,400)
 selected,density=Sources.forImage(image,800,1)
 check(selected=='medium.png'and density==1,'Explicit source auto wins over fallback')
 source.Attributes.sizes='(max-width:500px) 100px, auto';Sources.publishAutoSize(image,200)
 check(Sources.forImage(image,400,1)=='small.png','Earlier matching media source size stays authoritative')
 source.Attributes.sizes='(min-width:500px) auto, 800px'
 check(Sources.forImage(image,800,1)=='small.png'and Sources.forImage(image,400,1)=='large.png','Conditional source auto honors both remembered width and its media condition')
 source.Attributes.sizes='auto';image.Attributes.sizes='AUTO, 50vw';image.Attributes.loading='LAZY'
 check(Sources.allowsAuto(image)and Sources.forImage(image,800,1)=='small.png','HTML ASCII-insensitive auto/loading keywords')
 for _,invalid in {' auto','auto ','auto , 50px','automatic','auto(1px)','\\61uto'}do
  image.Attributes.sizes=invalid
  check(not Sources.allowsAuto(image),'Strict allows-auto prefix: '..invalid)
 end
 image.Attributes.sizes='auto, 50px';image.Attributes.loading='eager';source.Attributes.sizes='auto, 100px'
 check(not Sources.allowsAuto(image)and Sources.forImage(image,800,1)=='small.png','Eager image ignores auto and evaluates its following size')
 image.Attributes.loading='lazy';image.Attributes.sizes='auto'
 check(Sources.autoSize(image)==200,'Hidden/unrendered periods retain last auto width')
 for _,invalid in {-1,0/0,math.huge}do check(not Sources.publishAutoSize(image,invalid)and Sources.autoSize(image)==200,'Invalid measurements cannot replace a valid remembered size')end
 Sources.publishAutoSize(image,0);selected,density=Sources.forImage(image,800,1)
 check(selected=='small.png'and density==math.huge,'Zero concrete slot keeps infinite normalized density')
 local w,h=Sources.intrinsicSize(200,100,density);check(w==0 and h==0,'Zero slot has zero density-corrected natural dimensions')
 local clone=Node.element('img',{loading='lazy',sizes='auto',srcset='small.png 200w, large.png 800w'});clone.OwnerDocument=doc
 check(Sources.autoSize(clone)==nil and Sources.forImage(clone,800,1)=='large.png','New image does not inherit another node last auto width')
 local overrides={['Layout/FontProfiles']={face=function(f)return f end},['Layout/TextMeasure']={measure=function(t,_,size)return{X=#t*size/2,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local function create(class,parent,properties)
  local gui=table.clone(properties);gui.ClassName,gui.Parent=class,parent
  function gui:Destroy()self.Parent=nil end
  return gui
 end
 local renderer,layout=loadRenderTree({create=create,modifier=create}),loadBlockLayout(overrides)
 for _,css in {'','width:200px','height:100px','width:50%;height:100px','contain-intrinsic-size:400px 200px'}do
  local document=Parser.parse('<img id="auto" loading="lazy" sizes="auto" src="mapped.png" style="'..css..'">')
  local tree=renderer.build(document,{},error,nil,nil,nil,function()return'rbxassetid://1'end)
  layout.arrange(tree,800,0,0,function()return true end)
  local n=Node.findById(document,'auto');local item=tree:FindImageItem(n);local width=item.ContentWidth
  check(tree.NodeStyles[n].AutoImageSize and tree.NodeStyles[n].Contain.Size,'UA auto rule establishes size containment')
  local expected=if css=='width:200px'then 200 elseif css:find('50%%')or css:find('400px',1,true)then 400 else 300
  check(width==expected,'Auto layout initial concrete width: '..css)
  item.IntrinsicWidth,item.IntrinsicHeight=50,25
  layout.arrange(tree,800,0,0,function()return true end)
  check(item.ContentWidth==width,'Density-corrected metadata cannot feed back into auto width: '..css)
  tree.VisualEffects:Destroy()
 end
 for _,row in {
  {'contain:paint',300,150},{'contain:strict',300,150},{'contain:none!important',300,150},
  {'object-view-box:inset(0 25%)',300,150},{'contain-intrinsic-size:0px 0px',0,0},
  {'contain-intrinsic-width:initial',0,150},{'contain-intrinsic-width:unset',0,150},
  {'contain-intrinsic-size:revert',300,150},{'contain-intrinsic-size:unset',0,0},{'contain:paint',300,150,true},
 }do
  local document=Parser.parse('<img id="auto" loading="lazy" sizes="auto" src="mapped.png" style="'..(if row[4]then''else'display:block;')..row[1]..'">')
  local tree=renderer.build(document,{},error,nil,nil,nil,function()return'rbxassetid://1'end)
  layout.arrange(tree,800,0,0,function()return true end)
  local item=tree:FindImageItem(Node.findById(document,'auto'));local contain=item.Style.Contain
  check(contain.Size and not contain.Paint and not contain.Layout and not contain.Style,'UA important contain is exactly size: '..row[1])
  check(item.ContentWidth==row[2]and item.ContentHeight==row[3],'Auto containment dimensions respect cascade without object-view-box feedback: '..row[1])
  if item.Style.ObjectViewBox then check(item.Style.ObjectViewBox~=nil and item.ImageGui~=nil,'Object view box remains retained for image paint')end
  tree.VisualEffects:Destroy()
 end
 print('Auto image sources: '..checks..' mandatory grammar, remembered geometry, picture defaults, density and actual containment-layout controls passed')
end
