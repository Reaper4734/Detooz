
import torch
import torch.nn.functional as F
from transformers import MobileBertTokenizerFast, MobileBertForSequenceClassification

MODEL_PATH = "ml_pipeline/saved_model"

def test_model():
    print(f"🔄 Loading Model from {MODEL_PATH}...")
    try:
        tokenizer = MobileBertTokenizerFast.from_pretrained(MODEL_PATH)
        model = MobileBertForSequenceClassification.from_pretrained(MODEL_PATH)
        model.eval()
        
        # Move to GPU if available
        device = "cuda" if torch.cuda.is_available() else "cpu"
        model.to(device)
        print(f"✅ Model Loaded on {device.upper()}")
        
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return

    # Standard Label Map (Must match training!)
    # 0=ham, 1=otp, 2=scam
    id2label = {0: "HAM (Safe)", 1: "OTP (Sensitive)", 2: "SCAM (Danger)"}

    test_cases = [
        "Hey, are we still meeting for dinner tonight?",
        "Your SBI Bank KYC is expired. Update immediately at http://bit.ly/sbi-kyc",
        "Your OTP for payment of Rs 5000 is 883920. Do not share with anyone.",
        "CONGRATS! You won a iPhone 15. Call now 999-888-777 to claim.",
        "Mom I am in hospital need money urgent please transfer 5000",
        "Dear customer, your electricity connection will be disconnected tonight. Call officer 9876543210."
    ]

    print("\n🧐 Running Diagnostics...")
    print("-" * 60)
    print(f"{'MESSAGE':<50} | {'PREDICTION':<15} | {'CONFIDENCE'}")
    print("-" * 60)

    for text in test_cases:
        inputs = tokenizer(text, return_tensors="pt", truncation=True, padding=True).to(device)
        
        with torch.no_grad():
            outputs = model(**inputs)
            probs = F.softmax(outputs.logits, dim=1)
            confidence, predicted_class = torch.max(probs, dim=1)
            
        label = id2label[predicted_class.item()]
        score = confidence.item() * 100
        
        # Color output
        print(f"{text[:47]+'...':<50} | {label:<15} | {score:.2f}%")

    print("-" * 60)
    print("✅ Diagnostics Complete.")

if __name__ == "__main__":
    test_model()
