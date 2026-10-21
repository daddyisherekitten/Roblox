--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- HTML successful controls. Reads the shared live control records, including
-- controls without render boxes; never inspects native Roblox Instances.
local Node=require(script.Parent.Parent.DOM.Node)
local State=require(script.Parent.Parent.Controls.State)
local Defaults=require(script.Parent.Parent.Controls.Defaults)
local Strings=require(script.Parent.Strings)
local Directions=require(script.Parent.FormDirectionData)
local FormDataDOM={}
function FormDataDOM.new(vm: any,bridge: any,document: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true}
 local function check()assert(api.Alive and vm.Alive and bridge.Alive,"FormData DOM adapter disposed")end
 local function fail(name,message)VM.throw(if name~="TypeError"and name~="RangeError"and options.Events then options.Events:DOMException(message,name)else VM.error(name,message))end
 local html=ElementNames.html
 local function root(node)while node.Parent do node=node.Parent end;return node end
 local function ancestor(node,name)local current=node.Parent;while current do if html(current,name)then return current end;current=current.Parent end;return nil end
 local function owner(node)
  local handled,value=bridge.Controls:Get(node,"form");if handled then return if value==N or value==U then nil else bridge.Unwrap(value)end
  if node.Attributes.form~=nil then local tree=root(node);if tree.Kind~="Document"then return nil end;local found=Node.findById(tree,node.Attributes.form);return if found and html(found,"form")then found else nil end
  return ancestor(node,"form")
 end
 local function get(node,key,default)local handled,value=bridge.Controls:Get(node,key);return if handled then value else default end
 local function typeOf(node)
  local raw=(node.Attributes.type or ""):lower()
  if ElementNames.htmlName(node)=="input"and(raw=="file"or raw=="image")then return raw end
  return Defaults.kind(node)
 end
 local function contains(ranges,cp)
  local low,high=1,#ranges/2;while low<=high do local mid=math.floor((low+high)/2);if cp<ranges[mid*2-1]then high=mid-1 elseif cp>ranges[mid*2]then low=mid+1 else return true end end;return false
 end
 local function strong(text)
  for cp in Strings.codes(text)do vm.Step();if contains(Directions.RTL,cp)then return "rtl"elseif contains(Directions.LTR,cp)then return "ltr"end end;return nil
 end
 local function autoText(node)
  local pending={node};while #pending>0 do local current=table.remove(pending);vm.Step()
   if current.Kind=="Text"then local direction=strong(current.Text or "");if direction then return direction end
   elseif current==node or(not(current.Attributes and current.Attributes.dir)and not table.find({"bdi","script","style","textarea"},ElementNames.htmlName(current)))then for i=#current.Children,1,-1 do table.insert(pending,current.Children[i])end end
  end;return nil
 end
 local function direction(node,value)
  if options.Direction then local result=options.Direction(node,value);if result=="ltr"or result=="rtl"then return result end end
  local current=node;while current do
   local dir=(current.Attributes and current.Attributes.dir or ""):lower();if dir=="ltr"or dir=="rtl"then return dir
   elseif dir=="auto"then return (if current==node and(ElementNames.htmlName(node)=="input"or ElementNames.htmlName(node)=="textarea")then strong(value)else autoText(current))or "ltr"end
   current=current.Parent
  end;return "ltr"
 end
 function api:Entries(formValue,submitterValue)
  check();if not bridge.Controls then fail("NotSupportedError","FormData needs the DOM control state bridge")end
  local form=bridge.Unwrap(formValue);if not html(form,"form")then fail("TypeError","FormData requires an HTMLFormElement")end
  local submitter
  if submitterValue~=nil and submitterValue~=U and submitterValue~=N then
   submitter=bridge.Unwrap(submitterValue);local kind=typeOf(submitter)
   if not html(submitter)or(ElementNames.htmlName(submitter)~="button"and ElementNames.htmlName(submitter)~="input")or(kind~="submit"and kind~="image")then fail("TypeError","FormData submitter must be a submit button")end
   if owner(submitter)~=form then fail("NotFoundError","Submitter belongs to another form")end
  end
  local result={};local function append(name,value)if #result>=1024 then fail("RangeError","FormData entry budget exceeded")end;table.insert(result,{name=name,value=value})end
  local pending={root(form)}
  while #pending>0 do
   local node=table.remove(pending);vm.Step();for i=#node.Children,1,-1 do table.insert(pending,node.Children[i])end
   local definition=node.CustomElementDefinition
   local internals=definition and definition.API and definition.API.Internals
   if internals and internals:IsFormAssociated(node)then
    if internals:Owner(node)==form and not State.disabled(node)and not ancestor(node,"datalist")then for _,entry in internals:Submission(node)do append(entry.name,entry.value)end end
    continue
   end
   if not html(node)or not table.find({"input","textarea","select","button","object"},ElementNames.htmlName(node))then continue end
   if owner(node)~=form or State.disabled(node)or ancestor(node,"datalist")then continue end
   local kind=typeOf(node);local name=node.Attributes.name or ""
   if ElementNames.htmlName(node)=="button"or kind=="submit"or kind=="reset"or kind=="button"or kind=="image"then
    if node~=submitter then continue end
	   if kind=="image"then local prefix=if name==""then ""else name..".";local point=bridge.Controls:State(node).ImagePoint or {X=0,Y=0};append(prefix.."x",tostring(point.X));append(prefix.."y",tostring(point.Y));continue end
   end
   if name==""then continue end
   if kind=="checkbox"or kind=="radio"then if get(node,"checked",false)then append(name,get(node,"value","on"))end;continue end
   if ElementNames.htmlName(node)=="select"then
    local state=bridge.Controls:State(node)
    for index,item in state.Options or {}do vm.Step();if not item.Disabled and(if state.SelectMultiple then state.SelectedIndices[index]else state.SelectedIndex==index)then append(name,item.Value)end end
    continue
   end
   if kind=="file"then
    local state=bridge.Controls:State(node);local files=if options.GetFiles then options.GetFiles(node,state)else state.Files or {}
    if #files==0 then append(name,options.Network:CreateBlob({Bytes="",Type="application/octet-stream",Name="",LastModified=if options.Now then options.Now()else os.time()*1000}))
    else for _,file in files do vm.Step();local snapshot=options.Network:DescribeBlob(file);if not snapshot or snapshot.Name==nil then fail("TypeError","File input adapter returned a non-File value")end;append(name,file)end end
    continue
   end
   if ElementNames.htmlName(node)=="object"then continue end -- No plugin form submission adapter.
   local value=if kind=="hidden"and name:lower()=="_charset_"then "UTF-8"else get(node,"value","");append(name,value)
   local dirname=node.Attributes.dirname
   if dirname and dirname~=""and(ElementNames.htmlName(node)=="textarea"or(ElementNames.htmlName(node)=="input"and table.find({"text","search","tel","url","email"},(node.Attributes.type or "text"):lower())))then append(dirname,direction(node,value))end
  end
  return result
 end
 function api:Constructed(formValue,formData)
  check();local form=bridge.Unwrap(formValue)
  local event=options.Network.FormData:Event(formData)
  if options.Dispatch then options.Dispatch(form,event)
  elseif options.Events and options.TargetFor then options.Events:Dispatch(options.TargetFor(form),event,true)
  else fail("NotSupportedError","FormData formdata dispatch requires the DOM event adapter")end
 end
 function api:Destroy()self.Alive=false end
 return api
end
return FormDataDOM
