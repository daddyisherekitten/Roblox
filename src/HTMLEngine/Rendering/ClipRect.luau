--!strict
-- Legacy clip applies to the whole positioned surface, including its own paint.
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Clip={}
function Clip.bounds(style,width,height)
 local value=style.ClipRect
 if not value or (style.Position~='absolute'and style.Position~='fixed')then return 0,0,width,height,false end
 local top=if value[1]then Length.resolve(value[1],height)else 0
 local right=if value[2]then Length.resolve(value[2],width)else width
 local bottom=if value[3]then Length.resolve(value[3],height)else height
 local left=if value[4]then Length.resolve(value[4],width)else 0
 return left,top,math.max(0,right-left),math.max(0,bottom-top),true
end
function Clip.apply(box,x,y)
 local surface=if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui
 local viewport=box.ClipRectViewport
 local l,t,w,h,active=Clip.bounds(box.Style,box.OuterWidth or 0,box.OuterHeight or 0)
 if not active and not viewport then return end
 if not viewport then
  viewport=box.Factory.create('CanvasGroup',surface.Parent,{Name='LegacyClipViewport',BackgroundTransparency=1,GroupTransparency=0,ClipsDescendants=true})
  box.ClipRectViewport=viewport
 elseif surface.Parent~=viewport then viewport.Parent=surface.Parent end
 surface.Parent=viewport
 local bounds=box.OpacityGroup and box.OpacityBounds
 local bx,by=if bounds then math.floor(bounds[1])else 0,if bounds then math.floor(bounds[2])else 0
 if bounds and not active then w,h=bounds[3]-bx,bounds[4]-by;l,t=bx,by end
 viewport.Position=UDim2.fromOffset(x+l-bx,y+t-by);viewport.Size=UDim2.fromOffset(w,h);viewport.ClipsDescendants=active
 viewport.ZIndex=surface.ZIndex or 1;viewport.Visible=surface.Visible~=false
 surface.Position=UDim2.fromOffset(bx-l,by-t)
end
return Clip
