// Actual browser layout of logical DOM characters, without a browser-side
// bidi implementation. Reference captures use the isolated native browser.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
(async()=>{
 const browser=await openBrowser(path.resolve(__dirname,'../build/bidi-reference'));
 try {
  await browser.load('<!doctype html><meta charset="utf-8"><div id="sample"></div><div id="measure"></div>');
  const data=await browser.evaluate(String.raw`(()=>{
   const sample=document.getElementById('sample'),measure=document.getElementById('measure'),range=document.createRange(),records=[],measurementsByInput={};
   const inputs=[
    {name:'mixed-words',html:'ABC אבג 123 DEF'},
    {name:'mixed-word',html:'ABCאבג123DEF'},
    {name:'brackets',html:'ABC (אבג) 123 DEF'},
    {name:'numbers',html:'אבג 123 45.6 DEF'},
    {name:'arabic',html:'ABC مرحبا 123 DEF'},
    {name:'isolate',html:'אבג <span dir="ltr">ABC 123</span> דהו'},
    {name:'auto-isolate',html:'ABC <bdi>אבג 123</bdi> DEF'},
    {name:'bdo-rtl',html:'ABC <bdo dir="rtl">xyz 123 (ABC)</bdo> DEF'},
    {name:'bdo-ltr',html:'אבג <bdo dir="ltr">דהו 123 (אבג)</bdo> זחט'},
    {name:'override',html:'ABC <span style="direction:rtl;unicode-bidi:bidi-override">xyz 123</span> DEF'},
    {name:'embed',html:'ABC <span style="direction:rtl;unicode-bidi:embed">אבג 123 DEF</span> XYZ'},
    {name:'plaintext-inline',html:'ABC <span style="direction:ltr;unicode-bidi:plaintext">אבג 123</span> DEF'},
    {name:'nested',html:'אבג <bdi dir="ltr">ABC <bdi dir="rtl">דהו 123</bdi> DEF</bdi> זחט'},
    {name:'controls',html:'ABC&#x202e;xyz123&#x202c;DEF'},
    {name:'break',html:'אבג 123<br>ABC דהו'},
    {name:'preserved',html:'אבג 123   ABC',whiteSpace:'pre-wrap'},
    {name:'plaintext-lines',html:'אבג 123\nABC דהו',whiteSpace:'pre-wrap'},
    {name:'ltr-only',html:'ABC DEF GHI'},
    {name:'rtl-inline-edges',html:'ABC <span dir="rtl" style="padding-left:2px;padding-right:6px;border-left:1px solid red;border-right:3px solid blue">אבג 123 XYZ</span> DEF'},
    {name:'ltr-inline-edges',html:'אבג <span dir="ltr" style="padding-left:2px;padding-right:6px;border-left:1px solid red;border-right:3px solid blue">ABC 123 דהו</span> זחט'},
    {name:'rtl-number-edges',html:'ABC <span dir="rtl" style="padding-left:2px;padding-right:6px;border-left:1px solid red;border-right:3px solid blue">123 אבג</span> DEF'},
    {name:'hebrew-cluster',html:'ABC שָׁלוֹם 123 DEF'},
    {name:'arabic-join-control',html:'ABC لا\u200cمرحبا 123 DEF'},
    {name:'rtl-tracking',html:'אבג 123 DEF',letterSpacing:2},
   ];
   for(const input of inputs)for(const direction of ['ltr','rtl'])for(const unicodeBidi of ['normal','plaintext','bidi-override'])for(const width of [1000,140,80]){
    sample.style.cssText='margin:0;padding:0;border:0;font:16px/24px monospace;letter-spacing:'+(input.letterSpacing||0)+'px;white-space:'+(input.whiteSpace||'normal')+';text-autospace:no-autospace;text-align:start;direction:'+direction+';unicode-bidi:'+unicodeBidi+';width:'+width+'px';
    sample.innerHTML=input.html;
    measure.style.cssText='position:absolute;left:0;top:0;margin:0;padding:0;border:0;white-space:pre;font:16px/24px monospace;direction:ltr;unicode-bidi:normal;width:max-content';
    const base=sample.getBoundingClientRect(),chars=[],nodes=[],walker=document.createTreeWalker(sample,NodeFilter.SHOW_TEXT);let source=0;
    while(walker.nextNode()){
     const node=walker.currentNode;nodes.push(node.data);
     for(let offset=0;offset<node.length;){
      const code=node.data.codePointAt(offset),length=code>65535?2:1;
      range.setStart(node,offset);range.setEnd(node,offset+length);const rects=Array.from(range.getClientRects()).map(r=>({x:r.left-base.left,y:r.top-base.top,width:r.width,height:r.height}));
      chars.push({start:source+offset,finish:source+offset+length,text:node.data.slice(offset,offset+length),rects});offset+=length;
     }
     source+=node.length;
    }
    const sourceText=nodes.join(''),points=Array.from(sourceText);
    if(!measurementsByInput[input.name]){
     const measurements={};measurementsByInput[input.name]=measurements;
     const values=new Set(['',' ','0']);
     for(let first=0;first<points.length;first++)for(let last=first+1;last<=points.length;last++)values.add(points.slice(first,last).join(''));
     for(const text of values)for(const control of ['', '\u202d','\u202e']){
      const value=control+text+(control?'\u202c':'');measure.textContent=value;measurements[value]=measure.getBoundingClientRect().width;
     }
    }
    const styles=Array.from(sample.querySelectorAll('*')).map(node=>({tag:node.localName,dir:node.getAttribute('dir'),direction:getComputedStyle(node).direction,unicodeBidi:getComputedStyle(node).unicodeBidi,rtl:node.matches(':dir(rtl)')}));
    records.push({name:input.name,html:input.html,direction,unicodeBidi,width,letterSpacing:input.letterSpacing||0,whiteSpace:input.whiteSpace||'normal',source:sourceText,chars,styles,height:base.height,copied:(()=>{const selection=getSelection();selection.removeAllRanges();range.selectNodeContents(sample);selection.addRange(range);return selection.toString()})()});
   }
   const semantic=[];
   for(const html of ['<div dir="auto">123 אבג ABC</div>','<div dir="auto">123 ABC אבג</div>','<div dir="rtl"><bdi>123</bdi></div>','<div dir="auto"><bdi>אבג</bdi>ABC</div>','<div dir="auto"><span dir="invalid">אבג</span>ABC</div>','<div dir="auto"><span dir="rtl">אבג</span>ABC</div>','<div dir="auto"><textarea>אבג</textarea>ABC</div>','<div dir="rtl"><input type="tel" value="אבג"></div>','<input dir="auto" value="123 אבג">','<input dir="auto" type="text" value="123 אבג">','<input dir="auto" type="invalid" value="123 אבג">','<textarea dir="auto">אבג\nABC</textarea>','<pre dir="auto">אבג\nABC</pre>']){
    sample.innerHTML=html;
    semantic.push({html,styles:Array.from(sample.querySelectorAll('*')).map(node=>({tag:node.localName,direction:getComputedStyle(node).direction,unicodeBidi:getComputedStyle(node).unicodeBidi,rtl:node.matches(':dir(rtl)'),normativeUnicodeBidi:node.localName==='input'&&node.dir==='auto'&&node.type==='text'?'plaintext':null}))});
   }
   sample.style.cssText='';sample.innerHTML='<div id="host" dir="rtl"><span id="assigned">ABC</span></div>';
   const host=sample.querySelector('#host'),shadow=host.attachShadow({mode:'open'}),assigned=sample.querySelector('#assigned');
   shadow.innerHTML='<div id="scoped" dir="auto"><slot id="slot" dir="auto"></slot><span id="inside">123</span></div>';
   const slot=shadow.querySelector('#slot');
   const shadowSteps=[];
   const snapshot=operation=>shadowSteps.push({operation,styles:[host,assigned,...shadow.querySelectorAll('*')].map(node=>({id:node.id,direction:getComputedStyle(node).direction,unicodeBidi:getComputedStyle(node).unicodeBidi,rtl:node.matches(':dir(rtl)')}))});
   snapshot(null);
   for(const operation of [{id:'assigned',text:'אבג'},{id:'slot',dir:null},{id:'host',dir:'ltr'},{id:'assigned',text:'ABC'},{id:'host',dir:'auto'},{id:'assigned',text:'אבג'},{id:'slot',dir:'auto'},{id:'assigned',dir:'ltr'}]){
    const node=operation.id==='host'?host:operation.id==='slot'?slot:assigned;
    if('text'in operation)node.firstChild.data=operation.text;else if(operation.dir===null)node.removeAttribute('dir');else node.setAttribute('dir',operation.dir);
    snapshot(operation);
   }
   return {userAgent:navigator.userAgent,records,semantic,shadowSteps,measurements:measurementsByInput};
  })()`);
  fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/bidi-browser.json'),JSON.stringify(data,null,2)+'\n');
  console.log('Bidi reference:',data.records.length,'actual layouts;',data.semantic.length,'HTML directionality cases');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
