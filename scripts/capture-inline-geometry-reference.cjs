const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/inline-geometry-reference');fs.mkdirSync(folder,{recursive:true});
const image='<img width="20" height="10" src="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'20\' height=\'10\'%3E%3C/svg%3E">';
const probes=[
 ['empty','<span id="target"></span>'+image,''],
 ['collapsed space','X <span id="target"> </span> X'+image,''],
 ['empty padding','<span id="target" style="padding:2px;border:1px solid"></span>'+image,''],
 ['background around image','<span id="target" style="background:red">'+image+'</span>',''],
 ['padded image','<span id="target" style="padding:2px;border:1px solid">'+image+'</span>',''],
 ['plain image','<span id="target">'+image+'</span>',''],
 ['neutral merged text','X<span id="target">Y Z</span>X'+image,''],
 ['source spaces','<span id="target"> X Y </span>X'+image,''],
 ['wrapped images','<span id="target">'+image+' '+image+'</span>','#host{width:30px}'],
 ['wrapped background images','<span id="target" style="background:red">'+image+' '+image+'</span>','#host{width:30px}'],
 ['hidden visibility','<span id="target" style="visibility:hidden">'+image+'</span>',''],
 ['hidden padding','<span id="target" style="visibility:hidden;padding:2px;border:1px solid">'+image+'</span>',''],
 ['hidden background','<span id="target" style="visibility:hidden;background:red">'+image+'</span>',''],
 ['hidden ancestor','<span id="target" style="padding:2px;border:1px solid">'+image+'</span>','#host{visibility:hidden}'],
 ['display none','<span id="target" style="display:none">'+image+'</span>',''],
 ['transformed ancestor','<span id="target">'+image+'</span>','#host{transform:translate(12px,8px) scale(2);transform-origin:0 0}'],
 ['static body margin','<span id="target">'+image+'</span>','body{margin:8px}'],
 ['static body padding','<span id="target">'+image+'</span>','body{margin:8px;padding:5px;border:2px solid}'],
 ['positioned body','<span id="target">'+image+'</span>','body{margin:8px;padding:5px;border:2px solid;position:relative}'],
];
(async()=>{
 const browser=await openBrowser(folder),cases=[];
 try{
  const userAgent=await browser.evaluate('navigator.userAgent');
  for(const[mode,doctype]of[['no-quirks','<!doctype html>'],['limited-quirks','<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">'],['quirks','']]){
   for(const[name,body,extra]of probes){
    const css='body{margin:0;font-size:0;line-height:20px;word-spacing:5px}#host{width:80px;padding:3px;margin:4px}'+extra;
    const html=doctype+'<html><head></head><body><div id="host">'+body+'</div></body></html>';
    await browser.load(doctype+'<html><head><style>'+css+'</style></head><body><div id="host">'+body+'</div></body></html>');
    const expected=await browser.evaluate(`(()=>{const e=document.getElementById('target');const rect=r=>[r.x,r.y,r.width,r.height];return{rects:Array.from(e.getClientRects(),rect),bounding:rect(e.getBoundingClientRect()),offset:[e.offsetLeft,e.offsetTop,e.offsetWidth,e.offsetHeight,e.offsetParent?.id||e.offsetParent?.localName||null],client:[e.clientLeft,e.clientTop,e.clientWidth,e.clientHeight,e.scrollWidth,e.scrollHeight]}})()`);
    if(expected.rects.length&&expected.rects.every(r=>r[2]===0||r[3]===0)&&JSON.stringify(expected.bounding)!==JSON.stringify(expected.rects[0])){
     expected.boundingSpec=expected.rects[0];expected.deviation='Chromium returns the last zero-height line; CSSOM View requires the first.';
    }
    cases.push({name:mode+' '+name,mode,html,css,...expected});
   }
  }
  fs.writeFileSync(path.join(root,'tests/fixtures/inline-geometry-browser.json'),JSON.stringify({browser:userAgent,captured:'2026-10-09',source:'https://drafts.csswg.org/cssom-view/#dom-element-getclientrects',cases},null,2)+'\n');
  console.log('Inline geometry: '+cases.length+' native box/offset sequences captured.');
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
