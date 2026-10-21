--!strict
-- A document's origin is fixed at creation. Opaque origins compare by identity;
-- serializing two of them as "null" never makes those documents same-origin.
local URLRecord=require(script.Parent.Parent.JavaScript.URLRecord)
local Origin={}
local tuple={http=true,https=true,ftp=true,ws=true,wss=true}
function Origin.fromURL(address:string):any
 local ok,_,record=pcall(URLRecord.resolve,address)
 if ok then
  if tuple[record.Scheme]then return record.Scheme..'://'..record.Hostname..(if record.Port~=''then ':'..record.Port else '')end
  if record.Scheme=='blob'then
   local valid,_,inner=pcall(URLRecord.resolve,record.Path)
   if valid and(inner.Scheme=='http'or inner.Scheme=='https')then return inner.Scheme..'://'..inner.Hostname..(if inner.Port~=''then ':'..inner.Port else '')end
  end
 end
 return {}
end
function Origin.ensure(document:any,address:string?,inherited:any?,opaque:boolean?):any
 if document.DocumentOrigin==nil then document.DocumentOrigin=if opaque then {}elseif inherited~=nil then inherited else Origin.fromURL(address or 'about:blank')end
 return document.DocumentOrigin
end
return Origin
