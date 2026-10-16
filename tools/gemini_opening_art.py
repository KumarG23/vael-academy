#!/usr/bin/env python3
"""VS-1B reviewed jobs through Vael's existing Gemini image pipeline.

Usage (Pillow environment): python tools/gemini_opening_art.py JOB [...]
Each version is immutable. Add a new job for revisions; never overwrite a source.
The job file carries full prompts; each output gets reference hashes and timing.
No automatic install: review the master and the native Godot crop first.
"""
import hashlib
import json
from pathlib import Path
import sys
import time
from gemini_emotions import generate_image, MODEL
from gemini_pipeline_check import read_key

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/vs1b_story_art'


def main() -> int:
    jobs = json.loads((SOURCE / 'jobs.json').read_text())
    key = read_key(ROOT / '.env')
    if not key:
        print('Configured Gemini credential unavailable; no requests sent.')
        return 2
    for name in sys.argv[1:]:
        job = jobs[name]
        output = SOURCE / (name + '.png')
        if output.exists():
            print('Preserving existing', name, flush=True)
            continue
        refs = [(ROOT / p).read_bytes() for p in job['references']]
        record = {'job': name, 'model': MODEL, **job, 'reference_sha256': [hashlib.sha256(r).hexdigest() for r in refs]}
        refdir = SOURCE / 'references'
        refdir.mkdir(exist_ok=True)
        record['reference_snapshots'] = []
        for raw_ref in refs:
            snapshot = refdir / (hashlib.sha256(raw_ref).hexdigest() + '.png')
            if not snapshot.exists():
                snapshot.write_bytes(raw_ref)
            record['reference_snapshots'].append(str(snapshot.relative_to(ROOT)))
        started = time.monotonic()
        print('Generating', name, flush=True)
        try:
            raw = generate_image(key, job['prompt'], refs, job.get('aspect', '16:9'), '2K')
            output.write_bytes(raw)
            record['status'] = 'generated_pending_review'
            record['output_sha256'] = hashlib.sha256(raw).hexdigest()
        except Exception as error:
            record['status'] = 'failed'
            record['error'] = str(error).replace(key, '[REDACTED]')
        record['elapsed_seconds'] = round(time.monotonic() - started, 2)
        output.with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n')
        print(name, record['status'], record['elapsed_seconds'], flush=True)
        if record['status'] == 'failed':
            return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
