"""
Verify TFLite model output with specific test cases.
"""
import tensorflow as tf
import numpy as np
from transformers import MobileBertTokenizerFast

MODEL_PATH = 'backend/ml_pipeline/data/en_hinglish/scam_detector.tflite'
TOKENIZER_PATH = 'backend/ml_pipeline/data/en_hinglish/saved_model'

# Load tokenizer and TFLite model
tokenizer = MobileBertTokenizerFast.from_pretrained(TOKENIZER_PATH)
interpreter = tf.lite.Interpreter(MODEL_PATH)
interpreter.allocate_tensors()

# Get input/output details
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("Input order:")
for i, inp in enumerate(input_details):
    print(f"  {i}: {inp['name']} - shape: {inp['shape']}")

LABELS = ['HAM', 'OTP', 'SCAM']

test_cases = [
    "Your OTP is 123456. Do not share with anyone.",
    "You won a lottery of Rs 50 lakh! Call 9876543210 to claim",
    "Hey, want to grab lunch tomorrow?",
]

print("\n" + "="*80)
for text in test_cases:
    # Tokenize with max_length=128 (matching TFLite model)
    encoded = tokenizer(
        text,
        max_length=128,
        padding='max_length',
        truncation=True,
        return_tensors='np'
    )
    
    input_ids = encoded['input_ids'].astype(np.int32)
    attention_mask = encoded['attention_mask'].astype(np.int32)
    
    print(f"\nText: {text}")
    print(f"  Input IDs (first 10): {input_ids[0][:10]}")
    
    # Set inputs
    interpreter.set_tensor(input_details[0]['index'], input_ids)
    interpreter.set_tensor(input_details[1]['index'], attention_mask)
    
    # Run inference
    interpreter.invoke()
    
    # Get output
    output = interpreter.get_tensor(output_details[0]['index'])[0]
    
    # Softmax
    exp_output = np.exp(output - np.max(output))
    probs = exp_output / np.sum(exp_output)
    
    pred_idx = np.argmax(probs)
    
    print(f"  Raw output: {output}")
    print(f"  Probabilities: HAM={probs[0]:.4f}, OTP={probs[1]:.4f}, SCAM={probs[2]:.4f}")
    print(f"  Prediction: {LABELS[pred_idx]} ({probs[pred_idx]*100:.1f}%)")
