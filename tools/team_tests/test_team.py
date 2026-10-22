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
        self.assertEqual(team.command('sol', True)[2:4], ['resume', '--last'])
        self.assertIn('--continue', team.command('opus', True))
        self.assertIn('--continue', team.command('argon', True))

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
        with patch.object(team, 'active', return_value=['vael-issue-1', 'vael-issue-2']):
            with self.assertRaisesRegex(RuntimeError, 'Two writers'):
                team.start(3, 'sol')

    def test_closed_issue_does_not_create_workspace(self):
        with patch.object(team, 'active', return_value=[]), patch.object(team, 'run',
                  return_value=json.dumps({'state': 'CLOSED'})) as run:
            with self.assertRaisesRegex(RuntimeError, 'not open'):
                team.start(3, 'sol')
            self.assertEqual(run.call_count, 1)

    def test_idle_lead_does_not_call_a_model(self):
        with patch.object(team, 'run', return_value='[]'), patch.object(team.subprocess, 'run') as sub:
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


if __name__ == '__main__':
    unittest.main()
