--!strict
-- Normal presentation ends at supporting HTML replaced media. DOM, scripts,
-- resource state and stylesheet metadata remain owned by their usual services.
local Names=require(script.Parent.Parent.DOM.ElementNames)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local MediaContent={}
function MediaContent.media(node: any): boolean
 return Names.html(node,'audio')or Names.html(node,'video')
end
function MediaContent.contents(node: any): boolean
 -- Assigned slots participate in presentation ancestry. A ShadowRoot itself
 -- crosses through its host; FlatParent already crosses for its children.
 local current=if node then(if node.Kind=='ShadowRoot'then node.Host else ShadowTree.FlatParent(node))else nil
 while current do
  if MediaContent.media(current)then return true end
  current=if current.Kind=='ShadowRoot'then current.Host else ShadowTree.FlatParent(current)
 end
 -- Unassigned light children remain hidden DOM data. They must not acquire
 -- a renderer capability restriction or an ordinary native focus surface.
 current=if node then node.Parent or(if node.Kind=='ShadowRoot'then node.Host else nil)else nil
 while current do
  if MediaContent.media(current)then return true end
  current=current.Parent or(if current.Kind=='ShadowRoot'then current.Host else nil)
 end
 return false
end
function MediaContent.data(node: any): boolean
 return MediaContent.media(node)or MediaContent.contents(node)
end
return MediaContent
