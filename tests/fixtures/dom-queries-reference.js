// Authored reference fixture, executed unchanged in Chromium and the engine.
const queryCases = (() => {
  const HTML = 'http://www.w3.org/1999/xhtml', SVG = 'http://www.w3.org/2000/svg';
  function fresh(html) { const root = document.createElement('main'); root.id = 'query-root'; root.innerHTML = html; document.body.append(root); return root; }
  function ids(list) { return Array.from(list, node => node.id); }
  function errorName(fn) { try { fn(); return 'none'; } catch (error) { return error.name; } }
  return {
    names() {
      const root = fresh('<div id="one" name="query-name"></div><input id="two" name="query-name"><div id="id-only"></div><span id="upper" name="QUERY-NAME"></span><span id="empty" name=""></span><span id="undef" name="undefined"></span><span id="null" name="null"></span><span id="big" name="1"></span><svg><g id="foreign" name="query-name"/></svg><template><div name="query-name" id="inert"></div></template>');
      try {
        const list = document.getElementsByName('query-name');
        return { ids: ids(list), empty: ids(document.getElementsByName('')), upper: ids(document.getElementsByName('QUERY-NAME')),
          undefined: ids(document.getElementsByName(undefined)), null: ids(document.getElementsByName(null)), bigint: ids(document.getElementsByName(1n)),
          tag: Object.prototype.toString.call(list), named: typeof list.namedItem, ownName: list['one'] === undefined,
          item: list.item(0) === root.firstChild, missing: list.item(999) === null, elementAPI: typeof root.getElementsByName };
      } finally { root.remove(); }
    },
    liveNameMutation() {
      const root = fresh('<div id="one" name="live-query"></div><div id="two" name="other"></div>');
      try {
        const list = document.getElementsByName('live-query'), one = root.firstChild, two = root.lastChild;
        const snapshots = [ids(list)]; two.setAttribute('name', 'live-query'); snapshots.push(ids(list));
        root.prepend(two); snapshots.push(ids(list)); one.removeAttribute('name'); snapshots.push(ids(list));
        two.remove(); snapshots.push(ids(list)); root.append(two); snapshots.push(ids(list));
        const identity = list[0] === two; root.innerHTML = '<i id="three" name="live-query"></i>'; snapshots.push(ids(list));
        return { snapshots, identity, staticOldNode: two.parentNode === null, updatedItem: list.item(0) === root.firstChild };
      } finally { root.remove(); }
    },
    namespaces() {
      const root = fresh('<div id="html-div"></div><svg id="svg-root"><linearGradient id="gradient"></linearGradient><g id="group"><circle id="circle"></circle></g></svg><template><span id="inert"></span></template>');
      try {
        const svg = root.querySelector('svg');
        return { html: ids(root.getElementsByTagNameNS(HTML, '*')), svg: ids(root.getElementsByTagNameNS(SVG, '*')),
          both: ids(root.getElementsByTagNameNS('*', '*')), exact: ids(root.getElementsByTagNameNS('*', 'linearGradient')),
          wrongCase: ids(root.getElementsByTagNameNS(SVG, 'lineargradient')), upperHTML: ids(root.getElementsByTagNameNS(HTML, 'DIV')),
          null: ids(root.getElementsByTagNameNS(null, '*')), empty: ids(root.getElementsByTagNameNS('', '*')),
          undefined: ids(root.getElementsByTagNameNS(undefined, '*')), unknown: ids(root.getElementsByTagNameNS('urn:unknown', '*')),
          descendantsOnly: ids(svg.getElementsByTagNameNS(SVG, 'svg')), scoped: ids(svg.getElementsByTagNameNS(SVG, '*')),
          documentRoot: document.getElementsByTagNameNS(HTML, 'main')[0] === root,
          htmlTag: ids(root.getElementsByTagName('DIV')), svgTag: ids(root.getElementsByTagName('linearGradient')),
          svgTagWrongCase: ids(root.getElementsByTagName('LINEARGRADIENT')) };
      } finally { root.remove(); }
    },
    liveNamespaceMutation() {
      const root = fresh('<svg id="svg"><g id="first"></g></svg>');
      try {
        const svg = root.firstChild, list = svg.getElementsByTagNameNS(SVG, 'g'), retained = list[0];
        const snapshots = [ids(list)]; svg.insertAdjacentHTML('beforeend', '<g id="second"></g>'); snapshots.push(ids(list));
        svg.prepend(list[1]); snapshots.push(ids(list)); retained.remove(); snapshots.push(ids(list));
        svg.append(retained); snapshots.push(ids(list));
        return {snapshots, identity: list[1] === retained, tag: Object.prototype.toString.call(list), scope: list.length === 2};
      } finally { root.remove(); }
    },
    classAndNamedItems() {
      const root = fresh('<div id="one" name="alias" class="a b"></div><span id="two" class="a"></span><i id="three" class="A b"></i><svg><g id="foreign-id" name="foreign-name" class="a b"></g></svg>');
      try {
        const list = root.getElementsByClassName(' a\t b a\n'), first = root.firstChild;
        const initial = ids(list); first.className = 'a'; const changed = ids(list);
        const all = root.getElementsByTagName('*');
        return {initial, changed, empty: root.getElementsByClassName(' \t\n').length, nbsp: root.getElementsByClassName('a\u00a0b').length,
          htmlName: all.namedItem('alias') === first, svgId: all.namedItem('foreign-id') === root.querySelector('g'),
          svgName: all.namedItem('foreign-name') === null, svgProperty: all['foreign-name'] === undefined,
          missing: all.namedItem('') === null, nodeIdentity: all.namedItem('one') === first};
      } finally { root.remove(); }
    },
    requiredArguments() {
      const root = fresh('<div></div>');
      try {
        let calls = 0; const ns = {toString() { calls++; return SVG; }};
        return {name: errorName(() => document.getElementsByName()), tag: errorName(() => root.getElementsByTagName()),
          class: errorName(() => document.getElementsByClassName()), namespace: errorName(() => root.getElementsByTagNameNS()),
          local: errorName(() => document.getElementsByTagNameNS(ns)), noConversion: calls === 0,
          symbolName: errorName(() => document.getElementsByName(Symbol())), symbolTag: errorName(() => root.getElementsByTagName(Symbol())),
          symbolNamespace: errorName(() => root.getElementsByTagNameNS(Symbol(), '*')), symbolLocal: errorName(() => root.getElementsByTagNameNS('*', Symbol())),
          ignoredExtra: root.getElementsByTagName('div', Symbol()).length === 1};
      } finally { root.remove(); }
    },
    conversionAndGetters() {
      const root = fresh('<div id="converted" name="converted-query"></div><svg><g id="foreign"></g></svg>');
      try {
        const order = []; let converts = 0;
        const name = {[Symbol.toPrimitive](hint) { converts++; order.push(hint); return 'converted-query'; }};
        const names = document.getElementsByName(name); const before = ids(names); const after = ids(names);
        const namespace = {get toString() { order.push('get-namespace'); return function() {order.push('namespace'); return HTML;}; }};
        const local = {get toString() { order.push('get-local'); return function() {order.push('local'); root.append(document.createElement('div')); return 'div';}; }};
        const elements = root.getElementsByTagNameNS(namespace, local); const total = elements.length;
        let later = 0; const token = {}; let identical = false;
        try { root.getElementsByTagNameNS({get toString() {throw token;}}, {toString() {later++; return '*';}}); } catch (error) { identical = error === token; }
        return {order, converts, before, after, total, identical, shortCircuit: later === 0};
      } finally { root.remove(); }
    },
    receiverAndMetadata() {
      const root = fresh('<div id="target"><i id="nested"></i></div>');
      try {
        const div = root.firstChild; let conversions = 0; const argument = {toString() {conversions++; return '*';}};
        const documentMethod = document.getElementsByTagNameNS, elementMethod = root.getElementsByTagNameNS;
        const wrongDocument = errorName(() => documentMethod.call(root, '*', argument));
        const wrongElement = errorName(() => elementMethod.call(document, '*', argument));
        const invalid = errorName(() => elementMethod.call({}, '*', argument)); const unbound = errorName(() => elementMethod('*', argument));
        const nameMethod = document.getElementsByName; const descriptor = Object.getOwnPropertyDescriptor(nameMethod, 'length');
        return {wrongDocument, wrongElement, invalid, unbound, noConversion: conversions === 0,
          borrowed: ids(elementMethod.call(div, '*', '*')), stable: root.getElementsByTagNameNS === elementMethod,
          name: nameMethod.name, lengths: [document.getElementsByName.length, document.getElementsByTagName.length, documentMethod.length, root.getElementsByClassName.length],
          descriptor: [descriptor.writable, descriptor.enumerable, descriptor.configurable], nonconstructible: errorName(() => new nameMethod('x'))};
      } finally { root.remove(); }
    },
    liveIteration() {
      const root = fresh('<i id="one" name="iterated-query"></i><i id="two" name="iterated-query"></i>');
      try {
        const list = document.getElementsByName('iterated-query'), iterator = list.values();
        const first = iterator.next(); root.lastChild.remove(); const removed = iterator.next();
        const extra = document.createElement('i'); extra.id = 'three'; extra.setAttribute('name', 'iterated-query'); root.append(extra);
        const staysDone = iterator.next(); const all = ids(list); const visits = [];
        list.forEach((node, index, owner) => {visits.push([node.id, index, owner === list]); if (index === 0) root.lastChild.remove();});
        return {first: first.value.id, removed: removed.done, staysDone: staysDone.done, all, visits, final: ids(list)};
      } finally { root.remove(); }
    }
  };
})();
