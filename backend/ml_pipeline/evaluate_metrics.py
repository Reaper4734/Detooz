
import os
import pandas as pd
import torch
import torch.nn.functional as F
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from transformers import MobileBertTokenizerFast, MobileBertForSequenceClassification
from datasets import Dataset

# Config (Must match train.py)
# Using Absolute Paths to avoid CWD issues
BASE_DIR = r"C:\CP\plans\Detooz\backend"
DATA_FILE = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "final_training_set.csv")
SYNTHETIC_FILE = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "raw_data", "synthetic_augment.csv")
MODEL_PATH = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "saved_model")
BATCH_SIZE = 32

def evaluate_model():
    print("📊 Starting Comprehensive Model Evaluation...")
    
    # 1. Load Data (Replicate Train Logic to isolate Validation Set)
    if not os.path.exists(DATA_FILE):
        print(f"❌ Data file {DATA_FILE} not found.")
        return

    df = pd.read_csv(DATA_FILE)
    print(f"   Loaded {len(df)} base samples.")
    
    # Re-merge Synthetic if train.py did it (Crucial for correct split reconstruction)
    # train.py Logic:
    if os.path.exists(SYNTHETIC_FILE):
        syn_df = pd.read_csv(SYNTHETIC_FILE)
        syn_df = pd.concat([syn_df] * 5, ignore_index=True) 
        df = pd.concat([df, syn_df], ignore_index=True)
        print(f"   Re-merged {len(syn_df)} synthetic samples (Boosted 5x). Total: {len(df)}")
    
    # Label Map
    label_map = {"ham": 0, "otp": 1, "scam": 2}
    df['label'] = df['type'].map(label_map)
    df = df.dropna(subset=['label'])
    df['label'] = df['label'].astype(int)
    
    # Reconstruct Split
    print("   ✂️ Reconstructing Train/Test Split (Random State 42)...")
    _, val_df = train_test_split(df, test_size=0.1, random_state=42)
    print(f"   🧪 Validation Set Size: {len(val_df)} samples")

    # 2. Load Model
    print(f"   🧠 Loading Model from {MODEL_PATH}...")
    try:
        tokenizer = MobileBertTokenizerFast.from_pretrained(MODEL_PATH)
        model = MobileBertForSequenceClassification.from_pretrained(MODEL_PATH)
        device = "cuda" if torch.cuda.is_available() else "cpu"
        model.to(device)
        model.eval()
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return

    # 3. Inference
    print("   ⚡ Running Inference on Validation Set...")
    
    # Pre-tokenize
    val_df['text'] = val_df['text'].astype(str)
    texts = val_df['text'].tolist()
    true_labels = val_df['label'].tolist()
    
    pred_labels = []
    
    # Batch Inference
    for i in range(0, len(texts), BATCH_SIZE):
        batch_texts = texts[i : i + BATCH_SIZE]
        inputs = tokenizer(batch_texts, padding=True, truncation=True, max_length=128, return_tensors="pt").to(device)
        
        with torch.no_grad():
            outputs = model(**inputs)
            preds = torch.argmax(outputs.logits, dim=1).cpu().numpy()
            pred_labels.extend(preds)
            
        if i % (BATCH_SIZE * 10) == 0:
            print(f"      Processed {i}/{len(texts)}...")

    # 4. Metrics
    print("\n" + "="*40)
    print("📈 EVALUATION RESULTS")
    print("="*40)
    
    acc = accuracy_score(true_labels, pred_labels)
    
    target_names = ["HAM", "OTP", "SCAM"]
    report = classification_report(true_labels, pred_labels, target_names=target_names)
    cm = confusion_matrix(true_labels, pred_labels)
    
    output_text = f"✅ Accuracy: {acc:.4f} ({acc*100:.2f}%)\n\n"
    output_text += "📋 Classification Report:\n"
    output_text += report + "\n\n"
    output_text += "😵 Confusion Matrix:\n"
    output_text += f"{'True/Pred':<10} {'HAM':<8} {'OTP':<8} {'SCAM':<8}\n"
    for i, label in enumerate(target_names):
        output_text += f"{label:<10} {cm[i][0]:<8} {cm[i][1]:<8} {cm[i][2]:<8}\n"

    print(output_text)
    
    # Save to file
    report_path = os.path.join(BASE_DIR, "ml_pipeline", "evaluation_report.txt")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(output_text)
    print(f"\n📝 Report saved to {report_path}")

if __name__ == "__main__":
    evaluate_model()
