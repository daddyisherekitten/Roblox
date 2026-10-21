const fs=require('node:fs'),path=require('node:path');const {openBrowser}=require('./native-browser.cjs');
const fields=['display','width','height','min-width','min-height','max-width','max-height','position-area','position-anchor','position-try-order','position-try-fallbacks','top','right','bottom','left','box-sizing','background-color'];
const cases=[];
for(const mode of ['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'])for(const dir of ['ltr','rtl'])for(const [kind,size]of [['fixed','width:260px;height:70px'],['percentage','width:50%;height:30%']]){
 const html='<!doctype html><style>html,body{margin:0;padding:0}select{appearance:base-select;position:fixed;left:300px;top:230px;width:120px;height:40px;writing-mode:'+mode+';direction:'+dir+'}select::picker(select){appearance:base-select;scrollbar-width:none;'+(mode==='horizontal-tb'?'min-height:0;':'min-width:0;')+size+'}option{font-size:0;display:block;min-width:0;min-height:0;padding:0;width:20px;height:20px}option::checkmark{content:none}</style><select id=s><option></option><option></option></select>';
 cases.push({name:mode+'/'+dir+'/'+kind,html,states:[]});
}
async function main(){const folder=path.resolve(__dirname,'../build/select-cssom-reference');fs.mkdirSync(folder,{recursive:true});const browser=await openBrowser(folder);const fixture={captured:'2026-10-10',standard:'https://drafts.csswg.org/cssom/#resolved-values',fields,cases};let active='start';
 try{fixture.browser=await browser.evaluate('navigator.userAgent');
  const read=()=>browser.evaluate('(()=>{const p=getComputedStyle(s,"::picker(select)");return Object.fromEntries('+JSON.stringify(fields)+'.map(k=>[k,p.getPropertyValue(k)]))})()');
  for(const c of cases){active=c.name;await browser.load(c.html);c.states.push({action:'closed',expected:await read()});
   await browser.send('Runtime.evaluate',{expression:'s.showPicker()',userGesture:true});await browser.evaluate('new Promise(r=>setTimeout(r,35))');c.states.push({action:'open',expected:await read()});
   const css='select::picker(select){width:190px;height:55px;top:5px;background-color:red}';await browser.evaluate('(()=>{const sheet=document.createElement("style");sheet.id="changed";sheet.textContent='+JSON.stringify(css)+';document.head.append(sheet)})()');await browser.evaluate('new Promise(r=>setTimeout(r,35))');c.states.push({action:'mutate',css,expected:await read()});
   await browser.send('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});await browser.send('Input.dispatchKeyEvent',{type:'keyUp',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});await browser.evaluate('new Promise(r=>setTimeout(r,35))');c.states.push({action:'close',expected:await read()});
  }
 }catch(error){throw new Error(active+': '+error.message)}finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/select-cssom-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Picker CSSOM: '+cases.reduce((n,c)=>n+c.states.length,0)+' closed/open/mutation/close states captured.');
}
main().catch(error=>{console.error(error);process.exitCode=1});
