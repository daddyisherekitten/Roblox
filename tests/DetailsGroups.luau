--!strict
return function(Parser,Node,Runtime,Events,Details)
	local document=Parser.parseDocument('<!doctype html><details name="group" id="a" open><summary>A</summary></details><details name="group" id="b" open><summary>B</summary></details><details name="other" id="c" open></details><div id="host"></div>')
	local a,b=Node.findById(document,"a"),Node.findById(document,"b")
	assert(a.Attributes.open~=nil and b.Attributes.open==nil,"Parser insertion preserves the first open group member")
	local messages,diagnostics={},{}
	local events=Events.new(error)
	local runtime=Runtime.new(document,{Events=events,MaxSteps=200000,Console=function(_,value)table.insert(messages,value)end,
		Diagnostic=function(value)table.insert(diagnostics,value)end})
	local function run(source)
		local ok,message=runtime:Run(source);assert(ok,tostring(message));assert(#diagnostics==0,table.concat(diagnostics,"\n"))
	end
	run([=[
function check(v,m){if(!v)throw new Error(m);}
var a=document.getElementById('a'),b=document.getElementById('b'),c=document.getElementById('c');
var delivered=[];var bubbled=0;
document.addEventListener('toggle',function(){bubbled++;});
[a,b,c].forEach(function(d){d.addEventListener('toggle',function(e){
 check(e instanceof ToggleEvent && e.target===d && e.isTrusted,'ToggleEvent brand/target/trust');
 check(!e.bubbles && !e.cancelable && !e.composed && e.source===null,'ToggleEvent flags/source');
 delivered.push(d.id+':'+e.oldState+'>'+e.newState);
});});
check(delivered.length===0,'Parser toggles must be tasks');
]=])
	runtime:PumpTasks()
	run("check(delivered.join(',')==='a:closed>open,b:closed>closed,c:closed>open','Parser coalesced states/order: '+delivered);delivered=[];")
	run("b.open=true;check(!a.open && b.open && c.open,'Opening closes only the same named group');check(delivered.length===0,'Attribute toggles are async');")
	runtime:PumpTasks()
	run("check(delivered.join(',')==='b:closed>open,a:open>closed','Closing other task order: '+delivered);delivered=[];b.setAttribute('open','false');")
	runtime:PumpTasks();run("check(delivered.length===0,'Changing a present boolean value does not toggle');")
	run("b.open=false;b.open=true;b.open=false;queueMicrotask(function(){check(delivered.length===0,'Microtasks precede toggle tasks');});")
	runtime:PumpTasks();run("check(delivered.join(',')==='b:open>closed','Coalescing keeps original old and final new state');delivered=[];")
	run([=[
a.open=true;b.name='';b.open=true;check(a.open && b.open,'Empty names are not groups');
b.name='Group';check(a.open && b.open,'Names are case sensitive');
b.name='group';check(a.open && !b.open,'Renaming closes the renamed element');
var detached=document.createElement('div');var x=document.createElement('details'),y=document.createElement('details');
x.name='same';y.name='same';detached.appendChild(x);detached.appendChild(y);x.open=true;y.open=true;
check(!x.open && y.open,'Detached trees enforce grouping');
var z=document.createElement('details');z.name='same';z.open=true;detached.appendChild(z);
check(y.open && !z.open,'Insertion closes the inserted element');
var shadow=document.getElementById('host').attachShadow({mode:'closed'});
var inside=document.createElement('details');inside.name='group';shadow.appendChild(inside);inside.open=true;
check(a.open && inside.open,'Shadow root and document have different groups');
document.body.appendChild(inside);check(a.open && !inside.open,'Move runs insertion exclusivity in the destination');
var foreign=document.createElementNS('urn:example','details');foreign.setAttribute('name','group');foreign.setAttribute('open','');
document.body.appendChild(foreign);check(a.open && foreign.hasAttribute('open'),'Non-HTML details are not group members');
var ns=document.createElement('details');ns.setAttributeNS('urn:example','open','');
var nsToggles=0;ns.ontoggle=function(){nsToggles++;};
var fragment=document.createElement('div');fragment.innerHTML='<details name="f" open></details><details name="f" open></details>';
check(fragment.children[0].open && !fragment.children[1].open,'Fragment parser groups');
]=])
	runtime:PumpTasks();run("check(nsToggles===0 && bubbled===0,'Namespace exclusion/nonbubbling');delivered=[];")
	-- Reentrant listeners inherit the running task's old state until dispatch
	-- returns, matching the details toggle task tracker algorithm.
	run("var r=document.createElement('details');var reentrant=[];r.ontoggle=function(e){reentrant.push(e.oldState+'>'+e.newState);if(reentrant.length===1)r.open=false;};r.open=true;")
	runtime:PumpTasks();run("check(reentrant.join(',')==='closed>open,closed>closed','Reentrant task tracking: '+reentrant);")
	run("var records=[];new MutationObserver(function(rs){rs.forEach(function(m){records.push(m.target.id+':'+m.oldValue);});}).observe(document.body,{subtree:true,attributes:true,attributeFilter:['open'],attributeOldValue:true});b.open=true;check(records.length===0,'Observer delivery is not inline');")
	run("check(records.join(',')==='b:null,a:','Group closes use real attribute mutations: '+records);")
	-- Disposal cancels realm tasks rather than retaining closed DOM trees.
	run("b.open=false;");assert(runtime.EventLoop.TaskCount>0)
	runtime:Destroy();assert(runtime.EventLoop.TaskCount==0);events:Destroy()
	local deferred,fired={},{}
	local controller;local function change(node,key,value)local old=node.Attributes[key];node.Attributes[key]=value;controller:AttributeChanged(node,key,value,old)end
	controller=Details.new({Attribute=change})
	controller:Start(Node.document(),{QueueTask=function(fn)local item={Callback=fn};table.insert(deferred,item);return item end,
		CancelTask=function(item)item.Callback=nil end,Fire=function(node,old,new)table.insert(fired,{node,old,new})end})
	local group=Node.element("div",{});local first=Node.element("details",{name="n"});local second=Node.element("details",{name="n"})
	Node.append(group,first);Node.append(group,second);change(first,"open","");change(second,"open","")
	assert(first.Attributes.open==nil and second.Attributes.open~=nil)
	change(second,"open",nil);change(second,"open","")
	for _,item in table.clone(deferred)do if item.Callback then item.Callback()end end
	assert(#fired==2 and fired[1][1]==first and fired[1][2]=="closed" and fired[1][3]=="closed")
	assert(fired[2][1]==second and fired[2][2]=="closed" and fired[2][3]=="open")
	change(first,"open","");controller:Destroy()
	for _,item in deferred do assert(item.Callback==nil or #fired==2)end
	print("DetailsGroups: parser/native/DOM exclusivity, names, moves, shadow roots, task coalescing/reentrancy, events, observers and disposal passed")
end
