from __future__ import annotations

from passlib.hash import bcrypt
from sqlalchemy.orm import Session

from models import User


def register_user(
    db: Session,
    email: str,
    password: str,
    name: str | None = None,
    monthly_income: float | None = None,
):
    existing = db.query(User).filter(User.email == email).first()
    if existing:
        return None, "user exists"

    user = User(
        name=(name or "").strip() or None,
        email=email,
        password_hash=bcrypt.hash(password),
        monthly_income=monthly_income,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user, None


def authenticate_user(db: Session, email: str, password: str):
    user = db.query(User).filter(User.email == email).first()
    if not user or not bcrypt.verify(password, user.password_hash):
        return None
    return user
