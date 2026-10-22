"""Regressions for actual lead launch metadata and stale completion rows."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('completion_ua', Path(__file__).parents[1] / 'usage_analytics.py')
ua = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ua)


class LeadCompletionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name)
        self.db = self.state / 'usage.sqlite3'
        self.log = self.state / 'lead-1792687754493881846.log'
        self.args = dict(log_path=self.log, role='lead', profile='sol', provider='codex',
                         requested_model='gpt-6.1-sol', effort='high', started_at=1000,
                         repo='example/repo', trigger='timer', wake_reasons=['prs', 'workers'])
        self.log.write_text(json.dumps({'type': 'thread.started', 'thread_id': 'synthetic-lead-session'}) + '\n' +
                            json.dumps({'type': 'turn.completed', 'usage': {'input_tokens': 100,
                                       'cached_input_tokens': 80, 'output_tokens': 10}}) + '\n')

    def row(self):
        c = ua.connect(self.db, readonly=True)
        try:
            return dict(c.execute('select * from runs').fetchone())
        finally:
            c.close()

    def test_real_lead_finish_accepts_wake_list_and_retains_usage(self):
        ua.record_start(self.db, **self.args)
        ua.record_finish(self.db, **self.args, finished_at=1100, exit_code=0)
        row = self.row()
        self.assertEqual((row['status'], row['wake_reasons'], row['trigger']), ('success', 'prs,workers', 'timer'))
        self.assertEqual((row['input_tokens'], row['cached_input_tokens'], row['output_tokens']), (100, 80, 10))
        ua.record_finish(self.db, **self.args, finished_at=1100, exit_code=0)
        self.assertEqual(self.row()['input_tokens'], 100)

    def test_recent_terminal_log_reconciles_without_ten_minute_delay(self):
        ua.record_start(self.db, **self.args)
        ua.reconcile_running(self.db, self.state, [], older_than=600)
        row = self.row()
        self.assertEqual(row['status'], 'success')
        self.assertEqual(row['wake_reasons'], 'prs,workers')
        self.assertEqual(row['input_tokens'], 100)

    def test_duplicate_start_cannot_regress_finished_run(self):
        ua.record_finish(self.db, **self.args, finished_at=1100, exit_code=0)
        ua.record_start(self.db, **self.args)
        self.assertEqual(self.row()['status'], 'success')

    def test_live_worker_is_not_interrupted_by_reconciliation(self):
        args = {**self.args, 'role': 'worker', 'issue_number': 7,
                'log_path': self.state / 'issue-7-1792687754493881846.log'}
        args['log_path'].write_text(self.log.read_text())
        ua.record_start(self.db, **args)
        ua.reconcile_running(self.db, self.state, ['vael-issue-7'], older_than=0)
        self.assertEqual(self.row()['status'], 'running')
