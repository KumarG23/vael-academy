"""Deterministic GitHub discussion deltas. No model calls or dispatch authority.

Receipts contain identifiers/hashes, never comment bodies. Advance them only after
successful consumption (or a scan with no deltas). Automated posts are explicitly
marked, not guessed from a shared account's identity.
"""
import datetime
import hashlib
import json
import math
from pathlib import Path
import re
from urllib.parse import quote

AUTO_MARKER = '<!-- dev-studio:auto -->'


def _load(path):
    try:
        data = json.loads(Path(path).read_text())
        if (isinstance(data, dict) and data.get('version') == 1 and isinstance(data.get('entries'), dict)
                and all(type(data.get(key)) in (int, float) and math.isfinite(data[key])
                        for key in ('scanned_at', 'full_scan_at'))
                and all(isinstance(value, dict) and value.get('kind') in ('comment', 'inline', 'review')
                        and type(value.get('id')) is int and type(value.get('number')) is int
                        and isinstance(value.get('digest'), str) and type(value.get('auto')) is bool
                        for value in data['entries'].values())):
            return data
    except (OSError, ValueError):
        pass
    return None


def _pages(run, endpoint):
    data = json.loads(run('gh', 'api', '--paginate', '--slurp', endpoint))
    if not isinstance(data, list) or any(not isinstance(page, list) for page in data):
        raise ValueError('Expected complete paginated GitHub lists')
    return [row for page in data for row in page]


def collect(run, slug, issue_numbers, pr_numbers, receipt_path, now, refresh=3600):
    """Scan active/blocked issue comments and PR issue/inline/review discussions.

    First scan baselines old discussion history; the launcher's bootstrap/recovery
    pass owns initial plan review. Future replies/edits/removals produce deltas.
    Hourly full scans catch deletions and avoid reliance on incremental cursors.
    """
    previous = _load(receipt_path)
    targets = set(issue_numbers) | set(pr_numbers)
    old = previous['entries'] if previous else {}
    full = not previous or now < previous['scanned_at'] or now - previous['full_scan_at'] >= refresh
    query = ''
    if previous and not full:
        stamp = datetime.datetime.fromtimestamp(max(0, previous['scanned_at'] - 60), datetime.timezone.utc)
        query = '&since=' + quote(stamp.isoformat(), safe='')
    entries = {} if full else {k: v for k, v in old.items() if v.get('number') in targets}
    rows = []
    for kind, endpoint in [('comment', 'issues/comments'), ('inline', 'pulls/comments')]:
        for row in _pages(run, f'repos/{slug}/{endpoint}?per_page=100{query}'):
            if not isinstance(row, dict):
                raise ValueError('Malformed GitHub discussion')
            m = re.search(r'/(?:issues|pulls)/([1-9][0-9]*)$', row.get('issue_url') or row.get('pull_request_url') or '')
            if m:
                rows.append((kind, int(m[1]), row))
    # Reviews include submitted/dismissed state and editable bodies, not just comments.
    for number in sorted(set(pr_numbers)):
        for row in _pages(run, f'repos/{slug}/pulls/{number}/reviews?per_page=100'):
            if not isinstance(row, dict):
                raise ValueError('Malformed GitHub review')
            if row.get('state') != 'PENDING':
                rows.append(('review', number, row))
    for kind, number, row in rows:
        ident, body = row.get('id'), row.get('body') or ''
        if number not in targets or type(ident) is not int or ident <= 0 or not isinstance(body, str):
            continue
        key = f'{kind}:{ident}'
        # A marker only at the start avoids suppressing a human quoting a receipt.
        auto = body.lstrip().startswith(AUTO_MARKER)
        digest = hashlib.sha256(json.dumps([body, row.get('state'), row.get('commit_id'),
                                          row.get('path'), row.get('line')], sort_keys=True).encode()).hexdigest()
        entries[key] = {'number': number, 'kind': kind, 'id': ident, 'digest': digest, 'auto': auto}
    deltas = []
    if previous:
        for key, entry in entries.items():
            before = old.get(key)
            if not entry['auto'] and (before is None or before.get('digest') != entry['digest']):
                deltas.append({**entry, 'change': 'edited' if before else 'new'})
        if full:
            for key, entry in old.items():
                if key not in entries and entry.get('number') in targets and not entry.get('auto'):
                    deltas.append({**entry, 'change': 'removed'})
    deltas.sort(key=lambda d: (d['number'], d['kind'], d['id']))
    return {'deltas': deltas, 'baseline': previous is None, 'full_scan': full,
            'receipt': {'version': 1, 'entries': entries, 'scanned_at': now,
                        'full_scan_at': now if full else previous.get('full_scan_at', now)}}


def commit(path, observation):
    path = Path(path)
    tmp = path.with_suffix('.next')
    tmp.write_text(json.dumps(observation['receipt'], sort_keys=True))
    tmp.replace(path)


def delta_keys(observation):
    return sorted([d['kind'], d['id'], d['number'], d['digest'], d['change']]
                  for d in observation['deltas'])


def action_evidence(log):
    """Conservative native-tool evidence, not a claim of independently verified delivery."""
    counts = {'merge_commands': 0, 'review_commands': 0, 'dispatch_commands': 0, 'issue_commands': 0}
    terminal = False
    for line in Path(log).read_text(errors='replace').splitlines():
        try:
            record = json.loads(line)
        except ValueError:
            continue
        if not isinstance(record, dict):
            continue
        terminal |= record.get('type') == 'turn.completed'
        item = record.get('item') or {}
        if not isinstance(item, dict):
            continue
        if record.get('type') != 'item.completed' or item.get('type') != 'command_execution' or item.get('exit_code') != 0:
            continue
        command = item.get('command') or ''
        if not isinstance(command, str):
            continue
        for name, pattern in [('merge_commands', r'\bgh\s+pr\s+merge\b'),
                              ('review_commands', r'\bgh\s+pr\s+(comment|review)\b'),
                              ('dispatch_commands', r'team\.py\s+(start|handoff)\b'),
                              ('issue_commands', r'\bgh\s+issue\s+(create|edit|comment)\b')]:
            if re.search(pattern, command):
                counts[name] += 1
    return {'classification': 'action_commands_observed' if any(counts.values()) else
            'analysis_or_unclassified' if terminal else 'unknown',
            'provenance': 'native_successful_tool_commands_not_delivery_attestation', 'counts': counts}


def record_audit(path, *, log, run_id, trigger, reasons, before, acknowledged, finished_at, success):
    Path(path).write_text(json.dumps({'run_id': run_id, 'trigger': trigger,
        'wake_reasons': reasons, 'observed_before': before, 'acknowledged_after': acknowledged,
        'post_github_state': 'not_rescanned', 'completed_at': finished_at, 'success': success,
        'action_evidence': action_evidence(log)}, sort_keys=True))
