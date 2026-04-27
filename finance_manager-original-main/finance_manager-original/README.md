# 🌐 Finance Manager — AI-Powered Personal Financial Wellness App

Finance Manager is a full-stack personal finance platform that helps users track expenses, plan budgets, manage loans, and improve their financial health. The system uses rule-based AI modules to generate insights, detect risks, and provide personalized recommendations — all accessible through a modern Flutter mobile app.

---

## 🚀 Features

### 🔐 Authentication & Profiles

* Secure user registration and login
* JWT-based authentication
* User financial profile (income & preferences)

### 💰 Transaction Management

* Automatic transaction categorization
* Income vs expense separation
* Merchant-based classification
* Edit/delete transactions in real time

### 📊 Budgeting Tools

* Category-wise monthly budgets
* Overspending alerts
* Live budget vs usage tracking

### 🧮 Loan & Credit Monitoring

* PAN-based mock credit report flow
* Loan summary (principal, EMI, interest)
* Estimated credit utilization

### 🤖 AI Intelligence Layer

**1. Spending Analyzer**

* Identifies patterns, spikes, anomalies
* Merchant keyword-based auto-tagging

**2. Risk Assessment Engine**

* Generates a 0–100 financial health score
* Considers savings stability, debt load, emergency fund

**3. Finance Coach**

* Personalized advice
* Category-level insights
* Daily money-saving suggestions

### 📈 Insights & Reports

* Monthly expenditure summaries
* Category charts
* Risk alerts
* Emergency fund recommendation

---

## 🏗 Project Structure

```
Finance Manager/
├── fin_backend/
│   ├── ai/
│   │   ├── analyzer.py
│   │   ├── risk_predictor.py
│   │   └── coach.py
│   ├── routes/
│   ├── models.py
│   ├── database.py
│   ├── config.py
│   ├── app.py
│   └── requirements.txt
│
└── fin_mobile/
    ├── lib/
    │   ├── screens/
    │   ├── services/
    │   ├── providers/
    │   └── main.dart
    └── pubspec.yaml
```

---

## ⚙️ Backend Setup

```bash
cd fin_backend
python -m venv venv
```

Activate environment:

**Windows**

```bash
venv\Scripts\activate
```

**Mac/Linux**

```bash
source venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Environment variables (`.env`):

```
FLASK_ENV=development
SECRET_KEY=your-secret
JWT_SECRET=your-jwt-secret
DATABASE_URL=sqlite:///finlit_dev.db
```

Initialize DB:

```bash
python init_db.py
```

Start backend:

```bash
python app.py
```

---

## 📱 Mobile Setup

```bash
cd fin_mobile
flutter pub get
```

Add mobile `.env`:

```
BACKEND_URL=http://<your-local-ip>:5000
```

`API_BASE_URL` is also supported as a fallback for older setups.

Run application:

```bash
flutter run
```

---

## 🧩 Database Models

* **users** — user account & income profile
* **transactions** — categorized income/expense entries
* **budgets** — monthly spending limits
* **loans** — loan & EMI details
* **credit_report_snapshots** — credit report history
* **notifications** — AI-generated alerts

---

## 🔌 API Highlights

### Authentication

* `POST /api/auth/register`
* `POST /api/auth/login`

### Transactions

* Create / fetch / update / delete transactions

### Analytics

* `GET /api/analytics/health-score`
* `GET /api/analytics/risk-assessment`
* `GET /api/analytics/insights`
* `GET /api/analytics/spending-summary`
* `GET /api/analytics/emergency-fund-recommendation`

### Coaching

* Personalized financial advice
* Daily tips
* Budget recommendations

### Budgets & Credit

* Full budget CRUD
* PAN mock KYC flow
* Loan summary

---

## 🧪 Quick Test Example

```bash
# Register user
curl -X POST http://localhost:5000/api/auth/register \
-d '{"email":"user@example.com","password":"pass123","monthly_income":50000}'

# Add a transaction
curl -X POST http://localhost:5000/api/transactions/ \
-H "Authorization: Bearer TOKEN" \
-d '{"amount":1200,"merchant":"Swiggy"}'

# Fetch health score
curl http://localhost:5000/api/analytics/health-score \
-H "Authorization: Bearer TOKEN"
```

---

## 🎛 Financial Health Score (0–100)

| Metric             | Weight |
| ------------------ | ------ |
| Savings Ratio      | 30%    |
| Debt-to-Income     | 25%    |
| Emergency Fund     | 20%    |
| Credit Utilization | 15%    |
| Consistency        | 10%    |

---

## 🆕 Recent Changes (v1.1)

* More accurate income/expense detection
* Corrected DTI calculation using monthly EMI
* Improved anomaly detection
* Removed hardcoded assumptions
* Zero-division safety checks
* Enhanced auto-categorization logic
* Expanded notification system

---

## 🛣 Roadmap

* Banking API integration
* ML-based predictive modeling
* Investment/portfolio tracking
* Bill reminders & push notifications
* Multi-currency support
* Shared family accounts

---
