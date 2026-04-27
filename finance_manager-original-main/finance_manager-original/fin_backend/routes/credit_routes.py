# fin_backend/routes/credit_routes.py
from flask import Blueprint, request, jsonify
from database import SessionLocal
from models import Loan, CreditReportSnapshot, User
from routes.auth_utils import token_required
from services.rate_limiter import check_rate_limit
from datetime import datetime, timezone
import random
import string

credit_bp = Blueprint("credit", __name__)

# Mock KYC and credit bureau integration
# In production, this would integrate with actual credit bureaus via APIs

def generate_consent_id():
    """Generate a mock consent request ID"""
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=12))

def generate_otp():
    """Generate a 6-digit OTP"""
    return ''.join(random.choices(string.digits, k=6))

# Store OTPs temporarily (in production, use Redis or database)
otp_storage = {}


def _rate_limit_key(current_user_id: int, action: str) -> str:
    return f"{action}:{current_user_id}"


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)

@credit_bp.route("/kyc/initiate-pan-consent", methods=["POST"])
@token_required
def initiate_pan_consent(current_user):
    """
    POST /api/credit/kyc/initiate-pan-consent
    body: { "pan": "ABCDE1234F", "name": "John Doe", "dob": "1990-01-15", "mobile": "9876543210" }
    
    Initiates PAN-based KYC consent flow
    """
    data = request.get_json()
    pan = data.get("pan")
    name = data.get("name")
    dob = data.get("dob")
    mobile = data.get("mobile")
    
    if not all([pan, name, dob, mobile]):
        return jsonify({"error": "pan, name, dob, and mobile are required"}), 400

    allowed, retry_after = check_rate_limit(_rate_limit_key(current_user.id, "kyc_initiate"), limit=3, window_seconds=900)
    if not allowed:
        return jsonify({
            "error": "too_many_requests",
            "message": "Too many KYC initiation attempts. Please try again later.",
            "retry_after_seconds": retry_after,
        }), 429
    
    # Validate PAN format (basic check)
    if len(pan) != 10 or not pan[:5].isalpha() or not pan[5:9].isdigit() or not pan[9].isalpha():
        return jsonify({"error": "Invalid PAN format. Expected format: ABCDE1234F"}), 400
    
    # Generate consent request ID and OTP
    consent_id = generate_consent_id()
    otp = generate_otp()
    
    # Store OTP (in production, send via SMS)
    otp_storage[consent_id] = {
        "otp": otp,
        "pan": pan,
        "user_id": current_user.id,
        "mobile": mobile,
        "attempts": 0,
        "expires_at": _utcnow().timestamp() + 300  # 5 minutes
    }
    
    # In production, send OTP via SMS gateway
    print(f"[MOCK SMS] Sending OTP {otp} to {mobile}")
    
    return jsonify({
        "consent_request_id": consent_id,
        "message": f"OTP sent to {mobile}",
    }), 200

@credit_bp.route("/kyc/verify-otp", methods=["POST"])
@token_required
def verify_otp(current_user):
    """
    POST /api/credit/kyc/verify-otp
    body: { "consent_request_id": "ABC123XYZ456", "otp": "123456" }
    
    Verifies OTP and grants consent for credit report access
    """
    data = request.get_json()
    consent_id = data.get("consent_request_id")
    otp = data.get("otp")
    
    if not consent_id or not otp:
        return jsonify({"error": "consent_request_id and otp are required"}), 400

    allowed, retry_after = check_rate_limit(_rate_limit_key(current_user.id, "kyc_verify"), limit=5, window_seconds=900)
    if not allowed:
        return jsonify({
            "error": "too_many_requests",
            "message": "Too many OTP attempts. Please try again later.",
            "retry_after_seconds": retry_after,
        }), 429
    
    # Verify OTP
    stored_data = otp_storage.get(consent_id)
    
    if not stored_data:
        return jsonify({"error": "Invalid consent request ID"}), 404
    
    if stored_data["user_id"] != current_user.id:
        return jsonify({"error": "Unauthorized"}), 403
    
    if stored_data["expires_at"] < _utcnow().timestamp():
        del otp_storage[consent_id]
        return jsonify({"error": "OTP expired"}), 400
    
    stored_data["attempts"] = int(stored_data.get("attempts", 0)) + 1
    if stored_data["otp"] != otp:
        if stored_data["attempts"] >= 5:
            del otp_storage[consent_id]
            return jsonify({"error": "OTP locked due to too many invalid attempts"}), 429
        return jsonify({"error": "Invalid OTP"}), 400
    
    # OTP verified successfully
    del otp_storage[consent_id]
    
    return jsonify({
        "status": "verified",
        "message": "KYC consent granted. You can now fetch your credit report.",
        "pan": stored_data["pan"]
    }), 200

@credit_bp.route("/fetch-report", methods=["POST"])
@token_required
def fetch_credit_report(current_user):
    """
    POST /api/credit/fetch-report
    body: { "pan": "ABCDE1234F" }
    
    Fetches credit report from bureau (mock implementation)
    """
    data = request.get_json()
    pan = data.get("pan")
    
    if not pan:
        return jsonify({"error": "pan is required"}), 400
    
    db = SessionLocal()
    
    # Generate mock credit report data
    mock_loans = [
        {
            "account_type": "Personal Loan",
            "lender": "HDFC Bank",
            "current_balance": 150000,
            "emi_amount": 8500,
            "interest_rate": 10.5,
            "status": "open",
            "days_past_due": 0,
            "opened_date": "2023-01-15"
        },
        {
            "account_type": "Credit Card",
            "lender": "SBI Card",
            "current_balance": 25000,
            "emi_amount": 2000,
            "interest_rate": 36.0,
            "status": "open",
            "days_past_due": 0,
            "opened_date": "2022-06-10"
        },
        {
            "account_type": "Home Loan",
            "lender": "ICICI Bank",
            "current_balance": 2500000,
            "emi_amount": 25000,
            "interest_rate": 8.5,
            "status": "open",
            "days_past_due": 0,
            "opened_date": "2020-03-20"
        }
    ]
    
    # Save credit report snapshot
    snapshot = CreditReportSnapshot(
        user_id=current_user.id,
        bureau_name="CIBIL",
        credit_score=750,
        report_date=_utcnow(),
        raw_data={"loans": mock_loans, "pan": pan}
    )
    db.add(snapshot)
    
    # Save loans to database
    for loan_data in mock_loans:
        existing_loan = db.query(Loan).filter(
            Loan.user_id == current_user.id,
            Loan.account_type == loan_data["account_type"],
            Loan.lender == loan_data["lender"]
        ).first()
        
        if not existing_loan:
            loan = Loan(
                user_id=current_user.id,
                account_type=loan_data["account_type"],
                lender=loan_data["lender"],
                current_balance=loan_data["current_balance"],
                emi_amount=loan_data["emi_amount"],
                interest_rate=loan_data["interest_rate"],
                status=loan_data["status"],
                days_past_due=loan_data["days_past_due"],
                opened_date=datetime.fromisoformat(loan_data["opened_date"])
            )
            db.add(loan)
    
    db.commit()
    db.close()
    
    return jsonify({
        "status": "success",
        "message": "Credit report fetched successfully",
        "credit_score": 750,
        "loans_count": len(mock_loans),
        "total_outstanding": sum(l["current_balance"] for l in mock_loans),
        "total_monthly_emi": sum(l["emi_amount"] for l in mock_loans)
    }), 200

@credit_bp.route("/loans", methods=["GET"])
@token_required
def get_user_loans(current_user):
    """
    GET /api/credit/loans
    Returns normalized loans for the user
    """
    db = SessionLocal()
    
    loans = db.query(Loan).filter(Loan.user_id == current_user.id).all()
    
    result = []
    for loan in loans:
        result.append({
            "id": loan.id,
            "account_type": loan.account_type,
            "lender": loan.lender,
            "current_balance": float(loan.current_balance) if loan.current_balance else 0,
            "emi_amount": float(loan.emi_amount) if loan.emi_amount else 0,
            "interest_rate": float(loan.interest_rate) if loan.interest_rate else 0,
            "status": loan.status,
            "days_past_due": loan.days_past_due or 0,
            "opened_date": loan.opened_date.isoformat() if loan.opened_date else None
        })
    
    db.close()
    return jsonify({"loans": result, "count": len(result)})

@credit_bp.route("/summary", methods=["GET"])
@token_required
def get_credit_summary(current_user):
    """
    GET /api/credit/summary
    Returns credit summary: totals, active loans, last-updated
    """
    db = SessionLocal()
    
    loans = db.query(Loan).filter(Loan.user_id == current_user.id).all()
    
    total_outstanding = sum(float(loan.current_balance or 0) for loan in loans)
    total_emi = sum(float(loan.emi_amount or 0) for loan in loans if loan.status == 'open')
    active_loans = len([l for l in loans if l.status == 'open'])
    overdue_loans = len([l for l in loans if (l.days_past_due or 0) > 0])
    
    # Get latest credit report
    latest_report = db.query(CreditReportSnapshot).filter(
        CreditReportSnapshot.user_id == current_user.id
    ).order_by(CreditReportSnapshot.report_date.desc()).first()
    
    last_updated = latest_report.report_date if latest_report else None
    credit_score = latest_report.credit_score if latest_report else None
    
    db.close()
    
    return jsonify({
        "credit_score": credit_score,
        "total_outstanding": total_outstanding,
        "total_monthly_emi": total_emi,
        "active_loans": active_loans,
        "overdue_loans": overdue_loans,
        "last_updated": last_updated.isoformat() if last_updated else None
    })
