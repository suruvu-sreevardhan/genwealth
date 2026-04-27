# fin_backend/routes/coach_routes.py
from flask import Blueprint, request, jsonify
from database import SessionLocal
from models import Transaction, Loan, Budget, Notification
from routes.auth_utils import token_required
from datetime import datetime, timedelta
from ai.coach import recommend_actions, generate_budget_recommendations, generate_savings_tips, generate_daily_tip
from ai.risk_predictor import analyze_debt_burden
from services.health_service import calculate_financial_health_score_v2

coach_bp = Blueprint("coach", __name__)

@coach_bp.route("/get-advice", methods=["POST"])
@token_required
def get_personalized_advice(current_user):
    """
    POST /api/coach/get-advice
    Returns personalized financial advice based on user's financial health
    FIXED: Corrected spending calculation to exclude income
    """
    db = SessionLocal()

    # FIXED: Don't use hardcoded default
    monthly_income = float(current_user.monthly_income or 0) if current_user.monthly_income else 0

    if monthly_income == 0:
        db.close()
        return jsonify({
            "error": "Please set your monthly income in profile",
            "recommendations": ["Set up your profile with monthly income to get personalized advice"]
        }), 400

    all_txns = db.query(Transaction).filter(Transaction.user_id == current_user.id).all()
    now = datetime.utcnow()
    current_month = now.strftime("%Y-%m")
    budgets = db.query(Budget).filter(
        Budget.user_id == current_user.id,
        Budget.month == current_month
    ).all()

    health_data = calculate_financial_health_score_v2(
        monthly_income=monthly_income,
        transactions=all_txns,
        budgets=budgets,
    )

    month_start = datetime(now.year, now.month, 1)
    expenses = [
        t for t in all_txns
        if t.transaction_date >= month_start and getattr(t, 'type', 'expense') == 'expense'
    ]
    total_monthly_spend = sum(float(t.amount) for t in expenses)
    savings = monthly_income - total_monthly_spend

    # FIXED: Analyze spending patterns for contextual advice (only expenses)
    spending_by_category = {}
    for txn in expenses:
        cat = txn.category or "uncategorized"
        spending_by_category[cat] = spending_by_category.get(cat, 0) + float(txn.amount)

    financial_context = {
        'high_food_spending': spending_by_category.get('food', 0) > monthly_income * 0.15,
        'high_entertainment': spending_by_category.get('entertainment', 0) > monthly_income * 0.10,
        'irregular_income': False  # Could be determined by analyzing income patterns
    }

    recommendations = recommend_actions(health_data['score'], financial_context)

    db.close()
    return jsonify({
        "health_score": health_data['score'],
        "grade": health_data['grade'],
        "recommendations": recommendations,
        "spending_breakdown": spending_by_category,
        "monthly_income": monthly_income,
        "monthly_expenses": total_monthly_spend,
        "monthly_emi": 0,
        "monthly_savings": savings
    })

@coach_bp.route("/budget-recommendations", methods=["GET"])
@token_required
def get_budget_recommendations(current_user):
    """
    GET /api/coach/budget-recommendations
    Returns recommended budget allocation using 50/30/20 rule
    FIXED: Only counts expenses for current spending
    """
    db = SessionLocal()

    monthly_income = float(getattr(current_user, 'monthly_income', 0)) or 0

    if monthly_income == 0:
        db.close()
        return jsonify({
            "error": "Please set your monthly income in profile",
            "recommended": {}
        }), 400

    # Calculate current spending by category (last 30 days) - ONLY expenses
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    recent_txns = db.query(Transaction).filter(
        Transaction.user_id == current_user.id,
        Transaction.transaction_date >= thirty_days_ago
    ).all()

    # FIXED: Only count expenses
    current_spending = {}
    for txn in recent_txns:
        amount = float(txn.amount)
        if amount > 0 and txn.category not in ['salary', 'income', 'emi']:
            cat = txn.category or "uncategorized"
            current_spending[cat] = current_spending.get(cat, 0) + amount

    budget_plan = generate_budget_recommendations(monthly_income, current_spending)

    db.close()
    return jsonify(budget_plan)

@coach_bp.route("/savings-tips", methods=["GET"])
@token_required
def get_savings_tips(current_user):
    """
    GET /api/coach/savings-tips
    Returns practical savings tips
    """
    tips = generate_savings_tips()
    return jsonify({"tips": tips})

@coach_bp.route("/daily-tip", methods=["GET"])
@token_required
def get_daily_financial_tip(current_user):
    """
    GET /api/coach/daily-tip
    Returns daily financial wisdom
    """
    tip = generate_daily_tip()
    return jsonify({"tip": tip, "date": datetime.utcnow().strftime("%Y-%m-%d")})

@coach_bp.route("/notifications", methods=["GET"])
@token_required
def get_coaching_notifications(current_user):
    """
    GET /api/coach/notifications
    Returns pending coaching tips and alerts
    FIXED: Better notification logic
    """
    db = SessionLocal()

    notifications = []

    def _persist_notification(notification_type: str, severity: str, message: str, **extra):
        existing = db.query(Notification).filter(
            Notification.user_id == current_user.id,
            Notification.type == notification_type,
            Notification.message == message,
            Notification.is_read == 0,
        ).first()

        if existing is None:
            db.add(Notification(
                user_id=current_user.id,
                type=notification_type,
                message=message,
                is_read=0,
            ))

        item = {"type": notification_type, "severity": severity, "message": message}
        item.update(extra)
        notifications.append(item)

    # Check for budget overruns (current month)
    now = datetime.utcnow()
    current_month = now.strftime("%Y-%m")
    budgets = db.query(Budget).filter(
        Budget.user_id == current_user.id,
        Budget.month == current_month
    ).all()

    for budget in budgets:
        # Calculate spending for this budget's category in current month
        start_of_month = datetime(now.year, now.month, 1)

        txns = db.query(Transaction).filter(
            Transaction.user_id == current_user.id,
            Transaction.category == budget.category,
            Transaction.transaction_date >= start_of_month
        ).all()

        # FIXED: Only count expenses
        total_spent = sum(float(t.amount) for t in txns if float(t.amount) > 0)
        budget_limit = float(budget.limit_amount)

        if total_spent >= budget_limit:
            _persist_notification(
                "budget_exceeded",
                "high",
                f"⚠️ You've exceeded your {budget.category} budget by ₹{total_spent - budget_limit:.2f}",
                category=budget.category,
                spent=total_spent,
                limit=budget_limit,
            )
        elif total_spent >= budget_limit * 0.8:
            _persist_notification(
                "budget_warning",
                "medium",
                f"⚡ You've used {(total_spent/budget_limit*100):.0f}% of your {budget.category} budget",
                category=budget.category,
                spent=total_spent,
                limit=budget_limit,
            )

    # Check for overdue loans
    loans = db.query(Loan).filter(
        Loan.user_id == current_user.id,
        Loan.days_past_due > 0
    ).all()

    for loan in loans:
        _persist_notification(
            "overdue_payment",
            "critical",
            f"🚨 Your {loan.account_type} payment is {loan.days_past_due} days overdue!",
            loan_id=loan.id,
            lender=loan.lender,
            days_overdue=loan.days_past_due,
        )

    # Add a daily tip
    _persist_notification("daily_tip", "info", f"💡 {generate_daily_tip()}")

    db.commit()

    db.close()
    return jsonify({"notifications": notifications, "count": len(notifications)})
