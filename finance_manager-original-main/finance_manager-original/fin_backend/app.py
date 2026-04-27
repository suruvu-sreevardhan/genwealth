# fin_backend/app.py
from flask import Flask, jsonify, g, request
from flask_cors import CORS
from config import Config
from database import engine, Base, apply_schema_patches, apply_performance_patches, SessionLocal
import models  # import models to register tables with Base
import routes  # import routes package to register blueprints
import time
import uuid

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    CORS(
        app,
        resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}},
        supports_credentials=False,
    )

    # create DB tables if not present
    Base.metadata.create_all(bind=engine)
    apply_schema_patches()
    apply_performance_patches()

    @app.before_request
    def _start_request_timer():
        g.request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        g.request_started_at = time.perf_counter()

    @app.after_request
    def _attach_request_metadata(response):
        request_id = getattr(g, "request_id", None)
        if request_id:
            response.headers["X-Request-ID"] = request_id

        started_at = getattr(g, "request_started_at", None)
        if started_at is not None:
            duration_ms = (time.perf_counter() - started_at) * 1000
            print(f"[request] id={request_id} method={request.method} path={request.path} status={response.status_code} duration_ms={duration_ms:.2f}")

        return response

    @app.teardown_request
    def _cleanup_session(_exc=None):
        SessionLocal.remove()

    # register blueprints from routes package
    from routes.auth_routes import auth_bp
    from routes.transaction_routes import transactions_bp
    from routes.analytics_routes import analytics_bp
    from routes.coach_routes import coach_bp
    from routes.budget_routes import budget_bp
    from routes.credit_routes import credit_bp
    from routes.user_routes import user_bp
    from routes.sms_routes import sms_bp
    from routes.subscription_routes import subscriptions_bp
    from routes.bill_routes import bills_bp
    from routes.chatbot_routes import chatbot_bp
    from routes.compat_routes import compat_bp

    app.register_blueprint(auth_bp, url_prefix="/api/auth")
    app.register_blueprint(transactions_bp, url_prefix="/api/transactions")
    app.register_blueprint(sms_bp, url_prefix="/api/sms")
    app.register_blueprint(analytics_bp, url_prefix="/api/analytics")
    app.register_blueprint(coach_bp, url_prefix="/api/coach")
    app.register_blueprint(budget_bp, url_prefix="/api/budgets")
    app.register_blueprint(subscriptions_bp, url_prefix="/api/subscriptions")
    app.register_blueprint(bills_bp, url_prefix="/api/bills")
    app.register_blueprint(chatbot_bp, url_prefix="/api/chatbot")
    app.register_blueprint(credit_bp, url_prefix="/api/credit")
    app.register_blueprint(user_bp, url_prefix="/api/user")
    app.register_blueprint(compat_bp)

    @app.get("/")
    def index():
        return jsonify({"status": "ok", "message": "Finlit backend running"})

    @app.get("/api/health")
    def health_check():
        return jsonify({"status": "ok", "service": "finlit-backend"})

    return app

if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=5000, debug=False, use_reloader=False)
