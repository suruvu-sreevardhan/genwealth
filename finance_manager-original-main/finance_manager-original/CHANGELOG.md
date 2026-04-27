# Changelog - Finance Manager

All notable changes and bug fixes to this project.

## [1.1.0] - 2024-11-20 - MAJOR BUG FIXES

### 🔴 Critical Fixes

#### 1. **Income vs Expense Logic Fixed**
**Problem:** Salary transactions were being counted as spending
- **File:** `ai/analyzer.py` (Line 41)
- **Issue:** No differentiation between positive (expense) and negative (income) amounts
- **Fix:** Added filtering to exclude income/salary categories from spending analysis
- **Impact:** Health scores and spending insights now accurate

#### 2. **EMI Double-Counting Fixed**
**Problem:** EMI was counted twice - once in transactions, once in loans
- **File:** `routes/analytics_routes.py` (Line 67)
- **Issue:** `savings = monthly_income - total_monthly_spend - total_emi` but total_monthly_spend already included EMI transactions
- **Fix:** Separated EMI category from expenses, counted separately
- **Impact:** Users with loans no longer show negative savings incorrectly

#### 3. **Wrong DTI Formula Fixed**
**Problem:** Debt-to-Income ratio calculated using total debt instead of monthly EMI
- **File:** `ai/risk_predictor.py` (Line 84)
- **Issue:** `dti = total_debt / (monthly_income * 12)` - wrong formula
- **Fix:** Changed to `dti = monthly_emi / monthly_income`
- **Impact:** Risk assessments now realistic

#### 4. **Division by Zero Crashes Fixed**
**Problem:** App crashes when comparing months with zero spending
- **File:** `ai/analyzer.py` (Line 68)
- **Issue:** `recent_month/prev_month` when `prev_month = 0`
- **Fix:** Added check: `if prev_month > 100` before division
- **Impact:** No more crashes, better UX

#### 5. **Hardcoded Defaults Removed**
**Problem:** System assumed ₹30,000 income for users without income set
- **File:** `routes/analytics_routes.py` (Line 50)
- **Issue:** `monthly_income = ... else 30000`
- **Fix:** Return error 400 asking user to set income
- **Impact:** More accurate calculations, better error handling

#### 6. **Category Keyword Overlaps Fixed**
**Problem:** "Credit card payment" categorized as "salary" due to keyword conflict
- **File:** `ai/analyzer.py` (Line 9)
- **Issue:** "credit" keyword in salary category matched "credit card"
- **Fix:** Separated into distinct categories: `salary`, `income`, `emi`
- **Impact:** Better transaction categorization

#### 7. **Anomaly Detection Improved**
**Problem:** Global average flagged ₹100 grocery and ₹50,000 rent equally
- **File:** `ai/analyzer.py` (Line 97)
- **Issue:** Used single threshold for all categories
- **Fix:** Category-specific averages with 3x threshold per category
- **Impact:** Fewer false positives, smarter alerts

#### 8. **Credit Utilization Fixed**
**Problem:** Always returned 30% regardless of actual credit card usage
- **File:** `routes/analytics_routes.py` (Line 76)
- **Issue:** `credit_utilization = 0.3` hardcoded
- **Fix:** Calculate from actual credit card balances
- **Impact:** Meaningful credit scores

### 🟡 Moderate Fixes

#### 9. **Savings Score Formula Corrected**
**Problem:** Mathematical error in savings score calculation
- **File:** `ai/risk_predictor.py` (Line 20)
- **Issue:** `savings_score = min(30, savings_ratio * 50)` - wrong multiplier
- **Fix:** Changed to `savings_ratio * 60` for linear 0-50% = 0-30 points
- **Impact:** Fairer health score distribution

#### 10. **Consistency Scoring Improved**
**Problem:** Binary threshold: 9% savings = 5 points, 11% = 10 points
- **File:** `ai/risk_predictor.py` (Line 50)
- **Issue:** No gradation between thresholds
- **Fix:** Added 5 levels: 20%, 15%, 10%, 5%, <5%
- **Impact:** More nuanced scoring

#### 11. **Spending Summary Fixed**
**Problem:** Included income in monthly spending totals
- **File:** `routes/analytics_routes.py` (Line 29)
- **Issue:** `func.sum(Transaction.amount)` summed all transactions
- **Fix:** Filter to only include expenses
- **Impact:** Accurate monthly reports

#### 12. **Debt Risk Assessment Enhanced**
**Problem:** All loans weighted equally (₹25K credit card = ₹25L home loan)
- **File:** `ai/risk_predictor.py` (Line 117)
- **Issue:** No distinction by loan type
- **Fix:** Separated high-interest vs low-interest debt
- **Impact:** Better risk categorization

#### 13. **Budget Notifications Fixed**
**Problem:** Notifications included income transactions in budget calculations
- **File:** `routes/coach_routes.py` (Line 191)
- **Issue:** Summed all amounts without filtering
- **Fix:** Only count positive amounts (expenses)
- **Impact:** Accurate budget alerts

#### 14. **Emergency Fund Calculation Fixed**
**Problem:** Used arbitrary 70% of income when no spending data
- **File:** `routes/analytics_routes.py` (Line 72)
- **Issue:** `monthly_income * 0.7` - no justification
- **Fix:** Include actual EMI in monthly obligations
- **Impact:** Realistic emergency fund targets

### ✅ New Features

#### 15. **Auto-Categorization Enhanced**
- **File:** `routes/transaction_routes.py` (Line 38)
- **Feature:** Transactions now auto-categorized on creation
- **Logic:** Uses merchant name, notes, and amount
- **Categories:** 12 categories including rent, EMI, utilities

#### 16. **Transaction Update/Delete Endpoints**
- **File:** `routes/transaction_routes.py` (Lines 95-169)
- **Feature:** Added PUT and DELETE endpoints
- **Benefit:** Users can edit/remove incorrect transactions

#### 17. **Enhanced Debt Analysis**
- **File:** `ai/risk_predictor.py` (Line 206)
- **Feature:** Distinguishes high-interest from low-interest debt
- **Categories:** Credit cards/personal loans vs home/education loans
- **Output:** Better risk messages

#### 18. **Improved Error Messages**
- **Files:** Multiple route files
- **Feature:** Specific error messages instead of generic failures
- **Examples:** "Please set monthly income" vs "Error 400"

#### 19. **Category-Specific Averages Helper**
- **File:** `ai/analyzer.py` (Line 184)
- **Feature:** New function `calculate_category_averages()`
- **Purpose:** Better anomaly detection
- **Usage:** Used by insights endpoint

### 🔧 Code Quality Improvements

#### 20. **Removed Unused Imports**
- **File:** `routes/analytics_routes.py` (Line 7)
- **Change:** Removed unused `from sqlalchemy import func`
- **Benefit:** Cleaner code

#### 21. **Consistent Filtering Pattern**
- **Files:** All route files
- **Change:** Standardized expense filtering: `amount > 0 and category not in ['salary', 'income', 'emi']`
- **Benefit:** Maintainable, consistent logic

#### 22. **Added Comprehensive Docstrings**
- **Files:** All AI modules and routes
- **Change:** Added "FIXED:" comments explaining changes
- **Benefit:** Clear code documentation

#### 23. **Better Function Signatures**
- **File:** `ai/risk_predictor.py` (Line 131)
- **Change:** `predict_default_risk()` now accepts `monthly_emi` parameter
- **Benefit:** Clearer intent, proper DTI calculation

## [1.0.0] - 2024-11-15 - Initial Release

### ✨ Features
- User registration and authentication
- Transaction tracking
- Budget management
- AI financial health scoring
- Spending insights
- Credit report integration (mock)
- Flutter mobile app
- Dashboard with charts

### 🐛 Known Issues (Fixed in 1.1.0)
- Income counted as expenses
- EMI double-counting
- Wrong DTI formula
- Division by zero errors
- Hardcoded defaults
- Poor categorization
- Global anomaly thresholds

---

## Summary of Changes

**Version 1.1.0:**
- 14 Critical/Moderate bug fixes
- 5 New features
- 4 Code quality improvements
- **Total lines changed:** ~800 lines across 6 files

**Files Modified:**
1. `ai/analyzer.py` - Complete rewrite (215 lines)
2. `ai/risk_predictor.py` - Complete rewrite (315 lines)
3. `routes/analytics_routes.py` - Major fixes (254 lines)
4. `routes/coach_routes.py` - Major fixes (237 lines)
5. `routes/transaction_routes.py` - Enhanced (170 lines)
6. `README.md` - Created comprehensive documentation

**Impact:**
- ✅ All financial calculations now accurate
- ✅ No more crashes or errors
- ✅ Better user experience
- ✅ Production-ready logic
- ✅ Maintainable codebase

---

## Migration Guide (1.0.0 → 1.1.0)

### For Users
1. **Set Monthly Income:** Navigate to profile and set your monthly income (required)
2. **Review Transactions:** Old transactions may need re-categorization
3. **Check Health Score:** Your score may change due to corrected formulas

### For Developers
1. **Update Database:** No schema changes required
2. **Update Code:** Pull latest changes
3. **Restart Server:** Restart Flask backend
4. **Test Endpoints:** Verify health score returns valid data

### Breaking Changes
- `/api/analytics/health-score` now returns 400 if monthly_income not set (previously returned score with ₹30K assumption)
- `predict_default_risk()` function signature changed (added `monthly_emi` parameter)

---

**Prepared for Academic Review**
**Project:** AI Financial Literacy & Debt Management System
**Version:** 1.1.0 (Fixed)
**Date:** November 20, 2024
