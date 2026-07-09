#!/usr/bin/env python3
"""AW-59: batch portrait emotion variants through the Gemini image API.

Feeds a character's base portrait to gemini-3.1-flash-image with an
edit-in-place prompt per emotion and installs the results as
assets/portraits/portrait_<id>_<emotion>.png. Identity holds because the model
edits the provided image rather than re-rolling the character.

Reads GEMINI_API_KEY from the environment (source .env first). The key is
never printed. Run `godot --headless --import` after a batch.

Usage:
  python3 tools/gemini_emotions.py <unit_id> [emotion ...]
  python3 tools/gemini_emotions.py serra            # default 4 emotions
  python3 tools/gemini_emotions.py --missing       # every base portrait lacking a set
"""
import base64
import json
import os
import pathlib
import sys
import time
import urllib.request

MODEL = "gemini-3.1-flash-image"
PORTRAITS = pathlib.Path("assets/portraits")
DEFAULT_EMOTIONS = ["happy", "sad", "angry", "blush"]
PROMPTS = {
    "happy": "a warm, delighted smile — genuinely happy, eyes bright with joy",
    "sad": "sad and hurt — glistening teary eyes, brows tilted up, mouth small and wavering",
    "angry": "angry — furrowed brows, hard glaring eyes, tight frowning mouth",
    "blush": "deeply flustered and blushing — red cheeks, wide flustered eyes, caught off guard",
    "surprised": "shocked surprise — wide eyes, raised brows, mouth open in a small gasp",
    "smug": "smug and teasing — a knowing half-smile, one brow raised, playful confidence",
    "worried": "worried and anxious — knitted brows, biting lip, eyes uncertain",
    "determined": "fierce determination — set jaw, steady burning gaze, resolute",
}


def edit_portrait(key: str, base_png: bytes, emotion: str) -> bytes:
    prompt = (
        "Edit this character portrait. Keep it EXACTLY the same character, the same "
        "anime art style, the same framing and pose, the same outfit, hair, colors, "
        "lighting and background. Change ONLY the facial expression to: "
        f"{PROMPTS[emotion]}. Output a single edited image."
    )
    body = {
        "contents": [{"parts": [
            {"inline_data": {"mime_type": "image/png",
                             "data": base64.b64encode(base_png).decode()}},
            {"text": prompt},
        ]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        out = json.load(resp)
    for cand in out.get("candidates", []):
        for part in cand.get("content", {}).get("parts", []):
            if "inlineData" in part:
                return base64.b64decode(part["inlineData"]["data"])
    raise RuntimeError(f"no image in response: {json.dumps(out)[:300]}")


def run_unit(key: str, unit_id: str, emotions: list) -> None:
    base = PORTRAITS / f"portrait_{unit_id}.png"
    if not base.exists():
        print(f"  !! no base portrait for {unit_id}")
        return
    base_png = base.read_bytes()
    for emotion in emotions:
        out = PORTRAITS / f"portrait_{unit_id}_{emotion}.png"
        if out.exists():
            print(f"  = {out.name} exists, skipping")
            continue
        for attempt in range(3):
            try:
                out.write_bytes(edit_portrait(key, base_png, emotion))
                print(f"  + {out.name}")
                break
            except Exception as e:  # rate limits / transient — back off and retry
                wait = 12 * (attempt + 1)
                print(f"  … {emotion} attempt {attempt + 1} failed ({str(e)[:90]}), retrying in {wait}s")
                time.sleep(wait)
        else:
            print(f"  !! {emotion} failed after retries")
        time.sleep(4)  # stay friendly to the free-tier rate limit


def main() -> None:
    key = os.environ.get("GEMINI_API_KEY", "")
    if not key:
        sys.exit("GEMINI_API_KEY not in environment (source .env first)")
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    if args[0] == "--missing":
        for base in sorted(PORTRAITS.glob("portrait_*.png")):
            stem = base.stem.replace("portrait_", "")
            if "_" in stem:  # already an emotion variant
                continue
            missing = [e for e in DEFAULT_EMOTIONS
                       if not (PORTRAITS / f"portrait_{stem}_{e}.png").exists()]
            if missing:
                print(f"{stem}: {missing}")
                run_unit(key, stem, missing)
        return
    unit_id = args[0]
    emotions = args[1:] or DEFAULT_EMOTIONS
    print(f"{unit_id}:")
    run_unit(key, unit_id, emotions)


if __name__ == "__main__":
    main()
