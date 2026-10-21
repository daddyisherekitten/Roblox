const fs = require('node:fs'), path = require('node:path');
const { openBrowser } = require('./native-browser.cjs');
const root = path.resolve(__dirname, '..'), folder = path.join(root, 'build/quirks-values-reference');
fs.mkdirSync(folder, { recursive: true });
const inputs = [];
function add(properties, values) { for (const property of properties) for (const value of values) inputs.push({ property, value }); }
add(['width','height','min-width','min-height','max-width','max-height','top','right','bottom','left','font-size','letter-spacing','word-spacing','text-indent','vertical-align'], ['20','-2.5','+2','.5','1e2']);
add(['margin','padding','border-width','border-spacing','background-position'], ['2 3','2px 3','-2 3','calc(2 + 3px)']);
add(['margin-top','padding-left','border-right-width'], ['2','-2']);
add(['clip'], ['rect(1, 20, 30, 0)','rect(auto 20 30 0)','rect(1,,20,30,0)','rect(1,20,30,0,)','rect(1,20 30,0)']);
add(['color','background-color','border-color','border-left-color'], ['abc','abcdef','123','123456','000abc','0012abc','1234','1e2','1e2f','1e0abc','12ABCD','+123','-123','12.0abc','12345abc','\\66 00']);
add(['border','background','font','box-shadow','column-gap','gap','flex-basis','inline-size','border-inline-color','outline-color','fill'], ['2 solid red','abc','20','2 3','1e2']);
add(['color','width'], ['var(--v)']);
add(['font-size'], ['0','0px','.5px']);
(async () => {
  const browser = await openBrowser(folder), cases = [];
  try {
    const userAgent = await browser.evaluate('navigator.userAgent');
    for (const [mode, doctype] of [['no-quirks','<!doctype html>'],['limited-quirks','<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">'],['quirks','']]) {
      await browser.load(doctype + '<html><head></head><body></body></html>');
      const result = await browser.evaluate('(' + function(inputs) {
        return inputs.map(({property,value}) => {
          const element = document.createElement('div'); element.style.setProperty(property, value);
          const inline = element.style.getPropertyValue(property);
          const sheet = document.createElement('style'); sheet.textContent = 'div{'+property+':'+value+'}'; document.head.append(sheet);
          const rule = sheet.sheet.cssRules[0].style.getPropertyValue(property); sheet.remove();
          const supports = CSS.supports(property,value);
          const supportsSheet = document.createElement('style'); supportsSheet.textContent = '@supports ('+property+':'+value+'){#target{--supports:yes}}';
          const target = document.createElement('div'); target.id='target'; document.body.append(target); document.head.append(supportsSheet);
          const atSupports = getComputedStyle(target).getPropertyValue('--supports') === 'yes';
          supportsSheet.remove(); target.remove();
          return {property,value,inline,rule,supports,atSupports};
        });
      } + ')(' + JSON.stringify(inputs) + ')');
      for (const probe of result) if (probe.inline !== probe.rule) {
        probe.standardInline = probe.rule;
        probe.divergence = 'CSS Color 4 quirky-color token rules; Chromium setProperty fast path treats some three-character number tokens as identifiers.';
      }
      cases.push({mode,doctype,values:result});
    }
    const extra = await browser.evaluate(`(()=>{
      document.head.innerHTML='<style>#variable{--v:20;width:var(--v);--c:abc;color:var(--c)}@keyframes t{to{width:30;color:abc}}</style>';
      document.body.innerHTML='<div id="variable"></div>';
      const e=document.getElementById('variable'),s=getComputedStyle(e);
      const k=document.styleSheets[0].cssRules[1].cssRules[0].style;
      const result={variableWidth:s.width,variableColor:s.color,keyframeWidth:k.width,keyframeColor:k.color};
      const other=new DOMParser().parseFromString('<!doctype html><body></body>','text/html');e.style.width='20';other.adoptNode(e);
      result.adoptedWidth=e.style.width;e.style.height='20';result.adoptedNewHeight=e.style.height;
      return result;
    })()`);
    fs.writeFileSync(path.join(root, 'tests/fixtures/quirks-values-browser.json'), JSON.stringify({browser:userAgent,captured:'2026-10-09',standards:['https://drafts.csswg.org/css-values-4/#deprecated-quirky-length','https://drafts.csswg.org/css-color-4/#quirky-colors'],cases,extra},null,2)+'\n');
    console.log('Quirks values: '+(inputs.length*cases.length)+' native declaration/supports probes captured.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode=1; });
