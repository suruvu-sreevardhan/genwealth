from flask import Blueprint

from routes.auth_routes import register, login
from routes.transaction_routes import create_transaction, get_transactions
from routes.analytics_routes import dashboard_summary, get_insights
from routes.budget_routes import get_budgets
from routes.subscription_routes import list_subscriptions
from routes.chatbot_routes import handle_chat

compat_bp = Blueprint("compat", __name__)


@compat_bp.route("/register", methods=["POST"])
def register_compat():
    return register()


@compat_bp.route("/login", methods=["POST"])
def login_compat():
    return login()


@compat_bp.route("/add_transaction", methods=["POST"])
def add_transaction_compat():
    return create_transaction()


@compat_bp.route("/get_transactions", methods=["GET"])
def get_transactions_compat():
    return get_transactions()


@compat_bp.route("/get_summary", methods=["GET"])
def get_summary_compat():
    return dashboard_summary()


@compat_bp.route("/get_insights", methods=["GET"])
def get_insights_compat():
    return get_insights()


@compat_bp.route("/get_budgets", methods=["GET"])
def get_budgets_compat():
    return get_budgets()


@compat_bp.route("/get_subscriptions", methods=["GET"])
def get_subscriptions_compat():
    return list_subscriptions()


@compat_bp.route("/chatbot", methods=["POST"])
def chatbot_compat():
    return handle_chat()
