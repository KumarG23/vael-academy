import concurrent.futures
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

TOOLS_DIR = Path(__file__).resolve().parents[1]

ua_spec = importlib.util.spec_from_file_location('usage_analytics', TOOLS_DIR / 'usage_analytics.py')
assert ua_spec is not None and ua_spec.loader is not None
ua = importlib.util.module_from_spec(ua_spec)
ua_spec.loader.exec_module(ua)

team_spec = importlib.util.spec_from_file_location('team', TOOLS_DIR / 'team.py')
assert team_spec is not None and team_spec.loader is not None
team = importlib.util.module_from_spec(team_spec)
team_spec.loader.exec_module(team)


class UsageAnalyticsAndQuotaRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.state = self.root / 'state'
        self.repo = self.root / 'repo'
        self.db = self.state / 'usage-analytics.sqlite3'
        self.state.mkdir(parents=True, exist_ok=True)
        (self.state / 'worktrees').mkdir(exist_ok=True)
        self.repo.mkdir(parents=True, exist_ok=True)
        self.patches = [
            patch.object(team, 'STATE', self.state),
            patch.object(team, 'REPO', self.repo),
            patch.dict(os.environ, {'VAEL_USAGE_DB': str(self.db)}),
        ]
        for p in self.patches:
            p.start()
            self.addCleanup(p.stop)

    def test_sol_developer_and_emergency_hierarchy(self):
        self.assertEqual(team.LEAD, 'sol')
        self.assertEqual(team.PROFILES['sol'], ('codex', 'gpt-6.1-sol', 'high'))
        self.assertEqual(team.PROFILES['sol-dev'], ('codex', 'gpt-6.1-sol', 'medium'))
        self.assertIn('sol-dev', team.SENIOR_WORKERS)
        self.assertEqual(team.EMERGENCY_WORKERS, ('astra',))
        self.assertEqual(team.PROFILES['astra'][2], 'high')
        self.assertEqual(team.PROFILES['fable'][2], 'high')
        (self.state / 'disabled-fable').write_text('paid credits required; no spend authorized')
        for tier in ('junior', 'senior'):
            peers = team.eligible_peers(task_tier=tier, now_ts=1000.0)
            self.assertIn('sol-dev', peers)
            self.assertNotIn('sol', peers)
            self.assertNotIn('astra', peers)
            self.assertNotIn('fable', peers)
        self.assertIn('astra', team.eligible_peers(task_tier='emergency', now_ts=1000.0))
        self.assertNotIn('fable', team.eligible_peers(task_tier='emergency', now_ts=1000.0))
        self.assertIn('model_reasoning_effort="medium"', team.command('sol-dev'))
        self.assertIn('model_reasoning_effort="high"', team.command('sol'))
        self.assertEqual(team._quota_scope_and_provider('sol')[1],
                         team._quota_scope_and_provider('sol-dev')[1])
        prompt = team.lead_prompt([], [], [], ['test'])
        self.assertIn('Sole emergency developer', prompt)
        self.assertIn('sol-dev', prompt)
        self.assertNotIn('not emergency-only', prompt)

    def test_claude_session_limit_classification_and_reset_parsing(self):
        # Exact envelope shape from real Claude subscription session-limit logs on 2026-10-22.
        oct22_noon = 1792670400.0  # 2026-10-22T12:00:00Z
        records = [{
            'type': 'result',
            'subtype': 'success',
            'is_error': True,
            'duration_ms': 2016,
            'num_turns': 1,
            'result': "You've hit your session limit · resets 2:50pm (UTC)",
            'stop_reason': 'stop_sequence',
            'session_id': '5e550000-c1a0-4de0-8000-000000000015',
            'total_cost_usd': 0,
            'usage': {
                'input_tokens': 0,
                'cache_creation_input_tokens': 0,
                'cache_read_input_tokens': 0,
                'output_tokens': 0,
            },
            'modelUsage': {},
            'terminal_reason': 'api_error',
            'api_error_status': 429,
            'api_error': 'usage_limit_reached',
        }]
        info = ua.classify_native_failure('claude', records, 0, now_ts=oct22_noon)
        self.assertEqual(info['failure_kind'], 'quota_exhausted')
        self.assertEqual(info['blocked_reason'], 'session_limit')
        self.assertEqual(info['reset_at'], 1792680600.0)  # 2026-10-22T14:50:00Z
        self.assertEqual(info['reset_timezone'], 'UTC')
        self.assertEqual(info['reset_provenance'], 'provider_error_text')

        # Also verify 0-token usage is recorded as known 0, not NULL, when modelUsage is empty.
        facts = ua.parse_native('claude', records)
        self.assertEqual(facts['terminal'], 'failed')
        self.assertEqual(facts['usage_method'], 'per_run_usage')
        self.assertEqual(facts['usage']['input_tokens'], 0)
        self.assertEqual(facts['usage']['output_tokens'], 0)

    def test_unknown_reset_stays_unknown_never_fabricated(self):
        records = [{
            'type': 'result',
            'subtype': 'success',
            'is_error': True,
            'result': 'Rate limit exceeded for model',
            'api_error_status': 429,
        }]
        info = ua.classify_native_failure('claude', records, 1, now_ts=1792670400.0)
        self.assertEqual(info['failure_kind'], 'quota_exhausted')
        self.assertEqual(info['blocked_reason'], 'rate_limit')
        self.assertIsNone(info['reset_at'])
        self.assertIsNone(info['reset_timezone'])
        self.assertEqual(info['reset_provenance'], 'unknown')

    def test_false_positive_rejection_for_repaired_and_non_quota_failures(self):
        # 1. Intermediate failed tool call discussing "rate_limit" that was repaired before turn.completed
        codex_repaired = [
            {'type': 'thread.started', 'thread_id': '019a0b44-1111-2222-3333-444455556666'},
            {'type': 'item.completed', 'item': {'type': 'command_execution', 'exit_code': 1,
                                               'aggregated_output': 'FAIL: test_rate_limit_quota_exceeded'}},
            {'type': 'turn.completed', 'usage': {'input_tokens': 500, 'cached_input_tokens': 100, 'output_tokens': 50}},
        ]
        info = ua.classify_native_failure('codex', codex_repaired, 0)
        self.assertFalse(info['is_failed'])
        self.assertIsNone(info['failure_kind'])
        self.assertIsNone(info['blocked_reason'])

        # 2. Ordinary implementation/test failure
        exec_fail = [{'type': 'result', 'subtype': 'error_during_execution', 'is_error': True,
                      'result': 'AssertionError: expected 200 got 500'}]
        info = ua.classify_native_failure('claude', exec_fail, 1)
        self.assertEqual(info['failure_kind'], 'execution_failure')

        # 3. Auth failure
        auth_fail = [{'type': 'result', 'subtype': 'success', 'is_error': True,
                      'result': 'Not logged in · Please run /login'}]
        info = ua.classify_native_failure('claude', auth_fail, 1)
        self.assertEqual(info['failure_kind'], 'auth_failure')

        # 4. Permission failure
        perm_fail = [{'type': 'turn.failed', 'error': {'message': 'Permission denied (publickey)'}}]
        info = ua.classify_native_failure('codex', perm_fail, 1)
        self.assertEqual(info['failure_kind'], 'permission_failure')

        # 5. Network failure
        net_fail = [{'type': 'error', 'error': {'message': 'ECONNRESET: connection timed out'}}]
        info = ua.classify_native_failure('opencode', net_fail, 1)
        self.assertEqual(info['failure_kind'], 'network_failure')

    def test_cumulative_session_deltas_and_compaction_enrichment_without_double_counting(self):
        # Test AGY cumulative deltas across 2 runs + negative delta protection on run 3
        conn = ua.connect(self.db)
        try:
            r1_lines = [json.dumps({
                'status': 'SUCCESS',
                'conversation_id': 'c0de0000-a690-4000-8000-000000000020',
                'num_turns': 3,
                'usage': {'input_tokens': 1000, 'cache_read_tokens': 4000, 'output_tokens': 300, 'thinking_tokens': 100},
            })]
            r2_lines = [json.dumps({
                'status': 'SUCCESS',
                'conversation_id': 'c0de0000-a690-4000-8000-000000000020',
                'num_turns': 5,
                'usage': {'input_tokens': 1500, 'cache_read_tokens': 6500, 'output_tokens': 500, 'thinking_tokens': 180},
            })]
            row1 = ua.build_run(source_key='log:issue-14-1000.log', source_kind='import', role='worker',
                                provider='agy', profile='argon', profile_provenance='assignment_metadata',
                                requested_model='gemini-4-argon-medium', effort='medium',
                                started_at=1000.0, finished_at=1010.0, exit_code=0, lines=r1_lines, issue_number=14)
            row2 = ua.build_run(source_key='log:issue-14-2000.log', source_kind='import', role='worker',
                                provider='agy', profile='argon', profile_provenance='assignment_metadata',
                                requested_model='gemini-4-argon-medium', effort='medium',
                                started_at=2000.0, finished_at=2020.0, exit_code=0, lines=r2_lines, issue_number=14)
            ua.write(conn, lambda c: ua.finalize(c, row1))
            ua.write(conn, lambda c: ua.finalize(c, row2))

            rows = conn.execute("SELECT input_tokens, cached_input_tokens, output_tokens, reasoning_tokens, native_turns FROM runs WHERE provider='agy' ORDER BY started_at").fetchall()
            # Run 1: input = 1000 + 4000 = 5000, cached = 4000, output = 300, reasoning = 100, turns = 3
            self.assertEqual(tuple(rows[0]), (5000, 4000, 300, 100, 3))
            # Run 2 delta: input = (1500+6500) - 5000 = 3000, cached = 6500 - 4000 = 2500, output = 200, reasoning = 80, turns = 2
            self.assertEqual(tuple(rows[1]), (3000, 2500, 200, 80, 2))
        finally:
            conn.close()

    def test_codex_session_enrichment_preserves_historical_effort_and_compactions(self):
        codex_dir = self.root / 'codex_sessions'
        codex_dir.mkdir()
        tid = '019a0000-0000-7000-8000-000000000005'
        rollout = codex_dir / f'rollout-2026-10-22-{tid}.jsonl'
        rollout.write_text('\n'.join([
            json.dumps({'timestamp': '2026-10-22T01:00:00Z', 'type': 'session_meta', 'payload': {'cli_version': '0.115.0'}}),
            json.dumps({'timestamp': '2026-10-22T01:00:01Z', 'type': 'turn_context',
                        'payload': {'turn_id': 't1', 'model': 'gpt-6-astra', 'effort': 'high'}}),
            json.dumps({'timestamp': '2026-10-22T01:00:02Z', 'type': ' token_usage_record'.strip(),
                        'payload': {'turn_id': 't1', 'response_id': 'resp_1',
                                    'usage': {'input_tokens': 2000, 'cached_input_tokens': 1500,
                                              'cache_write_input_tokens': 0, 'output_tokens': 100,
                                              'reasoning_output_tokens': 60}}}),
            json.dumps({'timestamp': '2026-10-22T01:00:05Z', 'type': 'compacted', 'payload': {}}),
            json.dumps({'timestamp': '2026-10-22T01:00:06Z', 'type': 'token_usage_record',
                        'payload': {'turn_id': 't1', 'response_id': 'resp_compact',
                                    'usage': {'input_tokens': 3000, 'cached_input_tokens': 2000,
                                              'cache_write_input_tokens': 0, 'output_tokens': 150,
                                              'reasoning_output_tokens': 80}}}),
        ]))
        sessions = ua.NativeSessions(codex_root=codex_dir)
        start_ts = 1792630800.0  # 2026-10-22T01:00:00Z
        end_ts = start_ts + 20.0
        log_lines = [
            json.dumps({'type': 'thread.started', 'thread_id': tid}),
            # turn.completed omits compaction tokens (only reports 3000 instead of 5000)
            json.dumps({'type': 'turn.completed', 'usage': {'input_tokens': 3000, 'cached_input_tokens': 2000, 'output_tokens': 150}}),
        ]
        # Pass current profile default effort='medium', verify session turn_context overrides to 'high'
        row = ua.build_run(source_key='log:issue-5-100.log', source_kind='import', role='worker',
                           provider='codex', profile='astra', profile_provenance='assignment_metadata',
                           requested_model='gpt-6-astra', effort='medium',
                           started_at=start_ts, finished_at=end_ts, exit_code=0,
                           lines=log_lines, sessions=sessions, window_end=end_ts, issue_number=5)
        self.assertEqual(row['effort'], 'high')
        self.assertEqual(row['usage_method'], 'per_response_records')
        self.assertEqual(row['input_tokens'], 5000)  # 2000 + 3000 from token_usage_record, NOT summed with turn.completed
        self.assertEqual(row['compactions'], 1)
        self.assertEqual(row['provider_requests'], 2)

    def test_cooldown_stops_retry_storm_and_wakes_lead_once_per_material_transition(self):
        # Record a Claude session limit with known reset at t=2000
        team.record_provider_quota(
            'opus', 'session_limit',
            {'reset_at': 2000.0, 'reset_timezone': 'UTC', 'reset_provenance': 'provider_error_text'},
            issue_number=15, run_id='f1000000000000000000000000000015',
            session_key='5c0000000000000000000015', observed_at=1000.0,
        )
        # 1. While cooldown is active (t=1500), provider_quota_status is cooldown_active and start() refuses with 0 model calls
        q_active = team.provider_quota_status('opus', now_ts=1500.0)
        self.assertEqual(q_active['state'], 'cooldown_active')
        self.assertFalse(q_active['eligible'])
        with patch.object(team, 'provider_quota_status', return_value=q_active), patch.object(team, 'run') as gh_run:
            with self.assertRaisesRegex(RuntimeError, 'quota-blocked'):
                team.start(15, 'opus')
            gh_run.assert_not_called()

        # 2. Lead wake behavior across cooldown lifecycle:
        # Initial snapshot at t=1005 wakes once; saving receipt suppresses all ticks during [1005, 1999]
        parts_1005 = team.snapshot('head1', [], [], [], now_ts=1005.0)
        self.assertEqual(team.wake_reasons(parts_1005, now_ts=1005.0), ['first pass'])
        (self.state / 'lead-receipt.json').write_text(json.dumps({'parts': parts_1005, 'checked_at': 1005.0}))

        for tick in (1100.0, 1500.0, 1999.0):
            parts_tick = team.snapshot('head1', [], [], [], now_ts=tick)
            self.assertEqual(team.wake_reasons(parts_tick, now_ts=tick), [], f'unexpected wake at {tick}')

        # 3. At t=2001 (cooldown expired -> eligible_to_retry), snapshot changes and wakes lead ONCE with reason 'quota'
        parts_2001 = team.snapshot('head1', [], [], [], now_ts=2001.0)
        self.assertEqual(team.wake_reasons(parts_2001, now_ts=2001.0), ['quota'])
        (self.state / 'lead-receipt.json').write_text(json.dumps({'parts': parts_2001, 'checked_at': 2001.0}))

        # 4. Subsequent ticks at t=2100 do not re-wake while still in eligible_to_retry
        parts_2100 = team.snapshot('head1', [], [], [], now_ts=2100.0)
        self.assertEqual(team.wake_reasons(parts_2100, now_ts=2100.0), [])

    def test_unknown_reset_blocks_lane_and_wakes_only_once(self):
        team.record_provider_quota(
            'opus', 'rate_limit',
            {'reset_at': None, 'reset_timezone': None, 'reset_provenance': 'unknown'},
            issue_number=23, run_id='f1000000000000000000000000000023', observed_at=1000.0,
        )
        q_unk = team.provider_quota_status('opus', now_ts=5000.0)
        self.assertEqual(q_unk['state'], 'blocked_unknown_reset')
        self.assertFalse(q_unk['eligible'])
        self.assertIsNone(q_unk['reset_at'])

        parts_1000 = team.snapshot('head1', [], [], [], now_ts=1000.0)
        (self.state / 'lead-receipt.json').write_text(json.dumps({'parts': parts_1000, 'checked_at': 1000.0}))
        parts_1500 = team.snapshot('head1', [], [], [], now_ts=1500.0)
        self.assertEqual(team.wake_reasons(parts_1500, now_ts=1500.0), [])

    def test_exclusive_transfer_requires_old_worker_exit_and_preserves_wip_and_lineage(self):
        # Create a real git repo + worktree with uncommitted WIP and untracked files
        def git(cwd, *args):
            subprocess.run(['git', '-C', str(cwd), *args], check=True, capture_output=True, text=True)

        git(self.repo, 'init', '-b', 'main')
        git(self.repo, '-c', 'user.name=Test', '-c', 'user.email=t@example.invalid',
            'commit', '--allow-empty', '-m', 'initial')
        wt = self.state / 'worktrees/15'
        git(self.repo, 'worktree', 'add', '-b', 'team/issue-15', str(wt))
        (wt / 'tracked.gd').write_text('extends Node\n')
        git(wt, 'add', 'tracked.gd')
        git(wt, '-c', 'user.name=Test', '-c', 'user.email=t@example.invalid',
            'commit', '-m', 'WIP commit from opus')
        (wt / 'tracked.gd').write_text('extends Node\n# partial edit\n')
        (wt / 'untracked_notes.md').write_text('preserved untracked work\n')

        claude_sid = '5e550000-c1a0-4de0-8000-000000000015'
        claude_skey = ua.session_key_for('claude', claude_sid)
        failed_run_id = 'f1000000000000000000000000000015'
        assignment = {
            'profile': 'opus',
            'session_id': claude_sid,
            'issue': {'number': 15, 'title': 'Implement combat formula', 'body': 'Acceptance: tests pass'},
            'worktree': str(wt),
            'blocked': {
                'failure_kind': 'quota_exhausted',
                'blocked_reason': 'session_limit',
                'provider': 'claude',
                'profile': 'opus',
                'quota_scope': 'claude_subscription',
                'run_id': failed_run_id,
                'session_key': claude_skey,
                'worktree_key': 'issue-15',
                'observed_at': 1000.0,
                'reset_at': 5000.0,
                'reset_timezone': 'UTC',
                'reset_provenance': 'provider_error_text',
                'decision': 'pending',
            },
        }
        (self.state / 'issue-15.json').write_text(json.dumps(assignment))
        (self.state / 'issue-15.exit').write_text('1')

        # 1. Refuse handoff if tmux session is still active
        with patch.object(team, 'active', return_value=['vael-issue-15']):
            with self.assertRaisesRegex(RuntimeError, 'has not exited'):
                team.handoff(15, 'argon', now_ts=1020.0)

        # 2. Refuse handoff if recorded worker PID is still alive (even if tmux session is gone)
        (self.state / 'issue-15.pid').write_text(str(os.getpid()))
        with patch.object(team, 'active', return_value=[]):
            with self.assertRaisesRegex(RuntimeError, 'has not exited'):
                team.handoff(15, 'argon', now_ts=1020.0)
        (self.state / 'issue-15.pid').unlink()

        # 3. Once old worker has exited, cross-provider handoff (opus -> argon) succeeds:
        #    - resets session_id to None (never reuses Claude session ID with Argon!)
        #    - preserves old session lineage in handoff_history
        #    - preserves uncommitted/untracked files in worktree
        launched = []
        real_sub_run = subprocess.run
        def gh_safe_sub_run(args, *a, **kw):
            if args and args[0] == 'gh':
                return subprocess.CompletedProcess(args, 0, stdout='')
            return real_sub_run(args, *a, **kw)
        real_team_run = team.run
        def gh_safe_team_run(*args, **kwargs):
            if args and args[0] == 'gh':
                return ''
            return real_team_run(*args, **kwargs)
        with patch.object(team, 'active', return_value=[]), \
                patch.object(team, 'launch_worker', side_effect=lambda n, w: launched.append((n, w))), \
                patch.object(team.subprocess, 'run', side_effect=gh_safe_sub_run), \
                patch.object(team, 'run', side_effect=gh_safe_team_run):
            h_entry = team.handoff(15, 'argon', now_ts=1025.0)

            self.assertEqual(len(launched), 1)
            updated = json.loads((self.state / 'issue-15.json').read_text())
            self.assertEqual(updated['profile'], 'argon')
            self.assertIsNone(updated['session_id'])  # Cross-provider must NOT reuse Claude session_id
            self.assertNotIn(claude_sid, team.command('argon', updated['session_id']))
            self.assertEqual(h_entry['handoff_kind'], 'cross_provider_reassign')
            self.assertEqual(h_entry['from_profile'], 'opus')
            self.assertEqual(h_entry['from_session_id'], claude_sid)
            self.assertEqual(h_entry['from_session_key'], claude_skey)
            self.assertEqual((wt / 'tracked.gd').read_text(), 'extends Node\n# partial edit\n')
            self.assertEqual((wt / 'untracked_notes.md').read_text(), 'preserved untracked work\n')

            # Prompt for successor contains concise handoff summary (task, branch, files/progress, next action)
            prompt = team.worker_prompt(updated['issue'], handoff_info=updated['handoff_state'])
            self.assertIn('Lead-authorized handoff context:', prompt)
            self.assertIn('Previous owner `opus` (`claude`) stopped due to `session_limit`', prompt)
            self.assertIn('team/issue-15', prompt)
            self.assertIn('tracked.gd', prompt)
            self.assertIn('untracked_notes.md', prompt)

            # 4. Restart / idempotent duplicate suppression: repeating handoff for same source_run_id does not re-launch
            team.handoff(15, 'argon', now_ts=1030.0)
            self.assertEqual(len(launched), 1)

    def test_same_provider_continuation_retains_native_session_id(self):
        def git(cwd, *args):
            subprocess.run(['git', '-C', str(cwd), *args], check=True, capture_output=True, text=True)

        git(self.repo, 'init', '-b', 'main')
        git(self.repo, '-c', 'user.name=Test', '-c', 'user.email=t@example.invalid',
            'commit', '--allow-empty', '-m', 'initial')
        wt = self.state / 'worktrees/20'
        git(self.repo, 'worktree', 'add', '-b', 'team/issue-20', str(wt))

        codex_tid = '019a0b44-aaaa-bbbb-cccc-ddddeeeeffff'
        (self.state / 'issue-20.json').write_text(json.dumps({
            'profile': 'astra',
            'session_id': codex_tid,
            'issue': {'number': 20, 'title': 'Update docs', 'body': ''},
            'worktree': str(wt),
            'blocked': {
                'failure_kind': 'quota_exhausted',
                'blocked_reason': 'rate_limit',
                'run_id': '11112222333344445555666677778888',
            },
        }))
        (self.state / 'issue-20.exit').write_text('1')
        with patch.object(team, 'active', return_value=[]), \
                patch.object(team, 'launch_worker'), \
                patch.object(team.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, stdout='')), \
                patch.object(team, 'run', return_value=''):
            with patch.object(team, 'validate_worktree'):
                team.handoff(20, 'luna', now_ts=2000.0)
        updated = json.loads((self.state / 'issue-20.json').read_text())
        self.assertEqual(updated['profile'], 'luna')
        self.assertEqual(updated['session_id'], codex_tid)
        self.assertEqual(updated['handoff_state']['handoff_kind'], 'same_provider_reassign')

    def test_peer_selection_and_exhausted_no_eligible_peer_escalation(self):
        (self.state / 'disabled-fable').write_text('disabled in hierarchy')
        (self.state / 'issue-15.json').write_text(json.dumps({
            'profile': 'opus',
            'session_id': '5e550000-c1a0-4de0-8000-000000000015',
            'issue': {'number': 15, 'title': 'Implement core combat mechanic', 'body': ''},
            'worktree': str(self.state / 'worktrees/15'),
            'blocked': {
                'failure_kind': 'quota_exhausted',
                'blocked_reason': 'session_limit',
                'run_id': 'f1000000000000000000000000000015',
                'reset_at': 5000.0,
            },
        }))
        team.record_provider_quota(
            'opus', 'session_limit',
            {'reset_at': 5000.0, 'reset_timezone': 'UTC', 'reset_provenance': 'provider_error_text'},
            issue_number=15, run_id='f1000000000000000000000000000015', observed_at=1000.0,
        )
        # 1. With Claude on cooldown, senior peers for Opus are Sol/medium and Argon (never lead Sol or emergency-only models)
        rec = team.recommend_quota_action(15, now_ts=1050.0)
        self.assertEqual(rec['decision'], 'reassign')
        self.assertEqual(rec['candidates'], ['sol-dev', 'argon'])
        self.assertEqual(rec['to_profile'], 'sol-dev')

        # 2. If reset is imminent (within wait threshold), recommends WAIT
        rec_wait = team.recommend_quota_action(15, now_ts=4500.0, wait_threshold_sec=900)
        self.assertEqual(rec_wait['decision'], 'wait')
        self.assertEqual(rec_wait['to_profile'], 'opus')

        # 3. If Argon and the shared ChatGPT pool are also quota-blocked, no eligible senior peer exists -> recommends ESCALATE
        team.record_provider_quota(
            'argon', 'quota_exceeded',
            {'reset_at': 6000.0, 'reset_timezone': 'UTC', 'reset_provenance': 'provider_error_text'},
            observed_at=1050.0,
        )
        team.record_provider_quota(
            'astra', 'usage_limit',
            {'reset_at': 6000.0, 'reset_timezone': 'UTC', 'reset_provenance': 'provider_error_text'},
            observed_at=1050.0,
        )
        rec_esc = team.recommend_quota_action(15, now_ts=1060.0)
        self.assertEqual(rec_esc['decision'], 'escalate')
        self.assertIsNone(rec_esc['to_profile'])
        self.assertEqual(rec_esc['candidates'], [])

        with patch.object(team.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)):
            res = team.decide_quota(15, 'escalate', now_ts=1065.0)
        self.assertEqual(res['decision'], 'escalate')
        saved = json.loads((self.state / 'issue-15.json').read_text())
        self.assertEqual(saved['quota_decision']['outcome'], 'escalated_no_eligible_peer')

    def test_quota_interrupted_and_successor_attribution_and_merged_pr_efficiency(self):
        # Record quota-exhausted worker run #1 (Opus) followed by handoff run #2 (Argon) on issue #15 -> PR #42
        log1 = self.state / 'issue-15-1000000000000.log'
        log1.write_text(json.dumps({
            'type': 'result', 'subtype': 'success', 'is_error': True,
            'result': "You've hit your session limit · resets 2:50pm (UTC)",
            'session_id': '5e550000-c1a0-4de0-8000-000000000015',
            'terminal_reason': 'api_error', 'api_error_status': 429, 'api_error': 'usage_limit_reached',
            'modelUsage': {'claude-opus-4-7': {'inputTokens': 100, 'cacheReadInputTokens': 900,
                                               'cacheCreationInputTokens': 200, 'outputTokens': 300}},
        }))
        log2 = self.state / 'issue-15-2000000000000.log'
        log2.write_text(json.dumps({
            'status': 'SUCCESS',
            'conversation_id': 'c0de0000-a690-4000-8000-000000000020',
            'num_turns': 4,
            'usage': {'input_tokens': 2000, 'cache_read_tokens': 3000, 'output_tokens': 500, 'thinking_tokens': 150},
        }))
        r1_id = ua.record_finish(
            self.db, log_path=log1, role='worker', profile='opus', provider='claude',
            requested_model='opus', effort='medium', started_at=1000.0, finished_at=1100.0,
            exit_code=1, repo='KumarG23/vael-academy', issue_number=15, trigger='lead_dispatch',
        )
        skey1 = ua.session_key_for('claude', '5e550000-c1a0-4de0-8000-000000000015')
        ua.record_quota_decision(
            self.db, run_id=r1_id, issue_number=15, decision='reassign',
            to_profile='argon', to_provider='agy', handoff_kind='cross_provider_reassign',
            decided_at=1120.0,
        )
        r2_id = ua.record_finish(
            self.db, log_path=log2, role='worker', profile='argon', provider='agy',
            requested_model='gemini-4-argon-medium', effort='medium', started_at=1125.0, finished_at=1300.0,
            exit_code=0, repo='KumarG23/vael-academy', issue_number=15, trigger='handoff',
            handoff_from_run_id=r1_id, handoff_from_profile='opus', handoff_from_provider='claude',
            handoff_from_session_key=skey1, handoff_kind='cross_provider_reassign',
        )
        conn = ua.connect(self.db)
        try:
            ua.import_github(
                conn, 'KumarG23/vael-academy',
                [{'number': 15, 'state': 'CLOSED', 'createdAt': '2026-10-22T00:00:00Z',
                  'closedAt': '2026-10-22T01:00:00Z', 'title': 'Feat', 'labels': []}],
                [{'number': 42, 'state': 'MERGED', 'createdAt': '2026-10-22T00:30:00Z',
                  'closedAt': '2026-10-22T01:00:00Z', 'mergedAt': '2026-10-22T01:00:00Z',
                  'headRefName': 'team/issue-15', 'body': 'Closes #15'}],
            )
            ua.write(conn, lambda c: ua.attribute(c, 'KumarG23/vael-academy'))
            s = ua.summary(conn, ua.parse_filters({'range': 'all'}))
            # Attempt 1 tokens: (100+900+200) + 300 = 1500. Attempt 2 tokens: (2000+3000) + 500 = 5500. Total = 7000.
            self.assertEqual(s['totals']['total_tokens'], 7000)
            self.assertEqual(s['totals']['quota_exhausted'], 1)
            self.assertEqual(s['totals']['handoffs'], 1)
            self.assertEqual(s['efficiency']['merged_prs'], 1)
            self.assertEqual(s['efficiency']['mean_tokens_per_merged_pr'], 7000.0)

            qr = s['quota_recovery']
            self.assertEqual(qr['total_quota_events'], 1)
            self.assertEqual(qr['handoff_count'], 1)
            ev = qr['events'][0]
            self.assertEqual(ev['run_id'], r1_id)
            self.assertEqual(ev['successor_run_id'], r2_id)
            self.assertEqual(ev['profile'], 'opus')
            self.assertEqual(ev['successor_profile'], 'argon')
            self.assertEqual(ev['logical_task_id'], 'issue:15')
            self.assertEqual(ev['worktree_key'], 'issue-15')
            self.assertEqual(ev['failed_attempt_tokens'], 1500)
            self.assertEqual(ev['successor_attempt_tokens'], 5500)
            self.assertIsNone(ev['transfer_overhead_tokens'])
            self.assertEqual(ev['combined_task_tokens'], 7000)
            self.assertEqual(ev['known_subtotal_tokens'], 7000)
            self.assertEqual(ev['attempts_total'], 2)
            self.assertEqual(ev['attempts_usage_known'], 2)
            self.assertEqual(ev['token_coverage'], 'complete_both_attempts_known')
            self.assertEqual(ev['outcome'], 'delivered_merged')
        finally:
            conn.close()

    def test_quota_recovery_token_semantics_no_handoff_and_partial_unknown(self):
        # 1. No successor / no handoff yet: useful predecessor tokens must NOT be labeled transfer_overhead_tokens,
        #    and combined_task_tokens must be None (with known_subtotal_tokens + token_coverage='no_successor_yet').
        log_no_succ = self.state / 'issue-31-1000000000000.log'
        log_no_succ.write_text(json.dumps({
            'type': 'result', 'subtype': 'success', 'is_error': True,
            'result': "You've hit your session limit · resets 2:50pm (UTC)",
            'session_id': '11111111-2222-3333-4444-555555555555',
            'terminal_reason': 'api_error', 'api_error_status': 429, 'api_error': 'usage_limit_reached',
            'modelUsage': {'claude-opus-4-7': {'inputTokens': 500, 'cacheReadInputTokens': 1000,
                                               'cacheCreationInputTokens': 100, 'outputTokens': 200}},
        }))
        r_no_succ = ua.record_finish(
            self.db, log_path=log_no_succ, role='worker', profile='opus', provider='claude',
            requested_model='opus', effort='medium', started_at=1000.0, finished_at=1050.0,
            exit_code=1, repo='KumarG23/vael-academy', issue_number=31, trigger='lead_dispatch',
        )

        # 2. Handoff occurred, but successor attempt usage is unknown (e.g. interrupted before emitting usage):
        #    combined_task_tokens must be None, never silently equal to failed_attempt_tokens alone.
        log_pred = self.state / 'issue-32-1000000000000.log'
        log_pred.write_text(json.dumps({
            'type': 'result', 'subtype': 'success', 'is_error': True,
            'result': "You've hit your session limit · resets 2:50pm (UTC)",
            'session_id': '22222222-3333-4444-5555-666666666666',
            'terminal_reason': 'api_error', 'api_error_status': 429, 'api_error': 'usage_limit_reached',
            'modelUsage': {'claude-opus-4-7': {'inputTokens': 400, 'cacheReadInputTokens': 400,
                                               'cacheCreationInputTokens': 0, 'outputTokens': 100}},
        }))
        log_succ_unk = self.state / 'issue-32-2000000000000.log'
        log_succ_unk.write_text('unstructured crash before usage emitted\n')
        r_pred = ua.record_finish(
            self.db, log_path=log_pred, role='worker', profile='opus', provider='claude',
            requested_model='opus', effort='medium', started_at=2000.0, finished_at=2050.0,
            exit_code=1, repo='KumarG23/vael-academy', issue_number=32, trigger='lead_dispatch',
        )
        ua.record_quota_decision(
            self.db, run_id=r_pred, issue_number=32, decision='reassign',
            to_profile='argon', to_provider='agy', handoff_kind='cross_provider_reassign',
            decided_at=2060.0,
        )
        r_succ_unk = ua.record_finish(
            self.db, log_path=log_succ_unk, role='worker', profile='argon', provider='agy',
            requested_model='gemini-4-argon-medium', effort='medium', started_at=2065.0, finished_at=2100.0,
            exit_code=1, repo='KumarG23/vael-academy', issue_number=32, trigger='handoff',
            handoff_from_run_id=r_pred, handoff_from_profile='opus', handoff_from_provider='claude',
            handoff_kind='cross_provider_reassign',
        )

        conn = ua.connect(self.db)
        try:
            qr = ua.quota_recovery(conn)
            by_run = {ev['run_id']: ev for ev in qr['events']}

            ev1 = by_run[r_no_succ]
            self.assertEqual(ev1['failed_attempt_tokens'], 1800)
            self.assertIsNone(ev1['successor_run_id'])
            self.assertIsNone(ev1['successor_attempt_tokens'])
            self.assertIsNone(ev1['transfer_overhead_tokens'])
            self.assertIsNone(ev1['combined_task_tokens'])
            self.assertEqual(ev1['known_subtotal_tokens'], 1800)
            self.assertEqual(ev1['attempts_total'], 1)
            self.assertEqual(ev1['attempts_usage_known'], 1)
            self.assertEqual(ev1['token_coverage'], 'no_successor_yet')

            ev2 = by_run[r_pred]
            self.assertEqual(ev2['failed_attempt_tokens'], 900)
            self.assertEqual(ev2['successor_run_id'], r_succ_unk)
            self.assertIsNone(ev2['successor_attempt_tokens'])
            self.assertIsNone(ev2['transfer_overhead_tokens'])
            self.assertIsNone(ev2['combined_task_tokens'])
            self.assertEqual(ev2['known_subtotal_tokens'], 900)
            self.assertEqual(ev2['attempts_total'], 2)
            self.assertEqual(ev2['attempts_usage_known'], 1)
            self.assertEqual(ev2['token_coverage'], 'partial_attempt_usage_unknown')
        finally:
            conn.close()

    def test_historical_poll_unmatched_activation_and_bounded_window_matching(self):
        # 1. Verify v1 -> v2 schema migration converts legacy 'no_inference_unrecorded' (ai_launched=0)
        #    into 'unmatched_activation_unknown' with ai_launched=NULL.
        import sqlite3
        raw = sqlite3.connect(self.db)
        raw.executescript(ua.MIGRATIONS[1])
        raw.executescript("""
            DROP TABLE polls;
            CREATE TABLE polls(
                poll_id TEXT PRIMARY KEY,
                source_key TEXT NOT NULL UNIQUE,
                source_kind TEXT NOT NULL,
                at REAL NOT NULL,
                outcome TEXT NOT NULL,
                reasons TEXT,
                duration_ms INTEGER,
                ai_launched INTEGER NOT NULL,
                run_id TEXT,
                lead_profile TEXT
            );
            INSERT INTO polls(poll_id, source_key, source_kind, at, outcome, reasons, duration_ms, ai_launched, run_id, lead_profile)
            VALUES ('p_legacy', 'journal:legacy100', 'import', 100.0, 'no_inference_unrecorded', NULL, 500, 0, NULL, 'sol');
            PRAGMA user_version=1;
        """)
        raw.commit()
        raw.close()

        conn = ua.connect(self.db)
        try:
            migrated = conn.execute("SELECT outcome, ai_launched FROM polls WHERE poll_id='p_legacy'").fetchone()
            self.assertEqual(migrated['outcome'], 'unmatched_activation_unknown')
            self.assertIsNone(migrated['ai_launched'])
        finally:
            conn.close()

        # 2. Verify historical journal import:
        #    - Unmatched activation gets outcome='unmatched_activation_unknown' and ai_launched=None
        #    - Missing 'Finished' message does NOT attach a future unrelated lead-*.log hours later
        #    - Live record_poll('no_wake_reason') gets ai_launched=0 and is counted as verified zero-model skip
        lead_log = self.state / 'lead-1792635000000000000.log'  # t = 1792635000.0
        lead_log.write_text('\n'.join([
            json.dumps({'type': 'thread.started', 'thread_id': '019a0b44-9999-8888-7777-666655554444'}),
            json.dumps({'type': 'turn.completed', 'usage': {'input_tokens': 100, 'cached_input_tokens': 0, 'output_tokens': 20}}),
        ]))
        journal_lines = '\n'.join([
            # Activation 1 at t=1792630000..1792630002 (no lead log near this time)
            '1792630000.000000 host systemd[1000]: Starting vael-team-lead.service - Vael engineering lead pass...',
            '1792630002.000000 host systemd[1000]: Finished vael-team-lead.service - Vael engineering lead pass.',
            # Activation 2 at t=1792631000 with NO 'Finished' message (e.g. interrupted/incomplete journal);
            # lead_log is at 1792635000 (4000s later, well beyond 120s bound) and must NOT be matched to Activation 2!
            '1792631000.000000 host systemd[1000]: Starting vael-team-lead.service - Vael engineering lead pass...',
            # Activation 3 at t=1792634999..1792635010 (matches lead_log at 1792635000)
            '1792634999.000000 host systemd[1000]: Starting vael-team-lead.service - Vael engineering lead pass...',
            '1792635010.000000 host systemd[1000]: Finished vael-team-lead.service - Vael engineering lead pass.',
        ])
        ua.import_history(
            self.db, self.state, repo='KumarG23/vael-academy',
            profiles=team.PROFILES, journal=journal_lines,
        )
        ua.record_poll(self.db, at=1792636000.0, outcome='no_wake_reason', duration_ms=120, lead_profile='sol')

        conn = ua.connect(self.db)
        try:
            p_rows = {
                r['source_key']: dict(r)
                for r in conn.execute('SELECT * FROM polls').fetchall()
            }
            p1 = p_rows['journal:' + ua.digest(1792630000.0)]
            self.assertEqual(p1['outcome'], 'unmatched_activation_unknown')
            self.assertIsNone(p1['ai_launched'])
            self.assertIsNone(p1['run_id'])

            p2 = p_rows['journal:' + ua.digest(1792631000.0)]
            self.assertEqual(p2['outcome'], 'unmatched_activation_unknown')
            self.assertIsNone(p2['ai_launched'])
            self.assertIsNone(p2['run_id'])  # Not matched to future lead_log at 1792635000!

            p3 = p_rows['journal:' + ua.digest(1792634999.0)]
            self.assertEqual(p3['outcome'], 'inference_success')
            self.assertEqual(p3['ai_launched'], 1)
            self.assertIsNotNone(p3['run_id'])

            ps = ua.polls_summary(ua.polls(conn, {}))
            self.assertEqual(ps['ai_launched_count'], 1)
            self.assertEqual(ps['verified_zero_model_skips'], 1)
            self.assertEqual(ps['unmatched_historical_activations'], 3)  # p_legacy + p1 + p2
        finally:
            conn.close()

    def test_antigravity_multi_pool_quota_scopes_and_candidate_qualification_gates(self):
        # 1. Exact verified `agy models` IDs and distinct quota scopes
        self.assertEqual(team.PROFILES['argon'], ('agy', 'gemini-4-argon-medium', 'medium'))
        self.assertEqual(team.PROFILES['agy-opus'], ('agy', 'claude-opus-5-5-medium', 'medium'))
        self.assertEqual(team.PROFILES['agy-sonnet'], ('agy', 'claude-sonnet-5-5-medium', 'medium'))
        self.assertEqual(team.PROFILES['agy-gpt-oss'], ('agy', 'gpt-oss-120b-medium', 'medium'))
        self.assertEqual(team.PROFILES['agy-flash'], ('agy', 'gemini-3.8-flash-medium', 'medium'))
        self.assertEqual(team.PROFILES['opus'], ('claude', 'opus', 'medium'))

        self.assertEqual(ua.quota_scope_for('agy', 'argon', 'gemini-4-argon-medium'), 'agy_argon_weekly')
        self.assertEqual(ua.quota_scope_for('agy', 'agy-opus', 'claude-opus-5-5-medium'), 'agy_claude_gpt_oss_shared')
        self.assertEqual(ua.quota_scope_for('agy', 'agy-sonnet', 'claude-sonnet-5-5-medium'), 'agy_claude_gpt_oss_shared')
        self.assertEqual(ua.quota_scope_for('agy', 'agy-gpt-oss', 'gpt-oss-120b-medium'), 'agy_claude_gpt_oss_shared')
        self.assertEqual(ua.quota_scope_for('agy', 'agy-flash', 'gemini-3.8-flash-medium'), 'agy_gemini_shared')
        self.assertEqual(ua.quota_scope_for('claude', 'opus', 'opus'), 'claude_subscription')

        # 2. Fable remains retired/disabled and not reinterpreted
        (self.state / 'disabled-fable').write_text('retired profile')
        self.assertNotIn('fable', team.SENIOR_WORKERS)
        self.assertNotIn('fable', team.JUNIOR_WORKERS)
        self.assertTrue(team.profile_disabled_reason('fable'))

        # 3. Candidate Antigravity routes are disabled/unqualified by default
        for cand in ('agy-opus', 'agy-sonnet', 'agy-gpt-oss', 'agy-flash'):
            self.assertIn(cand, team.UNQUALIFIED_PROFILES)
            self.assertIsNotNone(team.profile_disabled_reason(cand))
            with self.assertRaisesRegex(RuntimeError, 'unqualified/disabled'):
                team.start(99, cand)
        self.assertEqual(team.eligible_peers(for_profile='opus', task_tier='senior', now_ts=1000.0), ['sol-dev', 'argon'])

        # 4. When candidate routes are qualified in isolated state, verify model-family quota pool isolation:
        for cand in ('agy-opus', 'agy-sonnet', 'agy-gpt-oss', 'agy-flash'):
            (self.state / f'qualified-{cand}').write_text('qualified in test')

        # 4a. Blocking Argon (`agy_argon_weekly`) blocks `argon`, NOT `agy-opus`, `agy-sonnet`, `agy-gpt-oss`, or `agy-flash`
        team.record_provider_quota(
            'argon', 'quota_exceeded',
            {'reset_at': 5000.0, 'reset_timezone': 'UTC', 'reset_provenance': 'provider_error_text'},
            observed_at=1000.0,
        )
        self.assertFalse(team.provider_quota_status('argon', now_ts=1100.0)['eligible'])
        for sibling in ('agy-opus', 'agy-sonnet', 'agy-gpt-oss', 'agy-flash', 'opus', 'astra'):
            self.assertTrue(team.provider_quota_status(sibling, now_ts=1100.0)['eligible'], sibling)

        # 4b. Blocking `agy-opus` (`agy_claude_gpt_oss_shared`) blocks `agy-opus`, `agy-sonnet`, and `agy-gpt-oss`,
        #     while `agy-flash` (`agy_gemini_shared`) and official `opus` (`claude_subscription`) stay eligible!
        team.record_provider_quota(
            'agy-opus', 'quota_exceeded',
            {'reset_at': 6000.0, 'reset_timezone': 'UTC', 'reset_provenance': 'provider_error_text'},
            observed_at=1000.0,
        )
        for shared_peer in ('agy-opus', 'agy-sonnet', 'agy-gpt-oss'):
            st = team.provider_quota_status(shared_peer, now_ts=1100.0)
            self.assertFalse(st['eligible'], shared_peer)
            self.assertEqual(st['quota_scope'], 'agy_claude_gpt_oss_shared')
        self.assertTrue(team.provider_quota_status('agy-flash', now_ts=1100.0)['eligible'])
        self.assertTrue(team.provider_quota_status('opus', now_ts=1100.0)['eligible'])

        # 4c. Official Claude (`opus`) quota block NEVER blocks `agy-opus` or `agy-sonnet`
        team.clear_provider_quota('agy-opus')
        team.record_provider_quota(
            'opus', 'session_limit',
            {'reset_at': 7000.0, 'reset_timezone': 'UTC', 'reset_provenance': 'provider_error_text'},
            observed_at=1000.0,
        )
        self.assertFalse(team.provider_quota_status('opus', now_ts=1100.0)['eligible'])
        self.assertTrue(team.provider_quota_status('agy-opus', now_ts=1100.0)['eligible'])
        self.assertTrue(team.provider_quota_status('agy-sonnet', now_ts=1100.0)['eligible'])

        # 5. Legacy provider-wide `quota-agy.json` backward compatibility
        team.clear_provider_quota('argon')
        (self.state / 'quota-agy.json').write_text(json.dumps({
            'provider': 'agy',
            'profile': 'argon',
            'blocked_reason': 'quota_exceeded',
            'observed_at': 1000.0,
            'reset_at': 8000.0,
            'reset_timezone': 'UTC',
            'reset_provenance': 'provider_error_text',
        }))
        self.assertFalse(team.provider_quota_status('argon', now_ts=1100.0)['eligible'])
        self.assertTrue(team.provider_quota_status('agy-opus', now_ts=1100.0)['eligible'])
        self.assertTrue(team.provider_quota_status('agy-flash', now_ts=1100.0)['eligible'])
        # Scope-keyed lookups of other pools must not inherit the legacy Argon block.
        self.assertTrue(team.provider_quota_status('agy_gemini_shared', now_ts=1100.0)['eligible'])
        self.assertTrue(team.provider_quota_status('agy_claude_gpt_oss_shared', now_ts=1100.0)['eligible'])
        self.assertFalse(team.provider_quota_status('agy_argon_weekly', now_ts=1100.0)['eligible'])
        provider_wide = team.provider_quota_status('agy', now_ts=1100.0)
        self.assertFalse(provider_wide['eligible'])
        self.assertEqual(provider_wide['quota_scope'], 'agy_argon_weekly')

        # Unknown-scope legacy `quota-agy.json` conservatively blocks all agy profiles
        (self.state / 'quota-agy.json').write_text(json.dumps({
            'provider': 'agy',
            'blocked_reason': 'quota_exceeded',
            'observed_at': 1000.0,
            'reset_at': 8000.0,
        }))
        self.assertFalse(team.provider_quota_status('argon', now_ts=1100.0)['eligible'])
        self.assertFalse(team.provider_quota_status('agy-opus', now_ts=1100.0)['eligible'])
        self.assertFalse(team.provider_quota_status('agy-flash', now_ts=1100.0)['eligible'])
        (self.state / 'quota-agy.json').unlink()

        # 6. `agy_subscription` preflight verifies `useG1Credits=false`
        ok_cfg = subprocess.CompletedProcess(
            ['agy'], 0,
            json.dumps({'status': 'SUCCESS', 'command': {'data': {'config': {'useG1Credits': False}}}}),
        )
        with patch.object(team.subprocess, 'run', return_value=ok_cfg):
            team.agy_subscription(self.state, {})

        bad_cfg = subprocess.CompletedProcess(
            ['agy'], 0,
            json.dumps({'status': 'SUCCESS', 'command': {'data': {'config': {'useG1Credits': True}}}}),
        )
        with patch.object(team.subprocess, 'run', return_value=bad_cfg):
            with self.assertRaisesRegex(RuntimeError, 'useG1Credits=false'):
                team.agy_subscription(self.state, {})

    def test_wrapper_manifest_import_lineage_cumulative_and_idempotence(self):
        # Synthetic wrapper logs using real envelope shapes: Claude session limit ->
        # cross-provider Argon run -> same-conversation Argon resume ending in 429.
        w = self.root / 'wrappers'
        w.mkdir()
        (w / 'build.log').write_text(json.dumps({
            'type': 'result', 'subtype': 'success', 'is_error': True, 'num_turns': 9,
            'result': "You've hit your session limit · resets 2:50pm (UTC)",
            'session_id': 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',
            'usage': {'input_tokens': 10, 'cache_creation_input_tokens': 20,
                      'cache_read_input_tokens': 300, 'output_tokens': 40},
            'modelUsage': {}, 'api_error_status': 429, 'api_error': 'usage_limit_reached'}) + '\n')
        (w / 'build.exit').write_text('1')
        conv = 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb'
        (w / 'argon.log').write_text(json.dumps({
            'conversation_id': conv, 'status': 'SUCCESS', 'response': 'done', 'num_turns': 1,
            'usage': {'input_tokens': 100, 'output_tokens': 10, 'thinking_tokens': 1,
                      'cache_read_tokens': 1000, 'total_tokens': 110}}) + '\n')
        (w / 'argon.json').write_text(json.dumps({
            'started_at': '2026-10-22T13:45:00+00:00', 'finished_at': '2026-10-22T14:43:00+00:00',
            'exit_code': 0, 'status': 'completed'}))
        (w / 'followup.log').write_text(
            'error: Individual quota reached. Resets in 94h4m52s.\n' + json.dumps({
                'conversation_id': conv, 'status': 'ERROR', 'response': '', 'num_turns': 2,
                'error': 'Individual quota reached. Please upgrade your subscription to increase your limits. '
                         'Resets in 94h4m52s.',
                'usage': {'input_tokens': 150, 'output_tokens': 25, 'thinking_tokens': 3,
                          'cache_read_tokens': 1600, 'total_tokens': 175}}) + '\n')
        (w / 'followup.json').write_text(json.dumps({
            'started_at': '2026-10-22T14:46:00+00:00', 'finished_at': '2026-10-22T15:18:00+00:00',
            'exit_code': 3, 'status': 'failed'}))
        manifest = [
            {'log': str(w / 'build.log'), 'exit_file': str(w / 'build.exit'), 'provider': 'claude',
             'profile': 'opus', 'requested_model': 'opus', 'effort': 'medium',
             'task': 'wrapper:usage-analytics', 'category': 'implementation'},
            {'log': str(w / 'argon.log'), 'receipt': str(w / 'argon.json'), 'provider': 'agy',
             'profile': 'argon', 'requested_model': 'gemini-4-argon-medium', 'effort': 'medium',
             'task': 'wrapper:usage-analytics', 'category': 'implementation',
             'predecessor_log': str(w / 'build.log')},
            {'log': str(w / 'followup.log'), 'receipt': str(w / 'followup.json'), 'provider': 'agy',
             'profile': 'argon', 'requested_model': 'gemini-4-argon-medium', 'effort': 'medium',
             'task': 'wrapper:usage-analytics', 'category': 'implementation'},
            {'log': str(w / 'absent.log'), 'provider': 'claude', 'profile': 'opus'},
        ]
        first = ua.import_wrapper_runs(self.db, manifest)
        self.assertEqual(first, {'entries': 4, 'runs': 3, 'missing_logs': 1, 'handoffs_linked': 1})
        ua.import_wrapper_runs(self.db, manifest)  # idempotent re-import
        conn = ua.connect(self.db, readonly=True)
        try:
            rows = {r['source_key']: dict(r) for r in conn.execute('SELECT * FROM runs')}
            self.assertEqual(len(rows), 3)
            build, argon, follow = (rows[ua.wrapper_key(w / 'build.log')], rows[ua.wrapper_key(w / 'argon.log')],
                                    rows[ua.wrapper_key(w / 'followup.log')])
            # No receipt -> start/duration unknown, not guessed.
            self.assertIsNone(build['started_at'])
            self.assertIsNone(build['duration_ms'])
            self.assertEqual(build['failure_kind'], 'quota_exhausted')
            self.assertEqual(build['quota_scope'], 'claude_subscription')
            self.assertIsNone(build['repo'])
            self.assertIsNone(build['issue_number'])
            self.assertEqual(build['trigger'], 'operator')
            # Lineage: Argon is a cross-provider handoff from the Claude quota stop.
            self.assertEqual(argon['handoff_from_run_id'], build['run_id'])
            self.assertEqual(argon['handoff_kind'], 'cross_provider_reassign')
            self.assertEqual(argon['quota_scope'], 'agy_argon_weekly')
            self.assertEqual(argon['duration_ms'], 58 * 60 * 1000)
            # Same conversation: resumed run gets the cumulative delta, not the whole snapshot.
            self.assertEqual(argon['input_tokens'], 1100)
            self.assertEqual(follow['input_tokens'], 1750 - 1100)
            self.assertEqual(follow['output_tokens'], 15)
            self.assertEqual(follow['failure_kind'], 'quota_exhausted')
            self.assertEqual(follow['blocked_reason'], 'quota_exceeded')
            self.assertEqual(follow['reset_provenance'], 'provider_error_text')
            self.assertEqual(follow['reset_at'], follow['finished_at'] + 94 * 3600 + 4 * 60 + 52)
            self.assertIsNone(follow['handoff_from_run_id'])
            # Model identity stays requested-only; agy emits no model field.
            self.assertIsNone(argon['resolved_model'])
            q = ua.quota_recovery(conn)
            events = {e['run_id']: e for e in q['events']}
            self.assertEqual(events[build['run_id']]['successor_run_id'], argon['run_id'])
            self.assertIsNone(events[build['run_id']]['transfer_overhead_tokens'])
            self.assertIsNone(events[follow['run_id']]['successor_run_id'])
            self.assertEqual(events[follow['run_id']]['quota_scope'], 'agy_argon_weekly')
        finally:
            conn.close()

    def test_wrapper_import_keeps_same_basename_logs_distinct(self):
        for name, provider in (('a', 'claude'), ('b', 'opencode')):
            d = self.root / 'smokes' / name
            d.mkdir(parents=True)
            rec = ({'type': 'result', 'subtype': 'success', 'is_error': False, 'session_id': f'{name}' * 8,
                    'usage': {'input_tokens': 1, 'output_tokens': 2}, 'modelUsage': {'claude-opus-5-5': {}}}
                   if provider == 'claude' else
                   {'type': 'step_finish', 'sessionID': 'ses_' + name * 8,
                    'part': {'tokens': {'input': 5, 'output': 1, 'reasoning': 0, 'cache': {'read': 0, 'write': 0}}}})
            (d / 'native.log').write_text(json.dumps(rec) + '\n')
        report = ua.import_wrapper_runs(self.db, [
            {'log': str(self.root / 'smokes/a/native.log'), 'provider': 'claude', 'profile': 'opus'},
            {'log': str(self.root / 'smokes/b/native.log'), 'provider': 'opencode', 'profile': 'deepseek'}])
        self.assertEqual(report['runs'], 2)
        conn = ua.connect(self.db, readonly=True)
        try:
            got = sorted((r['provider'], r['profile'], r['input_tokens'])
                         for r in conn.execute('SELECT provider, profile, input_tokens FROM runs'))
        finally:
            conn.close()
        self.assertEqual(got, [('claude', 'opus', 1), ('opencode', 'deepseek', 5)])

    def test_paid_credit_entitlement_denial_is_not_quota(self):
        # Real Fable smoke envelope shape: 429 status but a paid-credit entitlement denial.
        rec = {'type': 'result', 'subtype': 'success', 'is_error': True,
               'result': 'Fable 5.1 requires usage credits. Switch to another model, or manage usage credits.',
               'api_error_status': 429, 'api_error': 'model_requires_usage_credits', 'terminal_reason': 'api_error'}
        info = ua.classify_native_failure('claude', [rec], 1)
        self.assertEqual(info['failure_kind'], 'entitlement_denied')
        self.assertEqual(info['blocked_reason'], 'paid_credits_required')
        self.assertIsNone(info['reset_at'])
        # Antigravity's weekly quota text mentions upgrading but remains quota.
        agy = {'status': 'ERROR', 'error': 'Individual quota reached. Please upgrade your subscription to '
                                            'increase your limits. Resets in 1h.'}
        self.assertEqual(ua.classify_native_failure('agy', [agy], 3)['failure_kind'], 'quota_exhausted')

    def test_agy_structured_stderr_envelope_classifies_quota(self):
        lines = [
            'AGY_ERROR: ' + json.dumps({'short_error': 'RESOURCE_EXHAUSTED (code 429)',
                                        'status': 'RESOURCE_EXHAUSTED', 'error_code': 429}),
            json.dumps({'conversation_id': 'cccccccc-3333-4333-8333-cccccccccccc', 'status': 'ERROR',
                        'error': 'request failed', 'num_turns': 1}),
        ]
        info = ua.classify_native_failure('agy', lines, exit_code=3)
        self.assertEqual(info['failure_kind'], 'quota_exhausted')
        self.assertEqual(info['blocked_reason'], 'quota_exceeded')
        plain = ua.classify_native_failure('agy', lines[1:], exit_code=3)
        self.assertEqual(plain['failure_kind'], 'execution_failure')

    def test_agy_worker_runs_no_credit_preflight_before_inference(self):
        # Credits enabled -> worker stops after /config; no model command is launched.
        assignment = {'profile': 'argon', 'issue': {'number': 7, 'title': 'Fixture', 'body': ''},
                      'worktree': str(self.state), 'session_id': None}
        (self.state / 'issue-7.json').write_text(json.dumps(assignment))
        calls = []

        def fake_run(args, **kwargs):
            calls.append(list(args))
            if args[:4] == ['agy', '--output-format', 'json', '-p']:
                return subprocess.CompletedProcess(args, 0, json.dumps(
                    {'status': 'SUCCESS', 'command': {'data': {'config': {'useG1Credits': True}}}}))
            raise AssertionError('unexpected command: ' + ' '.join(map(str, args[:3])))

        with patch.object(team.subprocess, 'run', side_effect=fake_run), \
                patch.object(team, 'block_issue') as block:
            self.assertEqual(team.worker(7), 1)
            block.assert_called_once_with(7, 'argon', 1)
        self.assertEqual(calls, [['agy', '--output-format', 'json', '-p', '/config']])

    def test_concurrent_sqlite_writers_and_export_sanitization(self):
        # Verify WAL concurrent writers succeed and sanitize_row strips any non-allowlisted strings
        def writer(i):
            log = self.state / f'issue-{i}-{1000000000 + i}.log'
            log.write_text(json.dumps({'status': 'SUCCESS', 'conversation_id': f'conv-test-{i:04d}',
                                       'num_turns': 1, 'usage': {'input_tokens': 10, 'cache_read_tokens': 0,
                                                                 'output_tokens': 5, 'thinking_tokens': 0}}))
            ua.record_start(self.db, log_path=log, role='worker', profile='argon', provider='agy',
                            requested_model='gemini-4-argon-medium', effort='medium', started_at=1000.0 + i,
                            repo='KumarG23/vael-academy', issue_number=i)
            ua.record_finish(self.db, log_path=log, role='worker', profile='argon', provider='agy',
                             requested_model='gemini-4-argon-medium', effort='medium', started_at=1000.0 + i,
                             finished_at=1005.0 + i, exit_code=0, repo='KumarG23/vael-academy', issue_number=i)

        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(writer, range(1, 9)))

        conn = ua.connect(self.db)
        try:
            res = ua.runs(conn, ua.parse_filters({'range': 'all'}))
            self.assertEqual(res['total'], 8)
            dirty = dict(res['rows'][0], requested_model='/private/host/secret/path',
                         worktree_key='/private/srv/worktree', reset_timezone='You hit session limit')
            cleaned = ua.sanitize_row(dirty)
            self.assertIsNone(cleaned['requested_model'])
            self.assertIsNone(cleaned['worktree_key'])
            self.assertIsNone(cleaned['reset_timezone'])
        finally:
            conn.close()

    def test_lead_quota_exhaustion_pauses_without_silent_lead_replacement(self):
        # When Sol (lead) hits a quota limit, lead_pass pauses and records lead quota block without replacing LEAD.
        def fake_lead_run(*args, **kwargs):
            if args[:2] == ('gh', 'api'):
                return '[]'
            if args[:2] in (('gh', 'issue'), ('gh', 'pr')):
                return '[]'
            if args[:3] == ('git', 'branch', '--show-current'):
                return 'main'
            if args[:2] == ('git', 'rev-parse'):
                return 'head-sha-1'
            return ''

        def fake_native(args, **kwargs):
            if args[:3] == ['codex', 'login', 'status']:
                return subprocess.CompletedProcess(args, 0, 'Logged in using ChatGPT\n')
            kwargs['stdout'].write(json.dumps({
                'type': 'turn.failed',
                'error': {'message': "You've hit your usage limit · resets 4:00pm (UTC)"},
            }) + '\n')
            return subprocess.CompletedProcess(args, 0)

        with patch.object(team, 'run', side_effect=fake_lead_run), \
                patch.object(team, 'active', return_value=[]), \
                patch.object(team.subprocess, 'run', side_effect=fake_native):
            rc = team.lead()
        self.assertEqual(rc, 1)
        self.assertEqual(team.LEAD, 'sol')
        self.assertIn('no automatic lead replacement', (self.state / 'paused').read_text())
        qstatus = team.provider_quota_status('sol')
        self.assertEqual(qstatus['blocked_reason'], 'usage_limit')
        self.assertEqual(qstatus['decision'], 'escalate')

    def test_plan_exhausted_marker_and_deduplicated_pending_events(self):
        parts = team.snapshot('head1', [], [], [], now_ts=1000.0)
        (self.state / 'lead-receipt.json').write_text(json.dumps({'parts': parts, 'checked_at': 1000.0}))
        team.mark_plan_exhausted('awaiting Neal canon approval on Act II')

        # Even after REFRESH (3600s), periodic refresh is suppressed while plan-exhausted matches
        self.assertEqual(team.wake_reasons(parts, now_ts=1000.0 + team.REFRESH + 100), [])

        # Recording a deduplicated pending-work event changes snapshot and wakes immediately
        k1 = team.record_event('pr_head', '31:abc123')
        k2 = team.record_event('pr_head', '31:abc123')
        self.assertEqual(k1, k2)
        parts_ev = team.snapshot('head1', [], [], [], now_ts=1000.0 + team.REFRESH + 100)
        self.assertEqual(team.wake_reasons(parts_ev, now_ts=1000.0 + team.REFRESH + 100), ['events'])

    def test_idempotent_import_history_and_claude_opencode_parsing(self):
        # Write sample Claude (with total_cost_usd fallback) and OpenCode logs and import twice
        (self.state / 'issue-11.json').write_text(json.dumps({'profile': 'opus'}))
        (self.state / 'issue-11-1792670000000000000.log').write_text(json.dumps({
            'type': 'result', 'subtype': 'success', 'is_error': False,
            'session_id': 'aaaa1111-2222-3333-4444-555566667777',
            'total_cost_usd': 0.42, 'num_turns': 2,
            'modelUsage': {'claude-opus-4-7': {'inputTokens': 500, 'cacheReadInputTokens': 1500,
                                               'cacheCreationInputTokens': 100, 'outputTokens': 250}},
        }))
        (self.state / 'issue-12.json').write_text(json.dumps({'profile': 'deepseek'}))
        (self.state / 'issue-12-1792670001000000000.log').write_text('\n'.join([
            json.dumps({'type': 'step_finish', 'sessionID': 'ses_deepseek1234',
                        'part': {'cost': 0, 'tokens': {'input': 300, 'output': 80, 'reasoning': 40,
                                                       'cache': {'read': 700, 'write': 0}}}}),
            json.dumps({'type': 'tool_use', 'sessionID': 'ses_deepseek1234', 'part': {}}),
            json.dumps({'type': 'text', 'sessionID': 'ses_deepseek1234', 'part': {'text': 'done'}}),
        ]))
        r1 = ua.import_history(self.db, self.state, repo='KumarG23/vael-academy', profiles=team.PROFILES)
        r2 = ua.import_history(self.db, self.state, repo='KumarG23/vael-academy', profiles=team.PROFILES)
        self.assertEqual(r1['runs'], 2)
        self.assertEqual(r2['runs'], 2)
        conn = ua.connect(self.db)
        try:
            s = ua.summary(conn, ua.parse_filters({'range': 'all'}))
            # Claude: (500+1500+100) + 250 = 2350; OpenCode: (300+700) + 80 = 1080; Total = 3430
            self.assertEqual(s['totals']['total_tokens'], 3430)
            claude_row = conn.execute("SELECT provider_cost_usd, cost_basis FROM runs WHERE provider='claude'").fetchone()
            self.assertAlmostEqual(claude_row['provider_cost_usd'], 0.42)
            self.assertEqual(claude_row['cost_basis'], 'claude_cli_list_price_estimate')
        finally:
            conn.close()


if __name__ == '__main__':
    unittest.main()
