// Shared fixture: execute in Chromium and in the engine's ordinary JS realm.
const traversalCases = (() => {
  function fresh() {
    const root = document.createElement('div'); root.id = 'root';
    root.innerHTML = '<div id="a">A<span id="a1">one</span><i id="a2">two</i></div><section id="skip"><b id="s1">three</b></section><section id="reject"><b id="r1">four</b></section><!--note--><p id="z">Z</p>';
    return root;
  }
  function label(node) { return node === null ? null : node.id || node.nodeName + ':' + node.nodeValue; }
  function collect(traverser, method = 'nextNode') { const list = []; let node; while ((node = traverser[method]()) !== null) list.push(label(node)); return list; }
  function errorName(fn) { try { fn(); return 'none'; } catch (error) { return error.name; } }
  function choose(node) { return node.id === 'skip' ? NodeFilter.FILTER_SKIP : node.id === 'reject' ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT; }
  return {
    basic() {
      const root = fresh(); const iterator = document.createNodeIterator(root, NodeFilter.SHOW_ELEMENT, choose);
      const before = [label(iterator.referenceNode), iterator.pointerBeforeReferenceNode, iterator.root === root, iterator.filter === choose];
      const forward = collect(iterator); const reverse = collect(iterator, 'previousNode');
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT, choose);
      const walked = collect(walker); const walkedBack = collect(walker, 'previousNode');
      return { before, forward, reverse, walked, walkedBack, exhausted: iterator.previousNode() === null, all: collect(document.createNodeIterator(root)) };
    },
    navigation() {
      const root = fresh(); const walker = document.createTreeWalker(root, 1, choose); const steps = [];
      for (const name of ['firstChild', 'firstChild', 'nextSibling', 'previousSibling', 'parentNode', 'nextSibling', 'parentNode', 'lastChild', 'previousSibling', 'previousSibling', 'parentNode', 'previousNode']) steps.push([name, label(walker[name]()), label(walker.currentNode)]);
      walker.currentNode = root.querySelector('#r1'); steps.push(['parent-rejected', label(walker.parentNode())]);
      const outside = document.createElement('aside'); const child = document.createElement('em'); outside.append(child);
      walker.currentNode = child; steps.push(['outside-root-parent', label(walker.parentNode()), walker.currentNode === outside]);
      return { steps, nullCurrent: errorName(() => { walker.currentNode = null; }), unchanged: walker.currentNode === outside };
    },
    filterConversion() {
      const root = fresh(); let reads = 0; let receiver = false;
      const filter = { get acceptNode() { reads++; return function(node) { receiver = this === filter; return node.id === 'a' ? 65537.9 : 3; }; } };
      const iterator = document.createNodeIterator(root, 1, filter); const deferred = reads; const found = iterator.nextNode();
      let functionReceiver; function callback() { 'use strict'; functionReceiver = this; return 1; }
      Object.defineProperty(callback, 'acceptNode', { get() { throw new Error('callable filter property must not be read'); } });
      document.createTreeWalker(root, 1, callback).nextNode();
      const converted = document.createNodeIterator(root, { valueOf() { return -1; } }).whatToShow;
      const invalid = document.createNodeIterator(root, 1, {});
      return { deferred, reads, receiver, found: label(found), identity: iterator.filter === filter, callableThis: functionReceiver === undefined,
        converted, nullMask: document.createTreeWalker(root, null).nextNode(), zeroMask: document.createNodeIterator(root, 0, {}).nextNode(),
        badObject: errorName(() => invalid.nextNode()), badPrimitive: errorName(() => document.createTreeWalker(root, 1, 7)),
        bigMask: errorName(() => document.createNodeIterator(root, 1n)), symbolMask: errorName(() => document.createNodeIterator(root, Symbol())),
        numericFilter: label(document.createNodeIterator(root, 1, () => -65535).nextNode()) };
    },
    masksAndUnknownResult() {
      const root = fresh(); let calls = 0;
      const text = collect(document.createTreeWalker(root, NodeFilter.SHOW_TEXT, () => { calls++; return true; }));
      const comments = collect(document.createNodeIterator(root, NodeFilter.SHOW_COMMENT));
      const filter = node => node.id === 'a' ? 0 : 1;
      const child = document.createTreeWalker(root, 1, filter).firstChild();
      const next = document.createTreeWalker(root, 1, filter).nextNode();
      const fragment = document.createDocumentFragment(); fragment.append(root);
      return { text, calls, comments, child: label(child), next: label(next), fragment: collect(document.createNodeIterator(fragment, NodeFilter.SHOW_DOCUMENT_FRAGMENT)), attributes: collect(document.createNodeIterator(root, NodeFilter.SHOW_ATTRIBUTE)) };
    },
    errorsAndReentrancy(part) {
      const root = fresh();
      const parts = {
        exception() {
          const token = {}; let throws = true; const iterator = document.createNodeIterator(root, 1, () => { if (throws) throw token; return 1; });
          let identity = false; try { iterator.nextNode(); } catch (error) { identity = error === token; }
          const afterFailure = [label(iterator.referenceNode), iterator.pointerBeforeReferenceNode]; throws = false;
          return { identity, afterFailure, recovered: label(iterator.nextNode()) };
        },
        iterator() {
          let recursive; let recursiveCalls = 0;
          recursive = document.createNodeIterator(root, 1, () => { if (++recursiveCalls > 1) return 1; return recursive.nextNode(); });
          const recursiveError = errorName(() => recursive.nextNode());
          const outer = label(recursive.nextNode());
          return { recursiveError, outer, outerPosition: [label(recursive.referenceNode), recursive.pointerBeforeReferenceNode] };
        },
        walker() {
          let walker; let nestedParent; let walkerError; let walkerCalls = 0;
          walker = document.createTreeWalker(root, 1, () => { if (++walkerCalls > 1) return 1; nestedParent = walker.parentNode(); walkerError = errorName(() => walker.nextNode()); return 1; });
          return { walked: label(walker.nextNode()), walkerError, nestedParent };
        },
        coercion() {
          let coercion; let coercionError; let conversions = 0;
          coercion = document.createNodeIterator(root, 1, () => ({ valueOf() { if (++conversions > 1) return 1; coercionError = errorName(() => coercion.nextNode()); return 1; } }));
          return { coerced: label(coercion.nextNode()), coercionError };
        }
      };
      const result = {}; for (const name of part ? [part] : Object.keys(parts)) Object.assign(result, parts[name]()); return result;
    },
    deepNavigation() {
      const root = document.createElement('div'); root.id = 'deep-root';
      root.innerHTML = '<section id="skip-outer"><div id="skip-inner"><p id="reject-deep"><span id="hidden"></span></p><p id="accept-deep"></p></div><p id="accept-outer"></p></section><p id="end"></p>';
      const filter = node => node.id.startsWith('skip') ? 3 : node.id.startsWith('reject') ? 2 : 1;
      const walker = document.createTreeWalker(root, 1, filter); const steps = [];
      for (const name of ['firstChild', 'nextSibling', 'previousSibling', 'nextNode', 'parentNode', 'lastChild', 'previousSibling', 'previousNode', 'parentNode']) steps.push([name, label(walker[name]()), label(walker.currentNode)]);
      return { steps, forward: collect(document.createTreeWalker(root, 1, filter)) };
    },
    removals(part) {
      if (part === 'end') {
        const root = fresh(); const iterator = document.createNodeIterator(root, 1); collect(iterator);
        const before = [label(iterator.referenceNode), iterator.pointerBeforeReferenceNode];
        const backward = label(iterator.previousNode()); const selected = root.querySelector('#z');
        const afterBackward = [label(iterator.referenceNode), iterator.pointerBeforeReferenceNode];
        selected.remove();
        return {before, backward, afterBackward, removed: selected.parentNode === null,
          position: [label(iterator.referenceNode), iterator.pointerBeforeReferenceNode], next: label(iterator.nextNode())};
      }
      const afterRoot = fresh(); const after = document.createNodeIterator(afterRoot, 1); after.nextNode(); after.nextNode(); after.nextNode(); afterRoot.querySelector('#a').remove();
      const afterPosition = [label(after.referenceNode), after.pointerBeforeReferenceNode, label(after.nextNode())];
      const beforeRoot = fresh(); const before = document.createNodeIterator(beforeRoot, 1); before.nextNode(); before.nextNode(); before.nextNode(); before.previousNode(); beforeRoot.querySelector('#a').remove();
      const beforePosition = [label(before.referenceNode), before.pointerBeforeReferenceNode, label(before.nextNode())];
      const lastRoot = fresh(); const last = document.createNodeIterator(lastRoot, 1); collect(last); last.previousNode(); lastRoot.querySelector('#z').remove();
      const lastPosition = [label(last.referenceNode), last.pointerBeforeReferenceNode, label(last.nextNode())];
      const moveRoot = fresh(); const moved = moveRoot.querySelector('#a'); const move = document.createNodeIterator(moveRoot, 1); move.nextNode(); move.nextNode(); moveRoot.append(moved);
      const movePosition = [label(move.referenceNode), move.pointerBeforeReferenceNode, label(move.nextNode()), moveRoot.lastChild === moved];
      const detached = fresh(); const wrapper = document.createElement('div'); wrapper.append(detached); const retained = document.createNodeIterator(detached, 1); retained.nextNode(); retained.nextNode(); detached.remove();
      const retainedPosition = [label(retained.referenceNode), label(retained.nextNode()), retained.root === detached];
      return { afterPosition, beforePosition, lastPosition, movePosition, retainedPosition };
    },
    filterMutation() {
      const root = fresh(); let iterator;
      iterator = document.createNodeIterator(root, 1, node => { if (node.id === 'a') node.remove(); return 1; });
      const first = label(iterator.nextNode()); const candidate = iterator.nextNode();
      const adjusted = [label(iterator.referenceNode), iterator.pointerBeforeReferenceNode]; const next = label(iterator.nextNode());
      const otherRoot = fresh(); const skip = document.createNodeIterator(otherRoot, 1, node => { if (node.id === 'a') { node.remove(); return 3; } return 1; });
      const skipFirst = label(skip.nextNode()); const skipNext = label(skip.nextNode());
      const walkerRoot = fresh(); const walker = document.createTreeWalker(walkerRoot, 1, node => { if (node.id === 'a') node.remove(); return 1; });
      const current = walker.nextNode(); const walkerNext = label(walker.nextNode());
      return { first, candidate: label(candidate), detached: candidate.parentNode === null, adjusted, next, skipFirst, skipNext, walkerCurrent: label(current), walkerDetached: current.parentNode === null, walkerNext };
    },
    replacementPaths() {
      const root = document.createElement('div'); root.append('old'); const iterator = document.createNodeIterator(root, NodeFilter.SHOW_TEXT); iterator.nextNode(); root.textContent = 'new';
      const text = [label(iterator.referenceNode), iterator.pointerBeforeReferenceNode, label(iterator.nextNode())];
      const htmlRoot = fresh(); const html = document.createNodeIterator(htmlRoot, 1); html.nextNode(); html.nextNode(); html.nextNode(); htmlRoot.innerHTML = '<strong id="fresh">new</strong>';
      const markup = [label(html.referenceNode), label(html.nextNode())];
      const normalized = document.createElement('div'); normalized.append('left', '', 'right'); const merge = document.createNodeIterator(normalized, 4); merge.nextNode(); merge.nextNode(); normalized.normalize();
      const normal = [label(merge.referenceNode), merge.pointerBeforeReferenceNode, label(merge.nextNode()), normalized.childNodes.length];
      return { text, markup, normal };
    },
    identityAndDescriptors() {
      const root = fresh(); const iterator = document.createNodeIterator(root, 1); const walker = document.createTreeWalker(root, 1); const node = walker.nextNode();
      iterator.detach(); const usable = iterator.nextNode() === root; iterator.root = null; iterator.referenceNode = null; iterator.whatToShow = 0;
      const readOnly = [iterator.root === root, iterator.referenceNode === root, iterator.whatToShow === 1];
      const descriptor = Object.getOwnPropertyDescriptor(TreeWalker.prototype, 'currentNode');
      const strict = errorName(() => { 'use strict'; walker.root = null; });
      const mask = Object.getOwnPropertyDescriptor(NodeFilter, 'SHOW_ALL');
      return { usable, readOnly, strict, instance: iterator instanceof NodeIterator && walker instanceof TreeWalker, tag: Object.prototype.toString.call(walker), identity: node === root.firstChild && walker.currentNode === node,
        property: [typeof descriptor.get, typeof descriptor.set, descriptor.enumerable, descriptor.configurable], constant: [mask.value, mask.writable, mask.enumerable, mask.configurable],
        constructor: errorName(() => new TreeWalker()), callable: errorName(() => NodeFilter()), noPrototype: NodeFilter.prototype === undefined,
        receiver: errorName(() => TreeWalker.prototype.nextNode.call({})), factoryReceiver: errorName(() => document.createTreeWalker.call({}, root)) };
    }
  };
})();
