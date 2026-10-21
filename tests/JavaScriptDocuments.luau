--!strict
return function(Parser,Node,Runtime,Events)
	local doc=Parser.parseDocument('<!doctype html><html><head><title>Primary</title></head><body><main id="source"></main><aside id="target"></aside></body></html>')
	local changes={};local events=Events.new(error)
	local realm=Runtime.new(doc,{URL="https://example.test/path/index.html",Events=events,ControlAdapter={},Schedule=function()end,
		Changed=function(node,kind)table.insert(changes,{node,kind})end})
	local function run(source)
		realm:Run(source);assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,"\n"))
	end
	run([=[
function check(value,message){if(!value)throw new Error(message);}
check(document.doctype.name==='html'&&document.doctype.nodeType===10&&document.firstChild===document.doctype,'real primary doctype child');
check(document.compatMode==='CSS1Compat'&&document.contentType==='text/html'&&document.title==='Primary','document metadata');
const implementation=document.implementation;
const detached=implementation.createHTMLDocument('  Detached\n title  ');
check(detached.defaultView===null&&detached.location===null&&detached.URL==='about:blank'&&detached.compatMode==='CSS1Compat','detached window/origin');
check(detached.title==='Detached title'&&detached.doctype.ownerDocument===detached&&detached.documentElement.isConnected,'detached title/owner/connection');
const detachedBody=detached.body;
const editor=detached.createElement('input');editor.defaultValue='default';editor.value='typed';editor.id='retained';editor.expando={token:17};
detached.body.append(editor);
const adopted=document.adoptNode(editor);
check(adopted===editor&&editor.ownerDocument===document&&editor.parentNode===null&&!editor.isConnected,'adopt wrapper identity/owner');
document.getElementById('source').append(editor);
check(editor.value==='typed'&&editor.defaultValue==='default'&&editor.expando.token===17&&editor.isConnected,'adopt retains current control/expandos');
const imported=detached.importNode(editor,true);
check(imported!==editor&&imported.ownerDocument===detached&&imported.value==='typed'&&imported.expando===undefined,'import clone current value/no expando');
detached.title='New';check(detached.title==='New'&&detached.head.firstChild.textContent==='New','document title mutation');
const newBody=detached.createElement('body');detached.body=newBody;
check(detached.body===newBody&&detachedBody.parentNode===null,'document body replacement');
const fragment=detached.createDocumentFragment();const template=detached.createElement('template');template.innerHTML='<b>inside</b>';fragment.append(template);
document.adoptNode(fragment);
check(fragment.ownerDocument===document&&template.ownerDocument===document&&template.content.ownerDocument!==document&&template.content.firstChild.ownerDocument===template.content.ownerDocument&&template.content.ownerDocument===document.createElement('template').content.ownerDocument,'inclusive template adoption into shared inert contents document');
const shadowHost=detached.createElement('div');const shadow=shadowHost.attachShadow({mode:'open'});const shadowChild=detached.createElement('span');shadow.append(shadowChild);
document.adoptNode(shadowHost);check(shadow.ownerDocument===document&&shadowChild.ownerDocument===document,'inclusive shadow adoption');
const clonedDocument=detached.cloneNode(true);check(clonedDocument!==detached&&clonedDocument.defaultView===null&&clonedDocument.body.ownerDocument===clonedDocument&&clonedDocument.doctype!==detached.doctype,'document deep clone');
let illegal=0;try{document.append(document.createElement('a'),document.createElement('b'));}catch(e){if(e.name==='HierarchyRequestError')illegal++;}
try{document.adoptNode(document);}catch(e){if(e.name==='NotSupportedError')illegal++;}
try{document.adoptNode(shadow);}catch(e){if(e.name==='HierarchyRequestError')illegal++;}
check(illegal===3&&document.documentElement.tagName==='HTML','document errors/atomicity');
]=])
	run([=[
const namespace='urn:example',xml=implementation.createDocument(namespace,'p:Root',null);
check(xml instanceof XMLDocument&&xml.contentType==='application/xml'&&xml.documentElement.tagName==='p:Root'&&xml.documentElement.localName==='Root'&&xml.documentElement.prefix==='p'&&xml.documentElement.namespaceURI===namespace,'XML identity/qualified names');
const exact=xml.createElement('MiXeD');xml.documentElement.append(exact);
check(exact.tagName==='MiXeD'&&exact.namespaceURI===null&&xml.getElementsByTagName('mixed').length===0&&xml.getElementsByTagName('MiXeD')[0]===exact,'XML case/no namespace');
const cdata=xml.createCDATASection('a<b&c'),pi=xml.createProcessingInstruction('target','note');exact.append(cdata,pi);
check(cdata.nodeType===4&&pi.nodeType===7&&cdata.textContent==='a<b&c'&&pi.target==='target'&&exact.textContent==='a<b&c','CDATA/PI CharacterData');
cdata.appendData('!');check(cdata.data==='a<b&c!'&&pi.cloneNode().target==='target','CDATA/PI clone/mutation');
const parser=new DOMParser();const parsed=parser.parseFromString('<r xmlns="urn:r" xmlns:p="urn:p"><p:C p:Flag="one"><![CDATA[a<b]]></p:C></r>','application/xml');
check(parsed.documentElement.namespaceURI==='urn:r'&&parsed.getElementsByTagNameNS('urn:p','C').length===1&&parsed.getElementsByTagNameNS('urn:p','C')[0].getAttributeNS('urn:p','Flag')==='one','XML parser namespaces/attribute identity');
check(parsed.getElementsByTagNameNS('urn:p','C')[0].firstChild.nodeType===4&&parser.parseFromString('<r><bad></r>','application/xml').getElementsByTagName('parsererror').length===1,'XML malformed/CDATAs');
const parsedHTML=parser.parseFromString('<!doctype html><title>x</title><p>visible<script>window.parsedRan=1;</script>','text/html');
check(parsedHTML.doctype.name==='html'&&parsedHTML.title==='x'&&parsedHTML.body.querySelector('p')!==null&&window.parsedRan===undefined,'inert HTML parser');
check(parsedHTML.URL===document.URL&&parsed.URL===document.URL&&parsedHTML.defaultView===null,'DOMParser inherits its relevant document URL without a browsing context');
check(parser.parseFromString('<p>quirks','text/html').compatMode==='BackCompat','quirks parser mode');
]=])
	run([=[
const anchor=document.createElement('a');anchor.href='../project';anchor.target='_blank';anchor.download='report';anchor.lang='de';anchor.dir='RTL';anchor.translate=false;
check(anchor.href==='https://example.test/project'&&anchor.getAttribute('href')==='../project'&&anchor.target==='_blank'&&anchor.lang==='de'&&anchor.dir==='rtl'&&!anchor.translate,'common/URL reflected attributes');
const titleDescriptor=Object.getOwnPropertyDescriptor(HTMLElement.prototype,'title');titleDescriptor.set.call(anchor,'Reflected');
check(titleDescriptor.get.call(anchor)==='Reflected'&&anchor.getAttribute('title')==='Reflected'&&titleDescriptor.enumerable&&typeof Object.getOwnPropertyDescriptor(Document.prototype,'body').set==='function','native interface descriptors');
const quote=document.createElement('q'),blockquote=document.createElement('blockquote');
const cite=Object.getOwnPropertyDescriptor(HTMLQuoteElement.prototype,'cite');cite.set.call(quote,'../cite');cite.set.call(blockquote,'../cite');
check(cite.get.call(quote)==='https://example.test/cite'&&cite.get.call(blockquote)==='https://example.test/cite','shared HTML interface receiver tags');
anchor.contentEditable='plaintext-only';anchor.inputMode='NUMERIC';anchor.enterKeyHint='SEND';check(anchor.contentEditable==='plaintext-only'&&anchor.inputMode==='numeric'&&anchor.enterKeyHint==='send','editing reflections');
const attribute=document.createAttribute('DATA-Value');attribute.value='one';anchor.setAttributeNode(attribute);
check(attribute.ownerElement===anchor&&attribute.ownerDocument===document&&attribute.name==='data-value'&&attribute.nodeType===2&&anchor.attributes.getNamedItem('data-value')===attribute,'Attr identity/owner');
anchor.setAttribute('data-value','two');check(attribute.value==='two','retained Attr updates');
attribute.value='three';check(anchor.getAttribute('data-value')==='three','Attr setter mutates element');
anchor.removeAttributeNode(attribute);check(attribute.ownerElement===null&&attribute.value==='three'&&anchor.getAttribute('data-value')===null,'removed Attr retains value');
anchor.setAttributeNS('urn:a','a:key','namespaced');const nsAttr=anchor.getAttributeNodeNS('urn:a','key');
check(nsAttr.namespaceURI==='urn:a'&&nsAttr.localName==='key'&&nsAttr.prefix==='a'&&anchor.attributes.getNamedItemNS('urn:a','key')===nsAttr,'namespaced Attr');
anchor.removeAttributeNS('urn:a','key');check(nsAttr.ownerElement===null,'namespace removal updates Attr');
let attrError='';try{document.createElement('div').setAttributeNode(anchor.getAttributeNode('href'));}catch(e){attrError=e.name;}
check(attrError==='InUseAttributeError','owned Attr cannot be stolen');
const named=document.createElement('div');named.innerHTML='<i id="one" name="alias"></i><i id="two"></i><i id="one" name="item"></i>';
const collection=named.children;
check(Object.keys(collection).join(',')==='0,1,2'&&Object.getOwnPropertyNames(collection).join(',')==='0,1,2,one,alias,two'&&collection.alias===collection[0],'legacy collection name enumeration');
check(Object.getOwnPropertyDescriptor(collection,'alias').enumerable===false&&Object.getOwnPropertyDescriptor(collection,'0').writable===false,'legacy collection descriptors');
named.firstChild.remove();check(collection.one===collection[1]&&collection.alias===undefined&&Object.keys(collection).join(',')==='0,1','live name ordering');
]=])
	run([=[
let listenerCalls=0;editor.addEventListener('click',()=>listenerCalls++);document.getElementById('target').moveBefore(editor,null);editor.click();
check(listenerCalls===1&&editor.value==='typed'&&editor.parentNode.id==='target','state-preserving move listeners/control');
const table=document.createElement('table');table.innerHTML='<colgroup><col span="2"></colgroup><thead><tr><th>Head</th></tr></thead><tbody><tr><td rowspan="0"><input value="start"></td><td>Cell</td></tr></tbody><tfoot><tr><td>Foot</td></tr></tfoot>';
document.body.append(table);const bodyRow=table.tBodies[0].rows[0],liveRows=table.rows,tableControl=bodyRow.cells[0].firstChild;tableControl.value='retained';
const inserted=table.insertRow(1);inserted.insertCell().colSpan=2;inserted.insertCell().textContent='Added';
table.tFoot.append(bodyRow);check(liveRows.length===4&&liveRows[0]===table.tHead.rows[0]&&liveRows[3]===bodyRow&&tableControl.value==='retained'&&bodyRow.cells[0].rowSpan===0,'combined table sections/spans/retained input');
table.deleteRow(1);check(liveRows.length===3&&tableControl.value==='retained','table deletion live rows');
]=])
	assert(#realm.Diagnostics==0);realm:Destroy();events:Destroy()
	-- Genuine independently mounted document bridges exercise source removal,
	-- native setter routing, current control state and author wrapper retention.
	local sourceEvents,targetEvents=Events.new(error),Events.new(error)
	local source=Runtime.new(Parser.parseDocument('<html><body><input id="foreign" value="default"></body></html>'),{URL="https://example.test/source",Events=sourceEvents,ControlAdapter={},Schedule=function()end})
	local target=Runtime.new(Parser.parseDocument('<html><body></body></html>'),{URL="https://example.test/target",Events=targetEvents,ControlAdapter={},Schedule=function()end})
	source:Run("const foreign=document.getElementById('foreign');foreign.value='before';foreign.expando=9;")
	local foreign=source.DOM.Document.Get("getElementById")({"foreign"})
	target.VM.Global.Bindings.foreign={Value=foreign}
	target:Run("const beforeOwner=foreign.ownerDocument;document.body.append(foreign);foreign.value='after';if(foreign.ownerDocument!==document||foreign.value!=='after'||foreign.expando!==9)throw new Error('cross-realm adoption');")
	assert(#source.Diagnostics==0 and #target.Diagnostics==0,table.concat(source.Diagnostics,"\n")..table.concat(target.Diagnostics,"\n"))
	assert(foreign==target.DOM.Document.Get("getElementById")({"foreign"}),"Original author wrapper is the destination's canonical wrapper")
	source:Run("const selection=document.createElement('select');selection.multiple=true;selection.innerHTML='<option>A</option><option selected>B</option><option>C</option>';document.body.append(selection);selection.options[0].selected=true;selection.options[1].selected=false;selection.options[2].selected=true;")
	local selection=source.VM.Global.Bindings.selection.Value
	target.VM.Global.Bindings.selection={Value=selection}
	target:Run("document.body.append(selection);if(!selection.options[0].selected||selection.options[1].selected||!selection.options[2].selected)throw new Error('adoption option state');selection.options[0].defaultSelected=true;selection.options[2].defaultSelected=false;if(!selection.options[2].selected)throw new Error('adoption option dirty flag');const copy=selection.cloneNode(true);if(!copy.options[0].selected||!copy.options[1].selected||copy.options[2].selected)throw new Error('clone option attribute state');copy.options[2].defaultSelected=true;copy.options[2].defaultSelected=false;if(copy.options[2].selected)throw new Error('clone option starts clean');")
	assert(#source.Diagnostics==0 and #target.Diagnostics==0,table.concat(source.Diagnostics,"\n")..table.concat(target.Diagnostics,"\n"))
	source:Destroy();target:Destroy();sourceEvents:Destroy();targetEvents:Destroy()
	print("R02 document/HTML interfaces: DOMImplementation, XML/HTML parser, namespaces/Attr, doctype/quirks, cross-document identity/controls, named collections, table combinations and preserving moves passed")
end
