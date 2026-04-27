# fin_backend/config.py
import os
from dotenv import load_dotenv

load_dotenv()


def _as_bool(value: str | None, default: bool) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _split_csv(value: str | None, default: list[str]) -> list[str]:
    if not value:
        return default
    return [item.strip() for item in value.split(",") if item.strip()]

class Config:
    ENV = os.getenv("FLASK_ENV", "development").strip().lower()
    DEBUG = _as_bool(os.getenv("DEBUG"), ENV == "development")
    SECRET_KEY = os.getenv("SECRET_KEY", "super-secret-change-me")
    JWT_SECRET = os.getenv("JWT_SECRET", "jwt-secret-change-me")
    JWT_ISSUER = os.getenv("JWT_ISSUER", "finlit-api")
    JWT_AUDIENCE = os.getenv("JWT_AUDIENCE", "finlit-mobile")
    ACCESS_TOKEN_EXPIRES_MIN = int(os.getenv("ACCESS_TOKEN_EXPIRES_MIN", "1440"))
    CORS_ORIGINS = _split_csv(os.getenv("CORS_ORIGINS"), ["http://localhost:3000", "http://127.0.0.1:3000"]) 
    DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///finlit_dev.db")

    if ENV == "production":
        if SECRET_KEY == "super-secret-change-me":
            raise ValueError("SECRET_KEY must be set in production")
        if JWT_SECRET == "jwt-secret-change-me":
            raise ValueError("JWT_SECRET must be set in production")
        if "*" in CORS_ORIGINS:
            raise ValueError("CORS_ORIGINS cannot include '*' in production")
