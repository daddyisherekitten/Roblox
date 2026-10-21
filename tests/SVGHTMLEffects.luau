--!strict
return function(Embedded,Parser,Queue,loadImages,Raster,Hit,Filter,Advanced,Effects,source)
 local jobs,images,cleanups,diagnostics={},{},{},{}
 local tasks={defer=function(fn)table.insert(jobs,coroutine.create(fn))end,wait=function()coroutine.yield()end}
 local function drain()
  local count=0;while #jobs>0 do
   count+=1;assert(count<10000);local co=table.remove(jobs,1);local ok,e=coroutine.resume(co);assert(ok,e)
   if coroutine.status(co)~='dead'then table.insert(jobs,co)end
  end
 end
 local function create(_,parent,props)
  local gui=table.clone(props);gui.Parent=parent;function gui:Destroy()assert(not self.Dead);self.Dead=true end;return gui
 end
 local api={CreateEditableImage=function(_,options)
  local image={Size=options.Size,Writes=0};function image:WritePixelsBuffer(_,_,bytes)self.Pixels=bytes;self.Writes+=1 end
  function image:Destroy()assert(not self.Dead);self.Dead=true end;table.insert(images,image);return image
 end}
 local page={Alive=true,Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(cleanups,fn)end}
 local node=Parser.parse('<svg width="100" height="60" viewBox="0 0 100 60"><rect width="100" height="60" fill="red"/></svg>').Children[1]
 local style={FontSize=16,Padding={0,0,0,0},BorderSize=0,BorderRadius=0,ObjectFit='fill',Filter=Filter.parse('none')}
 local item={SVG=node,ContentWidth=100,ContentHeight=60,BoxWidth=100,BoxHeight=60,Style=style,ImageGui={},BoxGui={},ImageFactory={create=create}}
 local queue=loadImages(Embedded,Queue,Raster,Hit).start(page,{SVGItems={item}},function(message)table.insert(diagnostics,message)end,{Asset=api,Task=tasks,PrewarmStates=0,WorkBudgetMS=.1})
 local clip=assert(Advanced.clipPath('polygon(15% 0,100% 0,85% 100%,0 100%)',function(value)return {Value=tonumber((value:gsub('%%',''))),Percent=value:find('%%')~=nil}end))
 local mask=assert(Advanced.mask('linear-gradient(to right,black 40%,transparent)'))
 local function alpha(image,x,y)return buffer.readu8(image.Pixels,(y*image.Size.X+x)*4+3)end
 item.UpdateSVG();drain();local original=item.ImageGui.ImageContent
 local originalSource={Pixels=original.Pixels,Size=original.Size}
 assert(alpha(original,0,0)==255)
 style.ClipPath=clip;item.UpdateSVG();drain()
 local gui=assert(item.SVGEffectGui);local image=gui.ImageContent
 assert(not item.ImageGui.Visible and gui.Visible and image.Size.X==100 and image.Size.Y==60)
 assert(alpha(image,1,1)==0 and alpha(image,50,30)==255 and alpha(image,98,58)==0,'Polygon clips actual image alpha, without painting a fake parent color')
 style.ClipPath=nil;style.MaskImage=mask;item.UpdateSVG();drain()
 assert(item.SVGEffectGui==gui and gui.ImageContent==image,'Clip and mask reuse the paint GUI and same-sized texture')
 assert(alpha(image,20,30)==255 and alpha(image,40,30)>248 and alpha(image,70,30)>100 and alpha(image,70,30)<145 and alpha(image,98,30)<12,'Mask preserves its 40% stop before fading rightwards')
 assert(alpha(originalSource,98,30)==255,'The original SVG pixel buffer remains immutable while its retained texture changes')
 style.MaskImage=nil;style.Filter=Filter.parse('blur(7px)');item.UpdateSVG();drain()
 local blurred=gui.ImageContent;local pad=item.SVGEffectPlan.Pad
 assert(pad>=14 and alpha(blurred,pad-2,pad+30)>0 and alpha(blurred,pad+50,pad+30)>240,'Blur spreads into transparent overflow and retains the interior')
 assert(gui.Position[1]==-pad and gui.Size[1]==100+2*pad and item.BoxWidth==100,'Blur outsets change painting only')
 style.ClipPath=clip;style.MaskImage=mask;item.UpdateSVG();drain()
 local combined=gui.ImageContent
 assert(alpha(combined,pad+1,pad+1)==0 and alpha(combined,pad+50,pad+30)>150 and alpha(combined,pad+98,pad+30)<12,'Filters run before clip and mask when all three are combined')
 local rasters=queue.Stats.Rasters;item.UpdateSVG();drain();assert(queue.Stats.Rasters==rasters,'Unchanged effects reuse the completed frame')
 -- Rapid requests must publish only the latest captured style, not a live table.
 style.Filter=Filter.parse('blur(2px)');item.UpdateSVG();style.Filter=Filter.parse('none');style.ClipPath=nil;style.MaskImage=nil;item.UpdateSVG();drain()
 assert(item.ImageGui.Visible and not gui.Visible and not item.SVGEffectReady,'Removing effects restores the original native paint')
 style.MaskImage=mask;item.UpdateSVG();drain();assert(queue.Stats.CacheHits>0)
 item.ContentWidth,item.BoxWidth=60,60;item.UpdateSVG();drain();assert(gui.Size[1]==60 and gui.ImageContent.Size.X==60,'Resize recomputes mask geometry and keeps its GUI')
 local capture=assert(Effects.capture(item,Vector2.new(100,60)))
 assert(Effects.render(originalSource.Pixels,Vector2.new(100,60),capture,function()return false end)==nil,'Cancelled effect work publishes no frame')
 -- Actual delivered SVG uses the same pipeline, including its object-fit crop.
 local actual=Parser.parse(source).Children[1]
 local other={SVG=actual,SVGExternal=true,ContentWidth=120,ContentHeight=72,BoxWidth=120,BoxHeight=72,SVGRasterWidth=144,SVGRasterHeight=72,Style=table.clone(style),ImageGui={},BoxGui={},ImageFactory={create=create}}
 other.Style.Padding={0,0,0,0};other.Style.ObjectFit='cover';other.Style.ClipPath=clip;other.Style.Filter=Filter.parse('blur(3px)')
 queue:AddItems({other});other.UpdateSVG();drain();assert(other.SVGEffectReady and other.SVGEffectGui.Visible)
 queue:RemoveItems({other});assert(not other.UpdateSVG and not other.SVGEffectGui)
 for _,cleanup in cleanups do cleanup()end;drain();for _,value in images do assert(value.Dead,'Every retained effect image must be destroyed')end
 assert(#diagnostics==0,diagnostics[1]);assert(queue.CacheBytes==0 and queue.Stats.Yields>0)
 print('HTML SVG effects: actual Atelier SVG, polygon alpha, gradient stops, blur overflow, combined order, coalescing, resize, cache, cancellation and disposal passed')
end
