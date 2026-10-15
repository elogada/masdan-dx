import importlib.util
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('email_tool', Path(__file__).resolve().parents[1] / 'sendemail_tool_env.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class EmailRecipientTests(unittest.TestCase):
    def test_authenticated_demo_email_overrides_model_recipient(self):
        with patch.dict(os.environ, {'SMTP_EMAIL': 'relay@example.com', 'SMTP_PASSWORD': 'test-only'}), patch.object(module.smtplib, 'SMTP_SSL') as smtp:
            result = json.loads(module.Tools().send_email('Report', '**Hello**', ['admin@example.com'], __user__={'email': 'demo@example.com'}))
            self.assertEqual(result['to'], ['demo@example.com'])
            call = smtp.return_value.__enter__.return_value.sendmail.call_args
            self.assertEqual(call.args[1], ['demo@example.com'])
            self.assertIn('To: demo@example.com', call.args[2])
            self.assertNotIn('admin@example.com', call.args[2])

    def test_missing_identity_fails_without_sending(self):
        with patch.object(module.smtplib, 'SMTP_SSL') as smtp:
            result = json.loads(module.Tools().send_email('Report', 'Hello', ['admin@example.com']))
            self.assertEqual(result['status'], 'error')
            smtp.assert_not_called()

    def test_injected_headers_fail_without_sending(self):
        with patch.object(module.smtplib, 'SMTP_SSL') as smtp:
            result = json.loads(module.Tools().send_email('Report', 'Hello', [], __user__={'email': 'demo@example.com\r\nBcc: other@example.com'}))
            self.assertEqual(result['status'], 'error')
            smtp.assert_not_called()


if __name__ == '__main__':
    unittest.main()
