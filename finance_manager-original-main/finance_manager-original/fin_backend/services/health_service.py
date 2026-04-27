from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta
from math import sqrt


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def _grade_from_score(score: int) -> str:
    if score > 80:
        return "Good"
    if score >= 50:
        return "Average"
    return "Poor"


def _safe_amount(value) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _is_income(txn) -> bool:
    return getattr(txn, "type", "expense") == "income" or (txn.category or "") in ["income", "salary"]


def _is_expense(txn) -> bool:
    return not _is_income(txn)


def _month_bounds(year: int, month: int):
    start = datetime(year, month, 1)
    if month == 12:
        end = datetime(year + 1, 1, 1)
    else:
        end = datetime(year, month + 1, 1)
    return start, end


def _expense_stability_from_transactions(expense_transactions: list) -> tuple[float, dict]:
    if not expense_transactions:
        return 1.0, {
            "mean_daily_spend": 0.0,
            "std_daily_spend": 0.0,
            "coefficient_of_variation": 0.0,
        }

    now = datetime.utcnow()
    daily = defaultdict(float)

    for txn in expense_transactions:
        if not getattr(txn, "transaction_date", None):
            continue
        if (now - txn.transaction_date).days > 30:
            continue
        day_key = txn.transaction_date.date().isoformat()
        daily[day_key] += abs(_safe_amount(getattr(txn, "amount", 0)))

    if not daily:
        return 1.0, {
            "mean_daily_spend": 0.0,
            "std_daily_spend": 0.0,
            "coefficient_of_variation": 0.0,
        }

    values = list(daily.values())
    mean_val = sum(values) / len(values)
    variance = sum((v - mean_val) ** 2 for v in values) / len(values)
    std_val = sqrt(variance)

    if mean_val <= 0:
        cv = 0.0
    else:
        cv = std_val / mean_val

    stability = 1.0 / (1.0 + cv)

    return _clamp01(stability), {
        "mean_daily_spend": round(mean_val, 2),
        "std_daily_spend": round(std_val, 2),
        "coefficient_of_variation": round(cv, 4),
    }


def _budget_adherence(budgets: list, expenses_in_month: list) -> tuple[float, dict]:
    if not budgets:
        return 0.0, {"within_budget": 0, "total_budget_categories": 0, "adherence_ratio": 0.0}

    spent_by_category = defaultdict(float)
    for txn in expenses_in_month:
        category = (getattr(txn, "category", None) or "uncategorized").lower()
        spent_by_category[category] += abs(_safe_amount(getattr(txn, "amount", 0)))

    within = 0
    for budget in budgets:
        category = (getattr(budget, "category", None) or "uncategorized").lower()
        limit_amount = _safe_amount(getattr(budget, "limit_amount", 0))
        spent = spent_by_category.get(category, 0.0)
        if limit_amount <= 0 or spent <= limit_amount:
            within += 1

    total = len(budgets)
    ratio = within / total if total > 0 else 0.0

    return _clamp01(ratio), {
        "within_budget": within,
        "total_budget_categories": total,
        "adherence_ratio": round(ratio, 4),
    }


def calculate_financial_health_score_v2(monthly_income: float, transactions: list, budgets: list):
    monthly_income = _safe_amount(monthly_income)

    if monthly_income <= 0:
        return {
            "score": 0,
            "grade": "Poor",
            "components": {
                "savings_rate": 0.0,
                "budget_adherence": 0.0,
                "expense_stability": 0.0,
            },
            "weighted": {
                "savings_rate": 0.0,
                "budget_adherence": 0.0,
                "expense_stability": 0.0,
            },
            "formula": "0.4*savings_rate + 0.3*budget_adherence + 0.3*expense_stability",
            "details": {
                "monthly_income": 0.0,
                "monthly_expenses": 0.0,
                "savings_rate_raw": 0.0,
                "budget": {"within_budget": 0, "total_budget_categories": 0, "adherence_ratio": 0.0},
                "stability": {"mean_daily_spend": 0.0, "std_daily_spend": 0.0, "coefficient_of_variation": 0.0},
            },
            "interpretation": "No monthly income set. Add income to calculate score.",
        }

    now = datetime.utcnow()
    month_start, month_end = _month_bounds(now.year, now.month)

    incomes_in_month = [t for t in transactions if _is_income(t) and getattr(t, "transaction_date", now) >= month_start and getattr(t, "transaction_date", now) < month_end]
    expenses_in_month = [t for t in transactions if _is_expense(t) and getattr(t, "transaction_date", now) >= month_start and getattr(t, "transaction_date", now) < month_end]

    income_total = sum(abs(_safe_amount(t.amount)) for t in incomes_in_month)
    expense_total = sum(abs(_safe_amount(t.amount)) for t in expenses_in_month)

    income_base = income_total if income_total > 0 else monthly_income

    savings_rate_raw = (income_base - expense_total) / income_base if income_base > 0 else 0.0
    savings_rate = _clamp01(savings_rate_raw)

    budget_adherence, budget_details = _budget_adherence(budgets, expenses_in_month)
    expense_stability, stability_details = _expense_stability_from_transactions(expenses_in_month)

    weighted_savings = 0.4 * savings_rate
    weighted_budget = 0.3 * budget_adherence
    weighted_stability = 0.3 * expense_stability

    normalized_total = weighted_savings + weighted_budget + weighted_stability
    score = int(round(_clamp01(normalized_total) * 100))
    grade = _grade_from_score(score)

    return {
        "score": score,
        "grade": grade,
        "components": {
            "savings_rate": round(savings_rate, 4),
            "budget_adherence": round(budget_adherence, 4),
            "expense_stability": round(expense_stability, 4),
        },
        "weighted": {
            "savings_rate": round(weighted_savings, 4),
            "budget_adherence": round(weighted_budget, 4),
            "expense_stability": round(weighted_stability, 4),
        },
        "formula": "0.4*savings_rate + 0.3*budget_adherence + 0.3*expense_stability",
        "details": {
            "monthly_income": round(income_base, 2),
            "monthly_expenses": round(expense_total, 2),
            "savings_rate_raw": round(savings_rate_raw, 4),
            "budget": budget_details,
            "stability": stability_details,
        },
        "interpretation": grade,
    }
