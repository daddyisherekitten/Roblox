--!strict
local Builder=require(script.Parent.SceneBuilder)
local Parser=require(script.Parent.Parser)
local Viewport=require(script.Parent.Viewport)
local Raster=require(script.Parent.Raster)
local Length=require(script.Parent.Length)
local Geometry=require(script.Parent.Geometry)
local Paint=require(script.Parent.Paint)
local Transform=require(script.Parent.Transform)
local Bounds=require(script.Parent.TransformBounds)
local Rendering=require(script.Parent.Rendering)
local Document=require(script.Parent.Document)
local Gradient=require(script.Parent.Gradient)
local Resources=require(script.Parent.Resources)
local Text=require(script.Parent.Text)
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Embedded={}
local WorkContext=require(script.Parent.Parent.WorkContext)
local AttributeStore=require(script.Parent.Parent.DOM.AttributeStore)
function Embedded.document(node: any,external: boolean?,declarations: any?): any
 local doc={Kind='Document',Children={},Ids={},Diagnostics={},Valid=true,ResolveImage=node.PackagedImageResolver}
 local function clone(n,parent)
  WorkContext.checkpoint()
  local c={Kind=n.Kind,Name=n.Name,Text=n.Text,NamespaceURI=n.NamespaceURI,Parent=parent,Children={},Attributes=table.clone(n.Attributes or {}),ExpandedAttributes=table.clone(n.ExpandedAttributes or {})}
  if n.AttributeNamespaces then
   c.Attributes={}
   for key,value in n.Attributes do
    local info=n.AttributeNamespaces[key];local namespace=AttributeStore.namespace(n,key)
    if namespace then c.ExpandedAttributes[namespace..'\0'..info.LocalName]=value end
    local name=AttributeStore.name(n,key)
    if not namespace or name:find(':',1,true)then c.Attributes[name]=value end
   end
  end
  if declarations and n.Kind=='Element'then c.SourceElement=n;c.ExternalDeclarations=function(states)return declarations(n,states)end end
  if c.Attributes['xlink:href'] then c.ExpandedAttributes['http://www.w3.org/1999/xlink\0href']=c.Attributes['xlink:href'] end
  for _,child in n.Children or {} do table.insert(c.Children,clone(child,c)) end
  if c.Attributes.id and not doc.Ids[c.Attributes.id] then doc.Ids[c.Attributes.id]=c end
  return c
 end
 doc.Root=clone(node,doc);doc.Children={doc.Root}
 if external then return doc end
 -- These root declarations belong to the surrounding HTML box, not SVG paint.
 local boxOnly={opacity=true,['vertical-align']=true,position=true,top=true,right=true,bottom=true,left=true,['z-index']=true,['box-sizing']=true,['min-width']=true,['max-width']=true,['min-height']=true,['max-height']=true}
 local declarations={}
 for _,d in Syntax.declarations(doc.Root.Attributes.style or '') do
  local name=d.Text:match('^%s*([%w-]+)%s*:');name=name and name:lower()
  if not boxOnly[name] and not (name and (name:match('^margin') or name:match('^padding') or name:match('^border') or name:match('^background'))) then
   table.insert(declarations,d.Text..(if d.Important then ' !important' else ''))
  end
 end
 doc.Root.Attributes.style=table.concat(declarations,';')
 return doc
end
function Embedded.build(doc: any,width: number,height: number,states: any?): any
 -- The HTML content box defines the root viewport; intrinsic attributes served layout already.
 local root=doc.Root;local w,h=root.Attributes.width,root.Attributes.height
 root.Attributes.width=tostring(width);root.Attributes.height=tostring(height)
 local ok,data=pcall(Builder,Parser,Viewport,{Width=width,Height=height,States=states,EmbeddedSize=true,ResolveImage=doc.ResolveImage,Cases={{Name=root.Attributes.id or 'embedded-svg',Document=doc,Runtime=true}}},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
 root.Attributes.width=w;root.Attributes.height=h
 if not ok then error(data) end
 return data.Scenes[1],data.Diagnostics
end
return Embedded
