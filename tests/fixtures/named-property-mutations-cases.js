const namedPropertyMutationCases = [
  ['candidate-free updates', `(() => {
    const a=document.createElement('img'),b=document.createElement('img');a.name=b.name='npGroup';a.alt='a';b.alt='b';document.body.append(a,b);
    const kept=document.npGroup,windowKept=window.npGroup;
    const box=document.createElement('div');document.body.append(box);box.append(document.createElement('div'),document.createTextNode('first'));box.firstChild.textContent='second';box.className='changed';box.setAttribute('data-name','irrelevant');
    return JSON.stringify([document.npGroup===kept,window.npGroup===windowKept,kept.length,kept[0]===a,kept[1]===b]);
  })()`],
  ['duplicates and ancestor order', `(() => {
    const a=document.createElement('img'),b=document.createElement('img'),left=document.createElement('div'),right=document.createElement('div');a.name=b.name='npOrder';left.append(a);right.append(b);document.body.append(left,right);
    const kept=document.npOrder;document.body.prepend(right);
    const result=[kept===document.npOrder,kept[0]===b,kept[1]===a];left.append(b);result.push(kept[0]===a,kept[1]===b);
    a.remove();result.push(document.npOrder===b,kept.length===1,kept[0]===b);document.body.append(a);result.push(document.npOrder===kept,kept[0]===b,kept[1]===a);
    return JSON.stringify(result);
  })()`],
  ['ordinary namespace attributes', `(() => {
    const image=document.createElement('img');image.name='npOrdinary';image.id='npImageId';document.body.append(image);
    const result=[document.npOrdinary===image,document.npImageId===image,window.npImageId===image];
    image.setAttributeNS('urn:np','p:name','npForeignName');image.setAttributeNS('urn:np','p:id','npForeignId');
    result.push(document.npOrdinary===image,window.npForeignName===undefined,window.npForeignId===undefined);
    image.removeAttribute('name');result.push(document.npOrdinary===undefined,document.npImageId===undefined,window.npImageId===image);
    image.setAttributeNS(null,'name','npNullName');result.push(document.npNullName===image,document.npImageId===image);image.setAttribute('id','npRenamedId');result.push(window.npImageId===undefined,window.npRenamedId===image);
    return JSON.stringify(result);
  })()`],
  ['detached ancestor changes and reinsert', `(() => {
    const ancestor=document.createElement('div'),image=document.createElement('img');image.name='npConnected';image.id='npConnectedId';ancestor.append(image);document.body.append(ancestor);
    const result=[document.npConnected===image,window.npConnectedId===image];ancestor.remove();image.name='npDetached';image.id='npDetachedId';
    result.push(document.npConnected===undefined,document.npDetached===undefined,window.npConnectedId===undefined,window.npDetachedId===undefined);document.body.append(ancestor);
    result.push(document.npDetached===image,window.npDetachedId===image);return JSON.stringify(result);
  })()`],
  ['shadow and template scopes', `(() => {
    const template=document.createElement('template');template.innerHTML='<img name="npTemplate" id="npTemplateId">';document.body.append(template);
    const host=document.createElement('div'),root=host.attachShadow({mode:'open'});root.innerHTML='<img name="npShadow" id="npShadowId"><slot></slot>';document.body.append(host);
    const light=document.createElement('img');light.name='npLight';light.id='npLightId';host.append(light);
    const result=[document.npTemplate===undefined,window.npTemplateId===undefined,document.npShadow===undefined,window.npShadowId===undefined,document.npLight===light,window.npLightId===light];
    root.querySelector('img').name='npShadowChanged';template.content.firstChild.id='npTemplateChanged';result.push(document.npShadowChanged===undefined,window.npTemplateChanged===undefined);
    document.body.append(template.content);result.push(document.npTemplate===template.content.firstChild,document.npTemplate instanceof HTMLImageElement,window.npTemplateChanged===document.npTemplate);
    return JSON.stringify(result);
  })()`],
  ['adoption between documents', `(() => {
    const other=document.implementation.createHTMLDocument('Other'),image=document.createElement('img');image.name='npAdopt';image.id='npAdoptId';document.body.append(image);
    const result=[document.npAdopt===image,window.npAdoptId===image];other.adoptNode(image);result.push(document.npAdopt===undefined,window.npAdoptId===undefined,other.npAdopt===undefined);other.body.append(image);
    result.push(other.getElementsByTagName('img')[0]===image,image.ownerDocument===other);document.body.append(image);result.push(other.npAdopt===undefined,document.npAdopt===image,window.npAdoptId===image);return JSON.stringify(result);
  })()`],
  ['expanded name candidates', `(() => {
    const html=document.createElementNS('http://www.w3.org/1999/xhtml','h:img'),foreign=document.createElementNS('urn:np','f:img'),svg=document.createElementNS('http://www.w3.org/2000/svg','s:g');
    html.setAttribute('name','npPrefixName');foreign.setAttribute('name','npForeignName');svg.setAttribute('name','npSVGName');foreign.setAttribute('id','npForeignId');svg.setAttribute('id','npSVGId');document.body.append(html,foreign,svg);
    const result=[document.npPrefixName===html,window.npPrefixName===html,document.npForeignName===undefined,window.npForeignName===undefined,window.npSVGName===undefined,window.npForeignId===foreign,window.npSVGId===svg];
    svg.setAttribute('id','npSVGChanged');foreign.removeAttribute('id');result.push(window.npSVGId===undefined,window.npSVGChanged===svg,window.npForeignId===undefined);return JSON.stringify(result);
  })()`],
  ['document built-in override remains named', `(() => {
    const image=document.createElement('img'),create=document.createElement;image.name='createElement';document.body.append(image);
    const result=[document.createElement===image,typeof Document.prototype.createElement==='function'];image.remove();result.push(typeof document.createElement==='function',create.call(document,'div').localName==='div');
    return JSON.stringify(result);
  })()`],
  ['custom-element disconnect observes new names', `(() => {
    const log=[];class NamedDisconnect extends HTMLElement {disconnectedCallback(){log.push(document.npReaction===undefined,window.npReactionId===undefined);}}
    customElements.define('np-disconnect',NamedDisconnect);const host=document.createElement('np-disconnect'),image=document.createElement('img');image.name='npReaction';image.id='npReactionId';host.append(image);document.body.append(host);
    const before=[document.npReaction===image,window.npReactionId===image];host.remove();return JSON.stringify(before.concat(log));
  })()`],
  ['candidate rename and empty values', `(() => {
    const image=document.createElement('img');image.name='npOld';document.body.append(image);const result=[document.npOld===image];image.name='npNew';result.push(document.npOld===undefined,document.npNew===image);
    image.name='';result.push(document.npNew===undefined,document['']===undefined);image.setAttribute('name','npAgain');result.push(document.npAgain===image);image.removeAttribute('name');result.push(document.npAgain===undefined);return JSON.stringify(result);
  })()`],
  ['document legacy named assignment audit', `(() => {const image=document.createElement('img');image.name='createElement';document.body.append(image);document.createElement='own';return JSON.stringify([document.createElement===image,Object.prototype.hasOwnProperty.call(document,'createElement')]);})()`],
  ['detached document named getter audit', `(() => {const other=document.implementation.createHTMLDocument('Other'),image=other.createElement('img');image.name='npDetachedGetter';other.body.append(image);return JSON.stringify([other.npDetachedGetter===image,other.defaultView===null]);})()`],
  ['window child navigable name', `(() => {
    const frame=document.createElement('iframe');frame.name='npFrameName';document.body.append(frame);return JSON.stringify([window.npFrameName===frame.contentWindow,document.npFrameName===frame.contentWindow]);
  })()`]
].map(([name,source])=>({name,source,auditOnly:name.endsWith('audit')||name==='window child navigable name'}));

const namedDetachedMinimalSource = "(()=>{const rows=[];for(const factory of ['primary','implementation','DOMParser'])for(const element of ['plain','prefixed'])for(const attribute of ['plain','foreign']){const d=factory==='primary'?document:factory==='implementation'?document.implementation.createHTMLDocument('Other'):new DOMParser().parseFromString('<!doctype html><body></body>','text/html');const img=element==='plain'?d.createElement('img'):d.createElementNS('http://www.w3.org/1999/xhtml','h:img');if(attribute==='plain')img.setAttribute('name','npMinimal');else img.setAttributeNS('urn:np','p:name','npMinimal');d.body.append(img);rows.push({factory,element,attribute,constructor:d.constructor.name,htmlDocument:d instanceof HTMLDocument,contentType:d.contentType,nodeNS:img.namespaceURI,nodeLocal:img.localName,name:img.name,plain:img.getAttribute('name'),foreign:img.getAttributeNS('urn:np','name'),isRoot:img.getRootNode()===d,images:d.images.length,found:d.npMinimal===img,property:typeof d.npMinimal,own:Object.prototype.hasOwnProperty.call(d,'npMinimal')});img.remove();}return rows;})()";
