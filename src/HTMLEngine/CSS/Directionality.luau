--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- HTML directionality is a DOM semantic, independent of CSS direction.
-- The optional value reader supplies live input/textarea values to the host.
local Class=require(script.Parent.Parent.Layout.BidiClass)
local Shadow=require(script.Parent.Parent.DOM.ShadowTree)
local Work=require(script.Parent.Parent.WorkContext)
local Defaults=require(script.Parent.Parent.Controls.Defaults)
local Directionality={}
local function html(node: any): boolean return not node.NamespaceURI or node.NamespaceURI=='http://www.w3.org/1999/xhtml'end
local controls=setmetatable({},{__mode='kv'})
function Directionality.bind(node: any,control: any?) controls[node]=control end
function Directionality.unbind(node: any,control: any)
 if controls[node]==control then controls[node]=nil end
end
local values={hidden=true,text=true,search=true,tel=true,url=true,email=true,password=true,submit=true,reset=true,button=true}
local blocks={address=true,blockquote=true,center=true,div=true,figure=true,figcaption=true,footer=true,form=true,header=true,hr=true,legend=true,listing=true,main=true,p=true,plaintext=true,pre=true,summary=true,xmp=true,article=true,aside=true,h1=true,h2=true,h3=true,h4=true,h5=true,h6=true,hgroup=true,nav=true,search=true,section=true,table=true,caption=true,colgroup=true,col=true,thead=true,tbody=true,tfoot=true,tr=true,td=true,th=true,dir=true,dd=true,dl=true,dt=true,menu=true,ol=true,ul=true,li=true,output=true}
function Directionality.state(node: any): string?
 if node.NamespaceURI and node.NamespaceURI~='http://www.w3.org/1999/xhtml'then return nil end
 local raw=node.Attributes and node.Attributes.dir
 if not raw then return nil end
 local state=raw:lower();return if state=='ltr'or state=='rtl'or state=='auto'then state else nil
end
function Directionality.text(text: string): string?
 for _,code in utf8.codes(text)do Work.checkpoint();local kind=Class.get(code)
  if kind=='L'then return 'ltr'elseif kind=='R'or kind=='AL'then return 'rtl'end
 end
 return nil
end
local function excluded(node: any): boolean
 return node.Kind=='Element'and html(node)and(ElementNames.htmlName(node)=='bdi'or ElementNames.htmlName(node)=='script'or ElementNames.htmlName(node)=='style'or ElementNames.htmlName(node)=='textarea'or Directionality.state(node)~=nil)
end
-- A text mutation can change the nearest auto owner even without :dir rules.
-- Known dir states and excluded descendants isolate it from outer auto owners.
function Directionality.textOwner(node: any): any?
 local current=if node.Kind=='Text'then node.Parent else node
 while current do
  if current.Kind=='ShadowRoot'then return nil end
  local state=Directionality.state(current)
  if state=='auto'or html(current)and ElementNames.htmlName(current)=='bdi'and state==nil then return current end
  if excluded(current)then return nil end
  current=current.Parent
 end
 return nil
end
function Directionality.textOwners(node: any): any
 local owners={};local current=if node.Kind=='Text'then node.Parent else node
 local own=Directionality.textOwner(node);if own then owners[own]=true end
 while current do
  Work.checkpoint()
  if current.Kind=='ShadowRoot'or excluded(current)then break end
  local slot=current.AssignedSlot
  if slot and Directionality.state(slot)=='auto'then owners[slot]=true end
  current=current.Parent
 end
 return owners
end
local function contained(root: any,excludeRoot: boolean,read: any?): string?
 local pending={root}
 while #pending>0 do
  Work.checkpoint();local node=table.remove(pending)
  if (node~=root or excludeRoot)and excluded(node)then continue end
  if node.Kind=='Text'then local found=Directionality.text(node.Text or '');if found then return found end
  elseif node~=root and ElementNames.htmlName(node)=='slot'and Shadow.Root(node).Kind=='ShadowRoot'then return Directionality.of(Shadow.Root(node).Host,read)
  else for i=#(node.Children or {}),1,-1 do table.insert(pending,node.Children[i])end end
 end
 return nil
end
function Directionality.auto(node: any,read: any?): string?
 local kind=Defaults.kind(node)
 if ElementNames.htmlName(node)=='textarea'or ElementNames.htmlName(node)=='input'and values[kind]then
  local value=read and read(node)
  if value==nil and controls[node]then value=controls[node].Value end
  if value==nil then
   if ElementNames.htmlName(node)=='input'then value=node.Attributes.value or ''
   else local text={};local pending={node};while #pending>0 do local current=table.remove(pending);if current.Kind=='Text'then table.insert(text,current.Text or '')else for i=#(current.Children or {}),1,-1 do table.insert(pending,current.Children[i])end end end;value=table.concat(text)end
  end
  return Directionality.text(value)or(if value~=''then 'ltr'else nil)
 end
 if ElementNames.htmlName(node)=='slot'and Shadow.Root(node).Kind=='ShadowRoot'and #(node.AssignedNodes or {})>0 then
  for _,child in node.AssignedNodes do local found=if child.Kind=='Text'then Directionality.text(child.Text or '')else contained(child,true,read);if found then return found end end
  return nil
 end
 return contained(node,false,read)
end
function Directionality.of(node: any,read: any?): string
 local current=node
 while current do
  Work.checkpoint();local state=Directionality.state(current)
  if state=='ltr'or state=='rtl'then return state end
  if state=='auto'or html(current)and ElementNames.htmlName(current)=='bdi'and state==nil then return Directionality.auto(current,read)or 'ltr'end
  if ElementNames.htmlName(current)=='input'and(current.Attributes.type or ''):lower()=='tel'then return 'ltr'end
  local parent=current.Parent
  current=if parent and parent.Kind=='ShadowRoot'then parent.Host elseif parent and parent.Kind=='Element'then parent else nil
 end
 return 'ltr'
end
-- UA requirements use isolation for dir, with bdo overriding within isolation.
function Directionality.ua(node: any): string
 if node.NamespaceURI and node.NamespaceURI~='http://www.w3.org/1999/xhtml'then return 'normal'end
 local state=Directionality.state(node)
 local kind=Defaults.kind(node)
 if state=='auto'and(ElementNames.htmlName(node)=='pre'or ElementNames.htmlName(node)=='textarea'or ElementNames.htmlName(node)=='input'and(kind=='text'or kind=='search'or kind=='tel'or kind=='url'or kind=='email'))then return 'plaintext'end
 if ElementNames.htmlName(node)=='bdo'then return 'isolate-override'end
 if ElementNames.htmlName(node)=='bdi'or state~=nil or blocks[ElementNames.htmlName(node)]then return 'isolate'end
 return 'normal'
end
return Directionality
