# fin_backend/database.py
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker, declarative_base, scoped_session
from config import Config

engine = create_engine(Config.DATABASE_URL, echo=False, future=True)
SessionLocal = scoped_session(sessionmaker(autocommit=False, autoflush=False, bind=engine))
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def apply_schema_patches():
    """
    Apply lightweight backward-compatible schema patches for SQLite.
    """
    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return

    user_columns = {col["name"] for col in inspector.get_columns("users")}
    if "name" not in user_columns:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE users ADD COLUMN name VARCHAR(255)"))

    if "transactions" not in inspector.get_table_names():
        return

    transaction_columns = {col["name"] for col in inspector.get_columns("transactions")}
    if "type" not in transaction_columns:
        # Keep existing data usable by backfilling a safe default.
        with engine.begin() as conn:
            conn.execute(
                text("ALTER TABLE transactions ADD COLUMN type VARCHAR(20) NOT NULL DEFAULT 'expense'")
            )


def apply_performance_patches():
    """Create helpful indexes for frequent queries if they do not already exist."""
    if engine.dialect.name != "sqlite":
        return

    index_statements = [
        "CREATE INDEX IF NOT EXISTS ix_transactions_user_date ON transactions (user_id, transaction_date)",
        "CREATE INDEX IF NOT EXISTS ix_transactions_user_type ON transactions (user_id, type)",
        "CREATE INDEX IF NOT EXISTS ix_transactions_user_category ON transactions (user_id, category)",
        "CREATE INDEX IF NOT EXISTS ix_budgets_user_month ON budgets (user_id, month)",
        "CREATE INDEX IF NOT EXISTS ix_budgets_user_category ON budgets (user_id, category)",
        "CREATE INDEX IF NOT EXISTS ix_subscriptions_user_next_date ON subscriptions (user_id, next_date)",
        "CREATE INDEX IF NOT EXISTS ix_bills_user_due_date ON bills (user_id, due_date)",
        "CREATE INDEX IF NOT EXISTS ix_notifications_user_read ON notifications (user_id, is_read)",
        "CREATE INDEX IF NOT EXISTS ix_merchant_rules_user_key ON merchant_category_rules (user_id, merchant_key)",
    ]

    with engine.begin() as conn:
        for statement in index_statements:
            conn.execute(text(statement))
