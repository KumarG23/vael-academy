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
        with patch.object(team, 'run', side_effect=['[]', draft]), patch.object(team.subprocess, 'run') as sub:
            self.assertEqual(team.lead(), 0)
            sub.assert_not_called()

    def test_blocked_issue_is_not_an_actionable_queue(self):
        issue = json.dumps([{'number': 2, 'title': 'Wait', 'labels': [{'name': 'team:blocked'}]}])
        with patch.object(team, 'run', side_effect=[issue, '[]']), patch.object(team.subprocess, 'run') as sub:
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


if __name__ == '__main__':
    unittest.main()
