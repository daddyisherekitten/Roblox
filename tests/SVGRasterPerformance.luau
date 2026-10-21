--!strict
return function(Raster,Compositing,Blur,Embedded,HTMLParser)
 local function same(a,b,message)
  assert(buffer.len(a)==buffer.len(b),message..' size')
  for at=0,buffer.len(a)-1 do assert(buffer.readu8(a,at)==buffer.readu8(b,at),message..' byte '..at) end
 end
 local html=[=[<svg width="96" height="96"><defs>
 <filter id="shadow" color-interpolation-filters="sRGB"><feDropShadow stdDeviation="1.4" dx="1" dy="2"/></filter>
 <filter id="noise"><feTurbulence type="fractalNoise" baseFrequency=".1" numOctaves="2"/><feComposite in2="SourceGraphic" operator="in"/></filter>
 <clipPath id="clip"><circle cx="68" cy="68" r="20"/></clipPath>
 <mask id="mask"><rect width="96" height="96" fill="white" fill-opacity=".7"/></mask>
 </defs><style>#hot:hover{fill:yellow;stroke:purple;stroke-width:3}</style>
 <rect id="bg" width="96" height="96" fill="#123456"/>
 <g filter="url(#shadow)"><rect id="hot" x="4" y="4" width="25" height="25" fill="red"/></g>
 <circle cx="65" cy="20" r="16" fill="blue" filter="url(#noise)"/>
 <g opacity=".61"><rect x="3" y="40" width="27" height="32" fill="lime"/><circle cx="25" cy="62" r="20" fill="red"/></g>
 <g clip-path="url(#clip)"><rect x="45" y="40" width="45" height="50" fill="white"/><circle cx="63" cy="58" r="22" fill="blue" style="mix-blend-mode:multiply"/></g>
 <rect x="50" y="80" width="25" height="12" fill="yellow" mask="url(#mask)"/>
 </svg>]=]
 local doc=Embedded.document(HTMLParser.parse(html).Children[1]);local work=Raster.createWork()
 local function render(states,width)
  local scene,diagnostics=Embedded.build(doc,96,96,states);assert(#diagnostics==0)
  local expected=Raster.render(scene,nil,width)
  local actual=Raster.render(scene,nil,width,nil,work)
  same(actual,expected,'Retained layers preserve exact full render')
  return actual
 end
 render({},96);local builds=work.LayerBuilds;assert(builds>0 and work.RetainedBytes>0)
 render({hover=doc.Ids.hot},96)
 assert(work.LayerHits>=3,'First hover must reuse unrelated filters, opacity and masks')
 assert(work.LayerBuilds<=builds+1,'Only the changed filtered layer is rasterized on first hover')
 assert(work.PartialRenders==1 and work.RepaintPixels<96*96/3,'First hover repaints only the proven filter output rectangle')
 local hits=work.LayerHits;render({},96);assert(work.LayerHits>hits,'Rebuilt scenes share retained paint by value')
 doc.Ids.hot.Attributes.width='31';render({hover=doc.Ids.hot},96)
 doc.Ids.shadow.Children[1].Attributes.stdDeviation='2.3';render({},96)
 -- Changing transform/opacity and moving a filtered layer over a clipped blend
 -- must repaint both its old and new bounds, with the real current backdrop.
 doc.Ids.hot.Parent.Attributes.transform='translate(38 40)';render({},96)
 doc.Ids.hot.Parent.Attributes.opacity='.31';render({},96)
 doc.Ids.hot.Parent.Attributes.transform='translate(-8 -11) rotate(17)';render({},96)
 doc.Ids.hot.Parent.Attributes.opacity='0';render({},96)
 doc.Ids.hot.Parent.Attributes.opacity='1';render({},96)
 render({},73)
 -- Crop-only groups depend on the backdrop. Reusing their completed result
 -- would make a changed background or multiply blend visibly incorrect.
 doc.Ids.bg.Attributes.fill='#ffccee';render({},96)
 local partial=work.PartialRenders;doc.Ids.bg.Attributes.fill='#aabbcc';render({},96)
 assert(work.PartialRenders==partial,'Unbounded ordinary paint edits fall back to the full renderer')
 -- A cancelled frame must never become the source of a later partial repaint.
 doc.Ids.hot.Attributes.fill='black'
 assert(Raster.render(Embedded.build(doc,96,96,{}),nil,96,function()return false end,work)==nil)
 doc.Ids.hot.Attributes.fill='white';render({},96)
 Raster.releaseWork(work);assert(work.RetainedBytes==0 and work.RetainedFields==0 and #work.Retained==0)
 assert(Compositing.remember(work,'layer',{},buffer.create(4),1,1)==nil,'Disposed workers cannot re-register retained pixels')
 local owners={};local pixels=buffer.create(1024*1024*4)
 for i=1,4 do
  local owner=Raster.createWork();owners[i]=owner
  for j=1,3 do Compositing.remember(owner,'frame',{Value=j},pixels,1024,1) end
  assert(owner.RetainedBytes<=8*1024*1024,'Retained bytes stay within the owner budget')
 end
 local total=0;for _,owner in owners do total+=owner.RetainedBytes end
 assert(total<=24*1024*1024,'Retained bytes stay within the shared budget across owners')
 for _,owner in owners do Raster.releaseWork(owner) end
 local metadata=Raster.createWork();local tiny=buffer.create(4)
 local descriptor={Points=table.create(150000,1)}
 Compositing.remember(metadata,'frame',descriptor,tiny,1,1)
 Compositing.remember(metadata,'frame',descriptor,tiny,1,1)
 assert(metadata.RetainedFields<=262144 and #metadata.Retained==1,'Geometry metadata has a separate aggregate owner bound')
 assert(Compositing.remember(metadata,'frame',{Points=table.create(262145,1)},tiny,1,1)==nil,'Oversized geometry skips retention without rejecting rendering')
 Raster.releaseWork(metadata)
 -- Retained alpha bounds must exactly match the reference full-pixel scan.
 local cropOwner=Raster.createWork()
 local function cropCase(width,height,kind)
  local source=buffer.create(width*height*4);local left,top,right,bottom=width,height,-1,-1
  for y=0,height-1 do for x=0,width-1 do
   local visible=kind=='dense' or (kind=='sparse' and (x*17+y*31)%23==0) or (kind=='edge' and x==width-1 and y==height-1)
   if visible then
    local at=(y*width+x)*4;buffer.writeu32(source,at,0x01030201)
    left=math.min(left,x);right=math.max(right,x);top=math.min(top,y);bottom=math.max(bottom,y)
   end
  end end
  local rows=0
  local entry=Compositing.remember(cropOwner,'layer',{Case=kind,Width=width},source,width,1,function()rows+=1;return true end)
  assert(entry and rows==height,'Retained scans checkpoint every row')
  local box=entry.Region
  assert(box.X==left and box.Y==top and box.Width==math.max(0,right-left+1) and box.Height==math.max(0,bottom-top+1),'Exact sparse/dense/empty alpha bounds')
  local restored=buffer.create(buffer.len(source))
  for y=0,box.Height-1 do buffer.copy(restored,((box.Y+y)*width+box.X)*4,entry.Bytes,y*box.Width*4,box.Width*4) end
  same(restored,source,'Cropped retained pixels preserve exact RGBA')
 end
 for _,width in {1,2,13,64} do for _,kind in {'dense','sparse','edge','empty'} do cropCase(width,19,kind) end end
 local previousBytes,previousFields,previousCount=cropOwner.RetainedBytes,cropOwner.RetainedFields,#cropOwner.Retained
 local cancelRow=0
 local cancelled,completed=Compositing.remember(cropOwner,'layer',{},buffer.create(32*32*4),32,1,function()cancelRow+=1;return cancelRow~=3 end)
 assert(cancelled==nil and completed==false and cancelRow==3,'A single cancellation immediately terminates the alpha scan')
 assert(cropOwner.RetainedBytes==previousBytes and cropOwner.RetainedFields==previousFields and #cropOwner.Retained==previousCount,'Cancelled admission does not evict or publish cache entries')
 local released=Compositing.remember(cropOwner,'layer',{},buffer.create(16),2,1,function()Raster.releaseWork(cropOwner);return true end)
 assert(released==nil and #cropOwner.Retained==0 and cropOwner.RetainedBytes==0 and cropOwner.RetainedFields==0,'Release during a checkpoint cannot resurrect retained work')
 -- Exercise the production compositing caller too: cancellation must not be
 -- confused with an ordinary non-retained cache miss and subsequently resume.
 local stoppedOwner=Raster.createWork();local inScan=false;local stopOnce=false
 local didDraw=Compositing.draw(buffer.create(16),{{Opacity=.5}},function(bytes)
  buffer.writeu32(bytes,0,0xffffffff);inScan=true;return true
 end,2,function()
  if inScan and not stopOnce then stopOnce=true;return false end
  return true
 end,stoppedOwner)
 assert(not didDraw and stopOnce and #stoppedOwner.Retained==0 and stoppedOwner.CompositeLive==0,'Compositing propagates scan cancellation without retrying')
 Raster.releaseWork(stoppedOwner)
 -- Check the optimized orthogonal/alpha-only convolution against the original
 -- bilinear definition, including negative axes and zero-extension edges.
 local function allocate(_)return {Width=9,Height=7,Bytes=buffer.create(9*7*16),Space='sRGB'} end
 for _,alphaOnly in {false,true} do
  local input=allocate();input.AlphaOnly=alphaOnly
  for at=0,buffer.len(input.Bytes)-4,4 do buffer.writef32(input.Bytes,at,if alphaOnly and at%16~=12 then 0 else (at%31)/31) end
  for _,t in {{SX=1,SY=1},{SX=-1,SY=1},{SX=0,SY=0,KX=-1,KY=1}} do
   local actual=Blur.apply(input,1.3,.8,t,1,allocate,function()end)
   local current=input
   for _,axis in {{t.SX,t.KY or 0,1.3},{t.KX or 0,t.SY,.8}} do
    local weights,radius=Blur.kernel(axis[3]);local expected=allocate()
    for y=0,6 do for x=0,8 do
     local r,g,b,a=0,0,0,0
     for i=-radius,radius do local rr,gg,bb,aa=Blur.sample(current,x+i*axis[1],y+i*axis[2]);local w=weights[i+radius+1];r+=rr*w;g+=gg*w;b+=bb*w;a+=aa*w end
     local at=(y*9+x)*16;buffer.writef32(expected.Bytes,at,r);buffer.writef32(expected.Bytes,at+4,g);buffer.writef32(expected.Bytes,at+8,b);buffer.writef32(expected.Bytes,at+12,a)
    end end
    current=expected
   end
   same(actual.Bytes,current.Bytes,'Gaussian convolution remains bit exact')
  end
 end
 print('SVG retained raster: first-hover reuse, geometry/filter invalidation, backdrop correctness, resize, disposal and exact Gaussian pixels passed')
end
