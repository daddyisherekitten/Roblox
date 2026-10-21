// CSS Text reference capture; never attaches to the user's browser.
const fs = require('node:fs'), path = require('node:path');
const { openBrowser } = require('./native-browser.cjs');
async function capture() {
  const browser = await openBrowser(path.resolve(__dirname, '../build/whitespace-reference'));
  try {
    await browser.load('<!doctype html><meta charset="utf-8"><div id="sample"></div>');
    const data = await browser.evaluate(`(() => {
      const sample = document.getElementById('sample');
      const cases = [
        {name:'spaces', html:'  AA   BB CC  '},
        {name:'tabs-newline', html:' AA\\tBB\\n CC\\tDD '},
        {name:'inline', html:'AA <span>  BB </span> CC'},
        {name:'newline-inline', html:'AA<span>  </span>\\n<span>  BB</span>'},
        {name:'only-space', html:'     '},
        {name:'only-newlines', html:'\\n\\n'},
        {name:'trailing', html:'AA  ',align:'center'},
        {name:'forced', html:'AA  <br>BB  ',align:'center'},
        {name:'encoded-cr', html:'AA&#13;BB'},
        {name:'encoded-ff', html:'AA&#12;BB'},
        {name:'mixed-collapse', html:'AA <span style="white-space-collapse:preserve">  BB  </span> CC'},
        {name:'oversized-centered',html:'AAAAAAAAAAAA',align:'center'},
        {name:'oversized-right',html:'AAAAAAAAAAAA',align:'right'},
      ];
      const values = ['collapse','discard','preserve','preserve-breaks','preserve-spaces','break-spaces'];
      const records = [], supports = [];
      for (const collapse of values) for (const wrap of ['wrap','nowrap']) {
        supports.push({collapse,wrap,supported:CSS.supports('white-space-collapse',collapse)&&CSS.supports('text-wrap-mode',wrap)});
        for (const input of cases) for (const columns of [3,6,20]) {
          sample.style.cssText='font:10px/20px monospace;white-space-collapse:'+collapse+';text-wrap-mode:'+wrap+';tab-size:4;text-align:'+(input.align||'left');
          sample.textContent='X';
          const range=document.createRange();range.selectNodeContents(sample);
          const advance=range.getBoundingClientRect().width;
          sample.style.width=(columns*advance+.01)+'px';sample.innerHTML=input.html;
          const base=sample.getBoundingClientRect(), chars=[];let source=0;
          const walker=document.createTreeWalker(sample,NodeFilter.SHOW_TEXT);
          while(walker.nextNode()) {
            const node=walker.currentNode;
            for(let offset=0;offset<node.length;offset++) {
              range.setStart(node,offset);range.setEnd(node,offset+1);
              const rects=Array.from(range.getClientRects());
              const rect=rects.filter(r=>r.width>0).at(-1)||rects.at(-1);
              chars.push({offset:source++,text:node.data[offset],x:rect?(rect.left-base.left)/advance:null,line:rect?Math.round((rect.top-base.top)/20)+1:null,width:rect?rect.width/advance:null});
            }
          }
          const selection=getSelection();selection.removeAllRanges();range.selectNodeContents(sample);selection.addRange(range);const copied=selection.toString();selection.removeAllRanges();
          records.push({name:input.name,html:input.html,align:input.align||'left',collapse,wrap,columns,advance,height:base.height,scroll:sample.scrollWidth,copied,computed:{collapse:getComputedStyle(sample).whiteSpaceCollapse,wrap:getComputedStyle(sample).textWrapMode,whiteSpace:getComputedStyle(sample).whiteSpace},chars});
        }
      }
      const shorthand=['normal','nowrap','pre','pre-wrap','pre-line','break-spaces','collapse nowrap','preserve wrap','wrap preserve-breaks','preserve-breaks nowrap','break-spaces nowrap','preserve-spaces nowrap','discard wrap','nowrap nowrap','collapse preserve','normal wrap','nowrap preserve nowrap'].map(value=>{
        sample.style.cssText='white-space:'+value;
        return {value,supported:CSS.supports('white-space',value),specified:sample.style.whiteSpace,computed:getComputedStyle(sample).whiteSpace};
      });
      return {supports,shorthand,records,userAgent:navigator.userAgent};
    })()`);
    fs.writeFileSync(path.resolve(__dirname, '../tests/fixtures/whitespace-browser.json'), JSON.stringify(data,null,2)+'\n');
    console.log('Whitespace reference:',data.records.length,'layouts,',data.supports.filter(value=>value.supported).length,'supported axis pairs');
  } finally { await browser.close(); }
}
capture().catch(error=>{console.error(error);process.exitCode=1;});
