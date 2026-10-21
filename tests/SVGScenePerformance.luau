--!strict
-- Guard first-render work as well as the warmed hover-cache path.
return function(Embedded,Parser,Document,Text,Path,Bounds,Queries)
 local function parse(body)
  local doc=Parser.parse('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="80">'..body..'</svg>')
  assert(doc.Valid);return doc
 end
 local originalBounds,originalText=Bounds.reference,Text.expand
 local boundsCalls,textCalls=0,0
 Bounds.reference=function(...)boundsCalls+=1;return originalBounds(...)end
 Text.expand=function(...)textCalls+=1;return originalText(...)end
 local ok,problem=pcall(function()
  local doc=parse('<g id="group" transform="translate(5 7)"><rect id="box" x="10" y="20" width="30" height="15" fill="red"/></g>')
  local scene,issues=Embedded.build(doc,100,80)
  assert(#issues==0 and boundsCalls==0,'A plain runtime scene must not flatten every node just to populate unused DOM bounds')
  doc.Ids.box.Attributes.width='60'
  local box=Queries.box(scene,doc.Ids.group)
  assert(box.X==10 and box.Y==20 and box.Width==30 and box.Height==15,'Deferred local bounds belong to the rendered snapshot, even after source mutation')
  local firstCount=boundsCalls
  box.Width=999
  assert(Queries.box(scene,doc.Ids.group).Width==30 and boundsCalls==firstCount,'Repeated getBBox reuses its computation and returns an independent result')
  local changed=Embedded.build(doc,100,80)
  assert(Queries.box(changed,doc.Ids.group).Width==60,'A new scene invalidates old bounds')
  local matrix=Queries.matrix(scene,doc.Ids.box)
  assert(matrix.TX==5 and matrix.TY==7,'Laziness does not alter runtime coordinate systems')

  doc=parse('<defs><linearGradient id="g"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs><text id="label" x="4" y="38" font-size="24" fill="url(#g)" rotate="-5 5">ABBA</text>')
  textCalls=0
  scene,issues=Embedded.build(doc,100,80)
  assert(#issues==0 and textCalls==1,'Gradient reference bounds must share the already expanded text')
  assert(#scene.Shapes==4)
  local function equal(a,b)
   if type(a)~=type(b) then return false end
   if type(a)~='table' then return a==b end
   for key,value in a do if not equal(value,b[key]) then return false end end
   for key in b do if a[key]==nil then return false end end
   return true
  end
  local expanded=scene.Nodes[doc.Ids.label].Node
  for i,glyph in expanded.Children do
   local parts,errors=Path.parse(glyph.Attributes.d)
   assert(#errors==0 and equal(scene.Shapes[i].Geometry.Subpaths,parts),'Retained text outlines must exactly match serialized path coordinates and curves')
  end
  local before=textCalls
  local textBox=Queries.box(scene,doc.Ids.label)
  assert(textBox.Width>0 and textBox.Height>0 and textCalls==before,'Text getBBox reuses outline geometry')

  local usedText=parse('<defs><text id="template" y="30">AB</text></defs><use id="instance" href="#template"/>')
  local usedScene=Embedded.build(usedText,100,80)
  assert(#usedScene.Shapes==2 and usedScene.Shapes[1].SourceNode==usedText.Ids.instance and usedScene.Shapes[2].SourceNode==usedText.Ids.instance,'Text outlines retain the visible use instance as their hover/event target')

  local prepared=Document.prepare(doc)
  local resource,scope=prepared.Resource('#g',prepared.Root)
  local context={Width=100,Height=80,FontSize=16,RootFontSize=16}
  local a=prepared.Compute(resource,scope,context)
  local b=prepared.Compute(resource,scope,table.clone(context))
  assert(a==b,'Identical resource contexts share computed ancestry styles')
  resource.Attributes['stroke-width']='10%'
  local fresh=Document.prepare(doc)
  local target,newScope=fresh.Resource('#g',fresh.Root)
  assert(fresh.Compute(target,newScope,context).Values['stroke-width']=='10%','Resource style caches stay local to one prepared document')
  local stop=target.Children[1]
  local parentA=table.clone(a);parentA.Values=table.clone(a.Values);parentA.Values.fill='red'
  local parentB=table.clone(a);parentB.Values=table.clone(a.Values);parentB.Values.fill='blue'
  assert(fresh.Compute(stop,newScope,context,parentA).Values.fill=='red' and fresh.Compute(stop,newScope,context,parentB).Values.fill=='blue','Explicit resource inheritance cannot alias across parents')

  local custom=table.clone(Text.Font);custom.Glyphs=table.clone(Text.Font.Glyphs)
  local id=custom.Cmap[65];custom.Glyphs[id]=table.clone(custom.Glyphs[id])
  custom.Glyphs[id].Path='M0 0L100 0L100 100Z'
  local textDoc=Document.prepare(parse('<text>A</text>'));local node=textDoc.Root.Children[1]
  local old=Text.expand(node,context,nil,function()return custom end)
  custom.Glyphs[id].Path='M0 0L200 0L200 100Z'
  local nextTree=Text.expand(node,context,nil,function()return custom end)
  assert(old.Children[1].Attributes.d~=nextTree.Children[1].Attributes.d,'Glyph outline cache detects changes to a supplied font')
 end)
 Bounds.reference,Text.expand=originalBounds,originalText
 assert(ok,problem)
 print('SVG scene work: lazy snapshot bounds, resource ancestry reuse, shared text outlines and mutable custom fonts passed')
end
