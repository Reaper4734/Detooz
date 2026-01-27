
import os
import shutil
from transformers import MobileBertTokenizerFast

BASE_DIR = r"C:\CP\plans\Detooz\backend"
CHECKPOINT_DIR = os.path.join(BASE_DIR, "results", "checkpoint-4440")
TARGET_DIR = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "saved_model")

def restore_model():
    print(f"🔧 Restoring model from {CHECKPOINT_DIR} to {TARGET_DIR}...")
    
    # 1. Verify Checkpoint
    if not os.path.exists(CHECKPOINT_DIR):
        print(f"❌ Checkpoint not found at {CHECKPOINT_DIR}")
        return

    # 2. Create Target Dir
    os.makedirs(TARGET_DIR, exist_ok=True)
    
    # 3. Copy Checkpoint Files
    files_to_copy = ["config.json", "model.safetensors", "training_args.bin"]
    for fname in files_to_copy:
        src = os.path.join(CHECKPOINT_DIR, fname)
        dst = os.path.join(TARGET_DIR, fname)
        if os.path.exists(src):
            shutil.copy2(src, dst)
            print(f"   ✅ Copied {fname}")
        else:
            print(f"   ⚠️ Warning: {fname} not found in checkpoint.")

    # 4. Restore Tokenizer (Download from Hub if missing)
    print("   ⬇️ Downloading/Saving Tokenizer...")
    try:
        tokenizer = MobileBertTokenizerFast.from_pretrained("google/mobilebert-uncased")
        tokenizer.save_pretrained(TARGET_DIR)
        print("   ✅ Tokenizer saved successfully.")
    except Exception as e:
        print(f"   ❌ Failed to save tokenizer: {e}")

    print("\n✅ Restoration Complete.")

if __name__ == "__main__":
    restore_model()
