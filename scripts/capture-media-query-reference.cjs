const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/media-query-reference');fs.mkdirSync(folder,{recursive:true});
const queries=[
 '', ' ', '(', '()', 'all','screen','print','speech','unknown','not unknown','not all','only screen','only (width)',
 'not (width: 800px)','not (width: 800px) and (height: 600px)','not ((width: 800px) and (height: 600px))',
 'screen and (width:800px)','screen and (width:800px) or (height:600px)',
 'or and (color)','and','only','not','screen,',' , screen','bad!, screen','screen, bad!','(width:bogus), screen',
 '(unknown)','not (unknown)','not screen and (unknown)','(unknown) or (width > 0px)','(unknown) and (width < 0px)',
 'not ((unknown) and (width < 0px))','not ((unknown) or (width > 0px))',
 'unknown(function)','not unknown(function)','(unknown(function))','((width>0px) or unknown(function))',
 '(min-orientation:portrait)','not (min-orientation:portrait)','(orientation > portrait)',
 '(width:800px','(width:800px)),screen','(width:800px), (height:600px)',
 '(width > 0px) or (height > 0px) and (color)','(1px < width > 100px)',
 '(color: 8.5)','(color: 8.0)','(color: 8e0)','(color: -1)','not (color: -1)','(grid:0)','(grid:1)','(grid:2)','(grid)',
 '(width:0)','(width:800)','(width:8e2px)','(width:800.px)','(width:-1px)','not (width:-1px)',
 '(width > -1px)','(width <= -1px)','(min-width:-1px)','(max-width:-1px)','(width > 100000000px)',
 '(width:50em)','(width:50rem)','(width:100vw)','(width:100svw)','(width:100cqw)',
 '(width:calc(400px + 400px))','(width:min(900px,800px))','(width:var(--size))',
 '(aspect-ratio:4/3)','(aspect-ratio:1.3333333333333333)','(aspect-ratio:1/0)','(aspect-ratio:0/0)',
 'not (aspect-ratio:1/0)','(aspect-ratio < 1/0)','(aspect-ratio: -1/1)','(aspect-ratio:1/-1)',
 '(resolution:1dppx)','(resolution:96dpi)','(resolution:37.79527559055118dpcm)','(resolution:1x)',
 '(resolution:0)','(resolution:300dpi)','(resolution:-1dpi)','not (resolution:-1dpi)','(resolution:infinite)','(resolution:calc(2dppx / 2))',
 '(400px <= width <= 800px)','(800px >= width > 400px)','(width = 800px)','(800px = width)',
 '(width < = 800px)','(width => 800px)','(800px <= width < 800px)',
 '(w\\69 dth:800px)','scre\\65 n and (COLOR)','(WIDTH/**/:/**/800px)','(min-/**/width:1px)',
 '(orientation)','(hover)','(any-hover)','(pointer)','(any-pointer)','(prefers-color-scheme)','(forced-colors)',
 '(prefers-reduced-motion)','(prefers-reduced-transparency)','(prefers-reduced-data)','(prefers-contrast)',
 '(update)','(overflow-block)','(overflow-inline)','(scripting)','(scan)','(color-gamut)','(dynamic-range)',
 '(display-mode)','(inverted-colors)','(device-aspect-ratio:4/3)',
 'not (resolution:infinite)','(resolution < infinite)','(resolution > infinite)',
 'not print and (unknown)','not screen and (unknown)','not (width:1%)',
 '(color:calc(8))','(color:calc(8.0))','(color:calc(8/**/))','(color:calc(7.5))',
 '(aspect-ratio:calc(4)/3)','(aspect-ratio:4/calc(3))','(aspect-ratio:calc(4 / 3))',
 '(width:calc(400px+400px))','(width:calc(400px +400px))','(width:calc(400px+ 400px))',
 '(width:calc(400px/**/+/**/400px))','(width:calc(400px /*gap*/+ /*gap*/400px))',
 '(width:calc(4e2px + 400px))','(width:calc(400px + /*gap*/400px))',
 '(width:calc(400px 400px))','(width:min(800px))','(width:calc((400px + 400px)))',
 'future("line\nbreak"), screen','(future:"line\nbreak"), screen','(future:"line\nbreak")',
 '((width:800px))','(unknown [)])','(width:800px]','(width:800px),,print',
];
const discrete={
 orientation:['portrait','landscape'],hover:['none','hover'],'any-hover':['none','hover'],pointer:['none','fine','coarse'],'any-pointer':['none','fine','coarse'],
 'prefers-color-scheme':['light','dark'],'forced-colors':['none','active'],'prefers-reduced-motion':['no-preference','reduce'],
 'prefers-reduced-transparency':['no-preference','reduce'],'prefers-reduced-data':['no-preference','reduce'],'prefers-contrast':['no-preference','less','more','custom'],
 update:['none','slow','fast'],'overflow-block':['none','scroll','paged'],'overflow-inline':['none','scroll'],scripting:['none','initial-only','enabled'],
 scan:['interlace','progressive'],'color-gamut':['srgb','p3','rec2020'],'video-color-gamut':['srgb','p3','rec2020'],
 'dynamic-range':['standard','high'],'video-dynamic-range':['standard','high'],'display-mode':['browser','fullscreen','standalone','minimal-ui','picture-in-picture','window-controls-overlay'],
 'inverted-colors':['none','inverted'],'environment-blending':['opaque','additive','subtractive'],'nav-controls':['none','back'],
};
for(const [name,values] of Object.entries(discrete))for(const value of values)queries.push(`(${name}:${value})`);
const environments=[
 {name:'desktop',width:800,height:600,scale:1,type:'screen',features:[]},
 {name:'portrait and preferences',width:400,height:800,scale:2,type:'screen',features:[{name:'prefers-color-scheme',value:'dark'},{name:'prefers-reduced-motion',value:'reduce'},{name:'prefers-reduced-transparency',value:'reduce'},{name:'prefers-contrast',value:'more'}]},
 {name:'forced colors',width:800,height:600,scale:1,type:'screen',features:[{name:'forced-colors',value:'active'},{name:'prefers-contrast',value:'custom'}]},
 {name:'print',width:800,height:600,scale:1,type:'print',features:[]},
];
(async()=>{
 const browser=await openBrowser(folder),cases=[];
 try{
  const userAgent=await browser.evaluate('navigator.userAgent');await browser.load('<!doctype html><html><body><div id="target"></div></body></html>');
  for(const environment of environments){
   await browser.send('Emulation.setDeviceMetricsOverride',{width:environment.width,height:environment.height,deviceScaleFactor:environment.scale,mobile:false});
   await browser.send('Emulation.setEmulatedMedia',{media:environment.type,features:environment.features});
   const results=await browser.evaluate(`(${JSON.stringify(queries)}).map(source=>{const query=matchMedia(source);return{source,media:query.media,matches:query.matches}})`);
   const features=await browser.evaluate(`Object.fromEntries(Object.entries(${JSON.stringify(discrete)}).map(([name,values])=>[name,values.filter(value=>matchMedia('('+name+':'+value+')').matches)]))`);
   const metrics=await browser.evaluate('({width:innerWidth,height:innerHeight,deviceWidth:screen.width,deviceHeight:screen.height,resolution:devicePixelRatio})');
   const unsupported=Object.keys(discrete).filter(name=>features[name].length===0 && matchUnsupported(name,results));
   for(const result of results){
    if(result.source==='not (resolution:-1dpi)'){
     result.normativeMatches=true;result.normativeMedia='not (resolution: -1dpi)';
     result.deviation='MQ5 accepts negative resolution as a known false value; Chromium treats it as unknown.';
    }else if(result.source==='(resolution:-1dpi)'){
     result.normativeMedia='(resolution: -1dpi)';
     result.deviation='MQ5 accepts negative resolution; Chromium preserves an unknown component value.';
    }else if(result.source.includes('infinite')){
     if(result.source==='not (resolution:infinite)'||result.source==='(resolution < infinite)')result.normativeMatches=true;
     result.normativeMedia=result.source.replace('resolution:infinite','resolution: infinite');
     result.deviation='MQ5 recognizes infinite resolution; Chromium preserves an unknown value.';
    }else if(result.source==='(dynamic-range)'){
     result.normativeMatches=true;
     result.deviation='MQ5 boolean features match a supported nonzero/non-none value; Chromium returns false for standard dynamic range.';
    }
   }
   cases.push({name:environment.name,environment,metrics,features,unsupported,queries:results});
  }
  fs.writeFileSync(path.join(root,'tests/fixtures/media-query-browser.json'),JSON.stringify({browser:userAgent,captured:'2026-10-09',source:'https://drafts.csswg.org/mediaqueries-5/',cases},null,2)+'\n');
  console.log('Media queries: '+cases.length+' environments, '+cases.reduce((n,c)=>n+c.queries.length,0)+' native results captured.');
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
function matchUnsupported(name,results){
 const sample=results.find(query=>query.source.startsWith('('+name+':'));
 return sample && sample.media===sample.source;
}
