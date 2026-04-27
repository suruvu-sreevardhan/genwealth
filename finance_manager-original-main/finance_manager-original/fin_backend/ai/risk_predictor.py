# fin_backend/ai/risk_predictor.py
import math
from datetime import datetime, timedelta

def calculate_financial_health_score(monthly_income, total_monthly_spend, total_debt_emi=0,
                                    savings=0, emergency_fund_months=0, credit_utilization=0):
    """
    Comprehensive financial health score (0-100) based on multiple factors:
    - Savings ratio (30%)
    - Debt-to-income ratio (25%)
    - Emergency fund (20%)
    - Credit utilization (15%)
    - Spending consistency (10%)

    FIXED: Corrected all mathematical formulas for accurate scoring
    """
    if monthly_income in (None, 0):
        return {"score": 30, "grade": "Poor", "factors": {}}

    # FIXED: Calculate savings ratio correctly
    # total_monthly_spend should NOT include EMI (counted separately)
    disposable_income = monthly_income - total_debt_emi

    # Handle overspending case
    if disposable_income <= 0:
        savings_ratio = 0
        savings_amount = 0
    else:
        savings_amount = disposable_income - total_monthly_spend
        savings_ratio = max(0, savings_amount / monthly_income)

    # FIXED: Linear scoring (0-50% savings = 0-30 points)
    # If you save 50% of income = full 30 points
    savings_score = min(30, savings_ratio * 60)

    # 2. Debt-to-Income Ratio (25 points)
    # FIXED: DTI should be EMI/income, not total debt/annual income
    dti_ratio = total_debt_emi / monthly_income if monthly_income > 0 else 1

    if dti_ratio < 0.3:
        dti_score = 25
    elif dti_ratio < 0.4:
        dti_score = 20
    elif dti_ratio < 0.5:
        dti_score = 15
    elif dti_ratio < 0.6:
        dti_score = 10
    else:
        # Linear decrease after 60%
        dti_score = max(0, 10 - (dti_ratio - 0.6) * 25)

    # 3. Emergency Fund (20 points)
    if emergency_fund_months >= 6:
        emergency_score = 20
    elif emergency_fund_months >= 3:
        emergency_score = 15
    elif emergency_fund_months >= 1:
        emergency_score = 10
    elif emergency_fund_months >= 0.5:
        emergency_score = 5
    else:
        # FIXED: Linear scaling for < 0.5 months
        emergency_score = emergency_fund_months * 10

    # 4. Credit Utilization (15 points)
    if credit_utilization < 0.3:
        credit_score = 15
    elif credit_utilization < 0.5:
        credit_score = 10
    elif credit_utilization < 0.7:
        credit_score = 5
    else:
        credit_score = 0

    # 5. Spending Consistency (10 points)
    # FIXED: Gradual scoring instead of binary
    if savings_ratio >= 0.2:
        consistency_score = 10
    elif savings_ratio >= 0.15:
        consistency_score = 8
    elif savings_ratio >= 0.1:
        consistency_score = 6
    elif savings_ratio >= 0.05:
        consistency_score = 4
    else:
        consistency_score = 2

    total_score = int(savings_score + dti_score + emergency_score + credit_score + consistency_score)

    # Cap at 100
    total_score = min(100, total_score)

    # Determine grade
    if total_score >= 80:
        grade = "Excellent"
    elif total_score >= 60:
        grade = "Good"
    elif total_score >= 40:
        grade = "Fair"
    else:
        grade = "Poor"

    return {
        "score": total_score,
        "grade": grade,
        "factors": {
            "savings": {
                "score": int(savings_score),
                "ratio": f"{savings_ratio*100:.1f}%",
                "amount": round(savings_amount, 2)
            },
            "debt": {
                "score": int(dti_score),
                "dti_ratio": f"{dti_ratio*100:.1f}%",
                "monthly_emi": round(total_debt_emi, 2)
            },
            "emergency_fund": {
                "score": int(emergency_score),
                "months": round(emergency_fund_months, 2)
            },
            "credit_utilization": {
                "score": int(credit_score),
                "ratio": f"{credit_utilization*100:.1f}%"
            },
            "consistency": {
                "score": int(consistency_score)
            }
        }
    }

def predict_default_risk(monthly_income, monthly_emi, total_debt, missed_payments=0, credit_score=None):
    """
    FIXED: Predict probability of loan default (0-100)
    Uses monthly EMI instead of total debt for DTI calculation

    Risk factors:
    1. EMI-to-Income ratio (40%)
    2. Total debt burden (20%)
    3. Payment history (30%)
    4. Credit score (10%)
    """
    risk_score = 0

    # Factor 1: EMI-to-Income ratio (proper DTI) - Max 40 points
    if monthly_income > 0:
        dti = monthly_emi / monthly_income  # FIXED: Use monthly EMI
        if dti > 0.6:
            risk_score += 40
        elif dti > 0.5:
            risk_score += 35
        elif dti > 0.4:
            risk_score += 25
        elif dti > 0.3:
            risk_score += 15
        else:
            risk_score += 5
    else:
        risk_score += 50  # No income = very high risk

    # Factor 2: Total debt burden (as % of annual income) - Max 20 points
    if monthly_income > 0:
        annual_income = monthly_income * 12
        debt_to_income_ratio = total_debt / annual_income

        if debt_to_income_ratio > 5:  # Debt > 5 years income
            risk_score += 20
        elif debt_to_income_ratio > 3:
            risk_score += 15
        elif debt_to_income_ratio > 2:
            risk_score += 10
        else:
            risk_score += 5

    # Factor 3: Payment history - Max 30 points
    risk_score += min(30, missed_payments * 10)

    # Factor 4: Credit score (if available) - Max 10 points
    if credit_score:
        if credit_score < 550:
            risk_score += 10
        elif credit_score < 650:
            risk_score += 7
        elif credit_score < 700:
            risk_score += 3
        # No addition if credit score >= 700

    return min(100, risk_score)

def calculate_recommended_emergency_fund(monthly_expenses):
    """Calculate recommended emergency fund (3-6 months of expenses)"""
    if monthly_expenses <= 0:
        return {
            "minimum": 0,
            "recommended": 0,
            "ideal": 0,
            "message": "Add transactions to calculate emergency fund needs"
        }

    return {
        "minimum": round(monthly_expenses * 3, 2),
        "recommended": round(monthly_expenses * 6, 2),
        "ideal": round(monthly_expenses * 12, 2),
        "message": "Emergency fund should cover 3-6 months of expenses"
    }

def analyze_debt_burden(loans):
    """
    FIXED: Analyze overall debt burden with loan type weighting
    Distinguishes between high-interest and low-interest debt
    """
    total_debt = 0
    total_emi = 0
    active_loans = 0
    overdue_loans = 0

    # FIXED: Weight loans by risk/interest type
    high_interest_debt = 0  # Credit cards, personal loans
    low_interest_debt = 0   # Home loans, education loans

    loan_details = []

    for loan in loans:
        balance = float(loan.current_balance or 0)
        emi = float(loan.emi_amount or 0)
        account_type = loan.account_type or "Unknown"

        total_debt += balance

        if loan.status == 'open':
            active_loans += 1
            total_emi += emi

            # FIXED: Categorize by interest rate/type
            high_interest_types = ['Credit Card', 'Personal Loan', 'Payday Loan']
            if account_type in high_interest_types:
                high_interest_debt += balance
            else:
                low_interest_debt += balance

            loan_details.append({
                "type": account_type,
                "balance": balance,
                "emi": emi,
                "lender": loan.lender
            })

        if (loan.days_past_due or 0) > 0:
            overdue_loans += 1

    # FIXED: Better risk assessment based on multiple factors
    if overdue_loans > 0:
        risk_level = "Critical"
        risk_message = f"{overdue_loans} loan(s) overdue - immediate action required"
    elif high_interest_debt > total_debt * 0.5 and total_debt > 100000:  # >50% high-interest and >1L debt
        risk_level = "High"
        risk_message = "High-interest debt dominates - consider consolidation"
    elif total_emi > 0 and high_interest_debt > 0:
        risk_level = "Medium"
        risk_message = "Manageable debt but watch credit card balances"
    elif total_emi > 0:
        risk_level = "Low"
        risk_message = "Good debt (low interest)"
    else:
        risk_level = "None"
        risk_message = "No active debt"

    return {
        "total_outstanding": round(total_debt, 2),
        "high_interest_debt": round(high_interest_debt, 2),
        "low_interest_debt": round(low_interest_debt, 2),
        "total_monthly_emi": round(total_emi, 2),
        "active_loan_count": active_loans,
        "overdue_count": overdue_loans,
        "risk_level": risk_level,
        "risk_message": risk_message,
        "loan_details": loan_details
    }

def calculate_debt_free_date(loans):
    """
    Estimate when user will be debt-free based on current EMI payments
    """
    if not loans:
        return None

    # Calculate weighted average months remaining
    total_balance = 0
    weighted_months = 0

    for loan in loans:
        if loan.status != 'open':
            continue

        balance = float(loan.current_balance or 0)
        emi = float(loan.emi_amount or 0)

        if emi > 0:
            months_remaining = balance / emi
            weighted_months += months_remaining
            total_balance += balance

    if total_balance > 0 and weighted_months > 0:
        estimated_months = int(weighted_months)
        estimated_years = estimated_months // 12
        remaining_months = estimated_months % 12

        return {
            "months": estimated_months,
            "years": estimated_years,
            "remaining_months": remaining_months,
            "message": f"Approximately {estimated_years} year(s) and {remaining_months} month(s) at current EMI rate"
        }

    return None
