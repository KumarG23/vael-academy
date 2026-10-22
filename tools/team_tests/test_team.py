import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('team', Path(__file__).parents[1] / 'team.py')
assert spec is not None and spec.loader is not None
team = importlib.util.module_from_spec(spec)
spec.loader.exec_module(team)


class TeamTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name)
        self.patches = [patch.object(team, 'STATE', self.state), patch.object(team, 'REPO', self.state)]
        for p in self.patches:
            p.start()
            self.addCleanup(p.stop)

    def test_native_codex_has_tools_no_turn_limit_and_subscription(self):
        cmd = team.command('sol')
        self.assertIn('--dangerously-bypass-approvals-and-sandbox', cmd)
        self.assertIn('forced_login_method="chatgpt"', cmd)
        self.assertIn('gpt-6.1-sol', cmd)
        self.assertFalse(any('max-turn' in s for s in cmd))

    def test_resume_uses_same_native_conversation(self):
        session = 'test-session-1234'
        self.assertEqual(team.command('sol', session)[2:4], ['resume', session])
        self.assertEqual(team.command('opus', session)[-2:], ['--resume', session])
        self.assertEqual(team.command('argon', session)[-2:], ['--conversation', session])
        self.assertEqual(team.command('deepseek', session)[-2:], ['--session', session])

    def test_claude_has_native_shell_no_restricted_tool_adapter(self):
        cmd = team.command('opus')
        self.assertIn('--dangerously-skip-permissions', cmd)
        self.assertNotIn('--restricted', cmd)
        self.assertNotIn('--max-turns', cmd)
        self.assertNotIn('--no-session-persistence', cmd)

    def test_environment_removes_paid_api_overrides(self):
        with patch.dict(os.environ, {'ANTHROPIC_API_KEY': 'test', 'OPENAI_API_KEY': 'test',
                                    'ANTHROPIC_BASE_URL': 'https://example.invalid'}):
            env = team.environment()
        self.assertNotIn('ANTHROPIC_API_KEY', env)
        self.assertNotIn('OPENAI_API_KEY', env)
        self.assertNotIn('ANTHROPIC_BASE_URL', env)

    def test_pause_stops_new_assignments_before_github(self):
        (self.state / 'paused').write_text('operator pause')
        with patch.object(team, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'paused'):
                team.start(1, 'sol')
            run.assert_not_called()

    def test_disabled_profile_is_explicit_not_a_fallback(self):
        (self.state / 'disabled-fable').write_text('not yet exercised')
        with self.assertRaisesRegex(RuntimeError, 'not yet exercised'):
            team.start(1, 'fable')

    def test_live_session_not_dispatched_twice(self):
        with patch.object(team, 'active', return_value=['vael-issue-3']), patch.object(team, 'run') as run:
            team.start(3, 'sol')
            run.assert_not_called()

    def test_resource_capacity_not_agent_turn_cap(self):
        with patch.object(team, 'active', return_value=['vael-issue-1', 'vael-issue-2', 'vael-issue-3']):
            with self.assertRaisesRegex(RuntimeError, 'Three workers'):
                team.start(4, 'sol')

    def test_third_independent_worker_can_launch_while_two_run(self):
        import subprocess
        from types import SimpleNamespace
        (self.state / 'worktrees/9').mkdir(parents=True)
        issue = json.dumps({'number': 9, 'title': 'Independent task', 'body': '', 'state': 'OPEN'})
        def fake_run(*args, **kwargs):
            return issue if args[:3] == ('gh', 'issue', 'view') else ''
        with patch.object(team, 'active', return_value=['vael-issue-1', 'vael-issue-2']), \
                patch.object(team, 'run', side_effect=fake_run), patch.object(team, 'validate_worktree'), \
                patch.object(team.shutil, 'disk_usage', return_value=SimpleNamespace(free=10 * 1024**3)), \
                patch.object(team.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as launch:
            team.start(9, 'deepseek')
            cmd = launch.call_args.args[0]
            self.assertEqual(cmd[:4], ['systemd-run', '--user', '--scope', '--quiet'])
            self.assertIn(str(self.state / 'tmux.sock'), cmd)
            self.assertIn('VAEL_TEAM_STATE=' + str(self.state), cmd)
            self.assertIn('VAEL_REPO=' + str(self.state), cmd)
            self.assertNotIn('--wait', cmd)
            self.assertIn('new-session', cmd)
            self.assertIn('_worker 9', cmd[-1])
        self.assertEqual(json.loads((self.state / 'issue-9.json').read_text())['profile'], 'deepseek')

    def test_active_counts_both_sockets_without_inheriting_or_creating_a_server(self):
        from types import SimpleNamespace
        results = [SimpleNamespace(stdout='vael-issue-7\npersonal\nvael-issue-8\n'),
                   SimpleNamespace(stdout='vael-issue-8\nvael-issue-9\n')]
        with patch.object(team.subprocess, 'run', side_effect=results) as query:
            self.assertEqual(team.active(), ['vael-issue-7', 'vael-issue-8', 'vael-issue-9'])
        self.assertEqual(query.call_args_list[0].args[0][:4], ['tmux', '-L', 'default', '-N'])
        self.assertEqual(query.call_args_list[1].args[0][:4],
                         ['tmux', '-S', str(self.state / 'tmux.sock'), '-N'])

    def test_closed_issue_does_not_create_workspace(self):
        with patch.object(team, 'active', return_value=[]), patch.object(team, 'run',
                  return_value=json.dumps({'state': 'CLOSED'})) as run:
            with self.assertRaisesRegex(RuntimeError, 'not open'):
                team.start(3, 'sol')
            self.assertEqual(run.call_count, 1)

    SUBSCRIPTION = json.dumps({'loggedIn': True, 'authMethod': 'claude.ai',
                               'apiProvider': 'firstParty', 'subscriptionType': 'max'})
    CODEX_SUBSCRIPTION = 'Logged in using ChatGPT\n'

    def fake_lead_run(self, *args, **kwargs):
        if args[:2] == ('gh', 'api'):
            if getattr(self, 'github_error', False):
                raise ValueError('incomplete source')
            return json.dumps([getattr(self, 'comments', [])]) if '/issues/comments?' in args[-1] else '[[]]'
        if args[:2] == ('gh', 'issue'):
            return json.dumps(getattr(self, 'ready', []))
        if args[:2] == ('gh', 'pr'):
            return json.dumps(getattr(self, 'prs', []))
        if args[:3] == ('git', 'branch', '--show-current'):
            return 'main'
        if args[:2] == ('git', 'rev-parse'):
            return getattr(self, 'head', 'current-head')
        return ''

    def lead_once(self, result='success', running=()):
        """One lead pass with fake GitHub/git; returns (rc, inference calls)."""
        self.calls = []
        def native(args, **kwargs):
            if args[:3] == ['codex', 'login', 'status']:
                self.calls.append(('preflight', kwargs['cwd'], kwargs['env']))
                return team.subprocess.CompletedProcess(args, 0, self.CODEX_SUBSCRIPTION)
            if args[-2:] == ['auth', 'status']:
                self.calls.append(('preflight', kwargs['cwd'], kwargs['env']))
                return team.subprocess.CompletedProcess(args, 0, self.SUBSCRIPTION)
            self.calls.append(('inference', kwargs['cwd'], kwargs['env'], args, kwargs['input']))
            if getattr(self, 'during_lead', None):
                callback, self.during_lead = self.during_lead, None
                callback()
            if args[0] == 'codex':
                kwargs['stdout'].write(json.dumps({
                    'type': 'turn.completed' if result == 'success' else 'turn.failed'
                }) + '\n')
            else:
                kwargs['stdout'].write(json.dumps({'type': 'result', 'subtype': result,
                                                   'is_error': result != 'success'}))
            return team.subprocess.CompletedProcess(args, 0)
        with patch.object(team, 'run', side_effect=self.fake_lead_run), \
                patch.object(team, 'active', return_value=list(running)), \
                patch.object(team.subprocess, 'run', side_effect=native):
            rc = team.lead()
        return rc, [c for c in self.calls if c[0] == 'inference']

    def pr(self, head='abc123', status='COMPLETED', conclusion='SUCCESS', mergeable='MERGEABLE', **extra):
        check = {'__typename': 'CheckRun', 'name': 'verify', 'status': status, 'conclusion': conclusion,
                 'startedAt': '2026-10-22T12:00:00Z', 'detailsUrl': 'https://example.invalid/run/1'}
        check.update(extra)
        return {'number': 31, 'title': 'Fix', 'isDraft': False, 'labels': [], 'headRefOid': head,
                'mergeable': mergeable, 'statusCheckRollup': [check]}

    def test_lead_is_sol_subscription_with_same_cwd_env_preflight_first(self):
        rc, inference = self.lead_once()
        self.assertEqual(rc, 0)
        self.assertEqual([c[0] for c in self.calls], ['preflight', 'inference'])
        preflight, (_, cwd, env, cmd, prompt) = self.calls[0], inference[0]
        self.assertEqual((preflight[1], preflight[2]), (cwd, env))
        self.assertIs(preflight[2], env)
        self.assertEqual(cwd, team.REPO)
        self.assertEqual(cmd, team.command('sol'))
        self.assertIn('gpt-6.1-sol', cmd)
        self.assertIn('model_reasoning_effort="high"', cmd)
        self.assertIn('forced_login_method="chatgpt"', cmd)
        self.assertIn('engineering lead: Codex gpt-6.1-sol/high (`sol` profile', prompt)

    def test_lead_preflight_failure_pauses_without_inference_or_fallback(self):
        self.CODEX_SUBSCRIPTION = 'Logged in using API key\n'
        rc, inference = self.lead_once()
        self.assertEqual(rc, 1)
        self.assertEqual(inference, [])
        self.assertIn('no fallback', (self.state / 'paused').read_text())
        self.assertEqual((self.state / 'lead.exit').read_text(), '1')
        self.assertFalse((self.state / 'lead-receipt.json').exists())

    def test_lead_routing_prefers_subscription_capacity_and_keeps_owners(self):
        prompt = team.lead_prompt([], [], [], ['first pass'])
        for expected in ['`sol-dev` (`codex`, `gpt-6.1-sol`, `medium`)', 'qualified `deepseek` bounded',
                         'Evaluate `luna` for meaningful bounded implementation',
                         'Sole emergency developer',
                         'stays\nwith that owner through revisions', 'three workers',
                         'Only one worker controls the shared GUI', 'exact-head\nacceptance receipt',
                         'only the delta since the last reviewed SHA', '--match-head-commit']:
            self.assertIn(expected, prompt)
        self.assertEqual(team.LEAD, 'sol')
        self.assertEqual(team.PROFILES['sol'], ('codex', 'gpt-6.1-sol', 'high'))
        self.assertEqual(team.PROFILES['astra'], ('codex', 'gpt-6-astra', 'high'))
        self.assertEqual(team.PROFILES['opus'], ('claude', 'opus', 'medium'))
        self.assertEqual(team.PROFILES['argon'], ('agy', 'gemini-4-argon-medium', 'medium'))
        self.assertEqual(team.PROFILES['luna'], ('codex', 'gpt-6-luna', 'high'))

    def test_empty_queue_wakes_lead_to_derive_plan_work(self):
        rc, inference = self.lead_once()
        self.assertEqual(rc, 0)
        prompt = inference[0][4]
        self.assertIn('Create or refine GitHub issues', prompt)
        self.assertIn('graphical', prompt)
        self.assertIn('blocked task must not stop unrelated', prompt)
        self.assertIn('woke because: first pass', prompt)
        self.assertTrue((self.state / 'lead-receipt.json').exists())

    def test_recent_exhausted_plan_skips_model_until_recheck(self):
        self.lead_once()
        rc, inference = self.lead_once()
        self.assertEqual((rc, inference), (0, []))
        receipt = json.loads((self.state / 'lead-receipt.json').read_text())
        receipt['checked_at'] -= team.REFRESH + 1
        (self.state / 'lead-receipt.json').write_text(json.dumps(receipt))
        rc, inference = self.lead_once()
        self.assertEqual(inference, [])
        self.assertTrue((self.state / 'lead-scan.json').exists())

    def test_unchanged_actionable_queue_skips_inference_until_safety_refresh(self):
        self.ready = [{'number': 5, 'title': 'QA', 'body': 'Acceptance', 'labels': [{'name': 'team:ready'}]}]
        self.prs = [self.pr(status='IN_PROGRESS', conclusion='')]
        running = ['vael-issue-5']
        self.assertEqual(len(self.lead_once(running=running)[1]), 1)
        for _ in range(3):
            self.assertEqual(self.lead_once(running=running), (0, []))
        # Run URLs/timestamps are not state transitions.
        self.prs = [self.pr(status='IN_PROGRESS', conclusion='', detailsUrl='https://example.invalid/2',
                            startedAt='2026-10-22T13:00:00Z')]
        self.assertEqual(self.lead_once(running=running), (0, []))
        with patch.object(team.time, 'time', return_value=team.time.time() + team.REFRESH + 1):
            self.assertEqual(self.lead_once(running=running), (0, []))

    def test_github_and_worker_changes_wake_the_lead(self):
        self.ready = [{'number': 5, 'title': 'QA', 'body': 'Acceptance', 'labels': [{'name': 'team:ready'}]}]
        self.prs = [self.pr(status='IN_PROGRESS', conclusion='')]
        running = ['vael-issue-5']
        self.lead_once(running=running)
        changes = [
            ('prs', lambda: setattr(self, 'prs', [self.pr()])),                       # CI transition
            ('prs', lambda: setattr(self, 'prs', [self.pr(conclusion='FAILURE')])),   # CI result
            ('prs', lambda: setattr(self, 'prs', [self.pr(head='def456')])),          # new PR head
            ('prs', lambda: setattr(self, 'prs', [self.pr(head='def456', mergeable='CONFLICTING')])),
            ('ready', lambda: self.ready[0].update(body='Acceptance (revised by Neal)')),
            ('ready', lambda: self.ready.append({'number': 6, 'title': 'New', 'body': '', 'labels': [{'name': 'team:ready'}]})),
            ('main', lambda: setattr(self, 'head', 'next-head')),
            ('workers', lambda: running.append('vael-issue-6')),                     # slot change
            ('workers', lambda: (self.state / 'issue-5.exit').write_text('0')),     # completion
        ]
        for reason, change in changes:
            change()
            rc, inference = self.lead_once(running=running)
            self.assertEqual(rc, 0)
            self.assertEqual(len(inference), 1, reason)
            self.assertIn('woke because: ' + reason, inference[0][4])
            self.assertEqual(self.lead_once(running=running), (0, []), reason)

    def test_failed_turn_does_not_record_or_suppress_retry(self):
        self.prs = [self.pr()]
        self.lead_once()
        self.prs = [self.pr(head='def456')]
        rc, inference = self.lead_once(result='error_during_execution')
        self.assertEqual((rc, len(inference)), (1, 1))
        self.assertTrue((self.state / 'paused').exists())
        (self.state / 'paused').unlink()  # Operator resumes after inspection.
        rc, inference = self.lead_once()
        self.assertEqual((rc, len(inference)), (0, 1))
        self.assertIn('woke because: prs', inference[0][4])

    def test_failed_planning_does_not_record_success(self):
        rc, inference = self.lead_once(result='error_during_execution')
        self.assertEqual((rc, len(inference)), (1, 1))
        self.assertFalse((self.state / 'lead-receipt.json').exists())
        self.assertTrue((self.state / 'paused').exists())

    def test_corrupt_or_missing_receipt_wakes(self):
        parts = team.snapshot('h', [], [], [])
        self.assertEqual(team.wake_reasons(parts), ['first pass'])
        for receipt in ['broken', '[]', json.dumps({'parts': parts}), json.dumps({'checked_at': 'x'})]:
            (self.state / 'lead-receipt.json').write_text(receipt)
            self.assertEqual(team.wake_reasons(parts), ['receipt recovery'])

    def test_discussion_reply_wakes_once_even_with_exhausted_plan(self):
        self.ready = [{'number': 5, 'title': 'Awaiting decision', 'body': 'Question',
                       'labels': [{'name': 'team:blocked'}]}]
        self.lead_once()
        team.mark_plan_exhausted('Needs human decision')
        self.comments = [{'id': 71, 'body': 'Approved, continue',
                          'issue_url': f'https://api.github.com/repos/{team.SLUG}/issues/5'}]
        rc, inference = self.lead_once()
        self.assertEqual(rc, 0)
        self.assertEqual(len(inference), 1)
        self.assertIn('discussions', inference[0][4])
        self.assertIn('Tracked blocked issues: [5]', inference[0][4])
        self.assertEqual(self.lead_once(), (0, []))

    def test_blocked_issue_body_change_wakes_while_unrelated_worker_runs(self):
        self.ready = [{'number': 5, 'title': 'Decision', 'body': 'Question',
                       'labels': [{'name': 'team:blocked'}]}]
        self.lead_once(running=['vael-issue-77'])  # Initial defer without discarding future deltas.
        self.lead_once()  # Establish a successful plan receipt.
        self.ready[0]['body'] = 'Human answered in issue body'
        rc, inference = self.lead_once(running=['vael-issue-77'])
        self.assertEqual(rc, 0)
        self.assertEqual(len(inference), 1)
        self.assertIn('blocked', inference[0][4])

    def test_marked_bookkeeping_does_not_wake_same_account_lead(self):
        self.ready = [{'number': 5, 'title': 'QA', 'body': '', 'labels': [{'name': 'team:ready'}]}]
        self.lead_once()
        self.comments = [{'id': 71, 'body': team.lead_observation.AUTO_MARKER + '\nReview note',
                          'issue_url': f'https://api.github.com/repos/{team.SLUG}/issues/5'}]
        self.assertEqual(self.lead_once(), (0, []))

    def test_nudge_and_reply_during_model_call_remain_pending(self):
        self.ready = [{'number': 5, 'title': 'QA', 'body': '', 'labels': [{'name': 'team:ready'}]}]
        def during():
            self.comments = [{'id': 71, 'body': 'Arrived during inference',
                              'issue_url': f'https://api.github.com/repos/{team.SLUG}/issues/5'}]
            team.record_event('manual', 'new-request')
        self.during_lead = during
        self.lead_once()
        self.assertIn('manual:new-request', team.pending_events_snapshot())
        rc, inference = self.lead_once()
        self.assertEqual(rc, 0)
        self.assertIn('manual nudge', inference[0][4])
        self.assertIn('discussions', inference[0][4])
        self.assertEqual(team.pending_events_snapshot(), [])
        self.assertEqual(self.lead_once(), (0, []))

    def test_observer_failure_does_not_pause_healthy_team_or_invoke_sol(self):
        self.lead_once()
        before = (self.state / 'discussion-receipt.json').read_bytes()
        self.github_error = True
        self.assertEqual(self.lead_once(), (0, []))
        self.assertFalse((self.state / 'paused').exists())
        self.assertEqual((self.state / 'discussion-receipt.json').read_bytes(), before)

    def test_source_result_cap_is_unknown_not_silently_complete(self):
        self.ready = [{'number': n, 'title': 'Ready', 'body': '', 'labels': []} for n in range(1, 1001)]
        self.assertEqual(self.lead_once(), (0, []))
        self.assertFalse((self.state / 'paused').exists())
        self.assertFalse((self.state / 'discussion-receipt.json').exists())

    def test_corrupt_discussion_receipt_recovers_explicitly(self):
        self.lead_once()
        (self.state / 'discussion-receipt.json').write_text('{corrupt')
        rc, inference = self.lead_once()
        self.assertEqual(rc, 0)
        self.assertIn('receipt recovery', inference[0][4])
        self.assertEqual(self.lead_once(), (0, []))

    def test_systemd_origin_and_manual_nudge_durable_provenance(self):
        import sqlite3
        with patch.dict(team.os.environ, {'INVOCATION_ID': 'synthetic-service-invocation'}):
            self.lead_once()
            with patch.object(team.sys, 'argv', ['team.py', 'wake']):
                team.main()
            self.lead_once()
        conn = sqlite3.connect(team._analytics_db())
        try:
            rows = conn.execute('SELECT trigger,wake_reasons,status FROM runs ORDER BY started_at').fetchall()
            self.assertEqual([r[0] for r in rows], ['systemd', 'manual_start'])
            self.assertTrue(all(r[2] == 'success' for r in rows))
            self.assertIn('manual nudge', rows[1][1])
        finally:
            conn.close()
        audits = [json.loads(p.read_text()) for p in self.state.glob('lead-audit-*.json')]
        self.assertEqual(len(audits), 2)
        self.assertTrue(all(a['post_github_state'] == 'not_rescanned' for a in audits))
        self.assertTrue(all(a['action_evidence']['classification'] == 'analysis_or_unclassified' for a in audits))

    def test_wake_action_preserves_receipt_and_records_manual_intent(self):
        self.lead_once()
        with patch.object(team.sys, 'argv', ['team.py', 'wake']):
            self.assertEqual(team.main(), 0)
        self.assertEqual(len(self.lead_once()[1]), 1)

    def test_empty_queue_with_workers_running_waits_for_results(self):
        with patch.object(team, 'run', side_effect=self.fake_lead_run), \
                patch.object(team, 'active', return_value=['vael-issue-5']), \
                patch.object(team.subprocess, 'run') as sub:
            self.assertEqual(team.lead(), 0)
            sub.assert_not_called()

    def test_paused_lead_does_not_query_github(self):
        (self.state / 'paused').touch()
        with patch.object(team, 'run') as run:
            self.assertEqual(team.lead(), 0)
            run.assert_not_called()

    def test_worker_brief_carries_plan_acceptance_and_pr_ownership(self):
        prompt = team.worker_prompt({'number': 4, 'title': 'Fix click behavior', 'body': 'Acceptance: close on click'})
        for expected in ['MASTER_PLAN.md', 'owning bibles', 'Acceptance: close on click', 'Do not merge your own PR']:
            self.assertIn(expected, prompt)
        self.assertNotIn('Only change the exact files', prompt)


    def test_zero_exit_terminal_provider_error_is_failure(self):
        log = self.state / 'native.log'
        log.write_text(json.dumps({'type': 'result', 'is_error': True, 'subtype': 'success'}))
        self.assertEqual(team.native_result('opus', log, 0), 1)

    def test_native_warning_preamble_does_not_hide_success(self):
        log = self.state / 'native.log'
        log.write_text('native warning\n' + json.dumps({'type': 'result', 'is_error': False, 'subtype': 'success'}))
        self.assertEqual(team.native_result('opus', log, 0), 0)

    def test_codex_repaired_tool_failure_can_finish_successfully(self):
        log = self.state / 'native.log'
        log.write_text(json.dumps({'type': 'item.completed', 'item': {'exit_code': 1}}) + '\n' +
                       json.dumps({'type': 'turn.completed'}))
        self.assertEqual(team.native_result('sol', log, 0), 0)
        log.write_text(json.dumps({'type': 'turn.failed'}))
        self.assertEqual(team.native_result('sol', log, 0), 1)

    def test_argon_native_status_and_free_terminal_errors(self):
        log = self.state / 'native.log'
        log.write_text(json.dumps({'status': 'SUCCESS'}))
        self.assertEqual(team.native_result('argon', log, 0), 0)
        log.write_text(json.dumps({'type': 'error'}))
        self.assertEqual(team.native_result('deepseek', log, 0), 1)
        log.write_text(json.dumps({'type': 'text', 'part': {'text': 'delivery'}}))
        self.assertEqual(team.native_result('deepseek', log, 0), 0)

    def test_explicit_free_routes_do_not_have_paid_fallback(self):
        for profile in ('deepseek', 'minimax', 'nemotron', 'cohere'):
            cmd = team.command(profile)
            self.assertTrue(cmd[cmd.index('--model') + 1].endswith(('-free', ':free')))
            self.assertNotIn('--fallback-model', cmd)

    def test_draft_only_queue_does_not_invoke_model(self):
        draft = json.dumps([{'number': 1, 'title': 'Pending', 'isDraft': True, 'labels': []}])
        with patch.object(team, 'run', side_effect=lambda *a: '[]' if a[:2] == ('gh', 'issue') else draft if a[:2] == ('gh', 'pr') else '[[]]' if a[:2] == ('gh', 'api') else 'main' if a[:2] == ('git', 'branch') else ''), patch.object(team, 'active', return_value=['vael-issue-5']), patch.object(team.subprocess, 'run') as sub:
            self.assertEqual(team.lead(), 0)
            sub.assert_not_called()

    def test_blocked_issue_is_not_an_actionable_queue(self):
        issue = json.dumps([{'number': 2, 'title': 'Wait', 'labels': [{'name': 'team:blocked'}]}])
        with patch.object(team, 'run', side_effect=lambda *a: issue if a[:2] == ('gh', 'issue') else '[]' if a[:2] == ('gh', 'pr') else '[[]]' if a[:2] == ('gh', 'api') else 'main' if a[:2] == ('git', 'branch') else ''), patch.object(team, 'active', return_value=['vael-issue-5']), patch.object(team.subprocess, 'run') as sub:
            self.assertEqual(team.lead(), 0)
            sub.assert_not_called()

    def test_existing_worktree_must_match_repository_and_issue_branch(self):
        import subprocess
        repo = self.state / 'repo'
        repo.mkdir()
        def git(*args):
            return subprocess.run(['git', '-C', str(repo), *args], check=True, capture_output=True, text=True)
        git('init', '-b', 'main')
        git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '--allow-empty', '-m', 'seed')
        wt = self.state / 'issue-8'
        git('worktree', 'add', '-b', 'team/issue-8', str(wt))
        with patch.object(team, 'REPO', repo):
            team.validate_worktree(wt, 'team/issue-8')
            with self.assertRaisesRegex(RuntimeError, 'wrong branch'):
                team.validate_worktree(wt, 'team/issue-9')
            other = self.state / 'different'
            subprocess.run(['git', 'init', '-q', str(other)], check=True)
            with patch.object(team, 'REPO', other):
                with self.assertRaisesRegex(RuntimeError, 'different repository'):
                    team.validate_worktree(wt, 'team/issue-8')


    def test_cloud_billing_selectors_are_not_inherited(self):
        names = ['CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY',
                 'ANTHROPIC_PROFILE', 'CLAUDE_CODE_OAUTH_TOKEN', 'CLAUDE_CONFIG_DIR']
        with patch.dict(os.environ, {name: 'test' for name in names}):
            env = team.environment()
        for name in names:
            self.assertNotIn(name, env)
        cmd = team.command('opus')
        self.assertEqual(cmd[cmd.index('--setting-sources') + 1], '')
        self.assertIn('claudeai', cmd[cmd.index('--settings') + 1])

    def test_console_auth_is_rejected_without_logging_credentials(self):
        import subprocess
        console = subprocess.CompletedProcess([], 0, json.dumps({'loggedIn': True,
                    'authMethod': 'api_key', 'apiProvider': 'firstParty', 'subscriptionType': 'pro'}))
        with patch.object(team.subprocess, 'run', return_value=console):
            with self.assertRaisesRegex(RuntimeError, 'subscription'):
                team.claude_subscription(self.state, {})

    def test_session_id_is_from_native_output_not_checkout_existence(self):
        log = self.state / 'native.log'
        log.write_text('')
        self.assertIsNone(team.native_session('sol', log))
        for profile, field in [('sol', 'thread_id'), ('opus', 'session_id'),
                               ('argon', 'conversation_id'), ('deepseek', 'sessionID')]:
            log.write_text(json.dumps({'type': 'thread.started', field: 'session-issue-1234'}))
            self.assertEqual(team.native_session(profile, log), 'session-issue-1234')

    def test_missing_executable_records_failure_and_blocks_issue(self):
        assignment = {'profile': 'sol', 'issue': {'number': 7, 'title': 'Fixture', 'body': ''},
                      'worktree': str(self.state), 'session_id': None}
        (self.state / 'issue-7.json').write_text(json.dumps(assignment))
        with patch.object(team.subprocess, 'run', side_effect=FileNotFoundError), patch.object(team, 'block_issue') as block:
            self.assertEqual(team.worker(7), 1)
            block.assert_called_once_with(7, 'sol', 1)
        self.assertEqual((self.state / 'issue-7.exit').read_text(), '1')
        self.assertIsNone(json.loads((self.state / 'issue-7.json').read_text())['session_id'])

    def test_failed_github_block_pauses_dispatch_not_existing_work(self):
        import subprocess
        with patch.object(team.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, ['gh'])):
            team.block_issue(7, 'sol', 1)
        self.assertTrue((self.state / 'paused').exists())
        self.assertEqual((self.state / 'issue-7.exit').read_text(), '1')

    def test_lead_query_or_spawn_failure_is_recorded_once_and_paused(self):
        with patch.object(team, 'run', side_effect=FileNotFoundError):
            self.assertEqual(team.lead(), 1)
        self.assertTrue((self.state / 'paused').exists())
        self.assertEqual((self.state / 'lead.exit').read_text(), '1')


    def test_failed_first_tmux_launch_does_not_invent_session(self):
        import subprocess
        worktree = self.state / 'worktrees/7'
        worktree.mkdir(parents=True)
        issue = json.dumps({'number': 7, 'title': 'Fixture', 'body': '', 'state': 'OPEN'})
        def fake_run(*args, **kwargs):
            return issue if args[:3] == ('gh', 'issue', 'view') else ''
        with patch.object(team, 'active', return_value=[]), patch.object(team, 'run', side_effect=fake_run), \
                patch.object(team, 'validate_worktree'), patch.object(team, 'block_issue') as block, \
                patch.object(team.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, ['tmux'])):
            with self.assertRaises(subprocess.CalledProcessError):
                team.start(7, 'sol')
            block.assert_called_once_with(7, 'sol', 1)
        assignment = json.loads((self.state / 'issue-7.json').read_text())
        self.assertIsNone(assignment['session_id'])
        self.assertNotIn('resume', team.command('sol', assignment['session_id']))

    def test_two_issue_resumes_use_distinct_persisted_ids(self):
        for number in (7, 8):
            assignment = {'profile': 'sol', 'session_id': f'issue-{number}-native-session'}
            (self.state / f'issue-{number}.json').write_text(json.dumps(assignment))
        commands = []
        for number in (7, 8):
            assignment = json.loads((self.state / f'issue-{number}.json').read_text())
            commands.append(team.command(assignment['profile'], assignment['session_id']))
        self.assertIn('issue-7-native-session', commands[0])
        self.assertNotIn('issue-8-native-session', commands[0])
        self.assertIn('issue-8-native-session', commands[1])


    def test_interrupted_first_turn_recovers_confirmed_id_from_its_own_log(self):
        import subprocess
        worktree = self.state / 'worktrees/7'
        worktree.mkdir(parents=True)
        (self.state / 'issue-7.json').write_text(json.dumps({'profile': 'sol', 'session_id': None}))
        (self.state / 'issue-7-100.log').write_text(json.dumps(
            {'type': 'thread.started', 'thread_id': 'issue-seven-confirmed-session'}) + '\npartial tail')
        (self.state / 'issue-8-200.log').write_text(json.dumps(
            {'type': 'thread.started', 'thread_id': 'other-issue-session'}))
        issue = json.dumps({'number': 7, 'title': 'Interrupted', 'body': '', 'state': 'OPEN'})
        def fake_run(*args, **kwargs):
            return issue if args[:3] == ('gh', 'issue', 'view') else ''
        with patch.object(team, 'active', return_value=[]), patch.object(team, 'run', side_effect=fake_run), \
                patch.object(team, 'validate_worktree'), \
                patch.object(team.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)):
            team.start(7, 'sol')
        assignment = json.loads((self.state / 'issue-7.json').read_text())
        self.assertEqual(assignment['session_id'], 'issue-seven-confirmed-session')
        self.assertIn('issue-seven-confirmed-session', team.command('sol', assignment['session_id']))


if __name__ == '__main__':
    unittest.main()
