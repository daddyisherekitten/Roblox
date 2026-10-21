// Native text-transform output and copy, isolated from the user's browser.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
(async()=>{
  const browser=await openBrowser(path.resolve(__dirname,'../build/text-transform-reference'));
  try {
    await browser.load('<!doctype html><meta charset="utf-8"><div id="sample"></div>');
    const data=await browser.evaluate(`(()=>{
      const sample=document.getElementById('sample'),records=[];
      const cases=[
        {name:'latin',html:'Straße ẞ ǆ ǳ æ œ'},
        {name:'expansions',html:'ß ﬁ ﬃ ŉ ῄ'},
        {name:'scripts',html:'αβ ΓΔ ЙЁ աև Ⰰⰰ'},
        {name:'scripts-extended',html:'Ⴀაბ 𐐨𐐀 𞤀𞤢'},
        {name:'sigma',html:'ΟΣ ΟΣΑ Σ ΟΣ’ ΟΣ. ΟΣ́ ΟΣ́Α'},
        {name:'turkic',html:'i ı I İ İ Ị̇ Í̇'},
        {name:'lithuanian',html:'Í J̀ Į̃ Ì Í Ĩ i̇ j̇ į̇ ị̇'},
        {name:'dutch',html:'ijssel ijs IJssel iJssel ij́ssel'},
        {name:'greek-accent',html:'ά έ ή ί ό ύ ώ ΐ ΰ άυ άι η ή άυλος Μάιος ή ήχος ᾀ ᾆ ῄ'},
        {name:'word-boundaries',html:'„école“ d’art 12abc ab-cd ab—cd ab/cd ab_cd ab.cd ab:cd ⅲtest ²test a&#160;b'},
        {name:'kana',html:'ぁぃぅぇぉゃゅょっゎゕゖァィゥェォャュョッヮヵヶㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ'},
        {name:'width',html:'ABC abc 123 !? ｶﾞ ﾊﾟ ﾜﾞ ｲｪｫ ｰ ｡､･ ｢｣'},
        {name:'sigma-fragments',html:'Ο<span style="color:red">Σ</span> Ο<span>Σ́</span>A Ο<span style="font-weight:bold">Σ</span><i>́</i><b>Α</b>'},
        {name:'turkic-fragments',html:'I<span style="color:red">̇</span> I<span style="font-weight:bold">̣</span><b>̇</b>'},
        {name:'dutch-fragments',html:'i<span style="color:red">j</span>ssel i<b>j</b>ssel'},
        {name:'capitalize-fragments',html:'ab<b>cd</b> ef<span style="text-transform:none">gh</span>ij ab<span></span>cd ab<wbr>cd'},
        {name:'math-single',html:'x'}, {name:'math-greek',html:'θ'},
        {name:'math-multi',html:'xy'}, {name:'math-combining',html:'x́'},
      ];
      for(const mode of ['none','uppercase','lowercase','capitalize','full-width','full-size-kana','uppercase full-width full-size-kana','capitalize full-width','math-auto'])for(const lang of ['','en','tr','az-Latn','tr-Arab','lt','nl','el','bad--tag'])for(const input of cases){
        const supported=CSS.supports('text-transform',mode);
        sample.lang=lang;sample.style.cssText='font:20px/30px serif;white-space:normal;text-transform:'+mode;
        sample.innerHTML=input.html;
        const range=document.createRange();range.selectNodeContents(sample);const selection=getSelection();selection.removeAllRanges();selection.addRange(range);
        records.push({name:input.name,html:input.html,mode,lang,supported,computed:getComputedStyle(sample).textTransform,source:sample.textContent,display:sample.innerText,copied:selection.toString()});
      }
      return {records,userAgent:navigator.userAgent};
    })()`);
    fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/text-transform-browser.json'),JSON.stringify(data,null,2)+'\n');
    console.log('Text-transform reference:',data.records.length,'outputs');
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
