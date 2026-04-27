from flask import Blueprint, request, jsonify
from database import SessionLocal
from models import Transaction, Budget, Subscription, Bill
from routes.auth_utils import token_required
from ai.analyzer import analyze_spending_patterns
from ai.coach import generate_savings_tips, recommend_actions
from datetime import datetime, timedelta, timezone
import re

chatbot_bp = Blueprint("chatbot", __name__)


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)

def _format_currency(value):
    return f"₹{value:.2f}"

def _extract_amount(query: str) -> float | None:
    match = re.search(r"(₹|Rs\.?|INR)?\s*([0-9]+(?:[\.,][0-9]{1,2})?)", query, re.IGNORECASE)
    if not match:
        return None
    try:
        return float(match.group(2).replace(",", ""))
    except ValueError:
        return None

@chatbot_bp.route("/", methods=["POST"])
@token_required
def handle_chat(current_user):
    data = request.json or {}
    query = (data.get("query") or "").strip()
    if not query:
        return jsonify({"error": "query is required"}), 400

    db = SessionLocal()
    now = _utcnow()
    month_start = datetime(now.year, now.month, 1)
    transactions = db.query(Transaction).filter(
        Transaction.user_id == current_user.id,
        Transaction.transaction_date >= month_start
    ).all()
    budgets = db.query(Budget).filter(Budget.user_id == current_user.id).all()
    subscriptions = db.query(Subscription).filter(Subscription.user_id == current_user.id).all()
    bills = db.query(Bill).filter(Bill.user_id == current_user.id).all()
    db.close()

    expenses = [t for t in transactions if getattr(t, 'type', 'expense') == 'expense']
    insights = analyze_spending_patterns(expenses)
    spending_by_category = insights["patterns"].get("category_spending", {})
    top_category = max(spending_by_category.items(), key=lambda x: x[1])[0] if spending_by_category else None
    budget_categories = [b.category for b in budgets]

    query_lower = query.lower()
    answer = "I can help you understand your finances. Try asking about spending, budgets, or subscriptions."
    details = {}

    if any(term in query_lower for term in ["spend most", "where am i spending", "top category", "most spending"]):
        if top_category:
            amount = spending_by_category[top_category]
            answer = f"You are spending most on {top_category} with ₹{amount:.2f} this month."
            details = {"top_category": top_category, "amount": amount}
        else:
            answer = "I couldn't find enough expense data for this month yet."
    elif "save" in query_lower or "how can i" in query_lower or "save money" in query_lower:
        tips = generate_savings_tips()
        answer = "Here are a few ways to save money based on your spending patterns."
        details = {"tips": tips}
    elif "subscription" in query_lower or "subscriptions" in query_lower:
        total = sum(float(s.amount) for s in subscriptions)
        answer = f"Your saved subscriptions cost ₹{total:.2f} per cycle. Review recurring services and cancel unused items."
        details = {"subscription_count": len(subscriptions), "total_estimated_cost": total}
    elif "budget" in query_lower:
        if budget_categories:
            answer = f"You have active budgets for: {', '.join(budget_categories)}. Keep tracking category spending against them."
            details = {"budget_categories": budget_categories}
        else:
            answer = "You currently have no category budgets set. Add budgets to get alerts and better guidance."
    elif "afford" in query_lower or "can i" in query_lower:
        amount = _extract_amount(query_lower)
        if amount is not None:
            total_income = sum(float(t.amount) for t in transactions if getattr(t, 'type', 'expense') == 'income')
            total_expense = sum(float(t.amount) for t in expenses)
            remaining = total_income - total_expense
            if remaining >= amount:
                answer = f"Yes — you have about ₹{remaining:.2f} left this month, so ₹{amount:.2f} seems affordable."
            else:
                answer = f"It looks tight. You have about ₹{remaining:.2f} left this month, which is less than ₹{amount:.2f}."
            details = {"available": remaining, "requested": amount}
        else:
            answer = "Tell me an amount like ₹1200 and I can check whether your remaining budget can cover it."
    else:
        health_text = "Keep tracking expenses and stay within budget."
        if top_category:
            health_text = f"Your biggest expense area this month is {top_category}."
        answer = f"{health_text} If you'd like, ask me 'Where am I spending most?' or 'How can I save money?'"

    return jsonify({
        "query": query,
        "response": answer,
        "details": details
    }), 200
