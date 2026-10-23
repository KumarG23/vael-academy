"""Multi-project identity and scheduler regressions; never run native inference."""
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from test_team import team


class MultiProjectTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.vael = root / 'vael'; self.command = root / 'command'
        for state in (self.vael, self.command):
            (state / 'worktrees').mkdir(parents=True)
        self.registry = {
            'vael': {'state': str(self.vael), 'repo': str(root/'repo-vael'), 'slug': 'KumarG23/vael-academy', 'base': 'main'},
            'command': {'state': str(self.command), 'repo': str(root/'repo-command'), 'slug': 'KumarG23/jarvis-command', 'base': 'release/gpt6-sol-luna'},
        }
        self.stack = [patch.object(team, 'registry', return_value=self.registry),
                      patch.object(team, 'GLOBAL_STATE', self.vael),
                      patch.object(team.work_schedule, 'status', return_value={'open': True})]
        for p in self.stack:
            p.start(); self.addCleanup(p.stop)

    def test_issue_two_has_distinct_identity_and_no_cross_repo_actions(self):
        self.assertNotEqual('team/issue-2', 'team/command/issue-2')
        with patch.object(team, 'PROJECT', 'command'), patch.object(team, 'SLUG', 'KumarG23/jarvis-command'), \
             patch.object(team, 'BASE', 'release/gpt6-sol-luna'), patch.object(team, 'STATE', self.command), \
             patch.object(team, 'REPO', Path(self.registry['command']['repo'])), \
             patch.object(team, 'active', return_value=[]), patch.object(team, 'validate_worktree'), \
             patch.object(team.shutil, 'disk_usage', return_value=SimpleNamespace(free=10 * 1024**3)):
            self.assertEqual(team.issue_branch(2), 'team/command/issue-2')
            self.assertEqual(team.session_name(2), 'studio-command-issue-2')
            calls = []
            def fake_run(*args, **kwargs):
                calls.append((args, kwargs))
                if args[:3] == ('gh', 'issue', 'view'):
                    return json.dumps({'number': 2, 'title': 'M0', 'body': '', 'state': 'OPEN'})
                return ''
            with patch.object(team, 'run', side_effect=fake_run), patch.object(team.subprocess, 'run', return_value=SimpleNamespace(returncode=1)) as subprocess_run, patch.object(team, 'launch_worker'):
                team.start(2, 'luna')
            self.assertTrue(all('--repo' not in args or args[args.index('--repo')+1] == 'KumarG23/jarvis-command' for args, _ in calls))
            self.assertTrue(any(args[:3] == ('git', 'fetch', 'origin') and args[3] == 'release/gpt6-sol-luna' for args, _ in calls))
            self.assertTrue(any('origin/release/gpt6-sol-luna' in args for args, _ in calls))
            self.assertTrue(any('team/command/issue-2' in args for args, _ in calls))
            self.assertFalse(any('origin/main' in args or 'team/issue-2' in args for args, _ in calls))
            self.assertEqual(json.loads((self.command/'issue-2.json').read_text())['repo'], 'KumarG23/jarvis-command')
            with self.assertRaisesRegex(RuntimeError, 'M0-only'):
                team.start(3, 'luna')

    def test_pauses_and_receipts_independent_shared_quota(self):
        (self.command/'paused').write_text('Command pause')
        (self.command/'lead-receipt.json').write_text(json.dumps({'checked_at': 1, 'parts': {'main': 'command'}}))
        (self.vael/'lead-receipt.json').write_text(json.dumps({'checked_at': 1, 'parts': {'main': 'vael'}}))
        with patch.object(team, 'STATE', self.vael):
            self.assertFalse((team.STATE/'paused').exists())
            self.assertEqual(team.wake_reasons({'main': 'vael'}), [])
            team.record_provider_quota('argon','quota_exceeded',{'reset_at':None})
        with patch.object(team, 'STATE', self.command):
            self.assertTrue((team.STATE/'paused').exists())
            self.assertEqual(team.wake_reasons({'main': 'command'}), [])
            self.assertFalse(team.provider_quota_status('argon')['eligible'])
            self.assertIn('quota', team.snapshot('head', [], [], []))
        self.assertTrue((self.vael/'quota-agy_argon_weekly.json').exists())
        self.assertFalse((self.command/'quota-agy_argon_weekly.json').exists())

    def test_capacity_counts_both_project_sockets(self):
        with patch.object(team, 'PROJECT','vael'), patch.object(team, 'STATE', self.vael), \
             patch.object(team.subprocess, 'run', side_effect=[SimpleNamespace(stdout='vael-issue-2\n'),SimpleNamespace(stdout='vael-issue-3\n'),SimpleNamespace(stdout='studio-command-issue-2\n')]):
            self.assertEqual(len(team.active()), 3)
        with patch.object(team, 'STATE', self.vael), patch.object(team, 'active', return_value=['vael-issue-2','vael-issue-3','studio-command-issue-2']):
            with self.assertRaisesRegex(RuntimeError,'Three workers'):
                team.start(4,'luna')

    def test_intake_migration_is_readback_safe_and_idempotent(self):
        key = 'project-intake:https://github.com/KumarG23/jarvis-command/issues/2'
        (self.vael/'pending-events.json').write_text(json.dumps({key:{'kind':'project-intake','key':key.partition(':')[2]}}))
        self.assertTrue(team.migrate_intake())
        self.assertFalse(team.migrate_intake())
        self.assertIn(key,json.loads((self.command/'pending-events.json').read_text()))
        self.assertNotIn(key,json.loads((self.vael/'pending-events.json').read_text()))


    def test_fair_rotating_poll_keeps_independent_passes(self):
        for cfg in self.registry.values():
            Path(cfg['repo']).mkdir()
        with patch.object(team.subprocess, 'run', side_effect=lambda cmd, **kw: SimpleNamespace(returncode=0)) as run:
            self.assertEqual(team.lead_all(), 0)
            first = [call.kwargs['env']['STUDIO_PROJECT'] for call in run.call_args_list]
            run.reset_mock()
            self.assertEqual(team.lead_all(), 0)
            second = [call.kwargs['env']['STUDIO_PROJECT'] for call in run.call_args_list]
        self.assertEqual(first, ['command', 'vael'])
        self.assertEqual(second, ['vael', 'command'])
        self.assertFalse((self.command/'lead-receipt.json').exists())

    def test_window_prevents_poll_and_worker_before_models(self):
        with patch.object(team.work_schedule, 'status', return_value={'open':False}), patch.object(team.subprocess,'run',return_value=SimpleNamespace(returncode=0)) as spawn:
            self.assertEqual(team.lead_all(),0)
            self.assertEqual(spawn.call_count, 0)  # Parent gates before launching either child.
            with self.assertRaisesRegex(RuntimeError,'Outside daily'):
                team.start(2,'luna')

    def test_command_prompt_restricts_scope_and_reads_unmerged_plan(self):
        with patch.object(team,'PROJECT','command'), patch.object(team,'SLUG','KumarG23/jarvis-command'),patch.object(team,'BASE','release/gpt6-sol-luna'):
            prompt=team.lead_prompt([],[],[],['first pass'])
            self.assertIn('origin/docs/jarvis-command-v2-plan:MASTER_PLAN.md',prompt)
            self.assertIn('issue #2',prompt)
            self.assertIn('no implementation',prompt)
            self.assertIn('Never merge PR #3',prompt)
