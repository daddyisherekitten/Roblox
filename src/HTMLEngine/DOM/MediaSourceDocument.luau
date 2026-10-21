--!strict
-- Media resource provenance is data, not a retained realm/page/DOM wrapper.
local Names=require(script.Parent.ElementNames)
local Source={}
local function media(node)return Names.html(node,'audio')or Names.html(node,'video')or Names.html(node,'source')end
local function semantic(node)
 if not media(node)or not node.Attributes or node.Attributes.src==nil then return false end
 local info=node.AttributeNamespaces and node.AttributeNamespaces.src
 local namespace=info and(info.Namespace or info.NamespaceURI)
 return namespace==nil or namespace==''
end
function Source.context(document)
 if not document then return nil end
 local context=document.MediaSourceContext
 if not context then
  local address=document.URL or document.FallbackBaseURL or 'about:blank'
  context={Document=setmetatable({document},{__mode='v'}),URL=address,Base=address}
  document.MediaSourceContext=context
 end
 return context
end
function Source.observe(document,base,address)
 local context=Source.context(document)
 if type(base)=='string'then context.Base=base end
 if type(address)=='string'then context.URL=address end
end
function Source.seed(node,document,reset)
 if semantic(node)and(reset or node.MediaSourceDocument==nil)then node.MediaSourceDocument=Source.context(document or node.OwnerDocument)end
end
function Source.write(node,name,value,namespace,document)
 if name~='src'or namespace~=nil and namespace~=''or not media(node)then return end
 node.MediaSourceDocument=if value~=nil then Source.context(document or node.OwnerDocument)else nil
end
return Source
