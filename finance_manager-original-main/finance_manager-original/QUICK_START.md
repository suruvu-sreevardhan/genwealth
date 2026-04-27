# Quick Start Guide - Finance Manager

## 🚀 Get Running in 5 Minutes

### Step 1: Backend (2 minutes)
```bash
cd fin_backend
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt
python init_db.py
python app.py
```
✅ Backend running on `http://localhost:5000`

### Step 2: Mobile (2 minutes)
```bash
cd fin_mobile
flutter pub get
flutter run
```
✅ Mobile app running on emulator/device

### Step 3: Test (1 minute)
1. **Register:** Create account with email/password
2. **Set Income:** Go to profile → Enter monthly income (required!)
3. **Add Transaction:** Add a transaction (e.g., "Swiggy", ₹500)
4. **View Dashboard:** See your financial health score

---

## 🧪 Quick Test API

```bash
# 1. Register
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123","monthly_income":50000}'

# Response: {"token": "eyJ..."}

# 2. Add Transaction
curl -X POST http://localhost:5000/api/transactions/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"amount":1500,"merchant":"Swiggy"}'

# 3. Get Health Score
curl http://localhost:5000/api/analytics/health-score \
  -H "Authorization: Bearer YOUR_TOKEN"

# Response: {"score":65,"grade":"Good",...}
```

---

## 📱 Mobile App Navigation

```
Login/Register → Home (5 tabs)
├── Transactions - View/add transactions
├── Dashboard - Charts & health score
├── Coach - Personalized advice
├── Budget - Set & track budgets
└── Loans - Credit report & loans
```

---

## 🔧 Troubleshooting

### Backend won't start?
```bash
# Check Python version (need 3.8+)
python --version

# Reinstall dependencies
pip install --upgrade -r requirements.txt

# Reset database
rm finlit_dev.db
python init_db.py
```

### Mobile won't connect?
```bash
# 1. Find your local IP
ipconfig                    # Windows
ifconfig                   # Mac/Linux

# 2. Update fin_mobile/.env
BACKEND_URL=http://YOUR_IP:5000

# 3. Restart app
flutter clean
flutter pub get
flutter run
```

`API_BASE_URL` is still accepted as a fallback key.

### "Please set monthly income" error?
- Go to Profile/Settings in mobile app
- Enter your monthly income
- This is required for health score calculations

---

## 📚 Key Files to Review

| File | Purpose |
|------|---------|
| `README.md` | Complete documentation |
| `CHANGELOG.md` | All fixes and changes |
| `FIXES_SUMMARY.md` | Before/after comparison |
| `fin_backend/ai/analyzer.py` | Transaction categorization |
| `fin_backend/ai/risk_predictor.py` | Health score logic |
| `fin_backend/routes/analytics_routes.py` | Main API endpoints |

---

## 🎯 Key Features to Demonstrate

1. **Auto-Categorization**
   - Add transaction with merchant="Swiggy"
   - Category automatically set to "food"

2. **Financial Health Score**
   - Add income in profile
   - Add some transactions
   - View health score (0-100)

3. **Budget Tracking**
   - Create budget for "food" = ₹5000
   - Add food transactions
   - Get alerts at 80% and 100%

4. **Risk Assessment**
   - View default risk percentage
   - See debt analysis if loans exist

5. **AI Insights**
   - View spending patterns
   - Get anomaly alerts
   - See trend analysis

---

## 💡 Sample Data for Demo

```python
# Good Financial Health Demo
Income: ₹60,000
Transactions:
  - Groceries: ₹8,000
  - Food: ₹4,000
  - Transport: ₹2,000
  - Utilities: ₹3,000
  - Entertainment: ₹2,000
Emergency Fund: ₹2,00,000

Expected Result: Health Score ~75-80 (Good)
```

```python
# Poor Financial Health Demo
Income: ₹30,000
Transactions:
  - Food: ₹8,000
  - Entertainment: ₹6,000
  - Shopping: ₹10,000
  - Transport: ₹3,000
EMI: ₹15,000
Emergency Fund: ₹0

Expected Result: Health Score ~30-35 (Poor)
```

---

## 🎓 For Presentation

### 3-Minute Demo Script

**Minute 1:** Show the problem
- "Traditional expense trackers only track, don't advise"
- "Our app uses AI to analyze and coach"

**Minute 2:** Core features
- Live demo: Add transaction → Auto-categorized
- Show dashboard with health score
- Show personalized advice

**Minute 3:** Technical highlights
- "Fixed 14 critical bugs in financial calculations"
- "Implemented proper DTI formula"
- "Category-specific anomaly detection"

### Key Selling Points
1. ✅ Auto-categorization using ML
2. ✅ Financial health score (like CIBIL for personal finance)
3. ✅ Personalized AI coach
4. ✅ Real credit report integration (mock)
5. ✅ Production-quality code (after fixes)

---

## 🐛 Known Limitations (Be Honest)

1. **SQLite Database** - Limited scalability (mention PostgreSQL upgrade path)
2. **Mock Credit Bureau** - Real integration needs partnership
3. **Rule-Based AI** - Can be enhanced with ML models
4. **No Push Notifications** - Only in-app alerts

---

## 📞 Support

**Issues?** Check these files:
- `README.md` - Full documentation
- `CHANGELOG.md` - Known bugs and fixes
- `FIXES_SUMMARY.md` - Before/after comparisons

**Still stuck?** Review the code comments marked with `# FIXED:`

---

## ✅ Pre-Submission Checklist

- [ ] Backend runs without errors
- [ ] Mobile app connects to backend
- [ ] Can register new user
- [ ] Can add transactions
- [ ] Health score displays correctly
- [ ] Auto-categorization works
- [ ] Budget alerts work
- [ ] README.md is complete
- [ ] CHANGELOG.md documents all fixes
- [ ] Code has proper comments

---

**Time to Complete:** 5 minutes
**Difficulty:** Easy
**Prerequisites:** Python 3.8+, Flutter 3.0+

**Last Updated:** November 2024
**Version:** 1.1.0 (Fixed & Production-Ready)
