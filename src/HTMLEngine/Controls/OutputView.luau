--!strict
-- Output has form state, but its authored box is an ordinary CSS surface.
local BorderBox=require(script.Parent.Parent.Rendering.BorderBox)
local CornerRadii=require(script.Parent.Parent.Rendering.CornerRadii)
local OutputView={}
local function write(gui: any,key: string,value: any)if gui[key]~=value then gui[key]=value end end
function OutputView.paint(item: any)
 local box=item.OutputBox
 if not box or not item.BoxWidth or not item.BoxHeight then return end
 local s,width,height=item.Style,item.BoxWidth,item.BoxHeight
 local native=CornerRadii.native(s)
 s.NativeCornerRadii=native
 local resolved=CornerRadii.resolve(s,width,height)
 if native and resolved then CornerRadii.apply(box.Corner,resolved)
 else
  local radius=s.BorderRadius or 0
  if resolved then
   radius=math.huge
   for _,corner in resolved do radius=math.min(radius,corner[1],corner[2])end
  end
  if s.CornerShape~='round'then radius=0 end
  write(box.Corner,'CornerRadius',UDim.new(0,math.max(0,math.min(radius,width/2,height/2))))
 end
 local rounded=false
 if box.RadiusRenderer then rounded=box.RadiusRenderer:DrawRadius(box,s,width,height)end
 if rounded==nil then return end
 s.ResolvedBorderRadii=if rounded then box.ResolvedBorderRadii else nil
 write(box.Gui,'BackgroundColor3',s.Background or Color3.new(1,1,1))
 write(box.Gui,'BackgroundTransparency',if rounded or s.Visibility=='hidden' or not s.Background then 1 else 1-(s.BackgroundAlpha or 1))
 box.InsetEdges=BorderBox.update(box.InsetEdges,s,box.Gui,width,height,box.Factory,box.RadiusRenderer)
end
function OutputView.create(item: any,corners: any?)
 item.OutputBox={Gui=item.BoxGui,Corner=item.Corner,Factory=item.Factory,RadiusRenderer=corners}
end
function OutputView.release(item: any)
 local box=item.OutputBox
 if box and box.RadiusRenderer then box.RadiusRenderer:Remove(box)end
end
return OutputView
