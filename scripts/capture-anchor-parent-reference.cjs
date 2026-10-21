const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const folder=path.resolve(__dirname,'../build/anchor-parent-reference');fs.mkdirSync(folder,{recursive:true});
const anchor=(id,left,name)=>`<div id=${id} style="position:absolute;anchor-name:${name},--ref-${id};left:${left}px;top:40px;width:80px;height:30px"></div>`;
const probe=(extra='')=>`<div id=t style="position:fixed;position-anchor:match-parent;left:anchor(left,13px);top:anchor(bottom,17px);width:anchor-size(width,45px);height:20px;${extra}"></div>`;
const parent=(inside,extra='')=>`<div id=p style="position:fixed;left:250px;top:120px;width:160px;height:100px;position-anchor:--a;${extra}">${inside}</div>`;
const first=anchor('one',100,'--a'),second=anchor('two',400,'--b');
const cases=[
 {name:'Parent chosen element and live name change',markup:first+second+parent(probe()),steps:[{equivalent:'--ref-one'},{styles:{p:'position:fixed;left:250px;top:120px;width:160px;height:100px;position-anchor:--b'},equivalent:'--ref-two'}]},
 {name:'A chain follows the immediate parent default',markup:first+parent(parent(probe(),'position-anchor:match-parent').replace('id=p','id=middle')),steps:[{equivalent:'--ref-one'}]},
 {name:'An intervening normal parent has no default',markup:first+parent(parent(probe(),'position-anchor:normal').replace('id=p','id=middle')),steps:[{equivalent:'none'}]},
 {name:'Relative parent anchor property does not apply',markup:first+parent(probe(),'position:relative;position-anchor:--a'),steps:[{equivalent:'none'}]},
 {name:'Static parent anchor property does not apply',markup:first+parent(probe(),'position:static;position-anchor:--a'),steps:[{equivalent:'none'}]},
 {name:'Missing parent default uses function fallbacks',markup:first+parent(probe(),'position-anchor:--missing'),steps:[{equivalent:'none'}]},
 {name:'None parent default and later restoration',markup:first+parent(probe(),'position-anchor:none'),steps:[{equivalent:'none'},{styles:{p:'position:fixed;left:250px;top:120px;width:160px;height:100px;position-anchor:--a'},equivalent:'--ref-one'}]},
 {name:'The child does not resolve the same name in its own scope',markup:first+parent(`<section style="anchor-scope:--a">${anchor('local',550,'--a')}${probe()}</section>`),steps:[{equivalent:'none'}]},
 {name:'Scoped immediate parent retains the selected element',markup:first+parent(probe('anchor-scope:--a')),steps:[{equivalent:'--ref-one'}]},
 {name:'Parent anchor is unacceptable for an absolute child block',markup:first+parent(probe('position:absolute;position-anchor:match-parent')),steps:[{equivalent:'none'}]},
];
const resets=[
 {css:'position-anchor:--one;position:fixed',anchor:'normal'},
 {css:'position:fixed;position-anchor:--one',anchor:'--one'},
 {css:'position-anchor:--one!important;position:fixed',anchor:'--one'},
 {css:'position-anchor:--one;position:fixed!important',anchor:'normal'},
 {css:'position-anchor:--one;position:inherit',anchor:'--parent'},
 {css:'--position:fixed;position-anchor:--one;position:var(--position)',anchor:'normal'},
 {css:'--position:invalid;position-anchor:--one;position:var(--position)',anchor:'normal'},
 {css:'position-anchor:--one;position:invalid',anchor:'--one'},
];
const picker={html:'<!doctype html><style>html,body{margin:0;padding:0}select{appearance:base-select;left:250px;top:120px;width:160px;font:16px/24px Arial}select::picker(select){appearance:base-select;position-area:none;position-try-fallbacks:none;inset:auto;margin:0;border:0;padding:0;min-width:0;position-anchor:match-parent;left:anchor(left,13px);top:anchor(bottom,17px);width:anchor-size(width,45px);height:50px}option{padding:0;border:0;height:25px;box-sizing:border-box}</style>'+first+second+'<select id=s><option id=a>A</option><option id=b>B</option></select>',steps:[
 {style:'position:static;position-anchor:--a',equivalent:'none'},
 {style:'position:fixed;position-anchor:--a',equivalent:'--ref-one'},
 {style:'position:fixed;position-anchor:--b',equivalent:'--ref-two'},
 {style:'position:fixed;position-anchor:normal',equivalent:'none'},
]};
async function main(){const browser=await openBrowser(folder);const result={captured:'2026-10-10',standard:'https://drafts.csswg.org/css-anchor-position/#position-anchor',wpt:'https://github.com/web-platform-tests/wpt/blob/master/css/css-anchor-position/position-anchor-match-parent-rendering.html',cases,resets,picker};
 try{result.browser=await browser.evaluate('navigator.userAgent');result.supports=await browser.evaluate("CSS.supports('position-anchor','match-parent')");
  for(const c of cases){c.html='<!doctype html><style>html,body{margin:0;padding:0}</style>'+c.markup;c.expected=[];
   const styles={};for(const step of c.steps){Object.assign(styles,step.styles||{});await browser.load(c.html);await browser.evaluate(`(()=>{for(const[id,style]of Object.entries(${JSON.stringify(styles)}))document.getElementById(id).style.cssText=style})()`);
    const snapshot="(()=>{const r=t.getBoundingClientRect();return {rect:[r.x,r.y,r.width,r.height],computed:getComputedStyle(t).positionAnchor,declared:t.style.positionAnchor}})()";
    const raw=await browser.evaluate(snapshot);await browser.evaluate(`t.style.positionAnchor=${JSON.stringify(step.equivalent)}`);const equivalent=await browser.evaluate(snapshot);
    c.expected.push({native:raw,equivalent,standardAnchor:'match-parent',deviation:'Chromium 154 does not parse match-parent. Native equivalent geometry names the standard-selected element explicitly; missing/inapplicable/unacceptable parent references use none.'});
   }
  }
  for(const c of resets){await browser.load('<!doctype html><div id=p style="position:absolute;position-anchor:--parent"><div id=t></div></div>');await browser.evaluate('t.style.cssText='+JSON.stringify(c.css));c.native=await browser.evaluate("({position:t.style.position,anchor:t.style.positionAnchor,computed:getComputedStyle(t).positionAnchor,css:t.style.cssText})");}
  for(const step of picker.steps){await browser.load(picker.html);await browser.evaluate('s.style.cssText='+JSON.stringify(step.style));
   const shown=await browser.send('Runtime.evaluate',{expression:'s.showPicker()',userGesture:true});if(shown.exceptionDetails)throw new Error(shown.exceptionDetails.text);
   const snapshot="(()=>{const p=getComputedStyle(s,'::picker(select)'),r=a.getBoundingClientRect();return {anchor:p.positionAnchor,rect:[r.x,r.y,parseFloat(p.width),parseFloat(p.height)]}})()";
   step.native=await browser.evaluate(snapshot);await browser.evaluate('document.styleSheets[0].insertRule('+JSON.stringify('select::picker(select){position-anchor:'+step.equivalent+'}')+')');
   await browser.evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');step.equivalentGeometry=await browser.evaluate(snapshot);
  }
 }finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/anchor-parent-browser.json'),JSON.stringify(result,null,2)+'\n');console.log('Anchor parent: '+cases.reduce((n,c)=>n+c.steps.length,0)+' equivalent native geometries; '+resets.length+' raw reset states; '+picker.steps.length+' equivalent picker geometries; unsupported match-parent retained explicitly.');
}
main().catch(error=>{console.error(error);process.exitCode=1});
