--!strict
return function(Source)
 local checks=0
 local function check(value,label)checks+=1;assert(value,label)end
 local source,owners,contexts
 local function create()
  local old={Kind='Document',Children={},URL='https://history.test/A/index.html'}
  local root={Kind='Element',Name='html',Children={},Parent=old,OwnerDocument=old}
  local child={Kind='Element',Name='p',Children={},Parent=root,OwnerDocument=old};old.Children={root};root.Children={child}
  local plain={};local matched={Children={}};local matchedChild={Parent=matched};matched.Children={matchedChild};matchedChild.OwnerDocument=matched
  local current={Kind='Document',Children={},URL='https://history.test/B/index.html'}
  local node={Kind='Element',Name='source',Attributes={src='one.wav'},Children={},OwnerDocument=old}
  Source.write(node,'src','one.wav',nil,old);Source.observe(old,'https://history.test/A/','https://history.test/A/index.html')
  node.OwnerDocument=current
  return node,setmetatable({old,root,child,plain,matched,matchedChild},{__mode='v'}),setmetatable({node.MediaSourceDocument},{__mode='v'})
 end
 source,owners,contexts=create()
 local function pressureFrame()
  for _=1,128 do local pressure=table.create(2048);for index=1,2048 do pressure[index]={index}end end
 end
 pressureFrame()
 for index=1,6 do check(owners[index]==nil,'Weak source history releases old document/cyclic plain control '..index)end
 check(source.MediaSourceDocument~=nil and source.MediaSourceDocument.Document[1]==nil,'Retained SOURCE context has no strong document/realm link')
 check(source.MediaSourceDocument.Base=='https://history.test/A/'and source.MediaSourceDocument.URL=='https://history.test/A/index.html','Collected-origin profile keeps last observed data-only fallback')
 source.Attributes.src=nil;Source.write(source,'src',nil,nil,source.OwnerDocument);pressureFrame()
 check(source.MediaSourceDocument==nil and contexts[1]==nil,'src removal releases unused historical context')
 print('SOURCE_DOCUMENT_LIFETIME','controls=9','checks='..checks,'pressure=128x2048','scope=data-only weak document/context; no Page/VM/native GC claim')
end
