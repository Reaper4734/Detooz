"""
Training Script
Fine-tunes DistilBERT for SMS Scam Detection.
optimized for local GPU (RTX 4050).
"""
import os
import pandas as pd
import torch
from sklearn.model_selection import train_test_split
from transformers import MobileBertTokenizerFast, MobileBertForSequenceClassification, Trainer, TrainingArguments
from datasets import Dataset

# Config
DATA_FILE = "ml_pipeline/clean_training_set.csv"
MODEL_NAME = "google/mobilebert-uncased" # Best for Android (Small & Fast)
OUTPUT_DIR = "ml_pipeline/saved_model"

def train_model():
    print("🚀 Starting Training Pipeline...")
    
    # 1. Load Data
    if not os.path.exists(DATA_FILE):
        print(f"❌ Data file not found: {DATA_FILE}. Run pipeline.py first.")
        return

    df = pd.read_csv(DATA_FILE)
    print(f"   📊 Loaded {len(df)} samples.")
    
    # Label Map: SCAM=1, HAM=0, OTP=0 (User wants to block Scams, verify OTPs locally)
    # Actually, let's do Multi-Class? 
    # Decision: Binary (Safe vs UNSAFE) is better for blocking.
    # But User wants to distinguish OTP.
    # Let's map: ham->0, otp->1, scam->2
    
    label_map = {"ham": 0, "otp": 1, "scam": 2}
    df['label'] = df['type'].map(label_map)
    
    # Drop unknown
    df = df.dropna(subset=['label'])
    df['label'] = df['label'].astype(int)
    
    # Split
    train_df, val_df = train_test_split(df, test_size=0.1, random_state=42)
    
    train_dataset = Dataset.from_pandas(train_df[['text', 'label']])
    val_dataset = Dataset.from_pandas(val_df[['text', 'label']])
    
    # 2. Tokenize
    print("   🔠 Tokenizing...")
    tokenizer = MobileBertTokenizerFast.from_pretrained(MODEL_NAME)
    
    def tokenize_function(examples):
        return tokenizer(examples["text"], padding="max_length", truncation=True, max_length=128)
        
    train_tokenized = train_dataset.map(tokenize_function, batched=True)
    val_tokenized = val_dataset.map(tokenize_function, batched=True)
    
    # 3. Setup Model
    print("   🧠 Loading Model (MobileBERT)...")
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"      Using Device: {device.upper()}")
    
    model = MobileBertForSequenceClassification.from_pretrained(
        MODEL_NAME, num_labels=3
    ).to(device)
    
    # 4. Train
    training_args = TrainingArguments(
        output_dir="./results",
        num_train_epochs=2,              # Quick training for demo
        per_device_train_batch_size=16,  # 6GB VRAM can handle 16-32
        per_device_eval_batch_size=64,
        warmup_steps=500,
        weight_decay=0.01,
        logging_steps=100,
        eval_strategy="steps",
        save_strategy="epoch"
    )
    
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_tokenized,
        eval_dataset=val_tokenized,
    )
    
    print("   🏋️ Training Started...")
    trainer.train()
    
    # 5. Save
    print(f"   💾 Saving to {OUTPUT_DIR}...")
    model.save_pretrained(OUTPUT_DIR)
    tokenizer.save_pretrained(OUTPUT_DIR)
    print("✅ Model Saved Successfully.")

if __name__ == "__main__":
    train_model()
