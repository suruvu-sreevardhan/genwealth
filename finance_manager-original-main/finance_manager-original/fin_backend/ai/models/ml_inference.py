
import os, re, joblib

MODEL_PATH = "category_model.joblib"

normalization_dict = {
    "swigy":"swiggy",
    "swigy":"swiggy",
    "zomto":"zomato",
    "ubre":"uber",
    "amazn":"amazon",
    "flipkrt":"flipkart"
}

def clean_text(x):
    if x is None:
        x = ""
    x = str(x).lower().strip()
    x = re.sub(r"\s+", " ", x)
    for k,v in normalization_dict.items():
        x = x.replace(k,v)
    return x

def rule_based(merchant):
    m = clean_text(merchant)
    if "swiggy" in m or "zomato" in m:
        return "food"
    if "uber" in m or "ola" in m:
        return "transport"
    if "amazon" in m or "flipkart" in m:
        return "shopping"
    return "uncategorized"

def load_model(path=MODEL_PATH):
    if os.path.exists(path):
        return joblib.load(path)
    return None

def predict_category(merchant:str, notes:str, txn_type:str="", amount:float=0.0):
    model = load_model()
    txt = f"{clean_text(merchant)} {clean_text(notes)} {clean_text(txn_type)}"

    if amount <= 100:
        bucket="a"
    elif amount <= 500:
        bucket="b"
    elif amount <= 1000:
        bucket="c"
    elif amount <= 5000:
        bucket="d"
    elif amount <= 10000:
        bucket="e"
    else:
        bucket="f"

    txt += " amt_" + bucket

    if model is None:
        return {"predicted_category": rule_based(merchant), "confidence": None}

    pred = model.predict([txt])[0]

    confidence = None
    if hasattr(model[-1], "decision_function"):
        confidence = 0.90
    elif hasattr(model[-1], "predict_proba"):
        confidence = float(max(model.predict_proba([txt])[0]))

    return {"predicted_category": pred, "confidence": confidence}
