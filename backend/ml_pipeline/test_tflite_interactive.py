
import tensorflow as tf
import numpy as np
import os
from transformers import MobileBertTokenizerFast

BASE_DIR = r"C:\CP\plans\Detooz\backend"
MODEL_DIR = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "saved_model")
TFLITE_FILE = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "scam_detector.tflite")

def run_interactive_test():
    print("🚀 Loading TFLite Model...")
    
    if not os.path.exists(TFLITE_FILE):
        print(f"❌ TFLite model not found at {TFLITE_FILE}")
        return

    # Load Tokenizer for preprocessing
    tokenizer = MobileBertTokenizerFast.from_pretrained(MODEL_DIR)
    
    # Load TFLite
    interpreter = tf.lite.Interpreter(model_path=TFLITE_FILE)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    labels = ["HAM (Safe)", "OTP (Sensitive)", "SCAM (Danger)"]
    
    print("\n✅ Model Ready! Type a message to check (or 'q' to quit).")
    print("-" * 60)
    
    while True:
        try:
            text = input("\n📝 Enter Message: ").strip()
            if text.lower() in ['q', 'quit', 'exit']:
                break
            if not text: continue
            
            # Tokenize
            inputs = tokenizer(text, return_tensors="np", max_length=128, truncation=True, padding="max_length")
            
            input_ids = inputs['input_ids'].astype(np.int32)
            attention_mask = inputs['attention_mask'].astype(np.int32)
            
            # Inference
            interpreter.set_tensor(input_details[0]['index'], input_ids)
            interpreter.set_tensor(input_details[1]['index'], attention_mask)
            interpreter.invoke()
            
            logits = interpreter.get_tensor(output_details[0]['index'])[0]
            
            # Softmax
            exp_logits = np.exp(logits - np.max(logits))
            probs = exp_logits / exp_logits.sum()
            
            pred_idx = np.argmax(probs)
            confidence = probs[pred_idx] * 100
            
            print(f"🤖 Prediction: {labels[pred_idx]}")
            print(f"📊 Confidence: {confidence:.2f}%")
            print(f"   (Logits: {logits})")
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"❌ Error: {e}")

    print("\nExiting...")

if __name__ == "__main__":
    run_interactive_test()
