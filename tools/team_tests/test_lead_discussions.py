import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('lead_observation', Path(__file__).parents[1] / 'lead_observation.py')
obs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(obs)


class DiscussionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'discussion-receipt.json'
        self.comments, self.inline, self.reviews, self.calls = [], [], [], []

    def github(self, *args):
        self.calls.append(args)
        endpoint = args[-1]
        rows = self.inline if '/pulls/comments?' in endpoint else self.reviews if '/reviews?' in endpoint else self.comments
        return json.dumps(rows[:1]) + '\n' + json.dumps(rows[1:])  # Actual older gh --paginate shape.

    def scan(self, now=1000):
        return obs.collect(self.github, 'example/repo', [30], [34], self.path, now)

    def comment(self, ident=1, body='Human decision', number=30):
        return {'id': ident, 'body': body, 'user': {'login': 'shared-account'},
                'issue_url': f'https://api.github.com/repos/example/repo/issues/{number}'}

    def baseline(self):
        result = self.scan()
        self.assertTrue(result['baseline'])
        obs.commit(self.path, result)

    def test_blocked_issue_reply_wakes_without_body_or_user_in_receipt(self):
        self.baseline()
        self.comments = [self.comment()]
        result = self.scan(1100)
        self.assertEqual([(x['kind'], x['number'], x['change']) for x in result['deltas']], [('comment', 30, 'new')])
        text = json.dumps(result['receipt'])
        self.assertNotIn('Human decision', text)
        self.assertNotIn('shared-account', text)

    def test_same_account_auto_marker_does_not_hide_unmarked_human(self):
        self.baseline()
        self.comments = [self.comment(body=obs.AUTO_MARKER + '\nLead bookkeeping'), self.comment(2)]
        result = self.scan(1100)
        self.assertEqual([d['id'] for d in result['deltas']], [2])
        obs.commit(self.path, result)
        self.assertEqual(self.scan(1200)['deltas'], [])

    def test_quoted_marker_is_not_silenced(self):
        self.baseline()
        self.comments = [self.comment(body='Please correct this:\n' + obs.AUTO_MARKER)]
        self.assertEqual(len(self.scan(1100)['deltas']), 1)

    def test_edit_detected_and_failed_consumption_does_not_ack(self):
        self.comments = [self.comment()]
        self.baseline()
        self.comments[0]['body'] = 'Changed decision'
        first = self.scan(1100)
        self.assertEqual(first['deltas'][0]['change'], 'edited')
        self.assertEqual(obs.delta_keys(self.scan(1200)), obs.delta_keys(first))
        obs.commit(self.path, first)
        self.assertEqual(self.scan(1300)['deltas'], [])

    def test_inline_and_review_state_changes_detected(self):
        self.baseline()
        self.inline = [{'id': 8, 'body': 'Fix this', 'pull_request_url': 'https://api.github.com/repos/example/repo/pulls/34'}]
        self.reviews = [{'id': 9, 'body': '', 'state': 'CHANGES_REQUESTED'}]
        first = self.scan(1100)
        self.assertEqual({d['kind'] for d in first['deltas']}, {'inline', 'review'})
        obs.commit(self.path, first)
        self.reviews[0]['state'] = 'DISMISSED'
        self.assertEqual([d['kind'] for d in self.scan(1200)['deltas']], ['review'])

    def test_new_reply_during_model_turn_is_not_consumed(self):
        self.baseline()
        self.comments = [self.comment()]
        before_turn = self.scan(1100)
        self.comments.append(self.comment(2, 'Arrived during turn'))
        obs.commit(self.path, before_turn)
        self.assertEqual([d['id'] for d in self.scan(1200)['deltas']], [2])

    def test_hourly_scan_detects_deletion_and_unchanged_is_empty(self):
        self.comments = [self.comment()]
        self.baseline()
        self.assertEqual(self.scan(4700)['deltas'], [])
        self.comments = []
        result = self.scan(4700)
        self.assertTrue(result['full_scan'])
        self.assertEqual(result['deltas'][0]['change'], 'removed')

    def test_unrelated_closed_or_other_issue_does_not_wake(self):
        self.baseline()
        self.comments = [self.comment(number=999)]
        self.assertEqual(self.scan(1100)['deltas'], [])

    def test_partial_or_failed_github_scan_never_commits_empty_state(self):
        self.comments = [self.comment()]
        self.baseline()
        original = self.path.read_bytes()
        def bad(*args): return '{}'
        with self.assertRaises(ValueError):
            obs.collect(bad, 'example/repo', [30], [], self.path, 2000)
        self.assertEqual(self.path.read_bytes(), original)

    def test_pending_review_is_not_prematurely_consumed(self):
        self.baseline()
        self.reviews = [{'id': 9, 'body': 'draft', 'state': 'PENDING'}]
        self.assertEqual(self.scan(1100)['deltas'], [])
        self.reviews[0]['state'] = 'CHANGES_REQUESTED'
        self.assertEqual(self.scan(1200)['deltas'][0]['id'], 9)
