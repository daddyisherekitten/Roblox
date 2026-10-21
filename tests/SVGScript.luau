--!strict
return function(Syntax,VM,DOM,Session,Parser,Conditional,Document)
 local output={};local vm=VM.new({save=function(a) table.insert(output,a[1]) end})
 vm:Run([[const n=4; let sum=0; for(let i=0;i<n;i++){sum+=i;} function twice(x){return x*2;} save(twice(sum)); save(false || 'fallback'); save('v'+3);]])
 assert(output[1]==12 and output[2]=='fallback' and output[3]=='v3')
 vm:Run([[let k=0;while(k<10){k++;if(k===3){break;}}save(k);]])
 assert(output[4]==3)
 vm:Run([[save(Number(false));save(String(false));function identity(x){return x;}save(identity(false));]])
 assert(output[5]==0 and output[6]=='false' and output[7]==false,'False is a real JavaScript value')
 vm:Run([[const matrix={a:1,b:2,"e":7};matrix.f=9;save(matrix.a+matrix.b+matrix.e+matrix.f);]])
 assert(output[8]==19,'Bounded object literals expose readable and writable properties')
 local constructed=VM.new({save=function(args)table.insert(output,args[1])end});constructed:Run('function Box(value){this.value=value;}const box=new Box(23);save(box.value);');assert(output[9]==23,'Constructor expressions use the shared JavaScript object model')
 local seen='';local property=1
 local object={Get=function()return property end,Set=function(_,value)property=value end}
 local order=VM.new({left=function()seen..='L';return object end,right=function()seen..='R';return 2 end})
 order:Run('left().value+=right();');assert(seen=='LR' and property==3,'Lvalue is evaluated once before RHS')
 local callbacks={};vm=VM.new({keep=function(a)table.insert(callbacks,a[1])end,save=function(a)table.insert(output,a[1])end})
 vm:Run([[for(let i=0;i<3;i++){keep(function(){return i;});}]])
 for i,fn in callbacks do assert(vm:Call(fn,{})==i-1,'Per-iteration closure') end
 local ok,err=pcall(function()vm:Run('while(true){}')end);assert(not ok and tostring(err):find('budget'),'Infinite loop stopped')
 ok=pcall(function()vm:Run('const c=2;c=3;')end);assert(not ok,'const assignment rejected')
 ok=pcall(function()Syntax.parse('let f = =>42;')end);assert(not ok,'Invalid grammar is explicit')
 ok=pcall(function()vm:Run('game.GetService("HttpService");')end);assert(not ok,'No implicit Roblox host access')
 -- Public calls re-enter synchronously through host event callbacks. The whole
 -- event must retain one budget and unwind depth even if a host catches errors.
 for _,limit in {{Steps=256,Expected='budget'},{Steps=100000,Expected='depth'}} do
  local nested,callback;local calls=0
  nested=VM.new({keep=function(a)callback=a[1]end,reenter=function()
   calls+=1;if calls<90 then nested:Call(callback,{}) end
  end},{MaxSteps=limit.Steps})
  nested:Run('function again(){reenter();} keep(again);')
  local passed,problem=pcall(function()nested:Call(callback,{})end)
  assert(not passed and tostring(problem):find(limit.Expected),'Reentrant callbacks share the outer '..limit.Expected..' limit')
  assert(calls<90 and nested.Depth==0,'Failed nested calls restore outer depth')
  calls=90;nested:Call(callback,{})
  assert(nested.Depth==0 and nested.Steps<50,'The next independent callback receives a fresh budget')
 end
 local reentrant,good,bad;local depthRestored=false;local result
 reentrant=VM.new({keep=function(a)good=a[1];bad=a[2]end,host=function()
  local depth,steps=reentrant.Depth,reentrant.Steps
  local passed=pcall(function()reentrant:Call(bad,{})end)
  assert(not passed and reentrant.Depth==depth and reentrant.Steps>steps,'Caught callback errors preserve enclosing depth and accumulated steps')
  assert(reentrant:Call(good,{})==17 and reentrant.Depth==depth,'Nested success restores enclosing depth')
  depthRestored=true
 end,save=function(a)result=a[1]end})
 reentrant:Run('function good(){return 17;} function bad(){missing();} keep(good,bad); host(); save(23);')
 assert(depthRestored and result==23 and reentrant.Depth==0,'Outer execution continues correctly after a caught nested error')
 -- Reentrant Run shares the same budget, including reentry from host functions.
 local runner;local runs=0
 runner=VM.new({again=function()runs+=1;if runs<90 then runner:Run('again();')end end},{MaxSteps=50})
 local runOK,runError=pcall(function()runner:Run('again();')end)
 assert(not runOK and tostring(runError):find('budget') and runs<90 and runner.Depth==0)
 local disposed;local wrote=false
 disposed=VM.new({dispose=function()disposed:Destroy()end,save=function()wrote=true end})
 local aliveOK,aliveError=pcall(function()disposed:Run('dispose(); save();')end)
 assert(not aliveOK and tostring(aliveError):find('disposed') and not wrote,'Disposal in a callback stops subsequent script instructions')
 local yielding
 yielding=VM.new({},{Checkpoint=function()yielding:Destroy()end})
 local yieldOK,yieldError=pcall(function()yielding:Run('while(true){}')end)
 assert(not yieldOK and tostring(yieldError):find('disposed') and yielding.Depth==0,'Disposal during a checkpoint stops before execution resumes')
 local doc=Parser.parse([==[<svg xmlns="http://www.w3.org/2000/svg"><g id="host"/><rect id="button"/><text id="count">0</text><script><![CDATA[
 const root=document.getElementById('host');
 const c=document.createElementNS('http://www.w3.org/2000/svg','circle');
 c.setAttribute('id','new');c.setAttribute('r',20);root.appendChild(c);
 let count=0;
 function change(e){count++;c.setAttribute('cx',count*10);document.getElementById('count').textContent=String(count);}
 document.getElementById('button').addEventListener('click',change);
 ]]></script></svg>]==])
 local s=Session.new(doc,function()return {Shapes={},Nodes={}}end,{Report=function(e)error(e)end})
 local runtime=DOM.new(s);s.Script=runtime;runtime:Run();assert(#runtime.Diagnostics==0,runtime.Diagnostics[1] and runtime.Diagnostics[1].Value)
 assert(s:Node('new').Parent==s:Node('host'))
 s:Activate(s:Node('button'));s:Activate(s:Node('button'));assert(s:Node('new').Attributes.cx=='20' and s:Node('count').Children[1].Text=='2')
 runtime.VM:Run([[document.getElementById('button').removeEventListener('click',change);document.getElementById('new').remove();]])
 assert(s:Node('new')==nil);s:Activate(s:Node('button'));assert(s:Node('count').Children[1].Text=='2')
 runtime.VM:Run([[root.appendChild(c);]])
 assert(s:Node('new') and s:Node('new').Attributes.r=='20','Removed node can be reattached')
 s:Destroy();assert(not runtime.Alive and not runtime.VM.Alive and #runtime.Listeners==0)
 local focusDoc=Parser.parse([==[<svg xmlns="http://www.w3.org/2000/svg"><rect id="a"/><rect id="b"/><script><![CDATA[
 const a=document.getElementById('a');const b=document.getElementById('b');
 a.addEventListener('focus',function(){b.focus();});
 b.addEventListener('focus',function(){a.focus();});
 a.focus();
 ]]></script></svg>]==])
 local focusSession=Session.new(focusDoc,function()return {Shapes={},Nodes={}}end)
 local focusRuntime=DOM.new(focusSession,{MaxSteps=200});focusSession.Script=focusRuntime
 focusRuntime:Run()
 assert(#focusRuntime.Diagnostics>0 and focusRuntime.Diagnostics[1].Value:find('budget'),'Real synchronous focus events cannot reset the script budget')
 assert(focusRuntime.VM.Depth==0,'DOM listener error handling restores VM depth')
 focusSession:Destroy()
 assert(Conditional.matches({systemLanguage='de, en'},{Languages={'de-CH'}}))
 assert(not Conditional.matches({systemLanguage='de-CH'},{Languages={'de'}}))
 assert(not Conditional.matches({requiredExtensions='unknown'},{Languages={'en'}}))
 assert(Conditional.matches({requiredFeatures='a b'},{Features={a=true,b=true}}))
 doc=Parser.parse([==[<svg xmlns="http://www.w3.org/2000/svg"><switch><rect id="de" systemLanguage="de"/><rect id="en" systemLanguage="en"/><rect id="fallback"/></switch><view id="detail" viewBox="10 20 80 60"/></svg>]==])
 local styled=Document.prepare(doc,{Languages={'en-US'},Fragment='#detail'})
 assert(styled.Root.Attributes.viewBox=='10 20 80 60' and #styled.Root.Children==1)
 assert(styled.Root.Children[1].Children[1].Attributes.id=='en','First matching language branch only')
 assert(doc.Root.Attributes.viewBox==nil,'View selection preserves base SVG')
 styled=Document.prepare(doc,{Languages={'ja'},Fragment='svgView(viewBox(1,2,30,40);preserveAspectRatio(none))'})
 assert(styled.Root.Attributes.viewBox=='1 2 30 40' and styled.Root.Attributes.preserveAspectRatio=='none')
 assert(styled.Root.Children[1].Children[1].Attributes.id=='fallback')
 local legacy=Document.prepare(Parser.parse('<svg xmlns="http://www.w3.org/2000/svg"><font id="old"/><meshgradient id="draft"/></svg>'))
 assert(#legacy.Diagnostics==2 and legacy.Diagnostics[1].Code=='unsupported-svg-extension','Legacy/draft features are explicit diagnostics')
 print('SVG S41/S42: JS arithmetic, closures, loops, budgets, DOM creation/removal/events, disposal, language selection and view fragments passed')
end
