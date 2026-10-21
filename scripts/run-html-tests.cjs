// Bundle engine logic for the official Luau CLI. Engine sources stay Roblox-native.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const svgFixture = require('./svg-fixtures.cjs');
const {readWebsiteFile,readWebsiteModule} = require('./website-test-sources.cjs');
const demoSource = fs.readFileSync(path.join(root, 'examples/HTMLPage.client.luau'), 'utf8');
const websitesLoaderSource = fs.readFileSync(path.join(root, 'src/HTMLEngine/Websites/init.luau'), 'utf8');
// Historical page content is a non-served fixture for existing engine regressions.
const websiteFixtures = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/website-regressions.json'), 'utf8'));
const retiredWebsites = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/retired-websites.json'), 'utf8')).sites;
function retiredFile(folder, file) { return assert.ok(retiredWebsites[folder]?.files[file] !== undefined, `Missing retired fixture ${folder}/${file}`), retiredWebsites[folder].files[file]; }
// Keep the newer comparison/window inputs separate from older historical pages.
// Original browser files and generated Luau sources retain their exact bytes.
const retiredWindowPages = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/retired-window-pages-20261016.json'), 'utf8')).sites;
const fixtureHash = source => require('node:crypto').createHash('sha256').update(source, 'utf8').digest('hex');
for (const [folder, site] of Object.entries(retiredWindowPages)) {
  for (const kind of ['files', 'modules']) for (const [file, source] of Object.entries(site[kind])) {
    assert.equal(fixtureHash(source), site.sha256[kind][file], `Changed retired regression input ${folder}/${kind}/${file}`);
  }
}
function retiredPageFile(folder, file) {
  const source = retiredWindowPages[folder]?.files[file];
  assert.notEqual(source, undefined, `Missing retired page fixture ${folder}/${file}`);
  return source;
}
function retiredPageSources(moduleName, folderName) {
  const site = retiredWindowPages[folderName];
  assert.ok(site, `Missing retired page ${folderName}`);
  assert.equal(site.module, moduleName, `Wrong retired module for ${folderName}`);
  return {init: site.modules['init.luau'], htmlSource: site.modules['HTML.luau'], cssSource: site.modules['CSS.luau'],
    browserHTML: retiredPageFile(folderName, 'index.html'), browserCSS: retiredPageFile(folderName, 'styles.css')};
}
function websiteSources(moduleName, folderName) {
  const fixture = websiteFixtures.sites[folderName];
  assert.ok(fixture, `Missing regression fixture ${folderName}`);
  return {
    init: `return {URL = "http://localhost:8000/${folderName}/index.html"}`,
    htmlSource: `return [==[\n${fixture.html}]==]`,
    cssSource: `return [==[\n${fixture.css}]==]`,
    browserHTML: fixture.html,
    browserCSS: fixture.css,
  };
}
function currentWebsiteSources(moduleName, folderName, active = false) {
  if (!active && retiredWebsites[folderName]) {
    const html = retiredFile(folderName, 'index.html'), css = retiredFile(folderName, 'styles.css');
    return {init: retiredWebsites[folderName].init, htmlSource: 'return [==[\n' + html + ']==]', cssSource: 'return [==[\n' + css + ']==]', browserHTML: html, browserCSS: css};
  }
  return {
    init: readWebsiteModule(moduleName, 'init.luau'),
    htmlSource: readWebsiteModule(moduleName, 'HTML.luau'),
    cssSource: readWebsiteModule(moduleName, 'CSS.luau'),
    browserHTML: readWebsiteFile(folderName, 'index.html'),
    browserCSS: readWebsiteFile(folderName, 'styles.css'),
  };
}
const currentMain = currentWebsiteSources('Main', 'main');
const currentTest = currentWebsiteSources('Test', 'test');
const currentHover = currentWebsiteSources('HoverTests', 'hover-tests');
const currentJavaScript = currentWebsiteSources('JavaScriptTests', 'javascript-tests');
const currentFernweh = currentWebsiteSources('Fernweh', 'fernweh');
const currentFoundations = currentWebsiteSources('BrowserFoundations', 'browser-foundations');
const previousJavaScriptReview = JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-review-page.json'),'utf8'));
const previousRangeReview = JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-range-review-page.json'),'utf8'));
const previousCSSOMReview = JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-cssom-review-page.json'),'utf8'));
const previousSelectionCommitReview = JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-selection-commit-review-page.json'),'utf8'));
const previousTopLayerReview = JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-top-layer-review-page.json'),'utf8'));
const previousProfilesReview = JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-profiles-review-page.json'),'utf8'));
const previousComponentsReview = JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-components-review-page.json'),'utf8'));
const comparisonRoutes = [
  ['comparison', 'Comparison'], ['comparison-markup', 'ComparisonMarkup'],
  ['comparison-forms', 'ComparisonForms'], ['comparison-selectors', 'ComparisonSelectors'],
  ['comparison-cascade', 'ComparisonCascade'], ['comparison-layout', 'ComparisonLayout'],
  ['comparison-text', 'ComparisonText'], ['comparison-effects', 'ComparisonEffects'],
  ['comparison-motion', 'ComparisonMotion'], ['comparison-script', 'ComparisonScript'],
  ['comparison-canvas', 'ComparisonCanvas'],
];
const activeCatalog = JSON.parse(fs.readFileSync(path.join(root, 'scripts/data/wttg2-full-catalog.json'), 'utf8'));
assert.deepEqual(activeCatalog.selectedCounts, {realSites:60,deadLinks:30,htmlRoutes:175}, 'The entire original game website inventory, including all three Wikis');
assert.equal(activeCatalog.Modules.filter(page=>page.status==='withheld').length,15,'Explicitly identified unavailable source content');
assert.deepEqual(fs.readdirSync(path.join(root, 'src/HTMLEngine/Websites')).sort(), ['Assets','init.luau',...activeCatalog.Modules.map(x=>x.name)].sort(), 'Only the current game pages and private assets are registered');
function publishedFiles(folder) {
  return fs.readdirSync(folder,{withFileTypes:true}).flatMap(item=>item.isDirectory()
    ? publishedFiles(path.join(folder,item.name))
    : [path.relative(root,path.join(folder,item.name)).replaceAll('\\','/')]);
}
assert.deepEqual(publishedFiles(path.join(root,'examples/websites')).sort(), activeCatalog.files.map(x=>x.target).sort(), 'No retired authored pages are served beside the original-game port');
for(const file of [...activeCatalog.files,...activeCatalog.Modules.flatMap(x=>x.files),...(activeCatalog.assetFiles||[])]) {
  const source = fs.readFileSync(path.join(root,file.target || file.path));
  assert.equal(require('node:crypto').createHash('sha256').update(source).digest('hex'),file.sha256,'Published source changed: '+(file.target||file.path));
}
const windowCheck = currentWebsiteSources('WindowCheck', 'window-check', true);
const annoyingSite = currentWebsiteSources('AnnoyingSite', 'annoying-site', true);
const annoyingSiteOptions = JSON.parse(readWebsiteFile('annoying-site', 'options.json'));
annoyingSiteOptions.SVGs = Object.fromEntries((annoyingSiteOptions.LocalSVG || []).map(file => [file, readWebsiteFile('annoying-site', file)]));
delete annoyingSiteOptions.LocalSVG;delete annoyingSiteOptions.LocalScripts;
const annoyingSiteTestSource = {HTML: annoyingSite.browserHTML, CSS: annoyingSite.browserCSS,
  JavaScript: readWebsiteFile('annoying-site', 'app.js'), Options: annoyingSiteOptions};
const main = websiteSources('Main', 'main');
const cssBackgroundPosition = websiteSources('CSSBackgroundPosition', 'css-background-position');
const cssIndividualTransforms = websiteSources('CSSIndividualTransforms', 'css-individual-transforms');
const cssVisualProperties = websiteSources('CSSVisualProperties', 'css-visual-properties');
const cssTextAdvanced = websiteSources('CSSTextAdvanced', 'css-text-advanced');
const cssScrollInput = websiteSources('CSSScrollInput', 'css-scroll-input');
const cssFlowLayout = websiteSources('CSSFlowLayout', 'css-flow-layout');
const cssContainment = websiteSources('CSSContainment', 'css-containment');
const cssEffects = websiteSources('CSSEffects', 'css-effects');
const cssAdvancedMotion = websiteSources('CSSAdvancedMotion', 'css-advanced-motion');
const cssFontFeatures = websiteSources('CSSFontFeatures', 'css-font-features');
const cssCounters = websiteSources('CSSCounters', 'css-counters');
const cssExtended = websiteSources('CSSExtended', 'css-extended');
const cssNextFeatures = websiteSources('CSSNextFeatures', 'css-next-features');
const notFound = websiteSources('NotFound', 'not-found');
const stress = websiteSources('HTMLCSSStress', 'html-css-stress');
const stressManifest = websiteFixtures.stressManifest;
const stressPages = stressManifest.pages.map(item => ({ ...item, source: websiteSources(item.module, item.slug) }));
const demoStatusSource = demoSource.slice(demoSource.indexOf('local reportedReady = false'), demoSource.indexOf('local status = page.Root:GetAttributeChangedSignal'));
assert.ok(demoStatusSource.includes('local function updateStatus()'), 'Extract the actual demo status reporter for deferred-event tests');
function generatedLongString(source) {
  const captured = source.match(/return \[==\[([\s\S]*?)\]==\]/)?.[1];
  if (captured === undefined) return undefined;
  const normalized = captured.replace(/\r\n/g, '\n');
  return normalized.startsWith('\n') ? normalized.slice(1) : normalized;
}
for (const [name, page] of Object.entries({CurrentMain: currentMain, CurrentTest: currentTest, Main: main, CSSBackgroundPosition: cssBackgroundPosition, CSSIndividualTransforms: cssIndividualTransforms, CSSVisualProperties:cssVisualProperties, CSSTextAdvanced:cssTextAdvanced, CSSScrollInput:cssScrollInput, CSSFlowLayout:cssFlowLayout, CSSContainment:cssContainment, CSSEffects:cssEffects, CSSAdvancedMotion:cssAdvancedMotion, CSSFontFeatures:cssFontFeatures, CSSCounters:cssCounters, CSSExtended:cssExtended, CSSNextFeatures:cssNextFeatures, NotFound: notFound, ...Object.fromEntries(stressPages.map(item => [item.module, item.source]))})) {
  page.htmlExact = generatedLongString(page.htmlSource);
  page.cssExact = generatedLongString(page.cssSource);
  page.html = page.htmlExact?.trim();
  page.css = page.cssExact?.trim();
  assert.ok(page.html && page.css, `${name} HTML and CSS must exist`);
  assert.equal(page.htmlExact, page.browserHTML.replace(/\r\n/g, '\n'), `${name} HTML must match index.html exactly`);
  assert.equal(page.cssExact, page.browserCSS.replace(/\r\n/g, '\n'), `${name} CSS must match styles.css exactly`);
  assert.doesNotMatch(page.init, /SourceSHA256|SHA256/, `${name} metadata must not contain source hashes`);
  assert.doesNotMatch(page.init, /require\(script\.(?:HTML|CSS)\)/, `${name} metadata must not load its own children`);
}
const browserHTML = svgFixture('examples/svg-tests/supported-svg-stress-3.html').trim();
assert.equal(generatedLongString(currentFernweh.htmlSource), currentFernweh.browserHTML.replace(/\r\n/g, '\n'), 'Fernweh HTML must match the browser source exactly');
assert.equal(generatedLongString(currentFernweh.cssSource), currentFernweh.browserCSS.replace(/\r\n/g, '\n'), 'Fernweh CSS must match the browser source exactly');
assert.equal(generatedLongString(currentFoundations.htmlSource), currentFoundations.browserHTML.replace(/\r\n/g, '\n'), 'BrowserFoundations HTML must match the browser source exactly');
assert.equal(generatedLongString(currentFoundations.cssSource), currentFoundations.browserCSS.replace(/\r\n/g, '\n'), 'BrowserFoundations CSS must match the browser source exactly');
assert.equal(generatedLongString(currentHover.htmlSource), currentHover.browserHTML.replace(/\r\n/g, '\n'), 'Hover HTML must match the browser source exactly');
assert.equal(generatedLongString(currentHover.cssSource), currentHover.browserCSS.replace(/\r\n/g, '\n'), 'Hover CSS must match the browser source exactly');
assert.equal(generatedLongString(currentJavaScript.htmlSource), currentJavaScript.browserHTML.replace(/\r\n/g, '\n'), 'JavaScript HTML must match the browser source exactly');
assert.equal(generatedLongString(currentJavaScript.cssSource), currentJavaScript.browserCSS.replace(/\r\n/g, '\n'), 'JavaScript CSS must match the browser source exactly');
assert.equal(generatedLongString(windowCheck.htmlSource), windowCheck.browserHTML.replace(/\r\n/g, '\n'), 'WindowCheck HTML must match its published source exactly');
assert.equal(generatedLongString(windowCheck.cssSource), windowCheck.browserCSS.replace(/\r\n/g, '\n'), 'WindowCheck CSS must match its published source exactly');
assert.equal(generatedLongString(readWebsiteModule('WindowCheck', 'JavaScript.luau')), readWebsiteFile('window-check', 'app.js').replace(/\r\n/g, '\n'), 'WindowCheck JavaScript must match its preserved source exactly');
assert.equal(generatedLongString(annoyingSite.htmlSource), annoyingSiteTestSource.HTML.replace(/\r\n/g, '\n'), 'AnnoyingSite HTML must match the published source');
assert.equal(generatedLongString(annoyingSite.cssSource), annoyingSiteTestSource.CSS.replace(/\r\n/g, '\n'), 'AnnoyingSite CSS must match the published source');
assert.equal(generatedLongString(readWebsiteModule('AnnoyingSite', 'JavaScript.luau')), annoyingSiteTestSource.JavaScript.replace(/\r\n/g, '\n'), 'AnnoyingSite JavaScript must match the preserved source');
const demoHTML = browserHTML;
const featureHTML = fs.readFileSync(path.join(root, 'examples/ubuntu-roboto-page.html'), 'utf8').trim();
assert.ok(demoHTML && featureHTML, 'Demo and feature documents must exist');
assert.match(demoSource, /local WEBSITE = script:GetAttribute\("Website"\) or ""/, 'The LocalScript starts without a registered website; Website can select a future module');
assert.match(fs.readFileSync(path.join(root,'src/HTMLEngine/init.luau'),'utf8'), /destination\.Name\s*=\s*"NotFound"/, 'The engine-owned resolver mounts missing internal routes through the 404 website');
assert.match(fs.readFileSync(path.join(root,'src/HTMLEngine/Rendering/StandaloneHost/init.luau'),'utf8'), /SetAttribute\(['"]HTTPStatus['"],\s*404\)/, 'The engine-owned standalone error page exposes its HTTP status');
assert.match(main.init, /URL\s*=\s*["']http:\/\/localhost:8000\/main\/index\.html["']/, 'Main exposes its complete development URL');
assert.match(cssBackgroundPosition.init, /URL\s*=\s*["']http:\/\/localhost:8000\/css-background-position\/index\.html["']/, 'Background position test exposes its development URL');
assert.match(cssIndividualTransforms.init, /URL\s*=\s*["']http:\/\/localhost:8000\/css-individual-transforms\/index\.html["']/, 'Individual transforms test exposes its development URL');
assert.match(cssVisualProperties.init, /URL\s*=\s*["']http:\/\/localhost:8000\/css-visual-properties\/index\.html["']/, 'Visual property test exposes its development URL');
assert.match(cssTextAdvanced.init, /css-text-advanced\/index\.html/, 'Advanced text test exposes its development URL');
assert.match(cssScrollInput.init, /css-scroll-input\/index\.html/, 'Scroll and input test exposes its development URL');
assert.match(cssFlowLayout.init, /css-flow-layout\/index\.html/, 'Flow layout test exposes its development URL');
assert.match(cssContainment.init, /css-containment\/index\.html/, 'Containment test exposes its development URL');
assert.match(cssEffects.init, /css-effects\/index\.html/, 'Effects test exposes its development URL');
assert.match(cssAdvancedMotion.init, /css-advanced-motion\/index\.html/, 'Advanced motion test exposes its development URL');
assert.match(cssFontFeatures.init, /css-font-features\/index\.html/, 'Font features test exposes its development URL');
assert.match(cssCounters.init, /css-counters\/index\.html/, 'Counters test exposes its development URL');
assert.match(cssExtended.init, /css-extended\/index\.html/, 'Extended CSS test exposes its development URL');
assert.match(cssNextFeatures.init, /css-next-features\/index\.html/, 'Next features test exposes its development URL');
assert.match(websitesLoaderSource, /childSource\(name, module, "HTML"\)/, 'The central website loader reads the HTML child');
assert.match(websitesLoaderSource, /childSource\(name, module, "CSS"\)/, 'The central website loader reads the CSS child');
assert.match(demoSource, /website\.CSS[^\n]*options\.CSS/, 'Legacy direct CSS remains supported');
assert.match(demoSource, /website\.Stylesheets[^\n]*options\.Stylesheets/, 'Structured linked stylesheets remain supported');
assert.match(main.html, /<link\s+rel="stylesheet"\s+href="styles\.css">/i, 'Main links the same CSS in browsers and Roblox');
assert.match(cssBackgroundPosition.css, /background-position-x[\s\S]*background-position-y/i, 'Background position subtest exercises both axes');
assert.match(cssIndividualTransforms.css, /translate:[\s\S]*rotate:[\s\S]*scale:[\s\S]*transform:translateX/i, 'Transform subtest exercises individual and composed transforms');
assert.match(cssVisualProperties.css, /accent-color[\s\S]*scrollbar-color[\s\S]*image-rendering[\s\S]*text-wrap-mode/i, 'Visual batch exercises controls, scrolling, images and text');
assert.match(cssTextAdvanced.css, /hyphens[\s\S]*text-emphasis[\s\S]*quotes[\s\S]*writing-mode/i, 'Advanced text page exercises the complete batch');
assert.match(cssScrollInput.css, /scroll-snap-type[\s\S]*overscroll-behavior[\s\S]*appearance/i, 'Scroll and input page exercises snapping, overscroll and appearance');
assert.match(cssFlowLayout.css, /columns:[\s\S]*column-rule[\s\S]*float:[\s\S]*clear:[\s\S]*line-clamp/i, 'Flow page exercises the complete batch');
assert.match(cssContainment.css, /container:[\s\S]*@container[\s\S]*contain:paint[\s\S]*content-visibility/i, 'Containment page exercises the complete batch');
assert.match(cssEffects.css, /border-image-source[\s\S]*clip-path[\s\S]*mask-image[\s\S]*mix-blend-mode[\s\S]*backdrop-filter/i, 'Effects page exercises the complete batch');
assert.match(cssAdvancedMotion.css, /offset-path[\s\S]*perspective:[\s\S]*backface-visibility[\s\S]*animation-timeline/i, 'Advanced motion page exercises the complete batch');
assert.match(cssFontFeatures.css, /font-variant-numeric[\s\S]*font-feature-settings[\s\S]*font-variant:/i, 'Font feature page exercises longhands and shorthand');
assert.match(cssCounters.css, /counter-reset[\s\S]*counter-increment[\s\S]*counters\([\s\S]*counter-set/i, 'Counters page exercises resets, increments, sets and nested output');
assert.match(cssExtended.css, /background-attachment[\s\S]*scrollbar-gutter[\s\S]*shape-outside[\s\S]*mask-position[\s\S]*ruby-align[\s\S]*font-size-adjust[\s\S]*transform-box[\s\S]*animation-composition/i, 'Extended page exercises all seven new CSS groups');
assert.match(cssNextFeatures.css, /anchor-name[\s\S]*position-anchor[\s\S]*text-autospace[\s\S]*hanging-punctuation[\s\S]*mask-origin[\s\S]*mask-composite[\s\S]*corner-shape[\s\S]*border-image-outset[\s\S]*scroll-marker-group[\s\S]*animation-trigger/i, 'Next page exercises all five new CSS groups');
assert.match(demoHTML, /^<!doctype html>[\s\S]*<html\b[\s\S]*<head>[\s\S]*<\/head>[\s\S]*<body\b[\s\S]*<\/html>$/i);
assert.ok(Buffer.byteLength(demoHTML, 'utf8') < 22000, 'Keep the SVG test fixture compact');
assert.doesNotMatch(demoHTML, /data:font|base64,/i);
let quotes = '====';
while ([demoHTML,main.html,main.css,cssBackgroundPosition.html,cssBackgroundPosition.css,cssIndividualTransforms.html,cssIndividualTransforms.css,cssVisualProperties.html,cssVisualProperties.css,cssTextAdvanced.html,cssTextAdvanced.css,cssScrollInput.html,cssScrollInput.css,cssFlowLayout.html,cssFlowLayout.css,cssContainment.html,cssContainment.css,cssEffects.html,cssEffects.css,cssAdvancedMotion.html,cssAdvancedMotion.css,cssFontFeatures.html,cssFontFeatures.css,cssCounters.html,cssCounters.css,cssExtended.html,cssExtended.css,cssNextFeatures.html,cssNextFeatures.css,notFound.html,notFound.css].some(value => value.includes(']' + quotes + ']'))) quotes += '=';
const literal = value => {
  if (/^[\r\n]|[\x00-\x08\x0b\x0c\x0e-\x1f\r]/.test(value)) {
    return '"' + [...Buffer.from(value, 'utf8')].map(byte => '\\' + String(byte).padStart(3, '0')).join('') + '"';
  }
  let delimiter = quotes;
  while (value.includes(']' + delimiter + ']')) delimiter += '=';
  return '[' + delimiter + '[' + value + ']' + delimiter + ']';
};
const demoLiteral = literal(demoHTML);
const mainHTMLLiteral = literal(main.html);
const mainCSSLiteral = literal(main.css);
const cssBackgroundPositionHTMLLiteral = literal(cssBackgroundPosition.html);
const cssBackgroundPositionCSSLiteral = literal(cssBackgroundPosition.css);
const cssIndividualTransformsHTMLLiteral = literal(cssIndividualTransforms.html);
const cssIndividualTransformsCSSLiteral = literal(cssIndividualTransforms.css);
const cssVisualPropertiesHTMLLiteral=literal(cssVisualProperties.html);
const cssVisualPropertiesCSSLiteral=literal(cssVisualProperties.css);
const cssTextAdvancedHTMLLiteral=literal(cssTextAdvanced.html);
const cssTextAdvancedCSSLiteral=literal(cssTextAdvanced.css);
const cssScrollInputHTMLLiteral=literal(cssScrollInput.html);
const cssScrollInputCSSLiteral=literal(cssScrollInput.css);
const cssFlowLayoutHTMLLiteral=literal(cssFlowLayout.html);
const cssFlowLayoutCSSLiteral=literal(cssFlowLayout.css);
const cssContainmentHTMLLiteral=literal(cssContainment.html);
const cssContainmentCSSLiteral=literal(cssContainment.css);
const cssEffectsHTMLLiteral=literal(cssEffects.html);
const cssEffectsCSSLiteral=literal(cssEffects.css);
const cssAdvancedMotionHTMLLiteral=literal(cssAdvancedMotion.html);
const cssAdvancedMotionCSSLiteral=literal(cssAdvancedMotion.css);
const cssFontFeaturesHTMLLiteral=literal(cssFontFeatures.html);
const cssFontFeaturesCSSLiteral=literal(cssFontFeatures.css);
const cssCountersHTMLLiteral=literal(cssCounters.html);
const cssCountersCSSLiteral=literal(cssCounters.css);
const cssExtendedHTMLLiteral=literal(cssExtended.html);
const cssExtendedCSSLiteral=literal(cssExtended.css);
const cssNextFeaturesHTMLLiteral=literal(cssNextFeatures.html);
const cssNextFeaturesCSSLiteral=literal(cssNextFeatures.css);
const notFoundHTMLLiteral = literal(notFound.html);
const notFoundCSSLiteral = literal(notFound.css);
const featureLiteral = literal(featureHTML);
const svgEmbeddingHTML=svgFixture('examples/svg-tests/S03-embedding.html');
assert.ok(!svgEmbeddingHTML.includes(']===]'));
const svgEmbeddingLiteral='[===['+svgEmbeddingHTML+']===]';
const ids = ['SVG/Matrix', 'SVG/Viewport', 'SVG/Sizing', 'DOM/Node', 'HTML/Entities', 'HTML/Elements', 'HTML/Tokenizer', 'HTML/SVGNames', 'HTML/Parser', 'HTML/DocumentInfo', 'HTML/ResponsiveSources', 'HTML/WebVTT', 'CSS/Properties', 'CSS/Syntax', 'CSS/Selectors', 'CSS/Stylesheet', 'CSS/InlineStyle', 'Layout/TextWords', 'Layout/InlineWords', 'Layout/FontMetrics', 'Layout/WordFlow', 'PageSession'];
ids.push('Rendering/WorkerHost');
ids.push('SVG/RenderQueue');
ids.push('Rendering/BackgroundSVG');
ids.push('CSS/ScrollTimeline');
ids.push('CSS/AnchorPosition');
ids.push('CSS/PositionArea');
ids.push('DOM/DocumentOrigin');
ids.push('DOM/DocumentAccessors');
ids.push('DOM/TemplateDocument');
ids.push('HTML/ElementProfile');
ids.push('Layout/AnchorRegistry');
ids.push('Layout/AnchorFallback');
ids.push('Layout/Hyphenation',...fs.readdirSync(path.join(root,'src/HTMLEngine/Layout/HyphenationPatterns')).filter(name=>name.endsWith('.luau')).map(name=>'Layout/HyphenationPatterns/'+name.slice(0,-5)));
ids.push('HTML/Doctype','HTML/DocumentBuilder','HTML/TreeContext','HTML/DocumentHead','HTML/DocumentBody','HTML/TableBuilder','HTML/Formatting','HTML/ForeignContent','HTML/NamedEntities','HTML/ScriptData','HTML/SelectTree','HTML/SelectedContent','HTML/AttributeValues');
ids.push('JavaScript/DocumentStreams');
ids.push('HTML/DeclarativeShadowRoot','Layout/WhiteSpace');
ids.push('HTML/MediaSelection','HTML/MediaContent');
ids.push('HTML/VideoState','JavaScript/VideoElements','Input/VideoServices','Input/StreamVideo');
ids.push('HTML/AudioState');
ids.push('Layout/TextCaseData');
ids.push('DOM/ElementNames');
ids.push('HTML/InputStream');
ids.push('DOM/ShadowTree','Input/PointerCapture');
ids.push('Navigation/URL');
ids.push('Storage/Protocol','Storage/Server','Storage/Client','Storage/Memory');
ids.push('Layout/InlineFragments','Rendering/BorderShapePixels','CSS/ObjectViewBox','Layout/ShapeImage');
ids.push('CSS/BoxShadow', 'Rendering/InsetShadowPixels', 'Rendering/InsetShadows', 'Rendering/DecorationPixels', 'Rendering/DecorationPatterns', 'Layout/LetterSpacing', 'Layout/VerticalText', 'Layout/TextTransform', 'Layout/SkipInk', 'Layout/FontProfiles', ...['Arial', 'SourceSans', 'Ubuntu', 'Roboto', 'RobotoCondensed', 'RobotoMono', 'RobotoSlab', 'Inter', 'OpenSans'].map(name => 'Layout/FontProfiles/' + name));
const substitutes = ['Rendering/ShapeImages','SVG/Embedded','SVG/Raster','Rendering/SVGImages', 'Rendering/GuiFactory', 'Rendering/RenderTree', 'Rendering/FontPreload', 'Layout/BlockLayout', 'Layout/WordLayout', 'Layout/ListMarker', 'Layout/TextMeasure', 'Layout/TextDecoration', 'Input/TextSelection'];
ids.push('CSS/FontFamily', 'CSS/FontFeatures', 'CSS/Counters', 'CSS/CompositeValues', 'CSS/ResetProperties', 'CSS/ColumnRuleInsets', 'CSS/LayoutValues', 'CSS/VisualValues', 'CSS/ScrollValues', 'CSS/RelativeLengths', 'CSS/LengthExpression', 'CSS/Background', 'CSS/Variables', 'CSS/MediaQueries');
ids.push('CSS/NamedColors');
ids.push('CSS/Nesting');
ids.push('CSS/Matrix4', 'CSS/Transform2D', 'CSS/Motion', 'CSS/MotionPath', 'CSS/AdvancedVisual', 'CSS/ContainerQueries', 'Rendering/BoxTransform', 'Rendering/ClipRect', 'Rendering/HTMLAnimations', 'Rendering/VisualEffectPixels', 'Rendering/PerspectivePixels', 'Rendering/VisualEffects', 'Rendering/BlendGroups', 'SVG/Blend', 'SVG/RenderQueue', 'Rendering/ImageEffectPixels');
ids.push('Rendering/AnimationValues');
ids.push('Rendering/ProjectiveHit');
ids.push('Rendering/ResourceLoadHost');
ids.push('Rendering/AudioHost');
ids.push('Rendering/NativeMediaResources','Rendering/NativeImageResources');
ids.push('Rendering/GeneratedContent');
ids.push('Rendering/ScriptTransforms', 'Navigation/NotFound');
ids.push('Layout/TextSource','Rendering/ScriptSelection');
ids.push('Layout/BidiClass','Input/TextDirection','Layout/Bidi','Layout/BidiData','Layout/BidiExplicit','Layout/BidiSequences','Layout/BidiResolve','Layout/BidiScope','Layout/BidiInline','Layout/BidiPaint');
ids.push('Layout/VerticalOrientation','Layout/VerticalOrientationData');
ids.push('Input/UprightSelection');
ids.push('SVG/Curves', 'SVG/Arc');
ids.push('Layout/FontProfiles/PTSerif');
ids.push('Layout/FontProfiles/BuilderSans');
ids.push('Layout/FontProfiles/Lato');
ids.push('Layout/FontProfiles/Lora');
ids.push('Layout/FontProfiles/Merriweather');
ids.push('Layout/FontProfiles/Montserrat');
ids.push('Layout/FontProfiles/NotoSans');
ids.push('Layout/FontProfiles/NunitoSans');
ids.push('Layout/FontProfiles/PlayfairDisplay');
ids.push('Layout/FontProfiles/Poppins');
ids.push('Layout/FontProfiles/WorkSans');
ids.push('Layout/OverflowWrap', 'Layout/BoxSpacing');
ids.push('Layout/FloatLayout');
ids.push('Layout/ColumnLayout','Layout/MarginTrim','CSS/ColorScheme','Layout/MasonryLayout');
ids.push('Layout/FlexBalance');
substitutes.push('Layout/BlockImage');
ids.push('Layout/TextOverflow');
ids.push('Layout/FlexLayout', 'CSS/GridValues', 'Layout/GridPlacement', 'Layout/GridTracks', 'Layout/GridLayout', 'Layout/BoxAlignment');
ids.push('Layout/PositionedLayout');
ids.push('Layout/ScrollLayout');
ids.push('Rendering/ContainerStates');
ids.push('Layout/DirtyLayout', 'Layout/TextMutation', 'Layout/LayoutProbe','Layout/LayoutMeasurement');
ids.push('Layout/FieldsetLayout');
ids.push('Controls/TextValue', 'Controls/URLValue', 'Controls/TextSelection');
ids.push('Controls/ValidationMessage', 'Controls/ValidationEligibility', 'Controls/Validity', 'Controls/Pattern', 'Input/ValidationPopup');
ids.push('Layout/BorderGeometry', 'Rendering/PaintLayer', 'Rendering/CornerRadii', 'Rendering/BorderPattern', 'Rendering/BorderBox', 'Rendering/OutlineBox');
ids.push('Rendering/GroupOpacity', 'Rendering/MaskGradient');
ids.push('Rendering/MaskPixels');
ids.push('Rendering/MediaSources','Rendering/MediaBox','Rendering/LazyMedia','Input/MediaRuntime','Rendering/PermissionHost');
ids.push('Rendering/IFrameBox','Rendering/IFrameRuntime');
ids.push('Rendering/Dialog', 'Rendering/Popover');
ids.push('Rendering/TopLayerLayout');
ids.push('Rendering/ViewportLayer');
ids.push('Rendering/CanvasBackground');
ids.push('Rendering/SpacingOwners');
ids.push('Rendering/BackgroundPixels', 'Rendering/BackgroundImages');
ids.push('Rendering/DOMReconcile');
ids.push('Rendering/StructuralResources');
ids.push('Input/EventData');
ids.push(...fs.readdirSync(path.join(root,'src/HTMLEngine/JavaScript')).filter(name=>name.endsWith('.luau')).map(name=>'JavaScript/'+name.slice(0,-5)), 'Rendering/InlineGeometry', 'Rendering/ScriptClock', 'Rendering/ScriptGeometry', 'Rendering/HTMLScripts','Rendering/FullscreenHost');
for (const folder of ['DOM','Input','CSS']) ids.push(...fs.readdirSync(path.join(root,'src/HTMLEngine',folder)).filter(name=>name.endsWith('.luau')).map(name=>folder+'/'+name.slice(0,-5)).filter(id=>!ids.includes(id)&&!substitutes.includes(id)));
ids.push('WorkContext','SVG/Path','SVG/TextFont/Glyphs','SVG/TextFont/Bold/Glyphs','SVG/TextFont/Bold','SVG/TextFont/It/Glyphs','SVG/TextFont/It','SVG/TextFont/BoldIt/Glyphs','SVG/TextFont/BoldIt','SVG/TextFont','SVG/ScriptSyntax','SVG/ScriptVM','Rendering/CanvasPNG','Rendering/CanvasSurface','Rendering/CanvasTriangle','Rendering/CanvasWebGL','Rendering/CanvasWebGPU','Rendering/WorkBudget','Rendering/LayoutJob','Rendering/CanvasRuntime');
ids.push('Encoding/Data','Encoding/Decoder','Encoding/Multibyte','Encoding/ISO2022JP');
ids.push('HTML/EncodingSniff','HTML/ByteDocument','DOM/DocumentLanguage');
ids.push('DOM/DocumentMode');
ids.push('Layout/QuirksLayout');
ids.push('CSS/FormSelectors','CSS/QuirkyValues');
ids.push(...['GB18030','GBRanges','Big5','JIS0208','JIS0212','EUCKR'].map(name=>'Encoding/Indexes/'+name));
ids.push('Rendering/RadioDot');
ids.push('Rendering/TextureUpload');
ids.push('SVG/XML');
ids.push('Rendering/DisclosureIcons');
ids.push('Controls/SelectOptions', 'Input/SelectPopup','Rendering/PickerFragments');
ids.push('Input/SelectTypeAhead');
ids.push('Rendering/Disclosure');
ids.push('Layout/TableLayout');
ids.push('Layout/TextEmphasis','Layout/TextEmphasisData');
ids.push('Layout/TableGrid');
ids.push('Layout/TableBorders', 'Rendering/TableBorderPaint');
ids.push('Layout/TableColumns', 'Rendering/TableColumnPaint');
ids.push('Layout/TableCaptions');
ids.push('Layout/TableHeights');
ids.push('Layout/TableTracks');
ids.push('CSS/Filter','Rendering/ImageFilterPixels','Rendering/ImageFilters');
ids.push('Rendering/ImageBlurPixels','Rendering/ImageBlur');
ids.push('Input/CursorIcons','CSS/Cursor','Input/CursorLease','Input/CursorController','Input/CursorPreload');
ids.push('Controls/RangeValue', 'Controls/RangeView', 'Input/RangeDrag');
ids.push('Controls/ColorValue','Input/ColorPopup');
ids.push('Controls/NumericValue', 'Controls/NumberValue', 'Controls/NumberView');
ids.push('Controls/TemporalValue','Controls/TemporalEdit','Controls/TemporalView','Controls/FileView','Input/TemporalPopup','JavaScript/InputValues');
ids.push('Controls/GaugeValue', 'Controls/GaugeView');
ids.push('Rendering/ResizeGrip', 'Controls/TextareaView', 'Input/TextareaResize');
ids.push('Controls/Defaults', 'Controls/State', 'Controls/OutputView', 'Controls/View', 'Controls/FormModel', 'Input/Events', 'Input/HitTest', 'Input/ImageMap', 'Input/Links', 'Input/Controller');
ids.push('Rendering/BorderPaint', 'Rendering/BorderCornerPixels', 'Rendering/BorderCorners', 'Rendering/BorderImagePixels');
ids.push('Rendering/ImageSources', 'Layout/ImageLayout', 'Rendering/TextShadows', 'Rendering/ImageBox', 'Rendering/ImageFallback', 'CSS/ObjectPosition', 'CSS/Color', 'Layout/ImageFit', 'Layout/AspectRatio');
ids.push('Rendering/ReplacedElement');
substitutes.push('Rendering/ImageLoad', 'Rendering/ImageDimensions');
const nightwebSVGKeys=['Parser','SceneBuilder','Viewport','Length','Geometry','Paint','Transform','TransformBounds','Rendering','Document','Gradient','Resources','Text'];
const nightwebSVGVisited=new Set();
function includeNightwebSVG(id){
  if(nightwebSVGVisited.has(id)||substitutes.includes(id))return;
  nightwebSVGVisited.add(id);if(!ids.includes(id))ids.push(id);
  const base=path.join(root,'src/HTMLEngine',id),file=fs.existsSync(base+'.luau')?base+'.luau':path.join(base,'init.luau');
  for(const [,chain] of fs.readFileSync(file,'utf8').matchAll(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g)){
    const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);includeNightwebSVG(parts.join('/'));
  }
}
for(const key of nightwebSVGKeys)includeNightwebSVG('SVG/'+key);
function readModule(id, localSubstitutes = []) {
  for (const dependency of localSubstitutes) {
    const target = path.join(root, 'src/HTMLEngine', dependency);
    assert.ok(fs.existsSync(target + '.luau') || fs.existsSync(path.join(target, 'init.luau')), `Missing local dependency ${dependency}`);
  }
  const modulePath = path.join(root, 'src/HTMLEngine', id);
  return fs.readFileSync(fs.existsSync(modulePath + '.luau') ? modulePath + '.luau' : path.join(modulePath, 'init.luau'), 'utf8').replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g, (_, chain) => {
    const parts = id.split('/');
    for (const item of chain.slice(1).split('.')) item === 'Parent' ? parts.pop() : parts.push(item);
    const target = parts.join('/');
    if (![...ids, ...substitutes, ...localSubstitutes].includes(target)) throw new Error('Unknown dependency ' + target);
    return `require(${JSON.stringify(target)})`;
  });
}
// Roblox adds utf8.graphemes beyond the standalone Luau CLI. Supply Unicode
// fixture boundaries from Intl.Segmenter; ASCII uses its trivial byte boundaries.
const segmenter = new Intl.Segmenter('de', {granularity: 'grapheme'});
const unicodeFixtures = ['…', 'Äpfel', 'ÄPFEL', 'Äöß', 'A\u0308p', 'u\u0308berraschend', 'u\u0308', '👩‍💻p', 'A\u00a0B', 'XA\u00a0B','A\u0308😀👩‍👩‍👧‍👦Z'];
for (const fixture of JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/text-transform-browser.json'),'utf8')).records) {
  for (const field of ['source','display']) if (typeof fixture[field] === 'string') unicodeFixtures.push(fixture[field]);
}
unicodeFixtures.push('i̇gis', 'Ị̇', 'άι ή σ́');
for (const fixture of JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/bidi-browser.json'),'utf8')).records) unicodeFixtures.push(fixture.source);
for (const fixture of JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/vertical-mixed-browser.json'),'utf8')).records) unicodeFixtures.push(fixture.source);
for (const fixture of JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/vertical-emphasis-browser.json'),'utf8')).records) unicodeFixtures.push(fixture.source);
for (const word of [...stressPages.map(item => item.source.html + '\n' + item.source.css), currentMain.html, currentTest.html].join('\n').matchAll(/[^\s<>"'=;:{}]+/gu)) {
  if (/[^\x00-\x7f]/.test(word[0])) {
    unicodeFixtures.push(word[0], word[0].toUpperCase(), word[0].toLowerCase(), word[0].replace(/\u00ad/g, ''));
  }
}
const graphemeInputs = new Set(unicodeFixtures);
for (const value of unicodeFixtures) {
  for (const {segment} of segmenter.segment(value)) graphemeInputs.add(segment);
}
const graphemeTable = [...graphemeInputs].map(value => {
  const ranges = [...segmenter.segment(value)].map(({segment, index}) => {
    const first = Buffer.byteLength(value.slice(0, index), 'utf8') + 1;
    return `{${first},${first + Buffer.byteLength(segment, 'utf8') - 1}}`;
  });
  return `[ ${literal(value)} ] = {${ranges.join(',')}}`;
}).join(',\n');
const complexGraphemes = [...new Set(unicodeFixtures.flatMap(value => [...segmenter.segment(value)].map(part => part.segment)))].filter(value => [...value].length > 1).sort((a,b) => b.length - a.length);
// Minimal Roblox values for style/scheduler tests; this does not simulate rendering.
let bundle = `local graphemeFixtures = {${graphemeTable}}
local complexGraphemes = {${complexGraphemes.map(value => literal(value)).join(',')}}
local utf8 = setmetatable({graphemes = function(value)
 local ranges = graphemeFixtures[value]
 -- CSS can prepend generated quotes/counters to fixture words. Compose the
 -- known fixture clusters with ordinary codepoints without losing UTF-8 bytes.
 if not ranges and utf8.len(value) ~= #value then
  ranges={};local at=1
  while at<=#value do
   local after=utf8.offset(value,2,at) or #value+1
   for _,cluster in complexGraphemes do
    if value:sub(at,at+#cluster-1)==cluster then after=at+#cluster;break end
   end
   table.insert(ranges,{at,after-1});at=after
  end
 end
 local index = 0
 return function()
  index += 1
  if ranges then
   local range = ranges[index]
   if range then return range[1], range[2] end
  elseif index <= #value then return index, index end
 end
end}, {__index = utf8})
local colorMeta = {__eq = function(a,b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end,
 __index = function(c,key) return rawget(c, if key == "R" then 1 elseif key == "G" then 2 elseif key == "B" then 3 else 0) end}
local Color3 = {
 new = function(r,g,b) return setmetatable({r,g,b}, colorMeta) end,
 fromRGB = function(r,g,b) return setmetatable({r/255,g/255,b/255}, colorMeta) end,
}
local UDim2 = {new = function(xs,x,ys,y) return {x,y,XScale=xs,YScale=ys} end, fromOffset = function(x,y) return {x,y} end, fromScale = function(x,y) return {x,y} end}
local UDim = {new = function(scale, offset) return {Scale = scale, Offset = offset} end}
local NumberSequence={new=function(a,b)return {a,b}end}
local ColorSequenceKeypoint={new=function(time,value)return {Time=time,Value=value}end}
local ColorSequence={new=function(points)return {Keypoints=points}end}
local Vector2 = {new = function(x,y) return {X=x, Y=y} end}
local Font={fromEnum=function(font)return {Family=font}end}
local Content = {fromObject = function(object) return object end, fromUri = function(uri) return uri end}
local Enum = {TextXAlignment={Left="Left",Center="Center"}, TextYAlignment={Top="Top",Center="Center"}, UserInputType={MouseButton1="MouseButton1",MouseMovement="MouseMovement",Touch="Touch",Keyboard="Keyboard"}, KeyCode={Escape="Escape",Tab="Tab",LeftShift="LeftShift",RightShift="RightShift",Space="Space",Return="Return",Left="Left",Right="Right",Up="Up",Down="Down"}, Font = {Arial = "Arial", SourceSans = "SourceSans", Ubuntu = "Ubuntu"},
 ScrollingDirection = {X = "X", Y = "Y", XY = "XY"}, ScrollBarInset = {Always = "Always", None = "None"}, ElasticBehavior = {Never = "Never", WhenScrollable = "WhenScrollable"},
 TextDirection = {Auto="Auto",LeftToRight="LeftToRight",RightToLeft="RightToLeft"},
 ScaleType = {Tile = "Tile", Stretch = "Stretch", Fit = "Fit", Crop = "Crop"}, ResamplerMode={Default="Default",Pixelated="Pixelated"}, ApplyStrokeMode = {Border = "Border"}, BorderStrokePosition = {Inner = "Inner"}, LineJoinMode = {Miter = "Miter", Round = "Round"}}
local loaders, loaded = {}, {}
local function require(id)
 if loaded[id] == nil then loaded[id] = loaders[id]() end
 return loaded[id]
end
`;
bundle += 'Enum.KeyCode.Home="Home"; Enum.KeyCode.End="End"; Enum.UserInputType.MouseButton2="MouseButton2"; Enum.UserInputType.MouseButton3="MouseButton3"\n';
bundle += 'for _,name in {"LeftControl","RightControl","LeftAlt","RightAlt","LeftMeta","RightMeta"} do Enum.KeyCode[name]=name end\n';
bundle += 'Enum.EasingStyle={Sine="Sine"}; Enum.EasingDirection={InOut="InOut"}; local TweenInfo={new=function(...) return {...} end}\n';
for (const id of ids) {
  bundle += `loaders[${JSON.stringify(id)}] = function()\n${readModule(id)}\nend\n`;
}
bundle += 'loaders["Input/TextSelection"] = function()\nlocal nativeRequire=require\nlocal function require(id)\nif id=="Rendering/GuiFactory" then return {create=function(_,parent,properties) local object=table.clone(properties);object.Parent=parent;object.Destroy=function(self) self.Destroyed=true end;return object end} end\nif id=="Layout/TextMeasure" then return {measure=function(text, font, size) return Vector2.new(#text*size/2,size) end} end\nreturn nativeRequire(id) end\n' + readModule('Input/TextSelection') + '\nend\n';
bundle += 'local function loadTextSelection(overrides)\nlocal nativeRequire=require\nlocal function require(id)return overrides[id] or nativeRequire(id)end\n'+readModule('Input/TextSelection')+'\nend\n';
bundle += 'local function loadBlockImage(overrides)\nlocal nativeRequire = require\nlocal function require(id) return overrides[id] or nativeRequire(id) end\n' + readModule('Layout/BlockImage') + '\nend\n';
bundle += 'local function loadGuiFactory(Instance, Enum, Font)\n' + readModule('Rendering/GuiFactory') + '\nend\n';
bundle += 'local function loadTextMeasure(Instance, game)\n' + readModule('Layout/TextMeasure') + '\nend\n';
bundle += 'local function loadFontProfiles(Font, Enum, typeof)\n' + readModule('Layout/FontProfiles') + '\nend\n';
bundle += 'local function loadControlDefaults(Enum)\n' + readModule('Controls/Defaults') + '\nend\n';
const svgStatusSource=demoSource.slice(demoSource.indexOf('local svgPrevious ='),demoSource.indexOf('local svgStatus='));
bundle += 'local function loadSVGStatus(page, print)\n' + svgStatusSource + '\nreturn reportSVG\nend\n';
bundle += 'local function loadDemoStatus(page, startup, showError, print)\n' + demoStatusSource + '\nreturn updateStatus\nend\n';
bundle += 'local function loadFontPreload(game, task, Enum)\n' + readModule('Rendering/FontPreload') + '\nend\n';
bundle += 'local function loadCursorPreload(game, task, Instance, warn)\n' + readModule('Input/CursorPreload') + '\nend\n';
bundle += 'local function loadImageLoad(game, task, Enum)\n' + readModule('Rendering/ImageLoad') + '\nend\n';
bundle += 'local function loadImageDimensions(game, task)\n' + readModule('Rendering/ImageDimensions') + '\nend\n';
bundle += 'local function loadShapeImages()\n' + readModule('Rendering/ShapeImages') + '\nend\n';
bundle += 'local function loadImageFilters(game, task)\n' + readModule('Rendering/ImageFilters') + '\nend\n';
bundle += 'local function loadImageBlur(game, task)\n' + readModule('Rendering/ImageBlur') + '\nend\n';
// Only this fixture loader substitutes these unused SVG imports; ordinary suites keep their original definitions.
const posterEmbeddedDependencies = ['SceneBuilder','Parser','Length','Geometry','Paint','Transform','TransformBounds','Rendering','Document','Gradient','Resources','Text'].map(name => 'SVG/' + name);
bundle += 'local function loadPosterSVG(taskAPI,options,counts,check)\nlocal nativeRequire=require\nlocal embedded=(function()\nlocal function require(id)if id:sub(1,4)=="SVG/" then return {} end;return nativeRequire(id)end\n'+readModule('SVG/Embedded', posterEmbeddedDependencies)+'\nend)()\nlocal document=embedded.document\nembedded.document=function(...)counts.CloneStarted+=1;local result=document(...);counts.CloneCompleted+=1;return result end\nlocal fakeQueue={new=function(_,_,tasks,services)\nlocal disposed=false;local pending=0;local api={Stats={Rasters=0,Uploads=0,WarmQueued=0,WarmCompleted=0,WarmCancelled=0,HitBuilds=0}}\nfunction api:Pending()return pending end\nfunction api:WarmPending()return 0 end\nfunction api:WarmCapacity()return 0 end\nfunction api:Request()if disposed then return false end;counts.RasterRequests+=1;pending+=1;services.VisibleChanged(false);tasks.defer(function()if not disposed then pending-=1;services.VisibleChanged(pending==0)end end);return true end\nfunction api:Remove()end\nfunction api:Reset()end\nfunction api:CancelWarm()end\nfunction api:Destroy()disposed=true end\nreturn api end}\nlocal function require(id)\nif id=="SVG/Embedded" then return embedded elseif id=="SVG/RenderQueue" then return fakeQueue elseif id=="SVG/Raster" then return {} elseif id=="SVG/Style" then return {collect=function()return {} end,stateKey=function()return "static" end}elseif id=="SVG/HitTest" then return {}end\nreturn nativeRequire(id) end\n'+readModule('Rendering/SVGImages', ['SVG/HitTest','SVG/Style'])+'\nend\n';

bundle += 'local function loadMediaRuntime(task)\n' + readModule('Input/MediaRuntime') + '\nend\n';
bundle += 'local function loadVirtualCameraHost(env)\nlocal game,Instance,typeof,UDim2,Color3,Vector3=env.Game,env.Instance,env.Typeof,env.UDim2,env.Color3,env.Vector3\n' + readModule('Rendering/VirtualCameraHost') + '\nend\n';
bundle += 'local function loadIFrameRuntime(task)\n' + readModule('Rendering/IFrameRuntime') + '\nend\n';
bundle += 'local function loadTextDecoration(factory)\nlocal nativeRequire = require\nlocal function require(id) return if id == "Rendering/GuiFactory" then factory else nativeRequire(id) end\n' + readModule('Layout/TextDecoration') + '\nend\n';
// Lifecycle uses synthetic trees and tasks without native RunService. The
// separate motion suites exercise the real runtime, including its idle startup.
bundle += 'local function loadHTMLPage(overrides, task, clock, hostGame, nativeTypes)\nlocal game = hostGame or game\nlocal warn=warn or function()end\nlocal UDim2=if nativeTypes then nativeTypes.UDim2 else UDim2\nlocal os = if clock then {clock = clock} else os\nlocal nativeRequire = require\nlocal function require(id)\nif overrides[id] then return overrides[id] end\nif id == "Rendering/HTMLAnimations" then return {start = function() end} end\nif id == "Layout/TextMeasure" then return {measure = function() error("Unexpected native measurement in lifecycle test") end} end\nif id == "Layout/WordLayout" then return {repaint = function() end} end\nif id == "Input/CursorPreload" or id == "Rendering/FontPreload" or id == "Rendering/ImageLoad" or id == "Rendering/ImageDimensions" or id == "Rendering/ShapeImages" then return {start = function() end} end\nreturn nativeRequire(id) end\n' + readModule('Rendering/HTMLPage') + '\nend\n';
bundle += 'local function loadResizableTestWindow(game, Instance, Vector2, require)\n' + fs.readFileSync(path.join(root, 'examples/ResizableTestWindow.luau'), 'utf8') + '\nend\n';
bundle += require('./browser-test-bundle.cjs')(root);
bundle += require('./fallback-test-bundle.cjs')(root);
// Execute the actual LocalScript bootstrap through its first standalone mount.
// Native service/module boundaries are supplied by the startup fixture.
const demoBootstrapEnd = demoSource.indexOf('local cold=page.ColdLoadStats');
assert.ok(demoBootstrapEnd > 0, 'Missing HTMLPageDemo bootstrap boundary');
bundle += 'local function loadHTMLDemoStart(env)\nlocal game,workspace,Instance,task,script,require,print,warn=env.Game,env.Workspace,env.Instance,env.Task,env.Script,env.Require,env.Print,env.Warn\nlocal Color3,UDim2,Vector2,Enum=env.Color3,env.UDim2,env.Vector2,env.Enum\n' + demoSource.slice(0, demoBootstrapEnd) + '\nend\n';
bundle += 'local function loadBrowserPersistenceStart(game,require)\n'+fs.readFileSync(path.join(root,'examples/BrowserPersistence.server.luau'),'utf8')+'\nend\n';
bundle += 'local function loadHTMLStorageStart(game,require,Instance,task,warn)\n'+fs.readFileSync(path.join(root,'examples/HTMLStorage.server.luau'),'utf8')+'\nend\n';
for (const [name,id] of [['loadBackgroundSVG','Rendering/BackgroundSVG'],['loadBackgroundImages','Rendering/BackgroundImages']]) {
  bundle += `local function ${name}(overrides)\nlocal nativeRequire = require\nlocal function require(id) return overrides[id] or nativeRequire(id) end\n` + readModule(id) + '\nend\n';
}
bundle += 'local function loadInlineGeometry(factory)\nlocal nativeRequire = require\nlocal function require(id)\nif id == "Layout/TextMeasure" then return {measure = factory.measure or function(text, _, size) return Vector2.new(#text*size/2,size) end} end\nreturn nativeRequire(id) end\n' + readModule('Rendering/InlineGeometry') + '\nend\n';
bundle += 'local function loadRenderTree(factory)\nfactory.modifier = factory.modifier or function(_, _, properties) return table.clone(properties) end\nlocal nativeRequire = require\nlocal function require(id)\nif id == "Rendering/InlineGeometry" then return loadInlineGeometry(factory) end\nreturn if id == "Rendering/GuiFactory" then factory else nativeRequire(id) end\n' + readModule('Rendering/RenderTree') + '\nend\n';
for (const [name, id] of [['loadListMarker', 'Layout/ListMarker'], ['loadWordLayout', 'Layout/WordLayout'], ['loadBlockLayout', 'Layout/BlockLayout']]) {
  bundle += `local function ${name}(overrides)\nlocal nativeRequire = require\nlocal markerModule\nlocal function require(id)\nif overrides[id] then return overrides[id] end\nif id == "Layout/BlockImage" then return setmetatable({}, {__index = function(_, key) return loadBlockImage(overrides)[key] end}) end\n${name === 'loadBlockLayout' || name === 'loadWordLayout' ? 'if id == "Layout/ListMarker" then return {arrange = function(...) markerModule = markerModule or loadListMarker(overrides); return markerModule.arrange(...) end} end\n' : ''}if id == "Layout/TextDecoration" then return loadTextDecoration({create = function(_, _, props) return table.clone(props) end}) end\nreturn nativeRequire(id) end\n` + readModule(id) + '\nend\n';
}
const floatReference = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/float-browser.json'), 'utf8'));
const floatReferenceLua = '{width='+floatReference.width+',text='+literal(floatReference.text)+',words={'+Object.entries(floatReference.words).map(([text,width])=>'[ '+literal(text)+' ]='+width).join(',')+'},lines={'+floatReference.lines.map(line=>'{x='+line.x+',y='+line.y+',text='+literal(line.text)+'}').join(',')+'}}';
function toLua(value) {
  if (typeof value === 'string') return literal(value);
  if (Array.isArray(value)) return '{'+value.map(toLua).join(',')+'}';
  if (value && typeof value === 'object') return '{'+Object.entries(value).map(([k,v])=>'[ '+literal(k)+' ]='+toLua(v)).join(',')+'}';
  return value === null ? 'nil' : String(value);
}
const engineEntry = fs.readFileSync(path.join(root, 'src/HTMLEngine/init.luau'), 'utf8').replace(/require\(script\.([A-Za-z0-9_.]+)\)/g, (_, ref) => 'require(' + JSON.stringify(ref.replaceAll('.', '/')) + ')');
bundle += 'local function loadEngine(require,script)\n' + engineEntry + '\nend\n';
bundle += 'local function loadWorkContext(game,task,os)\n' + readModule('WorkContext') + '\nend\n';
bundle += "local function loadWebsiteCatalog(script)\nlocal nativeRequire=require\nlocal function require(id)return if type(id)==\"table\" then id.Value else nativeRequire(id)end\n" + readModule("Websites") + "\nend\n";
bundle += "\nlocal function loadHTMLScriptsCaptured(capture)\nlocal nativeRequire=require\nlocal function require(id)\nif id == \"JavaScript/Runtime\" then local actual=nativeRequire(id);return {new=function(document,options)capture.Apply=options.ApplyChanges;return actual.new(document,options)end} end\nreturn nativeRequire(id) end\n" + readModule('Rendering/HTMLScripts') + "\nend\n";
const testCases = [
  ['EngineEntry', 'loadEngine,require("WorkContext")'],
  ['LoadingWork', 'require("WorkContext"),loadWorkContext,require("HTML/Parser"),require("DOM/Node"),require("CSS/Stylesheet"),require("CSS/InlineStyle"),loadRenderTree,require("JavaScript/Runtime")'],
  ['LoadingTextures','require("WorkContext"),require("Rendering/TextureUpload"),require("SVG/RenderQueue"),require("Rendering/BackgroundPixels"),require("CSS/InlineStyle")'],
  ['RenderingAudit', 'require("Rendering/CanvasSurface"), require("Rendering/CanvasRuntime"), require("Rendering/CanvasBackground"), require("Rendering/MediaBox")'],
  ['ScrollLifecycleAudit', 'require("Layout/ScrollLayout")'],
  ['CSSLayoutAudit', 'require("Layout/WordFlow"), require("CSS/InlineStyle"), require("CSS/MediaQueries"), require("Layout/LetterSpacing")'],
  ['RemainingVisuals', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/ImageFit"), require("Rendering/ImageBox"), require("Layout/ImageLayout"), require("Layout/ShapeImage"), require("Layout/FloatLayout"), loadShapeImages, loadRenderTree, '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/remaining-visuals-browser.json'),'utf8')))],
  ['FeasibleVisuals', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Rendering/GroupOpacity"), require("Rendering/BorderShapePixels"), require("Rendering/VisualEffects"), loadRenderTree, loadWordLayout, '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/inline-fragments-browser.json'),'utf8')))],
	['VisualCompleteness', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Rendering/BorderImagePixels"), require("Rendering/MaskPixels"), require("Rendering/ClipRect"), loadRenderTree, loadWordLayout, loadBlockLayout, require("CSS/Properties"), '+literal(stressPages.find(item => item.slug === 'html-css-stress-css-visual').source.html)+', '+literal(stressPages.find(item => item.slug === 'html-css-stress-css-visual').source.css)],
	['CSSInitial', 'require("CSS/InlineStyle"), require("CSS/Properties"), require("HTML/Parser"), loadRenderTree'],
	['FixedColumns', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/columns-fixed-browser.json'),'utf8')).filter(item=>item.columnCount!=='auto'))],
	['Columns', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/ColumnLayout"), loadRenderTree, loadWordLayout, loadBlockLayout, '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/columns-browser.json'),'utf8')))+', require("Layout/DirtyLayout"), require("Rendering/BorderBox")'],
	['ColumnFeatures', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
	['ColumnRuleInsets', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/ColumnRuleInsets"), loadRenderTree, loadWordLayout, loadBlockLayout'],
	['RemainingLayout', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/Properties"), require("CSS/MediaQueries"), require("Rendering/CanvasBackground"), loadRenderTree, loadWordLayout, loadBlockLayout, '+literal(stressPages.find(item => item.slug === 'html-css-stress-css-layout').source.html)+', '+literal(stressPages.find(item => item.slug === 'html-css-stress-css-layout').source.css)],
	['FlexBalance', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/FlexBalance"), loadRenderTree, loadWordLayout, loadBlockLayout'],
	['FloatShapes', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/FloatLayout"), require("Layout/WordFlow"), loadRenderTree, loadWordLayout, loadBlockLayout, '+floatReferenceLua],
	['FloatInline', 'require("HTML/Parser"), require("DOM/Node"), loadRenderTree, loadWordLayout, loadBlockLayout, '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/float-inline-browser.json'),'utf8')))+', '+literal(fs.readFileSync(path.join(root,'examples/websites/thebombmaker/index.html'),'utf8'))+', '+literal(fs.readFileSync(path.join(root,'examples/websites/thebombmaker/style.css'),'utf8'))+', '+toLua(Object.fromEntries([...fs.readFileSync(path.join(root,'src/HTMLEngine/Websites/Assets/ImageManifest.luau'),'utf8').matchAll(/\{Path="\/thebombmaker\/images\/([^\"]+)",Width=(\d+),Height=(\d+)/g)].map(([,name,width,height])=>[name,{Width:Number(width),Height:Number(height)}])))],
	['InlineAtomicAlignment', 'require("HTML/Parser"), require("DOM/Node"), loadRenderTree, loadWordLayout, loadBlockLayout, '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/inline-middle-browser.json'),'utf8')))+', '+literal(fs.readFileSync(path.join(root,'examples/websites/mutilation/index.html'),'utf8'))+', '+literal(fs.readFileSync(path.join(root,'examples/websites/mutilation/style.css'),'utf8'))+', '+toLua(Object.fromEntries([...fs.readFileSync(path.join(root,'src/HTMLEngine/Websites/Assets/ImageManifest.luau'),'utf8').matchAll(/\{Path="\/mutilation\/images\/([^\"]+)",Width=(\d+),Height=(\d+)/g)].map(([,name,width,height])=>[name,{Width:Number(width),Height:Number(height)}])))],
	['DocumentInfo', 'require("HTML/Parser"), require("HTML/DocumentInfo"), require("Input/Links")'],
	['Websites', mainHTMLLiteral + ', ' + mainCSSLiteral + ', ' + cssBackgroundPositionHTMLLiteral + ', ' + cssBackgroundPositionCSSLiteral + ', ' + cssIndividualTransformsHTMLLiteral + ', ' + cssIndividualTransformsCSSLiteral + ', ' + cssVisualPropertiesHTMLLiteral + ', ' + cssVisualPropertiesCSSLiteral + ', ' + cssTextAdvancedHTMLLiteral + ', ' + cssTextAdvancedCSSLiteral + ', ' + cssScrollInputHTMLLiteral + ', ' + cssScrollInputCSSLiteral + ', ' + cssFlowLayoutHTMLLiteral + ', ' + cssFlowLayoutCSSLiteral + ', ' + cssContainmentHTMLLiteral + ', ' + cssContainmentCSSLiteral + ', ' + cssEffectsHTMLLiteral + ', ' + cssEffectsCSSLiteral + ', ' + cssAdvancedMotionHTMLLiteral + ', ' + cssAdvancedMotionCSSLiteral + ', ' + cssFontFeaturesHTMLLiteral + ', ' + cssFontFeaturesCSSLiteral + ', ' + cssCountersHTMLLiteral + ', ' + cssCountersCSSLiteral + ', ' + cssExtendedHTMLLiteral + ', ' + cssExtendedCSSLiteral + ', ' + cssNextFeaturesHTMLLiteral + ', ' + cssNextFeaturesCSSLiteral + ', ' + notFoundHTMLLiteral + ', ' + notFoundCSSLiteral + ', require("HTML/Parser"), loadRenderTree'],
	['Links', 'require("Navigation/URL")'],
  ['Grid', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/GridValues"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['LayoutPaintWrites', 'require("HTML/Parser"),require("DOM/Node"),loadRenderTree,loadWordLayout,loadBlockLayout,UDim2'],
  ['SVGEmbedding', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("SVG/Sizing"), loadRenderTree, loadWordLayout, loadBlockLayout, ' + svgEmbeddingLiteral],
  ['SVGStatus', 'loadSVGStatus'],
  ['DemoStatus', 'loadDemoStatus'],
  ['ImageFilters', 'require("CSS/Filter"), require("Rendering/ImageFilterPixels"), loadImageFilters, require("HTML/Parser"), loadRenderTree, loadImageLoad'],
  ['ImageBlur', 'require("CSS/Filter"), require("Rendering/ImageBlurPixels"), loadImageBlur, require("HTML/Parser"), loadRenderTree, loadWordLayout, require("Rendering/ImageBox")'],
  ['ImageDropShadow', 'require("CSS/Filter"), require("Rendering/ImageBlurPixels"), require("HTML/Parser"), loadRenderTree, loadWordLayout, loadImageBlur'],
  ['CursorPreload', 'loadCursorPreload, require("Input/CursorIcons")'],
  ['TableSpans', 'require("HTML/Parser"), require("Layout/TableGrid"), require("Layout/DirtyLayout"), require("Input/HitTest"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TableCollapse', 'require("HTML/Parser"), require("Layout/DirtyLayout"), require("Input/HitTest"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TableFixed', 'require("HTML/Parser"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TableExtras', 'require("HTML/Parser"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TableAdvanced', 'require("HTML/Parser"), require("Layout/DirtyLayout"), require("Layout/TableGrid"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TableIncremental', 'require("HTML/Parser"), require("DOM/Node"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['Cursors', 'require("HTML/Parser"), require("CSS/Cursor"), require("Input/CursorIcons"), require("Input/CursorLease"), require("Input/CursorController"), require("Input/Controller"), require("Input/HitTest"), loadRenderTree, require("Rendering/PaintLayer")'],
  ['Tables', 'require("HTML/Parser"), require("DOM/Node"), require("CSS/InlineStyle"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['Details', 'require("HTML/Parser"), require("DOM/Node"), require("Rendering/Disclosure"), require("Layout/DirtyLayout"), require("Input/Controller"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/HTMLScripts")'],
  ['DetailsGroups', 'require("HTML/Parser"), require("DOM/Node"), require("JavaScript/Runtime"), require("Input/Events"), require("DOM/DetailsState")'],
  ['ProjectiveHit', 'require("Rendering/ProjectiveHit"), require("CSS/Matrix4"), require("Input/HitTest")'],
  ['JavaScriptTypedMath', 'require("HTML/Parser"), require("JavaScript/Runtime"), require("Input/Events"), '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/typed-om-math-browser.json'),'utf8')))],
  ['Dialog', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/Dialog")'],
  ['TopLayerPositioning', 'require("HTML/Parser"),require("DOM/Node"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/Dialog"),require("Rendering/Popover"),require("Rendering/ViewportLayer"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/top-layer-positioning.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/top-layer-positioning-browser.json'),'utf8')))],
  ['DisclosureIcons', 'require("Rendering/DisclosureIcons"), require("HTML/Parser"), loadRenderTree, require("Rendering/Disclosure")'],
  ['Popover', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/Popover")'],
  ['Optgroups', 'require("HTML/Parser"), require("DOM/Node"), require("Controls/State"), require("Controls/FormModel"), require("Input/Events"), require("Input/SelectPopup"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['SelectTypeAhead', 'require("Input/SelectTypeAhead")'],
  ['Autofocus', 'require("HTML/Parser"), require("Input/Controller"), loadRenderTree'],
  ['FocusOutline', 'require("HTML/Parser"), require("DOM/Node"), require("Input/Controller"), loadRenderTree, loadWordLayout, loadBlockLayout, '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/focus-outline-browser.json'),'utf8')))],
  ['ValidationPopup', 'require("HTML/Parser"), require("Input/Controller"), require("Controls/ValidationMessage"), require("Input/ValidationPopup"), loadRenderTree'],
  ['TextValidation', 'require("HTML/Parser"), require("DOM/Node"), require("Controls/State"), require("Controls/TextValue"), require("Controls/URLValue"), require("Controls/FormModel"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['Fieldsets', 'require("HTML/Parser"), require("DOM/Node"), require("Controls/State"), require("Controls/FormModel"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TextareaResize', 'require("Rendering/ResizeGrip"), require("Input/TextareaResize"), require("HTML/Parser"), require("Controls/View"), require("Input/Controller"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['Gauges', 'require("HTML/Parser"), require("DOM/Node"), require("Controls/State"), require("Controls/GaugeValue"), require("Controls/View"), require("Input/Controller"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['Number', 'require("Controls/NumberValue"), require("HTML/Parser"), require("DOM/Node"), require("Controls/State"), require("Input/Controller"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TemporalInputs', 'require("Controls/TemporalValue"), require("Controls/TemporalEdit"), require("Input/TemporalPopup"), require("HTML/Parser"), require("DOM/Node"), require("Controls/State"), require("Controls/FormModel"), require("Input/Events"), require("JavaScript/Runtime"), loadRenderTree, loadWordLayout, loadBlockLayout, '+toLua(retiredPageFile('input-types','index.html'))+', '+toLua(retiredPageFile('input-types','app.js'))+', require("Input/Controller")'],
  ['Range', 'require("Controls/RangeValue"), require("HTML/Parser"), require("DOM/Node"), require("Input/Controller"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['RadioDot', 'require("Rendering/RadioDot"), require("Controls/View"), require("HTML/Parser"), loadRenderTree'],
  ['Select', 'require("HTML/Parser"), require("DOM/Node"), require("Controls/State"), require("Controls/FormModel"), require("Input/Events"), require("Input/Controller"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['Forms', 'require("HTML/Parser"), require("DOM/Node"), require("Controls/State"), require("Controls/FormModel"), require("Input/Events"), require("Input/HitTest"), require("Input/Controller"), loadRenderTree, loadWordLayout, loadBlockLayout, loadControlDefaults, loadFontProfiles, require("Controls/View")'],
  ['DirtyLayout', 'require("HTML/Parser"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout, ' + featureLiteral + ', require("Controls/View")'],
	['RelativeLengths', 'require("CSS/InlineStyle"), require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, require("CSS/LengthExpression")'],
	['Backgrounds', 'require("CSS/InlineStyle"), require("Rendering/BackgroundPixels"), require("Rendering/BackgroundImages")'],
	['ThreeDTransforms', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/Transform2D"), require("CSS/Matrix4"), require("Rendering/PerspectivePixels"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/HTMLAnimations"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/transform-composition-native.json'),'utf8')))],
	['Transforms', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/Transform2D"), loadRenderTree, loadWordLayout, loadBlockLayout'],
	['Motion', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/Stylesheet"), require("CSS/Motion"), require("CSS/MotionPath")'],
	['Animations', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/HTMLAnimations"), require("Rendering/ViewportLayer"), ' + literal(stressPages.find(item => item.slug === 'html-css-stress-effects').source.html) + ', ' + literal(stressPages.find(item => item.slug === 'html-css-stress-effects').source.css)],
	['HoverTransitionGeometry', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/HTMLAnimations"), require("Layout/DirtyLayout")'],
  ['MediumAdditions', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/Properties"), loadRenderTree, loadWordLayout, loadBlockLayout, ' + featureLiteral],
	['VerticalText', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout, '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/vertical-upright-browser.json'),'utf8')))],
	['CSSExpansion', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/Properties"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Layout/ScrollLayout")'],
	['HTMLMasks', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Rendering/MaskPixels"), loadRenderTree, loadWordLayout, loadBlockLayout, '+literal(stressPages.find(item => item.slug === 'html-css-stress-effects').source.css)],
	['VisualEffects', 'require("Rendering/VisualEffectPixels")'],
  ['RenderingLifetimes', 'require("Rendering/VisualEffects"), require("Rendering/BorderCorners"), require("CSS/InlineStyle"), require("WorkContext"), require("Rendering/InsetShadows")'],
  ['HTML', 'require("HTML/Parser"), require("DOM/Node")'],
  ['AttributeCatalog', 'require("HTML/Parser"), '+toLua(JSON.parse(fs.readFileSync(path.join(root,'docs/html-attributes.v1.json'),'utf8')))],
  ['AttributeCombinations', 'require("HTML/Parser"), require("DOM/Node"), require("JavaScript/Runtime"), require("Input/Events"), require("Controls/State"), require("Controls/FormModel"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['DocumentTree', 'require("HTML/Parser"), require("DOM/Node"), '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/html-document-tree.json'),'utf8')))],
  ['ImageDimensions', 'loadImageDimensions, require("HTML/Parser"), loadRenderTree, loadWordLayout'],
  ['ImageSources', 'require("Rendering/ImageSources")'],
  ['TextShadows', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout'],
	['Images', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadImageLoad'],
	['ResponsiveImages', 'require("HTML/Parser"), require("HTML/ResponsiveSources"), require("Input/ImageMap"), require("Input/Links"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/responsive-source-browser.json'),'utf8')))],
	['Media', 'require("HTML/Parser"), require("Rendering/MediaSources"), require("HTML/WebVTT"), loadRenderTree, require("Rendering/ImageSources")'],
  ['MediaRuntime', 'require("HTML/Parser"), loadMediaRuntime, require("Rendering/MediaBox")'],
	['IFrames', 'loadIFrameRuntime'],
	['CanvasBackground', 'require("HTML/Parser"), require("Rendering/CanvasBackground")'],
	['Canvas2D', 'require("Rendering/CanvasSurface"), require("SVG/ScriptVM"), require("Rendering/CanvasRuntime"), require("Rendering/CanvasWebGL"), require("Rendering/WorkBudget"), require("HTML/Parser"), ' + literal(stressPages.find(item => item.slug === 'html-css-stress-media').source.html)],
  ['ImageFit', 'require("CSS/InlineStyle"), require("Layout/ImageFit"), require("HTML/Parser"), loadRenderTree, loadWordLayout'],
  ['ImageAlignment', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/FontMetrics"), loadRenderTree, loadWordLayout'],
  ['InlineStyle', 'require("CSS/InlineStyle")'],
  ['LogicalSizing','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("JavaScript/ComputedStyle"),require("JavaScript/CSSDeclarations"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/logical-sizing-browser.json'),'utf8')))],
  ['IntrinsicHeight','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("JavaScript/ComputedStyle"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/intrinsic-height-browser.json'),'utf8')))],
  ['Visibility', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/ImageBox"), require("Layout/SkipInk")'],
  ['Colors', 'require("CSS/InlineStyle"), require("HTML/Parser"), loadRenderTree, loadWordLayout, require("Rendering/InsetShadowPixels"), require("Rendering/InsetShadows")'],
  ['Stylesheet', 'require("HTML/Parser"), require("DOM/Node"), loadRenderTree, require("CSS/Stylesheet")'],
  ['StylesheetCandidates', 'require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("CSS/Stylesheet")'],
  ['InlineBoxes', 'require("HTML/Parser"), require("DOM/Node"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TextSelection', 'require("HTML/Parser"), require("DOM/Node"), require("CSS/InlineStyle"), require("CSS/Stylesheet"), require("Input/TextSelection")'],
  ['Selectors', 'require("CSS/Selectors")'],
  ['Elements', 'require("HTML/Elements"), require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['NoScript', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOMMarkup"),loadRenderTree,loadWordLayout,loadBlockLayout'],
  ['HTMLPageDemo', demoLiteral + ', require("HTML/Parser"), loadRenderTree'],
  ['StudioWebsite', literal(currentMain.html) + ', ' + literal(currentMain.css) + ', ' + literal(currentTest.html) + ', ' + literal(currentTest.css) + ', require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['CyclicImageSizing', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['HoverTests', literal(currentHover.browserHTML) + ', ' + literal(currentHover.browserCSS) + ', require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/HTMLAnimations")'],
  ['CombinationStates', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/HTMLAnimations")'],
  ['CombinationPositioning', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/ViewportLayer")'],
  ['CombinationLayout', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['CombinationScrolling', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['CombinationPainting', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/ViewportLayer")'],
  ['HoverBorders', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['HoverWork', 'require("HTML/Parser"), require("DOM/Node"), require("CSS/Selectors"), require("CSS/Stylesheet"), require("Rendering/GeneratedContent"), require("Rendering/BoxTransform"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/HTMLAnimations")'],
  ['FontProfiles', 'require("Layout/FontProfiles")'],
  ['FontWeight', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/FontMetrics"), loadRenderTree, loadWordLayout, loadFontProfiles'],
  ['FontStyle', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/FontMetrics"), loadRenderTree, loadWordLayout, loadFontProfiles'],
  ['FontFeatures', 'require("CSS/InlineStyle"), require("CSS/FontFeatures")'],
  ['Counters', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/Counters"), loadRenderTree'],
  ['TextDecoration', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadTextDecoration'],
  ['DecorationStyles', 'require("CSS/InlineStyle"), require("Rendering/DecorationPixels"), require("Rendering/DecorationPatterns"), loadTextDecoration, require("Layout/SkipInk"), require("HTML/Parser"), loadRenderTree'],
  ['SkipInk', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/SkipInk"), loadRenderTree, loadWordLayout, loadTextDecoration'],
  ['LoadOptimizations', 'require("HTML/Parser"), require("DOM/Node"), require("CSS/InlineStyle"), require("CSS/Stylesheet"), loadFontProfiles, loadRenderTree, loadWordLayout, loadFontPreload'],
  ['GuideEstimates', 'require("Layout/FontProfiles")'],
  ['GuiFactory', 'loadGuiFactory'],
  ['TextMeasure', 'loadTextMeasure'],
  ['WordFlow', 'require("Layout/TextWords"), require("Layout/WordFlow")'],
  ['LineHeight', 'require("CSS/InlineStyle"), require("Layout/TextWords"), require("Layout/FontProfiles"), loadWordLayout, loadBlockLayout'],
  ['Baseline', 'require("HTML/Parser"), require("Layout/FontProfiles"), require("Layout/FontMetrics"), require("Layout/WordFlow"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TextAlign', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/WordFlow"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TextTransform', 'require("HTML/Parser"), require("DOM/Node"), require("CSS/InlineStyle"), require("Layout/TextTransform"), loadRenderTree, loadWordLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/text-transform-browser.json'),'utf8')))+',require("Layout/TextCaseData")'],
  ['TextIndent', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/WordFlow"), loadRenderTree, loadWordLayout, loadBlockLayout, '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/text-indent-browser.json'),'utf8')))],
  ['WordSpacing', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout'],
  ['LetterSpacing', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Layout/LetterSpacing"), loadRenderTree, loadWordLayout'],
  ['Border', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['Outline', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['BorderSides', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Layout/ImageLayout"), require("Rendering/ImageBox"), require("Rendering/InsetShadowPixels")'],
  ['BoxSizing', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['AspectRatio', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['BoxShadow', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['InsetShadows', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("Rendering/InsetShadowPixels"), require("Rendering/InsetShadows"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['Overflow', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
	['Scrolling', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
	['ScrollFeatures', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['OverflowWrap', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['TextOverflow', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['SimpleAdditions', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/Color"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['BorderCorners', 'require("CSS/InlineStyle"), require("Rendering/BorderCornerPixels"), require("Rendering/BorderCorners"), require("Rendering/BorderBox"), require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['FlexLayout', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['FlexWrap', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['FlexItemControls', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['AutoMargins', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['FlexBaseline', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['Positioning', 'require("HTML/Parser"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/ViewportLayer")'],
  ['SimpleFeatures', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("CSS/Color"), require("CSS/NamedColors"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['MarginCollapse', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['Lists', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("DOM/Node"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['SmallElements', 'require("HTML/Parser"), require("CSS/InlineStyle"), require("DOM/Node"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['WhiteSpace', 'require("HTML/Parser"), require("DOM/Node"), require("CSS/InlineStyle"), loadRenderTree, loadWordLayout, loadBlockLayout, '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/whitespace-browser.json'),'utf8')))],
  ['SVGHTMLIntegration', 'require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, '+ '[===['+svgFixture('examples/SVGLab/IntegrationPerformanceSource.luau').match(/HTML=\[===\[([\s\S]*?)\]===\]/)[1]+']===]'],
  ['StressCatalog', '{' + stressPages.map(item => '{name=' + literal(item.slug) + ',html=' + literal(item.source.html) + ',css=' + literal(item.source.css) + '}').join(',') + '}, require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['StressLayoutFeatures', literal(stressPages.find(item => item.slug === 'html-css-stress-layout').source.html) + ', ' + literal(stressPages.find(item => item.slug === 'html-css-stress-layout').source.css) + ', require("HTML/Parser"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Layout/ScrollLayout"), require("Input/HitTest")'],
  ['LayoutJob', 'require("Rendering/LayoutJob")'],
  ['ResizableTestWindow', 'loadResizableTestWindow'],
  ['CooperativeLayout', 'require("HTML/Parser"), require("Rendering/LayoutJob"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout'],
  ['JavaScriptLayout', 'require("HTML/Parser"), require("DOM/Node"), require("JavaScript/Runtime"), require("Input/Events"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/HTMLScripts"), require("Controls/FormModel"), ' + literal(fs.readFileSync(path.join(root, "tests/fixtures/javascript-labor-classic.html"), "utf8")) + ", " + literal(fs.readFileSync(path.join(root, "tests/fixtures/javascript-labor-classic.css"), "utf8"))],
  ['JavaScript', 'require("JavaScript/VM"), require("JavaScript/Runtime"), require("HTML/Parser"), require("DOM/Node"), require("Input/Events"), loadRenderTree, require("Rendering/HTMLScripts"), require("Controls/FormModel"), ' + literal(fs.readFileSync(path.join(root, "tests/fixtures/javascript-labor-classic.html"), "utf8")) + ", " + literal(fs.readFileSync(path.join(root, "tests/fixtures/javascript-labor-classic.css"), "utf8"))],
  ['PageLifecycle', 'require("PageSession"), loadHTMLPage'],
  ['PageResizeGestures', 'loadHTMLPage, require("Rendering/ScriptGeometry"), require("JavaScript/Geometry"), require("JavaScript/VM")'],
  ['PageLoading', 'loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/Dialog"),require("Rendering/Popover"),require("DOM/Node")'],
  ['SVGQueueVisibility', 'require("SVG/RenderQueue")'],
  ['HTMLPageAnimationScheduling', 'loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLAnimations"),require("DOM/Node")'],
];
testCases.push(['JavaScriptDOM', 'require("HTML/Parser"), require("DOM/Node"), require("JavaScript/Runtime"), require("Input/Events"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/HTMLScripts"), require("Controls/FormModel"), require("Input/Controller"), '+literal(fs.readFileSync(path.join(root,'tests/fixtures/javascript-labor-classic.html'),'utf8'))+', '+literal(fs.readFileSync(path.join(root,'tests/fixtures/javascript-labor-classic.css'),'utf8'))]);
const requested = new Set(process.argv.slice(2));
testCases.push(['AnimationPositionedOpacity','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLAnimations"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/animation-positioned-opacity-browser.json'),'utf8')))]);
testCases.push(['ColorPopup','require("Input/ColorPopup"),require("HTML/Parser"),require("DOM/Node"),require("Controls/State"),require("Controls/FormModel"),require("Input/Events"),require("Input/Controller"),require("Rendering/HTMLScripts"),loadRenderTree,loadWordLayout,loadBlockLayout']);
testCases.push(['Bidi','require("Layout/Bidi")']);
testCases.push(['BidiRendering','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("CSS/Directionality"),require("Layout/BidiInline"),require("Layout/BidiPaint"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/ScriptSelection"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/bidi-browser.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/bidi-ellipsis-browser.json'),'utf8')))]);
testCases.push(['VerticalMixed','require("HTML/Parser"),require("DOM/Node"),require("Layout/VerticalOrientation"),require("Layout/BidiPaint"),require("Layout/FontMetrics"),loadRenderTree,loadWordLayout,require("Rendering/ScriptSelection"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/vertical-mixed-browser.json'),'utf8')))+',loadTextSelection']);
testCases.push(['WritingAxes','require("CSS/InlineStyle"),require("CSS/WritingMode"),require("Layout/ScrollLayout"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/writing-axes-browser.json'),'utf8')))]);
testCases.push(['VerticalFragments','require("HTML/Parser"),require("DOM/Node"),require("Layout/FontMetrics"),loadRenderTree,loadWordLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/vertical-fragments-browser.json'),'utf8')))+',require("Rendering/ScriptSelection"),loadTextSelection']);
testCases.push(['VerticalDecoration','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("JavaScript/ComputedStyle"),require("Layout/FontMetrics"),loadRenderTree,loadWordLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/vertical-decoration-browser.json'),'utf8')))+',loadTextDecoration']);
testCases.push(['VerticalShadows','require("HTML/Parser"),require("DOM/Node"),require("Layout/FontMetrics"),loadRenderTree,loadWordLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/vertical-shadow-browser.json'),'utf8')))]);
testCases.push(['VerticalEmphasis','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("JavaScript/ComputedStyle"),require("Layout/FontMetrics"),require("Layout/TextEmphasis"),loadRenderTree,loadWordLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/vertical-emphasis-browser.json'),'utf8')))+',require("Rendering/ScriptSelection"),loadTextSelection,require("Rendering/GroupOpacity")']);
testCases.push(['HTMLMixBlending','require("HTML/Parser"),require("DOM/Node"),require("Rendering/PerspectivePixels"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/html-mix-blend-native.json'),'utf8')))]);
testCases.push(['CanvasBackgroundRendering','require("HTML/Parser"),require("DOM/Node"),require("Rendering/CanvasBackground"),require("Rendering/BackgroundImages"),require("JavaScript/Runtime"),require("Input/Events"),require("Rendering/HTMLScripts"),require("Layout/DirtyLayout"),require("Input/Controller"),require("Rendering/HTMLAnimations"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/canvas-background-browser.json'),'utf8')))+',loadHTMLPage,loadBackgroundSVG,loadBackgroundImages,require("Rendering/BorderCorners")']);
testCases.push(['CanvasInlineBackground','require("HTML/Parser"),require("DOM/Node"),require("Rendering/CanvasBackground"),require("Rendering/BackgroundImages"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/canvas-inline-background-browser.json'),'utf8')))]);
testCases.push(['LetterSpacingDynamic','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("Layout/InlineWords"),require("Rendering/SpacingOwners"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/letter-spacing-dynamic-browser.json'),'utf8')))]);
testCases.push(['JavaScriptDOMExpansion', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),require("Input/Events")']);
testCases.push(['JavaScriptModules', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("JavaScript/VM"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-modules.json'),'utf8')))]);
testCases.push(['JavaScriptWebAnimations', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),require("Input/Events"),require("JavaScript/HostEvents"),require("JavaScript/Promises"),require("JavaScript/WebAnimations"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/animation-zero-duration-native.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/css-animation-dom-native.json'),'utf8')))]);
testCases.push(['JavaScriptDOMCanvas', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),require("Input/Events"),require("JavaScript/HostEvents"),require("JavaScript/BinaryData"),require("JavaScript/DOMCanvas"),require("Rendering/CanvasSurface")']);
testCases.push(['JavaScriptCanvasHostIntegration', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Rendering/CanvasSurface")']);
testCases.push(['JavaScriptRuntimeStorage', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("JavaScript/Storage")']);
testCases.push(['WebStorageServer', 'require("Storage/Protocol"),require("Storage/Server")']);
testCases.push(['WebStorageClient', 'require("Storage/Client"),require("Storage/Protocol"),require("Storage/Server"),require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("JavaScript/Strings")']);
testCases.push(['SessionStorageHost', 'require("Storage/Memory"),require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(Object.fromEntries(['default','htmlpage','browser'].map(name=>[name,JSON.parse(fs.readFileSync(path.join(root,name+'.project.json'),'utf8'))])))+',function(game,require,Instance,task)\n'+fs.readFileSync(path.join(root,'examples/compat/RetiredPersistence.server.luau'),'utf8')+'\nend']);
testCases.push(['WebStorageRendering', 'require("HTML/Parser"),require("Rendering/HTMLScripts"),require("Input/Events"),require("JavaScript/Storage"),loadRenderTree,require("Controls/FormModel"),loadIFrameRuntime']);
testCases.push(['JavaScriptReviewPage', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),require("Rendering/CanvasSurface"),'+literal(previousJavaScriptReview.html)+','+literal(previousJavaScriptReview.css)+','+toLua(JSON.parse(retiredFile('javascript-tests','options.json')))]);
testCases.push(['JavaScriptRangeReviewPage', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),require("Rendering/CanvasSurface"),'+literal(previousRangeReview.html)+','+literal(previousRangeReview.css)+','+toLua(JSON.parse(retiredFile('javascript-tests','options.json')))]);
testCases.push(['JavaScriptSelection', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-selection.json'),'utf8')).filter(x=>!x.browserOnly))]);
const r04BrowserCases = JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-r04-selection-browser.json'),'utf8')).cases;
const r04Selection = JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-r04-selection.json'),'utf8'));
testCases.push(['JavaScriptShadowSelection', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(r04Selection.filter(x=>!x.name.startsWith('control ')&&!x.name.startsWith('password ')&&!['modify paragraph and document boundaries','selection crossing shadow boundary'].includes(x.name)).map(x=>({...x,expected:r04BrowserCases.find(y=>y.name===x.name).expected})))]);
testCases.push(['JavaScriptLanguage', 'require("JavaScript/VM"),require("JavaScript/StandardLibrary"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-r01-core.json'),'utf8')))+',require("JavaScript/BinaryData")']);
testCases.push(['JavaScriptAPIInventory', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events")']);
testCases.push(['JavaScriptAdoptEvents', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['JavaScriptSelectionRealms', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['JavaScriptInputReferences', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['JavaScriptCSSOM', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-cssom.json'),'utf8')).filter(x=>!x.browserOnly))]);
testCases.push(['JavaScriptRealmLifetime', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events")']);
testCases.push(['JavaScriptEncoding','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/encoding-browser.json'),'utf8')))]);
testCases.push(['EncodingDecoders','require("Encoding/Decoder"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/encoding-browser.json'),'utf8')))]);
testCases.push(['LiveByteDocuments','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/live-byte-documents-browser.json'),'utf8')))]);
testCases.push(['HTMLEncoding','require("HTML/Parser"),require("DOM/Node"),require("HTML/EncodingSniff"),require("HTML/DocumentInfo"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/html-encoding-browser.json'),'utf8')))]);
testCases.push(['DocumentLanguage','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/html-language-browser.json'),'utf8')))]);
testCases.push(['QuirksSelectors','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/html-quirks-browser.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/quirks-hover-browser.json'),'utf8')))]);
testCases.push(['QuirksValues','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/quirks-values-browser.json'),'utf8')))]);
testCases.push(['QuirksLayoutRendering','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/quirks-layout-browser.json'),'utf8')))]);
testCases.push(['InlineGeometryRendering','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/ScriptGeometry"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/inline-geometry-browser.json'),'utf8')))]);
testCases.push(['FormSelectors','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/form-selectors-browser.json'),'utf8')))]);
testCases.push(['SelectorNames','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Stylesheet"),loadRenderTree,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/selector-names-browser.json'),'utf8')))]);
testCases.push(['RelationalSelectors','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Selectors"),require("CSS/Nesting"),require("CSS/Stylesheet"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/relational-selectors-browser.json'),'utf8')))]);
testCases.push(['SelectText','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/select-text-browser.json'),'utf8')))]);
testCases.push(['ConstraintValidation','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/constraint-validation-browser.json'),'utf8')))]);
testCases.push(['JavaScriptTextControlSelection', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Controls/TextSelection"),require("Controls/State"),require("JavaScript/Strings"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-text-control-selection.json'),'utf8')))]);
testCases.push(['JavaScriptTextControlSelectionRendering', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller")']);
testCases.push(['JavaScriptStableGeometryRendering', 'require("HTML/Parser"),require("DOM/Node"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),require("Controls/View"),require("Input/Controller")']);
testCases.push(['JavaScriptContentEditing', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller")']);
testCases.push(['JavaScriptR04ReferenceRendering', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller"),'+toLua(r04Selection.filter(x=>x.name.startsWith('control ')||x.name.startsWith('password ')||['modify paragraph and document boundaries','selection crossing shadow boundary'].includes(x.name)).map(x=>({...x,expected:r04BrowserCases.find(y=>y.name===x.name).expected})))]);
testCases.push(['JavaScriptSelectionCommitReviewPage', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller"),'+literal(previousSelectionCommitReview.html)+','+literal(previousSelectionCommitReview.css)+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-selection-commit-page-browser.json'),'utf8')))]);
testCases.push(['JavaScriptTopLayerPerformanceReviewPage', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller"),'+literal(previousTopLayerReview.html)+','+literal(previousTopLayerReview.css)+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-top-layer-performance-page-browser.json'),'utf8')))+',require("Rendering/Dialog"),require("Rendering/Popover"),require("Rendering/ViewportLayer"),require("Input/HitTest")']);
testCases.push(['JavaScriptTopLayerRendering', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller"),require("Rendering/Dialog"),require("Rendering/Popover"),require("Rendering/GroupOpacity")']);
testCases.push(['JavaScriptTopLayer', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-top-layer.json'),'utf8')))]);
testCases.push(['JavaScriptPerformance', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-performance.json'),'utf8')))]);
testCases.push(['JavaScriptAnimationCommit', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLAnimations"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-animation-commit.json'),'utf8')))]);
testCases.push(['JavaScriptCSSOMRendering', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),require("Input/Controller"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/select-sizing-browser.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/select-pseudos-browser.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/editing-selectors-browser.json'),'utf8')))]);
testCases.push(['JavaScriptTablesRendering', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel")']);
testCases.push(['JavaScriptComponentsRendering', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel")']);
testCases.push(['JavaScriptShadowMutations', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel")']);
testCases.push(['CSSLayoutAnimations','require("HTML/Parser"),require("DOM/Node"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Layout/DirtyLayout"),require("Rendering/HTMLAnimations"),require("Rendering/AnimationValues"),require("Rendering/BoxTransform"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/animation-font-transition-native.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/animation-color-transition-native.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/css-animation-dom-native.json'),'utf8'))) ]);
testCases.push(['CSSRuleFamilies','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("CSS/Stylesheet"),require("CSS/CounterStyles"),loadRenderTree']);
testCases.push(['GeneratedContentRendering','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout']);
testCases.push(['JavaScriptPseudoContent','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-pseudo-content.json'),'utf8')))]);
testCases.push(['JavaScriptAnimationLayout','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLAnimations"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-animation-layout.json'),'utf8')))+',require("Rendering/ProjectiveHit"),require("Rendering/ViewportLayer"),require("Rendering/BorderCorners"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/css-animation-dom-native.json'),'utf8')))+',require("Rendering/InsetShadows")']);
testCases.push(['JavaScriptComponentsReviewPage','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller"),require("Rendering/HTMLAnimations"),'+literal(previousComponentsReview.html)+','+literal(previousComponentsReview.css)]);
testCases.push(['JavaScriptR04ReviewPage','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller"),require("Rendering/HTMLAnimations"),'+literal(currentJavaScript.browserHTML)+','+literal(currentJavaScript.browserCSS)]);
const fernwehFolder = 'fernweh';
const fernwehSVGs = Object.fromEntries(JSON.parse(retiredFile(fernwehFolder,'options.json')).LocalSVG.map(name => [name,retiredFile(fernwehFolder,name)]));
testCases.push(['FernwehWebsite','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller"),require("Rendering/HTMLAnimations"),'+literal(retiredFile(fernwehFolder,'index.html'))+','+literal(retiredFile(fernwehFolder,'styles.css'))+','+literal(retiredFile(fernwehFolder,'app.js'))+','+toLua(fernwehSVGs)+',require("Rendering/BorderCorners")']);
testCases.push(['JavaScriptCSSOMRules','require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),'+literal(fs.readFileSync(path.join(root,'tests/fixtures/cssom-rules-reference.js'),'utf8'))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/cssom-rules-expected.json'),'utf8')))]);
testCases.push(['JavaScriptComponents','require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-components.json'),'utf8')))]);
testCases.push(['JavaScriptElementInternalsState','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['JavaScriptDocuments','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['NamedPropertyMutations','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("JavaScript/DOMNamedProperties"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/named-property-mutations-browser.json'),'utf8')))]);
testCases.push(['TemplateDocuments','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("DOM/TemplateDocument"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/template-document-browser.json'),'utf8')))]);
testCases.push(['HTMLExpandedNames','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("DOM/ElementNames"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/html-expanded-names-browser.json'),'utf8')))]);
testCases.push(['HTMLExpandedRendering','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/html-expanded-rendering-browser.json'),'utf8')))]);
testCases.push(['HTMLExpandedHosts','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Stylesheet"),require("CSS/InlineStyle"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/html-expanded-host-browser.json'),'utf8')))]);
testCases.push(['HTMLExpandedResources','require("HTML/Parser"),require("DOM/Node"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),require("Rendering/CanvasRuntime"),require("Rendering/MediaSources"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/html-expanded-resource-browser.json'),'utf8')))]);
testCases.push(['InlineReplacedTransforms','require("HTML/Parser"),require("DOM/Node"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller"),require("Rendering/HTMLAnimations"),require("Rendering/BoxTransform"),require("Layout/LayoutMeasurement"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/inline-replaced-transforms-browser.json'),'utf8')))]);
testCases.push(['SVGStyleOwners','require("HTML/Parser"),require("JavaScript/DOMXML"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Stylesheet"),require("CSS/InlineStyle"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),require("Input/Controller"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/svg-style-owner-browser.json'),'utf8')))]);
testCases.push(['IntrinsicScrollbars','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("Layout/DirtyLayout"),require("Layout/ScrollLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/intrinsic-scrollbars-browser.json'),'utf8')))]);
testCases.push(['EditingSelectors','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/editing-selectors-browser.json'),'utf8')))]);
testCases.push(['HeadingSelectors','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Selectors"),require("CSS/Nesting"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/heading-browser.json'),'utf8')))]);
testCases.push(['XMLSerialization','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("JavaScript/XMLSerialization"),require("JavaScript/DOMMarkup"),require("JavaScript/DOMXML"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/xml-serialization-browser.json'),'utf8')))+',require("DOM/AttributeStore")']);
testCases.push(['XMLSerializationRendering','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("JavaScript/DOMMarkup")']);
testCases.push(['JavaScriptShadowCSSOM','require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events")']);
testCases.push(['NativePointerCapture','require("Input/PointerCapture"),require("DOM/Node"),require("Input/EventData")']);
testCases.push(['JavaScriptPointerTouch','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Input/PointerCapture"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-pointer-touch-browser.json'),'utf8')))]);
testCases.push(['NativeTextEdit','require("Input/NativeTextEdit")']);
testCases.push(['NativeSelectionCopy','require("Input/NativeSelectionCopy")']);
testCases.push(['JavaScriptPointerTouchRendering','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Input/Controller")']);
testCases.push(['JavaScriptCSSOMReviewPage', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),require("Rendering/CanvasSurface"),'+literal(previousCSSOMReview.html)+','+literal(previousCSSOMReview.css)+','+toLua(JSON.parse(retiredFile('javascript-tests','options.json')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-cssom-page-browser.json'),'utf8')))]);
testCases.push(['JavaScriptRangeContents', 'require("JavaScript/VM"),require("JavaScript/DOM"),require("JavaScript/DOMRanges"),require("JavaScript/RangeContents"),require("HTML/Parser"),require("DOM/Node"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-range-contents.json'),'utf8')))]);
testCases.push(['JavaScriptScriptLoader', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-script-loader.json'),'utf8')))]);
testCases.push(['DocumentStreams', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/document-streams-browser.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-script-loader.json'),'utf8')))+',require("HTML/Tokenizer")']);
  testCases.push(['DocumentStreamsRendering', 'require("HTML/Parser"),require("DOM/Node"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel")']);
  testCases.push(['StylesheetLoading', 'require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/stylesheet-loading-browser.json'),'utf8')))]);
  testCases.push(['StylesheetEmbedded', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/stylesheet-embedded-browser.json'),'utf8')))]);
  testCases.push(['BaseURLs','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/base-url-browser.json'),'utf8')))]);
  testCases.push(['NodeBaseURI','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/node-base-uri-browser.json'),'utf8')))]);
  testCases.push(['Srcdoc', 'require("HTML/Parser"),require("HTML/DocumentInfo"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/srcdoc-browser.json'),'utf8')))]);
testCases.push(['RichSelectAnchors','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("JavaScript/ComputedStyle"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/select-anchor-browser.json'),'utf8')))+',loadHTMLPage']);
testCases.push(['AnchorParent','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("JavaScript/ComputedStyle"),require("JavaScript/CSSDeclarations"),require("JavaScript/Runtime"),require("Input/Events"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/anchor-parent-browser.json'),'utf8')))]);
testCases.push(['PositionAreas','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("JavaScript/ComputedStyle"),require("JavaScript/CSSDeclarations"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/position-area-browser.json'),'utf8')))]);
testCases.push(['RichSelectUA','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/ComputedStyle"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/select-ua-browser.json'),'utf8')))]);
testCases.push(['RichSelectCSSOM','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/select-cssom-browser.json'),'utf8')))]);
testCases.push(['SelectShowPicker','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Input/Controller"),require("Rendering/HTMLScripts"),loadRenderTree,loadWordLayout,loadBlockLayout,loadIFrameRuntime,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/select-showpicker-browser.json'),'utf8')))]);
testCases.push(['HiddenUA','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/hidden-browser.json'),'utf8')))]);
testCases.push(['InputTypeState','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/input-type-browser.json'),'utf8')))]);
testCases.push(['InputTypeRendering','require("HTML/Parser"),require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/input-type-browser.json'),'utf8')))+',loadImageDimensions']);
testCases.push(['CSSPreludes','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Stylesheet"),require("CSS/InlineStyle"),require("DOM/Node"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/css-preludes-browser.json'),'utf8')))+',require("CSS/ImportRules")']);
testCases.push(['EventHandlerAttributes','require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/event-handler-attributes-browser.json'),'utf8')))]);
testCases.push(['GlobalAttributes','require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/global-attributes-browser.json'),'utf8')))]);
testCases.push(['DocumentCollections','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/document-collections-browser.json'),'utf8')))]);
testCases.push(['FormOwners','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("DOM/Node"),require("Controls/State"),require("Controls/FormModel"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/form-owners-browser.json'),'utf8')))]);
testCases.push(['AttributeNamespaces','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/attribute-namespaces-browser.json'),'utf8')))]);
testCases.push(['DocumentAccessors','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/document-accessors-browser.json'),'utf8')))+',require("HTML/DocumentInfo")']);
testCases.push(['PercentageGaps', 'require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/gap-browser.json'),'utf8')))]);
  testCases.push(['RichSelectStates', 'require("HTML/Parser"),require("DOM/Node"),require("CSS/Selectors"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/select-states-browser.json'),'utf8')))]);
  testCases.push(['RichSelectPicker', 'require("HTML/Parser"),require("DOM/Node"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/select-picker-browser.json'),'utf8')))]);
testCases.push(['JavaScriptResourceLoading','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("JavaScript/VM")']);
testCases.push(['JavaScriptAudio','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['MediaReflection','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/media-reflection-browser.json'),'utf8')))]);
testCases.push(['SourceReflection','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/source-reflection-browser.json'),'utf8')))]);
testCases.push(['VideoPresentationDOM','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/video-presentation-browser.json'),'utf8')))]);
testCases.push(['AudioSourceLifecycle','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/audio-source-lifecycle-browser.json'),'utf8')))]);
testCases.push(['AudioSourceCandidates','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/audio-source-candidates-browser.json'),'utf8')))]);
testCases.push(['AudioHost','require("Rendering/AudioHost"),require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),loadMediaRuntime,require("Rendering/MediaBox"),loadRenderTree,require("Rendering/HTMLScripts"),require("Controls/FormModel")']);
testCases.push(['AudioHostLifetime','require("Rendering/AudioHost"),false,true']);
testCases.push(['AudioSourceCandidatesRendering','require("HTML/Parser"),require("DOM/Node"),require("Input/Events"),require("Controls/FormModel"),loadMediaRuntime,require("Rendering/MediaBox"),loadRenderTree,require("Rendering/HTMLScripts"),loadWordLayout,loadBlockLayout,require("Layout/DirtyLayout"),require("Input/Controller"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/audio-source-candidates-browser.json'),'utf8')))]);
testCases.push(['MediaLiveRendering','require("HTML/Parser"),require("DOM/Node"),require("Input/Events"),require("Controls/FormModel"),loadMediaRuntime,require("Rendering/MediaBox"),loadRenderTree,require("Rendering/HTMLScripts"),loadWordLayout,loadBlockLayout,require("Layout/DirtyLayout"),require("Input/Controller"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/media-live-browser.json'),'utf8')))]);
testCases.push(['VideoPresentationRendering','loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/video-presentation-browser.json'),'utf8')))]);
testCases.push(['JavaScriptLoadingLifecycle','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['ResourceLoadHost','require("Rendering/ResourceLoadHost"),require("HTML/Parser"),require("DOM/Node")']);
testCases.push(['ResourceLoadHostLifetime','require("Rendering/ResourceLoadHost")']);
testCases.push(['PosterPresentation','loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox"),loadPosterSVG,require("WorkContext")']);
testCases.push(['MediaSelection','require("HTML/MediaSelection"),require("DOM/Node"),require("WorkContext")']);
testCases.push(['MediaSelectionAudioOpen','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['ResourceLoadHostLifetimeRendering','loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox")']);
testCases.push(['NativeAudioSelection','loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox"),{},require("Rendering/NativeMediaResources"),require("WorkContext")']);
testCases.push(['ImageResourceRendering','require("HTML/Parser"),require("DOM/Node"),loadRenderTree']);
testCases.push(['ImageErrorSizing','require("HTML/Parser"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/image-error-sizing.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/image-error-sizing-browser.json'),'utf8')))]);
testCases.push(['BrowserFoundationsWebsite','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),'+literal(currentFoundations.browserHTML)+','+literal(currentFoundations.browserCSS)+','+literal(retiredFile('browser-foundations','app.js'))+','+toLua(Object.fromEntries(['morning','evening'].map(name=>['assets/'+name+'.svg',retiredFile('browser-foundations','assets/'+name+'.svg')])))]);
testCases.push(['JavaScriptWorkerRealm','require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/WorkerRealm")']);
testCases.push(['JavaScriptWorkerHost','require("Rendering/WorkerHost")']);
testCases.push(['JavaScriptWorkerReferences','require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/WorkerRealm"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-worker-realms.json'),'utf8')))]);
testCases.push(['JavaScriptCanvasPaths','require("HTML/Parser"),require("JavaScript/Runtime"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-canvas-paths.json'),'utf8')))]);
testCases.push(['JavaScriptProfilesReviewPage','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/WorkerRealm"),'+literal(previousProfilesReview.html)+','+toLua(JSON.parse(retiredFile('javascript-tests','options.json')).JavaScriptServices)]);
const gamesHub = currentWebsiteSources('Main','main',true), memoryPage=currentWebsiteSources('Memory','memory',true);
for(const [module,folder,page]of [['Main','main',gamesHub],['Memory','memory',memoryPage]]){assert.equal(generatedLongString(page.htmlSource),page.browserHTML);assert.equal(generatedLongString(page.cssSource),page.browserCSS);assert.equal(generatedLongString(readWebsiteModule(module,'JavaScript.luau')),readWebsiteFile(folder,'app.js'));}
testCases.push(['MemoryGame','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("JavaScript/Storage"),'+literal(memoryPage.browserHTML)+','+literal(memoryPage.browserCSS)+','+literal(readWebsiteFile('memory', 'app.js'))+',loadRenderTree,loadWordLayout,loadBlockLayout,loadWebsiteCatalog,'+literal(gamesHub.browserHTML)+','+literal(gamesHub.browserCSS)+','+literal(readWebsiteFile('main', 'app.js'))+',require("Input/HitTest"),require("Rendering/HTMLAnimations"),'+toLua(Object.fromEntries(JSON.parse(readWebsiteFile('memory', 'options.json')).LocalSVG.map(source=>[source,readWebsiteFile('memory', source)])))]);
const hangmanPage = currentWebsiteSources('Hangman', 'hangman', true);
testCases.push(['MemoryRendering','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),require("Rendering/HTMLAnimations"),'+literal(memoryPage.browserHTML)+','+literal(memoryPage.browserCSS)+','+literal(readWebsiteFile('memory', 'app.js'))+','+toLua(Object.fromEntries(JSON.parse(readWebsiteFile('memory', 'options.json')).LocalSVG.map(source=>[source,readWebsiteFile('memory', source)])))]);
assert.equal(generatedLongString(hangmanPage.htmlSource), hangmanPage.browserHTML.replace(/\r\n/g, '\n'), 'Hangman HTML matches its browser source');
assert.equal(generatedLongString(hangmanPage.cssSource), hangmanPage.browserCSS.replace(/\r\n/g, '\n'), 'Hangman CSS matches its browser source');
assert.equal(generatedLongString(readWebsiteModule('Hangman', 'JavaScript.luau')), readWebsiteFile('hangman', 'app.js').replace(/\r\n/g, '\n'), 'Hangman JavaScript matches its browser source');
testCases.push(['HangmanGame','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("JavaScript/Storage"),'+literal(hangmanPage.browserHTML)+','+literal(hangmanPage.browserCSS)+','+literal(readWebsiteFile('hangman', 'app.js'))+',loadRenderTree,loadWordLayout,loadBlockLayout']);
testCases.push(['JavaScriptSpecializedDOM', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel")']);
testCases.push(['JavaScriptDOMControls', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),require("Input/Events"),require("Controls/State"),require("Controls/FormModel")']);
testCases.push(['JavaScriptMutationObserver', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),require("Input/Events"),require("JavaScript/MutationObserver")']);
testCases.push(['JavaScriptLayoutObservers', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),require("Input/Events"),require("JavaScript/Geometry"),require("JavaScript/LayoutObservers")']);
testCases.push(['JavaScriptObserverBudget', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['JavaScriptIteratorHelpers', 'require("JavaScript/VM"),require("JavaScript/IteratorHelpers"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-iterator-helpers.json'),'utf8')))]);
testCases.push(['JavaScriptJSONRaw', 'require("JavaScript/VM"),require("JavaScript/LibraryJSON"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-json-raw.json'),'utf8')))]);
testCases.push(['JavaScriptDOMQueries', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),'+literal(fs.readFileSync(path.join(root,'tests/fixtures/dom-queries-reference.js'),'utf8'))]);
testCases.push(['JavaScriptBinaryProperties', 'require("JavaScript/VM"),require("JavaScript/BinaryData"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-binary-properties.json'),'utf8')))]);
testCases.push(['JavaScriptDOMTraversal', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),require("JavaScript/DOMTraversal"),'+literal(fs.readFileSync(path.join(root,'tests/fixtures/dom-traversal-reference.js'),'utf8'))]);
testCases.push(['JavaScriptDOMRanges', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),require("JavaScript/DOMRanges"),require("JavaScript/RangeContents"),'+literal(fs.readFileSync(path.join(root,'tests/fixtures/dom-ranges-reference.js'),'utf8'))]);
testCases.push(['JavaScriptGeometryMath', 'require("JavaScript/VM"),require("JavaScript/Geometry"),require("JavaScript/HostEvents"),require("JavaScript/BinaryData"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-geometry-math.json'),'utf8')))+',require("JavaScript/StructuredClone")']);
testCases.push(['JavaScriptGeometryTransformParser', 'require("JavaScript/GeometryTransformParser"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-geometry-transform-parser.json'),'utf8')))]);
testCases.push(['JavaScriptHostIntegration', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("Rendering/ScriptGeometry")']);
testCases.push(['JavaScriptNativeDescriptors', 'require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("JavaScript/HostEvents"),require("JavaScript/Geometry")']);
testCases.push(['JavaScriptPromises', 'require("JavaScript/Runtime"), require("HTML/Parser"), require("DOM/Node"), require("JavaScript/VM"), '+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-promises.json'),'utf8')))]);
testCases.push(['ScriptTransforms', 'require("HTML/Parser"), require("DOM/Node"), require("JavaScript/Runtime"), require("CSS/InlineStyle"), require("Layout/DirtyLayout"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Rendering/HTMLAnimations")']);
testCases.push(['JavaScriptClock', 'require("JavaScript/Runtime"), require("HTML/Parser"), require("DOM/Node"), require("Input/Events"), require("Rendering/HTMLScripts"), loadRenderTree, loadWordLayout, loadBlockLayout, require("Layout/DirtyLayout"), require("Controls/FormModel"), '+literal(fs.readFileSync(path.join(root,'tests/fixtures/javascript-labor-classic.html'),'utf8'))+', '+literal(fs.readFileSync(path.join(root,'tests/fixtures/javascript-labor-classic.css'),'utf8'))+', require("CSS/InlineStyle"), require("Rendering/CanvasBackground")']);
testCases.push(['UnicodeNormalization','require("JavaScript/UnicodeNormalization"),require("JavaScript/Strings"),'+literal(fs.readFileSync(path.join(root,'tests/fixtures/unicode-normalization-17.txt'),'utf8'))]);
testCases.push(['JavaScriptTextData','require("JavaScript/VM"),require("JavaScript/Intl"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-text-data-native.json'),'utf8')).cases)]);
testCases.push(['URLRecords','require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),require("JavaScript/URLRecord"),require("DOM/DocumentOrigin"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/url-record-browser.json'),'utf8')))]);
testCases.push(['JavaScriptAdvancedLibrary','require("JavaScript/VM"),require("JavaScript/Intl"),require("JavaScript/ResourceStacks"),require("JavaScript/Promises"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-advanced-library.json'),'utf8')))]);
testCases.push(['JavaScriptResourceScopes','require("JavaScript/VM"),require("JavaScript/ResourceStacks"),require("JavaScript/Promises"),require("JavaScript/AsyncFunctions"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-resource-scopes.json'),'utf8')))]);
testCases.push(['JavaScriptGenerators','require("JavaScript/VM"),require("JavaScript/Generators"),require("JavaScript/Promises"),require("JavaScript/AsyncFunctions"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-generators.json'),'utf8')))]);
testCases.push(['JavaScriptAsyncExpansion','require("JavaScript/VM"),require("JavaScript/Promises"),require("JavaScript/AsyncFunctions"),require("JavaScript/EventLoop"),require("JavaScript/HostEvents"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-async-expansion.json'),'utf8')))]);
testCases.push(['CSSAtelierCore','require("CSS/Syntax"),require("CSS/Selectors"),require("HTML/Parser"),require("DOM/Node"),require("CSS/MediaQueries"),require("CSS/ContainerQueries"),require("CSS/LengthExpression"),require("CSS/InlineStyle"),require("CSS/Stylesheet")']);
testCases.push(['MediaQueryReference','require("CSS/MediaQueries"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/media-query-browser.json'),'utf8')))+',require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Stylesheet"),require("CSS/InlineStyle"),loadRenderTree']);
testCases.push(['ContainerQueryReference','require("CSS/ContainerQueries"),require("CSS/MediaQueries"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/container-query-browser.json'),'utf8')))+',require("HTML/Parser"),require("DOM/Node"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Layout/DirtyLayout")']);
testCases.push(['ContainerStyleReference','require("CSS/ContainerQueries"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/container-style-browser.json'),'utf8')))+',require("HTML/Parser"),require("DOM/Node"),require("CSS/Stylesheet"),require("CSS/InlineStyle"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Layout/DirtyLayout")']);
testCases.push(['ContainerScrollReference','require("CSS/ContainerQueries"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/container-scroll-browser.json'),'utf8')))+',require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Layout/DirtyLayout"),require("Rendering/ViewportLayer"),require("Layout/ScrollLayout")']);
testCases.push(['AnchorReference',toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/anchor-browser.json'),'utf8')))+',require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Layout/DirtyLayout")']);
testCases.push(['JavaScriptAnchorCSSOM','require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),'+literal(fs.readFileSync(path.join(root,'tests/fixtures/anchor-cssom-reference.js'),'utf8'))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/anchor-cssom-browser.json'),'utf8')))]);
testCases.push(['JavaScriptTypedOM','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['JavaScriptTypedTransforms','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/typed-transform-browser.json'),'utf8').replace(/^\uFEFF/,'')))]);
testCases.push(['JavaScriptSelectedContent','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/selected-content-browser.json'),'utf8').replace(/^\uFEFF/,'')))]);
testCases.push(['RichSelectRendering','require("HTML/Parser"),require("DOM/Node"),require("Input/Events"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),require("Input/Controller"),loadFontPreload,loadImageDimensions,loadImageLoad']);
testCases.push(['Hyphenation','require("HTML/Parser"),require("CSS/InlineStyle"),require("Layout/Hyphenation"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/hyphenation-browser.json'),'utf8')))]);
testCases.push(['CSSScrollViews','require("HTML/Parser"),require("DOM/Node"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLAnimations"),require("CSS/ScrollTimeline")']);
const atelierFolder=path.join(root,'tests/fixtures/css-atelier');
testCases.push(['CSSAtelierWebsite','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),'+literal(fs.readFileSync(path.join(atelierFolder,'index.html'),'utf8'))+','+literal(fs.readFileSync(path.join(atelierFolder,'styles.css'),'utf8'))+','+literal(fs.readFileSync(path.join(atelierFolder,'app.js'),'utf8'))+','+toLua(Object.fromEntries(['morning.svg','evening.svg','density-1.svg','density-2.svg'].map(name=>[name,fs.readFileSync(path.join(atelierFolder,name),'utf8')])))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/container-font-measurement-browser.json'),'utf8')))]);
const bytebudePage=currentWebsiteSources('Bytebude','bytebude',true);
assert.equal(generatedLongString(bytebudePage.htmlSource),bytebudePage.browserHTML);
assert.equal(generatedLongString(bytebudePage.cssSource),bytebudePage.browserCSS);
const bytebudeApp=readWebsiteFile('bytebude', 'app.js');
assert.equal(generatedLongString(readWebsiteModule('Bytebude', 'JavaScript.luau')),bytebudeApp);
testCases.push(['BytebudeWebsite','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("JavaScript/Storage"),loadRenderTree,loadWordLayout,loadBlockLayout,'+literal(bytebudePage.browserHTML)+','+literal(bytebudePage.browserCSS)+','+literal(bytebudeApp)]);
const comparisonPages = comparisonRoutes.map(([folder,module]) => {
  const page = retiredPageSources(module,folder);
  assert.equal(generatedLongString(page.htmlSource),page.browserHTML,folder+' HTML parity');
  assert.equal(generatedLongString(page.cssSource),page.browserCSS,folder+' CSS parity');
  const app = retiredWindowPages[folder].files['app.js'] || '';
  if (app) assert.equal(generatedLongString(retiredWindowPages[folder].modules['JavaScript.luau']),app,folder+' script parity');
  const svgs = folder==='comparison-effects' ? {'landscape.svg':retiredPageFile(folder,'landscape.svg')} : {};
  return {folder,module,html:page.browserHTML,css:page.browserCSS,app,svgs};
});
testCases.push(['ComparisonWebsite','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),require("Controls/FormModel"),require("Input/Controller"),'+toLua(comparisonPages)]);
testCases.push(['LayoutProbeRendering','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),require("Rendering/LayoutJob"),require("Layout/LayoutProbe"),loadRenderTree,loadWordLayout,loadBlockLayout,'+literal(bytebudePage.browserHTML)+','+literal(bytebudePage.browserCSS)]);
testCases.push(['LayoutAtomicMeasurements','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/ComputedStyle"),require("Layout/DirtyLayout"),require("Rendering/LayoutJob"),require("Input/Controller"),require("Rendering/HTMLScripts"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/layout-atomic-browser.json'),'utf8')))]);
testCases.push(['FlexAutoCross','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),require("Input/Controller"),require("Rendering/HTMLScripts"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/flex-auto-cross-browser.json'),'utf8')))]);
testCases.push(['PositionAlignment','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("Layout/DirtyLayout"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Layout/BoxAlignment"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/position-alignment-browser.json'),'utf8')))]);
testCases.push(['ContentVisibilityRendering','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Input/HitTest"),require("Rendering/BoxTransform"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/content-visibility-browser.json'),'utf8')))]);
testCases.push(['ContentVisibilityTopLayerRendering','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/Dialog"),require("Rendering/Popover"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/content-visibility-top-layer-browser.json'),'utf8')))]);
testCases.push(['ImageMapsDOM','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/image-maps-dom-browser.json'),'utf8')))]);
testCases.push(['ImageMapsRendering','require("HTML/Parser"),require("DOM/Node"),require("Layout/DirtyLayout"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Input/ImageMap"),require("Input/Links"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/image-maps-browser.json'),'utf8')))]);
testCases.push(['ControlBorders','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("Controls/View"),loadRenderTree,loadWordLayout,loadBlockLayout,'+literal(bytebudePage.browserHTML)+','+literal(bytebudePage.browserCSS)]);
testCases.push(['PictureTypeResources','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/picture-source-type-hints-browser.json'),'utf8')).cases)+',require("DOM/Node"),loadRenderTree']);
testCases.push(['VideoSourceInitialSelection','loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox"),require("WorkContext")']);
testCases.push(['VideoSourceSelection','loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox"),require("WorkContext")']);
testCases.push(['VideoSourceRetry','loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox"),require("WorkContext")']);
testCases.push(['VideoLazyLoading','loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/video-lazy-browser.json'),'utf8')))]);
testCases.push(['LazyMedia','require("HTML/Parser"),require("DOM/Node"),require("Rendering/LazyMedia")']);
testCases.push(["AudioCrossRealmCandidate","require(\"HTML/Parser\"),require(\"JavaScript/Runtime\"),require(\"Input/Events\"),require(\"Rendering/AudioHost\")","AudioCrossRealmCandidate"]);
testCases.push(["AudioOwnerCallbackReentry","require(\"HTML/Parser\"),require(\"JavaScript/Runtime\"),require(\"Input/Events\"),require(\"Rendering/AudioHost\"),\"owner-callback\"","AudioCrossRealmCandidate"]);
testCases.push(["AudioPaintReentry","require(\"HTML/Parser\"),require(\"JavaScript/Runtime\"),require(\"Input/Events\"),require(\"Rendering/AudioHost\"),\"paint-reentry\"","AudioCrossRealmCandidate"]);
testCases.push(["AudioLookupFault","require(\"HTML/Parser\"),require(\"JavaScript/Runtime\"),require(\"Input/Events\"),require(\"Rendering/AudioHost\"),\"lookup-fault\"","AudioCrossRealmCandidate"]);
testCases.push(["AudioNativeHooks","require(\"HTML/Parser\"),require(\"JavaScript/Runtime\"),require(\"Input/Events\"),require(\"Rendering/AudioHost\"),\"native-hooks\"","AudioCrossRealmCandidate"]);
testCases.push(["AudioOriginFactory","require(\"HTML/Parser\"),require(\"JavaScript/Runtime\"),require(\"Input/Events\"),require(\"Rendering/AudioHost\"),\"origin-factory\"","AudioCrossRealmCandidate"]);
testCases.push(["AudioCapabilityReentry","require(\"HTML/Parser\"),require(\"JavaScript/Runtime\"),require(\"Input/Events\"),require(\"Rendering/AudioHost\"),\"capability-reentry\"","AudioCrossRealmCandidate"]);
testCases.push(["AudioSettlementScheduler","require(\"HTML/Parser\"),require(\"JavaScript/Runtime\"),require(\"Input/Events\"),require(\"Rendering/AudioHost\"),\"settlement-scheduler\"","AudioCrossRealmCandidate"]);
testCases.push(["VideoDocumentLoadRendering","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\"),require(\"HTML/MediaSelection\")"]);
testCases.push(["MediaFallbackMounted","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\")"]);
testCases.push(["MediaFallbackCounterpartProbe","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\")"]);
testCases.push(["MediaFallbackShadowMounted","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\")"]);
testCases.push(["MediaFallbackSemanticsMounted","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\")"]);
testCases.push(["MediaFallbackLocalityMounted","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\")"]);
testCases.push(["VideoPrerenderDocumentLoad","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\"),require(\"HTML/MediaSelection\")"]);
testCases.push(["VideoPrerenderBoundaries","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\"),require(\"HTML/MediaSelection\"),loadHTMLScriptsCaptured"]);
testCases.push(["VideoPrerenderOwnerReceivers","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\"),require(\"HTML/MediaSelection\"),loadHTMLScriptsCaptured"]);
testCases.push(["NoRealmDocumentLoadOriginal","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\"),require(\"HTML/MediaSelection\"),loadIFrameRuntime"]);
testCases.push(["NoRealmDocumentLoad","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\"),require(\"HTML/MediaSelection\"),loadIFrameRuntime,require(\"Rendering/NativeMediaResources\")"]);
testCases.push(["VideoJavaScriptBindings","require(\"HTML/Parser\"),require(\"JavaScript/Runtime\"),require(\"Input/Events\"),require(\"HTML/VideoState\")"]);
testCases.push(["VideoJavaScriptMounted","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\")"]);
testCases.push(["VideoFacadeLifetime","require(\"DOM/Node\"),require(\"JavaScript/VideoElements\"),require(\"HTML/VideoState\")"]);
testCases.push(["VideoFacadeDestroyFaults","require(\"DOM/Node\"),require(\"JavaScript/VideoElements\"),require(\"HTML/VideoState\")"]);
testCases.push(["VideoRemoveSchedulerReview","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\")"]);
testCases.push(["VideoRemoveReentryReview","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\")"]);
testCases.push(["VideoStateNotificationReview","require(\"DOM/Node\"),require(\"JavaScript/VideoElements\"),require(\"HTML/VideoState\")"]);
testCases.push(["NativeImageDocumentLoadRendering","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),require(\"WorkContext\"),require(\"HTML/MediaSelection\"),loadIFrameRuntime,require(\"Rendering/NativeMediaResources\"),loadImageLoad,loadImageDimensions,require(\"Rendering/NativeImageResources\")"]);
testCases.push(["NativeImageOwnerGuards","require(\"Rendering/NativeImageResources\"),require(\"DOM/Node\")"]);
testCases.push(['IFrameAttributeNavigation','loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/iframe-attribute-navigation-browser.json'),'utf8')))+',require("HTML/MediaSelection"),loadIFrameRuntime,require("Rendering/NativeMediaResources"),require("JavaScript/URLRecord")']);
testCases.push(["IFrameLifecycle","loadIFrameRuntime,require(\"DOM/Node\")"]);
testCases.push(["IFrameLifecycleNested","loadIFrameRuntime,require(\"DOM/Node\")"]);
testCases.push(["IFrameLifecycleMounted","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),{},require(\"HTML/MediaSelection\"),loadIFrameRuntime,require(\"Rendering/NativeMediaResources\"),require(\"JavaScript/URLRecord\")"]);
testCases.push(['HistoricalSources','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("DOM/Node"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/audio-source-candidates-browser.json'),'utf8')))+',true']);
testCases.push(['NativeHistoricalSources','loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox"),{},require("Rendering/NativeMediaResources"),require("WorkContext"),require("DOM/TemplateDocument")']);
testCases.push(['SourceDocumentLifetime','require("DOM/MediaSourceDocument")']);
testCases.push(["IFrameSingleChildCleanup","loadIFrameRuntime,require(\"DOM/Node\")"]);
testCases.push(["IFrameSingleChildMounted","loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require(\"DOM/Node\"),require(\"Input/Controller\"),require(\"Rendering/HTMLScripts\"),require(\"Rendering/MediaBox\"),{},require(\"HTML/MediaSelection\"),loadIFrameRuntime,require(\"Rendering/NativeMediaResources\"),require(\"JavaScript/URLRecord\")"]);
testCases.push(["MeasurementOwnerBoundaries","require(\"Layout/LayoutMeasurement\"),require(\"DOM/Node\")"]);
testCases.push(['OverflowAlignment','require("HTML/Parser"),require("DOM/Node"),require("CSS/InlineStyle"),require("Layout/DirtyLayout"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Layout/BoxAlignment"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/overflow-alignment-browser.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/overflow-alignment-frozen.json'),'utf8')))]);
testCases.push(['DefaultNamespaces','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Selectors"),require("CSS/Stylesheet"),require("Layout/DirtyLayout"),require("Input/Controller"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/default-namespace-browser.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/default-namespace-frozen.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/default-namespace-context-browser.json'),'utf8')))]);
testCases.push(["VideoSeekPresentation","require(\"Input/VideoServices\"),require(\"HTML/VideoState\"),require(\"Rendering/MediaBox\"),require(\"DOM/Node\")"]);
testCases.push(["VideoSeekPresentationMounted",'loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("DOM/Node"),require("Input/Controller"),require("Rendering/HTMLScripts"),require("Rendering/MediaBox"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/video-presentation-browser.json'),'utf8')))+','+"require(\"HTML/VideoState\")"]);
testCases.push(['ScopeNamespaces','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Stylesheet"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/scope-namespace-browser.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/scope-namespace-controls-browser.json'),'utf8')))]);
testCases.push(['ScopeRetained','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Selectors"),require("CSS/Stylesheet"),require("Layout/DirtyLayout"),require("Input/Controller"),loadRenderTree,loadWordLayout,loadBlockLayout,require("Rendering/HTMLScripts"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/scope-retained-browser.json'),'utf8')))]);
testCases.push(['ScopeNestedContexts','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Stylesheet"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/scope-nested-browser.json'),'utf8')))+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/scope-cssom-context-browser.json'),'utf8')))]);
testCases.push(['ScopeTopReferences','require("HTML/Parser"),require("DOM/Node"),require("JavaScript/Runtime"),require("Input/Events"),require("CSS/Stylesheet"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/scope-top-references-browser.json'),'utf8')))]);
testCases.push(['BrowserShell','loadBrowser,browserFixture']);
testCases.push(['BrowserStartPage','loadBrowser,browserFixture']);
testCases.push(['BrowserSingleView','loadBrowser,browserFixture']);
testCases.push(['BrowserSessionMigration','loadBrowser,browserFixture,loadBrowserStore']);
testCases.push(['BrowserSingleSession','loadBrowser,browserFixture']);
testCases.push(['WindowManager','loadWindowManager,browserFixture,loadBrowserWindowHost,loadBrowser,loadBrowserBinding,loadWindowDemo']);
testCases.push(['WindowCloseGuard','loadWindowManager,browserFixture']);
testCases.push(['FallbackWindows','loadFallbackWindows,browserFixture']);
testCases.push(['StandaloneHTMLWindows','loadStandaloneHost,browserFixture,loadEngine,require("WorkContext"),require("HTML/Parser"),require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad,loadIFrameRuntime']);
testCases.push(['StandaloneHostLifetime','loadStandaloneHost,browserFixture']);
testCases.push(['WindowOpenCooperative','loadStandaloneHost,browserFixture,loadEngine,require("WorkContext"),require("HTML/Parser"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad']);
testCases.push(['BrowsingWindows','require("JavaScript/BrowsingWindows"),require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['JavaScriptSimpleDialogs','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("DOM/Node")']);
testCases.push(['JavaScriptIdleCallbacks','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),'+literal(retiredPageFile('comparison-script','index.html'))+','+literal(retiredPageFile('comparison-script','app.js'))]);
testCases.push(['JavaScriptScheduler','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events"),require("JavaScript/WorkerRealm"),'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-scheduler-native.json'),'utf8')))]);
testCases.push(['WordBreak','require("HTML/Parser"),require("CSS/InlineStyle"),loadRenderTree,loadWordLayout,loadBlockLayout,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/word-break-browser.json'),'utf8')))]);
testCases.push(['AutoImageSources','require("HTML/Parser"),require("DOM/Node"),require("HTML/ResponsiveSources"),loadRenderTree,loadWordLayout,loadBlockLayout']);
testCases.push(['AutoImageRendering',testCases.find(([name])=>name==='NativeImageDocumentLoadRendering')[1]]);
testCases.push(['InlineTextMutation','require("HTML/Parser"),require("CSS/InlineStyle"),loadRenderTree,loadWordLayout,loadBlockLayout']);
testCases.push(['JavaScriptXMLHttpRequest','require("JavaScript/VM"),require("JavaScript/Promises"),require("JavaScript/AsyncFunctions"),require("JavaScript/EventLoop"),require("JavaScript/HostEvents"),require("JavaScript/NetworkData"),require("HTML/Parser"),require("JavaScript/DOM"),require("JavaScript/CustomElements")']);
testCases.push(['JavaScriptXHRRuntime','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['JavaScriptWebLocks','require("JavaScript/VM"),require("JavaScript/Promises"),require("JavaScript/AsyncFunctions"),require("JavaScript/EventLoop"),require("JavaScript/HostEvents"),require("JavaScript/WebLocks")']);
testCases.push(['JavaScriptLocksRuntime','require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/WorkerRealm"),require("Input/Events"),require("JavaScript/WebLocks")']);
testCases.push(['DocumentLifecycle','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['BrowserWindowAPIs','loadWindowManager,loadBrowserWindowHost,loadBrowser,loadBrowserBinding,browserFixture,require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad']);
testCases.push(['BrowserLifecycleDialogs','loadWindowManager,loadBrowserWindowHost,loadBrowser,loadBrowserBinding,browserFixture,require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad,loadIFrameRuntime'+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/window-close-browser.json'),'utf8')))]);
const windowDemoSources='{'+[['Demo','WindowDemo','window-demo'],['Popup','WindowPopup','window-popup']].map(([key,module,folder])=>{
 const page=retiredPageSources(module,folder),app=retiredWindowPages[folder].modules['JavaScript.luau'];
 assert.equal(generatedLongString(page.htmlSource),page.browserHTML.replace(/\r\n/g,'\n'),folder+' HTML parity');
 assert.equal(generatedLongString(page.cssSource),page.browserCSS.replace(/\r\n/g,'\n'),folder+' CSS parity');
 assert.equal(generatedLongString(app),retiredPageFile(folder,'app.js').replace(/\r\n/g,'\n'),folder+' JavaScript parity');
 return key+'={Metadata=(function()\n'+page.init+'\nend)(),HTML=(function()\n'+page.htmlSource+'\nend)(),CSS=(function()\n'+page.cssSource+'\nend)(),JavaScript=(function()\n'+app+'\nend)()}';
}).join(',')+'}';
testCases.push(['BrowserWindowsMounted','loadWindowManager,loadBrowserWindowHost,loadBrowser,loadBrowserBinding,browserFixture,require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad,'+windowDemoSources+',loadWebsiteCatalog']);
testCases.push(['BrowserHTMLBinding','loadBrowser,loadBrowserBinding,browserFixture,require("Navigation/URL")']);
testCases.push(['BrowserHTMLMounted','loadBrowser,loadBrowserBinding,browserFixture,require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad']);
testCases.push(['SelectionCopyMounted','loadBrowser,loadBrowserBinding,browserFixture,require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad,loadIFrameRuntime']);
const wikiHoverWebsite = (()=>{
  const fixture=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/retired-wiki-hover-20261019.json'),'utf8'));
  const read=name=>{const item=fixture.sources[name];assert.equal(fixtureHash(item.source),item.sha256,'Retired Wiki hover input '+name);return item.source;};
  return `(function()\nlocal script={HTML="HTML",CSS="CSS",Parent={Assets={ImageCatalog="ImageCatalog"}}}\nlocal function require(token)\nif token=="ImageCatalog"then return{forPage=function()return{}end}\nelseif token=="HTML"then return(function()\n${read('HTML')}\nend)()\nelseif token=="CSS"then return(function()\n${read('CSS')}\nend)()\nelse error("Unexpected Wiki source dependency "..tostring(token))end\nend\n${read('init')}\nend)()`;
})();
testCases.push(['WikiHoverNavigation','loadBrowser,loadBrowserBinding,browserFixture,require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad,'+wikiHoverWebsite+',{Style=require("CSS/InlineStyle"),Selectors=require("CSS/Selectors"),Generated=require("Rendering/GeneratedContent"),BorderBox=require("Rendering/BorderBox"),BoxTransform=require("Rendering/BoxTransform")}']);
const fullWikiWebsites=require('./wttg2-test-sources.cjs').websiteTable(activeCatalog,['DeepWiki','DeepWiki2','DeepWiki3']);
testCases.push(['FullGameWikiNavigation','loadBrowser,loadBrowserBinding,browserFixture,require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad,'+fullWikiWebsites+',require("Storage/Memory")']);
const nightwebTestSources=require('./nightweb-test-sources.cjs'),retiredAuthored=nightwebTestSources.retiredAuthored();
const nightwebWebsites=nightwebTestSources.websiteTable(retiredAuthored.catalog,retiredAuthored.modules);
testCases.push(['NightwebRuntime','loadBrowser,loadBrowserBinding,browserFixture,require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad,'+nightwebWebsites]);
testCases.push(['NightwebNavigation','loadBrowser,loadBrowserBinding,browserFixture,require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad,'+nightwebWebsites]);
const nightwebIllustrations='{'+Object.entries(retiredAuthored.browserFiles).filter(([file])=>file.endsWith('.svg')).map(([file,source])=>'{Name='+JSON.stringify(file)+',SVG='+literal(source)+'}').join(',')+'}';
testCases.push(['NightwebIllustrations','{'+nightwebSVGKeys.map(key=>key+'=require("SVG/'+key+'")').join(',')+'},'+nightwebIllustrations]);
testCases.push(['HTMLPageStartup','loadHTMLDemoStart,browserFixture,'+toLua(JSON.parse(fs.readFileSync(path.join(root,'default.project.json'),'utf8')).tree.StarterPlayer.StarterPlayerScripts.HTMLPageDemo.$attributes)+','+toLua(JSON.parse(fs.readFileSync(path.join(root,'htmlpage.project.json'),'utf8')).tree.StarterPlayer.StarterPlayerScripts.HTMLPageDemo.$attributes)]);
testCases.push(['BrowserPersistenceStartup','loadBrowserPersistenceStart,browserFixture,loadHTMLStorageStart']);
testCases.push(['MediaDevicePermissions','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['MediaStreamCapture','require("HTML/Parser"),require("JavaScript/Runtime"),require("Input/Events")']);
testCases.push(['MediaStreamVideo','require("HTML/Parser"),loadMediaRuntime,require("Rendering/MediaBox"),require("HTML/VideoState"),require("Input/StreamVideo")']);
testCases.push(['AnnoyingSitePage','loadStandaloneHost,browserFixture,loadEngine,require("WorkContext"),require("HTML/Parser"),require("Navigation/URL"),loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,require("Input/Controller"),require("Rendering/HTMLScripts"),require("DOM/Node"),loadImageDimensions,loadImageLoad,loadIFrameRuntime,'+toLua(annoyingSiteTestSource)+',loadWindowManager,loadBrowserWindowHost,loadBrowser,loadBrowserBinding']);
testCases.push(['VirtualCameraHost','loadVirtualCameraHost']);
testCases.push(['PermissionHost','require("Rendering/PermissionHost")']);
testCases.push(['PermissionDialogUI','loadBrowser,loadFallbackWindows,browserFixture']);
for (const name of requested) assert.ok(testCases.some(([file]) => file === name), `Unknown test: ${name}`);
// This fixture deliberately waits for weak owners to be collected. Run it in
// its own Luau process so unrelated raster/layout allocations cannot determine
// whether its bounded allocation budget reaches the collector's next cycle.
const isolateLifetimes = requested.size !== 1 && (!requested.size || requested.has('RenderingLifetimes'));
// Incremental Luau collection depends on the preceding heap's size. Run GC
// capacity/lifetime assertions in fresh processes, retaining every assertion.
const isolatedGCChecks = ['JavaScriptCSSOM', 'JavaScriptRealmLifetime', 'EventHandlerAttributes', 'AttributeNamespaces', 'DocumentAccessors', 'DocumentCollections', 'TemplateDocuments', 'XMLSerializationRendering', 'URLRecords', 'SVGStyleOwners', 'ImageMapsDOM', 'ImageMapsRendering', 'ResourceLoadHostLifetimeRendering'].filter(name =>
  requested.size !== 1 && (!requested.size || requested.has(name)));
for (const [file, args, testSource = file] of testCases) {
  if (requested.size && !requested.has(file)) continue;
  if (isolateLifetimes && file === 'RenderingLifetimes') continue;
  if (isolatedGCChecks.includes(file)) continue;
  // These GC probes need their small independent bundles. Unrelated layout test
  // heaps change Luau's collector threshold, including the plain-object probe.
  if (file === 'JavaScriptDOMTraversal' || file === 'JavaScriptDOMQueries' || file === 'JavaScriptDOMRanges' || file === 'ResourceLoadHostLifetime' || file === 'MediaSelection' || file === 'SourceDocumentLifetime' || file === 'VideoFacadeLifetime' || file === 'VideoFacadeDestroyFaults' || file === 'VideoStateNotificationReview') continue;
  bundle += 'do\nlocal run = (function()\n' + fs.readFileSync(path.join(root, 'tests', testSource + '.luau'), 'utf8') + '\nend)()\nlocal result=run(' + args + ')\n' + (file === 'ThreeDTransforms' && process.env.HTML_3D_PREVIEW ? 'print("THREED_PREVIEW "..result.Width.." "..result.Height)\nlocal hex={}\nfor i=0,buffer.len(result.Pixels)-1 do hex[i+1]=string.format("%02x",buffer.readu8(result.Pixels,i)) end\nprint(table.concat(hex))\n' : '') + 'end\n';
}
fs.mkdirSync(path.join(root, 'build'), {recursive:true});
const target = path.join(root, `build/html-tests-${process.pid}.luau`);
fs.writeFileSync(target, bundle);
const executable = process.env.LUAU_BIN || path.join(root, 'build/tools/luau/luau.exe');
if (!fs.existsSync(executable)) throw new Error('Set LUAU_BIN to the official Luau CLI executable.');
const result = cp.spawnSync(executable, [target], process.env.HTML_3D_PREVIEW ? {encoding:'utf8', maxBuffer:8*1024*1024} : {stdio:'inherit'});
if (process.env.HTML_3D_PREVIEW) {
 const preview=result.stdout?.match(/THREED_PREVIEW (\d+) (\d+)\r?\n([a-f0-9]+)\r?\n/);
 process.stdout.write((result.stdout || '').replace(/THREED_PREVIEW [\s\S]*/,''));
 if (result.stderr) process.stderr.write(result.stderr);
 if (preview) {
  const rgba=path.join(root,'build','three-d-preview.rgba');
  const png=path.join(root,'build','three-d-preview.png');
  fs.writeFileSync(rgba,Buffer.from(preview[3],'hex'));
  cp.execFileSync('python',['-c', 'from PIL import Image; import sys; Image.frombytes("RGBA",(int(sys.argv[1]),int(sys.argv[2])),open(sys.argv[3],"rb").read()).save(sys.argv[4])',preview[1],preview[2],rgba,png]);
  console.log('3D preview:',png);
 }
}
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
if (!process.exitCode && (!requested.size || requested.has('JavaScriptDOMTraversal'))) {
  const traversalResult = cp.spawnSync(process.execPath, [path.join(root,'scripts/run-dom-traversal-tests.cjs')], {stdio:'inherit'});
  if (traversalResult.error) throw traversalResult.error;
  process.exitCode = traversalResult.status ?? 1;
}
if (!process.exitCode && (!requested.size || requested.has('JavaScriptDOMQueries'))) {
  const queryResult = cp.spawnSync(process.execPath, [path.join(root,'scripts/run-dom-queries-tests.cjs')], {stdio:'inherit'});
  if (queryResult.error) throw queryResult.error;
  process.exitCode = queryResult.status ?? 1;
}
if (!process.exitCode && (!requested.size || requested.has('JavaScriptDOMRanges'))) {
  const rangeResult = cp.spawnSync(process.execPath, [path.join(root,'scripts/run-dom-ranges-tests.cjs')], {stdio:'inherit'});
  if (rangeResult.error) throw rangeResult.error;
  process.exitCode = rangeResult.status ?? 1;
}
if (!process.exitCode && (!requested.size || requested.has('ResourceLoadHostLifetime'))) {
  const resourceLifetimeResult = cp.spawnSync(process.execPath, [path.join(root,'scripts/run-resource-load-host-lifetime-tests.cjs')], {stdio:'inherit'});
  if (resourceLifetimeResult.error) throw resourceLifetimeResult.error;
  process.exitCode = resourceLifetimeResult.status ?? 1;
}
if (!process.exitCode && (!requested.size || requested.has('AudioHostLifetime'))) {
  const audioLifetimeResult = cp.spawnSync(process.execPath, [path.join(root,'scripts/run-audio-host-lifetime-tests.cjs')], {stdio:'inherit'});
  if (audioLifetimeResult.error) throw audioLifetimeResult.error;
  process.exitCode = audioLifetimeResult.status ?? 1;
}
if (!process.exitCode && (!requested.size || requested.has('SourceDocumentLifetime'))) {
  const sourceLifetimeResult = cp.spawnSync(process.execPath, [path.join(root,'scripts/run-source-document-lifetime-tests.cjs')], {stdio:'inherit'});
  if (sourceLifetimeResult.error) throw sourceLifetimeResult.error;
  process.exitCode = sourceLifetimeResult.status ?? 1;
}
if (!process.exitCode && (!requested.size || requested.has('MediaSelection'))) {
  const selectionResult = cp.spawnSync(process.execPath, [path.join(root,'scripts/run-media-selection-tests.cjs')], {stdio:'inherit'});
  if (selectionResult.error) throw selectionResult.error;
  process.exitCode = selectionResult.status ?? 1;
}
const videoCompactChecks = ['VideoFacadeLifetime','VideoFacadeDestroyFaults','VideoStateNotificationReview'].filter(name => !requested.size || requested.has(name));
if (!process.exitCode && videoCompactChecks.length) {
  const videoCompactResult = cp.spawnSync(process.execPath, [path.join(root,'scripts/run-video-facade-tests.cjs'), ...videoCompactChecks], {stdio:'inherit', windowsHide:true});
  if (videoCompactResult.error) throw videoCompactResult.error;
  process.exitCode = videoCompactResult.status ?? 1;
}
if (!process.exitCode && isolateLifetimes) {
  const lifetimeResult = cp.spawnSync(process.execPath, [__filename, 'RenderingLifetimes'], {stdio:'inherit'});
  if (lifetimeResult.error) throw lifetimeResult.error;
  process.exitCode = lifetimeResult.status ?? 1;
}
if (!process.exitCode && (!requested.size || requested.has('Bidi'))) {
  const bidiResult=cp.spawnSync(process.execPath,[path.join(root,'scripts/test-bidi.cjs')],{stdio:'inherit'});
  if(bidiResult.error) throw bidiResult.error;
  process.exitCode=bidiResult.status ?? 1;
}
for (const name of isolatedGCChecks) {
  if (process.exitCode) break;
  const gcResult = cp.spawnSync(process.execPath, [__filename, name], {stdio:'inherit'});
  if (gcResult.error) throw gcResult.error;
  process.exitCode = gcResult.status ?? 1;
}
if (!process.exitCode) {
  const completed = testCases.filter(([name]) => !requested.size || requested.has(name)).length;
  console.log(`HTML tests: ${completed} registered suites passed, including required isolated checks.`);
}
