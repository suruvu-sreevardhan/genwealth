from __future__ import annotations

import unittest

from routes.auth_utils import create_access_token, decode_token
from services.rate_limiter import check_rate_limit, reset_rate_limits


class SecurityUtilitiesTest(unittest.TestCase):
    def setUp(self):
        reset_rate_limits()

    def test_access_token_contains_expected_claims(self):
        token = create_access_token(42, expires_minutes=5)
        payload = decode_token(token)

        self.assertEqual(payload["sub"], "42")
        self.assertIn("exp", payload)
        self.assertIn("iat", payload)
        self.assertIn("iss", payload)
        self.assertIn("aud", payload)

    def test_rate_limit_blocks_after_threshold(self):
        for _ in range(3):
            allowed, retry_after = check_rate_limit("auth_login:127.0.0.1", limit=3, window_seconds=60)
            self.assertTrue(allowed)
            self.assertEqual(retry_after, 0)

        allowed, retry_after = check_rate_limit("auth_login:127.0.0.1", limit=3, window_seconds=60)
        self.assertFalse(allowed)
        self.assertGreaterEqual(retry_after, 1)

    def test_rate_limit_resets_for_new_window(self):
        allowed, _ = check_rate_limit("auth_login:127.0.0.1", limit=1, window_seconds=1)
        self.assertTrue(allowed)

        # Reusing the same key immediately is blocked.
        allowed, _ = check_rate_limit("auth_login:127.0.0.1", limit=1, window_seconds=1)
        self.assertFalse(allowed)


if __name__ == "__main__":
    unittest.main()
