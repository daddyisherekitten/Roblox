"""Generate one Roblox website ModuleScript from browser-native files."""
from pathlib import Path
import json
import math
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
def quote(value):
    """Luau literals, not Python repr (which can emit invalid \\u escapes)."""
    escaped = []
    for char in value:
        code = ord(char)
        if char in ('"', '\\'):
            escaped.append('\\' + char)
        elif code < 32 or code == 127:
            escaped.append(f'\\{code:03d}')
        elif 0xD800 <= code <= 0xDFFF:
            raise ValueError("Unpaired Unicode surrogate in website metadata")
        else:
            escaped.append(char)
    return '"' + ''.join(escaped) + '"'

def luau(value, indent=0):
    if isinstance(value, dict):
        if not value:
            return "{}"
        prefix = "\t" * (indent + 1)
        entries = [f'{prefix}[{quote(key)}] = {luau(child, indent + 1)},' for key, child in value.items()]
        return "{\n" + "\n".join(entries) + "\n" + "\t" * indent + "}"
    if isinstance(value, list):
        return "{" + ", ".join(luau(child, indent) for child in value) + "}"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        if isinstance(value, float) and not math.isfinite(value):
            raise ValueError("Website options require finite numbers")
        return repr(value)
    if isinstance(value, str):
        return quote(value)
    if value is None:
        return "nil"
    raise TypeError(f"Unsupported option value: {type(value).__name__}")

def sync(site_name, module_name, display_name=None, origin="http://localhost:8000"):
    display_name = display_name or module_name
    origin = origin.rstrip("/")
    for value, pattern, message in (
        (site_name, r"[a-z0-9][a-z0-9-]*", "Invalid website folder"),
        (module_name, r"[A-Za-z][A-Za-z0-9_]*", "Invalid website module"),
        (origin, r'https?://[^/\s"<>]+', "Invalid website origin"),
    ):
        if not re.fullmatch(pattern, value):
            raise ValueError(message)
    folder = ROOT / "examples" / "websites" / site_name
    html_path, css_path = folder / "index.html", folder / "styles.css"
    websites_path = ROOT / "src" / "HTMLEngine" / "Websites"
    legacy_module_path = websites_path / f"{module_name}.luau"
    module_path = websites_path / module_name
    html = html_path.read_text(encoding="utf-8").replace("\r\n", "\n")
    css = css_path.read_text(encoding="utf-8").replace("\r\n", "\n")
    options_path = folder / "options.json"
    options = json.loads(options_path.read_text(encoding="utf-8")) if options_path.exists() else {}
    if not isinstance(options, dict):
        raise ValueError("Website options must be an object")
    for local_key, target_key, extension in (("LocalSVG", "SVGs", "svg"), ("LocalTracks", "Tracks", "vtt"), ("LocalStylesheets", "Stylesheets", "css")):
        local_paths = options.pop(local_key, [])
        if not isinstance(local_paths, list):
            raise ValueError(local_key + " must be a list of local paths")
        if local_paths:
            sources = options.setdefault(target_key, {})
            if not isinstance(sources, dict):
                raise ValueError(target_key + " must map paths to file contents")
            for name in local_paths:
                if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9._/-]+\." + extension, name):
                    raise ValueError(local_key + " entries must be local ." + extension + " paths")
                source_path = (folder / name).resolve()
                if not source_path.is_relative_to(folder.resolve()) or not source_path.is_file():
                    raise ValueError(local_key + " file is outside the website or missing: " + name)
                if name in sources:
                    raise ValueError("Duplicate local source: " + name)
                sources[name] = source_path.read_text(encoding="utf-8")
    local_scripts = options.pop("LocalScripts", [])
    single_script = None
    if not isinstance(local_scripts, list):
        raise ValueError("LocalScripts must be a list of local paths")
    if local_scripts:
        services = options.setdefault("JavaScriptServices", {})
        if not isinstance(services, dict):
            raise ValueError("JavaScriptServices must be an object")
        sources = services.setdefault("ScriptSources", {})
        if not isinstance(sources, dict):
            raise ValueError("ScriptSources must map URLs to file contents")
        for name in local_scripts:
            if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9._/-]+\.js", name):
                raise ValueError("LocalScripts entries must be local .js paths")
            source_path = (folder / name).resolve()
            if not source_path.is_relative_to(folder.resolve()) or not source_path.is_file():
                raise ValueError("LocalScripts file is outside the website or missing: " + name)
            relative_path = source_path.relative_to(folder.resolve()).as_posix()
            url = origin + '/' + site_name + '/' + relative_path
            if url in sources:
                raise ValueError("Duplicate local script source: " + url)
            sources[url] = source_path.read_text(encoding="utf-8")
            if len(local_scripts) == 1:
                single_script = (relative_path, sources[url])
                del sources[url]
                if not sources:
                    del services["ScriptSources"]
                if not services:
                    del options["JavaScriptServices"]
    # Linked/imported sheets belong to the document source map, rather than
    # becoming synthetic CSS or losing their own namespace/import scope.
    local_stylesheets = options.pop("Stylesheets", None)
    serialized_options = luau(options, 1)
    assert html.lower().lstrip().startswith("<!doctype html>") and html.lower().rstrip().endswith("</html>")
    assert re.search(r'<link\s+[^>]*rel=["\']stylesheet["\'][^>]*href=["\']styles\.css["\']', html, re.I), "index.html must link styles.css"
    assert "]==]" not in html and "]==]" not in css, "Source contains the Luau long-string delimiter"

    module_path.mkdir(parents=True, exist_ok=True)
    html_module = f"--!strict\n-- Generated from {html_path.relative_to(ROOT).as_posix()}.\nreturn [==[\n{html}]==]\n"
    css_module = f"--!strict\n-- Generated from {css_path.relative_to(ROOT).as_posix()}.\nreturn [==[\n{css}]==]\n"
    script_metadata = f"\tScriptPath = {quote(single_script[0])},\n" if single_script else ""
    index_module = (
        f"--!strict\n-- Generated by scripts/sync-website.py. Edit files under {folder.relative_to(ROOT).as_posix()} instead.\n"
        f"return {{\n\tName = {quote(display_name)},\n"
        f"\tURL = {quote(origin + '/' + site_name + '/index.html')},\n"
        f"{script_metadata}" + (f"\tStylesheets = {luau(local_stylesheets, 1)},\n" if local_stylesheets else "") + f"\tOptions = {serialized_options},\n}}\n"
    )
    (module_path / "HTML.luau").write_text(html_module, encoding="utf-8", newline="\n")
    (module_path / "CSS.luau").write_text(css_module, encoding="utf-8", newline="\n")
    (module_path / "init.luau").write_text(index_module, encoding="utf-8", newline="\n")
    javascript_path = module_path / "JavaScript.luau"
    if single_script:
        script_source = single_script[1].replace("\r\n", "\n")
        literal = quote(script_source) if "]==]" in script_source else "[==[\n" + script_source + "]==]"
        javascript_path.write_text("--!strict\n-- Generated from " + (folder / single_script[0]).relative_to(ROOT).as_posix() + ".\nreturn " + literal + "\n", encoding="utf-8", newline="\n")
    elif javascript_path.exists():
        javascript_path.unlink()
    if legacy_module_path.exists():
        legacy_module_path.unlink()
    print(f"Website {module_name} generated from {folder.relative_to(ROOT)}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit("Usage: python scripts/sync-website.py folder ModuleName [Title] [Origin]")
    sync(*sys.argv[1:])
