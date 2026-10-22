"""Daily launch gating without model, GitHub writes or live team state."""
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('team_hours', TOOLS / 'team.py')
team = importlib.util.module_from_spec(spec)
spec.loader.exec_module(team)
schedule = team.work_schedule


class WorkScheduleTests(unittest.TestCase):
    def test_boundaries_weekends_and_utc_dst(self):
        for date, offset in [('2026-01-10', '-05:00'), ('2026-07-12', '-04:00')]:
            for at, opened, next_at in [
                ('06:59', False, date + 'T07:00:00' + offset),
                ('07:00', True, None),
                ('16:59', True, None),
                ('17:00', False, None),
            ]:
                now = datetime.fromisoformat(date + 'T' + at + ':00' + offset)
                result = schedule.status(now)
                self.assertEqual(result['open'], opened)
                if next_at:
                    self.assertEqual(result['next_open_at'], next_at)
                elif opened:
                    self.assertIsNone(result['next_open_at'])
                else:
                    self.assertEqual(datetime.fromisoformat(result['next_open_at']).date().toordinal(),
                                     now.date().toordinal() + 1)
                self.assertEqual(result['policy'], 'finish_in_flight')
                self.assertEqual(result['days'], 'every_day')
                self.assertEqual(result['timezone'], 'America/New_York')
        self.assertFalse(schedule.status(datetime(2026, 3, 8, 10, 59, tzinfo=timezone.utc))['open'])
        self.assertTrue(schedule.status(datetime(2026, 3, 8, 11, 0, tzinfo=timezone.utc))['open'])
        self.assertFalse(schedule.status(datetime(2026, 11, 1, 11, 59, tzinfo=timezone.utc))['open'])
        self.assertTrue(schedule.status(datetime(2026, 11, 1, 12, 0, tzinfo=timezone.utc))['open'])
        with self.assertRaises(ValueError):
            schedule.status(datetime(2026, 1, 1, 8))

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.state = Path(tmp.name)
        for attr in ('STATE', 'REPO'):
            p = patch.object(team, attr, self.state)
            p.start()
            self.addCleanup(p.stop)

    def test_off_hours_lead_zero_model_poll_and_pending_nudge(self):
        team.record_event('manual', 'test-nudge')
        with patch.object(schedule, 'status', return_value={'open': False}), \
             patch.object(team, 'run') as gh, patch.object(team, 'preflight') as preflight, \
             patch.object(team.subprocess, 'run') as native:
            self.assertEqual(team.lead(), 0)
            gh.assert_not_called()
            preflight.assert_not_called()
            native.assert_not_called()
        self.assertFalse((self.state / 'paused').exists())
        self.assertFalse((self.state / 'lead-receipt.json').exists())
        self.assertFalse((self.state / 'lead.exit').exists())
        self.assertTrue(team.pending_events_snapshot())
        from sqlite3 import connect
        with connect(team._analytics_db()) as db:
            self.assertEqual(db.execute('select outcome from polls').fetchone()[0],
                             'outside_work_hours')

    def test_off_hours_start_handoff_dispatch_and_worker_have_no_mutation(self):
        assignment = self.state / 'issue-7.json'
        contents = json.dumps({'profile': 'sol-dev', 'issue': {'number': 7, 'title': 'fixture', 'body': ''},
                               'worktree': str(self.state), 'session_id': 'existing-native-session'})
        assignment.write_text(contents)
        with patch.object(schedule, 'status', return_value={'open': False}), \
             patch.object(team, 'run') as gh, patch.object(team, 'preflight') as preflight, \
             patch.object(team, 'active') as sessions, patch.object(team.subprocess, 'run') as native:
            for action in (lambda: team.start(7, 'sol-dev'), lambda: team.handoff(7, 'opus')):
                with self.assertRaisesRegex(RuntimeError, 'Outside daily'):
                    action()
            self.assertEqual(team.worker(7), 0)
            for mock in (gh, preflight, sessions, native):
                mock.assert_not_called()
        self.assertEqual(json.loads(assignment.read_text())['session_id'], 'existing-native-session')
        self.assertTrue(json.loads(assignment.read_text())['work_hours_deferred'])
        self.assertFalse((self.state / 'issue-7.exit').exists())
        self.assertFalse((self.state / 'paused').exists())

    def test_worker_dispatch_before_close_but_native_launch_after_close_defers(self):
        assignment = self.state / 'issue-7.json'
        assignment.write_text(json.dumps({'profile': 'sol-dev', 'issue': {'number': 7, 'title': 'fixture', 'body': ''},
                                          'worktree': str(self.state), 'session_id': 'existing-native-session'}))
        schedule_reads = iter([{'open': True}, {'open': True}, {'open': False}])
        with patch.object(schedule, 'status', side_effect=lambda: next(schedule_reads)), \
             patch.object(team, 'preflight') as preflight, \
             patch.object(team.subprocess, 'run') as native:
            self.assertEqual(team.worker(7), 0)
            preflight.assert_called_once()
            native.assert_not_called()
        saved = json.loads(assignment.read_text())
        self.assertEqual(saved['session_id'], 'existing-native-session')
        self.assertNotIn('worker_pid', saved)
        self.assertTrue(saved['work_hours_deferred'])
        self.assertFalse((self.state / 'issue-7.exit').exists())
        self.assertFalse((self.state / 'paused').exists())
        self.assertFalse((self.state / 'issue-7.pid').exists())

    def test_deferred_handoff_retries_same_lineage_when_window_reopens(self):
        assignment = self.state / 'issue-7.json'
        entry = {'to_profile': 'opus', 'source_run_id': 'prior-run', 'exit_mtime_ns': 0}
        original = {'profile': 'opus', 'issue': {'number': 7}, 'worktree': str(self.state),
                    'session_id': None, 'blocked': {'run_id': 'prior-run'},
                    'handoff_state': entry, 'work_hours_deferred': True}
        assignment.write_text(json.dumps(original))
        with patch.object(schedule, 'status', return_value={'open': True}), \
             patch.object(team, 'provider_quota_status', return_value={'eligible': True}), \
             patch.object(team, 'confirm_worker_exited', return_value=True), \
             patch.object(team, 'validate_worktree') as validate, \
             patch.object(team, 'launch_worker') as launch, \
             patch.object(team, 'run') as gh:
            self.assertEqual(team.handoff(7, 'opus'), entry)
            validate.assert_called_once()
            launch.assert_called_once_with(7, self.state)
            gh.assert_not_called()
        self.assertEqual(json.loads(assignment.read_text()), original)


if __name__ == '__main__':
    unittest.main()
