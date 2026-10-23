#!/usr/bin/env python3
"""Compare read-only reporter timelines from the real-input runs.
Usage: compare.py OUTPUT_DIR TESTED_SHA > results.json
"""
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])

def records(name):
    return [json.loads(line) for line in (root / (name + '.jsonl')).read_text().splitlines()]

def values(rows, kind):
    return [r['data'] for r in rows if r['kind'] == kind]

def exchanges(rows):
    result, start, rates = [], None, []
    for row in rows:
        if row['kind'] != 'state':
            continue
        s = row['data']
        if s['armed'] and start is None:
            start, rates = row['ms'], []
        if start is not None and (not rates or rates[-1]['speed'] != s['speed']):
            rates.append({'at_ms': row['ms'] - start, 'speed': s['speed']})
        if not s['armed'] and start is not None:
            result.append({'duration_ms': row['ms'] - start, 'rates': rates})
            start = None
    return result

def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

def hp_changes(rows):
    previous, result = {}, []
    for s in values(rows, 'state'):
        current = {u[0]: u[2] for u in s['units']}
        if previous:
            for uid in sorted(previous.keys() | current.keys()):
                if previous.get(uid) != current.get(uid):
                    result.append([uid, previous.get(uid), current.get(uid)])
        previous = current
    return result

out = {'tested_sha': sys.argv[2], 'routes': {}}
for route, count in [('map', 2), ('ill', 1), ('pop', 1)]:
    normal = records(route + '-normal')
    expected = values(normal, 'settled')
    # Movement/Wait also settles busy; retain those ordinary continuations.
    assert len(expected) >= count, (route, 'missing normal settles')
    result = {'normal': exchanges(normal), 'normal_settled_sha256': digest(expected),
              'normal_final_rng': values(normal, 'state')[-1]['rng'], 'comparisons': {}}
    for mode in ['hold', 'release']:
        rows = records(route + '-' + mode)
        states = values(rows, 'settled')
        contacts = values(rows, 'contact')
        final = values(rows, 'state')[-1]
        comparison = {
            'settle_count': len(states),
            'settled_sha256': digest(states),
            'final_rng': final['rng'],
            'entire_battle_roster_supports_equal': states == expected,
            'native_illustrated_contacts_equal': contacts == values(normal, 'contact'),
            'native_illustrated_contacts': contacts,
            'observed_hp_changes_equal': hp_changes(rows) == hp_changes(normal),
            'observed_hp_changes': hp_changes(rows),
            'exchanges': exchanges(rows),
            'final_rng_equal': final['rng'] == values(normal, 'state')[-1]['rng'],
            'final_speed': final['speed'],
            'final_time_scale': final['time_scale'],
            'final_ui_layer': final['ui_layer'],
        }
        assert len(states) == len(expected) and states == expected, (route, mode, 'outcome differs')
        assert comparison['native_illustrated_contacts_equal'] and comparison['observed_hp_changes_equal']
        assert comparison['final_rng_equal'] and final['speed'] == 1.0 and final['time_scale'] == 1.0
        assert len(comparison['exchanges']) == count
        assert not any(final[key] for key in ['busy', 'armed', 'cam', 'popup', 'stage']) and final['ui_layer']
        for index, span in enumerate(comparison['exchanges']):
            assert any(rate['speed'] == 2.0 for rate in span['rates']), 'held rate never activated'
            duration, normal_ms = span['duration_ms'], result['normal'][index]['duration_ms']
            if mode == 'hold':
                assert normal_ms * .32 < duration < normal_ms * .8, 'no visible speedup/motion'
            else:
                assert result['comparisons']['hold']['exchanges'][index]['duration_ms'] < duration < normal_ms + 150
                assert any(rate['speed'] == 1.0 and 0 < rate['at_ms'] < duration - 100 for rate in span['rates']), 'release did not restore pace mid-exchange'
        result['comparisons'][mode] = comparison
    out['routes'][route] = result
print(json.dumps(out, indent=2))
