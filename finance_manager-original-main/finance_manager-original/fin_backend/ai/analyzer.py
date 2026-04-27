# fin_backend/ai/analyzer.py
from datetime import datetime, timedelta
from collections import defaultdict
import re

CANONICAL_CATEGORIES = [
    "food",
    "shopping",
    "transport",
    "entertainment",
    "utilities",
    "healthcare",
    "education",
    "grocery",
    "fuel",
    "rent",
    "emi",
    "salary",
    "income",
    "uncategorized",
]

CATEGORY_ALIASES = {
    "food": ["food", "food & dining", "dining"],
    "shopping": ["shopping"],
    "transport": ["transport", "travel"],
    "entertainment": ["entertainment"],
    "utilities": ["utilities", "bills", "bills & utilities", "bills and utilities", "bill", "utility"],
    "healthcare": ["healthcare", "health", "medical"],
    "education": ["education"],
    "grocery": ["grocery", "groceries"],
    "fuel": ["fuel"],
    "rent": ["rent", "housing"],
    "emi": ["emi", "loan", "loan payment", "installment"],
    "salary": ["salary"],
    "income": ["income"],
    "uncategorized": ["uncategorized", "other", "others", "misc", "miscellaneous"],
}


def normalize_category(category: str | None) -> str:
    if not category:
        return "uncategorized"

    cleaned = category.strip().lower()
    for canonical, aliases in CATEGORY_ALIASES.items():
        if cleaned == canonical or cleaned in aliases:
            return canonical

    return cleaned if cleaned in CANONICAL_CATEGORIES else "uncategorized"


def get_category_aliases(category: str | None) -> list[str]:
    canonical = normalize_category(category)
    aliases = set(CATEGORY_ALIASES.get(canonical, []))
    aliases.add(canonical)
    return list(aliases)

AMOUNT_REGEX = re.compile(r"(?:₹|Rs\.?|INR)\s*([0-9]+(?:[\.,][0-9]{1,2})?)", re.IGNORECASE)
INCOME_KEYWORDS = ["credited", "received", "deposit", "refund", "salary", "bonus", "cashback", "income"]
EXPENSE_KEYWORDS = ["debited", "paid", "spent", "purchase", "withdrawn", "txn", "sent", "paid to"]

SPEC_AMOUNT_REGEX = re.compile(r"(?:₹|Rs\.?)\s?\d+(?:,\d{3})*(?:\.\d+)?", re.IGNORECASE)

SMART_CATEGORY_RULES = {
    "food": ["swiggy", "zomato", "restaurant", "cafe"],
    "transport": ["uber", "ola", "fuel"],
    "shopping": ["amazon", "flipkart"],
    "utilities": ["electricity", "water", "recharge"],
    "entertainment": ["netflix", "spotify"],
}

# FIXED: Improved keyword mapping with no overlaps
KEYWORD_MAP = {
    "grocery": ["dmart", "bigbasket", "grocery", "supermarket", "walmart", "store", "market", "reliance fresh", "more", "safal"],
    "fuel": ["bharat petroleum", "hpcl", "indane", "fuel", "petrol", "diesel", "indian oil", "shell", "bp", "gas station"],
    "salary": ["salary", "payroll", "wages", "stipend"],
    "income": ["income", "interest earned", "dividend", "bonus", "refund", "cashback"],
    "entertainment": ["netflix", "prime video", "spotify", "movie", "cinema", "pvr", "inox", "hotstar", "youtube premium", "gaming"],
    "food": ["swiggy", "zomato", "restaurant", "cafe", "food", "dominos", "pizza", "mcdonald", "kfc", "starbucks", "dunkin"],
    "shopping": ["amazon", "flipkart", "myntra", "ajio", "shopping", "mall", "retail", "nykaa"],
    "transport": ["uber", "ola", "metro", "bus", "auto", "taxi", "rapido", "train ticket", "flight"],
    "utilities": ["electricity", "water bill", "gas bill", "broadband", "internet", "mobile recharge", "phone bill", "wifi"],
    "healthcare": ["hospital", "pharmacy", "doctor", "medicine", "clinic", "apollo", "medplus", "netmeds", "health"],
    "education": ["school", "college", "tuition", "course", "books", "udemy", "coursera", "skillshare"],
    "emi": ["emi", "loan payment", "installment", "credit card bill"],
    "rent": ["rent", "lease", "house rent", "pg"]
}

def infer_transaction_type(category: str | None = None, merchant: str | None = None, notes: str = "", text: str = "") -> str:
    normalized = normalize_category(category)
    combined = " ".join(filter(None, [merchant, notes, text])).lower()

    if normalized in ["salary", "income"]:
        return "income"

    if any(keyword in combined for keyword in INCOME_KEYWORDS):
        return "income"

    if any(keyword in combined for keyword in EXPENSE_KEYWORDS):
        return "expense"

    if normalized == "uncategorized" and any(word in combined for word in ["credit", "deposit"]):
        return "income"

    return "expense"


def _clean_merchant_name(raw_merchant: str | None) -> str | None:
    if not raw_merchant:
        return None
    merchant = raw_merchant.strip()
    merchant = re.sub(r"(?:upi|a/c|account|bank|neft|imps|rtgs|utr|txn|ref|id)\b.*", "", merchant, flags=re.IGNORECASE)
    merchant = re.sub(r"\b(via|on|at|for|by)\b.*", "", merchant, flags=re.IGNORECASE)
    merchant = re.sub(r"[^a-zA-Z0-9&@.\-\s]", " ", merchant)
    merchant = re.sub(r"\s+", " ", merchant).strip(" .,-")
    return merchant.title() if merchant else None


def _extract_amount(text: str) -> float:
    amount_text = None

    spec_match = SPEC_AMOUNT_REGEX.search(text)
    if spec_match:
        amount_text = spec_match.group(0)
    else:
        fallback_match = AMOUNT_REGEX.search(text)
        if fallback_match:
            amount_text = fallback_match.group(1)

    if not amount_text:
        return 0.0

    cleaned = re.sub(r"(?:₹|Rs\.?|INR)", "", amount_text, flags=re.IGNORECASE)
    cleaned = cleaned.replace(",", "").strip()

    try:
        return float(cleaned)
    except ValueError:
        return 0.0


def extract_merchant_from_text(text: str) -> str | None:
    cleaned = text.strip().lower()
    match = re.search(r"(?:\bto\b|\bfrom\b)\s+([a-z0-9&@\.\-\s']+)", cleaned)
    if match:
        return _clean_merchant_name(match.group(1))
    return None


def parse_sms_transaction(text: str) -> dict:
    text = text or ""
    amount = _extract_amount(text)
    txn_type = "expense"

    lower_text = text.lower()
    if "credited" in lower_text:
        txn_type = "income"
    elif "debited" in lower_text:
        txn_type = "expense"
    elif any(word in lower_text for word in INCOME_KEYWORDS):
        txn_type = "income"
    elif any(word in lower_text for word in EXPENSE_KEYWORDS):
        txn_type = "expense"

    merchant = extract_merchant_from_text(text) or "Unknown Merchant"
    category = categorize(merchant, text, amount, txn_type)
    if txn_type == "income" and category == "uncategorized":
        category = "income"

    return {
        "amount": amount,
        "merchant": merchant,
        "type": txn_type,
        "category": category,
        "notes": text.strip()
    }


def detect_subscriptions(transactions):
    grouped = defaultdict(list)
    for txn in transactions:
        if getattr(txn, 'type', 'expense') != 'expense':
            continue
        merchant = (txn.merchant or "unknown").strip().lower()
        if not merchant:
            continue
        key = (merchant, float(txn.amount))
        grouped[key].append(txn)

    subscriptions = []
    for (merchant, amount), txns in grouped.items():
        if len(txns) < 3:
            continue
        txns = [txn for txn in txns if getattr(txn, 'transaction_date', None)]
        txns.sort(key=lambda t: t.transaction_date)
        deltas = []
        for i in range(1, len(txns)):
            delta = (txns[i].transaction_date - txns[i-1].transaction_date).days
            if delta > 0:
                deltas.append(delta)
        if not deltas:
            continue
        avg_days = sum(deltas) / len(deltas)
        if avg_days < 10:
            frequency = "weekly"
        elif avg_days < 40:
            frequency = "monthly"
        else:
            frequency = "irregular"

        last_date = txns[-1].transaction_date
        if frequency == "weekly":
            next_date = last_date + timedelta(days=7)
        elif frequency == "monthly":
            next_date = last_date + timedelta(days=30)
        else:
            next_date = last_date + timedelta(days=int(avg_days))

        subscriptions.append({
            "name": merchant.title(),
            "merchant": merchant.title(),
            "amount": amount,
            "frequency": frequency,
            "next_date": next_date.isoformat(),
            "occurrences": len(txns)
        })

    return subscriptions


def categorize(merchant: str, notes: str = "", amount: float = 0, txn_type: str | None = None) -> str:
    """
    Categorize transaction based on merchant, notes, amount, and optional type.
    """
    if not merchant and not notes:
        return "uncategorized"

    s = (merchant or "") + " " + (notes or "")
    s = s.lower()
    if txn_type == "income":
        return "income"

    for cat, keywords in SMART_CATEGORY_RULES.items():
        if any(keyword in s for keyword in keywords):
            return cat

    for cat, kws in KEYWORD_MAP.items():
        for kw in kws:
            if kw in s:
                return normalize_category(cat)

    if amount == 0 and "salary" in s:
        return "salary"

    return "uncategorized"


def analyze_spending_patterns(transactions):
    """
    Analyze spending patterns and return insights
    FIXED: Only analyzes expenses (positive amounts), excludes income
    """
    if not transactions:
        return {"insights": [], "patterns": {}}

    # Group by category
    category_spending = defaultdict(float)
    monthly_spending = defaultdict(float)
    merchant_frequency = defaultdict(int)

    for txn in transactions:
        if getattr(txn, 'type', 'expense') != 'expense':
            continue
        amount = float(txn.amount)
        if amount <= 0:
            continue

        cat = txn.category or "uncategorized"
        if cat in ['salary', 'income']:
            continue

        if not getattr(txn, 'transaction_date', None):
            continue
        month = txn.transaction_date.strftime("%Y-%m")
        merchant = txn.merchant or "unknown"

        category_spending[cat] += amount
        monthly_spending[month] += amount
        merchant_frequency[merchant] += 1

    # Find top categories
    top_categories = sorted(category_spending.items(), key=lambda x: x[1], reverse=True)[:5]

    # Calculate average monthly spending
    avg_monthly = sum(monthly_spending.values()) / len(monthly_spending) if monthly_spending else 0

    # Find most frequent merchants
    top_merchants = sorted(merchant_frequency.items(), key=lambda x: x[1], reverse=True)[:5]

    insights = []

    # Generate insights
    if top_categories:
        top_cat, top_amount = top_categories[0]
        total_spend = sum(category_spending.values())
        if total_spend > 0:
            percentage = (top_amount / total_spend) * 100
            insights.append(f"Your highest spending is on {top_cat}: ₹{top_amount:.2f} ({percentage:.0f}%)")

    # FIXED: Safe division with zero check and better logic
    if len(monthly_spending) > 1:
        months = sorted(monthly_spending.keys())
        recent_month = monthly_spending[months[-1]]
        prev_month = monthly_spending[months[-2]] if len(months) > 1 else 0

        # FIXED: Only compare if previous month has data
        if prev_month > 100:  # Ignore if prev month spending < ₹100
            change_ratio = recent_month / prev_month
            if change_ratio > 1.2:
                change_pct = ((change_ratio - 1) * 100)
                insights.append(f"⚠️ Your spending increased by {change_pct:.1f}% this month")
            elif change_ratio < 0.8:
                change_pct = ((1 - change_ratio) * 100)
                insights.append(f"✅ Great! You reduced spending by {change_pct:.1f}% this month")
        elif recent_month > 0 and prev_month == 0:
            insights.append("📊 First month with spending data recorded")

    if top_merchants:
        top_merchant, frequency = top_merchants[0]
        if top_merchant != "unknown":
            insights.append(f"You visit {top_merchant} most frequently ({frequency} times)")

    # Additional insights
    if len(category_spending) > 0:
        # Check for high discretionary spending
        discretionary = sum(category_spending.get(cat, 0) for cat in ['food', 'entertainment', 'shopping'])
        total_spend = sum(category_spending.values())
        if total_spend > 0:
            disc_pct = (discretionary / total_spend) * 100
            if disc_pct > 40:
                insights.append(f"💡 {disc_pct:.0f}% of your spending is on discretionary items (food, entertainment, shopping)")

    return {
        "insights": insights,
        "patterns": {
            "category_spending": dict(category_spending),
            "monthly_spending": dict(monthly_spending),
            "top_categories": top_categories,
            "top_merchants": top_merchants,
            "average_monthly": avg_monthly
        }
    }

def detect_anomalies(transactions, category_averages):
    """
    FIXED: Detect unusual spending patterns per category
    category_averages: dict of {category: avg_amount}
    """
    anomalies = []

    for txn in transactions:
        if getattr(txn, 'type', 'expense') != 'expense':
            continue
        amount = float(txn.amount)
        category = txn.category or "uncategorized"

        if amount <= 0 or category in ['salary', 'income']:
            continue

        cat_avg = category_averages.get(category, 0)

        # FIXED: Flag if transaction is > 3x category average (or > ₹5000 if no history)
        threshold_multiplier = 3

        if cat_avg > 0:
            if amount > cat_avg * threshold_multiplier:
                anomalies.append({
                    "transaction_id": txn.id,
                    "amount": amount,
                    "merchant": txn.merchant,
                    "category": category,
                    "date": txn.transaction_date.isoformat() if getattr(txn, 'transaction_date', None) else None,
                    "reason": f"{threshold_multiplier}x higher than your usual {category} spending (avg: ₹{cat_avg:.2f})"
                })
        elif amount > 5000:  # Flag large transactions with no history
            anomalies.append({
                "transaction_id": txn.id,
                "amount": amount,
                "merchant": txn.merchant,
                "category": category,
                "date": txn.transaction_date.isoformat() if getattr(txn, 'transaction_date', None) else None,
                "reason": f"Large {category} transaction (no spending history for comparison)"
            })

    return anomalies

def calculate_category_averages(transactions):
    """
    Calculate average spending per category
    Helper function for anomaly detection
    """
    category_totals = defaultdict(float)
    category_counts = defaultdict(int)

    for txn in transactions:
        if getattr(txn, 'type', 'expense') != 'expense':
            continue
        amount = float(txn.amount)

        if amount <= 0:
            continue

        category = txn.category or "uncategorized"

        if category in ['salary', 'income']:
            continue

        category_totals[category] += amount
        category_counts[category] += 1

    # Calculate averages
    category_averages = {}
    for cat in category_totals:
        if category_counts[cat] > 0:
            category_averages[cat] = category_totals[cat] / category_counts[cat]

    return category_averages
