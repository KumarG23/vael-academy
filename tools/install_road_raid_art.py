#!/usr/bin/env python3
"""Install explicitly selected VS-1B.5 paintings; no generation or portrait edits.
Pillow environment. Versions and exact reference snapshots stay in source folder.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/vs1b5_raid_art'


def main():
    selections = json.loads((SOURCE / 'selections.json').read_text())
    installed = []
    for name, job in selections['backdrops'].items():
        target = ROOT / 'assets/art/vn/painted' / (name + '.png')
        previous = hashlib.sha256(target.read_bytes()).hexdigest()
        Image.open(SOURCE / (job + '.png')).convert('RGB').save(target)
        installed.append({'output': str(target.relative_to(ROOT)), 'source': job,
                          'previous_sha256': previous,
                          'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    (SOURCE / 'installed.json').write_text(json.dumps(installed, indent=2) + '\n')

if __name__ == '__main__':
    main()
