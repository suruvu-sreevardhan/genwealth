from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from uuid import uuid4


_db_fd, _db_path = tempfile.mkstemp(prefix="finlit_smoke_", suffix=".db")
os.close(_db_fd)
os.environ.setdefault("FLASK_ENV", "testing")
os.environ.setdefault("DEBUG", "False")
os.environ.setdefault("SECRET_KEY", "test-secret-key")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret")
os.environ.setdefault("JWT_ISSUER", "finlit-api")
os.environ.setdefault("JWT_AUDIENCE", "finlit-mobile")
os.environ["DATABASE_URL"] = f"sqlite:///{_db_path}"

from app import create_app  # noqa: E402
from database import Base, SessionLocal, engine  # noqa: E402
from models import User  # noqa: E402
from services.auth_service import register_user  # noqa: E402
from services.rate_limiter import reset_rate_limits  # noqa: E402


class ApiSmokeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Base.metadata.create_all(bind=engine)
        cls.app = create_app()
        cls.client = cls.app.test_client()

    @classmethod
    def tearDownClass(cls):
        engine.dispose()
        try:
            Path(_db_path).unlink(missing_ok=True)
        except Exception:
            pass

    def setUp(self):
        reset_rate_limits()
        self.db = SessionLocal()
        self._clear_tables()

    def tearDown(self):
        self.db.close()

    def _clear_tables(self):
        self.db.query(User).delete()
        self.db.commit()

    def _register_user(self):
        email = f"user-{uuid4().hex[:8]}@example.com"
        password = "Password123!"
        user, error = register_user(self.db, email=email, password=password, name="Smoke Test", monthly_income=75000)
        self.assertIsNone(error)
        return email, password, user

    def _auth_headers(self, token: str):
        return {"Authorization": f"Bearer {token}"}

    def test_register_login_and_transaction_flow(self):
        email, password, _ = self._register_user()

        login_response = self.client.post("/api/auth/login", json={"email": email, "password": password})
        self.assertEqual(login_response.status_code, 200)
        token = login_response.get_json()["token"]

        txn_response = self.client.post(
            "/api/transactions/",
            json={
                "amount": 199.0,
                "merchant": "Swiggy",
                "notes": "Lunch",
                "type": "expense",
                "category": "food",
            },
            headers=self._auth_headers(token),
        )
        self.assertEqual(txn_response.status_code, 201)
        txn = txn_response.get_json()
        self.assertEqual(txn["type"], "expense")
        self.assertEqual(txn["merchant"], "Swiggy")

        list_response = self.client.get("/api/transactions/", headers=self._auth_headers(token))
        self.assertEqual(list_response.status_code, 200)
        self.assertGreaterEqual(len(list_response.get_json()), 1)

    def test_kyc_initiation_does_not_expose_mock_otp(self):
        email, password, _ = self._register_user()
        login_response = self.client.post("/api/auth/login", json={"email": email, "password": password})
        token = login_response.get_json()["token"]

        resp = self.client.post(
            "/api/credit/kyc/initiate-pan-consent",
            json={
                "pan": "ABCDE1234F",
                "name": "Smoke Test",
                "dob": "1990-01-15",
                "mobile": "9876543210",
            },
            headers=self._auth_headers(token),
        )
        self.assertEqual(resp.status_code, 200)
        payload = resp.get_json()
        self.assertIn("consent_request_id", payload)
        self.assertNotIn("mock_otp", payload)


if __name__ == "__main__":
    unittest.main()
