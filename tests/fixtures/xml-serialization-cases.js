function xmlSerializationChecks() {
  const records = [], XML = 'http://www.w3.org/XML/1998/namespace', XMLNS = 'http://www.w3.org/2000/xmlns/', HTML = 'http://www.w3.org/1999/xhtml';
  function record(name, value) { records.push({name: name, value: value}); }
  function attempt(action) { try { return {value: action()}; } catch (error) { return {error: error.name}; } }
  function run(name, make) {
    const d = document.implementation.createDocument(null, 'root', null);
    const node = make(d);
    record(name, [attempt(function () { return new XMLSerializer().serializeToString(node); }),
      attempt(function () { return node.outerHTML; }), attempt(function () { return node.innerHTML; })]);
  }
  run('unprefixed-attribute', d => { const n=d.createElementNS('urn:element','root'); n.setAttributeNS('urn:attribute','flag','yes'); return n; });
  run('element-attribute-prefix-conflict', d => { const n=d.createElementNS('urn:element','p:root'); n.setAttributeNS('urn:attribute','p:flag','yes'); return n; });
  run('element-local-prefix-conflict', d => { const n=d.createElementNS('urn:element','p:root'); n.setAttributeNS(XMLNS,'xmlns:p','urn:other'); return n; });
  run('element-default-conflict', d => { const n=d.createElementNS('urn:element','root'); n.setAttributeNS(XMLNS,'xmlns','urn:other'); return n; });
  run('prefix-candidates-last', d => { const n=d.createElementNS('urn:element','root'); n.setAttributeNS(XMLNS,'xmlns:a','urn:element'); n.setAttributeNS(XMLNS,'xmlns:b','urn:element'); return n; });
  run('prefix-preferred', d => { const n=d.createElementNS('urn:element','a:root'); n.setAttributeNS(XMLNS,'xmlns:a','urn:element'); n.setAttributeNS(XMLNS,'xmlns:b','urn:element'); return n; });
  run('xml-element-prefix', d => d.createElementNS(XML,'p:root'));
  run('xml-attribute-prefix', d => { const n=d.createElement('root'); n.setAttributeNS(XML,'p:lang','de'); return n; });
  run('prefix-inherited-remap', d => { const n=d.createElementNS('urn:root','root'); n.setAttributeNS(XMLNS,'xmlns:a','urn:child'); n.append(d.createElementNS('urn:child','b:child')); return n; });
  run('inherited-element-attribute-prefix-conflict', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:p','urn:a');const c=d.createElementNS('urn:a','p:child');c.setAttributeNS('urn:b','p:flag','x');n.append(c);return n; });
  run('default-reset', d => { const n=d.createElementNS('urn:root','root'), c=d.createElement('child'); c.append(d.createElementNS('urn:root','grand')); n.append(c); return n; });
  run('generated-prefix-collision', d => { const n=d.createElement('root'); n.setAttributeNS(XMLNS,'xmlns:ns1','urn:occupied'); n.setAttributeNS('urn:new','flag','x'); return n; });
  run('generated-prefix-siblings', d => { const n=d.createElement('root'); for(let i=0;i<2;i++){const c=d.createElement('child');c.setAttributeNS('urn:'+i,'flag','x');n.append(c);}return n; });
  run('null-namespace-xmlns', d => { const n=d.createElement('root'); n.setAttribute('xmlns','urn:decl'); return n; });
  run('unbound-element-local-colon', d => d.createElement('p:name'));
  run('unbound-attribute-colon', d => { const n=d.createElement('root'); n.setAttribute('p:name','x'); return n; });
  run('xml-escaped-whitespace', d => { const n=d.createElement('root');n.setAttribute('data','&<>"\t\n\r\u00a0');n.textContent='&<>\u00a0';return n; });
  run('xml-comment-invalid', d => { const n=d.createElement('root');n.append(d.createComment('x--y-'));return n; });
  run('xml-text-invalid', d => { const n=d.createElement('root');n.textContent='x\u0001y';return n; });
  run('xml-attribute-invalid', d => { const n=d.createElement('root');n.setAttribute('data','x\u0001y');return n; });
  run('xml-cdata-invalid', d => { const n=d.createElement('root'),c=d.createCDATASection('ok');c.data='bad]]>data';n.append(c);return n; });
  run('xml-pi-invalid-target', d => d.createProcessingInstruction('p:target',''));
  run('xml-pi-empty', d => d.createProcessingInstruction('target',''));
  run('xml-pi-invalid-data', d => { const n=d.createElement('root'),p=d.createProcessingInstruction('target','ok');p.data='bad?>data';n.append(p);return n; });
  run('xml-fragment', d => { const f=d.createDocumentFragment();for(let i=0;i<2;i++){const c=d.createElement('child');c.setAttributeNS('urn:'+i,'flag','x');f.append(c);}return f; });
  run('xml-attr-root', d => { const a=d.createAttributeNS('urn:a','p:flag');a.value='x';return a; });
  run('html-void', d => d.createElementNS(HTML,'input'));
  run('html-nonvoid-empty', d => d.createElementNS(HTML,'div'));
  run('foreign-empty', d => d.createElementNS('urn:a','root'));
  run('xml-script-escaping', d => { const n=d.createElementNS(HTML,'script');n.textContent='a < b && c > d';return n; });
  run('xmlns-reserved-value', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:p',XMLNS);return n; });
  run('xmlns-xml-redundant', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:p',XML);n.setAttributeNS(XMLNS,'xmlns:xml',XML);return n; });
  run('xmlns-prefix-undeclare', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:p','');return n; });
  run('xmlns-xml-prefix-rebind', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:xml','urn:other');return n; });
  run('xmlns-xmlns-prefix-rebind', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:xmlns','urn:other');return n; });
  run('xmlns-element-namespace', d => d.createElementNS(XMLNS,'xmlns'));
  run('xmlns-default-reset', d => { const n=d.createElementNS('urn:a','root');const c=d.createElement('child');c.setAttributeNS(XMLNS,'xmlns','');n.append(c);return n; });
  run('local-default-vs-prefix', d => { const n=d.createElementNS('urn:a','root');n.setAttributeNS(XMLNS,'xmlns','urn:a');n.setAttributeNS(XMLNS,'xmlns:p','urn:a');return n; });
  run('inherited-prefix-shadowed', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:p','urn:a');const c=d.createElementNS('urn:a','child');c.setAttributeNS(XMLNS,'xmlns:p','urn:b');n.append(c);return n; });
  run('sibling-prefix-redundancy', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:p','urn:a');for(let i=0;i<2;i++){const c=d.createElementNS('urn:a','p:child');c.setAttributeNS(XMLNS,'xmlns:p','urn:a');n.append(c);}return n; });
  run('html-template', d => { const n=d.createElementNS(HTML,'h:template');n.innerHTML='<h:span>one &amp; two</h:span>';return n; });
  run('html-document', d => document.implementation.createHTMLDocument('A & B'));
  run('empty-document', d => document.implementation.createDocument(null,null,null));
  run('doctype-public-system', d => document.implementation.createDocumentType('root','a b','x"y'));
  run('doctype-both-quotes', d => document.implementation.createDocumentType('root','','x"y\'z'));
  run('unicode-name', d => { const n=d.createElementNS('urn:é','é:名');n.setAttributeNS('urn:ß','ß:值','ü');return n; });
  run('xml-nested-default-and-prefix', d => { const n=d.createElementNS('urn:a','root');n.setAttributeNS(XMLNS,'xmlns:p','urn:a');const c=d.createElementNS('urn:a','p:child');c.setAttributeNS('urn:b','p:flag','x');c.append(d.createElementNS('urn:a','p:end'));n.append(c);return n; });
  run('attribute-prefix-order-conflict', d => { const n=d.createElement('root');n.setAttributeNS('urn:a','p:first','one');n.setAttributeNS('urn:b','p:second','two');return n; });
  run('attribute-later-declaration', d => { const n=d.createElement('root');n.setAttributeNS('urn:a','p:flag','x');n.setAttributeNS(XMLNS,'xmlns:p','urn:b');return n; });
  run('attribute-inherited-prefix-conflict', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:p','urn:a');const c=d.createElement('child');c.setAttributeNS('urn:b','p:flag','x');n.append(c);return n; });
  run('unprefixed-attribute-nearest-candidate', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:p','urn:a');n.setAttributeNS(XMLNS,'xmlns:q','urn:a');const c=d.createElement('child');c.setAttributeNS(XMLNS,'xmlns:s','urn:a');c.setAttributeNS('urn:a','flag','x');n.append(c);return n; });
  run('attribute-shadowed-prefix-candidate', d => { const n=d.createElement('root');n.setAttributeNS(XMLNS,'xmlns:p','urn:a');n.setAttributeNS(XMLNS,'xmlns:q','urn:a');const c=d.createElement('child');c.setAttributeNS(XMLNS,'xmlns:q','urn:b');c.setAttributeNS('urn:a','flag','x');n.append(c);return n; });
  run('xlink-no-special-prefix', d => { const n=d.createElement('root');n.setAttributeNS('http://www.w3.org/1999/xlink','href','one');n.setAttributeNS('urn:a','xl:flag','two');return n; });
  run('xml-void-with-children', d => { const n=d.createElementNS(HTML,'img');n.append(d.createElementNS(HTML,'style'));return n; });
  run('pi-xml-target', d => { const n=d.createElement('root');n.append(d.createProcessingInstruction('XmL','v'));return n; });
  run('doctype-public-tab', d => document.implementation.createDocumentType('root','a\tb',''));
  run('doctype-public-unicode', d => document.implementation.createDocumentType('root','ä',''));
  run('doctype-system-invalid-character', d => document.implementation.createDocumentType('root','','a\u0001b'));
  const d=document.implementation.createDocument('urn:r','r',null), n=d.createElementNS('urn:a','p:item');n.setAttributeNS('urn:b','p:flag','x');d.documentElement.append(n);
  const clone=n.cloneNode(true), target=document.implementation.createDocument(null,'root',null), imported=target.importNode(n,true);
  record('clone-import-source-identity',[n.prefix,n.getAttributeNodeNS('urn:b','flag').prefix,new XMLSerializer().serializeToString(n),new XMLSerializer().serializeToString(clone),new XMLSerializer().serializeToString(imported),n.prefix,n.getAttributeNodeNS('urn:b','flag').prefix,n.ownerDocument===d,imported.ownerDocument===target]);
  const before=n.outerHTML;const bad=d.createComment('bad--comment');n.append(bad);
  record('strict-error-atomicity',[attempt(()=>n.outerHTML),n.childNodes.length,n.lastChild===bad,n.prefix,n.getAttributeNodeNS('urn:b','flag').prefix]);n.removeChild(bad);record('strict-error-recovery',n.outerHTML===before);
  const s=new XMLSerializer(), p=XMLSerializer.prototype, method=p.serializeToString, descriptor=Object.getOwnPropertyDescriptor(p,'serializeToString');
  record('interface-descriptors',[XMLSerializer.name,XMLSerializer.length,method.name,method.length,descriptor.writable,descriptor.enumerable,descriptor.configurable,Object.prototype.toString.call(s),Object.getPrototypeOf(s)===p]);
  record('interface-brand-arguments',[attempt(()=>XMLSerializer()),attempt(()=>method.call({},d)),attempt(()=>s.serializeToString()),attempt(()=>s.serializeToString(null)),attempt(()=>s.serializeToString({nodeType:1})),attempt(()=>s.serializeToString(d.createTextNode('x')))]);
  return records;
}
function xmlCrossRealmChecks(ForeignSerializer, foreignNode) {
  const local=new XMLSerializer(), foreign=new ForeignSerializer();
  return [ForeignSerializer.prototype.serializeToString.call(local,foreignNode),
    XMLSerializer.prototype.serializeToString.call(foreign,foreignNode),
    foreignNode.prefix,foreignNode.getAttributeNodeNS('urn:b','flag').prefix,
    foreign instanceof ForeignSerializer,local instanceof XMLSerializer];
}
function xmlCrossRealmErrors(ForeignSerializer, ForeignTypeError) {
  const method=ForeignSerializer.prototype.serializeToString, local=new XMLSerializer();
  const records=[];
  for(const action of [()=>method.call({},foreignNode),()=>method.call(local,null),()=>method.call(local)]){
    try{action();records.push('missing');}catch(error){records.push([error.name,error instanceof ForeignTypeError,error instanceof TypeError]);}
  }
  return records;
}
