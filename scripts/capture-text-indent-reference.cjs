// CSS Text reference, isolated from the user's browser session.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
(async()=>{
  const browser=await openBrowser(path.resolve(__dirname,'../build/text-indent-reference'));
  try {
    await browser.load('<!doctype html><meta charset="utf-8"><div id="sample"></div>');
    const data=await browser.evaluate(`(()=>{
      const sample=document.getElementById('sample'),range=document.createRange(),records=[];
      const cases=[{name:'soft',html:'AA BB CC DD EE'},{name:'forced',html:'AA BB<br>CC DD'},{name:'leading',html:'<br>AA BB CC'},{name:'newline',html:'AA BB\\nCC DD',whiteSpace:'pre-line'},{name:'anonymous',html:'AA<div>BB</div>CC'}];
      for(const value of ['0','10px','-10px','25%','-25%','calc(10px + 10%)'])for(const flags of ['',' hanging',' each-line',' hanging each-line'])for(const direction of ['ltr','rtl'])for(const align of ['start','center','end'])for(const input of cases)for(const columns of [3,6,20]){
        const specified=value+flags,supported=CSS.supports('text-indent',specified);
        sample.style.cssText='font:10px/20px monospace;white-space:'+ (input.whiteSpace||'normal')+';direction:'+direction+';text-align:'+align+';text-indent:'+specified;
        sample.textContent='X';range.selectNodeContents(sample);const advance=range.getBoundingClientRect().width;
        sample.style.width=(columns*advance+.01)+'px';sample.innerHTML=input.html;
        const base=sample.getBoundingClientRect(),chars=[];let source=0;const walker=document.createTreeWalker(sample,NodeFilter.SHOW_TEXT);
        while(walker.nextNode()){
          const node=walker.currentNode;
          for(let offset=0;offset<node.length;offset++){
            range.setStart(node,offset);range.setEnd(node,offset+1);const rect=Array.from(range.getClientRects()).filter(r=>r.width>0).at(-1);
            chars.push({offset:source++,text:node.data[offset],x:rect?(rect.left-base.left)/advance:null,line:rect?Math.round((rect.top-base.top)/20)+1:null});
          }
        }
        records.push({specified,supported,direction,align,name:input.name,html:input.html,whiteSpace:input.whiteSpace||'normal',columns,advance,height:base.height,chars});
      }
      return {records,userAgent:navigator.userAgent};
    })()`);
    fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/text-indent-browser.json'),JSON.stringify(data,null,2)+'\n');
    console.log('Text-indent reference:',data.records.length,'layouts,',data.records.filter(r=>r.supported).length,'supported');
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
