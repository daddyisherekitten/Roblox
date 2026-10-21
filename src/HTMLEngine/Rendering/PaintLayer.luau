--!strict
-- Decorative GUI layers can cover a whole box, including transparent pixels.
-- Keep the DOM element beneath them as the input target.
local PaintLayer={}
function PaintLayer.create(factory: any,class: string,parent: any,properties: any): any
 local gui=factory.create(class,parent,properties)
 if gui.SetAttribute then gui:SetAttribute("HTMLPaintOnlyOverlay",true) end
 return gui
end
return PaintLayer
