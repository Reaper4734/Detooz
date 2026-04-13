import sys
import tensorflow as tf
import numpy as np
import os
from transformers import MobileBertTokenizerFast

# Force UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

# Setup paths assuming running from backend directory
BASE_DIR = os.getcwd()
# Tokenizer path: Verified running listing backend/ml_pipeline/saved_model
MODEL_DIR = os.path.join(BASE_DIR, "ml_pipeline", "saved_model")
# TFLite path: Verified running listing backend/ml_pipeline
TFLITE_FILE = os.path.join(BASE_DIR, "ml_pipeline", "scam_detector.tflite")

def run_automated_test():
    print("[INFO] Loading TFLite Model...")
    
    if not os.path.exists(TFLITE_FILE):
        print(f"[ERROR] TFLite model not found at {TFLITE_FILE}")
        return

    # Load Tokenizer for preprocessing
    print(f"Loading tokenizer from {MODEL_DIR}")
    try:
        tokenizer = MobileBertTokenizerFast.from_pretrained(MODEL_DIR)
    except Exception as e:
        print(f"[ERROR] Failed to load tokenizer: {e}")
        return
    
    # Load TFLite
    try:
        interpreter = tf.lite.Interpreter(model_path=TFLITE_FILE)
        interpreter.allocate_tensors()
    except Exception as e:
        print(f"[ERROR] Failed to load TFLite model: {e}")
        return
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print(f"[DEBUG] Input Details: {input_details}")
    print(f"[DEBUG] Output Details: {output_details}")
    sys.stdout.flush()

    labels = ["HAM", "OTP", "SCAM"]
    
    test_messages = [
        # Original problematic message
        'Hi mom how are you',
        
        # Variations of casual greetings
        'Hello mom, how are you doing today?',
        'Hey dad, I am fine',
        'Good morning, hope you are well',
        'How are you doing?',
        'I am fine, thank you',
        
        # "Hi Mom" scam patterns
        'Hi mom, I lost my phone',
        'Hey dad, I need money urgently',
        'Hi this is your son, send money to this number',
        'Mom I am in trouble please help',
        
        # Clear scams
        'Please send me 5000 rupees urgent',
        'Congratulations! You won lottery click here',
        'Your KYC is expiring, update now',
        
        # Clear HAM
        'Meeting at 5pm tomorrow',
        'Did you buy groceries?',
        'What time is dinner?',
        
        # OTP type
        'Your OTP is 123456',
        'Verification code: 5678',
    ]
    
    print('=' * 80)
    print(f"{'Message':<45} | {'Pred':<4} | {'Confidence'} | {'Logits'}")
    print('=' * 80)
    
    input_indices = {d['name']: d['index'] for d in input_details}
    # Heuristic to find input ids vs attention mask if names are present
    # Or just use index 0 if only 1 input
    
    use_attention_mask = len(input_details) > 1

    for msg in test_messages:
        # Tokenize (returns numpy arrays directly if we ask)
        inputs = tokenizer(msg, return_tensors="np", max_length=128, truncation=True, padding="max_length")
        
        input_ids = inputs['input_ids'].astype(np.int32)
        attention_mask = inputs['attention_mask'].astype(np.int32)
        
        # Inference
        # Try to map based on shape or index
        interpreter.set_tensor(input_details[0]['index'], input_ids)
        if use_attention_mask:
            interpreter.set_tensor(input_details[1]['index'], attention_mask)
        
        interpreter.invoke()
        
        logits = interpreter.get_tensor(output_details[0]['index'])[0]
        
        # Softmax
        exp_logits = np.exp(logits - np.max(logits))
        probs = exp_logits / exp_logits.sum()
        
        pred_idx = np.argmax(probs)
        conf = probs[pred_idx]
        
        # Show all class probabilities for borderline cases
        all_probs_str = ' | '.join([f'{labels[i]}:{probs[i]*100:.0f}%' for i in range(3)])
        
        line = f'{msg[:45]:<45} | {labels[pred_idx]:<4} | {conf*100:.1f}%'
        if conf < 0.90:
             line += f' ({all_probs_str})'
        
        print(line)

    print('=' * 80)

if __name__ == "__main__":
    run_automated_test()
