"""Independently decode only packed, selected PNG sources with Pillow.

No image files are written. The game archive is opened read-only; entries not
present in the reviewed pack manifest are never read.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--archive")
    parser.add_argument("--registry")
    parser.add_argument("--browser-root")
    args = parser.parse_args()
    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8-sig"))
    entries = {}
    archive = None
    if args.archive:
        if not args.registry:
            parser.error("--archive requires --registry")
        registry = json.loads(Path(args.registry).read_text(encoding="utf-8-sig"))
        if isinstance(registry, dict):
            registry = registry["Registry"]
        entries = {entry["Path"]: entry for entry in registry}
        archive = open(args.archive, "rb")
    elif not args.browser_root:
        parser.error("Supply --archive and --registry, or --browser-root")
    records = []
    try:
        for record in manifest["records"]:
            member = record["path"]
            if not member.lower().endswith(".png"):
                continue
            if archive:
                entry = entries[member]
                archive.seek(entry["Offset"])
                source = archive.read(entry["Length"])
                assert len(source) == entry["Length"], "Truncated PNG source"
            else:
                base = Path(args.browser_root).resolve()
                target = (base / member.lstrip("/")).resolve()
                assert target.is_relative_to(base), "PNG escaped browser root"
                source = target.read_bytes()
            if record.get("sourceSHA256"):
                assert hashlib.sha256(source).hexdigest() == record["sourceSHA256"], "Original PNG changed"
            with Image.open(io.BytesIO(source)) as image:
                rgba = image.convert("RGBA").tobytes()
                assert image.size == (record["width"], record["height"])
                pixel_hash = hashlib.sha256(rgba).hexdigest()
                assert pixel_hash == record["rgbaSHA256"], "Independent PNG RGBA differs: " + member
                records.append({"path": member, "width": image.width, "height": image.height,
                                "rgbaSHA256": pixel_hash})
    finally:
        if archive:
            archive.close()
    print(json.dumps({"decoder": "Pillow", "independentPNGCount": len(records), "records": records}))


if __name__ == "__main__":
    main()
