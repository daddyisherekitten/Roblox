"""Regression: metadata survives Python -> Luau, including invisible Unicode."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("sync_website", ROOT / "scripts/sync-website.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class SerializationTests(unittest.TestCase):
    def test_runtime_roundtrip(self):
        values = ['quotes "\' and \\', '\u2028\u200b\U0001f642', '\0' + '123\n\r\t\x1b\x7f']
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "roundtrip.luau"
            script.write_text('local values = ' + sync.luau(values) + '\n'
                              'for _, value in values do\n'
                              'local bytes = {}\n'
                              'for i=1,#value do bytes[i]=tostring(string.byte(value,i)) end\n'
                              'print(table.concat(bytes,","))\nend\n', encoding='utf-8')
            result = subprocess.run([ROOT / 'build/tools/luau/luau.exe', script], capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.splitlines(), [','.join(map(str, v.encode('utf-8'))) for v in values])

    def test_numeric_and_boolean_options(self):
        self.assertEqual(sync.luau([True, False, 12, 1.25]), '{true, false, 12, 1.25}')
        for invalid in [float('nan'), float('inf'), float('-inf')]:
            with self.assertRaises(ValueError):
                sync.luau(invalid)

    def test_sync_exact_content_and_no_partial_write(self):
        with tempfile.TemporaryDirectory() as directory:
            original = sync.ROOT
            try:
                sync.ROOT = Path(directory)
                folder = sync.ROOT / 'examples/websites/test'
                folder.mkdir(parents=True)
                html = '<!doctype html><html><head><link rel="stylesheet" href="styles.css"></head><body>Test</body></html>\n'
                (folder / 'index.html').write_text(html, encoding='utf-8')
                (folder / 'styles.css').write_text('body{color:red}\n', encoding='utf-8')
                sync.sync('test', 'Test', 'Hello\u2028world')
                target = sync.ROOT / 'src/HTMLEngine/Websites/Test/HTML.luau'
                self.assertEqual(target.read_text().split('return [==[\n')[1].removesuffix(']==]\n'), html)
                before = target.read_bytes()
                (folder / 'options.json').write_text('{"bad": NaN}')
                with self.assertRaises(ValueError):
                    sync.sync('test', 'Test')
                self.assertEqual(target.read_bytes(), before)
            finally:
                sync.ROOT = original

    def test_local_svg_is_packaged_from_the_browser_file(self):
        with tempfile.TemporaryDirectory() as directory:
            original = sync.ROOT
            try:
                sync.ROOT = Path(directory)
                folder = sync.ROOT / 'examples/websites/media'
                folder.mkdir(parents=True)
                (folder / 'index.html').write_text('<!doctype html><html><head><link rel="stylesheet" href="styles.css"></head><body><img src="sample.svg"></body></html>')
                (folder / 'styles.css').write_text('img{width:100%}')
                (folder / 'sample.svg').write_text('<svg width="4" height="3"><rect width="4" height="3"/></svg>')
                (folder / 'captions.vtt').write_text('WEBVTT\n\n00:00.000 --> 00:01.000\nHallo\n')
                (folder / 'tokens.css').write_text('@namespace s "http://www.w3.org/2000/svg";\ns|rect {fill:red}\n')
                (folder / 'options.json').write_text('{"LocalSVG":["sample.svg"],"LocalTracks":["captions.vtt"],"LocalStylesheets":["tokens.css"]}')
                sync.sync('media', 'Media')
                generated = (sync.ROOT / 'src/HTMLEngine/Websites/Media/init.luau').read_text()
                self.assertIn('["SVGs"]', generated)
                self.assertIn('["sample.svg"]', generated)
                self.assertIn('<svg width=\\"4\\"', generated)
                self.assertNotIn('LocalSVG', generated)
                self.assertIn('["Tracks"]', generated)
                self.assertIn('["captions.vtt"]', generated)
                self.assertIn('WEBVTT', generated)
                self.assertNotIn('LocalTracks', generated)
                self.assertIn('\tStylesheets = {', generated)
                self.assertIn('["tokens.css"]', generated)
                self.assertIn('@namespace s', generated)
                self.assertNotIn('LocalStylesheets', generated)
                (folder / 'options.json').write_text('{"LocalSVG":["../outside.svg"]}')
                with self.assertRaises(ValueError):
                    sync.sync('media', 'Media')
                self.assertEqual((sync.ROOT / 'src/HTMLEngine/Websites/Media/init.luau').read_text(), generated)
            finally:
                sync.ROOT = original

    def test_local_script_uses_the_browser_file_and_canonical_url(self):
        with tempfile.TemporaryDirectory() as directory:
            original = sync.ROOT
            try:
                sync.ROOT = Path(directory)
                folder = sync.ROOT / 'examples/websites/stays'
                folder.mkdir(parents=True)
                (folder / 'index.html').write_text('<!doctype html><html><head><link rel="stylesheet" href="styles.css"><script src="app.js" defer></script></head><body></body></html>')
                (folder / 'styles.css').write_text('body{color:green}')
                source = "window.title = 'Auszeit';\n"
                (folder / 'app.js').write_text(source)
                (folder / 'options.json').write_text('{"LocalScripts":["./app.js"]}')
                sync.sync('stays', 'Stays', origin='https://example.test')
                target = sync.ROOT / 'src/HTMLEngine/Websites/Stays/init.luau'
                generated = target.read_text()
                self.assertIn('ScriptPath = "app.js"', generated)
                javascript = sync.ROOT / 'src/HTMLEngine/Websites/Stays/JavaScript.luau'
                self.assertEqual(javascript.read_text().split('return [==[\n')[1].removesuffix(']==]\n'), source)
                self.assertNotIn('ScriptSources', generated)
                self.assertNotIn('LocalScripts', generated)
                for bad in ({'LocalScripts':['../outside.js']},
                            {'LocalScripts':['app.js', './app.js']},
                            {'LocalScripts':['app.js'], 'JavaScriptServices':[]},
                            {'LocalScripts':['app.js'], 'JavaScriptServices':{'ScriptSources':[]}}):
                    (folder / 'options.json').write_text(json.dumps(bad))
                    with self.assertRaises(ValueError):
                        sync.sync('stays', 'Stays', origin='https://example.test')
                    self.assertEqual(target.read_text(), generated)
            finally:
                sync.ROOT = original


if __name__ == '__main__':
    unittest.main()
