--!strict
-- Compare semantic ancestry, so a recascade's fresh style tables do not invent
-- new bidi boundaries or merge words across a real isolation boundary.
local Scope={}
function Scope.same(a: any,b: any): boolean
 while a~=b do
  if not a or not b or a.Node~=b.Node or a.Mode~=b.Mode or a.Direction~=b.Direction then return false end
  a,b=a.Parent,b.Parent
 end
 return true
end
function Scope.path(context: any,root: any): any
 local path={}
 while context and context.Node~=root do table.insert(path,context);context=context.Parent end
 for index=1,math.floor(#path/2)do local other=#path-index+1;path[index],path[other]=path[other],path[index]end
 return path
end
function Scope.controls(mode: string,rtl: boolean): (string,string)
 if mode=='embed'then return utf8.char(if rtl then 0x202b else 0x202a),utf8.char(0x202c)
 elseif mode=='isolate'then return utf8.char(if rtl then 0x2067 else 0x2066),utf8.char(0x2069)
 elseif mode=='bidi-override'then return utf8.char(if rtl then 0x202e else 0x202d),utf8.char(0x202c)
 elseif mode=='isolate-override'then return utf8.char(0x2068,if rtl then 0x202e else 0x202d),utf8.char(0x202c,0x2069)
 elseif mode=='plaintext'then return utf8.char(0x2068),utf8.char(0x2069)end
 return '',''
end
return Scope
