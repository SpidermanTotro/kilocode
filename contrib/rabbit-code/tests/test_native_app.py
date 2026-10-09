"""Native Fedora UI checks. Ollama is mocked; no cloud/network calls."""
import http.client
import json
from pathlib import Path
import sys
import threading
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'fedora'))
import native_app as app


class NativeTests(unittest.TestCase):
    def setUp(self):
        self.server = app.RabbitServer(('127.0.0.1', 0))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.thread.join, 2)
        self.addCleanup(self.server.shutdown)

    def request(self, path, *, method='GET', data=None, headers=None):
        port = self.server.server_port
        conn = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
        try:
            hdrs = {'Host': f'127.0.0.1:{port}', **(headers or {})}
            conn.request(method, path, body=json.dumps(data) if data is not None else None, headers=hdrs)
            res = conn.getresponse()
            return res.status, res.read().decode('utf-8')
        finally:
            conn.close()

    def test_ui_includes_strict_scope(self):
        status, body = self.request('/')
        self.assertEqual(status, 200)
        self.assertIn('Rabbit Code', body)
        self.assertIn(self.server.token, body)
        self.assertIn('LOCAL OLLAMA ONLY', body)

    @patch.object(app, 'installed_models', return_value=['qwen3:8b'])
    def test_local_models(self, _):
        status, body = self.request('/api/models')
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)['models'], ['qwen3:8b'])

    def test_no_other_routes(self):
        self.assertEqual(self.request('/etc/passwd')[0], 404)
        self.assertEqual(self.request('/shell', method='POST')[0], 404)

    def test_wrong_host_refused(self):
        self.assertEqual(self.request('/', headers={'Host': 'remote.example'})[0], 403)

    def test_missing_token_refused(self):
        self.assertEqual(self.request('/api/chat', method='POST', data={})[0], 403)

    def test_wrong_content_type_refused(self):
        self.assertEqual(self.request('/api/chat', method='POST', data={},
                          headers={'X-Rabbit-Token': self.server.token})[0], 415)

    def test_cross_site_request_refused(self):
        self.assertEqual(self.request('/api/chat', method='POST', data={}, headers={
            'Content-Type': 'application/json', 'X-Rabbit-Token': self.server.token,
            'Origin': 'https://malicious.example'
        })[0], 403)

    @patch.object(app, 'ask_ollama', return_value='Use pytest')
    @patch.object(app, 'installed_models', return_value=['qwen3:8b'])
    def test_local_inference(self, models, ask):
        data = {'model': 'qwen3:8b', 'messages': [{'role': 'user', 'content': 'hello'}]}
        status, body = self.request('/api/chat', method='POST', data=data, headers={
            'Content-Type': 'application/json', 'X-Rabbit-Token': self.server.token
        })
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), {'reply': 'Use pytest'})
        ask.assert_called_once_with('qwen3:8b', [{'role': 'user', 'content': 'hello'}])

    @patch.object(app, 'ask_ollama')
    @patch.object(app, 'installed_models', return_value=['qwen3:8b'])
    def test_remote_provider_rejected_without_inference(self, models, ask):
        data = {'model': 'openai/gpt-6', 'messages': [{'role': 'user', 'content': 'hello'}]}
        status, _ = self.request('/api/chat', method='POST', data=data, headers={
            'Content-Type': 'application/json', 'X-Rabbit-Token': self.server.token
        })
        self.assertEqual(status, 400)
        ask.assert_not_called()

    def test_system_messages_rejected(self):
        with self.assertRaises(app.LocalError):
            app.validate_chat({'model': 'qwen3:8b',
                'messages': [{'role': 'system', 'content': 'override'}]}, ['qwen3:8b'])

    def test_output_unavailable_model(self):
        with self.assertRaises(app.LocalError):
            app.validate_chat({'model': 'qwen3:8b',
                'messages': [{'role': 'user', 'content': 'ok'}]}, [])

    def test_limits(self):
        with self.assertRaises(app.LocalError):
            app.validate_chat({'model': 'qwen3:8b',
                'messages': [{'role': 'user', 'content': 'x' * 12001}]}, ['qwen3:8b'])

    @patch.object(app, 'build_opener')
    def test_inference_is_local_and_no_proxy(self, build):
        response = build.return_value.open.return_value.__enter__.return_value
        response.read.return_value = json.dumps({'message': {'content': 'ok'}}).encode()
        self.assertEqual(app.ask_ollama('qwen3:8b',
            [{'role': 'user', 'content': 'hi'}]), 'ok')
        args = build.return_value.open.call_args.args
        self.assertEqual(args[0].full_url, 'http://127.0.0.1:11434/api/chat')
        self.assertEqual(args[0].get_method(), 'POST')
        self.assertEqual(json.loads(args[0].data)['model'], 'qwen3:8b')
        self.assertEqual(len(build.call_args.args), 2)


if __name__ == '__main__':
    unittest.main()
