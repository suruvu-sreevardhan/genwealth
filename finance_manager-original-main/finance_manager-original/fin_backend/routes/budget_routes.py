# fin_backend/routes/budget_routes.py
from datetime import datetime, timezone

from flask import Blueprint, request, jsonify
from sqlalchemy import func

from ai.analyzer import get_category_aliases, normalize_category
from database import SessionLocal
from models import Budget, Transaction
from routes.auth_utils import token_required
from routes.analytics_routes import invalidate_summary_cache

budget_bp = Blueprint("budget", __name__)


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _month_bounds(month: str):
    parts = (month or "").split("-")
    if len(parts) != 2:
        raise ValueError("month must be in YYYY-MM format")

    year = int(parts[0])
    mon = int(parts[1])
    if mon < 1 or mon > 12:
        raise ValueError("month must be in YYYY-MM format")

    start = datetime(year, mon, 1)
    end = datetime(year + 1, 1, 1) if mon == 12 else datetime(year, mon + 1, 1)
    return start, end


def _serialize_budget(db, current_user_id: int, budget: Budget):
    try:
        start, end = _month_bounds(budget.month)
    except Exception:
        start, end = _month_bounds(_utcnow().strftime("%Y-%m"))

    aliases = [alias.lower() for alias in get_category_aliases(budget.category)]

    txns = db.query(Transaction).filter(
        Transaction.user_id == current_user_id,
        Transaction.type == "expense",
        func.lower(func.coalesce(Transaction.category, "")).in_(aliases),
        Transaction.amount > 0,
        Transaction.transaction_date >= start,
        Transaction.transaction_date < end,
    ).all()

    total_spent = sum(float(t.amount) for t in txns)
    limit = float(budget.limit_amount or 0)
    percentage_used = (total_spent / limit * 100) if limit > 0 else 0

    return {
        "id": budget.id,
        "category": budget.category,
        "limit_amount": limit,
        "spent": total_spent,
        "remaining": max(0, limit - total_spent),
        "percentage_used": percentage_used,
        "month": budget.month,
        "status": "exceeded" if total_spent > limit else "warning" if total_spent > limit * 0.8 else "on_track",
    }

@budget_bp.route("/", methods=["POST"])
@token_required
def create_budget(current_user):
    """
    POST /api/budgets
    body: { "category": "grocery", "limit_amount": 5000, "month": "2025-01" }
    """
    data = request.get_json() or {}
    category = normalize_category(data.get("category"))
    month = data.get("month") or _utcnow().strftime("%Y-%m")
    limit_amount = data.get("limit_amount")

    if not category or category == "uncategorized":
        return jsonify({"error": "category is required"}), 400
    if limit_amount is None:
        return jsonify({"error": "limit_amount is required"}), 400

    try:
        limit_amount = float(limit_amount)
        if limit_amount <= 0:
            return jsonify({"error": "limit_amount must be greater than 0"}), 400
        _month_bounds(month)
    except (TypeError, ValueError):
        return jsonify({"error": "month must be in YYYY-MM format and limit_amount must be numeric"}), 400

    db = SessionLocal()
    try:
        existing = db.query(Budget).filter(
            Budget.user_id == current_user.id,
            Budget.category == category,
            Budget.month == month,
        ).first()

        if existing:
            return jsonify({"error": "Budget already exists for this category and month"}), 400

        new_budget = Budget(
            user_id=current_user.id,
            category=category,
            limit_amount=limit_amount,
            month=month,
        )

        db.add(new_budget)
        db.commit()
        db.refresh(new_budget)
        invalidate_summary_cache(current_user.id)

        return jsonify(_serialize_budget(db, current_user.id, new_budget)), 201
    finally:
        db.close()

@budget_bp.route("/", methods=["GET"])
@token_required
def get_budgets(current_user):
    """
    GET /api/budgets?month=YYYY-MM
    Returns all budgets for the user, optionally filtered by month
    """
    month = request.args.get("month")

    db = SessionLocal()
    try:
        query = db.query(Budget).filter(Budget.user_id == current_user.id)

        if month:
            _month_bounds(month)
            query = query.filter(Budget.month == month)

        budgets = query.order_by(Budget.month.desc(), Budget.category.asc()).all()
        result = [_serialize_budget(db, current_user.id, budget) for budget in budgets]
        return jsonify({"budgets": result, "count": len(result)})
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400
    finally:
        db.close()


@budget_bp.route("/summary", methods=["GET"])
@token_required
def budget_summary(current_user):
    month = request.args.get("month") or _utcnow().strftime("%Y-%m")
    try:
        start, end = _month_bounds(month)
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400

    db = SessionLocal()
    try:
        budgets = db.query(Budget).filter(
            Budget.user_id == current_user.id,
            Budget.month == month,
        ).all()

        budget_items = [_serialize_budget(db, current_user.id, budget) for budget in budgets]
        total_limit = sum(item["limit_amount"] for item in budget_items)
        total_spent = sum(item["spent"] for item in budget_items)

        txns = db.query(Transaction).filter(
            Transaction.user_id == current_user.id,
            Transaction.type == "expense",
            Transaction.amount > 0,
            Transaction.transaction_date >= start,
            Transaction.transaction_date < end,
        ).all()

        uncategorized_spent = sum(
            float(t.amount)
            for t in txns
            if normalize_category(getattr(t, "category", None)) == "uncategorized"
        )

        return jsonify({
            "month": month,
            "budget_count": len(budget_items),
            "total_limit": total_limit,
            "total_spent": total_spent,
            "remaining": max(0, total_limit - total_spent),
            "percentage_used": (total_spent / total_limit * 100) if total_limit > 0 else 0,
            "uncategorized_spent": uncategorized_spent,
            "budgets": budget_items,
        })
    finally:
        db.close()

@budget_bp.route("/<int:budget_id>", methods=["PUT"])
@budget_bp.route("/<int:budget_id>", methods=["PATCH"])
@token_required
def update_budget(current_user, budget_id):
    """
    PUT /api/budgets/<id>
    body: { "limit_amount": 6000 }
    """
    data = request.get_json() or {}

    db = SessionLocal()
    try:
        budget = db.query(Budget).filter(
            Budget.id == budget_id,
            Budget.user_id == current_user.id,
        ).first()

        if not budget:
            return jsonify({"error": "Budget not found"}), 404

        if "category" in data:
            category = normalize_category(data.get("category"))
            if not category or category == "uncategorized":
                return jsonify({"error": "category is required"}), 400
            budget.category = category

        if "limit_amount" in data:
            try:
                new_limit = float(data.get("limit_amount"))
                if new_limit <= 0:
                    return jsonify({"error": "limit_amount must be greater than 0"}), 400
                budget.limit_amount = new_limit
            except (TypeError, ValueError):
                return jsonify({"error": "limit_amount must be numeric"}), 400

        if "month" in data:
            month = data.get("month")
            _month_bounds(month)
            budget.month = month

        db.commit()
        db.refresh(budget)
        invalidate_summary_cache(current_user.id)
        return jsonify(_serialize_budget(db, current_user.id, budget))
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400
    finally:
        db.close()

@budget_bp.route("/<int:budget_id>", methods=["DELETE"])
@token_required
def delete_budget(current_user, budget_id):
    """
    DELETE /api/budgets/<id>
    """
    db = SessionLocal()
    try:
        budget = db.query(Budget).filter(
            Budget.id == budget_id,
            Budget.user_id == current_user.id,
        ).first()

        if not budget:
            return jsonify({"error": "Budget not found"}), 404

        db.delete(budget)
        db.commit()
        invalidate_summary_cache(current_user.id)
        return jsonify({"message": "Budget deleted successfully"}), 200
    finally:
        db.close()
