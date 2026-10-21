--!strict
return function(Parser,Runtime,Events,fixture)
	for _,case in fixture.cases do
		local output,diagnostics={},{};local events=Events.new(error)
		local runtime=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),{Events=events,ControlAdapter={Events=events},MaxSteps=200000,
			Console=function(_,v)table.insert(output,v)end,Diagnostic=function(v)table.insert(diagnostics,v)end})
		local ok,message=runtime:Run('function record(v){console.log(String(v));}'..case.source)
		assert(ok,tostring(message));assert(#diagnostics==0,table.concat(diagnostics,' / '))
		assert(#output==#case.expected,case.name..' output length')
		for i,value in output do assert(value==case.expected[i],case.name..' ['..i..']: '..value..' ~= '..case.expected[i])end
		runtime:Destroy();events:Destroy()
	end
	local diagnostics={};local events=Events.new(error)
	local runtime=Runtime.new(Parser.parseDocument([=[<!doctype html><form id="form"><select id="s">
		<button><selectedcontent id="m"></selectedcontent></button>
		<option id="a" value="a"><b data-mark="a">A</b></option><option id="b" value="b"><i>B</i></option>
	</select></form>]=]),{Events=events,ControlAdapter={Events=events},MaxSteps=200000,Diagnostic=function(v)table.insert(diagnostics,v)end})
	local ok,message=runtime:Run([=[
function check(v,m){if(!v)throw new Error(m);}
const s=document.getElementById('s'),m=document.getElementById('m'),a=document.getElementById('a'),b=document.getElementById('b');
check(m.innerHTML==='<b data-mark="a">A</b>' && m.firstChild!==a.firstChild,'Initial deep copy');
let input=0; s.addEventListener('input',()=>input++);s.addEventListener('change',()=>input++);
const observer=new MutationObserver(()=>{});observer.observe(m,{childList:true});
s.value='b';const records=observer.takeRecords();check(records.length===1 && records[0].addedNodes.length===1 && records[0].removedNodes.length===1,'Normal replacement record');
const held=m.firstChild;held.title='local';b.firstChild.textContent='B2';
check(m.firstChild===held && m.innerHTML==='<i title="local">B</i>','Option text mutation preserves snapshot and identity');
s.value='b';check(m.firstChild!==held && m.innerHTML==='<i>B2</i>','Same-value setter refreshes deep copy');
b.selected=false;check(s.value==='a' && m.firstChild.tagName==='B','Option selection reset');
s.value='b';document.getElementById('form').reset();check(s.value==='a' && m.firstChild.tagName==='B','Form reset');
const nested=document.createElement('selectedcontent');m.appendChild(nested);s.value='b';check(nested.parentNode===null,'Nested mirror is replaced with the snapshot');
const blocked=document.createElement('selectedcontent');blocked.textContent='unchanged';b.appendChild(blocked);s.value='a';
check(blocked.textContent==='unchanged','Option descendants cannot be mirrors');
s.value='missing';check(m.childNodes.length===0 && s.selectedIndex===-1,'Empty selection clears copies');
s.value='a';s.multiple=true;s.value='b';check(m.firstChild.tagName==='B','Multiple select preserves existing copy');
s.multiple=false;check(m.firstChild.tagName==='I','Returning to single select refreshes copy');
check(input===0,'Programmatic copying does not synthesize user selection events');
const probe=document.createElement('select');
function insert(parent,name,value,namespace){const el=namespace?document.createElementNS(namespace,name):document.createElement(name);if(value)el.setAttribute('value',value);parent.appendChild(el);return el;}
const wrapper=insert(probe,'div');const first=insert(wrapper,'option','first');first.textContent='First';
insert(insert(wrapper,'optgroup'),'option','grouped');
const outer=insert(wrapper,'optgroup');insert(outer,'option','outer');insert(insert(outer,'optgroup'),'option','nested-group');
insert(insert(wrapper,'select'),'option','nested-select');insert(insert(wrapper,'datalist'),'option','datalist');
insert(insert(wrapper,'hr'),'option','hr-child');insert(first,'option','option-child');
insert(wrapper,'option','foreign','http://www.w3.org/2000/svg');
insert(insert(wrapper,'button'),'option','button-child');
check(probe.options.length===4 && [...probe.options].map(o=>o.value).join(',')==='first,grouped,outer,button-child','Normative option traversal excludes nested groups, selects, datalists, hr and option descendants, and foreign lookalikes');
observer.disconnect();
]=])
	assert(ok,tostring(message));assert(#diagnostics==0,table.concat(diagnostics,' / '));runtime:Destroy();events:Destroy()
	print('Selectedcontent: native Chromium snapshot sequence, deep identity, same-value refresh, multiple/select/reset, disabled descendants, normal observer records and cleanup passed')
end
