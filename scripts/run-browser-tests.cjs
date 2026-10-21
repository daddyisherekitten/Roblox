// This bundle contains Browser only; HTMLEngine is neither imported nor bundled.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
let bundle = require('./browser-test-bundle.cjs')(root);
for (const name of ['BrowserShell','BrowserStartPage','BrowserSingleView','BrowserSessionMigration','BrowserSingleSession']) bundle += '\ndo\nlocal run=(function()\n' + fs.readFileSync(path.join(root, 'tests',name+'.luau'), 'utf8') + '\nend)()\nrun(loadBrowser,browserFixture,loadBrowserStore)\nend\n';
fs.mkdirSync(path.join(root, 'build'), {recursive:true});
const target = path.join(root, `build/browser-tests-${process.pid}.luau`);
fs.writeFileSync(target, bundle);
const result = cp.spawnSync(process.env.LUAU_BIN || path.join(root, 'build/tools/luau/luau.exe'), [target], {stdio:'inherit'});
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
