"""Exercise the complete bootstrap script against a local Open WebUI API stub."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import unittest

ROOT = Path(__file__).resolve().parents[1]
PUBLIC_READ = {'principal_type': 'user', 'principal_id': '*', 'permission': 'read'}


class BootstrapAccessTests(unittest.TestCase):
    def run_bootstrap(self, existing, fail_access=False):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            source = (ROOT / 'sendemail_tool_env.py').read_text()
            state = {'tool': existing, 'updates': []}
            done = directory / 'done'

            class Handler(BaseHTTPRequestHandler):
                def log_message(self, *args):
                    pass

                def reply(self, value, status=200):
                    self.send_response(status)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps(value).encode())

                def do_GET(self):
                    if self.path == '/health':
                        return self.reply({'status': True})
                    if self.path == '/api/v1/users/default/permissions':
                        return self.reply({'features': {'automations': True}})
                    if self.path == '/api/v1/tools/id/sendemail_tool_env':
                        return self.reply(state['tool'] or {}, 200 if state['tool'] else 404)
                    return self.reply({}, 404)

                def do_POST(self):
                    payload = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                    if self.path == '/api/v1/auths/signin':
                        return self.reply({'token': 'test-only-token'})
                    if self.path == '/api/v1/tools/create':
                        state['tool'] = payload
                        return self.reply(payload)
                    if self.path.endswith('/access/update'):
                        if fail_access:
                            return self.reply({'detail': 'Access update failed'}, 500)
                        state['updates'].append(payload)
                        state['tool']['access_grants'] = payload['access_grants']
                        return self.reply(state['tool'])
                    if self.path == '/api/v1/models/import':
                        self.reply(True)
                        done.touch()
                        return
                    return self.reply({}, 404)

            server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            start = directory / 'start.sh'
            start.write_text('#!/bin/sh\nwhile [ ! -f "'+str(done)+'" ]; do sleep 0.05; done\n')
            start.chmod(0o700)
            environment = dict(os.environ, WEBUI_ADMIN_EMAIL='admin@example.com', WEBUI_ADMIN_PASSWORD='test-only', BOOTSTRAP_DIR=str(ROOT), OPENWEBUI_START_SCRIPT=str(start), OPENWEBUI_BASE_URL=f'http://127.0.0.1:{server.server_port}', MAX_WAIT_SECONDS='5')
            try:
                result = subprocess.run(['bash', str(ROOT / 'bootstrap.sh')], env=environment, capture_output=True, text=True, timeout=20)
            finally:
                done.touch()
                server.shutdown()
                server.server_close()
                thread.join()
            return result, state, source

    def test_fresh_tool_becomes_readable(self):
        result, state, _ = self.run_bootstrap(None)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(state['tool']['access_grants'], [PUBLIC_READ])

    def test_private_existing_tool_preserves_other_grants(self):
        grant = {'principal_type': 'group', 'principal_id': 'editors', 'permission': 'write'}
        tool = {'id': 'sendemail_tool_env', 'content': (ROOT / 'sendemail_tool_env.py').read_text(), 'access_grants': [grant]}
        result, state, _ = self.run_bootstrap(tool)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(state['tool']['access_grants'], [grant, PUBLIC_READ])

    def test_public_tool_needs_no_access_update(self):
        tool = {'id': 'sendemail_tool_env', 'content': (ROOT / 'sendemail_tool_env.py').read_text(), 'access_grants': [PUBLIC_READ]}
        result, state, _ = self.run_bootstrap(tool)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(state['updates'], [])

    def test_failed_access_update_fails_bootstrap(self):
        result, _, _ = self.run_bootstrap(None, fail_access=True)
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
