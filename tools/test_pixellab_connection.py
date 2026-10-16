"""VS-1B VFX connection regression: synthetic credentials, no network or spend."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

CLIENT = Path(__file__).resolve().parents[1] / 'assets/source/pixellab/tools/pixellab.py'
spec = importlib.util.spec_from_file_location('vael_pixellab', CLIENT)
client = importlib.util.module_from_spec(spec)
spec.loader.exec_module(client)


class CredentialTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.env = Path(self.tmp.name) / '.env'
        self.config = Path(self.tmp.name) / 'legacy.json'
        self.environ = patch.dict(os.environ, {}, clear=True)
        self.environ.start()
        self.addCleanup(self.environ.stop)

    def test_missing_fails_before_network_and_never_uses_gemini_key(self):
        self.env.write_text('VAEL_ART_API_KEY=not-a-pixellab-key\n')
        with self.assertRaisesRegex(RuntimeError, 'PixelLab credential unavailable'):
            client._token(self.env, self.config)

    def test_project_env_quotes_comments_and_environment_precedence(self):
        self.env.write_text('export PIXELLAB_API_KEY="fake-local-key" # comment\n')
        self.assertEqual(client._token(self.env, self.config), 'fake-local-key')
        os.environ['PIXELLAB_API_KEY'] = 'fake-process-key'
        self.assertEqual(client._token(self.env, self.config), 'fake-process-key')

    def test_legacy_configuration_compatibility(self):
        self.config.write_text('{"projects":{"x":{"mcpServers":{"pixellab":{"headers":{"Authorization":"Bearer fake-legacy"}}}}}}')
        self.assertEqual(client._token(self.env, self.config), 'fake-legacy')


class BridgeTests(unittest.TestCase):
    def setUp(self):
        path = Path(__file__).resolve().parent / 'pixellab_mcp_stdio.py'
        spec = importlib.util.spec_from_file_location('vael_stdio', path)
        self.bridge = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.bridge)

    def test_initialize_and_notifications(self):
        self.assertIsNone(self.bridge.respond({'method': 'notifications/initialized'}))
        r = self.bridge.respond({'id': 7, 'method': 'initialize', 'params': {'protocolVersion': '2024-11-05'}})
        self.assertEqual(r['id'], 7)
        self.assertIn('tools', r['result']['capabilities'])

    def test_real_upstream_schema_and_result_are_forwarded_with_client_id(self):
        payload = {'tools': [{'name': 'create_vfx'}]}
        with patch.object(self.bridge.pixellab, 'rpc', return_value={'id': 99, 'result': payload}) as rpc:
            r = self.bridge.respond({'id': 3, 'method': 'tools/list', 'params': {}})
            self.assertEqual(r, {'jsonrpc': '2.0', 'id': 3, 'result': payload})
            rpc.assert_called_once_with('tools/list', {})

    def test_errors_are_not_successes(self):
        error = {'code': -1, 'message': 'upstream failed'}
        with patch.object(self.bridge.pixellab, 'rpc', return_value={'error': error}):
            self.assertEqual(self.bridge.respond({'id': 4, 'method': 'tools/call'})['error'], error)
        self.assertEqual(self.bridge.respond({'id': 5, 'method': 'unknown'})['error']['code'], -32601)


if __name__ == '__main__':
    unittest.main()
