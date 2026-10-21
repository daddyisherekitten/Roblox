// Original canvas captures plus explicit owner/invalid-image/state reversals.
// Uses an isolated browser; PNG samples are stored as raw RGBA, never normalized
// to the separately recorded frozen-standard expectations.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const { openBrowser } = require('./native-browser.cjs');

const H = 'http://www.w3.org/1999/xhtml';
const folder = path.resolve(__dirname, '../build/canvas-background-reference');
const target = path.resolve(__dirname, '../tests/fixtures/canvas-background-browser.json');
const references = {
  root: 'https://www.w3.org/TR/2024/CRD-css-backgrounds-3-20240311/#root-background',
  body: 'https://www.w3.org/TR/2024/CRD-css-backgrounds-3-20240311/#body-background',
  transform: 'https://www.w3.org/TR/2019/CR-css-transforms-1-20190214/#transform-rendering',
  currentcolor: 'https://www.w3.org/TR/2026/CRD-css-color-4-20261009/#currentcolor-color',
  emptyURL: 'https://www.w3.org/TR/2024/CRD-css-values-3-20240322/#empty-urls',
};
const basicPoints = [60, 119, 120, 300, 540].map(y => [400, y]);
const planePoints = [0, 5, 10, 19, 20, 21, 39, 40, 59, 60, 79, 80, 119, 120, 139, 140, 300, 599]
  .map(y => [400, y]).concat([[10, 10], [10, 30]]);
const edgePoints = [0, 5, 14, 19, 20, 23, 24, 33, 34, 59, 60, 70, 93, 119, 120, 124, 143, 147,
  148, 153, 154, 163, 164, 167, 168, 179, 180, 239, 240, 273, 274, 299, 300, 304, 599]
  .map(y => [400, y]).concat([5, 19, 20, 23, 24, 33, 34, 780].map(x => [x, 60]));

function mount(rootCSS, bodyCSS, overrides = {}) {
  return { rootCSS, bodyCSS, rootName: 'html', rootNamespace: H, bodyName: 'body',
    bodyNamespace: H, kind: 'direct', ...overrides };
}
const ordinary = [
  ['ordinary', 'html', 'body', '', ''],
  ['prefixed', 'h:html', 'h:body', '', ''],
  ['hidden-body', 'html', 'body', 'visibility:hidden', ''],
  ['root-image', 'html', 'body', '', 'background-image:linear-gradient(red,red)'],
  ['contained-body', 'html', 'body', 'contain:paint', ''],
  ['contained-root', 'html', 'body', '', 'contain:layout'],
  ['foreign-body', 'html', 'f:body', '', ''],
  ['no-namespace-body', 'html', 'body', '', ''],
].map(([id, rootName, bodyName, bodyExtra, rootExtra]) => ({
  id, group: 'owner', constructed: true, points: basicPoints,
  mount: mount('margin:0;' + rootExtra,
    'display:block;margin:0;height:120px;background:rgb(20,80,140);' + bodyExtra,
    { rootName, bodyName, bodyNamespace: id === 'foreign-body' ? 'urn:foreign' : id === 'no-namespace-body' ? null : H }),
}));
const extras = [
  ['alpha-body', '', 'background:rgba(20,80,140,.5)'],
  ['alpha-root', 'background:rgba(20,80,140,.5)', 'background:none'],
  ['root-image-no-repeat', 'height:120px;background-image:linear-gradient(red,blue);background-repeat:no-repeat', 'background:none'],
  ['root-image-repeat', 'height:120px;background-image:linear-gradient(red,blue)', 'background:none'],
  ['hidden-root', 'visibility:hidden', ''],
  ['display-none-body', '', 'display:none'],
  ['contained-size-body', '', 'contain:size'],
  ['contained-style-root', 'contain:style', ''],
  ['content-visibility-auto-body', '', 'content-visibility:auto'],
  ['no-direct-body', '', '', 'nested'],
  ['root-background-with-containment', 'contain:layout;background:red', ''],
  ['body-opacity', '', 'opacity:.5'],
].map(([id, rootExtra, bodyExtra, kind]) => ({
  id, group: 'extra', constructed: true, points: basicPoints,
  mount: mount('margin:0;' + rootExtra,
    'display:block;margin:0;height:120px;background:rgb(20,80,140);' + bodyExtra,
    { kind: kind || 'direct' }),
}));
const plane = [
  { id: 'root-opacity-own', owner: 'root', effect: 'opacity:.5' },
  { id: 'root-opacity-propagated', owner: 'body', effect: 'opacity:.5' },
  { id: 'root-translate-own', owner: 'root', effect: 'transform:translateY(20px)' },
  { id: 'root-translate-propagated', owner: 'body', effect: 'transform:translateY(20px)' },
  { id: 'root-translate-pattern-own', owner: 'root', effect: 'transform:translateY(20px)', pattern: true },
  { id: 'root-translate-pattern-propagated', owner: 'body', effect: 'transform:translateY(20px)', pattern: true },
].map(item => {
  const paint = 'rgb(20,80,140)' + (item.pattern
    ? ' repeating-linear-gradient(red 0px,red 20px,blue 20px,blue 40px)' : '');
  const base = 'display:block;margin:0;height:120px;';
  return { ...item, group: 'root-plane', points: planePoints,
    mount: mount(base + item.effect + ';background:' + (item.owner === 'root' ? paint : 'none'),
      base + 'background:' + (item.owner === 'body' ? paint : 'none')),
    markerCSS: 'position:absolute;left:5px;top:5px;width:10px;height:10px;background:rgb(200,10,10)',
  };
});
const rootEdges = 'margin:20px;border:4px solid black;padding:10px;height:120px;';
const bodyEdges = 'margin:15px;border:3px solid orange;padding:6px;height:70px;';
const edges = [
  { id: 'body-gradient-currentcolor', rootCSS: 'margin:0;height:120px;color:red;',
    bodyCSS: 'margin:0;height:120px;color:blue;background-image:linear-gradient(currentColor,white);',
    change: { selector: 'body', property: 'color', value: 'lime' } },
  { id: 'root-gradient-currentcolor', rootCSS: 'margin:0;height:120px;color:red;background-image:linear-gradient(currentColor,white);',
    bodyCSS: 'margin:0;height:120px;color:blue;', change: { selector: 'html', property: 'color', value: 'lime' } },
  { id: 'body-color-currentcolor', rootCSS: 'margin:0;height:120px;color:red;',
    bodyCSS: 'margin:0;height:120px;color:blue;background-color:currentColor;',
    change: { selector: 'body', property: 'color', value: 'lime' } },
  ...['padding-box', 'content-box', 'border-box'].map(origin => ({
    id: 'body-gradient-root-edges-' + origin, rootCSS: rootEdges,
    bodyCSS: bodyEdges + 'background-image:linear-gradient(red,blue);background-origin:' + origin + ';background-clip:content-box;',
  })),
  { id: 'body-gradient-root-edges-no-repeat', rootCSS: rootEdges,
    bodyCSS: bodyEdges + 'background-image:linear-gradient(red,blue);background-origin:content-box;background-repeat:no-repeat;background-clip:content-box;' },
].map(({ rootCSS, bodyCSS, ...item }) => ({ ...item, group: 'currentcolor-edges', points: edgePoints,
  mount: mount(rootCSS, bodyCSS) }));
const dark = [
  { id: 'dark-transparent-root', opacity: 1, bodyPaint: 'transparent' },
  { id: 'dark-transparent-root-half', opacity: .5, bodyPaint: 'transparent' },
  { id: 'dark-body-blue-half', opacity: 1, bodyPaint: 'rgba(20,80,140,.5)' },
  { id: 'dark-body-blue-half-root-half', opacity: .5, bodyPaint: 'rgba(20,80,140,.5)' },
].map(item => ({ ...item, group: 'dark-ua',
  points: [10, 60, 119, 120, 300, 599].map(y => [400, y]).concat([[10, 10], [0, 0]]),
  mount: mount('display:block;margin:0;height:120px;color-scheme:dark;opacity:' + item.opacity + ';background:none',
    'display:block;margin:0;height:120px;background:' + item.bodyPaint),
  markerCSS: 'position:absolute;left:5px;top:5px;width:10px;height:10px;background:rgb(200,10,10)',
}));
const containers = ['body', 'root'].flatMap(owner => ['size', 'inline-size', 'normal', 'scroll-state'].map(containerType => ({
  id: owner + '-' + containerType, group: 'container-type', owner, containerType,
  points: [60, 119, 120, 300, 599].map(y => [400, y]),
  mount: mount('display:block;margin:0;height:120px;background:none;' + (owner === 'root' ? 'container-type:' + containerType : ''),
    'display:block;margin:0;height:120px;background:rgb(20,80,140);' + (owner === 'body' ? 'container-type:' + containerType : '')),
})));
const ownerControls = ['frameset-only', 'two-bodies', 'frameset-before-body'].map(kind => ({
  id: 'owner-' + kind, group: 'owner-eligibility', constructed: true,
  points: [60, 119, 120, 139, 160, 300, 599].map(y => [400, y]),
  mount: mount('display:block;margin:0;background:none;',
    'display:block;margin:0;height:120px;background:rgb(20,80,140);', { kind }),
}));
const invalidImages = [
  ['empty-quoted', 'url("")'], ['empty-bare', 'url()'],
  ['failed', 'url("about:invalid#canvas-missing")'],
  ['unsupported-type', 'image-set(url("about:invalid#canvas-unavailable") 1x type("application/x-canvas-unavailable"))'],
  ['none-failed-layer', 'none,url("about:invalid#canvas-missing")'],
].map(([id, value]) => ({
  id: 'image-eligibility-' + id, group: 'image-eligibility', points: basicPoints,
  mount: mount('display:block;margin:0;height:120px;background:none;',
    'display:block;margin:0;height:120px;background:rgb(20,80,140);'),
  operations: [{ selector: 'html', property: 'backgroundImage', value },
    { selector: 'html', property: 'backgroundImage', value: 'none' }],
  expectedDiagnostics: id === 'failed' || id === 'none-failed-layer' ? 1 : 0,
}));
const stateDefinitions = [
  ['display', ['none'], 'block'], ['visibility', ['hidden'], 'visible'],
  ['contain', ['size', 'layout', 'style', 'paint', 'content', 'strict'], 'none'],
  ['contentVisibility', ['auto', 'hidden'], 'visible'],
  ['containerType', ['size', 'inline-size', 'normal', 'scroll-state'], 'normal'],
];
const stateControls = ['html', 'body'].flatMap(selector => stateDefinitions.map(([property, values, reset]) => ({
  id: 'state-' + selector + '-' + property, group: 'source-state-reversal', points: basicPoints,
  mount: mount('display:block;margin:0;height:120px;background:none;',
    'display:block;margin:0;height:120px;background:rgb(20,80,140);'),
  operations: values.flatMap(value => [{ selector, property, value }, { selector, property, value: reset }]),
})));
const extensionCases = [...ownerControls, ...invalidImages, ...stateControls];

function documentHTML(item) {
  return '<!doctype html><html><head><style>html{' + item.mount.rootCSS + '}body{' + item.mount.bodyCSS + '}'
    + (item.markerCSS ? '#marker{' + item.markerCSS + '}' : '')
    + '</style></head><body>' + (item.markerCSS ? '<div id="marker"></div>' : '') + '</body></html>';
}
function samplePNG(buffer, points) {
  const script = 'import sys,json,io\nfrom PIL import Image\n'
    + 'im=Image.open(io.BytesIO(sys.stdin.buffer.read())).convert("RGBA")\n'
    + 'points=json.loads(sys.argv[1])\n'
    + 'print(json.dumps({"size":list(im.size),"pixels":[{"point":p,"rgba":list(im.getpixel(tuple(p)))} for p in points]}))';
  const result = cp.spawnSync(process.env.PYTHON_BIN || 'python', ['-c', script, JSON.stringify(points)],
    { input: buffer, windowsHide: true, maxBuffer: 1024 * 1024 });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('PNG pixel sampling failed: ' + result.stderr);
  return JSON.parse(result.stdout.toString('utf8'));
}
const snapshotExpression = `(()=>{
  function state(e){if(!e)return null;const r=e.getBoundingClientRect(),s=getComputedStyle(e);return {
    nodeName:e.nodeName,localName:e.localName,namespaceURI:e.namespaceURI,prefix:e.prefix,
    rect:[r.x,r.y,r.width,r.height],display:s.display,visibility:s.visibility,opacity:s.opacity,
    transform:s.transform,transformOrigin:s.transformOrigin,color:s.color,colorScheme:s.colorScheme,
    authoredBackgroundImage:e.style.backgroundImage,
    backgroundColor:s.backgroundColor,backgroundImage:s.backgroundImage,backgroundOrigin:s.backgroundOrigin,
    backgroundClip:s.backgroundClip,backgroundSize:s.backgroundSize,backgroundPosition:s.backgroundPosition,
    backgroundRepeat:s.backgroundRepeat,backgroundAttachment:s.backgroundAttachment,contain:s.contain,
    contentVisibility:s.contentVisibility,containerType:s.containerType,margin:[s.marginTop,s.marginRight,s.marginBottom,s.marginLeft],
    padding:[s.paddingTop,s.paddingRight,s.paddingBottom,s.paddingLeft],
    border:[s.borderTopWidth,s.borderRightWidth,s.borderBottomWidth,s.borderLeftWidth],size:[s.width,s.height]};}
  const root=document.documentElement,body=document.getElementById('audit-body')||document.body;
  return {root:state(root),body:state(body),marker:state(document.getElementById('marker')),
    documentBody:document.body===body,viewport:[innerWidth,innerHeight],scroll:[scrollX,scrollY],
    scrollSize:[root.scrollWidth,root.scrollHeight],serializedRoot:root.outerHTML};
})()`;
async function frames(browser, count = 2) {
  await browser.evaluate('new Promise(resolve=>{let n=' + count + ';const step=()=>--n?requestAnimationFrame(step):resolve();requestAnimationFrame(step)})');
}
async function capture(browser, item, label, expression = snapshotExpression) {
  await frames(browser);
  const snapshot = await browser.evaluate(expression);
  if (item.group === 'container-type') snapshot.supports = await browser.evaluate('CSS.supports("container-type",' + JSON.stringify(item.containerType) + ')');
  const png = Buffer.from((await browser.send('Page.captureScreenshot', { format: 'png', fromSurface: true })).data, 'base64');
  fs.writeFileSync(path.join(folder, item.id + '-' + label + '.png'), png);
  const sampled = samplePNG(png, item.points);
  return { snapshot, screenshotSize: sampled.size, pixels: sampled.pixels };
}
async function loadCase(browser, item) {
  if (!item.constructed) return browser.load(documentHTML(item));
  await browser.load('<!doctype html><html><body></body></html>');
  await browser.evaluate(`(()=>{const m=${JSON.stringify(item.mount)},H=${JSON.stringify(H)};
    const root=document.createElementNS(m.rootNamespace,m.rootName),body=document.createElementNS(m.bodyNamespace,m.kind==='frameset-only'?'frameset':m.bodyName),style=document.createElementNS(H,'style');
    body.id='audit-body';style.textContent=':root{'+m.rootCSS+'}#audit-body{'+m.bodyCSS+'}';
    if(m.kind==='nested'){const div=document.createElementNS(H,'div');div.append(body);root.append(style,div);}else {
      root.append(style);
      if(m.kind==='frameset-before-body'){const f=document.createElementNS(H,'frameset');f.style.cssText='display:block;margin:0;height:30px;background:rgb(200,10,10)';root.append(f);}
      root.append(body);
      if(m.kind==='two-bodies'){const next=document.createElementNS(H,'body');next.id='later-body';next.style.cssText='display:block;margin:0;height:40px;background:rgb(200,10,10)';root.append(next);}
    }
    document.replaceChild(root,document.documentElement);
  })()`);
}
function normative(item) {
  if (item.effect?.startsWith('transform:')) {
    const expected = { references: [references.transform, references.root],
      explanation: 'Root translation applies to the infinite canvas background, including a propagated body background. Native pixel samples are retained separately.',
      initial: { canvasTransform: [1, 0, 0, 1, 0, 20] } };
    if (item.pattern) {
      const phase = dy => item.points.filter(([x]) => x === 400).map(point => ({ point,
        rgba: ((point[1] - dy) % 40 + 40) % 40 < 20 ? [255, 0, 0, 255] : [0, 0, 255, 255] }));
      expected.initial.pixels = phase(20);
      expected.baseline = { canvasTransform: [1, 0, 0, 1, 0, 0], pixels: phase(0) };
      expected.explanation += ' Pixel expectations here are derived from the explicit 40px repeating pattern and transformed sample coordinates; Chromium keeps the raw pattern phase unchanged.';
    }
    return expected;
  }
  if (item.id === 'root-gradient-currentcolor') return {
    references: [references.root, references.currentcolor],
    explanation: 'Used currentColor follows the root color after a color-only mutation. The raw changed/delayed Chromium raster remains red although CSSOM is lime; fresh-changed is a separate native control.',
    initial: { usedGradientCurrentColor: [255, 0, 0] },
    changed: { usedGradientCurrentColor: [0, 255, 0], freshPixelControl: 'fresh-changed' },
  };
  if (item.id === 'body-gradient-currentcolor') return {
    references: [references.body, references.currentcolor],
    explanation: 'A propagated background-image is used on the root; its currentColor uses the root color. Body computed color is recorded independently.',
    initial: { usedGradientCurrentColor: [255, 0, 0] },
    changed: { usedGradientCurrentColor: [255, 0, 0] },
  };
  return undefined;
}

// Separate append-only owner evidence: the original PNG observations, case
// list and frozen expectations are never rewritten by this mode.
async function appendOwnerSelection() {
  const prior = JSON.parse(fs.readFileSync(target, 'utf8'));
  const existingOwnerRows = prior.ownerSelection?.rows || [];
  const blue = 'display:block;margin:0;width:800px;height:120px;background:rgb(20,80,140)';
  const red = 'display:block;margin:0;height:40px;background:rgb(200,10,10)';
  const transparent = 'display:block;margin:0;height:120px;background:none';
  const element = (name, namespace, style, children = [], id) => ({ name, namespace, style, children, ...(id ? { id } : {}) });
  const body = (style = blue, namespace = H, name = 'body', id = 'owner-body') => element(name, namespace, style, [], id);
  const recipes = [
    ['foreign-html-root', element('f:html', 'urn:canvas', blue, [body(red)]), 'root'],
    ['no-namespace-html-root', element('html', null, blue, [body(red)]), 'root'],
    ['foreign-root-nested-html', element('f:page', 'urn:canvas', transparent, [element('html', H, transparent, [body(blue)])]), 'root'],
    ['svg-root', element('svg', 'http://www.w3.org/2000/svg', blue, [body(red)]), 'root'],
    ['uppercase-html-local-name', element('HTML', H, blue, [body(red)]), 'root'],
    ['prefixed-html-root', element('h:html', H, transparent, [body(blue, H, 'h:body')]), 'owner-body'],
    ['foreign-body-before-html-body', element('html', H, transparent, [body(red, 'urn:canvas', 'f:body', 'foreign-body'), body()]), 'owner-body'],
    ['no-namespace-body-before-html-body', element('html', H, transparent, [body(red, null, 'body', 'plain-body'), body()]), 'owner-body'],
    ['first-transparent-body', element('html', H, transparent, [body(transparent), body(red, H, 'body', 'later-body')]), 'owner-body'],
    ['first-hidden-body', element('html', H, transparent, [body(blue + ';display:none'), body(red, H, 'body', 'later-body')]), 'owner-body'],
    ['first-contained-body', element('html', H, transparent, [body(blue + ';contain:paint'), body(red, H, 'body', 'later-body')]), 'root'],
  ].map(([id, root, expectedOwner]) => ({ id, root, expectedOwner, points: [[400, 300], [400, 599]] }));
  // The same author operations run in the native browser and mounted realm.
  recipes.push({ id: 'body-order-mutations', root: element('html', H, transparent, [body(blue), body(red, H, 'body', 'later-body')]), expectedOwner: 'owner-body', points: [[400, 300], [400, 599]], operations: [
    { owner: 'later-body', script: "document.getElementById('owner-body').remove();" },
    { owner: 'inserted-body', script: "var first=document.createElement('body');first.id='inserted-body';first.style.cssText='display:block;margin:0;height:40px;background:rgb(0,128,0)';document.documentElement.insertBefore(first,document.documentElement.firstChild);" },
    { owner: 'root', script: "document.getElementById('inserted-body').style.contain='layout';" },
    { owner: 'later-body', script: "document.getElementById('inserted-body').remove();" },
  ] });
  recipes.push({ id: 'document-element-replacement', root: element('html', H, transparent, [body(blue)]), expectedOwner: 'owner-body', points: [[400, 300], [400, 599]], operations: [
    { owner: 'root', script: "var replacement=document.createElementNS('urn:canvas','f:page');replacement.setAttribute('style','display:block;margin:0;width:800px;height:120px;background:rgb(0,128,0)');var sheet=document.createElementNS('http://www.w3.org/1999/xhtml','style');sheet.textContent=':root{display:block;margin:0;width:800px;height:120px;background:rgb(0,128,0)}';replacement.appendChild(sheet);document.replaceChild(replacement,document.documentElement);" },
    { owner: 'root', script: "var replacement=document.createElementNS('http://www.w3.org/2000/svg','svg');replacement.setAttribute('style','display:block;margin:0;width:800px;height:120px;background:rgb(20,80,140)');document.replaceChild(replacement,document.documentElement);" },
    { owner: 'owner-body', script: "var replacement=document.createElementNS('http://www.w3.org/1999/xhtml','h:html');replacement.setAttribute('style','display:block;margin:0;height:120px;background:none');var nextBody=document.createElementNS('http://www.w3.org/1999/xhtml','h:body');nextBody.setAttribute('id','owner-body');nextBody.setAttribute('style','display:block;margin:0;height:40px;background:rgb(200,10,10)');replacement.appendChild(nextBody);document.replaceChild(replacement,document.documentElement);" },
  ] });
  fs.mkdirSync(folder, { recursive: true });
  const browser = await openBrowser(folder), rows = [];
  const ownerSnapshot = snapshotExpression.replace('e.style.backgroundImage', '(e.style?e.style.backgroundImage:e.getAttribute("style"))')
    .replace("document.getElementById('audit-body')||document.body", "document.getElementById('inserted-body')||document.getElementById('owner-body')||document.getElementById('later-body')||document.body");
  try {
    for (const recipe of recipes.filter(recipe => !existingOwnerRows.some(row => row.id === recipe.id))) {
      await browser.load('<!doctype html><html><body></body></html>');
      await browser.evaluate(`(()=>{let n=0;const rules=[];function make(spec){const e=document.createElementNS(spec.namespace,spec.name),id=spec.id||'owner-node-'+n++;e.setAttribute('id',id);e.setAttribute('style',spec.style);rules.push('#'+id+'{'+spec.style+'}');for(const child of spec.children)e.append(make(child));return e;}const root=make(${JSON.stringify(recipe.root)}),style=document.createElementNS(${JSON.stringify(H)},'style');style.textContent=rules.join('');root.prepend(style);document.replaceChild(root,document.documentElement);})()`);
      const row = { ...recipe, initial: await capture(browser, recipe, 'owner-initial', ownerSnapshot), dynamic: [] };
      for (const [index, operation] of (recipe.operations || []).entries()) {
        await browser.evaluate(operation.script);
        row.dynamic.push({ operation, ...await capture(browser, recipe, 'owner-' + index, ownerSnapshot) });
      }
      rows.push(row);
    }
    if (!rows.length) throw new Error('All owner recipes are already captured; preserve existing evidence.');
    prior.ownerSelection = { ...(prior.ownerSelection || {}), captured: prior.ownerSelection?.captured || new Date().toISOString(), userAgent: await browser.evaluate('navigator.userAgent'), references: [references.root, references.body, 'https://www.w3.org/TR/css-contain-2/#contain-property'], scope: 'Actual expanded-name roots and first direct HTML body; unmodified native PNG/CSSOM states. Frameset local layout and generic SVG rasterization are separate.', rows: [...existingOwnerRows, ...rows] };
    fs.writeFileSync(target, JSON.stringify(prior, null, 2) + '\n');
    console.log('Appended ' + rows.length + ' independent owner cases / ' + rows.reduce((sum, row) => sum + 1 + row.dynamic.length, 0) + ' native states; original cases preserved.');
  } finally { await browser.close(); }
}

(async () => {
  if (process.argv.includes('--append-owner-selection')) return appendOwnerSelection();
  fs.mkdirSync(folder, { recursive: true });
  const append = process.argv.includes('--append-eligibility');
  const prior = append ? JSON.parse(fs.readFileSync(target, 'utf8')) : null;
  const originalCases = [...ordinary, ...extras, ...plane, ...edges, ...dark, ...containers];
  if (prior && JSON.stringify(prior.cases.slice(0, 45).map(item => item.id)) !== JSON.stringify(originalCases.map(item => item.id))) throw new Error('Original canvas rows changed');
  const browser = await openBrowser(folder), cases = prior ? prior.cases.slice(0, 45) : [];
  try {
    for (const item of append ? extensionCases : [...originalCases, ...extensionCases]) {
      await loadCase(browser, item);
      const { points, change, operations, ...recipe } = item;
      const row = { ...recipe, ...(item.constructed ? {} : { html: documentHTML(item) }),
        initial: await capture(browser, item, 'initial'), dynamic: [] };
      if (item.pattern) {
        const operation = { selector: 'html', property: 'transform', value: 'none' };
        await browser.evaluate('document.documentElement.style.transform="none"');
        row.dynamic.push({ id: 'baseline', operation, ...await capture(browser, item, 'baseline') });
      }
      if (change) {
        await browser.evaluate('document.querySelector(' + JSON.stringify(change.selector) + ').style.setProperty('
          + JSON.stringify(change.property) + ',' + JSON.stringify(change.value) + ')');
        row.dynamic.push({ id: 'changed', operation: change, ...await capture(browser, item, 'changed') });
        if (item.id === 'root-gradient-currentcolor') {
          await frames(browser, 10);
          row.dynamic.push({ id: 'changed-delayed', operation: { waitAnimationFrames: 10 },
            ...await capture(browser, item, 'changed-delayed') });
          const html = documentHTML(item).replace('color:red;', 'color:lime;');
          await browser.load(html);
          row.dynamic.push({ id: 'fresh-changed', operation: { loadHTML: html },
            ...await capture(browser, item, 'fresh-changed') });
        }
      }
      for (const [index, operation] of (operations || []).entries()) {
        await browser.evaluate('document.querySelector(' + JSON.stringify(operation.selector) + ').style['
          + JSON.stringify(operation.property) + ']=' + JSON.stringify(operation.value));
        row.dynamic.push({ id: 'state-' + index, operation, ...await capture(browser, item, 'state-' + index) });
      }
      const frozenNormativeExpected = normative(item);
      if (frozenNormativeExpected) row.frozenNormativeExpected = frozenNormativeExpected;
      cases.push(row);
    }
    if (cases.length !== 63 || new Set(cases.map(item => item.id)).size !== 63) throw new Error('Canvas case set changed');
    const fixture = { ...(prior || {}), schemaVersion: 1, captured: prior?.captured || new Date().toISOString(),
      eligibilityCaptured: new Date().toISOString(),
      userAgent: await browser.evaluate('navigator.userAgent'), viewport: [800, 600], deviceScaleFactor: 1,
      pixelFormat: 'PNG sampled with Pillow as unmodified RGBA; coordinates are viewport CSS pixels at DPR 1',
      references, scope: '45 original owner/containment/visibility/opacity/root-plane/currentColor/edge/dark-UA/container-type controls, plus 18 explicit owner, invalid-image and live state controls. Raw browser observations and derived frozen-standard expectations are separate.',
      cases };
    fs.writeFileSync(target, JSON.stringify(fixture, null, 2) + '\n');
    console.log('Canvas background reference: ' + cases.length + ' native cases, '
      + cases.reduce((sum, item) => sum + 1 + item.dynamic.length, 0) + ' snapshots saved.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
