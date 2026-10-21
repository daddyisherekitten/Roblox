"""Generate original, quiet media used only by the desktop-browser preview.

Roblox replaces these URL paths with the asset IDs in the page's options.json.
Requires Python's standard library and an ffmpeg build with libx264/libvorbis.
"""

import argparse
import json
import math
from pathlib import Path
import shutil
import subprocess


WIDTH = 640
HEIGHT = 360
FPS = 24
SECONDS = 5
COLORS = ((49, 205, 240), (244, 89, 166), (118, 233, 164), (251, 206, 89))


def frame_at(index):
    """All motion is periodic across the five-second clip boundary."""
    phase = math.tau * index / (FPS * SECONDS)
    pixels = bytearray(bytes((5, 7, 14)) * (WIDTH * HEIGHT))
    for number in range(20):
        angle = phase + number * math.tau / 20
        x = round(WIDTH / 2 + (85 + number % 5 * 39) * math.cos(angle))
        y = round(HEIGHT / 2 + (45 + number % 4 * 25) * math.sin(angle * (1 + number % 2)))
        radius = 10 + number % 5 * 4
        color = bytes(COLORS[number % len(COLORS)])
        for row in range(max(0, y - radius), min(HEIGHT, y + radius + 1)):
            extent = math.isqrt(radius * radius - (row - y) * (row - y))
            start = max(0, x - extent)
            end = min(WIDTH, x + extent + 1)
            offset = (row * WIDTH + start) * 3
            pixels[offset:offset + (end - start) * 3] = color * (end - start)
    return pixels


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    args = parser.parse_args()
    if not args.ffmpeg:
        parser.error("ffmpeg is not on PATH; pass --ffmpeg PATH")

    directory = Path(__file__).resolve().parents[1] / "examples/websites/annoying-site/media"
    directory.mkdir(parents=True, exist_ok=True)
    common = [args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y"]
    subprocess.run(common + [
        "-f", "lavfi", "-i", "sine=frequency=220:sample_rate=48000:duration=3",
        "-af", "volume=0.16", "-c:a", "libvorbis", "-q:a", "3", "-threads", "1",
        "-fflags", "+bitexact", "-flags:a", "+bitexact", str(directory / "theremin.ogg"),
    ], check=True)

    process = subprocess.Popen(common + [
        "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", f"{WIDTH}x{HEIGHT}",
        "-framerate", str(FPS), "-i", "pipe:0", "-an", "-c:v", "libx264", "-preset", "medium",
        "-crf", "28", "-pix_fmt", "yuv420p", "-threads", "1", "-movflags", "+faststart",
        "-fflags", "+bitexact", "-flags:v", "+bitexact", str(directory / "clip.mp4"),
    ], stdin=subprocess.PIPE)
    try:
        for index in range(FPS * SECONDS):
            process.stdin.write(frame_at(index))
        process.stdin.close()
    except BaseException:
        process.kill()
        process.wait()
        raise
    if process.wait() != 0:
        raise RuntimeError("ffmpeg could not encode the preview video")

    metadata = {
        "purpose": "Original local desktop-browser previews; not copies of the Roblox assets.",
        "generator": "scripts/generate-annoying-preview-media.py",
        "audio": {
            "file": "theremin.ogg", "frequencyHz": 220, "durationSeconds": 3,
            "nominalPeakAmplitude": 0.02,
            "robloxAssetId": "93424997719572",
        },
        "video": {
            "file": "clip.mp4", "width": WIDTH, "height": HEIGHT,
            "fps": FPS, "durationSeconds": SECONDS,
            "description": "Procedural colored discs moving on a dark background; no audio.",
            "robloxAssetId": "5608384572",
        },
    }
    (directory / "source.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    for name in ("theremin.ogg", "clip.mp4"):
        path = directory / name
        print(f"{path.relative_to(Path(__file__).resolve().parents[1])}: {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
