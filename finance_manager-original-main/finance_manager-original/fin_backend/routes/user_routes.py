# fin_backend/routes/user_routes.py
from flask import Blueprint, request, jsonify, Response
from database import SessionLocal
from models import User, Transaction, Budget, Subscription, Bill, CreditReportSnapshot, Notification, MerchantCategoryRule
from routes.auth_utils import token_required
from ai.analyzer import CANONICAL_CATEGORIES
from datetime import datetime
import csv
import io
from routes.analytics_routes import invalidate_summary_cache

user_bp = Blueprint("user", __name__)


def _serialize_transaction(txn: Transaction) -> dict:
    return {
        "amount": float(txn.amount),
        "type": txn.type,
        "category": txn.category,
        "merchant": txn.merchant,
        "transaction_date": txn.transaction_date.isoformat() if txn.transaction_date else None,
        "notes": txn.notes,
    }


def _serialize_budget(budget: Budget) -> dict:
    return {
        "category": budget.category,
        "limit_amount": float(budget.limit_amount),
        "month": budget.month,
    }


def _serialize_subscription(sub: Subscription) -> dict:
    return {
        "name": sub.name,
        "merchant": sub.merchant,
        "amount": float(sub.amount),
        "frequency": sub.frequency,
        "next_date": sub.next_date.isoformat() if sub.next_date else None,
    }


def _serialize_bill(bill: Bill) -> dict:
    return {
        "name": bill.name,
        "amount": float(bill.amount),
        "category": bill.category,
        "due_date": bill.due_date.isoformat() if bill.due_date else None,
        "paid": bool(bill.paid),
    }


def _safe_iso_to_dt(value: str | None):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None

@user_bp.route("/profile", methods=["GET"])
@token_required
def get_profile(current_user):
    """Get user profile information"""
    return jsonify({
        "id": current_user.id,
        "name": current_user.name,
        "email": current_user.email,
        "monthly_income": float(current_user.monthly_income) if current_user.monthly_income else None,
        "emergency_fund": float(current_user.emergency_fund) if current_user.emergency_fund else 0,
        "financial_goals": current_user.financial_goals
    })

@user_bp.route("/profile", methods=["PUT"])
@token_required
def update_profile(current_user):
    """Update user profile information"""
    data = request.json or {}

    db = SessionLocal()
    user = db.query(User).filter(User.id == current_user.id).first()

    if not user:
        db.close()
        return jsonify({"error": "User not found"}), 404

    # Update fields if provided
    if "name" in data:
        user.name = data["name"]
    if "monthly_income" in data:
        user.monthly_income = data["monthly_income"]
    if "emergency_fund" in data:
        user.emergency_fund = data["emergency_fund"]
    if "financial_goals" in data:
        user.financial_goals = data["financial_goals"]

    db.commit()
    db.refresh(user)
    invalidate_summary_cache(current_user.id)

    result = {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "monthly_income": float(user.monthly_income) if user.monthly_income else None,
        "emergency_fund": float(user.emergency_fund) if user.emergency_fund else 0,
        "financial_goals": user.financial_goals
    }

    db.close()
    return jsonify(result)

@user_bp.route("/categories", methods=["GET"])
@token_required
def get_categories(current_user):
    """Get all available transaction categories"""
    categories = sorted(list(set(CANONICAL_CATEGORIES)))

    return jsonify({"categories": categories})


@user_bp.route("/backup", methods=["GET"])
@token_required
def export_backup(current_user):
    """Export the user's key financial data as a JSON backup snapshot."""
    db = SessionLocal()
    try:
        transactions = db.query(Transaction).filter(Transaction.user_id == current_user.id).order_by(Transaction.transaction_date.desc()).all()
        budgets = db.query(Budget).filter(Budget.user_id == current_user.id).order_by(Budget.month.desc(), Budget.category.asc()).all()
        subscriptions = db.query(Subscription).filter(Subscription.user_id == current_user.id).order_by(Subscription.id.desc()).all()
        bills = db.query(Bill).filter(Bill.user_id == current_user.id).order_by(Bill.due_date.asc()).all()
        notifications = db.query(Notification).filter(Notification.user_id == current_user.id).order_by(Notification.created_at.desc()).all()
        rules = db.query(MerchantCategoryRule).filter(MerchantCategoryRule.user_id == current_user.id).order_by(MerchantCategoryRule.merchant_key.asc()).all()
        snapshots = db.query(CreditReportSnapshot).filter(CreditReportSnapshot.user_id == current_user.id).order_by(CreditReportSnapshot.report_date.desc()).all()

        return jsonify({
            "version": 1,
            "exported_at": datetime.utcnow().isoformat() + "Z",
            "profile": {
                "name": current_user.name,
                "email": current_user.email,
                "monthly_income": float(current_user.monthly_income) if current_user.monthly_income else None,
                "emergency_fund": float(current_user.emergency_fund) if current_user.emergency_fund else 0,
                "financial_goals": current_user.financial_goals,
            },
            "transactions": [_serialize_transaction(txn) for txn in transactions],
            "budgets": [_serialize_budget(budget) for budget in budgets],
            "subscriptions": [_serialize_subscription(sub) for sub in subscriptions],
            "bills": [_serialize_bill(bill) for bill in bills],
            "notifications": [
                {
                    "type": n.type,
                    "message": n.message,
                    "is_read": bool(n.is_read),
                    "created_at": n.created_at.isoformat() if n.created_at else None,
                }
                for n in notifications
            ],
            "merchant_category_rules": [
                {
                    "merchant_key": rule.merchant_key,
                    "category": rule.category,
                }
                for rule in rules
            ],
            "credit_report_snapshots": [
                {
                    "bureau_name": snap.bureau_name,
                    "credit_score": snap.credit_score,
                    "report_date": snap.report_date.isoformat() if snap.report_date else None,
                    "raw_data": snap.raw_data,
                }
                for snap in snapshots
            ],
        })
    finally:
        db.close()


@user_bp.route("/backup", methods=["POST"])
@token_required
def import_backup(current_user):
    """Restore user data from a backup snapshot without deleting existing records."""
    data = request.json or {}
    db = SessionLocal()
    try:
        profile = data.get("profile") or {}
        if "name" in profile:
            current_user.name = profile.get("name")
        if "monthly_income" in profile:
            current_user.monthly_income = profile.get("monthly_income")
        if "emergency_fund" in profile:
            current_user.emergency_fund = profile.get("emergency_fund")
        if "financial_goals" in profile:
            current_user.financial_goals = profile.get("financial_goals")

        for item in data.get("transactions", []):
            db.add(Transaction(
                user_id=current_user.id,
                amount=float(item.get("amount") or 0),
                type=item.get("type") or "expense",
                category=item.get("category"),
                merchant=item.get("merchant"),
                transaction_date=_safe_iso_to_dt(item.get("transaction_date")),
                notes=item.get("notes"),
            ))

        for item in data.get("budgets", []):
            db.add(Budget(
                user_id=current_user.id,
                category=item.get("category"),
                limit_amount=float(item.get("limit_amount") or 0),
                month=item.get("month"),
            ))

        for item in data.get("subscriptions", []):
            db.add(Subscription(
                user_id=current_user.id,
                name=item.get("name") or "Subscription",
                merchant=item.get("merchant"),
                amount=float(item.get("amount") or 0),
                frequency=item.get("frequency") or "monthly",
                next_date=_safe_iso_to_dt(item.get("next_date")),
            ))

        for item in data.get("bills", []):
            due_date = _safe_iso_to_dt(item.get("due_date"))
            if due_date is None:
                continue
            db.add(Bill(
                user_id=current_user.id,
                name=item.get("name") or "Bill",
                amount=float(item.get("amount") or 0),
                category=item.get("category"),
                due_date=due_date,
                paid=bool(item.get("paid", False)),
            ))

        for item in data.get("merchant_category_rules", []):
            merchant_key = (item.get("merchant_key") or "").strip().lower()
            category = item.get("category")
            if not merchant_key or not category:
                continue
            existing = db.query(MerchantCategoryRule).filter(
                MerchantCategoryRule.user_id == current_user.id,
                MerchantCategoryRule.merchant_key == merchant_key,
            ).first()
            if existing:
                existing.category = category
            else:
                db.add(MerchantCategoryRule(
                    user_id=current_user.id,
                    merchant_key=merchant_key,
                    category=category,
                ))

        db.commit()
        invalidate_summary_cache(current_user.id)
        return jsonify({"message": "Backup restored successfully"}), 200
    finally:
        db.close()


@user_bp.route("/notifications", methods=["GET"])
@token_required
def list_notifications(current_user):
    db = SessionLocal()
    try:
        notifications = db.query(Notification).filter(
            Notification.user_id == current_user.id
        ).order_by(Notification.is_read.asc(), Notification.created_at.desc()).all()

        return jsonify({
            "notifications": [
                {
                    "id": n.id,
                    "type": n.type,
                    "message": n.message,
                    "is_read": bool(n.is_read),
                    "created_at": n.created_at.isoformat() if n.created_at else None,
                }
                for n in notifications
            ],
            "count": len(notifications),
        })
    finally:
        db.close()


@user_bp.route("/notifications/mark-read", methods=["POST"])
@token_required
def mark_notifications_read(current_user):
    data = request.json or {}
    notification_id = data.get("notification_id")

    db = SessionLocal()
    try:
        query = db.query(Notification).filter(Notification.user_id == current_user.id)
        if notification_id is not None:
            query = query.filter(Notification.id == int(notification_id))

        updated = query.all()
        for notification in updated:
            notification.is_read = 1

        db.commit()
        invalidate_summary_cache(current_user.id)
        return jsonify({"message": "Notifications marked as read", "updated": len(updated)}), 200
    except (TypeError, ValueError):
        return jsonify({"error": "notification_id must be numeric"}), 400
    finally:
        db.close()


@user_bp.route("/report.csv", methods=["GET"])
@token_required
def export_user_report_csv(current_user):
    db = SessionLocal()
    try:
        transactions = db.query(Transaction).filter(Transaction.user_id == current_user.id).order_by(Transaction.transaction_date.desc()).all()

        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(["type", "id", "amount", "category", "merchant", "date", "notes"])

        for txn in transactions:
            writer.writerow([
                "transaction",
                txn.id,
                float(txn.amount),
                txn.category or "",
                txn.merchant or "",
                txn.transaction_date.isoformat() if txn.transaction_date else "",
                txn.notes or "",
            ])

        response = Response(buffer.getvalue(), mimetype="text/csv")
        response.headers["Content-Disposition"] = "attachment; filename=user-report.csv"
        return response
    finally:
        db.close()
