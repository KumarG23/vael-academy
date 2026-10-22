#!/usr/bin/env python3
"""Per-invocation usage telemetry for the native team launcher (stdlib only).

One shared implementation: ``team.py`` records live runs and scheduler polls here,
the historical importer reads existing native logs here, and a private dashboard
loads this same file to query/export. It is an analytics store, not a task ledger:
GitHub stays the only record of issues/PRs and this database is safe to delete.

Privacy contract: only allowlisted identifiers, enums, numbers and timestamps are
stored. Prompts, model output, tool payloads, raw log lines, exception text, file
paths, Git contents, account identifiers and credentials are never stored. Native
session IDs are stored only as a truncated one-way hash for grouping.

Unknown is NULL, never zero. Each usage figure carries its method/semantics.
"""
import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import sys
import time
import zoneinfo

SCHEMA_VERSION = 2
BUSY_TIMEOUT_MS = 5000
WRITE_ATTEMPTS = 8

PROVIDERS = ('codex', 'claude', 'agy', 'opencode')
ROUTES = {'codex': 'chatgpt_subscription', 'claude': 'claude_subscription',
          'agy': 'antigravity_signin', 'opencode': 'opencode_free'}
AGY_PROFILE_SCOPES = {
    'argon': 'agy_argon_weekly',
    'agy-flash': 'agy_gemini_shared',
    'agy-opus': 'agy_claude_gpt_oss_shared',
    'agy-sonnet': 'agy_claude_gpt_oss_shared',
    'agy-gpt-oss': 'agy_claude_gpt_oss_shared',
}
AGY_MODEL_SCOPES = {
    'gemini-4-argon-medium': 'agy_argon_weekly',
    'gemini-4-argon-high': 'agy_argon_weekly',
    'gemini-4-argon-low': 'agy_argon_weekly',
    'gemini-3.8-flash-medium': 'agy_gemini_shared',
    'gemini-3.8-flash-high': 'agy_gemini_shared',
    'gemini-3.8-flash-low': 'agy_gemini_shared',
    'claude-opus-5-5-medium': 'agy_claude_gpt_oss_shared',
    'claude-opus-5-5-high': 'agy_claude_gpt_oss_shared',
    'claude-opus-5-5-low': 'agy_claude_gpt_oss_shared',
    'claude-sonnet-5-5-medium': 'agy_claude_gpt_oss_shared',
    'claude-sonnet-5-5-high': 'agy_claude_gpt_oss_shared',
    'claude-sonnet-5-5-low': 'agy_claude_gpt_oss_shared',
    'gpt-oss-120b-medium': 'agy_claude_gpt_oss_shared',
}
QUOTA_SCOPES = (
    'chatgpt_subscription',
    'claude_subscription',
    'agy_argon_weekly',
    'agy_gemini_shared',
    'agy_claude_gpt_oss_shared',
    'antigravity_signin',
)
ROLES = ('lead', 'worker')
STATUSES = ('running', 'success', 'failed', 'interrupted', 'launch_error', 'unknown')
TRIGGERS = ('timer', 'manual_start', 'lead_dispatch', 'lead_handoff', 'handoff', 'operator', 'unknown')
CATEGORIES = ('lead_review', 'planning', 'lead_pass', 'implementation', 'qa', 'docs', 'bugfix', 'unknown')
ATTEMPTS = ('initial', 'retry', 'rework', 'handoff', 'lead')
FAILURE_KINDS = ('quota_exhausted', 'auth_failure', 'permission_failure', 'network_failure',
                 'execution_failure', 'interrupted', 'launch_error', 'entitlement_denied')
BLOCKED_REASONS = ('session_limit', 'usage_limit', 'rate_limit', 'quota_exceeded',
                   'subscription_preflight_failed', 'auth_error', 'permission_error',
                   'network_error', 'execution_error', 'interrupted_turn',
                   'unreported_exit', 'native_launch_failed', 'non_zero_exit', 'paid_credits_required')
RESET_PROVENANCES = ('provider_error_text', 'provider_error_field', 'provider_retry_after', 'unknown')
HANDOFF_KINDS = ('cross_provider_reassign', 'same_provider_reassign', 'same_owner_resume_after_cooldown')
QUOTA_DECISIONS = ('pending', 'wait', 'reassign', 'escalate', 'resumed')
POLL_OUTCOMES = ('paused', 'locked', 'lock_contention', 'deferred_workers_running',
                 'no_work_workers_running', 'dirty_checkout', 'no_wake_reason', 'unchanged',
                 'exhausted_empty_queue', 'quota_cooldown', 'error', 'preflight_failed',
                 'inference_success', 'inference_failed', 'unmatched_activation_unknown',
                 'no_inference_unrecorded', 'service_failed_unrecorded')
VERIFIED_ZERO_MODEL_OUTCOMES = (
    'paused', 'locked', 'lock_contention', 'deferred_workers_running',
    'no_work_workers_running', 'no_wake_reason', 'unchanged',
    'exhausted_empty_queue', 'quota_cooldown',
)
UNMATCHED_POLL_OUTCOMES = (
    'unmatched_activation_unknown', 'no_inference_unrecorded', 'service_failed_unrecorded',
)
MAX_JOURNAL_LAUNCH_WINDOW_SEC = 120.0
WAKE_REASONS = ('first pass', 'main', 'ready', 'prs', 'workers', 'quota', 'events', 'periodic refresh',
                'planning refresh', 'pending event')
EFFORTS = ('low', 'medium', 'high', 'xhigh', 'max', 'provider_default')
# Allowlisted identifier shapes. Anything else is stored/served as NULL.
MODEL_RE = re.compile(r'[A-Za-z0-9][A-Za-z0-9._:/-]{0,79}')
PROFILE_RE = re.compile(r'[a-z][a-z0-9_-]{0,31}')
VERSION_RE = re.compile(r'[0-9]{1,4}(?:\.[0-9]{1,6}){1,3}')
REPO_RE = re.compile(r'[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._-]{1,100}')
NATIVE_ID_RE = re.compile(r'[A-Za-z0-9_-]{8,100}')
WORKTREE_KEY_RE = re.compile(r'[a-z0-9][a-z0-9_-]{0,39}')
LOGICAL_TASK_RE = re.compile(r'[a-z0-9][a-z0-9_:#/-]{0,63}')
TZ_LABEL_RE = re.compile(r'[A-Za-z0-9_/+:-]{2,32}')
LOG_RE = re.compile(r'(lead|issue-([1-9][0-9]{0,8}))-([0-9]{16,20})\.log')

# Per-provider token conventions (documented evidence in the private audit):
#   codex    input includes cached reads; reasoning is a subset of output.
#   claude   input excludes cache read/creation; thinking is a subset of output.
#   agy      input excludes cache reads (total_tokens == input + output); the
#            relation of thinking to output and cumulative conversation summary
#            behavior are not formally documented by the provider -> flagged.
#   opencode per-step input excludes cache read/write (observed input < cache read);
#            reasoning can exceed output so it is NOT a subset of output.
# Normalized columns: input = ALL prompt tokens incl. cache, cached/cache_write are
# subsets of input, reasoning is reported alongside output. total = input + output.
SEMANTICS = {
    'codex': 'input_incl_cached;reasoning_subset_of_output',
    'claude': 'input_excl_cache_normalized;thinking_subset_of_output',
    'agy': 'cumulative_conversation_unconfirmed;input_excl_cache_normalized;thinking_relation_unknown',
    'opencode': 'input_excl_cache_normalized;reasoning_exceeds_output_not_subset',
}
USAGE_FIELDS = ('input_tokens', 'cached_input_tokens', 'cache_write_tokens', 'output_tokens', 'reasoning_tokens')


def now():
    return time.time()


def digest(*parts, size=32):
    return hashlib.sha256('\0'.join(str(p) for p in parts).encode()).hexdigest()[:size]


def session_key(provider, native_id):
    if not isinstance(native_id, str) or not NATIVE_ID_RE.fullmatch(native_id):
        return None
    return digest('session', provider, native_id, size=24)


session_key_for = session_key


def safe(value, pattern):
    return value if isinstance(value, str) and pattern.fullmatch(value) else None


def safe_enum(value, choices, default=None):
    return value if value in choices else default


def nonneg_int(value):
    if type(value) is int and 0 <= value < 10**15:
        return value
    if type(value) is float and math.isfinite(value) and 0 <= value < 1e15 and value == int(value):
        return int(value)
    return None


def nonneg_float(value):
    if type(value) in (int, float) and math.isfinite(value) and 0 <= value < 1e12:
        return float(value)
    return None


# ---------------------------------------------------------------------------
# Storage

MIGRATIONS = {1: '''
CREATE TABLE IF NOT EXISTS runs(
  run_id TEXT PRIMARY KEY,
  source_key TEXT NOT NULL UNIQUE,
  source_kind TEXT NOT NULL,
  parent_run_id TEXT,
  parent_provenance TEXT,
  session_key TEXT,
  role TEXT NOT NULL,
  profile TEXT,
  profile_provenance TEXT,
  provider TEXT,
  auth_route TEXT,
  requested_model TEXT,
  requested_model_source TEXT,
  resolved_model TEXT,
  resolved_model_provenance TEXT,
  effort TEXT,
  cli_version TEXT,
  repo TEXT,
  issue_number INTEGER,
  pr_number INTEGER,
  logical_task_id TEXT,
  worktree_key TEXT,
  task_category TEXT,
  attempt_kind TEXT,
  attempt_number INTEGER,
  trigger TEXT,
  wake_reasons TEXT,
  started_at REAL,
  finished_at REAL,
  duration_ms INTEGER,
  status TEXT NOT NULL,
  exit_code INTEGER,
  failure_kind TEXT,
  blocked_reason TEXT,
  quota_scope TEXT,
  reset_at REAL,
  reset_timezone TEXT,
  reset_provenance TEXT,
  handoff_from_run_id TEXT,
  handoff_from_profile TEXT,
  handoff_from_provider TEXT,
  handoff_from_session_key TEXT,
  handoff_kind TEXT,
  input_tokens INTEGER,
  cached_input_tokens INTEGER,
  cache_write_tokens INTEGER,
  output_tokens INTEGER,
  reasoning_tokens INTEGER,
  usage_method TEXT,
  usage_semantics TEXT,
  usage_note TEXT,
  native_turns INTEGER,
  tool_calls INTEGER,
  provider_requests INTEGER,
  provider_requests_source TEXT,
  compactions INTEGER,
  provider_cost_usd REAL,
  cost_basis TEXT,
  cum_json TEXT,
  updated_at REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS runs_started ON runs(started_at);
CREATE INDEX IF NOT EXISTS runs_session ON runs(session_key, started_at);
CREATE INDEX IF NOT EXISTS runs_issue ON runs(issue_number);
CREATE INDEX IF NOT EXISTS runs_logical_task ON runs(logical_task_id, started_at);
CREATE TABLE IF NOT EXISTS quota_events(
  event_id TEXT PRIMARY KEY,
  source_key TEXT NOT NULL UNIQUE,
  run_id TEXT,
  role TEXT NOT NULL,
  provider TEXT,
  profile TEXT,
  quota_scope TEXT,
  session_key TEXT,
  repo TEXT,
  issue_number INTEGER,
  pr_number INTEGER,
  logical_task_id TEXT,
  worktree_key TEXT,
  blocked_reason TEXT NOT NULL,
  observed_at REAL NOT NULL,
  reset_at REAL,
  reset_timezone TEXT,
  reset_provenance TEXT NOT NULL,
  decision TEXT,
  successor_run_id TEXT,
  successor_profile TEXT,
  successor_provider TEXT,
  successor_session_key TEXT,
  handoff_kind TEXT,
  handoff_at REAL,
  transfer_overhead_ms INTEGER,
  outcome TEXT
);
CREATE INDEX IF NOT EXISTS quota_events_at ON quota_events(observed_at);
CREATE INDEX IF NOT EXISTS quota_events_issue ON quota_events(issue_number, observed_at);
CREATE TABLE IF NOT EXISTS polls(
  poll_id TEXT PRIMARY KEY,
  source_key TEXT NOT NULL UNIQUE,
  source_kind TEXT NOT NULL,
  at REAL NOT NULL,
  outcome TEXT NOT NULL,
  reasons TEXT,
  duration_ms INTEGER,
  ai_launched INTEGER,
  run_id TEXT,
  lead_profile TEXT
);
CREATE INDEX IF NOT EXISTS polls_at ON polls(at);
CREATE TABLE IF NOT EXISTS github_items(
  repo TEXT NOT NULL,
  kind TEXT NOT NULL,
  number INTEGER NOT NULL,
  state TEXT,
  created_at REAL,
  closed_at REAL,
  merged_at REAL,
  head_issue INTEGER,
  linked_issues TEXT,
  category TEXT,
  PRIMARY KEY(repo, kind, number)
);
CREATE TABLE IF NOT EXISTS rate_cards(
  version TEXT NOT NULL,
  model TEXT NOT NULL,
  source TEXT NOT NULL,
  input_per_mtok REAL,
  cached_input_per_mtok REAL,
  cache_write_per_mtok REAL,
  output_per_mtok REAL,
  PRIMARY KEY(version, model)
);
CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT);
''',
    2: '''
CREATE TABLE IF NOT EXISTS polls_v2(
  poll_id TEXT PRIMARY KEY,
  source_key TEXT NOT NULL UNIQUE,
  source_kind TEXT NOT NULL,
  at REAL NOT NULL,
  outcome TEXT NOT NULL,
  reasons TEXT,
  duration_ms INTEGER,
  ai_launched INTEGER,
  run_id TEXT,
  lead_profile TEXT
);
INSERT OR REPLACE INTO polls_v2(poll_id, source_key, source_kind, at, outcome, reasons, duration_ms, ai_launched, run_id, lead_profile)
  SELECT poll_id, source_key, source_kind, at,
         CASE WHEN outcome = 'no_inference_unrecorded' THEN 'unmatched_activation_unknown' ELSE outcome END,
         reasons, duration_ms,
         CASE WHEN source_kind = 'import' AND run_id IS NULL THEN NULL ELSE ai_launched END,
         run_id, lead_profile
  FROM polls;
DROP TABLE polls;
ALTER TABLE polls_v2 RENAME TO polls;
CREATE INDEX IF NOT EXISTS polls_at ON polls(at);
'''}
SCHEMA = MIGRATIONS[1]


def connect(path, readonly=False):
    path = Path(path)
    if readonly:
        conn = sqlite3.connect('file:' + str(path) + '?mode=ro', uri=True, timeout=BUSY_TIMEOUT_MS / 1000,
                               isolation_level=None)
        conn.execute(f'PRAGMA busy_timeout={BUSY_TIMEOUT_MS}')
        conn.execute('PRAGMA query_only=1')
        conn.row_factory = sqlite3.Row
        return conn
    path.parent.mkdir(parents=True, exist_ok=True)
    old = os.umask(0o077)
    try:
        conn = sqlite3.connect(str(path), timeout=BUSY_TIMEOUT_MS / 1000, isolation_level=None)
    finally:
        os.umask(old)
    conn.row_factory = sqlite3.Row
    conn.execute(f'PRAGMA busy_timeout={BUSY_TIMEOUT_MS}')
    for attempt in range(WRITE_ATTEMPTS):
        try:
            mode = conn.execute('PRAGMA journal_mode=WAL').fetchone()[0].lower()
            break
        except sqlite3.OperationalError as error:
            if ('locked' not in str(error) and 'busy' not in str(error)) or attempt == WRITE_ATTEMPTS - 1:
                raise
            time.sleep(0.05 * (attempt + 1))
    if mode != 'wal':
        raise sqlite3.OperationalError('WAL unavailable')
    conn.execute('PRAGMA synchronous=NORMAL')
    migrate(conn)
    return conn


def write(conn, fn):
    """Bounded retry of one IMMEDIATE transaction; concurrent writers serialize."""
    for attempt in range(WRITE_ATTEMPTS):
        try:
            conn.execute('BEGIN IMMEDIATE')
            try:
                result = fn(conn)
                conn.execute('COMMIT')
                return result
            except BaseException:
                conn.execute('ROLLBACK')
                raise
        except sqlite3.OperationalError as error:
            if 'locked' not in str(error) and 'busy' not in str(error) or attempt == WRITE_ATTEMPTS - 1:
                raise
            time.sleep(0.05 * (attempt + 1))


def migrate(conn):
    def apply(c):
        version = c.execute('PRAGMA user_version').fetchone()[0]
        if version > SCHEMA_VERSION:
            raise sqlite3.DatabaseError('Analytics schema is newer than this code')
        for target in range(version + 1, SCHEMA_VERSION + 1):
            for statement in MIGRATIONS[target].split(';'):
                if statement.strip():
                    c.execute(statement)
            c.execute(f'PRAGMA user_version={target}')
    if conn.execute('PRAGMA user_version').fetchone()[0] != SCHEMA_VERSION:
        write(conn, apply)


RUN_COLUMNS = ('run_id', 'source_key', 'source_kind', 'parent_run_id', 'parent_provenance', 'session_key',
               'role', 'profile', 'profile_provenance', 'provider', 'auth_route', 'requested_model',
               'requested_model_source', 'resolved_model', 'resolved_model_provenance', 'effort',
               'cli_version', 'repo', 'issue_number', 'pr_number', 'logical_task_id', 'worktree_key',
               'task_category', 'attempt_kind', 'attempt_number', 'trigger', 'wake_reasons',
               'started_at', 'finished_at', 'duration_ms', 'status', 'exit_code',
               'failure_kind', 'blocked_reason', 'quota_scope', 'reset_at', 'reset_timezone',
               'reset_provenance', 'handoff_from_run_id', 'handoff_from_profile',
               'handoff_from_provider', 'handoff_from_session_key', 'handoff_kind',
               *USAGE_FIELDS, 'usage_method', 'usage_semantics', 'usage_note',
               'native_turns', 'tool_calls', 'provider_requests', 'provider_requests_source',
               'compactions', 'provider_cost_usd', 'cost_basis', 'cum_json')

QUOTA_EVENT_COLUMNS = ('event_id', 'source_key', 'run_id', 'role', 'provider', 'profile',
                       'quota_scope', 'session_key', 'repo', 'issue_number', 'pr_number',
                       'logical_task_id', 'worktree_key', 'blocked_reason', 'observed_at',
                       'reset_at', 'reset_timezone', 'reset_provenance', 'decision',
                       'successor_run_id', 'successor_profile', 'successor_provider',
                       'successor_session_key', 'handoff_kind', 'handoff_at',
                       'transfer_overhead_ms', 'outcome')


def upsert_run(conn, row):
    """Idempotent by source_key: re-recording/importing the same native log updates one row.

    A live 'running' row is never downgraded by a missing value: non-NULL known
    fields win over NULL in the incoming row.
    """
    row = {k: row.get(k) for k in RUN_COLUMNS}
    row['run_id'] = row['run_id'] or digest('run', row['source_key'])
    row['updated_at'] = now()
    cols = list(row)
    keep = ('run_id', 'source_key')
    updates = ', '.join(f'{c}=COALESCE(excluded.{c}, runs.{c})' if c not in keep else f'{c}=runs.{c}'
                        for c in cols)
    conn.execute(f'INSERT INTO runs({",".join(cols)}) VALUES({",".join("?" * len(cols))}) '
                 f'ON CONFLICT(source_key) DO UPDATE SET {updates}', [row[c] for c in cols])
    return conn.execute('SELECT run_id FROM runs WHERE source_key=?', (row['source_key'],)).fetchone()[0]


def upsert_quota_event(conn, event):
    event = {k: event.get(k) for k in QUOTA_EVENT_COLUMNS}
    event['event_id'] = event['event_id'] or digest('quota_event', event['source_key'])
    cols = list(event)
    keep = ('event_id', 'source_key')
    updates = ', '.join(f'{c}=COALESCE(excluded.{c}, quota_events.{c})' if c not in keep else f'{c}=quota_events.{c}'
                        for c in cols)
    conn.execute(f'INSERT INTO quota_events({",".join(cols)}) VALUES({",".join("?" * len(cols))}) '
                 f'ON CONFLICT(source_key) DO UPDATE SET {updates}', [event[c] for c in cols])
    return conn.execute('SELECT event_id FROM quota_events WHERE source_key=?', (event['source_key'],)).fetchone()[0]


def upsert_poll(conn, poll):
    cols = ('poll_id', 'source_key', 'source_kind', 'at', 'outcome', 'reasons', 'duration_ms',
            'ai_launched', 'run_id', 'lead_profile')
    poll = {c: poll.get(c) for c in cols}
    poll['poll_id'] = poll['poll_id'] or digest('poll', poll['source_key'])
    conn.execute(f'INSERT INTO polls({",".join(cols)}) VALUES({",".join("?" * len(cols))}) '
                 'ON CONFLICT(source_key) DO UPDATE SET ' +
                 ', '.join(f'{c}=excluded.{c}' for c in cols if c not in ('poll_id', 'source_key')),
                 [poll[c] for c in cols])


# ---------------------------------------------------------------------------
# Native output parsing, quota/error classification and reset parsing.

_TZ_OFFSETS = {
    'UTC': ('UTC', datetime.timezone.utc),
    'GMT': ('GMT', datetime.timezone.utc),
    'EDT': ('EDT', datetime.timezone(datetime.timedelta(hours=-4))),
    'EST': ('EST', datetime.timezone(datetime.timedelta(hours=-5))),
    'CDT': ('CDT', datetime.timezone(datetime.timedelta(hours=-5))),
    'CST': ('CST', datetime.timezone(datetime.timedelta(hours=-6))),
    'MDT': ('MDT', datetime.timezone(datetime.timedelta(hours=-6))),
    'MST': ('MST', datetime.timezone(datetime.timedelta(hours=-7))),
    'PDT': ('PDT', datetime.timezone(datetime.timedelta(hours=-7))),
    'PST': ('PST', datetime.timezone(datetime.timedelta(hours=-8))),
}
_MONTHS = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
           'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12}
_ISO_RESET_RE = re.compile(
    r'(?i)\b(?:resets?|try again|retry|available)\s+(?:at\s+|after\s+|on\s+)?'
    r'(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2})?(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}))'
)
_CLOCK_RESET_RE = re.compile(
    r'(?i)\b(?:resets?|try again|available)\s+(?:at\s+|on\s+)?'
    r'(?:(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2}),?\s+)?'
    r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*'
    r'(?:\(([A-Za-z0-9_/+:-]{2,32})\)|\b(UTC|GMT|EDT|EST|CDT|CST|MDT|MST|PDT|PST|Eastern|Pacific|Central|Mountain|[A-Za-z]+/[A-Za-z_]+)\b)'
)
_REL_RESET_RE = re.compile(
    r'(?i)\b(?:resets?\s+in|try again in|retry after)\s+'
    r'(?:(\d+)\s*h(?:ours?|r)?\s*)?(?:(\d+)\s*m(?:in(?:ute)?s?)?\s*)?(?:(\d+)\s*s(?:ec(?:ond)?s?)?)?\b'
)


def _resolve_tz(label):
    if not isinstance(label, str) or not label.strip():
        return None, None
    clean = label.strip().strip('()')
    upper = clean.upper()
    if upper in _TZ_OFFSETS:
        return _TZ_OFFSETS[upper]
    alias = {'EASTERN': 'America/New_York', 'PACIFIC': 'America/Los_Angeles',
             'CENTRAL': 'America/Chicago', 'MOUNTAIN': 'America/Denver'}.get(upper)
    target = alias or clean
    if re.fullmatch(r'[+-]\d{2}:?\d{2}', target):
        sign = -1 if target[0] == '-' else 1
        digits = target[1:].replace(':', '')
        offset = datetime.timedelta(hours=sign * int(digits[:2]), minutes=sign * int(digits[2:4]))
        return target, datetime.timezone(offset)
    try:
        return target, zoneinfo.ZoneInfo(target)
    except (KeyError, ValueError, zoneinfo.ZoneInfoNotFoundError):
        return None, None


def parse_reset_info(payload=None, text=None, reference_ts=None):
    """Extract (reset_at, reset_timezone, reset_provenance) when actually reported.

    Never fabricates a reset time or timezone: unknown stays (None, None, 'unknown').
    """
    ref = nonneg_float(reference_ts) or now()
    if isinstance(payload, dict):
        for field in ('reset_at', 'resets_at', 'eligible_after', 'quota_reset_at', 'rate_limit_reset_at'):
            val = payload.get(field)
            if type(val) in (int, float) and math.isfinite(val) and 1e9 <= val < 1e12:
                tz_label, _ = _resolve_tz(payload.get('reset_timezone') or payload.get('timezone') or 'UTC')
                return float(val), (tz_label or 'UTC'), 'provider_error_field'
            if isinstance(val, str) and len(val) <= 48:
                try:
                    iso = val.strip()
                    if iso.endswith('Z'):
                        dt_val = datetime.datetime.fromisoformat(iso[:-1] + '+00:00')
                        return dt_val.timestamp(), 'UTC', 'provider_error_field'
                    dt_val = datetime.datetime.fromisoformat(iso)
                    if dt_val.tzinfo is not None:
                        tz_name = safe(payload.get('reset_timezone') or dt_val.tzname() or 'UTC', TZ_LABEL_RE) or 'UTC'
                        return dt_val.timestamp(), tz_name, 'provider_error_field'
                except ValueError:
                    pass
        for field in ('retry_after', 'retry_after_seconds', 'reset_in_seconds'):
            sec = nonneg_float(payload.get(field))
            if sec is not None and 0 < sec <= 30 * 86400 and reference_ts is not None:
                return float(ref + sec), 'UTC', 'provider_retry_after'
    blob = text if isinstance(text, str) else ''
    if not blob and isinstance(payload, dict):
        parts = []
        for k in ('result', 'message', 'error', 'detail', 'reason'):
            v = payload.get(k)
            if isinstance(v, str):
                parts.append(v)
            elif isinstance(v, dict):
                for sk in ('message', 'detail', 'reason', 'reset_at', 'resets_at'):
                    if isinstance(v.get(sk), str):
                        parts.append(v[sk])
        blob = ' | '.join(parts)
    if blob:
        m = _ISO_RESET_RE.search(blob)
        if m:
            iso = m.group(1).strip()
            try:
                if iso.endswith('Z'):
                    dt_val = datetime.datetime.fromisoformat(iso[:-1] + '+00:00')
                    return dt_val.timestamp(), 'UTC', 'provider_error_text'
                dt_val = datetime.datetime.fromisoformat(iso)
                if dt_val.tzinfo is not None:
                    tz_name = safe(dt_val.tzname() or 'UTC', TZ_LABEL_RE) or 'UTC'
                    return dt_val.timestamp(), tz_name, 'provider_error_text'
            except ValueError:
                pass
        m = _CLOCK_RESET_RE.search(blob)
        if m:
            mon_s, day_s, hour_s, min_s, ampm, tz_paren, tz_word = m.groups()
            tz_label, tz_obj = _resolve_tz(tz_paren or tz_word)
            if tz_obj is not None:
                hour = int(hour_s)
                minute = int(min_s or '0')
                if ampm:
                    ampm_l = ampm.lower()
                    if not (1 <= hour <= 12 and 0 <= minute < 60):
                        return None, None, 'unknown'
                    if ampm_l == 'pm' and hour != 12:
                        hour += 12
                    elif ampm_l == 'am' and hour == 12:
                        hour = 0
                elif not (0 <= hour <= 23 and 0 <= minute < 60):
                    return None, None, 'unknown'
                ref_dt = datetime.datetime.fromtimestamp(ref, tz=tz_obj)
                year = ref_dt.year
                if mon_s and day_s:
                    month = _MONTHS[mon_s.lower()[:3]]
                    day = int(day_s)
                    try:
                        cand = datetime.datetime(year, month, day, hour, minute, 0, tzinfo=tz_obj)
                    except ValueError:
                        return None, None, 'unknown'
                    if cand.timestamp() < ref - 180 * 86400:
                        cand = cand.replace(year=year + 1)
                else:
                    cand = ref_dt.replace(hour=hour, minute=minute, second=0, microsecond=0)
                    if cand.timestamp() < ref - 60:
                        cand += datetime.timedelta(days=1)
                return cand.timestamp(), safe(tz_label, TZ_LABEL_RE), 'provider_error_text'
        if reference_ts is not None:
            m = _REL_RESET_RE.search(blob)
            if m and any(m.groups()):
                hrs = int(m.group(1) or 0)
                mins = int(m.group(2) or 0)
                secs = int(m.group(3) or 0)
                delta = hrs * 3600 + mins * 60 + secs
                if 0 < delta <= 30 * 86400:
                    return float(ref + delta), 'UTC', 'provider_error_text'
    return None, None, 'unknown'


_QUOTA_SESSION_RE = re.compile(r"(?i)\b(?:hit your session limit|session[ _-]limit(?:[ _-]reached|[ _-]exceeded)?|five[- ]hour.*limit)\b")
_QUOTA_USAGE_RE = re.compile(r"(?i)\b(?:hit your (?:usage|weekly|daily|monthly) limit|usage[ _-]limit(?:[ _-]reached|[ _-]exceeded)?|weekly[ _-]limit|allowance[ _-]exhausted)\b")
_QUOTA_RATE_RE = re.compile(r"(?i)\b(?:rate[ _-]limit(?:[ _-]error|[ _-]exceeded|[ _-]reached)?|too many requests|429\s+too many requests)\b")
_QUOTA_EXCEEDED_RE = re.compile(r"(?i)\b(?:quota[ _-]exceeded|(?:individual )?quota reached|insufficient[ _-]quota|resource[ _-]exhausted|billing[ _-]hard[ _-]limit|credit balance is too low)\b")
# Model/plan entitlement denials are not quota: no reset, never retried or credit-upgraded.
_ENTITLEMENT_RE = re.compile(r"(?i)(?:requires usage credits|model_requires_usage_credits|not (?:available|included) (?:on|in) your (?:plan|subscription))")
_AUTH_ERROR_RE = re.compile(r"(?i)\b(?:authentication[ _-](?:error|failed)|invalid[ _-]api[ _-]key|not logged in|login required|unauthorized|unauthenticated|expired[ _-]token)\b")
_PERM_ERROR_RE = re.compile(r"(?i)\b(?:permission[ _-]denied|access[ _-]denied|forbidden|sandbox[ _-]violation|approval[ _-]rejected)\b")
_NET_ERROR_RE = re.compile(r"(?i)\b(?:connection (?:refused|reset|closed|timed out)|network (?:error|unreachable)|econnrefused|econnreset|etimedout|enotfound|dns[ _-](?:error|lookup)|stream disconnected)\b")


def _classify_error_envelope(payload, text='', reference_ts=None):
    """Classify one terminal provider error envelope into structured allowlisted enums."""
    code_tokens = []
    status_code = None
    if isinstance(payload, dict):
        for k in ('api_error', 'code', 'error_code', 'reason', 'subtype', 'status', 'terminal_reason'):
            v = payload.get(k)
            if isinstance(v, str):
                code_tokens.append(v.lower())
            elif type(v) is int:
                status_code = v
        if type(payload.get('api_error_status')) is int:
            status_code = payload['api_error_status']
        err = payload.get('error')
        if isinstance(err, dict):
            for k in ('code', 'type', 'reason', 'status'):
                v = err.get(k)
                if isinstance(v, str):
                    code_tokens.append(v.lower())
                elif type(v) is int and status_code is None:
                    status_code = v
            if not text and isinstance(err.get('message'), str):
                text = err['message']
        elif isinstance(err, str) and not text:
            text = err
        if not text:
            for k in ('result', 'message', 'detail'):
                if isinstance(payload.get(k), str):
                    text = payload[k]
                    break
    blob = (text or '').strip()
    codes = ' '.join(code_tokens)
    is_ordinary_exec = 'error_during_execution' in code_tokens or 'tool_error' in code_tokens
    if _ENTITLEMENT_RE.search(blob) or _ENTITLEMENT_RE.search(codes):
        return {'failure_kind': 'entitlement_denied', 'blocked_reason': 'paid_credits_required',
                'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
    if not is_ordinary_exec:
        reason = None
        if _QUOTA_SESSION_RE.search(blob) or 'session_limit' in codes:
            reason = 'session_limit'
        elif _QUOTA_USAGE_RE.search(blob) or 'usage_limit_reached' in codes or 'usage_limit' in codes:
            reason = 'usage_limit'
        elif _QUOTA_EXCEEDED_RE.search(blob) or any(x in codes for x in ('quota_exceeded', 'insufficient_quota', 'resource_exhausted')):
            reason = 'quota_exceeded'
        elif _QUOTA_RATE_RE.search(blob) or status_code == 429 or any(x in codes for x in ('rate_limit_error', 'rate_limit_exceeded', 'rate_limit')):
            reason = 'rate_limit'
        if reason is not None:
            reset_at, reset_tz, reset_prov = parse_reset_info(payload, blob, reference_ts=reference_ts)
            return {'failure_kind': 'quota_exhausted', 'blocked_reason': reason,
                    'reset_at': reset_at, 'reset_timezone': reset_tz, 'reset_provenance': reset_prov}
    if status_code == 401 or _AUTH_ERROR_RE.search(blob) or any(x in codes for x in ('authentication_error', 'unauthorized', 'unauthenticated')):
        return {'failure_kind': 'auth_failure', 'blocked_reason': 'auth_error',
                'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
    if status_code == 403 or _PERM_ERROR_RE.search(blob) or any(x in codes for x in ('permission_denied', 'forbidden')):
        return {'failure_kind': 'permission_failure', 'blocked_reason': 'permission_error',
                'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
    if _NET_ERROR_RE.search(blob) or any(x in codes for x in ('network_error', 'connection_error', 'timeout')):
        return {'failure_kind': 'network_failure', 'blocked_reason': 'network_error',
                'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
    return {'failure_kind': 'execution_failure', 'blocked_reason': 'execution_error',
            'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}


def classify_native_failure(provider, lines, exit_code=None, reference_ts=None, now_ts=None):
    """Distinguish terminal provider quota/rate/session limits from ordinary failures.

    Intermediate repaired tool errors (e.g. a failed command in `item.completed`
    followed by `turn.completed`) are never treated as failures or quota limits.
    """
    if reference_ts is None and now_ts is not None:
        reference_ts = now_ts
    items = list(lines or [])
    if items and all(isinstance(x, dict) for x in items):
        records = items
        raw_tail = ''
    else:
        str_lines = [str(x) for x in items]
        records = list(json_records(str_lines))
        raw_tail = '\n'.join(str_lines[-8:]) if str_lines else ''
    if 'subscription preflight failed' in raw_tail or 'subscription login required' in raw_tail:
        return {'is_failed': True, 'failure_kind': 'auth_failure',
                'blocked_reason': 'subscription_preflight_failed',
                'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
    if 'Native launch failed:' in raw_tail:
        return {'is_failed': True, 'failure_kind': 'launch_error',
                'blocked_reason': 'native_launch_failed',
                'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
    if provider == 'codex':
        terminals = [r for r in records if r.get('type') in ('turn.completed', 'turn.failed')]
        if terminals and terminals[-1].get('type') == 'turn.completed' and not exit_code:
            return {'is_failed': False, 'failure_kind': None, 'blocked_reason': None,
                    'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
        err_records = [r for r in records if r.get('type') in ('turn.failed', 'error')]
        if err_records:
            info = _classify_error_envelope(err_records[-1], reference_ts=reference_ts)
            return {'is_failed': True, **info}
        if not terminals and exit_code is None:
            return {'is_failed': True, 'failure_kind': 'interrupted',
                    'blocked_reason': 'interrupted_turn' if records else 'unreported_exit',
                    'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
        return {'is_failed': True, 'failure_kind': 'execution_failure',
                'blocked_reason': 'non_zero_exit' if exit_code else 'execution_error',
                'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
    if provider == 'claude':
        results = [r for r in records if r.get('type') == 'result']
        if results:
            last = results[-1]
            if last.get('is_error') is False and last.get('subtype') == 'success' and not exit_code:
                return {'is_failed': False, 'failure_kind': None, 'blocked_reason': None,
                        'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
            info = _classify_error_envelope(last, reference_ts=reference_ts)
            if last.get('permission_denials') and info['failure_kind'] == 'execution_failure':
                info['failure_kind'] = 'permission_failure'
                info['blocked_reason'] = 'permission_error'
            return {'is_failed': True, **info}
        if exit_code is None:
            return {'is_failed': True, 'failure_kind': 'interrupted',
                    'blocked_reason': 'unreported_exit',
                    'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
        return {'is_failed': True, 'failure_kind': 'execution_failure',
                'blocked_reason': 'non_zero_exit',
                'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
    if provider == 'agy':
        terminal = records[-1] if records else None
        if terminal is not None:
            if terminal.get('status') == 'SUCCESS' and not exit_code:
                return {'is_failed': False, 'failure_kind': None, 'blocked_reason': None,
                        'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
            info = _classify_error_envelope(terminal, reference_ts=reference_ts)
            if info['failure_kind'] == 'execution_failure':
                # agy also prints a structured `AGY_ERROR: {...}` stderr envelope
                # (status/error_code); use it when the terminal text is unspecific.
                for line in reversed(raw_tail.splitlines()):
                    if line.startswith('AGY_ERROR: '):
                        try:
                            env = json.loads(line[len('AGY_ERROR: '):])
                        except ValueError:
                            break
                        if isinstance(env, dict):
                            alt = _classify_error_envelope(env, reference_ts=reference_ts)
                            if alt['failure_kind'] != 'execution_failure':
                                info = alt
                        break
            return {'is_failed': True, **info}
        if exit_code is None:
            return {'is_failed': True, 'failure_kind': 'interrupted',
                    'blocked_reason': 'unreported_exit',
                    'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
        return {'is_failed': True, 'failure_kind': 'execution_failure',
                'blocked_reason': 'non_zero_exit',
                'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
    if provider == 'opencode':
        errs = [r for r in records if r.get('type') == 'error']
        if errs:
            last_err = errs[-1]
            part = last_err.get('part') if isinstance(last_err.get('part'), dict) else {}
            merged = dict(part, **{k: v for k, v in last_err.items() if k != 'part'})
            info = _classify_error_envelope(merged, reference_ts=reference_ts)
            return {'is_failed': True, **info}
        if records and records[-1].get('type') == 'text' and (records[-1].get('part') or {}).get('text') and not exit_code:
            return {'is_failed': False, 'failure_kind': None, 'blocked_reason': None,
                    'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
        if not records and exit_code is None:
            return {'is_failed': True, 'failure_kind': 'interrupted',
                    'blocked_reason': 'unreported_exit',
                    'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
        return {'is_failed': True, 'failure_kind': 'execution_failure',
                'blocked_reason': 'non_zero_exit' if exit_code else 'execution_error',
                'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}
    return {'is_failed': bool(exit_code), 'failure_kind': 'execution_failure' if exit_code else None,
            'blocked_reason': 'non_zero_exit' if exit_code else None,
            'reset_at': None, 'reset_timezone': None, 'reset_provenance': None}


def json_records(lines):
    for line in lines:
        if isinstance(line, dict):
            yield line
            continue
        try:
            value = json.loads(line)
        except (ValueError, TypeError):
            continue  # Native stderr warnings interleave with JSON; never stored.
        if isinstance(value, dict):
            yield value


def _usage(input_tokens=None, cached=None, cache_write=None, output=None, reasoning=None):
    return {'input_tokens': input_tokens, 'cached_input_tokens': cached, 'cache_write_tokens': cache_write,
            'output_tokens': output, 'reasoning_tokens': reasoning}


def _sum(*values):
    values = [nonneg_int(v) for v in values]
    return None if any(v is None for v in values) else sum(values)


def parse_native(provider, lines):
    """Return whitelisted facts from one native invocation's stdout/stderr log.

    Keys: session_id (raw, caller hashes it), terminal ('success'|'failed'|None),
    usage (per-invocation, opencode or claude fallback), cumulative (session-cumulative
    snapshot for codex/claude/agy), turns, tool_calls, cost_usd/cost_basis, models.
    """
    out = {'session_id': None, 'terminal': None, 'usage': None, 'cumulative': None, 'turns': None,
           'tool_calls': None, 'cost_usd': None, 'cost_basis': None, 'models': {}, 'requests': None,
           'records': 0, 'usage_method': None}
    records = list(json_records(lines))
    out['records'] = len(records)
    if provider == 'codex':
        tools = 0
        for r in records:
            t = r.get('type')
            if t == 'thread.started' and out['session_id'] is None:
                out['session_id'] = r.get('thread_id')
            elif t == 'item.completed' and isinstance(r.get('item'), dict) and \
                    r['item'].get('type') in ('command_execution', 'file_change', 'mcp_tool_call', 'web_search'):
                tools += 1
            elif t in ('turn.completed', 'turn.failed'):
                out['terminal'] = 'success' if t == 'turn.completed' else 'failed'
                u = r.get('usage')
                if t == 'turn.completed' and isinstance(u, dict):
                    # Thread-cumulative across `exec resume` (verified on recorded logs).
                    out['cumulative'] = _usage(nonneg_int(u.get('input_tokens')), nonneg_int(u.get('cached_input_tokens')),
                                               nonneg_int(u.get('cache_write_input_tokens')),
                                               nonneg_int(u.get('output_tokens')),
                                               nonneg_int(u.get('reasoning_output_tokens')))
        out['tool_calls'] = tools if records else None
        if records and out['terminal'] is None and any(r.get('type') == 'error' for r in records):
            out['terminal'] = 'failed'
    elif provider == 'claude':
        results = [r for r in records if r.get('type') == 'result']
        for r in records:
            if isinstance(r.get('session_id'), str):
                out['session_id'] = r['session_id']
                break
        if results:
            r = results[-1]
            out['terminal'] = 'success' if r.get('is_error') is False and r.get('subtype') == 'success' else 'failed'
            mu = r.get('modelUsage')
            if isinstance(mu, dict) and mu:
                # modelUsage/total_cost_usd are session-cumulative across --resume and
                # already include any subagent/background usage of this session.
                totals = dict.fromkeys(USAGE_FIELDS, 0)
                cost = 0.0
                bases = set()
                for model, v in mu.items():
                    if not isinstance(v, dict):
                        totals = None
                        break
                    inp = nonneg_int(v.get('inputTokens'))
                    cr = nonneg_int(v.get('cacheReadInputTokens'))
                    cc = nonneg_int(v.get('cacheCreationInputTokens'))
                    o = nonneg_int(v.get('outputTokens'))
                    th = nonneg_int(v.get('thinkingTokens'))
                    if inp is None or o is None:
                        totals = None
                        break
                    cr_val = cr or 0
                    cc_val = cc or 0
                    totals['input_tokens'] += inp + cr_val + cc_val
                    totals['cached_input_tokens'] = None if cr is None and totals['cached_input_tokens'] is None else (totals['cached_input_tokens'] or 0) + cr_val
                    totals['cache_write_tokens'] = None if cc is None and totals['cache_write_tokens'] is None else (totals['cache_write_tokens'] or 0) + cc_val
                    totals['output_tokens'] += o
                    totals['reasoning_tokens'] = None if th is None or totals['reasoning_tokens'] is None else totals['reasoning_tokens'] + th
                    c = nonneg_float(v.get('costUSD'))
                    cost = None if c is None or cost is None else cost + c
                    if v.get('costBasis'):
                        bases.add(v.get('costBasis'))
                    if safe(model, MODEL_RE):
                        out['models'][model] = 'cli_model_usage'
                out['cumulative'] = totals
                if cost is not None and (not bases or bases == {'list'}):
                    out['cumulative_cost'] = cost
                    out['cost_basis'] = 'claude_cli_list_price_estimate'
            if out.get('cumulative_cost') is None:
                top_cost = nonneg_float(r.get('total_cost_usd'))
                if top_cost is not None and (out['cumulative'] is not None or top_cost > 0):
                    out['cumulative_cost'] = top_cost
                    out['cost_basis'] = 'claude_cli_list_price_estimate'
            # When modelUsage is absent/empty (e.g. 0-token immediate 429 session limit or
            # per-run usage-only fixture), use per-run `usage` without ever adding both.
            u = r.get('usage')
            if out['cumulative'] is None and isinstance(u, dict):
                inp = nonneg_int(u.get('input_tokens'))
                cr = nonneg_int(u.get('cache_read_input_tokens'))
                cc = nonneg_int(u.get('cache_creation_input_tokens'))
                o = nonneg_int(u.get('output_tokens'))
                details = u.get('output_tokens_details') if isinstance(u.get('output_tokens_details'), dict) else {}
                th = nonneg_int(details.get('thinking_tokens'))
                if th is None:
                    th = nonneg_int(u.get('thinking_tokens'))
                if inp is not None and o is not None:
                    out['usage'] = _usage(inp + (cr or 0) + (cc or 0), cr, cc, o, th)
                    out['usage_method'] = 'per_run_usage'
            out['turns_cumulative'] = None
            out['turns'] = nonneg_int(r.get('num_turns'))  # turns of the final result segment
    elif provider == 'agy':
        terminal = records[-1] if records else None
        if terminal is not None:
            out['terminal'] = 'success' if terminal.get('status') == 'SUCCESS' else 'failed'
            out['session_id'] = terminal.get('conversation_id')
            u = terminal.get('usage')
            if isinstance(u, dict):
                inp, cr = nonneg_int(u.get('input_tokens')), nonneg_int(u.get('cache_read_tokens'))
                out['cumulative'] = _usage((inp + (cr or 0)) if inp is not None else None, cr, None,
                                           nonneg_int(u.get('output_tokens')),
                                           nonneg_int(u.get('thinking_tokens')))
            out['turns_cumulative'] = nonneg_int(terminal.get('num_turns'))
            for key in ('model', 'resolved_model'):
                mval = safe(terminal.get(key), MODEL_RE)
                if mval:
                    out['models'][mval] = 'provider_response_model_field'
    elif provider == 'opencode':
        steps = 0
        total = dict.fromkeys(USAGE_FIELDS, 0)
        cost = 0.0
        tools = 0
        for r in records:
            if out['session_id'] is None and isinstance(r.get('sessionID'), str):
                out['session_id'] = r['sessionID']
            t = r.get('type')
            part = r.get('part') if isinstance(r.get('part'), dict) else {}
            if t == 'tool_use':
                tools += 1
            if t == 'step_finish':
                steps += 1
                tok = part.get('tokens') if isinstance(part.get('tokens'), dict) else {}
                cache = tok.get('cache') if isinstance(tok.get('cache'), dict) else {}
                inp, rd, wr = nonneg_int(tok.get('input')), nonneg_int(cache.get('read')), nonneg_int(cache.get('write'))
                o, rs = nonneg_int(tok.get('output')), nonneg_int(tok.get('reasoning'))
                step_inp = (inp + (rd or 0) + (wr or 0)) if inp is not None else None
                step = _usage(step_inp, rd, wr, o, rs)
                for k in USAGE_FIELDS:
                    total[k] = None if total[k] is None or step[k] is None else total[k] + step[k]
                c = nonneg_float(part.get('cost'))
                cost = None if c is None or cost is None else cost + c
        if any(r.get('type') == 'error' for r in records):
            out['terminal'] = 'failed'
        elif records and records[-1].get('type') == 'text' and (records[-1].get('part') or {}).get('text'):
            out['terminal'] = 'success'
        elif records:
            out['terminal'] = 'failed'
        if steps:
            out['usage'] = total
            out['usage_method'] = 'per_step_sum'
            out['requests'] = steps  # one step_finish per model call
            out['cost_usd'] = cost
            out['cost_basis'] = 'opencode_reported' if cost is not None else None
        out['tool_calls'] = tools if records else None
    if not NATIVE_ID_RE.fullmatch(out['session_id'] or ''):
        out['session_id'] = None
    return out


def iso_ts(value):
    if not isinstance(value, str):
        return nonneg_float(value)
    try:
        return datetime.datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()
    except ValueError:
        return None


class NativeSessions:
    """Optional read-only enrichment from native session stores.

    Only session transcripts are read (never auth/config files). Per record,
    only allowlisted fields are inspected: timestamps, model names, effort,
    CLI version, request/response IDs and token counts.
    """

    def __init__(self, codex_root=None, claude_root=None):
        self.codex_root = Path(codex_root) if codex_root else None
        self.claude_root = Path(claude_root) if claude_root else None
        self._cache = {}

    def _find(self, root, pattern):
        if root is None or not root.is_dir():
            return []
        return sorted(p for p in root.rglob(pattern) if p.is_file() and not p.is_symlink())

    def codex(self, thread_id):
        key = ('codex', thread_id)
        if key in self._cache:
            return self._cache[key]
        info = None
        if NATIVE_ID_RE.fullmatch(thread_id or ''):
            files = self._find(self.codex_root, f'rollout-*{thread_id}.jsonl')
            if files:
                info = {'cli_version': None, 'turns': {}, 'compactions': []}
                for f in files:
                    with f.open(errors='replace') as handle:
                        for r in json_records(handle):
                            t = r.get('type')
                            p = r.get('payload') if isinstance(r.get('payload'), dict) else {}
                            ts = iso_ts(r.get('timestamp'))
                            if t == 'session_meta':
                                info['cli_version'] = safe(p.get('cli_version'), VERSION_RE)
                            elif t == 'turn_context':
                                turn = info['turns'].setdefault(p.get('turn_id') or f'ctx-{ts}', {'start': ts})
                                turn['model'] = safe(p.get('model'), MODEL_RE)
                                turn['effort'] = safe_enum(p.get('effort'), EFFORTS)
                            elif t == 'event_msg' and p.get('type') == 'task_started' and isinstance(p.get('turn_id'), str):
                                turn = info['turns'].setdefault(p['turn_id'], {})
                                turn['start'] = nonneg_float(p.get('started_at')) or ts
                            elif t == 'token_usage_record' and isinstance(p.get('response_id'), str):
                                tid = p.get('root_turn_id') or p.get('turn_id')
                                turn = info['turns'].setdefault(tid, {})
                                responses = turn.setdefault('responses', {})
                                u = p.get('usage') if isinstance(p.get('usage'), dict) else {}
                                responses[p['response_id']] = _usage(
                                    nonneg_int(u.get('input_tokens')), nonneg_int(u.get('cached_input_tokens')),
                                    nonneg_int(u.get('cache_write_input_tokens')), nonneg_int(u.get('output_tokens')),
                                    nonneg_int(u.get('reasoning_output_tokens')))
                                turn.setdefault('first_ts', ts)
                            elif t == 'compacted' and ts is not None:
                                info['compactions'].append(ts)
        self._cache[key] = info
        return info

    def claude(self, session_id):
        key = ('claude', session_id)
        if key in self._cache:
            return self._cache[key]
        info = None
        if NATIVE_ID_RE.fullmatch(session_id or ''):
            files = self._find(self.claude_root, f'{session_id}.jsonl')
            if files:
                info = {'requests': {}}
                for f in files:
                    with f.open(errors='replace') as handle:
                        for r in json_records(handle):
                            if r.get('type') != 'assistant' or not isinstance(r.get('requestId'), str):
                                continue
                            m = r.get('message') if isinstance(r.get('message'), dict) else {}
                            info['requests'][r['requestId']] = {
                                'ts': iso_ts(r.get('timestamp')),
                                'response_model': safe(m.get('model'), MODEL_RE),
                                'requested_model': safe(r.get('requestedModel'), MODEL_RE),
                                'effort': safe_enum(r.get('effort'), EFFORTS),
                                'version': safe(r.get('version'), VERSION_RE),
                                'sidechain': r.get('isSidechain') is True}
        self._cache[key] = info
        return info


def _window_match(ts, start, end, slack=5.0):
    return ts is not None and start is not None and start - slack <= ts and (end is None or ts <= end + slack)


def enrich(row, facts, sessions, window):
    """Fold native session-store evidence into a run row (in place)."""
    provider, start, end = row['provider'], row['started_at'], row['finished_at']
    native = facts.get('session_id')
    if sessions is None or native is None:
        return
    if provider == 'codex':
        info = sessions.codex(native)
        if not info:
            return
        row['cli_version'] = row.get('cli_version') or info['cli_version']
        # Turns belong to the run whose window contains the turn start; the next
        # run of the same thread starts after this one, so windows don't overlap.
        mine = [t for t in info['turns'].values() if _window_match(t.get('start'), start, window)]
        responses = [u for t in mine for u in (t.get('responses') or {}).values()]
        models = {t.get('model') for t in mine if t.get('model')}
        if len(models) == 1:
            row['requested_model'] = models.pop()
            row['requested_model_source'] = 'native_session_turn_context'
        efforts = {t.get('effort') for t in mine if t.get('effort')}
        if len(efforts) == 1:
            row['effort'] = efforts.pop()
        if mine:
            row['provider_requests'] = len(responses)
            row['provider_requests_source'] = 'codex_rollout_response_records'
            row['compactions'] = sum(1 for ts in info['compactions'] if _window_match(ts, start, window))
            if responses and all(all(u[k] is not None for k in ('input_tokens', 'output_tokens')) for u in responses):
                usage = {k: (None if any(u[k] is None for u in responses) else sum(u[k] for u in responses))
                         for k in USAGE_FIELDS}
                row.update(usage)
                row['usage_method'] = 'per_response_records'
                row['usage_note'] = None
                row['_usage_final'] = True
            elif not responses:
                row.update(dict.fromkeys(USAGE_FIELDS, 0))
                row['usage_method'] = 'per_response_records'
                row['usage_note'] = 'no_provider_response_in_window'
                row['_usage_final'] = True
    elif provider == 'claude':
        info = sessions.claude(native)
        if not info:
            return
        mine = [r for r in info['requests'].values() if _window_match(r['ts'], start, window)]
        if mine:
            row['provider_requests'] = len(mine)
            row['provider_requests_source'] = 'claude_transcript_request_ids'
            resolved = {r['response_model'] for r in mine if r['response_model'] and not r['sidechain']}
            if len(resolved) == 1:
                row['resolved_model'] = resolved.pop()
                row['resolved_model_provenance'] = 'provider_response_model_field'
            requested = {r['requested_model'] for r in mine if r['requested_model'] and not r['sidechain']}
            if len(requested) == 1:
                row['requested_model'] = requested.pop()
                row['requested_model_source'] = 'native_transcript_requested_model'
            versions = {r['version'] for r in mine if r['version']}
            if len(versions) == 1:
                row['cli_version'] = row.get('cli_version') or versions.pop()


# ---------------------------------------------------------------------------
# Run construction and cumulative-delta normalization

def quota_scope_for(provider, profile=None, model=None):
    """Return the provider/pool quota scope for a route.

    Antigravity (`agy`) on Google AI Pro separates:
      - `agy_argon_weekly` (`gemini-4-argon-*`, `argon`)
      - `agy_gemini_shared` (`gemini-3.8-flash-*`, generic Gemini Flash/Pro)
      - `agy_claude_gpt_oss_shared` (`claude-opus-5-5-*`, `claude-sonnet-5-5-*`, `gpt-oss-120b-*`)
    Official Anthropic Claude (`claude` -> `claude_subscription`) and Antigravity Claude
    (`agy` -> `agy_claude_gpt_oss_shared`) never share quota or auth scope.
    """
    if provider == 'opencode' and profile:
        return f'opencode_free:{profile}'
    if provider == 'agy':
        if profile in AGY_PROFILE_SCOPES:
            return AGY_PROFILE_SCOPES[profile]
        if model in AGY_MODEL_SCOPES:
            return AGY_MODEL_SCOPES[model]
        if isinstance(model, str):
            low = model.lower()
            if 'argon' in low:
                return 'agy_argon_weekly'
            if low.startswith('gemini-'):
                return 'agy_gemini_shared'
            if low.startswith(('claude-', 'gpt-oss-')):
                return 'agy_claude_gpt_oss_shared'
        return 'antigravity_signin'
    return ROUTES.get(provider)


def logical_task_for(issue_number, role='worker'):
    if role == 'worker' and type(issue_number) is int and issue_number > 0:
        return f'issue:{issue_number}'
    return None


def worktree_key_for(issue_number, role='worker'):
    if role == 'worker' and type(issue_number) is int and issue_number > 0:
        return f'issue-{issue_number}'
    if role == 'lead':
        return 'lead-main'
    return None


def build_run(*, source_key, source_kind, role, provider, profile, profile_provenance, requested_model,
              effort, started_at, finished_at, exit_code, lines, sessions=None, window_end=None, **extra):
    """Turn one native invocation (metadata + its own log lines) into a run row."""
    facts = parse_native(provider, lines) if provider in PROVIDERS else parse_native('none', [])
    status = extra.pop('status', None)
    if status is None:
        if facts['terminal'] == 'success' and not exit_code:
            status = 'success'
        elif facts['terminal'] == 'failed' or exit_code:
            status = 'failed'
        elif finished_at is None:
            status = 'running'
        else:
            status = 'interrupted'  # Process ended (or log stopped) without a terminal record.
    ref_ts = finished_at if finished_at is not None else started_at
    failure = classify_native_failure(provider, lines, exit_code=exit_code, reference_ts=ref_ts)
    failure_kind = None
    blocked_reason = None
    reset_at = None
    reset_timezone = None
    reset_provenance = None
    if status in ('failed', 'interrupted', 'launch_error'):
        failure_kind = safe_enum(extra.get('failure_kind') or failure.get('failure_kind'), FAILURE_KINDS)
        if status == 'interrupted' and failure_kind is None:
            failure_kind = 'interrupted'
        elif status == 'launch_error' and failure_kind is None:
            failure_kind = 'launch_error'
        blocked_reason = safe_enum(extra.get('blocked_reason') or failure.get('blocked_reason'), BLOCKED_REASONS)
        if failure_kind == 'quota_exhausted':
            reset_at = nonneg_float(extra.get('reset_at') if 'reset_at' in extra else failure.get('reset_at'))
            reset_timezone = safe(extra.get('reset_timezone') if 'reset_timezone' in extra else failure.get('reset_timezone'), TZ_LABEL_RE)
            reset_provenance = safe_enum(
                extra.get('reset_provenance') if 'reset_provenance' in extra else failure.get('reset_provenance'),
                RESET_PROVENANCES, 'unknown')
    issue_num = nonneg_int(extra.get('issue_number'))
    clean_profile = safe(profile, PROFILE_RE)
    row = {
        'source_key': source_key, 'source_kind': source_kind, 'role': role,
        'provider': provider if provider in PROVIDERS else None,
        'auth_route': ROUTES.get(provider),
        'profile': clean_profile, 'profile_provenance': profile_provenance,
        'requested_model': safe(requested_model, MODEL_RE),
        'requested_model_source': 'launcher_profile' if requested_model else None,
        'resolved_model': None, 'resolved_model_provenance': None,
        'effort': safe_enum(effort, EFFORTS),
        'session_key': session_key(provider, facts['session_id']),
        'logical_task_id': safe(extra.get('logical_task_id'), LOGICAL_TASK_RE) or logical_task_for(issue_num, role),
        'worktree_key': safe(extra.get('worktree_key'), WORKTREE_KEY_RE) or worktree_key_for(issue_num, role),
        'started_at': started_at, 'finished_at': finished_at,
        'duration_ms': int((finished_at - started_at) * 1000) if started_at and finished_at and finished_at >= started_at else None,
        'status': status, 'exit_code': exit_code if type(exit_code) is int else None,
        'failure_kind': failure_kind, 'blocked_reason': blocked_reason,
        'quota_scope': quota_scope_for(provider, clean_profile, safe(requested_model, MODEL_RE)),
        'reset_at': reset_at, 'reset_timezone': reset_timezone, 'reset_provenance': reset_provenance,
        'handoff_from_run_id': None, 'handoff_from_profile': None,
        'handoff_from_provider': None, 'handoff_from_session_key': None, 'handoff_kind': None,
        'tool_calls': facts['tool_calls'], 'native_turns': None,
        'usage_semantics': SEMANTICS.get(provider),
        'provider_cost_usd': None, 'cost_basis': None,
    }
    row.update(dict.fromkeys(USAGE_FIELDS))
    if facts['usage'] is not None:  # opencode per-step sums or claude per-run fallback
        row.update(facts['usage'])
        row['usage_method'] = facts.get('usage_method') or 'per_step_sum'
        if facts['requests'] is not None:
            row['provider_requests'] = facts['requests']
            row['provider_requests_source'] = 'opencode_step_finish'
        if facts['cost_usd'] is not None:
            row['provider_cost_usd'] = facts['cost_usd']
            row['cost_basis'] = facts['cost_basis']
    cum = {}
    if facts['cumulative'] is not None:
        cum['usage'] = facts['cumulative']
    if facts.get('cumulative_cost') is not None:
        cum['cost'] = facts['cumulative_cost']
        cum['cost_basis'] = facts['cost_basis']
    if facts.get('turns_cumulative') is not None:
        cum['turns'] = facts['turns_cumulative']
    elif facts['turns'] is not None and provider == 'claude':
        row['native_turns'] = facts['turns']
    row['cum_json'] = json.dumps(cum, sort_keys=True) if cum else None
    if provider == 'claude' and len(facts['models']) == 1:
        # modelUsage key: model the CLI accounted usage under. Superseded below by the
        # provider response's own model field when a transcript is available.
        row['resolved_model'] = next(iter(facts['models']))
        row['resolved_model_provenance'] = 'cli_model_usage_key'
    elif provider == 'agy' and len(facts['models']) == 1:
        row['resolved_model'] = next(iter(facts['models']))
        row['resolved_model_provenance'] = 'provider_response_model_field'
    enrich(row, facts, sessions, window_end if window_end is not None else finished_at)
    for k, v in extra.items():
        if k in RUN_COLUMNS and v is not None:
            row[k] = v
    if row.get('issue_number') is not None and row.get('logical_task_id') is None:
        row['logical_task_id'] = logical_task_for(row['issue_number'], row['role'])
    if row.get('issue_number') is not None and row.get('worktree_key') is None:
        row['worktree_key'] = worktree_key_for(row['issue_number'], row['role'])
    return row


def recompute_session(conn, key):
    """Derive per-invocation usage from session-cumulative snapshots, in start order.

    A run without its own snapshot (interrupted/killed) stays NULL; the next run
    with a snapshot carries the gap and says so in usage_note. Exact per-response
    usage (usage_method=per_response_records) is never overwritten.
    """
    if key is None:
        return
    # Rows without a recorded start (e.g. receipt-less wrapper logs) order by finish.
    rows = conn.execute('SELECT run_id, cum_json, usage_method, provider, started_at FROM runs '
                        'WHERE session_key=? ORDER BY COALESCE(started_at, finished_at), run_id', (key,)).fetchall()
    prev = None
    gap = 0
    for r in rows:
        cum = json.loads(r['cum_json']) if r['cum_json'] else {}
        exact = r['usage_method'] in ('per_response_records', 'per_step_sum', 'per_run_usage')
        if 'usage' not in cum:
            if not exact:
                gap += 1
                conn.execute('UPDATE runs SET usage_method=?, usage_note=? WHERE run_id=?',
                             ('unreported', 'no_terminal_usage_record', r['run_id']))
            elif 'cost' in cum and prev is not None and 'cost' in prev:
                val = cum['cost'] - prev['cost']
                conn.execute('UPDATE runs SET provider_cost_usd=?, cost_basis=? WHERE run_id=?',
                             (val if val >= 0 else None, cum.get('cost_basis'), r['run_id']))
            elif 'cost' in cum and prev is None:
                conn.execute('UPDATE runs SET provider_cost_usd=?, cost_basis=? WHERE run_id=?',
                             (cum['cost'] if cum['cost'] >= 0 else None, cum.get('cost_basis'), r['run_id']))
            continue
        update = {}
        if prev is None or 'usage' not in prev:
            delta = cum['usage']
            note = 'first_snapshot_in_session' + (f';includes_prior_unreported:{gap}' if gap else '')
        else:
            delta = {k: (None if cum['usage'].get(k) is None or prev['usage'].get(k) is None
                         else cum['usage'][k] - prev['usage'][k]) for k in USAGE_FIELDS}
            note = f'includes_prior_unreported:{gap}' if gap else None
            if any(v is not None and v < 0 for v in delta.values()):
                delta = dict.fromkeys(USAGE_FIELDS)
                note = 'cumulative_decreased_unknown'
        if not exact:
            update.update(delta)
            update['usage_method'] = 'cumulative_delta'
            update['usage_note'] = note
        if 'cost' in cum:
            fresh = prev is None or 'usage' not in prev
            base = 0.0 if fresh else prev.get('cost')
            value = None if base is None else cum['cost'] - base
            update['provider_cost_usd'] = value if value is not None and value >= 0 else None
            update['cost_basis'] = cum.get('cost_basis')
        if 'turns' in cum:
            base = (prev or {}).get('turns', 0) if prev is not None and 'usage' in prev else 0
            update['native_turns'] = cum['turns'] - base if cum['turns'] >= base else None
        if update:
            conn.execute(f'UPDATE runs SET {", ".join(k + "=?" for k in update)} WHERE run_id=?',
                         [*update.values(), r['run_id']])
        prev = cum
        gap = 0


def sync_quota_events_for_run(conn, run_id):
    """Ensure a quota-exhausted run has a corresponding structured quota_events row."""
    r = conn.execute('SELECT * FROM runs WHERE run_id=?', (run_id,)).fetchall()
    if not r:
        return
    r = dict(r[0])
    if r.get('failure_kind') == 'quota_exhausted' and r.get('blocked_reason'):
        existing = conn.execute('SELECT decision, successor_run_id, handoff_at, outcome FROM quota_events WHERE source_key=?',
                                ('quota:' + r['source_key'],)).fetchone()
        upsert_quota_event(conn, {
            'source_key': 'quota:' + r['source_key'],
            'run_id': r['run_id'],
            'role': r['role'],
            'provider': r['provider'],
            'profile': r['profile'],
            'quota_scope': r['quota_scope'] or quota_scope_for(r['provider'], r['profile'], r.get('requested_model')),
            'session_key': r['session_key'],
            'repo': r['repo'],
            'issue_number': r['issue_number'],
            'pr_number': r['pr_number'],
            'logical_task_id': r['logical_task_id'] or logical_task_for(r['issue_number'], r['role']),
            'worktree_key': r['worktree_key'] or worktree_key_for(r['issue_number'], r['role']),
            'blocked_reason': r['blocked_reason'],
            'observed_at': r['finished_at'] or r['started_at'] or now(),
            'reset_at': r['reset_at'],
            'reset_timezone': r['reset_timezone'],
            'reset_provenance': r['reset_provenance'] or 'unknown',
            'decision': existing['decision'] if existing and existing['decision'] else 'pending',
            'successor_run_id': existing['successor_run_id'] if existing else None,
            'handoff_at': existing['handoff_at'] if existing else None,
            'outcome': existing['outcome'] if existing and existing['outcome'] else 'blocked_waiting_lead',
        })


def classify_attempts(conn, issue_number):
    """Order an issue's worker runs: initial, retry/handoff (after interrupt/failure), rework.

    Also links quota-interrupted or cross-profile handoff lineage and updates quota_events.
    """
    if issue_number is None:
        return
    rows = [dict(r) for r in conn.execute(
        "SELECT * FROM runs WHERE role='worker' AND issue_number=? ORDER BY started_at, run_id",
        (issue_number,)).fetchall()]
    previous = None
    for number, r in enumerate(rows, 1):
        logical_id = r.get('logical_task_id') or logical_task_for(issue_number, 'worker')
        wt_key = r.get('worktree_key') or worktree_key_for(issue_number, 'worker')
        handoff_from_id = r.get('handoff_from_run_id')
        handoff_from_prof = r.get('handoff_from_profile')
        handoff_from_prov = r.get('handoff_from_provider')
        handoff_from_sess = r.get('handoff_from_session_key')
        handoff_kind = r.get('handoff_kind')
        if previous is None:
            kind = 'initial'
        elif previous['status'] == 'success':
            kind = 'rework'
        else:
            kind = 'retry'
            if (previous.get('failure_kind') == 'quota_exhausted' or
                    (previous.get('profile') and r.get('profile') and previous.get('profile') != r.get('profile')) or
                    handoff_from_id):
                handoff_from_id = handoff_from_id or previous['run_id']
                handoff_from_prof = handoff_from_prof or previous.get('profile')
                handoff_from_prov = handoff_from_prov or previous.get('provider')
                handoff_from_sess = handoff_from_sess or previous.get('session_key')
                if handoff_from_prov and r.get('provider') and handoff_from_prov != r.get('provider'):
                    handoff_kind = handoff_kind or 'cross_provider_reassign'
                    kind = 'handoff'
                elif handoff_from_prof and r.get('profile') and handoff_from_prof != r.get('profile'):
                    handoff_kind = handoff_kind or 'same_provider_reassign'
                    kind = 'handoff'
                else:
                    handoff_kind = handoff_kind or 'same_owner_resume_after_cooldown'
        conn.execute(
            'UPDATE runs SET attempt_kind=?, attempt_number=?, logical_task_id=?, worktree_key=?, '
            'handoff_from_run_id=?, handoff_from_profile=?, handoff_from_provider=?, '
            'handoff_from_session_key=?, handoff_kind=? WHERE run_id=?',
            (kind, number, logical_id, wt_key, handoff_from_id, handoff_from_prof,
             handoff_from_prov, handoff_from_sess, handoff_kind, r['run_id'])
        )
        if handoff_from_id:
            q_ev = conn.execute('SELECT * FROM quota_events WHERE run_id=?', (handoff_from_id,)).fetchone()
            if q_ev:
                prev_end = previous['finished_at'] if previous and previous['run_id'] == handoff_from_id else q_ev['observed_at']
                overhead = (int((r['started_at'] - prev_end) * 1000)
                            if r.get('started_at') and prev_end and r['started_at'] >= prev_end else None)
                decision = 'reassign' if handoff_kind in ('cross_provider_reassign', 'same_provider_reassign') else 'resumed'
                outcome = ('succeeded_open' if r['status'] == 'success'
                           else 'in_progress' if r['status'] == 'running'
                           else 'successor_failed')
                conn.execute(
                    'UPDATE quota_events SET decision=?, successor_run_id=?, successor_profile=?, '
                    'successor_provider=?, successor_session_key=?, handoff_kind=?, '
                    'handoff_at=COALESCE(handoff_at, ?), transfer_overhead_ms=COALESCE(transfer_overhead_ms, ?), '
                    'outcome=? WHERE event_id=?',
                    (decision, r['run_id'], r.get('profile'), r.get('provider'), r.get('session_key'),
                     handoff_kind, r.get('started_at'), overhead, outcome, q_ev['event_id'])
                )
        previous = r


def attribute(conn, repo):
    """Attach worker runs to the PR built from their issue branch (team/issue-N)."""
    for issue, in conn.execute('SELECT DISTINCT issue_number FROM runs WHERE issue_number IS NOT NULL').fetchall():
        prs = conn.execute("SELECT number, merged_at, state FROM github_items WHERE repo=? AND kind='pr' AND head_issue=? "
                           'ORDER BY merged_at IS NULL, merged_at, number', (repo, issue)).fetchall()
        if not prs:
            prs = conn.execute("SELECT number, merged_at, state FROM github_items WHERE repo=? AND kind='pr' AND "
                               "EXISTS (SELECT 1 FROM json_each(linked_issues) WHERE value=?) "
                               'ORDER BY merged_at IS NULL, merged_at, number', (repo, issue)).fetchall()
        pr_num = prs[0]['number'] if prs else None
        merged = bool(prs and prs[0]['merged_at'] is not None)
        conn.execute('UPDATE runs SET pr_number=? WHERE issue_number=? AND role=?',
                     (pr_num, issue, 'worker'))
        conn.execute('UPDATE quota_events SET pr_number=? WHERE issue_number=?',
                     (pr_num, issue))
        if merged:
            conn.execute("UPDATE quota_events SET outcome='delivered_merged' WHERE issue_number=? AND successor_run_id IS NOT NULL",
                         (issue,))
        cat = conn.execute("SELECT category FROM github_items WHERE repo=? AND kind='issue' AND number=?",
                           (repo, issue)).fetchone()
        conn.execute("UPDATE runs SET task_category=? WHERE issue_number=? AND role='worker' AND "
                     "(task_category IS NULL OR task_category='unknown')",
                     ((cat['category'] if cat and cat['category'] else 'unknown'), issue))


def finalize(conn, row, repo=None):
    run_id = upsert_run(conn, row)
    key = conn.execute('SELECT session_key, issue_number FROM runs WHERE run_id=?', (run_id,)).fetchone()
    recompute_session(conn, key['session_key'])
    sync_quota_events_for_run(conn, run_id)
    if key['issue_number'] is not None:
        classify_attempts(conn, key['issue_number'])
        if repo:
            attribute(conn, repo)
    return run_id


# ---------------------------------------------------------------------------
# Live recording API used by team.py. Callers wrap these; telemetry never
# changes launcher behavior.

def run_key(log_path):
    return 'log:' + Path(log_path).name


def run_id_for(log_path):
    return digest('run', run_key(log_path))


def record_start(db_path, *, log_path, role, profile, provider, requested_model, effort, started_at,
                 repo=None, issue_number=None, trigger=None, wake_reasons=None, parent_run_id=None,
                 task_category=None, cli_version=None, handoff_from_run_id=None,
                 handoff_from_profile=None, handoff_from_provider=None,
                 handoff_from_session_key=None, handoff_kind=None):
    conn = connect(db_path)
    try:
        clean_issue = nonneg_int(issue_number)
        clean_prof = safe(profile, PROFILE_RE)
        clean_model = safe(requested_model, MODEL_RE)
        row = {'source_key': run_key(log_path), 'source_kind': 'live', 'role': role,
               'profile': clean_prof, 'profile_provenance': 'launcher',
               'provider': provider, 'auth_route': ROUTES.get(provider),
               'quota_scope': quota_scope_for(provider, clean_prof, clean_model),
               'requested_model': clean_model, 'requested_model_source': 'launcher_profile',
               'effort': safe_enum(effort, EFFORTS), 'repo': safe(repo, REPO_RE),
               'issue_number': clean_issue,
               'logical_task_id': logical_task_for(clean_issue, role),
               'worktree_key': worktree_key_for(clean_issue, role),
               'trigger': safe_enum(trigger, TRIGGERS, 'unknown'),
               'wake_reasons': ','.join(r for r in (wake_reasons or []) if r in WAKE_REASONS) or None,
               'parent_run_id': parent_run_id if isinstance(parent_run_id, str) and re.fullmatch(r'[0-9a-f]{32}', parent_run_id) else None,
               'parent_provenance': 'launcher_env' if parent_run_id else None,
               'task_category': safe_enum(task_category, CATEGORIES),
               'cli_version': safe(cli_version, VERSION_RE),
               'handoff_from_run_id': handoff_from_run_id if isinstance(handoff_from_run_id, str) and re.fullmatch(r'[0-9a-f]{32}', handoff_from_run_id) else None,
               'handoff_from_profile': safe(handoff_from_profile, PROFILE_RE),
               'handoff_from_provider': safe_enum(handoff_from_provider, PROVIDERS),
               'handoff_from_session_key': handoff_from_session_key if isinstance(handoff_from_session_key, str) and re.fullmatch(r'[0-9a-f]{24}', handoff_from_session_key) else None,
               'handoff_kind': safe_enum(handoff_kind, HANDOFF_KINDS),
               'started_at': started_at, 'status': 'running'}
        return write(conn, lambda c: upsert_run(c, row))
    finally:
        conn.close()


def record_finish(db_path, *, log_path, role, profile, provider, requested_model, effort, started_at,
                  finished_at, exit_code, status=None, sessions=None, repo=None, **extra):
    lines = Path(log_path).read_text(errors='replace').splitlines() if Path(log_path).exists() else []
    row = build_run(source_key=run_key(log_path), source_kind='live', role=role, provider=provider,
                    profile=profile, profile_provenance='launcher', requested_model=requested_model,
                    effort=effort, started_at=started_at, finished_at=finished_at, exit_code=exit_code,
                    lines=lines, sessions=sessions, status=status, repo=safe(repo, REPO_RE), **extra)
    conn = connect(db_path)
    try:
        return write(conn, lambda c: finalize(c, row, row.get('repo')))
    finally:
        conn.close()


def record_quota_decision(db_path, *, run_id=None, issue_number=None, decision, to_profile=None,
                          to_provider=None, handoff_kind=None, decided_at=None, outcome=None):
    """Record lead decision (wait, reassign, escalate) on a quota event."""
    conn = connect(db_path)
    try:
        def apply(c):
            row = None
            if run_id:
                row = c.execute('SELECT * FROM quota_events WHERE run_id=?', (run_id,)).fetchone()
            if row is None and issue_number is not None:
                row = c.execute('SELECT * FROM quota_events WHERE issue_number=? ORDER BY observed_at DESC LIMIT 1',
                                (issue_number,)).fetchone()
            if row is None:
                return None
            stamp = nonneg_float(decided_at) or now()
            overhead = (int((stamp - row['observed_at']) * 1000)
                        if decision == 'reassign' and row['observed_at'] and stamp >= row['observed_at']
                        else row['transfer_overhead_ms'])
            out_state = outcome or ('waiting_cooldown' if decision == 'wait'
                                    else 'reassigned_dispatched' if decision == 'reassign'
                                    else 'escalated_no_eligible_peer' if decision == 'escalate'
                                    else row['outcome'])
            c.execute(
                'UPDATE quota_events SET decision=?, successor_profile=COALESCE(?, successor_profile), '
                'successor_provider=COALESCE(?, successor_provider), handoff_kind=COALESCE(?, handoff_kind), '
                'handoff_at=COALESCE(?, handoff_at), transfer_overhead_ms=COALESCE(?, transfer_overhead_ms), '
                'outcome=? WHERE event_id=?',
                (safe_enum(decision, QUOTA_DECISIONS, 'pending'), safe(to_profile, PROFILE_RE),
                 safe_enum(to_provider, PROVIDERS), safe_enum(handoff_kind, HANDOFF_KINDS),
                 stamp if decision == 'reassign' else None, overhead, out_state, row['event_id'])
            )
            return row['event_id']
        return write(conn, apply)
    finally:
        conn.close()


def record_poll(db_path, *, at, outcome, reasons=(), duration_ms=None, run_id=None, lead_profile=None):
    poll = {'source_key': 'poll:' + digest('live', at, outcome, os.getpid()), 'source_kind': 'live',
            'at': at, 'outcome': safe_enum(outcome, POLL_OUTCOMES, 'error'),
            'reasons': ','.join(r for r in reasons if r in WAKE_REASONS) or None,
            'duration_ms': duration_ms, 'ai_launched': 1 if run_id else 0, 'run_id': run_id,
            'lead_profile': safe(lead_profile, PROFILE_RE)}
    conn = connect(db_path)
    try:
        write(conn, lambda c: upsert_poll(c, poll))
    finally:
        conn.close()


def reconcile_running(db_path, state_dir, live_sessions, older_than=600, sessions=None):
    """Finalize 'running' rows whose process is gone (e.g. killed with its scope)."""
    conn = connect(db_path)
    try:
        rows = conn.execute("SELECT * FROM runs WHERE status='running'").fetchall()
        for r in rows:
            name = r['source_key'][4:] if r['source_key'].startswith('log:') else None
            match = LOG_RE.fullmatch(name or '')
            if not match:
                continue
            log = Path(state_dir) / name
            if r['role'] == 'worker' and f'vael-issue-{r["issue_number"]}' in live_sessions:
                continue
            try:
                mtime = log.stat().st_mtime
            except OSError:
                continue
            if now() - mtime < older_than:
                continue
            row = build_run(source_key=r['source_key'], source_kind=r['source_kind'], role=r['role'],
                            provider=r['provider'], profile=r['profile'], profile_provenance=r['profile_provenance'],
                            requested_model=r['requested_model'], effort=r['effort'], started_at=r['started_at'],
                            finished_at=mtime, exit_code=None,
                            lines=log.read_text(errors='replace').splitlines(), sessions=sessions,
                            issue_number=r['issue_number'])
            if row['status'] == 'running':
                row['status'] = 'interrupted'
                if not row.get('failure_kind'):
                    row['failure_kind'] = 'interrupted'
            write(conn, lambda c: finalize(c, row, r['repo']))
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Historical import (idempotent). Source: native logs + assignment metadata in the
# team state directory, optional native session stores, GitHub metadata JSON and
# the lead service journal export. Nothing outside the allowlist is retained.

CATEGORY_WORDS = (('qa', re.compile(r'\b(qa|playthrough|validation|validate|verify|verification)\b', re.I)),
                  ('docs', re.compile(r'\b(docs?|documentation|handoff|readme)\b', re.I)),
                  ('bugfix', re.compile(r'\b(fix|bug|repair|regression|crash)\b', re.I)))


def categorize(title, labels=()):
    labels = {l.lower() for l in labels}
    for name, words in CATEGORY_WORDS:
        if name in labels or (isinstance(title, str) and words.search(title)):
            return name
    return 'implementation'


def detect_provider(lines):
    for r in json_records(lines):
        t = r.get('type')
        if t in ('thread.started', 'turn.started', 'turn.completed', 'turn.failed', 'item.completed', 'item.started'):
            return 'codex'
        if t in ('result', 'system', 'assistant', 'user') and ('session_id' in r or t == 'result'):
            return 'claude'
        if 'sessionID' in r and t in ('step_start', 'step_finish', 'tool_use', 'text', 'error'):
            return 'opencode'
        if 'conversation_id' in r and 'status' in r:
            return 'agy'
    return None


def import_github(conn, repo, issues, prs):
    """Store GitHub numbers/states/timestamps only. Bodies/titles are read for
    closing references/category and immediately discarded."""
    def apply(c):
        for i in issues:
            n = nonneg_int(i.get('number'))
            if not n:
                continue
            labels = [l.get('name') for l in i.get('labels') or [] if isinstance(l, dict)]
            c.execute('INSERT INTO github_items(repo,kind,number,state,created_at,closed_at,category) '
                      "VALUES(?,'issue',?,?,?,?,?) ON CONFLICT(repo,kind,number) DO UPDATE SET "
                      'state=excluded.state, created_at=excluded.created_at, closed_at=excluded.closed_at, '
                      'category=excluded.category',
                      (repo, n, safe_enum(i.get('state'), ('OPEN', 'CLOSED')), iso_ts(i.get('createdAt')),
                       iso_ts(i.get('closedAt')), categorize(i.get('title'), [l for l in labels if isinstance(l, str)])))
        for p in prs:
            n = nonneg_int(p.get('number'))
            if not n:
                continue
            head = re.fullmatch(r'team/issue-([1-9][0-9]{0,8})', p.get('headRefName') or '')
            linked = sorted({int(x) for x in re.findall(
                r'(?i)\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#([1-9][0-9]{0,8})\b', p.get('body') or '')})
            c.execute('INSERT INTO github_items(repo,kind,number,state,created_at,closed_at,merged_at,head_issue,linked_issues) '
                      "VALUES(?,'pr',?,?,?,?,?,?,?) ON CONFLICT(repo,kind,number) DO UPDATE SET state=excluded.state, "
                      'created_at=excluded.created_at, closed_at=excluded.closed_at, merged_at=excluded.merged_at, '
                      'head_issue=excluded.head_issue, linked_issues=excluded.linked_issues',
                      (repo, n, safe_enum(p.get('state'), ('OPEN', 'CLOSED', 'MERGED')), iso_ts(p.get('createdAt')),
                       iso_ts(p.get('closedAt')), iso_ts(p.get('mergedAt')),
                       int(head[1]) if head else None, json.dumps(linked)))
    write(conn, apply)


def parse_journal(text):
    """Pair lead-service activations from `journalctl -o short-unix` text (timestamps only)."""
    passes = []
    current = None
    for line in text.splitlines():
        m = re.match(r'([0-9]{9,11}\.[0-9]+) \S+ systemd\[[0-9]+\]: (.*)', line)
        if not m:
            continue
        ts, msg = float(m[1]), m[2]
        if msg.startswith('Starting vael-team-lead.service'):
            current = {'start': ts, 'end': None, 'failed': False}
            passes.append(current)
        elif current and msg.startswith('Finished vael-team-lead.service'):
            current['end'] = ts
            current = None
        elif current and msg.startswith('vael-team-lead.service: Failed') or \
                current and msg.startswith('Failed to start vael-team-lead.service'):
            current['failed'] = True
            current['end'] = ts
            current = None
    return passes


LEGACY_LEAD = {'codex': ('sol', 'gpt-6.1-sol', 'high'), 'claude': ('opus', 'opus', 'medium')}


def import_history(db_path, state_dir, *, repo, profiles, sessions=None, github=None, journal=None,
                   live=(), now_ts=None):
    """Idempotently import every native log in the team state directory.

    ``profiles`` maps profile -> (provider, model, effort) as the launcher defines
    them. Worker profile comes from that issue's assignment metadata (or recorded
    handoff history when reassigned across providers); it is accepted only if the
    log's own format matches its provider. Historical lead profile is inferred
    from the log format (Codex lead = Sol/high; Claude lead = Opus/medium) and
    labeled as inferred.
    """
    state = Path(state_dir)
    conn = connect(db_path)
    report = {'logs': 0, 'runs': 0, 'by_status': {}, 'by_provider': {}, 'unknown_profile': 0,
              'usage_known': 0, 'polls': 0, 'quota_events': 0}
    try:
        if github:
            import_github(conn, repo, github.get('issues', []), github.get('prs', []))
        assignments = {}
        assignment_records = {}
        for f in state.glob('issue-*.json'):
            m = re.fullmatch(r'issue-([1-9][0-9]{0,8})\.json', f.name)
            try:
                data = json.loads(f.read_text())
            except (OSError, ValueError):
                continue
            if m and isinstance(data, dict):
                num = int(m[1])
                assignments[num] = safe(data.get('profile'), PROFILE_RE)
                assignment_records[num] = data
        logs = []
        for log in state.glob('*.log'):
            m = LOG_RE.fullmatch(log.name)
            if m and not log.is_symlink():
                logs.append((int(m[3]) / 1e9, log, m))
        logs.sort(key=lambda x: x[0])
        lead_windows = []
        rows = []
        for i, (start, log, m) in enumerate(logs):
            report['logs'] += 1
            lines = log.read_text(errors='replace').splitlines()
            mtime = log.stat().st_mtime
            provider = detect_provider(lines)
            role = 'lead' if m[1] == 'lead' else 'worker'
            issue = int(m[2]) if m[2] else None
            profile = provenance = model = effort = None
            if role == 'worker':
                profile = assignments.get(issue)
                spec = profiles.get(profile)
                if spec and (provider is None or spec[0] == provider):
                    provider, model, effort = spec
                    provenance = 'assignment_metadata'
                else:
                    # Check recorded handoff_history on the issue if it was reassigned across providers.
                    hist = (assignment_records.get(issue) or {}).get('handoff_history') or []
                    matched = None
                    for h in hist:
                        if isinstance(h, dict):
                            hp = safe(h.get('from_profile'), PROFILE_RE)
                            hspec = profiles.get(hp)
                            if hspec and hspec[0] == provider:
                                matched = (hp, hspec)
                                break
                    if matched:
                        profile, (provider, model, effort) = matched
                        provenance = 'assignment_handoff_history'
                    else:
                        profile = None
            elif provider in LEGACY_LEAD:
                profile, _, effort = LEGACY_LEAD[provider]
                model = profiles.get(profile, (None, LEGACY_LEAD[provider][1]))[1]
                provenance = 'inferred_from_log_format'
            if profile is None:
                report['unknown_profile'] += 1
            # Claude/AGY print JSON only at exit, so an empty log may be a live run.
            # Live = an active tmux issue session / lead service, passed by the caller.
            running = (f'vael-issue-{issue}' if issue else 'lead') in live and log == max(
                (l for _, l, mm in logs if mm[1] == m[1]), key=lambda p: int(LOG_RE.fullmatch(p.name)[3]))
            finished = None if running else mtime
            forced = 'running' if running else ('interrupted' if not lines else None)
            # Same-thread later runs bound this run's window.
            row = build_run(source_key=run_key(log), source_kind='import', role=role, provider=provider,
                            profile=profile, profile_provenance=provenance, requested_model=model, effort=effort,
                            started_at=start, finished_at=None if not lines else finished, exit_code=None,
                            lines=lines, sessions=sessions, window_end=finished, status=forced,
                            issue_number=issue)
            row['repo'] = repo
            row['issue_number'] = issue
            row['trigger'] = 'timer' if role == 'lead' else 'unknown'
            row['task_category'] = 'lead_pass' if role == 'lead' else None
            row['attempt_kind'] = 'lead' if role == 'lead' else None
            rows.append(row)
            if role == 'lead':
                lead_windows.append((start, finished or start, row['source_key']))
        for row in rows:
            if row['role'] == 'worker':
                for start, end, key in lead_windows:
                    if start <= row['started_at'] <= end:
                        row['parent_run_id'] = digest('run', key)
                        row['parent_provenance'] = 'inferred_lead_time_window'
        def apply(c):
            keys = set()
            run_ids = []
            for row in rows:
                rid = upsert_run(c, row)
                run_ids.append(rid)
                keys.add(row['session_key'])
            for key in keys:
                recompute_session(c, key)
            for rid in run_ids:
                sync_quota_events_for_run(c, rid)
            for issue, in c.execute('SELECT DISTINCT issue_number FROM runs WHERE issue_number IS NOT NULL').fetchall():
                classify_attempts(c, issue)
                rec = assignment_records.get(issue) or {}
                qdec = rec.get('quota_decision')
                if isinstance(qdec, dict) and qdec.get('decision') in QUOTA_DECISIONS:
                    c.execute('UPDATE quota_events SET decision=?, outcome=COALESCE(?, outcome) WHERE issue_number=? AND successor_run_id IS NULL',
                              (qdec['decision'], qdec.get('outcome'), issue))
            attribute(c, repo)
            if journal is not None:
                passes = parse_journal(journal)
                used_lead_keys = set()
                for idx, p in enumerate(passes):
                    next_start = passes[idx + 1]['start'] if idx + 1 < len(passes) else None
                    # Strictly bound historical lead log matching: a service activation can only
                    # match a lead log created at/after activation start, before the next activation
                    # start, and within MAX_JOURNAL_LAUNCH_WINDOW_SEC when activation end is missing
                    # (never an open-ended 24h window that attaches future unrelated logs).
                    end_bound = (p['end'] + 1.0) if p['end'] is not None else (p['start'] + MAX_JOURNAL_LAUNCH_WINDOW_SEC)
                    if next_start is not None:
                        end_bound = min(end_bound, next_start - 0.001)
                    lead = next(
                        (w for w in lead_windows
                         if w[2] not in used_lead_keys and (p['start'] - 1.0) <= w[0] <= end_bound),
                        None,
                    )
                    if lead is not None:
                        used_lead_keys.add(lead[2])
                        status = c.execute('SELECT status FROM runs WHERE source_key=?', (lead[2],)).fetchone()
                        outcome = 'inference_success' if status and status[0] == 'success' else 'inference_failed'
                        ai_launched = 1
                        run_id_val = digest('run', lead[2])
                    else:
                        # Absence of a matched native lead log in historical journal import is NOT
                        # proof of a zero-model skip; preserve NULL ai_launched with explicit outcome.
                        outcome = 'service_failed_unrecorded' if p['failed'] else 'unmatched_activation_unknown'
                        ai_launched = None
                        run_id_val = None
                    upsert_poll(c, {'source_key': 'journal:' + digest(p['start']), 'source_kind': 'import',
                                    'at': p['start'], 'outcome': outcome, 'reasons': None,
                                    'duration_ms': int((p['end'] - p['start']) * 1000) if p['end'] else None,
                                    'ai_launched': ai_launched,
                                    'run_id': run_id_val, 'lead_profile': None})
                    report['polls'] += 1
        write(conn, apply)
        for r in conn.execute('SELECT status, provider, input_tokens FROM runs WHERE source_kind=?', ('import',)):
            report['runs'] += 1
            report['by_status'][r['status']] = report['by_status'].get(r['status'], 0) + 1
            report['by_provider'][r['provider'] or 'unknown'] = report['by_provider'].get(r['provider'] or 'unknown', 0) + 1
            report['usage_known'] += r['input_tokens'] is not None
        report['quota_events'] = conn.execute('SELECT COUNT(*) FROM quota_events').fetchone()[0]
    finally:
        conn.close()
    return report


def wrapper_key(log_path):
    # Full resolved path: different wrappers reuse basenames such as native.log.
    return 'wrapper:' + digest(str(Path(log_path).resolve()))


def import_wrapper_runs(db_path, entries):
    """Idempotently import operator wrapper invocations named by an explicit manifest.

    Each entry declares what the wrapper launched (``log``, ``provider``, ``profile``,
    ``requested_model``, ``effort``, ``task``) and optionally a ``receipt`` JSON with
    ISO ``started_at``/``finished_at``/``exit_code`` (or an ``exit_file``) and a
    ``predecessor_log`` for lineage. Only the native log's allowlisted terminal fields and these declared
    values are stored. A missing receipt leaves start/duration NULL rather than
    guessing; the manifest is the coverage boundary, not the whole account.
    """
    report = {'entries': 0, 'runs': 0, 'missing_logs': 0, 'handoffs_linked': 0}
    rows = []
    links = []
    for e in entries:
        report['entries'] += 1
        log = Path(e['log'])
        if not log.is_file() or log.is_symlink():
            report['missing_logs'] += 1
            continue
        receipt = {}
        if e.get('receipt'):
            try:
                data = json.loads(Path(e['receipt']).read_text())
                receipt = data if isinstance(data, dict) else {}
            except (OSError, ValueError):
                receipt = {}
        provider = safe_enum(e.get('provider'), PROVIDERS)
        lines = log.read_text(errors='replace').splitlines()
        started = iso_ts(e.get('started_at')) or iso_ts(receipt.get('started_at'))
        finished = iso_ts(receipt.get('finished_at'))
        if finished is None and lines:
            finished = log.stat().st_mtime
        exit_code = receipt.get('exit_code') if type(receipt.get('exit_code')) is int else None
        if exit_code is None and e.get('exit_file'):
            try:
                exit_code = int(Path(e['exit_file']).read_text().strip())
            except (OSError, ValueError):
                exit_code = None
        forced = None
        if not lines:
            forced = 'running' if receipt.get('status') == 'running' else 'interrupted'
        row = build_run(source_key=wrapper_key(log), source_kind='import', role='worker', provider=provider,
                        profile=e.get('profile'), profile_provenance='wrapper_manifest',
                        requested_model=e.get('requested_model'), effort=e.get('effort'),
                        started_at=started, finished_at=None if forced == 'running' else finished,
                        exit_code=exit_code, lines=lines, window_end=finished, status=forced)
        row['trigger'] = 'operator'
        row['task_category'] = safe_enum(e.get('category'), CATEGORIES, 'unknown')
        row['logical_task_id'] = safe(e.get('task'), LOGICAL_TASK_RE)
        row['worktree_key'] = safe(e.get('worktree_key'), WORKTREE_KEY_RE)
        row['repo'] = None
        row['issue_number'] = None
        rows.append(row)
        if e.get('predecessor_log'):
            links.append((row, wrapper_key(e['predecessor_log'])))

    def apply(c):
        keys = set()
        for row in rows:
            rid = upsert_run(c, row)
            keys.add(row['session_key'])
            report['runs'] += 1
        for key in keys:
            recompute_session(c, key)
        for row in rows:
            sync_quota_events_for_run(c, digest('run', row['source_key']))
        for row, pred_key in links:
            pred = c.execute('SELECT run_id, profile, provider, session_key FROM runs WHERE source_key=?',
                             (pred_key,)).fetchone()
            if pred is None:
                continue
            kind = ('cross_provider_reassign' if pred['provider'] != row['provider'] else
                    'same_owner_resume_after_cooldown' if pred['profile'] == row['profile'] else
                    'same_provider_reassign')
            rid = digest('run', row['source_key'])
            c.execute('UPDATE runs SET handoff_from_run_id=?, handoff_from_profile=?, handoff_from_provider=?, '
                      'handoff_from_session_key=?, handoff_kind=?, attempt_kind=? WHERE run_id=?',
                      (pred['run_id'], pred['profile'], pred['provider'], pred['session_key'], kind,
                       'handoff', rid))
            n = c.execute('UPDATE quota_events SET successor_run_id=?, successor_profile=?, successor_provider=?, '
                          'successor_session_key=?, handoff_kind=?, handoff_at=?, decision=?, outcome=? '
                          'WHERE run_id=?',
                          (rid, row['profile'], row['provider'], row['session_key'], kind, row['started_at'],
                           'reassign', 'handoff_started', pred['run_id'])).rowcount
            report['handoffs_linked'] += n

    conn = connect(db_path)
    try:
        write(conn, apply)
    finally:
        conn.close()
    return report


def load_rate_card(conn, path):
    """Optional, versioned API-equivalent rates. Never invented: the file must name
    its source. Per-million-token rates; missing rates stay NULL."""
    card = json.loads(Path(path).read_text())
    version, source = card.get('version'), card.get('source')
    if not (isinstance(version, str) and re.fullmatch(r'[A-Za-z0-9._-]{1,40}', version) and isinstance(source, str) and source):
        raise ValueError('Rate card needs a version and a source')
    def apply(c):
        for model, rates in (card.get('models') or {}).items():
            if safe(model, MODEL_RE):
                c.execute('INSERT OR REPLACE INTO rate_cards VALUES(?,?,?,?,?,?,?)',
                          (version, model, source[:200], *(nonneg_float(rates.get(k)) for k in
                           ('input', 'cached_input', 'cache_write', 'output'))))
    write(conn, apply)


# ---------------------------------------------------------------------------
# Analytics queries (read-only), shared with the dashboard.

FILTER_ENUMS = {'provider': PROVIDERS, 'role': ROLES, 'status': STATUSES, 'task': CATEGORIES,
                'effort': EFFORTS, 'attempt': ATTEMPTS, 'failure': FAILURE_KINDS}
FILTER_PATTERNS = {'model': MODEL_RE, 'profile': PROFILE_RE, 'repo': REPO_RE}
METRICS = ('total_tokens', 'input_tokens', 'uncached_input_tokens', 'cached_input_tokens', 'output_tokens',
           'reasoning_tokens', 'provider_requests', 'duration_ms', 'runs')
RANGES = {'24h': 86400, '7d': 7 * 86400, '30d': 30 * 86400, 'all': None}
MAX_SPAN = 400 * 86400


class FilterError(ValueError):
    pass


def parse_filters(params, now_ts=None):
    """Validate query parameters (dict of str -> str). Unknown keys are errors."""
    allowed = set(FILTER_ENUMS) | set(FILTER_PATTERNS) | {'range', 'from', 'to', 'issue', 'pr', 'metric',
                                                           'limit', 'offset', 'sort', 'dir', 'bucket'}
    for key in params:
        if key not in allowed:
            raise FilterError('unknown parameter')
    now_ts = now() if now_ts is None else now_ts
    f = {'range': params.get('range', '30d')}
    if f['range'] not in RANGES and f['range'] != 'custom':
        raise FilterError('invalid range')
    if f['range'] == 'custom':
        def stamp(value):
            if not isinstance(value, str) or len(value) > 40:
                raise ValueError
            moment = datetime.datetime.fromisoformat(value)
            if moment.tzinfo is None:
                moment = moment.replace(tzinfo=datetime.timezone.utc)
            return moment.timestamp()
        try:
            start, end = stamp(params['from']), stamp(params['to'])
        except (KeyError, ValueError, TypeError):
            raise FilterError('custom range needs from/to as YYYY-MM-DD or ISO time') from None
        if re.fullmatch(r'\d{4}-\d{2}-\d{2}', params['to']):
            end += 86400  # inclusive end date
        if not end > start or end - start > MAX_SPAN:
            raise FilterError('invalid custom range')
        f['from'], f['to'] = start, end
    elif RANGES[f['range']] is None:
        f['from'], f['to'] = None, None
    else:
        f['from'], f['to'] = now_ts - RANGES[f['range']], None
    for key, choices in FILTER_ENUMS.items():
        if key in params:
            if params[key] not in choices:
                raise FilterError('invalid ' + key)
            f[key] = params[key]
    for key, pattern in FILTER_PATTERNS.items():
        if key in params:
            if not pattern.fullmatch(params[key]):
                raise FilterError('invalid ' + key)
            f[key] = params[key]
    for key in ('issue', 'pr'):
        if key in params:
            if not re.fullmatch(r'[1-9][0-9]{0,8}', params[key]):
                raise FilterError('invalid ' + key)
            f[key] = int(params[key])
    f['metric'] = params.get('metric', 'total_tokens')
    if f['metric'] not in METRICS:
        raise FilterError('invalid metric')
    for key, default, top in (('limit', 100, 1000), ('offset', 0, 10**6)):
        value = params.get(key, str(default))
        if not re.fullmatch(r'[0-9]{1,7}', value) or int(value) > top:
            raise FilterError('invalid ' + key)
        f[key] = int(value)
    f['sort'] = params.get('sort', 'started_at')
    if f['sort'] not in ('started_at', 'duration_ms', 'total_tokens', 'input_tokens', 'output_tokens', 'provider_requests'):
        raise FilterError('invalid sort')
    f['dir'] = params.get('dir', 'desc')
    if f['dir'] not in ('asc', 'desc'):
        raise FilterError('invalid dir')
    f['bucket'] = params.get('bucket', 'auto')
    if f['bucket'] not in ('auto', 'hour', 'day'):
        raise FilterError('invalid bucket')
    return f


COLUMN_FOR = {'provider': 'provider', 'role': 'role', 'status': 'status', 'task': 'task_category',
              'effort': 'effort', 'attempt': 'attempt_kind', 'failure': 'failure_kind',
              'profile': 'profile', 'repo': 'repo', 'issue': 'issue_number', 'pr': 'pr_number'}


def where(f, time_col='started_at'):
    clauses, args = [], []
    if f.get('from') is not None:
        clauses.append(f'{time_col} >= ?')
        args.append(f['from'])
    if f.get('to') is not None:
        clauses.append(f'{time_col} < ?')
        args.append(f['to'])
    for key, col in COLUMN_FOR.items():
        if key in f:
            clauses.append(f'{col} = ?')
            args.append(f[key])
    if 'model' in f:
        clauses.append('COALESCE(resolved_model, requested_model) = ?')
        args.append(f['model'])
    return (' WHERE ' + ' AND '.join(clauses)) if clauses else '', args


TOTAL = '(input_tokens + output_tokens)'
METRIC_SQL = {'total_tokens': TOTAL, 'input_tokens': 'input_tokens',
              'uncached_input_tokens': '(input_tokens - cached_input_tokens)',
              'cached_input_tokens': 'cached_input_tokens', 'output_tokens': 'output_tokens',
              'reasoning_tokens': 'reasoning_tokens', 'provider_requests': 'provider_requests',
              'duration_ms': 'duration_ms', 'runs': '1'}


def _group(conn, f, column, metric_sql, base, args):
    rows = conn.execute(f'SELECT {column} AS key, COUNT(*) AS runs, SUM({metric_sql}) AS value, '
                        f'SUM(CASE WHEN {metric_sql} IS NULL THEN 1 ELSE 0 END) AS unknown '
                        f'FROM runs{base} GROUP BY {column} ORDER BY value DESC NULLS LAST, runs DESC', args).fetchall()
    return [{'key': r['key'], 'runs': r['runs'], 'value': r['value'], 'unknown': r['unknown']} for r in rows]


def summary(conn, f):
    base, args = where(f)
    metric_sql = METRIC_SQL[f['metric']]
    totals = conn.execute(f'''SELECT COUNT(*) runs,
        SUM(status='success') success, SUM(status='failed') failed, SUM(status='interrupted') interrupted,
        SUM(status='running') running, SUM(status IN ('launch_error','unknown')) other,
        SUM(failure_kind='quota_exhausted') quota_exhausted,
        SUM(handoff_from_run_id IS NOT NULL) handoffs,
        SUM(input_tokens) input_tokens, SUM(cached_input_tokens) cached_input_tokens,
        SUM(cache_write_tokens) cache_write_tokens, SUM(output_tokens) output_tokens,
        SUM(reasoning_tokens) reasoning_tokens, SUM({TOTAL}) total_tokens,
        SUM(provider_requests) provider_requests, SUM(duration_ms) duration_ms,
        SUM(input_tokens IS NULL) usage_unknown, SUM(input_tokens IS NOT NULL) usage_known,
        SUM(provider_requests IS NULL) requests_unknown, SUM(reasoning_tokens IS NULL) reasoning_unknown,
        SUM(resolved_model IS NULL) resolved_unknown, SUM(cached_input_tokens IS NULL) cached_unknown,
        SUM(input_tokens = 0 AND output_tokens = 0) usage_known_zero,
        SUM(role='lead') lead_runs, SUM(CASE WHEN role='lead' THEN {TOTAL} END) lead_tokens,
        SUM(role='lead' AND input_tokens IS NULL) lead_unknown
        FROM runs{base}''', args).fetchone()
    out = {'filters': {k: v for k, v in f.items() if k not in ('limit', 'offset')}, 'totals': dict(totals)}
    for dim, col in (('provider', 'provider'), ('model', 'COALESCE(resolved_model, requested_model)'),
                     ('role', 'role'), ('profile', 'profile'), ('task', 'task_category'), ('effort', 'effort'),
                     ('status', 'status'), ('attempt', 'attempt_kind'), ('failure', 'failure_kind')):
        out['by_' + dim] = _group(conn, f, col, metric_sql, base, args)
    # Model provenance: requested vs provider-resolved per run, never merged silently.
    out['model_provenance'] = [dict(r) for r in conn.execute(
        f'SELECT provider, auth_route, quota_scope, profile, requested_model, resolved_model, '
        f'resolved_model_provenance AS provenance, COUNT(*) runs FROM runs{base} '
        f'GROUP BY 1,2,3,4,5,6,7 ORDER BY runs DESC', args)]
    span = (f.get('to') or now()) - (f.get('from') or (conn.execute(f'SELECT MIN(started_at) FROM runs{base}', args).fetchone()[0] or now()))
    bucket = f['bucket'] if f['bucket'] != 'auto' else ('hour' if span <= 3 * 86400 else 'day')
    size = 3600 if bucket == 'hour' else 86400
    out['bucket'] = bucket
    out['timeseries'] = [dict(r) for r in conn.execute(
        f'SELECT CAST(started_at / {size} AS INTEGER) * {size} AS t, provider, COUNT(*) runs, '
        f'SUM({metric_sql}) value, SUM(CASE WHEN {metric_sql} IS NULL THEN 1 ELSE 0 END) unknown '
        f'FROM runs{base} GROUP BY 1, 2 ORDER BY 1', args)]
    out['efficiency'] = efficiency(conn, f)
    out['waste'] = waste(conn, f, base, args)
    out['quota_recovery'] = quota_recovery(conn, f)
    out['polls'] = polls(conn, f)
    out['polls_summary'] = polls_summary(out['polls'])
    out['cost'] = cost(conn, base, args)
    return out


def efficiency(conn, f):
    """Primary metric: attributable worker usage per merged PR.

    Denominator: PRs merged inside the date window (repo/PR filters apply).
    Numerator per PR: every worker run attributed to that PR via its issue
    branch -- initial attempts, retries, handoffs, interrupted runs and review
    rework -- regardless of when the run happened. Each run maps to at most one
    PR, so nothing is counted twice. Lead usage is shared across PRs and reported
    separately as unallocated; it is never spread into the per-PR numerator.
    Other filters (provider/model/role...) narrow the numerator's runs.
    """
    clauses, args = ["g.kind='pr'", 'g.merged_at IS NOT NULL'], []
    if f.get('from') is not None:
        clauses.append('g.merged_at >= ?')
        args.append(f['from'])
    if f.get('to') is not None:
        clauses.append('g.merged_at < ?')
        args.append(f['to'])
    if 'repo' in f:
        clauses.append('g.repo = ?')
        args.append(f['repo'])
    if 'pr' in f:
        clauses.append('g.number = ?')
        args.append(f['pr'])
    run_f = {k: v for k, v in f.items() if k not in ('from', 'to', 'pr', 'issue', 'repo')}
    run_where, run_args = where(run_f)
    run_where = run_where.replace(' WHERE ', ' AND ') if run_where else ''
    prs = conn.execute(f'''SELECT g.repo, g.number, g.merged_at, g.head_issue,
        COUNT(r.run_id) runs, SUM(r.attempt_kind IN ('retry','handoff')) retries,
        SUM(r.attempt_kind='handoff') handoffs, SUM(r.attempt_kind='rework') rework,
        SUM(r.status IN ('failed','interrupted')) wasted_runs,
        SUM(r.input_tokens + r.output_tokens) total_tokens, SUM(r.input_tokens - r.cached_input_tokens) uncached_input_tokens,
        SUM(r.output_tokens) output_tokens, SUM(r.provider_requests) provider_requests, SUM(r.duration_ms) duration_ms,
        SUM(r.run_id IS NOT NULL AND r.input_tokens IS NULL) usage_unknown,
        GROUP_CONCAT(DISTINCT COALESCE(r.resolved_model, r.requested_model)) models
        FROM github_items g LEFT JOIN runs r ON r.pr_number = g.number AND r.repo = g.repo AND r.role='worker'{run_where}
        WHERE {' AND '.join(clauses)} GROUP BY g.repo, g.number ORDER BY g.merged_at''', [*run_args, *args]).fetchall()
    prs = [dict(r) for r in prs]
    # Team PRs: built on a launcher issue branch or carrying attributed runs. Merged
    # PRs from outside the team launcher are counted separately, not as denominators.
    team = [p for p in prs if p['head_issue'] is not None or p['runs']]
    other = len(prs) - len(team)
    prs = team
    with_runs = [p for p in prs if p['runs']]
    complete = [p for p in with_runs if not p['usage_unknown']]
    lead_f = dict(run_f, role='lead')
    lead_f['from'], lead_f['to'] = f.get('from'), f.get('to')
    lw, la = where(lead_f)
    lead = conn.execute(f'SELECT COUNT(*) runs, SUM({TOTAL}) total_tokens, SUM(input_tokens IS NULL) unknown '
                        f'FROM runs{lw}', la).fetchone() if f.get('role') in (None, 'lead') else None
    unmerged_f = dict(run_f, role='worker')
    uw, ua = where(dict(unmerged_f, **{'from': f.get('from'), 'to': f.get('to')}))
    unattributed = conn.execute(
        f'SELECT COUNT(*) runs, SUM({TOTAL}) total_tokens FROM runs{uw} {"AND" if uw else "WHERE"} '
        "(pr_number IS NULL OR pr_number NOT IN (SELECT number FROM github_items WHERE kind='pr' AND merged_at IS NOT NULL))",
        ua).fetchone()
    merged = len(prs)
    numerator = sum(p['total_tokens'] or 0 for p in complete)
    values = sorted(p['total_tokens'] for p in complete)
    median = None
    if values:
        mid = len(values) // 2
        median = values[mid] if len(values) % 2 else (values[mid - 1] + values[mid]) / 2
    return {
        'definition': 'Attributable worker tokens (input incl. cache + output) per PR merged in the window; '
                      'includes initial attempts, retries, quota handoffs, interrupted runs and review rework on the PR issue '
                      'branch; lead usage is shared and shown separately, never allocated.',
        'merged_prs': merged, 'merged_prs_with_runs': len(with_runs), 'merged_prs_complete': len(complete),
        'merged_prs_outside_team': other,
        'mean_tokens_per_merged_pr': numerator / len(complete) if complete else None,
        'median_tokens_per_merged_pr': median,
        'coverage_warning': (merged != len(complete)),
        'shared_lead': {'runs': lead['runs'], 'total_tokens': lead['total_tokens'], 'usage_unknown': lead['unknown'],
                        'per_merged_pr_unallocated': (lead['total_tokens'] / merged if merged and lead['total_tokens'] is not None else None)}
        if lead is not None else None,
        'unattributed_worker': dict(unattributed),
        'prs': prs,
    }


def waste(conn, f, base, args):
    extra = ' AND ' if base else ' WHERE '
    rows = {}
    for name, cond in (('failed_or_interrupted', "status IN ('failed','interrupted')"),
                       ('quota_interrupted', "failure_kind = 'quota_exhausted'"),
                       ('retries', "attempt_kind IN ('retry','handoff')"),
                       ('handoffs', "attempt_kind = 'handoff' OR handoff_from_run_id IS NOT NULL"),
                       ('rework', "attempt_kind = 'rework'"),
                       ('periodic_lead_wakes', "role='lead' AND wake_reasons LIKE '%refresh%'"),
                       ('compacted_runs', 'compactions > 0')):
        r = conn.execute(f'SELECT COUNT(*) runs, SUM({TOTAL}) total_tokens, SUM(input_tokens IS NULL) unknown '
                         f'FROM runs{base}{extra}{cond}', args).fetchone()
        rows[name] = dict(r)
    totals = conn.execute(f'SELECT SUM(cached_input_tokens) cached, SUM(input_tokens) input FROM runs{base}'
                          f'{extra}cached_input_tokens IS NOT NULL', args).fetchone()
    rows['cached_input_share'] = (totals['cached'] / totals['input']) if totals['input'] else None
    return rows


def quota_recovery(conn, f=None):
    """Structured quota blocks, reset provenance, handoff lineage and task outcomes."""
    if f is None:
        f = {}
    clauses, args = [], []
    if f.get('from') is not None:
        clauses.append('q.observed_at >= ?')
        args.append(f['from'])
    if f.get('to') is not None:
        clauses.append('q.observed_at < ?')
        args.append(f['to'])
    if 'provider' in f:
        clauses.append('(q.provider = ? OR q.successor_provider = ?)')
        args.extend([f['provider'], f['provider']])
    if 'profile' in f:
        clauses.append('(q.profile = ? OR q.successor_profile = ?)')
        args.extend([f['profile'], f['profile']])
    if 'issue' in f:
        clauses.append('q.issue_number = ?')
        args.append(f['issue'])
    if 'pr' in f:
        clauses.append('q.pr_number = ?')
        args.append(f['pr'])
    w = (' WHERE ' + ' AND '.join(clauses)) if clauses else ''
    rows = conn.execute(f'''
        SELECT q.*,
               (r1.input_tokens + r1.output_tokens) AS failed_attempt_tokens,
               r1.duration_ms AS failed_attempt_duration_ms,
               (r2.input_tokens + r2.output_tokens) AS successor_attempt_tokens,
               r2.duration_ms AS successor_attempt_duration_ms,
               r2.status AS successor_status
        FROM quota_events q
        LEFT JOIN runs r1 ON r1.run_id = q.run_id
        LEFT JOIN runs r2 ON r2.run_id = q.successor_run_id
        {w}
        ORDER BY q.observed_at DESC, q.event_id
    ''', args).fetchall()
    events = []
    for r in rows:
        d = dict(r)
        t1 = nonneg_int(d.get('failed_attempt_tokens'))
        has_successor = bool(d.get('successor_run_id'))
        t2 = nonneg_int(d.get('successor_attempt_tokens')) if has_successor else None
        # Honest token attribution semantics:
        # 1. Useful predecessor work is NOT all transfer overhead; native CLIs do not separately
        #    meter handoff-prompt-only tokens vs productive work, so transfer_overhead_tokens
        #    remains None (unknown) unless separately measurable.
        # 2. Combined full-task tokens across a handoff are reported ONLY when a successor attempt
        #    exists AND every required attempt in the handoff pair has known token usage.
        #    When no successor exists or any required attempt's usage is NULL, combined_task_tokens
        #    stays None, and known_subtotal_tokens + token_coverage explicitly label what is known.
        if not has_successor:
            combined_tokens = None
            known_subtotal = t1
            attempts_total = 1
            attempts_known = 1 if t1 is not None else 0
            token_coverage = 'no_successor_yet' if t1 is not None else 'no_successor_usage_unknown'
        elif t1 is not None and t2 is not None:
            combined_tokens = t1 + t2
            known_subtotal = t1 + t2
            attempts_total = 2
            attempts_known = 2
            token_coverage = 'complete_both_attempts_known'
        else:
            combined_tokens = None
            known_subtotal = t1 if t1 is not None else t2
            attempts_total = 2
            attempts_known = (1 if t1 is not None else 0) + (1 if t2 is not None else 0)
            token_coverage = 'partial_attempt_usage_unknown' if known_subtotal is not None else 'all_attempts_usage_unknown'
        transfer_overhead_tokens = None
        events.append({
            'event_id': d['event_id'] if isinstance(d.get('event_id'), str) and re.fullmatch(r'[0-9a-f]{32}', d['event_id']) else None,
            'run_id': d['run_id'] if isinstance(d.get('run_id'), str) and re.fullmatch(r'[0-9a-f]{32}', d['run_id']) else None,
            'role': safe_enum(d.get('role'), ROLES),
            'provider': safe_enum(d.get('provider'), PROVIDERS),
            'profile': safe(d.get('profile'), PROFILE_RE),
            'quota_scope': d.get('quota_scope') if isinstance(d.get('quota_scope'), str) and re.fullmatch(r'[a-z0-9:_-]{2,48}', d['quota_scope']) else None,
            'session_key': d['session_key'] if isinstance(d.get('session_key'), str) and re.fullmatch(r'[0-9a-f]{24}', d['session_key']) else None,
            'repo': safe(d.get('repo'), REPO_RE),
            'issue_number': nonneg_int(d.get('issue_number')),
            'pr_number': nonneg_int(d.get('pr_number')),
            'logical_task_id': safe(d.get('logical_task_id'), LOGICAL_TASK_RE),
            'worktree_key': safe(d.get('worktree_key'), WORKTREE_KEY_RE),
            'blocked_reason': safe_enum(d.get('blocked_reason'), BLOCKED_REASONS),
            'observed_at': nonneg_float(d.get('observed_at')),
            'reset_at': nonneg_float(d.get('reset_at')),
            'reset_timezone': safe(d.get('reset_timezone'), TZ_LABEL_RE),
            'reset_provenance': safe_enum(d.get('reset_provenance'), RESET_PROVENANCES, 'unknown'),
            'decision': safe_enum(d.get('decision'), QUOTA_DECISIONS, 'pending'),
            'successor_run_id': d['successor_run_id'] if isinstance(d.get('successor_run_id'), str) and re.fullmatch(r'[0-9a-f]{32}', d['successor_run_id']) else None,
            'successor_profile': safe(d.get('successor_profile'), PROFILE_RE),
            'successor_provider': safe_enum(d.get('successor_provider'), PROVIDERS),
            'successor_session_key': d['successor_session_key'] if isinstance(d.get('successor_session_key'), str) and re.fullmatch(r'[0-9a-f]{24}', d['successor_session_key']) else None,
            'handoff_kind': safe_enum(d.get('handoff_kind'), HANDOFF_KINDS),
            'handoff_at': nonneg_float(d.get('handoff_at')),
            'transfer_overhead_ms': nonneg_int(d.get('transfer_overhead_ms')),
            'failed_attempt_tokens': t1,
            'failed_attempt_duration_ms': nonneg_int(d.get('failed_attempt_duration_ms')),
            'successor_attempt_tokens': t2,
            'successor_attempt_duration_ms': nonneg_int(d.get('successor_attempt_duration_ms')),
            'combined_task_tokens': combined_tokens,
            'known_subtotal_tokens': known_subtotal,
            'attempts_total': attempts_total,
            'attempts_usage_known': attempts_known,
            'token_coverage': token_coverage,
            'transfer_overhead_tokens': transfer_overhead_tokens,
            'outcome': d.get('outcome') if isinstance(d.get('outcome'), str) and re.fullmatch(r'[a-z0-9_]{2,40}', d['outcome']) else None,
        })
    return {
        'total_quota_events': len(events),
        'known_reset_count': sum(1 for e in events if e['reset_at'] is not None),
        'unknown_reset_count': sum(1 for e in events if e['reset_at'] is None),
        'handoff_count': sum(1 for e in events if e['successor_run_id'] or e['decision'] == 'reassign'),
        'events': events,
    }


def polls(conn, f):
    clauses, args = [], []
    if f.get('from') is not None:
        clauses.append('at >= ?')
        args.append(f['from'])
    if f.get('to') is not None:
        clauses.append('at < ?')
        args.append(f['to'])
    w = (' WHERE ' + ' AND '.join(clauses)) if clauses else ''
    rows = conn.execute(
        f'SELECT outcome, source_kind, COUNT(*) n, '
        f'SUM(CASE WHEN ai_launched = 1 THEN 1 ELSE 0 END) ai, '
        f'SUM(CASE WHEN ai_launched = 0 THEN 1 ELSE 0 END) zero_model_skips, '
        f'SUM(CASE WHEN ai_launched IS NULL THEN 1 ELSE 0 END) ai_unknown '
        f'FROM polls{w} GROUP BY 1, 2 ORDER BY n DESC', args
    ).fetchall()
    return [dict(r) for r in rows]


def polls_summary(poll_rows):
    """Distinguish verified zero-model skips from unclassified historical activations."""
    rows = list(poll_rows or [])
    return {
        'total_polls': sum(r.get('n') or 0 for r in rows),
        'ai_launched_count': sum(r.get('ai') or 0 for r in rows),
        'verified_zero_model_skips': sum(
            (r.get('zero_model_skips') or 0) for r in rows
            if r.get('outcome') in VERIFIED_ZERO_MODEL_OUTCOMES
        ),
        'unmatched_historical_activations': sum(
            (r.get('ai_unknown') or 0) for r in rows
            if r.get('outcome') in UNMATCHED_POLL_OUTCOMES
        ),
        'live_polls': sum((r.get('n') or 0) for r in rows if r.get('source_kind') == 'live'),
        'imported_polls': sum((r.get('n') or 0) for r in rows if r.get('source_kind') == 'import'),
    }


def cost(conn, base, args):
    """Provider-reported/estimated money is grouped by basis and never summed across bases."""
    rows = conn.execute(f'SELECT provider, cost_basis, COUNT(*) runs, SUM(provider_cost_usd) usd, '
                        f'SUM(provider_cost_usd IS NULL) unknown FROM runs{base} GROUP BY 1, 2', args).fetchall()
    out = [dict(r) for r in rows]
    cards = conn.execute('SELECT version, source, COUNT(*) models FROM rate_cards GROUP BY 1, 2').fetchall()
    estimates = []
    for card in cards:
        # Runs are priced only when every needed token count and rate is known.
        r = conn.execute(f'''SELECT COUNT(*) runs, COUNT(v) priced, SUM(v) usd FROM (SELECT
              ((input_tokens - cached_input_tokens - COALESCE(cache_write_tokens, 0)) * rc.input_per_mtok
              + cached_input_tokens * rc.cached_input_per_mtok
              + COALESCE(cache_write_tokens, 0) * COALESCE(rc.cache_write_per_mtok, rc.input_per_mtok)
              + output_tokens * rc.output_per_mtok) / 1e6 v
            FROM runs LEFT JOIN rate_cards rc ON rc.version = ? AND rc.model = COALESCE(resolved_model, requested_model)
            {base})''', [card['version'], *args]).fetchone()
        estimates.append({'version': card['version'], 'source': card['source'], 'runs_in_scope': r['runs'],
                          'runs_priced': r['priced'], 'usd': r['usd']})
    return {'by_basis': out, 'api_equivalent_estimates': estimates}


EXPORT_COLUMNS = ('run_id', 'parent_run_id', 'parent_provenance', 'session_key', 'role', 'profile',
                  'profile_provenance', 'provider', 'auth_route', 'requested_model', 'requested_model_source',
                  'resolved_model', 'resolved_model_provenance', 'effort', 'cli_version', 'repo',
                  'issue_number', 'pr_number', 'logical_task_id', 'worktree_key', 'task_category',
                  'attempt_kind', 'attempt_number', 'trigger', 'wake_reasons', 'started_at',
                  'finished_at', 'duration_ms', 'status', 'exit_code', 'failure_kind',
                  'blocked_reason', 'quota_scope', 'reset_at', 'reset_timezone', 'reset_provenance',
                  'handoff_from_run_id', 'handoff_from_profile', 'handoff_from_provider',
                  'handoff_from_session_key', 'handoff_kind', *USAGE_FIELDS, 'usage_method',
                  'usage_semantics', 'usage_note', 'native_turns', 'tool_calls',
                  'provider_requests', 'provider_requests_source', 'compactions',
                  'provider_cost_usd', 'cost_basis', 'source_kind')


def runs(conn, f):
    base, args = where(f)
    order = {'total_tokens': TOTAL}.get(f['sort'], f['sort'])
    rows = conn.execute(f'SELECT {", ".join(EXPORT_COLUMNS)} FROM runs{base} '
                        f'ORDER BY {order} {f["dir"].upper()} NULLS LAST, run_id LIMIT ? OFFSET ?',
                        [*args, f['limit'], f['offset']]).fetchall()
    count = conn.execute(f'SELECT COUNT(*) FROM runs{base}', args).fetchone()[0]
    return {'total': count, 'rows': [sanitize_row(dict(r)) for r in rows]}


def sanitize_row(row):
    """Last-line defense for API/export output: re-validate every field's shape."""
    out = {}
    for k in EXPORT_COLUMNS:
        v = row.get(k)
        if k in ('run_id', 'parent_run_id', 'handoff_from_run_id'):
            v = v if isinstance(v, str) and re.fullmatch(r'[0-9a-f]{32}', v) else None
        elif k in ('session_key', 'handoff_from_session_key'):
            v = v if isinstance(v, str) and re.fullmatch(r'[0-9a-f]{24}', v) else None
        elif k in ('requested_model', 'resolved_model'):
            v = safe(v, MODEL_RE)
        elif k in ('profile', 'handoff_from_profile'):
            v = safe(v, PROFILE_RE)
        elif k in ('provider', 'handoff_from_provider'):
            v = safe_enum(v, PROVIDERS)
        elif k == 'repo':
            v = safe(v, REPO_RE)
        elif k == 'cli_version':
            v = safe(v, VERSION_RE)
        elif k == 'logical_task_id':
            v = safe(v, LOGICAL_TASK_RE)
        elif k == 'worktree_key':
            v = safe(v, WORKTREE_KEY_RE)
        elif k == 'reset_timezone':
            v = safe(v, TZ_LABEL_RE)
        elif k in ('started_at', 'finished_at', 'provider_cost_usd', 'reset_at'):
            v = nonneg_float(v)
        elif k in ('issue_number', 'pr_number', 'attempt_number', 'duration_ms', 'exit_code', *USAGE_FIELDS,
                   'native_turns', 'tool_calls', 'provider_requests', 'compactions'):
            v = nonneg_int(v) if k != 'exit_code' else (v if type(v) is int and -255 <= v <= 255 else None)
        else:
            v = v if isinstance(v, str) and re.fullmatch(r'[a-z0-9_.;:,= -]{1,120}', v) else None
        out[k] = v
    return out


def export_rows(conn, f):
    f = dict(f, limit=1000000, offset=0)
    return runs(conn, f)['rows']


# ---------------------------------------------------------------------------
# CLI: historical import into an explicitly chosen (candidate) database.

def _profiles_from_team():
    here = Path(__file__).resolve().with_name('team.py')
    import importlib.util
    spec = importlib.util.spec_from_file_location('_team_profiles', here)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.PROFILES, module.SLUG


def main(argv=None):
    parser = argparse.ArgumentParser(description='Usage analytics import/report (no model calls).')
    sub = parser.add_subparsers(dest='action', required=True)
    imp = sub.add_parser('import', help='idempotent historical import of native team logs')
    imp.add_argument('--db', required=True, type=Path)
    imp.add_argument('--state', required=True, type=Path)
    imp.add_argument('--codex-sessions', type=Path)
    imp.add_argument('--claude-projects', type=Path)
    imp.add_argument('--github-issues', type=Path, help='gh issue list --json number,state,createdAt,closedAt,labels,title')
    imp.add_argument('--github-prs', type=Path, help='gh pr list --json number,state,mergedAt,createdAt,closedAt,headRefName,body')
    imp.add_argument('--journal', type=Path, help='journalctl --user -u vael-team-lead.service -o short-unix output')
    rates = sub.add_parser('rates', help='load a versioned, sourced API-equivalent rate card')
    rates.add_argument('--db', required=True, type=Path)
    rates.add_argument('card', type=Path)
    wrap = sub.add_parser('import-wrappers', help='idempotent import of operator wrapper runs from an explicit manifest')
    wrap.add_argument('--db', required=True, type=Path)
    wrap.add_argument('manifest', type=Path, help='JSON list of wrapper entries (see import_wrapper_runs)')
    args = parser.parse_args(argv)
    if args.action == 'import-wrappers':
        print(json.dumps(import_wrapper_runs(args.db, json.loads(args.manifest.read_text())), indent=2, sort_keys=True))
        return 0
    if args.action == 'rates':
        conn = connect(args.db)
        try:
            load_rate_card(conn, args.card)
        finally:
            conn.close()
        return 0
    profiles, slug = _profiles_from_team()
    github = None
    if args.github_issues or args.github_prs:
        github = {'issues': json.loads(args.github_issues.read_text()) if args.github_issues else [],
                  'prs': json.loads(args.github_prs.read_text()) if args.github_prs else []}
    report = import_history(args.db, args.state, repo=slug, profiles=profiles,
                            sessions=NativeSessions(args.codex_sessions, args.claude_projects), github=github,
                            journal=args.journal.read_text() if args.journal else None)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == '__main__':
    sys.exit(main())
