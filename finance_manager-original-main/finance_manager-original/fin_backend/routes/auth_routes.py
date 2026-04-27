# fin_backend/routes/auth_routes.py
from flask import Blueprint, request, jsonify
from database import SessionLocal
from routes.auth_utils import create_access_token
from services.auth_service import register_user, authenticate_user
from services.rate_limiter import check_rate_limit

auth_bp = Blueprint("auth", __name__)


def _rate_limit(bucket: str, limit: int, window_seconds: int):
    def decorator(fn):
        def wrapper(*args, **kwargs):
            client_ip = request.headers.get("X-Forwarded-For", request.remote_addr or "unknown")
            allowed, retry_after = check_rate_limit(f"{bucket}:{client_ip}", limit, window_seconds)
            if not allowed:
                return jsonify({
                    "error": "too_many_requests",
                    "message": "Too many attempts. Please try again later.",
                    "retry_after_seconds": retry_after,
                }), 429
            return fn(*args, **kwargs)
        wrapper.__name__ = fn.__name__
        return wrapper
    return decorator

@auth_bp.route("/register", methods=["POST"])
@_rate_limit("auth_register", limit=5, window_seconds=300)
def register():
    data = request.json or {}
    name = data.get("name")
    email = data.get("email")
    password = data.get("password")
    monthly_income = data.get("monthly_income")

    if not name or not email or not password:
        return jsonify({"error": "name, email and password required"}), 400

    db = SessionLocal()
    user, error = register_user(
        db=db,
        name=name,
        email=email,
        password=password,
        monthly_income=monthly_income,
    )
    if error:
        db.close()
        return jsonify({"error": error}), 400

    db.close()
    token = create_access_token(user.id)
    return jsonify({
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "token": token
    }), 201

@auth_bp.route("/login", methods=["POST"])
@_rate_limit("auth_login", limit=10, window_seconds=300)
def login():
    data = request.json or {}
    email = data.get("email")
    password = data.get("password")
    if not email or not password:
        return jsonify({"error": "email and password required"}), 400

    db = SessionLocal()
    user = authenticate_user(db, email, password)
    if not user:
        db.close()
        return jsonify({"error": "invalid credentials"}), 401

    token = create_access_token(user.id)
    db.close()
    return jsonify({"token": token, "user": {"id": user.id, "name": user.name, "email": user.email}})
