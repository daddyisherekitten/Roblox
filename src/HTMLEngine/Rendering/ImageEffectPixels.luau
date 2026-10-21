--!strict
-- Fitted image pixels: filters, then clip coverage, then alpha masks. The
-- replaced element's layout and hit target stay independent of this surface.
local Blur=require(script.Parent.ImageBlurPixels)
local Clips=require(script.Parent.VisualEffectPixels)
local Masks=require(script.Parent.MaskPixels)
local Border=require(script.Parent.Parent.Layout.BorderGeometry)
local Effects={}
function Effects.needed(style: any): boolean
 return style.ClipPath~=nil or style.MaskImage~=nil or style.MaskBorderSource~=nil or style.Filter and style.Filter.HasRaster==true or false
end
local function key(value: any): string
 if type(value)~='table'then return tostring(value)end
 local names={};for name in value do table.insert(names,name)end
 table.sort(names,function(a,b)return tostring(a)<tostring(b)end)
 local parts={};for _,name in names do table.insert(parts,tostring(name)..'='..key(value[name]))end
 return '{'..table.concat(parts,';')..'}'
end
function Effects.capture(item: any,sourceSize: any): any?
 local probe=table.clone(item);local style=table.clone(item.Style)
 style.Padding=table.clone(style.Padding or {0,0,0,0})
 style.Filter=table.clone(style.Filter or {Steps={},Key='none'})
 style.Filter.Outset=style.Filter.Outset or 0
 probe.Style=style
 local plan=Blur.plan(probe,sourceSize);if not plan then return nil end
 local t,r,b,l=Border.sizes(style)
 plan.BoxWidth=item.BoxWidth or plan.CSSWidth+l+r+style.Padding[2]+style.Padding[4]
 plan.BoxHeight=item.BoxHeight or plan.CSSHeight+t+b+style.Padding[1]+style.Padding[3]
 plan.Left,plan.Top=l+style.Padding[4],t+style.Padding[1]
 plan.Key..='|'..plan.BoxWidth..'|'..plan.BoxHeight..'|'..plan.Left..'|'..plan.Top
 for _,field in {'ClipPath','MaskImage','MaskBorderSource','MaskMode','MaskComposite','MaskOrigins','MaskClips','MaskSizes','MaskPositions','MaskRepeats','MaskBorderMode','MaskBorderSlice','MaskBorderWidth','MaskBorderOutset','MaskBorderRepeat','Color','Padding'}do
  plan.Key..='|'..field..':'..key(style[field])
 end
 return {Style=style,Plan=plan}
end
function Effects.render(source: buffer,sourceSize: any,captured: any,check: any): buffer?
 local style,plan=captured.Style,captured.Plan
 local pixels=Blur.render(source,sourceSize,style.Filter,plan,check);if not pixels then return nil end
 local coverage={Width=plan.Width,Height=plan.Height,OffsetX=plan.Left-plan.Pad,OffsetY=plan.Top-plan.Pad,
  ExtentWidth=plan.CSSWidth+plan.Pad*2,ExtentHeight=plan.CSSHeight+plan.Pad*2}
 if style.ClipPath then
  local alpha=Clips.clipAlpha(style.ClipPath,plan.BoxWidth,plan.BoxHeight,coverage,check);if not alpha then return nil end
  pixels=Masks.apply(pixels,alpha,check);if not pixels then return nil end
 end
 for _,definition in {style.MaskImage or false,style.MaskBorderSource or false}do
  if definition then
   local alpha=Masks.render(style,definition,plan.BoxWidth,plan.BoxHeight,coverage,check);if not alpha then return nil end
   pixels=Masks.apply(pixels,alpha,check);if not pixels then return nil end
  end
 end
 return pixels
end
return Effects
