--!strict
-- A request failure changes the image's contents, not its author-specified box.
local ImageFallback = {IconSize = 16}
function ImageFallback.broken(item: any): boolean
	if item.Control and item.Control.Type~="image" or item.MediaKind or item.IFrame or item.Canvas or item.SVG and not item.SVGExternal then return false end
	local request=item.Node and item.Node.ImageResourceState
	if request and request.Status=="error"then return true end
	if request and request.Status=="loaded"then return false end
	return not item.FilterReady and ((item.Source==nil and not item.SVG)
		or item.LoadFailed==true and not (item.ImageGui and item.ImageGui.IsLoaded))
end
function ImageFallback.refresh(item: any): boolean
	local fallback=ImageFallback.broken(item)and(item.Alt or "")~=""
	local changed=fallback~=(item.TextFallback==true);item.TextFallback=fallback
	return changed
end
return ImageFallback
