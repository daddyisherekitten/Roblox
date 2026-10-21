// Static project audit: compile first-party code and validate local references.
// This does not launch Roblox or a browser, or validate font rendering.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const browserRoot = path.join(root, 'examples/websites');
const publishedGame = JSON.parse(fs.readFileSync(path.join(root, 'scripts/data/wttg2-full-catalog.json'), 'utf8'));
const reviewedGameReferences = new Map();
for (const reference of [...publishedGame.MissingReferences, ...publishedGame.ExcludedReferences]) {
  const source = publishedGame.files.find(file => file.path === reference.sourcePath);
  assert.ok(source, `Unregistered original-game reference source: ${reference.sourcePath}`);
  const sourceFile = path.resolve(root, source.target);
  assert.ok(sourceFile.startsWith(browserRoot + path.sep));
  const target = path.resolve(browserRoot, reference.resolvedPath.replace(/^\//, ''));
  assert.ok(target.startsWith(browserRoot + path.sep));
  reviewedGameReferences.set(sourceFile + '\0' + target, source.sha256);
}
const retiredWebsites = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/retired-websites.json'), 'utf8')).sites;
const {retiredNightwebPages} = require('./website-test-sources.cjs');
cp.execFileSync(process.execPath,[path.join(root,'scripts/export-loading-modules.cjs'),'--check'],{stdio:'inherit'});
cp.execFileSync(process.env.PYTHON_BIN || 'python', [path.join(root, 'scripts/check-documentation.py')], {stdio:'inherit'});
cp.execFileSync(process.env.PYTHON_BIN || 'python', [path.join(root, 'scripts/check-html-attributes.py')], {stdio:'inherit'});
cp.execFileSync(process.env.PYTHON_BIN || 'python', [path.join(root, 'scripts/test-html-attributes.py')], {stdio:'inherit'});
cp.execFileSync(process.env.PYTHON_BIN || 'python', [path.join(root, 'scripts/check-css-coverage.py')], {stdio:'inherit'});
cp.execFileSync(process.env.PYTHON_BIN || 'python', [path.join(root, 'scripts/test-css-coverage.py')], {stdio:'inherit'});
function files(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
    const name = path.join(directory, entry.name);
    return entry.isDirectory() ? (entry.name === 'fonts' ? [] : files(name)) : [name];
  });
}
const sources = ['src', 'examples', 'tests', 'scripts'].flatMap(dir => files(path.join(root, dir)));
const compiler = process.env.LUAU_COMPILE_BIN || path.join(root, 'build/tools/luau/luau-compile.exe');
let luau = 0, javascript = 0, html = 0, references = 0, reviewedMissingReferences = 0;
const pythonSources = [];
function localReference(file, value) {
  value = value.replace(/&(?:quot|apos|amp|lt|gt);|&#(?:x[0-9a-f]+|\d+);/gi, entity => {
    if (entity[1] === '#') return String.fromCodePoint(parseInt(entity.slice(entity[2].toLowerCase() === 'x' ? 3 : 2, -1), entity[2].toLowerCase() === 'x' ? 16 : 10));
    return {'&quot;':'"','&apos;':"'",'&amp;':'&','&lt;':'<','&gt;':'>'}[entity.toLowerCase()];
  }).replace(/^(["'])(.*)\1$/, '$2');
  if (!value || /^(?:[a-z]+:|\/\/|#)/i.test(value)) return;
  const rootedBrowserReference = value.startsWith('/') && file.startsWith(browserRoot + path.sep);
  const target = rootedBrowserReference
    ? path.resolve(browserRoot, decodeURIComponent(value.split(/[?#]/)[0]).slice(1))
    : path.resolve(path.dirname(file), decodeURIComponent(value.split(/[?#]/)[0]));
  let exists = fs.existsSync(target);
  // Preserve only individually inventoried original-game omissions and reviewed
  // image exclusions. A changed source must be re-published before this applies.
  if (!exists) {
    const reviewedHash = reviewedGameReferences.get(file + '\0' + target);
    if (reviewedHash) {
      assert.equal(crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'), reviewedHash,
        `Changed original-game reference source: ${path.relative(root, file)}`);
      reviewedMissingReferences++;
      return;
    }
  }
  // Historical fixtures keep their original links to pages that are no longer
  // served. Only tests may resolve those links against the saved source archive.
  const fixturePath = path.relative(path.join(root, 'tests/fixtures'), file);
  if (!exists && fixturePath !== '..' && !fixturePath.startsWith('..' + path.sep) && !path.isAbsolute(fixturePath)) {
    const archiveTargets=[target];
    if (fixturePath.startsWith('css-atelier' + path.sep)) {
      const originalTarget = path.resolve(root, 'examples/websites', path.dirname(fixturePath), decodeURIComponent(value.split(/[?#]/)[0]));
      exists = fs.existsSync(originalTarget);
      archiveTargets.push(originalTarget);
    }
    for (const archiveTarget of archiveTargets) {
      const archivedPath = path.relative(path.join(root, 'examples/websites'), archiveTarget).split(path.sep);
      const folder=archivedPath.shift(), archivedFile=archivedPath.join('/');
      exists ||= [retiredWebsites[folder],retiredNightwebPages[folder]].some(site=>site && Object.hasOwn(site.files,archivedFile));
    }
  }
  assert.ok(exists, `Missing local reference in ${path.relative(root, file)}: ${value}`);
  references++;
}
for (const file of sources) {
  if (file.endsWith('.luau')) {
    const result = cp.spawnSync(compiler, ['--null', file], {encoding: 'utf8'});
    if (result.error) throw result.error;
    assert.equal(result.status, 0, `${file}\n${result.stdout}\n${result.stderr}`);
    luau++;
  } else if (file.endsWith('.py')) {
    pythonSources.push(file);
  } else if (/\.(?:[cm]?js)$/.test(file)) {
    const source = fs.readFileSync(file, 'utf8');
    let module = file.endsWith('.mjs');
    if (file.endsWith('.cjs')) {
      vm.compileFunction(source, ['exports', 'require', 'module', '__filename', '__dirname'], {filename: file});
    } else if (!module) {
      try { new vm.Script(source, {filename: file}); }
      catch (error) {
        if (!(error instanceof SyntaxError)) throw error;
        // Browser .js resources can be ES modules, including worker helpers.
        // Check the alternative parse goal without importing or executing it.
        module = true;
      }
    }
    if (module) {
      const result = cp.spawnSync(process.execPath, ['--check', '--input-type=module'], {input: source, encoding: 'utf8'});
      if (result.error) throw result.error;
      assert.equal(result.status, 0, `${file}\n${result.stderr}`);
    }
    javascript++;
  } else if (/\.(html|css)$/.test(file)) {
    const source = fs.readFileSync(file, 'utf8');
    const markup = source.replace(/(<script\b[^>]*>)[\s\S]*?(<\/script>)/gi, '$1$2');
    for (const match of markup.matchAll(/url\(\s*["']?([^"')\s]+)["']?\s*\)/g)) localReference(file, match[1]);
    if (!file.endsWith('.html')) continue;
    html++;
    // Deliberately broken anchors exercise the browser/engine 404 route.
    const auditedMarkup = markup.replace(/<a\b[^>]*\bdata-expected-missing\b[^>]*>/gi, tag => tag.replace(/\bhref\s*=\s*["'][^"']+["']/i, ''));
    for (const match of auditedMarkup.matchAll(/(?:src|href)\s*=\s*["']([^"']+)["']/g)) localReference(file, match[1]);
    for (const match of source.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)) {
      if (/\bsrc\s*=/i.test(match[1])) continue;
      const type = (match[1].match(/\btype\s*=\s*["']([^"']*)["']/i)?.[1] || '').trim().toLowerCase();
      if (type === 'module') {
        const result = cp.spawnSync(process.execPath, ['--check', '--input-type=module'], {input: match[2], encoding: 'utf8'});
        if (result.error) throw result.error;
        assert.equal(result.status, 0, `${file}\n${result.stderr}`);
      } else if (!type || /^(?:text|application)\/(?:java|ecma)script$/.test(type)) {
        new vm.Script(match[2], {filename: file});
      }
      // JSON, import maps and other data blocks are not JavaScript programs.
    }
  }
}
const pythonCheck = cp.spawnSync(process.env.PYTHON_BIN || 'python', ['-c',
  'import json,pathlib,sys\nfor file in json.load(sys.stdin):\n compile(pathlib.Path(file).read_text(encoding="utf-8-sig"),file,"exec")'],
  {input: JSON.stringify(pythonSources), encoding: 'utf8'});
if (pythonCheck.error) throw pythonCheck.error;
assert.equal(pythonCheck.status, 0, pythonCheck.stderr);
const browserCatalog = fs.readFileSync(path.join(root, 'examples/font-comparison-catalog.js'), 'utf8');
const catalog = JSON.parse(browserCatalog.slice(browserCatalog.indexOf('=') + 1).trim().replace(/;$/, ''));
const luaCatalog = fs.readFileSync(path.join(root, 'examples/FontComparison/Catalog.luau'), 'utf8');
const luaEntries = [...luaCatalog.matchAll(/Key = "([^"]+)", Name = "([^"]+)", Family = "([^"]+)"/g)];
assert.equal(catalog.fonts.length, 126);
assert.equal(luaEntries.length, catalog.fonts.length);
assert.equal(new Set(catalog.fonts.map(font => font.key)).size, catalog.fonts.length);
catalog.fonts.forEach((font, index) => {
  assert.deepEqual(luaEntries[index].slice(1), [font.key, font.name, font.family]);
  localReference(path.join(root, 'examples/font-comparison-catalog.js'), font.file);
});
const projects = fs.readdirSync(root).filter(file => file.endsWith('.project.json'));
function projectPaths(node, file) {
  if (!node || typeof node !== 'object') return;
  if (node.$path) localReference(file, node.$path);
  for (const child of Object.values(node)) if (child && typeof child === 'object') projectPaths(child, file);
}
for (const project of projects) {
  const file = path.join(root, project);
  projectPaths(JSON.parse(fs.readFileSync(file, 'utf8')).tree, file);
}
console.log(`Project audit passed: ${luau} Luau files, ${javascript} JS files, ${pythonSources.length} Python files, ${html} HTML files, ${references} local references, ${reviewedMissingReferences} inventoried original-game omissions/exclusions, ${projects.length} Rojo projects, 126 matching font entries.`);
