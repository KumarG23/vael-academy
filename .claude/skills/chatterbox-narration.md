---
name: chatterbox-narration
description: Generate or update Vael Academy narrator voice assets with the private Chatterbox service on ai-box.
---

# Chatterbox narration

Use `python3 tools/chatterbox_narrate.py` for generated narration. Chatterbox runs privately on ai-box over Tailscale; do not install or run the model on the Mac.

## Commands

```bash
python3 tools/chatterbox_narrate.py health
python3 tools/chatterbox_narrate.py voices
python3 tools/chatterbox_narrate.py render \
  --text "The academy gates opened." \
  --voice default \
  --output assets/audio/narration/academy_gates.wav
```

For longer scripts, use `--text-file path/to/script.txt`. Defaults are `exaggeration=0.7`, `temperature=0.6`, and `cfg_weight=0.6`; change them only for an intentional voice-direction test.

## Rules

- Treat narration as generated build-time assets, never a runtime network dependency.
- Use `default` for distributable prototypes. The `narrator`, `narrator-long`, and `neal` aliases are private voice-reference experiments; do not ship those clips without Neal's explicit approval and rights review.
- Use stable, descriptive snake_case filenames under `assets/audio/narration/`.
- Do not overwrite an approved clip merely because synthesis is nondeterministic. Generate a named variant or ask Neal to choose.
- Verify each result is a non-empty WAV and audition it before marking voice work complete.
- The first request after an idle period may take roughly 30–60 seconds while the GPU model loads. Subsequent batch requests are faster. The server unloads the model after ten idle minutes to protect Frigate/Ollama GPU headroom.
