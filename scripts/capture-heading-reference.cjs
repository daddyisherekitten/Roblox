// Preserve ordinary support separately from experimental IDL/AX controls.
// The :heading() selector remains a normative Selectors 5 profile.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs'),root=path.resolve(__dirname,'..');
const file=path.join(root,'tests/fixtures/heading-browser.json');
const namespace='http://www.w3.org/1999/xhtml',records=[];
for(const raw of [null,'','0','1','8','9','+2',' 3suffix','-1','1.5','1e2','0x9','bad','9'.repeat(400)]){
  records.push({name:'offset raw '+JSON.stringify(raw),source:"const h=document.createElement('h2');"+(raw===null?'':"h.setAttribute('headingoffset',"+JSON.stringify(raw)+");")+"window.headingResult=[h.headingOffset,h.headingReset,h.getAttribute('headingoffset')];"});
}
for(const value of ['0','8','9','-1','-2','4294967297','2147483648','3.9','NaN','Infinity','null',"'7'","'bad'"]){
  records.push({name:'offset setter '+value,source:"const h=document.createElement('h2');h.headingOffset="+value+";window.headingResult=[h.headingOffset,h.getAttribute('headingoffset')];"});
}
for(const value of ['false','true','0','1',"''","'false'",'null']){
  records.push({name:'reset setter '+value,source:"const h=document.createElement('h2');h.headingReset="+value+";window.headingResult=[h.headingReset,h.getAttribute('headingreset')];"});
}
records.push({name:'expanded HTML reflection',source:"const h=document.createElementNS('"+namespace+"','h:h3');h.headingOffset=5;h.headingReset=true;window.headingResult=[h.localName,h.tagName,h.headingOffset,h.headingReset,h.getAttribute('headingoffset'),h.getAttribute('headingreset')];"});
const headings=[];
const heading=(name,setup,expected)=>headings.push({name,setup,expected});
for(let rank=1;rank<=6;rank++)heading('rank '+rank,"const h=document.createElement('h"+rank+"');document.body.append(h);",rank);
heading('own offset',"const h=document.createElement('h2');h.setAttribute('headingoffset','2');document.body.append(h);",4);
heading('inclusive nested offsets',"const p=document.createElement('section'),h=document.createElement('h2');p.setAttribute('headingoffset','2');h.setAttribute('headingoffset','3');p.append(h);document.body.append(p);",7);
heading('final clamp',"const h=document.createElement('h6');h.setAttribute('headingoffset','8');document.body.append(h);",9);
heading('raw beyond reflection range',"const h=document.createElement('h1');h.setAttribute('headingoffset','9');document.body.append(h);",9);
heading('overflow raw integer',"const h=document.createElement('h1');h.setAttribute('headingoffset','"+'9'.repeat(400)+"');document.body.append(h);",9);
heading('invalid negative',"const h=document.createElement('h2');h.setAttribute('headingoffset','-3');document.body.append(h);",2);
heading('leading plus and trailing token',"const h=document.createElement('h2');h.setAttribute('headingoffset',' +2suffix');document.body.append(h);",4);
heading('own reset inclusive',"const p=document.createElement('section'),h=document.createElement('h2');p.setAttribute('headingoffset','5');h.setAttribute('headingoffset','1');h.setAttribute('headingreset','false');p.append(h);document.body.append(p);",3);
heading('ancestor reset inclusive',"const outer=document.createElement('section'),inner=document.createElement('div'),h=document.createElement('h2');outer.setAttribute('headingoffset','5');inner.setAttribute('headingoffset','1');inner.setAttribute('headingreset','');inner.append(h);outer.append(inner);document.body.append(outer);",3);
heading('prefixed HTML heading',"const h=document.createElementNS('"+namespace+"','h:h3');h.headingOffset=2;document.body.append(h);",5);
heading('prefixed HTML ancestor',"const p=document.createElementNS('"+namespace+"','h:section'),h=document.createElement('h2');p.headingOffset=2;p.append(h);document.body.append(p);",4);
heading('foreign ancestor ignored',"const p=document.createElementNS('urn:foreign','f:section'),h=document.createElement('h2');p.setAttribute('headingoffset','5');p.setAttribute('headingreset','');p.append(h);document.body.setAttribute('headingoffset','1');document.body.append(p);",3);
heading('namespaced attributes ignored',"const h=document.createElement('h2');h.setAttributeNS('urn:test','f:headingoffset','5');h.setAttributeNS('urn:test','f:headingreset','');document.body.setAttribute('headingoffset','1');document.body.append(h);",3);
heading('unprefixed namespace attributes ignored',"const h=document.createElement('h2');h.setAttributeNS('urn:test','headingoffset','5');h.setAttributeNS('urn:test','headingreset','');document.body.setAttribute('headingoffset','1');document.body.append(h);",3);
heading('shadow host ancestor',"const host=document.createElement('section');host.headingOffset=2;document.body.append(host);const shadow=host.attachShadow({mode:'open'}),h=document.createElement('h2');shadow.append(h);",4);
heading('slotted DOM ancestor',"const host=document.createElement('section');host.headingOffset=1;document.body.append(host);const shadow=host.attachShadow({mode:'open'}),slot=document.createElement('slot'),h=document.createElement('h2');slot.headingOffset=5;shadow.append(slot);host.append(h);",3);
heading('foreign heading',"const h=document.createElementNS('urn:foreign','f:h2');document.body.append(h);",null);
heading('null namespace heading',"const h=document.createElementNS(null,'h2');document.body.append(h);",null);
heading('uppercase HTML local name',"const h=document.createElementNS('"+namespace+"','h:H2');document.body.append(h);",null);
heading('ARIA independent algorithm',"const h=document.createElement('h2');h.headingOffset=1;h.setAttribute('aria-level','5');document.body.append(h);",3);
(async()=>{
  const ordinary=await openBrowser(path.join(root,'build'));
  let ordinarySupport,browserVersion;
  try{
    await ordinary.load('<!doctype html><body></body>');
    ordinarySupport=await ordinary.evaluate("(()=>{const h=document.createElement('h2');let selector;try{selector=h.matches(':heading(2)')}catch(error){selector=error.name}return {headingOffset:typeof h.headingOffset,headingReset:typeof h.headingReset,selector}})()");
    browserVersion=(await ordinary.send('Browser.getVersion')).product;
  }finally{await ordinary.close();}
  const browser=await openBrowser(path.join(root,'build'),{blinkFeatures:['HeadingOffset']});
  try{
    for(const record of records){
      await browser.load('<!doctype html><body></body>');
      record.json=await browser.evaluate(record.source+'JSON.stringify(window.headingResult)');
      if(record.name.startsWith('offset ')){
        const value=JSON.parse(record.json);
        if(value[0]>8){
          value[0]=8;record.normative={json:JSON.stringify(value),
            reference:'https://html.spec.whatwg.org/multipage/dom.html#htmlelement',
            reason:'ReflectRange=(0,8) clamps the getter to 8; the experimental Chromium getter clamps to 9. The setter content remains unchanged.'};
        }
      }
    }
    for(const record of headings){
      await browser.load('<!doctype html><body></body>');
      await browser.evaluate(record.setup+"h.textContent='HeadingControl';");
      const tree=await browser.send('Accessibility.getFullAXTree');
      const node=tree.nodes.find(node=>node.role?.value==='heading'&&node.name?.value==='HeadingControl');
      record.nativeLevel=node?.properties?.find(property=>property.name==='level')?.value.value??null;
      if(record.nativeLevel!==record.expected)record.normative={
        reference:'https://html.spec.whatwg.org/multipage/sections.html#heading-levels-&-offsets',
        reason:record.name==='ARIA independent algorithm'
          ?'AX respects aria-level. The HTML computed heading algorithm consumed by :heading() uses the native rank and offsets independently.'
          :'The experimental AX path differs from the HTML inclusive DOM ancestor, HTML namespace and shadow-host algorithm. Raw AX output is retained.'};
    }
    const fixture={browser:browserVersion,ordinarySupport,experimentalFeatures:['HeadingOffset'],records,headings,
      references:['https://html.spec.whatwg.org/multipage/sections.html#heading-levels-&-offsets','https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#reflecting-content-attributes-in-idl-attributes','https://drafts.csswg.org/selectors-5/#heading-pseudo']};
    if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify(fixture,null,2)+'\n');
    else assert.deepEqual(fixture,JSON.parse(fs.readFileSync(file,'utf8')));
    console.log(records.length+' experimental native heading IDL records + '+headings.length+' raw AX controls; ordinary selector support: '+ordinarySupport.selector);
    console.log(headings.filter(record=>record.nativeLevel!==record.expected).map(({name,expected,nativeLevel})=>({name,expected,nativeLevel})));
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
