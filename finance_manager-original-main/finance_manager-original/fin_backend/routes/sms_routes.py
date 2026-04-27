from flask import Blueprint, request, jsonify
from routes.auth_utils import token_required
from ai.analyzer import parse_sms_transaction

sms_bp = Blueprint("sms", __name__)

@sms_bp.route("/parse", methods=["POST"])
@token_required
def parse_sms(current_user):
    data = request.json or {}
    text = data.get("text") or data.get("message") or ""
    if not text:
        return jsonify({"error": "text is required"}), 400

    parsed = parse_sms_transaction(text)
    return jsonify(parsed), 200
