function htmlExpandedHostChecks(){
  const H='http://www.w3.org/1999/xhtml',records=[];
  function make(name){return document.createElementNS(H,'h:'+name);}
  function run(name,fn){try{records.push({name:name,value:fn()});}catch(error){records.push({name:name,value:{error:error.name}});}}
  run('prefixed-image-empty',()=>{const n=make('img');return [n instanceof HTMLImageElement,n.complete,n.naturalWidth,n.naturalHeight,n.width,n.height,n.currentSrc,n.tagName,n.prefix];});
  run('foreign-image-brand',()=>{const n=document.createElementNS('urn:foreign','img');try{Object.getOwnPropertyDescriptor(HTMLImageElement.prototype,'complete').get.call(n);return 'accepted';}catch(e){return e.name;}});
  run('prefixed-canvas-bitmap',()=>{const n=make('canvas');n.width=2;n.height=2;const c=n.getContext('2d');c.fillStyle='#336699';c.fillRect(0,0,1,1);return [n instanceof HTMLCanvasElement,c.canvas===n,n.width,n.height,Array.from(c.getImageData(0,0,1,1).data),n.tagName,n.prefix];});
  run('prefixed-canvas-default',()=>{const n=make('canvas');return [n.width,n.height,n.getContext('2d')===n.getContext('2d')];});
  run('foreign-canvas-brand',()=>{const n=document.createElementNS('urn:foreign','canvas');try{HTMLCanvasElement.prototype.getContext.call(n,'2d');return 'accepted';}catch(e){return e.name;}});
  run('prefixed-audio-empty',()=>{const n=make('audio');return [n instanceof HTMLAudioElement,n instanceof HTMLMediaElement,n.paused,n.volume,n.muted,n.currentTime,n.readyState,n.networkState,Number.isNaN(n.duration),n.error===null];});
  run('prefixed-audio-settings',()=>{const n=make('audio');n.volume=.3;n.muted=true;n.playbackRate=1.5;n.loop=true;return [n.volume,n.muted,n.playbackRate,n.loop,n.getAttribute('loop'),n.tagName];});
  run('foreign-audio-brand',()=>{const n=document.createElementNS('urn:foreign','audio');try{HTMLMediaElement.prototype.pause.call(n);return 'accepted';}catch(e){return e.name;}});
  run('prefixed-dialog-show-close',()=>{const n=make('dialog');document.body.append(n);n.show();const first=n.open;n.close('done');const result=[first,n.open,n.returnValue,n.tagName];n.remove();return result;});
  run('prefixed-dialog-modal',()=>{const n=make('dialog');document.body.append(n);n.showModal();const first=n.matches(':modal');n.close();const result=[first,n.matches(':modal'),n.open];n.remove();return result;});
  run('foreign-dialog-brand',()=>{const n=document.createElementNS('urn:foreign','dialog');try{HTMLDialogElement.prototype.show.call(n);return 'accepted';}catch(e){return e.name;}});
  run('prefixed-popover',()=>{const n=make('div');n.popover='manual';document.body.append(n);n.showPopover();const first=n.matches(':popover-open');n.hidePopover();const result=[first,n.matches(':popover-open')];n.remove();return result;});
  run('prefixed-inline-script',()=>{globalThis.expandedScriptCount=0;const n=make('script');n.textContent='globalThis.expandedScriptCount+=1';document.body.append(n);const clone=n.cloneNode(true);document.body.append(clone);return [expandedScriptCount,n.tagName,clone.tagName,n.prefix,clone.prefix];});
  run('foreign-script-inert',()=>{const n=document.createElementNS('urn:foreign','script');n.textContent='globalThis.expandedScriptCount+=100';document.body.append(n);return expandedScriptCount;});
  run('foreign-template-html-script',()=>{const t=document.createElementNS('urn:foreign','template'),s=make('script');s.textContent='globalThis.expandedScriptCount+=2';t.append(s);document.body.append(t);return expandedScriptCount;});
  run('HTML-template-script-inert',()=>{const t=make('template'),s=make('script');s.textContent='globalThis.expandedScriptCount+=4';t.content.append(s);document.body.append(t);const before=expandedScriptCount;document.body.append(t.content);return [before,expandedScriptCount];});
  run('math-container-html-script',()=>{const t=document.createElementNS('http://www.w3.org/1998/Math/MathML','m:math'),s=make('script');s.textContent='globalThis.expandedScriptCount+=8';t.append(s);document.body.append(t);return expandedScriptCount;});
  run('prefixed-SVG-script',()=>{const n=document.createElementNS('http://www.w3.org/2000/svg','s:script');n.textContent='globalThis.expandedScriptCount+=16';document.body.append(n);return [expandedScriptCount,n.tagName,n.prefix];});
  run('foreign-script-type-attribute',()=>{const n=make('script');n.setAttributeNS('urn:foreign','type','application/json');n.textContent='globalThis.expandedScriptCount+=32';document.body.append(n);return expandedScriptCount;});
  run('foreign-script-nomodule-attribute',()=>{const n=make('script');n.setAttributeNS('urn:foreign','nomodule','');n.textContent='globalThis.expandedScriptCount+=64';document.body.append(n);return expandedScriptCount;});
  run('foreign-script-src-attribute',()=>{const n=make('script');n.setAttributeNS('urn:foreign','src','data:text/javascript,expandedScriptCount=0');n.textContent='globalThis.expandedScriptCount+=128';document.body.append(n);return expandedScriptCount;});
  run('prefixed-style-owner',()=>{const n=make('style');n.textContent='#expanded-css-target { width:73px }';document.head.append(n);const target=make('div');target.id='expanded-css-target';document.body.append(target);return [n.sheet!==null,n.sheet.ownerNode===n,n.sheet.cssRules.length,getComputedStyle(target).width,n.tagName];});
  run('foreign-style-inert',()=>{const n=document.createElementNS('urn:foreign','style');n.textContent='#expanded-css-target { width:99px }';document.head.append(n);return [n.sheet===undefined,getComputedStyle(document.getElementById('expanded-css-target')).width];});
  run('foreign-style-type-attribute',()=>{const n=make('style');n.setAttributeNS('urn:foreign','type','invalid');n.textContent='#expanded-css-target { width:84px }';document.head.append(n);return [n.sheet!==null,getComputedStyle(document.getElementById('expanded-css-target')).width];});
  run('foreign-style-attribute-retains-sheet',()=>{const n=make('style');n.textContent='#expanded-css-target { width:85px }';document.head.append(n);const sheet=n.sheet;n.setAttributeNS('urn:foreign','type','text/plain');n.setAttributeNS('urn:foreign','disabled','');return [n.sheet===sheet,n.sheet.cssRules.length,getComputedStyle(document.getElementById('expanded-css-target')).width];});
  run('HTML-style-in-SVG-container',()=>{const root=document.createElementNS('http://www.w3.org/2000/svg','s:svg'),n=make('style');n.textContent='#expanded-css-target { width:86px }';root.append(n);document.body.append(root);return [n.sheet!==null,getComputedStyle(document.getElementById('expanded-css-target')).width];});
  run('prefixed-meta-language',()=>{const n=make('meta');n.setAttribute('http-equiv','content-language');n.setAttribute('content','de');document.head.append(n);return document.body.matches(':lang(de)');});
  run('foreign-meta-language',()=>{const n=document.createElementNS('urn:foreign','meta');n.setAttribute('http-equiv','content-language');n.setAttribute('content','fr');document.head.append(n);return [document.body.matches(':lang(de)'),document.body.matches(':lang(fr)')];});
  run('foreign-meta-pragma-attribute',()=>{const n=make('meta');n.setAttributeNS('urn:foreign','http-equiv','content-language');n.setAttribute('content','es');document.head.append(n);return [document.body.matches(':lang(de)'),document.body.matches(':lang(es)')];});
  run('prefixed-body-window-handler',()=>{const n=make('body'),callback=()=>1;n.onresize=callback;const result=[window.onresize===callback,n.onresize===callback];window.onresize=null;return result;});
  run('foreign-body-handler',()=>{const n=document.createElementNS('urn:foreign','body');return [n.onresize===undefined,n.onclick===undefined];});
  run('prefixed-form-handler-scope',()=>{const f=make('form'),input=make('input'),b=make('button');input.name='expandedAnswer';input.value='scope';b.setAttribute('onclick','return expandedAnswer.value');f.append(input,b);document.body.append(f);return b.onclick(new Event('click'));});
  run('global-handler-namespace-gates',()=>[H,'http://www.w3.org/2000/svg','http://www.w3.org/1998/Math/MathML','urn:foreign',null].map(ns=>{const n=document.createElementNS(ns,'div');return [ns,n.onclick===null,n.onclick===undefined];}));
  return records;
}
function htmlExpandedResourceStart(){
  const H='http://www.w3.org/1999/xhtml',waits=[];globalThis.expandedResourceLog=[];globalThis.expandedResourceValues={};
  function make(name){return document.createElementNS(H,'h:'+name);}
  function settle(name,p){waits.push(p.then(value=>{expandedResourceValues[name]=value;},error=>{expandedResourceValues[name]=error.name;}));}
  settle('foreign-decode-rejection',HTMLImageElement.prototype.decode.call(document.createElementNS('urn:foreign','img')));
  settle('prefixed-empty-decode',make('img').decode());
  const script=make('script');script.setAttributeNS('urn:foreign','type','application/json');script.src='data:text/javascript,expandedResourceLog.push("script-loaded")';
  settle('prefixed-script-load',new Promise(resolve=>{script.onload=()=>resolve([expandedResourceLog.includes('script-loaded'),script.tagName]);script.onerror=()=>resolve('error');}));document.body.append(script);
  const link=make('link');link.rel='stylesheet';link.href='data:text/css,%23expanded-css-target%7Bheight%3A45px%7D';link.setAttributeNS('urn:foreign','type','invalid');
  settle('prefixed-link-load',new Promise(resolve=>{link.onload=()=>resolve([link.sheet!==null,link.sheet.ownerNode===link,link.sheet.cssRules.length,getComputedStyle(document.getElementById('expanded-css-target')).height]);link.onerror=()=>resolve('error');}));document.head.append(link);
  const image=make('img');image.src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jq1kAAAAASUVORK5CYII=';document.body.append(image);
  settle('prefixed-image-load',image.decode().then(()=>[image.complete,image.naturalWidth,image.naturalHeight,image.width,image.height]));
  const picture=make('picture'),ignored=document.createElementNS('urn:foreign','source'),source=make('source'),responsive=make('img');
  ignored.setAttribute('srcset',image.src+'#ignored 1x');source.setAttribute('srcset',image.src+'#picture 1x');responsive.src=image.src+'#fallback';picture.append(ignored,source,responsive);document.body.append(picture);
  settle('prefixed-picture-source',responsive.decode().then(()=>[responsive.currentSrc.endsWith('#picture'),responsive.naturalWidth,responsive.naturalHeight]));
  return Promise.all(waits);
}
function htmlExpandedResourceFinish(){return Object.keys(expandedResourceValues).sort().map(name=>({name:name,value:expandedResourceValues[name]}));}
function htmlExpandedSrcsetChecks(){
  const png='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jq1kAAAAASUVORK5CYII=',one=png+'#one',two=png+'#two';
  const sources=[one+' 1x',one+',',one+' 1x, '+two+' 2x',one+' 1x,, '+two+' 2x',one+', '+two+' 2x',one+','+two,one+' nonsense(a,b), '+two+' 1x'];
  const profileSelected=[one,one,one,one,one,one+','+two,two];
  return Promise.all(sources.map((source,index)=>{const image=new Image();image.srcset=source;document.body.append(image);const result=()=>({source:source,selected:image.currentSrc,profileSelected:profileSelected[index],selection:index>=2&&index<=4?'ua-choice':'single-source'});return image.decode().then(result,result);}));
}
