--!strict
-- Explicit URL-to-asset mapping. Temporary EditableImages are always released.
local ImageAssets={}
function ImageAssets.resolver(mapping: any,service: any,content: any,vector: any): any
 return function(url: string): any
  local asset=mapping[url];if not asset then return nil end
  local image
  local ok,result=pcall(function()
   image=service:CreateEditableImageAsync(content.fromUri(asset))
   assert(image,'EditableImage allocation unavailable')
   local size=image.Size
   assert(size.X>=1 and size.Y>=1 and size.X<=1024 and size.Y<=1024,'SVG asset size budget exceeded')
   return {Width=size.X,Height=size.Y,Pixels=image:ReadPixelsBuffer(vector.new(0,0),size)}
  end)
  if image then image:Destroy() end
  if not ok then error(result) end
  return result
 end
end
return ImageAssets
