from flask import Blueprint, request, jsonify
from database import SessionLocal
from models import Bill
from routes.auth_utils import token_required
from datetime import datetime

bills_bp = Blueprint("bills", __name__)

@bills_bp.route("/", methods=["GET"])
@token_required
def list_bills(current_user):
    db = SessionLocal()
    bills = db.query(Bill).filter(Bill.user_id == current_user.id).order_by(Bill.due_date).all()
    result = []
    for bill in bills:
        result.append({
            "id": bill.id,
            "name": bill.name,
            "amount": float(bill.amount),
            "category": bill.category,
            "due_date": bill.due_date.isoformat(),
            "paid": bool(bill.paid)
        })
    db.close()
    return jsonify({"bills": result}), 200

@bills_bp.route("/", methods=["POST"])
@token_required
def create_bill(current_user):
    data = request.json or {}
    name = data.get("name")
    amount = data.get("amount")
    category = data.get("category")
    due_date = data.get("due_date")
    paid = bool(data.get("paid", False))

    if not name or amount is None or not due_date:
        return jsonify({"error": "name, amount, and due_date are required"}), 400

    try:
        amount = float(amount)
    except (TypeError, ValueError):
        return jsonify({"error": "amount must be a number"}), 400

    try:
        due_date = datetime.fromisoformat(due_date.replace('Z', '+00:00'))
    except Exception:
        return jsonify({"error": "due_date must be ISO format"}), 400

    db = SessionLocal()
    bill = Bill(
        user_id=current_user.id,
        name=name,
        amount=amount,
        category=category,
        due_date=due_date,
        paid=paid
    )
    db.add(bill)
    db.commit()
    db.refresh(bill)
    db.close()

    return jsonify({
        "id": bill.id,
        "name": bill.name,
        "amount": float(bill.amount),
        "category": bill.category,
        "due_date": bill.due_date.isoformat(),
        "paid": bool(bill.paid)
    }), 201

@bills_bp.route("/<int:bill_id>", methods=["PUT"])
@token_required
def update_bill(current_user, bill_id):
    data = request.json or {}
    db = SessionLocal()
    bill = db.query(Bill).filter(Bill.id == bill_id, Bill.user_id == current_user.id).first()
    if not bill:
        db.close()
        return jsonify({"error": "Bill not found"}), 404

    if "name" in data:
        bill.name = data["name"]
    if "amount" in data:
        try:
            bill.amount = float(data["amount"])
        except Exception:
            pass
    if "category" in data:
        bill.category = data["category"]
    if "due_date" in data:
        try:
            bill.due_date = datetime.fromisoformat(data["due_date"].replace('Z', '+00:00'))
        except Exception:
            pass
    if "paid" in data:
        bill.paid = bool(data["paid"])

    db.commit()
    db.refresh(bill)
    db.close()

    return jsonify({
        "id": bill.id,
        "name": bill.name,
        "amount": float(bill.amount),
        "category": bill.category,
        "due_date": bill.due_date.isoformat(),
        "paid": bool(bill.paid)
    }), 200

@bills_bp.route("/<int:bill_id>", methods=["DELETE"])
@token_required
def delete_bill(current_user, bill_id):
    db = SessionLocal()
    bill = db.query(Bill).filter(Bill.id == bill_id, Bill.user_id == current_user.id).first()
    if not bill:
        db.close()
        return jsonify({"error": "Bill not found"}), 404

    db.delete(bill)
    db.commit()
    db.close()
    return jsonify({"message": "Bill deleted successfully"}), 200
