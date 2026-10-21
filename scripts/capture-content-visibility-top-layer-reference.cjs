// Keep the raw browser states separate from the retained renderer's policy.
const fs = require('node:fs'), path = require('node:path'), cp = require('node:child_process');
const {openBrowser} = require('./native-browser.cjs');
const root = path.resolve(__dirname, '..');
const source = `<!doctype html><style>
body{margin:0;background:white;font:16px/20px Arial}
#outside{position:absolute;left:10px;top:10px;width:90px;height:24px}
#owner{position:absolute;left:10px;top:50px;width:180px;height:80px;background:lime}
dialog,[popover]{box-sizing:border-box;width:140px;height:80px;margin:auto;padding:8px;border:2px solid black;background:white}
</style><input id=outside><div id=owner><dialog id=dialog closedby=any><input id=inside></dialog><div id=popover popover=auto tabindex=0>Popover</div></div><script></script>`;
(async () => {
  const browser = await openBrowser(path.join(root, 'build'));
  const result = {standard:'https://drafts.csswg.org/css-contain-2/#content-visibility',htmlStandard:'https://html.spec.whatwg.org/multipage/interaction.html#modal-dialogs-and-inert-subtrees',source,states:[]};
  try {
    result.browser = await browser.send('Browser.getVersion');
    await browser.load(source);
    async function snapshot(name, operation) {
      await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
      const value = await browser.evaluate(`(()=>{
        const out={name:${JSON.stringify(name)},operation:${JSON.stringify(operation)},active:document.activeElement.id||document.activeElement.localName,ownerVisibility:getComputedStyle(owner).contentVisibility,dialog:{open:dialog.open,modal:dialog.matches(':modal')},popover:{open:popover.matches(':popover-open')}};
        for(const id of ['dialog','popover']){const e=document.getElementById(id),r=e.getBoundingClientRect();out[id].rect=[r.x,r.y,r.width,r.height];out[id].rectCount=e.getClientRects().length;out[id].contentVisibility=getComputedStyle(e).contentVisibility}
        out.cornerHit=document.elementFromPoint(4,4)?.id||document.elementFromPoint(4,4)?.localName;
        out.centerHit=document.elementFromPoint(400,300)?.id||document.elementFromPoint(400,300)?.localName;
        out.outsideHit=document.elementFromPoint(20,20)?.id||document.elementFromPoint(20,20)?.localName;
        return out;
      })()`);
      const screenshot = await browser.send('Page.captureScreenshot',{format:'png',clip:{x:0,y:0,width:8,height:8,scale:1}});
      const file = path.join(root,'build','content-visibility-top-layer-'+name+'.png');
      fs.writeFileSync(file,Buffer.from(screenshot.data,'base64'));
      value.cornerScreenshot = 'build/'+path.basename(file);
      result.states.push(value);
    }
    async function step(name, operation) { await browser.evaluate(operation); await snapshot(name, operation); }
    await step('modal-visible','outside.focus();dialog.showModal()');
    await step('modal-hidden','owner.style.contentVisibility="hidden"');
    await step('modal-hidden-outside-focus','outside.focus()');
    await step('modal-hidden-inside-focus','inside.focus()');
    await browser.send('Input.dispatchMouseEvent',{type:'mousePressed',x:4,y:4,button:'left',clickCount:1});
    await browser.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:4,y:4,button:'left',clickCount:1});
    await snapshot('modal-hidden-pointer','native pointer at (4,4)');
    await step('modal-hidden-reopen','dialog.showModal()');
    await step('modal-revealed','owner.style.contentVisibility="visible"');
    await step('modal-self-hidden','dialog.style.contentVisibility="hidden"');
    await step('modal-self-revealed','dialog.style.contentVisibility="visible"');
    await step('modal-hidden-escape-before','owner.style.contentVisibility="hidden"');
    await browser.send('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});
    await browser.send('Input.dispatchKeyEvent',{type:'keyUp',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});
    await snapshot('modal-hidden-escape-after','native Escape');
    await step('popover-hidden-open','popover.showPopover()');
    await step('popover-hidden-focus','popover.focus()');
    await browser.send('Input.dispatchMouseEvent',{type:'mousePressed',x:4,y:4,button:'left',clickCount:1});
    await browser.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:4,y:4,button:'left',clickCount:1});
    await snapshot('popover-hidden-pointer','native pointer at (4,4)');
    await step('popover-hidden-reopen','popover.matches(":popover-open")||popover.showPopover()');
    await step('popover-revealed','owner.style.contentVisibility="visible"');
    await step('popover-self-hidden','popover.style.contentVisibility="hidden"');
    await step('popover-hidden-escape-before','popover.style.contentVisibility="visible";owner.style.contentVisibility="hidden"');
    await browser.send('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});
    await browser.send('Input.dispatchKeyEvent',{type:'keyUp',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});
    await snapshot('popover-hidden-escape-after','native Escape');
    await step('popover-center-visible','owner.style.contentVisibility="visible";popover.showPopover()');
    await step('popover-center-hidden','owner.style.contentVisibility="hidden"');
    await browser.send('Input.dispatchMouseEvent',{type:'mousePressed',x:400,y:300,button:'left',clickCount:1});
    await browser.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:400,y:300,button:'left',clickCount:1});
    await snapshot('popover-hidden-center-pointer','native pointer at (400,300)');
  } finally { await browser.close(); }
  const samples=JSON.parse(cp.execFileSync('python',['-c','import json,sys;from PIL import Image;print(json.dumps([list(Image.open(p).getpixel((4,4))) for p in sys.argv[1:]]))',...result.states.map(s=>path.join(root,s.cornerScreenshot))],{encoding:'utf8'}));
  result.states.forEach((state,index)=>{state.cornerPixel=samples[index];});
  const fixture = path.join(root,'tests/fixtures/content-visibility-top-layer-browser.json');
  if(fs.existsSync(fixture)){
    const previous=JSON.parse(fs.readFileSync(fixture,'utf8')),assert=require('node:assert/strict');
    assert.equal(result.source,previous.source);
    assert.deepEqual(result.states.slice(0,previous.states.length),previous.states);
  }
  fs.writeFileSync(fixture, JSON.stringify(result,null,2)+'\n');
  console.log('Content visibility top layer: '+result.states.length+' raw browser states.');
})().catch(error => { console.error(error); process.exitCode=1; });
