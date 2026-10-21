function templateDocumentChecks() {
  const records = [];
  function record(name, value) { records.push({ name: name, value: value }); }
  const ns = 'http://www.w3.org/1999/xhtml';
  const impl = document.implementation;
  const html = impl.createHTMLDocument('outer');
  const xml = impl.createDocument('urn:root', 'r', null);
  const documents = [html, xml];
  for (let d = 0; d < documents.length; d++) {
    const doc = documents[d], key = d === 0 ? 'html' : 'xml';
    const a = doc.createElementNS(ns, 'template');
    const b = doc.createElementNS(ns, 'h:template');
    const owner = a.content.ownerDocument;
    record(key + '-inert-metadata', [owner !== doc, owner === b.content.ownerDocument,
      owner.nodeType, owner.defaultView === null, owner.location === null, owner.URL,
      owner.contentType, owner.compatMode, owner.documentElement === null, owner.childNodes.length,
      owner instanceof HTMLDocument, owner instanceof XMLDocument]);
    record(key + '-identity', [a instanceof HTMLTemplateElement, b instanceof HTMLTemplateElement,
      a.content === a.content, b.content === b.content, b.localName, b.prefix,
      a.content.parentNode === null, a.content.isConnected]);
    const nested = owner.createElementNS(ns, 'template');
    record(key + '-nested-owner-reuse', nested.content.ownerDocument === owner);
    const negative = [doc.createElementNS(null, 'template'), doc.createElementNS('urn:other', 'template'),
      doc.createElementNS(ns, 'Template'), doc.createElement('h:template')];
    record(key + '-negative', negative.map(function (node) { return [node instanceof HTMLTemplateElement, node.content === undefined]; }));
    const light = doc.createElementNS(ns, 'span'); light.textContent = 'light'; b.append(light);
    b.innerHTML = d === 0 ? '<b>inside</b><template><i>nested</i></template>' : '<h:b>inside</h:b><h:template><h:i>nested</h:i></h:template>';
    const inner = b.content.lastChild;
    record(key + '-inner-html', [b.children.length, b.textContent, b.innerHTML,
      b.content.children.length, b.content.firstChild.ownerDocument === owner,
      inner.content.ownerDocument === owner, inner.content.firstChild.ownerDocument === owner,
      b.content.querySelector('i') === null]);
    const clone = b.cloneNode(true), shallow = b.cloneNode(false);
    record(key + '-clone', [clone !== b, clone.ownerDocument === doc,
      clone.content !== b.content, clone.content.ownerDocument === owner,
      clone.content.firstChild !== b.content.firstChild,
      clone.content.firstChild.ownerDocument === owner,
      clone.content.lastChild.content.ownerDocument === owner,
      clone.firstChild !== light, clone.textContent, clone.innerHTML,
      shallow.childNodes.length, shallow.content.childNodes.length,
      shallow.content.ownerDocument === owner]);
    const contentClone = b.content.cloneNode(true);
    record(key + '-content-clone', [contentClone.ownerDocument === owner,
      contentClone.lastChild.content.ownerDocument === owner]);
    const other = impl.createHTMLDocument('target');
    const targetOwner = other.createElement('template').content.ownerDocument;
    const oldContent = b.content, oldChild = b.content.firstChild;
    other.adoptNode(b);
    record(key + '-adopt', [b.ownerDocument === other, b.content === oldContent,
      b.content.ownerDocument === targetOwner, oldChild.ownerDocument === targetOwner,
      inner.ownerDocument === targetOwner, inner.content.ownerDocument === targetOwner,
      light.ownerDocument === other]);
    const imported = doc.importNode(b, true);
    record(key + '-import', [imported.ownerDocument === doc, imported.content.ownerDocument === owner,
      imported.content.firstChild.ownerDocument === owner,
      imported.content.lastChild.content.ownerDocument === owner,
      imported.firstChild.ownerDocument === doc, b.ownerDocument === other]);
    other.body.append(b.content);
    record(key + '-extract', [b.content.childNodes.length, oldChild.ownerDocument === other,
      oldChild.isConnected, inner.ownerDocument === other, inner.content.ownerDocument === targetOwner,
      inner.content.firstChild.ownerDocument === targetOwner]);
    const detachedClone = doc.cloneNode(true);
    record(key + '-document-clone', detachedClone.createElementNS(ns, 'template').content.ownerDocument !== owner);
    const ownerClone = owner.cloneNode(true);
    record(key + '-inert-document-clone', [ownerClone instanceof Document,
      ownerClone instanceof HTMLDocument, ownerClone instanceof XMLDocument,
      ownerClone.contentType, ownerClone.createElementNS(ns, 'template').content.ownerDocument !== ownerClone]);
  }
  const parser = new DOMParser();
  const parsedHTML = parser.parseFromString('<!doctype html><template id="t"><span>A</span><template><b>B</b></template></template>', 'text/html');
  const t = parsedHTML.getElementById('t');
  record('html-parser', [t.childNodes.length, t.content.childNodes.length,
    t.content.ownerDocument !== parsedHTML, t.content.firstChild.ownerDocument === t.content.ownerDocument,
    t.content.lastChild.content.ownerDocument === t.content.ownerDocument,
    parsedHTML.querySelector('span') === null, t.innerHTML]);
  const parsedXML = parser.parseFromString('<r xmlns:h="http://www.w3.org/1999/xhtml"><h:template id="x"><h:span>A</h:span><h:template><h:b>B</h:b></h:template></h:template><template>C</template></r>', 'application/xml');
  const xt = parsedXML.getElementsByTagNameNS(ns, 'template')[0];
  record('xml-parser', [xt instanceof HTMLTemplateElement, xt.childNodes.length,
    xt.content.childNodes.length, xt.content.ownerDocument !== parsedXML,
    xt.content.firstChild.ownerDocument === xt.content.ownerDocument,
    xt.content.lastChild.content.ownerDocument === xt.content.ownerDocument,
    parsedXML.getElementsByTagNameNS(ns, 'span').length,
    parsedXML.getElementsByTagName('template')[0].content === undefined]);
  xt.innerHTML = '<h:span data-x="one"/><h:template><h:i>inner</h:i></h:template>';
  record('xml-prefixed-fragment', [xt.content.firstChild.namespaceURI,
    xt.content.firstChild.prefix, xt.content.lastChild.content.firstChild.localName,
    xt.content.firstChild.ownerDocument === xt.content.ownerDocument,
    xt.childNodes.length, xt.content.childNodes.length]);
  const before = xt.innerHTML; let syntax = '';
  try { xt.innerHTML = '<h:span>'; } catch (error) { syntax = error.name; }
  record('xml-fragment-error', [syntax, xt.innerHTML === before]);
  const prefixed = html.createElementNS(ns, 'h:template');
  prefixed.innerHTML = '<tr><td>cell</td></tr><template><p>nested</p></template>';
  record('html-prefixed-template-fragment', [prefixed.content.firstChild.localName,
    prefixed.content.firstChild.firstChild.localName, prefixed.innerHTML,
    prefixed.content.lastChild.content.firstChild.localName]);
  const descriptor = Object.getOwnPropertyDescriptor(HTMLTemplateElement.prototype, 'content');
  let brandErrors = 0;
  for (const receiver of [{}, html.createElement('div'), html.createElementNS('urn:other', 'template')]) {
    try { descriptor.get.call(receiver); } catch (error) { if (error.name === 'TypeError') brandErrors++; }
  }
  record('content-descriptor', [typeof descriptor.get, descriptor.set === undefined,
    descriptor.enumerable, descriptor.configurable, descriptor.get.call(prefixed) === prefixed.content,
    brandErrors]);
  const primary = document.createElement('template'), primaryOwner = primary.content.ownerDocument;
  record('primary-inert-metadata', [primaryOwner !== document, primaryOwner.URL,
    primaryOwner.baseURI, primaryOwner.defaultView === null, primaryOwner.location === null]);
  const inertCreated = primaryOwner.createElement('template');
  record('inert-created-template', inertCreated.content.ownerDocument === primaryOwner);
  let constructions = 0, connections = 0;
  class TemplateProbe extends HTMLElement {
    constructor() { super(); constructions++; }
    connectedCallback() { connections++; }
  }
  customElements.define('x-template-probe', TemplateProbe);
  const customTemplate = document.createElement('template');
  customTemplate.innerHTML = '<x-template-probe></x-template-probe><template><x-template-probe></x-template-probe></template>';
  const customClone = customTemplate.cloneNode(true);
  const inertCustom = customTemplate.content.ownerDocument.createElement('x-template-probe');
  record('custom-inert', [constructions, connections,
    customTemplate.content.firstChild instanceof TemplateProbe,
    customClone.content.firstChild instanceof TemplateProbe, inertCustom instanceof TemplateProbe]);
  const activeImport = document.importNode(customTemplate.content, true);
  record('custom-active-import', [constructions, connections,
    activeImport.firstChild instanceof TemplateProbe,
    activeImport.lastChild.content.firstChild instanceof TemplateProbe]);
  document.body.append(activeImport);
  record('custom-active-insertion', [constructions, connections]);
  const preservedContent = customTemplate.content, preservedCustom = preservedContent.firstChild;
  document.adoptNode(preservedCustom);
  record('custom-adopt-before-insert', [constructions, connections, preservedCustom instanceof TemplateProbe,
    preservedCustom.ownerDocument === document]);
  document.body.append(preservedCustom);
  record('custom-adopt-insert', [constructions, connections, preservedCustom instanceof TemplateProbe]);
  document.body.append(customClone);
  record('custom-mounted-template-stays-inert', [constructions, connections,
    customClone.content.lastChild.content.firstChild.isConnected]);
  const independent = document.createElement('div'); independent.content = 'ordinary expando';
  const foreignTemplate = document.createElementNS('urn:foreign', 'template'); foreignTemplate.content = 7;
  let readonlyError = '';
  try { (function () { 'use strict'; primary.content = document.createDocumentFragment(); })(); }
  catch (error) { readonlyError = error.name; }
  record('content-assignment', [independent.content, foreignTemplate.content, readonlyError,
    primary.content.ownerDocument === primaryOwner]);
  const inertFragment = primaryOwner.createDocumentFragment();
  const orphan = primaryOwner.createElement('span'); inertFragment.append(orphan);
  document.adoptNode(inertFragment);
  record('direct-contents-document-adoption', [inertFragment.ownerDocument === document,
    orphan.ownerDocument === document, inertCreated.content.ownerDocument === primaryOwner]);
  return records;
}
