---
name: kokoro-narration
description: Generate and compare Vael Academy narrator assets with the private Kokoro service on big-ai.
---

# Kokoro narration

Use `python3 tools/kokoro_narrate.py` for fast, consistent narrator voice assets. Kokoro runs CPU-only on big-ai over Tailscale, leaving the GPT-OSS GPU lane alone.

## Commands

```bash
python3 tools/kokoro_narrate.py health
python3 tools/kokoro_narrate.py voices
python3 tools/kokoro_narrate.py render \
  --text "The academy gates opened." \
  --voice af_heart \
  --speed 1.0 \
  --output assets/audio/narration/kokoro/academy_gates_af_heart.wav
```

For longer narration, use `--text-file path/to/script.txt`. Available voices come from the `voices` command. Start comparisons with `af_heart`, then test `af_bella`, `am_adam`, `bf_emma`, and `bm_george` when useful.

## Rules

- Treat generated narration as build-time assets; the shipped game must never depend on the live API.
- Keep engine comparisons explicit in filenames or engine-specific directories. Do not silently replace approved Chatterbox clips with Kokoro clips.
- Keep `speed=1.0` for the baseline. Test deliberate variants separately rather than moving the target during voice comparison.
- Use stable snake_case filenames under `assets/audio/narration/kokoro/`.
- Verify each output is a non-empty 24 kHz mono WAV and audition it before approval.
- Kokoro voices are synthetic stock voices rather than cloned real people, making Kokoro the safer default candidate for distributable narration; still retain model/voice/license provenance with shipped assets.
