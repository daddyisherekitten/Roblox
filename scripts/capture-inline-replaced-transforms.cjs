const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
const ids=['photo','drawing','sound','movie','button','editor','ellipsis'];
const pixel=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/html-expanded-resource-browser.json'),'utf8')).assets.first;
const html='<!doctype html><html><head><style>html,body{margin:0;padding:0}.row{height:120px;font-size:0;line-height:0}.ellipsis{width:180px;overflow:hidden;text-overflow:ellipsis}.item{display:inline;vertical-align:top;width:40px;height:24px;padding:3px 5px;border:2px solid black;margin:7px 11px;box-sizing:content-box;appearance:none;font:12px Arial;line-height:12px}</style></head><body>'+ids.map(id=>'<div class="row'+(id==='ellipsis'?' ellipsis':'')+'">'+({photo:'<img id="photo" class="item" src="'+pixel+'" alt="">',drawing:'<canvas id="drawing" class="item" width="2" height="2"></canvas>',sound:'<audio id="sound" class="item" controls></audio>',movie:'<video id="movie" class="item" controls></video>',button:'<button id="button" class="item">OK</button>',editor:'<input id="editor" class="item" value="retained">',ellipsis:'<img id="ellipsis" class="item" src="'+pixel+'" alt="">'})[id]+'</div>').join('')+'<script></script></body></html>';
const states=[
 {name:'none',style:'transform:none'},
 {name:'translate',style:'transform:translate(12px,-4px)'},
 {name:'scale',style:'transform:scale(1.5)'},
 {name:'rotate',style:'transform:rotate(30deg)'},
 {name:'origin-composed',style:'transform:translate(9px,6px) rotate(30deg) scale(1.25);transform-origin:20% 75%'},
 {name:'origin-change',style:'transform:translate(9px,6px) rotate(30deg) scale(1.25);transform-origin:3px 7px'},
 {name:'content-reference',style:'transform:translate(50%,25%) scale(1.5);transform-box:content-box;transform-origin:25% 50%'},
 {name:'fill-reference',style:'transform:translate(50%,25%) scale(1.5);transform-box:fill-box;transform-origin:25% 50%'},
 {name:'stroke-reference',style:'transform:translate(50%,25%) scale(1.5);transform-box:stroke-box;transform-origin:25% 50%'},
 {name:'view-reference',style:'transform:translate(50%,25%) scale(1.5);transform-box:view-box;transform-origin:25% 50%'},
 {name:'individual',style:'transform:translate(2px,3px);translate:12px -4px;rotate:30deg;scale:1.25'},
 {name:'rotate-z',style:'transform:rotate3d(0,0,1,30deg)'},
 {name:'reset',style:'transform:none'},
];
const source=String.raw`window.inlineIDs=['photo','drawing','sound','movie','button','editor','ellipsis'];
window.inlineResize=[];window.inlineObserver=new ResizeObserver(es=>{for(const e of es)inlineResize.push([e.target.id,e.contentRect.width,e.contentRect.height]);});
for(const id of inlineIDs)inlineObserver.observe(document.getElementById(id));
function inlineSet(style){for(const id of inlineIDs)document.getElementById(id).style.cssText=style;}
function inlineRects(){return inlineIDs.map(id=>{const n=document.getElementById(id),r=n.getBoundingClientRect(),s=getComputedStyle(n);return{id,x:r.x,y:r.y,width:r.width,height:r.height,cssWidth:s.width,cssHeight:s.height,transform:s.transform,origin:s.transformOrigin,translate:s.translate,rotate:s.rotate,scale:s.scale,transformBox:s.transformBox,opacity:s.opacity};});}
function inlineBaseline(){const animations=typeof inlineAnimations==='undefined'?[]:inlineAnimations;const effects=animations.map(a=>[a.effect,a.currentTime]);for(const a of animations)a.effect=null;const saved=inlineIDs.map(id=>document.getElementById(id).style.cssText);for(const id of inlineIDs){const s=document.getElementById(id).style;s.transform='none';s.translate='none';s.rotate='none';s.scale='none';}const result=inlineRects();for(let i=0;i<inlineIDs.length;i++)document.getElementById(inlineIDs[i]).style.cssText=saved[i];for(let i=0;i<animations.length;i++){animations[i].effect=effects[i][0];animations[i].currentTime=effects[i][1];}return result;}
function inlineAnimate(){window.inlineAnimations=inlineIDs.map(id=>{const a=document.getElementById(id).animate([{transform:'translate(0px,0px) scale(1)'},{transform:'translate(40px,10px) scale(1.5)'}],{duration:1000,fill:'both'});a.finished.catch(()=>{});a.pause();a.currentTime=500;return a;});}
function inlineOpacityAnimate(){window.inlineAnimations=inlineIDs.map(id=>{const a=document.getElementById(id).animate([{opacity:.2,transform:'translate(0px,0px) scale(1)'},{opacity:.8,transform:'translate(20px,10px) scale(1.5)'}],{duration:1000,fill:'both'});a.finished.catch(()=>{});a.pause();a.currentTime=500;return a;});}
function inlineCancel(){for(const a of inlineAnimations)a.cancel();}
`;
(async()=>{const browser=await openBrowser(path.join(root,'build'));try{
 await browser.load(html);await browser.evaluate('document.getElementById("photo").decode()');await browser.evaluate(source);
 const snapshots=[];
 const capture=async(name,style)=>{const rects=await browser.evaluate('inlineRects()'),baseline=await browser.evaluate('inlineBaseline()');const resize=await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>{const latest={};for(const e of inlineResize)latest[e[0]]=e;resolve(inlineIDs.map(id=>latest[id]));})))');const resizeCount=await browser.evaluate('inlineResize.length');snapshots.push({name,style,rects,baseline,resize,resizeCount});};
 for(const state of states){await browser.evaluate('inlineSet('+JSON.stringify(state.style)+')');await capture(state.name,state.style);}
 await browser.evaluate('inlineAnimate()');await capture('waapi-half',null);await browser.evaluate('inlineCancel()');await capture('waapi-cancel',null);
 await browser.evaluate('inlineSet("transform:translate(50%,25%) scale(1.5);width:60px;transform-origin:20% 75%")');await capture('resize','transform:translate(50%,25%) scale(1.5);width:60px;transform-origin:20% 75%');
 await browser.evaluate('inlineSet("transform:none")');await capture('opacity-base','transform:none');await browser.evaluate('inlineOpacityAnimate()');await capture('opacity-half',null);
 await browser.evaluate('inlineSet("width:80px")');await capture('opacity-resize','width:80px');
 await browser.evaluate('inlineCancel()');await capture('opacity-cancel',null);
 const fixture={html,source,ids,snapshots,userAgent:await browser.evaluate('navigator.userAgent'),references:['https://drafts.csswg.org/css-transforms-1/#transform-rendering','https://drafts.csswg.org/css-transforms-1/#transformable-element','https://drafts.csswg.org/css-transforms-1/#transform-box','https://drafts.csswg.org/css-transforms-2/#individual-transforms','https://drafts.csswg.org/resize-observer/#calculate-box-size']};
 fs.writeFileSync(path.join(root,'tests/fixtures/inline-replaced-transforms-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Inline transforms captured: '+snapshots.length+' states / '+snapshots.length*ids.length+' native element geometries');
 }finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
