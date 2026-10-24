"""Launcher-authored GitHub posts must be recognisable as automation.

Every native `gh issue comment` emitted by the launcher is captured here with a
fake subprocess, then fed through the real discussion observer. No model or
GitHub call is made, and a same-account unmarked reply must stay material.
"""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('team', Path(__file__).parents[1] / 'team.py')
assert spec is not None and spec.loader is not None
team = importlib.util.module_from_spec(spec)
spec.loader.exec_module(team)

MARKER = team.lead_observation.AUTO_MARKER


def comment_body(args):
    body = list(args)
    index = body.index('--body')
    return body[index + 1]


class AutomationMarkerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name)
        for target in ('STATE', 'GLOBAL_STATE', 'REPO'):
            patcher = patch.object(team, target, self.state)
            patcher.start()
            self.addCleanup(patcher.stop)
        patcher = patch.object(team.work_schedule, 'status', return_value={'open': True})
        patcher.start()
        self.addCleanup(patcher.stop)

    def assert_automation(self, body, *explanatory):
        self.assertTrue(body.startswith(MARKER), body)
        self.assertEqual(body.count(MARKER), 1, body)
        for text in explanatory:
            self.assertIn(text, body)

    def gh_process(self, calls):
        def fake(args, *rest, **kwargs):
            calls.append(list(args))
            return subprocess.CompletedProcess(args, 0, stdout='')
        return fake

    def start_body(self):
        (self.state / 'worktrees/9').mkdir(parents=True)
        issue = json.dumps({'number': 9, 'title': 'Bound task', 'body': '', 'state': 'OPEN'})
        comments = []

        def fake_run(*args, **kwargs):
            if args[:3] == ('gh', 'issue', 'view'):
                return issue
            if args[:3] == ('gh', 'issue', 'comment'):
                comments.append(args)
                return ''
            return ''

        with patch.object(team, 'active', return_value=[]), \
                patch.object(team, 'run', side_effect=fake_run), \
                patch.object(team, 'validate_worktree'), \
                patch.object(team.shutil, 'disk_usage',
                             return_value=SimpleNamespace(free=10 * 1024 ** 3)), \
                patch.object(team.subprocess, 'run',
                             side_effect=self.gh_process([])):
            team.start(9, 'deepseek')
        self.assertEqual(len(comments), 1)
        return comment_body(comments[0])

    def block_body(self, **failure):
        calls = []
        with patch.object(team.subprocess, 'run', side_effect=self.gh_process(calls)):
            team.block_issue(7, 'sol', 7, **failure)
        emitted = [call for call in calls if call[:3] == ['gh', 'issue', 'comment']]
        self.assertEqual(len(emitted), 1)
        return comment_body(emitted[0])

    def escalation_body(self):
        (self.state / 'issue-15.json').write_text(json.dumps({
            'profile': 'opus',
            'session_id': 'fixture-session',
            'issue': {'number': 15, 'title': 'Quota work', 'body': ''},
            'worktree': str(self.state / 'worktrees/15'),
            'blocked': {'failure_kind': 'quota_exhausted', 'blocked_reason': 'session_limit'},
        }))
        calls = []
        with patch.object(team.subprocess, 'run', side_effect=self.gh_process(calls)):
            team.decide_quota(15, 'escalate', now_ts=1000.0)
        emitted = [call for call in calls if call[:3] == ['gh', 'issue', 'comment']]
        self.assertEqual(len(emitted), 1)
        return comment_body(emitted[0])

    def handoff_body(self):
        worktree = self.state / 'worktrees/16'
        worktree.mkdir(parents=True)
        (self.state / 'issue-16.json').write_text(json.dumps({
            'profile': 'opus',
            'session_id': 'fixture-session',
            'issue': {'number': 16, 'title': 'Handoff work', 'body': ''},
            'worktree': str(worktree),
            'blocked': {'failure_kind': 'quota_exhausted', 'blocked_reason': 'session_limit',
                        'run_id': 'fixture-run'},
        }))
        (self.state / 'issue-16.exit').write_text('1')
        comments = []

        def fake_run(*args, **kwargs):
            if args[:3] == ('gh', 'issue', 'comment'):
                comments.append(args)
            return ''

        with patch.object(team, 'active', return_value=[]), \
                patch.object(team, 'validate_worktree'), \
                patch.object(team, 'worktree_progress', return_value={'branch': 'team/issue-16'}), \
                patch.object(team, 'launch_worker'), \
                patch.object(team, 'run', side_effect=fake_run), \
                patch.object(team.subprocess, 'run', side_effect=self.gh_process([])):
            team.handoff(16, 'argon', now_ts=1025.0)
        self.assertEqual(len(comments), 1)
        return comment_body(comments[0])

    def scan(self, bodies, stamp):
        rows = [{'id': 100 + index, 'body': body, 'user': {'login': 'shared-account'},
                 'issue_url': f'https://api.github.com/repos/{team.SLUG}/issues/5'}
                for index, body in enumerate(bodies)]

        def fake(*args):
            return json.dumps(rows if '/issues/comments?' in args[-1] else [])

        return team.lead_observation.collect(
            fake, team.SLUG, [5], [], self.state / 'discussion-receipt.json', stamp)

    def test_start_assignment_comment_is_marked_automation(self):
        self.assert_automation(self.start_body(), 'Engineering assignment: `deepseek`',
                               'Plan/bible alignment, tests, and lead review')

    def test_ordinary_block_report_is_marked_automation(self):
        self.assert_automation(self.block_body(), 'launch/turn did not complete (status 7)',
                               'No automatic model or paid-route fallback')

    def test_quota_block_report_is_marked_automation(self):
        body = self.block_body(failure_kind='quota_exhausted', blocked_reason='session_limit',
                               reset_info={'reset_at': 1700000000, 'reset_timezone': 'UTC'})
        self.assert_automation(body, 'stopped due to provider quota (`session_limit`)',
                               'Reported reset: 1700000000 (UTC)',
                               'No paid-route fallback')

    def test_quota_escalation_comment_is_marked_automation(self):
        self.assert_automation(self.escalation_body(), 'Lead quota escalation on issue #15',
                               'Preserved worktree and session lineage remain intact')

    def test_quota_handoff_comment_is_marked_automation(self):
        self.assert_automation(self.handoff_body(),
                               'Lead quota handoff: reassigning issue #16 from `opus` to `argon`',
                               'Existing worktree and lineage preserved')

    def test_marker_is_never_duplicated_on_an_already_marked_body(self):
        body = team.automated_comment(MARKER + '\nAlready marked')
        self.assertEqual(body, MARKER + '\nAlready marked')

    def test_observer_treats_launcher_comments_as_automation_but_human_reply_material(self):
        bodies = [self.start_body(), self.block_body(),
                  self.block_body(failure_kind='quota_exhausted', blocked_reason='session_limit'),
                  self.escalation_body(), self.handoff_body()]
        for body in bodies:
            self.assert_automation(body)

        baseline = self.scan([], 1000)
        self.assertTrue(baseline['baseline'])
        team.lead_observation.commit(self.state / 'discussion-receipt.json', baseline)
        automated = self.scan(bodies, 1100)
        self.assertEqual(automated['deltas'], [])

        human = 'Human: please change the ordering before merge'
        material = self.scan(bodies + [human], 1200)
        self.assertEqual([d['change'] for d in material['deltas']], ['new'])
        self.assertEqual(material['deltas'][0]['id'], 100 + len(bodies))


if __name__ == '__main__':
    unittest.main()
