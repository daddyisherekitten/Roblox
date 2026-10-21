--!strict
-- Browser-shaped tree and text semantics, independent of GUI test doubles.
return function(Parser,Node,DOM,VM,Events)
	local document=Parser.parseDocument('<!doctype html><html><head></head><body><main id="scope"><div id="a" class="item one">A</div><div id="b" class="item two">B</div><div id="c">C</div></main><aside id="other"></aside></body></html>')
	local events=Events.new(error);local changed={};local guarded=nil;local vm
	local host={Events=events,Window={},ReadyState="complete",
		Changed=function(node,kind,key)table.insert(changed,{Node=node,Kind=kind,Key=key})end,
		ValidateStructure=function(_,child)assert(child~=guarded,"Host rejected this node")end,
		Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,
		Get=function(object,key)return vm.Get(object,key)end,
		GetControl=function()return ""end,SetControl=function()end,Click=function()end}
	local bridge=DOM.new(document,host)
	local function wrap(node)return bridge.Wrap(node)end
	local function get(node,key)return wrap(node).Get(key)end
	local function call(node,key,...)return get(node,key)({...})end
	local function set(node,key,value)wrap(node).Set(key,value)end
	local function create(name)return bridge.Document.Get("createElement")({name}).DOMNode end
	local function expectError(fn,name)
		local ok,value=pcall(fn);assert(not ok,"Expected "..name)
		assert(VM.exceptionValue(value).Get("name")==name,"Expected DOM error "..name..", got "..VM.string(VM.exceptionValue(value)))
	end
	local scope=Node.findById(document,"scope");local a=Node.findById(document,"a");local b=Node.findById(document,"b");local c=Node.findById(document,"c");local other=Node.findById(document,"other")
	assert(call(a,"getAttributeNames").Items[1]=="id" and call(a,"getAttributeNames").Items[2]=="class","Parsed HTML attributes keep source order")
	vm=VM.new({document=bridge.Document,scope=wrap(scope),a=wrap(a),b=wrap(b),c=wrap(c)})
	bridge.AttachVM(vm)
	assert(call(a,"matches",".one") and call(a,"closest","main")==wrap(scope))
	assert(call(a,"closest",":scope")==wrap(a) and not call(a,"matches",":scope > div"))
	assert(call(scope,"querySelector",":scope > .one")==wrap(a))
	assert(call(document,"querySelector",":scope").DOMNode.Name=="html")
	local live=call(scope,"getElementsByClassName","item");local static=call(scope,"querySelectorAll",".item")
	assert(live.Get("length")==2 and static.Get("length")==2 and live.Get("namedItem")({"a"})==wrap(a))
	assert(live.Get("0")==wrap(a) and live.Get("01")==VM.Undefined and static.Get("item")({99})==VM.Null)
	set(c,"className","item two");assert(live.Get("length")==3 and static.Get("length")==2,"Live and static collections differ after a mutation")
	call(scope,"append",wrap(a),wrap(b),wrap(a))
	assert(scope.Children[1]==c and scope.Children[2]==b and scope.Children[3]==a,"Repeated nodes keep their final occurrence")
	call(a,"before",wrap(a));assert(scope.Children[3]==a)
	call(b,"after",wrap(a),wrap(b));assert(scope.Children[2]==a and scope.Children[3]==b)
	call(scope,"prepend",wrap(b),"start");assert(scope.Children[1]==b and scope.Children[2].Text=="start" and scope.Children[3]==c)
	assert(call(scope,"contains",wrap(a)) and call(a,"contains",wrap(a)) and not call(a,"contains",VM.Null))
	assert(call(scope,"compareDocumentPosition",wrap(a))==20 and call(a,"compareDocumentPosition",wrap(scope))==10)
	assert(call(b,"compareDocumentPosition",wrap(a))==4 and call(a,"compareDocumentPosition",wrap(b))==2)
	assert(call(a,"getRootNode")==bridge.Document and get(b,"nextElementSibling")==wrap(c) and get(c,"previousElementSibling")==wrap(b))
	assert(get(a,"nodeName")=="DIV" and get(a,"nodeValue")==VM.Null)
	local fragment=Node.documentFragment();local x=create("p");local y=create("p");Node.append(fragment,x);Node.append(fragment,y)
	call(scope,"append",wrap(fragment),wrap(x),wrap(fragment))
	assert(scope.Children[#scope.Children-1]==y and scope.Children[#scope.Children]==x and #fragment.Children==0,"Reusing a consumed fragment must not reinsert its old children")
	local bulk=create('div');local bulkNodes,bulkArguments={},{}
	for index=1,256 do local child=create('i');bulkNodes[index]=child;bulkArguments[index]=wrap(child)end
	for _,index in {128,1,256,128}do table.insert(bulkArguments,wrap(bulkNodes[index]))end
	call(bulk,'append',table.unpack(bulkArguments))
	assert(#bulk.Children==256 and bulk.Children[254]==bulkNodes[1]and bulk.Children[255]==bulkNodes[256]and bulk.Children[256]==bulkNodes[128],
		'A large argument batch retains each node once at its final occurrence')
	local expected=1
	for _,child in bulk.Children do
		if expected==1 or expected==128 then expected+=1 end
		if expected>=256 then break end
		assert(child==bulkNodes[expected],'Unique leading arguments preserve order after duplicate compaction');expected+=1
	end
	local fragmentOne,fragmentTwo=Node.documentFragment(),Node.documentFragment()
	local f1,f2,f3,f4=create('u'),create('u'),create('u'),create('u')
	Node.append(fragmentOne,f1);Node.append(fragmentOne,f2);Node.append(fragmentTwo,f3);Node.append(fragmentTwo,f4)
	call(bulk,'replaceChildren',wrap(f2),wrap(fragmentOne),wrap(f1),wrap(fragmentTwo),wrap(f2),wrap(fragmentOne),wrap(f3))
	assert(#bulk.Children==4 and bulk.Children[1]==f1 and bulk.Children[2]==f4 and bulk.Children[3]==f2 and bulk.Children[4]==f3
		and #fragmentOne.Children==0 and #fragmentTwo.Children==0,'Repeated arguments and consumed fragments preserve the temporary-fragment move order')
	call(scope,"replaceChildren",wrap(b),wrap(a))
	assert(#scope.Children==2 and scope.Children[1]==b and scope.Children[2]==a and not get(c,"isConnected"))
	local returned=call(scope,"replaceChild",wrap(b),wrap(a))
	assert(returned==wrap(a) and #scope.Children==1 and scope.Children[1]==b and a.Parent==nil)
	call(b,"replaceWith",wrap(a),"tail");assert(scope.Children[1]==a and scope.Children[2].Text=="tail")
	call(a,"before",wrap(b));assert(scope.Children[1]==b and scope.Children[2]==a)
	local original=table.clone(scope.Children)
	expectError(function()call(a,"append",wrap(b),wrap(scope))end,"HierarchyRequestError")
	assert(b.Parent==scope and #scope.Children==#original and scope.Children[1]==original[1],"Cycle checks precede every move")
	expectError(function()call(other,"insertBefore",wrap(a),wrap(b))end,"NotFoundError")
	assert(a.Parent==scope,"A bad reference does not detach the incoming node")
	expectError(function()call(fragment,"appendChild",wrap(fragment))end,"HierarchyRequestError")
	guarded=a
	assert(not pcall(function()call(other,"replaceChildren",wrap(b),wrap(a))end))
	assert(b.Parent==scope and a.Parent==scope and #other.Children==0,"Renderer rejection cannot partially commit the first node")
	guarded=nil
	local tokens=get(a,"classList");set(a,"className"," one  two one three ")
	assert(tokens.Get("length")==3 and tokens.Get("item")({0})=="one" and tokens.Get("item")({99})==VM.Null)
	assert(tokens.Get("toggle")({"one",true}) and a.Attributes.class==" one  two one three ","A forced no-op toggle preserves attribute whitespace")
	expectError(function()tokens.Get("add")({"valid","bad token"})end,"InvalidCharacterError")
	assert(a.Attributes.class==" one  two one three ","Token validation precedes class changes")
	assert(tokens.Get("replace")({"three","one"}) and a.Attributes.class=="one two")
	assert(tokens.Get("replace")({"one","two"}) and a.Attributes.class=="two")
	assert(not tokens.Get("replace")({"missing","x"}))
	expectError(function()tokens.Get("contains")({""})end,"SyntaxError")
	expectError(function()tokens.Get("supports")({"item"})end,"TypeError")
	local emptyClass=create("div");local emptyTokens=get(emptyClass,"classList")
	emptyTokens.Get("add")({});emptyTokens.Get("remove")({"missing"});assert(emptyClass.Attributes.class==nil,"Empty classList mutations do not create an absent class attribute")
	call(emptyClass,"setAttribute","data-z",1);call(emptyClass,"setAttribute","data-a",2)
	assert(call(emptyClass,"getAttributeNames").Items[1]=="data-z" and get(emptyClass,"dataset").Keys()[1]=="z","Dynamic attributes retain insertion order")
	assert(get(a,"append")==get(a,"append"),"Repeated method reads preserve identity")
	expectError(function()get(a,"append")({"bad"},VM.Undefined)end,"TypeError")
	get(a,"append")({"borrowed"},wrap(emptyClass));assert(emptyClass.Children[1].Text=="borrowed","Borrowed DOM methods use the receiver")
	local dataset=get(a,"dataset");dataset.Set("userName","Ada");dataset.Set("count",3);dataset.Set("nilValue",VM.Null)
	assert(a.Attributes["data-user-name"]=="Ada" and dataset.Get("count")=="3" and dataset.Get("nilValue")=="null")
	assert(dataset.Get("user-name")==VM.Undefined and dataset.Has("userName") and dataset.HasOwn("userName"))
	dataset.Delete("user-name");assert(dataset.Get("userName")=="Ada","Deleting an unsupported dataset key does not remove a different supported property")
	dataset.Delete("userName");assert(dataset.Get("userName")==VM.Undefined)
	expectError(function()dataset.Set("bad-key","x")end,"SyntaxError")
	local text=Node.text("A😀B");call(other,"appendChild",wrap(text))
	assert(get(text,"length")==4 and call(text,"substringData",1,2)=="😀")
	call(text,"replaceData",1,2,"x");assert(text.Text=="AxB")
	call(text,"insertData",1,"😀");assert(text.Text=="A😀xB")
	local suffix=call(text,"splitText",3).DOMNode
	assert(text.Text=="A😀" and suffix.Text=="xB" and other.Children[1]==text and other.Children[2]==suffix)
	assert(get(suffix,"wholeText")=="A😀xB" and get(text,"nextSibling")==wrap(suffix))
	call(other,"append",wrap(Node.text("")),wrap(Node.text("!")))
	call(other,"normalize");assert(#other.Children==1 and other.Children[1]==text and text.Text=="A😀xB!" and suffix.Parent==nil,"normalize retains the first nonempty Text identity")
	expectError(function()call(text,"substringData",99,1)end,"IndexSizeError")
	expectError(function()call(text,"splitText",-1)end,"IndexSizeError")
	local comment=bridge.Document.Get("createComment")({"quiet"}).DOMNode
	set(comment,"data",VM.Null);assert(comment.Text=="" and get(comment,"nodeName")=="#comment" and get(comment,"nodeType")==8)
	set(other,"innerHTML",'<p id="markup" data-note="a&amp;b">A &lt; B<br>tail</p><!--end-->')
	local markup=Node.findById(document,"markup")
	assert(markup.Attributes["data-note"]=="a&b" and Node.textContent(markup)=="A < Btail" and #other.Children==2)
	assert(get(other,"innerHTML"):find('data%-note="a&amp;b"') and get(other,"innerHTML"):find("A &lt; B<br>tail",1,true))
	call(markup,"insertAdjacentText","afterbegin","<plain>")
	assert(markup.Children[1].Text=="<plain>")
	local inserted=create("strong");call(inserted,"append","strong")
	assert(call(markup,"insertAdjacentElement","beforeend",wrap(inserted))==wrap(inserted))
	call(markup,"insertAdjacentHTML","afterend",'<span id="adjacent">next</span>')
	assert(get(markup,"nextElementSibling").DOMNode.Attributes.id=="adjacent")
	set(markup,"outerHTML",'<section id="replacement">replaced</section>')
	assert(markup.Parent==nil and Node.findById(document,"replacement").Parent==other)
	local template=create("template");set(template,"innerHTML",'<span class="inside">template</span>')
	assert(#template.Children==0 and #template.Content.Children==1 and call(template,"querySelector",".inside")==VM.Null)
	assert(call(template.Content,"querySelector",".inside").DOMNode==template.Content.Children[1])
	local shallow=call(template,"cloneNode").DOMNode;local deep=call(template,"cloneNode",true).DOMNode
	assert(#shallow.Content.Children==0 and #deep.Content.Children==1 and deep.Content.Children[1]~=template.Content.Children[1] and deep.Content.Host==deep)
	local div=create("div");set(div,"innerHTML",'<span>clone</span>')
	local cloned=call(div,"cloneNode",true).DOMNode
	assert(call(div,"isEqualNode",wrap(cloned)) and not call(div,"isSameNode",wrap(cloned)))
	call(div,"setAttribute","data-z","z");call(div,"setAttribute","data-a","a")
	local orderedClone=call(div,"cloneNode",true).DOMNode
	assert(get(orderedClone,"outerHTML")==get(div,"outerHTML"),"Cloning preserves dynamic attribute order")
	set(cloned.Children[1],"textContent","changed");assert(not call(div,"isEqualNode",wrap(cloned)))
	local tableNode=create("table");set(tableNode,"innerHTML","<tr><td>cell</td></tr>")
	assert(tableNode.Children[1].Name=="tbody" and tableNode.Children[1].Children[1].Name=="tr")
	set(tableNode,"innerHTML","<td>direct</td>");assert(tableNode.Children[1].Children[1].Name=="tr" and tableNode.Children[1].Children[1].Children[1].Name=="td")
	local tbody=create("tbody");set(tbody,"innerHTML","<td>direct</td>");assert(tbody.Children[1].Name=="tr" and tbody.Children[1].Children[1].Name=="td")
	local textarea=create("textarea");set(textarea,"innerHTML","<b>&amp;</b>");assert(#textarea.Children==1 and textarea.Children[1].Text=="<b>&</b>")
	local inert=create("div");set(inert,"innerHTML",'<template shadowrootmode="open"><span>inert</span></template>')
	assert(inert.Children[1].Name=="template" and inert.Children[1].Content.Children[1].Name=="span" and not inert.InternalShadowRoot,"innerHTML must not attach declarative shadow roots")
	local iteration=create("div");local view=get(iteration,"childNodes");local exhausted=view.Get("values")({})
	assert(exhausted.Get("next")({}).Get("done"))
	call(iteration,"append","a","b");assert(exhausted.Get("next")({}).Get("done"),"An exhausted collection iterator stays done after growth")
	local steps="";view.Get("forEach")({function(args)
		steps..=args[1].Get("data");if args[2]==0 then call(iteration,"append","c") end
	end})
	assert(steps=="ab","Live forEach captures its initial length")
	-- Ordinary JS uses wrapper properties and methods through the VM.
	local succeeded,failure=pcall(function()vm:Run([=[
a.dataset.jsValue = 7;
a.extraState = 12;
scope.append(a, "vm");
const selected = scope.querySelectorAll("div");
let names = "";
selected.forEach(function(node) { names += node.id; });
if (a.dataset.jsValue !== "7" || a.extraState !== 12 || names !== "ba") { throw new Error("DOM VM bridge"); }
const list=scope.childNodes;
if(typeof list[Symbol.iterator]!=="function"||Array.from(list).length!==list.length||list.item!==list.item){throw new Error("DOM iterator identity");}
const tokenList=a.classList;
if([...tokenList].join(' ')!==tokenList.value||tokenList.item!==tokenList.item){throw new Error("Class iterator identity");}
const iterator=list[Symbol.iterator]();if(iterator[Symbol.iterator]()!==iterator){throw new Error("Iterator protocol");}
list[0]=null;tokenList[0]='wrong';if(list[0]===null||tokenList[0]==='wrong'){throw new Error("Read-only collection index");}
const marker=Symbol('data');a.dataset[marker]=false;if(a.dataset[marker]!==false||Object.getOwnPropertySymbols(a.dataset)[0]!==marker){throw new Error("Dataset symbol property");}
let callbacksThrow=0;try{document.createElement('i').childNodes.forEach(null)}catch(e){if(e.name==='TypeError')callbacksThrow++}
try{document.createElement('i').classList.forEach(null)}catch(e){if(e.name==='TypeError')callbacksThrow++}
if(callbacksThrow!==2){throw new Error("Empty collection callback validation");}
]=])end)
	assert(succeeded,VM.string(VM.exceptionValue(failure)))
	assert(a.Attributes["data-js-value"]=="7" and wrap(a)==get(scope,"children").Get("1"))
	bridge:Destroy();events:Destroy();vm:Destroy()
	assert(not pcall(function()dataset.Get("count")end),"Retained dataset wrappers reject access after destruction")
	print("JavaScript DOM expansion: batch identity/atomicity, live queries, class tokens, dataset, UTF-16 CharacterData, fragments and templates passed")
end
