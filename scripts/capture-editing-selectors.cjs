// Frozen native controls for shared DOM/CSS/native-input editing ownership.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs'),root=path.resolve(__dirname,'..');
const file=path.join(root,'tests/fixtures/editing-selectors-browser.json');
const paintSetup="const editingPaintSheet=document.createElement('style');editingPaintSheet.textContent='#editingPaintHolder :read-only{color:rgb(91,53,17)}#editingPaintHolder :read-write{color:rgb(17,53,91)}#editingPaintHolder{background-color:rgb(3,7,11)}#editingPaintHolder:has(#editingPaintText:read-write){background-color:rgb(20,40,60)}';document.head.append(editingPaintSheet);const editingPaintHolder=document.createElement('div');editingPaintHolder.id='editingPaintHolder';editingPaintHolder.innerHTML='<p id=\"editingPaintText\">Retained editable text</p><div id=\"editingPaintIsland\" contenteditable=\"false\"><p id=\"editingPaintIslandText\">Protected text</p></div><input id=\"editingPaintInput\" value=\"retained\">';document.body.append(editingPaintHolder);const editingPaintInput=document.getElementById('editingPaintInput'),editingPaintIsland=document.getElementById('editingPaintIsland');";
const paintStates=[
 ['initial',''],
 ['editable host',"editingPaintHolder.contentEditable='true';"],
 ['plaintext host',"editingPaintHolder.contentEditable='plaintext-only';"],
 ['nested host',"editingPaintIsland.contentEditable='true';"],
 ['blocked outer host',"editingPaintHolder.contentEditable='false';"],
 ['nested inherit',"editingPaintIsland.contentEditable='inherit';"],
 ['readonly input',"editingPaintInput.readOnly=true;"],
 ['unset outer host',"editingPaintHolder.removeAttribute('contenteditable');"],
 ['document editing on',"document.designMode='on';"],
 ['document editing unchanged',"document.designMode='on';"],
 ['document editing off',"document.designMode='off';"],
 ['writable input',"editingPaintInput.readOnly=false;"],
 ['uppercase host',"editingPaintHolder.setAttribute('contenteditable','TRUE');"],
 ['invalid host',"editingPaintHolder.setAttribute('contenteditable','invalid');"],
].map(([name,code])=>({name,code}));
const paintSample="JSON.stringify(['editingPaintText','editingPaintIslandText','editingPaintInput'].map(id=>getComputedStyle(document.getElementById(id)).color).concat(getComputedStyle(editingPaintHolder).backgroundColor))";
(async()=>{
  const browser=await openBrowser(path.join(root,'build'));
  try{
    await browser.load('<!doctype html><title>Editing selector states</title><body></body>');
    const source=fs.readFileSync(path.join(root,'tests/fixtures/editing-selector-cases.js'),'utf8');
    const records=await browser.evaluate(source+'\neditingSelectorChecks()');
    for(const record of records)record.json=JSON.stringify(record.value);
    await browser.load('<!doctype html><title>Editing state paint</title><body></body>');
    await browser.evaluate(paintSetup);
    for(const state of paintStates)state.json=await browser.evaluate(state.code+paintSample);
    const normative={'document explicit false':{json:'[false,true,false]',
      reference:'https://w3c.github.io/editing/docs/execCommand/#editable',
      reason:'Editable descendants exclude an explicit contenteditable=false state even below the document editing host. Chromium designMode ignores that state; the raw native record is preserved.'}};
    for(const kind of ['range','color','hidden','submit','reset','button','image'])for(const readonly of [false,true]){
      const name='input states '+kind+' readonly '+readonly;
      const value=records.find(record=>record.name===name).value.slice();
      value[3]=false;
      normative[name]={json:JSON.stringify(value),reference:'https://html.spec.whatwg.org/multipage/semantics-other.html#selector-optional',
        reason:'HTML requires the required attribute to apply for :optional. It does not apply to this input state; Chromium still matches :optional. The raw native record is preserved.'};
    }
    const fixture={source,records,normative,paint:{setup:paintSetup,sample:paintSample,states:paintStates},browser:(await browser.send('Browser.getVersion')).product,
      references:['https://html.spec.whatwg.org/multipage/semantics-other.html#selector-read-write','https://html.spec.whatwg.org/multipage/interaction.html#editing']};
    if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify(fixture,null,2)+'\n');
    else assert.deepEqual(fixture,JSON.parse(fs.readFileSync(file,'utf8')));
    console.log(records.length+' native editing inheritance/input/namespace/shadow/designMode/reparent records verified.');
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
