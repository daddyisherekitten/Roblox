// The same finite authored cases run in Chromium and the engine.
const rangeCases=(()=>{
  function fresh(html){const root=document.createElement('main');root.id='range-root';root.innerHTML=html;document.body.append(root);return root;}
  function label(node){return node.nodeType===3?'#text:'+node.data:node.nodeType===8?'#comment:'+node.data:node.id||node.nodeName;}
  function point(range){return [[label(range.startContainer),range.startOffset],[label(range.endContainer),range.endOffset],range.collapsed];}
  function error(fn){try{fn();return 'none';}catch(e){return e.name;}}
  function descriptorFor(value,key){for(let current=value;current;current=Object.getPrototypeOf(current)){const descriptor=Object.getOwnPropertyDescriptor(current,key);if(descriptor)return descriptor;}throw new Error('Missing Range accessor '+key);}
  return {
    construction(){
      const root=fresh('<p id="p">one<b id="b">two</b>three</p>');
      try{const a=document.createRange(),b=new Range();a.selectNodeContents(root.firstChild);const clone=a.cloneRange();
        return {initial:[b.startContainer===document,b.endContainer===document,b.startOffset,b.endOffset,b.collapsed],text:String(a),common:a.commonAncestorContainer===root.firstChild,
          identity:clone!==a&&clone.startContainer===a.startContainer&&clone.endContainer===a.endContainer,clone:String(clone),instance:a instanceof Range&&a instanceof AbstractRange,
          tags:[Object.prototype.toString.call(a),Object.prototype.toString.call(clone)],construct:error(()=>Range()),abstract:error(()=>new AbstractRange())};
      }finally{root.remove();}
    },
    boundaries(){
      const root=fresh('<p id="a">abc</p><p id="b">def</p>');
      try{const a=root.firstChild,b=root.lastChild,r=new Range(),snapshots=[];
        r.setStart(a.firstChild,1);snapshots.push(point(r));r.setEnd(b.firstChild,2);snapshots.push(point(r));
        r.setStart(b.firstChild,3);snapshots.push(point(r));r.setEnd(a.firstChild,0);snapshots.push(point(r));
        r.setStartBefore(a);r.setEndAfter(b);snapshots.push(point(r));r.collapse();snapshots.push(point(r));
        r.selectNode(b);snapshots.push(point(r));r.collapse(true);snapshots.push(point(r));
        const detached=document.createElement('aside');r.setEnd(detached,0);snapshots.push([r.startContainer===detached,r.endContainer===detached,r.collapsed]);
        return {snapshots,orphan:error(()=>r.setStartBefore(detached)),document:error(()=>r.selectNode(document)),unchanged:r.startContainer===detached};
      }finally{root.remove();}
    },
    comparisons(){
      const root=fresh('<p id="a">abc</p><p id="b">def</p>');
      try{const a=new Range(),b=new Range(),one=root.firstChild.firstChild,two=root.lastChild.firstChild;a.setStart(one,1);a.setEnd(two,2);b.setStart(one,2);b.setEnd(two,3);
        const comparisons=[0,1,2,3].map(how=>a.compareBoundaryPoints(how,b));const points=[a.comparePoint(one,0),a.comparePoint(one,1),a.comparePoint(root,1),a.comparePoint(two,3)];
        const orphan=document.createTextNode('x'),other=new Range();other.selectNodeContents(orphan);
        return {comparisons,reverse:[0,1,2,3].map(how=>b.compareBoundaryPoints(how,a)),points,inclusive:[a.isPointInRange(one,1),a.isPointInRange(two,2),a.isPointInRange(two,3)],
          detached:a.isPointInRange(orphan,999),wrongRoot:error(()=>a.comparePoint(orphan,999)),wrongRange:error(()=>a.compareBoundaryPoints(0,other)),
          invalidHow:error(()=>a.compareBoundaryPoints(4,b)),modulo:a.compareBoundaryPoints(65536,b),
          intersections:[a.intersectsNode(root),a.intersectsNode(root.firstChild),a.intersectsNode(root.lastChild),a.intersectsNode(orphan),a.intersectsNode(document)]};
      }finally{root.remove();}
    },
    stringification(){
      const root=fresh('A😀<b id="b">BCD<i>EF</i></b><!--comment-->Z');
      try{const r=new Range(),first=root.firstChild,last=root.lastChild;r.setStart(first,1);r.setEnd(last,1);const all=String(r);r.setEnd(root.querySelector('i').firstChild,1);const partial=String(r);
        r.selectNode(root.querySelector('b'));const element=String(r);r.selectNodeContents(root);const contents=String(r);
        r.selectNodeContents(root.childNodes[2]);const comment=String(r);r.setStart(first,1);r.setEnd(first,2);const lone=String(r);
        return {all,partial,element,contents,comment,lone:[lone.length,lone.charCodeAt(0)],length:first.length};
      }finally{root.remove();}
    },
    characterData(){
      const root=fresh('abcdef');
      try{const text=root.firstChild,r=new Range();r.setStart(text,2);r.setEnd(text,5);const snapshots=[point(r)];text.insertData(1,'XY');snapshots.push(point(r));text.deleteData(3,2);snapshots.push(point(r));
        text.replaceData(2,2,'Q');snapshots.push(point(r));text.appendData('tail');snapshots.push(point(r));const selected=String(r);text.data=text.data;snapshots.push(point(r));
        const comment=document.createComment('abcd');root.append(comment);r.setStart(comment,1);r.setEnd(comment,3);comment.replaceData(1,1,'XY');const commentPoint=point(r);
        return {snapshots,selected,commentPoint,commentString:String(r)};
      }finally{root.remove();}
    },
    structuralMutations(){
      const root=fresh('<i id="a">A</i><i id="b">B</i><i id="c">C</i>');
      try{const a=root.firstChild,b=root.childNodes[1],c=root.lastChild,r=new Range(),inside=new Range();r.setStart(root,1);r.setEnd(root,3);inside.selectNodeContents(b.firstChild);
        const snapshots=[point(r)];const fragment=document.createDocumentFragment();const x=document.createElement('em');x.id='x';const y=document.createElement('em');y.id='y';fragment.append(x,y);root.insertBefore(fragment,b);snapshots.push(point(r));
        b.remove();snapshots.push(point(r));const removed=point(inside);root.append(a);snapshots.push(point(r));
        root.replaceChildren(c);snapshots.push(point(r));const detached=document.createTextNode('away'),other=new Range();other.selectNodeContents(detached);root.innerHTML='<b id="fresh">fresh</b>';snapshots.push(point(r));
        return {snapshots,removed,retained:c.parentNode===null&&c.textContent==='C',other:other.startContainer===detached&&other.endOffset===4};
      }finally{root.remove();}
    },
    splitText(){
      const root=fresh('abcdef<b id="end">Z</b>');
      try{const text=root.firstChild,r=new Range(),at=new Range(),parent=new Range();r.setStart(text,2);r.setEnd(text,5);at.setStart(text,3);at.setEnd(text,3);parent.setStart(root,1);parent.setEnd(root,2);
        const suffix=text.splitText(3);const attached={range:point(r),at:point(at),parent:point(parent),text:String(r),identity:r.endContainer===suffix};
        const detached=document.createTextNode('abcdef'),orphan=new Range();orphan.setStart(detached,2);orphan.setEnd(detached,5);const orphanSuffix=detached.splitText(3);
        return {attached,detached:point(orphan),orphanIdentity:orphan.endContainer===detached&&orphanSuffix.parentNode===null,invalid:error(()=>text.splitText(4))};
      }finally{root.remove();}
    },
    normalize(){
      const root=fresh('');
      try{const a=document.createTextNode('ab'),empty=document.createTextNode(''),b=document.createTextNode('cd'),c=document.createTextNode('ef');root.append(a,empty,b,c);
        const middle=new Range(),gap=new Range(),last=new Range();middle.setStart(b,1);middle.setEnd(c,1);gap.setStart(root,1);gap.setEnd(root,2);last.setStart(empty,0);last.setEnd(b,0);
        root.normalize();const normalized={middle:point(middle),gap:point(gap),empty:point(last),text:String(middle),retained:middle.startContainer===a&&middle.endContainer===a,count:root.childNodes.length,removed:empty.parentNode===null&&b.parentNode===null&&c.parentNode===null};
        const lead=document.createTextNode(''),word=document.createTextNode('word');root.replaceChildren(lead,word);const leading=new Range();leading.setStart(lead,0);leading.setEnd(root,1);root.normalize();
        const tail=document.createTextNode(''),trailing=new Range();root.append(tail);trailing.selectNodeContents(tail);root.normalize();
        return {normalized,leading:point(leading),word:word.parentNode===root,trailing:point(trailing),trailingIdentity:trailing.startContainer===word};
      }finally{root.remove();}
    },
    staticRange(){
      const root=fresh('abcdef');
      try{const text=root.firstChild,order=[];const init={get endContainer(){order.push('endContainer');return text;},get endOffset(){order.push('endOffset');return {valueOf(){order.push('endNumber');return 4;}};},get startContainer(){order.push('startContainer');return text;},get startOffset(){order.push('startOffset');return {valueOf(){order.push('startNumber');return 1;}};}};
        const r=new StaticRange(init);text.deleteData(0,5);const stale=point(r);
        const reversed=new StaticRange({startContainer:text,startOffset:999,endContainer:document.createTextNode('x'),endOffset:-1});
        const descriptor=descriptorFor(r,'startContainer');
        let strict='none';try{(function(){'use strict';r.startOffset=7;})();}catch(e){strict=e.name;}
        return {order,stale,invalidOffsets:[reversed.startOffset,reversed.endOffset],instance:r instanceof StaticRange&&r instanceof AbstractRange&&!(r instanceof Range),tag:Object.prototype.toString.call(r),
          methods:[typeof r.setStart,typeof r.cloneRange],descriptor:[typeof descriptor.get,descriptor.set===undefined,descriptor.enumerable,descriptor.configurable],readonly:r.startOffset===1,strict,
          missing:error(()=>new StaticRange({})),primitive:error(()=>new StaticRange(true)),called:error(()=>StaticRange(init))};
      }finally{root.remove();}
    },
    constructorTargets(){
      const root=fresh('abc');
      try{function Target(){}const custom={marker:1};Target.prototype=custom;const r=Reflect.construct(Range,[],Target);
        const start=descriptorFor(Range.prototype,'startContainer').get;
        const staticStart=descriptorFor(StaticRange.prototype,'startContainer').get;
        const order=[];const init={get endContainer(){order.push('endContainer');return root.firstChild;},get endOffset(){order.push('endOffset');return 2;},get startContainer(){order.push('startContainer');return root.firstChild;},get startOffset(){order.push('startOffset');return 1;}};
        const proxy=new Proxy(Target,{get(target,key){if(key==='prototype'){order.push('prototype');return custom;}return Reflect.get(target,key);}});
        const s=Reflect.construct(StaticRange,[init],proxy);Target.prototype=17;const fallback=Reflect.construct(Range,[],Target);
        const token={};let identity=false;try{Reflect.construct(Range,[],new Proxy(Target,{get(target,key){if(key==='prototype')throw token;return Reflect.get(target,key);}}));}catch(e){identity=e===token;}
        return {custom:Object.getPrototypeOf(r)===custom&&start.call(r)===document,static:Object.getPrototypeOf(s)===custom&&staticStart.call(s)===root.firstChild,order,
          fallback:Object.getPrototypeOf(fallback)===Range.prototype,identity,functionKeys:Object.getOwnPropertyNames(Range.prototype.setStart),constructorKeys:Object.getOwnPropertyNames(Range).slice(0,3)};
      }finally{root.remove();}
    },
    conversionsAndBrand(){
      const root=fresh('abc');
      try{const r=new Range(),text=root.firstChild,order=[];r.selectNodeContents(text);let count=0;
        r.setStart(text,{valueOf(){count++;text.data='ab';return 1;}});const after=point(r);const token={};let identity=false;
        try{r.setEnd(text,{valueOf(){throw token;}});}catch(e){identity=e===token;}
        const invalid=error(()=>Range.prototype.setStart.call({},text,{valueOf(){order.push('bad');return 0;}}));
        const getter=descriptorFor(r,'startOffset').get;
        const fake=error(()=>getter.call({}));const proto=Object.getOwnPropertyDescriptor(Range.prototype,'setStart');const constant=Object.getOwnPropertyDescriptor(Range.prototype,'START_TO_START');
        r.detach();r.selectNodeContents(text);
        return {after,count,identity,invalid,noConversion:order.length===0,fake,
          missing:error(()=>r.setStart(text)),symbol:error(()=>r.setStart(text,Symbol())),bigint:error(()=>r.setStart(text,1n)),negative:error(()=>r.setStart(text,-1)),
          invalidNode:error(()=>r.setEnd({},0)),source:error(()=>r.compareBoundaryPoints(0,new StaticRange({startContainer:text,startOffset:0,endContainer:text,endOffset:1}))),
          detached:String(r),prototype:Object.getPrototypeOf(Range.prototype)===AbstractRange.prototype&&Object.getPrototypeOf(StaticRange.prototype)===AbstractRange.prototype,
          constructorInheritance:Object.getPrototypeOf(Range)===AbstractRange&&Object.getPrototypeOf(StaticRange)===AbstractRange,
          accessorShape:[!!Object.getOwnPropertyDescriptor(AbstractRange.prototype,'startOffset'),!!Object.getOwnPropertyDescriptor(Range.prototype,'startOffset'),!!Object.getOwnPropertyDescriptor(StaticRange.prototype,'startOffset')],
          descriptor:[proto.writable,proto.enumerable,proto.configurable],constant:[constant.value,constant.writable,constant.enumerable,constant.configurable],
          lengths:[Range.length,StaticRange.length,r.setStart.length,r.compareBoundaryPoints.length,r.toString.length]};
      }finally{root.remove();}
    }
  };
})();
