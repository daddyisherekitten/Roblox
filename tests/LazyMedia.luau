--!strict
-- Continuation ownership/reentry and native-error delivery; geometry uses real mounted suite separately.
return function(Parser,Node,LazyMedia)
 local assertions=0
 local function check(value,label)assertions+=1;assert(value,label)end
 local function fixture(taskOverride,clock)
  local document=Parser.parse('<video id=v loading=lazy></video><video id=w loading=lazy></video>')
  local node=Node.findById(document,'v');local other=Node.findById(document,'w');local jobs={}
  local page={Alive=true,Document=document,GeometryViewport=function()return{Width=100,Height=100}end}
  local tree={NodeBoxes={},NodeStyles={}}
  for _,target in{node,other}do tree.NodeBoxes[target]={Node=target,Style={},LayoutX=0,LayoutY=500,OuterWidth=10,OuterHeight=10}end
  local tasks=taskOverride or{defer=function(fn)table.insert(jobs,fn)end,wait=function()end}
  return LazyMedia.new(page,tree,{Task=tasks,ScriptingEnabled=true,Clock=clock}),node,other,page,tree,jobs
 end
 do
  local owner,node,_,_,_,jobs=fixture();local seen={};local old=owner:Defer(node,'Media',function()error('Retired callback')end)
  owner:Defer(node,'Media',function()table.insert(seen,'media');owner:Defer(node,'Media',function()table.insert(seen,'next')end)end)
  owner:Defer(node,'Poster',function()table.insert(seen,'poster')end);old()
  check(owner.Count==2 and#jobs==1,'One coalesced check and one slot per kind; old cancel cannot clear replacement')
  check(owner:Resume(node)and table.concat(seen,',')=='media,poster'and owner.Count==1,'Both old slots taken before reentrant media continuation installs next')
  owner:Resume(node,'Media');check(table.concat(seen,',')=='media,poster,next'and owner.Count==0,'New continuation is independently resumable')
  owner:Destroy();for _,job in jobs do job()end;check(owner.Count==0,'Queued check after disposal is inert')
 end
 for _,kind in{'nil','false','table'}do
  local owner,node,_,_,_,jobs=fixture();local token=if kind=='false'then false elseif kind=='table'then{}else nil;local poster=false
  owner:Defer(node,'Media',function()error(token,0)end);owner:Defer(node,'Poster',function()poster=true end)
  local ok,value=pcall(owner.Resume,owner,node)
  check(not ok and value==token and poster and owner.Count==0,'First '..kind..' payload preserved after independent poster continuation')
  owner:Destroy();for _,job in jobs do job()end
 end
 do
  local owner,node,other,_,_,jobs=fixture();local count=0
  owner:Defer(node,'Media',function()count+=1;error(false,0)end);owner:Defer(other,'Media',function()count+=1;error(false,0)end)
  node.Attributes.loading='eager';other.Attributes.loading='eager'
  local ok,value=pcall(table.remove(jobs,1))
  check(not ok and value==false and count==2 and owner.Count==0,'One failing target cannot strand another target in same pending-only check')
  owner:Destroy()
 end
 do
  local owner,node,_,page,_,jobs=fixture();local poster=false
  owner:Defer(node,'Media',function()page.Alive=false;owner:Destroy()end);owner:Defer(node,'Poster',function()poster=true end)
  owner:Resume(node);check(not poster and owner.Count==0,'Disposal in media continuation prevents detached poster callback')
  for _,job in jobs do job()end
 end
 do
  local owner,node,_,_,_,jobs=fixture();local count=0
  local cancel=owner:Defer(node,'Media',function()count+=1 end);cancel();cancel();check(owner.Count==0,'Cancellation idempotently releases captured continuation')
  for _,job in jobs do job()end;table.clear(jobs)
  for _=1,5 do owner:Check(true)end;check(#jobs==0 and count==0,'Empty owner creates no queued scan')
  owner:Destroy()
 end
 do
  local owner,node=fixture({defer=function()error(false,0)end});local ok,value=pcall(owner.Defer,owner,node,'Media',function()end)
  check(not ok and value==false and owner.Count==0,'Scheduling failure releases rejected continuation with exact false error');owner:Destroy()
 end
 do
  local queued={};local now=0;local resumes=0
  local owner,node,_,page,_,_=fixture({defer=function(fn)table.insert(queued,fn)end,wait=function()coroutine.yield()end},function()now+=.002;return now end)
  owner:Defer(node,'Media',function()resumes+=1 end);owner:Check(true)
  local thread=coroutine.create(table.remove(queued,1));local ok=coroutine.resume(thread);check(ok and coroutine.status(thread)=='suspended','Real cooperative scan checkpoint suspended')
  for _=1,20 do owner:Check(true)end;check(#queued==0,'Geometry changes coalesce while one scan is suspended')
  page.Alive=false;owner:Destroy();local continued,message=coroutine.resume(thread)
  check(continued and coroutine.status(thread)=='dead'and resumes==0 and owner.Count==0 and#queued==0,'Disposal of suspended scan quietly cancels work and all continuations')
 end
 for _,kind in{'nil','false','table'}do
  local owner,node,other,page,_,jobs=fixture();local count=0;local token=if kind=='false'then false elseif kind=='table'then{}else nil
  local function fail()count+=1;page.Alive=false;owner:Destroy();error(token,0)end
  owner:Defer(node,'Media',fail);owner:Defer(other,'Media',fail);node.Attributes.loading='eager';other.Attributes.loading='eager'
  local ok,value=pcall(table.remove(jobs,1))
  check(not ok and value==token and count==1 and owner.Count==0,'Callback '..kind..' error survives immediate owner destruction and quiet scan cancellation')
 end
 print('LazyMedia: continuation replacement, cancellation/reentry, nil/false/table errors, independent target completion, teardown and idle-free checks; '..assertions..' assertions')
end
