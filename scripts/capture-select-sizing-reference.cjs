const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/select-sizing-reference');fs.mkdirSync(folder,{recursive:true});
const cases=[{
  name:'Ordinary dropdown/list modes and content sizing',
  html:'<!doctype html><style>select{font:16px monospace}</style><select id=s><option value=a selected>A</option><option value=b>A considerably longer caption</option></select>',
  code:`const s=document.getElementById('s');
const snapshot=()=>record(s.value,s.selectedIndex,s.multiple,s.size,Array.from(s.selectedOptions,o=>o.value).join(','),getComputedStyle(s).fieldSizing);
snapshot();const fixed=s.getBoundingClientRect().width;s.value='b';record(s.getBoundingClientRect().width===fixed);s.value='a';
s.size=3;snapshot();s.multiple=true;s.options[0].selected=true;s.options[1].selected=true;snapshot();s.multiple=false;snapshot();s.size=1;snapshot();
s.style.fieldSizing='content';s.value='a';snapshot();const small=s.getBoundingClientRect().width;record(small<fixed);s.value='b';record(s.getBoundingClientRect().width>small);
s.size=6;const contentHeight=s.getBoundingClientRect().height;snapshot();s.style.fieldSizing='fixed';record(s.getBoundingClientRect().height>contentHeight);s.size=0;snapshot();`,
},{
  name:'Base dropdown has UA-important content sizing',
  html:'<!doctype html><style>select{appearance:base-select;field-sizing:fixed!important}select::picker(select){appearance:base-select}</style><select id=s><button><selectedcontent></selectedcontent></button><option value=a>A</option><option value=b>A considerably longer caption</option></select>',
  code:`const s=document.getElementById('s');record(getComputedStyle(s).fieldSizing);const small=s.getBoundingClientRect().width;s.value='b';record(s.getBoundingClientRect().width>small);s.style.appearance='auto';record(getComputedStyle(s).fieldSizing);`,
},{
  name:'Fallback button text has content sizing and leaves light DOM unchanged',
  html:'<!doctype html><style>select{appearance:base-select;font:16px monospace}select::picker(select){appearance:base-select}</style><select id=s><option value=a label="Short"><b>Hidden styled children</b></option><option value=b>A considerably longer caption</option></select>',
  code:`const s=document.getElementById('s');const snapshot=()=>record(s.value,s.children.length,s.firstElementChild.tagName,getComputedStyle(s).appearance,getComputedStyle(s).fieldSizing);snapshot();const small=s.getBoundingClientRect().width;s.value='b';record(s.getBoundingClientRect().width>small);s.value='a';record(s.getBoundingClientRect().width===small);s.options[0].label='A considerably longer caption';record(s.getBoundingClientRect().width>small);s.options[0].label='Short';record(s.getBoundingClientRect().width===small);s.value='missing';record(s.value,s.selectedIndex,s.children.length);s.style.color='red';record(s.value,s.selectedIndex,s.children.length);s.options[0].label='Another';record(s.value,s.selectedIndex,s.children.length);`,
},{
  name:'First button and appearance transitions preserve selection, DOM and focus',
  html:'<!doctype html><style>select{appearance:base-select}select::picker(select){appearance:base-select}</style><form id=f><select id=s><option value=a>A</option><option value=b>B</option></select></form>',
  code:`const s=document.getElementById('s');s.focus();s.value='b';const button=document.createElement('button');button.innerHTML='<selectedcontent id="m"></selectedcontent>';s.prepend(button);const m=button.firstElementChild;const snapshot=()=>record(s.value,s.selectedIndex,m.textContent,getComputedStyle(s).appearance,document.activeElement===s);snapshot();s.style.appearance='auto';snapshot();s.value='a';snapshot();s.style.appearance='base-select';snapshot();button.remove();record(s.value,s.selectedIndex,s.children.length,document.activeElement===s);s.prepend(button);snapshot();document.getElementById('f').reset();snapshot();s.multiple=true;s.value='b';snapshot();s.multiple=false;snapshot();`,
},{
  name:'Explicit empty selectedness survives metadata and non-option mutations',
  html:'<!doctype html><form><select id=s><optgroup id=g label="Group"><option value=a>A</option><option value=b>B</option></optgroup></select></form>',
  code:`const s=document.getElementById('s'),g=document.getElementById('g'),a=s.options[0];const snapshot=()=>record(s.value,s.selectedIndex);s.value='missing';snapshot();a.label='Label';snapshot();a.value='changed';snapshot();a.textContent='Text';snapshot();a.disabled=true;snapshot();g.disabled=true;snapshot();g.disabled=false;snapshot();s.disabled=true;snapshot();s.disabled=false;snapshot();const button=document.createElement('button');button.textContent='Button';s.prepend(button);snapshot();button.remove();snapshot();const hr=document.createElement('hr');s.append(hr);snapshot();hr.remove();snapshot();a.disabled=false;const added=document.createElement('option');added.textContent='C';s.append(added);snapshot();s.value='missing';added.remove();snapshot();`,
},{
  name:'Base listbox exposes rich rows and transitions on retained author nodes',
  html:'<!doctype html><style>select{appearance:base-select;width:240px;height:76px;box-sizing:border-box;font:16px/24px monospace}option b{color:red}legend i{color:blue}</style><form id=f><select id=s multiple size=3><button id=richListButton>Hidden button</button><optgroup id=g label="Fallback group"><legend id=legend><i id=legendText>Rich group</i></legend><option id=a value=a selected><b id=bold>Alpha</b></option><option id=b value=b>Beta</option><option value=c>Gamma</option></optgroup></select></form>',
  code:`const s=document.getElementById('s'),a=document.getElementById('a'),bold=document.getElementById('bold'),legend=document.getElementById('legend'),button=document.getElementById('richListButton');const snapshot=()=>record(s.value,s.selectedIndex,Array.from(s.selectedOptions,o=>o.value).join(','));const r=s.getBoundingClientRect();record(getComputedStyle(s).display,getComputedStyle(a).display,getComputedStyle(legend).display,getComputedStyle(bold).color,getComputedStyle(document.getElementById('legendText')).color,r.width,r.height,button.getBoundingClientRect().height);snapshot();s.options[1].selected=true;snapshot();s.multiple=false;snapshot();s.multiple=true;document.getElementById('f').reset();snapshot();a.label='Label only';record(bold.getBoundingClientRect().height);a.label='';record(bold.getBoundingClientRect().height>0);legend.remove();record(s.options.length,document.getElementById('g').children.length);s.style.appearance='auto';record(getComputedStyle(s).appearance,s.value);s.style.appearance='base-select';record(getComputedStyle(s).display,s.value);`,
},{
  name:'Base option UA font-relative metrics follow final cascade and side overrides',
  html:'<!doctype html><style>select{appearance:base-select;width:240px;height:100px;box-sizing:border-box;font:16px/24px monospace}option{font-size:32px;line-height:40px;padding-right:3px}</style><select id=s size=3><option id=largeOption>Alpha</option><option>Beta</option></select>',
  code:`const s=document.getElementById('s'),a=document.getElementById('largeOption');const snapshot=()=>{const c=getComputedStyle(a);record(c.display,c.fontSize,c.lineHeight,c.paddingLeft,c.paddingRight,c.gap,c.minHeight)};snapshot();s.style.fontSize='20px';snapshot();a.style.fontSize='12px';snapshot();a.style.lineHeight='20px';snapshot();a.style.paddingLeft='2px';snapshot();a.style.paddingLeft='revert';snapshot();`,
},{
  name:'Computed gaps and physical constraints retain percentages and math rather than used dimensions',
  html:'<!doctype html><style>#metricsHost{width:400px;height:240px;font-size:16px}#metricsFlex{display:flex;width:200px;height:100px}</style><div id=metricsHost><div id=metricsFlex><div id=metricsChild>Item</div></div></div>',
  code:`const host=document.getElementById('metricsHost'),a=document.getElementById('metricsFlex'),b=document.getElementById('metricsChild');const snapshot=()=>{const c=getComputedStyle(a);record(c.width,c.minWidth,c.maxWidth,c.minHeight,c.maxHeight,c.gap,c.rowGap,c.columnGap)};snapshot();record(getComputedStyle(b).minWidth,getComputedStyle(b).minHeight);a.style.minWidth='10%';a.style.maxWidth='calc(50% - 2px)';a.style.minHeight='2em';a.style.gap='10% calc(20% + 3px)';snapshot();host.style.width='800px';snapshot();a.style.gap='normal 0';snapshot();a.style.gap='min(10%, 4px) clamp(2px, 5%, 8px)';snapshot();a.style.minWidth='calc(15% + 2px)';a.style.maxHeight='50%';snapshot();a.style.minWidth='auto';a.style.maxWidth='none';a.style.minHeight='auto';a.style.maxHeight='none';a.style.gap='initial';snapshot();`,
}];
const source=`<!doctype html><meta charset=utf-8><pre id=result></pre><script>
const cases=${JSON.stringify(cases).replaceAll('<','\\u003c')};
for(const c of cases){const frame=document.createElement('iframe');document.body.append(frame);const d=frame.contentDocument;d.open();d.write(c.html);d.close();c.expected=[];try{new Function('document','getComputedStyle','record',c.code)(d,frame.contentWindow.getComputedStyle.bind(frame.contentWindow),(...v)=>c.expected.push(v.map(String).join('|')));}catch(e){c.error=e.name+': '+e.message;}frame.remove();}
document.getElementById('result').textContent=JSON.stringify({browser:navigator.userAgent,captured:'2026-10-09',standard:'https://html.spec.whatwg.org/multipage/rendering.html#the-select-element-2',cases});
</script>`;
const file=path.join(folder,'reference.html');fs.writeFileSync(file,source);
async function capture(){
const browser=await openBrowser(folder);
let fixture;
try{await browser.load(source);fixture=JSON.parse(await browser.evaluate('document.getElementById("result").textContent'));}
finally{await browser.close();}
for(const c of fixture.cases)if(c.error)throw new Error(c.name+': '+c.error);
// Preserve Chromium's actual computed value. The current HTML UA rule is
// important and therefore overrides author-important field-sizing on a base
// dropdown. Chromium 154 sizes by content but exposes "fixed" in this case.
for(const name of ['Base dropdown has UA-important content sizing','Fallback button text has content sizing and leaves light DOM unchanged']){
  const base=fixture.cases.find(c=>c.name===name),parts=base.expected[0].split('|'),index=name.startsWith('Base dropdown')?0:4;
  if(parts[index]!=='content'){
    base.standardExpected=[...base.expected];parts[index]='content';base.standardExpected[0]=parts.join('|');
    base.standardDifference='HTML rendering specifies UA-important field-sizing:content on base dropdowns; Chromium 154 exposes fixed while sizing by content.';
  }
}
fs.writeFileSync(path.join(root,'tests/fixtures/select-sizing-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Select sizing: '+fixture.cases.length+' native sequences captured.');
}
capture().catch(error=>{console.error(error);process.exitCode=1;});

