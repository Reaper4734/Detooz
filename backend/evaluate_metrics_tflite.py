import os
import sys
import pandas as pd
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from transformers import MobileBertTokenizerFast

# Force UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

# Config
BASE_DIR = os.getcwd()
# Adjust paths assuming script is run from backend/
DATA_FILE = os.path.join(BASE_DIR, "ml_pipeline", "final_training_set.csv")
# Placeholder if not found, we will check existence
SYNTHETIC_FILE = os.path.join(BASE_DIR, "ml_pipeline", "clean_training_set.csv") # Use clean set as fallback or search
MODEL_DIR = os.path.join(BASE_DIR, "ml_pipeline", "saved_model")
TFLITE_FILE = os.path.join(BASE_DIR, "ml_pipeline", "scam_detector.tflite")

BATCH_SIZE = 1 # TFLite is usually batch 1 or need resize

def evaluate_model_tflite():
    print("[INFO] Starting Comprehensive TFLite Model Evaluation...")
    
    # 1. Load Data
    if not os.path.exists(DATA_FILE):
        print(f"[ERROR] Data file {DATA_FILE} not found.")
        return

    df = pd.read_csv(DATA_FILE)
    print(f"   Loaded {len(df)} base samples.")
    
    # Re-merge Synthetic if needed
    if os.path.exists(SYNTHETIC_FILE):
        syn_df = pd.read_csv(SYNTHETIC_FILE)
        # Replicate the boost factor from train.py (5x)
        syn_df = pd.concat([syn_df] * 5, ignore_index=True) 
        df = pd.concat([df, syn_df], ignore_index=True)
        print(f"   Re-merged {len(syn_df)} synthetic samples. Total: {len(df)}")
    
    # Label Map
    label_map = {"ham": 0, "otp": 1, "scam": 2}
    df['label'] = df['type'].map(label_map)
    df = df.dropna(subset=['label'])
    df['label'] = df['label'].astype(int)
    
    # Reconstruct Split
    print("   ✂️ Reconstructing Train/Test Split (Random State 42)...")
    _, val_df = train_test_split(df, test_size=0.1, random_state=42)
    # Limit to 2000 samples for speed
    val_df = val_df.head(2000)
    print(f"   🧪 Validation Set Size: {len(val_df)} samples (Subset for speed)")

    # 2. Load Resources
    print(f"   🧠 Loading Resources...")
    try:
        tokenizer = MobileBertTokenizerFast.from_pretrained(MODEL_DIR)
        interpreter = tf.lite.Interpreter(model_path=TFLITE_FILE)
        interpreter.allocate_tensors()
    except Exception as e:
        print(f"[ERROR] Failed to load resources: {e}")
        return

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # Determine input type
    input_indices = {d['name']: d['index'] for d in input_details}
    use_attention_mask = len(input_details) > 1

    # 3. Inference
    print("   ⚡ Running Inference on Validation Set...")
    
    val_df['text'] = val_df['text'].astype(str)
    texts = val_df['text'].tolist()
    true_labels = val_df['label'].tolist()
    
    pred_labels = []
    
    total = len(texts)
    
    for i, text in enumerate(texts):
        # Tokenize
        inputs = tokenizer(text, return_tensors="np", max_length=128, truncation=True, padding="max_length")
        input_ids = inputs['input_ids'].astype(np.int32)
        attention_mask = inputs['attention_mask'].astype(np.int32)
        
        # Set Tensor
        interpreter.set_tensor(input_details[0]['index'], input_ids)
        if use_attention_mask:
            interpreter.set_tensor(input_details[1]['index'], attention_mask)
            
        interpreter.invoke()
        
        logits = interpreter.get_tensor(output_details[0]['index'])[0]
        pred_idx = np.argmax(logits)
        pred_labels.append(pred_idx)
        
        if i % 100 == 0:
            print(f"      Processed {i}/{total}...", end='\r')

    print(f"      Processed {total}/{total} (Done)")

    # 4. Metrics
    print("\n" + "="*40)
    print("📈 EVALUATION RESULTS (TFLite)")
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
    
    with open("tflite_evaluation_report.txt", "w", encoding="utf-8") as f:
        f.write(output_text)

if __name__ == "__main__":
    evaluate_model_tflite()
