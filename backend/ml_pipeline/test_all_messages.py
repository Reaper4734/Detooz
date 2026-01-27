"""Test all the messages from the Dart integration tests."""
import tensorflow as tf
import numpy as np
from transformers import MobileBertTokenizerFast

MODEL_PATH = 'backend/ml_pipeline/data/en_hinglish/scam_detector.tflite'
TOKENIZER_PATH = 'backend/ml_pipeline/data/en_hinglish/saved_model'

tokenizer = MobileBertTokenizerFast.from_pretrained(TOKENIZER_PATH)
interpreter = tf.lite.Interpreter(MODEL_PATH)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

LABELS = ['HAM', 'OTP', 'SCAM']

def predict(text):
    encoded = tokenizer(text, max_length=128, padding='max_length', truncation=True, return_tensors='np')
    input_ids = encoded['input_ids'].astype(np.int32)
    attention_mask = encoded['attention_mask'].astype(np.int32)
    
    interpreter.set_tensor(input_details[0]['index'], input_ids)
    interpreter.set_tensor(input_details[1]['index'], attention_mask)
    interpreter.invoke()
    
    output = interpreter.get_tensor(output_details[0]['index'])[0]
    exp_output = np.exp(output - np.max(output))
    probs = exp_output / np.sum(exp_output)
    pred_idx = np.argmax(probs)
    
    return LABELS[pred_idx], probs[pred_idx]

# Scam messages
scam_msgs = [
    'You won a lottery of Rs 50 lakh! Call 9876543210 to claim',
    'Your account will be blocked. Update KYC immediately at bit.ly/xyz',
    'Congratulations! You have won iPhone 15. Click here to claim',
    'Dear customer, your bank account is frozen. Call 1800-xxx-xxxx',
    'URGENT: Pay Rs 5000 to avoid arrest. Contact 9999999999',
    'Your electricity will be cut today. Pay fine now at paytm.link/abc',
]

# OTP messages
otp_msgs = [
    'Your OTP is 123456. Do not share with anyone.',
    '567890 is your verification code for Amazon',
    'Use 998877 as your login OTP. Valid for 5 minutes.',
    'Your one time password is 445566',
]

# HAM messages
ham_msgs = [
    'Hey, want to grab lunch tomorrow?',
    'Meeting rescheduled to 3pm',
    'Thanks for the birthday wishes!',
    'Can you pick up milk on your way home?',
    'The movie was amazing, you should watch it',
]

print("="*80)
print("SCAM MESSAGES (Expected: SCAM)")
print("="*80)
for msg in scam_msgs:
    label, conf = predict(msg)
    status = "✅" if label == "SCAM" else "❌"
    print(f"{status} {label} ({conf*100:.1f}%): {msg[:50]}...")

print("\n" + "="*80)
print("OTP MESSAGES (Expected: OTP)")
print("="*80)
for msg in otp_msgs:
    label, conf = predict(msg)
    status = "✅" if label == "OTP" else "❌"
    print(f"{status} {label} ({conf*100:.1f}%): {msg[:50]}...")

print("\n" + "="*80)
print("HAM MESSAGES (Expected: HAM)")
print("="*80)
for msg in ham_msgs:
    label, conf = predict(msg)
    status = "✅" if label == "HAM" else "❌"
    print(f"{status} {label} ({conf*100:.1f}%): {msg[:50]}...")
