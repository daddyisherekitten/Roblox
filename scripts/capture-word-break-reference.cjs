// Isolated Chromium reference for the specified CSS Text compatibility value.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
async function capture(){
 const browser=await openBrowser(path.join(root,'build/engine-expansion-20261018/word-break-reference'));
 try{
  await browser.load('<!doctype html><meta charset="utf-8"><div id="sample"></div>');
  const version=await browser.send('Browser.getVersion');
  const result=await browser.evaluate(`(()=>{
   const sample=document.getElementById('sample'),records=[];
   const texts=['ABCDEFGHIJ','AA BBBB','AA ABCDEFGHIJ','AB<span>CDEFGH</span>IJ','ABCD<br>EFGHIJ'];
   for(const html of texts)for(const wordBreak of ['normal','break-all','break-word'])for(const overflowWrap of ['normal','break-word','anywhere'])for(const columns of [4,5,6]){
    sample.style.cssText='font:10px/20px monospace;white-space:normal;word-break:'+wordBreak+';overflow-wrap:'+overflowWrap+';width:max-content';
    sample.textContent='X';const advance=sample.getBoundingClientRect().width;
    sample.innerHTML=html;sample.style.width=(advance*columns+.01)+'px';
    const origin=sample.getBoundingClientRect(),lines=[],walker=document.createTreeWalker(sample,NodeFilter.SHOW_TEXT),range=document.createRange();
    let node;while(node=walker.nextNode())for(let index=0;index<node.length;index++){
     const char=node.data[index];if(char===' ')continue;
     range.setStart(node,index);range.setEnd(node,index+1);const rect=range.getBoundingClientRect();
     const line=Math.round((rect.top-origin.top)/20);lines[line]=(lines[line]||'')+char;
    }
    sample.style.width='min-content';const minimum=sample.getBoundingClientRect().width/advance;
    sample.style.width='max-content';const maximum=sample.getBoundingClientRect().width/advance;
    records.push({html,wordBreak,overflowWrap,columns,advance,lines:lines.filter(Boolean),minimum,maximum,computedWordBreak:getComputedStyle(sample).wordBreak,computedOverflowWrap:getComputedStyle(sample).overflowWrap});
   }
   return {records,supports:CSS.supports('word-break','break-word')};
  })()`);
  const specs=['https://drafts.csswg.org/css-text-3/#word-break-property','https://drafts.csswg.org/css-text-4/#word-break-property'];
  const standardSnapshots=[];
  for(const [index,url]of specs.entries()){
   const response=await fetch(url);if(!response.ok)throw Error('CSS Text reference HTTP '+response.status);
   const body=await response.text(),snapshot='build/engine-expansion-20261018/word-break-standard-'+index+'.html';fs.writeFileSync(path.join(root,snapshot),body);
   standardSnapshots.push({url,capturedAt:new Date().toISOString(),snapshot,sha256:crypto.createHash('sha256').update(body).digest('hex')});
  }
  const output={schema:1,capturedAt:new Date().toISOString(),browser:version.product,specs,scope:'ASCII line boundaries and min/max-content under all three overflow-wrap values; no complete word-break/CJK claim',...result,standardSnapshots};
  const destination=path.join(root,'tests/fixtures/word-break-browser.json');fs.writeFileSync(destination,JSON.stringify(output,null,2)+'\n');
  console.log('Word-break native reference:',result.records.length,'cases; SHA256',crypto.createHash('sha256').update(fs.readFileSync(destination)).digest('hex'));
 }finally{await browser.close();}
}
capture().catch(error=>{console.error(error);process.exitCode=1;});
