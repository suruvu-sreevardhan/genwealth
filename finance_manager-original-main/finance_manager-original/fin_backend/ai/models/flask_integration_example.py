
# Example Flask integration

from ml_inference import predict_category

def fallback_categorize(txn):
    if not txn.get("category"):
        try:
            result = predict_category(
                merchant=txn.get("merchant",""),
                notes=txn.get("notes",""),
                txn_type=txn.get("type",""),
                amount=float(txn.get("amount",0))
            )
            txn["category"] = result["predicted_category"]
        except Exception:
            txn["category"] = "uncategorized"

    return txn
