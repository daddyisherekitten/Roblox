// Pinned Gecko language examples and actual isolated Firefox/Chrome outputs.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {openBrowser}=require('./native-browser.cjs'),{openFirefox}=require('./native-firefox.cjs');
const root=path.resolve(__dirname,'..'),cache=path.join(__dirname,'data/irish-casing');
const commit='5836a062726f715fda621338a17b51aff30d0a8c';
const sourcePaths=['intl/unicharutil/util/IrishCasing.cpp','layout/generic/nsTextRunTransformations.cpp',
  ...['irish-uppercase-1.html','irish-uppercase-1-ref.html','irish-lowercase-1a.html','irish-lowercase-1-ref.html'].map(name=>'layout/reftests/text-transform/'+name)];
(async()=>{
  fs.mkdirSync(cache,{recursive:true});
  const sources={};
  for(const file of sourcePaths){
    const url='https://raw.githubusercontent.com/mozilla/gecko-dev/'+commit+'/'+file,target=path.join(cache,path.basename(file));
    if(process.argv.includes('--download')){const response=await fetch(url);if(!response.ok)throw new Error(url+': '+response.status);fs.writeFileSync(target,Buffer.from(await response.arrayBuffer()));}
    const data=fs.readFileSync(target);sources[file]={url,sha256:crypto.createHash('sha256').update(data).digest('hex')};
  }
  const licenseURL='https://www.mozilla.org/media/MPL/2.0/index.txt',licensePath=path.join(cache,'MPL-2.0.txt');
  if(process.argv.includes('--download')){const response=await fetch(licenseURL);if(!response.ok)throw new Error('MPL license: '+response.status);fs.writeFileSync(licensePath,Buffer.from(await response.arrayBuffer()));}
  const manifest={commit,license:'MPL-2.0',licenseURL,sources};fs.writeFileSync(path.join(cache,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  const firefox=await openFirefox(path.join(root,'build/irish-casing-reference'));let chrome;
  try{
    chrome=await openBrowser(path.join(root,'build/irish-casing-reference'));
    for(const browser of [firefox,chrome])await browser.load('<!doctype html><meta charset="utf-8"><div id="sample"></div>');
    const bodies=await firefox.evaluate(`(()=>{const parse=html=>new DOMParser().parseFromString(html,'text/html').body.textContent.split('/').map(value=>value.trim());return ${JSON.stringify(['irish-uppercase-1.html','irish-uppercase-1-ref.html','irish-lowercase-1a.html','irish-lowercase-1-ref.html'].map(name=>fs.readFileSync(path.join(cache,name),'utf8')))}.map(parse);})()`);
    const records=[];
    for(const [source,expected,mode]of [[bodies[0],bodies[1],'uppercase'],[bodies[2],bodies[3],'lowercase']]){
      if(source.length!==expected.length)throw new Error('Gecko source/reference lengths differ');
      source.forEach((text,index)=>records.push({name:'gecko-'+mode+'-'+index,html:text,source:text,mode,lang:'ga-IE',expected:expected[index]}));
    }
    const custom=[
      ['upper-prefix-fragments','t<span style="color:red">-</span><b>uisce</b> n<span>g</span>ael b<span>h</span><i>f</i>uil','uppercase','ga'],
      ['upper-h-fragments','h<span>É</span>ireann hataí háit hÁit','uppercase','ga'],
      ['lower-prefix-fragments','t<span style="color:red">U</span>ISCE n<span>A</span>THAIR NATHAIR','lowercase','ga'],
      ['upper-hyphens','t‐uisce t‑uisce n-éan n-Éan t-Éan','uppercase','ga'],
      ['lower-hyphens','nÉan n‐Éan n‑Éan tUISCE t-UISCE','lowercase','ga'],
      ['upper-boundaries','2bp _dt /ng (tsl) αbp b’p abp tsk t-léine','uppercase','ga'],
      ['upper-none-boundary','t<span style="text-transform:none">-</span>uisce','uppercase','ga'],
      ['upper-en-boundary','t<span lang="en">-</span>uisce','uppercase','ga'],
      ['upper-writing-system','ar aon tslí an t-uisce','uppercase','ga-Cyrl'],
      ['upper-case-combos','bhf bp dt gc hÉ mb n-éan nÁ nd ng t-uisce tÁ tsl tSl tSL tsn tsr tsa tSa tSA','uppercase','ga-Latn-IE'],
      ['capitalize','an t-uisce ar aon tslí','capitalize','ga'],
    ];
    for(const [name,html,mode,lang]of custom)records.push({name,html,mode,lang});
    const expression=`(()=>{const records=${JSON.stringify(records)},sample=document.getElementById('sample');return records.map(record=>{
      sample.lang=record.lang;sample.style.cssText='font:20px/30px serif;white-space:normal;text-transform:'+record.mode;sample.innerHTML=record.html;
      const selection=getSelection(),range=document.createRange();range.selectNodeContents(sample);selection.removeAllRanges();selection.addRange(range);
      const result={source:sample.textContent,display:sample.innerText,copied:selection.toString(),computed:getComputedStyle(sample).textTransform};
      if(sample.childNodes.length===1&&sample.firstChild.nodeType===3&&sample.textContent.length<100){result.partial=[];for(let i=0;i<sample.textContent.length;i++){range.setStart(sample.firstChild,i);range.setEnd(sample.firstChild,i+1);result.partial.push(selection.toString());}}
      return result;
    });})()`;
    const nativeFirefox=await firefox.evaluate(expression),nativeChrome=await chrome.evaluate(expression);
    records.forEach((record,index)=>{record.source=nativeFirefox[index].source;record.firefox=nativeFirefox[index];record.chrome=nativeChrome[index];});
    const fixturePath=path.join(root,'tests/fixtures/text-transform-browser.json'),fixture=JSON.parse(fs.readFileSync(fixturePath,'utf8'));
    fixture.irish={manifest,firefox:{browserVersion:firefox.capabilities.browserVersion,userAgent:firefox.capabilities.userAgent},chrome:{userAgent:await chrome.evaluate('navigator.userAgent')},records};
    fs.writeFileSync(fixturePath,JSON.stringify(fixture,null,2)+'\n');
    console.log('Irish casing reference:',records.length,'Firefox/Chrome paired outputs; Firefox',firefox.capabilities.browserVersion);
  }finally{if(chrome)await chrome.close();await firefox.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
