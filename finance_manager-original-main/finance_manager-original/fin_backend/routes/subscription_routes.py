from flask import Blueprint, request, jsonify
from database import SessionLocal
from models import Subscription, Transaction
from routes.auth_utils import token_required
from ai.analyzer import detect_subscriptions as detect_recurring_subscriptions
from datetime import datetime

subscriptions_bp = Blueprint("subscriptions", __name__)

@subscriptions_bp.route("/detect", methods=["POST"])
@token_required
def detect_subscriptions(current_user):
    data = request.json or {}
    persist = bool(data.get("persist", True))

    db = SessionLocal()
    txns = db.query(Transaction).filter(Transaction.user_id == current_user.id).all()
    detected = detect_recurring_subscriptions(txns)

    saved_count = 0
    if persist:
        for item in detected:
            name = item.get("name") or item.get("merchant") or "Subscription"
            merchant = item.get("merchant") or name
            amount = float(item.get("amount") or 0)
            frequency = item.get("frequency") or "monthly"
            next_date_raw = item.get("next_date")

            next_date = None
            if next_date_raw:
                try:
                    next_date = datetime.fromisoformat(next_date_raw.replace('Z', '+00:00'))
                except Exception:
                    next_date = None

            existing = db.query(Subscription).filter(
                Subscription.user_id == current_user.id,
                Subscription.merchant == merchant,
                Subscription.amount == amount,
                Subscription.frequency == frequency
            ).first()

            if existing:
                existing.name = name
                if next_date is not None:
                    existing.next_date = next_date
            else:
                db.add(Subscription(
                    user_id=current_user.id,
                    name=name,
                    merchant=merchant,
                    amount=amount,
                    frequency=frequency,
                    next_date=next_date
                ))
                saved_count += 1

        db.commit()

    db.close()
    return jsonify({
        "subscriptions": detected,
        "detected_count": len(detected),
        "saved_count": saved_count,
        "persisted": persist
    }), 200

@subscriptions_bp.route("/", methods=["GET"])
@token_required
def list_subscriptions(current_user):
    db = SessionLocal()
    subs = db.query(Subscription).filter(Subscription.user_id == current_user.id).order_by(Subscription.next_date).all()
    result = []
    for sub in subs:
        result.append({
            "id": sub.id,
            "name": sub.name,
            "merchant": sub.merchant,
            "amount": float(sub.amount),
            "frequency": sub.frequency,
            "next_date": sub.next_date.isoformat() if sub.next_date else None
        })
    db.close()
    return jsonify({"subscriptions": result}), 200

@subscriptions_bp.route("/", methods=["POST"])
@token_required
def create_subscription(current_user):
    data = request.json or {}
    name = data.get("name")
    merchant = data.get("merchant")
    amount = data.get("amount")
    frequency = data.get("frequency", "monthly")
    next_date = data.get("next_date")

    if not name or amount is None:
        return jsonify({"error": "name and amount are required"}), 400

    try:
        amount = float(amount)
    except (TypeError, ValueError):
        return jsonify({"error": "amount must be a number"}), 400

    if next_date:
        try:
            next_date = datetime.fromisoformat(next_date.replace('Z', '+00:00'))
        except Exception:
            return jsonify({"error": "next_date must be ISO format"}), 400
    else:
        next_date = None

    db = SessionLocal()
    subscription = Subscription(
        user_id=current_user.id,
        name=name,
        merchant=merchant,
        amount=amount,
        frequency=frequency,
        next_date=next_date
    )
    db.add(subscription)
    db.commit()
    db.refresh(subscription)
    db.close()

    return jsonify({
        "id": subscription.id,
        "name": subscription.name,
        "merchant": subscription.merchant,
        "amount": float(subscription.amount),
        "frequency": subscription.frequency,
        "next_date": subscription.next_date.isoformat() if subscription.next_date else None
    }), 201

@subscriptions_bp.route("/<int:sub_id>", methods=["PUT"])
@token_required
def update_subscription(current_user, sub_id):
    data = request.json or {}
    db = SessionLocal()
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        db.close()
        return jsonify({"error": "Subscription not found"}), 404

    if "name" in data:
        sub.name = data["name"]
    if "merchant" in data:
        sub.merchant = data["merchant"]
    if "amount" in data:
        try:
            sub.amount = float(data["amount"])
        except Exception:
            pass
    if "frequency" in data:
        sub.frequency = data["frequency"]
    if "next_date" in data:
        try:
            sub.next_date = datetime.fromisoformat(data["next_date"].replace('Z', '+00:00'))
        except Exception:
            pass

    db.commit()
    db.refresh(sub)
    db.close()

    return jsonify({
        "id": sub.id,
        "name": sub.name,
        "merchant": sub.merchant,
        "amount": float(sub.amount),
        "frequency": sub.frequency,
        "next_date": sub.next_date.isoformat() if sub.next_date else None
    }), 200

@subscriptions_bp.route("/<int:sub_id>", methods=["DELETE"])
@token_required
def delete_subscription(current_user, sub_id):
    db = SessionLocal()
    sub = db.query(Subscription).filter(Subscription.id == sub_id, Subscription.user_id == current_user.id).first()
    if not sub:
        db.close()
        return jsonify({"error": "Subscription not found"}), 404

    db.delete(sub)
    db.commit()
    db.close()
    return jsonify({"message": "Subscription deleted successfully"}), 200
