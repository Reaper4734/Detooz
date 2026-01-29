
import tensorflow as tf
import torch
import numpy as np
import os
import time
from transformers import MobileBertTokenizerFast, MobileBertForSequenceClassification
from sklearn.metrics import accuracy_score

BASE_DIR = r"C:\CP\plans\Detooz\backend"
MODEL_DIR = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "saved_model")
TFLITE_FILE = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "scam_detector.tflite")
TEST_TEXTS = [
    "Your account has been compromised. Click here to reset password.",
    "Hey fast pay the electricity bill otherwise connection cut.",
    "Your OTP is 123456. Do not share this with anyone.",
    "Mom, I'm in the hospital. Please send money.",
    "Your Jio plan is expiring tomorrow. Recharge now.",
    "Congratulations! You won a lottery of $1M. Claim now!"
]

def load_pytorch_model():
    print("🧠 Loading PyTorch Model...")
    tokenizer = MobileBertTokenizerFast.from_pretrained(MODEL_DIR)
    model = MobileBertForSequenceClassification.from_pretrained(MODEL_DIR)
    model.eval()
    return tokenizer, model

def run_tflite_inference(interpreter, input_ids, attention_mask):
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    interpreter.set_tensor(input_details[0]['index'], input_ids)
    interpreter.set_tensor(input_details[1]['index'], attention_mask)
    
    interpreter.invoke()
    
    output_data = interpreter.get_tensor(output_details[0]['index'])
    return output_data

def validate_conversion():
    print("🚀 Starting TFLite Validation...")
    
    # 1. Load PyTorch
    pt_tokenizer, pt_model = load_pytorch_model()
    
    # 2. Load TFLite
    if not os.path.exists(TFLITE_FILE):
        print(f"❌ TFLite model not found at {TFLITE_FILE}")
        return

    print("🧠 Loading TFLite Model...")
    interpreter = tf.lite.Interpreter(model_path=TFLITE_FILE)
    interpreter.allocate_tensors()
    
    print("\n🧐 Comparing Predictions...\n")
    print(f"{'Text':<50} | {'PyTorch':<10} | {'TFLite':<10} | {'Match':<5}")
    print("-" * 90)
    
    match_count = 0
    
    for text in TEST_TEXTS:
        # PyTorch Inference
        inputs = pt_tokenizer(text, return_tensors="pt", max_length=128, truncation=True, padding="max_length")
        with torch.no_grad():
            pt_logits = pt_model(**inputs).logits.numpy()
            pt_pred = np.argmax(pt_logits)
            
        # TFLite Inference
        # Note: TFLite input shape is usually fixed [1, 128], ensuring standard numpy types
        tf_input_ids = inputs['input_ids'].numpy().astype(np.int32)
        tf_attention_mask = inputs['attention_mask'].numpy().astype(np.int32)
        
        tf_logits = run_tflite_inference(interpreter, tf_input_ids, tf_attention_mask)
        tf_pred = np.argmax(tf_logits)
        
        match = "✅" if pt_pred == tf_pred else "❌"
        if pt_pred == tf_pred: match_count += 1
        
        display_text = (text[:47] + '..') if len(text) > 47 else text
        labels = ["HAM", "OTP", "SCAM"]
        
        print(f"{display_text:<50} | {labels[pt_pred]:<10} | {labels[tf_pred]:<10} | {match}")

    print("-" * 90)
    print(f"✅ Agreement: {match_count}/{len(TEST_TEXTS)} ({match_count/len(TEST_TEXTS)*100:.1f}%)")
    
    if match_count == len(TEST_TEXTS):
        print("\n🎉 Validation Passed! TFLite model is ready for deployment.")
    else:
        print("\n⚠️ Validation Warning: Output mismatch detected.")

if __name__ == "__main__":
    validate_conversion()
