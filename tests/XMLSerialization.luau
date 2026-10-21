--!strict
return function(Parser,Node,Runtime,Events,XML,Markup,XMLParser,fixture,Store)
 local document=Parser.parseDocument('<!doctype html><title>XML serialization</title><body><div id="plain">A &amp; B</div></body>')
 local events=Events.new(error);local realm=Runtime.new(document,{URL='https://example.test/xml',Events=events,ControlAdapter={},Schedule=function()end,MaxSteps=200000})
 assert(realm:Run(fixture.source..'\nconst xmlResults=xmlSerializationChecks();'),table.concat(realm.Diagnostics,'\n'))
 -- Frozen Chromium output stays unchanged. Current normative error checks,
 -- redundant namespace omission, Attr-root and DTD quoting differ explicitly.
 local deltas={
  ['null-namespace-xmlns']='[{"value":"<root xmlns=\\"urn:decl\\"/>"},{"error":"InvalidStateError"},{"value":""}]',
  ['unbound-element-local-colon']='[{"value":"<p:name/>"},{"error":"InvalidStateError"},{"value":""}]',
  ['unbound-attribute-colon']='[{"value":"<root p:name=\\"x\\"/>"},{"error":"InvalidStateError"},{"value":""}]',
  ['xml-comment-invalid']='[{"value":"<root><!--x--y---></root>"},{"error":"InvalidStateError"},{"error":"InvalidStateError"}]',
  ['xml-text-invalid']='[{"value":"<root>x\\u0001y</root>"},{"error":"InvalidStateError"},{"error":"InvalidStateError"}]',
  ['xml-attribute-invalid']='[{"value":"<root data=\\"x\\u0001y\\"/>"},{"error":"InvalidStateError"},{"value":""}]',
  ['xml-pi-invalid-data']='[{"value":"<root><?target bad?>data?></root>"},{"error":"InvalidStateError"},{"error":"InvalidStateError"}]',
  ['xml-attr-root']='[{"value":""},{},{}]',
  ['xmlns-reserved-value']='[{"value":"<root xmlns:p=\\"http://www.w3.org/2000/xmlns/\\"/>"},{"error":"InvalidStateError"},{"value":""}]',
  ['xmlns-xml-redundant']='[{"value":"<root/>"},{"value":"<root/>"},{"value":""}]',
  ['xmlns-prefix-undeclare']='[{"value":"<root xmlns:p=\\"\\"/>"},{"error":"InvalidStateError"},{"value":""}]',
  ['xmlns-default-reset']='[{"value":"<root xmlns=\\"urn:a\\"><child xmlns=\\"\\"/></root>"},{"value":"<root xmlns=\\"urn:a\\"><child xmlns=\\"\\"/></root>"},{"value":"<child/>"}]',
  ['xmlns-xml-prefix-rebind']='[{"value":"<root xmlns:xml=\\"urn:other\\"/>"},{"error":"InvalidStateError"},{"value":""}]',
  ['xmlns-xmlns-prefix-rebind']='[{"value":"<root xmlns:xmlns=\\"urn:other\\"/>"},{"error":"InvalidStateError"},{"value":""}]',
  ['xmlns-element-namespace']='[{"value":"<xmlns xmlns=\\"http://www.w3.org/2000/xmlns/\\"/>"},{"error":"InvalidStateError"},{"value":""}]',
  ['sibling-prefix-redundancy']='[{"value":"<root xmlns:p=\\"urn:a\\"><p:child/><p:child/></root>"},{"value":"<root xmlns:p=\\"urn:a\\"><p:child/><p:child/></root>"},{"value":"<p:child xmlns:p=\\"urn:a\\"/><p:child xmlns:p=\\"urn:a\\"/>"}]',
  ['doctype-public-system']='[{"value":"<!DOCTYPE root PUBLIC \\"a b\\" \'x\\"y\'>"},{},{}]',
  ['doctype-both-quotes']='[{"value":"<!DOCTYPE root SYSTEM \'x\\"y\'z\'>"},{},{}]',
  ['strict-error-atomicity']='[{"error":"InvalidStateError"},1,true,"p","p"]',
  ['pi-xml-target']='[{"value":"<root><?XmL v?></root>"},{"error":"InvalidStateError"},{"error":"InvalidStateError"}]',
 }
 local nativeCount,deltaCount=0,0
 for index,record in fixture.records do
  assert(realm:Run('window.xmlActual=JSON.stringify(xmlResults['..tostring(index-1)..'].value);'),table.concat(realm.Diagnostics,'\n'))
  local actual=realm.Window.Get('xmlActual');local expected=deltas[record.name]or record.json
  assert(actual==expected,record.name..'\nexpected '..expected..'\nactual '..tostring(actual))
  if deltas[record.name]then deltaCount+=1 else nativeCount+=1 end
 end
 -- Prefix fixup round-trips expanded names while preserving author Attr identity.
 assert(realm:Run([=[
 const parsed=new DOMParser().parseFromString('<r xmlns="urn:r" xmlns:p="urn:a"><p:item p:flag="one"/></r>','application/xml');
 const item=parsed.documentElement.firstChild;item.setAttributeNS('urn:b','p:other','two');
 const original=item.getAttributeNodeNS('urn:b','other'),originalPrefix=original.prefix;
 const output=new XMLSerializer().serializeToString(parsed);
 const round=new DOMParser().parseFromString(output,'application/xml');
 if(round.documentElement.namespaceURI!=='urn:r'||round.documentElement.firstChild.namespaceURI!=='urn:a'||round.documentElement.firstChild.getAttributeNS('urn:b','other')!=='two'||item.getAttributeNodeNS('urn:b','other')!==original||original.prefix!==originalPrefix)throw new Error('XML expanded-name roundtrip/Attr retention');
 const html=document.getElementById('plain');if(html.outerHTML!=='<div id="plain">A &amp; B</div>')throw new Error('HTML serializer changed');
 const before=html.firstChild;html.textContent='changed';if(html.innerHTML!=='changed'||html===before)throw new Error('HTML mutation route');
 const strict=document.implementation.createDocument(null,'root',null);strict.documentElement.append(strict.createComment('bad--comment'));
 for(const property of ['innerHTML','outerHTML']){let caught=false;try{strict.documentElement[property];}catch(error){caught=error instanceof DOMException&&error.name==='InvalidStateError'&&error.code===11&&Object.prototype.toString.call(error)==='[object DOMException]';}if(!caught)throw new Error('Actual XML DOMException '+property);}
 ]=]),table.concat(realm.Diagnostics,'\n'))
 local foreignEvents=Events.new(error);local foreign=Runtime.new(Parser.parseDocument('<!doctype html><title>Foreign</title><body></body>'),{URL='https://example.test/foreign',Events=foreignEvents,Schedule=function()end})
 assert(foreign:Run('window.foreignSerializer=XMLSerializer;window.foreignTypeError=TypeError;const fd=document.implementation.createDocument(null,"root",null);window.foreignNode=fd.createElementNS("urn:a","p:item");foreignNode.setAttributeNS("urn:b","p:flag","x");'))
 realm.VM.Global.Bindings.ForeignSerializer={Value=foreign.Window.Get('foreignSerializer')};realm.VM.Global.Bindings.foreignNode={Value=foreign.Window.Get('foreignNode')}
 assert(realm:Run('window.xmlCross=JSON.stringify(xmlCrossRealmChecks(ForeignSerializer,foreignNode));'),table.concat(realm.Diagnostics,'\n'))
 assert(realm.Window.Get('xmlCross')==fixture.crossRealmJSON,'Cross-realm native constructor brands/method borrowing/Node identity')
 realm.VM.Global.Bindings.ForeignTypeError={Value=foreign.Window.Get('foreignTypeError')}
 assert(realm:Run('window.xmlCrossErrors=JSON.stringify(xmlCrossRealmErrors(ForeignSerializer,ForeignTypeError));'),table.concat(realm.Diagnostics,'\n'))
 assert(realm.Window.Get('xmlCrossErrors')==fixture.crossRealmErrorsJSON,'Cross-realm XMLSerializer errors '..tostring(realm.Window.Get('xmlCrossErrors'))..' expected '..fixture.crossRealmErrorsJSON)
 foreign:Destroy();foreignEvents:Destroy()
 realm:Destroy();events:Destroy()
 -- Invalid raw renderer data cannot bypass XML 1.0 name/character/expanded
 -- attribute constraints. Serialization never mutates private attribute order.
 local xml=Node.document();xml.IsHTML=false
 local raw=Node.element('root',{first='a',second='b'});raw.NamespaceURI='';raw.OwnerDocument=xml
 raw.AttributeOrder={'first','second'}
 raw.AttributeNamespaces={first={Namespace='urn:x',LocalName='a',Prefix='p'},second={Namespace='urn:x',LocalName='a',Prefix='q'}}
 local before=table.clone(raw.AttributeOrder);assert(not pcall(XML.serialize,raw,false,true),'Duplicate expanded attribute must reject')
 assert(raw.AttributeOrder[1]==before[1]and raw.AttributeOrder[2]==before[2]and raw.Attributes.first=='a'and raw.Attributes.second=='b')
 raw.AttributeNamespaces=nil;raw.Attributes={};raw.AttributeOrder={}
 for _,name in {'1name','a:b',utf8.char(0xd7),utf8.char(0x3000),'a'..utf8.char(0xf0000)}do raw.LocalName=name;assert(not pcall(XML.serialize,raw,false,true),'XML NCName '..name)end
 for _,name in {'a',utf8.char(0xc0),utf8.char(0x3001),utf8.char(0x10000),'a'..utf8.char(0x300)}do raw.LocalName=name;assert(pcall(XML.serialize,raw,false,true),'Valid XML NCName '..name)end
 raw.LocalName='root'
 for _,code in {0,1,11,12,0xd800,0xfffe,0xffff}do
  local value=if code==0xd800 then string.char(237,160,128)else utf8.char(code)
  raw.Children={Node.text(value)};assert(not pcall(XML.serialize,raw,false,true),'XML Char '..tostring(code))
 end
 raw.Children={Node.text('\t\n\r'..utf8.char(0x10000))};assert(pcall(XML.serialize,raw,false,true),'Valid XML character boundaries')
 assert(not pcall(XML.serialize,xml,false,true),'Strict XML document needs root')
 assert(XML.serialize(xml,false,false)=='','Non-strict empty document')
 for _,public in {'tab\t','form\f',utf8.char(0xe4)}do assert(not pcall(XML.serialize,Node.documentType('root',public,''),false,true),'XML public identifier characters')end
 assert(XML.serialize(Node.documentType('root','a\n b','x"y'),false,true)=='<!DOCTYPE root PUBLIC "a\n b" \'x"y\'>','Quote-safe DTD system identifier')
 local combinations=0
 for _,parentURI in {'','urn:a','urn:b'}do for _,childURI in {'','urn:a','urn:b'}do for _,childPrefix in {'','p','q'}do
  if childPrefix~=''and childURI==''then continue end
  for _,attrPrefix in {'','p','q'}do for _,bindingURI in {'urn:a','urn:b'}do
   local parent=Node.element('root',{});parent.NamespaceURI=parentURI;parent.OwnerDocument=xml
   parent.Attributes.declaration=bindingURI;parent.AttributeOrder={'declaration'}
   parent.AttributeNamespaces={declaration={Namespace='http://www.w3.org/2000/xmlns/',Prefix='xmlns',LocalName='p',QualifiedName='xmlns:p'}}
   local child=Node.element('item',{one='a\t\n\r'..utf8.char(160),two='b&<>'});child.NamespaceURI=childURI;child.LocalName='item';child.Prefix=if childPrefix~=''then childPrefix else nil;child.OwnerDocument=xml
   child.AttributeOrder={'one','two'};child.AttributeNamespaces={one={Namespace='urn:a',LocalName='one',Prefix=if attrPrefix~=''then attrPrefix else nil},two={Namespace='urn:b',LocalName='two',Prefix=if attrPrefix~=''then attrPrefix else nil}}
   Node.append(parent,child);local output=XML.serialize(parent,false,true);local parsed=XMLParser.parse(output,'application/xml');local result=parsed.Children[1];local parsedChild=result.Children[1]
   assert((result.NamespaceURI or'')==parentURI and(parsedChild.NamespaceURI or'')==childURI,'Element namespace survives fixup '..output)
   local first,second=Store.expanded(parsedChild,'urn:a','one'),Store.expanded(parsedChild,'urn:b','two')
   assert(first and second and parsedChild.Attributes[first]==child.Attributes.one and parsedChild.Attributes[second]==child.Attributes.two,'Attribute namespace/value survives fixup '..output)
   assert(child.Prefix==(if childPrefix~=''then childPrefix else nil)and child.AttributeNamespaces.one.Prefix==(if attrPrefix~=''then attrPrefix else nil),'Prefix fixup never changes DOM')
   combinations+=1
  end end
 end end end
 local deep=raw;raw.Children={};for index=1,4096 do local child=Node.element('r',{});child.NamespaceURI='';child.OwnerDocument=xml;Node.append(deep,child);deep=child end
 assert(#XML.serialize(raw,false,true)>20000,'Deep XML is iterative')
 print('H05 XML serialization: '..tostring(nativeCount)..' exact native records + '..tostring(deltaCount)..' explicitly normative deltas + '..tostring(combinations)..' namespace/value roundtrips + cross-realm brands/DOMException/Attr identity/HTML/raw constraints/deep traversal passed')
end
