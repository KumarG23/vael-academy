#!/usr/bin/env python3
"""CP-2: check the existing Gemini art API without exporting its key for OAuth.

Run with Pillow installed:
  uv run --with pillow tools/gemini_pipeline_check.py --generate
The key is read from VAEL_ART_API_KEY (or GEMINI_API_KEY), never printed. A real
image test reuses gemini_emotions.edit_portrait and writes a separate specimen.
"""
import argparse
import json
import os
from pathlib import Path
import shlex
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def read_key(env_file: Path) -> str:
    key = os.environ.get("VAEL_ART_API_KEY", "") or os.environ.get("GEMINI_API_KEY", "")
    if key or not env_file.exists():
        return key
    for line in env_file.read_text().splitlines():
        name, separator, value = line.strip().removeprefix("export ").partition("=")
        if separator and name.strip() in ("VAEL_ART_API_KEY", "GEMINI_API_KEY"):
            words = shlex.split(value, comments=True)
            return words[0] if words else ""
    return ""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    parser.add_argument("--generate", action="store_true", help="also test one reference-image edit")
    parser.add_argument("--output", type=Path, default=ROOT / "assets/source/illustrated_pilot/gemini_smoke.png")
    args = parser.parse_args()
    report: dict = {"model": "gemini-3.1-flash-image", "generation_requested": args.generate}
    key = read_key(args.env_file)
    if not key:
        report.update(status="credential_missing", explanation="Set VAEL_ART_API_KEY in the gitignored project .env; no API request was sent.")
        print(json.dumps(report, indent=2))
        return 2
    started = time.monotonic()
    try:
        request = urllib.request.Request("https://generativelanguage.googleapis.com/v1beta/models", headers={"x-goog-api-key": key})
        with urllib.request.urlopen(request, timeout=30) as response:
            models = json.load(response)
        available = [m["name"] for m in models.get("models", []) if "image" in m["name"]]
        report.update(status="connected", image_models=available)
        if args.generate:
            if args.output.exists():
                raise FileExistsError("Output already exists; choose a new --output path.")
            # Exercise the project's established image-editing endpoint and
            # JPEG-to-PNG conversion rather than merely testing authentication.
            from gemini_emotions import edit_portrait
            from PIL import Image
            raw = edit_portrait(key, (ROOT / "assets/portraits/portrait_kai.png").read_bytes(), "determined")
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_bytes(raw)
            with Image.open(args.output) as image:
                report.update(status="image_generated", format=image.format, dimensions=list(image.size), output=str(args.output))
    except urllib.error.HTTPError as error:
        report.update(status="api_error", http_status=error.code)
        try:
            detail = json.loads(error.read()).get("error", {})
            report.update(api_status=detail.get("status"), explanation=str(detail.get("message", "")).replace(key, "[REDACTED]"))
        except (ValueError, UnicodeError):
            report["explanation"] = "The endpoint returned a non-JSON error."
    except Exception as error:
        report.update(status="failed", explanation=str(error).replace(key, "[REDACTED]"))
    report["elapsed_seconds"] = round(time.monotonic() - started, 2)
    print(json.dumps(report, indent=2))
    return 0 if report["status"] in ("connected", "image_generated") else 1


if __name__ == "__main__":
    raise SystemExit(main())
