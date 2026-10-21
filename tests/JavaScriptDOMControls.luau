--!strict
return function(Parser,Node,DOM,VM,Events,State,FormModel)
	local document=Parser.parseDocument('<html><body><form id="f"><input id="text" name="text" value="default" required><input id="box" type="checkbox" checked><input id="r1" type="radio" name="choice" checked><input id="r2" type="radio" name="choice" checked><textarea id="area">initial</textarea><select id="select"><option id="o1" value="a">Alpha</option><option id="o2" value="b" selected>Beta</option></select><select id="multi" multiple><option id="m1" selected>A</option><option id="m2" selected>B</option></select><button id="submit">Send</button></form><form id="other"><button id="foreign">Other</button></form><input id="external" form="f" value="external"><input id="number" type="number" value="4" min="2" max="8" step="2"><input id="email" type="email" value="a@b"><fieldset disabled><legend><input id="exempt"></legend><input id="disabled"></fieldset></body></html>')
	local controls,byNode={},{}
	local pending={document};while #pending>0 do
		local node=table.remove(pending)
		if node.Kind=="Element" and (node.Name=="input" or node.Name=="textarea" or node.Name=="select" or node.Name=="button") then local c=State.create(node);table.insert(controls,c);byNode[node]=c end
		for index=#node.Children,1,-1 do table.insert(pending,node.Children[index]) end
	end
	local events=Events.new(error);local model=FormModel.new(document,controls,events,function()end)
	local changed,notifications={},{};local lastReset,focus,vm
	events:BeforeEmit(function(e)if e.Type=="reset" then lastReset=e end end)
	local adapter={Events=events,ResolveControl=function(node)return byNode[node]end,
		SetControlValue=function(node,value)model:SetValue(byNode[node],value,false)end,
		SetControlChecked=function(node,value)model:SetChecked(byNode[node],value,false)end,
		ControlChanged=function(node,kind)table.insert(notifications,{Node=node,Kind=kind})end,
		FocusControl=function(node)focus=node end,BlurControl=function(node)if focus==node then focus=nil end end,
		ActivateControl=function(node)local c=byNode[node];if c then model:Activate(c)else events:Emit(node,"click")end end,
		ResetForm=function(form)model:Reset(form);return not lastReset.DefaultPrevented end,
		RequestSubmit=function(form,submitter)model:Submit(form,if submitter then byNode[submitter] else nil)end}
	local host={Events=events,ControlAdapter=adapter,Window={},ReadyState="complete",Changed=function(node,kind,key)table.insert(changed,{Node=node,Kind=kind,Key=key})end,
		Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(object,key)return vm.Get(object,key)end,
		GetControl=function()return VM.Undefined end,SetControl=function()error("Unbridged control")end,Click=function()end}
	local bridge=DOM.new(document,host)
	local function node(id)return Node.findById(document,id)end
	local function wrap(id)return bridge.Wrap(if type(id)=="string" then node(id) else id)end
	local function get(id,key)return wrap(id).Get(key)end
	local function set(id,key,value,strict)return wrap(id).Set(key,value,strict)end
	local function call(id,key,...)return get(id,key)({...})end
	local function expectError(callback,name)
		local ok,failure=pcall(callback);assert(not ok,"Expected "..name);assert(VM.exceptionValue(failure).Get("name")==name)
	end
	vm=VM.new({document=bridge.Document})
	assert(get("text","value")=="default" and get("text","defaultValue")=="default")
	set("text","defaultValue","new default");assert(get("text","value")=="new default")
	set("text","value","current\r\nvalue");assert(get("text","value")=="currentvalue" and get("text","defaultValue")=="new default")
	set("text","defaultValue","later default");assert(get("text","value")=="currentvalue" and byNode[node("text")].DefaultValue=="later default")
	set("text","value",VM.Null);assert(get("text","value")=="" and not call("text","checkValidity"))
	assert(get("text","form")==wrap("f") and get("external","form")==wrap("f"))
	local elements=get("f","elements");assert(get("f","elements")==elements and get("f","length")==elements.Get("length") and elements.Get("namedItem")({"text"})==wrap("text"))
	assert(get("box","value")=="on" and get("box","checked") and get("box","defaultChecked"))
	set("box","checked",false);set("box","defaultChecked",false);set("box","defaultChecked",true)
	assert(not get("box","checked") and get("box","defaultChecked"),"Dirty checkedness keeps the current value separate from its default")
	assert(not get("r1","checked") and get("r2","checked"),"The final default radio wins")
	set("r1","checked",true);assert(get("r1","checked") and not get("r2","checked"))
	local movedRadio=bridge.Document.Get("createElement")({"input"}).DOMNode
	set(movedRadio,"type","radio");set(movedRadio,"name",node("r1").Attributes.name);set(movedRadio,"checked",true)
	call(node("r1").Parent,"prepend",wrap(movedRadio));assert(get(movedRadio,"checked")and not get("r1","checked"),"An inserted checked radio wins even before an existing checked sibling")
	call(movedRadio,"remove");set("r1","checked",true)
	assert(get("box","disabled")==false and get("disabled","disabled")==false and byNode[node("disabled")].Disabled and not byNode[node("exempt")].Disabled,"disabled reflects the own attribute while native effective state includes fieldsets")
	local fieldset=node("disabled").Parent;set(fieldset,"disabled",false);assert(not byNode[node("disabled")].Disabled)
	set(fieldset,"disabled",true);assert(byNode[node("disabled")].Disabled and not byNode[node("exempt")].Disabled)
	set("text","readOnly",true);assert(get("text","readOnly") and not get("text","willValidate"));set("text","readOnly",false)
	local newInput=bridge.Document.Get("createElement")({"input"}).DOMNode
	set(newInput,"defaultValue","default");set(newInput,"value","current");set(newInput,"type","checkbox")
	assert(get(newInput,"value")=="current" and get(newInput,"defaultValue")=="current")
	set(newInput,"type","text");assert(get(newInput,"value")=="current" and not bridge.Controls:State(newInput).DOMDirtyValue)
	set(newInput,"defaultValue","fresh");assert(get(newInput,"value")=="fresh","Returning to value mode clears the dirty value flag")
	set(newInput,"type","range");set(newInput,"value","50");set(newInput,"max","10");assert(get(newInput,"value")=="10","Range constraint changes sanitize the current value")
	set("box","indeterminate",true);assert(get("box","indeterminate") and byNode[node("box")].Indeterminate)
	set("area","value","edited\r\nline");set("area","defaultValue","default area")
	assert(get("area","value")=="edited\nline" and get("area","textContent")=="default area")
	local freshArea=bridge.Document.Get("createElement")({"textarea"}).DOMNode
	set(freshArea,"textContent","\nline");assert(get(freshArea,"value")=="\nline" and get(freshArea,"defaultValue")=="\nline")
	set(freshArea,"defaultValue",VM.Null);assert(get(freshArea,"value")=="null")
	local cloned=call("text","cloneNode").DOMNode
	assert(get(cloned,"value")=="" and get(cloned,"defaultValue")=="later default" and bridge.Controls:State(cloned).DOMDirtyValue)
	local cloneBox=call("box","cloneNode").DOMNode;assert(not get(cloneBox,"checked") and get(cloneBox,"defaultChecked") and get(cloneBox,"indeterminate"))
	local options=get("select","options");assert(options==get("select","options") and options.Get("length")==2 and get("select","selectedIndex")==1 and get("o2","selected"))
	set("select","value","a");assert(get("o1","selected") and not get("o2","selected") and get("select","selectedIndex")==0)
	set("select","value","missing");assert(get("select","selectedIndex")==-1 and get("select","value")=="" and get("select","selectedOptions").Get("length")==0)
	set("select","selectedIndex",1);set("o1","selected",true);assert(get("select","value")=="a" and not get("o2","selected"))
	set("o1","defaultSelected",false);set("o1","defaultSelected",true);assert(get("o1","selected"),"A dirty option ignores its default selectedness")
	set("o1","value","changed");assert(get("select","value")=="changed" and byNode[node("select")].Value=="changed")
	assert(get("multi","selectedOptions").Get("length")==2)
	set("m1","selected",false);assert(get("multi","selectedOptions").Get("length")==1 and get("multi","value")=="B")
	set("multi","selectedIndex",0);assert(get("m1","selected") and not get("m2","selected"),"selectedIndex clears other choices even in multiple selects")
	local clonedSelect=call("select","cloneNode",true).DOMNode
	assert(get(clonedSelect,"selectedIndex")==1,"Select clones reset selectedness from content attributes")
	local dirtyOption=bridge.Document.Get("createElement")({"option"}).DOMNode;set(dirtyOption,"selected",true)
	local cloneOption=call(dirtyOption,"cloneNode").DOMNode;assert(not get(cloneOption,"selected"),"Option cloning copies attributes without copying dirty current selectedness")
	local newSelect=bridge.Document.Get("createElement")({"select"}).DOMNode
	local choice1=bridge.Document.Get("createElement")({"option"}).DOMNode
	local choice2=bridge.Document.Get("createElement")({"option"}).DOMNode
	set(choice1,"value","first");set(choice2,"value","second");set(choice2,"selected",true)
	call(newSelect,"append",wrap(choice1),wrap(choice2));assert(get(newSelect,"selectedIndex")==1 and get(newSelect,"value")=="second","A detached option retains selectedness when inserted into a new select")
	call(newSelect,"prepend",wrap(choice2));assert(get(newSelect,"selectedIndex")==0 and get(newSelect,"value")=="second","Selectedness follows option identity during reorder")
	call(choice2,"remove");assert(get(choice2,"selected") and get(newSelect,"selectedIndex")==0,"Removing a selected option retains its state and selects the surviving first option")
	call("text","focus");assert(focus==node("text"));call("text","blur");assert(focus==nil)
	local clickState=nil;local cancelClick=events:On(node("box"),"click",function(e)clickState=get("box","checked");e:PreventDefault()end)
	call("box","click");assert(clickState==true and not get("box","checked"),"Click preactivation and rollback use the native model");cancelClick:Disconnect()
	call("box","click");assert(get("box","checked"))
	local validity=get("text","validity");assert(validity==get("text","validity") and validity.Get("valueMissing"))
	local invalidCount,submitCount=0,0
	events:On(node("text"),"invalid",function(e)invalidCount+=1;assert(not e.Bubbles and e.Cancelable)end)
	events:On(node("f"),"submit",function(e)submitCount+=1;assert(e.Data.Submitter==node("submit") or e.Data.Submitter==nil);e:PreventDefault()end)
	call("f","requestSubmit",wrap("submit"));assert(invalidCount==1 and submitCount==0)
	set("text","value","ready");assert(validity.Get("valid"));call("f","requestSubmit",wrap("submit"));assert(submitCount==1)
	call("text","setCustomValidity","Choose another value");assert(not call("text","checkValidity") and get("text","validationMessage")=="Choose another value")
	assert(get(call("text","cloneNode").DOMNode,"validationMessage")=="","Cloning copies value and dirty flags, without copying custom validity")
	call("f","requestSubmit",wrap("submit"));assert(submitCount==1);call("text","setCustomValidity","")
	expectError(function()call("f","requestSubmit",wrap("text"))end,"TypeError")
	expectError(function()call("f","requestSubmit",wrap("foreign"))end,"NotFoundError")
	expectError(function()set("text","form",VM.Null)end,"TypeError");set("text","form",VM.Null,false);assert(get("text","form")==wrap("f"))
	set("number","value","3");assert(get("number","validity").Get("stepMismatch"));set("number","value","20");assert(get("number","validity").Get("rangeOverflow"));set("number","value","bad");assert(get("number","value")=="")
	set("email","value","bad");assert(get("email","validity").Get("typeMismatch"))
	local cancelReset=events:On(node("f"),"reset",function(e)e:PreventDefault()end)
	call("f","reset");assert(get("text","value")=="ready" and bridge.Controls:State(node("text")).DOMDirtyValue);cancelReset:Disconnect()
	call("f","reset");assert(get("text","value")=="later default" and get("area","value")=="default area" and not bridge.Controls:State(node("text")).DOMDirtyValue)
	set("text","defaultValue","clean default");assert(get("text","value")=="clean default")
	local ok,failure=pcall(function()vm:Run([[const text=document.getElementById('text');text.value='JavaScript';text.defaultValue='reset JS';if(text.value!=='JavaScript'||text.form!==document.getElementById('f'))throw new Error('control JS bridge');]])end)
	assert(ok,VM.string(VM.exceptionValue(failure)))
	local retained=get("text","validity");bridge:Destroy();assert(not pcall(function()retained.Get("valid")end));model:Destroy();events:Destroy()
	print("JavaScript DOM controls: native current/default state, dirty flags, cloning, radio/select identity, activation, cancellation and validation passed")
end
