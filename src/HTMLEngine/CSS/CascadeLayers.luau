--!strict
local MediaQueries=require(script.Parent.MediaQueries)
local Syntax=require(script.Parent.Syntax)
local Layers={}
function Layers.new()return {Root={Children={}},Events={}}end
function Layers.parts(name:string):any?
 local parts,index={},1
 repeat
  local part,after=Syntax.identifier(name,index)
  if not part or({initial=true,inherit=true,unset=true,revert=true,['revert-layer']=true,default=true})[part:lower()]then return nil end
  table.insert(parts,part);index=after
  if index>#name then return parts end
  if name:sub(index,index)~='.'then return nil end
  index+=1
 until index>#name
 return nil
end
function Layers.valid(name:string):boolean return Layers.parts(name)~=nil end
function Layers.name(name:string):string?
 local parts=Layers.parts(name);if not parts then return nil end
 for i,part in parts do parts[i]=Syntax.serializeIdentifier(part)end
 return table.concat(parts,'.')
end
function Layers.declare(state,name:string?,parent:any?,media:any?):any?
 parent=parent or state.Root;local parts={}
 if name and name~=''then
  parts=Layers.parts(name);if not parts then return nil end
 else table.insert(parts,{})end -- unique anonymous name
 local chain={};local at=parent
 while at and at~=state.Root do table.insert(chain,1,at);at=at.Parent end
 for _,part in parts do
  local child=parent.Children[part];if not child then child={Parent=parent,Children={},Name=part};parent.Children[part]=child end
  table.insert(chain,child);parent=child
 end
 table.insert(state.Events,{Chain=chain,Media=media})
 return parent
end
function Layers.update(state,environment):boolean
 local paths,counts,changed={},{},false
 for _,event in state.Events do
  local matches=true;for _,query in event.Media or{}do if not MediaQueries.matches(query,environment)then matches=false;break end end
  if not matches then continue end
  for _,layer in event.Chain do if not paths[layer]then local parent=layer.Parent;counts[parent]=(counts[parent]or 0)+1;local path=if parent==state.Root then{}else table.clone(paths[parent]);table.insert(path,counts[parent]);paths[layer]=path end end
 end
 for _,event in state.Events do for _,layer in event.Chain do
  local path=paths[layer];local previous=layer.Path
  if(not path)~=(not previous)or(path and previous and(#path~=#previous or table.concat(path,'.')~=table.concat(previous,'.')))then changed=true end
  layer.Path=path
 end end
 return changed
end
function Layers.compare(a,b):number
 if a==b then return 0 end
 local x,y=a and a.Path or{},b and b.Path or{}
 for i=1,math.max(#x,#y)do local lhs,rhs=x[i]or math.huge,y[i]or math.huge;if lhs~=rhs then return if lhs<rhs then-1 else 1 end end
 return 0
end
return Layers
