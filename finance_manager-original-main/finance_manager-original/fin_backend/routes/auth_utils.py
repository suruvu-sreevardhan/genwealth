# fin_backend/routes/auth_utils.py
import jwt
from datetime import datetime, timedelta, timezone
from flask import request, jsonify
from functools import wraps
from config import Config
from database import SessionLocal
from models import User

JWT_SECRET = Config.JWT_SECRET
JWT_ALGO = "HS256"
JWT_ISSUER = Config.JWT_ISSUER
JWT_AUDIENCE = Config.JWT_AUDIENCE
ACCESS_TOKEN_EXPIRES_MIN = Config.ACCESS_TOKEN_EXPIRES_MIN

def create_access_token(user_id: int, expires_minutes: int = ACCESS_TOKEN_EXPIRES_MIN):
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "iat": now,
        "exp": now + timedelta(minutes=expires_minutes),
        "iss": JWT_ISSUER,
        "aud": JWT_AUDIENCE,
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGO)
    # PyJWT returns str in v2+, keep it consistent
    if isinstance(token, bytes):
        token = token.decode("utf-8")
    return token

def decode_token(token: str):
    try:
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[JWT_ALGO],
            audience=JWT_AUDIENCE,
            issuer=JWT_ISSUER,
            options={"require": ["exp", "iat", "sub", "iss", "aud"]},
        )
        return payload
    except jwt.ExpiredSignatureError:
        return {"error": "token_expired"}
    except jwt.InvalidTokenError:
        return {"error": "invalid_token"}

def token_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", None)
        if not auth:
            return jsonify({"error": "authorization header required"}), 401
        parts = auth.split()
        if len(parts) != 2 or parts[0].lower() != "bearer":
            return jsonify({"error": "invalid authorization header format"}), 401
        token = parts[1]
        decoded = decode_token(token)
        if isinstance(decoded, dict) and decoded.get("error"):
            return jsonify({"error": decoded["error"]}), 401

        # Attach user to request context via kwargs
        user_id = decoded.get("sub")
        try:
            user_id = int(user_id)
        except (TypeError, ValueError):
            return jsonify({"error": "invalid_token_subject"}), 401

        db = SessionLocal()
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if not user:
                return jsonify({"error": "user not found"}), 401

            kwargs["current_user"] = user
            return fn(*args, **kwargs)
        finally:
            db.close()
    return wrapper
