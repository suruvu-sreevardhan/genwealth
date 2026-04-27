# fin_backend/ai/coach.py
from datetime import datetime
import random

def recommend_actions(health_score, financial_data=None):
    """Generate personalized financial advice based on health score and user data"""
    recommendations = []
    
    if health_score >= 80:
        recommendations.extend([
            "🎉 Excellent financial health! Keep up the great work.",
            "💡 Consider investing your surplus in mutual funds or SIP for long-term wealth.",
            "📊 Diversify your portfolio to include equity, debt, and gold.",
            "🎯 Set new financial goals like retirement planning or child's education."
        ])
    elif health_score >= 60:
        recommendations.extend([
            "👍 You're doing well! Focus on maintaining this momentum.",
            "💰 Increase your emergency fund to 6 months of expenses.",
            "📉 Review and reduce non-essential subscriptions and memberships.",
            "🎯 Set up automatic savings transfer on salary day."
        ])
    elif health_score >= 40:
        recommendations.extend([
            "⚠️ Your financial health needs attention.",
            "💳 Pay off high-interest credit card debt first.",
            "📊 Create a detailed monthly budget and track every expense.",
            "🚫 Avoid taking new loans until existing debt is reduced by 50%.",
            "💡 Look for ways to increase income - freelancing, side gigs."
        ])
    else:
        recommendations.extend([
            "🚨 Urgent action needed! Your finances are at risk.",
            "💸 Stop all non-essential spending immediately.",
            "📞 Contact a financial counselor for debt restructuring.",
            "📋 Create an emergency debt repayment plan.",
            "⚡ Consider debt consolidation to reduce EMI burden."
        ])
    
    # Add contextual recommendations based on spending patterns
    if financial_data:
        if financial_data.get('high_food_spending'):
            recommendations.append("🍽️ Your food delivery expenses are high. Cook at home to save ₹3000+/month.")
        
        if financial_data.get('high_entertainment'):
            recommendations.append("🎬 Reduce entertainment subscriptions. Keep only 1-2 essential services.")
        
        if financial_data.get('irregular_income'):
            recommendations.append("📈 Build a 12-month emergency fund due to irregular income.")
    
    return recommendations[:5]  # Return top 5 recommendations

def generate_budget_recommendations(monthly_income, current_spending):
    """Generate recommended budget allocation using 50/30/20 rule"""
    if not monthly_income or monthly_income <= 0:
        return None
    
    # 50/30/20 rule: 50% needs, 30% wants, 20% savings
    recommended_budget = {
        "needs": {
            "amount": monthly_income * 0.50,
            "categories": {
                "housing": monthly_income * 0.25,
                "utilities": monthly_income * 0.10,
                "groceries": monthly_income * 0.10,
                "transport": monthly_income * 0.05
            }
        },
        "wants": {
            "amount": monthly_income * 0.30,
            "categories": {
                "entertainment": monthly_income * 0.10,
                "dining_out": monthly_income * 0.10,
                "shopping": monthly_income * 0.10
            }
        },
        "savings": {
            "amount": monthly_income * 0.20,
            "categories": {
                "emergency_fund": monthly_income * 0.10,
                "investments": monthly_income * 0.07,
                "retirement": monthly_income * 0.03
            }
        }
    }
    
    # Calculate if user is over/under budget
    current_total = sum(current_spending.values()) if current_spending else 0
    variance = monthly_income - current_total
    
    return {
        "recommended": recommended_budget,
        "current_spending": current_total,
        "variance": variance,
        "status": "under_budget" if variance > 0 else "over_budget"
    }

def generate_savings_tips():
    """Generate practical savings tips"""
    tips = [
        "💡 Cancel unused subscriptions (OTT, gym, magazines)",
        "🍳 Meal prep on weekends to reduce food delivery expenses",
        "🚇 Use public transport instead of cab services",
        "💳 Pay credit card bills in full to avoid interest charges",
        "🛒 Make a shopping list and stick to it",
        "☕ Brew coffee at home instead of daily café visits",
        "📱 Switch to cheaper mobile/internet plans",
        "💡 Use LED bulbs and optimize electricity usage",
        "🎯 Use cashback and rewards credit cards wisely",
        "📚 Borrow books from library instead of buying"
    ]
    return random.sample(tips, 3)  # Return 3 random tips

def generate_daily_tip():
    """Generate a daily financial tip"""
    tips = [
        "Track every expense, no matter how small!",
        "Pay yourself first - save before you spend.",
        "Avoid impulse purchases - wait 24 hours before buying.",
        "Review your budget weekly, not just monthly.",
        "Automate your savings to make it effortless.",
        "Clear high-interest debt before investing.",
        "Build an emergency fund of 6 months expenses.",
        "Invest in your financial education.",
        "Compare prices before making purchases.",
        "Use the 50/30/20 budgeting rule."
    ]
    return random.choice(tips)
