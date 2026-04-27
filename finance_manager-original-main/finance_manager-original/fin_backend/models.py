# fin_backend/models.py
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Numeric, JSON, ForeignKey, Text, UniqueConstraint, Boolean, Index
from sqlalchemy.orm import relationship
from database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    monthly_income = Column(Numeric(10,2), nullable=True)
    emergency_fund = Column(Numeric(12,2), nullable=True, default=0)
    financial_goals = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    transactions = relationship("Transaction", back_populates="user", cascade="all, delete-orphan")
    budgets = relationship("Budget", back_populates="user", cascade="all, delete-orphan")
    subscriptions = relationship("Subscription", back_populates="user", cascade="all, delete-orphan")
    bills = relationship("Bill", back_populates="user", cascade="all, delete-orphan")
    loans = relationship("Loan", back_populates="user", cascade="all, delete-orphan")
    credit_snapshots = relationship("CreditReportSnapshot", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    merchant_category_rules = relationship("MerchantCategoryRule", back_populates="user", cascade="all, delete-orphan")

class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (
        Index("ix_transactions_user_date", "user_id", "transaction_date"),
        Index("ix_transactions_user_type", "user_id", "type"),
        Index("ix_transactions_user_category", "user_id", "category"),
    )
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    amount = Column(Numeric(12,2), nullable=False)
    type = Column(String(20), nullable=False, default="expense")
    category = Column(String(100), nullable=True)
    merchant = Column(String(255), nullable=True)
    transaction_date = Column(DateTime, default=datetime.utcnow)
    notes = Column(Text, nullable=True)

    user = relationship("User", back_populates="transactions")

class Budget(Base):
    __tablename__ = "budgets"
    __table_args__ = (
        Index("ix_budgets_user_month", "user_id", "month"),
        Index("ix_budgets_user_category", "user_id", "category"),
    )
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    category = Column(String(100))
    limit_amount = Column(Numeric(12,2))
    month = Column(String(7))  # YYYY-MM format

    user = relationship("User", back_populates="budgets")

class Subscription(Base):
    __tablename__ = "subscriptions"
    __table_args__ = (
        Index("ix_subscriptions_user_next_date", "user_id", "next_date"),
    )
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String(255), nullable=False)
    merchant = Column(String(255), nullable=True)
    amount = Column(Numeric(12,2), nullable=False)
    frequency = Column(String(50), nullable=False)
    next_date = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="subscriptions")

class Bill(Base):
    __tablename__ = "bills"
    __table_args__ = (
        Index("ix_bills_user_due_date", "user_id", "due_date"),
    )
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String(255), nullable=False)
    amount = Column(Numeric(12,2), nullable=False)
    category = Column(String(100), nullable=True)
    due_date = Column(DateTime, nullable=False)
    paid = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="bills")

class Loan(Base):
    __tablename__ = "loans"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    account_type = Column(String(50))
    lender = Column(String(255))
    current_balance = Column(Numeric(12,2))
    emi_amount = Column(Numeric(12,2))
    interest_rate = Column(Numeric(5,2))
    status = Column(String(20))
    days_past_due = Column(Integer, nullable=True, default=0)
    opened_date = Column(DateTime, nullable=True)

    user = relationship("User", back_populates="loans")

class CreditReportSnapshot(Base):
    __tablename__ = "credit_report_snapshots"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    bureau_name = Column(String(50))
    credit_score = Column(Integer)
    report_date = Column(DateTime, default=datetime.utcnow)
    raw_data = Column(JSON)

    user = relationship("User", back_populates="credit_snapshots")

class Notification(Base):
    __tablename__ = "notifications"
    __table_args__ = (
        Index("ix_notifications_user_read", "user_id", "is_read"),
    )
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    type = Column(String(20))  # 'info', 'warning', 'alert'
    message = Column(Text)
    is_read = Column(Integer, default=0)  # 0=unread, 1=read
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="notifications")


class MerchantCategoryRule(Base):
    __tablename__ = "merchant_category_rules"
    __table_args__ = (UniqueConstraint("user_id", "merchant_key", name="uq_user_merchant_rule"),)

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    merchant_key = Column(String(255), nullable=False, index=True)
    category = Column(String(100), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="merchant_category_rules")
