#!/usr/bin/env python3
"""Generate narration through Neal's private Chatterbox service on ai-box."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_URL = os.environ.get("CHATTERBOX_URL", "http://100.66.106.122:8124")


def request_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=15) as response:
        return json.load(response)


def synthesize(args: argparse.Namespace) -> int:
    if bool(args.text) == bool(args.text_file):
        raise SystemExit("Provide exactly one of --text or --text-file")
    text = args.text if args.text else Path(args.text_file).read_text(encoding="utf-8")
    text = text.strip()
    if not text:
        raise SystemExit("Narration text is empty")

    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "text": text,
        "voice": args.voice,
        "exaggeration": args.exaggeration,
        "temperature": args.temperature,
        "cfg_weight": args.cfg_weight,
    }
    request = urllib.request.Request(
        f"{args.url.rstrip('/')}/synthesize",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    fd, temporary_name = tempfile.mkstemp(prefix=f".{output.name}.", dir=output.parent)
    os.close(fd)
    temporary = Path(temporary_name)
    try:
        with urllib.request.urlopen(request, timeout=args.timeout) as response:
            temporary.write_bytes(response.read())
        if temporary.stat().st_size < 44 or temporary.read_bytes()[:4] != b"RIFF":
            raise RuntimeError("Server response is not a valid WAV file")
        temporary.replace(output)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise

    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(json.dumps({
        "status": "ok",
        "output": str(output),
        "bytes": output.stat().st_size,
        "sha256": digest,
        "voice": args.voice,
        "host": args.url,
    }))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=DEFAULT_URL)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("health")
    subparsers.add_parser("voices")

    render = subparsers.add_parser("render")
    source = render.add_mutually_exclusive_group(required=True)
    source.add_argument("--text")
    source.add_argument("--text-file")
    render.add_argument("--output", required=True)
    render.add_argument("--voice", default="default")
    render.add_argument("--exaggeration", type=float, default=0.7)
    render.add_argument("--temperature", type=float, default=0.6)
    render.add_argument("--cfg-weight", type=float, default=0.6)
    render.add_argument("--timeout", type=int, default=600)

    args = parser.parse_args()
    try:
        if args.command == "health":
            print(json.dumps(request_json(f"{args.url.rstrip('/')}/health"), indent=2))
            return 0
        if args.command == "voices":
            print(json.dumps(request_json(f"{args.url.rstrip('/')}/voices"), indent=2))
            return 0
        return synthesize(args)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        print(f"Chatterbox HTTP {exc.code}: {detail}", file=sys.stderr)
        return 1
    except (urllib.error.URLError, TimeoutError) as exc:
        print(f"Chatterbox is unreachable at {args.url}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
