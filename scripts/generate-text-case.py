"""Pinned Unicode 17 case/width/kana data. Reproducible offline after --download.

UnicodeData is shared with the existing normalization generator; no second copy.
The Unicode license is retained at src/HTMLEngine/JavaScript/Unicode.LICENSE.txt.
"""
from pathlib import Path
import argparse
import hashlib
import json
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
VERSION = "17.0.0"
BASE = f"https://www.unicode.org/Public/{VERSION}/ucd/"
CACHE = ROOT / f"scripts/data/unicode-case-{VERSION}"
SHARED = ROOT / f"scripts/data/unicode-{VERSION}/UnicodeData.txt"
SOURCES = {"SpecialCasing.txt": "SpecialCasing.txt", "DerivedCoreProperties.txt": "DerivedCoreProperties.txt", "PropList.txt": "PropList.txt"}


def rows(file):
    for line in file.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line and not line.startswith("@"):
            yield [part.strip() for part in line.split(";")]


def sequence(value):
    return "".join(chr(int(code, 16)) for code in value.split())


def ranges(values):
    result = []
    for code in sorted(values):
        if result and code == result[-1] + 1:
            result[-1] = code
        else:
            result.extend([code, code])
    return "{" + ",".join(map(str, result)) + "}"


def lua(value):
    return json.dumps(value, ensure_ascii=False)


def generate():
    parser = argparse.ArgumentParser()
    parser.add_argument("--download", action="store_true")
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    if args.download:
        for name, source in SOURCES.items():
            (CACHE / name).write_bytes(urllib.request.urlopen(BASE + source, timeout=30).read())
    manifest = {"version": VERSION, "license": "../../../src/HTMLEngine/JavaScript/Unicode.LICENSE.txt", "sources": {}}
    for name, source in SOURCES.items():
        data = (CACHE / name).read_bytes()
        manifest["sources"][name] = {"url": BASE + source, "sha256": hashlib.sha256(data).hexdigest()}
    manifest["sources"]["UnicodeData.txt"] = {"url": BASE + "UnicodeData.txt", "file": "../unicode-17.0.0/UnicodeData.txt", "sha256": hashlib.sha256(SHARED.read_bytes()).hexdigest()}
    tables = {name: {} for name in ("Upper", "Lower", "Title", "Wide", "Kana", "Math", "Combining")}
    letters, general_letters, names, boundaries, decompositions = set(), set(), {}, set(), {}
    pending = general_pending = None
    for row in rows(SHARED):
        code, name, category = int(row[0], 16), row[1], row[2]
        if category.startswith("L") or category in ("Nd", "Nl"):
            if name.endswith(", First>"):
                pending = code
            elif name.endswith(", Last>"):
                letters.update(range(pending, code + 1)); pending = None
            else:
                letters.add(code)
            if category.startswith("L"):
                if name.endswith(", First>"):
                    general_pending = code
                elif name.endswith(", Last>"):
                    general_letters.update(range(general_pending, code + 1)); general_pending = None
                else:
                    general_letters.add(code)
        names[name] = code
        if category == 'Pd' or category == 'Zs' or category in ('Zl', 'Zp'):
            boundaries.add(code)
        for field, index in (("Upper", 12), ("Lower", 13), ("Title", 14)):
            value = row[index] or (row[12] if field == "Title" else "")
            if value:
                tables[field][code] = sequence(value)
        if int(row[3]):
            tables["Combining"][code] = int(row[3])
        decomposition = row[5].split()
        if decomposition and not decomposition[0].startswith('<'):
            decompositions[code] = [int(value, 16) for value in decomposition]
        if decomposition and decomposition[0] == "<wide>":
            tables["Wide"][int(decomposition[1], 16)] = chr(code)
        elif decomposition and decomposition[0] == "<narrow>":
            tables["Wide"][code] = sequence(" ".join(decomposition[1:]))
        elif name.startswith("MATHEMATICAL ITALIC ") and decomposition and decomposition[0] == "<font>" and len(decomposition) == 2:
            tables["Math"][int(decomposition[1], 16)] = chr(code)
    tables["Math"][0x68] = "ℎ"  # The hole in Mathematical Italic is the legacy Planck constant.
    # Canonical Greek decompositions permit orthographic uppercasing without
    # changing the original text's normalization or source spans.
    def decompose(code):
        return [part for value in decompositions.get(code, [code]) for part in (decompose(value) if value != code else [code])]
    greek = {}
    for code in range(0x370, 0x2127):
        values = decompose(code)
        if values != [code] and 0x370 <= values[0] <= 0x3FF:
            greek[code] = values
    boundaries.update(range(9, 14))
    # This UA capitalization profile treats punctuation except apostrophes,
    # underscores and combining marks as word separators, matching Chromium.
    boundaries.update(map(ord, '/.:;!?()[]{}"'))
    for name, code in names.items():
        if name.startswith(("HIRAGANA LETTER SMALL ", "KATAKANA LETTER SMALL ", "HALFWIDTH KATAKANA LETTER SMALL ")):
            full = names.get(name.replace(" LETTER SMALL ", " LETTER "))
            if full is not None:
                tables["Kana"][code] = chr(full)
    conditional = []
    for row in rows(CACHE / "SpecialCasing.txt"):
        code = int(row[0], 16)
        mapping = {"Lower": sequence(row[1]), "Title": sequence(row[2]), "Upper": sequence(row[3])}
        if len(row) > 4 and row[4]:
            conditional.append({"Code": code, **mapping, "Conditions": row[4].lower().split()})
        else:
            for field, value in mapping.items():
                tables[field][code] = value
    properties = {name: set() for name in ("Cased", "Case_Ignorable", "Soft_Dotted")}
    for file in ("DerivedCoreProperties.txt", "PropList.txt"):
        for row in rows(CACHE / file):
            if row[1] not in properties:
                continue
            bounds = row[0].split("..")
            properties[row[1]].update(range(int(bounds[0], 16), int(bounds[-1], 16) + 1))
    lines = ["--!strict", "-- Generated by scripts/generate-text-case.py; pinned Unicode 17.0.0.",
             "-- Unicode License V3: ../JavaScript/Unicode.LICENSE.txt; source hashes in scripts/data/unicode-case-17.0.0/manifest.json.",
             *["-- " + line for line in (ROOT / "src/HTMLEngine/JavaScript/Unicode.LICENSE.txt").read_text(encoding="utf-8").splitlines()],
             'return {Version="17.0.0",']
    for name, table in tables.items():
        lines.append(name + "={")
        lines.extend(f"[{code}]={lua(value) if isinstance(value, str) else value}," for code, value in sorted(table.items()))
        lines.append("},")
    lines.append("Letters=" + ranges(letters) + ",")
    lines.append("GeneralLetters=" + ranges(general_letters) + ",")
    lines.append("Boundaries=" + ranges(boundaries) + ",")
    lines.append("Greek={" + ','.join(f'[{code}]={{' + ','.join(map(str, value)) + '}' for code, value in sorted(greek.items())) + "},")
    for name, values in properties.items():
        lines.append(name.replace("_", "") + "=" + ranges(values) + ",")
    lines.append("Conditional={")
    for entry in conditional:
        conditions = "{" + ",".join(lua(value) for value in entry["Conditions"]) + "}"
        lines.append("{" + f"Code={entry['Code']},Lower={lua(entry['Lower'])},Title={lua(entry['Title'])},Upper={lua(entry['Upper'])},Conditions={conditions}" + "},")
    lines.append("}}\n")
    (ROOT / "src/HTMLEngine/Layout/TextCaseData.luau").write_text("\n".join(lines), encoding="utf-8")
    (CACHE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("Unicode text case:", sum(len(table) for table in tables.values()), "mappings,", len(conditional), "conditional rules")


if __name__ == "__main__":
    generate()
