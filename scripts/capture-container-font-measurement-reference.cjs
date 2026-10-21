// Native container-font/Grid controls for the delivered CSS Atelier article.
// Chromium is isolated; these advances do not claim Roblox glyph equivalence.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'tests/fixtures/css-atelier');
const html=fs.readFileSync(path.join(folder,'index.html'),'utf8');
const css=fs.readFileSync(path.join(folder,'styles.css'),'utf8');
const story=html.split(/\r?\n/).find(line=>line.includes('id="container-shell"')).trim();
if(!story.endsWith('</div></div></div>'))throw new Error('Missing actual nested Atelier story');
const image='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(fs.readFileSync(path.join(folder,'morning.svg'),'utf8'));
const source='<!doctype html><style>'+css+'</style>'+story.replace('src="morning.svg"','src="'+image+'"');
(async()=>{
 const browser=await openBrowser(path.join(root,'build/container-font-measurement-native'));
 const reference={captured:'2026-10-10',scope:'Actual Atelier CSS/markup, container-dependent font and Grid columns; text advances are native controls, not Roblox shaping parity.',states:[]};
 try{
  await browser.send('Emulation.setDeviceMetricsOverride',{width:1120,height:900,deviceScaleFactor:1,mobile:false});
  await browser.load(source);await browser.evaluate('document.fonts.ready');reference.browser=await browser.evaluate('navigator.userAgent');
  for(const width of [423,560,422,421,300,600,780,420,423]){
   await browser.evaluate('document.getElementById("container-shell").style.width='+JSON.stringify(width+'px'));
   reference.states.push(await browser.evaluate(`(()=>{
    const shell=document.getElementById('container-shell'),story=shell.firstElementChild,img=story.firstElementChild,copy=story.children[1],heading=copy.querySelector('h4');
    const rect=e=>{const r=e.getBoundingClientRect();return[r.x,r.y,r.width,r.height]},s=getComputedStyle(heading),columns=getComputedStyle(story).gridTemplateColumns;
    const advance={};for(const text of ['Platz','verändert','Perspektiven.']){const e=document.createElement('span');e.style.cssText='display:inline-block;white-space:pre';for(const key of ['fontFamily','fontSize','fontWeight','fontStyle','letterSpacing'])e.style[key]=s[key];e.textContent=text;document.body.appendChild(e);advance[text]=e.getBoundingClientRect().width;e.remove()}
    return{width:${width},shell:rect(shell),story:rect(story),image:rect(img),copy:rect(copy),heading:rect(heading),display:getComputedStyle(story).display,columns,fontSize:parseFloat(s.fontSize),letterSpacing:parseFloat(s.letterSpacing),advance};
   })()`));
  }
 }finally{await browser.close()}
 fs.writeFileSync(path.join(root,'tests/fixtures/container-font-measurement-browser.json'),JSON.stringify(reference,null,2)+'\n');
 console.log('Container-font measurement: '+reference.states.length+' native retained size/font/Grid states.');
})().catch(error=>{console.error(error);process.exitCode=1});
