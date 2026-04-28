# GenWealth 🌐

**An AI-Driven Mobile System for Automated Expense Tracking, Behavioral Analysis, and Personalized Financial Insights**

A Bachelor of Technology (Computer Science & Engineering - AIML) project developed at **JAIN (Deemed-to-be University)**, Bangalore, India (Academic Year 2025-2026).

**Team Members:**
- Suruvu Sreevardhan (22BTRCL154)
- Charukonda Suprathik (22BTRCL037)
- Madhulika S (22BTRCL093)

**Under the Guidance of:**
- Dr. K.S. Arvind (Associate Professor, Project Guide)

---

## 🚀 Overview

GenWealth is a comprehensive, mobile-based personal finance management system designed to simplify expense tracking and enhance financial literacy. It helps users record income and expenses, automatically categorizes transactions using rule-based logic, monitors category-specific budgets, and detects recurring payments like subscriptions. The system provides actionable financial insights and calculates a unique **Financial Health Score** based on user behavior, helping individuals make sound financial decisions.

## 🎯 Key Features

### 📱 Premium Mobile Experience (Flutter)
* **Intuitive UI/UX**: Easy-to-use dashboard to log transactions manually and view financial statements.
* **Budget Management**: Set and track category-wise spending limits.
* **Recurring Expense Tracking**: Automatically detects and monitors recurring payments and subscriptions to prevent unnoticed expenses.
* **Smart Alert System**: Receive in-app notifications when spending reaches 80% of the allocated budget, exceeds the limit, or shows abnormal increases.

### 🤖 Intelligent Analytics (Flask Backend)
* **Spending Analyzer**: Uses a custom-trained **Machine Learning Model** to accurately categorize transactions (e.g., Food, Transport, Utilities, Shopping), with a smart rule-based fallback system.
* **Financial Health Score**: Calculates a comprehensive 0–100 score evaluating the user's financial condition based on savings rate, budget adherence, and expense stability.
* **AI Financial Assistant**: Delivers practical recommendations to improve spending habits, increase savings, and achieve financial discipline.

---

## 🏗 System Architecture

The application adopts a modular, three-layer architecture:

1. **Frontend**: Mobile application built with **Flutter** (Dart). Handles the user interface, data entry, and data visualization via charts.
2. **Backend**: RESTful API developed with **Python (Flask)**. Handles business logic, transaction processing, rule-based classification algorithms, and report generation.
3. **Database**: **SQLite**. A lightweight, embedded relational database for storing user profiles, transaction history, and budget configurations efficiently on the device.

```text
finance_manager-original-main/
├── Implementation/             # System documentation, architecture diagrams, and application screenshots
├── finlit_dev.db               # SQLite database for development
├── live.png                    # Project preview image
├── screen.png                  # Project preview image
└── finance_manager-original-main/
    └── finance_manager-original/
        ├── fin_backend/        # Python/Flask Backend & AI Engine
        └── fin_mobile/         # Flutter Mobile App
```

---

## ⚙️ Algorithms & Methodologies

1. **Transaction Classification Algorithm**: Machine learning-based inference (`joblib`, `scikit-learn`) on merchant names and descriptions, backed by robust rule-based logic.
2. **Financial Alert System Algorithm**: Continuously compares spending vs. defined thresholds, identifying significant increases over previous periods.
3. **Financial Health Score Algorithm**: 
   `Score = (0.4 × SavingsRate) + (0.3 × BudgetAdherence) + (0.3 × ExpenseStability)`

---

## 🛠 Getting Started

### 1. Backend Setup (fin_backend)

```bash
cd finance_manager-original-main/finance_manager-original/fin_backend
python -m venv venv
```

**Activate environment:**
* **Windows**: `venv\Scripts\activate`
* **Mac/Linux**: `source venv/bin/activate`

**Install dependencies & Start:**
```bash
pip install -r requirements.txt
python init_db.py
python app.py
```
*The backend will run on `http://127.0.0.1:5000`*

### 2. Mobile Setup (fin_mobile)

```bash
cd finance_manager-original-main/finance_manager-original/fin_mobile
flutter pub get
```

**Environment Variables:**
Create a `.env` file in the `fin_mobile` directory:
```env
BACKEND_URL=http://<your-local-ip>:5000
```

**Run the app:**
```bash
flutter run
```

---

## 📁 Implementation Details

The `Implementation` directory located at the root of this repository contains comprehensive resources regarding the system's architecture and final output:
* **Output Screenshots**: Visual documentation of the GenWealth application screens (Dashboard, Transactions, Profile, Tracking Page).
* **Implementation Guide**: Detailed documentation explaining the system architecture, AI modules, and integration workflows.

---

## 🛣 Future Scope

* **Predictive AI Modeling**: Expand the existing ML categorizer into broader predictive models for consumer behavior forecasting and optimized budget allocation.
* **Banking API Integration**: Direct integration with financial organizations for automated real-time transaction synchronization.
* **Multi-Language Support**: Expanding accessibility for a wider audience.
* **Dynamic Smart Alerts**: Behavior-based and adaptive threshold alerts via multiple channels (e.g., SMS, email).
* **Cloud Database Migration**: Moving to PostgreSQL or Firebase for better scalability.
