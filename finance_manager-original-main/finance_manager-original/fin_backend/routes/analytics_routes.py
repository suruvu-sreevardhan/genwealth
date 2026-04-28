# fin_backend/routes/analytics_routes.py
from flask import Blueprint, request, jsonify
from database import SessionLocal
from models import Transaction, User, Loan, Budget, Bill, Subscription
from routes.auth_utils import token_required
from datetime import datetime, timedelta, timezone
from collections import defaultdict
from threading import Lock
from time import monotonic
from ai.analyzer import (
    analyze_spending_patterns,
    detect_anomalies,
    calculate_category_averages,
    parse_sms_transaction,
    categorize,
    detect_subscriptions,
)
from ai.risk_predictor import calculate_financial_health_score, predict_default_risk, analyze_debt_burden, calculate_recommended_emergency_fund
from ai.coach import recommend_actions, generate_budget_recommendations, generate_savings_tips, generate_daily_tip
from services.health_service import calculate_financial_health_score_v2

analytics_bp = Blueprint("analytics", __name__)

_SUMMARY_CACHE: dict[tuple[int, str], tuple[float, dict]] = {}
_SUMMARY_CACHE_LOCK = Lock()
_SUMMARY_CACHE_TTL_SECONDS = 30


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _cache_get(user_id: int, key: str):
    now = monotonic()
    with _SUMMARY_CACHE_LOCK:
        entry = _SUMMARY_CACHE.get((user_id, key))
        if not entry:
            return None
        expires_at, payload = entry
        if expires_at < now:
            _SUMMARY_CACHE.pop((user_id, key), None)
            return None
        return payload


def _cache_set(user_id: int, key: str, payload: dict):
    with _SUMMARY_CACHE_LOCK:
        _SUMMARY_CACHE[(user_id, key)] = (monotonic() + _SUMMARY_CACHE_TTL_SECONDS, payload)


def invalidate_summary_cache(user_id: int | None = None):
    with _SUMMARY_CACHE_LOCK:
        if user_id is None:
            _SUMMARY_CACHE.clear()
            return
        for cache_key in list(_SUMMARY_CACHE.keys()):
            if cache_key[0] == user_id:
                _SUMMARY_CACHE.pop(cache_key, None)

@analytics_bp.route("/summary", methods=["GET"])
@token_required
def dashboard_summary(current_user):
    now = _utcnow()
    current_month = now.strftime("%Y-%m")
    cached = _cache_get(current_user.id, current_month)
    if cached is not None:
        return jsonify(cached)

    start = datetime(now.year, now.month, 1)
    if now.month == 12:
        end = datetime(now.year + 1, 1, 1)
    else:
        end = datetime(now.year, now.month + 1, 1)

    db = SessionLocal()
    txns = db.query(Transaction).filter(
        Transaction.user_id == current_user.id,
        Transaction.transaction_date >= start,
        Transaction.transaction_date < end
    ).order_by(Transaction.transaction_date.desc()).all()

    total_income = sum(float(t.amount) for t in txns if getattr(t, 'type', 'expense') == 'income')
    if total_income == 0 and current_user.monthly_income is not None:
        total_income = float(current_user.monthly_income)
    
    total_expense = sum(float(t.amount) for t in txns if getattr(t, 'type', 'expense') == 'expense')
    balance = total_income - total_expense

    recent = []
    for t in txns[:5]:
        recent.append({
            "id": t.id,
            "amount": float(t.amount),
            "type": t.type,
            "merchant": t.merchant,
            "category": t.category,
            "transaction_date": t.transaction_date.isoformat() if t.transaction_date else None,
            "notes": t.notes
        })

    expense_by_category = {}
    for t in txns:
        if getattr(t, 'type', 'expense') != 'expense':
            continue
        key = t.category or "uncategorized"
        expense_by_category[key] = expense_by_category.get(key, 0) + float(t.amount)

    top_categories = sorted(expense_by_category.items(), key=lambda x: x[1], reverse=True)[:3]
    top_categories_progress = [
        {
            "category": name,
            "spent": amount,
            "percentage": round((amount / total_expense * 100) if total_expense > 0 else 0, 1)
        }
        for name, amount in top_categories
    ]

    upcoming_bills = []
    bills = db.query(Bill).filter(
        Bill.user_id == current_user.id,
        Bill.paid == False,
        Bill.due_date >= now,
        Bill.due_date <= now + timedelta(days=30)
    ).order_by(Bill.due_date).all()
    for bill in bills:
        upcoming_bills.append({
            "id": bill.id,
            "name": bill.name,
            "amount": float(bill.amount),
            "category": bill.category,
            "due_date": bill.due_date.isoformat(),
            "paid": bill.paid
        })

    subscriptions = []
    for sub in db.query(Subscription).filter(Subscription.user_id == current_user.id).all():
        subscriptions.append({
            "id": sub.id,
            "name": sub.name,
            "merchant": sub.merchant,
            "amount": float(sub.amount),
            "frequency": sub.frequency,
            "next_date": sub.next_date.isoformat() if sub.next_date else None
        })

    insights = analyze_spending_patterns(txns)
    dynamic_insight = insights["insights"][0] if insights["insights"] else "Keep tracking to discover more insights."

    payload = {
        "month": current_month,
        "total_balance": balance,
        "total_income": total_income,
        "total_expense": total_expense,
        "recent_transactions": recent,
        "top_categories": top_categories_progress,
        "upcoming_bills": upcoming_bills,
        "subscriptions": subscriptions,
        "dynamic_insight": dynamic_insight
    }
    _cache_set(current_user.id, current_month, payload)

    db.close()
    return jsonify(payload)

@analytics_bp.route("/spending-summary", methods=["GET"])
@token_required
def spending_summary(current_user):
    month = request.args.get("month")  # format YYYY-MM
    if not month:
        return jsonify({"error": "month required (YYYY-MM)"}), 400

    db = SessionLocal()
    start = datetime.fromisoformat(month + "-01T00:00:00")
    parts = month.split("-")
    year = int(parts[0]); mon = int(parts[1])
    if mon == 12:
        end = datetime(year+1, 1, 1)
    else:
        end = datetime(year, mon+1, 1)

    # FIXED: Only sum expenses (positive amounts), exclude income
    transactions = db.query(Transaction).filter(
        Transaction.user_id == current_user.id,
        Transaction.transaction_date >= start,
        Transaction.transaction_date < end
    ).all()

    # Filter expenses only
    expenses = [t for t in transactions if float(t.amount) > 0 and t.category not in ['salary', 'income']]
    total = sum(float(t.amount) for t in expenses)

    by_cat = {}
    for t in expenses:
        cat = t.category if t.category else "uncategorized"
        by_cat[cat] = by_cat.get(cat, 0) + float(t.amount)

    db.close()

    return jsonify({
        "month": month,
        "total_spent": float(total),
        "by_category": by_cat
    })

@analytics_bp.route("/health-score", methods=["GET"])
@token_required
def get_health_score(current_user):
    """
    GET /api/analytics/health-score
    Returns comprehensive financial health score
    FIXED: Corrected all calculation logic
    """
    db = SessionLocal()

    monthly_income = float(current_user.monthly_income or 0) if current_user.monthly_income else 0

    txns = db.query(Transaction).filter(Transaction.user_id == current_user.id).all()
    now = _utcnow()
    current_month = now.strftime("%Y-%m")
    budgets = db.query(Budget).filter(
        Budget.user_id == current_user.id,
        Budget.month == current_month
    ).all()

    health_data = calculate_financial_health_score_v2(
        monthly_income=monthly_income,
        transactions=txns,
        budgets=budgets,
    )

    # Backward-compatible fields used by current mobile dashboard widgets.
    components = health_data.get("components", {})
    health_data["factors"] = {
        "savings": {"score": int(round((components.get("savings_rate", 0) * 40) * (30 / 40)))},
        "debt": {"score": int(round(components.get("budget_adherence", 0) * 25))},
        "emergency_fund": {"score": int(round(components.get("expense_stability", 0) * 20))}
    }

    if monthly_income <= 0:
        health_data["error"] = "Please set your monthly income in profile to calculate health score"
        db.close()
        return jsonify(health_data), 400

    db.close()
    return jsonify(health_data)

@analytics_bp.route("/risk-assessment", methods=["GET"])
@token_required
def get_risk_assessment(current_user):
    """
    GET /api/analytics/risk-assessment
    Returns detailed risk analysis including default probability
    FIXED: Uses correct DTI calculation
    """
    db = SessionLocal()

    monthly_income = float(current_user.monthly_income or 0) if current_user.monthly_income else 0
    loans = db.query(Loan).filter(Loan.user_id == current_user.id).all()

    total_debt = sum(float(loan.current_balance or 0) for loan in loans)
    total_emi = sum(float(loan.emi_amount or 0) for loan in loans if loan.status == 'open')
    missed_payments = sum(1 for loan in loans if (loan.days_past_due or 0) > 30)

    # Get latest credit score if available
    credit_score = None
    from models import CreditReportSnapshot
    latest_report = db.query(CreditReportSnapshot).filter(
        CreditReportSnapshot.user_id == current_user.id
    ).order_by(CreditReportSnapshot.report_date.desc()).first()
    if latest_report:
        credit_score = latest_report.credit_score

    # FIXED: Pass both EMI and total debt (corrected function signature)
    default_risk = predict_default_risk(
        monthly_income=monthly_income,
        monthly_emi=total_emi,  # FIXED: Added monthly EMI
        total_debt=total_debt,
        missed_payments=missed_payments,
        credit_score=credit_score
    )

    debt_analysis = analyze_debt_burden(loans)

    db.close()
    return jsonify({
        "default_risk_percentage": default_risk,
        "risk_level": "High" if default_risk > 60 else "Medium" if default_risk > 30 else "Low",
        "debt_analysis": debt_analysis
    })

@analytics_bp.route("/insights", methods=["GET"])
@token_required
def get_insights(current_user):
    """
    GET /api/analytics/insights
    Returns AI-generated spending insights and patterns
    FIXED: Uses category-specific averages for anomaly detection
    """
    db = SessionLocal()

    # Get last 90 days of transactions
    ninety_days_ago = _utcnow() - timedelta(days=90)
    all_txns = db.query(Transaction).filter(
        Transaction.user_id == current_user.id,
        Transaction.transaction_date >= ninety_days_ago
    ).all()

    # FIXED: Filter only expenses (skip income/refunds/salary)
    txns = [t for t in all_txns if float(t.amount) > 0 and t.category not in ['salary', 'income']]

    insights_data = analyze_spending_patterns(txns)

    # FIXED: Calculate category-specific averages for anomaly detection
    category_averages = calculate_category_averages(txns)

    # Get recent transactions for anomaly detection (last 7 days)
    recent_txns = [t for t in txns if t.transaction_date >= _utcnow() - timedelta(days=7)]
    anomalies = detect_anomalies(recent_txns, category_averages)  # FIXED: Pass category averages

    db.close()
    return jsonify({
        "insights": insights_data["insights"],
        "patterns": insights_data["patterns"],
        "anomalies": anomalies
    })


@analytics_bp.route("/gamification", methods=["GET"])
@token_required
def get_gamification(current_user):
    """
    GET /api/analytics/gamification
    Returns XP, streak metrics, badge status, and milestone unlocks.
    """
    now = _utcnow()
    start_30d = datetime(now.year, now.month, now.day) - timedelta(days=29)
    month_key = now.strftime("%Y-%m")
    month_start = datetime(now.year, now.month, 1)
    month_end = datetime(now.year + 1, 1, 1) if now.month == 12 else datetime(now.year, now.month + 1, 1)

    db = SessionLocal()
    try:
        txns_30d = db.query(Transaction).filter(
            Transaction.user_id == current_user.id,
            Transaction.transaction_date >= start_30d,
            Transaction.transaction_date <= now,
        ).all()

        txns_month = db.query(Transaction).filter(
            Transaction.user_id == current_user.id,
            Transaction.transaction_date >= month_start,
            Transaction.transaction_date < month_end,
        ).all()

        loans = db.query(Loan).filter(Loan.user_id == current_user.id).all()
        budgets = db.query(Budget).filter(
            Budget.user_id == current_user.id,
            Budget.month == month_key,
        ).all()

        daily_expense = defaultdict(float)
        daily_income = defaultdict(float)
        for t in txns_30d:
            if not t.transaction_date:
                continue
            d = t.transaction_date.date().isoformat()
            amount = float(t.amount or 0)
            ttype = (getattr(t, "type", "expense") or "expense").lower()
            if ttype == "income":
                daily_income[d] += abs(amount)
            else:
                daily_expense[d] += abs(amount)

        # 1) No-spend days in last 30 days
        no_spend_days = 0
        for i in range(30):
            day = (start_30d + timedelta(days=i)).date().isoformat()
            if daily_expense.get(day, 0) == 0:
                no_spend_days += 1

        # 2) Saving streak: consecutive days from today where expense == 0 OR income >= expense
        saving_streak = 0
        for i in range(30):
            day = (datetime(now.year, now.month, now.day) - timedelta(days=i)).date().isoformat()
            expense = daily_expense.get(day, 0)
            income = daily_income.get(day, 0)
            saving_day = expense == 0 or income >= expense
            if saving_day:
                saving_streak += 1
            else:
                break

        # 3) Budget adherence for badge progress
        spent_by_category = defaultdict(float)
        for t in txns_month:
            ttype = (getattr(t, "type", "expense") or "expense").lower()
            if ttype != "expense":
                continue
            category = (t.category or "uncategorized").lower()
            spent_by_category[category] += abs(float(t.amount or 0))

        budget_total = 0.0
        budget_ok_count = 0
        budget_exceeded_count = 0
        for b in budgets:
            limit_amount = abs(float(getattr(b, "limit_amount", 0) or 0))
            if limit_amount <= 0:
                continue
            budget_total += 1
            spent = spent_by_category.get((b.category or "uncategorized").lower(), 0)
            if spent <= limit_amount:
                budget_ok_count += 1
            if spent > limit_amount:
                budget_exceeded_count += 1

        budget_adherence = (budget_ok_count / budget_total) if budget_total > 0 else 0.0

        # 4) Debt profile for badge progress
        open_loans = [l for l in loans if (l.status or "").lower() == "open"]
        total_open_debt = sum(abs(float(l.current_balance or 0)) for l in open_loans)
        monthly_income = float(current_user.monthly_income or 0) if current_user.monthly_income else 0
        debt_target = (monthly_income * 2) if monthly_income > 0 else 0

        # 5) Investor signal
        invest_keywords = ["sip", "investment", "mutual", "stocks", "equity", "nps"]
        investor_hits = 0
        for t in txns_month:
            combined = f"{(t.category or '').lower()} {(t.merchant or '').lower()} {(t.notes or '').lower()}"
            if any(k in combined for k in invest_keywords):
                investor_hits += 1

        # XP model
        xp = 0
        xp += no_spend_days * 20
        xp += saving_streak * 15
        xp += int(budget_adherence * 100)
        if investor_hits > 0:
            xp += 80
        if total_open_debt == 0 and loans:
            xp += 100

        level = max(1, min(10, (xp // 200) + 1))
        level_names = {
            1: "Starter",
            2: "Planner",
            3: "Disciplined",
            4: "Saver",
            5: "Strategist",
            6: "Optimizer",
            7: "Builder",
            8: "Champion",
            9: "Master",
            10: "Legend",
        }

        budget_ninja_unlocked = budget_total >= 3 and budget_adherence >= 0.85 and budget_exceeded_count <= 1
        debt_slayer_unlocked = (len(open_loans) == 0) or (debt_target > 0 and total_open_debt <= debt_target)
        investor_starter_unlocked = investor_hits > 0

        badges = [
            {
                "id": "budget_ninja",
                "name": "Budget Ninja",
                "description": "Keep at least 85% of tracked budgets on track this month.",
                "unlocked": budget_ninja_unlocked,
                "progress": round(budget_adherence * 100, 1),
            },
            {
                "id": "debt_slayer",
                "name": "Debt Slayer",
                "description": "Maintain low or zero open debt burden.",
                "unlocked": debt_slayer_unlocked,
                "progress": 100.0
                if debt_slayer_unlocked
                else round(((debt_target / total_open_debt) * 100), 1)
                if total_open_debt > 0 and debt_target > 0
                else 0.0,
            },
            {
                "id": "investor_starter",
                "name": "Investor Starter",
                "description": "Log at least one investment-style transaction this month.",
                "unlocked": investor_starter_unlocked,
                "progress": 100.0 if investor_starter_unlocked else min(100.0, investor_hits * 40.0),
            },
        ]

        milestones = [
            {
                "title": "Spark Milestone",
                "xp_required": 150,
                "reward": "Priority AI saving tip",
                "unlocked": xp >= 150,
            },
            {
                "title": "Momentum Milestone",
                "xp_required": 350,
                "reward": "Advanced budget insights",
                "unlocked": xp >= 350,
            },
            {
                "title": "Mastery Milestone",
                "xp_required": 700,
                "reward": "Elite risk coaching",
                "unlocked": xp >= 700,
            },
        ]

        leaderboard_payload = {
            "enabled": False,
            "message": "Leaderboard is optional and currently disabled.",
            "sample_rank": None,
        }

        return jsonify({
            "xp": int(xp),
            "level": int(level),
            "level_name": level_names.get(level, "Saver"),
            "no_spend_days_30d": int(no_spend_days),
            "saving_streak_days": int(saving_streak),
            "badges": badges,
            "milestones": milestones,
            "leaderboard": leaderboard_payload,
        })
    finally:
        db.close()

@analytics_bp.route("/emergency-fund-recommendation", methods=["GET"])
@token_required
def get_emergency_fund_recommendation(current_user):
    """
    GET /api/analytics/emergency-fund-recommendation
    Returns recommended emergency fund amount
    FIXED: Includes EMI in monthly expenses
    """
    db = SessionLocal()

    # Calculate monthly expenses (last 30 days)
    thirty_days_ago = _utcnow() - timedelta(days=30)
    recent_txns = db.query(Transaction).filter(
        Transaction.user_id == current_user.id,
        Transaction.transaction_date >= thirty_days_ago
    ).all()

    # FIXED: Only count expenses, exclude income
    expenses = [t for t in recent_txns if float(t.amount) > 0 and t.category not in ['salary', 'income', 'emi']]
    monthly_expenses = sum(float(t.amount) for t in expenses)

    # FIXED: Add EMI to monthly expenses for emergency fund calculation
    loans = db.query(Loan).filter(Loan.user_id == current_user.id).all()
    total_emi = sum(float(loan.emi_amount or 0) for loan in loans if loan.status == 'open')

    total_monthly_obligations = monthly_expenses + total_emi

    recommendation = calculate_recommended_emergency_fund(total_monthly_obligations)

    # Add current emergency fund status
    current_fund = float(getattr(current_user, 'emergency_fund', 0))
    recommendation['current_fund'] = current_fund
    recommendation['months_covered'] = current_fund / total_monthly_obligations if total_monthly_obligations > 0 else 0

    if current_fund >= recommendation['recommended']:
        recommendation['status'] = 'excellent'
    elif current_fund >= recommendation['minimum']:
        recommendation['status'] = 'good'
    elif current_fund > 0:
        recommendation['status'] = 'needs_improvement'
    else:
        recommendation['status'] = 'critical'

    db.close()
    return jsonify({
        "monthly_obligations": total_monthly_obligations,
        "monthly_expenses": monthly_expenses,
        "monthly_emi": total_emi,
        "recommendations": recommendation
    })


@analytics_bp.route("/ai-widgets", methods=["GET"])
@token_required
def get_ai_widgets(current_user):
    """
    GET /api/analytics/ai-widgets
    Consolidated ML-powered finance widgets for dashboard cards.
    """
    db = SessionLocal()
    now = _utcnow()

    try:
        query_text = (request.args.get("text") or "").strip()

        six_months_ago = now - timedelta(days=180)
        thirty_days_ago = now - timedelta(days=30)

        txns_6m = db.query(Transaction).filter(
            Transaction.user_id == current_user.id,
            Transaction.transaction_date >= six_months_ago
        ).all()

        expenses_6m = [
            t for t in txns_6m
            if getattr(t, 'type', 'expense') == 'expense' and float(t.amount or 0) > 0 and (t.category or '').lower() not in ['salary', 'income']
        ]

        # 1) Auto category detection from text
        sample_text = query_text
        source = "query"

        if not sample_text:
            latest = db.query(Transaction).filter(
                Transaction.user_id == current_user.id
            ).order_by(Transaction.transaction_date.desc()).first()
            if latest:
                merchant = (latest.merchant or "").strip()
                notes = (latest.notes or "").strip()
                sample_text = f"{merchant} {notes}".strip()
                source = "latest_transaction"

        prediction = parse_sms_transaction(sample_text) if sample_text else {"category": "uncategorized", "merchant": None}
        predicted_category = prediction.get("category") or categorize("", sample_text)
        category_confidence = 0.86 if predicted_category != "uncategorized" else 0.52

        # 2) Subscription prediction
        subs = detect_subscriptions(txns_6m)
        subscriptions = sorted(subs, key=lambda s: s.get("next_date") or "")[:4]
        for sub in subscriptions:
            occurrences = int(sub.get("occurrences") or 0)
            sub["confidence"] = min(0.96, 0.58 + (occurrences * 0.08))
            sub["risk_level"] = "high" if occurrences >= 5 else "medium" if occurrences >= 3 else "low"

        # 3 + 4) Overspending warning and next-month spend forecast
        month_start = datetime(now.year, now.month, 1)
        month_end = datetime(now.year + 1, 1, 1) if now.month == 12 else datetime(now.year, now.month + 1, 1)
        days_in_month = (month_end - month_start).days
        days_elapsed = max(1, (now - month_start).days + 1)

        current_month_spend = sum(
            float(t.amount or 0)
            for t in expenses_6m
            if t.transaction_date and month_start <= t.transaction_date < month_end
        )
        projected_month_end = (current_month_spend / days_elapsed) * days_in_month

        monthly_map = defaultdict(float)
        for t in expenses_6m:
            if not t.transaction_date:
                continue
            key = t.transaction_date.strftime("%Y-%m")
            monthly_map[key] += float(t.amount or 0)

        recent_month_keys = sorted(monthly_map.keys())[-6:]
        recent_values = [monthly_map[k] for k in recent_month_keys]

        if len(recent_values) >= 2:
            trend_slope = (recent_values[-1] - recent_values[0]) / max(1, len(recent_values) - 1)
            forecast_next_month = max(0.0, recent_values[-1] + trend_slope)
            forecast_confidence = min(0.9, 0.52 + (len(recent_values) * 0.06))
        elif len(recent_values) == 1:
            forecast_next_month = recent_values[0]
            forecast_confidence = 0.5
        else:
            forecast_next_month = 0.0
            forecast_confidence = 0.35

        history_baseline = sum(recent_values[:-1]) / max(1, len(recent_values) - 1) if len(recent_values) > 1 else forecast_next_month
        overspend_ratio = (projected_month_end / history_baseline) if history_baseline > 0 else 1.0

        overspend_level = "high" if overspend_ratio >= 1.2 else "medium" if overspend_ratio >= 1.05 else "low"
        overspend_message = (
            "Your current pace indicates higher than usual spending."
            if overspend_level in ["high", "medium"]
            else "Your spending pace is within expected range."
        )

        # 5) Fraud / anomaly alerts
        category_averages = calculate_category_averages(expenses_6m)
        recent_expenses = [
            t for t in expenses_6m
            if t.transaction_date and t.transaction_date >= (now - timedelta(days=14))
        ]
        anomalies = detect_anomalies(recent_expenses, category_averages)
        anomaly_cards = []
        for item in anomalies[:4]:
            amount = float(item.get("amount") or 0)
            anomaly_cards.append({
                "transaction_id": item.get("transaction_id"),
                "merchant": item.get("merchant") or "Unknown",
                "category": item.get("category") or "uncategorized",
                "amount": amount,
                "reason": item.get("reason") or "Unusual spending pattern detected",
                "severity": "high" if amount >= 10000 else "medium",
                "date": item.get("date"),
            })

        # 6) Smart budget recommendation
        monthly_income = float(current_user.monthly_income or 0) if current_user.monthly_income else 0
        spend_30d_by_category = defaultdict(float)
        for t in expenses_6m:
            if not t.transaction_date or t.transaction_date < thirty_days_ago:
                continue
            category = (t.category or "uncategorized").lower()
            spend_30d_by_category[category] += float(t.amount or 0)

        budget_plan = generate_budget_recommendations(monthly_income, dict(spend_30d_by_category)) if monthly_income > 0 else None
        top_spend_category = None
        if spend_30d_by_category:
            top_spend_category = max(spend_30d_by_category.items(), key=lambda kv: kv[1])[0]

        budget_actions = []
        if budget_plan is None:
            budget_actions.append("Set monthly income to unlock personalized budget recommendations.")
        else:
            status = budget_plan.get("status", "under_budget")
            variance = float(budget_plan.get("variance") or 0)
            if status == "over_budget":
                budget_actions.append(f"Reduce discretionary spend by about ₹{abs(variance):.0f} this month.")
            else:
                budget_actions.append(f"You are under budget by about ₹{variance:.0f}. Consider moving this to savings.")
            if top_spend_category:
                budget_actions.append(f"Track {top_spend_category.title()} closely to improve budget efficiency.")

        payload = {
            "generated_at": now.isoformat(),
            "category_detection": {
                "input_text": sample_text,
                "source": source,
                "predicted_category": predicted_category,
                "merchant_hint": prediction.get("merchant"),
                "confidence": round(category_confidence, 2),
            },
            "subscription_prediction": {
                "count": len(subscriptions),
                "items": subscriptions,
            },
            "overspending_warning": {
                "level": overspend_level,
                "message": overspend_message,
                "current_month_spend": round(current_month_spend, 2),
                "projected_month_end_spend": round(projected_month_end, 2),
                "history_baseline": round(history_baseline, 2),
                "ratio": round(overspend_ratio, 2),
            },
            "next_month_forecast": {
                "amount": round(forecast_next_month, 2),
                "confidence": round(forecast_confidence, 2),
                "based_on_months": len(recent_values),
            },
            "fraud_anomaly_alerts": {
                "count": len(anomaly_cards),
                "items": anomaly_cards,
            },
            "smart_budget_recommendation": {
                "monthly_income": round(monthly_income, 2),
                "spending_30d": round(sum(spend_30d_by_category.values()), 2),
                "top_spend_category": top_spend_category,
                "plan": budget_plan,
                "actions": budget_actions,
            },
        }

        return jsonify(payload)
    finally:
        db.close()
