--!strict
local VM=require(script.Parent.ScriptVM)
local ScriptDOM={}
local NS='http://www.w3.org/2000/svg'
local function text(n) local s=if n.Kind=='Text' then n.Text else '';for _,c in n.Children do s..=text(c) end;return s end
function ScriptDOM.new(session: any,options: any?): any
 options=options or {};local runtime={Diagnostics={},Listeners={},Alive=true,Created=0};local wrappers={};local wrap,vm
 local function report(err) if #runtime.Diagnostics<100 then table.insert(runtime.Diagnostics,{Code='svg-script-error',Value=tostring(err)}) end end
 local function reindex()
  table.clear(session.Document.Ids)
  local function visit(n) if n.Attributes and n.Attributes.id and not session.Document.Ids[n.Attributes.id] then session.Document.Ids[n.Attributes.id]=n end;for _,c in n.Children do visit(c) end end
  visit(session.Document.Root);session:InvalidateStyles();session.Stats.Mutations+=1
 end
 local function unwrap(v) assert(type(v)=='table' and v.DOMNode and wrappers[v.DOMNode]==v,'Element from this document required');return v.DOMNode end
 local function attribute(n,key,value)
  local top=n;while top.Parent do top=top.Parent end
  if top==session.Document then session:SetAttribute(n,key,value) else n.Attributes[key]=value end
 end
 local function element(name)
  assert(type(name)=='string' and name:match('^[%a_][%w_-]*$'),'Invalid SVG element name')
  runtime.Created+=1;assert(runtime.Created<=1024,'Script DOM node budget exceeded')
  return {Kind='Element',Name=name,NamespaceURI=NS,Attributes={},ExpandedAttributes={},Children={}}
 end
 local function detach(n)
  if n.Parent then local i=table.find(n.Parent.Children,n);if i then table.remove(n.Parent.Children,i) end;n.Parent=nil end
 end
 local function query(root,selector)
  assert(type(selector)=='string','Selector must be a string')
  local id=selector:match('^#([%w_-]+)$');assert(id or selector:match('^[%a][%w_-]*$'),'Only id/tag selectors are supported by ScriptDOM')
  local function search(n) for _,c in n.Children do if c.Kind=='Element' then if (id and c.Attributes.id==id) or (not id and c.Name==selector) then return c end;local found=search(c);if found then return found end end end end
  return search(root)
 end
 local function event(e)
  return {Get=function(key)
   if key=='target' then return wrap(e.Target) elseif key=='currentTarget' then return wrap(e.CurrentTarget) elseif key=='type' then return e.Type elseif key=='eventPhase' then return e.Phase elseif key=='defaultPrevented' then return e.DefaultPrevented
   elseif key=='preventDefault' then return function() e:PreventDefault() end
   elseif key=='stopPropagation' then return function() e:StopPropagation() end
   elseif key=='stopImmediatePropagation' then return function() e:StopImmediatePropagation() end end
   local alias={key='Key',pointerId='PointerId',buttons='Buttons',shiftKey='ShiftKey',pointerType='PointerType'}
   return if alias[key] and e.Data[alias[key]]~=nil then e.Data[alias[key]] else VM.Undefined
  end}
 end
 wrap=function(n)
  if not n then return VM.Null end;if wrappers[n] then return wrappers[n] end
  local object={DOMNode=n};wrappers[n]=object
  object.Get=function(key)
   if key=='id' then return n.Attributes and n.Attributes.id or '' elseif key=='tagName' or key=='localName' then return n.Name or VM.Undefined
   elseif key=='namespaceURI' then return n.NamespaceURI or VM.Null elseif key=='textContent' then return text(n)
   elseif key=='ownerDocument' then return wrap(session.Document) elseif key=='parentNode' then return wrap(n.Parent)
   elseif key=='firstChild' then return wrap(n.Children[1]) elseif key=='children' then local items={};for _,c in n.Children do if c.Kind=='Element' then table.insert(items,wrap(c)) end end;return {Kind='array',Items=items}
   elseif key=='documentElement' and n==session.Document then return wrap(session.Document.Root)
   elseif key=='getElementById' and n==session.Document then return function(a) return wrap(session:Node(VM.string(a[1]))) end
   elseif key=='createElementNS' and n==session.Document then return function(a) assert(a[1]==NS,'Only SVG namespace is supported');return wrap(element(a[2])) end
   elseif key=='querySelector' then return function(a) return wrap(query(n,a[1])) end
   elseif key=='getAttribute' then return function(a) return n.Attributes[VM.string(a[1])] or VM.Null end
   elseif key=='setAttribute' then return function(a) local k=VM.string(a[1]);local v=VM.string(a[2]);assert(#k<256 and #v<=65536,'Attribute budget exceeded');attribute(n,k,v) end
   elseif key=='removeAttribute' then return function(a) attribute(n,VM.string(a[1]),nil) end
   elseif key=='appendChild' then return function(a)
    local child=unwrap(a[1]);assert(child~=session.Document.Root and child~=session.Document,'Cannot reparent document root')
    local current=n;local depth=0;while current do assert(current~=child,'Cannot insert a DOM ancestor');depth+=1;assert(depth<96,'Script DOM depth exceeded');current=current.Parent end
    detach(child);child.Parent=n;table.insert(n.Children,child);reindex();return wrap(child)
   end
   elseif key=='removeChild' then return function(a) local child=unwrap(a[1]);assert(child.Parent==n,'Not a child');detach(child);reindex();return wrap(child) end
   elseif key=='remove' then return function() assert(n~=session.Document.Root,'Cannot remove SVG root');detach(n);reindex() end
   elseif key=='focus' then return function() session:Focus(n) end
   elseif key=='addEventListener' then return function(a)
    assert(#runtime.Listeners<256,'Script listener budget exceeded');local kind=VM.string(a[1]);local fn=a[2];local capture=a[3]==true
    for _,entry in runtime.Listeners do if entry.Node==n and entry.Kind==kind and entry.Fn==fn and entry.Capture==capture then return end end
    local connection=session:On(n,kind,function(e) if runtime.Alive then local ok,err=pcall(function() vm:Call(fn,{event(e)}) end);if not ok then report(err) end end end,capture)
    table.insert(runtime.Listeners,{Node=n,Kind=kind,Fn=fn,Capture=capture,Connection=connection})
   end
   elseif key=='removeEventListener' then return function(a) for i=#runtime.Listeners,1,-1 do local v=runtime.Listeners[i];if v.Node==n and v.Kind==a[1] and v.Fn==a[2] and v.Capture==(a[3]==true) then v.Connection:Disconnect();table.remove(runtime.Listeners,i) end end end
   end
   return VM.Undefined
  end
  object.Set=function(key,value)
   if key=='id' then attribute(n,'id',VM.string(value))
   elseif key=='textContent' then
    local s=VM.string(value);assert(#s<=65536,'Text budget exceeded');for _,child in n.Children do child.Parent=nil end
    n.Children={};if s~='' then table.insert(n.Children,{Kind='Text',Text=s,Children={},Parent=n}) end;reindex()
   else error('Unsupported writable DOM property: '..VM.string(key)) end
  end
  return object
 end
 local globals={document=wrap(session.Document)}
 globals.Math={Get=function(key) local f=({min=math.min,max=math.max,round=function(x)return math.floor(x+.5)end,floor=math.floor,ceil=math.ceil,abs=math.abs,sin=math.sin,cos=math.cos})[key];if key=='PI' then return math.pi end;return if f then function(args) return f(table.unpack(args)) end else VM.Undefined end}
 vm=VM.new(globals,options);runtime.VM=vm
 function runtime:Run()
  local scripts={};local function visit(n) if n.Kind=='Element' and n.Name=='script' and n.NamespaceURI==NS then table.insert(scripts,n) end;for _,c in n.Children do visit(c) end end;visit(session.Document.Root)
  assert(#scripts<=32,'SVG script count budget exceeded')
  for _,node in scripts do
   local a=node.Attributes;local kind=a.type or 'application/ecmascript'
   if kind~='application/ecmascript' and kind~='text/ecmascript' and kind~='text/javascript' and kind~='application/javascript' then report('Unsupported SVG script type: '..kind);continue end
   local href=a.href or a['xlink:href'];local code=text(node)
   if href then if options.ResolveScript then code=options.ResolveScript(href) else report('External SVG script resolver unavailable: '..href);continue end end
   local ok,err=pcall(function() vm:Run(code) end);if not ok then report(err) end
  end
 end
 function runtime:Destroy() if not self.Alive then return end;self.Alive=false;for _,entry in self.Listeners do entry.Connection:Disconnect() end;table.clear(self.Listeners);table.clear(wrappers);vm:Destroy() end
 return runtime
end
return ScriptDOM
