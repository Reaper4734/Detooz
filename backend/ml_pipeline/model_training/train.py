"""
Training Script v3.0 - Production Grade
========================================
Fine-tunes MobileBERT for SMS Scam Detection with:
- Class Weights (OTP Boost)
- Stratified K-Fold Cross-Validation
- Cosine Learning Rate Scheduler
- Data Augmentation

User-Friendly Monitoring: Clear progress bars and status messages.
"""
import os
import sys
import random
import numpy as np
import pandas as pd
import torch
from datetime import datetime

# Fix Windows encoding for emojis
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')
from sklearn.model_selection import StratifiedKFold, train_test_split
from sklearn.metrics import accuracy_score, precision_recall_fscore_support, confusion_matrix, classification_report
from transformers import (
    MobileBertTokenizerFast, 
    MobileBertForSequenceClassification, 
    Trainer, 
    TrainingArguments,
    EarlyStoppingCallback
)
from datasets import Dataset
import matplotlib.pyplot as plt
import seaborn as sns

# ============================================
# CONFIGURATION
# ============================================
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA_FILE = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "final_training_set.csv")
SYNTHETIC_FILE = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "raw_data", "synthetic_augment.csv")
MODEL_NAME = "google/mobilebert-uncased"
OUTPUT_DIR = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "saved_model")

LABEL_NAMES = ["ham", "otp", "scam"]
CLASS_WEIGHTS = {0: 1.0, 1: 5.0, 2: 1.5}  # Boost OTP
N_FOLDS = 5
EPOCHS = 3

# ============================================
# USER-FRIENDLY DISPLAY HELPERS
# ============================================
def print_header(text):
    print("\n" + "=" * 60)
    print(f"  {text}")
    print("=" * 60)

def print_step(step_num, total_steps, text):
    bar_len = 20
    filled = int(bar_len * step_num / total_steps)
    bar = "█" * filled + "░" * (bar_len - filled)
    print(f"\n[{bar}] Step {step_num}/{total_steps}: {text}")

def print_progress(current, total, prefix="Progress"):
    pct = current / total * 100
    bar_len = 30
    filled = int(bar_len * current / total)
    bar = "█" * filled + "░" * (bar_len - filled)
    print(f"\r  {prefix}: [{bar}] {pct:.1f}% ({current}/{total})", end="", flush=True)

def print_metric(name, value, good_threshold=0.9):
    icon = "✅" if value >= good_threshold else "⚠️"
    print(f"  {icon} {name}: {value:.4f}")

def print_box(title, content_dict):
    print(f"\n┌{'─' * 40}┐")
    print(f"│ {title:^38} │")
    print(f"├{'─' * 40}┤")
    for k, v in content_dict.items():
        print(f"│ {k:<20} {str(v):>17} │")
    print(f"└{'─' * 40}┘")

# ============================================
# DATA AUGMENTATION
# ============================================
def augment_text(text, aug_prob=0.15):
    """Simple data augmentation: random word deletion."""
    # Handle NaN or non-string values
    if not isinstance(text, str):
        return str(text) if text else ""
    
    words = text.split()
    if len(words) <= 3:
        return text
    
    # Random word deletion
    new_words = [w for w in words if random.random() > aug_prob]
    
    if len(new_words) == 0:
        return text
    
    return " ".join(new_words)

def apply_augmentation(df, aug_ratio=0.3):
    """Apply augmentation to a portion of the dataset."""
    aug_df = df.sample(frac=aug_ratio, random_state=42).copy()
    aug_df['text'] = aug_df['text'].apply(augment_text)
    return pd.concat([df, aug_df], ignore_index=True)

# ============================================
# METRICS COMPUTATION
# ============================================
def compute_metrics(eval_pred):
    predictions, labels = eval_pred
    predictions = np.argmax(predictions, axis=1)
    
    precision, recall, f1, _ = precision_recall_fscore_support(labels, predictions, average='weighted')
    acc = accuracy_score(labels, predictions)
    
    return {
        'accuracy': acc,
        'f1': f1,
        'precision': precision,
        'recall': recall
    }

# ============================================
# CUSTOM TRAINER WITH CLASS WEIGHTS
# ============================================
class WeightedTrainer(Trainer):
    def __init__(self, class_weights, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.class_weights = torch.tensor(
            [class_weights[i] for i in range(len(class_weights))],
            dtype=torch.float32
        ).to(self.args.device)
    
    def compute_loss(self, model, inputs, return_outputs=False, **kwargs):
        labels = inputs.pop("labels")
        outputs = model(**inputs)
        logits = outputs.logits
        
        loss_fn = torch.nn.CrossEntropyLoss(weight=self.class_weights)
        loss = loss_fn(logits, labels)
        
        return (loss, outputs) if return_outputs else loss

# ============================================
# MAIN TRAINING FUNCTION
# ============================================
def train_model():
    start_time = datetime.now()
    
    print_header("🚀 TRAINING PIPELINE v3.0 (Production Grade)")
    print(f"  Started: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    total_steps = 8
    
    # ─────────────────────────────────────────
    # STEP 1: LOAD DATA
    # ─────────────────────────────────────────
    print_step(1, total_steps, "Loading Datasets")
    
    if not os.path.exists(DATA_FILE):
        print(f"  ❌ ERROR: Base data not found: {DATA_FILE}")
        return
    
    df = pd.read_csv(DATA_FILE)
    print(f"  📁 Clean Dataset: {len(df):,} samples")
    
    if os.path.exists(SYNTHETIC_FILE):
        syn_df = pd.read_csv(SYNTHETIC_FILE)
        df = pd.concat([df, syn_df], ignore_index=True)
        print(f"  📁 Synthetic Dataset: {len(syn_df):,} samples")
        print(f"  📊 Combined Total: {len(df):,} samples")
    
    # ─────────────────────────────────────────
    # STEP 2: LABEL MAPPING
    # ─────────────────────────────────────────
    print_step(2, total_steps, "Preparing Labels")
    
    label_map = {"ham": 0, "otp": 1, "scam": 2}
    df['label'] = df['type'].map(label_map)
    df = df.dropna(subset=['label'])
    df['label'] = df['label'].astype(int)
    
    class_dist = df['label'].value_counts().to_dict()
    print_box("Class Distribution", {
        "Ham (Safe)": f"{class_dist.get(0, 0):,}",
        "OTP": f"{class_dist.get(1, 0):,}",
        "Scam": f"{class_dist.get(2, 0):,}"
    })
    
    # ─────────────────────────────────────────
    # STEP 3: DATA AUGMENTATION
    # ─────────────────────────────────────────
    print_step(3, total_steps, "Applying Data Augmentation")
    
    original_len = len(df)
    df = apply_augmentation(df, aug_ratio=0.3)
    print(f"  📈 Augmented: {original_len:,} → {len(df):,} samples (+{len(df)-original_len:,})")
    
    # ─────────────────────────────────────────
    # STEP 4: TOKENIZER SETUP
    # ─────────────────────────────────────────
    print_step(4, total_steps, "Loading Tokenizer")
    
    tokenizer = MobileBertTokenizerFast.from_pretrained(MODEL_NAME)
    print(f"  ✅ Tokenizer: {MODEL_NAME}")
    
    def tokenize_function(examples):
        return tokenizer(examples["text"], padding="max_length", truncation=True, max_length=192)
    
    # ─────────────────────────────────────────
    # STEP 5: GPU CHECK
    # ─────────────────────────────────────────
    print_step(5, total_steps, "Checking GPU")
    
    device = "cuda" if torch.cuda.is_available() else "cpu"
    
    gpu_info = {"Device": device.upper()}
    if device == "cuda":
        gpu_info["GPU Name"] = torch.cuda.get_device_name(0)
        gpu_info["VRAM"] = f"{torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB"
    
    print_box("Hardware", gpu_info)
    
    # ─────────────────────────────────────────
    # STEP 6: K-FOLD CROSS-VALIDATION
    # ─────────────────────────────────────────
    print_step(6, total_steps, f"Training with {N_FOLDS}-Fold Cross-Validation")
    
    skf = StratifiedKFold(n_splits=N_FOLDS, shuffle=True, random_state=42)
    
    fold_metrics = []
    best_model = None
    best_f1 = 0
    
    X = df[['text', 'label']].reset_index(drop=True)
    y = df['label'].values
    
    for fold, (train_idx, val_idx) in enumerate(skf.split(X, y)):
        print(f"\n  ┌─ Fold {fold + 1}/{N_FOLDS} ─────────────────────────────────┐")
        
        train_df = X.iloc[train_idx].copy()
        val_df = X.iloc[val_idx].copy()
        
        # Ensure text column is string type
        train_df['text'] = train_df['text'].astype(str)
        val_df['text'] = val_df['text'].astype(str)
        
        train_dataset = Dataset.from_dict({'text': train_df['text'].tolist(), 'label': train_df['label'].tolist()})
        val_dataset = Dataset.from_dict({'text': val_df['text'].tolist(), 'label': val_df['label'].tolist()})
        
        print(f"  │ Train: {len(train_df):,} | Validation: {len(val_df):,}")
        
        # Tokenize
        train_tokenized = train_dataset.map(tokenize_function, batched=True)
        val_tokenized = val_dataset.map(tokenize_function, batched=True)
        
        # Load fresh model for each fold
        model = MobileBertForSequenceClassification.from_pretrained(
            MODEL_NAME, num_labels=3
        ).to(device)
        
        # Training arguments
        training_args = TrainingArguments(
            output_dir=f"./results/fold_{fold}",
            num_train_epochs=EPOCHS,
            per_device_train_batch_size=32,      # Reduced from 64 for faster training
            per_device_eval_batch_size=64,       # Reduced from 128
            gradient_accumulation_steps=2,
            warmup_steps=300,                    # Reduced for faster warmup
            weight_decay=0.01,
            learning_rate=2e-5,
            lr_scheduler_type="cosine",
            logging_steps=50,                    # More frequent logging
            eval_strategy="epoch",
            save_strategy="epoch",
            load_best_model_at_end=True,
            metric_for_best_model="f1",
            greater_is_better=True,
            fp16=False,
            dataloader_num_workers=0,            # Reduced to avoid overhead
            report_to="none",
            disable_tqdm=False
        )
        
        # Trainer with class weights
        trainer = WeightedTrainer(
            class_weights=CLASS_WEIGHTS,
            model=model,
            args=training_args,
            train_dataset=train_tokenized,
            eval_dataset=val_tokenized,
            compute_metrics=compute_metrics,
            callbacks=[EarlyStoppingCallback(early_stopping_patience=2)]
        )
        
        # Train
        trainer.train()
        
        # Evaluate fold
        results = trainer.evaluate()
        fold_metrics.append(results)
        
        print(f"  │ Results:")
        print(f"  │   Accuracy:  {results['eval_accuracy']:.4f}")
        print(f"  │   F1-Score:  {results['eval_f1']:.4f}")
        print(f"  │   Precision: {results['eval_precision']:.4f}")
        print(f"  │   Recall:    {results['eval_recall']:.4f}")
        print(f"  └─────────────────────────────────────────────┘")
        
        # Track best model
        if results['eval_f1'] > best_f1:
            best_f1 = results['eval_f1']
            best_model = model
            best_trainer = trainer
            best_val_tokenized = val_tokenized
    
    # ─────────────────────────────────────────
    # STEP 7: AGGREGATE METRICS
    # ─────────────────────────────────────────
    print_step(7, total_steps, "Calculating Final Metrics")
    
    avg_metrics = {
        "Accuracy": np.mean([m['eval_accuracy'] for m in fold_metrics]),
        "F1-Score": np.mean([m['eval_f1'] for m in fold_metrics]),
        "Precision": np.mean([m['eval_precision'] for m in fold_metrics]),
        "Recall": np.mean([m['eval_recall'] for m in fold_metrics])
    }
    
    std_metrics = {
        "Accuracy ±": np.std([m['eval_accuracy'] for m in fold_metrics]),
        "F1-Score ±": np.std([m['eval_f1'] for m in fold_metrics])
    }
    
    print_box("Average Metrics (5-Fold)", {k: f"{v:.4f}" for k, v in avg_metrics.items()})
    print(f"\n  Standard Deviation: F1 ± {std_metrics['F1-Score ±']:.4f}")
    
    # ─────────────────────────────────────────
    # STEP 8: SAVE BEST MODEL
    # ─────────────────────────────────────────
    print_step(8, total_steps, "Saving Best Model")
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    best_model.save_pretrained(OUTPUT_DIR)
    tokenizer.save_pretrained(OUTPUT_DIR)
    
    # Generate confusion matrix for best model
    predictions = best_trainer.predict(best_val_tokenized)
    preds = np.argmax(predictions.predictions, axis=1)
    labels = predictions.label_ids
    
    cm = confusion_matrix(labels, preds)
    
    # Save confusion matrix image
    plt.figure(figsize=(8, 6))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
                xticklabels=LABEL_NAMES, yticklabels=LABEL_NAMES)
    plt.xlabel('Predicted')
    plt.ylabel('Actual')
    plt.title('Confusion Matrix (Best Fold)')
    cm_path = os.path.join(OUTPUT_DIR, "confusion_matrix.png")
    plt.savefig(cm_path, dpi=150, bbox_inches='tight')
    plt.close()
    
    # Save metrics report
    report = classification_report(labels, preds, target_names=LABEL_NAMES)
    metrics_path = os.path.join(OUTPUT_DIR, "training_metrics.txt")
    with open(metrics_path, 'w') as f:
        f.write("=" * 50 + "\n")
        f.write("TRAINING METRICS REPORT\n")
        f.write("=" * 50 + "\n\n")
        f.write(f"Training Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Model: {MODEL_NAME}\n")
        f.write(f"Folds: {N_FOLDS}\n")
        f.write(f"Epochs per Fold: {EPOCHS}\n\n")
        f.write("Average Metrics (5-Fold):\n")
        for k, v in avg_metrics.items():
            f.write(f"  {k}: {v:.4f}\n")
        f.write("\n" + "=" * 50 + "\n")
        f.write("Classification Report (Best Fold):\n")
        f.write("=" * 50 + "\n")
        f.write(report)
    
    # ─────────────────────────────────────────
    # COMPLETE
    # ─────────────────────────────────────────
    end_time = datetime.now()
    duration = end_time - start_time
    
    print_header("✅ TRAINING COMPLETE!")
    
    print_box("Summary", {
        "Total Time": str(duration).split('.')[0],
        "Best F1": f"{best_f1:.4f}",
        "Model Saved": OUTPUT_DIR.split("\\")[-1]
    })
    
    print(f"\n  📁 Output Files:")
    print(f"     • {OUTPUT_DIR}/model.safetensors")
    print(f"     • {OUTPUT_DIR}/confusion_matrix.png")
    print(f"     • {OUTPUT_DIR}/training_metrics.txt")
    
    print("\n" + "=" * 60)
    print("  🎉 Your model is ready for deployment!")
    print("=" * 60 + "\n")

if __name__ == "__main__":
    train_model()
