// Real Chromium geometry for a paused effect created before the first frame.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
const variants=[
 ['initial example','left:22px;top:50px;width:100px;height:70px;opacity:.8'],
 ['negative offsets','left:-28px;top:18px;width:80px;height:45px;opacity:.35'],
 ['right bottom','right:21px;bottom:19px;width:130px;height:90px;opacity:.6'],
 ['percentage offsets','left:25%;top:30%;width:120px;height:60px;opacity:.8'],
 ['calculated offsets','left:calc(10% + 7px);top:calc(25% - 9px);width:110px;height:75px;opacity:.5'],
 ['relative','position:relative;left:18px;top:14px;width:100px;height:70px;opacity:.8'],
 ['flow margin','position:static;margin:24px 0 0 33px;width:100px;height:70px;opacity:.8'],
 ['nested opacity','left:20px;top:40px;width:100px;height:70px;opacity:.6','opacity:.7'],
 ['center origin rotation','left:38px;top:26px;width:110px;height:80px;opacity:.8;transform-origin:50% 50%;transform:rotate(12deg) scale(1.15) translateX(-9px)',null,['rotate(-20deg) scale(.8) translateX(-17px)','rotate(40deg) scale(1.4) translateX(29px)']],
 ['overflowing positioned child','left:230px;top:150px;width:90px;height:50px;opacity:.8','width:200px;height:100px;opacity:.7'],
 ['paint overflow origin','left:32px;top:44px;width:90px;height:60px;opacity:.5;box-shadow:-12px -8px 0 5px black'],
 ['alternate transform numbers','left:37px;top:79px;width:137px;height:53px;opacity:.7;transform:scale(.75) translateX(-31px)',null,['scale(.5) translateX(-18px)','scale(1.1) translateX(52px)']],
 ['percentage transform','left:10%;top:20%;width:150px;height:90px;opacity:.8;transform-origin:25% 75%;transform:scale(1.1) translateX(12%)',null,['translateX(-10%) scale(.9)','translateX(40%) scale(1.5)']],
 ['effect creates compositor','left:27px;top:63px;width:125px;height:55px;opacity:1',null,null,[.4,.9]],
 ['percentage matching primitives','left:10%;top:20%;width:150px;height:90px;opacity:.8;transform-origin:25% 75%;transform:translateX(12%) scale(1.1)',null,['translateX(-10%) scale(.9)','translateX(40%) scale(1.5)']],
 ['matrix accumulation equivalent pixels','left:10%;top:20%;width:150px;height:90px;opacity:.8;transform-origin:25% 75%;transform:scale(1.1) translateX(18px)',null,['translateX(-15px) scale(.9)','translateX(60px) scale(1.5)']],
];
async function main(){
 const browser=await openBrowser(path.join(root,'build/motion-base-review/native'));
 try{
  const file=path.join(root,'tests/fixtures/animation-positioned-opacity-browser.json');
  const prior=process.argv.includes('--append-new')?JSON.parse(fs.readFileSync(file,'utf8')):null;
  const records=[];
  for(const [name,style,parentStyle,frames,opacities]of variants)for(const composite of ['replace','add','accumulate']){
   const css='html,body{margin:0;padding:0}#stage{position:relative;width:340px;height:220px;'+(parentStyle||'')+'}#box{position:absolute;box-sizing:border-box;transform-origin:0 0;transform:scale(1.2) translateX(18px);'+style+'}';
   const transforms=frames||['scale(1) translateX(0px)','scale(1.4) translateX(36px)'];
   const source=`globalThis.effect=document.getElementById('box').animate(${JSON.stringify(transforms.map((transform,i)=>({transform,...(opacities?{opacity:opacities[i]}:{})})))},{duration:1000,fill:'both',composite:${JSON.stringify(composite)}});effect.pause();effect.currentTime=500;`;
   const existing=prior?.records.find(record=>record.name===name+' '+composite);
   if(existing){if(existing.css!==css||existing.source!==source)throw Error('Existing native case changed: '+existing.name);records.push(existing);continue;}
   await browser.load('<!doctype html><style>'+css+'</style><div id=stage><div id=box></div></div><script>'+source+'</script>');
   await browser.evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
   const expected=[];
   for(const resized of [false,true]){
    if(resized)await browser.evaluate("document.getElementById('stage').style.width='460px';document.getElementById('stage').style.height='280px'");
    for(const time of [500,0,250,750,1000])expected.push(await browser.evaluate(`(()=>{effect.currentTime=${time};const b=document.getElementById('box'),s=document.getElementById('stage'),br=b.getBoundingClientRect(),sr=s.getBoundingClientRect();return {resized:${resized},time:${time},rect:[br.left-sr.left,br.top-sr.top,br.width,br.height],transform:getComputedStyle(b).transform};})()`));
   }
   records.push({name:name+' '+composite,css,source,expected});
  }
  const percentageFallback=records.find(record=>record.name==='percentage transform accumulate');
  // Chromium 155 drops percentage translations when accumulating mismatched
  // primitives. Preserve its raw values and compare this one case with the
  // independently captured, mathematically equivalent pixel-valued transforms.
  percentageFallback.normativeReference='matrix accumulation equivalent pixels accumulate';
  percentageFallback.nativeDifference='Chromium 155 serializes zero translation for mismatched percentage-based accumulation. The target width remains 150px before and after resize: 12% = 18px, -10% = -15px, 40% = 60px. CSS Transforms 2 requires matrix conversion and arithmetic accumulation; the independent pixel reference retains the translations.';
  fs.writeFileSync(file,JSON.stringify({browser:await browser.send('Browser.getVersion'),records},null,2)+'\n');
  console.log('Captured '+records.length+' native cases / '+records.reduce((n,r)=>n+r.expected.length,0)+' held geometry states');
 }finally{await browser.close()}
}
main().catch(error=>{console.error(error.stack||error);process.exitCode=1});
