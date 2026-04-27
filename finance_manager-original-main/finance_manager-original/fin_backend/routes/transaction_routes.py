# fin_backend/routes/transaction_routes.py
import csv
import io

from flask import Blueprint, request, jsonify, Response
from database import SessionLocal
from models import Transaction, MerchantCategoryRule
from datetime import datetime, timedelta, timezone
from routes.auth_utils import token_required
from ai.analyzer import categorize, normalize_category, infer_transaction_type, parse_sms_transaction
from routes.analytics_routes import invalidate_summary_cache

transactions_bp = Blueprint("transactions", __name__)


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _merchant_key(merchant: str | None) -> str:
    return (merchant or "").strip().lower()


def _serialize_transaction(t: Transaction) -> dict:
    return {
        "id": t.id,
        "amount": float(t.amount),
        "type": t.type,
        "merchant": t.merchant,
        "category": t.category,
        "transaction_date": t.transaction_date.isoformat() if t.transaction_date else None,
        "notes": t.notes,
    }


def _upsert_merchant_rule(db, user_id: int, merchant: str | None, category: str | None):
    merchant_key = _merchant_key(merchant)
    normalized_category = normalize_category(category)

    if not merchant_key:
        return

    if normalized_category in ["uncategorized", "salary", "income"]:
        return

    existing_rule = db.query(MerchantCategoryRule).filter(
        MerchantCategoryRule.user_id == user_id,
        MerchantCategoryRule.merchant_key == merchant_key
    ).first()

    if existing_rule:
        existing_rule.category = normalized_category
    else:
        db.add(MerchantCategoryRule(
            user_id=user_id,
            merchant_key=merchant_key,
            category=normalized_category
        ))

@transactions_bp.route("/", methods=["POST"])
@token_required
def create_transaction(current_user):
    """
    Create a new transaction
    FIXED: Auto-categorizes transactions if category not provided
    """
    data = request.json or {}
    amount = data.get("amount")
    merchant = data.get("merchant", "")
    notes = data.get("notes", "")
    txn_date_str = data.get("transaction_date")
    category = data.get("category", None)
    txn_type = data.get("type")
    category_provided = "category" in data and data.get("category") is not None

    if amount is None:
        return jsonify({"error": "amount required"}), 400

    try:
        amount = float(amount)
    except (TypeError, ValueError):
        return jsonify({"error": "amount must be a number"}), 400

    if txn_date_str:
        try:
            txn_date = datetime.fromisoformat(txn_date_str.replace('Z', '+00:00'))
        except Exception:
            txn_date = _utcnow()
    else:
        txn_date = _utcnow()

    db = SessionLocal()

    if category_provided:
        category = normalize_category(category)
    else:
        learned_rule = db.query(MerchantCategoryRule).filter(
            MerchantCategoryRule.user_id == current_user.id,
            MerchantCategoryRule.merchant_key == _merchant_key(merchant)
        ).first()

        if learned_rule:
            category = normalize_category(learned_rule.category)
        else:
            category = categorize(merchant, notes, amount, txn_type)

    txn_type = infer_transaction_type(category, merchant, notes, notes)
    if data.get("type") in ["income", "expense"]:
        txn_type = data.get("type")

    txn = Transaction(
        user_id=current_user.id,
        amount=abs(amount),
        type=txn_type,
        merchant=merchant,
        notes=notes,
        transaction_date=txn_date,
        category=category
    )
    db.add(txn)

    if category_provided:
        _upsert_merchant_rule(db, current_user.id, merchant, category)

    db.commit()
    db.refresh(txn)
    invalidate_summary_cache(current_user.id)

    result = _serialize_transaction(txn)

    db.close()
    return jsonify(result), 201

@transactions_bp.route("/parse-sms", methods=["POST"])
@token_required
def parse_sms(current_user):
    data = request.json or {}
    text = data.get("text") or data.get("message") or ""
    if not text:
        return jsonify({"error": "text is required"}), 400

    parsed = parse_sms_transaction(text)
    return jsonify(parsed), 200

@transactions_bp.route("/", methods=["GET"])
@token_required
def get_transactions(current_user):
    """
    Get all transactions for the current user
    FIXED: Returns consistent format with all fields
    """
    limit = int(request.args.get("limit", 100))
    category_filter = request.args.get("category")
    date_filter = request.args.get("date")
    txn_type = request.args.get("type")
    min_amount = request.args.get("min_amount")
    max_amount = request.args.get("max_amount")

    db = SessionLocal()
    query = db.query(Transaction).filter(Transaction.user_id == current_user.id)

    if category_filter:
        query = query.filter(Transaction.category == normalize_category(category_filter))
    if txn_type in ["income", "expense"]:
        query = query.filter(Transaction.type == txn_type)
    if date_filter:
        try:
            date = datetime.fromisoformat(date_filter[:10])
            next_day = date + timedelta(days=1)
            query = query.filter(Transaction.transaction_date >= date, Transaction.transaction_date < next_day)
        except Exception:
            pass
    if min_amount:
        try:
            query = query.filter(Transaction.amount >= float(min_amount))
        except Exception:
            pass
    if max_amount:
        try:
            query = query.filter(Transaction.amount <= float(max_amount))
        except Exception:
            pass

    txns = query.order_by(Transaction.transaction_date.desc()).limit(limit).all()

    out = []
    for t in txns:
        out.append(_serialize_transaction(t))

    db.close()
    return jsonify(out)


@transactions_bp.route("/export/csv", methods=["GET"])
@token_required
def export_transactions_csv(current_user):
    """
    Export the user's transactions as CSV.
    Optional filters: month=YYYY-MM, category, type.
    """
    month = request.args.get("month")
    category_filter = request.args.get("category")
    txn_type = request.args.get("type")

    db = SessionLocal()
    try:
        query = db.query(Transaction).filter(Transaction.user_id == current_user.id)

        if category_filter:
            query = query.filter(Transaction.category == normalize_category(category_filter))
        if txn_type in ["income", "expense"]:
            query = query.filter(Transaction.type == txn_type)
        if month:
            try:
                start = datetime.fromisoformat(f"{month}-01")
                year, mon = map(int, month.split("-"))
                end = datetime(year + 1, 1, 1) if mon == 12 else datetime(year, mon + 1, 1)
                query = query.filter(Transaction.transaction_date >= start, Transaction.transaction_date < end)
            except Exception:
                return jsonify({"error": "month must be in YYYY-MM format"}), 400

        txns = query.order_by(Transaction.transaction_date.desc()).all()

        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(["id", "amount", "type", "merchant", "category", "transaction_date", "notes"])
        for txn in txns:
            writer.writerow([
                txn.id,
                float(txn.amount),
                txn.type,
                txn.merchant or "",
                txn.category or "",
                txn.transaction_date.isoformat() if txn.transaction_date else "",
                txn.notes or "",
            ])

        response = Response(buffer.getvalue(), mimetype="text/csv")
        response.headers["Content-Disposition"] = "attachment; filename=transactions.csv"
        return response
    finally:
        db.close()

@transactions_bp.route("/<int:transaction_id>", methods=["PUT"])
@token_required
def update_transaction(current_user, transaction_id):
    """
    Update an existing transaction
    NEW: Added update endpoint for editing transactions
    """
    data = request.json or {}

    db = SessionLocal()
    txn = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()

    if not txn:
        db.close()
        return jsonify({"error": "Transaction not found"}), 404

    # Update fields if provided
    if "amount" in data:
        try:
            txn.amount = abs(float(data["amount"]))
        except (TypeError, ValueError):
            pass
    if "merchant" in data:
        txn.merchant = data["merchant"]
    if "notes" in data:
        txn.notes = data["notes"]
    if "category" in data:
        txn.category = normalize_category(data["category"])
    if "type" in data and data["type"] in ["income", "expense"]:
        txn.type = data["type"]
    if "transaction_date" in data:
        try:
            txn.transaction_date = datetime.fromisoformat(data["transaction_date"].replace('Z', '+00:00'))
        except Exception:
            pass

    if ("merchant" in data or "notes" in data or "type" in data) and "category" not in data:
        learned_rule = db.query(MerchantCategoryRule).filter(
            MerchantCategoryRule.user_id == current_user.id,
            MerchantCategoryRule.merchant_key == _merchant_key(txn.merchant)
        ).first()
        if learned_rule:
            txn.category = normalize_category(learned_rule.category)
        else:
            txn.category = categorize(txn.merchant, txn.notes, float(txn.amount), txn.type)

    if "category" in data:
        _upsert_merchant_rule(db, current_user.id, txn.merchant, txn.category)

    db.commit()
    db.refresh(txn)
    invalidate_summary_cache(current_user.id)

    result = {
        "id": txn.id,
        "amount": float(txn.amount),
        "type": txn.type,
        "merchant": txn.merchant,
        "category": txn.category,
        "transaction_date": txn.transaction_date.isoformat(),
        "notes": txn.notes
    }

    db.close()
    return jsonify(result)

@transactions_bp.route("/<int:transaction_id>", methods=["DELETE"])
@token_required
def delete_transaction(current_user, transaction_id):
    """
    Delete a transaction
    NEW: Added delete endpoint
    """
    db = SessionLocal()
    txn = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()

    if not txn:
        db.close()
        return jsonify({"error": "Transaction not found"}), 404

    db.delete(txn)
    db.commit()
    db.close()
    invalidate_summary_cache(current_user.id)

    return jsonify({"message": "Transaction deleted successfully"}), 200
