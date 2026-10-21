--!strict
return function(Embedded,Parser,Queue,loadImages,Raster,Hit,Filter,Colors,sample,chain)
 local jobs,images,cleanups,diagnostics={},{},{},{}
 local taskAPI={defer=function(fn)table.insert(jobs,coroutine.create(fn))end,wait=function()coroutine.yield()end}
 local function drain()
  local count=0
  while #jobs>0 do
   count+=1;assert(count<10000)
   local co=table.remove(jobs,1);local ok,e=coroutine.resume(co);assert(ok,e)
   if coroutine.status(co)~='dead' then table.insert(jobs,co) end
  end
 end
 local api={CreateEditableImage=function(_,options)
  local image={Size=options.Size}
  function image:WritePixelsBuffer(_,_,bytes)self.Pixels=bytes end
  function image:Destroy()assert(not self.Dead);self.Dead=true end
  table.insert(images,image);return image
 end}
 local page={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(cleanups,fn)end}
 local node=Parser.parse(sample).Children[1]
 local filter=assert(Filter.parse(chain));assert(#filter.Steps==6 and not filter.HasRaster)
 local plain={SVG=node,ContentWidth=120,ContentHeight=90,Style={FontSize=16,Filter=Filter.parse('none')},ImageGui={}}
 local filtered={SVG=node,ContentWidth=120,ContentHeight=90,Style={FontSize=16,Filter=filter},ImageGui={}}
 local tree={SVGItems={plain,filtered}}
 local runtime=loadImages(Embedded,Queue,Raster,Hit)
 local queue=runtime.start(page,tree,function(message)table.insert(diagnostics,message)end,{Asset=api,Task=taskAPI,PrewarmStates=0})
 plain.UpdateSVG();filtered.UpdateSVG();drain();assert(#diagnostics==0,diagnostics[1])
 local original=plain.ImageGui.ImageContent.Pixels
 local expected=Colors.render(original,filter)
 local actual=filtered.ImageGui.ImageContent.Pixels
 assert(buffer.tostring(actual)==buffer.tostring(expected),'The local SVG image must pass through the entire HTML CSS color-filter chain before upload')
 assert(buffer.tostring(actual)~=buffer.tostring(original),'The filter-chain preview must differ from the original SVG')
 local image=filtered.ImageGui.ImageContent;local before=queue.Stats.Rasters
 filtered.UpdateSVG();drain();assert(queue.Stats.Rasters==before and filtered.ImageGui.ImageContent==image,'Unchanged SVG filters reuse their rendered image')
 filtered.Style.Filter=Filter.parse('invert()');filtered.UpdateSVG();drain()
 assert(buffer.tostring(image.Pixels)==buffer.tostring(Colors.render(original,filtered.Style.Filter)),'Changing the outer HTML filter updates the retained SVG texture')
 filtered.Style.Filter=filter;filtered.UpdateSVG();drain()
 assert(buffer.tostring(image.Pixels)==buffer.tostring(expected) and queue.Stats.CacheHits>0,'Returning to a filter state reuses that state without applying the filter twice')
 local vector=Parser.parse('<svg width="12" height="12" viewBox="0 0 12 12"><rect width="12" height="12"/></svg>').Children[1]
 local host={Kind='Element',Name='div',Attributes={},Children={vector}};vector.Parent=host
 local fill,declarations='#ff0000',0
 local inline={Node=vector,SVG=vector,ContentWidth=12,ContentHeight=12,Style={FontSize=16},ImageGui={},SVGDeclarations=function(source)
  declarations+=1;return {Normal=if source.Name=='rect'then{{Name='fill',Value=fill}}else{},Important={}}
 end}
 queue:AddItems({inline});inline.UpdateSVG();drain()
 local retained=inline.ImageGui.ImageContent
 local function channel(index)return buffer.readu8(retained.Pixels,(6*12+6)*4+index)end
 assert(channel(0)==255 and channel(1)==0,'External CSS paints the mounted inline SVG')
 local count,rasters=declarations,queue.Stats.Rasters
 tree.AnimationStyleRevision=1;tree.SVGStyleChanged({[{}]=true});drain()
 assert(declarations==count and queue.Stats.Rasters==rasters,'Unrelated style changes perform no SVG declaration scan or raster')
 fill='#0000ff';tree.AnimationStyleRevision=2;tree.SVGStyleChanged({[host]=true});drain()
 assert(declarations>count and channel(2)==255 and channel(0)==0 and inline.ImageGui.ImageContent==retained,'A changed SVG ancestor still updates the retained image')
 fill='#00ff00';tree.AnimationStyleRevision=3;tree.SVGStyleChanged({[vector.Children[1]]=true});drain()
 assert(channel(1)==255 and channel(2)==0,'A changed inner SVG node still updates its external CSS')
 fill='#ff0000';tree.AnimationStyleRevision=4;tree.SVGStyleChanged();drain()
 assert(channel(0)==255 and channel(1)==0,'Global stylesheet/media invalidation still updates every SVG')
 for _,cleanup in cleanups do cleanup() end;drain()
 for _,value in images do assert(value.Dead,'SVG filter output uses the existing queue lifetime') end
 assert(not filtered.UpdateSVG and queue.CacheBytes==0)
 print('HTML SVG filters: actual sample, six ordered color transforms, immutable original, dynamic filter cache, retained texture and disposal passed')
end
